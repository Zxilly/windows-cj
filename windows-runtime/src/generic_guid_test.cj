package windows_runtime

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testReferenceBoolUsesCanonicalGenericSignature() {
    @Expect(
        IReference<Bool>.signature(),
        "pinterface({61c17706-2d65-11e0-9ae8-d48564015472};b1)"
    )
    @Expect(IReference<Bool>.iid().toString(), "3C00FD60-2950-5939-A21A-2D12C5A01B8A")
}

@Test
func testNestedGenericInterfaceIidsUseCanonicalSignatures() {
    @Expect(
        IIterable<IStringable>.signature(),
        "pinterface({faa585ea-6214-4217-afda-7f46de5869b3};{96369f54-8eb6-48f0-abce-c1b211e627c3})"
    )
    @Expect(
        IIterable<IIterable<IStringable>>.iid().toString(),
        "96565EB9-A692-59C8-BCB5-647CDE4E6C4D"
    )
    @Expect(
        IVector<IIterable<IStringable>>.iid().toString(),
        "0E3F106F-A266-50A1-8043-C90FCF3844F6"
    )
    @Expect(
        IReference<IIterable<IStringable>>.iid().toString(),
        "F9E4006C-6E8C-56DF-811C-61F9990EBFB0"
    )
    @Expect(
        IReferenceArray<IIterable<IStringable>>.iid().toString(),
        "4A33FE03-E8B9-5346-A124-5449913ECA57"
    )
}
