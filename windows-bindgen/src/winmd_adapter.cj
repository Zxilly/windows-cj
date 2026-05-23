package windows_bindgen

import std.collection.*
import std.fs.*
import stdx.encoding.json.*
import stdx.crypto.digest.*
import stdx.encoding.hex.*
import windows_bindgen.winmd.*

// winmd_adapter.cj
//
// Adapts the native winmd reader engine (windows_bindgen.winmd) into the bindgen
// model records (model.cj) so that, downstream, `emitWinmdJson` can produce JSON
// that matches the reference C# winmd-to-json tool. The engine is frozen; this
// module only reads its public API and never mutates it.
//
// Entry point: loadWinmdFilesNative(paths) -> ArrayList<WinmdFileRecord>.
//
// Known engine information gaps (see report) that this adapter cannot fully
// reconstruct:
//   - Type source (TypeDefinition vs TypeReference): the engine collapses both
//     ELEMENT_TYPE_CLASS/VALUETYPE coded-index tags into ClassName/ValueName and
//     discards which table the index pointed at. We emit "TypeReference" (the
//     dominant case) for all Type signatures.
//   - CMOD modifiers: the engine folds CMOD_OPT/REQD into an `isConst` flag and
//     produces RefConst/PtrConst. For RefConst (`const T&`) the IsConst modifier
//     is reconstructable (it is always System.Runtime.CompilerServices.IsConst,
//     the only modifier the engine matches), so the "Modified" wrapper is rebuilt
//     in adaptType to preserve the by-reference ABI. For PtrConst the const-ness
//     is dropped (the golden does not wrap a const pointer in Modified either).

let TOOL_VERSION = "1.0.0"
let SCHEMA_VERSION = "1"
let SOURCE_SET = "winmd_main"

// Load one or more winmd files natively and adapt each into a WinmdFileRecord.
public func loadWinmdFilesNative(paths: Array<String>): ArrayList<WinmdFileRecord> {
    if (paths.size == 0) {
        throw Exception("at least one winmd path is required")
    }
    let results = ArrayList<WinmdFileRecord>()
    for (path in paths) {
        results.add(loadSingleWinmdFileNative(path))
    }
    return results
}

public func loadWinmdFilesNative(paths: ArrayList<String>): ArrayList<WinmdFileRecord> {
    let array = Array<String>(Int64(paths.size), {i => paths[i]})
    return loadWinmdFilesNative(array)
}

// CLI handler for the `--emit-winmd-json` mode. Returns Some(exitCode) when the
// arguments selected this mode, or None to let the caller fall through to the
// normal bindgen CLI.
//
// Modes:
//   -o <file>   write all inputs into a single JSON document (first input's
//               winmd_file / winmd_sha256 metadata is used as the header).
//   -d <dir>    write one <Namespace>.json per namespace under <dir>, mirroring
//               the reference converter's directory mode.
//   (neither)   write the single-document JSON to stdout.
func tryRunEmitWinmdJson(args: Array<String>): Option<Int64> {
    var selected = false
    let inputs = ArrayList<String>()
    var output = ""
    var outDir = ""
    var i: Int64 = 0
    while (i < Int64(args.size)) {
        let arg = args[i]
        if (arg == "--emit-winmd-json") {
            selected = true
        } else if (arg == "-o") {
            i += 1
            if (i >= Int64(args.size)) {
                throw Exception("-o requires a value")
            }
            output = args[i]
        } else if (arg == "-d") {
            i += 1
            if (i >= Int64(args.size)) {
                throw Exception("-d requires a value")
            }
            outDir = args[i]
        } else {
            inputs.add(arg)
        }
        i += 1
    }
    if (!selected) {
        return None
    }
    if (inputs.isEmpty()) {
        println("windows-bindgen --emit-winmd-json requires at least one .winmd input")
        return Some(1)
    }

    if (!outDir.isEmpty()) {
        emitWinmdJsonPerNamespace(inputs, outDir)
        return Some(0)
    }

    // Single-document mode (file or stdout). The header uses the first input.
    let records = loadWinmdFilesNative(Array<String>(Int64(inputs.size), {k => inputs[k]}))
    let merged = mergeRecordsForSingleDocument(records)
    let json = emitWinmdJson(merged)
    if (output.isEmpty()) {
        println(json)
    } else {
        File.writeTo(output, json.toArray())
    }
    return Some(0)
}

// Merge multiple file records into one document (header from the first input,
// types concatenated) so a single -o file can carry several winmd inputs.
func mergeRecordsForSingleDocument(records: ArrayList<WinmdFileRecord>): WinmdFileRecord {
    if (Int64(records.size) == 1) {
        return records[0]
    }
    let first = records[0]
    let types = ArrayList<TypeDefinitionRecord>()
    for (record in records) {
        for (t in record.types) {
            types.add(t)
        }
    }
    return WinmdFileRecord(first.winmdFile, first.winmdSha256, first.toolVersion, first.schemaVersion, first.sourceSet, types)
}

// Directory mode: one <Namespace>.json per namespace (skipping the empty
// namespace, matching the reference converter). Each per-namespace file carries
// the originating input's winmd_file / winmd_sha256 header.
func emitWinmdJsonPerNamespace(inputs: ArrayList<String>, outDir: String): Unit {
    ensureDir(outDir)
    let records = loadWinmdFilesNative(Array<String>(Int64(inputs.size), {k => inputs[k]}))
    // Group types by namespace, keyed in first-seen order; remember which file
    // header each namespace first appeared under.
    let namespaceOrder = ArrayList<String>()
    let typesByNamespace = HashMap<String, ArrayList<TypeDefinitionRecord>>()
    let headerByNamespace = HashMap<String, WinmdFileRecord>()
    for (record in records) {
        for (t in record.types) {
            if (t.namespace.isEmpty()) {
                continue
            }
            if (!typesByNamespace.contains(t.namespace)) {
                typesByNamespace.add(t.namespace, ArrayList<TypeDefinitionRecord>())
                headerByNamespace.add(t.namespace, record)
                namespaceOrder.add(t.namespace)
            }
            typesByNamespace[t.namespace].add(t)
        }
    }
    for (namespace in namespaceOrder) {
        let header = headerByNamespace[namespace]
        let doc = WinmdFileRecord(
            header.winmdFile,
            header.winmdSha256,
            header.toolVersion,
            header.schemaVersion,
            header.sourceSet,
            typesByNamespace[namespace]
        )
        let json = emitWinmdJson(doc)
        File.writeTo("${outDir}/${namespace}.json", json.toArray())
    }
}

func loadSingleWinmdFileNative(path: String): WinmdFileRecord {
    let file = match (WinmdFile.read(path)) {
        case Some(f) => f
        case None => throw Exception("failed to read winmd file: ${path}")
    }
    // Build a single-file TypeIndex so we can reuse its high-level accessors.
    let files = ArrayList<WinmdFile>()
    files.add(file)
    let index = TypeIndex(files)
    let fileIdx: Int64 = 0

    let sha = sha256HexOfFile(path)
    let fileName = baseName(path)

    // Walk the full TypeDef range (includes <Module> + nested types, matching the
    // C# tool's reader.TypeDefinitions enumeration).
    let types = ArrayList<TypeDefinitionRecord>()
    let (tdStart, tdEnd) = file.typeDefRange()
    var row = tdStart
    while (row < tdEnd) {
        types.add(adaptTypeDefinition(index, fileIdx, row))
        row += 1
    }

    return WinmdFileRecord(fileName, sha, TOOL_VERSION, SCHEMA_VERSION, SOURCE_SET, types)
}

// --- TypeDefinition adaptation ---

func adaptTypeDefinition(index: TypeIndex, fileIdx: Int64, row: Int64): TypeDefinitionRecord {
    let namespace = index.typeDefNamespace(fileIdx, row)
    let name = index.typeDefName(fileIdx, row)
    let flags = index.typeDefFlags(fileIdx, row)
    let isNested = flags.isNested()

    let baseType = adaptBaseType(index, fileIdx, row)
    let hasBaseType = baseType.isSome()

    // Type-level generic substitutes (ELEMENT_TYPE_VAR resolution). The engine's
    // blob reader replaces a VAR index with generics[idx] when supplied; passing
    // the real generic-parameter names recovers TResult/K/V/... instead of the
    // synthetic T0/T1 placeholders.
    let typeGenerics = typeGenericSubstitutes(index, fileIdx, row)

    let attributes = typeAttributesToStrings(flags.value)
    let customAttributes = adaptCustomAttributes(index, fileIdx, TABLE_TYPE_DEF, row)
    let fields = adaptFields(index, fileIdx, row, typeGenerics)
    let interfaceImpls = adaptInterfaceImplementations(index, fileIdx, row, typeGenerics)
    let layout = adaptLayout(index, fileIdx, row)
    let methods = adaptMethods(index, fileIdx, row, typeGenerics)
    let nestedTypes = adaptNestedTypes(index, fileIdx, row)
    let genericParameters = adaptTypeGenericParameters(index, fileIdx, row)
    let events = adaptEvents(index, fileIdx, row, typeGenerics)
    let properties = adaptProperties(index, fileIdx, row, typeGenerics)
    let supportedArchitectures = adaptSupportedArchitectures(index, fileIdx, row)
    let supportedOsPlatform = adaptSupportedOsPlatform(index, fileIdx, row)
    let isExperimental = adaptIsExperimental(index, fileIdx, row)

    return TypeDefinitionRecord(
        namespace,
        name,
        baseType: baseTypeOr(baseType),
        hasBaseType: hasBaseType,
        isNested: isNested,
        attributes: attributes,
        customAttributes: customAttributes,
        fields: fields,
        interfaceImplementations: interfaceImpls,
        layout: Some(layout),
        methods: methods,
        nestedTypes: nestedTypes,
        genericParameters: genericParameters,
        events: events,
        properties: properties,
        supportedArchitectures: supportedArchitectures,
        supportedOsPlatform: supportedOsPlatform,
        isExperimental: isExperimental,
        sourceSet: SOURCE_SET
    )
}

