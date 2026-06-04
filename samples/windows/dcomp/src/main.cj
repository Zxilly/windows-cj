package windows_sample_dcomp

import windows_sample_dcomp_bindings.Win32.Graphics.DirectComposition.{
    Apis as DCompApis,
    IDCompositionDesktopDeviceVtbl,
    IDCompositionDevice2Vtbl,
    IDCompositionVisualVtbl,
    IDCompositionVisual2Vtbl,
    IDCompositionTargetVtbl,
    IDCompositionSurfaceVtbl,
    IDCompositionRotateTransform3DVtbl,
    IDCompositionMatrixTransform3DVtbl,
    IDCompositionAnimationVtbl,
    DCOMPOSITION_FRAME_STATISTICS
}
import windows_sample_dcomp_bindings.Win32.Graphics.Direct2D.{
    Apis as D2DApis,
    ID2D1DeviceVtbl,
    ID2D1DeviceContextVtbl
}
import windows_sample_dcomp_bindings.Win32.Graphics.Direct2D.Common.{
    D2D1_COLOR_F,
    D2D_RECT_F
}
import windows_sample_dcomp_bindings.Win32.Graphics.Direct3D11.{Apis as D3D11Apis, ID3D11DeviceVtbl}
import windows_sample_dcomp_bindings.Win32.Graphics.DirectWrite.{
    Apis as DWriteApis,
    IDWriteFactory2Vtbl,
    IDWriteTextFormatVtbl
}
import windows_sample_dcomp_bindings.Win32.Graphics.Imaging.{
    Apis as WICApis,
    IWICImagingFactoryVtbl,
    IWICBitmapDecoderVtbl,
    IWICFormatConverterVtbl
}
import windows_sample_dcomp_bindings.Win32.Security.Cryptography.{Apis as CryptoApis, BCRYPT_ALG_HANDLE}
import windows_sample_dcomp_bindings.Win32.UI.Animation.{
    IUIAnimationManager2Vtbl,
    IUIAnimationTransitionLibrary2Vtbl,
    IUIAnimationVariable2Vtbl,
    IUIAnimationStoryboard2Vtbl,
    UI_ANIMATION_KEYFRAME
}
import windows_sample_dcomp_bindings.Win32.UI.HiDpi.{Apis as HiDpiApis, DPI_AWARENESS_CONTEXT}
import windows_sample_dcomp_bindings.Win32.UI.Shell.Apis as ShellApis
import windows_sample_dcomp_bindings.Win32.System.Com.Apis as ComApis
import windows_sample_dcomp_bindings.Win32.System.LibraryLoader.Apis as LoaderApis
import windows_sample_dcomp_bindings.Win32.Foundation.{HWND, HINSTANCE, HMODULE, RECT, POINT}
import windows_sample_dcomp_bindings.Win32.Graphics.Gdi.{Apis as GdiApis, HMONITOR}
import windows_sample_dcomp_bindings.Win32.UI.WindowsAndMessaging.{Apis as WndApis, WNDCLASSA, MSG, HMENU, HCURSOR}

import windows_core.{HRESULT, GUID, WindowsException, E_NOINTERFACE, queryInterfaceRaw, IUnknownVtbl}
import windows_numerics.{
    Matrix4x4,
    translationMatrix4x4,
    rotationYMatrix4x4,
    perspectiveProjectionMatrix4x4,
    multiply,
    Matrix3x2,
    translationMatrix3x2
}
import windows_strings.encodeUtf16WithNull
import windows_polyfill.handlePointerFromInt

import std.collection.ArrayList

// ============================================================================
// dcomp — behaviour-equivalent port of the reference sample.
//
// A DirectComposition card-flip memory game. A Direct3D11 device backs a
// Direct2D device, which backs an IDCompositionDesktopDevice; each card is a
// composition surface (one front, one back), drawn with Direct2D — the front
// shows a DirectWrite letter, the back a slice of a WIC-loaded background image.
// Each card pair is shuffled with BCryptGenRandom and flipped with a 3D rotate
// transform driven by the Windows Animation manager (v2). Mouse clicks hit-test
// the card grid, flip the card, and pair-match.
//
// Paradigm notes (Cangjie vs the reference language):
//   • The reference stashes `self as *mut Window` in GWLP_USERDATA and recovers
//     it in the wndproc. Cangjie is GC managed, so a managed object cannot be
//     round-tripped through a raw integer. This sample has exactly one window,
//     so the Window (a class, for persistent mutable per-window state) is held
//     in a top-level global `gWindow`; the top-level @C wndproc reads it and
//     dispatches to messageHandler. Behaviourally identical to the reference's
//     single-window self pointer; SetWindowLongPtrA is omitted.
//   • COM interface methods are invoked through the generator's per-interface
//     vtbl @C struct: read the vtbl pointer out of the raw COM pointer and call
//     methods through it — the exact ABI the reference's projected methods use.
//     Inherited methods are reached through nested `base_` fields (e.g. the
//     desktop device's CreateVisual/CreateSurface live on its base
//     IDCompositionDevice2; CreateTextFormat lives two levels down on
//     IDWriteFactory under IDWriteFactory2).
//   • There is no `cast::<T>()`; QueryInterface is performed with the documented
//     IID via windows_core.queryInterfaceRaw, returning the AddRef'd interface
//     pointer (wrapped takeOwnership so Release runs on drop).
//   • The reference creates IWICImagingFactory2; the generator does not surface
//     that newtype, only IWICImagingFactory. Both the WIC calls the sample uses
//     (CreateDecoderFromFilename / CreateFormatConverter) are inherited from the
//     IWICImagingFactory base, so creating the base interface is behaviourally
//     identical for this sample.
//   • There are no compile-time GUID literals; well-known IIDs/CLSIDs are parsed
//     at run time from their canonical string form — the run-time analogue.
//   • Scalar Win32/DXGI/D2D/DComp/DWrite/WIC flag values are not re-exported by
//     the facade, so the documented integer values are recorded as constants
//     below — semantically identical to the reference's enums.
//   • cfg!(debug_assertions) selects the release branch (no deck dump / no debug
//     prints), which is behaviourally equivalent for this sample.
//   • Matrix4x4 is the @C 16-f32 layout the IDCompositionMatrixTransform3D ABI
//     expects; windows_numerics provides translation / rotation_y / perspective
//     and the row-major 4x4 multiply, so a pointer to a built matrix is handed
//     straight to SetMatrix. Likewise Matrix3x2 for SetTransform.
//   • COM-pointer lifetimes are owned by the wrappers (raw pointers held in the
//     Window/Card classes, released explicitly); GC owns the wrappers.
// ============================================================================

// ---- Card grid geometry (the reference's consts) --------------------------
const CARD_ROWS: Int64 = 3
const CARD_COLUMNS: Int64 = 6
const CARD_MARGIN: Float32 = 15.0
const CARD_WIDTH: Float32 = 150.0
const CARD_HEIGHT: Float32 = 210.0
// WINDOW_WIDTH  = COLUMNS * (WIDTH + MARGIN) + MARGIN.
const WINDOW_WIDTH: Float32 = 6.0 * (150.0 + 15.0) + 15.0
// WINDOW_HEIGHT = ROWS * (HEIGHT + MARGIN) + MARGIN.
const WINDOW_HEIGHT: Float32 = 3.0 * (210.0 + 15.0) + 15.0

// ---- Well-known IIDs (canonical string form) ------------------------------
const IID_IUIAnimationManager2: String = "d8b6f7d4-4109-4d3f-acee-879926968cb1"
const IID_IUIAnimationTransitionLibrary2: String = "03cfae53-9580-4ee3-b363-2ece51b4af6a"
const IID_IDXGIDevice3: String = "6007896c-3244-4afd-bf18-a6d3beda5023"
const IID_ID2D1Device: String = "47dd575d-ac05-4cdd-8049-9b02cd16f44c"
const IID_IDCompositionDesktopDevice: String = "5f4633fe-1e08-4cb8-8c75-ce24333f5602"
const IID_IWICImagingFactory: String = "ec5ec8a9-c395-4314-9c77-54d7a935ff70"

