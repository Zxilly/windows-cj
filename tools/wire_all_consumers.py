# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Discover and wire every windows_sys consumer module in the repo.

A *consumer* is any module (cjpm.toml + sources) that, transitively over its
local ``path =`` dependencies, imports at least one ``windows_sys.<NS>``
facade. windows_sys gates each namespace behind a Cangjie ``cfg`` variable
(default off), so each consumer must inject a complete
``override-compile-option`` ``--cfg`` string listing every variable, with the
namespaces it (transitively) needs turned on and the rest off.

This tool automates the two-step pilot flow for *all* consumers:

    NS = consumer_namespaces.analyze(module)          # transitive facade set
    select_features.emit + write override into module/cjpm.toml

Discovery rules (mirrors the task spec):
  * Walk every ``cjpm.toml`` under the repo root, skipping any path that
    contains a ``target`` component.
  * Skip windows_sys itself and any module that lives *inside* the
    windows_sys directory.
  * Skip nested ``bindings`` member modules (e.g. ``samples/.../bindings``):
    they are self-contained projection sets, built as members of their parent
    sample, not standalone consumers. (Their facade-import set is empty anyway
    because they carry their own generated bindings, so they would be skipped by
    the non-empty filter regardless; we exclude them explicitly to avoid
    rewriting a member module's cjpm.toml.)
  * A candidate becomes a consumer only if its transitive facade-import
    namespace set is non-empty.

``--dry-run`` prints the consumers that would be wired (with their namespace
count) and writes nothing.

Usage::

    uv run tools/wire_all_consumers.py --dry-run
    uv run tools/wire_all_consumers.py
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Reuse the validated pilot tools as libraries (same directory).
sys.path.insert(0, str(Path(__file__).resolve().parent))

import consumer_namespaces as cn  # noqa: E402
import select_features as sf  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
WINDOWS_SYS_DIR = (ROOT / "windows_sys").resolve()
CJPM_TOML = "cjpm.toml"


def discover_module_dirs() -> list[Path]:
    """Every module dir (containing cjpm.toml) that is a wiring candidate."""
    candidates: list[Path] = []
    for cjpm in sorted(ROOT.rglob(CJPM_TOML)):
        rel = cjpm.relative_to(ROOT)
        parts = rel.parts
        if "target" in parts:
            continue
        module_dir = cjpm.parent.resolve()
        # Skip the repo-root workspace cjpm.toml (it has no [package] consumer body).
        if module_dir == ROOT:
            continue
        # Skip windows_sys itself and anything nested inside it.
        if module_dir == WINDOWS_SYS_DIR or WINDOWS_SYS_DIR in module_dir.parents:
            continue
        # Skip nested `bindings` member modules.
        if module_dir.name == "bindings":
            continue
        candidates.append(module_dir)
    return candidates


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Wire override-compile-option into every windows_sys consumer."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only print which modules would be wired (and each ns count); write nothing.",
    )
    parser.add_argument(
        "--windows-sys-dir",
        type=Path,
        default=WINDOWS_SYS_DIR,
        help="windows_sys directory holding namespace-deps.json and impl/cfg.toml.",
    )
    args = parser.parse_args(argv)

    package_dir = args.windows_sys_dir.resolve()
    universe = cn.load_namespace_universe(package_dir)
    deps = sf.load_namespace_deps(package_dir)
    cfg_vars = sf.all_cfg_vars(package_dir)

    consumers: list[tuple[Path, list[str], int]] = []  # (dir, seed_ns_sorted, closure_size)
    skipped_empty: list[Path] = []

    for module_dir in discover_module_dirs():
        namespaces, _notes = cn.analyze(module_dir, universe, verbose=False)
        if not namespaces:
            skipped_empty.append(module_dir)
            continue
        seeds = sorted(namespaces)
        closure = sf.transitive_closure(seeds, deps)
        consumers.append((module_dir, seeds, len(closure)))

    consumers.sort(key=lambda t: str(t[0].relative_to(ROOT)))

    print(f"Discovered {len(consumers)} consumer(s); {len(skipped_empty)} candidate(s) had empty ns set.")
    print()
    print(f"{'MODULE':<48} {'SEED_NS':>7} {'CLOSURE':>7}")
    print("-" * 66)
    for module_dir, seeds, closure_size in consumers:
        rel = module_dir.relative_to(ROOT).as_posix()
        print(f"{rel:<48} {len(seeds):>7} {closure_size:>7}")

    if args.dry_run:
        print()
        print("(--dry-run: no files written.)")
        print()
        print("Skipped (empty facade-import set):")
        for module_dir in sorted(skipped_empty, key=lambda p: str(p.relative_to(ROOT))):
            print(f"  {module_dir.relative_to(ROOT).as_posix()}")
        return 0

    print()
    changed = 0
    for module_dir, seeds, _closure_size in consumers:
        enabled = sf.transitive_closure(seeds, deps)
        override_cfg = sf.build_override_cfg(enabled, cfg_vars)
        override_value = sf.build_override_compile_option(override_cfg)
        cjpm_path = module_dir / CJPM_TOML
        did_change = sf.write_override_to_cjpm(cjpm_path, override_value)
        rel = module_dir.relative_to(ROOT).as_posix()
        state = "updated" if did_change else "unchanged"
        if did_change:
            changed += 1
        print(f"  {state:<10} {rel} (closure={len(enabled)}/{len(cfg_vars)})")

    print()
    print(f"Done: {changed} cjpm.toml updated, {len(consumers) - changed} already current.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
