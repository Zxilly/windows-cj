package windows_future

// WinRT async subsystem: IAsyncInfo / IAsyncAction / IAsyncOperation (+WithProgress),
// the six async completion/progress handler families, and the AsyncStatus value type.
// Extracted from the foundation projection package into windows_future. The shared
// WinRT-ABI thunk helpers and the HResult value type are imported from windows_core.

import std.collection.*
import windows_core.{ComObject, E_FAIL, E_NOINTERFACE, E_NOTIMPL, E_POINTER, HRESULT, HResult, HResultAbi, InParam, Result, RuntimeType, S_OK, Type, WinrtGenericType, asImplFromRaw, assumeInitTypedAbi, buildIInspectableVtbl, buildIUnknownVtbl, checkFoundationComOutHRESULT, delegateAsInspectable, foundationDirectScalarOutThunk, foundationGenericOutThunk, foundationNoInterfaceComOut, foundationNoInterfaceUInt32Out, foundationNotImplComOut, foundationNotImplValueOut, foundationProjectedScalarOutThunk, foundationUnitThunk, fromTypedAbi, projectTypedAbi, typeMarker}
import windows_core as windows_core
import windows_interface.{ComInterface, DescriptorSchemaProvider, GUID, IInspectable, IInspectableVtbl, IUnknown, IUnknownVtbl, InterfaceDescriptor, InterfaceDescriptorSchema, InterfaceMethodSchema, InterfaceParameterBridgeKind, InterfaceParameterSchema, InterfaceWrapperBase, RuntimeName, RuntimeType, RuntimeTypeContract}
import windows_interface as windows_interface

public struct AsyncStatus {
    public var value: Int32 = 0

    public init() {}

    public init(value: Int32) {
        this.value = value
    }

    public operator func ==(other: AsyncStatus): Bool {
        return this.value == other.value
    }
    public operator func !=(other: AsyncStatus): Bool {
        return this.value != other.value
    }
}

@C
public struct AsyncStatusAbi {
    public var value: Int32 = 0

    public init() {}

    public init(value: Int32) {
        this.value = value
    }
}

public let AsyncStatus_Canceled: AsyncStatus = AsyncStatus(2)

public let AsyncStatus_Completed: AsyncStatus = AsyncStatus(1)

public let AsyncStatus_Error: AsyncStatus = AsyncStatus(3)

public let AsyncStatus_Started: AsyncStatus = AsyncStatus(0)

extend AsyncStatus <: windows_core.CopyType & windows_core.RuntimeType & windows_core.Type<AsyncStatus, AsyncStatusAbi, AsyncStatus> & windows_core.WinrtGenericType<AsyncStatus> {
    public static func typeKind(): windows_core.TypeKind { windows_core.TypeKind.Copy }
    public static func abiType(): String { "AsyncStatusAbi" }
    public static func signature(): String { "enum(Windows.Foundation.AsyncStatus;i4)" }
    public static func projectAbi(value: AsyncStatus): AsyncStatusAbi {
        AsyncStatusAbi(value.value)
    }
    public static func assumeInitRef(abi: AsyncStatusAbi): AsyncStatus {
        AsyncStatus(abi.value)
    }
    public static func fromAbi(abi: AsyncStatusAbi): Result<AsyncStatus> { Result<AsyncStatus>.Ok(AsyncStatus.assumeInitRef(abi)) }
    public static func fromDefault(defaultValue: AsyncStatus): Result<AsyncStatus> { Result<AsyncStatus>.Ok(defaultValue) }
    public static func winrtOutputBridge(): windows_core.WinrtOutputBridge<AsyncStatus> {
        windows_core.ProjectedCopyWinrtOutputBridge<AsyncStatus, AsyncStatusAbi, AsyncStatus>()
    }
}

