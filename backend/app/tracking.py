"""Check-ins, missed-goal detection and monthly statistics (pure functions over UserData)."""
from datetime import date, datetime, timedelta
from statistics import mean
from typing import Dict, List, Optional

from .models import Goal, UserData
from .safety.red_flags import CRISIS_DIASTOLIC, CRISIS_SYSTOLIC

MISSED_DAYS_THRESHOLD = 3
LEVEL_UP_DAYS = 6  # of the last 7 days
MAX_LEVEL = 3


def period_key(freq: str, day: date) -> str:
    if freq == "daily":
        return day.isoformat()
    if freq == "weekly":
        y, w, _ = day.isocalendar()
        return f"{y}-W{w:02d}"
    return f"{day.year}-{day.month:02d}"


def is_done(data: UserData, goal: Goal, day: date) -> bool:
    return data.checkins.get(period_key(goal.frequency, day), {}).get(goal.id, False)


def checklist(data: UserData, day: date) -> Dict[str, List[dict]]:
    out: Dict[str, List[dict]] = {"daily": [], "weekly": [], "monthly": []}
    if not data.plan:
        return out
    for g in data.plan.active_goals(day.isoformat()):
        out[g.frequency].append({"goal": g.model_dump(), "done": is_done(data, g, day)})
    return out


def consecutive_missed_days(data: UserData, goal: Goal, today: date) -> int:
    """Days in a row before today (not counting today) on which a daily goal was not ticked."""
    missed = 0
    day = today - timedelta(days=1)
    start = date.fromisoformat(goal.active_from)
    while day >= start and missed < 30:
        if is_done(data, goal, day):
            break
        missed += 1
        day -= timedelta(days=1)
    return missed


def done_in_last_days(data: UserData, goal: Goal, today: date, days: int = 7) -> int:
    return sum(1 for i in range(1, days + 1) if is_done(data, goal, today - timedelta(days=i)))


def pending_adaptation(data: UserData, today: date) -> Optional[dict]:
    """The single daily goal (if any) the app should ask about. One question at a time.

    * "struggling": missed MISSED_DAYS_THRESHOLD+ days in a row -> ask why, make it easier.
    * "ready": done on LEVEL_UP_DAYS of the last 7 days -> offer the next step up.
    Struggling goals are asked about first.
    """
    if not data.plan:
        return None
    struggling = None
    ready = None
    # At most one "step up" offer per day (accepted or declined), so the patient isn't nagged.
    today_s = today.isoformat()
    offered_today = any(a.direction == "harder" and a.at[:10] == today_s for a in data.adaptations) or any(
        v == today_s for v in data.dismissed_adaptations.values()
    )
    for g in data.plan.active_goals(today.isoformat()):
        if g.frequency != "daily":
            continue
        dismissed = data.dismissed_adaptations.get(g.id)
        days_since_dismissed = (today - date.fromisoformat(dismissed)).days if dismissed else 999
        missed = consecutive_missed_days(data, g, today)
        if missed >= MISSED_DAYS_THRESHOLD and days_since_dismissed >= MISSED_DAYS_THRESHOLD:
            if struggling is None or missed > struggling[1]:
                struggling = (g, missed)
            continue
        active_days = (today - date.fromisoformat(g.active_from)).days
        if not offered_today and active_days >= 7 and g.level < MAX_LEVEL and days_since_dismissed >= 7:
            done = done_in_last_days(data, g, today)
            if done >= LEVEL_UP_DAYS and (ready is None or done > ready[1]):
                ready = (g, done)
    if struggling:
        return {"type": "struggling", "goal": struggling[0].model_dump(), "missed_days": struggling[1]}
    if ready:
        return {"type": "ready", "goal": ready[0].model_dump(), "done_days": ready[1]}
    return None


def _readings_between(data: UserData, start: date, end: date):
    out = []
    for r in data.bp:
        d = datetime.fromisoformat(r.taken_at).date()
        if start <= d <= end:
            out.append(r)
    return sorted(out, key=lambda r: r.taken_at)


