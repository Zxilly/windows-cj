package windows_core_winrt_runtime_smoke

import windows_core.*

public class SmokeFailure <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

public class DemoInner {
    public var value: Int32 = 7i32

    public init() {}
}

public class DemoRuntimeName <: RuntimeName {
    public init() {}

    public static func runtimeName(): String {
        "Demo.Runtime.Type"
    }
}

public class CounterBox {
    public var value: Int32 = 0i32

    public init() {}
}

public class RetainedFactoryThunkBox {
    public var value: Option<() -> Result<IUnknown>> = None

    public init() {}
}

func fail(msg: String): Unit {
    throw SmokeFailure(msg)
}

func samePointer(left: CPointer<Unit>, right: CPointer<Unit>): Bool {
    left.toUIntNative() == right.toUIntNative()
}

func readImplMut<T, U>(value: T): Option<U> where T <: IUnknownImpl {
    value.get_impl_mut<U>()
}

func readIsReferenceCountOne<T>(value: T): Bool where T <: IUnknownImpl {
    value.is_reference_count_one()
}

func readTrustLevel<T>(value: T): (HRESULT, Int32) where T <: IUnknownImpl {
    var trustLevel = -1i32
    let hr = value.GetTrustLevel(CPointer<Int32>(inout trustLevel))
    (HRESULT(hr), trustLevel)
}

func readAsInterface<T, U>(value: T, descriptor: InterfaceDescriptor<U>): U
where T <: IUnknownImpl, U <: ComInterface & Interface<U> {
    value.as_interface(descriptor)
}

func readToInterface<T, U>(value: T, descriptor: InterfaceDescriptor<U>): U
where T <: IUnknownImpl, U <: ComInterface & Interface<U> {
    value.to_interface(descriptor)
}

func readToObject<T, U>(value: T): ComObject<U> where T <: IUnknownImpl {
    value.to_object()
}

func expectAbiArray(): Unit {
    let seed = [10i32, 20i32, 30i32]
    var abi = AbiArray<Int32>.fromSlice(seed)
    if (abi.len() != 3) {
        fail("AbiArray.fromSlice should preserve element count")
    }
    if (abi.isEmpty()) {
        fail("AbiArray.fromSlice should not create an empty array")
    }
    if (abi.get(1) != 20i32) {
        fail("AbiArray.get should read the copied payload")
    }
    abi.set(2, 40i32)
    if (abi.get(2) != 40i32) {
        fail("AbiArray.set should update the backing CoTaskMem buffer")
    }
    let copied = abi.toArray()
    if (copied.size != 3 || copied[2] != 40i32) {
        fail("AbiArray.toArray should materialize the current contents")
    }
    let (raw, len) = abi.intoAbi()
    if (raw.isNull() || len != 3u32) {
        fail("AbiArray.intoAbi should hand off the native buffer and length")
    }
    let rebound = unsafe { AbiArray<Int32>.fromRawParts(raw, len) }
    if (rebound.get(0) != 10i32 || rebound.get(2) != 40i32) {
        fail("AbiArray.fromRawParts should rebind the native buffer without copying")
    }
    rebound.close()

    let textArray = AbiArray<HString>.fromSlice([HString("alpha"), HString("beta")])
    if (textArray.len() != 2 || textArray.get(1).get() != "beta") {
        fail("AbiArray should support projected non-CType elements through managed storage")
    }
    textArray.replaceWith([HString("gamma")])
    if (textArray.toArray().size != 1 || textArray.get(0).get() != "gamma") {
        fail("AbiArray.replaceWith should update projected managed storage")
    }
    textArray.close()
}

func expectArrayProxy(): Unit {
    var raw = CPointer<Int32>()
    var len = 0u32
    let proxy = unsafe {
        arrayProxy<Int32>(
            CPointer<CPointer<Int32>>(inout raw),
            CPointer<UInt32>(inout len)
        )
    }
    let array = proxy.value()
    array.replaceWith([5i32, 6i32, 7i32])
    proxy.close()
    if (raw.isNull() || len != 3u32) {
        fail("ArrayProxy.close should publish the staged ABI buffer")
    }
    let rebound = unsafe { AbiArray<Int32>.fromRawParts(raw, len) }
    if (rebound.get(0) != 5i32 || rebound.get(2) != 7i32) {
        fail("ArrayProxy should publish the written array contents")
    }
    rebound.close()
}

