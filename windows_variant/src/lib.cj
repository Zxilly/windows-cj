package windows_variant

import windows_common.Win32.Foundation as Foundation
import windows_common.Win32.System.Variant as VariantNs
import windows_strings.BSTR

public type VARIANT_BOOL = Foundation.VARIANT_BOOL
public type VARENUM = VariantNs.VARENUM
public type VARIANT = VariantNs.VARIANT

type VariantPayload = VariantNs.VARIANT__Anonymous_e__Union__Anonymous_e__Struct
type VariantValue = VariantNs.VARIANT__Anonymous_e__Union__Anonymous_e__Struct__Anonymous_e__Union

public let VARIANT_TRUE: VARIANT_BOOL = -1i16
public let VARIANT_FALSE: VARIANT_BOOL = 0i16

public let VT_EMPTY: VARENUM = 0u16
public let VT_NULL: VARENUM = 1u16
public let VT_I2: VARENUM = 2u16
public let VT_I4: VARENUM = 3u16
public let VT_R4: VARENUM = 4u16
public let VT_R8: VARENUM = 5u16
public let VT_CY: VARENUM = 6u16
public let VT_DATE: VARENUM = 7u16
public let VT_BSTR: VARENUM = 8u16
public let VT_DISPATCH: VARENUM = 9u16
public let VT_ERROR: VARENUM = 10u16
public let VT_BOOL: VARENUM = 11u16
public let VT_VARIANT: VARENUM = 12u16
public let VT_UNKNOWN: VARENUM = 13u16
public let VT_DECIMAL: VARENUM = 14u16
public let VT_I1: VARENUM = 16u16
public let VT_UI1: VARENUM = 17u16
public let VT_UI2: VARENUM = 18u16
public let VT_UI4: VARENUM = 19u16
public let VT_I8: VARENUM = 20u16
public let VT_UI8: VARENUM = 21u16
public let VT_INT: VARENUM = 22u16
public let VT_UINT: VARENUM = 23u16
public let VT_VOID: VARENUM = 24u16
public let VT_HRESULT: VARENUM = 25u16
public let VT_PTR: VARENUM = 26u16
public let VT_SAFEARRAY: VARENUM = 27u16
public let VT_CARRAY: VARENUM = 28u16
public let VT_USERDEFINED: VARENUM = 29u16
public let VT_LPSTR: VARENUM = 30u16
public let VT_LPWSTR: VARENUM = 31u16
public let VT_RECORD: VARENUM = 36u16
public let VT_INT_PTR: VARENUM = 37u16
public let VT_UINT_PTR: VARENUM = 38u16
public let VT_FILETIME: VARENUM = 64u16
public let VT_BLOB: VARENUM = 65u16
public let VT_STREAM: VARENUM = 66u16
public let VT_STORAGE: VARENUM = 67u16
public let VT_STREAMED_OBJECT: VARENUM = 68u16
public let VT_STORED_OBJECT: VARENUM = 69u16
public let VT_BLOB_OBJECT: VARENUM = 70u16
public let VT_CF: VARENUM = 71u16
public let VT_CLSID: VARENUM = 72u16
public let VT_VERSIONED_STREAM: VARENUM = 73u16
public let VT_BSTR_BLOB: VARENUM = 4095u16
public let VT_VECTOR: VARENUM = 4096u16
public let VT_ARRAY: VARENUM = 8192u16
public let VT_BYREF: VARENUM = 16384u16
public let VT_RESERVED: VARENUM = 32768u16
public let VT_ILLEGAL: VARENUM = 65535u16
public let VT_ILLEGALMASKED: VARENUM = 4095u16
public let VT_TYPEMASK: VARENUM = 4095u16

public func variantBool(value: Bool): VARIANT_BOOL {
    if (value) {
        VARIANT_TRUE
    } else {
        VARIANT_FALSE
    }
}

public func variantBoolFromBool(value: Bool): VARIANT_BOOL {
    variantBool(value)
}

