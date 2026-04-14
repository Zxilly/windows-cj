package Windows.Foundation

import std.collection.*
import windows_core.*
import windows_interface.*
import Windows.Foundation.Collections as Foundation_Collections
import Windows.Win32.Foundation as Win32_Foundation
import Windows.Win32.Foundation.*


@When[Windows_Foundation == "on"]
@C
public struct AsyncActionCompletedHandlerVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var _.ctor: CFunc<(CPointer<Unit>, CPointer<Unit>, IntNative) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, AsyncStatus) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class AsyncActionCompletedHandler <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncActionCompletedHandler {
        AsyncActionCompletedHandler(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncActionCompletedHandler {
        AsyncActionCompletedHandler(raw)
    }

    public static func iid(): GUID {
        return GUID(0xA4ED5C81, 0x76C9, 0x40BD, 0x8B, 0xE6, 0xB1, 0xD9, 0x0F, 0xB2, 0x0A, 0xE7)
    }

    public static func descriptor(): InterfaceDescriptor<AsyncActionCompletedHandler> {
        return InterfaceDescriptor<AsyncActionCompletedHandler>("AsyncActionCompletedHandler", AsyncActionCompletedHandler.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => AsyncActionCompletedHandler.fromAbiTake(raw) }, { raw => AsyncActionCompletedHandler.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "delegate({A4ED5C81-76C9-40BD-8BE6-B1D90FB20AE7})"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncActionCompletedHandler", AsyncActionCompletedHandler.signature(), AsyncActionCompletedHandler.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): AsyncActionCompletedHandlerVtbl {
        readVtbl<AsyncActionCompletedHandlerVtbl>(AsyncActionCompletedHandlerVtbl())
    }

    public unsafe func _.ctor(object: IInspectable, method: IntNative): Unit {
        let v = vtbl()
        let hr = v._.ctor(asRaw(), object.asRaw(), method)
        HRESULT(hr).ok()
    }

    public unsafe func Invoke(asyncInfo: IAsyncAction, asyncStatus: AsyncStatus): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.asRaw(), asyncStatus)
        HRESULT(hr).ok()
    }

    public static func new(invoke: (InParam<IAsyncAction>, AsyncStatus) -> Unit): AsyncActionCompletedHandler {
        let box = AsyncActionCompletedHandlerBox(invoke)
        let object = ComObject<AsyncActionCompletedHandlerBox>.new(box, [AsyncActionCompletedHandler.descriptorSchema()], [box.vtblPtr()])
        return object.intoInterface(AsyncActionCompletedHandler.descriptor())
    }
}

private open class AsyncActionCompletedHandlerInvoker {
    public open func Invoke(asyncInfo: InParam<IAsyncAction>, asyncStatus: AsyncStatus): Unit {
        ()
    }
}

private class AsyncActionCompletedHandlerBox <: AsyncActionCompletedHandlerInvoker {
    public let invoke_: (InParam<IAsyncAction>, AsyncStatus) -> Unit
    private let vtblHandle: CPointerHandle<AsyncActionCompletedHandlerVtbl>

    public init(invoke: (InParam<IAsyncAction>, AsyncStatus) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { acquireArrayRawData(Array<AsyncActionCompletedHandlerVtbl>(1, { _ => buildAsyncActionCompletedHandlerBoxVtbl() })) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public override func Invoke(asyncInfo: InParam<IAsyncAction>, asyncStatus: AsyncStatus): Unit {
        invoke_(asyncInfo, asyncStatus)
    }
}

func buildAsyncActionCompletedHandlerBoxVtbl(): AsyncActionCompletedHandlerVtbl {
    var vtbl = AsyncActionCompletedHandlerVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: AsyncStatus =>
        match (unsafe { asImplFromRaw<AsyncActionCompletedHandlerInvoker>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.Invoke(InParam<IAsyncAction>(IAsyncAction.viewOf(arg0)), arg1)
                return S_OK.value
            case None =>
                return E_NOTIMPL.value
        }
    }
    return vtbl
}

@When[Windows_Foundation == "on"]
@C
public struct AsyncActionProgressHandlerVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var _.ctor: CFunc<(CPointer<Unit>, CPointer<Unit>, IntNative) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class AsyncActionProgressHandler<TProgress> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType where TProgress <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncActionProgressHandler<TProgress> {
        AsyncActionProgressHandler<TProgress>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncActionProgressHandler<TProgress> {
        AsyncActionProgressHandler<TProgress>(raw)
    }

    public static func iid(): GUID {
        return GUID(0x6D844858, 0x0CFF, 0x4590, 0xAE, 0x89, 0x95, 0xA5, 0xA5, 0xC8, 0xB4, 0xB8)
    }

    public static func descriptor(): InterfaceDescriptor<AsyncActionProgressHandler<TProgress>> {
        return InterfaceDescriptor<AsyncActionProgressHandler<TProgress>>("AsyncActionProgressHandler", AsyncActionProgressHandler<TProgress>.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => AsyncActionProgressHandler<TProgress>.fromAbiTake(raw) }, { raw => AsyncActionProgressHandler<TProgress>.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({6D844858-0CFF-4590-AE89-95A5A5C8B4B8}")
        sb.append(";")
        sb.append(TProgress.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncActionProgressHandler", AsyncActionProgressHandler<TProgress>.signature(), AsyncActionProgressHandler<TProgress>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): AsyncActionProgressHandlerVtbl {
        readVtbl<AsyncActionProgressHandlerVtbl>(AsyncActionProgressHandlerVtbl())
    }

    public unsafe func _.ctor(object: IInspectable, method: IntNative): Unit {
        let v = vtbl()
        let hr = v._.ctor(asRaw(), object.asRaw(), method)
        HRESULT(hr).ok()
    }

    public unsafe func Invoke(asyncInfo: IAsyncActionWithProgress<TProgress>, progressInfo: TProgress): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.asRaw(), progressInfo)
        HRESULT(hr).ok()
    }

    public static func new(invoke: (InParam<IAsyncActionWithProgress<TProgress>>, TProgress) -> Unit): AsyncActionProgressHandler<TProgress> {
        let box = AsyncActionProgressHandlerBox<TProgress>(invoke)
        let object = ComObject<AsyncActionProgressHandlerBox<TProgress>>.new(box, [AsyncActionProgressHandler<TProgress>.descriptorSchema()], [box.vtblPtr()])
        return object.intoInterface(AsyncActionProgressHandler<TProgress>.descriptor())
    }
}

private open class AsyncActionProgressHandlerInvoker<TProgress> where TProgress <: windows_core.RuntimeType {
    public open func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, progressInfo: TProgress): Unit {
        ()
    }
}

private class AsyncActionProgressHandlerBox<TProgress> <: AsyncActionProgressHandlerInvoker<TProgress> where TProgress <: windows_core.RuntimeType {
    public let invoke_: (InParam<IAsyncActionWithProgress<TProgress>>, TProgress) -> Unit
    private let vtblHandle: CPointerHandle<AsyncActionProgressHandlerVtbl>

    public init(invoke: (InParam<IAsyncActionWithProgress<TProgress>>, TProgress) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { acquireArrayRawData(Array<AsyncActionProgressHandlerVtbl>(1, { _ => buildAsyncActionProgressHandlerBoxVtbl<TProgress>() })) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public override func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, progressInfo: TProgress): Unit {
        invoke_(asyncInfo, progressInfo)
    }
}

func buildAsyncActionProgressHandlerBoxVtbl<TProgress>(): AsyncActionProgressHandlerVtbl where TProgress <: windows_core.RuntimeType {
    var vtbl = AsyncActionProgressHandlerVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: CPointer<Unit> =>
        match (unsafe { asImplFromRaw<AsyncActionProgressHandlerInvoker<TProgress>>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.Invoke(InParam<IAsyncActionWithProgress<TProgress>>(IAsyncActionWithProgress<TProgress>.viewOf(arg0)), arg1)
                return S_OK.value
            case None =>
                return E_NOTIMPL.value
        }
    }
    return vtbl
}

@When[Windows_Foundation == "on"]
@C
public struct AsyncActionWithProgressCompletedHandlerVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var _.ctor: CFunc<(CPointer<Unit>, CPointer<Unit>, IntNative) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, AsyncStatus) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class AsyncActionWithProgressCompletedHandler<TProgress> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType where TProgress <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncActionWithProgressCompletedHandler<TProgress> {
        AsyncActionWithProgressCompletedHandler<TProgress>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncActionWithProgressCompletedHandler<TProgress> {
        AsyncActionWithProgressCompletedHandler<TProgress>(raw)
    }

    public static func iid(): GUID {
        return GUID(0x9C029F91, 0xCC84, 0x44FD, 0xAC, 0x26, 0x0A, 0x6C, 0x4E, 0x55, 0x52, 0x81)
    }

    public static func descriptor(): InterfaceDescriptor<AsyncActionWithProgressCompletedHandler<TProgress>> {
        return InterfaceDescriptor<AsyncActionWithProgressCompletedHandler<TProgress>>("AsyncActionWithProgressCompletedHandler", AsyncActionWithProgressCompletedHandler<TProgress>.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => AsyncActionWithProgressCompletedHandler<TProgress>.fromAbiTake(raw) }, { raw => AsyncActionWithProgressCompletedHandler<TProgress>.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({9C029F91-CC84-44FD-AC26-0A6C4E555281}")
        sb.append(";")
        sb.append(TProgress.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncActionWithProgressCompletedHandler", AsyncActionWithProgressCompletedHandler<TProgress>.signature(), AsyncActionWithProgressCompletedHandler<TProgress>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): AsyncActionWithProgressCompletedHandlerVtbl {
        readVtbl<AsyncActionWithProgressCompletedHandlerVtbl>(AsyncActionWithProgressCompletedHandlerVtbl())
    }

    public unsafe func _.ctor(object: IInspectable, method: IntNative): Unit {
        let v = vtbl()
        let hr = v._.ctor(asRaw(), object.asRaw(), method)
        HRESULT(hr).ok()
    }

    public unsafe func Invoke(asyncInfo: IAsyncActionWithProgress<TProgress>, asyncStatus: AsyncStatus): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.asRaw(), asyncStatus)
        HRESULT(hr).ok()
    }

    public static func new(invoke: (InParam<IAsyncActionWithProgress<TProgress>>, AsyncStatus) -> Unit): AsyncActionWithProgressCompletedHandler<TProgress> {
        let box = AsyncActionWithProgressCompletedHandlerBox<TProgress>(invoke)
        let object = ComObject<AsyncActionWithProgressCompletedHandlerBox<TProgress>>.new(box, [AsyncActionWithProgressCompletedHandler<TProgress>.descriptorSchema()], [box.vtblPtr()])
        return object.intoInterface(AsyncActionWithProgressCompletedHandler<TProgress>.descriptor())
    }
}

private open class AsyncActionWithProgressCompletedHandlerInvoker<TProgress> where TProgress <: windows_core.RuntimeType {
    public open func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, asyncStatus: AsyncStatus): Unit {
        ()
    }
}

private class AsyncActionWithProgressCompletedHandlerBox<TProgress> <: AsyncActionWithProgressCompletedHandlerInvoker<TProgress> where TProgress <: windows_core.RuntimeType {
    public let invoke_: (InParam<IAsyncActionWithProgress<TProgress>>, AsyncStatus) -> Unit
    private let vtblHandle: CPointerHandle<AsyncActionWithProgressCompletedHandlerVtbl>

    public init(invoke: (InParam<IAsyncActionWithProgress<TProgress>>, AsyncStatus) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { acquireArrayRawData(Array<AsyncActionWithProgressCompletedHandlerVtbl>(1, { _ => buildAsyncActionWithProgressCompletedHandlerBoxVtbl<TProgress>() })) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public override func Invoke(asyncInfo: InParam<IAsyncActionWithProgress<TProgress>>, asyncStatus: AsyncStatus): Unit {
        invoke_(asyncInfo, asyncStatus)
    }
}

func buildAsyncActionWithProgressCompletedHandlerBoxVtbl<TProgress>(): AsyncActionWithProgressCompletedHandlerVtbl where TProgress <: windows_core.RuntimeType {
    var vtbl = AsyncActionWithProgressCompletedHandlerVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: AsyncStatus =>
        match (unsafe { asImplFromRaw<AsyncActionWithProgressCompletedHandlerInvoker<TProgress>>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.Invoke(InParam<IAsyncActionWithProgress<TProgress>>(IAsyncActionWithProgress<TProgress>.viewOf(arg0)), arg1)
                return S_OK.value
            case None =>
                return E_NOTIMPL.value
        }
    }
    return vtbl
}

@When[Windows_Foundation == "on"]
@C
public struct AsyncOperationCompletedHandlerVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var _.ctor: CFunc<(CPointer<Unit>, CPointer<Unit>, IntNative) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, AsyncStatus) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class AsyncOperationCompletedHandler<TResult> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType where TResult <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncOperationCompletedHandler<TResult> {
        AsyncOperationCompletedHandler<TResult>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncOperationCompletedHandler<TResult> {
        AsyncOperationCompletedHandler<TResult>(raw)
    }

    public static func iid(): GUID {
        return GUID(0xFCDCF02C, 0xE5D8, 0x4478, 0x91, 0x5A, 0x4D, 0x90, 0xB7, 0x4B, 0x83, 0xA5)
    }

    public static func descriptor(): InterfaceDescriptor<AsyncOperationCompletedHandler<TResult>> {
        return InterfaceDescriptor<AsyncOperationCompletedHandler<TResult>>("AsyncOperationCompletedHandler", AsyncOperationCompletedHandler<TResult>.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => AsyncOperationCompletedHandler<TResult>.fromAbiTake(raw) }, { raw => AsyncOperationCompletedHandler<TResult>.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({FCDCF02C-E5D8-4478-915A-4D90B74B83A5}")
        sb.append(";")
        sb.append(TResult.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.AsyncOperationCompletedHandler", AsyncOperationCompletedHandler<TResult>.signature(), AsyncOperationCompletedHandler<TResult>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): AsyncOperationCompletedHandlerVtbl {
        readVtbl<AsyncOperationCompletedHandlerVtbl>(AsyncOperationCompletedHandlerVtbl())
    }

    public unsafe func _.ctor(object: IInspectable, method: IntNative): Unit {
        let v = vtbl()
        let hr = v._.ctor(asRaw(), object.asRaw(), method)
        HRESULT(hr).ok()
    }

    public unsafe func Invoke(asyncInfo: IAsyncOperation<TResult>, asyncStatus: AsyncStatus): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.asRaw(), asyncStatus)
        HRESULT(hr).ok()
    }

    public static func new(invoke: (InParam<IAsyncOperation<TResult>>, AsyncStatus) -> Unit): AsyncOperationCompletedHandler<TResult> {
        let box = AsyncOperationCompletedHandlerBox<TResult>(invoke)
        let object = ComObject<AsyncOperationCompletedHandlerBox<TResult>>.new(box, [AsyncOperationCompletedHandler<TResult>.descriptorSchema()], [box.vtblPtr()])
        return object.intoInterface(AsyncOperationCompletedHandler<TResult>.descriptor())
    }
}

private open class AsyncOperationCompletedHandlerInvoker<TResult> where TResult <: windows_core.RuntimeType {
    public open func Invoke(asyncInfo: InParam<IAsyncOperation<TResult>>, asyncStatus: AsyncStatus): Unit {
        ()
    }
}

private class AsyncOperationCompletedHandlerBox<TResult> <: AsyncOperationCompletedHandlerInvoker<TResult> where TResult <: windows_core.RuntimeType {
    public let invoke_: (InParam<IAsyncOperation<TResult>>, AsyncStatus) -> Unit
    private let vtblHandle: CPointerHandle<AsyncOperationCompletedHandlerVtbl>

    public init(invoke: (InParam<IAsyncOperation<TResult>>, AsyncStatus) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { acquireArrayRawData(Array<AsyncOperationCompletedHandlerVtbl>(1, { _ => buildAsyncOperationCompletedHandlerBoxVtbl<TResult>() })) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public override func Invoke(asyncInfo: InParam<IAsyncOperation<TResult>>, asyncStatus: AsyncStatus): Unit {
        invoke_(asyncInfo, asyncStatus)
    }
}

func buildAsyncOperationCompletedHandlerBoxVtbl<TResult>(): AsyncOperationCompletedHandlerVtbl where TResult <: windows_core.RuntimeType {
    var vtbl = AsyncOperationCompletedHandlerVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: AsyncStatus =>
        match (unsafe { asImplFromRaw<AsyncOperationCompletedHandlerInvoker<TResult>>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.Invoke(InParam<IAsyncOperation<TResult>>(IAsyncOperation<TResult>.viewOf(arg0)), arg1)
                return S_OK.value
            case None =>
                return E_NOTIMPL.value
        }
    }
    return vtbl
}

@When[Windows_Foundation == "on"]
@C
public struct AsyncOperationProgressHandlerVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var _.ctor: CFunc<(CPointer<Unit>, CPointer<Unit>, IntNative) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class AsyncOperationProgressHandler<TResult, TProgress> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncOperationProgressHandler<TResult, TProgress> {
        AsyncOperationProgressHandler<TResult, TProgress>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncOperationProgressHandler<TResult, TProgress> {
        AsyncOperationProgressHandler<TResult, TProgress>(raw)
    }

    public static func iid(): GUID {
        return GUID(0x55690902, 0x0AAB, 0x421A, 0x87, 0x78, 0xF8, 0xCE, 0x50, 0x26, 0xD7, 0x58)
    }

    public static func descriptor(): InterfaceDescriptor<AsyncOperationProgressHandler<TResult, TProgress>> {
        return InterfaceDescriptor<AsyncOperationProgressHandler<TResult, TProgress>>("AsyncOperationProgressHandler", AsyncOperationProgressHandler<TResult, TProgress>.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => AsyncOperationProgressHandler<TResult, TProgress>.fromAbiTake(raw) }, { raw => AsyncOperationProgressHandler<TResult, TProgress>.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({55690902-0AAB-421A-8778-F8CE5026D758}")
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
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): AsyncOperationProgressHandlerVtbl {
        readVtbl<AsyncOperationProgressHandlerVtbl>(AsyncOperationProgressHandlerVtbl())
    }

    public unsafe func _.ctor(object: IInspectable, method: IntNative): Unit {
        let v = vtbl()
        let hr = v._.ctor(asRaw(), object.asRaw(), method)
        HRESULT(hr).ok()
    }

    public unsafe func Invoke(asyncInfo: IAsyncOperationWithProgress<TResult, TProgress>, progressInfo: TProgress): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.asRaw(), progressInfo)
        HRESULT(hr).ok()
    }

    public static func new(invoke: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, TProgress) -> Unit): AsyncOperationProgressHandler<TResult, TProgress> {
        let box = AsyncOperationProgressHandlerBox<TResult, TProgress>(invoke)
        let object = ComObject<AsyncOperationProgressHandlerBox<TResult, TProgress>>.new(box, [AsyncOperationProgressHandler<TResult, TProgress>.descriptorSchema()], [box.vtblPtr()])
        return object.intoInterface(AsyncOperationProgressHandler<TResult, TProgress>.descriptor())
    }
}

private open class AsyncOperationProgressHandlerInvoker<TResult, TProgress> where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    public open func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, progressInfo: TProgress): Unit {
        ()
    }
}

private class AsyncOperationProgressHandlerBox<TResult, TProgress> <: AsyncOperationProgressHandlerInvoker<TResult, TProgress> where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    public let invoke_: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, TProgress) -> Unit
    private let vtblHandle: CPointerHandle<AsyncOperationProgressHandlerVtbl>

    public init(invoke: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, TProgress) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { acquireArrayRawData(Array<AsyncOperationProgressHandlerVtbl>(1, { _ => buildAsyncOperationProgressHandlerBoxVtbl<TResult, TProgress>() })) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public override func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, progressInfo: TProgress): Unit {
        invoke_(asyncInfo, progressInfo)
    }
}

func buildAsyncOperationProgressHandlerBoxVtbl<TResult, TProgress>(): AsyncOperationProgressHandlerVtbl where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    var vtbl = AsyncOperationProgressHandlerVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: CPointer<Unit> =>
        match (unsafe { asImplFromRaw<AsyncOperationProgressHandlerInvoker<TResult, TProgress>>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.Invoke(InParam<IAsyncOperationWithProgress<TResult, TProgress>>(IAsyncOperationWithProgress<TResult, TProgress>.viewOf(arg0)), arg1)
                return S_OK.value
            case None =>
                return E_NOTIMPL.value
        }
    }
    return vtbl
}

