package windows_core

import windows_implement.{ComBox, comRegistryInsert, comRegistryLookup, comRegistryRemove}

foreign {
    func CoCreateFreeThreadedMarshaler(
        punkOuter: CPointer<Unit>,
        ppunkMarshal: CPointer<CPointer<Unit>>
    ): Int32
}

extend IMarshal <: Interface<IMarshal> {}

class AggregatedMarshalerState {
    private let outer: IUnknown
    private let innerMarshaler: IMarshal
    private let count = RefCount()
    private let vtblHandle: CPointerHandle<IMarshalVtbl>
    private let slotHandle: CPointerHandle<ComBox>
    private let rawPointer: CPointer<Unit>
    private var registered: Bool = false

    public init(outer: IUnknown, innerMarshaler: IMarshal) {
        this.outer = outer
        this.innerMarshaler = innerMarshaler

        let vtblArray = Array<IMarshalVtbl>(1, { _ => buildAggregatedMarshalerVtbl() })
        vtblHandle = unsafe { acquireArrayRawData(vtblArray) }

        let rawVtbl = CPointer<Unit>(vtblHandle.pointer)
        let slots = Array<ComBox>(1, { _ => ComBox(rawVtbl, rootOffset: 0, slotIndex: 0, slotCount: 1) })
        slotHandle = unsafe { acquireArrayRawData(slots) }
        rawPointer = CPointer<Unit>(slotHandle.pointer)

        unsafe {
            let slotPtr = slotHandle.pointer
            var slot = slotPtr.read()
            slot.rootOffset = 0
            slot.slotIndex = 0
            slot.slotCount = 1
            slot.rootKey = rawPointer.toUIntNative()
            slotPtr.write(slot)
        }

        comRegistryInsert(rawPointer.toUIntNative(), this)
        registered = true
    }

    public func raw(): CPointer<Unit> {
        rawPointer
    }

    public func queryInterface(iid: CPointer<GUID>, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        unsafe {
            if (resultSlot.isNull()) {
                return E_POINTER.value
            }
            resultSlot.write(CPointer<Unit>())
            if (iid.isNull()) {
                return E_POINTER.value
            }
            if (iid.read() == IMarshal.iid()) {
                addRef()
                resultSlot.write(rawPointer)
                return S_OK.value
            }

            let outerRaw = outer.asRaw()
            if (outerRaw.isNull()) {
                return E_POINTER.value
            }
            let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(outerRaw).read()
            vtblPtr.read().QueryInterface(outerRaw, iid, resultSlot)
        }
    }

    public func addRef(): UInt32 {
        UInt32(count.addRef())
    }

    public func release(): UInt32 {
        let remaining = UInt32(count.release())
        if (remaining == 0u32) {
            destroy()
        }
        remaining
    }

    public func getUnmarshalClass(
        riid: CPointer<GUID>,
        pv: CPointer<Unit>,
        dwdestcontext: UInt32,
        pvdestcontext: CPointer<Unit>,
        mshlflags: UInt32,
        pcid: CPointer<GUID>
    ): Int32 {
        let raw = innerMarshaler.asRaw()
        if (raw.isNull()) {
            return E_POINTER.value
        }
        unsafe { innerMarshaler.vtbl().GetUnmarshalClass(raw, riid, pv, dwdestcontext, pvdestcontext, mshlflags, pcid) }
    }

    public func getMarshalSizeMax(
        riid: CPointer<GUID>,
        pv: CPointer<Unit>,
        dwdestcontext: UInt32,
        pvdestcontext: CPointer<Unit>,
        mshlflags: UInt32,
        psize: CPointer<UInt32>
    ): Int32 {
        let raw = innerMarshaler.asRaw()
        if (raw.isNull()) {
            return E_POINTER.value
        }
        unsafe { innerMarshaler.vtbl().GetMarshalSizeMax(raw, riid, pv, dwdestcontext, pvdestcontext, mshlflags, psize) }
    }

    public func marshalInterface(
        pstm: CPointer<Unit>,
        riid: CPointer<GUID>,
        pv: CPointer<Unit>,
        dwdestcontext: UInt32,
        pvdestcontext: CPointer<Unit>,
        mshlflags: UInt32
    ): Int32 {
        let raw = innerMarshaler.asRaw()
        if (raw.isNull()) {
            return E_POINTER.value
        }
        unsafe { innerMarshaler.vtbl().MarshalInterface(raw, pstm, riid, pv, dwdestcontext, pvdestcontext, mshlflags) }
    }

