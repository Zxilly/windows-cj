package windows_canvas

import windows_canvas_bindings.Win32.Graphics.Direct2D.{
    Apis as D2DApis,
    ID2D1Factory1,
    ID2D1Device,
    ID2D1Factory1Vtbl,
    ID2D1StrokeStyle1,
    D2D1_FACTORY_OPTIONS,
    D2D1_STROKE_STYLE_PROPERTIES1
}
import windows_canvas_bindings.Win32.Graphics.Direct3D11.{Apis as D3D11Apis, ID3D11Device}
import windows_canvas_bindings.Win32.Graphics.DirectWrite.{Apis as DWriteApis, IDWriteFactory}
import windows_canvas_bindings.Win32.Graphics.Dxgi.{
    IDXGIDevice,
    IDXGIAdapter,
    IDXGIFactory2,
    IDXGIDeviceVtbl,
    IDXGIObjectVtbl
}
import windows_canvas_bindings.Win32.Foundation.HMODULE

import windows_core.{HRESULT, GUID, queryInterfaceRaw, WindowsException, E_NOINTERFACE}

// --- Scalar D3D / D2D / DXGI / DWrite constants (not surfaced by the facade) ---
const D3D_DRIVER_TYPE_HARDWARE: Int32 = 1
const D3D_DRIVER_TYPE_WARP: Int32 = 5
const D3D11_CREATE_DEVICE_BGRA_SUPPORT: UInt32 = 0x20
const D3D_FEATURE_LEVEL_11_0: UInt32 = 0xb000
const D3D11_SDK_VERSION: UInt32 = 7
const D2D1_FACTORY_TYPE_SINGLE_THREADED: Int32 = 0
const D2D1_DEVICE_CONTEXT_OPTIONS_NONE: Int32 = 0
const DWRITE_FACTORY_TYPE_SHARED: Int32 = 0

// Well-known IIDs (canonical string form; the run-time analogue of compile-time
// GUID literals).
const IID_ID2D1Factory1: String = "bb12d362-daee-4b9a-aa1d-14ba401cfa1f"
const IID_IDXGIDevice: String = "54ec77fa-1377-44e6-8c32-88fd5f44c84c"
const IID_IDXGIFactory2: String = "50c83a1c-e072-4c48-87b0-3630fa36a6d0"
const IID_IDWriteFactory: String = "b859ee5a-d838-4b5b-a2e8-1adc7d93db48"

// QueryInterface a raw COM pointer for the given IID, returning the AddRef'd
// interface pointer or throwing E_NOINTERFACE (the reference's `cast::<T>()`).
func castRaw(source: CPointer<Unit>, iid: String): CPointer<Unit> {
    match (unsafe { queryInterfaceRaw(source, GUID.parse(iid)) }) {
        case Some(raw) => raw
        case None => throw WindowsException(E_NOINTERFACE)
    }
}

// Shared GPU device with automatic device-lost recovery.
//
// Encapsulates D3D11 device + D2D1 factory + D2D1 device creation. Provides the
// foundation for all canvas rendering operations.
//
// Cangjie paradigm note (equivalent): the reference owns its five COM
// interfaces by value and releases them on drop. Here each interface is held as
// a GC-managed binding wrapper created with `takeOwnership: true`, so the
// underlying COM object is Released exactly once when the wrapper is finalized.
public class GpuDevice {
    let d3dDevice: ID3D11Device
    let d2dFactory: ID2D1Factory1
    let d2dDevice: ID2D1Device
    let dxgiFactory: IDXGIFactory2
    let dwriteFactory: IDWriteFactory

    private init(
        d3dDevice: ID3D11Device,
        d2dFactory: ID2D1Factory1,
        d2dDevice: ID2D1Device,
        dxgiFactory: IDXGIFactory2,
        dwriteFactory: IDWriteFactory
    ) {
        this.d3dDevice = d3dDevice
        this.d2dFactory = d2dFactory
        this.d2dDevice = d2dDevice
        this.dxgiFactory = dxgiFactory
        this.dwriteFactory = dwriteFactory
    }

    // Create a GPU device with default settings (hardware, BGRA support).
    public static func create(): GpuDevice {
        return GpuDevice.createInternal(false)
    }

    // Create a software (WARP) device - useful for testing or headless rendering.
    public static func createWarp(): GpuDevice {
        return GpuDevice.createInternal(true)
    }

    private static func createInternal(software: Bool): GpuDevice {
        let driverType = if (software) {
            D3D_DRIVER_TYPE_WARP
        } else {
            D3D_DRIVER_TYPE_HARDWARE
        }

        // D3D11CreateDevice(None, type, None software module, BGRA_SUPPORT,
        // [FL_11_0], 1, SDK_VERSION, &device, None, None).
        var featureLevels = Array<UInt32>(1, repeat: D3D_FEATURE_LEVEL_11_0)
        let flHandle = unsafe { acquireArrayRawData(featureLevels) }
        var d3dRaw = CPointer<Unit>()
        try {
            unsafe {
                let hr = D3D11Apis.D3D11CreateDevice(
                    CPointer<Unit>(),
                    driverType,
                    HMODULE(),
                    D3D11_CREATE_DEVICE_BGRA_SUPPORT,
                    CPointer<Unit>(flHandle.pointer),
                    1,
                    D3D11_SDK_VERSION,
                    CPointer<Unit>(CPointer<CPointer<Unit>>(inout d3dRaw)),
                    CPointer<Unit>(),
                    CPointer<Unit>()
                )
                HRESULT(hr).check()
            }
        } finally {
            unsafe { releaseArrayRawData(flHandle) }
        }
        let d3dDevice = ID3D11Device(d3dRaw, takeOwnership: true)

        // D2D1CreateFactory(SINGLE_THREADED, IID_ID2D1Factory1, &options, &out).
        var options = D2D1_FACTORY_OPTIONS()
        var factoryIid = GUID.parse(IID_ID2D1Factory1)
        var factoryRaw = CPointer<Unit>()
        unsafe {
            D2DApis.D2D1CreateFactoryChecked(
                D2D1_FACTORY_TYPE_SINGLE_THREADED,
                CPointer<Unit>(CPointer<GUID>(inout factoryIid)),
                CPointer<Unit>(CPointer<D2D1_FACTORY_OPTIONS>(inout options)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout factoryRaw))
            )
        }
        let d2dFactory = ID2D1Factory1(factoryRaw, takeOwnership: true)