// ---- Coclass CLSIDs --------------------------------------------------------
const CLSID_UIAnimationManager2: String = "d25d8842-8884-4a4a-b321-091314379bdd"
const CLSID_UIAnimationTransitionLibrary2: String = "812f944a-c5c8-4cd9-b0a6-b3da802f228d"

// ---- COM / process flags ---------------------------------------------------
const CLSCTX_INPROC_SERVER: UInt32 = 1
const COINIT_MULTITHREADED: UInt32 = 0
// DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 is the sentinel handle value -4.
const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2_VALUE: Int64 = -4
// MONITOR_DEFAULTTONEAREST.
const MONITOR_DEFAULTTONEAREST: UInt32 = 0x0000_0002
// MDT_EFFECTIVE_DPI.
const MDT_EFFECTIVE_DPI: Int32 = 0
// GENERIC_READ.
const GENERIC_READ: UInt32 = 0x8000_0000
// BCRYPT_USE_SYSTEM_PREFERRED_RNG.
const BCRYPT_USE_SYSTEM_PREFERRED_RNG: UInt32 = 0x0000_0002

// ---- D3D / DXGI / D2D / DComp scalar constants -----------------------------
const D3D_DRIVER_TYPE_HARDWARE: Int32 = 1
const D3D11_CREATE_DEVICE_BGRA_SUPPORT: UInt32 = 0x20
const D3D11_SDK_VERSION: UInt32 = 7
const D2D1_DEVICE_CONTEXT_OPTIONS_NONE: Int32 = 0
const DXGI_FORMAT_B8G8R8A8_UNORM: Int32 = 87
// DXGI_ALPHA_MODE_PREMULTIPLIED.
const DXGI_ALPHA_MODE_PREMULTIPLIED: Int32 = 1
const DCOMPOSITION_BACKFACE_VISIBILITY_HIDDEN: Int32 = 1
const D2D1_INTERPOLATION_MODE_LINEAR: Int32 = 1
const D2D1_DRAW_TEXT_OPTIONS_NONE: Int32 = 0
const DWRITE_MEASURING_MODE_NATURAL: Int32 = 0

// ---- DirectWrite text-format enums -----------------------------------------
const DWRITE_FACTORY_TYPE_SHARED: Int32 = 0
const DWRITE_FONT_WEIGHT_NORMAL: Int32 = 400
const DWRITE_FONT_STYLE_NORMAL: Int32 = 0
const DWRITE_FONT_STRETCH_NORMAL: Int32 = 5
const DWRITE_TEXT_ALIGNMENT_CENTER: Int32 = 2
const DWRITE_PARAGRAPH_ALIGNMENT_CENTER: Int32 = 2

// ---- WIC enums -------------------------------------------------------------
const WICDecodeMetadataCacheOnDemand: Int32 = 0
const WICBitmapDitherTypeNone: Int32 = 0
const WICBitmapPaletteTypeMedianCut: Int32 = 3

// ---- Window messages / styles ----------------------------------------------
const WM_LBUTTONUP: UInt32 = 0x0202
const WM_PAINT: UInt32 = 0x000F
const WM_DPICHANGED: UInt32 = 0x02E0
const WM_CREATE: UInt32 = 0x0001
const WM_WINDOWPOSCHANGING: UInt32 = 0x0046
const WM_DESTROY: UInt32 = 0x0002
const WM_NCCREATE: UInt32 = 0x0081
const WM_QUIT: UInt32 = 0x0012
const CS_HREDRAW: UInt32 = 0x0002
const CS_VREDRAW: UInt32 = 0x0001
const GWL_STYLE: Int32 = -16
const WS_OVERLAPPED: UInt32 = 0x0000_0000
const WS_CAPTION: UInt32 = 0x00C0_0000
const WS_SYSMENU: UInt32 = 0x0008_0000
const WS_MINIMIZEBOX: UInt32 = 0x0002_0000
const WS_VISIBLE: UInt32 = 0x1000_0000
const WS_EX_NOREDIRECTIONBITMAP: UInt32 = 0x0020_0000
const CW_USEDEFAULT: Int32 = -2147483648
const IDC_ARROW_ID: Int64 = 32512
const SWP_NOACTIVATE: UInt32 = 0x0010
const SWP_NOZORDER: UInt32 = 0x0004
const SWP_NOMOVE: UInt32 = 0x0002

// ===========================================================================
// Status / Card / Window state.
// ===========================================================================

// enum Status { Hidden | Selected | Matched }. Equatable so it can be compared
// with == (the reference derives PartialEq).
enum Status <: Equatable<Status> {
    | Hidden
    | Selected
    | Matched

    public operator func ==(other: Status): Bool {
        match ((this, other)) {
            case (Hidden, Hidden) => true
            case (Selected, Selected) => true
            case (Matched, Matched) => true
            case _ => false
        }
    }

    public operator func !=(other: Status): Bool {
        !(this == other)
    }
}

// A single card. `variable` and `rotation` are owned raw COM pointers; offset is
// the card's physical top-left in the root visual.
class Card {
    var status: Status = Hidden
    var value: UInt8 = 0
    var offsetX: Float32 = 0.0
    var offsetY: Float32 = 0.0
    let variable: CPointer<Unit> // IUIAnimationVariable2 (owned)
    var rotation: CPointer<Unit> = CPointer<Unit>() // IDCompositionRotateTransform3D (owned)

    init(value: UInt8, variable: CPointer<Unit>) {
        this.value = value
        this.variable = variable
    }
}

// QueryInterface a raw COM pointer for the given IID, returning the AddRef'd
// interface pointer or throwing E_NOINTERFACE (the reference's `cast::<T>()`).
func castRaw(source: CPointer<Unit>, iid: String): CPointer<Unit> {
    match (unsafe { queryInterfaceRaw(source, GUID.parse(iid)) }) {
        case Some(raw) => raw
        case None => throw WindowsException(E_NOINTERFACE)
    }
}

// QueryInterface returning an Option (the reference's `.cast().ok()`); used when
// a null entry is acceptable (transform-group members).
func castRawOption(source: CPointer<Unit>, iid: String): CPointer<Unit> {
    match (unsafe { queryInterfaceRaw(source, GUID.parse(iid)) }) {
        case Some(raw) => raw
        case None => CPointer<Unit>()
    }
}

// Release a raw COM pointer.
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

func physicalToLogical(pixel: Float32, dpi: Float32): Float32 {
    pixel * 96.0f32 / dpi
}

func logicalToPhysical(pixel: Float32, dpi: Float32): Float32 {
    pixel * dpi / 96.0f32
}

// ===========================================================================
// The window. A class so its mutable device-dependent state survives across the
// many messages a single window receives.
// ===========================================================================
class Window {
    var handle: HWND = HWND()
    var dpiX: Float32 = 0.0
    var dpiY: Float32 = 0.0

    let format: CPointer<Unit>   // IDWriteTextFormat (owned)
    let image: CPointer<Unit>    // IWICFormatConverter (owned)
    let manager: CPointer<Unit>  // IUIAnimationManager2 (owned)
    let library: CPointer<Unit>  // IUIAnimationTransitionLibrary2 (owned)

    var first: ?Int64 = None
    let cards: ArrayList<Card> = ArrayList<Card>()

    var device: CPointer<Unit> = CPointer<Unit>()   // ID3D11Device (owned)
    var desktop: CPointer<Unit> = CPointer<Unit>()  // IDCompositionDesktopDevice (owned)
    var target: CPointer<Unit> = CPointer<Unit>()   // IDCompositionTarget (owned)

