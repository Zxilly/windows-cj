package windows_reactor_gallery.pages.design

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let typographyPageToken = newComponentTypeToken()

// ── Typography ────────────────────────────────────────────────────────────────

func typeSample(name: String, size: Float64, bold: Bool): Element {
    let tb = text_block("${name} \u{2014} ${intText(size)}pt").fontSize(size)
    if (bold) {
        tb.bold()
    }
    tb.toElement()
}

func typography_page(): Element {
    pageComponent(typographyPageToken, { _: RenderCx =>
        let ramp = vstack([
            typeSample("Caption", 12.0, false),
            typeSample("Body", 14.0, false),
            typeSample("Body Strong", 14.0, true),
            typeSample("Subtitle", 20.0, true),
            typeSample("Title", 28.0, true),
            typeSample("Title Large", 40.0, true),
            typeSample("Display", 68.0, true)
        ]).spacing(12.0).toElement()

        page_content(
            "Typography",
            "The WinUI 3 type ramp provides a set of named text styles for consistent hierarchy.",
            [ramp]
        )
    })
}
