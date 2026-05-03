"""windows_cj_bindgen.winmd_json: Python wrapper around winmd-to-json C# tool.

High-level entry point: parse_winmd(winmd_path) → WinmdFile dataclass.

Lower-level building blocks:
- run_winmd_to_json(winmd_path) → dict (raw JSON)
- load_winmd_file(dict) → WinmdFile (dict → dataclass)
- cache_key, store_cached, load_cached for caching
"""

from __future__ import annotations

from pathlib import Path

from windows_cj_bindgen.winmd_json.cache import (
    cache_key,
    load_cached,
    store_cached,
)
from windows_cj_bindgen.winmd_json.exceptions import (
    WinmdJsonError,
    WinmdParseError,
    WinmdToolNotFoundError,
)
from windows_cj_bindgen.winmd_json.loader import load_winmd_file
from windows_cj_bindgen.winmd_json.runner import locate_tool, run_winmd_to_json
from windows_cj_bindgen.winmd_json.schema import (
    CustomAttribute,
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


def parse_winmd(
    winmd_path: Path,
    workspace_root: Path | None = None,
    cache_dir: Path | None = None,
) -> WinmdFile:
    """High-level: subprocess + JSON load + dict → WinmdFile dataclass.

    If cache_dir is given, attempts cache lookup before subprocess; stores
    fresh subprocess output on miss.
    """
    if cache_dir is not None:
        winmd_bytes = winmd_path.read_bytes()
        # Determine tool version by querying the tool. For M1 we hardcode it
        # to match the csproj <Version>1.0.0</Version>; M2+ may add a query
        # mechanism if the tool is updated independently.
        tool_version = "1.0.0"
        key = cache_key(winmd_bytes=winmd_bytes, tool_version=tool_version)
        hit = load_cached(cache_dir=cache_dir, key=key)
        if hit is not None:
            return load_winmd_file(hit)
        data = run_winmd_to_json(winmd_path, workspace_root=workspace_root)
        store_cached(cache_dir=cache_dir, key=key, data=data)
        return load_winmd_file(data)
    # No cache → straight pass-through
    data = run_winmd_to_json(winmd_path, workspace_root=workspace_root)
    return load_winmd_file(data)


__all__ = [
    "CustomAttribute",
    "EventDefinition",
    "FieldDefinition",
    "GenericParameter",
    "InterfaceImplementation",
    "MethodDefinition",
    "MethodImport",
    "MethodSignature",
    "Parameter",
    "PropertyDefinition",
    "Signature",
    "TypeDefinition",
    "TypeLayout",
    "WinmdFile",
    "WinmdJsonError",
    "WinmdParseError",
    "WinmdToolNotFoundError",
    "cache_key",
    "load_cached",
    "load_winmd_file",
    "locate_tool",
    "parse_winmd",
    "run_winmd_to_json",
    "store_cached",
]
