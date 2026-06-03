package windows_registry

import std.collection.*
import windows_common.Win32.Foundation as Win32Foundation
import windows_common.Win32.Security as Win32Security
import windows_common.Win32.System.Kernel as Win32Kernel
import windows_common.Win32.System.Registry as Win32Registry
import windows_result.Error as WinError
import windows_result.*
import windows_strings.*

public type FILETIME = Win32Foundation.FILETIME
public type SECURITY_ATTRIBUTES = Win32Security.SECURITY_ATTRIBUTES

public type BOOL = Int32
public type HANDLE = Win32Foundation.HANDLE
public type HKEY = Win32Registry.HKEY

private let ERROR_INVALID_DATA = 13u32
private let ERROR_NO_MORE_ITEMS = 259u32
private let KEY_READ = 131097u32
private let KEY_WRITE = 131078u32
private let REG_OPTION_NON_VOLATILE = 0u32
private let REG_OPTION_VOLATILE = 1u32
private let REG_SZ = 1u32
private let REG_EXPAND_SZ = 2u32
private let REG_BINARY = 3u32
private let REG_DWORD = 4u32
private let REG_MULTI_SZ = 7u32
private let REG_QWORD = 11u32

private let INVALID_HANDLE_VALUE: HANDLE = rawHandle(-1)
private let HKEY_CLASSES_ROOT_RAW: HKEY = rawHKey(-2147483648)
private let HKEY_CURRENT_USER_RAW: HKEY = rawHKey(-2147483647)
private let HKEY_LOCAL_MACHINE_RAW: HKEY = rawHKey(-2147483646)
private let HKEY_USERS_RAW: HKEY = rawHKey(-2147483645)
private let HKEY_CURRENT_CONFIG_RAW: HKEY = rawHKey(-2147483643)

private func rawHandle(value: Int64): HANDLE {
    var handle = HANDLE()
    handle.Value = unsafe { CPointer<Unit>(CPointer<UInt8>() + value) }
    handle
}

private func rawHKey(value: Int64): HKEY {
    var key = HKEY()
    key.Value = unsafe { CPointer<Unit>(CPointer<UInt8>() + value) }
    key
}

private func isInvalidHandle(handle: HANDLE): Bool {
    handle.Value.isNull() || handle.Value.toUIntNative() == INVALID_HANDLE_VALUE.Value.toUIntNative()
}

private func closeHandleNoThrow(handle: HANDLE): Unit {
    if (isInvalidHandle(handle)) {
        return
    }
    try {
        let _ = Win32Foundation.CloseHandle(handle)
    } catch (_: Exception) {}
}

private func closeRegistryKeyNoThrow(handle: HKEY): Unit {
    if (handle.Value.isNull()) {
        return
    }
    try {
        let _ = Win32Registry.RegCloseKey(handle)
    } catch (_: Exception) {}
}

private func win32Result(status: UInt32): Result<Unit> {
    if (status == 0u32) {
        return Result<Unit>.Ok(())
    }
    Result<Unit>.Err(errorFromWin32(status))
}

private func invalidDataError(): WinError {
    errorFromWin32(ERROR_INVALID_DATA)
}

private func withWideString<R>(text: String, action: (PWSTR) -> R): R {
    let wide = CWideString(text)
    try {
        wide.withPtr { ptr =>
            action(PWSTR.fromRaw(ptr))
        }
    } finally {
        wide.close()
    }
}

private func withOptionalByteArrayPointer<R>(buffer: Array<UInt8>, action: (CPointer<UInt8>) -> R): R {
    if (buffer.isEmpty()) {
        return action(CPointer<UInt8>())
    }
    unsafe {
        let handle = acquireArrayRawData(buffer)
        try {
            action(handle.pointer)
        } finally {
            releaseArrayRawData(handle)
        }
    }
}

private func cloneBytes(bytes: Array<UInt8>): Array<UInt8> {
    let len = Int64(bytes.size)
    var result = Array<UInt8>(len, repeat: 0u8)
    var index: Int64 = 0
    while (index < len) {
        result[index] = bytes[index]
        index += 1
    }
    result
}

private func sliceBytes(bytes: Array<UInt8>, length: Int64): Array<UInt8> {
    var actualLength = length
    if (actualLength < 0) {
        actualLength = 0
    }
    if (actualLength > Int64(bytes.size)) {
        actualLength = Int64(bytes.size)
    }
    var result = Array<UInt8>(actualLength, repeat: 0u8)
    var index: Int64 = 0
    while (index < actualLength) {
        result[index] = bytes[index]
        index += 1
    }
    result
}

