"""'Ask Khutwa': patient questions answered by Claude, grounded in the guideline knowledge base.

Order of checks (safety first, AI last):
  1. Rule-based emergency detection (warning symptoms in Arabic/English) → safety engine, no AI.
  2. Rule-based medicine-change detection → fixed "ask your doctor" answer, no AI.
  3. Retrieve guideline entries (Arabic words are expanded to English search terms).
  4. Claude answers using ONLY those entries; the code keeps only cited entry IDs that were provided.
"""
import re
from typing import Dict, List, Optional

from .. import config
from ..models import Profile
from ..rag.knowledge_loader import GuidelineEntry
from ..rag.retriever import search as kb_search
from ..safety import red_flags
from . import prompts
from .claude_client import AIError, structured_call

# --- 1. emergency words → symptom ids used by the rule engine
_EMERGENCY = {
    "chest_pain": ["chest pain", "chest tightness", "pain in my chest",
                   "ألم في الصدر", "الم في الصدر", "ألم بالصدر", "الم بالصدر", "صدري يوجعني", "ضيقة في الصدر"],
    "shortness_of_breath": ["can't breathe", "cannot breathe", "short of breath", "shortness of breath", "trouble breathing",
                            "ضيق في التنفس", "ضيق تنفس", "ما اقدر اتنفس", "لا أستطيع التنفس"],
    "severe_headache": ["severe headache", "worst headache", "terrible headache", "صداع شديد", "صداع قوي"],
    "vision_changes": ["blurred vision", "blurry vision", "vision changes", "lost my vision", "can't see",
                       "تشوش في النظر", "زغللة", "لا أرى", "ما اشوف"],
    "weakness_numbness": ["numbness", "face drooping", "arm weakness", "sudden weakness", "can't move my",
                          "تنميل", "خدر", "ضعف مفاجئ", "ارتخاء في الوجه", "شلل"],
    "confusion_speech": ["slurred speech", "can't speak", "trouble speaking", "suddenly confused", "fainted",
                         "passed out", "unconscious", "صعوبة في الكلام", "لخبطة في الكلام", "أغمي", "اغمي",
                         "فقد الوعي", "فاقد الوعي"],
}

# --- 2. questions about changing medicines: never answered by the AI
_MED_CHANGE = [
    "stop my medicine", "stop taking", "skip my", "double", "dose", "increase my medicine", "reduce my medicine",
    "change my medicine", "instead of my medicine",
    "أوقف الدواء", "اوقف الدواء", "أترك الدواء", "اترك الدواء", "الجرعة", "جرعة", "أزيد الدواء", "اقلل الدواء", "أغير الدواء",
    "بدل الدواء", "بدال الدواء",
]

# --- 3. Arabic → English search terms (the knowledge base is written in English)
_AR_TERMS = {
    "ملح": "salt sodium", "مالح": "salt sodium", "كبسة": "kabsa stock cube salt", "مرق": "stock cube salt",
    "جبن": "cheese salt", "مخلل": "pickles salt", "زيتون": "olives salt", "خبز": "bread whole grains",
    "رز": "rice whole grains", "أرز": "rice whole grains", "خضار": "vegetables DASH", "فاكهة": "fruit DASH",
    "فواكه": "fruit DASH", "تمر": "dates potassium", "موز": "banana potassium", "بوتاسيوم": "potassium",
    "مشي": "walking aerobic activity", "أمشي": "walking aerobic activity", "رياضة": "exercise activity",
    "تمارين": "exercise activity", "ركبة": "knee pain seated activity", "جالس": "seated activity",
    "وزن": "weight loss", "سمنة": "weight overweight", "دواء": "medication adherence", "أدوية": "medication adherence",
    "حبوب": "medication pills", "أنسى": "remember medicines reminders", "قياس": "measure blood pressure home monitoring",
    "أقيس": "measure blood pressure home monitoring", "جهاز": "home bp monitor device", "قهوة": "caffeine coffee",
    "شاي": "caffeine tea", "تدخين": "smoking tobacco", "سجائر": "smoking tobacco", "شيشة": "shisha tobacco",
    "نوم": "sleep", "أنام": "sleep", "شخير": "snoring sleep apnoea", "ماء": "water", "صباح": "morning measure",
    "ضغط": "blood pressure",
    "سكر": "glucose sugar", "السكري": "diabetes glucose", "سكري": "diabetes glucose", "أنسولين": "insulin hypoglycemia",
    "انسولين": "insulin hypoglycemia", "هبوط": "low blood sugar hypoglycemia", "انخفاض السكر": "low blood sugar hypoglycemia",
    "عصير": "juice sugary drinks water", "مشروبات": "drinks water juice", "قدم": "feet foot care", "قدمي": "feet foot care",
    "رجلي": "feet foot care", "رمضان": "ramadan fasting", "صيام": "ramadan fasting", "أصوم": "ramadan fasting",
    "قرفة": "cinnamon supplements", "مكملات": "supplements", "فيتامين": "supplements vitamins", "تراكمي": "a1c glucose goals",
    "حلويات": "sweets sugar", "محلي": "sweeteners", "عيوني": "eye retinopathy", "عين": "eye retinopathy",
    "بقوليات": "legumes plant protein", "عدس": "lentils legumes plant protein", "فول": "beans legumes plant protein",
    "سمك": "fish mediterranean", "مكسرات": "nuts seeds plant protein", "جلوس": "sitting break up",
}

