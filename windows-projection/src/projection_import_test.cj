package windows_projection

import std.unittest.*
import std.unittest.testmacro.*
import windows_common.Win32.Foundation as CommonFoundation
import windows_common.Win32.System.Threading as CommonThreading
import windows_projection.Win32.Foundation as ProjectionFoundation
import windows_projection.Win32.System.Threading as ProjectionThreading

@Test
func testProjectionFacadeImportsWindowsCommonFoundation(): Unit {
    @Expect(sizeOf<ProjectionFoundation.BOOL>(), sizeOf<CommonFoundation.BOOL>())
    @Expect(sizeOf<ProjectionFoundation.HRESULT>(), sizeOf<CommonFoundation.HRESULT>())
    @Expect(sizeOf<ProjectionFoundation.HWND>(), sizeOf<CommonFoundation.HWND>())
}

@Test
func testProjectionFacadeImportsWindowsCommonThreading(): Unit {
    @Expect(sizeOf<ProjectionThreading.CREATE_EVENT>(), sizeOf<CommonThreading.CREATE_EVENT>())
    @Expect(sizeOf<ProjectionThreading.PROCESS_CREATION_FLAGS>(), sizeOf<CommonThreading.PROCESS_CREATION_FLAGS>())
    @Expect(sizeOf<ProjectionThreading.PROCESS_INFORMATION>(), sizeOf<CommonThreading.PROCESS_INFORMATION>())
    @Expect(sizeOf<ProjectionThreading.THREAD_ACCESS_RIGHTS>(), sizeOf<CommonThreading.THREAD_ACCESS_RIGHTS>())
}
