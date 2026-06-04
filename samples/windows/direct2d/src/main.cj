package windows_sample_direct2d

import windows_sample_direct2d_bindings.Win32.Graphics.Direct2D.{
    Apis as D2DApis,
    ID2D1DeviceContextVtbl,
    ID2D1EffectVtbl,
    ID2D1Factory1Vtbl,
    ID2D1DeviceVtbl,
    D2D1_FACTORY_OPTIONS,
    D2D1_BRUSH_PROPERTIES,
    D2D1_STROKE_STYLE_PROPERTIES1,
    D2D1_BITMAP_PROPERTIES1,
    D2D1_ELLIPSE
}
import windows_sample_direct2d_bindings.Win32.Graphics.Direct2D.Common.{
    D2D1_COLOR_F,
    D2D1_PIXEL_FORMAT,
    D2D_SIZE_F,
    D2D_SIZE_U
}
import windows_sample_direct2d_bindings.Win32.Graphics.Dxgi.{
    Apis as DxgiApis,
    IDXGIFactory2Vtbl,
    IDXGIDeviceVtbl,
    IDXGIObjectVtbl,
    IDXGISwapChainVtbl,
    DXGI_SWAP_CHAIN_DESC1
}
import windows_sample_direct2d_bindings.Win32.Graphics.Direct3D11.Apis as D3D11Apis
import windows_sample_direct2d_bindings.Win32.UI.Animation.{
    IUIAnimationManagerVtbl,
    IUIAnimationVariableVtbl,
    IUIAnimationTransitionLibraryVtbl
}
import windows_sample_direct2d_bindings.Win32.System.Com.Apis as ComApis
import windows_sample_direct2d_bindings.Win32.System.Performance.Apis as PerfApis
import windows_sample_direct2d_bindings.Win32.System.SystemInformation.Apis as SysInfoApis
import windows_sample_direct2d_bindings.Win32.System.LibraryLoader.Apis as LoaderApis
import windows_sample_direct2d_bindings.Win32.Foundation.{HWND, HINSTANCE, HMODULE, SYSTEMTIME, RECT}
import windows_sample_direct2d_bindings.Win32.UI.WindowsAndMessaging.{Apis as WndApis, WNDCLASSA, MSG, HMENU}
import windows_sample_direct2d_bindings.Win32.Graphics.Gdi.{Apis as GdiApis, PAINTSTRUCT}
import windows_sample_direct2d_bindings.Foundation.Numerics.{Vector2, Matrix3x2 as ProjectedMatrix3x2}

import windows_core.{HRESULT, GUID, WindowsException, E_NOINTERFACE, queryInterfaceRaw, IUnknownVtbl}
import windows_numerics.{Matrix3x2, identityMatrix3x2, translationMatrix3x2, rotationMatrix3x2, multiply}
import windows_strings.narrowStringFactory
import windows_polyfill.handlePointerFromInt

// ============================================================================
// direct2d — behaviour-equivalent port of the reference sample.
//
// A Direct2D analog clock: a Direct3D11/DXGI device + flip swap chain feed a
// Direct2D device context; the dial and hands are drawn with Direct2D, a drop
// shadow effect is composited, and the Windows Animation manager swings the
// hands on the first frame. A classic GetMessage/PeekMessage pump drives the
// repaint loop, with DXGI occlusion handling to pause rendering when hidden.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference stashes `self as *mut Window` in GWLP_USERDATA and recovers
//     it in the wndproc. Cangjie is GC managed, so a managed object cannot be
//     round-tripped through a raw integer. This sample has exactly one window,
//     so the Window (a class, for persistent mutable per-window state) is held
//     in a top-level global `gWindow`; the top-level @C wndproc reads it and
//     dispatches to messageHandler. This is behaviourally identical to the
//     reference's single-window self pointer. SetWindowLongPtrA is therefore
//     unnecessary and omitted.
//   • COM interface methods are not surfaced as instance methods; the generator
//     exposes each interface's vtbl as an @C struct. We read the vtbl pointer
//     out of the raw COM pointer and invoke methods through it — the exact ABI
//     the reference's projected methods perform. Inherited methods are reached
//     through the nested `base_` field (e.g. a device-context's BeginDraw lives
//     on ID2D1RenderTargetVtbl == DeviceContextVtbl.base_).
//   • There is no `cast::<T>()`; QueryInterface is performed with the documented
//     IID via windows_core.queryInterfaceRaw, returning the AddRef'd interface
//     pointer (wrapped takeOwnership so Release runs on drop).
//   • There are no compile-time GUID literals; well-known IIDs/CLSIDs are parsed
//     at run time from their canonical string form — the run-time analogue.
//   • Scalar Win32/DXGI/D2D flag values are not re-exported by the facade (only
//     the wrapped newtypes are), so the documented integer values are recorded
//     as constants below — semantically identical to the reference's enums.
//   • cfg!(debug_assertions) selects the release branch (no debug device / no
//     D2D debug layer), which is behaviourally equivalent for this sample.
//   • Matrix3x2 / Vector2: windows_numerics provides the affine helpers and the
//     row-major 3x2 multiply (rotation * translation). The struct is @C with the
//     identical 6-f32 layout the D2D ABI expects, so a pointer to it is handed
//     straight to SetTransform. DrawLine/ellipse take the projected Vector2 by
//     value, built field-wise.
//   • COM-pointer lifetimes are owned by the Resource wrappers (takeOwnership:
//     true → Release on close); GC owns the wrappers, so no manual AddRef.
// ============================================================================