private func trimTrailingWideNulls(units: Array<UInt16>): Array<UInt16> {
    var last = Int64(units.size)
    while (last > 0 && units[last - 1] == 0u16) {
        last -= 1
    }
    copyWideArray(units, length: last)
}

private func sliceWideUnits(units: Array<UInt16>, start: Int64, end: Int64): Array<UInt16> {
    var actualStart = start
    var actualEnd = end
    if (actualStart < 0) {
        actualStart = 0
    }
    if (actualEnd < actualStart) {
        actualEnd = actualStart
    }
    if (actualEnd > Int64(units.size)) {
        actualEnd = Int64(units.size)
    }
    let length = actualEnd - actualStart
    var result = Array<UInt16>(length, repeat: 0u16)
    var index: Int64 = 0
    while (index < length) {
        result[index] = units[actualStart + index]
        index += 1
    }
    result
}

private func wideUnitsToBytes(units: Array<UInt16>): Array<UInt8> {
    let unitCount = Int64(units.size)
    var result = Array<UInt8>(unitCount * 2, repeat: 0u8)
    var index: Int64 = 0
    while (index < unitCount) {
        let value = UInt32(units[index])
        result[index * 2] = UInt8(value & 0xFFu32)
        result[index * 2 + 1] = UInt8((value >> 8) & 0xFFu32)
        index += 1
    }
    result
}

private func bytesToWideUnits(bytes: Array<UInt8>): Array<UInt16> {
    let length = Int64(bytes.size) / 2
    var result = Array<UInt16>(length, repeat: 0u16)
    var index: Int64 = 0
    while (index < length) {
        let lo = UInt32(bytes[index * 2])
        let hi = UInt32(bytes[index * 2 + 1])
        result[index] = UInt16(lo | (hi << 8))
        index += 1
    }
    result
}

private func encodeWideBytesWithNull(text: String): Array<UInt8> {
    wideUnitsToBytes(encodeUtf16WithNull(text))
}

private func encodeWideBytesFromHStringWithNull(text: HString): Array<UInt8> {
    wideUnitsToBytes(appendWideNull(text.toWideArray()))
}

private func encodeMultiStringBytes(values: Array<String>): Array<UInt8> {
    let units = ArrayList<UInt16>()
    for (value in values) {
        let encoded = encodeUtf16WithNull(value)
        for (unit in encoded) {
            units.add(unit)
        }
    }
    units.add(0u16)

    var materialized = Array<UInt16>(units.size, repeat: 0u16)
    var index: Int64 = 0
    while (index < Int64(units.size)) {
        materialized[index] = units[index]
        index += 1
    }
    wideUnitsToBytes(materialized)
}

private func decodeRegistryString(bytes: Array<UInt8>): Result<String> {
    if ((Int64(bytes.size) % 2) != 0) {
        return Result<String>.Err(invalidDataError())
    }

    match (tryDecodeUtf16(trimTrailingWideNulls(bytesToWideUnits(bytes)))) {
        case Some(value) => Result<String>.Ok(value)
        case None => Result<String>.Err(invalidDataError())
    }
}

private func decodeRegistryMultiString(bytes: Array<UInt8>): Array<String> {
    let units = bytesToWideUnits(bytes)
    let result = ArrayList<String>()
    let total = Int64(units.size)
    var start: Int64 = 0
    var index: Int64 = 0
    while (index < total) {
        if (units[index] == 0u16) {
            if (index == start) {
                break
            }
            result.add(decodeUtf16(sliceWideUnits(units, start, index)))
            start = index + 1
        }
        index += 1
    }

    var materialized = Array<String>(result.size, repeat: "")
    var outIndex: Int64 = 0
    while (outIndex < Int64(result.size)) {
        materialized[outIndex] = result[outIndex]
        outIndex += 1
    }
    materialized
}

private func u32ToBytes(value: UInt32): Array<UInt8> {
    [
        UInt8(value & 0xFFu32),
        UInt8((value >> 8) & 0xFFu32),
        UInt8((value >> 16) & 0xFFu32),
        UInt8((value >> 24) & 0xFFu32)
    ]
}

