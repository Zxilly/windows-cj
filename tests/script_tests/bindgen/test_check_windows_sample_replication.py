from __future__ import annotations

import tempfile
import textwrap
import unittest
from pathlib import Path

import check_windows_sample_replication as samples


class WindowsSampleReplicationTests(unittest.TestCase):
    def test_feature_to_namespace_maps_cargo_features(self) -> None:
        self.assertEqual(
            samples.feature_to_namespace("Win32_UI_WindowsAndMessaging"),
            "Windows.Win32.UI.WindowsAndMessaging",
        )
        self.assertEqual(samples.feature_to_namespace("Data_Xml_Dom"), "Windows.Data.Xml.Dom")
        self.assertIsNone(samples.feature_to_namespace("std"))

    def test_sample_plan_extracts_features_from_all_dependency_sections(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sample = root / "windows" / "mixed"
            sample.mkdir(parents=True)
            (sample / "Cargo.toml").write_text(
                textwrap.dedent(
                    """
                    [package]
                    name = "sample_mixed"

                    [dependencies.windows]
                    workspace = true
                    features = ["Win32_Foundation", "std"]

                    [target.'cfg(windows)'.dependencies.windows-sys]
                    workspace = true
                    features = ["Win32_UI_Shell"]

                    [dev-dependencies.windows]
                    workspace = true
                    features = ["Win32_Foundation_Collections"]

                    [target.'cfg(windows)'.build-dependencies.windows-sys]
                    workspace = true
                    features = ["Win32_System_Com"]
                    """
                ),
                encoding="utf-8",
            )

            plan = samples.load_sample_plan(sample / "Cargo.toml", root)

        self.assertEqual(plan.label, "windows/mixed")
        self.assertEqual(plan.crates, ("windows", "windows-sys"))
        self.assertEqual(
            plan.features,
            ("Win32_Foundation", "Win32_Foundation_Collections", "Win32_System_Com", "Win32_UI_Shell", "std"),
        )
        self.assertEqual(
            plan.namespaces,
            (
                "Windows.Win32.Foundation",
                "Windows.Win32.Foundation.Collections",
                "Windows.Win32.System.Com",
                "Windows.Win32.UI.Shell",
            ),
        )
        self.assertTrue(plan.uses_windows_sys)

    def test_bindgen_command_uses_cjv_exec_and_sys_for_windows_sys(self) -> None:
        args = samples.parse_args(["--action", "dry-run"])
        plan = samples.SamplePlan(
            rel_path=Path("windows-sys/message_box"),
            package_name="sample_message_box_sys",
            crates=("windows-sys",),
            features=("Win32_UI_WindowsAndMessaging",),
            namespaces=("Windows.Win32.UI.WindowsAndMessaging",),
        )

        command = samples.bindgen_command(plan, args)

        self.assertEqual(command[:4], ["cjv", "exec", str(args.bindgen_bin), "default"])
        self.assertIn("--sys", command)
        self.assertIn("--dry-run", command)
        self.assertIn("Windows.Win32.UI.WindowsAndMessaging", command)

    def test_smoke_binary_command_uses_cjv_exec(self) -> None:
        command = samples.run_command_binary(Path("target/release/bin/main.exe"))

        self.assertEqual(command[:2], ["cjv", "exec"])
        self.assertEqual(command[2], str(Path("target/release/bin/main.exe")))

    def test_combined_samples_split_windows_and_windows_sys(self) -> None:
        plans = samples.combined_samples(
            [
                samples.SamplePlan(
                    rel_path=Path("windows/xml"),
                    package_name="sample_xml",
                    crates=("windows",),
                    features=("Data_Xml_Dom",),
                    namespaces=("Windows.Data.Xml.Dom",),
                ),
                samples.SamplePlan(
                    rel_path=Path("windows-sys/message_box"),
                    package_name="sample_message_box_sys",
                    crates=("windows-sys",),
                    features=("Win32_UI_WindowsAndMessaging",),
                    namespaces=("Windows.Win32.UI.WindowsAndMessaging",),
                ),
            ]
        )

        self.assertEqual([plan.label for plan in plans], ["_combined/windows", "_combined/windows_sys"])
        self.assertFalse(plans[0].uses_windows_sys)
        self.assertTrue(plans[1].uses_windows_sys)

    def test_manual_bindgen_plan_covers_filter_only_sample(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            sample = root / "services" / "time"
            sample.mkdir(parents=True)
            (sample / "Cargo.toml").write_text(
                textwrap.dedent(
                    """
                    [package]
                    name = "sample_service_time"
                    """
                ),
                encoding="utf-8",
            )

            plan = samples.load_sample_plan(sample / "Cargo.toml", root)

        self.assertEqual(plan.label, "services/time")
        self.assertEqual(plan.crates, ("windows-sys",))
        self.assertIn("SERVICE_ACCEPT_TIMECHANGE", plan.filters)
        command = samples.bindgen_command(plan, samples.parse_args(["--action", "dry-run"]))
        self.assertIn("--filter", command)
        self.assertIn("--derive", command)
        self.assertIn("--sys", command)


if __name__ == "__main__":
    unittest.main()