func expectSha1(): Unit {
    let buffer = ConstBuffer()
    if (!buffer.isEmpty() || buffer.length() != 0) {
        fail("ConstBuffer should start empty")
    }
    buffer.pushUtf8("ab")
    buffer.push(b'c')
    if (String.fromUtf8(buffer.toArray()) != "abc") {
        fail("ConstBuffer.pushUtf8/push should append UTF-8 bytes in order")
    }
    let cloned = buffer.clone()
    cloned.pushUtf8("d")
    if (String.fromUtf8(buffer.toArray()) != "abc") {
        fail("ConstBuffer.clone should preserve value semantics")
    }
    let merged = ConstBuffer.fromBytes("prefix".toArray())
    merged.pushOther(ConstBuffer.fromUtf8("-suffix"))
    if (String.fromUtf8(merged.toArray()) != "prefix-suffix") {
        fail("ConstBuffer.pushOther should append another immutable buffer")
    }
    let digest = sha1(ConstBuffer.fromUtf8("abc"))
    if (digest.toString() != "a9993e364706816aba3e25717850c26c9cd0d89d") {
        fail("sha1 should match the canonical digest for 'abc'")
    }
    let digestBytes = digest.bytes()
    if (digestBytes.size != 20 || digestBytes[0] != 0xA9u8 || digestBytes[19] != 0x9Du8) {
        fail("Sha1Digest.bytes should expose the canonical 20-byte digest payload")
    }
    let signatureGuid = guidFromSignature(ConstBuffer.fromUtf8("pinterface({00000000-0000-0000-c000-000000000046})"))
    if (signatureGuid.isZero()) {
        fail("guidFromSignature should derive a non-zero GUID from a signature buffer")
    }
}

func expectComObjectHelpers(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })
    var constructed = ComObject<DemoInner>.new(DemoInner(), schemas)
    if (constructed.get().value != 7i32) {
        fail("ComObject.new should expose the stored implementation value through get")
    }
    let constructedUnknown = constructed.toInterface(IUnknown.descriptor())
    match (unsafe { ComObject<DemoInner>.fromRaw(constructedUnknown.asRaw()) }) {
        case Result<ComObject<DemoInner>>.Ok(rebound) =>
            if (rebound.get().value != 7i32) {
                fail("ComObject.fromRaw should recover the original implementation object")
            }
        case Result<ComObject<DemoInner>>.Err(error) =>
            fail("ComObject.fromRaw failed: ")
    }
    constructedUnknown.close()
    let constructedFinalCount = IUnknown(constructed.asRaw()).release()
    if (constructedFinalCount != 0u32) {
        fail("ComObject.new/fromRaw probe object should release cleanly")
    }

    var object = createComObjectFromSchemas(DemoInner(), schemas)

    match (object.getMut()) {
        case Some(inner) =>
            inner.value = 9i32
        case None =>
            fail("ComObject.getMut should succeed while the COM object is uniquely owned")
    }

    let borrowedInspectable = object.asInterface(IInspectable.descriptor())
    if (!samePointer(borrowedInspectable.asRaw(), object.asRaw())) {
        fail("ComObject.asInterface should expose a borrowed interface view")
    }
    borrowedInspectable.close()

    let ownedInspectable = object.toInterface(IInspectable.descriptor())
    if (!samePointer(ownedInspectable.asRaw(), object.asRaw())) {
        fail("ComObject.toInterface should wrap the same COM identity")
    }
    ownedInspectable.close()

    match (unsafe { object.cast(IInspectable.descriptor()) }) {
        case Some(inspectable) =>
            if (!samePointer(inspectable.asRaw(), object.asRaw())) {
                fail("ComObject.cast should resolve implemented interfaces")
            }
            inspectable.close()
        case None =>
            fail("ComObject.cast should succeed for IInspectable")
    }

    let unknown = object.toInterface(IUnknown.descriptor())
    match (ComObject<DemoInner>.castFrom(unknown)) {
        case Some(rebound) =>
            unknown.close()
            match (rebound.getMut()) {
                case Some(inner) =>
                    if (inner.value != 9i32) {
                        fail("ComObject.castFrom should recover the original implementation value")
                    }
                case None =>
                    fail("ComObject.castFrom should recover a live ComObject view")
            }
        case None =>
            fail("ComObject.castFrom should recover a ComObject from one of its interfaces")
    }

    var takeObject = createComObjectFromSchemas(DemoInner(), schemas)
    match (takeObject.take()) {
        case Some(inner) =>
            if (inner.value != 7i32) {
                fail("ComObject.take should yield the stored implementation value")
            }
        case None =>
            fail("ComObject.take should succeed when the COM object is uniquely owned")
    }
}

