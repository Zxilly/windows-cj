package windows_reactor.winui

import windows_reactor.core.{Prop, PropValue}
import windows_core.{HString}
import windows_common.Microsoft.UI.Xaml.Media.Brush as XamlBrush
import windows_common.impl.{
    Microsoft_UI_Xaml_TextWrapping_Wrap,
    Microsoft_UI_Xaml_TextWrapping_NoWrap
}

// Per-family property setters for the text-display controls (TextBlock,
// RichTextBlock). The generic FrameworkElement / UIElement props, the font
// multi-interface probe (FontSize/FontWeight/FontFamily), all Attached* statics
// and Resources are handled in backend.cj before this function is reached; only
// the family-specific props land here. Returns true when the prop was consumed.
//
// Ported props (mirrors the set_prop arms for Handle::TextBlock / Handle::RichTextBlock):
//   - Text                  → TextBlock.Text (HString); RichTextBlock has no plain
//                             Text setter (its content is set through the separate
//                             setRichTextParagraphs backend path, not a prop).
//   - Foreground            → TextBlock / RichTextBlock high-level Foreground prop
//                             (BrushV sets a SolidColorBrush; Unset clears to null).
//   - Background            → TextBlock / RichTextBlock: consumed no-op (text
//                             controls have no Background surface; matches the
//                             reference arm that returns Ok(()) without effect).
//   - IsTextSelectionEnabled → RichTextBlock.IsTextSelectionEnabled (Bool).
//   - TextWrappingWrap       → TextBlock / RichTextBlock TextWrapping mapped to
//                             Wrap when true, NoWrap when false.
func applyTextProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        case Text => match ((handle, value)) {
            case (TextBlockH(tb), Str(s)) =>
                tb.Text = HString(s)
                true
            case _ => false
        }
        case Foreground => match ((handle, value)) {
            case (TextBlockH(tb), BrushV(b)) =>
                tb.Foreground = solidBrush(b)
                true
            case (RichTextBlockH(rtb), BrushV(b)) =>
                rtb.Foreground = solidBrush(b)
                true
            case (TextBlockH(tb), Unset) =>
                tb.Foreground = nullBrush()
                true
            case (RichTextBlockH(rtb), Unset) =>
                rtb.Foreground = nullBrush()
                true
            case _ => false
        }
        case Background => match ((handle, value)) {
            // Text controls have no Background surface — the reference consumes the
            // Brush value as a no-op (returns Ok(())). Mirror that: consumed, no effect.
            case (TextBlockH(_), BrushV(_)) => true
            case (RichTextBlockH(_), BrushV(_)) => true
            case _ => false
        }
        case IsTextSelectionEnabled => match ((handle, value)) {
            case (RichTextBlockH(rtb), BoolV(v)) =>
                rtb.IsTextSelectionEnabled = v
                true
            case _ => false
        }
        case TextWrappingWrap => match ((handle, value)) {
            case (TextBlockH(tb), BoolV(v)) =>
                tb.TextWrapping = if (v) {
                    Microsoft_UI_Xaml_TextWrapping_Wrap
                } else {
                    Microsoft_UI_Xaml_TextWrapping_NoWrap
                }
                true
            case (RichTextBlockH(rtb), BoolV(v)) =>
                rtb.TextWrapping = if (v) {
                    Microsoft_UI_Xaml_TextWrapping_Wrap
                } else {
                    Microsoft_UI_Xaml_TextWrapping_NoWrap
                }
                true
            case _ => false
        }
        case _ => false
    }
}

// A null-raw (non-owning) Brush, used to clear a Foreground back to its default
// (equivalent to put_Foreground(None) on the projection). The setter receives a
// null projection pointer which the XAML ABI interprets as "no brush".
func nullBrush(): XamlBrush {
    XamlBrush.viewOf(CPointer<Unit>())
}
