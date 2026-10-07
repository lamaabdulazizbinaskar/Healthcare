"""Disease module interface.

Each chronic condition (hypertension now; diabetes / heart failure later) is a module
that tells the shared engine:
  * which knowledge folder to retrieve from,
  * which retrieval queries to run for a given patient profile,
  * which retrieved entries are NOT appropriate for this patient (hard filters),
  * its rule-based red flags (see app/safety).
Adding a disease = add knowledge/<disease>/*.md + a new DiseaseModule subclass + register it.
"""
from abc import ABC, abstractmethod
from typing import Dict, List, Optional

from ..models import Profile
from ..rag.knowledge_loader import GuidelineEntry


class DiseaseModule(ABC):
    id: str
    name: Dict[str, str]  # {"en": ..., "ar": ...}
    available: bool = True

    @abstractmethod
    def retrieval_queries(self, profile: Profile) -> List[str]:
        """Search queries built from the profile; each one pulls a few guideline entries."""

    def is_applicable(self, entry: GuidelineEntry, profile: Profile) -> bool:
        """Hard, rule-based filter applied after retrieval (e.g. no weight-loss goal if BMI < 25)."""
        return True

    def patient_cautions(self, profile: Profile) -> List[str]:
        """Rule-based cautions passed to the AI as constraints (not advice to the patient)."""
        return []

    def excluded(self, profile: Profile) -> Optional[Dict[str, str]]:
        """Situations where no lifestyle plan may be generated (e.g. pregnancy). None = OK."""
        return None

    def insights(self, profile: Profile) -> List[Dict[str, str]]:
        """Bilingual 'based on your history' explanations shown with the plan."""
        return []