@C
public struct IAsyncInfoVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var Id: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32> = { _, result__ => foundationNotImplValueOut<UInt32>(result__, 0u32) }
    public var Status: CFunc<(CPointer<Unit>, CPointer<AsyncStatusAbi>) -> Int32> = { _, result__ => foundationNotImplValueOut<AsyncStatusAbi>(result__, AsyncStatusAbi()) }
    public var ErrorCode: CFunc<(CPointer<Unit>, CPointer<HResultAbi>) -> Int32> = { _, result__ => foundationNotImplValueOut<HResultAbi>(result__, HResultAbi()) }
    public var Cancel: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public var Close: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IAsyncInfoVtbl where Identity <: IAsyncInfo_Impl {
        let _ = offset
        var vtbl = IAsyncInfoVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.Id = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncInfo_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Id(result__)
                case None =>
                    foundationNoInterfaceUInt32Out(result__)
            }
        }
        vtbl.Status = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncInfo_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Status(result__)
                case None =>
                    if (result__.isNotNull()) {
                        unsafe { result__.write(AsyncStatusAbi()) }
                    }
                    E_NOINTERFACE.value
            }
        }
        vtbl.ErrorCode = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncInfo_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_ErrorCode(result__)
                case None =>
                    if (result__.isNotNull()) {
                        unsafe { result__.write(HResultAbi()) }
                    }
                    E_NOINTERFACE.value
            }
        }
        vtbl.Cancel = { instanceRaw =>
            match (unsafe { asImplFromRaw<IAsyncInfo_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Cancel()
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Close = { instanceRaw =>
            match (unsafe { asImplFromRaw<IAsyncInfo_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Close()
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IAsyncInfo.iid()) {
            return true
        }
        return false
    }
}

public interface IAsyncInfo_ImplErased {
    public func __winrtThunk_Id(result__: CPointer<UInt32>): Int32

    public func __winrtThunk_Status(result__: CPointer<AsyncStatusAbi>): Int32

    public func __winrtThunk_ErrorCode(result__: CPointer<HResultAbi>): Int32

    public func __winrtThunk_Cancel(): Int32

    public func __winrtThunk_Close(): Int32
}

public interface IAsyncInfo_Impl <: IAsyncInfo_ImplErased {
    public func Id(): windows_core.Result<UInt32>

    public func __winrtThunk_Id(result__: CPointer<UInt32>): Int32 {
        foundationDirectScalarOutThunk<UInt32>(result__, 0u32, { => this.Id() })
    }

    public func Status(): windows_core.Result<AsyncStatus>

    public func __winrtThunk_Status(result__: CPointer<AsyncStatusAbi>): Int32 {
        foundationProjectedScalarOutThunk<AsyncStatus, AsyncStatusAbi, AsyncStatus>(result__, AsyncStatusAbi(), { => this.Status() })
    }

    public func ErrorCode(): windows_core.Result<HResult>

    public func __winrtThunk_ErrorCode(result__: CPointer<HResultAbi>): Int32 {
        foundationProjectedScalarOutThunk<HResult, HResultAbi, HResult>(result__, HResultAbi(), { => this.ErrorCode() })
    }

    public func Cancel(): windows_core.Result<Unit>

    public func __winrtThunk_Cancel(): Int32 {
        foundationUnitThunk({ => this.Cancel() })
    }

    public func Close(): windows_core.Result<Unit>

    public func __winrtThunk_Close(): Int32 {
        foundationUnitThunk({ => this.Close() })
    }
}

public class IAsyncInfo <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncInfo {
        IAsyncInfo(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncInfo {
        IAsyncInfo(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID(0x00000036, 0x0000, 0x0000, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IAsyncInfo.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IAsyncInfo> {
        var descriptor = InterfaceDescriptor<IAsyncInfo>("IAsyncInfo", IAsyncInfo.iid(), windows_interface.eraseInterfaceDescriptor(IInspectable.descriptor()), Array<GUID>(), { raw => IAsyncInfo.fromAbiTake(raw) }, { raw => IAsyncInfo.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncInfo.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncInfo", IAsyncInfo.iid(), IInspectable.descriptorSchema(), Array<String>(), Array<GUID>(), "IAsyncInfoVtbl", "IAsyncInfo", "IAsyncInfo_Impl", [InterfaceMethodSchema("Id", 6, [InterfaceParameterSchema("result", "CPointer<UInt32>", "OutSlot<UInt32>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Status", 7, [InterfaceParameterSchema("result", "CPointer<AsyncStatusAbi>", "OutSlot<AsyncStatus>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("ErrorCode", 8, [InterfaceParameterSchema("result", "CPointer<HResultAbi>", "OutSlot<HResult>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Cancel", 9, Array<InterfaceParameterSchema>(), "Int32"), InterfaceMethodSchema("Close", 10, Array<InterfaceParameterSchema>(), "Int32")])
        schema.runtimeTypeContract = Some(IAsyncInfo.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{00000036-0000-0000-c000-000000000046}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IAsyncInfo"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IAsyncInfo", IAsyncInfo.signature(), IAsyncInfo.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IAsyncInfoVtbl {
        readVtbl<IAsyncInfoVtbl>(IAsyncInfoVtbl())
    }

    public unsafe func Id(): UInt32 {
        let v = vtbl()
        var result__ = 0u32
        let hr = v.Id(asRaw(), CPointer<UInt32>(inout result__))
        HRESULT(hr).check()
        return result__
    }

    public unsafe func Status(): AsyncStatus {
        let v = vtbl()
        var result__ = AsyncStatusAbi()
        let hr = v.Status(asRaw(), CPointer<AsyncStatusAbi>(inout result__))
        HRESULT(hr).check()
        return windows_core.fromTypedAbi(result__, windows_core.typeMarker<AsyncStatus>()).unwrap()
    }

    public unsafe func ErrorCode(): HResult {
        let v = vtbl()
        var result__ = HResultAbi()
        let hr = v.ErrorCode(asRaw(), CPointer<HResultAbi>(inout result__))
        HRESULT(hr).check()
        return windows_core.fromTypedAbi(result__, windows_core.typeMarker<HResult>()).unwrap()
    }

    public unsafe func Cancel(): Unit {
        let v = vtbl()
        let hr = v.Cancel(asRaw())
        HRESULT(hr).check()
    }

    public unsafe func Close(): Unit {
        let v = vtbl()
        let hr = v.Close(asRaw())
        HRESULT(hr).check()
    }
}

extend IAsyncInfo <: windows_core.Interface<IAsyncInfo> {}

@C
public struct AsyncActionCompletedHandlerVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, AsyncStatusAbi) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

public class AsyncActionCompletedHandler <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncActionCompletedHandler {
        AsyncActionCompletedHandler(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncActionCompletedHandler {
        AsyncActionCompletedHandler(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID(0xA4ED5C81, 0x76C9, 0x40BD, 0x8B, 0xE6, 0xB1, 0xD9, 0x0F, 0xB2, 0x0A, 0xE7)
    }

    public static func descriptor(): InterfaceDescriptor<AsyncActionCompletedHandler> {
        return InterfaceDescriptor<AsyncActionCompletedHandler>("AsyncActionCompletedHandler", AsyncActionCompletedHandler.iid(), [IUnknown.iid()], { raw => AsyncActionCompletedHandler.fromAbiTake(raw) }, { raw => AsyncActionCompletedHandler.viewOf(raw) })
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("AsyncActionCompletedHandler", AsyncActionCompletedHandler.iid(), IUnknown.descriptorSchema(), "AsyncActionCompletedHandlerVtbl", "AsyncActionCompletedHandler", "AsyncActionCompletedHandlerInvoker", [InterfaceMethodSchema("Invoke", 3, [InterfaceParameterSchema("asyncInfo", "CPointer<Unit>", "InParam<IAsyncAction>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("asyncStatus", "AsyncStatusAbi", "InParam<AsyncStatus>", InterfaceParameterBridgeKind.InParam)], "Int32")])
        schema.runtimeTypeContract = Some(AsyncActionCompletedHandler.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "delegate({a4ed5c81-76c9-40bd-8be6-b1d90fb20ae7})"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncActionCompletedHandler", AsyncActionCompletedHandler.signature(), AsyncActionCompletedHandler.iid())
    }

    public func asIInspectable(): IInspectable {
        delegateAsInspectable(asRaw(), "AsyncActionCompletedHandler")
    }

    public unsafe func vtbl(): AsyncActionCompletedHandlerVtbl {
        readVtbl<AsyncActionCompletedHandlerVtbl>(AsyncActionCompletedHandlerVtbl())
    }

    public unsafe func Invoke(asyncInfo: IAsyncAction, asyncStatus: AsyncStatus): Unit {
        Invoke(InParam<IAsyncAction>(asyncInfo), asyncStatus)
    }

    public unsafe func Invoke(asyncInfo: InParam<IAsyncAction>, asyncStatus: AsyncStatus): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.borrow<CPointer<Unit>>(), windows_core.projectTypedAbi(asyncStatus, windows_core.typeMarker<AsyncStatus>()))
        HRESULT(hr).check()
    }

    public static func new(invoke: (InParam<IAsyncAction>, AsyncStatus) -> Unit): AsyncActionCompletedHandler {
        let box = AsyncActionCompletedHandlerBox(invoke)
        let object = ComObject<AsyncActionCompletedHandlerBox>.new(box, [AsyncActionCompletedHandler.descriptorSchema()], box.vtblPtr())
        return object.intoInterface(AsyncActionCompletedHandler.descriptor())
    }
}

extend AsyncActionCompletedHandler <: windows_core.Interface<AsyncActionCompletedHandler> {}

public interface AsyncActionCompletedHandlerInvokerErased {
    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: AsyncStatusAbi): Int32
}

public interface AsyncActionCompletedHandlerInvoker <: AsyncActionCompletedHandlerInvokerErased {
    public func Invoke(asyncInfo: InParam<IAsyncAction>, asyncStatus: AsyncStatus): Unit {
        ()
    }

    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: AsyncStatusAbi): Int32 {
        try {
            let asyncInfo = if (arg0.isNull()) {
                InParam<IAsyncAction>()
            } else {
                InParam<IAsyncAction>(IAsyncAction.viewOf(arg0))
            }
            this.Invoke(asyncInfo, windows_core.assumeInitTypedAbi(arg1, windows_core.typeMarker<AsyncStatus>()))
            return S_OK.value
        } catch (error: windows_core.WindowsException) {
            return error.code().value
        } catch (_: Exception) {
            return windows_core.E_FAIL.value
        }
    }
}

private class AsyncActionCompletedHandlerBox <: AsyncActionCompletedHandlerInvoker & Resource {
    public let invoke_: (InParam<IAsyncAction>, AsyncStatus) -> Unit
    private let vtblHandle: CPointer<AsyncActionCompletedHandlerVtbl>
    private var closed: Bool = false

    public init(invoke: (InParam<IAsyncAction>, AsyncStatus) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { windows_interface.allocateNativeValue<AsyncActionCompletedHandlerVtbl>(buildAsyncActionCompletedHandlerBoxVtbl()) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func Invoke(asyncInfo: InParam<IAsyncAction>, asyncStatus: AsyncStatus): Unit {
        invoke_(asyncInfo, asyncStatus)
    }
}

func buildAsyncActionCompletedHandlerBoxVtbl(): AsyncActionCompletedHandlerVtbl {
    var vtbl = AsyncActionCompletedHandlerVtbl()
    vtbl.base_ = buildIUnknownVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: AsyncStatusAbi =>
        match (unsafe { asImplFromRaw<AsyncActionCompletedHandlerInvokerErased>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.__winrtThunk_Invoke(arg0, arg1)
            case None =>
                E_NOTIMPL.value
        }
    }
    return vtbl
}

@C
public struct AsyncActionProgressHandlerVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

public class AsyncActionProgressHandler<TProgress> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncActionProgressHandler<TProgress> {
        AsyncActionProgressHandler<TProgress>(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncActionProgressHandler<TProgress> {
        AsyncActionProgressHandler<TProgress>(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID.from_signature(AsyncActionProgressHandler<TProgress>.signature())
    }

    public static func descriptor(): InterfaceDescriptor<AsyncActionProgressHandler<TProgress>> {
        return InterfaceDescriptor<AsyncActionProgressHandler<TProgress>>("AsyncActionProgressHandler", AsyncActionProgressHandler<TProgress>.iid(), [IUnknown.iid()], { raw => AsyncActionProgressHandler<TProgress>.fromAbiTake(raw) }, { raw => AsyncActionProgressHandler<TProgress>.viewOf(raw) })
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("AsyncActionProgressHandler", AsyncActionProgressHandler<TProgress>.iid(), IUnknown.descriptorSchema(), "AsyncActionProgressHandlerVtbl", "AsyncActionProgressHandler", "AsyncActionProgressHandlerInvoker", [InterfaceMethodSchema("Invoke", 3, [InterfaceParameterSchema("asyncInfo", "CPointer<Unit>", "InParam<IAsyncActionWithProgress<TProgress>>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("progressInfo", "CPointer<Unit>", "TProgress", InterfaceParameterBridgeKind.Value)], "Int32")])
        schema.runtimeTypeContract = Some(AsyncActionProgressHandler<TProgress>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({6d844858-0cff-4590-ae89-95a5a5c8b4b8}")
        sb.append(";")
        sb.append(TProgress.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncActionProgressHandler", AsyncActionProgressHandler<TProgress>.signature(), AsyncActionProgressHandler<TProgress>.iid())
    }

    public func asIInspectable(): IInspectable {
        delegateAsInspectable(asRaw(), "AsyncActionProgressHandler")
    }

    public unsafe func vtbl(): AsyncActionProgressHandlerVtbl {
        readVtbl<AsyncActionProgressHandlerVtbl>(AsyncActionProgressHandlerVtbl())
    }

    public unsafe func Invoke(asyncInfo: IAsyncActionWithProgress<TProgress>, progressInfo: TProgress): Unit {
        Invoke(InParam<IAsyncActionWithProgress<TProgress>>(asyncInfo), progressInfo)
    }

    public unsafe func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, progressInfo: TProgress): Unit {
        let v = vtbl()
        var hr__: ?Int32 = None
        try (__genericBorrow0 = windows_core.winrtBorrowGenericIn<TProgress>(progressInfo)) {
            hr__ = Some(v.Invoke(asRaw(), asyncInfo.borrow<CPointer<Unit>>(), __genericBorrow0.asRaw()))
        }
        let hr = match (hr__) {
            case Some(value) => value
            case None => throw IllegalStateException("generic WinRT input borrow did not execute")
        }
        HRESULT(hr).check()
    }

    public static func new(invoke: (InParam<IAsyncActionWithProgress<TProgress>>, TProgress) -> Unit): AsyncActionProgressHandler<TProgress> {
        let box = AsyncActionProgressHandlerBox<TProgress>(invoke)
        let object = ComObject<AsyncActionProgressHandlerBox<TProgress>>.new(box, [AsyncActionProgressHandler<TProgress>.descriptorSchema()], box.vtblPtr())
        return object.intoInterface(AsyncActionProgressHandler<TProgress>.descriptor())
    }
}

extend<TProgress> AsyncActionProgressHandler<TProgress> <: windows_core.Interface<AsyncActionProgressHandler<TProgress>> where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {}

public interface AsyncActionProgressHandlerInvokerErased {
    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: CPointer<Unit>): Int32
}

public interface AsyncActionProgressHandlerInvoker<TProgress> <: AsyncActionProgressHandlerInvokerErased where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, progressInfo: TProgress): Unit {
        ()
    }

    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: CPointer<Unit>): Int32 {
        try {
            let asyncInfo = if (arg0.isNull()) {
                InParam<IAsyncActionWithProgress<TProgress>>()
            } else {
                InParam<IAsyncActionWithProgress<TProgress>>(IAsyncActionWithProgress<TProgress>.viewOf(arg0))
            }
            this.Invoke(asyncInfo, windows_core.winrtProjectGenericIn<TProgress>(arg1))
            return S_OK.value
        } catch (error: windows_core.WindowsException) {
            return error.code().value
        } catch (_: Exception) {
            return windows_core.E_FAIL.value
        }
    }
}

private class AsyncActionProgressHandlerBox<TProgress> <: AsyncActionProgressHandlerInvoker<TProgress> & Resource where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public let invoke_: (InParam<IAsyncActionWithProgress<TProgress>>, TProgress) -> Unit
    private let vtblHandle: CPointer<AsyncActionProgressHandlerVtbl>
    private var closed: Bool = false

    public init(invoke: (InParam<IAsyncActionWithProgress<TProgress>>, TProgress) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { windows_interface.allocateNativeValue<AsyncActionProgressHandlerVtbl>(buildAsyncActionProgressHandlerBoxVtbl<TProgress>()) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, progressInfo: TProgress): Unit {
        invoke_(asyncInfo, progressInfo)
    }
}

func buildAsyncActionProgressHandlerBoxVtbl<TProgress>(): AsyncActionProgressHandlerVtbl where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    var vtbl = AsyncActionProgressHandlerVtbl()
    vtbl.base_ = buildIUnknownVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: CPointer<Unit> =>
        match (unsafe { asImplFromRaw<AsyncActionProgressHandlerInvokerErased>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.__winrtThunk_Invoke(arg0, arg1)
            case None =>
                E_NOTIMPL.value
        }
    }
    return vtbl
}

@C
public struct AsyncActionWithProgressCompletedHandlerVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, AsyncStatusAbi) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

public class AsyncActionWithProgressCompletedHandler<TProgress> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncActionWithProgressCompletedHandler<TProgress> {
        AsyncActionWithProgressCompletedHandler<TProgress>(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncActionWithProgressCompletedHandler<TProgress> {
        AsyncActionWithProgressCompletedHandler<TProgress>(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID.from_signature(AsyncActionWithProgressCompletedHandler<TProgress>.signature())
    }

    public static func descriptor(): InterfaceDescriptor<AsyncActionWithProgressCompletedHandler<TProgress>> {
        return InterfaceDescriptor<AsyncActionWithProgressCompletedHandler<TProgress>>("AsyncActionWithProgressCompletedHandler", AsyncActionWithProgressCompletedHandler<TProgress>.iid(), [IUnknown.iid()], { raw => AsyncActionWithProgressCompletedHandler<TProgress>.fromAbiTake(raw) }, { raw => AsyncActionWithProgressCompletedHandler<TProgress>.viewOf(raw) })
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("AsyncActionWithProgressCompletedHandler", AsyncActionWithProgressCompletedHandler<TProgress>.iid(), IUnknown.descriptorSchema(), "AsyncActionWithProgressCompletedHandlerVtbl", "AsyncActionWithProgressCompletedHandler", "AsyncActionWithProgressCompletedHandlerInvoker", [InterfaceMethodSchema("Invoke", 3, [InterfaceParameterSchema("asyncInfo", "CPointer<Unit>", "InParam<IAsyncActionWithProgress<TProgress>>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("asyncStatus", "AsyncStatusAbi", "InParam<AsyncStatus>", InterfaceParameterBridgeKind.InParam)], "Int32")])
        schema.runtimeTypeContract = Some(AsyncActionWithProgressCompletedHandler<TProgress>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({9c029f91-cc84-44fd-ac26-0a6c4e555281}")
        sb.append(";")
        sb.append(TProgress.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncActionWithProgressCompletedHandler", AsyncActionWithProgressCompletedHandler<TProgress>.signature(), AsyncActionWithProgressCompletedHandler<TProgress>.iid())
    }

    public func asIInspectable(): IInspectable {
        delegateAsInspectable(asRaw(), "AsyncActionWithProgressCompletedHandler")
    }

    public unsafe func vtbl(): AsyncActionWithProgressCompletedHandlerVtbl {
        readVtbl<AsyncActionWithProgressCompletedHandlerVtbl>(AsyncActionWithProgressCompletedHandlerVtbl())
    }

    public unsafe func Invoke(asyncInfo: IAsyncActionWithProgress<TProgress>, asyncStatus: AsyncStatus): Unit {
        Invoke(InParam<IAsyncActionWithProgress<TProgress>>(asyncInfo), asyncStatus)
    }

    public unsafe func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, asyncStatus: AsyncStatus): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.borrow<CPointer<Unit>>(), windows_core.projectTypedAbi(asyncStatus, windows_core.typeMarker<AsyncStatus>()))
        HRESULT(hr).check()
    }

    public static func new(invoke: (InParam<IAsyncActionWithProgress<TProgress>>, AsyncStatus) -> Unit): AsyncActionWithProgressCompletedHandler<TProgress> {
        let box = AsyncActionWithProgressCompletedHandlerBox<TProgress>(invoke)
        let object = ComObject<AsyncActionWithProgressCompletedHandlerBox<TProgress>>.new(box, [AsyncActionWithProgressCompletedHandler<TProgress>.descriptorSchema()], box.vtblPtr())
        return object.intoInterface(AsyncActionWithProgressCompletedHandler<TProgress>.descriptor())
    }
}

extend<TProgress> AsyncActionWithProgressCompletedHandler<TProgress> <: windows_core.Interface<AsyncActionWithProgressCompletedHandler<TProgress>> where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {}

public interface AsyncActionWithProgressCompletedHandlerInvokerErased {
    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: AsyncStatusAbi): Int32
}

public interface AsyncActionWithProgressCompletedHandlerInvoker<TProgress> <: AsyncActionWithProgressCompletedHandlerInvokerErased where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, asyncStatus: AsyncStatus): Unit {
        ()
    }

    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: AsyncStatusAbi): Int32 {
        try {
            let asyncInfo = if (arg0.isNull()) {
                InParam<IAsyncActionWithProgress<TProgress>>()
            } else {
                InParam<IAsyncActionWithProgress<TProgress>>(IAsyncActionWithProgress<TProgress>.viewOf(arg0))
            }
            this.Invoke(asyncInfo, windows_core.assumeInitTypedAbi(arg1, windows_core.typeMarker<AsyncStatus>()))
            return S_OK.value
        } catch (error: windows_core.WindowsException) {
            return error.code().value
        } catch (_: Exception) {
            return windows_core.E_FAIL.value
        }
    }
}

private class AsyncActionWithProgressCompletedHandlerBox<TProgress> <: AsyncActionWithProgressCompletedHandlerInvoker<TProgress> & Resource where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public let invoke_: (InParam<IAsyncActionWithProgress<TProgress>>, AsyncStatus) -> Unit
    private let vtblHandle: CPointer<AsyncActionWithProgressCompletedHandlerVtbl>
    private var closed: Bool = false

    public init(invoke: (InParam<IAsyncActionWithProgress<TProgress>>, AsyncStatus) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { windows_interface.allocateNativeValue<AsyncActionWithProgressCompletedHandlerVtbl>(buildAsyncActionWithProgressCompletedHandlerBoxVtbl<TProgress>()) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, asyncStatus: AsyncStatus): Unit {
        invoke_(asyncInfo, asyncStatus)
    }
}

func buildAsyncActionWithProgressCompletedHandlerBoxVtbl<TProgress>(): AsyncActionWithProgressCompletedHandlerVtbl where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    var vtbl = AsyncActionWithProgressCompletedHandlerVtbl()
    vtbl.base_ = buildIUnknownVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: AsyncStatusAbi =>
        match (unsafe { asImplFromRaw<AsyncActionWithProgressCompletedHandlerInvokerErased>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.__winrtThunk_Invoke(arg0, arg1)
            case None =>
                E_NOTIMPL.value
        }
    }
    return vtbl
}

@C
public struct AsyncOperationCompletedHandlerVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, AsyncStatusAbi) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

public class AsyncOperationCompletedHandler<TResult> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncOperationCompletedHandler<TResult> {
        AsyncOperationCompletedHandler<TResult>(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncOperationCompletedHandler<TResult> {
        AsyncOperationCompletedHandler<TResult>(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID.from_signature(AsyncOperationCompletedHandler<TResult>.signature())
    }

    public static func descriptor(): InterfaceDescriptor<AsyncOperationCompletedHandler<TResult>> {
        return InterfaceDescriptor<AsyncOperationCompletedHandler<TResult>>("AsyncOperationCompletedHandler", AsyncOperationCompletedHandler<TResult>.iid(), [IUnknown.iid()], { raw => AsyncOperationCompletedHandler<TResult>.fromAbiTake(raw) }, { raw => AsyncOperationCompletedHandler<TResult>.viewOf(raw) })
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("AsyncOperationCompletedHandler", AsyncOperationCompletedHandler<TResult>.iid(), IUnknown.descriptorSchema(), "AsyncOperationCompletedHandlerVtbl", "AsyncOperationCompletedHandler", "AsyncOperationCompletedHandlerInvoker", [InterfaceMethodSchema("Invoke", 3, [InterfaceParameterSchema("asyncInfo", "CPointer<Unit>", "InParam<IAsyncOperation<TResult>>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("asyncStatus", "AsyncStatusAbi", "InParam<AsyncStatus>", InterfaceParameterBridgeKind.InParam)], "Int32")])
        schema.runtimeTypeContract = Some(AsyncOperationCompletedHandler<TResult>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({fcdcf02c-e5d8-4478-915a-4d90b74b83a5}")
        sb.append(";")
        sb.append(TResult.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncOperationCompletedHandler", AsyncOperationCompletedHandler<TResult>.signature(), AsyncOperationCompletedHandler<TResult>.iid())
    }

    public func asIInspectable(): IInspectable {
        delegateAsInspectable(asRaw(), "AsyncOperationCompletedHandler")
    }

    public unsafe func vtbl(): AsyncOperationCompletedHandlerVtbl {
        readVtbl<AsyncOperationCompletedHandlerVtbl>(AsyncOperationCompletedHandlerVtbl())
    }

    public unsafe func Invoke(asyncInfo: IAsyncOperation<TResult>, asyncStatus: AsyncStatus): Unit {
        Invoke(InParam<IAsyncOperation<TResult>>(asyncInfo), asyncStatus)
    }

    public unsafe func Invoke(asyncInfo: InParam<IAsyncOperation<TResult>>, asyncStatus: AsyncStatus): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.borrow<CPointer<Unit>>(), windows_core.projectTypedAbi(asyncStatus, windows_core.typeMarker<AsyncStatus>()))
        HRESULT(hr).check()
    }

    public static func new(invoke: (InParam<IAsyncOperation<TResult>>, AsyncStatus) -> Unit): AsyncOperationCompletedHandler<TResult> {
        let box = AsyncOperationCompletedHandlerBox<TResult>(invoke)
        let object = ComObject<AsyncOperationCompletedHandlerBox<TResult>>.new(box, [AsyncOperationCompletedHandler<TResult>.descriptorSchema()], box.vtblPtr())
        return object.intoInterface(AsyncOperationCompletedHandler<TResult>.descriptor())
    }
}

extend<TResult> AsyncOperationCompletedHandler<TResult> <: windows_core.Interface<AsyncOperationCompletedHandler<TResult>> where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {}

public interface AsyncOperationCompletedHandlerInvokerErased {
    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: AsyncStatusAbi): Int32
}

public interface AsyncOperationCompletedHandlerInvoker<TResult> <: AsyncOperationCompletedHandlerInvokerErased where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
    public func Invoke(asyncInfo: InParam<IAsyncOperation<TResult>>, asyncStatus: AsyncStatus): Unit {
        ()
    }

    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: AsyncStatusAbi): Int32 {
        try {
            let asyncInfo = if (arg0.isNull()) {
                InParam<IAsyncOperation<TResult>>()
            } else {
                InParam<IAsyncOperation<TResult>>(IAsyncOperation<TResult>.viewOf(arg0))
            }
            this.Invoke(asyncInfo, windows_core.assumeInitTypedAbi(arg1, windows_core.typeMarker<AsyncStatus>()))
            return S_OK.value
        } catch (error: windows_core.WindowsException) {
            return error.code().value
        } catch (_: Exception) {
            return windows_core.E_FAIL.value
        }
    }
}

private class AsyncOperationCompletedHandlerBox<TResult> <: AsyncOperationCompletedHandlerInvoker<TResult> & Resource where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
    public let invoke_: (InParam<IAsyncOperation<TResult>>, AsyncStatus) -> Unit
    private let vtblHandle: CPointer<AsyncOperationCompletedHandlerVtbl>
    private var closed: Bool = false

    public init(invoke: (InParam<IAsyncOperation<TResult>>, AsyncStatus) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { windows_interface.allocateNativeValue<AsyncOperationCompletedHandlerVtbl>(buildAsyncOperationCompletedHandlerBoxVtbl<TResult>()) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func Invoke(asyncInfo: InParam<IAsyncOperation<TResult>>, asyncStatus: AsyncStatus): Unit {
        invoke_(asyncInfo, asyncStatus)
    }
}

func buildAsyncOperationCompletedHandlerBoxVtbl<TResult>(): AsyncOperationCompletedHandlerVtbl where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
    var vtbl = AsyncOperationCompletedHandlerVtbl()
    vtbl.base_ = buildIUnknownVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: AsyncStatusAbi =>
        match (unsafe { asImplFromRaw<AsyncOperationCompletedHandlerInvokerErased>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.__winrtThunk_Invoke(arg0, arg1)
            case None =>
                E_NOTIMPL.value
        }
    }
    return vtbl
}

@C
public struct AsyncOperationProgressHandlerVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

public class AsyncOperationProgressHandler<TResult, TProgress> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncOperationProgressHandler<TResult, TProgress> {
        AsyncOperationProgressHandler<TResult, TProgress>(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncOperationProgressHandler<TResult, TProgress> {
        AsyncOperationProgressHandler<TResult, TProgress>(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID.from_signature(AsyncOperationProgressHandler<TResult, TProgress>.signature())
    }

    public static func descriptor(): InterfaceDescriptor<AsyncOperationProgressHandler<TResult, TProgress>> {
        return InterfaceDescriptor<AsyncOperationProgressHandler<TResult, TProgress>>("AsyncOperationProgressHandler", AsyncOperationProgressHandler<TResult, TProgress>.iid(), [IUnknown.iid()], { raw => AsyncOperationProgressHandler<TResult, TProgress>.fromAbiTake(raw) }, { raw => AsyncOperationProgressHandler<TResult, TProgress>.viewOf(raw) })
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("AsyncOperationProgressHandler", AsyncOperationProgressHandler<TResult, TProgress>.iid(), IUnknown.descriptorSchema(), "AsyncOperationProgressHandlerVtbl", "AsyncOperationProgressHandler", "AsyncOperationProgressHandlerInvoker", [InterfaceMethodSchema("Invoke", 3, [InterfaceParameterSchema("asyncInfo", "CPointer<Unit>", "InParam<IAsyncOperationWithProgress<TResult, TProgress>>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("progressInfo", "CPointer<Unit>", "TProgress", InterfaceParameterBridgeKind.Value)], "Int32")])
        schema.runtimeTypeContract = Some(AsyncOperationProgressHandler<TResult, TProgress>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({55690902-0aab-421a-8778-f8ce5026d758}")
        sb.append(";")
        sb.append(TResult.signature())
        sb.append(";")
        sb.append(TProgress.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncOperationProgressHandler", AsyncOperationProgressHandler<TResult, TProgress>.signature(), AsyncOperationProgressHandler<TResult, TProgress>.iid())
    }

    public func asIInspectable(): IInspectable {
        delegateAsInspectable(asRaw(), "AsyncOperationProgressHandler")
    }

    public unsafe func vtbl(): AsyncOperationProgressHandlerVtbl {
        readVtbl<AsyncOperationProgressHandlerVtbl>(AsyncOperationProgressHandlerVtbl())
    }

    public unsafe func Invoke(asyncInfo: IAsyncOperationWithProgress<TResult, TProgress>, progressInfo: TProgress): Unit {
        Invoke(InParam<IAsyncOperationWithProgress<TResult, TProgress>>(asyncInfo), progressInfo)
    }

    public unsafe func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, progressInfo: TProgress): Unit {
        let v = vtbl()
        var hr__: ?Int32 = None
        try (__genericBorrow0 = windows_core.winrtBorrowGenericIn<TProgress>(progressInfo)) {
            hr__ = Some(v.Invoke(asRaw(), asyncInfo.borrow<CPointer<Unit>>(), __genericBorrow0.asRaw()))
        }
        let hr = match (hr__) {
            case Some(value) => value
            case None => throw IllegalStateException("generic WinRT input borrow did not execute")
        }
        HRESULT(hr).check()
    }

    public static func new(invoke: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, TProgress) -> Unit): AsyncOperationProgressHandler<TResult, TProgress> {
        let box = AsyncOperationProgressHandlerBox<TResult, TProgress>(invoke)
        let object = ComObject<AsyncOperationProgressHandlerBox<TResult, TProgress>>.new(box, [AsyncOperationProgressHandler<TResult, TProgress>.descriptorSchema()], box.vtblPtr())
        return object.intoInterface(AsyncOperationProgressHandler<TResult, TProgress>.descriptor())
    }
}

extend<TResult, TProgress> AsyncOperationProgressHandler<TResult, TProgress> <: windows_core.Interface<AsyncOperationProgressHandler<TResult, TProgress>> where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {}

public interface AsyncOperationProgressHandlerInvokerErased {
    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: CPointer<Unit>): Int32
}

public interface AsyncOperationProgressHandlerInvoker<TResult, TProgress> <: AsyncOperationProgressHandlerInvokerErased where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, progressInfo: TProgress): Unit {
        ()
    }

    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: CPointer<Unit>): Int32 {
        try {
            let asyncInfo = if (arg0.isNull()) {
                InParam<IAsyncOperationWithProgress<TResult, TProgress>>()
            } else {
                InParam<IAsyncOperationWithProgress<TResult, TProgress>>(IAsyncOperationWithProgress<TResult, TProgress>.viewOf(arg0))
            }
            this.Invoke(asyncInfo, windows_core.winrtProjectGenericIn<TProgress>(arg1))
            return S_OK.value
        } catch (error: windows_core.WindowsException) {
            return error.code().value
        } catch (_: Exception) {
            return windows_core.E_FAIL.value
        }
    }
}

private class AsyncOperationProgressHandlerBox<TResult, TProgress> <: AsyncOperationProgressHandlerInvoker<TResult, TProgress> & Resource where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public let invoke_: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, TProgress) -> Unit
    private let vtblHandle: CPointer<AsyncOperationProgressHandlerVtbl>
    private var closed: Bool = false

    public init(invoke: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, TProgress) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { windows_interface.allocateNativeValue<AsyncOperationProgressHandlerVtbl>(buildAsyncOperationProgressHandlerBoxVtbl<TResult, TProgress>()) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, progressInfo: TProgress): Unit {
        invoke_(asyncInfo, progressInfo)
    }
}

func buildAsyncOperationProgressHandlerBoxVtbl<TResult, TProgress>(): AsyncOperationProgressHandlerVtbl where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    var vtbl = AsyncOperationProgressHandlerVtbl()
    vtbl.base_ = buildIUnknownVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: CPointer<Unit> =>
        match (unsafe { asImplFromRaw<AsyncOperationProgressHandlerInvokerErased>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.__winrtThunk_Invoke(arg0, arg1)
            case None =>
                E_NOTIMPL.value
        }
    }
    return vtbl
}

@C
public struct AsyncOperationWithProgressCompletedHandlerVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, AsyncStatusAbi) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

public class AsyncOperationWithProgressCompletedHandler<TResult, TProgress> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncOperationWithProgressCompletedHandler<TResult, TProgress> {
        AsyncOperationWithProgressCompletedHandler<TResult, TProgress>(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncOperationWithProgressCompletedHandler<TResult, TProgress> {
        AsyncOperationWithProgressCompletedHandler<TResult, TProgress>(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID.from_signature(AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.signature())
    }

    public static func descriptor(): InterfaceDescriptor<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>> {
        return InterfaceDescriptor<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>("AsyncOperationWithProgressCompletedHandler", AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.iid(), [IUnknown.iid()], { raw => AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.fromAbiTake(raw) }, { raw => AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.viewOf(raw) })
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("AsyncOperationWithProgressCompletedHandler", AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.iid(), IUnknown.descriptorSchema(), "AsyncOperationWithProgressCompletedHandlerVtbl", "AsyncOperationWithProgressCompletedHandler", "AsyncOperationWithProgressCompletedHandlerInvoker", [InterfaceMethodSchema("Invoke", 3, [InterfaceParameterSchema("asyncInfo", "CPointer<Unit>", "InParam<IAsyncOperationWithProgress<TResult, TProgress>>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("asyncStatus", "AsyncStatusAbi", "InParam<AsyncStatus>", InterfaceParameterBridgeKind.InParam)], "Int32")])
        schema.runtimeTypeContract = Some(AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({e85df41d-6aa7-46e3-a8e2-f009d840c627}")
        sb.append(";")
        sb.append(TResult.signature())
        sb.append(";")
        sb.append(TProgress.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncOperationWithProgressCompletedHandler", AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.signature(), AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.iid())
    }

    public func asIInspectable(): IInspectable {
        delegateAsInspectable(asRaw(), "AsyncOperationWithProgressCompletedHandler")
    }

    public unsafe func vtbl(): AsyncOperationWithProgressCompletedHandlerVtbl {
        readVtbl<AsyncOperationWithProgressCompletedHandlerVtbl>(AsyncOperationWithProgressCompletedHandlerVtbl())
    }

    public unsafe func Invoke(asyncInfo: IAsyncOperationWithProgress<TResult, TProgress>, asyncStatus: AsyncStatus): Unit {
        Invoke(InParam<IAsyncOperationWithProgress<TResult, TProgress>>(asyncInfo), asyncStatus)
    }

    public unsafe func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, asyncStatus: AsyncStatus): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.borrow<CPointer<Unit>>(), windows_core.projectTypedAbi(asyncStatus, windows_core.typeMarker<AsyncStatus>()))
        HRESULT(hr).check()
    }

    public static func new(invoke: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, AsyncStatus) -> Unit): AsyncOperationWithProgressCompletedHandler<TResult, TProgress> {
        let box = AsyncOperationWithProgressCompletedHandlerBox<TResult, TProgress>(invoke)
        let object = ComObject<AsyncOperationWithProgressCompletedHandlerBox<TResult, TProgress>>.new(box, [AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.descriptorSchema()], box.vtblPtr())
        return object.intoInterface(AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.descriptor())
    }
}

extend<TResult, TProgress> AsyncOperationWithProgressCompletedHandler<TResult, TProgress> <: windows_core.Interface<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>> where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {}

public interface AsyncOperationWithProgressCompletedHandlerInvokerErased {
    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: AsyncStatusAbi): Int32
}

public interface AsyncOperationWithProgressCompletedHandlerInvoker<TResult, TProgress> <: AsyncOperationWithProgressCompletedHandlerInvokerErased where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, asyncStatus: AsyncStatus): Unit {
        ()
    }

    public func __winrtThunk_Invoke(arg0: CPointer<Unit>, arg1: AsyncStatusAbi): Int32 {
        try {
            let asyncInfo = if (arg0.isNull()) {
                InParam<IAsyncOperationWithProgress<TResult, TProgress>>()
            } else {
                InParam<IAsyncOperationWithProgress<TResult, TProgress>>(IAsyncOperationWithProgress<TResult, TProgress>.viewOf(arg0))
            }
            this.Invoke(asyncInfo, windows_core.assumeInitTypedAbi(arg1, windows_core.typeMarker<AsyncStatus>()))
            return S_OK.value
        } catch (error: windows_core.WindowsException) {
            return error.code().value
        } catch (_: Exception) {
            return windows_core.E_FAIL.value
        }
    }
}

private class AsyncOperationWithProgressCompletedHandlerBox<TResult, TProgress> <: AsyncOperationWithProgressCompletedHandlerInvoker<TResult, TProgress> & Resource where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public let invoke_: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, AsyncStatus) -> Unit
    private let vtblHandle: CPointer<AsyncOperationWithProgressCompletedHandlerVtbl>
    private var closed: Bool = false

    public init(invoke: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, AsyncStatus) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { windows_interface.allocateNativeValue<AsyncOperationWithProgressCompletedHandlerVtbl>(buildAsyncOperationWithProgressCompletedHandlerBoxVtbl<TResult, TProgress>()) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle)
    }

    public func isClosed(): Bool {
        closed
    }

    ~init() {
        if (!closed) {
            closed = true
        }
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        unsafe { windows_interface.freeNativeValue(vtblHandle) }
        closed = true
    }

    public func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, asyncStatus: AsyncStatus): Unit {
        invoke_(asyncInfo, asyncStatus)
    }
}

func buildAsyncOperationWithProgressCompletedHandlerBoxVtbl<TResult, TProgress>(): AsyncOperationWithProgressCompletedHandlerVtbl where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    var vtbl = AsyncOperationWithProgressCompletedHandlerVtbl()
    vtbl.base_ = buildIUnknownVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: AsyncStatusAbi =>
        match (unsafe { asImplFromRaw<AsyncOperationWithProgressCompletedHandlerInvokerErased>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.__winrtThunk_Invoke(arg0, arg1)
            case None =>
                E_NOTIMPL.value
        }
    }
    return vtbl
}

@C
public struct IAsyncActionVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var SetCompleted: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Completed: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ => foundationNotImplComOut(result__) }
    public var GetResults: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IAsyncActionVtbl where Identity <: IAsyncAction_Impl {
        let _ = offset
        var vtbl = IAsyncActionVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.SetCompleted = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<IAsyncAction_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_SetCompleted(arg0)
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Completed = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncAction_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Completed(result__)
                case None =>
                    foundationNoInterfaceComOut(result__)
            }
        }
        vtbl.GetResults = { instanceRaw =>
            match (unsafe { asImplFromRaw<IAsyncAction_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_GetResults()
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IAsyncAction.iid()) {
            return true
        }
        for (ancestor in [IAsyncInfo.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }
}

public interface IAsyncAction_ImplErased {
    public func __winrtThunk_SetCompleted(arg0: CPointer<Unit>): Int32

    public func __winrtThunk_Completed(result__: CPointer<CPointer<Unit>>): Int32

    public func __winrtThunk_GetResults(): Int32
}

public interface IAsyncAction_Impl <: IAsyncAction_ImplErased & IAsyncInfo_Impl {
    public func SetCompleted(handler: InParam<AsyncActionCompletedHandler>): windows_core.Result<Unit>

    public func __winrtThunk_SetCompleted(arg0: CPointer<Unit>): Int32 {
        let handler = if (arg0.isNull()) {
            InParam<AsyncActionCompletedHandler>()
        } else {
            InParam<AsyncActionCompletedHandler>(AsyncActionCompletedHandler.viewOf(arg0))
        }
        foundationUnitThunk({ => this.SetCompleted(handler) })
    }

    public func Completed(): windows_core.Result<AsyncActionCompletedHandler>

    public func __winrtThunk_Completed(result__: CPointer<CPointer<Unit>>): Int32 {
        foundationGenericOutThunk<AsyncActionCompletedHandler>(result__, { => this.Completed() })
    }

    public func GetResults(): windows_core.Result<Unit>

    public func __winrtThunk_GetResults(): Int32 {
        foundationUnitThunk({ => this.GetResults() })
    }

    public func __winrtThunk_Id(result__: CPointer<UInt32>): Int32 {
        foundationDirectScalarOutThunk<UInt32>(result__, 0u32, { => this.Id() })
    }

    public func __winrtThunk_Status(result__: CPointer<AsyncStatusAbi>): Int32 {
        foundationProjectedScalarOutThunk<AsyncStatus, AsyncStatusAbi, AsyncStatus>(result__, AsyncStatusAbi(), { => this.Status() })
    }

    public func __winrtThunk_ErrorCode(result__: CPointer<HResultAbi>): Int32 {
        foundationProjectedScalarOutThunk<HResult, HResultAbi, HResult>(result__, HResultAbi(), { => this.ErrorCode() })
    }

    public func __winrtThunk_Cancel(): Int32 {
        foundationUnitThunk({ => this.Cancel() })
    }

    public func __winrtThunk_Close(): Int32 {
        foundationUnitThunk({ => this.Close() })
    }
}

public class IAsyncAction <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncAction {
        IAsyncAction(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncAction {
        IAsyncAction(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID(0x5A648006, 0x843A, 0x4DA9, 0x86, 0x5B, 0x9D, 0x26, 0xE5, 0xDF, 0xAD, 0x7B)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IAsyncAction.iid()) {
            return true
        }
        for (ancestor in [IAsyncInfo.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IAsyncAction> {
        var descriptor = InterfaceDescriptor<IAsyncAction>("IAsyncAction", IAsyncAction.iid(), windows_interface.eraseInterfaceDescriptor(IInspectable.descriptor()), [IAsyncInfo.iid()], { raw => IAsyncAction.fromAbiTake(raw) }, { raw => IAsyncAction.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncAction.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncAction", IAsyncAction.iid(), IInspectable.descriptorSchema(), ["IAsyncInfo"], [IAsyncInfo.iid()], "IAsyncActionVtbl", "IAsyncAction", "IAsyncAction_Impl", [InterfaceMethodSchema("SetCompleted", 6, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncActionCompletedHandler>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Completed", 7, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncActionCompletedHandler>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetResults", 8, Array<InterfaceParameterSchema>(), "Int32")])
        schema.runtimeTypeContract = Some(IAsyncAction.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{5a648006-843a-4da9-865b-9d26e5dfad7b}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IAsyncAction"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IAsyncAction", IAsyncAction.signature(), IAsyncAction.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIAsyncInfo(): IAsyncInfo {
        match (unsafe { query<IAsyncInfo>(IAsyncInfo.descriptor()) }) {
            case Some(value) => value
            case None => throw Exception("asIAsyncInfo: QueryInterface failed (E_NOINTERFACE)")
        }
    }

    public unsafe func vtbl(): IAsyncActionVtbl {
        readVtbl<IAsyncActionVtbl>(IAsyncActionVtbl())
    }

    public unsafe func SetCompleted(handler: AsyncActionCompletedHandler): Unit {
        let v = vtbl()
        let hr = v.SetCompleted(asRaw(), handler.asRaw())
        HRESULT(hr).check()
    }

    public unsafe func Completed(): AsyncActionCompletedHandler {
        let v = vtbl()
        var result__ = CPointer<Unit>()
        let hr = v.Completed(asRaw(), CPointer<CPointer<Unit>>(inout result__))
        checkFoundationComOutHRESULT(HRESULT(hr), CPointer<CPointer<Unit>>(inout result__))
        return AsyncActionCompletedHandler.fromAbiTake(result__)
    }

    public unsafe func GetResults(): Unit {
        let v = vtbl()
        let hr = v.GetResults(asRaw())
        HRESULT(hr).check()
    }
}

extend IAsyncAction <: windows_core.Interface<IAsyncAction> {}

@C
public struct IAsyncActionWithProgressVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var SetProgress: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Progress: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ => foundationNotImplComOut(result__) }
    public var SetCompleted: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Completed: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ => foundationNotImplComOut(result__) }
    public var GetResults: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity, TProgress>(offset!: Int64 = 0): IAsyncActionWithProgressVtbl where Identity <: IAsyncActionWithProgress_Impl<TProgress>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
        let _ = offset
        var vtbl = IAsyncActionWithProgressVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.SetProgress = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<IAsyncActionWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_SetProgress(arg0)
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Progress = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncActionWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Progress(result__)
                case None =>
                    foundationNoInterfaceComOut(result__)
            }
        }
        vtbl.SetCompleted = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<IAsyncActionWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_SetCompleted(arg0)
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Completed = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncActionWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Completed(result__)
                case None =>
                    foundationNoInterfaceComOut(result__)
            }
        }
        vtbl.GetResults = { instanceRaw =>
            match (unsafe { asImplFromRaw<IAsyncActionWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_GetResults()
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches<TProgress>(iid: GUID): Bool where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
        if (iid == IAsyncActionWithProgress<TProgress>.iid()) {
            return true
        }
        for (ancestor in [IAsyncInfo.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }
}

public interface IAsyncActionWithProgress_ImplErased {
    public func __winrtThunk_SetProgress(arg0: CPointer<Unit>): Int32

    public func __winrtThunk_Progress(result__: CPointer<CPointer<Unit>>): Int32

    public func __winrtThunk_SetCompleted(arg0: CPointer<Unit>): Int32

    public func __winrtThunk_Completed(result__: CPointer<CPointer<Unit>>): Int32

    public func __winrtThunk_GetResults(): Int32
}

public interface IAsyncActionWithProgress_Impl<TProgress> <: IAsyncActionWithProgress_ImplErased & IAsyncInfo_Impl where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public func SetProgress(handler: InParam<AsyncActionProgressHandler<TProgress>>): windows_core.Result<Unit>

    public func __winrtThunk_SetProgress(arg0: CPointer<Unit>): Int32 {
        let handler = if (arg0.isNull()) {
            InParam<AsyncActionProgressHandler<TProgress>>()
        } else {
            InParam<AsyncActionProgressHandler<TProgress>>(AsyncActionProgressHandler<TProgress>.viewOf(arg0))
        }
        foundationUnitThunk({ => this.SetProgress(handler) })
    }

    public func Progress(): windows_core.Result<AsyncActionProgressHandler<TProgress>>

    public func __winrtThunk_Progress(result__: CPointer<CPointer<Unit>>): Int32 {
        foundationGenericOutThunk<AsyncActionProgressHandler<TProgress>>(result__, { => this.Progress() })
    }

    public func SetCompleted(handler: InParam<AsyncActionWithProgressCompletedHandler<TProgress>>): windows_core.Result<Unit>

    public func __winrtThunk_SetCompleted(arg0: CPointer<Unit>): Int32 {
        let handler = if (arg0.isNull()) {
            InParam<AsyncActionWithProgressCompletedHandler<TProgress>>()
        } else {
            InParam<AsyncActionWithProgressCompletedHandler<TProgress>>(AsyncActionWithProgressCompletedHandler<TProgress>.viewOf(arg0))
        }
        foundationUnitThunk({ => this.SetCompleted(handler) })
    }

    public func Completed(): windows_core.Result<AsyncActionWithProgressCompletedHandler<TProgress>>

    public func __winrtThunk_Completed(result__: CPointer<CPointer<Unit>>): Int32 {
        foundationGenericOutThunk<AsyncActionWithProgressCompletedHandler<TProgress>>(result__, { => this.Completed() })
    }

    public func GetResults(): windows_core.Result<Unit>

    public func __winrtThunk_GetResults(): Int32 {
        foundationUnitThunk({ => this.GetResults() })
    }

    public func __winrtThunk_Id(result__: CPointer<UInt32>): Int32 {
        foundationDirectScalarOutThunk<UInt32>(result__, 0u32, { => this.Id() })
    }

    public func __winrtThunk_Status(result__: CPointer<AsyncStatusAbi>): Int32 {
        foundationProjectedScalarOutThunk<AsyncStatus, AsyncStatusAbi, AsyncStatus>(result__, AsyncStatusAbi(), { => this.Status() })
    }

    public func __winrtThunk_ErrorCode(result__: CPointer<HResultAbi>): Int32 {
        foundationProjectedScalarOutThunk<HResult, HResultAbi, HResult>(result__, HResultAbi(), { => this.ErrorCode() })
    }

    public func __winrtThunk_Cancel(): Int32 {
        foundationUnitThunk({ => this.Cancel() })
    }

    public func __winrtThunk_Close(): Int32 {
        foundationUnitThunk({ => this.Close() })
    }
}

public class IAsyncActionWithProgress<TProgress> <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncActionWithProgress<TProgress> {
        IAsyncActionWithProgress<TProgress>(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncActionWithProgress<TProgress> {
        IAsyncActionWithProgress<TProgress>(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID.from_signature(IAsyncActionWithProgress<TProgress>.signature())
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IAsyncActionWithProgress<TProgress>.iid()) {
            return true
        }
        for (ancestor in [IAsyncInfo.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IAsyncActionWithProgress<TProgress>> {
        var descriptor = InterfaceDescriptor<IAsyncActionWithProgress<TProgress>>("IAsyncActionWithProgress", IAsyncActionWithProgress<TProgress>.iid(), windows_interface.eraseInterfaceDescriptor(IInspectable.descriptor()), [IAsyncInfo.iid()], { raw => IAsyncActionWithProgress<TProgress>.fromAbiTake(raw) }, { raw => IAsyncActionWithProgress<TProgress>.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncActionWithProgress<TProgress>.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncActionWithProgress", IAsyncActionWithProgress<TProgress>.iid(), IInspectable.descriptorSchema(), ["IAsyncInfo"], [IAsyncInfo.iid()], "IAsyncActionWithProgressVtbl", "IAsyncActionWithProgress", "IAsyncActionWithProgress_Impl", [InterfaceMethodSchema("SetProgress", 6, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncActionProgressHandler<TProgress>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Progress", 7, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncActionProgressHandler<TProgress>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("SetCompleted", 8, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncActionWithProgressCompletedHandler<TProgress>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Completed", 9, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncActionWithProgressCompletedHandler<TProgress>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetResults", 10, Array<InterfaceParameterSchema>(), "Int32")])
        schema.runtimeTypeContract = Some(IAsyncActionWithProgress<TProgress>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({1f6db258-e803-48a1-9546-eb7353398884}")
        sb.append(";")
        sb.append(TProgress.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IAsyncActionWithProgress"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IAsyncActionWithProgress", IAsyncActionWithProgress<TProgress>.signature(), IAsyncActionWithProgress<TProgress>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIAsyncInfo(): IAsyncInfo {
        match (unsafe { query<IAsyncInfo>(IAsyncInfo.descriptor()) }) {
            case Some(value) => value
            case None => throw Exception("asIAsyncInfo: QueryInterface failed (E_NOINTERFACE)")
        }
    }

    public unsafe func vtbl(): IAsyncActionWithProgressVtbl {
        readVtbl<IAsyncActionWithProgressVtbl>(IAsyncActionWithProgressVtbl())
    }

    public unsafe func SetProgress(handler: AsyncActionProgressHandler<TProgress>): Unit {
        let v = vtbl()
        let hr = v.SetProgress(asRaw(), handler.asRaw())
        HRESULT(hr).check()
    }

    public unsafe func Progress(): AsyncActionProgressHandler<TProgress> {
        let v = vtbl()
        var result__ = CPointer<Unit>()
        let hr = v.Progress(asRaw(), CPointer<CPointer<Unit>>(inout result__))
        checkFoundationComOutHRESULT(HRESULT(hr), CPointer<CPointer<Unit>>(inout result__))
        return AsyncActionProgressHandler<TProgress>.fromAbiTake(result__)
    }

    public unsafe func SetCompleted(handler: AsyncActionWithProgressCompletedHandler<TProgress>): Unit {
        let v = vtbl()
        let hr = v.SetCompleted(asRaw(), handler.asRaw())
        HRESULT(hr).check()
    }

    public unsafe func Completed(): AsyncActionWithProgressCompletedHandler<TProgress> {
        let v = vtbl()
        var result__ = CPointer<Unit>()
        let hr = v.Completed(asRaw(), CPointer<CPointer<Unit>>(inout result__))
        checkFoundationComOutHRESULT(HRESULT(hr), CPointer<CPointer<Unit>>(inout result__))
        return AsyncActionWithProgressCompletedHandler<TProgress>.fromAbiTake(result__)
    }

    public unsafe func GetResults(): Unit {
        let v = vtbl()
        let hr = v.GetResults(asRaw())
        HRESULT(hr).check()
    }
}

extend<TProgress> IAsyncActionWithProgress<TProgress> <: windows_core.Interface<IAsyncActionWithProgress<TProgress>> where TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {}

@C
public struct IAsyncOperationVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var SetCompleted: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Completed: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ => foundationNotImplComOut(result__) }
    public var GetResults: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ => foundationNotImplComOut(result__) }
    public init() {}

    public static func new<Identity, TResult>(offset!: Int64 = 0): IAsyncOperationVtbl where Identity <: IAsyncOperation_Impl<TResult>, TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
        let _ = offset
        var vtbl = IAsyncOperationVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.SetCompleted = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<IAsyncOperation_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_SetCompleted(arg0)
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Completed = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncOperation_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Completed(result__)
                case None =>
                    foundationNoInterfaceComOut(result__)
            }
        }
        vtbl.GetResults = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncOperation_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_GetResults(result__)
                case None =>
                    foundationNoInterfaceComOut(result__)
            }
        }
        return vtbl
    }

    public static func matches<TResult>(iid: GUID): Bool where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
        if (iid == IAsyncOperation<TResult>.iid()) {
            return true
        }
        for (ancestor in [IAsyncInfo.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }
}

public interface IAsyncOperation_ImplErased {
    public func __winrtThunk_SetCompleted(arg0: CPointer<Unit>): Int32

    public func __winrtThunk_Completed(result__: CPointer<CPointer<Unit>>): Int32

    public func __winrtThunk_GetResults(result__: CPointer<CPointer<Unit>>): Int32
}

public interface IAsyncOperation_Impl<TResult> <: IAsyncOperation_ImplErased & IAsyncInfo_Impl where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
    public func SetCompleted(handler: InParam<AsyncOperationCompletedHandler<TResult>>): windows_core.Result<Unit>

    public func __winrtThunk_SetCompleted(arg0: CPointer<Unit>): Int32 {
        let handler = if (arg0.isNull()) {
            InParam<AsyncOperationCompletedHandler<TResult>>()
        } else {
            InParam<AsyncOperationCompletedHandler<TResult>>(AsyncOperationCompletedHandler<TResult>.viewOf(arg0))
        }
        foundationUnitThunk({ => this.SetCompleted(handler) })
    }

    public func Completed(): windows_core.Result<AsyncOperationCompletedHandler<TResult>>

    public func __winrtThunk_Completed(result__: CPointer<CPointer<Unit>>): Int32 {
        foundationGenericOutThunk<AsyncOperationCompletedHandler<TResult>>(result__, { => this.Completed() })
    }

    public func GetResults(): windows_core.Result<TResult>

    public func __winrtThunk_GetResults(result__: CPointer<CPointer<Unit>>): Int32 {
        foundationGenericOutThunk<TResult>(result__, { => this.GetResults() })
    }

    public func __winrtThunk_Id(result__: CPointer<UInt32>): Int32 {
        foundationDirectScalarOutThunk<UInt32>(result__, 0u32, { => this.Id() })
    }

    public func __winrtThunk_Status(result__: CPointer<AsyncStatusAbi>): Int32 {
        foundationProjectedScalarOutThunk<AsyncStatus, AsyncStatusAbi, AsyncStatus>(result__, AsyncStatusAbi(), { => this.Status() })
    }

    public func __winrtThunk_ErrorCode(result__: CPointer<HResultAbi>): Int32 {
        foundationProjectedScalarOutThunk<HResult, HResultAbi, HResult>(result__, HResultAbi(), { => this.ErrorCode() })
    }

    public func __winrtThunk_Cancel(): Int32 {
        foundationUnitThunk({ => this.Cancel() })
    }

    public func __winrtThunk_Close(): Int32 {
        foundationUnitThunk({ => this.Close() })
    }
}

public class IAsyncOperation<TResult> <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncOperation<TResult> {
        IAsyncOperation<TResult>(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncOperation<TResult> {
        IAsyncOperation<TResult>(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID.from_signature(IAsyncOperation<TResult>.signature())
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IAsyncOperation<TResult>.iid()) {
            return true
        }
        for (ancestor in [IAsyncInfo.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IAsyncOperation<TResult>> {
        var descriptor = InterfaceDescriptor<IAsyncOperation<TResult>>("IAsyncOperation", IAsyncOperation<TResult>.iid(), windows_interface.eraseInterfaceDescriptor(IInspectable.descriptor()), [IAsyncInfo.iid()], { raw => IAsyncOperation<TResult>.fromAbiTake(raw) }, { raw => IAsyncOperation<TResult>.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncOperation<TResult>.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncOperation", IAsyncOperation<TResult>.iid(), IInspectable.descriptorSchema(), ["IAsyncInfo"], [IAsyncInfo.iid()], "IAsyncOperationVtbl", "IAsyncOperation", "IAsyncOperation_Impl", [InterfaceMethodSchema("SetCompleted", 6, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncOperationCompletedHandler<TResult>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Completed", 7, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncOperationCompletedHandler<TResult>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetResults", 8, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<TResult>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IAsyncOperation<TResult>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({9fc2b0bb-e446-44e2-aa61-9cab8f636af2}")
        sb.append(";")
        sb.append(TResult.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IAsyncOperation"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IAsyncOperation", IAsyncOperation<TResult>.signature(), IAsyncOperation<TResult>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIAsyncInfo(): IAsyncInfo {
        match (unsafe { query<IAsyncInfo>(IAsyncInfo.descriptor()) }) {
            case Some(value) => value
            case None => throw Exception("asIAsyncInfo: QueryInterface failed (E_NOINTERFACE)")
        }
    }

    public unsafe func vtbl(): IAsyncOperationVtbl {
        readVtbl<IAsyncOperationVtbl>(IAsyncOperationVtbl())
    }

    public unsafe func SetCompleted(handler: AsyncOperationCompletedHandler<TResult>): Unit {
        let v = vtbl()
        let hr = v.SetCompleted(asRaw(), handler.asRaw())
        HRESULT(hr).check()
    }

    public unsafe func Completed(): AsyncOperationCompletedHandler<TResult> {
        let v = vtbl()
        var result__ = CPointer<Unit>()
        let hr = v.Completed(asRaw(), CPointer<CPointer<Unit>>(inout result__))
        checkFoundationComOutHRESULT(HRESULT(hr), CPointer<CPointer<Unit>>(inout result__))
        return AsyncOperationCompletedHandler<TResult>.fromAbiTake(result__)
    }

    public unsafe func GetResults(): TResult {
        let v = vtbl()
        return windows_core.winrtCallGenericOut<TResult>(v.GetResults, asRaw())
    }
}

extend<TResult> IAsyncOperation<TResult> <: windows_core.Interface<IAsyncOperation<TResult>> where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult> {}

@C
public struct IAsyncOperationWithProgressVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var SetProgress: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Progress: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ => foundationNotImplComOut(result__) }
    public var SetCompleted: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Completed: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ => foundationNotImplComOut(result__) }
    public var GetResults: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, result__ => foundationNotImplComOut(result__) }
    public init() {}

    public static func new<Identity, TResult, TProgress>(offset!: Int64 = 0): IAsyncOperationWithProgressVtbl where Identity <: IAsyncOperationWithProgress_Impl<TResult, TProgress>, TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
        let _ = offset
        var vtbl = IAsyncOperationWithProgressVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.SetProgress = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<IAsyncOperationWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_SetProgress(arg0)
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Progress = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncOperationWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Progress(result__)
                case None =>
                    foundationNoInterfaceComOut(result__)
            }
        }
        vtbl.SetCompleted = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<IAsyncOperationWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_SetCompleted(arg0)
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Completed = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncOperationWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_Completed(result__)
                case None =>
                    foundationNoInterfaceComOut(result__)
            }
        }
        vtbl.GetResults = { instanceRaw, result__ =>
            match (unsafe { asImplFromRaw<IAsyncOperationWithProgress_ImplErased>(instanceRaw) }) {
                case Some(impl) =>
                    impl.__winrtThunk_GetResults(result__)
                case None =>
                    foundationNoInterfaceComOut(result__)
            }
        }
        return vtbl
    }

    public static func matches<TResult, TProgress>(iid: GUID): Bool where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
        if (iid == IAsyncOperationWithProgress<TResult, TProgress>.iid()) {
            return true
        }
        for (ancestor in [IAsyncInfo.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }
}

public interface IAsyncOperationWithProgress_ImplErased {
    public func __winrtThunk_SetProgress(arg0: CPointer<Unit>): Int32

    public func __winrtThunk_Progress(result__: CPointer<CPointer<Unit>>): Int32

    public func __winrtThunk_SetCompleted(arg0: CPointer<Unit>): Int32

    public func __winrtThunk_Completed(result__: CPointer<CPointer<Unit>>): Int32

    public func __winrtThunk_GetResults(result__: CPointer<CPointer<Unit>>): Int32
}

public interface IAsyncOperationWithProgress_Impl<TResult, TProgress> <: IAsyncOperationWithProgress_ImplErased & IAsyncInfo_Impl where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public func SetProgress(handler: InParam<AsyncOperationProgressHandler<TResult, TProgress>>): windows_core.Result<Unit>

    public func __winrtThunk_SetProgress(arg0: CPointer<Unit>): Int32 {
        let handler = if (arg0.isNull()) {
            InParam<AsyncOperationProgressHandler<TResult, TProgress>>()
        } else {
            InParam<AsyncOperationProgressHandler<TResult, TProgress>>(AsyncOperationProgressHandler<TResult, TProgress>.viewOf(arg0))
        }
        foundationUnitThunk({ => this.SetProgress(handler) })
    }

    public func Progress(): windows_core.Result<AsyncOperationProgressHandler<TResult, TProgress>>

    public func __winrtThunk_Progress(result__: CPointer<CPointer<Unit>>): Int32 {
        foundationGenericOutThunk<AsyncOperationProgressHandler<TResult, TProgress>>(result__, { => this.Progress() })
    }

    public func SetCompleted(handler: InParam<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>): windows_core.Result<Unit>

    public func __winrtThunk_SetCompleted(arg0: CPointer<Unit>): Int32 {
        let handler = if (arg0.isNull()) {
            InParam<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>()
        } else {
            InParam<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>(AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.viewOf(arg0))
        }
        foundationUnitThunk({ => this.SetCompleted(handler) })
    }

    public func Completed(): windows_core.Result<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>

    public func __winrtThunk_Completed(result__: CPointer<CPointer<Unit>>): Int32 {
        foundationGenericOutThunk<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>(result__, { => this.Completed() })
    }

    public func GetResults(): windows_core.Result<TResult>

    public func __winrtThunk_GetResults(result__: CPointer<CPointer<Unit>>): Int32 {
        foundationGenericOutThunk<TResult>(result__, { => this.GetResults() })
    }

    public func __winrtThunk_Id(result__: CPointer<UInt32>): Int32 {
        foundationDirectScalarOutThunk<UInt32>(result__, 0u32, { => this.Id() })
    }

    public func __winrtThunk_Status(result__: CPointer<AsyncStatusAbi>): Int32 {
        foundationProjectedScalarOutThunk<AsyncStatus, AsyncStatusAbi, AsyncStatus>(result__, AsyncStatusAbi(), { => this.Status() })
    }

    public func __winrtThunk_ErrorCode(result__: CPointer<HResultAbi>): Int32 {
        foundationProjectedScalarOutThunk<HResult, HResultAbi, HResult>(result__, HResultAbi(), { => this.ErrorCode() })
    }

    public func __winrtThunk_Cancel(): Int32 {
        foundationUnitThunk({ => this.Cancel() })
    }

    public func __winrtThunk_Close(): Int32 {
        foundationUnitThunk({ => this.Close() })
    }
}

public class IAsyncOperationWithProgress<TResult, TProgress> <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncOperationWithProgress<TResult, TProgress> {
        IAsyncOperationWithProgress<TResult, TProgress>(raw, takeOwnership: true, allowManualRelease: false)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncOperationWithProgress<TResult, TProgress> {
        IAsyncOperationWithProgress<TResult, TProgress>(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        return GUID.from_signature(IAsyncOperationWithProgress<TResult, TProgress>.signature())
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IAsyncOperationWithProgress<TResult, TProgress>.iid()) {
            return true
        }
        for (ancestor in [IAsyncInfo.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IAsyncOperationWithProgress<TResult, TProgress>> {
        var descriptor = InterfaceDescriptor<IAsyncOperationWithProgress<TResult, TProgress>>("IAsyncOperationWithProgress", IAsyncOperationWithProgress<TResult, TProgress>.iid(), windows_interface.eraseInterfaceDescriptor(IInspectable.descriptor()), [IAsyncInfo.iid()], { raw => IAsyncOperationWithProgress<TResult, TProgress>.fromAbiTake(raw) }, { raw => IAsyncOperationWithProgress<TResult, TProgress>.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncOperationWithProgress<TResult, TProgress>.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncOperationWithProgress", IAsyncOperationWithProgress<TResult, TProgress>.iid(), IInspectable.descriptorSchema(), ["IAsyncInfo"], [IAsyncInfo.iid()], "IAsyncOperationWithProgressVtbl", "IAsyncOperationWithProgress", "IAsyncOperationWithProgress_Impl", [InterfaceMethodSchema("SetProgress", 6, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncOperationProgressHandler<TResult, TProgress>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Progress", 7, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncOperationProgressHandler<TResult, TProgress>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("SetCompleted", 8, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Completed", 9, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetResults", 10, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<TResult>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IAsyncOperationWithProgress<TResult, TProgress>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({b5d036d7-e297-498f-ba60-0289e76e23dd}")
        sb.append(";")
        sb.append(TResult.signature())
        sb.append(";")
        sb.append(TProgress.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IAsyncOperationWithProgress"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IAsyncOperationWithProgress", IAsyncOperationWithProgress<TResult, TProgress>.signature(), IAsyncOperationWithProgress<TResult, TProgress>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIAsyncInfo(): IAsyncInfo {
        match (unsafe { query<IAsyncInfo>(IAsyncInfo.descriptor()) }) {
            case Some(value) => value
            case None => throw Exception("asIAsyncInfo: QueryInterface failed (E_NOINTERFACE)")
        }
    }

    public unsafe func vtbl(): IAsyncOperationWithProgressVtbl {
        readVtbl<IAsyncOperationWithProgressVtbl>(IAsyncOperationWithProgressVtbl())
    }

    public unsafe func SetProgress(handler: AsyncOperationProgressHandler<TResult, TProgress>): Unit {
        let v = vtbl()
        let hr = v.SetProgress(asRaw(), handler.asRaw())
        HRESULT(hr).check()
    }

    public unsafe func Progress(): AsyncOperationProgressHandler<TResult, TProgress> {
        let v = vtbl()
        var result__ = CPointer<Unit>()
        let hr = v.Progress(asRaw(), CPointer<CPointer<Unit>>(inout result__))
        checkFoundationComOutHRESULT(HRESULT(hr), CPointer<CPointer<Unit>>(inout result__))
        return AsyncOperationProgressHandler<TResult, TProgress>.fromAbiTake(result__)
    }

    public unsafe func SetCompleted(handler: AsyncOperationWithProgressCompletedHandler<TResult, TProgress>): Unit {
        let v = vtbl()
        let hr = v.SetCompleted(asRaw(), handler.asRaw())
        HRESULT(hr).check()
    }

    public unsafe func Completed(): AsyncOperationWithProgressCompletedHandler<TResult, TProgress> {
        let v = vtbl()
        var result__ = CPointer<Unit>()
        let hr = v.Completed(asRaw(), CPointer<CPointer<Unit>>(inout result__))
        checkFoundationComOutHRESULT(HRESULT(hr), CPointer<CPointer<Unit>>(inout result__))
        return AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.fromAbiTake(result__)
    }

    public unsafe func GetResults(): TResult {
        let v = vtbl()
        return windows_core.winrtCallGenericOut<TResult>(v.GetResults, asRaw())
    }
}

extend<TResult, TProgress> IAsyncOperationWithProgress<TResult, TProgress> <: windows_core.Interface<IAsyncOperationWithProgress<TResult, TProgress>> where TResult <: windows_core.RuntimeType & windows_core.WinrtGenericType<TResult>, TProgress <: windows_core.RuntimeType & windows_core.WinrtGenericType<TProgress> {}
