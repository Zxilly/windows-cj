package windows_bindgen

import std.collection.*
import windows_metadata.*

// Generate handle type aliases
// Handle types are structs with a single field named "Value" of a primitive type.
// In Cangjie, these map to type aliases: type HANDLE = CPointer<Unit>
public func generateHandle(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String
): Unit {
    if (!isHandleType(index, fileIdx, row)) {
        return
    }

    let name = trimTick(index.typeDefName(fileIdx, row))
    let (fStart, _) = index.typeDefFields(fileIdx, row)
    let fieldType = index.fieldType(fileIdx, fStart)
    let cjType = cppType(fieldType)

    let feature = namespaceToFeature(namespace)
    let typeTags = typeAvailabilityTags(namespace, name, fileIdx, row, index.arches(TABLE_TYPE_DEF, fileIdx, row))
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)

    // Map the underlying primitive to the appropriate pointer or primitive type
    let handleType = handleAliasToCj(namespace, name, cjType)
    w.writeLine("public type ${name} = ${handleType}")
}

func handleAliasToCj(namespace: String, name: String, underlyingType: String): String {
    if (namespace == "Windows.Win32.Foundation") {
        if (name == "LRESULT") {
            return "IntNative"
        }
        if (name == "LPARAM") {
            return "IntNative"
        }
        if (name == "WPARAM") {
            return "UIntNative"
        }
    }
    return handleUnderlyingToCj(underlyingType)
}

// Map handle underlying types to their Cangjie equivalents
func handleUnderlyingToCj(underlyingType: String): String {
    // Most handles are pointer-sized integers that represent opaque OS handles
    if (underlyingType == "IntNative" || underlyingType == "UIntNative") {
        return "CPointer<Unit>"
    }
    if (underlyingType == "Int64" || underlyingType == "UInt64") {
        return "CPointer<Unit>"
    }
    if (underlyingType == "Int32" || underlyingType == "UInt32") {
        // Some handles are 32-bit (rare), still use pointer for consistency
        return underlyingType
    }
    return underlyingType
}

// Generate all handle type aliases for a namespace
public func generateHandlesForNamespace(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String
): Unit {
    let types = index.iter()
    for (entry in types) {
        let (ns, _, fIdx, tRow) = entry
        if (ns != namespace) {
            continue
        }
        let category = index.typeDefCategory(fIdx, tRow)
        match (category) {
            case Struct =>
                if (isHandleType(index, fIdx, tRow)) {
                    generateHandle(w, index, fIdx, tRow, namespace)
                }
            case _ => ()
        }
    }
}
