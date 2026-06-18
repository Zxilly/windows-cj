package windows_reactor.winui

import std.collection.{ArrayList}
import windows_reactor.core.{Event, EventHandler}
import windows_reference.{IReference}
import windows_reactor.bindings.Microsoft.UI.Xaml.{RoutedEventHandler}
import windows_reactor.bindings.Microsoft.UI.Xaml.Controls.{ToggleSwitch, RatingControl}
import windows_reactor.bindings.Microsoft.UI.Xaml.Controls.Primitives.{
    ToggleButton, RangeBase, RangeBaseValueChangedEventHandler, RangeBaseValueChangedEventArgs
}
import windows_reactor.bindings.Microsoft.UI.Xaml.Controls.{NumberBox as Microsoft_UI_Xaml_Controls_NumberBox, NumberBoxValueChangedEventArgs as Microsoft_UI_Xaml_Controls_NumberBoxValueChangedEventArgs, RatingControl as Microsoft_UI_Xaml_Controls_RatingControl}
import windows_reactor.bindings.Foundation.{TypedEventHandler as Windows_Foundation_TypedEventHandler_2}
import windows_interface.{IInspectable}

// ============================================================================
// Value / toggle input event family.
//
// wireInputEvents subscribes the reconciler's handler to value/toggle controls
// and returns the EventRevokers that own the registration(s). Each event mirrors
// the corresponding (Event::X, Handle::Y) arm of the reference backend's
// attach_event: QI the control identity to the interface that owns the event
// accessor, wrap the EventHandler in the matching projection delegate, register
// via the high-level addX accessor, and build an EventRevoker whose revoke
// closure unregisters (removeX) and releases the captured projections.
//
// Implemented:
//   - CheckedChanged: CheckBox + ToggleButton. QI to the Primitives.ToggleButton
//     surface and register BOTH Checked and Unchecked (two EventRevokers), each
//     reading IToggleButton.IsChecked from the sender and dispatching invokeBool.
//   - Toggled: ToggleSwitch.addToggled, reading IsOn -> invokeBool.
//   - ValueChanged: Slider (via the Primitives.RangeBase base surface using the
//     RangeBaseValueChangedEventHandler delegate, reading
//     RangeBaseValueChangedEventArgs.NewValue) and NumberBox (its own
//     ValueChanged TypedEventHandler delegate, reading
//     NumberBoxValueChangedEventArgs.NewValue) -> invokeF64.
//   - RadioChecked: RadioButton. QI to ToggleButton and register Checked ->
//     invoke() (the Unit/Click variant, matching the reference's invoke()).
//   - RatingValueChanged: RatingControl.addValueChanged, reading the sender's
//     Value -> invokeF64.
//
// The delegate must outlive the registration: it is captured by the revoke
// closure so WinUI's reference to it stays alive until detach. Every handler
// dispatch is wrapped in try/catch so a HandlerMismatchException (misrouted
// variant) never crosses the Invoke FFI boundary.
// ============================================================================
func wireInputEvents(handle: Handle, event: Event, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    match (event) {
        // ── CheckedChanged: CheckBox + ToggleButton (Checked AND Unchecked) ────
        case CheckedChanged =>
            match (handle) {
                case CheckBoxH(_) => wireToggleCheckedChanged(handle.asRaw(), handler, revokers)
                case ToggleButtonH(_) => wireToggleCheckedChanged(handle.asRaw(), handler, revokers)
                case _ => ()
            }
        // ── Toggled: ToggleSwitch ──────────────────────────────────────────────
        case Toggled =>
            match (handle) {
                case ToggleSwitchH(ts) =>
                    let target = ts
                    let delegate = RoutedEventHandler.new({ sender, _ =>
                        try {
                            handler.invokeBool(senderToggleSwitchIsOn(sender))
                        } catch (_: Exception) {
                            ()
                        }
                    })
                    let token = target.addToggled(delegate)
                    revokers.add(EventRevoker({ =>
                        try {
                            target.removeToggled(token)
                        } catch (_: Exception) {
                            ()
                        }
                        delegate.close()
                    }))
                case _ => ()
            }
        // ── ValueChanged: Slider (RangeBase) + NumberBox ───────────────────────
        case ValueChanged =>
            match (handle) {
                case SliderH(_) =>
                    let target = RangeBase.fromAbiTake(
                        queryRequired(handle.asRaw(), RangeBase.iid(),
                            "Microsoft.UI.Xaml.Controls.Primitives.IRangeBase")
                    )
                    let delegate = RangeBaseValueChangedEventHandler.new({ _, e =>
                        try {
                            handler.invokeF64(rangeBaseArgsNewValue(e))
                        } catch (_: Exception) {
                            ()
                        }
                    })
                    let token = target.addValueChanged(delegate)
                    revokers.add(EventRevoker({ =>
                        try {
                            target.removeValueChanged(token)
                        } catch (_: Exception) {
                            ()
                        }
                        delegate.close()
                        target.close()
                    }))
                case NumberBoxH(n) =>
                    let target = n
                    let delegate = Windows_Foundation_TypedEventHandler_2<
                        Microsoft_UI_Xaml_Controls_NumberBox,
                        Microsoft_UI_Xaml_Controls_NumberBoxValueChangedEventArgs
                    >.new({ _, args =>
                        try {
                            handler.invokeF64(numberBoxArgsNewValue(args))
                        } catch (_: Exception) {
                            ()
                        }
                    })
                    let token = target.addValueChanged(delegate)
                    revokers.add(EventRevoker({ =>
                        try {
                            target.removeValueChanged(token)
                        } catch (_: Exception) {
                            ()
                        }
                        delegate.close()
                    }))
                case _ => ()
            }
        // ── RadioChecked: RadioButton (Checked -> invoke()) ────────────────────
        case RadioChecked =>
            match (handle) {
                case RadioButtonH(_) =>
                    let target = ToggleButton.fromAbiTake(
                        queryRequired(handle.asRaw(), ToggleButton.iid(),
                            "Microsoft.UI.Xaml.Controls.Primitives.IToggleButton")
                    )
                    let delegate = RoutedEventHandler.new({ _, _ =>
                        try {
                            handler.invoke()
                        } catch (_: Exception) {
                            ()
                        }
                    })
                    let token = target.Checked(delegate)
                    revokers.add(EventRevoker({ =>
                        try {
                            target.RemoveChecked(token)
                        } catch (_: Exception) {
                            ()
                        }
                        delegate.close()
                        target.close()
                    }))
                case _ => ()
            }
        // ── RatingValueChanged: RatingControl ──────────────────────────────────
        case RatingValueChanged =>
            match (handle) {
                case RatingControlH(r) =>
                    let target = r
                    let delegate = Windows_Foundation_TypedEventHandler_2<
                        Microsoft_UI_Xaml_Controls_RatingControl,
                        IInspectable
                    >.new({ sender, _ =>
                        try {
                            handler.invokeF64(senderRatingValue(sender))
                        } catch (_: Exception) {
                            ()
                        }
                    })
                    let token = target.addValueChanged(delegate)
                    revokers.add(EventRevoker({ =>
                        try {
                            target.removeValueChanged(token)
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

// ── private helpers ──────────────────────────────────────────────────────────

// Register CheckedChanged on a ToggleButton-style control. QI the control
// identity to the Primitives.ToggleButton surface and subscribe BOTH the
// Checked and Unchecked routed events; each reads the current tri-state
// IsChecked from the sender and dispatches it as a Bool (mirrors the reference
// `add_Checked` / `add_Unchecked` pair that both call invoke_bool). Two
// EventRevokers are pushed — one per registration — so detach unwinds both.
//
// Each registration QI's its own ToggleButton view so the two delegates and the
// two revoke closures own independent projections (the WinRT add/remove pair
// operates on the same underlying object via a freshly-QI'd interface, matching
// the reference which casts to IToggleButton twice).
func wireToggleCheckedChanged(raw: CPointer<Unit>, handler: EventHandler,
                              revokers: ArrayList<EventRevoker>): Unit {
    // Checked arm.
    let checkedTarget = ToggleButton.fromAbiTake(
        queryRequired(raw, ToggleButton.iid(),
            "Microsoft.UI.Xaml.Controls.Primitives.IToggleButton")
    )
    let checkedDelegate = RoutedEventHandler.new({ sender, _ =>
        try {
            handler.invokeBool(senderToggleIsChecked(sender))
        } catch (_: Exception) {
            ()
        }
    })
    let checkedToken = checkedTarget.Checked(checkedDelegate)
    revokers.add(EventRevoker({ =>
        try {
            checkedTarget.RemoveChecked(checkedToken)
        } catch (_: Exception) {
            ()
        }
        checkedDelegate.close()
        checkedTarget.close()
    }))

    // Unchecked arm.
    let uncheckedTarget = ToggleButton.fromAbiTake(
        queryRequired(raw, ToggleButton.iid(),
            "Microsoft.UI.Xaml.Controls.Primitives.IToggleButton")
    )
    let uncheckedDelegate = RoutedEventHandler.new({ sender, _ =>
        try {
            handler.invokeBool(senderToggleIsChecked(sender))
        } catch (_: Exception) {
            ()
        }
    })
    let uncheckedToken = uncheckedTarget.Unchecked(uncheckedDelegate)
    revokers.add(EventRevoker({ =>
        try {
            uncheckedTarget.RemoveUnchecked(uncheckedToken)
        } catch (_: Exception) {
            ()
        }
        uncheckedDelegate.close()
        uncheckedTarget.close()
    }))
}

// Read IToggleButton.IsChecked from a (non-owning) sender raw pointer and
// flatten the tri-state nullable bool to a plain Bool, mirroring the reference
// `sender_is_checked` (`tb.cast::<IToggleButton>()...get_IsChecked().unwrap_or(false)`).
// A null sender, a control that is not a ToggleButton, or an indeterminate
// (null IReference<Bool>) state all collapse to false. The sender is borrowed
// for the duration of Invoke, so it is wrapped non-owning (viewOf) and never
// released here.
func senderToggleIsChecked(sender: CPointer<Unit>): Bool {
    if (sender.isNull()) {
        return false
    }
    // QI/getter failure (non-ToggleButton sender) or an indeterminate (null
    // IReference<Bool>) box both collapse to false, matching the reference
    // `unwrap_or(false)`. The IsChecked getter returns an owning IReference<Bool>
    // that must be released after unboxing.
    var result = false
    try {
        let tb = ToggleButton.viewOf(sender)
        let boxed = tb.IsChecked
        try {
            let boxRaw = boxed.asRaw()
            if (boxRaw.isNotNull()) {
                // Bridge the boxed value to the high-level IReference<Bool>
                // surface (same Windows.Foundation.IReference<Boolean> COM
                // interface) to unbox it.
                let reference = IReference<Bool>.viewOf(boxRaw)
                result = unsafe { reference.Value() }
            }
        } finally {
            boxed.close()
        }
    } catch (_: Exception) {
        result = false
    }
    return result
}

// Read ToggleSwitch.IsOn from a (non-owning) sender raw pointer, mirroring the
// reference `sender.cast::<ToggleSwitch>()...get_IsOn().unwrap_or(false)`.
func senderToggleSwitchIsOn(sender: CPointer<Unit>): Bool {
    if (sender.isNull()) {
        return false
    }
    try {
        let ts = ToggleSwitch.viewOf(sender)
        return ts.IsOn
    } catch (_: Exception) {
        return false
    }
}

// Read RatingControl.Value from a (non-owning) sender raw pointer, mirroring the
// reference `sender.cast::<RatingControl>()...get_Value().unwrap_or(-1.0)`.
func senderRatingValue(sender: CPointer<Unit>): Float64 {
    if (sender.isNull()) {
        return -1.0
    }
    try {
        let rc = RatingControl.viewOf(sender)
        return rc.Value
    } catch (_: Exception) {
        return -1.0
    }
}

// Read RangeBaseValueChangedEventArgs.NewValue from the (non-owning) args raw
// pointer of a RangeBase.ValueChanged delegate, mirroring the reference
// `args.cast::<IRangeBaseValueChangedEventArgs>()...get_NewValue()`.
func rangeBaseArgsNewValue(args: CPointer<Unit>): Float64 {
    if (args.isNull()) {
        return 0.0
    }
    let wrapped = RangeBaseValueChangedEventArgs.viewOf(args)
    return wrapped.NewValue
}

// Read NumberBoxValueChangedEventArgs.NewValue from the (non-owning) args raw
// pointer of a NumberBox.ValueChanged delegate, mirroring the reference
// `args.get_NewValue()`.
func numberBoxArgsNewValue(args: CPointer<Unit>): Float64 {
    if (args.isNull()) {
        return 0.0
    }
    let wrapped = Microsoft_UI_Xaml_Controls_NumberBoxValueChangedEventArgs.viewOf(args)
    return wrapped.NewValue
}
