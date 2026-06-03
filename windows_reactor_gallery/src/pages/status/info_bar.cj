package windows_reactor_gallery.pages.status

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── InfoBar ──────────────────────────────────────────────────────────────────

let infoBarPageToken = newComponentTypeToken()

func info_bar_page(): Element {
    pageComponent(infoBarPageToken, { cx: RenderCx =>
        let (visible, setVisible) = cx.useState<Bool>(true)

        page_content(
            "InfoBar",
            "A dismissible bar for app-level messages.",
            [
                sample_card(
                    "Toggle InfoBar",
                    vstack([
                        toggle_switch(visible)
                            .header("Show InfoBar")
                            .onChanged({ value: Bool => setVisible.call(value) })
                            .toElement(),
                        info_bar("Update available")
                            .message("A new version is ready to install.")
                            .informational()
                            .isOpenOf(visible)
                            .toElement()
                    ]).spacing(8.0).toElement(),
                    "info_bar(\"Title\").message(\"...\").isOpenOf(visible)"
                ),
                sample_card(
                    "Informational InfoBar",
                    info_bar("Update available")
                        .message("A new version is ready to install.")
                        .informational()
                        .toElement(),
                    "info_bar(\"Title\").message(\"...\").informational()"
                ),
                sample_card(
                    "Severity Variants",
                    vstack([
                        info_bar("Success")
                            .message("Operation completed.")
                            .success()
                            .toElement(),
                        info_bar("Warning")
                            .message("Check your input.")
                            .warning()
                            .toElement(),
                        info_bar("Error")
                            .message("Something went wrong.")
                            .infoBarError()
                            .toElement()
                    ]).spacing(8.0).toElement(),
                    "info_bar(\"Title\").message(\"Msg\").warning()"
                )
            ]
        )
    })
}
