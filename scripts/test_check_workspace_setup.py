#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path

import check_workspace_setup as setup


def write_file(root: Path, relative: str) -> None:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("placeholder\n", encoding="utf-8")


class ShellScriptGateTests(unittest.TestCase):
    def test_rejects_power_shell_and_batch_scripts(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            workspace = Path(temp_dir)
            write_file(workspace, "tools/build.ps1")
            write_file(workspace, "tools/build.bat")
            write_file(workspace, ".git/ignored.ps1")
            write_file(workspace, "target/ignored.bat")

            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                with self.assertRaises(SystemExit) as raised:
                    setup.check_no_shell_scripts(workspace)

            self.assertEqual(raised.exception.code, 1)
            message = stderr.getvalue()
            self.assertIn("tools/build.ps1", message)
            self.assertIn("tools/build.bat", message)
            self.assertNotIn("ignored.ps1", message)
            self.assertNotIn("ignored.bat", message)

    def test_reports_explicit_legacy_allowlist_entries(self) -> None:
        old_allowlist = setup.ALLOWED_LEGACY_SCRIPT_FILES
        try:
            setup.ALLOWED_LEGACY_SCRIPT_FILES = {
                "legacy/build.ps1": "kept for compatibility during migration",
            }
            with tempfile.TemporaryDirectory() as temp_dir:
                workspace = Path(temp_dir)
                write_file(workspace, "legacy/build.ps1")

                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    setup.check_no_shell_scripts(workspace)

            output = stdout.getvalue()
            self.assertIn("ALLOW: legacy script retained: legacy/build.ps1", output)
            self.assertIn("kept for compatibility during migration", output)
        finally:
            setup.ALLOWED_LEGACY_SCRIPT_FILES = old_allowlist


class WindowsStringFinalizerGateTests(unittest.TestCase):
    def write_string_sources(self, workspace: Path, ref_count_text: str, native_text: str) -> None:
        strings = workspace / "windows-strings" / "src"
        strings.mkdir(parents=True, exist_ok=True)
        (strings / "ref_count.cj").write_text(ref_count_text, encoding="utf-8")
        (strings / "native.cj").write_text(native_text, encoding="utf-8")

    def test_rejects_hstring_ref_count_mutex(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            workspace = Path(temp_dir)
            self.write_string_sources(
                workspace,
                "package windows_strings\nimport std.sync.Mutex\n",
                "package windows_strings\nfunc sysFreeStringAbi(ptr: CPointer<UInt16>): Unit {}\n",
            )

            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                with self.assertRaises(SystemExit) as raised:
                    setup.check_windows_string_finalizer_paths_are_lock_free(workspace)

            self.assertEqual(raised.exception.code, 1)
            self.assertIn("HString finalizer ref-count release lock-free", stderr.getvalue())

    def test_rejects_bstr_finalizer_symbol_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            workspace = Path(temp_dir)
            self.write_string_sources(
                workspace,
                "package windows_strings\n",
                (
                    "package windows_strings\n"
                    "let sysFreeStringProc = windows_libloading.FinalizerSafeProc(\"oleaut32.dll\", \"SysFreeString\")\n"
                    "func sysFreeStringAbi(ptr: CPointer<UInt16>): Unit {\n"
                    "    let proc = resolveOleaut32Proc(\"SysFreeString\")\n"
                    "}\n"
                ),
            )

            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                with self.assertRaises(SystemExit) as raised:
                    setup.check_windows_string_finalizer_paths_are_lock_free(workspace)

            self.assertEqual(raised.exception.code, 1)
            self.assertIn("must not resolve symbols during finalization", stderr.getvalue())

    def test_requires_bstr_finalizer_safe_proc_table(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            workspace = Path(temp_dir)
            self.write_string_sources(
                workspace,
                "package windows_strings\n",
                "package windows_strings\nfunc sysFreeStringAbi(ptr: CPointer<UInt16>): Unit {}\n",
            )

            stderr = io.StringIO()
            with contextlib.redirect_stderr(stderr):
                with self.assertRaises(SystemExit) as raised:
                    setup.check_windows_string_finalizer_paths_are_lock_free(workspace)

            self.assertEqual(raised.exception.code, 1)
            self.assertIn("FinalizerSafeProc", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
