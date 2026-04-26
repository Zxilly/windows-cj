package windows_metadata

import std.fs.*

// WinmdFile represents a parsed .winmd file with direct access to metadata tables
public class WinmdFile {
    public let reader: ByteReader
    public var strings: Int64 = 0   // offset to #Strings heap
    public var blobs: Int64 = 0     // offset to #Blob heap
    public var tables: Array<Table> = Array<Table>(TABLE_COUNT, {_ => Table()})

    public init(reader: ByteReader) {
        this.reader = reader
    }

    // Read and parse a .winmd file from disk
    public static func read(path: String): Option<WinmdFile> {
        try {
            let bytes = File.readFrom(path)
            return WinmdFile.parse(bytes)
        } catch (_: Exception) {
            return None
        }
    }

    // Parse a .winmd file from bytes
    public static func parse(bytes: Array<Byte>): Option<WinmdFile> {
      try {
        let br = ByteReader(bytes)
        let result = WinmdFile(br)

        // Parse PE headers
        let peInfo = parsePE(br)
        let metadataOffset = peInfo.metadataOffset

        // Verify metadata signature
        let metaSig = br.readUInt32(metadataOffset)
        if (metaSig != METADATA_SIGNATURE) {
            return None
        }

        // METADATA_HEADER: signature(4) + majorVersion(2) + minorVersion(2) + reserved(4) + length(4)
        // length is at offset 12 from metadata start
        let versionLength = Int64(br.readUInt32(metadataOffset + 12))

        // After the version string (padded to 4-byte boundary): flags(2) + streams(2)
        // streams count is at: metadataOffset + 16 + versionLength + 2
        let streamsCountOffset = metadataOffset + 16 + versionLength + 2
        let streamsCount = Int64(br.readUInt16(streamsCountOffset))

        // Stream headers start right after
        var view = streamsCountOffset + 2
        var tablesDataOffset: Int64 = 0

        var si: Int64 = 0
        while (si < streamsCount) {
            let streamOffset = Int64(br.readUInt32(view))
            let _ = Int64(br.readUInt32(view + 4))
            let streamName = br.readNullTermBytes(view + 8)
            let nameStr = String.fromUtf8(streamName)

            if (nameStr == "#Strings") {
                result.strings = metadataOffset + streamOffset
            } else if (nameStr == "#Blob") {
                result.blobs = metadataOffset + streamOffset
            } else if (nameStr == "#~") {
                tablesDataOffset = metadataOffset + streamOffset
            }
            // #GUID and #US are ignored

            // Advance past stream header: 8 bytes for offset+size, then name area padded to 4-byte boundary
            // Name area = name bytes + null terminator, padded to 4 bytes
            let nameLen = Int64(streamName.size)
            var padding = 4 - nameLen % 4
            if (padding == 0) {
                padding = 4
            }
            view = view + 8 + nameLen + padding
            si += 1
        }

        // Parse tables stream header
        // #~ stream: majorVersion(1) + minorVersion(1) + heapSizes(1) + reserved(1) + valid(8) + sorted(8) + rows...
        let heapSizes = br.readUInt8(tablesDataOffset + 6)
        let stringIndexSize: Int64 = if ((Int64(heapSizes) & 1) == 1) { 4 } else { 2 }
        let guidIndexSize: Int64 = if (((Int64(heapSizes) >> 1) & 1) == 1) { 4 } else { 2 }
        let blobIndexSize: Int64 = if (((Int64(heapSizes) >> 2) & 1) == 1) { 4 } else { 2 }
        let validBits = br.readUInt64(tablesDataOffset + 8)

        view = tablesDataOffset + 24

        // Temporary tables for unused-but-needed-for-size-calculation tables
        var unusedModule = Table()
        var unusedAssemblyOs = Table()
        var unusedAssemblyProcessor = Table()
        var unusedAssemblyRefOs = Table()
        var unusedAssemblyRefProcessor = Table()
        var unusedDeclSecurity = Table()
        var unusedEvent = Table()
        var unusedEventMap = Table()
        var unusedExportedType = Table()
        var unusedFieldMarshal = Table()
        var unusedFieldRva = Table()
        var unusedFile = Table()
        var unusedGenericParamConstraint = Table()
        var unusedManifestResource = Table()
        var unusedMethodImpl = Table()
        var unusedMethodSemantics = Table()
        var unusedMethodSpec = Table()
        var unusedProperty = Table()
        var unusedPropertyMap = Table()
        var unusedStandaloneSig = Table()

        // Read row counts for each valid table
        var bitIdx: Int64 = 0
        while (bitIdx < 64) {
            if (((validBits >> bitIdx) & 1u64) == 0u64) {
                bitIdx += 1
                continue
            }
            let rowCount = Int64(br.readUInt32(view))
            view += 4

            if (bitIdx == 0x00) { unusedModule.len = rowCount }
            else if (bitIdx == 0x01) { result.tables[TABLE_TYPE_REF].len = rowCount }
            else if (bitIdx == 0x02) { result.tables[TABLE_TYPE_DEF].len = rowCount }
            else if (bitIdx == 0x04) { result.tables[TABLE_FIELD].len = rowCount }
            else if (bitIdx == 0x06) { result.tables[TABLE_METHOD_DEF].len = rowCount }
            else if (bitIdx == 0x08) { result.tables[TABLE_METHOD_PARAM].len = rowCount }
            else if (bitIdx == 0x09) { result.tables[TABLE_INTERFACE_IMPL].len = rowCount }
            else if (bitIdx == 0x0a) { result.tables[TABLE_MEMBER_REF].len = rowCount }
            else if (bitIdx == 0x0b) { result.tables[TABLE_CONSTANT].len = rowCount }
            else if (bitIdx == 0x0c) { result.tables[TABLE_ATTRIBUTE].len = rowCount }
            else if (bitIdx == 0x0d) { unusedFieldMarshal.len = rowCount }
            else if (bitIdx == 0x0e) { unusedDeclSecurity.len = rowCount }
            else if (bitIdx == 0x0f) { result.tables[TABLE_CLASS_LAYOUT].len = rowCount }
            else if (bitIdx == 0x10) { result.tables[TABLE_FIELD_LAYOUT].len = rowCount }
            else if (bitIdx == 0x11) { unusedStandaloneSig.len = rowCount }
            else if (bitIdx == 0x12) { unusedEventMap.len = rowCount }
            else if (bitIdx == 0x14) { unusedEvent.len = rowCount }
            else if (bitIdx == 0x15) { unusedPropertyMap.len = rowCount }
            else if (bitIdx == 0x17) { unusedProperty.len = rowCount }
            else if (bitIdx == 0x18) { unusedMethodSemantics.len = rowCount }
            else if (bitIdx == 0x19) { unusedMethodImpl.len = rowCount }
            else if (bitIdx == 0x1a) { result.tables[TABLE_MODULE_REF].len = rowCount }
            else if (bitIdx == 0x1b) { result.tables[TABLE_TYPE_SPEC].len = rowCount }
            else if (bitIdx == 0x1c) { result.tables[TABLE_IMPL_MAP].len = rowCount }
            else if (bitIdx == 0x1d) { unusedFieldRva.len = rowCount }
            else if (bitIdx == 0x20) { result.tables[TABLE_ASSEMBLY].len = rowCount }
            else if (bitIdx == 0x21) { unusedAssemblyProcessor.len = rowCount }
            else if (bitIdx == 0x22) { unusedAssemblyOs.len = rowCount }
            else if (bitIdx == 0x23) { result.tables[TABLE_ASSEMBLY_REF].len = rowCount }
            else if (bitIdx == 0x24) { unusedAssemblyRefProcessor.len = rowCount }
            else if (bitIdx == 0x25) { unusedAssemblyRefOs.len = rowCount }
            else if (bitIdx == 0x26) { unusedFile.len = rowCount }
            else if (bitIdx == 0x27) { unusedExportedType.len = rowCount }
            else if (bitIdx == 0x28) { unusedManifestResource.len = rowCount }
            else if (bitIdx == 0x29) { result.tables[TABLE_NESTED_CLASS].len = rowCount }
            else if (bitIdx == 0x2a) { result.tables[TABLE_GENERIC_PARAM].len = rowCount }
            else if (bitIdx == 0x2b) { unusedMethodSpec.len = rowCount }
            else if (bitIdx == 0x2c) { unusedGenericParamConstraint.len = rowCount }

            bitIdx += 1
        }

        // Compute coded index sizes
        let typeDefOrRef = codedIndexSize([
            result.tables[TABLE_TYPE_DEF].len,
            result.tables[TABLE_TYPE_REF].len,
            result.tables[TABLE_TYPE_SPEC].len
        ])
        let hasConstant = codedIndexSize([
            result.tables[TABLE_FIELD].len,
            result.tables[TABLE_METHOD_PARAM].len,
            unusedProperty.len
        ])
        let hasFieldMarshal = codedIndexSize([
            result.tables[TABLE_FIELD].len,
            result.tables[TABLE_METHOD_PARAM].len
        ])
        let hasDeclSecurity = codedIndexSize([
            result.tables[TABLE_TYPE_DEF].len,
            result.tables[TABLE_METHOD_DEF].len,
            result.tables[TABLE_ASSEMBLY].len
        ])
        let memberRefParent = codedIndexSize([
            result.tables[TABLE_TYPE_DEF].len,
            result.tables[TABLE_TYPE_REF].len,
            result.tables[TABLE_MODULE_REF].len,
            result.tables[TABLE_METHOD_DEF].len,
            result.tables[TABLE_TYPE_SPEC].len
        ])
        let hasSemantics = codedIndexSize([
            unusedEvent.len,
            unusedProperty.len
        ])
        let methodDefOrRef = codedIndexSize([
            result.tables[TABLE_METHOD_DEF].len,
            result.tables[TABLE_MEMBER_REF].len
        ])
        let memberForwarded = codedIndexSize([
            result.tables[TABLE_FIELD].len,
            result.tables[TABLE_METHOD_DEF].len
        ])
        let implementation = codedIndexSize([
            unusedFile.len,
            result.tables[TABLE_ASSEMBLY_REF].len,
            unusedExportedType.len
        ])
        let customAttributeType = codedIndexSize([
            result.tables[TABLE_METHOD_DEF].len,
            result.tables[TABLE_MEMBER_REF].len,
            0, 0, 0
        ])
        let resolutionScope = codedIndexSize([
            unusedModule.len,
            result.tables[TABLE_MODULE_REF].len,
            result.tables[TABLE_ASSEMBLY_REF].len,
            result.tables[TABLE_TYPE_REF].len
        ])
        let typeOrMethodDef = codedIndexSize([
            result.tables[TABLE_TYPE_DEF].len,
            result.tables[TABLE_METHOD_DEF].len
        ])
        let hasCustomAttribute = codedIndexSize([
            result.tables[TABLE_METHOD_DEF].len,
            result.tables[TABLE_FIELD].len,
            result.tables[TABLE_TYPE_REF].len,
            result.tables[TABLE_TYPE_DEF].len,
            result.tables[TABLE_METHOD_PARAM].len,
            result.tables[TABLE_INTERFACE_IMPL].len,
            result.tables[TABLE_MEMBER_REF].len,
            unusedModule.len,
            unusedProperty.len,
            unusedEvent.len,
            unusedStandaloneSig.len,
            result.tables[TABLE_MODULE_REF].len,
            result.tables[TABLE_TYPE_SPEC].len,
            result.tables[TABLE_ASSEMBLY].len,
            result.tables[TABLE_ASSEMBLY_REF].len,
            unusedFile.len,
            unusedExportedType.len,
            unusedManifestResource.len,
            result.tables[TABLE_GENERIC_PARAM].len,
            unusedGenericParamConstraint.len,
            unusedMethodSpec.len
        ])

        // Set column layouts for all tables
        result.tables[TABLE_ASSEMBLY].setColumns(4, 8, 4, blobIndexSize, stringIndexSize, stringIndexSize)
        unusedAssemblyOs.setColumns(4, 4, 4, 0, 0, 0)
        unusedAssemblyProcessor.setColumns(4, 0, 0, 0, 0, 0)
        result.tables[TABLE_ASSEMBLY_REF].setColumns(8, 4, blobIndexSize, stringIndexSize, stringIndexSize, blobIndexSize)
        unusedAssemblyRefOs.setColumns(4, 4, 4, result.tables[TABLE_ASSEMBLY_REF].indexWidth(), 0, 0)
        unusedAssemblyRefProcessor.setColumns(4, result.tables[TABLE_ASSEMBLY_REF].indexWidth(), 0, 0, 0, 0)
        result.tables[TABLE_CLASS_LAYOUT].setColumns(2, 4, result.tables[TABLE_TYPE_DEF].indexWidth(), 0, 0, 0)
        result.tables[TABLE_CONSTANT].setColumns(2, hasConstant, blobIndexSize, 0, 0, 0)
        result.tables[TABLE_ATTRIBUTE].setColumns(hasCustomAttribute, customAttributeType, blobIndexSize, 0, 0, 0)
        unusedDeclSecurity.setColumns(2, hasDeclSecurity, blobIndexSize, 0, 0, 0)
        unusedEventMap.setColumns(result.tables[TABLE_TYPE_DEF].indexWidth(), unusedEvent.indexWidth(), 0, 0, 0, 0)
        unusedEvent.setColumns(2, stringIndexSize, typeDefOrRef, 0, 0, 0)
        unusedExportedType.setColumns(4, 4, stringIndexSize, stringIndexSize, implementation, 0)
        result.tables[TABLE_FIELD].setColumns(2, stringIndexSize, blobIndexSize, 0, 0, 0)
        result.tables[TABLE_FIELD_LAYOUT].setColumns(4, result.tables[TABLE_FIELD].indexWidth(), 0, 0, 0, 0)
        unusedFieldMarshal.setColumns(hasFieldMarshal, blobIndexSize, 0, 0, 0, 0)
        unusedFieldRva.setColumns(4, result.tables[TABLE_FIELD].indexWidth(), 0, 0, 0, 0)
        unusedFile.setColumns(4, stringIndexSize, blobIndexSize, 0, 0, 0)
        result.tables[TABLE_GENERIC_PARAM].setColumns(2, 2, typeOrMethodDef, stringIndexSize, 0, 0)
        unusedGenericParamConstraint.setColumns(result.tables[TABLE_GENERIC_PARAM].indexWidth(), typeDefOrRef, 0, 0, 0, 0)
        result.tables[TABLE_IMPL_MAP].setColumns(2, memberForwarded, stringIndexSize, result.tables[TABLE_MODULE_REF].indexWidth(), 0, 0)
        result.tables[TABLE_INTERFACE_IMPL].setColumns(result.tables[TABLE_TYPE_DEF].indexWidth(), typeDefOrRef, 0, 0, 0, 0)
        unusedManifestResource.setColumns(4, 4, stringIndexSize, implementation, 0, 0)
        result.tables[TABLE_MEMBER_REF].setColumns(memberRefParent, stringIndexSize, blobIndexSize, 0, 0, 0)
        result.tables[TABLE_METHOD_DEF].setColumns(4, 2, 2, stringIndexSize, blobIndexSize, result.tables[TABLE_METHOD_PARAM].indexWidth())
        unusedMethodImpl.setColumns(result.tables[TABLE_TYPE_DEF].indexWidth(), methodDefOrRef, methodDefOrRef, 0, 0, 0)
        unusedMethodSemantics.setColumns(2, result.tables[TABLE_METHOD_DEF].indexWidth(), hasSemantics, 0, 0, 0)
        unusedMethodSpec.setColumns(methodDefOrRef, blobIndexSize, 0, 0, 0, 0)
        unusedModule.setColumns(2, stringIndexSize, guidIndexSize, guidIndexSize, guidIndexSize, 0)
        result.tables[TABLE_MODULE_REF].setColumns(stringIndexSize, 0, 0, 0, 0, 0)
        result.tables[TABLE_NESTED_CLASS].setColumns(result.tables[TABLE_TYPE_DEF].indexWidth(), result.tables[TABLE_TYPE_DEF].indexWidth(), 0, 0, 0, 0)
        result.tables[TABLE_METHOD_PARAM].setColumns(2, 2, stringIndexSize, 0, 0, 0)
        unusedProperty.setColumns(2, stringIndexSize, blobIndexSize, 0, 0, 0)
        unusedPropertyMap.setColumns(result.tables[TABLE_TYPE_DEF].indexWidth(), unusedProperty.indexWidth(), 0, 0, 0, 0)
        unusedStandaloneSig.setColumns(blobIndexSize, 0, 0, 0, 0, 0)
        result.tables[TABLE_TYPE_DEF].setColumns(4, stringIndexSize, stringIndexSize, typeDefOrRef, result.tables[TABLE_FIELD].indexWidth(), result.tables[TABLE_METHOD_DEF].indexWidth())
        result.tables[TABLE_TYPE_REF].setColumns(resolutionScope, stringIndexSize, stringIndexSize, 0, 0, 0)
        result.tables[TABLE_TYPE_SPEC].setColumns(blobIndexSize, 0, 0, 0, 0, 0)

        // Assign data offsets in ECMA-335 table order
        view = unusedModule.setData(view)
        view = result.tables[TABLE_TYPE_REF].setData(view)
        view = result.tables[TABLE_TYPE_DEF].setData(view)
        view = result.tables[TABLE_FIELD].setData(view)
        view = result.tables[TABLE_METHOD_DEF].setData(view)
        view = result.tables[TABLE_METHOD_PARAM].setData(view)
        view = result.tables[TABLE_INTERFACE_IMPL].setData(view)
        view = result.tables[TABLE_MEMBER_REF].setData(view)
        view = result.tables[TABLE_CONSTANT].setData(view)
        view = result.tables[TABLE_ATTRIBUTE].setData(view)
        view = unusedFieldMarshal.setData(view)
        view = unusedDeclSecurity.setData(view)
        view = result.tables[TABLE_CLASS_LAYOUT].setData(view)
        view = result.tables[TABLE_FIELD_LAYOUT].setData(view)
        view = unusedStandaloneSig.setData(view)
        view = unusedEventMap.setData(view)
        view = unusedEvent.setData(view)
        view = unusedPropertyMap.setData(view)
        view = unusedProperty.setData(view)
        view = unusedMethodSemantics.setData(view)
        view = unusedMethodImpl.setData(view)
        view = result.tables[TABLE_MODULE_REF].setData(view)
        view = result.tables[TABLE_TYPE_SPEC].setData(view)
        view = result.tables[TABLE_IMPL_MAP].setData(view)
        view = unusedFieldRva.setData(view)
        view = result.tables[TABLE_ASSEMBLY].setData(view)
        view = unusedAssemblyProcessor.setData(view)
        view = unusedAssemblyOs.setData(view)
        view = result.tables[TABLE_ASSEMBLY_REF].setData(view)
        view = unusedAssemblyRefProcessor.setData(view)
        view = unusedAssemblyRefOs.setData(view)
        view = unusedFile.setData(view)
        view = unusedExportedType.setData(view)
        view = unusedManifestResource.setData(view)
        view = result.tables[TABLE_NESTED_CLASS].setData(view)
        view = result.tables[TABLE_GENERIC_PARAM].setData(view)

        return Some(result)
      } catch (_: Exception) {
        return None
      }
    }

