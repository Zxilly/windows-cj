package windows_implement

import windows_interface.*

public class StaticComObject<T> {
    private let object: ComObject<T>
    public let runtime: ComObjectRuntime<T>

    public init(object: ComObject<T>) {
        this.object = object
        this.runtime = object.runtime
        this.runtime.pinStaticReference()
    }

    public func asRaw(): CPointer<Unit> {
        object.asRaw()
    }

    public func toInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface {
        object.toInterface(descriptor)
    }

    public func asInterface<I>(descriptor: InterfaceDescriptor<I>): I where I <: ComInterface {
        object.asInterface(descriptor)
    }
}

public func createStaticComObject<T>(inner: T, supportedIids: Array<GUID>, agile!: Bool = true): StaticComObject<T> {
    StaticComObject<T>(createComObject(inner, supportedIids, agile: agile))
}

public func createStaticComObjectFromSchemas<T>(
    inner: T,
    schemas: Array<InterfaceDescriptorSchema>,
    agile!: Bool = true
): StaticComObject<T> {
    StaticComObject<T>(createComObjectFromSchemas(inner, schemas, agile: agile))
}

public func createStaticComObjectFromDescriptors<T, I>(
    inner: T,
    descriptors: Array<InterfaceDescriptor<I>>,
    agile!: Bool = true
): StaticComObject<T> where I <: ComInterface {
    StaticComObject<T>(createComObjectFromDescriptors(inner, descriptors, agile: agile))
}
