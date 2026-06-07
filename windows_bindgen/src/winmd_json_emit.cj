package windows_bindgen

import std.collection.*
import std.convert.*
import stdx.encoding.json.*

// winmd_json_emit.cj
//
// Serializes a WinmdFileRecord (the bindgen model) into a JSON document whose
// structure matches the reference C# winmd-to-json tool's schema exactly:
//
//   - The five top-level scalars use snake_case keys
//     (winmd_file / winmd_sha256 / tool_version / schema_version / source_set)
//     followed by a `types` array.
//   - Object keys inside each type / signature / member use PascalCase, emitted
//     in the same declaration order the C# `System.Text.Json` serializer uses.
//   - At the TType (signature) level, null sub-fields are OMITTED
//     (JsonIgnore WhenWritingNull). At the TypeDefinition / Field / Parameter
//     level, the C# DTO emits explicit `null` for absent values (BaseType,
//     DefaultValue, SupportedOsPlatform), so those keys ARE present with a JSON
//     null. This module reproduces both behaviors precisely.
//   - The output is pretty-printed with two-space indentation, and `<` / `>`
//     in strings are escaped as < / > (matching the C# writer's
//     default JavaScript-safe escaping for those characters).

// Render a WinmdFileRecord to the C#-schema JSON text.
public func emitWinmdJson(record: WinmdFileRecord): String {
    let builder = StringBuilder()
    builder.append("{\n")
    let indent = "  "
    appendStringField(builder, indent, "winmd_file", record.winmdFile, true)
    appendStringField(builder, indent, "winmd_sha256", record.winmdSha256, true)
    appendStringField(builder, indent, "tool_version", record.toolVersion, true)
    appendStringField(builder, indent, "schema_version", record.schemaVersion, true)
    appendStringField(builder, indent, "source_set", record.sourceSet, true)
    builder.append("${indent}\"types\": ")
    if (record.types.isEmpty()) {
        builder.append("[]\n")
    } else {
        builder.append("[\n")
        var i: Int64 = 0
        while (i < Int64(record.types.size)) {
            builder.append("${indent}  ")
            appendTypeDefinition(builder, "${indent}  ", record.types[i])
            if (i + 1 < Int64(record.types.size)) {
                builder.append(",")
            }
            builder.append("\n")
            i += 1
        }
        builder.append("${indent}]\n")
    }
    builder.append("}")
    return builder.toString()
}

// --- JSON value model used for fields that carry arbitrary JsonValue payloads ---

// A field entry: a PascalCase key plus either a rendered JSON value or a marker
// that the field should be skipped (omitted) entirely.
class JField {
    let key: String
    let value: String
    let skip: Bool

    init(key: String, value: String) {
        this.key = key
        this.value = value
        this.skip = false
    }

    init(key: String, skip!: Bool) {
        this.key = key
        this.value = ""
        this.skip = skip
    }
}

// Render an object from a list of pre-rendered fields at the given indentation.
// Fields flagged skip == true are omitted entirely.
func renderObject(fields: ArrayList<JField>, indent: String): String {
    let kept = ArrayList<JField>()
    for (f in fields) {
        if (!f.skip) {
            kept.add(f)
        }
    }
    if (kept.isEmpty()) {
        return "{}"
    }
    let builder = StringBuilder()
    builder.append("{\n")
    let inner = "${indent}  "
    var i: Int64 = 0
    while (i < Int64(kept.size)) {
        builder.append("${inner}\"${kept[i].key}\": ${kept[i].value}")
        if (i + 1 < Int64(kept.size)) {
            builder.append(",")
        }
        builder.append("\n")
        i += 1
    }
    builder.append("${indent}}")
    return builder.toString()
}

// Render an array of pre-rendered element strings.
func renderArray(elements: ArrayList<String>, indent: String): String {
    if (elements.isEmpty()) {
        return "[]"
    }
    let builder = StringBuilder()
    builder.append("[\n")
    let inner = "${indent}  "
    var i: Int64 = 0
    while (i < Int64(elements.size)) {
        builder.append("${inner}${elements[i]}")
        if (i + 1 < Int64(elements.size)) {
            builder.append(",")
        }
        builder.append("\n")
        i += 1
    }
    builder.append("${indent}]")
    return builder.toString()
}