func baseTypeOr(value: Option<String>): String {
    match (value) {
        case Some(v) => return v
        case None => return ""
    }
}

// BaseType: the extends coded index, formatted as "Namespace.Name" for
// TypeDef/TypeRef, or a flattened FormatType string for a TypeSpec base.
func adaptBaseType(index: TypeIndex, fileIdx: Int64, row: Int64): Option<String> {
    let (extTable, extRow) = index.typeDefExtends(fileIdx, row)
    if (extTable < 0) {
        return None
    }
    let file = index.getFile(fileIdx)
    if (extTable == TABLE_TYPE_DEF) {
        let ns = file.getString(extRow, TABLE_TYPE_DEF, 2)
        let nm = file.getString(extRow, TABLE_TYPE_DEF, 1)
        return Some(qualifiedName(ns, nm))
    }
    if (extTable == TABLE_TYPE_REF) {
        let ns = file.getString(extRow, TABLE_TYPE_REF, 2)
        let nm = file.getString(extRow, TABLE_TYPE_REF, 1)
        return Some(qualifiedName(ns, nm))
    }
    if (extTable == TABLE_TYPE_SPEC) {
        let spec = TypeSpec(index, fileIdx, extRow)
        return Some(formatType(spec.ty()))
    }
    return None
}

func qualifiedName(ns: String, nm: String): String {
    if (ns.isEmpty()) {
        return nm
    }
    return "${ns}.${nm}"
}

// --- Nested types ---

