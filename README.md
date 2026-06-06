# windows-cj

windows-cj 是一组面向仓颉的 Windows API 绑定、投影与工具包。项目目标是在仓颉中直接调用 Win32、COM、WinRT 和 WinUI 3 相关 API，同时尽量保持仓颉自身的类型系统、GC 与资源管理习惯。

仓库根目录是一个 `cjpm` workspace，稳定支持包、运行时投影包和绑定生成器都作为独立成员维护。你可以只依赖某几个小包，也可以组合它们构建完整的 Windows 桌面应用。

## 当前状态

- 目标平台：Windows x64，GNU 风格 Windows target。
- 工具链：Cangjie STS `1.1.0`。
- 必需组件：`stdx`，用于 `windows_bindgen` 的 JSON、digest、hex 等功能。
- CI：GitHub Actions 在 `windows-latest` 上执行 workspace build 与核心包测试。

## 仓库结构

| 路径 | 说明 |
| --- | --- |
| `windows_result` | `HRESULT`、状态码、`Result<T>`、基础错误处理类型 |
| `windows_strings` | `HString`、`BSTR`、`PCWSTR`、`PWSTR`、`CWideString` 等字符串封装 |
| `windows_core` | COM/WinRT 底座、vtable、接口指针、激活工厂、ABI 数组、基础 WinRT 值类型 |
| `windows_interface` | COM 接口描述、接口包装与宏支持 |
| `windows_implement` | 在仓颉对象上实现 COM 接口的支持代码 |
| `windows_foundation` | WinRT Foundation 投影，如 `Uri`、`PropertyValue`、事件 handler、`MemoryBuffer` |
| `windows_collections` | WinRT 集合投影与 stock helpers |
| `windows_future` | WinRT async 投影、完成回调与等待 helper |
| `windows_registry` / `windows_services` / `windows_threading` | 常用 Win32 子系统 helper |
| `windows_variant` / `windows_propvariant` / `windows_safearray` | COM 自动化相关类型 |
| `windows_common` | 已签入的 generated 支持符号与 native ABI helper |
| `windows_winui3` | WinUI 3 / Windows App SDK 运行时支持 |
| `windows_metadata` | 独立 `.winmd` metadata reader API |
| `windows_bindgen` | 读取 `.winmd` 并生成仓颉绑定源码的 CLI |
| `winmd` | 项目自带的 Windows metadata 输入 |
| `web/book` | mdBook 文档源码 |
| `scripts` | 代码生成、质量检查、测试编排等维护脚本 |

更完整的包说明见 [包结构总览](web/book/src/getting-started/packages.md)。

## 安装环境

安装 Cangjie STS `1.1.0`，并确保 `cjc`、`cjpm`、`cjv` 可用：

```powershell
cjc -v
cjpm -h
cjv --version
```

如果使用 `cjv` 管理工具链，需要附带安装 `stdx` component：

```powershell
cjv install sts-1.1.0 --component stdx
```

构建前设置仓颉运行时堆上限。这个值是上限，不是预占内存：

```powershell
$env:cjHeapSize = '32GB'
```

## 构建

在仓库根目录构建整个 workspace：

```powershell
$env:cjHeapSize = '32GB'
cjpm build
```

只构建某个成员：

```powershell
$env:cjHeapSize = '32GB'
cjpm build -m windows_core
```

构建 `windows_bindgen`：

```powershell
$env:cjHeapSize = '32GB'
cjpm build -m windows_bindgen
```

## 测试

运行单个包测试：

```powershell
$env:cjHeapSize = '32GB'
cjpm test -m windows_core --no-progress --no-color
```

运行 CI 中覆盖的核心包集合：

```powershell
$env:cjHeapSize = '32GB'
$members = @(
  'windows_result', 'windows_strings', 'windows_core',
  'windows_libloading', 'windows_version',
  'windows_registry', 'windows_interface', 'windows_implement',
  'windows_polyfill', 'windows_numerics', 'windows_variant',
  'windows_propvariant', 'windows_safearray', 'windows_threading',
  'windows_services'
)

foreach ($m in $members) {
  cjpm test -m $m --no-progress --no-color
  if ($LASTEXITCODE -ne 0) { throw "test failed: $m" }
}
```

