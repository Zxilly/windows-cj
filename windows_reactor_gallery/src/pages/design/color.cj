package windows_reactor_gallery.pages.design

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let colorPageToken = newComponentTypeToken()

// Format a single byte as two upper-case hex digits.
func hexByte(value: UInt8): String {
    let digits = "0123456789ABCDEF"
    let bytes = digits.toArray()
    let hi = Int64(value / 16u8)
    let lo = Int64(value % 16u8)
    String.fromUtf8([bytes[hi], bytes[lo]])
}

// "#RRGGBB" for the given color.
func hexColor(color: Color): String {
    "#" + hexByte(color.r) + hexByte(color.g) + hexByte(color.b)
}

// ── Color ───────────────────────────────────────────────────────────────────

func color_page(): Element {
    pageComponent(colorPageToken, { _: RenderCx =>
        let swatches: Array<(String, Color)> = [
            ("Accent", Color.rgb(0u8, 120u8, 212u8)),
            ("Accent Light 1", Color.rgb(51u8, 143u8, 221u8)),
            ("Accent Light 2", Color.rgb(102u8, 167u8, 230u8)),
            ("Accent Dark 1", Color.rgb(0u8, 96u8, 170u8)),
            ("Accent Dark 2", Color.rgb(0u8, 72u8, 128u8)),
            ("Success", Color.rgb(15u8, 123u8, 15u8)),
            ("Caution", Color.rgb(157u8, 93u8, 0u8)),
            ("Critical", Color.rgb(196u8, 43u8, 28u8))
        ]

        let cards = ArrayList<Element>()
        var index = 0
        for (sw in swatches) {
            let name = sw[0]
            let color = sw[1]
            let card = border(
                vstack([
                    text_block(name).fontSize(12.0).bold().toElement(),
                    text_block(hexColor(color)).fontSize(11.0).opacity(0.7).toElement()
                ]).spacing(4.0).toElement()
            )
                .background(Brush.Solid(color))
                .padding(Thickness.uniform(16.0))
                .cornerRadius(8.0)
                .gridRow(Int32(index / 4))
                .gridColumn(Int32(index % 4))
                .toElement()
            cards.add(card)
            index++
        }

        let rowCount = (swatches.size + 3) / 4
        let rows = ArrayList<GridLength>()
        var r = 0
        while (r < rowCount) {
            rows.add(GridLength.Auto)
            r++
        }

        let colorGrid = grid(cards.toArray())
            .rowsOf(rows.toArray())
            .columnsOf([GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0)])
            .rowSpacing(8.0)
            .columnSpacing(8.0)
            .toElement()

        page_content(
            "Color",
            "System accent and semantic colors used across WinUI 3 apps.",
            [colorGrid]
        )
    })
}
