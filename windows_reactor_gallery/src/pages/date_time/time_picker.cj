package windows_reactor_gallery.pages.date_time

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── TimePicker ──────────────────────────────────────────────────────────────

let timePickerPageToken = newComponentTypeToken()

func timePickerPage(cx: RenderCx): Element {
    let (selectedTime, setSelectedTime) = cx.useState<String>("No time selected")

    page_content(
        "TimePicker",
        "Pick a time using spinners.",
        [
            sample_card(
                "Basic TimePicker",
                vstack([
                    time_picker()
                        .headerOf("Select time")
                        .onChanged({ time: ReactorTimeSpan =>
                            // TimeSpan.Duration is in 100ns ticks: 36e9/hour, 6e8/minute.
                            let hours = time.Duration / 36000000000
                            let minutes = (time.Duration / 600000000) % 60
                            setSelectedTime.call("Selected: ${pad2(hours)}:${pad2(minutes)}")
                        })
                        .toElement(),
                    text_block(selectedTime).opacity(0.6).toElement()
                ])
                    .spacing(8.0)
                    .toElement(),
                "time_picker()\n    .headerOf(\"Select time\")\n    .onChanged(|time| setSelectedTime.call(...))"
            ),
            sample_card(
                "15-Minute Increments",
                time_picker()
                    .headerOf("Meeting time")
                    .minuteIncrementOf(15)
                    .toElement(),
                "time_picker().headerOf(\"Meeting time\").minuteIncrementOf(15)"
            )
        ]
    )
}
