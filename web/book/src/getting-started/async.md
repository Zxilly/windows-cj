# WinRT 异步操作

WinRT 里凡是可能耗时的调用（读文件、访问网络、唤起设备）都返回一个**异步对象**，而不是直接阻塞。调用方拿到这个对象后，可以注册完成回调、查询状态、或阻塞等待结果。windows-cj 把这套模型投影在 `windows_future` 包里。

越往上越贴近仓颉习惯：底层是 `IAsyncInfo` 状态机和 completed handler，往上 windows-cj 给了 `join()` / `when()` 这种直接拿结果的 helper，让异步代码读起来像同步。

## WinRT 异步模型

有四个异步接口，区别只在“有没有返回值”和“有没有进度”：

| 接口 | 有返回值 | 有进度 |
|---|---|---|
| `IAsyncAction` | 否 | 否 |
| `IAsyncActionWithProgress<TProgress>` | 否 | 是 |
| `IAsyncOperation<TResult>` | 是（`TResult`） | 否 |
| `IAsyncOperationWithProgress<TResult, TProgress>` | 是（`TResult`） | 是 |

它们都继承 **`IAsyncInfo`**，这是异步状态机的公共底座：

- `Id(): UInt32` —— 操作的唯一 id。
- `Status(): AsyncStatus` —— 当前状态。
- `ErrorCode(): HResult` —— 失败时的 HRESULT。
- `Cancel()` —— 请求取消。
- `Close()` —— 释放。

`AsyncStatus` 是一个薄封装的 `Int32`，有四个具名取值（来源：`windows_future/src/async_runtime.cj`）：

```text
AsyncStatus_Started    (0)  —— 进行中
AsyncStatus_Completed  (1)  —— 成功完成
AsyncStatus_Canceled   (2)  —— 已取消
AsyncStatus_Error      (3)  —— 出错
```

一个异步操作的生命就是从 `Started` 走向三个**终态**之一（`Completed` / `Canceled` / `Error`）。它们用 `==` 比较：

```cangjie
import windows_future.*

// info: IAsyncInfo
if (unsafe { info.Status() } == AsyncStatus_Completed) {
    // 成功
}
```

`TResult` / `TProgress` 都受 `where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T>` 约束——必须是可运行时投影的 WinRT 类型。

## 等待结果：`join()` 与 `when()`

最常见的需求是“等它完成、拿结果”。windows-cj 为每个异步接口扩展了两个 helper（来源：`windows_future/src/async_helpers.cj` 的 `extend` 块）：

- **`join(): Result<T>`** —— **阻塞**当前线程直到终态，然后把结果包成 `Result`：成功 `Ok(值)`、出错 `Err(对应 HRESULT)`、取消 `Err(E_ABORT)`。对 `IAsyncOperation<TResult>` 是 `Result<TResult>`，对 `IAsyncAction` 是 `Result<Unit>`。
- **`when(): Future<Result<...>>`** —— **不阻塞**，把 `join()` 丢到一个仓颉线程里跑，返回仓颉的 `Future`，你之后再 `.get()`。

`join()` 内部并不忙等：它通过 `IAsyncInfo.Id()` 找到该操作的终态事件并在 Win32 事件上等待（自家实现的异步对象），对外来对象则回退到轮询。终态后它会读 `Status()` 决定走 `GetResults()` 还是 `ErrorCode()`，并在内部正确释放临时的 `IAsyncInfo`。

```cangjie
import windows_core.*
import windows_future.*

// operation: IAsyncOperation<Int32>，从某个 WinRT API 拿到
func awaitValue(operation: IAsyncOperation<Int32>): Unit {
    // 阻塞等待，直接拿 Result<Int32>
    match (operation.join()) {
        case Result<Int32>.Ok(value) => println("结果: ${value}")
        case Result<Int32>.Err(error) => println("失败: HRESULT=${error.code()}")
    }
}
```

不想阻塞当前线程时用 `when()`：