    init() {
        manager = coCreateInstance(CLSID_UIAnimationManager2, IID_IUIAnimationManager2)

        // values is a row*column byte deck; build pairs of upper/lower letters
        // then shuffle, exactly mirroring the reference's two BCryptGenRandom
        // passes (Fisher-Yates-style per-byte modulo swap).
        let count = CARD_ROWS * CARD_COLUMNS
        let values = Array<UInt8>(count, repeat: UInt8(63)) // b'?'
        let randomBytes = Array<UInt8>(count, repeat: 0u8)

        genRandom(randomBytes)
        let a: UInt8 = 65 // b'A'
        var i = 0
        while (i < count / 2) {
            let value = a + (randomBytes[i] % 26)
            values[i * 2] = value
            values[i * 2 + 1] = value + 97 - 65 // + b'a' - b'A'
            i += 1
        }

        genRandom(randomBytes)
        i = 0
        while (i < count) {
            let j = Int64(randomBytes[i]) % count
            let tmp = values[i]
            values[i] = values[j]
            values[j] = tmp
            i += 1
        }

        // One card per deck value, each with its own animation variable at 0.0.
        i = 0
        while (i < count) {
            let variable = managerCreateAnimationVariable(manager, 0.0)
            cards.add(Card(values[i], variable))
            i += 1
        }

        // The reference dumps the deck under debug_assertions; the release branch
        // (no dump) is behaviourally equivalent.

        library = coCreateInstance(CLSID_UIAnimationTransitionLibrary2, IID_IUIAnimationTransitionLibrary2)
        format = createTextFormat()
        image = createImage()
    }

    // Build all device-dependent resources, then commit the composition tree.
    func createDeviceResources(): Unit {
        let device3d = createDevice3d()
        let device2d = createDevice2d(device3d)
        device = device3d

        // First release any previous target, otherwise CreateTargetForHwnd finds
        // the HWND occupied.
        releaseRaw(target)
        target = CPointer<Unit>()

        let desktopDevice = dCompositionCreateDevice2(device2d)
        let newTarget = createTargetForHwnd(desktopDevice, handle)
        let rootVisual = createVisual(desktopDevice)
        try {
            targetSetRoot(newTarget, rootVisual)
            target = newTarget

            let dc = deviceCreateDeviceContext(device2d)
            let brush = createSolidColorBrush(dc)
            let bitmap = createBitmapFromWicBitmap(dc, image)
            try {
                try {
                    let width = logicalToPhysical(CARD_WIDTH, dpiX)
                    let height = logicalToPhysical(CARD_HEIGHT, dpiY)

                    var row = 0
                    while (row < CARD_ROWS) {
                        var column = 0
                        while (column < CARD_COLUMNS) {
                            let card = cards[row * CARD_COLUMNS + column]

                            card.offsetX = logicalToPhysical(
                                Float32(column) * (CARD_WIDTH + CARD_MARGIN) + CARD_MARGIN, dpiX)
                            card.offsetY = logicalToPhysical(
                                Float32(row) * (CARD_HEIGHT + CARD_MARGIN) + CARD_MARGIN, dpiY)

                            if (card.status == Matched) {
                                column += 1
                                continue
                            }

                            let frontVisual = createVisual(desktopDevice)
                            visualSetOffsetX(frontVisual, card.offsetX)
                            visualSetOffsetY(frontVisual, card.offsetY)
                            visualAddVisual(rootVisual, frontVisual)

                            let backVisual = createVisual(desktopDevice)
                            visualSetOffsetX(backVisual, card.offsetX)
                            visualSetOffsetY(backVisual, card.offsetY)
                            visualAddVisual(rootVisual, backVisual)

                            let frontSurface = createSurface(desktopDevice, width, height)
                            visualSetContent(frontVisual, frontSurface)
                            drawCardFront(frontSurface, card.value, format, brush)

                            let backSurface = createSurface(desktopDevice, width, height)
                            visualSetContent(backVisual, backSurface)
                            drawCardBack(backSurface, bitmap, card.offsetX, card.offsetY)

                            let rotation = createRotateTransform3D(desktopDevice)
                            if (card.status == Selected) {
                                rotateSetAngle2(rotation, 180.0)
                            }
                            rotateSetAxisZ2(rotation, 0.0)
                            rotateSetAxisY2(rotation, 1.0)
                            createEffect(desktopDevice, frontVisual, rotation, true)
                            createEffect(desktopDevice, backVisual, rotation, false)

                            // Release the previous rotation (if any) and take this one.
                            releaseRaw(card.rotation)
                            card.rotation = rotation

                            // The visuals and surfaces are referenced by the
                            // composition tree; release our local references.
                            releaseRaw(frontSurface)
                            releaseRaw(backSurface)
                            releaseRaw(frontVisual)
                            releaseRaw(backVisual)

                            column += 1
                        }
                        row += 1
                    }

                    deviceCommit(desktopDevice)
                    desktop = desktopDevice
                } finally {
                    releaseRaw(bitmap)
                    releaseRaw(brush)
                }
            } finally {
                releaseRaw(dc)
            }
        } finally {
            releaseRaw(rootVisual)
            releaseRaw(device2d)
        }
    }

    // AdjustWindowRect-based physical client+frame size.
    func effectiveWindowSize(): (Int32, Int32) {
        var rect = RECT()
        rect.left = 0
        rect.top = 0
        rect.right = Int32(f32ToI32(logicalToPhysical(WINDOW_WIDTH, dpiX)))
        rect.bottom = Int32(f32ToI32(logicalToPhysical(WINDOW_HEIGHT, dpiY)))

        let style = unsafe { WndApis.GetWindowLongW(handle, GWL_STYLE) }
        unsafe {
            let _ = WndApis.AdjustWindowRect(
                CPointer<Unit>(CPointer<RECT>(inout rect)),
                UInt32(style),
                0
            )
        }
        return (rect.right - rect.left, rect.bottom - rect.top)
    }

    // WM_LBUTTONUP: hit-test the grid, flip / pair-match.
    func clickHandler(lparam: IntNative): Unit {
        // x = low 16 bits (unsigned); y = arithmetic >> 16 (signed). Mirrors the
        // reference's `lparam.0 as u16 as f32` / `(lparam.0 >> 16) as f32`. The
        // low-16 mask keeps a non-negative value so the Float32 cast is safe.
        let x = Float32(Int64(lparam) & 0xFFFF)
        let y = Float32(Int64(lparam) >> 16)

        let width = logicalToPhysical(CARD_WIDTH, dpiX)
        let height = logicalToPhysical(CARD_HEIGHT, dpiY)

        var next: ?Int64 = None
        var index = 0
        while (index < cards.size) {
            let card = cards[index]
            if (x > card.offsetX && y > card.offsetY && x < card.offsetX + width &&
                y < card.offsetY + height) {
                next = Some(index)
                break
            }
            index += 1
        }

        match (next) {
            case Some(nextIdx) =>
                // Same card already chosen, or already matched: nothing to do.
                match (first) {
                    case Some(f) where f == nextIdx => return ()
                    case _ => ()
                }
                if (cards[nextIdx].status == Matched) {
                    return ()
                }

                let stats = getFrameStatistics(desktop)
                let nextFrame = Float64(stats.nextEstimatedFrameTime) / Float64(stats.timeFrequency)

                managerUpdate(manager, nextFrame)
                let storyboard = managerCreateStoryboard(manager)
                try {
                    let keyFrame = addShowTransition(library, storyboard, cards[nextIdx])

                    match (first) {
                        case Some(firstIdx) =>
                            first = None
                            // diff(b'a' - b'A') == |first.value - next.value| means a pair.
                            let diff = absDiffU8(cards[firstIdx].value, cards[nextIdx].value)
                            var finalValue: Float64 = 0.0
                            if (UInt8(97 - 65) == diff) {
                                cards[firstIdx].status = Matched
                                cards[nextIdx].status = Matched
                                finalValue = 90.0
                            } else {
                                cards[firstIdx].status = Hidden
                                finalValue = 0.0
                            }

                            addHideTransition(library, storyboard, keyFrame, finalValue, cards[firstIdx])
                            addHideTransition(library, storyboard, keyFrame, finalValue, cards[nextIdx])

                            storyboardSchedule(storyboard, nextFrame)
                            updateAnimation(desktop, cards[firstIdx])
                            updateAnimation(desktop, cards[nextIdx])
                        case None =>
                            first = Some(nextIdx)
                            cards[nextIdx].status = Selected
                            storyboardSchedule(storyboard, nextFrame)
                            updateAnimation(desktop, cards[nextIdx])
                    }

                    deviceCommit(desktop)
                } finally {
                    releaseRaw(storyboard)
                }
            case None => ()
        }
    }

