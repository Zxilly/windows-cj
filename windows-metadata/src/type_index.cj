package windows_metadata

import std.collection.*

public interface HasAttributes {
    func attributeIndex(): TypeIndex
    func attributeTable(): Int64
    func attributeFileIdx(): Int64
    func attributeRow(): Int64

    func attributes(): ArrayList<Int64> {
        return attributeIndex().getAttributesFor(attributeTable(), attributeFileIdx(), attributeRow())
    }

    func findAttribute(attrName: String): Option<Int64> {
        return attributeIndex().findAttribute(attributeTable(), attributeFileIdx(), attributeRow(), attrName)
    }

    func hasAttribute(attrName: String): Bool {
        return findAttribute(attrName).isSome()
    }

    func arches(): String {
        return attributeIndex().arches(attributeTable(), attributeFileIdx(), attributeRow())
    }
}

public class TypeDefRef <: HasAttributes {
    public let index: TypeIndex
    public let fileIdx: Int64
    public let row: Int64

    public init(index: TypeIndex, fileIdx: Int64, row: Int64) {
        this.index = index
        this.fileIdx = fileIdx
        this.row = row
    }

    public func name(): String {
        return index.typeDefName(fileIdx, row)
    }

    public func namespace(): String {
        return index.typeDefNamespace(fileIdx, row)
    }

    public func typeName(): TypeName {
        return TypeName(namespace(), trimTick(name()))
    }

    public func flags(): TypeAttributes {
        return index.typeDefFlags(fileIdx, row)
    }

    public func category(): TypeCategory {
        return index.typeDefCategory(fileIdx, row)
    }

    public func methods(): ArrayList<MethodDefRef> {
        let rows = index.typeDefMethods(fileIdx, row)
        let result = ArrayList<MethodDefRef>()
        var i = rows[0]
        while (i < rows[1]) {
            result.add(MethodDefRef(index, fileIdx, i))
            i += 1
        }
        return result
    }

    public func fields(): ArrayList<FieldRef> {
        let rows = index.typeDefFields(fileIdx, row)
        let result = ArrayList<FieldRef>()
        var i = rows[0]
        while (i < rows[1]) {
            result.add(FieldRef(index, fileIdx, i))
            i += 1
        }
        return result
    }

    public func attributeIndex(): TypeIndex {
        return index
    }

    public func attributeTable(): Int64 {
        return TABLE_TYPE_DEF
    }

    public func attributeFileIdx(): Int64 {
        return fileIdx
    }

    public func attributeRow(): Int64 {
        return row
    }
}

public class MethodDefRef <: HasAttributes {
    public let index: TypeIndex
    public let fileIdx: Int64
    public let row: Int64

    public init(index: TypeIndex, fileIdx: Int64, row: Int64) {
        this.index = index
        this.fileIdx = fileIdx
        this.row = row
    }

    public func name(): String {
        return index.methodDefName(fileIdx, row)
    }

    public func owner(): TypeDefRef {
        return index.methodDefOwner(fileIdx, row)
    }

    public func attributeIndex(): TypeIndex {
        return index
    }

    public func attributeTable(): Int64 {
        return TABLE_METHOD_DEF
    }

    public func attributeFileIdx(): Int64 {
        return fileIdx
    }

    public func attributeRow(): Int64 {
        return row
    }
}

public class FieldRef <: HasAttributes {
    public let index: TypeIndex
    public let fileIdx: Int64
    public let row: Int64

    public init(index: TypeIndex, fileIdx: Int64, row: Int64) {
        this.index = index
        this.fileIdx = fileIdx
        this.row = row
    }

    public func name(): String {
        return index.fieldName(fileIdx, row)
    }

    public func owner(): TypeDefRef {
        return index.fieldOwner(fileIdx, row)
    }

    public func attributeIndex(): TypeIndex {
        return index
    }

    public func attributeTable(): Int64 {
        return TABLE_FIELD
    }

    public func attributeFileIdx(): Int64 {
        return fileIdx
    }

    public func attributeRow(): Int64 {
        return row
    }
}

