package windows_bindgen

import std.collection.*
import windows_metadata.*

let emptyFunctionGroupField = "__bindgen_empty__"

// Generate foreign func declarations for Win32 functions
// Groups functions by their DLL module and calling convention
public func generateFunctions(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String
): Unit {
    let category = index.typeDefCategory(fileIdx, row)
    match (category) {
        case Class =>
            // Win32 "class" types hold static methods that map to DLL functions
            let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
            if (mStart >= mEnd) {
                return
            }

            // Group methods by (module, callingConv)
            let groups = HashMap<String, ArrayList<Int64>>()
            let groupKeys = ArrayList<String>()
            var mi = mStart
            while (mi < mEnd) {
                let flags = index.methodDefFlags(fileIdx, mi)
                if (flags.contains(MethodAttributes.Static) && flags.contains(MethodAttributes.Public)) {
                    match (index.methodDefImplMap(fileIdx, mi)) {
                        case Some((pinvoke, _, moduleName)) =>
                            let missing = missingMethodDependencies(index, fileIdx, mi, Array<MetadataType>(0, {_ => MetadataType.Void}))
                            if (!missing.isEmpty()) {
                                warnMissingMethodDependencies(index, fileIdx, mi, missing)
                                mi += 1
                                continue
                            }
                            let cc = callingConventionAnnotation(pinvoke)
                            let condition = availabilityCondition(moduleToFeature(moduleName), itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, mi))
                            let key = functionGroupKey(moduleName, cc, condition)
                            if (!groups.contains(key)) {
                                groups[key] = ArrayList<Int64>()
                                groupKeys.add(key)
                            }
                            groups[key].add(mi)
                        case None => ()
                    }
                }
                mi += 1
            }

            // Generate a foreign block per group
            sortStrings(groupKeys)
            for (key in groupKeys) {
                let methods = groups[key]
                let (_, callingConv, condition) = parseFunctionGroupKey(key)
                sortMethodRows(index, fileIdx, methods)

                w.writeBlankLine()
                if (!condition.isEmpty()) {
                    w.writeLine("@When[${condition}]")
                }
                if (!callingConv.isEmpty()) {
                    w.writeLine(callingConv)
                }
                w.writeBlock("foreign", {=>
                    for (methodRow in methods) {
                        writeForeignFunc(w, index, fileIdx, methodRow)
                    }
                })
                for (methodRow in methods) {
                    writeForeignFuncWrapper(w, index, fileIdx, methodRow, condition)
                }
                if (shouldEmitSysFnPtrAliases()) {
                    for (methodRow in methods) {
                        writeForeignFuncAlias(w, index, fileIdx, methodRow, condition)
                    }
                }
            }
        case _ => ()
    }
}

func functionGroupKey(moduleName: String, callingConv: String, condition: String): String {
    return "${moduleName}\t${encodeFunctionGroupField(callingConv)}\t${encodeFunctionGroupField(condition)}"
}

func parseFunctionGroupKey(key: String): (String, String, String) {
    let parts = splitString(key, b'\t')
    let moduleName = if (!parts.isEmpty()) { parts[0] } else { "" }
    let callingConv = if (parts.size > 1) { decodeFunctionGroupField(parts[1]) } else { "" }
    let condition = if (parts.size > 2) { decodeFunctionGroupField(parts[2]) } else { "" }
    return (moduleName, callingConv, condition)
}

func encodeFunctionGroupField(value: String): String {
    if (value.isEmpty()) {
        return emptyFunctionGroupField
    }
    return value
}

func decodeFunctionGroupField(value: String): String {
    if (value == emptyFunctionGroupField) {
        return ""
    }
    return value
}

// Write a single foreign func declaration
func writeForeignFunc(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    methodRow: Int64
): Unit {
    let name = index.methodDefName(fileIdx, methodRow)
    let foreignName = foreignMethodName(index, fileIdx, methodRow)

    // Win32 free functions never have generic parameters
    let generics = Array<MetadataType>(0, {_ => MetadataType.Void})

    let sig = index.methodDefSignature(fileIdx, methodRow, generics)

    // Check if @FastNative candidate
    if (isFastNativeCandidate(name) || isFastNativeCandidate(foreignName)) {
        w.writeLine("@FastNative")
    }

    let paramNames = methodParamNames(index, fileIdx, methodRow, sig)
    let params = methodParamDecls(paramNames, sig, true)
    let returnType = cppType(sig.returnType)
    let paramStr = joinStrings(params, ", ")

    if (returnType == "Unit") {
        w.writeLine("func ${foreignName}(${paramStr}): Unit")
    } else {
        w.writeLine("func ${foreignName}(${paramStr}): ${returnType}")
    }
}

func writeForeignFuncWrapper(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    methodRow: Int64,
    condition: String
): Unit {
    let name = index.methodDefName(fileIdx, methodRow)
    let foreignName = foreignMethodName(index, fileIdx, methodRow)
    if (name == foreignName) {
        return
    }

    let sig = index.methodDefSignature(fileIdx, methodRow, Array<MetadataType>(0, {_ => MetadataType.Void}))
    if (methodHasVarArgs(sig)) {
        eprintln("warning: skipping wrapper for variadic import `${name}` -> `${foreignName}`")
        return
    }

    let paramNames = methodParamNames(index, fileIdx, methodRow, sig)
    let params = methodParamDecls(paramNames, sig, false)
    let paramStr = joinStrings(params, ", ")
    let callArgs = joinStrings(paramNames, ", ")
    let returnType = cppType(sig.returnType)

    w.writeBlankLine()
    if (!condition.isEmpty()) {
        w.writeLine("@When[${condition}]")
    }
    w.writeLine("unsafe func ${name}(${paramStr}): ${returnType} {")
    if (returnType == "Unit") {
        w.writeLine("    ${foreignName}(${callArgs})")
    } else {
        w.writeLine("    return ${foreignName}(${callArgs})")
    }
    w.writeLine("}")
}

