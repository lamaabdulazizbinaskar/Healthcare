"""A small local vector store (TF-IDF vectors + cosine similarity), pure Python.

Why not ChromaDB/FAISS? The knowledge base is ~30 entries, so a dependency-free store
keeps setup instant and fully offline. `VectorStore` is the seam: swap in a
ChromaDB-backed class (with real embeddings) without touching the callers.
"""
import math
import re
from collections import Counter
from typing import Dict, List, Optional, Tuple

from .knowledge_loader import GuidelineEntry

_TOKEN = re.compile(r"[a-z0-9]+")
_STOP = set(
    "a an and are as at be by for from has have in is it its of on or that the this to "
    "with your you per day week about can should".split()
)


def _tokens(text: str) -> List[str]:
    out = []
    for tok in _TOKEN.findall(text.lower()):
        if tok in _STOP or len(tok) < 2:
            continue
        # crude stemming so "exercises"/"exercise", "walking"/"walk" match
        for suffix in ("ing", "es", "s"):
            if tok.endswith(suffix) and len(tok) - len(suffix) >= 4:
                tok = tok[: -len(suffix)]
                break
        out.append(tok)
    return out


class VectorStore:
    def __init__(self, entries: List[GuidelineEntry]):
        self.entries: Dict[str, GuidelineEntry] = {e.id: e for e in entries}
        docs = {e.id: Counter(_tokens(e.search_text)) for e in entries}
        n = max(len(docs), 1)
        df: Counter = Counter()
        for counts in docs.values():
            df.update(counts.keys())
        self._idf = {t: math.log((1 + n) / (1 + c)) + 1 for t, c in df.items()}
        self._vectors = {doc_id: self._vectorize(c) for doc_id, c in docs.items()}

    def _vectorize(self, counts: Counter) -> Dict[str, float]:
        vec = {t: (1 + math.log(c)) * self._idf.get(t, 0.0) for t, c in counts.items()}
        norm = math.sqrt(sum(v * v for v in vec.values())) or 1.0
        return {t: v / norm for t, v in vec.items()}

    def search(
        self, query: str, k: int = 4, exclude: Optional[set] = None
    ) -> List[Tuple[GuidelineEntry, float]]:
        q = self._vectorize(Counter(_tokens(query)))
        scored = []
        for doc_id, vec in self._vectors.items():
            if exclude and doc_id in exclude:
                continue
            score = sum(w * vec.get(t, 0.0) for t, w in q.items())
            if score > 0:
                scored.append((self.entries[doc_id], score))
        scored.sort(key=lambda x: x[1], reverse=True)
        return scored[:k]

    def get(self, entry_id: str) -> Optional[GuidelineEntry]:
        return self.entries.get(entry_id)
