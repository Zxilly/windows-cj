package windows_propvariant

import windows_common.Win32.Foundation as Foundation
import windows_interface.GUID
import windows_polyfill.*
import windows_strings.BSTR
import windows_strings.encodeUtf16WithNull
import windows_strings.decodeWideFromPointer
import windows_variant as wv

public type VARENUM = wv.VARENUM
public type VARIANT_BOOL = wv.VARIANT_BOOL
public type FILETIME = Foundation.FILETIME

public let VARIANT_TRUE: VARIANT_BOOL = wv.VARIANT_TRUE
public let VARIANT_FALSE: VARIANT_BOOL = wv.VARIANT_FALSE

public let VT_EMPTY: VARENUM = wv.VT_EMPTY
public let VT_NULL: VARENUM = wv.VT_NULL
public let VT_I2: VARENUM = wv.VT_I2
public let VT_I4: VARENUM = wv.VT_I4
public let VT_R4: VARENUM = wv.VT_R4
public let VT_R8: VARENUM = wv.VT_R8
public let VT_CY: VARENUM = wv.VT_CY
public let VT_DATE: VARENUM = wv.VT_DATE
public let VT_BSTR: VARENUM = wv.VT_BSTR
public let VT_DISPATCH: VARENUM = wv.VT_DISPATCH
public let VT_ERROR: VARENUM = wv.VT_ERROR
public let VT_BOOL: VARENUM = wv.VT_BOOL
public let VT_VARIANT: VARENUM = wv.VT_VARIANT
public let VT_UNKNOWN: VARENUM = wv.VT_UNKNOWN
public let VT_DECIMAL: VARENUM = wv.VT_DECIMAL
public let VT_I1: VARENUM = wv.VT_I1
public let VT_UI1: VARENUM = wv.VT_UI1
public let VT_UI2: VARENUM = wv.VT_UI2
public let VT_UI4: VARENUM = wv.VT_UI4
public let VT_I8: VARENUM = wv.VT_I8
public let VT_UI8: VARENUM = wv.VT_UI8
public let VT_INT: VARENUM = wv.VT_INT
public let VT_UINT: VARENUM = wv.VT_UINT
public let VT_VOID: VARENUM = wv.VT_VOID
public let VT_HRESULT: VARENUM = wv.VT_HRESULT
public let VT_PTR: VARENUM = wv.VT_PTR
public let VT_SAFEARRAY: VARENUM = wv.VT_SAFEARRAY
public let VT_CARRAY: VARENUM = wv.VT_CARRAY
public let VT_USERDEFINED: VARENUM = wv.VT_USERDEFINED
public let VT_LPSTR: VARENUM = wv.VT_LPSTR
public let VT_LPWSTR: VARENUM = wv.VT_LPWSTR
public let VT_RECORD: VARENUM = wv.VT_RECORD
public let VT_INT_PTR: VARENUM = wv.VT_INT_PTR
public let VT_UINT_PTR: VARENUM = wv.VT_UINT_PTR
public let VT_FILETIME: VARENUM = wv.VT_FILETIME
public let VT_BLOB: VARENUM = wv.VT_BLOB
public let VT_STREAM: VARENUM = wv.VT_STREAM
public let VT_STORAGE: VARENUM = wv.VT_STORAGE
public let VT_STREAMED_OBJECT: VARENUM = wv.VT_STREAMED_OBJECT
public let VT_STORED_OBJECT: VARENUM = wv.VT_STORED_OBJECT
public let VT_BLOB_OBJECT: VARENUM = wv.VT_BLOB_OBJECT
public let VT_CF: VARENUM = wv.VT_CF
public let VT_CLSID: VARENUM = wv.VT_CLSID
public let VT_VERSIONED_STREAM: VARENUM = wv.VT_VERSIONED_STREAM
public let VT_BSTR_BLOB: VARENUM = wv.VT_BSTR_BLOB
public let VT_VECTOR: VARENUM = wv.VT_VECTOR
public let VT_ARRAY: VARENUM = wv.VT_ARRAY
public let VT_BYREF: VARENUM = wv.VT_BYREF
public let VT_RESERVED: VARENUM = wv.VT_RESERVED
public let VT_ILLEGAL: VARENUM = wv.VT_ILLEGAL
public let VT_ILLEGALMASKED: VARENUM = wv.VT_ILLEGALMASKED
public let VT_TYPEMASK: VARENUM = wv.VT_TYPEMASK

