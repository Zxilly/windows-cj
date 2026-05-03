# windows-cj-cfggen

VPGC feature closure resolver for windows-cj cjpm catalogs. Replaces the legacy
仓颉 `windows-cfggen` tool. Reuses BDD/predicate primitives from `windows-cj-bindgen`.

## Status

M0 setup phase. Most functionality is not yet implemented.
See [`../docs/superpowers/specs/2026-05-03-vpgc-bindgen-rewrite-design.md`](../docs/superpowers/specs/2026-05-03-vpgc-bindgen-rewrite-design.md)
for design.

## Install (development)

```bash
cd windows-cj/windows-cj-bindgen-py
pip install -e ".[test,dev]"
cd ../windows-cj-cfggen-py
pip install -e ".[test,dev]"
```

注意：必须先安装 windows-cj-bindgen-py，再安装 windows-cj-cfggen-py，因为后者
通过 monorepo path 依赖前者。

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
