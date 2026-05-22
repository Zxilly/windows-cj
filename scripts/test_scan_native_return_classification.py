#!/usr/bin/env python3
from __future__ import annotations

import io
import json
import contextlib
import tempfile
import unittest
from pathlib import Path

import scan_native_return_classification as scanner


def _primitive(name: str) -> dict:
    return {"Kind": "Primitive", "Name": name}


def _type(name: str) -> dict:
    return {"Kind": "Type", "Name": name}


def _pinvoke(name: str, dll: str, return_type: dict, doc: str | None = None) -> dict:
    method = {
        "Name": name,
        "Import": {"Name": name, "Module": {"Name": dll}},
        "Signature": {"ReturnType": return_type},
        "CustomAttributes": [],
    }
    if doc is not None:
        method["CustomAttributes"].append(
            {
                "Type": scanner.DOCUMENTATION_ATTRIBUTE,
                "FixedArguments": [{"Value": doc}],
            }
        )
    return method


def _doc(namespace: str, methods: list[dict]) -> dict:
    return {"types": [{"Namespace": namespace, "Name": "Apis", "Methods": methods}]}


class ReturnBucketTests(unittest.TestCase):
    def test_primitive_status_integers(self) -> None:
        self.assertEqual(scanner.classify_return_bucket(_primitive("UInt32")), "UInt32")
        self.assertEqual(scanner.classify_return_bucket(_primitive("Int32")), "Int32")
        self.assertEqual(scanner.classify_return_bucket(_primitive("UIntPtr")), "UIntPtr")
        self.assertEqual(scanner.classify_return_bucket(_primitive("IntPtr")), "IntPtr")
        self.assertEqual(scanner.classify_return_bucket(_primitive("Void")), "Void")

    def test_primitive_value_types_fall_through(self) -> None:
        self.assertEqual(scanner.classify_return_bucket(_primitive("Int16")), "OtherValue")
        self.assertEqual(scanner.classify_return_bucket(_primitive("Double")), "OtherValue")

    def test_typed_status_codes(self) -> None:
        self.assertEqual(scanner.classify_return_bucket(_type("HRESULT")), "HRESULT")
        self.assertEqual(scanner.classify_return_bucket(_type("NTSTATUS")), "NTSTATUS")
        self.assertEqual(scanner.classify_return_bucket(_type("WIN32_ERROR")), "WIN32_ERROR")
        self.assertEqual(scanner.classify_return_bucket(_type("BOOL")), "BOOL")
        self.assertEqual(scanner.classify_return_bucket(_type("BOOLEAN")), "BOOL")

    def test_handles_and_pointer(self) -> None:
        self.assertEqual(scanner.classify_return_bucket(_type("HANDLE")), "Handle")
        self.assertEqual(scanner.classify_return_bucket(_type("HWND")), "Handle")
        self.assertEqual(scanner.classify_return_bucket(_type("HKEY")), "Handle")
        self.assertEqual(scanner.classify_return_bucket(_type("SOCKET")), "Handle")
        self.assertEqual(scanner.classify_return_bucket({"Kind": "Pointer"}), "Pointer")

    def test_hresult_not_treated_as_handle(self) -> None:
        # HRESULT starts with H but must classify as HRESULT, not Handle.
        self.assertFalse(scanner._looks_like_handle("HRESULT"))
        self.assertTrue(scanner._looks_like_handle("HWND"))

    def test_status_enum_is_other_value(self) -> None:
        self.assertEqual(scanner.classify_return_bucket(_type("RPC_STATUS")), "OtherValue")

    def test_raw_return_label(self) -> None:
        self.assertEqual(scanner.raw_return_label(_primitive("UInt32")), "Primitive:UInt32")
        self.assertEqual(scanner.raw_return_label(_type("HRESULT")), "Type:HRESULT")
        self.assertEqual(scanner.raw_return_label({"Kind": "Pointer"}), "Pointer")


class DocUrlTests(unittest.TestCase):
    def test_extracts_documentation_url(self) -> None:
        method = _pinvoke("Foo", "X.dll", _primitive("UInt32"), doc="https://learn.example/foo")
        self.assertEqual(scanner.extract_doc_url(method), "https://learn.example/foo")

    def test_missing_documentation_url(self) -> None:
        method = _pinvoke("Foo", "X.dll", _primitive("UInt32"))
        self.assertIsNone(scanner.extract_doc_url(method))


