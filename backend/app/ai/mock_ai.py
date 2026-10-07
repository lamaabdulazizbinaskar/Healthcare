"""Offline "mock AI": deterministic, template-based goals so the app runs with no API key.

Still grounded: a template is only used when its guideline entry (ACC/AHA 2017 or ADA 2026)
was retrieved and allowed for the patient, and the goal carries that entry as its source.
"""
from typing import Dict, List, Optional

from ..diseases.rules import activity_level as effective_activity_level
from ..diseases.rules import fall_risk, hypo_risk, joint_problem
from ..models import Profile


def _t(freq, cat, ten, tar, wen, war):
    return {"frequency": freq, "category": cat, "title_en": ten, "title_ar": tar, "why_en": wen, "why_ar": war}


TEMPLATES: Dict[str, List[dict]] = {
    # ---------------------------------------------------------------- hypertension (ACC/AHA 2017)
    "HTN-SODIUM-03": [_t("daily", "diet", "No salt shaker at the table today", "لا مملحة على السفرة اليوم",
                         "Less salt lowers blood pressure (about 5–6 points).", "تقليل الملح يخفض الضغط (حوالي 5–6 درجات).")],
    "HTN-SODIUM-04": [_t("daily", "diet", "Use half a stock cube (or none) when cooking", "استخدم نصف مكعب مرق أو لا شيء عند الطبخ",
                         "Stock cubes are a big hidden source of salt.", "مكعبات المرق مصدر كبير للملح المخفي.")],
    "HTN-SODIUM-01": [_t("weekly", "diet", "Cook 3 meals this week with less salt than usual", "اطبخ 3 وجبات هذا الأسبوع بملح أقل من المعتاد",
                         "Cutting salt by even a little lowers blood pressure.", "تقليل الملح ولو قليلًا يخفض ضغط الدم.")],
    "HTN-DASH-01": [_t("weekly", "diet", "Fill half your plate with vegetables 4 days this week", "املأ نصف طبقك بالخضار 4 أيام هذا الأسبوع",
                       "The DASH way of eating lowers blood pressure by about 11 points.", "نظام داش الغذائي يخفض الضغط بحوالي 11 درجة.")],
    "HTN-DASH-02": [_t("daily", "diet", "Eat vegetables with lunch and dinner", "تناول خضارًا مع الغداء والعشاء",
                       "Vegetables and fruit are the heart of the DASH diet.", "الخضار والفواكه أساس نظام داش.")],
    "HTN-DASH-03": [_t("weekly", "diet", "Swap white bread or rice for whole grain 3 times", "استبدل الخبز أو الأرز الأبيض بالحبوب الكاملة 3 مرات",
                       "Whole grains are part of the DASH pattern.", "الحبوب الكاملة جزء من نظام داش.")],
    "HTN-POTASSIUM-01": [_t("daily", "diet", "Eat one potassium-rich food (banana, tomato, yogurt)", "تناول طعامًا غنيًا بالبوتاسيوم (موز، طماطم، زبادي)",
                            "Potassium from food helps lower blood pressure.", "البوتاسيوم من الطعام يساعد على خفض الضغط.")],
    "HTN-ACTIVITY-01": [_t("daily", "activity", "Walk briskly for 20 minutes", "امشِ بخطى سريعة لمدة 20 دقيقة",
                           "Regular aerobic activity lowers blood pressure by 5–8 points.", "النشاط الهوائي المنتظم يخفض الضغط 5–8 درجات.")],
    "HTN-ACTIVITY-03": [_t("daily", "activity", "Do 10 minutes of seated exercises", "مارس تمارين وأنت جالس لمدة 10 دقائق",
                           "Moving every day, even seated, helps your heart and blood pressure.", "الحركة يوميًا، ولو جالسًا، تفيد قلبك وضغطك.")],
    "HTN-ACTIVITY-05": [_t("weekly", "activity", "Handgrip squeezes, 3 sessions this week (seated)", "تمرين ضغط الكرة باليد، 3 جلسات هذا الأسبوع (جالسًا)",
                           "4 × 2-minute squeezes, 3 times a week, can lower BP by about 5 points.", "4 مرات ضغط لمدة دقيقتين، 3 مرات أسبوعيًا، قد تخفض الضغط حوالي 5 درجات.")],
    "HTN-ACTIVITY-06": [_t("weekly", "activity", "Strength exercises on 2 days this week", "تمارين قوة في يومين هذا الأسبوع",
                           "Strength training lowers blood pressure by about 4 points.", "تمارين القوة تخفض الضغط حوالي 4 درجات.")],
    "HTN-WEIGHT-02": [_t("weekly", "weight", "Weigh yourself on Friday morning", "قِس وزنك صباح يوم الجمعة",
                         "Tracking weight helps you reach a healthier weight.", "متابعة الوزن تساعدك على الوصول لوزن صحي.")],
    "HTN-WEIGHT-01": [_t("monthly", "weight", "Aim to lose 1 kg this month", "استهدف إنقاص 1 كجم هذا الشهر",
                         "Each kilogram lost lowers blood pressure by about 1 point.", "كل كيلوجرام تفقده يخفض الضغط حوالي درجة واحدة.")],
    "HTN-CAFFEINE-01": [_t("daily", "monitoring", "No qahwa or tea 30 minutes before measuring", "لا قهوة ولا شاي قبل القياس بنصف ساعة",
                           "Caffeine raises blood pressure for a short time.", "الكافيين يرفع الضغط لفترة قصيرة.")],
    "HTN-TOBACCO-01": [_t("daily", "lifestyle", "A smoke-free day (no cigarettes, shisha or vape)", "يوم بلا تدخين (لا سجائر ولا شيشة ولا فيب)",
                          "Smoking raises heart and stroke risk with high blood pressure.", "التدخين يزيد خطر القلب والجلطة مع الضغط.")],
    "HTN-HBPM-02": [_t("daily", "monitoring", "Measure your BP in the morning, seated and rested", "قِس ضغطك صباحًا وأنت جالس ومرتاح",
                       "Home readings show your doctor how treatment is working.", "قراءات البيت توضح لطبيبك مدى فعالية العلاج.")],
    "HTN-HBPM-01": [_t("weekly", "monitoring", "Ask your doctor or pharmacist which upper-arm BP monitor to use", "اسأل طبيبك أو الصيدلي عن جهاز ضغط للذراع مناسب",
                       "A validated upper-arm monitor gives reliable home readings.", "جهاز الذراع المعتمد يعطي قراءات منزلية موثوقة.")],
    "HTN-HBPM-03": [_t("monthly", "monitoring", "Show this month's report to your doctor", "اعرض تقرير هذا الشهر على طبيبك",
                       "Your readings help your doctor adjust treatment.", "قراءاتك تساعد طبيبك على ضبط العلاج.")],
    "HTN-MEDS-01": [_t("daily", "medication", "Take your BP medicine at the same time each day (e.g. with breakfast)",
                       "خذ دواء الضغط في نفس الوقت يوميًا (مثلًا مع الفطور)",
                       "Medicines only work when taken every day; a fixed habit helps you remember.",
                       "الدواء لا يعمل إلا إذا أُخذ كل يوم؛ والعادة الثابتة تساعدك على التذكر.")],
    "HTN-MEDS-03": [_t("monthly", "medication", "Count your tablets and arrange a refill", "عدّ حبوبك ورتّب لإعادة صرف الدواء",
                       "Running out is a common reason for missed doses.", "نفاد الدواء سبب شائع لنسيان الجرعات.")],
    # ---------------------------------------------------------------- diabetes (ADA 2026)
    "DM-NUTR-01": [_t("daily", "diet", "Add legumes or vegetables to lunch (lentils, beans, salad)", "أضف بقوليات أو خضارًا إلى الغداء (عدس، فول، سلطة)",
                      "Vegetables, legumes and whole foods help blood sugar and the heart.", "الخضار والبقوليات والأطعمة الكاملة تفيد السكر والقلب.")],
    "DM-NUTR-02": [_t("daily", "diet", "Choose whole-grain bread or brown rice instead of white", "اختر الخبز الأسمر أو الأرز البني بدل الأبيض",
                      "High-fibre carbohydrates raise blood sugar more slowly.", "الكربوهيدرات الغنية بالألياف ترفع السكر ببطء أكثر.")],
    "DM-NUTR-03": [_t("daily", "diet", "Drink water instead of juice or soft drinks today", "اشرب الماء بدل العصير أو المشروبات الغازية اليوم",
                      "Sugary drinks, even juice, raise blood sugar quickly.", "المشروبات السكرية، حتى العصير، ترفع السكر بسرعة.")],
    "DM-NUTR-04": [_t("weekly", "diet", "Swap 3 processed foods for fresh ones this week", "استبدل 3 أطعمة مصنّعة بأخرى طازجة هذا الأسبوع",
                      "Less processed food means less salt.", "أطعمة مصنّعة أقل تعني ملحًا أقل.")],
    "DM-NUTR-05": [_t("weekly", "diet", "Have a legume or nut-based meal 3 times this week", "تناول وجبة من البقوليات أو المكسرات 3 مرات هذا الأسبوع",
                      "Plant protein lowers heart risk.", "البروتين النباتي يقلل خطر أمراض القلب.")],
    "DM-NUTR-06": [_t("weekly", "diet", "Eat fish twice this week", "تناول السمك مرتين هذا الأسبوع",
                      "Fatty fish (Mediterranean style) protects the heart and helps glucose.", "السمك الدهني (النمط المتوسطي) يحمي القلب ويساعد السكر.")],
    "DM-NUTR-07": [_t("weekly", "diet", "Cook with olive oil instead of ghee or butter 3 times", "اطبخ بزيت الزيتون بدل السمن أو الزبدة 3 مرات",
                      "Less saturated fat lowers heart risk.", "دهون مشبعة أقل تعني خطرًا أقل على القلب.")],
    "DM-NUTR-08": [_t("daily", "diet", "Eat your meals at your usual times with similar carbohydrate", "تناول وجباتك في أوقاتها المعتادة بكمية نشويات متقاربة",
                      "With fixed insulin doses, steady meals prevent lows and highs.", "مع جرعات أنسولين ثابتة، انتظام الوجبات يمنع الانخفاض والارتفاع.")],
    "DM-WEIGHT-01": [_t("monthly", "weight", "Aim to lose 1–2 kg this month (towards 5–7%)", "استهدف إنقاص 1–2 كجم هذا الشهر (نحو 5–7٪)",
                        "Losing 5–7% of body weight improves blood sugar.", "إنقاص 5–7٪ من الوزن يحسّن السكر.")],
    "DM-OLD-01": [_t("daily", "diet", "Include protein in each meal (eggs, laban, fish, beans)", "أضف بروتينًا لكل وجبة (بيض، لبن، سمك، فول)",
                     "Enough protein keeps your muscles strong as you age.", "البروتين الكافي يحافظ على قوة عضلاتك مع التقدم في العمر.")],
    "DM-ACT-01": [_t("daily", "activity", "Walk or move for 20 minutes today", "امشِ أو تحرك 20 دقيقة اليوم",
                     "150 minutes a week of activity improves blood sugar.", "150 دقيقة نشاط أسبوعيًا تحسّن السكر.")],
    "DM-ACT-02": [_t("weekly", "activity", "Strength exercises on 2 non-consecutive days", "تمارين قوة في يومين غير متتاليين",
                     "Muscle work helps your body use sugar better.", "تمارين العضلات تساعد جسمك على استخدام السكر بشكل أفضل.")],
    "DM-ACT-03": [_t("daily", "activity", "Stand up and move every 30 minutes while sitting", "قم وتحرك كل 30 دقيقة أثناء الجلوس",
                     "Breaking up sitting helps blood sugar.", "كسر الجلوس الطويل يساعد على ضبط السكر.")],
    "DM-ACT-04": [_t("weekly", "activity", "Balance and stretching practice 3 times this week", "تمارين توازن وإطالة 3 مرات هذا الأسبوع",
                     "Balance training lowers the risk of falls.", "تمارين التوازن تقلل خطر السقوط.")],
    "DM-ACT-05": [_t("daily", "activity", "Light movement only: walk around the house a few times", "حركة خفيفة فقط: امشِ داخل البيت عدة مرات",
                     "Start gently and ask your doctor before harder exercise.", "ابدأ بلطف واسأل طبيبك قبل التمارين الأصعب.")],
    "DM-ACT-06": [_t("daily", "selfcare", "Carry glucose tablets or a sweet drink when you go out or exercise", "احمل أقراص جلوكوز أو مشروبًا محلّى عند الخروج أو التمرين",
                     "Insulin or sulfonylureas can cause low sugar during activity.", "الأنسولين أو أدوية السلفونيل يوريا قد تسبب انخفاض السكر أثناء النشاط.")],
    "DM-ACT-07": [_t("monthly", "activity", "Ask your eye doctor which exercise is safe for you", "اسأل طبيب العيون عن التمارين الآمنة لك",
                     "With diabetic eye disease, hard exercise may be unsafe.", "مع اعتلال الشبكية، قد تكون التمارين الشديدة غير آمنة.")],
    "DM-ACT-08": [_t("weekly", "selfcare", "Wear proper closed shoes for walking every time", "البس حذاءً مغلقًا مناسبًا للمشي في كل مرة",
                     "Numb feet can get hurt without you feeling it.", "القدم المخدّرة قد تُجرح دون أن تشعر.")],
    "DM-GLU-03": [_t("daily", "monitoring", "Check your blood sugar as your doctor advised and log it", "قِس السكر كما نصحك طبيبك وسجّله",
                     "Your log helps you and your doctor see what works.", "سجلك يساعدك وطبيبك على معرفة ما ينفع.")],
    "DM-GLU-01": [_t("monthly", "monitoring", "Know your A1C result and your personal goal", "اعرف نتيجة التراكمي وهدفك الشخصي",
                     "Many adults aim for A1C under 7%, but your goal may differ.", "كثير من البالغين هدفهم تراكمي أقل من 7٪، وقد يختلف هدفك.")],
    "DM-FOOT-01": [_t("daily", "selfcare", "Check both feet tonight (use a mirror for the soles)", "افحص قدميك الليلة (استخدم مرآة لباطن القدم)",
                      "Daily checks catch small foot problems early.", "الفحص اليومي يكشف مشاكل القدم الصغيرة مبكرًا.")],
    "DM-SMOKE-01": [_t("daily", "lifestyle", "A smoke-free day (no cigarettes, shisha or vape)", "يوم بلا تدخين (لا سجائر ولا شيشة ولا فيب)",
                       "Smoking raises the risk of diabetes complications.", "التدخين يزيد خطر مضاعفات السكري.")],
    "DM-SLEEP-01": [_t("daily", "lifestyle", "Go to bed at the same time; no screens 30 minutes before", "نَم في نفس الوقت؛ بلا شاشات قبل النوم بنصف ساعة",
                       "Good sleep routines help blood sugar and mood.", "روتين النوم الجيد يساعد السكر والمزاج.")],
    "DM-FAST-01": [_t("monthly", "medication", "Book a visit to plan fasting before Ramadan", "احجز موعدًا لتخطيط الصيام قبل رمضان",
                      "Medicines and timing may need changing before fasting.", "قد تحتاج الأدوية ومواعيدها إلى تعديل قبل الصيام.")],
    "DM-BP-01": [_t("daily", "monitoring", "Measure your blood pressure at home today", "قِس ضغطك في البيت اليوم",
                    "With diabetes, the usual BP goal is under 130/80.", "مع السكري، هدف الضغط عادةً أقل من 130/80.")],
}

