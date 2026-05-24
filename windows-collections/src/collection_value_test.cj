package windows_collections
import std.unittest.*
import std.unittest.testmacro.*

@Test
func testCollectionChangeAbiRoundTrip() {
    let abi = CollectionChange.projectAbi(CollectionChange_ItemInserted)
    let projected = CollectionChange.assumeInitRef(abi)

    @Expect(CollectionChange_Reset.value, 0)
    @Expect(CollectionChange_ItemInserted.value, 1)
    @Expect(CollectionChange_ItemRemoved.value, 2)
    @Expect(projected == CollectionChange_ItemInserted, true)
    @Expect(CollectionChange.signature(), "enum(Windows.Foundation.Collections.CollectionChange;i4)")
}