public func variantBoolToBool(value: VARIANT_BOOL): Bool {
    value != VARIANT_FALSE
}

public func isVariantTrue(value: VARIANT_BOOL): Bool {
    value == VARIANT_TRUE
}

public func isVariantFalse(value: VARIANT_BOOL): Bool {
    value == VARIANT_FALSE
}

func variantPayload(value: VARIANT): VariantPayload {
    value.Anonymous.Anonymous
}

func variantWithPayload(vt: VARENUM, payloadValue: VariantValue): VARIANT {
    var result = VARIANT()
    var outer = result.Anonymous
    var payload = outer.Anonymous
    payload.vt = vt
    payload.wReserved1 = 0u16
    payload.wReserved2 = 0u16
    payload.wReserved3 = 0u16
    payload.Anonymous = payloadValue
    outer.Anonymous = payload
    result.Anonymous = outer
    return result
}

public func emptyVariant(): VARIANT {
    VARIANT()
}

public func nullVariant(): VARIANT {
    variantWithPayload(VT_NULL, VariantValue())
}

public func variantVt(value: VARIANT): VARENUM {
    variantPayload(value).vt
}

public func variantIsEmpty(value: VARIANT): Bool {
    variantVt(value) == VT_EMPTY
}

public func variantIsNull(value: VARIANT): Bool {
    variantVt(value) == VT_NULL
}

public func variantIsScalar(value: VARIANT): Bool {
    let vt = variantVt(value)
    vt == VT_I1 || vt == VT_UI1 || vt == VT_I2 || vt == VT_UI2 ||
        vt == VT_I4 || vt == VT_UI4 || vt == VT_I8 || vt == VT_UI8 ||
        vt == VT_INT || vt == VT_UINT || vt == VT_R4 || vt == VT_R8 ||
        vt == VT_DATE || vt == VT_ERROR || vt == VT_BOOL
}

public func variantFromBool(value: Bool): VARIANT {
    var payload = VariantValue()
    payload.boolVal = variantBool(value)
    variantWithPayload(VT_BOOL, payload)
}

public func variantAsBool(value: VARIANT): Option<Bool> {
    let payload = variantPayload(value)
    if (payload.vt != VT_BOOL) {
        return None
    }
    return Some(variantBoolToBool(payload.Anonymous.boolVal))
}

public func variantFromInt8(value: Int8): VARIANT {
    var payload = VariantValue()
    payload.cVal = value
    variantWithPayload(VT_I1, payload)
}

public func variantAsInt8(value: VARIANT): Option<Int8> {
    let payload = variantPayload(value)
    if (payload.vt != VT_I1) {
        return None
    }
    return Some(payload.Anonymous.cVal)
}

public func variantFromUInt8(value: UInt8): VARIANT {
    var payload = VariantValue()
    payload.bVal = value
    variantWithPayload(VT_UI1, payload)
}

public func variantAsUInt8(value: VARIANT): Option<UInt8> {
    let payload = variantPayload(value)
    if (payload.vt != VT_UI1) {
        return None
    }
    return Some(payload.Anonymous.bVal)
}

public func variantFromInt16(value: Int16): VARIANT {
    var payload = VariantValue()
    payload.iVal = value
    variantWithPayload(VT_I2, payload)
}

public func variantAsInt16(value: VARIANT): Option<Int16> {
    let payload = variantPayload(value)
    if (payload.vt != VT_I2) {
        return None
    }
    return Some(payload.Anonymous.iVal)
}

public func variantFromUInt16(value: UInt16): VARIANT {
    var payload = VariantValue()
    payload.uiVal = value
    variantWithPayload(VT_UI2, payload)
}

public func variantAsUInt16(value: VARIANT): Option<UInt16> {
    let payload = variantPayload(value)
    if (payload.vt != VT_UI2) {
        return None
    }
    return Some(payload.Anonymous.uiVal)
}

public func variantFromI4(value: Int32): VARIANT {
    variantFromInt32(value)
}

public func variantFromInt32(value: Int32): VARIANT {
    var payload = VariantValue()
    payload.lVal = value
    variantWithPayload(VT_I4, payload)
}

