"""Unit tests for winmd_json.schema dataclasses."""

from __future__ import annotations

from windows_cj_bindgen.winmd_json.schema import (
    CustomAttribute,
    FieldDefinition,
    Signature,
    TypeDefinition,
    WinmdFile,
)


def test_winmd_file_construction() -> None:
    """WinmdFile dataclass holds metadata + types list."""
    wf = WinmdFile(
        winmd_file="Windows.Win32.winmd",
        winmd_sha256="0" * 64,
        tool_version="1.0.0",
        schema_version="1",
        source_set="winmd_main",
        types=[],
    )
    assert wf.winmd_file == "Windows.Win32.winmd"
    assert wf.source_set == "winmd_main"
    assert wf.types == []


def test_type_definition_minimal() -> None:
    """TypeDefinition dataclass with only required fields."""
    td = TypeDefinition(
        namespace="",
        name="<Module>",
        base_type=None,
        is_nested=False,
        attributes=[],
        custom_attributes=[],
        fields=[],
        interface_implementations=[],
        layout=None,
        methods=[],
        nested_types=[],
        generic_parameters=[],
        events=[],
        properties=[],
        supported_architectures=["X86", "X64", "Arm64"],
        supported_os_platform=None,
        is_experimental=False,
        source_set="winmd_main",
    )
    assert td.name == "<Module>"
    assert td.is_experimental is False
    assert td.supported_architectures == ["X86", "X64", "Arm64"]


def test_field_definition_minimal() -> None:
    """FieldDefinition dataclass with primitive signature."""
    fd = FieldDefinition(
        name="Length",
        signature=Signature(kind="Primitive", name="UInt32"),
        attributes=["Public"],
        custom_attributes=[],
        default_value=None,
        offset=-1,
        relative_virtual_address=0,
    )
    assert fd.name == "Length"
    assert fd.signature.kind == "Primitive"


def test_signature_nested_pointer() -> None:
    """Signature dataclass supports nested type via 'type' field."""
    inner = Signature(kind="Type", namespace="Windows.Win32.Foundation", name="HANDLE")
    outer = Signature(kind="Pointer", type=inner)
    assert outer.kind == "Pointer"
    assert outer.type is not None
    assert outer.type.name == "HANDLE"


def test_custom_attribute_minimal() -> None:
    """CustomAttribute dataclass."""
    ca = CustomAttribute(
        type="Windows.Win32.Foundation.Metadata.ConstAttribute",
        fixed_arguments=[],
        named_arguments=[],
    )
    assert ca.type.endswith(".ConstAttribute")
