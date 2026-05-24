package windows_bindgen

import std.collection.*
import stdx.encoding.json.*

class ParameterPair {
    public let name: String
    public let typeName: String

    public init(name: String, typeName: String) {
        this.name = name
        this.typeName = typeName
    }
}

class PInvokeStringOutSlot {
    public let pair: ParameterPair
    public let kind: String

    public init(pair: ParameterPair, kind: String) {
        this.pair = pair
        this.kind = kind
    }
}

class InterfaceDispatcherOutSlotCleanupSpec {
    public let pair: ParameterPair
    public let cleanupKind: String

    public init(pair: ParameterPair, cleanupKind: String) {
        this.pair = pair
        this.cleanupKind = cleanupKind
    }
}

class RuntimeBorrowSpec {
    public let name: String
    public let typeName: String
    public let sourceName: String

    public init(name: String, typeName: String, sourceName: String) {
        this.name = name
        this.typeName = typeName
        this.sourceName = sourceName
    }
}

class RuntimeArrayInputSpec {
    public let sourceName: String
    public let elementProjectedType: String
    public let elementAbiType: String
    public let elementSignature: SignatureRecord
    public let abiValuesName: String
    public let abiArrayName: String
    public let rawName: String
    public let lenName: String
    public let borrowsName: String
    public let indexName: String
    public let closeIndexName: String
    public let borrowName: String
    public let usesHandleBorrow: Bool

    public init(
        sourceName: String,
        elementProjectedType: String,
        elementAbiType: String,
        elementSignature: SignatureRecord,
        localPrefix: String,
        usesHandleBorrow: Bool
    ) {
        this.sourceName = sourceName
        this.elementProjectedType = elementProjectedType
        this.elementAbiType = elementAbiType
        this.elementSignature = elementSignature
        this.abiValuesName = "${localPrefix}AbiValues"
        this.abiArrayName = "${localPrefix}AbiArray"
        this.rawName = "${localPrefix}Raw"
        this.lenName = "${localPrefix}Len"
        this.borrowsName = "${localPrefix}Borrows"
        this.indexName = "${localPrefix}Index"
        this.closeIndexName = "${localPrefix}CloseIndex"
        this.borrowName = "${localPrefix}Borrow"
        this.usesHandleBorrow = usesHandleBorrow
    }
}

class RuntimeScalarOutputSpec {
    public let name: String
    public let valueName: String
    public let projectedType: String
    public let abiType: String
    public let signature: SignatureRecord

    public init(
        name: String,
        valueName: String,
        projectedType: String,
        abiType: String,
        signature: SignatureRecord
    ) {
        this.name = name
        this.valueName = valueName
        this.projectedType = projectedType
        this.abiType = abiType
        this.signature = signature
    }
}

class RuntimeRawAbiOutSlotCleanupSpec {
    public let slotName: String
    public let projectedType: String
    public let abiType: String

    public init(slotName: String, projectedType: String, abiType: String) {
        this.slotName = slotName
        this.projectedType = projectedType
        this.abiType = abiType
    }
}

class RuntimeRawAbiArrayOutSlotCleanupSpec {
    public let sizeSlotName: String
    public let dataSlotName: String
    public let elementProjectedType: String
    public let elementAbiType: String

    public init(
        sizeSlotName: String,
        dataSlotName: String,
        elementProjectedType: String,
        elementAbiType: String
    ) {
        this.sizeSlotName = sizeSlotName
        this.dataSlotName = dataSlotName
        this.elementProjectedType = elementProjectedType
        this.elementAbiType = elementAbiType
    }
}

class RuntimeArrayOutputSpec {
    public let targetName: String
    public let valueName: String
    public let dataName: String
    public let sizeName: String
    public let elementProjectedType: String
    public let elementAbiType: String
    public let elementSignature: SignatureRecord

    public init(
        targetName: String,
        valueName: String,
        dataName: String,
        sizeName: String,
        elementProjectedType: String,
        elementAbiType: String,
        elementSignature: SignatureRecord
    ) {
        this.targetName = targetName
        this.valueName = valueName
        this.dataName = dataName
        this.sizeName = sizeName
        this.elementProjectedType = elementProjectedType
        this.elementAbiType = elementAbiType
        this.elementSignature = elementSignature
    }
}

// A caller-allocated out array (IVector.GetMany style). The caller owns the
// `items` buffer of `itemsSize` element slots; the callee fills it. For handle
// element types the buffer is zeroed before the call and any handles written
// before a failure are released afterward (value elements own nothing, so the
// generic range helpers dispatch to no-ops for them).
class RuntimeCallerAllocatedArraySpec {
    public let sizeName: String
    public let itemsName: String
    public let elementProjectedType: String
    public let elementAbiType: String

    public init(
        sizeName: String,
        itemsName: String,
        elementProjectedType: String,
        elementAbiType: String
    ) {
        this.sizeName = sizeName
        this.itemsName = itemsName
        this.elementProjectedType = elementProjectedType
        this.elementAbiType = elementAbiType
    }
}

class RuntimeCallPlan {
    public let borrows: ArrayList<RuntimeBorrowSpec>
    public let args: ArrayList<String>
    public let arrayInputs: ArrayList<RuntimeArrayInputSpec>
    public let scalarOutputs: ArrayList<RuntimeScalarOutputSpec>
    public let arrayOutputs: ArrayList<RuntimeArrayOutputSpec>
    public let callerAllocatedArrays: ArrayList<RuntimeCallerAllocatedArraySpec>

    public init(borrows: ArrayList<RuntimeBorrowSpec>, args: ArrayList<String>) {
        this.borrows = borrows
        this.args = args
        this.arrayInputs = ArrayList<RuntimeArrayInputSpec>()
        this.scalarOutputs = ArrayList<RuntimeScalarOutputSpec>()
        this.arrayOutputs = ArrayList<RuntimeArrayOutputSpec>()
        this.callerAllocatedArrays = ArrayList<RuntimeCallerAllocatedArraySpec>()
    }

    public init(
        borrows: ArrayList<RuntimeBorrowSpec>,
        args: ArrayList<String>,
        arrayInputs: ArrayList<RuntimeArrayInputSpec>,
        scalarOutputs: ArrayList<RuntimeScalarOutputSpec>,
        arrayOutputs: ArrayList<RuntimeArrayOutputSpec>
    ) {
        this.borrows = borrows
        this.args = args
        this.arrayInputs = arrayInputs
        this.scalarOutputs = scalarOutputs
        this.arrayOutputs = arrayOutputs
        this.callerAllocatedArrays = ArrayList<RuntimeCallerAllocatedArraySpec>()
    }

    public init(
        borrows: ArrayList<RuntimeBorrowSpec>,
        args: ArrayList<String>,
        arrayInputs: ArrayList<RuntimeArrayInputSpec>,
        scalarOutputs: ArrayList<RuntimeScalarOutputSpec>,
        arrayOutputs: ArrayList<RuntimeArrayOutputSpec>,
        callerAllocatedArrays: ArrayList<RuntimeCallerAllocatedArraySpec>
    ) {
        this.borrows = borrows
        this.args = args
        this.arrayInputs = arrayInputs
        this.scalarOutputs = scalarOutputs
        this.arrayOutputs = arrayOutputs
        this.callerAllocatedArrays = callerAllocatedArrays
    }
}

class RawStorageSpec {
    public let typeName: String
    public let count: Int64
    public let repeatValue: String

    public init(typeName: String, count: Int64, repeatValue: String) {
        this.typeName = typeName
        this.count = count
        this.repeatValue = repeatValue
    }
}

class NativeBitfieldSpec {
    public let name: String
    public let bitOffset: Int64
    public let bitWidth: Int64

    public init(name: String, bitOffset: Int64, bitWidth: Int64) {
        this.name = name
        this.bitOffset = bitOffset
        this.bitWidth = bitWidth
    }
}

class RuntimeClassInterfaceSpec {
    public let symbol: SymbolRecord
    public let typeName: String
    public let fullName: String
    public let accessorName: String
    public let substitutions: ArrayList<RuntimeClassGenericSubstitution>

    public init(
        symbol: SymbolRecord,
        typeName: String,
        substitutions!: ArrayList<RuntimeClassGenericSubstitution> = ArrayList<RuntimeClassGenericSubstitution>()
    ) {
        this.symbol = symbol
        this.typeName = typeName
        this.fullName = symbol.fullName
        this.accessorName = cjIdentifier(symbol.name)
        this.substitutions = substitutions
    }
}

class RuntimeClassGenericSubstitution {
    public let name: String
    public let typeName: String

    public init(name: String, typeName: String) {
        this.name = name
        this.typeName = typeName
    }
}

public func renderSymbolImpl(symbol: SymbolRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    return renderSymbolImpl(symbol, symbolsByName, RenderOptions.defaults(), TargetAbiOptions.defaults())
}

public func renderSymbolImpl(
    symbol: SymbolRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    targetAbi: TargetAbiOptions
): String {
    return renderSymbolImpl(symbol, symbolsByName, RenderOptions.defaults(), targetAbi)
}

public func renderSymbolImpl(
    symbol: SymbolRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    options: RenderOptions
): String {
    return renderSymbolImpl(symbol, symbolsByName, options, TargetAbiOptions.defaults())
}

public func renderSymbolImpl(
    symbol: SymbolRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    options: RenderOptions,
    targetAbi: TargetAbiOptions
): String {
    if (!symbol.implSource.isEmpty()) {
        return symbol.implSource
    }
    match (symbol.typeDef) {
        case Some(typeDef) =>
            let header = "// ${symbol.fullName} (${symbol.metadataToken})"
            match (win32TextPointerRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\npublic type ${symbol.implName} = ${typeName}"
                case None => ()
            }
            match (eventRegistrationTokenRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\npublic type ${symbol.implName} = ${typeName}"
                case None => ()
            }
            match (hresultRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\npublic type ${symbol.implName} = ${typeName}"
                case None => ()
            }
            match (win32ScalarRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\n${renderRawAliasSymbol(symbol, typeDef, typeName)}"
                case None => ()
            }
            match (stringHandleRawAbiTypeByFullName(symbol.fullName)) {
                case Some(typeName) => return "${header}\npublic type ${symbol.implName} = ${typeName}"
                case None => ()
            }
            if (isEnumType(typeDef)) {
                return "${header}\n${renderEnumSymbol(symbol, typeDef, symbolsByName, options)}"
            }
            if (isDelegateType(typeDef)) {
                return "${header}\n${renderDelegateSymbol(symbol, typeDef, symbolsByName)}"
            }
            if (isValueType(typeDef)) {
                return "${header}\n${renderValueStructSymbol(symbol, typeDef, symbolsByName, options, targetAbi)}"
            }
            if (hasPInvokeMethods(typeDef)) {
                return "${header}\n${renderPInvokeSymbol(symbol, typeDef, symbolsByName, options, targetAbi)}"
            }
            if (isApisLikeClass(typeDef)) {
                return "${header}\n${renderPInvokeSymbol(symbol, typeDef, symbolsByName, options, targetAbi)}"
            }
            if (isInterfaceType(typeDef)) {
                match (guidAttributeString(typeDef)) {
                    case Some(guidValue) =>
                        if (!contains(typeDef.attributes, "WindowsRuntime")) {
                            return "${header}\n${renderNativeComInterfaceSymbol(symbol, typeDef, symbolsByName)}"
                        }
                        return "${header}\n${renderInterfaceSymbol(symbol, typeDef, symbolsByName, guidValue, options)}"
                    case None => ()
                }
                return "${header}\n${renderRawHandleSymbol(symbol, "interface")}"
            }
            if (isWinrtClassType(typeDef)) {
                match (renderWinrtRuntimeClassSymbol(symbol, typeDef, symbolsByName)) {
                    case Some(source) => return "${header}\n${source}"
                    case None => ()
                }
            }
            return "${header}\n${renderRawHandleSymbol(symbol, "class")}"
        case None =>
            return "// ${symbol.fullName}\n" +
                "public struct ${symbol.implName} {\n" +
                "    public init() {}\n" +
                "}"
    }
}

func isEnumType(typeDef: TypeDefinitionRecord): Bool {
    return typeDef.hasBaseType && typeDef.baseType == "System.Enum"
}

func isValueType(typeDef: TypeDefinitionRecord): Bool {
    if (typeDef.hasBaseType && typeDef.baseType == "System.ValueType") {
        return true
    }
    return contains(typeDef.attributes, "SequentialLayout") || contains(typeDef.attributes, "ExplicitLayout")
}

func isInterfaceType(typeDef: TypeDefinitionRecord): Bool {
    return contains(typeDef.attributes, "Interface")
}

func isDelegateType(typeDef: TypeDefinitionRecord): Bool {
    return typeDef.hasBaseType && typeDef.baseType == "System.MulticastDelegate"
}

func isWinrtClassType(typeDef: TypeDefinitionRecord): Bool {
    contains(typeDef.attributes, "Class") && contains(typeDef.attributes, "WindowsRuntime")
}

func isWinrtDelegateType(typeDef: TypeDefinitionRecord): Bool {
    return isDelegateType(typeDef) && contains(typeDef.attributes, "WindowsRuntime")
}

func hasPInvokeMethods(typeDef: TypeDefinitionRecord): Bool {
    for (method in typeDef.methods) {
        match (method.methodImport) {
            case Some(_) => return true
            case None => ()
        }
    }
    return false
}

func isApisLikeClass(typeDef: TypeDefinitionRecord): Bool {
    if (typeDef.name != "Apis") {
        return false
    }
    if (!typeDef.hasBaseType) {
        return false
    }
    if (typeDef.baseType != "System.Object") {
        return false
    }
    return true
}

func renderDelegateSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    if (isWinrtDelegateType(typeDef)) {
        match (guidAttributeString(typeDef)) {
            case Some(guidValue) =>
                match (delegateInvokeMethod(typeDef)) {
                    case Some(invokeMethod) =>
                        return renderWinrtDelegateSymbol(symbol, typeDef, symbolsByName, guidValue, invokeMethod)
                    case None =>
                        return renderUnsupportedWinrtDelegateSymbol(symbol, "missing Invoke method")
                }
            case None =>
                return renderUnsupportedWinrtDelegateSymbol(symbol, "missing GuidAttribute")
        }
    }
    match (delegateCFuncType(typeDef, symbolsByName)) {
        case Some(typeName) => return "public type ${symbol.implName} = ${typeName}"
        case None => return renderRawHandleSymbol(symbol, "delegate")
    }
}

func delegateInvokeMethod(typeDef: TypeDefinitionRecord): Option<MethodRecord> {
    for (method in typeDef.methods) {
        if (method.name == "Invoke") {
            return Some(method)
        }
    }
    return None
}

func renderUnsupportedWinrtDelegateSymbol(symbol: SymbolRecord, reason: String): String {
    return renderRawDelegateHandleSymbol(symbol) + "\n\n" +
        "// WinRT delegate authoring is unavailable for this metadata shape: ${cjStringContent(reason)}.\n" +
        "extend ${symbol.implName} {\n" +
        "    public static func unsupportedDelegateAuthoringReason(): String {\n" +
        "        return \"${cjStringContent(reason)}\"\n" +
        "    }\n\n" +
        "    public static func new(): ${symbol.implName} {\n" +
        "        throw Exception(\"${symbol.implName} cannot be authored as a WinRT delegate: ${cjStringContent(reason)}\")\n" +
        "    }\n" +
        "}"
}

func renderWinrtDelegateSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    guidValue: String,
    invokeMethod: MethodRecord
): String {
    let genericNames = genericParameterNames(typeDef)
    var content = renderWinrtDelegateVtbl(symbol, invokeMethod, symbolsByName)
    content += renderWinrtDelegateWrapper(symbol, typeDef, symbolsByName, guidValue, invokeMethod, genericNames)
    content += renderWinrtDelegateInvoker(symbol, invokeMethod, symbolsByName, genericNames)
    return content
}

func renderWinrtDelegateVtbl(
    symbol: SymbolRecord,
    invokeMethod: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let pairs = winrtDelegateAbiParameterPairs(invokeMethod, symbolsByName, symbol.fullName)
    var content = "@C\npublic struct ${symbol.implName}Vtbl {\n"
    content += "    public var base_: windows_interface.IUnknownVtbl = windows_interface.IUnknownVtbl()\n"
    content += "    public var Invoke: CFunc<(${interfaceCFuncParameterTypes(pairs)}) -> Int32> = " +
        "{ ${interfaceClosurePlaceholders(Int64(pairs.size) + 1)} => windows_core.E_NOTIMPL.value }\n"
    content += "    public init() {}\n"
    content += "}\n\n"
    return content
}

func renderWinrtDelegateWrapper(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    guidValue: String,
    invokeMethod: MethodRecord,
    genericNames: ArrayList<String>
): String {
    let genericParams = genericParameterList(genericNames)
    let genericWhere = genericRuntimeWhereClause(genericNames)
    let genericTypeName = "${symbol.implName}${genericParams}"
    let runtimeName = stripGenericArity(symbol.fullName)
    let abiPairs = winrtDelegateAbiParameterPairs(invokeMethod, symbolsByName, symbol.fullName)
    let projectInvoke = winrtDelegateCanProjectInvoke(invokeMethod, symbolsByName, symbol.fullName)
    let projectedPairs = if (projectInvoke) {
        winrtProjectedMethodParameterPairs(invokeMethod, symbolsByName, symbol.fullName)
    } else {
        abiPairs
    }
    var content = "public open class ${genericTypeName} <: windows_interface.InterfaceWrapperBase & " +
        "windows_interface.ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType & " +
        "windows_interface.DescriptorSchemaProvider${genericWhere} {\n"
    content += "    public init(raw: CPointer<Unit>) {\n"
    content += "        super(raw)\n"
    content += "    }\n\n"
    content += "    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {\n"
    content += "        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)\n"
    content += "    }\n\n"
    content += "    public static func fromAbiTake(raw: CPointer<Unit>): ${genericTypeName} {\n"
    content += "        Owned${symbol.implName}${genericParams}(raw)\n"
    content += "    }\n\n"
    content += "    public static func viewOf(raw: CPointer<Unit>): ${genericTypeName} {\n"
    content += "        ${genericTypeName}(raw, takeOwnership: false, allowManualRelease: false)\n"
    content += "    }\n\n"
    content += "    public static func iid(): windows_interface.GUID {\n"
    if (genericNames.isEmpty()) {
        match (guidAttributeInterfaceExpression(typeDef)) {
            case Some(expr) => content += "        ${expr}\n"
            case None => content += "        windows_interface.GUID.from_signature(${genericTypeName}.signature())\n"
        }
    } else {
        content += "        windows_interface.GUID.from_signature(${genericTypeName}.signature())\n"
    }
    content += "    }\n\n"
    content += "    public static func descriptor(): windows_interface.InterfaceDescriptor<${genericTypeName}> {\n"
    content += "        windows_interface.InterfaceDescriptor<${genericTypeName}>(\"${cjStringContent(runtimeName)}\", " +
        "${genericTypeName}.iid(), [windows_interface.IUnknown.iid()], " +
        "{ raw => ${genericTypeName}.fromAbiTake(raw) }, { raw => ${genericTypeName}.viewOf(raw) })\n"
    content += "    }\n\n"
    content += "    public static func descriptorSchema(): windows_interface.InterfaceDescriptorSchema {\n"
    content += "        var schema = windows_interface.InterfaceDescriptorSchema(\"${cjStringContent(runtimeName)}\", " +
        "${genericTypeName}.iid(), windows_interface.IUnknown.descriptorSchema(), " +
        "\"${symbol.implName}Vtbl\", \"${symbol.implName}\", \"${symbol.implName}Invoker\", " +
        "${winrtDelegateMethodSchemas(invokeMethod, symbolsByName, symbol.fullName)})\n"
    content += "        schema.runtimeTypeContract = Some(${genericTypeName}.runtimeType())\n"
    content += "        return schema\n"
    content += "    }\n\n"
    content += "    public static func abiType(): String {\n"
    content += "        \"CPointer<Unit>\"\n"
    content += "    }\n\n"
    if (genericNames.isEmpty()) {
        content += "    public static func signature(): String {\n"
        content += "        \"${cjStringContent(runtimeName)}\"\n"
        content += "    }\n\n"
    } else {
        content += renderGenericWinrtSignatureFunction(genericTypeName, guidValue, genericNames)
    }
    content += "    public static func runtimeType(): windows_interface.RuntimeTypeContract {\n"
    content += "        windows_interface.RuntimeTypeContract(\"${cjStringContent(runtimeName)}\", " +
        "${genericTypeName}.signature(), ${genericTypeName}.iid())\n"
    content += "    }\n\n"
    content += "    public static func projectionKind(): String {\n"
    content += "        return \"delegate\"\n"
    content += "    }\n"
    content += "\n"
    content += "    public unsafe func vtbl(): ${symbol.implName}Vtbl {\n"
    content += "        readVtbl<${symbol.implName}Vtbl>(${symbol.implName}Vtbl())\n"
    content += "    }\n\n"
    content += "    public unsafe func Invoke(${parameterPairListText(projectedPairs)}): Unit {\n"
    content += "        let liveRaw = asRaw()\n"
    content += "        if (liveRaw.isNull()) {\n"
    content += "            throw windows_core.WindowsException(windows_core.E_POINTER)\n"
    content += "        }\n"
    content += "        let v = vtbl()\n"
    if (projectInvoke) {
        content += "        var hr__ = windows_core.E_POINTER\n"
        content += renderWinrtDelegateProjectedInvokeAbiCall(
            invokeMethod,
            projectedPairs,
            symbolsByName,
            symbol.fullName,
            2
        )
        content += "        hr__.check()\n"
    } else {
        content += "        windows_core.HRESULT(v.Invoke(liveRaw${interfaceMethodCallArguments(abiPairs)})).check()\n"
    }
    content += "    }\n\n"
    content += "    public static func new(invoke: ${delegateClosureType(projectedPairs)}): ${genericTypeName} {\n"
    content += "        let box = ${symbol.implName}Box${genericParams}(invoke)\n"
    content += "        let object = windows_core.ComObject<${symbol.implName}Box${genericParams}>.new(" +
        "box, [${genericTypeName}.descriptorSchema()], box.vtblPtr())\n"
    content += "        return object.intoInterface(${genericTypeName}.descriptor())\n"
    content += "    }\n"
    content += "}\n\n"
    content += "extend${genericParams} ${genericTypeName} <: windows_core.Interface<${genericTypeName}>${genericWhere} {}\n\n"
    content += "private class Owned${symbol.implName}${genericParams} <: ${genericTypeName}${genericWhere} {\n"
    content += "    public init(raw: CPointer<Unit>) {\n"
    content += "        super(raw, takeOwnership: true, allowManualRelease: false)\n"
    content += "    }\n"
    content += "}\n"
    return content
}

func renderWinrtDelegateInvoker(
    symbol: SymbolRecord,
    invokeMethod: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    genericNames: ArrayList<String>
): String {
    let genericParams = genericParameterList(genericNames)
    let genericWhere = genericRuntimeWhereClause(genericNames)
    let abiPairs = winrtDelegateAbiParameterPairs(invokeMethod, symbolsByName, symbol.fullName)
    let projectInvoke = winrtDelegateCanProjectInvoke(invokeMethod, symbolsByName, symbol.fullName)
    let projectedPairs = if (projectInvoke) {
        winrtProjectedMethodParameterPairs(invokeMethod, symbolsByName, symbol.fullName)
    } else {
        abiPairs
    }
    var content = "\npublic interface ${symbol.implName}InvokerErased {\n"
    content += "    func __winrtThunk_Invoke(${parameterPairListText(abiPairs)}): Int32\n"
    content += "}\n\n"
    content += "public interface ${symbol.implName}Invoker${genericParams} <: " +
        "${symbol.implName}InvokerErased${genericWhere} {\n"
    content += "    func Invoke(${parameterPairListText(projectedPairs)}): Unit {\n"
    content += "        ()\n"
    content += "    }\n\n"
    content += "    func __winrtThunk_Invoke(${parameterPairListText(abiPairs)}): Int32 {\n"
    content += "        try {\n"
    if (projectInvoke) {
        content += "            this.Invoke(${winrtDelegateProjectedArguments(invokeMethod, abiPairs, projectedPairs, symbolsByName, symbol.fullName)})\n"
    } else {
        content += "            this.Invoke(${argumentPairListText(abiPairs)})\n"
    }
    content += "            return windows_core.S_OK.value\n"
    content += "        } catch (error: windows_core.WindowsException) {\n"
    content += "            return error.code().value\n"
    content += "        } catch (_: Exception) {\n"
    content += "            return windows_core.E_FAIL.value\n"
    content += "        }\n"
    content += "    }\n"
    content += "}\n\n"
    content += "private class ${symbol.implName}Box${genericParams} <: ${symbol.implName}Invoker${genericParams} & Resource${genericWhere} {\n"
    content += "    public let invoke_: ${delegateClosureType(projectedPairs)}\n"
    content += "    private let vtblHandle: CPointer<${symbol.implName}Vtbl>\n"
    content += "    private var closed: Bool = false\n\n"
    content += "    public init(invoke: ${delegateClosureType(projectedPairs)}) {\n"
    content += "        this.invoke_ = invoke\n"
    content += "        this.vtblHandle = unsafe { windows_interface.allocateNativeValue<${symbol.implName}Vtbl>(" +
        "build${symbol.implName}BoxVtbl${genericParams}()) }\n"
    content += "    }\n\n"
    content += "    public func vtblPtr(): CPointer<Unit> {\n"
    content += "        CPointer<Unit>(vtblHandle)\n"
    content += "    }\n\n"
    content += "    public func isClosed(): Bool {\n"
    content += "        closed\n"
    content += "    }\n\n"
    content += "    ~init() {\n"
    content += "        if (!closed) {\n"
    content += "            closed = true\n"
    content += "        }\n"
    content += "    }\n\n"
    content += "    public func close(): Unit {\n"
    content += "        if (closed) {\n"
    content += "            return\n"
    content += "        }\n"
    content += "        unsafe { windows_interface.freeNativeValue(vtblHandle) }\n"
    content += "        closed = true\n"
    content += "    }\n\n"
    content += "    public func Invoke(${parameterPairListText(projectedPairs)}): Unit {\n"
    content += "        invoke_(${argumentPairListText(projectedPairs)})\n"
    content += "    }\n"
    content += "}\n\n"
    content += "func build${symbol.implName}BoxVtbl${genericParams}(): ${symbol.implName}Vtbl${genericWhere} {\n"
    content += "    var vtbl = ${symbol.implName}Vtbl()\n"
    content += "    vtbl.base_ = windows_core.buildIUnknownVtbl()\n"
    content += "    vtbl.Invoke = { instanceRaw: CPointer<Unit>${delegateClosureTypedParameters(abiPairs)} =>\n"
    content += "        match (unsafe { windows_core.asImplFromRaw<${symbol.implName}InvokerErased>(instanceRaw) }) {\n"
    content += "            case Some(invoker) =>\n"
    content += "                invoker.__winrtThunk_Invoke(${argumentPairListText(abiPairs)})\n"
    content += "            case None =>\n"
    content += "                windows_core.E_NOTIMPL.value\n"
    content += "        }\n"
    content += "    }\n"
    content += "    return vtbl\n"
    content += "}\n"
    return content
}

func guidAttributeInterfaceExpression(typeDef: TypeDefinitionRecord): Option<String> {
    match (guidAttributeValues(typeDef)) {
        case Some(rawValues) =>
            let values = ArrayList<String>()
            var i: Int64 = 0
            while (i < 11) {
                values.add(guidLiteralPart(rawValues[i], i))
                i += 1
            }
            return Some("windows_interface.GUID.from_values(${joinStrings(values, ", ")})")
        case None => return None
    }
}

func winrtDelegateMethodSchemas(
    invokeMethod: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    return "[windows_interface.InterfaceMethodSchema(\"Invoke\", 3, " +
        "${winrtDelegateParameterSchemas(invokeMethod, symbolsByName, ownerFullName)}, \"Int32\")]"
}

func winrtDelegateParameterSchemas(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let pairs = winrtDelegateAbiParameterPairs(method, symbolsByName, ownerFullName)
    if (pairs.isEmpty()) {
        return "Array<windows_interface.InterfaceParameterSchema>(0, { _ => windows_interface.InterfaceParameterSchema(\"\", \"\", \"\", windows_interface.InterfaceParameterBridgeKind.Value) })"
    }
    let rendered = ArrayList<String>()
    for (pair in pairs) {
        rendered.add(
            "windows_interface.InterfaceParameterSchema(\"${pair.name}\", \"${pair.typeName}\", \"${pair.typeName}\", windows_interface.InterfaceParameterBridgeKind.Value)"
        )
    }
    return "[${joinStrings(rendered, ", ")}]"
}

func winrtDelegateAbiParameterPairs(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<ParameterPair> {
    let pairs = ArrayList<ParameterPair>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        let parameterName = interfaceParameterName(parameter, index)
        if (isWinrtArraySignature(signature)) {
            addInterfaceArrayAbiPairs(pairs, parameterName, signature, parameter, symbolsByName, ownerFullName)
        } else {
            pairs.add(ParameterPair(
                parameterName,
                interfaceParameterAbiType(signature, parameter, symbolsByName, ownerFullName)
            ))
        }
        index += 1
    }
    return pairs
}

func winrtDelegateInvokeReturnsUnitLike(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (method.signature.returnType.kind == "Void" || method.signature.returnType.kind == "Unit") {
        return true
    }
    match (hresultRawAbiType(method.signature.returnType, symbolsByName, ownerFullName)) {
        case Some(_) => return true
        case None => return false
    }
}

func winrtDelegateCanProjectInvoke(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (!winrtDelegateInvokeReturnsUnitLike(method, symbolsByName, ownerFullName)) {
        return false
    }
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        if (isOutParameter(parameter) || isByReferenceSignature(signature) || isWinrtArraySignature(signature)) {
            return false
        }
        index += 1
    }
    return true
}

func renderWinrtDelegateProjectedInvokeAbiCall(
    method: MethodRecord,
    projectedPairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    indentLevel: Int64
): String {
    let callPlan = runtimeClassFactoryCallPlan(method, projectedPairs, symbolsByName, ownerFullName)
    let callArgs = ArrayList<String>()
    callArgs.add("liveRaw")
    for (arg in callPlan.args) {
        callArgs.add(arg)
    }
    var content = ""
    var index: Int64 = 0
    while (index < Int64(callPlan.borrows.size)) {
        let borrow = callPlan.borrows[index]
        content += "${runtimeIndent(indentLevel + index)}try (${borrow.name} = windows_core.winrtBorrowGenericIn<${borrow.typeName}>(${borrow.sourceName})) {\n"
        index += 1
    }
    let callIndentLevel = indentLevel + Int64(callPlan.borrows.size)
    content += "${runtimeIndent(callIndentLevel)}hr__ = unsafe { v.Invoke(${joinStrings(callArgs, ", ")}) }\n"
    var closeIndex = Int64(callPlan.borrows.size) - 1
    while (closeIndex >= 0) {
        content += "${runtimeIndent(indentLevel + closeIndex)}}\n"
        closeIndex -= 1
    }
    return content
}

func winrtDelegateProjectedArguments(
    method: MethodRecord,
    abiPairs: ArrayList<ParameterPair>,
    projectedPairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let values = ArrayList<String>()
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        values.add(winrtDelegateProjectedArgument(
            abiPairs[index].name,
            abiPairs[index].typeName,
            projectedPairs[index].typeName,
            signature,
            symbolsByName,
            ownerFullName
        ))
        index += 1
    }
    return joinStrings(values, ", ")
}

func winrtDelegateProjectedArgument(
    name: String,
    abiType: String,
    projectedType: String,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (runtimeCallNeedsHandleBorrow(projectedType, abiType)) {
        return "windows_core.winrtProjectGenericIn<${projectedType}>(${name})"
    }
    if (projectedType == "windows_core.GuidValue" && abiType == "GUID") {
        return "windows_core.GuidValue.fromRaw(${name})"
    }
    if (isEnumSignature(signature, symbolsByName, ownerFullName)) {
        return "${projectedType}(${name})"
    }
    return name
}

func delegateClosureType(pairs: ArrayList<ParameterPair>): String {
    if (pairs.isEmpty()) {
        return "() -> Unit"
    }
    let types = ArrayList<String>()
    for (pair in pairs) {
        types.add(pair.typeName)
    }
    return "(${joinStrings(types, ", ")}) -> Unit"
}

func delegateClosureTypedParameters(pairs: ArrayList<ParameterPair>): String {
    var content = ""
    for (pair in pairs) {
        content += ", ${pair.name}: ${pair.typeName}"
    }
    return content
}

func renderValueStructSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    options: RenderOptions,
    targetAbi: TargetAbiOptions
): String {
    if (!hasPublicInstanceFields(typeDef) && hasLiteralFields(typeDef)) {
        return renderStaticLiteralStructSymbol(symbol, typeDef, symbolsByName)
    }
    if (contains(typeDef.attributes, "ExplicitLayout")) {
        return renderExplicitLayoutStructSymbol(symbol, typeDef, symbolsByName, options, targetAbi)
    }
    var content = "@C\npublic struct ${symbol.implName} {\n"
    var count: Int64 = 0
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            let fieldName = cjIdentifier(field.name)
            let fieldType = cjAbiTypeInContext(field.signature, symbolsByName, symbol.fullName)
            content += "    public var ${fieldName}: ${fieldType} = ${cjDefaultValue(fieldType)}\n"
            content += renderBitfieldProperties(fieldName, fieldType, field)
            count += 1
        }
    }
    if (count == 0) {
        content += "    public var reserved: Int32 = 0\n"
    }
    content += renderLiteralFieldConstants(typeDef, symbolsByName, true)
    if (options.hasDerive("guid_access")) {
        content += renderGuidAccessHelper(typeDef)
    }
    content += "}"
    return content
}

func renderGuidAccessHelper(typeDef: TypeDefinitionRecord): String {
    match (guidAttributeValues(typeDef)) {
        case Some(values) =>
            let parts = ArrayList<String>()
            var i: Int64 = 0
            while (i < 11) {
                parts.add(guidLiteralPart(values[i], i))
                i += 1
            }
            var content = "    public static func GUID(): GUID {\n"
            content += "        return GUID.from_values(${joinStrings(parts, ", ")})\n"
            content += "    }\n"
            return content
        case None => return ""
    }
}

func renderStaticLiteralStructSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    var content = "public struct ${symbol.implName} {\n"
    content += renderLiteralFieldConstants(typeDef, symbolsByName, false)
    content += "}"
    return content
}

func renderBitfieldProperties(fieldName: String, fieldType: String, field: FieldRecord): String {
    let specs = nativeBitfieldSpecs(field)
    if (specs.isEmpty()) {
        return ""
    }
    match (bitfieldReadHelper(fieldType)) {
        case Some(readHelper) =>
            let writeHelper = bitfieldWriteHelper(fieldType).getOrThrow()
            var content = ""
            for (spec in specs) {
                let propName = cjIdentifier(spec.name)
                if (!propName.isEmpty()) {
                    content += "\n"
                    content += "    public mut prop ${propName}: ${fieldType} {\n"
                    content += "        get() {\n"
                    content += "            return windows_polyfill.${readHelper}(${fieldName}, ${spec.bitOffset}, ${spec.bitWidth})\n"
                    content += "        }\n"
                    content += "        set(val) {\n"
                    content += "            ${fieldName} = windows_polyfill.${writeHelper}(${fieldName}, ${spec.bitOffset}, ${spec.bitWidth}, val)\n"
                    content += "        }\n"
                    content += "    }\n"
                }
            }
            return content
        case None => return ""
    }
}

