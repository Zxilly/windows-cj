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
import tomllib
from pathlib import Path


MATCH_EXPR_RE = re.compile(r"match\s*\(")
QUERY_INTERFACE_HELPERS = ("queryInterfaceRaw", "queryInterfaceAs", "comQueryInterfaceRaw")
QUERY_INTERFACE_HELPER_CALL = rf"(?:[A-Za-z_][A-Za-z0-9_]*\.)*(?:{'|'.join(QUERY_INTERFACE_HELPERS)})"
QUERY_INTERFACE_BINDING_RE = re.compile(
    rf"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:[^=\n]+)?\s*=\s*(?:unsafe\s*\{{\s*)?{QUERY_INTERFACE_HELPER_CALL}\b",
    re.MULTILINE,
)
QUERY_REQUIRED_BINDING_RE = re.compile(
    r"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:[^=\n]+)?\s*=\s*queryRequired\s*\(",
    re.MULTILINE,
)
QUERY_REQUIRED_CALL_RE = re.compile(r"\bqueryRequired\s*\(")
SOME_CASE_RE = re.compile(r"^(\s*)case\s+Some\(([A-Za-z_][A-Za-z0-9_]*)\)\s*=>", re.MULTILINE)
CASE_RE = re.compile(r"^(\s*)case\b.*=>", re.MULTILINE)
DIRECT_QUERY_INTERFACE_RE = re.compile(r"\.QueryInterface\s*\(")
DISCARDED_OWNED_WRAPPER_RE = re.compile(
    r"\b(?:let|var)\s+_\s*(?::[^=\n]+)?=\s*[^\n;]*"
    r"(?:fromAbiTake|fromAbiTakeWinrtHandle|takeFromAbi)\s*\(",
    re.MULTILINE,
)
CONDITIONAL_BLOCK_RE = re.compile(r"\b(?:if|else|while|for|match|do|case|try|catch)\b")
NESTED_FUNCTION_BLOCK_RE = re.compile(r"\b(?:func|init|get|set)\b")
LAMBDA_BODY_START_RE = re.compile(r"^\s*[^{}\n]*=>")
FROM_ABI_TAKE_RE = re.compile(
    r"public\s+static\s+func\s+fromAbiTake\s*\(\s*raw:\s*CPointer<Unit>\s*\)[^{]*\{",
    re.MULTILINE,
)
OWNED_CONSTRUCTOR_RE = re.compile(r"\bOwned[A-Za-z0-9_]*(?:\s*<[^{}\n]+>)?\s*\(\s*raw\s*\)")

# These files contain low-level helper implementations or COM forwarding thunks.
# New direct vtable QueryInterface calls should normally go through
# queryInterfaceRaw/queryInterfaceAs and will need an explicit review here.
DIRECT_QUERY_INTERFACE_ALLOWED_FILES = {
    "windows_result/src/com.cj",
    "windows_interface/src/interface_wrapper.cj",
    "windows_implement/src/composable_activation.cj",
    "windows_implement/src/weak_ref_count.cj",
    "windows_core/src/com_interface.cj",
    "windows_core/src/marshaler.cj",
    "windows_core/src/weak_ref_count.cj",
}


def rel(path: Path, workspace: Path) -> str:
    return path.relative_to(workspace).as_posix()


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def workspace_members(workspace: Path) -> list[str]:
    with (workspace / "cjpm.toml").open("rb") as f:
        config = tomllib.load(f)
    members = config.get("workspace", {}).get("members", [])
    if not isinstance(members, list) or not all(isinstance(member, str) for member in members):
        fail(f"{workspace / 'cjpm.toml'} workspace.members must be a string array")
    return list(members)


def cj_sources(workspace: Path, *, production_only: bool) -> list[Path]:
    sources: list[Path] = []
    for member in workspace_members(workspace):
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