class ClassifiedNameParseTests(unittest.TestCase):
    def test_parses_name_and_method_name_literals(self) -> None:
        source = """
        func a(name: String): Bool {
            return name == "WinHttpReadDataEx" || name == "DnsValidateName_W"
        }
        func b(method: MethodRecord): Bool {
            return method.name == "HttpReceiveHttpRequest"
        }
        """
        names = scanner.parse_classified_method_names(source)
        self.assertEqual(
            names,
            {"WinHttpReadDataEx", "DnsValidateName_W", "HttpReceiveHttpRequest"},
        )

    def test_ignores_dll_and_full_type_names(self) -> None:
        source = 'nativeMethodImportsFromModule(method, "WINHTTP.dll")\nfullName == "Windows.Win32.Foundation.HRESULT"'
        self.assertEqual(scanner.parse_classified_method_names(source), set())

    def test_captures_not_equal_guard(self) -> None:
        # `if (method.name != "X") { return false }` means X is special-cased.
        source = 'if (method.name != "WSAWaitForMultipleEvents") { return false }'
        self.assertEqual(
            scanner.parse_classified_method_names(source), {"WSAWaitForMultipleEvents"}
        )


class HighConfidenceFlagTests(unittest.TestCase):
    def test_status_dll_integer_unclassified_is_flagged(self) -> None:
        self.assertTrue(
            scanner.is_high_confidence_unclassified("UInt32", "WINHTTP.dll", classified=False)
        )
        self.assertTrue(
            scanner.is_high_confidence_unclassified("Int32", "WS2_32.dll", classified=False)
        )
        self.assertTrue(
            scanner.is_high_confidence_unclassified("WIN32_ERROR", "DNSAPI.dll", classified=False)
        )

    def test_classified_is_not_flagged(self) -> None:
        self.assertFalse(
            scanner.is_high_confidence_unclassified("UInt32", "WINHTTP.dll", classified=True)
        )

    def test_non_status_dll_not_flagged(self) -> None:
        self.assertFalse(
            scanner.is_high_confidence_unclassified("UInt32", "KERNEL32.dll", classified=False)
        )

    def test_non_integer_bucket_not_flagged(self) -> None:
        self.assertFalse(
            scanner.is_high_confidence_unclassified("HRESULT", "WINHTTP.dll", classified=False)
        )
        self.assertFalse(
            scanner.is_high_confidence_unclassified("BOOL", "WS2_32.dll", classified=False)
        )
        self.assertFalse(
            scanner.is_high_confidence_unclassified("Pointer", "WS2_32.dll", classified=False)
        )


class RecordAndScanTests(unittest.TestCase):
    def test_build_record_marks_classification(self) -> None:
        method = _pinvoke("WinHttpReadDataEx", "WINHTTP.dll", _primitive("UInt32"))
        record = scanner.build_record(
            "Windows.Win32.Networking.WinHttp", method, {"WinHttpReadDataEx"}
        )
        self.assertTrue(record.classified)
        self.assertFalse(record.high_confidence_unclassified)

        method2 = _pinvoke("WinHttpProtocolSend", "WINHTTP.dll", _primitive("UInt32"))
        record2 = scanner.build_record(
            "Windows.Win32.Networking.WinHttp", method2, {"WinHttpReadDataEx"}
        )
        self.assertFalse(record2.classified)
        self.assertTrue(record2.high_confidence_unclassified)

    def test_iter_pinvoke_skips_non_imports(self) -> None:
        doc = _doc(
            "NS",
            [
                _pinvoke("Imported", "X.dll", _primitive("UInt32")),
                {"Name": "NotImported", "Signature": {"ReturnType": _primitive("Void")}},
            ],
        )
        names = [m["Name"] for _, m in scanner.iter_pinvoke_methods(doc)]
        self.assertEqual(names, ["Imported"])

    def test_scan_end_to_end(self) -> None:
        with tempfile.TemporaryDirectory(prefix="scan-native-") as tmp:
            tmp_path = Path(tmp)
            winmd = tmp_path / "winmd-json"
            winmd.mkdir()
            (winmd / "WinHttp.json").write_text(
                json.dumps(
                    _doc(
                        "Windows.Win32.Networking.WinHttp",
                        [
                            _pinvoke("WinHttpReadDataEx", "WINHTTP.dll", _primitive("UInt32")),
                            _pinvoke("WinHttpProtocolSend", "WINHTTP.dll", _primitive("UInt32")),
                            _pinvoke("WinHttpQueryDataAvailable", "WINHTTP.dll", _type("BOOL")),
                        ],
                    )
                ),
                encoding="utf-8",
            )
            helpers = tmp_path / "native_helpers.cj"
            helpers.write_text(
                'func f(name: String) { return name == "WinHttpReadDataEx" }',
                encoding="utf-8",
            )
            records = scanner.scan(winmd, helpers)
            self.assertEqual(len(records), 3)
            candidates = scanner.high_confidence_candidates(records)
            self.assertEqual([c.name for c in candidates], ["WinHttpProtocolSend"])

    def test_scan_skips_non_metadata_json(self) -> None:
        with tempfile.TemporaryDirectory(prefix="scan-native-") as tmp:
            tmp_path = Path(tmp)
            winmd = tmp_path / "winmd-json"
            winmd.mkdir()
            (winmd / "manifest.json").write_text(json.dumps({"unrelated": 1}), encoding="utf-8")
            (winmd / "broken.json").write_text("{not json", encoding="utf-8")
            helpers = tmp_path / "native_helpers.cj"
            helpers.write_text("func f() {}", encoding="utf-8")
            self.assertEqual(scanner.scan(winmd, helpers), [])


