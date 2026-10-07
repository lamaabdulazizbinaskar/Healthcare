"""'What to eat': meal suggestions for hypertension and/or diabetes.

The meals are TEAM-AUTHORED Saudi examples (need dietitian review). Each one is tagged with the
guideline entries whose principles it applies (ACC/AHA 2017 DASH & sodium; ADA 2026 nutrition recs),
and rules pick meals that fit the patient's conditions and answers. No AI is needed, so it is
fast, offline and always grounded; Ask LifeStep (AI) answers follow-up food questions.
"""
import random
from datetime import date
from typing import Dict, List, Optional

from ..diseases import rules as R
from ..models import Profile
from ..rag.retriever import get_entry


def _m(mid, slot, en, ar, why_en, why_ar, sources, tags=()):
    return {"id": mid, "slot": slot, "name_en": en, "name_ar": ar, "why_en": why_en, "why_ar": why_ar,
            "source_ids": list(sources), "tags": list(tags)}


MEALS: List[Dict] = [
    # ------------------------------------------------------------ breakfast
    _m("b-foul", "breakfast", "Foul (fava beans) with olive oil, tomato and cucumber + ½ brown bread",
       "فول مع زيت الزيتون والطماطم والخيار + نصف رغيف أسمر",
       "Beans give plant protein and fibre; cook without added salt.", "الفول يعطي بروتينًا نباتيًا وأليافًا؛ اطبخه دون ملح مضاف.",
       ["DM-NUTR-05", "DM-NUTR-01", "HTN-DASH-01"], ["legumes", "fibre", "low_salt"]),
    _m("b-eggs", "breakfast", "2 boiled eggs, cucumber and tomato, small brown bread, plain laban",
       "بيضتان مسلوقتان، خيار وطماطم، خبز أسمر صغير، لبن",
       "Protein keeps you full; vegetables and low-fat dairy fit DASH.", "البروتين يشبعك؛ والخضار والألبان قليلة الدسم تناسب داش.",
       ["HTN-DASH-01", "DM-NUTR-01", "DM-OLD-01"], ["protein", "vegetables"]),
    _m("b-oats", "breakfast", "Oats cooked with low-fat milk, topped with walnuts (no sugar)",
       "شوفان مطبوخ بحليب قليل الدسم مع جوز (بدون سكر)",
       "Whole grains and nuts: high fibre, slow sugar rise.", "حبوب كاملة ومكسرات: ألياف عالية وارتفاع سكر بطيء.",
       ["DM-NUTR-02", "DM-NUTR-05", "HTN-DASH-03"], ["whole_grain", "fibre", "no_added_sugar"]),
    _m("b-yogurt", "breakfast", "Plain low-fat yogurt with seeds and a small apple",
       "زبادي قليل الدسم مع بذور وتفاحة صغيرة",
       "Low-fat dairy, seeds and whole fruit instead of juice.", "ألبان قليلة الدسم وبذور وفاكهة كاملة بدل العصير.",
       ["HTN-DASH-03", "DM-NUTR-05", "DM-NUTR-03"], ["dairy", "no_added_sugar"]),
    # ------------------------------------------------------------ lunch
    _m("l-kabsa", "lunch", "Lighter chicken kabsa: small portion of brown rice, half the plate salad, spices instead of stock cube",
       "كبسة دجاج أخف: كمية صغيرة من الأرز البني، نصف الطبق سلطة، بهارات بدل مكعب المرق",
       "Keeps your favourite dish with less salt and slower carbohydrate.", "تحافظ على طبقك المفضل مع ملح أقل ونشويات أبطأ.",
       ["HTN-SODIUM-04", "DM-NUTR-02", "HTN-DASH-02"], ["low_salt", "whole_grain", "vegetables"]),
    _m("l-fish", "lunch", "Grilled fish with lemon and olive oil, salad and a small portion of brown rice",
       "سمك مشوي بالليمون وزيت الزيتون مع سلطة وكمية صغيرة من الأرز البني",
       "Fish twice a week protects the heart (Mediterranean style).", "السمك مرتين أسبوعيًا يحمي القلب (النمط المتوسطي).",
       ["DM-NUTR-06", "HTN-DASH-01", "DM-NUTR-07"], ["fish", "vegetables"]),
    _m("l-lentil", "lunch", "Lentil soup (no stock cube) with fattoush (baked, not fried bread)",
       "شوربة عدس (بدون مكعب مرق) مع فتوش (خبز محمّص غير مقلي)",
       "Lentils are plant protein and fibre; homemade soup has far less salt.", "العدس بروتين نباتي وألياف؛ والشوربة المنزلية فيها ملح أقل بكثير.",
       ["DM-NUTR-05", "HTN-SODIUM-03", "DM-NUTR-01"], ["legumes", "low_salt", "fibre"]),
    _m("l-jareesh", "lunch", "Jareesh (cracked whole wheat) with chicken and vegetables, light on salt",
       "جريش مع دجاج وخضار، بملح خفيف",
       "Whole-grain wheat gives fibre for steadier blood sugar.", "القمح الكامل يعطي أليافًا لسكر أكثر استقرارًا.",
       ["DM-NUTR-02", "HTN-DASH-03", "HTN-SODIUM-01"], ["whole_grain", "fibre"]),
    # ------------------------------------------------------------ dinner
    _m("d-chicken", "dinner", "Grilled chicken with sautéed vegetables and a small brown bread",
       "دجاج مشوي مع خضار سوتيه وخبز أسمر صغير",
       "Lean protein and vegetables; light on carbohydrate in the evening.", "بروتين قليل الدهن وخضار؛ نشويات خفيفة في المساء.",
       ["DM-NUTR-01", "HTN-DASH-01"], ["protein", "vegetables"]),
    _m("d-shakshuka", "dinner", "Shakshuka (eggs with tomato and peppers) with brown bread",
       "شكشوكة (بيض مع طماطم وفلفل) مع خبز أسمر",
       "Vegetables and protein; use spices instead of extra salt.", "خضار وبروتين؛ استخدم البهارات بدل الملح الزائد.",
       ["HTN-DASH-02", "DM-NUTR-01", "HTN-SODIUM-03"], ["vegetables", "protein"]),
    _m("d-balela", "dinner", "Chickpea salad (balela) with olive oil and lemon",
       "سلطة حمص (بليلة) بزيت الزيتون والليمون",
       "Legumes and olive oil: good for blood sugar and the heart.", "البقوليات وزيت الزيتون: مفيدة للسكر والقلب.",
       ["DM-NUTR-05", "DM-NUTR-06", "HTN-DASH-01"], ["legumes", "fibre"]),
    _m("d-soup", "dinner", "Homemade vegetable soup with hummus and vegetable sticks",
       "شوربة خضار منزلية مع حمص وأصابع خضار",
       "Light, high-fibre and low in salt when homemade.", "خفيفة وغنية بالألياف وقليلة الملح عند تحضيرها في البيت.",
       ["HTN-DASH-02", "DM-NUTR-01", "HTN-SODIUM-03"], ["vegetables", "low_salt"]),
    # ------------------------------------------------------------ snacks
    _m("s-nuts", "snack", "A small handful of unsalted nuts", "حفنة صغيرة من المكسرات غير المملحة",
       "Plant protein and healthy fats; unsalted keeps sodium low.", "بروتين نباتي ودهون صحية؛ وغير المملحة تبقي الملح منخفضًا.",
       ["DM-NUTR-05", "HTN-SODIUM-04"], ["nuts", "low_salt"]),
    _m("s-fruit", "snack", "One whole fruit (orange or apple), not juice", "حبة فاكهة كاملة (برتقال أو تفاح)، وليس عصيرًا",
       "Whole fruit has fibre; juice raises sugar quickly.", "الفاكهة الكاملة فيها ألياف؛ والعصير يرفع السكر بسرعة.",
       ["DM-NUTR-03", "HTN-DASH-02"], ["fruit", "no_added_sugar"]),
    _m("s-veg", "snack", "Cucumber and carrot sticks with hummus", "أصابع خيار وجزر مع حمص",
       "Crunchy vegetables with legumes, no added sugar.", "خضار مقرمشة مع بقوليات، بلا سكر مضاف.",
       ["HTN-DASH-02", "DM-NUTR-05"], ["vegetables", "legumes"]),
    _m("s-laban", "snack", "A glass of plain laban (unsweetened)", "كوب لبن (غير محلّى)",
       "Low-fat dairy is part of DASH; choose unsweetened.", "الألبان قليلة الدسم جزء من داش؛ اختر غير المحلّى.",
       ["HTN-DASH-03", "DM-NUTR-03"], ["dairy", "no_added_sugar"]),
    _m("s-banana", "snack", "A banana", "موزة",
       "Potassium-rich fruit helps blood pressure.", "فاكهة غنية بالبوتاسيوم تساعد على خفض الضغط.",
       ["HTN-POTASSIUM-01", "HTN-DASH-02"], ["fruit", "potassium"]),
]

