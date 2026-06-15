package windows_reactor.winui

import std.collection.{ArrayList}
import std.process.{launch, ProcessRedirect}
import std.env.getCommandLine
import std.fs.Path
import windows_libloading as windows_libloading

// ============================================================================
// UI-stack self-bootstrap.
//
// The reactor render loop runs on the WinUI UI cjthread, and when Cangjie calls
// into native WinUI (the C2N transition) the native layout / message-pump frames
// run on the SAME cjthread stack — whose size is the runtime's coStackSize. On
// Windows that defaults to only 128 KB (CjScheduler.cpp InitCoStackSize), and the
// UI scheduler disables stack growth, so deep navigation overflows it.
//
// coStackSize is fixed at runtime init (before the program's main runs) from the
// `cjStackSize` environment variable — there is no in-process FFI to raise it
// afterwards (InitCJRuntime is pre-main + once-only). So a standalone exe launched
// with no such env cannot size its own UI stack from Cangjie code.
//
// reexecWithUiStackIfNeeded works around that: if `cjStackSize` is unset, it sets
// it and RE-LAUNCHES this same executable. The child inherits the (now-populated)
// environment block, so its runtime boots with the large UI stack; the parent just
// waits and forwards the child's exit code. When `cjStackSize` is already present
// (a launcher/wrapper set it, or we are the re-launched child), it is a no-op and
// the program runs normally — so the only cost on the configured path is one cheap
// env-var read.
//
// Call it as the FIRST thing in main(); return its value when it is Some:
//     match (reexecWithUiStackIfNeeded()) {
//         case Some(code) => return code
//         case None => ()
//     }
// ============================================================================

let UI_STACK_SENTINEL = "REACTOR_UI_STACK_BOOTSTRAPPED"

// `processorSpec` optionally pins the Cangjie scheduler's carrier count via the
// `cjProcessorNum` environment variable (same pre-main re-exec mechanism as the
// stack size). WinUI / CoreMessaging state is OS-thread-affine, but cjthreads
// migrate between carrier threads under load; with more than one carrier a
// sustained input burst can resume UI work on a different OS thread and trip a
// fail-fast assertion inside CoreMessagingXP (Win32EventLoopBridge,
// exception code 0xe0464645). Passing "1" serialises all cjthreads onto a
// single carrier, which removes the migration hazard at the cost of in-process
// parallelism. Leave it None for apps that need parallel cjthreads and do not
// drive the UI at machine-gun rates.
public func reexecWithUiStackIfNeeded(stackSpec!: String = "32mb", processorSpec!: ?String = None): ?Int64 {
    // Already re-launched (or a wrapper bootstrapped us) — never re-exec twice.
    if (environmentVariableExists(UI_STACK_SENTINEL)) {
        return None
    }
    let needStack = !environmentVariableExists("cjStackSize")
    let needProcessor = match (processorSpec) {
        case Some(_) => !environmentVariableExists("cjProcessorNum")
        case None => false
    }
    if (!needStack && !needProcessor) {
        return None
    }

    let exePath = currentExecutablePath()
    if (exePath.isEmpty()) {
        return None // cannot locate self; run on the default stack rather than fail.
    }

    // Populate the environment the child will inherit. The sentinel is a belt-and-
    // suspenders guard so the child never re-execs again even if cjStackSize were
    // somehow not inherited.
    if (!setEnvironmentVariableValue(UI_STACK_SENTINEL, "1")) {
        return None
    }
    if (needStack && !setEnvironmentVariableValue("cjStackSize", stackSpec)) {
        return None
    }
    match (processorSpec) {
        case Some(spec) =>
            if (needProcessor && !setEnvironmentVariableValue("cjProcessorNum", spec)) {
                return None
            }
        case None => ()
    }

    try {
        let child = launch(
            exePath,
            forwardedArguments(),
            workingDirectory: Path(executableDirectory(exePath)),
            stdIn: ProcessRedirect.Inherit,
            stdOut: ProcessRedirect.Inherit,
            stdErr: ProcessRedirect.Inherit
        )
        return Some(child.wait())
    } catch (_: Exception) {
        // Re-launch failed; fall back to running in-process (degraded stack) so the
        // app still starts.
        return None
    }
}

// ── Win32 helpers (reuse the package-internal FFI utilities from win32.cj) ───────

// True when the named environment variable is present in the process environment
// block. GetEnvironmentVariableW returns 0 only when the variable does not exist
// (a non-zero return — even ERROR_INSUFFICIENT_BUFFER — means it is set).
func environmentVariableExists(name: String): Bool {
    let getEnvironmentVariableW = CFunc<(CPointer<UInt16>, CPointer<UInt16>, UInt32) -> UInt32>(
        windows_libloading.resolveProc("kernel32.dll", "GetEnvironmentVariableW")
    )
    let wideName = nullTerminatedUtf16Ascii(name)
    let probe = Array<UInt16>(64, { _ => 0u16 })
    unsafe {
        let nameHandle = acquireArrayRawData(wideName)
        try {
            let probeHandle = acquireArrayRawData(probe)
            try {
                return getEnvironmentVariableW(nameHandle.pointer, probeHandle.pointer, 64u32) != 0u32
            } finally {
                releaseArrayRawData(probeHandle)
            }
        } finally {
            releaseArrayRawData(nameHandle)
        }
    }
}

