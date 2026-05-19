package windows_implement

import windows_interface.*

public func createFreeThreadedMarshaler(outer: CPointer<Unit>): Option<IMarshal> {
    if (outer.isNull()) {
        return None
    }

    var marshalerRaw = CPointer<Unit>()
    let hr = unsafe {
        CoCreateFreeThreadedMarshaler(outer, CPointer<CPointer<Unit>>(inout marshalerRaw))
    }
    if (hr != S_OK) {
        releaseFailedComOutSlot(CPointer<CPointer<Unit>>(inout marshalerRaw))
        return None
    }
    if (marshalerRaw.isNull()) {
        return None
    }

    let marshalerUnknown = IUnknown.fromAbiTake(marshalerRaw)
    match (unsafe { queryInterfaceAs(marshalerRaw, IMarshal.descriptor()) }) {
        case Some(value) =>
            marshalerUnknown.close()
            Some(value)
        case None =>
            marshalerUnknown.close()
            None
    }
}

public func cloneMarshaler(marshaler: IMarshal, resultSlot: CPointer<CPointer<Unit>>): Int32 {
    if (resultSlot.isNull()) {
        return E_POINTER
    }
    let raw = marshaler.asRaw()
    if (raw.isNull()) {
        unsafe { resultSlot.write(CPointer<Unit>()) }
        return E_NOINTERFACE
    }
    marshaler.addRef()
    unsafe { resultSlot.write(raw) }
    S_OK
}
