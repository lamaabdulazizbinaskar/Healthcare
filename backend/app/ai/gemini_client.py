"""Google Gemini (free tier via Google AI Studio): one JSON-schema call, JSON in / JSON out.

* Key comes from GEMINI_API_KEY (never hardcoded).
* Uses the REST API directly (httpx is already installed with the anthropic SDK).
* If the model rejects the JSON schema, we retry with the schema in the instructions instead.
"""
import json
import logging
from typing import Any, Dict, List, Union

import httpx

from .. import config
from .claude_client import AIError

log = logging.getLogger("lifestep.ai")

_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
# Google retires model versions; this alias always points to the current Flash model.
_FALLBACK_MODEL = "gemini-flash-latest"


def _text(content: Union[str, List[Dict[str, Any]]]) -> str:
    if isinstance(content, str):
        return content
    return "\n".join(b.get("text", "") for b in content if b.get("type") == "text")


def _post(model: str, body: Dict[str, Any]) -> httpx.Response:
    try:
        r = httpx.post(
            _URL.format(model=model),
            headers={"x-goog-api-key": config.GEMINI_API_KEY},
            json=body,
            timeout=90.0,
        )
        if r.status_code == 404 and model != _FALLBACK_MODEL:
            log.warning("Gemini model %s not found, using %s", model, _FALLBACK_MODEL)
            return _post(_FALLBACK_MODEL, body)
        return r
    except httpx.HTTPError as e:
        raise AIError("Could not reach the Gemini API") from e


def structured_call(
    system: str,
    content: Union[str, List[Dict[str, Any]]],
    schema: Dict[str, Any],
    max_tokens: int = 12000,
    effort: str = "medium",
) -> Dict[str, Any]:
    body = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": [{"role": "user", "parts": [{"text": _text(content)}]}],
        "generationConfig": {
            "maxOutputTokens": max_tokens,
            "responseMimeType": "application/json",
            "responseJsonSchema": schema,
        },
    }
    r = _post(config.GEMINI_MODEL, body)
    if r.status_code == 400 and "API_KEY_INVALID" in r.text:
        raise AIError("Invalid GEMINI_API_KEY")
    if r.status_code == 400:
        # Schema not accepted: put it in the instructions instead.
        log.warning("Gemini rejected the JSON schema, retrying without it: %s", r.text[:200])
        del body["generationConfig"]["responseJsonSchema"]
        body["systemInstruction"]["parts"][0]["text"] = (
            f"{system}\n\nReply with JSON only, matching this JSON schema exactly:\n{json.dumps(schema)}"
        )
        r = _post(config.GEMINI_MODEL, body)

    if r.status_code in (401, 403):
        raise AIError("Invalid GEMINI_API_KEY")
    if r.status_code == 429:
        raise AIError("Gemini rate limit reached, try again shortly")
    if r.status_code != 200:
        raise AIError(f"Gemini API error {r.status_code}: {r.text[:200]}")

    data = r.json()
    if data.get("promptFeedback", {}).get("blockReason"):
        raise AIError("Gemini declined this request")
    candidates = data.get("candidates") or []
    if not candidates:
        raise AIError("Gemini returned no answer")
    cand = candidates[0]
    if cand.get("finishReason") == "MAX_TOKENS":
        raise AIError("Gemini response was cut off (max tokens)")
    parts = cand.get("content", {}).get("parts", [])
    text = "".join(p.get("text", "") for p in parts if not p.get("thought"))
    try:
        return json.loads(text)
    except json.JSONDecodeError as e:
        raise AIError("Gemini returned invalid JSON") from e
