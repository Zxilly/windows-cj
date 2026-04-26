package windows_implement

import std.sync.*
import windows_interface.*

public interface WeakReferenceOwner {
    func weakReferenceIdentity(): CPointer<Unit>
    func weakReferenceIsAgileEnabled(): Bool
    func weakReferenceQueryInterface(iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32
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

    public func writeStrongReference(resultSlot: CPointer<CPointer<Unit>>): Int32 {
        if (resultSlot.isNull()) {
            return E_POINTER
        }
        if (ownerRaw.isNull() || !alive) {
            unsafe { resultSlot.write(CPointer<Unit>()) }
            return E_NOINTERFACE
        }
        addRefOwner()
        unsafe { resultSlot.write(strongRaw()) }
        S_OK
    }

    public func writeWeakReference(resultSlot: CPointer<CPointer<Unit>>): Int32 {
        if (resultSlot.isNull()) {
            return E_POINTER
        }
        addWeakRef()
        unsafe { resultSlot.write(weakRaw()) }
        S_OK
    }

    public func queryStrong(iidPtr: CPointer<GUID>, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (resultSlot.isNull()) {
                return E_POINTER
            }
            if (iidPtr.isNull()) {
                resultSlot.write(CPointer<Unit>())
                return E_POINTER
            }
            let iid = iidPtr.read()
            if (iid == IID_IWEAKREFERENCESOURCE) {
                return writeStrongReference(resultSlot)
            }
            queryOwner(iid, resultSlot)
        }
    }

    public func queryWeak(iidPtr: CPointer<GUID>, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (resultSlot.isNull()) {
                return E_POINTER
            }
            if (iidPtr.isNull()) {
                resultSlot.write(CPointer<Unit>())
                return E_POINTER
            }

            let iid = iidPtr.read()
            if (iid == IID_IWEAKREFERENCE || iid == IID_IUNKNOWN || iid == IID_IAGILEOBJECT) {
                return writeWeakReference(resultSlot)
            }

            if (iid == IID_IMARSHAL && ownerRaw.isNotNull()) {
                return cloneWeakMarshaler(resultSlot)
            }

            resultSlot.write(CPointer<Unit>())
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

    public func resolve(iidPtr: CPointer<GUID>, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (resultSlot.isNull()) {
                return E_POINTER
            }
            if (iidPtr.isNull()) {
                resultSlot.write(CPointer<Unit>())
                return E_POINTER
            }
            if (ownerRaw.isNull() || !alive) {
                resultSlot.write(CPointer<Unit>())
                return S_OK
            }
            queryOwner(iidPtr.read(), resultSlot)
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

    private func queryOwner(iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        if (ownerRaw.isNull() || !alive) {
            unsafe { resultSlot.write(CPointer<Unit>()) }
            return E_NOINTERFACE
        }
        var iidCopy = iid
        unsafe {
            let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(ownerRaw).read()
            vtblPtr.read().QueryInterface(ownerRaw, CPointer<GUID>(inout iidCopy), resultSlot)
        }
    }

    private func cloneWeakMarshaler(resultSlot: CPointer<CPointer<Unit>>): Int32 {
        match (ensureWeakMarshaler()) {
            case Some(marshaler) =>
                cloneMarshaler(marshaler, resultSlot)
            case None =>
                unsafe { resultSlot.write(CPointer<Unit>()) }
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

func lookupWeakReferenceTearOff(instanceRaw: CPointer<Unit>): Option<WeakReferenceTearOff> {
    if (instanceRaw.isNull()) {
        return None
    }
    let lookupKey = unsafe { rootRegistryKeyFromRaw(instanceRaw) }
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
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultSlot: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupWeakReferenceTearOff(instanceRaw)) {
        case Some(tearOff) => tearOff.queryStrong(iid, resultSlot)
        case None =>
            unsafe {
                if (resultSlot.isNotNull()) {
                    resultSlot.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE
    }
}

@C
public func weakReferenceSourceAddRefThunk(instanceRaw: CPointer<Unit>): UInt32 {
    match (lookupWeakReferenceTearOff(instanceRaw)) {
        case Some(tearOff) => tearOff.addRefOwner()
        case None => 0u32
    }
}

@C
public func weakReferenceSourceReleaseThunk(instanceRaw: CPointer<Unit>): UInt32 {
    match (lookupWeakReferenceTearOff(instanceRaw)) {
        case Some(tearOff) => tearOff.releaseOwner()
        case None => 0u32
    }
}

@C
public func weakReferenceSourceGetWeakReferenceThunk(
    instanceRaw: CPointer<Unit>,
    resultSlot: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupWeakReferenceTearOff(instanceRaw)) {
        case Some(tearOff) => tearOff.writeWeakReference(resultSlot)
        case None =>
            unsafe {
                if (resultSlot.isNotNull()) {
                    resultSlot.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE
    }
}

@C
public func weakReferenceQueryInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultSlot: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupWeakReferenceTearOff(instanceRaw)) {
        case Some(tearOff) => tearOff.queryWeak(iid, resultSlot)
        case None =>
            unsafe {
                if (resultSlot.isNotNull()) {
                    resultSlot.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE
    }
}

@C
public func weakReferenceAddRefThunk(instanceRaw: CPointer<Unit>): UInt32 {
    match (lookupWeakReferenceTearOff(instanceRaw)) {
        case Some(tearOff) => tearOff.addWeakRef()
        case None => 0u32
    }
}

@C
public func weakReferenceReleaseThunk(instanceRaw: CPointer<Unit>): UInt32 {
    match (lookupWeakReferenceTearOff(instanceRaw)) {
        case Some(tearOff) => tearOff.releaseWeakRef()
        case None => 0u32
    }
}

@C
public func weakReferenceResolveThunk(
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultSlot: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupWeakReferenceTearOff(instanceRaw)) {
        case Some(tearOff) => tearOff.resolve(iid, resultSlot)
        case None =>
            unsafe {
                if (resultSlot.isNotNull()) {
                    resultSlot.write(CPointer<Unit>())
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

    public func writeWeakReferenceSource(resultSlot: CPointer<CPointer<Unit>>): Int32 {
        let value = ensureTearOff()
        value.writeStrongReference(resultSlot)
    }

    public func writeObjectMarshaler(resultSlot: CPointer<CPointer<Unit>>): Int32 {
        if (resultSlot.isNull()) {
            return E_POINTER
        }
        if (raw.isNull()) {
            unsafe { resultSlot.write(CPointer<Unit>()) }
            return E_NOINTERFACE
        }
        match (ensureObjectMarshaler()) {
            case Some(marshaler) =>
                cloneMarshaler(marshaler, resultSlot)
            case None =>
                unsafe { resultSlot.write(CPointer<Unit>()) }
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
