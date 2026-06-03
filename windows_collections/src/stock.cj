package windows_collections
import windows_interface as windows_interface
import std.collection.*
import std.sync.AtomicInt64
import windows_core.{
    ComInterface,
    E_FAIL,
    E_NOINTERFACE,
    E_NOTIMPL,
    E_POINTER,
    HString,
    HandleWinrtType,
    HRESULT,
    Result,
    RuntimeType,
    S_OK,
    WinrtGenericType,
    WinError,
    asImplFromRaw,
    buildIInspectableVtbl,
    createComObjectFromSchemas,
    winrtProjectGenericIn,
    winrtReleaseGenericOutRange,
    winrtStoreGenericOutAt
}
import windows_interface.{GUID, IInspectableVtbl, InterfaceDescriptor, InterfaceDescriptorSchema, InterfaceMethodSchema, InterfaceParameterBridgeKind, InterfaceParameterSchema}

let STOCK_E_BOUNDS = HRESULT(-2147483637i32)
let IID_BINDABLE_ITERABLE = GUID(0x036D2C08, 0xDF29, 0x41AF, 0x8A, 0xA2, 0xD7, 0x74, 0xBE, 0x62, 0xBA, 0x6F)
let IID_BINDABLE_ITERATOR = GUID(0x6A1D6C07, 0x076D, 0x49F2, 0x83, 0x14, 0xF5, 0x2C, 0x9C, 0x9A, 0x83, 0x31)
let IID_BINDABLE_VECTOR = GUID(0x393DE7DE, 0x6FD0, 0x4C0D, 0xBB, 0x71, 0x47, 0x24, 0x4A, 0x11, 0x3E, 0x93)
let IID_BINDABLE_VECTOR_VIEW = GUID(0x346DD6E7, 0x976E, 0x4BC3, 0x81, 0x5D, 0xEC, 0xE2, 0x43, 0xBC, 0x0F, 0x33)

func stockBoundsError(): WinError {
    WinError(STOCK_E_BOUNDS)
}

func stockCloneValue<T>(value: T): T where T <: WinrtGenericType<T> {
    T.cloneWinrtValue(value)
}

func snapshotList<T>(source: Iterable<T>): ArrayList<T> where T <: WinrtGenericType<T> {
    let values = collectArrayList<T>(source)
    let result = ArrayList<T>()
    var completed = false
    try {
        for (value in values) {
            result.add(stockCloneValue<T>(value))
        }
        completed = true
    } finally {
        if (!completed) {
            closeStockList<T>(result)
        }
    }
    result
}

func stockClonePair<K, V>(key: K, value: V): (K, V)
where K <: WinrtGenericType<K>, V <: WinrtGenericType<V> {
    let keyClone = stockCloneValue<K>(key)
    try {
        let valueClone = stockCloneValue<V>(value)
        return (keyClone, valueClone)
    } catch (e: Exception) {
        closeStockValue<K>(keyClone)
        throw e
    }
}

func snapshotPairList<K, V>(source: Iterable<(K, V)>): ArrayList<(K, V)>
where K <: WinrtGenericType<K>, V <: WinrtGenericType<V> {
    let result = ArrayList<(K, V)>()
    var completed = false
    try {
        for ((key, value) in source) {
            result.add(stockClonePair<K, V>(key, value))
        }
        completed = true
    } finally {
        if (!completed) {
            closeStockPairList<K, V>(result)
        }
    }
    result
}

func closeStockValue<T>(value: T): Unit {
    match (value) {
        case resource: Resource =>
            resource.close()
        case _ => ()
    }
}

func closeStockList<T>(items: ArrayList<T>): Unit {
    for (value in items) {
        closeStockValue<T>(value)
    }
}

func closeStockPairList<K, V>(items: ArrayList<(K, V)>): Unit {
    for ((key, value) in items) {
        closeStockValue<K>(key)
        closeStockValue<V>(value)
    }
}

func bindableObjectOutParameter(name: String): InterfaceParameterSchema {
    InterfaceParameterSchema(name, "CPointer<CPointer<Unit>>", "Object", InterfaceParameterBridgeKind.OutSlot)
}

func bindableObjectInParameter(name: String): InterfaceParameterSchema {
    InterfaceParameterSchema(name, "CPointer<Unit>", "Object", InterfaceParameterBridgeKind.Value)
}

func bindableUInt32OutParameter(name: String): InterfaceParameterSchema {
    InterfaceParameterSchema(name, "CPointer<UInt32>", "UInt32", InterfaceParameterBridgeKind.OutSlot)
}

func bindableBoolOutParameter(name: String): InterfaceParameterSchema {
    InterfaceParameterSchema(name, "CPointer<Bool>", "Bool", InterfaceParameterBridgeKind.OutSlot)
}

func bindableIterableDescriptorSchema(): InterfaceDescriptorSchema {
    InterfaceDescriptorSchema(
        "IBindableIterable",
        IID_BINDABLE_ITERABLE,
        windows_interface.IInspectable.descriptorSchema(),
        Array<String>(),
        Array<GUID>(),
        "IBindableIterableVtbl",
        "IBindableIterable",
        "IBindableIterable_Impl",
        [
            InterfaceMethodSchema("First", 6, [bindableObjectOutParameter("result")], "Int32")
        ]
    )
}

func bindableIteratorDescriptorSchema(): InterfaceDescriptorSchema {
    InterfaceDescriptorSchema(
        "IBindableIterator",
        IID_BINDABLE_ITERATOR,
        windows_interface.IInspectable.descriptorSchema(),
        Array<String>(),
        Array<GUID>(),
        "IBindableIteratorVtbl",
        "IBindableIterator",
        "IBindableIterator_Impl",
        [
            InterfaceMethodSchema("Current", 6, [bindableObjectOutParameter("result")], "Int32"),
            InterfaceMethodSchema("HasCurrent", 7, [bindableBoolOutParameter("result")], "Int32"),
            InterfaceMethodSchema("MoveNext", 8, [bindableBoolOutParameter("result")], "Int32"),
            InterfaceMethodSchema(
                "GetMany",
                9,
                [
                    InterfaceParameterSchema("itemsSize", "Int32", "Int32", InterfaceParameterBridgeKind.Value),
                    InterfaceParameterSchema("items", "CPointer<Unit>", "CPointer<Unit>", InterfaceParameterBridgeKind.Value),
                    bindableUInt32OutParameter("result")
                ],
                "Int32"
            )
        ]
    )
}

func bindableVectorDescriptorSchema(): InterfaceDescriptorSchema {
    InterfaceDescriptorSchema(
        "IBindableVector",
        IID_BINDABLE_VECTOR,
        windows_interface.IInspectable.descriptorSchema(),
        ["IBindableIterable"],
        [IID_BINDABLE_ITERABLE],
        "IBindableVectorVtbl",
        "IBindableVector",
        "IBindableVector_Impl",
        [
            InterfaceMethodSchema("GetAt", 6, [InterfaceParameterSchema("index", "UInt32", "UInt32", InterfaceParameterBridgeKind.Value), bindableObjectOutParameter("result")], "Int32"),
            InterfaceMethodSchema("Size", 7, [bindableUInt32OutParameter("result")], "Int32"),
            InterfaceMethodSchema("GetView", 8, [bindableObjectOutParameter("result")], "Int32"),
            InterfaceMethodSchema("IndexOf", 9, [bindableObjectInParameter("value"), bindableUInt32OutParameter("index"), bindableBoolOutParameter("result")], "Int32"),
            InterfaceMethodSchema("SetAt", 10, [InterfaceParameterSchema("index", "UInt32", "UInt32", InterfaceParameterBridgeKind.Value), bindableObjectInParameter("value")], "Int32"),
            InterfaceMethodSchema("InsertAt", 11, [InterfaceParameterSchema("index", "UInt32", "UInt32", InterfaceParameterBridgeKind.Value), bindableObjectInParameter("value")], "Int32"),
            InterfaceMethodSchema("RemoveAt", 12, [InterfaceParameterSchema("index", "UInt32", "UInt32", InterfaceParameterBridgeKind.Value)], "Int32"),
            InterfaceMethodSchema("Append", 13, [bindableObjectInParameter("value")], "Int32"),
            InterfaceMethodSchema("RemoveAtEnd", 14, Array<InterfaceParameterSchema>(), "Int32"),
            InterfaceMethodSchema("Clear", 15, Array<InterfaceParameterSchema>(), "Int32")
        ]
    )
}