private func u64ToBytes(value: UInt64): Array<UInt8> {
    [
        UInt8(value & 0xFFu64),
        UInt8((value >> 8) & 0xFFu64),
        UInt8((value >> 16) & 0xFFu64),
        UInt8((value >> 24) & 0xFFu64),
        UInt8((value >> 32) & 0xFFu64),
        UInt8((value >> 40) & 0xFFu64),
        UInt8((value >> 48) & 0xFFu64),
        UInt8((value >> 56) & 0xFFu64)
    ]
}

private func bytesToU32(bytes: Array<UInt8>): Result<UInt32> {
    if (bytes.size != 4) {
        return Result<UInt32>.Err(invalidDataError())
    }
    Result<UInt32>.Ok(
        UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8u32) |
            (UInt32(bytes[2]) << 16u32) |
            (UInt32(bytes[3]) << 24u32)
    )
}

private func bytesToU64(bytes: Array<UInt8>): Result<UInt64> {
    if (bytes.size != 8) {
        return Result<UInt64>.Err(invalidDataError())
    }
    Result<UInt64>.Ok(
        UInt64(bytes[0]) |
            (UInt64(bytes[1]) << 8u64) |
            (UInt64(bytes[2]) << 16u64) |
            (UInt64(bytes[3]) << 24u64) |
            (UInt64(bytes[4]) << 32u64) |
            (UInt64(bytes[5]) << 40u64) |
            (UInt64(bytes[6]) << 48u64) |
            (UInt64(bytes[7]) << 56u64)
    )
}

public enum Type {
    | U32
    | U64
    | String
    | ExpandString
    | MultiString
    | Bytes
    | Other(UInt32)

    public static func fromRaw(raw: UInt32): Type {
        if (raw == REG_DWORD) {
            return Type.U32
        }
        if (raw == REG_QWORD) {
            return Type.U64
        }
        if (raw == REG_SZ) {
            return Type.String
        }
        if (raw == REG_EXPAND_SZ) {
            return Type.ExpandString
        }
        if (raw == REG_MULTI_SZ) {
            return Type.MultiString
        }
        if (raw == REG_BINARY) {
            return Type.Bytes
        }
        Type.Other(raw)
    }

    public func toRaw(): UInt32 {
        match (this) {
            case Type.U32 => REG_DWORD
            case Type.U64 => REG_QWORD
            case Type.String => REG_SZ
            case Type.ExpandString => REG_EXPAND_SZ
            case Type.MultiString => REG_MULTI_SZ
            case Type.Bytes => REG_BINARY
            case Type.Other(raw) => raw
        }
    }

    public operator func ==(other: Type): Bool {
        match ((this, other)) {
            case (Type.U32, Type.U32) => true
            case (Type.U64, Type.U64) => true
            case (Type.String, Type.String) => true
            case (Type.ExpandString, Type.ExpandString) => true
            case (Type.MultiString, Type.MultiString) => true
            case (Type.Bytes, Type.Bytes) => true
            case (Type.Other(left), Type.Other(right)) => left == right
            case _ => false
        }
    }

    public operator func !=(other: Type): Bool {
        !(this == other)
    }
}

public class Value {
    private var data_: Array<UInt8>
    private var ty_: Type

    public init(data: Array<UInt8>, ty: Type) {
        this.data_ = cloneBytes(data)
        this.ty_ = ty
    }

    public static func fromU32(value: UInt32): Value {
        Value(u32ToBytes(value), Type.U32)
    }

    public static func fromU64(value: UInt64): Value {
        Value(u64ToBytes(value), Type.U64)
    }

    public static func fromString(value: String): Value {
        Value(encodeWideBytesWithNull(value), Type.String)
    }

    public static func fromExpandString(value: String): Value {
        Value(encodeWideBytesWithNull(value), Type.ExpandString)
    }

    public static func fromHString(value: HString): Value {
        Value(encodeWideBytesFromHStringWithNull(value), Type.String)
    }

    public static func fromMultiString(values: Array<String>): Value {
        Value(encodeMultiStringBytes(values), Type.MultiString)
    }

    public static func fromBytes(value: Array<UInt8>): Value {
        Value(value, Type.Bytes)
    }

    public func ty(): Type {
        ty_
    }

    public func setTy(ty: Type): Unit {
        ty_ = ty
    }

    public func bytes(): Array<UInt8> {
        cloneBytes(data_)
    }

    public func asWide(): Array<UInt16> {
        bytesToWideUnits(data_)
    }

