package windows_reactor.winui

import std.collection.{ArrayList}
import windows_reactor.core.{Event, EventHandler}
import windows_interface.{IInspectable}
import windows_sys.Foundation.{TypedEventHandler}
import windows_sys.Microsoft.UI.Xaml.Controls.{
    Expander, ExpanderExpandingEventArgs, ExpanderCollapsedEventArgs,
    InfoBar, InfoBarClosedEventArgs,
    ContentDialog, ContentDialogClosedEventArgs,
    TeachingTip, TeachingTipClosedEventArgs,
    TitleBar
}

// ============================================================================
// Dialog / surface event family.
//
// wireDialogEvents subscribes the reconciler's handler to a dialog-style
// control and returns the EventRevokers that own the registration(s). The
// returned ArrayList is empty when the event is not yet wired (the backend
// then stores nothing for that key).
//
// Each arm mirrors the proven Click wiring in event_button.cj: bind the event
// delegate (a Windows.Foundation.TypedEventHandler<TSender, TArgs> built from a
// Cangjie closure — the projection's generated invoker already translates a
// thrown exception into an HRESULT and never lets it cross the Invoke FFI
// boundary), call the control's addX accessor to obtain a token, and build an
// EventRevoker whose revoke closure runs removeX(token) + delegate.close().
//
// The event accessors live directly on the variant-bound projection class
// (verified against props_dialog.cj, which sets e.IsExpanded / ib.Title /
// tt.Title / tb.Title on the same bound classes), so no extra QueryInterface is
// needed; we use the handle's bound projection object directly. The handle's
// projection is GC-owned and outlives this call, so the revoker does not close
// it — only the delegate it created.
//
// Handler-variant routing (matches the widget binders in core/widget_*.cj):
//   - ExpandedChanged   → CheckedChangedH → invokeBool(true on Expanding,
//                          false on Collapsed); two registrations.
//   - InfoBarClosed     → ClickH         → invoke() (InfoBar.Closed).
//   - ContentDialogClosed → IndexChangedH → invokeI32(ContentDialogResult).
//   - TeachingTipClosed / TeachingTipActionClick → ClickH → invoke().
//   - TitleBarBackRequested / TitleBarPaneToggle → ClickH → invoke().
//   - FlyoutOpened / FlyoutClosed: the reference has a generic no-op arm — not
//     yet wired on any handle, so this returns an empty revoker list.
// ============================================================================
func wireDialogEvents(handle: Handle, event: Event, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    match (event) {
        // ── Expander: Expanding(true) + Collapsed(false) ───────────────────
        case ExpandedChanged => match (handle) {
            case ExpanderH(e) =>
                // Expanding → IsExpanded becomes true.
                let expandingDelegate =
                    TypedEventHandler<Expander, ExpanderExpandingEventArgs>.new({ _, _ =>
                        try {
                            handler.invokeBool(true)
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let expandingToken = e.addExpanding(expandingDelegate)
                revokers.add(EventRevoker({ =>
                    try {
                        e.removeExpanding(expandingToken)
                    } catch (_: Exception) {
                        ()
                    }
                    expandingDelegate.close()
                }))
                // Collapsed → IsExpanded becomes false.
                let collapsedDelegate =
                    TypedEventHandler<Expander, ExpanderCollapsedEventArgs>.new({ _, _ =>
                        try {
                            handler.invokeBool(false)
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let collapsedToken = e.addCollapsed(collapsedDelegate)
                revokers.add(EventRevoker({ =>
                    try {
                        e.removeCollapsed(collapsedToken)
                    } catch (_: Exception) {
                        ()
                    }
                    collapsedDelegate.close()
                }))
            case _ => ()
        }
        // ── InfoBar.Closed ─────────────────────────────────────────────────
        case InfoBarClosed => match (handle) {
            case InfoBarH(ib) =>
                let delegate =
                    TypedEventHandler<InfoBar, InfoBarClosedEventArgs>.new({ _, _ =>
                        try {
                            handler.invoke()
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let token = ib.addClosed(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        ib.removeClosed(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── ContentDialog.Closed (carries the ContentDialogResult) ─────────
        case ContentDialogClosed => match (handle) {
            case ContentDialogH(d) =>
                let delegate =
                    TypedEventHandler<ContentDialog, ContentDialogClosedEventArgs>.new({ _, args =>
                        try {
                            handler.invokeI32(contentDialogClosedResult(args))
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let token = d.addClosed(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        d.removeClosed(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── TeachingTip.Closed ─────────────────────────────────────────────
        case TeachingTipClosed => match (handle) {
            case TeachingTipH(tt) =>
                let delegate =
                    TypedEventHandler<TeachingTip, TeachingTipClosedEventArgs>.new({ _, _ =>
                        try {
                            handler.invoke()
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let token = tt.addClosed(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        tt.removeClosed(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── TeachingTip.ActionButtonClick (args is IInspectable) ───────────
        case TeachingTipActionClick => match (handle) {
            case TeachingTipH(tt) =>
                let delegate =
                    TypedEventHandler<TeachingTip, IInspectable>.new({ _, _ =>
                        try {
                            handler.invoke()
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let token = tt.addActionButtonClick(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        tt.removeActionButtonClick(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── TitleBar.BackRequested (args is IInspectable) ──────────────────
        case TitleBarBackRequested => match (handle) {
            case TitleBarH(tb) =>
                let delegate =
                    TypedEventHandler<TitleBar, IInspectable>.new({ _, _ =>
                        try {
                            handler.invoke()
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let token = tb.addBackRequested(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        tb.removeBackRequested(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── TitleBar.PaneToggleRequested (args is IInspectable) ────────────
        case TitleBarPaneToggle => match (handle) {
            case TitleBarH(tb) =>
                let delegate =
                    TypedEventHandler<TitleBar, IInspectable>.new({ _, _ =>
                        try {
                            handler.invoke()
                        } catch (_: Exception) {
                            ()
                        }
                    })
                let token = tb.addPaneToggleRequested(delegate)
                revokers.add(EventRevoker({ =>
                    try {
                        tb.removePaneToggleRequested(token)
                    } catch (_: Exception) {
                        ()
                    }
                    delegate.close()
                }))
            case _ => ()
        }
        // ── Flyout open/close: reference is a generic no-op (not yet wired) ─
        case _ =>
            let _ = handle
            let _ = handler
    }
    revokers
}

// Read the ContentDialogResult value from a ContentDialog.Closed args pointer.
// The closure receives the raw IInspectable of the event args; QI it to the
// ContentDialogClosedEventArgs projection and read its Result discriminant
// (mirrors the Rust `args.get_Result().0`, defaulting to 0 / None on failure).
func contentDialogClosedResult(argsRaw: CPointer<Unit>): Int32 {
    if (argsRaw.isNull()) {
        return 0
    }
    let args = ContentDialogClosedEventArgs.fromAbiTake(
        queryRequired(
            argsRaw,
            ContentDialogClosedEventArgs.iid(),
            "Microsoft.UI.Xaml.Controls.IContentDialogClosedEventArgs"
        )
    )
    try {
        return args.Result.value
    } finally {
        args.close()
    }
}
