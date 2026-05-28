#!/usr/bin/env python3
from __future__ import annotations

import argparse
import contextlib
import io
import tempfile
import unittest
from pathlib import Path

import run_windows_workspace_tests as workspace


def write_file(root: Path, relative: str, text: str) -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


class WorkspaceRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.original_root = workspace.ROOT
        self.original_unittest_bin = workspace.UNITTEST_BIN
        workspace.ROOT = self.root
        workspace.UNITTEST_BIN = self.root / "target" / "release" / "unittest_bin"

        write_file(self.root, "cjpm.toml", '[workspace]\nmembers = ["windows_core", "windows_empty"]\n')
        write_file(self.root, "windows_core/cjpm.toml", '[package]\nname = "windows_core"\n')
        write_file(self.root, "windows_empty/cjpm.toml", '[package]\nname = "windows_empty"\n')
        write_file(self.root, "windows_core/src/core_test.cj", "package windows_core.tests\n@Test\nclass T {}\n")
        write_file(self.root, "windows_empty/src/lib.cj", "package windows_empty\n")
        write_file(self.root, "windows_core/target/ignored_test.cj", "package ignored\n@Test\nclass T {}\n")

    def tearDown(self) -> None:
        workspace.ROOT = self.original_root
        workspace.UNITTEST_BIN = self.original_unittest_bin
        self.temp.cleanup()

    def test_member_selection_uses_only_members_with_tests_by_default(self) -> None:
        self.assertEqual(workspace.workspace_members(), ["windows_core", "windows_empty"])
        self.assertEqual(workspace.test_package_names("windows_core"), ["windows_core.tests"])
        self.assertEqual(workspace.test_package_names("windows_empty"), [])
        self.assertEqual(workspace.parse_members([]), ["windows_core"])

    def test_exact_binary_path_and_commands_are_stable(self) -> None:
        binary = workspace.UNITTEST_BIN / "windows_core.tests.exe"

        self.assertEqual(workspace.test_binaries_for_member("windows_core"), [binary])
        self.assertEqual(
            workspace.workspace_build_command("windows_core"),
            ["cjpm", "test", "-m", "windows_core", "--no-run", "--no-progress", "--no-color"],
        )
        self.assertEqual(workspace.workspace_test_command(binary), ["cjv", "exec", str(binary), "--no-color", "--progress-brief"])

    def test_removes_expected_stale_binary_outputs_only(self) -> None:
        binary = workspace.UNITTEST_BIN / "windows_core.tests.exe"
        unrelated = workspace.UNITTEST_BIN / "other.exe"
        stale_paths = (
            binary,
            binary.with_name(f"{binary.stem}$test.cjo"),
            binary.with_name(f"{binary.stem}$test.cjo.flag"),
            unrelated,
        )
        for stale in stale_paths:
            stale.parent.mkdir(parents=True, exist_ok=True)
            stale.write_text("stale\n", encoding="utf-8")

        workspace.remove_expected_test_binaries("windows_core")

        self.assertFalse(binary.exists())
        self.assertFalse(binary.with_name(f"{binary.stem}$test.cjo").exists())
        self.assertFalse(binary.with_name(f"{binary.stem}$test.cjo.flag").exists())
        self.assertTrue(unrelated.exists())

    def test_unknown_member_and_non_positive_timeout_are_rejected(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "unknown workspace members"):
            workspace.parse_members(["missing"])
        with self.assertRaises(argparse.ArgumentTypeError):
            workspace.positive_int("0")

    def test_summary_counts_and_executed_count(self) -> None:
        counts = workspace.summary_counts("Summary: TOTAL: 6\n    PASSED: 5, SKIPPED: 0, ERROR: 0\n    FAILED: 1\n")

        self.assertEqual(counts, {"PASSED": 5, "SKIPPED": 0, "FAILED": 1, "ERROR": 0})
        self.assertEqual(workspace.executed_test_count(counts or {}), 6)
        self.assertIsNone(workspace.summary_counts("missing summary"))
        self.assertIsNone(workspace.summary_counts("PASSED: 1\nFAILED: 0\nERROR: 0\n"))
        self.assertIsNone(workspace.summary_counts("Summary: TOTAL: 1\n    PASSED: 1\n"))
        self.assertIsNone(
            workspace.summary_counts("Summary: TOTAL: 50\n    PASSED: 1, SKIPPED: 0, ERROR: 0\n    FAILED: 0\n")
        )

    def test_dry_run_skip_build_omits_build_command(self) -> None:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            result = workspace.dry_run_member("windows_core", skip_build=True)

        output = stdout.getvalue()
        self.assertEqual(result, 0)
        self.assertIn("# skip-build: existing unittest binaries", output)
        self.assertNotIn("cjpm test", output)
        self.assertIn("cjv exec", output)


if __name__ == "__main__":
    unittest.main()
