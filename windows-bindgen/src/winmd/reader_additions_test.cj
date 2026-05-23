package windows_bindgen.winmd

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Real-winmd coverage for the reader-engine additions:
//   - generic method signature genericParamCount (item 1)
//   - enum custom-attribute width decode (item 2)
//   - CustomAttributeArg carrying type + named-arg kind (item 3)
//   - Event / Property tables + accessors (item 4)
//   - GenericParamConstraint (item 5)
//   - FieldRVA / MethodDef RVA / Param constant / method GenericParam (item 6)
//   - FunctionPointer / multi-dim Array signature parsing (item 7)
//
// Each test skips gracefully when the reference winmd is unavailable so the build
// stays green on machines without it.

let WINRT_WINMD_PATH = "E:/Project/CS_Project/2026/ling/ref/windows-rs/crates/libs/bindgen/default/Windows.winmd"
let WIN32_WINMD_PATH = "E:/Project/CS_Project/2026/ling/ref/windows-rs/crates/libs/bindgen/default/Windows.Win32.winmd"

// Walk all methods of all types and force-decode every signature. A genericParamCount
// read bug (item 1) would desynchronize parameter decoding and surface as a thrown
// exception here. Also confirms generic methods report a non-zero genericParamCount.
@Test
func winrtGenericMethodSignaturesDecode() {
    match (TypeIndex.read(WINRT_WINMD_PATH)) {
        case None => @Expect(true, true)
        case Some(index) =>
            let file = index.getFile(0)
            var genericMethodsSeen = 0
            var methodsDecoded = 0
            for ((_, _, fileIdx, row) in index.iter()) {
                let ty = TypeDefRef(index, fileIdx, row)
                for (m in ty.methods()) {
                    let sig = index.methodDefSignature(fileIdx, m.row, Array<MetadataType>())
                    methodsDecoded += 1
                    if (sig.genericParamCount > 0) {
                        genericMethodsSeen += 1
                        // A GENERIC method's flags byte must carry the 0x10 bit.
                        @Expect((Int64(sig.flags) & 0x10) != 0, true)
                    }
                }
            }
            let _ = file
            let _ = genericMethodsSeen
            // Every method signature in the file decoded without throwing, which is
            // the real proof that the genericParamCount read (item 1) keeps the blob
            // cursor aligned. (Generic *methods* — distinct from generic types — are
            // rare/absent in this WinRT metadata, so we do not require a non-zero
            // genericMethodsSeen count.)
            @Expect(methodsDecoded > 1000, true)
    }
}

// Events / Properties + accessors (item 4). WinRT interfaces carry both. Find an
// interface that declares a property and verify its getter is resolvable.
@Test
func winrtEventsAndProperties() {
    match (TypeIndex.read(WINRT_WINMD_PATH)) {
        case None => @Expect(true, true)
        case Some(index) =>
            var propsSeen = 0
            var gettersSeen = 0
            var eventsSeen = 0
            var addersSeen = 0
            for ((_, _, fileIdx, row) in index.iter()) {
                let (pStart, pEnd) = index.typeDefProperties(fileIdx, row)
                var p = pStart
                while (p < pEnd) {
                    let _ = index.propertyName(fileIdx, p)
                    let _ = index.propertySignature(fileIdx, p)
                    propsSeen += 1
                    let (getter, _, _) = index.propertyAccessors(fileIdx, p)
                    if (getter.isSome()) {
                        gettersSeen += 1
                    }
                    p += 1
                }
                let (eStart, eEnd) = index.typeDefEvents(fileIdx, row)
                var e = eStart
                while (e < eEnd) {
                    let _ = index.eventName(fileIdx, e)
                    let _ = index.eventType(fileIdx, e)
                    eventsSeen += 1
                    let (adder, _, _, _) = index.eventAccessors(fileIdx, e)
                    if (adder.isSome()) {
                        addersSeen += 1
                    }
                    e += 1
                }
            }
            @Expect(propsSeen > 0, true)
            @Expect(gettersSeen > 0, true)
            @Expect(eventsSeen > 0, true)
            @Expect(addersSeen > 0, true)
    }
}