func expectIUnknownImplHelpers(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })
    let object = createComObjectFromSchemas(DemoInner(), schemas)
    if (!readIsReferenceCountOne(object.runtime)) {
        fail("IUnknownImpl.is_reference_count_one should report unique ownership for a fresh object")
    }
    match (readImplMut<ComObjectRuntime<DemoInner>, DemoInner>(object.runtime)) {
        case Some(inner) =>
            inner.value = 21i32
        case None =>
            fail("IUnknownImpl.get_impl_mut should surface the mutable inner implementation")
    }
    let (trustHr, trustLevel) = readTrustLevel(object.runtime)
    if (trustHr.failed() || trustLevel != 0i32) {
        fail("IUnknownImpl.GetTrustLevel should default to BaseTrust")
    }
    let borrowedUnknown = readAsInterface(object.runtime, IUnknown.descriptor())
    if (!samePointer(borrowedUnknown.asRaw(), object.asRaw())) {
        fail("IUnknownImpl.as_interface should expose the current COM identity")
    }
    borrowedUnknown.close()
    let ownedUnknown = readToInterface(object.runtime, IUnknown.descriptor())
    if (!samePointer(ownedUnknown.asRaw(), object.asRaw())) {
        fail("IUnknownImpl.to_interface should clone the current COM identity")
    }
    ownedUnknown.close()
    let rebound = readToObject<ComObjectRuntime<DemoInner>, DemoInner>(object.runtime)
    if (!samePointer(rebound.asRaw(), object.asRaw())) {
        fail("IUnknownImpl.to_object should rebuild the current ComObject view")
    }
    if (!readIsReferenceCountOne(object.runtime)) {
        fail("IUnknownImpl.to_object should not add an extra strong reference for the returned ComObject view")
    }
    let reboundUnknown = rebound.toInterface(IUnknown.descriptor())
    reboundUnknown.close()
    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("IUnknownImpl.to_object view should not retain an extra COM reference")
    }
}

func expectStaticComObject(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })
    let object = createStaticComObjectFromSchemas(DemoInner(), schemas)
    let ownedUnknown = object.toInterface(IUnknown.descriptor())
    if (!samePointer(ownedUnknown.asRaw(), object.asRaw())) {
        fail("StaticComObject.toInterface should expose the pinned COM identity")
    }
    ownedUnknown.close()
    match (object.runtime.getMut()) {
        case Some(_) =>
            fail("StaticComObject should pin the runtime and reject mutable extraction")
        case None => ()
    }
}

func expectGenericArrayProxySurface(): Unit {
    let stringProxy = unsafe { arrayProxy<HString>(CPointer<CPointer<Unit>>(), CPointer<UInt32>()) }
    stringProxy.value().replaceWith([HString("alpha"), HString("beta")])
    stringProxy.close()

    let interfaceProxy = unsafe { arrayProxy<IUnknown>(CPointer<CPointer<Unit>>(), CPointer<UInt32>()) }
    interfaceProxy.value().replaceWith([IUnknown(CPointer<Unit>())])
    interfaceProxy.close()
}

