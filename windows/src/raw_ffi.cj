package windows

import windows_sys.win32.foundation.*
import windows_sys.win32.security.*
import windows_sys.win32.storage.file_system.*
import windows_sys.win32.system.library_loader.*
import windows_sys.win32.system.threading.*
import windows_sys.win32.ui.windows_and_messaging.*

foreign {
    func GetLastError(): WIN32_ERROR
    func CloseHandle(hObject: HANDLE): Int32
    func CreateFileW(
        lpFileName: CPointer<UInt16>,
        dwDesiredAccess: UInt32,
        dwShareMode: FILE_SHARE_MODE,
        lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>,
        dwCreationDisposition: FILE_CREATION_DISPOSITION,
        dwFlagsAndAttributes: FILE_FLAGS_AND_ATTRIBUTES,
        hTemplateFile: HANDLE
    ): HANDLE
    func MessageBoxW(
        hWnd: HWND,
        lpText: CPointer<UInt16>,
        lpCaption: CPointer<UInt16>,
        uType: MESSAGEBOX_STYLE
    ): MESSAGEBOX_RESULT
    func GetModuleHandleW(lpModuleName: CPointer<UInt16>): HMODULE
    func LoadLibraryW(lpLibFileName: CPointer<UInt16>): HMODULE
    func CreateDirectoryW(
        lpPathName: CPointer<UInt16>,
        lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>
    ): Int32
    func DeleteFileW(lpFileName: CPointer<UInt16>): Int32
    func MoveFileW(
        lpExistingFileName: CPointer<UInt16>,
        lpNewFileName: CPointer<UInt16>
    ): Int32

    func CreateEventW(
        lpEventAttributes: CPointer<SECURITY_ATTRIBUTES>,
        bManualReset: Int32,
        bInitialState: Int32,
        lpName: CPointer<UInt16>
    ): HANDLE
    func CreateMutexW(
        lpMutexAttributes: CPointer<SECURITY_ATTRIBUTES>,
        bInitialOwner: Int32,
        lpName: CPointer<UInt16>
    ): HANDLE
    func ReleaseMutex(hMutex: HANDLE): Int32
    func WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: UInt32): WAIT_EVENT
    func WaitForMultipleObjects(
        nCount: UInt32,
        lpHandles: CPointer<HANDLE>,
        bWaitAll: Int32,
        dwMilliseconds: UInt32
    ): WAIT_EVENT
    func Sleep(dwMilliseconds: UInt32): Unit
    func EnterCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit
    func LeaveCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit

    func RegisterClassExW(lpwcx: CPointer<WNDCLASSEXW>): UInt16
    func CreateWindowExW(
        dwExStyle: WINDOW_EX_STYLE,
        lpClassName: CPointer<UInt16>,
        lpWindowName: CPointer<UInt16>,
        dwStyle: WINDOW_STYLE,
        x: Int32,
        y: Int32,
        nWidth: Int32,
        nHeight: Int32,
        hWndParent: HWND,
        hMenu: HMENU,
        hInstance: HINSTANCE,
        lpParam: CPointer<Unit>
    ): HWND
    func ShowWindow(hWnd: HWND, nCmdShow: SHOW_WINDOW_CMD): Int32
    func UpdateWindow(hWnd: HWND): Int32
    func DestroyWindow(hWnd: HWND): Int32
    func GetMessageW(
        lpMsg: CPointer<MSG>,
        hWnd: HWND,
        wMsgFilterMin: UInt32,
        wMsgFilterMax: UInt32
    ): Int32
    func TranslateMessage(lpMsg: CPointer<MSG>): Int32
    func DispatchMessageW(lpMsg: CPointer<MSG>): IntNative
    func SetTimer(
        hWnd: HWND,
        nIDEvent: UIntNative,
        uElapse: UInt32,
        lpTimerFunc: TIMERPROC
    ): UIntNative
    func KillTimer(hWnd: HWND, uIDEvent: UIntNative): Int32
    func EnumWindows(lpEnumFunc: WNDENUMPROC, lParam: IntNative): Int32
    func EnumChildWindows(hWndParent: HWND, lpEnumFunc: WNDENUMPROC, lParam: IntNative): Int32
    func PostQuitMessage(nExitCode: Int32): Unit
}

func ffiGetLastError(): WIN32_ERROR {
    unsafe { GetLastError() }
}

func ffiCloseHandle(hObject: HANDLE): Int32 {
    unsafe { CloseHandle(hObject) }
}

func ffiCreateFileW(
    lpFileName: CPointer<UInt16>,
    dwDesiredAccess: UInt32,
    dwShareMode: FILE_SHARE_MODE,
    lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>,
    dwCreationDisposition: FILE_CREATION_DISPOSITION,
    dwFlagsAndAttributes: FILE_FLAGS_AND_ATTRIBUTES,
    hTemplateFile: HANDLE
): HANDLE {
    unsafe {
        CreateFileW(
            lpFileName,
            dwDesiredAccess,
            dwShareMode,
            lpSecurityAttributes,
            dwCreationDisposition,
            dwFlagsAndAttributes,
            hTemplateFile
        )
    }
}

func ffiMessageBoxW(
    hWnd: HWND,
    lpText: CPointer<UInt16>,
    lpCaption: CPointer<UInt16>,
    uType: MESSAGEBOX_STYLE
): MESSAGEBOX_RESULT {
    unsafe { MessageBoxW(hWnd, lpText, lpCaption, uType) }
}

