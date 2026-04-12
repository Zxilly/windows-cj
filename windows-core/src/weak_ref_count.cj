package windows_core

import std.collection.HashMap
import std.sync.*
import windows_result.Result
import windows_implement.{
    ComBox,
    comRegistryInsert,
    comRegistryLookup,
    comRegistryRemove,
    comSlotRegistryInsert,
    comSlotRegistryRemove,
    createFreeThreadedMarshaler,
    rootRegistryKeyFromRaw
}

var weakReferenceRegistryMutex = Mutex()
var weakReferenceRegistry = HashMap<UIntNative, Object>()

class LocalAggregatedMarshalerHandle <: Resource {
    private let wrapper: IMarshal
    private var closed: Bool = false

    public init(wrapper: IMarshal) {
        this.wrapper = wrapper
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        wrapper.asRaw()
    }

    public func addRef(): UInt32 {
        if (closed) {
            return 0u32
        }
        wrapper.addRef()
    }

    public func release(): UInt32 {
        if (closed) {
            return 0u32
        }
        closed = true
        wrapper.release()
    }

    public func isClosed(): Bool {
        closed || wrapper.asRaw().isNull()
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        wrapper.close()
        closed = true
    }

    ~init() {
        if (closed) {
            return
        }
        wrapper.close()
        closed = true
    }
}

func cloneLocalMarshaler(marshaler: LocalAggregatedMarshalerHandle, ppvObject: CPointer<CPointer<Unit>>): Int32 {
    if (ppvObject.isNull()) {
        return E_POINTER.value
    }
    let raw = marshaler.asRaw()
    if (raw.isNull()) {
        unsafe { ppvObject.write(CPointer<Unit>()) }
        return E_NOINTERFACE.value
    }
    let _ = marshaler.addRef()
    unsafe { ppvObject.write(raw) }
    S_OK.value
}

func createLocalFreeThreadedMarshaler(outer: CPointer<Unit>): Option<LocalAggregatedMarshalerHandle> {
    match (createFreeThreadedMarshaler(outer)) {
        case Some(marshaler) =>
            let raw = marshaler.asRaw()
            if (raw.isNull()) {
                marshaler.close()
                return None
            }
            let _ = marshaler.addRef()
            marshaler.close()
            Some(LocalAggregatedMarshalerHandle(IMarshal(raw, ownsReference: true)))
        case None =>
            None
    }
}

func weakReferenceOwnerKey(raw: CPointer<Unit>): UIntNative {
    if (raw.isNull()) {
        return UIntNative(0)
    }
    unsafe { rootRegistryKeyFromRaw(raw) }
}

func weakReferenceRegistryLookup(ownerKey: UIntNative): Option<LocalWeakReferenceTearOff> {
    if (ownerKey == UIntNative(0)) {
        return None
    }
    synchronized(weakReferenceRegistryMutex) {
        match (weakReferenceRegistry.get(ownerKey)) {
            case Some(obj) =>
                match (obj) {
                    case tearOff: LocalWeakReferenceTearOff => Some(tearOff)
                    case _ =>
                        weakReferenceRegistry.remove(ownerKey)
                        None
                }
            case None =>
                None
        }
    }
}

func weakReferenceRegistryInsert(ownerKey: UIntNative, tearOff: LocalWeakReferenceTearOff): Unit {
    if (ownerKey == UIntNative(0)) {
        return
    }
    synchronized(weakReferenceRegistryMutex) {
        weakReferenceRegistry.add(ownerKey, tearOff)
    }
}

func weakReferenceRegistryRemove(ownerKey: UIntNative): Unit {
    if (ownerKey == UIntNative(0)) {
        return
    }
    synchronized(weakReferenceRegistryMutex) {
        weakReferenceRegistry.remove(ownerKey)
    }
}

