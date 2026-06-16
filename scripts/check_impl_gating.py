# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Structural completeness self-check for windows_sys impl cfg gating.

The generator structurally prefixes every top-level declaration it emits into the
``windows_sys.impl`` package with an ``@When[<namespace> == "on"]`` gate (see
``windows_bindgen/src/render_symbol.cj``). This is a render-time invariant, not a
source-text post-process, so a missed render point would silently emit an
ungated declaration that compiles under every feature selection (defeating the
opt-in shrinking). This script is the regression test for that invariant: it
scans the generated ``src/impl/*.cj`` chunks and asserts that **every** column-0
top-level declaration's annotation chain begins with an ``@When[...]`` gate.

Algorithm: a top-level declaration begins at a column-0 line that is either an
attribute (``@...``) or a declaration keyword (``public``/``private``/``extend``/
``func``/``type``). Such a line "starts" a declaration only when the preceding
non-blank line is a comment (``//``), a blank line, an import/package line, or a
closing brace at column 0 — i.e. it is not a continuation of an attribute chain
already in progress. For each declaration start the script walks the contiguous
column-0 ``@`` annotation block and requires its first line to be ``@When[``.
Any declaration whose chain does not begin with a gate is reported.

Exit code 0 = zero ungated top-level declarations. Non-zero = violations found.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMPL_DIR = ROOT / "windows_sys" / "src" / "impl"

# Column-0 keywords that begin a top-level declaration (after any attribute chain).
DECL_KEYWORDS = (
    "public ",
    "private ",
    "protected ",
    "internal ",
    "func ",
    "extend ",
    "extend<",
    "type ",
)


def is_decl_keyword(line: str) -> bool:
    return any(line.startswith(kw) for kw in DECL_KEYWORDS)


def is_attribute(line: str) -> bool:
    return line.startswith("@")


def is_when(line: str) -> bool:
    return line.startswith("@When[")


def starts_top_level_unit(line: str) -> bool:
    """A column-0 line that opens a top-level declaration unit."""
    if not line or line[0] in (" ", "\t"):
        return False
    return is_attribute(line) or is_decl_keyword(line)


def check_file(path: Path) -> list[tuple[int, str]]:
    """Return (line_number, line) for each ungated top-level declaration start."""
    lines = path.read_text(encoding="utf-8").splitlines()
    violations: list[tuple[int, str]] = []
    i = 0
    n = len(lines)
    in_unit = False  # currently inside a top-level decl's attribute/keyword chain
    while i < n:
        line = lines[i]
        if not starts_top_level_unit(line):
            # Body line (indented), blank, comment, brace, import, package, etc.
            # Any such line ends the current attribute/keyword chain.
            in_unit = False
            i += 1
            continue
        if in_unit:
            # Continuation of a chain that already opened (e.g. @C after @When,
            # or the keyword line after its attributes). Already accounted for by
            # the unit's first line; skip without re-checking.
            # A bare decl keyword line closes the chain.
            if is_decl_keyword(line):
                in_unit = False
            i += 1
            continue
        # This line opens a new top-level declaration unit. Its first line must be
        # the @When gate.
        if not is_when(line):
            violations.append((i + 1, line))
        # Open the chain; it stays open across following attribute lines until the
        # declaration keyword line (or a non-unit line) is reached.
        in_unit = not is_decl_keyword(line)
        i += 1
    return violations


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--impl-dir",
        type=Path,
        default=IMPL_DIR,
        help="Directory of generated impl chunks (default: windows_sys/src/impl).",
    )
    args = parser.parse_args(argv)

    impl_dir: Path = args.impl_dir
    if not impl_dir.exists():
        print(f"ERROR: impl directory not found: {impl_dir}", file=sys.stderr)
        return 2

    # The impl is emitted as one subpackage per namespace
    # (``src/impl/<ns_var>/symbols_<i>.cj``), so the chunks live one directory
    # deeper than the old monolithic ``src/impl/symbols_<i>.cj`` layout. A
    # recursive glob covers both layouts.
    files = sorted(impl_dir.glob("**/symbols_*.cj"))
    if not files:
        print(f"ERROR: no symbols_*.cj chunks under {impl_dir}", file=sys.stderr)
        return 2

    total_decls_checked = 0
    total_violations = 0
    for path in files:
        # Count gated decls for a positive signal, and collect violations.
        text = path.read_text(encoding="utf-8").splitlines()
        gated = sum(1 for ln in text if is_when(ln))
        total_decls_checked += gated
        violations = check_file(path)
        # Report the path relative to the impl dir so per-namespace subpackage
        # chunks (which all share the name ``symbols_<i>.cj``) are distinguishable.
        try:
            label = path.relative_to(impl_dir).as_posix()
        except ValueError:
            label = path.name
        for line_no, line in violations:
            total_violations += 1
            print(f"UNGATED: {label}:{line_no}: {line}")

    print(
        f"Scanned {len(files)} impl chunks, {total_decls_checked} gated top-level "
        f"declarations, {total_violations} ungated top-level declarations."
    )
    if total_violations:
        print("FAIL: found ungated top-level declarations.", file=sys.stderr)
        return 1
    print("OK: 0 ungated top-level declarations.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
