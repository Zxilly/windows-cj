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
        w.writeLine("public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {")
        w.writeLine("    super(raw, ownsReference: ownsReference)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func fromRaw(raw: CPointer<Unit>): ${typeName} {")
        w.writeLine("    ${typeName}(raw, ownsReference: true)")
        w.writeLine("}")
        w.writeBlankLine()
        w.writeLine("public static func fromRawBorrowed(raw: CPointer<Unit>): ${typeName} {")
        w.writeLine("    ${typeName}(raw)")
        w.writeLine("}")
        w.writeBlankLine()
        writeIidMethod(w, index, fileIdx, row, name)
        w.writeBlankLine()
        w.writeLine("public static func descriptor(): InterfaceDescriptor<${typeName}> {")
        w.writeLine("    return InterfaceDescriptor<${typeName}>(\"${name}\", ${typeName}.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => ${typeName}(raw, ownsReference: true) }, { raw => ${typeName}(raw) })")
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
        w.writeLine("    IInspectable(asRaw())")
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
                writeWinrtDelegateFactoryMethod(w, index, fileIdx, name, typeName, invokeMethodName, invokeSig, pStart, pEnd)
            case None => ()
        }
    })

    match (findWinrtDelegateInvoke(index, fileIdx, row, methodNames, genericsArray)) {
        case Some(invokeInfo) =>
            let (invokeMethodName, invokeSig, pStart, pEnd) = invokeInfo
            w.writeBlankLine()
            writeWinrtDelegateBoxSupport(w, index, fileIdx, name, typeName, vtblName, invokeMethodName, invokeSig, pStart, pEnd)
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
    methodName: String,
    sig: MethodSignature,
    pStart: Int64,
    pEnd: Int64
): Unit {
    let fnType = delegateInvokeFunctionType(index, sig, pStart, pEnd, fileIdx)
    w.writeLine("public static func new(invoke: ${fnType}): ${typeName} {")
    w.writeLine("    let box = ${name}Box(invoke)")
    w.writeLine("    let object = ComObject<${name}Box>.new(box, [${typeName}.descriptorSchema()], [box.vtblPtr()])")
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
    methodName: String,
    sig: MethodSignature,
    pStart: Int64,
    pEnd: Int64
): Unit {
    let fnType = delegateInvokeFunctionType(index, sig, pStart, pEnd, fileIdx)
    let delegateParams = delegateInvokeParams(index, sig, pStart, pEnd, fileIdx)
    let delegateArgs = delegateInvokeArgs(index, sig, pStart, pEnd, fileIdx)
    let returnType = highLevelType(index, sig.returnType)

    w.writeBlock("private open class ${name}Invoker", { =>
        w.writeLine("public open func ${methodName}(${delegateParams}): ${returnType} {")
        if (returnType == "Unit") {
            w.writeLine("    ()")
        } else {
            w.writeLine("    ${highLevelResultDefaultExpr(returnType)}")
        }
        w.writeLine("}")
    })

    w.writeBlankLine()
    w.writeBlock("private class ${name}Box <: ${name}Invoker", { =>
        w.writeLine("public let invoke_: ${fnType}")
        w.writeLine("private let vtblHandle: CPointerHandle<${vtblName}>")
        w.writeBlankLine()
        w.writeLine("public init(invoke: ${fnType}) {")
        w.writeLine("    this.invoke_ = invoke")
        w.writeLine("    this.vtblHandle = unsafe { acquireArrayRawData(Array<${vtblName}>(1, { _ => build${name}BoxVtbl() })) }")
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
    w.writeLine("func build${name}BoxVtbl(): ${vtblName} {")
    w.writeLine("    var vtbl = ${vtblName}()")
    w.writeLine("    vtbl.base_ = buildIInspectableVtbl()")
    w.writeLine("    vtbl.${methodName} = ${name}${methodName}Thunk")
    w.writeLine("    return vtbl")
    w.writeLine("}")

    w.writeBlankLine()
    w.writeLine("@C")
    w.writeLine("func ${name}${methodName}Thunk(${delegateThunkSignature(index, sig)}): Int32 {")
    w.writeLine("    match (unsafe { asImplFromRaw<${name}Invoker>(this_) }) {")
    w.writeLine("        case Some(invoker) =>")
    if (returnType == "Unit") {
        if (delegateArgs.isEmpty()) {
            w.writeLine("            invoker.${methodName}()")
        } else {
            w.writeLine("            invoker.${methodName}(${delegateThunkArgs(index, sig)})")
        }
        w.writeLine("            return S_OK.value")
    } else {
        let callExpr = if (delegateArgs.isEmpty()) {
            "invoker.${methodName}()"
        } else {
            "invoker.${methodName}(${delegateThunkArgs(index, sig)})"
        }
        w.writeLine("            let value = ${callExpr}")
            w.writeLine("            unsafe { result.write(${highLevelThunkReturnExpr(index, sig.returnType, "value")}) }")
        w.writeLine("            return S_OK.value")
    }
    w.writeLine("        case None =>")
    w.writeLine("            return E_NOTIMPL.value")
    w.writeLine("    }")
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
        params.add(highLevelType(index, sig.paramTypes[i]))
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
        params.add("${paramName}: ${highLevelType(index, sig.paramTypes[i])}")
        i += 1
    }
    return joinStrings(params, ", ")
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
    params.add("this_: CPointer<Unit>")
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