        // dxgiDevice = d3dDevice.cast::<IDXGIDevice>().
        let dxgiDeviceRaw = castRaw(d3dRaw, IID_IDXGIDevice)
        let dxgiDevice = IDXGIDevice(dxgiDeviceRaw, takeOwnership: true)

        // d2dDevice = factory.CreateDevice(dxgiDevice).
        var d2dDeviceRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1Factory1Vtbl>>(factoryRaw).read().read()
            let hr = vtbl.CreateDevice(
                factoryRaw,
                dxgiDeviceRaw,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout d2dDeviceRaw))
            )
            HRESULT(hr).check()
        }
        let d2dDevice = ID2D1Device(d2dDeviceRaw, takeOwnership: true)

        // adapter = dxgiDevice.GetAdapter().
        var adapterRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<IDXGIDeviceVtbl>>(dxgiDeviceRaw).read().read()
            let hr = vtbl.GetAdapter(
                dxgiDeviceRaw,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout adapterRaw))
            )
            HRESULT(hr).check()
        }
        let adapter = IDXGIAdapter(adapterRaw, takeOwnership: true)

        // dxgiFactory = adapter.GetParent::<IDXGIFactory2>().
        var dxgiFactoryIid = GUID.parse(IID_IDXGIFactory2)
        var dxgiFactoryRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<IDXGIObjectVtbl>>(adapterRaw).read().read()
            let hr = vtbl.GetParent(
                adapterRaw,
                CPointer<Unit>(CPointer<GUID>(inout dxgiFactoryIid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout dxgiFactoryRaw))
            )
            HRESULT(hr).check()
        }
        let dxgiFactory = IDXGIFactory2(dxgiFactoryRaw, takeOwnership: true)

        // DWriteCreateFactory(SHARED, IID_IDWriteFactory, &out).
        var dwriteIid = GUID.parse(IID_IDWriteFactory)
        var dwriteRaw = CPointer<Unit>()
        unsafe {
            let hr = DWriteApis.DWriteCreateFactory(
                DWRITE_FACTORY_TYPE_SHARED,
                CPointer<Unit>(CPointer<GUID>(inout dwriteIid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout dwriteRaw))
            )
            HRESULT(hr).check()
        }
        let dwriteFactory = IDWriteFactory(dwriteRaw, takeOwnership: true)

        // The transient adapter/dxgiDevice wrappers stay owned by GC and are
        // Released when finalized; keep them referenced via the locals above so
        // they are not collected before construction completes.
        return GpuDevice(d3dDevice, d2dFactory, d2dDevice, dxgiFactory, dwriteFactory)
    }

    // Create a composition swap chain for the given dimensions.
    public func createSwapChain(width: UInt32, height: UInt32): SwapChain {
        return SwapChain.newComposition(this, width, height)
    }

    // Create an HWND-targeting swap chain for standalone windowed rendering.
    //
    // `hwnd` must be a valid window handle for the lifetime of the returned
    // `SwapChain`.
    public func createSwapChainForHwnd(hwnd: CPointer<Unit>, width: UInt32, height: UInt32): SwapChain {
        return SwapChain.newForHwnd(this, hwnd, width, height)
    }

    // Access the raw D3D11 device.
    public func d3dDeviceRaw(): CPointer<Unit> {
        return this.d3dDevice.asRaw()
    }

    // Access the raw D2D1 device.
    public func d2dDeviceRaw(): CPointer<Unit> {
        return this.d2dDevice.asRaw()
    }

    // Access the raw D2D1 factory.
    public func d2dFactoryRaw(): CPointer<Unit> {
        return this.d2dFactory.asRaw()
    }

    // Access the raw DXGI factory.
    public func dxgiFactoryRaw(): CPointer<Unit> {
        return this.dxgiFactory.asRaw()
    }

    // Access the raw DWrite factory.
    public func dwriteFactoryRaw(): CPointer<Unit> {
        return this.dwriteFactory.asRaw()
    }

    // Create a stroke style from a builder.
    //
    // Stroke styles are device-independent and can be reused across frames.
    public func createStrokeStyle(builder: StrokeStyleBuilder): StrokeStyle {
        var props = builder.toAbi()
        let factoryRaw = this.d2dFactory.asRaw()
        var styleRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1Factory1Vtbl>>(factoryRaw).read().read()
            // CreateStrokeStyle(props1, dashes=None, dashCount=0, &out).
            let hr = vtbl.CreateStrokeStyle(
                factoryRaw,
                CPointer<Unit>(CPointer<D2D1_STROKE_STYLE_PROPERTIES1>(inout props)),
                CPointer<Unit>(),
                0,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout styleRaw))
            )
            HRESULT(hr).check()
        }
        return StrokeStyle(ID2D1StrokeStyle1(styleRaw, takeOwnership: true))
    }
}
