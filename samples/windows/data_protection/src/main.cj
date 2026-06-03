package windows_sample_data_protection

import windows_sample_data_protection_bindings.Security.Cryptography.DataProtection.DataProtectionProvider
import windows_sample_data_protection_bindings.Security.Cryptography.{CryptographicBuffer, BinaryStringEncoding}
import windows_sample_data_protection_bindings.Storage.Streams.IBuffer
import windows_sample_data_protection_bindings.Foundation.{IAsyncInfo, IAsyncOperation}
import windows_sample_data_protection_bindings.Win32.System.WinRT.IBufferByteAccessVtbl
import windows_core.{HRESULT, GUID, HString, WindowsException, E_NOINTERFACE, queryInterfaceRaw}
import std.fs.{File, removeIfExists}

// ============================================================================
// data_protection — behaviour-equivalent port of the reference sample.
//
// Uses the WinRT DataProtectionProvider to round-trip a secret string:
//   1. Create a provider bound to the "LOCAL=user" protection descriptor.
//   2. Convert "Hello world" to an IBuffer with CryptographicBuffer
//      (Utf8 encoding).
//   3. ProtectAsync the plaintext buffer, block for completion, then read the
//      protected buffer's raw bytes via the IBufferByteAccess COM interop
//      interface and persist them to secret.bin.
//   4. Read secret.bin back, rebuild an IBuffer with CreateFromByteArray,
//      UnprotectAsync it (blocking), and decode the result to a String, which
//      must equal the original "Hello world".
//
// Paradigm notes (Cangjie vs the reference language):
//   • There is no compile-time HSTRING literal (`h!`). HString values are built
//     at run time from Cangjie String with the HString(String) constructor —
//     semantically identical to an `h!` literal.
//   • BinaryStringEncoding::Utf8 == 0. The generated facade re-exports only the
//     enum type, not its scalar variant constants, so the Utf8 value is encoded
//     directly as BinaryStringEncoding(0).
//   • The async result type is the generator's own
//     Windows.Foundation.IAsyncOperation`1<IBuffer> wrapper (NOT the
//     windows_future projection), so it carries no high-level `.join()`. We
//     reproduce the reference's blocking `.join()` ourselves: QueryInterface the
//     operation for IAsyncInfo, poll Status() until it leaves the Started state,
//     then call GetResults through the operation's vtbl. This is the exact ABI
//     sequence a WinRT async-blocking helper performs. The provider's MTA is
//     bootstrapped implicitly by the activation-factory path, so — as in the
//     reference — no explicit apartment initialisation is required.
//   • IBufferByteAccess is a COM interop interface (derives from IUnknown, not
//     IInspectable) whose Buffer method is not surfaced as an instance method;
//     the generator emits its vtbl as an @C struct (IBufferByteAccessVtbl). We
//     QueryInterface the protected IBuffer's raw pointer for the interop IID,
//     read the raw byte pointer through the vtbl, and copy `Length()` bytes out
//     — the same operation the reference's `cast::<IBufferByteAccess>()` +
//     `Buffer()` + `from_raw_parts_mut` performs.
//   • File round-trip uses Cangjie's std.fs File.writeTo / File.readFrom, the
//     analogue of the reference's std::fs::write / std::fs::read.
//   • COM-pointer lifetime is owned by the generated Resource wrappers (each
//     Release's on close); GC owns the wrappers themselves, so no manual
//     AddRef/Release.
// ============================================================================

// Well-known IID of Windows.Win32.System.WinRT.IBufferByteAccess. The interop
// projection carries no iid() constant, so we QueryInterface with the documented
// GUID — exactly as the reference's typed `cast::<IBufferByteAccess>()` does.
const IID_IBUFFERBYTEACCESS: String = "905A0FEF-BC53-11DF-8C49-001E4FC686DA"

// BinaryStringEncoding.Utf8 underlying value.
const BINARY_STRING_ENCODING_UTF8: Int32 = 0

// AsyncStatus.Started — the non-terminal status; any other value means the
// operation has reached a terminal (Completed / Canceled / Error) state.
const ASYNC_STATUS_STARTED: Int32 = 0
const ASYNC_STATUS_COMPLETED: Int32 = 1

// Block until the given IAsyncOperation<IBuffer> reaches a terminal status, then
// return its result buffer. Mirrors the reference's `?.join()?`.
func awaitBuffer(operation: IAsyncOperation<IBuffer>): IBuffer {
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

    // Pull the result out of the operation's GetResults slot.
    var resultRaw = CPointer<Unit>()
    unsafe {
        operation.GetResults(CPointer<CPointer<Unit>>(inout resultRaw)).check()
    }
    return IBuffer.fromAbiTake(resultRaw)
}

