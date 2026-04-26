package windows_metadata.writer

import std.collection.*
import std.fs.*
import windows_metadata.*

let PE_OFFSET: Int64 = 64
let OPTIONAL_HEADER_SIZE: Int64 = 224
let CLR_HEADER_SIZE: Int64 = 72
let FILE_ALIGNMENT: Int64 = 512
let SECTION_ALIGNMENT: Int64 = 4096
let IMAGE_FILE_MACHINE_I386: UInt16 = 0x014Cu16
let IMAGE_FILE_EXECUTABLE_IMAGE: UInt16 = 0x0002u16
let IMAGE_FILE_32BIT_MACHINE: UInt16 = 0x0100u16
let IMAGE_FILE_DLL: UInt16 = 0x2000u16
let IMAGE_SUBSYSTEM_WINDOWS_CUI: UInt16 = 0x0003u16
let IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE: UInt16 = 0x0040u16
let IMAGE_DLLCHARACTERISTICS_NX_COMPAT: UInt16 = 0x0100u16
let IMAGE_DLLCHARACTERISTICS_NO_SEH: UInt16 = 0x0400u16
let WINDOWS_RUNTIME_ASSEMBLY_FLAGS: UInt32 = 0x200u32

class StringHeap {
    let offsets: HashMap<String, Int64>
    let bytes: ArrayList<Byte>

    init() {
        this.offsets = HashMap<String, Int64>()
        this.bytes = ArrayList<Byte>()
        bytes.add(0u8)
    }

    func insert(value: String): Int64 {
        if (value.isEmpty()) {
            return 0
        }
        if (offsets.contains(value)) {
            return offsets[value]
        }

        let offset = Int64(bytes.size)
        offsets[value] = offset
        for (b in value.toArray()) {
            bytes.add(b)
        }
        bytes.add(0u8)
        return offset
    }

    func toBytes(): Array<Byte> {
        return padTo4(toArray(bytes))
    }
}

class BlobHeap {
    let offsets: HashMap<BlobKey, Int64>
    let bytes: ArrayList<Byte>

    init() {
        this.offsets = HashMap<BlobKey, Int64>()
        this.bytes = ArrayList<Byte>()
        bytes.add(0u8)
    }

    func insert(value: Array<Byte>): Int64 {
        if (value.isEmpty()) {
            return 0
        }

        let key = BlobKey(value)
        if (offsets.contains(key)) {
            return offsets[key]
        }

        let offset = Int64(bytes.size)
        offsets[key] = offset
        appendBytes(bytes, encodeCompressed(value))
        appendBytes(bytes, value)
        return offset
    }

    func toBytes(): Array<Byte> {
        return padTo4(toArray(bytes))
    }
}

struct BlobKey <: Hashable & Equatable<BlobKey> {
    let bytes: Array<Byte>

    public init(bytes: Array<Byte>) {
        this.bytes = bytes
    }

    public operator func ==(other: BlobKey): Bool {
        if (bytes.size != other.bytes.size) {
            return false
        }

        var i: Int64 = 0
        while (i < Int64(bytes.size)) {
            if (bytes[i] != other.bytes[i]) {
                return false
            }
            i += 1
        }
        true
    }

    public operator func !=(other: BlobKey): Bool {
        !(this == other)
    }

    public func hashCode(): Int64 {
        var hasher = DefaultHasher()
        hasher.write(Int64(bytes.size))
        for (byte in bytes) {
            hasher.write(byte)
        }
        hasher.finish()
    }
}

struct ConstantStageKey <: Comparable<ConstantStageKey> {
    let parentTable: Int64
    let parentRow: Int64

    public init(parentTable: Int64, parentRow: Int64) {
        this.parentTable = parentTable
        this.parentRow = parentRow
    }

    public func compare(other: ConstantStageKey): Ordering {
        constantStageSortKey(parentTable, parentRow).compare(constantStageSortKey(other.parentTable, other.parentRow))
    }
}

struct AttributeStageKey <: Comparable<AttributeStageKey> {
    let parentTable: Int64
    let parentRow: Int64

    public init(parentTable: Int64, parentRow: Int64) {
        this.parentTable = parentTable
        this.parentRow = parentRow
    }

    public func compare(other: AttributeStageKey): Ordering {
        attributeStageSortKey(parentTable, parentRow).compare(attributeStageSortKey(other.parentTable, other.parentRow))
    }
}

struct GenericParamStageKey <: Comparable<GenericParamStageKey> {
    let ownerTable: Int64
    let ownerRow: Int64

    public init(ownerTable: Int64, ownerRow: Int64) {
        this.ownerTable = ownerTable
        this.ownerRow = ownerRow
    }

    public func compare(other: GenericParamStageKey): Ordering {
        genericParamStageSortKey(ownerTable, ownerRow).compare(genericParamStageSortKey(other.ownerTable, other.ownerRow))
    }
}

class ModuleRow {
    var generation: UInt16 = 0u16
    var name: Int64 = 0
    var mvid: UInt32 = 1u32
    var encId: UInt32 = 0u32
    var encBaseId: UInt32 = 0u32
}

class AssemblyRow {
    var hashAlgId: UInt32 = 0x00008004u32
    var majorVersion: UInt16 = 0x00FFu16
    var minorVersion: UInt16 = 0x00FFu16
    var buildNumber: UInt16 = 0x00FFu16
    var revisionNumber: UInt16 = 0x00FFu16
    var flags: UInt32 = WINDOWS_RUNTIME_ASSEMBLY_FLAGS
    var publicKey: Int64 = 0
    var name: Int64 = 0
    var culture: Int64 = 0
}

class AssemblyRefRow {
    var majorVersion: UInt16 = 0x00FFu16
    var minorVersion: UInt16 = 0x00FFu16
    var buildNumber: UInt16 = 0x00FFu16
    var revisionNumber: UInt16 = 0x00FFu16
    var flags: UInt32 = WINDOWS_RUNTIME_ASSEMBLY_FLAGS
    var publicKeyOrToken: Int64 = 0
    var name: Int64 = 0
    var culture: Int64 = 0
    var hashValue: Int64 = 0
}

class TypeDefRow {
    var flags: UInt32 = 0u32
    var name: Int64 = 0
    var namespace: Int64 = 0
    var extendsTag: Int64 = -1
    var extendsRow: Int64 = -1
    var fieldList: Int64 = 0
    var methodList: Int64 = 0
}

class TypeRefRow {
    var scopeTag: Int64 = 0
    var scopeRow: Int64 = 0
    var name: Int64 = 0
    var namespace: Int64 = 0
}

class FieldRow {
    var flags: UInt16 = 0u16
    var name: Int64 = 0
    var signature: Int64 = 0
}

class MethodDefRow {
    var rva: UInt32 = 0u32
    var implFlags: UInt16 = 0u16
    var flags: UInt16 = 0u16
    var name: Int64 = 0
    var signature: Int64 = 0
    var paramList: Int64 = 0
}

class ParamRow {
    var flags: UInt16 = 0u16
    var sequence: UInt16 = 0u16
    var name: Int64 = 0
}

class TypeSpecRow {
    var signature: Int64 = 0
}

class ModuleRefRow {
    var name: Int64 = 0
}

class MemberRefRow {
    var parentTag: Int64 = 0
    var parentRow: Int64 = 0
    var name: Int64 = 0
    var signature: Int64 = 0
}

class AttributeRow {
    var parentTable: Int64 = 0
    var parentRow: Int64 = 0
    var typeTable: Int64 = 0
    var typeRow: Int64 = 0
    var value: Int64 = 0
}

class ConstantRow {
    var ty: UInt8 = 0u8
    var parentTable: Int64 = 0
    var parentRow: Int64 = 0
    var value: Int64 = 0
}

class GenericParamRow {
    var number: UInt16 = 0u16
    var flags: UInt16 = 0u16
    var ownerTable: Int64 = 0
    var ownerRow: Int64 = 0
    var name: Int64 = 0
}

class InterfaceImplRow {
    var classRow: Int64 = 0
    var interfaceTag: Int64 = 0
    var interfaceRow: Int64 = 0
}

class ClassLayoutRow {
    var packingSize: UInt16 = 0u16
    var classSize: UInt32 = 0u32
    var parent: Int64 = 0
}

class FieldLayoutRow {
    var offset: UInt32 = 0u32
    var field: Int64 = 0
}

class NestedClassRow {
    var nestedClass: Int64 = 0
    var enclosingClass: Int64 = 0
}

class ImplMapRow {
    var mappingFlags: UInt16 = 0u16
    var memberTable: Int64 = 0
    var memberRow: Int64 = 0
    var importName: Int64 = 0
    var importScope: Int64 = 0
}

