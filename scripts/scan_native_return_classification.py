#!/usr/bin/env python3
"""Scan generated metadata for P/Invoke return-value classification gaps.

The generated P/Invoke wrappers return native status codes verbatim by default
and only gain a checked `Result` wrapper when the method name is special-cased in
the generator's classification source (`windows_bindgen/src/native_helpers.cj`).
That opt-in model is safe, but it is driven by hand-maintained allowlists, so it
is hard to prove that no status-returning export was missed.

This scanner walks the metadata under `.generated/winmd-json`, enumerates every
P/Invoke export, buckets its return type, records whether the generator already
special-cases the method, and highlights *high-confidence unclassified* status
candidates: integer-returning exports from DLLs whose documented calling
convention is a direct error / sentinel status, that are not yet classified.

The output is a triage aid, not an auto-allowlist. `--check` is an opt-in gate
that is intentionally NOT wired into the default quality gate until the initial
report has been triaged into a baseline of intentionally-raw exports.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable, Iterator, Optional


ROOT = Path(__file__).resolve().parents[1]


# DLLs whose documented convention is a direct Win32/WSA error code or a sentinel
# status carried in the integer return value (rather than a thread last-error or
# a BOOL). An unclassified integer-returning export from one of these is the
# high-signal case worth a human look.
STATUS_CONVENTION_DLLS = frozenset(
    {
        "WINHTTP.dll",
        "HTTPAPI.dll",
        "DNSAPI.dll",
        "WS2_32.dll",
        "MSWSOCK.dll",
    }
)

# Return-type buckets that can carry a direct integer status and follow a manual
# (name-allowlisted) convention in the generator. HRESULT/NTSTATUS/BOOL are
# handled by type-driven rules and are deliberately excluded from the gate flag.
HIGH_CONFIDENCE_STATUS_BUCKETS = frozenset({"UInt32", "Int32", "WIN32_ERROR"})

DOCUMENTATION_ATTRIBUTE = "Windows.Win32.Foundation.Metadata.DocumentationAttribute"

# `!=` counts too: a `name != "Foo"` early-return guard ("if not this name, bail")
# still means the generator special-cases that name.
CLASSIFIED_NAME_RE = re.compile(r'(?:method\.)?name\s*[=!]=\s*"([A-Za-z0-9_]+)"')

KNOWN_HANDLE_TYPES = frozenset({"HANDLE", "SOCKET", "HINTERNET"})


@dataclass(frozen=True)
class MethodRecord:
    name: str
    namespace: str
    dll: str
    return_bucket: str
    raw_return: str
    doc_url: Optional[str]
    classified: bool

    @property
    def high_confidence_unclassified(self) -> bool:
        return is_high_confidence_unclassified(
            self.return_bucket, self.dll, self.classified
        )


def is_high_confidence_unclassified(bucket: str, dll: str, classified: bool) -> bool:
    if classified:
        return False
    if dll not in STATUS_CONVENTION_DLLS:
        return False
    return bucket in HIGH_CONFIDENCE_STATUS_BUCKETS


def raw_return_label(return_type: dict) -> str:
    """A stable human label for the raw metadata return type."""
    kind = return_type.get("Kind")
    if kind == "Primitive":
        return f"Primitive:{return_type.get('Name')}"
    if kind == "Type":
        return f"Type:{return_type.get('Name')}"
    if kind == "Pointer":
        return "Pointer"
    return kind or "None"


def classify_return_bucket(return_type: dict) -> str:
    """Normalize a metadata return type into a coarse status/value bucket."""
    kind = return_type.get("Kind")
    if kind == "Pointer":
        return "Pointer"
    if kind == "Primitive":
        name = return_type.get("Name")
        if name in ("UInt32", "Int32", "UIntPtr", "IntPtr", "Void"):
            return name
        return "OtherValue"
    if kind == "Type":
        name = return_type.get("Name") or ""
        if name == "HRESULT":
            return "HRESULT"
        if name == "NTSTATUS":
            return "NTSTATUS"
        if name == "WIN32_ERROR":
            return "WIN32_ERROR"
        if name in ("BOOL", "BOOLEAN"):
            return "BOOL"
        if name in KNOWN_HANDLE_TYPES or _looks_like_handle(name):
            return "Handle"
        return "OtherValue"
    return "OtherValue"


def _looks_like_handle(name: str) -> bool:
    # HWND, HDC, HKEY, HMENU, HICON, ... HRESULT is excluded because it is matched
    # earlier; here the leading-H heuristic alone would otherwise capture it.
    return bool(re.match(r"^H[A-Z]", name)) and name != "HRESULT"


def extract_doc_url(method: dict) -> Optional[str]:
    for attr in method.get("CustomAttributes") or []:
        if attr.get("Type") != DOCUMENTATION_ATTRIBUTE:
            continue
        for fixed in attr.get("FixedArguments") or []:
            value = fixed.get("Value")
            if isinstance(value, str) and value.startswith("http"):
                return value
    return None


def parse_classified_method_names(cj_source: str) -> set[str]:
    """Extract every method name the generator special-cases by literal compare."""
    return set(CLASSIFIED_NAME_RE.findall(cj_source))


def iter_pinvoke_methods(namespace_doc: dict) -> Iterator[tuple[str, dict]]:
    """Yield (namespace, method) for every P/Invoke export in one metadata doc."""
    for type_def in namespace_doc.get("types") or []:
        namespace = type_def.get("Namespace") or ""
        for method in type_def.get("Methods") or []:
            imp = method.get("Import")
            if not imp:
                continue
            yield namespace, method


def build_record(
    namespace: str, method: dict, classified_names: set[str]
) -> MethodRecord:
    imp = method.get("Import") or {}
    dll = (imp.get("Module") or {}).get("Name") or "?"
    return_type = (method.get("Signature") or {}).get("ReturnType") or {"Kind": None}
    name = method.get("Name") or "?"
    return MethodRecord(
        name=name,
        namespace=namespace,
        dll=dll,
        return_bucket=classify_return_bucket(return_type),
        raw_return=raw_return_label(return_type),
        doc_url=extract_doc_url(method),
        classified=name in classified_names,
    )


def scan(winmd_json_dir: Path, helpers_cj: Path) -> list[MethodRecord]:
    classified_names = parse_classified_method_names(
        helpers_cj.read_text(encoding="utf-8")
    )
    records: list[MethodRecord] = []
    for json_path in sorted(winmd_json_dir.glob("*.json")):
        try:
            doc = json.loads(json_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        if not isinstance(doc, dict) or "types" not in doc:
            continue
        for namespace, method in iter_pinvoke_methods(doc):
            records.append(build_record(namespace, method, classified_names))
    records.sort(key=lambda r: (r.dll, r.namespace, r.name))
    return records


def high_confidence_candidates(records: Iterable[MethodRecord]) -> list[MethodRecord]:
    return [r for r in records if r.high_confidence_unclassified]


def _bucket_counts(records: Iterable[MethodRecord]) -> dict[str, int]:
    return dict(Counter(r.return_bucket for r in records))


def render_markdown(records: list[MethodRecord]) -> str:
    candidates = high_confidence_candidates(records)
    counts = _bucket_counts(records)
    lines: list[str] = []
    lines.append("# Native P/Invoke return-value classification report")
    lines.append("")
    lines.append(f"Total P/Invoke exports scanned: {len(records)}")
    lines.append("")
    lines.append("## Return buckets")
    lines.append("")
    lines.append("| Bucket | Count |")
    lines.append("| --- | --- |")
    for bucket in sorted(counts, key=lambda b: (-counts[b], b)):
        lines.append(f"| {bucket} | {counts[bucket]} |")
    lines.append("")
    lines.append("## High-confidence unclassified status candidates")
    lines.append("")
    lines.append(
        "Integer-returning exports from direct-status / sentinel-convention DLLs "
        "that the generator does not yet special-case."
    )
    lines.append("")
    if not candidates:
        lines.append("None.")
    else:
        lines.append("| DLL | Namespace | Method | Return | Doc |")
        lines.append("| --- | --- | --- | --- | --- |")
        for r in candidates:
            doc = r.doc_url or ""
            lines.append(
                f"| {r.dll} | {r.namespace} | {r.name} | {r.raw_return} | {doc} |"
            )
    lines.append("")
    return "\n".join(lines)


def render_json(records: list[MethodRecord], *, include_all_records: bool = False) -> str:
    payload: dict = {
        "total": len(records),
        "bucket_counts": _bucket_counts(records),
        "high_confidence_unclassified": [
            asdict(r) for r in high_confidence_candidates(records)
        ],
    }
    if include_all_records:
        payload["records"] = [asdict(r) for r in records]
    return json.dumps(payload, indent=2, ensure_ascii=False)


def load_baseline(path: Optional[Path]) -> set[str]:
    """Method names reviewed and accepted as intentionally raw (not a regression).

    The baseline is JSON: either a list of names or an object with an `accepted`
    list (extra keys such as documentation are ignored).
    """
    if path is None:
        return set()
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        if "accepted" not in data:
            raise ValueError(f"baseline {path} object is missing an 'accepted' key")
        data = data["accepted"]
    return {str(name) for name in data}


def default_paths() -> tuple[Path, Path]:
    return (
        ROOT / ".generated" / "winmd-json",
        ROOT / "windows_bindgen" / "src" / "native_helpers.cj",
    )


def main(argv: Optional[list[str]] = None) -> int:
    default_winmd, default_helpers = default_paths()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--winmd-json-dir",
        type=Path,
        default=default_winmd,
        help="Directory of per-namespace winmd JSON (default: .generated/winmd-json)",
    )
    parser.add_argument(
        "--helpers",
        type=Path,
        default=default_helpers,
        help="Path to native_helpers.cj classification source",
    )
    parser.add_argument("--out-json", type=Path, help="Write the JSON report here")
    parser.add_argument("--out-md", type=Path, help="Write the Markdown report here")
    parser.add_argument(
        "--full-records",
        action="store_true",
        help="Include every scanned export in the JSON report (default: summary only)",
    )
    parser.add_argument(
        "--baseline",
        type=Path,
        help="Method names accepted as intentionally raw; --check ignores these",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero if non-baselined high-confidence candidates exist",
    )
    parser.add_argument("--quiet", action="store_true", help="Suppress the stdout summary")
    args = parser.parse_args(argv)

    if not args.winmd_json_dir.is_dir():
        print(f"FAIL: winmd json dir not found: {args.winmd_json_dir}", file=sys.stderr)
        return 2
    if not args.helpers.is_file():
        print(f"FAIL: helpers source not found: {args.helpers}", file=sys.stderr)
        return 2

    records = scan(args.winmd_json_dir, args.helpers)
    candidates = high_confidence_candidates(records)

    if args.out_json:
        args.out_json.write_text(
            render_json(records, include_all_records=args.full_records), encoding="utf-8"
        )
    if args.out_md:
        args.out_md.write_text(render_markdown(records), encoding="utf-8")

    if not args.quiet:
        print(f"scanned {len(records)} P/Invoke exports")
        print(f"high-confidence unclassified candidates: {len(candidates)}")
        for r in candidates:
            print(f"  {r.dll}  {r.namespace}.{r.name}  -> {r.raw_return}")

    if args.check:
        baseline = load_baseline(args.baseline)
        regressions = [r for r in candidates if r.name not in baseline]
        if regressions:
            print(
                f"FAIL: {len(regressions)} unclassified status candidate(s) "
                "not in baseline",
                file=sys.stderr,
            )
            for r in regressions:
                print(f"  {r.dll}  {r.namespace}.{r.name}  -> {r.raw_return}", file=sys.stderr)
            return 1
        print("OK: no non-baselined unclassified status candidates")

    return 0


if __name__ == "__main__":
    sys.exit(main())
