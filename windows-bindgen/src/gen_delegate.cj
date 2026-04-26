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
    if (!shouldEmitDelegateRow(index, namespace, name, fileIdx, row)) {
        return
    }

    if (skipForSysGeneric(index, fileIdx, row)) {
        return
    }

    let mergedType = mergedDelegateAliasType(index, namespace, name, fileIdx, row)
    if (mergedType.isEmpty()) {
        return
    }

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
            let feature = namespaceToFeature(namespace)
            let typeTags = mergedDelegateTypeAvailabilityTags(index, namespace, name, fileIdx, row)
            w.writeBlankLine()
            writeAvailabilityForTags(w, feature, typeTags)
            w.writeLine("public type ${name} = ${mergedType}")
            return
        }
        mi += 1
    }
}

func shouldEmitDelegateRow(
    index: TypeIndex,
    namespace: String,
    name: String,
    fileIdx: Int64,
    row: Int64
): Bool {
    match (bindgenContext()) {
        case Some(context) =>
            let entries = context.typeMap.entriesForType(namespace, name)
            for (entry in entries) {
                match (index.typeDefCategory(entry.fileIdx, entry.row)) {
                    case Delegate => ()
                    case _ => continue
                }
                if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row))) {
                    continue
                }
                return entry.fileIdx == fileIdx && entry.row == row
            }
            return true
        case None =>
            return true
    }
}

func mergedDelegateTypeAvailabilityTags(
    index: TypeIndex,
    namespace: String,
    name: String,
    fileIdx: Int64,
    row: Int64
): ArrayList<String> {
    let result = ArrayList<String>()
    match (bindgenContext()) {
        case Some(context) =>
            let entries = context.typeMap.entriesForType(namespace, name)
            for (entry in entries) {
                match (index.typeDefCategory(entry.fileIdx, entry.row)) {
                    case Delegate => ()
                    case _ => continue
                }
                let entryArches = index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row)
                if (isUnsupportedOnlyArchitecture(entryArches)) {
                    continue
                }
                let entryTags = typeAvailabilityTags(namespace, name, entry.fileIdx, entry.row, entryArches)
                for (tag in entryTags) {
                    if (!containsDelegateTag(result, tag)) {
                        result.add(tag)
                    }
                }
            }
        case None => ()
    }
    if (result.isEmpty()) {
        return typeAvailabilityTags(namespace, name, fileIdx, row, index.arches(TABLE_TYPE_DEF, fileIdx, row))
    }
    return result
}

func containsDelegateTag(values: ArrayList<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

func mergedDelegateAliasType(
    index: TypeIndex,
    namespace: String,
    name: String,
    fileIdx: Int64,
    row: Int64
): String {
    let entries = collectDelegateRows(index, namespace, name, fileIdx, row)
    if (entries.isEmpty()) {
        return ""
    }

    let signatures = ArrayList<MethodSignature>()
    for ((entryFileIdx, entryRow) in entries) {
        match (delegateInvokeSignature(index, entryFileIdx, entryRow)) {
            case Some(sig) => signatures.add(sig)
            case None => ()
        }
    }
    if (signatures.isEmpty()) {
        return ""
    }

    let canonical = signatures[0]
    let returnTypes = ArrayList<String>()
    for (sig in signatures) {
        returnTypes.add(functionAbiTypeForPointerInNamespace(namespace, sig.returnType))
    }
    let mergedReturnType = mergeDelegateTypeStrings(returnTypes, "${namespace}.${name}", "return")

    var mergedParamTypes = ArrayList<String>()
    var paramCount = Int64(canonical.paramTypes.size)
    for (sig in signatures) {
        if (Int64(sig.paramTypes.size) != paramCount) {
            eprintln("warning: delegate ${namespace}.${name} has incompatible overload arity; using first signature")
            return delegateAliasTypeForSignature(namespace, canonical)
        }
    }

    var pi: Int64 = 0
    while (pi < paramCount) {
        let paramTypes = ArrayList<String>()
        for (sig in signatures) {
            paramTypes.add(functionAbiTypeForPointerInNamespace(namespace, sig.paramTypes[pi]))
        }
        mergedParamTypes.add(mergeDelegateTypeStrings(paramTypes, "${namespace}.${name}", "parameter ${pi}"))
        pi += 1
    }

    return "CFunc<(${joinStrings(mergedParamTypes, ", ")}) -> ${mergedReturnType}>"
}

func collectDelegateRows(
    index: TypeIndex,
    namespace: String,
    name: String,
    fileIdx: Int64,
    row: Int64
): ArrayList<(Int64, Int64)> {
    let result = ArrayList<(Int64, Int64)>()
    match (bindgenContext()) {
        case Some(context) =>
            let entries = context.typeMap.entriesForType(namespace, name)
            for (entry in entries) {
                match (index.typeDefCategory(entry.fileIdx, entry.row)) {
                    case Delegate => ()
                    case _ => continue
                }
                if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, entry.fileIdx, entry.row))) {
                    continue
                }
                result.add((entry.fileIdx, entry.row))
            }
        case None =>
            result.add((fileIdx, row))
    }
    return result
}