    public func toU32(): Result<UInt32> {
        match (ty_) {
            case Type.U32 =>
                bytesToU32(data_)
            case Type.U64 =>
                match (bytesToU64(data_)) {
                    case Result<UInt64>.Ok(value) =>
                        if ((value >> 32u64) != 0u64) {
                            Result<UInt32>.Err(invalidDataError())
                        } else {
                            Result<UInt32>.Ok(UInt32(value & 0xFFFFFFFFu64))
                        }
                    case Result<UInt64>.Err(error) =>
                        Result<UInt32>.Err(error)
                }
            case _ =>
                Result<UInt32>.Err(invalidDataError())
        }
    }

    public func toU64(): Result<UInt64> {
        match (ty_) {
            case Type.U64 =>
                bytesToU64(data_)
            case Type.U32 =>
                match (bytesToU32(data_)) {
                    case Result<UInt32>.Ok(value) => Result<UInt64>.Ok(UInt64(value))
                    case Result<UInt32>.Err(error) => Result<UInt64>.Err(error)
                }
            case _ =>
                Result<UInt64>.Err(invalidDataError())
        }
    }

    public func toStringValue(): Result<String> {
        match (ty_) {
            case Type.String => decodeRegistryString(data_)
            case Type.ExpandString => decodeRegistryString(data_)
            case _ => Result<String>.Err(invalidDataError())
        }
    }

    public func toHString(): Result<HString> {
        match (toStringValue()) {
            case Result<String>.Ok(value) =>
                Result<HString>.Ok(HString(value))
            case Result<String>.Err(error) =>
                Result<HString>.Err(error)
        }
    }

    public func toMultiString(): Result<Array<String>> {
        match (ty_) {
            case Type.MultiString =>
                Result<Array<String>>.Ok(decodeRegistryMultiString(data_))
            case Type.String =>
                match (toStringValue()) {
                    case Result<String>.Ok(value) =>
                        Result<Array<String>>.Ok([value])
                    case Result<String>.Err(error) =>
                        Result<Array<String>>.Err(error)
                }
            case Type.ExpandString =>
                match (toStringValue()) {
                    case Result<String>.Ok(value) =>
                        Result<Array<String>>.Ok([value])
                    case Result<String>.Err(error) =>
                        Result<Array<String>>.Err(error)
                }
            case _ =>
                Result<Array<String>>.Err(invalidDataError())
        }
    }
}

public class Transaction <: Resource {
    private var handle: HANDLE = HANDLE()
    private var closed = false

    private init(handle: HANDLE) {
        this.handle = handle
    }

    public static func new(): Result<Transaction> {
        let created = Win32Kernel.CreateTransaction(
            CPointer<SECURITY_ATTRIBUTES>(),
            CPointer<Unit>(),
            0u32,
            0u32,
            0u32,
            0u32,
            PWSTR()
        )
        if (isInvalidHandle(created)) {
            return Result<Transaction>.Err(errorFromThread())
        }
        Result<Transaction>.Ok(Transaction(created))
    }

    public static func fromRaw(handle: HANDLE): Transaction {
        Transaction(handle)
    }

    public func asRaw(): HANDLE {
        if (closed) {
            return HANDLE()
        }
        handle
    }

    public func isClosed(): Bool {
        closed
    }

    public func commit(): Result<Unit> {
        if (closed) {
            throw IllegalStateException("transaction is closed")
        }
        let result = Win32Kernel.CommitTransaction(handle)
        if (!result) {
            return Result<Unit>.Err(errorFromThread())
        }
        close()
        Result<Unit>.Ok(())
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        let closing = handle
        closed = true
        handle = HANDLE()
        closeHandleNoThrow(closing)
    }

    ~init() {
        closeHandleNoThrow(handle)
        closed = true
        handle = HANDLE()
    }
}

public class OpenOptions {
    private let parent_: Key
    private var access_: UInt32 = 0u32
    private var create_ = false
    private var transaction_: Option<Transaction> = None
    private var options_: UInt32 = REG_OPTION_NON_VOLATILE

    init(parent: Key) {
        this.parent_ = parent
    }

    public func read(): OpenOptions {
        access_ |= KEY_READ
        this
    }

    public func write(): OpenOptions {
        access_ |= KEY_WRITE
        this
    }

    public func access(access: UInt32): OpenOptions {
        access_ |= access
        this
    }

    public func create(): OpenOptions {
        create_ = true
        this
    }

    public func transaction(transaction: Transaction): OpenOptions {
        transaction_ = Some(transaction)
        this
    }

