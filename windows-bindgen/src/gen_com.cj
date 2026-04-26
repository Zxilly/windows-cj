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
    useSupportSymbol("windows_interface", "InterfaceWrapperBase")
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
            let returnType = comAbiType(sig.returnType)
            let signatureText = vtblSlotSignatureText(index, sig, returnType, isWinRT)
            let methodName = disambiguateMethodName(rawMethodName, signatureText)
            if (!missing.isEmpty()) {
                warnMissingMethodDependencies(index, fileIdx, mi, missing)
                // Degrade to opaque function-pointer slot; avoids unresolvable type references
                w.writeLine("public var ${methodName}: CPointer<Unit> = CPointer<Unit>.null")
            } else {
                w.writeLine("public var ${methodName}: ${vtblSlotType(index, sig, returnType, isWinRT)} = ${vtblSlotDefault(sig, isWinRT)}")
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
    w.writeLine("    ${name}.viewOf(raw)")
    w.writeLine("}")

    // --- Generate interface class ---
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    let implInterfaces = if (isWinRT && !isSysOnlyMode()) {
        "InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType"
    } else {
        "InterfaceWrapperBase & ComInterface"
    }
    w.writeBlock("public class ${name} <: ${implInterfaces}", {=>
        w.writeLine("public init(raw: CPointer<Unit>) {")
        w.writeLine("    super(raw)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {")
        w.writeLine("    super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func fromAbiTake(raw: CPointer<Unit>): ${name} {")
        w.writeLine("    ${name}(raw, takeOwnership: true, allowManualRelease: false)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func viewOf(raw: CPointer<Unit>): ${name} {")
        w.writeLine("    ${name}(raw, takeOwnership: false, allowManualRelease: false)")
        w.writeLine("}")
        w.writeBlankLine()

        // static iid() - try to extract from GuidAttribute
        writeIidMethod(w, index, fileIdx, row)

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
        w.writeLine("public unsafe func vtbl(): ${vtblName} {")
        w.writeLine("    readVtbl<${vtblName}>(${vtblName}())")
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
            if (isWinRT) {
                writeWinrtRawWrapperMethod(w, index, fileIdx, sig, methodName, pStart, pEnd)
            } else {
                writeWrapperMethod(w, index, fileIdx, sig, methodName, pStart, pEnd)
            }
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
                return BaseVtblSubstitution("windows_interface.IInspectableVtbl", None<String>)
            }
            let baseTypePath = projectedTypePath(baseType.namespace, baseLeaf)
            return BaseVtblSubstitution("${baseTypePath}Vtbl", Some<String>("${baseTypePath}.iid()"))
        case None =>
            if (isWinRT) {
                return BaseVtblSubstitution("windows_interface.IInspectableVtbl", None<String>)
            }
            return BaseVtblSubstitution("windows_interface.IUnknownVtbl", None<String>)
    }
}

func vtblSlotType(index: TypeIndex, sig: MethodSignature, returnType: String, isWinRT: Bool): String {
    var params = ArrayList<String>()
    params.add("CPointer<Unit>")
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        if (isWinRT) {
            addWinrtRawAbiParamTypes(index, params, sig.paramTypes[pi])
        } else {
            params.add(comAbiType(sig.paramTypes[pi]))
        }
        pi += 1
    }
    if (isWinRT) {
        addWinrtRawAbiResultTypes(index, params, sig.returnType)
        return "CFunc<(${joinStrings(params, ", ")}) -> Int32>"
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> ${returnType}>"
}

func vtblSlotDefault(sig: MethodSignature, isWinRT: Bool): String {
    var paramNames = ArrayList<String>()
    paramNames.add("_")
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        if (isWinRT) {
            addWinrtRawAbiParamNames(paramNames, sig.paramTypes[pi])
        } else {
            paramNames.add("_")
        }
        pi += 1
    }
    if (isWinRT) {
        addWinrtRawAbiResultNames(paramNames, sig.returnType)
        return "{ ${joinStrings(paramNames, ", ")} => 0 }"
    }
    return "{ ${joinStrings(paramNames, ", ")} => ${comAbiDefaultValue(sig.returnType)} }"
}

