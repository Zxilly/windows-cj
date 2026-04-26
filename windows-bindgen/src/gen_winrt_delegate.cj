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
    let typeName = typedProjectionName(name, genericParams)
    let vtblName = "${name}Vtbl"
    let runtimeName = "${namespace}.${name}"
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    let genericsArray = winmdBuildGenericArray(index, fileIdx, winmdRowGenericStart(index, fileIdx, row), winmdRowGenericEnd(index, fileIdx, row))
    let methodNames = buildWinrtMethodNames(index, fileIdx, row, genericsArray)
    let genericConstraintKinds = winrtGenericConstraintKindsForInterface(index, fileIdx, row, genericParams, genericsArray)
    let genericWhere = winrtProjectionWhereClause(genericParams, genericConstraintKinds)
    let delegateInvoke = findWinrtDelegateInvoke(index, fileIdx, row, methodNames, genericsArray)
    let typeTags = typeAvailabilityTags(namespace, name, fileIdx, row, arches)

    useSupportSymbol("windows_interface", "ComInterface")
    useSupportSymbol("windows_interface", "DescriptorSchemaProvider")
    useSupportSymbol("windows_interface", "InterfaceDescriptorSchema")
    useSupportSymbol("windows_interface", "InterfaceMethodSchema")
    useSupportSymbol("windows_interface", "InterfaceParameterBridgeKind")
    useSupportSymbol("windows_interface", "InterfaceParameterSchema")
    useSupportSymbol("windows_interface", "InterfaceWrapperBase")
    useSupportSymbol("windows_interface", "RuntimeName")
    useSupportSymbol("windows_interface", "RuntimeType")
    useSupportSymbol("windows_interface", "RuntimeTypeContract")
    useSupportSymbol("windows_interface", "InterfaceDescriptor")
    useSupportSymbol("windows_interface", "GUID")
    useSupportSymbol("windows_interface", "IInspectable")
    useSupportSymbol("windows_interface", "IUnknown")
    useSupportSymbol("windows_interface", "IUnknownVtbl")
    useSupportSymbol("windows_core", "RuntimeType")
    useSupportSymbol("windows_core", "InParam")
    useSupportSymbol("windows_core", "ComObject")
    useSupportSymbol("windows_core", "asImplFromRaw")
    useSupportSymbol("windows_core", "buildIUnknownVtbl")
    useSupportSymbol("windows_core", "S_OK")
    useSupportSymbol("windows_core", "E_NOTIMPL")
    useSupportSymbol("windows_core", "HRESULT")
    useSupportSymbol("windows_core", "winrtStoreGenericOut")

    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeLine("@C")
    w.writeBlock("public struct ${vtblName}", { =>
        w.writeLine("public var base_: IUnknownVtbl = IUnknownVtbl()")

        var methodRow = mStart
        while (methodRow < mEnd) {
            if (isWinrtDelegateConstructorMethod(index, fileIdx, methodRow)) {
                methodRow += 1
                continue
            }
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
    w.writeBlock("public class ${name}${genericDecl} <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider${genericWhere}", { =>
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
        w.writeLine("public static func descriptor(): InterfaceDescriptor<${typeName}> {")
        w.writeLine("    return InterfaceDescriptor<${typeName}>(\"${name}\", ${typeName}.iid(), [IUnknown.iid()], { raw => ${typeName}.fromAbiTake(raw) }, { raw => ${typeName}.viewOf(raw) })")
        w.writeLine("}")
        match (delegateInvoke) {
            case Some((invokeMethodName, invokeSig, pStart, pEnd)) =>
                let _ = invokeMethodName
                w.writeBlankLine()
                writeWinrtDelegateDescriptorSchemaMethod(w, index, fileIdx, name, typeName, vtblName, invokeSig, pStart, pEnd)
            case None => ()
        }
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
            if (isWinrtDelegateConstructorMethod(index, fileIdx, methodRow2)) {
                methodRow2 += 1
                continue
            }
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

        match (delegateInvoke) {
            case Some(invokeInfo) =>
                let (invokeMethodName, invokeSig, pStart, pEnd) = invokeInfo
                w.writeBlankLine()
                writeWinrtDelegateFactoryMethod(w, index, fileIdx, name, typeName, genericParams, invokeMethodName, invokeSig, pStart, pEnd)
            case None => ()
        }
    })
    w.writeBlankLine()
    writeAvailabilityForTags(w, feature, typeTags)
    w.writeLine("extend${genericDecl} ${typeName} <: windows_core.Interface<${typeName}>${genericWhere} {}")

    match (delegateInvoke) {
        case Some(invokeInfo) =>
            let (invokeMethodName, invokeSig, pStart, pEnd) = invokeInfo
            w.writeBlankLine()
            writeWinrtDelegateBoxSupport(w, index, fileIdx, name, typeName, vtblName, genericParams, genericConstraintKinds, invokeMethodName, invokeSig, pStart, pEnd)
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

func isWinrtDelegateConstructorMethod(index: TypeIndex, fileIdx: Int64, methodRow: Int64): Bool {
    let rawName = index.methodDefName(fileIdx, methodRow)
    return rawName == ".ctor" || rawName == ".cctor"
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
    w.writeLine("    let object = ComObject<${boxTypeName}>.new(box, [${typeName}.descriptorSchema()], box.vtblPtr())")
    w.writeLine("    return object.intoInterface(${typeName}.descriptor())")
    w.writeLine("}")
}

func writeWinrtDelegateDescriptorSchemaMethod(
    w: CodeWriter,
    index: TypeIndex,
    fileIdx: Int64,
    name: String,
    typeName: String,
    vtblName: String,
    sig: MethodSignature,
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

    let parameters = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        let seq = i + 1
        let paramName = if (seqToName.contains(seq)) {
            seqToName[seq]
        } else {
            "arg${i}"
        }
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(elem) =>
                parameters.add("InterfaceParameterSchema(\"${paramName}\", \"${escapeString(winrtPublicArrayPointerType(index, elem))}\", \"${escapeString(winrtPublicArrayPointerType(index, elem))}\", InterfaceParameterBridgeKind.Value)")
            case _ =>
                let publicType = highLevelType(index, sig.paramTypes[i])
                let abiType = highLevelAbiType(index, sig.paramTypes[i])
                let bridgeKind = if (highLevelArgumentExpr(index, sig.paramTypes[i], "value") != "value") {
                    "InterfaceParameterBridgeKind.InParam"
                } else {
                    "InterfaceParameterBridgeKind.Value"
                }
                let callerType = if (bridgeKind == "InterfaceParameterBridgeKind.InParam") {
                    "InParam<${escapeString(publicType)}>"
                } else {
                    escapeString(publicType)
                }
                parameters.add("InterfaceParameterSchema(\"${paramName}\", \"${escapeString(abiType)}\", \"${callerType}\", ${bridgeKind})")
        }
        i += 1
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

    w.writeLine("public static func descriptorSchema(): InterfaceDescriptorSchema {")
    w.writeLine("    var schema = InterfaceDescriptorSchema(\"${name}\", ${typeName}.iid(), IUnknown.descriptorSchema(), \"${vtblName}\", \"${name}\", \"${name}Invoker\", [InterfaceMethodSchema(\"Invoke\", 3, ${parameterLiteral}, \"Int32\")])")
    w.writeLine("    schema.runtimeTypeContract = Some(${typeName}.runtimeType())")
    w.writeLine("    return schema")
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
    genericConstraintKinds: HashMap<String, WinrtGenericConstraintKind>,
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
    let genericWhere = winrtProjectionWhereClause(genericParams, genericConstraintKinds)
    let erasedInvokerTypeName = winrtDelegateInvokerErasedName(name)
    let invokerTypeName = "${name}Invoker${genericDecl}"
    let boxTypeName = "${name}Box${genericDecl}"

    w.writeBlock("private open class ${erasedInvokerTypeName}", { =>
        writeWinrtDelegateThunkErasedMethod(w, index, sig, methodName)
    })

    w.writeBlankLine()
    w.writeBlock("private open class ${invokerTypeName} <: ${erasedInvokerTypeName}${genericWhere}", { =>
        w.writeLine("public open func ${methodName}(${delegateParams}): ${returnType} {")
        if (returnType == "Unit") {
            w.writeLine("    ()")
        } else {
            w.writeLine("    ${highLevelDefaultExpr(index, sig.returnType)}")
        }
        w.writeLine("}")
        w.writeBlankLine()
        writeWinrtDelegateThunkHelperMethod(w, index, sig, methodName, override: true)
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
    w.writeLine("    vtbl.base_ = buildIUnknownVtbl()")
    w.writeLine("    vtbl.${methodName} = { ${delegateThunkSignature(index, sig)} =>")
    w.writeLine("        match (unsafe { asImplFromRaw<${erasedInvokerTypeName}>(instanceRaw) }) {")
    w.writeLine("            case Some(invoker) =>")
    let thunkHelperArgs = delegateThunkHelperArgs(sig)
    let helperName = winrtDelegateThunkHelperName(methodName)
    if (thunkHelperArgs.isEmpty()) {
        w.writeLine("                return invoker.${helperName}()")
    } else {
        w.writeLine("                return invoker.${helperName}(${thunkHelperArgs})")
    }
    w.writeLine("            case None =>")
    w.writeLine("                return E_NOTIMPL.value")
    w.writeLine("        }")
    w.writeLine("    }")
    w.writeLine("    return vtbl")
    w.writeLine("}")
}

func winrtDelegateInvokerErasedName(name: String): String {
    return "${name}InvokerErased"
}

func winrtDelegateThunkHelperName(methodName: String): String {
    return "__winrtThunk_${methodName}"
}

func writeWinrtDelegateThunkErasedMethod(
    w: CodeWriter,
    index: TypeIndex,
    sig: MethodSignature,
    methodName: String
): Unit {
    let helperName = winrtDelegateThunkHelperName(methodName)
    let helperParams = delegateThunkHelperParams(index, sig)
    w.writeLine("public open func ${helperName}(${helperParams}): Int32 {")
    w.writeLine("    E_NOTIMPL.value")
    w.writeLine("}")
}

func writeWinrtDelegateThunkHelperMethod(
    w: CodeWriter,
    index: TypeIndex,
    sig: MethodSignature,
    methodName: String,
    override!: Bool = false
): Unit {
    let helperName = winrtDelegateThunkHelperName(methodName)
    let helperParams = delegateThunkHelperParams(index, sig)
    let modifier = if (override) { "public override func" } else { "public open func" }
    w.writeLine("${modifier} ${helperName}(${helperParams}): Int32 {")
    writeWinrtDelegateThunkBody(w, index, sig, "this", methodName)
    w.writeLine("}")
}

func writeWinrtDelegateThunkBody(
    w: CodeWriter,
    index: TypeIndex,
    sig: MethodSignature,
    receiver: String,
    methodName: String
): Unit {
    let callArgs = delegateThunkProjectedArgs(index, sig)
    let callExpr = if (callArgs.isEmpty()) {
        "${receiver}.${methodName}()"
    } else {
        "${receiver}.${methodName}(${callArgs})"
    }
    if (!highLevelHasResult(sig)) {
        w.writeLine("    ${callExpr}")
        w.writeLine("    return S_OK.value")
        return
    }

    w.writeLine("    let value = ${callExpr}")
    match (sig.returnType) {
        case MetadataType.Generic(name, _) =>
            w.writeLine("    return windows_core.winrtStoreGenericOut<${name}>(result, value)")
        case _ =>
            w.writeLine("    unsafe { result.write(${highLevelThunkReturnExpr(index, sig.returnType, "value")}) }")
            w.writeLine("    return S_OK.value")
    }
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
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(elem) =>
                params.add("UInt32")
                params.add(winrtPublicArrayPointerType(index, elem))
            case _ =>
                params.add(delegateCallbackType(index, sig.paramTypes[i]))
        }
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
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(elem) =>
                params.add("${paramName}Size: UInt32")
                params.add("${paramName}: ${winrtPublicArrayPointerType(index, elem)}")
            case _ =>
                params.add("${paramName}: ${delegateCallbackType(index, sig.paramTypes[i])}")
        }
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
        let paramName = if (seqToName.contains(seq)) {
            seqToName[seq]
        } else {
            "param${i}"
        }
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(_) =>
                args.add("${paramName}Size")
                args.add(paramName)
            case _ =>
                args.add(paramName)
        }
        i += 1
    }
    return joinStrings(args, ", ")
}

func delegateThunkSignature(index: TypeIndex, sig: MethodSignature): String {
    let params = ArrayList<String>()
    params.add("instanceRaw: CPointer<Unit>")
    let helperParams = delegateThunkHelperParams(index, sig)
    if (!helperParams.isEmpty()) {
        params.add(helperParams)
    }
    return joinStrings(params, ", ")
}

func delegateThunkHelperParams(index: TypeIndex, sig: MethodSignature): String {
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
        params.add("result: CPointer<${highLevelAbiType(index, sig.returnType)}>")
    }
    return joinStrings(params, ", ")
}