func bindableVectorViewDescriptorSchema(): InterfaceDescriptorSchema {
    InterfaceDescriptorSchema(
        "IBindableVectorView",
        IID_BINDABLE_VECTOR_VIEW,
        windows_interface.IInspectable.descriptorSchema(),
        ["IBindableIterable"],
        [IID_BINDABLE_ITERABLE],
        "IBindableVectorViewVtbl",
        "IBindableVectorView",
        "IBindableVectorView_Impl",
        [
            InterfaceMethodSchema("GetAt", 6, [InterfaceParameterSchema("index", "UInt32", "UInt32", InterfaceParameterBridgeKind.Value), bindableObjectOutParameter("result")], "Int32"),
            InterfaceMethodSchema("Size", 7, [bindableUInt32OutParameter("result")], "Int32"),
            InterfaceMethodSchema("IndexOf", 8, [bindableObjectInParameter("value"), bindableUInt32OutParameter("index"), bindableBoolOutParameter("result")], "Int32")
        ]
    )
}

func clearBindableObjectOutSlot(result: CPointer<CPointer<Unit>>): Unit {
    if (result.isNotNull()) {
        unsafe { result.write(CPointer<Unit>()) }
    }
}

func clearBindableBoolOutSlot(result: CPointer<Bool>): Unit {
    if (result.isNotNull()) {
        unsafe { result.write(false) }
    }
}

func clearBindableUInt32OutSlot(result: CPointer<UInt32>): Unit {
    if (result.isNotNull()) {
        unsafe { result.write(0u32) }
    }
}

func bindableNoInterfaceObjectOut(result: CPointer<CPointer<Unit>>): Int32 {
    clearBindableObjectOutSlot(result)
    E_NOINTERFACE.value
}

func bindableNoInterfaceBoolOut(result: CPointer<Bool>): Int32 {
    clearBindableBoolOutSlot(result)
    E_NOINTERFACE.value
}

func bindableNoInterfaceUInt32Out(result: CPointer<UInt32>): Int32 {
    clearBindableUInt32OutSlot(result)
    E_NOINTERFACE.value
}

func bindableNoInterfaceIndexBoolOut(index: CPointer<UInt32>, result: CPointer<Bool>): Int32 {
    clearBindableUInt32OutSlot(index)
    clearBindableBoolOutSlot(result)
    E_NOINTERFACE.value
}

func writeBindableInspectableOut(
    result: CPointer<CPointer<Unit>>,
    valueResult: Result<windows_interface.IInspectable>
): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    clearBindableObjectOutSlot(result)
    try {
        match (valueResult) {
            case Result<windows_interface.IInspectable>.Ok(value) =>
                let raw = value.intoAbi()
                if (raw.isNull()) {
                    return E_POINTER.value
                }
                unsafe { result.write(raw) }
                S_OK.value
            case Result<windows_interface.IInspectable>.Err(error) =>
                error.code().value
        }
    } catch (_: Exception) {
        E_FAIL.value
    }
}

func writeBindableRawOut(result: CPointer<CPointer<Unit>>, valueResult: Result<CPointer<Unit>>): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    clearBindableObjectOutSlot(result)
    try {
        match (valueResult) {
            case Result<CPointer<Unit>>.Ok(raw) =>
                if (raw.isNull()) {
                    return E_POINTER.value
                }
                unsafe { result.write(raw) }
                S_OK.value
            case Result<CPointer<Unit>>.Err(error) =>
                error.code().value
        }
    } catch (_: Exception) {
        E_FAIL.value
    }
}

func writeBindableBoolOut(result: CPointer<Bool>, valueResult: Result<Bool>): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    clearBindableBoolOutSlot(result)
    try {
        match (valueResult) {
            case Result<Bool>.Ok(value) =>
                unsafe { result.write(value) }
                S_OK.value
            case Result<Bool>.Err(error) =>
                error.code().value
        }
    } catch (_: Exception) {
        E_FAIL.value
    }
}

func writeBindableUInt32Out(result: CPointer<UInt32>, valueResult: Result<UInt32>): Int32 {
    if (result.isNull()) {
        return E_POINTER.value
    }
    clearBindableUInt32OutSlot(result)
    try {
        match (valueResult) {
            case Result<UInt32>.Ok(value) =>
                unsafe { result.write(value) }
                S_OK.value
            case Result<UInt32>.Err(error) =>
                error.code().value
        }
    } catch (_: Exception) {
        E_FAIL.value
    }
}

func writeBindableUnitResult(valueResult: Result<Unit>): Int32 {
    try {
        match (valueResult) {
            case Result<Unit>.Ok(_) => S_OK.value
            case Result<Unit>.Err(error) => error.code().value
        }
    } catch (_: Exception) {
        E_FAIL.value
    }
}

func bindableInspectableFromRaw(raw: CPointer<Unit>): Result<windows_interface.IInspectable> {
    if (raw.isNull()) {
        return Result<windows_interface.IInspectable>.Err(WinError(E_POINTER))
    }
    Result<windows_interface.IInspectable>.Ok(windows_interface.IInspectable.viewOf(raw))
}

@C
public struct IBindableIterableVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var First: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ =>
        bindableNoInterfaceObjectOut(result__)
    }
    public init() {}

    public static func newForVector(): IBindableIterableVtbl {
        var vtbl = IBindableIterableVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.First = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableRawOut(result__, impl.BindableFirst())
                case None => bindableNoInterfaceObjectOut(result__)
            }
        }
        vtbl
    }

    public static func newForVectorView(): IBindableIterableVtbl {
        var vtbl = IBindableIterableVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.First = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableVectorViewImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableRawOut(result__, impl.BindableFirst())
                case None => bindableNoInterfaceObjectOut(result__)
            }
        }
        vtbl
    }
}

@C
public struct IBindableIteratorVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var Current: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ =>
        bindableNoInterfaceObjectOut(result__)
    }
    public var HasCurrent: CFunc<(CPointer<Unit>, CPointer<Bool>) -> Int32> = { _, result__ =>
        bindableNoInterfaceBoolOut(result__)
    }
    public var MoveNext: CFunc<(CPointer<Unit>, CPointer<Bool>) -> Int32> = { _, result__ =>
        bindableNoInterfaceBoolOut(result__)
    }
    public var GetMany: CFunc<(CPointer<Unit>, Int32, CPointer<Unit>, CPointer<UInt32>) -> Int32> = { _, _, _, result__ =>
        bindableNoInterfaceUInt32Out(result__)
    }
    public init() {}

    public static func new(): IBindableIteratorVtbl {
        var vtbl = IBindableIteratorVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.Current = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableBindableIteratorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableInspectableOut(result__, impl.Current())
                case None => bindableNoInterfaceObjectOut(result__)
            }
        }
        vtbl.HasCurrent = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableBindableIteratorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableBoolOut(result__, impl.HasCurrent())
                case None => bindableNoInterfaceBoolOut(result__)
            }
        }
        vtbl.MoveNext = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableBindableIteratorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableBoolOut(result__, impl.MoveNext())
                case None => bindableNoInterfaceBoolOut(result__)
            }
        }
        vtbl.GetMany = { instanceRaw, itemsSize, items, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableBindableIteratorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableUInt32Out(result__, impl.GetMany(itemsSize, items))
                case None => bindableNoInterfaceUInt32Out(result__)
            }
        }
        vtbl
    }
}

