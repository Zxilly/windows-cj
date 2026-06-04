package windows_canvas

// Integration tests for windows_canvas, ported 1:1 from the reference canvas
// test suite. These tests create real D3D11/D2D devices via WARP (the software
// rasterizer) so they run headless with no GPU or display, and exercise the
// core public API surface: device creation, swap chains, drawing sessions, the
// drawing primitives, gradients, paths, text, bitmap loading and device-lost
// reporting.
//
// Naming note: the file ends in `_test.cj` so cjpm compiles it in test mode and
// the @When[test] fixtures below are retained. The reference's `drop(session)`
// (which runs EndDraw via the RAII guard) is spelled here as `session.close()`,
// the documented deterministic Resource-release path, because EndDraw must run
// before `present()`.

import std.unittest.*
import std.unittest.testmacro.*
import std.env.{getWorkingDirectory}
import std.fs.{File, Path, removeIfExists}
import windows_numerics.{vector2, matrix3x2, Vector2, Matrix3x2}
import windows_canvas_bindings.Win32.System.Com.Apis as ComApis

// --- COM initialization (ensure_com_initialized) ----------------------------
//
// The reference calls `CoIncrementMTAUsage` to put the process into the MTA so
// the WIC and Direct2D apartment-aware objects behave. The bindings surface the
// same combase/ole32 export, so this is a behaviour-equivalent setup.
func ensureComInitialized(): Unit {
    var cookie = CPointer<Unit>()
    unsafe {
        let _ = ComApis.CoIncrementMTAUsage(
            CPointer<Unit>(CPointer<CPointer<Unit>>(inout cookie))
        )
    }
}

// --- test.png fixture -------------------------------------------------------
//
// The reference loads `$CARGO_MANIFEST_DIR/test.png`. Cangjie has no such
// build-time path, so the exact same 2x2 PNG (the reference's `test.png`, byte
// for byte) is embedded below and materialized in the process working directory
// at test time. `load_bitmap` is then given the absolute path. This removes any
// dependency on where the test binary is launched from.
let TEST_PNG_BYTES: Array<UInt8> = [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 2,
    0, 0, 0, 2, 8, 2, 0, 0, 0, 253, 212, 154, 115, 0, 0, 0, 20, 73, 68, 65,
    84, 120, 156, 99, 248, 207, 192, 192, 0, 194, 12, 255, 255, 255, 255, 15,
    0, 31, 238, 5, 251, 176, 184, 151, 201, 0, 0, 0, 0, 73, 69, 78, 68, 174,
    66, 96, 130
]

// Write test.png into the working directory and return its absolute path.
func materializeTestPng(): String {
    let path = getWorkingDirectory().join("test.png")
    removeIfExists(path)
    let file = File.create(path)
    file.write(TEST_PNG_BYTES)
    file.close()
    return path.toString()
}

@Test
class CanvasTests {

    // create_device
    @TestCase
    func createDevice(): Unit {
        let device = GpuDevice.createWarp()
        // The reference fetches the d3d device, d2d device and dxgi factory and
        // simply confirms they are accessible. Here the raw COM pointers are
        // non-null on success.
        @Assert(!device.d3dDeviceRaw().isNull())
        @Assert(!device.d2dDeviceRaw().isNull())
        @Assert(!device.dxgiFactoryRaw().isNull())
    }

