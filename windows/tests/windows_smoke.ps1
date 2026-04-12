$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = "E:/Project/CS_Project/2026/ling"
$packageRoot = Join-Path $repoRoot "windows-cj/windows"
$workspaceRoot = Join-Path $env:TEMP ("windows-smoke-" + [guid]::NewGuid().ToString())
$runnerRoot = Join-Path $workspaceRoot "runner"
$srcRoot = Join-Path $runnerRoot "src"
$payloadRoot = Join-Path $workspaceRoot "payload"
$payloadLiteral = ($payloadRoot -replace '\\', '\\')
$fileLiteral = ((Join-Path $payloadRoot "smoke_a.txt") -replace '\\', '\\')
$movedLiteral = ((Join-Path $payloadRoot "smoke_b.txt") -replace '\\', '\\')

if (Test-Path $workspaceRoot) {
    Remove-Item -Recurse -Force $workspaceRoot
}
New-Item -ItemType Directory -Force $srcRoot | Out-Null

@'
[package]
  name = "windows_smoke"
  version = "0.1.0"
  description = "Smoke test for windows high-level wrappers"
  output-type = "executable"
  cjc-version = "1.1.0"

[dependencies]
  windows = { path = "E:/Project/CS_Project/2026/ling/windows-cj/windows" }
'@ | Set-Content -NoNewline (Join-Path $runnerRoot "cjpm.toml")

@"
package windows_smoke

import windows.*

public class SmokeFailure <: Exception {
    public init(msg: String) {
        super(msg)
    }
}

public class WindowCreateState {
    public var sawNcCreate: Bool = false
    public var sawCreate: Bool = false
    public var ncCreateHwnd: UIntNative = UIntNative(0)
}

public class TimerState {
    public var fired: Bool = false
    public var timerId: UIntNative = UIntNative(0)
}

func withWideString<R>(s: String, body: (CPointer<UInt16>) -> R): R {
    let ws = CWideString(s)
    try {
        return unsafe { ws.withPtr(body) }
    } finally {
        ws.close()
    }
}

func fail(msg: String): Unit {
    throw SmokeFailure(msg)
}

func expect(cond: Bool, msg: String): Unit {
    if (!cond) {
        fail(msg)
    }
}

