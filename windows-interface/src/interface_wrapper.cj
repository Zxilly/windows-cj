package windows_interface

import std.sync.AtomicBool
import windows_result.*
import windows_result.Error as WinResultError
import windows_strings.*

class OwnedHandleState {
    private let raw: CPointer<Unit>
    private let released = AtomicBool(false)

    public init(raw: CPointer<Unit>) {
        this.raw = raw
    }

    public func releaseHandle(): UInt32 {
        if (!released.compareAndSwap(false, true) || raw.isNull()) {
            return 0u32
        }
        releaseRaw(raw)
    }

    public func detachHandle(): CPointer<Unit> {
        if (!released.compareAndSwap(false, true) || raw.isNull()) {
            return CPointer<Unit>()
        }
        raw
    }

    ~init() {
        // COM Release can re-enter registry-backed Cangjie code. Finalizers
        // cannot use synchronization, so owned interface wrappers require
        // deterministic close/release by their Resource owner.
    }
}

func addRefRaw(raw: CPointer<Unit>): UInt32 {
    if (raw.isNull()) {
        return 0u32
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.AddRef(raw)
    }
}

func releaseRaw(raw: CPointer<Unit>): UInt32 {
    if (raw.isNull()) {
        return 0u32
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        vtbl.Release(raw)
    }
}

func releaseFailedOutRaw(hr: HRESULT, raw: CPointer<Unit>): Unit {
    if (hr.failed() && raw.isNotNull()) {
        let _ = releaseRaw(raw)
    }
}

func requireOwnedInterfaceRaw(raw: CPointer<Unit>): CPointer<Unit> {
    if (raw.isNull()) {
        throw WindowsException(E_POINTER)
    }
    raw
}

func takeIUnknownFromAbi(raw: CPointer<Unit>): IUnknown {
    IUnknown.fromAbiTake(raw)
}

func viewIUnknown(raw: CPointer<Unit>): IUnknown {
    IUnknown.viewOf(raw)
}

func takeIInspectableFromAbi(raw: CPointer<Unit>): IInspectable {
    IInspectable.fromAbiTake(raw)
}

func viewIInspectable(raw: CPointer<Unit>): IInspectable {
    IInspectable.viewOf(raw)
}

@C
public struct IUnknownVtbl {
    public var QueryInterface: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOINTERFACE.value }
    public var AddRef: CFunc<(CPointer<Unit>) -> UInt32> = { _ => 0u32 }
    public var Release: CFunc<(CPointer<Unit>) -> UInt32> = { _ => 0u32 }

    public init() {}
}

@C
public struct IInspectableVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var GetIids: CFunc<(CPointer<Unit>, CPointer<UInt32>, CPointer<CPointer<GUID>>) -> Int32> = { _, countPtr, iidsPtr =>
        unsafe {
            countPtr.write(0u32)
            iidsPtr.write(CPointer<GUID>())
        }
        0i32
    }
    public var GetRuntimeClassName: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, valuePtr =>
        unsafe { valuePtr.write(CPointer<Unit>()) }
        0i32
    }
    public var GetTrustLevel: CFunc<(CPointer<Unit>, CPointer<Int32>) -> Int32> = { _, valuePtr =>
        unsafe { valuePtr.write(0i32) }
        0i32
    }

    public init() {}
}

@C
public struct IAgileObjectVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()

    public init() {}
}

@C
public struct IAgileReferenceVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Resolve: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }

    public init() {}
}