func nativeBitfieldSpecs(field: FieldRecord): ArrayList<NativeBitfieldSpec> {
    let specs = ArrayList<NativeBitfieldSpec>()
    for (attr in field.customAttributes) {
        if (attr.typeName == "Windows.Win32.Foundation.Metadata.NativeBitfieldAttribute" &&
            attr.fixedArguments.size >= 3) {
            match (fixedArgumentString(attr.fixedArguments[0])) {
                case Some(name) =>
                    match (fixedArgumentInt64(attr.fixedArguments[1])) {
                        case Some(bitOffset) =>
                            match (fixedArgumentInt64(attr.fixedArguments[2])) {
                                case Some(bitWidth) => specs.add(NativeBitfieldSpec(name, bitOffset, bitWidth))
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
        }
    }
    return specs
}

func fixedArgumentString(argument: CustomAttributeFixedArgumentRecord): Option<String> {
    match (argument.value) {
        case Some(value) =>
            match (value.kind()) {
                case JsonKind.JsString => return Some(value.asString().getValue())
                case _ => ()
            }
        case None => ()
    }
    return None
}

func fixedArgumentInt64(argument: CustomAttributeFixedArgumentRecord): Option<Int64> {
    match (argument.value) {
        case Some(value) =>
            match (value.kind()) {
                case JsonKind.JsInt => return Some(value.asInt().getValue())
                case _ => ()
            }
        case None => ()
    }
    return None
}

func renderExplicitLayoutStructSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    options: RenderOptions,
    targetAbi: TargetAbiOptions
): String {
    let storage = rawStorageSpec(symbol.fullName, typeDef, symbolsByName, targetAbi)
    var content = "@C\npublic struct ${symbol.implName} {\n"
    content += "    public var _raw: VArray<${storage.typeName}, \$${storage.count}> = " +
        "VArray<${storage.typeName}, \$${storage.count}>(repeat: ${storage.repeatValue})\n"
    var count: Int64 = 0
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            content += "\n"
            content += renderExplicitLayoutProperty(symbol.fullName, field, symbolsByName)
            count += 1
        }
    }
    if (count == 0) {
        content += "\n    public mut prop reserved: UInt8 {\n" +
            "        get() { return 0 }\n" +
            "        set(_) { }\n" +
            "    }\n"
    }
    content += renderLiteralFieldConstants(typeDef, symbolsByName, true)
    if (options.hasDerive("guid_access")) {
        content += renderGuidAccessHelper(typeDef)
    }
    content += "}"
    return content
}

func renderLiteralFieldConstants(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    insideCStruct: Bool
): String {
    var content = ""
    for (field in typeDef.fields) {
        if (isLiteralField(field)) {
            match (literalValue(field.defaultValue)) {
                case Some(value) =>
                    let fieldName = cjIdentifier(field.name)
                    let fieldType = cjConstantType(field.signature, symbolsByName)
                    if (literalFieldRequiresFunction(insideCStruct, fieldType)) {
                        content += "    public static func ${fieldName}(): ${fieldType} {\n"
                        content += "        return ${cjLiteral(value, fieldType)}\n"
                        content += "    }\n"
                    } else if (literalFieldRequiresRuntimeStorage(fieldType)) {
                        content += "    public static let ${fieldName}: ${fieldType} = ${cjLiteral(value, fieldType)}\n"
                    } else {
                        content += "    public static const ${fieldName}: ${fieldType} = ${cjLiteral(value, fieldType)}\n"
                    }
                case None => ()
            }
        } else if (isPublicStaticField(field)) {
            let extra = renderApisFieldConstant(field, symbolsByName)
            if (!extra.isEmpty()) {
                content += extra
            }
        }
    }
    return content
}

func literalFieldRequiresFunction(insideCStruct: Bool, fieldType: String): Bool {
    insideCStruct && (fieldType == "String" || literalFieldRequiresRuntimeStorage(fieldType))
}

func literalFieldRequiresRuntimeStorage(fieldType: String): Bool {
    fieldType == "windows_strings.WideStringFactory" ||
    fieldType == "windows_strings.NarrowStringFactory"
}

func renderApisFieldConstants(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    var content = ""
    for (field in typeDef.fields) {
        if (!isPublicStaticField(field)) {
            continue
        }
        content += renderApisFieldConstant(field, symbolsByName)
    }
    return content
}

func isPublicStaticField(field: FieldRecord): Bool {
    return contains(field.attributes, "Public") &&
        contains(field.attributes, "Static")
}

func renderApisFieldConstant(
    field: FieldRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let fieldName = cjIdentifier(field.name)

    match (literalValue(field.defaultValue)) {
        case Some(value) =>
            let fieldType = cjConstantType(field.signature, symbolsByName)
            if (!isSimpleConstantFieldType(field.signature, fieldType, symbolsByName)) {
                match (renderHandleStructLiteralConstant(fieldName, field, fieldType, value, symbolsByName)) {
                    case Some(rendered) => return rendered
                    case None => return ""
                }
            }
            if (literalFieldRequiresFunction(false, fieldType) ||
                literalFieldRequiresRuntimeStorage(fieldType)) {
                return "    public static func ${fieldName}(): ${fieldType} {\n" +
                    "        return ${cjLiteral(value, fieldType)}\n" +
                    "    }\n"
            }
            return "    public static const ${fieldName}: ${fieldType} = ${cjLiteral(value, fieldType)}\n"
        case None => ()
    }

    match (fieldGuidAttributeValues(field)) {
        case Some(values) =>
            return renderFieldGuidConstant(fieldName, values)
        case None => ()
    }

    match (fieldConstantAttributeText(field)) {
        case Some(text) =>
            match (renderFieldConstantAttribute(fieldName, field, text, symbolsByName)) {
                case Some(rendered) => return rendered
                case None => return ""
            }
        case None => ()
    }

    return ""
}

func renderHandleStructLiteralConstant(
    fieldName: String,
    field: FieldRecord,
    fieldType: String,
    value: JsonValue,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    let _ = fieldType
    let fullName = signatureFullNameInContext(field.signature, symbolsByName, "")
    match (fullName) {
        case Some(name) =>
            if (startsWith(name, "System.")) {
                return None
            }
            match (win32ScalarRawAbiTypeByFullName(name)) {
                case Some(_) => return None
                case None => ()
            }
            match (stringHandleRawAbiTypeByFullName(name)) {
                case Some(_) => return None
                case None => ()
            }
            match (hresultRawAbiTypeByFullName(name)) {
                case Some(_) => return None
                case None => ()
            }
            match (eventRegistrationTokenRawAbiTypeByFullName(name)) {
                case Some(_) => return None
                case None => ()
            }
            match (win32TextPointerRawAbiTypeByFullName(name)) {
                case Some(_) => return None
                case None => ()
            }
            match (symbolsByName.get(name)) {
                case Some(targetSymbol) =>
                    match (targetSymbol.typeDef) {
                        case Some(targetDef) =>
                            if (!isValueType(targetDef) || isEnumType(targetDef)) {
                                return None
                            }
                            if (!hasNativeTypedefAttribute(targetDef)) {
                                return None
                            }
                            match (handleStructFieldInfo(targetDef, symbolsByName)) {
                                case Some(info) =>
                                    let literal = handleStructFieldLiteral(value, info.cjFieldType)
                                    match (literal) {
                                        case Some(rendered) =>
                                            let structType = qualifyMangledFullName(name)
                                            var content = "    public static func ${fieldName}(): ${structType} {\n"
                                            content += "        var value = ${structType}()\n"
                                            content += "        value.${info.cjFieldName} = ${rendered}\n"
                                            content += "        return value\n"
                                            content += "    }\n"
                                            return Some(content)
                                        case None => return None
                                    }
                                case None => return None
                            }
                        case None => return None
                    }
                case None => return None
            }
        case None => return None
    }
}

func hasNativeTypedefAttribute(typeDef: TypeDefinitionRecord): Bool {
    for (attr in typeDef.customAttributes) {
        if (hasAttributeName(attr, "NativeTypedefAttribute")) {
            return true
        }
    }
    return false
}

class HandleFieldInfo {
    public let cjFieldName: String
    public let cjFieldType: String

    public init(cjFieldName: String, cjFieldType: String) {
        this.cjFieldName = cjFieldName
        this.cjFieldType = cjFieldType
    }
}

func handleStructFieldInfo(
    targetDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<HandleFieldInfo> {
    var found: Option<HandleFieldInfo> = None
    var count: Int64 = 0
    for (targetField in targetDef.fields) {
        if (!isPublicInstanceField(targetField)) {
            continue
        }
        if (targetField.name == "value__") {
            continue
        }
        count += 1
        if (count > 1) {
            return None
        }
        let cjFieldName = cjIdentifier(targetField.name)
        let cjFieldType = cjAbiTypeInContext(targetField.signature, symbolsByName, targetDef.fullName())
        found = Some(HandleFieldInfo(cjFieldName, cjFieldType))
    }
    return found
}

func handleStructFieldLiteral(value: JsonValue, cjFieldType: String): Option<String> {
    match (value.kind()) {
        case JsonKind.JsInt =>
            let raw = value.asInt().getValue()
            if (cjFieldType == "CPointer<Unit>") {
                return Some("windows_polyfill.handlePointerFromInt(${raw}i64)")
            }
            if (startsWith(cjFieldType, "CPointer<")) {
                return Some("unsafe { ${cjFieldType}(windows_polyfill.handlePointerFromInt(${raw}i64)) }")
            }
            if (cjFieldType == "IntNative") {
                return Some("IntNative(${raw}i64)")
            }
            if (cjFieldType == "UIntNative") {
                return Some("UIntNative(${raw}i64)")
            }
            if (cjFieldType == "Int8" || cjFieldType == "Int16" || cjFieldType == "Int32" ||
                cjFieldType == "Int64" || cjFieldType == "UInt8" || cjFieldType == "UInt16" ||
                cjFieldType == "UInt32" || cjFieldType == "UInt64") {
                return Some("${raw}${integerLiteralSuffix(cjFieldType)}")
            }
            return None
        case _ => return None
    }
}

func integerLiteralSuffix(cjType: String): String {
    match (cjType) {
        case "Int8" => return "i8"
        case "Int16" => return "i16"
        case "Int32" => return "i32"
        case "Int64" => return "i64"
        case "UInt8" => return "u8"
        case "UInt16" => return "u16"
        case "UInt32" => return "u32"
        case "UInt64" => return "u64"
        case _ => return ""
    }
}

func isSimpleConstantFieldType(
    signature: SignatureRecord,
    fieldType: String,
    symbolsByName: HashMap<String, SymbolRecord>
): Bool {
    if (signature.kind == "Primitive") {
        return true
    }
    if (fieldType == "String") {
        return true
    }
    if (literalFieldRequiresRuntimeStorage(fieldType)) {
        return true
    }
    match (signatureFullNameInContext(signature, symbolsByName, "")) {
        case Some(fullName) =>
            if (startsWith(fullName, "System.")) {
                return fullName != "System.Guid" && fullName != "System.Object"
            }
            match (symbolsByName.get(fullName)) {
                case Some(symbol) =>
                    match (symbol.typeDef) {
                        case Some(typeDef) =>
                            if (isEnumType(typeDef)) {
                                return true
                            }
                            return false
                        case None => return false
                    }
                case None => return false
            }
        case None => ()
    }
    return false
}

func fieldGuidAttributeValues(field: FieldRecord): Option<ArrayList<Int64>> {
    for (attr in field.customAttributes) {
        if (hasAttributeName(attr, "GuidAttribute") && attr.fixedArguments.size >= 11) {
            let raw = ArrayList<Int64>()
            var i: Int64 = 0
            while (i < 11) {
                match (fixedArgumentInt64(attr.fixedArguments[i])) {
                    case Some(value) => raw.add(value)
                    case None => return None
                }
                i += 1
            }
            return Some(raw)
        }
    }
    return None
}

func renderFieldGuidConstant(fieldName: String, values: ArrayList<Int64>): String {
    let parts = ArrayList<String>()
    var i: Int64 = 0
    while (i < 11) {
        parts.add(guidLiteralPart(values[i], i))
        i += 1
    }
    var content = "    public static func ${fieldName}(): windows_interface.GUID {\n"
    content += "        return windows_interface.GUID.from_values(${joinStrings(parts, ", ")})\n"
    content += "    }\n"
    return content
}

func fieldConstantAttributeText(field: FieldRecord): Option<String> {
    for (attr in field.customAttributes) {
        if (hasAttributeName(attr, "ConstantAttribute") && attr.fixedArguments.size >= 1) {
            return fixedArgumentString(attr.fixedArguments[0])
        }
    }
    return None
}

func renderFieldConstantAttribute(
    fieldName: String,
    field: FieldRecord,
    input: String,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    let fullName = signatureFullNameInContext(field.signature, symbolsByName, "")
    match (fullName) {
        case Some(name) =>
            match (symbolsByName.get(name)) {
                case Some(targetSymbol) =>
                    match (targetSymbol.typeDef) {
                        case Some(targetDef) =>
                            if (!isValueType(targetDef)) {
                                return None
                            }
                            let typeName = qualifyMangledFullName(name)
                            return Some(renderConstantStructFromAttribute(
                                fieldName,
                                typeName,
                                targetDef,
                                input,
                                symbolsByName,
                                name
                            ))
                        case None => return None
                    }
                case None => return None
            }
        case None => return None
    }
}

func renderConstantStructFromAttribute(
    fieldName: String,
    typeName: String,
    targetDef: TypeDefinitionRecord,
    input: String,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let parser = ConstantAttributeParser(input)
    var content = "    public static func ${fieldName}(): ${typeName} {\n"
    content += "        var value = ${typeName}()\n"
    for (targetField in targetDef.fields) {
        if (!isPublicInstanceField(targetField)) {
            continue
        }
        let cjFieldName = cjIdentifier(targetField.name)
        let cjFieldType = cjAbiTypeInContext(targetField.signature, symbolsByName, ownerFullName)
        match (constantAttributeFieldAssignments(
            "value.${cjFieldName}", targetField.signature, cjFieldType, symbolsByName, parser
        )) {
            case Some(assignments) => content += assignments
            case None =>
                throw Exception(
                    "ConstantAttribute for ${ownerFullName}.${fieldName} contains unsupported field ${cjFieldName}: ${cjFieldType}"
                )
        }
    }
    content += "        return value\n"
    content += "    }\n"
    return content
}

func constantAttributeFieldAssignments(
    target: String,
    signature: SignatureRecord,
    fieldType: String,
    symbolsByName: HashMap<String, SymbolRecord>,
    parser: ConstantAttributeParser
): Option<String> {
    let fullName = signatureFullNameInContext(signature, symbolsByName, "")
    match (fullName) {
        case Some(name) =>
            if (name == "System.Guid") {
                return Some(constantAttributeGuidAssignment(target, fieldType, parser))
            }
        case None => ()
    }
    if (signature.kind == "Array") {
        match (signature.sizes) {
            case Some(sizes) =>
                if (sizes.size == 1 && sizes[0] > 0) {
                    return Some(constantAttributeArrayAssignment(target, fieldType, sizes[0], parser))
                }
            case None => ()
        }
        return None
    }
    if (signature.kind == "Pointer" || isByReferenceSignature(signature) || signature.kind == "SZArray") {
        let _ = parser.readLiteral()
        return Some("        ${target} = ${fieldType}()\n")
    }
    if (signature.kind == "Primitive") {
        match (parser.readLiteral()) {
            case Some(literal) =>
                return Some("        ${target} = ${literal}\n")
            case None => return None
        }
    }
    // Fallback: try a single literal.
    match (parser.readLiteral()) {
        case Some(literal) =>
            return Some("        ${target} = ${literal}\n")
        case None => return None
    }
}

func constantAttributeGuidAssignment(target: String, fieldType: String, parser: ConstantAttributeParser): String {
    let literals = parser.readBracedLiterals(11)
    let values = ArrayList<Int64>()
    var i: Int64 = 0
    while (i < literals.size) {
        match (parseDecimalInt64Signed(literals[i])) {
            case Some(value) => values.add(value)
            case None => values.add(0)
        }
        i += 1
    }
    while (values.size < 11) {
        values.add(0)
    }
    if (fieldType == "windows_interface.GUID" || fieldType == "GUID") {
        let parts = ArrayList<String>()
        var j: Int64 = 0
        while (j < 11) {
            parts.add(guidLiteralPart(values[j], j))
            j += 1
        }
        return "        ${target} = windows_interface.GUID.from_values(${joinStrings(parts, ", ")})\n"
    }
    return "        ${target} = ${fieldType}()\n"
}

func constantAttributeArrayAssignment(
    target: String,
    fieldType: String,
    length: Int64,
    parser: ConstantAttributeParser
): String {
    let literals = parser.readBracedLiterals(length)
    let suffix = vArrayElementLiteralSuffix(fieldType)
    let repeatValue = "0${suffix}"
    var content = ""
    content += "        ${target} = ${fieldType}(repeat: ${repeatValue})\n"
    var i: Int64 = 0
    while (i < length) {
        var literal = repeatValue
        if (i < literals.size) {
            literal = "${literals[i]}${suffix}"
        }
        content += "        ${target}[${i}] = ${literal}\n"
        i += 1
    }
    return content
}

func vArrayElementLiteralSuffix(varrayType: String): String {
    match (vArrayElementTypeName(varrayType)) {
        case Some(element) => return numericLiteralSuffix(element)
        case None => return ""
    }
}

func numericLiteralSuffix(typeName: String): String {
    match (typeName) {
        case "UInt8" => return "u8"
        case "UInt16" => return "u16"
        case "UInt32" => return "u32"
        case "UInt64" => return "u64"
        case "Int8" => return "i8"
        case "Int16" => return "i16"
        case "Int32" => return "i32"
        case "Int64" => return "i64"
        case _ => return ""
    }
}

func parseDecimalInt64Signed(value: String): Option<Int64> {
    let bytes = value.toArray()
    if (bytes.isEmpty()) {
        return None
    }
    var start: Int64 = 0
    var negative = false
    if (bytes[0] == b'-') {
        negative = true
        start = 1
    }
    if (start >= Int64(bytes.size)) {
        return None
    }
    var result: Int64 = 0
    var i: Int64 = start
    while (i < Int64(bytes.size)) {
        let byte = bytes[i]
        if (byte < b'0' || byte > b'9') {
            return None
        }
        result = result * 10 + Int64(byte - b'0')
        i += 1
    }
    if (negative) {
        result = -result
    }
    return Some(result)
}

class ConstantAttributeParser {
    private let bytes: Array<UInt8>
    private var position: Int64

    public init(input: String) {
        this.bytes = input.toArray()
        this.position = 0
    }

    public func readBracedLiterals(count: Int64): ArrayList<String> {
        let result = ArrayList<String>()
        skipWhitespaceAndCommas()
        if (position < Int64(bytes.size) && bytes[position] == b'{') {
            position += 1
        }
        var index: Int64 = 0
        while (index < count) {
            match (readLiteral()) {
                case Some(literal) => result.add(literal)
                case None => break
            }
            index += 1
        }
        skipWhitespaceAndCommas()
        if (position < Int64(bytes.size) && bytes[position] == b'}') {
            position += 1
        }
        return result
    }

    public func readLiteral(): Option<String> {
        skipWhitespaceAndCommas()
        if (position >= Int64(bytes.size)) {
            return None
        }
        let start = position
        while (position < Int64(bytes.size)) {
            let byte = bytes[position]
            if (byte == b' ' || byte == b',' || byte == b'}' || byte == b'{') {
                break
            }
            position += 1
        }
        if (position == start) {
            return None
        }
        return Some(String.fromUtf8(bytes[start..position]))
    }

    private func skipWhitespaceAndCommas(): Unit {
        while (position < Int64(bytes.size)) {
            let byte = bytes[position]
            if (byte == b' ' || byte == b',') {
                position += 1
            } else {
                break
            }
        }
    }
}

func renderExplicitLayoutProperty(
    ownerFullName: String,
    field: FieldRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let fieldName = cjIdentifier(field.name)
    let fieldType = cjAbiTypeInContext(field.signature, symbolsByName, ownerFullName)
    var content = "    public mut prop ${fieldName}: ${fieldType} {\n"
    content += "        get() {\n"
    content += "            unsafe {\n"
    content += "                var rawStorage = _raw\n"
    content += "                let base = CPointer<UInt8>(inout rawStorage)\n"
    match (unionReadHelper(fieldType)) {
        case Some(helper) =>
            content += "                return windows_polyfill.${helper}(base, ${field.offset})\n"
        case None =>
            content += renderPointerViewRead(fieldType, field.offset)
    }
    content += "            }\n"
    content += "        }\n"
    content += "        set(val) {\n"
    content += "            unsafe {\n"
    content += "                var rawStorage = _raw\n"
    content += "                let base = CPointer<UInt8>(inout rawStorage)\n"
    match (unionWriteHelper(fieldType)) {
        case Some(helper) =>
            content += "                windows_polyfill.${helper}(base, ${field.offset}, val)\n"
        case None =>
            content += renderPointerViewWrite(fieldType, field.offset)
    }
    content += "                _raw = rawStorage\n"
    content += "            }\n"
    content += "        }\n"
    content += "    }\n"
    return content
}

func renderPointerViewRead(fieldType: String, offset: Int64): String {
    var content = ""
    if (offset == 0) {
        content += "                let p = base\n"
    } else {
        content += "                let p = base + ${offset}\n"
    }
    content += "                let ptr = CPointer<${fieldType}>(p)\n"
    content += "                return ptr.read()\n"
    return content
}

func renderPointerViewWrite(fieldType: String, offset: Int64): String {
    var content = ""
    if (offset == 0) {
        content += "                let p = base\n"
    } else {
        content += "                let p = base + ${offset}\n"
    }
    content += "                let ptr = CPointer<${fieldType}>(p)\n"
    content += "                ptr.write(val)\n"
    return content
}

func rawStorageSpec(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): RawStorageSpec {
    return rawStorageSpec(ownerFullName, typeDef, symbolsByName, TargetAbiOptions.defaults())
}

func rawStorageSpec(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    targetAbi: TargetAbiOptions
): RawStorageSpec {
    let size = layoutSize(ownerFullName, typeDef, symbolsByName, targetAbi)
    let alignment = layoutAlignment(ownerFullName, typeDef, symbolsByName, targetAbi)
    if (alignment >= 8 && size % 8 == 0) {
        return RawStorageSpec("UInt64", size / 8, "0u64")
    }
    if (alignment >= 4 && size % 4 == 0) {
        return RawStorageSpec("UInt32", size / 4, "0u32")
    }
    if (alignment >= 2 && size % 2 == 0) {
        return RawStorageSpec("UInt16", size / 2, "0u16")
    }
    return RawStorageSpec("UInt8", size, "0u8")
}

func layoutSize(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Int64 {
    return layoutSize(ownerFullName, typeDef, symbolsByName, TargetAbiOptions.defaults())
}

func layoutSize(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    targetAbi: TargetAbiOptions
): Int64 {
    var size = declaredLayoutSize(typeDef)
    var inferred: Int64 = 0
    if (contains(typeDef.attributes, "ExplicitLayout")) {
        inferred = explicitLayoutSize(ownerFullName, typeDef, symbolsByName, targetAbi)
    } else {
        inferred = sequentialLayoutSize(ownerFullName, typeDef, symbolsByName, targetAbi)
    }
    if (inferred > size) {
        size = inferred
    }
    if (size > 0) {
        return size
    }
    return 1
}

func declaredLayoutSize(typeDef: TypeDefinitionRecord): Int64 {
    match (typeDef.layout) {
        case Some(layout) =>
            if (layout.size > 0) {
                return layout.size
            }
        case None => ()
    }
    return 1
}

func explicitLayoutSize(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Int64 {
    return explicitLayoutSize(ownerFullName, typeDef, symbolsByName, TargetAbiOptions.defaults())
}

func explicitLayoutSize(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    targetAbi: TargetAbiOptions
): Int64 {
    var size: Int64 = 0
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            let fieldType = cjAbiTypeInContext(field.signature, symbolsByName, ownerFullName)
            let end = field.offset + abiTypeSize(fieldType, symbolsByName, targetAbi)
            if (end > size) {
                size = end
            }
        }
    }
    return size
}

func sequentialLayoutSize(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Int64 {
    return sequentialLayoutSize(ownerFullName, typeDef, symbolsByName, TargetAbiOptions.defaults())
}

func sequentialLayoutSize(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    targetAbi: TargetAbiOptions
): Int64 {
    var offset: Int64 = 0
    var maxAlignment: Int64 = 1
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            let fieldType = cjAbiTypeInContext(field.signature, symbolsByName, ownerFullName)
            let fieldAlignment = effectiveFieldAlignment(typeDef, abiTypeAlignment(fieldType, symbolsByName, targetAbi))
            if (fieldAlignment > maxAlignment) {
                maxAlignment = fieldAlignment
            }
            offset = alignUp(offset, fieldAlignment)
            offset += abiTypeSize(fieldType, symbolsByName, targetAbi)
        }
    }
    return alignUp(offset, maxAlignment)
}

func layoutAlignment(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Int64 {
    return layoutAlignment(ownerFullName, typeDef, symbolsByName, TargetAbiOptions.defaults())
}

func layoutAlignment(
    ownerFullName: String,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    targetAbi: TargetAbiOptions
): Int64 {
    var alignment: Int64 = 1
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            let fieldAlignment = effectiveFieldAlignment(
                typeDef,
                abiTypeAlignment(cjAbiTypeInContext(field.signature, symbolsByName, ownerFullName), symbolsByName, targetAbi)
            )
            if (fieldAlignment > alignment) {
                alignment = fieldAlignment
            }
        }
    }
    return alignment
}

func effectiveFieldAlignment(typeDef: TypeDefinitionRecord, fieldAlignment: Int64): Int64 {
    match (typeDef.layout) {
        case Some(layout) =>
            if (layout.packingSize > 0 && layout.packingSize < fieldAlignment) {
                return layout.packingSize
            }
        case None => ()
    }
    return fieldAlignment
}

func alignUp(value: Int64, alignment: Int64): Int64 {
    if (alignment <= 1) {
        return value
    }
    let remainder = value % alignment
    if (remainder == 0) {
        return value
    }
    return value + alignment - remainder
}

func abiTypeAlignment(typeName: String, symbolsByName: HashMap<String, SymbolRecord>): Int64 {
    return abiTypeAlignment(typeName, symbolsByName, TargetAbiOptions.defaults())
}

func abiTypeAlignment(
    typeName: String,
    symbolsByName: HashMap<String, SymbolRecord>,
    targetAbi: TargetAbiOptions
): Int64 {
    if (typeName == "UInt64" || typeName == "Int64" || typeName == "Float64") {
        return 8
    }
    if (typeName == "UIntNative" || typeName == "IntNative" ||
        startsWith(typeName, "CPointer<") || startsWith(typeName, "CFunc<")) {
        return targetAbi.pointerSize
    }
    if (typeName == "UInt32" || typeName == "Int32" || typeName == "Float32") {
        return 4
    }
    if (typeName == "UInt16" || typeName == "Int16") {
        return 2
    }
    if (startsWith(typeName, "VArray<")) {
        match (vArrayElementTypeName(typeName)) {
            case Some(elementType) => return abiTypeAlignment(elementType, symbolsByName, targetAbi)
            case None => ()
        }
    }
    if (typeName == "Bool" || typeName == "UInt8" || typeName == "Int8") {
        return 1
    }
    for ((_, symbol) in symbolsByName) {
        if (symbol.implName == typeName) {
            match (symbol.typeDef) {
                case Some(typeDef) => return layoutAlignment(symbol.fullName, typeDef, symbolsByName, targetAbi)
                case None => return 1
            }
        }
    }
    return 1
}

func abiTypeSize(typeName: String, symbolsByName: HashMap<String, SymbolRecord>): Int64 {
    return abiTypeSize(typeName, symbolsByName, TargetAbiOptions.defaults())
}

func abiTypeSize(
    typeName: String,
    symbolsByName: HashMap<String, SymbolRecord>,
    targetAbi: TargetAbiOptions
): Int64 {
    if (typeName == "Bool" || typeName == "UInt8" || typeName == "Int8") {
        return 1
    }
    if (typeName == "UInt16" || typeName == "Int16") {
        return 2
    }
    if (typeName == "UInt32" || typeName == "Int32" || typeName == "Float32") {
        return 4
    }
    if (typeName == "UInt64" || typeName == "Int64" || typeName == "Float64") {
        return 8
    }
    if (typeName == "UIntNative" || typeName == "IntNative" ||
        startsWith(typeName, "CPointer<") || startsWith(typeName, "CFunc<")) {
        return targetAbi.pointerSize
    }
    if (startsWith(typeName, "VArray<")) {
        match (vArrayElementTypeName(typeName)) {
            case Some(elementType) =>
                match (vArrayCount(typeName)) {
                    case Some(count) => return abiTypeSize(elementType, symbolsByName, targetAbi) * count
                    case None => ()
                }
            case None => ()
        }
    }
    for ((_, symbol) in symbolsByName) {
        if (symbol.implName == typeName) {
            match (symbol.typeDef) {
                case Some(typeDef) => return layoutSize(symbol.fullName, typeDef, symbolsByName, targetAbi)
                case None => return 1
            }
        }
    }
    return 1
}

func unionReadHelper(typeName: String): Option<String> {
    match (typeName) {
        case "UInt8" => return Some("unionReadUInt8")
        case "Int8" => return Some("unionReadInt8")
        case "UInt16" => return Some("unionReadUInt16")
        case "Int16" => return Some("unionReadInt16")
        case "UInt32" => return Some("unionReadUInt32")
        case "Int32" => return Some("unionReadInt32")
        case "UInt64" => return Some("unionReadUInt64")
        case "Int64" => return Some("unionReadInt64")
        case "Float32" => return Some("unionReadFloat32")
        case "Float64" => return Some("unionReadFloat64")
        case _ => return None
    }
}

func unionWriteHelper(typeName: String): Option<String> {
    match (typeName) {
        case "UInt8" => return Some("unionWriteUInt8")
        case "Int8" => return Some("unionWriteInt8")
        case "UInt16" => return Some("unionWriteUInt16")
        case "Int16" => return Some("unionWriteInt16")
        case "UInt32" => return Some("unionWriteUInt32")
        case "Int32" => return Some("unionWriteInt32")
        case "UInt64" => return Some("unionWriteUInt64")
        case "Int64" => return Some("unionWriteInt64")
        case "Float32" => return Some("unionWriteFloat32")
        case "Float64" => return Some("unionWriteFloat64")
        case _ => return None
    }
}

func bitfieldReadHelper(typeName: String): Option<String> {
    match (typeName) {
        case "UInt8" => return Some("bitfieldReadUInt8")
        case "UInt16" => return Some("bitfieldReadUInt16")
        case "UInt32" => return Some("bitfieldReadUInt32")
        case "UInt64" => return Some("bitfieldReadUInt64")
        case _ => return None
    }
}

func bitfieldWriteHelper(typeName: String): Option<String> {
    match (typeName) {
        case "UInt8" => return Some("bitfieldWriteUInt8")
        case "UInt16" => return Some("bitfieldWriteUInt16")
        case "UInt32" => return Some("bitfieldWriteUInt32")
        case "UInt64" => return Some("bitfieldWriteUInt64")
        case _ => return None
    }
}

func renderEnumSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    options: RenderOptions
): String {
    let underlying = enumUnderlyingType(typeDef, symbolsByName)
    var content = "public struct ${symbol.implName} {\n" +
        "    public let value: ${underlying}\n" +
        "    public init() {\n" +
        "        this.value = ${cjLiteralInt("0", underlying)}\n" +
        "    }\n" +
        "    public init(value: ${underlying}) {\n" +
        "        this.value = value\n" +
        "    }\n"
    let isFlags = hasSystemFlagsAttribute(typeDef.customAttributes)
    if (isFlags) {
        content += renderFlagsEnumHelpers(symbol.implName)
    }
    if (isFlags && options.hasDerive("flags_ops")) {
        content += renderFlagsEnumExtendedHelpers(symbol.implName)
    }
    content += "}"
    for (field in typeDef.fields) {
        if (isEnumLiteral(field)) {
            match (literalValue(field.defaultValue)) {
                case Some(value) =>
                    content += "\npublic let ${symbol.implName}_${cjIdentifier(field.name)} = " +
                        "${symbol.implName}(${cjLiteral(value, underlying)})"
                case None => ()
            }
        }
    }
    return content
}

func renderFlagsEnumExtendedHelpers(typeName: String): String {
    var content = "    public func toggle(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value ^ other.value)\n"
    content += "    }\n"
    content += "    public func intersect(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value & other.value)\n"
    content += "    }\n"
    content += "    public func union(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value | other.value)\n"
    content += "    }\n"
    content += "    public func difference(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value & !other.value)\n"
    content += "    }\n"
    content += "    public func symmetric_difference(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value ^ other.value)\n"
    content += "    }\n"
    return content
}

func renderRawAliasSymbol(symbol: SymbolRecord, typeDef: TypeDefinitionRecord, rawType: String): String {
    var content = "public type ${symbol.implName} = ${rawType}"
    for (field in typeDef.fields) {
        if (isEnumLiteral(field)) {
            match (literalValue(field.defaultValue)) {
                case Some(value) =>
                    content += "\npublic let ${symbol.implName}_${cjIdentifier(field.name)}: ${symbol.implName} = " +
                        cjLiteral(value, rawType)
                case None => ()
            }
        }
    }
    return content
}

func hasSystemFlagsAttribute(attributes: ArrayList<CustomAttributeRecord>): Bool {
    for (attribute in attributes) {
        if (attribute.typeName == "System.FlagsAttribute" || attribute.typeName == "FlagsAttribute") {
            return true
        }
    }
    return false
}

func renderFlagsEnumHelpers(typeName: String): String {
    var content = "    public func contains(other: ${typeName}): Bool {\n"
    content += "        return (value & other.value) == other.value\n"
    content += "    }\n"
    content += "    public operator func |(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value | other.value)\n"
    content += "    }\n"
    content += "    public operator func &(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value & other.value)\n"
    content += "    }\n"
    content += "    public operator func ^(other: ${typeName}): ${typeName} {\n"
    content += "        return ${typeName}(value ^ other.value)\n"
    content += "    }\n"
    content += "    public operator func !(): ${typeName} {\n"
    content += "        return ${typeName}(!value)\n"
    content += "    }\n"
    return content
}

func renderPInvokeSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    options: RenderOptions,
    targetAbi: TargetAbiOptions
): String {
    var content = "public struct ${symbol.implName} {\n"
    content += "    public init() {}\n"
    for (method in typeDef.methods) {
        match (method.methodImport) {
            case Some(methodImport) =>
                validatePInvokeCallingConvention(method, methodImport, targetAbi)
                let params = methodParameterText(method, true, symbolsByName)
                let args = methodArgumentText(method, true, symbolsByName)
                let returnType = cjAbiType(method.signature.returnType, symbolsByName)
                let safeName = cjIdentifier(method.name)
                let procType = pinvokeCFuncType(method, returnType, symbolsByName)
                let moduleName = cjStringContent(methodImport.moduleName)
                let importName = cjStringContent(pinvokeImportName(method))
                content += "    public static func ${safeName}(${params}): ${returnType} {\n"
                content += "        let proc = ${procType}(windows_libloading.resolveProc(\"${moduleName}\", \"${importName}\"))\n"
                if (returnType == "Unit") {
                    content += "        unsafe { proc(${args}) }\n"
                } else {
                    content += "        return unsafe { proc(${args}) }\n"
                }
                content += "    }\n"
                if (options.ergonomicWrappers && !options.sys) {
                    content += renderPInvokeErgonomicWrapper(symbol.implName, method, methodImport, symbolsByName)
                }
            case None => ()
        }
    }
    content += renderApisFieldConstants(typeDef, symbolsByName)
    content += "}"
    return content
}

