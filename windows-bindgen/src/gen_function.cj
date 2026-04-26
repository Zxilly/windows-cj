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
            let runtimeGroups = HashMap<String, ArrayList<Int64>>()
            let runtimeGroupKeys = ArrayList<String>()
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
                        case Some((pinvoke, importName, moduleName)) =>
                            let missing = missingMethodDependencies(index, fileIdx, mi, Array<MetadataType>(0, {_ => MetadataType.Void}))
                            if (!missing.isEmpty()) {
                                warnMissingMethodDependencies(index, fileIdx, mi, missing)
                                mi += 1
                                continue
                            }
                            let cc = callingConventionAnnotation(pinvoke)
                            let methodTags = functionAvailabilityTags(index, fileIdx, mi)
                            let condition = availabilityCondition(moduleToFeature(moduleName), methodTags)
                            let key = functionGroupKey(moduleName, cc, condition)
                            if (functionRequiresRuntimeEntryPointResolver(index, fileIdx, mi)) {
                                if (!runtimeGroups.contains(key)) {
                                    runtimeGroups[key] = ArrayList<Int64>()
                                    runtimeGroupKeys.add(key)
                                }
                                runtimeGroups[key].add(mi)
                            } else {
                                if (!groups.contains(key)) {
                                    groups[key] = ArrayList<Int64>()
                                    groupKeys.add(key)
                                }
                                groups[key].add(mi)
                            }
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
                        writeForeignFunc(w, index, fileIdx, methodRow, namespace)
                    }
                })
                for (methodRow in methods) {
                    writeForeignFuncWrapper(w, index, fileIdx, methodRow, condition, namespace)
                }
                if (shouldEmitSysFnPtrAliases()) {
                    for (methodRow in methods) {
                        writeForeignFuncAlias(w, index, fileIdx, methodRow, condition, namespace)
                    }
                }
            }
            if (!runtimeGroupKeys.isEmpty()) {
                writeRuntimeEntryPointImports(w)
            }
            sortStrings(runtimeGroupKeys)
            for (key in runtimeGroupKeys) {
                let methods = runtimeGroups[key]
                let (moduleName, _, condition) = parseFunctionGroupKey(key)
                sortMethodRows(index, fileIdx, methods)
                for (methodRow in methods) {
                    writeRuntimeEntryPointFunc(w, index, fileIdx, methodRow, moduleName, condition, namespace)
                }
                if (shouldEmitSysFnPtrAliases()) {
                    for (methodRow in methods) {
                        writeForeignFuncAlias(w, index, fileIdx, methodRow, condition, namespace)
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

func functionAvailabilityTags(index: TypeIndex, fileIdx: Int64, methodRow: Int64): ArrayList<String> {
    let tags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, methodRow)
    if (!tags.isEmpty()) {
        return tags
    }
    return architectureCfgTags(index.arches(TABLE_METHOD_DEF, fileIdx, methodRow))
}

// Write a single foreign func declaration
func writeForeignFunc(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    methodRow: Int64,
    namespace: String
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
    let params = methodParamDecls(paramNames, sig, true, namespace)
    let returnType = functionAbiType(index, sig.returnType, namespace)
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
    condition: String,
    namespace: String
): Unit {
    if (functionRequiresRuntimeEntryPointResolver(index, fileIdx, methodRow)) {
        return
    }
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
    let params = methodParamDecls(paramNames, sig, false, namespace)
    let paramStr = joinStrings(params, ", ")
    let callArgs = joinStrings(paramNames, ", ")
    let returnType = functionAbiType(index, sig.returnType, namespace)

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
    condition: String,
    namespace: String
): Unit {
    let name = index.methodDefName(fileIdx, methodRow)
    let sig = index.methodDefSignature(fileIdx, methodRow, Array<MetadataType>(0, {_ => MetadataType.Void}))
    w.writeBlankLine()
    if (!condition.isEmpty()) {
        w.writeLine("@When[${condition}]")
    }
    w.writeLine("public type ${name}Fn = ${foreignFuncPointerType(sig, namespace)}")
}

func foreignFuncPointerType(sig: MethodSignature, namespace: String): String {
    let params = ArrayList<String>()
    for (paramType in sig.paramTypes) {
        params.add(functionAbiTypeForPointerInNamespace(namespace, paramType))
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> ${functionAbiTypeForPointerInNamespace(namespace, sig.returnType)}>"
}

func shouldEmitSysFnPtrAliases(): Bool {
    match (bindgenContext()) {
        case Some(context) => context.config.sysFnPtrs
        case None => false
    }
}

func writeRuntimeEntryPointImports(w: CodeWriter): Unit {
    w.writeBlankLine()
    w.writeBlock("foreign", {=>
        w.writeLine("func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CPointer<UInt8>): CPointer<Unit>")
        w.writeLine("func LoadLibraryA(lpLibFileName: CPointer<UInt8>): CPointer<Unit>")
    })
}

func writeRuntimeEntryPointFunc(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    methodRow: Int64,
    moduleName: String,
    condition: String,
    namespace: String
): Unit {
    let name = sanitizeIdentifier(index.methodDefName(fileIdx, methodRow))
    let sig = index.methodDefSignature(fileIdx, methodRow, Array<MetadataType>(0, {_ => MetadataType.Void}))
    if (methodHasVarArgs(sig)) {
        eprintln("warning: skipping runtime entry point wrapper for variadic import `${name}`")
        return
    }

    let importName = runtimeImportEntryPointName(index, fileIdx, methodRow)
    let isOrdinal = isOrdinalImportEntryPoint(importName)
    let cacheName = "__windowsBindgen_${name}ProcCache"
    let resolverName = "__windowsBindgen_${name}Proc"
    let params = methodParamDecls(methodParamNames(index, fileIdx, methodRow, sig), sig, false, namespace)
    let paramNames = methodParamNames(index, fileIdx, methodRow, sig)
    let paramStr = joinStrings(params, ", ")
    let callArgs = joinStrings(paramNames, ", ")
    let returnType = functionAbiType(index, sig.returnType, namespace)
    let functionPointerType = foreignFuncPointerType(sig, namespace)
    let moduleBytes = byteArrayLiteral(moduleName)

    w.writeBlankLine()
    if (!condition.isEmpty()) {
        w.writeLine("@When[${condition}]")
    }
    w.writeLine("var ${cacheName}: CPointer<Unit> = CPointer<Unit>()")
    w.writeBlankLine()
    if (!condition.isEmpty()) {
        w.writeLine("@When[${condition}]")
    }
    w.writeLine("func ${resolverName}(): CPointer<Unit> {")
    w.writeLine("    if (${cacheName}.isNotNull()) {")
    w.writeLine("        return ${cacheName}")
    w.writeLine("    }")
    w.writeLine("    let moduleName = ${moduleBytes}")
    if (isOrdinal) {
        let ordinal = ordinalImportValue(importName)
        w.writeLine("    let ordinal = unsafe { CPointer<UInt8>() + ${ordinal} }")
        w.writeLine("    unsafe {")
        w.writeLine("        let moduleHandle = acquireArrayRawData(moduleName)")
        w.writeLine("        try {")
        w.writeLine("            let module = LoadLibraryA(moduleHandle.pointer)")
        w.writeLine("            if (module.isNull()) {")
        w.writeLine("                throw Exception(\"failed to load ${moduleName}\")")
        w.writeLine("            }")
        w.writeLine("            let proc = GetProcAddress(module, ordinal)")
        w.writeLine("            if (proc.isNull()) {")
        w.writeLine("                throw Exception(\"failed to resolve ${name} entry point ${importName}\")")
        w.writeLine("            }")
        w.writeLine("            ${cacheName} = proc")
        w.writeLine("            return proc")
        w.writeLine("        } finally {")
        w.writeLine("            releaseArrayRawData(moduleHandle)")
        w.writeLine("        }")
        w.writeLine("    }")
    } else {
        // Non-identifier symbol name (decorated, mangled, etc.) -- cannot appear in a `foreign`
        // block where the function name IS the linker symbol. Resolve at runtime with
        // GetProcAddress, passing the symbol bytes as the lookup name.
        let symbolBytes = byteArrayLiteral(importName)
        w.writeLine("    let procName = ${symbolBytes}")
        w.writeLine("    unsafe {")
        w.writeLine("        let moduleHandle = acquireArrayRawData(moduleName)")
        w.writeLine("        try {")
        w.writeLine("            let module = LoadLibraryA(moduleHandle.pointer)")
        w.writeLine("            if (module.isNull()) {")
        w.writeLine("                throw Exception(\"failed to load ${moduleName}\")")
        w.writeLine("            }")
        w.writeLine("            let nameHandle = acquireArrayRawData(procName)")
        w.writeLine("            try {")
        w.writeLine("                let proc = GetProcAddress(module, nameHandle.pointer)")
        w.writeLine("                if (proc.isNull()) {")
        w.writeLine("                    throw Exception(\"failed to resolve ${name} entry point ${importName}\")")
        w.writeLine("                }")
        w.writeLine("                ${cacheName} = proc")
        w.writeLine("                return proc")
        w.writeLine("            } finally {")
        w.writeLine("                releaseArrayRawData(nameHandle)")
        w.writeLine("            }")
        w.writeLine("        } finally {")
        w.writeLine("            releaseArrayRawData(moduleHandle)")
        w.writeLine("        }")
        w.writeLine("    }")
    }
    w.writeLine("}")

    w.writeBlankLine()
    if (!condition.isEmpty()) {
        w.writeLine("@When[${condition}]")
    }
    w.writeLine("unsafe func ${name}(${paramStr}): ${returnType} {")
    w.writeLine("    let call = ${functionPointerType}(${resolverName}())")
    if (returnType == "Unit") {
        w.writeLine("    unsafe { call(${callArgs}) }")
    } else {
        w.writeLine("    return unsafe { call(${callArgs}) }")
    }
    w.writeLine("}")
}

public func functionRequiresRuntimeEntryPointResolver(index: TypeIndex, fileIdx: Int64, methodRow: Int64): Bool {
    match (index.methodDefImplMap(fileIdx, methodRow)) {
        case Some((_, importName, _)) =>
            if (importName.isEmpty()) {
                return false
            }
            if (isOrdinalImportEntryPoint(importName)) {
                return true
            }
            // Non-identifier symbols (decorated names, mangled names, etc.) cannot appear directly
            // inside a Cangjie `foreign` block -- the function name there IS the linker symbol.
            // Route them through the runtime resolver so the imported DLL is loaded and the symbol
            // is fetched via GetProcAddress at first call.
            return !isLegalForeignSymbolIdentifier(importName)
        case None => return false
    }
}

public func isSysOnlyMode(): Bool {
    match (bindgenContext()) {
        case Some(context) => context.config.generateSys && !context.config.generateHighLevel
        case None => false
    }
}

public func isHighLevelOnlyMode(): Bool {
    match (bindgenContext()) {
        case Some(context) => context.config.generateHighLevel && !context.config.generateSys
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
                if (isOrdinalImportEntryPoint(importName)) {
                    // Routed through runtime entry-point resolver; the foreign symbol used here
                    // is irrelevant because the resolver looks up the ordinal explicitly.
                    return methodName
                }
                if (isLegalForeignSymbolIdentifier(importName)) {
                    return importName
                }
                // Unhandled symbol shape (e.g. decorated `_func@8`, C++ mangled, or any name that
                // is not a legal Cangjie/foreign identifier). functionRequiresRuntimeEntryPointResolver
                // routes these through the runtime resolver, so this fallback should not be reached
                // for emitted normal `foreign` declarations. If it ever is, the linker would resolve
                // against `methodName` which would fail to bind to the expected DLL export -- emit
                // a precise warning so the regen log records the metadata shape.
                eprintln("warning: unsupported import entry point `${importName}` for `${index.methodDefName(fileIdx, methodRow)}` reached `foreign` emission path; expected runtime-resolver routing (cangjie-paradigm: foreign block function name IS the linker symbol)")
                return methodName
            }
        case None => ()
    }
    return methodName
}

func runtimeImportEntryPointName(index: TypeIndex, fileIdx: Int64, methodRow: Int64): String {
    match (index.methodDefImplMap(fileIdx, methodRow)) {
        case Some((_, importName, _)) => return importName
        case None => return ""
    }
}

func isOrdinalImportEntryPoint(name: String): Bool {
    let arr = name.toArray()
    if (arr.size < 2 || arr[0] != b'#') {
        return false
    }

    var i: Int64 = 1
    while (i < Int64(arr.size)) {
        let ch = arr[i]
        if (ch < b'0' || ch > b'9') {
            return false
        }
        i += 1
    }
    return true
}

func ordinalImportValue(name: String): Int64 {
    let arr = name.toArray()
    var value: Int64 = 0
    var i: Int64 = 1
    while (i < Int64(arr.size)) {
        value = value * 10 + Int64(arr[i] - b'0')
        i += 1
    }
    return value
}

func byteArrayLiteral(value: String): String {
    let bytes = value.toArray()
    let parts = ArrayList<String>()
    for (b in bytes) {
        parts.add("0x${hexByte(b)}u8")
    }
    parts.add("0u8")
    return "[${joinStrings(parts, ", ")}]"
}

func hexByte(value: Byte): String {
    let hex = "0123456789ABCDEF".toArray()
    let numeric = UInt64(value)
    let high = Int64((numeric >> 4) & 0xFu64)
    let low = Int64(numeric & 0xFu64)
    return String.fromUtf8([hex[high], hex[low]])
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

func methodParamDecls(paramNames: ArrayList<String>, sig: MethodSignature, includeVarArgs: Bool, namespace: String): ArrayList<String> {
    let params = ArrayList<String>()
    var paramIdx: Int64 = 0
    while (paramIdx < Int64(sig.paramTypes.size)) {
        params.add("${paramNames[paramIdx]}: ${functionAbiTypeForPointerInNamespace(namespace, sig.paramTypes[paramIdx])}")
        paramIdx += 1
    }
    if (includeVarArgs && methodHasVarArgs(sig)) {
        params.add("...")
    }
    return params
}

func functionAbiType(index: TypeIndex, ty: MetadataType, namespace: String): String {
    let _ = index
    return functionAbiTypeForPointerInNamespace(namespace, ty)
}

func functionAbiTypeForPointer(ty: MetadataType): String {
    return functionAbiTypeForPointerInNamespace("", ty)
}

func functionAbiTypeForPointerInNamespace(namespace: String, ty: MetadataType): String {
    if (isHighLevelOnlyMode()) {
        match (bindgenContext()) {
            case Some(context) => return highLevelFunctionAbiType(context.index, namespace, ty)
            case None => ()
        }
    }
    return cppType(ty)
}

func highLevelFunctionAbiType(index: TypeIndex, namespace: String, ty: MetadataType): String {
    let qualified = qualifyMetadataTypeWithNamespace(namespace, ty)
    match (qualified) {
        case MetadataType.ClassName(typeName) =>
            match (functionProjectedAbiTypeName(index, typeName)) {
                case Some(abiType) => return abiType
                case None => return highLevelAbiType(index, qualified)
            }
        case MetadataType.ValueName(typeName) =>
            match (functionProjectedAbiTypeName(index, typeName)) {
                case Some(abiType) => return abiType
                case None => return highLevelAbiType(index, qualified)
            }
        case MetadataType.Union(typeName) =>
            match (functionProjectedAbiTypeName(index, typeName)) {
                case Some(abiType) => return abiType
                case None => return highLevelAbiType(index, qualified)
            }
        case MetadataType.MdArray(inner) =>
            return "CPointer<${highLevelFunctionAbiType(index, namespace, inner)}>"
        case MetadataType.RefMut(inner) =>
            return "CPointer<${highLevelFunctionAbiType(index, namespace, inner)}>"
        case MetadataType.RefConst(inner) =>
            return "CPointer<${highLevelFunctionAbiType(index, namespace, inner)}>"
        case MetadataType.PtrMut(inner, depth) =>
            return wrapHighLevelFunctionAbiPointer(index, namespace, inner, depth)
        case MetadataType.PtrConst(inner, depth) =>
            return wrapHighLevelFunctionAbiPointer(index, namespace, inner, depth)
        case MetadataType.ArrayFixed(inner, size) =>
            return "VArray<${highLevelFunctionAbiType(index, namespace, inner)}, \$${size}>"
        case MetadataType.Packed(inner, _) =>
            return highLevelFunctionAbiType(index, namespace, inner)
        case _ => return highLevelAbiType(index, qualified)
    }
}

func wrapHighLevelFunctionAbiPointer(
    index: TypeIndex,
    namespace: String,
    inner: MetadataType,
    depth: Int64
): String {
    var result = highLevelFunctionAbiType(index, namespace, inner)
    var d = depth
    while (d > 0) {
        result = "CPointer<${result}>"
        d -= 1
    }
    return result
}

func functionProjectedAbiTypeName(index: TypeIndex, typeName: TypeName): Option<String> {
    if (!typeName.generics.isEmpty()) {
        return None
    }

    let namespace = typeName.namespace
    let name = trimTick(typeName.name)
    match (bindgenContext()) {
        case Some(context) =>
            if (!context.config.isForcedLocalType(namespace, name)) {
                match (context.references.importPathForType(namespace, name)) {
                    case Some(importPath) =>
                        if (importPath == "windows_core" || importPath == "windows_result") {
                            return None
                        }
                    case None => ()
                }
            }
        case None => ()
    }

    let candidates = index.get(namespace, name)
    for ((fileIdx, row) in candidates) {
        if (isUnsupportedOnlyArchitecture(index.arches(TABLE_TYPE_DEF, fileIdx, row))) {
            continue
        }
        match (index.typeDefCategory(fileIdx, row)) {
            case Enum => return Some(appendSourceIdentifierSuffix(typeNameToProjectionCj(index, typeName), "Abi"))
            case Struct =>
                if (functionTypeDefUsesProjectedAbi(index, fileIdx, row)) {
                    return Some(appendSourceIdentifierSuffix(typeNameToProjectionCj(index, typeName), "Abi"))
                }
            case _ => ()
        }
    }
    return None
}

func functionTypeDefUsesProjectedAbi(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    match (index.typeDefCategory(fileIdx, row)) {
        case Enum => return true
        case Struct =>
            let flags = index.typeDefFlags(fileIdx, row)
            let layout = index.typeDefClassLayout(fileIdx, row)
            let isUnion = flags.contains(TypeAttributes.ExplicitLayout)
            let isPacked = match (layout) {
                case Some((packing, _)) => packing != 0u16 && packing != 8u16
                case None => false
            }
            return !isHandleType(index, fileIdx, row) && !isUnion && !isPacked
        case _ => return false
    }
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
