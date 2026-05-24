# 概述

windows-cj 把庞大的 Windows API 拆分成若干个职责单一的仓颉包。这一节先建立全局视野：你会调用哪些层次的 API，它们分别由哪些包支撑，以及该从哪里入手。

## 三个层次的 Windows API

Windows 平台的 API 大致分三层，windows-cj 对三者都提供支持：

| 层次 | 典型代表 | 调用风格 |
| --- | --- | --- |
| **Win32（C 风格）** | `CreateThreadpoolWork`、`MessageBoxW`、注册表函数 | 直接调用导出函数，参数多为指针 / 句柄 |
| **COM** | `IUnknown`、`IDXGIFactory`、Shell 接口 | 通过虚函数表（vtable）调用，需要 `QueryInterface` |
| **WinRT** | `Windows.Foundation.Uri`、集合、异步 | 在 COM 之上，带运行时类型系统、激活工厂、泛型投影 |

越往下越底层、越接近裸 ABI；越往上越现代、越贴近仓颉习惯。三层共享同一套底座类型（`GUID`、`HRESULT`、`BOOL`、字符串），它们集中在 `windows-core`、`windows-result`、`windows-strings` 等基础包里。

## 一张依赖速写

```text
windows-result   ── 错误码 / HRESULT / BOOL / GUID
windows-strings  ── HString / BSTR / PCWSTR / PWSTR
        │
        ▼
windows-core     ── COM 接口底座、vtable、Type 投影、WinRT-ABI 底座
        │
        ├── windows-interface / windows-implement  ── 声明并实现 COM 接口
        ├── windows-collections                    ── WinRT 集合（IVector / IMap …）
        ├── windows-future                         ── WinRT 异步（IAsyncOperation …）
        └── windows-foundation                     ── Foundation 投影（Uri / PropertyValue …）
                │
                ▼
        windows-winui3   ── WinUI 3 / Windows App SDK 支持
```

`windows-bindgen` 独立于运行时之外：它是一个命令行工具，按需把元数据生成成仓颉源码包，供上面这些层消费。

## 我应该从哪里开始？

- 只想调用一个传统 Win32 函数？→ [调用第一个 Win32 API](first-win32-api.md)
- 要在字符串、错误码上和 Windows 打交道？→ [处理字符串](strings.md) 和 [错误处理与 HRESULT](error-handling.md)
- 要拿到并使用一个 COM 接口？→ [调用 COM API 与查询接口](com-api.md)
- 要把自己的仓颉类型暴露成 COM 接口？→ [实现 COM 接口](implement-com.md)
- 要消费 WinRT 运行时类、集合、异步？→ [调用 WinRT API](winrt-api.md)
- 要写图形界面？→ [WinUI 3 实战](winui3.md)

下一节先把环境装好。