    public func volatile(): OpenOptions {
        options_ |= REG_OPTION_VOLATILE
        this
    }

    public func open(path: String): Result<Key> {
        var handle = HKEY()
        var disposition = 0u32
        let pathWide = encodeUtf16WithNull(path)
        let status = unsafe {
            let pathHandle = acquireArrayRawData(pathWide)
            try {
                let pathPtr = PWSTR.fromRaw(pathHandle.pointer)
                match (transaction_) {
                    case Some(transaction) =>
                        if (create_) {
                            Win32Registry.RegCreateKeyTransactedW(
                                parent_.handleForCalls(),
                                pathPtr,
                                PWSTR(),
                                options_,
                                access_,
                                CPointer<SECURITY_ATTRIBUTES>(),
                                CPointer<HKEY>(inout handle),
                                CPointer<UInt32>(inout disposition),
                                transaction.asRaw()
                            )
                        } else {
                            Win32Registry.RegOpenKeyTransactedW(
                                parent_.handleForCalls(),
                                pathPtr,
                                0u32,
                                access_,
                                CPointer<HKEY>(inout handle),
                                transaction.asRaw()
                            )
                        }
                    case None =>
                        if (create_) {
                            Win32Registry.RegCreateKeyExW(
                                parent_.handleForCalls(),
                                pathPtr,
                                PWSTR(),
                                options_,
                                access_,
                                CPointer<SECURITY_ATTRIBUTES>(),
                                CPointer<HKEY>(inout handle),
                                CPointer<UInt32>(inout disposition)
                            )
                        } else {
                            Win32Registry.RegOpenKeyExW(
                                parent_.handleForCalls(),
                                pathPtr,
                                0u32,
                                access_,
                                CPointer<HKEY>(inout handle)
                            )
                        }
                }
            } finally {
                releaseArrayRawData(pathHandle)
            }
        }

        match (win32Result(status)) {
            case Result<Unit>.Ok(_) =>
                Result<Key>.Ok(Key.fromRaw(handle))
            case Result<Unit>.Err(error) =>
                Result<Key>.Err(error)
        }
    }
}

public class Key <: Resource {
    private var handle: HKEY = HKEY()
    private let ownsHandle: Bool
    private var closed = false

    private init(handle: HKEY, ownsHandle: Bool) {
        this.handle = handle
        this.ownsHandle = ownsHandle
    }

    static func borrowed(handle: HKEY): Key {
        Key(handle, false)
    }

    public static func fromRaw(handle: HKEY): Key {
        Key(handle, true)
    }

    func handleForCalls(): HKEY {
        if (ownsHandle && closed) {
            throw IllegalStateException("registry key is closed")
        }
        handle
    }

    public func asRaw(): HKEY {
        if (ownsHandle && closed) {
            return HKEY()
        }
        handle
    }

    public func isClosed(): Bool {
        ownsHandle && closed
    }

    public func create(path: String): Result<Key> {
        options().read().write().create().open(path)
    }

    public func open(path: String): Result<Key> {
        options().read().open(path)
    }

    public func options(): OpenOptions {
        OpenOptions(this)
    }

    public func rename(from: String, to: String): Result<Unit> {
        withWideString(from) { fromPtr =>
            withWideString(to) { toPtr =>
                win32Result(Win32Registry.RegRenameKey(handleForCalls(), fromPtr, toPtr))
            }
        }
    }

    public func removeTree(path: String): Result<Unit> {
        withWideString(path) { pathPtr =>
            win32Result(Win32Registry.RegDeleteTreeW(handleForCalls(), pathPtr))
        }
    }

    public func removeValue(name: String): Result<Unit> {
        withWideString(name) { namePtr =>
            win32Result(Win32Registry.RegDeleteValueW(handleForCalls(), namePtr))
        }
    }

    public func keys(): Result<KeyIterator> {
        var count = 0u32
        var maxLen = 0u32
        let status = Win32Registry.RegQueryInfoKeyW(
            handleForCalls(),
            PWSTR(),
            CPointer<UInt32>(),
            CPointer<UInt32>(inout count),
            CPointer<UInt32>(inout maxLen),
            CPointer<UInt32>(),
            CPointer<UInt32>(),
            CPointer<UInt32>(),
            CPointer<UInt32>(),
            CPointer<UInt32>(),
            CPointer<FILETIME>()
        )
        match (win32Result(status)) {
            case Result<Unit>.Ok(_) =>
                Result<KeyIterator>.Ok(KeyIterator(this, count, maxLen + 1u32))
            case Result<Unit>.Err(error) =>
                Result<KeyIterator>.Err(error)
        }
    }