func renderStringArray(values: ArrayList<String>, indent: String): String {
    let elements = ArrayList<String>()
    for (v in values) {
        elements.add(encodeJsonString(v))
    }
    return renderArray(elements, indent)
}

// --- Top-level TypeDefinition ---

func appendTypeDefinition(builder: StringBuilder, indent: String, td: TypeDefinitionRecord): Unit {
    builder.append(renderTypeDefinition(td, indent))
}

// The C# JsTypeDefinition serializes its properties in this declaration order:
//   Namespace, Name, BaseType, IsNested, Attributes, CustomAttributes, Fields,
//   InterfaceImplementations, Layout, Methods, NestedTypes, GenericParameters,
//   Events, Properties, SupportedArchitectures, SupportedOsPlatform,
//   IsExperimental, SourceSet
func renderTypeDefinition(td: TypeDefinitionRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Namespace", encodeJsonString(td.namespace)))
    fields.add(JField("Name", encodeJsonString(td.name)))
    // BaseType: explicit null when absent (DTO emits null).
    if (td.hasBaseType) {
        fields.add(JField("BaseType", encodeJsonString(td.baseType)))
    } else {
        fields.add(JField("BaseType", "null"))
    }
    fields.add(JField("IsNested", renderBool(td.isNested)))
    fields.add(JField("Attributes", renderStringArray(td.attributes, indent)))
    fields.add(JField("CustomAttributes", renderCustomAttributes(td.customAttributes, indent)))
    fields.add(JField("Fields", renderFields(td.fields, indent)))
    fields.add(JField("InterfaceImplementations", renderInterfaceImplementations(td.interfaceImplementations, indent)))
    fields.add(JField("Layout", renderLayout(td.layout, indent)))
    fields.add(JField("Methods", renderMethods(td.methods, indent)))
    fields.add(JField("NestedTypes", renderNestedTypes(td.nestedTypes, indent)))
    fields.add(JField("GenericParameters", renderGenericParameters(td.genericParameters, indent)))
    fields.add(JField("Events", renderEvents(td.events, indent)))
    fields.add(JField("Properties", renderProperties(td.properties, indent)))
    fields.add(JField("SupportedArchitectures", renderStringArray(td.supportedArchitectures, indent)))
    match (td.supportedOsPlatform) {
        case Some(value) => fields.add(JField("SupportedOsPlatform", encodeJsonString(value)))
        case None => fields.add(JField("SupportedOsPlatform", "null"))
    }
    fields.add(JField("IsExperimental", renderBool(td.isExperimental)))
    fields.add(JField("SourceSet", encodeJsonString(td.sourceSet)))
    return renderObject(fields, indent)
}

func renderNestedTypes(types: ArrayList<TypeDefinitionRecord>, indent: String): String {
    let elements = ArrayList<String>()
    let inner = "${indent}  "
    for (t in types) {
        elements.add(renderTypeDefinition(t, inner))
    }
    return renderArray(elements, indent)
}

func renderLayout(layout: Option<TypeLayoutRecord>, indent: String): String {
    match (layout) {
        case Some(value) =>
            let fields = ArrayList<JField>()
            fields.add(JField("IsDefault", renderBool(value.isDefault)))
            fields.add(JField("PackingSize", "${value.packingSize}"))
            fields.add(JField("Size", "${value.size}"))
            return renderObject(fields, indent)
        case None => return "null"
    }
}

// --- Fields ---

func renderFields(fields: ArrayList<FieldRecord>, indent: String): String {
    let elements = ArrayList<String>()
    let inner = "${indent}  "
    for (f in fields) {
        elements.add(renderField(f, inner))
    }
    return renderArray(elements, indent)
}