@C
public struct IMarshalVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var GetUnmarshalClass: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<Unit>, UInt32, CPointer<Unit>, UInt32, CPointer<GUID>) -> Int32> = { _, _, _, _, _, _, _ => E_NOTIMPL.value }
    public var GetMarshalSizeMax: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<Unit>, UInt32, CPointer<Unit>, UInt32, CPointer<UInt32>) -> Int32> = { _, _, _, _, _, _, _ => E_NOTIMPL.value }
    public var MarshalInterface: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<GUID>, CPointer<Unit>, UInt32, CPointer<Unit>, UInt32) -> Int32> = { _, _, _, _, _, _, _ => E_NOTIMPL.value }
    public var UnmarshalInterface: CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _, _ => E_NOTIMPL.value }
    public var ReleaseMarshalData: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32> = { _, _ => E_NOTIMPL.value }
    public var DisconnectObject: CFunc<(CPointer<Unit>, UInt32) -> Int32> = { _, _ => E_NOTIMPL.value }

    public init() {}
}

@C
public struct IWeakReferenceVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var Resolve: CFunc<(CPointer<Unit>, CPointer<GUID>, CPointer<CPointer<Unit>>) -> Int32> = { _, _, _ => E_NOTIMPL.value }

    public init() {}
}

@C
public struct IWeakReferenceSourceVtbl {
    public var base_: IUnknownVtbl = IUnknownVtbl()
    public var GetWeakReference: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }

    public init() {}
}

func iunknownDescriptorMethods(): Array<InterfaceMethodSchema> {
    let qiParams = [
        InterfaceParameterSchema("riid", "CPointer<GUID>", "CPointer<GUID>", InterfaceParameterBridgeKind.InParam),
        InterfaceParameterSchema("ppvObject", "CPointer<CPointer<Unit>>", "CPointer<CPointer<Unit>>", InterfaceParameterBridgeKind.OutSlot)
    ]
    [
        InterfaceMethodSchema("QueryInterface", 0, qiParams, "Int32"),
        InterfaceMethodSchema("AddRef", 1, Array<InterfaceParameterSchema>(), "UInt32"),
        InterfaceMethodSchema("Release", 2, Array<InterfaceParameterSchema>(), "UInt32")
    ]
}

func iinspectableDescriptorMethods(): Array<InterfaceMethodSchema> {
    let iidsParams = [
        InterfaceParameterSchema("iidCount", "CPointer<UInt32>", "CPointer<UInt32>", InterfaceParameterBridgeKind.OutSlot),
        InterfaceParameterSchema("iids", "CPointer<CPointer<GUID>>", "CPointer<CPointer<GUID>>", InterfaceParameterBridgeKind.OutSlot)
    ]
    let nameParams = [
        InterfaceParameterSchema("className", "CPointer<CPointer<Unit>>", "CPointer<CPointer<Unit>>", InterfaceParameterBridgeKind.OutSlot)
    ]
    let trustParams = [
        InterfaceParameterSchema("trustLevel", "CPointer<Int32>", "CPointer<Int32>", InterfaceParameterBridgeKind.OutSlot)
    ]
    [
        InterfaceMethodSchema("GetIids", 3, iidsParams, "Int32"),
        InterfaceMethodSchema("GetRuntimeClassName", 4, nameParams, "Int32"),
        InterfaceMethodSchema("GetTrustLevel", 5, trustParams, "Int32")
    ]
}

func iactivationFactoryDescriptorMethods(): Array<InterfaceMethodSchema> {
    let activateParams = [
        InterfaceParameterSchema("instance", "CPointer<CPointer<Unit>>", "CPointer<CPointer<Unit>>", InterfaceParameterBridgeKind.OutSlot)
    ]
    [
        InterfaceMethodSchema("ActivateInstance", 6, activateParams, "Int32")
    ]
}

public open class InterfaceWrapperBase <: Resource {
    protected let raw_: CPointer<Unit>
    protected let ownsHandle_: Bool
    protected let allowManualRelease_: Bool
    private let ownedHandleState_: Option<OwnedHandleState>
    protected var closed_: Bool = false

    public init(raw: CPointer<Unit>) {
        this.raw_ = raw
        this.ownsHandle_ = false
        this.allowManualRelease_ = true
        this.ownedHandleState_ = None
    }

