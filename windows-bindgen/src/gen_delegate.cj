package windows_bindgen

import std.collection.*
import windows_metadata.*

// Generate delegate (callback function type) definitions
// Win32 delegates become CFunc type aliases in Cangjie
public func generateDelegate(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String
): Unit {
    let name = trimTick(index.typeDefName(fileIdx, row))
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)

    // Determine calling convention from UnmanagedFunctionPointerAttribute.
    // Current toolchains reject @CallingConv on CFunc aliases, so delegates are
    // emitted as plain CFunc types regardless of their metadata calling convention.
    match (index.findAttribute(TABLE_TYPE_DEF, fileIdx, row, "UnmanagedFunctionPointerAttribute")) {
        case Some(attrRow) =>
            for ((_, value) in index.attributeValues(fileIdx, attrRow)) {
                match (value) {
                    case MetadataValue.ValI32(conv) =>
                        if (conv == 5) {
                            eprintln("warning: delegate ${name} uses FASTCALL; current Cangjie toolchain cannot encode callback calling conventions on CFunc aliases")
                        }
                    case MetadataValue.ValEnum(_, inner) =>
                        match (inner) {
                            case MetadataValue.ValI32(conv) =>
                                if (conv == 5) {
                                    eprintln("warning: delegate ${name} uses FASTCALL; current Cangjie toolchain cannot encode callback calling conventions on CFunc aliases")
                                }
                            case _ => ()
                        }
                    case _ => ()
                }
            }
        case None => ()
    }

    // Find the Invoke method
    var mi = mStart
    while (mi < mEnd) {
        let methodName = index.methodDefName(fileIdx, mi)
        if (methodName == "Invoke") {
            let generics = Array<MetadataType>(0, {_ => MetadataType.Void})
            let missing = missingMethodDependencies(index, fileIdx, mi, generics)
            if (!missing.isEmpty()) {
                warnMissingMethodDependencies(index, fileIdx, mi, missing)
                return
            }
            let sig = index.methodDefSignature(fileIdx, mi, generics)

            var paramTypes = ArrayList<String>()
            var pi: Int64 = 0
            while (pi < Int64(sig.paramTypes.size)) {
                paramTypes.add(cppType(sig.paramTypes[pi]))
                pi += 1
            }

            let returnType = cppType(sig.returnType)
            let paramStr = joinStrings(paramTypes, ", ")

            let feature = namespaceToFeature(namespace)
            let typeTags = typeAvailabilityTags(namespace, name, fileIdx, row, index.arches(TABLE_TYPE_DEF, fileIdx, row))
            w.writeBlankLine()
            writeAvailabilityForTags(w, feature, typeTags)
            w.writeLine("public type ${name} = CFunc<(${paramStr}) -> ${returnType}>")
            return
        }
        mi += 1
    }
}
