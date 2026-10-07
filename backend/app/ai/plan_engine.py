"""Plan generation & adaptation: retrieve -> generate (Claude or mock) -> enforce grounding."""
import logging
import uuid
from datetime import date
from typing import List, Optional, Tuple

from .. import config
from ..diseases import get_module
from ..models import Goal, Plan, Profile, Source, now_iso
from ..rag.knowledge_loader import GuidelineEntry
from ..rag.retriever import get_entry, retrieve, retrieve_for_profile
from . import mock_ai, prompts
from .claude_client import AIError, structured_call

log = logging.getLogger("lifestep.plan")

_MAX = {"daily": 7, "weekly": 4, "monthly": 3}  # mock caps daily at 6 (7 for "both")
_TIMES = {"morning", "afternoon", "evening", "anytime"}


def _new_id(freq: str) -> str:
    return f"{freq[0]}-{uuid.uuid4().hex[:8]}"


def _to_goals(raw_goals: List[dict], allowed: List[GuidelineEntry], start: str) -> List[Goal]:
    """Grounding guardrail: drop any goal that does not cite a retrieved guideline entry."""
    by_id = {e.id: e for e in allowed}
    counts = {"daily": 0, "weekly": 0, "monthly": 0}
    goals = []
    for g in raw_goals:
        ids = [i for i in g.get("source_ids", []) if i in by_id]
        freq = g.get("frequency")
        if not ids or freq not in counts:
            log.warning("Dropping ungrounded/invalid goal: %s", g.get("title_en"))
            continue
        if counts[freq] >= _MAX[freq]:
            continue
        counts[freq] += 1
        goals.append(Goal(
            id=_new_id(freq),
            frequency=freq,
            category=g["category"],
            title_en=g["title_en"].strip(),
            title_ar=g["title_ar"].strip(),
            why_en=g["why_en"].strip(),
            why_ar=g["why_ar"].strip(),
            tailoring_en=g.get("tailoring_en", "").strip(),
            tailoring_ar=g.get("tailoring_ar", "").strip(),
            time_of_day=g.get("time_of_day") if g.get("time_of_day") in _TIMES else "anytime",
            sources=[Source(id=i, title=by_id[i].title, citation=by_id[i].source) for i in ids],
            active_from=start,
        ))
    return goals


def generate_plan(profile: Profile, start: Optional[str] = None, force_mock: bool = False) -> Plan:
    start = start or date.today().isoformat()
    module = get_module(profile.disease)
    entries = retrieve_for_profile(profile)
    cautions = module.patient_cautions(profile)

    goals: List[Goal] = []
    summary = {"summary_en": "", "summary_ar": ""}
    generated_by = "mock"
    if config.AI_MODE == "claude" and not force_mock:
        try:
            result = structured_call(
                prompts.PLAN_SYSTEM,
                prompts.plan_user_message(profile, entries, cautions),
                prompts.PLAN_SCHEMA,
            )
            goals = _to_goals(result.get("goals", []), entries, start)
            summary = {k: result.get(k, "").strip() for k in summary}
            generated_by = f"claude:{config.CLAUDE_MODEL}"
            if len(goals) < 3:
                log.warning("Claude plan had too few grounded goals (%d); using mock plan", len(goals))
                goals = []
        except AIError as e:
            log.error("Claude plan generation failed, falling back to mock: %s", e)
    if not goals:
        raw = mock_ai.generate_plan(profile, [e.id for e in entries], cautions)
        goals = _to_goals(raw, entries, start)
        summary = mock_ai.plan_summary(profile)
        generated_by = "mock"

    order = {"daily": 0, "weekly": 1, "monthly": 2}
    goals.sort(key=lambda g: order[g.frequency])
    return Plan(
        user_id=profile.user_id,
        disease=profile.disease,
        created_at=now_iso(),
        generated_by=generated_by,
        goals=goals,
        retrieved_ids=[e.id for e in entries],
        insights=module.insights(profile),
        **summary,
    )


def adapt_goal(
    profile: Profile, goal: Goal, reason: str, today: str, force_mock: bool = False
) -> Tuple[Goal, str]:
    """Return (new_goal, generated_by). The new goal stays grounded in guideline entries."""
    module = get_module(profile.disease)
    entries = [get_entry(s.id) for s in goal.sources if get_entry(s.id)]
    query = f"{goal.category} {goal.title_en} {prompts.REASON_TEXT.get(reason, reason)} older adults limitations"
    for e in retrieve(profile.disease, query, k=3):
        if e.id not in {x.id for x in entries} and module.is_applicable(e, profile):
            entries.append(e)

    raw = None
    generated_by = "mock"
    if config.AI_MODE == "claude" and not force_mock:
        try:
            raw = structured_call(
                prompts.ADAPT_SYSTEM,
                prompts.adapt_user_message(
                    profile,
                    goal.model_dump_json(include={"frequency", "category", "title_en", "why_en", "time_of_day", "level", "sources"}),
                    reason, entries, module.patient_cautions(profile),
                ),
                prompts.GOAL_SCHEMA,
                max_tokens=4000,
            )
            generated_by = f"claude:{config.CLAUDE_MODEL}"
        except AIError as e:
            log.error("Claude adaptation failed, falling back to mock: %s", e)
    if raw is None:
        raw = mock_ai.adapt_goal(goal.model_dump(), reason)
        generated_by = "mock"
    new_goals = _to_goals([raw] if raw else [], entries, today)
    if not new_goals:
        raise ValueError("Could not produce a grounded adapted goal")
    new_goal = new_goals[0]
    new_goal.replaces = goal.id
    new_goal.level = goal.level + 1 if reason == "level_up" else max(1, goal.level - 1)
    return new_goal, generated_by
