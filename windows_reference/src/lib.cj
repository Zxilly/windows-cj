package windows_reference

import windows_core.{ComObject, DateTime, E_NOTIMPL, GuidValue, HString, Point, Rect, Result, Size, TimeSpan, WinError}
import windows_core as windows_core
import windows_foundation.{IPropertyValueVtbl, PropertyType_Boolean, PropertyType_DateTime, PropertyType_Double, PropertyType_Guid, PropertyType_Int16, PropertyType_Int32, PropertyType_Int64, PropertyType_OtherType, PropertyType_Point, PropertyType_Rect, PropertyType_Single, PropertyType_Size, PropertyType_String, PropertyType_TimeSpan, PropertyType_UInt16, PropertyType_UInt32, PropertyType_UInt64, PropertyType_UInt8}
import windows_foundation as windows_foundation
import windows_interface as windows_interface

public type IReference<T> = windows_foundation.IReference<T>
public type IReferenceVtbl = windows_foundation.IReferenceVtbl
public type IReference_Impl<T> = windows_foundation.IReference_Impl<T>
public type IPropertyValue = windows_foundation.IPropertyValue
public type IPropertyValue_Impl = windows_foundation.IPropertyValue_Impl
public type PropertyType = windows_foundation.PropertyType

func notImpl<T>(): Result<T> {
    Result<T>.Err(WinError.fromHRESULT(E_NOTIMPL))
}

func cloneGenericValue<T>(value: T): T {
    match (value) {
        case text: HString =>
            match (text.clone() as T) {
                case Some(cloned) => cloned
                case None => value
            }
        case _ => value
    }
}

func castStockValue<T, U>(value: T): Result<U> {
    match (value as U) {
        case Some(resolved) => Result<U>.Ok(cloneGenericValue<U>(resolved))
        case None => notImpl<U>()
    }
}

func stockPropertyType<T>(): PropertyType where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T> {
    let signature = T.signature()
    if (signature == UInt8.signature()) { return PropertyType_UInt8 }
    if (signature == Int16.signature()) { return PropertyType_Int16 }
    if (signature == UInt16.signature()) { return PropertyType_UInt16 }
    if (signature == Int32.signature()) { return PropertyType_Int32 }
    if (signature == UInt32.signature()) { return PropertyType_UInt32 }
    if (signature == Int64.signature()) { return PropertyType_Int64 }
    if (signature == UInt64.signature()) { return PropertyType_UInt64 }
    if (signature == Float32.signature()) { return PropertyType_Single }
    if (signature == Float64.signature()) { return PropertyType_Double }
    if (signature == Bool.signature()) { return PropertyType_Boolean }
    if (signature == HString.signature()) { return PropertyType_String }
    if (signature == GuidValue.signature()) { return PropertyType_Guid }
    if (signature == DateTime.signature()) { return PropertyType_DateTime }
    if (signature == TimeSpan.signature()) { return PropertyType_TimeSpan }
    if (signature == Point.signature()) { return PropertyType_Point }
    if (signature == Size.signature()) { return PropertyType_Size }
    if (signature == Rect.signature()) { return PropertyType_Rect }
    PropertyType_OtherType
}

private class StockReference<T> <: IReference_Impl<T> & Resource where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T> {
    private let value: T
    private let referenceVtblHandle: CPointer<IReferenceVtbl>
    private let propertyVtblHandle: CPointer<IPropertyValueVtbl>
    private var closed: Bool = false

    public init(value: T) {
        this.value = cloneGenericValue<T>(value)
        this.referenceVtblHandle = unsafe { windows_interface.allocateNativeValue<IReferenceVtbl>(IReferenceVtbl.new<StockReference<T>, T>()) }
        this.propertyVtblHandle = unsafe { windows_interface.allocateNativeValue<IPropertyValueVtbl>(IPropertyValueVtbl.new<StockReference<T>>()) }
    }