维护者常用的 workspace 检查入口：

```powershell
python .\scripts\check_workspace_setup.py
python .\scripts\check_windows_common_codegen.py --mode quick
```

## 运行可执行产物

仓颉编译产物不要直接裸跑 `.exe`。统一用 `cjv exec` 包裹执行，确保运行时环境与编译工具链一致：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe --help
```

其它 demo 或测试产物也遵循同一规则。

## 使用 windows_bindgen

`windows_bindgen` 是绑定生成器，不是运行时依赖包。它读取 `.winmd` metadata，按 feature 生成一个新的仓颉源码包。

列出可用 feature：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default --list-features
```

生成一个 Foundation 子集：

```powershell
cjv exec .\target\release\bin\windows_bindgen.exe default `
  --feature Windows.Foundation `
  --out .generated\windows `
  --clean
```

更多参数见 [用 windows_bindgen 生成绑定](web/book/src/getting-started/bindgen.md)。

## 在其它项目中依赖

在消费方 `cjpm.toml` 中按需添加路径依赖：

```toml
[package]
  name = "my_app"
  version = "0.1.0"
  output-type = "executable"
  cjc-version = "1.1.0"
  link-option = "-lole32 -loleaut32 -lwindowsapp"

[dependencies]
  windows_core = { path = "../windows-cj/windows_core" }
  windows_strings = { path = "../windows-cj/windows_strings" }
  windows_foundation = { path = "../windows-cj/windows_foundation" }
```

源码中按包名导入：

```cangjie
import windows_core.*
import windows_strings.*
import windows_foundation.*
```

`link-option` 需要写在最终可执行项目里。静态依赖包里的 native link option 不会自动向上传播。

## 文档

本仓库的使用文档位于 `web/book`：

- [引言](web/book/src/readme.md)
- [安装与环境配置](web/book/src/getting-started/installation.md)
- [包结构总览](web/book/src/getting-started/packages.md)
- [调用第一个 Win32 API](web/book/src/getting-started/first-win32-api.md)
- [调用 COM API](web/book/src/getting-started/com-api.md)
- [调用 WinRT API](web/book/src/getting-started/winrt-api.md)
- [WinUI 3 实战](web/book/src/getting-started/winui3.md)

本地构建文档：

```powershell
mdbook build web/book
```

## 发布

维护者发布到仓颉中心仓时使用 Python 脚本：

```powershell
python .\scripts\publish.py --detect-and-publish
```

脚本会按 workspace 依赖顺序发布版本号有变化的包，临时把包内 `path` 依赖改写成对应的 `version` 依赖，生成中心仓需要的 `.cjp` 和 `meta-data.json`，然后执行 `cjpm publish`。显式发布某几个包：

```powershell
python .\scripts\publish.py windows_libloading windows_strings
```

本地检查发布计划但不真正发布：

```powershell
python .\scripts\publish.py --detect-and-publish --dry-run
```

## 设计原则

- 以 Win32 / COM / WinRT ABI 行为等价为目标。
- 保持仓颉范式：对象生命周期由 GC 管理，原生资源通过 `Resource` 与显式 `close()` 管理。
- 对裸 COM 指针、native handle、BSTR、SAFEARRAY 等需要确定性释放的资源，封装层负责避免泄漏和 double free。
- 生成代码和稳定支持包分层维护：`windows_bindgen` 负责生成，`windows_common` 与各 runtime 包提供可复用底座。

## CI

主 CI 配置在 [.github/workflows/ci.yml](.github/workflows/ci.yml)。它会：

- 在 `windows-latest` 上安装 Cangjie STS `1.1.0` 和 `stdx` component。
- 构建整个 workspace。
- 测试核心包集合。