// C# JsFieldDefinition property order:
//   Name, Signature, Attributes, CustomAttributes, DefaultValue, Offset,
//   RelativeVirtualAddress
func renderField(f: FieldRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Name", encodeJsonString(f.name)))
    fields.add(JField("Signature", renderSignature(f.signature, "${indent}  ")))
    fields.add(JField("Attributes", renderStringArray(f.attributes, indent)))
    fields.add(JField("CustomAttributes", renderCustomAttributes(f.customAttributes, indent)))
    fields.add(JField("DefaultValue", renderOptionalJsonValue(f.defaultValue, indent)))
    fields.add(JField("Offset", "${f.offset}"))
    fields.add(JField("RelativeVirtualAddress", "${f.relativeVirtualAddress}"))
    return renderObject(fields, indent)
}

// --- Methods ---

func renderMethods(methods: ArrayList<MethodRecord>, indent: String): String {
    let elements = ArrayList<String>()
    let inner = "${indent}  "
    for (m in methods) {
        elements.add(renderMethod(m, inner))
    }
    return renderArray(elements, indent)
}

// C# JsMethodDefinition property order:
//   Name, Attributes, CustomAttributes, ImplAttributes, RelativeVirtualAddress,
//   Import, Signature, Parameters, GenericParameters
func renderMethod(m: MethodRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Name", encodeJsonString(m.name)))
    fields.add(JField("Attributes", renderStringArray(m.attributes, indent)))
    fields.add(JField("CustomAttributes", renderCustomAttributes(m.customAttributes, indent)))
    fields.add(JField("ImplAttributes", renderStringArray(m.implAttributes, indent)))
    fields.add(JField("RelativeVirtualAddress", "${m.relativeVirtualAddress}"))
    // Import: null when absent.
    match (m.methodImport) {
        case Some(mi) => fields.add(JField("Import", renderMethodImport(mi, indent)))
        case None => fields.add(JField("Import", "null"))
    }
    fields.add(JField("Signature", renderMethodSignature(m.signature, "${indent}  ")))
    fields.add(JField("Parameters", renderParameters(m.parameters, indent)))
    fields.add(JField("GenericParameters", renderGenericParameters(m.genericParameters, indent)))
    return renderObject(fields, indent)
}

// C# JsMethodImport property order: Name, Attributes, Module
func renderMethodImport(mi: MethodImportRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Name", encodeJsonString(mi.name)))
    fields.add(JField("Attributes", renderStringArray(mi.attributes, indent)))
    // Module is always rendered as an object (JsModuleReference): Name + CustomAttributes.
    let moduleFields = ArrayList<JField>()
    moduleFields.add(JField("Name", encodeJsonString(mi.moduleName)))
    match (mi.moduleReference) {
        case Some(moduleRef) =>
            moduleFields.add(JField("CustomAttributes", renderCustomAttributes(moduleRef.customAttributes, "${indent}  ")))
        case None =>
            moduleFields.add(JField("CustomAttributes", "[]"))
    }
    fields.add(JField("Module", renderObject(moduleFields, "${indent}  ")))
    return renderObject(fields, indent)
}

// C# JsMethodSignature property order:
//   GenericParameterCount, Header, ParameterTypes, RequiredParameterCount,
//   ReturnType
func renderMethodSignature(sig: MethodSignatureRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("GenericParameterCount", "${sig.genericParameterCount}"))
    fields.add(JField("Header", renderHeader(sig.header, indent)))
    let paramElements = ArrayList<String>()
    let paramInner = "${indent}  "
    for (p in sig.parameters) {
        paramElements.add(renderSignature(p, paramInner))
    }
    fields.add(JField("ParameterTypes", renderArray(paramElements, indent)))
    fields.add(JField("RequiredParameterCount", "${sig.requiredParameterCount}"))
    fields.add(JField("ReturnType", renderSignature(sig.returnType, "${indent}  ")))
    return renderObject(fields, indent)
}

// C# JsSignatureHeader property order:
//   Attributes, CallingConvention, HasExplicitThis, IsGeneric, IsInstance, Kind
func renderHeader(header: HashMap<String, JsonValue>, indent: String): String {
    if (header.isEmpty()) {
        return "{}"
    }
    let order = ["Attributes", "CallingConvention", "HasExplicitThis", "IsGeneric", "IsInstance", "Kind"]
    let fields = ArrayList<JField>()
    for (key in order) {
        match (header.get(key)) {
            case Some(value) => fields.add(JField(key, renderJsonValue(value, indent)))
            case None => ()
        }
    }
    // Emit any remaining keys not in the known order (defensive).
    for ((key, value) in header) {
        if (!containsString(order, key)) {
            fields.add(JField(key, renderJsonValue(value, indent)))
        }
    }
    return renderObject(fields, indent)
}

