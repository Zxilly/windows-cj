#!/usr/bin/env python3
from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import generate_vector_input_abi as generator


class VectorInputAbiGeneratorTests(unittest.TestCase):
    def test_check_collections_runtime_accepts_exact_generated_fragments(self) -> None:
        spec = generator.SPECS["Int16"]
        with tempfile.TemporaryDirectory(prefix="vector-input-abi-") as temp_dir:
            path = Path(temp_dir) / "collections_runtime.cj"
            path.write_text(
                "".join(fragment for _, fragment in generator.collections_runtime_fragments(spec)),
                encoding="utf-8",
            )
            original = generator.COLLECTIONS_RUNTIME
            generator.COLLECTIONS_RUNTIME = path
            try:
                self.assertTrue(generator.check_collections_runtime(spec))
            finally:
                generator.COLLECTIONS_RUNTIME = original

    def test_check_collections_runtime_rejects_missing_generated_fragment(self) -> None:
        spec = generator.SPECS["Int16"]
        fragments = generator.collections_runtime_fragments(spec)
        with tempfile.TemporaryDirectory(prefix="vector-input-abi-") as temp_dir:
            path = Path(temp_dir) / "collections_runtime.cj"
            path.write_text("".join(fragment for _, fragment in fragments[1:]), encoding="utf-8")
            original = generator.COLLECTIONS_RUNTIME
            generator.COLLECTIONS_RUNTIME = path
            stdout = io.StringIO()
            try:
                with contextlib.redirect_stdout(stdout):
                    self.assertFalse(generator.check_collections_runtime(spec))
            finally:
                generator.COLLECTIONS_RUNTIME = original

        self.assertIn("callVectorSetAtInt16", stdout.getvalue())

    def test_check_collections_runtime_rejects_empty_and_duplicate_fragments(self) -> None:
        spec = generator.SPECS["Int16"]
        valid_fragment = generator.render_set_at_helper(spec)
        cases = (
            [("empty", "")],
            [("first", valid_fragment), ("first", generator.render_insert_at_helper(spec))],
            [("first", valid_fragment), ("second", valid_fragment)],
        )
        for fragments in cases:
            with self.subTest(fragments=fragments):
                with tempfile.TemporaryDirectory(prefix="vector-input-abi-") as temp_dir:
                    path = Path(temp_dir) / "collections_runtime.cj"
                    path.write_text(valid_fragment, encoding="utf-8")
                    original_path = generator.COLLECTIONS_RUNTIME
                    original_fragments = generator.collections_runtime_fragments
                    generator.COLLECTIONS_RUNTIME = path
                    generator.collections_runtime_fragments = lambda _: fragments
                    try:
                        with contextlib.redirect_stdout(io.StringIO()):
                            self.assertFalse(generator.check_collections_runtime(spec))
                    finally:
                        generator.COLLECTIONS_RUNTIME = original_path
                        generator.collections_runtime_fragments = original_fragments

    def test_check_collections_runtime_rejects_duplicate_runtime_fragments(self) -> None:
        spec = generator.SPECS["Int16"]
        snippet = generator.render_set_at_helper(spec)
        with tempfile.TemporaryDirectory(prefix="vector-input-abi-") as temp_dir:
            path = Path(temp_dir) / "collections_runtime.cj"
            path.write_text(snippet + snippet, encoding="utf-8")
            original_path = generator.COLLECTIONS_RUNTIME
            original_fragments = generator.collections_runtime_fragments
            generator.COLLECTIONS_RUNTIME = path
            generator.collections_runtime_fragments = lambda _: [("set-at", snippet)]
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertFalse(generator.check_collections_runtime(spec))
            finally:
                generator.COLLECTIONS_RUNTIME = original_path
                generator.collections_runtime_fragments = original_fragments

    def test_check_all_runs_test_and_collections_checks_for_every_spec(self) -> None:
        calls: list[tuple[str, str]] = []

        def fake_check_test(spec: generator.TypeSpec) -> bool:
            calls.append(("test", spec.name))
            return True

        def fake_check_collections(spec: generator.TypeSpec) -> bool:
            calls.append(("collections", spec.name))
            return True

        with mock.patch.object(generator, "check_vector_test", side_effect=fake_check_test):
            with mock.patch.object(generator, "check_collections_runtime", side_effect=fake_check_collections):
                with mock.patch("sys.argv", ["generate_vector_input_abi.py", "--check-all"]):
                    self.assertEqual(generator.main(), 0)

        expected = []
        for spec in generator.SPECS.values():
            expected.append(("test", spec.name))
            expected.append(("collections", spec.name))
        self.assertEqual(calls, expected)

    def test_collections_write_still_requires_explicit_type(self) -> None:
        with mock.patch("sys.argv", ["generate_vector_input_abi.py", "--collections"]):
            with self.assertRaisesRegex(SystemExit, "--type is required"):
                generator.main()

    def test_check_all_cannot_be_scoped_to_one_type(self) -> None:
        with mock.patch("sys.argv", ["generate_vector_input_abi.py", "--type", "Int16", "--check-all"]):
            with self.assertRaisesRegex(SystemExit, "do not combine it with --type"):
                generator.main()


if __name__ == "__main__":
    unittest.main()