public class TypeSpec <: HasAttributes {
    public let index: TypeIndex
    public let fileIdx: Int64
    public let row: Int64

    public init(index: TypeIndex, fileIdx: Int64, row: Int64) {
        this.index = index
        this.fileIdx = fileIdx
        this.row = row
    }

    public func ty(): MetadataType {
        let file = index.getFile(fileIdx)
        var blob = file.getBlob(row, TABLE_TYPE_SPEC, 0)
        return blob.readTypeCode(file, Array<MetadataType>())
    }

    public func attributeIndex(): TypeIndex {
        return index
    }

    public func attributeTable(): Int64 {
        return TABLE_TYPE_SPEC
    }

    public func attributeFileIdx(): Int64 {
        return fileIdx
    }

    public func attributeRow(): Int64 {
        return row
    }
}

// TypeIndex builds a namespace -> name -> TypeDef index across one or more winmd files
public class TypeIndex {
    public let files: ArrayList<WinmdFile>
    // types: qualified TypeName -> list of TypeDef rows
    public let types: HashMap<TypeName, ArrayList<TypeDefKey>>
    public let namespaces: HashMap<String, Bool>
    // nested: outer TypeDef -> inner TypeDefs
    public let nested: HashMap<TypeDefKey, ArrayList<TypeDefKey>>

    public init(files: ArrayList<WinmdFile>) {
        this.files = files
        this.types = HashMap<TypeName, ArrayList<TypeDefKey>>()
        this.namespaces = HashMap<String, Bool>()
        this.nested = HashMap<TypeDefKey, ArrayList<TypeDefKey>>()
        buildIndex()
    }

    // Convenience: read a single winmd file
    public static func read(path: String): Option<TypeIndex> {
        match (WinmdFile.read(path)) {
            case Some(f) =>
                let files = ArrayList<WinmdFile>()
                files.add(f)
                return Some(TypeIndex(files))
            case None => return None
        }
    }

    // Convenience: read multiple winmd files
    public static func readMultiple(paths: Array<String>): Option<TypeIndex> {
        let fileList = ArrayList<WinmdFile>()
        for (p in paths) {
            match (WinmdFile.read(p)) {
                case Some(f) => fileList.add(f)
                case None => return None
            }
        }
        return Some(TypeIndex(fileList))
    }

    func buildIndex(): Unit {
        var filePos: Int64 = 0
        while (filePos < Int64(files.size)) {
            let file = files[filePos]
            let (tdStart, tdEnd) = file.typeDefRange()
            var defPos = tdStart
            while (defPos < tdEnd) {
                let namespace = file.getString(defPos, TABLE_TYPE_DEF, 2)
                if (namespace.isEmpty()) {
                    // Skip <Module> and nested types (they have empty namespace)
                    defPos += 1
                    continue
                }
                let name = file.getString(defPos, TABLE_TYPE_DEF, 1)
                let typeName = TypeName.named(namespace, trimTick(name))
                if (!types.contains(typeName)) {
                    types[typeName] = ArrayList<TypeDefKey>()
                }
                types[typeName].add(TypeDefKey(filePos, defPos))
                namespaces[namespace] = true

                defPos += 1
            }

            // Build nested class map
            let (ncStart, ncEnd) = file.nestedClassRange()
            var ncPos = ncStart
            while (ncPos < ncEnd) {
                let inner = file.getUInt(ncPos, TABLE_NESTED_CLASS, 0) - 1
                let outer = file.getUInt(ncPos, TABLE_NESTED_CLASS, 1) - 1
                let key = TypeDefKey(filePos, outer)
                if (!nested.contains(key)) {
                    nested[key] = ArrayList<TypeDefKey>()
                }
                nested[key].add(TypeDefKey(filePos, inner))
                ncPos += 1
            }

            filePos += 1
        }
    }

    // Get the WinmdFile at the given index
    public func getFile(index: Int64): WinmdFile {
        return files[index]
    }

