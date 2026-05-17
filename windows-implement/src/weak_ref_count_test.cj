package windows_implement

import std.sync.AtomicBool
import std.unittest.*
import std.unittest.testmacro.*
import windows_interface.*
import windows_result.Result

class WeakReferenceResolveRaceDummy {}

func takeWeakResolveProbeFromAbi(raw: CPointer<Unit>): IUnknown {
    IUnknown.fromAbiTake(raw)
}

func viewWeakResolveProbe(raw: CPointer<Unit>): IUnknown {
    IUnknown.viewOf(raw)
}

func weakResolveProbeDescriptor(): InterfaceDescriptor<IUnknown> {
    InterfaceDescriptor<IUnknown>(
        "WeakResolveProbe",
        GUID.parse("6E0C33EF-7231-4E68-A7D9-2103B8195101"),
        takeWeakResolveProbeFromAbi,
        viewWeakResolveProbe
    )
}

func takeWeakReferenceForResolveTest(owner: ComObject<WeakReferenceResolveRaceDummy>): IWeakReference {
    var sourceRaw = CPointer<Unit>()
    let sourceHr = owner.queryInterfaceBase(IID_IWEAKREFERENCESOURCE, CPointer<CPointer<Unit>>(inout sourceRaw))
    if (sourceHr != S_OK || sourceRaw.isNull()) {
        throw Exception("expected IWeakReferenceSource")
    }

    let source = IWeakReferenceSource.fromAbiTake(sourceRaw)
    try {
        match (unsafe { source.getWeakReference() }) {
            case Result<IWeakReference>.Ok(reference) =>
                reference
            case Result<IWeakReference>.Err(_) =>
                throw Exception("expected IWeakReference")
        }
    } finally {
        source.close()
    }
}

@Test
func testWeakReferenceResolveRetainsOwnerDuringQueryInterface() {
    let owner = createComObject(WeakReferenceResolveRaceDummy(), [IID_IINSPECTABLE])
    let descriptor = weakResolveProbeDescriptor()
    let observedTemporaryOwnerRef = AtomicBool(false)

    owner.runtime.setQueryInterfaceFallback({ iid, resultSlot =>
        if (iid == descriptor.iid) {
            observedTemporaryOwnerRef.store(!owner.runtime.isReferenceCountOne())
            unsafe {
                if (resultSlot.isNotNull()) {
                    resultSlot.write(CPointer<Unit>())
                }
            }
        }
        E_NOINTERFACE
    })

    let weakReference = takeWeakReferenceForResolveTest(owner)
    match (unsafe { weakReference.resolve(descriptor) }) {
        case Result<IUnknown>.Ok(value) =>
            value.close()
        case Result<IUnknown>.Err(_) =>
            ()
    }

    let retainedDuringQueryInterface = observedTemporaryOwnerRef.load()
    let releasedAfterResolve = owner.runtime.isReferenceCountOne()

    weakReference.close()
    owner.close()

    @Expect(retainedDuringQueryInterface, true)
    @Expect(releasedAfterResolve, true)
}