    // create_swap_chain
    @TestCase
    func createSwapChain(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)
        @Assert(chain.width(), 64u32)
        @Assert(chain.height(), 64u32)
    }

    // draw_and_present
    @TestCase
    func drawAndPresent(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        let session = chain.beginDraw()
        session.clear(ColorF.cornflowerBlue())
        session.close()

        @Assert(chain.present())
    }

    // resize_swap_chain
    @TestCase
    func resizeSwapChain(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)
        chain.resize(128, 128)
        @Assert(chain.width(), 128u32)
        @Assert(chain.height(), 128u32)
    }

    // brush_reuse_across_frames
    @TestCase
    func brushReuseAcrossFrames(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        let brush = chain.createSolidBrush(ColorF.red())

        for (_ in 0..3) {
            let session = chain.beginDraw()
            session.clear(ColorF.black())
            session.fillEllipse(Ellipse.circle(vector2(32.0, 32.0), 16.0), brush)
            session.close()
            @Assert(chain.present())
        }
    }

    // text_format_and_draw_text
    @TestCase
    func textFormatAndDrawText(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(128, 64)

        let format = TextFormat.create("Segoe UI", 16.0)
            .withAlignment(TextAlignment.Center)
        let brush = chain.createSolidBrush(ColorF.white())

        let session = chain.beginDraw()
        session.clear(ColorF.black())
        session.drawText("Hello", format, Rect(0.0, 0.0, 128.0, 64.0), brush)
        session.close()
        @Assert(chain.present())
    }

    // path_builder_typestate
    @TestCase
    func pathBuilderTypestate(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        // Build a triangle path.
        let path = PathBuilder.create(device)
            .begin(vector2(32.0, 0.0))
            .lineTo(vector2(64.0, 64.0))
            .lineTo(vector2(0.0, 64.0))
            .close()
            .build()

        let brush = chain.createSolidBrush(ColorF.green())

        let session = chain.beginDraw()
        session.clear(ColorF.black())
        session.fillPath(path, brush)
        session.drawPath(path, brush, 2.0)
        session.close()
        @Assert(chain.present())
    }

    // present_reports_no_device_lost
    @TestCase
    func presentReportsNoDeviceLost(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        let session = chain.beginDraw()
        session.clear(ColorF.black())
        session.close()

        // Normal present should return true - the device is fine.
        let result = chain.present()
        @Assert(result, true)
        @Assert(!chain.isDeviceLostNow())
    }

    // rounded_rect_draw_fill
    @TestCase
    func roundedRectDrawFill(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)
        let brush = chain.createSolidBrush(ColorF.red())

        let rrect = RoundedRect.uniform(Rect(5.0, 5.0, 55.0, 55.0), 8.0)

        let session = chain.beginDraw()
        session.clear(ColorF.black())
        session.fillRoundedRect(rrect, brush)
        session.drawRoundedRect(rrect, brush, 2.0)
        session.close()
        @Assert(chain.present())
    }

    // transform_set_get_restore
    @TestCase
    func transformSetGetRestore(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        let session = chain.beginDraw()
        session.clear(ColorF.black())

        // Default is identity.
        let identity = session.getTransform()
        @Assert(identity.M11, 1.0f32)
        @Assert(identity.M22, 1.0f32)
        @Assert(identity.M31, 0.0f32)

        // Set a translation.
        let translated = matrix3x2(1.0, 0.0, 0.0, 1.0, 10.0, 20.0)
        session.setTransform(translated)
        let got = session.getTransform()
        @Assert(got.M31, 10.0f32)
        @Assert(got.M32, 20.0f32)

        // withTransform restores the original.
        let scaled = matrix3x2(2.0, 0.0, 0.0, 2.0, 0.0, 0.0)
        session.withTransform(scaled, {=>
            let inside = session.getTransform()
            @Assert(inside.M11, 2.0f32)
        })
        let after = session.getTransform()
        @Assert(after.M31, 10.0f32) // restored to translated

        session.close()
        @Assert(chain.present())
    }

    // linear_gradient_brush
    @TestCase
    func linearGradientBrush(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        let session = chain.beginDraw()
        session.clear(ColorF.black())

        let gradient = session.createLinearGradient(
            vector2(0.0, 0.0),
            vector2(64.0, 0.0),
            [
                GradientStop(0.0, ColorF.red()),
                GradientStop(1.0, ColorF.blue())
            ]
        )

        // Use the gradient with various draw methods (same as a solid brush).
        session.fillRect(Rect(0.0, 0.0, 64.0, 32.0), gradient)
        session.fillEllipse(Ellipse.circle(vector2(32.0, 48.0), 12.0), gradient)

        session.close()
        @Assert(chain.present())
    }

    // radial_gradient_brush
    @TestCase
    func radialGradientBrush(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        let session = chain.beginDraw()
        session.clear(ColorF.black())

        let gradient = session.createRadialGradient(
            vector2(32.0, 32.0),
            32.0,
            32.0,
            [
                GradientStop(0.0, ColorF.white()),
                GradientStop(1.0, ColorF.black())
            ]
        )

        session.fillRect(Rect(0.0, 0.0, 64.0, 64.0), gradient)

        session.close()
        @Assert(chain.present())
    }

    // load_and_draw_bitmap
    @TestCase
    func loadAndDrawBitmap(): Unit {
        ensureComInitialized()
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        let pngPath = materializeTestPng()
        let bitmap = chain.loadBitmap(pngPath)

        @Assert(bitmap.width() > 0.0f32)
        @Assert(bitmap.height() > 0.0f32)

        let session = chain.beginDraw()
        session.clear(ColorF.black())
        session.drawBitmap(bitmap, Rect(0.0, 0.0, 64.0, 64.0), 1.0)
        session.close()
        @Assert(chain.present())
    }

    // load_bitmap_nonexistent_file_returns_err
    @TestCase
    func loadBitmapNonexistentFileReturnsErr(): Unit {
        ensureComInitialized()
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        // The reference returns Err; the cj API throws on COM failure, so the
        // behaviour-equivalent assertion is that loading a missing file throws.
        @AssertThrows(chain.loadBitmap("nonexistent_file_that_does_not_exist.png"))
    }

    // resize_zero_is_noop
    @TestCase
    func resizeZeroIsNoop(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)
        chain.resize(0, 0)
        @Assert(chain.width(), 64u32)
        @Assert(chain.height(), 64u32)
    }

    // path_builder_begin_hollow_and_end_open
    @TestCase
    func pathBuilderBeginHollowAndEndOpen(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        // Build a hollow open path (stroke-only, not closed).
        let path = PathBuilder.create(device)
            .beginHollow(vector2(0.0, 32.0))
            .lineTo(vector2(32.0, 0.0))
            .lineTo(vector2(64.0, 32.0))
            .endOpen()
            .build()

        let brush = chain.createSolidBrush(ColorF.white())
        let session = chain.beginDraw()
        session.clear(ColorF.black())
        session.drawPath(path, brush, 2.0)
        session.close()
        @Assert(chain.present())
    }

    // path_builder_multiple_figures
    @TestCase
    func pathBuilderMultipleFigures(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        // Two separate closed triangles in one path.
        let path = PathBuilder.create(device)
            .begin(vector2(0.0, 0.0))
            .lineTo(vector2(30.0, 0.0))
            .lineTo(vector2(15.0, 30.0))
            .close()
            .begin(vector2(34.0, 34.0))
            .lineTo(vector2(64.0, 34.0))
            .lineTo(vector2(49.0, 64.0))
            .close()
            .build()

        let brush = chain.createSolidBrush(ColorF.green())
        let session = chain.beginDraw()
        session.clear(ColorF.black())
        session.fillPath(path, brush)
        session.close()
        @Assert(chain.present())
    }

    // text_format_new_bold
    @TestCase
    func textFormatNewBold(): Unit {
        let format = TextFormat.createBold("Segoe UI", 20.0)

        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(128, 64)
        let brush = chain.createSolidBrush(ColorF.white())

        let session = chain.beginDraw()
        session.clear(ColorF.black())
        session.drawText("Bold", format, Rect(0.0, 0.0, 128.0, 64.0), brush)
        session.close()
        @Assert(chain.present())
    }

    // radial_gradient_with_fill_ellipse
    @TestCase
    func radialGradientWithFillEllipse(): Unit {
        let device = GpuDevice.createWarp()
        let chain = device.createSwapChain(64, 64)

        let session = chain.beginDraw()
        session.clear(ColorF.black())

        let gradient = session.createRadialGradient(
            vector2(32.0, 32.0),
            32.0,
            32.0,
            [
                GradientStop(0.0, ColorF.white()),
                GradientStop(1.0, ColorF.black())
            ]
        )

        // Use the radial gradient with fillEllipse (not just fillRect).
        session.fillEllipse(Ellipse.circle(vector2(32.0, 32.0), 30.0), gradient)

        session.close()
        @Assert(chain.present())
    }
}