@C
public struct IBindableVectorVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var GetAt: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> = { _, _, result__ =>
        bindableNoInterfaceObjectOut(result__)
    }
    public var Size: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32> = { _, result__ =>
        bindableNoInterfaceUInt32Out(result__)
    }
    public var GetView: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ =>
        bindableNoInterfaceObjectOut(result__)
    }
    public var IndexOf: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<UInt32>, CPointer<Bool>) -> Int32> = { _, _, index__, result__ =>
        bindableNoInterfaceIndexBoolOut(index__, result__)
    }
    public var SetAt: CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var InsertAt: CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var RemoveAt: CFunc<(CPointer<Unit>, UInt32) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Append: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var RemoveAtEnd: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public var Clear: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}

    public static func new(): IBindableVectorVtbl {
        var vtbl = IBindableVectorVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.GetAt = { instanceRaw, index, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableInspectableOut(result__, impl.GetAt(index))
                case None => bindableNoInterfaceObjectOut(result__)
            }
        }
        vtbl.Size = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableUInt32Out(result__, impl.Size())
                case None => bindableNoInterfaceUInt32Out(result__)
            }
        }
        vtbl.GetView = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableRawOut(result__, impl.BindableGetView())
                case None => bindableNoInterfaceObjectOut(result__)
            }
        }
        vtbl.IndexOf = { instanceRaw, valueRaw, index__, result__ =>
            if (index__.isNull() || result__.isNull()) {
                clearBindableUInt32OutSlot(index__)
                clearBindableBoolOutSlot(result__)
                E_POINTER.value
            } else if (valueRaw.isNull()) {
                clearBindableUInt32OutSlot(index__)
                clearBindableBoolOutSlot(result__)
                S_OK.value
            } else {
                match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                    case Some(impl) =>
                        match (bindableInspectableFromRaw(valueRaw)) {
                            case Result<windows_interface.IInspectable>.Ok(value) =>
                                writeBindableBoolOut(result__, impl.IndexOf(value, index__))
                            case Result<windows_interface.IInspectable>.Err(error) =>
                                error.code().value
                        }
                    case None => bindableNoInterfaceIndexBoolOut(index__, result__)
                }
            }
        }
        vtbl.SetAt = { instanceRaw, index, valueRaw =>
            if (valueRaw.isNull()) {
                E_POINTER.value
            } else {
                match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                    case Some(impl) =>
                        match (bindableInspectableFromRaw(valueRaw)) {
                            case Result<windows_interface.IInspectable>.Ok(value) =>
                                writeBindableUnitResult(impl.SetAt(index, value))
                            case Result<windows_interface.IInspectable>.Err(error) =>
                                error.code().value
                        }
                    case None => E_NOINTERFACE.value
                }
            }
        }
        vtbl.InsertAt = { instanceRaw, index, valueRaw =>
            if (valueRaw.isNull()) {
                E_POINTER.value
            } else {
                match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                    case Some(impl) =>
                        match (bindableInspectableFromRaw(valueRaw)) {
                            case Result<windows_interface.IInspectable>.Ok(value) =>
                                writeBindableUnitResult(impl.InsertAt(index, value))
                            case Result<windows_interface.IInspectable>.Err(error) =>
                                error.code().value
                        }
                    case None => E_NOINTERFACE.value
                }
            }
        }
        vtbl.RemoveAt = { instanceRaw, index =>
            match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableUnitResult(impl.RemoveAt(index))
                case None => E_NOINTERFACE.value
            }
        }
        vtbl.Append = { instanceRaw, valueRaw =>
            if (valueRaw.isNull()) {
                E_POINTER.value
            } else {
                match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                    case Some(impl) =>
                        match (bindableInspectableFromRaw(valueRaw)) {
                            case Result<windows_interface.IInspectable>.Ok(value) =>
                                writeBindableUnitResult(impl.Append(value))
                            case Result<windows_interface.IInspectable>.Err(error) =>
                                error.code().value
                        }
                    case None => E_NOINTERFACE.value
                }
            }
        }
        vtbl.RemoveAtEnd = { instanceRaw =>
            match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableUnitResult(impl.RemoveAtEnd())
                case None => E_NOINTERFACE.value
            }
        }
        vtbl.Clear = { instanceRaw =>
            match (unsafe { asImplFromRaw<StockInspectableVectorImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableUnitResult(impl.Clear())
                case None => E_NOINTERFACE.value
            }
        }
        vtbl
    }
}

@C
public struct IBindableVectorViewVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var GetAt: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> = { _, _, result__ =>
        bindableNoInterfaceObjectOut(result__)
    }
    public var Size: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32> = { _, result__ =>
        bindableNoInterfaceUInt32Out(result__)
    }
    public var IndexOf: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<UInt32>, CPointer<Bool>) -> Int32> = { _, _, index__, result__ =>
        bindableNoInterfaceIndexBoolOut(index__, result__)
    }
    public init() {}

    public static func new(): IBindableVectorViewVtbl {
        var vtbl = IBindableVectorViewVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.GetAt = { instanceRaw, index, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableVectorViewImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableInspectableOut(result__, impl.GetAt(index))
                case None => bindableNoInterfaceObjectOut(result__)
            }
        }
        vtbl.Size = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<StockInspectableVectorViewImpl>(instanceRaw) }) {
                case Some(impl) => writeBindableUInt32Out(result__, impl.Size())
                case None => bindableNoInterfaceUInt32Out(result__)
            }
        }
        vtbl.IndexOf = { instanceRaw, valueRaw, index__, result__ =>
            if (index__.isNull() || result__.isNull()) {
                clearBindableUInt32OutSlot(index__)
                clearBindableBoolOutSlot(result__)
                E_POINTER.value
            } else if (valueRaw.isNull()) {
                clearBindableUInt32OutSlot(index__)
                clearBindableBoolOutSlot(result__)
                S_OK.value
            } else {
                match (unsafe { asImplFromRaw<StockInspectableVectorViewImpl>(instanceRaw) }) {
                    case Some(impl) =>
                        match (bindableInspectableFromRaw(valueRaw)) {
                            case Result<windows_interface.IInspectable>.Ok(value) =>
                                writeBindableBoolOut(result__, impl.IndexOf(value, index__))
                            case Result<windows_interface.IInspectable>.Err(error) =>
                                error.code().value
                        }
                    case None => bindableNoInterfaceIndexBoolOut(index__, result__)
                }
            }
        }
        vtbl
    }
}

public func createStockInterface<Inner, I>(
    inner: Inner,
    schema: InterfaceDescriptorSchema,
    descriptor: InterfaceDescriptor<I>,
    vtblPtr: CPointer<Unit>
): I where I <: ComInterface {
    let schemas = Array<InterfaceDescriptorSchema>(1, { _ => schema })
    let object = createComObjectFromSchemas(inner, schemas, vtblPtr)
    try {
        object.toInterface(descriptor)
    } finally {
        object.close()
    }
}

// Multi-schema variant: register N schemas and N vtbls (one per schema, in matching order).
// Each schema's resolved slotIndex maps to vtbls[index] (slot 1 -> vtbls[0], slot 2 -> vtbls[1]).
// Used for stock objects that expose required-ancestor interfaces (e.g. IVectorView<T> expects
// QueryInterface(IID_IIterable<T>) to return an independent IIterable vtbl).
public func createStockInterfaceMulti<Inner, I>(
    inner: Inner,
    schemas: Array<InterfaceDescriptorSchema>,
    descriptor: InterfaceDescriptor<I>,
    vtblPtrs: Array<CPointer<Unit>>
): I where I <: ComInterface {
    let object = createComObjectFromSchemas(inner, schemas, vtblPtrs)
    try {
        object.toInterface(descriptor)
    } finally {
        object.close()
    }
}