// ---- Well-known IIDs (canonical string form) ------------------------------
const IID_ID2D1Factory1: String = "bb12d362-daee-4b9a-aa1d-14ba401cfa1f"
const IID_IDXGIDevice: String = "54ec77fa-1377-44e6-8c32-88fd5f44c84c"
const IID_IDXGIFactory2: String = "50c83a1c-e072-4c48-87b0-3630fa36a6d0"
const IID_IDXGISurface: String = "cafcb56c-6ac3-4889-bf47-9e23bbd260ec"
const IID_IUIAnimationManager: String = "9169896c-ac8d-4e7d-94e5-67fa4dc2f2e8"
const IID_IUIAnimationTransitionLibrary: String = "ca5a14b1-d24f-48b8-8fe4-c78169ba954e"

// ---- Coclass CLSIDs --------------------------------------------------------
const CLSID_UIAnimationManager: String = "4c1fc63a-695c-47e8-a339-1a194be3d0b8"
const CLSID_UIAnimationTransitionLibrary: String = "1d6322ad-aa85-4ef5-a828-86d71067d145"

// ---- D2D / D3D / DXGI scalar constants ------------------------------------
const D2D1_FACTORY_TYPE_SINGLE_THREADED: Int32 = 0
const D3D_DRIVER_TYPE_HARDWARE: Int32 = 1
const D3D_DRIVER_TYPE_WARP: Int32 = 5
const D3D11_CREATE_DEVICE_BGRA_SUPPORT: UInt32 = 0x20
const D3D11_SDK_VERSION: UInt32 = 7
const CLSCTX_ALL: UInt32 = 23
const COINIT_MULTITHREADED: UInt32 = 0
const D2D1_DEVICE_CONTEXT_OPTIONS_NONE: Int32 = 0
const D2D1_UNIT_MODE_DIPS: Int32 = 0
const D2D1_BITMAP_OPTIONS_TARGET: Int32 = 1
const D2D1_BITMAP_OPTIONS_CANNOT_DRAW: Int32 = 2
const DXGI_FORMAT_UNKNOWN: Int32 = 0
const DXGI_FORMAT_B8G8R8A8_UNORM: Int32 = 87
const D2D1_ALPHA_MODE_PREMULTIPLIED: Int32 = 1
const D2D1_ALPHA_MODE_IGNORE: Int32 = 3
const DXGI_USAGE_RENDER_TARGET_OUTPUT: UInt32 = 0x20
const DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL: Int32 = 3
const D2D1_INTERPOLATION_MODE_LINEAR: Int32 = 1
const D2D1_COMPOSITE_MODE_SOURCE_OVER: Int32 = 0
const D2D1_CAP_STYLE_ROUND: Int32 = 1
const D2D1_CAP_STYLE_TRIANGLE: Int32 = 3

// HRESULTs / present flags. DXGI_ERROR_UNSUPPORTED (0x887A0004) is a high-bit
// HRESULT; its signed-Int32 value is -2005270524.
const DXGI_STATUS_OCCLUDED: Int32 = 0x087A_0001
const DXGI_ERROR_UNSUPPORTED: Int32 = -2005270524
const DXGI_PRESENT_TEST: UInt32 = 0x0000_0001

// ---- Window messages / styles ---------------------------------------------
const WM_PAINT: UInt32 = 0x000F
const WM_SIZE: UInt32 = 0x0005
const WM_DISPLAYCHANGE: UInt32 = 0x007E
const WM_ACTIVATE: UInt32 = 0x0006
const WM_DESTROY: UInt32 = 0x0002
const WM_NCCREATE: UInt32 = 0x0081
const WM_QUIT: UInt32 = 0x0012
const WM_USER: UInt32 = 0x0400
const SIZE_MINIMIZED: UIntNative = 1
const PM_REMOVE: UInt32 = 0x0001
const CS_HREDRAW: UInt32 = 0x0002
const CS_VREDRAW: UInt32 = 0x0001
const WS_OVERLAPPEDWINDOW: UInt32 = 0x00CF_0000
const WS_VISIBLE: UInt32 = 0x1000_0000
const CW_USEDEFAULT: Int32 = -2147483648
const IDC_HAND_ID: Int64 = 32649

// QueryInterface a raw COM pointer for the given IID, returning the AddRef'd
// interface pointer or throwing E_NOINTERFACE (the reference's `cast::<T>()`).
func castRaw(source: CPointer<Unit>, iid: String): CPointer<Unit> {
    match (unsafe { queryInterfaceRaw(source, GUID.parse(iid)) }) {
        case Some(raw) => raw
        case None => throw WindowsException(E_NOINTERFACE)
    }
}

// Release a raw COM pointer (used for transient cast results we are done with).
func releaseRaw(raw: CPointer<Unit>): Unit {
    if (raw.isNull()) {
        return
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<IUnknownVtbl>>(raw).read()
        if (vtblPtr.isNotNull()) {
            let vtbl = vtblPtr.read()
            let _ = vtbl.Release(raw)
        }
    }
}

// ===========================================================================
// Clock hand angles, derived from the local wall clock (Angles::now()).
// ===========================================================================
struct Angles {
    var second: Float32 = 0.0
    var minute: Float32 = 0.0
    var hour: Float32 = 0.0
}

func anglesNow(): Angles {
    var time = SYSTEMTIME()
    unsafe {
        SysInfoApis.GetLocalTime(CPointer<Unit>(CPointer<SYSTEMTIME>(inout time)))
    }
    let second = (Float32(time.wSecond) + Float32(time.wMilliseconds) / 1000.0f32) * 6.0f32
    let minute = Float32(time.wMinute) * 6.0f32 + second / 60.0f32
    let hour = Float32(time.wHour % 12) * 30.0f32 + minute / 12.0f32
    var a = Angles()
    a.second = second
    a.minute = minute
    a.hour = hour
    return a
}

