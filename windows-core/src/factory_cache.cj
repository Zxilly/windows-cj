package windows_core

import windows_interface
import std.sync.*

let DLL_GET_ACTIVATION_FACTORY_PROC_NAME: Array<UInt8> = [
    0x44u8, 0x6Cu8, 0x6Cu8, 0x47u8, 0x65u8, 0x74u8, 0x41u8, 0x63u8,
    0x74u8, 0x69u8, 0x76u8, 0x61u8, 0x74u8, 0x69u8, 0x6Fu8, 0x6Eu8,
    0x46u8, 0x61u8, 0x63u8, 0x74u8, 0x6Fu8, 0x72u8, 0x79u8, 0u8
]
let COMBASE_DLL_NAME: Array<UInt8> = [
    0x63u8, 0x6Fu8, 0x6Du8, 0x62u8, 0x61u8, 0x73u8, 0x65u8, 0x2Eu8,
    0x64u8, 0x6Cu8, 0x6Cu8, 0u8
]
let DLL_SUFFIX: Array<UInt8> = [0x2Eu8, 0x64u8, 0x6Cu8, 0x6Cu8, 0u8]
let LOAD_LIBRARY_SEARCH_DEFAULT_DIRS: UInt32 = 0x00001000u32
let RO_GET_ACTIVATION_FACTORY_PROC_NAME: Array<UInt8> = [
    0x52u8, 0x6Fu8, 0x47u8, 0x65u8, 0x74u8, 0x41u8, 0x63u8, 0x74u8,
    0x69u8, 0x76u8, 0x61u8, 0x74u8, 0x69u8, 0x6Fu8, 0x6Eu8, 0x46u8,
    0x61u8, 0x63u8, 0x74u8, 0x6Fu8, 0x72u8, 0x79u8, 0u8
]
let CO_INCREMENT_MTA_USAGE_PROC_NAME: Array<UInt8> = [
    0x43u8, 0x6Fu8, 0x49u8, 0x6Eu8, 0x63u8, 0x72u8, 0x65u8, 0x6Du8,
    0x65u8, 0x6Eu8, 0x74u8, 0x4Du8, 0x54u8, 0x41u8, 0x55u8, 0x73u8,
    0x61u8, 0x67u8, 0x65u8, 0u8
]

var cachedCombaseModule: CPointer<Unit> = CPointer<Unit>()
var cachedRoGetActivationFactoryProc: CPointer<Unit> = CPointer<Unit>()
var cachedCoIncrementMTAUsageProc: CPointer<Unit> = CPointer<Unit>()
let combaseInitMutex = Mutex()

foreign {
    func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CPointer<UInt8>): CPointer<Unit>
    func LoadLibraryExA(lpLibFileName: CPointer<UInt8>, hFile: CPointer<Unit>, dwFlags: UInt32): CPointer<Unit>
    func FreeLibrary(hLibModule: CPointer<Unit>): Int32
}

func combaseModule(): CPointer<Unit> {
    // Double-checked: race between two threads must not call LoadLibraryExA twice
    // and stash conflicting handles into the global slot.
    if (cachedCombaseModule.isNotNull()) {
        return cachedCombaseModule
    }
    synchronized(combaseInitMutex) {
        if (cachedCombaseModule.isNotNull()) {
            return cachedCombaseModule
        }
        unsafe {
            let libraryHandle = acquireArrayRawData(COMBASE_DLL_NAME)
            try {
                let module = LoadLibraryExA(
                    libraryHandle.pointer,
                    CPointer<Unit>(),
                    LOAD_LIBRARY_SEARCH_DEFAULT_DIRS
                )
                if (module.isNull()) {
                    throw Exception("failed to load combase.dll")
                }
                cachedCombaseModule = module
                return module
            } finally {
                releaseArrayRawData(libraryHandle)
            }
        }
    }
}

func resolveCombaseProc(name: Array<UInt8>): CPointer<Unit> {
    let module = combaseModule()
    unsafe {
        let procHandle = acquireArrayRawData(name)
        try {
            let proc = GetProcAddress(module, procHandle.pointer)
            if (proc.isNull()) {
                throw Exception("failed to resolve combase proc")
            }
            proc
        } finally {
            releaseArrayRawData(procHandle)
        }
    }
}

