package windows

import windows_sys.Win32.Foundation.*
import windows_sys.Win32.Security.*
import windows_sys.Win32.Storage.FileSystem.*
import windows_sys.Win32.System.Threading.*
import windows_sys.Win32.UI.WindowsAndMessaging.*

foreign {
    func GetLastError(): UInt32
    func CloseHandle(hObject: HANDLE): Int32
    func CreateFileW(
        lpFileName: CPointer<UInt16>,
        dwDesiredAccess: UInt32,
        dwShareMode: UInt32,
        lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>,
        dwCreationDisposition: UInt32,
        dwFlagsAndAttributes: UInt32,
        hTemplateFile: HANDLE
    ): HANDLE
    func MessageBoxW(
        hWnd: HWND,
        lpText: CPointer<UInt16>,
        lpCaption: CPointer<UInt16>,
        uType: UInt32
    ): Int32
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
    func WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: UInt32): UInt32
    func WaitForMultipleObjects(
        nCount: UInt32,
        lpHandles: CPointer<HANDLE>,
        bWaitAll: Int32,
        dwMilliseconds: UInt32
    ): UInt32
    func Sleep(dwMilliseconds: UInt32): Unit

    func RegisterClassExW(lpwcx: CPointer<WNDCLASSEXW>): UInt16
    func CreateWindowExW(
        dwExStyle: UInt32,
        lpClassName: CPointer<UInt16>,
        lpWindowName: CPointer<UInt16>,
        dwStyle: UInt32,
        x: Int32,
        y: Int32,
        nWidth: Int32,
        nHeight: Int32,
        hWndParent: HWND,
        hMenu: HMENU,
        hInstance: HINSTANCE,
        lpParam: CPointer<Unit>
    ): HWND
    func ShowWindow(hWnd: HWND, nCmdShow: Int32): Int32
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

@When[Windows_Win32_System_Kernel == "on"]
foreign {
    func EnterCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit
    func LeaveCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit
}

func ffiGetLastError(): UInt32 {
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
            dwShareMode.value,
            lpSecurityAttributes,
            dwCreationDisposition.value,
            dwFlagsAndAttributes.value,
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
    unsafe { MESSAGEBOX_RESULT(MessageBoxW(hWnd, lpText, lpCaption, uType.value)) }
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
    unsafe { WAIT_EVENT(WaitForSingleObject(hHandle, dwMilliseconds)) }
}

func ffiWaitForMultipleObjects(
    nCount: UInt32,
    lpHandles: CPointer<HANDLE>,
    bWaitAll: Int32,
    dwMilliseconds: UInt32
): WAIT_EVENT {
    unsafe { WAIT_EVENT(WaitForMultipleObjects(nCount, lpHandles, bWaitAll, dwMilliseconds)) }
}

func ffiSleep(dwMilliseconds: UInt32): Unit {
    unsafe { Sleep(dwMilliseconds) }
}

@When[Windows_Win32_System_Kernel == "on"]
func ffiEnterCriticalSection(lpCriticalSection: CPointer<CRITICAL_SECTION>): Unit {
    unsafe { EnterCriticalSection(lpCriticalSection) }
}

@When[Windows_Win32_System_Kernel == "on"]
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
            dwExStyle.value,
            lpClassName,
            lpWindowName,
            dwStyle.value,
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
    unsafe { ShowWindow(hWnd, nCmdShow.value) }
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