func adaptNestedTypes(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<TypeDefinitionRecord> {
    let result = ArrayList<TypeDefinitionRecord>()
    for (nestedRow in index.getNested(fileIdx, row)) {
        result.add(adaptTypeDefinition(index, fileIdx, nestedRow))
    }
    return result
}

// --- Layout ---

func adaptLayout(index: TypeIndex, fileIdx: Int64, row: Int64): TypeLayoutRecord {
    match (index.typeDefClassLayout(fileIdx, row)) {
        case Some((packing, size)) =>
            return TypeLayoutRecord(false, Int64(packing), Int64(size))
        case None =>
            // No ClassLayout: C# TypeLayout.IsDefault is true with zeroed sizes.
            return TypeLayoutRecord(true, 0, 0)
    }
}

// Build the array of MetadataType substitutes for a TypeDef's generic
// parameters, indexed by sequence number. Each entry is Generic(realName, idx)
// so the engine's VAR resolution yields the declared name (TResult/K/V/...).
func typeGenericSubstitutes(index: TypeIndex, fileIdx: Int64, row: Int64): Array<MetadataType> {
    let (start, end) = index.typeDefGenericParams(fileIdx, row)
    let count = end - start
    if (count <= 0) {
        return Array<MetadataType>()
    }
    let names = ArrayList<String>()
    let sequences = ArrayList<Int64>()
    var gi = start
    while (gi < end) {
        names.add(index.genericParamName(fileIdx, gi))
        sequences.add(Int64(index.genericParamSequence(fileIdx, gi)))
        gi += 1
    }
    // Find the maximum sequence so the array can be indexed directly by VAR idx.
    var maxSeq: Int64 = -1
    for (s in sequences) {
        if (s > maxSeq) {
            maxSeq = s
        }
    }
    let result = Array<MetadataType>(maxSeq + 1, {i => MetadataType.Generic("T${i}", UInt16(i))})
    var k: Int64 = 0
    while (k < Int64(sequences.size)) {
        let seq = sequences[k]
        if (seq >= 0 && seq <= maxSeq) {
            result[seq] = MetadataType.Generic(names[k], UInt16(seq))
        }
        k += 1
    }
    return result
}

// --- Fields ---

func adaptFields(index: TypeIndex, fileIdx: Int64, row: Int64, generics: Array<MetadataType>): ArrayList<FieldRecord> {
    let result = ArrayList<FieldRecord>()
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fi = fStart
    while (fi < fEnd) {
        result.add(adaptField(index, fileIdx, fi, generics))
        fi += 1
    }
    return result
}

func adaptField(index: TypeIndex, fileIdx: Int64, fieldRow: Int64, generics: Array<MetadataType>): FieldRecord {
    let name = index.fieldName(fileIdx, fieldRow)
    let signature = adaptType(index, fileIdx, fieldTypeWithGenerics(index, fileIdx, fieldRow, generics))
    let flags = index.fieldFlags(fileIdx, fieldRow)
    let attributes = fieldAttributesToStrings(UInt32(flags.value))
    let customAttributes = adaptCustomAttributes(index, fileIdx, TABLE_FIELD, fieldRow)

    // DefaultValue: a JsConstant { TypeCode, Value } when a Constant row exists.
    // Read via the safe local decoder (the engine's fieldConstant path performs a
    // checked Int32 cast that overflows on U32 constants >= 0x80000000).
    let defaultValue = safeConstantJson(index, fileIdx, TABLE_FIELD, fieldRow)

    // Offset: FieldLayout offset, or -1 when absent (C# GetOffset() returns -1).
    var offset: Int64 = -1
    match (index.fieldLayout(fileIdx, fieldRow)) {
        case Some(value) => offset = Int64(value)
        case None => ()
    }

    // RelativeVirtualAddress: FieldRVA mapped RVA, or 0 when absent.
    var rva: Int64 = 0
    match (index.fieldRva(fileIdx, fieldRow)) {
        case Some(value) => rva = Int64(value)
        case None => ()
    }

    return FieldRecord(
        name,
        signature,
        attributes: attributes,
        customAttributes: customAttributes,
        defaultValue: defaultValue,
        offset: offset,
        relativeVirtualAddress: rva
    )
}

// Re-read a Field's type signature with the supplied type-level generics so VAR
// references resolve to their declared names (the engine's fieldType helper
// passes an empty generics array).
func fieldTypeWithGenerics(index: TypeIndex, fileIdx: Int64, fieldRow: Int64, generics: Array<MetadataType>): MetadataType {
    if (generics.size == 0) {
        return index.fieldType(fileIdx, fieldRow)
    }
    let file = index.getFile(fileIdx)
    var blob = file.getBlob(fieldRow, TABLE_FIELD, 2)
    let _ = blob.readU8() // FIELD signature calling-convention byte (0x06)
    return blob.readTypeSignature(file, generics)
}

// --- Methods ---

func adaptMethods(index: TypeIndex, fileIdx: Int64, row: Int64, generics: Array<MetadataType>): ArrayList<MethodRecord> {
    let result = ArrayList<MethodRecord>()
    let (mStart, mEnd) = index.typeDefMethods(fileIdx, row)
    var mi = mStart
    while (mi < mEnd) {
        result.add(adaptMethod(index, fileIdx, mi, generics))
        mi += 1
    }
    return result
}

func adaptMethod(index: TypeIndex, fileIdx: Int64, methodRow: Int64, generics: Array<MetadataType>): MethodRecord {
    let name = index.methodDefName(fileIdx, methodRow)
    let methodFlags = index.methodDefFlags(fileIdx, methodRow)
    let implFlags = index.methodDefImplFlags(fileIdx, methodRow)
    let signature = index.methodDefSignature(fileIdx, methodRow, generics)

    let attributes = methodAttributesToStrings(UInt32(methodFlags.value))
    let implAttributes = methodImplAttributesToStrings(UInt32(implFlags.value))
    let customAttributes = adaptCustomAttributes(index, fileIdx, TABLE_METHOD_DEF, methodRow)
    let rva = Int64(index.methodDefRva(fileIdx, methodRow))

    let methodSignature = adaptMethodSignature(index, fileIdx, signature)
    let parameters = adaptParameters(index, fileIdx, methodRow)
    let methodImport = adaptMethodImport(index, fileIdx, methodRow)
    let genericParameters = adaptMethodGenericParameters(index, fileIdx, methodRow)

    return MethodRecord(
        name,
        methodSignature,
        parameters: parameters,
        attributes: attributes,
        implAttributes: implAttributes,
        customAttributes: customAttributes,
        relativeVirtualAddress: rva,
        methodImport: methodImport,
        genericParameters: genericParameters
    )
}

func adaptMethodSignature(index: TypeIndex, fileIdx: Int64, sig: MethodSignature): MethodSignatureRecord {
    let returnType = adaptType(index, fileIdx, sig.returnType)
    let parameters = ArrayList<SignatureRecord>()
    for (p in sig.paramTypes) {
        parameters.add(adaptType(index, fileIdx, p))
    }
    let header = buildSignatureHeader(sig)
    return MethodSignatureRecord(
        returnType,
        parameters: parameters,
        requiredParameterCount: Int64(sig.paramTypes.size),
        genericParameterCount: sig.genericParamCount,
        header: header
    )
}

// Reconstruct the C# JsSignatureHeader fields from the raw calling-convention
// flags byte (ECMA-335 §II.23.2.3). The low nibble selects the kind; bit 0x10
// is GENERIC, 0x20 is HASTHIS, 0x40 is EXPLICITTHIS.
func buildSignatureHeader(sig: MethodSignature): HashMap<String, JsonValue> {
    let flags = Int64(sig.flags)
    let kindBits = flags & 0x0F
    let isGeneric = (flags & 0x10) != 0
    let hasThis = (flags & 0x20) != 0
    let explicitThis = (flags & 0x40) != 0

    let callingConvention = match (kindBits) {
        case 0x00 => "Default"
        case 0x01 => "CDecl"
        case 0x02 => "StdCall"
        case 0x03 => "ThisCall"
        case 0x04 => "FastCall"
        case 0x05 => "VarArgs"
        case 0x09 => "Unmanaged"
        case _ => "Default"
    }

    // The C# SignatureHeader.Kind is "Method" for a MethodDefSig/MethodRefSig,
    // "Property" for a property signature; method signatures here are always
    // "Method".
    let kind = if (kindBits == 0x08) {
        "Property"
    } else {
        "Method"
    }

    // SignatureHeader.Attributes is the calling-convention attribute flags
    // formatted via .ToString().Split(", "). For these signatures it renders
    // "Instance" when HASTHIS is set, "ExplicitThis" when set, "Generic" when
    // set, else "None".
    let attributeNames = ArrayList<String>()
    if (hasThis) {
        attributeNames.add("Instance")
    }
    if (explicitThis) {
        attributeNames.add("ExplicitThis")
    }
    if (isGeneric) {
        attributeNames.add("Generic")
    }
    if (attributeNames.isEmpty()) {
        attributeNames.add("None")
    }
    let attributeValues = ArrayList<JsonValue>()
    for (a in attributeNames) {
        attributeValues.add(JsonString(a))
    }

    let header = HashMap<String, JsonValue>()
    header.add("Attributes", JsonArray(attributeValues))
    header.add("CallingConvention", JsonString(callingConvention))
    header.add("HasExplicitThis", JsonBool(explicitThis))
    header.add("IsGeneric", JsonBool(isGeneric))
    header.add("IsInstance", JsonBool(hasThis))
    header.add("Kind", JsonString(kind))
    return header
}

// --- Parameters ---

func adaptParameters(index: TypeIndex, fileIdx: Int64, methodRow: Int64): ArrayList<ParameterRecord> {
    let result = ArrayList<ParameterRecord>()
    let (pStart, pEnd) = index.methodDefParams(fileIdx, methodRow)
    var pi = pStart
    while (pi < pEnd) {
        result.add(adaptParameter(index, fileIdx, pi))
        pi += 1
    }
    return result
}

func adaptParameter(index: TypeIndex, fileIdx: Int64, paramRow: Int64): ParameterRecord {
    let name = index.paramName(fileIdx, paramRow)
    let sequenceNumber = Int64(index.paramSequence(fileIdx, paramRow))
    let flags = index.paramFlags(fileIdx, paramRow)
    let attributes = parameterAttributesToStrings(UInt32(flags.value))
    let customAttributes = adaptCustomAttributes(index, fileIdx, TABLE_METHOD_PARAM, paramRow)

    let defaultValue = safeConstantJson(index, fileIdx, TABLE_METHOD_PARAM, paramRow)

    return ParameterRecord(
        name,
        sequenceNumber: sequenceNumber,
        attributes: attributes,
        customAttributes: customAttributes,
        defaultValue: defaultValue
    )
}

// --- Method import (P/Invoke) ---

func adaptMethodImport(index: TypeIndex, fileIdx: Int64, methodRow: Int64): Option<MethodImportRecord> {
    match (index.methodDefImplMap(fileIdx, methodRow)) {
        case Some((flags, importName, moduleName)) =>
            let attributes = pinvokeAttributesToStrings(UInt32(flags.value))
            let moduleRef = ModuleReferenceRecord(moduleName)
            return Some(MethodImportRecord(
                importName,
                moduleName,
                moduleReference: Some(moduleRef),
                attributes: attributes
            ))
        case None => return None
    }
}

// --- Generic parameters ---

func adaptTypeGenericParameters(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<GenericParameterRecord> {
    let (start, end) = index.typeDefGenericParams(fileIdx, row)
    return adaptGenericParameterRange(index, fileIdx, start, end)
}

func adaptMethodGenericParameters(index: TypeIndex, fileIdx: Int64, methodRow: Int64): ArrayList<GenericParameterRecord> {
    let (start, end) = index.methodGenericParams(fileIdx, methodRow)
    return adaptGenericParameterRange(index, fileIdx, start, end)
}

func adaptGenericParameterRange(index: TypeIndex, fileIdx: Int64, start: Int64, end: Int64): ArrayList<GenericParameterRecord> {
    let result = ArrayList<GenericParameterRecord>()
    let file = index.getFile(fileIdx)
    var gi = start
    while (gi < end) {
        let name = index.genericParamName(fileIdx, gi)
        let sequence = Int64(index.genericParamSequence(fileIdx, gi))
        let attrValue = UInt32(UInt16(file.getUInt(gi, TABLE_GENERIC_PARAM, 1)))
        let attributes = genericParameterAttributesToStrings(attrValue)
        let customAttributes = adaptCustomAttributes(index, fileIdx, TABLE_GENERIC_PARAM, gi)
        let constraints = adaptGenericParameterConstraints(index, fileIdx, gi)
        result.add(GenericParameterRecord(
            name,
            sequenceNumber: sequence,
            index: Some(sequence),
            attributes: attributes,
            customAttributes: customAttributes,
            constraints: constraints
        ))
        gi += 1
    }
    return result
}

// Generic-parameter constraints. The C# output renders each constraint as a
// JsEntityHandle (Kind + TypeReference/TypeDefinition/TypeSpecification). We
// reproduce that entity-handle shape as a JsonValue object.
func adaptGenericParameterConstraints(index: TypeIndex, fileIdx: Int64, genericParamRow: Int64): ArrayList<JsonValue> {
    let result = ArrayList<JsonValue>()
    let file = index.getFile(fileIdx)
    for ((table, row) in index.genericParamConstraints(fileIdx, genericParamRow)) {
        result.add(entityHandleJson(file, table, row))
    }
    return result
}

// --- Interface implementations ---

func adaptInterfaceImplementations(index: TypeIndex, fileIdx: Int64, row: Int64, generics: Array<MetadataType>): ArrayList<InterfaceImplementationRecord> {
    let result = ArrayList<InterfaceImplementationRecord>()
    let file = index.getFile(fileIdx)
    let (start, end) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = start
    while (ii < end) {
        let coded = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
        let (table, targetRow) = decodeCodedIndex(coded, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)
        let interfaceSignature = entityHandleSignature(index, file, fileIdx, table, targetRow, generics)
        let customAttributes = adaptCustomAttributes(index, fileIdx, TABLE_INTERFACE_IMPL, ii)
        result.add(InterfaceImplementationRecord(
            interfaceSignature: Some(interfaceSignature),
            customAttributes: customAttributes
        ))
        ii += 1
    }
    return result
}

// Build a SignatureRecord shaped like a JsEntityHandle for the InterfaceImpl
// `Interface` field. Kind is TypeReference/TypeDefinition/TypeSpecification with
// the matching member populated. `generics` supplies the declaring type's
// VAR substitutes for TypeSpec signatures.
func entityHandleSignature(index: TypeIndex, file: WinmdFile, fileIdx: Int64, table: Int64, row: Int64, generics: Array<MetadataType>): SignatureRecord {
    if (table == TABLE_TYPE_REF) {
        let ns = file.getString(row, TABLE_TYPE_REF, 2)
        let nm = file.getString(row, TABLE_TYPE_REF, 1)
        return SignatureRecord("TypeReference", typeReference: Some(MetadataTypeRecord(nm, ns)))
    }
    if (table == TABLE_TYPE_DEF) {
        let ns = file.getString(row, TABLE_TYPE_DEF, 2)
        let nm = file.getString(row, TABLE_TYPE_DEF, 1)
        return SignatureRecord("TypeDefinition", typeDefinition: Some(MetadataTypeRecord(nm, ns)))
    }
    if (table == TABLE_TYPE_SPEC) {
        var specBlob = file.getBlob(row, TABLE_TYPE_SPEC, 0)
        let specType = specBlob.readTypeCode(file, generics)
        let specSig = adaptType(index, fileIdx, specType)
        let specRecord = TypeSpecificationRecord(specSig)
        return SignatureRecord("TypeSpecification", typeSpecification: Some(specRecord))
    }
    return SignatureRecord("TypeReference")
}

// JsonValue form of an entity handle (used for generic-parameter constraints).
func entityHandleJson(file: WinmdFile, table: Int64, row: Int64): JsonValue {
    let obj = JsonObject()
    if (table == TABLE_TYPE_REF) {
        obj.put("Kind", JsonString("TypeReference"))
        let inner = JsonObject()
        inner.put("Name", JsonString(file.getString(row, TABLE_TYPE_REF, 1)))
        inner.put("Namespace", JsonString(file.getString(row, TABLE_TYPE_REF, 2)))
        obj.put("TypeReference", inner)
        obj.put("TypeDefinition", JsonNull())
        obj.put("TypeSpecification", JsonNull())
    } else if (table == TABLE_TYPE_DEF) {
        obj.put("Kind", JsonString("TypeDefinition"))
        obj.put("TypeReference", JsonNull())
        let inner = JsonObject()
        inner.put("Name", JsonString(file.getString(row, TABLE_TYPE_DEF, 1)))
        inner.put("Namespace", JsonString(file.getString(row, TABLE_TYPE_DEF, 2)))
        obj.put("TypeDefinition", inner)
        obj.put("TypeSpecification", JsonNull())
    } else {
        obj.put("Kind", JsonString("TypeSpecification"))
        obj.put("TypeReference", JsonNull())
        obj.put("TypeDefinition", JsonNull())
        obj.put("TypeSpecification", JsonNull())
    }
    return obj
}

// --- Events ---

func adaptEvents(index: TypeIndex, fileIdx: Int64, row: Int64, generics: Array<MetadataType>): ArrayList<EventRecord> {
    let result = ArrayList<EventRecord>()
    let file = index.getFile(fileIdx)
    let (start, end) = index.typeDefEvents(fileIdx, row)
    var ei = start
    while (ei < end) {
        let name = index.eventName(fileIdx, ei)
        let flags = index.eventFlags(fileIdx, ei)
        let attributes = eventAttributesToStrings(UInt32(flags))
        let customAttributes = adaptCustomAttributes(index, fileIdx, TABLE_EVENT, ei)
        // Event type is a TypeDefOrRef coded index → render as an entity-handle
        // signature (matches C# JsEntityHandle on the `Type` member).
        let (etTable, etRow) = index.eventType(fileIdx, ei)
        let typeSig = if (etTable < 0) {
            SignatureRecord("TypeReference")
        } else {
            entityHandleSignature(index, file, fileIdx, etTable, etRow, generics)
        }
        let (adder, remover, raiser, others) = index.eventAccessors(fileIdx, ei)
        let accessors = HashMap<String, JsonValue>()
        accessors.add("Adder", optionalStringJson(adder))
        accessors.add("Raiser", optionalStringJson(raiser))
        accessors.add("Remover", optionalStringJson(remover))
        accessors.add("Others", stringListJson(others))
        result.add(EventRecord(
            name,
            typeSig,
            attributes: attributes,
            customAttributes: customAttributes,
            accessors: accessors
        ))
        ei += 1
    }
    return result
}

// --- Properties ---

func adaptProperties(index: TypeIndex, fileIdx: Int64, row: Int64, generics: Array<MetadataType>): ArrayList<PropertyRecord> {
    let result = ArrayList<PropertyRecord>()
    let file = index.getFile(fileIdx)
    let (start, end) = index.typeDefProperties(fileIdx, row)
    var pi = start
    while (pi < end) {
        let name = index.propertyName(fileIdx, pi)
        let flags = index.propertyFlags(fileIdx, pi)
        let attributes = propertyAttributesToStrings(UInt32(flags))
        let customAttributes = adaptCustomAttributes(index, fileIdx, TABLE_PROPERTY, pi)
        // Re-read with type generics so property VAR references resolve to names
        // (index.propertySignature passes an empty generics array).
        var propBlob = file.getBlob(pi, TABLE_PROPERTY, 2)
        let sig = propBlob.readMethodSignature(file, generics)
        let signature = adaptMethodSignature(index, fileIdx, sig)
        let (getter, setter, others) = index.propertyAccessors(fileIdx, pi)
        let accessors = HashMap<String, JsonValue>()
        accessors.add("Getter", optionalStringJson(getter))
        accessors.add("Setter", optionalStringJson(setter))
        accessors.add("Others", stringListJson(others))
        result.add(PropertyRecord(
            name,
            signature,
            attributes: attributes,
            customAttributes: customAttributes,
            accessors: accessors
        ))
        pi += 1
    }
    return result
}

// --- Custom attributes ---

func adaptCustomAttributes(index: TypeIndex, fileIdx: Int64, table: Int64, row: Int64): ArrayList<CustomAttributeRecord> {
    let result = ArrayList<CustomAttributeRecord>()
    let attrRows = index.getAttributesFor(table, fileIdx, row)
    for (attrRow in attrRows) {
        result.add(adaptCustomAttribute(index, fileIdx, attrRow))
    }
    return result
}

func adaptCustomAttribute(index: TypeIndex, fileIdx: Int64, attrRow: Int64): CustomAttributeRecord {
    let ns = index.attributeNamespace(fileIdx, attrRow)
    let nm = index.attributeName(fileIdx, attrRow)
    let typeName = qualifiedName(ns, nm)
    let args = decodeAttributeArgsSafe(index, fileIdx, attrRow)

    let fixedArguments = ArrayList<CustomAttributeFixedArgumentRecord>()
    let namedArguments = ArrayList<CustomAttributeNamedArgumentRecord>()
    for (arg in args) {
        let typeSig = adaptType(index, fileIdx, arg.ty)
        let value = customAttributeValueToJson(arg.ty, arg.value)
        match (arg.kind) {
            case None =>
                fixedArguments.add(CustomAttributeFixedArgumentRecord(typeSig, value: value))
            case Some(kind) =>
                let kindName = match (kind) {
                    case NamedArgKind.Field => "Field"
                    case NamedArgKind.Property => "Property"
                }
                namedArguments.add(CustomAttributeNamedArgumentRecord(arg.name, typeSig, kindName, value: value))
        }
    }
    return CustomAttributeRecord(typeName, fixedArguments: fixedArguments, namedArguments: namedArguments)
}

// Decode a custom attribute's arguments without the engine's checked Int32/Int64
// casts (the engine's readMetadataValue overflows on I4/I8 values whose sign bit
// is set, e.g. InvalidHandleValueAttribute(-1)). We reuse the engine's safe
// signature-type reader (it only reads element-type codes, never values) to get
// the constructor parameter types, then decode the value blob ourselves with
// unsigned-safe primitive reads.
func decodeAttributeArgsSafe(index: TypeIndex, fileIdx: Int64, attrRow: Int64): ArrayList<CustomAttributeArg> {
    let file = index.getFile(fileIdx)
    let signature = attributeCtorSignature(file, attrRow)
    var blob = file.getBlob(attrRow, TABLE_ATTRIBUTE, 2)

    let values = ArrayList<CustomAttributeArg>()
    let prolog = blob.readU16()
    if (prolog != 1u16) {
        // Unexpected prolog: fall back to no decoded args (matches a defensive
        // empty result rather than corrupting the stream).
        return values
    }
    for (ty in signature.paramTypes) {
        values.add(CustomAttributeArg("", None, ty, readAttributeValueSafe(blob, file, ty)))
    }
    let namedArgCount = blob.readU16()
    var i: Int64 = 0
    while (i < Int64(namedArgCount)) {
        let kindByte = blob.readU8()
        let kind = match (kindByte) {
            case 0x53u8 => NamedArgKind.Field
            case 0x54u8 => NamedArgKind.Property
            case _ => return values
        }
        let ty = blob.readTypeCode(file, Array<MetadataType>())
        let name = blob.readUtf8()
        let value = readAttributeValueSafe(blob, file, ty)
        values.add(CustomAttributeArg(name, Some(kind), ty, value))
        i += 1
    }
    return values
}

// Resolve the custom-attribute constructor's MethodSignature (param types only)
// using public engine APIs. The constructor is a MethodDef or MemberRef coded by
// the CustomAttributeType index in TABLE_ATTRIBUTE column 1.
func attributeCtorSignature(file: WinmdFile, attrRow: Int64): MethodSignature {
    let coded = file.getUInt(attrRow, TABLE_ATTRIBUTE, 1)
    let (table, row) = decodeCodedIndex(coded, CODED_CUSTOM_ATTRIBUTE_TYPE_BITS, CODED_CUSTOM_ATTRIBUTE_TYPE_MAP)
    if (table == TABLE_METHOD_DEF) {
        var blob = file.getBlob(row, TABLE_METHOD_DEF, 4)
        return blob.readMethodSignature(file, Array<MetadataType>())
    }
    if (table == TABLE_MEMBER_REF) {
        var blob = file.getBlob(row, TABLE_MEMBER_REF, 2)
        return blob.readMethodSignature(file, Array<MetadataType>())
    }
    throw Exception("unsupported custom attribute constructor table: ${table}")
}

// Read one custom-attribute argument value of the given declared type using
// unsigned-safe primitive reads. Mirrors the engine's readMetadataValue but
// without the checked Int32/Int64 casts that overflow on sign-bit-set values.
func readAttributeValueSafe(blob: BlobReader, file: WinmdFile, ty: MetadataType): MetadataValue {
    match (ty) {
        case MetadataType.Boolean => return MetadataValue.ValBool(blob.readU8() != 0u8)
        case MetadataType.Char => return MetadataValue.ValU16(blob.readU16())
        case MetadataType.I8 => return MetadataValue.ValI8(signedI8(blob.readU8()))
        case MetadataType.U8 => return MetadataValue.ValU8(blob.readU8())
        case MetadataType.I16 => return MetadataValue.ValI16(signedI16(blob.readU16()))
        case MetadataType.U16 => return MetadataValue.ValU16(blob.readU16())
        case MetadataType.I32 => return MetadataValue.ValI32(signedI32Value(blob.readU32()))
        case MetadataType.U32 => return MetadataValue.ValU32(blob.readU32())
        case MetadataType.I64 => return MetadataValue.ValI64(reinterpretI64(blob.readU64()))
        case MetadataType.U64 => return MetadataValue.ValU64(blob.readU64())
        case MetadataType.F32 => return MetadataValue.ValF32(blob.readF32())
        case MetadataType.F64 => return MetadataValue.ValF64(blob.readF64())
        case MetadataType.MdString => return MetadataValue.ValUtf8(blob.readUtf8())
        case MetadataType.ClassName(tn) =>
            if (tn.matches("System", "Type")) {
                let s = blob.readUtf8()
                return MetadataValue.ValTypeName(splitLastDot(s))
            }
            return MetadataValue.ValEnum(tn, readEnumUnderlyingSafe(blob, file, tn))
        case MetadataType.ValueName(tn) =>
            return MetadataValue.ValEnum(tn, readEnumUnderlyingSafe(blob, file, tn))
        case _ =>
            // Fallback: read a 4-byte value as an unsigned int (best effort).
            return MetadataValue.ValU32(blob.readU32())
    }
}

// Resolve and read an enum-typed argument using its underlying width, unsigned-safe.
func readEnumUnderlyingSafe(blob: BlobReader, file: WinmdFile, tn: TypeName): MetadataValue {
    let underlying = match (file.enumUnderlyingType(tn.namespace, trimTick(tn.name))) {
        case Some(ty) => ty
        case None => MetadataType.I32
    }
    match (underlying) {
        case MetadataType.Boolean => return MetadataValue.ValBool(blob.readU8() != 0u8)
        case MetadataType.Char => return MetadataValue.ValU16(blob.readU16())
        case MetadataType.I8 => return MetadataValue.ValI8(signedI8(blob.readU8()))
        case MetadataType.U8 => return MetadataValue.ValU8(blob.readU8())
        case MetadataType.I16 => return MetadataValue.ValI16(signedI16(blob.readU16()))
        case MetadataType.U16 => return MetadataValue.ValU16(blob.readU16())
        case MetadataType.I32 => return MetadataValue.ValI32(signedI32Value(blob.readU32()))
        case MetadataType.U32 => return MetadataValue.ValU32(blob.readU32())
        case MetadataType.I64 => return MetadataValue.ValI64(reinterpretI64(blob.readU64()))
        case MetadataType.U64 => return MetadataValue.ValU64(blob.readU64())
        case _ => return MetadataValue.ValI32(signedI32Value(blob.readU32()))
    }
}

func signedI32Value(value: UInt32): Int32 {
    // Reinterpret the bit pattern without a checked cast.
    if (value >= 0x8000_0000u32) {
        return Int32(Int64(value) - 0x1_0000_0000)
    }
    return Int32(value)
}

// Signed reinterprets of byte / short, avoiding the engine's checked Int8/Int16
// casts which throw when the high bit is set.
func signedI8(value: UInt8): Int8 {
    if (value >= 0x80u8) {
        return Int8(Int64(value) - 0x100)
    }
    return Int8(value)
}

func signedI16(value: UInt16): Int16 {
    if (value >= 0x8000u16) {
        return Int16(Int64(value) - 0x1_0000)
    }
    return Int16(value)
}

func signedI8Value(value: UInt8): Int64 {
    if (value >= 0x80u8) {
        return Int64(value) - 0x100
    }
    return Int64(value)
}

func signedI16Value(value: UInt16): Int64 {
    if (value >= 0x8000u16) {
        return Int64(value) - 0x1_0000
    }
    return Int64(value)
}

func reinterpretI64(value: UInt64): Int64 {
    if (value > UInt64(Int64.Max)) {
        // Two's-complement reinterpret: v - 2^64.
        return Int64(value - 0x8000_0000_0000_0000u64) + Int64.Min
    }
    return Int64(value)
}

func splitLastDot(s: String): TypeName {
    let arr = s.toArray()
    var lastDot: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'.') {
            lastDot = i
        }
        i += 1
    }
    if (lastDot >= 0) {
        return TypeName.named(String.fromUtf8(arr[0..lastDot]), String.fromUtf8(arr[lastDot + 1..Int64(arr.size)]))
    }
    return TypeName.named("", s)
}

