package windows_interface

import windows_result.*
import windows_result.Error as WinResultError
import windows_strings.*

let COMBASE_DLL_NAME: Array<UInt16> = [
    0x0063u16, 0x006Fu16, 0x006Du16, 0x0062u16, 0x0061u16, 0x0073u16,
    0x0065u16, 0x002Eu16, 0x0064u16, 0x006Cu16, 0x006Cu16, 0u16
]
let WINDOWS_GET_STRING_RAW_BUFFER_PROC_NAME: Array<UInt8> = [
    0x57u8, 0x69u8, 0x6Eu8, 0x64u8, 0x6Fu8, 0x77u8, 0x73u8, 0x47u8,
    0x65u8, 0x74u8, 0x53u8, 0x74u8, 0x72u8, 0x69u8, 0x6Eu8, 0x67u8,
    0x52u8, 0x61u8, 0x77u8, 0x42u8, 0x75u8, 0x66u8, 0x66u8, 0x65u8,
    0x72u8, 0u8
]
let WINDOWS_DELETE_STRING_PROC_NAME: Array<UInt8> = [
    0x57u8, 0x69u8, 0x6Eu8, 0x64u8, 0x6Fu8, 0x77u8, 0x73u8, 0x44u8,
    0x65u8, 0x6Cu8, 0x65u8, 0x74u8, 0x65u8, 0x53u8, 0x74u8, 0x72u8,
    0x69u8, 0x6Eu8, 0x67u8, 0u8
]
let RO_GET_ACTIVATION_FACTORY_PROC_NAME: Array<UInt8> = [
    0x52u8, 0x6Fu8, 0x47u8, 0x65u8, 0x74u8, 0x41u8, 0x63u8, 0x74u8,
    0x69u8, 0x76u8, 0x61u8, 0x74u8, 0x69u8, 0x6Fu8, 0x6Eu8, 0x46u8,
    0x61u8, 0x63u8, 0x74u8, 0x6Fu8, 0x72u8, 0x79u8, 0u8
]

var cachedCombaseModule: CPointer<Unit> = CPointer<Unit>()
var cachedWindowsGetStringRawBufferProc: CPointer<Unit> = CPointer<Unit>()
var cachedWindowsDeleteStringProc: CPointer<Unit> = CPointer<Unit>()
var cachedRoGetActivationFactoryProc: CPointer<Unit> = CPointer<Unit>()

func addRefRaw(raw: CPointer<Unit>): UInt32 {
    if (raw.isNull()) {
        return 0u32
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.AddRef(raw)
    }
}

func releaseRaw(raw: CPointer<Unit>): UInt32 {
    if (raw.isNull()) {
        return 0u32
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.Release(raw)
    }
}

func wrapIUnknownOwned(raw: CPointer<Unit>): IUnknown {
    IUnknown(raw, ownsReference: true)
}

func wrapIUnknownBorrowed(raw: CPointer<Unit>): IUnknown {
    IUnknown(raw)
}

func wrapIInspectableOwned(raw: CPointer<Unit>): IInspectable {
    IInspectable(raw, ownsReference: true)
}

func wrapIInspectableBorrowed(raw: CPointer<Unit>): IInspectable {
    IInspectable(raw)
}

@C
public struct IUnknownVtbl {
    public var QueryInterface: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOINTERFACE.value }
    public var AddRef: CFunc<(CPointer<Unit>) -> UInt32> = { _ => 0u32 }
    public var Release: CFunc<(CPointer<Unit>) -> UInt32> = { _ => 0u32 }

    public init() {}
}

@C
public struct IInspectableVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var GetIids: CFunc<(CPointer<Unit>, CPointer<UInt32>, CPointer<CPointer<GUID>>) -> Int32> = { _, countPtr, iidsPtr =>
        unsafe {
            countPtr.write(0u32)
            iidsPtr.write(CPointer<GUID>())
        }
        0i32
    }
    public var GetRuntimeClassName: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, valuePtr =>
        unsafe { valuePtr.write(CPointer<Unit>()) }
        0i32
    }
    public var GetTrustLevel: CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32> = { _, valuePtr =>
        unsafe { valuePtr.write(0i32) }
        0i32
    }

    public init() {}
}