    public init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        let liveRaw = if (takeOwnership) { requireOwnedInterfaceRaw(raw) } else { raw }
        this.raw_ = liveRaw
        this.ownsHandle_ = takeOwnership
        this.allowManualRelease_ = false
        this.ownedHandleState_ = if (takeOwnership) { Some(OwnedHandleState(liveRaw)) } else { None }
    }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        let liveRaw = if (takeOwnership) { requireOwnedInterfaceRaw(raw) } else { raw }
        this.raw_ = liveRaw
        this.ownsHandle_ = takeOwnership
        this.allowManualRelease_ = allowManualRelease
        this.ownedHandleState_ = if (takeOwnership) { Some(OwnedHandleState(liveRaw)) } else { None }
    }

    public func asRaw(): CPointer<Unit> {
        if (closed_) {
            return CPointer<Unit>()
        }
        raw_
    }

    public func isClosed(): Bool {
        closed_
    }

    public func addRef(): UInt32 {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return 0u32
        }
        addRefRaw(liveRaw)
    }

    public func retainRaw(): CPointer<Unit> {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return CPointer<Unit>()
        }
        addRefRaw(liveRaw)
        liveRaw
    }

    public func intoAbi(): CPointer<Unit> {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return CPointer<Unit>()
        }
        let abiRaw = if (ownsHandle_) {
            detachOwnedHandle()
        } else {
            closed_ = true
            let _ = addRefRaw(liveRaw)
            liveRaw
        }
        closed_ = true
        abiRaw
    }

    public func release(): UInt32 {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return 0u32
        }
        if (ownsHandle_) {
            let remaining = releaseOwnedHandle()
            closed_ = true
            return remaining
        }
        if (allowManualRelease_) {
            closed_ = true
            let remaining = releaseRaw(liveRaw)
            return remaining
        }
        0u32
    }

    public unsafe func query<T>(descriptor: InterfaceDescriptor<T>): Option<T> {
        queryInterfaceAs(asRaw(), descriptor)
    }

    public unsafe func readVtbl<T>(defaultValue: T): T where T <: CType {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return defaultValue
        }
        let vtblPtr = CPointer<CPointer<T>>(liveRaw).read()
        vtblPtr.read()
    }

    public func close(): Unit {
        if (closed_) {
            return
        }
        if (ownsHandle_) {
            let _ = releaseOwnedHandle()
        }
        closed_ = true
    }

    protected func releaseOwnedHandle(): UInt32 {
        match (ownedHandleState_) {
            case Some(state) => state.releaseHandle()
            case None => 0u32
        }
    }

    protected func detachOwnedHandle(): CPointer<Unit> {
        match (ownedHandleState_) {
            case Some(state) => state.detachHandle()
            case None => CPointer<Unit>()
        }
    }

}

public open class IUnknown <: InterfaceWrapperBase & ComInterface & RuntimeName {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IUnknown {
        OwnedIUnknown(raw)
    }

    public static func viewOf(raw: CPointer<Unit>): IUnknown {
        IUnknown(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        IID_IUNKNOWN
    }

    public static func descriptor(): InterfaceDescriptor<IUnknown> {
        InterfaceDescriptor<IUnknown>("IUnknown", IID_IUNKNOWN, takeIUnknownFromAbi, viewIUnknown)
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        InterfaceDescriptorSchema(
            "IUnknown",
            IID_IUNKNOWN,
            "IUnknownVtbl",
            "IUnknown",
            "IUnknown_Impl",
            iunknownDescriptorMethods()
        )
    }

    public unsafe func vtbl(): IUnknownVtbl {
        readVtbl<IUnknownVtbl>(IUnknownVtbl())
    }

    public unsafe func queryRaw(targetIid: GUID): Option<CPointer<Unit>> {
        queryInterfaceRaw(asRaw(), targetIid)
    }
}

public open class IInspectable <: InterfaceWrapperBase & ComInterface & RuntimeName {

    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IInspectable {
        OwnedIInspectable(raw)
    }