@When[Windows_Foundation == "on"]
@C
public struct AsyncOperationWithProgressCompletedHandlerVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var _.ctor: CFunc<(CPointer<Unit>, CPointer<Unit>, IntNative) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, AsyncStatus) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class AsyncOperationWithProgressCompletedHandler<TResult, TProgress> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): AsyncOperationWithProgressCompletedHandler<TResult, TProgress> {
        AsyncOperationWithProgressCompletedHandler<TResult, TProgress>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): AsyncOperationWithProgressCompletedHandler<TResult, TProgress> {
        AsyncOperationWithProgressCompletedHandler<TResult, TProgress>(raw)
    }

    public static func iid(): GUID {
        return GUID(0xE85DF41D, 0x6AA7, 0x46E3, 0xA8, 0xE2, 0xF0, 0x09, 0xD8, 0x40, 0xC6, 0x27)
    }

    public static func descriptor(): InterfaceDescriptor<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>> {
        return InterfaceDescriptor<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>("AsyncOperationWithProgressCompletedHandler", AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.fromAbiTake(raw) }, { raw => AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({E85DF41D-6AA7-46E3-A8E2-F009D840C627}")
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
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): AsyncOperationWithProgressCompletedHandlerVtbl {
        readVtbl<AsyncOperationWithProgressCompletedHandlerVtbl>(AsyncOperationWithProgressCompletedHandlerVtbl())
    }

    public unsafe func _.ctor(object: IInspectable, method: IntNative): Unit {
        let v = vtbl()
        let hr = v._.ctor(asRaw(), object.asRaw(), method)
        HRESULT(hr).ok()
    }

    public unsafe func Invoke(asyncInfo: IAsyncOperationWithProgress<TResult, TProgress>, asyncStatus: AsyncStatus): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), asyncInfo.asRaw(), asyncStatus)
        HRESULT(hr).ok()
    }

    public static func new(invoke: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, AsyncStatus) -> Unit): AsyncOperationWithProgressCompletedHandler<TResult, TProgress> {
        let box = AsyncOperationWithProgressCompletedHandlerBox<TResult, TProgress>(invoke)
        let object = ComObject<AsyncOperationWithProgressCompletedHandlerBox<TResult, TProgress>>.new(box, [AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.descriptorSchema()], [box.vtblPtr()])
        return object.intoInterface(AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.descriptor())
    }
}

private open class AsyncOperationWithProgressCompletedHandlerInvoker<TResult, TProgress> where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    public open func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, asyncStatus: AsyncStatus): Unit {
        ()
    }
}

private class AsyncOperationWithProgressCompletedHandlerBox<TResult, TProgress> <: AsyncOperationWithProgressCompletedHandlerInvoker<TResult, TProgress> where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    public let invoke_: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, AsyncStatus) -> Unit
    private let vtblHandle: CPointerHandle<AsyncOperationWithProgressCompletedHandlerVtbl>

    public init(invoke: (InParam<IAsyncOperationWithProgress<TResult, TProgress>>, AsyncStatus) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { acquireArrayRawData(Array<AsyncOperationWithProgressCompletedHandlerVtbl>(1, { _ => buildAsyncOperationWithProgressCompletedHandlerBoxVtbl<TResult, TProgress>() })) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public override func Invoke(asyncInfo: InParam<IAsyncOperationWithProgress<TResult, TProgress>>, asyncStatus: AsyncStatus): Unit {
        invoke_(asyncInfo, asyncStatus)
    }
}

func buildAsyncOperationWithProgressCompletedHandlerBoxVtbl<TResult, TProgress>(): AsyncOperationWithProgressCompletedHandlerVtbl where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    var vtbl = AsyncOperationWithProgressCompletedHandlerVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: AsyncStatus =>
        match (unsafe { asImplFromRaw<AsyncOperationWithProgressCompletedHandlerInvoker<TResult, TProgress>>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.Invoke(InParam<IAsyncOperationWithProgress<TResult, TProgress>>(IAsyncOperationWithProgress<TResult, TProgress>.viewOf(arg0)), arg1)
                return S_OK.value
            case None =>
                return E_NOTIMPL.value
        }
    }
    return vtbl
}

@When[Windows_Foundation == "on"]
@C
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

@When[Windows_Foundation == "on"]
public let Canceled: AsyncStatus = AsyncStatus(2)

@When[Windows_Foundation == "on"]
public let Completed: AsyncStatus = AsyncStatus(1)

@When[Windows_Foundation == "on"]
public let Error: AsyncStatus = AsyncStatus(3)

@When[Windows_Foundation == "on"]
public let Started: AsyncStatus = AsyncStatus(0)

@When[Windows_Foundation == "on"]
@C
public struct DateTime {
    public var UniversalTime: Int64 = 0
    public init() {}
}

@When[Windows_Foundation == "on"]
public class Deferral <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): Deferral {
        Deferral(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): Deferral {
        Deferral(raw)
    }

    public static func iid(): GUID {
        IDeferral.iid()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.Deferral"
    }

    public static func descriptor(): InterfaceDescriptor<Deferral> {
        let ancestors = [IDeferral.iid(), IClosable.iid(), IInspectable.iid(), IUnknown.iid()]
        return InterfaceDescriptor<Deferral>("Deferral", IDeferral.iid(), ancestors, { raw => Deferral.fromAbiTake(raw) }, { raw => Deferral.viewOf(raw) })
    }

    public func defaultInterface(): IDeferral {
        IDeferral.viewOf(asRaw())
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "rc(Windows.Foundation.Deferral;{D6269732-3B7F-46A7-B40B-4FDCA2A2C693})"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.Deferral", Deferral.signature(), IDeferral.iid())
    }

    public static func activationFactory(): Option<IActivationFactory> {
        windows_interface.getActivationFactoryByName<IActivationFactory>(Deferral.runtimeName(), IActivationFactory.descriptor()).ok()
    }

    public static func isAgile(): Bool {
        true
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIDeferral(): IDeferral {
        IDeferral(asRaw())
    }

    public func asIClosable(): IClosable {
        IClosable(asRaw())
    }

    public static unsafe func Create(handler: DeferralCompletedHandler): Deferral {
        try (factory = windows_interface.getActivationFactoryByName<IDeferralFactory>(Deferral.runtimeName(), IDeferralFactory.descriptor()).unwrap()) {
            return factory.Create(handler)
        }
    }

    public unsafe func Complete(): Unit {
        defaultInterface().Complete()
    }

    public unsafe func Close(): Unit {
        asIClosable().Close()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct DeferralCompletedHandlerVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var _.ctor: CFunc<(CPointer<Unit>, CPointer<Unit>, IntNative) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var Invoke: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class DeferralCompletedHandler <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): DeferralCompletedHandler {
        DeferralCompletedHandler(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): DeferralCompletedHandler {
        DeferralCompletedHandler(raw)
    }

    public static func iid(): GUID {
        return GUID(0xED32A372, 0xF3C8, 0x4FAA, 0x9C, 0xFB, 0x47, 0x01, 0x48, 0xDA, 0x38, 0x88)
    }

    public static func descriptor(): InterfaceDescriptor<DeferralCompletedHandler> {
        return InterfaceDescriptor<DeferralCompletedHandler>("DeferralCompletedHandler", DeferralCompletedHandler.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => DeferralCompletedHandler.fromAbiTake(raw) }, { raw => DeferralCompletedHandler.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "delegate({ED32A372-F3C8-4FAA-9CFB-470148DA3888})"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.DeferralCompletedHandler", DeferralCompletedHandler.signature(), DeferralCompletedHandler.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): DeferralCompletedHandlerVtbl {
        readVtbl<DeferralCompletedHandlerVtbl>(DeferralCompletedHandlerVtbl())
    }

    public unsafe func _.ctor(object: IInspectable, method: IntNative): Unit {
        let v = vtbl()
        let hr = v._.ctor(asRaw(), object.asRaw(), method)
        HRESULT(hr).ok()
    }

    public unsafe func Invoke(): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw())
        HRESULT(hr).ok()
    }

    public static func new(invoke: () -> Unit): DeferralCompletedHandler {
        let box = DeferralCompletedHandlerBox(invoke)
        let object = ComObject<DeferralCompletedHandlerBox>.new(box, [DeferralCompletedHandler.descriptorSchema()], [box.vtblPtr()])
        return object.intoInterface(DeferralCompletedHandler.descriptor())
    }
}

private open class DeferralCompletedHandlerInvoker {
    public open func Invoke(): Unit {
        ()
    }
}

private class DeferralCompletedHandlerBox <: DeferralCompletedHandlerInvoker {
    public let invoke_: () -> Unit
    private let vtblHandle: CPointerHandle<DeferralCompletedHandlerVtbl>

    public init(invoke: () -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { acquireArrayRawData(Array<DeferralCompletedHandlerVtbl>(1, { _ => buildDeferralCompletedHandlerBoxVtbl() })) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public override func Invoke(): Unit {
        invoke_()
    }
}

func buildDeferralCompletedHandlerBoxVtbl(): DeferralCompletedHandlerVtbl {
    var vtbl = DeferralCompletedHandlerVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit> =>
        match (unsafe { asImplFromRaw<DeferralCompletedHandlerInvoker>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.Invoke()
                return S_OK.value
            case None =>
                return E_NOTIMPL.value
        }
    }
    return vtbl
}

@When[Windows_Foundation == "on"]
@C
public struct EventHandlerVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var _.ctor: CFunc<(CPointer<Unit>, CPointer<Unit>, IntNative) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class EventHandler<T> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType where T <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): EventHandler<T> {
        EventHandler<T>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): EventHandler<T> {
        EventHandler<T>(raw)
    }

    public static func iid(): GUID {
        return GUID(0x9DE1C535, 0x6AE1, 0x11E0, 0x84, 0xE1, 0x18, 0xA9, 0x05, 0xBC, 0xC5, 0x3F)
    }

    public static func descriptor(): InterfaceDescriptor<EventHandler<T>> {
        return InterfaceDescriptor<EventHandler<T>>("EventHandler", EventHandler<T>.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => EventHandler<T>.fromAbiTake(raw) }, { raw => EventHandler<T>.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({9DE1C535-6AE1-11E0-84E1-18A905BCC53F}")
        sb.append(";")
        sb.append(T.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.EventHandler", EventHandler<T>.signature(), EventHandler<T>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): EventHandlerVtbl {
        readVtbl<EventHandlerVtbl>(EventHandlerVtbl())
    }

    public unsafe func _.ctor(object: IInspectable, method: IntNative): Unit {
        let v = vtbl()
        let hr = v._.ctor(asRaw(), object.asRaw(), method)
        HRESULT(hr).ok()
    }

    public unsafe func Invoke(sender: IInspectable, args: T): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), sender.asRaw(), args)
        HRESULT(hr).ok()
    }

    public static func new(invoke: (InParam<IInspectable>, T) -> Unit): EventHandler<T> {
        let box = EventHandlerBox<T>(invoke)
        let object = ComObject<EventHandlerBox<T>>.new(box, [EventHandler<T>.descriptorSchema()], [box.vtblPtr()])
        return object.intoInterface(EventHandler<T>.descriptor())
    }
}

private open class EventHandlerInvoker<T> where T <: windows_core.RuntimeType {
    public open func Invoke(sender: InParam<IInspectable>, args: T): Unit {
        ()
    }
}

private class EventHandlerBox<T> <: EventHandlerInvoker<T> where T <: windows_core.RuntimeType {
    public let invoke_: (InParam<IInspectable>, T) -> Unit
    private let vtblHandle: CPointerHandle<EventHandlerVtbl>

    public init(invoke: (InParam<IInspectable>, T) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { acquireArrayRawData(Array<EventHandlerVtbl>(1, { _ => buildEventHandlerBoxVtbl<T>() })) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public override func Invoke(sender: InParam<IInspectable>, args: T): Unit {
        invoke_(sender, args)
    }
}

func buildEventHandlerBoxVtbl<T>(): EventHandlerVtbl where T <: windows_core.RuntimeType {
    var vtbl = EventHandlerVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: CPointer<Unit> =>
        match (unsafe { asImplFromRaw<EventHandlerInvoker<T>>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.Invoke(InParam<IInspectable>(IInspectable.viewOf(arg0)), arg1)
                return S_OK.value
            case None =>
                return E_NOTIMPL.value
        }
    }
    return vtbl
}

@When[Windows_Foundation == "on"]
public type EventRegistrationToken = CPointer<Unit>

@When[Windows_Foundation == "on"]
@C
public struct FoundationContract {
    public init() {}
}

@When[Windows_Foundation == "on"]
public class GuidHelper <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): GuidHelper {
        GuidHelper(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): GuidHelper {
        GuidHelper(raw)
    }

    public static func iid(): GUID {
        GUID()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.GuidHelper"
    }