public open class InterfaceWrapperBase <: Resource {
    private let raw_: CPointer<Unit>
    private let ownsReference_: Bool
    private var closed_: Bool = false

    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        this.raw_ = raw
        this.ownsReference_ = ownsReference
    }

    public func asRaw(): CPointer<Unit> {
        if (closed_) {
            return CPointer<Unit>()
        }
        raw_
    }

    public func isOwned(): Bool {
        ownsReference_
    }

    public func isClosed(): Bool {
        closed_
    }

    public func addRef(): UInt32 {
        addRefRaw(asRaw())
    }

    public func release(): UInt32 {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return 0u32
        }
        let count = releaseRaw(liveRaw)
        closed_ = true
        count
    }

    public unsafe func query<T>(descriptor: InterfaceDescriptor<T>): Option<T> {
        queryInterfaceAs(asRaw(), descriptor)
    }

    public unsafe func readVtbl<T>(defaultValue: T): T where T <: CType {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return defaultValue
        }
        let vtblPtr = CPointer<CPointer<T>>(liveRaw).read()
        vtblPtr.read()
    }

    public func close(): Unit {
        let liveRaw = asRaw()
        if (!liveRaw.isNull() && ownsReference_) {
            releaseRaw(liveRaw)
        }
        closed_ = true
    }
}

public class IUnknown <: InterfaceWrapperBase & ComInterface & RuntimeName {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func fromRaw(raw: CPointer<Unit>): IUnknown {
        IUnknown(raw, ownsReference: true)
    }

    public static func fromRawBorrowed(raw: CPointer<Unit>): IUnknown {
        IUnknown(raw)
    }

    public static func iid(): GUID {
        IID_IUNKNOWN
    }

    public static func descriptor(): InterfaceDescriptor<IUnknown> {
        InterfaceDescriptor<IUnknown>("IUnknown", IID_IUNKNOWN, wrapIUnknownOwned, wrapIUnknownBorrowed)
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        InterfaceDescriptorSchema(
            "IUnknown",
            IID_IUNKNOWN,
            "IUnknownVtbl",
            "IUnknown",
            "IUnknown_Impl",
            Array<InterfaceMethodSchema>(0, { _ => InterfaceMethodSchema("", 0, Array<String>(0, { _ => "" }), "") })
        )
    }

    public unsafe func vtbl(): IUnknownVtbl {
        readVtbl<IUnknownVtbl>(IUnknownVtbl())
    }

    public unsafe func queryRaw(targetIid: GUID): Option<CPointer<Unit>> {
        queryInterfaceRaw(asRaw(), targetIid)
    }
}

public class IInspectable <: InterfaceWrapperBase & ComInterface & RuntimeName {

    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func fromRaw(raw: CPointer<Unit>): IInspectable {
        IInspectable(raw, ownsReference: true)
    }

    public static func fromRawBorrowed(raw: CPointer<Unit>): IInspectable {
        IInspectable(raw)
    }

    public static func iid(): GUID {
        IID_IINSPECTABLE
    }

    public static func descriptor(): InterfaceDescriptor<IInspectable> {
        InterfaceDescriptor<IInspectable>(
            "IInspectable",
            IID_IINSPECTABLE,
            IUnknown.descriptor(),
            wrapIInspectableOwned,
            wrapIInspectableBorrowed
        )
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        InterfaceDescriptorSchema(
            "IInspectable",
            IID_IINSPECTABLE,
            IUnknown.descriptorSchema(),
            "IInspectableVtbl",
            "IInspectable",
            "IInspectable_Impl",
            Array<InterfaceMethodSchema>(0, { _ => InterfaceMethodSchema("", 0, Array<String>(0, { _ => "" }), "") })
        )
    }

    public func asIUnknown(): IUnknown {
        IUnknown(asRaw())
    }

    public unsafe func vtbl(): IInspectableVtbl {
        readVtbl<IInspectableVtbl>(IInspectableVtbl())
    }