main() {
    let module = getModuleHandle()
    expect(!module.isNull(), "getModuleHandle should return a valid module handle")

    let kernel32 = loadLibrary("kernel32.dll")
    expect(!kernel32.isNull(), "loadLibrary should return a valid module handle")

    let eventHandle = createEvent(true, true)
    try {
        let waitResult = waitForSingleObject(eventHandle, 0u32)
        expect(waitResult == WAIT_OBJECT_0, "signaled event should complete immediately")
    } finally {
        closeHandle(eventHandle)
    }

    let eventA = createEvent(true, true)
    let eventB = createEvent(true, true)
    try {
        let handles = [eventA, eventB]
        let waitResult = waitForMultipleObjects(handles, true, 0u32)
        expect(waitResult == WAIT_OBJECT_0, "all signaled events should complete immediately")
    } finally {
        closeHandle(eventB)
        closeHandle(eventA)
    }

    let mutexHandle = createMutex(true)
    try {
        releaseMutex(mutexHandle)
    } finally {
        closeHandle(mutexHandle)
    }

    let windowCreateState = WindowCreateState()
    let className = "CodexWindowsSmokeClass"
    registerWindowClass(className, CPointer<Unit>()) { _hwnd, msg, _wParam, _lParam =>
        if (msg == WM_NCCREATE) {
            windowCreateState.sawNcCreate = true
            windowCreateState.ncCreateHwnd = _hwnd.toUIntNative()
            return IntNative(1)
        }
        if (msg == WM_CREATE) {
            windowCreateState.sawCreate = true
            return IntNative(0)
        }
        IntNative(0)
    }
    let hwnd = createWindowWithHandler(
        0u32,
        className,
        "Codex Windows Smoke",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        320,
        200,
        HWND(),
        HMENU(),
        HINSTANCE()
    )
    expect(!hwnd.isNull(), "createWindowWithHandler should return a valid window handle")
    expect(windowCreateState.sawNcCreate, "createWindowWithHandler should dispatch WM_NCCREATE to the user handler")
    expect(windowCreateState.sawCreate, "createWindowWithHandler should dispatch WM_CREATE to the user handler")

    let foundTopLevelWindow = Box(false)
    enumWindows { enumHwnd =>
        if (enumHwnd.toUIntNative() == hwnd.toUIntNative()) {
            foundTopLevelWindow.value = true
            return false
        }
        true
    }
    expect(foundTopLevelWindow.value, "enumWindows should enumerate the newly created top-level window")

    let childClassName = "CodexWindowsSmokeChildClass"
    registerWindowClass(childClassName, module) { _hwnd, _msg, _wParam, _lParam =>
        if (_msg == WM_NCCREATE) {
            return IntNative(1)
        }
        IntNative(0)
    }
    let childHwnd = createWindowWithHandler(
        0u32,
        childClassName,
        "Codex Windows Smoke Child",
        WS_CHILD | WS_VISIBLE,
        0,
        0,
        80,
        40,
        hwnd,
        HMENU(),
        module
    )
    expect(!childHwnd.isNull(), "createWindowWithHandler should create child windows")

    let foundChildWindow = Box(false)
    enumChildWindows(hwnd) { enumHwnd =>
        if (enumHwnd.toUIntNative() == childHwnd.toUIntNative()) {
            foundChildWindow.value = true
            return false
        }
        true
    }
    expect(foundChildWindow.value, "enumChildWindows should enumerate the newly created child window")
    destroyWindow(childHwnd)
    destroyWindow(hwnd)

    let pendingStateA = WindowCreateState()
    let pendingStateB = WindowCreateState()
    let pendingClassNameA = "CodexWindowsPendingMatchA"
    let pendingClassNameB = "CodexWindowsPendingMatchB"
    let pendingHandlerA: (CPointer<Unit>, UInt32, UIntNative, IntNative) -> IntNative = { hwnd, msg, _wParam, _lParam =>
        if (msg == WM_NCCREATE) {
            pendingStateA.sawNcCreate = true
            pendingStateA.ncCreateHwnd = hwnd.toUIntNative()
            return IntNative(1)
        }
        if (msg == WM_CREATE) {
            pendingStateA.sawCreate = true
            return IntNative(0)
        }
        IntNative(0)
    }
    let pendingHandlerB: (CPointer<Unit>, UInt32, UIntNative, IntNative) -> IntNative = { hwnd, msg, _wParam, _lParam =>
        if (msg == WM_NCCREATE) {
            pendingStateB.sawNcCreate = true
            pendingStateB.ncCreateHwnd = hwnd.toUIntNative()
            return IntNative(1)
        }
        if (msg == WM_CREATE) {
            pendingStateB.sawCreate = true
            return IntNative(0)
        }
        IntNative(0)
    }
    registerWindowClass(pendingClassNameA, module, pendingHandlerA)
    registerWindowClass(pendingClassNameB, module, pendingHandlerB)

    let pendingRawKeyA = nextCallbackKey()
    let pendingRawKeyB = nextCallbackKey()
    let pendingKeyA = UIntNative(pendingRawKeyA)
    let pendingKeyB = UIntNative(pendingRawKeyB)
    let pendingParamA = registerPendingWndProc(pendingKeyA, pendingHandlerA)
    let pendingParamB = registerPendingWndProc(pendingKeyB, pendingHandlerB)

    var pendingHwndA = HWND()
    var pendingHwndB = HWND()
    try {
        pendingHwndA = withWideString(pendingClassNameA) { classPtr =>
            createWindowEx(
                0u32,
                classPtr,
                "Codex Pending Match A",
                WS_OVERLAPPEDWINDOW,
                CW_USEDEFAULT,
                CW_USEDEFAULT,
                240,
                180,
                HWND(),
                HMENU(),
                module,
                pendingParamA
            )
        }
        pendingHwndB = withWideString(pendingClassNameB) { classPtr =>
            createWindowEx(
                0u32,
                classPtr,
                "Codex Pending Match B",
                WS_OVERLAPPEDWINDOW,
                CW_USEDEFAULT,
                CW_USEDEFAULT,
                240,
                180,
                HWND(),
                HMENU(),
                module,
                pendingParamB
            )
        }
        expect(pendingStateA.sawNcCreate, "manual pending handler A should receive WM_NCCREATE")
        expect(pendingStateB.sawNcCreate, "manual pending handler B should receive WM_NCCREATE")
        expect(pendingStateA.sawCreate, "manual pending handler A should receive WM_CREATE")
        expect(pendingStateB.sawCreate, "manual pending handler B should receive WM_CREATE")
        expect(
            pendingStateA.ncCreateHwnd == pendingHwndA.toUIntNative(),
            "pending handler A should bind to the window created with key A"
        )
        expect(
            pendingStateB.ncCreateHwnd == pendingHwndB.toUIntNative(),
            "pending handler B should bind to the window created with key B"
        )
    } finally {
        if (!pendingHwndB.isNull()) {
            destroyWindow(pendingHwndB)
        }
        if (!pendingHwndA.isNull()) {
            destroyWindow(pendingHwndA)
        }
    }

    let dirPath = "$payloadLiteral"
    let filePath = "$fileLiteral"
    let movedPath = "$movedLiteral"

    createDirectory(dirPath)
    var duplicateDirectoryFailed = false
    try {
        createDirectory(dirPath)
    } catch (_: Win32Exception) {
        duplicateDirectoryFailed = true
    }
    expect(duplicateDirectoryFailed, "createDirectory should fail when the directory already exists")

    let fileHandle = createFile(
        filePath,
        GENERIC_WRITE,
        FILE_SHARE_NONE,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL
    )
    closeHandle(fileHandle)

    moveFile(filePath, movedPath)
    deleteFile(movedPath)
    match (tryCreateFile(movedPath, GENERIC_READ, FILE_SHARE_READ, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL)) {
        case Some(handle) =>
            closeHandle(handle)
            fail("deleted file should not be reopenable")
        case None => ()
    }

    let timerState = TimerState()
    timerState.timerId = setTimerWithHandler(HWND(), UIntNative(0), 10u32) { timerHwnd, timerMsg, timerId, _elapsed =>
        expect(timerHwnd.isNull(), "null-owner timer callback should receive a null HWND")
        expect(timerMsg == WM_TIMER, "timer callback should receive WM_TIMER")
        timerState.fired = true
        timerState.timerId = timerId
        killTimerWithHandler(HWND(), timerId)
        postQuitMessage(0)
    }
    let messageLoopExitCode = runMessageLoop()
    expect(timerState.fired, "setTimerWithHandler should invoke the registered timer callback")
    expect(timerState.timerId != UIntNative(0), "timer callback should surface a timer identifier")
    expect(messageLoopExitCode == 0, "runMessageLoop should return the quit code posted by the timer callback")
}
"@ | Set-Content -NoNewline (Join-Path $srcRoot "main.cj")

Push-Location $runnerRoot
$smokeSucceeded = $false
try {
    cjpm build | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "cjpm build failed with exit code $LASTEXITCODE"
    }
    $runOutput = cjpm run 2>&1 | Tee-Object -Variable windowsSmokeOutput | Out-String
    $windowsSmokeOutput | Out-Host
    if ($LASTEXITCODE -ne 0 -or $runOutput -match "An exception has occurred") {
        throw "cjpm run failed with exit code $LASTEXITCODE"
    }
    $smokeSucceeded = $true
}
finally {
    Pop-Location
    if ($smokeSucceeded -and (Test-Path $workspaceRoot)) {
        Remove-Item -Recurse -Force $workspaceRoot
    } elseif (-not $smokeSucceeded) {
        Write-Host "windows smoke workspace kept at: $workspaceRoot"
    }
}

Write-Host "windows smoke test passed."