    public static func viewOf(raw: CPointer<Unit>): IInspectable {
        IInspectable(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        IID_IINSPECTABLE
    }

    public static func descriptor(): InterfaceDescriptor<IInspectable> {
        InterfaceDescriptor<IInspectable>(
            "IInspectable",
            IID_IINSPECTABLE,
            IUnknown.descriptor(),
            takeIInspectableFromAbi,
            viewIInspectable
        )
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        InterfaceDescriptorSchema(
            "IInspectable",
            IID_IINSPECTABLE,
            IUnknown.descriptorSchema(),
            "IInspectableVtbl",
            "IInspectable",
            "IInspectable_Impl",
            iinspectableDescriptorMethods()
        )
    }

    public func asIUnknown(): IUnknown {
        IUnknown.viewOf(asRaw())
    }

    public unsafe func vtbl(): IInspectableVtbl {
        readVtbl<IInspectableVtbl>(IInspectableVtbl())
    }

    public unsafe func getIids(count: CPointer<UInt32>, values: CPointer<CPointer<GUID>>): HRESULT {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return E_POINTER
        }
        let v = vtbl()
        HRESULT(v.GetIids(liveRaw, count, values))
    }

    public unsafe func getRuntimeClassNameRaw(value: CPointer<CPointer<Unit>>): HRESULT {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return E_POINTER
        }
        let v = vtbl()
        HRESULT(v.GetRuntimeClassName(liveRaw, value))
    }

    public unsafe func getRuntimeClassName(): HString {
        var rawValue = CPointer<Unit>()
        let hr = getRuntimeClassNameRaw(CPointer<CPointer<Unit>>(inout rawValue))
        if (hr.failed()) {
            if (rawValue.isNotNull()) {
                releaseSystemHStringHandle(rawValue)
            }
            throw WindowsException(hr)
        }
        if (rawValue.isNull()) {
            return HString()
        }

        HString.fromSystemHandleTake(rawValue)
    }

    public unsafe func getTrustLevel(value: CPointer<Int32>): HRESULT {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return E_POINTER
        }
        let v = vtbl()
        HRESULT(v.GetTrustLevel(liveRaw, value))
    }
}

func takeIAgileObjectFromAbi(raw: CPointer<Unit>): IAgileObject {
    IAgileObject.fromAbiTake(raw)
}

func viewIAgileObject(raw: CPointer<Unit>): IAgileObject {
    IAgileObject.viewOf(raw)
}

func takeIAgileReferenceFromAbi(raw: CPointer<Unit>): IAgileReference {
    IAgileReference.fromAbiTake(raw)
}

func viewIAgileReference(raw: CPointer<Unit>): IAgileReference {
    IAgileReference.viewOf(raw)
}

func takeIMarshalFromAbi(raw: CPointer<Unit>): IMarshal {
    IMarshal.fromAbiTake(raw)
}

func viewIMarshal(raw: CPointer<Unit>): IMarshal {
    IMarshal.viewOf(raw)
}

func takeIWeakReferenceFromAbi(raw: CPointer<Unit>): IWeakReference {
    IWeakReference.fromAbiTake(raw)
}

func viewIWeakReference(raw: CPointer<Unit>): IWeakReference {
    IWeakReference.viewOf(raw)
}

func takeIWeakReferenceSourceFromAbi(raw: CPointer<Unit>): IWeakReferenceSource {
    IWeakReferenceSource.fromAbiTake(raw)
}

func viewIWeakReferenceSource(raw: CPointer<Unit>): IWeakReferenceSource {
    IWeakReferenceSource.viewOf(raw)
}

