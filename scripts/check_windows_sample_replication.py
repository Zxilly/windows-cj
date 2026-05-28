#!/usr/bin/env python3
"""Check whether reference sample metadata selections can be generated locally."""

from __future__ import annotations

import argparse
import os
import re
import signal
import subprocess
import sys
import tomllib
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence


ROOT = Path(__file__).resolve().parents[1]
REF_SAMPLES_ROOT = ROOT.parent / "ref" / ("windows" + "-rs") / "crates" / "samples"
DEFAULT_BINDGEN_BIN = ROOT / "target" / "release" / "bin" / "windows_bindgen.exe"
DEFAULT_OUT_ROOT = ROOT / "target"
IGNORED_WINDOWS_FEATURES = {"std"}
DEPENDENCY_SECTION_NAMES = ("dependencies", "dev-dependencies", "build-dependencies")
MANUAL_BINDGEN_PLANS = {
    "services/time": {
        "crates": ("windows-sys",),
        "filters": (
            "SERVICE_ACCEPT_TIMECHANGE",
            "SERVICE_CONTROL_TIMECHANGE",
            "SERVICE_TIMECHANGE_INFO",
            "FileTimeToSystemTime",
            "FileTimeToLocalFileTime",
        ),
        "derives": ("SYSTEMTIME=Debug", "SERVICE_TIMECHANGE_INFO=Debug"),
    },
}


@dataclass(frozen=True)
class SamplePlan:
    rel_path: Path
    package_name: str
    crates: tuple[str, ...]
    features: tuple[str, ...]
    namespaces: tuple[str, ...]
    filters: tuple[str, ...] = ()
    derives: tuple[str, ...] = ()

    @property
    def label(self) -> str:
        return self.rel_path.as_posix()

    @property
    def uses_windows_sys(self) -> bool:
        return "windows-sys" in self.crates

    @property
    def output_package_name(self) -> str:
        return sanitize_package_name(f"sample_{self.label}")


@dataclass(frozen=True)
class CheckResult:
    sample: SamplePlan
    status: str
    reason: str = ""


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Verify generated bindings for reference sample feature sets.")
    parser.add_argument(
        "--action",
        choices=("inventory", "dry-run", "generate", "build"),
        default="inventory",
        help="inventory lists plans; dry-run validates bindgen; generate writes packages; build also runs cjpm build.",
    )
    parser.add_argument("--samples-root", type=Path, default=REF_SAMPLES_ROOT)
    parser.add_argument("--bindgen-bin", type=Path, default=DEFAULT_BINDGEN_BIN)
    parser.add_argument("--out-root", type=Path, default=DEFAULT_OUT_ROOT)
    parser.add_argument("--timeout-seconds", type=positive_int, default=300)
    parser.add_argument("--sample", action="append", default=[], help="Substring filter for sample path or package name.")
    parser.add_argument("--max-samples", type=positive_int, help="Limit the number of selected samples.")
    parser.add_argument(
        "--combine-by-crate",
        action="store_true",
        help="Coalesce selected samples into one windows plan and one windows-sys plan.",
    )
    parser.add_argument("--stop-on-failure", action="store_true")
    parser.add_argument("--no-clean", action="store_true", help="Do not pass --clean before generated package writes.")
    parser.add_argument(
        "--run-smoke",
        action="store_true",
        help="After build, run known noninteractive runtime smoke tests for generated sample packages.",
    )
    parser.add_argument(
        "--no-sys-for-windows-sys",
        action="store_true",
        help="Do not pass --sys for samples that depend on windows-sys.",
    )
    parser.add_argument("--self-test", action="store_true", help="Run script self-tests and exit.")
    return parser.parse_args(argv)


def sanitize_package_name(value: str) -> str:
    sanitized = re.sub(r"[^0-9A-Za-z_]+", "_", value).strip("_").lower()
    sanitized = re.sub(r"_+", "_", sanitized)
    if not sanitized:
        return "sample"
    if sanitized[0].isdigit():
        return f"sample_{sanitized}"
    return sanitized


def unique_sorted(values: Iterable[str]) -> tuple[str, ...]:
    return tuple(sorted(set(values)))


def dependency_features(data: dict, crate_name: str) -> tuple[str, ...]:
    features: list[str] = []
    for section_name in DEPENDENCY_SECTION_NAMES:
        section = data.get(section_name, {})
        if not isinstance(section, dict):
            continue
        entry = section.get(crate_name)
        if isinstance(entry, dict):
            raw_features = entry.get("features", [])
            if isinstance(raw_features, list):
                features.extend(feature for feature in raw_features if isinstance(feature, str))
    target = data.get("target", {})
    if isinstance(target, dict):
        for target_data in target.values():
            if isinstance(target_data, dict):
                features.extend(dependency_features(target_data, crate_name))
    return tuple(features)