// --- Supported architectures / OS platform / experimental ---

func adaptSupportedArchitectures(index: TypeIndex, fileIdx: Int64, row: Int64): ArrayList<String> {
    let result = ArrayList<String>()
    match (index.findAttribute(TABLE_TYPE_DEF, fileIdx, row, "SupportedArchitectureAttribute")) {
        case Some(attrRow) =>
            let values = decodeAttributeArgsSafe(index, fileIdx, attrRow)
            if (!values.isEmpty()) {
                let arch = architectureIntFromValue(values[0].value)
                // Architecture.None (0) → empty list.
                if (arch == 0) {
                    return result
                }
                if ((arch & 1) != 0) {
                    result.add("X86")
                }
                if ((arch & 2) != 0) {
                    result.add("X64")
                }
                if ((arch & 4) != 0) {
                    result.add("Arm64")
                }
                return result
            }
            // Attribute present but no usable arg → fall through to "all".
        case None => ()
    }
    // No SupportedArchitectureAttribute → applies to all three architectures.
    result.add("X86")
    result.add("X64")
    result.add("Arm64")
    return result
}

func architectureIntFromValue(value: MetadataValue): Int64 {
    match (value) {
        case MetadataValue.ValI32(v) => return Int64(v)
        case MetadataValue.ValU32(v) => return Int64(v)
        case MetadataValue.ValEnum(_, inner) => return architectureIntFromValue(inner)
        case _ => return 0
    }
}

