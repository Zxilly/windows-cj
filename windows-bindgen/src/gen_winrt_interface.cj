package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.winmd.*

public func generateWinrtInterface(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    config: BindgenConfig
): Unit {
    let name = trimTick(index.typeDefName(fileIdx, row))
    let feature = namespaceToFeature(namespace)
    let arches = index.arches(TABLE_TYPE_DEF, fileIdx, row)
    let genericParams = winmdTypeGenericParameterNames(index, fileIdx, row)
    let genericDecl = typeGenericDeclaration(genericParams)
    let typeName = typedProjectionName(name, genericParams)
    let vtblName = "${name}Vtbl"
    let runtimeName = "${namespace}.${name}"
    let baseInterface = winmdFirstInterfaceType(index, fileIdx, row)
    let ancestors = winmdCollectInterfaceAncestors(index, fileIdx, row)
    let isExclusive = index.hasAttribute(TABLE_TYPE_DEF, fileIdx, row, "ExclusiveToAttribute")
    let emitImplSurface = shouldEmitWinrtImplSurface(config, isExclusive)
    let typeTags = typeAvailabilityTags(namespace, name, fileIdx, row, arches)
    let definitionTags = architectureCfgTags(arches)
    let implSurfaceTags = winrtInterfaceImplSurfaceAvailabilityTags(index, fileIdx, row, typeTags, ancestors)

    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    let genericsArray = winmdBuildGenericArray(index, fileIdx, winmdRowGenericStart(index, fileIdx, row), winmdRowGenericEnd(index, fileIdx, row))
    let methodNames = buildWinrtMethodNames(index, fileIdx, row, genericsArray)
    let genericConstraintKinds = winrtGenericConstraintKindsForInterface(index, fileIdx, row, genericParams, genericsArray)
    let genericWhere = winrtProjectionWhereClause(genericParams, genericConstraintKinds)

    // Register support symbols this file emits so the prelude can compute a
    // precise per-symbol import list rather than wildcard imports.
    useSupportSymbol("windows_interface", "ComInterface")
    useSupportSymbol("windows_interface", "RuntimeName")
    useSupportSymbol("windows_interface", "RuntimeType")
    useSupportSymbol("windows_interface", "RuntimeTypeContract")
    useSupportSymbol("windows_interface", "InterfaceWrapperBase")
    useSupportSymbol("windows_interface", "InterfaceDescriptor")
    useSupportSymbol("windows_interface", "InterfaceDescriptorSchema")
    useSupportSymbol("windows_interface", "InterfaceMethodSchema")
    useSupportSymbol("windows_interface", "InterfaceParameterSchema")
    useSupportSymbol("windows_interface", "InterfaceParameterBridgeKind")
    useSupportSymbol("windows_interface", "DescriptorSchemaProvider")
    useSupportSymbol("windows_interface", "GUID")
    useSupportSymbol("windows_interface", "IInspectable")
    useSupportSymbol("windows_interface", "IInspectableVtbl")
    useSupportSymbol("windows_interface", "IUnknown")
    useSupportSymbol("windows_interface", "IUnknownVtbl")
    useSupportSymbol("windows_core", "RuntimeType")
    useSupportSymbol("windows_core", "Result")
    useSupportSymbol("windows_core", "InParam")
    useSupportSymbol("windows_core", "OutSlot")
    useSupportSymbol("windows_core", "Type")
    useSupportSymbol("windows_core", "ComObject")
    useSupportSymbol("windows_core", "asImplFromRaw")
    useSupportSymbol("windows_core", "buildIInspectableVtbl")
    useSupportSymbol("windows_core", "assumeInitRef")
    useSupportSymbol("windows_core", "fromAbi")
    useSupportSymbol("windows_core", "projectAbiValue")
    useSupportSymbol("windows_core", "typeMarker")
    useSupportSymbol("windows_core", "projectTypedAbi")
    useSupportSymbol("windows_core", "assumeInitTypedAbi")
    useSupportSymbol("windows_core", "fromTypedAbi")
    useSupportSymbol("windows_core", "borrowOutSlotTypedAbi")
    useSupportSymbol("windows_core", "takeOutSlotTypedAbi")
    useSupportSymbol("windows_core", "S_OK")
    useSupportSymbol("windows_core", "E_POINTER")
    useSupportSymbol("windows_core", "E_NOTIMPL")
    useSupportSymbol("windows_core", "E_NOINTERFACE")
    useSupportSymbol("windows_core", "HRESULT")
    useSupportSymbol("windows_polyfill", "FactoryCache")

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, definitionTags)
    w.writeLine("@C")
    w.writeBlock("public struct ${vtblName}", { =>
        // Every WinRT interface vtbl derives directly from IInspectableVtbl.
        // Even when the metadata declares one or more required interfaces, the
        // vtable layout per WinRT ABI is { IInspectable; this interface's own
        // methods } — required interfaces are reached through QueryInterface,
        // not by inlining their vtbl into this slot. Inlining would shift the
        // own-method slot indices and break external COM consumers.
        w.writeLine("public var base_: IInspectableVtbl = IInspectableVtbl()")
        // baseInterface is intentionally not consulted for vtbl layout; it is
        // still consumed by the descriptor / matches surface below.
        let _ = baseInterface

        var methodRow = mStart
        while (methodRow < mEnd) {
            let methodName = methodNames[methodRow]
            let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
            let missing = missingMethodDependencies(index, fileIdx, methodRow, genericsArray)
            // Vtable slots preserve ABI layout even when the public wrapper
            // method is feature-gated. Cangjie cannot conditionally guard the
            // assignment statements in Vtbl.new(), so keep the slot present
            // and gate the callable wrapper surface instead.
            if (!missing.isEmpty()) {
                warnMissingMethodDependencies(index, fileIdx, methodRow, missing)
                // Degrade to opaque slot when dependencies are unavailable
                w.writeLine("public var ${methodName}: CPointer<Unit> = CPointer<Unit>.null")
            } else {
                let vtblEntry = generateWinrtVtblEntry(index, sig)
                let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, methodRow)
                if (!methodTags.isEmpty()) {
                    writeAvailabilityForTags(w, "", methodTags)
                    w.writeLine("public var ${methodName}: ${vtblEntry} = ${winrtVtblEntryDefault(index, sig)}")
                    writeNegatedAvailabilityForTags(w, "", methodTags)
                    w.writeLine("public var ${methodName}: UIntNative = UIntNative(0)")
                } else {
                    w.writeLine("public var ${methodName}: ${vtblEntry} = ${winrtVtblEntryDefault(index, sig)}")
                }
            }
            methodRow += 1
        }

        w.writeLine("public init() {}")

        if (emitImplSurface) {
            w.writeBlankLine()
            if (!implSurfaceTags.isEmpty()) {
                writeAvailabilityForTags(w, "", implSurfaceTags)
            }
            writeWinrtInterfaceVtblNewMethod(w, index, fileIdx, row, name, vtblName, baseInterface, genericParams,
                genericConstraintKinds, implSurfaceTags, methodNames, genericsArray)
            w.writeBlankLine()
            writeWinrtInterfaceVtblMatchesMethod(w, index, typeName, genericParams, genericConstraintKinds, ancestors)
        }
    })

    if (emitImplSurface) {
        w.writeBlankLine()
        writeAvailabilityForTags(w, feature, implSurfaceTags)
        writeWinrtInterfaceImplErasedSurface(w, index, fileIdx, row, name, methodNames, genericsArray)
        w.writeBlankLine()
        writeAvailabilityForTags(w, feature, implSurfaceTags)
        writeWinrtInterfaceImplSurface(w, index, fileIdx, row, name, genericParams, genericWhere, ancestors, methodNames, genericsArray)
    }

    writeWinrtAbiBridgeHelpers(w, index, fileIdx, row, name, feature, genericParams, methodNames, genericsArray)

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, definitionTags)
    w.writeBlock("public class ${name}${genericDecl} <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider${genericWhere}", { =>
        w.writeLine("public init(raw: CPointer<Unit>) {")
        w.writeLine("    super(raw)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("private init(raw: CPointer<Unit>, takeOwnership!: Bool) {")
        w.writeLine("    super(raw, takeOwnership: takeOwnership)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func fromAbiTake(raw: CPointer<Unit>): ${typeName} {")
        w.writeLine("    ${typeName}(raw, takeOwnership: true)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func viewOf(raw: CPointer<Unit>): ${typeName} {")
        w.writeLine("    ${typeName}(raw)")
        w.writeLine("}")
        w.writeBlankLine()
        writeWinrtIidMethod(w, index, fileIdx, row, typeName, genericParams)
        w.writeBlankLine()
        writeWinrtInterfaceMatchesMethod(w, index, typeName, ancestors)
        w.writeBlankLine()
        writeWinrtDescriptorMethod(w, index, name, typeName, ancestors)
        w.writeBlankLine()
        writeWinrtDescriptorSchemaMethod(w, index, fileIdx, row, name, typeName, vtblName, ancestors, methodNames, genericsArray)
        w.writeBlankLine()
        w.writeLine("public static func abiType(): String {")
        w.writeLine("    \"CPointer<Unit>\"")
        w.writeLine("}")
        w.writeBlankLine()
        writeWinrtSignatureMethod(w, index, fileIdx, row, genericParams, false)
        w.writeBlankLine()
        w.writeLine("public static func runtimeName(): String {")
        w.writeLine("    \"${runtimeName}\"")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func runtimeType(): RuntimeTypeContract {")
        w.writeLine("    RuntimeTypeContract(\"${runtimeName}\", ${typeName}.signature(), ${typeName}.iid())")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func asIInspectable(): IInspectable {")
        w.writeLine("    IInspectable.viewOf(asRaw())")
        w.writeLine("}")
        for (ancestor in ancestors) {
            let ancestorProjection = typeNameToProjectionCj(index, ancestor)
            let ancestorLeaf = trimTick(ancestor.name)
            if (ancestorLeaf == "IInspectable" || ancestorLeaf == "IUnknown") {
                continue
            }
            w.writeBlankLine()
            // The vtbl of `this` is flat (own methods only past the IInspectable head); it does NOT
            // contain the ancestor's slots inline. To talk to the ancestor we must perform a real
            // QueryInterface so the result has the ancestor's vtbl. Falling back to viewOf(asRaw())
            // would alias the wrong vtbl and dispatch slots into the wrong methods.
            w.writeLine("public func as${ancestorLeaf}(): ${ancestorProjection} {")
            w.writeLine("    match (unsafe { query<${ancestorProjection}>(${ancestorProjection}.descriptor()) }) {")
            w.writeLine("        case Some(value) => value")
            w.writeLine("        case None => throw Exception(\"as${ancestorLeaf}: QueryInterface failed (E_NOINTERFACE)\")")
            w.writeLine("    }")
            w.writeLine("}")
        }
        w.writeBlankLine()
        w.writeLine("public unsafe func vtbl(): ${vtblName} {")
        w.writeLine("    readVtbl<${vtblName}>(${vtblName}())")
        w.writeLine("}")

        var methodRow2 = mStart
        while (methodRow2 < mEnd) {
            let methodName = methodNames[methodRow2]
            let sig = index.methodDefSignature(fileIdx, methodRow2, genericsArray)
            let (pStart, pEnd) = index.methodDefParams(fileIdx, methodRow2)
            let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, methodRow2)
            w.writeBlankLine()
            if (!methodTags.isEmpty()) {
                writeAvailabilityForTags(w, "", methodTags)
            }
            writeWinrtWrapperMethod(w, index, fileIdx, name, genericParams, sig, methodName, pStart, pEnd)
            methodRow2 += 1
        }

        writeInterfaceIteratorProjectionMembers(w, index, namespace, name, genericParams, ancestors)
    })
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, definitionTags)
    w.writeLine("extend${genericDecl} ${typeName} <: windows_core.Interface<${typeName}>${genericWhere} {}")

    if (isIteratorProjectionSource(namespace, name) && genericParams.size == 1) {
        w.writeBlankLine()
        writeAvailabilityForTags(w, feature, definitionTags)
        writeIIteratorIteratorAdapter(w, genericParams[0])
    }
}

func shouldEmitWinrtImplSurface(config: BindgenConfig, isExclusive: Bool): Bool {
    return config.implement || !isExclusive
}

func winrtInterfaceImplSurfaceAvailabilityTags(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    ownTags: ArrayList<String>,
    ancestors: ArrayList<TypeName>
): ArrayList<String> {
    var result = winrtInterfaceOwnImplSurfaceAvailabilityTags(index, fileIdx, row, ownTags)
    for (ancestor in ancestors) {
        result = mergeAvailabilityTagsAsAnd(result, winrtInterfaceOwnImplSurfaceAvailabilityTagsForTypeName(index, ancestor))
    }
    return result
}

func winrtInterfaceOwnImplSurfaceAvailabilityTags(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    ownTags: ArrayList<String>
): ArrayList<String> {
    var result = copyAvailabilityTags(ownTags)
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        result = mergeAvailabilityTagsAsAnd(result, itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, methodRow))
        methodRow += 1
    }
    return result
}

