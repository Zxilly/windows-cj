package windows_runtime

import std.unittest.*
import std.unittest.testmacro.*
import windows_common.Win32.Foundation as Win32Foundation
import windows_common.Win32.System.Threading as Win32Threading
import windows_core.Result

@Test
func testFlsGetValueCheckedAcceptsNullValueWithStaleLastError() {
    let noCleanup = CFunc<(CPointer<Unit>) -> Unit>(CPointer<Unit>())
    match (Win32Threading.FlsAllocChecked(noCleanup)) {
        case Result<UInt32>.Ok(index) =>
            try {
                @Expect(Win32Threading.FlsSetValue(index, CPointer<Unit>()), true)
                Win32Foundation.SetLastError(123u32)
                match (Win32Threading.FlsGetValueChecked(index)) {
                    case Result<CPointer<Unit>>.Ok(value) => @Expect(value.isNull(), true)
                    case Result<CPointer<Unit>>.Err(error) =>
                        let _ = error
                        throw Exception("FlsGetValueChecked rejected a null FLS value with stale last error")
                }
            } finally {
                let _ = Win32Threading.FlsFree(index)
            }
        case Result<UInt32>.Err(error) =>
            let _ = error
            throw Exception("FlsAllocChecked failed")
    }
}

@Test
func testTlsGetValueCheckedAcceptsNullValueWithStaleLastError() {
    match (Win32Threading.TlsAllocChecked()) {
        case Result<UInt32>.Ok(index) =>
            try {
                @Expect(Win32Threading.TlsSetValue(index, CPointer<Unit>()), true)
                Win32Foundation.SetLastError(123u32)
                match (Win32Threading.TlsGetValueChecked(index)) {
                    case Result<CPointer<Unit>>.Ok(value) => @Expect(value.isNull(), true)
                    case Result<CPointer<Unit>>.Err(error) =>
                        let _ = error
                        throw Exception("TlsGetValueChecked rejected a null TLS value with stale last error")
                }
            } finally {
                let _ = Win32Threading.TlsFree(index)
            }
        case Result<UInt32>.Err(error) =>
            let _ = error
            throw Exception("TlsAllocChecked failed")
    }
}
