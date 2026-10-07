"""Disease module registry. 'both' = hypertension + diabetes in one consistent plan."""
from typing import Dict, List

from .base import DiseaseModule
from .lifestyle import LifestyleModule

_MODULES: Dict[str, DiseaseModule] = {
    "hypertension": LifestyleModule("hypertension", ["hypertension"], {"en": "High blood pressure", "ar": "ارتفاع ضغط الدم"}),
    "diabetes": LifestyleModule("diabetes", ["diabetes"], {"en": "Diabetes", "ar": "السكري"}),
    "both": LifestyleModule(
        "both", ["hypertension", "diabetes"], {"en": "High blood pressure + diabetes", "ar": "الضغط والسكري معًا"}
    ),
}

PLANNED: List[Dict] = [
    {"id": "heart_failure", "name": {"en": "Heart failure", "ar": "قصور القلب"}, "available": False},
]


def get_module(disease_id: str) -> DiseaseModule:
    if disease_id not in _MODULES:
        raise KeyError(f"Disease module '{disease_id}' is not available yet")
    return _MODULES[disease_id]


def list_modules() -> List[Dict]:
    return [{"id": k, "name": m.name, "available": True} for k, m in _MODULES.items()] + PLANNED
