package windows_bindgen

import std.collection.*
import windows_metadata.*
import windows_bindgen.winmd.*

// Maps MetadataType to Cangjie source type string for @C struct fields, foreign func params, etc.
public func metadataTypeToCj(ty: MetadataType): String {
    match (ty) {
        case MetadataType.Void => "Unit"
        case MetadataType.Boolean => "Bool"
        case MetadataType.Char => "UInt16"
        case MetadataType.I8 => "Int8"
        case MetadataType.U8 => "UInt8"
        case MetadataType.I16 => "Int16"
        case MetadataType.U16 => "UInt16"
        case MetadataType.I32 => "Int32"
        case MetadataType.U32 => "UInt32"
        case MetadataType.I64 => "Int64"
        case MetadataType.U64 => "UInt64"
        case MetadataType.F32 => "Float32"
        case MetadataType.F64 => "Float64"
        case MetadataType.ISize => "IntNative"
        case MetadataType.USize => "UIntNative"
        case MetadataType.MdString => "CPointer<UInt16>"
        case MetadataType.MdObject => "CPointer<Unit>"
        case MetadataType.ClassName(tn) => resolveTypeName(tn)
        case MetadataType.ValueName(tn) => resolveTypeName(tn)
        case MetadataType.Union(tn) => resolveTypeName(tn)
        case MetadataType.MdArray(elem) => "CPointer<${metadataTypeToCj(elem)}>"
        case MetadataType.Generic(name, _) => name
        case MetadataType.RefMut(inner) => "CPointer<${metadataTypeToCj(inner)}>"
        case MetadataType.RefConst(inner) => "CPointer<${metadataTypeToCj(inner)}>"
        case MetadataType.PtrMut(inner, depth) => wrapPointer(inner, depth)
        case MetadataType.PtrConst(inner, depth) => wrapPointer(inner, depth)
        case MetadataType.ArrayFixed(elem, size) => "VArray<${metadataTypeToCj(elem)}, \$${size}>"
        case MetadataType.Packed(inner, _) => metadataTypeToCj(inner)
    }
}

// Wrap a type in CPointer N times
func wrapPointer(inner: MetadataType, depth: Int64): String {
    var result = metadataTypeToCj(inner)
    var d = depth
    while (d > 0) {
        result = "CPointer<${result}>"
        d -= 1
    }
    return result
}

// Resolve a TypeName to its Cangjie name
func resolveTypeName(tn: TypeName): String {
    let ns = tn.namespace
    let name = trimTick(tn.name)

    // Well-known types from System namespace
    if (ns == "System") {
        if (name == "Guid") {
            useSupportSymbol("windows_interface", "GUID")
            return "GUID"
        }
        if (name == "Void") {
            return "Unit"
        }
        if (name == "Boolean") {
            return "Bool"
        }
        if (name == "SByte") {
            return "Int8"
        }
        if (name == "Byte") {
            return "UInt8"
        }
        if (name == "Int16") {
            return "Int16"
        }
        if (name == "UInt16") {
            return "UInt16"
        }
        if (name == "Int32") {
            return "Int32"
        }
        if (name == "UInt32") {
            return "UInt32"
        }
        if (name == "Int64") {
            return "Int64"
        }
        if (name == "UInt64") {
            return "UInt64"
        }
        if (name == "Single") {
            return "Float32"
        }
        if (name == "Double") {
            return "Float64"
        }
        if (name == "IntPtr") {
            return "IntNative"
        }
        if (name == "UIntPtr") {
            return "UIntNative"
        }
        if (name == "String") {
            return "CPointer<UInt16>"
        }
        if (name == "Object") {
            return "CPointer<Unit>"
        }
        if (name == "Type") {
            return "CPointer<Unit>"
        }
    }

    // Well-known Windows types
    if (ns == "Windows.Win32.Foundation") {
        if (name == "BOOL") {
            return "Int32"
        }
        if (name == "HANDLE") {
            return "CPointer<Unit>"
        }
        if (name == "HWND") {
            return "CPointer<Unit>"
        }
        if (name == "HINSTANCE") {
            return "CPointer<Unit>"
        }
        if (name == "HMODULE") {
            return "CPointer<Unit>"
        }
        if (name == "HRESULT") {
            return "Int32"
        }
        if (name == "PSTR") {
            return "CPointer<UInt8>"
        }
        if (name == "PWSTR") {
            return "CPointer<UInt16>"
        }
        if (name == "PCSTR") {
            return "CPointer<UInt8>"
        }
        if (name == "PCWSTR") {
            return "CPointer<UInt16>"
        }
        if (name == "BSTR") {
            return "CPointer<UInt16>"
        }
        if (name == "NTSTATUS") {
            return "Int32"
        }
        if (name == "LRESULT") {
            return "IntNative"
        }
        if (name == "WPARAM") {
            return "UIntNative"
        }
        if (name == "LPARAM") {
            return "IntNative"
        }
    }

    // Generic types with type arguments
    if (!tn.generics.isEmpty()) {
        // For COM generics, just use CPointer<Unit> since Cangjie can't express parameterized COM interfaces in @C context
        return "CPointer<Unit>"
    }

    return projectedTypePath(ns, name)
}

