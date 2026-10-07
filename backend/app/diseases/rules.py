"""Shared, deterministic decision rules (R1–R22) for hypertension and diabetes.

Every rule cites ONLY the two reference documents:
  * ACC/AHA 2017 – Whelton et al., 2017 High Blood Pressure Guideline (JACC 2018;71:e127–e248)
  * ADA 2026     – Standards of Care in Diabetes—2026 (Diabetes Care 2026;49(Suppl. 1))
The AI never decides these; it only words goals inside the limits they set.
"""
from typing import Dict, List, Optional

from ..models import Profile

ACC = "ACC/AHA 2017"
ADA = "ADA 2026"

SRC: Dict[str, str] = {
    "R1": f"{ACC} §6.2 rec 1, Table 15; {ADA} rec 5.12",
    "R2": f"{ACC} §6.2 rec 3, Table 15; {ADA} rec 5.20",
    "R3": f"{ACC} §6.2 rec 2 (DASH); {ADA} rec 5.14",
    "R4": f"{ADA} §5 pre-exercise risk (S104), recs 5.34–5.36; {ACC} §6.2 rec 5, Table 15",
    "R5": f"{ACC} §11.2 (crisis > 180/120)",
    "R6": f"{ACC} §4.2, Table 10; {ADA} rec 10.2",
    "R7": f"{ACC} §12.1",
    "R8": f"{ACC} §6.2 rec 4, Table 15 (potassium contraindications)",
    "R9": f"{ADA} §5 pre-exercise risk (S104)",
    "R10": f"{ACC} §10.2.2 (pregnancy); {ADA} rec 10.12",
    "R11": f"{ADA} rec 5.40; {ACC} Table 5",
    "R12": f"{ADA} recs 5.56–5.57; {ACC} §5.4.4, Table 5 (sleep apnoea)",
    "R13": f"{ADA} §4 person-centred collaborative care; {ACC} §12",
    "R14": f"{ADA} recs 5.38, 13.2, 13.11b",
    "R15": f"{ADA} §5 exercise & hypoglycemia (S105), recs 6.10, 6.15, 13.4",
    "R16": f"{ADA} recs 5.21, 5.25",
    "R17": f"{ADA} recs 5.14, 5.15, 5.24",
    "R18": f"{ADA} §5 exercise with retinopathy / neuropathy (S107), recs 12.30–12.31",
    "R19": f"{ADA} recs 6.1–6.3, Table 6.3",
    "R20": f"{ADA} recs 5.32–5.33",
    "R21": f"{ADA} recs 5.42–5.48",
    "R22": f"{ADA} rec 5.34 (break up sitting every 30 min)",
}

_K_RAISING = ("pril", "sartan", "spironolactone", "eplerenone", "amiloride", "triamterene")
_FALL_RISK = {"fallen", "unsteady", "worried_falling", "uses_cane", "uses_walker", "balance_problems"}
_JOINT = {"knee_pain", "hip_pain", "back_pain"}
_OFTEN = {"always", "often"}


# ----------------------------------------------------------------- derived facts
def k_raising(p: Profile) -> bool:
    return any(k in " ".join(p.medications).lower() for k in _K_RAISING)


def fall_risk(p: Profile) -> bool:
    return bool(set(p.limitations) & _FALL_RISK)


def joint_problem(p: Profile) -> bool:
    return bool(set(p.limitations) & _JOINT)


def bp_uncontrolled(p: Profile) -> bool:
    """Usual BP ≥ 160/100: ADA S104 lists inadequately managed hypertension as needing assessment before
    some exercise. (Team choice of the stage-2 cut-off; needs clinician sign-off.)"""
    return (p.usual_systolic or 0) >= 160 or (p.usual_diastolic or 0) >= 100


def activity_restricted(p: Profile) -> bool:
    """R4/R9: warning symptoms or uncontrolled BP → only light movement until a doctor has advised."""
    return bool(p.activity_safety) or bp_uncontrolled(p)


def hypo_risk(p: Profile) -> bool:
    """R15: insulin or insulin secretagogues (sulfonylureas) or recent low sugar episodes."""
    return p.has_diabetes and (
        bool(set(p.diabetes_meds) & {"insulin", "sulfonylurea"}) or p.low_sugar in ("sometimes", "often", "severe")
    )


def retinopathy(p: Profile) -> bool:
    return "retinopathy" in p.complications


def foot_risk(p: Profile) -> bool:
    return bool(set(p.complications) & {"neuropathy", "foot_ulcer"})


def smokes(p: Profile) -> bool:
    return p.tobacco in ("daily", "sometimes") or bool(set(p.diet_habits) & {"smokes", "shisha"})


def salty(p: Profile) -> bool:
    return p.salt_table in _OFTEN or p.salt_cooking in _OFTEN or p.salty_foods in _OFTEN or bool(
        set(p.diet_habits) & {"stock_cubes", "salty_cheese", "pickles", "eats_out_often"}
    )


