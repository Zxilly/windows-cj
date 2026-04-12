package windows_implement

import std.sync.*
import windows_interface.*

@C
public struct IWeakReferenceVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Resolve: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL }

    public init() {}
}

@C
public struct IWeakReferenceSourceVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var GetWeakReference: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL }

    public init() {}
}

public let IID_IWEAKREFERENCE = GUID.fromValues(0x00000037u32, 0x0000u16, 0x0000u16, 0xC0u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x46u8)
public let IID_IWEAKREFERENCESOURCE = GUID.fromValues(0x00000038u32, 0x0000u16, 0x0000u16, 0xC0u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x46u8)

func wrapIWeakReferenceOwned(raw: CPointer<Unit>): IWeakReference {
    IWeakReference(raw, ownsReference: true)
}

func wrapIWeakReferenceBorrowed(raw: CPointer<Unit>): IWeakReference {
    IWeakReference(raw)
}

func wrapIWeakReferenceSourceOwned(raw: CPointer<Unit>): IWeakReferenceSource {
    IWeakReferenceSource(raw, ownsReference: true)
}

func wrapIWeakReferenceSourceBorrowed(raw: CPointer<Unit>): IWeakReferenceSource {
    IWeakReferenceSource(raw)
}

public class IWeakReference <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func iid(): GUID {
        IID_IWEAKREFERENCE
    }

    public static func descriptor(): InterfaceDescriptor<IWeakReference> {
        InterfaceDescriptor<IWeakReference>("IWeakReference", IID_IWEAKREFERENCE, wrapIWeakReferenceOwned, wrapIWeakReferenceBorrowed)
    }

    public unsafe func vtbl(): IWeakReferenceVtbl {
        readVtbl<IWeakReferenceVtbl>(IWeakReferenceVtbl())
    }

    public unsafe func resolve<T>(descriptor: InterfaceDescriptor<T>): Option<T> where T <: ComInterface {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return None
        }

        var iid = descriptor.iid
        var raw = CPointer<Unit>()
        let hr = vtbl().Resolve(liveRaw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout raw))
        if (hr != S_OK || raw.isNull()) {
            return None
        }
        Some(descriptor.wrapOwned(raw))
    }
}

public class IWeakReferenceSource <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func iid(): GUID {
        IID_IWEAKREFERENCESOURCE
    }

    public static func descriptor(): InterfaceDescriptor<IWeakReferenceSource> {
        InterfaceDescriptor<IWeakReferenceSource>("IWeakReferenceSource", IID_IWEAKREFERENCESOURCE, wrapIWeakReferenceSourceOwned, wrapIWeakReferenceSourceBorrowed)
    }

    public unsafe func vtbl(): IWeakReferenceSourceVtbl {
        readVtbl<IWeakReferenceSourceVtbl>(IWeakReferenceSourceVtbl())
    }

    public unsafe func getWeakReference(): Option<IWeakReference> {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return None
        }

        var raw = CPointer<Unit>()
        let hr = vtbl().GetWeakReference(liveRaw, CPointer<CPointer<Unit>>(inout raw))
        if (hr != S_OK || raw.isNull()) {
            return None
        }
        Some(IWeakReference(raw, ownsReference: true))
    }
}

public interface WeakReferenceOwner {
    func weakReferenceIdentity(): CPointer<Unit>
    func weakReferenceIsAgileEnabled(): Bool
    func weakReferenceQueryInterface(iid: GUID, ppvObject: CPointer<CPointer<Unit>>): Int32
}

class WeakReferenceTearOff {
    private let strongVtblHandle: CPointerHandle<IWeakReferenceSourceVtbl>
    private let weakVtblHandle: CPointerHandle<IWeakReferenceVtbl>
    private let slotHandle: CPointerHandle<ComBox>
    private let weakCount = AtomicInt64(1)
    private let rootKey: UIntNative
    private let weakKey: UIntNative
    private let cacheMutex = Mutex()
    private var ownerRaw: CPointer<Unit>
    private var weakMarshaler: Option<IMarshal> = None
    private var alive: Bool = true
    private var registered: Bool = false

