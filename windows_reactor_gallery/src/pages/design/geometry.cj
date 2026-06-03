package windows_reactor_gallery.pages.design

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let geometryPageToken = newComponentTypeToken()

// ── Geometry ───────────────────────────────────────────────────────────────────

// Approximation note: the reference uses a Shape::rectangle().fill(..) primitive
// that has no widget equivalent here. A bordered empty box with a solid
// background and the given corner radius is the behaviourally-equivalent
// rounded swatch.
func radiusSwatch(radius: Float64): Element {
    border(Element.EmptyEl)
        .background(Brush.Solid(accentColor))
        .cornerRadius(radius)
        .width(48.0)
        .height(48.0)
        .toElement()
}

func radiusRow(name: String, value: Float64, recommendation: String): Element {
    hstack([
        radiusSwatch(value),
        vstack([
            text_block("${name} \u{2014} ${intText(value)}px").fontSize(14.0).bold().toElement(),
            text_block(recommendation).fontSize(12.0).opacity(0.6).toElement()
        ]).spacing(2.0).toElement()
    ]).spacing(12.0).toElement()
}

func tagBox(label: String, padX: Float64, padY: Float64): Element {
    border(text_block(label).padding(Thickness.xy(padX, padY)).toElement())
        .cornerRadius(4.0)
        .borderBrush(BrushBinding.ofColor(neutralStroke))
        .borderThickness(Thickness.uniform(1.0))
        .toElement()
}

func geometry_page(): Element {
    pageComponent(geometryPageToken, { _: RenderCx =>
        let cardResources = sample_card(
            "Corner Radius Resources",
            vstack([
                text_block("WinUI provides two standard corner radius values. ControlCornerRadius (4px) for interactive controls and OverlayCornerRadius (8px) for overlay surfaces.")
                    .opacity(0.6).fontSize(13.0).toElement(),
                radiusRow("Control", 4.0, "Buttons, text fields, combo boxes, sliders, toggles"),
                radiusRow("Overlay", 8.0, "Dialogs, flyouts, teaching tips, menus")
            ]).spacing(12.0).toElement(),
            "// ControlCornerRadius = 4px\nborder(content).cornerRadius(4.0)\n\n// OverlayCornerRadius = 8px\nborder(dialog).cornerRadius(8.0)"
        )

        let cardControl = sample_card(
            "ControlCornerRadius (4px)",
            vstack([
                text_block("Interactive controls use 4px rounding:").opacity(0.6).fontSize(13.0).toElement(),
                hstack([
                    tagBox("Button", 12.0, 6.0),
                    tagBox("Input", 12.0, 6.0),
                    tagBox("Tag", 8.0, 4.0)
                ]).spacing(8.0).toElement()
            ]).spacing(8.0).toElement(),
            "border(content)\n    .cornerRadius(4.0)\n    .borderBrush(BrushBinding.ofColor(Color.rgb(128, 128, 128)))\n    .borderThickness(Thickness.uniform(1.0))"
        )

        let cardOverlay = sample_card(
            "OverlayCornerRadius (8px)",
            vstack([
                text_block("Overlay surfaces use 8px rounding:").opacity(0.6).fontSize(13.0).toElement(),
                border(
                    vstack([
                        text_block("Dialog Title").fontSize(16.0).bold().toElement(),
                        text_block("This surface uses OverlayCornerRadius for its border rounding.")
                            .opacity(0.6).fontSize(13.0).toElement()
                    ]).spacing(8.0).padding(Thickness.uniform(16.0)).toElement()
                )
                    .cornerRadius(8.0)
                    .borderBrush(BrushBinding.ofColor(neutralStroke))
                    .borderThickness(Thickness.uniform(1.0))
                    .toElement()
            ]).spacing(8.0).toElement(),
            "border(dialog_content)\n    .cornerRadius(8.0)  // OverlayCornerRadius"
        )

        let cardCompare = sample_card(
            "Comparing Radii",
            hstack([
                vstack([
                    radiusSwatch(4.0),
                    text_block("4px\nControl").fontSize(11.0).opacity(0.6).toElement()
                ]).spacing(4.0).toElement(),
                vstack([
                    radiusSwatch(8.0),
                    text_block("8px\nOverlay").fontSize(11.0).opacity(0.6).toElement()
                ]).spacing(4.0).toElement()
            ]).spacing(24.0).toElement(),
            "// Rounded swatch with solid fill\nborder(content)\n    .background(Brush.Solid(Color.rgb(0, 120, 212)))\n    .cornerRadius(4.0)  // vs .cornerRadius(8.0)"
        )

        page_content(
            "Geometry",
            "WinUI defines shared corner radius values so controls and surfaces have a consistent shape language.",
            [cardResources, cardControl, cardOverlay, cardCompare]
        )
    })
}