func validatePInvokeCallingConvention(
    method: MethodRecord,
    methodImport: MethodImportRecord,
    targetAbi: TargetAbiOptions
): Unit {
    let callingConvention = methodImport.callingConvention
    if (callingConvention.isEmpty() || callingConvention == "Default" || callingConvention == "CDecl") {
        return
    }
    if (callingConvention == "WinApi") {
        if (targetAbi.pointerSize == 4) {
            throw Exception(
                "P/Invoke ${method.name} uses WinApi calling convention on a 32-bit target; " +
                "dynamic CFunc(resolveProc) bindings cannot emit @CallingConv[STDCALL]"
            )
        }
        return
    }
    throw Exception(
        "P/Invoke ${method.name} uses unsupported calling convention ${callingConvention}; " +
        "dynamic CFunc(resolveProc) bindings only support CDecl/default and WinApi on 64-bit targets"
    )
}

func renderPInvokeErgonomicWrapper(
    ownerImplName: String,
    method: MethodRecord,
    methodImport: MethodImportRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let hint = pinvokeReturnHint(method, symbolsByName)
    match (hint) {
        case PInvokeReturnHint.None => return ""
        case _ => ()
    }
    let sysName = cjIdentifier(method.name)
    let wrapperName = ergonomicWrapperName(sysName)
    if (wrapperName == sysName) {
        return ""
    }
    match (hint) {
        case PInvokeReturnHint.Query =>
            return renderPInvokeQueryWrapper(ownerImplName, method, sysName, wrapperName, symbolsByName)
        case PInvokeReturnHint.ResultValue =>
            return renderPInvokeResultValueWrapper(ownerImplName, method, sysName, wrapperName, symbolsByName)
        case PInvokeReturnHint.ResultVoid =>
            return renderPInvokeResultVoidWrapper(ownerImplName, method, sysName, wrapperName, symbolsByName)
        case PInvokeReturnHint.LastErrorBool =>
            return renderPInvokeLastErrorWrapper(ownerImplName, method, sysName, wrapperName, symbolsByName)
        case PInvokeReturnHint.LastErrorBoolStatus =>
            return renderPInvokeLastErrorBoolStatusWrapper(ownerImplName, method, sysName, wrapperName, symbolsByName)
        case PInvokeReturnHint.LastErrorBoolFalseSuccess =>
            return renderPInvokeLastErrorBoolFalseSuccessWrapper(ownerImplName, method, sysName, wrapperName, symbolsByName)
        case PInvokeReturnHint.None => return ""
    }
}

enum PInvokeReturnHint {
    | None
    | Query
    | ResultValue
    | ResultVoid
    | LastErrorBool
    | LastErrorBoolStatus
    | LastErrorBoolFalseSuccess
}

func ergonomicWrapperName(sysName: String): String {
    return "${sysName}Checked"
}

func pinvokeReturnHint(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): PInvokeReturnHint {
    let returnFullName = signatureFullNameInContext(method.signature.returnType, symbolsByName, "")
    let returnIsHresult = match (returnFullName) {
        case Some(name) =>
            hresultRawAbiTypeByFullName(name).isSome()
        case None => false
    }
    if (returnIsHresult) {
        if (pinvokeMethodLooksLikeQuery(method)) {
            return PInvokeReturnHint.Query
        }
        if (pinvokeMethodHasRetValOut(method)) {
            return PInvokeReturnHint.ResultValue
        }
        return PInvokeReturnHint.ResultVoid
    }
    let returnIsBool = match (returnFullName) {
        case Some(name) => nativeBooleanRawType(name).isSome()
        case None => false
    }
    if (returnIsBool && methodSupportsLastError(method) &&
        nativeSetLastErrorBoolStatusSuccessCondition(method, "lastError__").isSome()) {
        return PInvokeReturnHint.LastErrorBoolStatus
    }
    if (returnIsBool && methodSupportsLastError(method) &&
        !nativeBoolReturnFalseSuccessStatuses(method.name).isEmpty()) {
        return PInvokeReturnHint.LastErrorBoolFalseSuccess
    }
    if (returnIsBool && nativeBoolReturnCannotUseCheckedWrapper(method.name)) {
        return PInvokeReturnHint.None
    }
    if (returnIsBool && methodSupportsLastError(method) &&
        (!nativeMethodCanReturnMultipleSuccessValues(method) ||
            nativeMultipleSuccessBoolUsesZeroFailure(method.name)) &&
        !nativeMethodReturnsSemanticBool(method)) {
        return PInvokeReturnHint.LastErrorBool
    }
    return PInvokeReturnHint.None
}

func methodSupportsLastError(method: MethodRecord): Bool {
    match (method.methodImport) {
        case Some(methodImport) =>
            for (attribute in methodImport.attributes) {
                if (attribute == "SupportsLastError" || attribute == "SetLastError") {
                    return true
                }
            }
            return nativeMethodReportsLastErrorWithoutMetadata(method.name)
        case None => return nativeMethodReportsLastErrorWithoutMetadata(method.name)
    }
    return false
}

func pinvokeMethodHasRetValOut(method: MethodRecord): Bool {
    if (method.signature.parameters.isEmpty()) {
        return false
    }
    let lastIndex = Int64(method.signature.parameters.size) - 1
    let lastSig = method.signature.parameters[lastIndex]
    if (lastSig.kind != "Pointer" && !isByReferenceSignature(lastSig)) {
        return false
    }
    let metadataParameters = metadataMethodParameters(method)
    match (metadataParameterAt(metadataParameters, lastIndex)) {
        case Some(parameter) =>
            if (contains(parameter.attributes, "Out") && contains(parameter.attributes, "Retval")) {
                return true
            }
        case None => ()
    }
    return false
}

func pinvokeMethodLooksLikeQuery(method: MethodRecord): Bool {
    let count = Int64(method.signature.parameters.size)
    if (count < 2) {
        return false
    }
    let metadataParameters = metadataMethodParameters(method)
    let guidIndex = count - 2
    let objectIndex = count - 1
    let guidSig = method.signature.parameters[guidIndex]
    if (!signatureIsGuidPointer(guidSig)) {
        return false
    }
    match (metadataParameterAt(metadataParameters, guidIndex)) {
        case Some(parameter) =>
            if (!pinvokeParameterLooksLikeInterfaceId(parameter)) {
                return false
            }
        case None => return false
    }
    let objectSig = method.signature.parameters[objectIndex]
    if (!signatureIsPointerToPointerUnit(objectSig)) {
        return false
    }
    match (metadataParameterAt(metadataParameters, objectIndex)) {
        case Some(parameter) =>
            return parameterHasComOutPtrAttribute(parameter)
        case None => ()
    }
    return false
}

func pinvokeParameterLooksLikeInterfaceId(parameter: ParameterRecord): Bool {
    return equalsAsciiIgnoreCase(parameter.name, "iid") ||
        equalsAsciiIgnoreCase(parameter.name, "riid") ||
        equalsAsciiIgnoreCase(parameter.name, "iidResult") ||
        equalsAsciiIgnoreCase(parameter.name, "riidResult") ||
        equalsAsciiIgnoreCase(parameter.name, "interfaceId")
}

func parameterHasComOutPtrAttribute(parameter: ParameterRecord): Bool {
    for (attribute in parameter.customAttributes) {
        if (hasAttributeName(attribute, "ComOutPtrAttribute")) {
            return true
        }
    }
    return false
}

func pinvokeRetValOutHasComOutPtr(method: MethodRecord): Bool {
    if (method.signature.parameters.isEmpty()) {
        return false
    }
    let lastIndex = Int64(method.signature.parameters.size) - 1
    let metadataParameters = metadataMethodParameters(method)
    match (metadataParameterAt(metadataParameters, lastIndex)) {
        case Some(parameter) => return parameterHasComOutPtrAttribute(parameter)
        case None => return false
    }
}

func pinvokeRetValOutStringHandleKind(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    if (method.signature.parameters.isEmpty()) {
        return None
    }
    let lastIndex = Int64(method.signature.parameters.size) - 1
    return pinvokeStringHandlePointerKind(method.signature.parameters[lastIndex], symbolsByName)
}

func pinvokeStringHandlePointerKind(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    match (signaturePointerTarget(signature)) {
        case Some(target) =>
            match (signatureFullNameInContext(target, symbolsByName, "")) {
                case Some(fullName) =>
                    if (fullName == "Windows.Win32.System.WinRT.HSTRING") {
                        return Some("HSTRING")
                    }
                    if (fullName == "Windows.Win32.Foundation.BSTR") {
                        return Some("BSTR")
                    }
                case None => ()
            }
        case None => ()
    }
    return None
}

func pinvokeStringOutSlotParameters(
    method: MethodRecord,
    pairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<PInvokeStringOutSlot> {
    let metadataParameters = metadataMethodParameters(method)
    let result = ArrayList<PInvokeStringOutSlot>()
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size) && index < Int64(pairs.size)) {
        match (metadataParameterAt(metadataParameters, index)) {
            case Some(parameter) =>
                if (contains(parameter.attributes, "Out") && !contains(parameter.attributes, "Retval")) {
                    match (pinvokeStringHandlePointerKind(method.signature.parameters[index], symbolsByName)) {
                        case Some(kind) => result.add(PInvokeStringOutSlot(pairs[index], kind))
                        case None => ()
                    }
                }
            case None => ()
        }
        index += 1
    }
    return result
}

func pinvokeComOutPointerParameters(
    method: MethodRecord,
    pairs: ArrayList<ParameterPair>
): ArrayList<ParameterPair> {
    let metadataParameters = metadataMethodParameters(method)
    let result = ArrayList<ParameterPair>()
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size) && index < Int64(pairs.size)) {
        if (signaturePointerTarget(method.signature.parameters[index]).isSome()) {
            match (metadataParameterAt(metadataParameters, index)) {
                case Some(parameter) =>
                    if (contains(parameter.attributes, "Out") && parameterHasComOutPtrAttribute(parameter)) {
                        result.add(pairs[index])
                    }
                case None => ()
            }
        }
        index += 1
    }
    return result
}

func pinvokeComOutSlotExpression(pair: ParameterPair): String {
    if (pair.typeName == "CPointer<CPointer<Unit>>") {
        return pair.name
    }
    return "CPointer<CPointer<Unit>>(${pair.name})"
}

func pinvokeStringOutSlotExpression(slot: PInvokeStringOutSlot): String {
    pinvokeComOutSlotExpression(slot.pair)
}

func pinvokeClearStringOutSlot(slot: PInvokeStringOutSlot): String {
    "        unsafe { ${pinvokeStringOutSlotExpression(slot)}.write(CPointer<Unit>()) }\n"
}

func pinvokeRequireOutSlot(slotExpr: String): String {
    "        if (${slotExpr}.isNull()) {\n" +
        "            throw windows_core.WindowsException(windows_core.E_POINTER)\n" +
        "        }\n"
}

func pinvokeRequireComOutSlot(pair: ParameterPair): String {
    pinvokeRequireOutSlot(pinvokeComOutSlotExpression(pair))
}

func pinvokeRequireStringOutSlot(slot: PInvokeStringOutSlot): String {
    pinvokeRequireOutSlot(pinvokeStringOutSlotExpression(slot))
}

func pinvokeClearOutSlotExpression(slotExpr: String, indent: String): String {
    "${indent}unsafe { ${slotExpr}.write(CPointer<Unit>()) }\n"
}

func pinvokePreclearOutSlotExpression(slotExpr: String, indent: String): String {
    var content = "${indent}if (${slotExpr}.isNull()) {\n"
    content += "${indent}    nullOutSlot__ = true\n"
    content += "${indent}} else {\n"
    content += pinvokeClearOutSlotExpression(slotExpr, "${indent}    ")
    content += "${indent}}\n"
    return content
}

func pinvokePreclearOutSlots(
    comOutPairs: ArrayList<ParameterPair>,
    stringOutSlots: ArrayList<PInvokeStringOutSlot>,
    indent: String
): String {
    let hasMultipleOutSlots = comOutPairs.size > 1 ||
        stringOutSlots.size > 1 ||
        (!comOutPairs.isEmpty() && !stringOutSlots.isEmpty())
    var content = ""
    if (hasMultipleOutSlots) {
        content += "${indent}var nullOutSlot__ = false\n"
        for (pair in comOutPairs) {
            content += pinvokePreclearOutSlotExpression(pinvokeComOutSlotExpression(pair), indent)
        }
        for (slot in stringOutSlots) {
            content += pinvokePreclearOutSlotExpression(pinvokeStringOutSlotExpression(slot), indent)
        }
        content += "${indent}if (nullOutSlot__) {\n"
        content += "${indent}    throw windows_core.WindowsException(windows_core.E_POINTER)\n"
        content += "${indent}}\n"
    } else {
        for (pair in comOutPairs) {
            content += pinvokeRequireComOutSlot(pair)
            content += pinvokeClearOutSlotExpression(pinvokeComOutSlotExpression(pair), indent)
        }
        for (slot in stringOutSlots) {
            content += pinvokeRequireStringOutSlot(slot)
            content += pinvokeClearStringOutSlot(slot)
        }
    }
    return content
}

func pinvokeReleaseFailedStringOutSlot(slot: PInvokeStringOutSlot): String {
    let slotExpr = pinvokeStringOutSlotExpression(slot)
    var content = "            if (${slotExpr}.isNotNull()) {\n"
    content += "                let failedString__ = unsafe { ${slotExpr}.read() }\n"
    content += "                if (failedString__.isNotNull()) {\n"
    if (slot.kind == "HSTRING") {
        content += "                    windows_core.releaseSystemHStringHandle(failedString__)\n"
    } else if (slot.kind == "BSTR") {
        content += "                    let failedBstr__ = windows_strings.BSTR.fromRawTake(CPointer<UInt16>(failedString__))\n"
        content += "                    failedBstr__.close()\n"
    }
    content += "                    unsafe { ${slotExpr}.write(CPointer<Unit>()) }\n"
    content += "                }\n"
    content += "            }\n"
    return content
}

func pinvokeReleaseFailedOutSlots(
    comOutPairs: ArrayList<ParameterPair>,
    stringOutSlots: ArrayList<PInvokeStringOutSlot>
): String {
    var content = ""
    for (pair in comOutPairs) {
        content += "            windows_core.releaseFailedComOutSlot(${pinvokeComOutSlotExpression(pair)})\n"
    }
    for (slot in stringOutSlots) {
        content += pinvokeReleaseFailedStringOutSlot(slot)
    }
    return content
}

func pinvokeReleaseFailedResultValueSlot(
    resultHasComOutPtr: Bool,
    resultStringHandleKind: Option<String>
): String {
    var content = ""
    if (resultHasComOutPtr) {
        content += "            if (result__.isNotNull()) {\n"
        content += "                windows_core.releaseFailedComOutSlot(CPointer<CPointer<Unit>>(inout result__))\n"
        content += "            }\n"
    }
    match (resultStringHandleKind) {
        case Some(kind) =>
            content += "            if (result__.isNotNull()) {\n"
            if (kind == "HSTRING") {
                content += "                windows_core.releaseSystemHStringHandle(result__)\n"
            } else if (kind == "BSTR") {
                content += "                let failedBstr__ = windows_strings.BSTR.fromRawTake(CPointer<UInt16>(result__))\n"
                content += "                failedBstr__.close()\n"
            }
            content += "                result__ = CPointer<Unit>()\n"
            content += "            }\n"
        case None => ()
    }
    return content
}

func pinvokeThrowIfComOutSlotNullAfterSuccess(
    pair: ParameterPair,
    cleanupComOutPairs: ArrayList<ParameterPair>,
    cleanupStringOutSlots: ArrayList<PInvokeStringOutSlot>,
    resultHasComOutPtr: Bool,
    resultStringHandleKind: Option<String>
): String {
    let slotExpr = pinvokeComOutSlotExpression(pair)
    var content = "        if (unsafe { ${slotExpr}.read() }.isNull()) {\n"
    content += pinvokeReleaseFailedOutSlots(cleanupComOutPairs, cleanupStringOutSlots)
    content += pinvokeReleaseFailedResultValueSlot(resultHasComOutPtr, resultStringHandleKind)
    content += "            throw windows_core.WindowsException(windows_core.E_POINTER)\n"
    content += "        }\n"
    return content
}

func pinvokeThrowIfResultComOutNullAfterSuccess(
    cleanupComOutPairs: ArrayList<ParameterPair>,
    cleanupStringOutSlots: ArrayList<PInvokeStringOutSlot>
): String {
    var content = "        if (result__.isNull()) {\n"
    content += pinvokeReleaseFailedOutSlots(cleanupComOutPairs, cleanupStringOutSlots)
    content += "            throw windows_core.WindowsException(windows_core.E_POINTER)\n"
    content += "        }\n"
    return content
}

func signaturePointerTarget(signature: SignatureRecord): Option<SignatureRecord> {
    if (signature.kind != "Pointer" && !isByReferenceSignature(signature)) {
        return None
    }
    match (signature.typeSig) {
        case Some(nested) => return Some(nested)
        case None => ()
    }
    match (signature.unmodifiedType) {
        case Some(nested) => return Some(nested)
        case None => ()
    }
    return None
}

func signatureIsGuidPointer(signature: SignatureRecord): Bool {
    if (signature.kind != "Pointer" && !isByReferenceSignature(signature)) {
        return false
    }
    match (signature.typeSig) {
        case Some(nested) =>
            match (signatureFullNameInContext(nested, HashMap<String, SymbolRecord>(), "")) {
                case Some(fullName) => return fullName == "System.Guid"
                case None => return false
            }
        case None => return false
    }
}

func signatureIsPointerToPointerUnit(signature: SignatureRecord): Bool {
    if (signature.kind != "Pointer" && !isByReferenceSignature(signature)) {
        return false
    }
    match (signature.typeSig) {
        case Some(nested) =>
            if (nested.kind != "Pointer" && !isByReferenceSignature(nested)) {
                return false
            }
            return true
        case None => return false
    }
}

func renderPInvokeResultVoidWrapper(
    ownerImplName: String,
    method: MethodRecord,
    sysName: String,
    wrapperName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let pairs = methodParameterPairs(method, true, symbolsByName)
    let params = parameterPairListText(pairs)
    let args = methodArgumentText(method, true, symbolsByName)
    let comOutPairs = pinvokeComOutPointerParameters(method, pairs)
    let stringOutSlots = pinvokeStringOutSlotParameters(method, pairs, symbolsByName)
    let preserveStatus = nativeMethodCanReturnMultipleSuccessValues(method)
    let returnType = if (preserveStatus) {
        "windows_core.HRESULT"
    } else {
        "Unit"
    }
    var content = "    public static func ${wrapperName}(${params}): ${returnType} {\n"
    content += pinvokePreclearOutSlots(comOutPairs, stringOutSlots, "        ")
    content += "        let hr__ = ${ownerImplName}.${sysName}(${args})\n"
    if (comOutPairs.isEmpty() && stringOutSlots.isEmpty()) {
        if (preserveStatus) {
            content += "        let resultHr__ = windows_core.HRESULT(hr__)\n"
            content += "        resultHr__.check()\n"
            content += "        return resultHr__\n"
        } else {
            content += "        windows_core.HRESULT(hr__).check()\n"
        }
    } else {
        content += "        let resultHr__ = windows_core.HRESULT(hr__)\n"
        content += "        if (resultHr__.failed()) {\n"
        content += pinvokeReleaseFailedOutSlots(comOutPairs, stringOutSlots)
        content += "        }\n"
        content += "        resultHr__.check()\n"
        for (pair in comOutPairs) {
            content += pinvokeThrowIfComOutSlotNullAfterSuccess(pair, comOutPairs, stringOutSlots, false, None)
        }
        if (preserveStatus) {
            content += "        return resultHr__\n"
        }
    }
    content += "    }\n"
    return content
}

func renderPInvokeResultValueWrapper(
    ownerImplName: String,
    method: MethodRecord,
    sysName: String,
    wrapperName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let pairs = methodParameterPairs(method, true, symbolsByName)
    if (pairs.isEmpty()) {
        return ""
    }
    let lastIndex = Int64(pairs.size) - 1
    let lastPair = pairs[lastIndex]
    let lastSignature = method.signature.parameters[lastIndex]
    let valueType = match (signaturePointerTarget(lastSignature)) {
        case Some(target) => cjAbiType(target, symbolsByName)
        case None => pointerElementType(lastPair.typeName)
    }
    if (valueType.isEmpty() || valueType == "Unit") {
        return ""
    }
    let leadingPairs = ArrayList<ParameterPair>()
    var idx: Int64 = 0
    while (idx < lastIndex) {
        leadingPairs.add(pairs[idx])
        idx += 1
    }
    let leadingComOutPairs = pinvokeComOutPointerParameters(method, leadingPairs)
    let leadingStringOutSlots = pinvokeStringOutSlotParameters(method, leadingPairs, symbolsByName)
    let resultHasComOutPtr = valueType == "CPointer<Unit>" && pinvokeRetValOutHasComOutPtr(method)
    let resultStringHandleKind = pinvokeRetValOutStringHandleKind(method, symbolsByName)
    let valueReturnType = match (resultStringHandleKind) {
        case Some(kind) =>
            if (kind == "HSTRING") {
                "windows_core.HString"
            } else {
                "windows_strings.BSTR"
            }
        case None => valueType
    }
    let preserveStatus = nativeMethodCanReturnMultipleSuccessValues(method)
    let returnType = if (preserveStatus) {
        "(windows_core.HRESULT, ${valueReturnType})"
    } else {
        valueReturnType
    }
    let paramsText = parameterPairListText(leadingPairs)
    var content = "    public static func ${wrapperName}(${paramsText}): ${returnType} {\n"
    content += "        var result__: ${valueType} = ${cjDefaultValue(valueType)}\n"
    content += pinvokePreclearOutSlots(leadingComOutPairs, leadingStringOutSlots, "        ")
    var callArgs = ArrayList<String>()
    for (pair in leadingPairs) {
        callArgs.add(pair.name)
    }
    if (lastPair.typeName == "CPointer<${valueType}>") {
        callArgs.add("CPointer<${valueType}>(inout result__)")
    } else {
        callArgs.add("unsafe { ${lastPair.typeName}(CPointer<${valueType}>(inout result__)) }")
    }
    content += "        let hr__ = ${ownerImplName}.${sysName}(${joinStrings(callArgs, ", ")})\n"
    if (leadingComOutPairs.isEmpty() && leadingStringOutSlots.isEmpty() &&
        !resultHasComOutPtr && resultStringHandleKind.isNone()) {
        if (preserveStatus) {
            content += "        let resultHr__ = windows_core.HRESULT(hr__)\n"
            content += "        resultHr__.check()\n"
        } else {
            content += "        windows_core.HRESULT(hr__).check()\n"
        }
    } else {
        content += "        let resultHr__ = windows_core.HRESULT(hr__)\n"
        content += "        if (resultHr__.failed()) {\n"
        content += pinvokeReleaseFailedOutSlots(leadingComOutPairs, leadingStringOutSlots)
        content += pinvokeReleaseFailedResultValueSlot(resultHasComOutPtr, resultStringHandleKind)
        content += "        }\n"
        content += "        resultHr__.check()\n"
        for (pair in leadingComOutPairs) {
            content += pinvokeThrowIfComOutSlotNullAfterSuccess(
                pair,
                leadingComOutPairs,
                leadingStringOutSlots,
                resultHasComOutPtr,
                resultStringHandleKind
            )
        }
        if (resultHasComOutPtr) {
            content += pinvokeThrowIfResultComOutNullAfterSuccess(leadingComOutPairs, leadingStringOutSlots)
        }
    }
    match (resultStringHandleKind) {
        case Some(kind) =>
            if (kind == "HSTRING") {
                if (preserveStatus) {
                    content += "        return (resultHr__, windows_core.HString.fromSystemHandleTake(result__))\n"
                } else {
                    content += "        return windows_core.HString.fromSystemHandleTake(result__)\n"
                }
            } else {
                if (preserveStatus) {
                    content += "        return (resultHr__, windows_strings.BSTR.fromRawTake(CPointer<UInt16>(result__)))\n"
                } else {
                    content += "        return windows_strings.BSTR.fromRawTake(CPointer<UInt16>(result__))\n"
                }
            }
        case None =>
            if (preserveStatus) {
                content += "        return (resultHr__, result__)\n"
            } else {
                content += "        return result__\n"
            }
    }
    content += "    }\n"
    return content
}

func renderPInvokeQueryWrapper(
    ownerImplName: String,
    method: MethodRecord,
    sysName: String,
    wrapperName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let pairs = methodParameterPairs(method, true, symbolsByName)
    let count = Int64(pairs.size)
    if (count < 2) {
        return ""
    }
    let leadingPairs = ArrayList<ParameterPair>()
    var idx: Int64 = 0
    while (idx < count - 2) {
        leadingPairs.add(pairs[idx])
        idx += 1
    }
    let paramsText = parameterPairListText(leadingPairs)
    let separator = if (paramsText.isEmpty()) { "" } else { ", " }
    var content = "    public static func ${wrapperName}<T>(${paramsText}${separator}descriptor: windows_interface.InterfaceDescriptor<T>): T where T <: windows_interface.ComInterface {\n"
    content += "        var iid__ = descriptor.iid\n"
    content += "        var raw__: CPointer<Unit> = CPointer<Unit>()\n"
    let callArgs = ArrayList<String>()
    for (pair in leadingPairs) {
        callArgs.add(pair.name)
    }
    callArgs.add("unsafe { CPointer<Unit>(CPointer<windows_interface.GUID>(inout iid__)) }")
    callArgs.add("unsafe { CPointer<Unit>(CPointer<CPointer<Unit>>(inout raw__)) }")
    content += "        let hr__ = ${ownerImplName}.${sysName}(${joinStrings(callArgs, ", ")})\n"
    content += "        let resultHr__ = windows_core.HRESULT(hr__)\n"
    content += "        if (resultHr__.failed() && raw__.isNotNull()) {\n"
    content += "            let _ = descriptor.releasePointer(raw__)\n"
    content += "            raw__ = CPointer<Unit>()\n"
    content += "        }\n"
    content += "        resultHr__.check()\n"
    content += "        if (raw__.isNull()) {\n"
    content += "            throw windows_core.WindowsException(windows_core.E_POINTER)\n"
    content += "        }\n"
    content += "        return descriptor.takeFromAbi(raw__)\n"
    content += "    }\n"
    return content
}

func renderPInvokeLastErrorWrapper(
    ownerImplName: String,
    method: MethodRecord,
    sysName: String,
    wrapperName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let params = methodParameterText(method, true, symbolsByName)
    let args = methodArgumentText(method, true, symbolsByName)
    let falseLiteral = nativeBoolFalseLiteral(cjAbiType(method.signature.returnType, symbolsByName))
    var content = "    public static func ${wrapperName}(${params}): Unit {\n"
    content += "        let ok__ = ${ownerImplName}.${sysName}(${args})\n"
    content += "        if (ok__ == ${falseLiteral}) {\n"
    content += "            throw windows_core.WindowsException(windows_core.errorFromThread())\n"
    content += "        }\n"
    content += "    }\n"
    return content
}

func renderPInvokeLastErrorBoolStatusWrapper(
    ownerImplName: String,
    method: MethodRecord,
    sysName: String,
    wrapperName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let params = methodParameterText(method, true, symbolsByName)
    let args = methodArgumentText(method, true, symbolsByName)
    let falseLiteral = nativeBoolFalseLiteral(cjAbiType(method.signature.returnType, symbolsByName))
    var statusCondition = "lastError__ == 0u32"
    match (nativeSetLastErrorBoolStatusSuccessCondition(method, "lastError__")) {
        case Some(condition) => statusCondition = condition
        case None => ()
    }
    var content = "    public static func ${wrapperName}(${params}): UInt32 {\n"
    content += "        let ok__ = ${ownerImplName}.${sysName}(${args})\n"
    content += "        if (ok__ != ${falseLiteral}) {\n"
    content += "            return 0u32\n"
    content += "        }\n"
    content += "        let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n"
    content += "        let lastError__ = unsafe { getLastErrorProc__() }\n"
    content += "        if (${statusCondition}) {\n"
    content += "            return lastError__\n"
    content += "        }\n"
    content += "        throw windows_core.WindowsException(windows_core.errorFromWin32(lastError__))\n"
    content += "    }\n"
    return content
}

func renderPInvokeLastErrorBoolFalseSuccessWrapper(
    ownerImplName: String,
    method: MethodRecord,
    sysName: String,
    wrapperName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let params = methodParameterText(method, true, symbolsByName)
    let args = methodArgumentText(method, true, symbolsByName)
    let falseLiteral = nativeBoolFalseLiteral(cjAbiType(method.signature.returnType, symbolsByName))
    let falseSuccessStatuses = nativeBoolReturnFalseSuccessStatuses(method.name)
    var content = "    public static func ${wrapperName}(${params}): Bool {\n"
    content += "        let ok__ = ${ownerImplName}.${sysName}(${args})\n"
    content += "        if (ok__ != ${falseLiteral}) {\n"
    content += "            return true\n"
    content += "        }\n"
    content += "        let getLastErrorProc__ = CFunc<() -> UInt32>(windows_libloading.resolveProc(\"KERNEL32.dll\", \"GetLastError\"))\n"
    content += "        let lastError__ = unsafe { getLastErrorProc__() }\n"
    for (falseSuccessStatus in falseSuccessStatuses) {
        content += "        if (lastError__ == ${falseSuccessStatus}) {\n"
        content += "            return false\n"
        content += "        }\n"
    }
    content += "        throw windows_core.WindowsException(windows_core.errorFromWin32(lastError__))\n"
    content += "    }\n"
    return content
}

func pointerElementType(typeName: String): String {
    let prefix = "CPointer<"
    if (!startsWith(typeName, prefix)) {
        return ""
    }
    let bytes = typeName.toArray()
    let prefixSize = Int64(prefix.toArray().size)
    if (Int64(bytes.size) <= prefixSize + 1) {
        return ""
    }
    if (bytes[Int64(bytes.size) - 1] != b'>') {
        return ""
    }
    return String.fromUtf8(bytes[prefixSize..Int64(bytes.size) - 1])
}

func renderNativeComInterfaceSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    return renderRawHandleSymbol(symbol, "interface") + "\n\n" +
        renderNativeComInterfaceVtblSymbol(symbol, typeDef, symbolsByName)
}

func renderNativeComInterfaceVtblSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let vtblFullName = "${symbol.fullName}Vtbl"
    let vtblImplName = "${symbol.implName}Vtbl"
    var content = "// ${vtblFullName} (synthetic:${vtblImplName})\n"
    if (symbol.fullName == "Windows.Win32.System.Com.IUnknown") {
        content += "public type ${vtblImplName} = windows_interface.IUnknownVtbl"
        return content
    }

    let baseVtbl = nativeComInterfaceBaseVtblName(typeDef, symbolsByName, symbol.fullName)
    content += "@C\n"
    content += "public struct ${vtblImplName} {\n"
    content += "    public var base_: ${baseVtbl} = ${baseVtbl}()\n"
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, slotNames)
        slotNames.add(slotName)
        let cfuncType = nativeComInterfaceMethodCFuncType(method, symbolsByName)
        content += "    public var ${slotName}: ${cfuncType} = ${cfuncType}(CPointer<Unit>())\n"
    }
    content += "    public init() {}\n"
    content += "}"
    return content
}

func nativeComInterfaceBaseVtblName(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    match (nativeComInterfaceDirectBaseFullName(typeDef, symbolsByName, ownerFullName)) {
        case Some(baseFullName) =>
            if (baseFullName == "Windows.Win32.System.Com.IUnknown") {
                return "windows_interface.IUnknownVtbl"
            }
            if (baseFullName == "Windows.Win32.System.WinRT.IInspectable") {
                return "windows_interface.IInspectableVtbl"
            }
            return "${mangleFullName(baseFullName)}Vtbl"
        case None => return "windows_interface.IUnknownVtbl"
    }
}

func nativeComInterfaceDirectBaseFullName(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    for (implementation in typeDef.interfaceImplementations) {
        match (implementation.interfaceSignature) {
            case Some(signature) =>
                match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
                    case Some(fullName) => return Some(fullName)
                    case None => ()
                }
            case None => ()
        }
        match (implementation.typeDefinition) {
            case Some(metadataType) => return Some(metadataType.fullName())
            case None => ()
        }
        match (implementation.typeReference) {
            case Some(metadataType) => return Some(metadataType.fullName())
            case None => ()
        }
        match (implementation.typeSpecification) {
            case Some(typeSpecification) =>
                match (signatureFullNameInContext(typeSpecification.signature, symbolsByName, ownerFullName)) {
                    case Some(fullName) => return Some(fullName)
                    case None => ()
                }
            case None => ()
        }
    }
    return None
}

func nativeComInterfaceMethodCFuncType(method: MethodRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    let pairs = methodParameterPairs(method, true, symbolsByName)
    let types = ArrayList<String>()
    types.add("CPointer<Unit>")
    for (pair in pairs) {
        types.add(pair.typeName)
    }
    let returnType = cjAbiType(method.signature.returnType, symbolsByName)
    return "CFunc<(${joinStrings(types, ", ")}) -> ${returnType}>"
}

func pinvokeCFuncType(method: MethodRecord, returnType: String, symbolsByName: HashMap<String, SymbolRecord>): String {
    let pairs = methodParameterPairs(method, true, symbolsByName)
    if (pairs.isEmpty()) {
        return "CFunc<() -> ${returnType}>"
    }
    let params = ArrayList<String>()
    for (pair in pairs) {
        params.add(pair.typeName)
    }
    return "CFunc<(${joinStrings(params, ", ")}) -> ${returnType}>"
}

func renderInterfaceSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    guidValue: String,
    options: RenderOptions
): String {
    if (isGenericWinrtType(typeDef)) {
        return renderGenericWinrtInterfaceSymbol(symbol, typeDef, symbolsByName, guidValue, options)
    }
    let cleanupSpecs = interfaceMacroCleanupSpecs(symbol, typeDef, symbolsByName)
    var interfaceAttr = "@Interface[\"${guidValue}\", \"${cjStringContent(symbol.fullName)}\""
    if (!cleanupSpecs.isEmpty()) {
        interfaceAttr += ", \"${cjStringContent(cleanupSpecs)}\""
    }
    var content = "${interfaceAttr}]\n"
    content += "public interface ${symbol.implName} <: IInspectable {\n"
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, slotNames)
        slotNames.add(slotName)
        content += "    func ${slotName}(${interfaceMethodMacroParams(method, symbolsByName, symbol.fullName)}): Int32\n"
    }
    content += "}"
    if (options.implement) {
        content += "\n\n"
        content += renderInterfaceImplTrait(symbol, typeDef, symbolsByName)
    }
    return content
}

func interfaceMacroCleanupSpecs(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let entries = ArrayList<String>()
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, slotNames)
        slotNames.add(slotName)
        let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, symbol.fullName)
        let cleanupSpecs = interfaceDispatcherOutSlotCleanupSpecs(method, pairs, symbolsByName, symbol.fullName)
        for (spec in cleanupSpecs) {
            entries.add("${slotName}.${spec.pair.name}=${spec.cleanupKind}")
        }
    }
    joinStrings(entries, ";")
}

func renderInterfaceImplTrait(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    var content = "public interface ${symbol.implName}_Impl {\n"
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, slotNames)
        slotNames.add(slotName)
        let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, symbol.fullName)
        content += "    func ${slotName}(${parameterPairListText(pairs)}): Int32\n"
    }
    content += "}"
    return content
}

