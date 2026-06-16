# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Compute the set of windows_sys namespaces a consumer module needs.

A consumer's ``override-compile-option`` (see ``select_features.py --emit-override``)
applies from the *entry module* to **every dependency package**. Therefore the set
of namespaces a consumer must enable is the transitive union of the facade imports
found in:

  * the consumer module's own ``.cj`` source, AND
  * every non-windows_sys package it depends on (recursively, following the
    ``path = "..."`` entries in each ``cjpm.toml`` ``[dependencies]`` table).

Recursion stops at ``windows_sys`` itself (it is the gated library, not a
consumer) and at packages that are not local path dependencies.

For every ``import windows_sys.<A>.<B>...`` statement we map the imported
package to its WinRT/Win32 namespace and emit the de-duplicated set. That set is
fed to ``select_features.py --emit-override`` (which adds the transitive
namespace-dependency closure on top).

Namespace mapping (facade package suffix -> namespace):
  * suffix starting with ``Microsoft`` or ``Native``  -> namespace == suffix
  * otherwise (WinRT short names and ``Win32.*``)      -> namespace == ``Windows.`` + suffix
An import path may end in a *symbol* name rather than a package (e.g.
``windows_sys.Foundation.Uri`` imports the symbol ``Uri`` from package
``windows_sys.Foundation``). We therefore match the *longest* dotted prefix that
is a known namespace, using the universe of namespaces declared in
``namespace-deps.json``.

Usage::

    python tools/consumer_namespaces.py windows_foundation
    python tools/consumer_namespaces.py samples/reactor/windows_reactor_gallery --verbose

Output: one namespace per line (sorted), suitable to pass (comma-joined) to
``select_features.py --emit-override``. ``--csv`` prints them comma-joined on one
line; ``--emit-override-cmd`` prints the ready-to-run select_features command.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WINDOWS_SYS_DIR = ROOT / "windows_sys"
NAMESPACE_DEPS_NAME = "namespace-deps.json"
CJPM_TOML = "cjpm.toml"
SRC_DIR = "src"
WINDOWS_SYS_PKG = "windows_sys"

# `import windows_sys.A.B.C`            (single symbol or sub-package)
# `import windows_sys.A.B as alias`
# `import windows_sys.A.B.{X, Y}`       (member list; we only need the package)
# Leading whitespace allowed; statement may span lines for `{...}` but the package
# path is always fully on the `import` line up to `{`, `as`, or end-of-line.
IMPORT_RE = re.compile(
    r"^\s*(?:public\s+|protected\s+|internal\s+|private\s+)?import\s+"
    r"windows_sys\.(?P<path>[A-Za-z_][A-Za-z0-9_.]*)"
)


def fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_namespace_universe(windows_sys_dir: Path) -> set[str]:
    path = windows_sys_dir / NAMESPACE_DEPS_NAME
    if not path.exists():
        fail(
            f"missing {NAMESPACE_DEPS_NAME} under {windows_sys_dir}. Regenerate "
            "windows_sys with the current generator."
        )
    data = json.loads(path.read_text(encoding="utf-8"))
    universe: set[str] = set(data)
    for targets in data.values():
        universe.update(targets)
    return universe


def suffix_to_namespace(suffix: str) -> str:
    """Map a facade-package suffix (path after windows_sys.) to a namespace.

    `Foundation`            -> `Windows.Foundation`
    `Win32.System.Registry` -> `Windows.Win32.System.Registry`
    `Microsoft.UI.Xaml`     -> `Microsoft.UI.Xaml`
    `Native.AppRuntime`     -> `Native.AppRuntime`
    """
    head = suffix.split(".", 1)[0]
    if head in ("Microsoft", "Native"):
        return suffix
    return f"Windows.{suffix}"


def import_path_to_namespace(path: str, universe: set[str]) -> str | None:
    """Longest dotted prefix of `path` whose mapped namespace is in the universe."""
    segments = path.split(".")
    for length in range(len(segments), 0, -1):
        candidate = suffix_to_namespace(".".join(segments[:length]))
        if candidate in universe:
            return candidate
    return None