    public func values(): Result<ValueIterator> {
        var count = 0u32
        var nameMaxLen = 0u32
        var valueMaxLen = 0u32
        let status = Win32Registry.RegQueryInfoKeyW(
            handleForCalls(),
            PWSTR(),
            CPointer<UInt32>(),
            CPointer<UInt32>(),
            CPointer<UInt32>(),
            CPointer<UInt32>(),
            CPointer<UInt32>(inout count),
            CPointer<UInt32>(inout nameMaxLen),
            CPointer<UInt32>(inout valueMaxLen),
            CPointer<UInt32>(),
            CPointer<FILETIME>()
        )
        match (win32Result(status)) {
            case Result<Unit>.Ok(_) =>
                Result<ValueIterator>.Ok(ValueIterator(this, count, nameMaxLen + 1u32, valueMaxLen))
            case Result<Unit>.Err(error) =>
                Result<ValueIterator>.Err(error)
        }
    }

    public func setU32(name: String, value: UInt32): Result<Unit> {
        setBytes(name, Type.U32, u32ToBytes(value))
    }

    public func setU64(name: String, value: UInt64): Result<Unit> {
        setBytes(name, Type.U64, u64ToBytes(value))
    }

    public func setString(name: String, value: String): Result<Unit> {
        setBytes(name, Type.String, encodeWideBytesWithNull(value))
    }

    public func setHString(name: String, value: HString): Result<Unit> {
        setBytes(name, Type.String, encodeWideBytesFromHStringWithNull(value))
    }

    public func setExpandString(name: String, value: String): Result<Unit> {
        setBytes(name, Type.ExpandString, encodeWideBytesWithNull(value))
    }

    public func setExpandHString(name: String, value: HString): Result<Unit> {
        setBytes(name, Type.ExpandString, encodeWideBytesFromHStringWithNull(value))
    }

    public func setMultiString(name: String, value: Array<String>): Result<Unit> {
        setBytes(name, Type.MultiString, encodeMultiStringBytes(value))
    }

    public func setValue(name: String, value: Value): Result<Unit> {
        setBytes(name, value.ty(), value.bytes())
    }

    public func setBytes(name: String, ty: Type, value: Array<UInt8>): Result<Unit> {
        withWideString(name) { namePtr =>
            rawSetBytes(namePtr, ty, value)
        }
    }

    public func getType(name: String): Result<Type> {
        withWideString(name) { namePtr =>
            match (rawGetInfo(namePtr)) {
                case Result<(Type, Int64)>.Ok((ty, _)) =>
                    Result<Type>.Ok(ty)
                case Result<(Type, Int64)>.Err(error) =>
                    Result<Type>.Err(error)
            }
        }
    }

    public func getValue(name: String): Result<Value> {
        withWideString(name) { namePtr =>
            match (rawGetInfo(namePtr)) {
                case Result<(Type, Int64)>.Ok((ty, length)) =>
                    var buffer = Array<UInt8>(length, repeat: 0u8)
                    match (rawGetBytes(namePtr, buffer)) {
                        case Result<(Type, Int64)>.Ok((actualType, actualLength)) =>
                            Result<Value>.Ok(Value(sliceBytes(buffer, actualLength), actualType))
                        case Result<(Type, Int64)>.Err(error) =>
                            Result<Value>.Err(error)
                    }
                case Result<(Type, Int64)>.Err(error) =>
                    Result<Value>.Err(error)
            }
        }
    }

    public func getU32(name: String): Result<UInt32> {
        match (getU64(name)) {
            case Result<UInt64>.Ok(value) =>
                if (value > UInt64(UInt32.Max)) {
                    Result<UInt32>.Err(invalidDataError())
                } else {
                    Result<UInt32>.Ok(UInt32(value))
                }
            case Result<UInt64>.Err(error) =>
                Result<UInt32>.Err(error)
        }
    }

    public func getU64(name: String): Result<UInt64> {
        getValue(name).andThen { value =>
            match (value.ty()) {
                case Type.U32 =>
                    match (bytesToU32(value.bytes())) {
                        case Result<UInt32>.Ok(raw) => Result<UInt64>.Ok(UInt64(raw))
                        case Result<UInt32>.Err(error) => Result<UInt64>.Err(error)
                    }
                case Type.U64 =>
                    bytesToU64(value.bytes())
                case _ =>
                    Result<UInt64>.Err(invalidDataError())
            }
        }
    }

