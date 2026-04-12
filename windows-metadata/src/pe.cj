package windows_metadata

import std.fs.*
import std.collection.*

// PE/COFF constants
let IMAGE_DOS_SIGNATURE: UInt16 = 0x5A4D
let IMAGE_NT_SIGNATURE: UInt32 = 0x4550
let IMAGE_NT_OPTIONAL_HDR32_MAGIC: UInt16 = 0x10B
let IMAGE_NT_OPTIONAL_HDR64_MAGIC: UInt16 = 0x20B
let IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR: Int64 = 14
let METADATA_SIGNATURE: UInt32 = 0x424A5342

// Size of IMAGE_FILE_HEADER: 20 bytes
let SIZE_OF_IMAGE_FILE_HEADER: Int64 = 20
// Size of IMAGE_COR20_HEADER: 72 bytes
let SIZE_OF_IMAGE_COR20_HEADER: Int64 = 72
// Size of IMAGE_SECTION_HEADER: 40 bytes
let SIZE_OF_IMAGE_SECTION_HEADER: Int64 = 40

// Offsets within IMAGE_OPTIONAL_HEADER32: DataDirectory starts at offset 96, each entry is 8 bytes
let OPTIONAL32_DATA_DIR_OFFSET: Int64 = 96
// Total size of IMAGE_OPTIONAL_HEADER32: 96 + 16*8 = 224
let SIZE_OF_OPTIONAL_HEADER32: Int64 = 224

// Offsets within IMAGE_OPTIONAL_HEADER64: DataDirectory starts at offset 112
let OPTIONAL64_DATA_DIR_OFFSET: Int64 = 112
// Total size of IMAGE_OPTIONAL_HEADER64: 112 + 16*8 = 240
let SIZE_OF_OPTIONAL_HEADER64: Int64 = 240

// Section header field offsets (relative to section start)
let SECTION_VIRTUAL_SIZE_OFFSET: Int64 = 8
let SECTION_VIRTUAL_ADDRESS_OFFSET: Int64 = 12
let SECTION_POINTER_TO_RAW_DATA_OFFSET: Int64 = 20

// ByteReader — utility for reading little-endian values from a byte array
public class ByteReader {
    public let bytes: Array<Byte>

    public init(bytes: Array<Byte>) {
        this.bytes = bytes
    }

    public func readUInt8(offset: Int64): UInt8 {
        return UInt8(bytes[offset])
    }

    public func readUInt16(offset: Int64): UInt16 {
        let b0 = UInt16(UInt8(bytes[offset]))
        let b1 = UInt16(UInt8(bytes[offset + 1]))
        return b0 | (b1 << 8)
    }

