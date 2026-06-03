package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// NumberBox
// ============================================================================
let numberBoxPageToken = newComponentTypeToken()

func numberBoxPage(cx: RenderCx): Element {
    let (value, setValue) = cx.useState<Float64>(42.0)
    let (clamped, setClamped) = cx.useState<Float64>(5.0)

    page_content(
        "NumberBox",
        "A text control for entering numeric values with validation.",
        [
            sample_card(
                "Basic NumberBox",
                vstack([
                    number_box(value)
                        .header("Quantity")
                        .onValueChanged({ v: Float64 => setValue.call(v) })
                        .toElement(),
                    text_block("Value: ${value}").toElement()
                ]).spacing(8.0).toElement(),
                "number_box(value).header(\"Quantity\").onValueChanged(handler)"
            ),
            sample_card(
                "NumberBox with Range",
                vstack([
                    number_box(clamped)
                        .header("Rating (1-10)")
                        .range(1.0, 10.0)
                        .onValueChanged({ v: Float64 => setClamped.call(v) })
                        .toElement(),
                    text_block("Clamped value: ${clamped}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "number_box(val).header(\"Rating\").range(1.0, 10.0)"
            ),
            sample_card(
                "Disabled NumberBox",
                number_box(99.0).header("Fixed").enabled(false).toElement(),
                "number_box(99.0).enabled(false)"
            )
        ]
    )
}