func createStockIterator<T>(source: Iterable<T>): IIterator<T> where T <: RuntimeType & WinrtGenericType<T> {
    let items = snapshotList<T>(source)
    let impl = StockIteratorImpl<T>(items)
    createStockInterface<StockIteratorImpl<T>, IIterator<T>>(
        impl,
        IIterator<T>.descriptorSchema(),
        IIterator<T>.descriptor(),
        impl.vtblPtr()
    )
}

func createStockIteratorFromOwnedList<T>(items: ArrayList<T>): IIterator<T>
where T <: RuntimeType & WinrtGenericType<T> {
    try {
        createStockIterator<T>(items)
    } finally {
        closeStockList<T>(items)
    }
}

func createStockKeyValuePair<K, V>(key: K, value: V): IKeyValuePair<K, V>
where K <: RuntimeType & WinrtGenericType<K>, V <: RuntimeType & WinrtGenericType<V> {
    let (keyClone, valueClone) = stockClonePair<K, V>(key, value)
    let impl = StockKeyValuePairImpl<K, V>(keyClone, valueClone)
    createStockInterface<StockKeyValuePairImpl<K, V>, IKeyValuePair<K, V>>(
        impl,
        IKeyValuePair<K, V>.descriptorSchema(),
        IKeyValuePair<K, V>.descriptor(),
        impl.vtblPtr()
    )
}

func materializePairViews<K, V>(entries: ArrayList<(K, V)>): ArrayList<IKeyValuePair<K, V>>
where K <: RuntimeType & WinrtGenericType<K>, V <: RuntimeType & WinrtGenericType<V> {
    let result = ArrayList<IKeyValuePair<K, V>>()
    var completed = false
    try {
        for ((key, value) in entries) {
            result.add(createStockKeyValuePair<K, V>(key, value))
        }
        completed = true
    } finally {
        if (!completed) {
            closeStockList<IKeyValuePair<K, V>>(result)
        }
    }
    result
}

func writeIndexSlot(indexSlot: CPointer<UInt32>, value: UInt32): Unit {
    if (indexSlot.isNotNull()) {
        unsafe { indexSlot.write(value) }
    }
}

/// Write up to `min(itemsSize, source.size - startIndex)` elements from `source`
/// starting at `source[startIndex]` into the ABI buffer `items`.
/// Returns the number of elements actually written. Matches the WinRT
/// IIterator::GetMany / IVectorView::GetMany batch semantics.
func writeGenericManyRange<T>(
    itemsSize: UInt32,
    items: CPointer<Unit>,
    source: ArrayList<T>,
    startIndex: Int64
): Result<UInt32>
where T <: RuntimeType & WinrtGenericType<T> {
    if (itemsSize == 0u32) {
        return Result<UInt32>.Ok(0u32)
    }
    if (items.isNull()) {
        return Result<UInt32>.Err(WinError(E_POINTER))
    }
    if (startIndex < 0 || startIndex >= source.size) {
        return Result<UInt32>.Ok(0u32)
    }
    let remaining = source.size - startIndex
    let capacity = Int64(itemsSize)
    let actual = if (remaining < capacity) { remaining } else { capacity }
    var written = 0
    while (written < actual) {
        match (source.get(startIndex + written)) {
            case Some(value) =>
                let hr = HRESULT(winrtStoreGenericOutAt<T>(items, written, value))
                if (hr.failed()) {
                    if (written > 0) {
                        try {
                            winrtReleaseGenericOutRange<T>(items, UInt32(written))
                        } catch (_: Exception) {
                            ()
                        }
                    }
                    return Result<UInt32>.Err(WinError(hr))
                }
            case None =>
                break
        }
        written += 1
    }
    Result<UInt32>.Ok(UInt32(written))
}

public class StockIteratorImpl<T> <: IIterator_Impl<T> & Resource where T <: RuntimeType & WinrtGenericType<T> {
    private let items: ArrayList<T>
    private let vtblHandle: CPointer<IIteratorVtbl>
    private var closed: Bool = false
    private let index = AtomicInt64(0)

    public init(items: ArrayList<T>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIteratorVtbl>(IIteratorVtbl.new<StockIteratorImpl<T>, T>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeStockList<T>(items)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func Current(): Result<T> {
        let current = index.load()
        if (current < 0 || current >= items.size) {
            return Result<T>.Err(stockBoundsError())
        }
        match (items.get(current)) {
            case Some(value) => Result<T>.Ok(value)
            case None => Result<T>.Err(stockBoundsError())
        }
    }

    public func HasCurrent(): Result<Bool> {
        let current = index.load()
        Result<Bool>.Ok(current >= 0 && current < items.size)
    }

    public func MoveNext(): Result<Bool> {
        let current = index.load()
        if (current < items.size) {
            index.fetchAdd(1)
        }
        Result<Bool>.Ok(current + 1 < items.size)
    }

    public func GetMany(itemsSize: UInt32, items: CPointer<Unit>): Result<UInt32> {
        // IIterator::GetMany contract: copy up to `itemsSize` elements starting
        // from the current cursor, advance by the number written, and return that count.
        let current = index.load()
        match (writeGenericManyRange<T>(itemsSize, items, this.items, current)) {
            case Result<UInt32>.Ok(count) =>
                index.fetchAdd(Int64(count))
                Result<UInt32>.Ok(count)
            case Result<UInt32>.Err(error) =>
                Result<UInt32>.Err(error)
        }
    }
}

public class StockIterableImpl<T> <: IIterable_Impl<T> & Resource where T <: RuntimeType & WinrtGenericType<T> {
    private let items: ArrayList<T>
    private let vtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<T>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockIterableImpl<T>, T>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeStockList<T>(items)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func First(): Result<IIterator<T>> {
        Result<IIterator<T>>.Ok(createStockIterator<T>(items))
    }
}

public class StockVectorViewImpl<T> <: IVectorView_Impl<T> & Resource
where T <: RuntimeType & WinrtGenericType<T> & Equatable<T> {
    private let items: ArrayList<T>
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<T>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.new<StockVectorViewImpl<T>, T>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockVectorViewImpl<T>, T>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeStockList<T>(items)
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func First(): Result<IIterator<T>> {
        Result<IIterator<T>>.Ok(createStockIterator<T>(items))
    }

    public func GetAt(index: UInt32): Result<T> {
        let resolvedIndex = Int64(index)
        if (resolvedIndex < 0 || resolvedIndex >= items.size) {
            return Result<T>.Err(stockBoundsError())
        }
        match (items.get(resolvedIndex)) {
            case Some(value) => Result<T>.Ok(value)
            case None => Result<T>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: T, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (candidate == value) {
                        writeIndexSlot(indexSlot, UInt32(offset))
                        return Result<Bool>.Ok(true)
                    }
                case None => ()
            }
            offset += 1
        }
        // WinRT IVectorView::IndexOf contract: when value is not present,
        // out-param `index` MUST be 0.
        writeIndexSlot(indexSlot, 0u32)
        Result<Bool>.Ok(false)
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        // IVectorView::GetMany: copy up to `itemsSize` elements starting at
        // `startIndex`. The view does not have a cursor so nothing advances.
        writeGenericManyRange<T>(itemsSize, itemsBuffer, this.items, Int64(startIndex))
    }
}

public class StockInt32VectorViewImpl <: IVectorView_Impl<Int32> & Resource {
    private let items: ArrayList<Int32>
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<Int32>) {
        this.items = items
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.newInt32<StockInt32VectorViewImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockInt32VectorViewImpl, Int32>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func First(): Result<IIterator<Int32>> {
        Result<IIterator<Int32>>.Ok(createStockIterator<Int32>(items))
    }

    public func GetAt(index: UInt32): Result<Int32> {
        let resolvedIndex = Int64(index)
        if (resolvedIndex < 0 || resolvedIndex >= items.size) {
            return Result<Int32>.Err(stockBoundsError())
        }
        match (items.get(resolvedIndex)) {
            case Some(value) => Result<Int32>.Ok(value)
            case None => Result<Int32>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: Int32, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (candidate == value) {
                        writeIndexSlot(indexSlot, UInt32(offset))
                        return Result<Bool>.Ok(true)
                    }
                case None => ()
            }
            offset += 1
        }
        writeIndexSlot(indexSlot, 0u32)
        Result<Bool>.Ok(false)
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<Int32>(itemsSize, itemsBuffer, this.items, Int64(startIndex))
    }
}

