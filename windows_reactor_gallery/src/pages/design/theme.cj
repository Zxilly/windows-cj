package windows_reactor_gallery.pages.design

import std.collection.*
import windows_reactor.core.*
import windows_reactor_gallery.shared.*

let themePageToken = newComponentTypeToken()

// ── Theme ───────────────────────────────────────────────────────────────────

func tokenRow(name: String, themeRef: ThemeRef, description: String): Element {
    hstack([
        border(Element.EmptyEl)
            .backgroundTheme(themeRef)
            .width(22.0)
            .height(22.0)
            .cornerRadius(4.0)
            .toElement(),
        vstack([
            text_block("ThemeRef::${name}").fontSize(13.0).bold().toElement(),
            text_block(description).fontSize(12.0).opacity(0.6).toElement()
        ]).spacing(2.0).toElement()
    ]).spacing(8.0).toElement()
}

func statusRow(name: String, fg: ThemeRef, bg: ThemeRef): Element {
    hstack([
        border(
            text_block(name).fontSize(12.0).foregroundTheme(fg).padding(Thickness.xy(8.0, 4.0)).toElement()
        )
            .backgroundTheme(bg)
            .cornerRadius(4.0)
            .toElement()
    ]).toElement()
}

func strokeRow(name: String): Element {
    hstack([
        border(Element.EmptyEl)
            .width(46.0)
            .height(22.0)
            .cornerRadius(4.0)
            .borderBrush(BrushBinding.ofColor(neutralStroke))
            .borderThickness(Thickness.uniform(1.0))
            .toElement(),
        text_block("ThemeRef::${name}").fontSize(13.0).toElement()
    ]).spacing(8.0).toElement()
}

func theme_page(): Element {
    pageComponent(themePageToken, { _: RenderCx =>
        let cardTokens = sample_card(
            "Theme Token Reference",
            vstack([
                text_block("Use ThemeRef variants to reference system brushes that automatically adapt to the active theme.")
                    .opacity(0.6).fontSize(13.0).toElement(),
                tokenRow("Accent", ThemeRef.Accent, "Brand accent color"),
                tokenRow("CardBackground", ThemeRef.CardBackground, "Card surfaces"),
                tokenRow("SubtleFill", ThemeRef.SubtleFill, "Subtle backgrounds"),
                tokenRow("LayerFill", ThemeRef.LayerFill, "Floating surfaces"),
                tokenRow("SolidBackground", ThemeRef.SolidBackground, "Page background")
            ]).spacing(8.0).toElement(),
            "// Use theme references for adaptive colors:\ntext_block(\"Hello\").foregroundTheme(ThemeRef.PrimaryText)\nvstack([...]).backgroundTheme(ThemeRef.CardBackground)"
        )

        let cardText = sample_card(
            "Text Theme Tokens",
            vstack([
                text_block("Primary text").foregroundTheme(ThemeRef.PrimaryText).toElement(),
                text_block("Secondary text").foregroundTheme(ThemeRef.SecondaryText).toElement(),
                text_block("Tertiary text").foregroundTheme(ThemeRef.TertiaryText).toElement(),
                text_block("Disabled text").foregroundTheme(ThemeRef.DisabledText).toElement(),
                text_block("Accent text").foregroundTheme(ThemeRef.AccentText).toElement()
            ]).spacing(4.0).toElement(),
            "text_block(\"Primary\").foregroundTheme(ThemeRef.PrimaryText)\ntext_block(\"Secondary\").foregroundTheme(ThemeRef.SecondaryText)\ntext_block(\"Accent\").foregroundTheme(ThemeRef.AccentText)"
        )

        let cardStatus = sample_card(
            "System Status Colors",
            vstack([
                statusRow("Attention", ThemeRef.SystemAttention, ThemeRef.SystemAttentionBackground),
                statusRow("Success", ThemeRef.SystemSuccess, ThemeRef.SystemSuccessBackground),
                statusRow("Caution", ThemeRef.SystemCaution, ThemeRef.SystemCautionBackground),
                statusRow("Critical", ThemeRef.SystemCritical, ThemeRef.SystemCriticalBackground)
            ]).spacing(8.0).toElement(),
            "// System status colors:\nThemeRef.SystemSuccess              // foreground\nThemeRef.SystemSuccessBackground    // background"
        )

        let cardStroke = sample_card(
            "Stroke Tokens",
            vstack([
                strokeRow("CardStroke"),
                strokeRow("SurfaceStroke"),
                strokeRow("DividerStroke"),
                strokeRow("ControlStroke")
            ]).spacing(8.0).toElement(),
            "border(content)\n    .borderBrush(BrushBinding.ofTheme(ThemeRef.CardStroke))\n    .borderThickness(Thickness.uniform(1.0))"
        )

        page_content(
            "Theme",
            "Guidance on applying light, dark, and high-contrast themes using WinUI theme resources.",
            [cardTokens, cardText, cardStatus, cardStroke]
        )
    })
}