func getOrCreateWeakReferenceTearOff(ownerRaw: CPointer<Unit>): LocalWeakReferenceTearOff {
    let ownerKey = weakReferenceOwnerKey(ownerRaw)
    if (ownerKey == UIntNative(0)) {
        throw IllegalStateException("WeakReference tear-off requires a live COM identity")
    }

    match (weakReferenceRegistryLookup(ownerKey)) {
        case Some(existing) =>
            existing.bind(ownerRaw)
            return existing
        case None => ()
    }

    synchronized(weakReferenceRegistryMutex) {
        match (weakReferenceRegistry.get(ownerKey)) {
            case Some(obj) =>
                match (obj) {
                    case tearOff: LocalWeakReferenceTearOff =>
                        tearOff.bind(ownerRaw)
                        return tearOff
                    case _ =>
                        weakReferenceRegistry.remove(ownerKey)
                }
            case None => ()
        }

        let created = LocalWeakReferenceTearOff(ownerRaw, ownerKey)
        weakReferenceRegistry.add(ownerKey, created)
        created
    }
}

class LocalWeakReferenceTearOff {
    private let strongVtblHandle: CPointerHandle<IWeakReferenceSourceVtbl>
    private let weakVtblHandle: CPointerHandle<IWeakReferenceVtbl>
    private let slotHandle: CPointerHandle<ComBox>
    private let strongCount = AtomicInt64(0)
    private let weakCount = AtomicInt64(1)
    private let rootKeyValue: UIntNative
    private let weakKeyValue: UIntNative
    private let ownerKeyValue: UIntNative
    private let cacheMutex = Mutex()
    private var ownerRaw: CPointer<Unit>
    private var alive: Bool = true
    private var registered: Bool = false

    public init(ownerRaw: CPointer<Unit>, ownerKey: UIntNative) {
        this.ownerRaw = ownerRaw
        this.ownerKeyValue = ownerKey
        this.alive = ownerRaw.isNotNull()

        let strongVtblArray = Array<IWeakReferenceSourceVtbl>(1, { _ => buildLocalIWeakReferenceSourceVtbl() })
        let weakVtblArray = Array<IWeakReferenceVtbl>(1, { _ => buildLocalIWeakReferenceVtbl() })
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

        rootKeyValue = CPointer<Unit>(slotHandle.pointer).toUIntNative()
        weakKeyValue = CPointer<Unit>(unsafe { slotHandle.pointer + 1 }).toUIntNative()

        unsafe {
            let strongSlotPtr = slotHandle.pointer
            var strongSlot = strongSlotPtr.read()
            strongSlot.rootOffset = 0
            strongSlot.rootKey = rootKeyValue
            strongSlotPtr.write(strongSlot)

            let weakSlotPtr = slotHandle.pointer + 1
            var weakSlot = weakSlotPtr.read()
            weakSlot.rootOffset = 1
            weakSlot.rootKey = rootKeyValue
            weakSlotPtr.write(weakSlot)
        }

        comRegistryInsert(rootKeyValue, this)
        comSlotRegistryInsert(weakKeyValue, rootKeyValue)
        registered = true
    }

    public func bind(ownerRaw: CPointer<Unit>): Unit {
        this.ownerRaw = ownerRaw
        alive = ownerRaw.isNotNull()
    }

    public func strongRaw(): CPointer<Unit> {
        CPointer<Unit>(slotHandle.pointer)
    }

    public func weakRaw(): CPointer<Unit> {
        CPointer<Unit>(unsafe { slotHandle.pointer + 1 })
    }

