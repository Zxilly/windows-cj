package windows_canvas

import windows_canvas_bindings.Win32.Graphics.Imaging.{
    Apis as WICApis,
    IWICImagingFactory,
    IWICBitmapDecoder,
    IWICBitmapFrameDecode,
    IWICFormatConverter,
    IWICImagingFactoryVtbl,
    IWICBitmapDecoderVtbl,
    IWICFormatConverterVtbl
}
import windows_canvas_bindings.Win32.Graphics.Direct2D.{
    ID2D1Bitmap,
    ID2D1DeviceContextVtbl
}
import windows_canvas_bindings.Win32.System.Com.Apis as ComApis

import windows_core.{HRESULT, GUID}
import windows_strings.encodeUtf16WithNull

// --- Scalar WIC / COM constants (not surfaced by the facade) ---
const CLSCTX_INPROC_SERVER: UInt32 = 1
const GENERIC_READ: UInt32 = 0x8000_0000
const WICDecodeMetadataCacheOnDemand: Int32 = 0
const WICBitmapDitherTypeNone: Int32 = 0
const WICBitmapPaletteTypeMedianCut: Int32 = 3
const IID_IWICImagingFactory: String = "ec5ec8a9-c395-4314-9c77-54d7a935ff70"

// A GPU-resident bitmap that can be drawn to the canvas.
//
// Load from a file with `SwapChain.loadBitmap` and draw with
// `DrawingSession.drawBitmap`.
public class Bitmap {
    let inner: ID2D1Bitmap
    let widthDip: Float32
    let heightDip: Float32

    init(inner: ID2D1Bitmap, widthDip: Float32, heightDip: Float32) {
        this.inner = inner
        this.widthDip = widthDip
        this.heightDip = heightDip
    }

    func asRaw(): CPointer<Unit> {
        return this.inner.asRaw()
    }