// Get the Cangjie default value for a type (used in @C struct field initialization)
public func metadataTypeDefaultValue(ty: MetadataType): String {
    match (ty) {
        case MetadataType.Void => "()"
        case MetadataType.Boolean => "false"
        case MetadataType.Char => "0"
        case MetadataType.I8 => "0"
        case MetadataType.U8 => "0"
        case MetadataType.I16 => "0"
        case MetadataType.U16 => "0"
        case MetadataType.I32 => "0"
        case MetadataType.U32 => "0"
        case MetadataType.I64 => "0"
        case MetadataType.U64 => "0"
        case MetadataType.F32 => "0.0"
        case MetadataType.F64 => "0.0"
        // IntNative and UIntNative are primitive integer types, not classes
        case MetadataType.ISize => "0"
        case MetadataType.USize => "0"
        case MetadataType.MdString => "CPointer<UInt16>()"
        case MetadataType.MdObject => "CPointer<Unit>()"
        case MetadataType.ClassName(_) => "CPointer<Unit>()"
        case MetadataType.ValueName(tn) =>
            let resolved = resolveTypeName(tn)
            if (isPrimitiveCjType(resolved)) {
                "0"
            } else if (isPointerCjType(resolved)) {
                "${resolved}()"
            } else {
                "${resolved}()"
            }
        case MetadataType.Union(tn) =>
            let resolved = resolveTypeName(tn)
            if (isPrimitiveCjType(resolved)) {
                "0"
            } else if (isPointerCjType(resolved)) {
                "${resolved}()"
            } else {
                "${resolved}()"
            }
        case MetadataType.MdArray(_) => metadataTypeDefaultForPointer(ty)
        case MetadataType.Generic(_, _) => "CPointer<Unit>()"
        case MetadataType.RefMut(_) => metadataTypeDefaultForPointer(ty)
        case MetadataType.RefConst(_) => metadataTypeDefaultForPointer(ty)
        case MetadataType.PtrMut(_, _) => metadataTypeDefaultForPointer(ty)
        case MetadataType.PtrConst(_, _) => metadataTypeDefaultForPointer(ty)
        case MetadataType.ArrayFixed(elem, size) => "VArray<${metadataTypeToCj(elem)}, \$${size}>(repeat: ${metadataTypeDefaultValue(elem)})"
        case MetadataType.Packed(inner, _) => metadataTypeDefaultValue(inner)
    }
}

func metadataTypeDefaultForPointer(ty: MetadataType): String {
    return "${metadataTypeToCj(ty)}()"
}

func isPrimitiveCjType(s: String): Bool {
    return s == "Int8" || s == "UInt8" || s == "Int16" || s == "UInt16" || s == "Int32" || s == "UInt32" || s == "Int64" ||
        s == "UInt64" || s == "Float32" || s == "Float64" || s == "Bool" || s == "Unit" || s == "IntNative" || s ==
        "UIntNative"
}

func isPointerCjType(s: String): Bool {
    return s.startsWith("CPointer")
}

