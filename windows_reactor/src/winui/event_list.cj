package windows_reactor.winui

import std.collection.{ArrayList}
import windows_reactor.core.{Event, EventHandler}
import windows_core.{queryInterfaceRaw}
import windows_sys.Microsoft.UI.Xaml.Controls.{
    SelectionChangedEventHandler, TreeView, TreeViewItemInvokedEventArgs, TreeViewNode, RadioButtons
}
import windows_sys.Microsoft.UI.Xaml.Controls.Primitives.{Selector}
import windows_sys.Foundation.{TypedEventHandler}

// ============================================================================
// Selection / collection event family.
//
// wireListEvents subscribes the reconciler's handler to a selection/collection
// control and returns the EventRevokers that own the registration(s). Mirrors
// the (Event, Handle) arms of the reference backend's attach_event for the list
// family. The returned ArrayList is empty when the event is not wired.
//
// Implemented:
//   - ComboSelectionChanged   ComboBox  → Selector.SelectionChanged → SelectedIndex (invokeI32)
//   - ListBoxSelectionChanged ListBox   → Selector.SelectionChanged → SelectedIndex (invokeI32)
//   - TreeViewItemInvoked     TreeView  → TreeView.ItemInvoked → invoked node Content (invokeString)
//
// ComboBox and ListBox both expose Selector.SelectionChanged via the
// Microsoft.UI.Xaml.Controls.Primitives.ISelector interface, so each control's
// identity is QI'd to the Selector primitive (which owns the SelectionChanged
// accessor + SelectedIndex). The new index is read back from the sender pointer
// passed into the delegate, exactly as the reference closures do.
//
// TreeView.ItemInvoked is a TypedEventHandler<TreeView, TreeViewItemInvokedEventArgs>;
// the invoked item is unboxed to its TreeViewNode content string (the reference
// reads ITreeViewNode.Content as an IReference<HSTRING>).
// ============================================================================
func wireListEvents(handle: Handle, event: Event, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    match (event) {
        case ComboSelectionChanged =>
            // ComboBox.SelectionChanged lives on the Selector primitive
            // (ISelector). QI the control identity to Selector and wire it.
            let target = Selector.fromAbiTake(
                queryRequired(handle.asRaw(), Selector.iid(),
                    "Microsoft.UI.Xaml.Controls.Primitives.ISelector")
            )
            let delegate = SelectionChangedEventHandler.new({ sender, _ =>
                try {
                    handler.invokeI32(selectorSelectedIndex(sender))
                } catch (_: Exception) {
                    // invokeI32 may throw HandlerMismatchException for a
                    // misrouted variant; never let it cross the Invoke boundary.
                    ()
                }
            })
            let token = target.addSelectionChanged(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeSelectionChanged(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case ListBoxSelectionChanged =>
            // ListBox.SelectionChanged is the same Selector.SelectionChanged
            // accessor; identical wiring to the ComboBox arm.
            let target = Selector.fromAbiTake(
                queryRequired(handle.asRaw(), Selector.iid(),
                    "Microsoft.UI.Xaml.Controls.Primitives.ISelector")
            )
            let delegate = SelectionChangedEventHandler.new({ sender, _ =>
                try {
                    handler.invokeI32(selectorSelectedIndex(sender))
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addSelectionChanged(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeSelectionChanged(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case TreeViewItemInvoked =>
            // TreeView.ItemInvoked is a TypedEventHandler<TreeView, args>. The
            // invoked node's Content (a boxed string) is the payload.
            let target = TreeView.fromAbiTake(
                queryRequired(handle.asRaw(), TreeView.iid(),
                    "Microsoft.UI.Xaml.Controls.ITreeView")
            )
            let delegate = TypedEventHandler<TreeView, TreeViewItemInvokedEventArgs>.new({ _, args =>
                try {
                    handler.invokeString(treeViewInvokedContent(args))
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addItemInvoked(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeItemInvoked(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case RadioButtonsSelectionChanged =>
            // RadioButtons is NOT a Selector; it exposes its own SelectionChanged
            // (SelectionChangedEventHandler) + SelectedIndex. Mirror the reference:
            // subscribe on the RadioButtons and read the new index back from the
            // sender pointer (avoids a control↔delegate reference cycle).
            let target = RadioButtons.fromAbiTake(
                queryRequired(handle.asRaw(), RadioButtons.iid(),
                    "Microsoft.UI.Xaml.Controls.IRadioButtons")
            )
            let delegate = SelectionChangedEventHandler.new({ sender, _ =>
                try {
                    handler.invokeI32(radioButtonsSelectedIndex(sender))
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addSelectionChanged(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeSelectionChanged(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case _ =>
            // The templated-collection SelectionChanged (ListView/GridView/
            // FlipView) is wired by the templated backend-state coupling, not
            // this function.
            let _ = handle
            let _ = handler
    }
    revokers
}

// Read the current SelectedIndex from a RadioButtons sender pointer. RadioButtons
// is not a Selector, so it is QI'd to its own projection. Returns -1 when the QI
// fails (mirrors the reference unwrap_or(-1)).
func radioButtonsSelectedIndex(sender: CPointer<Unit>): Int32 {
    if (sender.isNull()) {
        return -1
    }
    match (unsafe { queryInterfaceRaw(sender, RadioButtons.iid()) }) {
        case Some(raw) =>
            let rb = RadioButtons.fromAbiTake(raw)
            try {
                return rb.SelectedIndex
            } catch (_: Exception) {
                return -1
            } finally {
                rb.close()
            }
        case None => return -1
    }
}

// Read the current SelectedIndex from a Selector sender pointer. The sender is
// a borrowed pointer; QI produces an owned Selector ref that is released after
// the read. Returns -1 when the QI fails (mirrors the reference unwrap_or(-1)).
func selectorSelectedIndex(sender: CPointer<Unit>): Int32 {
    if (sender.isNull()) {
        return -1
    }
    match (unsafe { queryInterfaceRaw(sender, Selector.iid()) }) {
        case Some(raw) =>
            let sel = Selector.fromAbiTake(raw)
            try {
                return sel.SelectedIndex
            } catch (_: Exception) {
                return -1
            } finally {
                sel.close()
            }
        case None => return -1
    }
}

// Unbox the TreeView.ItemInvoked args to the invoked node's Content string.
// args → TreeViewItemInvokedEventArgs.InvokedItem (IInspectable) → QI to
// TreeViewNode → Content (boxed IReference<HSTRING>) → String. Returns "" at any
// missing step (mirrors the reference unwrap_or_default()).
func treeViewInvokedContent(args: CPointer<Unit>): String {
    if (args.isNull()) {
        return ""
    }
    let argObj = TreeViewItemInvokedEventArgs.fromAbiTake(
        queryRequired(args, TreeViewItemInvokedEventArgs.iid(),
            "Microsoft.UI.Xaml.Controls.ITreeViewItemInvokedEventArgs")
    )
    try {
        let invoked = argObj.InvokedItem()
        try {
            let invokedRaw = invoked.asRaw()
            if (invokedRaw.isNull()) {
                return ""
            }
            match (unsafe { queryInterfaceRaw(invokedRaw, TreeViewNode.iid()) }) {
                case Some(nodeRaw) =>
                    let node = TreeViewNode.fromAbiTake(nodeRaw)
                    let content = node.Content()
                    try {
                        return hStringReferenceValue(content.asRaw())
                    } finally {
                        content.close()
                        node.close()
                    }
                case None => return ""
            }
        } finally {
            invoked.close()
        }
    } finally {
        argObj.close()
    }
}
