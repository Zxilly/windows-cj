package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// CheckBox
// ============================================================================
let checkBoxPageToken = newComponentTypeToken()

func checkBoxPage(cx: RenderCx): Element {
    let (accepted, setAccepted) = cx.useState<Bool>(false)
    let (emailOptIn, setEmail) = cx.useState<Bool>(true)
    let (smsOptIn, setSms) = cx.useState<Bool>(false)
    let (pushOptIn, setPush) = cx.useState<Bool>(true)

    var activeCount = 0
    if (emailOptIn) { activeCount++ }
    if (smsOptIn) { activeCount++ }
    if (pushOptIn) { activeCount++ }

    let acceptedText = if (accepted) { "Accepted \u{2713}" } else { "Not yet accepted" }

    page_content(
        "CheckBox",
        "A control that a user can select or clear.",
        [
            sample_card(
                "Basic CheckBox",
                vstack([
                    check_box(accepted)
                        .label("I accept the terms and conditions")
                        .onChanged({ v: Bool => setAccepted.call(v) })
                        .toElement(),
                    text_block(acceptedText).opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "check_box(checked).label(\"I accept\").onChanged({ v => set.call(v) })"
            ),
            sample_card(
                "Notification Preferences",
                vstack([
                    text_block("Choose your notification channels:").bold().toElement(),
                    check_box(emailOptIn).label("Email notifications").onChanged({ v: Bool => setEmail.call(v) }).toElement(),
                    check_box(smsOptIn).label("SMS notifications").onChanged({ v: Bool => setSms.call(v) }).toElement(),
                    check_box(pushOptIn).label("Push notifications").onChanged({ v: Bool => setPush.call(v) }).toElement(),
                    text_block("${activeCount} channel(s) active").opacity(0.6).toElement()
                ]).spacing(6.0).toElement(),
                "check_box(email).label(\"Email\").onChanged(handler)\ncheck_box(sms).label(\"SMS\").onChanged(handler)\ncheck_box(push).label(\"Push\").onChanged(handler)"
            ),
            sample_card(
                "Disabled States",
                vstack([
                    check_box(true).label("Always enabled (checked, disabled)").enabled(false).toElement(),
                    check_box(false).label("Always disabled (unchecked, disabled)").enabled(false).toElement()
                ]).spacing(6.0).toElement(),
                "check_box(true).label(\"Locked on\").enabled(false)"
            )
        ]
    )
}
