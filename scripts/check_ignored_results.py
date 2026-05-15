#!/usr/bin/env python3
"""Static audit: ignored HRESULT / Result.ok() values in .cj sources.

`HRESULT.ok()` (and the related `WIN32_ERROR.ok()`, `NTSTATUS.ok()`,
`Result<T>.ok()`) returns a value that the caller is responsible for
consuming. A statement-only call like

    foo.ok()

drops that value on the floor, silently swallowing errors. The
correct shape is either a tail expression (last expression of a block,
returned to the caller), a `match` / `let` / `return` over the
result, or `.unwrap()` / `.check()` for the throwing variants.

This audit runs over the active workspace `.cj` sources and reports
any standalone `.ok()` statement that is followed by another statement
inside the same block (so it cannot be the implicit return).

The heuristic is intentionally conservative: tail expressions are
allowed, expressions inside `match (...)`, `if (...)`, etc. are not
matched at all, and any `let`/`var`/`return`/`throw` prefix exempts
the line. The check should not have false positives but it has the
following documented blind spots that future audits should harden:

  - `.ok()` as the last statement of one branch of an `if`/`else`
    (the next line is `}`, so the tail-position guard accepts it
    even though execution continues past the branch).
  - `.ok()` as the last statement of a `try` or `match` arm whose
    enclosing block continues with more statements.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ACTIVE_WORKSPACE_MEMBERS = (
    "windows-metadata",
    "windows-libloading",
    "windows-result",
    "windows-strings",
    "windows-interface",
    "windows-implement",
    "windows-core",
    "windows-polyfill",
    "windows-runtime",
    "windows-threading",
    "windows-version",
    "windows-targets",
    "windows-registry",
    "windows-services",
    "windows-common",
    "windows-winui3",
    "windows",
)


# Generic argument lists may nest one level: `foo<Array<GUID>>().ok()`.
_GENERIC = r"<(?:[^<>]|<[^<>]*>)*>"
STATEMENT_OK_RE = re.compile(
    rf"^([A-Za-z_][\w]*(?:{_GENERIC})?(?:\.[A-Za-z_]\w*(?:{_GENERIC})?(?:\([^()]*\))?)*)\.ok\(\)\s*(?://.*)?$"
)


def next_meaningful_line(lines: list[str], start: int) -> str:
    j = start
    while j < len(lines):
        candidate = lines[j].strip()
        if not candidate or candidate.startswith("//"):
            j += 1
            continue
        return candidate
    return ""


def scan_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    findings: list[str] = []
    for index, raw in enumerate(lines):
        stripped = raw.strip()
        if not stripped.endswith(".ok()"):
            # accept "</ comment.ok())" etc. without further work
            continue
        if not STATEMENT_OK_RE.match(stripped):
            continue
        successor = next_meaningful_line(lines, index + 1)
        # Tail expression: the next meaningful character closes the block.
        if successor.startswith("}"):
            continue
        findings.append(f"{path}:{index + 1}: ignored Result.ok() value")
    return findings


def audit_workspace(workspace: Path) -> list[str]:
    findings: list[str] = []
    for member in ACTIVE_WORKSPACE_MEMBERS:
        src = workspace / member / "src"
        if not src.exists():
            continue
        for path in src.rglob("*.cj"):
            findings.extend(scan_file(path))
    return findings


def main() -> None:
    workspace = Path(__file__).resolve().parent.parent
    findings = audit_workspace(workspace)
    if findings:
        print("FAIL: ignored HRESULT/Result.ok() value(s):", file=sys.stderr)
        for entry in findings:
            print(f"  {entry}", file=sys.stderr)
        sys.exit(1)
    print(f"workspace = {workspace}")
    print("OK: no ignored HRESULT/Result.ok() values in active .cj sources")


if __name__ == "__main__":
    main()
