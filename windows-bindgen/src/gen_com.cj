package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.winmd.*

// Generate COM interface class and vtable struct
public func generateComInterface(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String
): Unit {
    let name = trimTick(index.typeDefName(fileIdx, row))
    let flags = index.typeDefFlags(fileIdx, row)
    let typeTags = typeAvailabilityTags(namespace, name, fileIdx, row, index.arches(TABLE_TYPE_DEF, fileIdx, row))

    // Only generate for interface types
    if (!flags.contains(TypeAttributes.Interface)) {
        return
    }

    let feature = namespaceToFeature(namespace)
    let isWinRT = flags.contains(TypeAttributes.WindowsRuntime) || winmdExtendsIInspectable(index, fileIdx, row)
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    let methodNames = buildNormalizedMethodNames(index, fileIdx, row)

    // Determine base interface
    let baseInterface = winmdFindBaseInterface(index, fileIdx, row)
    let vtblName = "${name}Vtbl"

    // Get generic params for this interface
    let (gpStart, gpEnd) = index.typeDefGenericParams(fileIdx, row)
    var genericParams = ArrayList<String>()
    let genericsArray = winmdBuildGenericArray(index, fileIdx, gpStart, gpEnd)
    if (gpStart < gpEnd) {
        var gpi = gpStart
        while (gpi < gpEnd) {
            let gpName = index.genericParamName(fileIdx, gpi)
            genericParams.add(gpName)
            gpi += 1
        }
    }

    // --- Generate Vtable @C struct ---
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeLine("@C")
    w.writeBlock("public struct ${vtblName}", {=>
        // Base vtable field
        if (name != "IUnknown") {
            match (baseInterface) {
                case Some(baseType) =>
                    let baseName = trimTick(baseType.name)
                    let baseTypePath = projectedTypePath(baseType.namespace, baseName)
                    if (baseName == "IInspectable") {
                        w.writeLine("public var base_: IInspectableVtbl = IInspectableVtbl()")
                    } else {
                        w.writeLine("public var base_: ${baseTypePath}Vtbl = ${baseTypePath}Vtbl()")
                    }
                case None =>
                    if (isWinRT) {
                        w.writeLine("public var base_: IInspectableVtbl = IInspectableVtbl()")
                    } else {
                        w.writeLine("public var base_: IUnknownVtbl = IUnknownVtbl()")
                    }
            }
        }

        // Method slots
        var mi = mStart
        while (mi < mEnd) {
            let methodName = methodNames[mi]
            let sig = index.methodDefSignature(fileIdx, mi, genericsArray)
            let missing = missingMethodDependencies(index, fileIdx, mi, genericsArray)
            let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, mi)
            if (!methodTags.isEmpty()) {
                writeAvailabilityForTags(w, "", methodTags)
            }
            if (!missing.isEmpty()) {
                warnMissingMethodDependencies(index, fileIdx, mi, missing)
                // Degrade to opaque function-pointer slot; avoids unresolvable type references
                w.writeLine("public var ${methodName}: CPointer<Unit> = CPointer<Unit>.null")
            } else {
                let vtblEntry = generateVtblEntry(sig)
                w.writeLine("public var ${methodName}: ${vtblEntry} = ${vtblEntryDefault(sig)}")
            }
            mi += 1
        }

        w.writeLine("public init() {}")
    })

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeLine("func take${name}FromAbi(raw: CPointer<Unit>): ${name} {")
    w.writeLine("    ${name}.fromAbiTake(raw)")
    w.writeLine("}")
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeLine("func view${name}(raw: CPointer<Unit>): ${name} {")
    w.writeLine("    ${name}(raw)")
    w.writeLine("}")

    // --- Generate interface class ---
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    let implInterfaces = if (isWinRT) {
        "ComInterface & Resource & windows_interface.RuntimeType & windows_core.RuntimeType"
    } else {
        "ComInterface & Resource"
    }
    w.writeBlock("public class ${name} <: ${implInterfaces}", {=>
        // IID
        w.writeLine("private let raw_: CPointer<Unit>")
        w.writeLine("private let ownsHandle_: Bool")
        w.writeLine("private var closed_: Bool = false")
        w.writeBlankLine()
        w.writeLine("public init(raw: CPointer<Unit>) {")
        w.writeLine("    this.raw_ = raw")
        w.writeLine("    this.ownsHandle_ = false")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("private init(raw: CPointer<Unit>, takeOwnership!: Bool) {")
        w.writeLine("    this.raw_ = raw")
        w.writeLine("    this.ownsHandle_ = takeOwnership")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func fromAbiTake(raw: CPointer<Unit>): ${name} {")
        w.writeLine("    ${name}(raw, takeOwnership: true)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func viewOf(raw: CPointer<Unit>): ${name} {")
        w.writeLine("    ${name}(raw)")
        w.writeLine("}")
        w.writeBlankLine()

        // static iid() - try to extract from GuidAttribute
        writeIidMethod(w, index, fileIdx, row, name)

        if (isWinRT) {
            w.writeBlankLine()
            w.writeLine("public static func abiType(): String {")
            w.writeLine("    \"CPointer<Unit>\"")
            w.writeLine("}")
            w.writeBlankLine()
            w.writeLine("public static func signature(): String {")
            w.writeLine("    \"${interfaceRuntimeSignature(index, fileIdx, row, ArrayList<MetadataType>())}\"")
            w.writeLine("}")
            w.writeBlankLine()
            w.writeLine("public static func runtimeType(): RuntimeTypeContract {")
            w.writeLine("    RuntimeTypeContract(\"${namespace}.${name}\", ${name}.signature(), ${name}.iid())")
            w.writeLine("}")
        }

        w.writeBlankLine()
        match (baseInterface) {
            case Some(baseType) =>
                let baseTypePath = projectedTypePath(baseType.namespace, trimTick(baseType.name))
                w.writeLine("public static func descriptor(): InterfaceDescriptor<${name}> {")
                w.writeLine("    return InterfaceDescriptor<${name}>(\"${name}\", ${name}.iid(), ${baseTypePath}.iid(), take${name}FromAbi, view${name})")
                w.writeLine("}")
            case None =>
                w.writeLine("public static func descriptor(): InterfaceDescriptor<${name}> {")
                w.writeLine("    return InterfaceDescriptor<${name}>(\"${name}\", ${name}.iid(), take${name}FromAbi, view${name})")
                w.writeLine("}")
        }
        w.writeBlankLine()
        w.writeLine("public func asRaw(): CPointer<Unit> {")
        w.writeLine("    if (closed_) {")
        w.writeLine("        return CPointer<Unit>()")
        w.writeLine("    }")
        w.writeLine("    raw_")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func isClosed(): Bool { closed_ }")

        // Vtable accessor
        w.writeBlankLine()
        w.writeLine("unsafe func vtbl(): ${vtblName} {")
        w.writeLine("    let liveRaw = asRaw()")
        w.writeLine("    if (liveRaw.isNull()) {")
        w.writeLine("        return ${vtblName}()")
        w.writeLine("    }")
        w.writeLine("    let vtblPtrPtr = CPointer<CPointer<${vtblName}>>(liveRaw)")
        w.writeLine("    let vtblPtr = vtblPtrPtr.read()")
        w.writeLine("    return vtblPtr.read()")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func addRef(): UInt32 {")
        w.writeLine("    let liveRaw = asRaw()")
        w.writeLine("    if (liveRaw.isNull()) {")
        w.writeLine("        return 0u32")
        w.writeLine("    }")
        w.writeLine("    unsafe {")
        w.writeLine("        let baseVtblPtr = CPointer<CPointer<IUnknownVtbl>>(liveRaw).read()")
        w.writeLine("        let baseVtbl = baseVtblPtr.read()")
        w.writeLine("        return baseVtbl.AddRef(liveRaw)")
        w.writeLine("    }")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func release(): UInt32 {")
        w.writeLine("    let liveRaw = asRaw()")
        w.writeLine("    if (liveRaw.isNull()) {")
        w.writeLine("        return 0u32")
        w.writeLine("    }")
        w.writeLine("    unsafe {")
        w.writeLine("        let baseVtblPtr = CPointer<CPointer<IUnknownVtbl>>(liveRaw).read()")
        w.writeLine("        let baseVtbl = baseVtblPtr.read()")
        w.writeLine("        let count = baseVtbl.Release(liveRaw)")
        w.writeLine("        closed_ = true")
        w.writeLine("        return count")
        w.writeLine("    }")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public unsafe func query<T>(descriptor: InterfaceDescriptor<T>): Option<T> {")
        w.writeLine("    queryInterfaceAs(asRaw(), descriptor)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func close(): Unit {")
        w.writeLine("    let liveRaw = asRaw()")
        w.writeLine("    if (!liveRaw.isNull() && ownsHandle_) {")
        w.writeLine("        unsafe {")
        w.writeLine("            let baseVtblPtr = CPointer<CPointer<IUnknownVtbl>>(liveRaw).read()")
        w.writeLine("            let baseVtbl = baseVtblPtr.read()")
        w.writeLine("            baseVtbl.Release(liveRaw)")
        w.writeLine("        }")
        w.writeLine("    }")
        w.writeLine("    closed_ = true")
        w.writeLine("}")

        // Wrapper methods
        var mi2 = mStart
        while (mi2 < mEnd) {
            let methodName = methodNames[mi2]
            let sig = index.methodDefSignature(fileIdx, mi2, genericsArray)
            let (pStart, pEnd) = index.methodDefParams(fileIdx, mi2)
            let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, mi2)

            w.writeBlankLine()
            if (!methodTags.isEmpty()) {
                writeAvailabilityForTags(w, "", methodTags)
            }
            writeWrapperMethod(w, index, fileIdx, sig, methodName, pStart, pEnd)
            mi2 += 1
        }
    })
}

func buildGenericArray(
    index: TypeIndex,
    fileIdx: Int64,
    gpStart: Int64,
    gpEnd: Int64
): Array<MetadataType> {
    if (gpStart >= gpEnd) {
        return Array<MetadataType>(0, {_ => MetadataType.Void})
    }

    var genList = ArrayList<MetadataType>()
    var gpi = gpStart
    while (gpi < gpEnd) {
        let gpName = index.genericParamName(fileIdx, gpi)
        genList.add(MetadataType.Generic(gpName, UInt16(gpi - gpStart)))
        gpi += 1
    }

    var result = Array<MetadataType>(genList.size, {_ => MetadataType.Void})
    var i: Int64 = 0
    while (i < Int64(genList.size)) {
        result[i] = genList[i]
        i += 1
    }
    return result
}

// Find the base interface name (first interface in InterfaceImpl)
// Returns (baseName, isInspectable) where isInspectable indicates WinRT interface
func findBaseInterface(index: TypeIndex, fileIdx: Int64, row: Int64): Option<String> {
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    if (iiStart < iiEnd) {
        let ifaceValue = file.getUInt(iiStart, TABLE_INTERFACE_IMPL, 1)
        let (ifaceTable, ifaceRow) = decodeCodedIndex(ifaceValue, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)

        var ifaceName = ""
        if (ifaceTable == TABLE_TYPE_DEF) {
            ifaceName = file.getString(ifaceRow, TABLE_TYPE_DEF, 1)
        } else if (ifaceTable == TABLE_TYPE_REF) {
            ifaceName = file.getString(ifaceRow, TABLE_TYPE_REF, 1)
        }

        if (!ifaceName.isEmpty() && ifaceName != "IUnknown") {
            return Some(trimTick(ifaceName))
        }
    }
    return None
}

// Check if a TypeDef interface extends IInspectable (directly or transitively)
func extendsIInspectable(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = iiStart
    while (ii < iiEnd) {
        let ifaceValue = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
        let (ifaceTable, ifaceRow) = decodeCodedIndex(ifaceValue, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)
        var ifaceName = ""
        if (ifaceTable == TABLE_TYPE_DEF) {
            ifaceName = file.getString(ifaceRow, TABLE_TYPE_DEF, 1)
        } else if (ifaceTable == TABLE_TYPE_REF) {
            ifaceName = file.getString(ifaceRow, TABLE_TYPE_REF, 1)
        }
        if (ifaceName == "IInspectable") {
            return true
        }
        ii += 1
    }
    return false
}

// Generate a CFunc type signature for a vtable entry
func generateVtblEntry(sig: MethodSignature): String {
    var params = ArrayList<String>()
    // First param is always the this pointer
    params.add("CPointer<Unit>")

    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        params.add(cppType(sig.paramTypes[pi]))
        pi += 1
    }

    let returnType = cppType(sig.returnType)
    let paramStr = joinStrings(params, ", ")
    return "CFunc<(${paramStr}) -> ${returnType}>"
}

// Generate default value for a vtable CFunc entry
func vtblEntryDefault(sig: MethodSignature): String {
    var paramNames = ArrayList<String>()
    paramNames.add("_")
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        paramNames.add("_")
        pi += 1
    }
    let paramStr = joinStrings(paramNames, ", ")
    let returnType = cppType(sig.returnType)
    // COM methods almost always return HRESULT (Int32); E_NOTIMPL = 0x80004001
    if (returnType == "Int32") {
        return "{ ${paramStr} => -2147467263i32 }"  // E_NOTIMPL
    } else if (returnType == "UInt32") {
        return "{ ${paramStr} => 0u32 }"
    } else if (returnType == "Unit") {
        return "{ ${paramStr} => () }"
    } else if (returnType == "Int64") {
        return "{ ${paramStr} => 0i64 }"
    } else if (returnType == "UInt64") {
        return "{ ${paramStr} => 0u64 }"
    } else if (returnType.startsWith("CPointer")) {
        return "{ ${paramStr} => ${returnType}() }"
    } else {
        // For any other return type fall back to Unit — vtable entries are called through unsafe code
        return "{ ${paramStr} => () }"
    }
}

