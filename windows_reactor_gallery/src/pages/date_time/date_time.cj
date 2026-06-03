package windows_reactor_gallery.pages.date_time

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Date and Time category pages.
//
// routeDateTime maps each Date and Time control tag to its page component.
// Each page fn is `func <name>Page(cx): Element` rendered through a
// pageComponent(token, { cx => ... }) so it owns an independent hook scope;
// one module-scope token per page is minted via newComponentTypeToken().
//
//   tag                    page fn                  file
//   --------------------   ----------------------   ------------------------
//   calendar-date-picker   calendarDatePickerPage   calendar_date_picker.cj
//   calendar-view          calendarViewPage         calendar_view.cj
//   date-picker            datePickerPage           date_picker.cj
//   time-picker            timePickerPage           time_picker.cj
// ============================================================================

// Zero-pad an Int64 to width 2 (e.g. 7 -> "07"), matching the reference's
// `{value:02}` time formatting. Shared by time_picker.cj.
func pad2(value: Int64): String {
    "${value}".padStart(2, padding: "0")
}

// ── Tag dispatch ────────────────────────────────────────────────────────────

public func routeDateTime(tag: String): ?Element {
    match (tag) {
        case "calendar-date-picker" => Some(pageComponent(calendarDatePickerPageToken, calendarDatePickerPage))
        case "calendar-view" => Some(pageComponent(calendarViewPageToken, calendarViewPage))
        case "date-picker" => Some(pageComponent(datePickerPageToken, datePickerPage))
        case "time-picker" => Some(pageComponent(timePickerPageToken, timePickerPage))
        case _ => None
    }
}