func expectWeakAndAgile(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })
    var object = createComObjectFromSchemas(DemoInner(), schemas)
    let unknown = object.toInterface(IUnknown.descriptor())
    let scopedUnknown = ScopedInterface<IUnknown>.new(unknown, IUnknown.descriptor())
    if (!samePointer(scopedUnknown.asRaw(), object.asRaw())) {
        fail("ScopedInterface.new should retain the same COM identity")
    }
    scopedUnknown.close()

    let emptyWeakRefCount = WeakRefCount.new()
    if (!emptyWeakRefCount.isOne()) {
        fail("WeakRefCount.new should start with a single weak reference")
    }
    match (emptyWeakRefCount.query(IUnknown.descriptor())) {
        case Some(_) =>
            fail("WeakRefCount.query should return None for an empty weak reference source")
        case None =>
            ()
    }

    let localWeakRefCount = WeakRefCount.new(raw: unknown.asRaw())
    match (localWeakRefCount.query(IUnknown.descriptor())) {
        case Some(resolved) =>
            if (!samePointer(resolved.asRaw(), object.asRaw())) {
                fail("WeakRefCount.query should recover the live COM identity")
            }
            resolved.close()
        case None =>
            fail("WeakRefCount.query should succeed for a live local object")
    }

    match (unsafe { unknown.query(IMarshal.descriptor()) }) {
        case Some(marshal) =>
            if (marshal.asRaw().isNull()) {
                fail("QueryInterface(IMarshal) should return a live marshaler for local agile objects")
            }
            marshal.close()
        case None =>
            fail("QueryInterface(IMarshal) should succeed for local agile objects")
    }

    match (unsafe { queryInterfaceAs(unknown.asRaw(), IWeakReferenceSource.descriptor()) }) {
        case Some(source) =>
            match (unsafe { source.getWeakReference() }) {
                case Result<IWeakReference>.Ok(reference) =>
                    match (unsafe { reference.query(IMarshal.descriptor()) }) {
                        case Some(weakMarshal) =>
                            if (weakMarshal.asRaw().isNull()) {
                                fail("local weak references should expose a live IMarshal implementation")
                            }
                            weakMarshal.close()
                        case None =>
                            fail("local weak references should support QueryInterface(IMarshal)")
                    }
                    reference.close()
                case Result<IWeakReference>.Err(error) =>
                    fail("IWeakReferenceSource.getWeakReference failed: ")
            }
            source.close()
        case None =>
            fail("local agile objects should expose IWeakReferenceSource")
    }

    let weak = Weak<IUnknown>.downgrade(unknown, IUnknown.descriptor())
    match (weak.upgrade()) {
        case Some(strong) =>
            if (!samePointer(strong.asRaw(), object.asRaw())) {
                fail("Weak.upgrade should recover the current COM identity")
            }
            strong.close()
        case None =>
            fail("Weak.upgrade should succeed before the object is destroyed")
    }

    match (AgileReference<IUnknown>.new(unknown, IUnknown.descriptor())) {
        case Result<AgileReference<IUnknown>>.Ok(reference) =>
            match (reference.resolve()) {
                case Result<IUnknown>.Ok(resolved) =>
                    if (!samePointer(resolved.asRaw(), object.asRaw())) {
                        fail("AgileReference.resolve should recover the target interface")
                    }
                    resolved.close()
                case Result<IUnknown>.Err(error) =>
                    fail("AgileReference.resolve failed: ")
            }
            reference.close()
        case Result<AgileReference<IUnknown>>.Err(error) =>
            fail("AgileReference.new failed: ")
    }

    unknown.close()
    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("weak/agile probe object should release cleanly")
    }

    match (weak.upgrade()) {
        case Some(_) =>
            fail("Weak.upgrade should fail after the object is destroyed")
        case None => ()
    }
}

