package windows_implement

import windows_interface.*

// Thunks translate native COM callbacks into registry-backed runtime calls.

func lookupRegistryObject(this_: CPointer<Unit>): Option<Object> {
    if (this_.isNull()) {
        return None
    }
    unsafe { comRegistryLookup(rootRegistryKeyFromRaw(this_)) }
}

@C
public func iunknownQueryInterfaceThunk(
    this_: CPointer<Unit>,
    iid: CPointer<GUID>,
    ppvObject: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (ppvObject.isNull()) {
            return E_POINTER
        }
        match (lookupRegistryObject(this_)) {
            case Some(obj) =>
                match (obj) {
                    case comObj: ComObjectBase =>
                        if (iid.isNull()) {
                            ppvObject.write(CPointer<Unit>())
                            return E_POINTER
                        }
                        comObj.queryInterfaceBase(this_, iid.read(), ppvObject)
                    case _ =>
                        ppvObject.write(CPointer<Unit>())
                        E_NOINTERFACE
                }
            case None =>
                ppvObject.write(CPointer<Unit>())
                E_NOINTERFACE
        }
    }
}

@C
public func iunknownAddRefThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupRegistryObject(this_)) {
        case Some(obj) =>
            match (obj) {
                case comObj: ComObjectBase => comObj.addRefBase()
                case _ => 0u32
            }
        case None => 0u32
    }
}

@C
public func iunknownReleaseThunk(this_: CPointer<Unit>): UInt32 {
    match (lookupRegistryObject(this_)) {
        case Some(obj) =>
            match (obj) {
                case comObj: ComObjectBase => comObj.releaseBase(this_.toUIntNative())
                case _ => 0u32
            }
        case None => 0u32
    }
}

@C
public func iinspectableGetIidsThunk(
    this_: CPointer<Unit>,
    count: CPointer<UInt32>,
    values: CPointer<CPointer<GUID>>
): Int32 {
    unsafe {
        if (count.isNull() || values.isNull()) {
            return E_POINTER
        }
        match (lookupRegistryObject(this_)) {
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
    this_: CPointer<Unit>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (value.isNull()) {
            return E_POINTER
        }
        match (lookupRegistryObject(this_)) {
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
    this_: CPointer<Unit>,
    value: CPointer<Int32>
): Int32 {
    unsafe {
        if (value.isNull()) {
            return E_POINTER
        }
        match (lookupRegistryObject(this_)) {
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
