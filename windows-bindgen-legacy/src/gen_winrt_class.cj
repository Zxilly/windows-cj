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
    let ownTypeTags = typeAvailabilityTags(namespace, name, fileIdx, row, arches)
    let typeTags = ownTypeTags
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
    useSupportSymbol("windows_interface", "IUnknown")
    useSupportSymbol("windows_core", "IGenericFactory")
    useSupportSymbol("windows_core", "RuntimeType")
    useSupportSymbol("windows_core", "HRESULT")
    useSupportSymbol("windows_polyfill", "FactoryCache")

    match (defaultInterface) {
        case Some(defaultType) =>
            if (genericParams.isEmpty() && isAsyncInterfaceType(defaultType)) {
                let defaultProjection = typeNameToProjectionCj(index, defaultType)
                w.writeBlankLine()
                writeAvailabilityForTags(w, feature, typeTags)
                w.writeLine("public type ${name} = ${defaultProjection}")
                return
            }
        case None =>
            writeStaticWinrtClass(
                w,
                index,
                fileIdx,
                row,
                name,
                typeName,
                runtimeName,
                genericDecl,
                genericWhere,
                feature,
                typeTags,
                factoryInterfaces
            )
            return
    }

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeBlock("public class ${name}${genericDecl} <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeName & windows_core.RuntimeType${genericWhere}", { =>
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
                writeWinrtClassQueryAccessor(w, "defaultInterface", defaultProjection)
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
        match (defaultInterface) {
            case Some(defaultType) =>
                writeWinrtClassSignatureMethod(w, index, fileIdx, row)
                w.writeBlankLine()
                let defaultProjection = typeNameToProjectionCj(index, defaultType)
                w.writeLine("public static func runtimeType(): RuntimeTypeContract {")
                w.writeLine("    RuntimeTypeContract(\"${runtimeName}\", ${typeName}.signature(), ${defaultProjection}.iid())")
                w.writeLine("}")
            case None =>
                // No default interface: rely on RuntimeName trait default `signature()` (returns runtimeName())
                // and emit a runtimeType() that uses the bare runtime name on both sides. This matches the
                // "no RuntimeType registration for static-only / non-activatable WinRT classes" contract.
                w.writeLine("public static func runtimeType(): RuntimeTypeContract {")
                w.writeLine("    RuntimeTypeContract(\"${runtimeName}\", \"${runtimeName}\")")
                w.writeLine("}")
        }
        w.writeBlankLine()
        w.writeLine("public static func activationFactory(): Option<IActivationFactory> {")
        w.writeLine("    windows_core.activationFactory<${typeName}>().ok()")
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
            w.writeLine("    var created__: Option<${typeName}> = Option<${typeName}>.None")
            w.writeLine("    try (factory__ = windows_core.factory<${typeName}, IGenericFactory>().unwrap()) {")
            w.writeLine("        created__ = Some(unsafe { factory__.ActivateInstance<${typeName}>(${typeName}.descriptor()).unwrap() })")
            w.writeLine("    }")
            w.writeLine("    match (created__) {")
            w.writeLine("        case Some(value) => return value")
            w.writeLine("        case None => throw IllegalStateException(\"Activation factory did not produce ${typeName}\")")
            w.writeLine("    }")
            w.writeLine("}")
        }
        w.writeBlankLine()
        w.writeLine("public func asIInspectable(): IInspectable {")
        w.writeLine("    IInspectable.viewOf(asRaw())")
        w.writeLine("}")

        let interfaceAccessorNames = HashMap<TypeName, String>()
        let usedAccessorNames = HashMap<String, Bool>()
        usedAccessorNames["asIInspectable"] = true
        match (defaultInterface) {
            case Some(defaultType) =>
                let defaultProjection = typeNameToProjectionCj(index, defaultType)
                let accessorName = winrtClassAsAccessorName(defaultType, usedAccessorNames)
                interfaceAccessorNames[defaultType] = accessorName
                w.writeBlankLine()
                writeWinrtClassQueryAccessor(w, accessorName, defaultProjection)
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
            let ifaceProjection = typeNameToProjectionCj(index, iface)
            let accessorName = winrtClassAsAccessorName(iface, usedAccessorNames)
            interfaceAccessorNames[iface] = accessorName
            w.writeBlankLine()
            writeWinrtClassQueryAccessor(w, accessorName, ifaceProjection)
        }

        for (baseType in bases) {
            let baseProjection = typeNameToProjectionCj(index, baseType)
            let accessorName = winrtClassAsAccessorName(baseType, usedAccessorNames)
            w.writeBlankLine()
            writeWinrtClassQueryAccessor(w, accessorName, baseProjection)
        }

        writeClassIteratorProjectionMembers(w, index, publicInterfaces)

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
                "${interfaceAccessorNames[iface]}()",
                classMethodNames,
                emittedMethodNames
            )
        }

        let emittedFactoryMethodNames = HashMap<String, Bool>()
        for (factoryInfo in factoryInterfaces) {
            let factoryProjection = typeNameToProjectionCj(index, factoryInfo.typeName)
            let factoryCandidates = index.get(factoryInfo.typeName.namespace, trimTick(factoryInfo.typeName.name))
            if (factoryCandidates.isEmpty()) {
                continue
            }
            let (factoryFileIdx, factoryRow) = factoryCandidates[0]
            let factoryTypeTags = winrtClassTypeAvailabilityTags(index, factoryInfo.typeName)
            let factoryGenerics = winmdBuildGenericArray(index, factoryFileIdx, winmdRowGenericStart(index, factoryFileIdx, factoryRow), winmdRowGenericEnd(index, factoryFileIdx, factoryRow))
            let factoryMethodNames = buildWinrtMethodNames(index, factoryFileIdx, factoryRow, factoryGenerics)
            let (fmStart, fmEnd) = index.typeDefMethods(factoryFileIdx, factoryRow)
            var factoryMethodRow = fmStart
            while (factoryMethodRow < fmEnd) {
                let factoryMethodName = factoryMethodNames[factoryMethodRow]
                let emittedFactoryMethodName = disambiguateWinrtClassFactoryMethodName(
                    factoryMethodName,
                    emittedMethodNames,
                    emittedFactoryMethodNames
                )
                let factorySig = index.methodDefSignature(factoryFileIdx, factoryMethodRow, factoryGenerics)
                let (fpStart, fpEnd) = index.methodDefParams(factoryFileIdx, factoryMethodRow)
                let missing = missingMethodDependencies(index, factoryFileIdx, factoryMethodRow, factoryGenerics)
                if (!missing.isEmpty()) {
                    warnMissingMethodDependencies(index, factoryFileIdx, factoryMethodRow, missing)
                    factoryMethodRow += 1
                    continue
                }
                emittedFactoryMethodNames[emittedFactoryMethodName] = true
                let methodTags = mergeAvailabilityTagsAsAnd(
                    itemAvailabilityTags(TABLE_METHOD_DEF, factoryFileIdx, factoryMethodRow),
                    factoryTypeTags
                )
                w.writeBlankLine()
                if (!methodTags.isEmpty()) {
                    writeAvailabilityForTags(w, "", methodTags)
                }
                writeWinrtClassFactoryMethod(
                    w,
                    index,
                    factoryFileIdx,
                    typeName,
                    factoryProjection,
                    emittedFactoryMethodName,
                    factoryMethodName,
                    factorySig,
                    fpStart,
                    fpEnd,
                    factoryInfo.kind
                )
                factoryMethodRow += 1
            }
        }
    })
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeBlock("extend${genericDecl} ${typeName} <: windows_core.HandleWinrtType<${typeName}>${genericWhere}", { =>
        w.writeLine("public static func intoWinrtHandle(value: ${typeName}): CPointer<Unit> {")
        w.writeLine("    value.asRaw()")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func fromAbiTakeWinrtHandle(raw: CPointer<Unit>): ${typeName} {")
        w.writeLine("    if (raw.isNull()) {")
        w.writeLine("        throw windows_core.WindowsException(windows_core.E_POINTER)")
        w.writeLine("    }")
        w.writeLine("    ${typeName}.fromAbiTake(raw)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func viewWinrtHandle(raw: CPointer<Unit>): ${typeName} {")
        w.writeLine("    ${typeName}.viewOf(raw)")
        w.writeLine("}")
    })
}