/// PROPVARIANT — ABI-identical layout to the Win32 PROPVARIANT structure
/// (24 bytes: 2 bytes vt + 6 bytes wReserved1/2/3 + 16-byte payload union).
///
/// PROPVARIANT shares its overall envelope with VARIANT but expands the
/// payload tag space (VT_LPSTR, VT_LPWSTR, VT_FILETIME, VT_CLSID,
/// VT_STREAM/STORAGE/CF/BLOB ...). Use the helpers in this module to read
/// and write payload fields by tag; lifetime is managed via `PropVariant`.
@C
public struct PROPVARIANT {
    public var vt: UInt16 = 0
    public var wReserved1: UInt16 = 0
    public var wReserved2: UInt16 = 0
    public var wReserved3: UInt16 = 0
    public var payload: VArray<UInt64, $2> = VArray<UInt64, $2>(repeat: 0u64)
}

func payloadBase(slot: CPointer<PROPVARIANT>): CPointer<UInt8> {
    unsafe {
        let bytes = CPointer<UInt8>(slot)
        bytes + 8
    }
}

unsafe func writePayloadPointer(base: CPointer<UInt8>, byteOffset: Int64, value: CPointer<Unit>): Unit {
    let target = CPointer<CPointer<Unit>>(base + byteOffset)
    target.write(value)
}

unsafe func readPayloadPointer(base: CPointer<UInt8>, byteOffset: Int64): CPointer<Unit> {
    let target = CPointer<CPointer<Unit>>(base + byteOffset)
    target.read()
}

func writeVtSlot(target: PROPVARIANT, vt: VARENUM): PROPVARIANT {
    var result = target
    result.vt = vt
    result.wReserved1 = 0u16
    result.wReserved2 = 0u16
    result.wReserved3 = 0u16
    return result
}

func zeroPayload(target: PROPVARIANT): PROPVARIANT {
    var result = target
    result.payload = VArray<UInt64, $2>(repeat: 0u64)
    return result
}

public func emptyPropVariant(): PROPVARIANT {
    PROPVARIANT()
}

public func nullPropVariant(): PROPVARIANT {
    writeVtSlot(zeroPayload(PROPVARIANT()), VT_NULL)
}

public func propVariantVt(value: PROPVARIANT): VARENUM {
    value.vt
}

public func propVariantIsEmpty(value: PROPVARIANT): Bool {
    propVariantVt(value) == VT_EMPTY
}

public func propVariantIsNull(value: PROPVARIANT): Bool {
    propVariantVt(value) == VT_NULL
}

public func propVariantIsScalar(value: PROPVARIANT): Bool {
    let vt = propVariantVt(value)
    vt == VT_I1 || vt == VT_UI1 || vt == VT_I2 || vt == VT_UI2 ||
        vt == VT_I4 || vt == VT_UI4 || vt == VT_I8 || vt == VT_UI8 ||
        vt == VT_INT || vt == VT_UINT || vt == VT_R4 || vt == VT_R8 ||
        vt == VT_DATE || vt == VT_ERROR || vt == VT_BOOL
}

// ---------------------------------------------------------------------------
// Scalar helpers — write to / read from the inline payload bytes.
// ---------------------------------------------------------------------------

public func propVariantFromBool(value: Bool): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_BOOL))
    let raw = if (value) { VARIANT_TRUE } else { VARIANT_FALSE }
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteInt16(payloadBase(slotPtr), 0, raw)
    }
    return result
}

public func propVariantAsBool(value: PROPVARIANT): Option<Bool> {
    if (value.vt != VT_BOOL) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        let raw = unionReadInt16(payloadBase(slotPtr), 0)
        Some(raw != VARIANT_FALSE)
    }
}

