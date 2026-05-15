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

