package windows_sys

// --- Window style constants (UInt32) ---
public let WS_OVERLAPPED: UInt32 = 0x00000000
public let WS_POPUP: UInt32 = 0x80000000
public let WS_CHILD: UInt32 = 0x40000000
public let WS_MINIMIZE: UInt32 = 0x20000000
public let WS_VISIBLE: UInt32 = 0x10000000
public let WS_DISABLED: UInt32 = 0x08000000
public let WS_CLIPSIBLINGS: UInt32 = 0x04000000
public let WS_CLIPCHILDREN: UInt32 = 0x02000000
public let WS_MAXIMIZE: UInt32 = 0x01000000
public let WS_CAPTION: UInt32 = 0x00C00000
public let WS_BORDER: UInt32 = 0x00800000
public let WS_DLGFRAME: UInt32 = 0x00400000
public let WS_VSCROLL: UInt32 = 0x00200000
public let WS_HSCROLL: UInt32 = 0x00100000
public let WS_SYSMENU: UInt32 = 0x00080000
public let WS_THICKFRAME: UInt32 = 0x00040000
public let WS_MINIMIZEBOX: UInt32 = 0x00020000
public let WS_MAXIMIZEBOX: UInt32 = 0x00010000
public let WS_OVERLAPPEDWINDOW: UInt32 = 0x00CF0000
public let WS_POPUPWINDOW: UInt32 = 0x80880000

// --- Extended window style constants ---
public let WS_EX_DLGMODALFRAME: UInt32 = 0x00000001
public let WS_EX_TOPMOST: UInt32 = 0x00000008
public let WS_EX_ACCEPTFILES: UInt32 = 0x00000010
public let WS_EX_TRANSPARENT: UInt32 = 0x00000020
public let WS_EX_APPWINDOW: UInt32 = 0x00040000
public let WS_EX_OVERLAPPEDWINDOW: UInt32 = 0x00000300
public let WS_EX_CLIENTEDGE: UInt32 = 0x00000200
public let WS_EX_WINDOWEDGE: UInt32 = 0x00000100

// --- Window message constants (UInt32) ---
public let WM_NULL: UInt32 = 0x0000
public let WM_CREATE: UInt32 = 0x0001
public let WM_DESTROY: UInt32 = 0x0002
public let WM_MOVE: UInt32 = 0x0003
public let WM_SIZE: UInt32 = 0x0005
public let WM_ACTIVATE: UInt32 = 0x0006
public let WM_SETFOCUS: UInt32 = 0x0007
public let WM_KILLFOCUS: UInt32 = 0x0008
public let WM_ENABLE: UInt32 = 0x000A
public let WM_PAINT: UInt32 = 0x000F
public let WM_CLOSE: UInt32 = 0x0010
public let WM_QUIT: UInt32 = 0x0012
public let WM_ERASEBKGND: UInt32 = 0x0014
public let WM_SHOWWINDOW: UInt32 = 0x0018
public let WM_NCCREATE: UInt32 = 0x0081
public let WM_NCDESTROY: UInt32 = 0x0082
public let WM_KEYDOWN: UInt32 = 0x0100
public let WM_KEYUP: UInt32 = 0x0101
public let WM_CHAR: UInt32 = 0x0102
public let WM_COMMAND: UInt32 = 0x0111
public let WM_SYSCOMMAND: UInt32 = 0x0112
public let WM_TIMER: UInt32 = 0x0113
public let WM_HSCROLL: UInt32 = 0x0114
public let WM_VSCROLL: UInt32 = 0x0115
public let WM_MOUSEMOVE: UInt32 = 0x0200
public let WM_LBUTTONDOWN: UInt32 = 0x0201
public let WM_LBUTTONUP: UInt32 = 0x0202
public let WM_RBUTTONDOWN: UInt32 = 0x0204
public let WM_RBUTTONUP: UInt32 = 0x0205
public let WM_USER: UInt32 = 0x0400