    public func getString(name: String): Result<String> {
        getValue(name).andThen { value =>
            value.toStringValue()
        }
    }

    public func getHString(name: String): Result<HString> {
        withWideString(name) { namePtr =>
            getHStringRaw(namePtr)
        }
    }

    private func getHStringRaw(namePtr: PWSTR): Result<HString> {
        let infoResult = rawGetInfo(namePtr)
        var ty = Type.U32
        var byteLen: Int64 = 0
        match (infoResult) {
            case Result<(Type, Int64)>.Ok((t, l)) =>
                ty = t
                byteLen = l
            case Result<(Type, Int64)>.Err(error) =>
                return Result<HString>.Err(error)
        }
        match (ty) {
            case Type.String => ()
            case Type.ExpandString => ()
            case _ => return Result<HString>.Err(invalidDataError())
        }
        if ((byteLen % 2) != 0) {
            return Result<HString>.Err(invalidDataError())
        }
        let unitLen = byteLen / 2
        let builder = HStringBuilder(unitLen)
        if (unitLen == 0) {
            return Result<HString>.Ok(builder.intoHString())
        }
        let header = unsafe { CPointer<HStringHeader>(builder.asRaw()) }
        let bytePtr = unsafe { CPointer<UInt8>(hStringHeaderInlineBuffer(header)) }
        var ty2 = 0u32
        var lenIo = UInt32(byteLen)
        let status = Win32Registry.RegQueryValueExW(
            handleForCalls(),
            namePtr,
            CPointer<UInt32>(inout ty2),
            bytePtr,
            CPointer<UInt32>(inout lenIo)
        )
        match (win32Result(status)) {
            case Result<Unit>.Ok(_) =>
                builder.trimEnd()
                Result<HString>.Ok(builder.intoHString())
            case Result<Unit>.Err(error) =>
                builder.close()
                Result<HString>.Err(error)
        }
    }

    public func getMultiString(name: String): Result<Array<String>> {
        getValue(name).andThen { value =>
            value.toMultiString()
        }
    }

    public func rawSetBytes(name: PWSTR, ty: Type, value: Array<UInt8>): Result<Unit> {
        let status = withOptionalByteArrayPointer(value) { valuePtr: CPointer<UInt8> =>
            Win32Registry.RegSetValueExW(handleForCalls(), name, ty.toRaw(), valuePtr, UInt32(value.size))
        }
        win32Result(status)
    }

    public func rawGetInfo(name: PWSTR): Result<(Type, Int64)> {
        var ty = 0u32
        var length = 0u32
        let status = Win32Registry.RegQueryValueExW(
            handleForCalls(),
            name,
            CPointer<UInt32>(inout ty),
            CPointer<UInt8>(),
            CPointer<UInt32>(inout length)
        )
        match (win32Result(status)) {
            case Result<Unit>.Ok(_) =>
                Result<(Type, Int64)>.Ok((Type.fromRaw(ty), Int64(length)))
            case Result<Unit>.Err(error) =>
                Result<(Type, Int64)>.Err(error)
        }
    }

    public func rawGetBytes(name: PWSTR, value: Array<UInt8>): Result<(Type, Int64)> {
        var ty = 0u32
        var length = UInt32(value.size)
        let status = if (value.isEmpty()) {
            Win32Registry.RegQueryValueExW(
                handleForCalls(),
                name,
                CPointer<UInt32>(inout ty),
                CPointer<UInt8>(),
                CPointer<UInt32>(inout length)
            )
        } else {
            unsafe {
                let valueHandle = acquireArrayRawData(value)
                try {
                    Win32Registry.RegQueryValueExW(
                        handleForCalls(),
                        name,
                        CPointer<UInt32>(inout ty),
                        valueHandle.pointer,
                        CPointer<UInt32>(inout length)
                    )
                } finally {
                    releaseArrayRawData(valueHandle)
                }
            }
        }
        match (win32Result(status)) {
            case Result<Unit>.Ok(_) =>
                Result<(Type, Int64)>.Ok((Type.fromRaw(ty), Int64(length)))
            case Result<Unit>.Err(error) =>
                Result<(Type, Int64)>.Err(error)
        }
    }

    public func close(): Unit {
        if (!ownsHandle || closed) {
            return
        }
        let closing = handle
        closed = true
        handle = HKEY()
        closeRegistryKeyNoThrow(closing)
    }