func writeWinrtClassQueryAccessor(
    w: CodeWriter,
    accessorName: String,
    projection: String
): Unit {
    w.writeLine("public func ${accessorName}(): ${projection} {")
    w.writeLine("    match (unsafe { query(${projection}.descriptor()) }) {")
    w.writeLine("        case Some(value) => value")
    w.writeLine("        case None => throw windows_core.WindowsException(windows_core.E_NOINTERFACE)")
    w.writeLine("    }")
    w.writeLine("}")
}

func winrtClassSurfaceAvailabilityTags(
    index: TypeIndex,
    ownTags: ArrayList<String>,
    defaultInterface: Option<TypeName>,
    publicInterfaces: ArrayList<TypeName>,
    bases: ArrayList<TypeName>
): ArrayList<String> {
    var result = copyAvailabilityTags(ownTags)
    match (defaultInterface) {
        case Some(defaultType) =>
            result = mergeAvailabilityTagsAsAnd(result, winrtClassTypeAvailabilityTags(index, defaultType))
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
        result = mergeAvailabilityTagsAsAnd(result, winrtClassTypeAvailabilityTags(index, iface))
    }
    for (baseType in bases) {
        result = mergeAvailabilityTagsAsAnd(result, winrtClassTypeAvailabilityTags(index, baseType))
    }
    return result
}

