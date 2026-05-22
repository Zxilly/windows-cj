package windows_implement

import windows_interface.*

public func queryComposableInner(
    innerRaw: CPointer<Unit>,
    iid: GUID,
    resultSlot: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (resultSlot.isNull()) {
            return E_POINTER
        }
        if (innerRaw.isNull()) {
            resultSlot.write(CPointer<Unit>())
            return E_NOINTERFACE
        }

        var requestedIid = iid
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(innerRaw).read()
        if (vtblPtr.isNull()) {
            resultSlot.write(CPointer<Unit>())
            return E_NOINTERFACE
        }

        resultSlot.write(CPointer<Unit>())
        let hr = vtblPtr.read().QueryInterface(innerRaw, CPointer<GUID>(inout requestedIid), resultSlot)
        if (hr != S_OK) {
            releaseFailedComOutSlot(resultSlot)
        }
        hr
    }
}

func closeComposableActivationState<TOuter, TBase>(
    outer: ComObject<TOuter>,
    baseObject: TBase,
    innerObject: IInspectable,
    closed: Bool
): Bool where TBase <: ComInterface & Resource {
    if (closed) {
        return true
    }
    outer.runtime.clearQueryInterfaceFallback()
    innerObject.close()
    baseObject.close()
    outer.releaseBase()
    true
}

public class ComposableActivation<TOuter, TBase> <: Resource where TBase <: ComInterface & Resource {
    public let outer: ComObject<TOuter>
    public let baseObject: TBase
    private let innerObject: IInspectable
    private var closed: Bool = false

    public init(outer: ComObject<TOuter>, baseObject: TBase, innerObject: IInspectable) {
        this.outer = outer
        this.baseObject = baseObject
        this.innerObject = innerObject
        this.outer.runtime.setQueryInterfaceFallback({ iid, resultSlot =>
            let innerRawValue = this.innerRaw()
            if (innerRawValue.isNotNull()) {
                return queryComposableInner(innerRawValue, iid, resultSlot)
            }
            queryComposableInner(this.baseRaw(), iid, resultSlot)
        })
    }

    public func asRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        outer.asRaw()
    }

    public func outerInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func baseRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        baseObject.asRaw()
    }

    public func innerRaw(): CPointer<Unit> {
        if (closed) {
            return CPointer<Unit>()
        }
        innerObject.asRaw()
    }

    public func innerInspectable(): IInspectable {
        IInspectable.viewOf(innerRaw())
    }

    public func queryInterface(iid: GUID, resultSlot: CPointer<CPointer<Unit>>): Int32 {
        if (closed) {
            unsafe {
                if (resultSlot.isNotNull()) {
                    resultSlot.write(CPointer<Unit>())
                }
            }
            return E_NOINTERFACE
        }
        outer.queryInterfaceBase(iid, resultSlot)
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        let _ = closeComposableActivationState(outer, baseObject, innerObject, false)
    }

    ~init() {
        closed = true
    }
}

public func createComposableOuter<TOuter>(
    outer: TOuter,
    schemas: Array<InterfaceDescriptorSchema>,
    agile!: Bool = true
): ComObject<TOuter> {
    createComObjectFromSchemas(outer, schemas, agile: agile)
}

public func createComposableOuter<TOuter>(
    outer: TOuter,
    schemas: Array<InterfaceDescriptorSchema>,
    vtblPtrs: Array<CPointer<Unit>>,
    agile!: Bool = true
): ComObject<TOuter> {
    createComObjectFromSchemas(outer, schemas, vtblPtrs, agile: agile)
}

public func activateComposable<TOuter, TBase>(
    outer: ComObject<TOuter>,
    activate: (IInspectable, CPointer<CPointer<Unit>>) -> TBase
): ComposableActivation<TOuter, TBase> where TBase <: ComInterface & Resource {
    var innerRaw = CPointer<Unit>()
    let baseObject: TBase
    try {
        baseObject = activate(IInspectable.viewOf(outer.asRaw()), CPointer<CPointer<Unit>>(inout innerRaw))
    } catch (e: Exception) {
        if (innerRaw.isNotNull()) {
            let _ = releaseComRaw(innerRaw)
            innerRaw = CPointer<Unit>()
        }
        outer.runtime.clearQueryInterfaceFallback()
        let _ = outer.releaseBase()
        throw e
    }
    try {
        let innerObject = if (innerRaw.isNull()) {
            IInspectable.viewOf(CPointer<Unit>())
        } else {
            let rawToTake = innerRaw
            innerRaw = CPointer<Unit>()
            IInspectable.fromAbiTake(rawToTake)
        }
        try {
            ComposableActivation<TOuter, TBase>(outer, baseObject, innerObject)
        } catch (e: Exception) {
            innerObject.close()
            throw e
        }
    } catch (e: Exception) {
        if (innerRaw.isNotNull()) {
            let _ = releaseComRaw(innerRaw)
            innerRaw = CPointer<Unit>()
        }
        outer.runtime.clearQueryInterfaceFallback()
        baseObject.close()
        let _ = outer.releaseBase()
        throw e
    }
}

public func activateComposable<TOuter, TBase>(
    outer: TOuter,
    schemas: Array<InterfaceDescriptorSchema>,
    activate: (IInspectable, CPointer<CPointer<Unit>>) -> TBase,
    agile!: Bool = true
): ComposableActivation<TOuter, TBase> where TBase <: ComInterface & Resource {
    activateComposable(createComposableOuter(outer, schemas, agile: agile), activate)
}

public func activateComposable<TOuter, TBase>(
    outer: TOuter,
    schemas: Array<InterfaceDescriptorSchema>,
    vtblPtrs: Array<CPointer<Unit>>,
    activate: (IInspectable, CPointer<CPointer<Unit>>) -> TBase,
    agile!: Bool = true
): ComposableActivation<TOuter, TBase> where TBase <: ComInterface & Resource {
    activateComposable(createComposableOuter(outer, schemas, vtblPtrs, agile: agile), activate)
}
