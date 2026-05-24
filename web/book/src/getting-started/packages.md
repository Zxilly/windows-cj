# 包结构总览

windows-cj 的工作区由一组职责单一的包组成。你几乎不会一次性用到全部——按需挑选即可。下表按层次分组，方便你定位入口。

## 基础底座

这几个包提供了贯穿三层 API 的公共类型，几乎所有上层包都依赖它们。

| 包名（目录） | 仓颉包名 | 职责 |
| --- | --- | --- |
| `windows-result` | `windows_result` | `HRESULT` / `Result<T>` / `BOOL` / `GUID` / `WIN32_ERROR` 等错误码与底座类型 |
| `windows-strings` | `windows_strings` | `HString` / `BSTR` / `PCWSTR` / `PWSTR` / `CWideString` 等字符串类型 |
| `windows-core` | `windows_core` | COM 接口底座、vtable、`Inspectable`、`Type` 投影、激活工厂缓存、`AgileReference`、ABI 数组，以及共享的 WinRT-ABI 底座（`DateTime` / `TimeSpan` / `Point` / `Rect` / `Size` 等值类型、`HResult`、QI helper） |
| `windows-polyfill` | `windows_polyfill` | 语言 / 标准库层面的补齐与兼容 helper |
| `windows-libloading` | `windows_libloading` | 动态库加载与导出函数解析（`LoadLibrary` / `GetProcAddress` 封装） |

## COM 接口

| 包名（目录） | 仓颉包名 | 职责 |
| --- | --- | --- |
| `windows-interface` | `windows_interface` | 声明 COM 接口及其 vtable 布局 |
| `windows-implement` | `windows_implement` | 在仓颉类型上实现既有 COM 接口 |

## WinRT 投影

| 包名（目录） | 仓颉包名 | 职责 |
| --- | --- | --- |
| `windows-foundation` | `windows_foundation` | Foundation 核心投影：`Uri` / `PropertyValue` / `IReference` / `MemoryBuffer` / `Deferral` / `EventHandler` / `TypedEventHandler` / `IStringable` / `IClosable` 等 |
| `windows-collections` | `windows_collections` | WinRT 集合投影与 stock 实现：`IVector` / `IMap` / `IIterable` + `StockVectorView` / `MapView` / `Iterator` |
| `windows-future` | `windows_future` | WinRT 异步投影与 await 机制：`IAsyncOperation` / `IAsyncAction` + handler 家族 |
| `windows-numerics` | `windows_numerics` | Numerics 易用值类型 helper（向量 / 矩阵等）|

## Win32 子系统

| 包名（目录） | 仓颉包名 | 职责 |
| --- | --- | --- |
| `windows-registry` | `windows_registry` | 注册表读写 |
| `windows-services` | `windows_services` | 服务控制管理 |
| `windows-threading` | `windows_threading` | 线程 / 线程池相关 |
| `windows-version` | `windows_version` | 系统版本信息查询 |
| `windows-variant` | `windows_variant` | `VARIANT` 类型 |
| `windows-propvariant` | `windows_propvariant` | `PROPVARIANT` 类型 |
| `windows-safearray` | `windows_safearray` | `SAFEARRAY` 类型 |

## 工具与支持

| 包名（目录） | 仓颉包名 | 职责 |
| --- | --- | --- |
| `windows-targets` | `windows_targets` | GNU 链接器所需的 Windows 导入库资源（链接期资产，非源码依赖） |
| `windows-common` | `windows_common` | 中心仓维护的 generated 支持 / 投影子集，以及可复用的底层 native ABI helper 入口（注意：它是支持符号包，**不是运行时**） |
| `windows-winui3` | `windows_winui3` | WinUI 3 / Windows App SDK 支持包 |
| `windows-bindgen` | `windows_bindgen` | 命令行绑定生成器，按需把元数据生成成仓颉源码包 |

## 怎么选

- 写一个调用传统 Win32 函数的小程序：`windows-result` + `windows-strings`（必要时加对应子系统包）。
- 消费一个 COM 接口：再加上 `windows-core`。
- 实现自己的 COM 接口：加上 `windows-interface` + `windows-implement`。
- 消费 WinRT（集合 / 异步 / Foundation）：按需加 `windows-collections` / `windows-future` / `windows-foundation`。
- 写 WinUI 3 界面：从 `windows-winui3` 入手，它会带入所需的支持符号。

接下来从最简单的场景开始：[调用第一个 Win32 API](first-win32-api.md)。