DRINKS = {
    "en": ["Water is the best drink", "Qahwa or tea without sugar", "No juice or soft drinks"],
    "ar": ["الماء أفضل مشروب", "قهوة أو شاي بدون سكر", "لا عصير ولا مشروبات غازية"],
    "source_ids": ["DM-NUTR-03", "HTN-CAFFEINE-01"],
}
LIMIT = {
    "en": ["Stock cubes, pickles, salty cheese", "Fast food and processed meat", "Sweets and sugary drinks",
           "White bread and white rice", "Fatty meat, ghee and butter"],
    "ar": ["مكعبات المرق والمخللات والجبن المالح", "الوجبات السريعة واللحوم المصنّعة", "الحلويات والمشروبات السكرية",
           "الخبز الأبيض والأرز الأبيض", "اللحوم الدسمة والسمن والزبدة"],
    "source_ids": ["DM-NUTR-01", "HTN-SODIUM-04", "DM-NUTR-07"],
}
SLOTS = ["breakfast", "lunch", "dinner", "snack"]


def _allowed(meal: Dict, p: Profile) -> bool:
    if "potassium" in meal["tags"] and (not p.has_hypertension or R.k_raising(p) or "kidney_disease" in p.conditions):
        return False  # ACC/AHA §6.2 rec 4 contraindications; banana is only suggested for its potassium (hypertension)
    return True


