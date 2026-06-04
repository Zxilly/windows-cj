package windows_canvas

import windows_reactor.core.{SwapChainPanelWidget, NativeElement, swap_chain_panel}
import windows_reactor.winui.{SwapChainPanelHandle, EventRevoker, swapChainPanelHandle}

import windows_numerics.{Matrix3x2, Vector2}

// ============================================================================
// reactor integration — GPU 2D drawing hosted inside the declarative reactor
// UI. Mirrors the reference reactor.rs (DrawContext + animated_canvas).
//
// Cangjie paradigm notes (behaviour-equivalent, not API-literal):
//   * The reference DrawContext is a borrowed view (`DrawContext<'a>`) that
//     `Deref`s to the DrawingSession so `ctx.fill_ellipse(..)` works directly.
//     Cangjie has no Deref; DrawContext is a small class holding the live
//     session + device + DIP size, and forwards each draw call to the session
//     (same observable D2D effect). The forwarders cover the full DrawingSession
//     surface so user draw code reads the same as the reference.
//   * The reference holds mutable render state behind Rc<RefCell<..>> / Rc<Cell>
//     to share it between the on_ready / on_rendering / on_resize closures. Here
//     that mutable state lives inside GC-managed classes (RenderState +
//     RenderStateHolder + SizeCell + ScaleCell); the closures capture the `let`
//     instance reference and mutate its `var` fields, which is exactly what
//     Cangjie permits (a captured `var` LOCAL cannot escape into a stored
//     closure, but a captured class reference can, and its fields stay mutable).
//   * The per-frame Rendering subscription and the composition-scale-changed
//     subscription are EventRevoker values (phase B). They MUST stay rooted for
//     as long as callbacks are wanted — the delegate behind each is a CCW, so a
//     dropped revoker would both stop the callbacks and risk a use-after-free.
//     RenderState holds them in fields so they live exactly as long as the
//     mounted panel's render state does (the reference keeps them in `_rendering`
//     / `_scale_revoker` fields of its RenderState for the same reason).
//
// THREAD MODEL: single-threaded, on the UI thread. CompositionTarget.Rendering
// fires once per composed frame on the UI thread; the draw callback, present and
// resize all run there. This matches the reference (which also drives the loop
// from the UI-thread Rendering event — no worker thread).
//
// ABI-BUG NOTE: none of the COM calls reached here return an aggregate by value,
// so the sret/RAX miscompilation in web/book/src/aggregate-return-abi-bug.md
// does not apply. DIP sizes come from the panel's ActualWidth/ActualHeight
// scalar getters (already handled inside SwapChainPanelHandle.onResize) and the
// composition scale from the scalar get_CompositionScaleX/Y out-param getters;
// bitmap pixel sizes come from the cached Bitmap.width()/height().
// ============================================================================

// Per-frame draw context handed to the user's draw closure.
//
// Holds the live DrawingSession for this frame plus the GpuDevice (for creating
// paths / stroke styles) and the render-target size in DIPs (resolution
// independent: the swap chain is sized in pixels, but draw code works in DIPs).
public class DrawContext {
    private let session: DrawingSession
    private let deviceValue: GpuDevice
    // Width of the render target in DIPs.
    public let width: Float32
    // Height of the render target in DIPs.
    public let height: Float32

    init(session: DrawingSession, device: GpuDevice, width: Float32, height: Float32) {
        this.session = session
        this.deviceValue = device
        this.width = width
        this.height = height
    }

    // Access the GPU device (for creating paths, stroke styles, etc.).
    public func device(): GpuDevice {
        return this.deviceValue
    }

    // Access the underlying DrawingSession for any call not forwarded below.
    public func drawingSession(): DrawingSession {
        return this.session
    }

    // ── Forwarded DrawingSession surface (the reference reaches these through
    //    Deref; here each is a thin forwarder with identical behaviour) ──────

    public func clear(color: ColorF): Unit {
        this.session.clear(color)
    }

    public func createSolidBrush(color: ColorF): Brush {
        return this.session.createSolidBrush(color)
    }

    public func createLinearGradient(start: Vector2, end: Vector2, stops: Array<GradientStop>): LinearGradient {
        return this.session.createLinearGradient(start, end, stops)
    }