    public func writeStrongReference(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER.value
            }
            ppvObject.write(CPointer<Unit>())
        }
        if (!alive || ownerRaw.isNull()) {
            return E_NOINTERFACE.value
        }

        let _ = addStrongRef()
        let _ = addRefOwner()
        unsafe { ppvObject.write(strongRaw()) }
        S_OK.value
    }

    public func writeWeakReference(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER.value
            }
            ppvObject.write(CPointer<Unit>())
        }

        let _ = addWeakRef()
        unsafe { ppvObject.write(weakRaw()) }
        S_OK.value
    }

    public func queryStrong(iid: CPointer<GUID>, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER.value
            }
            ppvObject.write(CPointer<Unit>())
            if (iid.isNull()) {
                return E_POINTER.value
            }
            if (iid.read() == IID_IWEAKREFERENCESOURCE) {
                return writeStrongReference(ppvObject)
            }
            queryOwner(iid.read(), ppvObject)
        }
    }

    public func queryWeak(iid: CPointer<GUID>, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER.value
            }
            ppvObject.write(CPointer<Unit>())
            if (iid.isNull()) {
                return E_POINTER.value
            }

            let requested = iid.read()
            if (requested == IID_IWEAKREFERENCE || requested == IID_IUNKNOWN || requested == IID_IAGILEOBJECT) {
                return writeWeakReference(ppvObject)
            }
            if (requested == IMarshal.iid() && alive && ownerRaw.isNotNull()) {
                return cloneWeakMarshaler(ppvObject)
            }
            E_NOINTERFACE.value
        }
    }

    public func addStrongRef(): UInt32 {
        UInt32(strongCount.fetchAdd(1) + 1)
    }

    public func releaseStrongRef(): UInt32 {
        let oldValue = strongCount.fetchSub(1)
        if (oldValue <= 0) {
            strongCount.fetchAdd(1)
            throw IllegalStateException("WeakReference strong over-release")
        }
        let remaining = UInt32(oldValue - 1)
        tryDestroy()
        remaining
    }

    public func addWeakRef(): UInt32 {
        UInt32(weakCount.fetchAdd(1) + 1)
    }

    public func isWeakCountOne(): Bool {
        weakCount.load() == 1
    }

    public func releaseWeakRef(): UInt32 {
        let oldValue = weakCount.fetchSub(1)
        if (oldValue <= 0) {
            weakCount.fetchAdd(1)
            throw IllegalStateException("WeakReference weak over-release")
        }
        let remaining = UInt32(oldValue - 1)
        tryDestroy()
        remaining
    }

    public func resolve(iid: CPointer<GUID>, ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER.value
            }
            ppvObject.write(CPointer<Unit>())
            if (iid.isNull()) {
                return E_POINTER.value
            }
        }

        if (!alive || ownerRaw.isNull()) {
            return S_OK.value
        }

        let _ = addRefOwner()
        try {
            unsafe { queryOwner(iid.read(), ppvObject) }
        } finally {
            let _ = releaseOwner()
        }
    }

    public func onObjectDestroyed(): Unit {
        if (!alive) {
            return
        }
        alive = false
        ownerRaw = CPointer<Unit>()
        weakReferenceRegistryRemove(ownerKeyValue)
        let _ = releaseWeakRef()
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
        if (!alive || ownerRaw.isNull()) {
            unsafe { ppvObject.write(CPointer<Unit>()) }
            return E_NOINTERFACE.value
        }

        var iidCopy = iid
        unsafe {
            let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(ownerRaw).read()
            vtblPtr.read().QueryInterface(ownerRaw, CPointer<GUID>(inout iidCopy), ppvObject)
        }
    }

    private func cloneWeakMarshaler(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        match (createWeakMarshaler()) {
            case Some(marshaler) =>
                try {
                    cloneLocalMarshaler(marshaler, ppvObject)
                } finally {
                    marshaler.close()
                }
            case None =>
                unsafe { ppvObject.write(CPointer<Unit>()) }
                E_NOINTERFACE.value
        }
    }

    private func createWeakMarshaler(): Option<LocalAggregatedMarshalerHandle> {
        createLocalFreeThreadedMarshaler(weakRaw())
    }

    private func tryDestroy(): Unit {
        if (alive) {
            return
        }
        if (strongCount.load() != 0 || weakCount.load() != 0) {
            return
        }
        destroy()
    }

    private func destroy(): Unit {
        synchronized(cacheMutex) {
            if (!registered) {
                return
            }
            weakReferenceRegistryRemove(ownerKeyValue)
            comSlotRegistryRemove(weakKeyValue)
            comRegistryRemove(rootKeyValue)
            registered = false
            unsafe { releaseArrayRawData(slotHandle) }
            unsafe { releaseArrayRawData(weakVtblHandle) }
            unsafe { releaseArrayRawData(strongVtblHandle) }
        }
    }
}