func adaptSupportedOsPlatform(index: TypeIndex, fileIdx: Int64, row: Int64): Option<String> {
    // The C# tool matches ONLY the System.Runtime.Versioning variant; the
    // Windows.Win32.Foundation.Metadata.SupportedOSPlatformAttribute is left out
    // of this field (it still appears under CustomAttributes).
    for (attrRow in index.getAttributesFor(TABLE_TYPE_DEF, fileIdx, row)) {
        let ns = index.attributeNamespace(fileIdx, attrRow)
        let nm = index.attributeName(fileIdx, attrRow)
        if (ns == "System.Runtime.Versioning" && nm == "SupportedOSPlatformAttribute") {
            let values = decodeAttributeArgsSafe(index, fileIdx, attrRow)
            for (arg in values) {
                match (arg.value) {
                    case MetadataValue.ValUtf8(s) => return Some(s)
                    case MetadataValue.ValUtf16(s) => return Some(s)
                    case _ => ()
                }
            }
            return None
        }
    }
    return None
}

func adaptIsExperimental(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    return index.hasAttribute(TABLE_TYPE_DEF, fileIdx, row, "ExperimentalAttribute")
}

// --- MetadataType -> SignatureRecord ---

// Convert a parsed MetadataType into the SignatureRecord shape the C# tool emits.
func adaptType(index: TypeIndex, fileIdx: Int64, ty: MetadataType): SignatureRecord {
    match (ty) {
        case MetadataType.Void => return primitive("Void")
        case MetadataType.Boolean => return primitive("Boolean")
        case MetadataType.Char => return primitive("Char")
        case MetadataType.I8 => return primitive("SByte")
        case MetadataType.U8 => return primitive("Byte")
        case MetadataType.I16 => return primitive("Int16")
        case MetadataType.U16 => return primitive("UInt16")
        case MetadataType.I32 => return primitive("Int32")
        case MetadataType.U32 => return primitive("UInt32")
        case MetadataType.I64 => return primitive("Int64")
        case MetadataType.U64 => return primitive("UInt64")
        case MetadataType.F32 => return primitive("Single")
        case MetadataType.F64 => return primitive("Double")
        case MetadataType.ISize => return primitive("IntPtr")
        case MetadataType.USize => return primitive("UIntPtr")
        case MetadataType.MdString => return primitive("String")
        case MetadataType.MdObject => return primitive("Object")
        case MetadataType.ClassName(tn) => return adaptNamedType(index, fileIdx, tn)
        case MetadataType.ValueName(tn) => return adaptNamedType(index, fileIdx, tn)
        case MetadataType.Union(tn) => return adaptNamedType(index, fileIdx, tn)
        case MetadataType.Generic(name, _) =>
            return SignatureRecord("GenericParameter", name: name)
        case MetadataType.MdArray(inner) =>
            return SignatureRecord("SZArray", typeSig: Some(adaptType(index, fileIdx, inner)))
        case MetadataType.RefMut(inner) =>
            // The reference golden serializes a BYREF as Kind="Reference".
            return SignatureRecord("Reference", typeSig: Some(adaptType(index, fileIdx, inner)))
        case MetadataType.RefConst(inner) =>
            // The engine folds a CMOD_OPT(IsConst) + BYREF on a non-pointer type
            // into RefConst (a `const T&`). The reference C# tool serializes this
            // as a Modified wrapper: an IsConst modifier over a Reference to the
            // inner type. The modifier *type* is recoverable — it is always
            // System.Runtime.CompilerServices.IsConst, which is exactly what the
            // engine matched to set the const flag. Reconstruct the full wrapper
            // so both the emitted JSON and the generated Cangjie ABI (a by-ref
            // pointer slot) match the golden exactly. Folding to the bare inner
            // type would drop the by-reference, producing a wrong by-value vtable
            // ABI (e.g. IGuidHelperStatics.Equals takes `const Guid&`, which must
            // be a pointer slot, not a by-value GUID).
            let referenceSig = SignatureRecord(
                "Reference",
                typeSig: Some(adaptType(index, fileIdx, inner))
            )
            return SignatureRecord(
                "Modified",
                modifierType: Some(typeRecord("System.Runtime.CompilerServices", "IsConst")),
                unmodifiedType: Some(referenceSig),
                isRequired: Some(false)
            )
        case MetadataType.PtrMut(inner, depth) =>
            return pointerChain(index, fileIdx, inner, depth)
        case MetadataType.PtrConst(inner, depth) =>
            return pointerChain(index, fileIdx, inner, depth)
        case MetadataType.ArrayFixed(inner, size) =>
            return arrayShaped(index, fileIdx, inner, 1, [size], [0])
        case MetadataType.ArrayShaped(inner, rank, sizes, lowerBounds) =>
            return arrayShaped(index, fileIdx, inner, rank, sizes, lowerBounds)
        case MetadataType.Packed(inner, _) =>
            return adaptType(index, fileIdx, inner)
        case MetadataType.Pinned(inner) =>
            return SignatureRecord("Pinned", typeSig: Some(adaptType(index, fileIdx, inner)))
        case MetadataType.FnPtr(sig) =>
            // FunctionPointer carries a method signature in the C# output.
            // The signature is exposed via the model's typeSpecification slot is
            // not appropriate; instead nest the method signature inside a Type
            // child is not how C# does it. C# emits Kind="FunctionPointer" with a
            // Signature sub-object. The model has no Signature slot on
            // SignatureRecord, so we approximate with the bare kind. (See report.)
            let _ = sig
            return SignatureRecord("FunctionPointer")
    }
}