_CAPS = {"daily": 6, "weekly": 4, "monthly": 3}

# When the app should ask about each daily goal.
_TIMES = {
    "HTN-HBPM-02": "morning", "HTN-MEDS-01": "morning", "HTN-MEDS-02": "morning", "HTN-CAFFEINE-01": "morning",
    "DM-BP-01": "morning", "DM-GLU-03": "morning", "DM-ACT-06": "morning",
    "HTN-SODIUM-03": "afternoon", "HTN-SODIUM-04": "afternoon", "HTN-DASH-02": "afternoon", "HTN-POTASSIUM-01": "afternoon",
    "DM-NUTR-01": "afternoon", "DM-NUTR-02": "afternoon", "DM-NUTR-03": "afternoon", "DM-NUTR-08": "afternoon",
    "DM-OLD-01": "afternoon", "DM-ACT-03": "afternoon", "DM-ACT-05": "afternoon",
    "HTN-ACTIVITY-01": "evening", "HTN-ACTIVITY-03": "evening", "DM-ACT-01": "evening", "DM-FOOT-01": "evening",
    "DM-SLEEP-01": "evening",
}


def plan_summary(p: Profile) -> dict:
    """Short bilingual overview of the lifestyle plan (offline mode)."""
    en, ar = [], []
    if p.has_hypertension:
        en.append("less salt")
        ar.append("ملح أقل")
    if p.has_diabetes:
        en.append("healthier carbohydrates and water instead of sugary drinks")
        ar.append("نشويات صحية أكثر والماء بدل المشروبات السكرية")
    en.append("daily movement")
    ar.append("حركة يومية")
    if p.medications or p.diabetes_meds:
        en.append("a steady medicine routine")
        ar.append("روتين ثابت للدواء")
    if p.bmi >= 25:
        en.append("a little weight loss")
        ar.append("إنقاص بسيط للوزن")
    joined_en = ", ".join(en[:-1]) + " and " + en[-1]
    joined_ar = "، ".join(ar[:-1]) + " و" + ar[-1]
    return {
        "summary_en": f"Your plan focuses on {joined_en}. We start with small steps that fit your health history and step them up as you succeed.",
        "summary_ar": f"تركّز خطتك على {joined_ar}. نبدأ بخطوات صغيرة تناسب تاريخك الصحي ونرفعها كلما نجحت.",
    }


