package windows_reactor_gallery.pages.text

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let autoSuggestBoxPageToken = newComponentTypeToken()

// ── AutoSuggestBox ───────────────────────────────────────────────────────────
// Text input that surfaces filtered suggestions as the query changes.
func autoSuggestBoxPage(cx: RenderCx): Element {
    let (query, setQuery) = cx.useState<String>("")

    let allFruits = ["Apple", "Banana", "Cherry", "Date", "Elderberry"]
    let needle = asciiLower(query)
    let suggestions = ArrayList<String>()
    for (fruit in allFruits) {
        if (query.isEmpty() || asciiLower(fruit).contains(needle)) {
            suggestions.add(fruit)
        }
    }

    let demo = vstack([
        auto_suggest_box(query)
            .itemsOf(suggestions)
            .placeholderOf("Search fruits...")
            .onTextChanged({ s: String => setQuery.call(s) })
            .toElement(),
        text_block("Query: \"${query}\"").opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    page_content(
        "AutoSuggestBox",
        "Text input that shows suggestions as you type.",
        [
            sample_card(
                "Basic AutoSuggestBox",
                demo,
                "auto_suggest_box(query).itemsOf(suggestions).onTextChanged(handler)"
            )
        ]
    )
}
