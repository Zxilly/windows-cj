package windows_sample_overlapped

import windows_sample_overlapped_bindings.Win32.Foundation.HANDLE
import windows_sample_overlapped_bindings.Win32.Foundation.Apis as FoundationApis
import windows_sample_overlapped_bindings.Win32.Storage.FileSystem.Apis as FileSystemApis
import windows_sample_overlapped_bindings.Win32.System.Threading.Apis as ThreadingApis
import windows_sample_overlapped_bindings.Win32.System.IO.{
    Apis as IOApis,
    OVERLAPPED,
    OVERLAPPED__Anonymous_e__Union as OVERLAPPED_0,
    OVERLAPPED__Anonymous_e__Union__Anonymous_e__Struct as OVERLAPPED_0_0
}
import std.fs.File

// ============================================================================
// overlapped — behaviour-equivalent port of the reference sample.
//
// Opens a file with FILE_FLAG_OVERLAPPED, creates a manual-reset event, and
// issues an asynchronous ReadFile that targets byte offset 9 for 12 bytes via
// an OVERLAPPED structure whose hEvent is the event. The thread then waits on
// the event, retrieves the async result with GetOverlappedResult, asserts that
// exactly 12 bytes were copied, and prints them as text.
//
// The reference opens `current_dir()/message.txt`. To stay self-contained the
// sample first writes that file with known content; reading 12 bytes from
// offset 9 yields a clean 12-character string, mirroring the reference's read
// of an existing message file. CreateFileA resolves the relative name against
// the current directory, identical to `current_dir().push("message.txt")`.
//
// Paradigm notes (Cangjie vs the reference language):
//   • OVERLAPPED is a nested-anonymous-union @C struct. The generator surfaces
//     the union as a struct with a `mut prop` over fixed storage and the inner
//     Offset/OffsetHigh as a leaf @C struct. We assemble the value bottom-up
//     (leaf -> union via its single-level mut prop -> OVERLAPPED field) — this
//     reproduces the exact C memory the reference initialises with its nested
//     struct literal.
//   • Owned HANDLEs (the file handle and the event handle) map to a Resource
//     class with a `closed` guard, an explicit close(), and a ~init() finalizer
//     — the GC-language analogue of the reference's owned-handle RAII drop that
//     CloseHandle's on scope exit. The guard prevents a double CloseHandle.
//   • CreateFileA / CreateEventA return a raw HANDLE with no HRESULT twin. The
//     reference's `?` early-returns on the failure sentinel; because the file is
//     written first the open always succeeds, and a null check is the
//     behaviour-equivalent safety net for the propagation.
//   • With FILE_FLAG_OVERLAPPED, ReadFile may complete synchronously (returns
//     TRUE) or queue asynchronously (returns FALSE with last error
//     ERROR_IO_PENDING). The authoritative result is taken from
//     GetOverlappedResult after waiting on the event, so the raw ReadFile is
//     issued and its return ignored — the reference's ERROR_IO_PENDING assert is
//     informational and its real bytes likewise come from GetOverlappedResult.
//   • GetOverlappedResultChecked throws a WindowsException on real failure,
//     mirroring the reference's `?`.
//   • Optional pointer arguments (lpSecurityAttributes, lpName,
//     lpNumberOfBytesRead) are absent; the ABI value is the null pointer, i.e.
//     a default-constructed CPointer.
//   • The scalar access/share/disposition/flag constants are not re-exported by
//     the facade, so their documented numeric values are used directly:
//       FILE_GENERIC_READ   = 1179785
//       FILE_SHARE_READ     = 1
//       OPEN_EXISTING       = 3
//       FILE_FLAG_OVERLAPPED = 1073741824
// ============================================================================

const FILE_GENERIC_READ: UInt32 = 1179785
const FILE_SHARE_READ: UInt32 = 1
const OPEN_EXISTING: UInt32 = 3
const FILE_FLAG_OVERLAPPED: UInt32 = 1073741824

// Owns a kernel HANDLE and closes it exactly once via CloseHandle, the
// behaviour-equivalent of the reference's owned-handle drop.
class OwnedHandle <: Resource {
    private let handle: HANDLE
    private var closed: Bool = false

    init(handle: HANDLE) {
        this.handle = handle
    }

    func value(): HANDLE {
        handle
    }

    public func isClosed(): Bool {
        closed
    }

