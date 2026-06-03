package windows_reactor_gallery.pages.date_time

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── CalendarView ────────────────────────────────────────────────────────────

let calendarViewPageToken = newComponentTypeToken()

func calendarViewPage(cx: RenderCx): Element {
    let (todayHighlighted, setTodayHighlighted) = cx.useState<Bool>(true)
    let (selectionChanges, setSelectionChanges) = cx.useState<Int64>(0)

    page_content(
        "CalendarView",
        "A calendar display for selecting a date.",
        [
            sample_card(
                "Basic CalendarView",
                vstack([
                    toggle_switch(todayHighlighted)
                        .header("Highlight today")
                        .onChanged({ value: Bool => setTodayHighlighted.call(value) })
                        .toElement(),
                    calendar_view()
                        .todayHighlighted(todayHighlighted)
                        .onChanged({ => setSelectionChanges.call(selectionChanges + 1) })
                        .toElement(),
                    text_block("Selection changed ${selectionChanges} time(s)")
                        .opacity(0.6)
                        .toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "toggle_switch(today_highlighted).onChanged(...)\ncalendar_view()\n    .todayHighlighted(today_highlighted)\n    .onChanged(|| setSelectionChanges.call(selectionChanges + 1))"
            ),
            sample_card(
                "CalendarView without Labels",
                calendar_view()
                    .todayHighlighted(true)
                    .groupLabelVisible(false)
                    .toElement(),
                "calendar_view().groupLabelVisible(false)"
            )
        ]
    )
}
