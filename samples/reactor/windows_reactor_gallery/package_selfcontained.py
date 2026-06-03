#!/usr/bin/env python3
"""Assemble a self-contained, cjv-free distributable of the reactor gallery and zip it.

The release `bin/` already carries the self-contained WinUI / Windows App SDK
runtime (no framework package needed) plus the RegFree WinRT manifest, resources
and assets. What it does NOT carry is the Cangjie runtime: normally `cjv exec`
puts the active toolchain's `libcangjie-*.dll` on PATH. For a machine without the
Cangjie toolchain those DLLs must travel with the app, so this script copies the
runtime + std DLLs next to the exe (skipping the compiler-/test-only ones).

It also drops a launcher (`run-gallery.cmd`) that sets `cjStackSize=32mb` before
launching — the default 128KB Cangjie thread stack overflows on the gallery's deep
WinUI call chains, so without this the app crashes (0xC000027B).

Prerequisite on the target: Microsoft Visual C++ Redistributable (x64) — standard
for any unpackaged WinUI 3 / Windows App SDK app; the runtime DLLs are not bundled.

Usage:
  python package_selfcontained.py           # stage into dist/ (no zip)
  python package_selfcontained.py --zip      # stage + produce the .zip
"""
from __future__ import annotations
import argparse, os, shutil, sys, zipfile
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent
BIN = ROOT / "target" / "release" / "bin"
DIST = ROOT / "dist"
PKG = DIST / "windows_reactor_gallery"
ZIP = DIST / "windows_reactor_gallery_selfcontained.zip"

# Cangjie toolchain runtime-lib dir (source of libcangjie-*.dll). Honour
# CANGJIE_HOME if exported (cjv sets it), else fall back to the known toolchain.
CANGJIE_HOME = Path(os.environ.get("CANGJIE_HOME", r"C:\Users\12009\.cjv\toolchains\sts-1.1.3"))
RT_LIB = CANGJIE_HOME / "runtime" / "lib" / "windows_x86_64_cjnative"

# Compiler-/test-only Cangjie DLLs that a deployed app never loads. Excluded to
# trim ~29 MB (ast is the 23 MB compiler AST; unittest* is the test framework).
EXCLUDE_PREFIXES = ("libcangjie-std-ast", "libcangjie-std-unittest")

LAUNCHER_NAME = "run-gallery.cmd"
LAUNCHER = """@echo off
rem Reactor WinUI Gallery launcher.
rem cjStackSize: the default 128KB Cangjie thread stack overflows on the gallery's
rem deep WinUI call chains; 32mb is required or the app crashes (0xC000027B).
setlocal
set cjStackSize=32mb
start "" "%~dp0main.exe"
"""

README_NAME = "README.txt"
README = """Reactor WinUI Gallery — 自包含发行包
======================================

运行方法
--------
双击 run-gallery.cmd。
它先设置 cjStackSize=32mb 再启动 main.exe。这一步必需：默认 128KB 的仓颉线程栈
在画廊深层 WinUI 调用链上会溢出，启动即崩溃（0xC000027B）。直接双击 main.exe
而不设该变量会崩。

前提条件
--------
目标机器需安装 Microsoft Visual C++ 可再发行组件 (x64)。这是非打包 WinUI 3 /
Windows App SDK 应用的标准依赖，绝大多数 Windows 机器已自带；若缺失可从以下地址
安装：
    https://aka.ms/vs/17/release/vc_redist.x64.exe

说明
----
- 本包自带 WinUI / Windows App SDK 运行时与仓颉运行时 DLL，解压到任意目录即可
  运行，无需安装 cjv 或仓颉工具链。
- 部署方式：直接解压（xcopy 部署）。
- 若把 main.exe 改名分发，请同时把 main.exe.manifest 改成同名（RegFree WinRT
  清单按 exe 文件名匹配）。
"""


def stage() -> None:
    if PKG.exists():
        shutil.rmtree(PKG)
    PKG.mkdir(parents=True)

    # 1) the whole self-contained bin (exe + WinUI/AppSDK DLLs + manifest + resources + assets)
    print(f"copying bin/ -> {PKG} ...", flush=True)
    shutil.copytree(BIN, PKG, dirs_exist_ok=True)

    # 2) Cangjie runtime + std DLLs (minus compiler/test-only)
    if not RT_LIB.is_dir():
        raise SystemExit(f"Cangjie runtime lib dir not found: {RT_LIB}")
    copied = skipped = 0
    for dll in sorted(RT_LIB.glob("*.dll")):
        if dll.name.startswith(EXCLUDE_PREFIXES):
            skipped += 1
            continue
        shutil.copy2(dll, PKG / dll.name)
        copied += 1
    print(f"cangjie runtime DLLs: copied {copied}, skipped {skipped} (compiler/test-only)", flush=True)

    # 3) launcher that sets cjStackSize
    (PKG / LAUNCHER_NAME).write_text(LAUNCHER, encoding="ascii")
    print(f"wrote launcher: {LAUNCHER_NAME}", flush=True)

    # 4) end-user README
    (PKG / README_NAME).write_text(README, encoding="utf-8")
    print(f"wrote readme: {README_NAME}", flush=True)

    files = list(PKG.rglob("*"))
    total = sum(f.stat().st_size for f in files if f.is_file())
    print(f"staged: {sum(1 for f in files if f.is_file())} files, {total/1024/1024:.1f} MB at {PKG}", flush=True)


def make_zip() -> None:
    if ZIP.exists():
        ZIP.unlink()
    print(f"zipping -> {ZIP} (deflate) ...", flush=True)
    n = 0
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for f in sorted(PKG.rglob("*")):
            if f.is_file():
                zf.write(f, f.relative_to(PKG.parent))
                n += 1
    print(f"wrote {ZIP}  ({n} entries, {ZIP.stat().st_size/1024/1024:.1f} MB)", flush=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--zip", action="store_true", help="also produce the .zip after staging")
    args = ap.parse_args()
    stage()
    if args.zip:
        make_zip()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