func writeForeignFuncAlias(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    methodRow: Int64,
    condition: String
): Unit {
    let name = index.methodDefName(fileIdx, methodRow)
    let sig = index.methodDefSignature(fileIdx, methodRow, Array<MetadataType>(0, {_ => MetadataType.Void}))
    w.writeBlankLine()
    if (!condition.isEmpty()) {
        w.writeLine("@When[${condition}]")
    }
    w.writeLine("public type ${name}Fn = ${foreignFuncPointerType(sig)}")
}

func foreignFuncPointerType(sig: MethodSignature): String {
    let params = ArrayList<String>()
    for (paramType in sig.paramTypes) {
        params.add(cppType(paramType))
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> ${cppType(sig.returnType)}>"
}

func shouldEmitSysFnPtrAliases(): Bool {
    match (bindgenContext()) {
        case Some(context) => context.config.sysFnPtrs
        case None => false
    }
}

func foreignMethodName(index: TypeIndex, fileIdx: Int64, methodRow: Int64): String {
    let methodName = sanitizeIdentifier(index.methodDefName(fileIdx, methodRow))
    match (index.methodDefImplMap(fileIdx, methodRow)) {
        case Some((_, importName, _)) =>
            if (!importName.isEmpty()) {
                if (isLegalForeignSymbolIdentifier(importName)) {
                    return importName
                }
                eprintln("warning: unsupported import entry point `${importName}` for `${index.methodDefName(fileIdx, methodRow)}`; falling back to method name")
                return methodName
            }
        case None => ()
    }
    return methodName
}

func isLegalForeignSymbolIdentifier(name: String): Bool {
    let arr = name.toArray()
    if (arr.isEmpty()) {
        return false
    }

    let first = arr[0]
    if (!((first >= b'a' && first <= b'z') || (first >= b'A' && first <= b'Z') || first == b'_')) {
        return false
    }

    var i: Int64 = 1
    while (i < Int64(arr.size)) {
        let ch = arr[i]
        if (!((ch >= b'a' && ch <= b'z') ||
              (ch >= b'A' && ch <= b'Z') ||
              (ch >= b'0' && ch <= b'9') ||
              ch == b'_')) {
            return false
        }
        i += 1
    }
    return true
}

func methodHasVarArgs(sig: MethodSignature): Bool {
    return MethodCallAttributes(sig.flags).contains(MethodCallAttributes.VARARG)
}

func methodParamNames(index: TypeIndex, fileIdx: Int64, methodRow: Int64, sig: MethodSignature): ArrayList<String> {
    let (pStart, pEnd) = index.methodDefParams(fileIdx, methodRow)

    // Param rows with seq=0 are return-value annotations and are skipped.
    var seqToName = HashMap<Int64, String>()
    var pr = pStart
    while (pr < pEnd) {
        let seq = Int64(index.paramSequence(fileIdx, pr))
        if (seq > 0) {
            let pn = index.paramName(fileIdx, pr)
            if (!pn.isEmpty()) {
                seqToName[seq] = sanitizeIdentifier(pn)
            }
        }
        pr += 1
    }

    let names = ArrayList<String>()
    var paramIdx: Int64 = 0
    while (paramIdx < Int64(sig.paramTypes.size)) {
        var paramName = "param${paramIdx}"
        let seq = paramIdx + 1
        if (seqToName.contains(seq)) {
            paramName = seqToName[seq]
        }
        names.add(paramName)
        paramIdx += 1
    }
    return names
}

func methodParamDecls(paramNames: ArrayList<String>, sig: MethodSignature, includeVarArgs: Bool): ArrayList<String> {
    let params = ArrayList<String>()
    var paramIdx: Int64 = 0
    while (paramIdx < Int64(sig.paramTypes.size)) {
        params.add("${paramNames[paramIdx]}: ${cppType(sig.paramTypes[paramIdx])}")
        paramIdx += 1
    }
    if (includeVarArgs && methodHasVarArgs(sig)) {
        params.add("...")
    }
    return params
}

// Join strings with separator
public func joinStrings(list: ArrayList<String>, sep: String): String {
    var sb = StringBuilder()
    var first = true
    for (s in list) {
        if (!first) {
            sb.append(sep)
        }
        sb.append(s)
        first = false
    }
    return sb.toString()
}

func sortMethodRows(index: TypeIndex, fileIdx: Int64, rows: ArrayList<Int64>): Unit {
    var i: Int64 = 1
    while (i < Int64(rows.size)) {
        let key = rows[i]
        var j = i - 1
        while (j >= 0 && methodRowLess(index, fileIdx, key, rows[j])) {
            rows[j + 1] = rows[j]
            j -= 1
        }
        rows[j + 1] = key
        i += 1
    }
}

func methodRowLess(index: TypeIndex, fileIdx: Int64, lhs: Int64, rhs: Int64): Bool {
    let lhsName = index.methodDefName(fileIdx, lhs)
    let rhsName = index.methodDefName(fileIdx, rhs)
    if (lhsName != rhsName) {
        return lhsName < rhsName
    }
    return lhs < rhs
}
