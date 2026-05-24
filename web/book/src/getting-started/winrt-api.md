# 调用 WinRT API

WinRT（Windows Runtime）是 Win32 之上更现代的一层。如果说 Win32 是一组扁平的 C 函数，COM 是带 vtable 的接口，那么 WinRT 就是在 COM 之上再加了一套**运行时类型系统**：每个类型都有运行时类名、每个对象都实现 `IInspectable`、字符串统一用 `HSTRING`、对象通过**激活工厂**创建、泛型类型在运行时按签名投影。

越往上越现代、越贴近仓颉习惯——但底层仍然是 COM 指针和 vtable 槽位，所以前一页 [COM API](com-api.md) 的所有规则（`Resource` 回收、`Option<T>` 代替 null、`<:` 实现接口）在这里继续适用。

## WinRT 是什么

把 WinRT 拆成几条具体约定，理解起来就清晰了：

- **建立在 COM 之上。** 每个 WinRT 接口仍然是一个 vtable 指针，前三槽是 `IUnknown` 的 `QueryInterface`/`AddRef`/`Release`。
- **统一根接口 `IInspectable`。** 所有 WinRT 对象都实现它（紧跟在 `IUnknown` 之后的三个槽：`GetIids`/`GetRuntimeClassName`/`GetTrustLevel`），所以任何 WinRT 对象都能问出自己的运行时类名。
- **运行时类型系统。** 类型有字符串签名（如 `"rc(Windows.Foundation.Uri;{...})"`），泛型接口的 IID 由签名计算得出——这就是 windows-cj 里 `IReference<T>.iid()` 调用 `GUID.from_signature(...)` 的原因。
- **激活工厂。** 你不能直接 `new` 一个 WinRT 运行时类；而是先拿到它的**激活工厂**（一个静态接口），再调用工厂上的 `CreateXxx`。windows-cj 把这套流程封装好了。
- **字符串用 `HSTRING`。** WinRT 方法收发字符串都用 `HSTRING`，在仓颉里对应 `HString`（见 [字符串](strings.md)）。

windows-cj 把这些投影分散在几个包里：基础值类型与激活底座在 `windows-core`，Foundation 投影（`Uri`、`PropertyValue`、`MemoryBuffer`、`Deferral` 等）在 `windows-foundation`，集合在 `windows-collections`，异步在 `windows-future`。

## 一个完整的例子：创建并使用 `Uri`

`Windows.Foundation.Uri` 是最适合入门的 WinRT 运行时类：它要走激活工厂、收发 `HString`、并实现了 `IStringable`。

先在 `cjpm.toml` 里声明依赖（路径按你的仓库布局调整）：

```toml
[dependencies]
  windows_core = { path = "../windows-core" }
  windows_foundation = { path = "../windows-foundation" }
```

然后：

```cangjie
import windows_core.*
import windows_foundation.*

func demoUri(): Unit {
    // HSTRING 形式的输入字符串。HString 实现 Resource，用完要 close。
    let uriText = HString("https://example.com/path?x=1&y=two")
    try {
        // Uri.CreateUri 内部走激活工厂：拿到 IUriRuntimeClassFactory，
        // 调用 CreateUri 槽位，把返回指针包成 Uri。
        // 这是静态工厂方法，标了 unsafe（最终读裸指针、走 CFunc）。
        let uri = unsafe { Uri.CreateUri(uriText) }
        try {
            // AbsoluteUri / Domain / Port 等都对应 IUriRuntimeClass 的 vtable 槽位，
            // 返回 HString 的方法把 HSTRING 包成 HString 交给你。
            let absolute = unsafe { uri.AbsoluteUri() }
            try {
                println("绝对地址: ${absolute.get()}")   // get() 取出仓颉 String
            } finally {
                absolute.close()
            }
            println("端口: ${unsafe { uri.Port() }}")

            // Uri 实现了 IStringable，所以可以 ToString()（同样返回 HString）。
            let text = unsafe { uri.ToString() }
            try {
                println("ToString: ${text.get()}")
            } finally {
                text.close()
            }
        } finally {
            uri.close()      // 确定性释放原生 COM 引用
        }
    } finally {
        uriText.close()
    }
}
```

要点：

- `Uri.CreateUri(...)` 是**激活工厂**调用的便捷封装。它内部用 `windows_core.factory<Uri, IUriRuntimeClassFactory>()` 取到工厂、调 `CreateUri`、`Uri.fromAbiTake(result)` 接管返回指针。（来源：`windows-foundation/src/foundation_runtime.cj` 的 `Uri.CreateUri` / `IUriRuntimeClassFactory.CreateUri`。）
- WinRT 投影方法标 `unsafe`，因为底层读裸指针、走 `CFunc`——在 `unsafe { }` 块里调用即可。
- 收发字符串用 `HString`；返回的 `HString` 由你负责 `close()`。`HString.get()` 把它转成仓颉 `String`。
- 错误以 `WindowsException`（HRESULT 失败）抛出，按 [错误处理](error-handling.md) 的方式接住。