// --- MessageBox button/icon constants ---
public let MB_OK: UInt32 = 0x00000000
public let MB_OKCANCEL: UInt32 = 0x00000001
public let MB_ABORTRETRYIGNORE: UInt32 = 0x00000002
public let MB_YESNOCANCEL: UInt32 = 0x00000003
public let MB_YESNO: UInt32 = 0x00000004
public let MB_RETRYCANCEL: UInt32 = 0x00000005
public let MB_ICONHAND: UInt32 = 0x00000010
public let MB_ICONQUESTION: UInt32 = 0x00000020
public let MB_ICONEXCLAMATION: UInt32 = 0x00000030
public let MB_ICONASTERISK: UInt32 = 0x00000040
public let MB_ICONERROR: UInt32 = 0x00000010
public let MB_ICONWARNING: UInt32 = 0x00000030
public let MB_ICONINFORMATION: UInt32 = 0x00000040

// --- MessageBox return values ---
public let IDOK: Int32 = 1
public let IDCANCEL: Int32 = 2
public let IDABORT: Int32 = 3
public let IDRETRY: Int32 = 4
public let IDIGNORE: Int32 = 5
public let IDYES: Int32 = 6
public let IDNO: Int32 = 7

// --- ShowWindow command constants ---
public let SW_HIDE: Int32 = 0
public let SW_SHOWNORMAL: Int32 = 1
public let SW_SHOWMINIMIZED: Int32 = 2
public let SW_SHOWMAXIMIZED: Int32 = 3
public let SW_MAXIMIZE: Int32 = 3
public let SW_SHOWNOACTIVATE: Int32 = 4
public let SW_SHOW: Int32 = 5
public let SW_MINIMIZE: Int32 = 6
public let SW_SHOWMINNOACTIVE: Int32 = 7
public let SW_SHOWNA: Int32 = 8
public let SW_RESTORE: Int32 = 9
public let SW_SHOWDEFAULT: Int32 = 10

// --- SetWindowPos constants ---
public let SWP_NOSIZE: UInt32 = 0x0001
public let SWP_NOMOVE: UInt32 = 0x0002
public let SWP_NOZORDER: UInt32 = 0x0004
public let SWP_SHOWWINDOW: UInt32 = 0x0040

// --- CW_USEDEFAULT ---
public let CW_USEDEFAULT: Int32 = -2147483648 // 0x80000000 = Int32.Min

// --- User32 @C structs ---

@C
public struct WNDCLASSEXW {
    public var cbSize: UInt32 = 0
    public var style: UInt32 = 0
    // WNDPROC = LRESULT CALLBACK (HWND, UINT, WPARAM, LPARAM)
    // LPARAM is pointer-sized, so model it as a raw pointer at the callback boundary.
    // IMPORTANT: Callers must define the actual callback with @CallingConv[STDCALL].
    public var lpfnWndProc: CFunc<(HWND, UInt32, UIntNative, CPointer<Unit>) -> IntNative> = CFunc<(HWND, UInt32, UIntNative, CPointer<Unit>) -> IntNative>(CPointer<Unit>())
    public var cbClsExtra: Int32 = 0
    public var cbWndExtra: Int32 = 0
    public var hInstance: HINSTANCE = CPointer<Unit>()
    public var hIcon: HICON = CPointer<Unit>()
    public var hCursor: HCURSOR = CPointer<Unit>()
    public var hbrBackground: HBRUSH = CPointer<Unit>()
    public var lpszMenuName: CPointer<UInt16> = CPointer<UInt16>()
    public var lpszClassName: CPointer<UInt16> = CPointer<UInt16>()
    public var hIconSm: HICON = CPointer<Unit>()

    public init() {}
}

@C
public struct MSG {
    public var hwnd: HWND = CPointer<Unit>()
    public var message: UInt32 = 0
    public var wParam: UIntNative = 0
    public var lParam: IntNative = 0
    public var time: UInt32 = 0
    public var pt: POINT = POINT()
    public var lPrivate: UInt32 = 0

    public init() {}
}