public open class IAgileObject <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) { super(raw) }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAgileObject { OwnedIAgileObject(raw) }
    public static func viewOf(raw: CPointer<Unit>): IAgileObject { IAgileObject(raw, takeOwnership: false, allowManualRelease: false) }
    public static func iid(): GUID { IID_IAGILEOBJECT }
    public static func descriptor(): InterfaceDescriptor<IAgileObject> {
        InterfaceDescriptor<IAgileObject>("IAgileObject", IID_IAGILEOBJECT, IUnknown.descriptor(), takeIAgileObjectFromAbi, viewIAgileObject)
    }
    public unsafe func vtbl(): IAgileObjectVtbl { readVtbl<IAgileObjectVtbl>(IAgileObjectVtbl()) }
}

public open class IAgileReference <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) { super(raw) }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IAgileReference { OwnedIAgileReference(raw) }
    public static func viewOf(raw: CPointer<Unit>): IAgileReference { IAgileReference(raw, takeOwnership: false, allowManualRelease: false) }
    public static func iid(): GUID { IID_IAGILEREFERENCE }
    public static func descriptor(): InterfaceDescriptor<IAgileReference> {
        InterfaceDescriptor<IAgileReference>("IAgileReference", IID_IAGILEREFERENCE, IUnknown.descriptor(), takeIAgileReferenceFromAbi, viewIAgileReference)
    }
    public unsafe func vtbl(): IAgileReferenceVtbl { readVtbl<IAgileReferenceVtbl>(IAgileReferenceVtbl()) }

    public unsafe func resolve<T>(descriptor: InterfaceDescriptor<T>): Result<T> where T <: ComInterface {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return Result<T>.Err(WinResultError.fromHRESULT(E_POINTER))
        }
        var iid = descriptor.iid
        var raw = CPointer<Unit>()
        let hr = HRESULT(vtbl().Resolve(liveRaw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout raw)))
        if (hr.failed()) {
            releaseFailedOutRaw(hr, raw)
            return Result<T>.Err(WinResultError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<T>.Err(WinResultError.fromHRESULT(E_POINTER))
        }
        Result<T>.Ok(descriptor.takeFromAbi(raw))
    }
}

public open class IMarshal <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) { super(raw) }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IMarshal { OwnedIMarshal(raw) }
    public static func viewOf(raw: CPointer<Unit>): IMarshal { IMarshal(raw, takeOwnership: false, allowManualRelease: false) }
    public static func iid(): GUID { IID_IMARSHAL }
    public static func descriptor(): InterfaceDescriptor<IMarshal> {
        InterfaceDescriptor<IMarshal>("IMarshal", IID_IMARSHAL, IUnknown.descriptor(), takeIMarshalFromAbi, viewIMarshal)
    }
    public unsafe func vtbl(): IMarshalVtbl { readVtbl<IMarshalVtbl>(IMarshalVtbl()) }
}

public open class IWeakReference <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) { super(raw) }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IWeakReference { OwnedIWeakReference(raw) }
    public static func viewOf(raw: CPointer<Unit>): IWeakReference { IWeakReference(raw, takeOwnership: false, allowManualRelease: false) }
    public static func iid(): GUID { IID_IWEAKREFERENCE }
    public static func descriptor(): InterfaceDescriptor<IWeakReference> {
        InterfaceDescriptor<IWeakReference>("IWeakReference", IID_IWEAKREFERENCE, IUnknown.descriptor(), takeIWeakReferenceFromAbi, viewIWeakReference)
    }
    public unsafe func vtbl(): IWeakReferenceVtbl { readVtbl<IWeakReferenceVtbl>(IWeakReferenceVtbl()) }

    public unsafe func resolve<T>(descriptor: InterfaceDescriptor<T>): Result<T> where T <: ComInterface {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return Result<T>.Err(WinResultError.fromHRESULT(E_POINTER))
        }
        var iid = descriptor.iid
        var raw = CPointer<Unit>()
        let hr = HRESULT(vtbl().Resolve(liveRaw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout raw)))
        if (hr.failed()) {
            releaseFailedOutRaw(hr, raw)
            return Result<T>.Err(WinResultError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<T>.Err(WinResultError.fromHRESULT(E_POINTER))
        }
        Result<T>.Ok(descriptor.takeFromAbi(raw))
    }
}

