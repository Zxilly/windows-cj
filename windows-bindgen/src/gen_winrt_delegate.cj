package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.winmd.*

public func generateWinrtDelegate(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    namespace: String
): Unit {
    let name = trimTick(index.typeDefName(fileIdx, row))
    let feature = namespaceToFeature(namespace)
    let arches = index.arches(TABLE_TYPE_DEF, fileIdx, row)
    let genericParams = winmdTypeGenericParameterNames(index, fileIdx, row)
    let genericDecl = typeGenericDeclaration(genericParams)
    let genericWhere = runtimeTypeWhereClause(genericParams)
    let typeName = typedProjectionName(name, genericParams)
    let vtblName = "${name}Vtbl"
    let runtimeName = "${namespace}.${name}"
    let methodNames = buildNormalizedMethodNames(index, fileIdx, row)
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    let genericsArray = winmdBuildGenericArray(index, fileIdx, winmdRowGenericStart(index, fileIdx, row), winmdRowGenericEnd(index, fileIdx, row))
    let typeTags = typeAvailabilityTags(namespace, name, fileIdx, row, arches)

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeLine("@C")
    w.writeBlock("public struct ${vtblName}", { =>
        w.writeLine("public var base_: IInspectableVtbl = IInspectableVtbl()")

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
    })

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
        writeIidMethod(w, index, fileIdx, row, name)
        w.writeBlankLine()
        w.writeLine("public static func descriptor(): InterfaceDescriptor<${typeName}> {")
        w.writeLine("    return InterfaceDescriptor<${typeName}>(\"${name}\", ${typeName}.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => ${typeName}.fromAbiTake(raw) }, { raw => ${typeName}.viewOf(raw) })")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func abiType(): String {")
        w.writeLine("    \"CPointer<Unit>\"")
        w.writeLine("}")
        w.writeBlankLine()
        writeWinrtSignatureMethod(w, index, fileIdx, row, genericParams, true)
        w.writeBlankLine()
        w.writeLine("public static func runtimeType(): RuntimeTypeContract {")
        w.writeLine("    RuntimeTypeContract(\"${runtimeName}\", ${typeName}.signature(), ${typeName}.iid())")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func asIInspectable(): IInspectable {")
        w.writeLine("    IInspectable.viewOf(asRaw())")
        w.writeLine("}")
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

        match (findWinrtDelegateInvoke(index, fileIdx, row, methodNames, genericsArray)) {
            case Some(invokeInfo) =>
                let (invokeMethodName, invokeSig, pStart, pEnd) = invokeInfo
                w.writeBlankLine()
                writeWinrtDelegateFactoryMethod(w, index, fileIdx, name, typeName, genericParams, invokeMethodName, invokeSig, pStart, pEnd)
            case None => ()
        }
    })

    match (findWinrtDelegateInvoke(index, fileIdx, row, methodNames, genericsArray)) {
        case Some(invokeInfo) =>
            let (invokeMethodName, invokeSig, pStart, pEnd) = invokeInfo
            w.writeBlankLine()
            writeWinrtDelegateBoxSupport(w, index, fileIdx, name, typeName, vtblName, genericParams, invokeMethodName, invokeSig, pStart, pEnd)
        case None => ()
    }
}

func findWinrtDelegateInvoke(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    methodNames: HashMap<Int64, String>,
    genericsArray: Array<MetadataType>
): Option<(String, MethodSignature, Int64, Int64)> {
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var methodRow = mStart
    while (methodRow < mEnd) {
        if (index.methodDefName(fileIdx, methodRow) == "Invoke") {
            let sig = index.methodDefSignature(fileIdx, methodRow, genericsArray)
            let (pStart, pEnd) = index.methodDefParams(fileIdx, methodRow)
            return Some((methodNames[methodRow], sig, pStart, pEnd))
        }
        methodRow += 1
    }
    None
}

func writeWinrtDelegateFactoryMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    name: String,
    typeName: String,
    genericParams: ArrayList<String>,
    methodName: String,
    sig: MethodSignature,
    pStart: Int64,
    pEnd: Int64
): Unit {
    let fnType = delegateInvokeFunctionType(index, sig, pStart, pEnd, fileIdx)
    let boxTypeName = typedProjectionName("${name}Box", genericParams)
    w.writeLine("public static func new(invoke: ${fnType}): ${typeName} {")
    w.writeLine("    let box = ${boxTypeName}(invoke)")
    w.writeLine("    let object = ComObject<${boxTypeName}>.new(box, [${typeName}.descriptorSchema()], [box.vtblPtr()])")
    w.writeLine("    return object.intoInterface(${typeName}.descriptor())")
    w.writeLine("}")
}