public func variantAsI4(value: VARIANT): Option<Int32> {
    variantAsInt32(value)
}

public func variantAsInt32(value: VARIANT): Option<Int32> {
    let payload = variantPayload(value)
    if (payload.vt != VT_I4) {
        return None
    }
    return Some(payload.Anonymous.lVal)
}

public func variantFromUI4(value: UInt32): VARIANT {
    variantFromUInt32(value)
}

public func variantFromUInt32(value: UInt32): VARIANT {
    var payload = VariantValue()
    payload.ulVal = value
    variantWithPayload(VT_UI4, payload)
}

public func variantAsUI4(value: VARIANT): Option<UInt32> {
    variantAsUInt32(value)
}

public func variantAsUInt32(value: VARIANT): Option<UInt32> {
    let payload = variantPayload(value)
    if (payload.vt != VT_UI4) {
        return None
    }
    return Some(payload.Anonymous.ulVal)
}

public func variantFromI8(value: Int64): VARIANT {
    variantFromInt64(value)
}

public func variantFromInt64(value: Int64): VARIANT {
    var payload = VariantValue()
    payload.llVal = value
    variantWithPayload(VT_I8, payload)
}

public func variantAsI8(value: VARIANT): Option<Int64> {
    variantAsInt64(value)
}

public func variantAsInt64(value: VARIANT): Option<Int64> {
    let payload = variantPayload(value)
    if (payload.vt != VT_I8) {
        return None
    }
    return Some(payload.Anonymous.llVal)
}

public func variantFromUInt64(value: UInt64): VARIANT {
    var payload = VariantValue()
    payload.ullVal = value
    variantWithPayload(VT_UI8, payload)
}

public func variantAsUInt64(value: VARIANT): Option<UInt64> {
    let payload = variantPayload(value)
    if (payload.vt != VT_UI8) {
        return None
    }
    return Some(payload.Anonymous.ullVal)
}

public func variantFromR4(value: Float32): VARIANT {
    variantFromFloat32(value)
}

public func variantFromFloat32(value: Float32): VARIANT {
    var payload = VariantValue()
    payload.fltVal = value
    variantWithPayload(VT_R4, payload)
}

public func variantAsR4(value: VARIANT): Option<Float32> {
    variantAsFloat32(value)
}

public func variantAsFloat32(value: VARIANT): Option<Float32> {
    let payload = variantPayload(value)
    if (payload.vt != VT_R4) {
        return None
    }
    return Some(payload.Anonymous.fltVal)
}

public func variantFromR8(value: Float64): VARIANT {
    variantFromFloat64(value)
}

public func variantFromFloat64(value: Float64): VARIANT {
    var payload = VariantValue()
    payload.dblVal = value
    variantWithPayload(VT_R8, payload)
}

public func variantAsR8(value: VARIANT): Option<Float64> {
    variantAsFloat64(value)
}

public func variantAsFloat64(value: VARIANT): Option<Float64> {
    let payload = variantPayload(value)
    if (payload.vt != VT_R8) {
        return None
    }
    return Some(payload.Anonymous.dblVal)
}

public func variantFromDate(value: Float64): VARIANT {
    var payload = VariantValue()
    payload.date = value
    variantWithPayload(VT_DATE, payload)
}

public func variantAsDate(value: VARIANT): Option<Float64> {
    let payload = variantPayload(value)
    if (payload.vt != VT_DATE) {
        return None
    }
    return Some(payload.Anonymous.date)
}

public func variantFromError(value: Int32): VARIANT {
    var payload = VariantValue()
    payload.scode = value
    variantWithPayload(VT_ERROR, payload)
}

public func variantAsError(value: VARIANT): Option<Int32> {
    let payload = variantPayload(value)
    if (payload.vt != VT_ERROR) {
        return None
    }
    return Some(payload.Anonymous.scode)
}

public func variantFromWin32Int(value: Int32): VARIANT {
    var payload = VariantValue()
    payload.intVal = value
    variantWithPayload(VT_INT, payload)
}