def _tailor(entry_id: str, goal: dict, p: Profile) -> dict:
    if entry_id == "HTN-ACTIVITY-03" and (fall_risk(p) or joint_problem(p)):
        goal["tailoring_en"] = "Seated so it is safe for your joints and balance."
        goal["tailoring_ar"] = "وأنت جالس حتى يكون آمنًا لمفاصلك وتوازنك."
    if entry_id == "HTN-SODIUM-04" and p.salt_cooking in ("always", "often"):
        goal["tailoring_en"] = "You told us salt or stock cubes go into most of your cooking."
        goal["tailoring_ar"] = "ذكرت أن الملح أو مكعبات المرق تُضاف لمعظم طبخك."
    if entry_id == "DM-NUTR-03" and p.sugary_drinks in ("always", "often"):
        goal["tailoring_en"] = "You said you often have sugary drinks or juice."
        goal["tailoring_ar"] = "ذكرت أنك تشرب المشروبات السكرية أو العصير كثيرًا."
    if entry_id == "DM-ACT-01" and hypo_risk(p):
        goal["tailoring_en"] = "Check your sugar before and after, and carry quick glucose."
        goal["tailoring_ar"] = "قِس السكر قبل وبعد، واحمل جلوكوزًا سريعًا."
    if entry_id == "DM-GLU-03" and p.has_hypertension and p.home_monitor not in ("none", "wrist"):
        # One morning check for both conditions (ADA rec 6.1 / Section 7 + ACC/AHA Table 10).
        goal["title_en"] = "Check your blood sugar and blood pressure this morning and log them"
        goal["title_ar"] = "قِس السكر والضغط صباح اليوم وسجّلهما"
        goal["why_en"] = "Your readings show you and your doctor what is working."
        goal["why_ar"] = "قراءاتك توضح لك ولطبيبك ما ينفع."
        goal["source_ids"] = ["DM-GLU-03", "HTN-HBPM-02"]
    level = effective_activity_level(p)
    if entry_id in ("HTN-ACTIVITY-01", "DM-ACT-01") and level in ("very_low", "low"):
        goal["title_en"] = "Walk or move for 10 minutes today"
        goal["title_ar"] = "امشِ أو تحرك 10 دقائق اليوم"
        goal["tailoring_en"] = goal.get("tailoring_en") or "Starting small because you are not very active yet."
        goal["tailoring_ar"] = goal.get("tailoring_ar") or "نبدأ بخطوة صغيرة لأن نشاطك الحالي قليل."
    elif entry_id in ("HTN-ACTIVITY-01", "DM-ACT-01") and level == "high":
        goal["title_en"] = "Keep up 30 minutes of brisk walking today"
        goal["title_ar"] = "حافظ على 30 دقيقة من المشي السريع اليوم"
    return goal