func isGenericWinrtType(typeDef: TypeDefinitionRecord): Bool {
    return !typeDef.genericParameters.isEmpty() && contains(typeDef.attributes, "WindowsRuntime")
}

func renderGenericWinrtInterfaceSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    guidValue: String,
    options: RenderOptions
): String {
    let _ = options
    let genericNames = genericParameterNames(typeDef)
    var content = renderGenericWinrtInterfaceVtbl(symbol, typeDef, symbolsByName)
    content += renderGenericWinrtInterfaceImplSurfaces(symbol, typeDef, symbolsByName, genericNames)
    content += renderGenericWinrtInterfaceWrapper(symbol, typeDef, symbolsByName, guidValue, genericNames)
    return content
}

func renderGenericWinrtInterfaceVtbl(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let exceptionAlias = "${symbol.implName}ExceptionBase"
    var content = "type ${exceptionAlias} = Exception\n\n@C\npublic struct ${symbol.implName}Vtbl {\n"
    content += "    public var base_: windows_interface.IInspectableVtbl = windows_interface.IInspectableVtbl()\n"
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, slotNames)
        slotNames.add(slotName)
        let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, symbol.fullName)
        content += "    public var ${slotName}: CFunc<(${interfaceCFuncParameterTypes(pairs)}) -> Int32> = " +
            interfaceDefaultVtblStub(method, pairs, symbolsByName, symbol.fullName)
    }
    content += "\n    public init() {}\n\n"
    content += "    public static func new(offset!: Int64 = 0): ${symbol.implName}Vtbl {\n"
    content += "        let _ = offset\n"
    content += "        var vtbl = ${symbol.implName}Vtbl()\n"
    content += "        vtbl.base_ = windows_core.buildIInspectableVtbl()\n"
    let newSlotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, newSlotNames)
        newSlotNames.add(slotName)
        let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, symbol.fullName)
        content += "        vtbl.${slotName} = { instanceRaw${interfaceClosureParameterNames(pairs)} =>\n"
        content += "            match (unsafe { windows_core.asImplFromRaw<${symbol.implName}_ImplErased>(instanceRaw) }) {\n"
        let outPairs = interfaceDispatcherOutSlotPairs(method, pairs, symbolsByName, symbol.fullName)
        let cleanupSpecs = interfaceDispatcherOutSlotCleanupSpecs(method, pairs, symbolsByName, symbol.fullName)
        let nullPairs = interfaceDispatcherNullCheckPairs(method, pairs, symbolsByName, symbol.fullName)
        let nullCondition = interfaceDispatcherOutSlotNullCondition(nullPairs)
        if (nullCondition.isEmpty()) {
            content += "                case Some(impl) =>\n"
            content += interfaceDispatcherInvoke(slotName, pairs, outPairs, cleanupSpecs, exceptionAlias, 5)
        } else {
            content += "                case Some(impl) =>\n"
            content += "                    if (${nullCondition}) {\n"
            content += interfaceDispatcherClearPairs(outPairs, 6)
            content += "                        windows_core.E_POINTER.value\n"
            content += "                    } else {\n"
            content += interfaceDispatcherClearPairs(outPairs, 6)
            content += interfaceDispatcherInvoke(slotName, pairs, outPairs, cleanupSpecs, exceptionAlias, 6)
            content += "                    }\n"
        }
        content += "                case None =>\n"
        content += interfaceDispatcherClearOutSlots(method, pairs, symbolsByName, symbol.fullName, 5)
        content += "                    windows_core.E_NOINTERFACE.value\n"
        content += "            }\n"
        content += "        }\n"
    }
    content += "        vtbl\n"
    content += "    }\n"
    content += "}\n\n"
    return content
}

func interfaceDispatcherInvoke(
    slotName: String,
    pairs: ArrayList<ParameterPair>,
    outPairs: ArrayList<ParameterPair>,
    cleanupSpecs: ArrayList<InterfaceDispatcherOutSlotCleanupSpec>,
    exceptionAlias: String,
    indentLevel: Int64
): String {
    let indent = runtimeIndent(indentLevel)
    let bodyIndent = runtimeIndent(indentLevel + 1)
    var content = "${indent}try {\n"
    content += "${bodyIndent}let resultHr__ = impl.${slotName}(${argumentPairListText(pairs)})\n"
    if (!outPairs.isEmpty()) {
        content += "${bodyIndent}if (windows_core.HRESULT(resultHr__).failed()) {\n"
        content += interfaceDispatcherReleaseFailedOutSlots(cleanupSpecs, indentLevel + 2)
        content += interfaceDispatcherClearPairs(outPairs, indentLevel + 2)
        content += "${bodyIndent}}\n"
    }
    content += "${bodyIndent}resultHr__\n"
    content += "${indent}} catch (error: windows_core.WindowsException) {\n"
    content += interfaceDispatcherReleaseFailedOutSlots(cleanupSpecs, indentLevel + 1)
    content += interfaceDispatcherClearPairs(outPairs, indentLevel + 1)
    content += "${bodyIndent}error.code().value\n"
    content += "${indent}} catch (_: ${exceptionAlias}) {\n"
    content += interfaceDispatcherReleaseFailedOutSlots(cleanupSpecs, indentLevel + 1)
    content += interfaceDispatcherClearPairs(outPairs, indentLevel + 1)
    content += "${bodyIndent}windows_core.E_FAIL.value\n"
    content += "${indent}}\n"
    return content
}

func interfaceDefaultVtblStub(
    method: MethodRecord,
    pairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let clears = interfaceDispatcherClearOutSlots(method, pairs, symbolsByName, ownerFullName, 2)
    if (clears.isEmpty()) {
        return "{ ${interfaceClosurePlaceholders(Int64(pairs.size) + 1)} => windows_core.E_NOTIMPL.value }\n"
    }
    return "{ _${interfaceClosureParameterNames(pairs)} =>\n" +
        clears +
        "        windows_core.E_NOTIMPL.value\n" +
        "    }\n"
}

func interfaceDispatcherOutSlotPairs(
    method: MethodRecord,
    pairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<ParameterPair> {
    let outPairs = ArrayList<ParameterPair>()
    let metadataParameters = metadataMethodParameters(method)
    var pairIndex: Int64 = 0
    var parameterIndex: Int64 = 0
    while (parameterIndex < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[parameterIndex]
        let parameter = metadataParameterAt(metadataParameters, parameterIndex)
        if (isWinrtArraySignature(signature)) {
            if (isOutParameter(parameter) && !isCallerAllocatedOutArrayParameter(parameter)) {
                outPairs.add(pairs[pairIndex])
                outPairs.add(pairs[pairIndex + 1])
            }
            pairIndex += 2
        } else {
            if (isOutParameter(parameter)) {
                outPairs.add(pairs[pairIndex])
            }
            pairIndex += 1
        }
        parameterIndex += 1
    }
    if (isWinrtArraySignature(method.signature.returnType)) {
        outPairs.add(pairs[pairIndex])
        outPairs.add(pairs[pairIndex + 1])
    } else {
        let returnType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, ownerFullName)
        if (returnType != "Unit") {
            outPairs.add(pairs[pairIndex])
        }
    }
    return outPairs
}

func interfaceDispatcherNullCheckPairs(
    method: MethodRecord,
    pairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<ParameterPair> {
    let nullPairs = ArrayList<ParameterPair>()
    let metadataParameters = metadataMethodParameters(method)
    var pairIndex: Int64 = 0
    var parameterIndex: Int64 = 0
    while (parameterIndex < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[parameterIndex]
        let parameter = metadataParameterAt(metadataParameters, parameterIndex)
        if (isWinrtArraySignature(signature)) {
            if (isOutParameter(parameter) && isCallerAllocatedOutArrayParameter(parameter)) {
                nullPairs.add(pairs[pairIndex + 1])
            }
            pairIndex += 2
        } else {
            pairIndex += 1
        }
        parameterIndex += 1
    }
    let outPairs = interfaceDispatcherOutSlotPairs(method, pairs, symbolsByName, ownerFullName)
    for (pair in outPairs) {
        nullPairs.add(pair)
    }
    return nullPairs
}

func interfaceDispatcherOutSlotCleanupSpecs(
    method: MethodRecord,
    pairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<InterfaceDispatcherOutSlotCleanupSpec> {
    let cleanupSpecs = ArrayList<InterfaceDispatcherOutSlotCleanupSpec>()
    let metadataParameters = metadataMethodParameters(method)
    var pairIndex: Int64 = 0
    var parameterIndex: Int64 = 0
    while (parameterIndex < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[parameterIndex]
        let parameter = metadataParameterAt(metadataParameters, parameterIndex)
        if (isWinrtArraySignature(signature)) {
            if (isOutParameter(parameter) && !isCallerAllocatedOutArrayParameter(parameter)) {
                match (runtimeArrayElementSignature(signature)) {
                    case Some(elementSignature) =>
                        let cleanupKind = "Array<${winrtProjectedTypeName(elementSignature, symbolsByName, ownerFullName)}>"
                        cleanupSpecs.add(InterfaceDispatcherOutSlotCleanupSpec(pairs[pairIndex + 1], cleanupKind))
                    case None => ()
                }
            }
            pairIndex += 2
        } else {
            if (isOutParameter(parameter)) {
                let cleanupKind = interfaceDispatcherOutSlotCleanupKind(signature, symbolsByName, ownerFullName)
                if (!cleanupKind.isEmpty()) {
                    cleanupSpecs.add(InterfaceDispatcherOutSlotCleanupSpec(pairs[pairIndex], cleanupKind))
                }
            }
            pairIndex += 1
        }
        parameterIndex += 1
    }
    if (isWinrtArraySignature(method.signature.returnType)) {
        match (runtimeArrayElementSignature(method.signature.returnType)) {
            case Some(elementSignature) =>
                let cleanupKind = "Array<${winrtProjectedTypeName(elementSignature, symbolsByName, ownerFullName)}>"
                cleanupSpecs.add(InterfaceDispatcherOutSlotCleanupSpec(pairs[pairIndex + 1], cleanupKind))
            case None => ()
        }
        return cleanupSpecs
    }

    let returnType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, ownerFullName)
    if (returnType != "Unit") {
        let cleanupKind = interfaceDispatcherOutSlotCleanupKind(method.signature.returnType, symbolsByName, ownerFullName)
        if (!cleanupKind.isEmpty()) {
            cleanupSpecs.add(InterfaceDispatcherOutSlotCleanupSpec(pairs[pairIndex], cleanupKind))
        }
    }
    cleanupSpecs
}

func interfaceDispatcherOutSlotCleanupKind(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let targetSignature = runtimeReferenceTargetSignature(signature)
    let abiType = interfaceSlotAbiType(targetSignature, symbolsByName, ownerFullName)
    if (abiType != "CPointer<Unit>") {
        return ""
    }
    let projectedType = winrtProjectedTypeName(targetSignature, symbolsByName, ownerFullName)
    if (projectedType == "windows_core.HString") {
        return "HString"
    }
    if (projectedType != "CPointer<Unit>") {
        return "Com"
    }
    ""
}

func interfaceDispatcherArrayCleanupElementType(cleanupKind: String): String {
    let prefix = "Array<"
    if (!startsWith(cleanupKind, prefix)) {
        return ""
    }
    let bytes = cleanupKind.toArray()
    let prefixSize = Int64(prefix.toArray().size)
    if (Int64(bytes.size) <= prefixSize + 1) {
        return ""
    }
    if (bytes[Int64(bytes.size) - 1] != b'>') {
        return ""
    }
    return String.fromUtf8(bytes[prefixSize..Int64(bytes.size) - 1])
}

func interfaceDispatcherOutSlotNullCondition(pairs: ArrayList<ParameterPair>): String {
    let checks = ArrayList<String>()
    for (pair in pairs) {
        if (!pointerElementType(pair.typeName).isEmpty()) {
            checks.add("${pair.name}.isNull()")
        }
    }
    return joinStrings(checks, " || ")
}

func interfaceDispatcherClearOutSlots(
    method: MethodRecord,
    pairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    indentLevel: Int64
): String {
    let outPairs = interfaceDispatcherOutSlotPairs(method, pairs, symbolsByName, ownerFullName)
    return interfaceDispatcherClearPairs(outPairs, indentLevel)
}

func interfaceDispatcherClearPairs(pairs: ArrayList<ParameterPair>, indentLevel: Int64): String {
    var content = ""
    for (pair in pairs) {
        content += interfaceDispatcherClearPair(pair, indentLevel)
    }
    return content
}

func interfaceDispatcherReleaseFailedOutSlots(
    cleanupSpecs: ArrayList<InterfaceDispatcherOutSlotCleanupSpec>,
    indentLevel: Int64
): String {
    var content = ""
    for (spec in cleanupSpecs) {
        content += interfaceDispatcherReleaseFailedOutSlot(spec, indentLevel)
    }
    content
}

func interfaceDispatcherReleaseFailedOutSlot(
    spec: InterfaceDispatcherOutSlotCleanupSpec,
    indentLevel: Int64
): String {
    let indent = runtimeIndent(indentLevel)
    let innerIndent = runtimeIndent(indentLevel + 1)
    let nestedIndent = runtimeIndent(indentLevel + 2)
    let slotName = spec.pair.name
    if (spec.cleanupKind == "Com") {
        return "${indent}windows_core.releaseFailedComOutSlot(${slotName})\n"
    }
    if (spec.cleanupKind == "HString") {
        return "${indent}if (${slotName}.isNotNull()) {\n" +
            "${innerIndent}let failedString__ = unsafe { ${slotName}.read() }\n" +
            "${innerIndent}if (failedString__.isNotNull()) {\n" +
            "${nestedIndent}windows_core.releaseSystemHStringHandle(failedString__)\n" +
            "${nestedIndent}unsafe { ${slotName}.write(CPointer<Unit>()) }\n" +
            "${innerIndent}}\n" +
            "${indent}}\n"
    }
    let arrayElementType = interfaceDispatcherArrayCleanupElementType(spec.cleanupKind)
    if (!arrayElementType.isEmpty()) {
        let dataPointerType = pointerElementType(spec.pair.typeName)
        let elementAbiType = pointerElementType(dataPointerType)
        if (dataPointerType.isEmpty() || elementAbiType.isEmpty()) {
            return ""
        }
        let sizeSlotName = "${slotName}Size"
        var content = "${indent}if (${slotName}.isNotNull()) {\n"
        content += "${innerIndent}var rawSize__ = 0u32\n"
        content += "${innerIndent}if (${sizeSlotName}.isNotNull()) {\n"
        content += "${nestedIndent}rawSize__ = unsafe { ${sizeSlotName}.read() }\n"
        content += "${innerIndent}}\n"
        content += "${innerIndent}let rawArray__ = unsafe { ${slotName}.read() }\n"
        content += "${innerIndent}if (rawArray__.isNotNull()) {\n"
        if (runtimeArrayElementUsesHandleBorrow(arrayElementType, elementAbiType)) {
            content += "${nestedIndent}windows_core.winrtReleaseGenericArrayOut<${arrayElementType}>(CPointer<Unit>(rawArray__), rawSize__)\n"
        } else {
            content += "${nestedIndent}windows_core.coTaskMemFree(CPointer<Unit>(rawArray__))\n"
        }
        content += "${innerIndent}}\n"
        content += "${innerIndent}unsafe { ${slotName}.write(${dataPointerType}()) }\n"
        content += "${indent}}\n"
        content += "${indent}if (${sizeSlotName}.isNotNull()) {\n"
        content += "${innerIndent}unsafe { ${sizeSlotName}.write(0u32) }\n"
        content += "${indent}}\n"
        return content
    }
    ""
}

func interfaceDispatcherClearPair(pair: ParameterPair, indentLevel: Int64): String {
    let valueType = pointerElementType(pair.typeName)
    if (valueType.isEmpty()) {
        return ""
    }
    let indent = runtimeIndent(indentLevel)
    let innerIndent = runtimeIndent(indentLevel + 1)
    return "${indent}if (${pair.name}.isNotNull()) {\n" +
        "${innerIndent}unsafe { ${pair.name}.write(${cjDefaultValue(valueType)}) }\n" +
        "${indent}}\n"
}

func renderGenericWinrtInterfaceImplSurfaces(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    genericNames: ArrayList<String>
): String {
    var content = "public interface ${symbol.implName}_ImplErased {\n"
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, slotNames)
        slotNames.add(slotName)
        let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, symbol.fullName)
        content += "    func ${slotName}(${parameterPairListText(pairs)}): Int32\n"
    }
    content += "}\n\n"
    content += "public interface ${symbol.implName}_Impl${genericParameterList(genericNames)} <: " +
        "${symbol.implName}_ImplErased${genericRuntimeWhereClause(genericNames)} {}\n\n"
    return content
}

func renderGenericWinrtInterfaceWrapper(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    guidValue: String,
    genericNames: ArrayList<String>
): String {
    let genericParams = genericParameterList(genericNames)
    let genericWhere = genericRuntimeWhereClause(genericNames)
    let genericTypeName = "${symbol.implName}${genericParams}"
    let runtimeName = stripGenericArity(symbol.fullName)
    var content = "public open class ${genericTypeName} <: windows_interface.InterfaceWrapperBase & " +
        "windows_interface.ComInterface & windows_core.RuntimeName & windows_interface.RuntimeType & " +
        "windows_core.RuntimeType & windows_interface.DescriptorSchemaProvider${genericWhere} {\n"
    content += "    public init(raw: CPointer<Unit>) {\n"
    content += "        super(raw)\n"
    content += "    }\n\n"
    content += "    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {\n"
    content += "        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)\n"
    content += "    }\n\n"
    content += "    public static func fromAbiTake(raw: CPointer<Unit>): ${genericTypeName} {\n"
    content += "        Owned${symbol.implName}${genericParams}(raw)\n"
    content += "    }\n\n"
    content += "    public static func viewOf(raw: CPointer<Unit>): ${genericTypeName} {\n"
    content += "        ${genericTypeName}(raw, takeOwnership: false, allowManualRelease: false)\n"
    content += "    }\n\n"
    content += "    public static func iid(): windows_interface.GUID {\n"
    content += "        windows_interface.GUID.from_signature(${genericTypeName}.signature())\n"
    content += "    }\n\n"
    content += "    public static func descriptor(): windows_interface.InterfaceDescriptor<${genericTypeName}> {\n"
    content += "        var descriptor = windows_interface.InterfaceDescriptor<${genericTypeName}>(\"${cjStringContent(runtimeName)}\", " +
        "${genericTypeName}.iid(), windows_interface.IInspectable.descriptor(), " +
        "{ raw => ${genericTypeName}.fromAbiTake(raw) }, { raw => ${genericTypeName}.viewOf(raw) }, " +
        "ownMethodCount: ${typeDef.methods.size})\n"
    content += "        descriptor.runtimeTypeContract = Some(${genericTypeName}.runtimeType())\n"
    content += "        return descriptor\n"
    content += "    }\n\n"
    content += "    public static func descriptorSchema(): windows_interface.InterfaceDescriptorSchema {\n"
    content += "        var schema = windows_interface.InterfaceDescriptorSchema(\"${cjStringContent(runtimeName)}\", " +
        "${genericTypeName}.iid(), windows_interface.IInspectable.descriptorSchema(), " +
        "\"${symbol.implName}Vtbl\", \"${symbol.implName}\", \"${symbol.implName}_Impl\", " +
        "${interfaceMethodSchemas(typeDef, symbolsByName, symbol.fullName)})\n"
    content += "        schema.runtimeTypeContract = Some(${genericTypeName}.runtimeType())\n"
    content += "        return schema\n"
    content += "    }\n\n"
    content += "    public static let VTABLE: ${symbol.implName}Vtbl = ${symbol.implName}Vtbl.new()\n\n"
    content += "    public static let VTABLE_HANDLE: CPointer<${symbol.implName}Vtbl> = " +
        "unsafe { windows_interface.allocateNativeValue<${symbol.implName}Vtbl>(VTABLE) }\n\n"
    content += "    public static func vtablePtr(): CPointer<Unit> {\n"
    content += "        CPointer<Unit>(VTABLE_HANDLE)\n"
    content += "    }\n\n"
    content += "    public static func abiType(): String {\n"
    content += "        \"CPointer<Unit>\"\n"
    content += "    }\n\n"
    content += renderGenericWinrtSignatureFunction(genericTypeName, guidValue, genericNames)
    content += "    public static func runtimeName(): String {\n"
    content += "        \"${cjStringContent(runtimeName)}\"\n"
    content += "    }\n\n"
    content += "    public static func runtimeType(): windows_interface.RuntimeTypeContract {\n"
    content += "        windows_interface.RuntimeTypeContract(\"${cjStringContent(runtimeName)}\", " +
        "${genericTypeName}.signature(), ${genericTypeName}.iid())\n"
    content += "    }\n\n"
    content += "    public static func projectionKind(): String {\n"
    content += "        return \"interface\"\n"
    content += "    }\n\n"
    content += "    public unsafe func vtbl(): ${symbol.implName}Vtbl {\n"
    content += "        readVtbl<${symbol.implName}Vtbl>(${symbol.implName}Vtbl())\n"
    content += "    }\n\n"
    content += renderGenericWinrtInterfaceMethods(symbol, typeDef, symbolsByName)
    content += "    public func asIInspectable(): windows_interface.IInspectable {\n"
    content += "        windows_interface.IInspectable.viewOf(asRaw())\n"
    content += "    }\n"
    content += "}\n\n"
    content += "extend${genericParams} ${genericTypeName} <: windows_core.Interface<${genericTypeName}>${genericWhere} {}\n\n"
    content += "private class Owned${symbol.implName}${genericParams} <: ${genericTypeName}${genericWhere} {\n"
    content += "    public init(raw: CPointer<Unit>) {\n"
    content += "        super(raw, takeOwnership: true, allowManualRelease: false)\n"
    content += "    }\n"
    content += "}\n"
    return content
}

func renderGenericWinrtInterfaceMethods(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    var content = ""
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, slotNames)
        slotNames.add(slotName)
        let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, symbol.fullName)
        content += "    public unsafe func ${slotName}(${parameterPairListText(pairs)}): windows_core.HRESULT {\n"
        for (tokenOutName in interfaceEventRegistrationTokenOutSlotNames(method, symbolsByName, symbol.fullName)) {
            content += "        if (${tokenOutName}.isNotNull()) {\n"
            content += "            unsafe { ${tokenOutName}.write(0i64) }\n"
            content += "        }\n"
        }
        content += "        let liveRaw = asRaw()\n"
        content += "        if (liveRaw.isNull()) {\n"
        content += "            return windows_core.E_POINTER\n"
        content += "        }\n"
        content += "        let v = vtbl()\n"
        content += "        windows_core.HRESULT(v.${slotName}(liveRaw${interfaceMethodCallArguments(pairs)}))\n"
        content += "    }\n\n"
    }
    return content
}

func interfaceEventRegistrationTokenOutSlotNames(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<String> {
    let names = ArrayList<String>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        if (isOutParameter(parameter) && isEventRegistrationTokenSignature(signature, symbolsByName, ownerFullName)) {
            names.add(interfaceParameterName(parameter, index))
        }
        index += 1
    }
    if (isEventRegistrationTokenSignature(method.signature.returnType, symbolsByName, ownerFullName)) {
        names.add(interfaceReturnParameterName(method))
    }
    return names
}

func isEventRegistrationTokenSignature(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    match (eventRegistrationTokenRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(_) => return true
        case None => return false
    }
}

func renderGenericWinrtSignatureFunction(
    genericTypeName: String,
    guidValue: String,
    genericNames: ArrayList<String>
): String {
    var content = "    public static func signature(): String {\n"
    content += "        var sb = StringBuilder()\n"
    content += "        sb.append(\"pinterface({${guidValue}}\")\n"
    for (name in genericNames) {
        content += "        sb.append(\";\")\n"
        content += "        sb.append(${name}.signature())\n"
    }
    content += "        sb.append(\")\")\n"
    content += "        return sb.toString()\n"
    content += "    }\n\n"
    return content
}

func genericParameterNames(typeDef: TypeDefinitionRecord): ArrayList<String> {
    let names = ArrayList<String>()
    var index: Int64 = 0
    for (parameter in typeDef.genericParameters) {
        let name = cjIdentifier(parameter.name)
        if (name.isEmpty() || name == "_") {
            names.add("T${index}")
        } else {
            names.add(name)
        }
        index += 1
    }
    return names
}

func genericParameterList(names: ArrayList<String>): String {
    if (names.isEmpty()) {
        return ""
    }
    return "<${joinStrings(names, ", ")}>"
}

func genericRuntimeWhereClause(names: ArrayList<String>): String {
    if (names.isEmpty()) {
        return ""
    }
    let constraints = ArrayList<String>()
    for (name in names) {
        constraints.add("${name} <: windows_core.RuntimeType & windows_core.WinrtGenericType<${name}>")
    }
    return " where ${joinStrings(constraints, ", ")}"
}

func interfaceCFuncParameterTypes(pairs: ArrayList<ParameterPair>): String {
    let values = ArrayList<String>()
    values.add("CPointer<Unit>")
    for (pair in pairs) {
        values.add(pair.typeName)
    }
    return joinStrings(values, ", ")
}

func interfaceClosurePlaceholders(count: Int64): String {
    let values = ArrayList<String>()
    var index: Int64 = 0
    while (index < count) {
        values.add("_")
        index += 1
    }
    return joinStrings(values, ", ")
}

func interfaceClosureParameterNames(pairs: ArrayList<ParameterPair>): String {
    var content = ""
    for (pair in pairs) {
        content += ", ${pair.name}"
    }
    return content
}

func interfaceMethodCallArguments(pairs: ArrayList<ParameterPair>): String {
    if (pairs.isEmpty()) {
        return ""
    }
    return ", ${argumentPairListText(pairs)}"
}

func interfaceMethodSchemas(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (typeDef.methods.isEmpty()) {
        return "Array<windows_interface.InterfaceMethodSchema>(0, { _ => windows_interface.InterfaceMethodSchema(\"\", 0, Array<windows_interface.InterfaceParameterSchema>(0, { _ => windows_interface.InterfaceParameterSchema(\"\", \"\", \"\", windows_interface.InterfaceParameterBridgeKind.Value) }), \"\") })"
    }
    let rendered = ArrayList<String>()
    let slotNames = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, slotNames)
        slotNames.add(slotName)
        rendered.add(
            "windows_interface.InterfaceMethodSchema(\"${slotName}\", ${interfaceParameterSchemas(method, symbolsByName, ownerFullName)}, \"Int32\")"
        )
    }
    return "[${joinStrings(rendered, ", ")}]"
}

func interfaceParameterSchemas(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let rendered = ArrayList<String>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        let parameterName = interfaceParameterName(parameter, index)
        if (isWinrtArraySignature(signature)) {
            let arrayPairs = ArrayList<ParameterPair>()
            addInterfaceArrayAbiPairs(
                arrayPairs,
                parameterName,
                signature,
                parameter,
                symbolsByName,
                ownerFullName
            )
            addInterfaceValueParameterSchemas(rendered, arrayPairs)
        } else if (isOutParameter(parameter)) {
            let targetSignature = runtimeReferenceTargetSignature(signature)
            let abiValueType = interfaceSlotAbiType(targetSignature, symbolsByName, ownerFullName)
            let abiType = "CPointer<${abiValueType}>"
            rendered.add(interfaceParameterSchemaLiteral(
                parameterName,
                abiType,
                interfaceOutSlotCallerType(targetSignature, abiValueType, symbolsByName, ownerFullName),
                "windows_interface.InterfaceParameterBridgeKind.OutSlot"
            ))
        } else {
            let pair = ParameterPair(
                parameterName,
                interfaceParameterAbiType(signature, parameter, symbolsByName, ownerFullName)
            )
            rendered.add(interfaceValueParameterSchemaLiteral(pair))
        }
        index += 1
    }
    if (isWinrtArraySignature(method.signature.returnType)) {
        let arrayPairs = ArrayList<ParameterPair>()
        addInterfaceArrayAbiPairs(
            arrayPairs,
            interfaceReturnParameterName(method),
            method.signature.returnType,
            None,
            symbolsByName,
            ownerFullName,
            out: true
        )
        addInterfaceValueParameterSchemas(rendered, arrayPairs)
    } else {
        let returnType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, ownerFullName)
        if (returnType != "Unit") {
            let resultName = interfaceReturnParameterName(method)
            rendered.add(interfaceParameterSchemaLiteral(
                resultName,
                "CPointer<${returnType}>",
                interfaceOutSlotCallerType(method.signature.returnType, returnType, symbolsByName, ownerFullName),
                "windows_interface.InterfaceParameterBridgeKind.OutSlot"
            ))
        }
    }
    if (rendered.isEmpty()) {
        return "Array<windows_interface.InterfaceParameterSchema>(0, { _ => windows_interface.InterfaceParameterSchema(\"\", \"\", \"\", windows_interface.InterfaceParameterBridgeKind.Value) })"
    }
    return "[${joinStrings(rendered, ", ")}]"
}

func interfaceParameterSchemaLiteral(name: String, abiType: String, callerType: String, bridgeKind: String): String {
    "windows_interface.InterfaceParameterSchema(\"${name}\", \"${abiType}\", \"${callerType}\", ${bridgeKind})"
}

func interfaceValueParameterSchemaLiteral(pair: ParameterPair): String {
    interfaceParameterSchemaLiteral(
        pair.name,
        pair.typeName,
        pair.typeName,
        "windows_interface.InterfaceParameterBridgeKind.Value"
    )
}

func addInterfaceValueParameterSchemas(rendered: ArrayList<String>, pairs: ArrayList<ParameterPair>): Unit {
    for (pair in pairs) {
        rendered.add(interfaceValueParameterSchemaLiteral(pair))
    }
}

func interfaceSchemaCallerValueType(abiValueType: String, projectedType: String): String {
    if (abiValueType == projectedType) {
        return projectedType
    }
    if (abiValueType == "CPointer<Unit>") {
        return projectedType
    }
    return abiValueType
}

func interfaceOutSlotCallerType(
    signature: SignatureRecord,
    abiValueType: String,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let projectedType = winrtProjectedTypeName(signature, symbolsByName, ownerFullName)
    let callerValueType = interfaceSchemaCallerValueType(abiValueType, projectedType)
    "OutSlot<${callerValueType}>"
}

func interfaceMethodMacroParams(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, ownerFullName)
    let rendered = ArrayList<String>()
    for (pair in pairs) {
        rendered.add("${pair.name}: ${pair.typeName}")
    }
    joinStrings(rendered, ", ")
}

func interfaceMethodMacroParameterPairs(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<ParameterPair> {
    let pairs = ArrayList<ParameterPair>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        let parameterName = interfaceParameterName(parameter, index)
        if (isWinrtArraySignature(signature)) {
            addInterfaceArrayAbiPairs(pairs, parameterName, signature, parameter, symbolsByName, ownerFullName)
        } else {
            pairs.add(ParameterPair(
                parameterName,
                interfaceParameterAbiType(signature, parameter, symbolsByName, ownerFullName)
            ))
        }
        index += 1
    }
    if (isWinrtArraySignature(method.signature.returnType)) {
        addInterfaceArrayAbiPairs(
            pairs,
            interfaceReturnParameterName(method),
            method.signature.returnType,
            None,
            symbolsByName,
            ownerFullName,
            out: true
        )
    } else {
        let returnType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, ownerFullName)
        if (returnType != "Unit") {
            pairs.add(ParameterPair(interfaceReturnParameterName(method), "CPointer<${returnType}>"))
        }
    }
    return pairs
}

func isWinrtArraySignature(signature: SignatureRecord): Bool {
    match (winrtArraySignature(signature)) {
        case Some(_) => return true
        case None => return false
    }
}

func isByReferenceSignature(signature: SignatureRecord): Bool {
    return signature.kind == "ByReference" || signature.kind == "Reference"
}

func winrtArraySignature(signature: SignatureRecord): Option<SignatureRecord> {
    if (signature.kind == "SZArray" || signature.kind == "Array") {
        return Some(signature)
    }
    if (isByReferenceSignature(signature)) {
        match (signature.typeSig) {
            case Some(nested) => return winrtArraySignature(nested)
            case None => ()
        }
    }
    return None
}

func addInterfaceArrayAbiPairs(
    pairs: ArrayList<ParameterPair>,
    name: String,
    signature: SignatureRecord,
    parameter: Option<ParameterRecord>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    out!: Bool = false
): Unit {
    let elementType = interfaceArrayElementAbiType(signature, symbolsByName, ownerFullName)
    if ((out || isOutParameter(parameter)) && !isCallerAllocatedOutArrayParameter(parameter)) {
        pairs.add(ParameterPair("${name}Size", "CPointer<UInt32>"))
        pairs.add(ParameterPair(name, "CPointer<CPointer<${elementType}>>"))
    } else {
        pairs.add(ParameterPair("${name}Size", "UInt32"))
        if (isCallerAllocatedOutArrayParameter(parameter) && elementType == "CPointer<Unit>") {
            pairs.add(ParameterPair(name, "CPointer<Unit>"))
        } else {
            pairs.add(ParameterPair(name, "CPointer<${elementType}>"))
        }
    }
}

func interfaceArrayElementAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    match (winrtArraySignature(signature)) {
        case Some(arraySignature) =>
            match (arraySignature.typeSig) {
                case Some(elementSignature) => return interfaceSlotAbiType(elementSignature, symbolsByName, ownerFullName)
                case None => ()
            }
        case None => ()
    }
    return "Unit"
}

func runtimeArrayElementSignature(signature: SignatureRecord): Option<SignatureRecord> {
    match (winrtArraySignature(signature)) {
        case Some(arraySignature) =>
            match (arraySignature.typeSig) {
                case Some(elementSignature) => return Some(elementSignature)
                case None => ()
            }
        case None => ()
    }
    return None
}

func runtimeArrayElementCanProject(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    match (runtimeArrayElementSignature(signature)) {
        case Some(elementSignature) =>
            let projectedType = winrtProjectedTypeName(elementSignature, symbolsByName, ownerFullName)
            let abiType = interfaceSlotAbiType(elementSignature, symbolsByName, ownerFullName)
            return projectedType != "CPointer<Unit>" && abiType != "Unit"
        case None => return false
    }
}

func runtimeArrayElementUsesHandleBorrow(projectedType: String, abiType: String): Bool {
    return abiType == "CPointer<Unit>" && projectedType != "CPointer<Unit>"
}

func runtimeReferenceTargetSignature(signature: SignatureRecord): SignatureRecord {
    if (isByReferenceSignature(signature)) {
        match (signature.typeSig) {
            case Some(nested) => return nested
            case None => ()
        }
        match (signature.unmodifiedType) {
            case Some(nested) => return nested
            case None => ()
        }
    }
    return signature
}

func isOutParameter(parameter: Option<ParameterRecord>): Bool {
    match (parameter) {
        case Some(value) => return contains(value.attributes, "Out")
        case None => return false
    }
}

func isCallerAllocatedOutArrayParameter(parameter: Option<ParameterRecord>): Bool {
    match (parameter) {
        case Some(value) =>
            if (!contains(value.attributes, "Out")) {
                return false
            }
            for (attribute in value.customAttributes) {
                if (hasAttributeName(attribute, "LengthIsAttribute")) {
                    return true
                }
            }
            return false
        case None => return false
    }
}

func interfaceParameterName(parameter: Option<ParameterRecord>, index: Int64): String {
    match (parameter) {
        case Some(value) =>
            let name = cjIdentifier(value.name)
            if (!name.isEmpty() && name != "_") {
                return name
            }
        case None => ()
    }
    "p${index}"
}