func lookupLocalWeakReferenceTearOff(this_: CPointer<Unit>): Option<LocalWeakReferenceTearOff> {
    if (this_.isNull()) {
        return None
    }
    let lookupKey = unsafe { rootRegistryKeyFromRaw(this_) }
    match (comRegistryLookup(lookupKey)) {
        case Some(obj) =>
            match (obj) {
                case tearOff: LocalWeakReferenceTearOff => Some(tearOff)
                case _ => None
            }
        case None =>
            None
    }
}

@C
func localWeakReferenceSourceQueryInterfaceThunk(
    this_: CPointer<Unit>,
    iid: CPointer<GUID>,
    ppvObject: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupLocalWeakReferenceTearOff(this_)) {
        case Some(tearOff) =>
            tearOff.queryStrong(iid, ppvObject)
        case None =>
            unsafe {
                if (ppvObject.isNotNull()) {
                    ppvObject.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE.value
    }
}

@C
func localWeakReferenceSourceAddRefThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupLocalWeakReferenceTearOff(this_)) {
        case Some(tearOff) =>
            let _ = tearOff.addStrongRef()
            tearOff.addRefOwner()
        case None =>
            0u32
    }
}

@C
func localWeakReferenceSourceReleaseThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupLocalWeakReferenceTearOff(this_)) {
        case Some(tearOff) =>
            let remaining = tearOff.releaseStrongRef()
            let _ = tearOff.releaseOwner()
            remaining
        case None =>
            0u32
    }
}

@C
func localWeakReferenceSourceGetWeakReferenceThunk(
    this_: CPointer<Unit>,
    ppvObject: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupLocalWeakReferenceTearOff(this_)) {
        case Some(tearOff) =>
            tearOff.writeWeakReference(ppvObject)
        case None =>
            unsafe {
                if (ppvObject.isNotNull()) {
                    ppvObject.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE.value
    }
}

@C
func localWeakReferenceQueryInterfaceThunk(
    this_: CPointer<Unit>,
    iid: CPointer<GUID>,
    ppvObject: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupLocalWeakReferenceTearOff(this_)) {
        case Some(tearOff) =>
            tearOff.queryWeak(iid, ppvObject)
        case None =>
            unsafe {
                if (ppvObject.isNotNull()) {
                    ppvObject.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE.value
    }
}

@C
func localWeakReferenceAddRefThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupLocalWeakReferenceTearOff(this_)) {
        case Some(tearOff) =>
            tearOff.addWeakRef()
        case None =>
            0u32
    }
}

@C
func localWeakReferenceReleaseThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupLocalWeakReferenceTearOff(this_)) {
        case Some(tearOff) =>
            tearOff.releaseWeakRef()
        case None =>
            0u32
    }
}

