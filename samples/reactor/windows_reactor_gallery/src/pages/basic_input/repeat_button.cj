package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// RepeatButton
// ============================================================================
let repeatButtonPageToken = newComponentTypeToken()

func repeatButtonPage(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int32>(0)
    let (fastCount, setFast) = cx.useState<Int32>(0)

    page_content(
        "RepeatButton",
        "A button that raises click events repeatedly while pressed.",
        [
            sample_card(
                "Basic RepeatButton",
                vstack([
                    repeat_button("Hold me").onClick({ => setCount.call(count + 1) }).toElement(),
                    text_block("Count: ${count}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "repeat_button(\"Hold me\").onClick(handler)"
            ),
            sample_card(
                "Fast Repeat (50ms interval)",
                vstack([
                    repeat_button("Fast +1")
                        .delay(200)
                        .interval(50)
                        .onClick({ => setFast.call(fastCount + 1) })
                        .toElement(),
                    text_block("Fast count: ${fastCount}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "repeat_button(\"Fast\").delay(200).interval(50).onClick(handler)"
            )
        ]
    )
}