    public func referenceVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(referenceVtblHandle)
    }

    public func propertyVtblPtr(): CPointer<Unit> {
        CPointer<Unit>(propertyVtblHandle)
    }

    private func closeStoredValue(): Unit {
        match (value) {
            case text: HString => text.close()
            case _ => ()
        }
    }

    private func freeVtablesNoThrow(): Unit {
        try {
            unsafe { windows_interface.freeNativeValue(referenceVtblHandle) }
        } catch (_: Exception) {}
        try {
            unsafe { windows_interface.freeNativeValue(propertyVtblHandle) }
        } catch (_: Exception) {}
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed) {
            try {
                unsafe { windows_interface.freeNativeValue(referenceVtblHandle) }
            } catch (_: Exception) {}
            try {
                unsafe { windows_interface.freeNativeValue(propertyVtblHandle) }
            } catch (_: Exception) {}
            match (value) {
                case text: HString => text.close()
                case _ => ()
            }
            closed = true
        }
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        freeVtablesNoThrow()
        closeStoredValue()
        closed = true
    }

    public func Value(): Result<T> {
        Result<T>.Ok(cloneGenericValue<T>(value))
    }

    public func Type(): Result<PropertyType> {
        Result<PropertyType>.Ok(stockPropertyType<T>())
    }

    public func IsNumericScalar(): Result<Bool> {
        let propertyType = stockPropertyType<T>()
        Result<Bool>.Ok(
            propertyType == PropertyType_UInt8 ||
            propertyType == PropertyType_Int16 ||
            propertyType == PropertyType_UInt16 ||
            propertyType == PropertyType_Int32 ||
            propertyType == PropertyType_UInt32 ||
            propertyType == PropertyType_Int64 ||
            propertyType == PropertyType_UInt64 ||
            propertyType == PropertyType_Single ||
            propertyType == PropertyType_Double
        )
    }

    public func GetUInt8(): Result<UInt8> { castStockValue<T, UInt8>(value) }
    public func GetInt16(): Result<Int16> { castStockValue<T, Int16>(value) }
    public func GetUInt16(): Result<UInt16> { castStockValue<T, UInt16>(value) }
    public func GetInt32(): Result<Int32> { castStockValue<T, Int32>(value) }
    public func GetUInt32(): Result<UInt32> { castStockValue<T, UInt32>(value) }
    public func GetInt64(): Result<Int64> { castStockValue<T, Int64>(value) }
    public func GetUInt64(): Result<UInt64> { castStockValue<T, UInt64>(value) }
    public func GetSingle(): Result<Float32> { castStockValue<T, Float32>(value) }
    public func GetDouble(): Result<Float64> { castStockValue<T, Float64>(value) }
    public func GetChar16(): Result<UInt16> { castStockValue<T, UInt16>(value) }
    public func GetBoolean(): Result<Bool> { castStockValue<T, Bool>(value) }
    public func GetString(): Result<HString> { castStockValue<T, HString>(value) }
    public func GetGuid(): Result<GuidValue> { castStockValue<T, GuidValue>(value) }
    public func GetDateTime(): Result<DateTime> { castStockValue<T, DateTime>(value) }
    public func GetTimeSpan(): Result<TimeSpan> { castStockValue<T, TimeSpan>(value) }
    public func GetPoint(): Result<Point> { castStockValue<T, Point>(value) }
    public func GetSize(): Result<Size> { castStockValue<T, Size>(value) }
    public func GetRect(): Result<Rect> { castStockValue<T, Rect>(value) }
    public func GetUInt8Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt8>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetInt16Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Int16>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetUInt16Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt16>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetInt32Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Int32>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetUInt32Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt32>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetInt64Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Int64>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetUInt64Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt64>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetSingleArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Float32>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetDoubleArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Float64>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetChar16Array(valueSize: CPointer<UInt32>, value: CPointer<CPointer<UInt16>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetBooleanArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<Bool>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetStringArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<CPointer<Unit>>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetInspectableArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<CPointer<Unit>>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetGuidArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<windows_interface.GUID>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetDateTimeArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<windows_core.DateTimeAbi>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetTimeSpanArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<windows_core.TimeSpanAbi>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetPointArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<windows_core.PointAbi>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetSizeArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<windows_core.SizeAbi>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
    public func GetRectArray(valueSize: CPointer<UInt32>, value: CPointer<CPointer<windows_core.RectAbi>>): Result<Unit> { let _ = valueSize; let _ = value; notImpl<Unit>() }
}

extend<T> IReference<T> where T <: windows_core.RuntimeType & windows_core.WinrtGenericType<T> {
    public static func from(value: T): IReference<T> {
        let box = StockReference<T>(value)
        let object = ComObject<StockReference<T>>.new(
            box,
            [IReference<T>.iid(), windows_foundation.IPropertyValue.iid(), windows_interface.IID_IINSPECTABLE],
            [box.referenceVtblPtr(), box.propertyVtblPtr()]
        )
        object.intoInterface(IReference<T>.descriptor())
    }
}

extend IReference<HString> {
    public static func from(value: String): IReference<HString> {
        let text = HString(value)
        try {
            return IReference<HString>.from(text)
        } finally {
            text.close()
        }
    }
}

public func hStringReference(value: String): IReference<HString> {
    IReference<HString>.from(value)
}

// Box a Bool into an IReference<Bool> (WinRT IReference<Boolean>). The generic
// IReference<T>.from factory resolves here (same package as the extension, with
// the Bool : WinrtGenericType conformance visible); exposing it as a free
// function lets other packages box a bool without the extension being
// import-visible at their call site. Mirrors hStringReference.
public func boolReference(value: Bool): IReference<Bool> {
    IReference<Bool>.from(value)
}
