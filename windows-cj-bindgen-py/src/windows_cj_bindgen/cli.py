"""Command-line entry point for windows-cj-bindgen."""

from __future__ import annotations

import click

from windows_cj_bindgen._version import __version__


@click.command()
@click.version_option(version=__version__, prog_name="windows-cj-bindgen")
def main() -> None:
    """VPGC bindgen for windows-cj.

    M0 阶段仅提供 --version / --help 入口。后续 milestone 实现实际功能。
    """
    click.echo(f"windows-cj-bindgen {__version__}")
    click.echo("M0 阶段: skeleton only. See docs/superpowers/specs/ for design.")


if __name__ == "__main__":
    main()