    public init(ownerRaw: CPointer<Unit>) {
        this.ownerRaw = ownerRaw

        let strongVtblArray = Array<IWeakReferenceSourceVtbl>(1, { _ => buildIWeakReferenceSourceVtbl() })
        let weakVtblArray = Array<IWeakReferenceVtbl>(1, { _ => buildIWeakReferenceVtbl() })
        strongVtblHandle = unsafe { acquireArrayRawData(strongVtblArray) }
        weakVtblHandle = unsafe { acquireArrayRawData(weakVtblArray) }

        let strongRaw = CPointer<Unit>(strongVtblHandle.pointer)
        let weakRaw = CPointer<Unit>(weakVtblHandle.pointer)
        let slots = Array<ComBox>(2, { index =>
            if (index == 0) {
                ComBox(strongRaw, rootOffset: 0, slotIndex: 0, slotCount: 2)
            } else {
                ComBox(weakRaw, rootOffset: 1, slotIndex: 1, slotCount: 2)
            }
        })
        slotHandle = unsafe { acquireArrayRawData(slots) }

        rootKey = CPointer<Unit>(slotHandle.pointer).toUIntNative()
        weakKey = CPointer<Unit>(unsafe { slotHandle.pointer + 1 }).toUIntNative()

        unsafe {
            let strongSlotPtr = slotHandle.pointer
            var strongSlot = strongSlotPtr.read()
            strongSlot.rootOffset = 0
            strongSlot.rootKey = rootKey
            strongSlotPtr.write(strongSlot)

            let weakSlotPtr = slotHandle.pointer + 1
            var weakSlot = weakSlotPtr.read()
            weakSlot.rootOffset = 1
            weakSlot.rootKey = rootKey
            weakSlotPtr.write(weakSlot)
        }

        comRegistryInsert(rootKey, this)
        comSlotRegistryInsert(weakKey, rootKey)
        registered = true
    }

    public func bind(ownerRaw: CPointer<Unit>): Unit {
        this.ownerRaw = ownerRaw
        if (ownerRaw.isNull()) {
            alive = false
        }
    }

    public func strongRaw(): CPointer<Unit> {
        CPointer<Unit>(slotHandle.pointer)
    }

    public func weakRaw(): CPointer<Unit> {
        CPointer<Unit>(unsafe { slotHandle.pointer + 1 })
    }

    public func writeStrongReference(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        if (ppvObject.isNull()) {
            return E_POINTER
        }
        if (ownerRaw.isNull() || !alive) {
            unsafe { ppvObject.write(CPointer<Unit>()) }
            return E_NOINTERFACE
        }
        addRefOwner()
        unsafe { ppvObject.write(strongRaw()) }
        S_OK
    }

    public func writeWeakReference(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        if (ppvObject.isNull()) {
            return E_POINTER
        }
        addWeakRef()
        unsafe { ppvObject.write(weakRaw()) }
        S_OK
    }

