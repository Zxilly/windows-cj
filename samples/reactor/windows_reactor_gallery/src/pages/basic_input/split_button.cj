package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// SplitButton
// ============================================================================
let splitButtonPageToken = newComponentTypeToken()

func splitButtonPage(cx: RenderCx): Element {
    let (clicks, setClicks) = cx.useState<Int64>(0)

    page_content(
        "SplitButton",
        "A button with a primary action and a flyout menu.",
        [
            sample_card(
                "Basic SplitButton",
                vstack([
                    split_button("Paste").onClick({ => setClicks.call(clicks + 1) }).toElement(),
                    text_block("Primary clicked: ${clicks} times").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "split_button(\"Paste\").onClick(handler)"
            ),
            sample_card(
                "Disabled SplitButton",
                split_button("Disabled Action").enabled(false).toElement(),
                "split_button(\"Disabled\").enabled(false)"
            )
        ]
    )
}
