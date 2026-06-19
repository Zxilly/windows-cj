#!/usr/bin/env python3
"""Regenerate the checked-in windows_sys package in place.

windows_sys is a generated package: its sources are produced by
windows_bindgen from the bundled raw `.winmd` metadata under ``winmd/`` for the
exact feature set recorded in ``windows_sys/codegen-manifest.json``
(``requested_features``). After any change to the generator
(``windows_bindgen/src``) that affects windows_sys's output, the checked-in
package must be regenerated so it matches the generator again — otherwise the
``scripts/check_windows_sys_codegen.py --mode full`` gate fails.

This script performs that in-place regeneration, reusing the exact input
conventions of the gate's ``generator_command``:

  * generator binary:  windows_bindgen/target/release/bin/main.exe
  * raw metadata:      every bundled ``winmd/*.winmd`` (sorted), parsed natively
  * features:          ``requested_features`` from the checked-in manifest, in order
  * runtime heap:      cjHeapSize=32GB (the 729-package workspace OOMs on the
                       256MB cjpm default; see the project notes)

The generator rewrites ``windows_sys/`` (``--clean``) together with a fresh
``codegen-manifest.json`` (file list + hashes), then restores the empty
``cjpm.lock`` ignored by the manifest checker. Run the codegen gate afterwards
to verify, e.g.::

    python scripts/regenerate_windows_sys.py
    python scripts/check_windows_sys_codegen.py --mode full

Usage::

    python scripts/regenerate_windows_sys.py [--skip-build] [--timeout-seconds N]
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

import windows_sys_manifest

ROOT = Path(__file__).resolve().parents[1]
WINDOWS_SYS = ROOT / "windows_sys"
WINMD_ROOT = ROOT / "winmd"
WINDOWS_BINDGEN = ROOT / "windows_bindgen"
# windows_bindgen is a dependency-free executable package. It is built in place
# (cwd=windows_bindgen) rather than via a root `cjpm build -m windows_bindgen`,
# because the workspace currently has nested members (e.g. windows_canvas and
# windows_canvas/bindings, and every samples/*/bindings under its sample) which
# cjpm rejects at the workspace level ("member modules are not allowed to be
# nested"). The in-place build skips that workspace validation. The produced
# generator binary is bin/main.exe (named after the package's main.cj entry).
GENERATOR_BINARY = WINDOWS_BINDGEN / "target" / "release" / "bin" / "main.exe"
WINDOWS_SYS_LOCK_CONTENT = "version = 0\n\n[requires]\n"
# The cfg-gated windows_sys compilation must use dev_perf_ci: nightly has a
# slow cfg-evaluation bug that dev_perf has fixed. The generator itself is a
# small dependency-light executable, but its source uses stdx.encoding.json; the
# dev_perf_ci toolchain ships no stdx component, so an ABI-compatible stdx path
# is injected for the generator build only (the produced binary is dependency
# free, and the actual gated windows_sys build is pure dev_perf_ci).
TOOLCHAIN = "dev_perf_ci"


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def stdx_static_path() -> str | None:
    """Resolve an ABI-compatible static stdx path for the generator build.

    dev_perf_ci has no stdx component, so reuse another installed toolchain's
    static stdx (preferring the active toolchain's). Honour an explicit
    CANGJIE_STDX_PATH_STATIC if the caller already set one.
    """
    existing = os.environ.get("CANGJIE_STDX_PATH_STATIC")
    if existing and (Path(existing) / "stdx").exists():
        return existing
    stdx_root = Path.home() / ".cjv" / "stdx"
    if not stdx_root.exists():
        return None
    candidates = [stdx_root / "tmp_build" / "static", *sorted(stdx_root.glob("*/static"))]
    for candidate in candidates:
        if (candidate / "stdx").exists():
            return str(candidate)
    return None


def command_env() -> dict[str, str]:
    env = os.environ.copy()
    env["cjHeapSize"] = "32GB"
    stdx = stdx_static_path()
    if stdx is not None:
        env["CANGJIE_STDX_PATH_STATIC"] = stdx
    return env


def run(command: list[str], *, timeout_seconds: int, cwd: Path = ROOT) -> None:
    print(f"+ {subprocess.list2cmdline(command)}  (cwd={cwd})", flush=True)
    try:
        result = subprocess.run(command, cwd=cwd, env=command_env(), timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        fail(f"command timed out after {timeout_seconds}s: {subprocess.list2cmdline(command)}")
        return
    if result.returncode != 0:
        fail(f"command failed with exit code {result.returncode}: {subprocess.list2cmdline(command)}")


def bundled_winmd_files() -> list[Path]:
    if not WINMD_ROOT.exists():
        fail(f"missing WinMD source directory: {WINMD_ROOT}")
    sources = sorted(WINMD_ROOT.glob("*.winmd"))
    if not sources:
        fail(f"no .winmd files found under {WINMD_ROOT}")
    return sources


def requested_features() -> list[str]:
    manifest = windows_sys_manifest.load_manifest(WINDOWS_SYS)
    features = windows_sys_manifest.requested_features(manifest, require_nonempty=True)
    return features


def build_generator(timeout_seconds: int) -> None:
    # Build in place (cwd=windows_bindgen) to bypass the workspace-level nested
    # member validation; see the GENERATOR_BINARY note above.
    run(["cjv", "run", TOOLCHAIN, "cjpm", "build"], timeout_seconds=timeout_seconds, cwd=WINDOWS_BINDGEN)
    if not GENERATOR_BINARY.exists():
        fail(f"generator binary was not produced: {GENERATOR_BINARY}")


def regenerate(timeout_seconds: int) -> None:
    features = requested_features()
    winmd_inputs = bundled_winmd_files()
    command = ["cjv", "run", TOOLCHAIN, str(GENERATOR_BINARY), "--common", "--clean", "--out", str(WINDOWS_SYS)]
    command += [str(path) for path in winmd_inputs]
    for feature in features:
        command += ["--feature", feature]
    print(
        f"Regenerating windows_sys: {len(features)} requested features, "
        f"{len(winmd_inputs)} bundled .winmd inputs",
        flush=True,
    )
    run(command, timeout_seconds=timeout_seconds)
    (WINDOWS_SYS / "cjpm.lock").write_text(WINDOWS_SYS_LOCK_CONTENT, encoding="utf-8")


def rewire_consumers(timeout_seconds: int) -> None:
    """Refresh every consumer's cfg from the freshly regenerated dependency graph.

    The per-namespace closure each consumer needs is derived entirely from the
    generator's output (``namespace-deps.json``) plus the consumer's own
    windows_sys imports — nobody hand-specifies namespaces. Running this as the
    final regeneration step keeps every consumer's ``override-compile-option`` in
    lockstep with the graph, so a regeneration that adds/moves cross-namespace
    references can never leave a consumer with a stale, now-incomplete cfg (the
    failure mode that broke fresh consumer builds before this was automated).
    """
    wire = ROOT / "tools" / "wire_all_consumers.py"
    print("Re-wiring all windows_sys consumers from the regenerated graph", flush=True)
    run([sys.executable, str(wire)], timeout_seconds=timeout_seconds)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Regenerate the checked-in windows_sys package in place.")
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="Reuse the existing generator binary instead of rebuilding windows_bindgen first.",
    )
    parser.add_argument(
        "--timeout-seconds",
        type=int,
        default=1200,
        help="Per-command watchdog (generator build and regeneration each get this budget).",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.skip_build:
        if not GENERATOR_BINARY.exists():
            fail(f"--skip-build requires an existing generator binary: {GENERATOR_BINARY}")
    else:
        build_generator(args.timeout_seconds)
    regenerate(args.timeout_seconds)
    rewire_consumers(args.timeout_seconds)
    manifest = windows_sys_manifest.load_manifest(WINDOWS_SYS)
    files = windows_sys_manifest.manifest_files(manifest)
    symbols = manifest.get("selected_symbols", [])
    print(
        f"OK: regenerated windows_sys — {len(files)} files, {len(symbols)} selected symbols. "
        "Verify with: python scripts/check_windows_sys_codegen.py --mode full",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