func expectEventAndFactoryCache(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })
    let object = createComObjectFromSchemas(DemoInner(), schemas)
    let unknown = object.toInterface(IUnknown.descriptor())

    let event = Event<IUnknown>.new(IUnknown.descriptor())
    let token = event.add(unknown).expect("Event.add should accept COM delegates")
    if (token.value == 0i64) {
        fail("Event tokens should be opaque non-zero encoded pointers")
    }
    let callbackCount = CounterBox()
    event.call({ delegate: IUnknown =>
        if (!samePointer(delegate.asRaw(), object.asRaw())) {
            return Result<Unit>.Err(WinError(E_FAIL, "event delegate identity mismatch"))
        }
        callbackCount.value += 1i32
        Result<Unit>.Ok(())
    })
    event.remove(token)
    event.call({ _: IUnknown =>
        callbackCount.value += 100i32
        Result<Unit>.Ok(())
    })
    if (callbackCount.value != 1i32) {
        fail("Event.remove should revoke the registered token")
    }
    let softErrorCount = CounterBox()
    let softErrorToken = event.add(unknown).expect("Event.add should register delegates for swallowed non-disconnect errors")
    event.call({ _: IUnknown =>
        softErrorCount.value += 1i32
        Result<Unit>.Err(WinError(E_FAIL, "soft event failure"))
    })
    event.call({ _: IUnknown =>
        softErrorCount.value += 10i32
        Result<Unit>.Ok(())
    })
    if (softErrorCount.value != 11i32) {
        fail("Event.call should swallow non-disconnect errors without revoking the delegate")
    }
    event.remove(softErrorToken)
    let autoCleanupCount = CounterBox()
    let disconnectToken = event.add(unknown).expect("Event.add should register delegates for automatic disconnect cleanup")
    event.call({ _: IUnknown =>
        autoCleanupCount.value += 1i32
        Result<Unit>.Err(WinError.fromHRESULT(HRESULT(-2147417848i32)))
    })
    if (autoCleanupCount.value != 1i32) {
        fail("Event.call should invoke the disconnecting delegate once before cleanup")
    }
    event.call({ _: IUnknown =>
        autoCleanupCount.value += 100i32
        Result<Unit>.Ok(())
    })
    if (autoCleanupCount.value != 1i32) {
        fail("Event.call should automatically remove delegates that report disconnect-style errors")
    }
    event.remove(disconnectToken)

    let cache = FactoryCache<DemoRuntimeName, IUnknown>.new(IUnknown.descriptor())
    let loadCount = CounterBox()
    match (cache.factory({ =>
        loadCount.value += 1i32
        Result<IUnknown>.Ok(object.toInterface(IUnknown.descriptor()))
    })) {
        case Ok(factory) =>
            if (!samePointer(factory.asRaw(), object.asRaw())) {
                fail("FactoryCache.factory should return the loaded COM identity")
            }
            factory.close()
        case Err(error) =>
            fail("FactoryCache.factory failed: ")
    }

    let loadOnlyCache = FactoryCache<DemoRuntimeName, IUnknown>.new(IUnknown.descriptor())
    let loadOnlyCount = CounterBox()
    match (loadOnlyCache.loadFactory({ =>
        loadOnlyCount.value += 1i32
        Result<IUnknown>.Ok(object.toInterface(IUnknown.descriptor()))
    })) {
        case Ok(factory) =>
            if (!samePointer(factory.asRaw(), object.asRaw())) {
                fail("FactoryCache.loadFactory should return the loaded COM identity")
            }
            factory.close()
        case Err(error) =>
            fail("FactoryCache.loadFactory failed: ")
    }
    if (loadOnlyCount.value != 1i32) {
        fail("FactoryCache.loadFactory should invoke the loader exactly once")
    }

    let first = cache.call(
        { =>
            loadCount.value += 1i32
            Result<IUnknown>.Ok(object.toInterface(IUnknown.descriptor()))
        },
        { getFactory: () -> Result<IUnknown> =>
            match (getFactory()) {
                case Ok(factory) =>
                    try {
                        if (!samePointer(factory.asRaw(), object.asRaw())) {
                            return Result<Int32>.Err(WinError(E_FAIL, "factory cache returned the wrong COM identity"))
                        }
                        Result<Int32>.Ok(11i32)
                    } finally {
                        factory.close()
                    }
                case Err(error) =>
                    Result<Int32>.Err(error)
            }
        }
    )
    match (first) {
        case Ok(value) =>
            if (value != 11i32) {
                fail("FactoryCache.call should return the callback result")
            }
        case Err(error) =>
            fail("FactoryCache.call failed: ")
    }

    let second = cache.call(
        { =>
            loadCount.value += 1i32
            Result<IUnknown>.Ok(object.toInterface(IUnknown.descriptor()))
        },
        { getFactory: () -> Result<IUnknown> =>
            match (getFactory()) {
                case Ok(factory) =>
                    try {
                        Result<Int32>.Ok(22i32)
                    } finally {
                        factory.close()
                    }
                case Err(error) =>
                    Result<Int32>.Err(error)
            }
        }
    )
    match (second) {
        case Ok(value) =>
            if (value != 22i32) {
                fail("FactoryCache.call should allow subsequent callbacks to run")
            }
        case Err(error) =>
            fail("FactoryCache.call failed on the cached path: ")
    }
    if (loadCount.value != 1i32) {
        fail("FactoryCache.factory should prime the cache for subsequent call invocations")
    }

    let retainedFactoryBox = RetainedFactoryThunkBox()
    let retained = cache.call(
        { =>
            loadCount.value += 1i32
            Result<IUnknown>.Ok(object.toInterface(IUnknown.descriptor()))
        },
        { getFactory: () -> Result<IUnknown> =>
            retainedFactoryBox.value = Some(getFactory)
            Result<Int32>.Ok(33i32)
        }
    )
    match (retained) {
        case Ok(value) =>
            if (value != 33i32) {
                fail("FactoryCache.call should return retained-thunk callback results")
            }
        case Err(error) =>
            fail("FactoryCache.call failed on the retained-thunk path: ")
    }
    match (retainedFactoryBox.value) {
        case Some(getRetainedFactory) =>
            match (getRetainedFactory()) {
                case Ok(retainedFactory) =>
                    try {
                        if (retainedFactory.asRaw().isNull()) {
                            fail("FactoryCache.call should provide a retained factory thunk that returns a live wrapper")
                        }
                        match (unsafe { retainedFactory.query(IUnknown.descriptor()) }) {
                            case Some(rebound) =>
                                if (!samePointer(rebound.asRaw(), object.asRaw())) {
                                    fail("retained factory thunks should continue to resolve the cached COM identity after FactoryCache.call returns")
                                }
                                rebound.close()
                            case None =>
                                fail("retained factory thunks should return wrappers that still support QueryInterface")
                        }
                    } finally {
                        retainedFactory.close()
                    }
                case Err(error) =>
                    fail("retained factory thunk failed after FactoryCache.call returned: ")
            }
        case None =>
            fail("FactoryCache.call retained-thunk probe did not capture the factory accessor")
    }

    loadOnlyCache.close()
    cache.close()
    event.close()
    unknown.close()
    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("event/cache probe object should release cleanly")
    }
}

