"""Seed the demo patient: an elderly man with hypertension and ~4 weeks of history.

Run manually:  python -m seed.seed_demo   (from backend/)
It is also run automatically on first API start in local-store mode, and via POST /api/demo/reset.
"""
import random
from datetime import date, datetime, time, timedelta

from app import config
from app.ai import plan_engine
from app.models import Adaptation, BPReading, Profile, UserData
from app.store import get_repository
from app.tracking import period_key

DAYS = 28

PROFILE = Profile(
    user_id=config.DEMO_USER_ID,
    name="Abdullah Al-Harbi",
    disease="both",
    age=68,
    sex="male",
    weight_kg=92,
    height_cm=170,
    medications=["Amlodipine 5 mg (morning)", "Losartan 50 mg (morning)"],
    limitations=["knee_pain", "uses_cane", "unsteady"],
    activity_level="low",
    diet_habits=["stock_cubes", "arabic_coffee", "salty_cheese", "eats_out_often"],
    language="ar",
    diagnosed="over_5_years",
    usual_systolic=152,
    usual_diastolic=94,
    conditions=["high_cholesterol"],
    family_history="yes",
    priorities=["salt", "activity"],
    # Evidence-based intake answers (see app/intake/hypertension.py)
    home_monitor="upper_arm",
    missed_doses="some",
    activity_days=2,
    activity_minutes=10,
    fruit_veg="1_2",
    salt_table="often",
    salt_cooking="always",
    salty_foods="often",
    tobacco="never",
    sleep_hours="5_6",
    sleep_signs=["snoring", "tired"],
    # Diabetes (ADA 2026 intake)
    diabetes_type="type2",
    diabetes_meds=["metformin", "sulfonylurea"],
    low_sugar="sometimes",
    glucose_monitor="meter",
    complications=["neuropathy"],
    fasting="yes",
    sugary_drinks="often",
    refined_grains="often",
    sitting_hours="gt8",
    mood="sometimes",
)


def seed(today: date = None) -> UserData:
    today = today or date.today()
    rng = random.Random(42)
    start = today - timedelta(days=DAYS - 1)

    profile = PROFILE.model_copy(deep=True)
    profile.created_at = datetime.combine(start, time(9, 0)).isoformat()
    plan = plan_engine.generate_plan(profile, start=start.isoformat(), force_mock=True)
    plan.created_at = profile.created_at
    data = UserData(profile=profile, plan=plan)

    # 1) A past adaptation: the medicine goal was replaced 16 days ago because he kept forgetting.
    adapt_day = today - timedelta(days=16)
    med_goal = next((g for g in plan.goals if g.category == "medication" and g.frequency == "daily"), None)
    if med_goal:
        # force_mock keeps the seed deterministic and offline even when a Claude key is configured.
        new_goal, _ = plan_engine.adapt_goal(profile, med_goal, "forgot", adapt_day.isoformat(), force_mock=True)
        med_goal.active_to = adapt_day.isoformat()
        plan.goals.insert(plan.goals.index(med_goal) + 1, new_goal)
        data.adaptations.append(Adaptation(
            old_goal_id=med_goal.id, new_goal_id=new_goal.id, reason="forgot",
            at=datetime.combine(adapt_day, time(20, 15)).isoformat(),
        ))

    # 2) Check-ins: adherence improves over the month. The seated-exercise goal is missed
    #    for the last 3 days so the demo shows the adaptive "why?" question.
    seated = next((g for g in plan.goals if g.category == "activity" and g.frequency == "daily"), None)
    # ...and one goal he has done every day for the past week, so the demo can offer a step up.
    star = next(
        (g for g in plan.goals if g.frequency == "daily" and g.category == "diet" and g.title_en.startswith("Eat vegetables")),
        next((g for g in plan.goals if g.frequency == "daily" and g.category == "diet"), None),
    )
    for i in range(DAYS):
        day = start + timedelta(days=i)
        if day >= today:
            break  # leave today unticked for the live demo
        progress = i / DAYS
        for g in plan.active_goals(day.isoformat()):
            key = period_key(g.frequency, day)
            if g.frequency == "daily":
                if seated and g.id == seated.id and (today - day).days <= 3:
                    continue
                if star and g.id == star.id and (today - day).days <= 7:
                    data.checkins.setdefault(key, {})[g.id] = True
                    continue
                p_done = 0.45 + 0.4 * progress
                if g.category == "medication":
                    p_done = 0.4 if g.id == (med_goal.id if med_goal else "") else 0.92
                if rng.random() < p_done:
                    data.checkins.setdefault(key, {})[g.id] = True
            elif day.weekday() == 4 and key != period_key(g.frequency, today):  # Friday review of past weeks
                if rng.random() < 0.7:
                    data.checkins.setdefault(key, {})[g.id] = True
            elif g.frequency == "monthly" and key != period_key("monthly", today) and day.day == 28:
                data.checkins.setdefault(key, {})[g.id] = True

    # Water: a few cups most days, today partly done.
    for i in range(DAYS):
        day = start + timedelta(days=i)
        data.water[day.isoformat()] = 3 if day == today else rng.randint(4, 8)

    # 3) BP readings, morning and (most) evenings, trending from ~154/95 down to ~138/86.
    for i in range(DAYS):
        day = start + timedelta(days=i)
        trend = i / (DAYS - 1)
        for slot, hour in (("am", 7), ("pm", 20)):
            if slot == "pm" and rng.random() < 0.35:
                continue
            if day == today and slot == "pm":
                continue
            sys_ = round(154 - 16 * trend + rng.gauss(0, 4) + (3 if slot == "am" else 0))
            dia = round(95 - 9 * trend + rng.gauss(0, 3))
            if i == 9 and slot == "am":
                sys_, dia = 172, 104  # one high reading after a wedding dinner
            data.bp.append(BPReading(
                id=f"seed{i:02d}{slot}",
                systolic=sys_, diastolic=dia, pulse=round(72 + rng.gauss(0, 5)),
                taken_at=datetime.combine(day, time(hour, rng.randint(0, 40))).isoformat(),
            ))

    # 4) Blood glucose (meter): fasting most mornings, some after-meal readings; improving over the month.
    from app.models import GlucoseReading

    for i in range(DAYS):
        day = start + timedelta(days=i)
        trend = i / (DAYS - 1)
        if day <= today:
            data.glucose.append(GlucoseReading(
                id=f"g{i:02d}f", value=round(158 - 30 * trend + rng.gauss(0, 9)), context="fasting",
                taken_at=datetime.combine(day, time(6, rng.randint(30, 59))).isoformat(),
            ))
        if i % 3 == 1 and day < today:
            data.glucose.append(GlucoseReading(
                id=f"g{i:02d}a", value=round(212 - 35 * trend + rng.gauss(0, 14)), context="after_meal",
                taken_at=datetime.combine(day, time(15, rng.randint(0, 40))).isoformat(),
            ))
    data.glucose.append(GlucoseReading(  # one low (level 1) two weeks ago, before lunch
        id="glow", value=66, context="before_meal",
        taken_at=datetime.combine(today - timedelta(days=14), time(12, 10)).isoformat(),
    ))

    get_repository().save(config.DEMO_USER_ID, data)
    return data


if __name__ == "__main__":
    d = seed()
    print(f"Seeded {config.DEMO_USER_ID}: {len(d.plan.goals)} goals, {len(d.bp)} BP readings")
