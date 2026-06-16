package windows_reactor.winui

import std.collection.{ArrayList}
import windows_reactor.core.{Event, EventHandler}
import windows_core.{HString, OutSlot}
import windows_sys.Foundation.{TypedEventHandler}
import windows_sys.Microsoft.UI.Xaml.{RoutedEventHandler}
import windows_sys.Microsoft.UI.Xaml.Controls.{
    TextBox, TextChangedEventHandler,
    PasswordBox,
    RichEditBox,
    AutoSuggestBox,
    AutoSuggestBoxTextChangedEventArgs,
    AutoSuggestBoxQuerySubmittedEventArgs,
    AutoSuggestBoxSuggestionChosenEventArgs
}
import windows_sys.Microsoft.UI.Text.{TextGetOptions_None as Microsoft_UI_Text_TextGetOptions_None}
import windows_sys.Microsoft.UI.Xaml.Controls.{AutoSuggestionBoxTextChangeReason_UserInput as Microsoft_UI_Xaml_Controls_AutoSuggestionBoxTextChangeReason_UserInput}

// ============================================================================
// Text-input event family.
//
// wireTextEvents subscribes the reconciler's handler to a text-input control
// and returns the EventRevokers that own the registration(s). The returned
// ArrayList is empty when the event is not yet wired (the backend then stores
// nothing for that key).
//
// Each arm mirrors the proven Click wiring in event_button.cj / the dialog
// family in event_dialog.cj: build the projection delegate (whose generated
// invoker already translates a thrown exception into an HRESULT and never lets
// it cross the Invoke FFI boundary), call the control's addX accessor to obtain
// a token, and build an EventRevoker whose revoke closure runs removeX(token)
// + delegate.close(). The accessors live directly on the variant-bound
// projection class, so the bound handle object is used directly for add/remove
// (verified against props_textinput.cj, which drives the same bound classes).
//
// The new value is read from the *sender / args raw pointer* inside the closure
// (not from a captured control), exactly as the reference closures do — this
// avoids a control↔delegate reference cycle and keeps teardown crisp. The
// per-control extraction helpers below QI the raw pointer to the projection
// type and read the high-level getter.
//
// Handler-variant routing (matches the widget binders in core/widget_*.cj — all
// of these bind TextChangedH(Callback<String>), routed via invokeString):
//   - TextChanged             → TextBox.TextChanged          → sender Text.
//   - PasswordChanged         → PasswordBox.PasswordChanged  → sender Password.
//   - RichEditBoxTextChanged  → RichEditBox.TextChanged      → Document GetText.
//   - AutoSuggestTextChanged  → AutoSuggestBox.TextChanged   → sender Text
//                                (only for AutoSuggestionBoxTextChangeReason::UserInput).
//   - AutoSuggestQuerySubmitted → AutoSuggestBox.QuerySubmitted → args QueryText.
//   - AutoSuggestSuggestionChosen → AutoSuggestBox.SuggestionChosen
//                                → args SelectedItem unboxed (IReference<HString>).
// ============================================================================
func wireTextEvents(handle: Handle, event: Event, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    match (event) {
        // ── TextBox.TextChanged (delegate = TextChangedEventHandler) ─────────
        case TextChanged => match (handle) {
            case TextBoxH(tb) =>
                let delegate = TextChangedEventHandler.new({ sender, _ =>
                    try {
                        handler.invokeString(senderTextBoxText(sender))
                    } catch (_: Exception) {
                        ()
                    }
                })
                let token = tb.addTextChanged(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        tb.removeTextChanged(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── PasswordBox.PasswordChanged (delegate = RoutedEventHandler) ──────
        case PasswordChanged => match (handle) {
            case PasswordBoxH(pb) =>
                let delegate = RoutedEventHandler.new({ sender, _ =>
                    try {
                        handler.invokeString(senderPasswordBoxPassword(sender))
                    } catch (_: Exception) {
                        ()
                    }
                })
                let token = pb.addPasswordChanged(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        pb.removePasswordChanged(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── RichEditBox.TextChanged (delegate = RoutedEventHandler) ──────────
        case RichEditBoxTextChanged => match (handle) {
            case RichEditBoxH(reb) =>
                let delegate = RoutedEventHandler.new({ sender, _ =>
                    try {
                        // Skip the synchronous TextChanged raised by a programmatic SetText
                        // (controlled-value re-apply); invoking the reactor handler there
                        // re-enters render and fail-fasts WinUIEdit. See richEditSuppressDepth.
                        if (!richEditTextChangeSuppressed()) {
                            handler.invokeString(senderRichEditBoxText(sender))
                        }
                    } catch (_: Exception) {
                        ()
                    }
                })
                let token = reb.addTextChanged(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        reb.removeTextChanged(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── AutoSuggestBox.TextChanged (TypedEventHandler; user input only) ──
        case AutoSuggestTextChanged => match (handle) {
            case AutoSuggestBoxH(asb) =>
                let delegate =
                    TypedEventHandler<AutoSuggestBox, AutoSuggestBoxTextChangedEventArgs>.new({ sender, args =>
                        try {
                            // Only fire for user input, not programmatic changes.
                            if (autoSuggestTextChangeIsUserInput(args)) {
                                handler.invokeString(senderAutoSuggestBoxText(sender))
                            }
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let token = asb.addTextChanged(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        asb.removeTextChanged(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── AutoSuggestBox.QuerySubmitted (TypedEventHandler; args QueryText) ─
        case AutoSuggestQuerySubmitted => match (handle) {
            case AutoSuggestBoxH(asb) =>
                let delegate =
                    TypedEventHandler<AutoSuggestBox, AutoSuggestBoxQuerySubmittedEventArgs>.new({ _, args =>
                        try {
                            handler.invokeString(autoSuggestQueryText(args))
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let token = asb.addQuerySubmitted(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        asb.removeQuerySubmitted(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── AutoSuggestBox.SuggestionChosen (TypedEventHandler; unbox item) ──
        case AutoSuggestSuggestionChosen => match (handle) {
            case AutoSuggestBoxH(asb) =>
                let delegate =
                    TypedEventHandler<AutoSuggestBox, AutoSuggestBoxSuggestionChosenEventArgs>.new({ _, args =>
                        try {
                            handler.invokeString(autoSuggestSelectedItemText(args))
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let token = asb.addSuggestionChosen(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        asb.removeSuggestionChosen(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        case _ =>
            let _ = handle
            let _ = handler
    }
    revokers
}

// ── Sender / args extraction helpers ────────────────────────────────────────
// Each QIs the raw event pointer to its projection type and reads the high-level
// getter (mirrors the reference `sender.cast::<T>()…` / `args.cast::<T>()…`
// chains). All return "" on a null pointer so a misformed callback never throws
// across the Invoke boundary.

// TextBox.TextChanged: read the live Text off the sender.
func senderTextBoxText(senderRaw: CPointer<Unit>): String {
    if (senderRaw.isNull()) {
        return ""
    }
    let tb = TextBox.fromAbiTake(
        queryRequired(senderRaw, TextBox.iid(), "Microsoft.UI.Xaml.Controls.ITextBox")
    )
    try {
        let hs = tb.Text
        try {
            return hs.toString()
        } finally {
            hs.close()
        }
    } finally {
        tb.close()
    }
}

// PasswordBox.PasswordChanged: read the live Password off the sender.
func senderPasswordBoxPassword(senderRaw: CPointer<Unit>): String {
    if (senderRaw.isNull()) {
        return ""
    }
    let pb = PasswordBox.fromAbiTake(
        queryRequired(senderRaw, PasswordBox.iid(), "Microsoft.UI.Xaml.Controls.IPasswordBox")
    )
    try {
        let hs = pb.Password
        try {
            return hs.toString()
        } finally {
            hs.close()
        }
    } finally {
        pb.close()
    }
}

// RichEditBox.TextChanged: pull the full document text via Document.GetText.
func senderRichEditBoxText(senderRaw: CPointer<Unit>): String {
    if (senderRaw.isNull()) {
        return ""
    }
    let reb = RichEditBox.fromAbiTake(
        queryRequired(senderRaw, RichEditBox.iid(), "Microsoft.UI.Xaml.Controls.IRichEditBox")
    )
    try {
        let doc = reb.Document
        try {
            let slot = OutSlot<HString>()
            try {
                doc.GetText(Microsoft_UI_Text_TextGetOptions_None, slot)
                match (slot.get()) {
                    case Some(hs) => return hs.toString()
                    case None => return ""
                }
            } finally {
                slot.close()
            }
        } finally {
            doc.close()
        }
    } finally {
        reb.close()
    }
}

// AutoSuggestBox.TextChanged: read the live Text off the sender.
func senderAutoSuggestBoxText(senderRaw: CPointer<Unit>): String {
    if (senderRaw.isNull()) {
        return ""
    }
    let asb = AutoSuggestBox.fromAbiTake(
        queryRequired(senderRaw, AutoSuggestBox.iid(), "Microsoft.UI.Xaml.Controls.IAutoSuggestBox")
    )
    try {
        let hs = asb.Text
        try {
            return hs.toString()
        } finally {
            hs.close()
        }
    } finally {
        asb.close()
    }
}

// AutoSuggestBox.TextChanged: only user edits (not programmatic Text=) should
// notify the reconciler — gate on the change Reason being UserInput.
func autoSuggestTextChangeIsUserInput(argsRaw: CPointer<Unit>): Bool {
    if (argsRaw.isNull()) {
        return false
    }
    let args = AutoSuggestBoxTextChangedEventArgs.fromAbiTake(
        queryRequired(
            argsRaw,
            AutoSuggestBoxTextChangedEventArgs.iid(),
            "Microsoft.UI.Xaml.Controls.IAutoSuggestBoxTextChangedEventArgs"
        )
    )
    try {
        return args.Reason.value == Microsoft_UI_Xaml_Controls_AutoSuggestionBoxTextChangeReason_UserInput.value
    } finally {
        args.close()
    }
}

// AutoSuggestBox.QuerySubmitted: the submitted query text lives on the args.
func autoSuggestQueryText(argsRaw: CPointer<Unit>): String {
    if (argsRaw.isNull()) {
        return ""
    }
    let args = AutoSuggestBoxQuerySubmittedEventArgs.fromAbiTake(
        queryRequired(
            argsRaw,
            AutoSuggestBoxQuerySubmittedEventArgs.iid(),
            "Microsoft.UI.Xaml.Controls.IAutoSuggestBoxQuerySubmittedEventArgs"
        )
    )
    try {
        let hs = args.QueryText
        try {
            return hs.toString()
        } finally {
            hs.close()
        }
    } finally {
        args.close()
    }
}

// AutoSuggestBox.SuggestionChosen: the chosen item is a boxed string
// (IReference<HString>, as seeded by setNavAutoSuggestItems). Unbox it with the
// package-shared hStringReferenceValue helper.
func autoSuggestSelectedItemText(argsRaw: CPointer<Unit>): String {
    if (argsRaw.isNull()) {
        return ""
    }
    let args = AutoSuggestBoxSuggestionChosenEventArgs.fromAbiTake(
        queryRequired(
            argsRaw,
            AutoSuggestBoxSuggestionChosenEventArgs.iid(),
            "Microsoft.UI.Xaml.Controls.IAutoSuggestBoxSuggestionChosenEventArgs"
        )
    )
    try {
        let item = args.SelectedItem
        try {
            return hStringReferenceValue(item.asRaw())
        } finally {
            item.close()
        }
    } finally {
        args.close()
    }
}
