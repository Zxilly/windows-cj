# 安装与环境配置

windows-cj 直接绑定 Win32 / COM / WinRT 的原生 ABI，因此**只能在 Windows 上构建和运行**。本节带你把工具链装好，并解释几个容易踩坑的环境约定。

## 1. 安装仓颉工具链

windows-cj 锁定 **cjc 1.1.0**（STS 通道）。从 [仓颉官网下载中心](https://cangjie-lang.cn/download/1.1.0) 获取 Windows x64 安装包：

- `cangjie-sdk-windows-x64-1.1.0.exe`（图形化安装），或
- `cangjie-sdk-windows-x64-1.1.0.zip`（解压即用）

安装完成后，确认 `cjc`（编译器）和 `cjpm`（包管理器）已在 `PATH` 中：

```powershell
cjc -v
cjpm -h
```

> **版本一致性**：仓库内每个包的 `cjpm.toml` 都声明了 `cjc-version = "1.1.0"`。使用其它版本的 cjc 可能因标准库 API 差异而无法编译。

## 2. 获取源码

```powershell
git clone https://github.com/Zxilly/windows-cj.git
cd windows-cj
```

仓库根目录是一个 cjpm **工作区**（`[workspace]`），把各个包作为成员统一管理：

```toml
[workspace]
members = [
    "windows-core",
    "windows-strings",
    "windows-result",
    "windows-foundation",
    # …其余包
]
```

## 3. 构建

在工作区根目录直接构建全部成员：

```powershell
cjpm build
```

或在某个包目录下单独构建该包及其依赖。

### 关于编译内存上限

多包工作区一次性编译时，仓颉运行时默认的 GC 堆上限可能不够，触发 OOM。构建前把上限调高即可（这是**上限**而非预留，不会预占物理内存）：

```powershell
$env:cjHeapSize = '32GB'
cjpm build
```

单包构建通常用不到这么高，但在工作区级别的全量构建中建议设置。

## 4. 在项目中使用 windows-cj

在你自己项目的 `cjpm.toml` 里，用路径依赖引入需要的包。注意**目录名用连字符、包名用下划线**：

```toml
[package]
  name = "my_app"
  version = "0.1.0"
  output-type = "executable"
  cjc-version = "1.1.0"
  # COM / WinRT 通常需要链接这几个系统库
  link-option = "-lole32 -loleaut32 -lwindowsapp"

[dependencies]
  windows_core = { path = "../windows-cj/windows-core" }
  windows_strings = { path = "../windows-cj/windows-strings" }
```

在仓颉源码中按包名（下划线）导入：

```cangjie
import windows_core.*
import windows_strings.HString
```

## 5. 运行产物

构建产物在 `target/` 下。运行可执行文件时，需要让运行时找到正确的工具链与系统运行时环境。本仓库统一通过仓颉版本管理器的 `cjv exec` 包裹运行，而不是直接双击 `.exe`：

```powershell
cjv exec .\target\release\bin\my_app.exe
```

这样能保证运行时链接到与编译期一致的仓颉运行时，COM / WinRT 调用才不会因环境不匹配而失败。

## 下一步

环境就绪后，先浏览 [包结构总览](packages.md)，了解每个包负责什么；然后从 [调用第一个 Win32 API](first-win32-api.md) 写下第一行真正调用 Windows 的代码。