// --- Parameters ---

func renderParameters(parameters: ArrayList<ParameterRecord>, indent: String): String {
    let elements = ArrayList<String>()
    let inner = "${indent}  "
    for (p in parameters) {
        elements.add(renderParameter(p, inner))
    }
    return renderArray(elements, indent)
}

// C# JsParameter property order:
//   Name, SequenceNumber, Attributes, CustomAttributes, DefaultValue
func renderParameter(p: ParameterRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Name", encodeJsonString(p.name)))
    fields.add(JField("SequenceNumber", "${p.sequenceNumber}"))
    fields.add(JField("Attributes", renderStringArray(p.attributes, indent)))
    fields.add(JField("CustomAttributes", renderCustomAttributes(p.customAttributes, indent)))
    fields.add(JField("DefaultValue", renderOptionalJsonValue(p.defaultValue, indent)))
    return renderObject(fields, indent)
}

// --- Generic parameters ---

func renderGenericParameters(parameters: ArrayList<GenericParameterRecord>, indent: String): String {
    let elements = ArrayList<String>()
    let inner = "${indent}  "
    for (gp in parameters) {
        elements.add(renderGenericParameter(gp, inner))
    }
    return renderArray(elements, indent)
}

// C# JsGenericParameter property order: Attributes, Index, Name, Constraints,
// CustomAttributes
func renderGenericParameter(gp: GenericParameterRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Attributes", renderStringArray(gp.attributes, indent)))
    match (gp.index) {
        case Some(value) => fields.add(JField("Index", "${value}"))
        case None => fields.add(JField("Index", "${gp.sequenceNumber}"))
    }
    fields.add(JField("Name", encodeJsonString(gp.name)))
    let constraintElements = ArrayList<String>()
    let inner = "${indent}  "
    for (c in gp.constraints) {
        constraintElements.add(renderJsonValue(c, inner))
    }
    fields.add(JField("Constraints", renderArray(constraintElements, indent)))
    fields.add(JField("CustomAttributes", renderCustomAttributes(gp.customAttributes, indent)))
    return renderObject(fields, indent)
}

// --- Events ---

func renderEvents(events: ArrayList<EventRecord>, indent: String): String {
    let elements = ArrayList<String>()
    let inner = "${indent}  "
    for (e in events) {
        elements.add(renderEvent(e, inner))
    }
    return renderArray(elements, indent)
}

// C# JsEventDefinition property order: Attributes, Name, Type, Accessors,
// CustomAttributes
func renderEvent(e: EventRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Attributes", renderStringArray(e.attributes, indent)))
    fields.add(JField("Name", encodeJsonString(e.name)))
    // The event Type is a JsEntityHandle (Kind + TypeReference/TypeDefinition/
    // TypeSpecification), the same shape used by InterfaceImplementation.Interface.
    fields.add(JField("Type", renderEntityHandle(e.typeSig, "${indent}  ")))
    fields.add(JField("Accessors", renderAccessors(e.accessors, indent)))
    fields.add(JField("CustomAttributes", renderCustomAttributes(e.customAttributes, indent)))
    return renderObject(fields, indent)
}

// --- Properties ---

func renderProperties(properties: ArrayList<PropertyRecord>, indent: String): String {
    let elements = ArrayList<String>()
    let inner = "${indent}  "
    for (p in properties) {
        elements.add(renderProperty(p, inner))
    }
    return renderArray(elements, indent)
}

// C# JsPropertyDefinition property order: Attributes, Name, Signature,
// Accessors, CustomAttributes
func renderProperty(p: PropertyRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Attributes", renderStringArray(p.attributes, indent)))
    fields.add(JField("Name", encodeJsonString(p.name)))
    fields.add(JField("Signature", renderMethodSignature(p.signature, "${indent}  ")))
    fields.add(JField("Accessors", renderAccessors(p.accessors, indent)))
    fields.add(JField("CustomAttributes", renderCustomAttributes(p.customAttributes, indent)))
    return renderObject(fields, indent)
}

