"""Generate docs/INTAKE_QUESTIONS.md from the intake registry and rules.

Run from backend/:  .venv/bin/python -m app.intake.export_doc
"""
from .. import config
from ..diseases.rules import SRC
from .registry import QUESTIONS, SECTIONS

HEADER = """# Khutwa: what we ask, why, and what it decides

> Generated from `backend/app/intake/registry.py` and `backend/app/diseases/rules.py` (the same code the
> app runs). Regenerate with `cd backend && .venv/bin/python -m app.intake.export_doc`.

## The two reference documents (the only sources)

| Code | Document |
|---|---|
| **ACC/AHA 2017** | Whelton PK, Carey RM, et al. *2017 ACC/AHA/AAPA/ABC/ACPM/AGS/APhA/ASH/ASPC/NMA/PCNA Guideline for the Prevention, Detection, Evaluation, and Management of High Blood Pressure in Adults.* J Am Coll Cardiol 2018;71:e127–e248. |
| **ADA 2026** | American Diabetes Association Professional Practice Committee. *Standards of Care in Diabetes—2026.* Diabetes Care 2026;49(Suppl. 1):S1–S371. |

Section, recommendation (e.g. "rec 5.25") and table numbers were checked against the PDFs provided by
the team. Wording in the app is our own (the ADA license forbids reproducing its text or using it for
machine learning without permission; neither PDF is in this repository).

## How decisions are made

1. The patient answers the questions below (only the ones relevant to their condition are shown).
2. **Fixed, tested rules (R1–R22)** turn the answers into what is allowed, what is not, and what comes first.
   Rules are code, not AI, and are covered by unit tests in `backend/tests/`.
3. The AI (Claude, when switched on) only words the goals in plain Arabic/English, using guideline summaries
   that the rules allowed for this patient. Any goal not citing an allowed entry is dropped by code.

## How reliable is this?

| Part | Trust | Why / limits |
|---|---|---|
| Thresholds & safety (BP ≥ 180/120, glucose < 70 / < 54, pregnancy, potassium) | **High** | Directly from numbered recommendations/tables; unit-tested at the exact boundaries. |
| Lifestyle targets (sodium, DASH, 150 min/week, 5–7% weight, water instead of sugary drinks…) | **High** | Directly from ACC/AHA Table 15 and ADA Section 5 recommendations (grades A/B mostly). |
| The questions | **Moderate** | Each asks about something the guidelines say to assess, but our short, elder-friendly wording is **not a validated questionnaire**. Answers are self-reported. |
| Combining two guidelines into one rule set | **Moderate** | Each rule is sourced, but the combination is ours and has **not been clinically validated**. Where they differ we use the stricter goal (e.g. sodium < 1500 mg/day ACC/AHA vs < 2300 ADA). |
| Team choices (marked *Team-authored*) | **Low until reviewed** | Saudi food examples, meal ideas, reminder times, the 160/100 activity cut-off. Need clinician / dietitian review. |

**Before real patients:** a clinician should review rules R1–R22 against the two PDFs; pilot the Arabic
questions with 10–15 older Saudi patients; obtain ADA permission for any non-educational use.

## Decision rules
"""

RULES = [
    ("R1", "BMI ≥ 25 → weight goal: ≥ 1 kg (hypertension) or 5–7% (diabetes)."),
    ("R2", "Salt at table / in cooking / salty foods 'often' → matching salt goals."),
    ("R3", "< 5 servings of vegetables & fruit a day → vegetables goal (DASH / ADA pattern)."),
    ("R4", "Warning symptoms or BP ≥ 160/100 → light movement only + ask doctor; otherwise goals sized from weekly minutes."),
    ("R5", "BP ≥ 180/120 → emergency alert (safety engine)."),
    ("R6", "Upper-arm monitor → daily home BP; none/wrist → ask about a validated arm device."),
    ("R7", "Missed BP doses → medicine routine first; stopped → refer to doctor."),
    ("R8", "ACE inhibitor/ARB/K-sparing diuretic or kidney disease → no potassium goal."),
    ("R9", "Heart disease / stroke → gentle activity; ask doctor."),
    ("R10", "Pregnant → no plan; see doctor."),
    ("R11", "Tobacco/vape use → smoke-free goal."),
    ("R12", "Short sleep (diabetes) → sleep routine goal; apnoea signs → ask doctor."),
    ("R13", "The patient's chosen priorities come first."),
    ("R14", "Age ≥ 65 / falls / joint pain → seated or chair-supported activity, balance practice, protein."),
    ("R15", "Insulin/sulfonylurea or recent lows → carry glucose, check around exercise; glucose < 70 / < 54 safety alerts."),
    ("R16", "Sugary drinks/juice → water-instead goal."),
    ("R17", "White bread/rice most meals → whole-grain / high-fibre goal."),
    ("R18", "Eye disease → no vigorous/heavy exercise; numb feet/ulcer → daily foot check, proper shoes."),
    ("R19", "Glucose meter/CGM → daily glucose log goal."),
    ("R20", "Plans to fast Ramadan → plan with care team well before."),
    ("R21", "Feeling down/overwhelmed (diabetes) → tell your care team."),
    ("R22", "Long sitting (diabetes) → move every 30 minutes."),
]


def _show_if(q) -> str:
    c = q.get("show_if")
    if not c:
        return ""
    text = str(c)
    if "'disease'" in text and "'diabetes'" in text and "hypertension" not in text:
        return " *(diabetes only)*"
    if "'disease'" in text and "hypertension" in text and "'diabetes'" not in text:
        return " *(hypertension only)*"
    return " *(asked only when relevant)*"


def build() -> str:
    lines = [HEADER, "| Rule | Decision | Source |", "|---|---|---|"]
    for rid, text in RULES:
        lines.append(f"| {rid} | {text} | {SRC.get(rid, '')} |")
    lines += ["", "## The questions", ""]
    current = None
    for n, q in enumerate(QUESTIONS, 1):
        if q["section"] != current:
            current = q["section"]
            lines += [f"### {SECTIONS[current]['en']} · {SECTIONS[current]['ar']}", ""]
        lines.append(f"**Q{n}. {q['en']}**{_show_if(q)}  ")
        lines.append(f"{q['ar']}  ")
        if q.get("options"):
            lines.append(f"*Answers:* {' / '.join(o['en'] for o in q['options'])}  ")
        lines.append(f"*Source:* {q['source']}  ")
        lines.append(f"*Decides:* {q['drives']}")
        lines.append("")
    return "\n".join(lines)


def main() -> None:
    out = config.PROJECT_DIR / "docs" / "INTAKE_QUESTIONS.md"
    out.parent.mkdir(exist_ok=True)
    out.write_text(build(), encoding="utf-8")
    print(f"Wrote {out} ({len(QUESTIONS)} questions)")


if __name__ == "__main__":
    main()
