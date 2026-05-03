#!/usr/bin/env python3
"""Verify bindgen no longer carries the legacy layered package path."""

from __future__ import annotations

import sys
from pathlib import Path


BINDGEN = Path(__file__).resolve().parents[1]
SRC = BINDGEN / "src"

FORBIDDEN_FILES = {
    "gen_layer.cj",
    "layer_assignment.cj",
}

FORBIDDEN_SNIPPETS = (
    "usesLayeredImpl",
    "LayerAssignment",
    "layerAssignment",
    "targetBucketSize",
    "BucketSize",
    "--layered",
    "--no-layered",
    "--bucket-size",
    "--target-bucket-size",
    "computeLayerAssignment",
    "namespaceHasLayeredTypes",
    "_impl_l",
)


def main() -> int:
    failures: list[str] = []
    for forbidden in sorted(FORBIDDEN_FILES):
        path = SRC / forbidden
        if path.exists():
            failures.append(f"forbidden layered source file still exists: {path}")

    for path in sorted(SRC.rglob("*.cj")):
        text = path.read_text(encoding="utf-8")
        for snippet in FORBIDDEN_SNIPPETS:
            if snippet in text:
                failures.append(f"{path}: contains forbidden snippet {snippet!r}")

    if failures:
        for failure in failures:
            print(failure)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