func interfaceReturnParameterName(method: MethodRecord): String {
    for (parameter in method.parameters) {
        if (parameter.sequenceNumber == 0) {
            let name = cjIdentifier(parameter.name)
            if (!name.isEmpty() && name != "_") {
                return name
            }
        }
    }
    "result"
}

func metadataMethodParameters(method: MethodRecord): ArrayList<ParameterRecord> {
    let metadataParameters = ArrayList<ParameterRecord>()
    for (parameter in method.parameters) {
        if (parameter.sequenceNumber > 0) {
            metadataParameters.add(parameter)
        }
    }
    return metadataParameters
}

func metadataParameterAt(parameters: ArrayList<ParameterRecord>, index: Int64): Option<ParameterRecord> {
    if (index < Int64(parameters.size)) {
        return Some(parameters[index])
    }
    return None
}

func interfaceParameterAbiType(
    signature: SignatureRecord,
    parameter: Option<ParameterRecord>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let targetSignature = runtimeReferenceTargetSignature(signature)
    let typeName = interfaceSlotAbiType(targetSignature, symbolsByName, ownerFullName)
    match (parameter) {
        case Some(metadata) =>
            if (contains(metadata.attributes, "Out")) {
                return "CPointer<${typeName}>"
            }
        case None => ()
    }
    if (isByReferenceSignature(signature)) {
        return "CPointer<${typeName}>"
    }
    return typeName
}

func interfaceSlotAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    match (win32TextPointerRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (eventRegistrationTokenRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (hresultRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (win32ScalarRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (stringHandleRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            if (fullName == "System.Guid") {
                return "GUID"
            }
            if (!startsWith(fullName, "System.")) {
                match (symbolsByName.get(fullName)) {
                    case Some(_) => ()
                    case None => return "CPointer<Unit>"
                }
            }
        case None => ()
    }
    return cjAbiTypeInContext(signature, symbolsByName, ownerFullName)
}

func uniqueInterfaceSlotName(method: MethodRecord, seen: ArrayList<String>): String {
    var base = projectedMethodBaseName(method)
    base = cjIdentifier(base)
    if (!containsExactString(seen, base)) {
        return base
    }
    var suffix: Int64 = 1
    var candidate = "${base}_${suffix}"
    while (containsExactString(seen, candidate)) {
        suffix += 1
        candidate = "${base}_${suffix}"
    }
    return candidate
}

func containsExactString(values: ArrayList<String>, expected: String): Bool {
    for (value in values) {
        if (value == expected) {
            return true
        }
    }
    return false
}

func projectedMethodBaseName(method: MethodRecord): String {
    if (contains(method.attributes, "SpecialName")) {
        if (startsWith(method.name, "get_")) {
            return stripPrefix(method.name, 4)
        }
        if (startsWith(method.name, "put_")) {
            return "Set${stripPrefix(method.name, 4)}"
        }
        if (startsWith(method.name, "add_")) {
            return stripPrefix(method.name, 4)
        }
        if (startsWith(method.name, "remove_")) {
            return "Remove${stripPrefix(method.name, 7)}"
        }
        return method.name
    }
    match (methodOverloadProjectionName(method)) {
        case Some(name) => return name
        case None => return method.name
    }
}

func methodOverloadProjectionName(method: MethodRecord): Option<String> {
    for (attribute in method.customAttributes) {
        if (hasAttributeName(attribute, "OverloadAttribute") && attribute.fixedArguments.size > 0) {
            match (fixedArgumentString(attribute.fixedArguments[0])) {
                case Some(name) =>
                    if (isGeneratedOverloadName(method.name, name)) {
                        return Some(method.name)
                    }
                    return Some(name)
                case None => ()
            }
        }
    }
    return None
}

func isGeneratedOverloadName(methodName: String, overloadName: String): Bool {
    if (!startsWith(overloadName, methodName)) {
        return false
    }
    let suffix = stripPrefix(overloadName, Int64(methodName.toArray().size))
    return isAsciiDecimalDigits(suffix)
}

func isAsciiDecimalDigits(value: String): Bool {
    let bytes = value.toArray()
    if (bytes.isEmpty()) {
        return false
    }
    for (byte in bytes) {
        if (byte < b'0' || byte > b'9') {
            return false
        }
    }
    return true
}

func stripPrefix(value: String, count: Int64): String {
    let bytes = value.toArray()
    if (count >= Int64(bytes.size)) {
        return ""
    }
    return String.fromUtf8(bytes[count..Int64(bytes.size)])
}

func guidAttributeLiteral(typeDef: TypeDefinitionRecord): Option<String> {
    match (guidAttributeValues(typeDef)) {
        case Some(rawValues) =>
            let values = ArrayList<String>()
            var i: Int64 = 0
            while (i < 11) {
                values.add(guidLiteralPart(rawValues[i], i))
                i += 1
            }
            return Some("return windows_core.GUID.from_values(${joinStrings(values, ", ")})")
        case None => return None
    }
}

func guidAttributeString(typeDef: TypeDefinitionRecord): Option<String> {
    match (guidAttributeValues(typeDef)) {
        case Some(values) =>
            return Some(
                "${fixedWidthHex(values[0], 8)}-" +
                "${fixedWidthHex(values[1], 4)}-" +
                "${fixedWidthHex(values[2], 4)}-" +
                "${fixedWidthHex(values[3], 2)}${fixedWidthHex(values[4], 2)}-" +
                "${fixedWidthHex(values[5], 2)}${fixedWidthHex(values[6], 2)}" +
                "${fixedWidthHex(values[7], 2)}${fixedWidthHex(values[8], 2)}" +
                "${fixedWidthHex(values[9], 2)}${fixedWidthHex(values[10], 2)}"
            )
        case None => return None
    }
}

func guidAttributeValues(typeDef: TypeDefinitionRecord): Option<ArrayList<Int64>> {
    for (attr in typeDef.customAttributes) {
        if (hasAttributeName(attr, "GuidAttribute") && attr.fixedArguments.size >= 11) {
            let rawValues = ArrayList<Int64>()
            var i: Int64 = 0
            while (i < 11) {
                match (fixedArgumentInt64(attr.fixedArguments[i])) {
                    case Some(value) => rawValues.add(value)
                    case None => return None
                }
                i += 1
            }
            return Some(rawValues)
        }
    }
    return None
}

func fixedWidthHex(value: Int64, width: Int64): String {
    var result = ""
    var remaining = value
    var cursor: Int64 = 0
    while (cursor < width) {
        result = hexDigit(remaining % 16) + result
        remaining /= 16
        cursor += 1
    }
    result
}

func hexDigit(value: Int64): String {
    match (value) {
        case 0 => return "0"
        case 1 => return "1"
        case 2 => return "2"
        case 3 => return "3"
        case 4 => return "4"
        case 5 => return "5"
        case 6 => return "6"
        case 7 => return "7"
        case 8 => return "8"
        case 9 => return "9"
        case 10 => return "a"
        case 11 => return "b"
        case 12 => return "c"
        case 13 => return "d"
        case 14 => return "e"
        case 15 => return "f"
        case _ => return "0"
    }
}

func guidLiteralPart(value: Int64, index: Int64): String {
    if (index == 0) {
        return "${value}u32"
    }
    if (index == 1 || index == 2) {
        return "${value}u16"
    }
    return "${value}u8"
}

func renderRawHandleSymbol(symbol: SymbolRecord, kind: String): String {
    if (kind == "delegate") {
        return renderRawDelegateHandleSymbol(symbol)
    }
    return "public class ${symbol.implName} <: Resource {\n" +
        "    private let raw: CPointer<Unit>\n" +
        "    private var ownsHandle: Bool = false\n" +
        "    private var closed: Bool = false\n" +
        "\n" +
        "    public init(raw: CPointer<Unit>) {\n" +
        "        this.raw = raw\n" +
        "    }\n" +
        "\n" +
        "    public init(raw: CPointer<Unit>, takeOwnership!: Bool) {\n" +
        "        if (takeOwnership && raw.isNull()) {\n" +
        "            throw windows_core.WindowsException(windows_core.E_POINTER)\n" +
        "        }\n" +
        "        this.raw = raw\n" +
        "        this.ownsHandle = takeOwnership\n" +
        "    }\n" +
        "\n" +
        "    public func asRaw(): CPointer<Unit> {\n" +
        "        if (closed) {\n" +
        "            return CPointer<Unit>()\n" +
        "        }\n" +
        "        raw\n" +
        "    }\n" +
        "\n" +
        "    public func isClosed(): Bool {\n" +
        "        closed\n" +
        "    }\n" +
        "\n" +
        "    public func close(): Unit {\n" +
        "        if (closed) {\n" +
        "            return\n" +
        "        }\n" +
        "        let shouldRelease = ownsHandle\n" +
        "        ownsHandle = false\n" +
        "        closed = true\n" +
        "        if (shouldRelease) {\n" +
        "            ${symbol.implName}.releaseRaw(raw)\n" +
        "        }\n" +
        "    }\n" +
        "\n" +
        "    public static func addRefRaw(raw: CPointer<Unit>): Unit {\n" +
        "        if (raw.isNull()) {\n" +
        "            return\n" +
        "        }\n" +
        "        unsafe {\n" +
        "            let vtblPtr = CPointer<CPointer<windows_interface.IUnknownVtbl>>(raw).read()\n" +
        "            if (vtblPtr.isNotNull()) {\n" +
        "                let vtbl = vtblPtr.read()\n" +
        "                let _ = vtbl.AddRef(raw)\n" +
        "            }\n" +
        "        }\n" +
        "    }\n" +
        "\n" +
        "    private static func releaseRaw(raw: CPointer<Unit>): Unit {\n" +
        "        if (raw.isNull()) {\n" +
        "            return\n" +
        "        }\n" +
        "        unsafe {\n" +
        "            let vtblPtr = CPointer<CPointer<windows_interface.IUnknownVtbl>>(raw).read()\n" +
        "            if (vtblPtr.isNotNull()) {\n" +
        "                let vtbl = vtblPtr.read()\n" +
        "                let _ = vtbl.Release(raw)\n" +
        "            }\n" +
        "        }\n" +
        "    }\n" +
        "\n" +
        "    public static func runtimeName(): String {\n" +
        "        return \"${cjStringContent(symbol.fullName)}\"\n" +
        "    }\n" +
        "    public static func projectionKind(): String {\n" +
        "        return \"${kind}\"\n" +
        "    }\n" +
        "}\n\n" +
        "extend ${symbol.implName} <: windows_core.HandleWinrtType<${symbol.implName}> {\n" +
        "    public static func intoWinrtHandle(value: ${symbol.implName}): CPointer<Unit> {\n" +
        "        value.asRaw()\n" +
        "    }\n\n" +
        "    public static func intoOwnedWinrtHandle(value: ${symbol.implName}): CPointer<Unit> {\n" +
        "        let raw = value.asRaw()\n" +
        "        if (raw.isNull()) {\n" +
        "            return CPointer<Unit>()\n" +
        "        }\n" +
        "        ${symbol.implName}.addRefRaw(raw)\n" +
        "        raw\n" +
        "    }\n\n" +
        "    public static func fromAbiTakeWinrtHandle(raw: CPointer<Unit>): ${symbol.implName} {\n" +
        "        ${symbol.implName}(raw, takeOwnership: true)\n" +
        "    }\n\n" +
        "    public static func viewWinrtHandle(raw: CPointer<Unit>): ${symbol.implName} {\n" +
        "        ${symbol.implName}(raw, takeOwnership: false)\n" +
        "    }\n\n" +
        "    public static func cloneWinrtValue(value: ${symbol.implName}): ${symbol.implName} {\n" +
        "        let raw = ${symbol.implName}.intoOwnedWinrtHandle(value)\n" +
        "        if (raw.isNull()) {\n" +
        "            throw windows_core.WindowsException(windows_core.E_POINTER)\n" +
        "        }\n" +
        "        ${symbol.implName}(raw, takeOwnership: true)\n" +
        "    }\n" +
        "}"
}

func renderRawDelegateHandleSymbol(symbol: SymbolRecord): String {
    return "public class ${symbol.implName} <: Resource {\n" +
        "    private let raw: CPointer<Unit>\n" +
        "    private var ownsHandle: Bool = false\n" +
        "    private var closed: Bool = false\n" +
        "\n" +
        "    public init(raw: CPointer<Unit>) {\n" +
        "        this.raw = raw\n" +
        "    }\n" +
        "\n" +
        "    public init(raw: CPointer<Unit>, takeOwnership!: Bool) {\n" +
        "        if (takeOwnership && raw.isNull()) {\n" +
        "            throw windows_core.WindowsException(windows_core.E_POINTER)\n" +
        "        }\n" +
        "        this.raw = raw\n" +
        "        this.ownsHandle = takeOwnership\n" +
        "    }\n" +
        "\n" +
        "    public func asRaw(): CPointer<Unit> {\n" +
        "        if (closed) {\n" +
        "            return CPointer<Unit>()\n" +
        "        }\n" +
        "        raw\n" +
        "    }\n" +
        "\n" +
        "    public func isClosed(): Bool {\n" +
        "        closed\n" +
        "    }\n" +
        "\n" +
        "    public func close(): Unit {\n" +
        "        if (closed) {\n" +
        "            return\n" +
        "        }\n" +
        "        let shouldRelease = ownsHandle\n" +
        "        ownsHandle = false\n" +
        "        closed = true\n" +
        "        if (shouldRelease) {\n" +
        "            ${symbol.implName}.releaseRaw(raw)\n" +
        "        }\n" +
        "    }\n" +
        "\n" +
        "    public static func addRefRaw(raw: CPointer<Unit>): Unit {\n" +
        "        if (raw.isNull()) {\n" +
        "            return\n" +
        "        }\n" +
        "        unsafe {\n" +
        "            let vtblPtr = CPointer<CPointer<windows_interface.IUnknownVtbl>>(raw).read()\n" +
        "            if (vtblPtr.isNotNull()) {\n" +
        "                let vtbl = vtblPtr.read()\n" +
        "                let _ = vtbl.AddRef(raw)\n" +
        "            }\n" +
        "        }\n" +
        "    }\n" +
        "\n" +
        "    private static func releaseRaw(raw: CPointer<Unit>): Unit {\n" +
        "        if (raw.isNull()) {\n" +
        "            return\n" +
        "        }\n" +
        "        unsafe {\n" +
        "            let vtblPtr = CPointer<CPointer<windows_interface.IUnknownVtbl>>(raw).read()\n" +
        "            if (vtblPtr.isNotNull()) {\n" +
        "                let vtbl = vtblPtr.read()\n" +
        "                let _ = vtbl.Release(raw)\n" +
        "            }\n" +
        "        }\n" +
        "    }\n" +
        "\n" +
        "    public static func runtimeName(): String {\n" +
        "        return \"${cjStringContent(symbol.fullName)}\"\n" +
        "    }\n" +
        "\n" +
        "    public static func projectionKind(): String {\n" +
        "        return \"delegate\"\n" +
        "    }\n" +
        "}\n\n" +
        "extend ${symbol.implName} <: windows_core.HandleWinrtType<${symbol.implName}> {\n" +
        "    public static func intoWinrtHandle(value: ${symbol.implName}): CPointer<Unit> {\n" +
        "        value.asRaw()\n" +
        "    }\n\n" +
        "    public static func intoOwnedWinrtHandle(value: ${symbol.implName}): CPointer<Unit> {\n" +
        "        let raw = value.asRaw()\n" +
        "        if (raw.isNull()) {\n" +
        "            return CPointer<Unit>()\n" +
        "        }\n" +
        "        ${symbol.implName}.addRefRaw(raw)\n" +
        "        raw\n" +
        "    }\n\n" +
        "    public static func fromAbiTakeWinrtHandle(raw: CPointer<Unit>): ${symbol.implName} {\n" +
        "        ${symbol.implName}(raw, takeOwnership: true)\n" +
        "    }\n\n" +
        "    public static func viewWinrtHandle(raw: CPointer<Unit>): ${symbol.implName} {\n" +
        "        ${symbol.implName}(raw, takeOwnership: false)\n" +
        "    }\n\n" +
        "    public static func cloneWinrtValue(value: ${symbol.implName}): ${symbol.implName} {\n" +
        "        let raw = ${symbol.implName}.intoOwnedWinrtHandle(value)\n" +
        "        if (raw.isNull()) {\n" +
        "            throw windows_core.WindowsException(windows_core.E_POINTER)\n" +
        "        }\n" +
        "        ${symbol.implName}(raw, takeOwnership: true)\n" +
        "    }\n" +
        "}"
}

func renderWinrtRuntimeClassSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    match (defaultWinrtClassInterfaceSpec(typeDef, symbolsByName, symbol.fullName)) {
        case Some(defaultInterface) =>
            let defaultInterfaceName = defaultInterface.typeName
            let interfaceSpecs = winrtClassInterfaceSpecs(typeDef, symbolsByName, symbol.fullName, defaultInterface)
            var content = "public class ${symbol.implName} <: windows_interface.InterfaceWrapperBase & " +
                "windows_interface.ComInterface & windows_interface.RuntimeName & windows_interface.RuntimeType & " +
                "windows_core.RuntimeName & windows_core.RuntimeType {\n"
            content += "    public init(raw: CPointer<Unit>) {\n"
            content += "        super(raw)\n"
            content += "    }\n\n"
            content += "    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {\n"
            content += "        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)\n"
            content += "    }\n\n"
            content += "    public static func fromAbiTake(raw: CPointer<Unit>): ${symbol.implName} {\n"
            content += "        ${symbol.implName}(raw, takeOwnership: true, allowManualRelease: false)\n"
            content += "    }\n\n"
            content += "    public static func viewOf(raw: CPointer<Unit>): ${symbol.implName} {\n"
            content += "        ${symbol.implName}(raw, takeOwnership: false, allowManualRelease: false)\n"
            content += "    }\n\n"
            content += "    public static func iid(): windows_interface.GUID {\n"
            content += "        ${defaultInterfaceName}.iid()\n"
            content += "    }\n\n"
            content += "    public static func descriptor(): windows_interface.InterfaceDescriptor<${symbol.implName}> {\n"
            content += "        let ancestors = [${runtimeClassAncestorIidExpressions(interfaceSpecs)}]\n"
            content += "        return windows_interface.InterfaceDescriptor<${symbol.implName}>(\"${cjStringContent(symbol.name)}\", " +
                "${defaultInterfaceName}.iid(), ancestors, { raw => ${symbol.implName}.fromAbiTake(raw) }, " +
                "{ raw => ${symbol.implName}.viewOf(raw) })\n"
            content += "    }\n\n"
            content += "    public func defaultInterface(): ${defaultInterfaceName} {\n"
            content += "        match (unsafe { query(${defaultInterfaceName}.descriptor()) }) {\n"
            content += "            case Some(value) => value\n"
            content += "            case None => throw windows_core.WindowsException(windows_core.E_NOINTERFACE)\n"
            content += "        }\n"
            content += "    }\n\n"
            content += "    public func asIInspectable(): windows_interface.IInspectable {\n"
            content += "        windows_interface.IInspectable.viewOf(asRaw())\n"
            content += "    }\n\n"
            for (interfaceSpec in interfaceSpecs) {
                content += renderRuntimeClassInterfaceAccessor(interfaceSpec, interfaceSpecs, defaultInterface)
            }
            content += renderRuntimeClassDefaultInterfaceMembers(symbol, defaultInterface, symbolsByName)
            if (hasDefaultActivatableConstructor(typeDef)) {
                content += "    public static func new(): ${symbol.implName} {\n"
                content += "        var created__: Option<${symbol.implName}> = Option<${symbol.implName}>.None\n"
                content += "        try (factory__ = windows_core.factory<${symbol.implName}, windows_core.IGenericFactory>().unwrap()) {\n"
                content += "            created__ = Some(unsafe { factory__.ActivateInstance<${symbol.implName}>(${symbol.implName}.descriptor()).unwrap() })\n"
                content += "        }\n"
                content += "        match (created__) {\n"
                content += "            case Some(value) => return value\n"
                content += "            case None => throw IllegalStateException(\"Activation factory did not produce ${cjStringContent(symbol.name)}\")\n"
                content += "        }\n"
                content += "    }\n\n"
            }
            content += renderRuntimeClassFactoryMethods(symbol, typeDef, symbolsByName)
            content += "    public static func abiType(): String {\n"
            content += "        \"CPointer<Unit>\"\n"
            content += "    }\n\n"
            content += "    public static func runtimeName(): String {\n"
            content += "        \"${cjStringContent(symbol.fullName)}\"\n"
            content += "    }\n\n"
            content += "    public static func signature(): String {\n"
            content += "        return \"rc(${cjStringContent(symbol.fullName)};{\" + ${defaultInterfaceName}.iid().toSignatureString() + \"})\"\n"
            content += "    }\n\n"
            content += "    public static func runtimeType(): windows_interface.RuntimeTypeContract {\n"
            content += "        windows_interface.RuntimeTypeContract(\"${cjStringContent(symbol.fullName)}\", " +
                "${symbol.implName}.signature(), ${defaultInterfaceName}.iid())\n"
            content += "    }\n"
            content += "}\n\n"
            content += "extend ${symbol.implName} <: windows_core.HandleWinrtType<${symbol.implName}> {\n"
            content += "    public static func intoWinrtHandle(value: ${symbol.implName}): CPointer<Unit> {\n"
            content += "        value.asRaw()\n"
            content += "    }\n\n"
            content += "    public static func fromAbiTakeWinrtHandle(raw: CPointer<Unit>): ${symbol.implName} {\n"
            content += "        if (raw.isNull()) {\n"
            content += "            throw windows_core.WindowsException(windows_core.E_POINTER)\n"
            content += "        }\n"
            content += "        ${symbol.implName}.fromAbiTake(raw)\n"
            content += "    }\n\n"
            content += "    public static func viewWinrtHandle(raw: CPointer<Unit>): ${symbol.implName} {\n"
            content += "        ${symbol.implName}.viewOf(raw)\n"
            content += "    }\n"
            content += "}"
            return Some(content)
        case None => return renderStaticOnlyWinrtRuntimeClassSymbol(symbol, typeDef, symbolsByName)
    }
}

func renderStaticOnlyWinrtRuntimeClassSymbol(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    let factoryMethods = renderRuntimeClassFactoryMethods(symbol, typeDef, symbolsByName)
    if (factoryMethods.isEmpty()) {
        return None
    }
    var content = "public struct ${symbol.implName} <: windows_interface.RuntimeName & windows_interface.RuntimeType & " +
        "windows_core.RuntimeName & windows_core.RuntimeType {\n"
    content += "    public init() {}\n\n"
    content += factoryMethods
    content += "    public static func abiType(): String {\n"
    content += "        \"CPointer<Unit>\"\n"
    content += "    }\n\n"
    content += "    public static func runtimeName(): String {\n"
    content += "        \"${cjStringContent(symbol.fullName)}\"\n"
    content += "    }\n\n"
    content += "    public static func signature(): String {\n"
    content += "        return \"rc(${cjStringContent(symbol.fullName)})\"\n"
    content += "    }\n\n"
    content += "    public static func runtimeType(): windows_interface.RuntimeTypeContract {\n"
    content += "        windows_interface.RuntimeTypeContract(\"${cjStringContent(symbol.fullName)}\", ${symbol.implName}.signature())\n"
    content += "    }\n"
    content += "}"
    return Some(content)
}

func renderRuntimeClassFactoryMethods(
    symbol: SymbolRecord,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let factories = runtimeClassFactoryInterfaceSpecs(typeDef, symbolsByName, symbol.fullName)
    var content = ""
    for (factorySpec in factories) {
        match (factorySpec.symbol.typeDef) {
            case Some(factoryTypeDef) =>
                let slotNames = ArrayList<String>()
                for (method in factoryTypeDef.methods) {
                    let methodName = uniqueInterfaceSlotName(method, slotNames)
                    slotNames.add(methodName)
                    content += renderRuntimeClassFactoryMethod(symbol, factorySpec, method, methodName, symbolsByName)
                }
            case None => ()
        }
    }
    return content
}

func renderRuntimeClassFactoryMethod(
    symbol: SymbolRecord,
    factorySpec: RuntimeClassInterfaceSpec,
    method: MethodRecord,
    methodName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    if (runtimeFactoryRequiresRawAbiShape(method, symbolsByName, symbol.fullName)) {
        return renderRuntimeClassFactoryRawAbiMethod(symbol, factorySpec, method, methodName, symbolsByName)
    }
    let pairs = runtimeProjectedMethodParameterPairs(method, symbolsByName, symbol.fullName)
    let params = parameterPairListText(pairs)
    let callPlan = runtimeClassFactoryCallPlan(method, pairs, symbolsByName, symbol.fullName)
    let returnType = runtimeProjectedReturnTypeName(method.signature.returnType, symbolsByName, symbol.fullName)
    var content = "    public static func ${methodName}(${params}): ${returnType} {\n"
    content += renderRuntimeClassProjectedMethodBody(
        symbol,
        method,
        methodName,
        callPlan,
        symbolsByName,
        2,
        RuntimeDispatchKind.Factory,
        Some(factorySpec)
    )
    content += "    }\n\n"
    return content
}

enum RuntimeDispatchKind {
    | Factory
    | Instance
}

func runtimeFactoryRequiresRawAbiShape(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    if (isWinrtArraySignature(method.signature.returnType) &&
        !runtimeArrayElementCanProject(method.signature.returnType, symbolsByName, ownerFullName)) {
        return true
    }
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        if (isWinrtArraySignature(signature) &&
            !runtimeArrayElementCanProject(signature, symbolsByName, ownerFullName)) {
            return true
        }
        index += 1
    }
    return false
}

func renderRuntimeClassFactoryRawAbiMethod(
    symbol: SymbolRecord,
    factorySpec: RuntimeClassInterfaceSpec,
    method: MethodRecord,
    methodName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, symbol.fullName)
    let params = parameterPairListText(pairs)
    let args = argumentPairListText(pairs)
    var content = "    public static func ${methodName}(${params}): Unit {\n"
    content += "        var hr__ = windows_core.E_POINTER\n"
    content += renderRuntimeClassRawAbiPreDispatchOutSlotClears(method, symbolsByName, symbol.fullName, 2)
    content += "        try (factory__ = windows_core.factory<${symbol.implName}, ${factorySpec.typeName}>().unwrap()) {\n"
    content += "            hr__ = unsafe { factory__.${methodName}(${args}) }\n"
    content += "        }\n"
    content += renderRuntimeClassRawAbiFailureCleanup(method, symbolsByName, symbol.fullName, 2)
    content += "        hr__.check()\n"
    content += "    }\n\n"
    return content
}

func renderRuntimeClassRawAbiPreDispatchOutSlotClears(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    indentLevel: Int64
): String {
    let cleanupSpecs = runtimeClassRawAbiFailedOutSlotCleanupSpecs(method, symbolsByName, ownerFullName)
    let arrayCleanupSpecs = runtimeClassRawAbiFailedArrayOutSlotCleanupSpecs(method, symbolsByName, ownerFullName)
    if (cleanupSpecs.isEmpty() && arrayCleanupSpecs.isEmpty()) {
        return ""
    }
    var content = ""
    for (spec in cleanupSpecs) {
        content += "${runtimeIndent(indentLevel)}if (${spec.slotName}.isNotNull()) {\n"
        content += "${runtimeIndent(indentLevel + 1)}unsafe { ${spec.slotName}.write(CPointer<Unit>()) }\n"
        content += "${runtimeIndent(indentLevel)}}\n"
    }
    for (spec in arrayCleanupSpecs) {
        content += "${runtimeIndent(indentLevel)}if (${spec.sizeSlotName}.isNotNull()) {\n"
        content += "${runtimeIndent(indentLevel + 1)}unsafe { ${spec.sizeSlotName}.write(0u32) }\n"
        content += "${runtimeIndent(indentLevel)}}\n"
        content += "${runtimeIndent(indentLevel)}if (${spec.dataSlotName}.isNotNull()) {\n"
        content += "${runtimeIndent(indentLevel + 1)}unsafe { ${spec.dataSlotName}.write(CPointer<${spec.elementAbiType}>()) }\n"
        content += "${runtimeIndent(indentLevel)}}\n"
    }
    return content
}

func renderRuntimeClassRawAbiFailureCleanup(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    indentLevel: Int64
): String {
    let cleanupSpecs = runtimeClassRawAbiFailedOutSlotCleanupSpecs(method, symbolsByName, ownerFullName)
    let arrayCleanupSpecs = runtimeClassRawAbiFailedArrayOutSlotCleanupSpecs(method, symbolsByName, ownerFullName)
    if (cleanupSpecs.isEmpty() && arrayCleanupSpecs.isEmpty()) {
        return ""
    }
    var content = ""
    content += "${runtimeIndent(indentLevel)}if (hr__.failed()) {\n"
    var index: Int64 = 0
    for (spec in cleanupSpecs) {
        if (runtimeArrayElementUsesHandleBorrow(spec.projectedType, spec.abiType)) {
            let partialName = "__rawAbiOut${index}Partial"
            content += "${runtimeIndent(indentLevel + 1)}if (!${spec.slotName}.isNull()) {\n"
            content += "${runtimeIndent(indentLevel + 2)}let ${partialName} = unsafe { ${spec.slotName}.read() }\n"
            content += "${runtimeIndent(indentLevel + 2)}if (${partialName}.isNotNull()) {\n"
            content += "${runtimeIndent(indentLevel + 3)}windows_core.winrtReleaseGenericOut<${spec.projectedType}>(${partialName})\n"
            content += "${runtimeIndent(indentLevel + 3)}unsafe { ${spec.slotName}.write(CPointer<Unit>()) }\n"
            content += "${runtimeIndent(indentLevel + 2)}}\n"
            content += "${runtimeIndent(indentLevel + 1)}}\n"
        } else {
            content += "${runtimeIndent(indentLevel + 1)}windows_core.releaseFailedComOutSlot(${spec.slotName})\n"
        }
        index += 1
    }
    var arrayIndex: Int64 = 0
    for (spec in arrayCleanupSpecs) {
        let sizeName = "__rawAbiArrayOut${arrayIndex}Size"
        let dataName = "__rawAbiArrayOut${arrayIndex}Data"
        content += "${runtimeIndent(indentLevel + 1)}if (!${spec.sizeSlotName}.isNull() && !${spec.dataSlotName}.isNull()) {\n"
        content += "${runtimeIndent(indentLevel + 2)}let ${sizeName} = unsafe { ${spec.sizeSlotName}.read() }\n"
        content += "${runtimeIndent(indentLevel + 2)}let ${dataName} = unsafe { ${spec.dataSlotName}.read() }\n"
        content += "${runtimeIndent(indentLevel + 2)}if (${dataName}.isNotNull()) {\n"
        if (runtimeArrayElementUsesHandleBorrow(spec.elementProjectedType, spec.elementAbiType)) {
            content += "${runtimeIndent(indentLevel + 3)}windows_core.winrtReleaseGenericArrayOut<${spec.elementProjectedType}>(CPointer<Unit>(${dataName}), ${sizeName})\n"
        } else {
            content += "${runtimeIndent(indentLevel + 3)}windows_core.coTaskMemFree(CPointer<Unit>(${dataName}))\n"
        }
        content += "${runtimeIndent(indentLevel + 3)}unsafe { ${spec.dataSlotName}.write(CPointer<${spec.elementAbiType}>()) }\n"
        content += "${runtimeIndent(indentLevel + 3)}unsafe { ${spec.sizeSlotName}.write(0u32) }\n"
        content += "${runtimeIndent(indentLevel + 2)}}\n"
        content += "${runtimeIndent(indentLevel + 1)}}\n"
        arrayIndex += 1
    }
    content += "${runtimeIndent(indentLevel)}}\n"
    return content
}

func runtimeClassRawAbiFailedOutSlotCleanupSpecs(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<RuntimeRawAbiOutSlotCleanupSpec> {
    let cleanupSpecs = ArrayList<RuntimeRawAbiOutSlotCleanupSpec>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        let targetSignature = runtimeReferenceTargetSignature(signature)
        let projectedType = winrtProjectedTypeName(targetSignature, symbolsByName, ownerFullName)
        let abiType = interfaceSlotAbiType(targetSignature, symbolsByName, ownerFullName)
        var cleanupType = projectedType
        var needsCleanup = runtimeArrayElementUsesHandleBorrow(projectedType, abiType)
        if (!needsCleanup && abiType == "CPointer<Unit>") {
            match (runtimeRawPointerReturnCleanupType(targetSignature)) {
                case Some(rawCleanupType) =>
                    cleanupType = rawCleanupType
                    needsCleanup = true
                case None => ()
            }
        }
        if (!isWinrtArraySignature(signature) && isOutParameter(parameter) &&
            interfaceParameterAbiType(signature, parameter, symbolsByName, ownerFullName) == "CPointer<CPointer<Unit>>" &&
            needsCleanup) {
            cleanupSpecs.add(RuntimeRawAbiOutSlotCleanupSpec(interfaceParameterName(parameter, index), cleanupType, abiType))
        }
        index += 1
    }
    let returnProjectedType = winrtProjectedTypeName(method.signature.returnType, symbolsByName, ownerFullName)
    let returnAbiType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, ownerFullName)
    var returnCleanupType = returnProjectedType
    var returnNeedsCleanup = runtimeArrayElementUsesHandleBorrow(returnProjectedType, returnAbiType)
    if (!returnNeedsCleanup && returnAbiType == "CPointer<Unit>") {
        match (runtimeRawPointerReturnCleanupType(method.signature.returnType)) {
            case Some(rawReturnCleanupType) =>
                returnCleanupType = rawReturnCleanupType
                returnNeedsCleanup = true
            case None => ()
        }
    }
    if (!isWinrtArraySignature(method.signature.returnType) && returnAbiType == "CPointer<Unit>" && returnNeedsCleanup) {
        cleanupSpecs.add(RuntimeRawAbiOutSlotCleanupSpec(interfaceReturnParameterName(method), returnCleanupType, returnAbiType))
    }
    return cleanupSpecs
}

func runtimeClassRawAbiFailedArrayOutSlotCleanupSpecs(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<RuntimeRawAbiArrayOutSlotCleanupSpec> {
    let cleanupSpecs = ArrayList<RuntimeRawAbiArrayOutSlotCleanupSpec>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        if (isWinrtArraySignature(signature) && isOutParameter(parameter)) {
            match (runtimeArrayElementSignature(signature)) {
                case Some(elementSignature) =>
                    let parameterName = interfaceParameterName(parameter, index)
                    cleanupSpecs.add(RuntimeRawAbiArrayOutSlotCleanupSpec(
                        "${parameterName}Size",
                        parameterName,
                        winrtProjectedTypeName(elementSignature, symbolsByName, ownerFullName),
                        interfaceSlotAbiType(elementSignature, symbolsByName, ownerFullName)
                    ))
                case None => ()
            }
        }
        index += 1
    }
    if (isWinrtArraySignature(method.signature.returnType)) {
        match (runtimeArrayElementSignature(method.signature.returnType)) {
            case Some(elementSignature) =>
                let returnName = interfaceReturnParameterName(method)
                cleanupSpecs.add(RuntimeRawAbiArrayOutSlotCleanupSpec(
                    "${returnName}Size",
                    returnName,
                    winrtProjectedTypeName(elementSignature, symbolsByName, ownerFullName),
                    interfaceSlotAbiType(elementSignature, symbolsByName, ownerFullName)
                ))
            case None => ()
        }
    }
    return cleanupSpecs
}