def dependency_crates(data: dict) -> tuple[str, ...]:
    crates: list[str] = []
    for crate_name in ("windows", "windows-sys"):
        if dependency_features(data, crate_name) or dependency_declared(data, crate_name):
            crates.append(crate_name)
    return tuple(crates)


def dependency_declared(data: dict, crate_name: str) -> bool:
    for section_name in DEPENDENCY_SECTION_NAMES:
        dependencies = data.get(section_name, {})
        if isinstance(dependencies, dict) and crate_name in dependencies:
            return True
    target = data.get("target", {})
    if isinstance(target, dict):
        for target_data in target.values():
            if isinstance(target_data, dict) and dependency_declared(target_data, crate_name):
                return True
    return False


def feature_to_namespace(feature: str) -> str | None:
    if feature in IGNORED_WINDOWS_FEATURES:
        return None
    return "Windows." + feature.replace("_", ".")


def load_sample_plan(cargo_toml: Path, samples_root: Path) -> SamplePlan:
    data = tomllib.loads(cargo_toml.read_text(encoding="utf-8"))
    rel_path = cargo_toml.parent.relative_to(samples_root)
    crates = dependency_crates(data)
    features: list[str] = []
    for crate_name in ("windows", "windows-sys"):
        features.extend(dependency_features(data, crate_name))
    namespaces = [namespace for feature in features if (namespace := feature_to_namespace(feature)) is not None]
    package_section = data.get("package", {})
    package_name = ""
    if isinstance(package_section, dict):
        raw_name = package_section.get("name", "")
        if isinstance(raw_name, str):
            package_name = raw_name
    manual = MANUAL_BINDGEN_PLANS.get(rel_path.as_posix(), {})
    manual_crates = manual.get("crates", ())
    plan_crates = crates
    if isinstance(manual_crates, tuple) and manual_crates:
        plan_crates = unique_sorted([*crates, *manual_crates])
    manual_filters = manual.get("filters", ())
    manual_derives = manual.get("derives", ())
    return SamplePlan(
        rel_path=rel_path,
        package_name=package_name,
        crates=plan_crates,
        features=unique_sorted(features),
        namespaces=unique_sorted(namespaces),
        filters=manual_filters if isinstance(manual_filters, tuple) else (),
        derives=manual_derives if isinstance(manual_derives, tuple) else (),
    )


def discover_samples(samples_root: Path) -> list[SamplePlan]:
    return [load_sample_plan(path, samples_root) for path in sorted(samples_root.rglob("Cargo.toml"))]


def matches_filters(sample: SamplePlan, filters: Sequence[str]) -> bool:
    if not filters:
        return True
    haystacks = (sample.label, sample.package_name, sample.output_package_name)
    return any(filter_value in haystack for filter_value in filters for haystack in haystacks)


def selected_samples(samples: Sequence[SamplePlan], args: argparse.Namespace) -> list[SamplePlan]:
    selected = [sample for sample in samples if matches_filters(sample, args.sample)]
    if args.max_samples is not None:
        return selected[: args.max_samples]
    return selected


def combined_samples(samples: Sequence[SamplePlan]) -> list[SamplePlan]:
    plans: list[SamplePlan] = []
    for uses_sys, name, crate_name in (
        (False, "_combined/windows", "windows"),
        (True, "_combined/windows_sys", "windows-sys"),
    ):
        group = [sample for sample in samples if sample.namespaces and sample.uses_windows_sys == uses_sys]
        if not group:
            continue
        features: list[str] = []
        namespaces: list[str] = []
        for sample in group:
            features.extend(sample.features)
            namespaces.extend(sample.namespaces)
        plans.append(
            SamplePlan(
                rel_path=Path(name),
                package_name=sanitize_package_name(name),
                crates=(crate_name,),
                features=unique_sorted(features),
                namespaces=unique_sorted(namespaces),
            )
        )
    for sample in samples:
        if sample.filters:
            plans.append(sample)
    return plans


