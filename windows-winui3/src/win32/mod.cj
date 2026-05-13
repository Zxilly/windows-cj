package windows_winui3.win32

import windows_core.HRESULT
import windows_common.Win32.System.Com as Win32Com

public let COINIT_APARTMENTTHREADED: Int32 = 2

public func CoInitializeEx(coInit: Int32): HRESULT {
    HRESULT(Win32Com.CoInitializeEx(coInit))
}

public func CoUninitialize(): Unit {
    Win32Com.CoUninitialize()
}

public func initializeApartmentThreaded(): HRESULT {
    CoInitializeEx(COINIT_APARTMENTTHREADED)
}

public func uninitializeApartment(): Unit {
    CoUninitialize()
}