func setEnvironmentVariableValue(name: String, value: String): Bool {
    let setEnvironmentVariableW = CFunc<(CPointer<UInt16>, CPointer<UInt16>) -> Int32>(
        windows_libloading.resolveProc("kernel32.dll", "SetEnvironmentVariableW")
    )
    let wideName = nullTerminatedUtf16Ascii(name)
    let wideValue = nullTerminatedUtf16Ascii(value)
    unsafe {
        let nameHandle = acquireArrayRawData(wideName)
        try {
            let valueHandle = acquireArrayRawData(wideValue)
            try {
                return setEnvironmentVariableW(nameHandle.pointer, valueHandle.pointer) != 0
            } finally {
                releaseArrayRawData(valueHandle)
            }
        } finally {
            releaseArrayRawData(nameHandle)
        }
    }
}

// Absolute path of the current executable via GetModuleFileNameW(NULL, ...).
func currentExecutablePath(): String {
    let getModuleFileNameW = CFunc<(CPointer<Unit>, CPointer<UInt16>, UInt32) -> UInt32>(
        windows_libloading.resolveProc("kernel32.dll", "GetModuleFileNameW")
    )
    let buffer = Array<UInt16>(MAX_MODULE_PATH, { _ => 0u16 })
    unsafe {
        let bufferHandle = acquireArrayRawData(buffer)
        try {
            let written = getModuleFileNameW(CPointer<Unit>(), bufferHandle.pointer, UInt32(MAX_MODULE_PATH))
            if (written == 0u32) {
                return ""
            }
            var length = Int64(written)
            if (length >= MAX_MODULE_PATH) {
                length = MAX_MODULE_PATH - 1
            }
            return utf16BufferToString(bufferHandle.pointer, length)
        } finally {
            releaseArrayRawData(bufferHandle)
        }
    }
}

// Directory portion of a path (no trailing separator). Separators are single-byte
// ASCII ('\\' or '/') which cannot occur inside a multi-byte UTF-8 sequence, so a
// byte scan is correct.
func executableDirectory(path: String): String {
    let bytes = path.toArray()
    var lastSeparator = -1
    var index = 0
    while (index < bytes.size) {
        if (bytes[index] == 92u8 || bytes[index] == 47u8) {
            lastSeparator = index
        }
        index += 1
    }
    if (lastSeparator <= 0) {
        return path
    }
    return path[0..lastSeparator]
}

// Current process arguments to forward to the child, dropping argv[0]. Returns an
// empty array when there are none (or the command line is unavailable).
func forwardedArguments(): Array<String> {
    try {
        let all = getCommandLine()
        if (all.size <= 1) {
            return Array<String>()
        }
        let forwarded = ArrayList<String>()
        var i = 1
        while (i < all.size) {
            forwarded.add(all[i])
            i += 1
        }
        return forwarded.toArray()
    } catch (_: Exception) {
        return Array<String>()
    }
}

// Decode `length` UTF-16 code units (with surrogate pairs) into a UTF-8 String.
func utf16BufferToString(buffer: CPointer<UInt16>, length: Int64): String {
    let bytes = ArrayList<UInt8>()
    var i = 0
    while (i < length) {
        var codePoint = UInt32(unsafe { buffer.read(i) })
        i += 1
        if (codePoint >= 0xD800 && codePoint <= 0xDBFF && i < length) {
            let low = UInt32(unsafe { buffer.read(i) })
            if (low >= 0xDC00 && low <= 0xDFFF) {
                codePoint = 0x10000 + ((codePoint - 0xD800) << 10) + (low - 0xDC00)
                i += 1
            }
        }
        if (codePoint < 0x80) {
            bytes.add(UInt8(codePoint))
        } else if (codePoint < 0x800) {
            bytes.add(UInt8(0xC0 | (codePoint >> 6)))
            bytes.add(UInt8(0x80 | (codePoint & 0x3F)))
        } else if (codePoint < 0x10000) {
            bytes.add(UInt8(0xE0 | (codePoint >> 12)))
            bytes.add(UInt8(0x80 | ((codePoint >> 6) & 0x3F)))
            bytes.add(UInt8(0x80 | (codePoint & 0x3F)))
        } else {
            bytes.add(UInt8(0xF0 | (codePoint >> 18)))
            bytes.add(UInt8(0x80 | ((codePoint >> 12) & 0x3F)))
            bytes.add(UInt8(0x80 | ((codePoint >> 6) & 0x3F)))
            bytes.add(UInt8(0x80 | (codePoint & 0x3F)))
        }
    }
    return String.fromUtf8(bytes.toArray())
}