func winrtInterfaceOwnImplSurfaceAvailabilityTagsForTypeName(index: TypeIndex, typeName: TypeName): ArrayList<String> {
    let candidates = index.get(typeName.definition())
    for (candidate in candidates) {
        let fileIdx = candidate.fileIdx
        let row = candidate.row
        let arches = index.arches(TABLE_TYPE_DEF, fileIdx, row)
        if (isUnsupportedOnlyArchitecture(arches)) {
            continue
        }
        match (index.typeDefCategory(fileIdx, row)) {
            case Interface =>
                let name = trimTick(typeName.name)
                let ownTags = typeAvailabilityTags(typeName.namespace, name, fileIdx, row, arches)
                return winrtInterfaceOwnImplSurfaceAvailabilityTags(index, fileIdx, row, ownTags)
            case _ => ()
        }
    }
    return ArrayList<String>()
}

func buildWinrtMethodNames(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    genericsArray: Array<MetadataType>
): HashMap<Int64, String> {
    let result = HashMap<Int64, String>()
    let baseNames = buildNormalizedMethodNames(index, fileIdx, row)
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
        result[methodRow] = disambiguateWinrtMethodName(index, baseNames[methodRow], sig)
        methodRow += 1
    }
    return result
}

func disambiguateWinrtMethodName(index: TypeIndex, methodName: String, sig: MethodSignature): String {
    return disambiguateMethodName(methodName, highLevelMethodSignatureText(index, sig))
}

func highLevelMethodSignatureText(index: TypeIndex, sig: MethodSignature): String {
    let parts = ArrayList<String>()
    parts.add(highLevelType(index, sig.returnType))
    for (paramType in sig.paramTypes) {
        parts.add(highLevelType(index, paramType))
    }
    return joinStrings(parts, " ")
}

func winrtAbiHelperGenericDeclaration(
    genericParams: ArrayList<String>,
    includeIdentity: Bool
): String {
    let params = ArrayList<String>()
    if (includeIdentity) {
        params.add("Identity")
    }
    for (genericParam in genericParams) {
        params.add(genericParam)
        params.add("${genericParam}Abi")
        params.add("${genericParam}Default")
    }
    if (params.isEmpty()) {
        return ""
    }
    return "<${joinStrings(params, ", ")}>"
}

func winrtAbiHelperWhereClause(
    interfaceName: String,
    genericParams: ArrayList<String>,
    includeIdentity: Bool
): String {
    let clauses = ArrayList<String>()
    if (includeIdentity) {
        clauses.add("Identity <: ${interfaceName}_Impl${typeGenericDeclaration(genericParams)}")
    }
    for (genericParam in genericParams) {
        clauses.add("${genericParam} <: windows_core.RuntimeType & windows_core.Type<${genericParam}, ${genericParam}Abi, ${genericParam}Default>")
        clauses.add("${genericParam}Abi <: CType")
    }
    if (clauses.isEmpty()) {
        return ""
    }
    return " where ${joinStrings(clauses, ", ")}"
}

func winrtAbiHelperMarkerParams(genericParams: ArrayList<String>): ArrayList<String> {
    let params = ArrayList<String>()
    for (genericParam in genericParams) {
        params.add("${genericParam}Marker: Option<${genericParam}>")
    }
    return params
}

func winrtAbiHelperMarkerNames(genericParams: ArrayList<String>): ArrayList<String> {
    let names = ArrayList<String>()
    for (genericParam in genericParams) {
        names.add("${genericParam}Marker")
    }
    return names
}

func winrtAbiHelperMarkerArgs(genericParams: ArrayList<String>): ArrayList<String> {
    let args = ArrayList<String>()
    for (genericParam in genericParams) {
        args.add("windows_core.typeMarker<${genericParam}>()")
    }
    return args
}

func winrtAbiCastHelperName(interfaceName: String, methodName: String): String {
    return "${interfaceName}_${methodName}_Cast"
}

func winrtAbiEraseHelperName(interfaceName: String, methodName: String): String {
    return "${interfaceName}_${methodName}_Erase"
}

func winrtPublicParameterDecls(
    index: TypeIndex,
    sig: MethodSignature,
    seqToName: HashMap<Int64, String>
): ArrayList<String> {
    let params = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        let seq = i + 1
        let paramName = if (seqToName.contains(seq)) {
            seqToName[seq]
        } else {
            "param${i}"
        }
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(elem) =>
                params.add("${paramName}Size: UInt32")
                params.add("${paramName}: ${winrtPublicArrayPointerType(index, elem)}")
            case _ =>
                params.add("${paramName}: ${highLevelType(index, sig.paramTypes[i])}")
        }
        i += 1
    }
    return params
}

func winrtPublicParameterNames(
    index: TypeIndex,
    sig: MethodSignature,
    seqToName: HashMap<Int64, String>
): ArrayList<String> {
    let names = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        let seq = i + 1
        let paramName = if (seqToName.contains(seq)) {
            seqToName[seq]
        } else {
            "param${i}"
        }
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(_) =>
                names.add("${paramName}Size")
                names.add(paramName)
            case _ =>
                names.add(paramName)
        }
        i += 1
    }
    return names
}

func winrtImplParameterDecls(
    index: TypeIndex,
    sig: MethodSignature,
    seqToName: HashMap<Int64, String>
): ArrayList<String> {
    let params = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        let seq = i + 1
        let paramName = if (seqToName.contains(seq)) {
            seqToName[seq]
        } else {
            "param${i}"
        }
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(elem) =>
                params.add("${paramName}Size: UInt32")
                params.add("${paramName}: ${winrtPublicArrayPointerType(index, elem)}")
            case _ =>
                let publicType = highLevelType(index, sig.paramTypes[i])
                let paramType = if (highLevelNeedsInParam(index, sig.paramTypes[i])) {
                    "InParam<${publicType}>"
                } else {
                    publicType
                }
                params.add("${paramName}: ${paramType}")
        }
        i += 1
    }
    return params
}