_MED_ANSWER = {
    "answer_en": (
        "Please don't stop, skip or change any blood pressure medicine on your own. Only your doctor or "
        "pharmacist can tell you about doses. Write your question down and ask them; your monthly report "
        "can help."
    ),
    "answer_ar": (
        "لا توقف أو تترك أو تغيّر أي دواء للضغط من نفسك. طبيبك أو الصيدلي فقط يستطيع أن يخبرك عن الجرعات. "
        "اكتب سؤالك واسألهم؛ وتقريرك الشهري يمكن أن يساعدك."
    ),
}


def _contains(text: str, phrases: List[str]) -> bool:
    """English phrases match whole words only ("numb" must not match "numbers"); Arabic as substrings."""
    t = text.lower().replace("’", "'")
    for p in phrases:
        p = p.lower()
        if p.isascii():
            if re.search(r"(?<![a-z])" + re.escape(p) + r"(?![a-z])", t):
                return True
        elif p in t:
            return True
    return False


def _search_text(question: str) -> str:
    extra = [en for ar, en in _AR_TERMS.items() if ar in question]
    return " ".join([question] + extra)


def _retrieve(disease: str, question: str, k: int = 5) -> List[GuidelineEntry]:
    hits = [e for e, _ in kb_search(disease, _search_text(question), k=k)]
    return [e for e in hits if e.id not in ("HTN-WARN-01",)]


ASK_SCHEMA = {
    "type": "object",
    "properties": {
        "answer_en": {"type": "string"},
        "answer_ar": {"type": "string"},
        "source_ids": {"type": "array", "items": {"type": "string"}},
        "suggest_doctor": {"type": "boolean"},
        "in_scope": {"type": "boolean"},
    },
    "required": ["answer_en", "answer_ar", "source_ids", "suggest_doctor", "in_scope"],
    "additionalProperties": False,
}

ASK_SYSTEM = f"""You are "Khutwa", a friendly health guide inside an app for adults in Saudi Arabia with high
blood pressure and/or diabetes, many of them elderly. The excerpts summarise only the 2017 ACC/AHA High Blood
Pressure Guideline and the ADA Standards of Care in Diabetes—2026. Answer the patient's question in simple, warm, short language
(2–4 short sentences), in natural English (`answer_en`) and Modern Standard Arabic a Saudi elderly reader
understands (`answer_ar`).

{prompts.GROUNDING_RULES}
More rules for questions:
- Use ONLY the GUIDELINE EXCERPTS. If they don't answer the question, say kindly that you can't answer
  that here and suggest asking their doctor; set in_scope=false and source_ids=[].
- Practical food questions (e.g. kabsa, dates, cheese) may be answered by applying the excerpts
  (e.g. salt or potassium advice), without inventing numbers that are not in them.
- Never diagnose, never interpret symptoms, never discuss medicine doses or changes.
- Set suggest_doctor=true when the patient should involve their doctor.
- You may use the PATIENT CONTEXT to personalise (e.g. seated exercise for knee pain).
"""


def _context(p: Optional[Profile], plan_titles: List[str]) -> str:
    if p is None:
        return "unknown"
    return (
        f"age {p.age}, BMI {p.bmi}, limitations {p.limitations}, conditions {p.conditions}, "
        f"medicines {p.medications}; current plan goals: {plan_titles[:8]}"
    )


def answer(question: str, disease: str, profile: Optional[Profile], plan_titles: List[str]) -> Dict:
    question = question.strip()[:500]

    # 1. Emergency words → rule engine, never the AI.
    symptoms = [sid for sid, words in _EMERGENCY.items() if _contains(question, words)]
    if symptoms:
        return {"type": "emergency", "safety": red_flags.evaluate(symptoms=symptoms).model_dump()}

    # 2. Medicine changes → fixed answer.
    if _contains(question, _MED_CHANGE):
        return {"type": "answer", "mode": "rule", **_MED_ANSWER, "sources": [], "suggest_doctor": True}

    entries = _retrieve(disease, question)
    by_id = {e.id: e for e in entries}

    def sources(ids: List[str]) -> List[Dict]:
        return [{"id": i, "title": by_id[i].title, "citation": by_id[i].source} for i in ids if i in by_id]

    if config.AI_MODE == "claude" and entries:
        try:
            r = structured_call(
                ASK_SYSTEM,
                f"PATIENT CONTEXT: {_context(profile, plan_titles)}\n\nGUIDELINE EXCERPTS:\n"
                f"{prompts.format_excerpts(entries)}\n\nPATIENT QUESTION: {question}",
                ASK_SCHEMA,
                max_tokens=2000,
                effort="low",
            )
            ids = [i for i in r.get("source_ids", []) if i in by_id]  # grounding guard
            return {
                "type": "answer",
                "mode": "claude",
                "answer_en": r["answer_en"],
                "answer_ar": r["answer_ar"],
                "sources": sources(ids),
                "suggest_doctor": bool(r.get("suggest_doctor")) or not r.get("in_scope", True),
            }
        except AIError:
            pass  # fall through to the offline answer

    # Offline / no match: show the closest guideline text itself (no AI).
    if not entries:
        return {
            "type": "answer", "mode": "offline", "sources": [], "suggest_doctor": True,
            "answer_en": "I couldn't find this in the app's guideline information. Please ask your doctor.",
            "answer_ar": "لم أجد هذا في معلومات الإرشادات في التطبيق. يُرجى سؤال طبيبك.",
        }
    top = entries[0]
    first = " ".join(re.split(r"(?<=\.)\s+", top.text)[:2])
    return {
        "type": "answer", "mode": "offline", "sources": sources([top.id]), "suggest_doctor": False,
        "answer_en": f"{top.title}: {first}",
        "answer_ar": f"(الذكاء الاصطناعي غير مفعّل، هذا نص الإرشاد كما هو) {top.title}: {first}",
    }
