package windows_reactor_gallery.pages

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

// ============================================================================
// Home landing page: an intro header plus a "Browse by Category" card grid.
// Selecting a category card navigates to that category's tag.
//
// (Placeholder-stage: per-control sample pages are filled in by a later stage;
// this and settings are the only real pages in the foundation layer.)
// ============================================================================

public func home_page(onNavigate: (String) -> Unit): Element {
    let items = ArrayList<CardItem>()
    for (category in CATEGORIES) {
        let controls = controls_in_category(category)
        let imageFile = if (controls.size > 0) { controls[0].image } else { "" }
        items.add(CardItem(
            category,
            "${controls.size} controls",
            imageFile,
            category_tag(category)
        ))
    }

    let root = grid([
        vstack([
            text_block("Reactor WinUI Gallery").fontSize(28.0).bold().toElement(),
            text_block("A showcase of WinUI controls built entirely with a declarative, component-based UI framework for WinUI 3.")
                .hAlign(HorizontalAlignment.Left)
                .maxWidth(500.0)
                .opacity(0.7)
                .wrap()
                .toElement()
        ]).spacing(8.0).gridRow(0).toElement(),
        grid([
            text_block("Browse by Category").fontSize(14.0).semibold().gridRow(0).toElement(),
            atGridRow(card_grid(items, onNavigate), 1)
        ]).rowsOf([GridLength.Auto, GridLength.Star(1.0)])
            .columnsOf([GridLength.Star(1.0)])
            .rowSpacing(16.0)
            .gridRow(1)
            .toElement()
    ]).rowsOf([GridLength.Auto, GridLength.Star(1.0)])
        .columnsOf([GridLength.Star(1.0)])
        .rowSpacing(32.0)

    border(root.toElement())
        .padding(Thickness(36.0, 40.0, 36.0, 36.0))
        .toElement()
}
