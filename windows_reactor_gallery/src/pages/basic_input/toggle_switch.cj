package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// ToggleSwitch
// ============================================================================
let toggleSwitchPageToken = newComponentTypeToken()

func toggleSwitchPage(cx: RenderCx): Element {
    let (wifiOn, setWifiOn) = cx.useState<Bool>(true)
    let (notificationsOn, setNotificationsOn) = cx.useState<Bool>(false)
    let (automationEnabled, setAutomationEnabled) = cx.useState<Bool>(false)
    let (overnightUpdates, setOvernightUpdates) = cx.useState<Bool>(true)

    let wifiText = if (wifiOn) { "Wi-Fi is connected." } else { "Wi-Fi is turned off." }
    let notifText = if (notificationsOn) {
        "Priority alerts will appear on the desktop."
    } else {
        "Only badges and summaries will be shown."
    }
    let automationText = if (!automationEnabled) {
        "Turn on scheduled updates to configure this option."
    } else if (overnightUpdates) {
        "Updates will install automatically at 2:00 AM."
    } else {
        "Updates will wait for manual approval."
    }

    page_content(
        "ToggleSwitch",
        "A compact switch for turning a setting on or off with immediate feedback.",
        [
            sample_card(
                "Basic Toggle",
                vstack([
                    toggle_switch(wifiOn)
                        .onContentText("On")
                        .offContentText("Off")
                        .onChanged({ v: Bool => setWifiOn.call(v) })
                        .toElement(),
                    text_block(wifiText).opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "toggle_switch(wifiOn)\n    .onChanged(...)"
            ),
            sample_card(
                "Toggle with Header",
                vstack([
                    toggle_switch(notificationsOn)
                        .header("Notifications")
                        .onContentText("On")
                        .offContentText("Muted")
                        .onChanged({ v: Bool => setNotificationsOn.call(v) })
                        .toElement(),
                    text_block(notifText).opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "toggle_switch(notificationsOn)\n    .header(\"Notifications\")\n    .onChanged(...)"
            ),
            sample_card(
                "Disabled State",
                vstack([
                    toggle_switch(automationEnabled)
                        .header("Enable scheduled updates")
                        .onChanged({ v: Bool => setAutomationEnabled.call(v) })
                        .toElement(),
                    toggle_switch(overnightUpdates)
                        .header("Install updates overnight")
                        .enabled(automationEnabled)
                        .onChanged({ v: Bool => setOvernightUpdates.call(v) })
                        .toElement(),
                    text_block(automationText).opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "toggle_switch(overnightUpdates)\n    .enabled(automationEnabled)\n    .onChanged(...)"
            )
        ]
    )
}
