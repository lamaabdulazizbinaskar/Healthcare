"""Simple in-memory limits for AI-backed endpoints, so a public demo link can't run up the Claude bill.

Per visitor (IP): KHUTWA_AI_PER_HOUR requests/hour (default 20). Whole app: KHUTWA_AI_PER_DAY/day (default 400).
Only applies when the AI is on; offline/demo mode is unlimited. Resets when the server restarts.
"""
import os
import threading
import time
from collections import defaultdict, deque

from fastapi import HTTPException, Request

from . import config

PER_HOUR = int(os.environ.get("KHUTWA_AI_PER_HOUR", "20"))
PER_DAY = int(os.environ.get("KHUTWA_AI_PER_DAY", "400"))

_lock = threading.Lock()
_by_ip = defaultdict(deque)
_all = deque()


def _client_ip(request: Request) -> str:
    fwd = request.headers.get("x-forwarded-for", "")
    return fwd.split(",")[0].strip() if fwd else (request.client.host if request.client else "unknown")


def ai_limit(request: Request) -> None:
    """FastAPI dependency: raise 429 when the visitor or the whole app is over its AI budget."""
    if config.AI_MODE != "claude":
        return
    now = time.time()
    ip = _client_ip(request)
    with _lock:
        q = _by_ip[ip]
        while q and now - q[0] > 3600:
            q.popleft()
        while _all and now - _all[0] > 86400:
            _all.popleft()
        if len(q) >= PER_HOUR or len(_all) >= PER_DAY:
            raise HTTPException(429, "Too many AI requests for this demo; please try again later.")
        q.append(now)
        _all.append(now)
