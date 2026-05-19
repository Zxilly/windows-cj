#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import unittest

import run_windows_quality_gate as gate


class QualityGatePlanTests(unittest.TestCase):
    def step_names(self, args: list[str]) -> list[str]:
        return [step.name for step in gate.build_steps(gate.parse_args(args))]

    def test_quick_mode_runs_static_gate_only(self) -> None:
        self.assertEqual(
            self.step_names(["--mode", "quick"]),
            [
                "py_compile",
                "windows-common codegen gate",
                "workspace setup audit",
                "ignored results audit",
                "ABI ownership audit",
            ],
        )

    def test_full_mode_adds_workspace_tests_and_macro_fixtures(self) -> None:
        self.assertEqual(
            self.step_names([]),
            [
                "py_compile",
                "windows-common codegen gate",
                "workspace setup audit",
                "ignored results audit",
                "ABI ownership audit",
                "workspace tests",
                "macro fixtures",
            ],
        )

    def test_winui_demo_smoke_is_explicit(self) -> None:
        self.assertNotIn("WinUI demo smoke", self.step_names([]))
        self.assertIn("WinUI demo smoke", self.step_names(["--include-winui-demo-smoke"]))

    def test_workspace_options_are_forwarded_to_workspace_runner(self) -> None:
        args = gate.parse_args(
            [
                "--workspace-timeout-seconds",
                "17",
                "--skip-workspace-build",
                "--workspace-member",
                "windows-core",
            ]
        )
        steps = {step.name: step for step in gate.build_steps(args)}
        command = steps["workspace tests"].command
        self.assertIn("--timeout-seconds", command)
        self.assertIn("17", command)
        self.assertIn("--skip-build", command)
        self.assertTrue(command[-1].endswith("windows-core"))

    def test_codegen_options_are_forwarded_to_codegen_gate(self) -> None:
        args = gate.parse_args(
            [
                "--codegen-timeout-seconds",
                "23",
                "--skip-codegen-regenerate",
            ]
        )
        steps = {step.name: step for step in gate.build_steps(args)}
        command = steps["windows-common codegen gate"].command
        self.assertIn("--timeout-seconds", command)
        self.assertIn("23", command)
        self.assertIn("--skip-regenerate", command)

    def test_codegen_gate_uses_common_bindgen_script(self) -> None:
        removed_subset_gate = "check_" + "windows" + "_sys_subset.py"
        steps = {step.name: step for step in gate.build_steps(gate.parse_args(["--mode", "quick"]))}
        command = steps["windows-common codegen gate"].command

        self.assertTrue(command[1].endswith("check_windows_common_codegen.py"))
        self.assertNotIn(removed_subset_gate, command)

    def test_macro_timeout_is_forwarded_as_environment(self) -> None:
        args = gate.parse_args(["--macro-timeout-seconds", "19"])
        steps = {step.name: step for step in gate.build_steps(args)}
        self.assertEqual(steps["macro fixtures"].env["WINDOWS_CJ_MACRO_CHECK_TIMEOUT_SECONDS"], "19")

    def test_all_steps_receive_cj_heap_size(self) -> None:
        step = gate.Step("sample", ["python", "-V"], env={"EXTRA": "1"})
        env = gate.merged_env(step, {"PATH": "x", "cjHeapSize": "1GB"})
        self.assertEqual(env["cjHeapSize"], "32GB")
        self.assertEqual(env["EXTRA"], "1")

    def test_quick_dry_run_prints_commands_without_running_them(self) -> None:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            result = gate.main(["--mode", "quick", "--dry-run"])

        self.assertEqual(result, 0)
        output = stdout.getvalue()
        self.assertIn("mode = quick", output)
        self.assertIn("check_windows_common_codegen.py", output)
        self.assertIn("check_workspace_setup.py", output)
        self.assertIn("check_ignored_results.py", output)
        self.assertIn("check_abi_ownership.py", output)
        self.assertIn("# dry-run: skipped", output)
        self.assertIn("WinUI demo smoke = skipped", output)


if __name__ == "__main__":
    unittest.main()
