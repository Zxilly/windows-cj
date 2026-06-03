package windows_reactor_gallery.pages.dialogs

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let commandBarFlyoutPageToken = newComponentTypeToken()

// ── CommandBarFlyout ─────────────────────────────────────────────────────────
// The CommandBarFlyout is attached to a button and pops on click: the primary
// commands (Cut/Copy/Paste) and the secondary commands (Select All / separator /
// Print) mirror the reference, with the last-action state wired through
// onCommandBarFlyoutClick(label).
func commandBarFlyoutPage(cx: RenderCx): Element {
    let (lastAction, setLastAction) = cx.useState<String>("(none)")

    let basicPrimary = ArrayList<CommandBarCommandDef>()
    basicPrimary.add(CommandBarCommandDef.Button("Cut", Some(SymbolGlyph.Cut)))
    basicPrimary.add(CommandBarCommandDef.Button("Copy", Some(SymbolGlyph.Copy)))
    basicPrimary.add(CommandBarCommandDef.Button("Paste", Some(SymbolGlyph.Paste)))

    let basicCard = sample_card(
        "Basic CommandBarFlyout",
        vstack([
            button("Show Commands")
                .commandBarFlyout(basicPrimary)
                .onCommandBarFlyoutClick({ label: String => setLastAction.call(label) })
                .toElement(),
            text_block("Last action: ${lastAction}").opacity(0.6).toElement()
        ]).spacing(8.0).toElement(),
        "button(\"Show Commands\")\n    .command_bar_flyout([\n        app_bar_button_icon(\"Cut\", SymbolGlyph.Cut),\n        app_bar_button_icon(\"Copy\", SymbolGlyph.Copy),\n        app_bar_button_icon(\"Paste\", SymbolGlyph.Paste),\n    ])\n    .on_command_bar_flyout_click(|label| set_action.call(label))"
    )

    let secPrimary = ArrayList<CommandBarCommandDef>()
    secPrimary.add(CommandBarCommandDef.Button("Share", Some(SymbolGlyph.Send)))
    let secSecondary = ArrayList<CommandBarCommandDef>()
    secSecondary.add(CommandBarCommandDef.Button("Select All", None))
    secSecondary.add(CommandBarCommandDef.Separator)
    secSecondary.add(CommandBarCommandDef.Button("Print", None))

    let secondaryCard = sample_card(
        "CommandBarFlyout with Secondary Commands",
        button("More Options")
            .commandBarFlyout(secPrimary)
            .commandBarFlyoutSecondaryOf(secSecondary)
            .onCommandBarFlyoutClick({ label: String => setLastAction.call(label) })
            .toElement(),
        "button(\"More Options\")\n    .command_bar_flyout([\n        app_bar_button_icon(\"Share\", SymbolGlyph.Send),\n    ])\n    .command_bar_flyout_secondary([\n        app_bar_button(\"Select All\"),\n        app_bar_separator(),\n        app_bar_button(\"Print\"),\n    ])"
    )

    page_content(
        "CommandBarFlyout",
        "A flyout that provides quick access to common commands.",
        [basicCard, secondaryCard]
    )
}