    // Deterministic release: CloseHandle the kernel object once.
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        unsafe { FoundationApis.CloseHandle(handle) }
    }

    // GC safety net. Marks closed first so an interleaving close() cannot run a
    // second CloseHandle on the same handle (no double free).
    ~init() {
        if (!closed) {
            closed = true
            unsafe { FoundationApis.CloseHandle(handle) }
        }
    }
}

main(): Int64 {
    // Mirror the reference's message file. Reading 12 bytes from offset 9 of
    // this content yields the clean 12-character string "overlapped!!".
    let content = "prefix:09overlapped!!"
    File.writeTo("message.txt", content.toArray())

    // CreateFileA(lpFileName, dwDesiredAccess, dwShareMode, lpSecurityAttributes
    // = None, dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile = 0).
    // The file name is a NUL-terminated ANSI string; CreateFileA resolves the
    // relative name against the current directory.
    let fileName = "message.txt\0".toArray()
    let raw = unsafe {
        let nameHandle = acquireArrayRawData(fileName)
        try {
            FileSystemApis.CreateFileA(
                nameHandle.pointer,
                FILE_GENERIC_READ,
                FILE_SHARE_READ,
                CPointer<Unit>(),
                OPEN_EXISTING,
                FILE_FLAG_OVERLAPPED,
                HANDLE()
            )
        } finally {
            releaseArrayRawData(nameHandle)
        }
    }

    // A failed open yields a null (or invalid) handle; treat that as the
    // reference's `?` early-return with a non-zero exit code.
    if (raw.Value.isNull()) {
        return 1
    }
    let file = OwnedHandle(raw)

    try {
        // CreateEventA(lpEventAttributes = None, bManualReset = true,
        // bInitialState = false, lpName = None). true / false -> 1 / 0.
        let eventRaw = unsafe {
            ThreadingApis.CreateEventA(CPointer<Unit>(), 1, 0, CPointer<UInt8>())
        }
        if (eventRaw.Value.isNull()) {
            return 1
        }
        let event = OwnedHandle(eventRaw)

        try {
            // Build the OVERLAPPED bottom-up so the nested anonymous union holds
            // Offset = 9, OffsetHigh = 0, exactly like the reference literal.
            var inner = OVERLAPPED_0_0()
            inner.Offset = 9
            inner.OffsetHigh = 0
            var union = OVERLAPPED_0()
            union.Anonymous = inner

            var overlapped = OVERLAPPED()
            overlapped.Anonymous = union
            overlapped.hEvent = event.value()

            // 12-byte read buffer (the reference's [u8; 12]).
            let buffer = Array<UInt8>(12, repeat: 0u8)

            unsafe {
                let bufHandle = acquireArrayRawData(buffer)
                try {
                    let overlappedPtr = CPointer<Unit>(CPointer<OVERLAPPED>(inout overlapped))

                    // ReadFile(hFile, buffer, 12, lpNumberOfBytesRead = None,
                    // lpOverlapped = &overlapped). With FILE_FLAG_OVERLAPPED the
                    // call either completes synchronously (returns TRUE) or
                    // queues asynchronously (returns FALSE with last error
                    // ERROR_IO_PENDING). Either way the authoritative result is
                    // retrieved below via the event + GetOverlappedResult, so we
                    // simply issue the read — mirroring the reference, whose
                    // ERROR_IO_PENDING assertion is purely informational and
                    // whose real bytes come from GetOverlappedResult.
                    FileSystemApis.ReadFile(
                        file.value(),
                        CPointer<Unit>(bufHandle.pointer),
                        12,
                        CPointer<Unit>(),
                        overlappedPtr
                    )

                    // Wait up to 2000 ms for the read to signal the event.
                    ThreadingApis.WaitForSingleObject(event.value(), 2000)

                    // GetOverlappedResult(hFile, &overlapped, &bytesCopied,
                    // bWait = false). The throwing twin mirrors the reference's
                    // `?`.
                    var bytesCopied: UInt32 = 0
                    let bytesPtr = CPointer<Unit>(CPointer<UInt32>(inout bytesCopied))
                    IOApis.GetOverlappedResultChecked(
                        file.value(),
                        overlappedPtr,
                        bytesPtr,
                        0
                    )

                    // The reference asserts exactly 12 bytes were copied.
                    if (bytesCopied != 12) {
                        return 1
                    }
                } finally {
                    releaseArrayRawData(bufHandle)
                }
            }

            // Print the bytes as text (the reference's from_utf8_lossy). The
            // content is ASCII so this is a faithful decode.
            println(String.fromUtf8(buffer))
        } finally {
            event.close()
        }
    } finally {
        file.close()
    }

    return 0
}