// Event / property accessor objects. The C# JsEventAccessors / JsPropertyAccessors
// serialize string-or-null members (Adder/Remover/Raiser/Others or Getter/Setter/
// Others). The model stores them as a generic HashMap<String, JsonValue>, so we
// emit the standard ordering followed by any remaining keys.
func renderAccessors(accessors: HashMap<String, JsonValue>, indent: String): String {
    if (accessors.isEmpty()) {
        return "{}"
    }
    let eventOrder = ["Adder", "Raiser", "Remover", "Others"]
    let propertyOrder = ["Getter", "Setter", "Others"]
    let fields = ArrayList<JField>()
    let emitted = ArrayList<String>()
    let order = if (accessors.contains("Adder") || accessors.contains("Raiser") || accessors.contains("Remover")) {
        eventOrder
    } else {
        propertyOrder
    }
    for (key in order) {
        match (accessors.get(key)) {
            case Some(value) =>
                fields.add(JField(key, renderJsonValue(value, indent)))
                emitted.add(key)
            case None => ()
        }
    }
    for ((key, value) in accessors) {
        if (!containsStringList(emitted, key)) {
            fields.add(JField(key, renderJsonValue(value, indent)))
        }
    }
    return renderObject(fields, indent)
}

// --- Interface implementations ---

func renderInterfaceImplementations(impls: ArrayList<InterfaceImplementationRecord>, indent: String): String {
    let elements = ArrayList<String>()
    let inner = "${indent}  "
    for (impl in impls) {
        elements.add(renderInterfaceImplementation(impl, inner))
    }
    return renderArray(elements, indent)
}

// C# JsInterfaceImplementation property order: Interface, CustomAttributes.
// The `Interface` is a JsEntityHandle (Kind + one of TypeReference/
// TypeDefinition/TypeSpecification populated, others null). The model captures
// that handle in `interfaceSignature` (kind == TypeReference/TypeDefinition/
// TypeSpecification), so we re-render it as the entity-handle shape.
func renderInterfaceImplementation(impl: InterfaceImplementationRecord, indent: String): String {
    let fields = ArrayList<JField>()
    match (impl.interfaceSignature) {
        case Some(sig) => fields.add(JField("Interface", renderEntityHandle(sig, "${indent}  ")))
        case None => fields.add(JField("Interface", "null"))
    }
    fields.add(JField("CustomAttributes", renderCustomAttributes(impl.customAttributes, indent)))
    return renderObject(fields, indent)
}

// Render a JsEntityHandle-shaped signature: Kind plus the matching populated
// member; the other two members are explicit null.
func renderEntityHandle(sig: SignatureRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Kind", encodeJsonString(sig.kind)))
    if (sig.kind == "TypeReference") {
        fields.add(JField("TypeReference", renderMetadataTypeOrNull(sig.typeReference, "${indent}  ")))
        fields.add(JField("TypeDefinition", "null"))
        fields.add(JField("TypeSpecification", "null"))
    } else if (sig.kind == "TypeDefinition") {
        fields.add(JField("TypeReference", "null"))
        fields.add(JField("TypeDefinition", renderMetadataTypeOrNull(sig.typeDefinition, "${indent}  ")))
        fields.add(JField("TypeSpecification", "null"))
    } else if (sig.kind == "TypeSpecification") {
        fields.add(JField("TypeReference", "null"))
        fields.add(JField("TypeDefinition", "null"))
        fields.add(JField("TypeSpecification", renderTypeSpecificationOrNull(sig.typeSpecification, "${indent}  ")))
    } else {
        // Fall back to a plain signature render for unexpected kinds.
        return renderSignature(sig, indent)
    }
    return renderObject(fields, indent)
}

