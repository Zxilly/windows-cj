#!/usr/bin/env python3
r"""Generate the windows_reactor.bindings subpackage as ONE flat package.

This replaces the namespace-nested bindings layout with a single flat package
(`windows_reactor.bindings`, code under `windows_reactor/src/bindings/`). The
nested layout shards the binding closure into one subpackage per namespace, and
sibling namespaces that reference each other form import cycles; the build tool
condenses each cycle into one multi-source-package compile node that cannot use
the single-source-package incremental cache, so any downstream edit forces the
whole binding closure to recompile. A flat single package is an ordinary
incremental node, so a downstream edit recompiles only the changed file and
skips the unchanged bindings.

Pipeline:
  1. generate  windows_bindgen --common --flat --package-name windows_reactor.bindings
               emits every selected type into one package (src/symbols_*.cj +
               src/mod.cj + src/native_helpers.cj) plus a flat-name-map.json that
               records the disambiguated flat name for every full name.
  2. graft     Move the generated src/* into windows_reactor/src/bindings/. The
               standalone cjpm.toml / manifest are dropped (a subpackage shares
               the parent cjpm.toml). No cfg.toml: a flat package has no per-
               namespace gating.
  3. rewrite   Rewrite the winui .cj imports from the nested form
               `import windows_reactor.bindings.<Ns...>.{Type as Alias}` to the
               flat form `import windows_reactor.bindings.{FlatType as Alias}`,
               resolving each Type through flat-name-map.json so a disambiguated
               type points at the right declaration.
  4. cjpm      Ensure windows_reactor/cjpm.toml uses --incremental-compile (the
               flat package makes it genuinely incremental) and drop the stale
               "cannot enable incremental" comment.

The real checked-in windows_sys (729 packages) is NEVER touched.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_app_narrow_bindings as base  # reuse winmd inputs + filter plumbing

WCJ = Path(__file__).resolve().parents[1]
REACTOR = WCJ / "windows_reactor"
REACTOR_SRC = REACTOR / "src"
BINDINGS_DIR = REACTOR_SRC / "bindings"
WINUI_DIR = REACTOR_SRC / "winui"
SCRATCH = WCJ / "_reactor_flat_gen"
SEEDS_JSON = WCJ / "scripts" / "reactor_bindings_seeds.json"
FLAT_PACKAGE = "windows_reactor.bindings"


def _force_rmtree(path: Path) -> None:
    def onexc(func, p, exc):
        try:
            os.chmod(p, stat.S_IWRITE)
            func(p)
        except Exception:
            pass

    if path.exists():
        if sys.version_info >= (3, 12):
            shutil.rmtree(path, onexc=onexc)
        else:  # pragma: no cover
            shutil.rmtree(path, onerror=lambda f, p, e: onexc(f, p, e))


# --------------------------------------------------------------------------- #
# Step 1: generate flat bindings into scratch
# --------------------------------------------------------------------------- #
def load_seeds() -> dict:
    if not SEEDS_JSON.is_file():
        raise SystemExit(f"missing seeds: {SEEDS_JSON}")
    return json.loads(SEEDS_JSON.read_text(encoding="utf-8"))


def generate(seeds: dict) -> None:
    if not base.GENERATOR.is_file():
        raise SystemExit(f"generator not built: {base.GENERATOR}")
    args = [
        "cjv", "run", "dev_perf_ci", str(base.GENERATOR),
        "--common", "--clean", "--flat",
        "--package-name", FLAT_PACKAGE,
        "--out", str(SCRATCH),
        *base.winmd_inputs(),
        *base.all_filter_args(seeds),
    ]
    print(f"=== bindgen --flat -> {SCRATCH} ({len(seeds['type_seeds'])} type + "
          f"{len(seeds['namespace_seeds'])} ns seeds) ===", flush=True)
    t = time.time()
    r = subprocess.run(args, cwd=str(WCJ), env=base.gen_env())
    if r.returncode != 0:
        raise SystemExit(f"bindgen failed (exit {r.returncode}).")
    print(f"generated in {time.time() - t:.1f}s", flush=True)


# --------------------------------------------------------------------------- #
# Step 2: graft into windows_reactor/src/bindings
# --------------------------------------------------------------------------- #
def graft() -> int:
    gen_src = SCRATCH / "src"
    if not gen_src.is_dir():
        raise SystemExit(f"generated src missing: {gen_src}")
    _force_rmtree(BINDINGS_DIR)
    BINDINGS_DIR.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(gen_src, BINDINGS_DIR)
    return sum(1 for _ in BINDINGS_DIR.rglob("*.cj"))


def load_flat_name_map() -> dict[str, str]:
    """full-name -> flat-name, plus short-name lookups for namespace-qualified
    rewrites. Built from flat-name-map.json (keyed by metadata full name)."""
    j = SCRATCH / "flat-name-map.json"
    if not j.is_file():
        raise SystemExit(f"missing flat-name-map.json: {j}")
    return json.loads(j.read_text(encoding="utf-8"))


# --------------------------------------------------------------------------- #
# Step 3: rewrite winui imports nested -> flat
# --------------------------------------------------------------------------- #
# An import line is one of:
#   import windows_reactor.bindings.<Ns...>.Type
#   import windows_reactor.bindings.<Ns...>.Type as Alias
#   import windows_reactor.bindings.<Ns...>.{A, B as X, ...}     (single or multi-line)
#   import windows_reactor.bindings.Native.AppRuntime as AppRuntime  (whole-namespace alias)
#
# Flat target:
#   import windows_reactor.bindings.{FlatType, FlatB as X, ...}
#   import windows_reactor.bindings as AppRuntime  (native helpers are now top-level)
#
# Each Type is resolved through flat-name-map.json keyed by its full name
# (<Ns>.<Type>); when absent (e.g. an enum-member pseudo-constant the map does
# not carry as a type) the short name is used unchanged.

IMPORT_RE = re.compile(
    r"^(?P<indent>\s*)(?P<vis>(?:public\s+|internal\s+|protected\s+|private\s+)?)"
    r"import\s+windows_reactor\.bindings\.(?P<path>[A-Za-z0-9_.]+?)"
    r"(?:\s+as\s+(?P<alias>\w+))?"
    r"(?P<brace>\s*\{[^}]*\})?\s*$",
    re.M | re.S,
)


def _flat_for(full_name: str, short_name: str, flat_map: dict[str, str]) -> str:
    if full_name in flat_map:
        return flat_map[full_name]
    return short_name


def _reconstruct_ns(segments: list[str]) -> str:
    return ".".join(segments)


def rewrite_winui_imports(flat_map: dict[str, str]) -> tuple[list[str], int]:
    changed: list[str] = []
    rewritten = 0

    def repl(m: re.Match) -> str:
        nonlocal rewritten
        indent = m.group("indent")
        vis = m.group("vis") or ""
        path = m.group("path").rstrip(".")
        alias = m.group("alias")
        brace = m.group("brace")
        segments = path.split(".")

        # Whole-namespace alias: `import windows_reactor.bindings.<Ns...> as Alias`
        # where <Ns...> is a namespace (not a type) — the alias is used for
        # qualified access to that namespace's P/Invoke helper functions, which
        # are now top-level in the flat package. Detected by: aliased, no brace,
        # and the dotted path's leaf does not resolve to a known type
        # (`<ns>.<leaf>` absent from the flat-name map). The `Native.*` helper
        # package and the Win32 system namespaces (e.g. Win32.System.Com) take
        # this branch. Alias the flat package itself.
        if brace is None and alias:
            leaf_ns = _reconstruct_ns(segments[:-1]) if len(segments) >= 2 else ""
            leaf_full = f"{leaf_ns}.{segments[-1]}" if leaf_ns else segments[-1]
            is_type = leaf_full in flat_map
            if segments and segments[0] == "Native":
                is_type = False
            if not is_type:
                rewritten += 1
                return f"{indent}{vis}import {FLAT_PACKAGE} as {alias}"

        if brace is not None:
            # Brace list: path is the namespace; rewrite each member.
            ns = _reconstruct_ns(segments)
            items = []
            for raw in brace.strip("{} \n\t").split(","):
                item = raw.strip()
                if not item:
                    continue
                if " as " in item:
                    type_name, item_alias = (s.strip() for s in item.split(" as ", 1))
                    flat = _flat_for(f"{ns}.{type_name}", type_name, flat_map)
                    items.append(f"{flat} as {item_alias}")
                else:
                    flat = _flat_for(f"{ns}.{item}", item, flat_map)
                    # Preserve original short name as alias only when it differs,
                    # so existing references in the file keep resolving.
                    if flat != item:
                        items.append(f"{flat} as {item}")
                    else:
                        items.append(flat)
            rewritten += 1
            joined = ", ".join(items)
            return f"{indent}{vis}import {FLAT_PACKAGE}.{{{joined}}}"

        # Single dotted import: last segment is the type, the rest the namespace.
        if len(segments) < 2:
            # Bare `import windows_reactor.bindings.X` with no namespace prefix —
            # already flat-ish; leave the single name but route through the map.
            type_name = segments[0]
            flat = _flat_for(type_name, type_name, flat_map)
            tail = f" as {alias}" if alias else (f" as {type_name}" if flat != type_name else "")
            rewritten += 1
            return f"{indent}{vis}import {FLAT_PACKAGE}.{flat}{tail}"

        ns = _reconstruct_ns(segments[:-1])
        type_name = segments[-1]
        flat = _flat_for(f"{ns}.{type_name}", type_name, flat_map)
        if alias:
            tail = f" as {alias}"
        elif flat != type_name:
            # Keep the original short name as an alias so references resolve.
            tail = f" as {type_name}"
        else:
            tail = ""
        rewritten += 1
        return f"{indent}{vis}import {FLAT_PACKAGE}.{flat}{tail}"

    for f in sorted(WINUI_DIR.rglob("*.cj")):
        txt = f.read_text(encoding="utf-8")
        new = IMPORT_RE.sub(repl, txt)
        if new != txt:
            f.write_text(new, encoding="utf-8")
            changed.append(str(f))
    return changed, rewritten


# --------------------------------------------------------------------------- #
# Step 4: reactor cjpm.toml -> incremental
# --------------------------------------------------------------------------- #
def rewrite_reactor_cjpm() -> bool:
    toml = REACTOR / "cjpm.toml"
    txt = toml.read_text(encoding="utf-8")
    orig = txt
    flat_comment = (
        "  # 裁剪绑定子包 windows_reactor.bindings 现为单一扁平包（无命名空间子包、无环），\n"
        "  # 是普通单源码包增量节点：改一个消费者文件只重编该文件，绑定包不变则整体跳过。\n"
    )
    # Replace the contiguous comment block directly above compile-option (the
    # stale "cannot enable incremental" note) with the flat-layout note.
    txt, n = re.subn(
        r"(?:[ \t]*#[^\n]*\n)+(?=[ \t]*compile-option\s*=)",
        flat_comment,
        txt,
        count=1,
    )
    if n == 0:
        # No comment block above compile-option; insert the note before it.
        txt = re.sub(
            r"(?=[ \t]*compile-option\s*=)",
            flat_comment,
            txt,
            count=1,
        )
    # Ensure --incremental-compile is present in compile-option.
    def ensure_inc(m: re.Match) -> str:
        val = m.group(1)
        if "--incremental-compile" not in val:
            val = val.replace("--experimental", "--experimental --incremental-compile", 1)
            if "--incremental-compile" not in val:
                val = f"--incremental-compile {val}".strip()
        return f'compile-option = "{val}"'

    txt = re.sub(r'compile-option\s*=\s*"([^"]*)"', ensure_inc, txt, count=1)
    if txt != orig:
        toml.write_text(txt, encoding="utf-8")
        return True
    return False


def rewrite_demo_cjpm(demo_dir: Path) -> bool:
    toml = demo_dir / "cjpm.toml"
    if not toml.is_file():
        return False
    txt = toml.read_text(encoding="utf-8")
    orig = txt

    def repl(match: re.Match) -> str:
        full = match.group(0)
        cleaned = re.sub(r'--cfg=\\".*?\\"\s*', "", full)
        cleaned = re.sub(r'"\s+', '"', cleaned, count=1)
        return cleaned

    txt = re.sub(r'override-compile-option\s*=\s*"(?:\\.|[^"\\])*"', repl, txt)
    if txt != orig:
        toml.write_text(txt, encoding="utf-8")
        return True
    return False


# --------------------------------------------------------------------------- #
def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--reuse-gen", action="store_true",
                   help="Reuse existing _reactor_flat_gen (skip bindgen).")
    p.add_argument("--demo", default=str(WCJ.parent / "windows-reactor-2048-demo"),
                   help="2048 demo dir to de-cfg.")
    args = p.parse_args(argv)

    if not args.reuse_gen:
        seeds = load_seeds()
        generate(seeds)

    flat_map = load_flat_name_map()
    print(f"flat-name-map entries: {len(flat_map)}", flush=True)
    collisions = sum(1 for k, v in flat_map.items() if v != k.rsplit(".", 1)[-1])
    print(f"disambiguated (suffixed) names: {collisions}", flush=True)

    cj_count = graft()
    print(f"grafted {cj_count} .cj into {BINDINGS_DIR}", flush=True)

    changed, rewritten = rewrite_winui_imports(flat_map)
    print(f"rewrote {rewritten} import lines across {len(changed)} winui files", flush=True)

    if rewrite_reactor_cjpm():
        print("updated windows_reactor/cjpm.toml (incremental on, stale comment dropped)", flush=True)
    else:
        print("windows_reactor/cjpm.toml unchanged", flush=True)

    if rewrite_demo_cjpm(Path(args.demo)):
        print(f"de-cfg'd demo cjpm.toml: {args.demo}", flush=True)
    else:
        print(f"demo cjpm.toml unchanged: {args.demo}", flush=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