def matching_paren_end(text: str, open_index: int) -> int | None:
    depth = 0
    in_string = False
    escaped = False
    index = open_index
    while index < len(text):
        char = text[index]
        if escaped:
            escaped = False
            index += 1
            continue
        if char == "\\" and in_string:
            escaped = True
            index += 1
            continue
        if char == '"':
            in_string = not in_string
            index += 1
            continue
        if in_string:
            index += 1
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return None


def matching_brace_end(text: str, open_index: int) -> int | None:
    depth = 0
    in_string = False
    escaped = False
    index = open_index
    while index < len(text):
        char = text[index]
        if escaped:
            escaped = False
            index += 1
            continue
        if char == "\\" and in_string:
            escaped = True
            index += 1
            continue
        if char == '"':
            in_string = not in_string
            index += 1
            continue
        if in_string:
            index += 1
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return None


def query_interface_match_positions(text: str) -> list[int]:
    positions: list[int] = []
    helper_bindings = {match.group(1) for match in QUERY_INTERFACE_BINDING_RE.finditer(text)}
    for match_expr in MATCH_EXPR_RE.finditer(text):
        open_index = text.find("(", match_expr.start(), match_expr.end())
        if open_index < 0:
            continue
        close_index = matching_paren_end(text, open_index)
        if close_index is None:
            continue
        header = text[match_expr.start() : close_index + 1]
        matched_value = text[open_index + 1 : close_index].strip()
        if any(helper in header for helper in QUERY_INTERFACE_HELPERS) or matched_value in helper_bindings:
            positions.append(match_expr.start())
    return positions


def extract_match_braced_block(text: str, match_start: int) -> tuple[str, int]:
    open_index = text.find("(", match_start)
    if open_index < 0:
        fail("internal parser error: expected a match expression")
    close_index = matching_paren_end(text, open_index)
    if close_index is None:
        fail("internal parser error: unterminated match expression")
    brace = text.find("{", close_index + 1)
    if brace < 0:
        fail("internal parser error: expected a match body")
    end = matching_brace_end(text, brace)
    if end is None:
        fail("internal parser error: unterminated match body")
    return text[brace + 1 : end], brace + 1


def case_body_until_next_sibling(block: str, match: re.Match[str]) -> str:
    indent = len(match.group(1))
    start = match.end()
    next_case_re = re.compile(r"^(\s*)case\s+", re.MULTILINE)
    for next_case in next_case_re.finditer(block, start):
        if len(next_case.group(1)) <= indent:
            return block[start : next_case.start()]
    return block[start:]


def query_result_consumed(body: str, name: str) -> bool:
    raw_name = re.escape(name)
    search_body = mask_cj_strings_and_comments(body)
    unconditional_body = mask_conditional_blocks(search_body)
    tail_body = single_non_comment_statement(search_body)
    final_body = last_non_comment_statement(search_body)
    tail_expression = tail_body if tail_body is not None else final_body
    qualified_prefix = rf"(?:[A-Za-z_][A-Za-z0-9_]*(?:\s*<[^{{}}\n]+>)?\.)*"
    enum_wrapper = rf"{qualified_prefix}(?:Some|Ok)"
    direct_tail_raw = tail_expression == name
    direct_tail_wrapper = (
        tail_expression is not None
        and re.fullmatch(rf"{enum_wrapper}\s*\(\s*{raw_name}\s*\)", tail_expression) is not None
    )
    known_take_call = (
        qualified_prefix
        + rf"(?:takeFromAbi|fromAbiTake|fromAbiTakeWinrtHandle)\s*\(\s*{raw_name}\b[^\n;]*\)"
    )
    direct_tail_owned_wrapper = (
        tail_expression is not None
        and (
            re.fullmatch(known_take_call, tail_expression) is not None
            or re.fullmatch(rf"{enum_wrapper}\s*\(\s*{known_take_call}\s*\)", tail_expression) is not None
        )
    )
    patterns = (
        rf"\breturn\s+{raw_name}\b(?!\s*\.)(?:\s*(?:;|$)|\s*\n)",
        rf"\breturn\s+{known_take_call}",
        rf"\breturn\s+{enum_wrapper}\s*\(\s*{raw_name}\s*\)",
        rf"\breturn\s+{enum_wrapper}\s*\([^\n;]*(?:takeFromAbi|releasePointer|fromAbiTake|fromAbiTakeWinrtHandle)\s*\(\s*{raw_name}\b[^\n;]*\)",
        rf"\b{raw_name}\s*\.\s*(?:close|intoAbi|release)\s*\(",
        rf"\b(?:interfaceHandleReleaseRaw|comReleaseRaw|releaseRaw)\s*\(\s*{raw_name}\s*\)",
        rf"\breleasePointer\s*\(\s*{raw_name}\s*\)",
    )
    return (
        direct_tail_raw
        or direct_tail_wrapper
        or direct_tail_owned_wrapper
        or any(re.search(pattern, unconditional_body, re.DOTALL) for pattern in patterns)
        or top_level_match_consumes_all_cases(search_body, name)
    )


