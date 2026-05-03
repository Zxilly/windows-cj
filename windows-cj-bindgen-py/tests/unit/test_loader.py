"""Unit tests for winmd_json.loader."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from windows_cj_bindgen.winmd_json.exceptions import WinmdParseError
from windows_cj_bindgen.winmd_json.loader import load_winmd_file
from windows_cj_bindgen.winmd_json.schema import (
    Signature,
    TypeDefinition,
    WinmdFile,
)


@pytest.fixture
def tiny_sample_dict() -> dict:
    fixture_path = Path(__file__).parent.parent / "fixtures" / "tiny_winmd_sample.json"
    return json.loads(fixture_path.read_text())


def test_load_returns_winmd_file(tiny_sample_dict: dict) -> None:
    wf = load_winmd_file(tiny_sample_dict)
    assert isinstance(wf, WinmdFile)
    assert wf.winmd_file == "Tiny.winmd"
    assert wf.source_set == "winmd_main"
    assert len(wf.types) == 2


def test_load_first_type_is_module(tiny_sample_dict: dict) -> None:
    wf = load_winmd_file(tiny_sample_dict)
    module = wf.types[0]
    assert isinstance(module, TypeDefinition)
    assert module.name == "<Module>"
    assert module.namespace == ""
    assert module.is_experimental is False
    assert module.supported_architectures == ["X86", "X64", "Arm64"]


def test_load_second_type_is_point(tiny_sample_dict: dict) -> None:
    wf = load_winmd_file(tiny_sample_dict)
    point = wf.types[1]
    assert point.name == "POINT"
    assert point.namespace == "Tiny.Foundation"
    assert point.base_type == "System.ValueType"
    assert point.supported_architectures == ["X64", "Arm64"]
    assert point.supported_os_platform == "windows10.0.10240"
    assert point.is_experimental is False
    assert len(point.fields) == 2


def test_load_field_signatures(tiny_sample_dict: dict) -> None:
    wf = load_winmd_file(tiny_sample_dict)
    point = wf.types[1]
    x_field, y_field = point.fields
    assert x_field.name == "x"
    assert isinstance(x_field.signature, Signature)
    assert x_field.signature.kind == "Primitive"
    assert x_field.signature.name == "Int32"
    assert y_field.name == "y"
    assert y_field.signature.name == "Int32"


def test_load_raises_on_missing_top_level_key() -> None:
    bad = {"types": []}  # missing winmd_file etc
    with pytest.raises(WinmdParseError, match="missing required key"):
        load_winmd_file(bad)


def test_load_raises_on_wrong_type_for_types() -> None:
    bad = {
        "winmd_file": "x.winmd",
        "winmd_sha256": "0" * 64,
        "tool_version": "1.0.0",
        "schema_version": "1",
        "source_set": "winmd_main",
        "types": "not-a-list",
    }
    with pytest.raises(WinmdParseError, match="types"):
        load_winmd_file(bad)


def test_load_unknown_schema_version() -> None:
    bad = {
        "winmd_file": "x.winmd",
        "winmd_sha256": "0" * 64,
        "tool_version": "1.0.0",
        "schema_version": "999",
        "source_set": "winmd_main",
        "types": [],
    }
    with pytest.raises(WinmdParseError, match="schema_version"):
        load_winmd_file(bad)


def test_load_recursive_signature() -> None:
    """Pointer signature wraps inner type signature."""
    pointer_type_def = {
        "Namespace": "X",
        "Name": "Y",
        "BaseType": None,
        "IsNested": False,
        "Attributes": [],
        "CustomAttributes": [],
        "Fields": [
            {
                "Name": "ptr",
                "Signature": {
                    "Kind": "Pointer",
                    "Type": {"Kind": "Type", "Namespace": "X", "Name": "HANDLE", "Comment": "TypeReference"},
                },
                "Attributes": [],
                "CustomAttributes": [],
                "DefaultValue": None,
                "Offset": -1,
                "RelativeVirtualAddress": 0,
            }
        ],
        "InterfaceImplementations": [],
        "Layout": None,
        "Methods": [],
        "NestedTypes": [],
        "GenericParameters": [],
        "Events": [],
        "Properties": [],
        "SupportedArchitectures": ["X64"],
        "SupportedOsPlatform": None,
        "IsExperimental": False,
        "SourceSet": "winmd_main",
    }
    wf = load_winmd_file(
        {
            "winmd_file": "x.winmd",
            "winmd_sha256": "0" * 64,
            "tool_version": "1.0.0",
            "schema_version": "1",
            "source_set": "winmd_main",
            "types": [pointer_type_def],
        }
    )
    field = wf.types[0].fields[0]
    assert field.signature.kind == "Pointer"
    assert field.signature.type is not None
    assert field.signature.type.kind == "Type"
    assert field.signature.type.name == "HANDLE"