// JsTypeReference / JsTypeDefinitionNamespaceAndNameOnly property order: Name, Namespace
func renderMetadataTypeOrNull(value: Option<MetadataTypeRecord>, indent: String): String {
    match (value) {
        case Some(mt) =>
            let fields = ArrayList<JField>()
            fields.add(JField("Name", encodeJsonString(mt.name)))
            fields.add(JField("Namespace", encodeJsonString(mt.namespace)))
            return renderObject(fields, indent)
        case None => return "null"
    }
}

// JsTypeSpecification property order: Signature, CustomAttributes
func renderTypeSpecificationOrNull(value: Option<TypeSpecificationRecord>, indent: String): String {
    match (value) {
        case Some(ts) =>
            let fields = ArrayList<JField>()
            fields.add(JField("Signature", renderSignature(ts.signature, "${indent}  ")))
            fields.add(JField("CustomAttributes", renderCustomAttributes(ts.customAttributes, indent)))
            return renderObject(fields, indent)
        case None => return "null"
    }
}

// --- Custom attributes ---

func renderCustomAttributes(attributes: ArrayList<CustomAttributeRecord>, indent: String): String {
    let elements = ArrayList<String>()
    let inner = "${indent}  "
    for (a in attributes) {
        elements.add(renderCustomAttribute(a, inner))
    }
    return renderArray(elements, indent)
}

// C# JsCustomAttribute property order: Type, FixedArguments, NamedArguments
func renderCustomAttribute(a: CustomAttributeRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Type", encodeJsonString(a.typeName)))
    let fixedElements = ArrayList<String>()
    let inner = "${indent}  "
    for (fa in a.fixedArguments) {
        fixedElements.add(renderFixedArgument(fa, inner))
    }
    fields.add(JField("FixedArguments", renderArray(fixedElements, indent)))
    let namedElements = ArrayList<String>()
    for (na in a.namedArguments) {
        namedElements.add(renderNamedArgument(na, inner))
    }
    fields.add(JField("NamedArguments", renderArray(namedElements, indent)))
    return renderObject(fields, indent)
}

// C# JsCustomAttributeFixedArgument property order: Type, Value
func renderFixedArgument(fa: CustomAttributeFixedArgumentRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Type", renderSignature(fa.typeSig, "${indent}  ")))
    fields.add(JField("Value", renderOptionalJsonValue(fa.value, indent)))
    return renderObject(fields, indent)
}

// C# JsCustomAttributeNamedArgument property order: Kind, Name, Type, Value
func renderNamedArgument(na: CustomAttributeNamedArgumentRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Kind", encodeJsonString(na.kind)))
    fields.add(JField("Name", encodeJsonString(na.name)))
    fields.add(JField("Type", renderSignature(na.typeSig, "${indent}  ")))
    fields.add(JField("Value", renderOptionalJsonValue(na.value, indent)))
    return renderObject(fields, indent)
}