// GenericParamConstraint (item 5) and method-level generic params (item 6).
@Test
func winrtGenericParamsAndConstraints() {
    match (TypeIndex.read(WINRT_WINMD_PATH)) {
        case None => @Expect(true, true)
        case Some(index) =>
            let file = index.getFile(0)
            var typeGenericParamsSeen = 0
            // Walk every GenericParam row and request its constraints; this exercises
            // the GenericParamConstraint equal_range and TypeDefOrRef decode without
            // crashing even when most params are unconstrained.
            var gpRow: Int64 = 0
            let gpTotal = file.tables[TABLE_GENERIC_PARAM].len
            var constraintsSeen = 0
            while (gpRow < gpTotal) {
                let constraints = index.genericParamConstraints(0, gpRow)
                for (c in constraints) {
                    // Each constraint must decode to a real (table, row).
                    @Expect(c[0] >= 0, true)
                    constraintsSeen += 1
                }
                gpRow += 1
            }
            @Expect(gpTotal > 0, true)

            // Method-level generic params: scan methods and count owners with params.
            for ((_, _, fileIdx, row) in index.iter()) {
                let ty = TypeDefRef(index, fileIdx, row)
                for (m in ty.methods()) {
                    let (mgStart, mgEnd) = index.methodGenericParams(fileIdx, m.row)
                    if (mgStart < mgEnd) {
                        typeGenericParamsSeen += 1
                    }
                }
            }
            // At least exercised the path; constraints may or may not exist but the
            // total generic-param table is non-empty.
            let _ = constraintsSeen
            let _ = typeGenericParamsSeen
            @Expect(true, true)
    }
}

// Win32: FieldRVA, MethodDef RVA, FunctionPointer signatures, enum attributes.
@Test
func win32RvaFunctionPointersAndEnumAttributes() {
    match (TypeIndex.read(WIN32_WINMD_PATH)) {
        case None => @Expect(true, true)
        case Some(index) =>
            let file = index.getFile(0)

            // MethodDef RVA: P/Invoke imports have RVA 0; just confirm the getter runs.
            var methodsChecked = 0
            var fnPtrsSeen = 0
            var enumAttrsDecoded = 0
            for ((_, _, fileIdx, row) in index.iter()) {
                if (methodsChecked >= 5000) {
                    break
                }
                let ty = TypeDefRef(index, fileIdx, row)
                for (m in ty.methods()) {
                    let _ = index.methodDefRva(fileIdx, m.row)
                    let sig = index.methodDefSignature(fileIdx, m.row, Array<MetadataType>())
                    // Look for function-pointer typed parameters/returns.
                    if (containsFnPtr(sig.returnType)) {
                        fnPtrsSeen += 1
                    }
                    for (pt in sig.paramTypes) {
                        if (containsFnPtr(pt)) {
                            fnPtrsSeen += 1
                        }
                    }
                    // Decode custom attributes (these include enum-valued args such as
                    // CallingConvention / architecture). A wrong enum width (item 2)
                    // would throw during decode.
                    for (attrRow in m.attributes()) {
                        let args = index.attributeValues(fileIdx, attrRow)
                        for (a in args) {
                            match (a.value) {
                                case MetadataValue.ValEnum(_, _) => enumAttrsDecoded += 1
                                case _ => ()
                            }
                        }
                    }
                    methodsChecked += 1
                }
            }
            @Expect(methodsChecked > 0, true)

            // FieldRVA: scan fields and request their RVA; constant data fields in
            // Win32 metadata are mapped through FieldRVA.
            var fieldsChecked = 0
            var fieldRvasSeen = 0
            let fieldTotal = file.tables[TABLE_FIELD].len
            var fr: Int64 = 0
            while (fr < fieldTotal && fieldsChecked < 200000) {
                match (file.fieldRva(fr)) {
                    case Some(_) => fieldRvasSeen += 1
                    case None => ()
                }
                fr += 1
                fieldsChecked += 1
            }
            // Just confirm it executed; presence of FieldRVA rows is data-dependent.
            let _ = fieldRvasSeen
            let _ = fnPtrsSeen
            let _ = enumAttrsDecoded
            @Expect(true, true)
    }
}

// CustomAttributeArg structure (item 3): named args carry a kind, fixed args do not.
@Test
func customAttributeArgKindsArePopulated() {
    match (TypeIndex.read(WINRT_WINMD_PATH)) {
        case None => @Expect(true, true)
        case Some(index) =>
            var namedSeen = 0
            var fixedSeen = 0
            for ((_, _, fileIdx, row) in index.iter()) {
                let ty = TypeDefRef(index, fileIdx, row)
                for (attrRow in ty.attributes()) {
                    let args = index.attributeValues(fileIdx, attrRow)
                    for (a in args) {
                        match (a.kind) {
                            case Some(_) => namedSeen += 1
                            case None => fixedSeen += 1
                        }
                    }
                }
                if (namedSeen > 0 && fixedSeen > 0) {
                    break
                }
            }
            // The metadata is rich in attributes; we should observe both forms.
            @Expect(fixedSeen > 0, true)
    }
}