public class WinmdWriter {
    let strings: StringHeap
    let blobs: BlobHeap
    let modules: ArrayList<ModuleRow>
    let assemblies: ArrayList<AssemblyRow>
    let assemblyRefs: ArrayList<AssemblyRefRow>
    let typeDefs: ArrayList<TypeDefRow>
    let typeRefs: ArrayList<TypeRefRow>
    let fields: ArrayList<FieldRow>
    let fieldLayouts: ArrayList<FieldLayoutRow>
    let methodDefs: ArrayList<MethodDefRow>
    let params: ArrayList<ParamRow>
    let moduleRefs: ArrayList<ModuleRefRow>
    let memberRefs: ArrayList<MemberRefRow>
    let attributes: ArrayList<AttributeRow>
    let constants: ArrayList<ConstantRow>
    let genericParams: ArrayList<GenericParamRow>
    let interfaceImpls: ArrayList<InterfaceImplRow>
    let classLayouts: ArrayList<ClassLayoutRow>
    let nestedClasses: ArrayList<NestedClassRow>
    let implMaps: ArrayList<ImplMapRow>
    let typeSpecs: ArrayList<TypeSpecRow>
    let typeRefIndex: HashMap<String, Int64>
    let typeSpecIndex: HashMap<Int64, Int64>
    let assemblyRefIndex: HashMap<String, Int64>
    let moduleRefIndex: HashMap<String, Int64>
    let memberRefIndex: HashMap<String, Int64>
    let constantStaging: TreeMap<ConstantStageKey, ConstantRow>
    let attributeStaging: TreeMap<AttributeStageKey, ArrayList<AttributeRow>>
    let genericParamStaging: TreeMap<GenericParamStageKey, ArrayList<GenericParamRow>>
    var reference: Option<TypeIndex>

    public init(name: String) {
        this.strings = StringHeap()
        this.blobs = BlobHeap()
        this.modules = ArrayList<ModuleRow>()
        this.assemblies = ArrayList<AssemblyRow>()
        this.assemblyRefs = ArrayList<AssemblyRefRow>()
        this.typeDefs = ArrayList<TypeDefRow>()
        this.typeRefs = ArrayList<TypeRefRow>()
        this.fields = ArrayList<FieldRow>()
        this.fieldLayouts = ArrayList<FieldLayoutRow>()
        this.methodDefs = ArrayList<MethodDefRow>()
        this.params = ArrayList<ParamRow>()
        this.moduleRefs = ArrayList<ModuleRefRow>()
        this.memberRefs = ArrayList<MemberRefRow>()
        this.attributes = ArrayList<AttributeRow>()
        this.constants = ArrayList<ConstantRow>()
        this.genericParams = ArrayList<GenericParamRow>()
        this.interfaceImpls = ArrayList<InterfaceImplRow>()
        this.classLayouts = ArrayList<ClassLayoutRow>()
        this.nestedClasses = ArrayList<NestedClassRow>()
        this.implMaps = ArrayList<ImplMapRow>()
        this.typeSpecs = ArrayList<TypeSpecRow>()
        this.typeRefIndex = HashMap<String, Int64>()
        this.typeSpecIndex = HashMap<Int64, Int64>()
        this.assemblyRefIndex = HashMap<String, Int64>()
        this.moduleRefIndex = HashMap<String, Int64>()
        this.memberRefIndex = HashMap<String, Int64>()
        this.constantStaging = TreeMap<ConstantStageKey, ConstantRow>()
        this.attributeStaging = TreeMap<AttributeStageKey, ArrayList<AttributeRow>>()
        this.genericParamStaging = TreeMap<GenericParamStageKey, ArrayList<GenericParamRow>>()
        this.reference = None

        let moduleRow = ModuleRow()
        moduleRow.name = strings.insert(name)
        modules.add(moduleRow)

        let assemblyRow = AssemblyRow()
        assemblyRow.name = strings.insert(name)
        assemblies.add(assemblyRow)

        ensureAssemblyRef("System")
        typeDef("", "<Module>", TypeAttributes(0u32))
    }

    public func setReference(reference: TypeIndex): Unit {
        this.reference = Some(reference)
    }

    public func typeDef(namespace: String, name: String, flags: TypeAttributes): Int64 {
        let row = TypeDefRow()
        row.flags = flags.value
        row.name = strings.insert(name)
        row.namespace = strings.insert(namespace)
        row.fieldList = Int64(fields.size)
        row.methodList = Int64(methodDefs.size)
        typeDefs.add(row)
        return Int64(typeDefs.size) - 1
    }

    public func typeDef(namespace: String, name: String, flags: TypeAttributes, extends: MetadataType): Int64 {
        let row = typeDef(namespace, name, flags)
        typeDefExtends(row, extends)
        return row
    }

    public func typeDefExtends(rowIndex: Int64, extends: MetadataType): Unit {
        if (rowIndex < 0 || rowIndex >= Int64(typeDefs.size)) {
            throw Exception("TypeDef row out of range")
        }

        let (tag, rowValue) = typeDefOrRefForType(extends)
        let row = typeDefs[rowIndex]
        row.extendsTag = tag
        row.extendsRow = rowValue
    }

    public func typeRef(namespace: String, name: String): Int64 {
        return ensureTypeRef(namespace, name)
    }

    public func field(name: String, ty: MetadataType, flags: FieldAttributes): Int64 {
        let row = FieldRow()
        row.flags = flags.value
        row.name = strings.insert(name)
        row.signature = blobs.insert(encodeFieldSignature(ty))
        fields.add(row)
        return Int64(fields.size) - 1
    }

    public func fieldLayout(field: Int64, offset: UInt32): Unit {
        let row = FieldLayoutRow()
        row.offset = offset
        row.field = field
        fieldLayouts.add(row)
    }

    public func methodDef(name: String, signature: MethodSignature, flags: MethodAttributes, implFlags: MethodImplAttributes): Int64 {
        let row = MethodDefRow()
        row.flags = flags.value
        row.implFlags = implFlags.value
        row.name = strings.insert(name)
        row.signature = blobs.insert(encodeMethodSignature(signature))
        row.paramList = Int64(params.size)
        methodDefs.add(row)
        return Int64(methodDefs.size) - 1
    }

    public func memberRef(name: String, signature: MethodSignature, parentTable: Int64, parentRow: Int64): Int64 {
        let signatureBlob = blobs.insert(encodeMethodSignature(signature))
        let key = "${parentTable}|${parentRow}|${name}|${signatureBlob}"
        if (memberRefIndex.contains(key)) {
            return memberRefIndex[key]
        }

        let row = MemberRefRow()
        row.parentTag = memberRefParentTag(parentTable)
        row.parentRow = parentRow
        row.name = strings.insert(name)
        row.signature = signatureBlob
        memberRefs.add(row)

        let index = Int64(memberRefs.size) - 1
        memberRefIndex[key] = index
        return index
    }

    public func param(name: String, sequence: UInt16, flags: ParamAttributes): Int64 {
        let row = ParamRow()
        row.flags = flags.value
        row.sequence = sequence
        row.name = strings.insert(name)
        params.add(row)
        return Int64(params.size) - 1
    }

    public func typeSpec(namespace: String, name: String, generics: Array<MetadataType>): Int64 {
        if (generics.isEmpty()) {
            throw Exception("TypeSpec requires at least one generic argument")
        }

        let typeName = "${name}`${generics.size}"
        let typeRefRow = ensureTypeRef(namespace, typeName)
        let buffer = ArrayList<Byte>()
        buffer.add(ELEMENT_TYPE_GENERICINST)
        buffer.add(ELEMENT_TYPE_CLASS)
        writeCompressed(buffer, encodeCodedIndex(1, typeRefRow, CODED_TYPE_DEF_OR_REF_BITS))
        writeCompressed(buffer, Int64(generics.size))
        for (generic in generics) {
            appendType(buffer, generic)
        }
        let signatureBytes = toArray(buffer)
        let signatureBlob = blobs.insert(signatureBytes)
        if (typeSpecIndex.contains(signatureBlob)) {
            return typeSpecIndex[signatureBlob]
        }

        let row = TypeSpecRow()
        row.signature = signatureBlob
        typeSpecs.add(row)
        let index = Int64(typeSpecs.size) - 1
        typeSpecIndex[signatureBlob] = index
        return index
    }

    public func attribute(parentTable: Int64, parentRow: Int64, typeTable: Int64, typeRow: Int64, values: ArrayList<(String, MetadataValue)>): Unit {
        let row = AttributeRow()
        row.parentTable = parentTable
        row.parentRow = parentRow
        row.typeTable = typeTable
        row.typeRow = typeRow
        row.value = blobs.insert(encodeAttributeValue(values))
        let key = attributeStageKey(parentTable, parentRow)
        if (!attributeStaging.contains(key)) {
            attributeStaging[key] = ArrayList<AttributeRow>()
        }
        attributeStaging[key].add(row)
    }

