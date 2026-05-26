#!/usr/bin/env python
"""Benchmark and parity harness for the native .winmd reader vs the JSON path.

Drives the built bindgen binary directly (with the Cangjie runtime DLL dir on
PATH so it does not hit the 0xC0000135 missing-DLL failure) and measures
end-to-end generation time for the two front-ends:

    JSON path    : <Namespace>.json   (representative of the C# pipeline output,
                   i.e. the cost *after* the converter has already produced JSON)
    native path  : <metadata>.winmd   (the native reader -> model -> .cj)

When WINDOWS_CJ_BENCH=1 is set, the bindgen binary additionally prints per-phase
timings to stderr ("native winmd parse+adapt", "buildSymbolRecords",
"generate"), which this harness captures and tabulates.

Modes
-----
  bench   : run the timing matrix (WinRT/Win32 x single/large feature x
            native/json) and print a comparison table.
  parity  : regenerate a fixed set of namespaces via both front-ends and run
            scripts/diff_generated_cj.py to assert byte-for-byte equality.
  both    : parity first (correctness gate), then bench (default).

Usage
-----
  python scripts/bench_winmd.py [bench|parity|both] [--repeat N] [--keep]

The output directories live under windows_bindgen/.generated/bench and are
cleaned at the end unless --keep is passed.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG = os.path.join(REPO, "windows_bindgen")
EXE = os.path.join(PKG, "target", "release", "bin", "windows_bindgen.exe")
RUNTIME = r"C:\Users\12009\.cjv\toolchains\sts-1.1.0\runtime\lib\windows_x86_64_cjnative"
DIFF = os.path.join(REPO, "scripts", "diff_generated_cj.py")

# Metadata sources. JSON files are the C#-converted documents (one per winmd);
# winmd files are the raw inputs parsed natively.
WINMD = {
    "winrt": os.path.join(REPO, "winmd", "Windows.winmd"),
    "win32": os.path.join(REPO, "winmd", "Windows.Win32.winmd"),
}
JSON = {
    "winrt": os.path.join(REPO, ".generated", "winmd-json-all", "Windows.json"),
    "win32": os.path.join(REPO, ".generated", "winmd-json-all", "Windows.Win32.json"),
}

OUT_ROOT = os.path.join(PKG, ".generated", "bench")

PHASE_RE = re.compile(r"\[bench\]\s+(.*?):\s+(\d+)\s+ms")


def make_env(bench=False):
    env = dict(os.environ)
    env["PATH"] = RUNTIME + os.pathsep + env.get("PATH", "")
    env["cjHeapSize"] = "32GB"
    if bench:
        env["WINDOWS_CJ_BENCH"] = "1"
    return env


def run_gen(source, features, out_abs, bench=True):
    """Run one generation. Returns (wall_seconds, phases_dict, ok)."""
    args = [EXE, source]
    for f in features:
        args += ["--feature", f]
    args += ["--out", out_abs, "--clean"]
    t0 = time.time()
    p = subprocess.run(args, cwd=PKG, env=make_env(bench), capture_output=True, text=True)
    dt = time.time() - t0
    if p.returncode != 0:
        print(f"  GEN FAILED rc={p.returncode}")
        print("  stderr:", (p.stderr or "")[-800:])
        return dt, {}, False
    phases = {m.group(1).strip(): int(m.group(2)) for m in PHASE_RE.finditer(p.stderr or "")}
    return dt, phases, True


# Bench matrix: (label, source_key, [features]).
# single-feature = one namespace; large = a broad namespace prefix tree.
BENCH_CASES = [
    ("WinRT single (Foundation)", "winrt", ["Windows.Foundation"]),
    ("WinRT large (UI + Foundation + Data)", "winrt",
     ["Windows.UI", "Windows.Foundation", "Windows.Data.Json",
      "Windows.Foundation.Collections", "Windows.Storage.Streams"]),
    ("Win32 single (System.Com)", "win32", ["Windows.Win32.System.Com"]),
    ("Win32 large (Com+Foundation+Threading+Memory+Registry)", "win32",
     ["Windows.Win32.System.Com", "Windows.Win32.Foundation",
      "Windows.Win32.System.Threading", "Windows.Win32.System.Memory",
      "Windows.Win32.System.Registry"]),
]

# Parity cases: P3-covered namespaces. byte-for-byte equality required.
PARITY_CASES = [
    ("win32-com", "win32", ["Windows.Win32.System.Com"]),
    ("win32-foundation", "win32", ["Windows.Win32.Foundation"]),
    ("winrt-foundation", "winrt", ["Windows.Foundation"]),
]


def cmd_bench(repeat):
    print("=" * 78)
    print("BENCH: native .winmd vs JSON path (wall seconds; phase ms in [...])")
    print("=" * 78)
    rows = []
    for label, key, feats in BENCH_CASES:
        for path_name, source in (("native", WINMD[key]), ("json", JSON[key])):
            best = None
            best_phases = {}
            for _ in range(repeat):
                out = os.path.join(OUT_ROOT, f"{key}-{path_name}")
                dt, phases, ok = run_gen(source, feats, out, bench=True)
                if not ok:
                    best = None
                    break
                if best is None or dt < best:
                    best = dt
                    best_phases = phases
            rows.append((label, path_name, best, best_phases))
            disp = f"{best:.2f}s" if best is not None else "FAIL"
            extra = ""
            if best_phases:
                parts = []
                for k in ("native winmd parse+adapt", "json parse",
                          "buildSymbolRecords", "generate (symbols -> .cj)"):
                    if k in best_phases:
                        parts.append(f"{k.split('(')[0].strip()}={best_phases[k]}ms")
                extra = "  [" + ", ".join(parts) + "]"
            print(f"  {label:32s} {path_name:7s} {disp:>8s}{extra}")
    print("\nSummary table")
    print(f"  {'case':32s} {'native':>9s} {'json':>9s} {'native/json':>12s}")
    by = {}
    for label, path_name, best, _ in rows:
        by.setdefault(label, {})[path_name] = best
    for label in [c[0] for c in BENCH_CASES]:
        n = by[label].get("native")
        j = by[label].get("json")
        ratio = f"{n / j:.2f}x" if (n and j) else "-"
        ns = f"{n:.2f}s" if n else "FAIL"
        js = f"{j:.2f}s" if j else "FAIL"
        print(f"  {label:32s} {ns:>9s} {js:>9s} {ratio:>12s}")
    return 0


def cmd_parity():
    print("=" * 78)
    print("PARITY: native .winmd vs JSON path must be byte-for-byte identical")
    print("=" * 78)
    all_ok = True
    for name, key, feats in PARITY_CASES:
        out_a = os.path.join(OUT_ROOT, f"{name}-json")
        out_b = os.path.join(OUT_ROOT, f"{name}-native")
        print(f"\n### {name}: {', '.join(feats)}")
        _, _, ok_a = run_gen(JSON[key], feats, out_a, bench=False)
        _, _, ok_b = run_gen(WINMD[key], feats, out_b, bench=False)
        if not (ok_a and ok_b):
            print("  generation failed")
            all_ok = False
            continue
        dp = subprocess.run([sys.executable, DIFF, out_a, out_b,
                             "--max-files", "8", "--show-diff-lines", "60"],
                            capture_output=True, text=True)
        print(dp.stdout[-2500:])
        if dp.returncode != 0:
            all_ok = False
            print(f"  PARITY FAIL ({name})")
        else:
            print(f"  PARITY OK ({name})")
    print("\n" + "=" * 78)
    print("PARITY RESULT:", "ALL IDENTICAL" if all_ok else "DIFFERENCES FOUND")
    return 0 if all_ok else 1


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("mode", nargs="?", default="both", choices=["bench", "parity", "both"])
    ap.add_argument("--repeat", type=int, default=1, help="bench repeats; best wall time kept")
    ap.add_argument("--keep", action="store_true", help="keep generated bench output dirs")
    opts = ap.parse_args()

    if not os.path.exists(EXE):
        print(f"binary not found: {EXE}\nbuild first: cjpm build (in windows_bindgen)")
        return 2

    rc = 0
    try:
        if opts.mode in ("parity", "both"):
            rc = cmd_parity()
            if rc != 0 and opts.mode == "both":
                print("\nparity failed; skipping bench")
                return rc
        if opts.mode in ("bench", "both"):
            rc = cmd_bench(opts.repeat) or rc
    finally:
        if not opts.keep and os.path.isdir(OUT_ROOT):
            shutil.rmtree(OUT_ROOT, ignore_errors=True)
    return rc


if __name__ == "__main__":
    sys.exit(main())
