package windows_implement

import std.collection.HashMap
import std.sync.Mutex

var comRegistryMutex = Mutex()
var comRegistry = HashMap<UIntNative, Object>()
var comSlotRegistry = HashMap<UIntNative, UIntNative>()

public func comRegistryInsert(key: UIntNative, obj: Object): Unit {
    synchronized(comRegistryMutex) {
        comRegistry.add(key, obj)
    }
}

public func comRegistryLookup(key: UIntNative): Option<Object> {
    synchronized(comRegistryMutex) {
        comRegistry.get(key)
    }
}

public func comRegistryRemove(key: UIntNative): Unit {
    synchronized(comRegistryMutex) {
        comRegistry.remove(key)
    }
}

public func comSlotRegistryInsert(slotKey: UIntNative, rootKey: UIntNative): Unit {
    synchronized(comRegistryMutex) {
        comSlotRegistry.add(slotKey, rootKey)
    }
}

public func comSlotRegistryLookup(slotKey: UIntNative): Option<UIntNative> {
    synchronized(comRegistryMutex) {
        comSlotRegistry.get(slotKey)
    }
}

public func comSlotRegistryContains(slotKey: UIntNative): Bool {
    synchronized(comRegistryMutex) {
        comSlotRegistry.contains(slotKey)
    }
}

public func comSlotRegistryRemove(slotKey: UIntNative): Unit {
    synchronized(comRegistryMutex) {
        comSlotRegistry.remove(slotKey)
    }
}