func winrtActualThunkParams(index: TypeIndex, sig: MethodSignature): ArrayList<String> {
    let params = ArrayList<String>()
    params.add("CPointer<Unit>")
    for (paramType in sig.paramTypes) {
        match (paramType) {
            case MetadataType.MdArray(elem) =>
                params.add("UInt32")
                params.add(winrtActualArrayPointerType(index, elem))
            case _ =>
                params.add(winrtActualAbiType(index, paramType))
        }
    }
    if (highLevelHasResult(sig)) {
        match (sig.returnType) {
            case MetadataType.MdArray(elem) =>
                params.add("CPointer<UInt32>")
                params.add("CPointer<${winrtActualArrayPointerType(index, elem)}>")
            case _ =>
                params.add("CPointer<${winrtActualAbiType(index, sig.returnType)}>")
        }
    }
    return params
}

func winrtActualAbiArgumentExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    match (ty) {
        case MetadataType.Generic(name, _) =>
            return "windows_core.projectTypedAbi(${expr}, windows_core.typeMarker<${name}>())"
        case _ =>
            return highLevelArgumentExpr(index, ty, expr)
    }
}

func winrtActualThunkArgumentExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    match (ty) {
        case MetadataType.Generic(name, _) =>
            return "windows_core.assumeInitTypedAbi(${expr}, windows_core.typeMarker<${name}>())"
        case _ =>
            return highLevelThunkParamExpr(index, ty, expr)
    }
}

func winrtActualReturnExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    match (ty) {
        case MetadataType.Generic(name, _) =>
            return "windows_core.fromTypedAbi(${expr}, windows_core.typeMarker<${name}>()).unwrap()"
        case _ =>
            return highLevelReturnExpr(index, ty, expr)
    }
}

func winrtActualThunkReturnExpr(index: TypeIndex, ty: MetadataType, expr: String): String {
    match (ty) {
        case MetadataType.Generic(name, _) =>
            return "windows_core.projectTypedAbi(${expr}, windows_core.typeMarker<${name}>())"
        case _ =>
            return highLevelThunkReturnExpr(index, ty, expr)
    }
}

func winrtActualResultDefaultExpr(index: TypeIndex, ty: MetadataType): String {
    match (ty) {
        case MetadataType.Generic(name, _) => "${name}Abi()"
        case _ => highLevelResultDefaultExpr(highLevelAbiType(index, ty))
    }
}

func winrtArrayThunkBridgeExpr(index: TypeIndex, elem: MetadataType, expr: String): String {
    match (elem) {
        case MetadataType.Generic(_, _) => "CPointer<Unit>(${expr})"
        case _ => expr
    }
}

func winrtPublicReturnType(index: TypeIndex, ty: MetadataType): String {
    match (ty) {
        case MetadataType.MdArray(elem) => "(UInt32, ${winrtPublicArrayPointerType(index, elem)})"
        case _ => highLevelType(index, ty)
    }
}

// WinRT ABI bridge helpers (cast/erase) -- this surface is intentionally currently a no-op.
// The supporting helpers below (writeWinrtAbiCastHelper, writeWinrtAbiEraseHelper, and friends)
// remain in the source as a seed for the future generic-ABI bridge implementation. They are
// retained alongside this no-op to preserve the design intent while keeping the active code
// path clean. Compiler `-Woff unused` keeps these helpers from polluting the build log.
func writeWinrtAbiBridgeHelpers(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    interfaceName: String,
    feature: String,
    genericParams: ArrayList<String>,
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>
): Unit {
    let _ = w
    let _ = index
    let _ = fileIdx
    let _ = row
    let _ = interfaceName
    let _ = feature
    let _ = genericParams
    let _ = methodNames
    let _ = genericsArray
    // No body -- this hook is currently disabled. Reactivate by reinstating the per-method bridge
    // emission loop using the helpers defined later in this file.
}

func writeWinrtAbiCastHelper(
    w: CodeWriter,
    index: TypeIndex,
    interfaceName: String,
    genericParams: ArrayList<String>,
    sig: MethodSignature,
    methodName: String
): Unit {
    let genericDecl = winrtAbiHelperGenericDeclaration(genericParams, false)
    let whereClause = winrtAbiHelperWhereClause(interfaceName, genericParams, false)
    let fieldType = generateWinrtVtblEntry(index, sig)
    let actualThunkType = "CFunc<(${joinStrings(winrtActualThunkParams(index, sig), ", ")}) -> Int32>"
    let params = ArrayList<String>()
    params.add("slot: ${fieldType}")
    for (markerParam in winrtAbiHelperMarkerParams(genericParams)) {
        params.add(markerParam)
    }
    w.writeLine("func ${winrtAbiCastHelperName(interfaceName, methodName)}${genericDecl}(${joinStrings(params, ", ")}): ${actualThunkType}${whereClause} {")
    w.indent()
    for (markerName in winrtAbiHelperMarkerNames(genericParams)) {
        w.writeLine("let _ = ${markerName}")
    }
    w.writeLine("return ${actualThunkType}(CPointer<Unit>(slot))")
    w.dedent()
    w.writeLine("}")
}

func writeWinrtAbiEraseHelper(
    w: CodeWriter,
    index: TypeIndex,
    interfaceName: String,
    genericParams: ArrayList<String>,
    sig: MethodSignature,
    methodName: String
): Unit {
    let genericDecl = winrtAbiHelperGenericDeclaration(genericParams, false)
    let whereClause = winrtAbiHelperWhereClause(interfaceName, genericParams, false)
    let fieldType = generateWinrtVtblEntry(index, sig)
    let actualThunkType = "CFunc<(${joinStrings(winrtActualThunkParams(index, sig), ", ")}) -> Int32>"
    let params = ArrayList<String>()
    for (markerParam in winrtAbiHelperMarkerParams(genericParams)) {
        params.add(markerParam)
    }
    params.add("thunk: ${actualThunkType}")
    w.writeLine("func ${winrtAbiEraseHelperName(interfaceName, methodName)}${genericDecl}(${joinStrings(params, ", ")}): ${fieldType}${whereClause} {")
    w.indent()
    for (markerName in winrtAbiHelperMarkerNames(genericParams)) {
        w.writeLine("let _ = ${markerName}")
    }
    w.writeLine("return ${fieldType}(CPointer<Unit>(thunk))")
    w.dedent()
    w.writeLine("}")
}

func writeWinrtInterfaceImplSurface(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    name: String,
    genericParams: ArrayList<String>,
    genericWhere: String,
    ancestors: ArrayList<TypeName>,
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>
): Unit {
    let implName = "${name}_Impl"
    let erasedName = winrtImplErasedName(name)
    let inherited = ArrayList<String>()
    inherited.add(erasedName)
    for (ancestor in minimizeImplAncestors(index, ancestors)) {
        inherited.add(winrtImplSurfaceTypeName(index, ancestor))
    }

    let header = "public interface ${implName}${typeGenericDeclaration(genericParams)} <: ${joinStrings(inherited, " & ")}${genericWhere}"

    w.writeBlock(header, { =>
        let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
        var wroteMember = false
        var methodRow = mStart
        while (methodRow < mEnd) {
            let methodName = methodNames[methodRow]
            let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
            let (pStart, pEnd) = index.methodDefParams(fileIdx, methodRow)
            if (wroteMember) {
                w.writeBlankLine()
            }
            w.writeLine(winrtImplMethodDeclaration(index, fileIdx, sig, methodName, pStart, pEnd))
            w.writeBlankLine()
            writeWinrtImplThunkHelperMethod(w, index, sig, methodName)
            wroteMember = true
            methodRow += 1
        }
        writeInheritedWinrtImplThunkOverrides(w, index, fileIdx, row, ancestors, methodNames, genericsArray, wroteMember)
    })
}

func winrtImplErasedName(name: String): String {
    return "${name}_ImplErased"
}

func writeWinrtInterfaceImplErasedSurface(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    name: String,
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>
): Unit {
    let erasedName = winrtImplErasedName(name)
    w.writeBlock("public interface ${erasedName}", { =>
        let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
        var methodRow = mStart
        while (methodRow < mEnd) {
            let methodName = methodNames[methodRow]
            let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
            w.writeLine("public func ${winrtThunkHelperName(methodName)}(${joinStrings(winrtThunkHelperParamDecls(index, sig), ", ")}): Int32")
            methodRow += 1
            if (methodRow < mEnd) {
                w.writeBlankLine()
            }
        }
    })
}

func writeInheritedWinrtImplThunkOverrides(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    ancestors: ArrayList<TypeName>,
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>,
    wroteMember: Bool
): Unit {
    let reservedHelpers = HashMap<String, Bool>()
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        reservedHelpers[winrtThunkHelperName(methodNames[methodRow])] = true
        methodRow += 1
    }

    let emittedHelpers = HashMap<String, Bool>()
    var wroteAny = wroteMember
    for (ancestor in ancestors) {
        let candidates = index.get(ancestor.namespace, trimTick(ancestor.name))
        if (candidates.isEmpty()) {
            continue
        }
        let (ancestorFileIdx, ancestorRow) = candidates[0]
        let ancestorGenericsArray = winmdBuildGenericArray(
            index,
            ancestorFileIdx,
            winmdRowGenericStart(index, ancestorFileIdx, ancestorRow),
            winmdRowGenericEnd(index, ancestorFileIdx, ancestorRow)
        )
        let ancestorMethodNames = buildWinrtMethodNames(index, ancestorFileIdx, ancestorRow, ancestorGenericsArray)
        let (ancestorMethodStart, ancestorMethodEnd) = index.typeDefMethods(ancestorFileIdx, ancestorRow)
        var ancestorMethodRow = ancestorMethodStart
        while (ancestorMethodRow < ancestorMethodEnd) {
            let ancestorMethodName = ancestorMethodNames[ancestorMethodRow]
            let helperName = winrtThunkHelperName(ancestorMethodName)
            if (reservedHelpers.contains(helperName) || emittedHelpers.contains(helperName)) {
                ancestorMethodRow += 1
                continue
            }

            if (wroteAny) {
                w.writeBlankLine()
            }
            let sig = substituteMethodSignature(
                index.methodDefSignature(ancestorFileIdx, ancestorMethodRow, ancestorGenericsArray),
                ancestor.generics
            )
            let originalSig = index.methodDefSignature(ancestorFileIdx, ancestorMethodRow, ancestorGenericsArray)
            let callExpr = winrtInheritedImplCallExpr(index, originalSig, sig, "this", ancestorMethodName)
            writeWinrtImplThunkHelperMethodWithParamSig(w, index, sig, originalSig, ancestorMethodName, callExpr)
            emittedHelpers[helperName] = true
            wroteAny = true
            ancestorMethodRow += 1
        }
    }
}

func writeWinrtInterfaceVtblNewMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    name: String,
    vtblName: String,
    baseInterface: Option<TypeName>,
    genericParams: ArrayList<String>,
    genericConstraintKinds: HashMap<String, WinrtGenericConstraintKind>,
    implSurfaceTags: ArrayList<String>,
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>
): Unit {
    let genericDecl = winrtImplMethodGenericDeclaration(genericParams)
    let whereClause = winrtImplMethodWhereClause(name, genericParams, genericConstraintKinds)
    w.writeLine("public static func new${genericDecl}(offset!: Int64 = 0): ${vtblName}${whereClause} {")
    w.indent()
    w.writeLine("let _ = offset")
    w.writeLine("var vtbl = ${vtblName}()")
    // base_ is always IInspectable; required interfaces live in their own
    // vtbls, reached via QueryInterface, not inlined into this struct.
    w.writeLine("vtbl.base_ = buildIInspectableVtbl()")
    let _ = baseInterface

    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        let methodName = methodNames[methodRow]
        let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
        let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, methodRow)
        if (methodTags.isEmpty()) {
            writeWinrtImplThunkAssignment(w, index, name, genericParams, sig, methodName)
        } else {
            w.writeLine("vtbl = ${vtblName}.${winrtVtblAssignHelperName(methodName)}${winrtImplMethodGenericInvocation(genericParams)}(vtbl)")
        }
        methodRow += 1
    }

    w.writeLine("return vtbl")
    w.dedent()
    w.writeLine("}")

    methodRow = mStart
    while (methodRow < mEnd) {
        let methodName = methodNames[methodRow]
        let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
        let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, methodRow)
        if (!methodTags.isEmpty()) {
            writeWinrtVtblAssignHelper(w, index, name, vtblName, genericParams, genericConstraintKinds, sig, methodName,
                implSurfaceTags, methodTags)
        }
        methodRow += 1
    }
}

func winrtImplMethodGenericInvocation(genericParams: ArrayList<String>): String {
    let params = ArrayList<String>()
    params.add("Identity")
    for (genericParam in genericParams) {
        params.add(genericParam)
    }
    return "<${joinStrings(params, ", ")}>"
}

func winrtVtblAssignHelperName(methodName: String): String {
    return "__assign${methodName}"
}

func writeWinrtVtblAssignHelper(
    w: CodeWriter,
    index: TypeIndex,
    name: String,
    vtblName: String,
    genericParams: ArrayList<String>,
    genericConstraintKinds: HashMap<String, WinrtGenericConstraintKind>,
    sig: MethodSignature,
    methodName: String,
    implSurfaceTags: ArrayList<String>,
    methodTags: ArrayList<String>
): Unit {
    let genericDecl = winrtImplMethodGenericDeclaration(genericParams)
    let whereClause = winrtImplMethodWhereClause(name, genericParams, genericConstraintKinds)
    let helperName = winrtVtblAssignHelperName(methodName)

    w.writeBlankLine()
    writeWinrtVtblAssignHelperAvailability(w, implSurfaceTags, methodTags, true)
    w.writeBlock("public static func ${helperName}${genericDecl}(vtbl: ${vtblName}): ${vtblName}${whereClause}", { =>
        w.writeLine("var next = vtbl")
        writeWinrtImplThunkAssignmentForReceiver(w, index, name, genericParams, sig, methodName, "next")
        w.writeLine("return next")
    })

    w.writeBlankLine()
    writeWinrtVtblAssignHelperAvailability(w, implSurfaceTags, methodTags, false)
    w.writeBlock("public static func ${helperName}${genericDecl}(vtbl: ${vtblName}): ${vtblName}${whereClause}", { =>
        w.writeLine("return vtbl")
    })
}

func writeWinrtVtblAssignHelperAvailability(
    w: CodeWriter,
    implSurfaceTags: ArrayList<String>,
    methodTags: ArrayList<String>,
    positive: Bool
): Unit {
    let surfaceCondition = availabilityCondition("", implSurfaceTags)
    let methodCondition = if (positive) {
        availabilityCondition("", methodTags)
    } else {
        negatedAvailabilityCondition("", methodTags)
    }
    let condition = combineAvailabilityConditionsAsAnd(surfaceCondition, methodCondition)
    if (!condition.isEmpty()) {
        w.writeLine("@When[${condition}]")
    }
}

func combineAvailabilityConditionsAsAnd(left: String, right: String): String {
    if (left.isEmpty()) {
        return right
    }
    if (right.isEmpty()) {
        return left
    }
    return "${wrapAvailabilityConditionOperand(left)} && ${wrapAvailabilityConditionOperand(right)}"
}

func wrapAvailabilityConditionOperand(condition: String): String {
    if (condition.indexOf(" && ", 0).isSome() || condition.indexOf(" || ", 0).isSome()) {
        return "(${condition})"
    }
    return condition
}

func writeWinrtInterfaceVtblMatchesMethod(
    w: CodeWriter,
    index: TypeIndex,
    typeName: String,
    genericParams: ArrayList<String>,
    genericConstraintKinds: HashMap<String, WinrtGenericConstraintKind>,
    ancestors: ArrayList<TypeName>
): Unit {
    let genericDecl = typeGenericDeclaration(genericParams)
    let genericWhere = winrtProjectionWhereClause(genericParams, genericConstraintKinds)
    w.writeLine("public static func matches${genericDecl}(iid: GUID): Bool${genericWhere} {")
    w.indent()
    w.writeLine("if (iid == ${typeName}.iid()) {")
    w.indent()
    w.writeLine("return true")
    w.dedent()
    w.writeLine("}")
    if (!ancestors.isEmpty()) {
        w.writeLine("for (ancestor in ${ancestorIidArrayLiteral(index, ancestors)}) {")
        w.indent()
        w.writeLine("if (ancestor == iid) {")
        w.indent()
        w.writeLine("return true")
        w.dedent()
        w.writeLine("}")
        w.dedent()
        w.writeLine("}")
    }
    w.writeLine("return false")
    w.dedent()
    w.writeLine("}")
}

func writeWinrtInterfaceMatchesMethod(
    w: CodeWriter,
    index: TypeIndex,
    typeName: String,
    ancestors: ArrayList<TypeName>
): Unit {
    writeWinrtMatchesMethod(w, index, typeName, ancestors)
}

func writeWinrtMatchesMethod(
    w: CodeWriter,
    index: TypeIndex,
    typeName: String,
    ancestors: ArrayList<TypeName>
): Unit {
    w.writeLine("public static func matches(iid: GUID): Bool {")
    w.indent()
    w.writeLine("if (iid == ${typeName}.iid()) {")
    w.indent()
    w.writeLine("return true")
    w.dedent()
    w.writeLine("}")
    if (!ancestors.isEmpty()) {
        w.writeLine("for (ancestor in ${ancestorIidArrayLiteral(index, ancestors)}) {")
        w.indent()
        w.writeLine("if (ancestor == iid) {")
        w.indent()
        w.writeLine("return true")
        w.dedent()
        w.writeLine("}")
        w.dedent()
        w.writeLine("}")
    }
    w.writeLine("return false")
    w.dedent()
    w.writeLine("}")
}

func winrtImplMethodDeclaration(
    index: TypeIndex,
    fileIdx: Int64,
    sig: MethodSignature,
    methodName: String,
    pStart: Int64,
    pEnd: Int64
): String {
    let seqToName = parameterNameMap(index, fileIdx, pStart, pEnd)
    let params = winrtImplParameterDecls(index, sig, seqToName)
    return "public func ${methodName}(${joinStrings(params, ", ")}): ${winrtImplReturnType(index, sig.returnType)}"
}

func winrtImplReturnType(index: TypeIndex, ty: MetadataType): String {
    return "windows_core.Result<${winrtPublicReturnType(index, ty)}>"
}

func winrtThunkHelperName(methodName: String): String {
    return "__winrtThunk_${methodName}"
}

func winrtThunkHelperParamDecls(index: TypeIndex, sig: MethodSignature): ArrayList<String> {
    let params = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(elem) =>
                params.add("arg${i}Size: UInt32")
                params.add("arg${i}: ${winrtPublicArrayPointerType(index, elem)}")
            case _ =>
                params.add("arg${i}: ${highLevelAbiType(index, sig.paramTypes[i])}")
        }
        i += 1
    }
    if (highLevelHasResult(sig)) {
        match (sig.returnType) {
            case MetadataType.MdArray(elem) =>
                params.add("resultSize__: CPointer<UInt32>")
                params.add("result__: CPointer<${winrtPublicArrayPointerType(index, elem)}>")
            case _ =>
                params.add("result__: CPointer<${highLevelAbiType(index, sig.returnType)}>")
        }
    }
    return params
}

func winrtThunkHelperArgs(sig: MethodSignature): ArrayList<String> {
    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(_) =>
                args.add("arg${i}Size")
                args.add("arg${i}")
            case _ =>
                args.add("arg${i}")
        }
        i += 1
    }
    if (highLevelHasResult(sig)) {
        match (sig.returnType) {
            case MetadataType.MdArray(_) =>
                args.add("resultSize__")
                args.add("result__")
            case _ =>
                args.add("result__")
        }
    }
    return args
}