    public func unmarshalInterface(
        pstm: CPointer<Unit>,
        riid: CPointer<GUID>,
        ppv: CPointer<CPointer<Unit>>
    ): Int32 {
        let raw = innerMarshaler.asRaw()
        if (raw.isNull()) {
            return E_POINTER.value
        }
        unsafe { innerMarshaler.vtbl().UnmarshalInterface(raw, pstm, riid, ppv) }
    }

    public func releaseMarshalData(pstm: CPointer<Unit>): Int32 {
        let raw = innerMarshaler.asRaw()
        if (raw.isNull()) {
            return E_POINTER.value
        }
        unsafe { innerMarshaler.vtbl().ReleaseMarshalData(raw, pstm) }
    }

    public func disconnectObject(dwreserved: UInt32): Int32 {
        let raw = innerMarshaler.asRaw()
        if (raw.isNull()) {
            return E_POINTER.value
        }
        unsafe { innerMarshaler.vtbl().DisconnectObject(raw, dwreserved) }
    }

    private func destroy(): Unit {
        if (registered) {
            comRegistryRemove(rawPointer.toUIntNative())
            registered = false
        }
        innerMarshaler.close()
        outer.close()
        unsafe { releaseArrayRawData(slotHandle) }
        unsafe { releaseArrayRawData(vtblHandle) }
    }
}

func lookupAggregatedMarshaler(instanceRaw: CPointer<Unit>): Option<AggregatedMarshalerState> {
    if (instanceRaw.isNull()) {
        return None
    }
    match (comRegistryLookup(instanceRaw.toUIntNative())) {
        case Some(obj) =>
            match (obj) {
                case state: AggregatedMarshalerState => Some(state)
                case _ => None
            }
        case None =>
            None
    }
}

@C
func aggregatedMarshalerQueryInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultSlot: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupAggregatedMarshaler(instanceRaw)) {
        case Some(state) => state.queryInterface(iid, resultSlot)
        case None =>
            unsafe {
                if (resultSlot.isNotNull()) {
                    resultSlot.write(CPointer<Unit>())
                }
            }
            E_NOINTERFACE.value
    }
}

@C
func aggregatedMarshalerAddRefThunk(instanceRaw: CPointer<Unit>): UInt32 {
    match (lookupAggregatedMarshaler(instanceRaw)) {
        case Some(state) => state.addRef()
        case None => 0u32
    }
}

@C
func aggregatedMarshalerReleaseThunk(instanceRaw: CPointer<Unit>): UInt32 {
    match (lookupAggregatedMarshaler(instanceRaw)) {
        case Some(state) => state.release()
        case None => 0u32
    }
}

@C
func aggregatedMarshalerGetUnmarshalClassThunk(
    instanceRaw: CPointer<Unit>,
    riid: CPointer<GUID>,
    pv: CPointer<Unit>,
    dwdestcontext: UInt32,
    pvdestcontext: CPointer<Unit>,
    mshlflags: UInt32,
    pcid: CPointer<GUID>
): Int32 {
    match (lookupAggregatedMarshaler(instanceRaw)) {
        case Some(state) => state.getUnmarshalClass(riid, pv, dwdestcontext, pvdestcontext, mshlflags, pcid)
        case None => E_NOINTERFACE.value
    }
}

@C
func aggregatedMarshalerGetMarshalSizeMaxThunk(
    instanceRaw: CPointer<Unit>,
    riid: CPointer<GUID>,
    pv: CPointer<Unit>,
    dwdestcontext: UInt32,
    pvdestcontext: CPointer<Unit>,
    mshlflags: UInt32,
    psize: CPointer<UInt32>
): Int32 {
    match (lookupAggregatedMarshaler(instanceRaw)) {
        case Some(state) => state.getMarshalSizeMax(riid, pv, dwdestcontext, pvdestcontext, mshlflags, psize)
        case None => E_NOINTERFACE.value
    }
}

@C
func aggregatedMarshalerMarshalInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    pstm: CPointer<Unit>,
    riid: CPointer<GUID>,
    pv: CPointer<Unit>,
    dwdestcontext: UInt32,
    pvdestcontext: CPointer<Unit>,
    mshlflags: UInt32
): Int32 {
    match (lookupAggregatedMarshaler(instanceRaw)) {
        case Some(state) => state.marshalInterface(pstm, riid, pv, dwdestcontext, pvdestcontext, mshlflags)
        case None => E_NOINTERFACE.value
    }
}

