"""Picks the AI provider for structured calls: Claude or Gemini (see config.AI_MODE)."""
from typing import Any, Dict, List, Union

from .. import config
from . import claude_client, gemini_client
from .claude_client import AIError

__all__ = ["AIError", "structured_call"]


def structured_call(
    system: str,
    content: Union[str, List[Dict[str, Any]]],
    schema: Dict[str, Any],
    max_tokens: int = 12000,
    effort: str = "medium",
) -> Dict[str, Any]:
    if config.AI_MODE == "gemini":
        return gemini_client.structured_call(system, content, schema, max_tokens, effort)
    return claude_client.structured_call(system, content, schema, max_tokens, effort)
