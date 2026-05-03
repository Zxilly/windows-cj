"""Convert winmd-to-json JSON dict → schema dataclasses.

Handles the case-conversion (PascalCase JSON → snake_case Python), recursive
signature decoding, and validation of the top-level wrapper shape including
schema_version compatibility.
"""

from __future__ import annotations

from typing import Any

from windows_cj_bindgen.winmd_json.exceptions import WinmdParseError
from windows_cj_bindgen.winmd_json.schema import (
    CustomAttribute,
    CustomAttributeFixedArgument,
    CustomAttributeNamedArgument,
    EventDefinition,
    FieldDefinition,
    GenericParameter,
    InterfaceImplementation,
    MethodDefinition,
    MethodImport,
    MethodSignature,
    Parameter,
    PropertyDefinition,
    Signature,
    TypeDefinition,
    TypeLayout,
    WinmdFile,
)

SUPPORTED_SCHEMA_VERSIONS = frozenset({"1"})


def load_winmd_file(data: dict[str, Any]) -> WinmdFile:
    """Convert a top-level winmd-to-json JSON dict to a WinmdFile dataclass."""
    required = ("winmd_file", "winmd_sha256", "tool_version", "schema_version", "source_set", "types")
    for key in required:
        if key not in data:
            raise WinmdParseError(f"missing required key '{key}' in winmd-to-json output")

    sv = data["schema_version"]
    if sv not in SUPPORTED_SCHEMA_VERSIONS:
        raise WinmdParseError(f"unsupported schema_version {sv!r}; supported: {sorted(SUPPORTED_SCHEMA_VERSIONS)}")

    types_raw = data["types"]
    if not isinstance(types_raw, list):
        raise WinmdParseError(f"'types' must be a list, got {type(types_raw).__name__}")

    return WinmdFile(
        winmd_file=data["winmd_file"],
        winmd_sha256=data["winmd_sha256"],
        tool_version=data["tool_version"],
        schema_version=data["schema_version"],
        source_set=data["source_set"],
        types=[_load_type(t) for t in types_raw],
    )


def _load_type(d: dict[str, Any]) -> TypeDefinition:
    return TypeDefinition(
        namespace=d["Namespace"],
        name=d["Name"],
        base_type=d.get("BaseType"),
        is_nested=d["IsNested"],
        attributes=list(d.get("Attributes", [])),
        custom_attributes=[_load_custom_attribute(a) for a in d.get("CustomAttributes", [])],
        fields=[_load_field(f) for f in d.get("Fields", [])],
        interface_implementations=[_load_iimpl(i) for i in d.get("InterfaceImplementations", [])],
        layout=_load_layout(d.get("Layout")),
        methods=[_load_method(m) for m in d.get("Methods", [])],
        nested_types=[_load_type(n) for n in d.get("NestedTypes", [])],
        generic_parameters=[_load_generic_parameter(g) for g in d.get("GenericParameters", [])],
        events=[_load_event(e) for e in d.get("Events", [])],
        properties=[_load_property(p) for p in d.get("Properties", [])],
        supported_architectures=list(d.get("SupportedArchitectures", [])),
        supported_os_platform=d.get("SupportedOsPlatform"),
        is_experimental=d.get("IsExperimental", False),
        source_set=d.get("SourceSet", "winmd_main"),
    )


def _load_signature(d: dict[str, Any]) -> Signature:
    return Signature(
        kind=d["Kind"],
        name=d.get("Name"),
        namespace=d.get("Namespace"),
        type=_load_signature(d["Type"]) if "Type" in d and d["Type"] is not None else None,
        type_arguments=([_load_signature(t) for t in d["TypeArguments"]] if d.get("TypeArguments") else None),
        modifier_type=(
            _load_signature(d["ModifierType"]) if "ModifierType" in d and d["ModifierType"] is not None else None
        ),
        unmodified_type=(
            _load_signature(d["UnmodifiedType"]) if "UnmodifiedType" in d and d["UnmodifiedType"] is not None else None
        ),
        is_required=d.get("IsRequired"),
        lower_bounds=list(d["LowerBounds"]) if d.get("LowerBounds") is not None else None,
        rank=d.get("Rank"),
        sizes=list(d["Sizes"]) if d.get("Sizes") is not None else None,
        comment=d.get("Comment"),
    )


def _load_custom_attribute(d: dict[str, Any]) -> CustomAttribute:
    return CustomAttribute(
        type=d["Type"],
        fixed_arguments=[_load_ca_fixed(a) for a in d.get("FixedArguments", [])],
        named_arguments=[_load_ca_named(a) for a in d.get("NamedArguments", [])],
    )


