package windows_reactor_gallery.pages.date_time

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── CalendarDatePicker ──────────────────────────────────────────────────────

let calendarDatePickerPageToken = newComponentTypeToken()

func calendarDatePickerPage(cx: RenderCx): Element {
    let (selectedDate, setSelectedDate) = cx.useState<String>("No date selected")

    page_content(
        "CalendarDatePicker",
        "Pick a date from a calendar dropdown.",
        [
            sample_card(
                "Basic CalendarDatePicker",
                vstack([
                    calendar_date_picker()
                        .headerOf("Appointment Date")
                        .placeholderTextOf("Select a date")
                        .todayHighlighted(true)
                        .onChanged({ value: ?ReactorDateTime =>
                            match (value) {
                                case Some(date) => setSelectedDate.call("Selected: " + formatReactorDateTime(date))
                                case None => setSelectedDate.call("Selection cleared")
                            }
                        })
                        .toElement(),
                    text_block(selectedDate).opacity(0.6).toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "calendar_date_picker()\n    .headerOf(\"Appointment Date\")\n    .onChanged(|value| setSelectedDate.call(...))"
            ),
            sample_card(
                "Disabled CalendarDatePicker",
                calendar_date_picker()
                    .headerOf("Locked Date")
                    .placeholderTextOf("Cannot change")
                    .enabled(false)
                    .toElement(),
                "calendar_date_picker().enabled(false)"
            )
        ]
    )
}