func writeWinrtDelegateBoxSupport(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    name: String,
    typeName: String,
    vtblName: String,
    genericParams: ArrayList<String>,
    methodName: String,
    sig: MethodSignature,
    pStart: Int64,
    pEnd: Int64
): Unit {
    let fnType = delegateInvokeFunctionType(index, sig, pStart, pEnd, fileIdx)
    let delegateParams = delegateInvokeParams(index, sig, pStart, pEnd, fileIdx)
    let delegateArgs = delegateInvokeArgs(index, sig, pStart, pEnd, fileIdx)
    let returnType = highLevelType(index, sig.returnType)
    let genericDecl = typeGenericDeclaration(genericParams)
    let genericWhere = runtimeTypeWhereClause(genericParams)
    let invokerTypeName = "${name}Invoker${genericDecl}"
    let boxTypeName = "${name}Box${genericDecl}"

    w.writeBlock("private open class ${invokerTypeName}${genericWhere}", { =>
        w.writeLine("public open func ${methodName}(${delegateParams}): ${returnType} {")
        if (returnType == "Unit") {
            w.writeLine("    ()")
        } else {
            w.writeLine("    ${highLevelResultDefaultExpr(returnType)}")
        }
        w.writeLine("}")
    })

    w.writeBlankLine()
    w.writeBlock("private class ${boxTypeName} <: ${invokerTypeName}${genericWhere}", { =>
        w.writeLine("public let invoke_: ${fnType}")
        w.writeLine("private let vtblHandle: CPointerHandle<${vtblName}>")
        w.writeBlankLine()
        w.writeLine("public init(invoke: ${fnType}) {")
        w.writeLine("    this.invoke_ = invoke")
        if (genericDecl.isEmpty()) {
            w.writeLine("    this.vtblHandle = unsafe { acquireArrayRawData(Array<${vtblName}>(1, { _ => build${name}BoxVtbl() })) }")
        } else {
            w.writeLine("    this.vtblHandle = unsafe { acquireArrayRawData(Array<${vtblName}>(1, { _ => build${name}BoxVtbl${genericDecl}() })) }")
        }
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public func vtblPtr(): CPointer<Unit> {")
        w.writeLine("    CPointer<Unit>(vtblHandle.pointer)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public override func ${methodName}(${delegateParams}): ${returnType} {")
        if (delegateArgs.isEmpty()) {
            w.writeLine("    invoke_()")
        } else {
            w.writeLine("    invoke_(${delegateArgs})")
        }
        w.writeLine("}")
    })

    w.writeBlankLine()
    w.writeLine("func build${name}BoxVtbl${genericDecl}(): ${vtblName}${genericWhere} {")
    w.writeLine("    var vtbl = ${vtblName}()")
    w.writeLine("    vtbl.base_ = buildIInspectableVtbl()")
    w.writeLine("    vtbl.${methodName} = { ${delegateThunkSignature(index, sig)} =>")
    w.writeLine("        match (unsafe { asImplFromRaw<${invokerTypeName}>(instanceRaw) }) {")
    w.writeLine("            case Some(invoker) =>")
    if (returnType == "Unit") {
        if (delegateArgs.isEmpty()) {
            w.writeLine("                invoker.${methodName}()")
        } else {
            w.writeLine("                invoker.${methodName}(${delegateThunkArgs(index, sig)})")
        }
        w.writeLine("                return S_OK.value")
    } else {
        let callExpr = if (delegateArgs.isEmpty()) {
            "invoker.${methodName}()"
        } else {
            "invoker.${methodName}(${delegateThunkArgs(index, sig)})"
        }
        w.writeLine("                let value = ${callExpr}")
        w.writeLine("                unsafe { result.write(${highLevelThunkReturnExpr(index, sig.returnType, "value")}) }")
        w.writeLine("                return S_OK.value")
    }
    w.writeLine("            case None =>")
    w.writeLine("                return E_NOTIMPL.value")
    w.writeLine("        }")
    w.writeLine("    }")
    w.writeLine("    return vtbl")
    w.writeLine("}")
}

func delegateInvokeFunctionType(
    index: TypeIndex,
    sig: MethodSignature,
    pStart: Int64,
    pEnd: Int64,
    fileIdx: Int64
): String {
    let params = ArrayList<String>()
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

    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        params.add(delegateCallbackType(index, sig.paramTypes[i]))
        i += 1
    }
    return "(${joinStrings(params, ", ")}) -> ${highLevelType(index, sig.returnType)}"
}

func delegateInvokeParams(
    index: TypeIndex,
    sig: MethodSignature,
    pStart: Int64,
    pEnd: Int64,
    fileIdx: Int64
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
        params.add("${paramName}: ${delegateCallbackType(index, sig.paramTypes[i])}")
        i += 1
    }
    return joinStrings(params, ", ")
}

func delegateCallbackType(index: TypeIndex, ty: MetadataType): String {
    match (ty) {
        case MetadataType.MdObject => "InParam<IInspectable>"
        case MetadataType.ClassName(tn) =>
            return "InParam<${typeNameToProjectionCj(index, tn)}>"
        case MetadataType.ValueName(tn) =>
            if (!tn.generics.isEmpty() || isReferenceProjectionType(index, tn)) {
                return "InParam<${typeNameToProjectionCj(index, tn)}>"
            }
            return highLevelType(index, ty)
        case _ =>
            return highLevelType(index, ty)
    }
}

func delegateInvokeArgs(
    index: TypeIndex,
    sig: MethodSignature,
    pStart: Int64,
    pEnd: Int64,
    fileIdx: Int64
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

    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        let seq = i + 1
        if (seqToName.contains(seq)) {
            args.add(seqToName[seq])
        } else {
            args.add("param${i}")
        }
        i += 1
    }
    return joinStrings(args, ", ")
}

func delegateThunkSignature(index: TypeIndex, sig: MethodSignature): String {
    let params = ArrayList<String>()
    params.add("instanceRaw: CPointer<Unit>")
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        params.add("arg${i}: ${highLevelAbiType(index, sig.paramTypes[i])}")
        i += 1
    }
    if (highLevelHasResult(sig)) {
        params.add("result: CPointer<${highLevelAbiType(index, sig.returnType)}>")
    }
    return joinStrings(params, ", ")
}

func delegateThunkArgs(index: TypeIndex, sig: MethodSignature): String {
    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        args.add(highLevelThunkParamExpr(index, sig.paramTypes[i], "arg${i}"))
        i += 1
    }
    return joinStrings(args, ", ")
}
