package windows_implement

import windows_interface.*
import windows_result.{E_FAIL, WindowsException}
import windows_strings.releaseSystemHStringHandle

// Thunks translate native COM callbacks into registry-backed runtime calls.

func lookupRegistryObject(instanceRaw: CPointer<Unit>): Option<Object> {
    if (instanceRaw.isNull()) {
        return None
    }
    unsafe { comRegistryLookup(rootRegistryKeyFromRaw(instanceRaw)) }
}

func releaseFailedRuntimeClassNameSlot(hr: Int32, value: CPointer<CPointer<Unit>>): Int32 {
    if (hr >= 0 || value.isNull()) {
        return hr
    }

    unsafe {
        let raw = value.read()
        if (raw.isNotNull()) {
            releaseSystemHStringHandle(raw)
            value.write(CPointer<Unit>())
        }
    }
    hr
}

func clearInspectableIidsOutSlots(count: CPointer<UInt32>, values: CPointer<CPointer<GUID>>): Unit {
    unsafe {
        if (count.isNotNull()) {
            count.write(0u32)
        }
        if (values.isNotNull()) {
            values.write(CPointer<GUID>())
        }
    }
}

func releaseFailedInspectableIidsOutSlots(
    hr: Int32,
    count: CPointer<UInt32>,
    values: CPointer<CPointer<GUID>>
): Int32 {
    if (hr < 0 && values.isNotNull()) {
        unsafe {
            let raw = values.read()
            if (raw.isNotNull()) {
                CoTaskMemFree(CPointer<Unit>(raw))
            }
        }
    }
    if (hr < 0) {
        clearInspectableIidsOutSlots(count, values)
    }
    hr
}

func clearTrustLevelOutSlot(value: CPointer<Int32>): Unit {
    unsafe {
        if (value.isNotNull()) {
            value.write(0i32)
        }
    }
}

@C
public func iunknownQueryInterfaceThunk(
    instanceRaw: CPointer<Unit>,
    iid: CPointer<GUID>,
    resultSlot: CPointer<CPointer<Unit>>
): Int32 {
    try {
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
    } catch (error: WindowsException) {
        releaseFailedComOutSlot(resultSlot)
        error.code().value
    } catch (_: Exception) {
        releaseFailedComOutSlot(resultSlot)
        E_FAIL.value
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
    try {
        unsafe {
            if (count.isNull() || values.isNull()) {
                clearInspectableIidsOutSlots(count, values)
                return E_POINTER
            }
            clearInspectableIidsOutSlots(count, values)
            let hr = match (lookupRegistryObject(instanceRaw)) {
                case Some(obj) =>
                    match (obj) {
                        case inspectable: IInspectableBase => inspectable.getIidsBase(count, values)
                        case _ => E_NOINTERFACE
                    }
                case None => E_NOINTERFACE
            }
            releaseFailedInspectableIidsOutSlots(hr, count, values)
        }
    } catch (error: WindowsException) {
        releaseFailedInspectableIidsOutSlots(error.code().value, count, values)
    } catch (_: Exception) {
        releaseFailedInspectableIidsOutSlots(E_FAIL.value, count, values)
    }
}

@C
public func iinspectableGetRuntimeClassNameThunk(
    instanceRaw: CPointer<Unit>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    try {
        unsafe {
            if (value.isNull()) {
                return E_POINTER
            }
            value.write(CPointer<Unit>())
            let hr = match (lookupRegistryObject(instanceRaw)) {
                case Some(obj) =>
                    match (obj) {
                        case inspectable: IInspectableBase => inspectable.getRuntimeClassNameBase(value)
                        case _ => E_NOINTERFACE
                    }
                case None => E_NOINTERFACE
            }
            releaseFailedRuntimeClassNameSlot(hr, value)
        }
    } catch (error: WindowsException) {
        releaseFailedRuntimeClassNameSlot(error.code().value, value)
    } catch (_: Exception) {
        releaseFailedRuntimeClassNameSlot(E_FAIL.value, value)
    }
}

@C
public func iinspectableGetTrustLevelThunk(
    instanceRaw: CPointer<Unit>,
    value: CPointer<Int32>
): Int32 {
    try {
        unsafe {
            if (value.isNull()) {
                return E_POINTER
            }
            clearTrustLevelOutSlot(value)
            match (lookupRegistryObject(instanceRaw)) {
                case Some(obj) =>
                    match (obj) {
                        case inspectable: IInspectableBase => inspectable.getTrustLevelBase(value)
                        case _ => E_NOINTERFACE
                    }
                case None => E_NOINTERFACE
            }
        }
    } catch (error: WindowsException) {
        clearTrustLevelOutSlot(value)
        error.code().value
    } catch (_: Exception) {
        clearTrustLevelOutSlot(value)
        E_FAIL.value
    }
}
