package windows_reactor_apps

// ============================================================================
// game_notepad — Notepad app body.
//
// Reference: apps/examples/notepad.rs
// Window title: "windows_reactor — notepad"
//
// A minimal single-surface text editor: one multiline text box bound to a
// single String state cell, stretched to fill the whole window. Typing
// updates the state; the state feeds back into the box value. There is no
// board / move / win-detection logic — the sample is purely a text surface.
// ============================================================================

import windows_reactor.core.{
    RenderCx,
    Element,
    text_box,
    HorizontalAlignment,
    VerticalAlignment
}

public func notepadApp(cx: RenderCx): Element {
    // Single source of truth: the document text.
    let (text, setText) = cx.useState<String>("")

    text_box(text)
        .multiline()
        .placeholder("Start typing\u{2026}")
        .onChanged({ v: String => setText.call(v) })
        .hAlign(HorizontalAlignment.Stretch)
        .vAlign(VerticalAlignment.Stretch)
        .toElement()
}
