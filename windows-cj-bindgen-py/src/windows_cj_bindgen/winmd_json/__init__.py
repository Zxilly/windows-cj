"""windows_cj_bindgen.winmd_json: Python wrapper around winmd-to-json C# tool.

Public API:
- WinmdJsonError: base exception
- WinmdToolNotFoundError: subclass for missing exe
- WinmdParseError: subclass for invalid output
- run_winmd_to_json(winmd_path) -> dict: low-level subprocess + JSON load
- parse_winmd(winmd_path) -> WinmdFile: high-level parse + dataclass model
"""

from __future__ import annotations

from windows_cj_bindgen.winmd_json.exceptions import (
    WinmdJsonError,
    WinmdParseError,
    WinmdToolNotFoundError,
)

__all__ = [
    "WinmdJsonError",
    "WinmdParseError",
    "WinmdToolNotFoundError",
]
