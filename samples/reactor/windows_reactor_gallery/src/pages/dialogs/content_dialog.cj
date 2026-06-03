package windows_reactor_gallery.pages.dialogs

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let contentDialogPageToken = newComponentTypeToken()

// ── ContentDialog ──────────────────────────────────────────────────────────
func contentDialogPage(cx: RenderCx): Element {
    let (open, setOpen) = cx.useState<Bool>(false)
    let (resultText, setResult) = cx.useState<String>("(none)")
    let (open2, setOpen2) = cx.useState<Bool>(false)

    let basicCard = sample_card(
        "Basic Confirmation Dialog",
        vstack([
            button("Show Dialog").onClick({ => setOpen.call(true) }).toElement(),
            content_dialog("Confirm Action")
                .contentOf("Are you sure you want to proceed?")
                .primaryButtonTextOf("Yes")
                .closeButtonTextOf("No")
                .open(open)
                .onClosed({ r: ContentDialogResult =>
                    setOpen.call(false)
                    let s = match (r) {
                        case Primary => "Primary (Yes)"
                        case Secondary => "Secondary"
                        case NoneRes => "Closed (No)"
                    }
                    setResult.call(s)
                })
                .toElement(),
            text_block("Last result: ${resultText}").opacity(0.6).toElement()
        ]).spacing(8.0).toElement(),
        "content_dialog(\"Title\").contentOf(\"...\").primaryButtonTextOf(\"Yes\").open(open)"
    )

    let threeButtonCard = sample_card(
        "Three-Button Dialog",
        vstack([
            button("Show Three-Button").onClick({ => setOpen2.call(true) }).toElement(),
            content_dialog("Save Changes?")
                .contentOf("You have unsaved changes. What would you like to do?")
                .primaryButtonTextOf("Save")
                .secondaryButtonTextOf("Don't Save")
                .closeButtonTextOf("Cancel")
                .open(open2)
                .onClosed({ _: ContentDialogResult => setOpen2.call(false) })
                .toElement()
        ]).spacing(8.0).toElement(),
        "content_dialog(\"Save?\").primaryButtonTextOf(\"Save\").secondaryButtonTextOf(\"Don't Save\")"
    )

    page_content(
        "ContentDialog",
        "A modal dialog box with content and action buttons.",
        [basicCard, threeButtonCard]
    )
}