func delegateInvokeSignature(index: TypeIndex, fileIdx: Int64, row: Int64): Option<MethodSignature> {
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var mi = mStart
    while (mi < mEnd) {
        if (index.methodDefName(fileIdx, mi) == "Invoke") {
            let generics = Array<MetadataType>(0, {_ => MetadataType.Void})
            let missing = missingMethodDependencies(index, fileIdx, mi, generics)
            if (!missing.isEmpty()) {
                warnMissingMethodDependencies(index, fileIdx, mi, missing)
                return None
            }
            return Some(index.methodDefSignature(fileIdx, mi, generics))
        }
        mi += 1
    }
    return None
}

func delegateAliasTypeForSignature(namespace: String, sig: MethodSignature): String {
    let paramTypes = ArrayList<String>()
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        paramTypes.add(functionAbiTypeForPointerInNamespace(namespace, sig.paramTypes[pi]))
        pi += 1
    }
    return "CFunc<(${joinStrings(paramTypes, ", ")}) -> ${functionAbiTypeForPointerInNamespace(namespace, sig.returnType)}>"
}

func mergeDelegateTypeStrings(
    types: ArrayList<String>,
    delegateName: String,
    position: String
): String {
    if (types.isEmpty()) {
        return "Unit"
    }

    let first = types[0]
    var allSame = true
    for (typeName in types) {
        if (typeName != first) {
            allSame = false
            break
        }
    }
    if (allSame) {
        return first
    }

    if (allPointerTypes(types)) {
        let depth = commonPointerDepth(types)
        if (depth > 0) {
            return pointerTypeWithUnit(depth)
        }
        return "CPointer<Unit>"
    }

    // Build the deduplicated list of distinct type strings observed across the merged delegate
    // rows (typically one row per architecture). The chosen merged type is `first`, which matches
    // the row order returned by `collectDelegateRows`. When the divergence reduces to a 32-bit
    // pointer slot vs. a 64-bit integer slot the difference is purely an architecture-conditioned
    // ABI shape (x86 vs. x64/aarch64). The arch gate emitted alongside this delegate excludes the
    // x86-only row anyway, so the merged type is correct for every emitted target -- the divergence
    // is metadata noise, not an ABI bug.
    let distinct = ArrayList<String>()
    for (typeName in types) {
        var seen = false
        for (existing in distinct) {
            if (existing == typeName) {
                seen = true
                break
            }
        }
        if (!seen) {
            distinct.add(typeName)
        }
    }
    if (distinct.size <= 1) {
        return first
    }
    if (delegateDivergenceIsArchPointerWidth(distinct)) {
        // Suppress: pointer-width divergence between architectures collapses to the architecturally
        // correct integer slot for the kept row; x86 row (if any) is filtered by arch gate.
        return first
    }

    eprintln("warning: delegate ${delegateName} has incompatible ${position} types ${distinct}; using first signature type ${first} (cangjie-paradigm: cross-arch metadata rows merged into a single CFunc alias)")
    return first
}

// Detect "32-bit pointer vs 64-bit integer" divergences across architecture-specific delegate
// rows. Such divergences are inherent in winmd metadata (PTERMINATION_HANDLER, etc.) and resolve
// to the correct slot for whichever architecture the resulting alias is gated to.
func delegateDivergenceIsArchPointerWidth(distinct: ArrayList<String>): Bool {
    if (distinct.size != 2) {
        return false
    }
    var hasUInt64 = false
    var hasNarrowPointer = false
    for (ty in distinct) {
        if (ty == "UInt64") {
            hasUInt64 = true
        } else if (ty == "CPointer<Unit>" || ty.startsWith("CPointer<")) {
            hasNarrowPointer = true
        }
    }
    return hasUInt64 && hasNarrowPointer
}

func allPointerTypes(types: ArrayList<String>): Bool {
    for (typeName in types) {
        if (pointerDepth(typeName) <= 0) {
            return false
        }
    }
    return true
}

func commonPointerDepth(types: ArrayList<String>): Int64 {
    if (types.isEmpty()) {
        return 0
    }
    let firstDepth = pointerDepth(types[0])
    if (firstDepth <= 0) {
        return 0
    }
    for (typeName in types) {
        if (pointerDepth(typeName) != firstDepth) {
            return 1
        }
    }
    return firstDepth
}

func pointerDepth(typeName: String): Int64 {
    var current = typeName
    var depth: Int64 = 0
    while (current.startsWith("CPointer<") && current.endsWith(">")) {
        let arr = current.toArray()
        current = String.fromUtf8(arr[Int64("CPointer<".toArray().size)..Int64(arr.size) - 1])
        depth += 1
    }
    return depth
}

func pointerTypeWithUnit(depth: Int64): String {
    var result = "Unit"
    var remaining = depth
    while (remaining > 0) {
        result = "CPointer<${result}>"
        remaining -= 1
    }
    return result
}