func primitive(name: String): SignatureRecord {
    return SignatureRecord("Primitive", name: name)
}

// A named type. When the TypeName carries generic arguments it is an
// instantiated generic and the C# tool emits Kind="Generic" with a Type child
// (Kind="Type") and TypeArguments. Otherwise it is a plain Kind="Type".
func adaptNamedType(index: TypeIndex, fileIdx: Int64, tn: TypeName): SignatureRecord {
    if (tn.generics.isEmpty()) {
        return typeRecord(tn.namespace, tn.name)
    }
    // Generic instantiation. The base type retains its backtick-suffixed name.
    let base = typeRecord(tn.namespace, tn.name)
    let typeArguments = ArrayList<SignatureRecord>()
    for (arg in tn.generics) {
        typeArguments.add(adaptType(index, fileIdx, arg))
    }
    return SignatureRecord("Generic", typeSig: Some(base), typeArguments: typeArguments)
}

// A Kind="Type" record with namespace/name and the source-marker Comment.
//
// The engine does not preserve whether the original coded index pointed at a
// TypeDef or a TypeRef, so we emit the dominant "TypeReference" marker. (See
// report — this requires an engine change to resolve precisely.)
func typeRecord(namespace: String, name: String): SignatureRecord {
    return SignatureRecord(
        "Type",
        name: name,
        namespace: namespace,
        hasNamespace: true,
        comment: "TypeReference"
    )
}

// Build a nested Pointer chain `depth` levels deep wrapping the inner type.
func pointerChain(index: TypeIndex, fileIdx: Int64, inner: MetadataType, depth: Int64): SignatureRecord {
    var current = adaptType(index, fileIdx, inner)
    var i: Int64 = 0
    while (i < depth) {
        current = SignatureRecord("Pointer", typeSig: Some(current))
        i += 1
    }
    return current
}

func arrayShaped(
    index: TypeIndex,
    fileIdx: Int64,
    inner: MetadataType,
    rank: Int64,
    sizes: Array<Int64>,
    lowerBounds: Array<Int64>
): SignatureRecord {
    let sizeList = ArrayList<Int64>()
    for (s in sizes) {
        sizeList.add(s)
    }
    let lowerList = ArrayList<Int64>()
    for (l in lowerBounds) {
        lowerList.add(l)
    }
    return SignatureRecord(
        "Array",
        typeSig: Some(adaptType(index, fileIdx, inner)),
        lowerBounds: Some(lowerList),
        rank: Some(rank),
        sizes: Some(sizeList)
    )
}

// --- MetadataValue -> JsonValue (with ToCustomValue special-casing) ---

// ELEMENT_TYPE codes needed for safe constant decoding (the engine's BlobReader
// readI32 performs a checked Int32 cast that overflows on U32 constants whose
// high bit is set, so we decode constants here using unsigned reads).
let ET_BOOLEAN: Int64 = 2
let ET_CHAR: Int64 = 3
let ET_I1: Int64 = 4
let ET_U1: Int64 = 5
let ET_I2: Int64 = 6
let ET_U2: Int64 = 7
let ET_I4: Int64 = 8
let ET_U4: Int64 = 9
let ET_I8: Int64 = 10
let ET_U8: Int64 = 11
let ET_R4: Int64 = 12
let ET_R8: Int64 = 13
let ET_STRING: Int64 = 14
let ET_CLASS: Int64 = 18

// Look up the Constant row for a Field/Param and decode it into a JsConstant
// JsonValue { TypeCode, Value }, or None when no constant exists. `parentTable`
// is TABLE_FIELD or TABLE_METHOD_PARAM.
func safeConstantJson(index: TypeIndex, fileIdx: Int64, parentTable: Int64, parentRow: Int64): Option<JsonValue> {
    let file = index.getFile(fileIdx)
    let tag = if (parentTable == TABLE_FIELD) {
        0
    } else {
        1 // Param
    }
    let encoded = encodeCodedIndex(tag, parentRow, CODED_HAS_CONSTANT_BITS)
    let (start, end) = file.equalRange(TABLE_CONSTANT, 1, encoded)
    if (start >= end) {
        return None
    }
    let typeCode = file.getUInt(start, TABLE_CONSTANT, 0) & 0xFF
    var blob = file.getBlob(start, TABLE_CONSTANT, 2)
    let (codeName, jsonValue) = decodeConstant(blob, typeCode)
    let obj = JsonObject()
    obj.put("TypeCode", JsonString(codeName))
    obj.put("Value", jsonValue)
    return Some(obj)
}

