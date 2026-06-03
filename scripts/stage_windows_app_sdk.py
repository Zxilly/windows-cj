#!/usr/bin/env python3
"""Stage the Windows App SDK runtime files used by WinUI samples."""

from __future__ import annotations

import argparse
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_STAGE_ROOT = ROOT / ".generated" / "windows-app-sdk"
NUGET_URL = "https://www.nuget.org/api/v2/package/{name}/{version}"
PACKAGES = {
    "Microsoft.WindowsAppSDK.Foundation": "2.0.21",
    "Microsoft.WindowsAppSDK.InteractiveExperiences": "2.0.13",
    "Microsoft.WindowsAppSDK.Runtime": "2.1.3",
    "Microsoft.WindowsAppSDK.WinUI": "2.1.0",
}
RUNTIME_MSIX_NAME = "Microsoft.WindowsAppRuntime.2.msix"
RUNTIME_MSIX_ARCH = {
    "x64": "win10-x64",
    "x86": "win10-x86",
    "arm64": "win10-arm64",
    "arm64ec": "win10-arm64",
}
MSIX_STAGE_EXCLUDES = {
    "AppxBlockMap.xml",
    "AppxManifest.xml",
    "AppxMetadata",
    "AppxSignature.p7x",
    "microsoft.system.package.metadata",
    "MSIX",
}
STAGE_ROOT_EXCLUDES = {"packages"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download and stage Windows App SDK sample runtime files.")
    parser.add_argument("--stage-root", type=Path, default=DEFAULT_STAGE_ROOT)
    parser.add_argument("--arch", choices=("x64", "x86", "arm64", "arm64ec"), default="x64")
    parser.add_argument("--copy-to", action="append", type=Path, default=[])
    return parser.parse_args()


def download_package(name: str, version: str, packages_dir: Path) -> Path:
    packages_dir.mkdir(parents=True, exist_ok=True)
    archive = packages_dir / f"{name}.{version}.nupkg"
    if archive.exists():
        return archive
    url = NUGET_URL.format(name=name, version=version)
    print(f"downloading {url}", flush=True)
    urllib.request.urlretrieve(url, archive)
    return archive


def extract_package(archive: Path, name: str, version: str, packages_dir: Path) -> Path:
    extract_dir = packages_dir / f"{name}-{version}"
    if extract_dir.exists():
        return extract_dir
    extract_dir.mkdir(parents=True)
    with zipfile.ZipFile(archive) as zip_file:
        zip_file.extractall(extract_dir)
    return extract_dir


def stage_package(name: str, version: str, packages_dir: Path) -> Path:
    archive = download_package(name, version, packages_dir)
    return extract_package(archive, name, version, packages_dir)


def extract_msix(msix: Path, extract_dir: Path) -> Path:
    if (extract_dir / "AppxManifest.xml").is_file():
        return extract_dir
    extract_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(msix) as zip_file:
        zip_file.extractall(extract_dir)
    return extract_dir


def require_file(path: Path) -> Path:
    if not path.is_file():
        raise FileNotFoundError(path)
    return path


def copy_payload_entries(source_dir: Path, output_dir: Path, excludes: set[str]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for entry in source_dir.iterdir():
        if entry.name in excludes:
            continue
        target = output_dir / entry.name
        if entry.is_dir():
            shutil.copytree(entry, target, dirs_exist_ok=True)
        elif entry.is_file():
            shutil.copy2(entry, target)


def clean_stage_payload(stage_root: Path) -> None:
    stage_root.mkdir(parents=True, exist_ok=True)
    for entry in stage_root.iterdir():
        if entry.name in STAGE_ROOT_EXCLUDES:
            continue
        if entry.is_dir():
            shutil.rmtree(entry)
        else:
            entry.unlink()


def copy_framework_native_files(package_dir: Path, output_dir: Path, arch: str) -> None:
    source = package_dir / "runtimes-framework" / f"win-{arch}" / "native"
    if not source.is_dir():
        raise FileNotFoundError(source)
    copy_payload_entries(source, output_dir, set())


def copy_runtime_files(stage_root: Path, arch: str) -> None:
    packages_dir = stage_root / "packages"
    foundation_dir = stage_package("Microsoft.WindowsAppSDK.Foundation", PACKAGES["Microsoft.WindowsAppSDK.Foundation"], packages_dir)
    interactive_dir = stage_package(
        "Microsoft.WindowsAppSDK.InteractiveExperiences",
        PACKAGES["Microsoft.WindowsAppSDK.InteractiveExperiences"],
        packages_dir,
    )
    runtime_dir = stage_package("Microsoft.WindowsAppSDK.Runtime", PACKAGES["Microsoft.WindowsAppSDK.Runtime"], packages_dir)
    winui_dir = stage_package("Microsoft.WindowsAppSDK.WinUI", PACKAGES["Microsoft.WindowsAppSDK.WinUI"], packages_dir)
    stage_root.mkdir(parents=True, exist_ok=True)

    bootstrap = require_file(
        foundation_dir / "runtimes" / f"win-{arch}" / "native" / "Microsoft.WindowsAppRuntime.Bootstrap.dll"
    )
    microsoft_ui_pri = require_file(
        interactive_dir / "runtimes-framework" / f"win-{arch}" / "native" / "Microsoft.UI.pri"
    )
    msix_arch = RUNTIME_MSIX_ARCH[arch]
    runtime_msix = require_file(runtime_dir / "tools" / "MSIX" / msix_arch / RUNTIME_MSIX_NAME)
    runtime_payload_dir = extract_msix(runtime_msix, packages_dir / f"Microsoft.WindowsAppRuntime-{PACKAGES['Microsoft.WindowsAppSDK.Runtime']}-{msix_arch}")

    clean_stage_payload(stage_root)
    copy_payload_entries(runtime_payload_dir, stage_root, MSIX_STAGE_EXCLUDES)
    copy_framework_native_files(foundation_dir, stage_root, arch)
    copy_framework_native_files(interactive_dir, stage_root, arch)
    copy_framework_native_files(winui_dir, stage_root, arch)
    shutil.copy2(bootstrap, stage_root / "Microsoft.WindowsAppRuntime.Bootstrap.dll")
    if not (stage_root / "Microsoft.UI.pri").is_file():
        shutil.copy2(microsoft_ui_pri, stage_root / "Microsoft.UI.pri")


def copy_to_output(stage_root: Path, output_dir: Path) -> None:
    copy_payload_entries(stage_root, output_dir, STAGE_ROOT_EXCLUDES)


def main() -> int:
    args = parse_args()
    stage_root = args.stage_root.resolve()
    copy_runtime_files(stage_root, args.arch)
    for output_dir in args.copy_to:
        copy_to_output(stage_root, output_dir.resolve())
    print(f"staged Windows App SDK files at {stage_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