    // Iterate all types: yields (namespace, name, fileIndex, typeDefRow) tuples
    public func iter(): ArrayList<(String, String, Int64, Int64)> {
        var result = ArrayList<(String, String, Int64, Int64)>()
        for ((typeName, entries) in types) {
            for (entry in entries) {
                result.add((typeName.namespace, trimTick(typeName.name), entry.fileIdx, entry.row))
            }
        }
        return result
    }

    public func iterTypeEntries(): ArrayList<(TypeName, TypeDefKey)> {
        let result = ArrayList<(TypeName, TypeDefKey)>()
        for ((typeName, entries) in types) {
            for (entry in entries) {
                result.add((typeName, entry))
            }
        }
        return result
    }

    // Get all TypeDef entries for a given namespace and name
    public func get(namespace: String, name: String): ArrayList<(Int64, Int64)> {
        let typed = get(TypeName.named(namespace, trimTick(name)))
        let result = ArrayList<(Int64, Int64)>()
        for (entry in typed) {
            result.add((entry.fileIdx, entry.row))
        }
        return result
    }

    public func get(typeName: TypeName): ArrayList<TypeDefKey> {
        let key = typeName.definition()
        if (types.contains(key)) {
            return types[key]
        }
        return ArrayList<TypeDefKey>()
    }

    // Check if a namespace exists
    public func containsNamespace(namespace: String): Bool {
        return namespaces.contains(namespace)
    }

    // Check if a specific type exists
    public func contains(namespace: String, name: String): Bool {
        return contains(TypeName.named(namespace, trimTick(name)))
    }

    public func contains(typeName: TypeName): Bool {
        return types.contains(typeName.definition())
    }

    // Get the first matching TypeDef, or throw if not found or ambiguous
    public func expect(namespace: String, name: String): (Int64, Int64) {
        let result = expect(TypeName.named(namespace, trimTick(name)))
        return (result.fileIdx, result.row)
    }

    public func expect(typeName: TypeName): TypeDefKey {
        let results = get(typeName)
        if (results.isEmpty()) {
            throw Exception("type not found: ${typeName.definition()}")
        }
        if (Int64(results.size) > 1) {
            throw Exception("more than one type found: ${typeName.definition()}")
        }
        return results[0]
    }

    // Get nested types for a given outer TypeDef
    public func getNested(fileIdx: Int64, outerRow: Int64): ArrayList<Int64> {
        let key = TypeDefKey(fileIdx, outerRow)
        let result = ArrayList<Int64>()
        if (nested.contains(key)) {
            for (entry in nested[key]) {
                result.add(entry.row)
            }
        }
        return result
    }

    public func getNestedKeys(fileIdx: Int64, outerRow: Int64): ArrayList<TypeDefKey> {
        let key = TypeDefKey(fileIdx, outerRow)
        if (nested.contains(key)) {
            return nested[key]
        }
        return ArrayList<TypeDefKey>()
    }

    // Get the assembly name for a given type
    public func assemblyName(namespace: String, name: String): Option<String> {
        let results = get(TypeName.named(namespace, trimTick(name)))
        if (results.isEmpty()) {
            return None
        }
        let fileIdx = results[0].fileIdx
        return files[fileIdx].assemblyName()
    }

    // --- High-level table accessors ---

    // Get TypeDef flags
    public func typeDefFlags(fileIdx: Int64, row: Int64): TypeAttributes {
        let file = files[fileIdx]
        return TypeAttributes(UInt32(file.getUInt(row, TABLE_TYPE_DEF, 0)))
    }

    // Get TypeDef name
    public func typeDefName(fileIdx: Int64, row: Int64): String {
        return files[fileIdx].getString(row, TABLE_TYPE_DEF, 1)
    }

    // Get TypeDef namespace
    public func typeDefNamespace(fileIdx: Int64, row: Int64): String {
        return files[fileIdx].getString(row, TABLE_TYPE_DEF, 2)
    }

