# 错误处理与 HRESULT

Windows API 报告成败的方式五花八门：COM 和 WinRT 用 `HRESULT`，传统 Win32 函数常返回 `BOOL` 再让你去查 `GetLastError`，内核 / 驱动用 `NTSTATUS`，注册表等子系统用 `WIN32_ERROR`。`windows-result` 把这些统一成几个可组合的类型，并提供 `Result<T>` 让你在「抛异常」和「显式传播」之间自由选择。

它们都来自 `windows_result` 包。

## HRESULT：成功还是失败

`HRESULT` 是一个 32 位结果码（`struct`，值类型），内部是一个 `Int32`。判定规则很简单：**非负为成功，负数为失败**（最高位是 SEVERITY 位）。

```cangjie
import windows_result.*

let hr = HRESULT(0i32)   // S_OK

hr.isOk()        // true —— value >= 0
hr.isErr()       // false —— value < 0
hr.succeeded()   // isOk() 的别名，贴近 Win32 SUCCEEDED 习惯
hr.failed()      // isErr() 的别名，贴近 FAILED
```

包里预定义了常用的 `HRESULT` 常量：

```cangjie
S_OK            // HRESULT(0)
S_FALSE         // HRESULT(1)，注意它也是「成功」
E_FAIL
E_INVALIDARG
E_NOINTERFACE
E_NOTIMPL
E_POINTER
E_OUTOFMEMORY
E_ACCESSDENIED
// …
```

`HRESULT` 还能取人类可读的消息、格式化成十六进制：

```cangjie
let hr = E_INVALIDARG
println(hr.toString())   // "0x80070057"（8 位大写十六进制）
println(hr.message())    // 调 FormatMessageW 拿系统消息文本
```

### 从 HRESULT 得到 Result 或抛异常

`HRESULT` 提供了三种「往下走」的方式：

```cangjie
let hr: HRESULT = someComCall()

// 1) 转成 Result<Unit>：成功 Ok(())，失败 Err(Error)
let r: Result<Unit> = hr.ok()

// 2) 失败就抛 WindowsException，成功正常返回
hr.check()

// 3) 串联后续操作：成功才执行 op，并把返回值包成 Ok
let mapped: Result<Int64> = hr.map { => computeSomething() }
let chained: Result<Int64> = hr.andThen { => anotherFallibleStep() }
```

还有 `unwrap()` / `expect(message)`，失败时直接 `panic`（适合「这里绝不该失败」的断言场景）。

## Result\<T>：可失败操作的显式表达

`Result<T>` 是一个 `enum`，要么 `Ok(T)`，要么 `Err(Error)`。当一个操作可能失败、而你想让调用方决定怎么处理（而不是直接抛异常）时，就返回 `Result<T>`。

```cangjie
public enum Result<T> {
    | Ok(T)
    | Err(Error)
}
```

取值、判定、传播：

```cangjie
let r: Result<Int64> = doWork()

// 判定
r.isOk()
r.isErr()

// 取值（失败会 panic）
let v: Int64 = r.unwrap()
let v2: Int64 = r.expect("doWork 不该失败")

// 带默认值地取
let v3: Int64 = r.unwrapOr(0)
let v4: Int64 = r.unwrapOrElse { e => fallback(e) }

// 用 match 解构，两条路径都显式处理
match (r) {
    case Ok(value) => println("成功：${value}")
    case Err(error) => println("失败：${error}")
}
```

链式组合（成功才继续，失败直接短路传播）：

```cangjie
let pipeline: Result<String> =
    doWork()
        .map { n => n * 2 }                 // 变换 Ok 值
        .andThen { n => formatResult(n) }   // 继续一个可失败步骤
        .mapErr { e => e }                  // 变换 Err

// 想退回 Option，丢弃错误细节
let opt: Option<Int64> = doWork().ok()
let errOpt: Option<Error> = doWork().err()
```

`Err` 携带的是 `Error` 类型，它封装了一个 `HRESULT` 以及（在 Windows 上）可选的 `IErrorInfo` 富信息：

```cangjie
match (doWork()) {
    case Ok(_) => ()
    case Err(error) =>
        let code: HRESULT = error.code()   // 拿到底层 HRESULT
        println(error.message())           // 错误文本
        println(error.toString())          // "文本 (0x........)"
}
```

需要自己造一个错误时：`Error.fromHRESULT(hr)`、`Error.fromWin32(code)`、`Error.fromThread()`（读取当前线程的 last error），或带消息的 `Error(code, "出错原因")`。

