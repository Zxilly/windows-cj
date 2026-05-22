#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SMOKE = ROOT.parent / "windows-cj-demo" / "tools" / "smoke_winui3.py"


def load_smoke_module():
    spec = importlib.util.spec_from_file_location("smoke_winui3", SMOKE)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"unable to load {SMOKE}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(SMOKE.exists(), "windows-cj-demo smoke script is unavailable")
class WinuiDemoSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.smoke = load_smoke_module()

    def report_result(self, returncode: int, stdout: str, stderr: str, timed_out: bool) -> tuple[int, str, str]:
        captured_stdout = io.StringIO()
        captured_stderr = io.StringIO()
        with contextlib.redirect_stdout(captured_stdout), contextlib.redirect_stderr(captured_stderr):
            result = self.smoke.report_result(returncode, stdout, stderr, timed_out)
        return result, captured_stdout.getvalue(), captured_stderr.getvalue()

    def test_activation_marker_passes_before_or_after_watchdog(self) -> None:
        result, stdout, stderr = self.report_result(0, "[demo] Window activated\n", "", False)
        self.assertEqual(result, 0)
        self.assertIn("[demo] Window activated", stdout)
        self.assertEqual(stderr, "")

        timed_result, _, timed_stderr = self.report_result(1, "", "[demo] Window activated\n", True)
        self.assertEqual(timed_result, 0)
        self.assertNotIn("timed out before window activation", timed_stderr)

    def test_missing_activation_marker_reports_actionable_failure(self) -> None:
        result, _, stderr = self.report_result(0, "started\n", "", False)

        self.assertEqual(result, 1)
        self.assertIn("missing window activation marker", stderr)

    def test_timeout_without_activation_marker_reports_timeout(self) -> None:
        result, _, stderr = self.report_result(0, "started\n", "", True)

        self.assertEqual(result, 1)
        self.assertIn("timed out before window activation", stderr)

    def test_nonzero_exit_preserves_process_failure_and_stderr(self) -> None:
        result, stdout, stderr = self.report_result(7, "out\n", "err\n", False)

        self.assertEqual(result, 7)
        self.assertEqual(stdout, "out\n")
        self.assertEqual(stderr, "err\n")

    def test_main_launches_demo_through_cjv_exec_mem(self) -> None:
        captured: dict[str, object] = {}

        class FakeProcess:
            returncode = 0
            pid = 12345

            def poll(self) -> int:
                return 0

            def communicate(self, timeout: int | None = None) -> tuple[str, str]:
                return "[demo] Window activated\n", ""

        def fake_popen(command, **kwargs):
            captured["command"] = command
            captured["kwargs"] = kwargs
            return FakeProcess()

        with tempfile.TemporaryDirectory(prefix="winui-smoke-test-") as temp_dir:
            exe = Path(temp_dir) / "main.exe"
            exe.write_text("placeholder\n", encoding="utf-8")
            env = {**os.environ, "WINDOWS_CJ_DEMO_EXE": str(exe), "WINDOWS_APPSDK_BOOTSTRAP_DLL": "skip-discovery"}
            with mock.patch.dict(os.environ, env, clear=True), mock.patch.object(self.smoke.subprocess, "Popen", fake_popen):
                captured_stdout = io.StringIO()
                captured_stderr = io.StringIO()
                with contextlib.redirect_stdout(captured_stdout), contextlib.redirect_stderr(captured_stderr):
                    result = self.smoke.main()

        self.assertEqual(result, 0)
        self.assertEqual(captured_stdout.getvalue(), "[demo] Window activated\n")
        self.assertEqual(captured_stderr.getvalue(), "")
        command = captured["command"]
        kwargs = captured["kwargs"]
        self.assertEqual(command, ["cjv", "exec", "+mem", str(exe)])
        self.assertNotEqual(command[0], str(exe))
        self.assertEqual(kwargs["cwd"], self.smoke.ROOT)
        self.assertEqual(kwargs["env"]["WINDOWS_CJ_DEMO_EXE"], str(exe))


if __name__ == "__main__":
    unittest.main()
