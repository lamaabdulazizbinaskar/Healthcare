"""Thin wrapper around the Anthropic SDK: one structured-output call, JSON in / JSON out.

* Key comes from ANTHROPIC_API_KEY (never hardcoded).
* Structured outputs (`output_config.format`) guarantee the reply matches our JSON schema.
* Server-side refusal fallback ("default") is enabled so a safety-classifier decline on the
  primary model is retried on a fallback model inside the same call.
"""
import json
import logging
from typing import Any, Dict, List, Union

import anthropic

from .. import config

log = logging.getLogger("khutwa.ai")

_client = None


class AIError(RuntimeError):
    pass


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(timeout=120.0)
    return _client


def structured_call(
    system: str,
    content: Union[str, List[Dict[str, Any]]],
    schema: Dict[str, Any],
    max_tokens: int = 12000,
    effort: str = "medium",
) -> Dict[str, Any]:
    client = _get_client()
    try:
        response = client.beta.messages.create(
            model=config.CLAUDE_MODEL,
            max_tokens=max_tokens,
            system=system,
            messages=[{"role": "user", "content": content}],
            output_config={"effort": effort, "format": {"type": "json_schema", "schema": schema}},
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
        )
    except anthropic.AuthenticationError as e:
        raise AIError("Invalid ANTHROPIC_API_KEY") from e
    except anthropic.RateLimitError as e:
        raise AIError("Claude rate limit reached, try again shortly") from e
    except anthropic.APIStatusError as e:
        raise AIError(f"Claude API error {e.status_code}: {e.message}") from e
    except anthropic.APIConnectionError as e:
        raise AIError("Could not reach the Claude API") from e

    if response.stop_reason == "refusal":
        raise AIError("Claude declined this request")
    if response.stop_reason == "max_tokens":
        raise AIError("Claude response was cut off (max_tokens)")
    text = "".join(b.text for b in response.content if b.type == "text")
    try:
        return json.loads(text)
    except json.JSONDecodeError as e:
        raise AIError("Claude returned invalid JSON") from e
