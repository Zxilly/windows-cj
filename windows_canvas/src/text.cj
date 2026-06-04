package windows_canvas

import windows_canvas_bindings.Win32.Graphics.DirectWrite.{
    Apis as DWriteApis,
    IDWriteFactory,
    IDWriteTextFormat,
    IDWriteFactoryVtbl,
    IDWriteTextFormatVtbl
}

import windows_core.{HRESULT, GUID}
import windows_strings.encodeUtf16WithNull

// --- DWrite scalar constants (not surfaced by the facade) ---
const DWRITE_FACTORY_TYPE_SHARED_T: Int32 = 0
const DWRITE_FONT_STYLE_NORMAL: Int32 = 0
const DWRITE_FONT_STRETCH_NORMAL: Int32 = 5
const DWRITE_TEXT_ALIGNMENT_LEADING: Int32 = 0
const DWRITE_TEXT_ALIGNMENT_TRAILING: Int32 = 1
const DWRITE_TEXT_ALIGNMENT_CENTER: Int32 = 2
const DWRITE_PARAGRAPH_ALIGNMENT_NEAR: Int32 = 0
const DWRITE_PARAGRAPH_ALIGNMENT_FAR: Int32 = 1
const DWRITE_PARAGRAPH_ALIGNMENT_CENTER: Int32 = 2
const IID_IDWriteFactory_T: String = "b859ee5a-d838-4b5b-a2e8-1adc7d93db48"

// Horizontal text alignment.
public enum TextAlignment {
    | Leading
    | Center
    | Trailing
}

// Vertical paragraph alignment.
public enum ParagraphAlignment {
    | Top
    | ParagraphCenter
    | Bottom
}

// Font weight.
//
// Cangjie paradigm note (equivalent): the reference uses a single-field tuple
// struct with associated `NORMAL`/`BOLD` constants. Here the same numeric
// weight is held in a value struct with static factories (identical values).
public struct FontWeight {
    public let value: Int32

    public init(value: Int32) {
        this.value = value
    }

    public static func normal(): FontWeight {
        return FontWeight(400)
    }

    public static func bold(): FontWeight {
        return FontWeight(700)
    }
}

// A text format describing font family, size, weight, and alignment.
//
// Created independently of any device - DWrite factories are shared singletons.
public class TextFormat {
    let inner: IDWriteTextFormat

    init(inner: IDWriteTextFormat) {
        this.inner = inner
    }

    // Access the raw `IDWriteTextFormat`.
    func asRaw(): CPointer<Unit> {
        return this.inner.asRaw()
    }

    // Create a text format with the given font family and size (normal weight).
    public static func create(family: String, size: Float32): TextFormat {
        return TextFormat.withWeight(family, size, FontWeight.normal())
    }

    // Create a bold text format.
    public static func createBold(family: String, size: Float32): TextFormat {
        return TextFormat.withWeight(family, size, FontWeight.bold())
    }

    // Create a text format with a specific weight.
    public static func withWeight(family: String, size: Float32, weight: FontWeight): TextFormat {
        // factory = DWriteCreateFactory(SHARED, IID_IDWriteFactory, &out).
        var iid = GUID.parse(IID_IDWriteFactory_T)
        var factoryRaw = CPointer<Unit>()
        unsafe {
            let hr = DWriteApis.DWriteCreateFactory(
                DWRITE_FACTORY_TYPE_SHARED_T,
                CPointer<Unit>(CPointer<GUID>(inout iid)),
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout factoryRaw))
            )
            HRESULT(hr).check()
        }
        let factory = IDWriteFactory(factoryRaw, takeOwnership: true)

        var familyWide = encodeUtf16WithNull(family)
        var localeWide = encodeUtf16WithNull("en-us")
        let familyHandle = unsafe { acquireArrayRawData(familyWide) }
        let localeHandle = unsafe { acquireArrayRawData(localeWide) }
        var formatRaw = CPointer<Unit>()
        try {
            unsafe {
                let vtbl = CPointer<CPointer<IDWriteFactoryVtbl>>(factoryRaw).read().read()
                // CreateTextFormat(family, collection=None, weight, NORMAL style,
                // NORMAL stretch, size, locale, &out).
                let hr = vtbl.CreateTextFormat(
                    factoryRaw,
                    familyHandle.pointer,
                    CPointer<Unit>(),
                    weight.value,
                    DWRITE_FONT_STYLE_NORMAL,
                    DWRITE_FONT_STRETCH_NORMAL,
                    size,
                    localeHandle.pointer,
                    CPointer<Unit>(CPointer<CPointer<Unit>>(inout formatRaw))
                )
                HRESULT(hr).check()
            }
        } finally {
            unsafe {
                releaseArrayRawData(familyHandle)
                releaseArrayRawData(localeHandle)
            }
        }
        factory.close()
        return TextFormat(IDWriteTextFormat(formatRaw, takeOwnership: true))
    }

    // Set horizontal text alignment. Returns `this` for chaining.
    public func withAlignment(alignment: TextAlignment): TextFormat {
        let value = match (alignment) {
            case Leading => DWRITE_TEXT_ALIGNMENT_LEADING
            case Center => DWRITE_TEXT_ALIGNMENT_CENTER
            case Trailing => DWRITE_TEXT_ALIGNMENT_TRAILING
        }
        let raw = this.inner.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<IDWriteTextFormatVtbl>>(raw).read().read()
            let _ = vtbl.SetTextAlignment(raw, value)
        }
        return this
    }

    // Set vertical paragraph alignment. Returns `this` for chaining.
    public func withParagraphAlignment(alignment: ParagraphAlignment): TextFormat {
        let value = match (alignment) {
            case Top => DWRITE_PARAGRAPH_ALIGNMENT_NEAR
            case ParagraphCenter => DWRITE_PARAGRAPH_ALIGNMENT_CENTER
            case Bottom => DWRITE_PARAGRAPH_ALIGNMENT_FAR
        }
        let raw = this.inner.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<IDWriteTextFormatVtbl>>(raw).read().read()
            let _ = vtbl.SetParagraphAlignment(raw, value)
        }
        return this
    }
}