    public func constant(parentTable: Int64, parentRow: Int64, value: MetadataValue, ty: MetadataType): Unit {
        let elementType = ty.elementTypeCode()
        if (elementType == 0u8) {
            throw Exception("unsupported constant type")
        }

        let row = ConstantRow()
        row.ty = elementType
        row.parentTable = parentTable
        row.parentRow = parentRow
        row.value = blobs.insert(encodeConstantValue(value, ty))
        constantStaging[constantStageKey(parentTable, parentRow)] = row
    }

    public func genericParam(name: String, ownerTable: Int64, ownerRow: Int64, number: UInt16, flags: GenericParamAttributes): Unit {
        let row = GenericParamRow()
        row.number = number
        row.flags = flags.value
        row.ownerTable = ownerTable
        row.ownerRow = ownerRow
        row.name = strings.insert(name)
        let key = genericParamStageKey(ownerTable, ownerRow)
        if (!genericParamStaging.contains(key)) {
            genericParamStaging[key] = ArrayList<GenericParamRow>()
        }
        genericParamStaging[key].add(row)
    }

    public func interfaceImpl(classRow: Int64, interfaceType: MetadataType): Unit {
        let (tag, rowValue) = typeDefOrRefForType(interfaceType)
        let row = InterfaceImplRow()
        row.classRow = classRow
        row.interfaceTag = tag
        row.interfaceRow = rowValue
        interfaceImpls.add(row)
    }

    public func classLayout(parent: Int64, packingSize: UInt16, classSize: UInt32): Unit {
        let row = ClassLayoutRow()
        row.packingSize = packingSize
        row.classSize = classSize
        row.parent = parent
        classLayouts.add(row)
    }

    public func nestedClass(inner: Int64, outer: Int64): Unit {
        let row = NestedClassRow()
        row.nestedClass = inner
        row.enclosingClass = outer
        nestedClasses.add(row)
    }

    public func implMap(method: Int64, flags: PInvokeAttributes, importName: String, importScope: String): Unit {
        let row = ImplMapRow()
        row.mappingFlags = flags.value
        row.memberTable = TABLE_METHOD_DEF
        row.memberRow = method
        row.importName = strings.insert(importName)
        row.importScope = ensureModuleRef(importScope)
        implMaps.add(row)
    }

    public func toBytes(): Array<Byte> {
        let records = padTo4(buildTablesStream())
        let stringsBytes = strings.toBytes()
        let guidBytes = Array<Byte>(16, repeat: 0u8)
        let blobBytes = blobs.toBytes()
        let metadataVersion = versionBytes()
        let metadataHeaderSize: Int64 = 4 + 2 + 2 + 4 + 4 + Int64(metadataVersion.size) + 2 + 2
        let streamHeadersSize: Int64 = (8 + 4) + (8 + 12) + (8 + 8) + (8 + 8)
        let metadataSize = metadataHeaderSize + streamHeadersSize + Int64(records.size) + Int64(stringsBytes.size) + Int64(guidBytes.size) + Int64(blobBytes.size)
        let sectionVirtualSize = CLR_HEADER_SIZE + metadataSize
        let sectionRawSize = roundUp(sectionVirtualSize, FILE_ALIGNMENT)
        let sizeOfImage = roundUp(SECTION_ALIGNMENT + sectionRawSize, SECTION_ALIGNMENT)

        let buffer = ArrayList<Byte>()

        writeDosHeader(buffer)
        writePeSignature(buffer)
        writeFileHeader(buffer)
        writeOptionalHeader(buffer, sizeOfImage)
        writeSectionHeader(buffer, sectionVirtualSize, sectionRawSize)
        padBuffer(buffer, FILE_ALIGNMENT)

        let metadataRva = SECTION_ALIGNMENT + CLR_HEADER_SIZE
        writeClrHeader(buffer, metadataRva, metadataSize)

        let metadataStart = Int64(buffer.size)
        writeMetadataHeader(buffer, metadataVersion)

        let streamOffset = Int64(buffer.size) - metadataStart + streamHeadersSize
        writeStreamHeader(buffer, streamOffset, Int64(records.size), "#~", 4)
        writeStreamHeader(buffer, streamOffset + Int64(records.size), Int64(stringsBytes.size), "#Strings", 12)
        writeStreamHeader(buffer, streamOffset + Int64(records.size) + Int64(stringsBytes.size), Int64(guidBytes.size), "#GUID", 8)
        writeStreamHeader(buffer, streamOffset + Int64(records.size) + Int64(stringsBytes.size) + Int64(guidBytes.size), Int64(blobBytes.size), "#Blob", 8)

        appendBytes(buffer, records)
        appendBytes(buffer, stringsBytes)
        appendBytes(buffer, guidBytes)
        appendBytes(buffer, blobBytes)
        padBuffer(buffer, FILE_ALIGNMENT + sectionRawSize)

        return toArray(buffer)
    }

    public func writeTo(path: String): Unit {
        File.writeTo(path, toBytes())
    }

    func ensureAssemblyRef(assemblyName: String): Int64 {
        if (assemblyRefIndex.contains(assemblyName)) {
            return assemblyRefIndex[assemblyName]
        }

        let row = AssemblyRefRow()
        if (assemblyName == "System") {
            row.majorVersion = 4u16
            row.minorVersion = 0u16
            row.buildNumber = 0u16
            row.revisionNumber = 0u16
            row.flags = 0u32
            row.publicKeyOrToken = blobs.insert([0xB7u8, 0x7Au8, 0x5Cu8, 0x56u8, 0x19u8, 0x34u8, 0xE0u8, 0x89u8])
            row.name = strings.insert("mscorlib")
        } else {
            row.name = strings.insert(assemblyName)
        }
        assemblyRefs.add(row)

        let index = Int64(assemblyRefs.size) - 1
        assemblyRefIndex[assemblyName] = index
        return index
    }

    func ensureModuleRef(name: String): Int64 {
        if (moduleRefIndex.contains(name)) {
            return moduleRefIndex[name]
        }

        let row = ModuleRefRow()
        row.name = strings.insert(name)
        moduleRefs.add(row)

        let index = Int64(moduleRefs.size) - 1
        moduleRefIndex[name] = index
        return index
    }

    func ensureTypeRef(namespace: String, name: String): Int64 {
        let key = typeRefKey(namespace, name)
        if (typeRefIndex.contains(key)) {
            return typeRefIndex[key]
        }

        let row = TypeRefRow()
        match (splitNestedName(name)) {
            case Some((parentName, leafName)) =>
                let enclosing = ensureTypeRef(namespace, parentName)
                row.scopeTag = resolutionScopeTag(TABLE_TYPE_REF)
                row.scopeRow = enclosing
                row.name = strings.insert(leafName)
                row.namespace = strings.insert("")
            case None =>
                match (resolveAssemblyName(namespace, name)) {
                    case Some(assemblyName) =>
                        row.scopeTag = resolutionScopeTag(TABLE_ASSEMBLY_REF)
                        row.scopeRow = ensureAssemblyRef(assemblyName)
                    case None =>
                        row.scopeTag = resolutionScopeTag(TABLE_MODULE)
                        row.scopeRow = 0
                }
                row.name = strings.insert(name)
                row.namespace = strings.insert(namespace)
        }
        typeRefs.add(row)

        let index = Int64(typeRefs.size) - 1
        typeRefIndex[key] = index
        return index
    }

    func resolveAssemblyName(namespace: String, name: String): Option<String> {
        match (reference) {
            case Some(referenceIndex) =>
                match (referenceIndex.assemblyName(namespace, trimTick(name))) {
                    case Some(assemblyName) => return Some(assemblyName)
                    case None => ()
                }
            case None => ()
        }

        if (namespace == "System") {
            return Some("System")
        }
        return None
    }

    func typeDefOrRefForType(ty: MetadataType): (Int64, Int64) {
        match (ty) {
            case MetadataType.ClassName(typeName) =>
                if (typeName.generics.isEmpty()) {
                    return (1, ensureTypeRef(typeName.namespace, typeName.name))
                }
                return (2, typeSpec(typeName.namespace, typeName.name, genericsToArray(typeName.generics)))
            case MetadataType.ValueName(typeName) =>
                if (typeName.generics.isEmpty()) {
                    return (1, ensureTypeRef(typeName.namespace, typeName.name))
                }
                return (2, typeSpec(typeName.namespace, typeName.name, genericsToArray(typeName.generics)))
            case MetadataType.Union(typeName) =>
                if (typeName.generics.isEmpty()) {
                    return (1, ensureTypeRef(typeName.namespace, typeName.name))
                }
                return (2, typeSpec(typeName.namespace, typeName.name, genericsToArray(typeName.generics)))
            case _ =>
                throw Exception("TypeDefOrRef requires class, value, or union metadata type")
        }
    }