public func propVariantFromInt8(value: Int8): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_I1))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteInt8(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsInt8(value: PROPVARIANT): Option<Int8> {
    if (value.vt != VT_I1) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadInt8(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromUInt8(value: UInt8): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_UI1))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteUInt8(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsUInt8(value: PROPVARIANT): Option<UInt8> {
    if (value.vt != VT_UI1) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadUInt8(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromInt16(value: Int16): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_I2))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteInt16(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsInt16(value: PROPVARIANT): Option<Int16> {
    if (value.vt != VT_I2) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadInt16(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromUInt16(value: UInt16): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_UI2))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteUInt16(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsUInt16(value: PROPVARIANT): Option<UInt16> {
    if (value.vt != VT_UI2) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadUInt16(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromInt32(value: Int32): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_I4))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteInt32(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsInt32(value: PROPVARIANT): Option<Int32> {
    if (value.vt != VT_I4) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadInt32(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromUInt32(value: UInt32): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_UI4))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteUInt32(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsUInt32(value: PROPVARIANT): Option<UInt32> {
    if (value.vt != VT_UI4) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadUInt32(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromInt64(value: Int64): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_I8))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteInt64(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsInt64(value: PROPVARIANT): Option<Int64> {
    if (value.vt != VT_I8) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadInt64(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromUInt64(value: UInt64): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_UI8))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteUInt64(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsUInt64(value: PROPVARIANT): Option<UInt64> {
    if (value.vt != VT_UI8) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadUInt64(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromFloat32(value: Float32): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_R4))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteFloat32(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsFloat32(value: PROPVARIANT): Option<Float32> {
    if (value.vt != VT_R4) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadFloat32(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromFloat64(value: Float64): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_R8))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteFloat64(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsFloat64(value: PROPVARIANT): Option<Float64> {
    if (value.vt != VT_R8) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadFloat64(payloadBase(slotPtr), 0))
    }
}

public func propVariantFromError(value: Int32): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_ERROR))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteInt32(payloadBase(slotPtr), 0, value)
    }
    return result
}

public func propVariantAsError(value: PROPVARIANT): Option<Int32> {
    if (value.vt != VT_ERROR) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(unionReadInt32(payloadBase(slotPtr), 0))
    }
}

// ---------------------------------------------------------------------------
// FILETIME payload (VT_FILETIME) — inline 8-byte structure.
// ---------------------------------------------------------------------------

public func propVariantFromFileTime(value: FILETIME): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_FILETIME))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteUInt32(payloadBase(slotPtr), 0, value.dwLowDateTime)
        unionWriteUInt32(payloadBase(slotPtr), 4, value.dwHighDateTime)
    }
    return result
}

public func propVariantFromFileTimeParts(low: UInt32, high: UInt32): PROPVARIANT {
    var ft = FILETIME()
    ft.dwLowDateTime = low
    ft.dwHighDateTime = high
    propVariantFromFileTime(ft)
}

public func propVariantAsFileTime(value: PROPVARIANT): Option<FILETIME> {
    if (value.vt != VT_FILETIME) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        var ft = FILETIME()
        ft.dwLowDateTime = unionReadUInt32(payloadBase(slotPtr), 0)
        ft.dwHighDateTime = unionReadUInt32(payloadBase(slotPtr), 4)
        Some(ft)
    }
}

// ---------------------------------------------------------------------------
// CLSID payload (VT_CLSID) — pointer to GUID on heap. Storage is taken over
// by the caller's PropVariant wrapper, which will free it via PropVariantClear.
// ---------------------------------------------------------------------------

public func propVariantFromClsid(value: GUID): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_CLSID))
    let raw = unsafe { allocateGuid(value) }
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        writePayloadPointer(payloadBase(slotPtr), 0, raw)
    }
    return result
}

public func propVariantAsClsid(value: PROPVARIANT): Option<GUID> {
    if (value.vt != VT_CLSID) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        let raw = readPayloadPointer(payloadBase(slotPtr), 0)
        let guidPtr = CPointer<GUID>(raw)
        if (guidPtr.isNull()) {
            return None
        }
        Some(guidPtr.read())
    }
}

unsafe func allocateGuid(value: GUID): CPointer<Unit> {
    let size = UIntNative(16)
    let raw = coTaskMemAllocAbi(size)
    if (raw.isNull()) {
        throw PropVariantAbiException("failed to allocate GUID storage for PROPVARIANT VT_CLSID")
    }
    let guidPtr = CPointer<GUID>(raw)
    guidPtr.write(value)
    raw
}

// ---------------------------------------------------------------------------
// VT_LPSTR / VT_LPWSTR payload — raw C strings owned by CoTaskMem allocation.
// ---------------------------------------------------------------------------

