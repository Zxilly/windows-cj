#!/usr/bin/env python3
r"""Generate a trimmed Windows bindings subpackage that ships inside windows_reactor.

This reshapes `windows_reactor` to carry its OWN narrow Windows bindings as the
subpackage `windows_reactor.bindings` (code under `windows_reactor/src/bindings/`),
so the framework no longer depends on the full multi-package `windows_sys`. The
trimmed binding closure is the transitive closure of exactly the namespaces the
reactor framework imports.

Pipeline:
  1. extract  Scan windows_reactor/src for `import windows_sys.X` usage and derive
              a precise per-type filter seed set (reuses the hardened extractor in
              gen_app_narrow_bindings.py: auto-derives Vtbl->parent, whole-namespace
              `import ... as`, and generic short names).
  2. generate windows_bindgen --common --package-name windows_reactor.bindings emits
              the closure with package decls rooted at `windows_reactor.bindings.<Ns>`
              and per-namespace cfg-gated declarations, into a scratch dir.
  3. graft    Move the generated `<scratch>/src/*` into
              `windows_reactor/src/bindings/` (the dotted root name already matches
              this directory layout: a package `windows_reactor.bindings.Microsoft.UI.Xaml`
              must live at `windows_reactor/src/bindings/Microsoft/UI/Xaml/`). The
              generated standalone cjpm.toml/manifest are dropped — a subpackage
              shares the parent package's cjpm.toml.
  4. gate-on  Flip every generated cfg.toml from `X = "off"` to `X = "on"`. The
              closure is already pruned to exactly the namespaces reactor needs, so
              every defined var is required; flipping them on makes the subpackage
              self-gating with NO `--cfg` needed anywhere downstream.
  5. rewire   In the 32 winui .cj files rewrite `import windows_sys.` ->
              `import windows_reactor.bindings.`. Update windows_reactor/cjpm.toml:
              drop the windows_sys dep + the giant cfg override, add the support
              packages the closure needs (windows_strings, windows_polyfill).

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
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_app_narrow_bindings as base  # reuse seed extraction + bindgen plumbing

WCJ = Path(__file__).resolve().parents[1]
REACTOR = WCJ / "windows_reactor"
REACTOR_SRC = REACTOR / "src"
BINDINGS_DIR = REACTOR_SRC / "bindings"
WINUI_DIR = REACTOR_SRC / "winui"
SCRATCH = WCJ / "_reactor_bindings_gen"

# Support packages the generated binding closure depends on. The grafted
# subpackage shares windows_reactor's cjpm.toml, so these must be available as
# windows_reactor dependencies. Path is relative to windows_reactor/.
REQUIRED_SUPPORT = {
    "windows_core": "../windows_core",
    "windows_interface": "../windows_interface",
    "windows_libloading": "../windows_libloading",
    "windows_strings": "../windows_strings",
    "windows_polyfill": "../windows_polyfill",
}


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
# Step 1+2: seeds + generate (only scans windows_reactor/src)
# --------------------------------------------------------------------------- #
def extract_reactor_seeds() -> dict:
    """Seeds from windows_reactor/src only. base.extract_seeds scans REACTOR_SRC
    plus `<app>/src`; passing a non-existent app dir restricts it to reactor."""
    seeds = base.extract_seeds(WCJ / "__no_app__")
    (WCJ / "scripts" / "reactor_bindings_seeds.json").write_text(
        json.dumps(seeds, indent=2), encoding="utf-8"
    )
    return seeds


def generate(seeds: dict) -> None:
    if not base.GENERATOR.is_file():
        raise SystemExit(f"generator not built: {base.GENERATOR}")
    args = [
        "cjv", "run", "dev_perf_ci", str(base.GENERATOR),
        "--common", "--clean",
        "--package-name", "windows_reactor.bindings",
        "--out", str(SCRATCH),
        *base.winmd_inputs(),
        *base.all_filter_args(seeds),
    ]
    print(f"=== bindgen -> {SCRATCH} ({len(seeds['type_seeds'])} type + "
          f"{len(seeds['namespace_seeds'])} ns seeds) ===", flush=True)
    r = subprocess.run(args, cwd=str(WCJ), env=base.gen_env())
    if r.returncode != 0:
        raise SystemExit(f"bindgen failed (exit {r.returncode}).")


# --------------------------------------------------------------------------- #
# Step 3+4: graft into windows_reactor/src/bindings + flip cfg on
# --------------------------------------------------------------------------- #
def graft() -> tuple[int, int]:
    gen_src = SCRATCH / "src"
    if not gen_src.is_dir():
        raise SystemExit(f"generated src missing: {gen_src}")
    _force_rmtree(BINDINGS_DIR)
    BINDINGS_DIR.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(gen_src, BINDINGS_DIR)
    cj_count = sum(1 for _ in BINDINGS_DIR.rglob("*.cj"))

    cfg_flipped = 0
    for cfg in BINDINGS_DIR.rglob("cfg.toml"):
        txt = cfg.read_text(encoding="utf-8")
        new = re.sub(r'(\w+)\s*=\s*"off"', r'\1 = "on"', txt)
        if new != txt:
            cfg.write_text(new, encoding="utf-8")
            cfg_flipped += 1
    return cj_count, cfg_flipped


def support_deps_from_scratch() -> dict[str, str]:
    """Support package deps the generated closure declared, mapped to the path
    a windows_reactor dependency uses (../<pkg>)."""
    toml = SCRATCH / "cjpm.toml"
    deps: dict[str, str] = {}
    if toml.is_file():
        in_deps = False
        for line in toml.read_text(encoding="utf-8").splitlines():
            if line.strip() == "[dependencies]":
                in_deps = True
                continue
            if in_deps:
                m = re.match(r"\s*(\w+)\s*=", line)
                if m:
                    deps[m.group(1)] = f"../{m.group(1)}"
    return deps


# --------------------------------------------------------------------------- #
# Step 5: rewrite winui imports + windows_reactor/cjpm.toml
# --------------------------------------------------------------------------- #
def rewrite_winui_imports() -> list[str]:
    changed: list[str] = []
    pat = re.compile(r"^(\s*(?:public\s+|internal\s+|protected\s+|private\s+)?import\s+)windows_sys\.",
                     re.M)
    for f in sorted(WINUI_DIR.rglob("*.cj")):
        txt = f.read_text(encoding="utf-8")
        new = pat.sub(r"\1windows_reactor.bindings.", txt)
        if new != txt:
            f.write_text(new, encoding="utf-8")
            changed.append(str(f))
    return changed


def rewrite_reactor_cjpm(closure_deps: dict[str, str]) -> None:
    toml = REACTOR / "cjpm.toml"
    txt = toml.read_text(encoding="utf-8")

    # Drop the giant per-namespace cfg override line entirely (self-gated now).
    txt = re.sub(r'^\s*override-compile-option\s*=\s*"(?:\\.|[^"\\])*"\s*\n', "", txt, flags=re.M)

    # Drop the windows_sys dependency line.
    txt = re.sub(r'^\s*windows_sys\s*=\s*\{[^}]*\}\s*\n', "", txt, flags=re.M)

    # Ensure every required support package is present in [dependencies].
    want = dict(REQUIRED_SUPPORT)
    want.update(closure_deps)  # closure is source of truth; keep ../<pkg> form
    present = set(re.findall(r'^\s*(\w+)\s*=\s*\{\s*path', txt, flags=re.M))
    additions = []
    for name, path in sorted(want.items()):
        if name not in present:
            additions.append(f'  {name} = {{ path = "{path}" }}')
    if additions:
        # Insert after the [dependencies] header.
        txt = re.sub(r'(\[dependencies\]\s*\n)', r'\1' + "\n".join(additions) + "\n", txt, count=1)

    toml.write_text(txt, encoding="utf-8")


def rewrite_demo_cjpm(demo_dir: Path) -> bool:
    toml = demo_dir / "cjpm.toml"
    if not toml.is_file():
        return False
    txt = toml.read_text(encoding="utf-8")
    orig = txt
    # The override is `--cfg="..." [--disable-reflection]`. Strip the --cfg="..."
    # portion, keep any trailing flags (e.g. --disable-reflection).
    def strip_cfg(m: str) -> str:
        body = m
        # body is the full override value (without surrounding quotes handled by caller)
        return body

    # Match: override-compile-option = "...--cfg=\"....\" <trailing>..."
    def repl(match: re.Match) -> str:
        full = match.group(0)
        # Remove the --cfg=\"...\" chunk (escaped quotes inside).
        cleaned = re.sub(r'--cfg=\\".*?\\"\s*', "", full)
        # Collapse double spaces inside the value.
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
                   help="Reuse existing _reactor_bindings_gen (skip extract+bindgen).")
    p.add_argument("--demo", default=str(WCJ.parent / "windows-reactor-2048-demo"),
                   help="2048 demo dir to de-cfg.")
    args = p.parse_args(argv)

    if not args.reuse_gen:
        seeds = extract_reactor_seeds()
        print(f"type seeds: {len(seeds['type_seeds'])}  ns seeds: {len(seeds['namespace_seeds'])}", flush=True)
        generate(seeds)
    sym = base.narrow_sys_symbol_count(SCRATCH)
    print(f"binding symbols: {sym}", flush=True)

    cj_count, cfg_flipped = graft()
    print(f"grafted {cj_count} .cj into {BINDINGS_DIR}, flipped {cfg_flipped} cfg.toml to on", flush=True)

    closure_deps = support_deps_from_scratch()
    print(f"closure support deps: {sorted(closure_deps)}", flush=True)

    changed = rewrite_winui_imports()
    print(f"rewrote imports in {len(changed)} winui files", flush=True)

    rewrite_reactor_cjpm(closure_deps)
    print("rewrote windows_reactor/cjpm.toml (dropped windows_sys + cfg, added support pkgs)", flush=True)

    if rewrite_demo_cjpm(Path(args.demo)):
        print(f"de-cfg'd demo cjpm.toml: {args.demo}", flush=True)
    else:
        print(f"demo cjpm.toml unchanged: {args.demo}", flush=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