def _priority(entry_id: str, p: Profile, index: int) -> int:
    """Lower = chosen first. Safety goals, then goals the patient's own answers point to, then the rest."""
    from ..diseases import rules as R

    safety = {
        "DM-ACT-06": R.hypo_risk(p), "DM-ACT-05": True, "DM-FOOT-01": R.foot_risk(p),
        "DM-ACT-07": True, "DM-ACT-08": True,
    }
    if safety.get(entry_id):
        return 0
    if entry_id == "HTN-MEDS-01" and p.missed_doses in ("some", "many"):
        return 1
    # Tier 1: food/drink and monitoring goals the patient's own answers point to.
    tier1 = {
        "HTN-SODIUM-04": R.salty_cooking_or_foods(p), "HTN-SODIUM-03": p.salt_table in ("always", "often"),
        "DM-NUTR-03": R.sugary(p), "DM-NUTR-02": R.refined(p), "HTN-TOBACCO-01": R.smokes(p),
        "DM-SMOKE-01": R.smokes(p), "HTN-HBPM-02": True, "DM-GLU-03": True, "HTN-MEDS-01": True,
    }
    if tier1.get(entry_id):
        return 10 + index
    # Tier 2: other answer-driven habits.
    tier2 = {"DM-ACT-03": p.sitting_hours == "gt8", "DM-SLEEP-01": R.short_or_poor_sleep(p), "DM-FAST-01": p.fasting == "yes"}
    if tier2.get(entry_id):
        return 50 + index
    return 100 + index


