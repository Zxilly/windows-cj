"""Exception types for winmd_json."""

from __future__ import annotations


class WinmdJsonError(Exception):
    """Base exception for winmd_json failures."""


class WinmdToolNotFoundError(WinmdJsonError):
    """Raised when the winmd-to-json.exe cannot be located or launched."""


class WinmdParseError(WinmdJsonError):
    """Raised when winmd-to-json output cannot be parsed as the expected JSON shape."""
