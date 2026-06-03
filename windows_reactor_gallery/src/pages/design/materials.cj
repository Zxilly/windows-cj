package windows_reactor_gallery.pages.design

import std.collection.*
import windows_reactor.core.*
import windows_reactor.winui.{setBackdrop, Backdrop}
import windows_reactor_gallery.shared.*

let materialsPageToken = newComponentTypeToken()

// ── Materials ────────────────────────────────────────────────────────────────

func materialDescription(selected: Int32): String {
    if (selected == 0i32) {
        "Mica samples the desktop wallpaper and applies a subtle tint. Default for app windows."
    } else if (selected == 1i32) {
        "Mica Alt uses a stronger tint - ideal for tab-based UIs and title bar regions."
    } else if (selected == 2i32) {
        "Acrylic provides translucent blur with noise. Falls back to solid when inactive."
    } else {
        "No system backdrop - solid color background."
    }
}

func materials_page(): Element {
    pageComponent(materialsPageToken, { cx: RenderCx =>
        let (selected, setSelected) = cx.useState<Int32>(0i32)

        let options: Array<String> = ["Mica", "Mica Alt", "Acrylic", "None (solid)"]

        // The reference applies the chosen window backdrop via
        // set_backdrop(Backdrop::..). We mirror that here: each selection maps to
        // a Backdrop variant and switches the live window material before updating
        // the selection state used for the description text.
        let switcher = listView<String>(options, { item: String, _idx: Int64 =>
            text_block(item).padding(Thickness.uniform(10.0)).toElement()
        })
            .withKeySelector({ item: String => item })
            .selectedIndex(selected)
            .onSelectionChanged({ index: Int32 =>
                let bd = match (index) {
                    case 0i32 => Backdrop.Mica
                    case 1i32 => Backdrop.MicaAlt
                    case 2i32 => Backdrop.Acrylic
                    case _ => Backdrop.None_
                }
                setBackdrop(bd)
                setSelected.call(index)
            })
            .height(170.0)
            .build()

        let cardSwitcher = sample_card(
            "Live Backdrop Switcher",
            vstack([
                text_block("Select a backdrop material to apply it to this window:").toElement(),
                switcher,
                text_block(materialDescription(selected)).opacity(0.7).toElement()
            ]).spacing(8.0).toElement(),
            "set_backdrop(Some(Backdrop.Mica))\nset_backdrop(Some(Backdrop.MicaAlt))\nset_backdrop(Some(Backdrop.Acrylic))\nset_backdrop(None) // remove backdrop"
        )

        let cardGuidance = sample_card(
            "Usage Guidance",
            vstack([
                text_block("\u{2022} Use Mica for primary app windows (default material)").fontSize(13.0).toElement(),
                text_block("\u{2022} Use Mica Alt for windows with prominent tabs or sections").fontSize(13.0).toElement(),
                text_block("\u{2022} Use Acrylic for transient surfaces (flyouts, dialogs)").fontSize(13.0).toElement(),
                text_block("\u{2022} All materials degrade gracefully on unsupported hardware").fontSize(13.0).toElement()
            ]).spacing(6.0).toElement(),
            "// At app level:\nApp(root).backdrop(Backdrop.Mica).run()\n\n// Runtime switching:\nset_backdrop(Some(Backdrop.Acrylic))"
        )

        page_content(
            "Materials",
            "Window backdrop materials that provide depth and visual hierarchy using translucent surfaces.",
            [cardSwitcher, cardGuidance]
        )
    })
}