func ffiGetModuleHandleW(lpModuleName: CPointer<UInt16>): HMODULE {
    unsafe { GetModuleHandleW(lpModuleName) }
}

func ffiLoadLibraryW(lpLibFileName: CPointer<UInt16>): HMODULE {
    unsafe { LoadLibraryW(lpLibFileName) }
}

func ffiCreateDirectoryW(
    lpPathName: CPointer<UInt16>,
    lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>
): Int32 {
    unsafe { CreateDirectoryW(lpPathName, lpSecurityAttributes) }
}

func ffiDeleteFileW(lpFileName: CPointer<UInt16>): Int32 {
    unsafe { DeleteFileW(lpFileName) }
}

func ffiMoveFileW(
    lpExistingFileName: CPointer<UInt16>,
    lpNewFileName: CPointer<UInt16>
): Int32 {
    unsafe { MoveFileW(lpExistingFileName, lpNewFileName) }
}

func ffiCreateEventW(
    lpEventAttributes: CPointer<SECURITY_ATTRIBUTES>,
    bManualReset: Int32,
    bInitialState: Int32,
    lpName: CPointer<UInt16>
): HANDLE {
    unsafe { CreateEventW(lpEventAttributes, bManualReset, bInitialState, lpName) }
}

func ffiCreateMutexW(
    lpMutexAttributes: CPointer<SECURITY_ATTRIBUTES>,
    bInitialOwner: Int32,
    lpName: CPointer<UInt16>
): HANDLE {
    unsafe { CreateMutexW(lpMutexAttributes, bInitialOwner, lpName) }
}

func ffiReleaseMutex(hMutex: HANDLE): Int32 {
    unsafe { ReleaseMutex(hMutex) }
}

func ffiWaitForSingleObject(hHandle: HANDLE, dwMilliseconds: UInt32): WAIT_EVENT {
    unsafe { WaitForSingleObject(hHandle, dwMilliseconds) }
}

func ffiWaitForMultipleObjects(
    nCount: UInt32,
    lpHandles: CPointer<HANDLE>,
    bWaitAll: Int32,
    dwMilliseconds: UInt32
): WAIT_EVENT {
    unsafe { WaitForMultipleObjects(nCount, lpHandles, bWaitAll, dwMilliseconds) }
}

func ffiSleep(dwMilliseconds: UInt32): Unit {
    unsafe { Sleep(dwMilliseconds) }
}

func ffiEnterCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit {
    unsafe { EnterCriticalSection(lpCriticalSection) }
}

func ffiLeaveCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit {
    unsafe { LeaveCriticalSection(lpCriticalSection) }
}

func ffiRegisterClassExW(lpwcx: CPointer<WNDCLASSEXW>): UInt16 {
    unsafe { RegisterClassExW(lpwcx) }
}

func ffiCreateWindowExW(
    dwExStyle: WINDOW_EX_STYLE,
    lpClassName: CPointer<UInt16>,
    lpWindowName: CPointer<UInt16>,
    dwStyle: WINDOW_STYLE,
    x: Int32,
    y: Int32,
    nWidth: Int32,
    nHeight: Int32,
    hWndParent: HWND,
    hMenu: HMENU,
    hInstance: HINSTANCE,
    lpParam: CPointer<Unit>
): HWND {
    unsafe {
        CreateWindowExW(
            dwExStyle,
            lpClassName,
            lpWindowName,
            dwStyle,
            x,
            y,
            nWidth,
            nHeight,
            hWndParent,
            hMenu,
            hInstance,
            lpParam
        )
    }
}

func ffiShowWindow(hWnd: HWND, nCmdShow: SHOW_WINDOW_CMD): Int32 {
    unsafe { ShowWindow(hWnd, nCmdShow) }
}

func ffiUpdateWindow(hWnd: HWND): Int32 {
    unsafe { UpdateWindow(hWnd) }
}

func ffiDestroyWindow(hWnd: HWND): Int32 {
    unsafe { DestroyWindow(hWnd) }
}

func ffiGetMessageW(
    lpMsg: CPointer<MSG>,
    hWnd: HWND,
    wMsgFilterMin: UInt32,
    wMsgFilterMax: UInt32
): Int32 {
    unsafe { GetMessageW(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax) }
}

func ffiTranslateMessage(lpMsg: CPointer<MSG>): Int32 {
    unsafe { TranslateMessage(lpMsg) }
}

func ffiDispatchMessageW(lpMsg: CPointer<MSG>): IntNative {
    unsafe { DispatchMessageW(lpMsg) }
}

func ffiSetTimer(
    hWnd: HWND,
    nIDEvent: UIntNative,
    uElapse: UInt32,
    lpTimerFunc: TIMERPROC
): UIntNative {
    unsafe { SetTimer(hWnd, nIDEvent, uElapse, lpTimerFunc) }
}

func ffiKillTimer(hWnd: HWND, uIDEvent: UIntNative): Int32 {
    unsafe { KillTimer(hWnd, uIDEvent) }
}

func ffiEnumWindows(lpEnumFunc: WNDENUMPROC, lParam: IntNative): Int32 {
    unsafe { EnumWindows(lpEnumFunc, lParam) }
}

func ffiEnumChildWindows(hWndParent: HWND, lpEnumFunc: WNDENUMPROC, lParam: IntNative): Int32 {
    unsafe { EnumChildWindows(hWndParent, lpEnumFunc, lParam) }
}

func ffiPostQuitMessage(nExitCode: Int32): Unit {
    unsafe { PostQuitMessage(nExitCode) }
}
