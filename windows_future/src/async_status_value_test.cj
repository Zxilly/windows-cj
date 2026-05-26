package windows_future

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testAsyncStatusConstantsHaveExpectedAbiValues() {
    @Expect(AsyncStatus_Started.value, 0)
    @Expect(AsyncStatus_Completed.value, 1)
    @Expect(AsyncStatus_Canceled.value, 2)
    @Expect(AsyncStatus_Error.value, 3)
    @Expect(AsyncStatus.signature(), "enum(Windows.Foundation.AsyncStatus;i4)")
    let abi = AsyncStatus.projectAbi(AsyncStatus_Completed)
    @Expect(AsyncStatus.assumeInitRef(abi) == AsyncStatus_Completed, true)
}