    // WM_PAINT: build the device on first paint, otherwise check for device loss.
    func paintHandler(): Unit {
        if (device.isNotNull()) {
            // GetDeviceRemovedReason(): if the device was removed this throws and
            // the caller drops the device (handled in messageHandler).
            getDeviceRemovedReason(device)
        } else {
            createDeviceResources()
        }
        unsafe {
            let _ = GdiApis.ValidateRect(handle, CPointer<Unit>())
        }
    }

    // WM_DPICHANGED: adopt the suggested rect + recompute the frame size, drop
    // the device so it rebuilds at the new DPI.
    func dpiChangedHandler(wparam: UIntNative, lparam: IntNative): Unit {
        // wparam is unsigned (UIntNative); low 16 bits = dpiX, high 16 = dpiY.
        dpiX = Float32(UInt64(wparam) & 0xFFFFu64)
        dpiY = Float32((UInt64(wparam) >> 16) & 0xFFFFu64)

        // lparam points at the suggested RECT.
        let rectPtr = unsafe { CPointer<RECT>(handlePointerFromInt(Int64(lparam))) }
        let rect = unsafe { rectPtr.read() }
        let size = effectiveWindowSize()

        unsafe {
            let _ = WndApis.SetWindowPos(
                handle,
                HWND(),
                rect.left,
                rect.top,
                size[0],
                size[1],
                SWP_NOACTIVATE | SWP_NOZORDER
            )
        }
        releaseRaw(device)
        device = CPointer<Unit>()
    }

    // WM_CREATE: read the monitor DPI and size the window frame.
    func createHandler(): Unit {
        let monitor = unsafe { WndApis_MonitorFromWindow(handle, MONITOR_DEFAULTTONEAREST) }
        var dpiXi: UInt32 = 0
        var dpiYi: UInt32 = 0
        unsafe {
            let hr = HiDpiApis.GetDpiForMonitor(
                monitor,
                MDT_EFFECTIVE_DPI,
                CPointer<Unit>(CPointer<UInt32>(inout dpiXi)),
                CPointer<Unit>(CPointer<UInt32>(inout dpiYi))
            )
            HRESULT(hr).check()
        }
        dpiX = Float32(dpiXi)
        dpiY = Float32(dpiYi)

        let size = effectiveWindowSize()
        unsafe {
            let _ = WndApis.SetWindowPos(
                handle,
                HWND(),
                0,
                0,
                size[0],
                size[1],
                SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOZORDER
            )
        }
    }

    func messageHandler(message: UInt32, wparam: UIntNative, lparam: IntNative): IntNative {
        match (message) {
            case 0x0202 => // WM_LBUTTONUP
                clickHandler(lparam)
                return 0
            case 0x000F => // WM_PAINT
                try {
                    paintHandler()
                } catch (e: Exception) {
                    // Device loss can cause rendering to fail and should not be
                    // considered fatal.
                    releaseRaw(device)
                    device = CPointer<Unit>()
                }
                return 0
            case 0x02E0 => // WM_DPICHANGED
                dpiChangedHandler(wparam, lparam)
                return 0
            case 0x0001 => // WM_CREATE
                createHandler()
                return 0
            case 0x0046 => // WM_WINDOWPOSCHANGING (prevents resize on device loss)
                return 0
            case 0x0002 => // WM_DESTROY
                unsafe { WndApis.PostQuitMessage(0) }
                return 0
            case _ =>
                return unsafe { WndApis.DefWindowProcA(handle, message, wparam, lparam) }
        }
    }

