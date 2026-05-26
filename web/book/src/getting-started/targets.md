# 链接与 windows_targets

当你调用一个 Win32 / COM / WinRT 函数（比如 `RegGetValueW`、`CoCreateInstance`、`RoGetActivationFactory`）时，仓颉只知道这个符号的**声明**，并不知道它的机器码在哪。把"符号名"对应到"系统 DLL 里的导出地址"这件事，发生在**链接期**：链接器需要一份**导入库（import library）**，里面记录了每个导出符号属于哪个 DLL、怎么跳转过去。没有这份导入库，链接会以"undefined reference"失败。

windows-cj 走的是 **GNU 工具链**（mingw 风格）。GNU 链接器用 `-l...` 选项来引入库：`-lkernel32` 找 `libkernel32.a`、`-l:libwindows.0.53.0.a` 直接按文件名引入某个归档。windows-cj 把所有需要的 Win32 导入符号都打包进了**一个**归档文件，由 `windows_targets` 包提供。

## `windows_targets` 是什么

`windows_targets` 是一个**链接期资产包**，不是普通的源码依赖。它的职责只有一个：捆绑 GNU 导入库归档（`x86_64_gnu/lib/libwindows.0.53.0.a`），并提供一组 helper API，让链接工具能定位归档路径、生成正确的 `-L` / `-l` 选项。

正因为它是资产包而非源码依赖，**普通源码包不应该**只为了拿到链接资产就把 `windows_targets` 写进自己的 `[dependencies]`。真正消费它的是链接 / 构建工具：它们找到包的根目录，再向 helper API 要归档路径或 GNU 链接选项。

历史上的生成 / 链接工具用这个归档做两件事：一是枚举可用的 Win32 导入符号，二是把一大串按 DLL 拆分的 `-l...` 替换成单一的 `-L<lib> -l:libwindows.0.53.0.a`。

## 支持矩阵

`windows_targets` 只为真正捆绑了归档文件的 target 声明"支持"。下表是当前矩阵（见 `windows_targets/src/lib.cj` 与 `windows_targets/README.md`）：

```text
| Target key     | 架构    | 工具链 | 仓颉 env | 状态        | 归档载荷                              |
| -------------- | ------- | ------ | -------- | ----------- | ------------------------------------- |
| x86_64_gnu     | x86_64  | GNU    | gnu      | supported   | x86_64_gnu/lib/libwindows.0.53.0.a    |
| i686_gnu       | i686    | GNU    | gnu      | unsupported | 无                                    |
| aarch64_gnu    | aarch64 | GNU    | gnu      | unsupported | 无                                    |
| x86_64_msvc    | x86_64  | MSVC   | （空）   | unsupported | 无                                    |
| i686_msvc      | i686    | MSVC   | （空）   | unsupported | 无                                    |
| aarch64_msvc   | aarch64 | MSVC   | （空）   | unsupported | 无                                    |
```

要点：

- **目前只有 `x86_64_gnu` 真正捆绑了归档载荷。** 这也是 windows-cj 现阶段唯一支持的链接 target（Windows x86_64 GNU）。
- "unsupported" 的 target 是矩阵里**已知但没有载荷**的 target。它们**不会**放占位归档文件——没有载荷就是没有载荷。
- MSVC 系列在矩阵里列出只是为了可被检视（introspection），但因为这个包不带 MSVC 导入库，所以是 unsupported。

每个 target 由值类型 `ImportLibTarget` 描述，带 `name` / `arch` / `toolchain` / `cangjieEnv` / `archiveDirectory` / `archiveName: Option<String>` / `supported` 等字段。注意 `archiveName` 是 `Option<String>`：unsupported target 取值为 `None`，这是它"没有载荷"的直接编码方式（仓颉用 `Option<T>` 代替 null）。

## COM / WinRT 的 `link-option`

`libwindows.0.53.0.a` 覆盖的是 Win32 基础导入符号。COM / WinRT 还需要额外的系统库，它们用各自的 `-l` 选项引入，最常见的是：

- `-lole32` —— COM 运行时核心（`CoCreateInstance`、`CoTaskMemFree` 等）。
- `-loleaut32` —— OLE 自动化（`BSTR` 的 `SysAllocStringLen` / `SysFreeString`、`VARIANT` 等）。
- `-lwindowsapp` —— WinRT 的伞库（`RoGetActivationFactory`、`WindowsCreateString` 等运行时入口）。

这些选项写在**消费方项目**（你的可执行程序）的 `cjpm.toml` 的 `[package]` 段里，用 `link-option` 字段：

```toml
[package]
  name = "my_app"
  version = "0.1.0"
  output-type = "executable"
  cjc-version = "1.1.0"
  # COM / WinRT 通常需要链接这几个系统库
  link-option = "-lole32 -loleaut32 -lwindowsapp"

[dependencies]
  windows_core = { path = "../windows-cj/windows_core" }
  windows_strings = { path = "../windows-cj/windows_strings" }
```

为什么放在最终产物这一层？因为链接是在生成可执行文件 / 动态库时发生的——只有最终把所有 `.a` 拼到一起的那一步，链接器才需要知道全部系统库。中间的静态库包（`output-type = "static"`）只是把目标码攒起来，符号留到最后再解析。所以 `link-option` 写在 `output-type = "executable"` 的项目里。