def parse_dependency_paths(cjpm_path: Path) -> list[tuple[str, Path]]:
    """Return (dep_name, resolved_dir) for every local `path =` dependency.

    Minimal line-oriented parse of the flat cjpm.toml the repo uses: only entries
    inside the [dependencies] table that carry a `path = "..."` are followed.
    """
    deps: list[tuple[str, Path]] = []
    in_deps = False
    base = cjpm_path.parent
    name_re = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{(?P<body>.*)\}\s*$')
    path_re = re.compile(r'path\s*=\s*"([^"]+)"')
    for raw in cjpm_path.read_text(encoding="utf-8").splitlines():
        stripped = raw.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_deps = stripped == "[dependencies]"
            continue
        if not in_deps or not stripped or stripped.startswith("#"):
            continue
        m = name_re.match(raw)
        if not m:
            continue
        pm = path_re.search(m.group("body"))
        if not pm:
            continue
        dep_dir = (base / pm.group(1)).resolve()
        deps.append((m.group(1), dep_dir))
    return deps


def collect_cj_imports(module_dir: Path) -> set[str]:
    """All `import windows_sys.<path>` package-path strings under module_dir/src.

    Skips windows_sys.impl (the gated implementation package, not a facade) and
    test files only if explicitly excluded (we include tests by default: their
    imports still drive what must compile when the consumer's tests build)."""
    src = module_dir / SRC_DIR
    search_root = src if src.exists() else module_dir
    found: set[str] = set()
    for cj in search_root.rglob("*.cj"):
        for line in cj.read_text(encoding="utf-8", errors="replace").splitlines():
            m = IMPORT_RE.match(line)
            if not m:
                continue
            path = m.group("path")
            if path == "impl" or path.startswith("impl."):
                continue
            found.add(path)
    return found


def analyze(
    entry_dir: Path, universe: set[str], verbose: bool
) -> tuple[set[str], list[str]]:
    """Walk entry module + transitive non-windows_sys path deps; collect namespaces."""
    namespaces: set[str] = set()
    notes: list[str] = []
    visited: set[Path] = set()
    queue: list[tuple[Path, str]] = [(entry_dir.resolve(), entry_dir.name)]

    while queue:
        module_dir, label = queue.pop()
        if module_dir in visited:
            continue
        visited.add(module_dir)

        cjpm = module_dir / CJPM_TOML
        if not cjpm.exists():
            notes.append(f"  skip (no cjpm.toml): {label} [{module_dir}]")
            continue

        import_paths = collect_cj_imports(module_dir)
        local_ns: set[str] = set()
        for path in sorted(import_paths):
            ns = import_path_to_namespace(path, universe)
            if ns is None:
                notes.append(f"  WARN unmapped facade import in {label}: windows_sys.{path}")
                continue
            local_ns.add(ns)
        if local_ns:
            notes.append(f"  {label}: {len(local_ns)} ns -> {', '.join(sorted(local_ns))}")
        namespaces |= local_ns

        for dep_name, dep_dir in parse_dependency_paths(cjpm):
            if dep_name == WINDOWS_SYS_PKG:
                continue  # the gated library; not a consumer of itself
            if dep_dir == WINDOWS_SYS_DIR.resolve():
                continue
            if dep_dir not in visited:
                queue.append((dep_dir, dep_name))

    return namespaces, notes


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compute windows_sys namespaces a consumer module needs (transitively)."
    )
    parser.add_argument(
        "consumer",
        help="Path to the consumer module directory (containing cjpm.toml), relative to repo root or absolute.",
    )
    parser.add_argument(
        "--windows-sys-dir",
        type=Path,
        default=WINDOWS_SYS_DIR,
        help=f"windows_sys directory holding {NAMESPACE_DEPS_NAME} (default: {WINDOWS_SYS_DIR}).",
    )
    parser.add_argument("--verbose", action="store_true", help="Print per-module breakdown to stderr.")
    parser.add_argument("--csv", action="store_true", help="Print namespaces comma-joined on one line.")
    parser.add_argument(
        "--emit-override-cmd",
        action="store_true",
        help="Print a ready-to-run select_features.py --emit-override command.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    entry = Path(args.consumer)
    if not entry.is_absolute():
        entry = (ROOT / entry).resolve()
    if not entry.exists():
        fail(f"consumer directory not found: {entry}")
    universe = load_namespace_universe(args.windows_sys_dir.resolve())

    namespaces, notes = analyze(entry, universe, args.verbose)

    if args.verbose:
        print("module breakdown:", file=sys.stderr)
        for note in notes:
            print(note, file=sys.stderr)
        print(f"total namespaces (pre-closure): {len(namespaces)}", file=sys.stderr)

    ordered = sorted(namespaces)
    if args.emit_override_cmd:
        print(
            "python tools/select_features.py --emit-override "
            + ",".join(ordered)
        )
    elif args.csv:
        print(",".join(ordered))
    else:
        for ns in ordered:
            print(ns)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