// Copy the full contents of an IBuffer out as a byte array by going through the
// IBufferByteAccess interop interface. Mirrors the reference's `as_mut_bytes`.
func readBufferBytes(buffer: IBuffer): Array<UInt8> {
    // buffer.Length() -> byte count.
    var length: UInt32 = 0
    unsafe {
        buffer.Length(CPointer<UInt32>(inout length)).check()
    }

    // QueryInterface the buffer for the byte-access interop interface.
    let interopRaw = match (unsafe { queryInterfaceRaw(buffer.asRaw(), GUID.parse(IID_IBUFFERBYTEACCESS)) }) {
        case Some(raw) => raw
        case None => throw WindowsException(E_NOINTERFACE)
    }

    var data = CPointer<UInt8>()
    unsafe {
        // Read the interop vtbl and call Buffer(this, ppData: **BYTE). The
        // out-param is a type-erased CPointer<Unit> in this projection.
        let vtblPtr = CPointer<CPointer<IBufferByteAccessVtbl>>(interopRaw).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.Buffer(
            interopRaw,
            CPointer<Unit>(CPointer<CPointer<UInt8>>(inout data))
        )
        // The interop interface was AddRef'd by QueryInterface; release our ref.
        // IBufferByteAccess derives directly from IUnknown, so Release is on
        // vtbl.base_. The backing storage stays valid for as long as the buffer
        // wrapper (held by the caller) is alive.
        let _ = vtbl.base_.Release(interopRaw)
        HRESULT(hr).check()
    }

    let count = Int64(length)
    let bytes = Array<UInt8>(count, repeat: 0u8)
    unsafe {
        var i = 0
        while (i < count) {
            bytes[i] = data.read(i)
            i += 1
        }
    }
    return bytes
}

main(): Int64 {
    let secretPath = "secret.bin"

    // Build the protection descriptor + plaintext, mirroring the reference's
    // h!("LOCAL=user") / h!("Hello world").
    let descriptor = HString("LOCAL=user")
    let plaintext = HString("Hello world")
    let utf8 = BinaryStringEncoding(BINARY_STRING_ENCODING_UTF8)

    try {
        let provider = DataProtectionProvider.CreateOverloadExplicit(descriptor)
        try {
            // "Hello world" -> IBuffer (Utf8).
            let unprotected = CryptographicBuffer.ConvertStringToBinary(plaintext, utf8)
            try {
                // ProtectAsync(&unprotected).join()
                let protectOp = provider.ProtectAsync(unprotected)
                let protected = try {
                    awaitBuffer(protectOp)
                } finally {
                    protectOp.close()
                }

                try {
                    // Read the protected bytes and persist them to secret.bin.
                    let protectedBytes = readBufferBytes(protected)
                    File.writeTo(secretPath, protectedBytes)

                    // Read secret.bin back and rebuild an IBuffer.
                    let roundTrippedBytes = File.readFrom(secretPath)
                    let reloaded = CryptographicBuffer.CreateFromByteArray(roundTrippedBytes)
                    try {
                        // UnprotectAsync(&protected).join()
                        let unprotectOp = provider.UnprotectAsync(reloaded)
                        let recovered = try {
                            awaitBuffer(unprotectOp)
                        } finally {
                            unprotectOp.close()
                        }

                        try {
                            // Decode the recovered buffer back to a String.
                            let message = CryptographicBuffer.ConvertBinaryToString(utf8, recovered)
                            try {
                                // The reference prints the debug form (quoted).
                                println("\"${message}\"")
                                if (message.toString() != "Hello world") {
                                    eprintln("round-trip mismatch: got ${message}")
                                    return 1
                                }
                            } finally {
                                message.close()
                            }
                        } finally {
                            recovered.close()
                        }
                    } finally {
                        reloaded.close()
                    }
                } finally {
                    protected.close()
                }
            } finally {
                unprotected.close()
            }
        } finally {
            provider.close()
        }
    } catch (e: WindowsException) {
        // DataProtectionProvider requires a usable user/domain context; if that
        // is unavailable the WinRT call throws. Surface it as a failing exit
        // status, matching the reference's `?`-propagated Result.
        eprintln("data protection failed: ${e}")
        return 1
    } finally {
        descriptor.close()
        plaintext.close()
        // Remove the runtime artifact so the tree stays clean.
        removeIfExists(secretPath, recursive: true)
    }

    return 0
}