func runtimeClassFactoryCallPlan(
    method: MethodRecord,
    pairs: ArrayList<ParameterPair>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): RuntimeCallPlan {
    let borrows = ArrayList<RuntimeBorrowSpec>()
    let args = ArrayList<String>()
    let arrayInputs = ArrayList<RuntimeArrayInputSpec>()
    let scalarOutputs = ArrayList<RuntimeScalarOutputSpec>()
    let arrayOutputs = ArrayList<RuntimeArrayOutputSpec>()
    let callerAllocatedArrays = ArrayList<RuntimeCallerAllocatedArraySpec>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    // `pairs` is the projected public parameter list. A caller-allocated out
    // array contributes two projected pairs (`${name}Size`, `${name}`), so the
    // pair cursor advances independently from the metadata-parameter index.
    var pairIndex: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        let pair = pairs[pairIndex]
        if (isWinrtArraySignature(signature)) {
            match (runtimeArrayElementSignature(signature)) {
                case Some(elementSignature) =>
                    let elementProjectedType = winrtProjectedTypeName(elementSignature, symbolsByName, ownerFullName)
                    let elementAbiType = interfaceSlotAbiType(elementSignature, symbolsByName, ownerFullName)
                    if (isCallerAllocatedOutArrayParameter(parameter)) {
                        // Caller-allocated fill buffer: forward (size, items)
                        // straight through; the caller owns the buffer. The
                        // buffer is zeroed before the call and any handles
                        // written before a failure are released afterward.
                        let sizePair = pairs[pairIndex]
                        let itemsPair = pairs[pairIndex + 1]
                        args.add(sizePair.name)
                        if (elementAbiType == "CPointer<Unit>") {
                            args.add(itemsPair.name)
                        } else {
                            args.add("CPointer<Unit>(${itemsPair.name})")
                        }
                        callerAllocatedArrays.add(RuntimeCallerAllocatedArraySpec(
                            sizePair.name,
                            itemsPair.name,
                            elementProjectedType,
                            elementAbiType
                        ))
                        pairIndex += 2
                    } else if (isOutParameter(parameter)) {
                        let localPrefix = "__arg${index}"
                        arrayOutputs.add(RuntimeArrayOutputSpec(
                            pair.name,
                            "${localPrefix}Value",
                            "${localPrefix}Data",
                            "${localPrefix}Size",
                            elementProjectedType,
                            elementAbiType,
                            elementSignature
                        ))
                        args.add("CPointer<UInt32>(inout ${localPrefix}Size)")
                        args.add("CPointer<CPointer<${elementAbiType}>>(inout ${localPrefix}Data)")
                        pairIndex += 1
                    } else {
                        let localPrefix = "__arg${index}"
                        arrayInputs.add(RuntimeArrayInputSpec(
                            pair.name,
                            elementProjectedType,
                            elementAbiType,
                            elementSignature,
                            localPrefix,
                            runtimeArrayElementUsesHandleBorrow(elementProjectedType, elementAbiType)
                        ))
                        args.add("${localPrefix}Len")
                        args.add("${localPrefix}Raw")
                        pairIndex += 1
                    }
                case None => pairIndex += 1
            }
        } else if (isOutParameter(parameter)) {
            let targetSignature = runtimeReferenceTargetSignature(signature)
            let projectedType = winrtProjectedTypeName(targetSignature, symbolsByName, ownerFullName)
            let abiType = interfaceSlotAbiType(targetSignature, symbolsByName, ownerFullName)
            let valueName = "__arg${index}Value"
            scalarOutputs.add(RuntimeScalarOutputSpec(pair.name, valueName, projectedType, abiType, targetSignature))
            args.add("${pair.name}.borrowMut<${abiType}>()")
            pairIndex += 1
        } else if (isByReferenceSignature(signature)) {
            args.add(pair.name)
            pairIndex += 1
        } else {
            let abiType = interfaceSlotAbiType(signature, symbolsByName, ownerFullName)
            if (runtimeCallNeedsHandleBorrow(pair.typeName, abiType)) {
                let borrowName = "__argBorrow${borrows.size}"
                borrows.add(RuntimeBorrowSpec(borrowName, pair.typeName, pair.name))
                args.add("${borrowName}.asRaw()")
            } else {
                args.add(runtimeInputAbiExpression(pair.name, pair.typeName, abiType, signature, symbolsByName, ownerFullName))
            }
            pairIndex += 1
        }
        index += 1
    }
    return RuntimeCallPlan(borrows, args, arrayInputs, scalarOutputs, arrayOutputs, callerAllocatedArrays)
}

func runtimeCallNeedsHandleBorrow(typeName: String, abiType: String): Bool {
    return abiType == "CPointer<Unit>" && typeName != "CPointer<Unit>"
}

func runtimeInputAbiExpression(
    name: String,
    typeName: String,
    abiType: String,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (typeName == "windows_core.GuidValue" && abiType == "GUID") {
        return "${name}.toRaw()"
    }
    if (isEnumSignature(signature, symbolsByName, ownerFullName)) {
        return "${name}.value"
    }
    return name
}

func renderRuntimeClassFactoryAbiCall(
    symbol: SymbolRecord,
    factorySpec: RuntimeClassInterfaceSpec,
    methodName: String,
    callPlan: RuntimeCallPlan,
    outputArg: String,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let outputArgs = ArrayList<String>()
    if (!outputArg.isEmpty()) {
        outputArgs.add(outputArg)
    }
    return renderRuntimeClassFactoryAbiCallWithArgs(
        symbol,
        factorySpec,
        methodName,
        callPlan,
        outputArgs,
        symbolsByName,
        ownerFullName
    )
}

func renderRuntimeClassFactoryAbiCallWithArgs(
    symbol: SymbolRecord,
    factorySpec: RuntimeClassInterfaceSpec,
    methodName: String,
    callPlan: RuntimeCallPlan,
    outputArgs: ArrayList<String>,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let callArgs = ArrayList<String>()
    for (arg in callPlan.args) {
        callArgs.add(arg)
    }
    for (arg in outputArgs) {
        callArgs.add(arg)
    }
    var content = ""
    var index: Int64 = 0
    while (index < Int64(callPlan.borrows.size)) {
        let borrow = callPlan.borrows[index]
        content += "${runtimeIndent(2 + index)}try (${borrow.name} = windows_core.winrtBorrowGenericIn<${borrow.typeName}>(${borrow.sourceName})) {\n"
        index += 1
    }
    var callIndentLevel = 2 + Int64(callPlan.borrows.size)
    var arrayIndex: Int64 = 0
    while (arrayIndex < Int64(callPlan.arrayInputs.size)) {
        let spec = callPlan.arrayInputs[arrayIndex]
        content += renderRuntimeArrayInputOpen(spec, callIndentLevel, symbolsByName, ownerFullName)
        callIndentLevel += runtimeArrayInputNesting(spec)
        arrayIndex += 1
    }
    let factoryIndentLevel = callIndentLevel
    content += "${runtimeIndent(factoryIndentLevel)}try (factory__ = windows_core.factory<${symbol.implName}, ${factorySpec.typeName}>().unwrap()) {\n"
    content += "${runtimeIndent(factoryIndentLevel + 1)}hr__ = unsafe { factory__.${methodName}(${joinStrings(callArgs, ", ")}) }\n"
    content += "${runtimeIndent(factoryIndentLevel)}}\n"
    var closeArrayIndex = Int64(callPlan.arrayInputs.size) - 1
    while (closeArrayIndex >= 0) {
        let spec = callPlan.arrayInputs[closeArrayIndex]
        callIndentLevel -= runtimeArrayInputNesting(spec)
        content += renderRuntimeArrayInputClose(spec, callIndentLevel)
        closeArrayIndex -= 1
    }
    var closeIndex = Int64(callPlan.borrows.size) - 1
    while (closeIndex >= 0) {
        content += "${runtimeIndent(2 + closeIndex)}}\n"
        closeIndex -= 1
    }
    return content
}

func runtimeArrayInputNesting(spec: RuntimeArrayInputSpec): Int64 {
    if (spec.usesHandleBorrow) {
        return 2
    }
    return 1
}

func renderRuntimeArrayInputOpen(
    spec: RuntimeArrayInputSpec,
    indentLevel: Int64,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    var content = ""
    if (spec.usesHandleBorrow) {
        content += "${runtimeIndent(indentLevel)}let ${spec.abiValuesName} = Array<CPointer<Unit>>(${spec.sourceName}.size, { _ => CPointer<Unit>() })\n"
        content += "${runtimeIndent(indentLevel)}var ${spec.borrowsName} = Array<Option<windows_core.WinrtInputBorrow>>(${spec.sourceName}.size, { _ => Option<windows_core.WinrtInputBorrow>.None })\n"
        content += "${runtimeIndent(indentLevel)}try {\n"
        content += "${runtimeIndent(indentLevel + 1)}var ${spec.indexName} = 0\n"
        content += "${runtimeIndent(indentLevel + 1)}while (${spec.indexName} < ${spec.sourceName}.size) {\n"
        content += "${runtimeIndent(indentLevel + 2)}let ${spec.borrowName} = windows_core.winrtBorrowGenericIn<${spec.elementProjectedType}>(${spec.sourceName}[${spec.indexName}])\n"
        content += "${runtimeIndent(indentLevel + 2)}${spec.borrowsName}[${spec.indexName}] = Some(${spec.borrowName})\n"
        content += "${runtimeIndent(indentLevel + 2)}${spec.abiValuesName}[${spec.indexName}] = ${spec.borrowName}.asRaw()\n"
        content += "${runtimeIndent(indentLevel + 2)}${spec.indexName} += 1\n"
        content += "${runtimeIndent(indentLevel + 1)}}\n"
        content += "${runtimeIndent(indentLevel + 1)}let ${spec.abiArrayName} = windows_core.AbiArray<CPointer<Unit>>.fromSlice(${spec.abiValuesName})\n"
        content += "${runtimeIndent(indentLevel + 1)}let (${spec.rawName}, ${spec.lenName}) = ${spec.abiArrayName}.intoAbi()\n"
        content += "${runtimeIndent(indentLevel + 1)}try {\n"
        return content
    }

    let abiExpression = runtimeInputAbiExpression(
        "${spec.sourceName}[index]",
        spec.elementProjectedType,
        spec.elementAbiType,
        spec.elementSignature,
        symbolsByName,
        ownerFullName
    )
    content += "${runtimeIndent(indentLevel)}let ${spec.abiValuesName} = Array<${spec.elementAbiType}>(${spec.sourceName}.size, { index => ${abiExpression} })\n"
    content += "${runtimeIndent(indentLevel)}let ${spec.abiArrayName} = windows_core.AbiArray<${spec.elementAbiType}>.fromSlice(${spec.abiValuesName})\n"
    content += "${runtimeIndent(indentLevel)}let (${spec.rawName}, ${spec.lenName}) = ${spec.abiArrayName}.intoAbi()\n"
    content += "${runtimeIndent(indentLevel)}try {\n"
    return content
}

func renderRuntimeArrayInputClose(spec: RuntimeArrayInputSpec, indentLevel: Int64): String {
    var content = ""
    if (spec.usesHandleBorrow) {
        content += "${runtimeIndent(indentLevel + 1)}} finally {\n"
        content += "${runtimeIndent(indentLevel + 2)}windows_core.coTaskMemFree(CPointer<Unit>(${spec.rawName}))\n"
        content += "${runtimeIndent(indentLevel + 1)}}\n"
        content += "${runtimeIndent(indentLevel)}} finally {\n"
        content += "${runtimeIndent(indentLevel + 1)}var ${spec.closeIndexName} = 0\n"
        content += "${runtimeIndent(indentLevel + 1)}while (${spec.closeIndexName} < ${spec.borrowsName}.size) {\n"
        content += "${runtimeIndent(indentLevel + 2)}match (${spec.borrowsName}[${spec.closeIndexName}]) {\n"
        content += "${runtimeIndent(indentLevel + 3)}case Some(borrow) => borrow.close()\n"
        content += "${runtimeIndent(indentLevel + 3)}case None => ()\n"
        content += "${runtimeIndent(indentLevel + 2)}}\n"
        content += "${runtimeIndent(indentLevel + 2)}${spec.closeIndexName} += 1\n"
        content += "${runtimeIndent(indentLevel + 1)}}\n"
        content += "${runtimeIndent(indentLevel)}}\n"
        return content
    }

    content += "${runtimeIndent(indentLevel)}} finally {\n"
    content += "${runtimeIndent(indentLevel + 1)}windows_core.coTaskMemFree(CPointer<Unit>(${spec.rawName}))\n"
    content += "${runtimeIndent(indentLevel)}}\n"
    return content
}

func runtimeProjectedReturnExpression(
    returnType: String,
    returnAbiType: String,
    resultName: String,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (returnType == returnAbiType) {
        return resultName
    }
    if (returnType == "windows_core.GuidValue" && returnAbiType == "GUID") {
        return "windows_core.GuidValue.fromRaw(${resultName})"
    }
    if (isEnumSignature(signature, symbolsByName, ownerFullName)) {
        return "${returnType}(${resultName})"
    }
    if (returnAbiType == "CPointer<Unit>") {
        if (returnType == "windows_core.HString") {
            return "windows_core.HString.fromSystemHandleTake(${resultName})"
        }
        return "${returnType}.fromAbiTakeWinrtHandle(${resultName})"
    }
    return resultName
}

func runtimeRawPointerReturnCleanupType(signature: SignatureRecord): Option<String> {
    if (signature.kind == "Primitive") {
        if (signature.name == "Object") {
            return Some("windows_interface.IInspectable")
        }
        if (signature.name == "String") {
            return Some("windows_core.HString")
        }
    }
    return None
}

// A generic OUT/return whose element is an open generic parameter of the
// parameterized default interface (e.g. IVector<T>.GetAt -> T). The vtable slot
// is type-erased to CPointer<Unit>, so the value must be bridged through the
// element's output bridge rather than assuming a reference-handle shape. The
// projected `T` is finalized to the concrete element type by
// applyRuntimeClassGenericSubstitutions, so emitting winrtTakeGenericOut<T>
// resolves to the correct value/string/reference bridge per closed argument.
func isRuntimeGenericParameterSignature(signature: SignatureRecord): Bool {
    match (signature.typeSpecification) {
        case Some(typeSpec) => return isRuntimeGenericParameterSignature(typeSpec.signature)
        case None => ()
    }
    if (signature.kind == "GenericParameter") {
        return true
    }
    return false
}

