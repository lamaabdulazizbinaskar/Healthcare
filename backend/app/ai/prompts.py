"""Prompts and JSON schemas for every Claude call. Kept in one place for review."""
import json
from typing import List

from ..models import Profile
from ..rag.knowledge_loader import GuidelineEntry

CATEGORIES = ["diet", "activity", "medication", "monitoring", "weight", "lifestyle", "selfcare"]

GROUNDING_RULES = """\
STRICT GROUNDING RULES (patient safety):
1. Every goal MUST be based only on the GUIDELINE EXCERPTS provided. List the excerpt IDs it
   is based on in `source_ids`. Never cite an ID that is not in the excerpts.
2. Do not add medical facts, numbers, foods, exercises or claims that are not stated in or
   directly implied by the excerpts. Personalising (making a goal smaller, seated, or tied to
   the patient's routine) is allowed; inventing new advice is not.
3. Never tell the patient to start, stop, or change any medicine or dose.
4. Never diagnose. This app supports, and does not replace, the doctor's plan.
5. Respect every PATIENT CAUTION below.
"""

LANGUAGE_RULES = """\
WRITING STYLE (many users are elderly):
- Write every text twice: natural English (`_en`) and natural Modern Standard Arabic that a
  Saudi elderly reader understands (`_ar`). Not a word-for-word translation.
- Titles: an action the patient can tick off, max ~8 words, concrete (what, how much, when).
- `why_*`: 1–2 short sentences, plain language, no jargon, explain the benefit for blood pressure.
- `tailoring_*`: one short sentence saying how this goal was adapted to THIS patient
  (e.g. "Seated because of your knee pain"), or an empty string if not personalised.
"""

_goal_props = {
    "frequency": {"type": "string", "enum": ["daily", "weekly", "monthly"]},
    "category": {"type": "string", "enum": CATEGORIES},
    "title_en": {"type": "string"},
    "title_ar": {"type": "string"},
    "why_en": {"type": "string"},
    "why_ar": {"type": "string"},
    "tailoring_en": {"type": "string"},
    "tailoring_ar": {"type": "string"},
    "time_of_day": {"type": "string", "enum": ["morning", "afternoon", "evening", "anytime"]},
    "source_ids": {"type": "array", "items": {"type": "string"}},
}
GOAL_SCHEMA = {
    "type": "object",
    "properties": _goal_props,
    "required": list(_goal_props.keys()),
    "additionalProperties": False,
}
PLAN_SCHEMA = {
    "type": "object",
    "properties": {
        "summary_en": {"type": "string"},
        "summary_ar": {"type": "string"},
        "goals": {"type": "array", "items": GOAL_SCHEMA},
    },
    "required": ["summary_en", "summary_ar", "goals"],
    "additionalProperties": False,
}



def format_excerpts(entries: List[GuidelineEntry]) -> str:
    blocks = []
    for e in entries:
        extra = f"\nCONTRAINDICATIONS: {e.contraindications}" if e.contraindications else ""
        blocks.append(
            f"[{e.id}] {e.title}\nSOURCE: {e.source}\nSUGGESTED FREQUENCY: {e.frequency_hint}{extra}\n{e.text}"
        )
    return "\n\n".join(blocks)


def profile_summary(p: Profile) -> str:
    return json.dumps(
        {
            "age": p.age,
            "sex": p.sex,
            "weight_kg": p.weight_kg,
            "height_cm": p.height_cm,
            "bmi": p.bmi,
            "current_medications": p.medications,
            "physical_limitations": p.limitations,
            "activity_level": p.activity_level,
            "diet_habits": p.diet_habits,
            "diagnosed": p.diagnosed,
            "usual_bp": f"{p.usual_systolic}/{p.usual_diastolic}" if p.usual_systolic else "unknown",
            "other_conditions": p.conditions,
            "family_history_heart_disease_or_stroke": p.family_history,
            "wants_to_work_on_first": p.priorities,
            "preferred_language": p.language,
        },
        ensure_ascii=False,
    )


PLAN_SYSTEM = f"""You are a lifestyle-coaching assistant inside "Khutwa", an app that helps adults in
Saudi Arabia with high blood pressure and/or diabetes turn their doctor's advice to "change your
lifestyle" into small daily, weekly and monthly actions. The excerpts summarise only two documents:
the 2017 ACC/AHA High Blood Pressure Guideline and the ADA Standards of Care in Diabetes—2026.

{GROUNDING_RULES}
{LANGUAGE_RULES}
PLAN SHAPE:
- 4 to 6 DAILY goals, 2 to 4 WEEKLY goals, 1 to 3 MONTHLY goals.
- Cover the most impactful areas the excerpts support for this patient: safety first (e.g. low blood
  sugar precautions, foot checks), salt, eating pattern and drinks, activity (adapted to limitations),
  medicine routine (only if they take medicines), home monitoring, weight (only if excerpts are given).
- Make goals small and achievable for this specific person; start easy for low activity levels.
  The plan will be stepped up later as they succeed, so level 1 should feel easy.
- Put what the patient said they want to work on first (`wants_to_work_on_first`).
- `time_of_day`: when the app should remind them (e.g. medicine/BP check "morning", cooking goals
  "afternoon", walking "evening"); "anytime" for weekly/monthly goals.
- `summary_*`: 2–3 short sentences, addressed to the patient, describing their lifestyle plan and
  how it fits their history (no new medical facts).
"""


def plan_user_message(p: Profile, entries: List[GuidelineEntry], cautions: List[str]) -> str:
    caution_text = "\n".join(f"- {c}" for c in cautions) or "- none"
    return (
        f"PATIENT PROFILE:\n{profile_summary(p)}\n\nPATIENT CAUTIONS:\n{caution_text}\n\n"
        f"GUIDELINE EXCERPTS:\n{format_excerpts(entries)}\n\n"
        "Create the personalised plan now."
    )


ADAPT_SYSTEM = f"""You adjust ONE goal in the lifestyle plan of a patient with high blood pressure and/or diabetes.
- If the patient kept missing it, make it easier or better suited to the reason they gave.
- If the reason is LEVEL UP (they succeeded consistently), make it one small step more challenging,
  never beyond the targets stated in the excerpts and never ignoring the PATIENT CAUTIONS.
Either way it must still serve the same guideline recommendation. Keep the same frequency and
time_of_day unless the reason clearly requires otherwise.

{GROUNDING_RULES}
{LANGUAGE_RULES}
Return exactly one goal.
"""

REASON_TEXT = {
    "too_hard": "It is too hard for me",
    "no_time": "I don't have time",
    "pain": "It causes pain or discomfort",
    "forgot": "I keep forgetting",
    "dont_like": "I don't like it",
    "not_relevant": "It doesn't fit my life/culture",
    "level_up": "LEVEL UP: they did this goal on most days for the last week and are ready for the next step",
}


def adapt_user_message(p: Profile, goal_json: str, reason: str, entries: List[GuidelineEntry], cautions: List[str]) -> str:
    caution_text = "\n".join(f"- {c}" for c in cautions) or "- none"
    return (
        f"PATIENT PROFILE:\n{profile_summary(p)}\n\nPATIENT CAUTIONS:\n{caution_text}\n\n"
        f"CURRENT GOAL (missed several days in a row):\n{goal_json}\n\n"
        f"PATIENT'S REASON: {REASON_TEXT.get(reason, reason)}\n\n"
        f"GUIDELINE EXCERPTS:\n{format_excerpts(entries)}\n\nReturn the adjusted goal."
    )