    // Get TypeDef extends (decoded as TypeDefOrRef coded index)
    // Returns (table, row) or (-1, -1) if no extends
    public func typeDefExtends(fileIdx: Int64, row: Int64): (Int64, Int64) {
        let file = files[fileIdx]
        let value = file.getUInt(row, TABLE_TYPE_DEF, 3)
        if (value == 0) {
            return (-1, -1)
        }
        return decodeCodedIndex(value, CODED_TYPE_DEF_OR_REF_BITS, CODED_TYPE_DEF_OR_REF_MAP)
    }

    // Get TypeDef fields range
    public func typeDefFields(fileIdx: Int64, row: Int64): (Int64, Int64) {
        return files[fileIdx].getList(row, TABLE_TYPE_DEF, 4, TABLE_FIELD)
    }

    // Get TypeDef methods range
    public func typeDefMethods(fileIdx: Int64, row: Int64): (Int64, Int64) {
        return files[fileIdx].getList(row, TABLE_TYPE_DEF, 5, TABLE_METHOD_DEF)
    }

    // Determine the category of a TypeDef
    public func typeDefCategory(fileIdx: Int64, row: Int64): TypeCategory {
        let (extTable, extRow) = typeDefExtends(fileIdx, row)
        if (extTable < 0) {
            return TypeCategory.Interface
        }
        let file = files[fileIdx]
        var extNs = ""
        var extName = ""
        if (extTable == TABLE_TYPE_DEF) {
            extNs = file.getString(extRow, TABLE_TYPE_DEF, 2)
            extName = file.getString(extRow, TABLE_TYPE_DEF, 1)
        } else if (extTable == TABLE_TYPE_REF) {
            extNs = file.getString(extRow, TABLE_TYPE_REF, 2)
            extName = file.getString(extRow, TABLE_TYPE_REF, 1)
        }

        if (extNs == "System") {
            if (extName == "Enum") { return TypeCategory.Enum }
            if (extName == "MulticastDelegate") { return TypeCategory.Delegate }
            if (extName == "ValueType") { return TypeCategory.Struct }
            if (extName == "Attribute") { return TypeCategory.Attribute }
        }
        return TypeCategory.Class
    }

    // Get MethodDef name
    public func methodDefName(fileIdx: Int64, row: Int64): String {
        return files[fileIdx].getString(row, TABLE_METHOD_DEF, 3)
    }

    // Get MethodDef flags
    public func methodDefFlags(fileIdx: Int64, row: Int64): MethodAttributes {
        let file = files[fileIdx]
        return MethodAttributes(UInt16(file.getUInt(row, TABLE_METHOD_DEF, 2)))
    }

    // Get MethodDef impl flags
    public func methodDefImplFlags(fileIdx: Int64, row: Int64): MethodImplAttributes {
        let file = files[fileIdx]
        return MethodImplAttributes(UInt16(file.getUInt(row, TABLE_METHOD_DEF, 1)))
    }

    // Get MethodDef signature
    public func methodDefSignature(fileIdx: Int64, row: Int64, generics: Array<MetadataType>): MethodSignature {
        let file = files[fileIdx]
        var blob = file.getBlob(row, TABLE_METHOD_DEF, 4)
        return blob.readMethodSignature(file, generics)
    }

    // Get MethodDef params range
    public func methodDefParams(fileIdx: Int64, row: Int64): (Int64, Int64) {
        return files[fileIdx].getList(row, TABLE_METHOD_DEF, 5, TABLE_METHOD_PARAM)
    }

    func findMethodDefOwnerRow(fileIdx: Int64, row: Int64): Int64 {
        let file = files[fileIdx]
        let (typeStart, typeEnd) = file.typeDefRange()
        var typeRow = typeStart
        while (typeRow < typeEnd) {
            let (methodStart, methodEnd) = typeDefMethods(fileIdx, typeRow)
            if (methodStart <= row && row < methodEnd) {
                return typeRow
            }
            typeRow += 1
        }
        throw Exception("Failed to locate MethodDef owner for row ${row}")
    }

    public func methodDefOwner(fileIdx: Int64, row: Int64): TypeDefRef {
        let ownerRow = findMethodDefOwnerRow(fileIdx, row)
        return TypeDefRef(this, fileIdx, ownerRow)
    }

