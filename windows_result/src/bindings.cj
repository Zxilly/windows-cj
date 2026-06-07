package windows_result

import std.sync.AtomicInt32
import windows_libloading as windows_libloading

type IntPtr = CPointer<Unit>
type FORMAT_MESSAGE_OPTIONS = UInt32

let observedSysFreeStringCount = AtomicInt32(0)

@When[os == "Windows"]
public func debugObservedSysFreeStringCount(): Int32 {
    observedSysFreeStringCount.load()
}

@When[os != "Windows"]
func ensureDynamicWin32CFuncAbiSupported(): Unit {}

@When[os == "Windows" && arch == "x86_64"]
func ensureDynamicWin32CFuncAbiSupported(): Unit {}

@When[os == "Windows" && arch != "x86_64"]
func ensureDynamicWin32CFuncAbiSupported(): Unit {
    throw Exception("dynamic Win32 CFunc ABI is only supported on Windows x86_64")
}

func resolveDynamicWin32Proc(moduleName: String, procName: String): CPointer<Unit> {
    // @CallingConv cannot be applied to local CFunc casts, so this dynamic path is only
    // valid where Win32 uses the platform C calling convention.
    ensureDynamicWin32CFuncAbiSupported()
    windows_libloading.resolveProc(moduleName, procName)
}

func FormatMessageW(
    dwFlags: UInt32,
    lpSource: CPointer<Unit>,
    dwMessageId: UInt32,
    dwLanguageId: UInt32,
    lpBuffer: CPointer<CPointer<UInt16>>,
    nSize: UInt32,
    arguments: CPointer<Unit>
): UInt32 {
    let proc = CFunc<(UInt32, CPointer<Unit>, UInt32, UInt32, CPointer<CPointer<UInt16>>, UInt32, CPointer<Unit>) -> UInt32>(
        resolveDynamicWin32Proc("kernel32.dll", "FormatMessageW")
    )
    unsafe { proc(dwFlags, lpSource, dwMessageId, dwLanguageId, lpBuffer, nSize, arguments) }
}

func GetProcessHeap(): IntPtr {
    let proc = CFunc<() -> IntPtr>(resolveDynamicWin32Proc("kernel32.dll", "GetProcessHeap"))
    unsafe { proc() }
}

func HeapFree(hHeap: IntPtr, dwFlags: UInt32, lpMem: CPointer<Unit>): Int32 {
    let proc = CFunc<(IntPtr, UInt32, CPointer<Unit>) -> Int32>(
        resolveDynamicWin32Proc("kernel32.dll", "HeapFree")
    )
    unsafe { proc(hHeap, dwFlags, lpMem) }
}

func GetLastError(): UInt32 {
    let proc = CFunc<() -> UInt32>(resolveDynamicWin32Proc("kernel32.dll", "GetLastError"))
    unsafe { proc() }
}

let FORMAT_MESSAGE_ALLOCATE_BUFFER: FORMAT_MESSAGE_OPTIONS = 0x00000100u32
let FORMAT_MESSAGE_IGNORE_INSERTS: FORMAT_MESSAGE_OPTIONS = 0x00000200u32
let FORMAT_MESSAGE_FROM_HMODULE: FORMAT_MESSAGE_OPTIONS = 0x00000800u32
let FORMAT_MESSAGE_FROM_SYSTEM: FORMAT_MESSAGE_OPTIONS = 0x00001000u32
public let ERROR_INVALID_DATA: WIN32_ERROR = WIN32_ERROR(13u32)
public let ERROR_NO_UNICODE_TRANSLATION: WIN32_ERROR = WIN32_ERROR(1113u32)
let FACILITY_NT_BIT: UInt32 = 0x10000000u32

@C
struct UInt128 {
    let high: UInt64
    let low: UInt64

    init(high: UInt64, low: UInt64) {
        this.high = high
        this.low = low
    }
}

@C
struct GUID {
    var data1: UInt32 = 0u32
    var data2: UInt16 = 0u16
    var data3: UInt16 = 0u16
    var data4: VArray<UInt8, $8> = VArray<UInt8, $8>(repeat: 0u8)

    init() {}

    init(
        data1: UInt32,
        data2: UInt16,
        data3: UInt16,
        data4_0: UInt8,
        data4_1: UInt8,
        data4_2: UInt8,
        data4_3: UInt8,
        data4_4: UInt8,
        data4_5: UInt8,
        data4_6: UInt8,
        data4_7: UInt8
    ) {
        this.data1 = data1
        this.data2 = data2
        this.data3 = data3
        this.data4[0] = data4_0
        this.data4[1] = data4_1
        this.data4[2] = data4_2
        this.data4[3] = data4_3
        this.data4[4] = data4_4
        this.data4[5] = data4_5
        this.data4[6] = data4_6
        this.data4[7] = data4_7
    }

