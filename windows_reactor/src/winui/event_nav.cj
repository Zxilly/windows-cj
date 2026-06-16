package windows_reactor.winui

import std.collection.{ArrayList, HashSet, HashMap}
import windows_reactor.core.{Event, EventHandler}
import windows_core.{queryInterfaceRaw}
import windows_interface.{IInspectable}
import windows_sys.Microsoft.UI.Xaml.{FrameworkElement, RoutedEventHandler}
import windows_sys.Foundation.{TypedEventHandler}
import windows_sys.Microsoft.UI.Xaml.Controls.{
    TabView, TabViewTabCloseRequestedEventArgs,
    NavigationView, NavigationViewBackRequestedEventArgs, NavigationViewSelectionChangedEventArgs,
    NavigationViewItem,
    AutoSuggestBox, AutoSuggestBoxQuerySubmittedEventArgs, AutoSuggestBoxSuggestionChosenEventArgs,
    AutoSuggestBoxTextChangedEventArgs,
    Pivot, SelectorBar, SelectorBarSelectionChangedEventArgs, SplitView,
    BreadcrumbBar, BreadcrumbBarItemClickedEventArgs,
    SelectionChangedEventHandler
}

// NavigationView owners whose WinUI Loaded event has fired (template applied, the
// ItemsRepeater realized live containers). The programmatic SelectedItem write is
// deferred until then (props_nav.cj) — writing it during prophase, before the control is
// in the live tree, makes WinUI's own OnApplyTemplate read a pre-realization item and AV.
let navLoadedOwners = HashSet<UIntNative>()
func navMarkLoaded(ownerKey: UIntNative): Unit { navLoadedOwners.add(ownerKey) }
func navIsLoaded(ownerKey: UIntNative): Bool { navLoadedOwners.contains(ownerKey) }

// Explicit strong-retention for the Loaded + SelectionChanged delegates handed to WinUI.
// These are Cangjie CCWs; WinUI's AddRef does not root the managed object against the
// Cangjie GC, so we keep a live reference for the registration's lifetime (released by the
// revoke closure). Keyed by owner so the revoke closure can drop all of a control's
// delegates. (Object is not Hashable, so a per-owner ArrayList is used, not a set.)
let navDelegateRetention = HashMap<UIntNative, ArrayList<Object>>()
func retainNavDelegate(ownerKey: UIntNative, d: Object): Unit {
    match (navDelegateRetention.get(ownerKey)) {
        case Some(list) => list.add(d)
        case None =>
            let list = ArrayList<Object>()
            list.add(d)
            navDelegateRetention[ownerKey] = list
    }
}
func releaseNavDelegates(ownerKey: UIntNative): Unit { navDelegateRetention.remove(ownerKey) }