public class StockKeyValuePairImpl<K, V> <: IKeyValuePair_Impl<K, V> & Resource
where K <: RuntimeType & WinrtGenericType<K>, V <: RuntimeType & WinrtGenericType<V> {
    private let key_: K
    private let value_: V
    private let vtblHandle: CPointer<IKeyValuePairVtbl>
    private var closed: Bool = false

    public init(key: K, value: V) {
        this.key_ = key
        this.value_ = value
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IKeyValuePairVtbl>(IKeyValuePairVtbl.new<StockKeyValuePairImpl<K, V>, K, V>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeStockValue<K>(key_)
        closeStockValue<V>(value_)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func Key(): Result<K> {
        Result<K>.Ok(key_)
    }

    public func Value(): Result<V> {
        Result<V>.Ok(value_)
    }
}

public class StockMapViewImpl<K, V> <: IMapView_Impl<K, V> & Resource
where K <: RuntimeType & HandleWinrtType<K> & Equatable<K>, V <: RuntimeType & WinrtGenericType<V> {
    private let entries: ArrayList<(K, V)>
    private let pairViews: ArrayList<IKeyValuePair<K, V>>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(K, V)>) {
        this.entries = entries
        this.pairViews = materializePairViews<K, V>(entries)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.new<StockMapViewImpl<K, V>, K, V>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockMapViewImpl<K, V>, IKeyValuePair<K, V>>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeStockPairList<K, V>(entries)
        closeStockList<IKeyValuePair<K, V>>(pairViews)
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func First(): Result<IIterator<IKeyValuePair<K, V>>> {
        Result<IIterator<IKeyValuePair<K, V>>>.Ok(
            createStockIterator<IKeyValuePair<K, V>>(pairViews)
        )
    }

    public func Lookup(key: K): Result<V> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<V>.Ok(candidateValue)
            }
        }
        Result<V>.Err(stockBoundsError())
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: K): Result<Bool> {
        for ((candidateKey, _) in entries) {
            if (candidateKey == key) {
                return Result<Bool>.Ok(true)
            }
        }
        Result<Bool>.Ok(false)
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        if (first.isNotNull()) {
            unsafe { first.write(CPointer<Unit>()) }
        }
        if (second.isNotNull()) {
            unsafe { second.write(CPointer<Unit>()) }
        }
        Result<Unit>.Ok(())
    }
}

func sameInspectableVectorElement(left: windows_interface.IInspectable, right: windows_interface.IInspectable): Bool {
    left.asRaw().toUIntNative() == right.asRaw().toUIntNative()
}

func retainInspectableVectorElement(value: windows_interface.IInspectable): Result<windows_interface.IInspectable> {
    let raw = value.retainRaw()
    if (raw.isNull()) {
        return Result<windows_interface.IInspectable>.Err(WinError(E_POINTER))
    }
    Result<windows_interface.IInspectable>.Ok(windows_interface.IInspectable.fromAbiTake(raw))
}

func mustRetainInspectableVectorElement(value: windows_interface.IInspectable): windows_interface.IInspectable {
    match (retainInspectableVectorElement(value)) {
        case Result<windows_interface.IInspectable>.Ok(retained) => retained
        case Result<windows_interface.IInspectable>.Err(_) => throw Exception("expected live IInspectable")
    }
}

func closeInspectableVectorElements(values: ArrayList<windows_interface.IInspectable>): Unit {
    var offset = 0
    while (offset < values.size) {
        match (values.get(offset)) {
            case Some(value) => value.close()
            case None => ()
        }
        offset += 1
    }
    values.clear()
}

class StockInspectableBindableIteratorImpl <: Resource {
    private let items: ArrayList<windows_interface.IInspectable>
    private let vtblHandle: CPointer<IBindableIteratorVtbl>
    private var closed: Bool = false
    private let index = AtomicInt64(0)

    public init(seed: ArrayList<windows_interface.IInspectable>) {
        this.items = ArrayList<windows_interface.IInspectable>(seed.size, { offset => mustRetainInspectableVectorElement(seed[offset]) })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IBindableIteratorVtbl>(IBindableIteratorVtbl.new())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeInspectableVectorElements(items)
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func Current(): Result<windows_interface.IInspectable> {
        let current = index.load()
        if (current < 0 || current >= items.size) {
            return Result<windows_interface.IInspectable>.Err(stockBoundsError())
        }
        match (items.get(current)) {
            case Some(value) => retainInspectableVectorElement(value)
            case None => Result<windows_interface.IInspectable>.Err(stockBoundsError())
        }
    }

    public func HasCurrent(): Result<Bool> {
        let current = index.load()
        Result<Bool>.Ok(current >= 0 && current < items.size)
    }

    public func MoveNext(): Result<Bool> {
        let current = index.load()
        if (current < items.size) {
            index.fetchAdd(1)
        }
        Result<Bool>.Ok(current + 1 < items.size)
    }

    public func GetMany(itemsSize: Int32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        if (itemsSize <= 0) {
            return Result<UInt32>.Ok(0u32)
        }
        let current = index.load()
        match (writeGenericManyRange<windows_interface.IInspectable>(UInt32(itemsSize), itemsBuffer, items, current)) {
            case Result<UInt32>.Ok(count) =>
                index.fetchAdd(Int64(count))
                Result<UInt32>.Ok(count)
            case Result<UInt32>.Err(error) =>
                Result<UInt32>.Err(error)
        }
    }
}

func createStockInspectableBindableIteratorRaw(source: Iterable<windows_interface.IInspectable>): Result<CPointer<Unit>> {
    let items = collectArrayList<windows_interface.IInspectable>(source)
    let impl = StockInspectableBindableIteratorImpl(items)
    let object = createComObjectFromSchemas(impl, [bindableIteratorDescriptorSchema()], impl.vtblPtr())
    var raw = CPointer<Unit>()
    let hr = HRESULT(object.queryInterfaceBase(IID_BINDABLE_ITERATOR, CPointer<CPointer<Unit>>(inout raw)))
    object.close()
    if (hr.failed()) {
        return Result<CPointer<Unit>>.Err(WinError(hr))
    }
    if (raw.isNull()) {
        return Result<CPointer<Unit>>.Err(WinError(E_POINTER))
    }
    Result<CPointer<Unit>>.Ok(raw)
}

class StockInspectableVectorViewImpl <: IVectorView_Impl<windows_interface.IInspectable> & Resource {
    private let items: ArrayList<windows_interface.IInspectable>
    private let vtblHandle: CPointer<IVectorViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private let bindableIterableVtblHandle: CPointer<IBindableIterableVtbl>
    private let bindableVectorViewVtblHandle: CPointer<IBindableVectorViewVtbl>
    private var closed: Bool = false