    // Read an integer value from a table cell
    public func getUInt(row: Int64, table: Int64, column: Int64): Int64 {
        let tbl = tables[table]
        let col = tbl.columns[column]
        let offset = tbl.offset + row * tbl.width + col.offset
        return reader.readByWidth(offset, col.width)
    }

    // Read a string from the #Strings heap
    public func getString(row: Int64, table: Int64, column: Int64): String {
        let offset = strings + getUInt(row, table, column)
        return reader.readNullTermStr(offset)
    }

    // Read a blob from the #Blob heap
    public func getBlob(row: Int64, table: Int64, column: Int64): BlobReader {
        let offset = blobs + getUInt(row, table, column)
        let initialByte = reader.readUInt8(offset)

        var blobSize: Int64 = 0
        var blobSizeBytes: Int64 = 0

        let topBits = Int64(initialByte) >> 5
        if (topBits <= 3) {
            blobSize = Int64(initialByte & 0x7Fu8)
            blobSizeBytes = 1
        } else if (topBits <= 5) {
            blobSize = Int64(initialByte & 0x3Fu8)
            blobSizeBytes = 2
        } else if (topBits == 6) {
            blobSize = Int64(initialByte & 0x1Fu8)
            blobSizeBytes = 4
        } else {
            throw Exception("Invalid blob size encoding")
        }

        // Read remaining size bytes
        var bi: Int64 = 1
        while (bi < blobSizeBytes) {
            blobSize = (blobSize << 8) + Int64(reader.readUInt8(offset + bi))
            bi += 1
        }

        let dataOffset = offset + blobSizeBytes
        return BlobReader(reader.bytes, dataOffset, blobSize)
    }

