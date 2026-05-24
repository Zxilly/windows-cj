# 调用 COM API 与查询接口

很多 Windows 能力是以 COM 接口的形式暴露的。这一页讲清楚 COM 的核心模型，以及 windows-cj 如何把它映射进仓颉：怎样拿到一个接口、调用它的方法、查询它实现的其它接口，以及如何正确管理原生 COM 指针的生命周期。

当某段代码看起来与你在其它语言里的写法不同时，多半是因为它遵循了仓颉的范式，而非缺失了功能。

## COM 模型速讲

一个 COM 对象在内存里是一个指向 **vtable**（虚函数表）的指针。vtable 是一组按固定顺序排列的函数指针，调用方通过“第几个槽位”来调用方法，这就是 COM 的 ABI 约定。

每个 COM 接口都继承自 `IUnknown`，它的前三个槽位永远是：

```text
槽 0: QueryInterface(riid, ppvObject)  —— 问“你支不支持这个接口？”
槽 1: AddRef()                          —— 引用计数 +1
槽 2: Release()                         —— 引用计数 -1，归零则销毁
```

- **引用计数**决定对象何时销毁：每持有一份引用就 `AddRef`，用完就 `Release`。
- **`QueryInterface`** 用一个 IID（接口 GUID）问对象要另一个接口；支持就返回新指针（并已 `AddRef`），不支持就返回 `E_NOINTERFACE`。

### windows-cj 怎么映射

底座类型定义在 `windows-interface` 包里，并由 `windows-core` 重导出（你通常 `import windows_core` 即可）。关键约定：

- 接口契约 `ComInterface`：每个 COM 接口包装类都实现它，提供 `asRaw(): CPointer<Unit>`（拿到底层指针）和静态的 `iid()`。
  （来源：`windows-interface/src/interface_descriptor.cj`）
- vtable 用 `@C struct` 表达，例如 `IUnknownVtbl`、`IInspectableVtbl`。它们的字段是 `CFunc<...>`，第一个字段 `base_` 内联基接口的 vtable，从而复刻 C 的内存布局。
  （来源：`windows-interface/src/interface_wrapper.cj`）
- 接口包装类（`IUnknown`、`IInspectable` 等）继承自 `InterfaceWrapperBase`，它实现了 `Resource`，负责持有原生指针并在关闭时 `Release`。
- `InterfaceDescriptor<T>` 是“调用侧契约”：它把一个接口名、IID、以及“如何从 ABI 指针构造仓颉包装”绑在一起。查询和投影都围绕它进行。

仓颉是 GC 语言。**仓颉对象之间的引用由 GC 管理，你不需要、也不应该手写 AddRef/Release 来维持仓颉侧的存活**。`AddRef`/`Release` 只在跨越仓颉 ↔ 原生 COM 边界、需要明确“谁拥有这块原生引用”时才出现，而 windows-cj 已经把这部分封装进了 `Resource` 生命周期里（见本页最后一节）。

## 拿到一个接口并调用它的方法

接口包装类把每个 vtable 槽位暴露成一个普通方法。因为调用最终会读裸指针、走 `CFunc`，所以这些方法标了 `unsafe`，需要在 `unsafe { }` 块里调用。

以 `IInspectable`（所有 WinRT 对象都实现它）为例，它的方法直接对应 vtable 槽位：

```cangjie
import windows_core.*

// 假设你从某处拿到了一个实现 IInspectable 的对象包装 inspectable: IInspectable
func printRuntimeClass(inspectable: IInspectable): Unit {
    // getRuntimeClassName 内部读 vtbl，调用 GetRuntimeClassName 槽位，
    // 并把返回的 HSTRING 包装成 HString（失败时抛 WindowsException）
    let name = unsafe { inspectable.getRuntimeClassName() }
    println("运行时类名: ${name}")
}
```

`IInspectable` 还提供了底层一点的入口，比如直接读 vtable 调用某个槽位：

```cangjie
// 直接走 ABI：传入 out 槽位指针，拿回 HRESULT
var trustLevel = 0i32
let hr = unsafe { inspectable.getTrustLevel(CPointer<Int32>(inout trustLevel)) }
if (hr.succeeded()) {
    println("trust level = ${trustLevel}")
}
```

要点：

- 方法返回 `HRESULT`（薄封装的 `Int32`），用 `.succeeded()` / `.failed()` 判断，或在更高层封装里直接抛 `WindowsException`。
- out 参数是 `CPointer<...>`，用 `CPointer<T>(inout localVar)` 取本地变量地址传进去——这就是 COM 的“传出参数”约定。

绝大多数 Win32/WinRT 接口由绑定生成器产出，使用方式与上面一致：拿到包装对象，`unsafe { obj.SomeMethod(...) }`。

## 查询接口（QueryInterface）

“这个对象还实现了别的接口吗？”——这正是 `QueryInterface` 回答的问题。windows-cj 提供了几条等价路径，全部基于 `InterfaceDescriptor<T>`。

### 顶层 `cast`：返回 `Result<U>`

`cast` 把一个接口查询成另一个接口，成功给 `Result.Ok(目标接口)`，失败给 `Result.Err(错误)`：

```cangjie
import windows_core.*

// 把任意 ComInterface 查询成 IAgileObject
func tryAsAgile<T>(source: T): Option<IAgileObject> where T <: ComInterface & Interface<T> {
    match (unsafe { cast<T, IAgileObject>(source, IAgileObject.descriptor()) }) {
        case Result<IAgileObject>.Ok(agile) => Some(agile)
        case Result<IAgileObject>.Err(_)    => None
    }
}
```

