# 实现 COM 接口

上一页讲的是**消费**已有的 COM 接口；这一页讲反方向：**实现**一个 COM 接口，让你的仓颉对象能被系统或其它 COM 组件回调。windows-cj 用 `windows-interface`（声明接口）+ `windows-implement`（在仓颉类上实现）两个包配合完成。

这套机制不是“移植某门语言的 trait”，而是仓颉对 COM vtable ABI 的**等价表达**。当它的形态和你在别处见过的写法不同时，是因为它在 GC 语言里复刻了原生 vtable 的内存布局与路由，而不是缺了什么。

## 什么时候需要“实现”一个接口

- **回调 / 事件处理**：系统要求你传入一个实现了某接口的对象，之后由它回调你（典型如 WinRT 的 handler、枚举回调）。
- **把仓颉对象交给系统或其它 COM 组件**：对方拿到的是一个标准 COM 指针（带 vtable、能 `QueryInterface`、能引用计数），但背后跑的是你的仓颉代码。

如果你只是调用别人的接口，不需要本页内容——回到[调用 COM API](com-api.md)即可。

## 仓颉范式下的实现机制

先理解一个核心约束，后面的设计就都顺理成章了。

COM 要求暴露给原生侧的是一个 `@C struct` vtable（一排 `CFunc` 函数指针），它的内存布局必须严格符合 C ABI。而仓颉官方文档明确规定：**`@C` 修饰的 `struct` 成员类型必须满足 `CType` 约束、不能实现或扩展接口、不能持有 managed（GC）对象。**

所以 vtable **不能**直接内嵌一个指向“你的仓颉对象”的引用。windows-cj 用 **slot header（槽位头）+ registry（注册表）查找** 来解决：

```text
原生侧拿到的指针  ─►  ComBox 槽（@C struct，第一字段是 vtable 指针）
                         │  rootKey: UIntNative  ← 用作注册表键
                         ▼
              comRegistry: HashMap<UIntNative, Object>
                         │
                         ▼
                你的仓颉对象（GC 管理）
```

- `ComBox` 是一个 `@C struct`，第一个字段就是 vtable 指针，所以这块槽可以被直接当成 COM 接口指针看待；额外字段（`rootOffset` / `slotIndex` / `slotCount` / `rootKey`）记录它在多接口对象里的位置和回查键。
  （来源：`windows-implement/src/com_box.cj`）
- vtable 里每个 `CFunc` thunk 收到原生调用时，第一个参数是这块槽的裸指针。thunk 先用 `rootRegistryKeyFromRaw(...)` 把它换算成根对象的注册表键，再去 `comRegistry`（一个受 `Mutex` 保护的 `HashMap<UIntNative, Object>`）里 `comRegistryLookup` 找回你的仓颉对象，最后把调用转发过去。
  （来源：`windows-implement/src/com_registry.cj`、`windows-implement/src/com_box.cj`）

引用计数和 `QueryInterface` 也由这套运行时统一处理：`ComObjectRuntime<T>` 用原子计数实现 `AddRef`/`Release`，`queryInterfaceBase` 按 IID 在已解析的描述符里查对应槽位返回指针；归零时从注册表里摘除并关闭内部资源。`IUnknown`/`IInspectable`/`IAgileObject`/`IMarshal`/`IWeakReferenceSource` 这些“系统接口”会被自动接住，无需你实现。
（来源：`windows-implement/src/interface_impl_surface.cj`）

### 深继承链与 slot 计数

当接口有继承链（`IDerived <: IBase`）或一个类实现多个接口时，运行时要为每个“自定义接口”分配一个独立的 vtable 槽（slot 0 永远留给身份/`IUnknown` 或 `IInspectable`）。

- `InterfaceDescriptor` 通过 `ownMethodCount` / `descriptorOwnMethodCount()` 记录“本接口自己新增的方法数”，并把祖先 IID 展开进 `ancestorIids`，使 `QueryInterface` 能正确命中继承来的接口 IID。
  （来源：`windows-interface/src/interface_descriptor.cj`）
- 运行时按继承深度挑选每个槽该用哪个描述符（深度更大的派生接口优先占槽），保证派生接口的 vtable 覆盖到全部继承方法。
  （来源：`windows-implement/src/interface_impl_surface.cj` 的 `requiredDescriptorIndicesForCustomSlots`）

好消息是：**这些你都不用手写**。下面两个宏会替你生成 vtable 结构、thunk、描述符和实现壳。

## 第一步：用 `windows-interface` 声明接口

用 `@Interface` 宏修饰一个 `interface`，把 IID 和（可选的）运行时类名写在方括号里。宏会自动生成对应的 `Vtbl`（`@C struct`）、`InterfaceDescriptor`、`descriptorSchema()`、包装类，以及给实现侧用的 `XXX_Impl` 接口。

方法当前以原始 ABI 形式声明：返回 `Int32`（HRESULT），参数是 ABI 类型。

```cangjie
import windows_interface.macros.Interface

@Interface["11111111-1111-1111-1111-111111111111", "Fixture.Counter"]
public interface IFixtureCounter {
    func Count(value: UInt32): Int32
}
```

继承也支持，用 `<:` 指定单一直接基接口：

```cangjie
@Interface["33333333-3333-3333-3333-333333333333", "Fixture.Base"]
public interface IFixtureBase {
    func BaseValue(value: UInt32): Int32
}

@Interface["44444444-4444-4444-4444-444444444444", "Fixture.Derived"]
public interface IFixtureDerived <: IFixtureBase {
    func DerivedValue(value: UInt32): Int32
}
```