@C
public struct CREATESTRUCTW {
    public var lpCreateParams: CPointer<Unit> = CPointer<Unit>()
    public var hInstance: HINSTANCE = CPointer<Unit>()
    public var hMenu: HMENU = CPointer<Unit>()
    public var hwndParent: HWND = CPointer<Unit>()
    public var cy: Int32 = 0
    public var cx: Int32 = 0
    public var y: Int32 = 0
    public var x: Int32 = 0
    public var style: Int32 = 0
    public var lpszName: CPointer<UInt16> = CPointer<UInt16>()
    public var lpszClass: CPointer<UInt16> = CPointer<UInt16>()
    public var dwExStyle: UInt32 = 0

    public init() {}
}

// --- User32 foreign functions ---

foreign {
    // MessageBox
    func MessageBoxW(
        hWnd: HWND,
        lpText: CPointer<UInt16>,
        lpCaption: CPointer<UInt16>,
        uType: UInt32
    ): Int32

    // Window class
    func RegisterClassExW(lpwcx: CPointer<WNDCLASSEXW>): UInt16
    func UnregisterClassW(lpClassName: CPointer<UInt16>, hInstance: HINSTANCE): Int32

    // Window creation / destruction
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
    // WPARAM = UIntNative, LPARAM = IntNative, LRESULT = IntNative in FFI
    func DefWindowProcW(hWnd: HWND, msg: UInt32, wParam: UIntNative, lParam: IntNative): IntNative
    func ShowWindow(hWnd: HWND, nCmdShow: Int32): Int32
    func UpdateWindow(hWnd: HWND): Int32
    func DestroyWindow(hWnd: HWND): Int32

    // Window lookup / enumeration
    func FindWindowW(
        lpClassName: CPointer<UInt16>,
        lpWindowName: CPointer<UInt16>
    ): HWND
    // IMPORTANT: lpEnumFunc callback must be defined with @CallingConv[STDCALL].
    func EnumWindows(
        lpEnumFunc: CFunc<(HWND, IntNative) -> Int32>,
        lParam: IntNative
    ): Int32
    func EnumChildWindows(
        hWndParent: HWND,
        lpEnumFunc: CFunc<(HWND, IntNative) -> Int32>,
        lParam: IntNative
    ): Int32
    func GetClassNameW(
        hWnd: HWND,
        lpClassName: CPointer<UInt16>,
        nMaxCount: Int32
    ): Int32

    // Message loop
    func GetMessageW(
        lpMsg: CPointer<MSG>,
        hWnd: HWND,
        wMsgFilterMin: UInt32,
        wMsgFilterMax: UInt32
    ): Int32
    func TranslateMessage(lpMsg: CPointer<MSG>): Int32
    func DispatchMessageW(lpMsg: CPointer<MSG>): IntNative
    func PostMessageW(hWnd: HWND, msg: UInt32, wParam: UIntNative, lParam: IntNative): Int32
    func PostQuitMessage(nExitCode: Int32): Unit
    func SendMessageW(hWnd: HWND, msg: UInt32, wParam: UIntNative, lParam: IntNative): IntNative

    // Window rect / position
    func GetClientRect(hWnd: HWND, lpRect: CPointer<RECT>): Int32
    func GetWindowRect(hWnd: HWND, lpRect: CPointer<RECT>): Int32
    func SetWindowPos(
        hWnd: HWND,
        hWndInsertAfter: HWND,
        x: Int32,
        y: Int32,
        cx: Int32,
        cy: Int32,
        uFlags: UInt32
    ): Int32
    func MoveWindow(
        hWnd: HWND,
        x: Int32,
        y: Int32,
        nWidth: Int32,
        nHeight: Int32,
        bRepaint: Int32
    ): Int32
    func InvalidateRect(hWnd: HWND, lpRect: CPointer<RECT>, bErase: Int32): Int32

    // Timer — lpTimerFunc callback must be defined with @CallingConv[STDCALL]
    func SetTimer(
        hWnd: HWND,
        nIDEvent: UIntNative,
        uElapse: UInt32,
        lpTimerFunc: CFunc<(HWND, UInt32, UIntNative, UInt32) -> Unit>
    ): UIntNative
    func KillTimer(hWnd: HWND, uIDEvent: UIntNative): Int32

    // DC
    func GetDC(hWnd: HWND): HDC
    func ReleaseDC(hWnd: HWND, hDC: HDC): Int32
}