（`cast` 来源：`windows-core/src/interface.cj`；它内部调用 `queryInterfaceResult`，对失败结果会正确 `Release` 出参，避免泄漏。）

### 从裸指针直接查询：返回 `Option`

如果手头是一个裸 `CPointer<Unit>`，可以用 `queryInterfaceAs`（成功返回 `Some(包装)`，否则 `None`），或更底层的 `queryInterfaceRaw`（返回 `Option<CPointer<Unit>>`）：

```cangjie
// 用 descriptor 一步查询并包装
match (unsafe { queryInterfaceAs(rawPointer, IInspectable.descriptor()) }) {
    case Some(inspectable) => unsafe { inspectable.getRuntimeClassName() }
    case None              => throw Exception("对象未实现 IInspectable")
}
```

（来源：`windows-interface/src/interface_wrapper.cj` 的 `queryInterfaceRaw` / `queryInterfaceAs`，由 `windows-core` 重导出。）

### 包装对象上的 `.query(...)`

`InterfaceWrapperBase` 自带一个实例方法 `query<T>(descriptor)`，等价于“拿自己的 `asRaw()` 去 QueryInterface”，返回 `Option<T>`：

```cangjie
// inspectable 是某个接口包装；查询它是否也实现 IWeakReferenceSource
match (unsafe { inspectable.query(IWeakReferenceSource.descriptor()) }) {
    case Some(source) => /* 拿到 IWeakReferenceSource */ ()
    case None         => ()
}
```

无论走哪条路径，**失败时你拿到的是 `None` 或 `Result.Err`，而不是 null**——仓颉没有 `null`，缺失值一律用 `Option<T>`/`Result<T>` 表达。

## `AgileReference<T>`：跨线程安全传递接口

很多 COM 对象绑定在创建它的单元（apartment）上，不能裸跨线程使用。`AgileReference<T>` 把一个接口包成可在任意线程解引用的敏捷引用，底层调用 `RoGetAgileReference`。

```cangjie
import windows_core.*

// 把一个接口对象 obj 包成敏捷引用
func makeAgile<T>(obj: T, descriptor: InterfaceDescriptor<T>): Result<AgileReference<T>> where T <: ComInterface {
    AgileReference<T>.new(obj, descriptor)
}

// 在另一个线程里解引用，重新拿回接口
func useOnOtherThread<T>(reference: AgileReference<T>): Result<T> where T <: ComInterface {
    reference.resolve()   // 返回 Result<T>：Ok(接口) 或 Err(HRESULT)
}
```

（来源：`windows-core/src/agile_reference.cj`。签名为 `AgileReference<T>.new(object: T, descriptor: InterfaceDescriptor<T>): Result<AgileReference<T>>` 与 `resolve(): Result<T>`，其中 `T <: ComInterface`。）

`AgileReference<T>` 本身实现 `Resource`：用完后 `close()` 会释放它内部持有的敏捷引用。

## 原生 COM 指针的生命周期

这是与“GC 管理仓颉对象”相对的另一半：**原生 COM 引用不归 GC 管，必须确定性地释放。** windows-cj 的做法是让接口包装实现 `Resource`：

- `InterfaceWrapperBase`（所有接口包装的基类）实现 `Resource`，提供 `close()`。它内部用 `closed_: Bool` 作回收标记，并对“拥有所有权的句柄”用一个带原子标志的 `OwnedHandleState` 兜底——这样 **析构器 `~init` 与显式 `close()` 不会重复 `Release`（避免 double free）**。
  （来源：`windows-interface/src/interface_wrapper.cj`）
- 取得所有权的包装（`fromAbiTake` 系列，对应 QueryInterface/激活返回的“已 AddRef”指针）在 `close()` 时正好做一次 `Release`；只是“借用视图”（`viewOf`）则不释放。
- `closed_` 标记保证 `close()` 幂等：第二次调用直接返回，不会二次释放。

实践上，用仓颉的 `try`-`finally` 做确定性回收（与官方 `Resource` 的 try-with-resource 语义一致）：

```cangjie
import windows_core.*

func consume(rawFromQuery: CPointer<Unit>): Unit {
    // fromAbiTake 接管所有权：close() 时会 Release 一次
    let inspectable = IInspectable.fromAbiTake(rawFromQuery)
    try {
        let name = unsafe { inspectable.getRuntimeClassName() }
        println(name)
    } finally {
        inspectable.close()   // 确定性释放原生引用
    }
}
```

对于由你实现并交给系统的对象（`ComObject<T>`），生命周期略有不同——它用引用计数驱动 `releaseBase()`，详见下一页。

要点回顾：

- 仓颉对象之间的引用：GC 管，**不要**手写 AddRef/Release 去维持。
- 跨边界的原生 COM 引用：用 `Resource` + `close()` 确定性回收，回收标记防 double free。
- 缺失值用 `Option<T>`，错误用 `Result<T>` / `HRESULT`，没有 `null`。
- 接口实现关系用 `<:`（如 `IUnknown <: InterfaceWrapperBase & ComInterface`）。

## 下一步 / 相关

- [实现 COM 接口](implement-com.md)：当你需要把一个仓颉对象交给系统/其它 COM 组件时。
- [调用 WinRT API](winrt-api.md)：基于 `IInspectable` 的更高层投影。
- [错误处理](error-handling.md)：`HRESULT` / `Result<T>` / `WindowsException` 的完整用法。
- [字符串](strings.md)：`HString` / `HSTRING` 与 COM/WinRT 的交互。