func isEnumSignature(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Bool {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            match (symbolsByName.get(fullName)) {
                case Some(symbol) =>
                    match (symbol.typeDef) {
                        case Some(typeDef) => return isEnumType(typeDef)
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }
    return false
}

func runtimeIndent(level: Int64): String {
    var result = ""
    var index: Int64 = 0
    while (index < level) {
        result += "    "
        index += 1
    }
    return result
}

func runtimeClassFactoryInterfaceSpecs(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<RuntimeClassInterfaceSpec> {
    let values = ArrayList<RuntimeClassInterfaceSpec>()
    for (attribute in typeDef.customAttributes) {
        if (isRuntimeClassFactoryAttribute(attribute)) {
            for (fullName in customAttributeTypeNameArgumentFullNames(attribute)) {
                match (symbolsByName.get(fullName)) {
                    case Some(symbol) =>
                        addRuntimeClassFactoryInterfaceSpec(values, symbol)
                    case None =>
                        match (resolveRelativeTypeFullName(ownerFullName, fullName, symbolsByName)) {
                            case Some(relativeFullName) =>
                                match (symbolsByName.get(relativeFullName)) {
                                    case Some(symbol) => addRuntimeClassFactoryInterfaceSpec(values, symbol)
                                    case None => ()
                                }
                            case None => ()
                        }
                }
            }
        }
    }
    return values
}

func addRuntimeClassFactoryInterfaceSpec(values: ArrayList<RuntimeClassInterfaceSpec>, symbol: SymbolRecord): Unit {
    match (symbol.typeDef) {
        case Some(typeDef) =>
            if (isInterfaceType(typeDef)) {
                addUniqueInterfaceSpec(values, RuntimeClassInterfaceSpec(symbol, symbol.implName))
            }
        case None => ()
    }
}

func isRuntimeClassFactoryAttribute(attribute: CustomAttributeRecord): Bool {
    return hasAttributeName(attribute, "StaticAttribute") ||
        hasAttributeName(attribute, "ActivatableAttribute") ||
        hasAttributeName(attribute, "ComposableAttribute")
}

func hasAttributeName(attribute: CustomAttributeRecord, shortName: String): Bool {
    return attribute.typeName == shortName || endsWith(attribute.typeName, ".${shortName}")
}

func winrtProjectedMethodParameterPairs(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<ParameterPair> {
    let pairs = ArrayList<ParameterPair>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        pairs.add(ParameterPair(
            interfaceParameterName(parameter, index),
            winrtProjectedTypeName(signature, symbolsByName, ownerFullName)
        ))
        index += 1
    }
    return pairs
}

func runtimeProjectedMethodParameterPairs(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): ArrayList<ParameterPair> {
    let pairs = ArrayList<ParameterPair>()
    let metadataParameters = metadataMethodParameters(method)
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        let parameter = metadataParameterAt(metadataParameters, index)
        let name = interfaceParameterName(parameter, index)
        if (isWinrtArraySignature(signature)) {
            match (runtimeArrayElementSignature(signature)) {
                case Some(elementSignature) =>
                    let elementType = winrtProjectedTypeName(elementSignature, symbolsByName, ownerFullName)
                    if (isCallerAllocatedOutArrayParameter(parameter)) {
                        // Caller-allocated fill buffer (IVector.GetMany style):
                        // the caller owns the buffer and its capacity, the
                        // callee fills it and returns the written count. Mirror
                        // the interface renderer's caller-allocated ABI pair.
                        let elementAbiType = interfaceArrayElementAbiType(signature, symbolsByName, ownerFullName)
                        pairs.add(ParameterPair("${name}Size", "UInt32"))
                        if (elementAbiType == "CPointer<Unit>") {
                            pairs.add(ParameterPair(name, "CPointer<Unit>"))
                        } else {
                            pairs.add(ParameterPair(name, "CPointer<${elementAbiType}>"))
                        }
                    } else if (isOutParameter(parameter)) {
                        pairs.add(ParameterPair(name, "windows_core.OutSlot<Array<${elementType}>>"))
                    } else {
                        pairs.add(ParameterPair(name, "Array<${elementType}>"))
                    }
                case None =>
                    pairs.add(ParameterPair(name, "CPointer<Unit>"))
            }
        } else if (isOutParameter(parameter)) {
            let targetSignature = runtimeReferenceTargetSignature(signature)
            pairs.add(ParameterPair(
                name,
                "windows_core.OutSlot<${winrtProjectedTypeName(targetSignature, symbolsByName, ownerFullName)}>"
            ))
        } else if (isByReferenceSignature(signature)) {
            let targetSignature = runtimeReferenceTargetSignature(signature)
            pairs.add(ParameterPair(name, "CPointer<${interfaceSlotAbiType(targetSignature, symbolsByName, ownerFullName)}>"))
        } else {
            pairs.add(ParameterPair(
                name,
                winrtProjectedTypeName(signature, symbolsByName, ownerFullName)
            ))
        }
        index += 1
    }
    return pairs
}

func runtimeProjectedReturnTypeName(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    if (isWinrtArraySignature(signature)) {
        match (runtimeArrayElementSignature(signature)) {
            case Some(elementSignature) =>
                return "Array<${winrtProjectedTypeName(elementSignature, symbolsByName, ownerFullName)}>"
            case None => return "Array<CPointer<Unit>>"
        }
    }
    return winrtProjectedTypeName(signature, symbolsByName, ownerFullName)
}

func parameterPairListText(pairs: ArrayList<ParameterPair>): String {
    let rendered = ArrayList<String>()
    for (pair in pairs) {
        rendered.add("${pair.name}: ${pair.typeName}")
    }
    return joinStrings(rendered, ", ")
}

func argumentPairListText(pairs: ArrayList<ParameterPair>): String {
    let rendered = ArrayList<String>()
    for (pair in pairs) {
        rendered.add(pair.name)
    }
    return joinStrings(rendered, ", ")
}

func winrtClassInterfaceSpecs(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    defaultInterface: RuntimeClassInterfaceSpec
): ArrayList<RuntimeClassInterfaceSpec> {
    let values = ArrayList<RuntimeClassInterfaceSpec>()
    addRuntimeClassInterfaceSpecWithRequired(values, defaultInterface, symbolsByName)
    for (implementation in typeDef.interfaceImplementations) {
        match (runtimeClassInterfaceSpec(implementation, symbolsByName, ownerFullName)) {
            case Some(spec) =>
                addRuntimeClassInterfaceSpecWithRequired(values, spec, symbolsByName)
            case None => ()
        }
    }
    addRuntimeClassBaseInterfaceSpecs(values, typeDef, symbolsByName)
    return values
}

func addUniqueInterfaceSpec(values: ArrayList<RuntimeClassInterfaceSpec>, spec: RuntimeClassInterfaceSpec): Unit {
    let _ = tryAddUniqueInterfaceSpec(values, spec)
}

func tryAddUniqueInterfaceSpec(values: ArrayList<RuntimeClassInterfaceSpec>, spec: RuntimeClassInterfaceSpec): Bool {
    for (value in values) {
        if (value.typeName == spec.typeName) {
            return false
        }
    }
    values.add(spec)
    return true
}

func addRuntimeClassInterfaceSpecWithRequired(
    values: ArrayList<RuntimeClassInterfaceSpec>,
    spec: RuntimeClassInterfaceSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): Unit {
    if (!tryAddUniqueInterfaceSpec(values, spec)) {
        return
    }
    match (spec.symbol.typeDef) {
        case Some(typeDef) =>
            for (implementation in typeDef.interfaceImplementations) {
                match (runtimeClassInterfaceSpecWithSubstitutions(
                    implementation,
                    symbolsByName,
                    spec.fullName,
                    spec.substitutions
                )) {
                    case Some(requiredSpec) =>
                        addRuntimeClassInterfaceSpecWithRequired(values, requiredSpec, symbolsByName)
                    case None => ()
                }
            }
        case None => ()
    }
}

func addRuntimeClassBaseInterfaceSpecs(
    values: ArrayList<RuntimeClassInterfaceSpec>,
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Unit {
    if (!typeDef.hasBaseType || typeDef.baseType.isEmpty() || typeDef.baseType == "System.Object") {
        return
    }
    match (symbolsByName.get(typeDef.baseType)) {
        case Some(baseSymbol) =>
            match (baseSymbol.typeDef) {
                case Some(baseTypeDef) =>
                    match (defaultWinrtClassInterfaceSpec(baseTypeDef, symbolsByName, baseSymbol.fullName)) {
                        case Some(baseDefault) =>
                            addRuntimeClassInterfaceSpecWithRequired(values, baseDefault, symbolsByName)
                        case None => ()
                    }
                    for (implementation in baseTypeDef.interfaceImplementations) {
                        match (runtimeClassInterfaceSpec(implementation, symbolsByName, baseSymbol.fullName)) {
                            case Some(spec) =>
                                addRuntimeClassInterfaceSpecWithRequired(values, spec, symbolsByName)
                            case None => ()
                        }
                    }
                    addRuntimeClassBaseInterfaceSpecs(values, baseTypeDef, symbolsByName)
                case None => ()
            }
        case None => ()
    }
}

func runtimeClassAncestorIidExpressions(interfaceSpecs: ArrayList<RuntimeClassInterfaceSpec>): String {
    let values = ArrayList<String>()
    for (interfaceSpec in interfaceSpecs) {
        values.add("${interfaceSpec.typeName}.iid()")
    }
    values.add("windows_interface.IInspectable.iid()")
    values.add("windows_interface.IUnknown.iid()")
    joinStrings(values, ", ")
}

func renderRuntimeClassInterfaceAccessor(
    interfaceSpec: RuntimeClassInterfaceSpec,
    interfaceSpecs: ArrayList<RuntimeClassInterfaceSpec>,
    defaultInterface: RuntimeClassInterfaceSpec
): String {
    let accessorName = runtimeClassInterfaceAccessorName(interfaceSpec, interfaceSpecs)
    var content = "    public func as${accessorName}(): ${interfaceSpec.typeName} {\n"
    if (interfaceSpec.typeName == defaultInterface.typeName) {
        content += "        defaultInterface()\n"
    } else {
        content += "        match (unsafe { query<${interfaceSpec.typeName}>(${interfaceSpec.typeName}.descriptor()) }) {\n"
        content += "            case Some(value) => value\n"
        content += "            case None => throw windows_core.WindowsException(windows_core.E_NOINTERFACE)\n"
        content += "        }\n"
    }
    content += "    }\n\n"
    content
}

func runtimeClassInterfaceAccessorName(
    interfaceSpec: RuntimeClassInterfaceSpec,
    interfaceSpecs: ArrayList<RuntimeClassInterfaceSpec>
): String {
    var count: Int64 = 0
    for (candidate in interfaceSpecs) {
        if (candidate.accessorName == interfaceSpec.accessorName) {
            count += 1
        }
    }
    if (count <= 1) {
        return interfaceSpec.accessorName
    }
    return "${interfaceSpec.accessorName}_${mangleFullName(interfaceSpec.typeName)}"
}

func renderRuntimeClassDefaultInterfaceMembers(
    symbol: SymbolRecord,
    defaultInterface: RuntimeClassInterfaceSpec,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    match (defaultInterface.symbol.typeDef) {
        case Some(interfaceTypeDef) =>
            let slotNames = runtimeInterfaceSlotNamesByMethod(interfaceTypeDef)
            let accessorNames = ArrayList<String>()
            var content = ""
            for (property in interfaceTypeDef.properties) {
                content += renderRuntimeClassProperty(symbol, property, interfaceTypeDef, slotNames, accessorNames, symbolsByName)
            }
            for (event in interfaceTypeDef.events) {
                content += renderRuntimeClassEvent(symbol, event, interfaceTypeDef, slotNames, accessorNames, symbolsByName)
            }
            for (method in interfaceTypeDef.methods) {
                if (!containsExactString(accessorNames, method.name)) {
                    content += renderRuntimeClassInstanceMethod(symbol, method, runtimeInterfaceSlotName(slotNames, method), symbolsByName)
                }
            }
            // The default-interface members above are rendered against the
            // interface's own type definition, so any closed generic argument of
            // a parameterized default interface (e.g. IObservableVector<T> closed
            // as IObservableVector<UIElement>) is still emitted with the open
            // generic parameter name. The runtime class itself is not generic, so
            // those open parameters must be rewritten to the concrete reference
            // types the default interface closes over before they leak into member
            // bodies. The rewrite preserves the type-erased generic-handle ABI
            // dispatch (winrtBorrowGenericIn / fromAbiTakeWinrtHandle), which is
            // the correct shape for the WinRT generic interface vtable.
            return applyRuntimeClassGenericSubstitutions(content, defaultInterface.substitutions)
        case None => return ""
    }
}

// Rewrite whole-identifier occurrences of each generic-parameter name in
// `text` to its concrete substitution type. The scan is a single pass over the
// UTF-8 bytes that only replaces a token when its full identifier span matches a
// substitution name, so partial matches inside larger identifiers (e.g. the `T`
// in `Token` or `winrtBorrowGenericIn`) are left untouched. With no
// substitutions the input is returned unchanged.
func applyRuntimeClassGenericSubstitutions(
    text: String,
    substitutions: ArrayList<RuntimeClassGenericSubstitution>
): String {
    if (substitutions.isEmpty()) {
        return text
    }
    let bytes = text.toArray()
    let total = Int64(bytes.size)
    let builder = StringBuilder()
    var index: Int64 = 0
    while (index < total) {
        if (!isIdentifierByte(bytes[index])) {
            // Pass through a contiguous run of non-identifier bytes verbatim.
            // Identifier bytes are all ASCII, so any multi-byte UTF-8 sequence
            // (lead/continuation bytes are all >= 0x80) stays grouped in this run
            // and is reconstructed losslessly.
            var separatorEnd = index
            while (separatorEnd < total && !isIdentifierByte(bytes[separatorEnd])) {
                separatorEnd += 1
            }
            builder.append(String.fromUtf8(bytes[index..separatorEnd]))
            index = separatorEnd
            continue
        }
        // The preceding byte (if any) is a non-identifier byte here, so `index`
        // starts a whole identifier token; consume its full span.
        var end = index
        while (end < total && isIdentifierByte(bytes[end])) {
            end += 1
        }
        let token = String.fromUtf8(bytes[index..end])
        builder.append(runtimeClassGenericSubstitutionTypeName(token, substitutions) ?? token)
        index = end
    }
    return builder.toString()
}

func isIdentifierByte(byte: Byte): Bool {
    return isAsciiAlphaNumeric(byte) || byte == b'_'
}

func runtimeInterfaceSlotNamesByMethod(typeDef: TypeDefinitionRecord): HashMap<String, String> {
    let values = HashMap<String, String>()
    let seen = ArrayList<String>()
    for (method in typeDef.methods) {
        let slotName = uniqueInterfaceSlotName(method, seen)
        seen.add(slotName)
        let key = runtimeMethodSlotKey(method)
        if (!values.contains(key)) {
            values.add(key, slotName)
        }
    }
    return values
}

func runtimeInterfaceSlotName(slotNames: HashMap<String, String>, method: MethodRecord): String {
    match (slotNames.get(runtimeMethodSlotKey(method))) {
        case Some(name) => return name
        case None => return cjIdentifier(projectedMethodBaseName(method))
    }
}

func runtimeMethodSlotKey(method: MethodRecord): String {
    let parts = ArrayList<String>()
    parts.add(method.name)
    for (signature in method.signature.parameters) {
        parts.add(runtimeSignatureSlotKey(signature))
    }
    parts.add(runtimeSignatureSlotKey(method.signature.returnType))
    return joinStrings(parts, "|")
}

func runtimeSignatureSlotKey(signature: SignatureRecord): String {
    match (signature.typeSpecification) {
        case Some(typeSpec) => return "TypeSpecification(${runtimeSignatureSlotKey(typeSpec.signature)})"
        case None => ()
    }
    var content = "${signature.kind}:${signature.namespace}:${signature.name}"
    match (signature.typeSig) {
        case Some(nested) => content += "<${runtimeSignatureSlotKey(nested)}>"
        case None => ()
    }
    if (!signature.typeArguments.isEmpty()) {
        let arguments = ArrayList<String>()
        for (argument in signature.typeArguments) {
            arguments.add(runtimeSignatureSlotKey(argument))
        }
        content += "[${joinStrings(arguments, ",")}]"
    }
    return content
}

func renderRuntimeClassProperty(
    symbol: SymbolRecord,
    property: PropertyRecord,
    interfaceTypeDef: TypeDefinitionRecord,
    slotNames: HashMap<String, String>,
    accessorNames: ArrayList<String>,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    if (!property.signature.parameters.isEmpty()) {
        return ""
    }
    let getterName = runtimeAccessorMethodName(property.accessors, "Getter") ?? "get_${property.name}"
    match (runtimeMethodByName(interfaceTypeDef, getterName)) {
        case Some(getter) =>
            addUnique(accessorNames, getter.name)
            let setterName = runtimeAccessorMethodName(property.accessors, "Setter") ?? "put_${property.name}"
            let propertyName = cjIdentifier(property.name)
            let propertyType = runtimeProjectedReturnTypeName(property.signature.returnType, symbolsByName, symbol.fullName)
            var content = ""
            match (runtimeMethodByName(interfaceTypeDef, setterName)) {
                case Some(setter) =>
                    addUnique(accessorNames, setter.name)
                    let pairs = runtimeProjectedMethodParameterPairs(setter, symbolsByName, symbol.fullName)
                    let setterParameterName = runtimePropertySetterParameterName(pairs)
                    let getterPairs = runtimeProjectedMethodParameterPairs(getter, symbolsByName, symbol.fullName)
                    content += "    public mut prop ${propertyName}: ${propertyType} {\n"
                    content += "        get() {\n"
                    content += renderRuntimeClassProjectedMethodBody(
                        symbol,
                        getter,
                        runtimeInterfaceSlotName(slotNames, getter),
                        runtimeClassFactoryCallPlan(getter, getterPairs, symbolsByName, symbol.fullName),
                        symbolsByName,
                        3,
                        RuntimeDispatchKind.Instance,
                        None
                    )
                    content += "        }\n"
                    content += "        set(${setterParameterName}) {\n"
                    content += renderRuntimeClassProjectedMethodBody(
                        symbol,
                        setter,
                        runtimeInterfaceSlotName(slotNames, setter),
                        runtimeClassFactoryCallPlan(setter, pairs, symbolsByName, symbol.fullName),
                        symbolsByName,
                        3,
                        RuntimeDispatchKind.Instance,
                        None
                    )
                    content += "        }\n"
                    content += "    }\n\n"
                case None =>
                    let getterPairs = runtimeProjectedMethodParameterPairs(getter, symbolsByName, symbol.fullName)
                    content += "    public prop ${propertyName}: ${propertyType} {\n"
                    content += "        get() {\n"
                    content += renderRuntimeClassProjectedMethodBody(
                        symbol,
                        getter,
                        runtimeInterfaceSlotName(slotNames, getter),
                        runtimeClassFactoryCallPlan(getter, getterPairs, symbolsByName, symbol.fullName),
                        symbolsByName,
                        3,
                        RuntimeDispatchKind.Instance,
                        None
                    )
                    content += "        }\n"
                    content += "    }\n\n"
            }
            return content
        case None => return ""
    }
}

func runtimePropertySetterParameterName(pairs: ArrayList<ParameterPair>): String {
    if (!pairs.isEmpty()) {
        return pairs[0].name
    }
    return "value"
}

func renderRuntimeClassEvent(
    symbol: SymbolRecord,
    event: EventRecord,
    interfaceTypeDef: TypeDefinitionRecord,
    slotNames: HashMap<String, String>,
    accessorNames: ArrayList<String>,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    var content = ""
    let eventName = cjIdentifier(event.name)
    match (runtimeAccessorMethodName(event.accessors, "Adder")) {
        case Some(adderName) =>
            match (runtimeMethodByName(interfaceTypeDef, adderName)) {
                case Some(adder) =>
                    addUnique(accessorNames, adder.name)
                    content += renderRuntimeClassInstanceMethodWithName(
                        symbol,
                        adder,
                        "add${eventName}",
                        runtimeInterfaceSlotName(slotNames, adder),
                        symbolsByName
                    )
                case None => ()
            }
        case None => ()
    }
    match (runtimeAccessorMethodName(event.accessors, "Remover")) {
        case Some(removerName) =>
            match (runtimeMethodByName(interfaceTypeDef, removerName)) {
                case Some(remover) =>
                    addUnique(accessorNames, remover.name)
                    content += renderRuntimeClassInstanceMethodWithName(
                        symbol,
                        remover,
                        "remove${eventName}",
                        runtimeInterfaceSlotName(slotNames, remover),
                        symbolsByName
                    )
                case None => ()
            }
        case None => ()
    }
    return content
}

func renderRuntimeClassInstanceMethod(
    symbol: SymbolRecord,
    method: MethodRecord,
    slotName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    renderRuntimeClassInstanceMethodWithName(symbol, method, slotName, slotName, symbolsByName)
}

func renderRuntimeClassInstanceMethodWithName(
    symbol: SymbolRecord,
    method: MethodRecord,
    publicName: String,
    slotName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    if (runtimeFactoryRequiresRawAbiShape(method, symbolsByName, symbol.fullName)) {
        return renderRuntimeClassInstanceRawAbiMethod(symbol, method, publicName, slotName, symbolsByName)
    }
    let pairs = runtimeProjectedMethodParameterPairs(method, symbolsByName, symbol.fullName)
    let params = parameterPairListText(pairs)
    let returnType = runtimeProjectedReturnTypeName(method.signature.returnType, symbolsByName, symbol.fullName)
    let callPlan = runtimeClassFactoryCallPlan(method, pairs, symbolsByName, symbol.fullName)
    var content = "    public func ${publicName}(${params}): ${returnType} {\n"
    content += renderRuntimeClassProjectedMethodBody(
        symbol,
        method,
        slotName,
        callPlan,
        symbolsByName,
        2,
        RuntimeDispatchKind.Instance,
        None
    )
    content += "    }\n\n"
    return content
}

func renderRuntimeClassInstanceRawAbiMethod(
    symbol: SymbolRecord,
    method: MethodRecord,
    publicName: String,
    slotName: String,
    symbolsByName: HashMap<String, SymbolRecord>
): String {
    let pairs = interfaceMethodMacroParameterPairs(method, symbolsByName, symbol.fullName)
    let params = parameterPairListText(pairs)
    let args = argumentPairListText(pairs)
    var content = "    public func ${publicName}(${params}): Unit {\n"
    content += "        var hr__ = windows_core.E_POINTER\n"
    content += renderRuntimeClassRawAbiPreDispatchOutSlotClears(method, symbolsByName, symbol.fullName, 2)
    content += "        try (interface__ = defaultInterface()) {\n"
    if (args.isEmpty()) {
        content += "            hr__ = unsafe { interface__.${slotName}() }\n"
    } else {
    content += "            hr__ = unsafe { interface__.${slotName}(${args}) }\n"
    }
    content += "        }\n"
    content += renderRuntimeClassRawAbiFailureCleanup(method, symbolsByName, symbol.fullName, 2)
    content += "        hr__.check()\n"
    content += "    }\n\n"
    return content
}

func runtimeReturnArrayOutputSpec(
    method: MethodRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<RuntimeArrayOutputSpec> {
    if (!isWinrtArraySignature(method.signature.returnType)) {
        return None
    }
    match (runtimeArrayElementSignature(method.signature.returnType)) {
        case Some(elementSignature) =>
            return Some(RuntimeArrayOutputSpec(
                "",
                "__returnValue",
                "__returnData",
                "__returnSize",
                winrtProjectedTypeName(elementSignature, symbolsByName, ownerFullName),
                interfaceSlotAbiType(elementSignature, symbolsByName, ownerFullName),
                elementSignature
            ))
        case None => return None
    }
}

func renderRuntimeArrayOutputDeclarations(output: RuntimeArrayOutputSpec, indentLevel: Int64): String {
    var content = ""
    content += "${runtimeIndent(indentLevel)}var ${output.sizeName} = 0u32\n"
    content += "${runtimeIndent(indentLevel)}var ${output.dataName} = CPointer<${output.elementAbiType}>()\n"
    return content
}

func renderRuntimeOutSlotGuards(callPlan: RuntimeCallPlan, indentLevel: Int64): String {
    var content = ""
    let hasMultipleOutSlots = callPlan.scalarOutputs.size > 1 ||
        callPlan.arrayOutputs.size > 1 ||
        (!callPlan.scalarOutputs.isEmpty() && !callPlan.arrayOutputs.isEmpty())
    if (hasMultipleOutSlots) {
        content += "${runtimeIndent(indentLevel)}var nullOutSlot__ = false\n"
        for (output in callPlan.scalarOutputs) {
            content += "${runtimeIndent(indentLevel)}if (${output.name}.isNull()) {\n"
            content += "${runtimeIndent(indentLevel + 1)}nullOutSlot__ = true\n"
            content += "${runtimeIndent(indentLevel)}} else {\n"
            content += "${runtimeIndent(indentLevel + 1)}${output.name}.clear()\n"
            content += "${runtimeIndent(indentLevel)}}\n"
        }
        for (output in callPlan.arrayOutputs) {
            content += "${runtimeIndent(indentLevel)}if (${output.targetName}.isNull()) {\n"
            content += "${runtimeIndent(indentLevel + 1)}nullOutSlot__ = true\n"
            content += "${runtimeIndent(indentLevel)}} else {\n"
            content += "${runtimeIndent(indentLevel + 1)}${output.targetName}.clear()\n"
            content += "${runtimeIndent(indentLevel)}}\n"
        }
        content += "${runtimeIndent(indentLevel)}if (nullOutSlot__) {\n"
        content += "${runtimeIndent(indentLevel + 1)}throw windows_core.WindowsException(windows_core.E_POINTER)\n"
        content += "${runtimeIndent(indentLevel)}}\n"
    } else {
        for (output in callPlan.scalarOutputs) {
            content += "${runtimeIndent(indentLevel)}if (${output.name}.isNull()) {\n"
            content += "${runtimeIndent(indentLevel + 1)}throw windows_core.WindowsException(windows_core.E_POINTER)\n"
            content += "${runtimeIndent(indentLevel)}}\n"
            content += "${runtimeIndent(indentLevel)}${output.name}.clear()\n"
        }
        for (output in callPlan.arrayOutputs) {
            content += "${runtimeIndent(indentLevel)}if (${output.targetName}.isNull()) {\n"
            content += "${runtimeIndent(indentLevel + 1)}throw windows_core.WindowsException(windows_core.E_POINTER)\n"
            content += "${runtimeIndent(indentLevel)}}\n"
            content += "${runtimeIndent(indentLevel)}${output.targetName}.clear()\n"
        }
    }
    return content
}

func renderRuntimeScalarOutputPublish(
    output: RuntimeScalarOutputSpec,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    indentLevel: Int64
): String {
    var content = ""
    content += "${runtimeIndent(indentLevel)}let ${output.valueName} = match (${output.name}.takeAbi<${output.abiType}>()) {\n"
    content += "${runtimeIndent(indentLevel + 1)}case Some(value) => value\n"
    content += "${runtimeIndent(indentLevel + 1)}case None => throw windows_core.WindowsException(windows_core.E_POINTER)\n"
    content += "${runtimeIndent(indentLevel)}}\n"
    content += "${runtimeIndent(indentLevel)}${output.name}.write(${runtimeProjectedReturnExpression(output.projectedType, output.abiType, output.valueName, output.signature, symbolsByName, ownerFullName)})\n"
    return content
}

func renderRuntimeScalarOutputFailureCleanup(
    output: RuntimeScalarOutputSpec,
    indentLevel: Int64
): String {
    var cleanupType: Option<String> = None
    if (runtimeArrayElementUsesHandleBorrow(output.projectedType, output.abiType)) {
        cleanupType = Some(output.projectedType)
    } else if (output.abiType == "CPointer<Unit>") {
        cleanupType = runtimeRawPointerReturnCleanupType(output.signature)
    }
    match (cleanupType) {
        case None => return ""
        case Some(projectedCleanupType) =>
            let rawName = "${output.valueName}Partial"
            var content = ""
            content += "${runtimeIndent(indentLevel)}if (hr__.failed()) {\n"
            content += "${runtimeIndent(indentLevel + 1)}match (${output.name}.takeAbi<${output.abiType}>()) {\n"
            content += "${runtimeIndent(indentLevel + 2)}case Some(${rawName}) =>\n"
            content += "${runtimeIndent(indentLevel + 3)}if (${rawName}.isNotNull()) {\n"
            content += "${runtimeIndent(indentLevel + 4)}windows_core.winrtReleaseGenericOut<${projectedCleanupType}>(${rawName})\n"
            content += "${runtimeIndent(indentLevel + 3)}}\n"
            content += "${runtimeIndent(indentLevel + 2)}case None => ()\n"
            content += "${runtimeIndent(indentLevel + 1)}}\n"
            content += "${runtimeIndent(indentLevel)}}\n"
            return content
    }
}

func renderRuntimeArrayOutputFailureCleanup(
    output: RuntimeArrayOutputSpec,
    indentLevel: Int64
): String {
    var content = ""
    if (runtimeArrayElementUsesHandleBorrow(output.elementProjectedType, output.elementAbiType)) {
        content += "${runtimeIndent(indentLevel)}if (hr__.failed() && ${output.dataName}.isNotNull()) {\n"
        content += "${runtimeIndent(indentLevel + 1)}windows_core.winrtReleaseGenericArrayOut<${output.elementProjectedType}>(CPointer<Unit>(${output.dataName}), ${output.sizeName})\n"
        content += "${runtimeIndent(indentLevel + 1)}${output.dataName} = CPointer<${output.elementAbiType}>()\n"
        content += "${runtimeIndent(indentLevel + 1)}${output.sizeName} = 0u32\n"
        content += "${runtimeIndent(indentLevel)}}\n"
        return content
    }
    content += "${runtimeIndent(indentLevel)}if (hr__.failed() && ${output.dataName}.isNotNull()) {\n"
    content += "${runtimeIndent(indentLevel + 1)}windows_core.coTaskMemFree(CPointer<Unit>(${output.dataName}))\n"
    content += "${runtimeIndent(indentLevel + 1)}${output.dataName} = CPointer<${output.elementAbiType}>()\n"
    content += "${runtimeIndent(indentLevel + 1)}${output.sizeName} = 0u32\n"
    content += "${runtimeIndent(indentLevel)}}\n"
    return content
}

func renderRuntimeArrayOutputPublish(
    output: RuntimeArrayOutputSpec,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    indentLevel: Int64
): String {
    var content = renderRuntimeArrayTakeValue(output, symbolsByName, ownerFullName, indentLevel, false)
    content += "${runtimeIndent(indentLevel)}${output.targetName}.write(${output.valueName})\n"
    return content
}

func renderRuntimeArrayTakeValue(
    output: RuntimeArrayOutputSpec,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    indentLevel: Int64,
    asReturn: Bool
): String {
    if (runtimeArrayElementUsesHandleBorrow(output.elementProjectedType, output.elementAbiType)) {
        let expression = "windows_core.winrtTakeGenericArrayOut<${output.elementProjectedType}>(CPointer<Unit>(${output.dataName}), ${output.sizeName})"
        if (asReturn) {
            return "${runtimeIndent(indentLevel)}return ${expression}\n"
        }
        return "${runtimeIndent(indentLevel)}let ${output.valueName} = ${expression}\n"
    }

    let projectedName = "${output.valueName}Projected"
    let ownedName = "${output.valueName}Owned"
    let abiArrayName = "${output.valueName}AbiArray"
    let abiValuesName = "${output.valueName}AbiValues"
    let projection = runtimeProjectedReturnExpression(
        output.elementProjectedType,
        output.elementAbiType,
        "${abiValuesName}[index]",
        output.elementSignature,
        symbolsByName,
        ownerFullName
    )
    // Emit straight-line statements rather than an immediately-invoked closure.
    // The data/size locals have their addresses taken earlier via `inout`, and
    // capturing them inside a nested closure mixes managed and raw address
    // spaces in a way the backend rejects; in-scope statements avoid that.
    var content = ""
    content += "${runtimeIndent(indentLevel)}if (${output.sizeName} > 0u32 && ${output.dataName}.isNull()) {\n"
    content += "${runtimeIndent(indentLevel + 1)}throw windows_core.WindowsException(windows_core.E_POINTER)\n"
    content += "${runtimeIndent(indentLevel)}}\n"
    content += "${runtimeIndent(indentLevel)}var ${projectedName} = Array<${output.elementProjectedType}>()\n"
    content += "${runtimeIndent(indentLevel)}var ${ownedName}: Option<windows_core.AbiArray<${output.elementAbiType}>> = None\n"
    content += "${runtimeIndent(indentLevel)}try {\n"
    content += "${runtimeIndent(indentLevel + 1)}let ${abiArrayName} = unsafe { windows_core.AbiArray<${output.elementAbiType}>.fromRawParts(${output.dataName}, ${output.sizeName}) }\n"
    content += "${runtimeIndent(indentLevel + 1)}${ownedName} = Some(${abiArrayName})\n"
    content += "${runtimeIndent(indentLevel + 1)}let ${abiValuesName} = ${abiArrayName}.toArray()\n"
    content += "${runtimeIndent(indentLevel + 1)}${projectedName} = Array<${output.elementProjectedType}>(${abiValuesName}.size, { index => ${projection} })\n"
    content += "${runtimeIndent(indentLevel)}} finally {\n"
    content += "${runtimeIndent(indentLevel + 1)}match (${ownedName}) {\n"
    content += "${runtimeIndent(indentLevel + 2)}case Some(array) => array.close()\n"
    content += "${runtimeIndent(indentLevel + 2)}case None => windows_core.coTaskMemFree(CPointer<Unit>(${output.dataName}))\n"
    content += "${runtimeIndent(indentLevel + 1)}}\n"
    content += "${runtimeIndent(indentLevel)}}\n"
    if (asReturn) {
        content += "${runtimeIndent(indentLevel)}return ${projectedName}\n"
    } else {
        content += "${runtimeIndent(indentLevel)}let ${output.valueName} = ${projectedName}\n"
    }
    return content
}

// The items buffer of a caller-allocated out array as a CPointer<Unit>, which
// is what the type-erased generic range helpers accept. When the projected
// parameter is already CPointer<Unit> (generic-erased element) it is passed
// through unchanged; a concrete element pointer is reinterpreted.
func runtimeCallerAllocatedItemsExpression(spec: RuntimeCallerAllocatedArraySpec): String {
    if (spec.elementAbiType == "CPointer<Unit>") {
        return spec.itemsName
    }
    return "CPointer<Unit>(${spec.itemsName})"
}

func renderRuntimeClassProjectedMethodBody(
    symbol: SymbolRecord,
    method: MethodRecord,
    slotName: String,
    callPlan: RuntimeCallPlan,
    symbolsByName: HashMap<String, SymbolRecord>,
    indentLevel: Int64,
    dispatchKind: RuntimeDispatchKind,
    factorySpec: Option<RuntimeClassInterfaceSpec>
): String {
    let returnType = runtimeProjectedReturnTypeName(method.signature.returnType, symbolsByName, symbol.fullName)
    let returnAbiType = interfaceSlotAbiType(method.signature.returnType, symbolsByName, symbol.fullName)
    // A non-array return whose element is an open generic parameter of the
    // parameterized default interface (e.g. IVector<T>.GetAt -> T). The vtable
    // slot is type-erased to CPointer<Unit>, so the value is bridged through the
    // element's output bridge instead of assuming a reference-handle shape.
    let hasArrayReturn = isWinrtArraySignature(method.signature.returnType)
    let isGenericReturn = !hasArrayReturn &&
        isRuntimeGenericParameterSignature(runtimeReferenceTargetSignature(method.signature.returnType))
    let extraArgs = ArrayList<String>()
    var content = ""
    match (runtimeReturnArrayOutputSpec(method, symbolsByName, symbol.fullName)) {
        case Some(arrayReturn) =>
            content += renderRuntimeArrayOutputDeclarations(arrayReturn, indentLevel)
            extraArgs.add("CPointer<UInt32>(inout ${arrayReturn.sizeName})")
            extraArgs.add("CPointer<CPointer<${arrayReturn.elementAbiType}>>(inout ${arrayReturn.dataName})")
        case None =>
            if (returnType != "Unit") {
                content += "${runtimeIndent(indentLevel)}var result__ = ${cjDefaultValue(returnAbiType)}\n"
                extraArgs.add("CPointer<${returnAbiType}>(inout result__)")
            }
    }
    for (output in callPlan.arrayOutputs) {
        content += renderRuntimeArrayOutputDeclarations(output, indentLevel)
    }
    content += "${runtimeIndent(indentLevel)}var hr__ = windows_core.E_POINTER\n"
    content += renderRuntimeOutSlotGuards(callPlan, indentLevel)
    for (callerArray in callPlan.callerAllocatedArrays) {
        // Zero the caller-allocated buffer so handle elements have a known state
        // for the failure-release pass (value elements dispatch to a no-op).
        content += "${runtimeIndent(indentLevel)}windows_core.winrtPrepareGenericOutRange<${callerArray.elementProjectedType}>(${runtimeCallerAllocatedItemsExpression(callerArray)}, ${callerArray.sizeName})\n"
    }
    match (dispatchKind) {
        case RuntimeDispatchKind.Factory =>
            match (factorySpec) {
                case Some(spec) =>
                    content += renderRuntimeClassFactoryAbiCallWithArgs(
                        symbol,
                        spec,
                        slotName,
                        callPlan,
                        extraArgs,
                        symbolsByName,
                        symbol.fullName
                    )
                case None =>
                    content += "${runtimeIndent(indentLevel)}throw IllegalStateException(\"Runtime factory dispatch is missing factory metadata\")\n"
            }
        case RuntimeDispatchKind.Instance =>
            content += renderRuntimeClassInstanceAbiCallWithArgs(
                slotName,
                callPlan,
                extraArgs,
                indentLevel,
                symbolsByName,
                symbol.fullName
            )
    }
    if (isGenericReturn) {
        // The slot holds a type-erased generic OUT value; release any owned
        // resource (handle/string element) through the bridge and clear it.
        // Value elements own nothing, so this dispatches to a no-op for them.
        content += "${runtimeIndent(indentLevel)}if (hr__.failed()) {\n"
        content += "${runtimeIndent(indentLevel + 1)}windows_core.winrtReleaseFailedGenericOut<${returnType}>(CPointer<CPointer<Unit>>(inout result__))\n"
        content += "${runtimeIndent(indentLevel)}}\n"
    } else if (!hasArrayReturn && returnType != "Unit" && runtimeArrayElementUsesHandleBorrow(returnType, returnAbiType)) {
        content += "${runtimeIndent(indentLevel)}if (hr__.failed() && result__.isNotNull()) {\n"
        content += "${runtimeIndent(indentLevel + 1)}windows_core.winrtReleaseGenericOut<${returnType}>(result__)\n"
        content += "${runtimeIndent(indentLevel + 1)}result__ = CPointer<Unit>()\n"
        content += "${runtimeIndent(indentLevel)}}\n"
    }
    if (!hasArrayReturn && !isGenericReturn && returnType == "CPointer<Unit>" && returnAbiType == "CPointer<Unit>") {
        match (runtimeRawPointerReturnCleanupType(method.signature.returnType)) {
            case Some(cleanupType) =>
                content += "${runtimeIndent(indentLevel)}if (hr__.failed() && result__.isNotNull()) {\n"
                content += "${runtimeIndent(indentLevel + 1)}windows_core.winrtReleaseGenericOut<${cleanupType}>(result__)\n"
                content += "${runtimeIndent(indentLevel + 1)}result__ = CPointer<Unit>()\n"
                content += "${runtimeIndent(indentLevel)}}\n"
            case None => ()
        }
    }
    for (output in callPlan.scalarOutputs) {
        content += renderRuntimeScalarOutputFailureCleanup(output, indentLevel)
    }
    match (runtimeReturnArrayOutputSpec(method, symbolsByName, symbol.fullName)) {
        case Some(arrayReturn) =>
            content += renderRuntimeArrayOutputFailureCleanup(arrayReturn, indentLevel)
        case None => ()
    }
    for (output in callPlan.arrayOutputs) {
        content += renderRuntimeArrayOutputFailureCleanup(output, indentLevel)
    }
    for (callerArray in callPlan.callerAllocatedArrays) {
        // On failure, release any element handles the callee wrote into the
        // caller-allocated buffer before failing (no-op for value elements).
        content += "${runtimeIndent(indentLevel)}if (hr__.failed()) {\n"
        content += "${runtimeIndent(indentLevel + 1)}windows_core.winrtReleaseGenericOutRange<${callerArray.elementProjectedType}>(${runtimeCallerAllocatedItemsExpression(callerArray)}, ${callerArray.sizeName})\n"
        content += "${runtimeIndent(indentLevel)}}\n"
    }
    content += "${runtimeIndent(indentLevel)}hr__.check()\n"
    for (output in callPlan.scalarOutputs) {
        content += renderRuntimeScalarOutputPublish(output, symbolsByName, symbol.fullName, indentLevel)
    }
    for (output in callPlan.arrayOutputs) {
        content += renderRuntimeArrayOutputPublish(output, symbolsByName, symbol.fullName, indentLevel)
    }
    match (runtimeReturnArrayOutputSpec(method, symbolsByName, symbol.fullName)) {
        case Some(arrayReturn) =>
            content += renderRuntimeArrayTakeValue(arrayReturn, symbolsByName, symbol.fullName, indentLevel, true)
        case None =>
            if (isGenericReturn) {
                // Bridge the type-erased generic OUT slot to the concrete
                // projected element. winrtTakeGenericOut<T> dispatches via the
                // element output bridge; the projected `T` is finalized to the
                // concrete element type by applyRuntimeClassGenericSubstitutions.
                content += "${runtimeIndent(indentLevel)}return windows_core.winrtTakeGenericOut<${returnType}>(CPointer<CPointer<Unit>>(inout result__))\n"
            } else if (returnType != "Unit") {
                content += "${runtimeIndent(indentLevel)}return ${runtimeProjectedReturnExpression(returnType, returnAbiType, "result__", method.signature.returnType, symbolsByName, symbol.fullName)}\n"
            }
    }
    return content
}

func renderRuntimeClassInstanceAbiCall(
    slotName: String,
    callPlan: RuntimeCallPlan,
    outputArg: String,
    indentLevel: Int64
): String {
    let outputArgs = ArrayList<String>()
    if (!outputArg.isEmpty()) {
        outputArgs.add(outputArg)
    }
    return renderRuntimeClassInstanceAbiCallWithArgs(
        slotName,
        callPlan,
        outputArgs,
        indentLevel,
        HashMap<String, SymbolRecord>(),
        ""
    )
}

func renderRuntimeClassInstanceAbiCallWithArgs(
    slotName: String,
    callPlan: RuntimeCallPlan,
    outputArgs: ArrayList<String>,
    indentLevel: Int64,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    let callArgs = ArrayList<String>()
    for (arg in callPlan.args) {
        callArgs.add(arg)
    }
    for (arg in outputArgs) {
        callArgs.add(arg)
    }
    var content = ""
    var index: Int64 = 0
    while (index < Int64(callPlan.borrows.size)) {
        let borrow = callPlan.borrows[index]
        content += "${runtimeIndent(indentLevel + index)}try (${borrow.name} = windows_core.winrtBorrowGenericIn<${borrow.typeName}>(${borrow.sourceName})) {\n"
        index += 1
    }
    var callIndentLevel = indentLevel + Int64(callPlan.borrows.size)
    var arrayIndex: Int64 = 0
    while (arrayIndex < Int64(callPlan.arrayInputs.size)) {
        let spec = callPlan.arrayInputs[arrayIndex]
        content += renderRuntimeArrayInputOpen(spec, callIndentLevel, symbolsByName, ownerFullName)
        callIndentLevel += runtimeArrayInputNesting(spec)
        arrayIndex += 1
    }
    let interfaceIndentLevel = callIndentLevel
    content += "${runtimeIndent(interfaceIndentLevel)}try (interface__ = defaultInterface()) {\n"
    if (callArgs.isEmpty()) {
        content += "${runtimeIndent(interfaceIndentLevel + 1)}hr__ = unsafe { interface__.${slotName}() }\n"
    } else {
        content += "${runtimeIndent(interfaceIndentLevel + 1)}hr__ = unsafe { interface__.${slotName}(${joinStrings(callArgs, ", ")}) }\n"
    }
    content += "${runtimeIndent(interfaceIndentLevel)}}\n"
    var closeArrayIndex = Int64(callPlan.arrayInputs.size) - 1
    while (closeArrayIndex >= 0) {
        let spec = callPlan.arrayInputs[closeArrayIndex]
        callIndentLevel -= runtimeArrayInputNesting(spec)
        content += renderRuntimeArrayInputClose(spec, callIndentLevel)
        closeArrayIndex -= 1
    }
    var closeIndex = Int64(callPlan.borrows.size) - 1
    while (closeIndex >= 0) {
        content += "${runtimeIndent(indentLevel + closeIndex)}}\n"
        closeIndex -= 1
    }
    return content
}

func runtimeAccessorMethodName(accessors: HashMap<String, JsonValue>, key: String): Option<String> {
    match (accessors.get(key)) {
        case Some(value) =>
            match (value.kind()) {
                case JsonKind.JsString => return Some(value.asString().getValue())
                case _ => ()
            }
        case None => ()
    }
    return None
}

func runtimeMethodByName(typeDef: TypeDefinitionRecord, name: String): Option<MethodRecord> {
    for (method in typeDef.methods) {
        if (method.name == name) {
            return Some(method)
        }
    }
    return None
}

func defaultWinrtClassInterfaceSpec(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<RuntimeClassInterfaceSpec> {
    for (implementation in typeDef.interfaceImplementations) {
        if (hasCustomAttribute(implementation.customAttributes, "DefaultAttribute")) {
            match (runtimeClassInterfaceSpec(implementation, symbolsByName, ownerFullName)) {
                case Some(spec) => return Some(spec)
                case None => ()
            }
        }
    }
    return None
}

func runtimeClassInterfaceSpec(
    implementation: InterfaceImplementationRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<RuntimeClassInterfaceSpec> {
    return runtimeClassInterfaceSpecWithSubstitutions(
        implementation,
        symbolsByName,
        ownerFullName,
        ArrayList<RuntimeClassGenericSubstitution>()
    )
}

func runtimeClassInterfaceSpecWithSubstitutions(
    implementation: InterfaceImplementationRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    substitutions: ArrayList<RuntimeClassGenericSubstitution>
): Option<RuntimeClassInterfaceSpec> {
    match (implementation.interfaceSignature) {
        case Some(signature) =>
            match (interfaceImplementationFullName(implementation, symbolsByName, ownerFullName)) {
                case Some(fullName) =>
                    match (symbolsByName.get(fullName)) {
                        case Some(symbol) =>
                            return Some(RuntimeClassInterfaceSpec(
                                symbol,
                                closedWinrtTypeNameWithSubstitutions(
                                    signature,
                                    symbol,
                                    symbolsByName,
                                    ownerFullName,
                                    substitutions
                                ),
                                substitutions: runtimeClassGenericSubstitutions(
                                    symbol,
                                    signature,
                                    symbolsByName,
                                    ownerFullName,
                                    substitutions
                                )
                            ))
                        case None => ()
                    }
                case None => ()
            }
        case None => ()
    }
    match (interfaceImplementationFullName(implementation, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            match (symbolsByName.get(fullName)) {
                case Some(symbol) => return Some(RuntimeClassInterfaceSpec(symbol, symbol.implName))
                case None => ()
            }
        case None => ()
    }
    return None
}

func runtimeClassGenericSubstitutions(
    symbol: SymbolRecord,
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    substitutions: ArrayList<RuntimeClassGenericSubstitution>
): ArrayList<RuntimeClassGenericSubstitution> {
    let values = ArrayList<RuntimeClassGenericSubstitution>()
    match (symbol.typeDef) {
        case Some(typeDef) =>
            let names = genericParameterNames(typeDef)
            let arguments = signatureTypeArguments(signature)
            var index: Int64 = 0
            while (index < Int64(names.size) && index < Int64(arguments.size)) {
                let argument = arguments[index]
                var typeName = "windows_interface.IInspectable"
                if (winrtGenericArgumentSatisfiesRuntimeConstraint(argument, symbolsByName, ownerFullName, substitutions)) {
                    typeName = winrtProjectedTypeNameWithSubstitutions(
                        argument,
                        symbolsByName,
                        ownerFullName,
                        substitutions
                    )
                }
                values.add(RuntimeClassGenericSubstitution(
                    names[index],
                    typeName
                ))
                index += 1
            }
        case None => ()
    }
    return values
}

func runtimeClassGenericSubstitutionTypeName(
    name: String,
    substitutions: ArrayList<RuntimeClassGenericSubstitution>
): Option<String> {
    for (substitution in substitutions) {
        if (substitution.name == name) {
            return Some(substitution.typeName)
        }
    }
    return None
}

func closedWinrtTypeName(
    signature: SignatureRecord,
    symbol: SymbolRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    return closedWinrtTypeNameWithSubstitutions(
        signature,
        symbol,
        symbolsByName,
        ownerFullName,
        ArrayList<RuntimeClassGenericSubstitution>()
    )
}

func closedWinrtTypeNameWithSubstitutions(
    signature: SignatureRecord,
    symbol: SymbolRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    substitutions: ArrayList<RuntimeClassGenericSubstitution>
): String {
    let typeArguments = signatureTypeArguments(signature)
    if (typeArguments.isEmpty()) {
        return symbol.implName
    }
    let rendered = ArrayList<String>()
    for (argument in typeArguments) {
        if (!winrtGenericArgumentSatisfiesRuntimeConstraint(argument, symbolsByName, ownerFullName, substitutions)) {
            return "windows_interface.IInspectable"
        }
        rendered.add(winrtProjectedTypeNameWithSubstitutions(argument, symbolsByName, ownerFullName, substitutions))
    }
    "${symbol.implName}<${joinStrings(rendered, ", ")}>"
}

func winrtGenericArgumentSatisfiesRuntimeConstraint(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    substitutions: ArrayList<RuntimeClassGenericSubstitution>
): Bool {
    match (signature.typeSpecification) {
        case Some(typeSpec) =>
            return winrtGenericArgumentSatisfiesRuntimeConstraint(typeSpec.signature, symbolsByName, ownerFullName, substitutions)
        case None => ()
    }
    if (signature.kind == "Primitive") {
        return true
    }
    if (signature.kind == "GenericParameter") {
        let name = cjIdentifier(signature.name)
        match (runtimeClassGenericSubstitutionTypeName(name, substitutions)) {
            case Some(typeName) => return typeName != "windows_interface.IInspectable"
            case None => return true
        }
    }
    if (signature.kind == "Void" || signature.kind == "Unit") {
        return false
    }
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            if (fullName == "System.String" || fullName == "System.Guid" || fullName == "System.Object") {
                return true
            }
            if (startsWith(fullName, "System.")) {
                return true
            }
            match (symbolsByName.get(fullName)) {
                case Some(symbol) =>
                    match (symbol.typeDef) {
                        case Some(typeDef) =>
                            // Value structs and WinRT enums (projected as value
                            // structs) do not implement the WinrtGenericType /
                            // RuntimeType projection a closed generic argument
                            // requires, so they fall back to IInspectable.
                            return !isValueType(typeDef) && !isEnumType(typeDef)
                        case None => return true
                    }
                case None => return true
            }
        case None => ()
    }
    match (signature.typeSig) {
        case Some(nested) =>
            return winrtGenericArgumentSatisfiesRuntimeConstraint(nested, symbolsByName, ownerFullName, substitutions)
        case None => return false
    }
}

func signatureTypeArguments(signature: SignatureRecord): ArrayList<SignatureRecord> {
    match (signature.typeSpecification) {
        case Some(typeSpec) => return signatureTypeArguments(typeSpec.signature)
        case None => ()
    }
    if (!signature.typeArguments.isEmpty()) {
        return signature.typeArguments
    }
    match (signature.typeSig) {
        case Some(nested) => return signatureTypeArguments(nested)
        case None => return ArrayList<SignatureRecord>()
    }
}

func winrtProjectedTypeName(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    return winrtProjectedTypeNameWithSubstitutions(
        signature,
        symbolsByName,
        ownerFullName,
        ArrayList<RuntimeClassGenericSubstitution>()
    )
}

func winrtProjectedTypeNameWithSubstitutions(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String,
    substitutions: ArrayList<RuntimeClassGenericSubstitution>
): String {
    match (signature.typeSpecification) {
        case Some(typeSpec) =>
            return winrtProjectedTypeNameWithSubstitutions(typeSpec.signature, symbolsByName, ownerFullName, substitutions)
        case None => ()
    }
    if (signature.kind == "Primitive") {
        if (signature.name == "String") {
            return "windows_core.HString"
        }
        if (signature.name == "Object") {
            return "windows_interface.IInspectable"
        }
        return primitiveCjType(signature.name)
    }
    if (signature.kind == "GenericParameter") {
        let name = cjIdentifier(signature.name)
        match (runtimeClassGenericSubstitutionTypeName(name, substitutions)) {
            case Some(typeName) => return typeName
            case None => ()
        }
        if (!name.isEmpty() && name != "_") {
            return name
        }
    }
    if (signature.kind == "Void" || signature.kind == "Unit") {
        return "Unit"
    }
    match (stringHandleRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) =>
            if (fullName == "System.String") {
                return "windows_core.HString"
            }
            if (fullName == "System.Guid") {
                return "windows_core.GuidValue"
            }
            if (fullName == "System.Object") {
                return "windows_interface.IInspectable"
            }
            if (startsWith(fullName, "System.")) {
                return systemType(fullName)
            }
            match (symbolsByName.get(fullName)) {
                case Some(symbol) =>
                    return closedWinrtTypeNameWithSubstitutions(
                        signature,
                        symbol,
                        symbolsByName,
                        ownerFullName,
                        substitutions
                    )
                case None => return qualifyMangledFullName(fullName)
            }
        case None => ()
    }
    match (signature.typeSig) {
        case Some(nested) => return winrtProjectedTypeNameWithSubstitutions(nested, symbolsByName, ownerFullName, substitutions)
        case None => ()
    }
    return "CPointer<Unit>"
}

func interfaceImplementationFullName(
    implementation: InterfaceImplementationRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (implementation.interfaceSignature) {
        case Some(signature) =>
            match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
                case Some(fullName) => return Some(fullName)
                case None => ()
            }
        case None => ()
    }
    match (implementation.typeDefinition) {
        case Some(metadataType) => return Some(metadataType.fullName())
        case None => ()
    }
    match (implementation.typeReference) {
        case Some(metadataType) => return Some(metadataType.fullName())
        case None => ()
    }
    match (implementation.typeSpecification) {
        case Some(typeSpecification) =>
            match (signatureFullNameInContext(typeSpecification.signature, symbolsByName, ownerFullName)) {
                case Some(fullName) => return Some(fullName)
                case None => ()
            }
        case None => ()
    }
    return None
}

func hasCustomAttribute(attributes: ArrayList<CustomAttributeRecord>, shortName: String): Bool {
    for (attribute in attributes) {
        if (attribute.typeName == shortName || endsWith(attribute.typeName, ".${shortName}")) {
            return true
        }
    }
    return false
}

func hasDefaultActivatableConstructor(typeDef: TypeDefinitionRecord): Bool {
    for (attribute in typeDef.customAttributes) {
        if ((attribute.typeName == "ActivatableAttribute" || endsWith(attribute.typeName, ".ActivatableAttribute")) &&
            !customAttributeHasTypeNameArgument(attribute)) {
            return true
        }
    }
    return false
}

func customAttributeHasTypeNameArgument(attribute: CustomAttributeRecord): Bool {
    for (argument in attribute.fixedArguments) {
        if (isSystemTypeSignature(argument.typeSig)) {
            return true
        }
    }
    return false
}

func customAttributeTypeNameArgumentFullNames(attribute: CustomAttributeRecord): ArrayList<String> {
    let values = ArrayList<String>()
    for (argument in attribute.fixedArguments) {
        if (isSystemTypeSignature(argument.typeSig)) {
            match (fixedArgumentTypeFullName(argument)) {
                case Some(fullName) => values.add(fullName)
                case None => ()
            }
        }
    }
    return values
}

func fixedArgumentTypeFullName(argument: CustomAttributeFixedArgumentRecord): Option<String> {
    match (literalValue(argument.value)) {
        case Some(value) => return jsonTypeFullName(value)
        case None => return None
    }
}

func jsonTypeFullName(value: JsonValue): Option<String> {
    match (value.kind()) {
        case JsonKind.JsString => return Some(value.asString().getValue())
        case JsonKind.JsObject =>
            let obj = value.asObject()
            match (jsonObjectStringMember(obj, "FullName")) {
                case Some(fullName) => return Some(fullName)
                case None => ()
            }
            let namespaceName = jsonObjectStringMember(obj, "Namespace") ?? ""
            let shortName = jsonObjectStringMember(obj, "Name") ?? ""
            if (!shortName.isEmpty()) {
                if (namespaceName.isEmpty()) {
                    return Some(shortName)
                }
                return Some("${namespaceName}.${shortName}")
            }
        case _ => ()
    }
    return None
}

func jsonObjectStringMember(obj: JsonObject, name: String): Option<String> {
    match (obj.get(name)) {
        case Some(value) =>
            match (value.kind()) {
                case JsonKind.JsString => return Some(value.asString().getValue())
                case _ => ()
            }
        case None => ()
    }
    return None
}

func isSystemTypeSignature(signature: SignatureRecord): Bool {
    if (signature.kind == "Type" && signature.namespace == "System" && signature.name == "Type") {
        return true
    }
    match (signatureFullNameInContext(signature, HashMap<String, SymbolRecord>(), "")) {
        case Some(fullName) => return fullName == "System.Type"
        case None => return false
    }
}

func isPublicInstanceField(field: FieldRecord): Bool {
    return contains(field.attributes, "Public") &&
        !contains(field.attributes, "Static") &&
        !contains(field.attributes, "Literal")
}

func hasPublicInstanceFields(typeDef: TypeDefinitionRecord): Bool {
    for (field in typeDef.fields) {
        if (isPublicInstanceField(field) && field.name != "value__") {
            return true
        }
    }
    return false
}

func isLiteralField(field: FieldRecord): Bool {
    return contains(field.attributes, "Public") &&
        contains(field.attributes, "Static") &&
        contains(field.attributes, "Literal")
}

func hasLiteralFields(typeDef: TypeDefinitionRecord): Bool {
    for (field in typeDef.fields) {
        if (isLiteralField(field)) {
            return true
        }
    }
    return false
}

func isEnumLiteral(field: FieldRecord): Bool {
    return isLiteralField(field)
}

func enumUnderlyingType(typeDef: TypeDefinitionRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    for (field in typeDef.fields) {
        if (field.name == "value__") {
            return cjAbiType(field.signature, symbolsByName)
        }
    }
    return "Int32"
}

func methodParameterText(method: MethodRecord, abi: Bool, symbolsByName: HashMap<String, SymbolRecord>): String {
    let pairs = methodParameterPairs(method, abi, symbolsByName)
    var content = ""
    var first = true
    for (pair in pairs) {
        if (!first) {
            content += ", "
        }
        content += "${pair.name}: ${pair.typeName}"
        first = false
    }
    return content
}

func methodArgumentText(method: MethodRecord, abi: Bool, symbolsByName: HashMap<String, SymbolRecord>): String {
    let pairs = methodParameterPairs(method, abi, symbolsByName)
    var content = ""
    var first = true
    for (pair in pairs) {
        if (!first) {
            content += ", "
        }
        content += pair.name
        first = false
    }
    return content
}

func methodParameterPairs(
    method: MethodRecord,
    abi: Bool,
    symbolsByName: HashMap<String, SymbolRecord>
): ArrayList<ParameterPair> {
    let metadataParameters = ArrayList<ParameterRecord>()
    for (parameter in method.parameters) {
        if (parameter.sequenceNumber > 0) {
            metadataParameters.add(parameter)
        }
    }
    let pairs = ArrayList<ParameterPair>()
    var index: Int64 = 0
    while (index < Int64(method.signature.parameters.size)) {
        let signature = method.signature.parameters[index]
        var name = "p${index}"
        if (index < Int64(metadataParameters.size)) {
            let parameterName = cjIdentifier(metadataParameters[index].name)
            if (!parameterName.isEmpty() && parameterName != "_") {
                name = parameterName
            }
        }
        var typeName = cjAbiType(signature, symbolsByName)
        if (!abi) {
            typeName = cjProjectedType(signature, symbolsByName)
        }
        pairs.add(ParameterPair(name, typeName))
        index += 1
    }
    return pairs
}

func pinvokeImportName(method: MethodRecord): String {
    match (method.methodImport) {
        case Some(methodImport) => return methodImport.name
        case None => return method.name
    }
}

func cjProjectedType(signature: SignatureRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    return cjAbiType(signature, symbolsByName)
}

func cjConstantType(signature: SignatureRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    if (signature.kind == "Primitive" && signature.name == "String") {
        return "String"
    }
    match (win32StringPointerLiteralFactoryType(signature, symbolsByName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (signatureFullNameInContext(signature, symbolsByName, "")) {
        case Some(fullName) =>
            if (fullName == "System.String") {
                return "String"
            }
            if (fullName == "System.Guid") {
                return "GUID"
            }
        case None => ()
    }
    return cjAbiType(signature, symbolsByName)
}

func win32StringPointerLiteralFactoryType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, "")) {
        case Some(fullName) =>
            if (fullName == "Windows.Win32.Foundation.PCWSTR") {
                return Some("windows_strings.WideStringFactory")
            }
            if (fullName == "Windows.Win32.Foundation.PCSTR") {
                return Some("windows_strings.NarrowStringFactory")
            }
        case None => ()
    }
    return None
}

func win32TextPointerRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return win32TextPointerRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func win32TextPointerRawAbiTypeByFullName(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.PWSTR" ||
        fullName == "Windows.Win32.Foundation.PCWSTR") {
        return Some("CPointer<UInt16>")
    }
    if (fullName == "Windows.Win32.Foundation.PSTR" ||
        fullName == "Windows.Win32.Foundation.PCSTR") {
        return Some("CPointer<UInt8>")
    }
    return None
}

func eventRegistrationTokenRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return eventRegistrationTokenRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func eventRegistrationTokenRawAbiTypeByFullName(fullName: String): Option<String> {
    if (fullName == "Windows.Foundation.EventRegistrationToken" ||
        fullName == "Windows.Win32.System.WinRT.EventRegistrationToken") {
        return Some("Int64")
    }
    return None
}

func hresultRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return hresultRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func hresultRawAbiTypeByFullName(fullName: String): Option<String> {
    if (fullName == "Windows.Foundation.HResult" ||
        fullName == "Windows.Win32.Foundation.HRESULT") {
        return Some("Int32")
    }
    return None
}

func win32ScalarRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return win32ScalarRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func win32ScalarRawAbiTypeByFullName(fullName: String): Option<String> {
    match (fullName) {
        case "Windows.Win32.Foundation.BOOL" => return Some("Int32")
        case "Windows.Win32.Foundation.BOOLEAN" => return Some("UInt8")
        case "Windows.Win32.Foundation.CHAR" => return Some("Int8")
        case "Windows.Win32.Foundation.COLORREF" => return Some("UInt32")
        case "Windows.Win32.Foundation.DWORD_PTR" => return Some("UIntNative")
        case "Windows.Win32.Foundation.DUPLICATE_HANDLE_OPTIONS" => return Some("UInt32")
        case "Windows.Win32.Foundation.GENERIC_ACCESS_RIGHTS" => return Some("UInt32")
        case "Windows.Win32.Foundation.HANDLE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Foundation.HANDLE_PTR" => return Some("UIntNative")
        case "Windows.Win32.Foundation.INT_PTR" => return Some("IntNative")
        case "Windows.Win32.Foundation.LONG_PTR" => return Some("IntNative")
        case "Windows.Win32.Foundation.LPARAM" => return Some("IntNative")
        case "Windows.Win32.Foundation.LRESULT" => return Some("IntNative")
        case "Windows.Win32.Foundation.NTSTATUS" => return Some("Int32")
        case "Windows.Win32.Foundation.NTSTATUS_FACILITY_CODE" => return Some("UInt32")
        case "Windows.Win32.Foundation.NTSTATUS_SEVERITY_CODE" => return Some("UInt32")
        case "Windows.Win32.Foundation.OBJECT_ATTRIBUTE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Foundation.SHANDLE_PTR" => return Some("IntNative")
        case "Windows.Win32.Foundation.SIZE_T" => return Some("UIntNative")
        case "Windows.Win32.Foundation.SSIZE_T" => return Some("IntNative")
        case "Windows.Win32.Foundation.UINT_PTR" => return Some("UIntNative")
        case "Windows.Win32.Foundation.ULONG_PTR" => return Some("UIntNative")
        case "Windows.Win32.Foundation.VARIANT_BOOL" => return Some("Int16")
        case "Windows.Win32.Foundation.WAIT_EVENT" => return Some("UInt32")
        case "Windows.Win32.Foundation.WIN32_ERROR" => return Some("UInt32")
        case "Windows.Win32.Foundation.WPARAM" => return Some("UIntNative")
        case "Windows.Win32.Security.ACE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.ACE_REVISION" => return Some("UInt32")
        case "Windows.Win32.Security.ACL_INFORMATION_CLASS" => return Some("Int32")
        case "Windows.Win32.Security.AUDIT_EVENT_TYPE" => return Some("Int32")
        case "Windows.Win32.Security.CLAIM_SECURITY_ATTRIBUTE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE" => return Some("UInt16")
        case "Windows.Win32.Security.CREATE_RESTRICTED_TOKEN_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.ENUM_PERIOD" => return Some("Int32")
        case "Windows.Win32.Security.LOGON32_LOGON" => return Some("UInt32")
        case "Windows.Win32.Security.LOGON32_PROVIDER" => return Some("UInt32")
        case "Windows.Win32.Security.MANDATORY_LEVEL" => return Some("Int32")
        case "Windows.Win32.Security.OBJECT_SECURITY_INFORMATION" => return Some("UInt32")
        case "Windows.Win32.Security.SECURITY_AUTO_INHERIT_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.SECURITY_DESCRIPTOR_CONTROL" => return Some("UInt16")
        case "Windows.Win32.Security.SECURITY_IMPERSONATION_LEVEL" => return Some("Int32")
        case "Windows.Win32.Security.SID_NAME_USE" => return Some("Int32")
        case "Windows.Win32.Security.SYSTEM_AUDIT_OBJECT_ACE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.Security.TOKEN_ACCESS_MASK" => return Some("UInt32")
        case "Windows.Win32.Security.TOKEN_ELEVATION_TYPE" => return Some("Int32")
        case "Windows.Win32.Security.TOKEN_INFORMATION_CLASS" => return Some("Int32")
        case "Windows.Win32.Security.TOKEN_MANDATORY_POLICY_ID" => return Some("UInt32")
        case "Windows.Win32.Security.TOKEN_PRIVILEGES_ATTRIBUTES" => return Some("UInt32")
        case "Windows.Win32.Security.TOKEN_TYPE" => return Some("Int32")
        case "Windows.Win32.Security.WELL_KNOWN_SID_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.ADVANCED_FEATURE_FLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.ADVF" => return Some("Int32")
        case "Windows.Win32.System.Com.APTTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.APTTYPEQUALIFIER" => return Some("Int32")
        case "Windows.Win32.System.Com.ApplicationType" => return Some("Int32")
        case "Windows.Win32.System.Com.BINDINFOF" => return Some("Int32")
        case "Windows.Win32.System.Com.BIND_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.CALLCONV" => return Some("Int32")
        case "Windows.Win32.System.Com.CALLTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.CLSCTX" => return Some("UInt32")
        case "Windows.Win32.System.Com.COINIT" => return Some("Int32")
        case "Windows.Win32.System.Com.COINITBASE" => return Some("Int32")
        case "Windows.Win32.System.Com.COMSD" => return Some("Int32")
        case "Windows.Win32.System.Com.COWAIT_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.CWMO_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.CO_MARSHALING_CONTEXT_ATTRIBUTES" => return Some("Int32")
        case "Windows.Win32.System.Com.DATADIR" => return Some("Int32")
        case "Windows.Win32.System.Com.DCOM_CALL_STATE" => return Some("Int32")
        case "Windows.Win32.System.Com.DESCKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.DISPATCH_FLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.DVASPECT" => return Some("UInt32")
        case "Windows.Win32.System.Com.EOLE_AUTHENTICATION_CAPABILITIES" => return Some("Int32")
        case "Windows.Win32.System.Com.EXTCONN" => return Some("Int32")
        case "Windows.Win32.System.Com.FUNCFLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.FUNCKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_EH_VALUES" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_PROPERTIES" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_RO_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_RPCTP_VALUES" => return Some("Int32")
        case "Windows.Win32.System.Com.GLOBALOPT_UNMARSHALING_POLICY_VALUES" => return Some("Int32")
        case "Windows.Win32.System.Com.IDLFLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.IMPLTYPEFLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.INVOKEKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.LOCKTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.MEMCTX" => return Some("Int32")
        case "Windows.Win32.System.Com.MKRREDUCE" => return Some("Int32")
        case "Windows.Win32.System.Com.MKSYS" => return Some("Int32")
        case "Windows.Win32.System.Com.MSHCTX" => return Some("Int32")
        case "Windows.Win32.System.Com.MSHLFLAGS" => return Some("Int32")
        case "Windows.Win32.System.Com.PENDINGMSG" => return Some("Int32")
        case "Windows.Win32.System.Com.PENDINGTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.REGCLS" => return Some("Int32")
        case "Windows.Win32.System.Com.ROT_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Com.RPCOPT_PROPERTIES" => return Some("Int32")
        case "Windows.Win32.System.Com.RPCOPT_SERVER_LOCALITY_VALUES" => return Some("Int32")
        case "Windows.Win32.System.Com.RPC_C_AUTHN_LEVEL" => return Some("UInt32")
        case "Windows.Win32.System.Com.RPC_C_IMP_LEVEL" => return Some("UInt32")
        case "Windows.Win32.System.Com.SERVERCALL" => return Some("Int32")
        case "Windows.Win32.System.Com.ShutdownType" => return Some("Int32")
        case "Windows.Win32.System.Com.STATFLAG" => return Some("Int32")
        case "Windows.Win32.System.Com.STGC" => return Some("Int32")
        case "Windows.Win32.System.Com.STGM" => return Some("UInt32")
        case "Windows.Win32.System.Com.STGTY" => return Some("Int32")
        case "Windows.Win32.System.Com.STREAM_SEEK" => return Some("UInt32")
        case "Windows.Win32.System.Com.SYSKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.THDTYPE" => return Some("Int32")
        case "Windows.Win32.System.Com.TYMED" => return Some("Int32")
        case "Windows.Win32.System.Com.TYPEKIND" => return Some("Int32")
        case "Windows.Win32.System.Com.TYSPEC" => return Some("Int32")
        case "Windows.Win32.System.Com.URI_CREATE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Com.Uri_PROPERTY" => return Some("Int32")
        case "Windows.Win32.System.Com.VARFLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Com.VARKIND" => return Some("Int32")
        case "Windows.Win32.System.Diagnostics.Debug.CONTEXT_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Kernel.COMPARTMENT_ID" => return Some("Int32")
        case "Windows.Win32.System.Kernel.EVENT_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Kernel.EXCEPTION_DISPOSITION" => return Some("Int32")
        case "Windows.Win32.System.Kernel.NT_PRODUCT_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Kernel.SUITE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Kernel.TIMER_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Kernel.WAIT_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Ole.PARAMFLAGS" => return Some("UInt16")
        case "Windows.Win32.System.Registry.REG_CREATE_KEY_DISPOSITION" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_NOTIFY_FILTER" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_OPEN_CREATE_OPTIONS" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_RESTORE_KEY_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Registry.REG_ROUTINE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_SAM_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_SAVE_FORMAT" => return Some("UInt32")
        case "Windows.Win32.System.Registry.REG_VALUE_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.Services.ENUM_SERVICE_STATE" => return Some("UInt32")
        case "Windows.Win32.System.Services.ENUM_SERVICE_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.Services.SC_ACTION_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SC_ENUM_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SC_EVENT_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SC_STATUS_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_CONFIG" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_DIRECTORY_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_ERROR" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_NOTIFY" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_REGISTRY_STATE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_RUNS_IN_PROCESS" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_SHARED_DIRECTORY_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_SHARED_REGISTRY_STATE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Services.SERVICE_START_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_STATUS_CURRENT_STATE" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_TRIGGER_ACTION" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_TRIGGER_SPECIFIC_DATA_ITEM_DATA_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.Services.SERVICE_TRIGGER_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.COMPUTER_NAME_FORMAT" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.CPU_SET_INFORMATION_TYPE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.DEP_SYSTEM_POLICY_TYPE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.DEVELOPER_DRIVE_ENABLEMENT_STATE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.DEVICEFAMILYDEVICEFORM" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.DEVICEFAMILYINFOENUM" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.FIRMWARE_TABLE_PROVIDER" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.FIRMWARE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.IMAGE_FILE_MACHINE" => return Some("UInt16")
        case "Windows.Win32.System.SystemInformation.LOGICAL_PROCESSOR_RELATIONSHIP" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.OS_DEPLOYEMENT_STATE_VALUES" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.OS_PRODUCT_TYPE" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.PROCESSOR_ARCHITECTURE" => return Some("UInt16")
        case "Windows.Win32.System.SystemInformation.PROCESSOR_CACHE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.RTL_SYSTEM_GLOBAL_DATA_ID" => return Some("Int32")
        case "Windows.Win32.System.SystemInformation.USER_CET_ENVIRONMENT" => return Some("UInt32")
        case "Windows.Win32.System.SystemInformation.VER_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.SystemServices.RTL_UMS_SCHEDULER_REASON" => return Some("Int32")
        case "Windows.Win32.System.Threading.AVRT_PRIORITY" => return Some("Int32")
        case "Windows.Win32.System.Threading.CREATE_EVENT" => return Some("UInt32")
        case "Windows.Win32.System.Threading.CREATE_PROCESS_LOGON_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.GET_GUI_RESOURCES_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.MACHINE_ATTRIBUTES" => return Some("Int32")
        case "Windows.Win32.System.Threading.MEMORY_PRIORITY" => return Some("UInt32")
        case "Windows.Win32.System.Threading.OVERRIDE_PREFETCH_PARAMETER" => return Some("UInt32")
        case "Windows.Win32.System.Threading.POWER_REQUEST_CONTEXT_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESSOR_FEATURE_ID" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_ACCESS_RIGHTS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_AFFINITY_AUTO_UPDATE_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_CREATION_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_DEP_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_INFORMATION_CLASS" => return Some("Int32")
        case "Windows.Win32.System.Threading.PROCESS_MEMORY_EXHAUSTION_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Threading.PROCESS_MITIGATION_POLICY" => return Some("Int32")
        case "Windows.Win32.System.Threading.PROCESS_NAME_FORMAT" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROCESS_PROTECTION_LEVEL" => return Some("UInt32")
        case "Windows.Win32.System.Threading.PROC_THREAD_ATTRIBUTE_NUM" => return Some("UInt32")
        case "Windows.Win32.System.Threading.QUEUE_USER_APC_FLAGS" => return Some("Int32")
        case "Windows.Win32.System.Threading.RTWQ_WORKQUEUE_TYPE" => return Some("Int32")
        case "Windows.Win32.System.Threading.STARTUPINFOW_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.SYNCHRONIZATION_ACCESS_RIGHTS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.THREAD_ACCESS_RIGHTS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.THREAD_CREATION_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Threading.THREAD_INFORMATION_CLASS" => return Some("Int32")
        case "Windows.Win32.System.Threading.THREAD_PRIORITY" => return Some("Int32")
        case "Windows.Win32.System.Threading.TP_CALLBACK_PRIORITY" => return Some("Int32")
        case "Windows.Win32.System.Threading.UMS_THREAD_INFO_CLASS" => return Some("Int32")
        case "Windows.Win32.System.Threading.WORKER_THREAD_FLAGS" => return Some("UInt32")
        case "Windows.Win32.System.Variant.VARENUM" => return Some("UInt16")
        case _ => return None
    }
}

func stringHandleRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
        case Some(fullName) => return stringHandleRawAbiTypeByFullName(fullName)
        case None => ()
    }
    return None
}

