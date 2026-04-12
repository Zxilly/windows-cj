package result_smoke_abort_probe

import windows_result.*
import windows_result.Error as WinError

main(): Unit {
    try {
        let _ = Result<Int32>.Err(WinError.fromHRESULT(E_FAIL)).unwrap()
        println("returned")
    } catch (_: Exception) {
        println("caught")
    }
}