package windows_core

// Compatibility facade: the implementation runtime lives in windows_implement.
// Keep these public imports so existing windows_core users do not need to
// change imports while the hand-written COM implementation remains single-owned.
public import windows_implement.{
    ComObject,
    ComObjectRuntime,
    ComObjectBase,
    IInspectableBase,
    ImplementationAccess,
    WeakReferenceOwner,
    ResolvedDescriptor,
    StaticComObject,
    asImpl,
    asImplFromRaw,
    buildIUnknownVtbl,
    buildIInspectableVtbl,
    createComObject,
    createComObjectFromSchemas,
    createComObjectFromDescriptors,
    createResolvedDescriptor,
    createStaticComObject,
    createStaticComObjectFromSchemas,
    createStaticComObjectFromDescriptors
}

extend<T> ComObject<T> {
    public func asInterfaceRef<I>(descriptor: InterfaceDescriptor<I>): InterfaceRef<I> where I <: ComInterface & Interface<I> {
        let view = asInterface(descriptor)
        InterfaceRef<I>.fromInterface(view)
    }
}
