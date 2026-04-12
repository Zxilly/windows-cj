package windows_implement

import windows_interface.*

public unsafe func asImpl<T>(source: ComInterface): Option<T> {
    asImplFromRaw<T>(source.asRaw())
}

public unsafe func asImplFromRaw<T>(raw: CPointer<Unit>, slotOffset!: Int64 = -1): Option<T> {
    if (raw.isNull()) {
        return None
    }
    let lookupKey = rootRegistryKeyFromRaw(raw, slotOffset: slotOffset)
    let scopedLookupRaw = if (slotOffset >= 0) {
        recoverRootRaw(raw, slotOffset: slotOffset)
    } else {
        raw
    }
    match (comRegistryLookup(lookupKey)) {
        case Some(obj) =>
            match (obj) {
                case access: ImplementationAccess => access.getImplAs<T>()
                case _ => None
            }
        case None => lookupScopedInterfaceTarget<T>(scopedLookupRaw)
    }
}
