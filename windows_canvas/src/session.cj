package windows_canvas

import windows_numerics.{Vector2, Matrix3x2}
import windows_canvas_bindings.Foundation.Numerics.Vector2 as ProjectedVector2

import windows_canvas_bindings.Win32.Graphics.Direct2D.{
    ID2D1DeviceContext,
    ID2D1DeviceContextVtbl,
    D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES,
    D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES,
    D2D1_ELLIPSE,
    D2D1_ROUNDED_RECT,
    ID2D1SolidColorBrush,
    ID2D1LinearGradientBrush,
    ID2D1RadialGradientBrush,
    ID2D1GradientStopCollection
}
import windows_canvas_bindings.Win32.Graphics.Direct2D.Common.{D2D1_COLOR_F, D2D1_GRADIENT_STOP, D2D_RECT_F}

import windows_core.HRESULT
import windows_strings.{encodeUtf16Units}

// --- D2D draw / gradient scalar constants (not surfaced by the facade) ---
const D2D1_GAMMA_2_2: Int32 = 0
const D2D1_EXTEND_MODE_CLAMP: Int32 = 0
const D2D1_DRAW_TEXT_OPTIONS_NONE: Int32 = 0
const DWRITE_MEASURING_MODE_NATURAL: Int32 = 0
const D2D1_INTERPOLATION_MODE_LINEAR: Int32 = 1

// Create a solid color brush bound to the given raw device context. Shared by
// `SwapChain.createSolidBrush` and `DrawingSession.createSolidBrush`.
func createSolidBrushOn(contextRaw: CPointer<Unit>, color: ColorF): Brush {
    var c = color.toAbi()
    var brushRaw = CPointer<Unit>()
    unsafe {
        let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(contextRaw).read().read()
        // CreateSolidColorBrush lives on ID2D1RenderTarget (the context base).
        let hr = vtbl.base_.CreateSolidColorBrush(
            contextRaw,
            CPointer<Unit>(CPointer<D2D1_COLOR_F>(inout c)),
            CPointer<Unit>(),
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout brushRaw))
        )
        HRESULT(hr).check()
    }
    return Brush(ID2D1SolidColorBrush(brushRaw, takeOwnership: true))
}

// Safe wrapper over `ID2D1DeviceContext`.
//
// Calls `BeginDraw` on creation and `EndDraw` on `close`.
//
// Cangjie paradigm note (equivalent): the reference is an RAII guard whose
// `Drop` runs `EndDraw` (setting the device-lost flag on a device-lost code).
// Cangjie has no destructor scoping for borrows, so this is a `Resource` whose
// `close()` (and `~init` finalizer as a safety net) calls `EndDraw` exactly
// once, guarded by a `closed` flag to avoid a double EndDraw. The device-lost
// flag is the same shared object the SwapChain reads after present.
public class DrawingSession <: Resource {
    let context: ID2D1DeviceContext
    let deviceLostFlag: DeviceLostFlag
    var closed: Bool = false