def bindgen_command(sample: SamplePlan, args: argparse.Namespace) -> list[str]:
    command = [
        "cjv",
        "exec",
        str(args.bindgen_bin),
        "default",
        "--package-name",
        sample.output_package_name,
    ]
    for namespace in sample.namespaces:
        command.extend(["--feature", namespace])
    for filter_value in sample.filters:
        command.extend(["--filter", filter_value])
    for derive in sample.derives:
        command.extend(["--derive", derive])
    if sample.uses_windows_sys and not args.no_sys_for_windows_sys:
        command.append("--sys")
    if args.action == "dry-run":
        command.append("--dry-run")
    else:
        command.extend(["--out", str(args.out_root / sample.output_package_name)])
        if not args.no_clean:
            command.append("--clean")
    return command


def build_command() -> list[str]:
    return ["cjpm", "build"]


def run_command_binary(binary: Path) -> list[str]:
    return ["cjv", "exec", str(binary)]


def merged_env() -> dict[str, str]:
    env = os.environ.copy()
    env["cjHeapSize"] = "32GB"
    return env


def kill_process_tree(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/F", "/T", "/PID", str(process.pid)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def run_command(command: list[str], *, cwd: Path, timeout_seconds: int) -> tuple[int, str]:
    print(f"+ {cwd}> {' '.join(command)}", flush=True)
    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    process = subprocess.Popen(
        command,
        cwd=cwd,
        env=merged_env(),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        creationflags=creationflags,
        start_new_session=(os.name != "nt"),
    )
    try:
        output, _ = process.communicate(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        kill_process_tree(process)
        output, _ = process.communicate()
        if output:
            print(output, end="")
        return 124, f"timeout after {timeout_seconds}s"
    if output:
        print(output, end="")
    return process.returncode, output or ""


def inventory_result(sample: SamplePlan) -> CheckResult:
    if not sample.namespaces and not sample.filters:
        return CheckResult(sample, "SKIP", "no Windows feature metadata in Cargo.toml")
    return CheckResult(sample, "PLAN", ", ".join(sample.namespaces))


def check_sample(sample: SamplePlan, args: argparse.Namespace) -> CheckResult:
    if not sample.namespaces and not sample.filters:
        return CheckResult(sample, "SKIP", "no Windows feature metadata in Cargo.toml")
    if args.action == "inventory":
        return inventory_result(sample)
    code, output = run_command(bindgen_command(sample, args), cwd=ROOT, timeout_seconds=args.timeout_seconds)
    if code != 0:
        return CheckResult(sample, "FAIL", summarize_failure(code, output))
    if args.action != "build":
        return CheckResult(sample, "PASS")
    out_dir = args.out_root / sample.output_package_name
    code, output = run_command(build_command(), cwd=out_dir, timeout_seconds=args.timeout_seconds)
    if code != 0:
        return CheckResult(sample, "FAIL", summarize_failure(code, output))
    if args.run_smoke:
        smoke_result = run_sample_smoke(sample, out_dir, args)
        if smoke_result is not None:
            return smoke_result
    return CheckResult(sample, "PASS")


def dependency_path(from_dir: Path, dependency_dir: Path) -> str:
    return os.path.relpath(dependency_dir, from_dir).replace(os.sep, "/")


def write_text_if_changed(path: Path, content: str) -> None:
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return
    path.write_text(content, encoding="utf-8")


def run_sample_smoke(sample: SamplePlan, out_dir: Path, args: argparse.Namespace) -> CheckResult | None:
    if sample.label == "windows/xml":
        return run_xml_smoke(sample, out_dir, args)
    if sample.label == "services/time":
        return run_services_time_smoke(sample, out_dir, args)
    return None


def run_xml_smoke(sample: SamplePlan, out_dir: Path, args: argparse.Namespace) -> CheckResult:
    smoke_dir = args.out_root / f"{sample.output_package_name}_smoke"
    package_name = f"{sample.output_package_name}_smoke"
    source = (
        XML_SMOKE_SOURCE.replace("__BINDINGS_PACKAGE__", sample.output_package_name)
        .replace("__SMOKE_PACKAGE__", package_name)
    )
    write_smoke_project(
        smoke_dir=smoke_dir,
        package_name=package_name,
        link_option='  link-option = "-lole32 -loleaut32 -lwindowsapp"\n',
        dependencies={
            sample.output_package_name: out_dir,
            "windows_core": ROOT / "windows_core",
            "windows_interface": ROOT / "windows_interface",
            "windows_libloading": ROOT / "windows_libloading",
            "windows_polyfill": ROOT / "windows_polyfill",
            "windows_strings": ROOT / "windows_strings",
        },
        source=source,
    )
    return build_and_run_smoke(sample, smoke_dir, args)


def run_services_time_smoke(sample: SamplePlan, out_dir: Path, args: argparse.Namespace) -> CheckResult:
    smoke_dir = args.out_root / f"{sample.output_package_name}_smoke"
    package_name = f"{sample.output_package_name}_smoke"
    source = (
        SERVICES_TIME_SMOKE_SOURCE.replace("__BINDINGS_PACKAGE__", sample.output_package_name)
        .replace("__SMOKE_PACKAGE__", package_name)
    )
    write_smoke_project(
        smoke_dir=smoke_dir,
        package_name=package_name,
        link_option="",
        dependencies={
            sample.output_package_name: out_dir,
            "windows_interface": ROOT / "windows_interface",
            "windows_libloading": ROOT / "windows_libloading",
            "windows_polyfill": ROOT / "windows_polyfill",
        },
        source=source,
    )
    return build_and_run_smoke(sample, smoke_dir, args)


def write_smoke_project(
    *,
    smoke_dir: Path,
    package_name: str,
    link_option: str,
    dependencies: dict[str, Path],
    source: str,
) -> None:
    src_dir = smoke_dir / "src"
    src_dir.mkdir(parents=True, exist_ok=True)
    dependency_lines = "".join(
        f'  {name} = {{ path = "{dependency_path(smoke_dir, path)}" }}\n' for name, path in dependencies.items()
    )
    manifest = (
        "[package]\n"
        f'  name = "{package_name}"\n'
        '  version = "0.1.0"\n'
        '  output-type = "executable"\n'
        '  cjc-version = "1.1.0"\n'
        '  compile-option = "-Woff unused"\n'
        f"{link_option}"
        "\n"
        "[dependencies]\n"
        f"{dependency_lines}"
    )
    write_text_if_changed(smoke_dir / "cjpm.toml", manifest)
    write_text_if_changed(src_dir / "main.cj", source)


def build_and_run_smoke(sample: SamplePlan, smoke_dir: Path, args: argparse.Namespace) -> CheckResult:
    code, output = run_command(build_command(), cwd=smoke_dir, timeout_seconds=args.timeout_seconds)
    if code != 0:
        return CheckResult(sample, "FAIL", "smoke build " + summarize_failure(code, output))
    binary = smoke_dir / "target" / "release" / "bin" / "main.exe"
    code, output = run_command(run_command_binary(binary), cwd=smoke_dir, timeout_seconds=args.timeout_seconds)
    if code != 0:
        return CheckResult(sample, "FAIL", "smoke run " + summarize_failure(code, output))
    return CheckResult(sample, "PASS", "runtime smoke passed")


XML_SMOKE_SOURCE = textwrap.dedent(
    """
    package __SMOKE_PACKAGE__

    import __BINDINGS_PACKAGE__.Data.Xml.Dom.*
    import windows_core.*

    main(): Int64 {
        let document = XmlDocument.new()
        try {
            let xml = HString("<root><child>ok</child></root>")
            try {
                try (io = document.asIXmlDocumentIO()) {
                    let hr = unsafe { io.LoadXml(xml.asRaw()) }
                    hr.check()
                }
            } finally {
                xml.close()
            }

            let root = document.DocumentElement
            try {
                var nodeNameRaw = CPointer<Unit>()
                try (node = root.asIXmlNode()) {
                    let hr = unsafe { node.NodeName(CPointer<CPointer<Unit>>(inout nodeNameRaw)) }
                    hr.check()
                }
                let nodeName = HString.fromSystemHandleTake(nodeNameRaw)
                try {
                    let name = nodeName.get()
                    println("root=${name}")
                    if (name != "root") {
                        return 1
                    }
                } finally {
                    nodeName.close()
                }

                var innerTextRaw = CPointer<Unit>()
                try (serializer = root.asIXmlNodeSerializer()) {
                    let hr = unsafe { serializer.InnerText(CPointer<CPointer<Unit>>(inout innerTextRaw)) }
                    hr.check()
                }
                let innerText = HString.fromSystemHandleTake(innerTextRaw)
                try {
                    let text = innerText.get()
                    println("text=${text}")
                    if (text != "ok") {
                        return 1
                    }
                } finally {
                    innerText.close()
                }
            } finally {
                root.close()
            }
        } finally {
            document.close()
        }
        return 0
    }
    """
).lstrip()


SERVICES_TIME_SMOKE_SOURCE = textwrap.dedent(
    """
    package __SMOKE_PACKAGE__

    import __BINDINGS_PACKAGE__.Win32.Foundation as Foundation
    import __BINDINGS_PACKAGE__.Win32.System.Services as Services
    import __BINDINGS_PACKAGE__.Win32.System.Time as Time

    main(): Int64 {
        let accept = Services.Apis.SERVICE_ACCEPT_TIMECHANGE
        let control = Services.Apis.SERVICE_CONTROL_TIMECHANGE
        var info = Services.SERVICE_TIMECHANGE_INFO()
        info.liOldTime = 11i64
        info.liNewTime = 17i64

        var fileTime = Foundation.FILETIME()
        fileTime.dwLowDateTime = 0u32
        fileTime.dwHighDateTime = 0u32
        var systemTime = Foundation.SYSTEMTIME()
        let fileTimePointer = CPointer<Foundation.FILETIME>(inout fileTime)
        let systemTimePointer = CPointer<Foundation.SYSTEMTIME>(inout systemTime)
        let ok = unsafe {
            Time.Apis.FileTimeToSystemTime(CPointer<Unit>(fileTimePointer), CPointer<Unit>(systemTimePointer))
        }

        println("service_constants=${accept},${control}")
        println("service_timechange_delta=${info.liNewTime - info.liOldTime}")
        println("filetime_ok=${ok}")
        println("systemtime=${systemTime.wYear}-${systemTime.wMonth}-${systemTime.wDay}T${systemTime.wHour}:${systemTime.wMinute}:${systemTime.wSecond}.${systemTime.wMilliseconds}")

        if (accept != 512u32 || control != 16u32 || info.liNewTime - info.liOldTime != 6i64) {
            return 1
        }
        if (ok != 1i32 || systemTime.wYear != 1601u16 || systemTime.wMonth != 1u16 || systemTime.wDay != 1u16) {
            return 1
        }
        return 0
    }
    """
).lstrip()


def summarize_failure(code: int, output: str) -> str:
    if code == 124:
        return output
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    if not lines:
        return f"exit {code}"
    return f"exit {code}: {lines[-1]}"


def print_inventory(samples: Sequence[SamplePlan]) -> None:
    for sample in samples:
        result = inventory_result(sample)
        crates = ",".join(sample.crates) if sample.crates else "-"
        features = ",".join(sample.features) if sample.features else "-"
        filters = ",".join(sample.filters) if sample.filters else "-"
        print(f"{result.status:4} {sample.label:55} crates={crates:16} features={features} filters={filters}")


def print_summary(results: Sequence[CheckResult]) -> None:
    counts: dict[str, int] = {}
    for result in results:
        counts[result.status] = counts.get(result.status, 0) + 1
        detail = f" - {result.reason}" if result.reason else ""
        print(f"{result.status:4} {result.sample.label}{detail}")
    print("")
    print("Summary: " + ", ".join(f"{name}={counts[name]}" for name in sorted(counts)))


def self_test() -> None:
    assert sanitize_package_name("windows-sys/create_window") == "windows_sys_create_window"
    assert feature_to_namespace("Win32_UI_WindowsAndMessaging") == "Windows.Win32.UI.WindowsAndMessaging"
    assert feature_to_namespace("Data_Xml_Dom") == "Windows.Data.Xml.Dom"
    assert feature_to_namespace("std") is None
    data = tomllib.loads(
        """
[package]
name = "sample"

[dependencies.windows]
workspace = true
features = ["Win32_Foundation", "std"]

[target.'cfg(windows)'.dependencies.windows-sys]
workspace = true
features = ["Win32_UI_Shell"]

[dev-dependencies.windows]
workspace = true
features = ["Win32_Foundation_Collections"]
"""
    )
    assert dependency_crates(data) == ("windows", "windows-sys")
    assert dependency_features(data, "windows") == ("Win32_Foundation", "std", "Win32_Foundation_Collections")
    assert dependency_features(data, "windows-sys") == ("Win32_UI_Shell",)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    if args.self_test:
        self_test()
        print("self-test passed")
        return 0
    samples = selected_samples(discover_samples(args.samples_root), args)
    if args.combine_by_crate:
        samples = combined_samples(samples)
    if args.action == "inventory":
        print_inventory(samples)
        return 0
    results: list[CheckResult] = []
    for sample in samples:
        result = check_sample(sample, args)
        results.append(result)
        print(f"{result.status:4} {sample.label}" + (f" - {result.reason}" if result.reason else ""), flush=True)
        if result.status == "FAIL" and args.stop_on_failure:
            break
    print_summary(results)
    return 1 if any(result.status == "FAIL" for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
