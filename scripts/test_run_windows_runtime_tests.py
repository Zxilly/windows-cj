#!/usr/bin/env python3
from __future__ import annotations

import argparse
import contextlib
import io
from unittest import mock
import tempfile
import unittest
from pathlib import Path

import run_windows_runtime_tests as runtime


class RuntimeRunnerTests(unittest.TestCase):
    def test_summary_counts_and_executed_count(self) -> None:
        counts = runtime.summary_counts("Summary: TOTAL: 3\n    PASSED: 2, SKIPPED: 0, ERROR: 1\n    FAILED: 0\n")

        self.assertEqual(counts, {"PASSED": 2, "SKIPPED": 0, "FAILED": 0, "ERROR": 1})
        self.assertEqual(runtime.executed_test_count(counts or {}), 3)
        self.assertIsNone(runtime.summary_counts("missing summary"))
        self.assertIsNone(runtime.summary_counts("PASSED: 1\nFAILED: 0\nERROR: 0\n"))
        self.assertIsNone(runtime.summary_counts("Summary: TOTAL: 1\n    PASSED: 1\n"))
        self.assertIsNone(
            runtime.summary_counts("Summary: TOTAL: 50\n    PASSED: 1, SKIPPED: 0, ERROR: 0\n    FAILED: 0\n")
        )

    def test_runtime_command_uses_cjv_exec_and_filter(self) -> None:
        command = runtime.runtime_test_command(Path("windows_foundation.exe"), "StringTests", ["--", "--seed=7"])

        self.assertEqual(command[0:3], ["cjv", "exec", "windows_foundation.exe"])
        self.assertIn("--filter=StringTests", command)
        self.assertIn("--progress-brief", command)
        self.assertIn("--seed=7", command)

    def test_runtime_command_rejects_unittest_timeout_each(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "do not pass --timeout-each"):
            runtime.runtime_test_command(Path("windows_foundation.exe"), None, ["--", "--timeout-each=1"])

    def test_package_binary_names_map_split_packages(self) -> None:
        self.assertEqual(runtime.package_binary_name("windows_foundation"), "windows_foundation.exe")
        self.assertEqual(runtime.package_binary_name("windows_collections"), "windows_collections.exe")
        self.assertEqual(runtime.package_binary_name("windows_future"), "windows_future.exe")
        self.assertEqual(
            runtime.SPLIT_PACKAGES,
            ("windows_foundation", "windows_collections", "windows_future"),
        )

    def test_positive_int_rejects_non_positive_timeout(self) -> None:
        self.assertEqual(runtime.positive_int("1"), 1)
        with self.assertRaises(argparse.ArgumentTypeError):
            runtime.positive_int("0")

    def test_removes_expected_stale_runtime_binary_outputs_only(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            binary = root / "windows_foundation.exe"
            unrelated = root / "other.exe"
            stale_paths = (
                binary,
                binary.with_name(f"{binary.stem}$test.cjo"),
                binary.with_name(f"{binary.stem}$test.cjo.flag"),
                unrelated,
            )
            for stale in stale_paths:
                stale.write_text("stale\n", encoding="utf-8")

            runtime.remove_expected_runtime_binary(binary)

            self.assertFalse(binary.exists())
            self.assertFalse(binary.with_name(f"{binary.stem}$test.cjo").exists())
            self.assertFalse(binary.with_name(f"{binary.stem}$test.cjo.flag").exists())
            self.assertTrue(unrelated.exists())

    def test_main_runs_repeated_filters_after_one_build(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            binary = Path(temp_dir) / "windows_foundation.exe"
            binary.write_text("stub\n", encoding="utf-8")
            calls: list[list[str]] = []

            def fake_run(command: list[str], **_: object) -> tuple[int, str]:
                calls.append(command)
                return 0, "Summary: TOTAL: 1\n    PASSED: 1, SKIPPED: 0, ERROR: 0\n    FAILED: 0\n"

            with mock.patch.object(runtime, "package_binary", return_value=binary):
                with mock.patch.object(runtime, "remove_expected_runtime_binary"):
                    with mock.patch.object(runtime, "run_with_watchdog", side_effect=fake_run):
                        with contextlib.redirect_stdout(io.StringIO()):
                            result = runtime.main(["--filter", "one", "--filter", "two"])

        self.assertEqual(result, 0)
        self.assertEqual(calls[0], ["cjpm", "test", "--no-run", "--no-progress", "--no-color"])
        self.assertIn("--filter=one", calls[1])
        self.assertIn("--filter=two", calls[2])
        self.assertEqual(len(calls), 3)

    def test_main_targets_requested_split_package(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            binary = Path(temp_dir) / "windows_collections.exe"
            binary.write_text("stub\n", encoding="utf-8")
            seen: dict[str, object] = {}

            def fake_run(command: list[str], **kwargs: object) -> tuple[int, str]:
                seen["command"] = command
                seen["cwd"] = kwargs.get("cwd")
                return 0, "Summary: TOTAL: 1\n    PASSED: 1, SKIPPED: 0, ERROR: 0\n    FAILED: 0\n"

            with mock.patch.object(runtime, "package_binary", return_value=binary) as pkg_binary:
                with mock.patch.object(runtime, "remove_expected_runtime_binary"):
                    with mock.patch.object(runtime, "run_with_watchdog", side_effect=fake_run):
                        with contextlib.redirect_stdout(io.StringIO()):
                            result = runtime.main(["--package", "windows_collections", "--skip-build"])

        self.assertEqual(result, 0)
        pkg_binary.assert_called_with("windows_collections")


if __name__ == "__main__":
    unittest.main()
