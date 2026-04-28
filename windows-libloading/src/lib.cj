package windows_libloading

import std.collection.*
import std.sync.*

let libraryCache = HashMap<String, CPointer<Unit>>()
let symbolCache = HashMap<String, CPointer<Unit>>()
let cacheMutex = Mutex()

foreign {
    func GetProcAddress(hModule: CPointer<Unit>, lpProcName: CPointer<UInt8>): CPointer<Unit>
    func LoadLibraryA(lpLibFileName: CPointer<UInt8>): CPointer<Unit>
}

public func loadLibrary(moduleName: String): CPointer<Unit> {
    synchronized(cacheMutex) {
        if (libraryCache.contains(moduleName)) {
            return libraryCache[moduleName]
        }

        let moduleNameBytes = nullTerminatedUtf8(moduleName)
        unsafe {
            let moduleNameHandle = acquireArrayRawData(moduleNameBytes)
            try {
                let module = LoadLibraryA(moduleNameHandle.pointer)
                if (module.isNull()) {
                    throw Exception("failed to load ${moduleName}")
                }
                libraryCache[moduleName] = module
                return module
            } finally {
                releaseArrayRawData(moduleNameHandle)
            }
        }
    }
}

public func resolveProc(moduleName: String, procName: String): CPointer<Unit> {
    let cacheKey = "${moduleName}\n${procName}"
    synchronized(cacheMutex) {
        if (symbolCache.contains(cacheKey)) {
            return symbolCache[cacheKey]
        }

        let module = loadLibraryLocked(moduleName)
        let procNameBytes = nullTerminatedUtf8(procName)
        unsafe {
            let procNameHandle = acquireArrayRawData(procNameBytes)
            try {
                let proc = GetProcAddress(module, procNameHandle.pointer)
                if (proc.isNull()) {
                    throw Exception("failed to resolve ${procName} from ${moduleName}")
                }
                symbolCache[cacheKey] = proc
                return proc
            } finally {
                releaseArrayRawData(procNameHandle)
            }
        }
    }
}

public func resolveProcByOrdinal(moduleName: String, ordinal: Int64): CPointer<Unit> {
    let cacheKey = "${moduleName}\n#${ordinal}"
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

func loadLibraryLocked(moduleName: String): CPointer<Unit> {
    if (libraryCache.contains(moduleName)) {
        return libraryCache[moduleName]
    }

    let moduleNameBytes = nullTerminatedUtf8(moduleName)
    unsafe {
        let moduleNameHandle = acquireArrayRawData(moduleNameBytes)
        try {
            let module = LoadLibraryA(moduleNameHandle.pointer)
            if (module.isNull()) {
                throw Exception("failed to load ${moduleName}")
            }
            libraryCache[moduleName] = module
            return module
        } finally {
            releaseArrayRawData(moduleNameHandle)
        }
    }
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
