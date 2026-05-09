package windows_targets

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testBundledTargetMetadataIsStable() {
    @Expect(targetsVersion(), "0.53.0")
    @Expect(defaultGnuArchiveName(), "libwindows.0.53.0.a")
}