def generate_plan(p: Profile, entry_ids: List[str], cautions: List[str]) -> List[dict]:
    """Return raw goal dicts (same shape as the Claude schema) for the retrieved, allowed entries."""
    entry_ids = sorted(entry_ids, key=lambda e: _priority(e, p, entry_ids.index(e)))
    # 1) Coverage: the best goal of each core area. 2) Then fill by priority (max 3 per area).
    from ..diseases.rules import smokes

    core = {"diet", "activity", "monitoring", "medication", "selfcare"} | ({"lifestyle"} if smokes(p) else set())
    candidates = [(e, tpl) for e in entry_ids for tpl in TEMPLATES.get(e, [])]
    first_pass, seen_cat = [], set()
    for e, tpl in candidates:
        key = (tpl["frequency"], tpl["category"])
        if tpl["category"] in core and key not in seen_cat:
            seen_cat.add(key)
            first_pass.append((e, tpl))
    ordered = first_pass + [c for c in candidates if c not in first_pass]
    counts = {"daily": 0, "weekly": 0, "monthly": 0}
    per_cat: Dict[tuple, int] = {}
    goals = []
    for entry_id, tpl in ordered:
        for tpl in [tpl]:
            freq = tpl["frequency"]
            cap = _CAPS[freq] + (1 if p.disease == "both" and freq == "daily" else 0)
            key = (freq, tpl["category"])
            if counts[freq] >= cap or per_cat.get(key, 0) >= 3:
                continue
            goal = dict(tpl, tailoring_en="", tailoring_ar="", source_ids=[entry_id],
                        time_of_day=_TIMES.get(entry_id, "anytime") if freq == "daily" else "anytime")
            goals.append(_tailor(entry_id, goal, p))
            counts[freq] += 1
            per_cat[key] = per_cat.get(key, 0) + 1
    return goals