    // Get the range of rows in another table that belong to a given row (for list columns like fields, methods, params)
    public func getList(row: Int64, table: Int64, column: Int64, otherTable: Int64): (Int64, Int64) {
        let first = getUInt(row, table, column) - 1
        let next = row + 1
        var last: Int64 = 0
        if (next < tables[table].len) {
            last = getUInt(next, table, column) - 1
        } else {
            last = tables[otherTable].len
        }
        return (first, last)
    }

    // Binary search for equal range (for sorted tables like InterfaceImpl, Attribute, etc.)
    public func equalRange(table: Int64, column: Int64, value: Int64): (Int64, Int64) {
        var first: Int64 = 0
        var last = tables[table].len
        var count = last

        while (true) {
            if (count == 0) {
                last = first
                break
            }
            let count2 = count / 2
            let middle = first + count2
            let middleValue = getUInt(middle, table, column)

            if (middleValue < value) {
                first = middle + 1
                count = count - count2 - 1
            } else if (middleValue > value) {
                count = count2
            } else {
                let first2 = lowerBound(table, first, middle, column, value)
                first = first + count
                last = upperBound(table, middle + 1, first, column, value)
                first = first2
                break
            }
        }
        return (first, last)
    }

    // Find the parent row using upper_bound
    public func parentRow(row: Int64, table: Int64, column: Int64): Int64 {
        return upperBound(table, 0, tables[table].len, column, row + 1) - 1
    }