    func buildTablesStream(): Array<Byte> {
        let orderedConstants = materializeConstantRows(constantStaging)
        let orderedAttributes = materializeAttributeRows(attributeStaging)
        let orderedGenericParams = materializeGenericParamRows(genericParamStaging)
        sortClassLayoutRows(classLayouts)
        sortFieldLayoutRows(fieldLayouts)
        sortInterfaceImplRows(interfaceImpls)
        sortImplMapRows(implMaps)
        sortNestedClassRows(nestedClasses)

        let validBits = computeValidBits(orderedConstants, orderedAttributes, orderedGenericParams)
        let resolutionScopeSize = codedIndexSize([Int64(modules.size), Int64(moduleRefs.size), Int64(assemblyRefs.size), Int64(typeRefs.size)])
        let typeDefOrRefSize = codedIndexSize([Int64(typeDefs.size), Int64(typeRefs.size), Int64(typeSpecs.size)])
        let hasConstantSize = codedIndexSize([Int64(fields.size), Int64(params.size), 0])
        let typeOrMethodDefSize = codedIndexSize([Int64(typeDefs.size), Int64(methodDefs.size)])
        let memberRefParentSize = codedIndexSize([Int64(typeDefs.size), Int64(typeRefs.size), Int64(moduleRefs.size), Int64(methodDefs.size), Int64(typeSpecs.size)])
        let customAttributeTypeSize = codedIndexSize([Int64(methodDefs.size), Int64(memberRefs.size), 0, 0, 0])
        let hasCustomAttributeSize = codedIndexSize([
            Int64(methodDefs.size),
            Int64(fields.size),
            Int64(typeRefs.size),
            Int64(typeDefs.size),
            Int64(params.size),
            Int64(interfaceImpls.size),
            Int64(memberRefs.size),
            Int64(modules.size),
            0,
            0,
            0,
            Int64(moduleRefs.size),
            Int64(typeSpecs.size),
            Int64(assemblies.size),
            Int64(assemblyRefs.size),
            0,
            0,
            0,
            Int64(orderedGenericParams.size),
            0,
            0
        ])
        let memberForwardedSize = codedIndexSize([Int64(fields.size), Int64(methodDefs.size)])
        let typeDefIndexSize = tableIndexSize(Int64(typeDefs.size))
        let fieldIndexSize = tableIndexSize(Int64(fields.size))
        let methodIndexSize = tableIndexSize(Int64(methodDefs.size))
        let paramIndexSize = tableIndexSize(Int64(params.size))
        let moduleRefIndexSize = tableIndexSize(Int64(moduleRefs.size))

        let buffer = ArrayList<Byte>()
        writeU32(buffer, 0u32)
        buffer.add(2u8)
        buffer.add(0u8)
        buffer.add(0b111u8)
        buffer.add(0u8)
        writeU64(buffer, UInt64(validBits))
        writeU64(buffer, 0u64)

        if (isTableValid(validBits, 0x00)) { writeU32(buffer, UInt32(modules.size)) }
        if (isTableValid(validBits, 0x01)) { writeU32(buffer, UInt32(typeRefs.size)) }
        if (isTableValid(validBits, 0x02)) { writeU32(buffer, UInt32(typeDefs.size)) }
        if (isTableValid(validBits, 0x04)) { writeU32(buffer, UInt32(fields.size)) }
        if (isTableValid(validBits, 0x06)) { writeU32(buffer, UInt32(methodDefs.size)) }
        if (isTableValid(validBits, 0x08)) { writeU32(buffer, UInt32(params.size)) }
        if (isTableValid(validBits, 0x09)) { writeU32(buffer, UInt32(interfaceImpls.size)) }
        if (isTableValid(validBits, 0x0A)) { writeU32(buffer, UInt32(memberRefs.size)) }
        if (isTableValid(validBits, 0x0B)) { writeU32(buffer, UInt32(orderedConstants.size)) }
        if (isTableValid(validBits, 0x0C)) { writeU32(buffer, UInt32(orderedAttributes.size)) }
        if (isTableValid(validBits, 0x0F)) { writeU32(buffer, UInt32(classLayouts.size)) }
        if (isTableValid(validBits, 0x10)) { writeU32(buffer, UInt32(fieldLayouts.size)) }
        if (isTableValid(validBits, 0x1A)) { writeU32(buffer, UInt32(moduleRefs.size)) }
        if (isTableValid(validBits, 0x1B)) { writeU32(buffer, UInt32(typeSpecs.size)) }
        if (isTableValid(validBits, 0x1C)) { writeU32(buffer, UInt32(implMaps.size)) }
        if (isTableValid(validBits, 0x20)) { writeU32(buffer, UInt32(assemblies.size)) }
        if (isTableValid(validBits, 0x23)) { writeU32(buffer, UInt32(assemblyRefs.size)) }
        if (isTableValid(validBits, 0x29)) { writeU32(buffer, UInt32(nestedClasses.size)) }
        if (isTableValid(validBits, 0x2A)) { writeU32(buffer, UInt32(orderedGenericParams.size)) }

        for (row in modules) {
            writeU16(buffer, row.generation)
            writeU32(buffer, UInt32(row.name))
            writeU32(buffer, row.mvid)
            writeU32(buffer, row.encId)
            writeU32(buffer, row.encBaseId)
        }

        for (row in typeRefs) {
            writeCode(buffer, encodeCodedIndex(row.scopeTag, row.scopeRow, CODED_RESOLUTION_SCOPE_BITS), resolutionScopeSize)
            writeU32(buffer, UInt32(row.name))
            writeU32(buffer, UInt32(row.namespace))
        }

        for (row in typeDefs) {
            writeU32(buffer, row.flags)
            writeU32(buffer, UInt32(row.name))
            writeU32(buffer, UInt32(row.namespace))
            if (row.extendsTag < 0) {
                writeCode(buffer, 0, typeDefOrRefSize)
            } else {
                writeCode(buffer, encodeCodedIndex(row.extendsTag, row.extendsRow, CODED_TYPE_DEF_OR_REF_BITS), typeDefOrRefSize)
            }
            writeIndex(buffer, row.fieldList, Int64(fields.size), fieldIndexSize)
            writeIndex(buffer, row.methodList, Int64(methodDefs.size), methodIndexSize)
        }

        for (row in fields) {
            writeU16(buffer, row.flags)
            writeU32(buffer, UInt32(row.name))
            writeU32(buffer, UInt32(row.signature))
        }

        for (row in methodDefs) {
            writeU32(buffer, row.rva)
            writeU16(buffer, row.implFlags)
            writeU16(buffer, row.flags)
            writeU32(buffer, UInt32(row.name))
            writeU32(buffer, UInt32(row.signature))
            writeIndex(buffer, row.paramList, Int64(params.size), paramIndexSize)
        }

        for (row in params) {
            writeU16(buffer, row.flags)
            writeU16(buffer, row.sequence)
            writeU32(buffer, UInt32(row.name))
        }

        for (row in interfaceImpls) {
            writeIndex(buffer, row.classRow, Int64(typeDefs.size), typeDefIndexSize)
            writeCode(buffer, encodeCodedIndex(row.interfaceTag, row.interfaceRow, CODED_TYPE_DEF_OR_REF_BITS), typeDefOrRefSize)
        }

        for (row in memberRefs) {
            writeCode(buffer, encodeCodedIndex(row.parentTag, row.parentRow, CODED_MEMBER_REF_PARENT_BITS), memberRefParentSize)
            writeU32(buffer, UInt32(row.name))
            writeU32(buffer, UInt32(row.signature))
        }

        for (row in orderedConstants) {
            buffer.add(row.ty)
            buffer.add(0u8)
            writeCode(buffer, encodeCodedIndex(hasConstantTag(row.parentTable), row.parentRow, CODED_HAS_CONSTANT_BITS), hasConstantSize)
            writeU32(buffer, UInt32(row.value))
        }

        for (row in orderedAttributes) {
            let parent = encodeHasCustomAttribute(row.parentTable, row.parentRow).getOrThrow()
            writeCode(buffer, parent, hasCustomAttributeSize)
            writeCode(buffer, encodeCodedIndex(customAttributeTypeTag(row.typeTable), row.typeRow, CODED_CUSTOM_ATTRIBUTE_TYPE_BITS), customAttributeTypeSize)
            writeU32(buffer, UInt32(row.value))
        }

        for (row in classLayouts) {
            writeU16(buffer, row.packingSize)
            writeU32(buffer, row.classSize)
            writeIndex(buffer, row.parent, Int64(typeDefs.size), typeDefIndexSize)
        }

        for (row in fieldLayouts) {
            writeU32(buffer, row.offset)
            writeIndex(buffer, row.field, Int64(fields.size), fieldIndexSize)
        }

        for (row in moduleRefs) {
            writeU32(buffer, UInt32(row.name))
        }

        for (row in typeSpecs) {
            writeU32(buffer, UInt32(row.signature))
        }

        for (row in implMaps) {
            writeU16(buffer, row.mappingFlags)
            writeCode(buffer, encodeCodedIndex(memberForwardedTag(row.memberTable), row.memberRow, CODED_MEMBER_FORWARDED_BITS), memberForwardedSize)
            writeU32(buffer, UInt32(row.importName))
            writeIndex(buffer, row.importScope, Int64(moduleRefs.size), moduleRefIndexSize)
        }

        for (row in assemblies) {
            writeU32(buffer, row.hashAlgId)
            writeU16(buffer, row.majorVersion)
            writeU16(buffer, row.minorVersion)
            writeU16(buffer, row.buildNumber)
            writeU16(buffer, row.revisionNumber)
            writeU32(buffer, row.flags)
            writeU32(buffer, UInt32(row.publicKey))
            writeU32(buffer, UInt32(row.name))
            writeU32(buffer, UInt32(row.culture))
        }

        for (row in assemblyRefs) {
            writeU16(buffer, row.majorVersion)
            writeU16(buffer, row.minorVersion)
            writeU16(buffer, row.buildNumber)
            writeU16(buffer, row.revisionNumber)
            writeU32(buffer, row.flags)
            writeU32(buffer, UInt32(row.publicKeyOrToken))
            writeU32(buffer, UInt32(row.name))
            writeU32(buffer, UInt32(row.culture))
            writeU32(buffer, UInt32(row.hashValue))
        }

        for (row in nestedClasses) {
            writeIndex(buffer, row.nestedClass, Int64(typeDefs.size), typeDefIndexSize)
            writeIndex(buffer, row.enclosingClass, Int64(typeDefs.size), typeDefIndexSize)
        }

        for (row in orderedGenericParams) {
            writeU16(buffer, row.number)
            writeU16(buffer, row.flags)
            writeCode(buffer, encodeCodedIndex(typeOrMethodDefTag(row.ownerTable), row.ownerRow, CODED_TYPE_OR_METHOD_DEF_BITS), typeOrMethodDefSize)
            writeU32(buffer, UInt32(row.name))
        }

        return toArray(buffer)
    }

