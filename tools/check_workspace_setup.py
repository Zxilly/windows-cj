#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = []
# ///
"""Verify windows-cj/ workspace has all M0/M0.5/M0.7 setup artifacts.

The workspace path is derived from this script's own location
(__file__'s parent.parent), so it can be invoked from any cwd.

Checks:
- legacy backups exist (windows-bindgen-legacy/, windows-cfggen-legacy/)
- new project skeletons exist with required files
- winmd-to-json bin/ exe exists and is executable (plus its build script)
- CLI entry points (windows-cj-bindgen, windows-cj-cfggen) are on PATH and respond to --version
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


def fail(msg: str) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def check_path_exists(path: Path, kind: str) -> None:
    if not path.exists():
        fail(f"missing {kind}: {path}")


def check_legacy_backups(workspace: Path) -> None:
    check_path_exists(workspace / "windows-bindgen-legacy", "legacy bindgen backup")
    check_path_exists(workspace / "windows-cfggen-legacy", "legacy cfggen backup")
    check_path_exists(workspace / "windows-bindgen-legacy" / "src", "legacy bindgen src/")
    check_path_exists(workspace / "windows-cfggen-legacy" / "src", "legacy cfggen src/")


def check_bindgen_py(workspace: Path) -> None:
    root = workspace / "windows-cj-bindgen-py"
    check_path_exists(root, "bindgen-py root")
    check_path_exists(root / "pyproject.toml", "bindgen-py pyproject.toml")
    check_path_exists(root / "src" / "windows_cj_bindgen" / "__init__.py", "bindgen-py __init__.py")
    check_path_exists(root / "src" / "windows_cj_bindgen" / "cli.py", "bindgen-py cli.py")
    check_path_exists(root / "tests" / "test_smoke.py", "bindgen-py smoke tests")


def check_cfggen_py(workspace: Path) -> None:
    root = workspace / "windows-cj-cfggen-py"
    check_path_exists(root, "cfggen-py root")
    check_path_exists(root / "pyproject.toml", "cfggen-py pyproject.toml")
    check_path_exists(root / "src" / "windows_cj_cfggen" / "__init__.py", "cfggen-py __init__.py")
    check_path_exists(root / "src" / "windows_cj_cfggen" / "cli.py", "cfggen-py cli.py")
    check_path_exists(root / "tests" / "test_smoke.py", "cfggen-py smoke tests")


def check_winmd_to_json(workspace: Path) -> None:
    root = workspace / "winmd-to-json"
    check_path_exists(root, "winmd-to-json root")
    check_path_exists(root / "Program.cs", "winmd-to-json Program.cs")
    check_path_exists(root / "winmd-to-json.csproj", "winmd-to-json csproj")
    check_path_exists(root / "LICENSE", "winmd-to-json LICENSE")
    check_path_exists(root / "README.md", "winmd-to-json README")
    check_path_exists(root / "scripts" / "build_and_publish.ps1", "winmd-to-json build script")
    check_path_exists(root / "bin" / "winmd-to-json.exe", "winmd-to-json published exe")


def check_cli_entry_points() -> None:
    if shutil.which("windows-cj-bindgen") is None:
        fail("windows-cj-bindgen entry point not on PATH; run pip install -e in bindgen-py")
    if shutil.which("windows-cj-cfggen") is None:
        fail("windows-cj-cfggen entry point not on PATH; run pip install -e in cfggen-py")

    for cmd in ("windows-cj-bindgen", "windows-cj-cfggen"):
        try:
            result = subprocess.run([cmd, "--version"], check=False, capture_output=True, text=True)
        except OSError as exc:
            fail(f"{cmd} --version could not be launched: {exc}")
            return  # unreachable (fail exits) but satisfies type checkers
        if result.returncode != 0:
            fail(f"{cmd} --version exited {result.returncode}: {result.stderr}")
        if not result.stdout.strip():
            fail(f"{cmd} --version produced empty stdout: {result.stdout!r}")


def main() -> None:
    workspace = Path(__file__).resolve().parent.parent
    print(f"workspace = {workspace}")

    check_legacy_backups(workspace)
    print("OK: legacy backups present")

    check_bindgen_py(workspace)
    print("OK: windows-cj-bindgen-py skeleton present")

    check_cfggen_py(workspace)
    print("OK: windows-cj-cfggen-py skeleton present")

    check_winmd_to_json(workspace)
    print("OK: winmd-to-json vendored and published")

    check_cli_entry_points()
    print("OK: CLI entry points reachable on PATH")

    print("\nAll M0+M0.5+M0.7 setup checks PASS.")


if __name__ == "__main__":
    main()
