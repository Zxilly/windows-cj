# 调用第一个 Win32 API

Win32 是 Windows 最底层、也是历史最悠久的一层 API：它就是一组从系统 DLL（`kernel32.dll`、`advapi32.dll`、`user32.dll` 等）里导出的 **C 风格函数**。它们有几个共同特征：

- **导出函数**：每个函数都是某个 DLL 的导出符号，名字常带 `A`/`W` 后缀（ANSI / 宽字符），例如 `RegGetValueA` / `RegGetValueW`。
- **句柄（handle）**：系统资源（注册表项、进程、窗口……）用一个不透明的整数 / 指针句柄表示，例如 `HKEY`、`HANDLE`。
- **指针参数**：很多参数是缓冲区指针、或者"出参指针"（函数往你给的地址里写结果）。
- **整数返回码**：成功 / 失败用 `BOOL`（0 假、非 0 真）或 `HRESULT` / Win32 错误码（`0` 表示成功）表达，而不是抛异常。

在仓颉里调用这类函数有两条路径，从上往下越来越接近裸 ABI：

1. **优先**：直接用 windows-cj 已经封装好的子系统包。它把句柄生命周期、宽字符串编码、错误码翻译都替你做好了，你写的是地道的仓颉代码。
2. **进阶**：当某个函数还没有现成封装时，用仓颉 `foreign func` + `@C` 自己声明，并在 `unsafe` 块里调用。

下面分别走一遍。

## 路径一：用现成的高层封装（推荐）

最省事的方式是找到对应子系统包，直接调用它的公开函数。以查询操作系统版本为例 —— `windows_version` 包已经把 `RtlGetVersion` 封装成了一个干净的值类型 `OsVersion`。

### 写依赖：`cjpm.toml`

注意 windows-cj 的命名约定：**目录名和仓颉包名都用下划线**。引依赖时键名是包名，路径也指向同名目录。

```toml
[package]
  name = "my_app"
  version = "0.1.0"
  output-type = "executable"
  cjc-version = "1.1.0"

[dependencies]
  windows_version = { path = "../windows-cj/windows_version" }
```

### 写代码

```cangjie
import windows_version.*

main(): Int64 {
    // 读取当前系统版本（内部调用 Win32 的 RtlGetVersion）
    let version = OsVersion.current()
    println("Windows 版本：${version}")  // 例如 10.0.0.26200

    // 判断是不是服务器版（内部读取 OSVERSIONINFOEXW.wProductType）
    if (is_server()) {
        println("这是服务器版 Windows")
    } else {
        println("这是工作站版 Windows")
    }

    // 读取修订号 UBR（内部走注册表 RegGetValueA）
    println("修订号：${revision()}")
    0
}
```

`OsVersion.current()` / `is_server()` / `revision()` 都是 `windows_version` 的公开 API（见 `windows_version/src/lib.cj`）。你完全看不到指针、句柄、宽字符——封装层已经把这些都吞掉了。`OsVersion` 是一个实现了 `ToString` 的值类型（`struct`），字符串插值时会得到 `major.minor.pack.build` 的形式。

### 高层 API 怎么报告错误

更复杂的子系统会把"成功 / 失败"建模成返回值，而不是让你检查整数码。以 `windows_registry` 为例，它的读写函数返回 `Result<T>`：

```toml
[dependencies]
  windows_registry = { path = "../windows-cj/windows_registry" }
```

```cangjie
import windows_registry.*
import windows_result.*

main(): Int64 {
    // LOCAL_MACHINE 是预定义的根键（对应 HKEY_LOCAL_MACHINE）
    let opened = LOCAL_MACHINE.open("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion")
    match (opened) {
        case Ok(key) =>
            // Key 实现了 Resource，用 try-with-resource 自动关闭句柄
            try (k = key) {
                match (k.getString("ProductName")) {
                    case Ok(name) => println("产品名：${name}")
                    case Err(e) => println("读取失败：${e}")
                }
            }
        case Err(e) =>
            println("打开注册表项失败：${e}")
    }
    0
}
```

这里几件事都是封装层替你做的：

- `LOCAL_MACHINE` 是 `Key.borrowed(...)` 预建好的根键常量，不需要你自己拼 `HKEY` 句柄。
- `open` / `getString` 返回 `Result<Key>` / `Result<String>`，用 `match` 解构，不需要检查 Win32 状态码。
- `Key` 实现了 `Resource`，`try (k = key) { ... }` 会在作用域结束时自动调用 `RegCloseKey`，不会泄漏句柄。
- 宽字符串（UTF-16）编码、缓冲区分配全部在内部完成，你只传普通仓颉 `String`。

> **范式提醒**：仓颉用 `Option<T>` 代替 `null`，用 `Result<T>` 表达可失败的操作；句柄类型由 GC 持有的 `class`（如 `Key`）管理生命周期，配合 `Resource` 的 `close()` 释放原生资源——你不需要手动 `AddRef`/`Release`。

## 路径二：自己声明 `foreign func`（进阶）

如果某个 Win32 函数还没有现成封装，你可以照 C 头文件的签名，用仓颉 FFI 自己声明。底层的 `windows_libloading` 包本身就是这么写的，可以当模板参考（见 `windows_libloading/src/lib.cj`）。

### 关键语法点（以仓颉官方 FFI 文档为准）

