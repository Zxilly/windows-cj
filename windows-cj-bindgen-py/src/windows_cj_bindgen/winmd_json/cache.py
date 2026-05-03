"""sha256-based cache for winmd-to-json output.

Cache key is derived from (winmd content sha256, tool version) so a winmd file
or tool upgrade automatically invalidates entries. Cache misses are returned
as None (caller decides whether to run subprocess).
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


def cache_key(winmd_bytes: bytes, tool_version: str) -> str:
    """Compute a stable cache key from winmd content + tool version."""
    sha = hashlib.sha256(winmd_bytes).hexdigest()
    return f"{sha[:32]}-{tool_version}"


def store_cached(cache_dir: Path, key: str, data: dict[str, Any]) -> None:
    """Store data under key in cache_dir, creating the dir if needed."""
    cache_dir.mkdir(parents=True, exist_ok=True)
    path = cache_dir / f"{key}.json"
    path.write_text(json.dumps(data), encoding="utf-8")


def load_cached(cache_dir: Path, key: str) -> dict[str, Any] | None:
    """Load data for key from cache_dir, or None if missing or corrupt."""
    path = cache_dir / f"{key}.json"
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))  # type: ignore[no-any-return]
    except (json.JSONDecodeError, OSError):
        return None