def monthly_stats(data: UserData, end: date, days: int = 30) -> dict:
    start = end - timedelta(days=days - 1)
    plan = data.plan

    # Adherence: daily goals counted per day, weekly per ISO week, monthly per month.
    expected = done = 0
    per_goal: Dict[str, Dict] = {}
    seen_periods = set()
    if plan:
        day = start
        while day <= end:
            for g in plan.active_goals(day.isoformat()):
                key = (g.id, period_key(g.frequency, day))
                if key in seen_periods:
                    continue
                seen_periods.add(key)
                ok = is_done(data, g, day)
                # The current day/week/month is still in progress: don't count it as missed yet.
                if not ok and period_key(g.frequency, day) == period_key(g.frequency, end):
                    continue
                expected += 1
                done += ok
                stats = per_goal.setdefault(g.id, {"goal": g, "expected": 0, "done": 0})
                stats["expected"] += 1
                stats["done"] += ok
            day += timedelta(days=1)
    adherence = round(100 * done / expected) if expected else 0

    readings = _readings_between(data, start, end)
    bp = {"count": len(readings)}
    if readings:
        first = readings[: max(1, min(7, len(readings) // 3))]
        last = readings[-max(1, min(7, len(readings) // 3)):]
        bp.update(
            avg_systolic=round(mean(r.systolic for r in readings)),
            avg_diastolic=round(mean(r.diastolic for r in readings)),
            first_avg=f"{round(mean(r.systolic for r in first))}/{round(mean(r.diastolic for r in first))}",
            last_avg=f"{round(mean(r.systolic for r in last))}/{round(mean(r.diastolic for r in last))}",
            change_systolic=round(mean(r.systolic for r in last) - mean(r.systolic for r in first)),
            max=max(readings, key=lambda r: r.systolic).model_dump(),
            min=min(readings, key=lambda r: r.systolic).model_dump(),
            crisis_count=sum(
                1 for r in readings if r.systolic >= CRISIS_SYSTOLIC or r.diastolic >= CRISIS_DIASTOLIC
            ),
            above_target_count=sum(1 for r in readings if r.systolic >= 140 or r.diastolic >= 90),
            with_symptoms=[r.model_dump() for r in readings if r.symptoms],
        )

    gl = [g for g in data.glucose if start.isoformat() <= g.taken_at[:10] <= end.isoformat()]
    glucose = {"count": len(gl)}
    if gl:
        fasting = [g.value for g in gl if g.context == "fasting"]
        glucose.update(
            avg=round(mean(g.value for g in gl)),
            fasting_avg=round(mean(fasting)) if fasting else None,
            # ADA 2026 Table 6.4 levels and Table 6.3 target band (70–180 mg/dL used as a simple "in range" share).
            lows=sum(1 for g in gl if g.value < 70),
            very_lows=sum(1 for g in gl if g.value < 54),
            in_range_pct=round(100 * sum(1 for g in gl if 70 <= g.value <= 180) / len(gl)),
            highest=max(g.value for g in gl),
        )

    goal_rows = sorted(
        (
            {
                "title_en": s["goal"].title_en,
                "title_ar": s["goal"].title_ar,
                "frequency": s["goal"].frequency,
                "adherence": round(100 * s["done"] / s["expected"]) if s["expected"] else 0,
                "retired": s["goal"].active_to is not None,
            }
            for s in per_goal.values()
        ),
        key=lambda r: r["adherence"],
    )
    difficulties = []
    if plan:
        by_id = {g.id: g for g in plan.goals}
        for a in data.adaptations:
            if start.isoformat() <= a.at[:10] <= end.isoformat() and a.old_goal_id in by_id:
                old, new = by_id[a.old_goal_id], by_id.get(a.new_goal_id)
                difficulties.append({
                    "reason": a.reason,
                    "direction": a.direction,
                    "date": a.at[:10],
                    "old_en": old.title_en, "old_ar": old.title_ar,
                    "new_en": new.title_en if new else "", "new_ar": new.title_ar if new else "",
                })
    return {
        "period": {"start": start.isoformat(), "end": end.isoformat()},
        "adherence_percent": adherence,
        "goals": goal_rows,
        "bp": bp,
        "glucose": glucose,
        "difficulties": difficulties,
    }