// Convert a MetadataValue to Cangjie literal source code
public func metadataValueToCj(value: MetadataValue, ty: MetadataType): String {
    match (value) {
        case ValBool(v) =>
            if (v) {
                "true"
            } else {
                "false"
            }
        case ValI8(v) => "${v}i8"
        case ValU8(v) => "${v}u8"
        case ValI16(v) => "${v}i16"
        case ValU16(v) => "${v}u16"
        case ValI32(v) => "${v}i32"
        case ValU32(v) => "${v}u32"
        case ValI64(v) => "${v}i64"
        case ValU64(v) => "${v}u64"
        case ValF32(v) => formatF32Literal(v)
        case ValF64(v) => formatF64Literal(v)
        case ValUtf8(v) => "\"${escapeString(v)}\""
        case ValUtf16(v) => "\"${escapeString(v)}\""
        case ValTypeName(_) => "CPointer<Unit>()"
        case ValEnum(_, inner) => metadataValueToCj(inner, ty)
    }
}

// Format a Float32 value as a valid Cangjie f32 literal
func formatF32Literal(v: Float32): String {
    if (v != v) { // NaN check: NaN != NaN
        return "Float32.nan"
    }
    // Check for infinity via comparison (infinity > max finite float)
    // Using a known large value to detect infinity
    let s = "${v}"
    if (s == "Infinity" || s == "inf") {
        return "Float32.infinity"
    }
    if (s == "-Infinity" || s == "-inf") {
        return "-Float32.infinity"
    }
    // Ensure the literal has a decimal point so Cangjie parses it as Float32
    let arr = s.toArray()
    var hasDot = false
    var hasE = false
    for (ch in arr) {
        if (ch == b'.') {
            hasDot = true
        }
        if (ch == b'e' || ch == b'E') {
            hasE = true
        }
    }
    if (!hasDot && !hasE) {
        return "${s}.0f32"
    }
    return "${s}f32"
}

// Format a Float64 value as a valid Cangjie f64 literal
func formatF64Literal(v: Float64): String {
    if (v != v) {
        return "Float64.nan"
    }
    let s = "${v}"
    if (s == "Infinity" || s == "inf") {
        return "Float64.infinity"
    }
    if (s == "-Infinity" || s == "-inf") {
        return "-Float64.infinity"
    }
    let arr = s.toArray()
    var hasDot = false
    var hasE = false
    for (ch in arr) {
        if (ch == b'.') {
            hasDot = true
        }
        if (ch == b'e' || ch == b'E') {
            hasE = true
        }
    }
    if (!hasDot && !hasE) {
        return "${s}.0f64"
    }
    return "${s}f64"
}

// Escape a string for Cangjie source
func escapeString(s: String): String {
    let arr = s.toArray()
    var result = ArrayList<Byte>()
    var i: Int64 = 0
    while (i < Int64(arr.size)) {
        let ch = arr[i]
        if (ch == b'\\') {
            result.add(b'\\')
            result.add(b'\\')
        } else if (ch == b'"') {
            result.add(b'\\')
            result.add(b'"')
        } else if (ch == b'\n') {
            result.add(b'\\')
            result.add(b'n')
        } else if (ch == b'\r') {
            result.add(b'\\')
            result.add(b'r')
        } else if (ch == b'\t') {
            result.add(b'\\')
            result.add(b't')
        } else {
            result.add(ch)
        }
        i += 1
    }
    return byteListToString(result)
}

// Determine the Cangjie type string for a constant's underlying type
public func constantTypeToCj(ty: MetadataType): String {
    match (ty) {
        case MetadataType.Boolean => "Bool"
        case MetadataType.I8 => "Int8"
        case MetadataType.U8 => "UInt8"
        case MetadataType.I16 => "Int16"
        case MetadataType.U16 => "UInt16"
        case MetadataType.I32 => "Int32"
        case MetadataType.U32 => "UInt32"
        case MetadataType.I64 => "Int64"
        case MetadataType.U64 => "UInt64"
        case MetadataType.F32 => "Float32"
        case MetadataType.F64 => "Float64"
        case MetadataType.MdString => "String"
        case _ => metadataTypeToCj(ty)
    }
}

// Check if a type is a handle type (single field named "Value" of primitive type)
public func isHandleType(index: TypeIndex, fileIdx: Int64, row: Int64): Bool {
    let category = index.typeDefCategory(fileIdx, row)
    match (category) {
        case Struct =>
            let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
            let fieldCount = fEnd - fStart
            if (fieldCount == 1) {
                let fieldNm = index.fieldName(fileIdx, fStart)
                if (fieldNm == "Value") {
                    let fieldTy = index.fieldType(fileIdx, fStart)
                    return isPrimitiveMetadataType(fieldTy) || isPointerMetadataType(fieldTy)
                }
            }
            return false
        case _ => return false
    }
}