    func run(): Unit {
        let instance = unsafe { LoaderApis.GetModuleHandleA(CPointer<UInt8>()) }

        let classNameArr = narrowBytes("window")
        let titleArr = narrowBytes("Sample Window")
        let classHandle = unsafe { acquireArrayRawData(classNameArr) }
        let titleHandle = unsafe { acquireArrayRawData(titleArr) }
        try {
            let cursor = unsafe {
                WndApis.LoadCursorW(HINSTANCE(), CPointer<UInt16>(handlePointerFromInt(IDC_ARROW_ID)))
            }

            var hinst = HINSTANCE()
            hinst.Value = instance.Value

            var wc = WNDCLASSA()
            wc.hCursor = cursor
            wc.hInstance = hinst
            wc.lpszClassName = classHandle.pointer
            wc.style = CS_HREDRAW | CS_VREDRAW
            wc.lpfnWndProc = wndproc

            let atom = unsafe {
                WndApis.RegisterClassA(CPointer<Unit>(CPointer<WNDCLASSA>(inout wc)))
            }
            if (atom == 0) {
                return ()
            }

            // The reference passes `self` as the create-param to recover it in
            // WM_NCCREATE; we publish gWindow before creation so the wndproc has
            // it from the very first message.
            let win = unsafe {
                WndApis.CreateWindowExA(
                    WS_EX_NOREDIRECTIONBITMAP,
                    classHandle.pointer,
                    titleHandle.pointer,
                    WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_VISIBLE,
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
            handle = win
            if (win.Value.isNull()) {
                return ()
            }

            var message = MSG()
            let msgPtr = unsafe { CPointer<Unit>(CPointer<MSG>(inout message)) }
            while (unsafe { WndApis.GetMessageA(msgPtr, HWND(), 0, 0) } != 0) {
                unsafe { WndApis.DispatchMessageA(msgPtr) }
            }
        } finally {
            unsafe {
                releaseArrayRawData(classHandle)
                releaseArrayRawData(titleHandle)
            }
        }
    }
}

// |a - b| for UInt8 (the reference's u8::abs_diff).
func absDiffU8(a: UInt8, b: UInt8): UInt8 {
    if (a >= b) {
        a - b
    } else {
        b - a
    }
}

// Saturating-ish Float32 -> Int32 truncation toward zero (the reference's
// `as i32`; NaN/negative-overflow guarded so the checked cast never panics).
func f32ToI32(value: Float32): Int32 {
    if (value.isNaN()) {
        return 0
    }
    if (value >= 2147483647.0f32) {
        return Int32.Max
    }
    if (value <= -2147483648.0f32) {
        return Int32.Min
    }
    return Int32(value)
}

// Saturating Float32 -> UInt32 (the reference's `as u32` on a non-negative).
func f32ToU32(value: Float32): UInt32 {
    if (value.isNaN() || value <= 0.0f32) {
        return 0
    }
    if (value >= 4294967296.0f32) {
        return UInt32.Max
    }
    return UInt32(value)
}

// Build a NUL-terminated narrow (ANSI) byte array for class/title strings.
func narrowBytes(s: String): Array<UInt8> {
    let bytes = s.toArray()
    let result = Array<UInt8>(bytes.size + 1, repeat: 0u8)
    var i = 0
    while (i < bytes.size) {
        result[i] = bytes[i]
        i += 1
    }
    return result
}

// ===========================================================================
// BCryptGenRandom(None, buffer, BCRYPT_USE_SYSTEM_PREFERRED_RNG).
// ===========================================================================
func genRandom(buffer: Array<UInt8>): Unit {
    let handle = unsafe { acquireArrayRawData(buffer) }
    try {
        unsafe {
            let hr = CryptoApis.BCryptGenRandom(
                BCRYPT_ALG_HANDLE(),
                CPointer<Unit>(handle.pointer),
                UInt32(buffer.size),
                BCRYPT_USE_SYSTEM_PREFERRED_RNG
            )
            HRESULT(hr).check()
        }
    } finally {
        unsafe { releaseArrayRawData(handle) }
    }
}

// ===========================================================================
// CoCreateInstance(clsid, None, CLSCTX_INPROC_SERVER, iid) -> owned raw pointer.
// ===========================================================================
func coCreateInstance(clsidStr: String, iidStr: String): CPointer<Unit> {
    var clsid = GUID.parse(clsidStr)
    var iid = GUID.parse(iidStr)
    var outRaw = CPointer<Unit>()
    unsafe {
        let hr = ComApis.CoCreateInstance(
            CPointer<Unit>(CPointer<GUID>(inout clsid)),
            CPointer<Unit>(),
            CLSCTX_INPROC_SERVER,
            CPointer<Unit>(CPointer<GUID>(inout iid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// ===========================================================================
// create_text_format(): IDWriteFactory2 -> CreateTextFormat(Candara, en) ->
// SetTextAlignment(CENTER) / SetParagraphAlignment(CENTER).
// ===========================================================================
func createTextFormat(): CPointer<Unit> {
    var iid = GUID.parse(IID_IDWriteFactory2())
    var factory = CPointer<Unit>()
    unsafe {
        let hr = DWriteApis.DWriteCreateFactory(
            DWRITE_FACTORY_TYPE_SHARED,
            CPointer<Unit>(CPointer<GUID>(inout iid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout factory))
        )
        HRESULT(hr).check()
    }

    let fontName = encodeUtf16WithNull("Candara")
    let locale = encodeUtf16WithNull("en")
    let fontHandle = unsafe { acquireArrayRawData(fontName) }
    let localeHandle = unsafe { acquireArrayRawData(locale) }
    var formatRaw = CPointer<Unit>()
    try {
        unsafe {
            // CreateTextFormat lives on IDWriteFactory == Factory2.base_.base_.
            let vtbl = CPointer<CPointer<IDWriteFactory2Vtbl>>(factory).read().read()
            let hr = vtbl.base_.base_.CreateTextFormat(
                factory,
                fontHandle.pointer,
                CPointer<Unit>(),
                DWRITE_FONT_WEIGHT_NORMAL,
                DWRITE_FONT_STYLE_NORMAL,
                DWRITE_FONT_STRETCH_NORMAL,
                CARD_HEIGHT / 2.0f32,
                localeHandle.pointer,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout formatRaw))
            )
            HRESULT(hr).check()
        }
    } finally {
        unsafe {
            releaseArrayRawData(fontHandle)
            releaseArrayRawData(localeHandle)
        }
    }

    unsafe {
        let vtbl = CPointer<CPointer<IDWriteTextFormatVtbl>>(formatRaw).read().read()
        let hr1 = vtbl.SetTextAlignment(formatRaw, DWRITE_TEXT_ALIGNMENT_CENTER)
        HRESULT(hr1).check()
        let hr2 = vtbl.SetParagraphAlignment(formatRaw, DWRITE_PARAGRAPH_ALIGNMENT_CENTER)
        HRESULT(hr2).check()
    }
    releaseRaw(factory)
    return formatRaw
}

// IID_IDWriteFactory2 (canonical string form).
func IID_IDWriteFactory2(): String {
    return "0439fc60-ca44-4994-8dee-3a9af7b732ec"
}

// ===========================================================================
// create_image(): IWICImagingFactory -> CreateDecoderFromFilename ->
// GetFrame(0) -> CreateFormatConverter -> Initialize(32bppBGR).
// ===========================================================================
func createImage(): CPointer<Unit> {
    let factory = coCreateInstance(WICCLSID(), IID_IWICImagingFactory)
    try {
        let pathArr = resolveImagePath()
        let pathHandle = unsafe { acquireArrayRawData(pathArr) }
        var decoder = CPointer<Unit>()
        try {
            unsafe {
                let vtbl = CPointer<CPointer<IWICImagingFactoryVtbl>>(factory).read().read()
                let hr = vtbl.CreateDecoderFromFilename(
                    factory,
                    pathHandle.pointer,
                    CPointer<Unit>(),
                    GENERIC_READ,
                    WICDecodeMetadataCacheOnDemand,
                    CPointer<Unit>(CPointer<CPointer<Unit>>(inout decoder))
                )
                HRESULT(hr).check()
            }
        } finally {
            unsafe { releaseArrayRawData(pathHandle) }
        }

        // source = decoder.GetFrame(0).
        var source = CPointer<Unit>()
        try {
            unsafe {
                let vtbl = CPointer<CPointer<IWICBitmapDecoderVtbl>>(decoder).read().read()
                let hr = vtbl.GetFrame(
                    decoder,
                    0,
                    CPointer<Unit>(CPointer<CPointer<Unit>>(inout source))
                )
                HRESULT(hr).check()
            }

            // converter = factory.CreateFormatConverter().
            var converter = CPointer<Unit>()
            unsafe {
                let vtbl = CPointer<CPointer<IWICImagingFactoryVtbl>>(factory).read().read()
                let hr = vtbl.CreateFormatConverter(
                    factory,
                    CPointer<Unit>(CPointer<CPointer<Unit>>(inout converter))
                )
                HRESULT(hr).check()
            }

            // converter.Initialize(source, 32bppBGR, None dither, None palette,
            // 0.0, MedianCut).
            var dstFormat = WICApis.GUID_WICPixelFormat32bppBGR()
            unsafe {
                let vtbl = CPointer<CPointer<IWICFormatConverterVtbl>>(converter).read().read()
                let hr = vtbl.Initialize(
                    converter,
                    source,
                    CPointer<Unit>(CPointer<GUID>(inout dstFormat)),
                    WICBitmapDitherTypeNone,
                    CPointer<Unit>(),
                    0.0,
                    WICBitmapPaletteTypeMedianCut
                )
                HRESULT(hr).check()
            }
            releaseRaw(decoder)
            return converter
        } finally {
            releaseRaw(source)
        }
    } finally {
        releaseRaw(factory)
    }
}

// CLSID_WICImagingFactory string form (matches the bindings' factory GUID).
func WICCLSID(): String {
    return "cacaf262-9370-4615-a13b-9f5539da4c0a"
}

// Resolve the background image path: prefer "image.jpg" in the cwd (the
// reference's PathFileExistsW probe), else the sample's source subdirectory.
// Returns a NUL-terminated UTF-16 path buffer.
func resolveImagePath(): Array<UInt16> {
    let primary = encodeUtf16WithNull("image.jpg")
    let primaryHandle = unsafe { acquireArrayRawData(primary) }
    var exists = false
    try {
        exists = unsafe { ShellApis.PathFileExistsW(primaryHandle.pointer) } != 0
    } finally {
        unsafe { releaseArrayRawData(primaryHandle) }
    }
    if (exists) {
        return primary
    }
    return encodeUtf16WithNull("samples\\windows\\dcomp\\image.jpg")
}

// ===========================================================================
// create_device_3d(): D3D11CreateDevice(HARDWARE, BGRA_SUPPORT).
// ===========================================================================
func createDevice3d(): CPointer<Unit> {
    var deviceRaw = CPointer<Unit>()
    unsafe {
        let hr = D3D11Apis.D3D11CreateDevice(
            CPointer<Unit>(),
            D3D_DRIVER_TYPE_HARDWARE,
            HMODULE(),
            D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            CPointer<Unit>(),
            0,
            D3D11_SDK_VERSION,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout deviceRaw)),
            CPointer<Unit>(),
            CPointer<Unit>()
        )
        HRESULT(hr).check()
    }
    return deviceRaw
}

// ===========================================================================
// create_device_2d(): device3d.cast::<IDXGIDevice3>() -> D2D1CreateDevice.
// ===========================================================================
func createDevice2d(device3d: CPointer<Unit>): CPointer<Unit> {
    let dxgi = castRaw(device3d, IID_IDXGIDevice3)
    var outRaw = CPointer<Unit>()
    try {
        unsafe {
            let hr = D2DApis.D2D1CreateDevice(
                dxgi,
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
            )
            HRESULT(hr).check()
        }
    } finally {
        releaseRaw(dxgi)
    }
    return outRaw
}

// DCompositionCreateDevice2(device2d) -> IDCompositionDesktopDevice (owned).
func dCompositionCreateDevice2(device2d: CPointer<Unit>): CPointer<Unit> {
    var iid = GUID.parse(IID_IDCompositionDesktopDevice)
    var outRaw = CPointer<Unit>()
    unsafe {
        let hr = DCompApis.DCompositionCreateDevice2(
            device2d,
            CPointer<Unit>(CPointer<GUID>(inout iid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// ===========================================================================
// Desktop-device vtbl helpers. CreateVisual / CreateSurface / CreateRotate /
// CreateMatrix / CreateTransform3DGroup / CreateAnimation / Commit /
// GetFrameStatistics live on IDCompositionDevice2 (the desktop device's base);
// CreateTargetForHwnd lives on IDCompositionDesktopDevice (top level).
// ===========================================================================

func createTargetForHwnd(desktop: CPointer<Unit>, hwnd: HWND): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionDesktopDeviceVtbl>>(desktop).read().read()
        let hr = vtbl.CreateTargetForHwnd(
            desktop,
            hwnd,
            1, // topmost = TRUE
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// create_visual(): device.CreateVisual() then SetBackFaceVisibility(HIDDEN).
func createVisual(desktop: CPointer<Unit>): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionDesktopDeviceVtbl>>(desktop).read().read()
        let hr = vtbl.base_.CreateVisual(desktop, CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw)))
        HRESULT(hr).check()
    }
    // SetBackFaceVisibility on IDCompositionVisual2.
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionVisual2Vtbl>>(outRaw).read().read()
        let hr = vtbl.SetBackFaceVisibility(outRaw, DCOMPOSITION_BACKFACE_VISIBILITY_HIDDEN)
        HRESULT(hr).check()
    }
    return outRaw
}

func createSurface(desktop: CPointer<Unit>, width: Float32, height: Float32): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionDesktopDeviceVtbl>>(desktop).read().read()
        let hr = vtbl.base_.CreateSurface(
            desktop,
            f32ToU32(width),
            f32ToU32(height),
            DXGI_FORMAT_B8G8R8A8_UNORM,
            DXGI_ALPHA_MODE_PREMULTIPLIED,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

func createRotateTransform3D(desktop: CPointer<Unit>): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionDesktopDeviceVtbl>>(desktop).read().read()
        let hr = vtbl.base_.CreateRotateTransform3D(desktop, CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw)))
        HRESULT(hr).check()
    }
    return outRaw
}

func createMatrixTransform3D(desktop: CPointer<Unit>): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionDesktopDeviceVtbl>>(desktop).read().read()
        let hr = vtbl.base_.CreateMatrixTransform3D(desktop, CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw)))
        HRESULT(hr).check()
    }
    return outRaw
}

