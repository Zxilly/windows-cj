package windows_reactor.winui

import std.collection.{ArrayList}
import windows_reactor.core.{Event, EventHandler}
import windows_common.Microsoft.UI.Xaml.{RoutedEventHandler}
import windows_common.Microsoft.UI.Xaml.Controls.Primitives.{ButtonBase}
import windows_common.Microsoft.UI.Xaml.Controls.{SplitButton, SplitButtonClickEventArgs}
import windows_common.Foundation.{TypedEventHandler}

// ============================================================================
// Button event family.
//
// wireButtonEvents subscribes the reconciler's handler to a button-style
// control and returns the EventRevokers that own the registration(s). The
// returned ArrayList is empty when the event is not yet wired (the backend
// then stores nothing for that key).
//
// Implemented: Click (the P4b-events baseline sample). The button's identity
// is QI'd to ButtonBase, the EventHandler is wrapped in a RoutedEventHandler
// delegate, and ButtonBase.addClick/removeClick manage the subscription. The
// revoke closure removes the handler and releases the captured projections.
//
// SplitButtonClick is wired here the same way: the identity is QI'd to the
// SplitButton runtime class, whose Click event is a
// TypedEventHandler<SplitButton, SplitButtonClickEventArgs> (the SplitButton
// "primary action" click, distinct from the ButtonBase.Click on the drop-down
// arm), and SplitButton.addClick/removeClick own the subscription.
//
// MenuFlyoutItemClicked and CommandBarFlyoutClick are NOT wired here: their
// per-item add_Click wiring needs the flyout's items, which are (re)built by the
// props layer (props_button.cj) and recreated on every rebuild. The backend
// therefore intercepts these two events in attachEvent BEFORE this dispatch,
// stashing the EventHandler in its menuClickHandlers / commandBarFlyoutHandlers
// registry, and re-runs the per-item wiring (wireButtonMenuFlyoutClicks /
// wireButtonCommandBarFlyoutClicks) after each flyout rebuild in setProp. These
// arms are consequently unreachable for those events; they push no revoker (the
// `case _` arm) should the routing ever reach them, keeping wireControlEvent
// exhaustive.
// ============================================================================
func wireButtonEvents(handle: Handle, event: Event, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    match (event) {
        case Click =>
            // QI the control's identity to the ButtonBase primitive that owns
            // the Click event accessors.
            let target = ButtonBase.fromAbiTake(
                queryRequired(handle.asRaw(), ButtonBase.iid(), "Microsoft.UI.Xaml.Controls.Primitives.IButtonBase")
            )
            // The delegate must outlive the registration: capture it in the
            // revoke closure so it is not collected while WinUI references it.
            let delegate = RoutedEventHandler.new({ _, _ =>
                try {
                    handler.invoke()
                } catch (_: Exception) {
                    // invoke() may throw HandlerMismatchException for a misrouted
                    // variant; never let it cross the Invoke FFI boundary.
                    ()
                }
            })
            let token = target.addClick(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeClick(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case SplitButtonClick =>
            // QI the control's identity to the SplitButton runtime class that
            // owns the primary-action Click event. SplitButton.Click is a
            // TypedEventHandler (sender = SplitButton, args =
            // SplitButtonClickEventArgs), so the delegate closure receives raw
            // (sender, args) ABI pointers; neither is needed for a unit invoke.
            let target = SplitButton.fromAbiTake(
                queryRequired(handle.asRaw(), SplitButton.iid(), "Microsoft.UI.Xaml.Controls.ISplitButton")
            )
            let delegate = TypedEventHandler<SplitButton, SplitButtonClickEventArgs>.new({ _, _ =>
                try {
                    handler.invoke()
                } catch (_: Exception) {
                    // A misrouted variant throws HandlerMismatchException; never
                    // let it cross the Invoke FFI boundary.
                    ()
                }
            })
            let token = target.addClick(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeClick(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case MenuFlyoutItemClicked | CommandBarFlyoutClick =>
            // Unreachable: attachEvent intercepts these two events before
            // wireControlEvent and stashes the handler in the backend's
            // menuClickHandlers / commandBarFlyoutHandlers registry (the per-item
            // add_Click wiring is then driven by setProp on every flyout rebuild).
            // Kept here only to keep the family match exhaustive; pushes nothing.
            let _ = handle
            let _ = handler
        case _ =>
            // wireControlEvent only routes button-family events here; any other
            // variant is unreachable and registers nothing.
            let _ = handle
            let _ = handler
    }
    revokers
}