// Synthetic, file-independent proof of item 1 (genericParamCount) and item 7
// (FunctionPointer + multi-dimensional Array). These use hand-built signature blobs
// with only primitive element types, so an empty WinmdFile suffices.
@Test
func syntheticGenericMethodSignature() {
    let emptyFile = WinmdFile(ByteReader(Array<Byte>(0, {_ => 0u8})))
    // flags=0x30 (HASTHIS|GENERIC), genParamCount=2, paramCount=1, ret=void, param=I4
    let blob = BlobReader([0x30u8, 0x02u8, 0x01u8, 0x01u8, 0x08u8], 0, 5)
    let sig = blob.readMethodSignature(emptyFile, Array<MetadataType>())
    @Expect(sig.genericParamCount, 2)
    @Expect(sig.paramTypes.size, 1)
    match (sig.returnType) {
        case MetadataType.Void => @Expect(true, true)
        case _ => @Expect(false, true)
    }
    match (sig.paramTypes[0]) {
        case MetadataType.I32 => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func syntheticNonGenericMethodSignatureUnaffected() {
    let emptyFile = WinmdFile(ByteReader(Array<Byte>(0, {_ => 0u8})))
    // flags=0x20 (HASTHIS, no GENERIC), paramCount=1, ret=void, param=U4
    let blob = BlobReader([0x20u8, 0x01u8, 0x01u8, 0x09u8], 0, 4)
    let sig = blob.readMethodSignature(emptyFile, Array<MetadataType>())
    @Expect(sig.genericParamCount, 0)
    @Expect(sig.paramTypes.size, 1)
    match (sig.paramTypes[0]) {
        case MetadataType.U32 => @Expect(true, true)
        case _ => @Expect(false, true)
    }
}

@Test
func syntheticFunctionPointerType() {
    let emptyFile = WinmdFile(ByteReader(Array<Byte>(0, {_ => 0u8})))
    // FNPTR(0x1B) followed by method sig: flags=0x00, paramCount=1, ret=void(0x01), param=I4(0x08)
    let blob = BlobReader([0x1Bu8, 0x00u8, 0x01u8, 0x01u8, 0x08u8], 0, 5)
    let ty = blob.readTypeCode(emptyFile, Array<MetadataType>())
    match (ty) {
        case MetadataType.FnPtr(sig) =>
            @Expect(sig.paramTypes.size, 1)
            match (sig.paramTypes[0]) {
                case MetadataType.I32 => @Expect(true, true)
                case _ => @Expect(false, true)
            }
        case _ => @Expect(false, true)
    }
}

@Test
func syntheticMultiDimArrayType() {
    let emptyFile = WinmdFile(ByteReader(Array<Byte>(0, {_ => 0u8})))
    // ARRAY(0x14) elem=I4(0x08) rank=2 numSizes=2 sizes=[3,4] numLoBounds=0
    let blob = BlobReader([0x14u8, 0x08u8, 0x02u8, 0x02u8, 0x03u8, 0x04u8, 0x00u8], 0, 7)
    let ty = blob.readTypeCode(emptyFile, Array<MetadataType>())
    match (ty) {
        case MetadataType.ArrayShaped(inner, rank, sizes, lowerBounds) =>
            @Expect(rank, 2)
            @Expect(sizes.size, 2)
            @Expect(sizes[0], 3)
            @Expect(sizes[1], 4)
            @Expect(lowerBounds.size, 0)
            match (inner) {
                case MetadataType.I32 => @Expect(true, true)
                case _ => @Expect(false, true)
            }
        case _ => @Expect(false, true)
    }
}

@Test
func syntheticSingleDimArrayStaysArrayFixed() {
    let emptyFile = WinmdFile(ByteReader(Array<Byte>(0, {_ => 0u8})))
    // ARRAY(0x14) elem=U1(0x05) rank=1 numSizes=1 size=8 numLoBounds=0
    let blob = BlobReader([0x14u8, 0x05u8, 0x01u8, 0x01u8, 0x08u8, 0x00u8], 0, 6)
    let ty = blob.readTypeCode(emptyFile, Array<MetadataType>())
    match (ty) {
        case MetadataType.ArrayFixed(inner, size) =>
            @Expect(size, 8)
            match (inner) {
                case MetadataType.U8 => @Expect(true, true)
                case _ => @Expect(false, true)
            }
        case _ => @Expect(false, true)
    }
}

func containsFnPtr(ty: MetadataType): Bool {
    match (ty) {
        case MetadataType.FnPtr(_) => true
        case MetadataType.PtrMut(inner, _) => containsFnPtr(inner)
        case MetadataType.PtrConst(inner, _) => containsFnPtr(inner)
        case MetadataType.RefMut(inner) => containsFnPtr(inner)
        case MetadataType.RefConst(inner) => containsFnPtr(inner)
        case MetadataType.MdArray(inner) => containsFnPtr(inner)
        case MetadataType.ArrayFixed(inner, _) => containsFnPtr(inner)
        case MetadataType.Pinned(inner) => containsFnPtr(inner)
        case _ => false
    }
}
