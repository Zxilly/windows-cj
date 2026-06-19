package windows_bindgen

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

// Helpers ------------------------------------------------------------------

func contains(items: ArrayList<String>, value: String): Bool {
    for (s in items) {
        if (s == value) {
            return true
        }
    }
    return false
}

func joinList(items: ArrayList<String>): String {
    let sb = StringBuilder()
    var first = true
    for (s in items) {
        if (!first) {
            sb.append(", ")
        }
        sb.append(s)
        first = false
    }
    return sb.toString()
}

// TypeAttributes -----------------------------------------------------------

@Test
func testTypeAttributesPublicSealedImport() {
    // Public(1) | Sealed(0x100) | Import(0x1000)
    let r = typeAttributesToStrings(0x0001 | 0x0100 | 0x1000)
    @Expect(contains(r, "Public"), true)
    @Expect(contains(r, "Sealed"), true)
    @Expect(contains(r, "Import"), true)
    // Layout/ClassSemantics/StringFormat default to Auto*/Class/Ansi.
    @Expect(contains(r, "AutoLayout"), true)
    @Expect(contains(r, "Class"), true)
    @Expect(contains(r, "AnsiClass"), true)
}

@Test
func testTypeAttributesGoldenStructCombo() {
    // A real golden combo:
    // Public, SequentialLayout, Class, Sealed, AnsiClass, BeforeFieldInit
    // Public=1, SequentialLayout=0x8, Class=0, Sealed=0x100, AnsiClass=0,
    // BeforeFieldInit=0x100000
    let v: UInt32 = 0x0001 | 0x0008 | 0x0100 | 0x0010_0000
    let r = typeAttributesToStrings(v)
    @Expect(joinList(r), "Public, SequentialLayout, Class, Sealed, AnsiClass, BeforeFieldInit")
}

@Test
func testTypeAttributesInterfaceWindowsRuntime() {
    // NotPublic, AutoLayout, Interface, Abstract, WindowsRuntime, AnsiClass
    // NotPublic=0, AutoLayout=0, Interface=0x20, Abstract=0x80,
    // WindowsRuntime=0x4000, AnsiClass=0
    let v: UInt32 = 0x0020 | 0x0080 | 0x4000
    let r = typeAttributesToStrings(v)
    @Expect(joinList(r), "NotPublic, AutoLayout, Interface, Abstract, WindowsRuntime, AnsiClass")
}

@Test
func testTypeAttributesNestedExplicitLayout() {
    // NestedPublic, ExplicitLayout, Class, Sealed, AnsiClass, BeforeFieldInit
    // NestedPublic=2, ExplicitLayout=0x10, Sealed=0x100, BeforeFieldInit=0x100000
    let v: UInt32 = 0x0002 | 0x0010 | 0x0100 | 0x0010_0000
    let r = typeAttributesToStrings(v)
    @Expect(joinList(r), "NestedPublic, ExplicitLayout, Class, Sealed, AnsiClass, BeforeFieldInit")
}

// MethodAttributes ---------------------------------------------------------

@Test
func testMethodAttributesPublicStaticPinvoke() {
    // Public, Static, HideBySig, ReuseSlot, PinvokeImpl
    // Public=6, Static=0x10, HideBySig=0x80, ReuseSlot=0, PinvokeImpl=0x2000
    let v: UInt32 = 0x0006 | 0x0010 | 0x0080 | 0x2000
    let r = methodAttributesToStrings(v)
    @Expect(joinList(r), "Public, Static, HideBySig, ReuseSlot, PinvokeImpl")
}

@Test
func testMethodAttributesVirtualNewSlotAbstract() {
    // Public, Virtual, HideBySig, NewSlot, Abstract, SpecialName
    // Public=6, Virtual=0x40, HideBySig=0x80, NewSlot=0x100, Abstract=0x400,
    // SpecialName=0x800
    let v: UInt32 = 0x0006 | 0x0040 | 0x0080 | 0x0100 | 0x0400 | 0x0800
    let r = methodAttributesToStrings(v)
    @Expect(joinList(r), "Public, Virtual, HideBySig, NewSlot, Abstract, SpecialName")
}

@Test
func testMethodAttributesPrivateRtSpecial() {
    // Private, HideBySig, ReuseSlot, SpecialName, RTSpecialName
    // Private=1, HideBySig=0x80, ReuseSlot=0, SpecialName=0x800, RTSpecialName=0x1000
    let v: UInt32 = 0x0001 | 0x0080 | 0x0800 | 0x1000
    let r = methodAttributesToStrings(v)
    @Expect(joinList(r), "Private, HideBySig, ReuseSlot, SpecialName, RTSpecialName")
}

// MethodImplAttributes -----------------------------------------------------

@Test
func testMethodImplAttributesIlManaged() {
    // IL=0, Managed=0 -> "IL", "Managed"
    let r = methodImplAttributesToStrings(0)
    @Expect(joinList(r), "IL, Managed")
}

@Test
func testMethodImplAttributesRuntimeManaged() {
    // Runtime=3, Managed=0 -> "Runtime", "Managed"
    let r = methodImplAttributesToStrings(0x0003)
    @Expect(joinList(r), "Runtime, Managed")
}

@Test
func testMethodImplAttributesPreserveSig() {
    // IL=0, Managed=0, PreserveSig=0x80
    let r = methodImplAttributesToStrings(0x0080)
    @Expect(joinList(r), "IL, Managed, PreserveSig")
}

// PInvoke / MethodImport ---------------------------------------------------