### 这个 `Uri` 例子真实可信

`windows-foundation` 的冒烟测试就跑了几乎一模一样的流程：`Uri.CreateUri(HString(...))` → `AbsoluteUri()` → `QueryParsed()` 拿到 `WwwFormUrlDecoder` → 遍历查询参数，全部跨真实 vtable ABI 往返。（来源：`windows-foundation/src/windows_foundation_smoke_test.cj`。）

## 激活工厂缓存做了什么

“拿到工厂”这一步并不便宜——它要按运行时类名去 `combase.dll` 里查 DLL、解析激活工厂、`QueryInterface` 到你要的工厂接口。windows-cj 把这条路径集中在 `windows-core/src/factory_cache.cj` 里：

- **`loadFactoryByName<I>(runtimeName, descriptor)` / `factory<C, I>()`**：核心入口。先调 `RoGetActivationFactory`（系统激活）；若返回“类未注册”，再回退到 reg-free 路径——按命名空间逐段截断猜 DLL 名（`Windows.Foundation.Uri` → `Windows.Foundation.dll` → `Windows.dll`），用 `DllGetActivationFactory` 取工厂。
- **MTA 兜底**：若激活返回 `CO_E_NOTINITIALIZED`，会先 `CoIncrementMTAUsage` 把当前进程并入 MTA，再重试一次。这个 cookie 进程内只取一次（`FactoryMTAUsageGuard`），不会每次回退都泄漏。
- **`FactoryCache<C, I>`**：可选的工厂缓存。它只缓存满足 `IAgileObject`（敏捷）的工厂——非敏捷工厂不缓存，避免跨单元误用。缓存本身实现 `Resource`，`close()` 时释放缓存的工厂指针；`closed` 标记防止 `~init` 与 `close()` 重复释放。

你平时不会直接碰这些——`Uri.CreateUri`、`PropertyValue.CreateInt32` 这类便捷方法已经替你调用了 `factory<...>()`。理解它存在的意义在于：**WinRT 对象的“构造”实质是一次激活工厂查找 + 一次工厂方法调用。**

## Type 投影：ABI 类型如何映射到仓颉

WinRT 的每个参数/返回值在 ABI 层都有一个具体的 C 表示（`HSTRING`、`Int32`、内联结构体、接口指针……），而在仓颉侧你想用的是 `HString`、`Int32`、`Point`、接口包装类。把两者对应起来的，是 `windows-core/src/type_system.cj` 里的 `Type` 接口：

```cangjie
public interface Type<TProjected, TAbi, TDefault> <: WindowsType {
    static func typeKind(): TypeKind            // Interface / Clone / Copy
    static func projectAbi(value: TProjected): TAbi
    static func assumeInitRef(abi: TAbi): TProjected
    static func fromAbi(abi: TAbi): Result<TProjected>
    static func fromDefault(defaultValue: TDefault): Result<TProjected>
}
```

理解这套设计的几个点：

- **三个类型参数而非关联类型。** 仓颉泛型不支持关联类型，所以这里用 `Type<TProjected, TAbi, TDefault>` 把“仓颉投影类型 / ABI 表示 / 默认值类型”三者显式列出。这是语言范式差异下的等价方案，不是缺陷。
- **`TypeKind` 区分三类**（`type_system.cj` 的 `enum TypeKind { | Interface | Clone | Copy }`）：值类型（`Copy`，如 `DateTime`）、需要克隆的类型（`Clone`，如 `HString`）、接口（`Interface`）。
- **`projectAbi` / `assumeInitRef`** 是一对：把仓颉值打成 ABI 结构、再从 ABI 结构还原仓颉值。泛型方法把这对操作借给 vtable 调用，让 `IReference<T>.Value()`、`IVector<T>.GetAt(i)` 这类泛型方法能在运行时按 `T` 正确收发。

你写业务代码时几乎不会直接实现 `Type`——绑定生成器为每个值类型生成好了。但当你看到泛型方法签名里要求 `where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T>` 时，背后就是这套投影在工作。

## Foundation 值类型与 `IReference<T>` 装箱

WinRT 有一批小的内联值类型，windows-cj 把它们定义在 `windows-core/src/foundation_values.cj`（放在 core 是为了让 collections 和 foundation 都能用而不形成依赖环）：

| 仓颉类型 | 字段 | WinRT 含义 |
|---|---|---|
| `DateTime` | `UniversalTime: Int64` | 绝对时间点（100ns 刻度） |
| `TimeSpan` | `Duration: Int64` | 时间间隔（100ns 刻度） |
| `Point` | `X, Y: Float32` | 二维点 |
| `Size` | `Width, Height: Float32` | 尺寸 |
| `Rect` | `X, Y, Width, Height: Float32` | 矩形 |
| `EventRegistrationToken` | `Value: Int64` | 事件注册句柄 |

