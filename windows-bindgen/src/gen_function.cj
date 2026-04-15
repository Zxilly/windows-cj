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
                    let methodArches = index.arches(TABLE_METHOD_DEF, fileIdx, mi)
                    if (isUnsupportedOnlyArchitecture(methodArches)) {
                        mi += 1
                        continue
                    }
                    match (index.methodDefImplMap(fileIdx, mi)) {
                        case Some((pinvoke, _, moduleName)) =>
                            let missing = missingMethodDependencies(index, fileIdx, mi, Array<MetadataType>(0, {_ => MetadataType.Void}))
                            if (!missing.isEmpty()) {
                                warnMissingMethodDependencies(index, fileIdx, mi, missing)
                                mi += 1
                                continue
                            }
                            let cc = callingConventionAnnotation(pinvoke)
                            let methodTags = mergeMethodAvailabilityTags(
                                itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, mi),
                                architectureCfgTags(index.arches(TABLE_METHOD_DEF, fileIdx, mi)))
                            let condition = availabilityCondition(moduleToFeature(moduleName), methodTags)
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

    writeArrayHintAnnotations(w, index, fileIdx, methodRow, sig)
    writePInvokeHints(w, index, fileIdx, methodRow)
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

// Emit doc comments that surface per-param metadata which the sys-layer
// signature alone cannot express: array length hints, Optional/Reserved
// markers. High-level wrappers can use the same sources later.
func writeArrayHintAnnotations(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    methodRow: Int64,
    sig: MethodSignature
): Unit {
    let (pStart, pEnd) = index.methodDefParams(fileIdx, methodRow)
    var paramRow = pStart
    while (paramRow < pEnd) {
        let seq = Int64(index.paramSequence(fileIdx, paramRow))
        if (seq > 0) {
            let paramName = index.paramName(fileIdx, paramRow)
            let paramLabel = if (paramName.isEmpty()) { "arg${seq}" } else { paramName }
            let hints = ArrayList<String>()
            match (index.paramArrayHint(fileIdx, paramRow)) {
                case HintNone => ()
                case hint => hints.add(formatArrayHint(hint))
            }
            if (index.paramIsOptional(fileIdx, paramRow)) {
                hints.add("optional")
            }
            if (index.paramIsReserved(fileIdx, paramRow)) {
                hints.add("reserved")
            }
            if (!hints.isEmpty()) {
                w.writeLine("// param-hint: ${paramLabel} ${joinStrings(hints, " ")}")
            }
        }
        paramRow += 1
    }
}

// Surface PInvoke metadata that the foreign-func declaration alone drops
// (SetLastError requires GetLastError immediately after the call; toolchain
// limitations may hide calling conventions). Comment-only — read by reviewers
// or future high-level wrappers.
func writePInvokeHints(w: CodeWriter, index: TypeIndex, fileIdx: Int64, methodRow: Int64): Unit {
    match (index.methodDefImplMap(fileIdx, methodRow)) {
        case Some((flags, _, _)) =>
            let parts = ArrayList<String>()
            if (flags.contains(PInvokeAttributes.SupportsLastError)) {
                parts.add("SetLastError")
            }
            if (flags.contains(PInvokeAttributes.CallConvCdecl)) {
                parts.add("cc=cdecl")
            } else if (flags.contains(PInvokeAttributes.CallConvFastcall)) {
                parts.add("cc=fastcall")
            }
            if (!parts.isEmpty()) {
                w.writeLine("// pinvoke-hint: ${joinStrings(parts, " ")}")
            }
        case None => ()
    }
}

func mergeMethodAvailabilityTags(first: ArrayList<String>, second: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (v in first) {
        result.add(v)
    }
    for (v in second) {
        var seen = false
        for (existing in result) {
            if (existing == v) {
                seen = true
                break
            }
        }
        if (!seen) {
            result.add(v)
        }
    }
    return result
}

func formatArrayHint(hint: ParamArrayHint): String {
    match (hint) {
        case HintFixed(n) => "fixed=${n}"
        case HintRelativeLen(i) => "len=param[${i}]"
        case HintRelativeBytes(i) => "bytes=param[${i}]"
        case HintNone => ""
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

public func isSysOnlyMode(): Bool {
    match (bindgenContext()) {
        case Some(context) => context.config.generateSys && !context.config.generateHighLevel
        case None => false
    }
}

// Sys mode cannot project WinRT generic parameters; filter generic types out
// of generation and export lists to keep the sys layer compilable.
public func skipForSysGeneric(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    if (!isSysOnlyMode()) {
        return false
    }
    let (gStart, gEnd) = index.typeDefGenericParams(fileIdx, row)
    return gStart < gEnd
}

public func typeDefIsGeneric(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    let (gStart, gEnd) = index.typeDefGenericParams(fileIdx, row)
    return gStart < gEnd
}

public func isTypeNameGeneric(index: TypeIndex, namespace: String, name: String): Bool {
    let candidates = index.get(namespace, name)
    if (candidates.isEmpty()) {
        return false
    }
    let (fi, ri) = candidates[0]
    return typeDefIsGeneric(index, fi, ri)
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
