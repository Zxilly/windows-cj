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
inside the same control-flow path (so it cannot be the implicit return).
It also rejects `let _ = value.ok()`, which explicitly discards the
returned `Result`.

The heuristic is intentionally conservative: tail expressions are
allowed, expressions inside larger expressions are not matched at all,
and any `let`/`var`/`return`/`throw` prefix exempts the line. The check
tracks brace depth far enough to reject `.ok()` at the tail of an
`if`/`try`/`match` branch when the enclosing expression is followed by
more work.
"""

from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path


IGNORED_OK_ASSIGN_RE = re.compile(r"^(?:let|var)\s+_(?:\s*:[^=]+)?\s*=.*\.ok\(\)")
DISCARD_ASSIGN_START_RE = re.compile(r"^(?:let|var)\s+_(?:\s*:[^=]+)?\s*=\s*$")
DISCARD_ASSIGN_WITH_RHS_RE = re.compile(r"^(?:let|var)\s+_(?:\s*:[^=]+)?\s*=\s*(.+)$")
EXEMPT_OK_PREFIX_RE = re.compile(r"^(?:let|var|return|throw|match|if|while|for|try|case)\b")
CONTINUATION_RE = re.compile(r"^(?:}?\s*)?(?:else|catch|finally)\b")
LOOP_BLOCK_RE = re.compile(r"^(?:while|for)\b")
BLOCK_RESULT_OWNER_RE = re.compile(
    r"^(?:(?:public|private|protected|internal|static|unsafe|open|override|mut|foreign)\s+)*"
    r"(?:(?:operator\s+)?func|init|main|~init|get|set)\b"
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


def strip_line_comment(line: str) -> str:
    return mask_cj_strings_and_comments(line)


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


def has_top_level_assignment(code: str) -> bool:
    paren_depth = 0
    brace_depth = 0
    bracket_depth = 0
    in_string = False
    escaped = False
    for index, char in enumerate(code):
        if escaped:
            escaped = False
            continue
        if char == "\\" and in_string:
            escaped = True
            continue
        if char == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if char == "(":
            paren_depth += 1
            continue
        if char == ")" and paren_depth > 0:
            paren_depth -= 1
            continue
        if char == "{":
            brace_depth += 1
            continue
        if char == "}" and brace_depth > 0:
            brace_depth -= 1
            continue
        if char == "[":
            bracket_depth += 1
            continue
        if char == "]" and bracket_depth > 0:
            bracket_depth -= 1
            continue
        if char != "=" or paren_depth != 0 or brace_depth != 0 or bracket_depth != 0:
            continue
        previous_char = code[index - 1] if index > 0 else ""
        next_char = code[index + 1] if index + 1 < len(code) else ""
        if previous_char in {"=", "!", "<", ">", "-"} or next_char in {"=", ">"}:
            continue
        return True
    return False


def top_level_assignment_rhs(code: str) -> str | None:
    paren_depth = 0
    brace_depth = 0
    bracket_depth = 0
    for index, char in enumerate(code):
        if char == "(":
            paren_depth += 1
            continue
        if char == ")" and paren_depth > 0:
            paren_depth -= 1
            continue
        if char == "{":
            brace_depth += 1
            continue
        if char == "}" and brace_depth > 0:
            brace_depth -= 1
            continue
        if char == "[":
            bracket_depth += 1
            continue
        if char == "]" and bracket_depth > 0:
            bracket_depth -= 1
            continue
        if char != "=" or paren_depth != 0 or brace_depth != 0 or bracket_depth != 0:
            continue
        previous_char = code[index - 1] if index > 0 else ""
        next_char = code[index + 1] if index + 1 < len(code) else ""
        if previous_char in {"=", "!", "<", ">", "-"} or next_char in {"=", ">"}:
            continue
        return code[index + 1 :]
    return None


def is_statement_ok_call(line: str) -> bool:
    code = strip_line_comment(line).strip()
    if code.endswith(";"):
        code = code[:-1].rstrip()
    code = strip_outer_parens(code)
    if not code.endswith(".ok()"):
        return False
    if EXEMPT_OK_PREFIX_RE.match(code):
        return False
    if has_top_level_assignment(code):
        return False
    receiver = code[: -len(".ok()")].strip()
    return bool(receiver)


def strip_top_level_lambda_arrow(statement: str) -> str:
    paren_depth = 0
    brace_depth = 0
    bracket_depth = 0
    index = 0
    while index + 1 < len(statement):
        char = statement[index]
        if char == "(":
            paren_depth += 1
            index += 1
            continue
        if char == ")" and paren_depth > 0:
            paren_depth -= 1
            index += 1
            continue
        if char == "{":
            brace_depth += 1
            index += 1
            continue
        if char == "}" and brace_depth > 0:
            brace_depth -= 1
            index += 1
            continue
        if char == "[":
            bracket_depth += 1
            index += 1
            continue
        if char == "]" and bracket_depth > 0:
            bracket_depth -= 1
            index += 1
            continue
        if (
            char == "="
            and statement[index + 1] == ">"
            and paren_depth == 0
            and brace_depth == 0
            and bracket_depth == 0
        ):
            return statement[index + 2 :].strip()
        index += 1
    return statement.strip()


def strip_outer_parens(code: str) -> str:
    stripped = code.strip()
    while stripped.startswith("(") and stripped.endswith(")"):
        depth = 0
        in_string = False
        escaped = False
        closes_at_end = False
        for index, char in enumerate(stripped):
            if escaped:
                escaped = False
                continue
            if char == "\\" and in_string:
                escaped = True
                continue
            if char == '"':
                in_string = not in_string
                continue
            if in_string:
                continue
            if char == "(":
                depth += 1
                continue
            if char == ")":
                depth -= 1
                if depth == 0:
                    closes_at_end = index == len(stripped) - 1
                    break
        if not closes_at_end:
            break
        stripped = stripped[1:-1].strip()
    return stripped


def strip_inline_body_braces(body: str) -> str:
    code = body.strip()
    if code.startswith("{") and code.endswith("}"):
        code = code[1:-1].strip()
    return code


def split_top_level_semicolon_statements(code: str) -> list[str]:
    statements: list[str] = []
    start = 0
    paren_depth = 0
    brace_depth = 0
    bracket_depth = 0
    in_string = False
    escaped = False
    for index, char in enumerate(code):
        if escaped:
            escaped = False
            continue
        if char == "\\" and in_string:
            escaped = True
            continue
        if char == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if char == "(":
            paren_depth += 1
            continue
        if char == ")" and paren_depth > 0:
            paren_depth -= 1
            continue
        if char == "{":
            brace_depth += 1
            continue
        if char == "}" and brace_depth > 0:
            brace_depth -= 1
            continue
        if char == "[":
            bracket_depth += 1
            continue
        if char == "]" and bracket_depth > 0:
            bracket_depth -= 1
            continue
        if char == ";" and paren_depth == 0 and brace_depth == 0 and bracket_depth == 0:
            statement = code[start:index].strip()
            if statement:
                statements.append(statement)
            start = index + 1
    final_statement = code[start:].strip()
    if final_statement:
        statements.append(final_statement)
    return statements


def is_ignored_ok_discard_statement(statement: str) -> bool:
    code = statement.strip()
    return IGNORED_OK_ASSIGN_RE.match(code) is not None or is_statement_ok_call(code)


def statement_has_ignored_ok_result(statement: str) -> bool:
    code = strip_top_level_lambda_arrow(statement.strip())
    if not code:
        return False
    return (
        is_ignored_ok_discard_statement(code)
        or is_inline_control_ok_call(code)
        or is_inline_control_nontail_ok_call(code)
        or inline_block_has_nontail_ok_statement(code)
    )


def inline_body_has_nontail_ok_statement(body: str) -> bool:
    statements = split_top_level_semicolon_statements(strip_inline_body_braces(body))
    return any(statement_has_ignored_ok_result(statement) for statement in statements[:-1])


def line_has_nontail_ok_statement(line: str) -> bool:
    statements = split_top_level_semicolon_statements(strip_line_comment(line).strip())
    return any(is_ignored_ok_discard_statement(statement) for statement in statements[:-1])


def inline_block_has_nontail_ok_statement(line: str) -> bool:
    code = strip_line_comment(line).strip()
    for match in re.finditer(r"\{\s*([^{}]*\.ok\(\)[^{}]*)\}", code):
        if inline_body_has_nontail_ok_statement(match.group(1)):
            return True
    return False


def iter_brace_bodies(code: str):
    stack: list[int] = []
    for index, char in enumerate(code):
        if char == "{":
            stack.append(index)
            continue
        if char == "}" and stack:
            start = stack.pop()
            yield code[start + 1 : index]


def assignment_rhs_has_nontail_ok_statement(line: str) -> bool:
    code = strip_line_comment(line).strip()
    if ".ok()" not in code:
        return False
    rhs = top_level_assignment_rhs(code)
    if rhs is None:
        return False
    return any(inline_body_has_nontail_ok_statement(body) for body in iter_brace_bodies(rhs))


def inline_body_ok_statement(body: str) -> bool:
    statements = split_top_level_semicolon_statements(strip_inline_body_braces(body))
    if len(statements) != 1:
        return False
    code = statements[0]
    return is_statement_ok_call(code)


def is_inline_control_nontail_ok_call(line: str) -> bool:
    code = strip_line_comment(line).strip()
    for case_match in re.finditer(r"\bcase\b[^{}]*?=>", code):
        body_start = case_match.end()
        next_case = re.search(r"\bcase\b", code[body_start:])
        next_brace = code.find("}", body_start)
        body_end = len(code)
        if next_case is not None:
            body_end = min(body_end, body_start + next_case.start())
        if next_brace >= 0:
            body_end = min(body_end, next_brace)
        if inline_body_has_nontail_ok_statement(code[body_start:body_end]):
            return True
    if "{" not in code or "}" not in code:
        return False
    for match in re.finditer(r"\{\s*([^{}]*\.ok\(\)[^{}]*)\}", code):
        prefix = code[: match.start()].strip()
        if re.search(r"(?:^|\})\s*(?:if|else|try|catch|finally|while|for)\b", prefix):
            if inline_body_has_nontail_ok_statement(match.group(1)):
                return True
    return False


def is_inline_control_ok_call(line: str) -> bool:
    code = strip_line_comment(line).strip()
    if code.endswith(";"):
        code = code[:-1].rstrip()
    if not code.endswith("}") and "=>" not in code:
        return False
    if code.startswith("case ") and "=>" in code:
        return inline_body_ok_statement(code.split("=>", 1)[1])
    match = re.search(r"\{\s*([^{}]+?\.ok\(\))\s*\}\s*$", code)
    if not match:
        return False
    prefix = code[: match.start()].strip()
    if not re.match(r"^(?:}?\s*)?(?:if|else|try|catch|finally|while|for)\b", prefix):
        return False
    return inline_body_ok_statement(match.group(1))


def brace_delta(line: str) -> int:
    code = strip_line_comment(line)
    in_string = False
    escaped = False
    delta = 0
    for char in code:
        if escaped:
            escaped = False
            continue
        if char == "\\" and in_string:
            escaped = True
            continue
        if char == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if char == "{":
            delta += 1
        elif char == "}":
            delta -= 1
    return delta


def nesting_delta(line: str) -> int:
    delta = 0
    for char in strip_line_comment(line):
        if char in "({[":
            delta += 1
        elif char in ")}]":
            delta -= 1
    return delta


def discard_expression_has_ok(lines: list[str]) -> bool:
    for raw in lines:
        stripped = raw.strip()
        if not stripped:
            continue
        if line_has_nontail_ok_statement(stripped):
            return True
        if inline_block_has_nontail_ok_statement(stripped):
            return True
        if IGNORED_OK_ASSIGN_RE.match(stripped):
            return True
        if is_inline_control_nontail_ok_call(stripped):
            return True
        if is_statement_ok_call(stripped):
            return True
        if is_inline_control_ok_call(stripped):
            return True
    return False


def collect_discard_expression(lines: list[str], start: int) -> tuple[int, list[str]]:
    expression: list[str] = []
    depth = 0
    index = start
    while index < len(lines):
        stripped = lines[index].strip()
        if not stripped and not expression:
            index += 1
            continue
        expression.append(lines[index])
        depth += nesting_delta(lines[index])
        if depth <= 0:
            return index, expression
        index += 1
    return len(lines) - 1, expression


def brace_depths(lines: list[str]) -> tuple[list[int], list[int]]:
    before: list[int] = []
    after: list[int] = []
    depth = 0
    for line in lines:
        before.append(depth)
        depth += brace_delta(line)
        if depth < 0:
            depth = 0
        after.append(depth)
    return before, after


def next_meaningful_index(lines: list[str], start: int) -> int | None:
    index = start
    while index < len(lines):
        candidate = strip_line_comment(lines[index]).strip()
        if candidate:
            return index
        index += 1
    return None


def skip_opened_block(lines: list[str], depth_after: list[int], start: int, body_depth: int) -> int:
    index = start + 1
    while index < len(lines):
        if strip_line_comment(lines[index]).strip() and depth_after[index] < body_depth:
            return index
        index += 1
    return len(lines) - 1


def block_opener_for_depth(
    lines: list[str],
    depth_before: list[int],
    depth_after: list[int],
    before_index: int,
    frame_depth: int,
) -> str:
    for index in range(before_index, -1, -1):
        stripped = strip_line_comment(lines[index]).strip()
        if "{" not in stripped:
            continue
        if depth_before[index] < frame_depth <= depth_after[index]:
            return stripped
    return ""


def block_owns_tail_result(
    lines: list[str],
    depth_before: list[int],
    depth_after: list[int],
    before_index: int,
    frame_depth: int,
) -> bool:
    opener = block_opener_for_depth(lines, depth_before, depth_after, before_index, frame_depth)
    return BLOCK_RESULT_OWNER_RE.match(opener) is not None


def block_is_loop(
    lines: list[str],
    depth_before: list[int],
    depth_after: list[int],
    before_index: int,
    frame_depth: int,
) -> bool:
    opener = block_opener_for_depth(lines, depth_before, depth_after, before_index, frame_depth)
    return LOOP_BLOCK_RE.match(opener) is not None


def is_tail_ok_statement(lines: list[str], index: int) -> bool:
    depth_before, depth_after = brace_depths(lines)
    frame_depth = depth_before[index]
    cursor = index + 1
    while True:
        next_index = next_meaningful_index(lines, cursor)
        if next_index is None:
            return True

        stripped = strip_line_comment(lines[next_index]).strip()
        line_depth = depth_before[next_index]

        if line_depth < frame_depth:
            frame_depth = line_depth

        if stripped.startswith("case ") and line_depth == frame_depth:
            if "{" in stripped:
                body_depth = max(depth_after[next_index], frame_depth + 1)
                cursor = skip_opened_block(lines, depth_after, next_index, body_depth) + 1
            else:
                cursor = next_index + 1
            continue

        if CONTINUATION_RE.match(stripped) and "{" in stripped and line_depth <= frame_depth:
            if depth_after[next_index] < frame_depth:
                frame_depth = depth_after[next_index]
                cursor = next_index + 1
            else:
                body_depth = max(depth_after[next_index], frame_depth)
                cursor = skip_opened_block(lines, depth_after, next_index, body_depth) + 1
            continue

        if stripped.startswith("}") and line_depth >= frame_depth:
            if CONTINUATION_RE.match(stripped) and "{" in stripped:
                body_depth = max(depth_after[next_index], frame_depth)
                cursor = skip_opened_block(lines, depth_after, next_index, body_depth) + 1
                frame_depth = max(frame_depth - 1, 0)
                continue
            if block_is_loop(lines, depth_before, depth_after, next_index, frame_depth):
                return False
            if block_owns_tail_result(lines, depth_before, depth_after, next_index, frame_depth):
                return True
            frame_depth = depth_after[next_index]
            cursor = next_index + 1
            continue

        if line_depth == frame_depth:
            return False

        cursor = next_index + 1


def scan_lines(label: str, lines: list[str]) -> list[str]:
    findings: list[str] = []
    masked_lines = mask_cj_strings_and_comments("\n".join(lines)).split("\n")
    index = 0
    while index < len(masked_lines):
        raw = masked_lines[index]
        stripped = raw.strip()
        if DISCARD_ASSIGN_START_RE.match(stripped):
            end_index, expression = collect_discard_expression(masked_lines, index + 1)
            if discard_expression_has_ok(expression):
                findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
            index = end_index + 1
            continue
        discard_with_rhs = DISCARD_ASSIGN_WITH_RHS_RE.match(stripped)
        if discard_with_rhs is not None and not IGNORED_OK_ASSIGN_RE.match(stripped):
            rhs = discard_with_rhs.group(1)
            if nesting_delta(rhs) > 0:
                end_index, rest = collect_discard_expression(masked_lines, index + 1)
                expression = [rhs, *rest]
                if discard_expression_has_ok(expression):
                    findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
                index = end_index + 1
                continue
        if assignment_rhs_has_nontail_ok_statement(stripped):
            findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
            index += 1
            continue
        if line_has_nontail_ok_statement(stripped):
            findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
            index += 1
            continue
        if inline_block_has_nontail_ok_statement(stripped):
            findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
            index += 1
            continue
        if IGNORED_OK_ASSIGN_RE.match(stripped):
            findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
            index += 1
            continue
        if is_inline_control_nontail_ok_call(stripped):
            findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
            index += 1
            continue
        if not is_statement_ok_call(stripped):
            if not is_inline_control_ok_call(stripped):
                index += 1
                continue
        if is_tail_ok_statement(masked_lines, index):
            index += 1
            continue
        findings.append(f"{label}:{index + 1}: ignored Result.ok() value")
        index += 1
    return findings


def scan_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return scan_lines(str(path), text.splitlines())


def self_check() -> None:
    if not scan_lines("<self>", ["hr.ok() // ignored", "println(\"after\")"]):
        raise AssertionError("standalone .ok() with trailing comment must be rejected")
    if not scan_lines("<self>", ["HRESULT(hr).ok() // ignored", "println(\"after\")"]):
        raise AssertionError("constructor receiver .ok() must be rejected")
    if not scan_lines("<self>", ["HRESULT(unsafe { table.Remove(raw, token) }).ok()", "println(\"after\")"]):
        raise AssertionError("unsafe-block receiver .ok() must be rejected")
    if not scan_lines("<self>", ["let _ = hr.ok() // ignored"]):
        raise AssertionError("discarded .ok() assignment with trailing comment must be rejected")
    if not scan_lines("<self>", ["let _ = hr.ok(); // ignored"]):
        raise AssertionError("discarded .ok() assignment with trailing semicolon must be rejected")
    if not scan_lines("<self>", ["let _: Result<Unit> = hr.ok()"]):
        raise AssertionError("typed discarded .ok() assignment must be rejected")
    if not scan_lines("<self>", ["var _ = hr.ok()"]):
        raise AssertionError("var discarded .ok() assignment must be rejected")
    if not scan_lines("<self>", ["let _ = (hr.ok())"]):
        raise AssertionError("parenthesized discarded .ok() assignment must be rejected")
    if not scan_lines("<self>", ["let _ = if (condition) { hr.ok() } else { other.ok() }"]):
        raise AssertionError("discarded conditional .ok() assignment must be rejected")
    if not scan_lines("<self>", ["let _ =", "    hr.ok()"]):
        raise AssertionError("multiline discarded .ok() assignment must be rejected")
    if not scan_lines(
        "<self>",
        [
            "let _ = match (value) {",
            "    case Some(_) => hr.ok()",
            "    case None => other.ok()",
            "}",
        ],
    ):
        raise AssertionError("multiline discarded block expression .ok() assignment must be rejected")
    if not scan_lines("<self>", ["hr.ok() /* { */; println(\"after\")"]):
        raise AssertionError("same-line .ok() before work with block-comment brace must be rejected")
    if scan_lines("<self>", ["let result = HRESULT(hr).ok()", "println(\"after\")"]):
        raise AssertionError("stored .ok() value should remain allowed")
    if scan_lines("<self>", ["hr.ok() // tail", "}"]):
        raise AssertionError("tail-position standalone .ok() should remain allowed")
    if scan_lines("<self>", ["public func ok(): Result<Unit> {", "    hr.ok()", "}", "public func other(): Bool {", "    true", "}"]):
        raise AssertionError("function-tail standalone .ok() before another declaration should remain allowed")
    if not scan_lines("<self>", ["if (condition) {", "    hr.ok()", "}", "println(\"after\")"]):
        raise AssertionError("branch-tail .ok() before outer work must be rejected")
    if scan_lines("<self>", ["if (condition) {", "    hr.ok()", "} else {", "    other.ok()", "}", "}"]):
        raise AssertionError("tail-position if branches should remain allowed")
    if not scan_lines("<self>", ["if (condition) {", "    hr.ok()", "} else { other.ok() }", "println(\"after\")"]):
        raise AssertionError("inline else .ok() before outer work must be rejected")
    if not scan_lines("<self>", ["if (condition) { hr.ok(); println(\"after\") }"]):
        raise AssertionError("inline non-tail if-body .ok() must be rejected")
    if not scan_lines("<self>", ["case Some(_) => hr.ok(); println(\"after\")"]):
        raise AssertionError("inline non-tail case-body .ok() must be rejected")
    if not scan_lines("<self>", ["let f = { => if (condition) { HRESULT(hr).ok() }; println(\"after\") }"]):
        raise AssertionError("assigned inline control-expression .ok() before work must be rejected")
    if scan_lines("<self>", ["let f = { => HRESULT(hr).ok() }"]):
        raise AssertionError("assigned lambda tail .ok() should remain allowed")


def workspace_members(workspace: Path) -> list[str]:
    with (workspace / "cjpm.toml").open("rb") as f:
        config = tomllib.load(f)
    members = config.get("workspace", {}).get("members", [])
    if not isinstance(members, list) or not all(isinstance(member, str) for member in members):
        raise RuntimeError(f"{workspace / 'cjpm.toml'} workspace.members must be a string array")
    return list(members)


def audit_workspace(workspace: Path) -> list[str]:
    findings: list[str] = []
    for member in workspace_members(workspace):
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
    try:
        findings = audit_workspace(workspace)
    except RuntimeError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
    if findings:
        print("FAIL: ignored HRESULT/Result.ok() value(s):", file=sys.stderr)
        for entry in findings:
            print(f"  {entry}", file=sys.stderr)
        sys.exit(1)
    print(f"workspace = {workspace}")
    print("OK: no ignored HRESULT/Result.ok() values in active .cj sources")


if __name__ == "__main__":
    main()