    public func createRadialGradient(center: Vector2, radiusX: Float32, radiusY: Float32, stops: Array<GradientStop>): RadialGradient {
        return this.session.createRadialGradient(center, radiusX, radiusY, stops)
    }

    public func drawLine(p0: Vector2, p1: Vector2, brush: Paint, width: Float32): Unit {
        this.session.drawLine(p0, p1, brush, width)
    }

    public func drawLineStyled(p0: Vector2, p1: Vector2, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        this.session.drawLineStyled(p0, p1, brush, width, style)
    }

    public func drawRect(rect: Rect, brush: Paint, width: Float32): Unit {
        this.session.drawRect(rect, brush, width)
    }

    public func drawRectStyled(rect: Rect, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        this.session.drawRectStyled(rect, brush, width, style)
    }

    public func fillRect(rect: Rect, brush: Paint): Unit {
        this.session.fillRect(rect, brush)
    }

    public func drawRoundedRect(rect: RoundedRect, brush: Paint, width: Float32): Unit {
        this.session.drawRoundedRect(rect, brush, width)
    }

    public func drawRoundedRectStyled(rect: RoundedRect, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        this.session.drawRoundedRectStyled(rect, brush, width, style)
    }

    public func fillRoundedRect(rect: RoundedRect, brush: Paint): Unit {
        this.session.fillRoundedRect(rect, brush)
    }

    public func drawEllipse(ellipse: Ellipse, brush: Paint, width: Float32): Unit {
        this.session.drawEllipse(ellipse, brush, width)
    }

    public func drawEllipseStyled(ellipse: Ellipse, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        this.session.drawEllipseStyled(ellipse, brush, width, style)
    }

    public func fillEllipse(ellipse: Ellipse, brush: Paint): Unit {
        this.session.fillEllipse(ellipse, brush)
    }

    public func drawText(text: String, format: TextFormat, rect: Rect, brush: Paint): Unit {
        this.session.drawText(text, format, rect, brush)
    }

    public func drawPath(path: Path, brush: Paint, width: Float32): Unit {
        this.session.drawPath(path, brush, width)
    }

    public func drawPathStyled(path: Path, brush: Paint, width: Float32, style: StrokeStyle): Unit {
        this.session.drawPathStyled(path, brush, width, style)
    }

    public func fillPath(path: Path, brush: Paint): Unit {
        this.session.fillPath(path, brush)
    }

    public func drawBitmap(bitmap: Bitmap, dest: Rect, opacity: Float32): Unit {
        this.session.drawBitmap(bitmap, dest, opacity)
    }

    public func loadBitmap(path: String): Bitmap {
        return this.session.loadBitmap(path)
    }

    public func setTransform(transform: Matrix3x2): Unit {
        this.session.setTransform(transform)
    }

    public func getTransform(): Matrix3x2 {
        return this.session.getTransform()
    }

    public func withTransform(transform: Matrix3x2, f: () -> Unit): Unit {
        this.session.withTransform(transform, f)
    }
}

// Shared mutable cell for the panel's current size in DIPs (the reference's
// Rc<Cell<(f32, f32)>>). A GC class so on_ready / on_rendering / on_resize all
// see the same live value through their captured `let` reference.
class SizeCell {
    var width: Float32 = 0.0
    var height: Float32 = 0.0
}

// Shared mutable cell for the current composition (DPI) scale (Rc<Cell<f32>>).
class ScaleCell {
    var value: Float32 = 1.0
}

// Live per-mount render state: the GPU device, the composition swap chain, the
// panel interop handle, the current scale, and the rooted event subscriptions.
// Mirrors the reference RenderState. Its fields are mutable so device-lost
// rebuilds and scale changes can swap the device / chain in place.
class RenderState {
    var device: GpuDevice
    var chain: SwapChain
    let panel: SwapChainPanelHandle
    var scale: Float32
    // Rooted so per-frame / scale-changed / resize callbacks keep firing and
    // their CCW delegates stay alive (closed when this state is dropped — i.e. at
    // unmount, when the holder is cleared and GC finalizes the revokers).
    let rendering: EventRevoker
    let scaleRevoker: ?EventRevoker
    let resizeRevoker: ?EventRevoker