    public func readUInt32(offset: Int64): UInt32 {
        let b0 = UInt32(UInt8(bytes[offset]))
        let b1 = UInt32(UInt8(bytes[offset + 1]))
        let b2 = UInt32(UInt8(bytes[offset + 2]))
        let b3 = UInt32(UInt8(bytes[offset + 3]))
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    public func readUInt64(offset: Int64): UInt64 {
        let lo = UInt64(readUInt32(offset))
        let hi = UInt64(readUInt32(offset + 4))
        return lo | (hi << 32)
    }

    public func readInt32(offset: Int64): Int32 {
        return Int32(readUInt32(offset))
    }

    // Read a null-terminated ASCII/UTF-8 string
    public func readNullTermStr(offset: Int64): String {
        var end = offset
        while (end < Int64(bytes.size) && bytes[end] != 0u8) {
            end += 1
        }
        let len = end - offset
        if (len == 0) {
            return ""
        }
        let arr = Array<Byte>(len, {i => bytes[offset + i]})
        return String.fromUtf8(arr)
    }

    // Read a byte slice as string (for stream name matching)
    public func readNullTermBytes(offset: Int64): Array<Byte> {
        var end = offset
        while (end < Int64(bytes.size) && bytes[end] != 0u8) {
            end += 1
        }
        let len = end - offset
        return Array<Byte>(len, {i => bytes[offset + i]})
    }

    // Read value by column width (1, 2, or 4 bytes), returned as Int64
    public func readByWidth(offset: Int64, width: Int64): Int64 {
        if (width == 1) {
            return Int64(readUInt8(offset))
        } else if (width == 2) {
            return Int64(readUInt16(offset))
        } else if (width == 4) {
            return Int64(readUInt32(offset))
        } else {
            return Int64(readUInt64(offset))
        }
    }
}

// Result of PE parsing: offsets needed to locate metadata
public class PEInfo {
    public var metadataOffset: Int64 = 0
    public var metadataSize: Int64 = 0
}

// Section header info needed for RVA translation
class SectionInfo {
    public var virtualAddress: UInt32 = 0
    public var virtualSize: UInt32 = 0
    public var pointerToRawData: UInt32 = 0
}

func sectionFromRva(sections: ArrayList<SectionInfo>, rva: UInt32): Option<SectionInfo> {
    for (s in sections) {
        if (rva >= s.virtualAddress && rva < s.virtualAddress + s.virtualSize) {
            return Some(s)
        }
    }
    return None
}

func offsetFromRva(section: SectionInfo, rva: UInt32): Int64 {
    return Int64(rva - section.virtualAddress + section.pointerToRawData)
}

// Parse PE/COFF headers to locate CLI metadata
public func parsePE(reader: ByteReader): PEInfo {
    let result = PEInfo()

    // DOS Header: e_magic at offset 0, e_lfanew at offset 60
    let dosMagic = reader.readUInt16(0)
    if (dosMagic != IMAGE_DOS_SIGNATURE) {
        throw Exception("Invalid DOS signature")
    }

    let lfanew = reader.readInt32(60)
    let peOffset = Int64(lfanew)

    // PE Signature
    let peSig = reader.readUInt32(peOffset)
    if (peSig != IMAGE_NT_SIGNATURE) {
        throw Exception("Invalid PE signature")
    }

    // IMAGE_FILE_HEADER starts right after PE signature (4 bytes)
    let fileHeaderOffset = peOffset + 4
    let numberOfSections = Int64(reader.readUInt16(fileHeaderOffset + 2))

    // Optional header starts after file header
    let optionalOffset = fileHeaderOffset + SIZE_OF_IMAGE_FILE_HEADER
    let optionalMagic = reader.readUInt16(optionalOffset)

    var comVirtualAddress: UInt32 = 0
    var sectionsOffset: Int64 = 0

    if (optionalMagic == IMAGE_NT_OPTIONAL_HDR32_MAGIC) {
        // 32-bit: DataDirectory[14] at offset 96 + 14*8
        let ddOffset = optionalOffset + OPTIONAL32_DATA_DIR_OFFSET + IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR * 8
        comVirtualAddress = reader.readUInt32(ddOffset)
        sectionsOffset = optionalOffset + SIZE_OF_OPTIONAL_HEADER32
    } else if (optionalMagic == IMAGE_NT_OPTIONAL_HDR64_MAGIC) {
        // 64-bit: DataDirectory[14] at offset 112 + 14*8
        let ddOffset = optionalOffset + OPTIONAL64_DATA_DIR_OFFSET + IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR * 8
        comVirtualAddress = reader.readUInt32(ddOffset)
        sectionsOffset = optionalOffset + SIZE_OF_OPTIONAL_HEADER64
    } else {
        throw Exception("Unknown optional header magic")
    }

    // Parse section headers
    var sections = ArrayList<SectionInfo>()
    var i: Int64 = 0
    while (i < numberOfSections) {
        let secOff = sectionsOffset + i * SIZE_OF_IMAGE_SECTION_HEADER
        let sec = SectionInfo()
        sec.virtualSize = reader.readUInt32(secOff + SECTION_VIRTUAL_SIZE_OFFSET)
        sec.virtualAddress = reader.readUInt32(secOff + SECTION_VIRTUAL_ADDRESS_OFFSET)
        sec.pointerToRawData = reader.readUInt32(secOff + SECTION_POINTER_TO_RAW_DATA_OFFSET)
        sections.add(sec)
        i += 1
    }

    // Locate IMAGE_COR20_HEADER
    let comSection = sectionFromRva(sections, comVirtualAddress)
    if (comSection.isNone()) {
        throw Exception("Cannot find COM descriptor section")
    }
    let clrOffset = offsetFromRva(comSection.getOrThrow(), comVirtualAddress)

    // IMAGE_COR20_HEADER: cb at 0, MetaData at offset 8 (VirtualAddress=8, Size=12)
    let clrCb = reader.readUInt32(clrOffset)
    if (Int64(clrCb) != SIZE_OF_IMAGE_COR20_HEADER) {
        throw Exception("Invalid IMAGE_COR20_HEADER size")
    }

    let metaVA = reader.readUInt32(clrOffset + 8)
    let metaSize = reader.readUInt32(clrOffset + 12)

    let metaSection = sectionFromRva(sections, metaVA)
    if (metaSection.isNone()) {
        throw Exception("Cannot find metadata section")
    }

    result.metadataOffset = offsetFromRva(metaSection.getOrThrow(), metaVA)
    result.metadataSize = Int64(metaSize)
    return result
}
