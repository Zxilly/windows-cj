# 处理字符串

Windows 内部几乎全用 UTF-16 宽字符（`UInt16`），而仓颉的 `String` 是 UTF-8。和 Windows 打交道时，几乎每一次跨边界都要做一次「UTF-8 ↔ UTF-16」的转换。`windows-strings` 把这件事封装成几个职责清晰的类型，你只要根据 API 期待的形态挑一个用就行。

越往下越底层、越接近裸 ABI；越往上越现代、越贴近仓颉习惯：

```text
PCWSTR / PWSTR   ── 裸宽字符指针（只读 / 可写），不拥有内存
CWideString      ── 仓颉持有的、以 NUL 结尾的 UTF-16 缓冲，喂给 Win32 入参
BSTR             ── 长度前缀的 OLE 字符串，COM / 自动化常用
HString          ── WinRT 的 HSTRING，运行时投影最常用
```

它们都来自 `windows_strings` 包。下面逐一拆解。

## String 与 UTF-16 的关系

仓颉 `String` 按 UTF-8 存储字节；Windows 想要的是 UTF-16 码元序列。`windows-strings` 在内部用一套编解码 helper 完成两边互转，并且对非法序列做了防御（遇到坏字节会替换成 `U+FFFD`，不会崩）。

大多数时候你不需要手动调编解码函数——构造一个 `HString` / `BSTR` / `CWideString` 时转换会自动发生；取回内容时再转回 `String`。关键是理解：**这些包装类型内部存的是 UTF-16，对外的「人话」接口才是仓颉 `String`。**

## HString：WinRT 的字符串

`HString` 对应 WinRT 的 `HSTRING`，是你在运行时投影里最常碰到的字符串类型。它是一个 `class`（引用类型），由 GC 管理对象本身的引用关系，但**底层 UTF-16 缓冲是它自己持有的堆内存**，需要回收——所以它实现了 `Resource`。

### 构造

```cangjie
import windows_strings.*

// 从仓颉 String 直接构造（最常用）
let hs = HString("Hello, WinRT")

// 空字符串（HSTRING 的空值就是 null 句柄）
let empty = HString()

// 从一段 UTF-16 码元数组构造
let fromUnits = HString.fromWide([0x0048u16, 0x0069u16])  // "Hi"
```

### 取回内容、长度、是否为空

```cangjie
let hs = HString("café")

let text: String = hs.get()          // 有损解码，等价于 toString()
let same: String = hs.toString()     // ToString 实现，同 get()

// 无损解码：内容是合法 UTF-16 时返回 Some，否则 None
match (hs.tryToString()) {
    case Some(s) => println("解出来了：${s}")
    case None    => println("含非法代理对，无法无损解码")
}

let n: Int64 = hs.length()    // UTF-16 码元个数
let blank: Bool = hs.isEmpty()
```

`get()` / `toString()` 走的是 lossy 解码（坏数据替换成 `U+FFFD`），适合「我只想拿到能显示的文本」；`tryToString()` 返回 `Option<String>`，适合「我要确认内容确实是合法 UTF-16」。

### 生命周期：close 或 try-with-resource

`HString` 实现了 `Resource`（`isClosed()` / `close()`），离开作用域时底层缓冲必须被释放。推荐用 try-with-resource，自动调用 `close()`：

```cangjie
try (hs = HString("scoped string")) {
    println(hs.get())
}   // 离开块时自动 close()，释放 UTF-16 缓冲
```

如果不用 try-with-resource，可以手动 `close()`：

```cangjie
let hs = HString("manual")
println(hs.get())
hs.close()                  // 显式回收
println(hs.isClosed())      // true
```

即便你忘了 `close()`，`HString` 也有 `~init()` 析构器兜底；但仍建议显式管理，让回收时机可控。注意 `HString` 内部用了回收标记（`closed`），`close()` 和析构器之间不会重复释放。

### 在指针边界上桥接

很多底层 API 需要一个宽字符指针。`HString` 提供了零拷贝借用：

```cangjie
let hs = HString("path")

// 借出 PCWSTR（只读宽指针），仅在闭包内有效
hs.withPCWSTR { p =>
    // p: PCWSTR，可以传给期待 PCWSTR 的 API
}

// 借出裸 CPointer<UInt16>
hs.withPtr { ptr =>
    // ptr: CPointer<UInt16>
}
```

> 借出的指针 / 切片只在 `HString` 存活且未 `close` 期间有效，不要把它们存到闭包外面。

## BSTR：OLE / 自动化字符串

`BSTR` 是长度前缀的 UTF-16 字符串，由 OLE 自动化（`oleaut32.dll` 的 `SysAllocStringLen` / `SysFreeString`）分配和释放，在 COM、脚本自动化、`VARIANT` 场景里随处可见。它同样是 `class` 且实现 `Resource`——**当它拥有存储时**需要回收。

```cangjie
// 自己分配一个 BSTR（拥有存储）
try (b = BSTR("automation")) {
    let s: String = b.get()
    let n: Int64 = b.length()        // 字符数
    let bytes: UInt32 = b.byteLength()
    let owns: Bool = b.ownsStorage() // true，这块内存归它管
}   // close() 调用 SysFreeString
```

当一个 API 把 BSTR 指针交还给你时，要分清「所有权是否转移」：

```cangjie
// 所有权转移给你：用完由这个包装负责 SysFreeString
let owned = BSTR.fromRawTake(rawPtr)

// 只是借用：你不拥有它，close() 不会去 free
let borrowed = BSTR.fromRawView(rawPtr)
```