    func encodeFieldSignature(ty: MetadataType): Array<Byte> {
        let buffer = ArrayList<Byte>()
        buffer.add(0x06u8)
        appendType(buffer, ty)
        return toArray(buffer)
    }

    func encodeMethodSignature(signature: MethodSignature): Array<Byte> {
        let buffer = ArrayList<Byte>()
        buffer.add(signature.flags)
        writeCompressed(buffer, Int64(signature.paramTypes.size))
        appendType(buffer, signature.returnType)
        for (ty in signature.paramTypes) {
            appendType(buffer, ty)
        }
        return toArray(buffer)
    }

    func encodeConstantValue(value: MetadataValue, ty: MetadataType): Array<Byte> {
        let buffer = ArrayList<Byte>()
        appendConstantValue(buffer, value, ty)
        return toArray(buffer)
    }

    func encodeAttributeValue(values: ArrayList<(String, MetadataValue)>): Array<Byte> {
        let buffer = ArrayList<Byte>()
        writeU16(buffer, 1u16)

        var fixedCount: Int64 = 0
        while (fixedCount < Int64(values.size) && values[fixedCount][0].isEmpty()) {
            appendAttributeMetadataValue(buffer, values[fixedCount][1])
            fixedCount += 1
        }

        writeU16(buffer, UInt16(Int64(values.size) - fixedCount))

        var index: Int64 = fixedCount
        while (index < Int64(values.size)) {
            let name = values[index][0]
            let value = values[index][1]
            buffer.add(0x53u8)
            appendAttributeNamedType(buffer, value)
            writeSerString(buffer, name)
            appendAttributeMetadataValue(buffer, value)
            index += 1
        }

        return toArray(buffer)
    }

    func appendType(buffer: ArrayList<Byte>, ty: MetadataType): Unit {
        match (ty) {
            case MetadataType.Void => buffer.add(ELEMENT_TYPE_VOID)
            case MetadataType.Boolean => buffer.add(ELEMENT_TYPE_BOOLEAN)
            case MetadataType.Char => buffer.add(ELEMENT_TYPE_CHAR)
            case MetadataType.I8 => buffer.add(ELEMENT_TYPE_I1)
            case MetadataType.U8 => buffer.add(ELEMENT_TYPE_U1)
            case MetadataType.I16 => buffer.add(ELEMENT_TYPE_I2)
            case MetadataType.U16 => buffer.add(ELEMENT_TYPE_U2)
            case MetadataType.I32 => buffer.add(ELEMENT_TYPE_I4)
            case MetadataType.U32 => buffer.add(ELEMENT_TYPE_U4)
            case MetadataType.I64 => buffer.add(ELEMENT_TYPE_I8)
            case MetadataType.U64 => buffer.add(ELEMENT_TYPE_U8)
            case MetadataType.F32 => buffer.add(ELEMENT_TYPE_R4)
            case MetadataType.F64 => buffer.add(ELEMENT_TYPE_R8)
            case MetadataType.ISize => buffer.add(ELEMENT_TYPE_I)
            case MetadataType.USize => buffer.add(ELEMENT_TYPE_U)
            case MetadataType.MdString => buffer.add(ELEMENT_TYPE_STRING)
            case MetadataType.MdObject => buffer.add(ELEMENT_TYPE_OBJECT)
            case MetadataType.MdArray(inner) =>
                buffer.add(ELEMENT_TYPE_SZARRAY)
                appendType(buffer, inner)
            case MetadataType.RefMut(inner) =>
                buffer.add(ELEMENT_TYPE_BYREF)
                appendType(buffer, inner)
            case MetadataType.RefConst(inner) =>
                buffer.add(ELEMENT_TYPE_CMOD_REQD)
                let constRef = ensureTypeRef("System.Runtime.CompilerServices", "IsConst")
                writeCompressed(buffer, encodeCodedIndex(1, constRef, CODED_TYPE_DEF_OR_REF_BITS))
                buffer.add(ELEMENT_TYPE_BYREF)
                appendType(buffer, inner)
            case MetadataType.PtrMut(inner, pointers) =>
                var i: Int64 = 0
                while (i < pointers) {
                    buffer.add(ELEMENT_TYPE_PTR)
                    i += 1
                }
                appendType(buffer, inner)
            case MetadataType.PtrConst(inner, pointers) =>
                buffer.add(ELEMENT_TYPE_CMOD_REQD)
                let constRef = ensureTypeRef("System.Runtime.CompilerServices", "IsConst")
                writeCompressed(buffer, encodeCodedIndex(1, constRef, CODED_TYPE_DEF_OR_REF_BITS))
                var i: Int64 = 0
                while (i < pointers) {
                    buffer.add(ELEMENT_TYPE_PTR)
                    i += 1
                }
                appendType(buffer, inner)
            case MetadataType.ArrayFixed(inner, len) =>
                buffer.add(ELEMENT_TYPE_ARRAY)
                appendType(buffer, inner)
                writeCompressed(buffer, 1)
                writeCompressed(buffer, 1)
                writeCompressed(buffer, len)
                writeCompressed(buffer, 0)
            case MetadataType.Generic(_, number) =>
                buffer.add(ELEMENT_TYPE_VAR)
                writeCompressed(buffer, Int64(number))
            case MetadataType.ClassName(tn) =>
                appendTypeName(buffer, false, tn.namespace, tn.name, tn.generics)
            case MetadataType.ValueName(tn) =>
                appendTypeName(buffer, true, tn.namespace, tn.name, tn.generics)
            case MetadataType.Union(tn) =>
                appendTypeName(buffer, true, tn.namespace, tn.name, tn.generics)
            case MetadataType.Packed(inner, _) =>
                appendType(buffer, inner)
        }
    }

    func appendTypeName(buffer: ArrayList<Byte>, isValueType: Bool, namespace: String, name: String, generics: ArrayList<MetadataType>): Unit {
        if (!generics.isEmpty()) {
            buffer.add(ELEMENT_TYPE_GENERICINST)
            buffer.add(if (isValueType) { ELEMENT_TYPE_VALUETYPE } else { ELEMENT_TYPE_CLASS })
            let genericRef = ensureTypeRef(namespace, "${name}`${generics.size}")
            writeCompressed(buffer, encodeCodedIndex(1, genericRef, CODED_TYPE_DEF_OR_REF_BITS))
            writeCompressed(buffer, Int64(generics.size))
            for (generic in generics) {
                appendType(buffer, generic)
            }
            return
        }

        buffer.add(if (isValueType) { ELEMENT_TYPE_VALUETYPE } else { ELEMENT_TYPE_CLASS })
        let row = ensureTypeRef(namespace, name)
        writeCompressed(buffer, encodeCodedIndex(1, row, CODED_TYPE_DEF_OR_REF_BITS))
    }