    public init(seed: ArrayList<windows_interface.IInspectable>) {
        this.items = ArrayList<windows_interface.IInspectable>(seed.size, { index => mustRetainInspectableVectorElement(seed[index]) })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorViewVtbl>(IVectorViewVtbl.new<StockInspectableVectorViewImpl, windows_interface.IInspectable>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockInspectableVectorViewImpl, windows_interface.IInspectable>())
        }
        this.bindableIterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IBindableIterableVtbl>(IBindableIterableVtbl.newForVectorView())
        }
        this.bindableVectorViewVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IBindableVectorViewVtbl>(IBindableVectorViewVtbl.new())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    public func bindableIterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(bindableIterableVtblHandle)
    }

    public func bindableVectorViewVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(bindableVectorViewVtblHandle)
    }

    private func drainItems(): Unit {
        closeInspectableVectorElements(items)
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        drainItems()
        unsafe {
            windows_interface.freeNativeValue(bindableVectorViewVtblHandle)
            windows_interface.freeNativeValue(bindableIterableVtblHandle)
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func First(): Result<IIterator<windows_interface.IInspectable>> {
        Result<IIterator<windows_interface.IInspectable>>.Ok(toIterator<windows_interface.IInspectable>(items))
    }

    public func BindableFirst(): Result<CPointer<Unit>> {
        createStockInspectableBindableIteratorRaw(items)
    }

    public func GetAt(index: UInt32): Result<windows_interface.IInspectable> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<windows_interface.IInspectable>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => retainInspectableVectorElement(value)
            case None => Result<windows_interface.IInspectable>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func IndexOf(value: windows_interface.IInspectable, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (sameInspectableVectorElement(candidate, value)) {
                        if (indexSlot.isNotNull()) {
                            unsafe { indexSlot.write(UInt32(offset)) }
                        }
                        return Result<Bool>.Ok(true)
                    }
                case None => ()
            }
            offset += 1
        }
        if (indexSlot.isNotNull()) {
            unsafe { indexSlot.write(0u32) }
        }
        Result<Bool>.Ok(false)
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<windows_interface.IInspectable>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }
}

func createStockInspectableVectorView(source: Iterable<windows_interface.IInspectable>): IVectorView<windows_interface.IInspectable> {
    let items = collectArrayList<windows_interface.IInspectable>(source)
    let impl = StockInspectableVectorViewImpl(items)
    let schemas = [
        IIterable<windows_interface.IInspectable>.descriptorSchema(),
        IVectorView<windows_interface.IInspectable>.descriptorSchema(),
        bindableIterableDescriptorSchema(),
        bindableVectorViewDescriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr(), impl.bindableIterableVtblPtr(), impl.bindableVectorViewVtblPtr()]
    createStockInterfaceMulti<StockInspectableVectorViewImpl, IVectorView<windows_interface.IInspectable>>(
        impl,
        schemas,
        IVectorView<windows_interface.IInspectable>.descriptor(),
        vtbls
    )
}

func createStockInspectableBindableVectorViewRaw(source: Iterable<windows_interface.IInspectable>): Result<CPointer<Unit>> {
    let items = collectArrayList<windows_interface.IInspectable>(source)
    let impl = StockInspectableVectorViewImpl(items)
    let schemas = [
        IIterable<windows_interface.IInspectable>.descriptorSchema(),
        IVectorView<windows_interface.IInspectable>.descriptorSchema(),
        bindableIterableDescriptorSchema(),
        bindableVectorViewDescriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr(), impl.bindableIterableVtblPtr(), impl.bindableVectorViewVtblPtr()]
    let object = createComObjectFromSchemas(impl, schemas, vtbls)
    var raw = CPointer<Unit>()
    let hr = HRESULT(object.queryInterfaceBase(IID_BINDABLE_VECTOR_VIEW, CPointer<CPointer<Unit>>(inout raw)))
    object.close()
    if (hr.failed()) {
        return Result<CPointer<Unit>>.Err(WinError(hr))
    }
    if (raw.isNull()) {
        return Result<CPointer<Unit>>.Err(WinError(E_POINTER))
    }
    Result<CPointer<Unit>>.Ok(raw)
}

public class StockInspectableVectorImpl <: IVector_Impl<windows_interface.IInspectable> & Resource {
    private let items: ArrayList<windows_interface.IInspectable>
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private let bindableIterableVtblHandle: CPointer<IBindableIterableVtbl>
    private let bindableVectorVtblHandle: CPointer<IBindableVectorVtbl>
    private var closed: Bool = false

    public init(seed: ArrayList<windows_interface.IInspectable>) {
        this.items = ArrayList<windows_interface.IInspectable>(seed.size, { index => mustRetainInspectableVectorElement(seed[index]) })
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.new<StockInspectableVectorImpl, windows_interface.IInspectable>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockInspectableVectorImpl, windows_interface.IInspectable>())
        }
        this.bindableIterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IBindableIterableVtbl>(IBindableIterableVtbl.newForVector())
        }
        this.bindableVectorVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IBindableVectorVtbl>(IBindableVectorVtbl.new())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    public func bindableIterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(bindableIterableVtblHandle)
    }

    public func bindableVectorVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(bindableVectorVtblHandle)
    }

    private func drainItems(): Unit {
        closeInspectableVectorElements(items)
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        drainItems()
        unsafe {
            windows_interface.freeNativeValue(bindableVectorVtblHandle)
            windows_interface.freeNativeValue(bindableIterableVtblHandle)
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func First(): Result<IIterator<windows_interface.IInspectable>> {
        Result<IIterator<windows_interface.IInspectable>>.Ok(toIterator<windows_interface.IInspectable>(items))
    }

    public func BindableFirst(): Result<CPointer<Unit>> {
        createStockInspectableBindableIteratorRaw(items)
    }

    public func GetAt(index: UInt32): Result<windows_interface.IInspectable> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<windows_interface.IInspectable>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(value) => retainInspectableVectorElement(value)
            case None => Result<windows_interface.IInspectable>.Err(stockBoundsError())
        }
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(items.size))
    }

    public func GetView(): Result<IVectorView<windows_interface.IInspectable>> {
        Result<IVectorView<windows_interface.IInspectable>>.Ok(createStockInspectableVectorView(items))
    }

    public func BindableGetView(): Result<CPointer<Unit>> {
        createStockInspectableBindableVectorViewRaw(items)
    }

    public func IndexOf(value: windows_interface.IInspectable, indexSlot: CPointer<UInt32>): Result<Bool> {
        var offset = 0
        while (offset < items.size) {
            match (items.get(offset)) {
                case Some(candidate) =>
                    if (sameInspectableVectorElement(candidate, value)) {
                        if (indexSlot.isNotNull()) {
                            unsafe { indexSlot.write(UInt32(offset)) }
                        }
                        return Result<Bool>.Ok(true)
                    }
                case None => ()
            }
            offset += 1
        }
        if (indexSlot.isNotNull()) {
            unsafe { indexSlot.write(0u32) }
        }
        Result<Bool>.Ok(false)
    }

    public func SetAt(index: UInt32, value: windows_interface.IInspectable): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        match (retainInspectableVectorElement(value)) {
            case Result<windows_interface.IInspectable>.Ok(retained) =>
                match (items.get(resolved)) {
                    case Some(previous) => previous.close()
                    case None => ()
                }
                items[resolved] = retained
                Result<Unit>.Ok(())
            case Result<windows_interface.IInspectable>.Err(error) =>
                Result<Unit>.Err(error)
        }
    }

    public func InsertAt(index: UInt32, value: windows_interface.IInspectable): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved > items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        match (retainInspectableVectorElement(value)) {
            case Result<windows_interface.IInspectable>.Ok(retained) =>
                items.add(retained, at: resolved)
                Result<Unit>.Ok(())
            case Result<windows_interface.IInspectable>.Err(error) =>
                Result<Unit>.Err(error)
        }
    }

    public func RemoveAt(index: UInt32): Result<Unit> {
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {
            return Result<Unit>.Err(stockBoundsError())
        }
        match (items.get(resolved)) {
            case Some(previous) => previous.close()
            case None => ()
        }
        items.remove(at: resolved)
        Result<Unit>.Ok(())
    }

    public func Append(value: windows_interface.IInspectable): Result<Unit> {
        match (retainInspectableVectorElement(value)) {
            case Result<windows_interface.IInspectable>.Ok(retained) =>
                items.add(retained)
                Result<Unit>.Ok(())
            case Result<windows_interface.IInspectable>.Err(error) =>
                Result<Unit>.Err(error)
        }
    }

    public func RemoveAtEnd(): Result<Unit> {
        if (items.size == 0) {
            return Result<Unit>.Err(stockBoundsError())
        }
        match (items.get(items.size - 1)) {
            case Some(previous) => previous.close()
            case None => ()
        }
        items.remove(at: items.size - 1)
        Result<Unit>.Ok(())
    }

    public func Clear(): Result<Unit> {
        drainItems()
        Result<Unit>.Ok(())
    }

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {
        writeGenericManyRange<windows_interface.IInspectable>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {
            return Result<Unit>.Err(WinError(E_POINTER))
        }
        let replacements = ArrayList<windows_interface.IInspectable>()
        var completed = false
        try {
            let slots = CPointer<CPointer<Unit>>(itemsBuffer)
            var index = 0
            while (index < Int64(itemsSize)) {
                let raw = unsafe { (slots + index).read() }
                let borrowed = winrtProjectGenericIn<windows_interface.IInspectable>(raw)
                match (retainInspectableVectorElement(borrowed)) {
                    case Result<windows_interface.IInspectable>.Ok(retained) =>
                        replacements.add(retained)
                    case Result<windows_interface.IInspectable>.Err(error) =>
                        return Result<Unit>.Err(error)
                }
                index += 1
            }
            completed = true
        } finally {
            if (!completed) {
                closeInspectableVectorElements(replacements)
            }
        }
        drainItems()
        for (value in replacements) {
            items.add(value)
        }
        Result<Unit>.Ok(())
    }
}

