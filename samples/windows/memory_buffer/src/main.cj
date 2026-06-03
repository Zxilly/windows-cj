package windows_sample_memory_buffer

import windows_sample_memory_buffer_bindings.Foundation.MemoryBuffer
import windows_sample_memory_buffer_bindings.Win32.System.WinRT.IMemoryBufferByteAccessVtbl
import windows_core.{HRESULT, GUID, WindowsException, E_NOINTERFACE, queryInterfaceRaw}

// ============================================================================
// memory_buffer — behaviour-equivalent port of the reference sample.
//
// Creates a WinRT MemoryBuffer of 11 bytes, takes an IMemoryBufferReference on
// it, queries that reference for the IMemoryBufferByteAccess COM interop
// interface, and uses GetBuffer to obtain a raw pointer + length into the
// buffer's storage. We then write "hello world" through the raw pointer and
// read it back, asserting the round-trip.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference's `as_mut_slice` returns a `&mut [u8]` produced by
//     `slice::from_raw_parts_mut(data, len)`. Cangjie has no borrow-checked
//     slice over foreign memory; we keep the raw `CPointer<UInt8>` + length and
//     write/read bytes directly with the pointer's indexed write/read. This is
//     the exact unsafe operation the reference performs — it explicitly notes
//     "this is inherently unsafe ... no borrow/lifetime checking".
//   • MemoryBuffer.Create / CreateReference are projected as high-level
//     throwing methods (each runs the ABI call and `.check()`s the HRESULT),
//     mirroring the reference's `?`. The implicit MTA is bootstrapped by the
//     activation-factory path, so no explicit CoInitializeEx is required —
//     matching the reference, which also performs no apartment init.
//   • IMemoryBufferByteAccess is a COM interop interface whose methods are not
//     surfaced as instance methods; the generator emits its vtbl as an @C
//     struct (IMemoryBufferByteAccessVtbl). We QueryInterface the reference's
//     raw pointer for the interop IID, then invoke GetBuffer through the vtbl
//     directly — the same ABI the reference's `cast`+`GetBuffer` perform.
//   • COM-pointer lifetime is managed by the generated Resource wrappers
//     (MemoryBuffer / IMemoryBufferReference take ownership and Release on
//     close); GC owns the wrappers themselves, so no manual AddRef/Release.
// ============================================================================

// Well-known IID of Windows.Win32.System.WinRT.IMemoryBufferByteAccess. The
// synthetic interop projection carries no iid()/descriptor() constant, so we
// QueryInterface with the documented GUID, exactly as the reference's typed
// `cast::<IMemoryBufferByteAccess>()` does under the hood.
const IID_IMEMORYBUFFERBYTEACCESS: String = "5B0D3235-4DBA-4D44-865E-8F1D0E4FD04D"

// Obtain the raw (data pointer, byte length) view of the buffer backing the
// given IMemoryBufferReference raw pointer. The caller must keep the reference
// alive for the lifetime of the returned pointer (the reference notes this is
// inherently unsafe and unchecked).
func getBuffer(referenceRaw: CPointer<Unit>): (CPointer<UInt8>, Int64) {
    // QueryInterface the reference for the byte-access interop interface.
    let interopRaw = match (unsafe { queryInterfaceRaw(referenceRaw, GUID.parse(IID_IMEMORYBUFFERBYTEACCESS)) }) {
        case Some(raw) => raw
        case None => throw WindowsException(E_NOINTERFACE)
    }

    var data = CPointer<UInt8>()
    var len: UInt32 = 0
    unsafe {
        // Read the interop interface's vtbl and call GetBuffer. The ABI shape is
        // GetBuffer(this, ppData: **BYTE, pLength: *UInt32); both out-params are
        // type-erased CPointer<Unit> in this projection.
        let vtblPtr = CPointer<CPointer<IMemoryBufferByteAccessVtbl>>(interopRaw).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.GetBuffer(
            interopRaw,
            CPointer<Unit>(CPointer<CPointer<UInt8>>(inout data)),
            CPointer<Unit>(CPointer<UInt32>(inout len))
        )
        // The interop interface was AddRef'd by QueryInterface; release our ref
        // now (the underlying buffer stays valid for as long as the reference
        // wrapper is alive, which the caller guarantees). IMemoryBufferByteAccess
        // derives directly from IUnknown, so Release is on vtbl.base_.
        let _ = vtbl.base_.Release(interopRaw)
        HRESULT(hr).check()
    }

    return (data, Int64(len))
}

main(): Int64 {
    // Create an 11-byte MemoryBuffer and take a reference to it.
    let buffer = MemoryBuffer.Create(11u32)
    let reference = buffer.CreateReference()
    try {
        let referenceRaw = reference.asRaw()

        // assert_eq!(reference.Capacity()?, 11)
        var capacity: UInt32 = 0
        unsafe {
            reference.Capacity(CPointer<UInt32>(inout capacity)).check()
        }
        if (capacity != 11u32) {
            println("capacity mismatch: expected 11, got ${capacity}")
            return 1
        }

        // The literal "hello world" (11 ASCII bytes), the reference's b"hello world".
        let message: Array<UInt8> = [
            104u8, 101u8, 108u8, 108u8, 111u8, 32u8,
            119u8, 111u8, 114u8, 108u8, 100u8
        ]

        // Write to buffer...
        let (writePtr, writeLen) = getBuffer(referenceRaw)
        if (writeLen != message.size) {
            println("buffer length mismatch: expected ${message.size}, got ${writeLen}")
            return 1
        }
        unsafe {
            var i = 0
            while (i < writeLen) {
                writePtr.write(i, message[i])
                i += 1
            }
        }

        // Read from buffer...
        let (readPtr, readLen) = getBuffer(referenceRaw)
        let readBack = Array<UInt8>(readLen, repeat: 0u8)
        unsafe {
            var i = 0
            while (i < readLen) {
                readBack[i] = readPtr.read(i)
                i += 1
            }
        }

        // assert_eq!(slice, b"hello world")
        var i = 0
        while (i < message.size) {
            if (readBack[i] != message[i]) {
                println("byte ${i} mismatch: expected ${message[i]}, got ${readBack[i]}")
                return 1
            }
            i += 1
        }

        // Decode and print the round-tripped contents to make the success visible.
        println(String.fromUtf8(readBack))
    } finally {
        reference.close()
        buffer.close()
    }

    return 0
}