    // Get Field name
    public func fieldName(fileIdx: Int64, row: Int64): String {
        return files[fileIdx].getString(row, TABLE_FIELD, 1)
    }

    // Get Field flags
    public func fieldFlags(fileIdx: Int64, row: Int64): FieldAttributes {
        let file = files[fileIdx]
        return FieldAttributes(UInt16(file.getUInt(row, TABLE_FIELD, 0)))
    }

    // Get Field type
    public func fieldType(fileIdx: Int64, row: Int64): MetadataType {
        let file = files[fileIdx]
        var blob = file.getBlob(row, TABLE_FIELD, 2)
        let _ = blob.readU8() // should be 0x06
        return blob.readTypeSignature(file, Array<MetadataType>())
    }

    public func fieldOwner(fileIdx: Int64, row: Int64): TypeDefRef {
        let ownerRow = files[fileIdx].parentRow(row, TABLE_TYPE_DEF, 4)
        return TypeDefRef(this, fileIdx, ownerRow)
    }

    // Get Param name
    public func paramName(fileIdx: Int64, row: Int64): String {
        return files[fileIdx].getString(row, TABLE_METHOD_PARAM, 2)
    }

    // Get Param flags
    public func paramFlags(fileIdx: Int64, row: Int64): ParamAttributes {
        let file = files[fileIdx]
        return ParamAttributes(UInt16(file.getUInt(row, TABLE_METHOD_PARAM, 0)))
    }

    // Get Param sequence
    public func paramSequence(fileIdx: Int64, row: Int64): UInt16 {
        let file = files[fileIdx]
        return UInt16(file.getUInt(row, TABLE_METHOD_PARAM, 1))
    }

    // Get TypeRef name
    public func typeRefName(fileIdx: Int64, row: Int64): String {
        return files[fileIdx].getString(row, TABLE_TYPE_REF, 1)
    }

    // Get TypeRef namespace
    public func typeRefNamespace(fileIdx: Int64, row: Int64): String {
        return files[fileIdx].getString(row, TABLE_TYPE_REF, 2)
    }

    // Get ModuleRef name
    public func moduleRefName(fileIdx: Int64, row: Int64): String {
        return files[fileIdx].getString(row, TABLE_MODULE_REF, 0)
    }

    // Get GenericParam name
    public func genericParamName(fileIdx: Int64, row: Int64): String {
        return files[fileIdx].getString(row, TABLE_GENERIC_PARAM, 3)
    }

    // Get GenericParam sequence
    public func genericParamSequence(fileIdx: Int64, row: Int64): UInt16 {
        let file = files[fileIdx]
        return UInt16(file.getUInt(row, TABLE_GENERIC_PARAM, 0))
    }

    // Get GenericParams for a TypeDef (equal_range on GenericParam table, column 2)
    public func typeDefGenericParams(fileIdx: Int64, row: Int64): (Int64, Int64) {
        let file = files[fileIdx]
        let encodedOwner = encodeCodedIndex(0, row, CODED_TYPE_OR_METHOD_DEF_BITS) // 0 = TypeDef tag
        return file.equalRange(TABLE_GENERIC_PARAM, 2, encodedOwner)
    }

    // Get InterfaceImpls for a TypeDef (equal_range on InterfaceImpl table, column 0)
    public func typeDefInterfaceImpls(fileIdx: Int64, row: Int64): (Int64, Int64) {
        let file = files[fileIdx]
        return file.equalRange(TABLE_INTERFACE_IMPL, 0, row + 1)
    }

    // Get ClassLayout for a TypeDef
    public func typeDefClassLayout(fileIdx: Int64, row: Int64): Option<(UInt16, UInt32)> {
        let file = files[fileIdx]
        let (start, end) = file.equalRange(TABLE_CLASS_LAYOUT, 2, row + 1)
        if (start < end) {
            let packingSize = UInt16(file.getUInt(start, TABLE_CLASS_LAYOUT, 0))
            let classSize = UInt32(file.getUInt(start, TABLE_CLASS_LAYOUT, 1))
            return Some((packingSize, classSize))
        }
        return None
    }

