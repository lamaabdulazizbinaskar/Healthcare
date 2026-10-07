"""Pydantic data model shared by the API, storage and AI layers.

Typing uses `Optional`/`List` (not `X | None`) so the backend runs on Python 3.9+.
"""
from datetime import datetime
from typing import Dict, List, Optional

from pydantic import BaseModel, Field

Frequency = str  # "daily" | "weekly" | "monthly"


class Profile(BaseModel):
    user_id: str = ""
    name: str = ""
    disease: str = "hypertension"  # "hypertension" | "diabetes" | "both"
    age: int = Field(ge=18, le=120)
    sex: str = "male"  # "male" | "female"
    weight_kg: float = Field(gt=20, lt=350)
    height_cm: float = Field(gt=100, lt=250)
    medications: List[str] = []
    limitations: List[str] = []  # e.g. "knee_pain", "uses_cane", "back_pain"
    activity_level: str = "low"  # "very_low" | "low" | "moderate" | "high"
    diet_habits: List[str] = []  # e.g. "eats_out_often", "stock_cubes", "smokes"
    language: str = "ar"  # "ar" | "en"
    # --- Health history (asked before the plan is built) ---
    diagnosed: str = "unknown"  # "this_year" | "1_5_years" | "over_5_years" | "unknown"
    usual_systolic: Optional[int] = Field(default=None, ge=60, le=300)
    usual_diastolic: Optional[int] = Field(default=None, ge=30, le=200)
    conditions: List[str] = []  # "diabetes" | "high_cholesterol" | "heart_disease" | "stroke" | "kidney_disease"
    family_history: str = "unknown"  # "yes" | "no" | "unknown" (heart disease / stroke in close family)
    priorities: List[str] = []  # what the patient wants to work on (salt, food, activity, weight, medicines, smoking, sleep)
    # --- Evidence-based intake (see app/intake/hypertension.py for each question's source) ---
    pregnant: str = "no"  # "yes" | "no" | "not_sure"  (asked to women < 55)
    home_monitor: str = "unknown"  # "upper_arm" | "wrist" | "none"
    missed_doses: str = "unknown"  # "none" | "some" | "many" | "stopped"
    activity_safety: List[str] = []  # PAR-Q+: "chest_pain" | "dizziness" | "supervised_only"
    activity_days: Optional[int] = Field(default=None, ge=0, le=7)  # GPAQ-style
    activity_minutes: Optional[int] = Field(default=None, ge=0, le=300)
    fruit_veg: str = "unknown"  # servings/day: "0" | "1_2" | "3_4" | "5_plus"
    salt_table: str = "unknown"  # WHO STEPS frequency: always | often | sometimes | rarely | never
    salt_cooking: str = "unknown"
    salty_foods: str = "unknown"
    tobacco: str = "unknown"  # "daily" | "sometimes" | "quit" | "never"
    sleep_hours: str = "unknown"  # "lt5" | "5_6" | "7_9" | "gt9"
    sleep_signs: List[str] = []  # "snoring" | "tired" | "observed"
    # --- Diabetes intake (ADA Standards of Care 2026) ---
    diabetes_type: str = "unknown"  # "type2" | "type1" | "unknown"
    diabetes_meds: List[str] = []  # "insulin" | "sulfonylurea" | "metformin" | "glp1" | "sglt2" | "other"
    low_sugar: str = "unknown"  # episodes in last 3 months: "none" | "sometimes" | "often" | "severe"
    glucose_monitor: str = "unknown"  # "meter" | "cgm" | "none"
    complications: List[str] = []  # "retinopathy" | "neuropathy" | "foot_ulcer"
    fasting: str = "unknown"  # plans to fast Ramadan: "yes" | "no" | "unsure"
    sugary_drinks: str = "unknown"  # frequency (always/often/sometimes/rarely/never)
    refined_grains: str = "unknown"  # white bread/rice at most meals: frequency
    sitting_hours: str = "unknown"  # "lt4" | "4_8" | "gt8"
    mood: str = "unknown"  # felt down/overwhelmed in last 2 weeks: "no" | "sometimes" | "often"

    @property
    def diseases(self) -> List[str]:
        return ["hypertension", "diabetes"] if self.disease == "both" else [self.disease]

    @property
    def has_diabetes(self) -> bool:
        return "diabetes" in self.diseases

    @property
    def has_hypertension(self) -> bool:
        return "hypertension" in self.diseases

    @property
    def weekly_activity_minutes(self) -> Optional[int]:
        if self.activity_days is None:
            return None
        return self.activity_days * (self.activity_minutes or 0)
    created_at: Optional[str] = None

    @property
    def bmi(self) -> float:
        h = self.height_cm / 100
        return round(self.weight_kg / (h * h), 1)


