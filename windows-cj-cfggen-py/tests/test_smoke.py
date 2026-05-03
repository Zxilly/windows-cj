"""Smoke tests verifying the project skeleton is healthy."""

from __future__ import annotations

import subprocess
import sys

import pytest

import windows_cj_cfggen
from windows_cj_cfggen._version import __version__


def test_package_imports() -> None:
    """Package can be imported."""
    assert windows_cj_cfggen.__version__ == __version__


def test_version_is_string() -> None:
    """__version__ is a non-empty string."""
    assert isinstance(__version__, str)
    assert __version__


def test_cli_module_imports() -> None:
    """CLI module is importable without errors."""
    from windows_cj_cfggen import cli

    assert callable(cli.main)


def test_cli_invocation_via_subprocess() -> None:
    """`python -m` style invocation works (sanity check for entry point)."""
    result = subprocess.run(
        [sys.executable, "-c", "from windows_cj_cfggen.cli import main; print('ok')"],
        check=False,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0
    assert "ok" in result.stdout


def test_gen_subcommand_raises_not_implemented() -> None:
    """`gen` 子命令在 M0 阶段必须 raise NotImplementedError."""
    from click.testing import CliRunner

    from windows_cj_cfggen.cli import main

    runner = CliRunner()
    result = runner.invoke(main, ["gen"])

    assert result.exit_code != 0
    assert isinstance(result.exception, NotImplementedError)


def test_bindgen_dependency_available() -> None:
    """windows-cj-bindgen is installed and importable as a dependency."""
    pytest.importorskip("windows_cj_bindgen")
    import windows_cj_bindgen

    assert isinstance(windows_cj_bindgen.__version__, str)