// ===========================================================================
// The window. A class so its mutable device-dependent state survives across
// the many messages a single window receives.
// ===========================================================================
class Window {
    // Device-independent resources (created once).
    let factory: CPointer<Unit>      // ID2D1Factory1 (owned)
    let dxfactory: CPointer<Unit>    // IDXGIFactory2 (owned)
    let style: CPointer<Unit>        // ID2D1StrokeStyle1 (owned)
    let manager: CPointer<Unit>      // IUIAnimationManager (owned)
    let variable: CPointer<Unit>     // IUIAnimationVariable (owned)

    var handle: HWND = HWND()

    // Device-dependent resources (recreated on device loss).
    var target: CPointer<Unit> = CPointer<Unit>()      // ID2D1DeviceContext
    var swapchain: CPointer<Unit> = CPointer<Unit>()   // IDXGISwapChain1
    var brush: CPointer<Unit> = CPointer<Unit>()       // ID2D1SolidColorBrush
    var shadow: CPointer<Unit> = CPointer<Unit>()      // ID2D1Effect
    var clock: CPointer<Unit> = CPointer<Unit>()       // ID2D1Bitmap1

    var dpi: Float32 = 0.0
    var visible: Bool = false
    var occlusion: UInt32 = 0
    var frequency: Int64 = 0
    var angles: Angles = Angles()

    init() {
        factory = createFactory()
        dxfactory = createDxFactory()
        style = createStyle(factory)
        manager = coCreateInstance(CLSID_UIAnimationManager, IID_IUIAnimationManager)

        let transition = createTransition()

        // GetDesktopDpi (on ID2D1Factory, the base of ID2D1Factory1).
        var dpiX: Float32 = 0.0
        var dpiY: Float32 = 0.0
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1Factory1Vtbl>>(factory).read()
            let vtbl = vtblPtr.read()
            vtbl.base_.GetDesktopDpi(
                factory,
                CPointer<Unit>(CPointer<Float32>(inout dpiX)),
                CPointer<Unit>(CPointer<Float32>(inout dpiY))
            )
        }
        dpi = dpiX

        var freq: Int64 = 0
        unsafe {
            PerfApis.QueryPerformanceFrequencyChecked(CPointer<Unit>(CPointer<Int64>(inout freq)))
        }
        frequency = freq

