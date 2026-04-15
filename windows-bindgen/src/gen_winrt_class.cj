package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.winmd.*

public func generateWinrtClass(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String,
    config: BindgenConfig
): Unit {
    let _ = config
    let name = trimTick(index.typeDefName(fileIdx, row))
    let feature = namespaceToFeature(namespace)
    let arches = index.arches(TABLE_TYPE_DEF, fileIdx, row)
    let genericParams = winmdTypeGenericParameterNames(index, fileIdx, row)
    let genericDecl = typeGenericDeclaration(genericParams)
    let genericWhere = runtimeTypeWhereClause(genericParams)
    let typeName = typedProjectionName(name, genericParams)
    let runtimeName = "${namespace}.${name}"
    let defaultInterface = winmdDefaultClassInterfaceType(index, fileIdx, row)
    let interfaces = collectClassInterfaces(index, fileIdx, row)
    let publicInterfaces = filterPublicClassInterfaces(index, interfaces, defaultInterface)
    let factoryInterfaces = collectFactoryInterfaces(index, fileIdx, row)
    let bases = winmdCollectClassBases(index, fileIdx, row)
    let typeTags = typeAvailabilityTags(namespace, name, fileIdx, row, arches)
    let agile = isAgileType(index, fileIdx, row)
    let hasDefaultConstructor = hasDefaultActivatableConstructor(index, fileIdx, row)

    useSupportSymbol("windows_interface", "ComInterface")
    useSupportSymbol("windows_interface", "InterfaceWrapperBase")
    useSupportSymbol("windows_interface", "RuntimeName")
    useSupportSymbol("windows_interface", "RuntimeType")
    useSupportSymbol("windows_interface", "RuntimeTypeContract")
    useSupportSymbol("windows_interface", "InterfaceDescriptor")
    useSupportSymbol("windows_interface", "GUID")
    useSupportSymbol("windows_interface", "IActivationFactory")
    useSupportSymbol("windows_interface", "IInspectable")
    useSupportSymbol("windows_core", "RuntimeType")
    useSupportSymbol("windows_polyfill", "FactoryCache")
    useSupportSymbol("windows_polyfill", "HRESULT")

    match (defaultInterface) {
        case Some(defaultType) =>
            if (genericParams.isEmpty() && isAsyncInterfaceType(defaultType)) {
                let defaultProjection = typeNameToProjectionCj(index, defaultType)
                w.writeBlankLine()
                writeAvailabilityForTags(w, feature, typeTags)
                w.writeLine("public type ${name} = ${defaultProjection}")
                return
            }
        case None => ()
    }

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeBlock("public class ${name}${genericDecl} <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType${genericWhere}", { =>
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
        writeWinrtClassIidMethod(w, index, defaultInterface)
        w.writeBlankLine()
        w.writeLine("public static func runtimeName(): String {")
        w.writeLine("    \"${runtimeName}\"")
        w.writeLine("}")
        w.writeBlankLine()
        match (defaultInterface) {
            case Some(defaultType) =>
                let defaultProjection = typeNameToProjectionCj(index, defaultType)
                w.writeLine("public static func descriptor(): InterfaceDescriptor<${typeName}> {")
                w.writeLine("    let ancestors = ${classAncestorIidArrayLiteral(index, publicInterfaces)}")
                w.writeLine("    return InterfaceDescriptor<${typeName}>(\"${name}\", ${defaultProjection}.iid(), ancestors, { raw => ${typeName}.fromAbiTake(raw) }, { raw => ${typeName}.viewOf(raw) })")
                w.writeLine("}")
                w.writeBlankLine()
                w.writeLine("public func defaultInterface(): ${defaultProjection} {")
                w.writeLine("    ${defaultProjection}.viewOf(asRaw())")
                w.writeLine("}")
            case None =>
                w.writeLine("public static func descriptor(): InterfaceDescriptor<${typeName}> {")
                w.writeLine("    return InterfaceDescriptor<${typeName}>(\"${name}\", GUID(), [IInspectable.iid(), IUnknown.iid()], { raw => ${typeName}.fromAbiTake(raw) }, { raw => ${typeName}.viewOf(raw) })")
                w.writeLine("}")
        }
        w.writeBlankLine()
        w.writeLine("public static func abiType(): String {")
        w.writeLine("    \"CPointer<Unit>\"")
        w.writeLine("}")
        w.writeBlankLine()
        writeWinrtClassSignatureMethod(w, index, fileIdx, row)
        w.writeBlankLine()
        match (defaultInterface) {
            case Some(defaultType) =>
                let defaultProjection = typeNameToProjectionCj(index, defaultType)
                w.writeLine("public static func runtimeType(): RuntimeTypeContract {")
                w.writeLine("    RuntimeTypeContract(\"${runtimeName}\", ${typeName}.signature(), ${defaultProjection}.iid())")
                w.writeLine("}")
            case None =>
                w.writeLine("public static func runtimeType(): RuntimeTypeContract {")
                w.writeLine("    RuntimeTypeContract(\"${runtimeName}\", ${typeName}.signature())")
                w.writeLine("}")
        }
        w.writeBlankLine()
        w.writeLine("public static func activationFactory(): Option<IActivationFactory> {")
        w.writeLine("    windows_interface.getActivationFactoryByName<IActivationFactory>(${typeName}.runtimeName(), IActivationFactory.descriptor()).ok()")
        w.writeLine("}")
        if (agile) {
            w.writeBlankLine()
            w.writeLine("public static func isAgile(): Bool {")
            w.writeLine("    true")
            w.writeLine("}")
        }
        if (hasDefaultConstructor) {
            w.writeBlankLine()
            w.writeLine("public static func new(): ${typeName} {")
            w.writeLine("    try (factory = windows_interface.getActivationFactoryByName<IGenericFactory>(${typeName}.runtimeName(), IGenericFactory.descriptor()).unwrap()) {")
            w.writeLine("        return unsafe { factory.ActivateInstance<${typeName}>(${typeName}.descriptor()).unwrap() }")
            w.writeLine("    }")
            w.writeLine("}")
        }
        w.writeBlankLine()
        w.writeLine("public func asIInspectable(): IInspectable {")
        w.writeLine("    IInspectable.viewOf(asRaw())")
        w.writeLine("}")

        match (defaultInterface) {
            case Some(defaultType) =>
                let defaultProjection = typeNameToProjectionCj(index, defaultType)
                w.writeBlankLine()
                w.writeLine("public func as${trimTick(defaultType.name)}(): ${defaultProjection} {")
                w.writeLine("    ${defaultProjection}(asRaw())")
                w.writeLine("}")
            case None => ()
        }

        for (iface in publicInterfaces) {
            let ifaceLeaf = trimTick(iface.name)
            match (defaultInterface) {
                case Some(defaultType) =>
                    if (iface == defaultType) {
                        continue
                    }
                case None => ()
            }
            let ifaceProjection = typeNameToProjectionCj(index, iface)
            w.writeBlankLine()
            w.writeLine("public func as${ifaceLeaf}(): ${ifaceProjection} {")
            w.writeLine("    ${ifaceProjection}(asRaw())")
            w.writeLine("}")
        }

        for (baseType in bases) {
            let baseLeaf = trimTick(baseType.name)
            let baseProjection = typeNameToProjectionCj(index, baseType)
            w.writeBlankLine()
            w.writeLine("public func as${baseLeaf}(): ${baseProjection} {")
            w.writeLine("    ${baseProjection}(asRaw())")
            w.writeLine("}")
        }

        writeClassIteratorProjectionMembers(w, index, publicInterfaces)

        for (factoryInfo in factoryInterfaces) {
            let factoryProjection = typeNameToProjectionCj(index, factoryInfo.typeName)
            let factoryCandidates = index.get(factoryInfo.typeName.namespace, trimTick(factoryInfo.typeName.name))
            if (factoryCandidates.isEmpty()) {
                continue
            }
            let (factoryFileIdx, factoryRow) = factoryCandidates[0]
            let factoryMethodNames = buildNormalizedMethodNames(index, factoryFileIdx, factoryRow)
            let factoryGenerics = winmdBuildGenericArray(index, factoryFileIdx, winmdRowGenericStart(index, factoryFileIdx, factoryRow), winmdRowGenericEnd(index, factoryFileIdx, factoryRow))
            let (fmStart, fmEnd) = index.typeDefMethods(factoryFileIdx, factoryRow)
            var factoryMethodRow = fmStart
            while (factoryMethodRow < fmEnd) {
                let factoryMethodName = factoryMethodNames[factoryMethodRow]
                let factorySig = index.methodDefSignature(factoryFileIdx, factoryMethodRow, factoryGenerics)
                let (fpStart, fpEnd) = index.methodDefParams(factoryFileIdx, factoryMethodRow)
                let missing = missingMethodDependencies(index, factoryFileIdx, factoryMethodRow, factoryGenerics)
                if (!missing.isEmpty()) {
                    warnMissingMethodDependencies(index, factoryFileIdx, factoryMethodRow, missing)
                    factoryMethodRow += 1
                    continue
                }
                let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, factoryFileIdx, factoryMethodRow)
                w.writeBlankLine()
                if (!methodTags.isEmpty()) {
                    writeAvailabilityForTags(w, "", methodTags)
                }
                writeWinrtClassFactoryMethod(w, index, factoryFileIdx, typeName, factoryProjection, factoryMethodName, factorySig, fpStart, fpEnd)
                factoryMethodRow += 1
            }
        }

        let classMethodNames = MethodNames()
        let emittedMethodNames = HashMap<String, Bool>()
        match (defaultInterface) {
            case Some(defaultType) =>
                writeWinrtClassMethodsForInterface(
                    w,
                    index,
                    namespace,
                    name,
                    defaultType,
                    "defaultInterface()",
                    classMethodNames,
                    emittedMethodNames
                )
            case None => ()
        }

        for (iface in publicInterfaces) {
            match (defaultInterface) {
                case Some(defaultType) =>
                    if (iface == defaultType) {
                        continue
                    }
                case None => ()
            }

            writeWinrtClassMethodsForInterface(
                w,
                index,
                namespace,
                name,
                iface,
                "as${trimTick(iface.name)}()",
                classMethodNames,
                emittedMethodNames
            )
        }
    })
}