@C
func aggregatedMarshalerUnmarshalInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    pstm: CPointer<Unit>,
    riid: CPointer<GUID>,
    ppv: CPointer<CPointer<Unit>>
): Int32 {
    match (lookupAggregatedMarshaler(instanceRaw)) {
        case Some(state) => state.unmarshalInterface(pstm, riid, ppv)
        case None => E_NOINTERFACE.value
    }
}

@C
func aggregatedMarshalerReleaseMarshalDataThunk(
    instanceRaw: CPointer<Unit>,
    pstm: CPointer<Unit>
): Int32 {
    match (lookupAggregatedMarshaler(instanceRaw)) {
        case Some(state) => state.releaseMarshalData(pstm)
        case None => E_NOINTERFACE.value
    }
}

@C
func aggregatedMarshalerDisconnectObjectThunk(
    instanceRaw: CPointer<Unit>,
    dwreserved: UInt32
): Int32 {
    match (lookupAggregatedMarshaler(instanceRaw)) {
        case Some(state) => state.disconnectObject(dwreserved)
        case None => E_NOINTERFACE.value
    }
}

func buildAggregatedMarshalerVtbl(): IMarshalVtbl {
    var vtbl = IMarshalVtbl()
    vtbl.base_.QueryInterface = aggregatedMarshalerQueryInterfaceThunk
    vtbl.base_.AddRef = aggregatedMarshalerAddRefThunk
    vtbl.base_.Release = aggregatedMarshalerReleaseThunk
    vtbl.GetUnmarshalClass = aggregatedMarshalerGetUnmarshalClassThunk
    vtbl.GetMarshalSizeMax = aggregatedMarshalerGetMarshalSizeMaxThunk
    vtbl.MarshalInterface = aggregatedMarshalerMarshalInterfaceThunk
    vtbl.UnmarshalInterface = aggregatedMarshalerUnmarshalInterfaceThunk
    vtbl.ReleaseMarshalData = aggregatedMarshalerReleaseMarshalDataThunk
    vtbl.DisconnectObject = aggregatedMarshalerDisconnectObjectThunk
    vtbl
}

func cloneIUnknownOwned(value: IUnknown): Result<IUnknown> {
    let raw = value.asRaw()
    if (raw.isNull()) {
        return Result<IUnknown>.Err(WinError(E_POINTER))
    }
    value.addRef()
    Result<IUnknown>.Ok(IUnknown.fromAbiTake(raw))
}

func createInnerMarshaler(): Result<IMarshal> {
    var marshalerRaw = CPointer<Unit>()
    let hr = unsafe {
        HRESULT(
            CoCreateFreeThreadedMarshaler(
                CPointer<Unit>(),
                CPointer<CPointer<Unit>>(inout marshalerRaw)
            )
        )
    }
    if (hr.failed()) {
        return Result<IMarshal>.Err(WinError.fromHRESULT(hr))
    }
    if (marshalerRaw.isNull()) {
        return Result<IMarshal>.Err(WinError(E_POINTER))
    }

    let marshalerUnknown = IUnknown.fromAbiTake(marshalerRaw)
    match (unsafe { queryInterfaceAs(marshalerRaw, IMarshal.descriptor()) }) {
        case Some(value) =>
            marshalerUnknown.close()
            Result<IMarshal>.Ok(value)
        case None =>
            marshalerUnknown.close()
            Result<IMarshal>.Err(WinError(E_NOINTERFACE))
    }
}

public class Marshaler {
    private let inner: IMarshal

    public init(inner: IMarshal) {
        this.inner = inner
    }

    public func asInterface(): IMarshal {
        let raw = inner.asRaw()
        inner.addRef()
        IMarshal.fromAbiTake(raw)
    }
}

public func createMarshaler(outer: IUnknown): Result<IMarshal> {
    match (cloneIUnknownOwned(outer)) {
        case Result<IUnknown>.Ok(clonedOuter) =>
            match (createInnerMarshaler()) {
                case Result<IMarshal>.Ok(innerMarshaler) =>
                    let state = AggregatedMarshalerState(clonedOuter, innerMarshaler)
                    Result<IMarshal>.Ok(IMarshal.fromAbiTake(state.raw()))
                case Result<IMarshal>.Err(error) =>
                    clonedOuter.close()
                    Result<IMarshal>.Err(error)
            }
        case Result<IUnknown>.Err(error) =>
            Result<IMarshal>.Err(error)
    }
}
