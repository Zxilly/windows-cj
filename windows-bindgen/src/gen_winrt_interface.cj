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
    let methodNames = buildNormalizedMethodNames(index, fileIdx, row)
    let genericParams = winmdTypeGenericParameterNames(index, fileIdx, row)
    let genericDecl = typeGenericDeclaration(genericParams)
    let genericWhere = runtimeTypeWhereClause(genericParams)
    let typeName = typedProjectionName(name, genericParams)
    let vtblName = "${name}Vtbl"
    let runtimeName = "${namespace}.${name}"
    let baseInterface = winmdFirstInterfaceType(index, fileIdx, row)
    let ancestors = winmdCollectInterfaceAncestors(index, fileIdx, row)
    let isExclusive = index.hasAttribute(TABLE_TYPE_DEF, fileIdx, row, "ExclusiveToAttribute")
    let emitImplSurface = shouldEmitWinrtImplSurface(config, isExclusive)
    let typeTags = typeAvailabilityTags(namespace, name, fileIdx, row, arches)

    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    let genericsArray = winmdBuildGenericArray(index, fileIdx, winmdRowGenericStart(index, fileIdx, row), winmdRowGenericEnd(index, fileIdx, row))

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
    useSupportSymbol("windows_interface", "IUnknownVtbl")
    useSupportSymbol("windows_core", "RuntimeType")
    useSupportSymbol("windows_polyfill", "HRESULT")

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeLine("@C")
    w.writeBlock("public struct ${vtblName}", { =>
        match (baseInterface) {
            case Some(baseType) =>
                let baseName = "${trimTick(baseType.name)}Vtbl"
                w.writeLine("public var base_: ${baseName} = ${baseName}()")
            case None =>
                w.writeLine("public var base_: IInspectableVtbl = IInspectableVtbl()")
        }

        var methodRow = mStart
        while (methodRow < mEnd) {
            let methodName = methodNames[methodRow]
            let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
            let missing = missingMethodDependencies(index, fileIdx, methodRow, genericsArray)
            let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, methodRow)
            if (!methodTags.isEmpty()) {
                writeAvailabilityForTags(w, "", methodTags)
            }
            if (!missing.isEmpty()) {
                warnMissingMethodDependencies(index, fileIdx, methodRow, missing)
                // Degrade to opaque slot when dependencies are unavailable
                w.writeLine("public var ${methodName}: CPointer<Unit> = CPointer<Unit>.null")
            } else {
                let vtblEntry = generateWinrtVtblEntry(index, sig)
                w.writeLine("public var ${methodName}: ${vtblEntry} = ${winrtVtblEntryDefault(index, sig)}")
            }
            methodRow += 1
        }

        w.writeLine("public init() {}")

        if (emitImplSurface) {
            w.writeBlankLine()
            writeWinrtInterfaceVtblNewMethod(w, index, fileIdx, row, name, vtblName, baseInterface, genericParams, methodNames, genericsArray)
            w.writeBlankLine()
            writeWinrtInterfaceVtblMatchesMethod(w, index, typeName, ancestors)
        }
    })

    if (emitImplSurface) {
        w.writeBlankLine()
        writeAvailabilityForTags(w, feature, typeTags)
        writeWinrtInterfaceImplSurface(w, index, fileIdx, row, name, genericParams, genericWhere, ancestors, methodNames, genericsArray)
    }

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
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
        writeIidMethod(w, index, fileIdx, row, name)
        w.writeBlankLine()
        writeWinrtInterfaceMatchesMethod(w, index, typeName, ancestors)
        w.writeBlankLine()
        writeWinrtDescriptorMethod(w, index, name, typeName, baseInterface)
        w.writeBlankLine()
        writeWinrtDescriptorSchemaMethod(w, index, fileIdx, row, name, typeName, vtblName, baseInterface, methodNames, genericsArray)
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
            w.writeLine("public func as${ancestorLeaf}(): ${ancestorProjection} {")
            w.writeLine("    ${ancestorProjection}.viewOf(asRaw())")
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
            writeWinrtWrapperMethod(w, index, fileIdx, sig, methodName, pStart, pEnd)
            methodRow2 += 1
        }

        writeInterfaceIteratorProjectionMembers(w, index, namespace, name, genericParams, ancestors)
    })

    if (isIteratorProjectionSource(namespace, name) && genericParams.size == 1) {
        w.writeBlankLine()
        writeAvailabilityForTags(w, feature, typeTags)
        writeIIteratorIteratorAdapter(w, genericParams[0])
    }
}