        // CreateAnimationVariable(0.0) then schedule the swing transition.
        var variableRaw = CPointer<Unit>()
        unsafe {
            let vtblPtr = CPointer<CPointer<IUIAnimationManagerVtbl>>(manager).read()
            let vtbl = vtblPtr.read()
            let hr = vtbl.CreateAnimationVariable(
                manager,
                0.0,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout variableRaw))
            )
            HRESULT(hr).check()
            let hr2 = vtbl.ScheduleTransition(manager, variableRaw, transition, getTime(freq))
            HRESULT(hr2).check()
        }
        variable = variableRaw

        // The scheduled transition object is no longer needed by us.
        releaseRaw(transition)

        angles = anglesNow()
    }

    // Create device-dependent resources lazily, then draw one frame.
    func render(): Unit {
        if (target.isNull()) {
            let device = createDevice()
            try {
                let newTarget = createRenderTarget(factory, device)
                unsafe {
                    let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(newTarget).read()
                    let vtbl = vtblPtr.read()
                    vtbl.base_.SetDpi(newTarget, dpi, dpi)
                }

                let newSwapchain = createSwapchain(device, handle)
                createSwapchainBitmap(newSwapchain, newTarget)

                brush = createBrush(newTarget)
                target = newTarget
                swapchain = newSwapchain
                createDeviceSizeResources()
            } finally {
                releaseRaw(device)
            }
        }

        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.base_.BeginDraw(target)
        }

        draw()

        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            // EndDraw(None, None).
            let hr = vtbl.base_.EndDraw(target, CPointer<Unit>(), CPointer<Unit>())
            HRESULT(hr).check()
        }

        let presentHr = present(1, 0)
        if (presentHr.isErr()) {
            if (presentHr.value == DXGI_STATUS_OCCLUDED) {
                // RegisterOcclusionStatusWindow(handle, WM_USER).
                var cookie: UInt32 = 0
                unsafe {
                    let vtblPtr = CPointer<CPointer<IDXGIFactory2Vtbl>>(dxfactory).read()
                    let vtbl = vtblPtr.read()
                    let hr = vtbl.RegisterOcclusionStatusWindow(
                        dxfactory,
                        handle,
                        WM_USER,
                        CPointer<Unit>(CPointer<UInt32>(inout cookie))
                    )
                    HRESULT(hr).check()
                }
                occlusion = cookie
                visible = false
            } else {
                releaseDevice()
            }
        }
    }

    func releaseDevice(): Unit {
        releaseRaw(target)
        target = CPointer<Unit>()
        releaseRaw(swapchain)
        swapchain = CPointer<Unit>()
        releaseDeviceResources()
    }

    func releaseDeviceResources(): Unit {
        releaseRaw(brush)
        brush = CPointer<Unit>()
        releaseRaw(clock)
        clock = CPointer<Unit>()
        releaseRaw(shadow)
        shadow = CPointer<Unit>()
    }

    // IDXGISwapChain1::Present(sync, flags) -> HRESULT. Present lives on the
    // IDXGISwapChain base of IDXGISwapChain1.
    func present(sync: UInt32, flags: UInt32): HRESULT {
        unsafe {
            let vtblPtr = CPointer<CPointer<IDXGISwapChainVtbl>>(swapchain).read()
            let vtbl = vtblPtr.read()
            return HRESULT(vtbl.Present(swapchain, sync, flags))
        }
    }

    func draw(): Unit {
        // manager.Update(get_time(frequency), None).
        unsafe {
            let vtblPtr = CPointer<CPointer<IUIAnimationManagerVtbl>>(manager).read()
            let vtbl = vtblPtr.read()
            let hr = vtbl.Update(manager, getTime(frequency), CPointer<Unit>())
            HRESULT(hr).check()
        }

        // target.Clear(white).
        var white = D2D1_COLOR_F()
        white.r = 1.0
        white.g = 1.0
        white.b = 1.0
        white.a = 1.0
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.base_.Clear(target, CPointer<Unit>(CPointer<D2D1_COLOR_F>(inout white)))
        }

        // previous = target.GetTarget(); target.SetTarget(clock); target.Clear(None).
        var previous = CPointer<Unit>()
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.GetTarget(target, CPointer<Unit>(CPointer<CPointer<Unit>>(inout previous)))
            vtbl.SetTarget(target, clock)
            vtbl.base_.Clear(target, CPointer<Unit>())
        }

        drawClock()

        // target.SetTarget(previous); SetTransform(translation(5,5)).
        var shift = translationMatrix3x2(5.0, 5.0)
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.SetTarget(target, previous)
            vtbl.base_.SetTransform(target, CPointer<Unit>(CPointer<Matrix3x2>(inout shift)))
        }

        // shadow output image for the shadow draw.
        var shadowOutput = CPointer<Unit>()
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1EffectVtbl>>(shadow).read()
            let vtbl = vtblPtr.read()
            vtbl.GetOutput(shadow, CPointer<Unit>(CPointer<CPointer<Unit>>(inout shadowOutput)))
        }

        // DrawImage(shadow output, None, None, LINEAR, SOURCE_OVER).
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.DrawImage(
                target,
                shadowOutput,
                CPointer<Unit>(),
                CPointer<Unit>(),
                D2D1_INTERPOLATION_MODE_LINEAR,
                D2D1_COMPOSITE_MODE_SOURCE_OVER
            )
        }
        // GetOutput AddRef'd the image; release our reference.
        releaseRaw(shadowOutput)

        // SetTransform(identity); DrawImage(clock, None, None, LINEAR, SOURCE_OVER).
        var ident = identityMatrix3x2()
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.base_.SetTransform(target, CPointer<Unit>(CPointer<Matrix3x2>(inout ident)))
            vtbl.DrawImage(
                target,
                clock,
                CPointer<Unit>(),
                CPointer<Unit>(),
                D2D1_INTERPOLATION_MODE_LINEAR,
                D2D1_COMPOSITE_MODE_SOURCE_OVER
            )
        }

        // GetTarget AddRef'd `previous`; release it.
        releaseRaw(previous)
    }

    func drawClock(): Unit {
        // size = render-target size in DIPs (see sizeDip — it avoids the
        // aggregate-return ABI bug in ID2D1RenderTarget::GetSize).
        let size = sizeDip()

        let minSide = if (size.width < size.height) { size.width } else { size.height }
        let clamped = if (minSide > 200.0f32) { minSide } else { 200.0f32 }
        let radius = clamped / 2.0f32 - 50.0f32

        let translation = translationMatrix3x2(size.width / 2.0f32, size.height / 2.0f32)

        // SetTransform(translation).
        var t = translation
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.base_.SetTransform(target, CPointer<Unit>(CPointer<Matrix3x2>(inout t)))
        }

        // ellipse centred at origin.
        var ellipse = D2D1_ELLIPSE()
        ellipse.point = zeroProjectedVector2()
        ellipse.radiusX = radius
        ellipse.radiusY = radius

        // DrawEllipse(ellipse, brush, radius/20, None).
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.base_.DrawEllipse(
                target,
                CPointer<Unit>(CPointer<D2D1_ELLIPSE>(inout ellipse)),
                brush,
                radius / 20.0f32,
                CPointer<Unit>()
            )
        }

        // swing = variable.GetValue().
        var swing: Float64 = 0.0
        unsafe {
            let vtblPtr = CPointer<CPointer<IUIAnimationVariableVtbl>>(variable).read()
            let vtbl = vtblPtr.read()
            let hr = vtbl.GetValue(variable, CPointer<Unit>(CPointer<Float64>(inout swing)))
            HRESULT(hr).check()
        }

        var nowAngles = anglesNow()

        if (swing < 1.0) {
            if (angles.second > nowAngles.second) {
                nowAngles.second += 360.0f32
            }
            if (angles.minute > nowAngles.minute) {
                nowAngles.minute += 360.0f32
            }
            if (angles.hour > nowAngles.hour) {
                nowAngles.hour += 360.0f32
            }

            let s = Float32(swing)
            nowAngles.second *= s
            nowAngles.minute *= s
            nowAngles.hour *= s
        }

        // Second hand.
        drawHand(nowAngles.second, translation, radius * 0.75f32, radius / 25.0f32)
        // Minute hand.
        drawHand(nowAngles.minute, translation, radius * 0.75f32, radius / 15.0f32)
        // Hour hand.
        drawHand(nowAngles.hour, translation, radius * 0.5f32, radius / 10.0f32)
    }

    // SetTransform(rotation(angle) * translation); DrawLine(0,0 -> 0,-length).
    func drawHand(angle: Float32, translation: Matrix3x2, length: Float32, strokeWidth: Float32): Unit {
        var m = multiply(rotationMatrix3x2(angle), translation)
        var p0 = zeroProjectedVector2()
        var p1 = projectedVector2(0.0f32, -length)
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.base_.SetTransform(target, CPointer<Unit>(CPointer<Matrix3x2>(inout m)))
            vtbl.base_.DrawLine(target, p0, p1, brush, strokeWidth, style)
        }
    }

    func createDeviceSizeResources(): Unit {
        let newClock = createClock()
        shadow = createShadow(target, newClock)
        clock = newClock
    }

    // Render-target size in DIPs, obtained WITHOUT ID2D1RenderTarget::GetSize.
    // That COM getter returns a D2D_SIZE_F aggregate by value, which the
    // generated value-returning CFunc miscompiles on x64: it reads the sret
    // return-buffer POINTER out of RAX instead of the value, so the size comes
    // back as garbage (here it had been masked by the saturating cast + the
    // 200.0 floor in drawClock). See web/book/src/aggregate-return-abi-bug.md.
    // The correct fix is a bindgen change emitting an explicit out-parameter
    // signature for aggregate returns + regen, after which this can revert to
    // target.GetSize(). Until then we use GetClientRect — a plain out-parameter
    // call — and convert physical pixels to DIPs by the DPI scale (the target
    // was created with SetDpi(dpi), so its DIP size == client px * 96 / dpi).
    func sizeDip(): D2D_SIZE_F {
        var rect = RECT()
        unsafe {
            WndApis.GetClientRect(handle, CPointer<Unit>(CPointer<RECT>(inout rect)))
        }
        let scale = dpi / 96.0f32
        var size = D2D_SIZE_F()
        size.width = Float32(rect.right - rect.left) / scale
        size.height = Float32(rect.bottom - rect.top) / scale
        return size
    }

    // CreateBitmap with TARGET option, dpi-scaled pixel size — the offscreen
    // clock face. Returns an owned ID2D1Bitmap1 raw pointer.
    func createClock(): CPointer<Unit> {
        let sizeF = sizeDip()

        var sizeU = D2D_SIZE_U()
        // The reference performs `(size * dpi / 96.0) as u32`, which in Rust
        // truncates toward zero and saturates (negative -> 0, overflow -> max,
        // NaN -> 0). Cangjie's checked UInt32(Float32) panics on those inputs, so
        // saturate explicitly to preserve the reference's behaviour.
        sizeU.width = f32ToU32Saturating(sizeF.width * dpi / 96.0f32)
        sizeU.height = f32ToU32Saturating(sizeF.height * dpi / 96.0f32)

        var props = D2D1_BITMAP_PROPERTIES1()
        props.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM
        props.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED
        props.dpiX = dpi
        props.dpiY = dpi
        props.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET

        var bitmapRaw = CPointer<Unit>()
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            // CreateBitmap(size, sourceData=None, pitch=0, props, outBitmap).
            let hr = vtbl.CreateBitmap(
                target,
                sizeU,
                CPointer<Unit>(),
                0,
                CPointer<Unit>(CPointer<D2D1_BITMAP_PROPERTIES1>(inout props)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout bitmapRaw))
            )
            HRESULT(hr).check()
        }
        return bitmapRaw
    }

    func resizeSwapchainBitmap(): Unit {
        if (target.isNull()) {
            return
        }

        // target.SetTarget(None).
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            vtbl.SetTarget(target, CPointer<Unit>())
        }

        // ResizeBuffers(0,0,0,UNKNOWN,0).
        var resizeOk = false
        unsafe {
            let vtblPtr = CPointer<CPointer<IDXGISwapChainVtbl>>(swapchain).read()
            let vtbl = vtblPtr.read()
            let hr = vtbl.ResizeBuffers(swapchain, 0, 0, 0, DXGI_FORMAT_UNKNOWN, 0)
            resizeOk = HRESULT(hr).isOk()
        }

        if (resizeOk) {
            createSwapchainBitmap(swapchain, target)
            createDeviceSizeResources()
        } else {
            releaseDevice()
        }

        render()
    }

    func messageHandler(message: UInt32, wparam: UIntNative, lparam: IntNative): IntNative {
        // Constant patterns must be literals (a bare `const` identifier parses as
        // a binding pattern that matches everything), so the documented message
        // ids are matched directly. WM_PAINT=0x000F, WM_SIZE=0x0005,
        // WM_DISPLAYCHANGE=0x007E, WM_USER=0x0400, WM_ACTIVATE=0x0006,
        // WM_DESTROY=0x0002.
        match (message) {
            case 0x000F =>
                var ps = PAINTSTRUCT()
                unsafe {
                    GdiApis.BeginPaint(handle, CPointer<Unit>(CPointer<PAINTSTRUCT>(inout ps)))
                    render()
                    let _ = GdiApis.EndPaint(handle, CPointer<Unit>(CPointer<PAINTSTRUCT>(inout ps)))
                }
                return 0
            case 0x0005 =>
                if (wparam != SIZE_MINIMIZED) {
                    resizeSwapchainBitmap()
                }
                return 0
            case 0x007E =>
                render()
                return 0
            case 0x0400 =>
                if (present(0, DXGI_PRESENT_TEST).isOk()) {
                    // UnregisterOcclusionStatus(occlusion).
                    unsafe {
                        let vtblPtr = CPointer<CPointer<IDXGIFactory2Vtbl>>(dxfactory).read()
                        let vtbl = vtblPtr.read()
                        vtbl.UnregisterOcclusionStatus(dxfactory, occlusion)
                    }
                    occlusion = 0
                    visible = true
                }
                return 0
            case 0x0006 =>
                // HIWORD(wparam) != 0 => minimized; only render when not minimized.
                visible = (UInt16(wparam >> 16) == 0)
                return 0
            case 0x0002 =>
                unsafe { WndApis.PostQuitMessage(0) }
                return 0
            case _ =>
                return unsafe { WndApis.DefWindowProcA(handle, message, wparam, lparam) }
        }
    }

    func run(): Unit {
        // GetModuleHandleA(None).
        let instance = unsafe { LoaderApis.GetModuleHandleA(CPointer<UInt8>()) }
        let instancePtr = instance.Value

        narrowStringFactory("window").withPtr { className =>
            narrowStringFactory("Sample Window").withPtr { windowName =>
                // LoadCursorW(None, IDC_HAND).
                let cursor = unsafe {
                    WndApis.LoadCursorW(HINSTANCE(), CPointer<UInt16>(handlePointerFromInt(IDC_HAND_ID)))
                }

                var hinst = HINSTANCE()
                hinst.Value = instancePtr

                var wc = WNDCLASSA()
                wc.hCursor = cursor
                wc.hInstance = hinst
                wc.lpszClassName = className.asPtr()
                wc.style = CS_HREDRAW | CS_VREDRAW
                wc.lpfnWndProc = wndproc

                let atom = unsafe {
                    WndApis.RegisterClassA(CPointer<Unit>(CPointer<WNDCLASSA>(inout wc)))
                }
                if (atom == 0) {
                    return ()
                }

                // CreateWindowExA(0, class, title, OVERLAPPEDWINDOW|VISIBLE,
                // CW_USEDEFAULT x4, None, None, instance, None). The reference
                // passes `self` as the create-param to recover it in WM_NCCREATE;
                // we instead publish gWindow before creation so the wndproc has
                // it from the very first message.
                let win = unsafe {
                    WndApis.CreateWindowExA(
                        0,
                        className.asPtr(),
                        windowName.asPtr(),
                        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                        CW_USEDEFAULT,
                        CW_USEDEFAULT,
                        CW_USEDEFAULT,
                        CW_USEDEFAULT,
                        HWND(),
                        HMENU(),
                        hinst,
                        CPointer<Unit>()
                    )
                }
                // The reference records the window handle in WM_NCCREATE; with no
                // user-data round-trip we capture it here (and again on first use).
                handle = win

                if (win.Value.isNull()) {
                    return ()
                }

                var message = MSG()
                let msgPtr = unsafe { CPointer<Unit>(CPointer<MSG>(inout message)) }
                while (true) {
                    if (visible) {
                        render()
                        // Drain the queue with PeekMessage(PM_REMOVE).
                        while (unsafe { WndApis.PeekMessageA(msgPtr, HWND(), 0, 0, PM_REMOVE) } != 0) {
                            if (message.message == WM_QUIT) {
                                return ()
                            }
                            unsafe { WndApis.DispatchMessageA(msgPtr) }
                        }
                    } else {
                        let _ = unsafe { WndApis.GetMessageA(msgPtr, HWND(), 0, 0) }
                        if (message.message == WM_QUIT) {
                            return ()
                        }
                        unsafe { WndApis.DispatchMessageA(msgPtr) }
                    }
                }
            }
        }
    }
}

