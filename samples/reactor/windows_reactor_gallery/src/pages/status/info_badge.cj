package windows_reactor_gallery.pages.status

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── InfoBadge ────────────────────────────────────────────────────────────────

let infoBadgePageToken = newComponentTypeToken()

func info_badge_page(): Element {
    pageComponent(infoBadgePageToken, { cx: RenderCx =>
        let (count, setCount) = cx.useState<Int64>(3)

        page_content(
            "InfoBadge",
            "A small indicator conveying status on another element.",
            [
                sample_card(
                    "Dynamic Counter",
                    vstack([
                        hstack([
                            button("Add notification").onClick({ => setCount.call(count + 1) }).toElement(),
                            button("Clear").onClick({ => setCount.call(0) }).toElement()
                        ]).spacing(8.0).toElement(),
                        hstack([
                            InfoBadge.numeric(Int32(count)).toElement(),
                            text_block("${count} unread").opacity(0.6).toElement()
                        ]).spacing(8.0).toElement()
                    ]).spacing(12.0).toElement(),
                    "InfoBadge.numeric(count) // updates reactively"
                ),
                sample_card(
                    "Numeric InfoBadge",
                    hstack([
                        InfoBadge.numeric(1).toElement(),
                        InfoBadge.numeric(12).toElement(),
                        InfoBadge.numeric(99).toElement()
                    ]).spacing(16.0).toElement(),
                    "InfoBadge.numeric(1), InfoBadge.numeric(99)"
                ),
                sample_card(
                    "Dot InfoBadge",
                    hstack([
                        button("Notifications").withIcon(SymbolGlyph.Mail).toElement(),
                        InfoBadge.dot().toElement()
                    ]).spacing(8.0).toElement(),
                    "InfoBadge.dot() // compact presence indicator"
                )
            ]
        )
    })
}