def _load_ca_fixed(d: dict[str, Any]) -> CustomAttributeFixedArgument:
    return CustomAttributeFixedArgument(type=_load_signature(d["Type"]), value=d.get("Value"))


def _load_ca_named(d: dict[str, Any]) -> CustomAttributeNamedArgument:
    return CustomAttributeNamedArgument(
        name=d["Name"],
        type=_load_signature(d["Type"]),
        kind=d["Kind"],
        value=d.get("Value"),
    )


def _load_field(d: dict[str, Any]) -> FieldDefinition:
    return FieldDefinition(
        name=d["Name"],
        signature=_load_signature(d["Signature"]),
        attributes=list(d.get("Attributes", [])),
        custom_attributes=[_load_custom_attribute(a) for a in d.get("CustomAttributes", [])],
        default_value=d.get("DefaultValue"),
        offset=d["Offset"],
        relative_virtual_address=d["RelativeVirtualAddress"],
    )


def _load_iimpl(d: dict[str, Any]) -> InterfaceImplementation:
    return InterfaceImplementation(
        type_definition=d.get("TypeDefinition"),
        type_reference=d.get("TypeReference"),
        type_specification=d.get("TypeSpecification"),
        custom_attributes=[_load_custom_attribute(a) for a in d.get("CustomAttributes", [])],
    )


def _load_layout(d: dict[str, Any] | None) -> TypeLayout | None:
    if d is None:
        return None
    return TypeLayout(is_default=d["IsDefault"], packing_size=d["PackingSize"], size=d["Size"])


def _load_method(d: dict[str, Any]) -> MethodDefinition:
    return MethodDefinition(
        name=d["Name"],
        signature=_load_method_signature(d["Signature"]),
        parameters=[_load_parameter(p) for p in d.get("Parameters", [])],
        attributes=list(d.get("Attributes", [])),
        impl_attributes=list(d.get("ImplAttributes", [])),
        custom_attributes=[_load_custom_attribute(a) for a in d.get("CustomAttributes", [])],
        relative_virtual_address=d.get("RelativeVirtualAddress", 0),
        method_import=_load_method_import(d.get("MethodImport")),
    )


def _load_method_signature(d: dict[str, Any]) -> MethodSignature:
    return MethodSignature(
        return_type=_load_signature(d["ReturnType"]),
        parameters=[_load_signature(p) for p in d.get("Parameters", [])],
        generic_parameter_count=d.get("GenericParameterCount", 0),
        header=d.get("Header", {}),
    )


def _load_parameter(d: dict[str, Any]) -> Parameter:
    sig = d.get("Signature")
    return Parameter(
        name=d["Name"],
        sequence_number=d["SequenceNumber"],
        attributes=list(d.get("Attributes", [])),
        custom_attributes=[_load_custom_attribute(a) for a in d.get("CustomAttributes", [])],
        default_value=d.get("DefaultValue"),
        signature=_load_signature(sig) if sig is not None else None,
    )


def _load_method_import(d: dict[str, Any] | None) -> MethodImport | None:
    if d is None:
        return None
    return MethodImport(
        name=d["Name"],
        module=d["Module"],
        attributes=list(d.get("Attributes", [])),
    )


def _load_generic_parameter(d: dict[str, Any]) -> GenericParameter:
    return GenericParameter(
        name=d["Name"],
        sequence_number=d["SequenceNumber"],
        attributes=list(d.get("Attributes", [])),
        custom_attributes=[_load_custom_attribute(a) for a in d.get("CustomAttributes", [])],
        constraints=list(d.get("Constraints", [])),
    )


def _load_event(d: dict[str, Any]) -> EventDefinition:
    return EventDefinition(
        name=d["Name"],
        type=_load_signature(d["Type"]),
        attributes=list(d.get("Attributes", [])),
        custom_attributes=[_load_custom_attribute(a) for a in d.get("CustomAttributes", [])],
        accessors=d.get("Accessors", {}),
    )


def _load_property(d: dict[str, Any]) -> PropertyDefinition:
    return PropertyDefinition(
        name=d["Name"],
        signature=_load_method_signature(d["Signature"]),
        attributes=list(d.get("Attributes", [])),
        custom_attributes=[_load_custom_attribute(a) for a in d.get("CustomAttributes", [])],
        accessors=d.get("Accessors", {}),
        default_value=d.get("DefaultValue"),
    )