    init(
        device: GpuDevice,
        chain: SwapChain,
        panel: SwapChainPanelHandle,
        scale: Float32,
        rendering: EventRevoker,
        scaleRevoker: ?EventRevoker,
        resizeRevoker: ?EventRevoker
    ) {
        this.device = device
        this.chain = chain
        this.panel = panel
        this.scale = scale
        this.rendering = rendering
        this.scaleRevoker = scaleRevoker
        this.resizeRevoker = resizeRevoker
    }

    // Recreate the device + swap chain after device loss and re-bind the panel.
    // Returns true on success; on any failure the previous (lost) device/chain
    // are left in place and false is returned (the next frame retries). Mirrors
    // the reference RenderState::rebuild.
    func rebuild(pixelWidth: UInt32, pixelHeight: UInt32): Bool {
        try {
            let newDevice = GpuDevice.create()
            let newChain = newDevice.createSwapChain(pixelWidth, pixelHeight)
            let dpi = 96.0f32 * this.scale
            newChain.setDpi(dpi, dpi)
            newChain.setCompositionScale(this.scale, this.scale)
            this.panel.setSwapChain(newChain.rawSwapChain())
            this.device = newDevice
            this.chain = newChain
            return true
        } catch (_: Exception) {
            return false
        }
    }
}

// Heap slot for the Option<RenderState> the closures share (the reference's
// Rc<RefCell<Option<RenderState>>>). on_ready fills it; the per-frame / resize /
// scale-changed callbacks read + mutate it.
class RenderStateHolder {
    var value: ?RenderState = None
}

// Clamp a DIP dimension scaled to pixels to at least 1 (the reference's
// `((w * s) as u32).max(1)`).
func toPixelDim(dip: Float32, scale: Float32): UInt32 {
    let scaled = dip * scale
    if (scaled < 1.0) {
        return 1
    }
    return UInt32(scaled)
}

// Create an animated canvas widget that calls `draw` every frame.
//
// Handles device creation, swap chain management, resize, and the per-frame
// rendering loop automatically. If the GPU device is lost (driver update,
// sleep/wake, etc.), the widget silently recreates the device and resumes.
//
// The swap chain is created at the display's native pixel resolution for crisp
// rendering; the DrawContext reports dimensions in DIPs so draw code stays
// resolution independent.
//
// Usage (mirrors the reference animated_canvas):
//
//   animatedCanvas({ ctx: DrawContext =>
//       ctx.clear(ColorF.cornflowerBlue())
//       ctx.fillEllipse(ellipse, brush)
//   }).margin(Thickness.uniform(16.0))
//
// Returns the SwapChainPanelWidget so the caller can chain layout modifiers
// (.margin / .gridRow / ...) and lower it with .toElement().
public func animatedCanvas(draw: (DrawContext) -> Unit): SwapChainPanelWidget {
    // Shared mutable state, mirroring the reference's three Rc cells.
    let holder = RenderStateHolder()
    let size = SizeCell()
    let scaleCell = ScaleCell()

    // The reference wires on_resize at the WIDGET level; here the layout-size
    // subscription is a SwapChainPanelHandle method (phase B), so it is wired
    // inside onReady once the live handle exists (see onCanvasReady). Behaviour
    // is equivalent: size changes still resize the swap chain buffers.
    return swap_chain_panel()
        .onReady({ native: NativeElement =>
            onCanvasReady(native, draw, holder, size, scaleCell)
        })
}