    public static func descriptor(): InterfaceDescriptor<GuidHelper> {
        return InterfaceDescriptor<GuidHelper>("GuidHelper", GUID(), [IInspectable.iid(), IUnknown.iid()], { raw => GuidHelper.fromAbiTake(raw) }, { raw => GuidHelper.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "Windows.Foundation.GuidHelper"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.GuidHelper", GuidHelper.signature())
    }

    public static func activationFactory(): Option<IActivationFactory> {
        windows_interface.getActivationFactoryByName<IActivationFactory>(GuidHelper.runtimeName(), IActivationFactory.descriptor()).ok()
    }

    public static func isAgile(): Bool {
        true
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public static unsafe func CreateNewGuid(): GUID {
        try (factory = windows_interface.getActivationFactoryByName<IGuidHelperStatics>(GuidHelper.runtimeName(), IGuidHelperStatics.descriptor()).unwrap()) {
            return factory.CreateNewGuid()
        }
    }

    public static unsafe func Empty(): GUID {
        try (factory = windows_interface.getActivationFactoryByName<IGuidHelperStatics>(GuidHelper.runtimeName(), IGuidHelperStatics.descriptor()).unwrap()) {
            return factory.Empty()
        }
    }

    public static unsafe func Equals(target: CPointer<GUID>, value: CPointer<GUID>): Bool {
        try (factory = windows_interface.getActivationFactoryByName<IGuidHelperStatics>(GuidHelper.runtimeName(), IGuidHelperStatics.descriptor()).unwrap()) {
            return factory.Equals(target, value)
        }
    }
}

@When[Windows_Foundation == "on"]
public type HResult = Int32

@When[Windows_Foundation == "on"]
@C
public struct IAsyncActionVtbl {
    public var base_: IAsyncInfoVtbl = IAsyncInfoVtbl()
    public var SetCompleted: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Completed: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetResults: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IAsyncActionVtbl where Identity <: IAsyncAction_Impl {
        let _ = offset
        var vtbl = IAsyncActionVtbl()
        vtbl.base_ = IAsyncInfoVtbl.new<Identity>(offset: offset)
        vtbl.SetCompleted = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.SetCompleted(InParam<AsyncActionCompletedHandler>(AsyncActionCompletedHandler.viewOf(arg0)))) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Completed = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Completed()) {
                        case Result<AsyncActionCompletedHandler>.Ok(value) =>
                            let raw = value.intoAbi()
                            if (raw.isNull()) {
                                E_POINTER.value
                            } else {
                                unsafe { result__.write(raw) }
                                S_OK.value
                            }
                        case Result<AsyncActionCompletedHandler>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetResults = { instanceRaw =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetResults()) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
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

@When[Windows_Foundation == "on"]
public interface IAsyncAction_Impl <: IAsyncInfo_Impl {
    public func SetCompleted(handler: InParam<AsyncActionCompletedHandler>): windows_core.Result<Unit>
    public func Completed(): windows_core.Result<AsyncActionCompletedHandler>
    public func GetResults(): windows_core.Result<Unit>
}

@When[Windows_Foundation == "on"]
public class IAsyncAction <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncAction {
        IAsyncAction(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncAction {
        IAsyncAction(raw)
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
        var descriptor = InterfaceDescriptor<IAsyncAction>("IAsyncAction", IAsyncAction.iid(), IAsyncInfo.descriptor(), { raw => IAsyncAction.fromAbiTake(raw) }, { raw => IAsyncAction.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncAction.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncAction", IAsyncAction.iid(), IAsyncInfo.descriptorSchema(), "IAsyncActionVtbl", "IAsyncAction", "IAsyncAction_Impl", [InterfaceMethodSchema("SetCompleted", 11, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncActionCompletedHandler>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Completed", 12, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncActionCompletedHandler>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetResults", 13, [], "Int32")])
        schema.runtimeTypeContract = Some(IAsyncAction.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{5A648006-843A-4DA9-865B-9D26E5DFAD7B}"
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
        IAsyncInfo.viewOf(asRaw())
    }

    public unsafe func vtbl(): IAsyncActionVtbl {
        readVtbl<IAsyncActionVtbl>(IAsyncActionVtbl())
    }

    public unsafe func SetCompleted(handler: AsyncActionCompletedHandler): Unit {
        let v = vtbl()
        let hr = v.SetCompleted(asRaw(), handler.asRaw())
        HRESULT(hr).ok()
    }

    public unsafe func Completed(): AsyncActionCompletedHandler {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.Completed(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return AsyncActionCompletedHandler.fromAbiTake(result)
    }

    public unsafe func GetResults(): Unit {
        let v = vtbl()
        let hr = v.GetResults(asRaw())
        HRESULT(hr).ok()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IAsyncActionWithProgressVtbl {
    public var base_: IAsyncInfoVtbl = IAsyncInfoVtbl()
    public var SetProgress: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Progress: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var SetCompleted: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Completed: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetResults: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity, TProgress>(offset!: Int64 = 0): IAsyncActionWithProgressVtbl where Identity <: IAsyncActionWithProgress_Impl<TProgress>, TProgress <: windows_core.RuntimeType {
        let _ = offset
        var vtbl = IAsyncActionWithProgressVtbl()
        vtbl.base_ = IAsyncInfoVtbl.new<Identity>(offset: offset)
        vtbl.SetProgress = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.SetProgress(InParam<AsyncActionProgressHandler<TProgress>>(AsyncActionProgressHandler<TProgress>.viewOf(arg0)))) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Progress = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Progress()) {
                        case Result<AsyncActionProgressHandler<TProgress>>.Ok(value) =>
                            let raw = value.intoAbi()
                            if (raw.isNull()) {
                                E_POINTER.value
                            } else {
                                unsafe { result__.write(raw) }
                                S_OK.value
                            }
                        case Result<AsyncActionProgressHandler<TProgress>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.SetCompleted = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.SetCompleted(InParam<AsyncActionWithProgressCompletedHandler<TProgress>>(AsyncActionWithProgressCompletedHandler<TProgress>.viewOf(arg0)))) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Completed = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Completed()) {
                        case Result<AsyncActionWithProgressCompletedHandler<TProgress>>.Ok(value) =>
                            let raw = value.intoAbi()
                            if (raw.isNull()) {
                                E_POINTER.value
                            } else {
                                unsafe { result__.write(raw) }
                                S_OK.value
                            }
                        case Result<AsyncActionWithProgressCompletedHandler<TProgress>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetResults = { instanceRaw =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetResults()) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
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
}

@When[Windows_Foundation == "on"]
public interface IAsyncActionWithProgress_Impl<TProgress> <: IAsyncInfo_Impl where TProgress <: windows_core.RuntimeType {
    public func SetProgress(handler: InParam<AsyncActionProgressHandler<TProgress>>): windows_core.Result<Unit>
    public func Progress(): windows_core.Result<AsyncActionProgressHandler<TProgress>>
    public func SetCompleted(handler: InParam<AsyncActionWithProgressCompletedHandler<TProgress>>): windows_core.Result<Unit>
    public func Completed(): windows_core.Result<AsyncActionWithProgressCompletedHandler<TProgress>>
    public func GetResults(): windows_core.Result<Unit>
}

@When[Windows_Foundation == "on"]
public class IAsyncActionWithProgress<TProgress> <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TProgress <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncActionWithProgress<TProgress> {
        IAsyncActionWithProgress<TProgress>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncActionWithProgress<TProgress> {
        IAsyncActionWithProgress<TProgress>(raw)
    }

    public static func iid(): GUID {
        return GUID(0x1F6DB258, 0xE803, 0x48A1, 0x95, 0x46, 0xEB, 0x73, 0x53, 0x39, 0x88, 0x84)
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
        var descriptor = InterfaceDescriptor<IAsyncActionWithProgress<TProgress>>("IAsyncActionWithProgress", IAsyncActionWithProgress<TProgress>.iid(), IAsyncInfo.descriptor(), { raw => IAsyncActionWithProgress<TProgress>.fromAbiTake(raw) }, { raw => IAsyncActionWithProgress<TProgress>.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncActionWithProgress<TProgress>.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncActionWithProgress", IAsyncActionWithProgress<TProgress>.iid(), IAsyncInfo.descriptorSchema(), "IAsyncActionWithProgressVtbl", "IAsyncActionWithProgress", "IAsyncActionWithProgress_Impl", [InterfaceMethodSchema("SetProgress", 11, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncActionProgressHandler<TProgress>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Progress", 12, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncActionProgressHandler<TProgress>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("SetCompleted", 13, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncActionWithProgressCompletedHandler<TProgress>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Completed", 14, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncActionWithProgressCompletedHandler<TProgress>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetResults", 15, [], "Int32")])
        schema.runtimeTypeContract = Some(IAsyncActionWithProgress<TProgress>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({1F6DB258-E803-48A1-9546-EB7353398884}")
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
        IAsyncInfo.viewOf(asRaw())
    }

    public unsafe func vtbl(): IAsyncActionWithProgressVtbl {
        readVtbl<IAsyncActionWithProgressVtbl>(IAsyncActionWithProgressVtbl())
    }

    public unsafe func SetProgress(handler: AsyncActionProgressHandler<TProgress>): Unit {
        let v = vtbl()
        let hr = v.SetProgress(asRaw(), handler.asRaw())
        HRESULT(hr).ok()
    }

    public unsafe func Progress(): AsyncActionProgressHandler<TProgress> {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.Progress(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return AsyncActionProgressHandler<TProgress>.fromAbiTake(result)
    }

    public unsafe func SetCompleted(handler: AsyncActionWithProgressCompletedHandler<TProgress>): Unit {
        let v = vtbl()
        let hr = v.SetCompleted(asRaw(), handler.asRaw())
        HRESULT(hr).ok()
    }

    public unsafe func Completed(): AsyncActionWithProgressCompletedHandler<TProgress> {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.Completed(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return AsyncActionWithProgressCompletedHandler<TProgress>.fromAbiTake(result)
    }

    public unsafe func GetResults(): Unit {
        let v = vtbl()
        let hr = v.GetResults(asRaw())
        HRESULT(hr).ok()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IAsyncInfoVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var Id: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Status: CFunc<(CPointer<Unit>, CPointer<AsyncStatus>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var ErrorCode: CFunc<(CPointer<Unit>, CPointer<HResult>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Cancel: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public var Close: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IAsyncInfoVtbl where Identity <: IAsyncInfo_Impl {
        let _ = offset
        var vtbl = IAsyncInfoVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.Id = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Id()) {
                        case Result<UInt32>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<UInt32>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Status = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Status()) {
                        case Result<AsyncStatus>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<AsyncStatus>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.ErrorCode = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.ErrorCode()) {
                        case Result<HResult>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<HResult>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Cancel = { instanceRaw =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Cancel()) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Close = { instanceRaw =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Close()) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
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

@When[Windows_Foundation == "on"]
public interface IAsyncInfo_Impl {
    public func Id(): windows_core.Result<UInt32>
    public func Status(): windows_core.Result<AsyncStatus>
    public func ErrorCode(): windows_core.Result<HResult>
    public func Cancel(): windows_core.Result<Unit>
    public func Close(): windows_core.Result<Unit>
}

@When[Windows_Foundation == "on"]
public class IAsyncInfo <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncInfo {
        IAsyncInfo(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncInfo {
        IAsyncInfo(raw)
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
        var descriptor = InterfaceDescriptor<IAsyncInfo>("IAsyncInfo", IAsyncInfo.iid(), IInspectable.descriptor(), { raw => IAsyncInfo.fromAbiTake(raw) }, { raw => IAsyncInfo.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncInfo.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncInfo", IAsyncInfo.iid(), IInspectable.descriptorSchema(), "IAsyncInfoVtbl", "IAsyncInfo", "IAsyncInfo_Impl", [InterfaceMethodSchema("Id", 6, [InterfaceParameterSchema("result", "CPointer<UInt32>", "OutSlot<UInt32>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Status", 7, [InterfaceParameterSchema("result", "CPointer<AsyncStatus>", "OutSlot<AsyncStatus>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("ErrorCode", 8, [InterfaceParameterSchema("result", "CPointer<HResult>", "OutSlot<HResult>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Cancel", 9, [], "Int32"), InterfaceMethodSchema("Close", 10, [], "Int32")])
        schema.runtimeTypeContract = Some(IAsyncInfo.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{00000036-0000-0000-C000-000000000046}"
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
        var result = 0
        let hr = v.Id(asRaw(), CPointer<UInt32>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Status(): AsyncStatus {
        let v = vtbl()
        var result = AsyncStatus()
        let hr = v.Status(asRaw(), CPointer<AsyncStatus>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func ErrorCode(): HResult {
        let v = vtbl()
        var result = HResult()
        let hr = v.ErrorCode(asRaw(), CPointer<HResult>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Cancel(): Unit {
        let v = vtbl()
        let hr = v.Cancel(asRaw())
        HRESULT(hr).ok()
    }

    public unsafe func Close(): Unit {
        let v = vtbl()
        let hr = v.Close(asRaw())
        HRESULT(hr).ok()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IAsyncOperationVtbl {
    public var base_: IAsyncInfoVtbl = IAsyncInfoVtbl()
    public var SetCompleted: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Completed: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetResults: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity, TResult>(offset!: Int64 = 0): IAsyncOperationVtbl where Identity <: IAsyncOperation_Impl<TResult>, TResult <: windows_core.RuntimeType {
        let _ = offset
        var vtbl = IAsyncOperationVtbl()
        vtbl.base_ = IAsyncInfoVtbl.new<Identity>(offset: offset)
        vtbl.SetCompleted = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.SetCompleted(InParam<AsyncOperationCompletedHandler<TResult>>(AsyncOperationCompletedHandler<TResult>.viewOf(arg0)))) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Completed = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Completed()) {
                        case Result<AsyncOperationCompletedHandler<TResult>>.Ok(value) =>
                            let raw = value.intoAbi()
                            if (raw.isNull()) {
                                E_POINTER.value
                            } else {
                                unsafe { result__.write(raw) }
                                S_OK.value
                            }
                        case Result<AsyncOperationCompletedHandler<TResult>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetResults = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetResults()) {
                        case Result<TResult>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<TResult>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
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
}

@When[Windows_Foundation == "on"]
public interface IAsyncOperation_Impl<TResult> <: IAsyncInfo_Impl where TResult <: windows_core.RuntimeType {
    public func SetCompleted(handler: InParam<AsyncOperationCompletedHandler<TResult>>): windows_core.Result<Unit>
    public func Completed(): windows_core.Result<AsyncOperationCompletedHandler<TResult>>
    public func GetResults(): windows_core.Result<TResult>
}

@When[Windows_Foundation == "on"]
public class IAsyncOperation<TResult> <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TResult <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncOperation<TResult> {
        IAsyncOperation<TResult>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncOperation<TResult> {
        IAsyncOperation<TResult>(raw)
    }

    public static func iid(): GUID {
        return GUID(0x9FC2B0BB, 0xE446, 0x44E2, 0xAA, 0x61, 0x9C, 0xAB, 0x8F, 0x63, 0x6A, 0xF2)
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
        var descriptor = InterfaceDescriptor<IAsyncOperation<TResult>>("IAsyncOperation", IAsyncOperation<TResult>.iid(), IAsyncInfo.descriptor(), { raw => IAsyncOperation<TResult>.fromAbiTake(raw) }, { raw => IAsyncOperation<TResult>.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncOperation<TResult>.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncOperation", IAsyncOperation<TResult>.iid(), IAsyncInfo.descriptorSchema(), "IAsyncOperationVtbl", "IAsyncOperation", "IAsyncOperation_Impl", [InterfaceMethodSchema("SetCompleted", 11, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncOperationCompletedHandler<TResult>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Completed", 12, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncOperationCompletedHandler<TResult>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetResults", 13, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<TResult>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IAsyncOperation<TResult>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({9FC2B0BB-E446-44E2-AA61-9CAB8F636AF2}")
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
        IAsyncInfo.viewOf(asRaw())
    }

    public unsafe func vtbl(): IAsyncOperationVtbl {
        readVtbl<IAsyncOperationVtbl>(IAsyncOperationVtbl())
    }

    public unsafe func SetCompleted(handler: AsyncOperationCompletedHandler<TResult>): Unit {
        let v = vtbl()
        let hr = v.SetCompleted(asRaw(), handler.asRaw())
        HRESULT(hr).ok()
    }

    public unsafe func Completed(): AsyncOperationCompletedHandler<TResult> {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.Completed(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return AsyncOperationCompletedHandler<TResult>.fromAbiTake(result)
    }

    public unsafe func GetResults(): TResult {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.GetResults(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return result
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IAsyncOperationWithProgressVtbl {
    public var base_: IAsyncInfoVtbl = IAsyncInfoVtbl()
    public var SetProgress: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Progress: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var SetCompleted: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Completed: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetResults: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity, TResult, TProgress>(offset!: Int64 = 0): IAsyncOperationWithProgressVtbl where Identity <: IAsyncOperationWithProgress_Impl<TResult, TProgress>, TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
        let _ = offset
        var vtbl = IAsyncOperationWithProgressVtbl()
        vtbl.base_ = IAsyncInfoVtbl.new<Identity>(offset: offset)
        vtbl.SetProgress = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.SetProgress(InParam<AsyncOperationProgressHandler<TResult, TProgress>>(AsyncOperationProgressHandler<TResult, TProgress>.viewOf(arg0)))) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Progress = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Progress()) {
                        case Result<AsyncOperationProgressHandler<TResult, TProgress>>.Ok(value) =>
                            let raw = value.intoAbi()
                            if (raw.isNull()) {
                                E_POINTER.value
                            } else {
                                unsafe { result__.write(raw) }
                                S_OK.value
                            }
                        case Result<AsyncOperationProgressHandler<TResult, TProgress>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.SetCompleted = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.SetCompleted(InParam<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>(AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.viewOf(arg0)))) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Completed = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Completed()) {
                        case Result<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>.Ok(value) =>
                            let raw = value.intoAbi()
                            if (raw.isNull()) {
                                E_POINTER.value
                            } else {
                                unsafe { result__.write(raw) }
                                S_OK.value
                            }
                        case Result<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetResults = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetResults()) {
                        case Result<TResult>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<TResult>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
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
}

@When[Windows_Foundation == "on"]
public interface IAsyncOperationWithProgress_Impl<TResult, TProgress> <: IAsyncInfo_Impl where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    public func SetProgress(handler: InParam<AsyncOperationProgressHandler<TResult, TProgress>>): windows_core.Result<Unit>
    public func Progress(): windows_core.Result<AsyncOperationProgressHandler<TResult, TProgress>>
    public func SetCompleted(handler: InParam<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>): windows_core.Result<Unit>
    public func Completed(): windows_core.Result<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>
    public func GetResults(): windows_core.Result<TResult>
}

@When[Windows_Foundation == "on"]
public class IAsyncOperationWithProgress<TResult, TProgress> <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where TResult <: windows_core.RuntimeType, TProgress <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAsyncOperationWithProgress<TResult, TProgress> {
        IAsyncOperationWithProgress<TResult, TProgress>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IAsyncOperationWithProgress<TResult, TProgress> {
        IAsyncOperationWithProgress<TResult, TProgress>(raw)
    }

    public static func iid(): GUID {
        return GUID(0xB5D036D7, 0xE297, 0x498F, 0xBA, 0x60, 0x02, 0x89, 0xE7, 0x6E, 0x23, 0xDD)
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
        var descriptor = InterfaceDescriptor<IAsyncOperationWithProgress<TResult, TProgress>>("IAsyncOperationWithProgress", IAsyncOperationWithProgress<TResult, TProgress>.iid(), IAsyncInfo.descriptor(), { raw => IAsyncOperationWithProgress<TResult, TProgress>.fromAbiTake(raw) }, { raw => IAsyncOperationWithProgress<TResult, TProgress>.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IAsyncOperationWithProgress<TResult, TProgress>.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IAsyncOperationWithProgress", IAsyncOperationWithProgress<TResult, TProgress>.iid(), IAsyncInfo.descriptorSchema(), "IAsyncOperationWithProgressVtbl", "IAsyncOperationWithProgress", "IAsyncOperationWithProgress_Impl", [InterfaceMethodSchema("SetProgress", 11, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncOperationProgressHandler<TResult, TProgress>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Progress", 12, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncOperationProgressHandler<TResult, TProgress>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("SetCompleted", 13, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>", InterfaceParameterBridgeKind.InParam)], "Int32"), InterfaceMethodSchema("Completed", 14, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<AsyncOperationWithProgressCompletedHandler<TResult, TProgress>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetResults", 15, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<TResult>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IAsyncOperationWithProgress<TResult, TProgress>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({B5D036D7-E297-498F-BA60-0289E76E23DD}")
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
        IAsyncInfo.viewOf(asRaw())
    }

    public unsafe func vtbl(): IAsyncOperationWithProgressVtbl {
        readVtbl<IAsyncOperationWithProgressVtbl>(IAsyncOperationWithProgressVtbl())
    }

    public unsafe func SetProgress(handler: AsyncOperationProgressHandler<TResult, TProgress>): Unit {
        let v = vtbl()
        let hr = v.SetProgress(asRaw(), handler.asRaw())
        HRESULT(hr).ok()
    }

    public unsafe func Progress(): AsyncOperationProgressHandler<TResult, TProgress> {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.Progress(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return AsyncOperationProgressHandler<TResult, TProgress>.fromAbiTake(result)
    }

    public unsafe func SetCompleted(handler: AsyncOperationWithProgressCompletedHandler<TResult, TProgress>): Unit {
        let v = vtbl()
        let hr = v.SetCompleted(asRaw(), handler.asRaw())
        HRESULT(hr).ok()
    }

    public unsafe func Completed(): AsyncOperationWithProgressCompletedHandler<TResult, TProgress> {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.Completed(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return AsyncOperationWithProgressCompletedHandler<TResult, TProgress>.fromAbiTake(result)
    }

    public unsafe func GetResults(): TResult {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.GetResults(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return result
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IClosableVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var Close: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IClosableVtbl where Identity <: IClosable_Impl {
        let _ = offset
        var vtbl = IClosableVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.Close = { instanceRaw =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Close()) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IClosable.iid()) {
            return true
        }
        return false
    }
}

@When[Windows_Foundation == "on"]
public interface IClosable_Impl {
    public func Close(): windows_core.Result<Unit>
}

@When[Windows_Foundation == "on"]
public class IClosable <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IClosable {
        IClosable(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IClosable {
        IClosable(raw)
    }

    public static func iid(): GUID {
        return GUID(0x30D5A829, 0x7FA4, 0x4026, 0x83, 0xBB, 0xD7, 0x5B, 0xAE, 0x4E, 0xA9, 0x9E)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IClosable.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IClosable> {
        var descriptor = InterfaceDescriptor<IClosable>("IClosable", IClosable.iid(), IInspectable.descriptor(), { raw => IClosable.fromAbiTake(raw) }, { raw => IClosable.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IClosable.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IClosable", IClosable.iid(), IInspectable.descriptorSchema(), "IClosableVtbl", "IClosable", "IClosable_Impl", [InterfaceMethodSchema("Close", 6, [], "Int32")])
        schema.runtimeTypeContract = Some(IClosable.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IClosable"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IClosable", IClosable.signature(), IClosable.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IClosableVtbl {
        readVtbl<IClosableVtbl>(IClosableVtbl())
    }

    public unsafe func Close(): Unit {
        let v = vtbl()
        let hr = v.Close(asRaw())
        HRESULT(hr).ok()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IDeferralVtbl {
    public var base_: IClosableVtbl = IClosableVtbl()
    public var Complete: CFunc<(CPointer<Unit>) -> Int32> = { _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IDeferral <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IDeferral {
        IDeferral(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IDeferral {
        IDeferral(raw)
    }

    public static func iid(): GUID {
        return GUID(0xD6269732, 0x3B7F, 0x46A7, 0xB4, 0x0B, 0x4F, 0xDC, 0xA2, 0xA2, 0xC6, 0x93)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IDeferral.iid()) {
            return true
        }
        for (ancestor in [IClosable.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IDeferral> {
        var descriptor = InterfaceDescriptor<IDeferral>("IDeferral", IDeferral.iid(), IClosable.descriptor(), { raw => IDeferral.fromAbiTake(raw) }, { raw => IDeferral.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IDeferral.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IDeferral", IDeferral.iid(), IClosable.descriptorSchema(), "IDeferralVtbl", "IDeferral", "IDeferral_Impl", [InterfaceMethodSchema("Complete", 7, [], "Int32")])
        schema.runtimeTypeContract = Some(IDeferral.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{D6269732-3B7F-46A7-B40B-4FDCA2A2C693}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IDeferral"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IDeferral", IDeferral.signature(), IDeferral.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIClosable(): IClosable {
        IClosable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IDeferralVtbl {
        readVtbl<IDeferralVtbl>(IDeferralVtbl())
    }

    public unsafe func Complete(): Unit {
        let v = vtbl()
        let hr = v.Complete(asRaw())
        HRESULT(hr).ok()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IDeferralFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var Create: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IDeferralFactory <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IDeferralFactory {
        IDeferralFactory(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IDeferralFactory {
        IDeferralFactory(raw)
    }

    public static func iid(): GUID {
        return GUID(0x65A1ECC5, 0x3FB5, 0x4832, 0x8C, 0xA9, 0xF0, 0x61, 0xB2, 0x81, 0xD1, 0x3A)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IDeferralFactory.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IDeferralFactory> {
        var descriptor = InterfaceDescriptor<IDeferralFactory>("IDeferralFactory", IDeferralFactory.iid(), IInspectable.descriptor(), { raw => IDeferralFactory.fromAbiTake(raw) }, { raw => IDeferralFactory.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IDeferralFactory.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IDeferralFactory", IDeferralFactory.iid(), IInspectable.descriptorSchema(), "IDeferralFactoryVtbl", "IDeferralFactory", "IDeferralFactory_Impl", [InterfaceMethodSchema("Create", 6, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<DeferralCompletedHandler>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<Deferral>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IDeferralFactory.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{65A1ECC5-3FB5-4832-8CA9-F061B281D13A}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IDeferralFactory"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IDeferralFactory", IDeferralFactory.signature(), IDeferralFactory.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IDeferralFactoryVtbl {
        readVtbl<IDeferralFactoryVtbl>(IDeferralFactoryVtbl())
    }

    public unsafe func Create(handler: DeferralCompletedHandler): Deferral {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.Create(asRaw(), handler.asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return Deferral.fromAbiTake(result)
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IGetActivationFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var GetActivationFactory: CFunc<(CPointer<Unit>, CPointer<UInt16>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IGetActivationFactoryVtbl where Identity <: IGetActivationFactory_Impl {
        let _ = offset
        var vtbl = IGetActivationFactoryVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.GetActivationFactory = { instanceRaw, arg0, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetActivationFactory(arg0)) {
                        case Result<IInspectable>.Ok(value) =>
                            let raw = value.intoAbi()
                            if (raw.isNull()) {
                                E_POINTER.value
                            } else {
                                unsafe { result__.write(raw) }
                                S_OK.value
                            }
                        case Result<IInspectable>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IGetActivationFactory.iid()) {
            return true
        }
        return false
    }
}

@When[Windows_Foundation == "on"]
public interface IGetActivationFactory_Impl {
    public func GetActivationFactory(activatableClassId: CPointer<UInt16>): windows_core.Result<IInspectable>
}

@When[Windows_Foundation == "on"]
public class IGetActivationFactory <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IGetActivationFactory {
        IGetActivationFactory(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IGetActivationFactory {
        IGetActivationFactory(raw)
    }

    public static func iid(): GUID {
        return GUID(0x4EDB8EE2, 0x96DD, 0x49A7, 0x94, 0xF7, 0x46, 0x07, 0xDD, 0xAB, 0x8E, 0x3C)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IGetActivationFactory.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IGetActivationFactory> {
        var descriptor = InterfaceDescriptor<IGetActivationFactory>("IGetActivationFactory", IGetActivationFactory.iid(), IInspectable.descriptor(), { raw => IGetActivationFactory.fromAbiTake(raw) }, { raw => IGetActivationFactory.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IGetActivationFactory.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IGetActivationFactory", IGetActivationFactory.iid(), IInspectable.descriptorSchema(), "IGetActivationFactoryVtbl", "IGetActivationFactory", "IGetActivationFactory_Impl", [InterfaceMethodSchema("GetActivationFactory", 6, [InterfaceParameterSchema("activatableClassId", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IGetActivationFactory.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{4EDB8EE2-96DD-49A7-94F7-4607DDAB8E3C}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IGetActivationFactory"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IGetActivationFactory", IGetActivationFactory.signature(), IGetActivationFactory.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IGetActivationFactoryVtbl {
        readVtbl<IGetActivationFactoryVtbl>(IGetActivationFactoryVtbl())
    }

    public unsafe func GetActivationFactory(activatableClassId: CPointer<UInt16>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.GetActivationFactory(asRaw(), activatableClassId, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IGuidHelperStaticsVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var CreateNewGuid: CFunc<(CPointer<Unit>, CPointer<GUID>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Empty: CFunc<(CPointer<Unit>, CPointer<GUID>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Equals: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<GUID>, CPointer<Bool>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IGuidHelperStatics <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IGuidHelperStatics {
        IGuidHelperStatics(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IGuidHelperStatics {
        IGuidHelperStatics(raw)
    }

    public static func iid(): GUID {
        return GUID(0x59C7966B, 0xAE52, 0x5283, 0xAD, 0x7F, 0xA1, 0xB9, 0xE9, 0x67, 0x8A, 0xDD)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IGuidHelperStatics.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IGuidHelperStatics> {
        var descriptor = InterfaceDescriptor<IGuidHelperStatics>("IGuidHelperStatics", IGuidHelperStatics.iid(), IInspectable.descriptor(), { raw => IGuidHelperStatics.fromAbiTake(raw) }, { raw => IGuidHelperStatics.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IGuidHelperStatics.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IGuidHelperStatics", IGuidHelperStatics.iid(), IInspectable.descriptorSchema(), "IGuidHelperStaticsVtbl", "IGuidHelperStatics", "IGuidHelperStatics_Impl", [InterfaceMethodSchema("CreateNewGuid", 6, [InterfaceParameterSchema("result", "CPointer<GUID>", "OutSlot<GUID>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Empty", 7, [InterfaceParameterSchema("result", "CPointer<GUID>", "OutSlot<GUID>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Equals", 8, [InterfaceParameterSchema("target", "CPointer<GUID>", "CPointer<GUID>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("value", "CPointer<GUID>", "CPointer<GUID>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<Bool>", "OutSlot<Bool>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IGuidHelperStatics.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{59C7966B-AE52-5283-AD7F-A1B9E9678ADD}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IGuidHelperStatics"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IGuidHelperStatics", IGuidHelperStatics.signature(), IGuidHelperStatics.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IGuidHelperStaticsVtbl {
        readVtbl<IGuidHelperStaticsVtbl>(IGuidHelperStaticsVtbl())
    }

    public unsafe func CreateNewGuid(): GUID {
        let v = vtbl()
        var result = GUID()
        let hr = v.CreateNewGuid(asRaw(), CPointer<GUID>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Empty(): GUID {
        let v = vtbl()
        var result = GUID()
        let hr = v.Empty(asRaw(), CPointer<GUID>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Equals(target: CPointer<GUID>, value: CPointer<GUID>): Bool {
        let v = vtbl()
        var result = false
        let hr = v.Equals(asRaw(), target, value, CPointer<Bool>(inout result))
        HRESULT(hr).ok()
        return result
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IMemoryBufferVtbl {
    public var base_: IClosableVtbl = IClosableVtbl()
    public var CreateReference: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IMemoryBufferVtbl where Identity <: IMemoryBuffer_Impl {
        let _ = offset
        var vtbl = IMemoryBufferVtbl()
        vtbl.base_ = IClosableVtbl.new<Identity>(offset: offset)
        vtbl.CreateReference = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.CreateReference()) {
                        case Result<IMemoryBufferReference>.Ok(value) =>
                            let raw = value.intoAbi()
                            if (raw.isNull()) {
                                E_POINTER.value
                            } else {
                                unsafe { result__.write(raw) }
                                S_OK.value
                            }
                        case Result<IMemoryBufferReference>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IMemoryBuffer.iid()) {
            return true
        }
        for (ancestor in [IClosable.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }
}

@When[Windows_Foundation == "on"]
public interface IMemoryBuffer_Impl <: IClosable_Impl {
    public func CreateReference(): windows_core.Result<IMemoryBufferReference>
}

@When[Windows_Foundation == "on"]
public class IMemoryBuffer <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IMemoryBuffer {
        IMemoryBuffer(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IMemoryBuffer {
        IMemoryBuffer(raw)
    }

    public static func iid(): GUID {
        return GUID(0xFBC4DD2A, 0x245B, 0x11E4, 0xAF, 0x98, 0x68, 0x94, 0x23, 0x26, 0x0C, 0xF8)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IMemoryBuffer.iid()) {
            return true
        }
        for (ancestor in [IClosable.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IMemoryBuffer> {
        var descriptor = InterfaceDescriptor<IMemoryBuffer>("IMemoryBuffer", IMemoryBuffer.iid(), IClosable.descriptor(), { raw => IMemoryBuffer.fromAbiTake(raw) }, { raw => IMemoryBuffer.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IMemoryBuffer.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IMemoryBuffer", IMemoryBuffer.iid(), IClosable.descriptorSchema(), "IMemoryBufferVtbl", "IMemoryBuffer", "IMemoryBuffer_Impl", [InterfaceMethodSchema("CreateReference", 7, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IMemoryBufferReference>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IMemoryBuffer.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{FBC4DD2A-245B-11E4-AF98-689423260CF8}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IMemoryBuffer"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IMemoryBuffer", IMemoryBuffer.signature(), IMemoryBuffer.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIClosable(): IClosable {
        IClosable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IMemoryBufferVtbl {
        readVtbl<IMemoryBufferVtbl>(IMemoryBufferVtbl())
    }

    public unsafe func CreateReference(): IMemoryBufferReference {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateReference(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IMemoryBufferReference.fromAbiTake(result)
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IMemoryBufferFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var Create: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IMemoryBufferFactory <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IMemoryBufferFactory {
        IMemoryBufferFactory(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IMemoryBufferFactory {
        IMemoryBufferFactory(raw)
    }

    public static func iid(): GUID {
        return GUID(0xFBC4DD2B, 0x245B, 0x11E4, 0xAF, 0x98, 0x68, 0x94, 0x23, 0x26, 0x0C, 0xF8)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IMemoryBufferFactory.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IMemoryBufferFactory> {
        var descriptor = InterfaceDescriptor<IMemoryBufferFactory>("IMemoryBufferFactory", IMemoryBufferFactory.iid(), IInspectable.descriptor(), { raw => IMemoryBufferFactory.fromAbiTake(raw) }, { raw => IMemoryBufferFactory.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IMemoryBufferFactory.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IMemoryBufferFactory", IMemoryBufferFactory.iid(), IInspectable.descriptorSchema(), "IMemoryBufferFactoryVtbl", "IMemoryBufferFactory", "IMemoryBufferFactory_Impl", [InterfaceMethodSchema("Create", 6, [InterfaceParameterSchema("capacity", "UInt32", "UInt32", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<MemoryBuffer>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IMemoryBufferFactory.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{FBC4DD2B-245B-11E4-AF98-689423260CF8}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IMemoryBufferFactory"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IMemoryBufferFactory", IMemoryBufferFactory.signature(), IMemoryBufferFactory.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IMemoryBufferFactoryVtbl {
        readVtbl<IMemoryBufferFactoryVtbl>(IMemoryBufferFactoryVtbl())
    }

    public unsafe func Create(capacity: UInt32): MemoryBuffer {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.Create(asRaw(), capacity, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return MemoryBuffer.fromAbiTake(result)
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IMemoryBufferReferenceVtbl {
    public var base_: IClosableVtbl = IClosableVtbl()
    public var Capacity: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Closed: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<EventRegistrationToken>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var RemoveClosed: CFunc<(CPointer<Unit>, EventRegistrationToken) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IMemoryBufferReferenceVtbl where Identity <: IMemoryBufferReference_Impl {
        let _ = offset
        var vtbl = IMemoryBufferReferenceVtbl()
        vtbl.base_ = IClosableVtbl.new<Identity>(offset: offset)
        vtbl.Capacity = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Capacity()) {
                        case Result<UInt32>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<UInt32>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Closed = { instanceRaw, arg0, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Closed(InParam<TypedEventHandler<IMemoryBufferReference, IInspectable>>(TypedEventHandler<IMemoryBufferReference, IInspectable>.viewOf(arg0)))) {
                        case Result<EventRegistrationToken>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<EventRegistrationToken>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.RemoveClosed = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.RemoveClosed(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IMemoryBufferReference.iid()) {
            return true
        }
        for (ancestor in [IClosable.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }
}

@When[Windows_Foundation == "on"]
public interface IMemoryBufferReference_Impl <: IClosable_Impl {
    public func Capacity(): windows_core.Result<UInt32>
    public func Closed(handler: InParam<TypedEventHandler<IMemoryBufferReference, IInspectable>>): windows_core.Result<EventRegistrationToken>
    public func RemoveClosed(cookie: EventRegistrationToken): windows_core.Result<Unit>
}

@When[Windows_Foundation == "on"]
public class IMemoryBufferReference <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IMemoryBufferReference {
        IMemoryBufferReference(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IMemoryBufferReference {
        IMemoryBufferReference(raw)
    }

    public static func iid(): GUID {
        return GUID(0xFBC4DD29, 0x245B, 0x11E4, 0xAF, 0x98, 0x68, 0x94, 0x23, 0x26, 0x0C, 0xF8)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IMemoryBufferReference.iid()) {
            return true
        }
        for (ancestor in [IClosable.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IMemoryBufferReference> {
        var descriptor = InterfaceDescriptor<IMemoryBufferReference>("IMemoryBufferReference", IMemoryBufferReference.iid(), IClosable.descriptor(), { raw => IMemoryBufferReference.fromAbiTake(raw) }, { raw => IMemoryBufferReference.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IMemoryBufferReference.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IMemoryBufferReference", IMemoryBufferReference.iid(), IClosable.descriptorSchema(), "IMemoryBufferReferenceVtbl", "IMemoryBufferReference", "IMemoryBufferReference_Impl", [InterfaceMethodSchema("Capacity", 7, [InterfaceParameterSchema("result", "CPointer<UInt32>", "OutSlot<UInt32>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Closed", 8, [InterfaceParameterSchema("handler", "CPointer<Unit>", "InParam<TypedEventHandler<IMemoryBufferReference, IInspectable>>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("result", "CPointer<EventRegistrationToken>", "OutSlot<EventRegistrationToken>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("RemoveClosed", 9, [InterfaceParameterSchema("cookie", "EventRegistrationToken", "EventRegistrationToken", InterfaceParameterBridgeKind.Value)], "Int32")])
        schema.runtimeTypeContract = Some(IMemoryBufferReference.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{FBC4DD29-245B-11E4-AF98-689423260CF8}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IMemoryBufferReference"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IMemoryBufferReference", IMemoryBufferReference.signature(), IMemoryBufferReference.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIClosable(): IClosable {
        IClosable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IMemoryBufferReferenceVtbl {
        readVtbl<IMemoryBufferReferenceVtbl>(IMemoryBufferReferenceVtbl())
    }

    public unsafe func Capacity(): UInt32 {
        let v = vtbl()
        var result = 0
        let hr = v.Capacity(asRaw(), CPointer<UInt32>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Closed(handler: TypedEventHandler<IMemoryBufferReference, IInspectable>): EventRegistrationToken {
        let v = vtbl()
        var result = EventRegistrationToken()
        let hr = v.Closed(asRaw(), handler.asRaw(), CPointer<EventRegistrationToken>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func RemoveClosed(cookie: EventRegistrationToken): Unit {
        let v = vtbl()
        let hr = v.RemoveClosed(asRaw(), cookie)
        HRESULT(hr).ok()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IPropertyValueVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var Type: CFunc<(CPointer<Unit>, CPointer<PropertyType>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var IsNumericScalar: CFunc<(CPointer<Unit>, CPointer<Bool>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetUInt8: CFunc<(CPointer<Unit>, CPointer<UInt8>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetInt16: CFunc<(CPointer<Unit>, CPointer<Int16>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetUInt16: CFunc<(CPointer<Unit>, CPointer<UInt16>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetInt32: CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetUInt32: CFunc<(CPointer<Unit>, CPointer<UInt32>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetInt64: CFunc<(CPointer<Unit>, CPointer<Int64>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetUInt64: CFunc<(CPointer<Unit>, CPointer<UInt64>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetSingle: CFunc<(CPointer<Unit>, CPointer<Float32>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetDouble: CFunc<(CPointer<Unit>, CPointer<Float64>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetChar16: CFunc<(CPointer<Unit>, CPointer<UInt16>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetBoolean: CFunc<(CPointer<Unit>, CPointer<Bool>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetString: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetGuid: CFunc<(CPointer<Unit>, CPointer<GUID>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetDateTime: CFunc<(CPointer<Unit>, CPointer<DateTime>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetTimeSpan: CFunc<(CPointer<Unit>, CPointer<TimeSpan>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetPoint: CFunc<(CPointer<Unit>, CPointer<Point>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetSize: CFunc<(CPointer<Unit>, CPointer<Size>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetRect: CFunc<(CPointer<Unit>, CPointer<Rect>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetUInt8Array: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt8>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetInt16Array: CFunc<(CPointer<Unit>, CPointer<CPointer<Int16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetUInt16Array: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetInt32Array: CFunc<(CPointer<Unit>, CPointer<CPointer<Int32>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetUInt32Array: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt32>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetInt64Array: CFunc<(CPointer<Unit>, CPointer<CPointer<Int64>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetUInt64Array: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt64>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetSingleArray: CFunc<(CPointer<Unit>, CPointer<CPointer<Float32>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetDoubleArray: CFunc<(CPointer<Unit>, CPointer<CPointer<Float64>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetChar16Array: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetBooleanArray: CFunc<(CPointer<Unit>, CPointer<CPointer<Bool>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetStringArray: CFunc<(CPointer<Unit>, CPointer<CPointer<CPointer<UInt16>>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetInspectableArray: CFunc<(CPointer<Unit>, CPointer<CPointer<CPointer<Unit>>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetGuidArray: CFunc<(CPointer<Unit>, CPointer<CPointer<GUID>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetDateTimeArray: CFunc<(CPointer<Unit>, CPointer<CPointer<DateTime>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetTimeSpanArray: CFunc<(CPointer<Unit>, CPointer<CPointer<TimeSpan>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetPointArray: CFunc<(CPointer<Unit>, CPointer<CPointer<Point>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetSizeArray: CFunc<(CPointer<Unit>, CPointer<CPointer<Size>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var GetRectArray: CFunc<(CPointer<Unit>, CPointer<CPointer<Rect>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IPropertyValueVtbl where Identity <: IPropertyValue_Impl {
        let _ = offset
        var vtbl = IPropertyValueVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.Type = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Type()) {
                        case Result<PropertyType>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<PropertyType>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.IsNumericScalar = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.IsNumericScalar()) {
                        case Result<Bool>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Bool>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetUInt8 = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetUInt8()) {
                        case Result<UInt8>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<UInt8>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetInt16 = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetInt16()) {
                        case Result<Int16>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Int16>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetUInt16 = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetUInt16()) {
                        case Result<UInt16>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<UInt16>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetInt32 = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetInt32()) {
                        case Result<Int32>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Int32>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetUInt32 = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetUInt32()) {
                        case Result<UInt32>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<UInt32>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetInt64 = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetInt64()) {
                        case Result<Int64>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Int64>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetUInt64 = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetUInt64()) {
                        case Result<UInt64>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<UInt64>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetSingle = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetSingle()) {
                        case Result<Float32>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Float32>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetDouble = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetDouble()) {
                        case Result<Float64>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Float64>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetChar16 = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetChar16()) {
                        case Result<UInt16>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<UInt16>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetBoolean = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetBoolean()) {
                        case Result<Bool>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Bool>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetString = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetString()) {
                        case Result<CPointer<UInt16>>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<CPointer<UInt16>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetGuid = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetGuid()) {
                        case Result<GUID>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<GUID>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetDateTime = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetDateTime()) {
                        case Result<DateTime>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<DateTime>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetTimeSpan = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetTimeSpan()) {
                        case Result<TimeSpan>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<TimeSpan>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetPoint = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetPoint()) {
                        case Result<Point>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Point>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetSize = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetSize()) {
                        case Result<Size>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Size>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetRect = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetRect()) {
                        case Result<Rect>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<Rect>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetUInt8Array = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetUInt8Array(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetInt16Array = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetInt16Array(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetUInt16Array = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetUInt16Array(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetInt32Array = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetInt32Array(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetUInt32Array = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetUInt32Array(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetInt64Array = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetInt64Array(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetUInt64Array = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetUInt64Array(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetSingleArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetSingleArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetDoubleArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetDoubleArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetChar16Array = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetChar16Array(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetBooleanArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetBooleanArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetStringArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetStringArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetInspectableArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetInspectableArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetGuidArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetGuidArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetDateTimeArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetDateTimeArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetTimeSpanArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetTimeSpanArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetPointArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetPointArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetSizeArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetSizeArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.GetRectArray = { instanceRaw, arg0 =>
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.GetRectArray(arg0)) {
                        case Result<Unit>.Ok(_) =>
                            S_OK.value
                        case Result<Unit>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IPropertyValue.iid()) {
            return true
        }
        return false
    }
}

@When[Windows_Foundation == "on"]
public interface IPropertyValue_Impl {
    public func Type(): windows_core.Result<PropertyType>
    public func IsNumericScalar(): windows_core.Result<Bool>
    public func GetUInt8(): windows_core.Result<UInt8>
    public func GetInt16(): windows_core.Result<Int16>
    public func GetUInt16(): windows_core.Result<UInt16>
    public func GetInt32(): windows_core.Result<Int32>
    public func GetUInt32(): windows_core.Result<UInt32>
    public func GetInt64(): windows_core.Result<Int64>
    public func GetUInt64(): windows_core.Result<UInt64>
    public func GetSingle(): windows_core.Result<Float32>
    public func GetDouble(): windows_core.Result<Float64>
    public func GetChar16(): windows_core.Result<UInt16>
    public func GetBoolean(): windows_core.Result<Bool>
    public func GetString(): windows_core.Result<CPointer<UInt16>>
    public func GetGuid(): windows_core.Result<GUID>
    public func GetDateTime(): windows_core.Result<DateTime>
    public func GetTimeSpan(): windows_core.Result<TimeSpan>
    public func GetPoint(): windows_core.Result<Point>
    public func GetSize(): windows_core.Result<Size>
    public func GetRect(): windows_core.Result<Rect>
    public func GetUInt8Array(value: CPointer<CPointer<UInt8>>): windows_core.Result<Unit>
    public func GetInt16Array(value: CPointer<CPointer<Int16>>): windows_core.Result<Unit>
    public func GetUInt16Array(value: CPointer<CPointer<UInt16>>): windows_core.Result<Unit>
    public func GetInt32Array(value: CPointer<CPointer<Int32>>): windows_core.Result<Unit>
    public func GetUInt32Array(value: CPointer<CPointer<UInt32>>): windows_core.Result<Unit>
    public func GetInt64Array(value: CPointer<CPointer<Int64>>): windows_core.Result<Unit>
    public func GetUInt64Array(value: CPointer<CPointer<UInt64>>): windows_core.Result<Unit>
    public func GetSingleArray(value: CPointer<CPointer<Float32>>): windows_core.Result<Unit>
    public func GetDoubleArray(value: CPointer<CPointer<Float64>>): windows_core.Result<Unit>
    public func GetChar16Array(value: CPointer<CPointer<UInt16>>): windows_core.Result<Unit>
    public func GetBooleanArray(value: CPointer<CPointer<Bool>>): windows_core.Result<Unit>
    public func GetStringArray(value: CPointer<CPointer<CPointer<UInt16>>>): windows_core.Result<Unit>
    public func GetInspectableArray(value: CPointer<CPointer<CPointer<Unit>>>): windows_core.Result<Unit>
    public func GetGuidArray(value: CPointer<CPointer<GUID>>): windows_core.Result<Unit>
    public func GetDateTimeArray(value: CPointer<CPointer<DateTime>>): windows_core.Result<Unit>
    public func GetTimeSpanArray(value: CPointer<CPointer<TimeSpan>>): windows_core.Result<Unit>
    public func GetPointArray(value: CPointer<CPointer<Point>>): windows_core.Result<Unit>
    public func GetSizeArray(value: CPointer<CPointer<Size>>): windows_core.Result<Unit>
    public func GetRectArray(value: CPointer<CPointer<Rect>>): windows_core.Result<Unit>
}

@When[Windows_Foundation == "on"]
public class IPropertyValue <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IPropertyValue {
        IPropertyValue(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IPropertyValue {
        IPropertyValue(raw)
    }

    public static func iid(): GUID {
        return GUID(0x4BD682DD, 0x7554, 0x40E9, 0x9A, 0x9B, 0x82, 0x65, 0x4E, 0xDE, 0x7E, 0x62)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IPropertyValue.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IPropertyValue> {
        var descriptor = InterfaceDescriptor<IPropertyValue>("IPropertyValue", IPropertyValue.iid(), IInspectable.descriptor(), { raw => IPropertyValue.fromAbiTake(raw) }, { raw => IPropertyValue.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IPropertyValue.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IPropertyValue", IPropertyValue.iid(), IInspectable.descriptorSchema(), "IPropertyValueVtbl", "IPropertyValue", "IPropertyValue_Impl", [InterfaceMethodSchema("Type", 6, [InterfaceParameterSchema("result", "CPointer<PropertyType>", "OutSlot<PropertyType>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("IsNumericScalar", 7, [InterfaceParameterSchema("result", "CPointer<Bool>", "OutSlot<Bool>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetUInt8", 8, [InterfaceParameterSchema("result", "CPointer<UInt8>", "OutSlot<UInt8>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetInt16", 9, [InterfaceParameterSchema("result", "CPointer<Int16>", "OutSlot<Int16>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetUInt16", 10, [InterfaceParameterSchema("result", "CPointer<UInt16>", "OutSlot<UInt16>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetInt32", 11, [InterfaceParameterSchema("result", "CPointer<Int32>", "OutSlot<Int32>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetUInt32", 12, [InterfaceParameterSchema("result", "CPointer<UInt32>", "OutSlot<UInt32>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetInt64", 13, [InterfaceParameterSchema("result", "CPointer<Int64>", "OutSlot<Int64>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetUInt64", 14, [InterfaceParameterSchema("result", "CPointer<UInt64>", "OutSlot<UInt64>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetSingle", 15, [InterfaceParameterSchema("result", "CPointer<Float32>", "OutSlot<Float32>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetDouble", 16, [InterfaceParameterSchema("result", "CPointer<Float64>", "OutSlot<Float64>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetChar16", 17, [InterfaceParameterSchema("result", "CPointer<UInt16>", "OutSlot<UInt16>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetBoolean", 18, [InterfaceParameterSchema("result", "CPointer<Bool>", "OutSlot<Bool>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetString", 19, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetGuid", 20, [InterfaceParameterSchema("result", "CPointer<GUID>", "OutSlot<GUID>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetDateTime", 21, [InterfaceParameterSchema("result", "CPointer<DateTime>", "OutSlot<DateTime>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetTimeSpan", 22, [InterfaceParameterSchema("result", "CPointer<TimeSpan>", "OutSlot<TimeSpan>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetPoint", 23, [InterfaceParameterSchema("result", "CPointer<Point>", "OutSlot<Point>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetSize", 24, [InterfaceParameterSchema("result", "CPointer<Size>", "OutSlot<Size>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetRect", 25, [InterfaceParameterSchema("result", "CPointer<Rect>", "OutSlot<Rect>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("GetUInt8Array", 26, [InterfaceParameterSchema("value", "CPointer<CPointer<UInt8>>", "CPointer<CPointer<UInt8>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetInt16Array", 27, [InterfaceParameterSchema("value", "CPointer<CPointer<Int16>>", "CPointer<CPointer<Int16>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetUInt16Array", 28, [InterfaceParameterSchema("value", "CPointer<CPointer<UInt16>>", "CPointer<CPointer<UInt16>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetInt32Array", 29, [InterfaceParameterSchema("value", "CPointer<CPointer<Int32>>", "CPointer<CPointer<Int32>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetUInt32Array", 30, [InterfaceParameterSchema("value", "CPointer<CPointer<UInt32>>", "CPointer<CPointer<UInt32>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetInt64Array", 31, [InterfaceParameterSchema("value", "CPointer<CPointer<Int64>>", "CPointer<CPointer<Int64>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetUInt64Array", 32, [InterfaceParameterSchema("value", "CPointer<CPointer<UInt64>>", "CPointer<CPointer<UInt64>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetSingleArray", 33, [InterfaceParameterSchema("value", "CPointer<CPointer<Float32>>", "CPointer<CPointer<Float32>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetDoubleArray", 34, [InterfaceParameterSchema("value", "CPointer<CPointer<Float64>>", "CPointer<CPointer<Float64>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetChar16Array", 35, [InterfaceParameterSchema("value", "CPointer<CPointer<UInt16>>", "CPointer<CPointer<UInt16>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetBooleanArray", 36, [InterfaceParameterSchema("value", "CPointer<CPointer<Bool>>", "CPointer<CPointer<Bool>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetStringArray", 37, [InterfaceParameterSchema("value", "CPointer<CPointer<CPointer<UInt16>>>", "CPointer<CPointer<CPointer<UInt16>>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetInspectableArray", 38, [InterfaceParameterSchema("value", "CPointer<CPointer<CPointer<Unit>>>", "CPointer<CPointer<CPointer<Unit>>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetGuidArray", 39, [InterfaceParameterSchema("value", "CPointer<CPointer<GUID>>", "CPointer<CPointer<GUID>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetDateTimeArray", 40, [InterfaceParameterSchema("value", "CPointer<CPointer<DateTime>>", "CPointer<CPointer<DateTime>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetTimeSpanArray", 41, [InterfaceParameterSchema("value", "CPointer<CPointer<TimeSpan>>", "CPointer<CPointer<TimeSpan>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetPointArray", 42, [InterfaceParameterSchema("value", "CPointer<CPointer<Point>>", "CPointer<CPointer<Point>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetSizeArray", 43, [InterfaceParameterSchema("value", "CPointer<CPointer<Size>>", "CPointer<CPointer<Size>>", InterfaceParameterBridgeKind.Value)], "Int32"), InterfaceMethodSchema("GetRectArray", 44, [InterfaceParameterSchema("value", "CPointer<CPointer<Rect>>", "CPointer<CPointer<Rect>>", InterfaceParameterBridgeKind.Value)], "Int32")])
        schema.runtimeTypeContract = Some(IPropertyValue.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{4BD682DD-7554-40E9-9A9B-82654EDE7E62}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IPropertyValue"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IPropertyValue", IPropertyValue.signature(), IPropertyValue.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IPropertyValueVtbl {
        readVtbl<IPropertyValueVtbl>(IPropertyValueVtbl())
    }

    public unsafe func Type(): PropertyType {
        let v = vtbl()
        var result = PropertyType()
        let hr = v.Type(asRaw(), CPointer<PropertyType>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func IsNumericScalar(): Bool {
        let v = vtbl()
        var result = false
        let hr = v.IsNumericScalar(asRaw(), CPointer<Bool>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetUInt8(): UInt8 {
        let v = vtbl()
        var result = 0
        let hr = v.GetUInt8(asRaw(), CPointer<UInt8>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetInt16(): Int16 {
        let v = vtbl()
        var result = 0
        let hr = v.GetInt16(asRaw(), CPointer<Int16>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetUInt16(): UInt16 {
        let v = vtbl()
        var result = 0
        let hr = v.GetUInt16(asRaw(), CPointer<UInt16>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetInt32(): Int32 {
        let v = vtbl()
        var result = 0
        let hr = v.GetInt32(asRaw(), CPointer<Int32>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetUInt32(): UInt32 {
        let v = vtbl()
        var result = 0
        let hr = v.GetUInt32(asRaw(), CPointer<UInt32>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetInt64(): Int64 {
        let v = vtbl()
        var result = 0
        let hr = v.GetInt64(asRaw(), CPointer<Int64>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetUInt64(): UInt64 {
        let v = vtbl()
        var result = 0
        let hr = v.GetUInt64(asRaw(), CPointer<UInt64>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetSingle(): Float32 {
        let v = vtbl()
        var result = 0.0f32
        let hr = v.GetSingle(asRaw(), CPointer<Float32>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetDouble(): Float64 {
        let v = vtbl()
        var result = 0.0f64
        let hr = v.GetDouble(asRaw(), CPointer<Float64>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetChar16(): UInt16 {
        let v = vtbl()
        var result = 0
        let hr = v.GetChar16(asRaw(), CPointer<UInt16>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetBoolean(): Bool {
        let v = vtbl()
        var result = false
        let hr = v.GetBoolean(asRaw(), CPointer<Bool>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetString(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.GetString(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetGuid(): GUID {
        let v = vtbl()
        var result = GUID()
        let hr = v.GetGuid(asRaw(), CPointer<GUID>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetDateTime(): DateTime {
        let v = vtbl()
        var result = DateTime()
        let hr = v.GetDateTime(asRaw(), CPointer<DateTime>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetTimeSpan(): TimeSpan {
        let v = vtbl()
        var result = TimeSpan()
        let hr = v.GetTimeSpan(asRaw(), CPointer<TimeSpan>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetPoint(): Point {
        let v = vtbl()
        var result = Point()
        let hr = v.GetPoint(asRaw(), CPointer<Point>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetSize(): Size {
        let v = vtbl()
        var result = Size()
        let hr = v.GetSize(asRaw(), CPointer<Size>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetRect(): Rect {
        let v = vtbl()
        var result = Rect()
        let hr = v.GetRect(asRaw(), CPointer<Rect>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func GetUInt8Array(value: CPointer<CPointer<UInt8>>): Unit {
        let v = vtbl()
        let hr = v.GetUInt8Array(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetInt16Array(value: CPointer<CPointer<Int16>>): Unit {
        let v = vtbl()
        let hr = v.GetInt16Array(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetUInt16Array(value: CPointer<CPointer<UInt16>>): Unit {
        let v = vtbl()
        let hr = v.GetUInt16Array(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetInt32Array(value: CPointer<CPointer<Int32>>): Unit {
        let v = vtbl()
        let hr = v.GetInt32Array(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetUInt32Array(value: CPointer<CPointer<UInt32>>): Unit {
        let v = vtbl()
        let hr = v.GetUInt32Array(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetInt64Array(value: CPointer<CPointer<Int64>>): Unit {
        let v = vtbl()
        let hr = v.GetInt64Array(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetUInt64Array(value: CPointer<CPointer<UInt64>>): Unit {
        let v = vtbl()
        let hr = v.GetUInt64Array(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetSingleArray(value: CPointer<CPointer<Float32>>): Unit {
        let v = vtbl()
        let hr = v.GetSingleArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetDoubleArray(value: CPointer<CPointer<Float64>>): Unit {
        let v = vtbl()
        let hr = v.GetDoubleArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetChar16Array(value: CPointer<CPointer<UInt16>>): Unit {
        let v = vtbl()
        let hr = v.GetChar16Array(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetBooleanArray(value: CPointer<CPointer<Bool>>): Unit {
        let v = vtbl()
        let hr = v.GetBooleanArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetStringArray(value: CPointer<CPointer<CPointer<UInt16>>>): Unit {
        let v = vtbl()
        let hr = v.GetStringArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetInspectableArray(value: CPointer<CPointer<CPointer<Unit>>>): Unit {
        let v = vtbl()
        let hr = v.GetInspectableArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetGuidArray(value: CPointer<CPointer<GUID>>): Unit {
        let v = vtbl()
        let hr = v.GetGuidArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetDateTimeArray(value: CPointer<CPointer<DateTime>>): Unit {
        let v = vtbl()
        let hr = v.GetDateTimeArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetTimeSpanArray(value: CPointer<CPointer<TimeSpan>>): Unit {
        let v = vtbl()
        let hr = v.GetTimeSpanArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetPointArray(value: CPointer<CPointer<Point>>): Unit {
        let v = vtbl()
        let hr = v.GetPointArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetSizeArray(value: CPointer<CPointer<Size>>): Unit {
        let v = vtbl()
        let hr = v.GetSizeArray(asRaw(), value)
        HRESULT(hr).ok()
    }

    public unsafe func GetRectArray(value: CPointer<CPointer<Rect>>): Unit {
        let v = vtbl()
        let hr = v.GetRectArray(asRaw(), value)
        HRESULT(hr).ok()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IPropertyValueStaticsVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var CreateEmpty: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var CreateUInt8: CFunc<(CPointer<Unit>, UInt8, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateInt16: CFunc<(CPointer<Unit>, Int16, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateUInt16: CFunc<(CPointer<Unit>, UInt16, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateInt32: CFunc<(CPointer<Unit>, Int32, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateUInt32: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateInt64: CFunc<(CPointer<Unit>, Int64, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateUInt64: CFunc<(CPointer<Unit>, UInt64, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateSingle: CFunc<(CPointer<Unit>, Float32, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateDouble: CFunc<(CPointer<Unit>, Float64, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateChar16: CFunc<(CPointer<Unit>, UInt16, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateBoolean: CFunc<(CPointer<Unit>, Bool, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateString: CFunc<(CPointer<Unit>, CPointer<UInt16>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateInspectable: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateGuid: CFunc<(CPointer<Unit>, GUID, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateDateTime: CFunc<(CPointer<Unit>, DateTime, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateTimeSpan: CFunc<(CPointer<Unit>, TimeSpan, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreatePoint: CFunc<(CPointer<Unit>, Point, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateSize: CFunc<(CPointer<Unit>, Size, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateRect: CFunc<(CPointer<Unit>, Rect, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateUInt8Array: CFunc<(CPointer<Unit>, UInt32, CPointer<UInt8>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateInt16Array: CFunc<(CPointer<Unit>, UInt32, CPointer<Int16>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateUInt16Array: CFunc<(CPointer<Unit>, UInt32, CPointer<UInt16>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateInt32Array: CFunc<(CPointer<Unit>, UInt32, CPointer<Int32>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateUInt32Array: CFunc<(CPointer<Unit>, UInt32, CPointer<UInt32>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateInt64Array: CFunc<(CPointer<Unit>, UInt32, CPointer<Int64>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateUInt64Array: CFunc<(CPointer<Unit>, UInt32, CPointer<UInt64>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateSingleArray: CFunc<(CPointer<Unit>, UInt32, CPointer<Float32>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateDoubleArray: CFunc<(CPointer<Unit>, UInt32, CPointer<Float64>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateChar16Array: CFunc<(CPointer<Unit>, UInt32, CPointer<UInt16>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateBooleanArray: CFunc<(CPointer<Unit>, UInt32, CPointer<Bool>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateStringArray: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<UInt16>>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateInspectableArray: CFunc<(CPointer<Unit>, UInt32, CPointer<CPointer<Unit>>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateGuidArray: CFunc<(CPointer<Unit>, UInt32, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateDateTimeArray: CFunc<(CPointer<Unit>, UInt32, CPointer<DateTime>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateTimeSpanArray: CFunc<(CPointer<Unit>, UInt32, CPointer<TimeSpan>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreatePointArray: CFunc<(CPointer<Unit>, UInt32, CPointer<Point>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateSizeArray: CFunc<(CPointer<Unit>, UInt32, CPointer<Size>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var CreateRectArray: CFunc<(CPointer<Unit>, UInt32, CPointer<Rect>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IPropertyValueStatics <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IPropertyValueStatics {
        IPropertyValueStatics(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IPropertyValueStatics {
        IPropertyValueStatics(raw)
    }

    public static func iid(): GUID {
        return GUID(0x629BDBC8, 0xD932, 0x4FF4, 0x96, 0xB9, 0x8D, 0x96, 0xC5, 0xC1, 0xE8, 0x58)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IPropertyValueStatics.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IPropertyValueStatics> {
        var descriptor = InterfaceDescriptor<IPropertyValueStatics>("IPropertyValueStatics", IPropertyValueStatics.iid(), IInspectable.descriptor(), { raw => IPropertyValueStatics.fromAbiTake(raw) }, { raw => IPropertyValueStatics.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IPropertyValueStatics.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IPropertyValueStatics", IPropertyValueStatics.iid(), IInspectable.descriptorSchema(), "IPropertyValueStaticsVtbl", "IPropertyValueStatics", "IPropertyValueStatics_Impl", [InterfaceMethodSchema("CreateEmpty", 6, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateUInt8", 7, [InterfaceParameterSchema("value", "UInt8", "UInt8", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateInt16", 8, [InterfaceParameterSchema("value", "Int16", "Int16", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateUInt16", 9, [InterfaceParameterSchema("value", "UInt16", "UInt16", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateInt32", 10, [InterfaceParameterSchema("value", "Int32", "Int32", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateUInt32", 11, [InterfaceParameterSchema("value", "UInt32", "UInt32", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateInt64", 12, [InterfaceParameterSchema("value", "Int64", "Int64", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateUInt64", 13, [InterfaceParameterSchema("value", "UInt64", "UInt64", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateSingle", 14, [InterfaceParameterSchema("value", "Float32", "Float32", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateDouble", 15, [InterfaceParameterSchema("value", "Float64", "Float64", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateChar16", 16, [InterfaceParameterSchema("value", "UInt16", "UInt16", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateBoolean", 17, [InterfaceParameterSchema("value", "Bool", "Bool", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateString", 18, [InterfaceParameterSchema("value", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateInspectable", 19, [InterfaceParameterSchema("value", "CPointer<Unit>", "InParam<IInspectable>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateGuid", 20, [InterfaceParameterSchema("value", "GUID", "GUID", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateDateTime", 21, [InterfaceParameterSchema("value", "DateTime", "DateTime", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateTimeSpan", 22, [InterfaceParameterSchema("value", "TimeSpan", "TimeSpan", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreatePoint", 23, [InterfaceParameterSchema("value", "Point", "Point", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateSize", 24, [InterfaceParameterSchema("value", "Size", "Size", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateRect", 25, [InterfaceParameterSchema("value", "Rect", "Rect", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateUInt8Array", 26, [InterfaceParameterSchema("value", "CPointer<UInt8>", "CPointer<UInt8>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateInt16Array", 27, [InterfaceParameterSchema("value", "CPointer<Int16>", "CPointer<Int16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateUInt16Array", 28, [InterfaceParameterSchema("value", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateInt32Array", 29, [InterfaceParameterSchema("value", "CPointer<Int32>", "CPointer<Int32>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateUInt32Array", 30, [InterfaceParameterSchema("value", "CPointer<UInt32>", "CPointer<UInt32>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateInt64Array", 31, [InterfaceParameterSchema("value", "CPointer<Int64>", "CPointer<Int64>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateUInt64Array", 32, [InterfaceParameterSchema("value", "CPointer<UInt64>", "CPointer<UInt64>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateSingleArray", 33, [InterfaceParameterSchema("value", "CPointer<Float32>", "CPointer<Float32>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateDoubleArray", 34, [InterfaceParameterSchema("value", "CPointer<Float64>", "CPointer<Float64>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateChar16Array", 35, [InterfaceParameterSchema("value", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateBooleanArray", 36, [InterfaceParameterSchema("value", "CPointer<Bool>", "CPointer<Bool>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateStringArray", 37, [InterfaceParameterSchema("value", "CPointer<CPointer<UInt16>>", "CPointer<CPointer<UInt16>>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateInspectableArray", 38, [InterfaceParameterSchema("value", "CPointer<CPointer<Unit>>", "CPointer<CPointer<Unit>>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateGuidArray", 39, [InterfaceParameterSchema("value", "CPointer<GUID>", "CPointer<GUID>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateDateTimeArray", 40, [InterfaceParameterSchema("value", "CPointer<DateTime>", "CPointer<DateTime>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateTimeSpanArray", 41, [InterfaceParameterSchema("value", "CPointer<TimeSpan>", "CPointer<TimeSpan>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreatePointArray", 42, [InterfaceParameterSchema("value", "CPointer<Point>", "CPointer<Point>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateSizeArray", 43, [InterfaceParameterSchema("value", "CPointer<Size>", "CPointer<Size>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateRectArray", 44, [InterfaceParameterSchema("value", "CPointer<Rect>", "CPointer<Rect>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<IInspectable>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IPropertyValueStatics.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{629BDBC8-D932-4FF4-96B9-8D96C5C1E858}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IPropertyValueStatics"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IPropertyValueStatics", IPropertyValueStatics.signature(), IPropertyValueStatics.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IPropertyValueStaticsVtbl {
        readVtbl<IPropertyValueStaticsVtbl>(IPropertyValueStaticsVtbl())
    }

    public unsafe func CreateEmpty(): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateEmpty(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateUInt8(value: UInt8): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateUInt8(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateInt16(value: Int16): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateInt16(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateUInt16(value: UInt16): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateUInt16(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateInt32(value: Int32): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateInt32(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateUInt32(value: UInt32): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateUInt32(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateInt64(value: Int64): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateInt64(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateUInt64(value: UInt64): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateUInt64(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateSingle(value: Float32): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateSingle(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateDouble(value: Float64): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateDouble(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateChar16(value: UInt16): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateChar16(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateBoolean(value: Bool): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateBoolean(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateString(value: CPointer<UInt16>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateString(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateInspectable(value: IInspectable): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateInspectable(asRaw(), value.asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateGuid(value: GUID): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateGuid(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateDateTime(value: DateTime): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateDateTime(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateTimeSpan(value: TimeSpan): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateTimeSpan(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreatePoint(value: Point): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreatePoint(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateSize(value: Size): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateSize(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateRect(value: Rect): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateRect(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateUInt8Array(value: CPointer<UInt8>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateUInt8Array(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateInt16Array(value: CPointer<Int16>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateInt16Array(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateUInt16Array(value: CPointer<UInt16>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateUInt16Array(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateInt32Array(value: CPointer<Int32>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateInt32Array(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateUInt32Array(value: CPointer<UInt32>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateUInt32Array(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateInt64Array(value: CPointer<Int64>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateInt64Array(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateUInt64Array(value: CPointer<UInt64>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateUInt64Array(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateSingleArray(value: CPointer<Float32>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateSingleArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateDoubleArray(value: CPointer<Float64>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateDoubleArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateChar16Array(value: CPointer<UInt16>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateChar16Array(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateBooleanArray(value: CPointer<Bool>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateBooleanArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateStringArray(value: CPointer<CPointer<UInt16>>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateStringArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateInspectableArray(value: CPointer<CPointer<Unit>>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateInspectableArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateGuidArray(value: CPointer<GUID>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateGuidArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateDateTimeArray(value: CPointer<DateTime>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateDateTimeArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateTimeSpanArray(value: CPointer<TimeSpan>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateTimeSpanArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreatePointArray(value: CPointer<Point>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreatePointArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateSizeArray(value: CPointer<Size>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateSizeArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }

    public unsafe func CreateRectArray(value: CPointer<Rect>): IInspectable {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateRectArray(asRaw(), value, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return IInspectable.fromAbiTake(result)
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IReferenceVtbl {
    public var base_: IPropertyValueVtbl = IPropertyValueVtbl()
    public var Value: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity, T>(offset!: Int64 = 0): IReferenceVtbl where Identity <: IReference_Impl<T>, T <: windows_core.RuntimeType {
        let _ = offset
        var vtbl = IReferenceVtbl()
        vtbl.base_ = IPropertyValueVtbl.new<Identity>(offset: offset)
        vtbl.Value = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Value()) {
                        case Result<T>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<T>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IReference<T>.iid()) {
            return true
        }
        for (ancestor in [IPropertyValue.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }
}

@When[Windows_Foundation == "on"]
public interface IReference_Impl<T> <: IPropertyValue_Impl where T <: windows_core.RuntimeType {
    public func Value(): windows_core.Result<T>
}

@When[Windows_Foundation == "on"]
public class IReference<T> <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where T <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IReference<T> {
        IReference<T>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IReference<T> {
        IReference<T>(raw)
    }

    public static func iid(): GUID {
        return GUID(0x61C17706, 0x2D65, 0x11E0, 0x9A, 0xE8, 0xD4, 0x85, 0x64, 0x01, 0x54, 0x72)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IReference<T>.iid()) {
            return true
        }
        for (ancestor in [IPropertyValue.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IReference<T>> {
        var descriptor = InterfaceDescriptor<IReference<T>>("IReference", IReference<T>.iid(), IPropertyValue.descriptor(), { raw => IReference<T>.fromAbiTake(raw) }, { raw => IReference<T>.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IReference<T>.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IReference", IReference<T>.iid(), IPropertyValue.descriptorSchema(), "IReferenceVtbl", "IReference", "IReference_Impl", [InterfaceMethodSchema("Value", 45, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<T>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IReference<T>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({61C17706-2D65-11E0-9AE8-D48564015472}")
        sb.append(";")
        sb.append(T.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IReference"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IReference", IReference<T>.signature(), IReference<T>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIPropertyValue(): IPropertyValue {
        IPropertyValue.viewOf(asRaw())
    }

    public unsafe func vtbl(): IReferenceVtbl {
        readVtbl<IReferenceVtbl>(IReferenceVtbl())
    }

    public unsafe func Value(): T {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.Value(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return result
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IReferenceArrayVtbl {
    public var base_: IPropertyValueVtbl = IPropertyValueVtbl()
    public var Value: CFunc<(CPointer<Unit>, CPointer<UInt32>, CPointer<CPointer<CPointer<Unit>>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity, T>(offset!: Int64 = 0): IReferenceArrayVtbl where Identity <: IReferenceArray_Impl<T>, T <: windows_core.RuntimeType {
        let _ = offset
        var vtbl = IReferenceArrayVtbl()
        vtbl.base_ = IPropertyValueVtbl.new<Identity>(offset: offset)
        vtbl.Value = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Value()) {
                        case Result<CPointer<T>>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<CPointer<T>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IReferenceArray<T>.iid()) {
            return true
        }
        for (ancestor in [IPropertyValue.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }
}

@When[Windows_Foundation == "on"]
public interface IReferenceArray_Impl<T> <: IPropertyValue_Impl where T <: windows_core.RuntimeType {
    public func Value(): windows_core.Result<CPointer<T>>
}

@When[Windows_Foundation == "on"]
public class IReferenceArray<T> <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider where T <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IReferenceArray<T> {
        IReferenceArray<T>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IReferenceArray<T> {
        IReferenceArray<T>(raw)
    }

    public static func iid(): GUID {
        return GUID(0x61C17707, 0x2D65, 0x11E0, 0x9A, 0xE8, 0xD4, 0x85, 0x64, 0x01, 0x54, 0x72)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IReferenceArray<T>.iid()) {
            return true
        }
        for (ancestor in [IPropertyValue.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IReferenceArray<T>> {
        var descriptor = InterfaceDescriptor<IReferenceArray<T>>("IReferenceArray", IReferenceArray<T>.iid(), IPropertyValue.descriptor(), { raw => IReferenceArray<T>.fromAbiTake(raw) }, { raw => IReferenceArray<T>.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IReferenceArray<T>.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IReferenceArray", IReferenceArray<T>.iid(), IPropertyValue.descriptorSchema(), "IReferenceArrayVtbl", "IReferenceArray", "IReferenceArray_Impl", [InterfaceMethodSchema("Value", 45, [InterfaceParameterSchema("result", "CPointer<CPointer<T>>", "OutSlot<CPointer<T>>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IReferenceArray<T>.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({61C17707-2D65-11E0-9AE8-D48564015472}")
        sb.append(";")
        sb.append(T.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IReferenceArray"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IReferenceArray", IReferenceArray<T>.signature(), IReferenceArray<T>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIPropertyValue(): IPropertyValue {
        IPropertyValue.viewOf(asRaw())
    }

    public unsafe func vtbl(): IReferenceArrayVtbl {
        readVtbl<IReferenceArrayVtbl>(IReferenceArrayVtbl())
    }

    public unsafe func Value(): CPointer<T> {
        let v = vtbl()
        var result = CPointer<T>()
        let hr = v.Value(asRaw(), CPointer<CPointer<T>>(inout result))
        HRESULT(hr).ok()
        return result
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IStringableVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var ToString: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IStringableVtbl where Identity <: IStringable_Impl {
        let _ = offset
        var vtbl = IStringableVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.ToString = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.ToString()) {
                        case Result<CPointer<UInt16>>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<CPointer<UInt16>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IStringable.iid()) {
            return true
        }
        return false
    }
}

@When[Windows_Foundation == "on"]
public interface IStringable_Impl {
    public func ToString(): windows_core.Result<CPointer<UInt16>>
}

@When[Windows_Foundation == "on"]
public class IStringable <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IStringable {
        IStringable(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IStringable {
        IStringable(raw)
    }

    public static func iid(): GUID {
        return GUID(0x96369F54, 0x8EB6, 0x48F0, 0xAB, 0xCE, 0xC1, 0xB2, 0x11, 0xE6, 0x27, 0xC3)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IStringable.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IStringable> {
        var descriptor = InterfaceDescriptor<IStringable>("IStringable", IStringable.iid(), IInspectable.descriptor(), { raw => IStringable.fromAbiTake(raw) }, { raw => IStringable.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IStringable.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IStringable", IStringable.iid(), IInspectable.descriptorSchema(), "IStringableVtbl", "IStringable", "IStringable_Impl", [InterfaceMethodSchema("ToString", 6, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IStringable.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{96369F54-8EB6-48F0-ABCE-C1B211E627C3}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IStringable"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IStringable", IStringable.signature(), IStringable.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IStringableVtbl {
        readVtbl<IStringableVtbl>(IStringableVtbl())
    }

    public unsafe func ToString(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.ToString(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IUriEscapeStaticsVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var UnescapeComponent: CFunc<(CPointer<Unit>, CPointer<UInt16>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var EscapeComponent: CFunc<(CPointer<Unit>, CPointer<UInt16>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IUriEscapeStatics <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IUriEscapeStatics {
        IUriEscapeStatics(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IUriEscapeStatics {
        IUriEscapeStatics(raw)
    }

    public static func iid(): GUID {
        return GUID(0xC1D432BA, 0xC824, 0x4452, 0xA7, 0xFD, 0x51, 0x2B, 0xC3, 0xBB, 0xE9, 0xA1)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IUriEscapeStatics.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IUriEscapeStatics> {
        var descriptor = InterfaceDescriptor<IUriEscapeStatics>("IUriEscapeStatics", IUriEscapeStatics.iid(), IInspectable.descriptor(), { raw => IUriEscapeStatics.fromAbiTake(raw) }, { raw => IUriEscapeStatics.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IUriEscapeStatics.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IUriEscapeStatics", IUriEscapeStatics.iid(), IInspectable.descriptorSchema(), "IUriEscapeStaticsVtbl", "IUriEscapeStatics", "IUriEscapeStatics_Impl", [InterfaceMethodSchema("UnescapeComponent", 6, [InterfaceParameterSchema("toUnescape", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("EscapeComponent", 7, [InterfaceParameterSchema("toEscape", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IUriEscapeStatics.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{C1D432BA-C824-4452-A7FD-512BC3BBE9A1}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IUriEscapeStatics"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IUriEscapeStatics", IUriEscapeStatics.signature(), IUriEscapeStatics.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IUriEscapeStaticsVtbl {
        readVtbl<IUriEscapeStaticsVtbl>(IUriEscapeStaticsVtbl())
    }

    public unsafe func UnescapeComponent(toUnescape: CPointer<UInt16>): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.UnescapeComponent(asRaw(), toUnescape, CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func EscapeComponent(toEscape: CPointer<UInt16>): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.EscapeComponent(asRaw(), toEscape, CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IUriRuntimeClassVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var AbsoluteUri: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var DisplayUri: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Domain: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Extension: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Fragment: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Host: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Password: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Path: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Query: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var QueryParsed: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var RawUri: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var SchemeName: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var UserName: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Port: CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Suspicious: CFunc<(CPointer<Unit>, CPointer<Bool>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Equals: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Bool>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CombineUri: CFunc<(CPointer<Unit>, CPointer<UInt16>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IUriRuntimeClass <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IUriRuntimeClass {
        IUriRuntimeClass(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IUriRuntimeClass {
        IUriRuntimeClass(raw)
    }

    public static func iid(): GUID {
        return GUID(0x9E365E57, 0x48B2, 0x4160, 0x95, 0x6F, 0xC7, 0x38, 0x51, 0x20, 0xBB, 0xFC)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IUriRuntimeClass.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IUriRuntimeClass> {
        var descriptor = InterfaceDescriptor<IUriRuntimeClass>("IUriRuntimeClass", IUriRuntimeClass.iid(), IInspectable.descriptor(), { raw => IUriRuntimeClass.fromAbiTake(raw) }, { raw => IUriRuntimeClass.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IUriRuntimeClass.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IUriRuntimeClass", IUriRuntimeClass.iid(), IInspectable.descriptorSchema(), "IUriRuntimeClassVtbl", "IUriRuntimeClass", "IUriRuntimeClass_Impl", [InterfaceMethodSchema("AbsoluteUri", 6, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("DisplayUri", 7, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Domain", 8, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Extension", 9, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Fragment", 10, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Host", 11, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Password", 12, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Path", 13, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Query", 14, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("QueryParsed", 15, [InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<WwwFormUrlDecoder>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("RawUri", 16, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("SchemeName", 17, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("UserName", 18, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Port", 19, [InterfaceParameterSchema("result", "CPointer<Int32>", "OutSlot<Int32>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Suspicious", 20, [InterfaceParameterSchema("result", "CPointer<Bool>", "OutSlot<Bool>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Equals", 21, [InterfaceParameterSchema("pUri", "CPointer<Unit>", "InParam<Uri>", InterfaceParameterBridgeKind.InParam), InterfaceParameterSchema("result", "CPointer<Bool>", "OutSlot<Bool>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CombineUri", 22, [InterfaceParameterSchema("relativeUri", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<Uri>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IUriRuntimeClass.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{9E365E57-48B2-4160-956F-C7385120BBFC}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IUriRuntimeClass"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IUriRuntimeClass", IUriRuntimeClass.signature(), IUriRuntimeClass.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IUriRuntimeClassVtbl {
        readVtbl<IUriRuntimeClassVtbl>(IUriRuntimeClassVtbl())
    }

    public unsafe func AbsoluteUri(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.AbsoluteUri(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func DisplayUri(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.DisplayUri(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Domain(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.Domain(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Extension(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.Extension(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Fragment(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.Fragment(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Host(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.Host(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Password(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.Password(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Path(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.Path(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Query(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.Query(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func QueryParsed(): WwwFormUrlDecoder {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.QueryParsed(asRaw(), CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return WwwFormUrlDecoder.fromAbiTake(result)
    }

    public unsafe func RawUri(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.RawUri(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func SchemeName(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.SchemeName(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func UserName(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.UserName(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Port(): Int32 {
        let v = vtbl()
        var result = 0
        let hr = v.Port(asRaw(), CPointer<Int32>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Suspicious(): Bool {
        let v = vtbl()
        var result = false
        let hr = v.Suspicious(asRaw(), CPointer<Bool>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Equals(pUri: Uri): Bool {
        let v = vtbl()
        var result = false
        let hr = v.Equals(asRaw(), pUri.asRaw(), CPointer<Bool>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func CombineUri(relativeUri: CPointer<UInt16>): Uri {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CombineUri(asRaw(), relativeUri, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return Uri.fromAbiTake(result)
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IUriRuntimeClassFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var CreateUri: CFunc<(CPointer<Unit>, CPointer<UInt16>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var CreateWithRelativeUri: CFunc<(CPointer<Unit>, CPointer<UInt16>, CPointer<UInt16>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IUriRuntimeClassFactory <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IUriRuntimeClassFactory {
        IUriRuntimeClassFactory(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IUriRuntimeClassFactory {
        IUriRuntimeClassFactory(raw)
    }

    public static func iid(): GUID {
        return GUID(0x44A9796F, 0x723E, 0x4FDF, 0xA2, 0x18, 0x03, 0x3E, 0x75, 0xB0, 0xC0, 0x84)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IUriRuntimeClassFactory.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IUriRuntimeClassFactory> {
        var descriptor = InterfaceDescriptor<IUriRuntimeClassFactory>("IUriRuntimeClassFactory", IUriRuntimeClassFactory.iid(), IInspectable.descriptor(), { raw => IUriRuntimeClassFactory.fromAbiTake(raw) }, { raw => IUriRuntimeClassFactory.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IUriRuntimeClassFactory.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IUriRuntimeClassFactory", IUriRuntimeClassFactory.iid(), IInspectable.descriptorSchema(), "IUriRuntimeClassFactoryVtbl", "IUriRuntimeClassFactory", "IUriRuntimeClassFactory_Impl", [InterfaceMethodSchema("CreateUri", 6, [InterfaceParameterSchema("uri", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<Uri>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("CreateWithRelativeUri", 7, [InterfaceParameterSchema("baseUri", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("relativeUri", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<Uri>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IUriRuntimeClassFactory.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{44A9796F-723E-4FDF-A218-033E75B0C084}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IUriRuntimeClassFactory"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IUriRuntimeClassFactory", IUriRuntimeClassFactory.signature(), IUriRuntimeClassFactory.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IUriRuntimeClassFactoryVtbl {
        readVtbl<IUriRuntimeClassFactoryVtbl>(IUriRuntimeClassFactoryVtbl())
    }

    public unsafe func CreateUri(uri: CPointer<UInt16>): Uri {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateUri(asRaw(), uri, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return Uri.fromAbiTake(result)
    }

    public unsafe func CreateWithRelativeUri(baseUri: CPointer<UInt16>, relativeUri: CPointer<UInt16>): Uri {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateWithRelativeUri(asRaw(), baseUri, relativeUri, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return Uri.fromAbiTake(result)
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IUriRuntimeClassWithAbsoluteCanonicalUriVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var AbsoluteCanonicalUri: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var DisplayIri: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IUriRuntimeClassWithAbsoluteCanonicalUri <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IUriRuntimeClassWithAbsoluteCanonicalUri {
        IUriRuntimeClassWithAbsoluteCanonicalUri(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IUriRuntimeClassWithAbsoluteCanonicalUri {
        IUriRuntimeClassWithAbsoluteCanonicalUri(raw)
    }

    public static func iid(): GUID {
        return GUID(0x758D9661, 0x221C, 0x480F, 0xA3, 0x39, 0x50, 0x65, 0x66, 0x73, 0xF4, 0x6F)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IUriRuntimeClassWithAbsoluteCanonicalUri.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IUriRuntimeClassWithAbsoluteCanonicalUri> {
        var descriptor = InterfaceDescriptor<IUriRuntimeClassWithAbsoluteCanonicalUri>("IUriRuntimeClassWithAbsoluteCanonicalUri", IUriRuntimeClassWithAbsoluteCanonicalUri.iid(), IInspectable.descriptor(), { raw => IUriRuntimeClassWithAbsoluteCanonicalUri.fromAbiTake(raw) }, { raw => IUriRuntimeClassWithAbsoluteCanonicalUri.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IUriRuntimeClassWithAbsoluteCanonicalUri.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IUriRuntimeClassWithAbsoluteCanonicalUri", IUriRuntimeClassWithAbsoluteCanonicalUri.iid(), IInspectable.descriptorSchema(), "IUriRuntimeClassWithAbsoluteCanonicalUriVtbl", "IUriRuntimeClassWithAbsoluteCanonicalUri", "IUriRuntimeClassWithAbsoluteCanonicalUri_Impl", [InterfaceMethodSchema("AbsoluteCanonicalUri", 6, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("DisplayIri", 7, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IUriRuntimeClassWithAbsoluteCanonicalUri.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{758D9661-221C-480F-A339-50656673F46F}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IUriRuntimeClassWithAbsoluteCanonicalUri"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IUriRuntimeClassWithAbsoluteCanonicalUri", IUriRuntimeClassWithAbsoluteCanonicalUri.signature(), IUriRuntimeClassWithAbsoluteCanonicalUri.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IUriRuntimeClassWithAbsoluteCanonicalUriVtbl {
        readVtbl<IUriRuntimeClassWithAbsoluteCanonicalUriVtbl>(IUriRuntimeClassWithAbsoluteCanonicalUriVtbl())
    }

    public unsafe func AbsoluteCanonicalUri(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.AbsoluteCanonicalUri(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func DisplayIri(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.DisplayIri(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IWwwFormUrlDecoderEntryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var Name: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var Value: CFunc<(CPointer<Unit>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public init() {}

    public static func new<Identity>(offset!: Int64 = 0): IWwwFormUrlDecoderEntryVtbl where Identity <: IWwwFormUrlDecoderEntry_Impl {
        let _ = offset
        var vtbl = IWwwFormUrlDecoderEntryVtbl()
        vtbl.base_ = buildIInspectableVtbl()
        vtbl.Name = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Name()) {
                        case Result<CPointer<UInt16>>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<CPointer<UInt16>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        vtbl.Value = { instanceRaw, result__ =>
            if (result__.isNull()) {
                return E_POINTER.value
            }
            match (unsafe { asImplFromRaw<Identity>(instanceRaw) }) {
                case Some(impl) =>
                    match (impl.Value()) {
                        case Result<CPointer<UInt16>>.Ok(value) =>
                            unsafe { result__.write(value) }
                            S_OK.value
                        case Result<CPointer<UInt16>>.Err(error) =>
                            error.code().value
                    }
                case None =>
                    E_NOINTERFACE.value
            }
        }
        return vtbl
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IWwwFormUrlDecoderEntry.iid()) {
            return true
        }
        return false
    }
}

@When[Windows_Foundation == "on"]
public interface IWwwFormUrlDecoderEntry_Impl {
    public func Name(): windows_core.Result<CPointer<UInt16>>
    public func Value(): windows_core.Result<CPointer<UInt16>>
}

@When[Windows_Foundation == "on"]
public class IWwwFormUrlDecoderEntry <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IWwwFormUrlDecoderEntry {
        IWwwFormUrlDecoderEntry(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IWwwFormUrlDecoderEntry {
        IWwwFormUrlDecoderEntry(raw)
    }

    public static func iid(): GUID {
        return GUID(0x125E7431, 0xF678, 0x4E8E, 0xB6, 0x70, 0x20, 0xA9, 0xB0, 0x6C, 0x51, 0x2D)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IWwwFormUrlDecoderEntry.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IWwwFormUrlDecoderEntry> {
        var descriptor = InterfaceDescriptor<IWwwFormUrlDecoderEntry>("IWwwFormUrlDecoderEntry", IWwwFormUrlDecoderEntry.iid(), IInspectable.descriptor(), { raw => IWwwFormUrlDecoderEntry.fromAbiTake(raw) }, { raw => IWwwFormUrlDecoderEntry.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IWwwFormUrlDecoderEntry.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IWwwFormUrlDecoderEntry", IWwwFormUrlDecoderEntry.iid(), IInspectable.descriptorSchema(), "IWwwFormUrlDecoderEntryVtbl", "IWwwFormUrlDecoderEntry", "IWwwFormUrlDecoderEntry_Impl", [InterfaceMethodSchema("Name", 6, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32"), InterfaceMethodSchema("Value", 7, [InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IWwwFormUrlDecoderEntry.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{125E7431-F678-4E8E-B670-20A9B06C512D}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IWwwFormUrlDecoderEntry"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IWwwFormUrlDecoderEntry", IWwwFormUrlDecoderEntry.signature(), IWwwFormUrlDecoderEntry.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IWwwFormUrlDecoderEntryVtbl {
        readVtbl<IWwwFormUrlDecoderEntryVtbl>(IWwwFormUrlDecoderEntryVtbl())
    }

    public unsafe func Name(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.Name(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public unsafe func Value(): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.Value(asRaw(), CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IWwwFormUrlDecoderRuntimeClassVtbl {
    public var base_: IIterableVtbl = IIterableVtbl()
    public var GetFirstValueByName: CFunc<(CPointer<Unit>, CPointer<UInt16>, CPointer<CPointer<UInt16>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IWwwFormUrlDecoderRuntimeClass <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IWwwFormUrlDecoderRuntimeClass {
        IWwwFormUrlDecoderRuntimeClass(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IWwwFormUrlDecoderRuntimeClass {
        IWwwFormUrlDecoderRuntimeClass(raw)
    }

    public static func iid(): GUID {
        return GUID(0xD45A0451, 0xF225, 0x4542, 0x92, 0x96, 0x0E, 0x1D, 0xF5, 0xD2, 0x54, 0xDF)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IWwwFormUrlDecoderRuntimeClass.iid()) {
            return true
        }
        for (ancestor in [Foundation_Collections.IIterable<IWwwFormUrlDecoderEntry>.iid(), Foundation_Collections.IVectorView<IWwwFormUrlDecoderEntry>.iid(), Foundation_Collections.IIterable<T0>.iid(), IInspectable.iid(), IUnknown.iid()]) {
            if (ancestor == iid) {
                return true
            }
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IWwwFormUrlDecoderRuntimeClass> {
        var descriptor = InterfaceDescriptor<IWwwFormUrlDecoderRuntimeClass>("IWwwFormUrlDecoderRuntimeClass", IWwwFormUrlDecoderRuntimeClass.iid(), Foundation_Collections.IIterable<IWwwFormUrlDecoderEntry>.descriptor(), { raw => IWwwFormUrlDecoderRuntimeClass.fromAbiTake(raw) }, { raw => IWwwFormUrlDecoderRuntimeClass.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IWwwFormUrlDecoderRuntimeClass.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IWwwFormUrlDecoderRuntimeClass", IWwwFormUrlDecoderRuntimeClass.iid(), Foundation_Collections.IIterable<IWwwFormUrlDecoderEntry>.descriptorSchema(), "IWwwFormUrlDecoderRuntimeClassVtbl", "IWwwFormUrlDecoderRuntimeClass", "IWwwFormUrlDecoderRuntimeClass_Impl", [InterfaceMethodSchema("GetFirstValueByName", 7, [InterfaceParameterSchema("name", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<UInt16>>", "OutSlot<CPointer<UInt16>>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IWwwFormUrlDecoderRuntimeClass.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{D45A0451-F225-4542-9296-0E1DF5D254DF}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IWwwFormUrlDecoderRuntimeClass"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IWwwFormUrlDecoderRuntimeClass", IWwwFormUrlDecoderRuntimeClass.signature(), IWwwFormUrlDecoderRuntimeClass.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIIterable(): Foundation_Collections.IIterable<IWwwFormUrlDecoderEntry> {
        Foundation_Collections.IIterable<IWwwFormUrlDecoderEntry>.viewOf(asRaw())
    }

    public func asIVectorView(): Foundation_Collections.IVectorView<IWwwFormUrlDecoderEntry> {
        Foundation_Collections.IVectorView<IWwwFormUrlDecoderEntry>.viewOf(asRaw())
    }

    public func asIIterable(): Foundation_Collections.IIterable<T0> {
        Foundation_Collections.IIterable<T0>.viewOf(asRaw())
    }

    public unsafe func vtbl(): IWwwFormUrlDecoderRuntimeClassVtbl {
        readVtbl<IWwwFormUrlDecoderRuntimeClassVtbl>(IWwwFormUrlDecoderRuntimeClassVtbl())
    }

    public unsafe func GetFirstValueByName(name: CPointer<UInt16>): CPointer<UInt16> {
        let v = vtbl()
        var result = CPointer<UInt16>()
        let hr = v.GetFirstValueByName(asRaw(), name, CPointer<CPointer<UInt16>>(inout result))
        HRESULT(hr).ok()
        return result
    }

    public func intoIterator(): Iterator<IWwwFormUrlDecoderEntry> {
        asIIterable().intoIterator()
    }

    public func iterator(): Iterator<IWwwFormUrlDecoderEntry> {
        intoIterator()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct IWwwFormUrlDecoderRuntimeClassFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var CreateWwwFormUrlDecoder: CFunc<(CPointer<Unit>, CPointer<UInt16>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class IWwwFormUrlDecoderRuntimeClassFactory <: InterfaceWrapperBase & ComInterface & RuntimeName & windows_interface.RuntimeType & windows_core.RuntimeType & DescriptorSchemaProvider {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IWwwFormUrlDecoderRuntimeClassFactory {
        IWwwFormUrlDecoderRuntimeClassFactory(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IWwwFormUrlDecoderRuntimeClassFactory {
        IWwwFormUrlDecoderRuntimeClassFactory(raw)
    }

    public static func iid(): GUID {
        return GUID(0x5B8C6B3D, 0x24AE, 0x41B5, 0xA1, 0xBF, 0xF0, 0xC3, 0xD5, 0x44, 0x84, 0x5B)
    }

    public static func matches(iid: GUID): Bool {
        if (iid == IWwwFormUrlDecoderRuntimeClassFactory.iid()) {
            return true
        }
        return false
    }

    public static func descriptor(): InterfaceDescriptor<IWwwFormUrlDecoderRuntimeClassFactory> {
        var descriptor = InterfaceDescriptor<IWwwFormUrlDecoderRuntimeClassFactory>("IWwwFormUrlDecoderRuntimeClassFactory", IWwwFormUrlDecoderRuntimeClassFactory.iid(), IInspectable.descriptor(), { raw => IWwwFormUrlDecoderRuntimeClassFactory.fromAbiTake(raw) }, { raw => IWwwFormUrlDecoderRuntimeClassFactory.viewOf(raw) })
        descriptor.runtimeTypeContract = Some(IWwwFormUrlDecoderRuntimeClassFactory.runtimeType())
        return descriptor
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        var schema = InterfaceDescriptorSchema("IWwwFormUrlDecoderRuntimeClassFactory", IWwwFormUrlDecoderRuntimeClassFactory.iid(), IInspectable.descriptorSchema(), "IWwwFormUrlDecoderRuntimeClassFactoryVtbl", "IWwwFormUrlDecoderRuntimeClassFactory", "IWwwFormUrlDecoderRuntimeClassFactory_Impl", [InterfaceMethodSchema("CreateWwwFormUrlDecoder", 6, [InterfaceParameterSchema("query", "CPointer<UInt16>", "CPointer<UInt16>", InterfaceParameterBridgeKind.Value), InterfaceParameterSchema("result", "CPointer<CPointer<Unit>>", "OutSlot<WwwFormUrlDecoder>", InterfaceParameterBridgeKind.OutSlot)], "Int32")])
        schema.runtimeTypeContract = Some(IWwwFormUrlDecoderRuntimeClassFactory.runtimeType())
        return schema
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "{5B8C6B3D-24AE-41B5-A1BF-F0C3D544845B}"
    }

    public static func runtimeName(): String {
        "Windows.Foundation.IWwwFormUrlDecoderRuntimeClassFactory"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.IWwwFormUrlDecoderRuntimeClassFactory", IWwwFormUrlDecoderRuntimeClassFactory.signature(), IWwwFormUrlDecoderRuntimeClassFactory.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IWwwFormUrlDecoderRuntimeClassFactoryVtbl {
        readVtbl<IWwwFormUrlDecoderRuntimeClassFactoryVtbl>(IWwwFormUrlDecoderRuntimeClassFactoryVtbl())
    }

    public unsafe func CreateWwwFormUrlDecoder(query: CPointer<UInt16>): WwwFormUrlDecoder {
        let v = vtbl()
        var result = CPointer<Unit>()
        let hr = v.CreateWwwFormUrlDecoder(asRaw(), query, CPointer<CPointer<Unit>>(inout result))
        HRESULT(hr).ok()
        return WwwFormUrlDecoder.fromAbiTake(result)
    }
}

@When[Windows_Foundation == "on"]
public class MemoryBuffer <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): MemoryBuffer {
        MemoryBuffer(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): MemoryBuffer {
        MemoryBuffer(raw)
    }

    public static func iid(): GUID {
        IMemoryBuffer.iid()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.MemoryBuffer"
    }

    public static func descriptor(): InterfaceDescriptor<MemoryBuffer> {
        let ancestors = [IMemoryBuffer.iid(), IClosable.iid(), IInspectable.iid(), IUnknown.iid()]
        return InterfaceDescriptor<MemoryBuffer>("MemoryBuffer", IMemoryBuffer.iid(), ancestors, { raw => MemoryBuffer.fromAbiTake(raw) }, { raw => MemoryBuffer.viewOf(raw) })
    }

    public func defaultInterface(): IMemoryBuffer {
        IMemoryBuffer.viewOf(asRaw())
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "rc(Windows.Foundation.MemoryBuffer;{FBC4DD2A-245B-11E4-AF98-689423260CF8})"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.MemoryBuffer", MemoryBuffer.signature(), IMemoryBuffer.iid())
    }

    public static func activationFactory(): Option<IActivationFactory> {
        windows_interface.getActivationFactoryByName<IActivationFactory>(MemoryBuffer.runtimeName(), IActivationFactory.descriptor()).ok()
    }

    public static func isAgile(): Bool {
        true
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIMemoryBuffer(): IMemoryBuffer {
        IMemoryBuffer(asRaw())
    }

    public func asIClosable(): IClosable {
        IClosable(asRaw())
    }

    public static unsafe func Create(capacity: UInt32): MemoryBuffer {
        try (factory = windows_interface.getActivationFactoryByName<IMemoryBufferFactory>(MemoryBuffer.runtimeName(), IMemoryBufferFactory.descriptor()).unwrap()) {
            return factory.Create(capacity)
        }
    }

    public unsafe func CreateReference(): IMemoryBufferReference {
        return defaultInterface().CreateReference()
    }

    public unsafe func Close(): Unit {
        asIClosable().Close()
    }
}

@When[Windows_Foundation == "on"]
@C
public struct Point {
    public var X: Float32 = 0.0
    public var Y: Float32 = 0.0
    public init() {}
}

@When[Windows_Foundation == "on"]
@C
public struct PropertyType {
    public var value: Int32 = 0

    public init() {}

    public init(value: Int32) {
        this.value = value
    }

    public operator func ==(other: PropertyType): Bool {
        return this.value == other.value
    }
    public operator func !=(other: PropertyType): Bool {
        return this.value != other.value
    }
}

@When[Windows_Foundation == "on"]
public let Empty: PropertyType = PropertyType(0)

@When[Windows_Foundation == "on"]
public let `UInt8`: PropertyType = PropertyType(1)

@When[Windows_Foundation == "on"]
public let `Int16`: PropertyType = PropertyType(2)

@When[Windows_Foundation == "on"]
public let `UInt16`: PropertyType = PropertyType(3)

@When[Windows_Foundation == "on"]
public let `Int32`: PropertyType = PropertyType(4)

@When[Windows_Foundation == "on"]
public let `UInt32`: PropertyType = PropertyType(5)

@When[Windows_Foundation == "on"]
public let `Int64`: PropertyType = PropertyType(6)

@When[Windows_Foundation == "on"]
public let `UInt64`: PropertyType = PropertyType(7)

@When[Windows_Foundation == "on"]
public let Single: PropertyType = PropertyType(8)

@When[Windows_Foundation == "on"]
public let Double: PropertyType = PropertyType(9)

@When[Windows_Foundation == "on"]
public let Char16: PropertyType = PropertyType(10)

@When[Windows_Foundation == "on"]
public let Boolean: PropertyType = PropertyType(11)

@When[Windows_Foundation == "on"]
public let String: PropertyType = PropertyType(12)

@When[Windows_Foundation == "on"]
public let Inspectable: PropertyType = PropertyType(13)

@When[Windows_Foundation == "on"]
public let DateTime_CONST: PropertyType = PropertyType(14)

@When[Windows_Foundation == "on"]
public let TimeSpan_CONST: PropertyType = PropertyType(15)

@When[Windows_Foundation == "on"]
public let Guid: PropertyType = PropertyType(16)

@When[Windows_Foundation == "on"]
public let Point_CONST: PropertyType = PropertyType(17)

@When[Windows_Foundation == "on"]
public let Size_CONST: PropertyType = PropertyType(18)

@When[Windows_Foundation == "on"]
public let Rect_CONST: PropertyType = PropertyType(19)

@When[Windows_Foundation == "on"]
public let OtherType: PropertyType = PropertyType(20)

@When[Windows_Foundation == "on"]
public let UInt8Array: PropertyType = PropertyType(1025)

@When[Windows_Foundation == "on"]
public let Int16Array: PropertyType = PropertyType(1026)

@When[Windows_Foundation == "on"]
public let UInt16Array: PropertyType = PropertyType(1027)

@When[Windows_Foundation == "on"]
public let Int32Array: PropertyType = PropertyType(1028)

@When[Windows_Foundation == "on"]
public let UInt32Array: PropertyType = PropertyType(1029)

@When[Windows_Foundation == "on"]
public let Int64Array: PropertyType = PropertyType(1030)

@When[Windows_Foundation == "on"]
public let UInt64Array: PropertyType = PropertyType(1031)

@When[Windows_Foundation == "on"]
public let SingleArray: PropertyType = PropertyType(1032)

@When[Windows_Foundation == "on"]
public let DoubleArray: PropertyType = PropertyType(1033)

@When[Windows_Foundation == "on"]
public let Char16Array: PropertyType = PropertyType(1034)

@When[Windows_Foundation == "on"]
public let BooleanArray: PropertyType = PropertyType(1035)

@When[Windows_Foundation == "on"]
public let StringArray: PropertyType = PropertyType(1036)

@When[Windows_Foundation == "on"]
public let InspectableArray: PropertyType = PropertyType(1037)

@When[Windows_Foundation == "on"]
public let DateTimeArray: PropertyType = PropertyType(1038)

@When[Windows_Foundation == "on"]
public let TimeSpanArray: PropertyType = PropertyType(1039)

@When[Windows_Foundation == "on"]
public let GuidArray: PropertyType = PropertyType(1040)

@When[Windows_Foundation == "on"]
public let PointArray: PropertyType = PropertyType(1041)

@When[Windows_Foundation == "on"]
public let SizeArray: PropertyType = PropertyType(1042)

@When[Windows_Foundation == "on"]
public let RectArray: PropertyType = PropertyType(1043)

@When[Windows_Foundation == "on"]
public let OtherTypeArray: PropertyType = PropertyType(1044)

@When[Windows_Foundation == "on"]
public class PropertyValue <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): PropertyValue {
        PropertyValue(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): PropertyValue {
        PropertyValue(raw)
    }

    public static func iid(): GUID {
        GUID()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.PropertyValue"
    }

    public static func descriptor(): InterfaceDescriptor<PropertyValue> {
        return InterfaceDescriptor<PropertyValue>("PropertyValue", GUID(), [IInspectable.iid(), IUnknown.iid()], { raw => PropertyValue.fromAbiTake(raw) }, { raw => PropertyValue.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "Windows.Foundation.PropertyValue"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.PropertyValue", PropertyValue.signature())
    }

    public static func activationFactory(): Option<IActivationFactory> {
        windows_interface.getActivationFactoryByName<IActivationFactory>(PropertyValue.runtimeName(), IActivationFactory.descriptor()).ok()
    }

    public static func isAgile(): Bool {
        true
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public static unsafe func CreateEmpty(): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateEmpty()
        }
    }

    public static unsafe func CreateUInt8(value: UInt8): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateUInt8(value)
        }
    }

    public static unsafe func CreateInt16(value: Int16): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateInt16(value)
        }
    }

    public static unsafe func CreateUInt16(value: UInt16): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateUInt16(value)
        }
    }

    public static unsafe func CreateInt32(value: Int32): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateInt32(value)
        }
    }

    public static unsafe func CreateUInt32(value: UInt32): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateUInt32(value)
        }
    }

    public static unsafe func CreateInt64(value: Int64): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateInt64(value)
        }
    }

    public static unsafe func CreateUInt64(value: UInt64): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateUInt64(value)
        }
    }

    public static unsafe func CreateSingle(value: Float32): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateSingle(value)
        }
    }

    public static unsafe func CreateDouble(value: Float64): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateDouble(value)
        }
    }

    public static unsafe func CreateChar16(value: UInt16): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateChar16(value)
        }
    }

    public static unsafe func CreateBoolean(value: Bool): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateBoolean(value)
        }
    }

    public static unsafe func CreateString(value: CPointer<UInt16>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateString(value)
        }
    }

    public static unsafe func CreateInspectable(value: IInspectable): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateInspectable(value)
        }
    }

    public static unsafe func CreateGuid(value: GUID): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateGuid(value)
        }
    }

    public static unsafe func CreateDateTime(value: DateTime): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateDateTime(value)
        }
    }

    public static unsafe func CreateTimeSpan(value: TimeSpan): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateTimeSpan(value)
        }
    }

    public static unsafe func CreatePoint(value: Point): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreatePoint(value)
        }
    }

    public static unsafe func CreateSize(value: Size): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateSize(value)
        }
    }

    public static unsafe func CreateRect(value: Rect): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateRect(value)
        }
    }

    public static unsafe func CreateUInt8Array(value: CPointer<UInt8>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateUInt8Array(value)
        }
    }

    public static unsafe func CreateInt16Array(value: CPointer<Int16>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateInt16Array(value)
        }
    }

    public static unsafe func CreateUInt16Array(value: CPointer<UInt16>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateUInt16Array(value)
        }
    }

    public static unsafe func CreateInt32Array(value: CPointer<Int32>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateInt32Array(value)
        }
    }

    public static unsafe func CreateUInt32Array(value: CPointer<UInt32>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateUInt32Array(value)
        }
    }

    public static unsafe func CreateInt64Array(value: CPointer<Int64>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateInt64Array(value)
        }
    }

    public static unsafe func CreateUInt64Array(value: CPointer<UInt64>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateUInt64Array(value)
        }
    }

    public static unsafe func CreateSingleArray(value: CPointer<Float32>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateSingleArray(value)
        }
    }

    public static unsafe func CreateDoubleArray(value: CPointer<Float64>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateDoubleArray(value)
        }
    }

    public static unsafe func CreateChar16Array(value: CPointer<UInt16>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateChar16Array(value)
        }
    }

    public static unsafe func CreateBooleanArray(value: CPointer<Bool>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateBooleanArray(value)
        }
    }

    public static unsafe func CreateStringArray(value: CPointer<CPointer<UInt16>>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateStringArray(value)
        }
    }

    public static unsafe func CreateInspectableArray(value: CPointer<CPointer<Unit>>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateInspectableArray(value)
        }
    }

    public static unsafe func CreateGuidArray(value: CPointer<GUID>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateGuidArray(value)
        }
    }

    public static unsafe func CreateDateTimeArray(value: CPointer<DateTime>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateDateTimeArray(value)
        }
    }

    public static unsafe func CreateTimeSpanArray(value: CPointer<TimeSpan>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateTimeSpanArray(value)
        }
    }

    public static unsafe func CreatePointArray(value: CPointer<Point>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreatePointArray(value)
        }
    }

    public static unsafe func CreateSizeArray(value: CPointer<Size>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateSizeArray(value)
        }
    }

    public static unsafe func CreateRectArray(value: CPointer<Rect>): IInspectable {
        try (factory = windows_interface.getActivationFactoryByName<IPropertyValueStatics>(PropertyValue.runtimeName(), IPropertyValueStatics.descriptor()).unwrap()) {
            return factory.CreateRectArray(value)
        }
    }
}

@When[Windows_Foundation == "on"]
@C
public struct Rect {
    public var X: Float32 = 0.0
    public var Y: Float32 = 0.0
    public var Width: Float32 = 0.0
    public var Height: Float32 = 0.0
    public init() {}
}

@When[Windows_Foundation == "on"]
@C
public struct Size {
    public var Width: Float32 = 0.0
    public var Height: Float32 = 0.0
    public init() {}
}

@When[Windows_Foundation == "on"]
@C
public struct TimeSpan {
    public var Duration: Int64 = 0
    public init() {}
}

@When[Windows_Foundation == "on"]
@C
public struct TypedEventHandlerVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var _.ctor: CFunc<(CPointer<Unit>, CPointer<Unit>, IntNative) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public var Invoke: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _, _ => E_NOTIMPL.value }
    public init() {}
}

@When[Windows_Foundation == "on"]
public class TypedEventHandler<TSender, TResult> <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType where TSender <: windows_core.RuntimeType, TResult <: windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): TypedEventHandler<TSender, TResult> {
        TypedEventHandler<TSender, TResult>(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): TypedEventHandler<TSender, TResult> {
        TypedEventHandler<TSender, TResult>(raw)
    }

    public static func iid(): GUID {
        return GUID(0x9DE1C534, 0x6AE1, 0x11E0, 0x84, 0xE1, 0x18, 0xA9, 0x05, 0xBC, 0xC5, 0x3F)
    }

    public static func descriptor(): InterfaceDescriptor<TypedEventHandler<TSender, TResult>> {
        return InterfaceDescriptor<TypedEventHandler<TSender, TResult>>("TypedEventHandler", TypedEventHandler<TSender, TResult>.iid(), [IInspectable.iid(), IUnknown.iid()], { raw => TypedEventHandler<TSender, TResult>.fromAbiTake(raw) }, { raw => TypedEventHandler<TSender, TResult>.viewOf(raw) })
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        var sb = StringBuilder()
        sb.append("pinterface({9DE1C534-6AE1-11E0-84E1-18A905BCC53F}")
        sb.append(";")
        sb.append(TSender.signature())
        sb.append(";")
        sb.append(TResult.signature())
        sb.append(")")
        return sb.toString()
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.TypedEventHandler", TypedEventHandler<TSender, TResult>.signature(), TypedEventHandler<TSender, TResult>.iid())
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): TypedEventHandlerVtbl {
        readVtbl<TypedEventHandlerVtbl>(TypedEventHandlerVtbl())
    }

    public unsafe func _.ctor(object: IInspectable, method: IntNative): Unit {
        let v = vtbl()
        let hr = v._.ctor(asRaw(), object.asRaw(), method)
        HRESULT(hr).ok()
    }

    public unsafe func Invoke(sender: TSender, args: TResult): Unit {
        let v = vtbl()
        let hr = v.Invoke(asRaw(), sender, args)
        HRESULT(hr).ok()
    }

    public static func new(invoke: (TSender, TResult) -> Unit): TypedEventHandler<TSender, TResult> {
        let box = TypedEventHandlerBox<TSender, TResult>(invoke)
        let object = ComObject<TypedEventHandlerBox<TSender, TResult>>.new(box, [TypedEventHandler<TSender, TResult>.descriptorSchema()], [box.vtblPtr()])
        return object.intoInterface(TypedEventHandler<TSender, TResult>.descriptor())
    }
}

private open class TypedEventHandlerInvoker<TSender, TResult> where TSender <: windows_core.RuntimeType, TResult <: windows_core.RuntimeType {
    public open func Invoke(sender: TSender, args: TResult): Unit {
        ()
    }
}

private class TypedEventHandlerBox<TSender, TResult> <: TypedEventHandlerInvoker<TSender, TResult> where TSender <: windows_core.RuntimeType, TResult <: windows_core.RuntimeType {
    public let invoke_: (TSender, TResult) -> Unit
    private let vtblHandle: CPointerHandle<TypedEventHandlerVtbl>

    public init(invoke: (TSender, TResult) -> Unit) {
        this.invoke_ = invoke
        this.vtblHandle = unsafe { acquireArrayRawData(Array<TypedEventHandlerVtbl>(1, { _ => buildTypedEventHandlerBoxVtbl<TSender, TResult>() })) }
    }

    public func vtblPtr(): CPointer<Unit> {
        CPointer<Unit>(vtblHandle.pointer)
    }

    public override func Invoke(sender: TSender, args: TResult): Unit {
        invoke_(sender, args)
    }
}

func buildTypedEventHandlerBoxVtbl<TSender, TResult>(): TypedEventHandlerVtbl where TSender <: windows_core.RuntimeType, TResult <: windows_core.RuntimeType {
    var vtbl = TypedEventHandlerVtbl()
    vtbl.base_ = buildIInspectableVtbl()
    vtbl.Invoke = { instanceRaw: CPointer<Unit>, arg0: CPointer<Unit>, arg1: CPointer<Unit> =>
        match (unsafe { asImplFromRaw<TypedEventHandlerInvoker<TSender, TResult>>(instanceRaw) }) {
            case Some(invoker) =>
                invoker.Invoke(arg0, arg1)
                return S_OK.value
            case None =>
                return E_NOTIMPL.value
        }
    }
    return vtbl
}

@When[Windows_Foundation == "on"]
@C
public struct UniversalApiContract {
    public init() {}
}

@When[Windows_Foundation == "on"]
public class Uri <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): Uri {
        Uri(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): Uri {
        Uri(raw)
    }

    public static func iid(): GUID {
        IUriRuntimeClass.iid()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.Uri"
    }

    public static func descriptor(): InterfaceDescriptor<Uri> {
        let ancestors = [IUriRuntimeClass.iid(), IStringable.iid(), IInspectable.iid(), IUnknown.iid()]
        return InterfaceDescriptor<Uri>("Uri", IUriRuntimeClass.iid(), ancestors, { raw => Uri.fromAbiTake(raw) }, { raw => Uri.viewOf(raw) })
    }

    public func defaultInterface(): IUriRuntimeClass {
        IUriRuntimeClass.viewOf(asRaw())
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "rc(Windows.Foundation.Uri;{9E365E57-48B2-4160-956F-C7385120BBFC})"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.Uri", Uri.signature(), IUriRuntimeClass.iid())
    }

    public static func activationFactory(): Option<IActivationFactory> {
        windows_interface.getActivationFactoryByName<IActivationFactory>(Uri.runtimeName(), IActivationFactory.descriptor()).ok()
    }

    public static func isAgile(): Bool {
        true
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIUriRuntimeClass(): IUriRuntimeClass {
        IUriRuntimeClass(asRaw())
    }

    public func asIStringable(): IStringable {
        IStringable(asRaw())
    }

    public static unsafe func UnescapeComponent(toUnescape: CPointer<UInt16>): CPointer<UInt16> {
        try (factory = windows_interface.getActivationFactoryByName<IUriEscapeStatics>(Uri.runtimeName(), IUriEscapeStatics.descriptor()).unwrap()) {
            return factory.UnescapeComponent(toUnescape)
        }
    }

    public static unsafe func EscapeComponent(toEscape: CPointer<UInt16>): CPointer<UInt16> {
        try (factory = windows_interface.getActivationFactoryByName<IUriEscapeStatics>(Uri.runtimeName(), IUriEscapeStatics.descriptor()).unwrap()) {
            return factory.EscapeComponent(toEscape)
        }
    }

    public static unsafe func CreateUri(uri: CPointer<UInt16>): Uri {
        try (factory = windows_interface.getActivationFactoryByName<IUriRuntimeClassFactory>(Uri.runtimeName(), IUriRuntimeClassFactory.descriptor()).unwrap()) {
            return factory.CreateUri(uri)
        }
    }

    public static unsafe func CreateWithRelativeUri(baseUri: CPointer<UInt16>, relativeUri: CPointer<UInt16>): Uri {
        try (factory = windows_interface.getActivationFactoryByName<IUriRuntimeClassFactory>(Uri.runtimeName(), IUriRuntimeClassFactory.descriptor()).unwrap()) {
            return factory.CreateWithRelativeUri(baseUri, relativeUri)
        }
    }

    public unsafe func AbsoluteUri(): CPointer<UInt16> {
        return defaultInterface().AbsoluteUri()
    }

    public unsafe func DisplayUri(): CPointer<UInt16> {
        return defaultInterface().DisplayUri()
    }

    public unsafe func Domain(): CPointer<UInt16> {
        return defaultInterface().Domain()
    }

    public unsafe func Extension(): CPointer<UInt16> {
        return defaultInterface().Extension()
    }

    public unsafe func Fragment(): CPointer<UInt16> {
        return defaultInterface().Fragment()
    }

    public unsafe func Host(): CPointer<UInt16> {
        return defaultInterface().Host()
    }

    public unsafe func Password(): CPointer<UInt16> {
        return defaultInterface().Password()
    }

    public unsafe func Path(): CPointer<UInt16> {
        return defaultInterface().Path()
    }

    public unsafe func Query(): CPointer<UInt16> {
        return defaultInterface().Query()
    }

    public unsafe func QueryParsed(): WwwFormUrlDecoder {
        return defaultInterface().QueryParsed()
    }

    public unsafe func RawUri(): CPointer<UInt16> {
        return defaultInterface().RawUri()
    }

    public unsafe func SchemeName(): CPointer<UInt16> {
        return defaultInterface().SchemeName()
    }

    public unsafe func UserName(): CPointer<UInt16> {
        return defaultInterface().UserName()
    }

    public unsafe func Port(): Int32 {
        return defaultInterface().Port()
    }

    public unsafe func Suspicious(): Bool {
        return defaultInterface().Suspicious()
    }

    public unsafe func Equals(value: Uri): Bool {
        return defaultInterface().Equals(value)
    }

    public unsafe func CombineUri(instance: CPointer<UInt16>): Uri {
        return defaultInterface().CombineUri(instance)
    }

    public unsafe func ToString(): CPointer<UInt16> {
        return asIStringable().ToString()
    }
}

@When[Windows_Foundation == "on"]
public class WwwFormUrlDecoder <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): WwwFormUrlDecoder {
        WwwFormUrlDecoder(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): WwwFormUrlDecoder {
        WwwFormUrlDecoder(raw)
    }

    public static func iid(): GUID {
        IWwwFormUrlDecoderRuntimeClass.iid()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.WwwFormUrlDecoder"
    }

    public static func descriptor(): InterfaceDescriptor<WwwFormUrlDecoder> {
        let ancestors = [IWwwFormUrlDecoderRuntimeClass.iid(), Foundation_Collections.IIterable<IWwwFormUrlDecoderEntry>.iid(), Foundation_Collections.IVectorView<IWwwFormUrlDecoderEntry>.iid(), Foundation_Collections.IIterable<T0>.iid(), IInspectable.iid(), IUnknown.iid()]
        return InterfaceDescriptor<WwwFormUrlDecoder>("WwwFormUrlDecoder", IWwwFormUrlDecoderRuntimeClass.iid(), ancestors, { raw => WwwFormUrlDecoder.fromAbiTake(raw) }, { raw => WwwFormUrlDecoder.viewOf(raw) })
    }

    public func defaultInterface(): IWwwFormUrlDecoderRuntimeClass {
        IWwwFormUrlDecoderRuntimeClass.viewOf(asRaw())
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "rc(Windows.Foundation.WwwFormUrlDecoder;{D45A0451-F225-4542-9296-0E1DF5D254DF})"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.WwwFormUrlDecoder", WwwFormUrlDecoder.signature(), IWwwFormUrlDecoderRuntimeClass.iid())
    }

    public static func activationFactory(): Option<IActivationFactory> {
        windows_interface.getActivationFactoryByName<IActivationFactory>(WwwFormUrlDecoder.runtimeName(), IActivationFactory.descriptor()).ok()
    }

    public static func isAgile(): Bool {
        true
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIWwwFormUrlDecoderRuntimeClass(): IWwwFormUrlDecoderRuntimeClass {
        IWwwFormUrlDecoderRuntimeClass(asRaw())
    }

    public func asIIterable(): Foundation_Collections.IIterable<IWwwFormUrlDecoderEntry> {
        Foundation_Collections.IIterable<IWwwFormUrlDecoderEntry>(asRaw())
    }

    public func asIVectorView(): Foundation_Collections.IVectorView<IWwwFormUrlDecoderEntry> {
        Foundation_Collections.IVectorView<IWwwFormUrlDecoderEntry>(asRaw())
    }

    public func asIIterable(): Foundation_Collections.IIterable<T0> {
        Foundation_Collections.IIterable<T0>(asRaw())
    }

    public func intoIterator(): Iterator<IWwwFormUrlDecoderEntry> {
        asIIterable().intoIterator()
    }

    public func iterator(): Iterator<IWwwFormUrlDecoderEntry> {
        intoIterator()
    }

    public static unsafe func CreateWwwFormUrlDecoder(query: CPointer<UInt16>): WwwFormUrlDecoder {
        try (factory = windows_interface.getActivationFactoryByName<IWwwFormUrlDecoderRuntimeClassFactory>(WwwFormUrlDecoder.runtimeName(), IWwwFormUrlDecoderRuntimeClassFactory.descriptor()).unwrap()) {
            return factory.CreateWwwFormUrlDecoder(query)
        }
    }

    public unsafe func GetFirstValueByName(phstrValue: CPointer<UInt16>): CPointer<UInt16> {
        return defaultInterface().GetFirstValueByName(phstrValue)
    }

    public unsafe func First(): Foundation_Collections.IIterator<T> {
        return asIIterable().First()
    }

    public unsafe func GetAt(index: UInt32): T {
        return asIVectorView().GetAt(index)
    }

    public unsafe func Size(): UInt32 {
        return asIVectorView().Size()
    }

    public unsafe func IndexOf(value: T, index: CPointer<UInt32>): Bool {
        return asIVectorView().IndexOf(value, index)
    }

    public unsafe func GetMany(startIndex: UInt32, items: CPointer<T>): UInt32 {
        return asIVectorView().GetMany(startIndex, items)
    }
}

@When[Windows_Foundation == "on"]
public class WwwFormUrlDecoderEntry <: InterfaceWrapperBase & ComInterface & windows_interface.RuntimeType & windows_core.RuntimeType {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): WwwFormUrlDecoderEntry {
        WwwFormUrlDecoderEntry(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): WwwFormUrlDecoderEntry {
        WwwFormUrlDecoderEntry(raw)
    }

    public static func iid(): GUID {
        IWwwFormUrlDecoderEntry.iid()
    }

    public static func runtimeName(): String {
        "Windows.Foundation.WwwFormUrlDecoderEntry"
    }

    public static func descriptor(): InterfaceDescriptor<WwwFormUrlDecoderEntry> {
        let ancestors = [IWwwFormUrlDecoderEntry.iid(), IInspectable.iid(), IUnknown.iid()]
        return InterfaceDescriptor<WwwFormUrlDecoderEntry>("WwwFormUrlDecoderEntry", IWwwFormUrlDecoderEntry.iid(), ancestors, { raw => WwwFormUrlDecoderEntry.fromAbiTake(raw) }, { raw => WwwFormUrlDecoderEntry.viewOf(raw) })
    }

    public func defaultInterface(): IWwwFormUrlDecoderEntry {
        IWwwFormUrlDecoderEntry.viewOf(asRaw())
    }

    public static func abiType(): String {
        "CPointer<Unit>"
    }

    public static func signature(): String {
        "rc(Windows.Foundation.WwwFormUrlDecoderEntry;{125E7431-F678-4E8E-B670-20A9B06C512D})"
    }

    public static func runtimeType(): RuntimeTypeContract {
        RuntimeTypeContract("Windows.Foundation.WwwFormUrlDecoderEntry", WwwFormUrlDecoderEntry.signature(), IWwwFormUrlDecoderEntry.iid())
    }

    public static func activationFactory(): Option<IActivationFactory> {
        windows_interface.getActivationFactoryByName<IActivationFactory>(WwwFormUrlDecoderEntry.runtimeName(), IActivationFactory.descriptor()).ok()
    }

    public static func isAgile(): Bool {
        true
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public func asIWwwFormUrlDecoderEntry(): IWwwFormUrlDecoderEntry {
        IWwwFormUrlDecoderEntry(asRaw())
    }

    public unsafe func Name(): CPointer<UInt16> {
        return defaultInterface().Name()
    }

    public unsafe func Value(): CPointer<UInt16> {
        return defaultInterface().Value()
    }
}
