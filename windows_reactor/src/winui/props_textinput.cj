package windows_reactor.winui

import windows_reactor.core.{Prop, PropValue}
import windows_reactor.core.PasswordRevealMode as ReactorPasswordRevealMode
import windows_core.{HString, OutSlot}
import windows_reactor.bindings.{TextSetOptions_None as Microsoft_UI_Text_TextSetOptions_None, TextGetOptions_None as Microsoft_UI_Text_TextGetOptions_None}
import windows_reactor.bindings.{TextWrapping_Wrap as Microsoft_UI_Xaml_TextWrapping_Wrap, TextWrapping_NoWrap as Microsoft_UI_Xaml_TextWrapping_NoWrap}
import windows_reactor.bindings.{PasswordRevealMode_Peek as Microsoft_UI_Xaml_Controls_PasswordRevealMode_Peek, PasswordRevealMode_Hidden as Microsoft_UI_Xaml_Controls_PasswordRevealMode_Hidden, PasswordRevealMode_Visible as Microsoft_UI_Xaml_Controls_PasswordRevealMode_Visible}
// Depth>0 while the reactor is programmatically setting RichEditBox text (controlled
// value). RichEditBox raises TextChanged synchronously from SetText; the TextChanged
// delegate (event_text.cj) skips while this is >0 so a programmatic set never re-enters
// the reactor (onChanged -> setState -> render) and fail-fasts WinUIEdit. WinUI is STA.
var richEditSuppressDepth: Int64 = 0
func richEditTextChangeSuppressed(): Bool { richEditSuppressDepth > 0 }