func writeWinrtImplThunkHelperMethod(
    w: CodeWriter,
    index: TypeIndex,
    sig: MethodSignature,
    methodName: String
): Unit {
    writeWinrtImplThunkHelperMethodWithCallExpr(w, index, sig, methodName, winrtImplCallExpr(index, sig, "this",
        methodName))
}

func writeWinrtImplThunkHelperMethodWithCallExpr(
    w: CodeWriter,
    index: TypeIndex,
    sig: MethodSignature,
    methodName: String,
    callExpr: String
): Unit {
    writeWinrtImplThunkHelperMethodWithParamSig(w, index, sig, sig, methodName, callExpr)
}

func writeWinrtImplThunkHelperMethodWithParamSig(
    w: CodeWriter,
    index: TypeIndex,
    sig: MethodSignature,
    paramSig: MethodSignature,
    methodName: String,
    callExpr: String
): Unit {
    let helperName = winrtThunkHelperName(methodName)
    let helperParams = winrtThunkHelperParamDecls(index, paramSig)
    w.writeBlock("public func ${helperName}(${joinStrings(helperParams, ", ")}): Int32", { =>
        writeWinrtImplThunkBody(w, index, sig, callExpr)
    })
}

func winrtImplMethodGenericDeclaration(genericParams: ArrayList<String>): String {
    let params = ArrayList<String>()
    params.add("Identity")
    for (genericParam in genericParams) {
        params.add(genericParam)
    }
    return "<${joinStrings(params, ", ")}>"
}

func winrtImplMethodWhereClause(
    name: String,
    genericParams: ArrayList<String>,
    genericConstraintKinds: HashMap<String, WinrtGenericConstraintKind>
): String {
    let clauses = ArrayList<String>()
    clauses.add("Identity <: ${name}_Impl${typeGenericDeclaration(genericParams)}")
    for (genericParam in genericParams) {
        clauses.add(winrtConstraintClauseForGeneric(genericParam, genericConstraintKinds))
    }
    return " where ${joinStrings(clauses, ", ")}"
}

func winrtImplSurfaceTypeName(index: TypeIndex, typeName: TypeName): String {
    let projectionPath = projectedTypePath(typeName.namespace, trimTick(typeName.name))
    let genericArgs = ArrayList<String>()
    for (generic in typeName.generics) {
        genericArgs.add(metadataTypeToProjectionCj(index, generic))
    }
    if (genericArgs.isEmpty()) {
        return "${projectionPath}_Impl"
    }
    return "${projectionPath}_Impl<${joinStrings(genericArgs, ", ")}>"
}

func typeNameIdentityKey(typeName: TypeName): String {
    return "${typeName.namespace}|${trimTick(typeName.name)}|${typeName.generics.size}"
}

func minimizeImplAncestors(index: TypeIndex, ancestors: ArrayList<TypeName>): ArrayList<TypeName> {
    let _ = index
    let seen = HashMap<String, Bool>()
    let result = ArrayList<TypeName>()
    for (ancestor in ancestors) {
        let key = typeNameIdentityKey(ancestor)
        if (!seen.contains(key)) {
            seen[key] = true
            result.add(ancestor)
        }
    }
    return result
}

func writeWinrtImplThunkAssignment(
    w: CodeWriter,
    index: TypeIndex,
    interfaceName: String,
    genericParams: ArrayList<String>,
    sig: MethodSignature,
    methodName: String
): Unit {
    writeWinrtImplThunkAssignmentForReceiver(w, index, interfaceName, genericParams, sig, methodName, "vtbl")
}

func writeWinrtImplThunkAssignmentForReceiver(
    w: CodeWriter,
    index: TypeIndex,
    interfaceName: String,
    genericParams: ArrayList<String>,
    sig: MethodSignature,
    methodName: String,
    receiver: String
): Unit {
    let _ = genericParams
    let helperName = winrtThunkHelperName(methodName)
    let abiParams = ArrayList<String>()
    abiParams.add("instanceRaw")
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(_) =>
                abiParams.add("arg${i}Size")
                abiParams.add("arg${i}")
            case _ =>
                abiParams.add("arg${i}")
        }
        i += 1
    }
    if (highLevelHasResult(sig)) {
        match (sig.returnType) {
            case MetadataType.MdArray(_) =>
                abiParams.add("resultSize__")
                abiParams.add("result__")
            case _ =>
                abiParams.add("result__")
        }
    }

    w.writeLine("${receiver}.${methodName} = { ${joinStrings(abiParams, ", ")} =>")
    w.indent()
    w.writeLine("match (unsafe { asImplFromRaw<${winrtImplErasedName(interfaceName)}>(instanceRaw) }) {")
    w.indent()
    w.writeLine("case Some(impl) =>")
    w.indent()
    let helperArgs = winrtThunkHelperArgs(sig)
    if (helperArgs.isEmpty()) {
        w.writeLine("impl.${helperName}()")
    } else {
        w.writeLine("impl.${helperName}(${joinStrings(helperArgs, ", ")})")
    }
    w.dedent()
    w.writeLine("case None =>")
    w.indent()
    w.writeLine("E_NOINTERFACE.value")
    w.dedent()
    w.dedent()
    w.writeLine("}")
    w.dedent()
    w.writeLine("}")
}

func writeWinrtImplThunkBody(
    w: CodeWriter,
    index: TypeIndex,
    sig: MethodSignature,
    callExpr: String
): Unit {
    if (highLevelHasResult(sig)) {
        match (sig.returnType) {
            case MetadataType.MdArray(_) =>
                w.writeLine("if (resultSize__.isNull() || result__.isNull()) {")
                w.indent()
                w.writeLine("return E_POINTER.value")
                w.dedent()
                w.writeLine("}")
            case _ =>
                w.writeLine("if (result__.isNull()) {")
                w.indent()
                w.writeLine("return E_POINTER.value")
                w.dedent()
                w.writeLine("}")
        }
    }
    w.writeLine("match (${callExpr}) {")
    w.indent()
    if (highLevelHasResult(sig)) {
        let resultType = winrtPublicReturnType(index, sig.returnType)
        if (winrtMethodHasArrayReturn(sig)) {
            let elem = match (sig.returnType) {
                case MetadataType.MdArray(inner) => inner
                case _ => MetadataType.Void
            }
            w.writeLine("case Result<${resultType}>.Ok(value) =>")
            w.indent()
            w.writeLine("let (size, data) = value")
            w.writeLine("unsafe { resultSize__.write(size) }")
            w.writeLine("unsafe { result__.write(${winrtArrayThunkBridgeExpr(index, elem, "data")}) }")
            w.writeLine("S_OK.value")
            w.dedent()
        } else {
            match (sig.returnType) {
                case MetadataType.Generic(name, _) =>
                    w.writeLine("case Result<${resultType}>.Ok(value) =>")
                    w.indent()
                    w.writeLine("windows_core.winrtStoreGenericOut<${name}>(result__, value)")
                    w.dedent()
                case _ =>
                    if (winrtMethodHasReferenceReturn(index, sig.returnType)) {
                        w.writeLine("case Result<${resultType}>.Ok(value) =>")
                        w.indent()
                        let rawExpr = highLevelThunkReturnExpr(index, sig.returnType, "value")
                        w.writeLine("let raw = ${rawExpr}")
                        w.writeLine("if (raw.isNull()) {")
                        w.indent()
                        w.writeLine("E_POINTER.value")
                        w.dedent()
                        w.writeLine("} else {")
                        w.indent()
                        w.writeLine("unsafe { result__.write(raw) }")
                        w.writeLine("S_OK.value")
                        w.dedent()
                        w.writeLine("}")
                        w.dedent()
                    } else {
                        w.writeLine("case Result<${resultType}>.Ok(value) =>")
                        w.indent()
                        let writeExpr = highLevelThunkReturnExpr(index, sig.returnType, "value")
                        w.writeLine("unsafe { result__.write(${writeExpr}) }")
                        w.writeLine("S_OK.value")
                        w.dedent()
                    }
            }
        }
        w.writeLine("case Result<${resultType}>.Err(error) =>")
        w.indent()
        w.writeLine("error.code().value")
        w.dedent()
    } else {
        w.writeLine("case Result<Unit>.Ok(_) =>")
        w.indent()
        w.writeLine("S_OK.value")
        w.dedent()
        w.writeLine("case Result<Unit>.Err(error) =>")
        w.indent()
        w.writeLine("error.code().value")
        w.dedent()
    }
    w.dedent()
    w.writeLine("}")
}

func winrtImplCallExpr(index: TypeIndex, sig: MethodSignature, receiver: String, methodName: String): String {
    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(elem) =>
                args.add("arg${i}Size")
                args.add(winrtArrayThunkBridgeExpr(index, elem, "arg${i}"))
            case MetadataType.Generic(name, _) =>
                args.add("windows_core.winrtProjectGenericIn<${name}>(arg${i})")
            case _ =>
                args.add(highLevelThunkParamExpr(index, sig.paramTypes[i], "arg${i}"))
        }
        i += 1
    }
    if (args.isEmpty()) {
        return "${receiver}.${methodName}()"
    }
    return "${receiver}.${methodName}(${joinStrings(args, ", ")})"
}

