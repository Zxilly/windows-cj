from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "windows-interface"
WORK = PACKAGE / "target" / "macro-check"
DEPS_TARGET = WORK / "deps"
MACRO_SRC = PACKAGE / "src" / "macros" / "windows_interface_macros.cj"
FIXTURE_DIR = PACKAGE / "tests" / "macros"


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


def run(args: list[str], *, env: dict[str, str] | None = None) -> None:
    print("+ " + " ".join(args), flush=True)
    subprocess.run(args, cwd=ROOT, env=env, check=True)


def member_name(package: str) -> str:
    return package.replace("_", "-")


def package_output(package: str) -> Path:
    return DEPS_TARGET / "release" / package


def build_import_packages(env: dict[str, str]) -> None:
    for package in IMPORT_PACKAGES:
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
    if WORK.exists():
        shutil.rmtree(WORK)
    WORK.mkdir(parents=True)


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
