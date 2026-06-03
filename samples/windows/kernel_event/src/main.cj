package windows_sample_kernel_event

import windows_sample_kernel_event_bindings.Win32.Foundation.HANDLE
import windows_sample_kernel_event_bindings.Win32.Foundation.Apis as FoundationApis
import windows_sample_kernel_event_bindings.Win32.System.Threading.Apis as ThreadingApis

// ============================================================================
// kernel_event — behaviour-equivalent port of the reference sample.
//
// Creates a manual-reset kernel event with CreateEventW, signals it with
// SetEvent, then performs a zero-timeout WaitForSingleObject. Because the event
// is manual-reset and already signalled, the wait returns immediately with
// WAIT_OBJECT_0 (0). The kernel HANDLE is owned by an OwnedHandle wrapper whose
// finalizer / close() calls CloseHandle exactly once, mirroring the reference's
// owned-handle RAII that closes the handle when it goes out of scope.
//
// Paradigm note (Cangjie vs the reference language):
//   • The reference wraps the raw HANDLE in an owned-handle type whose Drop impl
//     calls CloseHandle. Cangjie is a GC language with no Drop/ownership; the
//     behaviour-equivalent construct is a class implementing the Resource
//     interface (`<: Resource`) with a `closed` guard, an explicit close() for
//     deterministic release, and a ~init() finalizer as the GC safety net. The
//     guard prevents a double CloseHandle if both close() and ~init() run.
//   • CreateEventW returns the HANDLE directly (it has no fallible/HRESULT
//     twin in the binding). The reference's `?` early-returns when the call
//     fails; a failed CreateEventW yields a null handle, so a null check is the
//     behaviour-equivalent of that error propagation.
//   • SetEvent has a throwing twin (SetEventChecked) that raises a
//     WindowsException on failure — the direct analogue of the reference's `?`.
//   • The reference passes None for the optional security attributes and the
//     optional event name; the ABI value for an absent LPSECURITY_ATTRIBUTES /
//     LPCWSTR is the null pointer. There is no `null` keyword in Cangjie, so the
//     null pointer is the default-constructed CPointer<T>().
//   • CreateEventW's bManualReset / bInitialState are Win32 BOOLs (Int32): the
//     reference passes true / false, i.e. 1 / 0.
// ============================================================================

// Owns a kernel HANDLE and closes it exactly once. CloseHandle lives in the
// Win32.Foundation Apis surface (FoundationApis here).
class OwnedHandle <: Resource {
    private let handle: HANDLE
    private var closed: Bool = false

    init(handle: HANDLE) {
        this.handle = handle
    }

    // The owned raw handle, for passing to the Win32 calls (SetEvent / wait).
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
    // CreateEventW(lpEventAttributes = None, bManualReset = true, bInitialState
    // = false, lpName = None). Null pointers for the two optional arguments.
    let raw = unsafe {
        ThreadingApis.CreateEventW(CPointer<Unit>(), 1, 0, CPointer<UInt16>())
    }

    // A failed CreateEventW returns a null handle; treat that as the reference's
    // `?` early-return with a non-zero exit code.
    if (raw.Value.isNull()) {
        return 1
    }

    // Take ownership so the handle is closed deterministically on scope exit.
    let event = OwnedHandle(raw)
    try {
        // SetEvent: throwing twin mirrors the reference's `?`.
        ThreadingApis.SetEventChecked(event.value())

        // Zero-timeout wait. The event is signalled and manual-reset, so this
        // returns WAIT_OBJECT_0 (0) immediately. The reference ignores the
        // return value; we do too.
        unsafe { ThreadingApis.WaitForSingleObject(event.value(), 0) }
    } finally {
        event.close()
    }

    return 0
}
