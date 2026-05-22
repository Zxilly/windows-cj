#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import json
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


def _make_workspace(tmp_path: Path, helpers_text: str = "func f() {}") -> tuple[Path, Path]:
    """Create an empty winmd-json dir and a helpers file; tests add winmd files."""
    winmd = tmp_path / "winmd-json"
    winmd.mkdir()
    helpers = tmp_path / "native_helpers.cj"
    helpers.write_text(helpers_text, encoding="utf-8")
    return winmd, helpers


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
        # HRESULT must win over the leading-H handle heuristic.
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

    def test_status_enum_is_other_value(self) -> None:
        self.assertEqual(scanner.classify_return_bucket(_type("RPC_STATUS")), "OtherValue")


class DocUrlTests(unittest.TestCase):
    def test_extracts_documentation_url(self) -> None:
        method = _pinvoke("Foo", "X.dll", _primitive("UInt32"), doc="https://learn.example/foo")
        self.assertEqual(scanner.extract_doc_url(method), "https://learn.example/foo")

    def test_ignores_non_documentation_attribute(self) -> None:
        method = _pinvoke("Foo", "X.dll", _primitive("UInt32"))
        method["CustomAttributes"].append(
            {"Type": "Some.Other.Attribute", "FixedArguments": [{"Value": "ignored"}]}
        )
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

    def test_ignores_dll_args_and_other_identifier_compares(self) -> None:
        # DLL string args and non-`name` identifier compares must not be captured;
        # the dot-free `fullName` value proves the rejection is the identifier,
        # not an accident of dots in the value.
        source = (
            'nativeMethodImportsFromModule(method, "WINHTTP.dll")\n'
            'fullName == "HRESULT"\n'
            'method.fullName == "SomeType"\n'
        )
        self.assertEqual(scanner.parse_classified_method_names(source), set())

    def test_captures_not_equal_guard(self) -> None:
        # `if (method.name != "X") { return false }` means X is special-cased.
        source = 'if (method.name != "WSAWaitForMultipleEvents") { return false }'
        self.assertEqual(
            scanner.parse_classified_method_names(source), {"WSAWaitForMultipleEvents"}
        )


class HighConfidenceFlagTests(unittest.TestCase):
    def test_qualifying_cases_flagged(self) -> None:
        for bucket, dll in [("UInt32", "WINHTTP.dll"), ("Int32", "WS2_32.dll"), ("WIN32_ERROR", "DNSAPI.dll")]:
            with self.subTest(bucket=bucket, dll=dll):
                self.assertTrue(
                    scanner.is_high_confidence_unclassified(bucket, dll, classified=False)
                )

    def test_non_qualifying_cases_not_flagged(self) -> None:
        self.assertFalse(
            scanner.is_high_confidence_unclassified("UInt32", "WINHTTP.dll", classified=True)
        )
        self.assertFalse(
            scanner.is_high_confidence_unclassified("UInt32", "KERNEL32.dll", classified=False)
        )
        for bucket in ("HRESULT", "BOOL", "Pointer"):
            with self.subTest(bucket=bucket):
                self.assertFalse(
                    scanner.is_high_confidence_unclassified(bucket, "WINHTTP.dll", classified=False)
                )


class RecordTests(unittest.TestCase):
    _NS = "Windows.Win32.Networking.WinHttp"

    def test_classified_record(self) -> None:
        method = _pinvoke("WinHttpReadDataEx", "WINHTTP.dll", _primitive("UInt32"))
        record = scanner.build_record(self._NS, method, {"WinHttpReadDataEx"})
        self.assertTrue(record.classified)
        self.assertFalse(record.high_confidence_unclassified)
        self.assertEqual(record.raw_return, "Primitive:UInt32")

    def test_unclassified_record_is_high_confidence(self) -> None:
        method = _pinvoke("WinHttpProtocolSend", "WINHTTP.dll", _primitive("UInt32"))
        record = scanner.build_record(self._NS, method, {"WinHttpReadDataEx"})
        self.assertFalse(record.classified)
        self.assertTrue(record.high_confidence_unclassified)

    def test_missing_module_falls_back(self) -> None:
        method = {"Name": "Foo", "Import": {"Name": "Foo"}, "Signature": {"ReturnType": _primitive("UInt32")}}
        self.assertEqual(scanner.build_record("NS", method, set()).dll, "?")

    def test_missing_signature_does_not_crash(self) -> None:
        method = {"Name": "Foo", "Import": {"Name": "Foo", "Module": {"Name": "X.dll"}}}
        record = scanner.build_record("NS", method, set())
        self.assertEqual(record.return_bucket, "OtherValue")


