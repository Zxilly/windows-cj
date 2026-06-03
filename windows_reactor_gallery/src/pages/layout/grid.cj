package windows_reactor_gallery.pages.layout

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ── Grid ───────────────────────────────────────────────────────────────────────

let gridPageToken = newComponentTypeToken()

func gridCell(label: String, row: Int32, col: Int32): Element {
    text_block(label)
        .padding(Thickness.uniform(12.0))
        .gridRow(row)
        .gridColumn(col)
        .toElement()
}

func gridPage(cx: RenderCx): Element {
    let (wide, setWide) = cx.useState<Bool>(false)

    let basicGrid = grid([
        gridCell("1,1", 0, 0),
        gridCell("1,2", 0, 1),
        gridCell("1,3", 0, 2),
        gridCell("2,1", 1, 0),
        gridCell("2,2", 1, 1),
        gridCell("2,3", 1, 2)
    ])
        .rowsOf([GridLength.Auto, GridLength.Auto])
        .columnsOf([GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0)])
        .rowSpacing(4.0)
        .columnSpacing(4.0)
        .width(400.0)
        .toElement()

    let spanningGrid = grid([
        text_block("Header (spans 3 columns)")
            .bold()
            .padding(Thickness.uniform(12.0))
            .gridRow(0)
            .gridColumn(0)
            .gridColumnSpan(3)
            .toElement(),
        gridCell("Left", 1, 0),
        text_block("Center (spans 2)")
            .padding(Thickness.uniform(12.0))
            .gridRow(1)
            .gridColumn(1)
            .gridColumnSpan(2)
            .toElement(),
        text_block("Footer (spans 3)")
            .padding(Thickness.uniform(12.0))
            .gridRow(2)
            .gridColumn(0)
            .gridColumnSpan(3)
            .toElement()
    ])
        .rowsOf([GridLength.Auto, GridLength.Auto, GridLength.Auto])
        .columnsOf([GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0)])
        .rowSpacing(4.0)
        .columnSpacing(4.0)
        .width(400.0)
        .toElement()

    let mixedGrid = grid([
        text_block("100px").padding(Thickness.uniform(8.0)).gridRow(0).gridColumn(0).toElement(),
        text_block("1*").padding(Thickness.uniform(8.0)).gridRow(0).gridColumn(1).toElement(),
        text_block("2*").padding(Thickness.uniform(8.0)).gridRow(0).gridColumn(2).toElement()
    ])
        .rowsOf([GridLength.Auto])
        .columnsOf([GridLength.Pixel(100.0), GridLength.Star(1.0), GridLength.Star(2.0)])
        .columnSpacing(4.0)
        .width(400.0)
        .toElement()

    let switchableGrid = if (wide) {
        grid([
            text_block("Col 1").gridColumn(0).toElement(),
            text_block("Col 2").gridColumn(1).toElement(),
            text_block("Col 3").gridColumn(2).toElement()
        ])
            .rowsOf([GridLength.Auto])
            .columnsOf([GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0)])
            .columnSpacing(8.0)
            .toElement()
    } else {
        grid([
            text_block("Row 0, Col 0").gridRow(0).gridColumn(0).toElement(),
            text_block("Row 0, Col 1").gridRow(0).gridColumn(1).toElement(),
            text_block("Row 1, Col 0").gridRow(1).gridColumn(0).toElement(),
            text_block("Row 1, Col 1").gridRow(1).gridColumn(1).toElement()
        ])
            .rowsOf([GridLength.Auto, GridLength.Auto])
            .columnsOf([GridLength.Star(1.0), GridLength.Star(1.0)])
            .rowSpacing(8.0)
            .columnSpacing(8.0)
            .toElement()
    }

    page_content(
        "Grid",
        "Arranges children in rows and columns with star/pixel/auto sizing.",
        [
            sample_card(
                "Basic Grid (2×3)",
                basicGrid,
                "grid(()).rowsOf([Auto, Auto]).columnsOf([Star(1.0), Star(1.0), Star(1.0)])\n// children placed with .gridRow(r).gridColumn(c)"
            ),
            sample_card(
                "Column & Row Spanning",
                spanningGrid,
                "text_block(\"Header\").gridColumnSpan(3)\ntext_block(\"Center\").gridColumn(1).gridColumnSpan(2)"
            ),
            sample_card(
                "Mixed Sizing (Pixel + Star)",
                mixedGrid,
                "grid(()).columnsOf([Pixel(100.0), Star(1.0), Star(2.0)])\n// 100px fixed, 1* proportional, 2* double proportional"
            ),
            sample_card(
                "Switchable Layout",
                vstack([
                    toggle_switch(wide)
                        .header("Wide layout (3 columns)")
                        .onChanged({ v: Bool => setWide.call(v) })
                        .toElement(),
                    switchableGrid
                ])
                    .spacing(12.0)
                    .toElement(),
                "// Grid layout changes dynamically with state\nif wide { grid with 3 columns } else { grid with 2×2 }"
            )
        ]
    )
}