// Decode a constant blob of the given ELEMENT_TYPE into (TypeCode string, value).
// Integer values are read unsigned and widened to Int64 so the full UInt32 range
// is preserved; UInt64 values above Int64.Max become strings (C# normalizer).
func decodeConstant(blob: BlobReader, typeCode: Int64): (String, JsonValue) {
    if (typeCode == ET_BOOLEAN) {
        return ("Boolean", JsonBool(blob.readU8() != 0u8))
    }
    if (typeCode == ET_CHAR) {
        return ("Char", JsonInt(Int64(blob.readU16())))
    }
    if (typeCode == ET_I1) {
        return ("SByte", JsonInt(signedI8Value(blob.readU8())))
    }
    if (typeCode == ET_U1) {
        return ("Byte", JsonInt(Int64(blob.readU8())))
    }
    if (typeCode == ET_I2) {
        return ("Int16", JsonInt(signedI16Value(blob.readU16())))
    }
    if (typeCode == ET_U2) {
        return ("UInt16", JsonInt(Int64(blob.readU16())))
    }
    if (typeCode == ET_I4) {
        return ("Int32", JsonInt(Int64(signedI32(blob.readU32()))))
    }
    if (typeCode == ET_U4) {
        return ("UInt32", JsonInt(Int64(blob.readU32())))
    }
    if (typeCode == ET_I8) {
        return ("Int64", JsonInt(Int64(blob.readU64())))
    }
    if (typeCode == ET_U8) {
        let v = blob.readU64()
        if (v > UInt64(Int64.Max)) {
            return ("UInt64", JsonString("${v}"))
        }
        return ("UInt64", JsonInt(Int64(v)))
    }
    if (typeCode == ET_R4) {
        return ("Single", JsonFloat(Float64(blob.readF32())))
    }
    if (typeCode == ET_R8) {
        return ("Double", JsonFloat(blob.readF64()))
    }
    if (typeCode == ET_STRING) {
        return ("String", JsonString(blob.readUtf16()))
    }
    if (typeCode == ET_CLASS) {
        // A null reference constant (ELEMENT_TYPE_CLASS) carries a 4-byte zero.
        return ("Object", JsonNull())
    }
    return ("Object", JsonNull())
}

// Reinterpret a UInt32 as a two's-complement Int64 (sign-extended Int32).
func signedI32(value: UInt32): Int64 {
    if (value >= 0x8000_0000u32) {
        return Int64(value) - 0x1_0000_0000
    }
    return Int64(value)
}

// A field/parameter Constant renders as a JsConstant: { TypeCode, Value }.
func constantToJson(constType: MetadataType, value: MetadataValue): JsonValue {
    let obj = JsonObject()
    obj.put("TypeCode", JsonString(constantTypeCode(constType)))
    obj.put("Value", scalarValueToJson(value))
    return obj
}

func constantTypeCode(ty: MetadataType): String {
    match (ty) {
        case MetadataType.Boolean => return "Boolean"
        case MetadataType.Char => return "Char"
        case MetadataType.I8 => return "SByte"
        case MetadataType.U8 => return "Byte"
        case MetadataType.I16 => return "Int16"
        case MetadataType.U16 => return "UInt16"
        case MetadataType.I32 => return "Int32"
        case MetadataType.U32 => return "UInt32"
        case MetadataType.I64 => return "Int64"
        case MetadataType.U64 => return "UInt64"
        case MetadataType.F32 => return "Single"
        case MetadataType.F64 => return "Double"
        case MetadataType.MdString => return "String"
        case _ => return "Object"
    }
}

// Custom-attribute argument value, applying the C# TypeProvider.ToCustomValue
// special-casing for well-known enum types (architecture flags, attribute
// targets, calling convention, System.Type). All other values pass through the
// raw scalar normalizer (ulong > Int64.Max becomes a string).
func customAttributeValueToJson(ty: MetadataType, value: MetadataValue): JsonValue {
    let typeName = metadataTypeFullName(ty)
    match (typeName) {
        case Some(name) =>
            if (name == "System.AttributeTargets") {
                return attributeTargetsArray(value, true)
            }
            if (name == "Windows.Foundation.Metadata.AttributeTargets") {
                return attributeTargetsArray(value, false)
            }
            if (name == "System.Runtime.InteropServices.CallingConvention") {
                return JsonString(callingConventionName(enumIntValue(value)))
            }
            if (name == "Windows.Foundation.Metadata.CompositionType") {
                return JsonString(compositionTypeName(enumIntValue(value)))
            }
            if (name == "Windows.Foundation.Metadata.DeprecationType") {
                return JsonString(deprecationTypeName(enumIntValue(value)))
            }
            if (name == "Windows.Foundation.Metadata.GCPressureAmount") {
                return JsonString(gcPressureAmountName(enumIntValue(value)))
            }
            if (name == "Windows.Foundation.Metadata.MarshalingType") {
                return JsonString(marshalingTypeName(enumIntValue(value)))
            }
            if (name == "Windows.Foundation.Metadata.ThreadingModel") {
                return JsonString(threadingModelName(enumIntValue(value)))
            }
            if (name == "Windows.Win32.Foundation.Metadata.Architecture" ||
                name == "Windows.Win32.Interop.Architecture") {
                return architectureArray(enumIntValue(value))
            }
            // System.Type values are decoded as a type-name string by the engine.
            return scalarValueToJson(value)
        case None =>
            return scalarValueToJson(value)
    }
}

// Map a MetadataType to "Namespace.Name" when it is a named (class/value) type.
func metadataTypeFullName(ty: MetadataType): Option<String> {
    match (ty) {
        case MetadataType.ClassName(tn) => return Some(qualifiedName(tn.namespace, tn.name))
        case MetadataType.ValueName(tn) => return Some(qualifiedName(tn.namespace, tn.name))
        case MetadataType.Union(tn) => return Some(qualifiedName(tn.namespace, tn.name))
        case _ => return None
    }
}

// Extract the integer payload from an enum/scalar value.
func enumIntValue(value: MetadataValue): Int64 {
    match (value) {
        case MetadataValue.ValEnum(_, inner) => return enumIntValue(inner)
        case MetadataValue.ValI8(v) => return Int64(v)
        case MetadataValue.ValU8(v) => return Int64(v)
        case MetadataValue.ValI16(v) => return Int64(v)
        case MetadataValue.ValU16(v) => return Int64(v)
        case MetadataValue.ValI32(v) => return Int64(v)
        case MetadataValue.ValU32(v) => return Int64(v)
        case MetadataValue.ValI64(v) => return v
        case MetadataValue.ValU64(v) => return Int64(v)
        case _ => return 0
    }
}

// Scalar value → JsonValue. UInt64 values exceeding Int64.Max are emitted as a
// string (JsonValueNormalizer.Normalize). Enum values that are not specially
// cased render as their raw underlying integer (ToCustomValue default path).
func scalarValueToJson(value: MetadataValue): JsonValue {
    match (value) {
        case MetadataValue.ValBool(v) => return JsonBool(v)
        case MetadataValue.ValU8(v) => return JsonInt(Int64(v))
        case MetadataValue.ValI8(v) => return JsonInt(Int64(v))
        case MetadataValue.ValU16(v) => return JsonInt(Int64(v))
        case MetadataValue.ValI16(v) => return JsonInt(Int64(v))
        case MetadataValue.ValU32(v) => return JsonInt(Int64(v))
        case MetadataValue.ValI32(v) => return JsonInt(Int64(v))
        case MetadataValue.ValI64(v) => return JsonInt(v)
        case MetadataValue.ValU64(v) =>
            if (v > UInt64(Int64.Max)) {
                return JsonString("${v}")
            }
            return JsonInt(Int64(v))
        case MetadataValue.ValF32(v) => return JsonFloat(Float64(v))
        case MetadataValue.ValF64(v) => return JsonFloat(v)
        case MetadataValue.ValUtf8(s) => return JsonString(s)
        case MetadataValue.ValUtf16(s) => return JsonString(s)
        case MetadataValue.ValTypeName(tn) => return JsonString(qualifiedName(tn.namespace, tn.name))
        case MetadataValue.ValEnum(_, inner) => return scalarValueToJson(inner)
    }
}

// Architecture flags → array of names (matches ((Architecture)val).ToString().Split(", ")).
func architectureArray(value: Int64): JsonValue {
    let names = ArrayList<JsonValue>()
    if (value == 0) {
        names.add(JsonString("None"))
        return JsonArray(names)
    }
    if ((value & 1) != 0) {
        names.add(JsonString("X86"))
    }
    if ((value & 2) != 0) {
        names.add(JsonString("X64"))
    }
    if ((value & 4) != 0) {
        names.add(JsonString("Arm64"))
    }
    return JsonArray(names)
}

