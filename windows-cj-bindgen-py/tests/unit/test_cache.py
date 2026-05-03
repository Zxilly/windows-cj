"""Unit tests for winmd_json.cache."""

from __future__ import annotations

import hashlib
from pathlib import Path

from windows_cj_bindgen.winmd_json.cache import (
    cache_key,
    load_cached,
    store_cached,
)


def test_cache_key_combines_sha_and_tool_version() -> None:
    """cache_key is a stable function of (winmd content sha256, tool version)."""
    winmd = b"hello winmd"
    expected_winmd_sha = hashlib.sha256(winmd).hexdigest()
    key = cache_key(winmd_bytes=winmd, tool_version="1.0.0")
    assert expected_winmd_sha[:16] in key
    assert "1.0.0" in key


def test_cache_key_changes_when_tool_version_changes() -> None:
    winmd = b"hello"
    k1 = cache_key(winmd_bytes=winmd, tool_version="1.0.0")
    k2 = cache_key(winmd_bytes=winmd, tool_version="1.1.0")
    assert k1 != k2


def test_cache_key_changes_when_winmd_changes() -> None:
    k1 = cache_key(winmd_bytes=b"a", tool_version="1.0.0")
    k2 = cache_key(winmd_bytes=b"b", tool_version="1.0.0")
    assert k1 != k2


def test_store_and_load_roundtrip(tmp_path: Path) -> None:
    """store_cached writes file, load_cached reads it."""
    cache_dir = tmp_path / "cache"
    payload = {"types": [], "winmd_file": "x.winmd"}
    store_cached(cache_dir=cache_dir, key="abc123", data=payload)
    loaded = load_cached(cache_dir=cache_dir, key="abc123")
    assert loaded == payload


def test_load_cached_returns_none_on_miss(tmp_path: Path) -> None:
    cache_dir = tmp_path / "cache"
    cache_dir.mkdir()
    assert load_cached(cache_dir=cache_dir, key="never-stored") is None


def test_load_cached_returns_none_when_dir_missing(tmp_path: Path) -> None:
    cache_dir = tmp_path / "nonexistent-cache"
    assert load_cached(cache_dir=cache_dir, key="anything") is None


def test_store_creates_dir_if_missing(tmp_path: Path) -> None:
    cache_dir = tmp_path / "deep" / "path"
    store_cached(cache_dir=cache_dir, key="k", data={"x": 1})
    assert cache_dir.exists()
    assert load_cached(cache_dir=cache_dir, key="k") == {"x": 1}


def test_load_cached_returns_none_on_corrupt_file(tmp_path: Path) -> None:
    cache_dir = tmp_path / "cache"
    cache_dir.mkdir()
    (cache_dir / "bad.json").write_text("not json")
    assert load_cached(cache_dir=cache_dir, key="bad") is None