public open class IWeakReferenceSource <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) { super(raw) }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IWeakReferenceSource { OwnedIWeakReferenceSource(raw) }
    public static func viewOf(raw: CPointer<Unit>): IWeakReferenceSource { IWeakReferenceSource(raw, takeOwnership: false, allowManualRelease: false) }
    public static func iid(): GUID { IID_IWEAKREFERENCESOURCE }
    public static func descriptor(): InterfaceDescriptor<IWeakReferenceSource> {
        InterfaceDescriptor<IWeakReferenceSource>("IWeakReferenceSource", IID_IWEAKREFERENCESOURCE, IUnknown.descriptor(), takeIWeakReferenceSourceFromAbi, viewIWeakReferenceSource)
    }
    public unsafe func vtbl(): IWeakReferenceSourceVtbl { readVtbl<IWeakReferenceSourceVtbl>(IWeakReferenceSourceVtbl()) }

    public unsafe func getWeakReference(): Result<IWeakReference> {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return Result<IWeakReference>.Err(WinResultError.fromHRESULT(E_POINTER))
        }
        var raw = CPointer<Unit>()
        let hr = HRESULT(vtbl().GetWeakReference(liveRaw, CPointer<CPointer<Unit>>(inout raw)))
        if (hr.failed()) {
            releaseFailedOutRaw(hr, raw)
            return Result<IWeakReference>.Err(WinResultError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<IWeakReference>.Err(WinResultError.fromHRESULT(E_POINTER))
        }
        Result<IWeakReference>.Ok(IWeakReference.fromAbiTake(raw))
    }
}

@C
public struct IActivationFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var ActivateInstance: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }

    public init() {}
}

func takeIActivationFactoryFromAbi(raw: CPointer<Unit>): IActivationFactory {
    IActivationFactory.fromAbiTake(raw)
}

func viewIActivationFactory(raw: CPointer<Unit>): IActivationFactory {
    IActivationFactory.viewOf(raw)
}

public open class IActivationFactory <: InterfaceWrapperBase & ComInterface & RuntimeName {

    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    protected init(raw: CPointer<Unit>, takeOwnership!: Bool, allowManualRelease!: Bool) {
        super(raw, takeOwnership: takeOwnership, allowManualRelease: allowManualRelease)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IActivationFactory {
        OwnedIActivationFactory(raw)
    }

    public static func viewOf(raw: CPointer<Unit>): IActivationFactory {
        IActivationFactory(raw, takeOwnership: false, allowManualRelease: false)
    }

    public static func iid(): GUID {
        IID_IACTIVATIONFACTORY
    }

    public static func descriptor(): InterfaceDescriptor<IActivationFactory> {
        InterfaceDescriptor<IActivationFactory>(
            "IActivationFactory",
            IID_IACTIVATIONFACTORY,
            IInspectable.descriptor(),
            takeIActivationFactoryFromAbi,
            viewIActivationFactory
        )
    }

    public static func descriptorSchema(): InterfaceDescriptorSchema {
        InterfaceDescriptorSchema(
            "IActivationFactory",
            IID_IACTIVATIONFACTORY,
            IInspectable.descriptorSchema(),
            "IActivationFactoryVtbl",
            "IActivationFactory",
            "IActivationFactory_Impl",
            iactivationFactoryDescriptorMethods()
        )
    }

    public func asIInspectable(): IInspectable {
        IInspectable.viewOf(asRaw())
    }

    public unsafe func vtbl(): IActivationFactoryVtbl {
        readVtbl<IActivationFactoryVtbl>(IActivationFactoryVtbl())
    }

    public unsafe func activateInstance(result: CPointer<CPointer<Unit>>): HRESULT {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return E_POINTER
        }
        let v = vtbl()
        HRESULT(v.ActivateInstance(liveRaw, result))
    }

