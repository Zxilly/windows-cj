package windows

// =============================================================================
// WinRT Async Bridge: IAsyncOperation<T> -> Future<T>
// =============================================================================
// WinRT asynchronous operations return IAsyncOperation<T> / IAsyncAction.
// This module provides bridge utilities to convert them into Cangjie's native
// Future<T> via spawn { ... }, supporting get(), get(timeout), and cancel().

// IAsyncInfo status values (matching Windows.Foundation.AsyncStatus enum)
public let ASYNC_STATUS_STARTED: Int32 = 0
public let ASYNC_STATUS_COMPLETED: Int32 = 1
public let ASYNC_STATUS_CANCELED: Int32 = 2
public let ASYNC_STATUS_ERROR: Int32 = 3

// IAsyncInfo vtable offsets (after IUnknown: QI=0, AddRef=1, Release=2,
// then IInspectable: GetIids=3, GetRuntimeClassName=4, GetTrustLevel=5)
// IAsyncInfo: get_Id=6, get_Status=7, get_ErrorCode=8, Cancel=9, Close=10
let IASYNCINFO_GET_STATUS_SLOT: Int64 = 7
let IASYNCINFO_GET_ERRORCODE_SLOT: Int64 = 8
let IASYNCINFO_CANCEL_SLOT: Int64 = 9

// Poll the status of an IAsyncInfo-compatible COM object.
unsafe func pollAsyncStatus(asyncInfo: CPointer<Unit>): Int32 {
    let vtblPtr = CPointer<CPointer<CPointer<Unit>>>(asyncInfo).read()
    let getStatusFn = CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32>(
        (vtblPtr + IASYNCINFO_GET_STATUS_SLOT).read()
    )
    var status: Int32 = 0
    let hr = getStatusFn(asyncInfo, CPointer<Int32>(inout status))
    if (hr < 0) {
        throw WindowsException(HRESULT(hr))
    }
    status
}

// cancelAsync — cancels an IAsyncInfo-compatible COM object.
// Public API for canceling a running async operation.
public unsafe func cancelAsync(asyncInfo: CPointer<Unit>): Unit {
    let vtblPtr = CPointer<CPointer<CPointer<Unit>>>(asyncInfo).read()
    let cancelFn = CFunc<(CPointer<Unit>) -> Int32>(
        (vtblPtr + IASYNCINFO_CANCEL_SLOT).read()
    )
    let hr = cancelFn(asyncInfo)
    if (hr < 0) {
        throw WindowsException(HRESULT(hr))
    }
}

// Get the HRESULT error code from a failed IAsyncInfo operation.
unsafe func getAsyncErrorCode(asyncInfo: CPointer<Unit>): Int32 {
    let vtblPtr = CPointer<CPointer<CPointer<Unit>>>(asyncInfo).read()
    let getErrorCodeFn = CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32>(
        (vtblPtr + IASYNCINFO_GET_ERRORCODE_SLOT).read()
    )
    var errorCode: Int32 = 0
    let hr = getErrorCodeFn(asyncInfo, CPointer<Int32>(inout errorCode))
    if (hr < 0) {
        throw WindowsException(HRESULT(hr))
    }
    errorCode
}

// waitForAsync — blocks until an IAsyncInfo-compatible operation completes.
// Polls status in a loop with short sleeps. Returns the final status.
// Respects Cangjie thread cancellation.
public unsafe func waitForAsync(asyncInfo: CPointer<Unit>): Int32 {
    while (true) {
        if (Thread.currentThread.hasPendingCancellation) {
            cancelAsync(asyncInfo)
            return ASYNC_STATUS_CANCELED
        }
        let status = pollAsyncStatus(asyncInfo)
        if (status != ASYNC_STATUS_STARTED) {
            return status
        }
        sleep(Duration.millisecond)
    }
    ASYNC_STATUS_ERROR // unreachable
}

// addRefRaw / releaseRaw — COM reference counting through IUnknown vtable
unsafe func addRefRaw(ptr: CPointer<Unit>): UInt32 {
    let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(ptr).read()
    let vtbl = vtblPtr.read()
    vtbl.AddRef(ptr)
}

unsafe func releaseRaw(ptr: CPointer<Unit>): UInt32 {
    let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(ptr).read()
    let vtbl = vtblPtr.read()
    vtbl.Release(ptr)
}

// runAsync — wraps a WinRT IAsyncOperation into a Cangjie Future.
// Takes ownership of an extra COM reference to keep the operation alive.
//
// Example:
//   let future = runAsync<StorageFile>(asyncOpPtr) { opPtr =>
//       // Call GetResults vtable slot and wrap result
//   }
//   let file = future.get()
//   // Or with timeout:
//   let file = future.get(5 * Duration.second)
public func runAsync<T>(
    asyncOp: CPointer<Unit>,
    getResults: (CPointer<Unit>) -> T
): Future<T> {
    unsafe { addRefRaw(asyncOp) }
    spawn {
        try {
            let status = unsafe { waitForAsync(asyncOp) }
            match (status) {
                case s where s == ASYNC_STATUS_COMPLETED =>
                    return getResults(asyncOp)
                case s where s == ASYNC_STATUS_CANCELED =>
                    throw WindowsException(HRESULT(E_ABORT.value))
                case _ =>
                    let errorCode = unsafe { getAsyncErrorCode(asyncOp) }
                    throw WindowsException(HRESULT(errorCode))
            }
        } finally {
            unsafe { releaseRaw(asyncOp) }
        }
    }
}