func winrtClassTypeAvailabilityTags(index: TypeIndex, typeName: TypeName): ArrayList<String> {
    let candidates = index.get(typeName.namespace, trimTick(typeName.name))
    if (candidates.isEmpty()) {
        return ArrayList<String>()
    }

    let (fileIdx, row) = candidates[0]
    return typeAvailabilityTags(
        typeName.namespace,
        trimTick(typeName.name),
        fileIdx,
        row,
        index.arches(TABLE_TYPE_DEF, fileIdx, row)
    )
}

func mergeAvailabilityTagsAsAnd(first: ArrayList<String>, second: ArrayList<String>): ArrayList<String> {
    if (first.isEmpty()) {
        return copyAvailabilityTags(second)
    }
    if (second.isEmpty()) {
        return copyAvailabilityTags(first)
    }

    let left = availabilityCondition("", first)
    let right = availabilityCondition("", second)
    if (left.isEmpty()) {
        return copyAvailabilityTags(second)
    }
    if (right.isEmpty()) {
        return copyAvailabilityTags(first)
    }
    if (left == right) {
        let same = ArrayList<String>()
        same.add(left)
        return same
    }

    let result = ArrayList<String>()
    result.add("(${left}) && (${right})")
    return result
}

func copyAvailabilityTags(tags: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    for (tag in tags) {
        result.add(tag)
    }
    return result
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

func writeStaticWinrtClass(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    name: String,
    typeName: String,
    runtimeName: String,
    genericDecl: String,
    genericWhere: String,
    feature: String,
    typeTags: ArrayList<String>,
    factoryInterfaces: ArrayList<WinrtFactoryInterface>
): Unit {
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeBlock("public class ${name}${genericDecl} <: windows_interface.RuntimeName & windows_core.RuntimeName${genericWhere}", { =>
        w.writeLine("private init() {}")
        w.writeBlankLine()
        w.writeLine("public static func runtimeName(): String {")
        w.writeLine("    \"${runtimeName}\"")
        w.writeLine("}")
        w.writeBlankLine()
        // Disambiguate signature() and runtimeType() between windows_interface.RuntimeName and
        // windows_core.RuntimeName (both inherit them as defaulted methods). Static-only WinRT
        // classes never carry a default-interface signature, so use the bare runtime name.
        w.writeLine("public static func signature(): String {")
        w.writeLine("    \"${runtimeName}\"")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func runtimeType(): RuntimeTypeContract {")
        w.writeLine("    RuntimeTypeContract(\"${runtimeName}\", \"${runtimeName}\")")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func activationFactory(): Option<IActivationFactory> {")
        w.writeLine("    windows_core.activationFactory<${typeName}>().ok()")
        w.writeLine("}")

        let emittedFactoryMethodNames = HashMap<String, Bool>()
        for (factoryInfo in factoryInterfaces) {
            let factoryProjection = typeNameToProjectionCj(index, factoryInfo.typeName)
            let factoryCandidates = index.get(factoryInfo.typeName.namespace, trimTick(factoryInfo.typeName.name))
            if (factoryCandidates.isEmpty()) {
                continue
            }
            let (factoryFileIdx, factoryRow) = factoryCandidates[0]
            let factoryTypeTags = winrtClassTypeAvailabilityTags(index, factoryInfo.typeName)
            let factoryGenerics = winmdBuildGenericArray(index, factoryFileIdx, winmdRowGenericStart(index, factoryFileIdx, factoryRow), winmdRowGenericEnd(index, factoryFileIdx, factoryRow))
            let factoryMethodNames = buildWinrtMethodNames(index, factoryFileIdx, factoryRow, factoryGenerics)
            let (fmStart, fmEnd) = index.typeDefMethods(factoryFileIdx, factoryRow)
            var factoryMethodRow = fmStart
            while (factoryMethodRow < fmEnd) {
                let factoryMethodName = factoryMethodNames[factoryMethodRow]
                let emittedFactoryMethodName = disambiguateWinrtClassFactoryMethodName(
                    factoryMethodName,
                    HashMap<String, Bool>(),
                    emittedFactoryMethodNames
                )
                let factorySig = index.methodDefSignature(factoryFileIdx, factoryMethodRow, factoryGenerics)
                let (fpStart, fpEnd) = index.methodDefParams(factoryFileIdx, factoryMethodRow)
                let missing = missingMethodDependencies(index, factoryFileIdx, factoryMethodRow, factoryGenerics)
                if (!missing.isEmpty()) {
                    warnMissingMethodDependencies(index, factoryFileIdx, factoryMethodRow, missing)
                    factoryMethodRow += 1
                    continue
                }
                emittedFactoryMethodNames[emittedFactoryMethodName] = true
                let methodTags = mergeAvailabilityTagsAsAnd(
                    itemAvailabilityTags(TABLE_METHOD_DEF, factoryFileIdx, factoryMethodRow),
                    factoryTypeTags
                )
                w.writeBlankLine()
                if (!methodTags.isEmpty()) {
                    writeAvailabilityForTags(w, "", methodTags)
                }
                writeWinrtClassFactoryMethod(
                    w,
                    index,
                    factoryFileIdx,
                    typeName,
                    factoryProjection,
                    emittedFactoryMethodName,
                    factoryMethodName,
                    factorySig,
                    fpStart,
                    fpEnd,
                    factoryInfo.kind
                )
                factoryMethodRow += 1
            }
        }
    })
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
    let ifaceTypeTags = winrtClassTypeAvailabilityTags(index, iface)
    let ifaceGenerics = winmdBuildGenericArray(index, ifaceFileIdx, winmdRowGenericStart(index, ifaceFileIdx, ifaceRow), winmdRowGenericEnd(index, ifaceFileIdx, ifaceRow))
    let targetMethodNames = buildWinrtMethodNames(index, ifaceFileIdx, ifaceRow, ifaceGenerics)
    let (mStart, mEnd) = index.typeDefMethods(ifaceFileIdx, ifaceRow)
    var methodRow = mStart
    while (methodRow < mEnd) {
        let sig = index.methodDefSignature(ifaceFileIdx, methodRow, ifaceGenerics)
        let classSig = substituteMethodSignature(sig, iface.generics)
        let classMethodName = disambiguateWinrtMethodName(index, classMethodNames.add(index, ifaceFileIdx, methodRow), classSig)
        if (emittedMethodNames.contains(classMethodName)) {
            methodRow += 1
            continue
        }

        let targetMethodName = targetMethodNames[methodRow]
        let (pStart, pEnd) = index.methodDefParams(ifaceFileIdx, methodRow)
        let missing = missingMethodDependencies(index, ifaceFileIdx, methodRow, ifaceGenerics)
        if (!missing.isEmpty()) {
            warnMissingMethodDependencies(index, ifaceFileIdx, methodRow, missing)
            methodRow += 1
            continue
        }

        emittedMethodNames[classMethodName] = true
        let methodTags = mergeAvailabilityTagsAsAnd(
            itemAvailabilityTags(TABLE_METHOD_DEF, ifaceFileIdx, methodRow),
            ifaceTypeTags
        )
        w.writeBlankLine()
        if (!methodTags.isEmpty()) {
            writeAvailabilityForTags(w, "", methodTags)
        }
        writeWinrtClassForwardMethod(w, index, ifaceFileIdx, classSig, sig, classMethodName, targetMethodName, accessorExpr, pStart, pEnd)
        methodRow += 1
    }
}

func writeWinrtClassForwardMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    sig: MethodSignature,
    targetSig: MethodSignature,
    methodName: String,
    targetMethodName: String,
    accessorExpr: String,
    pStart: Int64,
    pEnd: Int64
): Unit {
    let seqToName = parameterNameMap(index, fileIdx, pStart, pEnd)
    let params = winrtPublicParameterDecls(index, sig, seqToName)
    let args = ArrayList<String>()
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
                args.add("${paramName}Size")
                match (targetSig.paramTypes[i]) {
                    case MetadataType.MdArray(MetadataType.Generic(_, _)) =>
                        args.add("CPointer<Unit>(${paramName})")
                    case _ =>
                        args.add(paramName)
                }
            case _ =>
                args.add(paramName)
        }
        i += 1
    }
    let returnType = winrtPublicReturnType(index, sig.returnType)
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

    let needsArrayReturnBridge = match (sig.returnType) {
        case MetadataType.MdArray(_) =>
            match (targetSig.returnType) {
                case MetadataType.MdArray(MetadataType.Generic(_, _)) => true
                case _ => false
            }
        case _ => false
    }

    w.writeLine("public unsafe func ${methodName}(${paramText}): ${returnType} {")
    if (needsArrayReturnBridge) {
        let arrayPointerType = match (sig.returnType) {
            case MetadataType.MdArray(elem) => winrtPublicArrayPointerType(index, elem)
            case _ => "CPointer<Unit>"
        }
        if (argText.isEmpty()) {
            w.writeLine("    let (resultSize__, result__) = ${accessorExpr}.${targetMethodName}()")
        } else {
            w.writeLine("    let (resultSize__, result__) = ${accessorExpr}.${targetMethodName}(${argText})")
        }
        w.writeLine("    return (resultSize__, ${arrayPointerType}(result__))")
    } else if (argText.isEmpty()) {
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
    targetMethodName: String,
    sig: MethodSignature,
    pStart: Int64,
    pEnd: Int64,
    kind: WinrtFactoryKind
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

    // Composable factory methods take 2 trailing params (baseInterface, innerInterface)
    // that are reserved for inheritance/aggregation. Reference implementation hides
    // them from the user-facing surface and passes null/null at the call site.
    let isComposable = match (kind) {
        case WinrtFactoryKind.Composable => true
        case _ => false
    }
    let totalParams = Int64(sig.paramTypes.size)
    let userParamCount = if (isComposable && totalParams >= 2) {
        totalParams - 2
    } else {
        totalParams
    }

    let params = ArrayList<String>()
    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < userParamCount) {
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
                args.add("${paramName}Size")
                args.add(winrtArrayThunkBridgeExpr(index, elem, paramName))
            case _ =>
                params.add("${paramName}: ${highLevelType(index, sig.paramTypes[i])}")
                args.add(paramName)
        }
        i += 1
    }
    if (isComposable && totalParams >= 2) {
        // Pass null IInspectable for baseInterface and the dedicated unused inner
        // pointer slot for innerInterface; matches the reference implementation.
        args.add("IInspectable.viewOf(CPointer<Unit>())")
        args.add("CPointer<CPointer<Unit>>(inout composableInner__)")
    }

    let paramText = joinStrings(params, ", ")
    let argText = joinStrings(args, ", ")
    let returnType = winrtPublicReturnType(index, sig.returnType)
    w.writeLine("public static unsafe func ${methodName}(${paramText}): ${returnType} {")
    if (isComposable && totalParams >= 2) {
        w.writeLine("    var composableInner__: CPointer<Unit> = CPointer<Unit>()")
    }
    if (returnType != "Unit") {
        w.writeLine("    var result__: Option<${returnType}> = Option<${returnType}>.None")
    }
    w.writeLine("    try (factory__ = windows_core.factory<${typeName}, ${factoryProjection}>().unwrap()) {")
    if (returnType == "Unit") {
        if (argText.isEmpty()) {
            w.writeLine("        factory__.${targetMethodName}()")
        } else {
            w.writeLine("        factory__.${targetMethodName}(${argText})")
        }
    } else if (argText.isEmpty()) {
        w.writeLine("        result__ = Some(factory__.${targetMethodName}())")
    } else {
        w.writeLine("        result__ = Some(factory__.${targetMethodName}(${argText}))")
    }
    w.writeLine("    }")
    if (returnType == "Unit") {
        w.writeLine("    return ()")
    } else {
        w.writeLine("    match (result__) {")
        w.writeLine("        case Some(value) => return value")
        w.writeLine("        case None => throw IllegalStateException(\"Activation factory call `${targetMethodName}` did not return a value\")")
        w.writeLine("    }")
    }
    w.writeLine("}")
}

