#!/usr/bin/env python3
"""Prepare NuGet metadata for Windows App SDK binding generation."""

from __future__ import annotations

import argparse
import json
import shutil
import urllib.request
import zipfile
from pathlib import Path
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parent
DEFAULT_APPSDK_VERSION = "1.8.260416003"
APPSDK_PACKAGE_ID = "Microsoft.WindowsAppSDK"
WEBVIEW2_PACKAGE_ID = "Microsoft.Web.WebView2"
DEFAULT_APPSDK_COMPONENT_IDS = (
    "Microsoft.WindowsAppSDK.Foundation",
    "Microsoft.WindowsAppSDK.InteractiveExperiences",
    "Microsoft.WindowsAppSDK.WinUI",
    "Microsoft.WindowsAppSDK.Widgets",
    "Microsoft.WindowsAppSDK.AI",
    "Microsoft.WindowsAppSDK.ML",
    "Microsoft.WindowsAppSDK.Runtime",
)
METADATA_SUFFIXES = (".winmd",)
BOOTSTRAP_DLL_NAME = "Microsoft.WindowsAppRuntime.Bootstrap.dll"
PACKAGE_METADATA_PATTERNS = {
    "microsoft.windowsappsdk.foundation": ("metadata/*.winmd",),
    "microsoft.windowsappsdk.interactiveexperiences": ("metadata/10.0.18362.0/*.winmd",),
    "microsoft.windowsappsdk.winui": ("metadata/*.winmd",),
    "microsoft.windowsappsdk.widgets": ("metadata/*.winmd",),
    "microsoft.windowsappsdk.ai": ("metadata/*.winmd",),
    "microsoft.windowsappsdk.ml": ("metadata/*.winmd",),
    "microsoft.web.webview2": ("lib/*.winmd",),
}


def normalize_package_id(package_id: str) -> str:
    return package_id.lower()


def nuget_flat_container_url(package_id: str, version: str) -> str:
    normalized = normalize_package_id(package_id)
    return f"https://api.nuget.org/v3-flatcontainer/{normalized}/{version}/{normalized}.{version}.nupkg"


