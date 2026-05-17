#!/usr/bin/env python3
"""Static audit for owned ABI pointer lifetime invariants.

The checks here intentionally stay conservative. They cover the high-risk COM
shapes used in the active workspace without attempting to parse all Cangjie:

* raw QueryInterface helpers must either transfer the returned reference to a
  wrapper/return value or release it deterministically;
* direct vtable QueryInterface calls must stay confined to known helper or
  forwarding modules;
* generated/interface owned fromAbiTake constructors must route through the
  shared InterfaceWrapperBase takeOwnership guard, so null success out-pointers
  become E_POINTER instead of live wrappers around null.
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

QUERY_MATCH_RE = re.compile(r"match\s*\([^\n]*(?:queryInterfaceRaw|queryInterfaceAs|comQueryInterfaceRaw)")
SOME_CASE_RE = re.compile(r"^(\s*)case\s+Some\(([A-Za-z_][A-Za-z0-9_]*)\)\s*=>", re.MULTILINE)
DIRECT_QUERY_INTERFACE_RE = re.compile(r"\.QueryInterface\s*\(")
FROM_ABI_TAKE_RE = re.compile(
    r"public\s+static\s+func\s+fromAbiTake\s*\(\s*raw:\s*CPointer<Unit>\s*\)[^{]*\{",
    re.MULTILINE,
)

# These files contain low-level helper implementations or COM forwarding thunks.
# New direct vtable QueryInterface calls should normally go through
# queryInterfaceRaw/queryInterfaceAs and will need an explicit review here.
DIRECT_QUERY_INTERFACE_ALLOWED_FILES = {
    "windows-result/src/com.cj",
    "windows-interface/src/interface_wrapper.cj",
    "windows-implement/src/composable_activation.cj",
    "windows-implement/src/weak_ref_count.cj",
    "windows-core/src/com_interface.cj",
    "windows-core/src/marshaler.cj",
    "windows-core/src/weak_ref_count.cj",
}


def rel(path: Path, workspace: Path) -> str:
    return path.relative_to(workspace).as_posix()


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def cj_sources(workspace: Path, *, production_only: bool) -> list[Path]:
    sources: list[Path] = []
    for member in ACTIVE_WORKSPACE_MEMBERS:
        src = workspace / member / "src"
        if not src.exists():
            continue
        for path in src.rglob("*.cj"):
            if production_only and path.name.endswith("_test.cj"):
                continue
            sources.append(path)
    return sorted(sources)


def extract_braced_block(text: str, start: int) -> str:
    brace = text.find("{", start)
    if brace < 0:
        fail("internal parser error: expected a braced block")

    depth = 0
    index = brace
    while index < len(text):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[brace + 1 : index]
        index += 1
    fail("internal parser error: unterminated braced block")


def case_body_until_next_sibling(block: str, match: re.Match[str]) -> str:
    indent = len(match.group(1))
    start = match.end()
    next_case_re = re.compile(r"^(\s*)case\s+", re.MULTILINE)
    for next_case in next_case_re.finditer(block, start):
        if len(next_case.group(1)) <= indent:
            return block[start : next_case.start()]
    return block[start:]


def query_result_consumed(body: str, name: str) -> bool:
    patterns = (
        rf"\breturn\b[^\n;]*\b{name}\b",
        rf"\b(?:Some|Ok)\s*\([^)]*\b{name}\b",
        rf"=\s*Some\s*\([^)]*\b{name}\b",
        rf"\b{name}\s*\.\s*(?:close|intoAbi|release)\s*\(",
        rf"\b(?:interfaceHandleReleaseRaw|comReleaseRaw|releaseRaw)\s*\(\s*{name}\s*\)",
        rf"\b(?:takeFromAbi|releasePointer)\s*\(\s*{name}\s*\)",
        rf"\.\s*(?:fromAbiTake|fromAbiTakeWinrtHandle)\s*\(\s*{name}\s*\)",
        rf"\b(?:InterfaceHandle|ComHandle)<[^\n>]+>\.fromAbiTake\s*\(\s*{name}\b",
    )
    return any(re.search(pattern, body, re.DOTALL) for pattern in patterns)


def check_query_interface_results_consumed(workspace: Path) -> None:
    findings: list[str] = []
    for source in cj_sources(workspace, production_only=True):
        text = source.read_text(encoding="utf-8")
        for query_match in QUERY_MATCH_RE.finditer(text):
            block = extract_braced_block(text, query_match.start())
            for some_case in SOME_CASE_RE.finditer(block):
                name = some_case.group(2)
                body = case_body_until_next_sibling(block, some_case)
                if query_result_consumed(body, name):
                    continue
                line = text[: query_match.start()].count("\n") + block[: some_case.start()].count("\n") + 1
                findings.append(
                    f"{rel(source, workspace)}:{line}: QueryInterface result {name!r} "
                    "must be returned/wrapped or closed"
                )
    if findings:
        print("FAIL: QueryInterface result ownership audit failed:", file=sys.stderr)
        for finding in findings:
            print(f"  {finding}", file=sys.stderr)
        sys.exit(1)


def check_direct_query_interface_call_sites(workspace: Path) -> None:
    findings: list[str] = []
    for source in cj_sources(workspace, production_only=True):
        text = source.read_text(encoding="utf-8")
        if not DIRECT_QUERY_INTERFACE_RE.search(text):
            continue
        relative = rel(source, workspace)
        if relative in DIRECT_QUERY_INTERFACE_ALLOWED_FILES:
            continue
        for line_number, line in enumerate(text.splitlines(), start=1):
            if DIRECT_QUERY_INTERFACE_RE.search(line):
                findings.append(
                    f"{relative}:{line_number}: direct QueryInterface calls must use "
                    "queryInterfaceRaw/queryInterfaceAs or be added as a narrow helper exception"
                )
    if findings:
        print("FAIL: direct QueryInterface call site audit failed:", file=sys.stderr)
        for finding in findings:
            print(f"  {finding}", file=sys.stderr)
        sys.exit(1)


def check_interface_take_ownership_guard(workspace: Path) -> None:
    interface_wrapper = workspace / "windows-interface" / "src" / "interface_wrapper.cj"
    text = interface_wrapper.read_text(encoding="utf-8")
    guard = extract_braced_block(text, text.find("func requireOwnedInterfaceRaw"))
    if "raw.isNull()" not in guard or "throw WindowsException(E_POINTER)" not in guard:
        fail("windows-interface requireOwnedInterfaceRaw must reject null owned COM pointers with E_POINTER")
    if text.count("let liveRaw = if (takeOwnership) { requireOwnedInterfaceRaw(raw) } else { raw }") < 2:
        fail("InterfaceWrapperBase takeOwnership constructors must route through requireOwnedInterfaceRaw")


def check_from_abi_take_routes_to_owned_guard(workspace: Path) -> None:
    findings: list[str] = []
    for source in cj_sources(workspace, production_only=True):
        relative = rel(source, workspace)
        if (
            relative.startswith("windows-strings/")
            or relative.startswith("windows/src/")
            or relative.startswith("windows-interface/src/macros/")
            or relative.startswith("windows-implement/src/descriptor_codegen")
        ):
            continue
        text = source.read_text(encoding="utf-8")
        for match in FROM_ABI_TAKE_RE.finditer(text):
            body = extract_braced_block(text, match.start())
            if (
                "takeOwnership: true" in body
                or re.search(r"\bOwned[A-Za-z0-9_]*\s*\(\s*raw\s*\)", body)
                or "requireOwnedInterfaceRaw(raw)" in body
            ):
                continue
            # Generic declarations and descriptor closures are not owned constructors.
            if not body.strip() or "static func fromAbiTake(raw:" in body:
                continue
            line = text[: match.start()].count("\n") + 1
            findings.append(
                f"{relative}:{line}: fromAbiTake(raw) must route owned COM pointers "
                "through the shared takeOwnership null guard"
            )
    if findings:
        print("FAIL: fromAbiTake owned pointer guard audit failed:", file=sys.stderr)
        for finding in findings:
            print(f"  {finding}", file=sys.stderr)
        sys.exit(1)


def main() -> None:
    workspace = Path(__file__).resolve().parent.parent
    check_query_interface_results_consumed(workspace)
    check_direct_query_interface_call_sites(workspace)
    check_interface_take_ownership_guard(workspace)
    check_from_abi_take_routes_to_owned_guard(workspace)
    print(f"workspace = {workspace}")
    print("OK: ABI ownership and QueryInterface result invariants hold")


if __name__ == "__main__":
    main()
