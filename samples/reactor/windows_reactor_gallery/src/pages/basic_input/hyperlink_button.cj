package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// HyperlinkButton
// ============================================================================
let hyperlinkButtonPageToken = newComponentTypeToken()

func hyperlinkButtonPage(cx: RenderCx): Element {
    let (clicks, setClicks) = cx.useState<Int32>(0)

    page_content(
        "HyperlinkButton",
        "A button that appears as a hyperlink and navigates to a URI.",
        [
            sample_card(
                "Navigate to URI",
                hyperlink_button("Visit Microsoft").navigateUri("https://www.microsoft.com").toElement(),
                "hyperlink_button(\"Visit\").navigateUri(\"https://...\")"
            ),
            sample_card(
                "HyperlinkButton with Click Handler",
                vstack([
                    hyperlink_button("Click me (no navigation)")
                        .onClick({ => setClicks.call(clicks + 1) })
                        .toElement(),
                    text_block("Clicked: ${clicks} times").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "hyperlink_button(\"Click me\").onClick(handler)"
            )
        ]
    )
}
