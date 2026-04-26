package windows_implement

import windows_interface.*

let OLE32_DLL_NAME: Array<UInt16> = [
    0x006Fu16, 0x006Cu16, 0x0065u16, 0x0033u16, 0x0032u16,
    0x002Eu16, 0x0064u16, 0x006Cu16, 0x006Cu16, 0u16
]
let CO_CREATE_FREE_THREADED_MARSHALER_PROC_NAME: Array<UInt8> = [
    0x43u8, 0x6Fu8, 0x43u8, 0x72u8, 0x65u8, 0x61u8, 0x74u8, 0x65u8,
    0x46u8, 0x72u8, 0x65u8, 0x65u8, 0x54u8, 0x68u8, 0x72u8, 0x65u8,
    0x61u8, 0x64u8, 0x65u8, 0x64u8, 0x4Du8, 0x61u8, 0x72u8, 0x73u8,
    0x68u8, 0x61u8, 0x6Cu8, 0x65u8, 0x72u8, 0u8
]

var cachedOle32Module: CPointer<Unit> = CPointer<Unit>()
var cachedCoCreateFreeThreadedMarshalerProc: CPointer<Unit> = CPointer<Unit>()

foreign {
    func LoadLibraryW(lpLibFileName: CPointer<UInt16>): CPointer<Unit>
    func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CPointer<UInt8>): CPointer<Unit>
}

func ole32Module(): CPointer<Unit> {
    if (cachedOle32Module.isNotNull()) {
        return cachedOle32Module
    }

    unsafe {
        let handle = acquireArrayRawData(OLE32_DLL_NAME)
        try {
            let module = LoadLibraryW(handle.pointer)
            if (module.isNull()) {
                return CPointer<Unit>()
            }
            cachedOle32Module = module
            module
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

func coCreateFreeThreadedMarshalerProc(): CPointer<Unit> {
    if (cachedCoCreateFreeThreadedMarshalerProc.isNotNull()) {
        return cachedCoCreateFreeThreadedMarshalerProc
    }

    let module = ole32Module()
    if (module.isNull()) {
        return CPointer<Unit>()
    }

    unsafe {
        let handle = acquireArrayRawData(CO_CREATE_FREE_THREADED_MARSHALER_PROC_NAME)
        try {
            let proc = GetProcAddress(module, handle.pointer)
            if (proc.isNull()) {
                return CPointer<Unit>()
            }
            cachedCoCreateFreeThreadedMarshalerProc = proc
            proc
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

public func createFreeThreadedMarshaler(outer: CPointer<Unit>): Option<IMarshal> {
    if (outer.isNull()) {
        return None
    }

    let proc = coCreateFreeThreadedMarshalerProc()
    if (proc.isNull()) {
        return None
    }

    let create = CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>(proc)
    var marshalerRaw = CPointer<Unit>()
    let hr = unsafe {
        create(outer, CPointer<CPointer<Unit>>(inout marshalerRaw))
    }
    if (hr != S_OK || marshalerRaw.isNull()) {
        return None
    }

    let marshalerUnknown = IUnknown.fromAbiTake(marshalerRaw)
    match (unsafe { queryInterfaceAs(marshalerRaw, IMarshal.descriptor()) }) {
        case Some(value) =>
            marshalerUnknown.close()
            Some(value)
        case None =>
            marshalerUnknown.close()
            None
    }
}

public func cloneMarshaler(marshaler: IMarshal, resultSlot: CPointer<CPointer<Unit>>): Int32 {
    if (resultSlot.isNull()) {
        return E_POINTER
    }
    let raw = marshaler.asRaw()
    if (raw.isNull()) {
        unsafe { resultSlot.write(CPointer<Unit>()) }
        return E_NOINTERFACE
    }
    marshaler.addRef()
    unsafe { resultSlot.write(raw) }
    S_OK
}