```cangjie
import std.time.*
import windows_core.*
import windows_future.*

// operation: IAsyncOperation<Int32>
func awaitWithTimeout(operation: IAsyncOperation<Int32>): Unit {
    let future = operation.when()                 // 立即返回 Future<Result<Int32>>
    // ...这中间可以干别的...
    match (future.get(Duration.second * 2)) {     // 最多等 2 秒
        case Result<Int32>.Ok(value) => println("结果: ${value}")
        case Result<Int32>.Err(_)    => println("失败或取消")
    }
}
```

（`join()` / `when()` 与 `future.get(Duration)` 的用法直接取自 `windows_future/src/async_helpers_test.cj` 里的 `testReadyOperationJoinAndWhenReturnValue`。）

`IAsyncAction`（无返回值）同理，只是结果类型是 `Result<Unit>`：

```cangjie
import windows_core.*
import windows_future.*

// action: IAsyncAction
match (action.join()) {
    case Result<Unit>.Ok(_)     => println("完成")
    case Result<Unit>.Err(error) => println("失败: ${error.code()}")
}
```

## 注册 completed handler（用闭包）

如果你想在完成时被**回调**而不是阻塞等待，就注册一个 completed handler。每个异步接口有一个对应的 handler 委托，用静态 `new(...)` 接受闭包构造，再用 `SetCompleted(...)` 挂上去：

| 异步接口 | completed handler |
|---|---|
| `IAsyncAction` | `AsyncActionCompletedHandler` |
| `IAsyncOperation<TResult>` | `AsyncOperationCompletedHandler<TResult>` |
| `IAsyncActionWithProgress<TProgress>` | `AsyncActionWithProgressCompletedHandler<TProgress>` |
| `IAsyncOperationWithProgress<TResult, TProgress>` | `AsyncOperationWithProgressCompletedHandler<TResult, TProgress>` |

闭包收到两个参数：异步对象本身（`InParam<...>`）和终态 `AsyncStatus`。**成功 / 错误 / 取消三种情况都从 `status` 区分**：

```cangjie
import windows_core.*
import windows_future.*

// operation: IAsyncOperation<Int32>
func registerCallback(operation: IAsyncOperation<Int32>): Unit {
    let handler = AsyncOperationCompletedHandler<Int32>.new(
        { info: InParam<IAsyncOperation<Int32>>, status: AsyncStatus =>
            if (status == AsyncStatus_Completed) {
                // 成功：从 info 取出操作并读结果（InParam.get() 解出 T）
                let op = info.get()
                println("完成: ${unsafe { op.GetResults() }}")
            } else if (status == AsyncStatus_Canceled) {
                println("已取消")
            } else {
                // AsyncStatus_Error：读 IAsyncInfo.ErrorCode() 取 HRESULT
                println("出错")
            }
        }
    )
    try {
        unsafe { operation.SetCompleted(handler) }   // 挂上回调
        // 若操作已经完成，SetCompleted 会立即在当前线程触发一次回调
    } finally {
        handler.close()
    }
}
```

要点（来源：`async_helpers_test.cj` 的 `testNativeAsyncCompletedGettersReturnStoredHandlers`，那里用一模一样的 `AsyncOperationCompletedHandler<Int32>.new({ info, status => ... })` 闭包构造，并用 `SetCompleted` / `Completed` 往返）：

- handler 由仓颉闭包支撑、是个 COM 对象——存活由 GC 管，**不要**手写 AddRef/Release；不再需要时 `close()` 释放 COM 包装。
- 注册后还能用 `unsafe { operation.Completed() }` 取回当前挂着的 handler。
- 三种终态全靠 `status`：`AsyncStatus_Completed` / `AsyncStatus_Canceled` / `AsyncStatus_Error`。错误的具体 HRESULT 在 `IAsyncInfo.ErrorCode()`。

## 查询状态与取消

异步对象通过 `asIAsyncInfo()` 拿到它的 `IAsyncInfo` 面（QueryInterface），就能查状态、读错误码、请求取消：

