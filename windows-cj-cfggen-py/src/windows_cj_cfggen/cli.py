"""Command-line entry point for windows-cj-cfggen."""

from __future__ import annotations

import click

from windows_cj_cfggen._version import __version__


@click.group()
@click.version_option(version=__version__, prog_name="windows-cj-cfggen")
def main() -> None:
    """VPGC cfggen for windows-cj.

    M0 阶段仅提供 --version / --help 入口。后续 milestone 实现 gen 子命令。
    """


@main.command("gen")
def gen() -> None:
    """Generate cfg.toml + link-options.txt from cjpm catalogs.

    M0 阶段为占位实现 (raises NotImplementedError).
    """
    raise NotImplementedError("windows-cj-cfggen gen 在 M0 阶段未实现。详见后续 milestone。")


if __name__ == "__main__":
    main()