// CreateTransform3DGroup(transforms[], count) -> owned IDCompositionTransform3D.
func createTransform3DGroup(desktop: CPointer<Unit>, transforms: Array<CPointer<Unit>>): CPointer<Unit> {
    let handle = unsafe { acquireArrayRawData(transforms) }
    var outRaw = CPointer<Unit>()
    try {
        unsafe {
            let vtbl = CPointer<CPointer<IDCompositionDesktopDeviceVtbl>>(desktop).read().read()
            let hr = vtbl.base_.CreateTransform3DGroup(
                desktop,
                CPointer<Unit>(handle.pointer),
                UInt32(transforms.size),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
            )
            HRESULT(hr).check()
        }
    } finally {
        unsafe { releaseArrayRawData(handle) }
    }
    return outRaw
}

func createAnimation(desktop: CPointer<Unit>): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionDesktopDeviceVtbl>>(desktop).read().read()
        let hr = vtbl.base_.CreateAnimation(desktop, CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw)))
        HRESULT(hr).check()
    }
    return outRaw
}

func deviceCommit(desktop: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionDesktopDeviceVtbl>>(desktop).read().read()
        let hr = vtbl.base_.Commit(desktop)
        HRESULT(hr).check()
    }
}

func getFrameStatistics(desktop: CPointer<Unit>): DCOMPOSITION_FRAME_STATISTICS {
    var stats = DCOMPOSITION_FRAME_STATISTICS()
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionDesktopDeviceVtbl>>(desktop).read().read()
        let hr = vtbl.base_.GetFrameStatistics(
            desktop,
            CPointer<Unit>(CPointer<DCOMPOSITION_FRAME_STATISTICS>(inout stats))
        )
        HRESULT(hr).check()
    }
    return stats
}

// ===========================================================================
// IDCompositionTarget::SetRoot.
// ===========================================================================
func targetSetRoot(target: CPointer<Unit>, visual: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionTargetVtbl>>(target).read().read()
        let hr = vtbl.SetRoot(target, visual)
        HRESULT(hr).check()
    }
}

// ===========================================================================
// IDCompositionVisual(2) helpers. SetOffsetX2/SetOffsetY2 == the float overload
// (_1); SetContent / AddVisual / SetEffect live on the IDCompositionVisual base.
// ===========================================================================
func visualSetOffsetX(visual: CPointer<Unit>, value: Float32): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionVisual2Vtbl>>(visual).read().read()
        let hr = vtbl.base_.SetOffsetX_1(visual, value)
        HRESULT(hr).check()
    }
}

func visualSetOffsetY(visual: CPointer<Unit>, value: Float32): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionVisual2Vtbl>>(visual).read().read()
        let hr = vtbl.base_.SetOffsetY_1(visual, value)
        HRESULT(hr).check()
    }
}

func visualAddVisual(parent: CPointer<Unit>, child: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionVisual2Vtbl>>(parent).read().read()
        // AddVisual(child, insertAbove=FALSE, referenceVisual=None).
        let hr = vtbl.base_.AddVisual(parent, child, 0, CPointer<Unit>())
        HRESULT(hr).check()
    }
}

func visualSetContent(visual: CPointer<Unit>, content: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionVisual2Vtbl>>(visual).read().read()
        let hr = vtbl.base_.SetContent(visual, content)
        HRESULT(hr).check()
    }
}

func visualSetEffect(visual: CPointer<Unit>, effect: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionVisual2Vtbl>>(visual).read().read()
        let hr = vtbl.base_.SetEffect(visual, effect)
        HRESULT(hr).check()
    }
}

// ===========================================================================
// IDCompositionRotateTransform3D float setters (SetAngle2 / SetAxisY2 / etc.).
// ===========================================================================
func rotateSetAngle2(rotation: CPointer<Unit>, value: Float32): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionRotateTransform3DVtbl>>(rotation).read().read()
        let hr = vtbl.SetAngle_1(rotation, value)
        HRESULT(hr).check()
    }
}

func rotateSetAxisY2(rotation: CPointer<Unit>, value: Float32): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionRotateTransform3DVtbl>>(rotation).read().read()
        let hr = vtbl.SetAxisY_1(rotation, value)
        HRESULT(hr).check()
    }
}

func rotateSetAxisZ2(rotation: CPointer<Unit>, value: Float32): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionRotateTransform3DVtbl>>(rotation).read().read()
        let hr = vtbl.SetAxisZ_1(rotation, value)
        HRESULT(hr).check()
    }
}

// rotation.SetAngle(animation) — the animation-driven angle setter.
func rotateSetAngleAnimation(rotation: CPointer<Unit>, animation: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionRotateTransform3DVtbl>>(rotation).read().read()
        let hr = vtbl.SetAngle(rotation, animation)
        HRESULT(hr).check()
    }
}

// matrixTransform.SetMatrix(&matrix).
func matrixSetMatrix(transform: CPointer<Unit>, matrix: Matrix4x4): Unit {
    var m = matrix
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionMatrixTransform3DVtbl>>(transform).read().read()
        let hr = vtbl.SetMatrix(transform, CPointer<Unit>(CPointer<Matrix4x4>(inout m)))
        HRESULT(hr).check()
    }
}

