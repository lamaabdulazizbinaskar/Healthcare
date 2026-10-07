import uuid
from datetime import date, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

from .. import config, tracking
from ..ai import plan_engine
from ..auth import current_user
from ..ratelimit import ai_limit
from ..diseases import list_modules
from ..models import Adaptation, BPReading, GlucoseReading, Profile, UserData, now_iso
from ..report.doctor_report import build_pdf
from ..safety import red_flags
from ..store import get_repository

router = APIRouter(prefix="/api")


def _load(uid: str) -> UserData:
    return get_repository().load(uid)


def _save(uid: str, data: UserData) -> None:
    get_repository().save(uid, data)


def _require_plan(data: UserData) -> None:
    if not data.profile or not data.plan:
        raise HTTPException(404, "No plan yet. Complete onboarding first.")


def _today(day: Optional[str]) -> date:
    return date.fromisoformat(day) if day else date.today()


@router.get("/health")
def health():
    return {"status": "ok", "ai_mode": config.AI_MODE, "model": config.CLAUDE_MODEL, "store": config.STORE}


@router.get("/diseases")
def diseases():
    return list_modules()


# ---------- Profile & plan ----------

@router.get("/profile")
def get_profile(uid: str = Depends(current_user)):
    data = _load(uid)
    return {"profile": data.profile, "has_plan": data.plan is not None}


@router.get("/intake")
def intake():
    """The intake questionnaire for hypertension and/or diabetes (questions, options, sources)."""
    from ..intake.registry import SECTIONS, public_questions

    return {"sections": SECTIONS, "questions": public_questions()}


@router.post("/onboarding", dependencies=[Depends(ai_limit)])
def onboarding(profile: Profile, uid: str = Depends(current_user)):
    """Save the profile and generate the first plan in one step (fewer screens for elderly users)."""
    profile.user_id = uid
    profile.created_at = now_iso()
    from ..diseases import get_module

    try:
        exclusion = get_module(profile.disease).excluded(profile)
    except KeyError as e:
        raise HTTPException(400, str(e))
    if exclusion:
        # R10: no lifestyle plan in situations the app isn't designed for (e.g. pregnancy).
        return {"profile": profile, "plan": None, "safety": None, "excluded": exclusion}
    try:
        plan = plan_engine.generate_plan(profile)
    except KeyError as e:
        raise HTTPException(400, str(e))
    data = _load(uid)
    data.profile, data.plan = profile, plan
    data.checkins, data.adaptations, data.dismissed_adaptations = {}, [], {}
    _save(uid, data)
    # The usual BP they reported goes through the same rule engine as any reading.
    safety = (
        red_flags.evaluate(profile.usual_systolic, profile.usual_diastolic)
        if profile.usual_systolic and profile.has_hypertension
        else None
    )
    return {"profile": profile, "plan": plan, "safety": safety}


class LanguageUpdate(BaseModel):
    language: str


@router.post("/profile/language")
def set_language(body: LanguageUpdate, uid: str = Depends(current_user)):
    data = _load(uid)
    if data.profile:
        data.profile.language = "en" if body.language == "en" else "ar"
        _save(uid, data)
    return {"ok": True}


@router.post("/plan/regenerate", dependencies=[Depends(ai_limit)])
def regenerate(uid: str = Depends(current_user)):
    data = _load(uid)
    if not data.profile:
        raise HTTPException(404, "No profile")
    data.plan = plan_engine.generate_plan(data.profile)
    data.checkins, data.dismissed_adaptations = {}, {}
    _save(uid, data)
    return data.plan


@router.get("/plan")
def get_plan(uid: str = Depends(current_user)):
    data = _load(uid)
    _require_plan(data)
    return data.plan


# ---------- Checklist ----------

@router.get("/checklist")
def get_checklist(day: Optional[str] = None, uid: str = Depends(current_user)):
    data = _load(uid)
    _require_plan(data)
    today = _today(day)
    started = date.fromisoformat(data.plan.created_at[:10])
    return {
        "date": today.isoformat(),
        "plan_week": (today - started).days // 7 + 1,
        "lists": tracking.checklist(data, today),
        "pending_adaptation": tracking.pending_adaptation(data, today),
        "generated_by": data.plan.generated_by,
    }


class CheckIn(BaseModel):
    done: bool
    day: Optional[str] = None


@router.post("/checklist/{goal_id}")
def check(goal_id: str, body: CheckIn, uid: str = Depends(current_user)):
    data = _load(uid)
    _require_plan(data)
    goal = next((g for g in data.plan.goals if g.id == goal_id), None)
    if goal is None:
        raise HTTPException(404, "Unknown goal")
    key = tracking.period_key(goal.frequency, _today(body.day))
    data.checkins.setdefault(key, {})[goal_id] = body.done
    _save(uid, data)
    return {"ok": True}


# ---------- Adaptive plan ----------

class AdaptRequest(BaseModel):
    reason: str  # too_hard | no_time | pain | forgot | dont_like | not_relevant | level_up | keep
    day: Optional[str] = None


