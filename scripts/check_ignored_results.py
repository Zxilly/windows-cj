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
inside the same block (so it cannot be the implicit return). It also
rejects `let _ = value.ok()`, which explicitly discards the returned
`Result`.

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
IGNORED_OK_ASSIGN_RE = re.compile(r"^let\s+_\s*=.*\.ok\(\)\s*(?://.*)?$")


def next_meaningful_line(lines: list[str], start: int) -> str:
    j = start
    while j < len(lines):
        candidate = lines[j].strip()
        if not candidate or candidate.startswith("//"):
            j += 1
            continue
        return candidate
    return ""


def scan_lines(label: str, lines: list[str]) -> list[str]:
    findings: list[str] = []
    for index, raw in enumerate(lines):
        stripped = raw.strip()
        if IGNORED_OK_ASSIGN_RE.match(stripped):
            findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
            continue
        if not STATEMENT_OK_RE.match(stripped):
            continue
        successor = next_meaningful_line(lines, index + 1)
        # Tail expression: the next meaningful character closes the block.
        if successor.startswith("}"):
            continue
        findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
    return findings


def scan_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return scan_lines(str(path), text.splitlines())


def self_check() -> None:
    if not scan_lines("<self>", ["hr.ok() // ignored", "println(\"after\")"]):
        raise AssertionError("standalone .ok() with trailing comment must be rejected")
    if not scan_lines("<self>", ["let _ = hr.ok() // ignored"]):
        raise AssertionError("discarded .ok() assignment with trailing comment must be rejected")
    if scan_lines("<self>", ["hr.ok() // tail", "}"]):
        raise AssertionError("tail-position standalone .ok() should remain allowed")


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
    try:
        self_check()
    except AssertionError as error:
        print(f"FAIL: check_ignored_results self-check failed: {error}", file=sys.stderr)
        sys.exit(1)
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
