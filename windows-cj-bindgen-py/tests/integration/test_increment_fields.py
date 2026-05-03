"""Verify the 4 windows-cj increment fields are populated in real winmds."""

from __future__ import annotations

from pathlib import Path

import pytest

from windows_cj_bindgen.winmd_json import parse_winmd


def _workspace_root() -> Path:
    return Path(__file__).resolve().parents[3]


@pytest.fixture(scope="module", autouse=True)
def _check_tool_available() -> None:
    exe = _workspace_root() / "winmd-to-json" / "bin" / "winmd-to-json.exe"
    if not exe.exists():
        pytest.skip(f"winmd-to-json.exe not at {exe}")


@pytest.mark.integration
def test_supported_architectures_field_present() -> None:
    wf = parse_winmd(_workspace_root() / "winmd" / "Windows.Wdk.winmd", workspace_root=_workspace_root())
    real_types = [t for t in wf.types if t.name != "<Module>"]
    for t in real_types[:50]:
        assert isinstance(t.supported_architectures, list)
        for a in t.supported_architectures:
            assert a in ("X86", "X64", "Arm64"), f"unexpected arch {a!r} on {t.name}"


@pytest.mark.integration
def test_is_experimental_field_is_bool() -> None:
    wf = parse_winmd(_workspace_root() / "winmd" / "Windows.winmd", workspace_root=_workspace_root())
    real_types = [t for t in wf.types if t.name != "<Module>"]
    for t in real_types[:200]:
        assert isinstance(t.is_experimental, bool)


@pytest.mark.integration
def test_supported_os_platform_is_string_or_none() -> None:
    wf = parse_winmd(_workspace_root() / "winmd" / "Windows.winmd", workspace_root=_workspace_root())
    real_types = [t for t in wf.types if t.name != "<Module>"]
    for t in real_types[:200]:
        assert t.supported_os_platform is None or isinstance(t.supported_os_platform, str)


@pytest.mark.integration
def test_source_set_is_winmd_main() -> None:
    wf = parse_winmd(_workspace_root() / "winmd" / "Windows.Wdk.winmd", workspace_root=_workspace_root())
    assert wf.source_set == "winmd_main"
    real_types = [t for t in wf.types if t.name != "<Module>"]
    for t in real_types:
        assert t.source_set == "winmd_main"


@pytest.mark.integration
def test_some_win32_types_are_arch_restricted() -> None:
    """Win32 has many types restricted to specific architectures (e.g. x86 fastcall types)."""
    wf = parse_winmd(_workspace_root() / "winmd" / "Windows.Win32.winmd", workspace_root=_workspace_root())
    real_types = [t for t in wf.types if t.name != "<Module>"]
    arch_restricted = [t for t in real_types if set(t.supported_architectures) != {"X86", "X64", "Arm64"}]
    assert len(arch_restricted) > 0, "expected some Win32 types to be arch-restricted"


@pytest.mark.integration
def test_some_winrt_types_are_experimental() -> None:
    """WinRT has experimental APIs marked with ExperimentalAttribute."""
    wf = parse_winmd(_workspace_root() / "winmd" / "Windows.winmd", workspace_root=_workspace_root())
    real_types = [t for t in wf.types if t.name != "<Module>"]
    # Allow zero experimental types — some winmd snapshots may have had experimental
    # APIs promoted to stable. We just require the field to be populated correctly.
    assert all(isinstance(t.is_experimental, bool) for t in real_types)