    public func queryStrong(iidPtr: CPointer<GUID>, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER
            }
            if (iidPtr.isNull()) {
                ppvObject.write(CPointer<Unit>())
                return E_POINTER
            }
            let iid = iidPtr.read()
            if (iid == IID_IWEAKREFERENCESOURCE) {
                return writeStrongReference(ppvObject)
            }
            queryOwner(iid, ppvObject)
        }
    }

    public func queryWeak(iidPtr: CPointer<GUID>, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER
            }
            if (iidPtr.isNull()) {
                ppvObject.write(CPointer<Unit>())
                return E_POINTER
            }

            let iid = iidPtr.read()
            if (iid == IID_IWEAKREFERENCE || iid == IID_IUNKNOWN || iid == IID_IAGILEOBJECT) {
                return writeWeakReference(ppvObject)
            }

            if (iid == IID_IMARSHAL && ownerRaw.isNotNull()) {
                return cloneWeakMarshaler(ppvObject)
            }

            ppvObject.write(CPointer<Unit>())
            E_NOINTERFACE
        }
    }

    public func addWeakRef(): UInt32 {
        UInt32(weakCount.fetchAdd(1) + 1)
    }

    public func releaseWeakRef(): UInt32 {
        let oldValue = weakCount.fetchSub(1)
        if (oldValue <= 0) {
            weakCount.fetchAdd(1)
            throw IllegalStateException("WeakReferenceTearOff over-release")
        }
        let remaining = UInt32(oldValue - 1)
        if (remaining == 0u32) {
            destroy()
        }
        remaining
    }

    public func resolve(iidPtr: CPointer<GUID>, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER
            }
            if (iidPtr.isNull()) {
                ppvObject.write(CPointer<Unit>())
                return E_POINTER
            }
            if (ownerRaw.isNull() || !alive) {
                ppvObject.write(CPointer<Unit>())
                return S_OK
            }
            queryOwner(iidPtr.read(), ppvObject)
        }
    }

    public func onObjectDestroyed(): Unit {
        if (!alive) {
            return
        }
        alive = false
        ownerRaw = CPointer<Unit>()
        releaseWeakRef()
    }

    public func addRefOwner(): UInt32 {
        if (ownerRaw.isNull()) {
            return 0u32
        }
        unsafe {
            let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(ownerRaw).read()
            vtblPtr.read().AddRef(ownerRaw)
        }
    }

    public func releaseOwner(): UInt32 {
        if (ownerRaw.isNull()) {
            return 0u32
        }
        unsafe {
            let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(ownerRaw).read()
            vtblPtr.read().Release(ownerRaw)
        }
    }

    private func queryOwner(iid: GUID, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        if (ownerRaw.isNull() || !alive) {
            unsafe { ppvObject.write(CPointer<Unit>()) }
            return E_NOINTERFACE
        }
        var iidCopy = iid
        unsafe {
            let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(ownerRaw).read()
            vtblPtr.read().QueryInterface(ownerRaw, CPointer<GUID>(inout iidCopy), ppvObject)
        }
    }

    private func cloneWeakMarshaler(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        match (ensureWeakMarshaler()) {
            case Some(marshaler) =>
                cloneMarshaler(marshaler, ppvObject)
            case None =>
                unsafe { ppvObject.write(CPointer<Unit>()) }
                E_NOINTERFACE
        }
    }

    private func ensureWeakMarshaler(): Option<IMarshal> {
        synchronized(cacheMutex) {
            match (weakMarshaler) {
                case Some(marshaler) =>
                    if (marshaler.asRaw().isNotNull()) {
                        return Some(marshaler)
                    }
                    weakMarshaler = None
                case None => ()
            }

            match (createFreeThreadedMarshaler(weakRaw())) {
                case Some(marshaler) =>
                    weakMarshaler = Some(marshaler)
                    Some(marshaler)
                case None =>
                    None
            }
        }
    }

    private func destroy(): Unit {
        synchronized(cacheMutex) {
            if (!registered) {
                return
            }
            match (weakMarshaler) {
                case Some(marshaler) =>
                    marshaler.close()
                    weakMarshaler = None
                case None => ()
            }
            comSlotRegistryRemove(weakKey)
            comRegistryRemove(rootKey)
            registered = false
            unsafe { releaseArrayRawData(slotHandle) }
            unsafe { releaseArrayRawData(weakVtblHandle) }
            unsafe { releaseArrayRawData(strongVtblHandle) }
        }
    }
}

func lookupWeakReferenceTearOff(this_: CPointer<Unit>): Option<WeakReferenceTearOff> {
    if (this_.isNull()) {
        return None
    }
    let lookupKey = unsafe { rootRegistryKeyFromRaw(this_) }
    match (comRegistryLookup(lookupKey)) {
        case Some(obj) =>
            match (obj) {
                case tearOff: WeakReferenceTearOff => Some(tearOff)
                case _ => None
            }
        case None =>
            None
    }
}

@C
public func weakReferenceSourceQueryInterfaceThunk(
    this_: CPointer<Unit>,
    iid: CPointer<GUID>,
    ppvObject: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupWeakReferenceTearOff(this_)) {
        case Some(tearOff) => tearOff.queryStrong(iid, ppvObject)
        case None =>
            unsafe {
                if (ppvObject.isNotNull()) {
                    ppvObject.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE
    }
}

@C
public func weakReferenceSourceAddRefThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupWeakReferenceTearOff(this_)) {
        case Some(tearOff) => tearOff.addRefOwner()
        case None => 0u32
    }
}

@C
public func weakReferenceSourceReleaseThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupWeakReferenceTearOff(this_)) {
        case Some(tearOff) => tearOff.releaseOwner()
        case None => 0u32
    }
}

