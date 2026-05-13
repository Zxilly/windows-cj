package windows_core

import windows_interface.InterfaceDescriptorBase

func descriptorVtableMatches(descriptor: InterfaceDescriptorBase, candidate: GUID): Bool {
    if (descriptor.descriptorIid() == candidate) {
        return true
    }
    match (descriptor.descriptorDirectBase()) {
        case Some(baseDescriptor) =>
            return descriptorVtableMatches(baseDescriptor, candidate)
        case None => ()
    }
    for (ancestor in descriptor.descriptorAncestorIids()) {
        if (ancestor == candidate) {
            return true
        }
    }
    false
}

public func queryRequiredFor<T, U>(): Bool where T <: ComInterface & Interface<T>, U <: ComInterface & Interface<U> {
    if (T.iid() == U.iid()) {
        return false
    }
    !descriptorVtableMatches(U.descriptor(), T.iid())
}

public func coerceInterfaceValue<T, U>(
    value: U,
    target: InterfaceDescriptor<T>
): Result<T> where T <: ComInterface & Interface<T>, U <: ComInterface & Interface<U> {
    let raw = value.asRaw()
    if (raw.isNull()) {
        return Result<T>.Err(WinError(E_POINTER))
    }

    if (!queryRequiredFor<T, U>()) {
        return Result<T>.Ok(target.viewOf(raw))
    }

    match (unsafe { queryInterfaceRaw(raw, target.iid) }) {
        case Some(resolved) =>
            Result<T>.Ok(target.takeFromAbi(resolved))
        case None =>
            Result<T>.Err(WinError(E_NOINTERFACE))
    }
}