@router.post("/adapt/{goal_id}", dependencies=[Depends(ai_limit)])
def adapt(goal_id: str, body: AdaptRequest, uid: str = Depends(current_user)):
    data = _load(uid)
    _require_plan(data)
    today = _today(body.day)
    goal = next((g for g in data.plan.goals if g.id == goal_id and g.active_to is None), None)
    if goal is None:
        raise HTTPException(404, "Unknown or inactive goal")
    if body.reason == "keep":
        data.dismissed_adaptations[goal_id] = today.isoformat()
        _save(uid, data)
        return {"kept": True}
    try:
        new_goal, generated_by = plan_engine.adapt_goal(data.profile, goal, body.reason, today.isoformat())
    except ValueError as e:
        raise HTTPException(422, str(e))
    goal.active_to = today.isoformat()
    data.plan.goals.insert(data.plan.goals.index(goal) + 1, new_goal)
    data.adaptations.append(
        Adaptation(
            old_goal_id=goal.id, new_goal_id=new_goal.id, reason=body.reason, at=now_iso(),
            direction="harder" if body.reason == "level_up" else "easier",
        )
    )
    _save(uid, data)
    return {"old_goal": goal, "new_goal": new_goal, "generated_by": generated_by}


# ---------- Blood pressure & safety ----------

@router.get("/bp")
def list_bp(uid: str = Depends(current_user)):
    return sorted(_load(uid).bp, key=lambda r: r.taken_at)


@router.post("/bp")
def add_bp(reading: BPReading, uid: str = Depends(current_user)):
    data = _load(uid)
    reading.id = uuid.uuid4().hex[:10]
    reading.taken_at = reading.taken_at or now_iso()
    data.bp.append(reading)
    _save(uid, data)
    return {"reading": reading, "safety": red_flags.evaluate(reading.systolic, reading.diastolic, reading.symptoms)}


class SymptomCheck(BaseModel):
    symptoms: List[str] = []
    systolic: Optional[int] = None
    diastolic: Optional[int] = None


@router.post("/safety/check")
def safety_check(body: SymptomCheck):
    return red_flags.evaluate(body.systolic, body.diastolic, body.symptoms)


# ---------- Ask Khutwa (AI questions, grounded) ----------

class Question(BaseModel):
    question: str


@router.post("/ask", dependencies=[Depends(ai_limit)])
def ask(body: Question, uid: str = Depends(current_user)):
    from ..ai.ask import answer

    if not body.question.strip():
        raise HTTPException(400, "Empty question")
    data = _load(uid)
    disease = data.profile.disease if data.profile else "hypertension"
    titles = [g.title_en for g in data.plan.active_goals(date.today().isoformat())] if data.plan else []
    return answer(body.question, disease, data.profile, titles)


# ---------- Water habit tracker ----------

_FLUID_CAUTION_CONDITIONS = {"kidney_disease", "heart_disease"}


def _water_state(data: UserData, today: date) -> dict:
    conditions = set(data.profile.conditions) if data.profile else set()
    return {
        "date": today.isoformat(),
        "cups": data.water.get(today.isoformat(), 0),
        "target": data.water_target,
        "week": [
            {"date": (today - timedelta(days=i)).isoformat(), "cups": data.water.get((today - timedelta(days=i)).isoformat(), 0)}
            for i in range(6, -1, -1)
        ],
        # Fluid limits can matter with heart or kidney disease: tell them to ask their doctor.
        "fluid_caution": bool(conditions & _FLUID_CAUTION_CONDITIONS),
    }


@router.get("/water")
def get_water(day: Optional[str] = None, uid: str = Depends(current_user)):
    return _water_state(_load(uid), _today(day))


class WaterUpdate(BaseModel):
    delta: int = 0  # +1 / -1 cup
    target: Optional[int] = None
    day: Optional[str] = None


@router.post("/water")
def update_water(body: WaterUpdate, uid: str = Depends(current_user)):
    data = _load(uid)
    today = _today(body.day)
    key = today.isoformat()
    data.water[key] = max(0, min(30, data.water.get(key, 0) + body.delta))
    if body.target is not None:
        data.water_target = max(1, min(20, body.target))
    _save(uid, data)
    return _water_state(data, today)


# ---------- What to eat (meal suggestions) ----------

@router.get("/meals")
def meals(day: Optional[str] = None, uid: str = Depends(current_user)):
    from ..food.meals import suggestions

    return suggestions(_load(uid).profile, _today(day))


# ---------- Blood glucose (diabetes) ----------

@router.get("/glucose")
def list_glucose(uid: str = Depends(current_user)):
    return sorted(_load(uid).glucose, key=lambda r: r.taken_at)


@router.post("/glucose")
def add_glucose(reading: GlucoseReading, uid: str = Depends(current_user)):
    data = _load(uid)
    reading.id = uuid.uuid4().hex[:10]
    reading.taken_at = reading.taken_at or now_iso()
    data.glucose.append(reading)
    _save(uid, data)
    return {"reading": reading, "safety": red_flags.evaluate_glucose(reading.value, reading.symptoms)}


# ---------- Doctor report ----------

@router.get("/report")
def report(day: Optional[str] = None, uid: str = Depends(current_user)):
    data = _load(uid)
    _require_plan(data)
    return tracking.monthly_stats(data, _today(day))


@router.get("/report.pdf")
def report_pdf(day: Optional[str] = None, uid: Optional[str] = None, caller: str = Depends(current_user)):
    # `uid` query param lets a browser open the PDF link directly in demo auth mode.
    user = uid if (uid and config.AUTH == "demo") else caller
    data = _load(user)
    _require_plan(data)
    pdf = build_pdf(data, tracking.monthly_stats(data, _today(day)))
    return Response(
        pdf, media_type="application/pdf",
        headers={"Content-Disposition": 'inline; filename="khutwa-monthly-report.pdf"'},
    )


# ---------- Demo ----------

@router.post("/demo/reset")
def demo_reset():
    from seed.seed_demo import seed

    seed()
    return {"ok": True, "user_id": config.DEMO_USER_ID}
