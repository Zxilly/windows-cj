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

    if (skipForSysGeneric(index, fileIdx, row)) {
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

    // Evaluate base interface substitution once (used by vtbl struct and descriptor).
    let baseSubstitution = resolveBaseVtblSubstitution(index, baseInterface, isWinRT)

    // Record the support-package symbols this interface emits so the prelude
    // can produce a precise import list instead of a wildcard.
    useSupportSymbol("windows_interface", "ComInterface")
    useSupportSymbol("windows_interface", "GUID")
    useSupportSymbol("windows_interface", "InterfaceDescriptor")
    useSupportSymbol("windows_interface", "IUnknownVtbl")
    useSupportSymbol("windows_interface", "queryInterfaceAs")
    if (isWinRT) {
        useSupportSymbol("windows_interface", "IInspectableVtbl")
    }
    if (baseSubstitution.vtblType == "IInspectableVtbl") {
        useSupportSymbol("windows_interface", "IInspectableVtbl")
    } else if (baseSubstitution.vtblType == "IUnknownVtbl") {
        useSupportSymbol("windows_interface", "IUnknownVtbl")
    }
    if (isWinRT && !isSysOnlyMode()) {
        useSupportSymbol("windows_interface", "RuntimeType")
        useSupportSymbol("windows_core", "RuntimeType")
        useSupportSymbol("windows_interface", "RuntimeTypeContract")
    }

    // --- Generate Vtable @C struct ---
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeLine("@C")
    w.writeBlock("public struct ${vtblName}", {=>
        if (name != "IUnknown") {
            w.writeLine("public var base_: ${baseSubstitution.vtblType} = ${baseSubstitution.vtblType}()")
        }

        var mi = mStart
        while (mi < mEnd) {
            let rawMethodName = methodNames[mi]
            let sig = index.methodDefSignature(fileIdx, mi, genericsArray)
            let missing = missingMethodDependencies(index, fileIdx, mi, genericsArray)
            let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, mi)
            if (!methodTags.isEmpty()) {
                writeAvailabilityForTags(w, "", methodTags)
            }
            // Rename when the vtable slot identifier would shadow any type
            // referenced in its signature (return type OR param types).
            let returnType = cppType(sig.returnType)
            let methodName = disambiguateMethodName(rawMethodName, methodSignatureText(sig, returnType))
            if (!missing.isEmpty()) {
                warnMissingMethodDependencies(index, fileIdx, mi, missing)
                // Degrade to opaque function-pointer slot; avoids unresolvable type references
                w.writeLine("public var ${methodName}: CPointer<Unit> = CPointer<Unit>.null")
            } else {
                w.writeLine("public var ${methodName}: ${vtblSlotType(sig, returnType)} = ${vtblSlotDefault(sig)}")
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
    let implInterfaces = if (isWinRT && !isSysOnlyMode()) {
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

        if (isWinRT && !isSysOnlyMode()) {
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
        match (baseSubstitution.parentIidExpr) {
            case Some(parentIid) =>
                w.writeLine("public static func descriptor(): InterfaceDescriptor<${name}> {")
                w.writeLine("    return InterfaceDescriptor<${name}>(\"${name}\", ${name}.iid(), ${parentIid}, take${name}FromAbi, view${name})")
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

struct BaseVtblSubstitution {
    BaseVtblSubstitution(
        public let vtblType: String,
        public let parentIidExpr: Option<String>
    ) {}
}

// In sys mode the generic parent interface / vtable is filtered out, so fall back
// to IInspectableVtbl and omit the parent IID from the descriptor.
func resolveBaseVtblSubstitution(
    index: TypeIndex,
    baseInterface: Option<TypeName>,
    isWinRT: Bool
): BaseVtblSubstitution {
    match (baseInterface) {
        case Some(baseType) =>
            let baseLeaf = trimTick(baseType.name)
            if (baseLeaf == "IInspectable" ||
                (isSysOnlyMode() && isTypeNameGeneric(index, baseType.namespace, baseLeaf))) {
                return BaseVtblSubstitution("IInspectableVtbl", None<String>)
            }
            let baseTypePath = projectedTypePath(baseType.namespace, baseLeaf)
            return BaseVtblSubstitution("${baseTypePath}Vtbl", Some<String>("${baseTypePath}.iid()"))
        case None =>
            if (isWinRT) {
                return BaseVtblSubstitution("IInspectableVtbl", None<String>)
            }
            return BaseVtblSubstitution("IUnknownVtbl", None<String>)
    }
}

func vtblSlotType(sig: MethodSignature, returnType: String): String {
    var params = ArrayList<String>()
    params.add("CPointer<Unit>")
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        params.add(cppType(sig.paramTypes[pi]))
        pi += 1
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> ${returnType}>"
}

func vtblSlotDefault(sig: MethodSignature): String {
    var paramNames = ArrayList<String>()
    paramNames.add("_")
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        paramNames.add("_")
        pi += 1
    }
    return "{ ${joinStrings(paramNames, ", ")} => ${cppDefaultValue(sig.returnType)} }"
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

    let wrapperName = disambiguateMethodName(methodName, methodSignatureText(sig, returnType))

    if (returnType == "Unit") {
        w.writeLine("public unsafe func ${wrapperName}(${paramStr}): Unit {")
        w.writeLine("    let __vt = vtbl()")
        w.writeLine("    let __liveRaw = asRaw()")
        if (argStr.isEmpty()) {
            w.writeLine("    __vt.${wrapperName}(__liveRaw)")
        } else {
            w.writeLine("    __vt.${wrapperName}(__liveRaw, ${argStr})")
        }
    } else {
        w.writeLine("public unsafe func ${wrapperName}(${paramStr}): ${returnType} {")
        w.writeLine("    let __vt = vtbl()")
        w.writeLine("    let __liveRaw = asRaw()")
        if (argStr.isEmpty()) {
            w.writeLine("    return __vt.${wrapperName}(__liveRaw)")
        } else {
            w.writeLine("    return __vt.${wrapperName}(__liveRaw, ${argStr})")
        }
    }
    w.writeLine("}")
}

// Concatenate every type referenced in a MethodSignature into a single string
// so identifier-shadowing checks can scan the whole surface in one pass.
func methodSignatureText(sig: MethodSignature, returnType: String): String {
    let parts = ArrayList<String>()
    parts.add(returnType)
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        parts.add(cppType(sig.paramTypes[pi]))
        pi += 1
    }
    return joinStrings(parts, " ")
}

// Names of types referenced from every emitted COM class (iid, descriptor,
// runtimeType bodies). A method whose identifier equals one of these would
// shadow the imported type even when its own signature doesn't mention it.
let alwaysShadowingNames_: HashSet<String> = HashSet<String>([
    "GUID",
    "InterfaceDescriptor",
    "RuntimeTypeContract",
    "ComInterface",
    "Resource",
    "InterfaceWrapperBase",
    "IInspectable",
    "IUnknown",
    "IInspectableVtbl",
    "IUnknownVtbl",
    // COM class members emitted unconditionally by gen_com.cj.
    "close",
    "isClosed",
    "asRaw",
    "addRef",
    "release",
    "vtbl",
    "iid",
    "descriptor",
    "fromAbiTake",
    "viewOf",
    "query"
])

// Rename when the method identifier shadows a type referenced anywhere in its
// own signature (return type or parameter types) or matches an always-imported
// type name that the surrounding class body references.
func disambiguateMethodName(methodName: String, signatureText: String): String {
    if (alwaysShadowingNames_.contains(methodName)) {
        return "get_${methodName}"
    }
    if (methodName == signatureText || signatureContainsTypeReference(signatureText, methodName)) {
        return "get_${methodName}"
    }
    return methodName
}

func signatureContainsTypeReference(signature: String, name: String): Bool {
    let sigBytes = signature.toArray()
    let nameBytes = name.toArray()
    let n = Int64(sigBytes.size)
    let m = Int64(nameBytes.size)
    if (m == 0 || m > n) {
        return false
    }
    var i: Int64 = 0
    while (i + m <= n) {
        var matches = true
        var j: Int64 = 0
        while (j < m) {
            if (sigBytes[i + j] != nameBytes[j]) {
                matches = false
                break
            }
            j += 1
        }
        if (matches) {
            let beforeOk = i == 0 || !isIdentifierChar(sigBytes[i - 1])
            let afterIdx = i + m
            let afterOk = afterIdx >= n || !isIdentifierChar(sigBytes[afterIdx])
            if (beforeOk && afterOk) {
                return true
            }
        }
        i += 1
    }
    return false
}

func isIdentifierChar(b: Byte): Bool {
    if (b == b'_') { return true }
    if (b >= b'a' && b <= b'z') { return true }
    if (b >= b'A' && b <= b'Z') { return true }
    if (b >= b'0' && b <= b'9') { return true }
    return false
}
