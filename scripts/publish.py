#!/usr/bin/env python3
"""Publish windows-cj workspace members to the Cangjie central repository."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tarfile
import time
import tomllib
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from typing import Callable, Sequence


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "https://github.com/Zxilly/windows-cj"
DEFAULT_CJ_HEAP_SIZE = "32GB"
EXCLUDED_NAMES = {"cjpm.lock", "cangjie-repo.toml"}
EXCLUDED_PARTS = {"target", "__pycache__", ".generated"}
EXTRA_PACKAGE_PATHS = {
    "windows_bindgen": ((ROOT / "winmd", Path("winmd")),),
}


Run = Callable[..., subprocess.CompletedProcess[str]]


@dataclass(frozen=True)
class PackageInfo:
    member: str
    name: str
    version: str
    output_type: str
    dependencies: dict[str, str]


def read_toml(path: Path) -> dict:
    return tomllib.loads(path.read_text(encoding="utf-8"))


def workspace_members(root: Path = ROOT) -> list[str]:
    data = read_toml(root / "cjpm.toml")
    return list(data["workspace"]["members"])


def package_info(root: Path, member: str, package_to_member: dict[str, str]) -> PackageInfo:
    member_dir = root / member
    data = read_toml(member_dir / "cjpm.toml")
    package = data["package"]
    dependencies: dict[str, str] = {}
    for dep_name, dep_info in data.get("dependencies", {}).items():
        if not isinstance(dep_info, dict) or "path" not in dep_info:
            continue
        if dep_name not in package_to_member:
            continue
        dependencies[dep_name] = package_to_member[dep_name]
    return PackageInfo(
        member=member,
        name=package["name"],
        version=package["version"],
        output_type=package.get("output-type", "static"),
        dependencies=dependencies,
    )


def package_infos(root: Path = ROOT) -> dict[str, PackageInfo]:
    members = workspace_members(root)
    package_to_member: dict[str, str] = {}
    for member in members:
        data = read_toml(root / member / "cjpm.toml")
        package_to_member[data["package"]["name"]] = member
    return {member: package_info(root, member, package_to_member) for member in members}


def topological_members(root: Path = ROOT) -> list[str]:
    infos = package_infos(root)
    ordered: list[str] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(member: str) -> None:
        if member in visited:
            return
        if member in visiting:
            raise RuntimeError(f"workspace dependency cycle reaches {member}")
        visiting.add(member)
        for dep_member in sorted(infos[member].dependencies.values()):
            visit(dep_member)
        visiting.remove(member)
        visited.add(member)
        ordered.append(member)

    for member in workspace_members(root):
        visit(member)
    return ordered


def get_old_version(member: str, run: Run = subprocess.run) -> str | None:
    try:
        result = run(
            ["git", "show", f"HEAD~1:{member}/cjpm.toml"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
        return tomllib.loads(result.stdout)["package"]["version"]
    except (subprocess.CalledProcessError, KeyError, tomllib.TOMLDecodeError):
        return None


def detect_changed_members(root: Path = ROOT, run: Run = subprocess.run) -> list[str]:
    changed: list[str] = []
    infos = package_infos(root)
    for member in topological_members(root):
        old_version = get_old_version(member, run=run)
        if old_version != infos[member].version:
            changed.append(member)
    return changed


def replace_path_dependencies(toml_text: str, infos: dict[str, PackageInfo], info: PackageInfo) -> str:
    result = toml_text
    for dep_name, dep_member in info.dependencies.items():
        dep_version = infos[dep_member].version
        pattern = re.compile(
            rf"^(\s*{re.escape(dep_name)}\s*=\s*)\{{[^}}]*\bpath\s*=\s*\"[^\"]+\"[^}}]*\}}(\s*)$",
            re.MULTILINE,
        )
        result, count = pattern.subn(rf'\1{{ version = "{dep_version}" }}\2', result)
        if count != 1:
            raise RuntimeError(f"expected one path dependency for {dep_name} in {info.member}/cjpm.toml, found {count}")
    return result


def publish_env(base: dict[str, str] | None = None) -> dict[str, str]:
    env = dict(os.environ if base is None else base)
    env["cjHeapSize"] = DEFAULT_CJ_HEAP_SIZE
    return env


def tracked_files(root: Path, member: str, run: Run = subprocess.run) -> list[Path]:
    try:
        result = run(["git", "ls-files", "--", member], cwd=root, capture_output=True, text=True, check=True)
        files = [root / line for line in result.stdout.splitlines() if line]
        if files:
            return files
    except subprocess.CalledProcessError:
        pass

    member_dir = root / member
    return sorted(path for path in member_dir.rglob("*") if path.is_file())


def should_bundle(path: Path, member_dir: Path) -> bool:
    try:
        relative = path.relative_to(member_dir)
    except ValueError:
        relative = path.name
    parts = relative.parts if isinstance(relative, Path) else (relative,)
    if path.name in EXCLUDED_NAMES:
        return False
    return not any(part in EXCLUDED_PARTS for part in parts)


def iter_bundle_entries(root: Path, info: PackageInfo, run: Run = subprocess.run) -> list[tuple[Path, Path]]:
    member_dir = root / info.member
    entries: list[tuple[Path, Path]] = []
    for path in tracked_files(root, info.member, run=run):
        if not should_bundle(path, member_dir):
            continue
        entries.append((path, path.relative_to(member_dir)))

    for source_root, destination_root in EXTRA_PACKAGE_PATHS.get(info.member, ()):
        if not source_root.exists():
            continue
        for path in sorted(source_root.rglob("*")):
            if path.is_file() and should_bundle(path, source_root):
                entries.append((path, destination_root / path.relative_to(source_root)))

    unique: dict[Path, Path] = {}
    for source, destination in entries:
        unique[destination] = source
    return [(source, destination) for destination, source in sorted(unique.items(), key=lambda item: item[0].as_posix())]


def dependency_metadata(data: dict) -> list[dict[str, str]]:
    deps: list[dict[str, str]] = []
    for dep_name, dep_info in data.get("dependencies", {}).items():
        if isinstance(dep_info, dict) and "version" in dep_info:
            deps.append({"name": dep_name, "version": dep_info["version"]})
    return deps


def make_bundle(root: Path, info: PackageInfo, transformed_toml: str, run: Run = subprocess.run) -> Path:
    member_dir = root / info.member
    target_dir = member_dir / "target"
    target_dir.mkdir(exist_ok=True)
    prefix = f"{info.name}-{info.version}"
    cjp_path = target_dir / f"{prefix}.cjp"

    buf = BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        toml_bytes = transformed_toml.encode("utf-8")
        toml_info = tarfile.TarInfo(f"{prefix}/cjpm.toml")
        toml_info.size = len(toml_bytes)
        tar.addfile(toml_info, BytesIO(toml_bytes))

        for source, destination in iter_bundle_entries(root, info, run=run):
            if destination == Path("cjpm.toml"):
                continue
            tar.add(str(source), arcname=f"{prefix}/{destination.as_posix()}")

    tarball = buf.getvalue()
    cjp_path.write_bytes(tarball)
    sha256 = hashlib.sha256(tarball).hexdigest()

    transformed_data = tomllib.loads(transformed_toml)
    package = transformed_data["package"]
    meta = {
        "organization": "",
        "name": info.name,
        "version": info.version,
        "description": package.get("description", ""),
        "artifact-type": "src",
        "executable": info.output_type == "executable",
        "authors": package.get("authors", []),
        "repository": package.get("repository", REPOSITORY),
        "homepage": package.get("homepage", ""),
        "documentation": package.get("documentation", ""),
        "tag": package.get("tag", []),
        "category": package.get("category", []),
        "license": package.get("license", []),
        "cjc-version": package.get("cjc-version", ""),
        "index": {
            "organization": "",
            "name": info.name,
            "version": info.version,
            "dependencies": dependency_metadata(transformed_data),
            "test-dependencies": [],
            "script-dependencies": [],
            "sha256sum": sha256,
            "yanked": False,
            "cjc-version": package.get("cjc-version", ""),
            "index-version": 1,
        },
        "meta-version": 1,
    }
    (target_dir / "meta-data.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  Bundled {cjp_path.name} ({len(tarball)} bytes, sha256={sha256[:16]}...)")
    return cjp_path


def create_github_release(member: str, version: str, run: Run = subprocess.run) -> None:
    tag = f"{member}/v{version}"
    title = f"{member} v{version}"
    result = run(["gh", "release", "create", tag, "--title", title, "--generate-notes"])
    if result.returncode == 0:
        print(f"  Created GitHub release {tag}")
    else:
        print(f"  Warning: failed to create GitHub release {tag}")


def publish_member(
    root: Path,
    info: PackageInfo,
    infos: dict[str, PackageInfo],
    *,
    dry_run: bool,
    run: Run = subprocess.run,
) -> None:
    member_dir = root / info.member
    toml_path = member_dir / "cjpm.toml"
    original_toml = toml_path.read_text(encoding="utf-8")
    transformed_toml = replace_path_dependencies(original_toml, infos, info)

    if dry_run:
        print(f"=== Would publish {info.member} {info.version} ===")
        for dep_name, dep_member in info.dependencies.items():
            print(f"  {dep_name} -> version {infos[dep_member].version}")
        return

    try:
        toml_path.write_text(transformed_toml, encoding="utf-8")
        print(f"=== Publishing {info.member} {info.version} ===")
        make_bundle(root, info, transformed_toml, run=run)

        for attempt in range(1, 4):
            result = run(["cjpm", "publish"], cwd=member_dir, env=publish_env())
            if result.returncode == 0:
                break
            print(f"  Attempt {attempt}/3 failed, retrying...")
            time.sleep(5 * attempt)
        else:
            raise SystemExit(f"Failed to publish {info.member} after 3 attempts")
        print(f"=== {info.member} published ===\n")
    finally:
        toml_path.write_text(original_toml, encoding="utf-8")


def select_members(root: Path, requested: Sequence[str], detect: bool, run: Run = subprocess.run) -> list[str]:
    if detect:
        return detect_changed_members(root, run=run)
    all_members = set(workspace_members(root))
    unknown = sorted(set(requested) - all_members)
    if unknown:
        raise SystemExit(f"Unknown workspace members: {', '.join(unknown)}")
    return list(requested)


def publish_members(
    root: Path,
    members: Sequence[str],
    *,
    dry_run: bool = False,
    github_release: bool = True,
    run: Run = subprocess.run,
) -> None:
    infos = package_infos(root)
    selected = set(members)
    ordered = [member for member in topological_members(root) if member in selected]
    if not ordered:
        print("No matching members to publish.")
        return

    published: list[tuple[str, str]] = []
    for member in ordered:
        info = infos[member]
        publish_member(root, info, infos, dry_run=dry_run, run=run)
        if not dry_run:
            published.append((member, info.version))

    if not dry_run and github_release:
        for member, version in published:
            create_github_release(member, version, run=run)


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Publish windows-cj packages to the Cangjie central repository.")
    parser.add_argument("members", nargs="*", help="Workspace member directories to publish.")
    parser.add_argument("--detect-and-publish", action="store_true", help="Publish members whose version changed since HEAD~1.")
    parser.add_argument("--dry-run", action="store_true", help="Print the publish plan without creating bundles or publishing.")
    parser.add_argument("--skip-github-release", action="store_true", help="Do not create GitHub releases after publishing.")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    if args.detect_and_publish and args.members:
        raise SystemExit("--detect-and-publish cannot be combined with explicit members")
    if not args.detect_and_publish and not args.members:
        raise SystemExit("pass workspace members or --detect-and-publish")
    members = select_members(ROOT, args.members, args.detect_and_publish)
    if args.detect_and_publish and not members:
        print("No version changes detected.")
        return 0
    if args.detect_and_publish:
        print(f"Detected version changes: {', '.join(members)}")
    publish_members(
        ROOT,
        members,
        dry_run=args.dry_run,
        github_release=not args.skip_github_release,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