- `foreign func` 声明外部函数，**只能有声明、不能有函数体**。
- Win32 导出函数用 **STDCALL** 调用约定，用 `@CallingConv[STDCALL]` 标注；它可以修饰单个函数，也可以修饰一整个 `foreign` 块（块内每个函数都套上同样的约定）。不标注时默认是 `CDECL`。
- 调用 `foreign` 函数**必须**包在 `unsafe { ... }` 块里——仓颉的 unsafe 是**块级别**的，不是函数级别。
- 指针参数用 `CPointer<T>`；空指针 / NULL 用 `CPointer<T>()`（再用 `.isNull()` 判空）。句柄（`HMODULE`、`HANDLE`）在 ABI 上就是指针，对应 `CPointer<Unit>`。
- C 字符串参数对应 `CPointer<UInt8>`（窄字符）或 `CPointer<UInt16>`（宽字符）。

### 声明骨架

下面照搬 `windows_libloading` 里对三个 `kernel32` 导出函数的真实声明：

```cangjie
@CallingConv[STDCALL]
foreign {
    func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CPointer<UInt8>): CPointer<Unit>
    func FreeLibrary(hLibModule: CPointer<Unit>): Int32
    func LoadLibraryExA(lpLibFileName: CPointer<UInt8>, hFile: CPointer<Unit>, dwFlags: UInt32): CPointer<Unit>
}
```

- `HMODULE` / `HANDLE` → `CPointer<Unit>`
- `LPCSTR`（窄字符串）→ `CPointer<UInt8>`
- `DWORD` → `UInt32`，`BOOL`（C 的 int 返回）→ `Int32`

### 调用骨架

调用时，把仓颉数据转成 C 兼容形式，包进 `unsafe`，再判返回值。下面是 `windows_libloading` 里 `LoadLibraryExA` 的真实调用片段（保留要点）：

```cangjie
func loadLibraryWithFlags(moduleNameBytes: Array<UInt8>, flags: UInt32): CPointer<Unit> {
    unsafe {
        // 把仓颉数组的底层缓冲区借出原生指针
        let moduleNameHandle = acquireArrayRawData(moduleNameBytes)
        try {
            let module = LoadLibraryExA(moduleNameHandle.pointer, CPointer<Unit>(), flags)
            if (module.isNull()) {            // NULL 返回即失败
                throw Exception("failed to load module")
            }
            module
        } finally {
            releaseArrayRawData(moduleNameHandle)  // 用完务必释放
        }
    }
}
```

要点：

- `CPointer<Unit>()` 构造了一个空指针，对应 C 侧的 `NULL`（这里作为 `hFile` 传入）。
- 返回的句柄用 `.isNull()` 判断是否失败——这正是 Win32"返回 NULL / 0 表示出错"的惯例。
- 把仓颉 `Array` 的内存交给 C 时，要用 `acquireArrayRawData` / `releaseArrayRawData` 成对借出 / 归还，并放在 `try { ... } finally { ... }` 里保证释放。

> 还有一条更动态的路径：`windows_libloading` 提供了 `resolveProc(moduleName, procName)`，运行时用 `LoadLibrary` + `GetProcAddress` 解析出函数地址，再用 `CFunc<...>` 把地址转成可调用的函数指针。`windows_result` 内部就用这种方式调用 `kernel32` / `oleaut32` 的函数（见 `windows_result/src/bindings.cj`）。当你不想在链接期绑定符号、或要按需加载时，这很有用。

### 返回值：BOOL 与 HRESULT

自己声明 FFI 时要记住 Win32 的错误约定，并尽量翻译成仓颉的表达方式：

- 返回 `BOOL` 的函数：`0` 是失败。`windows_result` 提供了 `BOOL` 值类型，`.as_bool()` 转成仓颉 `Bool`，`.ok()` 转成 `Result<Unit>`（失败时自动带上 `GetLastError` 的错误信息），`.unwrap()` 在失败时 panic。
- 返回 `HRESULT` 的函数（COM 风格）：用 `windows_result` 的 `HRESULT` 类型表达，负值 / 高位置 1 表示失败。
- 返回 Win32 状态码（如注册表函数返回 `LSTATUS`）：`0` 成功，非 0 是错误码，可用 `errorFromWin32(code)` 翻成 `Error`。

错误码到异常 / `Result` 的完整映射，参见 [错误处理与 HRESULT](error-handling.md)。

## 小结

- 能用现成封装就用现成封装：你写的是带 `Result` / `Option` / `Resource` 的地道仓颉代码，看不到指针和句柄。
- 没有封装时，按 C 签名写 `foreign func`（`@CallingConv[STDCALL]`），在 `unsafe` 块里调用，指针用 `CPointer<T>`、句柄用 `CPointer<Unit>`、字符串用 `CPointer<UInt8>` / `CPointer<UInt16>`。
- 始终用 `BOOL` / `HRESULT` / Win32 状态码判断成败，并翻译成仓颉的错误表达。

## 下一步 / 相关

- [处理字符串](strings.md) —— Win32 的 `W` 函数要求 UTF-16 宽字符串，这一节讲 `HString` / `PCWSTR` / `PWSTR` / `CWideString` 怎么用。
- [错误处理与 HRESULT](error-handling.md) —— `BOOL` / `HRESULT` / `Error` / `Win32Exception` 的完整体系。
- [调用 COM API 与查询接口](com-api.md) —— 从 C 风格函数进阶到 vtable 调用与 `QueryInterface`。
