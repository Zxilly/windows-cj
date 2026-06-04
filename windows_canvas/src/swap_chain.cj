package windows_canvas

import windows_canvas_bindings.Win32.Graphics.Direct2D.{
    ID2D1DeviceContext,
    ID2D1Bitmap,
    ID2D1SolidColorBrush,
    ID2D1DeviceVtbl,
    ID2D1DeviceContextVtbl,
    D2D1_BITMAP_PROPERTIES1
}
import windows_canvas_bindings.Win32.Graphics.Direct2D.Common.{D2D1_COLOR_F, D2D1_PIXEL_FORMAT}
import windows_canvas_bindings.Win32.Graphics.Dxgi.{
    IDXGISwapChain1,
    IDXGISwapChain2,
    IDXGISurface,
    IDXGIFactory2Vtbl,
    IDXGISwapChainVtbl,
    IDXGISwapChain2Vtbl,
    DXGI_SWAP_CHAIN_DESC1,
    DXGI_MATRIX_3X2_F
}

import windows_canvas_bindings.Win32.Foundation.HWND

import windows_core.{HRESULT, GUID, queryInterfaceRaw}

// --- Scalar DXGI / D2D constants (not surfaced by the facade) ---
const DXGI_FORMAT_UNKNOWN: Int32 = 0
const DXGI_FORMAT_B8G8R8A8_UNORM: Int32 = 87
const DXGI_USAGE_RENDER_TARGET_OUTPUT: UInt32 = 0x20
const DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL: Int32 = 3
const DXGI_ALPHA_MODE_PREMULTIPLIED: Int32 = 1
const D2D1_ALPHA_MODE_PREMULTIPLIED: Int32 = 1
const D2D1_BITMAP_OPTIONS_TARGET: Int32 = 1
const D2D1_BITMAP_OPTIONS_CANNOT_DRAW: Int32 = 2

const IID_IDXGISurface: String = "cafcb56c-6ac3-4889-bf47-9e23bbd260ec"
const IID_IDXGISwapChain2: String = "a8be2ac4-199f-4946-b331-79599fb98de7"

// A mutable, shared device-lost flag. A small class so a single instance can be
// shared between the SwapChain and the DrawingSession it hands out (the
// reference uses `Cell<bool>` for the same purpose).
class DeviceLostFlag {
    var lost: Bool = false
}

// Manages a DXGI swap chain with safe resize and present.
//
// Cangjie paradigm note (equivalent): the COM interfaces are held as
// GC-managed binding wrappers (Release on finalize); the `Cell<bool>` of the
// reference becomes a small shared class so the begin-draw session can flip it.
public class SwapChain {
    var swapChain: IDXGISwapChain1
    let d2dContext: ID2D1DeviceContext
    let deviceLostFlag: DeviceLostFlag
    var widthValue: UInt32
    var heightValue: UInt32
    var dpiX: Float32 = 96.0
    var dpiY: Float32 = 96.0

    private init(
        swapChain: IDXGISwapChain1,
        d2dContext: ID2D1DeviceContext,
        width: UInt32,
        height: UInt32
    ) {
        this.swapChain = swapChain
        this.d2dContext = d2dContext
        this.deviceLostFlag = DeviceLostFlag()
        this.widthValue = width
        this.heightValue = height
    }

