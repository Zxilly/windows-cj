#!/usr/bin/env python3
"""Verify generated output does not use Phase 0 impl.pN partitions.

By default this checks the package refreshed by build_all.py. Pass explicit
source roots to check additional generated packages.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GENERATED_SRC_ROOTS = (ROOT / "windows-sys" / "src",)
IMPL_PARTITION_IMPORT = re.compile(r"\.impl\.p\d+\b")
IMPL_PARTITION_PATH = re.compile(r"(?:^|[\\/])impl[\\/]p\d+(?:[\\/]|$)")


def source_roots() -> list[Path]:
    if len(sys.argv) > 1:
        return [Path(arg).resolve() for arg in sys.argv[1:]]
    return list(DEFAULT_GENERATED_SRC_ROOTS)


def main() -> int:
    failures: list[str] = []
    for src_root in source_roots():
        if not src_root.exists():
            continue
        for path in src_root.rglob("*.cj"):
            rendered = str(path.relative_to(ROOT))
            if IMPL_PARTITION_PATH.search(rendered):
                failures.append(f"forbidden impl partition path: {rendered}")
            text = path.read_text(encoding="utf-8")
            if IMPL_PARTITION_IMPORT.search(text):
                failures.append(f"{rendered}: contains .impl.pN import/package reference")

    if failures:
        for failure in failures[:200]:
            print(failure)
        if len(failures) > 200:
            print(f"... {len(failures) - 200} more")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