    static func zeroed(): GUID {
        GUID()
    }

    static func from_u128(value: UInt128): GUID {
        GUID(
            UInt32(value.high >> 32),
            UInt16((value.high >> 16) & 0xFFFFu64),
            UInt16(value.high & 0xFFFFu64),
            UInt8((value.low >> 56) & 0xFFu64),
            UInt8((value.low >> 48) & 0xFFu64),
            UInt8((value.low >> 40) & 0xFFu64),
            UInt8((value.low >> 32) & 0xFFu64),
            UInt8((value.low >> 24) & 0xFFu64),
            UInt8((value.low >> 16) & 0xFFu64),
            UInt8((value.low >> 8) & 0xFFu64),
            UInt8(value.low & 0xFFu64)
        )
    }

    public operator func ==(other: GUID): Bool {
        if (data1 != other.data1 || data2 != other.data2 || data3 != other.data3) {
            return false
        }

        var index: Int64 = 0
        while (index < 8) {
            if (data4[index] != other.data4[index]) {
                return false
            }
            index += 1
        }
        true
    }

    public operator func !=(other: GUID): Bool {
        !(this == other)
    }
}

let IID_IUNKNOWN = GUID.from_u128(UInt128(0x0000000000000000u64, 0xC000000000000046u64))
let IID_IERRORINFO = GUID.from_u128(UInt128(0x1CF2B120547D101Bu64, 0x8E6508002B2BD119u64))
let IID_IRESTRICTEDERRORINFO = GUID.from_u128(UInt128(0x82BA70924C88427Du64, 0xA7BC16DD93FEB67Eu64))
let IID_IUnknown = IID_IUNKNOWN
let IID_IErrorInfo = IID_IERRORINFO
let IID_IRestrictedErrorInfo = IID_IRESTRICTEDERRORINFO

func clearDefaultUnknownOutSlot(slot: CPointer<CPointer<Unit>>): Unit {
    if (slot.isNotNull()) {
        unsafe { slot.write(CPointer<Unit>()) }
    }
}

func clearDefaultBstrOutSlot(slot: CPointer<CPointer<UInt16>>): Unit {
    if (slot.isNotNull()) {
        unsafe { slot.write(CPointer<UInt16>()) }
    }
}

func clearDefaultGuidOutSlot(slot: CPointer<GUID>): Unit {
    if (slot.isNotNull()) {
        unsafe { slot.write(GUID.zeroed()) }
    }
}

func clearDefaultInt32OutSlot(slot: CPointer<Int32>): Unit {
    if (slot.isNotNull()) {
        unsafe { slot.write(0i32) }
    }
}

func clearDefaultUInt32OutSlot(slot: CPointer<UInt32>): Unit {
    if (slot.isNotNull()) {
        unsafe { slot.write(0u32) }
    }
}

@C
struct IUnknown {
    var lpVtbl: CPointer<IUnknownVtbl> = CPointer<IUnknownVtbl>()
    init() {}
}

@C
struct IErrorInfo {
    var lpVtbl: CPointer<IErrorInfoVtbl> = CPointer<IErrorInfoVtbl>()
    init() {}
}

@C
struct IRestrictedErrorInfo {
    var lpVtbl: CPointer<IRestrictedErrorInfoVtbl> = CPointer<IRestrictedErrorInfoVtbl>()
    init() {}
}

@C
struct IUnknownVtbl {
    var QueryInterface: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, resultPtr =>
        if (resultPtr.isNull()) {
            return E_POINTER.value
        }
        clearDefaultUnknownOutSlot(resultPtr)
        E_NOINTERFACE.value
    }
    var AddRef: CFunc<(CPointer<Unit>) -> UInt32> = { _ => 0u32 }
    var Release: CFunc<(CPointer<Unit>) -> UInt32> = { _ => 0u32 }

    init() {}
}

@C
struct IErrorInfoVtbl {
    var base__: IUnknownVtbl = IUnknownVtbl()
    var GetGUID: CFunc<(CPointer<Unit>, CPointer<GUID>) -> Int32> = { _, result =>
        clearDefaultGuidOutSlot(result)
        E_NOTIMPL.value
    }
    var GetSource: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, result =>
        clearDefaultBstrOutSlot(result)
        E_NOTIMPL.value
    }
    var GetDescription: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, result =>
        clearDefaultBstrOutSlot(result)
        E_NOTIMPL.value
    }
    var GetHelpFile: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, result =>
        clearDefaultBstrOutSlot(result)
        E_NOTIMPL.value
    }
    var GetHelpContext: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32> = { _, result =>
        clearDefaultUInt32OutSlot(result)
        E_NOTIMPL.value
    }

    init() {}
}