public class StockInt32MapViewImpl <: IMapView_Impl<Int32, Int32> & Resource {
    private let entries: ArrayList<(Int32, Int32)>
    private let pairViews: ArrayList<IKeyValuePair<Int32, Int32>>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, Int32)>) {
        this.entries = entries
        this.pairViews = materializePairViews<Int32, Int32>(entries)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.newInt32Int32<StockInt32MapViewImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockInt32MapViewImpl, IKeyValuePair<Int32, Int32>>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, Int32>>> {
        Result<IIterator<IKeyValuePair<Int32, Int32>>>.Ok(
            createStockIterator<IKeyValuePair<Int32, Int32>>(pairViews)
        )
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeStockPairList<Int32, Int32>(entries)
        closeStockList<IKeyValuePair<Int32, Int32>>(pairViews)
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func Lookup(key: Int32): Result<Int32> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<Int32>.Ok(candidateValue)
            }
        }
        Result<Int32>.Err(stockBoundsError())
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: Int32): Result<Bool> {
        for ((candidateKey, _) in entries) {
            if (candidateKey == key) {
                return Result<Bool>.Ok(true)
            }
        }
        Result<Bool>.Ok(false)
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        if (first.isNotNull()) {
            unsafe { first.write(CPointer<Unit>()) }
        }
        if (second.isNotNull()) {
            unsafe { second.write(CPointer<Unit>()) }
        }
        Result<Unit>.Ok(())
    }
}

public class StockInt32HStringMapViewImpl <: IMapView_Impl<Int32, HString> & Resource {
    private let entries: ArrayList<(Int32, HString)>
    private let pairViews: ArrayList<IKeyValuePair<Int32, HString>>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, HString)>) {
        this.entries = entries
        this.pairViews = materializePairViews<Int32, HString>(entries)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.newInt32HString<StockInt32HStringMapViewImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockInt32HStringMapViewImpl, IKeyValuePair<Int32, HString>>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, HString>>> {
        Result<IIterator<IKeyValuePair<Int32, HString>>>.Ok(
            createStockIterator<IKeyValuePair<Int32, HString>>(pairViews)
        )
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeStockPairList<Int32, HString>(entries)
        closeStockList<IKeyValuePair<Int32, HString>>(pairViews)
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func Lookup(key: Int32): Result<HString> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<HString>.Ok(candidateValue)
            }
        }
        Result<HString>.Err(stockBoundsError())
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: Int32): Result<Bool> {
        for ((candidateKey, _) in entries) {
            if (candidateKey == key) {
                return Result<Bool>.Ok(true)
            }
        }
        Result<Bool>.Ok(false)
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        if (first.isNotNull()) {
            unsafe { first.write(CPointer<Unit>()) }
        }
        if (second.isNotNull()) {
            unsafe { second.write(CPointer<Unit>()) }
        }
        Result<Unit>.Ok(())
    }
}

public class StockInt32UInt64MapViewImpl <: IMapView_Impl<Int32, UInt64> & Resource {
    private let entries: ArrayList<(Int32, UInt64)>
    private let pairViews: ArrayList<IKeyValuePair<Int32, UInt64>>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, UInt64)>) {
        this.entries = entries
        this.pairViews = materializePairViews<Int32, UInt64>(entries)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.newInt32UInt64<StockInt32UInt64MapViewImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockInt32UInt64MapViewImpl, IKeyValuePair<Int32, UInt64>>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, UInt64>>> {
        Result<IIterator<IKeyValuePair<Int32, UInt64>>>.Ok(
            createStockIterator<IKeyValuePair<Int32, UInt64>>(pairViews)
        )
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeStockPairList<Int32, UInt64>(entries)
        closeStockList<IKeyValuePair<Int32, UInt64>>(pairViews)
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func Lookup(key: Int32): Result<UInt64> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<UInt64>.Ok(candidateValue)
            }
        }
        Result<UInt64>.Err(stockBoundsError())
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: Int32): Result<Bool> {
        for ((candidateKey, _) in entries) {
            if (candidateKey == key) {
                return Result<Bool>.Ok(true)
            }
        }
        Result<Bool>.Ok(false)
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        if (first.isNotNull()) {
            unsafe { first.write(CPointer<Unit>()) }
        }
        if (second.isNotNull()) {
            unsafe { second.write(CPointer<Unit>()) }
        }
        Result<Unit>.Ok(())
    }
}