func isPrimitiveMetadataType(ty: MetadataType): Bool {
    match (ty) {
        case MetadataType.Boolean => true
        case MetadataType.I8 => true
        case MetadataType.U8 => true
        case MetadataType.I16 => true
        case MetadataType.U16 => true
        case MetadataType.I32 => true
        case MetadataType.U32 => true
        case MetadataType.I64 => true
        case MetadataType.U64 => true
        case MetadataType.F32 => true
        case MetadataType.F64 => true
        case MetadataType.ISize => true
        case MetadataType.USize => true
        case _ => false
    }
}

func isPointerMetadataType(ty: MetadataType): Bool {
    match (ty) {
        case MetadataType.MdString => true
        case MetadataType.MdObject => true
        case MetadataType.MdArray(_) => true
        case MetadataType.RefMut(_) => true
        case MetadataType.RefConst(_) => true
        case MetadataType.PtrMut(_, _) => true
        case MetadataType.PtrConst(_, _) => true
        case _ => false
    }
}

// Map calling convention from PInvokeAttributes to a supported Cangjie annotation.
// Current toolchains accept @CallingConv[CDECL] on foreign declarations, but reject
// @CallingConv[STDCALL], so Win32 stdcall imports fall back to the compiler default.
public func callingConventionAnnotation(attrs: PInvokeAttributes): String {
    if (attrs.contains(PInvokeAttributes.CallConvCdecl)) {
        return "@CallingConv[CDECL]"
    }
    if (attrs.contains(PInvokeAttributes.CallConvFastcall)) {
        eprintln("warning: FASTCALL not supported in current Cangjie toolchain; omitting calling-convention annotation")
        return ""
    }
    // Default Win32 imports are stdcall, but current toolchains reject @CallingConv[STDCALL].
    return ""
}

// Check if a function can be marked @FastNative (short, non-blocking)
public func isFastNativeCandidate(funcName: String): Bool {
    let fastNatives = [
        "GetLastError",
        "SetLastError",
        "CloseHandle",
        "GetTickCount",
        "GetTickCount64",
        "GetCurrentThreadId",
        "GetCurrentProcessId",
        "GetCurrentProcess",
        "GetCurrentThread",
        "InterlockedIncrement",
        "InterlockedDecrement",
        "InterlockedExchange",
        "InterlockedCompareExchange"
    ]
    for (fn in fastNatives) {
        if (funcName == fn) {
            return true
        }
    }
    return false
}

// Determine the feature name for a DLL module name
public func moduleToFeature(moduleName: String): String {
    // Strip ".dll" suffix if present
    let arr = moduleName.toArray()
    let len = Int64(arr.size)
    var baseName = moduleName
    if (len > 4) {
        let suffix = String.fromUtf8(arr[len - 4..len])
        if (suffix == ".dll" || suffix == ".DLL") {
            baseName = String.fromUtf8(arr[0..len - 4])
        }
    }
    let baseArr = baseName.toArray()
    var result = Array<Byte>(
        baseArr.size,
        {
            i =>
                let ch = baseArr[i]
                if (ch == b'-' || ch == b'.') {
                    b'_'
                } else if (ch >= b'a' && ch <= b'z') {
                    ch - b'a' + b'A'
                } else {
                    ch
                }
        }
    )
    return sanitizeIdentifier(String.fromUtf8(result))
}

// Determine the feature name for a namespace
public func namespaceToFeature(namespace: String): String {
    let parts = splitString(namespace, b'.')
    let normalized = ArrayList<String>()
    for (p in parts) {
        normalized.add(sanitizeIdentifier(p))
    }
    return joinStrings(normalized, "_")
}