// The on_ready body, lifted out of animatedCanvas so the captured-state types
// stay obvious. Builds the device + composition swap chain, binds it to the
// panel, wires the scale-changed + per-frame Rendering subscriptions, and stores
// the resulting RenderState. Any failure leaves the holder empty (no canvas
// renders), exactly like the reference's early `return` on Err.
func onCanvasReady(
    native: NativeElement,
    draw: (DrawContext) -> Unit,
    holder: RenderStateHolder,
    size: SizeCell,
    scaleCell: ScaleCell
): Unit {
    let panel = swapChainPanelHandle(native)

    // Composition scale is known once the panel has had its first layout; before
    // that compositionScale() answers (1.0, 1.0). Use the X scale (square pixels).
    let (sx, _) = panel.compositionScale()
    let s = sx
    scaleCell.value = s

    let pw = toPixelDim(size.width, s)
    let ph = toPixelDim(size.height, s)

    let device: GpuDevice
    let chain: SwapChain
    try {
        device = GpuDevice.create()
        chain = device.createSwapChain(pw, ph)
        let dpi = 96.0f32 * s
        chain.setDpi(dpi, dpi)
        chain.setCompositionScale(s, s)
        panel.setSwapChain(chain.rawSwapChain())
    } catch (_: Exception) {
        return
    }

    // Listen for composition-scale changes (window moved to a different-DPI
    // monitor). Resize + re-DPI the live chain to keep pixels crisp. Mirrors the
    // reference on_composition_scale_changed body.
    var scaleRevoker: ?EventRevoker = None
    try {
        let revoker = panel.onCompositionScaleChanged({ newS: Float32, _: Float32 =>
            scaleCell.value = newS
            let npw = toPixelDim(size.width, newS)
            let nph = toPixelDim(size.height, newS)
            match (holder.value) {
                case Some(rs) =>
                    rs.scale = newS
                    rs.chain.resize(npw, nph)
                    let ndpi = 96.0f32 * newS
                    rs.chain.setDpi(ndpi, ndpi)
                    rs.chain.setCompositionScale(newS, newS)
                case None => ()
            }
        })
        scaleRevoker = Some(revoker)
    } catch (_: Exception) {
        scaleRevoker = None
    }

    // Listen for layout-size changes (the reference's widget-level on_resize).
    // SwapChainPanelHandle.onResize fires with the panel's new ActualWidth /
    // ActualHeight in DIPs (scalar getters — no aggregate-return ABI hazard);
    // update the shared size and resize the live chain's buffers. The first
    // layout pass after mount also fires this, which is what brings the chain up
    // to the real client size when onReady ran before layout (size still 0).
    var resizeRevoker: ?EventRevoker = None
    try {
        let revoker = panel.onResize({ w: Float64, h: Float64 =>
            size.width = Float32(w)
            size.height = Float32(h)
            let cur = scaleCell.value
            let rpw = toPixelDim(size.width, cur)
            let rph = toPixelDim(size.height, cur)
            match (holder.value) {
                case Some(rs) => rs.chain.resize(rpw, rph)
                case None => ()
            }
        })
        resizeRevoker = Some(revoker)
    } catch (_: Exception) {
        resizeRevoker = None
    }

    // Per-frame draw loop on CompositionTarget.Rendering. Reads the live
    // RenderState out of the shared holder each frame, opens a session, runs the
    // user draw callback, then presents — recreating the device on device-lost.
    let rendering: EventRevoker
    try {
        rendering = panel.onRendering({ =>
            renderFrame(draw, holder, size)
        })
    } catch (_: Exception) {
        // No Rendering subscription -> the canvas would never paint; bail (the
        // device/chain GC away since we never store them).
        return
    }

    holder.value = Some(RenderState(device, chain, panel, s, rendering, scaleRevoker, resizeRevoker))
}

// One frame: skip when not yet sized; otherwise begin a session, run the user
// draw, close the session (EndDraw), then present. On a device-lost present,
// rebuild the device/chain at the current pixel size. Mirrors the reference
// on_rendering closure.
func renderFrame(draw: (DrawContext) -> Unit, holder: RenderStateHolder, size: SizeCell): Unit {
    match (holder.value) {
        case Some(rs) =>
            let w = size.width
            let h = size.height
            if (w <= 0.0 || h <= 0.0) {
                return
            }
            // begin_draw -> draw -> end_draw -> present. A draw-time COM failure
            // would throw; swallow it so a single bad frame never tears down the
            // loop (the reference's begin_draw returns Err and the closure just
            // returns for that frame).
            let session = try {
                rs.chain.beginDraw()
            } catch (_: Exception) {
                return
            }
            try {
                let ctx = DrawContext(session, rs.device, w, h)
                draw(ctx)
            } catch (_: Exception) {
                ()
            } finally {
                // EndDraw must always run (it also latches device-lost into the
                // shared flag that present() reads). Mirrors dropping the
                // DrawContext/session at end of the reference closure.
                session.close()
            }

            let ok = try {
                rs.chain.present()
            } catch (_: Exception) {
                // A non-device-lost present failure: skip this frame.
                true
            }
            if (!ok) {
                // Device lost: rebuild at the current pixel size and resume next
                // frame.
                let pw = toPixelDim(w, rs.scale)
                let ph = toPixelDim(h, rs.scale)
                let _ = rs.rebuild(pw, ph)
            }
        case None => ()
    }
}