    func computeValidBits(
        constantRows: ArrayList<ConstantRow>,
        attributeRows: ArrayList<AttributeRow>,
        genericParamRows: ArrayList<GenericParamRow>
    ): Int64 {
        var bits: Int64 = 0
        if (!modules.isEmpty()) { bits |= 1 << 0x00 }
        if (!typeRefs.isEmpty()) { bits |= 1 << 0x01 }
        if (!typeDefs.isEmpty()) { bits |= 1 << 0x02 }
        if (!fields.isEmpty()) { bits |= 1 << 0x04 }
        if (!methodDefs.isEmpty()) { bits |= 1 << 0x06 }
        if (!params.isEmpty()) { bits |= 1 << 0x08 }
        if (!interfaceImpls.isEmpty()) { bits |= 1 << 0x09 }
        if (!memberRefs.isEmpty()) { bits |= 1 << 0x0A }
        if (!constantRows.isEmpty()) { bits |= 1 << 0x0B }
        if (!attributeRows.isEmpty()) { bits |= 1 << 0x0C }
        if (!classLayouts.isEmpty()) { bits |= 1 << 0x0F }
        if (!fieldLayouts.isEmpty()) { bits |= 1 << 0x10 }
        if (!moduleRefs.isEmpty()) { bits |= 1 << 0x1A }
        if (!typeSpecs.isEmpty()) { bits |= 1 << 0x1B }
        if (!implMaps.isEmpty()) { bits |= 1 << 0x1C }
        if (!assemblies.isEmpty()) { bits |= 1 << 0x20 }
        if (!assemblyRefs.isEmpty()) { bits |= 1 << 0x23 }
        if (!nestedClasses.isEmpty()) { bits |= 1 << 0x29 }
        if (!genericParamRows.isEmpty()) { bits |= 1 << 0x2A }
        return bits
    }
}

func typeRefKey(namespace: String, name: String): String {
    return "${namespace}|${name}"
}

func constantStageKey(parentTable: Int64, parentRow: Int64): ConstantStageKey {
    return ConstantStageKey(parentTable, parentRow)
}

func attributeStageKey(parentTable: Int64, parentRow: Int64): AttributeStageKey {
    return AttributeStageKey(parentTable, parentRow)
}

func genericParamStageKey(ownerTable: Int64, ownerRow: Int64): GenericParamStageKey {
    return GenericParamStageKey(ownerTable, ownerRow)
}

func constantStageSortKey(parentTable: Int64, parentRow: Int64): Int64 {
    return encodeCodedIndex(hasConstantTag(parentTable), parentRow, CODED_HAS_CONSTANT_BITS)
}

func attributeStageSortKey(parentTable: Int64, parentRow: Int64): Int64 {
    return encodeHasCustomAttribute(parentTable, parentRow).getOrThrow()
}

func genericParamStageSortKey(ownerTable: Int64, ownerRow: Int64): Int64 {
    return encodeCodedIndex(typeOrMethodDefTag(ownerTable), ownerRow, CODED_TYPE_OR_METHOD_DEF_BITS)
}

func materializeConstantRows(staging: TreeMap<ConstantStageKey, ConstantRow>): ArrayList<ConstantRow> {
    let result = ArrayList<ConstantRow>()
    for ((_, row) in staging) {
        result.add(row)
    }
    sortConstantRows(result)
    return result
}

func materializeAttributeRows(staging: TreeMap<AttributeStageKey, ArrayList<AttributeRow>>): ArrayList<AttributeRow> {
    let result = ArrayList<AttributeRow>()
    for ((_, rows) in staging) {
        for (row in rows) {
            result.add(row)
        }
    }
    sortAttributeRows(result)
    return result
}

func materializeGenericParamRows(staging: TreeMap<GenericParamStageKey, ArrayList<GenericParamRow>>): ArrayList<GenericParamRow> {
    let result = ArrayList<GenericParamRow>()
    for ((_, rows) in staging) {
        for (row in rows) {
            result.add(row)
        }
    }
    sortGenericParamRows(result)
    return result
}

func splitNestedName(name: String): Option<(String, String)> {
    let arr = name.toArray()
    var lastSlash: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        if (arr[i] == b'/') {
            lastSlash = i
        }
        i += 1
    }

    if (lastSlash <= 0 || lastSlash >= Int64(arr.size) - 1) {
        return None
    }

    return Some((
        String.fromUtf8(arr[0..lastSlash]),
        String.fromUtf8(arr[lastSlash + 1..Int64(arr.size)])
    ))
}

func genericsToArray(values: ArrayList<MetadataType>): Array<MetadataType> {
    var result = Array<MetadataType>(values.size, {_ => MetadataType.Void})
    var index: Int64 = 0
    while (index < Int64(values.size)) {
        result[index] = values[index]
        index += 1
    }
    return result
}

func hasConstantTag(table: Int64): Int64 {
    if (table == TABLE_FIELD) {
        return 0
    }
    if (table == TABLE_METHOD_PARAM) {
        return 1
    }
    throw Exception("unsupported HasConstant table: ${table}")
}

func customAttributeTypeTag(table: Int64): Int64 {
    if (table == TABLE_METHOD_DEF) {
        return 2
    }
    if (table == TABLE_MEMBER_REF) {
        return 3
    }
    throw Exception("unsupported CustomAttributeType table: ${table}")
}

func memberRefParentTag(table: Int64): Int64 {
    if (table == TABLE_TYPE_DEF) {
        return 0
    }
    if (table == TABLE_TYPE_REF) {
        return 1
    }
    if (table == TABLE_MODULE_REF) {
        return 2
    }
    if (table == TABLE_METHOD_DEF) {
        return 3
    }
    if (table == TABLE_TYPE_SPEC) {
        return 4
    }
    throw Exception("unsupported MemberRef parent table: ${table}")
}

func memberForwardedTag(table: Int64): Int64 {
    if (table == TABLE_FIELD) {
        return 0
    }
    if (table == TABLE_METHOD_DEF) {
        return 1
    }
    throw Exception("unsupported MemberForwarded table: ${table}")
}

func typeOrMethodDefTag(table: Int64): Int64 {
    if (table == TABLE_TYPE_DEF) {
        return 0
    }
    if (table == TABLE_METHOD_DEF) {
        return 1
    }
    throw Exception("unsupported TypeOrMethodDef table: ${table}")
}

func resolutionScopeTag(table: Int64): Int64 {
    if (table == TABLE_MODULE) {
        return 0
    }
    if (table == TABLE_MODULE_REF) {
        return 1
    }
    if (table == TABLE_ASSEMBLY_REF) {
        return 2
    }
    if (table == TABLE_TYPE_REF) {
        return 3
    }
    throw Exception("unsupported ResolutionScope table: ${table}")
}

func sortConstantRows(rows: ArrayList<ConstantRow>): Unit {
    var i: Int64 = 1
    while (i < Int64(rows.size)) {
        let key = rows[i]
        var j = i - 1
        while (j >= 0 && constantSortKey(rows[j]) > constantSortKey(key)) {
            rows[j + 1] = rows[j]
            j -= 1
        }
        rows[j + 1] = key
        i += 1
    }
}

func constantSortKey(row: ConstantRow): Int64 {
    return encodeCodedIndex(hasConstantTag(row.parentTable), row.parentRow, CODED_HAS_CONSTANT_BITS)
}

func sortAttributeRows(rows: ArrayList<AttributeRow>): Unit {
    var i: Int64 = 1
    while (i < Int64(rows.size)) {
        let key = rows[i]
        var j = i - 1
        while (j >= 0 && attributeSortKey(rows[j]) > attributeSortKey(key)) {
            rows[j + 1] = rows[j]
            j -= 1
        }
        rows[j + 1] = key
        i += 1
    }
}

func attributeSortKey(row: AttributeRow): Int64 {
    return encodeHasCustomAttribute(row.parentTable, row.parentRow).getOrThrow()
}

func sortClassLayoutRows(rows: ArrayList<ClassLayoutRow>): Unit {
    var i: Int64 = 1
    while (i < Int64(rows.size)) {
        let key = rows[i]
        var j = i - 1
        while (j >= 0 && rows[j].parent > key.parent) {
            rows[j + 1] = rows[j]
            j -= 1
        }
        rows[j + 1] = key
        i += 1
    }
}

func sortFieldLayoutRows(rows: ArrayList<FieldLayoutRow>): Unit {
    var i: Int64 = 1
    while (i < Int64(rows.size)) {
        let key = rows[i]
        var j = i - 1
        while (j >= 0 && rows[j].field > key.field) {
            rows[j + 1] = rows[j]
            j -= 1
        }
        rows[j + 1] = key
        i += 1
    }
}

