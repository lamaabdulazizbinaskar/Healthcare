"""Retrieval: one vector store per knowledge folder; a module may search several (e.g. 'both')."""
from functools import lru_cache
from typing import List, Optional

from .. import config
from ..diseases import get_module
from ..models import Profile
from .knowledge_loader import GuidelineEntry, load_knowledge
from .vector_store import VectorStore


@lru_cache(maxsize=None)
def get_store(folder: str) -> VectorStore:
    return VectorStore(load_knowledge(config.KNOWLEDGE_DIR, folder))


def folders_for(disease: str) -> List[str]:
    return list(getattr(get_module(disease), "folders", [disease]))


def get_entry(entry_id: str) -> Optional[GuidelineEntry]:
    for folder in ("hypertension", "diabetes"):
        e = get_store(folder).get(entry_id)
        if e:
            return e
    return None


def search(disease: str, query: str, k: int = 4, exclude: Optional[set] = None):
    hits = []
    for folder in folders_for(disease):
        hits.extend(get_store(folder).search(query, k=k, exclude=exclude))
    hits.sort(key=lambda x: x[1], reverse=True)
    return hits[:k]


def retrieve_for_profile(profile: Profile, per_query: int = 2) -> List[GuidelineEntry]:
    """Run each module query, keep the top hits, apply the module's hard filters, dedupe."""
    module = get_module(profile.disease)
    seen = set()
    results: List[GuidelineEntry] = []
    for query in module.retrieval_queries(profile):
        for entry, _score in search(profile.disease, query, k=per_query, exclude=seen):
            if not module.is_applicable(entry, profile):
                continue
            seen.add(entry.id)
            results.append(entry)
    return results


def retrieve(disease: str, query: str, k: int = 4) -> List[GuidelineEntry]:
    return [e for e, _ in search(disease, query, k=k)]
