package windows_strings

import std.sync.AtomicInt32
import windows_libloading as windows_libloading

let observedWindowsCreateStringCount = AtomicInt32(0)
let observedWindowsDeleteStringCount = AtomicInt32(0)

public func debugObservedWindowsCreateStringCount(): Int32 {
    observedWindowsCreateStringCount.load()
}

public func debugObservedWindowsDeleteStringCount(): Int32 {
    observedWindowsDeleteStringCount.load()
}

@When[os != "Windows"]
func ensureDynamicWin32CFuncAbiSupported(): Unit {}

@When[os == "Windows" && arch == "x86_64"]
func ensureDynamicWin32CFuncAbiSupported(): Unit {}

@When[os == "Windows" && arch != "x86_64"]
func ensureDynamicWin32CFuncAbiSupported(): Unit {
    throw HStringAbiException("dynamic Win32 CFunc ABI is only supported on Windows x86_64")
}

func resolveOleaut32Proc(name: String): CPointer<Unit> {
    ensureDynamicWin32CFuncAbiSupported()
    try {
        windows_libloading.resolveProc("oleaut32.dll", name)
    } catch (_: Exception) {
        throw BStrAbiException("failed to resolve OleAut32 BSTR ABI")
    }
}

func resolveWinrtStringProc(name: String): CPointer<Unit> {
    ensureDynamicWin32CFuncAbiSupported()
    windows_libloading.resolveProc("combase.dll", name)
}

@CallingConv[STDCALL]
foreign {
    func GetProcessHeap(): CPointer<Unit>
    func HeapAlloc(hHeap: CPointer<Unit>, dwFlags: UInt32, dwBytes: UIntNative): CPointer<Unit>
    func HeapFree(hHeap: CPointer<Unit>, dwFlags: UInt32, lpMem: CPointer<Unit>): Int32
}

let sysFreeStringProc = windows_libloading.FinalizerSafeProc("oleaut32.dll", "SysFreeString")

func ensureSysFreeStringAbiResolved(): Unit {
    try {
        let _ = sysFreeStringProc.ensureResolved()
    } catch (_: Exception) {
        throw BStrAbiException("failed to resolve OleAut32 BSTR ABI")
    }
}

func sysAllocStringLenAbi(ptr: CPointer<UInt16>, unitLength: UInt32): CPointer<UInt16> {
    ensureSysFreeStringAbiResolved()
    let alloc = CFunc<(CPointer<UInt16>, UInt32) -> CPointer<UInt16>>(resolveOleaut32Proc("SysAllocStringLen"))
    unsafe {
        alloc(ptr, unitLength)
    }
}

func sysFreeStringAbi(ptr: CPointer<UInt16>): Unit {
    let proc = sysFreeStringProc.rawIfResolvedForFinalizer()
    if (proc.isNull()) {
        throw BStrAbiException("SysFreeString ABI was not resolved before finalizer-safe release")
    }
    let freeFn = CFunc<(CPointer<UInt16>) -> Unit>(proc)
    unsafe {
        freeFn(ptr)
    }
}

func sysStringLenAbi(ptr: CPointer<UInt16>): UInt32 {
    let lenFn = CFunc<(CPointer<UInt16>) -> UInt32>(resolveOleaut32Proc("SysStringLen"))
    unsafe {
        lenFn(ptr)
    }
}

func sysStringByteLenAbi(ptr: CPointer<UInt16>): UInt32 {
    let lenFn = CFunc<(CPointer<UInt16>) -> UInt32>(resolveOleaut32Proc("SysStringByteLen"))
    unsafe {
        lenFn(ptr)
    }
}

func windowsGetStringRawBufferAbi(handle: CPointer<Unit>, length: CPointer<UInt32>): CPointer<UInt16> {
    let proc = resolveWinrtStringProc("WindowsGetStringRawBuffer")
    let funcPtr = CFunc<(CPointer<Unit>, CPointer<UInt32>) -> CPointer<UInt16>>(proc)
    unsafe {
        funcPtr(handle, length)
    }
}

func windowsCreateStringAbi(source: CPointer<UInt16>, length: UInt32): CPointer<Unit> {
    var handle = CPointer<Unit>()
    let proc = resolveWinrtStringProc("WindowsCreateString")
    let funcPtr = CFunc<(CPointer<UInt16>, UInt32, CPointer<CPointer<Unit>>) -> Int32>(proc)
    let hr = unsafe {
        funcPtr(source, length, CPointer<CPointer<Unit>>(inout handle))
    }
    if (hr < 0) {
        throw HStringAbiException("WindowsCreateString failed")
    }
    observedWindowsCreateStringCount.fetchAdd(1)
    handle
}

func windowsDeleteStringAbi(handle: CPointer<Unit>): Unit {
    if (handle.isNull()) {
        return
    }
    let proc = resolveWinrtStringProc("WindowsDeleteString")
    let funcPtr = CFunc<(CPointer<Unit>) -> Int32>(proc)
    unsafe {
        funcPtr(handle)
    }
    observedWindowsDeleteStringCount.fetchAdd(1)
}

public func releaseSystemHStringHandle(handle: CPointer<Unit>): Unit {
    windowsDeleteStringAbi(handle)
}