// Write the static iid() method by extracting GuidAttribute
func writeIidMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64
): Unit {
    let guid = guidAttributeLiteral(index, fileIdx, row)
    match (guid) {
        case Some(g) =>
            w.writeLine("public static func iid(): GUID {")
            w.writeLine("    return GUID(${g})")
            w.writeLine("}")
        case None =>
            w.writeLine("public static func iid(): GUID {")
            w.writeLine("    return GUID.zeroed()")
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
        let paramType = comAbiType(sig.paramTypes[pi])
        params.add("${paramName}: ${paramType}")
        argNames.add(paramName)
        pi += 1
    }

    let returnType = comAbiType(sig.returnType)
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

func writeWinrtRawWrapperMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    sig: MethodSignature,
    methodName: String,
    pStart: Int64,
    pEnd: Int64
): Unit {
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

    var params = ArrayList<String>()
    var argNames = ArrayList<String>()
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        var paramName = "param${pi}"
        let seq = pi + 1
        if (seqToName.contains(seq)) {
            paramName = seqToName[seq]
        }
        addWinrtRawWrapperParam(index, params, argNames, paramName, sig.paramTypes[pi])
        pi += 1
    }
    addWinrtRawWrapperResultParam(index, params, argNames, sig.returnType)

    let returnType = comAbiType(sig.returnType)
    let wrapperName = disambiguateMethodName(methodName, vtblSlotSignatureText(index, sig, returnType, true))
    let paramStr = joinStrings(params, ", ")
    let argStr = joinStrings(argNames, ", ")

    w.writeLine("public unsafe func ${wrapperName}(${paramStr}): Int32 {")
    w.writeLine("    let __vt = vtbl()")
    w.writeLine("    let __liveRaw = asRaw()")
    if (argStr.isEmpty()) {
        w.writeLine("    return __vt.${wrapperName}(__liveRaw)")
    } else {
        w.writeLine("    return __vt.${wrapperName}(__liveRaw, ${argStr})")
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
        parts.add(comAbiType(sig.paramTypes[pi]))
        pi += 1
    }
    return joinStrings(parts, " ")
}

func vtblSlotSignatureText(index: TypeIndex, sig: MethodSignature, returnType: String, isWinRT: Bool): String {
    if (!isWinRT) {
        return methodSignatureText(sig, returnType)
    }
    let parts = ArrayList<String>()
    var pi: Int64 = 0
    while (pi < Int64(sig.paramTypes.size)) {
        collectWinrtRawAbiParamTypeText(index, parts, sig.paramTypes[pi])
        pi += 1
    }
    collectWinrtRawAbiResultTypeText(index, parts, sig.returnType)
    parts.add("Int32")
    return joinStrings(parts, " ")
}

func addWinrtRawAbiParamTypes(index: TypeIndex, params: ArrayList<String>, ty: MetadataType): Unit {
    match (ty) {
        case MetadataType.MdArray(elem) =>
            params.add("UInt32")
            params.add(winrtRawArrayPointerType(index, elem))
        case _ =>
            params.add(winrtRawSlotType(index, ty))
    }
}

func addWinrtRawAbiResultTypes(index: TypeIndex, params: ArrayList<String>, ty: MetadataType): Unit {
    match (ty) {
        case MetadataType.Void => return
        case MetadataType.MdArray(elem) =>
            params.add("CPointer<UInt32>")
            params.add("CPointer<${winrtRawArrayPointerType(index, elem)}>")
        case _ =>
            params.add("CPointer<${winrtRawSlotType(index, ty)}>")
    }
}

func addWinrtRawAbiParamNames(names: ArrayList<String>, ty: MetadataType): Unit {
    match (ty) {
        case MetadataType.MdArray(_) =>
            names.add("_")
            names.add("_")
        case _ =>
            names.add("_")
    }
}

func addWinrtRawAbiResultNames(names: ArrayList<String>, ty: MetadataType): Unit {
    match (ty) {
        case MetadataType.Void => ()
        case MetadataType.MdArray(_) =>
            names.add("_")
            names.add("_")
        case _ =>
            names.add("_")
    }
}

func addWinrtRawWrapperParam(
    index: TypeIndex,
    params: ArrayList<String>,
    argNames: ArrayList<String>,
    paramName: String,
    ty: MetadataType
): Unit {
    match (ty) {
        case MetadataType.MdArray(elem) =>
            params.add("${paramName}Size: UInt32")
            params.add("${paramName}: ${winrtRawArrayPointerType(index, elem)}")
            argNames.add("${paramName}Size")
            argNames.add(paramName)
        case _ =>
            params.add("${paramName}: ${winrtRawSlotType(index, ty)}")
            argNames.add(paramName)
    }
}

