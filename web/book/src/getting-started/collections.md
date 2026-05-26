# WinRT 集合

WinRT 有一套自己的集合接口家族，命名空间是 `Windows.Foundation.Collections`。它们都是 WinRT 泛型接口——建立在 COM 之上、IID 由签名计算、元素按 `Type` 投影。windows-cj 把它们投影在 `windows_collections` 包里。

这一页讲两件事：**消费**别人给你的 WinRT 集合（遍历、取元素），以及用 **stock 实现**把仓颉数据当作 WinRT 集合**交出去**。

越往上越贴近仓颉习惯：消费侧的迭代器直接接进了仓颉的 `for-in`。

## 集合接口家族

| 接口 | 语义 | 关键方法 |
|---|---|---|
| `IIterable<T>` | 可迭代——能要到一个迭代器 | `First(): IIterator<T>` |
| `IIterator<T>` | 游标——逐个走过元素 | `Current()`、`HasCurrent()`、`MoveNext()`、`GetMany(...)` |
| `IVectorView<T>` | **只读**索引序列 | `GetAt(index)`、`Size()`、`IndexOf(...)`、`GetMany(...)` |
| `IVector<T>` | **可变**索引序列 | 上面的 + `SetAt`、`InsertAt`、`Append`、`RemoveAt`、`RemoveAtEnd`、`Clear`、`GetView()`、`ReplaceAll` |
| `IMapView<K, V>` | **只读**键值映射 | `Lookup(key)`、`Size()`、`HasKey(key)`、`Split(...)` |
| `IMap<K, V>` | **可变**键值映射 | 上面的 + `Insert`、`Remove`、`Clear`、`GetView()` |
| `IKeyValuePair<K, V>` | 映射里的一个条目 | `Key()`、`Value()` |

记忆方式：**View 结尾的是只读快照**，不带 View 的是可变集合，可变集合都能 `GetView()` 给出一份只读视图。`IVector`/`IVectorView`/`IMap`/`IMapView` 都继承 `IIterable<T>`，所以都能遍历。

（来源：`windows_collections/src/collections_runtime.cj`，每个接口的 `descriptorSchema()` 列出了它的真实 vtable 槽位与方法名。）

所有泛型参数都受同一套约束：`where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T>`——`T` 必须是可在运行时投影的 WinRT 类型（标量、`HString`、值类型、或接口）。

## 遍历一个集合

### 方式一：索引（`Size` + `GetAt`）

对 `IVectorView<T>` / `IVector<T>`，最直接的就是按下标取：

```cangjie
import windows_core.*
import windows_collections.*

// view: IVectorView<Int32>，从某个 WinRT API 拿到
func sumView(view: IVectorView<Int32>): Int64 {
    var total: Int64 = 0
    let count = unsafe { view.Size() }          // 元素个数（UInt32）
    var i = 0u32
    while (i < count) {
        let item = unsafe { view.GetAt(i) }     // 第 i 个元素，按 T 投影回 Int32
        total += Int64(item)
        i += 1
    }
    total
}
```

`windows_collections` 的冒烟测试就用了这条路径：构造一个 `IVectorView<Int32>`，断言 `Size()` 为 3、`GetAt(0)` 为 10、`IndexOf(20, ...)` 命中下标 1，全部跨真实 vtbl ABI 往返。（来源：`windows_collections/src/windows_collections_smoke_test.cj`。）

### 方式二：迭代器（`First` / `IIterator`）

`IIterable<T>.First()` 给你一个 `IIterator<T>` 游标。WinRT 迭代器的协议是：迭代器创建时就指向第一个元素，`HasCurrent()` 问“当前是否有效”，`Current()` 取当前元素，`MoveNext()` 前进一格并返回前进后是否仍有效。

```cangjie
import windows_core.*
import windows_collections.*

// iterable: IIterable<Int32>
func printAll(iterable: IIterable<Int32>): Unit {
    let it = unsafe { iterable.First() }        // 拿到 IIterator<Int32>
    try {
        while (unsafe { it.HasCurrent() }) {
            let value = unsafe { it.Current() }
            println(value)
            unsafe { it.MoveNext() }
        }
    } finally {
        it.close()                              // 释放迭代器的原生引用
    }
}
```

