package windows_core

func writePublishedLength(lengthTarget: CPointer<UInt32>, length: UInt32): Unit {
    if (lengthTarget.isNotNull()) {
        unsafe { lengthTarget.write(length) }
    }
}

func allocateUnitPointerSlots(length: Int64): CPointer<CPointer<Unit>> {
    if (length <= 0) {
        return CPointer<CPointer<Unit>>()
    }

    let totalBytes = sizeOf<UIntNative>() * UIntNative(length)
    let raw = unsafe { CoTaskMemAlloc(totalBytes) }
    if (raw.isNull()) {
        throw WindowsException(E_OUTOFMEMORY)
    }
    CPointer<CPointer<Unit>>(raw)
}

func releasePublishedObjectSlots<T>(
    values: Array<T>,
    slots: CPointer<CPointer<Unit>>,
    count: Int64
): Unit {
    var index = 0
    while (index < count) {
        let raw = unsafe { (slots + index).read() }
        match (values[index]) {
            case _: HString =>
                releaseSystemHStringHandle(raw)
            case _: ComInterface =>
                interfaceHandleReleaseRaw(raw)
            case _ => ()
        }
        index += 1
    }
}

func publishCopyArray<T>(
    staged: AbiArray<T>,
    dataTarget: CPointer<CPointer<T>>,
    lengthTarget: CPointer<UInt32>
): Unit where T <: CType {
    if (dataTarget.isNull()) {
        writePublishedLength(lengthTarget, UInt32(staged.len()))
        staged.close()
        return
    }

    let (raw, length) = staged.intoAbi()
    unsafe { dataTarget.write(raw) }
    writePublishedLength(lengthTarget, length)
}

func publishObjectArray<T>(
    staged: AbiArray<T>,
    dataTarget: CPointer<CPointer<Unit>>,
    lengthTarget: CPointer<UInt32>
): Unit {
    let values = staged.toArray()
    let length = UInt32(values.size)

    try {
        if (dataTarget.isNotNull()) {
            if (values.size == 0) {
                unsafe { dataTarget.write(CPointer<Unit>()) }
            } else {
                let slots = allocateUnitPointerSlots(values.size)
                var index = 0
                try {
                    while (index < values.size) {
                        match (values[index]) {
                            case value: HString =>
                                unsafe { (slots + index).write(value.toSystemHandleCopy()) }
                            case value: ComInterface =>
                                let raw = value.asRaw()
                                if (raw.isNotNull()) {
                                    interfaceHandleAddRefRaw(raw)
                                }
                                unsafe { (slots + index).write(raw) }
                            case _ =>
                                throw Exception("ArrayProxy object marshaller only supports HString and COM interface elements")
                        }
                        index += 1
                    }
                } catch (error: Exception) {
                    releasePublishedObjectSlots(values, slots, index)
                    unsafe { CoTaskMemFree(CPointer<Unit>(slots)) }
                    throw error
                }
                unsafe { dataTarget.write(CPointer<Unit>(slots)) }
            }
        }

        writePublishedLength(lengthTarget, length)
        staged.close()
    } finally {
        closeProjectedElements(values)
    }
}

// ArrayProxy stages an ABI array and publishes it to WinRT out parameters on close.
public class ArrayProxy<T> <: Resource {
    private let publish: (AbiArray<T>) -> Unit
    private let staged = AbiArray<T>()
    private var closed: Bool = false

    init(publish: (AbiArray<T>) -> Unit) {
        this.publish = publish
    }

    public func value(): AbiArray<T> {
        staged
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        publish(staged)
        closed = true
    }

    ~init() {
        // Finalizers must not invoke publish or staged cleanup; those paths can
        // release native handles or projected HString storage. Explicit close()
        // remains the deterministic owner for staged cleanup/publication.
        if (!closed) {
            closed = true
        }
    }
}

public unsafe func arrayProxy<T>(
    dataTarget: CPointer<CPointer<T>>,
    lengthTarget: CPointer<UInt32>
): ArrayProxy<T> where T <: CType {
    ArrayProxy<T>({ staged => publishCopyArray(staged, dataTarget, lengthTarget) })
}

public unsafe func arrayProxy<T>(
    dataTarget: CPointer<CPointer<Unit>>,
    lengthTarget: CPointer<UInt32>
): ArrayProxy<T> {
    ArrayProxy<T>({ staged => publishObjectArray(staged, dataTarget, lengthTarget) })
}
