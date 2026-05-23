#!/usr/bin/env python
"""Structural diff between a native-emitted winmd JSON and the C# golden JSON.

Compares two winmd-to-json documents (the reference C# "golden" output and the
native Cangjie emitter's output) type-by-type and field-by-field, tolerating
pure ordering / cosmetic differences and surfacing only semantic differences
(kind strings, attribute arrays, signature structure, custom-attribute values,
etc.).

Usage:
    python diff_winmd_json.py GOLDEN.json NATIVE.json [options]

Options:
    --namespaces NS[,NS...]   Only compare types in these namespaces.
    --max-diffs N             Stop after reporting N differing types (default 50).
    --ignore-comment          Treat signature "Comment" (TypeDefinition vs
                              TypeReference source marker) as equal. Useful while
                              the reader engine cannot recover the source tag.
    --ignore-header           Ignore method-signature "Header" objects.
    --summary-only            Print only the final summary, not per-type diffs.

Exit code is 0 when no semantic differences remain, 1 otherwise.

The script loads both documents fully; for very large inputs (e.g. the 200+ MB
Windows.Win32 golden) pass --namespaces to restrict the comparison and keep
memory bounded, or pre-split the golden by namespace.
"""

import argparse
import json
import sys
from collections import OrderedDict


def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def type_key(t, parent=""):
    """Stable identity for a type: dotted path of namespace+name (nested types
    are keyed by their declaring chain via the caller passing `parent`)."""
    ns = t.get("Namespace") or ""
    name = t.get("Name") or ""
    base = f"{ns}.{name}" if ns else name
    if parent:
        return f"{parent}/{name}"
    return base


def index_types(types):
    """Map top-level type identity -> type object. Duplicate identities (the C#
    tool emits nested types both inline and as top-level entries) keep the first."""
    out = OrderedDict()
    for t in types:
        key = type_key(t)
        if key not in out:
            out[key] = t
    return out


def normalize(obj, opts, in_signature=False):
    """Recursively normalize a JSON value for semantic comparison.

    - Drop fields the caller asked to ignore.
    - Leave everything else structurally intact.
    """
    if isinstance(obj, dict):
        result = {}
        # Detect whether this dict is a TType signature (has a "Kind" that is a
        # signature kind). We only strip Comment inside signatures.
        is_sig = "Kind" in obj and isinstance(obj.get("Kind"), str)
        for k, v in obj.items():
            if opts.ignore_comment and k == "Comment" and is_sig:
                continue
            if opts.ignore_header and k == "Header":
                continue
            result[k] = normalize(v, opts, in_signature=is_sig or in_signature)
        return result
    if isinstance(obj, list):
        return [normalize(v, opts, in_signature) for v in obj]
    return obj


def floats_equal(a, b):
    """True when two numbers are equal, tolerating Single (float32) rounding.

    C# System.Text.Json writes a `Single` constant using ~7-significant-digit
    round-trip formatting, while the native emitter widens to double; both encode
    the same IEEE-754 Single. Compare by collapsing each to float32 precision."""
    if a == b:
        return True
    try:
        import struct
        fa = struct.unpack("f", struct.pack("f", float(a)))[0]
        fb = struct.unpack("f", struct.pack("f", float(b)))[0]
        return fa == fb
    except (OverflowError, ValueError):
        return False


