package windows_reactor_gallery.pages.text

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let typeRampPageToken = newComponentTypeToken()

// ── Type Ramp ────────────────────────────────────────────────────────────────
// The WinUI 3 named type-ramp steps approximated with text_block size/weight,
// a custom font-size strip, and a composed article card. The reference exposes
// title/subtitle/body* as named text factories; the framework has no such free
// functions, so each step is rendered as text_block(..).fontSize(..) with the
// matching weight (semibold for Title/Subtitle/BodyStrong, regular otherwise).
func typeRampPage(cx: RenderCx): Element {
    let _ = cx

    let rampDemo = vstack([
        typeTitle("Title \u{2014} 28px Semibold"),
        typeSubtitle("Subtitle \u{2014} 20px Semibold"),
        typeBodyLarge("BodyLarge \u{2014} 18px Regular"),
        typeBodyStrong("BodyStrong \u{2014} 14px Semibold"),
        typeBody("Body \u{2014} 14px Regular"),
        typeCaption("Caption \u{2014} 12px Regular")
    ]).spacing(8.0).toElement()

    let customDemo = vstack([
        text_block("Small text").fontSize(10.0).toElement(),
        text_block("Normal text").fontSize(14.0).toElement(),
        text_block("Large text").fontSize(24.0).toElement(),
        text_block("Huge text").fontSize(36.0).toElement()
    ]).spacing(4.0).toElement()

    let articleCard = border(
        vstack([
            typeTitle("Release Notes"),
            typeSubtitle("Version 2.5"),
            typeBodyStrong("New update available"),
            typeBody("Version 2.5 ships performance improvements and several bug fixes."),
            typeBody("Restart the app to apply.")
        ]).spacing(8.0).toElement()
    ).padding(Thickness.uniform(16.0)).cornerRadius(8.0).toElement()

    page_content(
        "Type Ramp",
        "Named text factories for the WinUI 3 type ramp.",
        [
            sample_card(
                "Type Ramp Factories",
                rampDemo,
                "text_block(\"Title\").fontSize(28.0).semibold()\n" +
                "text_block(\"Subtitle\").fontSize(20.0).semibold()\n" +
                "text_block(\"BodyLarge\").fontSize(18.0)\n" +
                "text_block(\"BodyStrong\").fontSize(14.0).semibold()\n" +
                "text_block(\"Body\").fontSize(14.0)\n" +
                "text_block(\"Caption\").fontSize(12.0)"
            ),
            sample_card(
                "Custom Font Size",
                customDemo,
                "text_block(\"Small\").fontSize(10.0)\n" +
                "text_block(\"Normal\").fontSize(14.0)\n" +
                "text_block(\"Large\").fontSize(24.0)\n" +
                "text_block(\"Huge\").fontSize(36.0)"
            ),
            sample_card(
                "Composed Example \u{2014} Article Card",
                articleCard,
                "border(vstack([\n" +
                "    typeTitle(\"Release Notes\"),\n" +
                "    typeSubtitle(\"Version 2.5\"),\n" +
                "    typeBodyStrong(\"New update available\"),\n" +
                "    typeBody(\"...description...\")\n" +
                "]).spacing(8.0).toElement()).padding(16.0)"
            )
        ]
    )
}

// ── Type-ramp text factories ─────────────────────────────────────────────────
// WinUI 3 type-ramp steps as text_block with the matching size and weight.
func typeTitle(s: String): Element { text_block(s).fontSize(28.0).semibold().toElement() }
func typeSubtitle(s: String): Element { text_block(s).fontSize(20.0).semibold().toElement() }
func typeBodyLarge(s: String): Element { text_block(s).fontSize(18.0).toElement() }
func typeBodyStrong(s: String): Element { text_block(s).fontSize(14.0).semibold().toElement() }
func typeBody(s: String): Element { text_block(s).fontSize(14.0).toElement() }
func typeCaption(s: String): Element { text_block(s).fontSize(12.0).toElement() }
