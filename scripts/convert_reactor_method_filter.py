#!/usr/bin/env python3
r"""Convert the reference projection's method-level binding manifest into the
windows-cj `--filter` rule set.

Background
----------
The reference WinUI reactor projection trims bindings at *method* granularity:
its manifest (vendored in-tree as `scripts/reactor_method_manifest.txt`) lists,
per type, only the specific members
the framework actually calls, e.g.

    Microsoft.UI.Xaml.Controls.IButton::{put_Flyout, get_Flyout}
    Microsoft.UI.Xaml.Controls.Button::{CreateInstance}
    Microsoft.UI.Xaml.ElementTheme                       (whole type, no members)

windows-cj's bindgen already supports member-level filtering. Its `--filter`
rule grammar (see `windows_bindgen/src/main.cj` `selectionPatternMatchesMember`)
matches a member by EXACT dotted full name `Type.member` (NOT the `::{...}`
group syntax), and a record is pulled in + pruned to exactly the named members
whenever at least one member rule for it is supplied (`filterRecordMembers`:
`matchedMembers == 0` -> keep whole type). A type with no member rule stays a
whole-type seed.

So the conversion is:

    Type::{m1, m2}   ->   Type.m1   Type.m2          (member-level rules)
    Type::*          ->   Type                        (whole type)
    Type             ->   Type                        (whole type)

with three projection-specific fixups:

  * Namespace prefixes already line up (the reference manifest and the
    windows-cj winmd both use `Microsoft.UI.Xaml...` and `Windows...`), so no
    rewrite is needed for those.

  * `extras.*` lines reference a synthetic `extras.winmd` the reference build
    fabricates. windows-cj does NOT use that winmd; the same capabilities are
    reached differently:
      - ISwapChainPanelNative  -> the real Win32 metadata type
        `Windows.Win32.System.WinRT.Xaml.ISwapChainPanelNative` (used via a
        hand-written vtbl call in winui/swap_chain.cj).
      - IWindowNative          -> NOT used as a binding (WindowHandle is a
        hand-written class that does not project IWindowNative). Dropped.
      - MddBootstrap* / WINDOWSAPPSDK_* -> reached through the hand-written
        `Native.AppRuntime` P/Invoke surface, not a winmd binding. Dropped from
        the filter; they are pulled in by the separate native-helper path.

  * A handful of types the windows-cj host needs whole (CCW factory/overrides
    and projected generics) are force-kept as whole-type seeds even though the
    reference manifest lists them with member rules or `--implement`. These are
    listed in WHOLE_TYPE_OVERRIDES below; the windows-cj host reads their full
    vtbl/iid surface by hand rather than through `--implement` generation.

The script emits `scripts/reactor_method_filter.json` with:
    { "filters": [ ... ordered --filter rule list ... ],
      "namespace_seeds": [ ... ],
      "native_namespaces": [ ... ],
      "stats": { ... } }

`build_reactor_bindings_flat.py` consumes `filters` directly as the
`--filter <rule>` argv list.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

WCJ = Path(__file__).resolve().parents[1]
LING = WCJ.parent
# Vendored copy of the reference projection's method-level binding manifest
# (one `Namespace.Type::{members}` rule per line). Kept in-tree so the converter
# is self-contained and does not reach into the external read-only reference.
REACTOR_TXT = WCJ / "scripts" / "reactor_method_manifest.txt"
SEEDS_JSON = WCJ / "scripts" / "reactor_bindings_seeds.json"
FULL_MANIFEST = WCJ / "windows_sys" / "codegen-manifest.json"
OUT_JSON = WCJ / "scripts" / "reactor_method_filter.json"

# Activation members the reference manifest pins on a runtime class. In the
# windows-cj metadata these live on the class's *factory* interface, not the
# runtime class type, so a `RuntimeClass.CreateInstance` member rule matches no
# member. The runtime class is instead kept whole (its activation + factory
# closure is pulled in, and its instance methods are still trimmed because they
# are projected from the (separately method-trimmed) interface records).
ACTIVATION_MEMBERS = {
    "CreateInstance",
    "CreateInstanceWithSymbol",
    "CreateInstanceWithName",
    "CreateUri",
}

# windows-cj's bindgen cannot filter a free function / constant by name; they are
# only reachable by seeding the whole containing namespace. The reference manifest
# lists Win32 free functions across several namespaces, but the windows-cj winui
# layer only actually calls into these two (the rest are for features it
# implements differently or not at all). So we pull ONLY these namespaces whole;
# any other reference Win32 free-fn line is dropped (its feature is unused).
# Real Win32 *types* (HWND, LPARAM, ...) are matchable by name and stay as
# whole-type rules regardless of this list.
WIN32_FREE_FN_NAMESPACES = {
    "Windows.Win32.System.Com",   # CoInitializeEx / CoUninitialize / COINIT_*
    "Windows.Win32.UI.HiDpi",     # SetProcessDpiAwarenessContext / DPI_AWARENESS_*
}

# extras.* -> windows-cj filter rule (None = drop; reached via another path).
EXTRAS_MAP: dict[str, str | None] = {
    "ISwapChainPanelNative": "Windows.Win32.System.WinRT.Xaml.ISwapChainPanelNative",
    "IWindowNative": None,  # WindowHandle is hand-written; no IWindowNative binding.
    # MddBootstrap* and WINDOWSAPPSDK_* live behind Native.AppRuntime P/Invoke.
    "MddBootstrapInitialize2": None,
    "MddBootstrapInitializeOptions": None,
    "MddBootstrapInitializeOptions_OnNoMatch_ShowUI": None,
    "MddBootstrapInitializeOptions_OnPackageIdentity_NOOP": None,
    "MddBootstrapShutdown": None,
    "WINDOWSAPPSDK_RELEASE_MAJORMINOR": None,
    "WINDOWSAPPSDK_RELEASE_VERSION_TAG_W": None,
    "WINDOWSAPPSDK_RUNTIME_VERSION_UINT64": None,
}

# Types the windows-cj host needs whole (full vtbl/iid by hand, not --implement),
# regardless of any member rules in the reference manifest. Kept as whole-type
# seeds. (Generic short-name forms handled separately.)
WHOLE_TYPE_OVERRIDES: set[str] = {
    "Microsoft.UI.Xaml.IApplicationOverrides",
    "Microsoft.UI.Xaml.Markup.IXamlMetadataProvider",
    "Microsoft.UI.Xaml.Markup.IXamlType",
    "Microsoft.UI.Xaml.IApplication",
}

# Generic projected types: the reference manifest names them by full name but the
# windows-cj bindgen matches generics by arity-stripped short name (record.name).
# These come from the existing seeds' generic handling; keep the short-name form.
GENERIC_SHORT = {
    "Windows.Foundation.Collections.IMap": "IMap",
    "Windows.Foundation.Collections.IVector": "IVector",
    "Windows.Foundation.IReference": "IReference",
    "Windows.Foundation.EventHandler": "EventHandler",
    "Windows.Foundation.TypedEventHandler": "TypedEventHandler",
}


def parse_reactor_txt(path: Path) -> tuple[dict[str, set[str] | None], list[str]]:
    """Return (type -> members-or-None, ordered type list).

    members == None  => whole type (no `::` or `::*`).
    members == set()  => appeared only with `::{}` empties (treated whole).
    members == {..}   => member-level rules.
    `extras.*` entries are folded into the returned dict already mapped/dropped.
    """
    members: dict[str, set[str] | None] = {}
    order: list[str] = []

    def note(t: str) -> None:
        if t not in members:
            order.append(t)

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue

        # extras.* fixup
        if line.startswith("extras."):
            body = line[len("extras."):]
            type_part = body.split("::", 1)[0]
            mapped = EXTRAS_MAP.get(type_part, "__UNKNOWN__")
            if mapped == "__UNKNOWN__":
                raise SystemExit(f"unmapped extras entry: {line}")
            if mapped is None:
                continue
            # extras entries carry no member rules we honor (ISwapChainPanelNative
            # is consumed via hand-written vtbl), so keep the mapped type whole.
            note(mapped)
            if members.get(mapped) is None:
                members[mapped] = None
            continue

        if "::" in line:
            t, rest = line.split("::", 1)
            rest = rest.strip()
            note(t)
            if rest == "*":
                # whole type
                members.setdefault(t, None)
                if members.get(t) == set():
                    members[t] = None
            elif rest.startswith("{"):
                ms = {m.strip() for m in rest.strip("{} ").split(",") if m.strip()}
                cur = members.get(t)
                if cur is None and t in members:
                    # already whole; whole wins
                    pass
                else:
                    members.setdefault(t, set())
                    if members[t] is not None:
                        members[t] |= ms
            else:
                members.setdefault(t, None)
        else:
            note(line)
            members.setdefault(line, None)

    return members, order


def load_metadata_oracle() -> tuple[set[str], set[str]]:
    """(type full names, namespace prefixes) from the full windows_sys manifest.

    Used to classify a reference member rule `Parent.member`:
      * Parent is a type      -> member rule (or activation -> whole type).
      * Parent is a namespace  -> the member is a free function / constant; pull
                                  the whole namespace as a namespace seed.
    """
    types: set[str] = set()
    namespaces: set[str] = set()
    if FULL_MANIFEST.is_file():
        full = json.loads(FULL_MANIFEST.read_text(encoding="utf-8")).get("selected_symbols", [])
        for t in full:
            base = t.split("`", 1)[0]  # strip generic arity
            types.add(base)
            parts = base.split(".")
            for i in range(1, len(parts)):
                namespaces.add(".".join(parts[:i]))
    return types, namespaces


def to_filter_rules(
    members: dict[str, set[str] | None],
    order: list[str],
    type_set: set[str],
    ns_set: set[str],
) -> tuple[list[str], set[str], set[str], dict[str, str]]:
    """Return (ordered rule list, member-rule set, extra namespace seeds,
    reclassification notes).

    Member rules are resolved against the metadata oracle:
      * activation member on a runtime class -> whole-type the class.
      * member whose parent is a namespace (free fn/const) -> namespace seed.
      * otherwise kept as a `Type.member` member rule.
    """
    rules: list[str] = []
    member_rules: set[str] = set()
    ns_seeds: set[str] = set()
    notes: dict[str, str] = {}
    whole_typed: set[str] = set()

    def add_whole(t: str) -> None:
        if t not in whole_typed and t not in rules:
            rules.append(t)
            whole_typed.add(t)

    for t in order:
        ms = members[t]
        if t in GENERIC_SHORT:
            add_whole(GENERIC_SHORT[t])
            continue
        if t in WHOLE_TYPE_OVERRIDES:
            add_whole(t)
            continue
        if ms is None or not ms:
            # bare dotted name with no member rules. If it is a known type, keep
            # it whole. If it is NOT a type but its parent IS a namespace, it is a
            # free function / constant (the reference manifest lists these as bare
            # `Namespace.Func` names) -> pull the whole namespace as a seed.
            if t in type_set:
                add_whole(t)
            else:
                parent = t.rsplit(".", 1)[0] if "." in t else ""
                if parent and parent in ns_set and parent not in type_set:
                    # free function / constant. Only pull the namespace if the
                    # winui layer actually uses it; otherwise drop (unused feature).
                    if parent in WIN32_FREE_FN_NAMESPACES or not parent.startswith("Windows.Win32."):
                        ns_seeds.add(parent)
                        notes[t] = f"namespace seed {parent} (free fn/const)"
                    else:
                        notes[t] = f"dropped (unused Win32 free fn in {parent})"
                else:
                    # unknown to oracle (e.g. enum member pseudo-name) — keep as a
                    # whole-type rule and let bindgen report loudly if unmatched.
                    add_whole(t)
            continue

        parent_is_type = t in type_set
        parent_is_ns = (not parent_is_type) and (t in ns_set)

        if parent_is_ns:
            # free functions / constants -> whole namespace seed (allowlisted)
            if t in WIN32_FREE_FN_NAMESPACES or not t.startswith("Windows.Win32."):
                ns_seeds.add(t)
                notes[t] = "namespace seed (free fn/const)"
            else:
                notes[t] = f"dropped (unused Win32 free fn namespace {t})"
            continue

        for m in sorted(ms):
            if m in ACTIVATION_MEMBERS:
                # activation member lives on the factory, not the class type.
                add_whole(t)
                notes[f"{t}.{m}"] = "whole-type (activation on factory)"
                continue
            rule = f"{t}.{m}"
            rules.append(rule)
            member_rules.add(rule)

    return rules, member_rules, ns_seeds, notes


def main() -> int:
    if not REACTOR_TXT.is_file():
        raise SystemExit(f"missing reference manifest: {REACTOR_TXT}")

    members, order = parse_reactor_txt(REACTOR_TXT)

    # carry over the windows-cj-specific whole-type seeds + factories that the
    # reference manifest does not list (host CCW factories, projected base
    # classes, generics, etc.). Sourced from the existing integral seeds minus
    # anything already covered by the reference manifest.
    existing = json.loads(SEEDS_JSON.read_text(encoding="utf-8"))
    existing_types = list(existing["type_seeds"])
    namespace_seeds = list(existing["namespace_seeds"])
    native_namespaces = list(existing["native_namespaces"])

    covered = set(members.keys()) | set(GENERIC_SHORT.values())
    # also treat the generic full-name keys as covered
    covered |= set(GENERIC_SHORT.keys())

    extra_whole: list[str] = []
    for t in existing_types:
        if t in covered:
            continue
        # generic short names already present in reference via GENERIC_SHORT
        if t in ("IMap", "IVector", "IReference", "EventHandler", "TypedEventHandler"):
            continue
        extra_whole.append(t)

    type_set, ns_set = load_metadata_oracle()
    if not type_set:
        raise SystemExit(f"metadata oracle empty; need {FULL_MANIFEST}")

    rules, member_rules, derived_ns, notes = to_filter_rules(members, order, type_set, ns_set)
    # append windows-cj-only whole-type seeds not in the reference manifest
    for t in extra_whole:
        if t not in rules:
            rules.append(t)

    # merge namespace seeds: existing + reference-derived (free fn/const lines)
    for ns in sorted(derived_ns):
        if ns not in namespace_seeds:
            namespace_seeds.append(ns)

    method_rules = [r for r in rules if r in member_rules]
    whole_rules = [r for r in rules if r not in member_rules]

    out = {
        "filters": rules,
        "namespace_seeds": namespace_seeds,
        "native_namespaces": native_namespaces,
        "stats": {
            "reference_manifest": REACTOR_TXT.name,
            "total_filter_rules": len(rules),
            "member_level_rules": len(method_rules),
            "whole_type_rules": len(whole_rules),
            "namespace_seeds": len(namespace_seeds),
            "derived_namespace_seeds": sorted(derived_ns),
            "types_with_member_rules": sum(1 for t, m in members.items() if m),
            "types_whole": sum(1 for t, m in members.items() if not m),
            "windows_cj_only_whole_seeds": sorted(extra_whole),
            "reclassifications": notes,
        },
    }
    OUT_JSON.write_text(json.dumps(out, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"wrote {OUT_JSON}")
    print(f"  total filter rules : {len(rules)}")
    print(f"  member-level rules : {len(method_rules)}")
    print(f"  whole-type rules   : {len(whole_rules)}")
    print(f"  namespace seeds    : {len(namespace_seeds)} ({sorted(namespace_seeds)})")
    print(f"  derived ns seeds   : {sorted(derived_ns)}")
    print(f"  windows-cj-only whole seeds carried over: {len(extra_whole)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