func winrtInheritedImplCallExpr(
    index: TypeIndex,
    originalSig: MethodSignature,
    substitutedSig: MethodSignature,
    receiver: String,
    methodName: String
): String {
    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(substitutedSig.paramTypes.size)) {
        match (substitutedSig.paramTypes[i]) {
            case MetadataType.MdArray(elem) =>
                args.add("arg${i}Size")
                args.add(winrtArrayThunkBridgeExpr(index, elem, "arg${i}"))
            case _ =>
                match (originalSig.paramTypes[i]) {
                    case MetadataType.Generic(_, _) =>
                        args.add(
                            "windows_core.winrtProjectGenericIn<${highLevelType(index, substitutedSig.paramTypes[i])}>(arg${i})")
                    case _ =>
                        args.add(highLevelThunkParamExpr(index, substitutedSig.paramTypes[i], "arg${i}"))
                }
        }
        i += 1
    }
    if (args.isEmpty()) {
        return "${receiver}.${methodName}()"
    }
    return "${receiver}.${methodName}(${joinStrings(args, ", ")})"
}

func winrtGenericInputBorrowName(index: Int64): String {
    return "__genericBorrow${index}"
}

func indentPrefix(level: Int64): String {
    var prefix = ""
    var i: Int64 = 0
    while (i < level) {
        prefix += "    "
        i += 1
    }
    return prefix
}

func writeWinrtHrCallWithGenericInputs(
    w: CodeWriter,
    callExpr: String,
    genericInputTypes: ArrayList<String>,
    genericInputNames: ArrayList<String>
): Unit {
    if (genericInputTypes.isEmpty()) {
        w.writeLine("    let hr = ${callExpr}")
        return
    }

    w.writeLine("    var hr__: ?Int32 = None")
    var i: Int64 = 0
    while (i < Int64(genericInputTypes.size)) {
        let borrowName = winrtGenericInputBorrowName(i)
        w.writeLine("${indentPrefix(i + 1)}try (${borrowName} = windows_core.winrtBorrowGenericIn<${genericInputTypes[i]}>(${genericInputNames[i]})) {")
        i += 1
    }
    w.writeLine("${indentPrefix(i + 1)}hr__ = Some(${callExpr})")
    while (i > 0) {
        i -= 1
        w.writeLine("${indentPrefix(i + 1)}}")
    }
    w.writeLine("    let hr = match (hr__) {")
    w.writeLine("        case Some(value) => value")
    w.writeLine("        case None => throw IllegalStateException(\"generic WinRT input borrow did not execute\")")
    w.writeLine("    }")
}

func winrtMethodHasReferenceReturn(index: TypeIndex, ty: MetadataType): Bool {
    if (isWinrtStringMetadataType(ty)) {
        return true
    }
    match (ty) {
        case MetadataType.MdObject => true
        case MetadataType.ClassName(_) => true
        case MetadataType.ValueName(tn) => !tn.generics.isEmpty() || isReferenceProjectionType(index, tn)
        case _ => false
    }
}

func writeWinrtDescriptorMethod(
    w: CodeWriter,
    index: TypeIndex,
    name: String,
    typeName: String,
    ancestors: ArrayList<TypeName>
): Unit {
    w.writeLine("public static func descriptor(): InterfaceDescriptor<${typeName}> {")
    // WinRT vtables always derive directly from IInspectable. Required
    // interfaces are reachable via QueryInterface but are NOT inlined in the
    // vtbl, so their IIDs are passed as `extraAncestorIids` rather than as
    // chain bases. This keeps own-method slot indices correct while still
    // allowing QI to succeed for the required-interface contracts.
    let extraAncestorIids = winrtRequiredInterfaceIidArrayLiteral(index, ancestors)
    w.writeLine("    var descriptor = InterfaceDescriptor<${typeName}>(\"${name}\", ${typeName}.iid(), IInspectable.descriptor(), ${extraAncestorIids}, { raw => ${typeName}.fromAbiTake(raw) }, { raw => ${typeName}.viewOf(raw) })")
    w.writeLine("    descriptor.runtimeTypeContract = Some(${typeName}.runtimeType())")
    w.writeLine("    return descriptor")
    w.writeLine("}")
}

func writeWinrtDescriptorSchemaMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    name: String,
    typeName: String,
    vtblName: String,
    ancestors: ArrayList<TypeName>,
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>
): Unit {
    w.writeLine("public static func descriptorSchema(): InterfaceDescriptorSchema {")
    let extraAncestorIids = winrtRequiredInterfaceIidArrayLiteral(index, ancestors)
    let extraAncestorNames = winrtRequiredInterfaceNameArrayLiteral(ancestors)
    let directBaseSchema = winrtDirectBaseSchemaCall(index, fileIdx, row)
    w.writeLine("    var schema = InterfaceDescriptorSchema(\"${name}\", ${typeName}.iid(), ${directBaseSchema}, ${extraAncestorNames}, ${extraAncestorIids}, \"${vtblName}\", \"${name}\", \"${name}_Impl\", ${methodSchemaArrayLiteral(index, fileIdx, row, methodNames, genericsArray)})")
    w.writeLine("    schema.runtimeTypeContract = Some(${typeName}.runtimeType())")
    w.writeLine("    return schema")
    w.writeLine("}")
}

// Build a Cangjie array literal of the IIDs of all required interfaces for a
// WinRT interface (recursively, deduplicated). IInspectable / IUnknown are
// excluded because they are already represented by the directBase descriptor
// chain rooted at IInspectable.
func winrtRequiredInterfaceIidArrayLiteral(index: TypeIndex, ancestors: ArrayList<TypeName>): String {
    let items = ArrayList<String>()
    let seen = HashMap<String, Bool>()
    for (ancestor in ancestors) {
        let leaf = trimTick(ancestor.name)
        if (leaf == "IInspectable" || leaf == "IUnknown") {
            continue
        }
        let projection = typeNameToProjectionCj(index, ancestor)
        let entry = "${projection}.iid()"
        if (!seen.contains(entry)) {
            seen[entry] = true
            items.add(entry)
        }
    }
    if (items.isEmpty()) {
        return "Array<GUID>()"
    }
    return "[${joinStrings(items, ", ")}]"
}

// Build a Cangjie array literal of the leaf names of all required interfaces
// for a WinRT interface (recursively, deduplicated). IInspectable / IUnknown
// are excluded for the same reason as above.
func winrtRequiredInterfaceNameArrayLiteral(ancestors: ArrayList<TypeName>): String {
    let items = ArrayList<String>()
    let seen = HashMap<String, Bool>()
    for (ancestor in ancestors) {
        let leaf = trimTick(ancestor.name)
        if (leaf == "IInspectable" || leaf == "IUnknown") {
            continue
        }
        if (!seen.contains(leaf)) {
            seen[leaf] = true
            items.add("\"${leaf}\"")
        }
    }
    if (items.isEmpty()) {
        return "Array<String>()"
    }
    return "[${joinStrings(items, ", ")}]"
}

func writeWinrtSignatureMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    genericParams: ArrayList<String>,
    isDelegate: Bool
): Unit {
    match (guidAttributeText(index, fileIdx, row)) {
        case Some(guidText) =>
            if (genericParams.isEmpty()) {
                if (isDelegate) {
                    w.writeLine("public static func signature(): String {")
                    w.writeLine("    \"delegate({${guidText}})\"")
                    w.writeLine("}")
                } else {
                    w.writeLine("public static func signature(): String {")
                    w.writeLine("    \"{${guidText}}\"")
                    w.writeLine("}")
                }
                return
            }

            w.writeLine("public static func signature(): String {")
            w.writeLine("    var sb = StringBuilder()")
            w.writeLine("    sb.append(\"pinterface({${guidText}}\")")
            for (genericParam in genericParams) {
                w.writeLine("    sb.append(\";\")")
                w.writeLine("    sb.append(${genericParam}.signature())")
            }
            w.writeLine("    sb.append(\")\")")
            w.writeLine("    return sb.toString()")
            w.writeLine("}")
        case None =>
            let fallback = if (isDelegate) {
                delegateRuntimeSignature(index, fileIdx, row, ArrayList<MetadataType>())
            } else {
                interfaceRuntimeSignature(index, fileIdx, row, ArrayList<MetadataType>())
            }
            w.writeLine("public static func signature(): String {")
            w.writeLine("    \"${fallback}\"")
            w.writeLine("}")
    }
}

func writeWinrtIidMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    typeName: String,
    genericParams: ArrayList<String>
): Unit {
    if (genericParams.isEmpty()) {
        writeIidMethod(w, index, fileIdx, row)
        return
    }

    w.writeLine("public static func iid(): GUID {")
    w.writeLine("    return GUID.from_signature(${typeName}.signature())")
    w.writeLine("}")
}

func methodSchemaArrayLiteral(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>
): String {
    let items = ArrayList<String>()
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var slot: Int64 = abiSlotStartForType(index, fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
        let parameters = ArrayList<String>()
        let (pStart, pEnd) = index.methodDefParams(fileIdx, methodRow)
        let names = parameterNameMap(index, fileIdx, pStart, pEnd)
        var paramIndex: Int64 = 0
        while (paramIndex < Int64(sig.paramTypes.size)) {
            let publicType = highLevelType(index, sig.paramTypes[paramIndex])
            let abiType = highLevelAbiType(index, sig.paramTypes[paramIndex])
            let bridgeKind = if (highLevelNeedsInParam(index, sig.paramTypes[paramIndex])) {
                "InterfaceParameterBridgeKind.InParam"
            } else {
                "InterfaceParameterBridgeKind.Value"
            }
            let callerType = if (bridgeKind == "InterfaceParameterBridgeKind.InParam") {
                "InParam<${escapeString(publicType)}>"
            } else {
                escapeString(publicType)
            }
            let paramName = if (names.contains(paramIndex + 1)) {
                names[paramIndex + 1]
            } else {
                "arg${paramIndex}"
            }
            parameters.add("InterfaceParameterSchema(\"${paramName}\", \"${escapeString(abiType)}\", \"${callerType}\", ${bridgeKind})")
            paramIndex += 1
        }
        if (highLevelHasResult(sig)) {
            parameters.add(
                "InterfaceParameterSchema(\"result\", \"${escapeString("CPointer<${highLevelAbiType(index, sig.returnType)}>")}\", \"${escapeString("OutSlot<${highLevelType(index, sig.returnType)}>")}\", InterfaceParameterBridgeKind.OutSlot)"
            )
        }
        let parameterLiteral = if (parameters.isEmpty()) {
            "Array<InterfaceParameterSchema>()"
        } else {
            "[${joinStrings(parameters, ", ")}]"
        }
        let literal = "InterfaceMethodSchema(\"${methodNames[methodRow]}\", ${slot}, ${parameterLiteral}, \"Int32\")"
        items.add(literal)
        slot += 1
        methodRow += 1
    }
    return "[${joinStrings(items, ", ")}]"
}