func sortGenericParamRows(rows: ArrayList<GenericParamRow>): Unit {
    var i: Int64 = 1
    while (i < Int64(rows.size)) {
        let key = rows[i]
        var j = i - 1
        while (j >= 0 && genericParamSortKey(rows[j]) > genericParamSortKey(key)) {
            rows[j + 1] = rows[j]
            j -= 1
        }
        rows[j + 1] = key
        i += 1
    }
}

func genericParamSortKey(row: GenericParamRow): Int64 {
    return (encodeCodedIndex(typeOrMethodDefTag(row.ownerTable), row.ownerRow, CODED_TYPE_OR_METHOD_DEF_BITS) << 16) + Int64(row.number)
}

func sortInterfaceImplRows(rows: ArrayList<InterfaceImplRow>): Unit {
    var i: Int64 = 1
    while (i < Int64(rows.size)) {
        let key = rows[i]
        var j = i - 1
        while (j >= 0 && rows[j].classRow > key.classRow) {
            rows[j + 1] = rows[j]
            j -= 1
        }
        rows[j + 1] = key
        i += 1
    }
}

func sortImplMapRows(rows: ArrayList<ImplMapRow>): Unit {
    var i: Int64 = 1
    while (i < Int64(rows.size)) {
        let key = rows[i]
        var j = i - 1
        while (j >= 0 && implMapSortKey(rows[j]) > implMapSortKey(key)) {
            rows[j + 1] = rows[j]
            j -= 1
        }
        rows[j + 1] = key
        i += 1
    }
}

func implMapSortKey(row: ImplMapRow): Int64 {
    return encodeCodedIndex(memberForwardedTag(row.memberTable), row.memberRow, CODED_MEMBER_FORWARDED_BITS)
}

func sortNestedClassRows(rows: ArrayList<NestedClassRow>): Unit {
    var i: Int64 = 1
    while (i < Int64(rows.size)) {
        let key = rows[i]
        var j = i - 1
        while (j >= 0 && rows[j].nestedClass > key.nestedClass) {
            rows[j + 1] = rows[j]
            j -= 1
        }
        rows[j + 1] = key
        i += 1
    }
}

func appendConstantValue(buffer: ArrayList<Byte>, value: MetadataValue, ty: MetadataType): Unit {
    match (value) {
        case MetadataValue.ValBool(v) =>
            if (ty.elementTypeCode() != ELEMENT_TYPE_BOOLEAN) {
                throw Exception("constant bool type mismatch")
            }
            buffer.add(if (v) { 1u8 } else { 0u8 })
        case MetadataValue.ValU8(v) =>
            buffer.add(v)
        case MetadataValue.ValI8(v) =>
            buffer.add(UInt8(v))
        case MetadataValue.ValU16(v) =>
            writeU16(buffer, v)
        case MetadataValue.ValI16(v) =>
            writeU16(buffer, UInt16(v))
        case MetadataValue.ValU32(v) =>
            writeU32(buffer, v)
        case MetadataValue.ValI32(v) =>
            writeU32(buffer, UInt32(v))
        case MetadataValue.ValU64(v) =>
            writeU64(buffer, v)
        case MetadataValue.ValI64(v) =>
            writeU64(buffer, UInt64(v))
        case MetadataValue.ValF32(v) =>
            writeU32(buffer, v.toBits())
        case MetadataValue.ValF64(v) =>
            writeU64(buffer, v.toBits())
        case MetadataValue.ValUtf8(v) =>
            if (ty.elementTypeCode() != ELEMENT_TYPE_STRING) {
                throw Exception("constant string type mismatch")
            }
            writeUtf16Raw(buffer, v)
        case MetadataValue.ValUtf16(v) =>
            if (ty.elementTypeCode() != ELEMENT_TYPE_STRING) {
                throw Exception("constant string type mismatch")
            }
            writeUtf16Raw(buffer, v)
        case MetadataValue.ValEnum(_, inner) =>
            appendConstantValue(buffer, inner, ty)
        case _ =>
            throw Exception("unsupported constant value")
    }
}

func appendAttributeNamedType(buffer: ArrayList<Byte>, value: MetadataValue): Unit {
    match (value) {
        case MetadataValue.ValEnum(typeName, _) =>
            buffer.add(0x55u8)
            if (typeName.namespace.isEmpty()) {
                writeSerString(buffer, typeName.name)
            } else {
                writeSerString(buffer, "${typeName.namespace}.${typeName.name}")
            }
        case _ =>
            buffer.add(metadataValueTypeCode(value))
    }
}

func appendAttributeMetadataValue(buffer: ArrayList<Byte>, value: MetadataValue): Unit {
    match (value) {
        case MetadataValue.ValBool(v) =>
            buffer.add(if (v) { 1u8 } else { 0u8 })
        case MetadataValue.ValU8(v) =>
            buffer.add(v)
        case MetadataValue.ValI8(v) =>
            buffer.add(UInt8(v))
        case MetadataValue.ValU16(v) =>
            writeU16(buffer, v)
        case MetadataValue.ValI16(v) =>
            writeU16(buffer, UInt16(v))
        case MetadataValue.ValU32(v) =>
            writeU32(buffer, v)
        case MetadataValue.ValI32(v) =>
            writeU32(buffer, UInt32(v))
        case MetadataValue.ValU64(v) =>
            writeU64(buffer, v)
        case MetadataValue.ValI64(v) =>
            writeU64(buffer, UInt64(v))
        case MetadataValue.ValF32(v) =>
            writeU32(buffer, v.toBits())
        case MetadataValue.ValF64(v) =>
            writeU64(buffer, v.toBits())
        case MetadataValue.ValUtf8(v) =>
            writeSerString(buffer, v)
        case MetadataValue.ValUtf16(v) =>
            writeSerString(buffer, v)
        case MetadataValue.ValTypeName(typeName) =>
            if (typeName.namespace.isEmpty()) {
                writeSerString(buffer, typeName.name)
            } else {
                writeSerString(buffer, "${typeName.namespace}.${typeName.name}")
            }
        case MetadataValue.ValEnum(_, inner) =>
            appendAttributeMetadataValue(buffer, inner)
    }
}

func metadataValueTypeCode(value: MetadataValue): UInt8 {
    match (value) {
        case MetadataValue.ValBool(_) => ELEMENT_TYPE_BOOLEAN
        case MetadataValue.ValU8(_) => ELEMENT_TYPE_U1
        case MetadataValue.ValI8(_) => ELEMENT_TYPE_I1
        case MetadataValue.ValU16(_) => ELEMENT_TYPE_U2
        case MetadataValue.ValI16(_) => ELEMENT_TYPE_I2
        case MetadataValue.ValU32(_) => ELEMENT_TYPE_U4
        case MetadataValue.ValI32(_) => ELEMENT_TYPE_I4
        case MetadataValue.ValU64(_) => ELEMENT_TYPE_U8
        case MetadataValue.ValI64(_) => ELEMENT_TYPE_I8
        case MetadataValue.ValF32(_) => ELEMENT_TYPE_R4
        case MetadataValue.ValF64(_) => ELEMENT_TYPE_R8
        case MetadataValue.ValUtf8(_) => ELEMENT_TYPE_STRING
        case MetadataValue.ValUtf16(_) => ELEMENT_TYPE_STRING
        case MetadataValue.ValTypeName(_) => 0x50u8
        case MetadataValue.ValEnum(_, _) => 0x55u8
    }
}

func writeSerString(buffer: ArrayList<Byte>, value: String): Unit {
    let bytes = value.toArray()
    writeCompressed(buffer, Int64(bytes.size))
    appendBytes(buffer, bytes)
}

func writeUtf16Raw(buffer: ArrayList<Byte>, value: String): Unit {
    let iter = value.runes()
    while (true) {
        match (iter.next()) {
            case Some(rune) =>
                let codePoint = UInt32(rune)
                if (codePoint <= 0xFFFFu32) {
                    writeU16(buffer, UInt16(codePoint))
                } else {
                    let scalarOffset = codePoint - 0x10000u32
                    writeU16(buffer, UInt16(0xD800u32 + (scalarOffset >> 10)))
                    writeU16(buffer, UInt16(0xDC00u32 + (scalarOffset & 0x03FFu32)))
                }
            case None => break
        }
    }
}

func toArray(bytes: ArrayList<Byte>): Array<Byte> {
    return Array<Byte>(bytes.size, { i => bytes[i] })
}

func appendBytes(buffer: ArrayList<Byte>, bytes: Array<Byte>): Unit {
    for (b in bytes) {
        buffer.add(b)
    }
}

func encodeCompressed(value: Array<Byte>): Array<Byte> {
    let buffer = ArrayList<Byte>()
    writeCompressed(buffer, Int64(value.size))
    return toArray(buffer)
}

