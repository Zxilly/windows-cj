package windows_reactor_gallery.pages.dialogs

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let teachingTipPageToken = newComponentTypeToken()

// ── TeachingTip ────────────────────────────────────────────────────────────
func teachingTipPage(cx: RenderCx): Element {
    let (showBasic, setBasic) = cx.useState<Bool>(false)
    let (showAction, setActionOpen) = cx.useState<Bool>(false)
    let (actionCount, setCount) = cx.useState<Int64>(0)

    let basicCard = sample_card(
        "Basic TeachingTip",
        vstack([
            button("Show Tip").onClick({ => setBasic.call(true) }).toElement(),
            teaching_tip("Did you know?")
                .subtitleOf("You can customize this teaching tip with a subtitle.")
                .open(showBasic)
                .onClosed({ => setBasic.call(false) })
                .toElement()
        ]).spacing(8.0).toElement(),
        "teaching_tip(\"Title\").subtitleOf(\"...\").open(show).onClosed(handler)"
    )

    let actionCard = sample_card(
        "TeachingTip with Action",
        vstack([
            button("Show Action Tip").onClick({ => setActionOpen.call(true) }).toElement(),
            teaching_tip("Take Action")
                .subtitleOf("Click the action button to increment the counter.")
                .open(showAction)
                .actionButton("Got it!")
                .closeButton("Dismiss")
                .onActionClick({ => setCount.call(actionCount + 1) })
                .onClosed({ => setActionOpen.call(false) })
                .toElement(),
            text_block("Action clicked: ${actionCount} times").opacity(0.6).toElement()
        ]).spacing(8.0).toElement(),
        "teaching_tip(\"Title\").actionButton(\"Got it!\").onActionClick(handler)"
    )

    page_content(
        "TeachingTip",
        "A notification flyout for guiding users through features.",
        [basicCard, actionCard]
    )
}
