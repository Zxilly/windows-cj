package windows_implement

import windows_interface.*

public func buildIUnknownVtbl(offset!: Int64 = 0): IUnknownVtbl {
    let _ = offset
    var vtbl = IUnknownVtbl()
    vtbl.QueryInterface = iunknownQueryInterfaceThunk
    vtbl.AddRef = iunknownAddRefThunk
    vtbl.Release = iunknownReleaseThunk
    vtbl
}

public func buildIInspectableVtbl(offset!: Int64 = 0): IInspectableVtbl {
    let _ = offset
    var vtbl = IInspectableVtbl()
    vtbl.base_ = buildIUnknownVtbl(offset: offset)
    vtbl.GetIids = iinspectableGetIidsThunk
    vtbl.GetRuntimeClassName = iinspectableGetRuntimeClassNameThunk
    vtbl.GetTrustLevel = iinspectableGetTrustLevelThunk
    vtbl
}