    // Get FieldLayout offset for a Field row.
    public func fieldLayout(fileIdx: Int64, row: Int64): Option<UInt32> {
        let file = files[fileIdx]
        let (start, end) = file.equalRange(TABLE_FIELD_LAYOUT, 1, row + 1)
        if (start < end) {
            return Some(UInt32(file.getUInt(start, TABLE_FIELD_LAYOUT, 0)))
        }
        return None
    }

    // Get ImplMap for a MethodDef
    public func methodDefImplMap(fileIdx: Int64, row: Int64): Option<(PInvokeAttributes, String, String)> {
        let file = files[fileIdx]
        let encoded = encodeCodedIndex(1, row, CODED_MEMBER_FORWARDED_BITS) // 1 = MethodDef tag
        let (start, end) = file.equalRange(TABLE_IMPL_MAP, 1, encoded)
        if (start < end) {
            let flags = PInvokeAttributes(UInt16(file.getUInt(start, TABLE_IMPL_MAP, 0)))
            let importName = file.getString(start, TABLE_IMPL_MAP, 2)
            let moduleRefRow = file.getUInt(start, TABLE_IMPL_MAP, 3) - 1
            let moduleName = file.getString(moduleRefRow, TABLE_MODULE_REF, 0)
            return Some((flags, importName, moduleName))
        }
        return None
    }

    // Get Constant for a Field
    public func fieldConstant(fileIdx: Int64, row: Int64): Option<(MetadataType, MetadataValue)> {
        let file = files[fileIdx]
        let encoded = encodeCodedIndex(0, row, CODED_HAS_CONSTANT_BITS) // 0 = Field tag
        let (start, end) = file.equalRange(TABLE_CONSTANT, 1, encoded)
        if (start < end) {
            let constTypeCode = UInt8(file.getUInt(start, TABLE_CONSTANT, 0))
            let constType = elementTypeToMetadataType(constTypeCode)
            var blob = file.getBlob(start, TABLE_CONSTANT, 2)
            let value = readConstantValue(blob, constType)
            return Some((constType, value))
        }
        return None
    }

    // Get CustomAttributes for a row (identified by HasCustomAttribute coded index)
    public func getAttributes(fileIdx: Int64, hasAttrEncoded: Int64): ArrayList<(Int64, Int64, Int64)> {
        let file = files[fileIdx]
        let (start, end) = file.equalRange(TABLE_ATTRIBUTE, 0, hasAttrEncoded)
        var result = ArrayList<(Int64, Int64, Int64)>()
        var i = start
        while (i < end) {
            result.add((fileIdx, TABLE_ATTRIBUTE, i))
            i += 1
        }
        return result
    }

    public func getAttributesFor(table: Int64, fileIdx: Int64, row: Int64): ArrayList<Int64> {
        match (encodeHasCustomAttribute(table, row)) {
            case Some(encoded) =>
                let attrs = getAttributes(fileIdx, encoded)
                let result = ArrayList<Int64>()
                for (attr in attrs) {
                    result.add(attr[2])
                }
                return result
            case None =>
                return ArrayList<Int64>()
        }
    }

    public func attributeName(fileIdx: Int64, attrRow: Int64): String {
        let file = files[fileIdx]
        let (table, row) = decodeAttributeCtor(file, attrRow)
        if (table == TABLE_METHOD_DEF) {
            return methodDefOwner(fileIdx, row).name()
        }
        if (table == TABLE_MEMBER_REF) {
            let (parentTable, parentRow) = decodeMemberRefParent(file, row)
            if (parentTable == TABLE_TYPE_DEF) {
                return file.getString(parentRow, TABLE_TYPE_DEF, 1)
            }
            if (parentTable == TABLE_TYPE_REF) {
                return file.getString(parentRow, TABLE_TYPE_REF, 1)
            }
        }
        throw Exception("Unsupported custom attribute constructor table: ${table}")
    }

