package windows_sample_thread_pool_work

import windows_sample_thread_pool_work_bindings.Win32.System.Threading.{Apis, PTP_CALLBACK_INSTANCE, PTP_WORK}
import std.sync.AtomicInt32

// ============================================================================
// thread_pool_work — behaviour-equivalent port of the reference sample.
//
// Creates a thread-pool work object with CreateThreadpoolWork, submits it ten
// times with SubmitThreadpoolWork, then drains the queue with
// WaitForThreadpoolWorkCallbacks. The work callback increments a shared counter
// once per invocation, so the final count is 10.
//
// Paradigm note (Cangjie vs the reference language):
//   • PTP_WORK_CALLBACK is a top-level `@C func`. A Cangjie @C function IS a
//     CFunc value and can be handed to a Win32 API expecting a function
//     pointer; like the reference's `extern "system" fn`, it CANNOT capture, so
//     the accumulator lives in a top-level global. The reference uses a static
//     RwLock<i32>; an AtomicInt32 is the behaviour-equivalent shared counter —
//     the thread-pool worker threads each fetchAdd(1) without a separate lock.
//   • The reference passes `None` for the optional pv / pcbe parameters; the
//     ABI value for an absent LPVOID / PTP_CALLBACK_ENVIRON is the null pointer,
//     i.e. CPointer<Unit>(). There is no `null` keyword in Cangjie.
//   • CreateThreadpoolWork returns the PTP_WORK handle directly (it has no
//     fallible/HRESULT twin); failure is signalled by a null handle, mirroring
//     the reference's `?` which would early-return on a null handle.
// ============================================================================

// Shared counter, accumulated from the worker-thread callbacks. Top-level
// because the @C callback cannot capture surrounding state.
let counter = AtomicInt32(0)

// PTP_WORK_CALLBACK: (PTP_CALLBACK_INSTANCE, LPVOID context, PTP_WORK).
// All three parameters are ignored; the body simply bumps the counter.
@C
func callback(_: PTP_CALLBACK_INSTANCE, _: CPointer<Unit>, _: PTP_WORK): Unit {
    counter.fetchAdd(1)
}

main(): Int64 {
    unsafe {
        // None / None for the optional context and callback-environment pointers.
        let work = Apis.CreateThreadpoolWork(callback, CPointer<Unit>(), CPointer<Unit>())
        if (work.Value.isNull()) {
            // CreateThreadpoolWork failed; report a non-zero exit code, matching
            // the reference's `?` early-return on error.
            return 1
        }

        for (_ in 0..10) {
            Apis.SubmitThreadpoolWork(work)
        }

        // fCancelPendingCallbacks = false -> wait for all submitted work to run.
        Apis.WaitForThreadpoolWorkCallbacks(work, 0)
    }

    println("counter: ${counter.load()}")
    return 0
}
