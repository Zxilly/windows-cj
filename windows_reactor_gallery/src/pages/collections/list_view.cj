package windows_reactor_gallery.pages.collections

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let listViewPageToken = newComponentTypeToken()

// ── ListView ───────────────────────────────────────────────────────────────--
// Displays rich, scrollable collections that react to selection changes. Three
// cards: a static inbox, a contact selector, and a playlist browser.
func listViewPage(cx: RenderCx): Element {
    let (selectedContact, setSelectedContact) = cx.useState<Int64>(1)
    let (selectedPlaylist, setSelectedPlaylist) = cx.useState<Int64>(0)

    let inboxItems: Array<String> = [
        "Quarterly planning notes",
        "Design review follow-up",
        "Flight confirmation",
        "Weekly status summary",
        "Welcome to the team",
        "Shared gallery feedback"
    ]

    let contacts: Array<String> = ["Avery", "Diego", "Harper", "Mina", "Noah"]
    let contactIdx = if (selectedContact >= 0) { selectedContact } else { 0 }
    let contactLabel = if (contactIdx < contacts.size) {
        contacts[contactIdx]
    } else {
        "(none)"
    }

    let playlists: Array<String> = ["Morning Focus", "Deep Work", "Evening Reset", "Weekend Mix"]
    let playlistIdx = if (selectedPlaylist >= 0) { selectedPlaylist } else { 0 }
    let playlistLabel = if (playlistIdx < playlists.size) {
        playlists[playlistIdx]
    } else {
        "(none)"
    }

    // Card 1: Basic ListView — static rich rows.
    let basicList = listView<String>(inboxItems, { item: String, idx: Int64 =>
        vstack([
            text_block(item).bold().toElement(),
            text_block("Message #${idx + 1} \u{2022} Updated just now").opacity(0.6).toElement()
        ])
            .spacing(2.0)
            .padding(Thickness.uniform(8.0))
            .toElement()
    })
        .withKeySelector({ item: String => item })
        .height(220.0)
        .build()

    // Card 2: Selection display.
    let contactList = listView<String>(contacts, { item: String, _idx: Int64 =>
        text_block(item).padding(Thickness.uniform(10.0)).toElement()
    })
        .withKeySelector({ item: String => item })
        .selectedIndex(Int32(selectedContact))
        .onSelectionChanged({ index: Int32 => setSelectedContact.call(Int64(index)) })
        .height(180.0)
        .build()

    let contactSample = vstack([
        contactList,
        text_block("Selected contact: ${contactLabel}").opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    // Card 3: Playlist browser.
    let playlistList = listView<String>(playlists, { item: String, idx: Int64 =>
        vstack([
            text_block(item).bold().toElement(),
            text_block("${12 + idx * 5} tracks ready to play").opacity(0.6).toElement()
        ])
            .spacing(2.0)
            .padding(Thickness.uniform(10.0))
            .toElement()
    })
        .withKeySelector({ item: String => item })
        .selectedIndex(Int32(selectedPlaylist))
        .onSelectionChanged({ index: Int32 => setSelectedPlaylist.call(Int64(index)) })
        .height(200.0)
        .build()

    let playlistSample = vstack([
        playlistList,
        text_block("Now browsing: ${playlistLabel}").opacity(0.6).toElement()
    ]).spacing(8.0).toElement()

    page_content(
        "ListView",
        "Displays rich, scrollable collections that can react to selection changes.",
        [
            sample_card(
                "Basic ListView",
                basicList,
                "list_view(items, |item, idx| {\n    vstack((text_block(item.clone()).bold(), ...)).padding(Thickness::uniform(8.0))\n})"
            ),
            sample_card(
                "Selection Display",
                contactSample,
                "list_view(contacts, |item, _| text_block(item.clone()))\n    .selected_index(selected_contact)\n    .on_selection_changed(...)"
            ),
            sample_card(
                "Playlist Browser",
                playlistSample,
                "list_view(playlists, |item, idx| {\n    vstack((text_block(item.clone()).bold(), ...))\n})\n.selected_index(selected_playlist)\n.on_selection_changed(...)"
            )
        ]
    )
}
