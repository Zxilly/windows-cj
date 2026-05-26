package windows_foundation
import windows_core.{DateTime, EventRegistrationToken}
import std.unittest.*
import std.unittest.testmacro.*

@Test
func testFoundationValueTypesProjectAbiRoundTrip() {
    var date = DateTime()
    date.UniversalTime = 123456789i64
    var token = EventRegistrationToken()
    token.Value = 99i64

    let dateAbi = DateTime.projectAbi(date)
    let tokenAbi = EventRegistrationToken.projectAbi(token)

    @Expect(DateTime.assumeInitRef(dateAbi).UniversalTime, 123456789i64)
    @Expect(EventRegistrationToken.assumeInitRef(tokenAbi).Value, 99i64)
    @Expect(DateTime.signature(), "struct(Windows.Foundation.DateTime;i8)")
}