func shouldEmitWinrtImplSurface(config: BindgenConfig, isExclusive: Bool): Bool {
    return config.implement || !isExclusive
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
    let inherited = ArrayList<String>()
    for (ancestor in ancestors) {
        inherited.add(winrtImplSurfaceTypeName(index, ancestor))
    }

    let header = if (inherited.isEmpty()) {
        "public interface ${implName}${typeGenericDeclaration(genericParams)}${genericWhere}"
    } else {
        "public interface ${implName}${typeGenericDeclaration(genericParams)} <: ${joinStrings(inherited, " & ")}${genericWhere}"
    }

    w.writeBlock(header, { =>
        let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
        var methodRow = mStart
        while (methodRow < mEnd) {
            let methodName = methodNames[methodRow]
            let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
            let (pStart, pEnd) = index.methodDefParams(fileIdx, methodRow)
            let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, fileIdx, methodRow)
            if (!methodTags.isEmpty()) {
                writeAvailabilityForTags(w, "", methodTags)
            }
            w.writeLine(winrtImplMethodDeclaration(index, fileIdx, sig, methodName, pStart, pEnd))
            methodRow += 1
        }
    })
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
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>
): Unit {
    let genericDecl = winrtImplMethodGenericDeclaration(genericParams)
    let whereClause = winrtImplMethodWhereClause(name, genericParams)
    w.writeLine("public static func new${genericDecl}(offset!: Int64 = 0): ${vtblName}${whereClause} {")
    w.indent()
    w.writeLine("let _ = offset")
    w.writeLine("var vtbl = ${vtblName}()")
    match (baseInterface) {
        case Some(baseType) =>
            w.writeLine("vtbl.base_ = ${winrtBaseVtblBuilderExpr(index, baseType)}")
        case None =>
            w.writeLine("vtbl.base_ = buildIInspectableVtbl()")
    }

    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        let methodName = methodNames[methodRow]
        let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
        writeWinrtImplThunkAssignment(w, index, sig, methodName)
        methodRow += 1
    }

    w.writeLine("return vtbl")
    w.dedent()
    w.writeLine("}")
}

func writeWinrtInterfaceVtblMatchesMethod(
    w: CodeWriter,
    index: TypeIndex,
    typeName: String,
    ancestors: ArrayList<TypeName>
): Unit {
    writeWinrtMatchesMethod(w, index, typeName, ancestors)
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
    let seqToName = HashMap<Int64, String>()
    var paramRow = pStart
    while (paramRow < pEnd) {
        let seq = Int64(index.paramSequence(fileIdx, paramRow))
        if (seq > 0) {
            let paramName = index.paramName(fileIdx, paramRow)
            if (!paramName.isEmpty()) {
                seqToName[seq] = sanitizeIdentifier(paramName)
            }
        }
        paramRow += 1
    }

    let params = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        let seq = i + 1
        let paramName = if (seqToName.contains(seq)) {
            seqToName[seq]
        } else {
            "param${i}"
        }
        let publicType = highLevelType(index, sig.paramTypes[i])
        let paramType = if (highLevelArgumentExpr(index, sig.paramTypes[i], "value") != "value") {
            "InParam<${publicType}>"
        } else {
            publicType
        }
        params.add("${paramName}: ${paramType}")
        i += 1
    }

    return "public func ${methodName}(${joinStrings(params, ", ")}): ${winrtImplReturnType(index, sig.returnType)}"
}

func winrtImplReturnType(index: TypeIndex, ty: MetadataType): String {
    return "windows_core.Result<${highLevelType(index, ty)}>"
}

func winrtImplMethodGenericDeclaration(genericParams: ArrayList<String>): String {
    let params = ArrayList<String>()
    params.add("Identity")
    for (genericParam in genericParams) {
        params.add(genericParam)
    }
    return "<${joinStrings(params, ", ")}>"
}

func winrtImplMethodWhereClause(name: String, genericParams: ArrayList<String>): String {
    let clauses = ArrayList<String>()
    clauses.add("Identity <: ${name}_Impl${typeGenericDeclaration(genericParams)}")
    for (genericParam in genericParams) {
        clauses.add("${genericParam} <: windows_core.RuntimeType")
    }
    return " where ${joinStrings(clauses, ", ")}"
}

