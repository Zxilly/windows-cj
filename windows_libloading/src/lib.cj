package windows_libloading

import std.collection.*
import std.sync.*

let libraryCache = HashMap<String, CPointer<Unit>>()
let symbolCache = HashMap<String, CPointer<Unit>>()
let cacheMutex = Mutex()
let LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR: UInt32 = 0x00000100u32
let LOAD_LIBRARY_SEARCH_SYSTEM32: UInt32 = 0x00000800u32
let LOAD_LIBRARY_SEARCH_DEFAULT_DIRS: UInt32 = 0x00001000u32

public class FinalizerSafeProc {
    private let moduleName: String
    private let procName: String
    private var proc: CPointer<Unit> = CPointer<Unit>()

    public init(moduleName: String, procName: String) {
        ensureSystemModuleName(moduleName)
        this.moduleName = moduleName
        this.procName = procName
    }

    public func ensureResolved(): CPointer<Unit> {
        if (proc.isNull()) {
            proc = resolveProc(moduleName, procName)
        }
        proc
    }

    public func rawIfResolvedForFinalizer(): CPointer<Unit> {
        proc
    }
}

@CallingConv[STDCALL]
foreign {
    func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CPointer<UInt8>): CPointer<Unit>
    func FreeLibrary(hLibModule: CPointer<Unit>): Int32
    func LoadLibraryExA(lpLibFileName: CPointer<UInt8>, hFile: CPointer<Unit>, dwFlags: UInt32): CPointer<Unit>
}

public func loadLibrary(moduleName: String): CPointer<Unit> {
    let moduleKey = systemModuleKey(moduleName)
    synchronized(cacheMutex) {
        if (libraryCache.contains(moduleKey)) {
            return libraryCache[moduleKey]
        }

        let moduleNameBytes = nullTerminatedUtf8(moduleName)
        let module = loadSystemLibraryUncached(moduleNameBytes)
        libraryCache[moduleKey] = module
        return module
    }
}

public func resolveProc(moduleName: String, procName: String): CPointer<Unit> {
    let moduleKey = systemModuleKey(moduleName)
    let cacheKey = "${moduleKey}\n${procName}"
    synchronized(cacheMutex) {
        if (symbolCache.contains(cacheKey)) {
            return symbolCache[cacheKey]
        }

        let module = loadLibraryLocked(moduleName)
        let procNameBytes = nullTerminatedUtf8(procName)
        let proc = resolveProcUncached(module, procNameBytes)
        symbolCache[cacheKey] = proc
        return proc
    }
}

public func resolveProcFromSearchPath(moduleName: String, procName: String): CPointer<Unit> {
    let moduleKey = searchPathModuleKey(moduleName)
    let cacheKey = "${moduleKey}\n${procName}"
    synchronized(cacheMutex) {
        if (symbolCache.contains(cacheKey)) {
            return symbolCache[cacheKey]
        }

        let module = loadLibraryFromSearchPathLocked(moduleName)
        let procNameBytes = nullTerminatedUtf8(procName)
        let proc = resolveProcUncached(module, procNameBytes)
        symbolCache[cacheKey] = proc
        return proc
    }
}

public func resolveProcByOrdinal(moduleName: String, ordinal: Int64): CPointer<Unit> {
    if (ordinal < 0 || ordinal > 0xFFFF) {
        throw Exception("ordinal must be in the range 0..65535")
    }
    let moduleKey = systemModuleKey(moduleName)
    let cacheKey = "${moduleKey}\n#${ordinal}"
    synchronized(cacheMutex) {
        if (symbolCache.contains(cacheKey)) {
            return symbolCache[cacheKey]
        }

        let module = loadLibraryLocked(moduleName)
        let ordinalPtr = unsafe { CPointer<UInt8>() + ordinal }
        let proc = unsafe { GetProcAddress(module, ordinalPtr) }
        if (proc.isNull()) {
            throw Exception("failed to resolve ordinal #${ordinal} from ${moduleName}")
        }
        symbolCache[cacheKey] = proc
        return proc
    }
}

public func loadSystemLibraryUncached(moduleNameBytes: Array<UInt8>): CPointer<Unit> {
    ensureSystemModuleNameBytes(moduleNameBytes)
    loadLibraryWithFlags(moduleNameBytes, LOAD_LIBRARY_SEARCH_SYSTEM32)
}

public func loadLibraryUncached(moduleNameBytes: Array<UInt8>): CPointer<Unit> {
    loadLibraryWithFlags(moduleNameBytes, LOAD_LIBRARY_SEARCH_DEFAULT_DIRS)
}

public func loadLibraryFromSearchPathUncached(moduleName: String): CPointer<Unit> {
    let moduleNameBytes = nullTerminatedUtf8(moduleName)
    loadLibraryWithFlags(moduleNameBytes, searchPathLoadFlags(moduleName))
}

