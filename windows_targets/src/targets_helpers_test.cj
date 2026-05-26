package windows_targets

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testDefaultGnuArchiveNameIsVersionedLibraryNameOnly() {
    let archive = defaultGnuArchiveName()

    @Expect(archive, "libwindows.${targetsVersion()}.a")
    @Expect(archive.indexOf("/", 0), None)
    @Expect(archive.indexOf("\\", 0), None)
}