func roGetActivationFactoryProc(): CPointer<Unit> {
    if (cachedRoGetActivationFactoryProc.isNotNull()) {
        return cachedRoGetActivationFactoryProc
    }
    synchronized(combaseInitMutex) {
        if (cachedRoGetActivationFactoryProc.isNotNull()) {
            return cachedRoGetActivationFactoryProc
        }
        let proc = resolveCombaseProc(RO_GET_ACTIVATION_FACTORY_PROC_NAME)
        cachedRoGetActivationFactoryProc = proc
        return proc
    }
}

func coIncrementMTAUsageProc(): CPointer<Unit> {
    if (cachedCoIncrementMTAUsageProc.isNotNull()) {
        return cachedCoIncrementMTAUsageProc
    }
    synchronized(combaseInitMutex) {
        if (cachedCoIncrementMTAUsageProc.isNotNull()) {
            return cachedCoIncrementMTAUsageProc
        }
        let proc = resolveCombaseProc(CO_INCREMENT_MTA_USAGE_PROC_NAME)
        cachedCoIncrementMTAUsageProc = proc
        return proc
    }
}

func callRoGetActivationFactory(
    activatableClassId: CPointer<Unit>,
    iid: CPointer<GUID>,
    factory: CPointer<CPointer<Unit>>
): Int32 {
    let proc = roGetActivationFactoryProc()
    let funcPtr = CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32>(proc)
    unsafe {
        funcPtr(activatableClassId, iid, factory)
    }
}

func callCoIncrementMTAUsage(cookie: CPointer<CPointer<Unit>>): Int32 {
    let proc = coIncrementMTAUsageProc()
    let funcPtr = CFunc<(CPointer<CPointer<Unit>>) -> Int32>(proc)
    unsafe {
        funcPtr(cookie)
    }
}

func queryFactoryInterface<I>(
    rawFactory: CPointer<Unit>,
    descriptor: InterfaceDescriptor<I>
): Result<I> where I <: ComInterface {
    if (rawFactory.isNull()) {
        return Result<I>.Err(WinError(E_POINTER))
    }

    let owner = IUnknown.fromAbiTake(rawFactory)
    try {
        match (unsafe { queryInterfaceAs(rawFactory, descriptor) }) {
            case Some(value) =>
                Result<I>.Ok(value)
            case None =>
                Result<I>.Err(WinError(E_NOINTERFACE))
        }
    } finally {
        owner.close()
    }
}