> 纯 Win32（不碰 COM/WinRT）的小程序往往连这几个 `-l` 都不需要——`libwindows.0.53.0.a` 已经把 `kernel32` / `advapi32` 等基础导入符号包含进去了。等你用到 COM / WinRT 再按需加。

## `ImportLibTarget` 的 helper API

如果你在写自己的链接 / 构建工具、需要程序化地拿到归档路径或链接选项，`windows_targets` 暴露了下面这些函数（签名见 `windows_targets/src/lib.cj`）。它们分"探测式"（返回 `Option`，不抛异常）和"强制式"（拿不到就抛 `UnsupportedTarget`）两类。

### 查询 target

```cangjie
import windows_targets.*

// 探测式：unsupported / 未知 target 返回 None，不抛异常
let probe: Option<ImportLibTarget> = findSupportedImportLibTarget("x86_64_gnu")

// 强制式：unsupported / 未知 target 抛 UnsupportedTarget
let target: ImportLibTarget = requireSupportedImportLibTarget("x86_64_gnu")

// 自动选当前编译环境对应的 target（仅在 Windows x86_64 GNU 下解析成功，否则抛异常）
let current: ImportLibTarget = requireCurrentImportLibTarget()
```

`requireCurrentImportLibTarget()` 内部用 `@When[...]` 条件编译判断当前 `os` / `arch` / `env`：只有 `Windows && x86_64 && gnu` 才返回 `x86_64_gnu`，其它组合直接抛 `UnsupportedTarget("current", "windows_targets only bundles import libraries for x86_64 Windows GNU")`。

### 取归档路径与链接选项

`ImportLibTarget` 的方法（同样有 `archive...()` 探测式和 `requireArchive...()` 强制式两套）：

```cangjie
let target = requireSupportedImportLibTarget("x86_64_gnu")

// 相对包根的归档路径
target.archiveRelativePath()
// => Some("x86_64_gnu/lib/libwindows.0.53.0.a")，unsupported target 为 None

target.requireArchiveRelativePath()
// => "x86_64_gnu/lib/libwindows.0.53.0.a"，unsupported 时抛 UnsupportedTarget

// 拼上调用方给定的包根目录
let root = "E:/toolchain/windows_targets"
target.requireArchivePath(root)
// => "E:/toolchain/windows_targets/x86_64_gnu/lib/libwindows.0.53.0.a"

// 生成 GNU 链接器需要的两个选项
target.requireGnuLinkOptions(root)
// => ["-LE:/toolchain/windows_targets/x86_64_gnu/lib", "-l:libwindows.0.53.0.a"]
```

`requireGnuLinkOptions(root)` 返回的两项正是把一份归档喂给 GNU 链接器的标准组合：`-L<目录>` 指定搜索路径，`-l:<文件名>` 按精确文件名引入归档。注意它只对 `toolchain == "gnu"` 的 target 有效，对非 GNU target（即便受支持）会抛 `UnsupportedTarget`。

### 不支持的 target 会抛 `UnsupportedTarget`

`UnsupportedTarget` 是一个 `<: Exception` 的公开异常类，带 `targetName` 和 `reason` 两个字段，消息形如：

```text
unsupported windows_targets import library target `aarch64_gnu`: no bundled import library payload exists under aarch64_gnu/lib
```

所有 `require...` 系列都在拿到链接选项 / 做任何 ABI 假设**之前**就抛出它，让你尽早 fail-fast。如果你只是想检视矩阵、不想触发异常，就用 `findImportLibTarget` / `findSupportedImportLibTarget` / `archiveRelativePath()` 这些返回 `Option` 的探测式 API。

顶层还有一组同名的自由函数包装（`requireImportLibGnuLinkOptions(target, root)`、`importLibArchivePath(target, root)` 等），行为和对应的方法一致，方便不想持有 `ImportLibTarget` 实例时直接调用。

## 小结

- 调用 Windows API 需要链接期的**导入库**把符号解析到系统 DLL；windows-cj 用 GNU 工具链 + 单一归档 `libwindows.0.53.0.a`。
- `windows_targets` 是链接期资产包，目前只支持 `x86_64_gnu`；其余 target 在矩阵里列出但无载荷（unsupported）。
- COM / WinRT 在最终可执行项目的 `cjpm.toml` 里用 `link-option = "-lole32 -loleaut32 -lwindowsapp"` 补充系统库。
- 用 `requireSupportedImportLibTarget` / `requireCurrentImportLibTarget` 解析 target，用 `requireGnuLinkOptions(root)` 拿链接选项；不支持的 target 会抛 `UnsupportedTarget`。

## 下一步 / 相关

- [用 windows_bindgen 生成绑定](bindgen.md) —— 绑定生成器如何按需把元数据生成成仓颉源码包。
- [WinUI 3 实战](winui3.md) —— WinUI 3 / Windows App SDK 项目的链接与运行环境。
- [安装与环境配置](installation.md) —— 工具链版本、`cjHeapSize`、`cjv exec` 运行约定。