public func variantAsWin32Int(value: VARIANT): Option<Int32> {
    let payload = variantPayload(value)
    if (payload.vt != VT_INT) {
        return None
    }
    return Some(payload.Anonymous.intVal)
}

public func variantFromWin32UInt(value: UInt32): VARIANT {
    var payload = VariantValue()
    payload.uintVal = value
    variantWithPayload(VT_UINT, payload)
}

public func variantAsWin32UInt(value: VARIANT): Option<UInt32> {
    let payload = variantPayload(value)
    if (payload.vt != VT_UINT) {
        return None
    }
    return Some(payload.Anonymous.uintVal)
}

/// Construct a VT_BSTR VARIANT by transferring ownership of the BSTR storage
/// to the VARIANT. The returned VARIANT must subsequently be released via
/// VariantClear (typically by wrapping it in a `Variant` resource).
public func variantFromBstr(value: BSTR): VARIANT {
    let raw = value.intoRaw()
    var payload = VariantValue()
    payload.bstrVal = unsafe { CPointer<Unit>(raw) }
    variantWithPayload(VT_BSTR, payload)
}

/// Construct a VT_BSTR VARIANT from a Cangjie String. Allocates fresh BSTR
/// storage via SysAllocStringLen.
public func variantFromString(value: String): VARIANT {
    variantFromBstr(BSTR(value))
}

/// View the BSTR payload of a VT_BSTR VARIANT without taking ownership of the
/// storage. The returned BSTR does not free the underlying pointer on close.
public func variantAsBstr(value: VARIANT): Option<BSTR> {
    let payload = variantPayload(value)
    if (payload.vt != VT_BSTR) {
        return None
    }
    let rawUnit = payload.Anonymous.bstrVal
    let raw = unsafe { CPointer<UInt16>(rawUnit) }
    Some(BSTR.fromRawView(raw))
}

/// Construct a VT_UNKNOWN VARIANT from a raw IUnknown pointer. The caller is
/// responsible for any AddRef bookkeeping prior to handing the pointer over;
/// VariantClear will issue Release on the contained interface.
public func variantFromUnknownRaw(value: CPointer<Unit>): VARIANT {
    var payload = VariantValue()
    payload.punkVal = value
    variantWithPayload(VT_UNKNOWN, payload)
}

/// Read the raw IUnknown pointer from a VT_UNKNOWN VARIANT without taking
/// ownership.
public func variantAsUnknownRaw(value: VARIANT): Option<CPointer<Unit>> {
    let payload = variantPayload(value)
    if (payload.vt != VT_UNKNOWN) {
        return None
    }
    Some(payload.Anonymous.punkVal)
}

/// Construct a VT_DISPATCH VARIANT from a raw IDispatch pointer.
public func variantFromDispatchRaw(value: CPointer<Unit>): VARIANT {
    var payload = VariantValue()
    payload.pdispVal = value
    variantWithPayload(VT_DISPATCH, payload)
}

/// Read the raw IDispatch pointer from a VT_DISPATCH VARIANT.
public func variantAsDispatchRaw(value: VARIANT): Option<CPointer<Unit>> {
    let payload = variantPayload(value)
    if (payload.vt != VT_DISPATCH) {
        return None
    }
    Some(payload.Anonymous.pdispVal)
}

/// Construct a VT_SAFEARRAY VARIANT from a raw SAFEARRAY pointer.
public func variantFromSafeArrayRaw(value: CPointer<Unit>): VARIANT {
    var payload = VariantValue()
    payload.parray = value
    variantWithPayload(VT_SAFEARRAY, payload)
}

/// Read the raw SAFEARRAY pointer from a VT_SAFEARRAY VARIANT.
public func variantAsSafeArrayRaw(value: VARIANT): Option<CPointer<Unit>> {
    let payload = variantPayload(value)
    if (payload.vt != VT_SAFEARRAY) {
        return None
    }
    Some(payload.Anonymous.parray)
}