public func propVariantFromStringAnsi(value: Array<UInt8>): PROPVARIANT {
    let bytes = nullTerminatedAnsi(value)
    let raw = unsafe { allocateAnsi(bytes) }
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_LPSTR))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        writePayloadPointer(payloadBase(slotPtr), 0, raw)
    }
    return result
}

public func propVariantFromString(value: String): PROPVARIANT {
    let withNull = encodeUtf16WithNull(value)
    let raw = unsafe { allocateWide(withNull) }
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_LPWSTR))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        writePayloadPointer(payloadBase(slotPtr), 0, raw)
    }
    return result
}

public func propVariantAsString(value: PROPVARIANT): Option<String> {
    var copy = value
    let vt = value.vt
    if (vt == VT_LPWSTR) {
        unsafe {
            let slotPtr = CPointer<PROPVARIANT>(inout copy)
            let raw = readPayloadPointer(payloadBase(slotPtr), 0)
            let ptr = CPointer<UInt16>(raw)
            if (ptr.isNull()) {
                return None
            }
            return Some(decodeWideFromPointer(ptr))
        }
    }
    if (vt == VT_LPSTR) {
        unsafe {
            let slotPtr = CPointer<PROPVARIANT>(inout copy)
            let raw = readPayloadPointer(payloadBase(slotPtr), 0)
            let ptr = CPointer<UInt8>(raw)
            if (ptr.isNull()) {
                return None
            }
            return Some(decodeAnsi(ptr))
        }
    }
    None
}

// ---------------------------------------------------------------------------
// VT_BSTR — same model as VARIANT; ownership of the BSTR storage is given
// to the PROPVARIANT (and ultimately freed by PropVariantClear).
// ---------------------------------------------------------------------------

public func propVariantFromBstr(value: BSTR): PROPVARIANT {
    let raw = value.intoRaw()
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_BSTR))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        let asUnit = CPointer<Unit>(raw)
        writePayloadPointer(payloadBase(slotPtr), 0, asUnit)
    }
    return result
}

public func propVariantFromBstrString(value: String): PROPVARIANT {
    propVariantFromBstr(BSTR(value))
}

public func propVariantAsBstr(value: PROPVARIANT): Option<BSTR> {
    if (value.vt != VT_BSTR) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        let raw = readPayloadPointer(payloadBase(slotPtr), 0)
        let ptr = CPointer<UInt16>(raw)
        Some(BSTR.fromRawView(ptr))
    }
}

// ---------------------------------------------------------------------------
// VT_UNKNOWN / VT_DISPATCH / VT_STREAM / VT_STORAGE — raw IUnknown pointers.
// ---------------------------------------------------------------------------

public func propVariantFromUnknownRaw(value: CPointer<Unit>): PROPVARIANT {
    propVariantFromInterfacePointer(VT_UNKNOWN, value)
}

public func propVariantAsUnknownRaw(value: PROPVARIANT): Option<CPointer<Unit>> {
    propVariantReadInterfacePointer(value, VT_UNKNOWN)
}

public func propVariantFromDispatchRaw(value: CPointer<Unit>): PROPVARIANT {
    propVariantFromInterfacePointer(VT_DISPATCH, value)
}

public func propVariantAsDispatchRaw(value: PROPVARIANT): Option<CPointer<Unit>> {
    propVariantReadInterfacePointer(value, VT_DISPATCH)
}

public func propVariantFromStreamRaw(value: CPointer<Unit>): PROPVARIANT {
    propVariantFromInterfacePointer(VT_STREAM, value)
}

public func propVariantAsStreamRaw(value: PROPVARIANT): Option<CPointer<Unit>> {
    propVariantReadInterfacePointer(value, VT_STREAM)
}

public func propVariantFromStorageRaw(value: CPointer<Unit>): PROPVARIANT {
    propVariantFromInterfacePointer(VT_STORAGE, value)
}

public func propVariantAsStorageRaw(value: PROPVARIANT): Option<CPointer<Unit>> {
    propVariantReadInterfacePointer(value, VT_STORAGE)
}

func propVariantFromInterfacePointer(tag: VARENUM, value: CPointer<Unit>): PROPVARIANT {
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), tag))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        writePayloadPointer(payloadBase(slotPtr), 0, value)
    }
    return result
}