    static func newComposition(device: GpuDevice, width: UInt32, height: UInt32): SwapChain {
        var desc = DXGI_SWAP_CHAIN_DESC1()
        desc.Width = width
        desc.Height = height
        desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM
        desc.SampleDesc.Count = 1
        desc.SampleDesc.Quality = 0
        desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
        desc.BufferCount = 2
        desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL
        desc.AlphaMode = DXGI_ALPHA_MODE_PREMULTIPLIED

        let factoryRaw = device.dxgiFactoryRaw()
        let d3dRaw = device.d3dDeviceRaw()
        var swapRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<IDXGIFactory2Vtbl>>(factoryRaw).read().read()
            let hr = vtbl.CreateSwapChainForComposition(
                factoryRaw,
                d3dRaw,
                CPointer<Unit>(CPointer<DXGI_SWAP_CHAIN_DESC1>(inout desc)),
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout swapRaw))
            )
            HRESULT(hr).check()
        }
        let swapChain = IDXGISwapChain1(swapRaw, takeOwnership: true)
        return SwapChain.fromSwapChain(device, swapChain, width, height)
    }

    static func newForHwnd(device: GpuDevice, hwnd: CPointer<Unit>, width: UInt32, height: UInt32): SwapChain {
        var desc = DXGI_SWAP_CHAIN_DESC1()
        desc.Width = width
        desc.Height = height
        desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM
        desc.SampleDesc.Count = 1
        desc.SampleDesc.Quality = 0
        desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
        desc.BufferCount = 2
        desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL

        let factoryRaw = device.dxgiFactoryRaw()
        let d3dRaw = device.d3dDeviceRaw()
        var hwndValue = HWND()
        hwndValue.Value = hwnd
        var swapRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<IDXGIFactory2Vtbl>>(factoryRaw).read().read()
            // CreateSwapChainForHwnd(device, hwnd, &desc, fullscreen=None,
            // restrictToOutput=None, &out).
            let hr = vtbl.CreateSwapChainForHwnd(
                factoryRaw,
                d3dRaw,
                hwndValue,
                CPointer<Unit>(CPointer<DXGI_SWAP_CHAIN_DESC1>(inout desc)),
                CPointer<Unit>(),
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout swapRaw))
            )
            HRESULT(hr).check()
        }
        let swapChain = IDXGISwapChain1(swapRaw, takeOwnership: true)
        return SwapChain.fromSwapChain(device, swapChain, width, height)
    }

    static func fromSwapChain(
        device: GpuDevice,
        swapChain: IDXGISwapChain1,
        width: UInt32,
        height: UInt32
    ): SwapChain {
        let d2dDeviceRaw = device.d2dDeviceRaw()
        var contextRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceVtbl>>(d2dDeviceRaw).read().read()
            let hr = vtbl.CreateDeviceContext(
                d2dDeviceRaw,
                0,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout contextRaw))
            )
            HRESULT(hr).check()
        }
        let context = ID2D1DeviceContext(contextRaw, takeOwnership: true)
        let result = SwapChain(swapChain, context, width, height)
        result.setTarget()
        return result
    }

    // Resize the swap chain buffers. Zero dimensions are ignored (no-op).
    public func resize(width: UInt32, height: UInt32): Unit {
        if (width == 0 || height == 0) {
            return
        }
        let contextRaw = this.d2dContext.asRaw()
        let swapRaw = this.swapChain.asRaw()
        unsafe {
            // context.SetTarget(None).
            let cvtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(contextRaw).read().read()
            cvtbl.SetTarget(contextRaw, CPointer<Unit>())
            // swapChain.ResizeBuffers(0, width, height, UNKNOWN, 0).
            let svtbl = CPointer<CPointer<IDXGISwapChainVtbl>>(swapRaw).read().read()
            let hr = svtbl.ResizeBuffers(swapRaw, 0, width, height, DXGI_FORMAT_UNKNOWN, 0)
            HRESULT(hr).check()
        }
        this.widthValue = width
        this.heightValue = height
        this.setTarget()
    }

    // Begin a drawing session targeting this swap chain's back buffer. The
    // session calls BeginDraw on creation and EndDraw on close.
    public func beginDraw(): DrawingSession {
        this.deviceLostFlag.lost = false
        return DrawingSession(this.d2dContext, this.deviceLostFlag)
    }

    // Present the rendered frame. Call after closing the `DrawingSession`.
    //
    // Returns `true` on success, `false` if the device was lost (caller should
    // recreate the device and swap chain), or throws for other failures.
    public func present(): Bool {
        // If EndDraw detected device-lost, don't bother presenting.
        if (this.deviceLostFlag.lost) {
            return false
        }
        let swapRaw = this.swapChain.asRaw()
        let hr = unsafe {
            let vtbl = CPointer<CPointer<IDXGISwapChainVtbl>>(swapRaw).read().read()
            HRESULT(vtbl.Present(swapRaw, 1, 0))
        }
        if (isDeviceLost(hr)) {
            return false
        }
        hr.check()
        return true
    }

    // Create a solid color brush that can be reused across draw sessions.
    public func createSolidBrush(color: ColorF): Brush {
        return createSolidBrushOn(this.d2dContext.asRaw(), color)
    }

    // Load a bitmap from an image file (PNG, JPEG, BMP, etc.).
    //
    // Requires COM to be initialized. The bitmap is device-dependent and should
    // be reloaded after device loss.
    public func loadBitmap(path: String): Bitmap {
        return Bitmap.loadFromFile(this.d2dContext.asRaw(), path)
    }

    // Access the raw DXGI swap chain.
    public func rawSwapChain(): CPointer<Unit> {
        return this.swapChain.asRaw()
    }

    // Current width in pixels.
    public func width(): UInt32 {
        return this.widthValue
    }

    // Current height in pixels.
    public func height(): UInt32 {
        return this.heightValue
    }

    // Set the DPI of the D2D render target.
    //
    // Call this with `96.0 * scale` so Direct2D and DirectWrite render at the
    // correct resolution. Also refreshes the render target bitmap.
    public func setDpi(dpiX: Float32, dpiY: Float32): Unit {
        this.dpiX = dpiX
        this.dpiY = dpiY
        let contextRaw = this.d2dContext.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(contextRaw).read().read()
            vtbl.base_.SetDpi(contextRaw, dpiX, dpiY)
        }
        // Recreate the target bitmap with the updated DPI.
        this.setTarget()
    }

    // Apply an inverse composition scale to the swap chain so that a
    // pixel-sized buffer is presented at the correct DIP size.
    //
    // Sets `IDXGISwapChain2::SetMatrixTransform` to `1/scale`.
    public func setCompositionScale(scaleX: Float32, scaleY: Float32): Unit {
        let swapRaw = this.swapChain.asRaw()
        match (unsafe { queryInterfaceRaw(swapRaw, GUID.parse(IID_IDXGISwapChain2)) }) {
            case Some(sc2Raw) =>
                let sc2 = IDXGISwapChain2(sc2Raw, takeOwnership: true)
                var matrix = DXGI_MATRIX_3X2_F()
                matrix._11 = 1.0 / scaleX
                matrix._12 = 0.0
                matrix._21 = 0.0
                matrix._22 = 1.0 / scaleY
                matrix._31 = 0.0
                matrix._32 = 0.0
                unsafe {
                    let vtbl = CPointer<CPointer<IDXGISwapChain2Vtbl>>(sc2Raw).read().read()
                    let _ = vtbl.SetMatrixTransform(
                        sc2Raw,
                        CPointer<Unit>(CPointer<DXGI_MATRIX_3X2_F>(inout matrix))
                    )
                }
                sc2.close()
            case None => ()
        }
    }

    // Returns `true` if the device was lost during the last draw/present cycle.
    public func isDeviceLostNow(): Bool {
        return this.deviceLostFlag.lost
    }

    func setTarget(): Unit {
        let swapRaw = this.swapChain.asRaw()
        let contextRaw = this.d2dContext.asRaw()

        // surface = swapChain.GetBuffer(0) as IDXGISurface.
        var surfaceIid = GUID.parse(IID_IDXGISurface)
        var surfaceRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<IDXGISwapChainVtbl>>(swapRaw).read().read()
            let hr = vtbl.GetBuffer(
                swapRaw,
                0,
                CPointer<Unit>(CPointer<GUID>(inout surfaceIid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout surfaceRaw))
            )
            HRESULT(hr).check()
        }
        let surface = IDXGISurface(surfaceRaw, takeOwnership: true)

        var props = D2D1_BITMAP_PROPERTIES1()
        props.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM
        props.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED
        props.dpiX = this.dpiX
        props.dpiY = this.dpiY
        props.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET | D2D1_BITMAP_OPTIONS_CANNOT_DRAW

        var bitmapRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(contextRaw).read().read()
            let hr = vtbl.CreateBitmapFromDxgiSurface(
                contextRaw,
                surfaceRaw,
                CPointer<Unit>(CPointer<D2D1_BITMAP_PROPERTIES1>(inout props)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout bitmapRaw))
            )
            HRESULT(hr).check()
            // SetTarget(bitmap).
            vtbl.SetTarget(contextRaw, bitmapRaw)
            // Ensure context DPI matches after SetTarget (some target types reset it).
            vtbl.base_.SetDpi(contextRaw, this.dpiX, this.dpiY)
        }
        let bitmap = ID2D1Bitmap(bitmapRaw, takeOwnership: true)
        // The bitmap is now owned by the context as its target; release our
        // construction-time reference (SetTarget AddRef'd it).
        bitmap.close()
        surface.close()
    }
}
