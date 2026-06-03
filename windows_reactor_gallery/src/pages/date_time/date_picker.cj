package windows_reactor_gallery.pages.date_time

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── DatePicker ──────────────────────────────────────────────────────────────

let datePickerPageToken = newComponentTypeToken()

func datePickerPage(cx: RenderCx): Element {
    let (selectedDate, setSelectedDate) = cx.useState<String>("No date selected")

    page_content(
        "DatePicker",
        "Pick a date using spinners.",
        [
            sample_card(
                "Full DatePicker",
                vstack([
                    date_picker()
                        .headerOf("Select date")
                        .onChanged({ date: ReactorDateTime => setSelectedDate.call("Selected: " + formatReactorDateTime(date)) })
                        .toElement(),
                    text_block(selectedDate).opacity(0.6).toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "date_picker()\n    .headerOf(\"Select date\")\n    .onChanged(|date| setSelectedDate.call(\"Selected: {date}\"))"
            ),
            sample_card(
                "Month and Year Only",
                date_picker()
                    .headerOf("Month/Year")
                    .dayVisibleOf(false)
                    .toElement(),
                "date_picker().headerOf(\"Month/Year\").dayVisibleOf(false)"
            )
        ]
    )
}
