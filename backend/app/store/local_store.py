"""Local mock store: one JSON file per user under backend/data/. Zero setup."""
import re
import threading
from pathlib import Path

from ..models import UserData
from .base import Repository


class LocalJsonRepository(Repository):
    def __init__(self, data_dir: Path):
        self.data_dir = data_dir
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self._lock = threading.Lock()

    def _path(self, user_id: str) -> Path:
        safe = re.sub(r"[^A-Za-z0-9_-]", "_", user_id)
        return self.data_dir / f"{safe}.json"

    def load(self, user_id: str) -> UserData:
        path = self._path(user_id)
        with self._lock:
            if not path.exists():
                return UserData()
            return UserData.model_validate_json(path.read_text(encoding="utf-8"))

    def save(self, user_id: str, data: UserData) -> None:
        path = self._path(user_id)
        with self._lock:
            tmp = path.with_suffix(".tmp")
            tmp.write_text(data.model_dump_json(indent=2), encoding="utf-8")
            tmp.replace(path)

    def delete(self, user_id: str) -> None:
        with self._lock:
            self._path(user_id).unlink(missing_ok=True)