@Test
func testPinvokeWinApi() {
    // CallingConventionWinApi=0x100 only
    let r = pinvokeAttributesToStrings(0x0100)
    @Expect(joinList(r), "CallingConventionWinApi")
}

@Test
func testPinvokeExactSpellingStdCall() {
    // ExactSpelling=1 | CallingConventionStdCall=0x300
    let r = pinvokeAttributesToStrings(0x0001 | 0x0300)
    @Expect(contains(r, "ExactSpelling"), true)
    @Expect(contains(r, "CallingConventionStdCall"), true)
}

@Test
func testPinvokeExactSpellingSetLastErrorCDecl() {
    // ExactSpelling=1 | SetLastError=0x40 | CallingConventionCDecl=0x200
    let r = pinvokeAttributesToStrings(0x0001 | 0x0040 | 0x0200)
    @Expect(joinList(r), "ExactSpelling, SetLastError, CallingConventionCDecl")
}

@Test
func testPinvokeNone() {
    let r = pinvokeAttributesToStrings(0)
    @Expect(joinList(r), "None")
}

@Test
func testPinvokeCharSetThisCallFastCall() {
    // CharSetUnicode=0x4 | CallingConventionThisCall=0x400
    let r1 = pinvokeAttributesToStrings(0x0004 | 0x0400)
    @Expect(contains(r1, "CharSetUnicode"), true)
    @Expect(contains(r1, "CallingConventionThisCall"), true)
    // CallingConventionFastCall=0x500
    let r2 = pinvokeAttributesToStrings(0x0500)
    @Expect(contains(r2, "CallingConventionFastCall"), true)
}

// FieldAttributes (.NET [Flags] ToString) ----------------------------------

@Test
func testFieldAttributesPublicOnly() {
    // Public=6
    let r = fieldAttributesToStrings(0x0006)
    @Expect(joinList(r), "Public")
}

@Test
func testFieldAttributesPublicStatic() {
    // Public=6 | Static=0x10
    let r = fieldAttributesToStrings(0x0006 | 0x0010)
    @Expect(joinList(r), "Public, Static")
}

@Test
func testFieldAttributesPublicStaticLiteralHasDefault() {
    // Public=6 | Static=0x10 | Literal=0x40 | HasDefault=0x8000
    let r = fieldAttributesToStrings(0x0006 | 0x0010 | 0x0040 | 0x8000)
    @Expect(joinList(r), "Public, Static, Literal, HasDefault")
}

@Test
func testFieldAttributesPublicSpecialRtSpecial() {
    // Public=6 | SpecialName=0x200 | RTSpecialName=0x400
    let r = fieldAttributesToStrings(0x0006 | 0x0200 | 0x0400)
    @Expect(joinList(r), "Public, SpecialName, RTSpecialName")
}

@Test
func testFieldAttributesPrivateSpecialRtSpecial() {
    // Private=1 | SpecialName=0x200 | RTSpecialName=0x400
    let r = fieldAttributesToStrings(0x0001 | 0x0200 | 0x0400)
    @Expect(joinList(r), "Private, SpecialName, RTSpecialName")
}

@Test
func testFieldAttributesPrivateScopeZero() {
    // value 0 -> PrivateScope
    let r = fieldAttributesToStrings(0)
    @Expect(joinList(r), "PrivateScope")
}

// ParameterAttributes ------------------------------------------------------

@Test
func testParameterAttributesNone() {
    let r = parameterAttributesToStrings(0)
    @Expect(joinList(r), "None")
}

@Test
func testParameterAttributesIn() {
    let r = parameterAttributesToStrings(0x0001)
    @Expect(joinList(r), "In")
}

@Test
func testParameterAttributesInOutOptional() {
    // In=1 | Out=2 | Optional=0x10
    let r = parameterAttributesToStrings(0x0001 | 0x0002 | 0x0010)
    @Expect(joinList(r), "In, Out, Optional")
}

@Test
func testParameterAttributesOutOptional() {
    // Out=2 | Optional=0x10
    let r = parameterAttributesToStrings(0x0002 | 0x0010)
    @Expect(joinList(r), "Out, Optional")
}

// GenericParameterAttributes -----------------------------------------------

@Test
func testGenericParameterAttributesNone() {
    let r = genericParameterAttributesToStrings(0)
    @Expect(joinList(r), "None")
}

@Test
func testGenericParameterAttributesCovariantConstraint() {
    // Covariant=1 | ReferenceTypeConstraint=4
    let r = genericParameterAttributesToStrings(0x0001 | 0x0004)
    @Expect(joinList(r), "Covariant, ReferenceTypeConstraint")
}

// EventAttributes ----------------------------------------------------------

@Test
func testEventAttributesNone() {
    let r = eventAttributesToStrings(0)
    @Expect(joinList(r), "None")
}

@Test
func testEventAttributesSpecialName() {
    // SpecialName=0x200 | RTSpecialName=0x400
    let r = eventAttributesToStrings(0x0200 | 0x0400)
    @Expect(joinList(r), "SpecialName, RTSpecialName")
}

// PropertyAttributes -------------------------------------------------------

@Test
func testPropertyAttributesNone() {
    let r = propertyAttributesToStrings(0)
    @Expect(joinList(r), "None")
}

@Test
func testPropertyAttributesSpecialHasDefault() {
    // SpecialName=0x200 | HasDefault=0x1000
    let r = propertyAttributesToStrings(0x0200 | 0x1000)
    @Expect(joinList(r), "SpecialName, HasDefault")
}
