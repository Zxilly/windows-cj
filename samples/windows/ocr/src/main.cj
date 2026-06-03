package windows_sample_ocr

import windows_sample_ocr_bindings.Storage.{StorageFile, FileAccessMode}
import windows_sample_ocr_bindings.Storage.Streams.IRandomAccessStream
import windows_sample_ocr_bindings.Graphics.Imaging.{BitmapDecoder, SoftwareBitmap}
import windows_sample_ocr_bindings.Media.Ocr.{OcrEngine, OcrResult}
import windows_sample_ocr_bindings.Foundation.{IAsyncInfo, IAsyncOperation}
import windows_core.{HRESULT, GUID, HString, WindowsException, RuntimeType, WinrtGenericType, E_NOINTERFACE, queryInterfaceRaw, winrtCallGenericOut}
import std.env.getWorkingDirectory

// ============================================================================
// ocr — behaviour-equivalent port of the reference sample.
//
// Resolves <cwd>/message.png, opens it as a WinRT StorageFile, decodes it into a
// SoftwareBitmap, recognises the text on it with the OCR engine built from the
// user's profile languages, and prints the recognised text. Every async call is
// driven to completion with a blocking helper, mirroring the reference's
// `?.join()?` chain.
//
// Paradigm notes (Cangjie vs the reference language):
//   • There is no compile-time HSTRING literal. The image path is built at run
//     time from std.env.getWorkingDirectory() joined with "message.png" and
//     wrapped in a real WinRT HSTRING via windows_core.HString — the same ABI a
//     literal would yield.
//   • The generated projection of IAsyncOperation<T> is the bindings' own
//     Windows.Foundation.IAsyncOperation`1 wrapper, NOT the windows_future
//     projection, so it carries no high-level `.join()`. We reproduce the
//     reference's blocking `.join()` ourselves in awaitOperation<T>: QueryInterface
//     the operation for IAsyncInfo, poll Status() until it leaves the Started
//     state, surface a faulted status as its ErrorCode HRESULT, then pull the
//     typed result through the operation's GetResults vtbl slot using
//     windows_core.winrtCallGenericOut (the canonical generic-OUT bridge that
//     wraps the raw ABI pointer into the projected T). This is the exact ABI
//     sequence a WinRT async-blocking helper performs. The OCR engine's MTA is
//     bootstrapped implicitly by the activation-factory path, so — as in the
//     reference — no explicit apartment initialisation is required.
//   • FileAccessMode::Read == 0; the facade re-exports FileAccessMode_Read, used
//     directly to match the reference's FileAccessMode::Read.
//   • BitmapDecoder exposes the SoftwareBitmap accessor only through the
//     IBitmapFrameWithSoftwareBitmap synthetic COM interface (no high-level
//     instance method). We query that interface and invoke GetSoftwareBitmapAsync
//     through it, wrapping the returned raw async-operation pointer as
//     IAsyncOperation<SoftwareBitmap> — the same call the reference's projected
//     GetSoftwareBitmapAsync performs.
//   • OcrEngine::TryCreateFromUserProfileLanguages returns the engine directly;
//     when no OCR language pack is installed the WinRT call yields a null engine,
//     which the projection surfaces as a thrown WindowsException(E_POINTER). We
//     catch it and report it as an environment dependency, matching the
//     reference's error propagation out of main.
//   • COM-pointer lifetimes are owned by the generated Resource wrappers (each
//     Release's on close); GC owns the wrappers themselves, so no manual
//     AddRef/Release.
// ============================================================================

// AsyncStatus (Windows.Foundation.AsyncStatus). Started==0 is the only
// non-terminal value; anything else ends the wait.
const ASYNC_STATUS_STARTED: Int32 = 0
const ASYNC_STATUS_COMPLETED: Int32 = 1

// FileAccessMode::Read underlying value. The facade re-exports only the
// FileAccessMode type, not its scalar variant constants, so the Read value is
// encoded directly as FileAccessMode(0).
const FILE_ACCESS_MODE_READ: Int32 = 0