## BOOL：和仓颉 Bool 互转

很多 Win32 函数返回 `BOOL`（其实是 `Int32`，非零为真）。`windows-result` 的 `BOOL` 是值类型，提供了和仓颉 `Bool` 的双向转换：

```cangjie
// Bool -> BOOL
let b1: BOOL = BOOL.from(true)
let b2: BOOL = BOOL.fromBool(false)
let b3: BOOL = BOOL(true)          // 构造器也接受 Bool

// 预定义常量
let yes = TRUE   // BOOL(1)
let no  = FALSE  // BOOL(0)

// BOOL -> Bool
let ok: Bool = b1.as_bool()        // value != 0

// 取反
let flipped: BOOL = !b1
```

更有用的是把 `BOOL` 直接转成错误处理流程——失败时它会去读 `GetLastError`：

```cangjie
let result: BOOL = someWin32Call()

// 1) 转 Result<Unit>：true -> Ok(())，false -> Err(errorFromThread())
let r: Result<Unit> = result.ok()

// 2) false 就 panic
result.unwrap()

// 3) false 就 panic，带自定义前缀
result.expect("someWin32Call 失败")
```

`BOOL.ok()` 在 false 时调用的 `errorFromThread()` 会捕获当前线程的 last error，这正好匹配 Win32「返回 FALSE，错误码在 GetLastError 里」的约定。

## 底座类型：WIN32_ERROR、NTSTATUS、GUID

**`WIN32_ERROR`** —— 无符号 Win32 错误码（注册表、服务等子系统常用）。`0` 表示 `ERROR_SUCCESS`，可以转成 `HRESULT` 或 `Error`：

```cangjie
let err = WIN32_ERROR(5u32)          // ERROR_ACCESS_DENIED
err.isOk()                           // false（非 0）
let hr: HRESULT = err.toHRESULT()    // 编码成 FACILITY_WIN32（0x8007xxxx）
let r: Result<Unit> = err.ok()
let last = WIN32_ERROR.fromThread()  // 读 GetLastError
```

**`NTSTATUS`** —— NT 内核 / 驱动状态码，同样「非负为成功」，可 `toHRESULT()`（失败码会被打上 `FACILITY_NT_BIT`）、`ok()`、`unwrap()`。

**`GUID`** —— 16 字节的接口 / 类标识符，是 `@C struct`（保证和 Windows ABI 布局一致），支持 `==` / `!=` 比较。你在 COM `QueryInterface`、WinRT 激活时会反复用到它；这里只需知道它是底座类型，由更上层的包按需构造。

这几者最终都能汇流到 `HRESULT` / `Error`，所以你的错误处理可以统一在一条管线上。

## 串起来：调用一个返回 HRESULT 的操作

下面是一个把上述类型组合起来的典型形态——一个会返回 `HRESULT` 的操作，成功 / 失败两条路径都显式处理：

```cangjie
import windows_result.*

// 假设它封装了某个 COM / WinRT 调用，返回 HRESULT
func openWidget(name: String): HRESULT {
    // … 实际调用底层 API，把返回的 i32 包成 HRESULT(...) …
    HRESULT(0i32)
}

func useWidget(name: String): Result<Unit> {
    let hr = openWidget(name)

    // 把 HRESULT 转成 Result，让调用方决定如何处理
    match (hr.ok()) {
        case Ok(_) =>
            println("打开成功：${name}")
            Result<Unit>.Ok(())
        case Err(error) =>
            println("打开失败：${error}")          // 含文本和 0x.... 码
            println("HRESULT = ${error.code()}")   // 底层 HRESULT
            Result<Unit>.Err(error)
    }
}

main() {
    match (useWidget("display")) {
        case Ok(_)      => println("一切就绪")
        case Err(error) => println("放弃，原因：${error.message()}")
    }
}
```

如果你更想用「失败即抛异常」的风格，可以把中间那段换成一行 `hr.check()`——它在失败时抛 `WindowsException`（其 `.code()` 给出 `HRESULT`），成功则继续往下。两种风格按场景选用即可：库的内部边界倾向 `Result<T>` 显式传播，应用顶层用 `check()` / 异常更省事。

## 下一步 / 相关

掌握了字符串和错误码这两块底座，你就可以正式开始消费真正的接口了。继续阅读：[调用 COM API 与查询接口](com-api.md)。