func winrtImplSurfaceTypeName(index: TypeIndex, typeName: TypeName): String {
    let genericArgs = ArrayList<String>()
    for (generic in typeName.generics) {
        genericArgs.add(metadataTypeToProjectionCj(index, generic))
    }
    if (genericArgs.isEmpty()) {
        return "${trimTick(typeName.name)}_Impl"
    }
    return "${trimTick(typeName.name)}_Impl<${joinStrings(genericArgs, ", ")}>"
}

func winrtBaseVtblBuilderExpr(index: TypeIndex, typeName: TypeName): String {
    let genericArgs = ArrayList<String>()
    genericArgs.add("Identity")
    for (generic in typeName.generics) {
        genericArgs.add(metadataTypeToProjectionCj(index, generic))
    }
    return "${trimTick(typeName.name)}Vtbl.new<${joinStrings(genericArgs, ", ")}>(offset: offset)"
}

func writeWinrtImplThunkAssignment(
    w: CodeWriter,
    index: TypeIndex,
    sig: MethodSignature,
    methodName: String
): Unit {
    let abiParams = ArrayList<String>()
    abiParams.add("instanceRaw")
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        abiParams.add("arg${i}")
        i += 1
    }
    if (highLevelHasResult(sig)) {
        abiParams.add("result__")
    }

    w.writeLine("vtbl.${methodName} = { ${joinStrings(abiParams, ", ")} =>")
    w.indent()
    if (highLevelHasResult(sig)) {
        w.writeLine("if (result__.isNull()) {")
        w.indent()
        w.writeLine("return E_POINTER.value")
        w.dedent()
        w.writeLine("}")
    }
    w.writeLine("match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {")
    w.indent()
    w.writeLine("case Some(impl) =>")
    w.indent()
    w.writeLine("match (${winrtImplCallExpr(index, sig, methodName)}) {")
    w.indent()
    if (highLevelHasResult(sig)) {
        let resultType = highLevelType(index, sig.returnType)
        if (winrtMethodHasReferenceReturn(index, sig.returnType)) {
            w.writeLine("case Result<${resultType}>.Ok(value) =>")
            w.indent()
            w.writeLine("let raw = ${highLevelThunkReturnExpr(index, sig.returnType, "value")}")
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
            w.writeLine("unsafe { result__.write(${highLevelThunkReturnExpr(index, sig.returnType, "value")}) }")
            w.writeLine("S_OK.value")
            w.dedent()
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

func winrtImplCallExpr(index: TypeIndex, sig: MethodSignature, methodName: String): String {
    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        args.add(highLevelThunkParamExpr(index, sig.paramTypes[i], "arg${i}"))
        i += 1
    }
    if (args.isEmpty()) {
        return "impl.${methodName}()"
    }
    return "impl.${methodName}(${joinStrings(args, ", ")})"
}

func winrtMethodHasReferenceReturn(index: TypeIndex, ty: MetadataType): Bool {
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
    baseInterface: Option<TypeName>
): Unit {
    w.writeLine("public static func descriptor(): InterfaceDescriptor<${typeName}> {")
    match (baseInterface) {
        case Some(baseType) =>
            let baseProjection = typeNameToProjectionCj(index, baseType)
            w.writeLine("    var descriptor = InterfaceDescriptor<${typeName}>(\"${name}\", ${typeName}.iid(), ${baseProjection}.descriptor(), { raw => ${typeName}.fromAbiTake(raw) }, { raw => ${typeName}.viewOf(raw) })")
        case None =>
            w.writeLine("    var descriptor = InterfaceDescriptor<${typeName}>(\"${name}\", ${typeName}.iid(), IInspectable.descriptor(), { raw => ${typeName}.fromAbiTake(raw) }, { raw => ${typeName}.viewOf(raw) })")
    }
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
    baseInterface: Option<TypeName>,
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>
): Unit {
    w.writeLine("public static func descriptorSchema(): InterfaceDescriptorSchema {")
    match (baseInterface) {
        case Some(baseType) =>
            let baseProjection = typeNameToProjectionCj(index, baseType)
            w.writeLine("    var schema = InterfaceDescriptorSchema(\"${name}\", ${typeName}.iid(), ${baseProjection}.descriptorSchema(), \"${vtblName}\", \"${name}\", \"${name}_Impl\", ${methodSchemaArrayLiteral(index, fileIdx, row, methodNames, genericsArray)})")
        case None =>
            w.writeLine("    var schema = InterfaceDescriptorSchema(\"${name}\", ${typeName}.iid(), IInspectable.descriptorSchema(), \"${vtblName}\", \"${name}\", \"${name}_Impl\", ${methodSchemaArrayLiteral(index, fileIdx, row, methodNames, genericsArray)})")
    }
    w.writeLine("    schema.runtimeTypeContract = Some(${typeName}.runtimeType())")
    w.writeLine("    return schema")
    w.writeLine("}")
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
            let bridgeKind = if (highLevelArgumentExpr(index, sig.paramTypes[paramIndex], "value") != "value") {
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
        let literal = "InterfaceMethodSchema(\"${methodNames[methodRow]}\", ${slot}, [${joinStrings(parameters, ", ")}], \"Int32\")"
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
    match (winmdFirstInterfaceType(index, fileIdx, row)) {
        case Some(baseType) =>
            abiSlotExtentForType(index, baseType)
        case None =>
            6
    }
}

func abiSlotExtentForType(index: TypeIndex, typeName: TypeName): Int64 {
    let leaf = trimTick(typeName.name)
    if (leaf == "IUnknown") {
        return 3
    }
    if (leaf == "IInspectable") {
        return 6
    }

    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
    if (candidates.isEmpty()) {
        return 6
    }
    let (baseFileIdx, baseRow) = candidates[0]
    let (mStart, mEnd) = index.typeDefMethods(baseFileIdx, baseRow)
    abiSlotStartForType(index, baseFileIdx, baseRow) + (mEnd - mStart)
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
                params.add("CPointer<${highLevelAbiType(index, elem)}>")
            case _ =>
                params.add(highLevelAbiType(index, paramType))
        }
    }
    if (highLevelHasResult(sig)) {
        match (sig.returnType) {
            case MetadataType.MdArray(elem) =>
                // WinRT array return ABI: out-size pointer + out-data pointer
                params.add("CPointer<UInt32>")
                params.add("CPointer<CPointer<${highLevelAbiType(index, elem)}>>")
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
    sig: MethodSignature,
    methodName: String,
    pStart: Int64,
    pEnd: Int64
): Unit {
    let seqToName = HashMap<Int64, String>()
    var paramRow = pStart
    while (paramRow < pEnd) {
        let seq = Int64(index.paramSequence(fileIdx, paramRow))
        if (seq > 0) {
            let paramName = index.paramName(fileIdx, paramRow)
            if (!paramName.isEmpty()) {
                seqToName[seq] = sanitizeIdentifier(paramName)
            }
        }
        paramRow += 1
    }

    let params = ArrayList<String>()
    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        let seq = i + 1
        let paramName = if (seqToName.contains(seq)) {
            seqToName[seq]
        } else {
            "param${i}"
        }
        params.add("${paramName}: ${highLevelType(index, sig.paramTypes[i])}")
        args.add(highLevelArgumentExpr(index, sig.paramTypes[i], paramName))
        i += 1
    }

    let returnType = highLevelType(index, sig.returnType)
    let paramText = joinStrings(params, ", ")
    let argText = joinStrings(args, ", ")
    if (returnType == "Unit") {
        w.writeLine("public unsafe func ${methodName}(${paramText}): Unit {")
        w.writeLine("    let v = vtbl()")
        if (argText.isEmpty()) {
            w.writeLine("    let hr = v.${methodName}(asRaw())")
        } else {
            w.writeLine("    let hr = v.${methodName}(asRaw(), ${argText})")
        }
        w.writeLine("    HRESULT(hr).ok()")
        w.writeLine("}")
        return
    }

    w.writeLine("public unsafe func ${methodName}(${paramText}): ${returnType} {")
    w.writeLine("    let v = vtbl()")
    let slotReturnType = highLevelAbiType(index, sig.returnType)
    w.writeLine("    var result = ${highLevelResultDefaultExpr(slotReturnType)}")
    if (argText.isEmpty()) {
        w.writeLine("    let hr = v.${methodName}(asRaw(), CPointer<${slotReturnType}>(inout result))")
    } else {
        w.writeLine("    let hr = v.${methodName}(asRaw(), ${argText}, CPointer<${slotReturnType}>(inout result))")
    }
    w.writeLine("    HRESULT(hr).ok()")
    w.writeLine("    return ${highLevelReturnExpr(index, sig.returnType, "result")}")
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
    w.writeBlock("public class IIteratorIterator<${itemType}> <: Iterator<${itemType}> where ${itemType} <: windows_core.RuntimeType", { =>
        w.writeLine("private let source_: IIterator<${itemType}>")
        w.writeBlankLine()
        w.writeLine("public init(raw: CPointer<Unit>) {")
        w.writeLine("    this.source_ = IIterator<${itemType}>.viewOf(raw)")
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