func stringHandleRawAbiTypeByFullName(fullName: String): Option<String> {
    if (fullName == "Windows.Win32.Foundation.BSTR" ||
        fullName == "Windows.Win32.System.WinRT.HSTRING") {
        return Some("CPointer<Unit>")
    }
    return None
}

func knownRawAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (win32TextPointerRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    match (eventRegistrationTokenRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    match (hresultRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    match (win32ScalarRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    match (stringHandleRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return Some(typeName)
        case None => ()
    }
    return None
}

func rawPointerAbiType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    if (signature.kind != "Pointer" && !isByReferenceSignature(signature) &&
        signature.kind != "SZArray") {
        return None
    }
    match (signature.typeSig) {
        case Some(nested) =>
            match (knownRawAbiType(nested, symbolsByName, ownerFullName)) {
                case Some(typeName) => return Some("CPointer<${typeName}>")
                case None => ()
            }
            match (rawPointerAbiType(nested, symbolsByName, ownerFullName)) {
                case Some(typeName) => return Some("CPointer<${typeName}>")
                case None => ()
            }
        case None => ()
    }
    match (signature.unmodifiedType) {
        case Some(nested) =>
            match (knownRawAbiType(nested, symbolsByName, ownerFullName)) {
                case Some(typeName) => return Some("CPointer<${typeName}>")
                case None => ()
            }
            match (rawPointerAbiType(nested, symbolsByName, ownerFullName)) {
                case Some(typeName) => return Some("CPointer<${typeName}>")
                case None => ()
            }
        case None => ()
    }
    return None
}

func cjAbiType(signature: SignatureRecord, symbolsByName: HashMap<String, SymbolRecord>): String {
    return cjAbiTypeInContext(signature, symbolsByName, "")
}

func cjAbiTypeInContext(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): String {
    match (win32TextPointerRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (eventRegistrationTokenRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (hresultRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (win32ScalarRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    match (stringHandleRawAbiType(signature, symbolsByName, ownerFullName)) {
        case Some(typeName) => return typeName
        case None => ()
    }
    if (signature.kind == "Primitive") {
        return primitiveCjType(signature.name)
    }
    if (signature.kind == "Void" || signature.kind == "Unit") {
        return "Unit"
    }
    if (signature.kind == "Array") {
        match (fixedArrayCjType(signature, symbolsByName, ownerFullName)) {
            case Some(typeName) => return typeName
            case None => return "CPointer<Unit>"
        }
    }
    if (signature.kind == "Pointer" || isByReferenceSignature(signature) ||
        signature.kind == "SZArray") {
        match (rawPointerAbiType(signature, symbolsByName, ownerFullName)) {
            case Some(typeName) => return typeName
            case None => ()
        }
        return "CPointer<Unit>"
    }
    if (signature.kind == "Type" || signature.kind == "TypeReference" || signature.kind == "TypeDefinition") {
        match (signatureFullNameInContext(signature, symbolsByName, ownerFullName)) {
            case Some(fullName) =>
                if (fullName == "System.Guid") {
                    return "GUID"
                }
                if (startsWith(fullName, "System.")) {
                    return systemType(fullName)
                }
                match (symbolsByName.get(fullName)) {
                    case Some(symbol) =>
                        match (symbol.typeDef) {
                            case Some(typeDef) =>
                                if (isEnumType(typeDef)) {
                                    return enumUnderlyingType(typeDef, symbolsByName)
                                }
                                if (isWinrtDelegateType(typeDef)) {
                                    return "CPointer<Unit>"
                                }
                                if (isDelegateType(typeDef)) {
                                    match (delegateCFuncType(typeDef, symbolsByName)) {
                                        case Some(typeName) => return typeName
                                        case None => ()
                                    }
                                }
                                if (!isValueType(typeDef)) {
                                    return "CPointer<Unit>"
                                }
                            case None => ()
                        }
                    case None => ()
                }
                return qualifyMangledFullName(fullName)
            case None => ()
        }
    }
    match (signature.typeSpecification) {
        case Some(_) => return "CPointer<Unit>"
        case None => ()
    }
    match (signature.typeSig) {
        case Some(nested) => return cjAbiTypeInContext(nested, symbolsByName, ownerFullName)
        case None => ()
    }
    match (signature.unmodifiedType) {
        case Some(nested) => return cjAbiTypeInContext(nested, symbolsByName, ownerFullName)
        case None => ()
    }
    return "CPointer<Unit>"
}

func delegateCFuncType(
    typeDef: TypeDefinitionRecord,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    for (method in typeDef.methods) {
        if (method.name == "Invoke") {
            let params = ArrayList<String>()
            for (parameter in method.signature.parameters) {
                params.add(cjAbiType(parameter, symbolsByName))
            }
            let returnType = cjAbiType(method.signature.returnType, symbolsByName)
            if (params.isEmpty()) {
                return Some("CFunc<() -> ${returnType}>")
            }
            return Some("CFunc<(${joinStrings(params, ", ")}) -> ${returnType}>")
        }
    }
    return None
}

func fixedArrayCjType(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signature.rank) {
        case Some(rank) =>
            if (rank != 1) {
                return None
            }
        case None => return None
    }
    match (signature.sizes) {
        case Some(sizes) =>
            if (sizes.size != 1 || sizes[0] <= 0) {
                return None
            }
            match (signature.typeSig) {
                case Some(elementSignature) =>
                    let elementType = cjAbiTypeInContext(elementSignature, symbolsByName, ownerFullName)
                    return Some("VArray<${elementType}, \$${sizes[0]}>")
                case None => return None
            }
        case None => return None
    }
}

func signatureFullNameInContext(
    signature: SignatureRecord,
    symbolsByName: HashMap<String, SymbolRecord>,
    ownerFullName: String
): Option<String> {
    match (signature.typeSpecification) {
        case Some(typeSpec) => return signatureFullNameInContext(typeSpec.signature, symbolsByName, ownerFullName)
        case None => ()
    }
    if (!signature.name.isEmpty() && signature.hasNamespace) {
        if (signature.namespace.isEmpty()) {
            match (resolveRelativeTypeFullName(ownerFullName, signature.name, symbolsByName)) {
                case Some(fullName) => return Some(remapKnownTypeFullName(fullName))
                case None => ()
            }
            return Some(signature.name)
        }
        return Some(remapKnownTypeFullName("${signature.namespace}.${signature.name}"))
    }
    match (signature.typeReference) {
        case Some(metadataType) =>
            if (metadataType.namespace.isEmpty()) {
                match (resolveRelativeTypeFullName(ownerFullName, metadataType.name, symbolsByName)) {
                    case Some(fullName) => return Some(remapKnownTypeFullName(fullName))
                    case None => ()
                }
            }
            return Some(remapKnownTypeFullName(metadataType.fullName()))
        case None => ()
    }
    match (signature.typeDefinition) {
        case Some(metadataType) =>
            if (metadataType.namespace.isEmpty()) {
                match (resolveRelativeTypeFullName(ownerFullName, metadataType.name, symbolsByName)) {
                    case Some(fullName) => return Some(remapKnownTypeFullName(fullName))
                    case None => ()
                }
            }
            return Some(remapKnownTypeFullName(metadataType.fullName()))
        case None => ()
    }
    if (signature.kind == "Generic") {
        match (signature.typeSig) {
            case Some(nested) => return signatureFullNameInContext(nested, symbolsByName, ownerFullName)
            case None => ()
        }
    }
    return None
}

func remapKnownTypeFullName(fullName: String): String {
    match (fullName) {
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_MATRIX_3X2_F" =>
            return "Windows.Foundation.Numerics.Matrix3x2"
        case "Windows.Win32.Graphics.Direct3D.D3DMATRIX" =>
            return "Windows.Foundation.Numerics.Matrix4x4"
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_MATRIX_4X4_F" =>
            return "Windows.Foundation.Numerics.Matrix4x4"
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_POINT_2F" =>
            return "Windows.Foundation.Numerics.Vector2"
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_VECTOR_2F" =>
            return "Windows.Foundation.Numerics.Vector2"
        case "Windows.Win32.Graphics.Direct2D.Common.D2D_VECTOR_4F" =>
            return "Windows.Foundation.Numerics.Vector4"
        case _ => return fullName
    }
}

func resolveRelativeTypeFullName(
    ownerFullName: String,
    name: String,
    symbolsByName: HashMap<String, SymbolRecord>
): Option<String> {
    var current = ownerFullName
    while (!current.isEmpty()) {
        let candidate = "${current}.${name}"
        match (symbolsByName.get(candidate)) {
            case Some(_) => return Some(candidate)
            case None => ()
        }
        current = parentFullName(current)
    }
    return None
}

func parentFullName(fullName: String): String {
    let bytes = fullName.toArray()
    var i = Int64(bytes.size) - 1
    while (i >= 0) {
        if (bytes[i] == b'.') {
            return String.fromUtf8(bytes[0..i])
        }
        i -= 1
    }
    return ""
}

func primitiveCjType(name: String): String {
    match (name) {
        case "Boolean" => return "Bool"
        case "Bool" => return "Bool"
        case "Byte" => return "UInt8"
        case "Char" => return "UInt16"
        case "Double" => return "Float64"
        case "Float" => return "Float32"
        case "Float32" => return "Float32"
        case "Float64" => return "Float64"
        case "Int8" => return "Int8"
        case "Int16" => return "Int16"
        case "Int32" => return "Int32"
        case "Int64" => return "Int64"
        case "SByte" => return "Int8"
        case "Single" => return "Float32"
        case "String" => return "CPointer<Unit>"
        case "UInt8" => return "UInt8"
        case "UInt16" => return "UInt16"
        case "UInt32" => return "UInt32"
        case "UInt64" => return "UInt64"
        case "Void" => return "Unit"
        case _ => return "CPointer<Unit>"
    }
}

func systemType(fullName: String): String {
    match (fullName) {
        case "System.Boolean" => return "Bool"
        case "System.Byte" => return "UInt8"
        case "System.Char" => return "UInt16"
        case "System.Double" => return "Float64"
        case "System.Int16" => return "Int16"
        case "System.Int32" => return "Int32"
        case "System.Int64" => return "Int64"
        case "System.IntPtr" => return "CPointer<Unit>"
        case "System.Object" => return "CPointer<Unit>"
        case "System.SByte" => return "Int8"
        case "System.Single" => return "Float32"
        case "System.String" => return "CPointer<Unit>"
        case "System.UInt16" => return "UInt16"
        case "System.UInt32" => return "UInt32"
        case "System.UInt64" => return "UInt64"
        case "System.UIntPtr" => return "CPointer<Unit>"
        case "System.Void" => return "Unit"
        case _ => return "CPointer<Unit>"
    }
}

func cjDefaultValue(typeName: String): String {
    if (typeName == "Bool") {
        return "false"
    }
    if (typeName == "Float32") {
        return "0.0f32"
    }
    if (typeName == "Float64") {
        return "0.0f64"
    }
    if (startsWith(typeName, "CPointer<")) {
        return "${typeName}()"
    }
    if (startsWith(typeName, "CFunc<")) {
        return "${typeName}(CPointer<Unit>())"
    }
    if (startsWith(typeName, "VArray<")) {
        match (vArrayElementTypeName(typeName)) {
            case Some(elementType) => return "${typeName}(repeat: ${vArrayRepeatValue(elementType)})"
            case None => return "${typeName}()"
        }
    }
    match (typeName) {
        case "UInt8" => return "0u8"
        case "UInt16" => return "0u16"
        case "UInt32" => return "0u32"
        case "UInt64" => return "0u64"
        case "Int8" => return "0i8"
        case "Int16" => return "0i16"
        case "Int32" => return "0i32"
        case "Int64" => return "0i64"
        case "UIntNative" => return "0"
        case "IntNative" => return "0"
        case _ => return "${typeName}()"
    }
}

func vArrayRepeatValue(elementType: String): String {
    match (elementType) {
        case "UInt8" => return "0u8"
        case "UInt16" => return "0u16"
        case "UInt32" => return "0u32"
        case "UInt64" => return "0u64"
        case "UIntNative" => return "0"
        case "Int8" => return "0i8"
        case "Int16" => return "0i16"
        case "Int32" => return "0i32"
        case "Int64" => return "0i64"
        case "IntNative" => return "0"
        case _ => return cjDefaultValue(elementType)
    }
}

func vArrayElementTypeName(typeName: String): Option<String> {
    let bytes = typeName.toArray()
    let prefix = "VArray<"
    let prefixBytes = prefix.toArray()
    if (!startsWith(typeName, prefix)) {
        return None
    }
    var i = Int64(prefixBytes.size)
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b',') {
            return Some(String.fromUtf8(bytes[Int64(prefixBytes.size)..i]))
        }
        i += 1
    }
    return None
}

func vArrayCount(typeName: String): Option<Int64> {
    let bytes = typeName.toArray()
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'$') {
            let start = i + 1
            var end = start
            while (end < Int64(bytes.size) && bytes[end] >= b'0' && bytes[end] <= b'9') {
                end += 1
            }
            if (end > start) {
                return parseDecimalInt64(String.fromUtf8(bytes[start..end]))
            }
            return None
        }
        i += 1
    }
    return None
}

func parseDecimalInt64(value: String): Option<Int64> {
    let bytes = value.toArray()
    if (bytes.isEmpty()) {
        return None
    }
    var result: Int64 = 0
    for (byte in bytes) {
        if (byte < b'0' || byte > b'9') {
            return None
        }
        result = result * 10 + Int64(byte - b'0')
    }
    return Some(result)
}

func literalValue(value: Option<JsonValue>): Option<JsonValue> {
    match (value) {
        case Some(jsonValue) =>
            match (jsonValue.kind()) {
                case JsonKind.JsObject =>
                    match (jsonValue.asObject().get("Value")) {
                        case Some(inner) => return Some(inner)
                        case None => return Some(jsonValue)
                    }
                case _ => return Some(jsonValue)
            }
        case None => return None
    }
}

func cjLiteral(value: JsonValue, typeName: String): String {
    match (value.kind()) {
        case JsonKind.JsBool =>
            if (value.asBool().getValue()) {
                return "true"
            }
            return "false"
        case JsonKind.JsInt =>
            if (typeName == "Bool") {
                if (value.asInt().getValue() == 0) {
                    return "false"
                }
                return "true"
            }
            return "${value.asInt().getValue()}"
        case JsonKind.JsFloat => return "${value.asFloat().getValue()}"
        case JsonKind.JsString =>
            if (typeName == "String") {
                return "\"${cjStringContent(value.asString().getValue())}\""
            }
            if (typeName == "windows_strings.WideStringFactory") {
                return "windows_strings.wideStringFactory(\"${cjStringContent(value.asString().getValue())}\")"
            }
            if (typeName == "windows_strings.NarrowStringFactory") {
                return "windows_strings.pcstrLiteral(\"${cjStringContent(value.asString().getValue())}\")"
            }
            return value.asString().getValue()
        case _ => return cjDefaultValue(typeName)
    }
}

func cjLiteralInt(value: String, typeName: String): String {
    return value
}

func cjIdentifier(value: String): String {
    return facadeShortName(value)
}

func cjStringContent(value: String): String {
    let bytes = value.toArray()
    var result = ""
    for (byte in bytes) {
        if (byte == b'\\') {
            result += "\\\\"
        } else if (byte == b'"') {
            result += "\\\""
        } else if (byte == b'$') {
            result += "\\$"
        } else if (byte == b'\n') {
            result += "\\n"
        } else if (byte == b'\r') {
            result += "\\r"
        } else {
            result += String.fromUtf8([byte])
        }
    }
    return result
}

func startsWith(value: String, prefix: String): Bool {
    let valueBytes = value.toArray()
    let prefixBytes = prefix.toArray()
    if (prefixBytes.size > valueBytes.size) {
        return false
    }
    var i: Int64 = 0
    while (i < Int64(prefixBytes.size)) {
        if (valueBytes[i] != prefixBytes[i]) {
            return false
        }
        i += 1
    }
    return true
}
