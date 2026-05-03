"""Dataclasses mirroring winmd-to-json JSON output structure.

These are intentionally permissive — we keep extra fields unfrozen and as Optional
so future winmd-to-json schema bumps don't immediately break loading. Field names
are snake_case for Python convention; the JSON has PascalCase fields and
loader.py is responsible for the case conversion.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class Signature:
    """A type signature (recursive: pointers wrap inner signatures)."""

    kind: str  # "Primitive" | "Type" | "Pointer" | "Array" | "Generic" | "GenericParameter" | "ModifiedType"
    name: str | None = None
    namespace: str | None = None
    type: Signature | None = None
    type_arguments: list[Signature] | None = None
    modifier_type: Signature | None = None
    unmodified_type: Signature | None = None
    is_required: bool | None = None
    lower_bounds: list[int] | None = None
    rank: int | None = None
    sizes: list[int] | None = None
    comment: str | None = None


@dataclass
class CustomAttributeFixedArgument:
    type: Signature
    value: Any  # primitive, string, list, or another CustomAttributeFixedArgument


@dataclass
class CustomAttributeNamedArgument:
    name: str
    type: Signature
    kind: str  # "Field" | "Property"
    value: Any


@dataclass
class CustomAttribute:
    type: str  # full namespace.name of attribute class
    fixed_arguments: list[CustomAttributeFixedArgument]
    named_arguments: list[CustomAttributeNamedArgument]


@dataclass
class TypeLayout:
    is_default: bool
    packing_size: int
    size: int


@dataclass
class FieldDefinition:
    name: str
    signature: Signature
    attributes: list[str]
    custom_attributes: list[CustomAttribute]
    default_value: Any  # None or { "Type": "...", "Value": ... }
    offset: int
    relative_virtual_address: int


@dataclass
class Parameter:
    name: str
    sequence_number: int
    attributes: list[str]
    custom_attributes: list[CustomAttribute]
    default_value: Any
    signature: Signature | None = None  # may be omitted for the return parameter slot


@dataclass
class MethodSignature:
    return_type: Signature
    parameters: list[Signature]
    generic_parameter_count: int
    header: dict[str, Any]


@dataclass
class MethodImport:
    name: str
    module: str
    attributes: list[str]


@dataclass
class MethodDefinition:
    name: str
    signature: MethodSignature
    parameters: list[Parameter]
    attributes: list[str]
    impl_attributes: list[str]
    custom_attributes: list[CustomAttribute]
    relative_virtual_address: int
    method_import: MethodImport | None = None


@dataclass
class GenericParameter:
    name: str
    sequence_number: int
    attributes: list[str]
    custom_attributes: list[CustomAttribute]
    constraints: list[Any]


@dataclass
class InterfaceImplementation:
    type_definition: Any | None = None  # JsTypeDefinitionNamespaceAndNameOnly when handle is TypeDefinition
    type_reference: Any | None = None
    type_specification: Any | None = None
    custom_attributes: list[CustomAttribute] = field(default_factory=list)


@dataclass
class EventDefinition:
    name: str
    type: Signature
    attributes: list[str]
    custom_attributes: list[CustomAttribute]
    accessors: dict[str, Any]


@dataclass
class PropertyDefinition:
    name: str
    signature: MethodSignature
    attributes: list[str]
    custom_attributes: list[CustomAttribute]
    accessors: dict[str, Any]
    default_value: Any


@dataclass
class TypeDefinition:
    namespace: str
    name: str
    base_type: str | None
    is_nested: bool
    attributes: list[str]
    custom_attributes: list[CustomAttribute]
    fields: list[FieldDefinition]
    interface_implementations: list[InterfaceImplementation]
    layout: TypeLayout | None
    methods: list[MethodDefinition]
    nested_types: list[TypeDefinition]
    generic_parameters: list[GenericParameter]
    events: list[EventDefinition]
    properties: list[PropertyDefinition]
    # Increment fields added by windows-cj-bindgen vendoring of ynkdir/winmd-printer:
    supported_architectures: list[str]
    supported_os_platform: str | None
    is_experimental: bool
    source_set: str


@dataclass
class WinmdFile:
    """Top-level wrapper around the JSON output of winmd-to-json."""

    winmd_file: str
    winmd_sha256: str  # hex sha256 of the .winmd file content
    tool_version: str
    schema_version: str
    source_set: str
    types: list[TypeDefinition]