// Saturating Float32 -> UInt32 cast, matching the reference's `as u32`
// (truncate toward zero; negative/NaN -> 0; > UInt32.Max -> UInt32.Max).
func f32ToU32Saturating(value: Float32): UInt32 {
    if (value.isNaN() || value <= 0.0f32) {
        return 0
    }
    if (value >= 4294967296.0f32) {
        return UInt32.Max
    }
    return UInt32(value)
}

// ===========================================================================
// Projected Vector2 helpers (the generator's Vector2 used by DrawLine /
// D2D1_ELLIPSE.point, distinct from windows_numerics.Vector2).
// ===========================================================================
func projectedVector2(x: Float32, y: Float32): Vector2 {
    var v = Vector2()
    v.X = x
    v.Y = y
    return v
}

func zeroProjectedVector2(): Vector2 {
    return projectedVector2(0.0, 0.0)
}

// ===========================================================================
// Free creation helpers (the reference's free functions).
// ===========================================================================

// QueryPerformanceCounter / frequency -> seconds.
func getTime(frequency: Int64): Float64 {
    var time: Int64 = 0
    unsafe {
        PerfApis.QueryPerformanceCounterChecked(CPointer<Unit>(CPointer<Int64>(inout time)))
    }
    return Float64(time) / Float64(frequency)
}