### 方式三：直接用仓颉 `for-in`

windows-cj 让 `IIterator<T>` 和 `IIterable<T>` 都提供了 `iterator(): Iterator<T>`（仓颉标准库的迭代器接口），所以你可以直接 `for-in`，不必手写 `HasCurrent`/`MoveNext`：

```cangjie
import windows_core.*
import windows_collections.*

// iterable: IIterable<Int32>，转成仓颉迭代器后用 for-in
func printAllForIn(iterable: IIterable<Int32>): Unit {
    for (value in iterable) {       // IIterable<T> 实现了 iterator()
        println(value)
    }
}
```

（来源：`collections_runtime.cj` 的 `IIterable<T>.iterator()` / `intoIterator()` 返回 `IIteratorIterator<T>`，后者实现仓颉 `Iterator<T>`。这是消费侧最贴近仓颉习惯的写法。）

### 映射：`Lookup` / `HasKey`

```cangjie
import windows_core.*
import windows_collections.*

// mapView: IMapView<Int32, Int32>
func lookupOr(mapView: IMapView<Int32, Int32>, key: Int32, fallback: Int32): Int32 {
    if (unsafe { mapView.HasKey(key) }) {       // 先确认键存在
        return unsafe { mapView.Lookup(key) }   // 取值，按 V 投影
    }
    fallback
}
```

遍历映射时，元素类型是 `IKeyValuePair<K, V>`，用 `Key()` / `Value()` 拆开：

```cangjie
// mapView: IMapView<Int32, Int32>
for (pair in mapView) {                  // 元素是 IKeyValuePair<Int32, Int32>
    let k = unsafe { pair.Key() }
    let v = unsafe { pair.Value() }
    println("${k} => ${v}")
}
```

### 修改可变集合

`IVector<T>` / `IMap<K, V>` 多出一组写方法：

```cangjie
import windows_core.*
import windows_collections.*

// vector: IVector<Int32>
func mutate(vector: IVector<Int32>): Unit {
    unsafe {
        vector.Append(40i32)        // 尾部追加
        vector.InsertAt(0u32, 5i32) // 在下标 0 插入
        vector.SetAt(1u32, 99i32)   // 覆盖下标 1
        vector.RemoveAtEnd()        // 移除最后一个
    }
    // 取一份只读视图交给只接受 IVectorView 的 API
    let view = unsafe { vector.GetView() }
    try {
        println("现在有 ${unsafe { view.Size() }} 个元素")
    } finally {
        view.close()
    }
}
```

（来源：`collections_runtime.cj` 的 `IVector` 方法 `Append`/`InsertAt`/`SetAt`/`RemoveAt`/`RemoveAtEnd`/`Clear`/`GetView`/`ReplaceAll`，以及 `IMap` 的 `Insert`/`Remove`/`Clear`/`GetView`。）

## stock 实现：把仓颉数据当作 WinRT 集合交出去

反过来的需求也很常见：一个 WinRT API 要你传入一个 `IVectorView<Int32>` 或 `IMapView<K, V>`，而你手上是仓颉的 `Array` / `ArrayList`。这时不用自己实现 vtable——`windows_collections/src/stock.cj` 提供了一组 **stock（现成）转换函数**，把任意仓颉 `Iterable` 包成 WinRT 集合 COM 对象。

| 函数 | 输入 | 产出 |
|---|---|---|
| `toIterator<T>(source: Iterable<T>)` | 仓颉可迭代 | `IIterator<T>` |
| `toIterable<T>(source: Iterable<T>)` | 仓颉可迭代 | `IIterable<T>` |
| `toVectorView<T>(source: Iterable<T>)` | 仓颉可迭代 | `IVectorView<T>` |
| `toKeyValuePair<K, V>(key, value)` | 一对键值 | `IKeyValuePair<K, V>` |
| `toMapView<K, V>(source: Iterable<(K, V)>)` | 键值对序列 | `IMapView<K, V>` |

