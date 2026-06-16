package windows_safearray

import windows_sys.Win32.System.Com as ComNs
import windows_variant.VARENUM

public type SAFEARRAY = ComNs.SAFEARRAY
public type SAFEARRAYBOUND = ComNs.SAFEARRAYBOUND

public let FADF_AUTO: UInt16 = 0x0001u16
public let FADF_STATIC: UInt16 = 0x0002u16
public let FADF_EMBEDDED: UInt16 = 0x0004u16
public let FADF_FIXEDSIZE: UInt16 = 0x0010u16
public let FADF_RECORD: UInt16 = 0x0020u16
public let FADF_HAVEIID: UInt16 = 0x0040u16
public let FADF_HAVEVARTYPE: UInt16 = 0x0080u16
public let FADF_BSTR: UInt16 = 0x0100u16
public let FADF_UNKNOWN: UInt16 = 0x0200u16
public let FADF_DISPATCH: UInt16 = 0x0400u16
public let FADF_VARIANT: UInt16 = 0x0800u16
public let FADF_RESERVED: UInt16 = 0xF008u16

public func makeBound(elements: UInt32, lowerBound!: Int32 = 0i32): SAFEARRAYBOUND {
    var bound = SAFEARRAYBOUND()
    bound.cElements = elements
    bound.lLbound = lowerBound
    bound
}

func readSafeArrayDescriptor(handle: CPointer<SAFEARRAY>): SAFEARRAY {
    if (handle.isNull()) {
        throw SafeArrayAbiException("SAFEARRAY pointer is null")
    }
    unsafe { handle.read() }
}

public func safeArrayDims(handle: CPointer<SAFEARRAY>): UInt16 {
    readSafeArrayDescriptor(handle).cDims
}

public func safeArrayFeatures(handle: CPointer<SAFEARRAY>): UInt16 {
    readSafeArrayDescriptor(handle).fFeatures
}

public func safeArrayElementSize(handle: CPointer<SAFEARRAY>): UInt32 {
    readSafeArrayDescriptor(handle).cbElements
}

public func safeArrayLockCount(handle: CPointer<SAFEARRAY>): UInt32 {
    readSafeArrayDescriptor(handle).cLocks
}

public func safeArrayDataPtr(handle: CPointer<SAFEARRAY>): CPointer<Unit> {
    readSafeArrayDescriptor(handle).pvData
}
