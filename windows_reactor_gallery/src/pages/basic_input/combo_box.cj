package windows_reactor_gallery.pages.basic_input

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// ComboBox
// ============================================================================
let comboBoxPageToken = newComponentTypeToken()

func comboBoxPage(cx: RenderCx): Element {
    let (selected, setSelected) = cx.useState<Int32>(-1)

    let colors = ["Red", "Green", "Blue", "Yellow"]
    let label = if (selected >= 0) {
        nth(colors, Int64(selected))
    } else {
        "(none)"
    }

    page_content(
        "ComboBox",
        "A drop-down list of items a user can select from.",
        [
            sample_card(
                "Basic ComboBox",
                vstack([
                    combo_box(toList(colors))
                        .header("Color")
                        .placeholder("Pick a color")
                        .selectedIndexOf(selected)
                        .onSelectionChanged({ i: Int32 => setSelected.call(i) })
                        .toElement(),
                    text_block("Selected: ${label}").opacity(0.6).toElement()
                ]).spacing(8.0).toElement(),
                "combo_box(colors).header(\"Color\").onSelectionChanged(handler)"
            ),
            sample_card(
                "Editable ComboBox",
                combo_box(toList(["Cat", "Dog", "Fox"]))
                    .header("Animal")
                    .placeholder("Type or pick")
                    .editable(true)
                    .toElement(),
                "combo_box(items).editable(true)"
            )
        ]
    )
}
