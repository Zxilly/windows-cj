"""Smoke tests verifying the project skeleton is healthy."""

from __future__ import annotations

import subprocess
import sys

import windows_cj_bindgen
from windows_cj_bindgen._version import __version__


def test_package_imports() -> None:
    """Package can be imported."""
    assert windows_cj_bindgen.__version__ == __version__


def test_version_is_string() -> None:
    """__version__ is a non-empty string."""
    assert isinstance(__version__, str)
    assert __version__


def test_cli_module_imports() -> None:
    """CLI module is importable without errors."""
    from windows_cj_bindgen import cli

    assert callable(cli.main)


def test_cli_invocation_via_subprocess() -> None:
    """`python -m` style invocation works (sanity check for entry point)."""
    result = subprocess.run(
        [sys.executable, "-c", "from windows_cj_bindgen.cli import main; print('ok')"],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "ok" in result.stdout