class Source(BaseModel):
    id: str
    title: str
    citation: str


class Goal(BaseModel):
    id: str
    frequency: Frequency
    category: str  # diet | activity | medication | monitoring | weight | lifestyle
    title_en: str
    title_ar: str
    why_en: str
    why_ar: str
    tailoring_en: str = ""
    tailoring_ar: str = ""
    time_of_day: str = "anytime"  # "morning" | "afternoon" | "evening" | "anytime" — when the app asks
    level: int = 1  # goes up when the patient succeeds, down when it's too hard
    sources: List[Source] = []
    active_from: str  # YYYY-MM-DD
    active_to: Optional[str] = None  # set when the goal is replaced by an adapted one
    replaces: Optional[str] = None


class Plan(BaseModel):
    user_id: str
    disease: str
    created_at: str
    generated_by: str  # "claude:<model>" | "mock"
    goals: List[Goal]
    retrieved_ids: List[str] = []
    summary_en: str = ""  # plain-language overview of the lifestyle plan
    summary_ar: str = ""
    insights: List[Dict[str, str]] = []  # "based on your history" facts: {icon, text_en, text_ar}

    def active_goals(self, day: str) -> List[Goal]:
        return [
            g for g in self.goals
            if g.active_from <= day and (g.active_to is None or g.active_to > day)
        ]


class BPReading(BaseModel):
    id: str = ""
    systolic: int = Field(ge=50, le=300)
    diastolic: int = Field(ge=30, le=200)
    pulse: Optional[int] = Field(default=None, ge=20, le=250)
    taken_at: str = ""  # ISO datetime
    symptoms: List[str] = []


class GlucoseReading(BaseModel):
    id: str = ""
    value: int = Field(ge=20, le=600)  # mg/dL
    context: str = "fasting"  # "fasting" | "before_meal" | "after_meal" | "bedtime" | "other"
    taken_at: str = ""
    symptoms: List[str] = []


class Adaptation(BaseModel):
    old_goal_id: str
    new_goal_id: str
    reason: str
    at: str
    direction: str = "easier"  # "easier" | "harder"


class SafetyResult(BaseModel):
    level: str  # "ok" | "elevated" | "emergency"
    reasons: List[str] = []
    title_en: str = ""
    title_ar: str = ""
    message_en: str = ""
    message_ar: str = ""


class UserData(BaseModel):
    """Everything stored for one user. The local store keeps this as one JSON file."""
    profile: Optional[Profile] = None
    plan: Optional[Plan] = None
    # period key ("2026-10-06" | "2026-W41" | "2026-10") -> goal_id -> done
    checkins: Dict[str, Dict[str, bool]] = {}
    bp: List[BPReading] = []
    glucose: List[GlucoseReading] = []
    adaptations: List[Adaptation] = []
    dismissed_adaptations: Dict[str, str] = {}  # goal_id -> date dismissed
    # Water habit tracker: date -> cups. Not a guideline target; the patient (or doctor) sets it.
    water: Dict[str, int] = {}
    water_target: int = 8


def now_iso() -> str:
    return datetime.now().replace(microsecond=0).isoformat()