func addWinrtRawWrapperResultParam(
    index: TypeIndex,
    params: ArrayList<String>,
    argNames: ArrayList<String>,
    ty: MetadataType
): Unit {
    match (ty) {
        case MetadataType.Void => ()
        case MetadataType.MdArray(elem) =>
            let arrayPointerType = winrtRawArrayPointerType(index, elem)
            params.add("resultSize__: CPointer<UInt32>")
            params.add("result__: CPointer<${arrayPointerType}>")
            argNames.add("resultSize__")
            argNames.add("result__")
        case _ =>
            let slotType = winrtRawSlotType(index, ty)
            params.add("result__: CPointer<${slotType}>")
            argNames.add("result__")
    }
}

func collectWinrtRawAbiParamTypeText(index: TypeIndex, parts: ArrayList<String>, ty: MetadataType): Unit {
    match (ty) {
        case MetadataType.MdArray(elem) =>
            parts.add("UInt32")
            parts.add(winrtRawArrayPointerType(index, elem))
        case _ =>
            parts.add(winrtRawSlotType(index, ty))
    }
}

func collectWinrtRawAbiResultTypeText(index: TypeIndex, parts: ArrayList<String>, ty: MetadataType): Unit {
    match (ty) {
        case MetadataType.Void => ()
        case MetadataType.MdArray(elem) =>
            parts.add("CPointer<UInt32>")
            parts.add("CPointer<${winrtRawArrayPointerType(index, elem)}>")
        case _ =>
            parts.add("CPointer<${winrtRawSlotType(index, ty)}>")
    }
}

func winrtRawArrayPointerType(index: TypeIndex, elem: MetadataType): String {
    return "CPointer<${winrtRawSlotType(index, elem)}>"
}

func winrtRawSlotType(index: TypeIndex, ty: MetadataType): String {
    if (isWinrtStringMetadataType(ty)) {
        return "CPointer<Unit>"
    }
    match (ty) {
        case MetadataType.MdObject => return "CPointer<Unit>"
        case MetadataType.ClassName(typeName) =>
            if (isNativeDelegateTypeName(index, typeName)) {
                return cppType(ty)
            }
            return "CPointer<Unit>"
        case MetadataType.ValueName(typeName) =>
            if (isNativeDelegateTypeName(index, typeName)) {
                return cppType(ty)
            }
            if (isReferenceProjectionType(index, typeName)) {
                return "CPointer<Unit>"
            }
            return cppType(ty)
        case MetadataType.MdArray(elem) =>
            return winrtRawArrayPointerType(index, elem)
        case MetadataType.Generic(_, _) =>
            return "CPointer<Unit>"
        case MetadataType.RefMut(inner) =>
            return "CPointer<${winrtRawSlotType(index, inner)}>"
        case MetadataType.RefConst(inner) =>
            return "CPointer<${winrtRawSlotType(index, inner)}>"
        case MetadataType.PtrMut(inner, depth) =>
            return wrapWinrtRawSlotPointer(index, inner, depth)
        case MetadataType.PtrConst(inner, depth) =>
            return wrapWinrtRawSlotPointer(index, inner, depth)
        case MetadataType.ArrayFixed(inner, size) =>
            return "VArray<${winrtRawSlotType(index, inner)}, \$${size}>"
        case MetadataType.Packed(inner, _) =>
            return winrtRawSlotType(index, inner)
        case _ =>
            return cppType(ty)
    }
}

func wrapWinrtRawSlotPointer(index: TypeIndex, inner: MetadataType, depth: Int64): String {
    var result = winrtRawSlotType(index, inner)
    var d = depth
    while (d > 0) {
        result = "CPointer<${result}>"
        d -= 1
    }
    return result
}

func comAbiType(ty: MetadataType): String {
    return functionAbiTypeForPointerInNamespace(currentNamespace(), ty)
}

func comAbiDefaultValue(ty: MetadataType): String {
    let abiType = comAbiType(ty)
    if (abiType != cppType(ty)) {
        return highLevelResultDefaultExpr(abiType)
    }
    return cppDefaultValue(ty)
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
