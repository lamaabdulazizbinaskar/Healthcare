"""Runtime configuration, read from environment variables (and an optional backend/.env)."""
import os
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
PROJECT_DIR = BACKEND_DIR.parent


def _load_dotenv(path: Path) -> None:
    """Minimal .env loader so we don't need python-dotenv. Existing env vars win."""
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


_load_dotenv(BACKEND_DIR / ".env")

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
CLAUDE_MODEL = os.environ.get("CLAUDE_MODEL", "claude-opus-5-5")

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

_ai_mode = os.environ.get("KHUTWA_AI_MODE", "auto").lower()
if _ai_mode == "auto":
    AI_MODE = "claude" if ANTHROPIC_API_KEY else "gemini" if GEMINI_API_KEY else "mock"
else:
    AI_MODE = _ai_mode  # "claude" | "gemini" | "mock"
AI_ON = AI_MODE in ("claude", "gemini")
AI_MODEL = {"claude": CLAUDE_MODEL, "gemini": GEMINI_MODEL}.get(AI_MODE, "")

STORE = os.environ.get("KHUTWA_STORE", "local").lower()  # "local" | "firestore"
AUTH = os.environ.get("KHUTWA_AUTH", "demo").lower()  # "demo" | "firebase"

DATA_DIR = Path(os.environ.get("KHUTWA_DATA_DIR", BACKEND_DIR / "data"))
KNOWLEDGE_DIR = Path(os.environ.get("KHUTWA_KNOWLEDGE_DIR", PROJECT_DIR / "knowledge"))
WEB_BUILD_DIR = Path(os.environ.get("KHUTWA_WEB_DIR", PROJECT_DIR / "app" / "build" / "web"))

DEMO_USER_ID = "demo-patient"