// CoCreateInstance(clsid, None, CLSCTX_ALL, iid, &out) -> owned raw pointer.
func coCreateInstance(clsidStr: String, iidStr: String): CPointer<Unit> {
    var clsid = GUID.parse(clsidStr)
    var iid = GUID.parse(iidStr)
    var outRaw = CPointer<Unit>()
    unsafe {
        let clsidPtr = CPointer<Unit>(CPointer<GUID>(inout clsid))
        let iidPtr = CPointer<Unit>(CPointer<GUID>(inout iid))
        let hr = ComApis.CoCreateInstance(
            clsidPtr,
            CPointer<Unit>(),
            CLSCTX_ALL,
            iidPtr,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// D2D1CreateFactory(SINGLE_THREADED, IID_ID2D1Factory1, &options, &out).
func createFactory(): CPointer<Unit> {
    var options = D2D1_FACTORY_OPTIONS()
    // Release: leave debugLevel at 0 (NONE).
    var iid = GUID.parse(IID_ID2D1Factory1)
    var outRaw = CPointer<Unit>()
    unsafe {
        let iidPtr = CPointer<Unit>(CPointer<GUID>(inout iid))
        D2DApis.D2D1CreateFactoryChecked(
            D2D1_FACTORY_TYPE_SINGLE_THREADED,
            iidPtr,
            CPointer<Unit>(CPointer<D2D1_FACTORY_OPTIONS>(inout options)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
    }
    return outRaw
}

// CreateDXGIFactory1(IID_IDXGIFactory2, &out).
func createDxFactory(): CPointer<Unit> {
    var iid = GUID.parse(IID_IDXGIFactory2)
    var outRaw = CPointer<Unit>()
    unsafe {
        let iidPtr = CPointer<Unit>(CPointer<GUID>(inout iid))
        let hr = DxgiApis.CreateDXGIFactory1(
            iidPtr,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// factory.CreateStrokeStyle(props{round,triangle}, None, 0, &out).
func createStyle(factory: CPointer<Unit>): CPointer<Unit> {
    var props = D2D1_STROKE_STYLE_PROPERTIES1()
    props.startCap = D2D1_CAP_STYLE_ROUND
    props.endCap = D2D1_CAP_STYLE_TRIANGLE

    var outRaw = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<ID2D1Factory1Vtbl>>(factory).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.CreateStrokeStyle(
            factory,
            CPointer<Unit>(CPointer<D2D1_STROKE_STYLE_PROPERTIES1>(inout props)),
            CPointer<Unit>(),
            0,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// CoCreateInstance(UIAnimationTransitionLibrary) then
// CreateAccelerateDecelerateTransition(5,1,0.2,0.8) -> owned transition.
func createTransition(): CPointer<Unit> {
    let library = coCreateInstance(CLSID_UIAnimationTransitionLibrary, IID_IUIAnimationTransitionLibrary)
    var transitionRaw = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<IUIAnimationTransitionLibraryVtbl>>(library).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.CreateAccelerateDecelerateTransition(
            library,
            5.0,
            1.0,
            0.2,
            0.8,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout transitionRaw))
        )
        HRESULT(hr).check()
    }
    releaseRaw(library)
    return transitionRaw
}

// target.CreateSolidColorBrush(color, props{opacity 0.8, identity}) -> owned.
func createBrush(target: CPointer<Unit>): CPointer<Unit> {
    var color = D2D1_COLOR_F()
    color.r = 0.92
    color.g = 0.38
    color.b = 0.208
    color.a = 1.0

    var props = D2D1_BRUSH_PROPERTIES()
    props.opacity = 0.8
    props.transform = bindingsIdentityMatrix()

    var outRaw = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
        let vtbl = vtblPtr.read()
        let hr = vtbl.base_.CreateSolidColorBrush(
            target,
            CPointer<Unit>(CPointer<D2D1_COLOR_F>(inout color)),
            CPointer<Unit>(CPointer<D2D1_BRUSH_PROPERTIES>(inout props)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// target.CreateEffect(CLSID_D2D1Shadow); shadow.SetInput(0, clock, true).
func createShadow(target: CPointer<Unit>, clock: CPointer<Unit>): CPointer<Unit> {
    var clsid = D2DApis.CLSID_D2D1Shadow()
    var shadowRaw = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
        let vtbl = vtblPtr.read()
        let clsidPtr = CPointer<Unit>(CPointer<GUID>(inout clsid))
        let hr = vtbl.CreateEffect(
            target,
            clsidPtr,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout shadowRaw))
        )
        HRESULT(hr).check()
    }
    unsafe {
        let vtblPtr = CPointer<CPointer<ID2D1EffectVtbl>>(shadowRaw).read()
        let vtbl = vtblPtr.read()
        // SetInput(0, clock, invalidate=TRUE).
        vtbl.SetInput(shadowRaw, 0, clock, 1)
    }
    return shadowRaw
}

// create_device(): try HARDWARE, fall back to WARP on DXGI_ERROR_UNSUPPORTED.
func createDevice(): CPointer<Unit> {
    let (raw, hr) = createDeviceWithType(D3D_DRIVER_TYPE_HARDWARE)
    if (hr.isErr() && hr.value == DXGI_ERROR_UNSUPPORTED) {
        let (warpRaw, warpHr) = createDeviceWithType(D3D_DRIVER_TYPE_WARP)
        warpHr.check()
        return warpRaw
    }
    hr.check()
    return raw
}

// D3D11CreateDevice(None, type, None, BGRA_SUPPORT, None, SDK_VERSION, &device,
// None, None). Returns (device raw, hr) so the caller can branch on the code.
func createDeviceWithType(driverType: Int32): (CPointer<Unit>, HRESULT) {
    let flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT
    var deviceRaw = CPointer<Unit>()
    let hr = unsafe {
        D3D11Apis.D3D11CreateDevice(
            CPointer<Unit>(),
            driverType,
            instanceNullModule(),
            flags,
            CPointer<Unit>(),
            0,
            D3D11_SDK_VERSION,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout deviceRaw)),
            CPointer<Unit>(),
            CPointer<Unit>()
        )
    }
    return (deviceRaw, HRESULT(hr))
}

// factory.CreateDevice(device.cast::<IDXGIDevice>()); d2device.CreateDeviceContext;
// target.SetUnitMode(DIPS) -> owned ID2D1DeviceContext.
func createRenderTarget(factory: CPointer<Unit>, device: CPointer<Unit>): CPointer<Unit> {
    let dxdevice = castRaw(device, IID_IDXGIDevice)
    var d2device = CPointer<Unit>()
    try {
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1Factory1Vtbl>>(factory).read()
            let vtbl = vtblPtr.read()
            let hr = vtbl.CreateDevice(
                factory,
                dxdevice,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout d2device))
            )
            HRESULT(hr).check()
        }
    } finally {
        releaseRaw(dxdevice)
    }

    var targetRaw = CPointer<Unit>()
    try {
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceVtbl>>(d2device).read()
            let vtbl = vtblPtr.read()
            let hr = vtbl.CreateDeviceContext(
                d2device,
                D2D1_DEVICE_CONTEXT_OPTIONS_NONE,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout targetRaw))
            )
            HRESULT(hr).check()
        }
    } finally {
        releaseRaw(d2device)
    }

    unsafe {
        let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(targetRaw).read()
        let vtbl = vtblPtr.read()
        vtbl.SetUnitMode(targetRaw, D2D1_UNIT_MODE_DIPS)
    }
    return targetRaw
}

