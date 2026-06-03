package windows_reactor_gallery.pages.media

import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let personPicturePageToken = newComponentTypeToken()

// ── PersonPicture ──────────────────────────────────────────────────────────--
//
// A circular avatar. A ToggleSwitch flips between three avatars that derive
// their initials from display names and three avatars whose initials are
// provided directly; the helper text below updates to describe the active mode.
func personPicturePage(cx: RenderCx): Element {
    let (showDisplayNames, setShowDisplayNames) = cx.useState<Bool>(true)

    let pictures: Element = if (showDisplayNames) {
        hstack([
            person_picture().displayNameOf("Alice Smith").toElement(),
            person_picture().displayNameOf("Bob Johnson").toElement(),
            person_picture().displayNameOf("Carol Lee").toElement()
        ])
            .spacing(16.0)
            .toElement()
    } else {
        hstack([
            person_picture().initialsOf("AS").toElement(),
            person_picture().initialsOf("BJ").toElement(),
            person_picture().initialsOf("CL").toElement()
        ])
            .spacing(16.0)
            .toElement()
    }

    let helperText = if (showDisplayNames) {
        "Initials are generated from the display names."
    } else {
        "Initials can also be provided directly."
    }

    let body = vstack([
        toggle_switch(showDisplayNames)
            .header("Use display names")
            .onChanged({ value: Bool => setShowDisplayNames.call(value) })
            .toElement(),
        pictures,
        text_block(helperText).opacity(0.6).toElement()
    ])
        .spacing(12.0)
        .toElement()

    page_content(
        "PersonPicture",
        "A circular avatar for a person.",
        [sample_card(
            "Display Names or Initials",
            body,
            #"toggle_switch(mode).onChanged(...)
person_picture().displayNameOf("Alice Smith")
person_picture().initialsOf("AS")"#
        )]
    )
}
