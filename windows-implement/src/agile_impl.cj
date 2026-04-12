package windows_implement

import windows_interface.*

@C
public struct IAgileObjectVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()

    public init() {}
}

@C
public struct IMarshalVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var GetUnmarshalClass: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<Unit>, UInt32, CPointer<Unit>, UInt32, CPointer<GUID>) -> Int32> = { _, _, _, _, _, _, _ => E_NOTIMPL }
    public var GetMarshalSizeMax: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<Unit>, UInt32, CPointer<Unit>, UInt32, CPointer<UInt32>) -> Int32> = { _, _, _, _, _, _, _ => E_NOTIMPL }
    public var MarshalInterface: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<GUID>, CPointer<Unit>, UInt32, CPointer<Unit>, UInt32) -> Int32> = { _, _, _, _, _, _, _ => E_NOTIMPL }
    public var UnmarshalInterface: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL }
    public var ReleaseMarshalData: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL }
    public var DisconnectObject: CFunc<(CPointer<Unit>, UInt32) -> Int32> = { _, _ => E_NOTIMPL }

    public init() {}
}

public let IID_IAGILEOBJECT = GUID.fromValues(0x94EA2B94u32, 0xE9CCu16, 0x49E0u16, 0xC0u8, 0xFFu8, 0xEEu8, 0x64u8, 0xCAu8, 0x8Fu8, 0x5Bu8, 0x90u8)
public let IID_IMARSHAL = GUID.fromValues(0x00000003u32, 0x0000u16, 0x0000u16, 0xC0u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x46u8)

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

func wrapIAgileObjectOwned(raw: CPointer<Unit>): IAgileObject {
    IAgileObject(raw, ownsReference: true)
}

func wrapIAgileObjectBorrowed(raw: CPointer<Unit>): IAgileObject {
    IAgileObject(raw)
}

func wrapIMarshalOwned(raw: CPointer<Unit>): IMarshal {
    IMarshal(raw, ownsReference: true)
}

func wrapIMarshalBorrowed(raw: CPointer<Unit>): IMarshal {
    IMarshal(raw)
}

public class IAgileObject <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func iid(): GUID {
        IID_IAGILEOBJECT
    }

    public static func descriptor(): InterfaceDescriptor<IAgileObject> {
        InterfaceDescriptor<IAgileObject>("IAgileObject", IID_IAGILEOBJECT, wrapIAgileObjectOwned, wrapIAgileObjectBorrowed)
    }

    public unsafe func vtbl(): IAgileObjectVtbl {
        readVtbl<IAgileObjectVtbl>(IAgileObjectVtbl())
    }
}

public class IMarshal <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func iid(): GUID {
        IID_IMARSHAL
    }

    public static func descriptor(): InterfaceDescriptor<IMarshal> {
        InterfaceDescriptor<IMarshal>("IMarshal", IID_IMARSHAL, wrapIMarshalOwned, wrapIMarshalBorrowed)
    }

    public unsafe func vtbl(): IMarshalVtbl {
        readVtbl<IMarshalVtbl>(IMarshalVtbl())
    }
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

    let marshalerUnknown = IUnknown(marshalerRaw, ownsReference: true)
    match (unsafe { queryInterfaceAs(marshalerRaw, IMarshal.descriptor()) }) {
        case Some(value) =>
            marshalerUnknown.close()
            Some(value)
        case None =>
            marshalerUnknown.close()
            None
    }
}

public func cloneMarshaler(marshaler: IMarshal, ppvObject: CPointer<CPointer<Unit>>): Int32 {
    if (ppvObject.isNull()) {
        return E_POINTER
    }
    let raw = marshaler.asRaw()
    if (raw.isNull()) {
        unsafe { ppvObject.write(CPointer<Unit>()) }
        return E_NOINTERFACE
    }
    marshaler.addRef()
    unsafe { ppvObject.write(raw) }
    S_OK
}