func winrtClassAsAccessorName(typeName: TypeName, usedNames: HashMap<String, Bool>): String {
    let leaf = trimTick(typeName.name)
    let primary = sanitizeIdentifier("as${leaf}")
    if (!usedNames.contains(primary)) {
        usedNames[primary] = true
        return primary
    }

    let qualified = sanitizeIdentifier("as${winrtClassNamespaceAccessorPrefix(typeName.namespace)}${leaf}")
    if (!usedNames.contains(qualified)) {
        usedNames[qualified] = true
        return qualified
    }

    var suffix: Int64 = 2
    while (true) {
        let candidate = sanitizeIdentifier("${qualified}${suffix}")
        if (!usedNames.contains(candidate)) {
            usedNames[candidate] = true
            return candidate
        }
        suffix += 1
    }

    return qualified
}

func winrtClassNamespaceAccessorPrefix(namespace: String): String {
    let parts = splitString(namespace, b'.')
    let sb = StringBuilder()
    var i: Int64 = 0
    if (!parts.isEmpty() && parts[0] == "Windows") {
        i = 1
    }
    while (i < Int64(parts.size)) {
        sb.append(sanitizeIdentifier(parts[i]))
        i += 1
    }
    return sb.toString()
}

func disambiguateWinrtClassFactoryMethodName(
    methodName: String,
    reservedMethodNames: HashMap<String, Bool>,
    emittedFactoryMethodNames: HashMap<String, Bool>
): String {
    if (!reservedMethodNames.contains(methodName) && !emittedFactoryMethodNames.contains(methodName)) {
        return methodName
    }

    let suffixedBase = sanitizeIdentifier("${methodName}Static")
    if (!reservedMethodNames.contains(suffixedBase) && !emittedFactoryMethodNames.contains(suffixedBase)) {
        return suffixedBase
    }

    var suffix: Int64 = 2
    while (true) {
        let candidate = sanitizeIdentifier("${suffixedBase}${suffix}")
        if (!reservedMethodNames.contains(candidate) && !emittedFactoryMethodNames.contains(candidate)) {
            return candidate
        }
        suffix += 1
    }

    return suffixedBase
}