def salty_cooking_or_foods(p: Profile) -> bool:
    return p.salt_cooking in _OFTEN or p.salty_foods in _OFTEN or bool(
        set(p.diet_habits) & {"stock_cubes", "salty_cheese", "pickles", "eats_out_often"}
    )


def low_veg(p: Profile) -> bool:
    return p.fruit_veg != "5_plus"


def sugary(p: Profile) -> bool:
    return p.sugary_drinks in _OFTEN or p.sugary_drinks == "sometimes"


def refined(p: Profile) -> bool:
    return p.refined_grains in _OFTEN


def short_or_poor_sleep(p: Profile) -> bool:
    return p.sleep_hours in ("lt5", "5_6") or bool(p.sleep_signs)


def possible_sleep_apnoea(p: Profile) -> bool:
    return sum(1 for s in ("snoring", "tired", "observed") if s in p.sleep_signs) >= 2 or "observed" in p.sleep_signs


def weekly_minutes(p: Profile) -> Optional[int]:
    return p.weekly_activity_minutes


def activity_level(p: Profile) -> str:
    m = weekly_minutes(p)
    if m is None:
        return p.activity_level
    if m < 30:
        return "very_low"
    if m < 90:
        return "low"
    if m < 150:
        return "moderate"
    return "high"


# Kept for older imports.
effective_activity_level = activity_level


# ----------------------------------------------------------------- exclusions
def excluded(p: Profile) -> Optional[Dict[str, str]]:
    """R10: pregnancy → no lifestyle plan (specialist-led care)."""
    if p.sex == "female" and p.pregnant == "yes":
        return {
            "reason": "pregnancy",
            "title_en": "Please talk to your doctor first",
            "title_ar": "يُرجى التحدث مع طبيبك أولًا",
            "message_en": (
                "Pregnancy changes how high blood pressure and diabetes are managed, and some blood pressure "
                "medicines must not be used in pregnancy. LifeStep is not designed for pregnancy, so we won't build "
                "a plan. Please contact your doctor or antenatal clinic. If you have a severe headache, vision "
                "changes or chest pain, call 997."
            ),
            "message_ar": (
                "الحمل يغيّر طريقة علاج الضغط والسكري، وبعض أدوية الضغط لا تُستخدم أثناء الحمل. تطبيق خطوة حياة غير "
                "مصمم للحمل، لذلك لن نبني خطة. يُرجى التواصل مع طبيبك أو عيادة متابعة الحمل. إذا كان لديك صداع "
                "شديد أو تغيّر في النظر أو ألم في الصدر، اتصلي على 997."
            ),
            "source": f"{ACC} §10.2.2 (ACE inhibitors/ARBs must not be used in pregnancy); {ADA} rec 10.12",
        }
    return None


# ----------------------------------------------------------------- cautions for the AI
def cautions(p: Profile) -> List[str]:
    c = []
    if k_raising(p) or "kidney_disease" in p.conditions:
        c.append("Kidney disease or potassium-raising medicine: no goal to increase potassium (ACC/AHA §6.2 rec 4).")
    if activity_restricted(p):
        c.append("Warning symptoms or BP ≥ 160/100: only light movement / less sitting; no exercise targets, no "
                 "handgrip or strength training; tell them to check with their doctor first (ADA S104).")
    if set(p.conditions) & {"heart_disease", "stroke"}:
        c.append("Heart disease or stroke: gentle activity only; mention checking with their doctor (ADA S104).")
    if fall_risk(p) or joint_problem(p):
        c.append("Fall risk or joint pain: seated / chair-supported low-impact activity with balance work.")
    if hypo_risk(p):
        c.append("Insulin/sulfonylurea or recent low sugars: any activity goal must mention checking glucose and "
                 "carrying quick glucose (ADA S105); never suggest skipping meals.")
    if retinopathy(p):
        c.append("Diabetic eye disease: no vigorous or heavy-lifting exercise (ADA S107).")
    if foot_risk(p):
        c.append("Numb feet or foot ulcer history: low-impact activity, daily foot checks, proper footwear (ADA S107, 12.30).")
    if p.home_monitor in ("none", "wrist"):
        c.append("No upper-arm monitor: no daily home-reading goal; suggest asking about a validated device (ACC/AHA Table 10).")
    if p.missed_doses in ("some", "many"):
        c.append("Missed BP medicine doses: medicine routine is the first daily goal (ACC/AHA §12.1).")
    if p.missed_doses == "stopped":
        c.append("Stopped BP medicines: no medicine goals; never advise restarting – refer to their doctor.")
    if p.fasting == "yes":
        c.append("Plans to fast Ramadan: include a goal to see the care team well before fasting (ADA 5.32–5.33).")
    if p.age >= 75 or activity_level(p) == "very_low":
        c.append("Start activity goals very small (a few minutes) and build up gradually.")
    c.append("Never suggest starting, stopping or changing any medicine or dose, or skipping meals.")
    return c