_ADAPT = {
    "activity": {
        "too_hard": ("Do 5 minutes of seated marching", "حرّك قدميك وأنت جالس لمدة 5 دقائق",
                     "A smaller step you can do every day.", "خطوة أصغر تستطيع فعلها كل يوم."),
        "no_time": ("Move for 5 minutes after one prayer", "تحرك 5 دقائق بعد إحدى الصلوات",
                    "Short sessions spread through the day still count.", "الجلسات القصيرة الموزعة خلال اليوم تُحتسب."),
        "pain": ("Gentle seated arm and ankle movements, 5 minutes", "حركات خفيفة للذراعين والكاحلين وأنت جالس، 5 دقائق",
                 "Gentle seated movement keeps you active without straining painful joints.", "الحركة الخفيفة جالسًا تبقيك نشيطًا دون إجهاد المفاصل."),
        "forgot": ("Do your exercise right after Asr prayer", "مارس تمرينك بعد صلاة العصر مباشرة",
                   "Linking exercise to a daily habit makes it easier to remember.", "ربط التمرين بعادة يومية يسهّل تذكره."),
        "dont_like": ("Squeeze a soft ball while watching TV", "اضغط كرة لينة أثناء مشاهدة التلفاز",
                      "Handgrip exercise is another way to help.", "تمرين قبضة اليد طريقة أخرى للمساعدة."),
    },
    "diet": {
        "too_hard": ("Make one small food swap today", "قم بتبديل غذائي صغير واحد اليوم",
                     "Small changes add up.", "التغييرات الصغيرة تتراكم."),
        "no_time": ("Choose one ready healthy option today (laban, fruit, salad)", "اختر خيارًا صحيًا جاهزًا اليوم (لبن، فاكهة، سلطة)",
                    "A quick, simple swap still helps.", "تبديل سريع وبسيط يفيد أيضًا."),
        "forgot": ("Put a water bottle and fruit where you can see them", "ضع قارورة ماء وفاكهة حيث تراها",
                   "Seeing healthy choices makes them easier.", "رؤية الخيارات الصحية تسهّلها."),
        "dont_like": ("Flavour one dish with lemon, garlic or spices", "أضف نكهة لطبق واحد بالليمون أو الثوم أو البهارات",
                      "Herbs and spices give taste without salt or sugar.", "الأعشاب والبهارات تعطي طعمًا دون ملح أو سكر."),
    },
    "medication": {
        "forgot": ("Keep your pills next to your breakfast plate + phone alarm", "ضع حبوبك بجانب طبق الفطور مع منبّه بالجوال",
                   "A visible place and an alarm help you never miss a dose.", "المكان الظاهر والمنبّه يساعدانك على عدم النسيان."),
        "*": ("Fill a weekly pill organizer every Friday", "املأ علبة الدواء الأسبوعية كل جمعة",
              "A pill organizer makes the routine simple.", "علبة الدواء الأسبوعية تجعل الروتين بسيطًا."),
    },
    "monitoring": {
        "forgot": ("Measure right after waking, before breakfast", "قِس بعد الاستيقاظ مباشرة وقبل الفطور",
                   "The same time every day makes it a habit.", "القياس في نفس الوقت يجعله عادة."),
        "*": ("Measure once in the morning", "قِس مرة واحدة صباحًا",
              "One good reading a day is still very useful.", "قراءة واحدة جيدة يوميًا مفيدة جدًا."),
    },
    "selfcare": {
        "*": ("Check your feet after your evening wudu", "افحص قدميك بعد وضوء المغرب أو العشاء",
              "Linking it to wudu makes the daily check easy.", "ربطه بالوضوء يجعل الفحص اليومي سهلًا."),
    },
    "weight": {
        "*": ("Weigh yourself once this week", "قِس وزنك مرة واحدة هذا الأسبوع",
              "Seeing your weight regularly helps you notice progress.", "متابعة وزنك تساعدك على ملاحظة التقدم."),
    },
    "lifestyle": {
        "*": ("Keep the morning smoke-free", "اجعل فترة الصباح بلا تدخين",
              "Every smoke-free hour helps. Ask your doctor about quitting support.", "كل ساعة بلا تدخين تفيد. اسأل طبيبك عن برامج الإقلاع."),
    },
}