func delegateThunkHelperArgs(sig: MethodSignature): String {
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
        args.add("result")
    }
    return joinStrings(args, ", ")
}

func delegateThunkProjectedArgs(index: TypeIndex, sig: MethodSignature): String {
    let args = ArrayList<String>()
    var i: Int64 = 0
    while (i < Int64(sig.paramTypes.size)) {
        match (sig.paramTypes[i]) {
            case MetadataType.MdArray(_) =>
                args.add("arg${i}Size")
                args.add("arg${i}")
            case MetadataType.MdString =>
                args.add("${winrtStringProjectionType()}.viewOf(arg${i})")
            case MetadataType.ClassName(tn) =>
                if (isSystemStringTypeName(tn)) {
                    args.add("${winrtStringProjectionType()}.viewOf(arg${i})")
                } else {
                    args.add(highLevelThunkParamExpr(index, sig.paramTypes[i], "arg${i}"))
                }
            case MetadataType.ValueName(tn) =>
                if (isSystemStringTypeName(tn)) {
                    args.add("${winrtStringProjectionType()}.viewOf(arg${i})")
                } else {
                    args.add(highLevelThunkParamExpr(index, sig.paramTypes[i], "arg${i}"))
                }
            case MetadataType.Generic(name, _) =>
                args.add("windows_core.winrtProjectGenericIn<${name}>(arg${i})")
            case _ =>
                args.add(highLevelThunkParamExpr(index, sig.paramTypes[i], "arg${i}"))
        }
        i += 1
    }
    return joinStrings(args, ", ")
}