// --- Signatures (TType) ---
//
// C# TType property declaration order (System.Text.Json honors it):
//   Kind, Type, Namespace, Name, LowerBounds, Rank, Sizes, TypeArguments,
//   ModifierType, UnmodifiedType, IsRequired, Signature, Comment
// All sub-fields except Kind are JsonIgnore-WhenWritingNull, so absent values
// are OMITTED rather than emitted as null.
func renderSignature(sig: SignatureRecord, indent: String): String {
    let fields = ArrayList<JField>()
    fields.add(JField("Kind", encodeJsonString(sig.kind)))
    // Type (nested element / generic base / pointer target).
    match (sig.typeSig) {
        case Some(inner) => fields.add(JField("Type", renderSignature(inner, "${indent}  ")))
        case None => fields.add(JField("Type", skip: true))
    }
    // Namespace / Name. The model always stores Strings; the C# DTO omits them
    // when null. We treat an empty hasNamespace flag / empty name as "absent".
    if (sig.hasNamespace) {
        fields.add(JField("Namespace", encodeJsonString(sig.namespace)))
    } else {
        fields.add(JField("Namespace", skip: true))
    }
    if (signatureNamePresent(sig)) {
        fields.add(JField("Name", encodeJsonString(sig.name)))
    } else {
        fields.add(JField("Name", skip: true))
    }
    // LowerBounds / Rank / Sizes (Array kind).
    match (sig.lowerBounds) {
        case Some(values) => fields.add(JField("LowerBounds", renderIntArray(values, indent)))
        case None => fields.add(JField("LowerBounds", skip: true))
    }
    match (sig.rank) {
        case Some(value) => fields.add(JField("Rank", "${value}"))
        case None => fields.add(JField("Rank", skip: true))
    }
    match (sig.sizes) {
        case Some(values) => fields.add(JField("Sizes", renderIntArray(values, indent)))
        case None => fields.add(JField("Sizes", skip: true))
    }
    // TypeArguments (Generic kind).
    if (sig.typeArguments.isEmpty()) {
        fields.add(JField("TypeArguments", skip: true))
    } else {
        let argElements = ArrayList<String>()
        let inner = "${indent}  "
        for (arg in sig.typeArguments) {
            argElements.add(renderSignature(arg, inner))
        }
        fields.add(JField("TypeArguments", renderArray(argElements, indent)))
    }
    // ModifierType / UnmodifiedType / IsRequired (Modified kind).
    match (sig.modifierType) {
        case Some(inner) => fields.add(JField("ModifierType", renderSignature(inner, "${indent}  ")))
        case None => fields.add(JField("ModifierType", skip: true))
    }
    match (sig.unmodifiedType) {
        case Some(inner) => fields.add(JField("UnmodifiedType", renderSignature(inner, "${indent}  ")))
        case None => fields.add(JField("UnmodifiedType", skip: true))
    }
    match (sig.isRequired) {
        case Some(value) => fields.add(JField("IsRequired", renderBool(value)))
        case None => fields.add(JField("IsRequired", skip: true))
    }
    // Signature (FunctionPointer kind).
    match (sig.functionPointerSignature) {
        case Some(value) => fields.add(JField("Signature", renderMethodSignature(value, "${indent}  ")))
        case None => fields.add(JField("Signature", skip: true))
    }
    // Comment (TypeDefinition / TypeReference source marker).
    match (sig.comment) {
        case Some(value) => fields.add(JField("Comment", encodeJsonString(value)))
        case None => fields.add(JField("Comment", skip: true))
    }
    return renderObject(fields, indent)
}

// Whether a signature carries a Name worth emitting. Primitives, Types,
// GenericParameters carry a name; structural kinds (Pointer/Array/...) do not.
func signatureNamePresent(sig: SignatureRecord): Bool {
    if (sig.name.isEmpty()) {
        return false
    }
    match (sig.kind) {
        case "Primitive" => return true
        case "Type" => return true
        case "GenericParameter" => return true
        case "SerializedName" => return true
        case _ => return !sig.name.isEmpty()
    }
}

// --- Scalar / JsonValue rendering ---

func renderOptionalJsonValue(value: Option<JsonValue>, indent: String): String {
    match (value) {
        case Some(v) => return renderJsonValue(v, indent)
        case None => return "null"
    }
}

// Render an arbitrary JsonValue with the same two-space pretty layout used by
// the rest of the document.
func renderJsonValue(value: JsonValue, indent: String): String {
    match (value.kind()) {
        case JsonKind.JsNull => return "null"
        case JsonKind.JsBool => return renderBool(value.asBool().getValue())
        case JsonKind.JsInt => return "${value.asInt().getValue()}"
        case JsonKind.JsFloat => return renderFloat(value.asFloat().getValue())
        case JsonKind.JsString => return encodeJsonString(value.asString().getValue())
        case JsonKind.JsArray =>
            let arr = value.asArray()
            let elements = ArrayList<String>()
            let inner = "${indent}  "
            var i: Int64 = 0
            while (i < arr.size()) {
                elements.add(renderJsonValue(arr[i], inner))
                i += 1
            }
            return renderArray(elements, indent)
        case JsonKind.JsObject =>
            let obj = value.asObject()
            let fields = ArrayList<JField>()
            let inner = "${indent}  "
            for ((key, v) in obj.getFields()) {
                fields.add(JField(key, renderJsonValue(v, inner)))
            }
            return renderObject(fields, indent)
    }
}

func renderBool(value: Bool): String {
    if (value) {
        return "true"
    }
    return "false"
}

