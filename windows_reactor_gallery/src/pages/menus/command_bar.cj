package windows_reactor_gallery.pages.menus

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── CommandBar ───────────────────────────────────────────────────────────────
// A toolbar for app commands and actions. The interactive card tracks the last
// command label clicked; the basic card just renders the bar.
func command_bar_page(cx: RenderCx): Element {
    let (status, setStatus) = cx.useState<String>("Choose a command")

    let interactiveBar = command_bar(commandBarCommands())
        .onClick({ label: String => setStatus.call("Last command: ${label}") })

    let interactiveSample = vstack([
        interactiveBar.toElement(),
        text_block(status).opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    let basicSample = command_bar(commandBarCommands()).toElement()

    page_content(
        "CommandBar",
        "A toolbar for app commands and actions.",
        [
            sample_card(
                "Interactive CommandBar",
                interactiveSample,
                #"command_bar(commands).onClick({ label => setStatus.call("Last command: ${label}") })"#
            ),
            sample_card(
                "Basic CommandBar",
                basicSample,
                #"command_bar([CommandBarCommandDef.Button(label, icon)])"#
            )
        ]
    )
}

// The shared Add / Edit / Delete command set used by both CommandBar cards.
func commandBarCommands(): ArrayList<CommandBarCommandDef> {
    ArrayList<CommandBarCommandDef>([
        CommandBarCommandDef.Button("Add", Some(SymbolGlyph.Add)),
        CommandBarCommandDef.Button("Edit", Some(SymbolGlyph.Edit)),
        CommandBarCommandDef.Button("Delete", Some(SymbolGlyph.Delete))
    ])
}

let commandBarPageToken = newComponentTypeToken()