public class StockInt32VectorViewInt32MapViewImpl <: IMapView_Impl<Int32, IVectorView<Int32>> & Resource {
    private let entries: ArrayList<(Int32, IVectorView<Int32>)>
    private let pairViews: ArrayList<IKeyValuePair<Int32, IVectorView<Int32>>>
    private let vtblHandle: CPointer<IMapViewVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(entries: ArrayList<(Int32, IVectorView<Int32>)>) {
        this.entries = entries
        this.pairViews = materializePairViews<Int32, IVectorView<Int32>>(entries)
        this.vtblHandle = unsafe {
            windows_interface.allocateNativeValue<IMapViewVtbl>(IMapViewVtbl.newInt32VectorViewInt32<StockInt32VectorViewInt32MapViewImpl>())
        }
        this.iterableVtblHandle = unsafe {
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<StockInt32VectorViewInt32MapViewImpl, IKeyValuePair<Int32, IVectorView<Int32>>>())
        }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func iterableVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(iterableVtblHandle)
    }

    public func First(): Result<IIterator<IKeyValuePair<Int32, IVectorView<Int32>>>> {
        Result<IIterator<IKeyValuePair<Int32, IVectorView<Int32>>>>.Ok(
            createStockIterator<IKeyValuePair<Int32, IVectorView<Int32>>>(pairViews)
        )
    }

    ~init() {
        if (closed) {
            return
        }
        closed = true
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closeStockPairList<Int32, IVectorView<Int32>>(entries)
        closeStockList<IKeyValuePair<Int32, IVectorView<Int32>>>(pairViews)
        unsafe {
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }
        closed = true
    }

    public func Lookup(key: Int32): Result<IVectorView<Int32>> {
        for ((candidateKey, candidateValue) in entries) {
            if (candidateKey == key) {
                return Result<IVectorView<Int32>>.Ok(candidateValue)
            }
        }
        Result<IVectorView<Int32>>.Err(stockBoundsError())
    }

    public func Size(): Result<UInt32> {
        Result<UInt32>.Ok(UInt32(entries.size))
    }

    public func HasKey(key: Int32): Result<Bool> {
        for ((candidateKey, _) in entries) {
            if (candidateKey == key) {
                return Result<Bool>.Ok(true)
            }
        }
        Result<Bool>.Ok(false)
    }

    public func Split(first: CPointer<CPointer<Unit>>, second: CPointer<CPointer<Unit>>): Result<Unit> {
        if (first.isNotNull()) {
            unsafe { first.write(CPointer<Unit>()) }
        }
        if (second.isNotNull()) {
            unsafe { second.write(CPointer<Unit>()) }
        }
        Result<Unit>.Ok(())
    }
}

public func toIterator<T>(source: Iterable<T>): IIterator<T> where T <: RuntimeType & WinrtGenericType<T> {
    createStockIterator<T>(source)
}

public func toIterable<T>(source: Iterable<T>): IIterable<T> where T <: RuntimeType & WinrtGenericType<T> {
    let items = snapshotList<T>(source)
    let impl = StockIterableImpl<T>(items)
    createStockInterface<StockIterableImpl<T>, IIterable<T>>(
        impl,
        IIterable<T>.descriptorSchema(),
        IIterable<T>.descriptor(),
        impl.vtblPtr()
    )
}

public func toVectorView<T>(source: Iterable<T>): IVectorView<T>
where T <: RuntimeType & HandleWinrtType<T> & Equatable<T> {
    let items = snapshotList<T>(source)
    let impl = StockVectorViewImpl<T>(items)
    // Register the IIterable<T> required-ancestor surface alongside IVectorView<T> so QI for
    // IID_IIterable<T> returns its own independent vtbl (slot 1) rather than the IVectorView vtbl
    // (slot 2). Each schema's slot index matches its position in the schemas array.
    let schemas = [IIterable<T>.descriptorSchema(), IVectorView<T>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    createStockInterfaceMulti<StockVectorViewImpl<T>, IVectorView<T>>(
        impl,
        schemas,
        IVectorView<T>.descriptor(),
        vtbls
    )
}

public func toVectorView(source: Iterable<Int32>): IVectorView<Int32> {
    let items = snapshotList<Int32>(source)
    let impl = StockInt32VectorViewImpl(items)
    let schemas = [IIterable<Int32>.descriptorSchema(), IVectorView<Int32>.descriptorSchema()]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    createStockInterfaceMulti<StockInt32VectorViewImpl, IVectorView<Int32>>(
        impl,
        schemas,
        IVectorView<Int32>.descriptor(),
        vtbls
    )
}

public func toInspectableVector(source: Iterable<windows_interface.IInspectable>): IVector<windows_interface.IInspectable> {
    let items = collectArrayList<windows_interface.IInspectable>(source)
    let impl = StockInspectableVectorImpl(items)
    let schemas = [
        IIterable<windows_interface.IInspectable>.descriptorSchema(),
        IVector<windows_interface.IInspectable>.descriptorSchema(),
        bindableIterableDescriptorSchema(),
        bindableVectorDescriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr(), impl.bindableIterableVtblPtr(), impl.bindableVectorVtblPtr()]
    createStockInterfaceMulti<StockInspectableVectorImpl, IVector<windows_interface.IInspectable>>(
        impl,
        schemas,
        IVector<windows_interface.IInspectable>.descriptor(),
        vtbls
    )
}

public func toKeyValuePair<K, V>(key: K, value: V): IKeyValuePair<K, V>
where K <: RuntimeType & WinrtGenericType<K>, V <: RuntimeType & WinrtGenericType<V> {
    createStockKeyValuePair<K, V>(key, value)
}

public func toMapView<K, V>(source: Iterable<(K, V)>): IMapView<K, V>
where K <: RuntimeType & HandleWinrtType<K> & Equatable<K>, V <: RuntimeType & WinrtGenericType<V> {
    let entries = snapshotPairList<K, V>(source)
    let impl = StockMapViewImpl<K, V>(entries)
    // Register IIterable<IKeyValuePair<K, V>> as an independent slot so QI to the iterable
    // ancestor returns a distinct vtbl from the IMapView vtbl.
    let schemas = [
        IIterable<IKeyValuePair<K, V>>.descriptorSchema(),
        IMapView<K, V>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    createStockInterfaceMulti<StockMapViewImpl<K, V>, IMapView<K, V>>(
        impl,
        schemas,
        IMapView<K, V>.descriptor(),
        vtbls
    )
}

public func toMapView(source: Iterable<(Int32, Int32)>): IMapView<Int32, Int32> {
    let entries = snapshotPairList<Int32, Int32>(source)
    let impl = StockInt32MapViewImpl(entries)
    let schemas = [
        IIterable<IKeyValuePair<Int32, Int32>>.descriptorSchema(),
        IMapView<Int32, Int32>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    createStockInterfaceMulti<StockInt32MapViewImpl, IMapView<Int32, Int32>>(
        impl,
        schemas,
        IMapView<Int32, Int32>.descriptor(),
        vtbls
    )
}

public func toMapView(source: Iterable<(Int32, HString)>): IMapView<Int32, HString> {
    let entries = snapshotPairList<Int32, HString>(source)
    let impl = StockInt32HStringMapViewImpl(entries)
    let schemas = [
        IIterable<IKeyValuePair<Int32, HString>>.descriptorSchema(),
        IMapView<Int32, HString>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    createStockInterfaceMulti<StockInt32HStringMapViewImpl, IMapView<Int32, HString>>(
        impl,
        schemas,
        IMapView<Int32, HString>.descriptor(),
        vtbls
    )
}

public func toMapView(source: Iterable<(Int32, UInt64)>): IMapView<Int32, UInt64> {
    let entries = snapshotPairList<Int32, UInt64>(source)
    let impl = StockInt32UInt64MapViewImpl(entries)
    let schemas = [
        IIterable<IKeyValuePair<Int32, UInt64>>.descriptorSchema(),
        IMapView<Int32, UInt64>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    createStockInterfaceMulti<StockInt32UInt64MapViewImpl, IMapView<Int32, UInt64>>(
        impl,
        schemas,
        IMapView<Int32, UInt64>.descriptor(),
        vtbls
    )
}

public func toMapView(source: Iterable<(Int32, IVectorView<Int32>)>): IMapView<Int32, IVectorView<Int32>> {
    let entries = snapshotPairList<Int32, IVectorView<Int32>>(source)
    let impl = StockInt32VectorViewInt32MapViewImpl(entries)
    let schemas = [
        IIterable<IKeyValuePair<Int32, IVectorView<Int32>>>.descriptorSchema(),
        IMapView<Int32, IVectorView<Int32>>.descriptorSchema()
    ]
    let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
    createStockInterfaceMulti<StockInt32VectorViewInt32MapViewImpl, IMapView<Int32, IVectorView<Int32>>>(
        impl,
        schemas,
        IMapView<Int32, IVectorView<Int32>>.descriptor(),
        vtbls
    )
}