public func metadataTypeToProjectionCj(index: TypeIndex, ty: MetadataType): String {
    match (ty) {
        case MetadataType.Void => "Unit"
        case MetadataType.Boolean => "Bool"
        case MetadataType.Char => "UInt16"
        case MetadataType.I8 => "Int8"
        case MetadataType.U8 => "UInt8"
        case MetadataType.I16 => "Int16"
        case MetadataType.U16 => "UInt16"
        case MetadataType.I32 => "Int32"
        case MetadataType.U32 => "UInt32"
        case MetadataType.I64 => "Int64"
        case MetadataType.U64 => "UInt64"
        case MetadataType.F32 => "Float32"
        case MetadataType.F64 => "Float64"
        case MetadataType.ISize => "IntNative"
        case MetadataType.USize => "UIntNative"
        case MetadataType.MdString => "String"
        case MetadataType.MdObject => "IInspectable"
        case MetadataType.ClassName(tn) => typeNameToProjectionCj(index, tn)
        case MetadataType.ValueName(tn) => typeNameToProjectionCj(index, tn)
        case MetadataType.Union(tn) => typeNameToProjectionCj(index, tn)
        case MetadataType.MdArray(inner) => "CPointer<${metadataTypeToProjectionCj(index, inner)}>"
        case MetadataType.Generic(name, _) => name
        case MetadataType.RefMut(inner) => "CPointer<${metadataTypeToProjectionCj(index, inner)}>"
        case MetadataType.RefConst(inner) => "CPointer<${metadataTypeToProjectionCj(index, inner)}>"
        case MetadataType.PtrMut(inner, depth) => wrapProjectionPointer(index, inner, depth)
        case MetadataType.PtrConst(inner, depth) => wrapProjectionPointer(index, inner, depth)
        case MetadataType.ArrayFixed(inner, size) => "VArray<${metadataTypeToProjectionCj(index, inner)}, \$${size}>"
        case MetadataType.Packed(inner, _) => metadataTypeToProjectionCj(index, inner)
    }
}

public func metadataTypeToWinrtAbiCj(ty: MetadataType): String {
    match (ty) {
        case MetadataType.Generic(_, _) => "CPointer<Unit>"
        case MetadataType.ClassName(tn) =>
            if (!tn.generics.isEmpty()) {
                return "CPointer<Unit>"
            }
            return metadataTypeToCj(ty)
        case MetadataType.ValueName(tn) =>
            if (!tn.generics.isEmpty()) {
                return "CPointer<Unit>"
            }
            return metadataTypeToCj(ty)
        case MetadataType.MdObject => "CPointer<Unit>"
        case _ => metadataTypeToCj(ty)
    }
}

public func metadataTypeRuntimeSignature(index: TypeIndex, ty: MetadataType): String {
    match (ty) {
        case MetadataType.Boolean => "b1"
        case MetadataType.Char => "c2"
        case MetadataType.I8 => "i1"
        case MetadataType.U8 => "u1"
        case MetadataType.I16 => "i2"
        case MetadataType.U16 => "u2"
        case MetadataType.I32 => "i4"
        case MetadataType.U32 => "u4"
        case MetadataType.I64 => "i8"
        case MetadataType.U64 => "u8"
        case MetadataType.F32 => "f4"
        case MetadataType.F64 => "f8"
        case MetadataType.ISize => "is"
        case MetadataType.USize => "us"
        case MetadataType.MdString => "string"
        case MetadataType.MdObject => "cinterface(IInspectable)"
        case MetadataType.ClassName(tn) => typeNameRuntimeSignature(index, tn)
        case MetadataType.ValueName(tn) => typeNameRuntimeSignature(index, tn)
        case MetadataType.Union(tn) => typeNameRuntimeSignature(index, tn)
        case MetadataType.Packed(inner, _) => metadataTypeRuntimeSignature(index, inner)
        case _ => "cinterface(IInspectable)"
    }
}

public func typeNameToProjectionCj(index: TypeIndex, tn: TypeName): String {
    let ns = tn.namespace
    let name = trimTick(tn.name)

    if (ns == "System") {
        if (name == "String") {
            return "String"
        }
        if (name == "Object") {
            return "IInspectable"
        }
    }

    if (tn.generics.isEmpty()) {
        return projectedTypePath(ns, name)
    }

    let genericArgs = ArrayList<String>()
    for (generic in tn.generics) {
        genericArgs.add(metadataTypeToProjectionCj(index, generic))
    }
    return "${projectedTypePath(ns, name)}<${joinStrings(genericArgs, ", ")}>"
}