    public func attributeNamespace(fileIdx: Int64, attrRow: Int64): String {
        let file = files[fileIdx]
        let (table, row) = decodeAttributeCtor(file, attrRow)
        if (table == TABLE_METHOD_DEF) {
            return methodDefOwner(fileIdx, row).namespace()
        }
        if (table == TABLE_MEMBER_REF) {
            let (parentTable, parentRow) = decodeMemberRefParent(file, row)
            if (parentTable == TABLE_TYPE_DEF) {
                return file.getString(parentRow, TABLE_TYPE_DEF, 2)
            }
            if (parentTable == TABLE_TYPE_REF) {
                return file.getString(parentRow, TABLE_TYPE_REF, 2)
            }
        }
        throw Exception("Unsupported custom attribute constructor namespace table: ${table}")
    }

    public func attributeValues(fileIdx: Int64, attrRow: Int64): ArrayList<(String, MetadataValue)> {
        let file = files[fileIdx]
        let signature = attributeSignature(file, attrRow)
        var blob = file.getBlob(attrRow, TABLE_ATTRIBUTE, 2)
        return blob.readCustomAttributeValues(file, signature)
    }

    public func findAttribute(table: Int64, fileIdx: Int64, row: Int64, attrName: String): Option<Int64> {
        let attrs = getAttributesFor(table, fileIdx, row)
        for (attrRow in attrs) {
            if (attributeName(fileIdx, attrRow) == attrName) {
                return Some(attrRow)
            }
        }
        return None
    }

    public func hasAttribute(table: Int64, fileIdx: Int64, row: Int64, attrName: String): Bool {
        return findAttribute(table, fileIdx, row, attrName).isSome()
    }

    // True when the parameter carries the ECMA `Optional` flag — high-level
    // wrappers translate these into `Option<T>` to mirror the WinRT/Win32
    // contract that nullable arguments may be omitted.
    public func paramIsOptional(fileIdx: Int64, paramRow: Int64): Bool {
        return paramFlags(fileIdx, paramRow).contains(ParamAttributes.Optional)
    }

    // True when the parameter carries the `ReservedAttribute` — callers must
    // pass null/zero. High-level wrappers omit such parameters from the surface.
    public func paramIsReserved(fileIdx: Int64, paramRow: Int64): Bool {
        return findAttribute(TABLE_METHOD_PARAM, fileIdx, paramRow, "ReservedAttribute").isSome()
    }

    // Inspect NativeArrayInfoAttribute / MemorySizeAttribute on a parameter row.
    // Returns HintNone when neither attribute is present.
    public func paramArrayHint(fileIdx: Int64, paramRow: Int64): ParamArrayHint {
        match (findAttribute(TABLE_METHOD_PARAM, fileIdx, paramRow, "NativeArrayInfoAttribute")) {
            case Some(attrRow) =>
                for ((_, value) in attributeValues(fileIdx, attrRow)) {
                    match (value) {
                        case MetadataValue.ValI16(v) => return ParamArrayHint.HintRelativeLen(v)
                        case MetadataValue.ValI32(v) => return ParamArrayHint.HintFixed(v)
                        case _ => ()
                    }
                }
            case None => ()
        }
        match (findAttribute(TABLE_METHOD_PARAM, fileIdx, paramRow, "MemorySizeAttribute")) {
            case Some(attrRow) =>
                for ((_, value) in attributeValues(fileIdx, attrRow)) {
                    match (value) {
                        case MetadataValue.ValI16(v) => return ParamArrayHint.HintRelativeBytes(v)
                        case _ => ()
                    }
                }
            case None => ()
        }
        return ParamArrayHint.HintNone
    }

    public func arches(table: Int64, fileIdx: Int64, row: Int64): String {
        match (findAttribute(table, fileIdx, row, "SupportedArchitectureAttribute")) {
            case Some(attrRow) =>
                let values = attributeValues(fileIdx, attrRow)
                if (!values.isEmpty()) {
                    match (values[0][1]) {
                        case MetadataValue.ValI32(v) => return "${v}"
                        case MetadataValue.ValEnum(_, MetadataValue.ValI32(v)) => return "${v}"
                        case _ => return "0"
                    }
                }
                return "0"
            case None =>
                return "0"
        }
    }
}