def diff_value(path, golden, native, diffs, opts):
    if type(golden) is not type(native):
        # Tolerate int/float equivalence (e.g. 1 vs 1.0) and float32 rounding.
        if isinstance(golden, (int, float)) and not isinstance(golden, bool) \
                and isinstance(native, (int, float)) and not isinstance(native, bool):
            if not floats_equal(golden, native):
                diffs.append((path, golden, native))
            return
        # Tolerate bool stored as int.
        diffs.append((path, golden, native))
        return
    if isinstance(golden, (int, float)) and not isinstance(golden, bool):
        if not floats_equal(golden, native):
            diffs.append((path, golden, native))
        return
    if isinstance(golden, dict):
        gkeys = set(golden.keys())
        nkeys = set(native.keys())
        for k in sorted(gkeys - nkeys):
            diffs.append((f"{path}.{k}", golden[k], "<MISSING>"))
        for k in sorted(nkeys - gkeys):
            diffs.append((f"{path}.{k}", "<ABSENT>", native[k]))
        for k in sorted(gkeys & nkeys):
            diff_value(f"{path}.{k}", golden[k], native[k], diffs, opts)
        return
    if isinstance(golden, list):
        if len(golden) != len(native):
            diffs.append((f"{path}[len]", len(golden), len(native)))
            # still compare overlapping prefix
        for i in range(min(len(golden), len(native))):
            diff_value(f"{path}[{i}]", golden[i], native[i], diffs, opts)
        return
    if golden != native:
        diffs.append((path, golden, native))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("golden")
    ap.add_argument("native")
    ap.add_argument("--namespaces", default="")
    ap.add_argument("--max-diffs", type=int, default=50)
    ap.add_argument("--ignore-comment", action="store_true")
    ap.add_argument("--ignore-header", action="store_true")
    ap.add_argument("--summary-only", action="store_true")
    opts = ap.parse_args()

    namespaces = set(n for n in opts.namespaces.split(",") if n)

    golden = load(opts.golden)
    native = load(opts.native)

    # Top-level scalar comparison.
    scalar_keys = ["winmd_file", "winmd_sha256", "tool_version", "schema_version", "source_set"]
    header_diffs = []
    for k in scalar_keys:
        if golden.get(k) != native.get(k):
            header_diffs.append((k, golden.get(k), native.get(k)))
    if header_diffs:
        print("== top-level scalar differences ==")
        for k, g, n in header_diffs:
            print(f"  {k}: golden={g!r} native={n!r}")

    def keep(t):
        if not namespaces:
            return True
        return (t.get("Namespace") or "") in namespaces

    gtypes = index_types([t for t in golden.get("types", []) if keep(t)])
    ntypes = index_types([t for t in native.get("types", []) if keep(t)])

    gkeys = set(gtypes)
    nkeys = set(ntypes)

    only_golden = sorted(gkeys - nkeys)
    only_native = sorted(nkeys - gkeys)

    if only_golden:
        print(f"== {len(only_golden)} types only in golden (first 20) ==")
        for k in only_golden[:20]:
            print(f"  {k}")
    if only_native:
        print(f"== {len(only_native)} types only in native (first 20) ==")
        for k in only_native[:20]:
            print(f"  {k}")

    differing_types = 0
    total_field_diffs = 0
    shown = 0
    for key in sorted(gkeys & nkeys):
        g = normalize(gtypes[key], opts)
        n = normalize(ntypes[key], opts)
        diffs = []
        diff_value(key, g, n, diffs, opts)
        if diffs:
            differing_types += 1
            total_field_diffs += len(diffs)
            if not opts.summary_only and shown < opts.max_diffs:
                shown += 1
                print(f"\n== {key} ({len(diffs)} field diffs) ==")
                for path, gv, nv in diffs[:25]:
                    print(f"  {path}\n    golden: {json.dumps(gv, ensure_ascii=False)[:200]}")
                    print(f"    native: {json.dumps(nv, ensure_ascii=False)[:200]}")

    print("\n================ SUMMARY ================")
    print(f"golden types:      {len(gkeys)}")
    print(f"native types:      {len(nkeys)}")
    print(f"only in golden:    {len(only_golden)}")
    print(f"only in native:    {len(only_native)}")
    print(f"shared types:      {len(gkeys & nkeys)}")
    print(f"differing types:   {differing_types}")
    print(f"total field diffs: {total_field_diffs}")

    if header_diffs or only_golden or only_native or differing_types:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
