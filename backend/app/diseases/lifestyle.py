"""Lifestyle module for hypertension, type 2/1 diabetes, or both.

One class handles all three cases so a patient with both conditions gets one consistent plan.
Decisions come from app/diseases/rules.py (R1–R22); sources: ACC/AHA 2017 and ADA 2026 only.
"""
from typing import Dict, List, Optional

from ..models import Profile
from ..rag.knowledge_loader import GuidelineEntry
from . import rules as R
from .base import DiseaseModule

_PRIORITY_QUERIES = {
    "salt": ["reduce sodium salt intake diet", "practical ways cut salt cooking processed"],
    "food": ["healthy eating pattern vegetables legumes whole grains", "DASH diet vegetables fruit whole grains"],
    "sugar": ["water instead of sugary drinks juice", "high fibre carbohydrate whole grains"],
    "activity": ["150 minutes activity week", "aerobic activity walking exercise minutes per week"],
    "weight": ["weight loss overweight"],
    "medicines": ["take blood pressure medication adherence"],
    "smoking": ["smoking tobacco vape"],
    "sleep": ["sleep routine night"],
    "glucose": ["glucose goals monitoring", "check glucose meter"],
}


class LifestyleModule(DiseaseModule):
    def __init__(self, disease_id: str, folders: List[str], name: Dict[str, str]):
        self.id = disease_id
        self.folders = folders
        self.name = name

    # ---------------------------------------------------------------- helpers
    def _htn(self) -> bool:
        return "hypertension" in self.folders

    def _dm(self) -> bool:
        return "diabetes" in self.folders

    def excluded(self, p: Profile) -> Optional[Dict[str, str]]:
        return R.excluded(p)

    # ---------------------------------------------------------------- retrieval
    def retrieval_queries(self, p: Profile) -> List[str]:
        q: List[str] = []
        if self._htn() and p.medications and p.missed_doses in ("some", "many"):
            q.append("take blood pressure medication adherence")  # R7 first
        if self._dm() and R.hypo_risk(p):
            q.append("low blood sugar hypoglycemia treatment")  # R15 safety knowledge early
        for pr in p.priorities:  # R13
            q.extend(_PRIORITY_QUERIES.get(pr, []))
        # Food (R2, R3, R16, R17)
        if self._dm():
            q.append("healthy eating pattern vegetables legumes whole grains")
            if R.sugary(p):
                q.append("water instead of sugary drinks juice")
            if R.refined(p):
                q.append("high fibre carbohydrate whole grains")
        if self._htn():
            q += ["reduce sodium salt intake diet", "practical ways cut salt cooking processed"]
            if R.salty_cooking_or_foods(p):
                q.append("saudi salty foods kabsa stock cube cheese")
            q.append("DASH diet vegetables fruit whole grains")
        elif R.salty(p):
            q.append("limit sodium processed food")
        # Monitoring (R6, R19)
        if self._htn():
            q += ["home blood pressure monitoring measurement technique", "keep readings share doctor"]
        if self._dm():
            q.append("check glucose meter monitoring")
            if self._htn():
                q.append("blood pressure home diabetes goal")
        # Activity (R4, R9, R14, R15, R18, R22)
        if R.activity_restricted(p) or set(p.conditions) & {"heart_disease", "stroke"}:
            q.append("check safety before harder exercise doctor")
        if self._dm():
            q.append("break up sitting every 30 minutes")
            if not R.activity_restricted(p):
                q += ["150 minutes activity week", "strength exercise resistance"]
            if p.age >= 65 or R.fall_risk(p):
                q.append("balance flexibility older adults")
            if R.hypo_risk(p):
                q.append("low blood sugar during exercise insulin")
            if R.retinopathy(p):
                q.append("eye disease retinopathy exercise")
            if R.foot_risk(p):
                q += ["check feet every day", "numb feet exercise footwear"]
            elif self._dm():
                q.append("check feet every day")
        if self._htn() and not R.activity_restricted(p):
            if R.fall_risk(p) or R.joint_problem(p) or p.age >= 75:
                q.append("adapting activity pain mobility seated")
            q.append("isometric handgrip seated exercise")
            if not self._dm():
                q.append("aerobic activity walking exercise minutes per week")
        # Medicines (R7)
        if self._htn() and p.medications:
            q += ["take blood pressure medication adherence", "habits remember medicines", "refill medicines"]
        # Weight (R1)
        if p.bmi >= 25:
            q.append("weight loss overweight")
        # Tobacco (R11), sleep (R12), fasting (R20), mood (R21)
        if R.smokes(p):
            q.append("smoking tobacco vape")
        if self._dm() and R.short_or_poor_sleep(p):
            q.append("sleep routine night")
        if self._dm() and p.fasting in ("yes", "unsure"):
            q.append("ramadan fasting planning")
        if self._dm() and p.age >= 65:
            q.append("protein older adults")
        if self._htn():
            q.append("potassium food")
        if "drinks_alcohol" in p.diet_habits:
            q.append("alcohol limit")
        if set(p.diet_habits) & {"arabic_coffee", "lots_of_coffee"}:
            q.append("caffeine before measuring")
        return q

    # ---------------------------------------------------------------- hard filters
    def is_applicable(self, entry: GuidelineEntry, p: Profile) -> bool:
        e = entry.id
        restricted = R.activity_restricted(p)
        # Safety knowledge / advice used by Ask Khutwa and the food guide, never checklist goals.
        never_goals = {"HTN-WARN-01", "HTN-SLEEP-02", "HTN-MEDS-02", "DM-GLU-02", "DM-PSY-01", "DM-NUTR-09",
                       "DM-NUTR-10", "DM-DSMES-01", "DM-BP-01"}
        if e in never_goals:
            return False  # safety knowledge / advice, shown elsewhere, never a checklist goal
        if e in ("HTN-WEIGHT-01", "HTN-WEIGHT-02", "DM-WEIGHT-01") and p.bmi < 25:  # R1
            return False
        if e in ("HTN-WEIGHT-01", "HTN-WEIGHT-02") and self._dm():
            return False  # one weight goal (ADA 5–7%) when both conditions
        if e == "HTN-SODIUM-04" and not R.salty_cooking_or_foods(p):  # R2
            return False
        if e == "HTN-SODIUM-03" and p.salt_table in ("rarely", "never") and p.salt_cooking in ("rarely", "never"):
            return False
        if e == "DM-NUTR-04" and self._htn():
            return False  # the stricter ACC/AHA sodium goal applies instead
        if e == "HTN-DASH-02" and not R.low_veg(p):  # R3
            return False
        if e == "DM-NUTR-03" and p.sugary_drinks in ("rarely", "never"):  # R16
            return False
        if e == "DM-NUTR-02" and p.refined_grains in ("rarely", "never"):  # R17
            return False
        if e == "DM-NUTR-08" and "insulin" not in p.diabetes_meds:
            return False
        # Activity (R4, R9, R14, R18)
        hard = {"HTN-ACTIVITY-01", "HTN-ACTIVITY-05", "HTN-ACTIVITY-06", "DM-ACT-01", "DM-ACT-02"}
        if restricted and (e in hard or e in ("HTN-ACTIVITY-03", "DM-ACT-04")):
            return False
        if e == "DM-ACT-05" and not (restricted or set(p.conditions) & {"heart_disease", "stroke"}):
            return False
        if (R.fall_risk(p) or R.joint_problem(p)) and e in ("HTN-ACTIVITY-01", "HTN-ACTIVITY-06"):
            return False
        if set(p.conditions) & {"heart_disease", "stroke"} and e in ("HTN-ACTIVITY-05", "HTN-ACTIVITY-06", "DM-ACT-02"):
            return False
        if R.retinopathy(p) and e in ("HTN-ACTIVITY-06",):
            return False
        if e == "HTN-ACTIVITY-03" and not (R.fall_risk(p) or R.joint_problem(p) or p.age >= 75 or R.activity_level(p) == "very_low"):
            return False
        if e == "HTN-ACTIVITY-01" and self._dm():
            return False  # DM-ACT-01 (150 min/week) covers aerobic activity
        if e == "DM-ACT-06" and not R.hypo_risk(p):
            return False
        if e == "DM-ACT-07" and not R.retinopathy(p):
            return False
        if e == "DM-ACT-08" and not R.foot_risk(p):
            return False
        if e == "DM-ACT-04" and not (p.age >= 65 or R.fall_risk(p)):
            return False
        # Monitoring (R6, R19)
        if e == "HTN-HBPM-02" and p.home_monitor in ("none", "wrist"):
            return False
        if e == "HTN-HBPM-01" and p.home_monitor not in ("none", "wrist"):
            return False
        if e == "DM-BP-01" and not self._htn():
            return False
        if e == "DM-GLU-03" and p.glucose_monitor == "none":
            return False
        # Medicines (R7), potassium (R8)
        if e.startswith("HTN-MEDS") and (not p.medications or p.missed_doses == "stopped"):
            return False
        if e == "HTN-POTASSIUM-01" and (R.k_raising(p) or "kidney_disease" in p.conditions):
            return False
        # Tobacco (R11), sleep (R12), fasting (R20), older adults
        if e in ("HTN-TOBACCO-01", "DM-SMOKE-01") and not R.smokes(p):
            return False
        if e == "DM-SMOKE-01" and self._htn():
            return False  # one smoking goal
        if e == "DM-SLEEP-01" and not R.short_or_poor_sleep(p):
            return False
        if e == "DM-FAST-01" and p.fasting not in ("yes", "unsure"):
            return False
        if e == "DM-OLD-01" and p.age < 65:
            return False
        if e in ("HTN-ALCOHOL-01", "DM-ALCOHOL-01") and "drinks_alcohol" not in p.diet_habits:
            return False
        if e == "HTN-CAFFEINE-01" and not set(p.diet_habits) & {"arabic_coffee", "lots_of_coffee"}:
            return False
        return True

    def patient_cautions(self, p: Profile) -> List[str]:
        return R.cautions(p)

    # ---------------------------------------------------------------- explanations
    def insights(self, p: Profile) -> List[Dict[str, str]]:
        out: List[Dict[str, str]] = []

        def add(rule: str, icon: str, en: str, ar: str) -> None:
            out.append({"rule": rule, "icon": icon, "text_en": en, "text_ar": ar, "source": R.SRC.get(rule, "")})

        if R.activity_restricted(p):
            add("R4", "stop", "Your answers (warning symptoms or BP 160/100+): light movement only for now. Please check with your doctor before more exercise.",
                "إجاباتك (أعراض تحذيرية أو ضغط 160/100 أو أكثر): حركة خفيفة فقط الآن. اسأل طبيبك قبل زيادة التمارين.")
        if R.hypo_risk(p):
            add("R15", "bp", "Your diabetes medicines or recent low sugars: we added safety steps for low blood sugar, especially around exercise.",
                "أدوية السكري أو انخفاضات السكر الأخيرة: أضفنا خطوات أمان لانخفاض السكر، خاصة حول التمارين.")
        if p.low_sugar == "severe":
            add("R15", "stop", "You had a severe low sugar. Please tell your doctor; your treatment may need review.",
                "حدث لك انخفاض شديد في السكر. أخبر طبيبك؛ قد يحتاج علاجك إلى مراجعة.")
        if p.missed_doses == "stopped":
            add("R7", "pill", "You stopped your BP medicines. Please talk to your doctor first; we did not add medicine goals.",
                "توقفت عن أدوية الضغط. تحدث مع طبيبك أولًا؛ لم نضف أهدافًا للدواء.")
        elif p.missed_doses in ("some", "many"):
            add("R7", "pill", "You missed some doses this week: your medicine routine is your first daily goal.",
                "نسيت بعض الجرعات هذا الأسبوع: روتين الدواء هو أول أهدافك اليومية.")
        if R.retinopathy(p):
            add("R18", "stop", "Diabetic eye disease: no vigorous or heavy-lifting exercise; check with your eye doctor first.",
                "اعتلال الشبكية السكري: لا تمارين عنيفة أو رفع أثقال؛ استشر طبيب العيون أولًا.")
        if R.foot_risk(p):
            add("R18", "chair", "Numb feet or past foot ulcer: daily foot checks and low-impact activity.",
                "تنميل القدمين أو قرحة سابقة: فحص يومي للقدمين ونشاط خفيف التأثير.")
        if p.priorities:
            add("R13", "flag", "Your plan starts with what you chose to work on.", "تبدأ خطتك بما اخترت أن تعمل عليه.")
        if R.fall_risk(p) or R.joint_problem(p):
            add("R14", "chair", "Falls, balance or joint pain: activity is seated or chair-supported, with balance practice.",
                "السقوط أو التوازن أو ألم المفاصل: النشاط وأنت جالس أو مستند إلى كرسي مع تمارين توازن.")
        mins = R.weekly_minutes(p)
        if mins is not None and not R.activity_restricted(p):
            target = 150 if self._dm() else 90
            if mins < target:
                add("R4", "steps", f"You're active about {mins} minutes a week (goal: {target}+). We start a little above where you are.",
                    f"تتحرك حوالي {mins} دقيقة أسبوعيًا (الهدف: {target} أو أكثر). نبدأ بخطوة أعلى قليلًا مما أنت عليه.")
        if self._dm() and p.sitting_hours == "gt8":
            add("R22", "steps", "You sit more than 8 hours a day: a goal to break up sitting every 30 minutes is included.",
                "تجلس أكثر من 8 ساعات يوميًا: أضفنا هدفًا لكسر الجلوس كل 30 دقيقة.")
        if R.sugary(p) and self._dm():
            add("R16", "salt", "Sugary drinks or juice: we added a 'water instead' goal.", "مشروبات سكرية أو عصير: أضفنا هدف 'الماء بدلًا منها'.")
        if R.refined(p) and self._dm():
            add("R17", "salt", "White bread or rice at most meals: we added a whole-grain / high-fibre goal.",
                "خبز أو أرز أبيض في معظم الوجبات: أضفنا هدفًا للحبوب الكاملة والألياف.")
        if self._htn() and R.salty(p):
            add("R2", "salt", "Your answers show salt from the table, cooking or salty foods: salt goals come first.",
                "إجاباتك تُظهر ملحًا من السفرة أو الطبخ أو الأطعمة المالحة: أهداف الملح أولًا.")
        if R.low_veg(p) and p.fruit_veg != "unknown":
            add("R3", "salt", "Fewer than 5 servings of vegetables and fruit a day: a vegetables goal is included.",
                "أقل من 5 حصص خضار وفواكه يوميًا: أضفنا هدفًا للخضار.")
        if p.bmi >= 25:
            pct = "5–7%" if self._dm() else "at least 1 kg"
            pct_ar = "5–7٪" if self._dm() else "1 كجم على الأقل"
            add("R1", "weight", f"BMI {p.bmi}: a steady weight goal ({pct}) is included.", f"مؤشر كتلة الجسم {p.bmi}: أضفنا هدفًا تدريجيًا للوزن ({pct_ar}).")
        if self._htn() and (R.k_raising(p) or "kidney_disease" in p.conditions):
            add("R8", "pill", "Your medicines or kidneys: no potassium goal without asking your doctor.",
                "أدويتك أو كليتاك: لا هدف لزيادة البوتاسيوم دون سؤال طبيبك.")
        if self._htn() and p.home_monitor in ("none", "wrist"):
            add("R6", "bp", "No upper-arm monitor at home: ask your doctor or pharmacist which validated arm monitor to use.",
                "لا يوجد جهاز ذراع في البيت: اسأل طبيبك أو الصيدلي عن جهاز ذراع معتمد.")
        elif self._htn() and p.usual_systolic and (p.usual_systolic >= 130 or (p.usual_diastolic or 0) >= 80):
            add("R6", "bp", f"Your usual BP ({p.usual_systolic}/{p.usual_diastolic}) is above the 130/80 goal: daily home readings.",
                f"ضغطك المعتاد ({p.usual_systolic}/{p.usual_diastolic}) أعلى من الهدف 130/80: قياس يومي في البيت.")
        if R.smokes(p):
            add("R11", "smoke", "You smoke or vape: a smoke-free goal is part of your plan.", "أنت تدخن: هدف الامتناع عن التدخين ضمن خطتك.")
        if self._dm() and p.fasting in ("yes", "unsure"):
            add("R20", "flag", "You may fast in Ramadan: plan it with your care team well before.", "قد تصوم رمضان: خطط لذلك مع فريقك الطبي مبكرًا.")
        if R.possible_sleep_apnoea(p):
            add("R12", "bp", "Your sleep answers can be signs of sleep apnoea. Please ask your doctor (not a diagnosis).",
                "إجاباتك عن النوم قد تكون علامات انقطاع النفس أثناء النوم. اسأل طبيبك (هذا ليس تشخيصًا).")
        if self._dm() and p.mood in ("sometimes", "often"):
            add("R21", "heart", "Feeling down or overwhelmed is common with diabetes. Please tell your care team; they can help.",
                "الشعور بالإحباط أو الإرهاق شائع مع السكري. أخبر فريقك الطبي؛ يمكنهم مساعدتك.")
        if set(p.conditions) & {"heart_disease", "stroke"}:
            add("R9", "heart", "Heart disease or previous stroke: activity stays gentle; check with your doctor.",
                "مرض القلب أو جلطة سابقة: النشاط يبقى خفيفًا؛ استشر طبيبك.")
        return out
