from __future__ import annotations

import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "windows-interface"
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


def member_name(package: str) -> str:
    return package.replace("_", "-")


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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