class RenderTests(unittest.TestCase):
    def _records(self) -> list[scanner.MethodRecord]:
        return [
            scanner.MethodRecord(
                "WinHttpProtocolSend",
                "Windows.Win32.Networking.WinHttp",
                "WINHTTP.dll",
                "UInt32",
                "Primitive:UInt32",
                None,
                False,
            ),
            scanner.MethodRecord(
                "WinHttpReadDataEx",
                "Windows.Win32.Networking.WinHttp",
                "WINHTTP.dll",
                "UInt32",
                "Primitive:UInt32",
                None,
                True,
            ),
        ]

    def test_markdown_lists_only_candidates(self) -> None:
        md = scanner.render_markdown(self._records())
        self.assertIn("WinHttpProtocolSend", md)
        self.assertIn("Total P/Invoke exports scanned: 2", md)
        # The classified method must not appear in the candidate table.
        candidate_section = md.split("## High-confidence unclassified status candidates")[1]
        self.assertNotIn("WinHttpReadDataEx", candidate_section)

    def test_json_payload_shape(self) -> None:
        payload = json.loads(scanner.render_json(self._records()))
        self.assertEqual(payload["total"], 2)
        self.assertEqual(payload["bucket_counts"], {"UInt32": 2})
        self.assertEqual(
            [r["name"] for r in payload["high_confidence_unclassified"]],
            ["WinHttpProtocolSend"],
        )


class BaselineTests(unittest.TestCase):
    def test_json_list_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "b.json"
            p.write_text(json.dumps(["A", "B"]), encoding="utf-8")
            self.assertEqual(scanner.load_baseline(p), {"A", "B"})

    def test_json_dict_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "b.json"
            p.write_text(json.dumps({"accepted": ["A"]}), encoding="utf-8")
            self.assertEqual(scanner.load_baseline(p), {"A"})

    def test_plain_text_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "b.txt"
            p.write_text("# comment\nA\nB\n", encoding="utf-8")
            self.assertEqual(scanner.load_baseline(p), {"A", "B"})

    def test_none_baseline(self) -> None:
        self.assertEqual(scanner.load_baseline(None), set())


class MainCheckTests(unittest.TestCase):
    def _setup_workspace(self) -> tuple[Path, Path]:
        tmp_path = Path(tempfile.mkdtemp(prefix="scan-native-main-"))
        winmd = tmp_path / "winmd-json"
        winmd.mkdir()
        (winmd / "WinHttp.json").write_text(
            json.dumps(
                _doc(
                    "Windows.Win32.Networking.WinHttp",
                    [_pinvoke("WinHttpProtocolSend", "WINHTTP.dll", _primitive("UInt32"))],
                )
            ),
            encoding="utf-8",
        )
        helpers = tmp_path / "native_helpers.cj"
        helpers.write_text("func f() {}", encoding="utf-8")
        return winmd, helpers

    def test_check_fails_on_unbaselined_candidate(self) -> None:
        winmd, helpers = self._setup_workspace()
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr), contextlib.redirect_stdout(io.StringIO()):
            rc = scanner.main(
                ["--winmd-json-dir", str(winmd), "--helpers", str(helpers), "--check", "--quiet"]
            )
        self.assertEqual(rc, 1)
        self.assertIn("WinHttpProtocolSend", stderr.getvalue())

    def test_check_passes_when_candidate_baselined(self) -> None:
        winmd, helpers = self._setup_workspace()
        baseline = helpers.parent / "baseline.txt"
        baseline.write_text("WinHttpProtocolSend\n", encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            rc = scanner.main(
                [
                    "--winmd-json-dir",
                    str(winmd),
                    "--helpers",
                    str(helpers),
                    "--check",
                    "--baseline",
                    str(baseline),
                    "--quiet",
                ]
            )
        self.assertEqual(rc, 0)

    def test_missing_winmd_dir_returns_2(self) -> None:
        _, helpers = self._setup_workspace()
        with contextlib.redirect_stderr(io.StringIO()):
            rc = scanner.main(
                ["--winmd-json-dir", str(helpers.parent / "nope"), "--helpers", str(helpers)]
            )
        self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