    public unsafe func activateInstance<T>(descriptor: InterfaceDescriptor<T>): Result<T> where T <: ComInterface {
        var raw = CPointer<Unit>()
        let hr = activateInstance(CPointer<CPointer<Unit>>(inout raw))
        if (hr.failed()) {
            releaseFailedOutRaw(hr, raw)
            return Result<T>.Err(WinResultError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<T>.Err(WinResultError.fromHRESULT(E_POINTER))
        }
        if (descriptor.iid == IInspectable.iid()) {
            return Result<T>.Ok(descriptor.takeFromAbi(raw))
        }

        var iid = descriptor.iid
        var projectedRaw = CPointer<Unit>()
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        let vtbl = vtblPtr.read()
        let queryHr = HRESULT(vtbl.QueryInterface(raw, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout projectedRaw)))
        let _ = releaseRaw(raw)
        if (queryHr.failed()) {
            if (projectedRaw.isNotNull()) {
                let _ = releaseRaw(projectedRaw)
            }
            return Result<T>.Err(WinResultError.fromHRESULT(queryHr))
        }
        if (projectedRaw.isNull()) {
            return Result<T>.Err(WinResultError.fromHRESULT(E_POINTER))
        }
        Result<T>.Ok(descriptor.takeFromAbi(projectedRaw))
    }
}

private class OwnedIUnknown <: IUnknown {
    public init(raw: CPointer<Unit>) {
        super(raw, takeOwnership: true, allowManualRelease: false)
    }
}

private class OwnedIInspectable <: IInspectable {
    public init(raw: CPointer<Unit>) {
        super(raw, takeOwnership: true, allowManualRelease: false)
    }
}

private class OwnedIAgileObject <: IAgileObject {
    public init(raw: CPointer<Unit>) {
        super(raw, takeOwnership: true, allowManualRelease: false)
    }
}

private class OwnedIAgileReference <: IAgileReference {
    public init(raw: CPointer<Unit>) {
        super(raw, takeOwnership: true, allowManualRelease: false)
    }
}

private class OwnedIMarshal <: IMarshal {
    public init(raw: CPointer<Unit>) {
        super(raw, takeOwnership: true, allowManualRelease: false)
    }
}

private class OwnedIWeakReference <: IWeakReference {
    public init(raw: CPointer<Unit>) {
        super(raw, takeOwnership: true, allowManualRelease: false)
    }
}

private class OwnedIWeakReferenceSource <: IWeakReferenceSource {
    public init(raw: CPointer<Unit>) {
        super(raw, takeOwnership: true, allowManualRelease: false)
    }
}

private class OwnedIActivationFactory <: IActivationFactory {
    public init(raw: CPointer<Unit>) {
        super(raw, takeOwnership: true, allowManualRelease: false)
    }
}

public unsafe func queryInterfaceRaw(source: CPointer<Unit>, targetIid: GUID): Option<CPointer<Unit>> {
    if (source.isNull()) {
        return None
    }

    var iid = targetIid
    var result = CPointer<Unit>()
    let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(source).read()
    let vtbl = vtblPtr.read()
    let hr = HRESULT(vtbl.QueryInterface(source, CPointer<GUID>(inout iid), CPointer<CPointer<Unit>>(inout result)))

    if (hr.succeeded() && !result.isNull()) {
        Some(result)
    } else {
        if (result.isNotNull()) {
            let _ = releaseRaw(result)
        }
        None
    }
}

public unsafe func queryInterfaceAs<T>(source: CPointer<Unit>, descriptor: InterfaceDescriptor<T>): Option<T> {
    match (queryInterfaceRaw(source, descriptor.iid)) {
        case Some(raw) => Some(descriptor.takeFromAbi(raw))
        case None => None
    }
}

public unsafe func queryInterfaceAs<T>(source: ComInterface, descriptor: InterfaceDescriptor<T>): Option<T> {
    queryInterfaceAs(source.asRaw(), descriptor)
}
