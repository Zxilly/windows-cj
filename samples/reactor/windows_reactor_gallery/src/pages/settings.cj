package windows_reactor_gallery.pages

import std.collection.*
import windows_reactor.core.*

// ============================================================================
// Settings page: an about/info surface. A static read-only page in the
// foundation layer (no interactive settings yet).
// ============================================================================

public func settings_page(): Element {
    let content = vstack([
        text_block("Settings").fontSize(28.0).bold().toElement(),
        vstack([
            text_block("About this app").bold().toElement(),
            vstack([
                text_block("WinUI Gallery (Reactor)").bold().toElement(),
                text_block("Version 0.1.0").fontSize(12.0).opacity(0.6).toElement()
            ]).spacing(2.0).toElement(),
            text_block("This app is built with a declarative component-based UI framework for WinUI 3. It demonstrates how to recreate the WinUI Gallery experience using reactive hooks and a composable element DSL.")
                .fontSize(13.0)
                .wrap()
                .opacity(0.6)
                .toElement()
        ]).spacing(12.0).padding(Thickness.uniform(20.0)).toElement(),
        vstack([
            text_block("Built with the reactor model").bold().toElement(),
            text_block("Framework: declarative element DSL").fontSize(13.0).toElement(),
            text_block("Platform: WinUI 3 / Windows App SDK").fontSize(13.0).toElement(),
            text_block("Rendering: virtual DOM reconciler").fontSize(13.0).toElement(),
            text_block("State: hook-based state management").fontSize(13.0).toElement()
        ]).spacing(8.0).padding(Thickness.uniform(20.0)).toElement()
    ])
        .spacing(24.0)
        .margin(Thickness(36.0, 24.0, 36.0, 36.0))
        .hAlign(HorizontalAlignment.Stretch)

    scroll_view(content.toElement()).toElement()
}