// ===========================================================================
// create_effect(): pre-translate+rotate, post-perspective+translate, group the
// pre/rotation/post transforms and bind to the visual's effect.
// ===========================================================================
func createEffect(
    desktop: CPointer<Unit>,
    visual: CPointer<Unit>,
    rotation: CPointer<Unit>,
    front: Bool
): Unit {
    // dpi-scaled card dimensions; uses the desktop's owning Window dpi via the
    // global (the reference threads dpi through; we read it from gWindow, which
    // is the same single window).
    let dpiX = currentDpiX()
    let dpiY = currentDpiY()
    let width = logicalToPhysical(CARD_WIDTH, dpiX)
    let height = logicalToPhysical(CARD_HEIGHT, dpiY)

    let yAngle = if (front) { 180.0f32 } else { 0.0f32 }
    let preMatrix = multiply(
        translationMatrix4x4(-width / 2.0f32, -height / 2.0f32, 0.0f32),
        rotationYMatrix4x4(yAngle)
    )
    let preTransform = createMatrixTransform3D(desktop)
    matrixSetMatrix(preTransform, preMatrix)

    let postMatrix = multiply(
        perspectiveProjectionMatrix4x4(width * 2.0f32),
        translationMatrix4x4(width / 2.0f32, height / 2.0f32, 0.0f32)
    )
    let postTransform = createMatrixTransform3D(desktop)
    matrixSetMatrix(postTransform, postMatrix)

    // The group members are IDCompositionTransform3D casts of pre, rotation, post.
    let preCast = castRawOption(preTransform, IID_IDCompositionTransform3D())
    let rotCast = castRawOption(rotation, IID_IDCompositionTransform3D())
    let postCast = castRawOption(postTransform, IID_IDCompositionTransform3D())
    let members: Array<CPointer<Unit>> = [preCast, rotCast, postCast]

    let group = createTransform3DGroup(desktop, members)
    visualSetEffect(visual, group)

    // Release the casts and the local pre/post transforms; the group + visual
    // retain what they need.
    releaseRaw(preCast)
    releaseRaw(rotCast)
    releaseRaw(postCast)
    releaseRaw(group)
    releaseRaw(preTransform)
    releaseRaw(postTransform)
}

// IID_IDCompositionTransform3D (canonical string form).
func IID_IDCompositionTransform3D(): String {
    return "71185722-246b-41f2-aad1-0443f7f4bfc2"
}

// ===========================================================================
// Animation transition helpers (the reference's free functions).
// ===========================================================================

// add_show_transition: duration = (180 - variable.GetValue()) / 180; build an
// accelerate-decelerate transition to 180; add it; return the keyframe after it.
func addShowTransition(
    library: CPointer<Unit>,
    storyboard: CPointer<Unit>,
    card: Card
): UI_ANIMATION_KEYFRAME {
    let current = variableGetValue(card.variable)
    let duration = (180.0 - current) / 180.0
    let transition = createTransition(library, duration, 180.0)
    try {
        storyboardAddTransition(storyboard, card.variable, transition)
        return storyboardAddKeyframeAfterTransition(storyboard, transition)
    } finally {
        releaseRaw(transition)
    }
}

// add_hide_transition: duration 1.0 to final_value, added at the keyframe.
func addHideTransition(
    library: CPointer<Unit>,
    storyboard: CPointer<Unit>,
    keyFrame: UI_ANIMATION_KEYFRAME,
    finalValue: Float64,
    card: Card
): Unit {
    let transition = createTransition(library, 1.0, finalValue)
    try {
        storyboardAddTransitionAtKeyframe(storyboard, card.variable, transition, keyFrame)
    } finally {
        releaseRaw(transition)
    }
}

// update_animation: device.CreateAnimation(); variable.GetCurve(animation);
// rotation.SetAngle(animation).
func updateAnimation(desktop: CPointer<Unit>, card: Card): Unit {
    let animation = createAnimation(desktop)
    try {
        variableGetCurve(card.variable, animation)
        rotateSetAngleAnimation(card.rotation, animation)
    } finally {
        releaseRaw(animation)
    }
}

// library.CreateAccelerateDecelerateTransition(duration, final, 0.2, 0.8).
func createTransition(library: CPointer<Unit>, duration: Float64, finalValue: Float64): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationTransitionLibrary2Vtbl>>(library).read().read()
        let hr = vtbl.CreateAccelerateDecelerateTransition(
            library,
            duration,
            finalValue,
            0.2,
            0.8,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// ===========================================================================
// IUIAnimationManager2 / Variable2 / Storyboard2 helpers.
// ===========================================================================
func managerUpdate(manager: CPointer<Unit>, timeNow: Float64): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationManager2Vtbl>>(manager).read().read()
        // Update(timeNow, updateResult=None).
        let hr = vtbl.Update(manager, timeNow, CPointer<Unit>())
        HRESULT(hr).check()
    }
}

// manager.CreateAnimationVariable(initial) -> owned IUIAnimationVariable2.
func managerCreateAnimationVariable(mgr: CPointer<Unit>, initial: Float64): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationManager2Vtbl>>(mgr).read().read()
        let hr = vtbl.CreateAnimationVariable(
            mgr,
            initial,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

func managerCreateStoryboard(manager: CPointer<Unit>): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationManager2Vtbl>>(manager).read().read()
        let hr = vtbl.CreateStoryboard(manager, CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw)))
        HRESULT(hr).check()
    }
    return outRaw
}

func variableGetValue(variable: CPointer<Unit>): Float64 {
    var value: Float64 = 0.0
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationVariable2Vtbl>>(variable).read().read()
        let hr = vtbl.GetValue(variable, CPointer<Unit>(CPointer<Float64>(inout value)))
        HRESULT(hr).check()
    }
    return value
}

func variableGetCurve(variable: CPointer<Unit>, animation: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationVariable2Vtbl>>(variable).read().read()
        let hr = vtbl.GetCurve(variable, animation)
        HRESULT(hr).check()
    }
}

func storyboardAddTransition(storyboard: CPointer<Unit>, variable: CPointer<Unit>, transition: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationStoryboard2Vtbl>>(storyboard).read().read()
        let hr = vtbl.AddTransition(storyboard, variable, transition)
        HRESULT(hr).check()
    }
}

func storyboardAddKeyframeAfterTransition(storyboard: CPointer<Unit>, transition: CPointer<Unit>): UI_ANIMATION_KEYFRAME {
    var keyFrame = UI_ANIMATION_KEYFRAME()
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationStoryboard2Vtbl>>(storyboard).read().read()
        let hr = vtbl.AddKeyframeAfterTransition(
            storyboard,
            transition,
            CPointer<Unit>(CPointer<UI_ANIMATION_KEYFRAME>(inout keyFrame))
        )
        HRESULT(hr).check()
    }
    return keyFrame
}

func storyboardAddTransitionAtKeyframe(
    storyboard: CPointer<Unit>,
    variable: CPointer<Unit>,
    transition: CPointer<Unit>,
    keyFrame: UI_ANIMATION_KEYFRAME
): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationStoryboard2Vtbl>>(storyboard).read().read()
        let hr = vtbl.AddTransitionAtKeyframe(storyboard, variable, transition, keyFrame)
        HRESULT(hr).check()
    }
}

func storyboardSchedule(storyboard: CPointer<Unit>, timeNow: Float64): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IUIAnimationStoryboard2Vtbl>>(storyboard).read().read()
        // Schedule(timeNow, schedulingResult=None).
        let hr = vtbl.Schedule(storyboard, timeNow, CPointer<Unit>())
        HRESULT(hr).check()
    }
}

// ===========================================================================
// Direct2D device-context helpers.
// ===========================================================================

// device2d.CreateDeviceContext(NONE) -> owned ID2D1DeviceContext.
func deviceCreateDeviceContext(device2d: CPointer<Unit>): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<ID2D1DeviceVtbl>>(device2d).read().read()
        let hr = vtbl.CreateDeviceContext(
            device2d,
            D2D1_DEVICE_CONTEXT_OPTIONS_NONE,
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// dc.CreateSolidColorBrush(black, None) -> owned ID2D1SolidColorBrush.
func createSolidColorBrush(dc: CPointer<Unit>): CPointer<Unit> {
    var color = D2D1_COLOR_F()
    color.r = 0.0
    color.g = 0.0
    color.b = 0.0
    color.a = 1.0
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(dc).read().read()
        let hr = vtbl.base_.CreateSolidColorBrush(
            dc,
            CPointer<Unit>(CPointer<D2D1_COLOR_F>(inout color)),
            CPointer<Unit>(),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// dc.CreateBitmapFromWicBitmap(image, None) -> owned ID2D1Bitmap1.
func createBitmapFromWicBitmap(dc: CPointer<Unit>, image: CPointer<Unit>): CPointer<Unit> {
    var outRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(dc).read().read()
        let hr = vtbl.CreateBitmapFromWicBitmap(
            dc,
            image,
            CPointer<Unit>(),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout outRaw))
        )
        HRESULT(hr).check()
    }
    return outRaw
}

