#!/usr/bin/env python3
"""Rebuild bindgen, regenerate sys, then clean+build sys."""
import os
import subprocess
import sys

BINDGEN = r"E:\Project\CS_Project\2026\ling\windows-cj\windows-bindgen"
SYS = r"E:\Project\CS_Project\2026\ling\windows-cj\windows-sys"

env = dict(os.environ)
env["cjHeapSize"] = "16gb"


def run(cmd, cwd, capture=False):
    print(f"=== {cwd} :: {' '.join(cmd)} ===", flush=True)
    if capture:
        return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)
    return subprocess.run(cmd, cwd=cwd, env=env)


print("[1/4] build bindgen")
res = run(["cjpm", "build"], BINDGEN)
if res.returncode != 0:
    print("bindgen build failed", flush=True)
    sys.exit(1)

print("[2/4] regen")
res = run([
    "cjpm", "run", "--",
    "--in", "../winmd/Windows.Win32.winmd",
    "--in", "../winmd/Windows.winmd",
    "--in", "../winmd/Windows.Wdk.winmd",
    "--out", "../windows-sys/src",
    "--sys",
], BINDGEN)
if res.returncode != 0:
    print("regen failed", flush=True)
    sys.exit(1)

print("[3/4] clean sys")
run(["cjpm", "clean"], SYS, capture=True)

print("[4/4] build sys")
log_path = os.path.join(SYS, "build_errors.log")
with open(log_path, "w") as log:
    res = subprocess.run(["cjpm", "build", "-j", "1"], cwd=SYS, env=env, stderr=log)
print(f"sys cjpm exit: {res.returncode}", flush=True)

with open(log_path) as f:
    text = f.read()
err_lines = [l for l in text.splitlines() if l.startswith("error")]
print(f"error count: {len(err_lines)}", flush=True)
counts = {}
for l in err_lines:
    counts[l] = counts.get(l, 0) + 1
for line, n in sorted(counts.items(), key=lambda x: -x[1])[:10]:
    print(f"  {n}\t{line}", flush=True)
