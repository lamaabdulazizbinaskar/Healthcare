"""Parse the /knowledge markdown files into structured guideline entries.

See knowledge/README.md for the exact entry format.
"""
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List

_HEADING = re.compile(r"^##\s+([A-Z0-9-]+):\s*(.+)$")
_META = re.compile(r"^-\s+([a-z_]+):\s*(.+)$")


@dataclass
class GuidelineEntry:
    id: str
    title: str
    disease: str
    source: str = ""
    tags: List[str] = field(default_factory=list)
    frequency_hint: str = "daily"
    contraindications: str = ""
    text: str = ""

    @property
    def search_text(self) -> str:
        return " ".join([self.title, " ".join(self.tags), self.text])


def _parse_file(path: Path, disease: str) -> List[GuidelineEntry]:
    entries: List[GuidelineEntry] = []
    current = None
    body: List[str] = []

    def flush():
        if current is not None:
            current.text = " ".join(l.strip() for l in body if l.strip())
            entries.append(current)

    for line in path.read_text(encoding="utf-8").splitlines():
        m = _HEADING.match(line)
        if m:
            flush()
            current = GuidelineEntry(id=m.group(1), title=m.group(2).strip(), disease=disease)
            body = []
            continue
        if current is None:
            continue
        meta = _META.match(line)
        if meta and not body:
            key, value = meta.group(1), meta.group(2).strip()
            if key == "tags":
                current.tags = [t.strip() for t in value.split(",") if t.strip()]
            elif key in ("source", "frequency_hint", "contraindications"):
                setattr(current, key, value)
            continue
        if line.startswith(">"):
            continue
        body.append(line)
    flush()
    return entries


def load_knowledge(knowledge_dir: Path, disease: str) -> List[GuidelineEntry]:
    folder = knowledge_dir / disease
    entries: List[GuidelineEntry] = []
    for path in sorted(folder.glob("*.md")):
        entries.extend(_parse_file(path, disease))
    return entries