def query_required_result_consumed(body: str, name: str) -> bool:
    if query_result_consumed(body, name):
        return True
    raw_name = re.escape(name)
    search_body = mask_cj_strings_and_comments(body)
    tail_body = single_non_comment_statement(search_body)
    final_body = last_non_comment_statement(search_body)
    tail_expression = tail_body if tail_body is not None else final_body
    owning_wrapper = r"(?:UIElementHandle|ButtonBaseHandle|XamlObjectHandle)\s*\(\s*" + raw_name + r"\s*\)"
    if tail_expression is not None and re.fullmatch(owning_wrapper, tail_expression) is not None:
        return True
    return re.search(rf"\breturn\s+{owning_wrapper}", search_body) is not None


def strip_line_comments(text: str) -> str:
    return mask_cj_strings_and_comments(text)


def mask_cj_strings_and_comments(text: str) -> str:
    chars = list(text)

    def mask_range(start: int, end: int) -> None:
        for offset in range(start, end):
            if chars[offset] != "\n":
                chars[offset] = " "

    index = 0
    while index < len(text):
        if text.startswith("//", index):
            end = text.find("\n", index)
            if end < 0:
                end = len(text)
            mask_range(index, end)
            index = end
            continue
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                end = len(text)
            else:
                end += 2
            mask_range(index, end)
            index = end
            continue
        if text[index] == "#":
            hash_count = 0
            while index + hash_count < len(text) and text[index + hash_count] == "#":
                hash_count += 1
            string_start = index + hash_count
            if string_start < len(text) and text[string_start] == '"':
                close_marker = '"' + ("#" * hash_count)
                end = text.find(close_marker, string_start + 1)
                if end < 0:
                    end = len(text)
                else:
                    end += len(close_marker)
                mask_range(index, end)
                index = end
                continue
        if text[index] == '"':
            end = index + 1
            escaped = False
            while end < len(text):
                char = text[end]
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    end += 1
                    break
                end += 1
            mask_range(index, min(end, len(text)))
            index = end
            continue
        if text[index] == "'":
            end = index + 1
            escaped = False
            while end < len(text):
                char = text[end]
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == "'":
                    end += 1
                    break
                end += 1
            mask_range(index, min(end, len(text)))
            index = end
            continue
        index += 1
    return "".join(chars)


def mask_conditional_blocks(text: str) -> str:
    chars = list(text)
    index = 0
    while index < len(text):
        if text[index] != "{":
            index += 1
            continue
        header_end = index - 1
        while header_end >= 0 and text[header_end].isspace():
            header_end -= 1
        line_start = max(
            text.rfind("\n", 0, header_end + 1),
            text.rfind("}", 0, header_end + 1),
            text.rfind(";", 0, header_end + 1),
        ) + 1
        prefix = text[line_start : header_end + 1]
        end = matching_brace_end(text, index)
        if end is None:
            return text
        body_prefix = text[index + 1 : min(end, index + 160)]
        if (
            CONDITIONAL_BLOCK_RE.search(prefix)
            or NESTED_FUNCTION_BLOCK_RE.search(prefix)
            or LAMBDA_BODY_START_RE.search(body_prefix)
        ):
            for offset in range(index, end + 1):
                if chars[offset] != "\n":
                    chars[offset] = " "
            index = end + 1
            continue
        index += 1
    return "".join(chars)