    public unsafe func getIids(count: CPointer<UInt32>, values: CPointer<CPointer<GUID>>): HRESULT {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return E_POINTER
        }
        let v = vtbl()
        HRESULT(v.GetIids(liveRaw, count, values))
    }

    public unsafe func getRuntimeClassNameRaw(value: CPointer<CPointer<Unit>>): HRESULT {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return E_POINTER
        }
        let v = vtbl()
        HRESULT(v.GetRuntimeClassName(liveRaw, value))
    }

    public unsafe func getRuntimeClassName(): HString {
        var rawValue = CPointer<Unit>()
        let hr = getRuntimeClassNameRaw(CPointer<CPointer<Unit>>(inout rawValue))
        if (hr.failed()) {
            throw WindowsException(hr)
        }
        if (rawValue.isNull()) {
            return HString()
        }

        var length = 0u32
        let buffer = windowsGetStringRawBufferAbi(rawValue, CPointer<UInt32>(inout length))
        let copied = copyWideUnits(buffer, length)
        windowsDeleteStringAbi(rawValue)
        HString.fromWide(copied, length: Int64(length))
    }

    public unsafe func getTrustLevel(value: CPointer<Int32>): HRESULT {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return E_POINTER
        }
        let v = vtbl()
        HRESULT(v.GetTrustLevel(liveRaw, value))
    }
}

@C
public struct IActivationFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var ActivateInstance: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }

    public init() {}
}

func wrapIActivationFactoryOwned(raw: CPointer<Unit>): IActivationFactory {
    IActivationFactory(raw, ownsReference: true)
}

func wrapIActivationFactoryBorrowed(raw: CPointer<Unit>): IActivationFactory {
    IActivationFactory(raw)
}

public class IActivationFactory <: InterfaceWrapperBase & ComInterface & RuntimeName {

    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func fromRaw(raw: CPointer<Unit>): IActivationFactory {
        IActivationFactory(raw, ownsReference: true)
    }

    public static func fromRawBorrowed(raw: CPointer<Unit>): IActivationFactory {
        IActivationFactory(raw)
    }

    public static func iid(): GUID {
        IID_IACTIVATIONFACTORY
    }

    public static func descriptor(): InterfaceDescriptor<IActivationFactory> {
        InterfaceDescriptor<IActivationFactory>(
            "IActivationFactory",
            IID_IACTIVATIONFACTORY,
            IInspectable.descriptor(),
            wrapIActivationFactoryOwned,
            wrapIActivationFactoryBorrowed
        )
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        InterfaceDescriptorSchema(
            "IActivationFactory",
            IID_IACTIVATIONFACTORY,
            IInspectable.descriptorSchema(),
            "IActivationFactoryVtbl",
            "IActivationFactory",
            "IActivationFactory_Impl",
            Array<InterfaceMethodSchema>(0, { _ => InterfaceMethodSchema("", 0, Array<String>(0, { _ => "" }), "") })
        )
    }

    public func asIInspectable(): IInspectable {
        IInspectable(asRaw())
    }

    public unsafe func vtbl(): IActivationFactoryVtbl {
        readVtbl<IActivationFactoryVtbl>(IActivationFactoryVtbl())
    }

    public unsafe func activateInstance(result: CPointer<CPointer<Unit>>): HRESULT {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return E_POINTER
        }
        let v = vtbl()
        HRESULT(v.ActivateInstance(liveRaw, result))
    }
}

public unsafe func queryInterfaceRaw(source: CPointer<Unit>, targetIid: GUID): Option<CPointer<Unit>> {
    if (source.isNull()) {
        return None
    }

    var iid = targetIid
    var result = CPointer<Unit>()
    let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(source).read()
    let vtbl = vtblPtr.read()
    let hr = HRESULT(vtbl.QueryInterface(source, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout result)))

    if (hr.succeeded() && !result.isNull()) {
        Some(result)
    } else {
        None
    }
}

public unsafe func queryInterfaceAs<T>(source: CPointer<Unit>, descriptor: InterfaceDescriptor<T>): Option<T> {
    match (queryInterfaceRaw(source, descriptor.iid)) {
        case Some(raw) => Some(descriptor.wrapOwned(raw))
        case None => None
    }
}

public unsafe func queryInterfaceAs<T>(source: ComInterface, descriptor: InterfaceDescriptor<T>): Option<T> {
    queryInterfaceAs(source.asRaw(), descriptor)
}