func writeWinrtClassIidMethod(
    w: CodeWriter,
    index: TypeIndex,
    defaultInterface: Option<TypeName>
): Unit {
    match (defaultInterface) {
        case Some(defaultType) =>
            let defaultProjection = typeNameToProjectionCj(index, defaultType)
            w.writeLine("public static func iid(): GUID {")
            w.writeLine("    ${defaultProjection}.iid()")
            w.writeLine("}")
        case None =>
            w.writeLine("public static func iid(): GUID {")
            w.writeLine("    GUID()")
            w.writeLine("}")
    }
}

func writeWinrtClassSignatureMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64
): Unit {
    w.writeLine("public static func signature(): String {")
    w.writeLine("    \"${classRuntimeSignature(index, fileIdx, row)}\"")
    w.writeLine("}")
}

func writeWinrtClassMethodsForInterface(
    w: CodeWriter,
    index: TypeIndex,
    namespace: String,
    className: String,
    iface: TypeName,
    accessorExpr: String,
    classMethodNames: MethodNames,
    emittedMethodNames: HashMap<String, Bool>
): Unit {
    let candidates = index.get(iface.namespace, trimTick(iface.name))
    if (candidates.isEmpty()) {
        return
    }

    let (ifaceFileIdx, ifaceRow) = candidates[0]
    let targetMethodNames = buildNormalizedMethodNames(index, ifaceFileIdx, ifaceRow)
    let ifaceGenerics = winmdBuildGenericArray(index, ifaceFileIdx, winmdRowGenericStart(index, ifaceFileIdx, ifaceRow), winmdRowGenericEnd(index, ifaceFileIdx, ifaceRow))
    let (mStart, mEnd) = index.typeDefMethods(ifaceFileIdx, ifaceRow)
    var methodRow = mStart
    while (methodRow < mEnd) {
        let classMethodName = classMethodNames.add(index, ifaceFileIdx, methodRow)
        if (emittedMethodNames.contains(classMethodName)) {
            methodRow += 1
            continue
        }

        let targetMethodName = targetMethodNames[methodRow]
        let sig = index.methodDefSignature(ifaceFileIdx, methodRow, ifaceGenerics)
        let (pStart, pEnd) = index.methodDefParams(ifaceFileIdx, methodRow)
        let missing = missingMethodDependencies(index, ifaceFileIdx, methodRow, ifaceGenerics)
        if (!missing.isEmpty()) {
            warnMissingMethodDependencies(index, ifaceFileIdx, methodRow, missing)
            methodRow += 1
            continue
        }

        emittedMethodNames[classMethodName] = true
        let methodTags = itemAvailabilityTags(TABLE_METHOD_DEF, ifaceFileIdx, methodRow)
        w.writeBlankLine()
        if (!methodTags.isEmpty()) {
            writeAvailabilityForTags(w, "", methodTags)
        }
        writeWinrtClassForwardMethod(w, index, ifaceFileIdx, sig, classMethodName, targetMethodName, accessorExpr, pStart, pEnd)
        methodRow += 1
    }
}

func writeWinrtClassForwardMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    sig: MethodSignature,
    methodName: String,
    targetMethodName: String,
    accessorExpr: String,
    pStart: Int64,
    pEnd: Int64
): Unit {
    let params = ArrayList<String>()
    let args = ArrayList<String>()
    var i: Int64 = 0
    var paramRow = pStart
    while (i < Int64(sig.paramTypes.size)) {
        var paramName = "param${i}"
        if (paramRow < pEnd) {
            let candidate = index.paramName(fileIdx, paramRow)
            if (!candidate.isEmpty()) {
                paramName = sanitizeIdentifier(candidate)
            }
            paramRow += 1
        }
        params.add("${paramName}: ${highLevelType(index, sig.paramTypes[i])}")
        args.add(paramName)
        i += 1
    }

    let returnType = highLevelType(index, sig.returnType)
    let paramText = joinStrings(params, ", ")
    let argText = joinStrings(args, ", ")
    if (returnType == "Unit") {
        w.writeLine("public unsafe func ${methodName}(${paramText}): Unit {")
        if (argText.isEmpty()) {
            w.writeLine("    ${accessorExpr}.${targetMethodName}()")
        } else {
            w.writeLine("    ${accessorExpr}.${targetMethodName}(${argText})")
        }
        w.writeLine("}")
        return
    }

    w.writeLine("public unsafe func ${methodName}(${paramText}): ${returnType} {")
    if (argText.isEmpty()) {
        w.writeLine("    return ${accessorExpr}.${targetMethodName}()")
    } else {
        w.writeLine("    return ${accessorExpr}.${targetMethodName}(${argText})")
    }
    w.writeLine("}")
}

