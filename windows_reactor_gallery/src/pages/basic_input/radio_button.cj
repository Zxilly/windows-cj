package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// RadioButton (RadioButtons group)
// ============================================================================
let radioButtonPageToken = newComponentTypeToken()

func radioButtonPage(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int32>(0)

    let options = ["Option A", "Option B", "Option C"]
    let label = nth(options, Int64(selected))

    page_content(
        "RadioButton",
        "Select one option from a group.",
        [
            sample_card(
                "Basic RadioButtons",
                vstack([
                    radio_buttons(toList(options))
                        .header("Pick one")
                        .selectedIndexOf(selected)
                        .onSelectionChanged({ i: Int32 => setSelected.call(i) })
                        .toElement(),
                    text_block("Selected: ${label}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "radio_buttons([\"A\", \"B\", \"C\"]).selectedIndexOf(idx).onSelectionChanged(handler)"
            ),
            sample_card(
                "RadioButtons with Header",
                radio_buttons(toList(["Small", "Medium", "Large", "Extra Large"]))
                    .header("T-shirt size")
                    .selectedIndexOf(1)
                    .toElement(),
                "radio_buttons(sizes).header(\"T-shirt size\").selectedIndexOf(1)"
            )
        ]
    )
}