它们都是仓颉 `struct`（值语义），并通过 `extend` 实现了 `CopyType & Type<...>`，带有 ABI 伴生结构（`@C struct DateTimeAbi` 等）用于跨边界传递：

```cangjie
import windows_core.*

let now = DateTime()           // UniversalTime 默认 0
let topLeft = Point()          // X = 0, Y = 0
var box = Rect()
box.Width = 320.0
box.Height = 240.0
```

### 装箱：`PropertyValue` 与 `IReference<T>`

WinRT 用 `IReference<T>`（“可空的盒子”）和 `PropertyValue`（装箱原语）在“需要 `IInspectable` 的地方传一个标量”。`windows-foundation` 的 `PropertyValue` 提供一组静态工厂，每个都返回装好的 `IInspectable`：

```cangjie
import windows_core.*
import windows_foundation.*

// 把一个 Int32 装箱成 IInspectable（内部走 IPropertyValueStatics 激活工厂）
let boxed = unsafe { PropertyValue.CreateInt32(42i32) }
try {
    // 之后可以把 boxed 当作 IInspectable 传给任何接收装箱值的 WinRT API
    // 也能 QueryInterface 回 IPropertyValue 读出原值。
    ()
} finally {
    boxed.close()
}
```

（来源：`windows-foundation/src/foundation_runtime.cj` 的 `PropertyValue.CreateInt32` / `CreateString` / `CreateGuid` / `CreateDateTime` / `CreatePoint` 等，以及它们背后的 `IPropertyValueStatics`。）

`IReference<T>` 是泛型版本：它的 `Value()` 方法按 `T` 投影出真实值，`Type()` 报告底层 `PropertyType`。它要求 `T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T>`——也就是 `T` 必须是能在运行时投影的 WinRT 类型。

`PropertyValue` 还能装数组（`CreateInt32Array(Array<Int32>)`、`CreateStringArray(Array<HString>)` 等），对应 `IReferenceArray<T>`，用法同理。

## 事件：`EventHandler<T>` 与 `TypedEventHandler<TSender, TResult>`

WinRT 事件通过委托接口分发回调。windows-foundation 提供两个：

- `EventHandler<T>`：经典事件，回调签名 `(sender: IInspectable, args: T)`。
- `TypedEventHandler<TSender, TResult>`：强类型发送者与参数，回调签名 `(sender: TSender, args: TResult)`。

两者都用静态 `new(...)` 接受一个**闭包**来构造——这正是仓颉处理回调的方式（无需手写 vtable）：

```cangjie
import windows_core.*
import windows_foundation.*

// 构造一个 TypedEventHandler；闭包就是收到事件时执行的逻辑。
let handler = TypedEventHandler<IInspectable, IInspectable>.new(
    { sender: IInspectable, args: IInspectable =>
        // 在这里处理事件。sender / args 由调用方传入。
        let _ = sender
        let _ = args
    }
)
try {
    // 之后把 handler 交给某个 WinRT 对象的 add_Xxx 事件注册方法，
    // 它会返回一个 EventRegistrationToken，用于后续注销。
    ()
} finally {
    handler.close()
}
```

（来源：`windows-foundation/src/foundation_runtime.cj` 的 `TypedEventHandler.new(invoke: (TSender, TResult) -> Unit)` 与 `EventHandler.new(invoke: (InParam<IInspectable>, T) -> Unit)`。两个泛型参数都受 `WinrtGenericType` 约束。）

注意 `new(...)` 构造出的 handler 是一个由仓颉对象支撑的 COM 对象——它的存活由 GC 管理，你**不需要**手写 AddRef/Release；只需在不再需要时 `close()` 释放底层 COM 包装。

## 范式提醒

- **GC 管仓颉对象，你管原生引用。** 接口包装实现 `Resource`，用 `try`/`finally` 或 try-with-resource 做确定性 `close()`；回收标记防 double free。
- **没有 null。** 缺失值用 `Option<T>`，可失败结果用 `Result<T>` / `HRESULT`。
- **接口实现用 `<:`**，条件表达式必须带括号（`if (hr.succeeded())`）。
- **回调用闭包**，不用手写委托类。
- 不要为了“对齐某种语言”而生造借用/所有权概念——仓颉的范式就是这样。

## 下一步 / 相关

- [WinRT 集合](collections.md)：`IVector` / `IMap` / `IIterable` 家族与 stock 实现。
- [WinRT 异步操作](async.md)：`IAsyncOperation<T>` / `IAsyncAction` 与等待结果。
- [字符串](strings.md)：`HString` / `HSTRING` 的完整用法。
- [错误处理](error-handling.md)：`HRESULT` / `Result<T>` / `WindowsException`。
- [调用 COM API](com-api.md)：WinRT 底下那一层 COM 模型。