def download_file(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temp = destination.with_suffix(destination.suffix + ".tmp")
    with urllib.request.urlopen(url) as response, temp.open("wb") as output:
        shutil.copyfileobj(response, output)
    temp.replace(destination)


def safe_extract(zip_path: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    destination_root = destination.resolve()
    with zipfile.ZipFile(zip_path) as archive:
        for member in archive.infolist():
            target = (destination / member.filename).resolve()
            try:
                target.relative_to(destination_root)
            except ValueError as exc:
                raise RuntimeError(f"refusing unsafe zip member path: {member.filename}") from exc
        archive.extractall(destination)


def ensure_package(package_id: str, version: str, cache_dir: Path, force: bool = False) -> Path:
    normalized = normalize_package_id(package_id)
    package_root = cache_dir / "packages" / normalized / version
    marker = package_root / ".complete"
    if marker.exists() and not force:
        return package_root

    nupkg = cache_dir / "downloads" / f"{normalized}.{version}.nupkg"
    if force or not nupkg.exists():
        download_file(nuget_flat_container_url(package_id, version), nupkg)

    if package_root.exists():
        shutil.rmtree(package_root)
    safe_extract(nupkg, package_root)
    marker.write_text("prepared\n", encoding="utf-8")
    return package_root


def xml_local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def normalize_constant_part(value: str) -> str:
    chars: list[str] = []
    previous_underscore = False
    previous_was_lower_or_digit = False
    for char in value:
        if char.isalnum():
            if char.isupper() and previous_was_lower_or_digit and not previous_underscore:
                chars.append("_")
            chars.append(char.upper())
            previous_underscore = False
            previous_was_lower_or_digit = char.islower() or char.isdigit()
        elif not previous_underscore:
            chars.append("_")
            previous_underscore = True
            previous_was_lower_or_digit = False
    return "".join(chars).strip("_")


def strip_version_range(version: str) -> str:
    return version.strip().strip("[]()")


def discover_dependencies(nuspec_text: str) -> dict[str, str]:
    root = ElementTree.fromstring(nuspec_text)
    result: dict[str, str] = {}
    for dependency in root.iter():
        if xml_local_name(dependency.tag) != "dependency":
            continue
        dependency_id = dependency.attrib.get("id", "").strip()
        version = dependency.attrib.get("version", "").strip()
        if not dependency_id or not version:
            continue
        result[dependency_id] = strip_version_range(version)
    return result


def discover_dependency_version(nuspec_text: str, dependency_id: str) -> str | None:
    for found_id, version in discover_dependencies(nuspec_text).items():
        if found_id.lower() == dependency_id.lower():
            return version
    return None


def read_nuspec(package_root: Path) -> str:
    nuspecs = sorted(package_root.glob("*.nuspec"))
    if not nuspecs:
        raise FileNotFoundError(f"no .nuspec found under {package_root}")
    return nuspecs[0].read_text(encoding="utf-8")


def add_version_constant(constants: dict[str, str], parts: list[str], value: str) -> None:
    cleaned = value.strip()
    if not cleaned:
        return
    suffix = "_".join(normalize_constant_part(part) for part in parts if part)
    if suffix:
        constants[f"WINDOWS_APPSDK_{suffix}"] = cleaned


def walk_version_info(node: ElementTree.Element, parts: list[str], constants: dict[str, str]) -> None:
    node_name = xml_local_name(node.tag)
    child_parts = parts + ([node_name] if parts or normalize_constant_part(node_name) != "WINDOWS_APP_SDK" else [])
    text = (node.text or "").strip()
    if text and len(list(node)) == 0:
        add_version_constant(constants, child_parts, text)
    for key, value in node.attrib.items():
        normalized_node = normalize_constant_part(node_name)
        normalized_key = normalize_constant_part(key)
        if child_parts and normalized_key.startswith(normalized_node + "_"):
            suffix = normalized_key[len(normalized_node) + 1 :]
            prefix = "_".join(normalize_constant_part(part) for part in child_parts if part)
            cleaned = value.strip()
            if cleaned and prefix and suffix:
                constants[f"WINDOWS_APPSDK_{prefix}_{suffix}"] = cleaned
        else:
            add_version_constant(constants, child_parts + [key], value)
    for child in node:
        walk_version_info(child, child_parts, constants)


def parse_version_info(version_info_text: str) -> dict[str, str]:
    root = ElementTree.fromstring(version_info_text)
    constants: dict[str, str] = {}
    for key, value in root.attrib.items():
        add_version_constant(constants, [key], value)
    for child in root:
        walk_version_info(child, [], constants)

    if not constants:
        raise ValueError("WindowsAppSDK-VersionInfo.xml did not contain version constants")
    return dict(sorted(constants.items()))


def find_version_info(package_root: Path) -> Path:
    matches = sorted(package_root.rglob("WindowsAppSDK-VersionInfo.xml"))
    if not matches:
        raise FileNotFoundError(f"WindowsAppSDK-VersionInfo.xml not found under {package_root}")
    return matches[0]


def relative_posix(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def collect_relative_paths(root: Path, suffixes: tuple[str, ...]) -> list[str]:
    lowered = tuple(suffix.lower() for suffix in suffixes)
    return sorted(
        relative_posix(root, path)
        for path in root.rglob("*")
        if path.is_file() and path.suffix.lower() in lowered
    )


def collect_bootstrap_dlls(appsdk_root: Path) -> list[str]:
    return sorted(
        relative_posix(appsdk_root, path)
        for path in appsdk_root.rglob("*.dll")
        if path.name.lower() == BOOTSTRAP_DLL_NAME.lower()
    )


def collect_package_metadata(root: Path, package_id: str) -> list[str]:
    patterns = PACKAGE_METADATA_PATTERNS.get(normalize_package_id(package_id), ("metadata/*.winmd", "lib/*.winmd"))
    paths: list[str] = []
    for pattern in patterns:
        paths.extend(relative_posix(root, path) for path in root.glob(pattern) if path.is_file())
    return sorted(dict.fromkeys(paths))


def absolute_paths(root: Path, relative_paths: list[str]) -> list[str]:
    return [str(root / path) for path in relative_paths]


def package_entry(package_id: str, version: str, root: Path) -> dict[str, object]:
    metadata = collect_package_metadata(root, package_id)
    return {
        "id": package_id,
        "version": version,
        "root": str(root),
        "metadata": metadata,
        "metadata_paths": absolute_paths(root, metadata),
    }


def build_metadata(
    appsdk_root: Path,
    component_roots: dict[str, tuple[str, Path]],
    webview2_root: Path,
    appsdk_version: str,
    webview2_version: str,
) -> dict[str, object]:
    component_entries = [
        package_entry(package_id, version, root)
        for package_id, (version, root) in sorted(component_roots.items())
    ]
    appsdk_metadata_paths: list[str] = []
    bootstrap_paths: list[str] = []
    version_info_root = appsdk_root
    version_info_path: Path | None = None
    for entry in component_entries:
        appsdk_metadata_paths.extend(entry["metadata_paths"])  # type: ignore[arg-type]
        root = Path(str(entry["root"]))
        bootstrap_paths.extend(absolute_paths(root, collect_bootstrap_dlls(root)))
        try:
            candidate = find_version_info(root)
            version_info_root = root
            version_info_path = candidate
        except FileNotFoundError:
            pass

    if version_info_path is None:
        version_info_path = find_version_info(appsdk_root)

    webview2_entry = package_entry(WEBVIEW2_PACKAGE_ID, webview2_version, webview2_root)
    return {
        "packages": {
            "appsdk": {
                "id": APPSDK_PACKAGE_ID,
                "version": appsdk_version,
                "root": str(appsdk_root),
                "components": component_entries,
                "metadata_paths": sorted(appsdk_metadata_paths),
                "bootstrap_dll_paths": sorted(bootstrap_paths),
                "version_info": str(version_info_path),
                "version_info_relative": relative_posix(version_info_root, version_info_path),
                "version_constants": parse_version_info(version_info_path.read_text(encoding="utf-8")),
            },
            "webview2": webview2_entry,
        },
        "inputs": {
            "appsdk_winmds": sorted(appsdk_metadata_paths),
            "webview2_winmds": webview2_entry["metadata_paths"],
            "bootstrap_dlls": sorted(bootstrap_paths),
        },
    }


def cj_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def cj_u16_array(value: str) -> str:
    values = [f"{ord(ch)}u16" for ch in value]
    values.append("0u16")
    return "[" + ", ".join(values) + "]"


def write_version_cj(constants: dict[str, str], output: Path) -> None:
    release_major_minor = constants.get("WINDOWS_APPSDK_RELEASE_MAJOR_MINOR_UINT32", "0")
    release_tag = constants.get("WINDOWS_APPSDK_RELEASE_SHORT_TAG", constants.get("WINDOWS_APPSDK_RELEASE_TAG", ""))
    runtime_version = constants.get("WINDOWS_APPSDK_RUNTIME_VERSION_UINT16", "0")
    runtime_version_string = constants.get("WINDOWS_APPSDK_RUNTIME_VERSION_STRING", "")
    text = "\n".join(
        [
            "package windows_appsdk",
            "",
            'public let WINDOWS_APPSDK_BOOTSTRAP_DLL = "Microsoft.WindowsAppRuntime.Bootstrap.dll"',
            f"public let WINDOWS_APPSDK_RELEASE_MAJORMINOR = UInt32({release_major_minor})",
            f"public let WINDOWS_APPSDK_RELEASE_VERSION_TAG = {cj_string(release_tag)}",
            f"public let WINDOWS_APPSDK_RELEASE_VERSION_TAG_WIDE: Array<UInt16> = {cj_u16_array(release_tag)}",
            f"public let WINDOWS_APPSDK_RUNTIME_VERSION = UInt64({runtime_version})",
            f"public let WINDOWS_APPSDK_RUNTIME_VERSION_STRING = {cj_string(runtime_version_string)}",
            "public let MDD_BOOTSTRAP_INITIALIZE_OPTIONS_NONE = 0u32",
            "",
            "public func packageVersion(major: UInt16, minor: UInt16, build: UInt16, revision: UInt16): UInt64 {",
            "    (UInt64(major) << 48u64) |",
            "        (UInt64(minor) << 32u64) |",
            "        (UInt64(build) << 16u64) |",
            "        UInt64(revision)",
            "}",
            "",
        ]
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--appsdk-version", default=DEFAULT_APPSDK_VERSION)
    parser.add_argument(
        "--component",
        action="append",
        default=[],
        help="Additional AppSDK component package id to download; defaults to the binding component set.",
    )
    parser.add_argument("--webview2-version", help="Override WebView2 NuGet version instead of reading the AppSDK nuspec.")
    parser.add_argument("--cache", type=Path, default=ROOT / "target" / "nuget-cache")
    parser.add_argument("--metadata-out", type=Path)
    parser.add_argument("--version-cj-out", type=Path, help="Write generated windows_appsdk version constants.")
    parser.add_argument("--force", action="store_true", help="Redownload and re-extract packages.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    appsdk_root = ensure_package(APPSDK_PACKAGE_ID, args.appsdk_version, args.cache, args.force)
    appsdk_nuspec = read_nuspec(appsdk_root)
    dependencies = discover_dependencies(appsdk_nuspec)
    component_ids = list(dict.fromkeys([*DEFAULT_APPSDK_COMPONENT_IDS, *args.component]))
    component_roots: dict[str, tuple[str, Path]] = {}
    webview2_version = args.webview2_version or discover_dependency_version(appsdk_nuspec, WEBVIEW2_PACKAGE_ID)
    for component_id in component_ids:
        component_version = dependencies.get(component_id)
        if not component_version:
            continue
        component_root = ensure_package(component_id, component_version, args.cache, args.force)
        component_roots[component_id] = (component_version, component_root)
        if not webview2_version:
            webview2_version = discover_dependency_version(read_nuspec(component_root), WEBVIEW2_PACKAGE_ID)

    if not webview2_version:
        raise SystemExit("could not discover WebView2 version from AppSDK packages; pass --webview2-version")

    webview2_root = ensure_package(WEBVIEW2_PACKAGE_ID, webview2_version, args.cache, args.force)
    metadata = build_metadata(appsdk_root, component_roots, webview2_root, args.appsdk_version, webview2_version)

    output_path = args.metadata_out or (
        ROOT / "target" / "nuget-metadata" / f"windows-appsdk-{args.appsdk_version}.json"
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.version_cj_out:
        constants = metadata["packages"]["appsdk"]["version_constants"]  # type: ignore[index]
        write_version_cj(constants, args.version_cj_out)  # type: ignore[arg-type]
    print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
