package windows_interface

public unsafe func allocateNativeValue<T>(value: T): CPointer<T> where T <: CType {
    let raw = LibC.malloc<T>()
    if (raw.isNull()) {
        throw Exception("native allocation failed")
    }
    raw.write(value)
    raw
}

public unsafe func allocateNativeArray<T>(values: Array<T>): CPointer<T> where T <: CType {
    if (values.size == 0) {
        return CPointer<T>()
    }
    let raw = LibC.malloc<T>(count: values.size)
    if (raw.isNull()) {
        throw Exception("native allocation failed")
    }
    var index = 0
    while (index < values.size) {
        (raw + index).write(values[index])
        index += 1
    }
    raw
}

public unsafe func freeNativeValue<T>(raw: CPointer<T>): Unit where T <: CType {
    if (raw.isNotNull()) {
        LibC.free<T>(raw)
    }
}