`fromRawView` 得到的 `BSTR` 的 `ownsStorage()` 是 `false`，`close()` 不会释放别人的内存——这正是处理「函数返回的指针」时需要的安全语义。还有 `intoRaw()` 可以把裸指针的所有权交还给调用方（之后这个 `BSTR` 实例失效，由调用方负责 `SysFreeString`）。

## PCWSTR / PWSTR：裸宽字符指针

这两个是 `struct`（值类型），只是 `CPointer<UInt16>` 的轻量包装，**不拥有任何内存**，对应 Win32 签名里的 `LPCWSTR`（只读）和 `LPWSTR`（可写）。

| 类型 | 含义 | 典型用途 |
| --- | --- | --- |
| `PCWSTR` | 指向 UTF-16 的**只读**指针 | 把字符串**传入** Win32 函数 |
| `PWSTR` | 指向 UTF-16 的**可写**指针 | 接收 Win32 函数**写出**的缓冲 |

```cangjie
// 从裸指针包一层
let pc = PCWSTR.fromRaw(somePtr)
let pw = PWSTR.fromRaw(outBuffer)

let isNull: Bool = pc.isNull()
let raw: CPointer<UInt16> = pc.asPtr()

// PWSTR 可以降级成只读的 PCWSTR
let ro: PCWSTR = pw.toPCWSTR()
```

因为它们只是借用别人的内存、长度要靠扫描 NUL 终止符，所以解码 / 取长度类操作标了 `unsafe`，调用者要自己保证指针有效且以 NUL 结尾：

```cangjie
unsafe {
    let len: Int64 = pc.length()         // 扫描到 NUL 为止
    let arr: Array<UInt16> = pc.toArray()
    let lossy: String = pc.toStringLossy()
    let maybe: Option<String> = pc.toString() // toString 返回 Option<String>（解码失败为 None）
    let hs: HString = pc.toHString()           // 需要 HString 时用 toHString()
}
```

> 这些指针类型不管理生命周期：底层内存属于产生它的那一方（一个还活着的 `HString`、一个 Win32 调用栈上的缓冲等）。`PCWSTR` / `PWSTR` 失效与否完全取决于那块内存。

## CWideString：喂给 Win32 入参的宽缓冲

当你要把一个仓颉字符串作为 `LPCWSTR` **传给** Win32 函数时，`CWideString` 是最顺手的选择：它把 `String` 编码成**以 NUL 结尾**的 UTF-16 缓冲并由仓颉持有，再借出指针给你调用：

```cangjie
let title = CWideString("提示")

title.withPtr { ptr =>
    // ptr: CPointer<UInt16>，以 NUL 结尾，可直接传给 MessageBoxW 之类
}

let n: Int64 = title.length()   // 逻辑长度（不含结尾 NUL）

// 反向：从一个以 NUL 结尾的宽指针读回 String
let back: String = CWideString.fromPointer(ptr)
```

`CWideString` 也实现了 `Resource`，但它持有的是仓颉托管数组，`close()` 只是打个标记，主要的内存由 GC 回收。它和上面三者的分工是：**输入参数走 `CWideString`，输出 / 借用走 `PWSTR` / `PCWSTR`，COM 走 `BSTR`，WinRT 走 `HString`。**

## 字面量风格的构造（无编译期宏）

仓颉没有编译期字面量宏，所以 `windows-strings` 用工厂 / 惰性单例来表达「写死的常量字符串」这件事。`literals.cj` 提供了一组工厂和便捷函数：

```cangjie
// 工厂：先建一次，可重复借出指针
let wf: WideStringFactory = wideStringFactory("C:\\Windows")
wf.withPtr { p =>            // p: PCWSTR
    // ...
}
let cw: CWideString = wf.value()

// HString 工厂会缓存已创建的 HString（惰性单例）
let hf: HStringFactory = hStringFactory("Windows.Foundation")
let hs: HString = hf.value()   // 第二次调用复用同一个未关闭的实例

// 便捷直达函数
let lit: HString = hStringLiteral("ready")
let wide: CWideString = wideStringLiteral("path")
```

`HStringFactory.value()` 内部缓存了上一次创建的 `HString`，只要它没被 `close`，重复取用就是同一个对象——这就是用惰性单例等价表达「编译期常量字符串」的方式。

## 内存与生命周期速记

| 类型 | 是否拥有底层存储 | 何时需要 close |
| --- | --- | --- |
| `HString` | 是（堆上的 UTF-16 缓冲） | 是，用 try-with-resource 或 `close()` |
| `BSTR`（`fromRawTake` / 自分配） | 是（`SysAllocStringLen`） | 是 |
| `BSTR`（`fromRawView`） | 否（借用） | 否，`close()` 不会 free |
| `CWideString` | 持有托管数组 | `close()` 仅打标记，内存由 GC 回收 |
| `PCWSTR` / `PWSTR` | 否（纯借用指针） | 无需，生命周期跟随被指向的内存 |

记住一条主线：**拥有原生堆内存的类型（`HString`、自分配的 `BSTR`）才需要确定性回收；其余要么是借用指针，要么由 GC 兜底。** 对象之间的引用全部由 GC 管理，你不需要手动 AddRef/Release。

## 下一步 / 相关

字符串处理之后，下一道绕不开的关是错误码——几乎每个 Windows API 都用 `HRESULT` 或 `BOOL` 报告成败。继续阅读：[错误处理与 HRESULT](error-handling.md)。