func loadLibraryWithFlags(moduleNameBytes: Array<UInt8>, flags: UInt32): CPointer<Unit> {
    ensureNullTerminatedBytes(moduleNameBytes, "module name")
    unsafe {
        let moduleNameHandle = acquireArrayRawData(moduleNameBytes)
        try {
            let module = LoadLibraryExA(moduleNameHandle.pointer, CPointer<Unit>(), flags)
            if (module.isNull()) {
                throw Exception("failed to load module")
            }
            module
        } finally {
            releaseArrayRawData(moduleNameHandle)
        }
    }
}

public func resolveProcUncached(module: CPointer<Unit>, procNameBytes: Array<UInt8>): CPointer<Unit> {
    ensureNullTerminatedBytes(procNameBytes, "proc name")
    unsafe {
        let procNameHandle = acquireArrayRawData(procNameBytes)
        try {
            let proc = GetProcAddress(module, procNameHandle.pointer)
            if (proc.isNull()) {
                throw Exception("failed to resolve proc")
            }
            proc
        } finally {
            releaseArrayRawData(procNameHandle)
        }
    }
}

public func freeLibrary(module: CPointer<Unit>): Int32 {
    unsafe { FreeLibrary(module) }
}

func loadLibraryLocked(moduleName: String): CPointer<Unit> {
    let moduleKey = systemModuleKey(moduleName)
    if (libraryCache.contains(moduleKey)) {
        return libraryCache[moduleKey]
    }

    let moduleNameBytes = nullTerminatedUtf8(moduleName)
    let module = loadSystemLibraryUncached(moduleNameBytes)
    libraryCache[moduleKey] = module
    return module
}

func loadLibraryFromSearchPathLocked(moduleName: String): CPointer<Unit> {
    let moduleKey = searchPathModuleKey(moduleName)
    if (libraryCache.contains(moduleKey)) {
        return libraryCache[moduleKey]
    }

    let module = loadLibraryFromSearchPathUncached(moduleName)
    libraryCache[moduleKey] = module
    return module
}

func systemModuleKey(moduleName: String): String {
    ensureSystemModuleName(moduleName)
    "system:${canonicalModuleName(moduleName)}"
}

func searchPathModuleKey(moduleName: String): String {
    "search:${canonicalModuleName(moduleName)}"
}

func canonicalModuleName(moduleName: String): String {
    let bytes = moduleName.toArray()
    let length = Int64(bytes.size)
    let normalized = Array<UInt8>(length, { index =>
        let byte = bytes[index]
        if (byte >= 0x41u8 && byte <= 0x5Au8) {
            byte + 0x20u8
        } else {
            byte
        }
    })
    String.fromUtf8(normalized)
}

func searchPathLoadFlags(moduleName: String): UInt32 {
    if (isAbsoluteModulePath(moduleName)) {
        return LOAD_LIBRARY_SEARCH_DEFAULT_DIRS + LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR
    }
    LOAD_LIBRARY_SEARCH_DEFAULT_DIRS
}

func ensureSystemModuleName(moduleName: String): Unit {
    if (isPathLikeModuleName(moduleName)) {
        throw Exception("system module loads require a bare DLL name")
    }
}

func ensureSystemModuleNameBytes(moduleNameBytes: Array<UInt8>): Unit {
    var index: Int64 = 0
    while (index < moduleNameBytes.size) {
        let byte = moduleNameBytes[index]
        if (byte == 0u8) {
            return
        }
        if (isPathSeparator(byte) || byte == 0x3Au8) {
            throw Exception("system module loads require a bare DLL name")
        }
        index += 1
    }
    throw Exception("module name must be null-terminated")
}

func ensureNullTerminatedBytes(bytes: Array<UInt8>, label: String): Unit {
    var index: Int64 = 0
    while (index < bytes.size) {
        if (bytes[index] == 0u8) {
            return
        }
        index += 1
    }
    throw Exception("${label} must be null-terminated")
}

func isPathLikeModuleName(moduleName: String): Bool {
    let bytes = moduleName.toArray()
    for (byte in bytes) {
        if (isPathSeparator(byte) || byte == 0x3Au8) {
            return true
        }
    }
    false
}

func isAbsoluteModulePath(moduleName: String): Bool {
    let bytes = moduleName.toArray()
    if (bytes.size >= 3 && bytes[1] == 0x3Au8 && isPathSeparator(bytes[2])) {
        return true
    }
    if (bytes.size >= 2 && isPathSeparator(bytes[0]) && isPathSeparator(bytes[1])) {
        return true
    }
    false
}

func isPathSeparator(value: UInt8): Bool {
    value == 0x5Cu8 || value == 0x2Fu8
}

func nullTerminatedUtf8(value: String): Array<UInt8> {
    let bytes = value.toArray()
    let length = Int64(bytes.size)
    return Array<UInt8>(length + 1, { index =>
        if (index < length) {
            bytes[index]
        } else {
            0u8
        }
    })
}
