package windows_reactor_gallery.pages.status

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── ToolTip ──────────────────────────────────────────────────────────────────

let toolTipPageToken = newComponentTypeToken()

func tool_tip_page(): Element {
    pageComponent(toolTipPageToken, { cx: RenderCx =>
        let (hoverCount, setHoverCount) = cx.useState<Int64>(0)

        // Rich tooltip content. There is no dedicated `.tooltip_with`/rich
        // builder method on Button, so the rich Tooltip is attached by writing
        // the shared Modifiers.tooltip slot directly (the lowered-element
        // equivalent of a builder call) — see atGridRow in controls.cj for the
        // same pattern of mutating a widget's live Modifiers.
        let richTooltip = Tooltip.rich(
            vstack([
                text_block("Interactive tooltip").bold().toElement(),
                text_block("Hover to inspect the tooltip, then click to log another visit.").toElement(),
                text_block("Hover count: ${hoverCount}").opacity(0.6).toElement()
            ]).spacing(4.0).toElement()
        )

        let hoverTarget = button("Hover target").onClick({ => setHoverCount.call(hoverCount + 1) })
        hoverTarget.mods.tooltip = Some(richTooltip)

        page_content(
            "ToolTip",
            "A popup with helpful text on hover.",
            [
                sample_card(
                    "Interactive ToolTip",
                    vstack([
                        hoverTarget.toElement(),
                        text_block("Hover count: ${hoverCount}").opacity(0.6).toElement()
                    ]).spacing(8.0).toElement(),
                    "button(\"Hover target\")\n    .tooltip(Tooltip.rich(content))\n    .onClick(...)"
                ),
                sample_card(
                    "Button with ToolTip",
                    button("Hover me").tooltip("This is a helpful tooltip").toElement(),
                    "button(\"Hover me\").tooltip(\"This is a helpful tooltip\")"
                ),
                sample_card(
                    "Multiple Controls with Tooltips",
                    hstack([
                        button("Save")
                            .withIcon(SymbolGlyph.Save)
                            .tooltip("Save the file")
                            .toElement(),
                        button("Copy")
                            .withIcon(SymbolGlyph.Copy)
                            .tooltip("Copy to clipboard")
                            .toElement(),
                        button("Delete")
                            .withIcon(SymbolGlyph.Delete)
                            .tooltip("Delete selected item")
                            .toElement()
                    ]).spacing(8.0).toElement(),
                    "button(\"Save\").withIcon(SymbolGlyph.Save).tooltip(\"Save the file\")"
                )
            ]
        )
    })
}