func parameterNameMap(
    index: TypeIndex,
    fileIdx: Int64,
    pStart: Int64,
    pEnd: Int64
): HashMap<Int64, String> {
    let result = HashMap<Int64, String>()
    var paramRow = pStart
    while (paramRow < pEnd) {
        let seq = Int64(index.paramSequence(fileIdx, paramRow))
        if (seq > 0) {
            let paramName = index.paramName(fileIdx, paramRow)
            if (!paramName.isEmpty()) {
                result[seq] = sanitizeIdentifier(paramName)
            }
        }
        paramRow += 1
    }
    result
}

func abiSlotStartForType(index: TypeIndex, fileIdx: Int64, row: Int64): Int64 {
    // The schema's `abiSlot` is an absolute vtbl index that downstream
    // consumers use to dispatch through the runtime. Per WinRT ABI the
    // own-method region of an interface starts at slot 6 (IUnknown's
    // QI/AddRef/Release followed by IInspectable's GetIids /
    // GetRuntimeClassName / GetTrustLevel) PLUS the cumulative own-method
    // count of every direct base interface in the required-interface
    // chain. Consumers walking the schema rely on the absolute slot, so
    // chains like IAsyncAction -> IAsyncInfo must offset by IAsyncInfo's 5
    // own methods (giving slot 11 for the first IAsyncAction method).
    let visited = HashMap<String, Bool>()
    return 6 + winrtDirectBaseChainOwnMethodCount(index, fileIdx, row, visited)
}

// Walk the first required-interface chain starting at (fileIdx, row) and
// sum the own-method count of every base interface encountered. Recursion
// follows `winmdFirstInterfaceType` so the chain matches the metadata
// writer's notion of the "direct base" (the first entry in InterfaceImpl,
// excluding IUnknown / IInspectable).
func winrtDirectBaseChainOwnMethodCount(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    visited: HashMap<String, Bool>
): Int64 {
    match (winmdFirstInterfaceType(index, fileIdx, row)) {
        case Some(baseType) =>
            let key = baseType.definition().toString()
            if (visited.contains(key)) {
                return 0
            }
            visited[key] = true
            let candidates = index.get(baseType.definition())
            if (candidates.isEmpty()) {
                return 0
            }
            let entry = candidates[0]
            let (mStart, mEnd) = index.typeDefMethods(entry.fileIdx, entry.row)
            let ownCount = mEnd - mStart
            return ownCount + winrtDirectBaseChainOwnMethodCount(index, entry.fileIdx, entry.row, visited)
        case None => 0
    }
}

// Return the Cangjie expression that yields the schema of the direct base
// interface (the first required interface). When the interface only
// derives from IInspectable, fall back to `IInspectable.descriptorSchema()`.
func winrtDirectBaseSchemaCall(index: TypeIndex, fileIdx: Int64, row: Int64): String {
    match (winmdFirstInterfaceType(index, fileIdx, row)) {
        case Some(baseType) => "${typeNameToProjectionCj(index, baseType)}.descriptorSchema()"
        case None => "IInspectable.descriptorSchema()"
    }
}

func ancestorIidArrayLiteral(index: TypeIndex, ancestors: ArrayList<TypeName>): String {
    let items = ArrayList<String>()
    for (ancestor in ancestors) {
        items.add("${typeNameToProjectionCj(index, ancestor)}.iid()")
    }
    items.add("IInspectable.iid()")
    items.add("IUnknown.iid()")
    let unique = ArrayList<String>()
    let seen = HashMap<String, Bool>()
    for (item in items) {
        if (!seen.contains(item)) {
            seen[item] = true
            unique.add(item)
        }
    }
    return "[${joinStrings(unique, ", ")}]"
}

func ancestorInterfaceNameArrayLiteral(ancestors: ArrayList<TypeName>): String {
    let items = ArrayList<String>()
    let seen = HashMap<String, Bool>()
    for (ancestor in ancestors) {
        let name = trimTick(ancestor.name)
        if (!seen.contains(name)) {
            seen[name] = true
            items.add("\"${name}\"")
        }
    }
    return "[${joinStrings(items, ", ")}]"
}

func generateWinrtVtblEntry(index: TypeIndex, sig: MethodSignature): String {
    let params = ArrayList<String>()
    params.add("CPointer<Unit>")
    for (paramType in sig.paramTypes) {
        match (paramType) {
            case MetadataType.MdArray(elem) =>
                // WinRT array ABI: size param + data pointer param
                params.add("UInt32")
                params.add(winrtPublicArrayPointerType(index, elem))
            case _ =>
                params.add(highLevelAbiType(index, paramType))
        }
    }
    if (highLevelHasResult(sig)) {
        match (sig.returnType) {
            case MetadataType.MdArray(elem) =>
                // WinRT array return ABI: out-size pointer + out-data pointer
                params.add("CPointer<UInt32>")
                params.add("CPointer<${winrtPublicArrayPointerType(index, elem)}>")
            case _ =>
                params.add("CPointer<${highLevelAbiType(index, sig.returnType)}>")
        }
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> Int32>"
}

func winrtVtblEntryDefault(index: TypeIndex, sig: MethodSignature): String {
    let params = ArrayList<String>()
    params.add("_")
    for (paramType in sig.paramTypes) {
        match (paramType) {
            case MetadataType.MdArray(_) =>
                // size + data pointer
                params.add("_")
                params.add("_")
            case _ =>
                params.add("_")
        }
    }
    if (highLevelHasResult(sig)) {
        match (sig.returnType) {
            case MetadataType.MdArray(_) =>
                // out-size pointer + out-data pointer
                params.add("_")
                params.add("_")
            case _ =>
                params.add("_")
        }
    }
    let paramNames = joinStrings(params, ", ")
    return "{ ${paramNames} => E_NOTIMPL.value }"
}

func writeWinrtWrapperMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    interfaceName: String,
    genericParams: ArrayList<String>,
    sig: MethodSignature,
    methodName: String,
    pStart: Int64,
    pEnd: Int64
): Unit {
    let seqToName = parameterNameMap(index, fileIdx, pStart, pEnd)
    let params = winrtPublicParameterDecls(index, sig, seqToName)
    let returnType = winrtPublicReturnType(index, sig.returnType)
    let paramText = joinStrings(params, ", ")
    let bridgedArgs = ArrayList<String>()
    let genericInputTypes = ArrayList<String>()
    let genericInputNames = ArrayList<String>()
    var genericReturnName = ""
    match (sig.returnType) {
        case MetadataType.Generic(name, _) => genericReturnName = name
        case _ => ()
    }
    var singleUInt32Arg = ""
    var genericInputCount: Int64 = 0
    var singleGenericInputType = ""
    var singleGenericInputName = ""
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        let seq = i + 1
        let paramName = if (seqToName.contains(seq)) {
            seqToName[seq]
        } else {
            "param${i}"
        }
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(elem) =>
                bridgedArgs.add("${paramName}Size")
                bridgedArgs.add(winrtArrayThunkBridgeExpr(index, elem, paramName))
            case MetadataType.Generic(name, _) =>
                if (genericInputCount == 0) {
                    singleGenericInputType = name
                    singleGenericInputName = paramName
                }
                genericInputTypes.add(name)
                genericInputNames.add(paramName)
                bridgedArgs.add("${winrtGenericInputBorrowName(genericInputCount)}.asRaw()")
                genericInputCount += 1
            case _ =>
                match (sig.paramTypes[i]) {
                    case MetadataType.U32 =>
                        if (Int64(sig.paramTypes.size) == 1) {
                            singleUInt32Arg = paramName
                        }
                    case _ => ()
                }
                bridgedArgs.add(highLevelArgumentExpr(index, sig.paramTypes[i], paramName))
        }
        i += 1
    }

    if (genericReturnName.isEmpty()) {
        let argText = joinStrings(bridgedArgs, ", ")
        let slotCall = if (argText.isEmpty()) {
            "v.${methodName}(asRaw())"
        } else {
            "v.${methodName}(asRaw(), ${argText})"
        }
        if (returnType == "Unit") {
            w.writeLine("public unsafe func ${methodName}(${paramText}): Unit {")
            w.writeLine("    let v = vtbl()")
            writeWinrtHrCallWithGenericInputs(w, slotCall, genericInputTypes, genericInputNames)
            w.writeLine("    HRESULT(hr).ok()")
            w.writeLine("}")
            return
        }

        if (winrtMethodHasArrayReturn(sig)) {
            let arrayPointerType = match (sig.returnType) {
                case MetadataType.MdArray(elem) => winrtPublicArrayPointerType(index, elem)
                case _ => "CPointer<Unit>"
            }
            w.writeLine("public unsafe func ${methodName}(${paramText}): ${returnType} {")
            w.writeLine("    let v = vtbl()")
            w.writeLine("    var resultSize__: UInt32 = 0u32")
            w.writeLine("    var result__: ${arrayPointerType} = ${highLevelResultDefaultExpr(arrayPointerType)}")
            let arrayCall = if (argText.isEmpty()) {
                "v.${methodName}(asRaw(), CPointer<UInt32>(inout resultSize__), CPointer<${arrayPointerType}>(inout result__))"
            } else {
                "v.${methodName}(asRaw(), ${argText}, CPointer<UInt32>(inout resultSize__), CPointer<${arrayPointerType}>(inout result__))"
            }
            writeWinrtHrCallWithGenericInputs(w, arrayCall, genericInputTypes, genericInputNames)
            w.writeLine("    HRESULT(hr).ok()")
            w.writeLine("    return (resultSize__, result__)")
            w.writeLine("}")
            return
        }

        w.writeLine("public unsafe func ${methodName}(${paramText}): ${returnType} {")
        w.writeLine("    let v = vtbl()")
        let slotReturnType = highLevelAbiType(index, sig.returnType)
        w.writeLine("    var result__ = ${highLevelResultDefaultExpr(slotReturnType)}")
        let resultCall = if (argText.isEmpty()) {
            "v.${methodName}(asRaw(), CPointer<${slotReturnType}>(inout result__))"
        } else {
            "v.${methodName}(asRaw(), ${argText}, CPointer<${slotReturnType}>(inout result__))"
        }
        writeWinrtHrCallWithGenericInputs(w, resultCall, genericInputTypes, genericInputNames)
        w.writeLine("    HRESULT(hr).ok()")
        w.writeLine("    return ${highLevelReturnExpr(index, sig.returnType, "result__")}")
        w.writeLine("}")
        return
    }

    w.writeLine("public unsafe func ${methodName}(${paramText}): ${returnType} {")
    w.writeLine("    let v = vtbl()")
    if (Int64(sig.paramTypes.size) == 0) {
        w.writeLine("    return windows_core.winrtCallGenericOut<${genericReturnName}>(v.${methodName}, asRaw())")
    } else if (Int64(sig.paramTypes.size) == 1 && !singleUInt32Arg.isEmpty()) {
        w.writeLine("    return windows_core.winrtCallGenericOutAfterUInt32<${genericReturnName}>(v.${methodName}, asRaw(), ${singleUInt32Arg})")
    } else if (Int64(sig.paramTypes.size) == 1 && genericInputCount == 1) {
        w.writeLine(
            "    return windows_core.winrtCallGenericOutFromGenericInput<${genericReturnName}, ${singleGenericInputType}>(v.${methodName}, asRaw(), ${singleGenericInputName})")
    } else {
        w.writeLine("    throw IllegalStateException(\"generic WinRT method '${methodName}' is not supported yet\")")
    }
    w.writeLine("}")
}