func copyWideUnits(ptr: CPointer<UInt16>, length: UInt32): Array<UInt16> {
    if (ptr.isNull() || length == 0u32) {
        return Array<UInt16>(0, { _ => 0u16 })
    }
    Array<UInt16>(Int64(length), { index =>
        unsafe { (ptr + index).read() }
    })
}

func combaseModule(): CPointer<Unit> {
    if (cachedCombaseModule.isNotNull()) {
        return cachedCombaseModule
    }

    unsafe {
        let handle = acquireArrayRawData(COMBASE_DLL_NAME)
        try {
            let module = LoadLibraryW(handle.pointer)
            if (module.isNull()) {
                throw Exception("failed to load combase.dll")
            }
            cachedCombaseModule = module
            return module
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

func resolveCombaseProc(name: Array<UInt8>): CPointer<Unit> {
    let module = combaseModule()
    unsafe {
        let handle = acquireArrayRawData(name)
        try {
            let proc = GetProcAddress(module, handle.pointer)
            if (proc.isNull()) {
                throw Exception("failed to resolve combase proc")
            }
            proc
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

func windowsGetStringRawBufferProc(): CPointer<Unit> {
    if (cachedWindowsGetStringRawBufferProc.isNotNull()) {
        return cachedWindowsGetStringRawBufferProc
    }
    let proc = resolveCombaseProc(WINDOWS_GET_STRING_RAW_BUFFER_PROC_NAME)
    cachedWindowsGetStringRawBufferProc = proc
    proc
}

func windowsDeleteStringProc(): CPointer<Unit> {
    if (cachedWindowsDeleteStringProc.isNotNull()) {
        return cachedWindowsDeleteStringProc
    }
    let proc = resolveCombaseProc(WINDOWS_DELETE_STRING_PROC_NAME)
    cachedWindowsDeleteStringProc = proc
    proc
}

func roGetActivationFactoryProc(): CPointer<Unit> {
    if (cachedRoGetActivationFactoryProc.isNotNull()) {
        return cachedRoGetActivationFactoryProc
    }
    let proc = resolveCombaseProc(RO_GET_ACTIVATION_FACTORY_PROC_NAME)
    cachedRoGetActivationFactoryProc = proc
    proc
}

func windowsGetStringRawBufferAbi(handle: CPointer<Unit>, length: CPointer<UInt32>): CPointer<UInt16> {
    let proc = windowsGetStringRawBufferProc()
    let funcPtr = CFunc<(CPointer<Unit>, CPointer<UInt32>) -> CPointer<UInt16>>(proc)
    unsafe {
        funcPtr(handle, length)
    }
}

func windowsDeleteStringAbi(handle: CPointer<Unit>): Unit {
    if (handle.isNull()) {
        return
    }
    let proc = windowsDeleteStringProc()
    let funcPtr = CFunc<(CPointer<Unit>) -> Int32>(proc)
    unsafe {
        funcPtr(handle)
    }
}

public func getActivationFactoryByName<T>(
    runtimeName: String,
    descriptor: InterfaceDescriptor<T>
): Result<T> where T <: ComInterface {
    let classId = HString(runtimeName)
    try {
        getActivationFactory(classId, descriptor)
    } finally {
        classId.close()
    }
}

public func getActivationFactory<T>(
    classId: HString,
    descriptor: InterfaceDescriptor<T>
): Result<T> where T <: ComInterface {
    let proc = roGetActivationFactoryProc()
    if (proc.isNull()) {
        return Result<T>.Err(WinResultError.fromHRESULT(E_NOINTERFACE))
    }

    var iid = descriptor.iid
    var raw = CPointer<Unit>()
    let call = CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32>(proc)
    let hr = unsafe {
        HRESULT(
            call(
                classId.asRaw(),
                CPointer<GUID>(inout iid),
                CPointer<CPointer<Unit>>(inout raw)
            )
        )
    }
    if (hr.failed()) {
        return Result<T>.Err(WinResultError.fromHRESULT(hr))
    }
    if (raw.isNull()) {
        return Result<T>.Err(WinResultError.fromHRESULT(E_POINTER))
    }
    Result<T>.Ok(descriptor.wrapOwned(raw))
}
