#!/usr/bin/env python3
r"""Generate per-app narrow Windows bindings and build the app against them.

Single reusable entry point for the per-app narrow-bindings flow validated by the
PoC (full 393.8 MB -> per-type narrow 111.4 MB, ~5x faster build). It runs the
whole pipeline end to end:

  1. extract   Scan the framework (windows_reactor) + app source for windows_sys
               usage and derive a precise per-type filter seed set, auto-deriving
               the two non-filterable import forms (whole-namespace `import ... as`
               and `*Vtbl` companion structs) so no hand fixups are needed.
  2. generate  Run windows_bindgen with `--filter <seed>` per seed to emit a
               narrow windows_sys (only the seeds + their transitive closure).
  3. stage     Build a temp cjpm workspace whose single `windows_sys` member IS
               the narrow one (avoids the workspace-member-injection conflict),
               and a copy of the app pointing at it, with cfg gated to exactly the
               namespaces the narrow closure defines.
  4. build     Clean-build the staged app with the gating toolchain at -j 4 (to
               dodge the GC mutator-lock watchdog under heavy parallelism), with
               cjHeapSize=32GB and cjMutatorLockTimeout=240, and report exe size +
               wall-clock time.

The real checked-in windows_sys (729 packages) and windows_reactor are NEVER
modified; everything lands in sibling `_narrow_*` / `*-narrow` directories.

Usage:
    python scripts/gen_app_narrow_bindings.py                 # defaults to 2048 demo
    python scripts/gen_app_narrow_bindings.py --app <dir>
    python scripts/gen_app_narrow_bindings.py --app <dir> --skip-build
    python scripts/gen_app_narrow_bindings.py --reuse-sys     # reuse existing narrow sys
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import stat
import subprocess
import sys
import time
from pathlib import Path

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
WCJ = Path(__file__).resolve().parents[1]                  # windows-cj
LING = WCJ.parent                                          # ling/
REACTOR_SRC = WCJ / "windows_reactor" / "src"
WINMD_DIR = WCJ / "winmd"
GENERATOR = WCJ / "windows_bindgen" / "target" / "release" / "bin" / "main.exe"
FULL_MANIFEST = WCJ / "windows_sys" / "codegen-manifest.json"
GATING = Path.home() / ".cjv" / "toolchains" / "gating"

# Known baseline numbers for the reporting table (from the PoC).
BASELINE_BYTES = 412_972_032        # full windows_sys 2048 demo exe
PER_NS_BYTES = 277_741_056          # per-namespace narrow 2048 demo exe


# --------------------------------------------------------------------------- #
# Step 1: seed extraction (hardened — auto-derives the 2 gap forms)
# --------------------------------------------------------------------------- #
NON_WINDOWS_ROOTS = {"Microsoft", "Native"}


def _reconstruct_namespace(segments: list[str]) -> str:
    """Re-add the stripped `Windows` root unless the path starts with a known
    non-Windows root (Microsoft / Native)."""
    if not segments:
        return ""
    if segments[0] in NON_WINDOWS_ROOTS:
        return ".".join(segments)
    return "Windows." + ".".join(segments)


def _load_metadata_oracle() -> tuple[set[str], set[str], dict[str, str]]:
    """Load the full windows_sys symbol universe (READ-ONLY) and derive:
      * types        — every exact type full name (incl. backtick arity, e.g.
                       `Windows.Foundation.IReference`1`).
      * namespaces   — every namespace prefix.
      * generic_map  — arity-stripped full name -> short name, so a generic type
                       imported as `Windows.Foundation.IReference` resolves to the
                       short-name filter `IReference` (bindgen matches generics by
                       arity-stripped `record.name`, not the backtick full name).
    Used to disambiguate an ambiguous `import windows_sys.A.B.C as X` (is C a type
    or a namespace?) and to pick a filter form the bindgen will actually match."""
    import json

    types: set[str] = set()
    namespaces: set[str] = set()
    generic_map: dict[str, str] = {}
    if FULL_MANIFEST.is_file():
        full = json.loads(FULL_MANIFEST.read_text(encoding="utf-8")).get("selected_symbols", [])
        for t in full:
            types.add(t)
            parts = t.split(".")
            for i in range(1, len(parts)):
                namespaces.add(".".join(parts[:i]))
            if "`" in t:
                stripped = t.split("`", 1)[0]          # IMap`2 -> ...IMap
                generic_map[stripped] = stripped.rsplit(".", 1)[-1]
    return types, namespaces, generic_map


def _app_cj_files(app_dir: Path) -> list[Path]:
    files: list[Path] = []
    for base in (REACTOR_SRC, app_dir / "src"):
        if base.exists():
            files.extend(sorted(base.rglob("*.cj")))
    return files


def extract_seeds(app_dir: Path) -> dict:
    """Return {'type_seeds', 'namespace_seeds', 'native_namespaces', 'stats'}.

    Type imports become full-name type seeds. The two non-filterable forms are
    auto-derived:
      * `*Vtbl` companion struct -> seed the parent interface (drop `Vtbl`).
      * whole-namespace `import windows_sys.A.B.C as Alias` (no brace, where
        A.B.C is a namespace not a type) -> seed the namespace.
    Enum-member pseudo-constants (`Foo_Bar`) are dropped as type seeds because the
    bindgen cannot filter them directly; their parent enum is pulled in by the
    closure of whatever references it, but to be safe we also seed the parent enum
    name (text before the first `_` in the member) when it exists as a type.
    """
    type_fullnames, namespaces_known, generic_map = _load_metadata_oracle()
    have_oracle = bool(type_fullnames)

    type_seeds: set[str] = set()
    namespace_seeds: set[str] = set()
    native_namespaces: set[str] = set()
    auto_vtbl: set[str] = set()
    auto_whole_ns: set[str] = set()
    auto_generic: set[str] = set()

    import_re = re.compile(
        r"import\s+windows_sys\.([A-Za-z0-9_.]+)\s*(?:as\s+\w+)?\s*(\{(?:[^{}]*)\})?",
        re.DOTALL,
    )

    def add_type_seed(ns: str, type_name: str) -> None:
        # Vtbl companion -> parent interface seed.
        if type_name.endswith("Vtbl") and len(type_name) > 4:
            parent = type_name[:-4]
            type_seeds.add(f"{ns}.{parent}")
            auto_vtbl.add(f"{ns}.{type_name} -> {ns}.{parent}")
            return
        full = f"{ns}.{type_name}"
        # Exact non-generic record: seed by full name.
        if not have_oracle or full in type_fullnames:
            type_seeds.add(full)
            return
        # Generic type: the metadata full name carries a backtick arity
        # (`IMap`2`), so neither the plain full name nor the namespace prefix
        # match. The bindgen matches generics by the arity-stripped short name
        # (`record.name`), so seed that.
        if full in generic_map:
            short = generic_map[full]
            type_seeds.add(short)
            auto_generic.add(f"{full} -> {short} (generic)")
            return
        # Enum-member pseudo-constant (NOT filterable). Seed parent enum if known.
        if "_" in type_name:
            parent = type_name.split("_", 1)[0]
            parent_full = f"{ns}.{parent}"
            if parent_full in type_fullnames:
                type_seeds.add(parent_full)
            elif parent_full in generic_map:
                type_seeds.add(generic_map[parent_full])
            return
        # Unknown to oracle: seed the full name and let bindgen error loudly if
        # it names no record (surfaces a real extraction gap rather than hiding it).
        type_seeds.add(full)

    for f in _app_cj_files(app_dir):
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in import_re.finditer(text):
            path = m.group(1).rstrip(".")
            brace = m.group(2)
            segments = path.split(".")
            if not segments:
                continue
            if brace:
                ns = _reconstruct_namespace(segments)
                if segments[0] == "Native":
                    native_namespaces.add(ns)
                    continue
                for item in brace.strip("{} \n\t").split(","):
                    item = item.strip()
                    if not item:
                        continue
                    type_name = item.split(" as ")[0].strip()
                    if type_name:
                        add_type_seed(ns, type_name)
            else:
                if segments[0] == "Native":
                    native_namespaces.add(_reconstruct_namespace(segments))
                    continue
                if len(segments) < 2:
                    namespace_seeds.add(_reconstruct_namespace(segments))
                    continue
                # Ambiguous: `import windows_sys.A.B.C as Alias` — C may be a type
                # OR a whole namespace (P/Invoke fns live under namespaces).
                full_candidate = _reconstruct_namespace(segments)            # treat path as namespace
                type_candidate_ns = _reconstruct_namespace(segments[:-1])
                type_candidate = f"{type_candidate_ns}.{segments[-1]}"
                if have_oracle:
                    if type_candidate in type_fullnames:
                        add_type_seed(type_candidate_ns, segments[-1])
                    elif full_candidate in namespaces_known:
                        namespace_seeds.add(full_candidate)
                        auto_whole_ns.add(full_candidate)
                    else:
                        # Unknown to oracle; fall back to type seed (bindgen will
                        # error loudly if it is not a record).
                        add_type_seed(type_candidate_ns, segments[-1])
                else:
                    # No oracle: assume type (original behaviour).
                    add_type_seed(type_candidate_ns, segments[-1])

    return {
        "type_seeds": sorted(type_seeds),
        "namespace_seeds": sorted(namespace_seeds),
        "native_namespaces": sorted(native_namespaces),
        "stats": {
            "files_scanned": len(_app_cj_files(app_dir)),
            "auto_vtbl_parents": sorted(auto_vtbl),
            "auto_whole_namespace": sorted(auto_whole_ns),
            "auto_generic_short": sorted(auto_generic),
            "oracle": have_oracle,
        },
    }


def all_filter_args(seeds: dict) -> list[str]:
    """The flat `--filter <seed>` argv list: type seeds + namespace seeds."""
    args: list[str] = []
    for s in seeds["type_seeds"]:
        args += ["--filter", s]
    for s in seeds["namespace_seeds"]:
        args += ["--filter", s]
    return args


# --------------------------------------------------------------------------- #
# Step 2: bindgen generation
# --------------------------------------------------------------------------- #
def winmd_inputs() -> list[str]:
    files = sorted(str(p) for p in WINMD_DIR.glob("*.winmd"))
    if not files:
        raise SystemExit(f"no .winmd files under {WINMD_DIR}")
    return files


def gen_env() -> dict:
    env = dict(os.environ)
    env["cjHeapSize"] = "32GB"
    return env


def generate_narrow_sys(out_dir: Path, seeds: dict) -> None:
    if not GENERATOR.is_file():
        raise SystemExit(f"generator not built: {GENERATOR}\n  build it: cd windows_bindgen && cjpm build")
    args = [
        "cjv", "run", "dev_perf_ci", str(GENERATOR),
        "--common", "--clean", "--out", str(out_dir),
        *winmd_inputs(),
        *all_filter_args(seeds),
    ]
    print(f"=== generating narrow sys -> {out_dir} ({len(seeds['type_seeds'])} type + "
          f"{len(seeds['namespace_seeds'])} ns seeds) ===", flush=True)
    r = subprocess.run(args, cwd=str(WCJ), env=gen_env())
    if r.returncode != 0:
        raise SystemExit(f"bindgen failed (exit {r.returncode}). A seed may name no record; "
                         f"check the error above and adjust the import or seed.")


def narrow_sys_symbol_count(out_dir: Path) -> int:
    import json

    m = out_dir / "codegen-manifest.json"
    if not m.is_file():
        return -1
    return len(json.loads(m.read_text(encoding="utf-8")).get("selected_symbols", []))


# --------------------------------------------------------------------------- #
# Step 3: staging (temp workspace + app variant)
# --------------------------------------------------------------------------- #
def _force_rmtree(path: Path) -> None:
    def onexc(func, p, exc):
        try:
            os.chmod(p, stat.S_IWRITE)
            func(p)
        except Exception:
            pass

    if sys.version_info >= (3, 12):
        shutil.rmtree(path, onexc=onexc)
    else:  # pragma: no cover
        shutil.rmtree(path, onerror=lambda f, p, e: onexc(f, p, e))


def narrow_cfg_all_on(narrow_sys: Path) -> tuple[str, int]:
    """Every cfg var the narrow closure defines, turned on. The per-type closure
    is already pruned to exactly the namespaces the app needs transitively, so all
    defined vars are required."""
    cfg_toml = next(narrow_sys.rglob("cfg.toml"))
    names = sorted(set(re.findall(r"^(\w+)\s*=", cfg_toml.read_text(encoding="utf-8"), re.M)))
    return ", ".join(f"{n}=on" for n in names), len(names)


def stage_workspace(narrow_sys: Path, ws: Path, scratch_names: set[str]) -> str:
    """Copy windows-cj to `ws`, dropping target/ + .git + scratch dirs + the real
    windows_sys, then drop the narrow sys in as `ws/windows_sys`. Rewire the
    in-workspace windows_reactor's windows_sys dep + cfg. Returns the cfg body."""
    if ws.exists():
        print(f"removing existing {ws.name} ...", flush=True)
        _force_rmtree(ws)

    def ignore(dir_path, names):
        drop = set()
        for n in names:
            if n in ("target", ".git", "__pycache__"):
                drop.add(n)
            if Path(dir_path) == WCJ and (n in scratch_names or n == "windows_sys"):
                drop.add(n)
        return list(drop)

    print(f"staging {ws.name} (copy of windows-cj, excl target/windows_sys) ...", flush=True)
    shutil.copytree(WCJ, ws, ignore=ignore)

    def ignore_target(dir_path, names):
        return ["target"] if "target" in names else []

    print(f"placing narrow sys as {ws.name}/windows_sys ...", flush=True)
    shutil.copytree(narrow_sys, ws / "windows_sys", ignore=ignore_target)

    cfg_body, n = narrow_cfg_all_on(narrow_sys)
    print(f"narrow cfg vars (all on): {n}", flush=True)
    rtoml = ws / "windows_reactor" / "cjpm.toml"
    txt = rtoml.read_text(encoding="utf-8")
    txt = re.sub(r'(windows_sys\s*=\s*\{\s*path\s*=\s*)"[^"]*"', r'\1"../windows_sys"', txt)
    new_override = f'override-compile-option = "--cfg=\\"{cfg_body}\\""'
    txt = re.sub(r'override-compile-option\s*=\s*"(?:\\.|[^"\\])*"', new_override, txt)
    rtoml.write_text(txt, encoding="utf-8")
    print("staged windows_reactor: windows_sys -> ../windows_sys, cfg set", flush=True)
    return cfg_body


def stage_app(app_dir: Path, app_dst: Path, ws: Path, cfg_body: str) -> None:
    if app_dst.exists():
        print(f"removing existing {app_dst.name} ...", flush=True)
        _force_rmtree(app_dst)

    def ignore(dir_path, names):
        drop = []
        for n in names:
            if n in ("target", "dist", "__pycache__", ".git") or n.endswith(".zip"):
                drop.append(n)
        return drop

    print(f"staging {app_dst.name} ...", flush=True)
    shutil.copytree(app_dir, app_dst, ignore=ignore)

    dtoml = app_dst / "cjpm.toml"
    txt = dtoml.read_text(encoding="utf-8")
    rel = os.path.relpath(ws / "windows_reactor", app_dst).replace("\\", "/")
    txt = re.sub(r'(windows_reactor\s*=\s*\{\s*path\s*=\s*)"[^"]*"', rf'\1"{rel}"', txt)
    # Preserve a trailing --disable-reflection if the app had one.
    trailing = " --disable-reflection" if "--disable-reflection" in txt else ""
    new_override = f'override-compile-option = "--cfg=\\"{cfg_body}\\"{trailing}"'
    if re.search(r'override-compile-option\s*=\s*"', txt):
        txt = re.sub(r'override-compile-option\s*=\s*"(?:\\.|[^"\\])*"', new_override, txt)
    else:
        txt = txt.replace("[dependencies]", f"  {new_override}\n\n[dependencies]", 1)
    dtoml.write_text(txt, encoding="utf-8")
    print(f"staged app: windows_reactor -> {rel}, cfg set", flush=True)


# --------------------------------------------------------------------------- #
# Step 4: build + measure
# --------------------------------------------------------------------------- #
def build_env() -> dict:
    env = dict(os.environ)
    env["CANGJIE_HOME"] = str(GATING)
    env["cjHeapSize"] = "32GB"
    env["cjMutatorLockTimeout"] = "240"
    prefix = os.pathsep.join(
        str(GATING / p)
        for p in (
            r"tools\lib", r"tools\bin", r"bin",
            r"lib\windows_x86_64_cjnative",
            r"runtime\lib\windows_x86_64_cjnative",
        )
    )
    env["PATH"] = prefix + os.pathsep + env.get("PATH", "")
    return env


def find_cjpm() -> Path:
    for cand in (GATING / "tools" / "bin" / "cjpm.exe", GATING / "bin" / "cjpm.exe"):
        if cand.is_file():
            return cand
    raise SystemExit("cjpm.exe not found in gating toolchain")


def build_and_measure(app_dst: Path, jobs: int) -> int:
    cjpm = find_cjpm()
    env = build_env()
    exe = app_dst / "target" / "release" / "bin" / "main.exe"
    log = app_dst / "_narrow_build.log"
    print(f"=== build {app_dst.name} via {cjpm} (-j {jobs}) ===", flush=True)
    t0 = time.monotonic()
    with open(log, "w", encoding="utf-8", errors="replace") as fh:
        r = subprocess.run([str(cjpm), "build", "-j", str(jobs)],
                           cwd=str(app_dst), env=env, stdout=fh, stderr=subprocess.STDOUT)
    dt = time.monotonic() - t0
    print(f"CJPM_EXIT={r.returncode}", flush=True)
    print(f"BUILD_SECONDS={dt:.1f}  ({dt / 60:.1f} min)", flush=True)
    if exe.exists():
        sz = exe.stat().st_size
        print(f"EXE_BYTES={sz}  EXE_MB={sz / 1048576:.1f}", flush=True)
        print(f"vs full  {BASELINE_BYTES / 1048576:.1f} MB  ratio={sz / BASELINE_BYTES:.3f}", flush=True)
        print(f"vs perNS {PER_NS_BYTES / 1048576:.1f} MB  ratio={sz / PER_NS_BYTES:.3f}", flush=True)
    else:
        print("EXE_MISSING — closure gap or build error. Last 60 log lines:", flush=True)
        tail = log.read_text(encoding="utf-8", errors="replace").splitlines()[-60:]
        print("\n".join(tail), flush=True)
    return r.returncode


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #
def main(argv: list[str] | None = None) -> int:
    import json

    p = argparse.ArgumentParser(description="Generate per-app narrow Windows bindings and build.")
    p.add_argument("--app", default=str(LING / "windows-reactor-2048-demo"),
                   help="App directory (default: 2048 demo).")
    p.add_argument("--narrow-sys", default=str(WCJ / "_narrow_sys_app"),
                   help="Output dir for the generated narrow windows_sys.")
    p.add_argument("--workspace", default=str(LING / "_narrow_ws_app"),
                   help="Temp staged workspace dir.")
    p.add_argument("--app-out", default="",
                   help="Staged app variant dir (default: <app>-narrow).")
    p.add_argument("--jobs", type=int, default=4, help="cjpm build parallelism (default 4).")
    p.add_argument("--reuse-sys", action="store_true",
                   help="Reuse an existing narrow sys (skip extract+generate).")
    p.add_argument("--reuse-ws", action="store_true",
                   help="Reuse an existing staged workspace + app (skip staging).")
    p.add_argument("--skip-build", action="store_true", help="Stop before building.")
    args = p.parse_args(argv)

    app_dir = Path(args.app).resolve()
    narrow_sys = Path(args.narrow_sys).resolve()
    ws = Path(args.workspace).resolve()
    app_dst = Path(args.app_out).resolve() if args.app_out else \
        app_dir.with_name(app_dir.name + "-narrow")

    if not app_dir.is_dir():
        raise SystemExit(f"app dir not found: {app_dir}")

    scratch_names = {narrow_sys.name, ws.name, app_dst.name,
                     "_narrow_sys", "_narrow_sys_bytype", "_narrow_sys_app",
                     "_narrow_ws", "_narrow_ws_bytype", "_narrow_ws_app",
                     "windows_reactor_narrow"}

    # --- Step 1+2: seeds + generate -------------------------------------- #
    if not args.reuse_sys:
        seeds = extract_seeds(app_dir)
        st = seeds["stats"]
        seeds_path = WCJ / "scripts" / "narrow_app_seeds.json"
        seeds_path.write_text(json.dumps(seeds, indent=2), encoding="utf-8")
        print(f"scanned {st['files_scanned']} .cj files (oracle={st['oracle']})", flush=True)
        print(f"type seeds: {len(seeds['type_seeds'])}  "
              f"namespace seeds: {len(seeds['namespace_seeds'])}  "
              f"native ns: {len(seeds['native_namespaces'])}", flush=True)
        if st["auto_vtbl_parents"]:
            print("AUTO-DERIVED Vtbl->parent seeds:", flush=True)
            for v in st["auto_vtbl_parents"]:
                print(f"  {v}", flush=True)
        if st["auto_whole_namespace"]:
            print("AUTO-DERIVED whole-namespace `import ... as` seeds:", flush=True)
            for v in st["auto_whole_namespace"]:
                print(f"  {v}", flush=True)
        print(f"wrote {seeds_path}", flush=True)
        generate_narrow_sys(narrow_sys, seeds)
    print(f"narrow sys symbols: {narrow_sys_symbol_count(narrow_sys)}", flush=True)

    # --- Step 3: stage --------------------------------------------------- #
    if not args.reuse_ws:
        cfg_body = stage_workspace(narrow_sys, ws, scratch_names)
        stage_app(app_dir, app_dst, ws, cfg_body)
    else:
        print("reusing existing staged workspace + app", flush=True)

    if args.skip_build:
        print("--skip-build: stopping before build.", flush=True)
        print(f"staged app: {app_dst}", flush=True)
        return 0

    # --- Step 4: build + measure ----------------------------------------- #
    return build_and_measure(app_dst, args.jobs)


if __name__ == "__main__":
    raise SystemExit(main())
