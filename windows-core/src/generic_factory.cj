package windows_core

let IID_IGENERICFACTORY = GUID.fromValues(0x00000035u32, 0x0000u16, 0x0000u16, 0xC0u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x46u8)

func takeIGenericFactoryFromAbi(raw: CPointer<Unit>): IGenericFactory {
    IGenericFactory.fromAbiTake(raw)
}

func viewIGenericFactory(raw: CPointer<Unit>): IGenericFactory {
    IGenericFactory.viewOf(raw)
}

@C
public struct IGenericFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var ActivateInstance: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }

    public init() {}
}

public class IGenericFactory <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>) {
        super(raw)
    }

    private init(raw: CPointer<Unit>, takeOwnership!: Bool) {
        super(raw, takeOwnership: takeOwnership)
    }

    public static func fromAbiTake(raw: CPointer<Unit>): IGenericFactory {
        IGenericFactory(raw, takeOwnership: true)
    }

    public static func viewOf(raw: CPointer<Unit>): IGenericFactory {
        IGenericFactory(raw)
    }

    public static func iid(): GUID {
        IID_IGENERICFACTORY
    }

    public static func descriptor(): InterfaceDescriptor<IGenericFactory> {
        InterfaceDescriptor<IGenericFactory>(
            "IGenericFactory",
            IID_IGENERICFACTORY,
            IInspectable.descriptor(),
            takeIGenericFactoryFromAbi,
            viewIGenericFactory
        )
    }

    public unsafe func vtbl(): IGenericFactoryVtbl {
        readVtbl<IGenericFactoryVtbl>(IGenericFactoryVtbl())
    }

    public unsafe func activateInstanceRaw(result: CPointer<CPointer<Unit>>): HRESULT {
        let liveRaw = asRaw()
        if (liveRaw.isNull()) {
            return E_POINTER
        }
        let v = vtbl()
        HRESULT(v.ActivateInstance(liveRaw, result))
    }

    public unsafe func ActivateInstance<T>(descriptor: InterfaceDescriptor<T>): Result<T> where T <: ComInterface {
        var raw = CPointer<Unit>()
        let hr = activateInstanceRaw(CPointer<CPointer<Unit>>(inout raw))
        if (hr.failed()) {
            return Result<T>.Err(WinError.fromHRESULT(hr))
        }
        if (raw.isNull()) {
            return Result<T>.Err(WinError(E_POINTER))
        }
        if (descriptor.iid == IInspectable.iid()) {
            return Result<T>.Ok(descriptor.takeFromAbi(raw))
        }
        match (unsafe { queryInterfaceResult(raw, descriptor) }) {
            case QueryResult<InterfaceHandle<T>>.Ok(pointer) =>
                interfaceHandleReleaseRaw(raw)
                return Result<T>.Ok(descriptor.takeFromAbi(pointer.intoAbi()))
            case QueryResult<InterfaceHandle<T>>.Err(error) =>
                interfaceHandleReleaseRaw(raw)
                return Result<T>.Err(WinError.fromHRESULT(error))
        }
    }
}

extend IGenericFactory <: Interface<IGenericFactory> {}
