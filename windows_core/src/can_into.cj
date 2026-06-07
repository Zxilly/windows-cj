package windows_core

import windows_interface.{InterfaceDescriptorBase, eraseInterfaceDescriptor}

func descriptorVtableMatches(descriptor: InterfaceDescriptorBase, candidate: GUID): Bool {
    if (descriptor.descriptorIid() == candidate) {
        return true
    }
    match (descriptor.descriptorDirectBase()) {
        case Some(base) =>
            descriptorVtableMatches(base, candidate)
        case None =>
            false
    }
}

public func queryRequiredFor<T, U>(): Bool where T <: ComInterface & Interface<T>, U <: ComInterface & Interface<U> {
    if (T.iid() == U.iid()) {
        return false
    }
    !descriptorVtableMatches(eraseInterfaceDescriptor<U>(U.descriptor()), T.iid())
}
