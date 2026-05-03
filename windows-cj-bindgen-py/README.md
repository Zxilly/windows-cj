# windows-cj-bindgen

VPGC algorithm bindgen for windows-cj. Generates Cangjie projection from WinMD metadata
following the Visibility-Preserving Guarded Condensation algorithm.

## Status

M0 setup phase. Most functionality is not yet implemented.
See [`../docs/superpowers/specs/2026-05-03-vpgc-bindgen-rewrite-design.md`](../docs/superpowers/specs/2026-05-03-vpgc-bindgen-rewrite-design.md)
for design.

## Install (development)

```bash
cd windows-cj/windows-cj-bindgen-py
pip install -e ".[test,dev]"
```

## Run tests

```bash
pytest
```

## Lint and type check

```bash
ruff check .
ruff format --check .
mypy src
```

## License

MIT