    init(context: ID2D1DeviceContext, deviceLostFlag: DeviceLostFlag) {
        this.context = context
        this.deviceLostFlag = deviceLostFlag
        let raw = context.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.BeginDraw(raw)
        }
    }

    private func contextRaw(): CPointer<Unit> {
        return this.context.asRaw()
    }

    // Clear the render target to the specified color.
    public func clear(color: ColorF): Unit {
        var c = color.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.Clear(raw, CPointer<Unit>(CPointer<D2D1_COLOR_F>(inout c)))
        }
    }

    // Draw a line between two points.
    public func drawLine(p0: Vector2, p1: Vector2, brush: Paint, width: Float32): Unit {
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawLine(raw, toProjectedVector2(p0), toProjectedVector2(p1), brush.asRawBrush(), width, CPointer<Unit>())
        }
    }

    // Draw a line with a stroke style.
    public func drawLineStyled(p0: Vector2, p1: Vector2, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawLine(raw, toProjectedVector2(p0), toProjectedVector2(p1), brush.asRawBrush(), width, style.asRaw())
        }
    }

    // Draw a rectangle outline.
    public func drawRect(rect: Rect, brush: Paint, width: Float32): Unit {
        var r = rect.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawRectangle(
                raw,
                CPointer<Unit>(CPointer<D2D_RECT_F>(inout r)),
                brush.asRawBrush(),
                width,
                CPointer<Unit>()
            )
        }
    }

    // Draw a rectangle outline with a stroke style.
    public func drawRectStyled(rect: Rect, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        var r = rect.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawRectangle(
                raw,
                CPointer<Unit>(CPointer<D2D_RECT_F>(inout r)),
                brush.asRawBrush(),
                width,
                style.asRaw()
            )
        }
    }

    // Fill a rectangle.
    public func fillRect(rect: Rect, brush: Paint): Unit {
        var r = rect.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.FillRectangle(
                raw,
                CPointer<Unit>(CPointer<D2D_RECT_F>(inout r)),
                brush.asRawBrush()
            )
        }
    }

    // Draw a rounded rectangle outline.
    public func drawRoundedRect(rect: RoundedRect, brush: Paint, width: Float32): Unit {
        var rr = rect.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawRoundedRectangle(
                raw,
                CPointer<Unit>(CPointer<D2D1_ROUNDED_RECT>(inout rr)),
                brush.asRawBrush(),
                width,
                CPointer<Unit>()
            )
        }
    }

    // Draw a rounded rectangle outline with a stroke style.
    public func drawRoundedRectStyled(rect: RoundedRect, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        var rr = rect.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawRoundedRectangle(
                raw,
                CPointer<Unit>(CPointer<D2D1_ROUNDED_RECT>(inout rr)),
                brush.asRawBrush(),
                width,
                style.asRaw()
            )
        }
    }

    // Fill a rounded rectangle.
    public func fillRoundedRect(rect: RoundedRect, brush: Paint): Unit {
        var rr = rect.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.FillRoundedRectangle(
                raw,
                CPointer<Unit>(CPointer<D2D1_ROUNDED_RECT>(inout rr)),
                brush.asRawBrush()
            )
        }
    }

    // Draw an ellipse outline.
    public func drawEllipse(ellipse: Ellipse, brush: Paint, width: Float32): Unit {
        var e = ellipse.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawEllipse(
                raw,
                CPointer<Unit>(CPointer<D2D1_ELLIPSE>(inout e)),
                brush.asRawBrush(),
                width,
                CPointer<Unit>()
            )
        }
    }

    // Draw an ellipse outline with a stroke style.
    public func drawEllipseStyled(ellipse: Ellipse, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        var e = ellipse.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawEllipse(
                raw,
                CPointer<Unit>(CPointer<D2D1_ELLIPSE>(inout e)),
                brush.asRawBrush(),
                width,
                style.asRaw()
            )
        }
    }

    // Fill an ellipse.
    public func fillEllipse(ellipse: Ellipse, brush: Paint): Unit {
        var e = ellipse.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.FillEllipse(
                raw,
                CPointer<Unit>(CPointer<D2D1_ELLIPSE>(inout e)),
                brush.asRawBrush()
            )
        }
    }

    // Create a solid color brush bound to this session's device context.
    public func createSolidBrush(color: ColorF): Brush {
        return createSolidBrushOn(this.contextRaw(), color)
    }

    // Create a linear gradient brush.
    //
    // `start` and `end` define the gradient axis in local coordinates. `stops`
    // defines colors at positions 0.0-1.0 along the axis.
    public func createLinearGradient(start: Vector2, end: Vector2, stops: Array<GradientStop>): LinearGradient {
        let collection = this.createGradientStopCollection(stops)
        var props = D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES()
        props.startPoint = toProjectedVector2(start)
        props.endPoint = toProjectedVector2(end)
        let raw = this.contextRaw()
        var brushRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            let hr = vtbl.base_.CreateLinearGradientBrush(
                raw,
                CPointer<Unit>(CPointer<D2D1_LINEAR_GRADIENT_BRUSH_PROPERTIES>(inout props)),
                CPointer<Unit>(),
                collection.asRaw(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout brushRaw))
            )
            HRESULT(hr).check()
        }
        collection.close()
        return LinearGradient(ID2D1LinearGradientBrush(brushRaw, takeOwnership: true))
    }

    // Create a radial gradient brush.
    //
    // `center` is the gradient center. `radiusX`/`radiusY` define the ellipse.
    // `stops` defines colors at positions 0.0 (center) to 1.0 (edge).
    public func createRadialGradient(center: Vector2, radiusX: Float32, radiusY: Float32, stops: Array<GradientStop>): RadialGradient {
        let collection = this.createGradientStopCollection(stops)
        var props = D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES()
        props.center = toProjectedVector2(center)
        var zero = ProjectedVector2()
        zero.X = 0.0
        zero.Y = 0.0
        props.gradientOriginOffset = zero
        props.radiusX = radiusX
        props.radiusY = radiusY
        let raw = this.contextRaw()
        var brushRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            let hr = vtbl.base_.CreateRadialGradientBrush(
                raw,
                CPointer<Unit>(CPointer<D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES>(inout props)),
                CPointer<Unit>(),
                collection.asRaw(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout brushRaw))
            )
            HRESULT(hr).check()
        }
        collection.close()
        return RadialGradient(ID2D1RadialGradientBrush(brushRaw, takeOwnership: true))
    }

    private func createGradientStopCollection(stops: Array<GradientStop>): ID2D1GradientStopCollection {
        var abiStops = Array<D2D1_GRADIENT_STOP>(stops.size, repeat: D2D1_GRADIENT_STOP())
        for (i in 0..stops.size) {
            abiStops[i] = stops[i].toAbi()
        }
        let stopsHandle = unsafe { acquireArrayRawData(abiStops) }
        let raw = this.contextRaw()
        var collectionRaw = CPointer<Unit>()
        try {
            unsafe {
                let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
                // CreateGradientStopCollection(stops, count, GAMMA_2_2, CLAMP, &out)
                // on ID2D1RenderTarget (the context base).
                let hr = vtbl.base_.CreateGradientStopCollection(
                    raw,
                    CPointer<Unit>(stopsHandle.pointer),
                    UInt32(stops.size),
                    D2D1_GAMMA_2_2,
                    D2D1_EXTEND_MODE_CLAMP,
                    CPointer<Unit>(CPointer<CPointer<Unit>>(inout collectionRaw))
                )
                HRESULT(hr).check()
            }
        } finally {
            unsafe { releaseArrayRawData(stopsHandle) }
        }
        return ID2D1GradientStopCollection(collectionRaw, takeOwnership: true)
    }

    // Draw text within a layout rectangle.
    public func drawText(text: String, format: TextFormat, rect: Rect, brush: Paint): Unit {
        var wide = encodeUtf16Units(text)
        var r = rect.toAbi()
        let raw = this.contextRaw()
        let textHandle = unsafe { acquireArrayRawData(wide) }
        try {
            unsafe {
                let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
                vtbl.base_.DrawText(
                    raw,
                    textHandle.pointer,
                    UInt32(wide.size),
                    format.asRaw(),
                    CPointer<Unit>(CPointer<D2D_RECT_F>(inout r)),
                    brush.asRawBrush(),
                    D2D1_DRAW_TEXT_OPTIONS_NONE,
                    DWRITE_MEASURING_MODE_NATURAL
                )
            }
        } finally {
            unsafe { releaseArrayRawData(textHandle) }
        }
    }

    // Draw a path geometry outline.
    public func drawPath(path: Path, brush: Paint, width: Float32): Unit {
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawGeometry(raw, path.asRaw(), brush.asRawBrush(), width, CPointer<Unit>())
        }
    }

    // Draw a path geometry outline with a stroke style.
    public func drawPathStyled(path: Path, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.DrawGeometry(raw, path.asRaw(), brush.asRawBrush(), width, style.asRaw())
        }
    }

    // Fill a path geometry.
    public func fillPath(path: Path, brush: Paint): Unit {
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.FillGeometry(raw, path.asRaw(), brush.asRawBrush(), CPointer<Unit>())
        }
    }

    // Draw a bitmap at the specified destination rectangle.
    //
    // The bitmap is scaled to fill `dest`. Use `opacity` (0.0-1.0) to blend.
    public func drawBitmap(bitmap: Bitmap, dest: Rect, opacity: Float32): Unit {
        var r = dest.toAbi()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            // DrawBitmap lives on ID2D1RenderTarget (sourceRect=None,
            // perspectiveTransform omitted on the base overload).
            vtbl.base_.DrawBitmap(
                raw,
                bitmap.asRaw(),
                CPointer<Unit>(CPointer<D2D_RECT_F>(inout r)),
                opacity,
                D2D1_INTERPOLATION_MODE_LINEAR,
                CPointer<Unit>()
            )
        }
    }

    // Load a bitmap from an image file (PNG, JPEG, BMP, etc.).
    public func loadBitmap(path: String): Bitmap {
        return Bitmap.loadFromFile(this.contextRaw(), path)
    }

    // Set the current transform matrix.
    public func setTransform(transform: Matrix3x2): Unit {
        var t = transform
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.SetTransform(raw, CPointer<Unit>(CPointer<Matrix3x2>(inout t)))
        }
    }

    // Get the current transform matrix.
    public func getTransform(): Matrix3x2 {
        var t = Matrix3x2()
        let raw = this.contextRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            vtbl.base_.GetTransform(raw, CPointer<Unit>(CPointer<Matrix3x2>(inout t)))
        }
        return t
    }

    // Execute a closure with a temporary transform, then restore the previous one.
    public func withTransform(transform: Matrix3x2, f: () -> Unit): Unit {
        let prev = this.getTransform()
        this.setTransform(transform)
        f()
        this.setTransform(prev)
    }

    // Access the raw D2D1 device context for advanced usage.
    public func raw(): CPointer<Unit> {
        return this.contextRaw()
    }

    public func isClosed(): Bool {
        return this.closed
    }

    // End the drawing session. Calls EndDraw exactly once; if EndDraw reports a
    // device-lost code, the shared flag is set so the SwapChain skips present.
    public func close(): Unit {
        if (this.closed) {
            return
        }
        this.closed = true
        let raw = this.context.asRaw()
        let hr = unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
            // EndDraw(tag1=None, tag2=None).
            HRESULT(vtbl.base_.EndDraw(raw, CPointer<Unit>(), CPointer<Unit>()))
        }
        if (hr.isErr() && isDeviceLost(hr)) {
            this.deviceLostFlag.lost = true
        }
    }

    // Finalizer safety net mirroring the reference's RAII Drop: if the caller
    // never closed the session, EndDraw still runs exactly once. The finalizer
    // may not invoke `this`'s own instance methods, so the EndDraw sequence is
    // inlined here (it does the same work as `close()`).
    ~init() {
        if (!this.closed) {
            this.closed = true
            let raw = this.context.asRaw()
            let hr = unsafe {
                let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(raw).read().read()
                HRESULT(vtbl.base_.EndDraw(raw, CPointer<Unit>(), CPointer<Unit>()))
            }
            if (hr.isErr() && isDeviceLost(hr)) {
                this.deviceLostFlag.lost = true
            }
        }
    }
}