// device.cast::<IDXGIDevice>().GetAdapter().GetParent::<IDXGIFactory2>().
func getDxgiFactory(device: CPointer<Unit>): CPointer<Unit> {
    let dxdevice = castRaw(device, IID_IDXGIDevice)
    var adapter = CPointer<Unit>()
    try {
        unsafe {
            let vtblPtr = CPointer<CPointer<IDXGIDeviceVtbl>>(dxdevice).read()
            let vtbl = vtblPtr.read()
            let hr = vtbl.GetAdapter(dxdevice, CPointer<Unit>(CPointer<CPointer<Unit>>(inout adapter)))
            HRESULT(hr).check()
        }
    } finally {
        releaseRaw(dxdevice)
    }

    var iid = GUID.parse(IID_IDXGIFactory2)
    var factoryRaw = CPointer<Unit>()
    try {
        unsafe {
            let vtblPtr = CPointer<CPointer<IDXGIObjectVtbl>>(adapter).read()
            let vtbl = vtblPtr.read()
            let iidPtr = CPointer<Unit>(CPointer<GUID>(inout iid))
            let hr = vtbl.GetParent(
                adapter,
                iidPtr,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout factoryRaw))
            )
            HRESULT(hr).check()
        }
    } finally {
        releaseRaw(adapter)
    }
    return factoryRaw
}