    // Load a bitmap from an image file (PNG, JPEG, BMP, etc.).
    //
    // `contextRaw` is the raw `ID2D1RenderTarget`/`ID2D1DeviceContext` that owns
    // the resulting GPU bitmap.
    static func loadFromFile(contextRaw: CPointer<Unit>, path: String): Bitmap {
        // wicFactory = CoCreateInstance(CLSID_WICImagingFactory).
        var clsid = WICApis.CLSID_WICImagingFactory()
        var iid = GUID.parse(IID_IWICImagingFactory)
        var factoryRaw = CPointer<Unit>()
        unsafe {
            let hr = ComApis.CoCreateInstance(
                CPointer<Unit>(CPointer<GUID>(inout clsid)),
                CPointer<Unit>(),
                CLSCTX_INPROC_SERVER,
                CPointer<Unit>(CPointer<GUID>(inout iid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout factoryRaw))
            )
            HRESULT(hr).check()
        }
        let factory = IWICImagingFactory(factoryRaw, takeOwnership: true)

        // decoder = factory.CreateDecoderFromFilename(path, None, GENERIC_READ,
        // OnDemand).
        var widePath = encodeUtf16WithNull(path)
        let pathHandle = unsafe { acquireArrayRawData(widePath) }
        var decoderRaw = CPointer<Unit>()
        try {
            unsafe {
                let vtbl = CPointer<CPointer<IWICImagingFactoryVtbl>>(factoryRaw).read().read()
                let hr = vtbl.CreateDecoderFromFilename(
                    factoryRaw,
                    pathHandle.pointer,
                    CPointer<Unit>(),
                    GENERIC_READ,
                    WICDecodeMetadataCacheOnDemand,
                    CPointer<Unit>(CPointer<CPointer<Unit>>(inout decoderRaw))
                )
                HRESULT(hr).check()
            }
        } finally {
            unsafe { releaseArrayRawData(pathHandle) }
        }
        let decoder = IWICBitmapDecoder(decoderRaw, takeOwnership: true)

        // frame = decoder.GetFrame(0).
        var frameRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<IWICBitmapDecoderVtbl>>(decoderRaw).read().read()
            let hr = vtbl.GetFrame(
                decoderRaw,
                0,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout frameRaw))
            )
            HRESULT(hr).check()
        }

        // converter = factory.CreateFormatConverter().
        var converterRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<IWICImagingFactoryVtbl>>(factoryRaw).read().read()
            let hr = vtbl.CreateFormatConverter(
                factoryRaw,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout converterRaw))
            )
            HRESULT(hr).check()
        }
        let converter = IWICFormatConverter(converterRaw, takeOwnership: true)

        // converter.Initialize(frame, 32bppPBGRA, DitherNone, None, 0.0,
        // MedianCut).
        var dstFormat = WICApis.GUID_WICPixelFormat32bppPBGRA()
        unsafe {
            let vtbl = CPointer<CPointer<IWICFormatConverterVtbl>>(converterRaw).read().read()
            let hr = vtbl.Initialize(
                converterRaw,
                frameRaw,
                CPointer<Unit>(CPointer<GUID>(inout dstFormat)),
                WICBitmapDitherTypeNone,
                CPointer<Unit>(),
                0.0,
                WICBitmapPaletteTypeMedianCut
            )
            HRESULT(hr).check()
        }

        // Read the pixel dimensions via IWICBitmapSource::GetSize. This is the
        // standard two-out-parameter ABI (HRESULT GetSize(UINT* w, UINT* h)) and
        // is therefore safe to call directly. We deliberately do NOT use
        // ID2D1Bitmap::GetSize: that COM method returns a D2D_SIZE_F aggregate by
        // value, which on x64 uses the hidden-return-pointer (sret) convention.
        // The generated value-returning CFunc reads the result back out of RAX —
        // where the callee left the buffer POINTER, not the value — so it yields
        // garbage (and calling it through a mismatched signature corrupts state).
        // At the default 96 DPI the WIC pixel size equals the DIP size that
        // ID2D1Bitmap::GetSize would report, so this is behaviourally equivalent.
        // See docs/cj-aggregate-return-com-abi-bug.md for the full analysis and
        // the expected root fix (a bindgen change emitting explicit out-param
        // signatures for aggregate returns, after which this can revert to
        // ID2D1Bitmap::GetSize once the bindings are regenerated).
        // GetSize lives on the IWICBitmapSource base of IWICFormatConverter.
        var pxW: UInt32 = 0
        var pxH: UInt32 = 0
        unsafe {
            let vtbl = CPointer<CPointer<IWICFormatConverterVtbl>>(converterRaw).read().read()
            let hr = vtbl.base_.GetSize(
                converterRaw,
                CPointer<Unit>(CPointer<UInt32>(inout pxW)),
                CPointer<Unit>(CPointer<UInt32>(inout pxH))
            )
            HRESULT(hr).check()
        }

        // bitmap = context.CreateBitmapFromWicBitmap(converter, None).
        var bitmapRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1DeviceContextVtbl>>(contextRaw).read().read()
            let hr = vtbl.CreateBitmapFromWicBitmap(
                contextRaw,
                converterRaw,
                CPointer<Unit>(),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout bitmapRaw))
            )
            HRESULT(hr).check()
        }

        // Release the transient WIC objects we no longer need (the bitmap owns
        // its GPU copy of the pixels).
        let frame = IWICBitmapFrameDecode(frameRaw, takeOwnership: true)
        frame.close()
        converter.close()
        decoder.close()
        factory.close()

        return Bitmap(
            ID2D1Bitmap(bitmapRaw, takeOwnership: true),
            Float32(pxW),
            Float32(pxH)
        )
    }

    // Width of the bitmap in device-independent pixels.
    public func width(): Float32 {
        return this.widthDip
    }

    // Height of the bitmap in device-independent pixels.
    public func height(): Float32 {
        return this.heightDip
    }
}
