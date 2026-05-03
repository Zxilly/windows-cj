"""Subprocess wrapper around winmd-to-json.exe.

Locates the vendored exe under <workspace>/winmd-to-json/bin/, launches it as
a subprocess with the winmd path, validates the response, and returns the
parsed JSON dict. The subprocess invocation is defensive against the upstream
ynkdir/winmd-printer usage() behavior of writing help text to stdout (which
would otherwise look like a successful run with garbage JSON).
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

from windows_cj_bindgen.winmd_json.exceptions import (
    WinmdParseError,
    WinmdToolNotFoundError,
)


def locate_tool(workspace_root: Path | None = None) -> Path:
    """Find the vendored winmd-to-json.exe.

    workspace_root defaults to ascending from this file's location until we find
    a directory containing winmd-to-json/bin/winmd-to-json.exe.
    """
    if workspace_root is None:
        # __file__ is .../windows-cj-bindgen-py/src/windows_cj_bindgen/winmd_json/runner.py
        # workspace root is ../../../.. from here
        workspace_root = Path(__file__).resolve().parents[4]

    exe = workspace_root / "winmd-to-json" / "bin" / "winmd-to-json.exe"
    if not exe.exists():
        raise WinmdToolNotFoundError(
            f"winmd-to-json.exe not found at {exe}. "
            "Run `pwsh winmd-to-json/scripts/build_and_publish.ps1` to publish it."
        )
    return exe


def run_winmd_to_json(
    winmd_path: Path,
    workspace_root: Path | None = None,
) -> dict[str, Any]:
    """Invoke winmd-to-json.exe on a winmd file and return the parsed JSON.

    Raises:
        WinmdToolNotFoundError: exe missing, winmd missing, or subprocess OSError
        WinmdParseError: exe exit non-zero or stdout not valid JSON
    """
    if not winmd_path.exists():
        raise WinmdToolNotFoundError(f"winmd file not found: {winmd_path}")

    exe = locate_tool(workspace_root=workspace_root)

    try:
        result = subprocess.run(
            [str(exe), str(winmd_path)],
            check=False,
            capture_output=True,
        )
    except OSError as exc:
        raise WinmdToolNotFoundError(f"could not launch {exe}: {exc}") from exc

    if result.returncode != 0:
        stderr_text = result.stderr.decode("utf-8", errors="replace") if result.stderr else "(empty)"
        raise WinmdParseError(f"winmd-to-json exit code {result.returncode} for {winmd_path}\nstderr: {stderr_text}")

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        # Defense against upstream usage() writing help text to stdout
        head = result.stdout[:200].decode("utf-8", errors="replace")
        raise WinmdParseError(
            f"winmd-to-json output not valid JSON for {winmd_path}\n"
            f"first 200 bytes of stdout: {head!r}\n"
            f"json error: {exc}"
        ) from exc

    if not isinstance(data, dict):
        raise WinmdParseError(f"winmd-to-json output is not a JSON object for {winmd_path}: got {type(data).__name__}")

    return data