// swapchain.GetBuffer(0) -> IDXGISurface; CreateBitmapFromDxgiSurface; SetTarget.
func createSwapchainBitmap(swapchain: CPointer<Unit>, target: CPointer<Unit>): Unit {
    var iid = GUID.parse(IID_IDXGISurface)
    var surface = CPointer<Unit>()
    unsafe {
        let vtblPtr = CPointer<CPointer<IDXGISwapChainVtbl>>(swapchain).read()
        let vtbl = vtblPtr.read()
        let iidPtr = CPointer<Unit>(CPointer<GUID>(inout iid))
        let hr = vtbl.GetBuffer(
            swapchain,
            0,
            iidPtr,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout surface))
        )
        HRESULT(hr).check()
    }

    try {
        var props = D2D1_BITMAP_PROPERTIES1()
        props.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM
        props.pixelFormat.alphaMode = D2D1_ALPHA_MODE_IGNORE
        props.dpiX = 96.0
        props.dpiY = 96.0
        props.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET | D2D1_BITMAP_OPTIONS_CANNOT_DRAW

        var bitmap = CPointer<Unit>()
        unsafe {
            let vtblPtr = CPointer<CPointer<ID2D1DeviceContextVtbl>>(target).read()
            let vtbl = vtblPtr.read()
            let hr = vtbl.CreateBitmapFromDxgiSurface(
                target,
                surface,
                CPointer<Unit>(CPointer<D2D1_BITMAP_PROPERTIES1>(inout props)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout bitmap))
            )
            HRESULT(hr).check()
            // SetTarget(bitmap).
            vtbl.SetTarget(target, bitmap)
        }
        releaseRaw(bitmap)
    } finally {
        releaseRaw(surface)
    }
}

// get_dxgi_factory(device).CreateSwapChainForHwnd(device, hwnd, &desc) -> owned.
func createSwapchain(device: CPointer<Unit>, window: HWND): CPointer<Unit> {
    let factory = getDxgiFactory(device)
    try {
        var desc = DXGI_SWAP_CHAIN_DESC1()
        desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM
        desc.SampleDesc.Count = 1
        desc.SampleDesc.Quality = 0
        desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT
        desc.BufferCount = 2
        desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL

        var outRaw = CPointer<Unit>()
        unsafe {
            let vtblPtr = CPointer<CPointer<IDXGIFactory2Vtbl>>(factory).read()
            let vtbl = vtblPtr.read()
            let hr = vtbl.CreateSwapChainForHwnd(
                factory,
                device,
                window,
                CPointer<Unit>(CPointer<DXGI_SWAP_CHAIN_DESC1>(inout desc)),
                CPointer<Unit>(),
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
            )
            HRESULT(hr).check()
        }
        return outRaw
    } finally {
        releaseRaw(factory)
    }
}

// ===========================================================================
// Tiny utilities.
// ===========================================================================

// Build the projected (bindings) identity Matrix3x2 used in D2D1_BRUSH_PROPERTIES.
func bindingsIdentityMatrix(): ProjectedMatrix3x2 {
    var m = ProjectedMatrix3x2()
    m.M11 = 1.0
    m.M22 = 1.0
    return m
}

// A null HMODULE for the Software adapter argument of D3D11CreateDevice.
func instanceNullModule(): HMODULE {
    return HMODULE()
}

// ===========================================================================
// The single window, held globally so the @C wndproc can reach it (the GC-safe
// analogue of the reference's GWLP_USERDATA self pointer).
// ===========================================================================
var gWindow: Option<Window> = None

// WNDPROC. Must match CFunc<(HWND, UInt32, UIntNative, IntNative) -> IntNative>.
@C
func wndproc(window: HWND, message: UInt32, wparam: UIntNative, lparam: IntNative): IntNative {
    match (gWindow) {
        case Some(w) =>
            // Mirror the reference recording the handle on the first message.
            if (w.handle.Value.isNull()) {
                w.handle = window
            }
            return w.messageHandler(message, wparam, lparam)
        case None =>
            return unsafe { WndApis.DefWindowProcA(window, message, wparam, lparam) }
    }
}

main(): Int64 {
    // CoInitializeEx(None, MULTITHREADED).ok()?
    unsafe {
        ComApis.CoInitializeExChecked(CPointer<Unit>(), COINIT_MULTITHREADED).check()
    }

    let window = Window()
    gWindow = Some(window)
    window.run()
    return 0
}
