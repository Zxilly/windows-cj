package windows_canvas_minimal

import std.fs.exists
import windows_canvas.{DrawContext, ColorF, Rect, Bitmap}

// ============================================================================
// bitmap — load a PNG and draw it twice (original size, then scaled-to-fill).
//
// Bitmaps are GPU resources and must be reloaded after device loss; like the
// reference this example reloads per frame for simplicity (a real app would
// cache it and reload only on device recreation).
// ============================================================================

func makeBitmapDraw(): (DrawContext) -> Unit {
    { ctx: DrawContext =>
        ctx.clear(ColorF(0.1, 0.1, 0.1, 1.0))

        let path = locateSamplePng()

        // A missing/undecodable file throws; skip the frame (mirrors the
        // reference `let Ok(bitmap) = ... else return`).
        let bitmap: Bitmap
        try {
            bitmap = ctx.loadBitmap(path)
        } catch (_: Exception) {
            return
        }

        // Draw at original size in the top-left. width()/height() are cached
        // scalar getters (set at load time from the WIC pixel size), not the
        // ID2D1Bitmap::GetSize aggregate-return COM method.
        let w = bitmap.width()
        let h = bitmap.height()
        ctx.drawBitmap(bitmap, Rect(20.0, 20.0, 20.0 + w, 20.0 + h), 1.0)

        // Draw scaled to fill a larger area.
        ctx.drawBitmap(
            bitmap,
            Rect(120.0, 20.0, ctx.width - 20.0, ctx.height - 20.0),
            0.8
        )
    }
}

// Locate sample.png. The reference joins CARGO_MANIFEST_DIR/examples/sample.png;
// Cangjie has no reliable current-exe here, so probe the documented likely
// locations (mirrors the dcomp / direct3d12 sample resource probing): beside the
// exe / working directory, the sample src dir, climbing out of target/release/bin,
// and the repo-root-relative path — so it is found however the sample is run.
func locateSamplePng(): String {
    let candidates: Array<String> = [
        "sample.png",
        "src/sample.png",
        "../../src/sample.png",
        "../../../src/sample.png",
        "samples/canvas/minimal/src/sample.png"
    ]
    for (c in candidates) {
        if (exists(c)) {
            return c
        }
    }
    // Fall back to the first candidate; loadBitmap surfaces the error if it
    // truly cannot be found (and the draw closure skips the frame).
    return candidates[0]
}