func writeClassIteratorProjectionMembers(
    w: CodeWriter,
    index: TypeIndex,
    interfaces: ArrayList<TypeName>
): Unit {
    match (iterableClassProjectionItemType(index, interfaces)) {
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

func iterableClassProjectionItemType(index: TypeIndex, interfaces: ArrayList<TypeName>): Option<String> {
    for (iface in interfaces) {
        if (iface.definitionMatches("Windows.Foundation.Collections", "IIterable") && !iface.generics.isEmpty()) {
            return Some(metadataTypeToProjectionCj(index, iface.generics[0]))
        }
    }
    return None
}

func defaultClassInterfaceType(index: TypeIndex, fileIdx: Int64, row: Int64): Option<TypeName> {
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = iiStart
    while (ii < iiEnd) {
        if (index.hasAttribute(TABLE_INTERFACE_IMPL, fileIdx, ii, "DefaultAttribute")) {
            let ifaceValue = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
            return decodeTypeDefOrRefTypeName(index, fileIdx, ifaceValue)
        }
        ii += 1
    }
    return None
}

func collectClassInterfaces(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let seen = HashMap<TypeName, Bool>()
    for (iface in winmdCollectInterfaceAncestors(index, fileIdx, row)) {
        if (!seen.contains(iface)) {
            seen[iface] = true
            result.add(iface)
        }
    }

    for (baseType in winmdCollectClassBases(index, fileIdx, row)) {
        let candidates = index.get(baseType.namespace, trimTick(baseType.name))
        if (candidates.isEmpty()) {
            continue
        }
        let (baseFileIdx, baseRow) = candidates[0]
        for (iface in winmdCollectInterfaceAncestors(index, baseFileIdx, baseRow)) {
            if (!seen.contains(iface)) {
                seen[iface] = true
                result.add(iface)
            }
        }
    }

    return result
}

func collectClassBases(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeName> {
    let result = ArrayList<TypeName>()
    let seen = HashMap<TypeName, Bool>()
    var currentFileIdx = fileIdx
    var currentRow = row
    while (true) {
        let file = index.getFile(currentFileIdx)
        let (table, extRow) = index.typeDefExtends(currentFileIdx, currentRow)
        if (table != TABLE_TYPE_DEF && table != TABLE_TYPE_REF) {
            break
        }

        let baseNamespace = if (table == TABLE_TYPE_DEF) {
            file.getString(extRow, TABLE_TYPE_DEF, 2)
        } else {
            file.getString(extRow, TABLE_TYPE_REF, 2)
        }
        let baseName = if (table == TABLE_TYPE_DEF) {
            trimTick(file.getString(extRow, TABLE_TYPE_DEF, 1))
        } else {
            trimTick(file.getString(extRow, TABLE_TYPE_REF, 1))
        }

        if (baseNamespace == "System" && baseName == "Object") {
            break
        }

        let typeName = TypeName(baseNamespace, baseName)
        if (!seen.contains(typeName)) {
            seen[typeName] = true
            result.add(typeName)
        }

        let candidates = index.get(baseNamespace, baseName)
        if (candidates.isEmpty()) {
            break
        }
        let (nextFileIdx, nextRow) = candidates[0]
        currentFileIdx = nextFileIdx
        currentRow = nextRow
    }
    return result
}

func classAncestorIidArrayLiteral(index: TypeIndex, interfaces: ArrayList<TypeName>): String {
    let items = ArrayList<String>()
    for (iface in interfaces) {
        items.add("${typeNameToProjectionCj(index, iface)}.iid()")
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

func writeWinrtClassFactoryMethod(
    w: CodeWriter,
    index: TypeIndex,
    methodFileIdx: Int64,
    typeName: String,
    factoryProjection: String,
    methodName: String,
    sig: MethodSignature,
    pStart: Int64,
    pEnd: Int64
): Unit {
    let seqToName = HashMap<Int64, String>()
    var paramRow = pStart
    while (paramRow < pEnd) {
        let seq = Int64(index.paramSequence(methodFileIdx, paramRow))
        if (seq > 0) {
            let paramName = index.paramName(methodFileIdx, paramRow)
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
        args.add(paramName)
        i += 1
    }

    let paramText = joinStrings(params, ", ")
    let argText = joinStrings(args, ", ")
    let returnType = highLevelType(index, sig.returnType)
    w.writeLine("public static unsafe func ${methodName}(${paramText}): ${returnType} {")
    w.writeLine("    try (factory = windows_interface.getActivationFactoryByName<${factoryProjection}>(${typeName}.runtimeName(), ${factoryProjection}.descriptor()).unwrap()) {")
    if (returnType == "Unit") {
        if (argText.isEmpty()) {
            w.writeLine("        factory.${methodName}()")
        } else {
            w.writeLine("        factory.${methodName}(${argText})")
        }
        w.writeLine("        return ()")
    } else if (argText.isEmpty()) {
        w.writeLine("        return factory.${methodName}()")
    } else {
        w.writeLine("        return factory.${methodName}(${argText})")
    }
    w.writeLine("    }")
    w.writeLine("}")
}
