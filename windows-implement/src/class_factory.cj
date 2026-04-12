package windows_implement

import windows_interface.*

// Factory helpers are intentionally thin: they only assemble the runtime surface
// from explicit descriptor inputs.

public func createComObject<T>(inner: T, supportedIids: Array<GUID>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, supportedIids, agile: agile)
}

public func createComObject<T>(inner: T, supportedIids: Array<GUID>, vtblPtr: CPointer<Unit>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, supportedIids, vtblPtr, agile: agile)
}

public func createComObject<T>(inner: T, supportedIids: Array<GUID>, vtblPtrs: Array<CPointer<Unit>>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, supportedIids, vtblPtrs, agile: agile)
}

public func createComObjectFromSchemas<T>(inner: T, schemas: Array<InterfaceDescriptorSchema>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, schemas, agile: agile)
}

public func createComObjectFromSchemas<T>(inner: T, schemas: Array<InterfaceDescriptorSchema>, vtblPtr: CPointer<Unit>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, schemas, vtblPtr, agile: agile)
}

public func createComObjectFromSchemas<T>(inner: T, schemas: Array<InterfaceDescriptorSchema>, vtblPtrs: Array<CPointer<Unit>>, agile!: Bool = true): ComObject<T> {
    ComObject<T>(inner, schemas, vtblPtrs, agile: agile)
}

public func createComObjectFromDescriptors<T, I>(inner: T, descriptors: Array<InterfaceDescriptor<I>>, agile!: Bool = true): ComObject<T> where I <: ComInterface {
    let supportedIids = supportedIidsFromDescriptors(descriptors)
    let resolvedDescriptors = resolveDescriptors(descriptors)
    let object = ComObject<T>(inner, supportedIids, resolvedDescriptors, agile: agile)
    applyRuntimeTypeFromDescriptors(object.runtime, descriptors)
    object
}

public func createComObjectFromDescriptors<T, I>(
    inner: T,
    descriptors: Array<InterfaceDescriptor<I>>,
    vtblPtr: CPointer<Unit>,
    agile!: Bool = true
): ComObject<T> where I <: ComInterface {
    let supportedIids = supportedIidsFromDescriptors(descriptors)
    let resolvedDescriptors = resolveDescriptors(descriptors)
    let object = ComObject<T>(inner, supportedIids, resolvedDescriptors, vtblPtr, agile: agile)
    applyRuntimeTypeFromDescriptors(object.runtime, descriptors)
    object
}

public func createComObjectFromDescriptors<T, I>(
    inner: T,
    descriptors: Array<InterfaceDescriptor<I>>,
    vtblPtrs: Array<CPointer<Unit>>,
    agile!: Bool = true
): ComObject<T> where I <: ComInterface {
    let supportedIids = supportedIidsFromDescriptors(descriptors)
    let resolvedDescriptors = resolveDescriptors(descriptors)
    let object = ComObject<T>(inner, supportedIids, resolvedDescriptors, vtblPtrs, agile: agile)
    applyRuntimeTypeFromDescriptors(object.runtime, descriptors)
    object
}

public func createResolvedDescriptor(schema: InterfaceDescriptorSchema): ResolvedDescriptor {
    resolveSchema(schema)
}

public func createResolvedDescriptor<I>(descriptor: InterfaceDescriptor<I>): ResolvedDescriptor {
    resolveDescriptor(descriptor)
}