_LEVEL_UP = {
    "activity": ("Move for 20 minutes, in two short sessions", "تحرك 20 دقيقة على فترتين قصيرتين",
                 "You're ready for a little more activity.", "أنت جاهز لنشاط أكثر قليلًا."),
    "diet": ("Make two meals today following your plan", "اجعل وجبتين اليوم حسب خطتك",
             "Your habits are getting stronger; one more step.", "عاداتك تقوى؛ خطوة إضافية."),
    "medication": ("Take medicines on time and check your weekly pill box", "خذ أدويتك في وقتها وراجع علبة الدواء الأسبوعية",
                   "You're doing great with your medicines.", "أنت ملتزم بأدويتك."),
    "monitoring": ("Measure morning and evening (2 readings each)", "قِس صباحًا ومساءً (قراءتان كل مرة)",
                   "Two readings morning and evening give the clearest picture.", "قراءتان صباحًا ومساءً تعطيان أوضح صورة."),
    "selfcare": ("Check your feet and moisturise (not between toes)", "افحص قدميك وضع مرطّبًا (ليس بين الأصابع)",
                 "Good daily foot care prevents problems.", "العناية اليومية بالقدم تمنع المشاكل."),
    "weight": ("Weigh yourself every Friday and note it", "قِس وزنك كل جمعة وسجّله",
               "Regular tracking helps you keep going.", "المتابعة المنتظمة تساعدك على الاستمرار."),
    "lifestyle": ("A full smoke-free day", "يوم كامل بلا تدخين",
                  "Every smoke-free day helps your heart.", "كل يوم بلا تدخين يفيد قلبك."),
}


def adapt_goal(goal: dict, reason: str) -> Optional[dict]:
    if reason == "level_up":
        pick = _LEVEL_UP.get(goal["category"])
        tail_en, tail_ar = "Stepped up because you did so well last week.", "رفعناه لأنك أبدعت الأسبوع الماضي."
    else:
        options = _ADAPT.get(goal["category"], {})
        pick = options.get(reason) or options.get("*") or options.get("too_hard")
        tail_en, tail_ar = ("Adjusted after you told us why the old goal was hard.",
                            "عدّلناه بعد أن أخبرتنا لماذا كان الهدف السابق صعبًا.")
    if pick is None:
        return None
    ten, tar, wen, war = pick
    return dict(
        frequency=goal["frequency"], category=goal["category"],
        title_en=ten, title_ar=tar, why_en=wen, why_ar=war,
        tailoring_en=tail_en, tailoring_ar=tail_ar,
        time_of_day=goal.get("time_of_day", "anytime"),
        source_ids=[s["id"] for s in goal.get("sources", [])],
    )