func loadSystemActivationFactory<I>(
    runtimeName: String,
    descriptor: InterfaceDescriptor<I>
): Result<I> where I <: ComInterface {
    let classId = HString(runtimeName)
    try {
        var iid = descriptor.iid
        var raw = CPointer<Unit>()
        var hr = unsafe {
            HRESULT(
                callRoGetActivationFactory(
                    classId.asRaw(),
                    CPointer<GUID>(inout iid),
                    CPointer<CPointer<Unit>>(inout raw)
                )
            )
        }

        if (hr.value == CO_E_NOTINITIALIZED.value) {
            var cookie = CPointer<Unit>()
            callCoIncrementMTAUsage(CPointer<CPointer<Unit>>(inout cookie))
            iid = descriptor.iid
            raw = CPointer<Unit>()
            hr = unsafe {
                HRESULT(
                    callRoGetActivationFactory(
                        classId.asRaw(),
                        CPointer<GUID>(inout iid),
                        CPointer<CPointer<Unit>>(inout raw)
                    )
                )
            }
        }

        if (hr.failed()) {
            return Result<I>.Err(WinError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<I>.Err(WinError(E_POINTER))
        }

        queryFactoryInterface(raw, descriptor)
    } finally {
        classId.close()
    }
}

func findPreviousNamespaceDot(bytes: Array<UInt8>, fromIndex: Int64): Int64 {
    if (bytes.size == 0) {
        return -1
    }

    var index = fromIndex
    if (index >= bytes.size) {
        index = Int64(bytes.size) - 1
    }
    while (index >= 0) {
        if (bytes[index] == 0x2Eu8) {
            return index
        }
        index -= 1
    }
    -1
}

func makeDllName(runtimeNameBytes: Array<UInt8>, prefixLength: Int64): Array<UInt8> {
    Array<UInt8>(prefixLength + Int64(DLL_SUFFIX.size), { index =>
        if (index < prefixLength) {
            runtimeNameBytes[index]
        } else {
            DLL_SUFFIX[index - prefixLength]
        }
    })
}

func loadRegFreeFactoryFromDll<I>(
    runtimeName: String,
    libraryName: Array<UInt8>,
    descriptor: InterfaceDescriptor<I>
): Result<I> where I <: ComInterface {
    unsafe {
        let libraryHandle = acquireArrayRawData(libraryName)
        try {
            let module = LoadLibraryExA(
                libraryHandle.pointer,
                CPointer<Unit>(),
                LOAD_LIBRARY_SEARCH_DEFAULT_DIRS
            )
            if (module.isNull()) {
                return Result<I>.Err(WinError(E_NOINTERFACE))
            }

            let procHandle = acquireArrayRawData(DLL_GET_ACTIVATION_FACTORY_PROC_NAME)
            try {
                let address = GetProcAddress(module, procHandle.pointer)
                if (address.isNull()) {
                    FreeLibrary(module)
                    return Result<I>.Err(WinError(E_NOINTERFACE))
                }

                let classId = HString(runtimeName)
                try {
                    let getActivationFactory = CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32>(address)
                    var rawFactory = CPointer<Unit>()
                    let hr = HRESULT(
                        getActivationFactory(
                            classId.asRaw(),
                            CPointer<CPointer<Unit>>(inout rawFactory)
                        )
                    )
                    if (hr.failed() || rawFactory.isNull()) {
                        FreeLibrary(module)
                        if (hr.failed()) {
                            return Result<I>.Err(WinError.fromHRESULT(hr))
                        }
                        return Result<I>.Err(WinError(E_POINTER))
                    }

                    queryFactoryInterface(rawFactory, descriptor)
                } finally {
                    classId.close()
                }
            } finally {
                releaseArrayRawData(procHandle)
            }
        } finally {
            releaseArrayRawData(libraryHandle)
        }
    }
}

func loadRegFreeActivationFactory<I>(
    runtimeName: String,
    descriptor: InterfaceDescriptor<I>
): Result<I> where I <: ComInterface {
    let runtimeNameBytes = runtimeName.toArray()
    var searchIndex = Int64(runtimeNameBytes.size) - 1
    while (searchIndex >= 0) {
        let dotIndex = findPreviousNamespaceDot(runtimeNameBytes, searchIndex)
        if (dotIndex < 0) {
            break
        }

        let libraryName = makeDllName(runtimeNameBytes, dotIndex)
        match (loadRegFreeFactoryFromDll(runtimeName, libraryName, descriptor)) {
            case Result<I>.Ok(value) =>
                return Result<I>.Ok(value)
            case Result<I>.Err(_) =>
                ()
        }
        searchIndex = dotIndex - 1
    }

    Result<I>.Err(WinError.fromHRESULT(REGDB_E_CLASSNOTREG))
}

func loadActivationFactory<I>(
    runtimeName: String,
    descriptor: InterfaceDescriptor<I>
): Result<I> where I <: ComInterface {
    match (loadSystemActivationFactory(runtimeName, descriptor)) {
        case Result<I>.Ok(value) =>
            Result<I>.Ok(value)
        case Result<I>.Err(error) =>
            if (error.code().value == REGDB_E_CLASSNOTREG.value) {
                return loadRegFreeActivationFactory(runtimeName, descriptor)
            }
            Result<I>.Err(error)
    }
}

public func factory<C, I>(): Result<I> where C <: RuntimeName, I <: ComInterface & Interface<I> {
    loadActivationFactory(C.runtimeName(), I.descriptor())
}

public func loadFactory<C, I>(): Result<I> where C <: RuntimeName, I <: ComInterface & Interface<I> {
    loadActivationFactory(C.runtimeName(), I.descriptor())
}

public func activationFactory<C>(): Result<windows_interface.IActivationFactory> where C <: RuntimeName {
    loadActivationFactory(C.runtimeName(), windows_interface.IActivationFactory.descriptor())
}

public class FactoryCache<C, I> <: Resource where C <: RuntimeName, I <: ComInterface & Interface<I> {
    private let descriptor: InterfaceDescriptor<I>
    private let mutex = Mutex()
    private var cached: Option<InterfaceHandle<I>> = None
    private var closed: Bool = false

    public init(descriptor: InterfaceDescriptor<I>) {
        this.descriptor = descriptor
    }

    public static func new(descriptor: InterfaceDescriptor<I>): FactoryCache<C, I> {
        FactoryCache<C, I>(descriptor)
    }

    public func runtimeName(): String {
        C.runtimeName()
    }

    public func call<R>(callback: (() -> Result<I>) -> Result<R>): Result<R> {
        call({ =>
            loadActivationFactory(C.runtimeName(), descriptor)
        }, callback)
    }

    public func call<R>(
        loader: () -> Result<I>,
        callback: (() -> Result<I>) -> Result<R>
    ): Result<R> {
        // Expose an accessor instead of a wrapper so callers do not capture an object this method would have to invalidate.
        callback({ =>
            factory(loader)
        })
    }

    public func factory(): Result<I> {
        factory({ =>
            loadActivationFactory(C.runtimeName(), descriptor)
        })
    }

    public func factory(loader: () -> Result<I>): Result<I> {
        var cachedClone: Option<InterfaceHandle<I>> = None
        var rejected = false
        synchronized(mutex) {
            if (closed) {
                rejected = true
            } else {
                match (cached) {
                    case Some(pointer) =>
                        cachedClone = Some(pointer.retain())
                    case None =>
                        ()
                }
            }
        }
        if (rejected) {
            return Result<I>.Err(WinError(E_POINTER))
        }
        match (cachedClone) {
            case Some(pointer) =>
                return Result<I>.Ok(descriptor.takeFromAbi(pointer.intoAbi()))
            case None => ()
        }

        loadFactory(loader)
    }

    public func loadFactory(): Result<I> {
        loadActivationFactory(C.runtimeName(), descriptor)
    }

    public func loadFactory(loader: () -> Result<I>): Result<I> {
        match (loader()) {
            case Result<I>.Ok(factory) =>
                match (factory as InterfaceWrapperBase) {
                    case Some(wrapper) =>
                        var shouldCache = false
                        match (unsafe { wrapper.query(IAgileObject.descriptor()) }) {
                            case Some(agile) =>
                                agile.close()
                                shouldCache = true
                            case None =>
                                ()
                        }
                        if (shouldCache) {
                            let cachedPointer = InterfaceHandle<I>.retainInterface(factory, descriptor)
                            match (storeCachedIfAbsent(cachedPointer)) {
                                case Result<InterfaceHandle<I>>.Ok(resultPointer) =>
                                    wrapper.close()
                                    return Result<I>.Ok(descriptor.takeFromAbi(resultPointer.intoAbi()))
                                case Result<InterfaceHandle<I>>.Err(error) =>
                                    wrapper.close()
                                    return Result<I>.Err(error)
                            }
                        }
                        wrapper.addRef()
                        let raw = wrapper.asRaw()
                        wrapper.close()
                        return Result<I>.Ok(descriptor.takeFromAbi(raw))
                    case None =>
                        return Result<I>.Ok(factory)
                }
            case Result<I>.Err(error) =>
                Result<I>.Err(error)
        }
    }

    public func isClosed(): Bool {
        synchronized(mutex) {
            closed
        }
    }

    public func close(): Unit {
        var cachedPointer: Option<InterfaceHandle<I>> = None
        synchronized(mutex) {
            if (closed) {
                return
            }
            closed = true
            match (cached) {
                case Some(pointer) =>
                    cachedPointer = Some(pointer)
                case None =>
                    ()
            }
            cached = None
        }
        match (cachedPointer) {
            case Some(pointer) => pointer.close()
            case None => ()
        }
    }

    private func storeCachedIfAbsent(pointer: InterfaceHandle<I>): Result<InterfaceHandle<I>> {
        var result: Option<InterfaceHandle<I>> = None
        var closeIncoming = false
        var rejected = false
        synchronized(mutex) {
            if (closed) {
                closeIncoming = true
                rejected = true
            } else {
                match (cached) {
                    case Some(existing) =>
                        result = Some(existing.retain())
                        closeIncoming = true
                    case None =>
                        cached = Some(pointer)
                        result = Some(pointer.retain())
                }
            }
        }
        if (closeIncoming) {
            pointer.close()
        }
        if (rejected) {
            return Result<InterfaceHandle<I>>.Err(WinError(E_POINTER))
        }
        match (result) {
            case Some(value) => Result<InterfaceHandle<I>>.Ok(value)
            case None => throw IllegalStateException("FactoryCache failed to resolve a cached pointer")
        }
    }
}