def top_level_match_consumes_all_cases(text: str, name: str) -> bool:
    for match_expr in MATCH_EXPR_RE.finditer(text):
        if brace_depth_at(text, match_expr.start()) != 0:
            continue
        open_index = text.find("(", match_expr.start(), match_expr.end())
        if open_index < 0:
            continue
        close_index = matching_paren_end(text, open_index)
        if close_index is None:
            continue
        brace = text.find("{", close_index)
        if brace < 0:
            continue
        end = matching_brace_end(text, brace)
        if end is None:
            continue
        block = text[brace + 1 : end]
        cases = list(CASE_RE.finditer(block))
        if cases and all(query_result_consumed(case_body_until_next_sibling(block, case), name) for case in cases):
            return True
    return False


def brace_depth_at(text: str, target: int) -> int:
    depth = 0
    in_string = False
    escaped = False
    index = 0
    while index < target:
        char = text[index]
        if escaped:
            escaped = False
            index += 1
            continue
        if char == "\\" and in_string:
            escaped = True
            index += 1
            continue
        if char == '"':
            in_string = not in_string
            index += 1
            continue
        if in_string:
            index += 1
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        index += 1
    return depth


def single_non_comment_statement(text: str) -> str | None:
    statements = [line.strip() for line in mask_cj_strings_and_comments(text).splitlines() if line.strip()]
    if len(statements) != 1:
        return None
    if ";" in statements[0]:
        return None
    return statements[0]


def last_non_comment_statement(text: str) -> str | None:
    statements = [line.strip() for line in mask_cj_strings_and_comments(text).splitlines() if line.strip()]
    if not statements:
        return None
    if ";" in statements[-1]:
        return None
    return statements[-1]


def check_query_interface_results_consumed(workspace: Path) -> None:
    findings: list[str] = []
    for source in cj_sources(workspace, production_only=True):
        text = source.read_text(encoding="utf-8")
        for query_match_start in query_interface_match_positions(text):
            block, block_start = extract_match_braced_block(text, query_match_start)
            for some_case in SOME_CASE_RE.finditer(block):
                name = some_case.group(2)
                body = case_body_until_next_sibling(block, some_case)
                if query_result_consumed(body, name):
                    continue
                line = text[:block_start].count("\n") + block[: some_case.start()].count("\n") + 1
                findings.append(
                    f"{rel(source, workspace)}:{line}: QueryInterface result {name!r} "
                    "must be returned/wrapped or closed"
                )
    if findings:
        print("FAIL: QueryInterface result ownership audit failed:", file=sys.stderr)
        for finding in findings:
            print(f"  {finding}", file=sys.stderr)
        sys.exit(1)


