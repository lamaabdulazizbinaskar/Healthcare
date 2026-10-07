"""Rule-based red-flag safety layer. Deliberately NOT AI: deterministic, auditable, testable.

The Flutter app mirrors these thresholds in app/lib/safety/red_flags.dart so the alert
also fires offline. Keep both in sync (tests in backend/tests/test_red_flags.py).
"""
from typing import Iterable, List, Optional

from ..models import SafetyResult

CRISIS_SYSTOLIC = 180  # >= triggers emergency alert
CRISIS_DIASTOLIC = 120
STAGE2_SYSTOLIC = 140  # >= is "elevated" (advise contacting the care team, not emergency)
STAGE2_DIASTOLIC = 90

WARNING_SYMPTOMS = {
    "chest_pain": ("chest pain", "ألم في الصدر"),
    "severe_headache": ("severe headache", "صداع شديد"),
    "shortness_of_breath": ("shortness of breath", "ضيق في التنفس"),
    "vision_changes": ("vision changes", "تغيّر في النظر"),
    "weakness_numbness": ("weakness or numbness", "ضعف أو تنميل"),
    "confusion_speech": ("confusion or difficulty speaking", "تشوّش أو صعوبة في الكلام"),
}

_EMERGENCY_EN = (
    "Seek emergency care now. Call 997 or go to the nearest emergency department. "
    "Do not drive yourself. Do not take extra blood pressure medicine unless your doctor told you to."
)
_EMERGENCY_AR = (
    "اطلب الرعاية الطارئة الآن. اتصل على 997 أو توجّه إلى أقرب قسم طوارئ. "
    "لا تقد السيارة بنفسك. لا تأخذ جرعة إضافية من دواء الضغط إلا إذا أخبرك طبيبك بذلك."
)


def evaluate(
    systolic: Optional[int] = None,
    diastolic: Optional[int] = None,
    symptoms: Iterable[str] = (),
) -> SafetyResult:
    reasons: List[str] = []
    symptoms = [s for s in symptoms if s in WARNING_SYMPTOMS]
    crisis = (systolic is not None and systolic >= CRISIS_SYSTOLIC) or (
        diastolic is not None and diastolic >= CRISIS_DIASTOLIC
    )
    if crisis:
        reasons.append(f"bp_crisis:{systolic}/{diastolic}")
    reasons.extend(f"symptom:{s}" for s in symptoms)

    if crisis or symptoms:
        if crisis and symptoms:
            title_en, title_ar = "Very high blood pressure with warning signs", "ضغط مرتفع جدًا مع علامات خطر"
        elif crisis:
            title_en, title_ar = "Your blood pressure is dangerously high", "ضغط دمك مرتفع بشكل خطير"
        else:
            names_en = ", ".join(WARNING_SYMPTOMS[s][0] for s in symptoms)
            names_ar = "، ".join(WARNING_SYMPTOMS[s][1] for s in symptoms)
            title_en, title_ar = f"Warning sign: {names_en}", f"علامة خطر: {names_ar}"
        return SafetyResult(
            level="emergency",
            reasons=reasons,
            title_en=title_en,
            title_ar=title_ar,
            message_en=_EMERGENCY_EN,
            message_ar=_EMERGENCY_AR,
        )

    elevated = (systolic is not None and systolic >= STAGE2_SYSTOLIC) or (
        diastolic is not None and diastolic >= STAGE2_DIASTOLIC
    )
    if elevated:
        return SafetyResult(
            level="elevated",
            reasons=[f"bp_elevated:{systolic}/{diastolic}"],
            title_en="This reading is above target",
            title_ar="هذه القراءة أعلى من المستهدف",
            message_en=(
                "Rest for 5 minutes and measure again. If your readings stay this high for "
                "several days, contact your doctor or clinic."
            ),
            message_ar=(
                "استرح 5 دقائق ثم أعد القياس. إذا بقيت قراءاتك بهذا الارتفاع لعدة أيام، "
                "تواصل مع طبيبك أو العيادة."
            ),
        )
    return SafetyResult(level="ok")


# ---------------------------------------------------------------- blood glucose (ADA 2026)
# ADA Standards of Care 2026, Table 6.4 / text S139: level 1 hypoglycemia < 70 mg/dL,
# level 2 < 54 mg/dL (needs immediate action); rec 6.15: treat with glucose, recheck after 15 min.
HYPO_LEVEL1 = 70
HYPO_LEVEL2 = 54
GLUCOSE_SEVERE_SYMPTOMS = {"confused", "cant_swallow", "fainted"}


def evaluate_glucose(value: int, symptoms: Iterable[str] = ()) -> SafetyResult:
    symptoms = [s for s in symptoms if s in GLUCOSE_SEVERE_SYMPTOMS]
    if symptoms or value < HYPO_LEVEL2:
        emergency = bool(symptoms)
        return SafetyResult(
            level="emergency" if emergency else "urgent",
            reasons=[f"glucose:{value}"] + [f"symptom:{s}" for s in symptoms],
            title_en="Very low blood sugar: act now" if not emergency else "Severe low blood sugar: get help now",
            title_ar="انخفاض شديد في السكر: تصرّف الآن" if not emergency else "انخفاض حاد في السكر: اطلب المساعدة الآن",
            message_en=(
                "Take glucose now (glucose tablets, or juice or regular soft drink), not chocolate or fatty food. "
                "Check again in 15 minutes and repeat if still low. If the person is confused, can't swallow or has "
                "fainted, call 997 and do not give food or drink by mouth."
            ),
            message_ar=(
                "تناول الجلوكوز الآن (أقراص جلوكوز، أو عصير، أو مشروب غازي عادي)، وليس الشوكولاتة أو الطعام الدسم. "
                "قِس مرة أخرى بعد 15 دقيقة وكرّر إذا بقي منخفضًا. إذا كان الشخص مشوشًا أو لا يستطيع البلع أو فقد الوعي، "
                "اتصل على 997 ولا تعطه طعامًا أو شرابًا بالفم."
            ),
        )
    if value < HYPO_LEVEL1:
        return SafetyResult(
            level="low",
            reasons=[f"glucose:{value}"],
            title_en="Low blood sugar", title_ar="انخفاض في السكر",
            message_en="Take glucose (tablets or a sugary drink), check again in 15 minutes and repeat if still under 70. Tell your doctor about low sugars.",
            message_ar="تناول الجلوكوز (أقراص أو مشروب سكري)، وقِس مرة أخرى بعد 15 دقيقة وكرّر إذا بقي أقل من 70. أخبر طبيبك عن انخفاضات السكر.",
        )
    return SafetyResult(level="ok")