```cangjie
import windows_core.*
import windows_future.*

// action: IAsyncAction
func cancelIt(action: IAsyncAction): Unit {
    let info = action.asIAsyncInfo()
    try {
        unsafe { info.Cancel() }                      // 请求取消
        if (unsafe { info.Status() } == AsyncStatus_Canceled) {
            println("已进入取消态")
        }
        // 出错时读 HRESULT：
        if (unsafe { info.Status() } == AsyncStatus_Error) {
            println("错误码: ${unsafe { info.ErrorCode() }.Value}")
        }
    } finally {
        info.close()
    }
}
```

取消后再 `join()`，会得到 `Result.Err`，其 HRESULT 为 `E_ABORT`。（来源：`async_helpers_test.cj` 的 `testSpawnedActionCancelTransitionsToCanceled`：`info.Cancel()` 后 `Status()` 变 `Canceled`，`join()` 返回 `E_ABORT`。）

## 自己发起一个异步操作

不只是消费——你也能把一段仓颉工作包成 WinRT 异步对象交出去。`windows_future` 提供静态 `spawnAsync(...)` 与 `ready(...)`：

```cangjie
import windows_core.*
import windows_future.*

// 把一段会返回 Int32 的工作丢到后台线程，立即得到 IAsyncOperation<Int32>
let operation = IAsyncOperation<Int32>.spawnAsync({ =>
    // 这里是后台执行的逻辑
    21i32 * 2
})
// 之后照常 join() / when() / 注册 handler
println(operation.join().unwrap())     // 42

// 已知结果时用 ready(...) 造一个“已完成”的操作
let done = IAsyncOperation<Int32>.ready(7i32)
```

`spawnAsync` 内部用 `spawn { ... }` 起一个仓颉线程跑你的闭包，正常结束就 `complete(result)`，抛 `WindowsException` 就把它的 HRESULT 透传给操作的错误态，被取消就转 `Canceled`。带进度的变体闭包会多收到一个 `reporter` 参数，调用 `reporter.report(value)` 上报进度：

```cangjie
import windows_core.*
import windows_future.*

// 带进度：闭包收到一个 ProgressReporter，可多次 report
let op = IAsyncOperationWithProgress<Int32, UInt32>.spawnAsync({ reporter =>
    reporter.report(50u32)        // 上报 50% 进度
    reporter.report(100u32)
    99i32                          // 最终结果
})
```

（来源：`async_helpers.cj` 的 `IAsyncOperation.spawnAsync` / `ready`、`ProgressReporter<TProgress>.report`，以及 `async_helpers_test.cj` 的 `testSpawnedOperationWithProgressPreservesWindowsExceptionHRESULT`。）

## 生命周期与线程注意事项

- **阻塞 vs 非阻塞。** `join()` 阻塞当前线程；在 UI/敏捷线程上长时间阻塞不可取，那种场合用 `when()`（后台跑）或 completed handler（回调）。
- **handler 触发线程。** completed handler 可能在发起线程之外被回调；如果它要触碰只能在特定单元（apartment）使用的对象，先用 `AgileReference<T>` 把对象包成敏捷引用再跨线程解引用（见 [COM API](com-api.md)）。
- **原生引用确定性回收。** `IAsyncInfo`、handler、异步对象都实现 `Resource`，用 `try`/`finally` `close()`；回收标记防 `~init` 与 `close()` 重复释放。
- **GC 管仓颉对象。** 闭包捕获的仓颉对象由 GC 维持存活，不需要手写引用计数。
- **没有 null。** 结果用 `Result<T>`，缺失值用 `Option<T>`，错误透传为 `HRESULT`。
- **条件表达式带括号**（`if (status == AsyncStatus_Completed)`），接口实现用 `<:`。

## 下一步 / 相关

- [WinUI 3](winui3.md)：UI 场景下大量使用异步与 typed 事件。
- [生成绑定](bindgen.md)：异步方法（以及它们的 handler/进度类型）是怎么被生成出来的。
- [WinRT 集合](collections.md)：异步方法常返回集合结果。
- [调用 WinRT API](winrt-api.md)：激活工厂、Type 投影、事件 handler。
- [错误处理](error-handling.md)：`Result<T>` / `HRESULT` / `WindowsException`。