func writeInterfaceIteratorProjectionMembers(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String,
    name: String,
    genericParams: ArrayList<String>,
    ancestors: ArrayList<TypeName>
): Unit {
    if (genericParams.size == 1 && isIteratorProjectionSource(namespace, name)) {
        let itemType = genericParams[0]
        w.writeBlankLine()
        w.writeLine("public func intoIterator(): Iterator<${itemType}> {")
        w.writeLine("    IIteratorIterator<${itemType}>(asRaw())")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func iterator(): Iterator<${itemType}> {")
        w.writeLine("    intoIterator()")
        w.writeLine("}")
        return
    }

    if (genericParams.size == 1 && isIterableProjectionSource(namespace, name)) {
        let itemType = genericParams[0]
        w.writeBlankLine()
        w.writeLine("public func intoIterator(): Iterator<${itemType}> {")
        w.writeLine("    IIteratorIterator<${itemType}>(unsafe { First() })")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func iterator(): Iterator<${itemType}> {")
        w.writeLine("    intoIterator()")
        w.writeLine("}")
        return
    }

    match (iterableProjectionItemType(index, ancestors)) {
        case Some(itemType) =>
            w.writeBlankLine()
            w.writeLine("public func intoIterator(): Iterator<${itemType}> {")
            w.writeLine("    asIIterable().intoIterator()")
            w.writeLine("}")
            w.writeBlankLine()
            w.writeLine("public func iterator(): Iterator<${itemType}> {")
            w.writeLine("    intoIterator()")
            w.writeLine("}")
        case None => ()
    }
}

func writeIIteratorIteratorAdapter(w: CodeWriter, itemType: String): Unit {
    w.writeBlock("public class IIteratorIterator<${itemType}> <: Iterator<${itemType}> where ${itemType} <: windows_core.RuntimeType & windows_core.WinrtGenericType<${itemType}>", { =>
        w.writeLine("private let source_: IIterator<${itemType}>")
        w.writeBlankLine()
        w.writeLine("public init(raw: CPointer<Unit>) {")
        w.writeLine("    this.source_ = IIterator<${itemType}>.viewOf(raw)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public init(source: IIterator<${itemType}>) {")
        w.writeLine("    this.source_ = source")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func next(): Option<${itemType}> {")
        w.writeLine("    if (!unsafe { source_.HasCurrent() }) {")
            w.writeLine("        return None")
        w.writeLine("    }")
        w.writeLine("    match (unsafe { source_.Current() } as ${itemType}) {")
        w.writeLine("        case Some(current) =>")
        w.writeLine("            let _ = unsafe { source_.MoveNext() }")
        w.writeLine("            return Some(current)")
        w.writeLine("        case None =>")
        w.writeLine("            return None")
        w.writeLine("    }")
        w.writeLine("}")
    })
}

func iterableProjectionItemType(index: TypeIndex, interfaces: ArrayList<TypeName>): Option<String> {
    for (iface in interfaces) {
        if (iface.definitionMatches("Windows.Foundation.Collections", "IIterable") && !iface.generics.isEmpty()) {
            return Some(metadataTypeToProjectionCj(index, iface.generics[0]))
        }
    }
    return None
}

func isIteratorProjectionSource(namespace: String, name: String): Bool {
    return namespace == "Windows.Foundation.Collections" && name == "IIterator"
}

func isIterableProjectionSource(namespace: String, name: String): Bool {
    return namespace == "Windows.Foundation.Collections" && name == "IIterable"
}

func typeGenericParameterNames(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<String> {
    let result = ArrayList<String>()
    let (gpStart, gpEnd) = index.typeDefGenericParams(fileIdx, row)
    var gpRow = gpStart
    while (gpRow < gpEnd) {
        result.add(index.genericParamName(fileIdx, gpRow))
        gpRow += 1
    }
    return result
}

func rowGenericStart(index: TypeIndex, fileIdx: Int64, row: Int64): Int64 {
    let (gpStart, _) = index.typeDefGenericParams(fileIdx, row)
    return gpStart
}

func rowGenericEnd(index: TypeIndex, fileIdx: Int64, row: Int64): Int64 {
    let (_, gpEnd) = index.typeDefGenericParams(fileIdx, row)
    return gpEnd
}

func typeGenericDeclaration(genericParams: ArrayList<String>): String {
    if (genericParams.isEmpty()) {
        return ""
    }
    return "<${joinStrings(genericParams, ", ")}>"
}

func typedProjectionName(name: String, genericParams: ArrayList<String>): String {
    return "${name}${typeGenericDeclaration(genericParams)}"
}

func runtimeTypeWhereClause(genericParams: ArrayList<String>): String {
    if (genericParams.isEmpty()) {
        return ""
    }

    let clauses = ArrayList<String>()
    for (genericParam in genericParams) {
        clauses.add("${genericParam} <: windows_core.RuntimeType")
    }
    return " where ${joinStrings(clauses, ", ")}"
}

func winrtProjectionWhereClause(
    genericParams: ArrayList<String>,
    genericConstraintKinds: HashMap<String, WinrtGenericConstraintKind>
): String {
    if (genericParams.isEmpty()) {
        return ""
    }

    let clauses = ArrayList<String>()
    for (genericParam in genericParams) {
        clauses.add(winrtConstraintClauseForGeneric(genericParam, genericConstraintKinds))
    }
    return " where ${joinStrings(clauses, ", ")}"
}

func firstInterfaceType(index: TypeIndex, fileIdx: Int64, row: Int64): Option<TypeName> {
    let direct = directInterfaceTypes(index, fileIdx, row)
    if (direct.isEmpty()) {
        return None
    }
    return Some(direct[0])
}

func collectInterfaceAncestors(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let seen = HashMap<String, Bool>()
    for (iface in directInterfaceTypes(index, fileIdx, row)) {
        collectInterfaceAncestorsFromType(index, iface, result, seen)
    }
    return result
}

func collectInterfaceAncestorsFromType(
    index: TypeIndex,
    iface: TypeName,
    result: ArrayList<TypeName>,
    seen: HashMap<String, Bool>
): Unit {
    let key = "${iface.namespace}|${trimTick(iface.name)}|${iface.generics.size}"
    if (seen.contains(key)) {
        return
    }
    seen[key] = true
    result.add(iface)

    let candidates = index.get(iface.namespace, trimTick(iface.name))
    if (candidates.isEmpty()) {
        return
    }
    let (ifaceFileIdx, ifaceRow) = candidates[0]
    for (baseType in directInterfaceTypes(index, ifaceFileIdx, ifaceRow)) {
        collectInterfaceAncestorsFromType(index, baseType, result, seen)
    }
}

func directInterfaceTypes(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = iiStart
    while (ii < iiEnd) {
        let ifaceValue = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
        match (decodeTypeDefOrRefTypeName(index, fileIdx, ifaceValue)) {
            case Some(typeName) =>
                let leaf = trimTick(typeName.name)
                if (leaf != "IUnknown" && leaf != "IInspectable") {
                    result.add(typeName)
                }
            case None => ()
        }
        ii += 1
    }
    return result
}