class ScanTests(unittest.TestCase):
    def test_scan_end_to_end(self) -> None:
        with tempfile.TemporaryDirectory(prefix="scan-native-") as tmp:
            winmd, helpers = _make_workspace(
                Path(tmp),
                helpers_text='func f(name: String) { return name == "WinHttpReadDataEx" }',
            )
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
            records = scanner.scan(winmd, helpers)
            self.assertEqual(len(records), 3)
            candidates = scanner.high_confidence_candidates(records)
            self.assertEqual([c.name for c in candidates], ["WinHttpProtocolSend"])

    def test_scan_skips_non_metadata_json(self) -> None:
        with tempfile.TemporaryDirectory(prefix="scan-native-") as tmp:
            winmd, helpers = _make_workspace(Path(tmp))
            (winmd / "manifest.json").write_text(json.dumps({"unrelated": 1}), encoding="utf-8")
            (winmd / "broken.json").write_text("{not json", encoding="utf-8")
            self.assertEqual(scanner.scan(winmd, helpers), [])

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


class RenderTests(unittest.TestCase):
    def _records(self) -> list[scanner.MethodRecord]:
        ns = "Windows.Win32.Networking.WinHttp"
        return [
            scanner.MethodRecord("WinHttpProtocolSend", ns, "WINHTTP.dll", "UInt32", "Primitive:UInt32", None, False),
            scanner.MethodRecord("WinHttpReadDataEx", ns, "WINHTTP.dll", "UInt32", "Primitive:UInt32", None, True),
        ]

    def test_markdown_lists_only_candidates(self) -> None:
        md = scanner.render_markdown(self._records())
        self.assertIn("WinHttpProtocolSend", md)
        self.assertIn("Total P/Invoke exports scanned: 2", md)
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

    def test_full_records_are_opt_in(self) -> None:
        self.assertNotIn("records", json.loads(scanner.render_json(self._records())))
        full = json.loads(scanner.render_json(self._records(), include_all_records=True))
        self.assertEqual(len(full["records"]), 2)


class BaselineTests(unittest.TestCase):
    def test_load_baseline_json_formats(self) -> None:
        cases = [
            ("list", json.dumps(["A", "B"]), {"A", "B"}),
            ("dict_accepted", json.dumps({"accepted": ["A"], "notes": "x"}), {"A"}),
        ]
        for label, content, expected in cases:
            with self.subTest(label):
                with tempfile.TemporaryDirectory() as tmp:
                    p = Path(tmp) / "b.json"
                    p.write_text(content, encoding="utf-8")
                    self.assertEqual(scanner.load_baseline(p), expected)

    def test_dict_without_accepted_raises(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "b.json"
            p.write_text(json.dumps({"names": ["A"]}), encoding="utf-8")
            with self.assertRaises(ValueError):
                scanner.load_baseline(p)

    def test_none_baseline(self) -> None:
        self.assertEqual(scanner.load_baseline(None), set())


class MainCheckTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="scan-native-main-")
        self.winmd, self.helpers = _make_workspace(Path(self._tmp.name))
        (self.winmd / "WinHttp.json").write_text(
            json.dumps(
                _doc(
                    "Windows.Win32.Networking.WinHttp",
                    [_pinvoke("WinHttpProtocolSend", "WINHTTP.dll", _primitive("UInt32"))],
                )
            ),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_check_fails_on_unbaselined_candidate(self) -> None:
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr), contextlib.redirect_stdout(io.StringIO()):
            rc = scanner.main(
                ["--winmd-json-dir", str(self.winmd), "--helpers", str(self.helpers), "--check", "--quiet"]
            )
        self.assertEqual(rc, 1)
        self.assertIn("WinHttpProtocolSend", stderr.getvalue())

    def test_check_passes_when_candidate_baselined(self) -> None:
        baseline = self.helpers.parent / "baseline.json"
        baseline.write_text(json.dumps(["WinHttpProtocolSend"]), encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            rc = scanner.main(
                [
                    "--winmd-json-dir", str(self.winmd),
                    "--helpers", str(self.helpers),
                    "--check", "--baseline", str(baseline), "--quiet",
                ]
            )
        self.assertEqual(rc, 0)

    def test_missing_winmd_dir_returns_2(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            rc = scanner.main(
                ["--winmd-json-dir", str(self.helpers.parent / "nope"), "--helpers", str(self.helpers)]
            )
        self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