// Per-family property setters for editable text-input controls (TextBox,
// PasswordBox, RichEditBox). Returns true when the prop was consumed.
//
// Ported from the reference set_prop arms (Handle::TextBox / PasswordBox /
// RichEditBox). The shared FrameworkElement/UIElement/font/attached/resources
// props are handled in backend.cj before this is reached; only the family
// props land here.
//
// Projection ABI (spec §8.1): every member used here is a high-level `mut prop`
// on the variant-bound projection class (verified against the windows_sys
// projections): TextBox.{Text, PlaceholderText, Header, AcceptsReturn,
// TextWrapping, IsReadOnly(unused)}, PasswordBox.{Password, PlaceholderText,
// Header, PasswordRevealMode, IsPasswordRevealButtonEnabled}, RichEditBox.{
// Document (getter) → SetText, PlaceholderText, Header, IsReadOnly}. IsEnabled is
// QI'd to the high-level Control surface (it is not on the leaf classes). The
// Header prop takes an IInspectable; the reference wraps the header string in a
// TextBlock, so we mirror that (string_as_textblock equivalent).
func applyTextInputProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        // ── TextBox ──────────────────────────────────────────────────────────
        case TextBoxValue => match ((handle, value)) {
            case (TextBoxH(t), Str(s)) =>
                // Skip the round-trip when the live text already matches (the
                // reference guards against re-entrant TextChanged notifications).
                let cur = t.Text
                try {
                    if (cur.toString() == s) {
                        return true
                    }
                } finally {
                    cur.close()
                }
                t.Text = HString(s)
                true
            case _ => false
        }
        case AcceptsReturn => match ((handle, value)) {
            case (TextBoxH(t), BoolV(v)) =>
                t.AcceptsReturn = v
                true
            case (TextBoxH(t), Unset) =>
                t.AcceptsReturn = false
                true
            case _ => false
        }
        // ── PasswordBox ──────────────────────────────────────────────────────
        case PasswordValue => match ((handle, value)) {
            case (PasswordBoxH(p), Str(s)) =>
                let cur = p.Password
                try {
                    if (cur.toString() == s) {
                        return true
                    }
                } finally {
                    cur.close()
                }
                p.Password = HString(s)
                true
            case (PasswordBoxH(p), Unset) =>
                p.Password = HString("")
                true
            case _ => false
        }
        case PasswordRevealMode => match ((handle, value)) {
            case (PasswordBoxH(p), PasswordRevealModeV(m)) =>
                p.PasswordRevealMode = match (m) {
                    case ReactorPasswordRevealMode.Peek => Microsoft_UI_Xaml_Controls_PasswordRevealMode_Peek
                    case ReactorPasswordRevealMode.Hidden => Microsoft_UI_Xaml_Controls_PasswordRevealMode_Hidden
                    case ReactorPasswordRevealMode.Visible => Microsoft_UI_Xaml_Controls_PasswordRevealMode_Visible
                }
                true
            case _ => false
        }
        case IsPasswordRevealButtonEnabled => match ((handle, value)) {
            case (PasswordBoxH(p), BoolV(v)) =>
                p.IsPasswordRevealButtonEnabled = v
                true
            case (PasswordBoxH(p), Unset) =>
                p.IsPasswordRevealButtonEnabled = true
                true
            case _ => false
        }
        // ── RichEditBox ──────────────────────────────────────────────────────
        case RichEditBoxText => match ((handle, value)) {
            case (RichEditBoxH(reb), Str(s)) =>
                let doc = reb.Document
                try {
                    // Skip SetText when the document already holds this value. RichEditBox
                    // raises TextChanged SYNCHRONOUSLY from SetText; the reactor's
                    // controlled-value pattern re-applies the text every render, so an
                    // unconditional SetText fires TextChanged -> onChanged -> setState ->
                    // render -> SetText … a reentrant loop that fail-fasts WinUI
                    // (0xC000027B). Comparing first breaks the loop. The comparison is RAW
                    // (no trimming): RichEditBox.GetText always appends a trailing CR, and
                    // the read path (event_text.cj senderRichEditBoxText) stores that same
                    // CR-bearing string verbatim, so the controlled value the reactor feeds
                    // back already carries the CR — current == s is symmetric and converges.
                    // Trimming only one side would make the guard never match (CR accretes,
                    // count inflates, runaway). Mirrors the reference raw compare.
                    var current = ""
                    let slot = OutSlot<HString>()
                    try {
                        doc.GetText(Microsoft_UI_Text_TextGetOptions_None, slot)
                        match (slot.get()) {
                            case Some(cur) => current = cur.toString()
                            case None => ()
                        }
                    } finally {
                        slot.close()
                    }
                    if (current != s) {
                        let hs = HString(s)
                        // Suppress the synchronous TextChanged that SetText raises: it is a
                        // programmatic (controlled-value) change, not user input, and letting
                        // it run onChanged -> setState -> render mid-render fail-fasts
                        // WinUIEdit (0xC000027B). The TextChanged handler (event_text.cj)
                        // skips while suppressed. STA single-threaded, so a plain counter is
                        // safe.
                        richEditSuppressDepth += 1
                        try {
                            doc.SetText(Microsoft_UI_Text_TextSetOptions_None, hs)
                        } finally {
                            richEditSuppressDepth -= 1
                            hs.close()
                        }
                    }
                } finally {
                    doc.close()
                }
                true
            case _ => false
        }
        case RichEditBoxIsReadOnly => match ((handle, value)) {
            case (RichEditBoxH(reb), BoolV(v)) =>
                reb.IsReadOnly = v
                true
            case _ => false
        }
        // ── shared family props (Placeholder / Header / TextWrappingWrap /
        //    IsEnabled) — dispatched per-variant to the right projection ────────
        case Placeholder => match ((handle, value)) {
            case (TextBoxH(t), Str(s)) => t.PlaceholderText = HString(s); true
            case (TextBoxH(t), Unset) => t.PlaceholderText = HString(""); true
            case (PasswordBoxH(p), Str(s)) => p.PlaceholderText = HString(s); true
            case (PasswordBoxH(p), Unset) => p.PlaceholderText = HString(""); true
            case (RichEditBoxH(reb), Str(s)) => reb.PlaceholderText = HString(s); true
            case (RichEditBoxH(reb), Unset) => reb.PlaceholderText = HString(""); true
            case _ => false
        }
        case Header => match ((handle, value)) {
            case (TextBoxH(t), Str(s)) => t.Header = headerInspectable(s); true
            case (TextBoxH(t), Unset) => t.Header = emptyInspectable(); true
            case (PasswordBoxH(p), Str(s)) => p.Header = headerInspectable(s); true
            case (PasswordBoxH(p), Unset) => p.Header = emptyInspectable(); true
            case (RichEditBoxH(reb), Str(s)) => reb.Header = headerInspectable(s); true
            case (RichEditBoxH(reb), Unset) => reb.Header = emptyInspectable(); true
            case _ => false
        }
        case TextWrappingWrap => match ((handle, value)) {
            case (TextBoxH(t), BoolV(v)) =>
                t.TextWrapping = if (v) { Microsoft_UI_Xaml_TextWrapping_Wrap } else { Microsoft_UI_Xaml_TextWrapping_NoWrap }
                true
            case (TextBoxH(t), Unset) =>
                t.TextWrapping = Microsoft_UI_Xaml_TextWrapping_NoWrap
                true
            case _ => false
        }
        case IsEnabled => match ((handle, value)) {
            // IsEnabled lives on Control (a base of all three leaf classes), so
            // the shared setControlEnabled QIs to the Control surface and drives
            // it there. The reference handles TextBox/PasswordBox here; RichEditBox
            // is Control-derived too. (headerInspectable / emptyInspectable /
            // setControlEnabled are package-shared free helpers from props_pickers.)
            case (TextBoxH(_), BoolV(v)) => setControlEnabled(handle, v); true
            case (PasswordBoxH(_), BoolV(v)) => setControlEnabled(handle, v); true
            case (RichEditBoxH(_), BoolV(v)) => setControlEnabled(handle, v); true
            case (TextBoxH(_), Unset) => setControlEnabled(handle, true); true
            case (PasswordBoxH(_), Unset) => setControlEnabled(handle, true); true
            case (RichEditBoxH(_), Unset) => setControlEnabled(handle, true); true
            case _ => false
        }
        case _ => false
    }
}