public func typeNameRuntimeSignature(index: TypeIndex, tn: TypeName): String {
    let ns = tn.namespace
    let name = trimTick(tn.name)
    if (ns == "System") {
        if (name == "String") {
            return "string"
        }
        if (name == "Object") {
            return "cinterface(IInspectable)"
        }
        if (name == "Guid") {
            return "g16"
        }
        if (name == "Boolean") {
            return "b1"
        }
        if (name == "Byte") {
            return "u1"
        }
        if (name == "SByte") {
            return "i1"
        }
        if (name == "Int16") {
            return "i2"
        }
        if (name == "UInt16") {
            return "u2"
        }
        if (name == "Int32") {
            return "i4"
        }
        if (name == "UInt32") {
            return "u4"
        }
        if (name == "Int64") {
            return "i8"
        }
        if (name == "UInt64") {
            return "u8"
        }
        if (name == "Single") {
            return "f4"
        }
        if (name == "Double") {
            return "f8"
        }
    }

    let runtimeName = qualifiedRuntimeName(tn)
    let typeName = trimTick(tn.name)
    let candidates = index.get(ns, typeName)
    if (candidates.isEmpty()) {
        return runtimeName
    }

    let (fileIdx, row) = candidates[0]
    let category = index.typeDefCategory(fileIdx, row)
    match (category) {
        case Interface => return interfaceRuntimeSignature(index, fileIdx, row, tn.generics)
        case Delegate => return delegateRuntimeSignature(index, fileIdx, row, tn.generics)
        case Class => return classRuntimeSignature(index, fileIdx, row)
        case Enum => return enumRuntimeSignature(index, fileIdx, row)
        case Struct => return structRuntimeSignature(index, fileIdx, row)
        case Attribute => return runtimeName
    }
}

public func interfaceRuntimeSignature(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    genericArgs: ArrayList<MetadataType>
): String {
    match (guidAttributeText(index, fileIdx, row)) {
        case Some(guidText) =>
            if (genericArgs.isEmpty()) {
                return "{${guidText}}"
            }

            var sb = StringBuilder()
            sb.append("pinterface({")
            sb.append(guidText)
            sb.append("}")
            for (generic in genericArgs) {
                sb.append(";")
                sb.append(metadataTypeRuntimeSignature(index, generic))
            }
            sb.append(")")
            return sb.toString()
        case None => return qualifiedRuntimeName(
            TypeName(index.typeDefNamespace(fileIdx, row), trimTick(index.typeDefName(fileIdx, row)), genericArgs))
    }
}

public func delegateRuntimeSignature(
    index: TypeIndex,
    fileIdx: Int64,
    row: Int64,
    genericArgs: ArrayList<MetadataType>
): String {
    match (guidAttributeText(index, fileIdx, row)) {
        case Some(guidText) =>
            if (genericArgs.isEmpty()) {
                return "delegate({${guidText}})"
            }
            return interfaceRuntimeSignature(index, fileIdx, row, genericArgs)
        case None => return qualifiedRuntimeName(
            TypeName(index.typeDefNamespace(fileIdx, row), trimTick(index.typeDefName(fileIdx, row)), genericArgs))
    }
}

public func classRuntimeSignature(index: TypeIndex, fileIdx: Int64, row: Int64): String {
    let runtimeName = "${index.typeDefNamespace(fileIdx, row)}.${trimTick(index.typeDefName(fileIdx, row))}"
    match (findDefaultInterfaceType(index, fileIdx, row)) {
        case Some(defaultInterface) => return "rc(${runtimeName};${typeNameRuntimeSignature(index, defaultInterface)})"
        case None => return runtimeName
    }
}

func enumRuntimeSignature(index: TypeIndex, fileIdx: Int64, row: Int64): String {
    let runtimeName = "${index.typeDefNamespace(fileIdx, row)}.${trimTick(index.typeDefName(fileIdx, row))}"
    let underlying = enumUnderlyingMetadataType(index, fileIdx, row)
    return "enum(${runtimeName};${metadataTypeRuntimeSignature(index, underlying)})"
}

func structRuntimeSignature(index: TypeIndex, fileIdx: Int64, row: Int64): String {
    var sb = StringBuilder()
    sb.append("struct(")
    sb.append(index.typeDefNamespace(fileIdx, row))
    sb.append(".")
    sb.append(trimTick(index.typeDefName(fileIdx, row)))
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fStart
    while (fieldRow < fEnd) {
        let fieldFlags = index.fieldFlags(fileIdx, fieldRow)
        if (!fieldFlags.contains(FieldAttributes.Literal)) {
            sb.append(";")
            sb.append(metadataTypeRuntimeSignature(index, index.fieldType(fileIdx, fieldRow)))
        }
        fieldRow += 1
    }
    sb.append(")")
    return sb.toString()
}

