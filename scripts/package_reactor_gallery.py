#!/usr/bin/env python3
"""Build a self-contained Windows reactor gallery zip."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from xml.etree import ElementTree
from xml.sax.saxutils import escape

import stage_windows_app_sdk


ROOT = Path(__file__).resolve().parents[1]
GALLERY = ROOT / "samples" / "reactor" / "windows_reactor_gallery"
TARGET = GALLERY / "target"
BUILD_BIN = TARGET / "release" / "bin"
DEFAULT_PUBLISH = TARGET / "gallery-self-contained"
DEFAULT_ZIP = TARGET / "windows_reactor_gallery_x64_self_contained.zip"
APPX_NS = {"appx": "http://schemas.microsoft.com/appx/manifest/foundation/windows10"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Package the reactor gallery with local Windows App SDK DLLs.")
    parser.add_argument("--arch", choices=("x64", "x86", "arm64", "arm64ec"), default="x64")
    parser.add_argument("--publish-dir", type=Path, default=DEFAULT_PUBLISH)
    parser.add_argument("--zip", type=Path, default=DEFAULT_ZIP)
    parser.add_argument("--skip-build", action="store_true")
    return parser.parse_args()


def run(command: list[str], cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    print("+ " + " ".join(command), flush=True)
    subprocess.run(command, cwd=cwd, env=env, check=True)


def clean_dir(path: Path) -> None:
    resolved = path.resolve()
    target = TARGET.resolve()
    if resolved != target and target not in resolved.parents:
        raise RuntimeError(f"refusing to delete outside target: {resolved}")
    if resolved.exists():
        shutil.rmtree(resolved)
    resolved.mkdir(parents=True)


def copy_tree(source: Path, target: Path) -> None:
    if source.is_dir():
        shutil.copytree(source, target, dirs_exist_ok=True)


def build_gallery() -> None:
    env = os.environ.copy()
    env["cjHeapSize"] = "32GB"
    run(["cjpm", "build", "-i"], cwd=GALLERY, env=env)


def copy_gallery_payload(publish_dir: Path) -> None:
    exe = BUILD_BIN / "main.exe"
    if not exe.is_file():
        raise FileNotFoundError(f"missing built gallery executable: {exe}")
    shutil.copy2(exe, publish_dir / "main.exe")
    copy_tree(GALLERY / "assets", publish_dir / "assets")


def candidate_tool_paths(tool: str) -> list[Path]:
    roots = [
        Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")),
        Path(os.environ.get("ProgramFiles", r"C:\Program Files")),
    ]
    preferred: list[Path] = []
    fallback: list[Path] = []
    for root in roots:
        kits = root / "Windows Kits" / "10" / "bin"
        if kits.is_dir():
            preferred.extend(kits.glob(f"*/x64/{tool}"))
            fallback.extend(kits.glob(f"*/*/{tool}"))
    preferred_paths = sorted({path.resolve() for path in preferred if path.is_file()}, reverse=True)
    fallback_paths = sorted({path.resolve() for path in fallback if path.is_file()}, reverse=True)
    return preferred_paths + [path for path in fallback_paths if path not in preferred_paths]


def find_tool(tool: str) -> Path:
    paths = candidate_tool_paths(tool)
    if paths:
        return paths[0]
    raise FileNotFoundError(f"{tool} not found under Windows Kits 10 bin")


def generate_empty_app_pri(publish_dir: Path) -> None:
    makepri = find_tool("makepri.exe")
    with tempfile.TemporaryDirectory(prefix="reactor-gallery-pri-") as temp_name:
        temp = Path(temp_name)
        project_root = temp / "root"
        config_dir = temp / "config"
        project_root.mkdir()
        config_dir.mkdir()
        config = config_dir / "priconfig.xml"
        output = temp / "resources.pri"
        run([str(makepri), "createconfig", "/cf", str(config), "/dq", "en-US", "/pv", "10.0.0", "/o"])
        run([str(makepri), "new", "/pr", str(project_root), "/cf", str(config), "/of", str(output), "/o"])
        shutil.copy2(output, publish_dir / "resources.pri")


def ensure_resources_pri(publish_dir: Path) -> None:
    if (publish_dir / "resources.pri").is_file():
        return
    generate_empty_app_pri(publish_dir)


def runtime_appx_manifest(stage_root: Path, arch: str) -> Path:
    msix_arch = stage_windows_app_sdk.RUNTIME_MSIX_ARCH[arch]
    version = stage_windows_app_sdk.PACKAGES["Microsoft.WindowsAppSDK.Runtime"]
    manifest = stage_root / "packages" / f"Microsoft.WindowsAppRuntime-{version}-{msix_arch}" / "AppxManifest.xml"
    if not manifest.is_file():
        raise FileNotFoundError(manifest)
    return manifest


def generate_self_contained_manifest(publish_dir: Path, stage_root: Path, arch: str) -> Path:
    tree = ElementTree.parse(runtime_appx_manifest(stage_root, arch))
    lines = [
        "<?xml version='1.0' encoding='utf-8' standalone='yes'?>",
        "<assembly manifestVersion='1.0'",
        "  xmlns:asmv3='urn:schemas-microsoft-com:asm.v3'",
        "  xmlns='urn:schemas-microsoft-com:asm.v1'>",
        "  <assemblyIdentity version='1.0.0.0' processorArchitecture='*' name='windows_reactor_gallery' type='win32'/>",
    ]
    class_count = 0
    for extension in tree.findall(".//appx:Extension[@Category='windows.activatableClass.inProcessServer']", APPX_NS):
        server = extension.find("appx:InProcessServer", APPX_NS)
        if server is None:
            continue
        path = server.findtext("appx:Path", default="", namespaces=APPX_NS)
        if not path or not (publish_dir / path).is_file():
            continue
        classes = server.findall("appx:ActivatableClass", APPX_NS)
        if not classes:
            continue
        lines.append(f"  <asmv3:file name='{escape(path)}'>")
        for activatable in classes:
            class_id = activatable.attrib.get("ActivatableClassId")
            if not class_id:
                continue
            threading = activatable.attrib.get("ThreadingModel", "both")
            lines.append(
                f"    <activatableClass name='{escape(class_id)}' threadingModel='{escape(threading)}' "
                "xmlns='urn:schemas-microsoft-com:winrt.v1'/>"
            )
            class_count += 1
        lines.append("  </asmv3:file>")
    lines.append("</assembly>")
    if class_count == 0:
        raise RuntimeError("generated manifest contains no activatable classes")
    manifest = publish_dir / "main.exe.manifest"
    manifest.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return manifest


def embed_manifest(publish_dir: Path, manifest: Path) -> None:
    mt = find_tool("mt.exe")
    run([str(mt), "-nologo", "-manifest", str(manifest), f"-outputresource:{publish_dir / 'main.exe'};#1"])


def copy_cangjie_runtime(publish_dir: Path) -> None:
    configured = os.environ.get("CANGJIE_RUNTIME_DIR")
    candidates: list[Path] = []
    if configured:
        candidates.append(Path(configured))
    candidates.extend(Path.home().glob(".cjv/toolchains/*/runtime/lib/windows_x86_64_cjnative"))
    runtime_dirs = sorted([path for path in candidates if path.is_dir()], key=lambda p: p.stat().st_mtime, reverse=True)
    if not runtime_dirs:
        raise FileNotFoundError("Cangjie runtime directory not found")
    for dll in runtime_dirs[0].glob("*.dll"):
        shutil.copy2(dll, publish_dir / dll.name)


def create_zip(publish_dir: Path, zip_path: Path) -> None:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(publish_dir.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(publish_dir))


def main() -> int:
    args = parse_args()
    publish_dir = args.publish_dir.resolve()
    zip_path = args.zip.resolve()
    if not args.skip_build:
        build_gallery()
    stage_root = stage_windows_app_sdk.DEFAULT_STAGE_ROOT.resolve()
    stage_windows_app_sdk.copy_runtime_files(stage_root, args.arch)
    clean_dir(publish_dir)
    copy_gallery_payload(publish_dir)
    stage_windows_app_sdk.copy_to_output(stage_root, publish_dir)
    copy_cangjie_runtime(publish_dir)
    ensure_resources_pri(publish_dir)
    manifest = generate_self_contained_manifest(publish_dir, stage_root, args.arch)
    embed_manifest(publish_dir, manifest)
    create_zip(publish_dir, zip_path)
    print(f"publish_dir={publish_dir}")
    print(f"zip={zip_path}")
    print(f"zip_size={zip_path.stat().st_size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