@C
public func weakReferenceSourceGetWeakReferenceThunk(
    this_: CPointer<Unit>,
    ppvObject: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupWeakReferenceTearOff(this_)) {
        case Some(tearOff) => tearOff.writeWeakReference(ppvObject)
        case None =>
            unsafe {
                if (ppvObject.isNotNull()) {
                    ppvObject.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE
    }
}

@C
public func weakReferenceQueryInterfaceThunk(
    this_: CPointer<Unit>,
    iid: CPointer<GUID>,
    ppvObject: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupWeakReferenceTearOff(this_)) {
        case Some(tearOff) => tearOff.queryWeak(iid, ppvObject)
        case None =>
            unsafe {
                if (ppvObject.isNotNull()) {
                    ppvObject.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE
    }
}

@C
public func weakReferenceAddRefThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupWeakReferenceTearOff(this_)) {
        case Some(tearOff) => tearOff.addWeakRef()
        case None => 0u32
    }
}

@C
public func weakReferenceReleaseThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupWeakReferenceTearOff(this_)) {
        case Some(tearOff) => tearOff.releaseWeakRef()
        case None => 0u32
    }
}

@C
public func weakReferenceResolveThunk(
    this_: CPointer<Unit>,
    iid: CPointer<GUID>,
    ppvObject: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupWeakReferenceTearOff(this_)) {
        case Some(tearOff) => tearOff.resolve(iid, ppvObject)
        case None =>
            unsafe {
                if (ppvObject.isNotNull()) {
                    ppvObject.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE
    }
}

func buildIWeakReferenceSourceVtbl(): IWeakReferenceSourceVtbl {
    var vtbl = IWeakReferenceSourceVtbl()
    vtbl.base_.QueryInterface = weakReferenceSourceQueryInterfaceThunk
    vtbl.base_.AddRef = weakReferenceSourceAddRefThunk
    vtbl.base_.Release = weakReferenceSourceReleaseThunk
    vtbl.GetWeakReference = weakReferenceSourceGetWeakReferenceThunk
    vtbl
}

func buildIWeakReferenceVtbl(): IWeakReferenceVtbl {
    var vtbl = IWeakReferenceVtbl()
    vtbl.base_.QueryInterface = weakReferenceQueryInterfaceThunk
    vtbl.base_.AddRef = weakReferenceAddRefThunk
    vtbl.base_.Release = weakReferenceReleaseThunk
    vtbl.Resolve = weakReferenceResolveThunk
    vtbl
}

public class WeakRefCount {
    private var raw: CPointer<Unit>
    private var tearOff: Option<WeakReferenceTearOff> = None
    private var objectMarshaler: Option<IMarshal> = None
    private let stateMutex = Mutex()

    public init(raw: CPointer<Unit>) {
        this.raw = raw
    }

    public func bind(raw: CPointer<Unit>): Unit {
        synchronized(stateMutex) {
            this.raw = raw
            match (tearOff) {
                case Some(value) => value.bind(raw)
                case None => ()
            }
        }
    }

    public func onObjectDestroyed(): Unit {
        synchronized(stateMutex) {
            raw = CPointer<Unit>()
            match (objectMarshaler) {
                case Some(marshaler) =>
                    marshaler.close()
                    objectMarshaler = None
                case None => ()
            }
            match (tearOff) {
                case Some(value) => value.onObjectDestroyed()
                case None => ()
            }
        }
    }

    public func writeWeakReferenceSource(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        let value = ensureTearOff()
        value.writeStrongReference(ppvObject)
    }

    public func writeObjectMarshaler(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        if (ppvObject.isNull()) {
            return E_POINTER
        }
        if (raw.isNull()) {
            unsafe { ppvObject.write(CPointer<Unit>()) }
            return E_NOINTERFACE
        }
        match (ensureObjectMarshaler()) {
            case Some(marshaler) =>
                cloneMarshaler(marshaler, ppvObject)
            case None =>
                unsafe { ppvObject.write(CPointer<Unit>()) }
                E_NOINTERFACE
        }
    }

    private func ensureTearOff(): WeakReferenceTearOff {
        synchronized(stateMutex) {
            match (tearOff) {
                case Some(value) => value
                case None =>
                    let created = WeakReferenceTearOff(raw)
                    tearOff = Some(created)
                    created
            }
        }
    }

    private func ensureObjectMarshaler(): Option<IMarshal> {
        synchronized(stateMutex) {
            match (objectMarshaler) {
                case Some(marshaler) =>
                    if (marshaler.asRaw().isNotNull()) {
                        return Some(marshaler)
                    }
                    objectMarshaler = None
                case None => ()
            }

            match (createFreeThreadedMarshaler(raw)) {
                case Some(marshaler) =>
                    objectMarshaler = Some(marshaler)
                    Some(marshaler)
                case None =>
                    None
            }
        }
    }
}
