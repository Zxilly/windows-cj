#!/usr/bin/env python3
"""Unified quality gate for the active windows-cj workspace.

Default mode is the full non-UI gate:

    python scripts/run_windows_quality_gate.py

Use quick mode for static/script checks only:

    python scripts/run_windows_quality_gate.py --mode quick

The WinUI demo smoke opens UI and is therefore opt-in:

    python scripts/run_windows_quality_gate.py --include-winui-demo-smoke
"""

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Sequence


ROOT = Path(__file__).resolve().parents[1]
DEMO_ROOT = ROOT.parent / "windows-cj-demo"
DEFAULT_WORKSPACE_TIMEOUT_SECONDS = 240
DEFAULT_CODEGEN_TIMEOUT_SECONDS = 300


@dataclass(frozen=True)
class Step:
    name: str
    command: list[str]
    cwd: Path = ROOT
    env: dict[str, str] = field(default_factory=dict)


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the windows-cj quality gate.")
    parser.add_argument(
        "--mode",
        choices=("quick", "full"),
        default="full",
        help="quick runs static/script checks; full also runs generated subset gates, workspace tests, and macro fixtures.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Print the planned gate commands without running them.")
    parser.add_argument(
        "--workspace-member",
        action="append",
        default=[],
        metavar="MEMBER",
        help="Limit full-mode workspace tests to a member. Can be repeated.",
    )
    parser.add_argument(
        "--skip-workspace-build",
        action="store_true",
        help="Forward --skip-build to run_windows_workspace_tests.py in full mode.",
    )
    parser.add_argument(
        "--workspace-timeout-seconds",
        type=positive_int,
        default=DEFAULT_WORKSPACE_TIMEOUT_SECONDS,
        help="External watchdog timeout for each workspace build/test step.",
    )
    parser.add_argument(
        "--codegen-timeout-seconds",
        type=positive_int,
        default=DEFAULT_CODEGEN_TIMEOUT_SECONDS,
        help="External watchdog timeout for each generated subset gate build/regenerate step.",
    )
    parser.add_argument(
        "--skip-codegen-regenerate",
        action="store_true",
        help="Skip the full-mode temporary windows-common regeneration/diff step.",
    )
    parser.add_argument(
        "--macro-timeout-seconds",
        type=positive_int,
        help="Override WINDOWS_CJ_MACRO_CHECK_TIMEOUT_SECONDS for the macro fixture step.",
    )
    parser.add_argument(
        "--include-winui-demo-smoke",
        action="store_true",
        help="Also run ../windows-cj-demo/tools/smoke_winui3.py. This may open UI.",
    )
    return parser.parse_args(argv)


def python_sources(root: Path = ROOT) -> list[Path]:
    source_roots = [
        root / "scripts",
        root / "windows-interface" / "scripts",
    ]
    demo_tools = root.parent / "windows-cj-demo" / "tools"
    if demo_tools.exists():
        source_roots.append(demo_tools)

    sources: list[Path] = []
    seen: set[Path] = set()
    for source_root in source_roots:
        if not source_root.exists():
            continue
        for path in sorted(source_root.rglob("*.py")):
            if "__pycache__" in path.parts:
                continue
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            sources.append(path)
    return sources


def script(path: str) -> str:
    return str(ROOT / path)


def build_steps(args: argparse.Namespace) -> list[Step]:
    py_files = python_sources(ROOT)
    if not py_files:
        raise RuntimeError("no Python sources found for py_compile")

    steps = [
        Step(
            "py_compile",
            [sys.executable, "-m", "py_compile", *[str(path) for path in py_files]],
        ),
        Step(
            "windows-common codegen gate",
            [
                sys.executable,
                script("scripts/check_windows_common_codegen.py"),
                "--mode",
                args.mode,
                "--timeout-seconds",
                str(args.codegen_timeout_seconds),
                *(["--skip-regenerate"] if args.skip_codegen_regenerate else []),
            ],
        ),
        Step("workspace setup audit", [sys.executable, script("scripts/check_workspace_setup.py")]),
        Step("ignored results audit", [sys.executable, script("scripts/check_ignored_results.py")]),
        Step("ABI ownership audit", [sys.executable, script("scripts/check_abi_ownership.py")]),
    ]

    if args.mode == "full":
        workspace_command = [
            sys.executable,
            script("scripts/run_windows_workspace_tests.py"),
            "--timeout-seconds",
            str(args.workspace_timeout_seconds),
        ]
        if args.skip_workspace_build:
            workspace_command.append("--skip-build")
        workspace_command.extend(args.workspace_member)
        steps.append(Step("workspace tests", workspace_command))

        macro_env: dict[str, str] = {}
        if args.macro_timeout_seconds is not None:
            macro_env["WINDOWS_CJ_MACRO_CHECK_TIMEOUT_SECONDS"] = str(args.macro_timeout_seconds)
        steps.append(
            Step(
                "macro fixtures",
                [sys.executable, script("windows-interface/scripts/check_macros.py")],
                env=macro_env,
            )
        )

    if args.include_winui_demo_smoke:
        smoke = DEMO_ROOT / "tools" / "smoke_winui3.py"
        steps.append(Step("WinUI demo smoke", [sys.executable, str(smoke)], cwd=DEMO_ROOT))

    return steps


def display_command(command: Sequence[str]) -> str:
    if os.name == "nt":
        return subprocess.list2cmdline(list(command))
    return shlex.join(command)


def merged_env(step: Step, parent_env: dict[str, str] | None = None) -> dict[str, str]:
    env = dict(os.environ if parent_env is None else parent_env)
    env["cjHeapSize"] = "32GB"
    env.update(step.env)
    return env


def validate_steps(steps: Sequence[Step]) -> None:
    for step in steps:
        if not step.cwd.exists():
            raise RuntimeError(f"{step.name} cwd does not exist: {step.cwd}")
        for token in step.command[1:]:
            if not token.endswith(".py"):
                continue
            path = Path(token)
            if path.is_absolute() and not path.exists():
                raise RuntimeError(f"{step.name} script does not exist: {path}")


def run_step(step: Step, *, dry_run: bool) -> int:
    print(f"\n== {step.name} ==")
    print(f"+ {display_command(step.command)}")
    if dry_run:
        print("# dry-run: skipped")
        return 0

    started = time.perf_counter()
    result = subprocess.run(step.command, cwd=step.cwd, env=merged_env(step))
    elapsed = time.perf_counter() - started
    print(f"# {step.name} finished in {elapsed:.2f}s with exit code {result.returncode}", flush=True)
    return result.returncode


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        steps = build_steps(args)
        validate_steps(steps)
    except RuntimeError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 2

    print(f"workspace = {ROOT}")
    print(f"mode = {args.mode}")
    if not args.include_winui_demo_smoke:
        print("WinUI demo smoke = skipped (use --include-winui-demo-smoke to run it)")

    for step in steps:
        result = run_step(step, dry_run=args.dry_run)
        if result != 0:
            print(f"FAIL: {step.name} exited with {result}", file=sys.stderr)
            return result

    action = "planned" if args.dry_run else "completed"
    print(f"\nOK: quality gate {action} successfully ({len(steps)} steps)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
