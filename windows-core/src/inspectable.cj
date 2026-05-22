package windows_core

import windows_implement.IInspectableBase
import windows_implement.ComObjectRuntime
import windows_strings.releaseSystemHStringHandle

public interface IInspectableImpl <: IUnknownImpl & IInspectableBase {}

extend<T> ComObjectRuntime<T> <: IInspectableImpl {}

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

func clearInspectableTrustLevelOutSlot(value: CPointer<Int32>): Unit {
    unsafe {
        if (value.isNotNull()) {
            value.write(0i32)
        }
    }
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
                coTaskMemFree(CPointer<Unit>(raw))
            }
        }
    }
    if (hr < 0) {
        clearInspectableIidsOutSlots(count, values)
    }
    hr
}

@C
func coreIInspectableGetIidsThunk(
    instanceRaw: CPointer<Unit>,
    count: CPointer<UInt32>,
    values: CPointer<CPointer<GUID>>
): Int32 {
    try {
        unsafe {
            if (count.isNull() || values.isNull()) {
                clearInspectableIidsOutSlots(count, values)
                return E_POINTER.value
            }
            clearInspectableIidsOutSlots(count, values)
        }

        let hr = match (lookupComImpl<IInspectableImpl>(instanceRaw)) {
            case Some(value) =>
                value.getIidsBase(count, values)
            case None =>
                E_NOINTERFACE.value
        }
        releaseFailedInspectableIidsOutSlots(hr, count, values)
    } catch (error: WindowsException) {
        releaseFailedInspectableIidsOutSlots(error.code().value, count, values)
    } catch (_: Exception) {
        releaseFailedInspectableIidsOutSlots(E_FAIL.value, count, values)
    }
}

@C
func coreIInspectableGetRuntimeClassNameThunk(
    instanceRaw: CPointer<Unit>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    try {
        unsafe {
            if (value.isNull()) {
                return E_POINTER.value
            }
            value.write(CPointer<Unit>())
        }

        let hr = match (lookupComImpl<IInspectableImpl>(instanceRaw)) {
            case Some(inspectable) =>
                inspectable.getRuntimeClassNameBase(value)
            case None =>
                E_NOINTERFACE.value
        }
        releaseFailedRuntimeClassNameSlot(hr, value)
    } catch (error: WindowsException) {
        releaseFailedRuntimeClassNameSlot(error.code().value, value)
    } catch (_: Exception) {
        releaseFailedRuntimeClassNameSlot(E_FAIL.value, value)
    }
}

@C
func coreIInspectableGetTrustLevelThunk(
    instanceRaw: CPointer<Unit>,
    value: CPointer<Int32>
): Int32 {
    try {
        unsafe {
            if (value.isNull()) {
                return E_POINTER.value
            }
        }
        clearInspectableTrustLevelOutSlot(value)

        match (lookupComImpl<IInspectableImpl>(instanceRaw)) {
            case Some(inspectable) =>
                inspectable.getTrustLevelBase(value)
            case None =>
                E_NOINTERFACE.value
        }
    } catch (error: WindowsException) {
        clearInspectableTrustLevelOutSlot(value)
        error.code().value
    } catch (_: Exception) {
        clearInspectableTrustLevelOutSlot(value)
        E_FAIL.value
    }
}

public func newIInspectableVtbl<T>(offset!: Int64 = 0): IInspectableVtbl where T <: IInspectableImpl {
    let _ = offset
    var vtbl = IInspectableVtbl()
    vtbl.base_ = newIUnknownVtbl<T>(offset: offset)
    vtbl.GetIids = coreIInspectableGetIidsThunk
    vtbl.GetRuntimeClassName = coreIInspectableGetRuntimeClassNameThunk
    vtbl.GetTrustLevel = coreIInspectableGetTrustLevelThunk
    vtbl
}