// Write the static iid() method by extracting GuidAttribute
func writeIidMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    name: String
): Unit {
    let guid = guidAttributeLiteral(index, fileIdx, row)
    match (guid) {
        case Some(g) =>
            w.writeLine("public static func iid(): GUID {")
            w.writeLine("    return GUID(${g})")
            w.writeLine("}")
        case None =>
            let displayName = if (currentNamespace().isEmpty()) {
                name
            } else {
                qualifiedTypeName(currentNamespace(), name)
            }
            match (bindgenContext()) {
                case Some(context) => context.warnings.add("missing GuidAttribute for `${displayName}`")
                case None => ()
            }
            w.writeLine("public static func iid(): GUID {")
            w.writeLine("    throw Exception(\"missing GuidAttribute for ${displayName}\")")
            w.writeLine("}")
    }
}

// Write a wrapper method that calls through the vtable
func writeWrapperMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    sig: MethodSignature,
    methodName: String,
    pStart: Int64,
    pEnd: Int64
): Unit {
    // Build sequence-number → name map from the Param table
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

    // Build param list for the wrapper
    var params = ArrayList<String>()
    var argNames = ArrayList<String>()
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        var paramName = "param${pi}"
        let seq = pi + 1
        if (seqToName.contains(seq)) {
            paramName = seqToName[seq]
        }
        let paramType = cppType(sig.paramTypes[pi])
        params.add("${paramName}: ${paramType}")
        argNames.add(paramName)
        pi += 1
    }

    let returnType = cppType(sig.returnType)
    let paramStr = joinStrings(params, ", ")
    let argStr = joinStrings(argNames, ", ")

    if (returnType == "Unit") {
        w.writeLine("public unsafe func ${methodName}(${paramStr}): Unit {")
        w.writeLine("    let v = vtbl()")
        w.writeLine("    let liveRaw = asRaw()")
        if (argStr.isEmpty()) {
            w.writeLine("    v.${methodName}(liveRaw)")
        } else {
            w.writeLine("    v.${methodName}(liveRaw, ${argStr})")
        }
    } else {
        w.writeLine("public unsafe func ${methodName}(${paramStr}): ${returnType} {")
        w.writeLine("    let v = vtbl()")
        w.writeLine("    let liveRaw = asRaw()")
        if (argStr.isEmpty()) {
            w.writeLine("    return v.${methodName}(liveRaw)")
        } else {
            w.writeLine("    return v.${methodName}(liveRaw, ${argStr})")
        }
    }
    w.writeLine("}")
}
