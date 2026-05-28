from __future__ import annotations

import io
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

import publish


def write_file(root: Path, relative: str, text: str = "x\n") -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def write_package(root: Path, member: str, body: str) -> None:
    write_file(root, f"{member}/cjpm.toml", body)
    write_file(root, f"{member}/src/lib.cj", f"package {member}\n")


class PublishScriptTests(unittest.TestCase):
    def test_topological_order_uses_workspace_dependencies(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_file(root, "cjpm.toml", '[workspace]\nmembers = ["app", "core", "strings"]\n')
            write_package(
                root,
                "app",
                (
                    '[package]\nname = "app"\nversion = "0.1.0"\n'
                    '[dependencies]\ncore = { path = "../core" }\n'
                ),
            )
            write_package(
                root,
                "core",
                (
                    '[package]\nname = "core"\nversion = "0.1.0"\n'
                    '[dependencies]\nstrings = { path = "../strings" }\n'
                ),
            )
            write_package(root, "strings", '[package]\nname = "strings"\nversion = "0.1.0"\n')

            self.assertEqual(publish.topological_members(root), ["strings", "core", "app"])

    def test_path_dependencies_are_rewritten_to_versions(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_file(root, "cjpm.toml", '[workspace]\nmembers = ["app", "core"]\n')
            app_toml = (
                '[package]\nname = "app"\nversion = "1.0.0"\n'
                '[dependencies]\ncore = { path = "../core" }\n'
                '[target.x86_64-w64-mingw32.bin-dependencies]\npath-option = ["${CANGJIE_STDX_PATH_STATIC}/stdx"]\n'
            )
            write_package(root, "app", app_toml)
            write_package(root, "core", '[package]\nname = "core"\nversion = "2.0.0"\n')
            infos = publish.package_infos(root)

            rewritten = publish.replace_path_dependencies(app_toml, infos, infos["app"])

            self.assertIn('core = { version = "2.0.0" }', rewritten)
            self.assertIn("[target.x86_64-w64-mingw32.bin-dependencies]", rewritten)

    def test_bundle_includes_assets_and_excludes_build_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_file(root, "cjpm.toml", '[workspace]\nmembers = ["windows_targets"]\n')
            package_toml = (
                '[package]\nname = "windows_targets"\nversion = "0.1.0"\n'
                'description = "targets"\noutput-type = "static"\ncjc-version = "1.1.0"\n'
            )
            write_package(root, "windows_targets", package_toml)
            write_file(root, "windows_targets/README.md", "# targets\n")
            write_file(root, "windows_targets/cjpm.lock", "version = 0\n")
            write_file(root, "windows_targets/target/junk.txt", "junk\n")
            write_file(root, "windows_targets/x86_64_gnu/lib/libwindows.a", "archive\n")
            info = publish.package_infos(root)["windows_targets"]

            cjp = publish.make_bundle(root, info, package_toml)

            with tarfile.open(cjp, mode="r:gz") as tar:
                names = set(tar.getnames())
            self.assertIn("windows_targets-0.1.0/x86_64_gnu/lib/libwindows.a", names)
            self.assertIn("windows_targets-0.1.0/README.md", names)
            self.assertNotIn("windows_targets-0.1.0/cjpm.lock", names)
            self.assertNotIn("windows_targets-0.1.0/target/junk.txt", names)

    def test_publish_restores_toml_and_forces_heap_size(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_file(root, "cjpm.toml", '[workspace]\nmembers = ["app", "core"]\n')
            app_toml = (
                '[package]\nname = "app"\nversion = "1.0.0"\n'
                '[dependencies]\ncore = { path = "../core" }\n'
            )
            write_package(root, "app", app_toml)
            write_package(root, "core", '[package]\nname = "core"\nversion = "2.0.0"\n')
            infos = publish.package_infos(root)
            publish_envs: list[dict[str, str]] = []

            def fake_run(command, **kwargs):
                if command[:2] == ["git", "ls-files"]:
                    return subprocess.CompletedProcess(command, 0, stdout="", stderr="")
                if command == ["cjpm", "publish"]:
                    publish_envs.append(kwargs["env"])
                    return subprocess.CompletedProcess(command, 0)
                raise AssertionError(f"unexpected command: {command}")

            publish.publish_member(root, infos["app"], infos, dry_run=False, run=fake_run)

            self.assertEqual((root / "app" / "cjpm.toml").read_text(encoding="utf-8"), app_toml)
            self.assertEqual(publish_envs[0]["cjHeapSize"], "32GB")


if __name__ == "__main__":
    unittest.main()
