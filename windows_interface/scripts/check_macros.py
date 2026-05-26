from __future__ import annotations

import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "windows_interface"
WORK = PACKAGE / "target" / "macro-check"
DEPS_TARGET = WORK / "deps"
MACRO_SRC = PACKAGE / "src" / "macros" / "windows_interface_macros.cj"
FIXTURE_DIR = PACKAGE / "tests" / "macros"
COMMAND_TIMEOUT_SECONDS = int(os.environ.get("WINDOWS_CJ_MACRO_CHECK_TIMEOUT_SECONDS", "300"))
MACRO_DEPENDENCY_ROOT = "windows_core"


IMPORT_PACKAGES = [
    "windows_interface",
    "windows_implement",
    "windows_core",
    "windows_result",
    "windows_strings",
    "windows_libloading",
]


DESCRIPTOR_CODEGEN_GENERATOR_SOURCE = r'''
package descriptor_codegen_generator

import windows_implement.*
import windows_interface.*

main(): Int64 {
    let schema = InterfaceDescriptorSchema(
        "Fixture.IOutput",
        GUID.parse("33333333-3434-5656-7878-909090909090"),
        IUnknown.descriptorSchema(),
        "Fixture_IOutputVtbl",
        "Fixture_IOutput",
        "Fixture_IOutput_Impl",
        [
            InterfaceMethodSchema(
                "Create",
                3,
                [
                    InterfaceParameterSchema(
                        "result",
                        "CPointer<CPointer<Unit>>",
                        "OutSlot<Fixture_IOutput>",
                        InterfaceParameterBridgeKind.OutSlot
                    )
                ],
                "Int32"
            )
        ]
    )
    println(renderDescriptor(resolveSchema(schema)))
    0
}
'''.lstrip()


DESCRIPTOR_CODEGEN_COMPILE_HEADER = r'''
package descriptor_codegen_compile_fixture

import windows_core as windows_core
import windows_interface.*
import windows_interface as windows_interface
import windows_implement.*
import windows_result as windows_result

'''.lstrip()


DESCRIPTOR_CODEGEN_COMPILE_MAIN = r'''

main(): Int64 {
    let schema = Fixture_IOutput.descriptorSchema()
    if (schema.methods.size != 1) {
        return 1
    }
    if (!Fixture_IOutput.matches(Fixture_IOutput.iid())) {
        return 1
    }
    0
}
'''.lstrip()


def package_cjc_version() -> str:
    for line in (PACKAGE / "cjpm.toml").read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("cjc-version"):
            _, value = stripped.split("=", 1)
            return value.strip().strip('"')
    raise RuntimeError(f"cjc-version not found in {PACKAGE / 'cjpm.toml'}")


def cjv_toolchain_arg() -> str:
    override = os.environ.get("CJV_TOOLCHAIN", "").strip()
    if override:
        if override.startswith("+"):
            return override
        return f"+{override}"
    return f"+sts-{package_cjc_version()}"


def cjv_exec_args(executable: Path) -> list[str]:
    return ["cjv", "exec", cjv_toolchain_arg(), str(executable)]