// ===========================================================================
// Surface drawing. surface.BeginDraw(None, IID_ID2D1DeviceContext, &dc, &offset)
// returns a device context + the surface's atlas offset; draw; EndDraw.
// ===========================================================================
// Returns the device context plus the surface's atlas offset (x, y). A @C
// struct cannot be a tuple member, so the POINT's fields are returned directly.
func surfaceBeginDraw(surface: CPointer<Unit>): (CPointer<Unit>, Int32, Int32) {
    var dc = CPointer<Unit>()
    var offset = POINT()
    var iid = GUID.parse(IID_ID2D1DeviceContext())
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionSurfaceVtbl>>(surface).read().read()
        // BeginDraw(updateRect=None, iid, &updateObject, &updateOffset).
        let hr = vtbl.BeginDraw(
            surface,
            CPointer<Unit>(),
            CPointer<Unit>(CPointer<GUID>(inout iid)),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout dc)),
            CPointer<Unit>(CPointer<POINT>(inout offset))
        )
        HRESULT(hr).check()
    }
    return (dc, offset.x, offset.y)
}

func surfaceEndDraw(surface: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<IDCompositionSurfaceVtbl>>(surface).read().read()
        let hr = vtbl.EndDraw(surface)
        HRESULT(hr).check()
    }
}

// IID_ID2D1DeviceContext (canonical string form).
func IID_ID2D1DeviceContext(): String {
    return "e8f7fe7a-191c-466d-ad95-975678bda998"
}

// draw_card_front: clear white, draw the letter centred.
func drawCardFront(surface: CPointer<Unit>, value: UInt8, format: CPointer<Unit>, brush: CPointer<Unit>): Unit {
    let dpiX = currentDpiX()
    let dpiY = currentDpiY()
    let (dc, offsetX, offsetY) = surfaceBeginDraw(surface)
    try {
        // dc.SetDpi(dpiX, dpiY). SetDpi/SetTransform/Clear/DrawText live on the
        // ID2D1RenderTarget base == ID2D1DeviceContextVtbl.base_.
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(dc).read().read()
            vtbl.base_.SetDpi(dc, dpiX, dpiY)
        }

        // dc.SetTransform(translation(offset -> logical)).
        var transform = translationMatrix3x2(
            physicalToLogical(Float32(offsetX), dpiX),
            physicalToLogical(Float32(offsetY), dpiY)
        )
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(dc).read().read()
            vtbl.base_.SetTransform(dc, CPointer<Unit>(CPointer<Matrix3x2>(inout transform)))
        }

        // dc.Clear(white).
        var white = D2D1_COLOR_F()
        white.r = 1.0
        white.g = 1.0
        white.b = 1.0
        white.a = 1.0
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(dc).read().read()
            vtbl.base_.Clear(dc, CPointer<Unit>(CPointer<D2D1_COLOR_F>(inout white)))
        }

        // dc.DrawText(&[value], format, rect, brush, NONE, NATURAL). The text is
        // one UTF-16 code unit (the ASCII letter byte widened).
        var rect = D2D_RECT_F()
        rect.left = 0.0
        rect.top = 0.0
        rect.right = CARD_WIDTH
        rect.bottom = CARD_HEIGHT
        var text = Array<UInt16>(1, repeat: UInt16(value))
        let textHandle = unsafe { acquireArrayRawData(text) }
        try {
            unsafe {
                let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(dc).read().read()
                vtbl.base_.DrawText(
                    dc,
                    textHandle.pointer,
                    1,
                    format,
                    CPointer<Unit>(CPointer<D2D_RECT_F>(inout rect)),
                    brush,
                    D2D1_DRAW_TEXT_OPTIONS_NONE,
                    DWRITE_MEASURING_MODE_NATURAL
                )
            }
        } finally {
            unsafe { releaseArrayRawData(textHandle) }
        }
    } finally {
        releaseRaw(dc)
        surfaceEndDraw(surface)
    }
}

// draw_card_back: draw the slice of the background bitmap for this card.
func drawCardBack(surface: CPointer<Unit>, bitmap: CPointer<Unit>, offsetX: Float32, offsetY: Float32): Unit {
    let dpiX = currentDpiX()
    let dpiY = currentDpiY()
    let (dc, dcOffsetX, dcOffsetY) = surfaceBeginDraw(surface)
    try {
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(dc).read().read()
            vtbl.base_.SetDpi(dc, dpiX, dpiY)
        }

        var transform = translationMatrix3x2(
            physicalToLogical(Float32(dcOffsetX), dpiX),
            physicalToLogical(Float32(dcOffsetY), dpiY)
        )
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(dc).read().read()
            vtbl.base_.SetTransform(dc, CPointer<Unit>(CPointer<Matrix3x2>(inout transform)))
        }

        let left = physicalToLogical(offsetX, dpiX)
        let top = physicalToLogical(offsetY, dpiY)
        var rect = D2D_RECT_F()
        rect.left = left
        rect.top = top
        rect.right = left + CARD_WIDTH
        rect.bottom = top + CARD_HEIGHT

        // dc.DrawBitmap(bitmap, dest=None, opacity=1.0, LINEAR, src=Some(rect),
        // perspective=None). The 7-arg DrawBitmap lives on ID2D1DeviceContext.
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(dc).read().read()
            vtbl.DrawBitmap(
                dc,
                bitmap,
                CPointer<Unit>(),
                1.0,
                D2D1_INTERPOLATION_MODE_LINEAR,
                CPointer<Unit>(CPointer<D2D_RECT_F>(inout rect)),
                CPointer<Unit>()
            )
        }
    } finally {
        releaseRaw(dc)
        surfaceEndDraw(surface)
    }
}

// device.GetDeviceRemovedReason() — on ID3D11Device (directly under IUnknown).
func getDeviceRemovedReason(device: CPointer<Unit>): Unit {
    unsafe {
        let vtbl = CPointer<CPointer<ID3D11DeviceVtbl>>(device).read().read()
        let hr = vtbl.GetDeviceRemovedReason(device)
        HRESULT(hr).check()
    }
}

// ===========================================================================
// The single window, held globally so the @C wndproc can reach it (the GC-safe
// analogue of the reference's GWLP_USERDATA self pointer).
// ===========================================================================
var gWindow: ?Window = None

func currentDpiX(): Float32 {
    match (gWindow) {
        case Some(w) => w.dpiX
        case None => 96.0
    }
}

func currentDpiY(): Float32 {
    match (gWindow) {
        case Some(w) => w.dpiY
        case None => 96.0
    }
}

// MonitorFromWindow wrapper (exposed under the Gdi Apis facade).
func WndApis_MonitorFromWindow(hwnd: HWND, flags: UInt32): HMONITOR {
    return unsafe { GdiApis.MonitorFromWindow(hwnd, flags) }
}

// WNDPROC. Must match CFunc<(HWND, UInt32, UIntNative, IntNative) -> IntNative>.
@C
func wndproc(window: HWND, message: UInt32, wparam: UIntNative, lparam: IntNative): IntNative {
    match (gWindow) {
        case Some(w) =>
            if (w.handle.Value.isNull()) {
                w.handle = window
            }
            return w.messageHandler(message, wparam, lparam)
        case None =>
            return unsafe { WndApis.DefWindowProcA(window, message, wparam, lparam) }
    }
}

main(): Int64 {
    unsafe {
        let hr = ComApis.CoInitializeEx(CPointer<Unit>(), COINIT_MULTITHREADED)
        HRESULT(hr).check()
        var ctx = DPI_AWARENESS_CONTEXT()
        ctx.Value = handlePointerFromInt(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2_VALUE)
        let _ = HiDpiApis.SetProcessDpiAwarenessContext(ctx)
    }

    let window = Window()
    gWindow = Some(window)
    window.run()
    return 0
}
