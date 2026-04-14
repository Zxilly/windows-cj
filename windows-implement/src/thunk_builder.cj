package windows_implement

import windows_interface.*

// Thunks translate native COM callbacks into registry-backed runtime calls.

func lookupRegistryObject(instanceRaw: CPointer<Unit>): Option<Object> {
    if (instanceRaw.isNull()) {
        return None
    }
    unsafe { comRegistryLookup(rootRegistryKeyFromRaw(instanceRaw)) }
}

@C
public func iunknownQueryInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultSlot: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (resultSlot.isNull()) {
            return E_POINTER
        }
        match (lookupRegistryObject(instanceRaw)) {
            case Some(obj) =>
                match (obj) {
                    case comObj: ComObjectBase =>
                        if (iid.isNull()) {
                            resultSlot.write(CPointer<Unit>())
                            return E_POINTER
                        }
                        comObj.queryInterfaceBase(instanceRaw, iid.read(), resultSlot)
                    case _ =>
                        resultSlot.write(CPointer<Unit>())
                        E_NOINTERFACE
                }
            case None =>
                resultSlot.write(CPointer<Unit>())
                E_NOINTERFACE
        }
    }
}

@C
public func iunknownAddRefThunk(instanceRaw: CPointer<Unit>): UInt32 {
    match (lookupRegistryObject(instanceRaw)) {
        case Some(obj) =>
            match (obj) {
                case comObj: ComObjectBase => comObj.addRefBase()
                case _ => 0u32
            }
        case None => 0u32
    }
}

@C
public func iunknownReleaseThunk(instanceRaw: CPointer<Unit>): UInt32 {
    match (lookupRegistryObject(instanceRaw)) {
        case Some(obj) =>
            match (obj) {
                case comObj: ComObjectBase => comObj.releaseBase(instanceRaw.toUIntNative())
                case _ => 0u32
            }
        case None => 0u32
    }
}

@C
public func iinspectableGetIidsThunk(
    instanceRaw: CPointer<Unit>,
    count: CPointer<UInt32>,
    values: CPointer<CPointer<GUID>>
): Int32 {
    unsafe {
        if (count.isNull() || values.isNull()) {
            return E_POINTER
        }
        match (lookupRegistryObject(instanceRaw)) {
            case Some(obj) =>
                match (obj) {
                    case inspectable: IInspectableBase => inspectable.getIidsBase(count, values)
                    case _ =>
                        count.write(0u32)
                        values.write(CPointer<GUID>())
                        E_NOINTERFACE
                }
            case None =>
                count.write(0u32)
                values.write(CPointer<GUID>())
                E_NOINTERFACE
        }
    }
}

@C
public func iinspectableGetRuntimeClassNameThunk(
    instanceRaw: CPointer<Unit>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (value.isNull()) {
            return E_POINTER
        }
        match (lookupRegistryObject(instanceRaw)) {
            case Some(obj) =>
                match (obj) {
                    case inspectable: IInspectableBase => inspectable.getRuntimeClassNameBase(value)
                    case _ =>
                        value.write(CPointer<Unit>())
                        E_NOINTERFACE
                }
            case None =>
                value.write(CPointer<Unit>())
                E_NOINTERFACE
        }
    }
}

@C
public func iinspectableGetTrustLevelThunk(
    instanceRaw: CPointer<Unit>,
    value: CPointer<Int32>
): Int32 {
    unsafe {
        if (value.isNull()) {
            return E_POINTER
        }
        match (lookupRegistryObject(instanceRaw)) {
            case Some(obj) =>
                match (obj) {
                    case inspectable: IInspectableBase => inspectable.getTrustLevelBase(value)
                    case _ =>
                        value.write(0i32)
                        E_NOINTERFACE
                }
            case None =>
                value.write(0i32)
                E_NOINTERFACE
        }
    }
}
