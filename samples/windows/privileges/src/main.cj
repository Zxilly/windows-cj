package windows_sample_privileges

import windows_sample_privileges_bindings.Win32.Foundation.{HANDLE, HLOCAL, Apis as FoundationApis}
import windows_sample_privileges_bindings.Win32.Security.{TOKEN_PRIVILEGES, LUID_AND_ATTRIBUTES, Apis as SecurityApis}
import windows_sample_privileges_bindings.Win32.System.Threading.{Apis as ThreadingApis}
import windows_sample_privileges_bindings.Win32.System.Memory.{Apis as MemoryApis}
import windows_strings.decodeUtf16

// ============================================================================
// privileges — behaviour-equivalent port of the reference sample.
//
// Opens the current process token (OpenProcessToken with TOKEN_QUERY), then
// uses the classic two-pass GetTokenInformation(TokenPrivileges) pattern: the
// first call with a null buffer reports the required byte count, then a
// LocalAlloc'd block of that size is filled by the second call. The block is
// reinterpreted as a TOKEN_PRIVILEGES header and its variable-length
// Privileges[] array is walked by raw pointer arithmetic. Each privilege's
// LUID is resolved to a name with the two-pass LookupPrivilegeNameW and printed.
// The buffer is released with LocalFree; the token handle is reclaimed at
// process exit, matching the reference which relies on Owned/Drop.
//
// Paradigm notes (Cangjie vs the reference language):
//   • There is no borrow/ownership ABI. Out-parameters are passed as
//     CPointer<Unit>(CPointer<T>(inout v)); the generated *Checked twins throw
//     on a zero (failure) return, mirroring the reference's `?` propagation.
//   • `inout` is a CALL-SITE-ONLY construct in Cangjie and may not appear on a
//     function parameter, nor target a `let`/parameter binding. So the LUID is
//     taken from a local `var entry` copied out of the array, and the whole
//     name-resolution is inline in the walk loop (no by-ref helper).
//   • The facade re-exports types but NOT scalar constants, so the documented
//     bit values TOKEN_QUERY / TokenPrivileges / LPTR are inlined as constants
//     (their impl-level values: 8, 3, 64 — see the generated symbols module).
//   • TOKEN_PRIVILEGES / LUID_AND_ATTRIBUTES / LUID are @C structs (CType), so
//     they round-trip through CPointer. The variable-length Privileges[] is
//     reached by casting the buffer to a byte pointer, skipping the 4-byte
//     UInt32 PrivilegeCount header, and indexing LUID_AND_ATTRIBUTES elements —
//     the equivalent of the reference's `header.Privileges.as_ptr()` walk.
//   • LookupPrivilegeNameW takes &privilege.Luid; the LUID is the first field
//     of LUID_AND_ATTRIBUTES (offset 0), so a pointer to the element is also a
//     pointer to its LUID. LocalAlloc's uBytes is a SIZE_T, surfaced in this
//     ABI as a CPointer<Unit> whose address-bits carry the byte count.
// ============================================================================

// Documented scalar constants the facade does not export.
//   TOKEN_QUERY      = TOKEN_ACCESS_MASK 0x0008
//   TokenPrivileges  = TOKEN_INFORMATION_CLASS 3
//   LPTR             = LOCAL_ALLOC_FLAGS 0x0040 (LMEM_FIXED | LMEM_ZEROINIT)
const TOKEN_QUERY: UInt32 = 0x0008
const TOKEN_PRIVILEGES_CLASS: Int32 = 3
const LPTR: UInt32 = 0x0040

main(): Int64 {
    unsafe {
        // OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)
        var token = HANDLE()
        let tokenPtr = CPointer<Unit>(CPointer<HANDLE>(inout token))
        ThreadingApis.OpenProcessTokenChecked(
            ThreadingApis.GetCurrentProcess(), TOKEN_QUERY, tokenPtr)

        // First pass: discover the required buffer size. The unchecked call is
        // expected to fail with ERROR_INSUFFICIENT_BUFFER and fill bytesRequired.
        var bytesRequired: UInt32 = 0
        let bytesRequiredPtr = CPointer<Unit>(CPointer<UInt32>(inout bytesRequired))
        SecurityApis.GetTokenInformation(
            token, TOKEN_PRIVILEGES_CLASS, CPointer<Unit>(), 0, bytesRequiredPtr)

        // LocalAlloc(LPTR, bytesRequired): uBytes is SIZE_T, modelled here as a
        // CPointer<Unit> whose address-bits ARE the byte count.
        let sizeArg = CPointer<Unit>(CPointer<UInt8>() + Int64(bytesRequired))
        let buffer = MemoryApis.LocalAlloc(LPTR, sizeArg)
        let bufferPtr = buffer.Value
        if (bufferPtr.isNull()) {
            return 1
        }

        try {
            // Second pass: fill the buffer.
            var written = bytesRequired
            let writtenPtr = CPointer<Unit>(CPointer<UInt32>(inout written))
            SecurityApis.GetTokenInformationChecked(
                token, TOKEN_PRIVILEGES_CLASS, bufferPtr, bytesRequired, writtenPtr)

            // header = *(TOKEN_PRIVILEGES*)buffer
            let header = CPointer<TOKEN_PRIVILEGES>(bufferPtr).read()
            let count = Int64(header.PrivilegeCount)

            // privileges = &header.Privileges[0]: skip the 4-byte PrivilegeCount
            // field, then index LUID_AND_ATTRIBUTES elements.
            let arrayBase = CPointer<LUID_AND_ATTRIBUTES>(CPointer<UInt8>(bufferPtr) + 4)

            var index = 0
            while (index < count) {
                // Copy the element out so its LUID lives in a local `var`, the
                // only thing `inout` may target.
                var entry = (arrayBase + index).read()
                printPrivilegeName(entry)
                index += 1
            }
        } finally {
            FoundationApis.LocalFree(buffer)
        }
    }
    return 0
}

// Resolve a single privilege LUID to its name and print it via the two-pass
// LookupPrivilegeNameW size pattern. `entry` is taken by value; its LUID is at
// offset 0, so a pointer to the (local, mutable copy of the) entry is also a
// pointer to its LUID.
func printPrivilegeName(entry: LUID_AND_ATTRIBUTES): Unit {
    var local = entry
    unsafe {
        let luidPtr = CPointer<Unit>(CPointer<LUID_AND_ATTRIBUTES>(inout local))

        // First pass: lpName null -> nameLen receives the required length
        // (including the terminating null).
        var nameLen: UInt32 = 0
        let nameLenPtr = CPointer<Unit>(CPointer<UInt32>(inout nameLen))
        SecurityApis.LookupPrivilegeNameW(
            CPointer<UInt16>(), luidPtr, CPointer<UInt16>(), nameLenPtr)

        // Buffer of nameLen + 1 UInt16s, mirroring the reference's vec![0u16; n+1].
        let name = Array<UInt16>(Int64(nameLen) + 1, repeat: 0u16)
        let nameHandle = acquireArrayRawData(name)
        try {
            // Second pass writes the name and updates len to the character count
            // (excluding the terminating null).
            var len = nameLen
            let lenPtr = CPointer<Unit>(CPointer<UInt32>(inout len))
            SecurityApis.LookupPrivilegeNameWChecked(
                CPointer<UInt16>(), luidPtr, nameHandle.pointer, lenPtr)

            println(decodeUtf16(name[0..Int64(len)]))
        } finally {
            releaseArrayRawData(nameHandle)
        }
    }
}