（以上写法与 `windows-interface/tests/macros/interface_implement_fixture.cj` 的真实 fixture 完全一致。宏定义见 `windows-interface/src/macros/windows_interface_macros.cj` 的 `public macro Interface`。）

宏生成的产物里有几个关键件，后面会用到：

- `IFixtureCounter.descriptor()` —— `InterfaceDescriptor<IFixtureCounter>`，查询/投影时用。
- `IFixtureCounter.descriptorSchema()` —— 描述符 schema，建对象时用。
- `IFixtureCounter.vtablePtr()` —— 指向该接口 vtable 的原生指针（一份共享单例，`@C struct` 没有 const fn，所以用 lazy static 等价表达）。
- `IFixtureCounter_Impl` —— 你的类需要实现的接口（由 `@Implement` 自动挂上）。

## 第二步：用 `windows-implement` 在仓颉类上实现

用 `@Implement` 宏修饰你的 `class`，方括号里列出要实现的接口名（可多个）。宏会把对应的 `_Impl` 接口加到类的父类型上，并生成一个 `toComObject(...)` 扩展方法，帮你把这个对象包成可交给原生侧的 `ComObject<T>`。

你只需要写出每个接口方法的方法体——参数和返回类型与接口声明里一致：

```cangjie
import windows_core.{ComObject, E_INVALIDARG, S_FALSE}
import windows_interface.macros.Implement

@Implement[IFixtureCounter]
public class FixtureCounter {
    public func Count(value: UInt32): Int32 {
        if (value == 7u32) {
            return S_FALSE.value
        }
        E_INVALIDARG.value
    }
}

// 把仓颉对象包成 COM 对象，交给系统/其它组件
public func createFixtureCounter(): ComObject<FixtureCounter> {
    FixtureCounter().toComObject()
}
```

实现多个接口，只要在 `@Implement` 里列出来，并把每个接口的方法都写齐：

```cangjie
@Implement[IFixtureCounter, IFixtureLabel]
public class CompositeFixtureCounter {
    public func Count(value: UInt32): Int32 { /* ... */ E_INVALIDARG.value }
    public func Label(value: UInt32): Int32 { /* ... */ E_INVALIDARG.value }
}
```

（以上同样来自真实 fixture。`@Implement` 宏定义见 `windows-interface/src/macros/windows_interface_macros.cj`；生成的 `toComObject` 内部调用 `windows_core.createImplementedComObject(this, schema(s), vtablePtr(s), agile: ...)`，该函数定义在 `windows-implement/src/class_factory.cj`。）

`toComObject` 默认 `agile: Bool = true`，即让对象额外支持 `IAgileObject` / `IMarshal`（自由线程封送），这通常是你想要的。

## 第三步：使用并回收 `ComObject<T>`

`ComObject<T>` 既是“你的实现的持有者”，也是它的 COM 身份。它实现 `Resource`，用引用计数管理生命周期：

```cangjie
import windows_core.*

let object = FixtureCounter().toComObject()
try {
    // 取出某个接口视图来调用（toInterface 走 QueryInterface 路由到对应槽）
    let counter = object.toInterface(IFixtureCounter.descriptor())
    try {
        let hr = unsafe { counter.Count(7u32) }
        println("hr = ${hr.value}")
    } finally {
        counter.close()        // 释放这份接口引用
    }
} finally {
    let _ = object.releaseBase()   // 引用计数 -1，归零时销毁并从注册表摘除
}
```

（这正是 fixture `main()` 里的真实用法，见 `windows-interface/tests/macros/interface_implement_fixture.cj`。）

要点：

- `ComObject<T>` 的 `releaseBase()` / `close()` 走的是引用计数；归零时运行时会从 `comRegistry` 摘除注册项、关闭内部资源、释放 native vtable/槽句柄。回收标记（`closed` + 运行时的 `destroyed` 原子标志）防止重复释放。
- 取出的接口视图（`toInterface` 的返回值）是独立的 `Resource`，单独 `close()`。
- 你**不需要**为仓颉对象之间的引用手写 AddRef/Release——GC 管这部分；引用计数只对应“原生侧持有了多少份这个 COM 身份”。

## 自由线程封送（Free-Threaded Marshaler）

当 `agile: true` 时，运行时会在 `QueryInterface(IID_IMarshal)` 上提供一个自由线程封送器，使对象可以安全跨单元使用。windows-implement 通过 `CoCreateFreeThreadedMarshaler`（`ole32.dll`）按需创建它：

```cangjie
// windows-implement 内部封装：为 outer 创建自由线程封送器，失败返回 None
public func createFreeThreadedMarshaler(outer: CPointer<Unit>): Option<IMarshal>
```

（来源：`windows-implement/src/agile_impl.cj` 与 `windows-implement/src/native.cj`。一般情况下你不直接调用它——`toComObject(agile: true)` 已经把这条路接好了。）

## 一句话总结

你写的只是一个普通仓颉 `class` + 两个宏注解；windows-cj 在背后用 `@C struct` vtable + slot header + 注册表查找，把原生 COM 调用准确路由回你的对象，并用引用计数 + `Resource` 回收标记管好生命周期。这是对 COM vtable ABI 的等价表达，不是某门语言概念的搬运。

## 下一步 / 相关

- [调用 COM API 与查询接口](com-api.md)：消费侧的视角与 `QueryInterface`。
- [调用 WinRT API](winrt-api.md)：基于本页机制的更高层 WinRT 投影。
- [错误处理](error-handling.md)：`HRESULT` / `Result<T>` 与从 thunk 返回错误码。
- [包结构总览](packages.md)：`windows-interface` / `windows-implement` 在工作区里的位置。