func decodeAttributeCtor(file: WinmdFile, attrRow: Int64): (Int64, Int64) {
    let coded = file.getUInt(attrRow, TABLE_ATTRIBUTE, 1)
    return decodeCodedIndex(coded, CODED_CUSTOM_ATTRIBUTE_TYPE_BITS, CODED_CUSTOM_ATTRIBUTE_TYPE_MAP)
}

func decodeMemberRefParent(file: WinmdFile, memberRefRow: Int64): (Int64, Int64) {
    let coded = file.getUInt(memberRefRow, TABLE_MEMBER_REF, 0)
    return decodeCodedIndex(coded, CODED_MEMBER_REF_PARENT_BITS, CODED_MEMBER_REF_PARENT_MAP)
}

func attributeSignature(file: WinmdFile, attrRow: Int64): MethodSignature {
    let (table, row) = decodeAttributeCtor(file, attrRow)
    if (table == TABLE_METHOD_DEF) {
        var blob = file.getBlob(row, TABLE_METHOD_DEF, 4)
        return blob.readMethodSignature(file, Array<MetadataType>())
    }
    if (table == TABLE_MEMBER_REF) {
        var blob = file.getBlob(row, TABLE_MEMBER_REF, 2)
        return blob.readMethodSignature(file, Array<MetadataType>())
    }
    throw Exception("Unsupported custom attribute signature table: ${table}")
}

// Convert ELEMENT_TYPE code to MetadataType for constants
func elementTypeToMetadataType(code: UInt8): MetadataType {
    if (code == ELEMENT_TYPE_BOOLEAN) { return MetadataType.Boolean }
    if (code == ELEMENT_TYPE_I1) { return MetadataType.I8 }
    if (code == ELEMENT_TYPE_U1) { return MetadataType.U8 }
    if (code == ELEMENT_TYPE_I2) { return MetadataType.I16 }
    if (code == ELEMENT_TYPE_U2) { return MetadataType.U16 }
    if (code == ELEMENT_TYPE_I4) { return MetadataType.I32 }
    if (code == ELEMENT_TYPE_U4) { return MetadataType.U32 }
    if (code == ELEMENT_TYPE_I8) { return MetadataType.I64 }
    if (code == ELEMENT_TYPE_U8) { return MetadataType.U64 }
    if (code == ELEMENT_TYPE_R4) { return MetadataType.F32 }
    if (code == ELEMENT_TYPE_R8) { return MetadataType.F64 }
    if (code == ELEMENT_TYPE_STRING) { return MetadataType.MdString }
    throw Exception("Unknown constant element type: ${code}")
}

// Read a constant value from a blob
func readConstantValue(blob: BlobReader, ty: MetadataType): MetadataValue {
    match (ty) {
        case MetadataType.Boolean => MetadataValue.ValBool(blob.readBool())
        case MetadataType.I8 => MetadataValue.ValI8(blob.readI8())
        case MetadataType.U8 => MetadataValue.ValU8(blob.readU8())
        case MetadataType.I16 => MetadataValue.ValI16(blob.readI16())
        case MetadataType.U16 => MetadataValue.ValU16(blob.readU16())
        case MetadataType.I32 => MetadataValue.ValI32(blob.readI32())
        case MetadataType.U32 => MetadataValue.ValU32(blob.readU32())
        case MetadataType.I64 => MetadataValue.ValI64(blob.readI64())
        case MetadataType.U64 => MetadataValue.ValU64(blob.readU64())
        case MetadataType.F32 => MetadataValue.ValF32(blob.readF32())
        case MetadataType.F64 => MetadataValue.ValF64(blob.readF64())
        case MetadataType.MdString => MetadataValue.ValUtf16(blob.readUtf16())
        case _ => throw Exception("Unsupported constant type")
    }
}
