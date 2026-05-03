"""End-to-end: run real winmd-to-json.exe on the 3 vendored winmd files.

These tests are slow (~30s per file). Skip if winmd-to-json.exe is not
published yet.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from windows_cj_bindgen.winmd_json import (
    WinmdToolNotFoundError,
    parse_winmd,
)


def _workspace_root() -> Path:
    # tests/integration/test_three_winmds.py is at .../windows-cj-bindgen-py/tests/integration/
    # workspace root is parents[2] = .../windows-cj-bindgen-py, and we need its parent = vpgc-worktree root
    return Path(__file__).resolve().parents[3]


def _winmd(name: str) -> Path:
    return _workspace_root() / "winmd" / name


@pytest.fixture(scope="module", autouse=True)
def _check_tool_available() -> None:
    """Skip module if winmd-to-json.exe is not published."""
    exe = _workspace_root() / "winmd-to-json" / "bin" / "winmd-to-json.exe"
    if not exe.exists():
        pytest.skip(f"winmd-to-json.exe not at {exe}; run `pwsh winmd-to-json/scripts/build_and_publish.ps1` first")


@pytest.mark.integration
def test_parse_wdk_winmd() -> None:
    """Windows.Wdk.winmd parses successfully."""
    wf = parse_winmd(_winmd("Windows.Wdk.winmd"), workspace_root=_workspace_root())
    assert wf.winmd_file.endswith("Windows.Wdk.winmd")
    assert wf.source_set == "winmd_main"
    assert len(wf.winmd_sha256) == 64
    real_types = [t for t in wf.types if t.name != "<Module>"]
    assert len(real_types) > 100
    # Wdk has many Windows.Wdk.* namespaced types
    wdk_types = [t for t in real_types if t.namespace.startswith("Windows.Wdk")]
    assert len(wdk_types) > 50


@pytest.mark.integration
def test_parse_winrt_winmd() -> None:
    """Windows.winmd (WinRT) parses successfully."""
    wf = parse_winmd(_winmd("Windows.winmd"), workspace_root=_workspace_root())
    assert wf.winmd_file.endswith("Windows.winmd")
    assert wf.source_set == "winmd_main"
    real_types = [t for t in wf.types if t.name != "<Module>"]
    assert len(real_types) > 1000


@pytest.mark.integration
def test_parse_win32_winmd() -> None:
    """Windows.Win32.winmd parses successfully."""
    wf = parse_winmd(_winmd("Windows.Win32.winmd"), workspace_root=_workspace_root())
    assert wf.winmd_file.endswith("Windows.Win32.winmd")
    assert wf.source_set == "winmd_main"
    real_types = [t for t in wf.types if t.name != "<Module>"]
    assert len(real_types) > 30000


@pytest.mark.integration
def test_parse_missing_file_raises() -> None:
    """parse_winmd on a nonexistent path raises WinmdToolNotFoundError."""
    with pytest.raises(WinmdToolNotFoundError, match="winmd file"):
        parse_winmd(_workspace_root() / "definitely-does-not-exist.winmd")
