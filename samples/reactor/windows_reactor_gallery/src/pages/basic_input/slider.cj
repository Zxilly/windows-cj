package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Slider
// ============================================================================
let sliderPageToken = newComponentTypeToken()

func sliderPage(cx: RenderCx): Element {
    let (volume, setVolume) = cx.useState<Float64>(35.0)
    let (brightness, setBrightness) = cx.useState<Float64>(60.0)
    let (temperature, setTemperature) = cx.useState<Float64>(21.0)

    page_content(
        "Slider",
        "Select a value from a range with precise, touch-friendly input.",
        [
            sample_card(
                "Basic Slider",
                vstack([
                    slider(volume)
                        .range(0.0, 100.0)
                        .step(1.0)
                        .header("Volume")
                        .onChanged({ v: Float64 => setVolume.call(v) })
                        .toElement(),
                    text_block("Volume: ${fmt0(volume)}%").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "slider(volume)\n    .range(0.0, 100.0)\n    .step(1.0)\n    .onChanged(...)"
            ),
            sample_card(
                "Vertical Slider",
                hstack([
                    slider(brightness)
                        .range(0.0, 100.0)
                        .step(5.0)
                        .header("Brightness")
                        .vertical()
                        .height(140.0)
                        .onChanged({ v: Float64 => setBrightness.call(v) })
                        .toElement(),
                    vstack([
                        text_block("Screen brightness").bold().toElement(),
                        text_block("${fmt0(brightness)}%").fontSize(18.0).toElement(),
                        text_block("Drag the thumb to preview a stronger or softer look.").opacity(0.6).toElement()
                    ]).spacing(4.0).toElement()
                ]).spacing(16.0).toElement(),
                "slider(brightness)\n    .vertical()\n    .height(140.0)\n    .onChanged(...)"
            ),
            sample_card(
                "Range with Value Label",
                vstack([
                    slider(temperature)
                        .range(16.0, 30.0)
                        .step(0.5)
                        .header("Room temperature")
                        .onChanged({ v: Float64 => setTemperature.call(v) })
                        .toElement(),
                    text_block("Target: ${fmt1(temperature)} \u{00B0}C").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "slider(temperature)\n    .range(16.0, 30.0)\n    .step(0.5)\n    .onChanged(...)"
            )
        ]
    )
}
