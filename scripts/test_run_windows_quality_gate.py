#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import unittest

import run_windows_quality_gate as gate


class QualityGatePlanTests(unittest.TestCase):
    def step_names(self, args: list[str]) -> list[str]:
        return [step.name for step in gate.build_steps(gate.parse_args(args))]

    def test_quick_mode_runs_generator_and_static_gate(self) -> None:
        self.assertEqual(
            self.step_names(["--mode", "quick"]),
            [
                "py_compile",
                "python unit tests",
                "windows-common codegen self-test",
                "vector input ABI generator check",
                "windows-runtime runner self-test",
                "windows-foundation smoke test",
                "windows-collections smoke test",
                "windows-future smoke test",
                "workspace runner self-test",
                "quick workspace Cangjie tests",
                "windows-common codegen gate",
                "workspace setup audit",
                "ignored results audit",
                "ABI ownership audit",
                "macro fixtures",
            ],
        )

    def test_full_mode_adds_workspace_tests_and_macro_fixtures(self) -> None:
        self.assertEqual(
            self.step_names([]),
            [
                "py_compile",
                "python unit tests",
                "windows-common codegen self-test",
                "vector input ABI generator check",
                "windows-runtime runner self-test",
                "windows-foundation smoke test",
                "windows-collections smoke test",
                "windows-future smoke test",
                "workspace runner self-test",
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
                "--allow-missing-winui-metadata",
            ]
        )
        steps = {step.name: step for step in gate.build_steps(args)}
        command = steps["windows-common codegen gate"].command
        self.assertIn("--timeout-seconds", command)
        self.assertIn("23", command)
        self.assertIn("--skip-regenerate", command)
        self.assertIn("--allow-missing-winui-metadata", command)

    def test_full_codegen_gate_defaults_to_available_winui_metadata_subset(self) -> None:
        steps = {step.name: step for step in gate.build_steps(gate.parse_args(["--mode", "full"]))}
        command = steps["windows-common codegen gate"].command

        self.assertIn("--allow-missing-winui-metadata", command)

    def test_quick_codegen_gate_keeps_missing_winui_metadata_opt_in(self) -> None:
        steps = {step.name: step for step in gate.build_steps(gate.parse_args(["--mode", "quick"]))}
        command = steps["windows-common codegen gate"].command

        self.assertNotIn("--allow-missing-winui-metadata", command)

    def test_codegen_gate_uses_common_bindgen_script(self) -> None:
        removed_subset_gate = "check_" + "windows" + "_sys_subset.py"
        steps = {step.name: step for step in gate.build_steps(gate.parse_args(["--mode", "quick"]))}
        command = steps["windows-common codegen gate"].command

        self.assertTrue(command[1].endswith("check_windows_common_codegen.py"))
        self.assertNotIn(removed_subset_gate, command)

    def test_quick_gate_runs_focused_cangjie_tests(self) -> None:
        args = gate.parse_args(["--mode", "quick", "--workspace-timeout-seconds", "29"])
        steps = {step.name: step for step in gate.build_steps(args)}
        command = steps["quick workspace Cangjie tests"].command

        self.assertTrue(command[1].endswith("run_windows_workspace_tests.py"))
        self.assertIn("--timeout-seconds", command)
        self.assertIn("29", command)
        self.assertEqual(
            command[-7:],
            [
                "windows-bindgen",
                "windows-core",
                "windows-implement",
                "windows-interface",
                "windows-foundation",
                "windows-collections",
                "windows-future",
            ],
        )

    def test_quick_gate_runs_per_package_runtime_smoke_tests(self) -> None:
        args = gate.parse_args(["--mode", "quick", "--workspace-timeout-seconds", "31"])
        steps = {step.name: step for step in gate.build_steps(args)}

        self.assertEqual(
            gate.QUICK_RUNTIME_SMOKE_FILTERS,
            [
                "testRealActivationFactoryReportsUnavailableClass",
                "testRealPropertyValueInt32ArrayRoundTrip",
                "testRealUriDecoderRoundTripsHStringAndCollectionProjection",
            ],
        )
        self.assertEqual(
            list(gate.RUNTIME_SMOKE_FILTERS_BY_PACKAGE.keys()),
            ["windows-foundation", "windows-collections", "windows-future"],
        )

        for package, filters in gate.RUNTIME_SMOKE_FILTERS_BY_PACKAGE.items():
            command = steps[f"{package} smoke test"].command
            self.assertTrue(command[1].endswith("run_windows_runtime_tests.py"))
            self.assertIn("--package", command)
            self.assertIn(package, command)
            self.assertIn("--timeout-seconds", command)
            self.assertIn("31", command)
            self.assertEqual(command.count("--filter"), len(filters))
            for filter_name in filters:
                self.assertIn(filter_name, command)

    def test_vector_input_abi_generator_check_uses_full_runtime_drift_check(self) -> None:
        steps = {step.name: step for step in gate.build_steps(gate.parse_args(["--mode", "quick"]))}
        command = steps["vector input ABI generator check"].command

        self.assertTrue(command[1].endswith("generate_vector_input_abi.py"))
        self.assertEqual(command[-1], "--check-all")
        self.assertNotIn("--type", command)

    def test_mode_help_mentions_generator_tests(self) -> None:
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            with self.assertRaises(SystemExit) as raised:
                gate.parse_args(["--help"])

        self.assertEqual(raised.exception.code, 0)
        self.assertIn("focused Cangjie workspace", stdout.getvalue())

    def test_macro_timeout_is_forwarded_as_environment(self) -> None:
        args = gate.parse_args(["--macro-timeout-seconds", "19"])
        steps = {step.name: step for step in gate.build_steps(args)}
        self.assertEqual(steps["macro fixtures"].env["WINDOWS_CJ_MACRO_CHECK_TIMEOUT_SECONDS"], "19")

    def test_all_steps_receive_cj_heap_size(self) -> None:
        step = gate.Step("sample", ["python", "-V"], env={"EXTRA": "1", "cjHeapSize": "1GB"})
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
        self.assertNotIn("winmd-to-json.csproj", output)
        self.assertNotIn("convert_winmd_to_json.py", output)
        self.assertIn("--self-test", output)
        self.assertIn("unittest", output)
        self.assertIn("check_windows_common_codegen.py", output)
        self.assertIn("generate_vector_input_abi.py", output)
        self.assertIn("--check-all", output)
        self.assertIn("run_windows_runtime_tests.py", output)
        for filters in gate.RUNTIME_SMOKE_FILTERS_BY_PACKAGE.values():
            for filter_name in filters:
                self.assertIn(filter_name, output)
        self.assertIn("windows-foundation", output)
        self.assertIn("windows-collections", output)
        self.assertIn("windows-future", output)
        self.assertIn("run_windows_workspace_tests.py", output)
        self.assertIn("windows-bindgen", output)
        self.assertIn("windows-core", output)
        self.assertIn("windows-implement", output)
        self.assertIn("windows-interface", output)
        self.assertIn("check_workspace_setup.py", output)
        self.assertIn("check_ignored_results.py", output)
        self.assertIn("check_abi_ownership.py", output)
        self.assertIn("# dry-run: skipped", output)
        self.assertIn("WinUI demo smoke = skipped", output)


if __name__ == "__main__":
    unittest.main()