def kill_process_tree(pid: int) -> None:
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/F", "/T", "/PID", str(pid)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return
    try:
        os.killpg(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def run(args: list[str], *, env: dict[str, str] | None = None) -> None:
    print("+ " + " ".join(args), flush=True)
    started = time.perf_counter()
    kwargs = {
        "cwd": ROOT,
        "env": env,
    }
    if os.name != "nt":
        kwargs["start_new_session"] = True
    process = subprocess.Popen(args, **kwargs)
    try:
        returncode = process.wait(timeout=COMMAND_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired as exc:
        kill_process_tree(process.pid)
        elapsed = time.perf_counter() - started
        raise RuntimeError(
            f"command timed out after {elapsed:.1f}s (limit {COMMAND_TIMEOUT_SECONDS}s): {' '.join(args)}"
        ) from exc
    elapsed = time.perf_counter() - started
    if returncode != 0:
        raise subprocess.CalledProcessError(returncode, args)
    print(f"# done in {elapsed:.2f}s", flush=True)


def capture(args: list[str], *, env: dict[str, str] | None = None) -> str:
    print("+ " + " ".join(args), flush=True)
    started = time.perf_counter()
    kwargs = {
        "cwd": ROOT,
        "env": env,
        "stdout": subprocess.PIPE,
        "text": True,
        "encoding": "utf-8",
    }
    if os.name != "nt":
        kwargs["start_new_session"] = True
    process = subprocess.Popen(args, **kwargs)
    try:
        stdout, _ = process.communicate(timeout=COMMAND_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired as exc:
        kill_process_tree(process.pid)
        elapsed = time.perf_counter() - started
        raise RuntimeError(
            f"command timed out after {elapsed:.1f}s (limit {COMMAND_TIMEOUT_SECONDS}s): {' '.join(args)}"
        ) from exc
    elapsed = time.perf_counter() - started
    if process.returncode != 0:
        if stdout:
            print(stdout, end="", flush=True)
        raise subprocess.CalledProcessError(process.returncode, args)
    print(f"# done in {elapsed:.2f}s", flush=True)
    return stdout


def member_name(package: str) -> str:
    return package


def package_output(package: str) -> Path:
    return DEPS_TARGET / "release" / package


def build_import_packages(env: dict[str, str]) -> None:
    run(
        [
            "cjpm",
            "build",
            "-m",
            member_name(MACRO_DEPENDENCY_ROOT),
            "--target-dir",
            str(DEPS_TARGET),
        ],
        env=env,
    )
    missing = [package for package in IMPORT_PACKAGES if not package_output(package).exists()]
    for package in missing:
        run(
            [
                "cjpm",
                "build",
                "-m",
                member_name(package),
                "--target-dir",
                str(DEPS_TARGET),
            ],
            env=env,
        )
    for package in IMPORT_PACKAGES:
        output = package_output(package)
        if not output.exists():
            raise RuntimeError(f"missing freshly built macro dependency: {output}")


def clean_work_dir() -> None:
    resolved = WORK.resolve()
    package_target = (PACKAGE / "target").resolve()
    if package_target not in resolved.parents:
        raise RuntimeError(f"refusing to remove unexpected path: {resolved}")
    clean_deps = os.environ.get("WINDOWS_CJ_MACRO_CHECK_CLEAN_DEPS", "") == "1"
    WORK.mkdir(parents=True, exist_ok=True)
    deps_resolved = DEPS_TARGET.resolve()
    for child in WORK.iterdir():
        if child.resolve() == deps_resolved and not clean_deps:
            continue
        if child.is_dir() and not child.is_symlink():
            shutil.rmtree(child)
        else:
            child.unlink()


def import_args() -> list[str]:
    args: list[str] = ["--import-path", str(WORK)]
    for package in IMPORT_PACKAGES:
        args.extend(["--import-path", str(package_output(package))])
    return args


def link_args() -> list[str]:
    args: list[str] = []
    for package in IMPORT_PACKAGES:
        args.extend(["-L", str(package_output(package))])
    for package in IMPORT_PACKAGES:
        args.append(f"-l{package}")
    return args


def compile_descriptor_codegen_fixture(env: dict[str, str]) -> None:
    generator_src = WORK / "descriptor_codegen_generator.cj"
    generator_src.write_text(DESCRIPTOR_CODEGEN_GENERATOR_SOURCE, encoding="utf-8")
    generator_out = WORK / "descriptor_codegen_generator"
    generator_out.mkdir()
    generator_exe = generator_out / "descriptor_codegen_generator.exe"
    run(
        [
            "cjc",
            str(generator_src),
            "-o",
            str(generator_exe),
            "-Woff",
            "unused",
            *import_args(),
            *link_args(),
        ],
        env=env,
    )
    generated_body = capture(cjv_exec_args(generator_exe), env=env)
    if "windows_core.winrtStoreGenericOut<Fixture_IOutput>(result__, value)" not in generated_body:
        raise RuntimeError("descriptor codegen fixture did not exercise generic output storage")
    if "Fixture.IOutput_CreateThunk" in generated_body:
        raise RuntimeError("descriptor codegen emitted an invalid dotted thunk identifier")
    if "extend Fixture_IOutput <: windows_core.Interface<Fixture_IOutput> {}" not in generated_body:
        raise RuntimeError("descriptor codegen did not emit the Interface<T> marker extension")

    fixture_src = WORK / "descriptor_codegen_compile_fixture.cj"
    fixture_src.write_text(
        DESCRIPTOR_CODEGEN_COMPILE_HEADER + generated_body + DESCRIPTOR_CODEGEN_COMPILE_MAIN,
        encoding="utf-8",
    )
    fixture_out = WORK / "descriptor_codegen_compile_fixture"
    fixture_out.mkdir()
    fixture_exe = fixture_out / "descriptor_codegen_compile_fixture.exe"
    run(
        [
            "cjc",
            str(fixture_src),
            "-o",
            str(fixture_exe),
            "-Woff",
            "unused",
            *import_args(),
            *link_args(),
        ],
        env=env,
    )
    run(cjv_exec_args(fixture_exe), env=env)


def main() -> int:
    clean_work_dir()
    for macrocall in FIXTURE_DIR.glob("*.macrocall"):
        macrocall.unlink()
    env = os.environ.copy()
    env["cjHeapSize"] = "32GB"

    build_import_packages(env)

    run(
        [
            "cjc",
            str(MACRO_SRC),
            "--compile-macro",
            "--output-dir",
            str(WORK),
        ],
        env=env,
    )

    fixtures = sorted(FIXTURE_DIR.glob("*.cj"))
    if not fixtures:
        raise RuntimeError(f"no macro fixtures found in {FIXTURE_DIR}")
    for fixture in fixtures:
        fixture_out = WORK / fixture.stem
        fixture_out.mkdir()
        fixture_exe = fixture_out / f"{fixture.stem}.exe"
        run(
            [
                "cjc",
                str(fixture),
                "-o",
                str(fixture_exe),
                "-Woff",
                "unused",
                *import_args(),
                *link_args(),
            ],
            env=env,
        )
        run(cjv_exec_args(fixture_exe), env=env)
    compile_descriptor_codegen_fixture(env)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