@C
func localWeakReferenceResolveThunk(
    this_: CPointer<Unit>,
    iid: CPointer<GUID>,
    ppvObject: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupLocalWeakReferenceTearOff(this_)) {
        case Some(tearOff) =>
            tearOff.resolve(iid, ppvObject)
        case None =>
            unsafe {
                if (ppvObject.isNotNull()) {
                    ppvObject.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE.value
    }
}

func buildLocalIWeakReferenceSourceVtbl(): IWeakReferenceSourceVtbl {
    var vtbl = IWeakReferenceSourceVtbl()
    vtbl.base_.QueryInterface = localWeakReferenceSourceQueryInterfaceThunk
    vtbl.base_.AddRef = localWeakReferenceSourceAddRefThunk
    vtbl.base_.Release = localWeakReferenceSourceReleaseThunk
    vtbl.GetWeakReference = localWeakReferenceSourceGetWeakReferenceThunk
    vtbl
}

func buildLocalIWeakReferenceVtbl(): IWeakReferenceVtbl {
    var vtbl = IWeakReferenceVtbl()
    vtbl.base_.QueryInterface = localWeakReferenceQueryInterfaceThunk
    vtbl.base_.AddRef = localWeakReferenceAddRefThunk
    vtbl.base_.Release = localWeakReferenceReleaseThunk
    vtbl.Resolve = localWeakReferenceResolveThunk
    vtbl
}

public class WeakRefCount {
    private var raw: CPointer<Unit>
    private var tearOff: Option<LocalWeakReferenceTearOff> = None
    private let stateMutex = Mutex()

    public init() {
        raw = CPointer<Unit>()
    }

    public init(raw: CPointer<Unit>) {
        this.raw = raw
    }

    public static func new(raw!: CPointer<Unit> = CPointer<Unit>()): WeakRefCount {
        WeakRefCount(raw)
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
            match (tearOff) {
                case Some(value) => value.onObjectDestroyed()
                case None => ()
            }
        }
    }

    public func isAlive(): Bool {
        raw.isNotNull()
    }

    public func isOne(): Bool {
        synchronized(stateMutex) {
            match (tearOff) {
                case Some(value) => value.isWeakCountOne()
                case None => true
            }
        }
    }

    public func query<T>(descriptor: InterfaceDescriptor<T>): Option<T> where T <: ComInterface {
        if (!isAlive()) {
            return None
        }
        unsafe { queryInterfaceAs(raw, descriptor) }
    }

    public func writeWeakReferenceSource(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER.value
            }
            ppvObject.write(CPointer<Unit>())
        }
        if (raw.isNull()) {
            return E_NOINTERFACE.value
        }
        ensureTearOff().writeStrongReference(ppvObject)
    }

    public func writeObjectMarshaler(ppvObject: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (ppvObject.isNull()) {
                return E_POINTER.value
            }
            ppvObject.write(CPointer<Unit>())
        }
        if (raw.isNull()) {
            return E_NOINTERFACE.value
        }

        match (createObjectMarshaler()) {
            case Some(marshaler) =>
                try {
                    cloneLocalMarshaler(marshaler, ppvObject)
                } finally {
                    marshaler.close()
                }
            case None =>
                E_NOINTERFACE.value
        }
    }

    public func createTearOff<T>(descriptor: InterfaceDescriptor<T>): TearOff<T> where T <: ComInterface {
        var sourceRaw = CPointer<Unit>()
        let sourceCode = writeWeakReferenceSource(CPointer<CPointer<Unit>>(inout sourceRaw))
        if (sourceCode != S_OK.value || sourceRaw.isNull()) {
            return TearOff<T>(descriptor)
        }

        let source = IWeakReferenceSource(sourceRaw, ownsReference: true)
        try {
            match (unsafe { source.getWeakReference() }) {
                case Result<IWeakReference>.Ok(reference) =>
                    TearOff<T>(descriptor, reference)
                case Result<IWeakReference>.Err(_) =>
                    TearOff<T>(descriptor)
            }
        } finally {
            source.close()
        }
    }

    private func ensureTearOff(): LocalWeakReferenceTearOff {
        synchronized(stateMutex) {
            match (tearOff) {
                case Some(existing) =>
                    existing.bind(raw)
                    existing
                case None =>
                    let created = getOrCreateWeakReferenceTearOff(raw)
                    tearOff = Some(created)
                    created
            }
        }
    }

    private func createObjectMarshaler(): Option<LocalAggregatedMarshalerHandle> {
        synchronized(stateMutex) {
            createLocalFreeThreadedMarshaler(raw)
        }
    }
}

public class TearOff<T> <: Resource where T <: ComInterface {
    private let descriptor: InterfaceDescriptor<T>
    private let weakReference: Option<IWeakReference>
    private var closed: Bool = false

    init(descriptor: InterfaceDescriptor<T>) {
        this.descriptor = descriptor
        this.weakReference = None
    }

    init(
        descriptor: InterfaceDescriptor<T>,
        weakReference: IWeakReference
    ) {
        this.descriptor = descriptor
        this.weakReference = Some(weakReference)
    }

    public func upgrade(): Option<T> {
        if (closed) {
            return None
        }

        match (weakReference) {
            case Some(reference) =>
                match (unsafe { reference.resolve(descriptor) }) {
                    case Result<T>.Ok(value) => Some(value)
                    case Result<T>.Err(_) => Option<T>.None
                }
            case None =>
                Option<T>.None
        }
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }

        match (weakReference) {
            case Some(reference) => reference.close()
            case None => ()
        }
        closed = true
    }

    ~init() {
        if (closed) {
            return
        }
        match (weakReference) {
            case Some(reference) => reference.close()
            case None => ()
        }
        closed = true
    }
}
