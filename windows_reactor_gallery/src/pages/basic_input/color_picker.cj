package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Equatable wrapper for the color-picker tuple state ───────────────────────
// useState<T> requires T <: Equatable<T>; the reference keeps an (r,g,b,a)
// tuple, which we wrap so it can back a state slot.
struct RgbaState <: Equatable<RgbaState> {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8

    init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        this.r = r
        this.g = g
        this.b = b
        this.a = a
    }

    public operator func ==(other: RgbaState): Bool {
        r == other.r && g == other.g && b == other.b && a == other.a
    }
    public operator func !=(other: RgbaState): Bool { !(this == other) }
}

// ============================================================================
// ColorPicker
// ============================================================================
let colorPickerPageToken = newComponentTypeToken()

func colorPickerPage(cx: RenderCx): Element {
    let (color, setColor) = cx.useState<RgbaState>(RgbaState(50u8, 120u8, 200u8, 255u8))

    page_content(
        "ColorPicker",
        "A control that lets a user pick a color.",
        [
            sample_card(
                "Full ColorPicker",
                vstack([
                    color_picker(ColorArgb.new(color.r, color.g, color.b))
                        .alphaEnabled(true)
                        .onChanged({ c: (UInt8, UInt8, UInt8, UInt8) =>
                            // onChanged delivers the new color as (a, r, g, b)
                            // (alpha first; see invokeColor). RgbaState stores
                            // (r, g, b, a), so reorder — feeding the tuple straight
                            // through mapped alpha→red and made the swatch jump
                            // channels after every selection.
                            setColor.call(RgbaState(c[1], c[2], c[3], c[0]))
                        })
                        .toElement(),
                    text_block("RGBA(${color.r}, ${color.g}, ${color.b}, ${color.a})").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "color_picker(color).alphaEnabled(true).onChanged(handler)"
            ),
            sample_card(
                "Minimal ColorPicker",
                color_picker(ColorArgb.new(200u8, 50u8, 50u8))
                    .hexInputVisible(false)
                    .colorChannelTextInputVisible(false)
                    .toElement(),
                "color_picker(c).hexInputVisible(false).colorChannelTextInputVisible(false)"
            )
        ]
    )
}