@C
struct IRestrictedErrorInfoVtbl {
    var base__: IUnknownVtbl = IUnknownVtbl()
    var GetErrorDetails: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>, CPointer<Int32>, CPointer<CPointer<UInt16>>, CPointer<CPointer<UInt16>>) -> Int32> = { _, fallback, errorCode, description, reference =>
        clearDefaultBstrOutSlot(fallback)
        clearDefaultInt32OutSlot(errorCode)
        clearDefaultBstrOutSlot(description)
        clearDefaultBstrOutSlot(reference)
        E_NOTIMPL.value
    }
    var GetReference: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, result =>
        clearDefaultBstrOutSlot(result)
        E_NOTIMPL.value
    }

    init() {}
}

func GetErrorInfo(dwReserved: UInt32, pperrinfo: CPointer<CPointer<IErrorInfo>>): Int32 {
    let proc = CFunc<(UInt32, CPointer<CPointer<IErrorInfo>>) -> Int32>(
        resolveDynamicWin32Proc("oleaut32.dll", "GetErrorInfo")
    )
    unsafe { proc(dwReserved, pperrinfo) }
}

func SetErrorInfo(dwReserved: UInt32, perrinfo: CPointer<Unit>): Int32 {
    let proc = CFunc<(UInt32, CPointer<Unit>) -> Int32>(
        resolveDynamicWin32Proc("oleaut32.dll", "SetErrorInfo")
    )
    unsafe { proc(dwReserved, perrinfo) }
}

func SysAllocStringLen(strIn: CPointer<UInt16>, ui: UInt32): CPointer<UInt16> {
    let proc = CFunc<(CPointer<UInt16>, UInt32) -> CPointer<UInt16>>(
        resolveDynamicWin32Proc("oleaut32.dll", "SysAllocStringLen")
    )
    unsafe { proc(strIn, ui) }
}

func SysFreeString(bstrString: CPointer<UInt16>): Unit {
    let proc = CFunc<(CPointer<UInt16>) -> Unit>(
        resolveDynamicWin32Proc("oleaut32.dll", "SysFreeString")
    )
    unsafe { proc(bstrString) }
}

func SysStringLen(pbstr: CPointer<UInt16>): UInt32 {
    let proc = CFunc<(CPointer<UInt16>) -> UInt32>(
        resolveDynamicWin32Proc("oleaut32.dll", "SysStringLen")
    )
    unsafe { proc(pbstr) }
}

func RoOriginateErrorW(error: Int32, cchMax: UInt32, message: CPointer<UInt16>): Int32 {
    let proc = CFunc<(Int32, UInt32, CPointer<UInt16>) -> Int32>(
        resolveDynamicWin32Proc("combase.dll", "RoOriginateErrorW")
    )
    unsafe { proc(error, cchMax, message) }
}

@When[os == "Windows"]
func sysAllocStringLenAbi(text: CPointer<UInt16>, length: UInt32): CPointer<UInt16> {
    unsafe { SysAllocStringLen(text, length) }
}

@When[os != "Windows"]
func sysAllocStringLenAbi(_: CPointer<UInt16>, _: UInt32): CPointer<UInt16> {
    CPointer<UInt16>()
}

@When[os == "Windows"]
func sysFreeStringAbi(text: CPointer<UInt16>): Unit {
    unsafe { SysFreeString(text) }
    observedSysFreeStringCount.fetchAdd(1)
}

@When[os != "Windows"]
func sysFreeStringAbi(_: CPointer<UInt16>): Unit {}

@When[os == "Windows"]
func sysStringLenAbi(text: CPointer<UInt16>): UInt32 {
    unsafe { SysStringLen(text) }
}

@When[os != "Windows"]
func sysStringLenAbi(_: CPointer<UInt16>): UInt32 {
    0u32
}

@When[os == "Windows"]
func getErrorInfoAbi(dwReserved: UInt32, pperrinfo: CPointer<CPointer<IErrorInfo>>): Int32 {
    unsafe { GetErrorInfo(dwReserved, pperrinfo) }
}

@When[os != "Windows"]
func getErrorInfoAbi(_: UInt32, _: CPointer<CPointer<IErrorInfo>>): Int32 {
    E_NOTIMPL.value
}

@When[os == "Windows"]
func setErrorInfoAbi(dwReserved: UInt32, perrinfo: CPointer<Unit>): Int32 {
    unsafe { SetErrorInfo(dwReserved, perrinfo) }
}

@When[os != "Windows"]
func setErrorInfoAbi(_: UInt32, _: CPointer<Unit>): Int32 {
    E_NOTIMPL.value
}

@When[os == "Windows"]
func roOriginateErrorWAbi(error: Int32, cchMax: UInt32, message: CPointer<UInt16>): Int32 {
    unsafe { RoOriginateErrorW(error, cchMax, message) }
}

@When[os != "Windows"]
func roOriginateErrorWAbi(_: Int32, _: UInt32, _: CPointer<UInt16>): Int32 {
    0i32
}