def check_owned_raw_query_required_results_consumed(workspace: Path) -> None:
    xaml = workspace / "windows_winui3" / "src" / "xaml" / "mod.cj"
    if not xaml.exists():
        return
    text = xaml.read_text(encoding="utf-8")
    masked = mask_cj_strings_and_comments(text)
    findings: list[str] = []
    binding_spans: list[tuple[int, int]] = []
    for match in QUERY_REQUIRED_BINDING_RE.finditer(masked):
        name = match.group(1)
        line_end = masked.find("\n", match.end())
        if line_end < 0:
            line_end = len(masked)
        # The WinUI helper has short functions; keep the audit conservative and local.
        body = masked[line_end : min(len(masked), line_end + 2400)]
        binding_spans.append((match.start(), line_end))
        if query_required_result_consumed(body, name):
            continue
        line = text[: match.start()].count("\n") + 1
        findings.append(
            f"{rel(xaml, workspace)}:{line}: queryRequired result {name!r} "
            "must be transferred to an owning wrapper or released with releaseRaw"
        )

    for match in QUERY_REQUIRED_CALL_RE.finditer(masked):
        if any(start <= match.start() < end for start, end in binding_spans):
            continue
        line_start = masked.rfind("\n", 0, match.start()) + 1
        line_end = masked.find("\n", match.end())
        if line_end < 0:
            line_end = len(masked)
        line = masked[line_start:line_end]
        if re.search(r"\bfunc\s+queryRequired\s*\(", line):
            continue
        if re.search(r"\b(?:UIElementHandle|ButtonBaseHandle|XamlObjectHandle)\s*\(\s*queryRequired\s*\(", line):
            continue
        line_number = text[: match.start()].count("\n") + 1
        findings.append(
            f"{rel(xaml, workspace)}:{line_number}: queryRequired call must be immediately wrapped, "
            "bound for checked release, or returned through an owning wrapper"
        )

    if findings:
        print("FAIL: WinUI queryRequired ownership audit failed:", file=sys.stderr)
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


def check_discarded_owned_wrappers(workspace: Path) -> None:
    findings: list[str] = []
    for source in cj_sources(workspace, production_only=True):
        text = source.read_text(encoding="utf-8")
        masked = mask_cj_strings_and_comments(text)
        for match in DISCARDED_OWNED_WRAPPER_RE.finditer(masked):
            line = text[: match.start()].count("\n") + 1
            findings.append(
                f"{rel(source, workspace)}:{line}: owned ABI wrapper constructors "
                "must not be discarded with let _"
            )
    if findings:
        print("FAIL: discarded owned ABI wrapper audit failed:", file=sys.stderr)
        for finding in findings:
            print(f"  {finding}", file=sys.stderr)
        sys.exit(1)


def check_interface_take_ownership_guard(workspace: Path) -> None:
    interface_wrapper = workspace / "windows_interface" / "src" / "interface_wrapper.cj"
    text = interface_wrapper.read_text(encoding="utf-8")
    guard = extract_braced_block(text, text.find("func requireOwnedInterfaceRaw"))
    if "raw.isNull()" not in guard or "throw WindowsException(E_POINTER)" not in guard:
        fail("windows_interface requireOwnedInterfaceRaw must reject null owned COM pointers with E_POINTER")
    if text.count("let liveRaw = if (takeOwnership) { requireOwnedInterfaceRaw(raw) } else { raw }") < 2:
        fail("InterfaceWrapperBase takeOwnership constructors must route through requireOwnedInterfaceRaw")


def check_from_abi_take_routes_to_owned_guard(workspace: Path) -> None:
    findings: list[str] = []
    for source in cj_sources(workspace, production_only=True):
        relative = rel(source, workspace)
        if (
            relative.startswith("windows_bindgen/")
            or relative.startswith("windows_strings/")
            or relative.startswith("windows_interface/src/macros/")
            or relative.startswith("windows_implement/src/descriptor_codegen")
        ):
            continue
        text = source.read_text(encoding="utf-8")
        for match in FROM_ABI_TAKE_RE.finditer(text):
            body = extract_braced_block(text, match.start())
            if (
                "takeOwnership: true" in body
                or OWNED_CONSTRUCTOR_RE.search(body)
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
    check_owned_raw_query_required_results_consumed(workspace)
    check_direct_query_interface_call_sites(workspace)
    check_discarded_owned_wrappers(workspace)
    check_interface_take_ownership_guard(workspace)
    check_from_abi_take_routes_to_owned_guard(workspace)
    print(f"workspace = {workspace}")
    print("OK: ABI ownership and QueryInterface result invariants hold")


if __name__ == "__main__":
    main()
