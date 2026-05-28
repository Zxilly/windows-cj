from __future__ import annotations

import re
from pathlib import Path


TEST_ANNOTATION_RE = re.compile(r"^\s*@Test(?:\b|$)", re.MULTILINE)


class WorkspaceTestContractViolation(Exception):
    pass


def check_test_only_sources_stay_in_test_files(workspace: Path) -> None:
    for source in sorted(workspace.glob("windows_*/src/**/*.cj")):
        if source.name.endswith("_test.cj"):
            continue
        relative = source.relative_to(workspace).as_posix()
        if source.name == "test_support.cj" or source.name.endswith("_test_support.cj"):
            raise WorkspaceTestContractViolation(
                f"{relative} must be named *_support_test.cj so cjpm keeps test helpers out of production builds"
            )
        text = source.read_text(encoding="utf-8")
        if "std.unittest" in text or TEST_ANNOTATION_RE.search(text):
            raise WorkspaceTestContractViolation(
                f"{relative} imports unittest or declares tests but does not end with _test.cj"
            )
