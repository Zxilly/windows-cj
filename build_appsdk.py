#!/usr/bin/env python3
"""Generate WebView2 and Windows App SDK Cangjie bindings from NuGet metadata."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import prepare_nuget_metadata


ROOT = Path(__file__).resolve().parent
BINDGEN = ROOT / "windows-bindgen"
WINMD_INPUTS = (
    ROOT / "winmd" / "Windows.Win32.winmd",
    ROOT / "winmd" / "Windows.winmd",
    ROOT / "winmd" / "Windows.Wdk.winmd",
)

ENV = dict(os.environ)
ENV["cjHeapSize"] = os.environ.get("cjHeapSize", "32GB")


def default_jobs() -> int:
    raw = os.environ.get("BINDGEN_JOBS")
    if raw:
        try:
            jobs = int(raw)
        except ValueError:
            jobs = 0
        if jobs <= 0:
            raise SystemExit("BINDGEN_JOBS must be a positive integer")
        return jobs
    return max(1, os.cpu_count() or 1)


def run(command: list[str], cwd: Path) -> None:
    print(f"=== {cwd} :: {' '.join(command)} ===", flush=True)
    result = subprocess.run(command, cwd=cwd, env=ENV, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def prepare_metadata(args: argparse.Namespace) -> Path:
    metadata_path = args.metadata_out or (
        ROOT / "target" / "nuget-metadata" / f"windows-appsdk-{args.appsdk_version}.json"
    )
    command = [
        sys.executable,
        str(ROOT / "prepare_nuget_metadata.py"),
        "--appsdk-version",
        args.appsdk_version,
        "--cache",
        str(args.cache),
        "--metadata-out",
        str(metadata_path),
        "--version-cj-out",
        str(ROOT / "windows-appsdk" / "src" / "version.cj"),
    ]
    if args.webview2_version:
        command.extend(["--webview2-version", args.webview2_version])
    if args.force_nuget:
        command.append("--force")
    run(command, ROOT)
    return metadata_path


def clean_generated_package(package_root: Path) -> None:
    src = package_root / "src"
    for namespace_root in ("Microsoft",):
        path = src / namespace_root
        if path.exists():
            shutil.rmtree(path)
    for artifact in ("cfg_list.toml", "features.toml", "link-options.toml", "features.json"):
        (package_root / artifact).unlink(missing_ok=True)


def bindgen_command(
    output_dir: Path,
    mode: str,
    metadata_inputs: list[str],
    filters: list[str],
    references: list[str],
    jobs: int,
) -> list[str]:
    command = ["cjv", "exec", "cjpm", "run", "--"]
    for winmd in WINMD_INPUTS:
        command.extend(["--in", str(winmd)])
    for winmd in metadata_inputs:
        command.extend(["--in", winmd])
    command.extend(["--out", str(output_dir)])
    if mode == "sys":
        command.append("--sys")
    else:
        command.extend(["--no-sys", "--high-level"])
    for namespace_filter in filters:
        command.extend(["--filter", namespace_filter])
    for reference in references:
        command.extend(["--reference", reference])
    command.extend(["--jobs", str(jobs)])
    return command


def generate_bindings(metadata_path: Path, jobs: int, skip_bindgen_build: bool) -> None:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    webview2_winmds = list(metadata["inputs"]["webview2_winmds"])
    appsdk_winmds = list(metadata["inputs"]["appsdk_winmds"])

    if not skip_bindgen_build:
        run(["cjv", "exec", "cjpm", "build"], BINDGEN)

    generations = [
        (
            ROOT / "windows-webview2-sys",
            "sys",
            webview2_winmds,
            ["Microsoft.Web.WebView2"],
            ["windows_sys,skip-root,Windows"],
        ),
        (
            ROOT / "windows-webview2",
            "high",
            webview2_winmds,
            ["Microsoft.Web.WebView2"],
            ["windows,skip-root,Windows"],
        ),
        (
            ROOT / "windows-appsdk-sys",
            "sys",
            appsdk_winmds + webview2_winmds,
            [
                "Microsoft.Foundation",
                "Microsoft.Graphics",
                "Microsoft.Security",
                "Microsoft.UI",
                "Microsoft.Windows",
                "!Microsoft.Web.WebView2",
            ],
            [
                "windows_sys,skip-root,Windows",
                "windows_webview2_sys,full,Microsoft.Web.WebView2",
            ],
        ),
        (
            ROOT / "windows-appsdk",
            "high",
            appsdk_winmds + webview2_winmds,
            [
                "Microsoft.Foundation",
                "Microsoft.Graphics",
                "Microsoft.Security",
                "Microsoft.UI",
                "Microsoft.Windows",
                "!Microsoft.Web.WebView2",
            ],
            [
                "windows,skip-root,Windows",
                "windows_webview2,full,Microsoft.Web.WebView2",
            ],
        ),
    ]

    for package_root, mode, inputs, filters, references in generations:
        clean_generated_package(package_root)
        run(bindgen_command(package_root / "src", mode, inputs, filters, references, jobs), BINDGEN)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--appsdk-version", default=prepare_nuget_metadata.DEFAULT_APPSDK_VERSION)
    parser.add_argument("--webview2-version")
    parser.add_argument("--cache", type=Path, default=ROOT / "target" / "nuget-cache")
    parser.add_argument("--metadata-out", type=Path)
    parser.add_argument("--jobs", type=int, default=default_jobs())
    parser.add_argument("--force-nuget", action="store_true")
    parser.add_argument("--skip-bindgen-build", action="store_true")
    parser.add_argument("--metadata-only", action="store_true")
    args = parser.parse_args()
    if args.jobs <= 0:
        parser.error("--jobs must be a positive integer")
    return args


def main() -> None:
    args = parse_args()
    metadata_path = prepare_metadata(args)
    if args.metadata_only:
        return
    generate_bindings(metadata_path, args.jobs, args.skip_bindgen_build)


if __name__ == "__main__":
    main()
