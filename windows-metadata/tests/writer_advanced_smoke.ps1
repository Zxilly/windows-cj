$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "_smoke_common.ps1")

$supportFile = Join-Path $PSScriptRoot "support/writer_support.cj"

$output = Invoke-WindowsMetadataSmokeProgram -Name "writer_advanced" -Program @'
package windows_metadata_smoke_writer_advanced

import windows_metadata.*
import windows_metadata.writer.*
import std.collection.*

func findTypeRefRow(file: WinmdFile, namespace: String, name: String): Int64 {
    var row: Int64 = 0
    while (row < file.tables[TABLE_TYPE_REF].len) {
        if (file.getString(row, TABLE_TYPE_REF, 2) == namespace && file.getString(row, TABLE_TYPE_REF, 1) == name) {
            return row
        }
        row += 1
    }
    throw Exception("missing TypeRef ${namespace}.${name}")
}

func findAssemblyRefRow(file: WinmdFile, name: String): Int64 {
    var row: Int64 = 0
    while (row < file.tables[TABLE_ASSEMBLY_REF].len) {
        if (file.getString(row, TABLE_ASSEMBLY_REF, 3) == name) {
            return row
        }
        row += 1
    }
    throw Exception("missing AssemblyRef ${name}")
}

main(_args: Array<String>) {
    let refPath = "E:/Project/CS_Project/2026/ling/windows-cj/winmd/Windows.winmd"
    let outPath = "./writer-advanced-smoke.winmd"

    let refFiles = ArrayList<WinmdFile>()
    match (WinmdFile.read(refPath)) {
        case Some(file) => refFiles.add(file)
        case None => throw Exception("failed to read reference winmd")
    }

    let writer = WinmdWriter("WriterAdvanced")
    writer.setReference(TypeIndex(refFiles))

    let outer = writer.typeDef("Writer.Advanced", "Outer", TypeAttributes.Public)
    let inner = writer.typeDef("", "Inner", TypeAttributes.NestedPublic)
    writer.nestedClass(inner, outer)
    writer.classLayout(outer, 8u16, 32u32)

    let valueFieldFlags = FieldAttributes(UInt16(FieldAttributes.Public.value | FieldAttributes.Static.value | FieldAttributes.Literal.value))
    let valueField = writer.field("Value", MetadataType.I32, valueFieldFlags)
    writer.fieldLayout(valueField, 12u32)
    writer.constant(TABLE_FIELD, valueField, MetadataValue.ValI32(42i32), MetadataType.I32)

    let nestedField = writer.field("NestedRef", MetadataType.ClassName(TypeName("Writer.Advanced", "Outer/Inner")), FieldAttributes.Public)
    let systemField = writer.field("SystemType", MetadataType.ClassName(TypeName("System", "Type")), FieldAttributes.Public)

    let methodSig = MethodSignature()
    methodSig.returnType = MetadataType.ClassName(TypeName("System", "Type"))
    methodSig.paramTypes.add(MetadataType.ClassName(TypeName("Windows.Foundation", "IStringable")))
    let methodFlags = MethodAttributes(UInt16(MethodAttributes.Public.value | MethodAttributes.PInvokeImpl.value))
    let method = writer.methodDef("Create", methodSig, methodFlags, MethodImplAttributes(0u16))
    writer.param("value", 1u16, ParamAttributes.In)
    let invokeFlags = PInvokeAttributes(UInt16(PInvokeAttributes.NoMangle.value | PInvokeAttributes.CallConvPlatformapi.value))
    writer.implMap(method, invokeFlags, "CreateThing", "kernel32.dll")

    writer.genericParam("T", TABLE_TYPE_DEF, outer, 0u16, GenericParamAttributes(0u16))
    writer.interfaceImpl(outer, MetadataType.ClassName(TypeName("Windows.Foundation", "IStringable")))

    let attrSig = MethodSignature()
    attrSig.returnType = MetadataType.Void
    let obsoleteRef = writer.typeRef("System", "ObsoleteAttribute")
    let obsoleteCtor = writer.memberRef(".ctor", attrSig, TABLE_TYPE_REF, obsoleteRef)
    writer.attribute(TABLE_TYPE_DEF, outer, TABLE_MEMBER_REF, obsoleteCtor, ArrayList<(String, MetadataValue)>())

    writer.writeTo(outPath)

    match (WinmdFile.read(outPath)) {
        case Some(file) =>
            if (file.tables[TABLE_MEMBER_REF].len != 1) {
                throw Exception("MemberRef table missing")
            }
            if (file.tables[TABLE_ATTRIBUTE].len != 1) {
                throw Exception("Attribute table missing")
            }
            if (file.tables[TABLE_CONSTANT].len != 1) {
                throw Exception("Constant table missing")
            }
            if (file.tables[TABLE_GENERIC_PARAM].len != 1) {
                throw Exception("GenericParam table missing")
            }
            if (file.tables[TABLE_INTERFACE_IMPL].len != 1) {
                throw Exception("InterfaceImpl table missing")
            }
            if (file.tables[TABLE_CLASS_LAYOUT].len != 1) {
                throw Exception("ClassLayout table missing")
            }
            if (file.tables[TABLE_FIELD_LAYOUT].len != 1) {
                throw Exception("FieldLayout table missing")
            }
            if (file.tables[TABLE_NESTED_CLASS].len != 1) {
                throw Exception("NestedClass table missing")
            }
            if (file.tables[TABLE_IMPL_MAP].len != 1) {
                throw Exception("ImplMap table missing")
            }
            if (file.tables[TABLE_ASSEMBLY_REF].len < 2) {
                throw Exception("AssemblyRef table missing expected scopes")
            }

            let stringableRow = findTypeRefRow(file, "Windows.Foundation", "IStringable")
            let stringableScope = decodeCodedIndex(file.getUInt(stringableRow, TABLE_TYPE_REF, 0), CODED_RESOLUTION_SCOPE_BITS, CODED_RESOLUTION_SCOPE_MAP)
            if (stringableScope[0] != TABLE_ASSEMBLY_REF) {
                throw Exception("Windows.Foundation.IStringable should resolve via AssemblyRef")
            }

            let systemRow = findTypeRefRow(file, "System", "Type")
            let systemScope = decodeCodedIndex(file.getUInt(systemRow, TABLE_TYPE_REF, 0), CODED_RESOLUTION_SCOPE_BITS, CODED_RESOLUTION_SCOPE_MAP)
            if (systemScope[0] != TABLE_ASSEMBLY_REF) {
                throw Exception("System.Type should resolve via AssemblyRef")
            }
            let mscorlibRow = findAssemblyRefRow(file, "mscorlib")
            if (systemScope[1] != mscorlibRow) {
                throw Exception("System.Type should resolve to mscorlib AssemblyRef")
            }

            let outerRow = findTypeRefRow(file, "Writer.Advanced", "Outer")
            let innerRow = findTypeRefRow(file, "", "Inner")
            let innerScope = decodeCodedIndex(file.getUInt(innerRow, TABLE_TYPE_REF, 0), CODED_RESOLUTION_SCOPE_BITS, CODED_RESOLUTION_SCOPE_MAP)
            if (innerScope[0] != TABLE_TYPE_REF || innerScope[1] != outerRow) {
                throw Exception("Nested TypeRef should resolve through enclosing TypeRef")
            }

            let files = ArrayList<WinmdFile>()
            files.add(file)
            let index = TypeIndex(files)
            match (index.fieldConstant(0, valueField)) {
                case Some((ty, MetadataValue.ValI32(v))) =>
                    match (ty) {
                        case MetadataType.I32 =>
                            if (v != 42i32) {
                                throw Exception("constant value mismatch")
                            }
                        case _ =>
                            throw Exception("constant type mismatch")
                    }
                case _ =>
                    throw Exception("constant row not readable")
            }
            match (index.methodDefImplMap(0, method)) {
                case Some((_, importName, moduleName)) =>
                    if (importName != "CreateThing" || moduleName != "kernel32.dll") {
                        throw Exception("ImplMap payload mismatch")
                    }
                case None =>
                    throw Exception("ImplMap row not readable")
            }

            println("writer-advanced-ok")
        case None =>
            throw Exception("failed to read writer output")
    }
}
'@

if ($output -notmatch "writer-advanced-ok") {
    throw "writer advanced smoke output mismatch: $output"
}

Write-Host "writer advanced smoke passed."