func expectMarshaler(): Unit {
    let schemas = Array(1, { _ => IInspectable.descriptorSchema() })
    var object = createComObjectFromSchemas(DemoInner(), schemas)
    let unknown = object.toInterface(IUnknown.descriptor())

    match (createMarshaler(unknown)) {
        case Result<IMarshal>.Ok(marshal) =>
            let raw = marshal.asRaw()
            if (raw.isNull()) {
                fail("createMarshaler should return a live IMarshal interface")
            }
            match (unsafe { marshal.query(IInspectable.descriptor()) }) {
                case Some(inspectable) =>
                    if (!samePointer(inspectable.asRaw(), object.asRaw())) {
                        fail("createMarshaler should aggregate IMarshal onto the outer COM identity")
                    }
                    inspectable.close()
                case None =>
                    fail("aggregated marshaler should forward non-IMarshal QueryInterface calls to the outer object")
            }
            marshal.close()
        case Result<IMarshal>.Err(error) =>
            fail("createMarshaler failed: ")
    }

    unknown.close()
    let finalCount = IUnknown(object.asRaw()).release()
    if (finalCount != 0u32) {
        fail("marshaler probe object should release cleanly")
    }
}

main(_: Array<String>) {
    expectAbiArray()
    expectArrayProxy()
    expectGenericArrayProxySurface()
    expectSha1()
    expectComObjectHelpers()
    expectIUnknownImplHelpers()
    expectStaticComObject()
    expectWeakAndAgile()
    expectEventAndFactoryCache()
    expectMarshaler()
}