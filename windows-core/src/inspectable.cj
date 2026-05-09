package windows_core

import windows_implement.IInspectableBase
import windows_implement.ComObjectRuntime

public interface IInspectableImpl <: IUnknownImpl & IInspectableBase {}

extend<T> ComObjectRuntime<T> <: IInspectableImpl {}

@C
func coreIInspectableGetIidsThunk(
    instanceRaw: CPointer<Unit>,
    count: CPointer<UInt32>,
    values: CPointer<CPointer<GUID>>
): Int32 {
    unsafe {
        if (count.isNull() || values.isNull()) {
            return E_POINTER.value
        }
        count.write(0u32)
        values.write(CPointer<GUID>())
    }

    match (lookupComImpl<IInspectableImpl>(instanceRaw)) {
        case Some(value) =>
            value.getIidsBase(count, values)
        case None =>
            E_NOINTERFACE.value
    }
}

@C
func coreIInspectableGetRuntimeClassNameThunk(
    instanceRaw: CPointer<Unit>,
    value: CPointer<CPointer<Unit>>
): Int32 {
    unsafe {
        if (value.isNull()) {
            return E_POINTER.value
        }
        value.write(CPointer<Unit>())
    }

    match (lookupComImpl<IInspectableImpl>(instanceRaw)) {
        case Some(inspectable) =>
            inspectable.getRuntimeClassNameBase(value)
        case None =>
            E_NOINTERFACE.value
    }
}

@C
func coreIInspectableGetTrustLevelThunk(
    instanceRaw: CPointer<Unit>,
    value: CPointer<Int32>
): Int32 {
    unsafe {
        if (value.isNull()) {
            return E_POINTER.value
        }
        value.write(0i32)
    }

    match (lookupComImpl<IInspectableImpl>(instanceRaw)) {
        case Some(inspectable) =>
            inspectable.getTrustLevelBase(value)
        case None =>
            E_NOINTERFACE.value
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
