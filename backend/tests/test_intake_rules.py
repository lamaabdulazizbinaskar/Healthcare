"""Each intake answer must drive the decision documented in app/intake/registry.py (rules R1–R22)."""
from app.ai.plan_engine import generate_plan
from app.diseases import get_module
from app.diseases.rules import SRC, possible_sleep_apnoea
from app.intake.registry import QUESTIONS
from app.models import Profile
from app.rag.retriever import get_entry, retrieve_for_profile


def profile(**kw) -> Profile:
    base = dict(age=60, sex="male", weight_kg=75, height_cm=175)  # BMI 24.5
    base.update(kw)
    return Profile(**base)


def ids(p: Profile):
    return {s.id for g in generate_plan(p, force_mock=True).goals for s in g.sources}


def test_only_the_two_reference_documents_are_cited():
    allowed = ("ACC/AHA", "ADA", "Team-authored", "Not clinical")
    for q in QUESTIONS:
        assert q["source"].strip() and q["drives"].strip() and q["why_en"].strip() and q["why_ar"].strip(), q["id"]
        assert any(a in q["source"] for a in allowed), q["id"]
        for banned in ("WHO", "PAR-Q", "STEADI", "STOP-Bang", "GPAQ", "KDIGO", "Life's Essential"):
            assert banned not in q["source"], (q["id"], banned)
    for rule, src in SRC.items():
        assert "ACC/AHA 2017" in src or "ADA 2026" in src, rule
    for disease in ("hypertension", "diabetes", "both"):
        for e in retrieve_for_profile(profile(disease=disease)):
            assert any(a in e.source for a in allowed), e.id


def test_r10_pregnancy_excludes_plan():
    m = get_module("both")
    assert m.excluded(profile(sex="female", age=30, pregnant="yes"))["reason"] == "pregnancy"
    assert m.excluded(profile(sex="female", age=30, pregnant="no")) is None


def test_r4_warning_symptoms_mean_light_movement_only():
    got = ids(profile(disease="both", activity_safety=["chest_pain"]))
    assert "DM-ACT-05" in got
    assert not got & {"HTN-ACTIVITY-01", "HTN-ACTIVITY-05", "HTN-ACTIVITY-06", "DM-ACT-01", "DM-ACT-02"}


def test_r1_weight_goal_only_when_overweight_and_ada_target_with_diabetes():
    assert not any(i.endswith("WEIGHT-01") for i in ids(profile(disease="both")))
    got = ids(profile(disease="both", weight_kg=95))
    assert "DM-WEIGHT-01" in got and "HTN-WEIGHT-01" not in got


def test_r6_no_daily_home_bp_without_arm_monitor():
    got = ids(profile(disease="hypertension", home_monitor="none"))
    assert "HTN-HBPM-02" not in got and "HTN-HBPM-01" in got


def test_r7_stopped_medicines_get_no_medicine_goals():
    assert not any(i.startswith("HTN-MEDS") for i in ids(profile(medications=["Amlodipine"], missed_doses="stopped")))


def test_r8_no_potassium_goal_with_arb_or_kidney_disease():
    assert "HTN-POTASSIUM-01" not in ids(profile(medications=["Losartan 50 mg"]))
    assert "HTN-POTASSIUM-01" not in ids(profile(conditions=["kidney_disease"]))


def test_r15_low_sugar_safety_with_insulin_or_sulfonylurea():
    assert "DM-ACT-06" in ids(profile(disease="diabetes", diabetes_meds=["sulfonylurea"]))
    assert "DM-ACT-06" not in ids(profile(disease="diabetes", diabetes_meds=["metformin"], low_sugar="none"))


def test_r16_water_goal_for_sugary_drinks():
    assert "DM-NUTR-03" in ids(profile(disease="diabetes", sugary_drinks="often"))
    assert "DM-NUTR-03" not in ids(profile(disease="diabetes", sugary_drinks="never"))


def test_r18_feet_and_eyes():
    got = ids(profile(disease="diabetes", complications=["neuropathy"]))
    assert "DM-FOOT-01" in got and "DM-ACT-08" in got
    assert "HTN-ACTIVITY-06" not in ids(profile(disease="both", complications=["retinopathy"]))


def test_r20_ramadan_planning_goal():
    assert "DM-FAST-01" in ids(profile(disease="diabetes", fasting="yes"))


def test_r11_smoke_free_goal_only_for_smokers():
    assert "HTN-TOBACCO-01" in ids(profile(tobacco="daily"))
    assert "HTN-TOBACCO-01" not in ids(profile(tobacco="quit"))


def test_r12_sleep_apnoea_flag():
    assert possible_sleep_apnoea(profile(sleep_signs=["snoring", "observed"]))
    assert not possible_sleep_apnoea(profile(sleep_signs=["tired"]))


def test_diabetes_only_plan_has_no_hypertension_entries():
    assert not any(i.startswith("HTN-") for i in ids(profile(disease="diabetes", medications=["Losartan"])))


def test_every_goal_source_exists_in_the_knowledge_base():
    for d in ("hypertension", "diabetes", "both"):
        for g in generate_plan(profile(disease=d, weight_kg=95, sugary_drinks="often"), force_mock=True).goals:
            for s in g.sources:
                assert get_entry(s.id) is not None, s.id
