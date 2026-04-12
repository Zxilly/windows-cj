package windows_core

let IID_IGENERICFACTORY = GUID.fromValues(0x00000035u32, 0x0000u16, 0x0000u16, 0xC0u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x00u8, 0x46u8)

func wrapIGenericFactoryOwned(raw: CPointer<Unit>): IGenericFactory {
    IGenericFactory(raw, ownsReference: true)
}

func wrapIGenericFactoryBorrowed(raw: CPointer<Unit>): IGenericFactory {
    IGenericFactory(raw)
}

@C
public struct IGenericFactoryVtbl {
    public var base_: IInspectableVtbl = IInspectableVtbl()
    public var ActivateInstance: CFunc<(CPointer<Unit>, CPointer<CPointer<Unit>>) -> Int32> = { _, _ => E_NOTIMPL.value }

    public init() {}
}

public class IGenericFactory <: InterfaceWrapperBase & ComInterface {
    public init(raw: CPointer<Unit>, ownsReference!: Bool = false) {
        super(raw, ownsReference: ownsReference)
    }

    public static func fromRaw(raw: CPointer<Unit>): IGenericFactory {
        IGenericFactory(raw, ownsReference: true)
    }

    public static func fromRawBorrowed(raw: CPointer<Unit>): IGenericFactory {
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
            wrapIGenericFactoryOwned,
            wrapIGenericFactoryBorrowed
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
            return Result<T>.Ok(descriptor.wrapOwned(raw))
        }
        match (unsafe { queryInterfaceResult(raw, descriptor) }) {
            case QueryResult<ComPtr<T>>.Ok(pointer) =>
                comPtrReleaseRaw(raw)
                return Result<T>.Ok(descriptor.wrapOwned(pointer.detach()))
            case QueryResult<ComPtr<T>>.Err(error) =>
                comPtrReleaseRaw(raw)
                return Result<T>.Err(WinError.fromHRESULT(error))
        }
    }
}

extend IGenericFactory <: Interface<IGenericFactory> {}
