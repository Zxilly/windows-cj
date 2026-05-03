"""Unit tests for winmd_json.runner."""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from windows_cj_bindgen.winmd_json.exceptions import (
    WinmdParseError,
    WinmdToolNotFoundError,
)
from windows_cj_bindgen.winmd_json.runner import (
    locate_tool,
    run_winmd_to_json,
)


def test_locate_tool_returns_path_when_found(tmp_path: Path) -> None:
    """locate_tool finds the exe at the expected vendored location."""
    fake_exe = tmp_path / "winmd-to-json" / "bin" / "winmd-to-json.exe"
    fake_exe.parent.mkdir(parents=True)
    fake_exe.write_bytes(b"fake")
    result = locate_tool(workspace_root=tmp_path)
    assert result == fake_exe


def test_locate_tool_raises_when_missing(tmp_path: Path) -> None:
    """locate_tool raises WinmdToolNotFoundError when exe absent."""
    with pytest.raises(WinmdToolNotFoundError, match=r"winmd-to-json\.exe"):
        locate_tool(workspace_root=tmp_path)


def test_run_winmd_to_json_returns_dict(tmp_path: Path) -> None:
    """run_winmd_to_json invokes subprocess and returns parsed JSON dict."""
    fake_exe = tmp_path / "winmd-to-json" / "bin" / "winmd-to-json.exe"
    fake_exe.parent.mkdir(parents=True)
    fake_exe.write_bytes(b"fake")
    fake_winmd = tmp_path / "test.winmd"
    fake_winmd.write_bytes(b"fake winmd bytes")

    fake_output = {
        "winmd_file": "test.winmd",
        "winmd_sha256": "0" * 64,
        "tool_version": "1.0.0",
        "schema_version": "1",
        "source_set": "winmd_main",
        "types": [],
    }
    mock_result = MagicMock(returncode=0, stdout=json.dumps(fake_output).encode("utf-8"), stderr=b"")
    with patch("subprocess.run", return_value=mock_result) as mock_run:
        result = run_winmd_to_json(fake_winmd, workspace_root=tmp_path)
    assert result == fake_output
    mock_run.assert_called_once()
    args = mock_run.call_args[0][0]
    assert args[0] == str(fake_exe)
    assert args[1] == str(fake_winmd)


def test_run_winmd_to_json_raises_on_nonzero_exit(tmp_path: Path) -> None:
    """run_winmd_to_json raises WinmdParseError when exe exits non-zero."""
    fake_exe = tmp_path / "winmd-to-json" / "bin" / "winmd-to-json.exe"
    fake_exe.parent.mkdir(parents=True)
    fake_exe.write_bytes(b"fake")
    fake_winmd = tmp_path / "test.winmd"
    fake_winmd.write_bytes(b"fake")

    mock_result = MagicMock(returncode=1, stdout=b"", stderr=b"some error")
    with patch("subprocess.run", return_value=mock_result), pytest.raises(WinmdParseError, match="exit code 1"):
        run_winmd_to_json(fake_winmd, workspace_root=tmp_path)


def test_run_winmd_to_json_raises_on_invalid_json(tmp_path: Path) -> None:
    """run_winmd_to_json raises WinmdParseError when stdout is not JSON.

    Critical: per Task 4 review of M0, winmd-to-json upstream usage() writes
    to stdout (not stderr), so a zero-arg or wrong-arg invocation that produces
    "winmd-printer [-h] ..." text instead of JSON must surface as a parse error
    with a useful message.
    """
    fake_exe = tmp_path / "winmd-to-json" / "bin" / "winmd-to-json.exe"
    fake_exe.parent.mkdir(parents=True)
    fake_exe.write_bytes(b"fake")
    fake_winmd = tmp_path / "test.winmd"
    fake_winmd.write_bytes(b"fake")

    mock_result = MagicMock(returncode=0, stdout=b"winmd-printer [-h] usage line", stderr=b"")
    with patch("subprocess.run", return_value=mock_result), pytest.raises(WinmdParseError, match="not valid JSON"):
        run_winmd_to_json(fake_winmd, workspace_root=tmp_path)


def test_run_winmd_to_json_raises_when_winmd_missing(tmp_path: Path) -> None:
    """run_winmd_to_json validates winmd path before launching subprocess."""
    fake_exe = tmp_path / "winmd-to-json" / "bin" / "winmd-to-json.exe"
    fake_exe.parent.mkdir(parents=True)
    fake_exe.write_bytes(b"fake")
    nonexistent_winmd = tmp_path / "missing.winmd"

    with pytest.raises(WinmdToolNotFoundError, match="winmd file"):
        run_winmd_to_json(nonexistent_winmd, workspace_root=tmp_path)


def test_run_winmd_to_json_raises_on_oserror(tmp_path: Path) -> None:
    """OSError from subprocess.run is converted to WinmdToolNotFoundError."""
    fake_exe = tmp_path / "winmd-to-json" / "bin" / "winmd-to-json.exe"
    fake_exe.parent.mkdir(parents=True)
    fake_exe.write_bytes(b"fake")
    fake_winmd = tmp_path / "test.winmd"
    fake_winmd.write_bytes(b"fake")

    with (
        patch("subprocess.run", side_effect=OSError("permission denied")),
        pytest.raises(WinmdToolNotFoundError, match="permission denied"),
    ):
        run_winmd_to_json(fake_winmd, workspace_root=tmp_path)
