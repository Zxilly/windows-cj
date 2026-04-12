package windows_implement

import std.collection.HashMap
import std.sync.Mutex

var comRegistryMutex = Mutex()
var comRegistry = HashMap<UIntNative, Object>()
var comSlotRegistry = HashMap<UIntNative, UIntNative>()

public func comRegistryInsert(key: UIntNative, obj: Object): Unit {
    comRegistryMutex.lock()
    comRegistry.add(key, obj)
    comRegistryMutex.unlock()
}

public func comRegistryLookup(key: UIntNative): Option<Object> {
    comRegistryMutex.lock()
    let result = comRegistry.get(key)
    comRegistryMutex.unlock()
    result
}

public func comRegistryRemove(key: UIntNative): Unit {
    comRegistryMutex.lock()
    comRegistry.remove(key)
    comRegistryMutex.unlock()
}

public func comSlotRegistryInsert(slotKey: UIntNative, rootKey: UIntNative): Unit {
    comRegistryMutex.lock()
    comSlotRegistry.add(slotKey, rootKey)
    comRegistryMutex.unlock()
}

public func comSlotRegistryLookup(slotKey: UIntNative): Option<UIntNative> {
    comRegistryMutex.lock()
    let result = comSlotRegistry.get(slotKey)
    comRegistryMutex.unlock()
    result
}

public func comSlotRegistryContains(slotKey: UIntNative): Bool {
    comRegistryMutex.lock()
    let present = comSlotRegistry.contains(slotKey)
    comRegistryMutex.unlock()
    present
}

public func comSlotRegistryRemove(slotKey: UIntNative): Unit {
    comRegistryMutex.lock()
    comSlotRegistry.remove(slotKey)
    comRegistryMutex.unlock()
}