    func lowerBound(table: Int64, startFirst: Int64, last: Int64, column: Int64, value: Int64): Int64 {
        var first = startFirst
        var count = last - first
        while (count > 0) {
            let count2 = count / 2
            let middle = first + count2
            if (getUInt(middle, table, column) < value) {
                first = middle + 1
                count = count - count2 - 1
            } else {
                count = count2
            }
        }
        return first
    }

    func upperBound(table: Int64, startFirst: Int64, last: Int64, column: Int64, value: Int64): Int64 {
        var first = startFirst
        var count = last - first
        while (count > 0) {
            let count2 = count / 2
            let middle = first + count2
            if (value < getUInt(middle, table, column)) {
                count = count2
            } else {
                first = middle + 1
                count = count - count2 - 1
            }
        }
        return first
    }

    // Get the assembly name (from the Assembly table, row 0, column 4)
    public func assemblyName(): Option<String> {
        if (tables[TABLE_ASSEMBLY].len == 0) {
            return None
        }
        return Some(getString(0, TABLE_ASSEMBLY, 4))
    }

    // Range of TypeDef rows
    public func typeDefRange(): (Int64, Int64) {
        return (0, tables[TABLE_TYPE_DEF].len)
    }

    // Range of NestedClass rows
    public func nestedClassRange(): (Int64, Int64) {
        return (0, tables[TABLE_NESTED_CLASS].len)
    }
}