func propVariantReadInterfacePointer(value: PROPVARIANT, tag: VARENUM): Option<CPointer<Unit>> {
    if (value.vt != tag) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        Some(readPayloadPointer(payloadBase(slotPtr), 0))
    }
}

// ---------------------------------------------------------------------------
// VT_BLOB — paired (cElems, pElems) inline in the payload bytes. Pattern
// matches PROPVARIANT_0_0_0.blob (BLOB { cbSize: u32, pBlobData: *mut u8 }).
// ---------------------------------------------------------------------------

public func propVariantFromBytes(value: Array<UInt8>): PROPVARIANT {
    let size = UInt32(value.size)
    let raw = unsafe { allocateBytes(value) }
    var result = zeroPayload(writeVtSlot(PROPVARIANT(), VT_BLOB))
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout result)
        unionWriteUInt32(payloadBase(slotPtr), 0, size)
        writePayloadPointer(payloadBase(slotPtr), 8, raw)
    }
    return result
}

public func propVariantAsBytes(value: PROPVARIANT): Option<Array<UInt8>> {
    if (value.vt != VT_BLOB) {
        return None
    }
    var copy = value
    unsafe {
        let slotPtr = CPointer<PROPVARIANT>(inout copy)
        let size = unionReadUInt32(payloadBase(slotPtr), 0)
        let raw = readPayloadPointer(payloadBase(slotPtr), 8)
        let ptr = CPointer<UInt8>(raw)
        if (ptr.isNull() || size == 0u32) {
            return Some(Array<UInt8>())
        }
        let length = Int64(size)
        let copyOut = Array<UInt8>(length, { index =>
            (ptr + index).read()
        })
        Some(copyOut)
    }
}

// ---------------------------------------------------------------------------
// Raw allocation helpers (ole32::CoTaskMemAlloc).
// ---------------------------------------------------------------------------

unsafe func allocateBytes(value: Array<UInt8>): CPointer<Unit> {
    let size = UIntNative(value.size)
    let raw = if (size == UIntNative(0)) {
        coTaskMemAllocAbi(UIntNative(1))
    } else {
        coTaskMemAllocAbi(size)
    }
    if (raw.isNull()) {
        throw PropVariantAbiException("failed to allocate BLOB storage for PROPVARIANT")
    }
    if (size > UIntNative(0)) {
        let bytePtr = CPointer<UInt8>(raw)
        var index: Int64 = 0
        while (index < value.size) {
            (bytePtr + index).write(value[index])
            index += 1
        }
    }
    raw
}

unsafe func allocateAnsi(bytes: Array<UInt8>): CPointer<Unit> {
    let size = UIntNative(bytes.size)
    let raw = coTaskMemAllocAbi(size)
    if (raw.isNull()) {
        throw PropVariantAbiException("failed to allocate LPSTR storage for PROPVARIANT")
    }
    let bytePtr = CPointer<UInt8>(raw)
    var index: Int64 = 0
    while (index < bytes.size) {
        (bytePtr + index).write(bytes[index])
        index += 1
    }
    raw
}

unsafe func allocateWide(units: Array<UInt16>): CPointer<Unit> {
    let size = UIntNative(units.size * 2)
    let raw = coTaskMemAllocAbi(size)
    if (raw.isNull()) {
        throw PropVariantAbiException("failed to allocate LPWSTR storage for PROPVARIANT")
    }
    let widePtr = CPointer<UInt16>(raw)
    var index: Int64 = 0
    while (index < units.size) {
        (widePtr + index).write(units[index])
        index += 1
    }
    raw
}

func nullTerminatedAnsi(value: Array<UInt8>): Array<UInt8> {
    let length = value.size
    let result = Array<UInt8>(length + 1, { index =>
        if (index < length) {
            value[index]
        } else {
            0u8
        }
    })
    result
}

unsafe func decodeAnsi(ptr: CPointer<UInt8>): String {
    var length: Int64 = 0
    while (true) {
        let byte = (ptr + length).read()
        if (byte == 0u8) {
            break
        }
        length += 1
    }
    let bytes = Array<UInt8>(length, { index =>
        (ptr + index).read()
    })
    String.fromUtf8(bytes)
}