func renderFloat(value: Float64): String {
    return shortestFloatString(value)
}

// Produce the shortest decimal string that parses back to exactly `value`
// (round-trippable). The default Float64 interpolation rounds to ~6 significant
// digits, which loses precision and can change the encoded IEEE-754 value, so we
// search increasing precision until the parsed result round-trips.
func shortestFloatString(value: Float64): String {
    if (value != value) {
        // NaN — emit 0 (constants never carry NaN; defensive).
        return "0"
    }
    var precision: Int64 = 1
    while (precision <= 17) {
        let candidate = trimFloatString(value.format(".${precision}"))
        if (parseFloatLenient(candidate) == value) {
            return candidate
        }
        precision += 1
    }
    return trimFloatString(value.format(".17"))
}

// Strip a redundant trailing ".0" / trailing zeros in the fractional part while
// keeping at least one fractional digit when a dot is present.
func trimFloatString(text: String): String {
    if (!text.contains(".") || text.contains("e") || text.contains("E")) {
        return text
    }
    let arr = text.toArray()
    var end = Int64(arr.size)
    while (end > 0 && arr[end - 1] == b'0') {
        end -= 1
    }
    if (end > 0 && arr[end - 1] == b'.') {
        // Keep one zero so the JSON number stays a float (e.g. "2.0").
        end += 1
    }
    return String.fromUtf8(arr[0..end])
}

func parseFloatLenient(text: String): Float64 {
    try {
        return Float64.parse(text)
    } catch (_: Exception) {
        return Float64.NaN
    }
}

func renderIntArray(values: ArrayList<Int64>, indent: String): String {
    let elements = ArrayList<String>()
    for (v in values) {
        elements.add("${v}")
    }
    return renderArray(elements, indent)
}

// Encode a String as a JSON string literal. Mirrors the C# Utf8JsonWriter's
// default escaping for the characters that matter for structural comparison:
//   - the mandatory JSON escapes (", \\, control chars)
//   - `<` and `>` as < / > (C# escapes these by default)
func encodeJsonString(value: String): String {
    let builder = StringBuilder()
    builder.append("\"")
    for (r in value.runes()) {
        let code = UInt32(r)
        if (r == r'"') {
            builder.append("\\\"")
        } else if (r == r'\\') {
            builder.append("\\\\")
        } else if (r == r'\n') {
            builder.append("\\n")
        } else if (r == r'\r') {
            builder.append("\\r")
        } else if (r == r'\t') {
            builder.append("\\t")
        } else if (r == r'\b') {
            builder.append("\\b")
        } else if (r == r'\f') {
            builder.append("\\f")
        } else if (r == r'<') {
            builder.append("\\u003C")
        } else if (r == r'>') {
            builder.append("\\u003E")
        } else if (r == r'&') {
            builder.append("\\u0026")
        } else if (r == r'\'') {
            builder.append("\\u0027")
        } else if (r == r'+') {
            builder.append("\\u002B")
        } else if (code < 0x20u32) {
            builder.append("\\u")
            builder.append(hex4(code))
        } else {
            builder.append(r)
        }
    }
    builder.append("\"")
    return builder.toString()
}

func hex4(value: UInt32): String {
    let digits = "0123456789abcdef".toArray()
    let b3 = digits[Int64((value >> 12) & 0xFu32)]
    let b2 = digits[Int64((value >> 8) & 0xFu32)]
    let b1 = digits[Int64((value >> 4) & 0xFu32)]
    let b0 = digits[Int64(value & 0xFu32)]
    return String.fromUtf8([b3, b2, b1, b0])
}

func appendStringField(builder: StringBuilder, indent: String, key: String, value: String, comma: Bool): Unit {
    builder.append("${indent}\"${key}\": ${encodeJsonString(value)}")
    if (comma) {
        builder.append(",")
    }
    builder.append("\n")
}

func containsString(values: Array<String>, value: String): Bool {
    for (v in values) {
        if (v == value) {
            return true
        }
    }
    return false
}

func containsStringList(values: ArrayList<String>, value: String): Bool {
    for (v in values) {
        if (v == value) {
            return true
        }
    }
    return false
}
