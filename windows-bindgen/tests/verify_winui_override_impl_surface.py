#!/usr/bin/env python3
"""Verify WinUI override interfaces get authoring implementation surface."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


BINDGEN = Path(__file__).resolve().parents[1]
ROOT = BINDGEN.parent
WINMD_INPUTS = (
    ROOT / "winmd" / "Windows.Win32.winmd",
    ROOT / "winmd" / "Windows.winmd",
    ROOT / "winmd" / "Windows.Wdk.winmd",
)


def latest_appsdk_metadata() -> Path:
    metadata_dir = ROOT / "target" / "nuget-metadata"
    candidates = sorted(metadata_dir.glob("windows-appsdk-*.json"))
    if not candidates:
        raise SystemExit(f"missing AppSDK metadata under {metadata_dir}")
    return candidates[-1]


def bindgen_command(output_dir: Path, metadata_path: Path) -> list[str]:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    command = ["cjv", "exec", "cjpm", "run", "--"]
    for winmd in WINMD_INPUTS:
        command.extend(["--in", str(winmd)])
    for winmd in metadata["inputs"]["appsdk_winmds"]:
        command.extend(["--in", winmd])
    for winmd in metadata["inputs"]["webview2_winmds"]:
        command.extend(["--in", winmd])
    command.extend(
        [
            "--out",
            str(output_dir),
            "--no-sys",
            "--high-level",
            "--filter",
            "Microsoft.UI.Xaml",
            "--reference",
            "windows,skip-root,Windows",
            "--reference",
            "windows_webview2,full,Microsoft.Web.WebView2",
            "--jobs",
            "1",
        ]
    )
    return command


def generated_xaml_text(output_dir: Path) -> str:
    matches: list[Path] = []
    for path in output_dir.rglob("*.cj"):
        text = path.read_text(encoding="utf-8")
        if "IApplicationOverrides" in text:
            matches.append(path)
    if not matches:
        raise SystemExit("generated Microsoft.UI.Xaml output with IApplicationOverrides was not found")
    return "\n".join(path.read_text(encoding="utf-8") for path in matches)


def require(text: str, needle: str) -> None:
    if needle not in text:
        raise SystemExit(f"missing generated text: {needle}")


def forbid(text: str, needle: str) -> None:
    if needle in text:
        raise SystemExit(f"unexpected generated text: {needle}")


def main() -> int:
    env = dict(os.environ)
    env["cjHeapSize"] = env.get("cjHeapSize", "32GB")
    metadata_path = latest_appsdk_metadata()
    with tempfile.TemporaryDirectory(prefix="windows-cj-bindgen-") as temp:
        output_dir = Path(temp) / "src"
        command = bindgen_command(output_dir, metadata_path)
        print(" ".join(command), flush=True)
        result = subprocess.run(command, cwd=BINDGEN, env=env, check=False)
        if result.returncode != 0:
            return result.returncode

        text = generated_xaml_text(output_dir)
        require(text, "public static func new<Identity>(offset!: Int64 = 0): IApplicationOverridesVtbl where Identity <: IApplicationOverrides_Impl")
        require(text, "public interface IApplicationOverrides_ImplErased")
        require(text, "public interface IApplicationOverrides_Impl <: IApplicationOverrides_ImplErased")
        require(text, '"IApplicationOverridesVtbl", "IApplicationOverrides", "IApplicationOverrides_Impl"')
        require(text, "private interface ApplicationInitializationCallbackInvokerErased")
        require(text, "private interface ApplicationInitializationCallbackInvoker <: ApplicationInitializationCallbackInvokerErased")
        require(text, "private class ApplicationInitializationCallbackBox <: ApplicationInitializationCallbackInvoker")
        forbid(text, "private open class ApplicationInitializationCallbackInvokerErased")
        forbid(text, "private open class ApplicationInitializationCallbackInvoker <: ApplicationInitializationCallbackInvokerErased")
        forbid(text, "public override func Invoke(p: InParam<ApplicationInitializationCallbackParams>): Unit")
        forbid(text, "public interface IDragUIOverride_Impl")
        forbid(text, "public interface IDragUIOverride_ImplErased")
    return 0


if __name__ == "__main__":
    sys.exit(main())