def _sources(ids: List[str], p: Profile) -> List[Dict]:
    out = []
    for i in ids:
        if i.startswith("HTN-") and not p.has_hypertension:
            continue
        if i.startswith("DM-") and not p.has_diabetes:
            continue
        e = get_entry(i)
        if e:
            out.append({"id": e.id, "title": e.title, "citation": e.source})
    return out


def suggestions(p: Optional[Profile], day: date) -> Dict:
    """A day's menu: several options per slot (the app shows one and 'Another idea' cycles)."""
    if p is None:
        p = Profile(age=60, weight_kg=80, height_cm=170, disease="both")
    rng = random.Random(f"{p.user_id}-{day.isoformat()}")  # stable for the day, different tomorrow
    slots = []
    for slot in SLOTS:
        options = [m for m in MEALS if m["slot"] == slot and _allowed(m, p)]
        rng.shuffle(options)
        slots.append({
            "slot": slot,
            "options": [dict(m, sources=_sources(m["source_ids"], p)) for m in options],
        })
    notes_en, notes_ar, note_sources = [], [], []
    if p.has_diabetes:
        # ADA 2026 S94: diabetes plate method.
        notes_en.append("Plate method: half vegetables, a quarter protein, a quarter whole grains or legumes.")
        notes_ar.append("طريقة الطبق: نصفه خضار، وربعه بروتين، وربعه حبوب كاملة أو بقوليات.")
        note_sources.append("DM-NUTR-11")
    if R.hypo_risk(p):
        notes_en.append("On insulin or sulfonylureas: don't skip meals, and keep glucose tablets with you.")
        notes_ar.append("مع الأنسولين أو السلفونيل يوريا: لا تترك وجبات، واحمل أقراص الجلوكوز معك.")
        note_sources += ["DM-NUTR-08", "DM-ACT-06"]
    if p.has_hypertension:
        notes_en.append("Cook with spices, lemon and garlic instead of salt and stock cubes.")
        notes_ar.append("اطبخ بالبهارات والليمون والثوم بدل الملح ومكعبات المرق.")
        note_sources.append("HTN-SODIUM-03")
    return {
        "date": day.isoformat(),
        "slots": slots,
        "drinks": {"en": DRINKS["en"], "ar": DRINKS["ar"], "sources": _sources(DRINKS["source_ids"], p)},
        "limit": {"en": LIMIT["en"], "ar": LIMIT["ar"], "sources": _sources(LIMIT["source_ids"], p)},
        "notes": {"en": notes_en, "ar": notes_ar, "sources": _sources(note_sources, p)},
        "authored_note_en": "Meal ideas are written by the LifeStep team to apply the guideline principles shown; a dietitian should review them.",
        "authored_note_ar": "أفكار الوجبات من إعداد فريق خطوة حياة لتطبيق مبادئ الإرشادات الموضحة؛ ويجب أن يراجعها أخصائي تغذية.",
    }