// System.AttributeTargets → array; Windows.Foundation.Metadata.AttributeTargets
// (a non-Flags enum in the C# tool) → a single string. `isFlags` selects.
func attributeTargetsArray(value: MetadataValue, isFlags: Bool): JsonValue {
    let v = enumIntValue(value)
    if (isFlags) {
        return systemAttributeTargetsArray(v)
    }
    return JsonString(windowsAttributeTargetsName(v))
}

// System.AttributeTargets [Flags] enum member names in ascending value order.
func systemAttributeTargetsArray(value: Int64): JsonValue {
    // System.AttributeTargets.All == 32767; ToString() yields "All".
    if (value == 32767) {
        let all = ArrayList<JsonValue>()
        all.add(JsonString("All"))
        return JsonArray(all)
    }
    let members: Array<(String, Int64)> = [
        ("Assembly", 0x0001),
        ("Module", 0x0002),
        ("Class", 0x0004),
        ("Struct", 0x0008),
        ("Enum", 0x0010),
        ("Constructor", 0x0020),
        ("Method", 0x0040),
        ("Property", 0x0080),
        ("Field", 0x0100),
        ("Event", 0x0200),
        ("Interface", 0x0400),
        ("Parameter", 0x0800),
        ("Delegate", 0x1000),
        ("ReturnValue", 0x2000),
        ("GenericParameter", 0x4000)
    ]
    let names = ArrayList<JsonValue>()
    if (value == 0) {
        names.add(JsonString("0"))
        return JsonArray(names)
    }
    for ((name, bit) in members) {
        if ((value & bit) == bit) {
            names.add(JsonString(name))
        }
    }
    return JsonArray(names)
}

func windowsAttributeTargetsName(value: Int64): String {
    // The reference converter casts the raw value through the BCL
    // System.AttributeTargets enum and calls .ToString() (NOT the winmd
    // Windows.Foundation.Metadata.AttributeTargets member names), so e.g. a raw
    // value of 512 renders as "Event" (System.AttributeTargets.Event) rather
    // than "RuntimeClass". Reproduce the System.AttributeTargets .ToString().
    if (value == 32767) {
        return "All"
    }
    let members: Array<(Int64, String)> = [
        (0x0001, "Assembly"),
        (0x0002, "Module"),
        (0x0004, "Class"),
        (0x0008, "Struct"),
        (0x0010, "Enum"),
        (0x0020, "Constructor"),
        (0x0040, "Method"),
        (0x0080, "Property"),
        (0x0100, "Field"),
        (0x0200, "Event"),
        (0x0400, "Interface"),
        (0x0800, "Parameter"),
        (0x1000, "Delegate"),
        (0x2000, "ReturnValue"),
        (0x4000, "GenericParameter")
    ]
    if (value == 0) {
        return "0"
    }
    // System.AttributeTargets is a [Flags] enum; .ToString() joins matched
    // members with ", ". For these winmd usages the value is typically a single
    // flag, but join defensively to match the BCL formatter.
    let names = ArrayList<String>()
    var remaining = value
    for ((bit, name) in members) {
        if ((value & bit) == bit) {
            names.add(name)
            remaining &= !bit
        }
    }
    if (remaining != 0 || names.isEmpty()) {
        return "${value}"
    }
    return joinComma(names)
}

func callingConventionName(value: Int64): String {
    match (value) {
        case 1 => return "Winapi"
        case 2 => return "Cdecl"
        case 3 => return "StdCall"
        case 4 => return "ThisCall"
        case 5 => return "FastCall"
        case _ => return "${value}"
    }
}

func compositionTypeName(value: Int64): String {
    match (value) {
        case 1 => return "Protected"
        case 2 => return "Public"
        case _ => return "${value}"
    }
}

func deprecationTypeName(value: Int64): String {
    match (value) {
        case 0 => return "Deprecate"
        case 1 => return "Remove"
        case _ => return "${value}"
    }
}

func gcPressureAmountName(value: Int64): String {
    match (value) {
        case 0 => return "Low"
        case 1 => return "Medium"
        case 2 => return "High"
        case _ => return "${value}"
    }
}

func marshalingTypeName(value: Int64): String {
    match (value) {
        case 0 => return "InvalidMarshaling"
        case 1 => return "None"
        case 2 => return "Agile"
        case 3 => return "Standard"
        case _ => return "${value}"
    }
}

func threadingModelName(value: Int64): String {
    match (value) {
        case 0 => return "InvalidThreading"
        case 1 => return "STA"
        case 2 => return "MTA"
        case 3 => return "Both"
        case _ => return "${value}"
    }
}

// --- FormatType (for TypeSpec base types) ---

// Mirror the C# JsTypeDefinition.FormatType: flatten a type into the textual
// representation used for TypeSpec base types.
func formatType(ty: MetadataType): String {
    match (ty) {
        case MetadataType.Void => return "Void"
        case MetadataType.Boolean => return "Boolean"
        case MetadataType.Char => return "Char"
        case MetadataType.I8 => return "SByte"
        case MetadataType.U8 => return "Byte"
        case MetadataType.I16 => return "Int16"
        case MetadataType.U16 => return "UInt16"
        case MetadataType.I32 => return "Int32"
        case MetadataType.U32 => return "UInt32"
        case MetadataType.I64 => return "Int64"
        case MetadataType.U64 => return "UInt64"
        case MetadataType.F32 => return "Single"
        case MetadataType.F64 => return "Double"
        case MetadataType.ISize => return "IntPtr"
        case MetadataType.USize => return "UIntPtr"
        case MetadataType.MdString => return "String"
        case MetadataType.MdObject => return "Object"
        case MetadataType.ClassName(tn) => return formatNamedType(tn)
        case MetadataType.ValueName(tn) => return formatNamedType(tn)
        case MetadataType.Union(tn) => return formatNamedType(tn)
        case MetadataType.Generic(name, _) => return name
        case MetadataType.MdArray(inner) => return "${formatType(inner)}[]"
        case MetadataType.RefMut(inner) => return "${formatType(inner)}&"
        case MetadataType.RefConst(inner) => return formatType(inner)
        case MetadataType.PtrMut(inner, depth) => return "${formatType(inner)}${stars(depth)}"
        case MetadataType.PtrConst(inner, depth) => return "${formatType(inner)}${stars(depth)}"
        case MetadataType.ArrayFixed(inner, _) => return "${formatType(inner)}[]"
        case MetadataType.ArrayShaped(inner, rank, _, _) => return "${formatType(inner)}[${commas(rank)}]"
        case MetadataType.Packed(inner, _) => return formatType(inner)
        case MetadataType.Pinned(inner) => return "pinned ${formatType(inner)}"
        case MetadataType.FnPtr(_) => return "methodptr"
    }
}

func formatNamedType(tn: TypeName): String {
    let qualified = qualifiedName(tn.namespace, tn.name)
    if (tn.generics.isEmpty()) {
        return qualified
    }
    let parts = ArrayList<String>()
    for (g in tn.generics) {
        parts.add(formatType(g))
    }
    return "${qualified}[${joinComma(parts)}]"
}

func stars(depth: Int64): String {
    let builder = StringBuilder()
    var i: Int64 = 0
    while (i < depth) {
        builder.append("*")
        i += 1
    }
    return builder.toString()
}

func commas(rank: Int64): String {
    let count = if (rank - 1 > 0) {
        rank - 1
    } else {
        0
    }
    let builder = StringBuilder()
    var i: Int64 = 0
    while (i < count) {
        builder.append(",")
        i += 1
    }
    return builder.toString()
}

func joinComma(parts: ArrayList<String>): String {
    let builder = StringBuilder()
    var first = true
    for (p in parts) {
        if (!first) {
            builder.append(", ")
        }
        builder.append(p)
        first = false
    }
    return builder.toString()
}

// --- Small helpers ---

func optionalStringJson(value: Option<String>): JsonValue {
    match (value) {
        case Some(s) => return JsonString(s)
        case None => return JsonNull()
    }
}

func stringListJson(values: ArrayList<String>): JsonValue {
    let elements = ArrayList<JsonValue>()
    for (v in values) {
        elements.add(JsonString(v))
    }
    return JsonArray(elements)
}

// SHA-256 of the whole file as lowercase hex.
func sha256HexOfFile(path: String): String {
    let bytes = File.readFrom(path)
    let sha = SHA256()
    sha.write(bytes)
    let digest = sha.finish()
    return toHexString(digest).toAsciiLower()
}

// Extract the file name (last path component) from a full path.
func baseName(path: String): String {
    let arr = path.toArray()
    var lastSep: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'/' || arr[i] == b'\\') {
            lastSep = i
        }
        i += 1
    }
    if (lastSep < 0) {
        return path
    }
    return String.fromUtf8(arr[lastSep + 1..Int64(arr.size)])
}
