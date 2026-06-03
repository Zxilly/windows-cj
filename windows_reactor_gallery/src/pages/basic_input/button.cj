package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Button
// ============================================================================
let buttonPageToken = newComponentTypeToken()

func buttonPage(cx: RenderCx): Element {
    let (basicOutput, setBasicOutput) = cx.useState<String>("Ready")
    let (accentOutput, setAccentOutput) = cx.useState<String>("Ready")
    let (subtleOutput, setSubtleOutput) = cx.useState<String>("Ready")
    let (linkOutput, setLinkOutput) = cx.useState<String>("Ready")

    page_content(
        "Button",
        "A button that responds to user clicks and pointer input.",
        [
            sample_card(
                "Basic Button — .onClick(handler)",
                vstack([
                    button("Save").onClick({ => setBasicOutput.call("Saved!") }).toElement(),
                    text_block(basicOutput).foregroundTheme(ThemeRef.SecondaryText).toElement()
                ]).spacing(8.0).toElement(),
                "button(\"Save\").onClick({ => setOutput.call(\"Saved!\") })"
            ),
            sample_card(
                "Disabled Button",
                button("Can't Click").enabled(false).toElement(),
                "button(\"Can't Click\").enabled(false)"
            ),
            sample_card(
                "Accent style — .accent()",
                vstack([
                    button("Confirm").onClick({ => setAccentOutput.call("Confirmed!") }).accent().toElement(),
                    text_block(accentOutput).foregroundTheme(ThemeRef.SecondaryText).toElement()
                ]).spacing(8.0).toElement(),
                "button(\"Confirm\").onClick(...).accent()"
            ),
            sample_card(
                "Subtle style — .subtle()",
                vstack([
                    button("Cancel").onClick({ => setSubtleOutput.call("Cancelled.") }).subtle().toElement(),
                    text_block(subtleOutput).foregroundTheme(ThemeRef.SecondaryText).toElement()
                ]).spacing(8.0).toElement(),
                "button(\"Cancel\").onClick(...).subtle()"
            ),
            sample_card(
                "Text-link style — .textLink()",
                vstack([
                    hstack([
                        text_block("Need help?").foregroundTheme(ThemeRef.SecondaryText).toElement(),
                        button("Learn more").onClick({ => setLinkOutput.call("Link clicked.") }).textLink().toElement()
                    ]).spacing(4.0).toElement(),
                    text_block(linkOutput).foregroundTheme(ThemeRef.SecondaryText).toElement()
                ]).spacing(8.0).toElement(),
                "button(\"Learn more\").onClick(...).textLink()"
            )
        ]
    )
}