    ~init() {
        if (ownsHandle) {
            closeRegistryKeyNoThrow(handle)
        }
        closed = true
        handle = HKEY()
    }
}

public class KeyIterator <: Iterator<String> {
    private let key_: Key
    private let count_: UInt32
    private let nameBuffer: Array<UInt16>
    private var index: UInt32 = 0u32

    init(key: Key, count: UInt32, maxNameLen: UInt32) {
        this.key_ = key
        this.count_ = count
        this.nameBuffer = Array<UInt16>(Int64(maxNameLen), repeat: 0u16)
    }

    public func next(): Option<String> {
        if (index >= count_) {
            return None
        }
        var nameLength = UInt32(nameBuffer.size)
        let status = unsafe {
            let nameHandle = acquireArrayRawData(nameBuffer)
            try {
                Win32Registry.RegEnumKeyExW(
                    key_.handleForCalls(),
                    index,
                    PWSTR.fromRaw(nameHandle.pointer),
                    CPointer<UInt32>(inout nameLength),
                    PWSTR(),
                    CPointer<UInt32>(),
                    CPointer<FILETIME>()
                )
            } finally {
                releaseArrayRawData(nameHandle)
            }
        }
        if (status == ERROR_NO_MORE_ITEMS) {
            index = count_
            return None
        }
        if (status == 0u32) {
            index += 1u32
            return Some(decodeUtf16(copyWideArray(nameBuffer, length: Int64(nameLength))))
        }
        throw Win32Exception(status)
    }
}

public class ValueIterator <: Iterator<(String, Value)> {
    private let key_: Key
    private let count_: UInt32
    private let nameBuffer: Array<UInt16>
    private let dataBuffer: Array<UInt8>
    private var index: UInt32 = 0u32

    init(key: Key, count: UInt32, maxNameLen: UInt32, maxValueLen: UInt32) {
        this.key_ = key
        this.count_ = count
        this.nameBuffer = Array<UInt16>(Int64(maxNameLen), repeat: 0u16)
        this.dataBuffer = Array<UInt8>(Int64(maxValueLen), repeat: 0u8)
    }

    public func next(): Option<(String, Value)> {
        if (index >= count_) {
            return None
        }
        var ty = 0u32
        var nameLength = UInt32(nameBuffer.size)
        var dataLength = UInt32(dataBuffer.size)
        let status = unsafe {
            let nameHandle = acquireArrayRawData(nameBuffer)
            try {
                if (dataBuffer.isEmpty()) {
                    Win32Registry.RegEnumValueW(
                        key_.handleForCalls(),
                        index,
                        PWSTR.fromRaw(nameHandle.pointer),
                        CPointer<UInt32>(inout nameLength),
                        CPointer<UInt32>(inout ty),
                        CPointer<UInt8>(),
                        CPointer<UInt32>(inout dataLength)
                    )
                } else {
                    let dataHandle = acquireArrayRawData(dataBuffer)
                    try {
                        Win32Registry.RegEnumValueW(
                            key_.handleForCalls(),
                            index,
                            PWSTR.fromRaw(nameHandle.pointer),
                            CPointer<UInt32>(inout nameLength),
                            CPointer<UInt32>(inout ty),
                            dataHandle.pointer,
                            CPointer<UInt32>(inout dataLength)
                        )
                    } finally {
                        releaseArrayRawData(dataHandle)
                    }
                }
            } finally {
                releaseArrayRawData(nameHandle)
            }
        }
        if (status == ERROR_NO_MORE_ITEMS) {
            index = count_
            return None
        }
        if (status == 0u32) {
            index += 1u32
            let name = decodeUtf16(copyWideArray(nameBuffer, length: Int64(nameLength)))
            let value = Value(sliceBytes(dataBuffer, Int64(dataLength)), Type.fromRaw(ty))
            return Some((name, value))
        }
        throw Win32Exception(status)
    }
}

public let CLASSES_ROOT = Key.borrowed(HKEY_CLASSES_ROOT_RAW)
public let CURRENT_CONFIG = Key.borrowed(HKEY_CURRENT_CONFIG_RAW)
public let CURRENT_USER = Key.borrowed(HKEY_CURRENT_USER_RAW)
public let LOCAL_MACHINE = Key.borrowed(HKEY_LOCAL_MACHINE_RAW)
public let USERS = Key.borrowed(HKEY_USERS_RAW)