public func user32MessageBoxW(
    hWnd: HWND,
    lpText: CPointer<UInt16>,
    lpCaption: CPointer<UInt16>,
    uType: UInt32
): Int32 {
    unsafe { MessageBoxW(hWnd, lpText, lpCaption, uType) }
}

public func user32RegisterClassExW(lpwcx: CPointer<WNDCLASSEXW>): UInt16 {
    unsafe { RegisterClassExW(lpwcx) }
}

public func user32CreateWindowExW(
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

public func user32DefWindowProcW(
    hWnd: HWND,
    msg: UInt32,
    wParam: UIntNative,
    lParam: IntNative
): IntNative {
    unsafe { DefWindowProcW(hWnd, msg, wParam, lParam) }
}

public func user32ShowWindow(hWnd: HWND, nCmdShow: Int32): Int32 {
    unsafe { ShowWindow(hWnd, nCmdShow) }
}

public func user32UpdateWindow(hWnd: HWND): Int32 {
    unsafe { UpdateWindow(hWnd) }
}

public func user32DestroyWindow(hWnd: HWND): Int32 {
    unsafe { DestroyWindow(hWnd) }
}

public func user32FindWindowW(
    lpClassName: CPointer<UInt16>,
    lpWindowName: CPointer<UInt16>
): HWND {
    unsafe { FindWindowW(lpClassName, lpWindowName) }
}

public func user32EnumWindows(
    lpEnumFunc: CFunc<(HWND, IntNative) -> Int32>,
    lParam: IntNative
): Int32 {
    unsafe { EnumWindows(lpEnumFunc, lParam) }
}

public func user32EnumChildWindows(
    hWndParent: HWND,
    lpEnumFunc: CFunc<(HWND, IntNative) -> Int32>,
    lParam: IntNative
): Int32 {
    unsafe { EnumChildWindows(hWndParent, lpEnumFunc, lParam) }
}

public func user32GetClassNameW(
    hWnd: HWND,
    lpClassName: CPointer<UInt16>,
    nMaxCount: Int32
): Int32 {
    unsafe { GetClassNameW(hWnd, lpClassName, nMaxCount) }
}

public func user32GetMessageW(
    lpMsg: CPointer<MSG>,
    hWnd: HWND,
    wMsgFilterMin: UInt32,
    wMsgFilterMax: UInt32
): Int32 {
    unsafe { GetMessageW(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax) }
}

public func user32TranslateMessage(lpMsg: CPointer<MSG>): Int32 {
    unsafe { TranslateMessage(lpMsg) }
}

public func user32DispatchMessageW(lpMsg: CPointer<MSG>): IntNative {
    unsafe { DispatchMessageW(lpMsg) }
}

public func user32PostMessageW(
    hWnd: HWND,
    msg: UInt32,
    wParam: UIntNative,
    lParam: IntNative
): Int32 {
    unsafe { PostMessageW(hWnd, msg, wParam, lParam) }
}

public func user32PostQuitMessage(nExitCode: Int32): Unit {
    unsafe { PostQuitMessage(nExitCode) }
}

public func user32SendMessageW(
    hWnd: HWND,
    msg: UInt32,
    wParam: UIntNative,
    lParam: IntNative
): IntNative {
    unsafe { SendMessageW(hWnd, msg, wParam, lParam) }
}

public func user32SetTimer(
    hWnd: HWND,
    nIDEvent: UIntNative,
    uElapse: UInt32,
    lpTimerFunc: CFunc<(HWND, UInt32, UIntNative, UInt32) -> Unit>
): UIntNative {
    unsafe { SetTimer(hWnd, nIDEvent, uElapse, lpTimerFunc) }
}

public func user32KillTimer(hWnd: HWND, uIDEvent: UIntNative): Int32 {
    unsafe { KillTimer(hWnd, uIDEvent) }
}