```cangjie
import std.collection.*
import windows_core.*
import windows_collections.*

// 把仓颉的 ArrayList<Int32> 交成一个只读 WinRT IVectorView<Int32>
func handOff(): Unit {
    let data = ArrayList<Int32>([10i32, 20i32, 30i32])
    let view = toVectorView(data)     // 得到 IVectorView<Int32>
    try {
        // 现在 view 是一个真正的 WinRT COM 对象，可以传给任何
        // 接受 IVectorView<Int32> 的 WinRT 方法。
        println("交出 ${unsafe { view.Size() }} 个元素")
    } finally {
        view.close()
    }
}
```

这正是冒烟测试的写法：`toVectorView(ArrayList<Int32>([10, 20, 30]))` 然后跨 ABI 调 `Size()`/`GetAt()`/`IndexOf()`。（来源：`windows_collections_smoke_test.cj` + `stock.cj` 的 `toVectorView`。）

映射同理：

```cangjie
import windows_core.*
import windows_collections.*

// 把一组 (Int32, Int32) 键值对交成只读 WinRT IMapView<Int32, Int32>
let entries = [(1i32, 100i32), (2i32, 200i32)]
let mapView = toMapView(entries)      // 得到 IMapView<Int32, Int32>
try {
    println(unsafe { mapView.Lookup(1i32) })   // 100
} finally {
    mapView.close()
}
```

### stock 实现在背后做了什么

值得了解一点机制，便于理解约束来自哪里：

- 泛型版 `toVectorView<T>` 要求 `T <: RuntimeType & HandleWinrtType<T> & Equatable<T>`——`Equatable` 是因为 `IVectorView.IndexOf` 要比较元素。常用标量（`Int32` 等）还有专门的非泛型重载（如 `toVectorView(source: Iterable<Int32>)`），路径更直接。
- 它先用 `snapshotList<T>(source)` 把仓颉数据**拍快照**存进一个内部 impl 对象（`StockVectorViewImpl<T>` / `StockInt32VectorViewImpl` 等），交出去的是这份快照——之后改动原 `ArrayList` 不会影响已交出的视图。
- 然后用 `createStockInterfaceMulti(...)` 把 impl 包成一个多接口 COM 对象：同时注册 `IIterable<T>` 和 `IVectorView<T>` 两张独立 vtbl，让对 `IID_IIterable<T>` 的 QueryInterface 返回它自己的 vtbl 槽位，而不是错误地复用 `IVectorView` 的。
- 返回的集合是由仓颉 impl 对象支撑的 COM 对象，存活由 GC 管理；你只需在交出方用完后 `close()` 释放 COM 包装。

（来源：`stock.cj` 的 `toVectorView` / `toMapView` / `createStockInterfaceMulti` 与各 `Stock*Impl` 类。）

## 范式提醒

- 集合接口方法标 `unsafe`（最终走 vtable 裸调用），在 `unsafe { }` 里调用。
- 取到的迭代器 / 视图 / 元素包装都实现 `Resource`，用 `try`/`finally` `close()`；回收标记防 double free。
- 缺失值用 `Option<T>`、没有 null；先 `HasKey` 再 `Lookup` 是稳妥写法。
- 消费侧优先用 `for-in`（`IIterable<T>` 已接进仓颉迭代器协议）；交出侧优先用 `toVectorView` / `toMapView`，不要手写 vtable。
- 泛型约束 `where T <: RuntimeType & WinrtGenericType<T>` 不是噪音，它保证 `T` 能在运行时投影。

## 下一步 / 相关

- [WinRT 异步操作](async.md)：很多集合是异步方法的返回结果，配合 `IAsyncOperation<T>` 使用。
- [调用 WinRT API](winrt-api.md)：激活工厂、Type 投影、Foundation 值类型。
- [字符串](strings.md)：集合里常见 `HString` 键值。
- [错误处理](error-handling.md)：`HRESULT` / `WindowsException` 的处理。