// ============================================================================
// Navigation / shell event family.
//
// wireNavEvents mirrors the reference backend's attach_event arms for the
// shell controls (TabView, NavigationView + its inner AutoSuggestBox, Pivot,
// SelectorBar, SplitView, BreadcrumbBar) and returns one EventRevoker per
// registration. The wiring shape follows the proven Click template
// (event_button.cj): QI the control's identity to a fresh owned projection,
// wrap the reconciler's EventHandler in the matching projection delegate, call
// the high-level addX accessor for a token, and build an EventRevoker whose
// revoke closure removes the handler and releases the captured projections.
//
// Each delegate closure receives RAW sender/args pointers (the projection
// delegate ABI is `(CPointer<Unit>, CPointer<Unit>) -> Unit`). Payload
// extraction QIs those raw pointers to the projection args/control types and
// reads the high-level getter — see the per-event private helpers below. Every
// handler.invoke* call is wrapped in try/catch so a HandlerMismatchException
// (or any read failure) never crosses the Invoke FFI boundary.
//
// Projection ABI (verified against windows_sys):
//   - TabView.addSelectionChanged(SelectionChangedEventHandler) /
//     addTabCloseRequested(TypedEventHandler<TabView, TabViewTabCloseRequestedEventArgs>)
//   - NavigationView.addSelectionChanged(TypedEventHandler<NavigationView,
//     NavigationViewSelectionChangedEventArgs>); BackRequested lives only on the
//     raw INavigationView2 interface (no high-level addBackRequested), reached
//     via asINavigationView2().BackRequested(delegate.asRaw(), tokenSlot).
//   - AutoSuggestBox (NavigationView.AutoSuggestBox) addQuerySubmitted /
//     addTextChanged / addSuggestionChosen (TypedEventHandler<AutoSuggestBox, …>).
//   - Pivot.addSelectionChanged(SelectionChangedEventHandler).
//   - SelectorBar.addSelectionChanged(TypedEventHandler<SelectorBar,
//     SelectorBarSelectionChangedEventArgs>); the new value is read from the
//     captured SelectorBar's SelectedItem.Text.
//   - SplitView.addPaneClosed(TypedEventHandler<SplitView, IInspectable>).
//
// No-op / deferred (see report):
//   - BreadcrumbItemClicked: the reference arm is itself a no-op
//     (diag::unhandled_event); BreadcrumbBar item clicks are not wired.
//   - MenuBarItemClicked / CommandBarClick: handled OUTSIDE this dispatch. The
//     backend intercepts them in attachEvent, stashes the handler in its
//     menuClickHandlers registry, wires the existing items immediately
//     (wireMenuBarClicks / wireCommandBarClicks, in props_nav.cj) and re-wires
//     after every item rebuild in setProp. They are therefore unreachable here
//     (the `case _` arm registers nothing, keeping the match exhaustive).
// ============================================================================
func wireNavEvents(handle: Handle, event: Event, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    match ((event, handle)) {
        // ── TabView.SelectionChanged → selected index ─────────────────────────
        case (TabSelectionChanged, TabViewH(_)) =>
            let target = TabView.fromAbiTake(
                queryRequired(handle.asRaw(), TabView.iid(), "Microsoft.UI.Xaml.Controls.ITabView")
            )
            let delegate = SelectionChangedEventHandler.new({ sender, _ =>
                try {
                    let idx = tabViewSelectedIndex(sender)
                    if (idx >= 0) {
                        handler.invokeI32(idx)
                    }
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

        // ── TabView.TabCloseRequested → closed tab key (FrameworkElement.Tag) ──
        case (TabCloseRequested, TabViewH(_)) =>
            let target = TabView.fromAbiTake(
                queryRequired(handle.asRaw(), TabView.iid(), "Microsoft.UI.Xaml.Controls.ITabView")
            )
            let delegate = TypedEventHandler<TabView, TabViewTabCloseRequestedEventArgs>.new({ _, argsRaw =>
                try {
                    handler.invokeString(tabCloseRequestedKey(argsRaw))
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addTabCloseRequested(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeTabCloseRequested(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))

        // ── TabView.AddTabButtonClick → built-in "+" add-tab button click ─────
        case (AddTabButtonClick, TabViewH(_)) =>
            let target = TabView.fromAbiTake(
                queryRequired(handle.asRaw(), TabView.iid(), "Microsoft.UI.Xaml.Controls.ITabView")
            )
            let delegate = TypedEventHandler<TabView, IInspectable>.new({ _, _ =>
                try {
                    handler.invoke()
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addAddTabButtonClick(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeAddTabButtonClick(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))

        // ── NavigationView.SelectionChanged → selected item tag ───────────────
        // Reads the tag from the EVENT ARGS' SelectedItem (args.SelectedItem -> cast
        // NavigationViewItem -> FrameworkElement.Tag -> unbox IReference<HSTRING>),
        // mirroring the reference, but ONLY once the control is Loaded — the nested demo's
        // initial programmatic-selection fire happens during the pre-Loaded templating
        // pass, where reading back into the projection access-violates. A Loaded gate
        // (set by a no-COM-read Loaded delegate) skips that early fire while serving
        // genuine user selections on settled controls (the gallery shell navigation). Once
        // Loaded, any deferred programmatic selection is applied against the realized
        // containers.
        case (NavSelectionChanged, NavigationViewH(_)) =>
            let ownerKey = handle.asRaw().toUIntNative()
            let target = NavigationView.fromAbiTake(
                queryRequired(handle.asRaw(), NavigationView.iid(), "Microsoft.UI.Xaml.Controls.INavigationView")
            )
            let fe = FrameworkElement.fromAbiTake(
                queryRequired(handle.asRaw(), FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement")
            )
            let loadedDelegate = RoutedEventHandler.new({ _, _ =>
                navMarkLoaded(ownerKey)
                try {
                    applyDeferredNavSelection(target, ownerKey)
                } catch (_: Exception) {
                    ()
                }
            })
            let loadedToken = fe.addLoaded(loadedDelegate)
            retainNavDelegate(ownerKey, loadedDelegate)
            let delegate = TypedEventHandler<NavigationView, NavigationViewSelectionChangedEventArgs>.new({ _, argsRaw =>
                try {
                    if (navIsLoaded(ownerKey)) {
                        handler.invokeString(navSelectionTagFromArgs(argsRaw))
                    }
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addSelectionChanged(delegate)
            retainNavDelegate(ownerKey, delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeSelectionChanged(token)
                } catch (_: Exception) {
                    ()
                }
                try {
                    fe.removeLoaded(loadedToken)
                } catch (_: Exception) {
                    ()
                }
                releaseNavDelegates(ownerKey)
                delegate.close()
                loadedDelegate.close()
                target.close()
                fe.close()
            }))

        // ── NavigationView.BackRequested (raw INavigationView2) ───────────────
        case (NavBackRequested, NavigationViewH(_)) =>
            let target = NavigationView.fromAbiTake(
                queryRequired(handle.asRaw(), NavigationView.iid(), "Microsoft.UI.Xaml.Controls.INavigationView")
            )
            // BackRequested has no high-level accessor; QI to the raw
            // INavigationView2 surface and register the delegate's raw pointer.
            let iface = target.asINavigationView2()
            let delegate = TypedEventHandler<NavigationView, NavigationViewBackRequestedEventArgs>.new({ _, _ =>
                try {
                    handler.invoke()
                } catch (_: Exception) {
                    ()
                }
            })
            var token = 0i64
            checkHRESULT(
                unsafe { iface.BackRequested(delegate.asRaw(), CPointer<Int64>(inout token)) },
                "INavigationView2.BackRequested"
            )
            let revokeToken = token
            revokers.add(EventRevoker({ =>
                try {
                    // `iface` (the QI'd INavigationView2 borrow) is captured here so
                    // it stays alive for RemoveBackRequested; it is GC-managed (no
                    // explicit close, mirroring props_nav.cj's interface borrows).
                    checkHRESULT(unsafe { iface.RemoveBackRequested(revokeToken) }, "INavigationView2.RemoveBackRequested")
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))

        // ── NavigationView search box: QuerySubmitted ─────────────────────────
        case (NavSearchQuerySubmitted, NavigationViewH(_)) =>
            let nv = NavigationView.fromAbiTake(
                queryRequired(handle.asRaw(), NavigationView.iid(), "Microsoft.UI.Xaml.Controls.INavigationView")
            )
            let asb = nv.AutoSuggestBox
            if (asb.asRaw().isNotNull()) {
                let delegate = TypedEventHandler<AutoSuggestBox, AutoSuggestBoxQuerySubmittedEventArgs>.new({ _, argsRaw =>
                    try {
                        handler.invokeString(navAutoSuggestQueryText(argsRaw))
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
                    asb.close()
                    nv.close()
                }))
            } else {
                asb.close()
                nv.close()
            }

        // ── NavigationView search box: TextChanged ────────────────────────────
        case (NavSearchTextChanged, NavigationViewH(_)) =>
            let nv = NavigationView.fromAbiTake(
                queryRequired(handle.asRaw(), NavigationView.iid(), "Microsoft.UI.Xaml.Controls.INavigationView")
            )
            let asb = nv.AutoSuggestBox
            if (asb.asRaw().isNotNull()) {
                let delegate = TypedEventHandler<AutoSuggestBox, AutoSuggestBoxTextChangedEventArgs>.new({ senderRaw, _ =>
                    try {
                        handler.invokeString(navAutoSuggestSenderText(senderRaw))
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
                    asb.close()
                    nv.close()
                }))
            } else {
                asb.close()
                nv.close()
            }

        // ── NavigationView search box: SuggestionChosen ───────────────────────
        case (NavSearchSuggestionChosen, NavigationViewH(_)) =>
            let nv = NavigationView.fromAbiTake(
                queryRequired(handle.asRaw(), NavigationView.iid(), "Microsoft.UI.Xaml.Controls.INavigationView")
            )
            let asb = nv.AutoSuggestBox
            if (asb.asRaw().isNotNull()) {
                let delegate = TypedEventHandler<AutoSuggestBox, AutoSuggestBoxSuggestionChosenEventArgs>.new({ _, argsRaw =>
                    try {
                        handler.invokeString(navAutoSuggestChosenItem(argsRaw))
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
                    asb.close()
                    nv.close()
                }))
            } else {
                asb.close()
                nv.close()
            }

        // ── Pivot.SelectionChanged → selected index ───────────────────────────
        case (PivotSelectionChanged, PivotH(_)) =>
            let target = Pivot.fromAbiTake(
                queryRequired(handle.asRaw(), Pivot.iid(), "Microsoft.UI.Xaml.Controls.IPivot")
            )
            let delegate = SelectionChangedEventHandler.new({ sender, _ =>
                try {
                    let idx = pivotSelectedIndex(sender)
                    if (idx >= 0) {
                        handler.invokeI32(idx)
                    }
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

        // ── SelectorBar.SelectionChanged → selected item text ─────────────────
        case (SelectorBarSelectionChanged, SelectorBarH(_)) =>
            let target = SelectorBar.fromAbiTake(
                queryRequired(handle.asRaw(), SelectorBar.iid(), "Microsoft.UI.Xaml.Controls.ISelectorBar")
            )
            // Mirror the reference: the new value is read from the control's
            // SelectedItem (captured), not from the (empty) args object.
            let delegate = TypedEventHandler<SelectorBar, SelectorBarSelectionChangedEventArgs>.new({ _, _ =>
                try {
                    let text = selectorBarSelectedText(target)
                    match (text) {
                        case Some(t) => handler.invokeString(t)
                        case None => ()
                    }
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

        // ── SplitView.PaneClosed ──────────────────────────────────────────────
        case (SplitViewPaneClosed, SplitViewH(_)) =>
            let target = SplitView.fromAbiTake(
                queryRequired(handle.asRaw(), SplitView.iid(), "Microsoft.UI.Xaml.Controls.ISplitView")
            )
            let delegate = TypedEventHandler<SplitView, IInspectable>.new({ _, _ =>
                try {
                    handler.invoke()
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addPaneClosed(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removePaneClosed(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))

        // ── BreadcrumbBar.ItemClicked → clicked crumb index ───────────────────
        // The reference no-ops this event; here the Cangjie BreadcrumbBar
        // projection exposes addItemClicked + Args.Index, so we forward the
        // clicked crumb's index (matching the TabView/Pivot index-event shape).
        case (BreadcrumbItemClicked, BreadcrumbBarH(_)) =>
            let target = BreadcrumbBar.fromAbiTake(
                queryRequired(handle.asRaw(), BreadcrumbBar.iid(), "Microsoft.UI.Xaml.Controls.IBreadcrumbBar")
            )
            let delegate = TypedEventHandler<BreadcrumbBar, BreadcrumbBarItemClickedEventArgs>.new({ _, argsRaw =>
                try {
                    handler.invokeI32(breadcrumbItemClickedIndex(argsRaw))
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addItemClicked(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeItemClicked(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))

        case _ =>
            // MenuBarItemClicked / CommandBarClick: intercepted by the backend in
            // attachEvent (menuClickHandlers registry + per-item wiring driven by
            // setProp), so they never reach this dispatch — see the file header.
            let _ = handle
            let _ = handler
    }
    revokers
}

// ── payload-extraction helpers ──────────────────────────────────────────────
//
// Each takes a RAW sender/args pointer from the delegate closure, QIs it to the
// projection type, and reads the high-level getter. A null pointer or a failed
// QI/getter surfaces as the documented default (the caller's try/catch already
// guards against any thrown WindowsException).

// TabView.SelectedIndex from the SelectionChanged sender (or -1 when absent).
func tabViewSelectedIndex(senderRaw: CPointer<Unit>): Int32 {
    if (senderRaw.isNull()) {
        return -1
    }
    match (unsafe { queryInterfaceRaw(senderRaw, TabView.iid()) }) {
        case Some(raw) =>
            let tv = TabView.fromAbiTake(raw)
            try {
                return tv.SelectedIndex
            } finally {
                tv.close()
            }
        case None => return -1
    }
}

// Closed-tab key from TabViewTabCloseRequestedEventArgs.Tab → the TabViewItem's
// FrameworkElement.Tag (a boxed HString), mirroring the reference traversal.
func tabCloseRequestedKey(argsRaw: CPointer<Unit>): String {
    if (argsRaw.isNull()) {
        return ""
    }
    match (unsafe { queryInterfaceRaw(argsRaw, TabViewTabCloseRequestedEventArgs.iid()) }) {
        case Some(raw) =>
            let args = TabViewTabCloseRequestedEventArgs.fromAbiTake(raw)
            try {
                let tab = args.Tab
                try {
                    if (tab.asRaw().isNull()) {
                        return ""
                    }
                    return navFrameworkElementTag(tab.asRaw())
                } finally {
                    tab.close()
                }
            } finally {
                args.close()
            }
        case None => return ""
    }
}

// Read the newly-selected item's tag from the SelectionChanged EVENT ARGS, mirroring the
// reference handler (backend/mod.rs ~3214): args.SelectedItem -> cast NavigationViewItem
// -> IFrameworkElement.Tag -> unbox IReference<HSTRING>. Reading the args' carried item
// (rather than the sender control's live SelectedItem DP) avoids re-entering WinUI's
// Control::GetValue on the SelectedItem dependency property, which access-violated during
// the nested demo control's template/selection pass. Returns "" when there is no current
// selection or the item carries no NavigationViewItem tag (the gallery callbacks no-op on
// an empty tag, matching the reference's unwrap_or_default()).
func navSelectionTagFromArgs(argsRaw: CPointer<Unit>): String {
    if (argsRaw.isNull()) {
        return ""
    }
    match (unsafe { queryInterfaceRaw(argsRaw, NavigationViewSelectionChangedEventArgs.iid()) }) {
        case Some(raw) =>
            let args = NavigationViewSelectionChangedEventArgs.fromAbiTake(raw)
            try {
                let item = args.SelectedItem
                try {
                    if (item.asRaw().isNull()) {
                        return ""
                    }
                    // Only NavigationViewItems carry a navigation tag (the settings item /
                    // headers do not); match the reference's cast-or-skip.
                    match (unsafe { queryInterfaceRaw(item.asRaw(), NavigationViewItem.iid()) }) {
                        case Some(itemRaw) =>
                            let nvi = NavigationViewItem.fromAbiTake(itemRaw)
                            try {
                                return navFrameworkElementTag(nvi.asRaw())
                            } finally {
                                nvi.close()
                            }
                        case None => return ""
                    }
                } finally {
                    item.close()
                }
            } finally {
                args.close()
            }
        case None => return ""
    }
}

// AutoSuggestBoxQuerySubmittedEventArgs.QueryText.
func navAutoSuggestQueryText(argsRaw: CPointer<Unit>): String {
    if (argsRaw.isNull()) {
        return ""
    }
    match (unsafe { queryInterfaceRaw(argsRaw, AutoSuggestBoxQuerySubmittedEventArgs.iid()) }) {
        case Some(raw) =>
            let args = AutoSuggestBoxQuerySubmittedEventArgs.fromAbiTake(raw)
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
        case None => return ""
    }
}

// AutoSuggestBox.Text from the TextChanged sender (nav search variant fires for
// every change — no reason filter, mirroring the reference nav arm).
func navAutoSuggestSenderText(senderRaw: CPointer<Unit>): String {
    if (senderRaw.isNull()) {
        return ""
    }
    match (unsafe { queryInterfaceRaw(senderRaw, AutoSuggestBox.iid()) }) {
        case Some(raw) =>
            let asb = AutoSuggestBox.fromAbiTake(raw)
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
        case None => return ""
    }
}

// AutoSuggestBoxSuggestionChosenEventArgs.SelectedItem (a boxed HString).
func navAutoSuggestChosenItem(argsRaw: CPointer<Unit>): String {
    if (argsRaw.isNull()) {
        return ""
    }
    match (unsafe { queryInterfaceRaw(argsRaw, AutoSuggestBoxSuggestionChosenEventArgs.iid()) }) {
        case Some(raw) =>
            let args = AutoSuggestBoxSuggestionChosenEventArgs.fromAbiTake(raw)
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
        case None => return ""
    }
}

// Selector.SelectedIndex from the Pivot SelectionChanged sender (or -1). The
// Pivot identity itself exposes SelectedIndex, so QI back to Pivot and read it.
func pivotSelectedIndex(senderRaw: CPointer<Unit>): Int32 {
    if (senderRaw.isNull()) {
        return -1
    }
    match (unsafe { queryInterfaceRaw(senderRaw, Pivot.iid()) }) {
        case Some(raw) =>
            let p = Pivot.fromAbiTake(raw)
            try {
                return p.SelectedIndex
            } finally {
                p.close()
            }
        case None => return -1
    }
}

// SelectorBar.SelectedItem.Text — None when there is no current selection.
func selectorBarSelectedText(sb: SelectorBar): ?String {
    let item = sb.SelectedItem
    try {
        if (item.asRaw().isNull()) {
            return None
        }
        let hs = item.Text
        try {
            return Some(hs.toString())
        } finally {
            hs.close()
        }
    } finally {
        item.close()
    }
}

// BreadcrumbBarItemClickedEventArgs.Index — the zero-based index of the clicked
// crumb (or -1 when the args pointer is null / not a BreadcrumbBar click args).
func breadcrumbItemClickedIndex(argsRaw: CPointer<Unit>): Int32 {
    if (argsRaw.isNull()) {
        return -1
    }
    match (unsafe { queryInterfaceRaw(argsRaw, BreadcrumbBarItemClickedEventArgs.iid()) }) {
        case Some(raw) =>
            let args = BreadcrumbBarItemClickedEventArgs.fromAbiTake(raw)
            try {
                return args.Index
            } finally {
                args.close()
            }
        case None => return -1
    }
}

// Read a control's FrameworkElement.Tag (a boxed IReference<HString>) as a
// String. QI the raw pointer to IFrameworkElement, read Tag, unbox via the
// shared hStringReferenceValue helper (defined in props_nav.cj).
func navFrameworkElementTag(raw: CPointer<Unit>): String {
    let fe = FrameworkElement.fromAbiTake(
        queryRequired(raw, FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement")
    )
    try {
        let boxed = fe.Tag
        try {
            return hStringReferenceValue(boxed.asRaw())
        } finally {
            boxed.close()
        }
    } finally {
        fe.close()
    }
}