func enumUnderlyingMetadataType(index: TypeIndex, fileIdx: Int64, row: Int64): MetadataType {
    let (fStart, fEnd) = index.typeDefFields(fileIdx, row)
    var fieldRow = fStart
    while (fieldRow < fEnd) {
        let fieldName = index.fieldName(fileIdx, fieldRow)
        if (fieldName == "value__") {
            return index.fieldType(fileIdx, fieldRow)
        }
        fieldRow += 1
    }
    return MetadataType.I32
}

func qualifiedRuntimeName(tn: TypeName): String {
    let name = trimTick(tn.name)
    if (tn.namespace.isEmpty()) {
        return name
    }
    return "${tn.namespace}.${name}"
}

func projectedTypePath(namespace: String, name: String): String {
    if (namespace.isEmpty()) {
        return escapeSourceIdentifier(name)
    }

    match (bindgenContext()) {
        case Some(context) =>
            let current = currentNamespace()
            if (context.typeMap.containsType(namespace, name)) {
                if (current.isEmpty() || current == namespace || context
                    .config
                    .sharesGeneratedPackage(current, namespace)) {
                    return escapeSourceIdentifier(name)
                }

                return "${packageTypeQualifier(context.config, namespace)}.${escapeSourceIdentifier(name)}"
            }

            if (context.references.containsType(namespace, name)) {
                return context.references.rewriteQualified(namespace, name)
            }

            if (current.isEmpty() || current == namespace || context.config.sharesGeneratedPackage(current, namespace)) {
                return escapeSourceIdentifier(name)
            }

            return "${packageTypeQualifier(context.config, namespace)}.${escapeSourceIdentifier(name)}"
        case None => return escapeSourceIdentifier(name)
    }
}

func packageTypeQualifier(config: BindgenConfig, namespace: String): String {
    let packageName = config.packageNameForNamespace(namespace)
    return importedPackageQualifier(packageName)
}

func importedPackageQualifier(packageName: String): String {
    let parts = splitString(packageName, b'.')
    if (parts.isEmpty()) {
        return packageName
    }

    let aliasParts = ArrayList<String>()
    var start: Int64 = 0
    if (parts.size > 1) {
        start = 1
    }

    var i = start
    while (i < Int64(parts.size)) {
        aliasParts.add(parts[i])
        i += 1
    }
    if (aliasParts.isEmpty()) {
        aliasParts.add(parts[parts.size - 1])
    }
    return sanitizeIdentifier(joinStrings(aliasParts, "_"))
}

func wrapProjectionPointer(index: TypeIndex, inner: MetadataType, depth: Int64): String {
    var result = metadataTypeToProjectionCj(index, inner)
    var d = depth
    while (d > 0) {
        result = "CPointer<${result}>"
        d -= 1
    }
    return result
}

func findDefaultInterfaceType(index: TypeIndex, fileIdx: Int64, row: Int64): Option<TypeName> {
    let file = index.getFile(fileIdx)
    let (iiStart, iiEnd) = index.typeDefInterfaceImpls(fileIdx, row)
    var ii = iiStart
    while (ii < iiEnd) {
        if (index.hasAttribute(TABLE_INTERFACE_IMPL, fileIdx, ii, "DefaultAttribute")) {
            let ifaceValue = file.getUInt(ii, TABLE_INTERFACE_IMPL, 1)
            let (ifaceTable, ifaceRow) = decodeCodedIndex(ifaceValue, CODED_TYPE_DEF_OR_REF_BITS,
                CODED_TYPE_DEF_OR_REF_MAP)
            if (ifaceTable == TABLE_TYPE_DEF) {
                return Some(
                    TypeName(file.getString(ifaceRow, TABLE_TYPE_DEF, 2),
                        trimTick(file.getString(ifaceRow, TABLE_TYPE_DEF, 1))))
            }
            if (ifaceTable == TABLE_TYPE_REF) {
                return Some(
                    TypeName(file.getString(ifaceRow, TABLE_TYPE_REF, 2),
                        trimTick(file.getString(ifaceRow, TABLE_TYPE_REF, 1))))
            }
        }
        ii += 1
    }
    return None
}