// Block until the given IAsyncOperation<T> reaches a terminal status, then return
// its typed result. Mirrors the reference's `?.join()?`.
func awaitOperation<T>(operation: IAsyncOperation<T>): T
    where T <: RuntimeType & WinrtGenericType<T> {
    // QueryInterface the operation for IAsyncInfo so we can observe Status().
    let infoRaw = match (unsafe { queryInterfaceRaw(operation.asRaw(), IAsyncInfo.iid()) }) {
        case Some(raw) => raw
        case None => throw WindowsException(E_NOINTERFACE)
    }
    let info = IAsyncInfo.fromAbiTake(infoRaw)
    try {
        // Poll until the operation leaves the Started state. WinRT signals
        // completion through the runtime; a short sleep keeps this cooperative
        // without burning the CPU.
        while (true) {
            var status: Int32 = ASYNC_STATUS_STARTED
            unsafe {
                info.Status(CPointer<Int32>(inout status)).check()
            }
            if (status != ASYNC_STATUS_STARTED) {
                if (status != ASYNC_STATUS_COMPLETED) {
                    // Surface the failure HRESULT the same way the reference's
                    // join() propagates a non-success status.
                    var errorCode: Int32 = 0
                    unsafe {
                        info.ErrorCode(CPointer<Int32>(inout errorCode)).check()
                    }
                    throw WindowsException(HRESULT(errorCode))
                }
                break
            }
            sleep(Duration.millisecond * 5)
        }
    } finally {
        info.close()
    }

    // Pull the typed result out of the operation's GetResults vtbl slot via the
    // generic-OUT bridge (wraps the raw ABI pointer into the projected T).
    unsafe { winrtCallGenericOut<T>(operation.vtbl().GetResults, operation.asRaw()) }
}

main(): Int64 {
    // Build <cwd>/message.png, the reference's current_dir().push("message.png").
    let imagePath = getWorkingDirectory().join("message.png").toString()
    let message = HString(imagePath)

    try {
        // StorageFile::GetFileFromPathAsync(&HSTRING)?.join()?
        let fileOp = StorageFile.GetFileFromPathAsync(message)
        let file = try {
            awaitOperation<StorageFile>(fileOp)
        } finally {
            fileOp.close()
        }
        try {
            // file.OpenAsync(FileAccessMode::Read)?.join()?
            let streamOp = file.OpenAsync(FileAccessMode(FILE_ACCESS_MODE_READ))
            let stream = try {
                awaitOperation<IRandomAccessStream>(streamOp)
            } finally {
                streamOp.close()
            }
            try {
                // BitmapDecoder::CreateAsync(&stream)?.join()?
                let decodeOp = BitmapDecoder.CreateAsync(stream)
                let decode = try {
                    awaitOperation<BitmapDecoder>(decodeOp)
                } finally {
                    decodeOp.close()
                }
                try {
                    // decode.GetSoftwareBitmapAsync()?.join()?
                    // The accessor lives on the IBitmapFrameWithSoftwareBitmap
                    // synthetic COM interface; call it and wrap the returned
                    // async-operation pointer as IAsyncOperation<SoftwareBitmap>.
                    let frame = decode.asIBitmapFrameWithSoftwareBitmap()
                    let bitmap = try {
                        var bitmapOpRaw = CPointer<Unit>()
                        unsafe {
                            frame.GetSoftwareBitmapAsync(CPointer<CPointer<Unit>>(inout bitmapOpRaw)).check()
                        }
                        let bitmapOp = IAsyncOperation<SoftwareBitmap>.fromAbiTake(bitmapOpRaw)
                        try {
                            awaitOperation<SoftwareBitmap>(bitmapOp)
                        } finally {
                            bitmapOp.close()
                        }
                    } finally {
                        frame.close()
                    }
                    try {
                        // OcrEngine::TryCreateFromUserProfileLanguages()?
                        let engine = OcrEngine.TryCreateFromUserProfileLanguages()
                        try {
                            // engine.RecognizeAsync(&bitmap)?.join()?
                            let resultOp = engine.RecognizeAsync(bitmap)
                            let result = try {
                                awaitOperation<OcrResult>(resultOp)
                            } finally {
                                resultOp.close()
                            }
                            try {
                                // println!("{:?}", result.Text()?) — the reference
                                // prints the debug form (quoted) of the HSTRING.
                                let text = result.Text
                                println("\"${text}\"")
                                text.close()
                            } finally {
                                result.close()
                            }
                        } finally {
                            engine.close()
                        }
                    } finally {
                        bitmap.close()
                    }
                } finally {
                    decode.close()
                }
            } finally {
                stream.close()
            }
        } finally {
            file.close()
        }
    } catch (e: WindowsException) {
        // The OCR engine is null when no OCR language pack is installed (the
        // projection surfaces this as E_POINTER), and the file open fails when
        // message.png is missing. Both are environment dependencies, not code
        // defects; report and propagate a failing exit status as the reference's
        // `?` does.
        eprintln("ocr failed: ${e}")
        return 1
    } finally {
        message.close()
    }

    return 0
}
