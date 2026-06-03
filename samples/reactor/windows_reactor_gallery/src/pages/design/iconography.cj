package windows_reactor_gallery.pages.design

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let iconographyPageToken = newComponentTypeToken()

// ── Iconography ────────────────────────────────────────────────────────────────

func iconography_page(): Element {
    pageComponent(iconographyPageToken, { _: RenderCx =>
        let icons: Array<(String, SymbolGlyph)> = [
            ("Home", SymbolGlyph.Home),
            ("Setting", SymbolGlyph.Setting),
            ("Find", SymbolGlyph.Find),
            ("Mail", SymbolGlyph.Mail),
            ("Camera", SymbolGlyph.Camera),
            ("Edit", SymbolGlyph.Edit),
            ("Favorite", SymbolGlyph.Favorite),
            ("Flag", SymbolGlyph.Flag),
            ("World", SymbolGlyph.World),
            ("Help", SymbolGlyph.Help),
            ("More", SymbolGlyph.More),
            ("People", SymbolGlyph.People),
            ("Add", SymbolGlyph.Add),
            ("Delete", SymbolGlyph.Delete),
            ("Save", SymbolGlyph.Save),
            ("Back", SymbolGlyph.Back)
        ]

        let cards = ArrayList<Element>()
        var index = 0
        for (entry in icons) {
            let name = entry[0]
            let glyph = entry[1]
            let card = border(
                vstack([
                    button(name).withIcon(glyph).toElement(),
                    text_block(name).fontSize(11.0).opacity(0.7).toElement()
                ]).spacing(8.0).toElement()
            )
                .backgroundTheme(ThemeRef.CardBackground)
                .borderBrush(BrushBinding.ofColor(Color.rgb(160u8, 160u8, 160u8)))
                .borderThickness(Thickness.uniform(1.0))
                .padding(Thickness.uniform(16.0))
                .cornerRadius(8.0)
                .gridRow(Int32(index / 4))
                .gridColumn(Int32(index % 4))
                .toElement()
            cards.add(card)
            index++
        }

        let rowCount = (icons.size + 3) / 4
        let rows = ArrayList<GridLength>()
        var r = 0
        while (r < rowCount) {
            rows.add(GridLength.Auto)
            r++
        }

        let iconsGrid = grid(cards.toArray())
            .rowsOf(rows.toArray())
            .columnsOf([GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0), GridLength.Star(1.0)])
            .rowSpacing(8.0)
            .columnSpacing(8.0)
            .toElement()

        page_content(
            "Iconography",
            "Segoe MDL2 Assets icons available through the SymbolGlyph enum.",
            [iconsGrid]
        )
    })
}