func writeCompressed(buffer: ArrayList<Byte>, value: Int64): Unit {
    if (value < 0 || value >= 0x20000000) {
        throw Exception("compressed integer out of range: ${value}")
    }

    if (value < 0x80) {
        buffer.add(UInt8(value))
    } else if (value < 0x4000) {
        buffer.add(UInt8(((value >> 8) & 0x3F) | 0x80))
        buffer.add(UInt8(value & 0xFF))
    } else {
        buffer.add(UInt8(((value >> 24) & 0x1F) | 0xC0))
        buffer.add(UInt8((value >> 16) & 0xFF))
        buffer.add(UInt8((value >> 8) & 0xFF))
        buffer.add(UInt8(value & 0xFF))
    }
}

func padTo4(bytes: Array<Byte>): Array<Byte> {
    let rounded = roundUp(Int64(bytes.size), 4)
    if (rounded == Int64(bytes.size)) {
        return bytes
    }

    let buffer = ArrayList<Byte>()
    appendBytes(buffer, bytes)
    padBuffer(buffer, rounded)
    return toArray(buffer)
}

func padBuffer(buffer: ArrayList<Byte>, size: Int64): Unit {
    while (Int64(buffer.size) < size) {
        buffer.add(0u8)
    }
}

func roundUp(value: Int64, align: Int64): Int64 {
    if (align <= 0) {
        throw Exception("alignment must be positive")
    }
    let rounded = value + align - 1
    return (rounded / align) * align
}

func isTableValid(bits: Int64, bit: Int64): Bool {
    return ((bits >> bit) & 1) == 1
}

func tableIndexSize(len: Int64): Int64 {
    if (len < (1 << 16)) {
        return 2
    }
    return 4
}

func writeCode(buffer: ArrayList<Byte>, value: Int64, size: Int64): Unit {
    if (size == 2) {
        writeU16(buffer, UInt16(value))
    } else {
        writeU32(buffer, UInt32(value))
    }
}

func writeIndex(buffer: ArrayList<Byte>, index: Int64, len: Int64, size: Int64): Unit {
    let _ = len
    let value = index + 1
    if (size == 2) {
        writeU16(buffer, UInt16(value))
    } else {
        writeU32(buffer, UInt32(value))
    }
}

func writeU16(buffer: ArrayList<Byte>, value: UInt16): Unit {
    buffer.add(UInt8(value & 0x00FFu16))
    buffer.add(UInt8((value >> 8) & 0x00FFu16))
}

func writeU32(buffer: ArrayList<Byte>, value: UInt32): Unit {
    buffer.add(UInt8(value & 0x000000FFu32))
    buffer.add(UInt8((value >> 8) & 0x000000FFu32))
    buffer.add(UInt8((value >> 16) & 0x000000FFu32))
    buffer.add(UInt8((value >> 24) & 0x000000FFu32))
}

func writeU64(buffer: ArrayList<Byte>, value: UInt64): Unit {
    writeU32(buffer, UInt32(value & 0xFFFFFFFFu64))
    writeU32(buffer, UInt32((value >> 32) & 0xFFFFFFFFu64))
}

func writeAscii(buffer: ArrayList<Byte>, value: String): Unit {
    appendBytes(buffer, value.toArray())
}

func writeFixedAscii(buffer: ArrayList<Byte>, value: String, size: Int64): Unit {
    let bytes = value.toArray()
    var i: Int64 = 0
    while (i < size) {
        if (i < Int64(bytes.size)) {
            buffer.add(bytes[i])
        } else {
            buffer.add(0u8)
        }
        i += 1
    }
}

func versionBytes(): Array<Byte> {
    let version = ArrayList<Byte>()
    writeAscii(version, "WindowsRuntime 1.4")
    while (version.size < 20) {
        version.add(0u8)
    }
    return toArray(version)
}

func writeStreamHeader(buffer: ArrayList<Byte>, offset: Int64, size: Int64, name: String, paddedNameSize: Int64): Unit {
    writeU32(buffer, UInt32(offset))
    writeU32(buffer, UInt32(size))
    writeAscii(buffer, name)
    buffer.add(0u8)
    let nameBytes = name.toArray()
    var written = Int64(nameBytes.size) + 1
    while (written < paddedNameSize) {
        buffer.add(0u8)
        written += 1
    }
    while ((Int64(buffer.size) % 4) != 0) {
        buffer.add(0u8)
    }
}

func writeDosHeader(buffer: ArrayList<Byte>): Unit {
    writeU16(buffer, IMAGE_DOS_SIGNATURE)
    padBuffer(buffer, 60)
    writeU32(buffer, UInt32(PE_OFFSET))
}

func writePeSignature(buffer: ArrayList<Byte>): Unit {
    writeU32(buffer, IMAGE_NT_SIGNATURE)
}

func writeFileHeader(buffer: ArrayList<Byte>): Unit {
    writeU16(buffer, IMAGE_FILE_MACHINE_I386)
    writeU16(buffer, 1u16)
    writeU32(buffer, 0u32)
    writeU32(buffer, 0u32)
    writeU32(buffer, 0u32)
    writeU16(buffer, UInt16(OPTIONAL_HEADER_SIZE))
    writeU16(buffer, IMAGE_FILE_DLL | IMAGE_FILE_32BIT_MACHINE | IMAGE_FILE_EXECUTABLE_IMAGE)
}

func writeOptionalHeader(buffer: ArrayList<Byte>, sizeOfImage: Int64): Unit {
    writeU16(buffer, IMAGE_NT_OPTIONAL_HDR32_MAGIC)
    buffer.add(11u8)
    buffer.add(0u8)
    writeU32(buffer, 0u32)
    writeU32(buffer, 1024u32)
    writeU32(buffer, 0u32)
    writeU32(buffer, 0u32)
    writeU32(buffer, 0u32)
    writeU32(buffer, 0u32)
    writeU32(buffer, 0x400000u32)
    writeU32(buffer, UInt32(SECTION_ALIGNMENT))
    writeU32(buffer, UInt32(FILE_ALIGNMENT))
    writeU16(buffer, 6u16)
    writeU16(buffer, 2u16)
    writeU16(buffer, 0u16)
    writeU16(buffer, 0u16)
    writeU16(buffer, 6u16)
    writeU16(buffer, 2u16)
    writeU32(buffer, 0u32)
    writeU32(buffer, UInt32(sizeOfImage))
    writeU32(buffer, UInt32(FILE_ALIGNMENT))
    writeU32(buffer, 0u32)
    writeU16(buffer, IMAGE_SUBSYSTEM_WINDOWS_CUI)
    writeU16(buffer, IMAGE_DLLCHARACTERISTICS_NX_COMPAT | IMAGE_DLLCHARACTERISTICS_NO_SEH | IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE)
    writeU32(buffer, 0x00100000u32)
    writeU32(buffer, 0u32)
    writeU32(buffer, 4096u32)
    writeU32(buffer, 0u32)
    writeU32(buffer, 0x00100000u32)
    writeU32(buffer, 16u32)

    var i: Int64 = 0
    while (i < 16) {
        if (i == IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR) {
            writeU32(buffer, UInt32(SECTION_ALIGNMENT))
            writeU32(buffer, UInt32(CLR_HEADER_SIZE))
        } else {
            writeU32(buffer, 0u32)
            writeU32(buffer, 0u32)
        }
        i += 1
    }
}

func writeSectionHeader(buffer: ArrayList<Byte>, virtualSize: Int64, rawSize: Int64): Unit {
    writeFixedAscii(buffer, ".text", 8)
    writeU32(buffer, UInt32(virtualSize))
    writeU32(buffer, UInt32(SECTION_ALIGNMENT))
    writeU32(buffer, UInt32(rawSize))
    writeU32(buffer, UInt32(FILE_ALIGNMENT))
    writeU32(buffer, 0u32)
    writeU32(buffer, 0u32)
    writeU16(buffer, 0u16)
    writeU16(buffer, 0u16)
    writeU32(buffer, 0x40000020u32)
}

func writeClrHeader(buffer: ArrayList<Byte>, metadataRva: Int64, metadataSize: Int64): Unit {
    writeU32(buffer, UInt32(CLR_HEADER_SIZE))
    writeU16(buffer, 2u16)
    writeU16(buffer, 5u16)
    writeU32(buffer, UInt32(metadataRva))
    writeU32(buffer, UInt32(metadataSize))
    writeU32(buffer, 1u32)
    writeU32(buffer, 0u32)
    var i: Int64 = 0
    while (i < 6) {
        writeU32(buffer, 0u32)
        writeU32(buffer, 0u32)
        i += 1
    }
}

func writeMetadataHeader(buffer: ArrayList<Byte>, version: Array<Byte>): Unit {
    writeU32(buffer, METADATA_SIGNATURE)
    writeU16(buffer, 1u16)
    writeU16(buffer, 1u16)
    writeU32(buffer, 0u32)
    writeU32(buffer, UInt32(version.size))
    appendBytes(buffer, version)
    writeU16(buffer, 0u16)
    writeU16(buffer, 4u16)
}
