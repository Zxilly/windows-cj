package windows_reactor.winui

import std.collection.{HashMap, ArrayList, HashSet}
import windows_reactor.core.{
    Backend,
    ControlId,
    ControlKind,
    Prop,
    PropValue,
    Event,
    EventKey,
    EventHandler,
    Brush,
    Thickness,
    HorizontalAlignment,
    VerticalAlignment,
    Callback,
    SelectionMode,
    ThemeRef,
    ImplicitTransitions,
    LayoutAnimationConfig,
    AnimationConfig,
    RichTextParagraph,
    AccessibilityModifiers,
    KeyboardAccelerator,
    Tooltip,
    PointerHandlers,
    ReactorDateTime,
    ReactorTimeSpan,
    NativeElement
}
import windows_core.{HString, OutSlot, queryInterfaceRaw}
import windows_interface.{IInspectable}
import windows_sys.Microsoft.UI.Xaml.Controls.{
    Panel, ContentControl, TextBlock, Control, RichTextBlock, Grid, Canvas,
    RelativePanel, TabView, UIElementCollection, Border, Viewbox, ContentDialog
}
import windows_sys.Microsoft.UI.Xaml.{UIElement, FrameworkElement, IUIElement, XamlRoot, Thickness as XamlThickness}
import windows_sys.Microsoft.UI.Xaml.Media.SolidColorBrush
import windows_sys.Microsoft.UI.Xaml.Media.Brush as XamlBrush
import windows_sys.Microsoft.UI.Xaml.Media.FontFamily
import windows_sys.UI.Color as XamlColor
import windows_sys.impl.Windows_UI_Text.{Windows_UI_Text_FontWeight}
import windows_reference.{hStringReference}

// ============================================================================
// HandlerSlot — mutable holder for the live EventHandler of one (control, event)
// registration. Controls that persist across re-renders (notably the shell
// NavigationView) must NOT revoke+re-subscribe their native event every render:
// the reconciler produces a fresh Callback (new identity) per render, so a naive
// attachEvent would re-bind once per navigation. Those accumulated detach/attach
// cycles eventually break native event delivery (~30 renders) and leak kernel
// Event handles. Instead attachEvent subscribes ONCE with a stable forwarding
// handler that reads the slot at fire time, and later renders only swap the
// slot's contents.
// ============================================================================
class HandlerSlot {
    var current: EventHandler
    init(h: EventHandler) { this.current = h }
}

// A stable EventHandler (same variant as the slot's current value) that forwards
// every invocation to whatever handler the slot currently holds. Built once per
// (control, event) and wired into the native event; the slot is swapped on
// subsequent renders so the latest handler runs without re-subscribing. The
// variant is fixed per event (Click -> ClickH, …), so the once-built variant
// stays correct for the lifetime of the registration.
func makeForwardingHandler(slot: HandlerSlot): EventHandler {
    match (slot.current) {
        case ClickH(_) => ClickH(Callback<Unit>({ _ => slot.current.invoke() }))
        case CheckedChangedH(_) => CheckedChangedH(Callback<Bool>({ v => slot.current.invokeBool(v) }))
        case TextChangedH(_) => TextChangedH(Callback<String>({ s => slot.current.invokeString(s) }))
        case ValueChangedH(_) => ValueChangedH(Callback<Float64>({ v => slot.current.invokeF64(v) }))
        case IndexChangedH(_) => IndexChangedH(Callback<Int32>({ v => slot.current.invokeI32(v) }))
        case TabKeyH(_) => TabKeyH(Callback<String>({ s => slot.current.invokeString(s) }))
        case ColorChangedH(_) => ColorChangedH(Callback<(UInt8, UInt8, UInt8, UInt8)>({ c =>
            let (a, r, g, b) = c
            slot.current.invokeColor(a, r, g, b)
        }))
        case DateTimeChangedH(_) => DateTimeChangedH(Callback<ReactorDateTime>({ dt => slot.current.invokeDateTime(dt) }))
        case TimeChangedH(_) => TimeChangedH(Callback<ReactorTimeSpan>({ ts => slot.current.invokeTimeSpan(ts) }))
    }
}

// ============================================================================
// WinUIBackend — imperative backend creating real Microsoft.UI.Xaml controls
// and driving them on the WinUI thread. P4b widened it from the minimal 3-control
// set to the full 61-control dispatch skeleton: a shared setProp pipeline and
// per-family applyXxxProps free functions (the family bodies are filled by
// follow-up agents). Children management dispatches per parent-handle family
// (Panel / single-content / ContentControl / TabView / Pivot), mirroring the
// reference visual_insert_at / visual_remove_at / visual_set_at.
//
// setProp pipeline (mirrors mod.rs set_prop layering, but split for parallel
// fill-in): generic FrameworkElement/UIElement props → font props → attached
// props → resources → per-family applyControlProp.
//
// Property ABI (spec §8.1): high-level class `mut prop` setters where present
// (TextBlock.Text, Panel.Background, …); raw IFrameworkElement/IUIElement HRESULT
// setters for the inherited layout props; static attached-property methods
// (Grid.SetRow, Canvas.SetLeft, RelativePanel.SetAlign*).
// ============================================================================

public class WinUIBackend <: Backend {
    private let controls = HashMap<UInt32, Handle>()
    // One (control, event) registration may install several native handlers
    // (e.g. CheckedChanged = Checked + Unchecked), so each key owns a list of
    // revokers. Keyed by the core EventKey value (id.raw + event tag).
    private let eventRevokers = HashMap<EventKey, ArrayList<EventRevoker>>()
    // Stable forwarding-handler slots, one per (control, event) regular-event
    // registration (NOT the menu/command-bar synthetic events). Lets a control
    // that survives re-renders swap its live handler without re-subscribing the
    // native event. Keyed identically to eventRevokers.
    private let eventSlots = HashMap<EventKey, HandlerSlot>()
    private let parentChildren = HashMap<UInt32, ArrayList<UInt32>>() // logical child mirror
    // Templated-list SelectionChanged revoker, one per list control (separate
    // from eventRevokers because it is owned by the templated path, not
    // attachEvent). Keyed by control raw id.
    private let templatedSelectionRevokers = HashMap<UInt32, EventRevoker>()
    // Per-control pointer-handler revokers (separate surface from eventRevokers
    // because pointer events use the universal IUIElement event surface).
    private let pointerRevokers = HashMap<UInt32, ArrayList<EventRevoker>>()
    // Registry of theme brush bindings per control so they can be re-resolved
    // when the app theme changes (dark <-> light). Stores the control kind (for
    // the Style TargetType) alongside the (Prop, ThemeRef) pairs.
    private let themeBrushRegistry = HashMap<UInt32, (ControlKind, Array<(Prop, ThemeRef)>)>()
    // Stored click handlers for MenuBar / MenuFlyout / CommandBar items so the
    // per-item Click subscriptions can be (re-)wired every time the item
    // collection is rebuilt by setProp. Keyed by the control raw id, mirroring
    // the reference menu_click_handlers / command_bar_flyout_handlers registries.
    // menuClickHandlers covers MenuBarItemClicked (MenuBar), MenuFlyoutItemClicked
    // (Button / DropDownButton flyout) and CommandBarClick (CommandBar);
    // commandBarFlyoutHandlers covers CommandBarFlyoutClick (Button flyout).
    private let menuClickHandlers = HashMap<UInt32, EventHandler>()
    private let commandBarFlyoutHandlers = HashMap<UInt32, EventHandler>()
    // Controls that have had a layout Translation animation started. Only these
    // need (and may safely receive) a StopAnimation at destroy time — calling
    // GetElementVisual on every doomed control would force-create a hand-off
    // visual + CoreMessaging channel traffic per destroyed element.
    private let translationAnimated = HashSet<UInt32>()
    private var nextId: UInt32 = 1

    public init() {}

    private func allocId(): ControlId {
        let id = ControlId(nextId)
        nextId = nextId + 1
        id
    }

    private func handleFor(id: ControlId): Handle {
        match (controls.get(id.raw)) {
            case Some(h) => h
            case None => throw Exception("WinUIBackend: unknown control #${id.raw}")
        }
    }

    // Read-only accessor used by the host to attach the root element into the
    // window. Returns the root control's raw UIElement pointer (non-owning).
    public func uiElementRawOf(id: ControlId): ?CPointer<Unit> {
        match (controls.get(id.raw)) {
            case Some(h) =>
                let ui = h.asUIElement()
                Some(ui.asRaw())
            case None => None
        }
    }

    // Backend interface: surface the live control's native element as an opaque
    // NativeElement token for interop (e.g. the SwapChainPanel on-mounted callback
    // attaching a swap chain). The token carries the control's raw IUIElement
    // pointer as a UIntNative; the winui SwapChainPanelHandle rebuilds the WinRT
    // interop views from it. Non-owning — the live Handle (in `controls`) owns the
    // COM ref. Mirrors the reference WinUIBackend::get_native_element.
    public func getNativeElement(id: ControlId): ?NativeElement {
        match (controls.get(id.raw)) {
            case Some(h) => Some(NativeElement(h.asUIElement().asRaw().toUIntNative()))
            case None => None
        }
    }

    // Locate the live TitleBar control (if any) and return its raw IUIElement
    // pointer (non-owning). Mirrors the reference find_titlebar: the post-render
    // hook uses this to wire the custom title bar into the Window caption / drag
    // region on every root change. Returns None when no TitleBar is mounted.
    public func titleBarUiElementRaw(): ?CPointer<Unit> {
        for ((_, h) in controls) {
            match (h) {
                case TitleBarH(tb) => return Some(tb.asIUIElement().asRaw())
                case _ => ()
            }
        }
        None
    }

    // Diagnostic: describe a control's live state. For a TextBlock its Text; for
    // a Panel its Children.Size; otherwise the kind name. Used by the smoke
    // harness to confirm props/children actually landed on the COM objects.
    public func debugDescribe(id: ControlId): String {
        match (controls.get(id.raw)) {
            case Some(h) =>
                match (h) {
                    case TextBlockH(tb) =>
                        try {
                            let s = tb.Text
                            return "TextBlock text='${s.toString()}'"
                        } catch (e: Exception) {
                            return "TextBlock <text read failed: ${e}>"
                        }
                    case StackPanelH(_) =>
                        try {
                            let n = panelChildrenVec(h).Size
                            return "StackPanel children=${n}"
                        } catch (e: Exception) {
                            return "StackPanel <children read failed: ${e}>"
                        }
                    case _ => return h.kindName()
                }
            case None => return "#${id.raw} unknown"
        }
    }

    // ── Backend core methods ────────────────────────────────────────────────

    public func create(kind: ControlKind): ControlId {
        let id = allocId()
        let handle = makeHandleForKind(kind)
        controls[id.raw] = handle
        parentChildren[id.raw] = ArrayList<UInt32>()
        id
    }

    public func setProp(id: ControlId, which: Prop, value: PropValue): Unit {
        let handle = handleFor(id)
        try {
            // Layered dispatch: the first layer that consumes the prop wins.
            if (applyGenericElementProp(handle, which, value)) {
                return
            }
            if (applyFontProp(handle, which, value)) {
                return
            }
            if (applyAttachedProp(handle, which, value)) {
                return
            }
            if (applyResourcesProp(handle, which, value)) {
                return
            }
            let consumed = applyControlProp(handle, which, value)
            // After a menu / command-bar item collection is rebuilt, re-wire the
            // stored per-item Click handlers against the freshly-built items
            // (mirrors the reference set_prop re-wire blocks). No-op when no click
            // handler was attached to this control.
            if (consumed && isMenuRebuildProp(which)) {
                rewireMenuClicks(id, which)
            }
        } catch (e: Exception) {
            // COM failures must not panic the render loop (spec §8.3).
            println("WinUIBackend.setProp(#${id.raw}, ${which.tag()}) failed: ${e}")
        }
    }

    // Whether `which` rebuilds a menu / command-bar item collection that carries
    // synthesised per-item Click handlers needing re-wiring after the rebuild.
    private func isMenuRebuildProp(which: Prop): Bool {
        match (which) {
            case MenuBarItems | MenuFlyoutItems | CommandBarFlyoutCommands
                | CommandBarPrimaryCommands | CommandBarSecondaryCommands => true
            case _ => false
        }
    }

    public func appendChild(parent: ControlId, child: ControlId): Unit {
        let mirror = childMirror(parent)
        // Visual append index = current count of NON-phantom children (the slot a
        // newly-appended real child lands in). Compute BEFORE pushing the child.
        let vIndex = visualIndex(parent, mirror.size)
        mirror.add(child.raw)
        // Phantom children (ContentDialog) are tracked logically but never
        // inserted into the parent's visual Children (mirrors ref append_child
        // backend/mod.rs:2436-2444).
        if (isPhantomChild(child)) {
            return
        }
        try {
            visualInsertAt(handleFor(parent), vIndex, handleFor(child))
        } catch (e: Exception) {
            println("WinUIBackend.appendChild failed: ${e}")
        }
    }

    public func insertChild(parent: ControlId, index: Int64, child: ControlId): Unit {
        let mirror = childMirror(parent)
        var idx = index
        if (idx < 0) { idx = 0 }
        if (idx > mirror.size) { idx = mirror.size }
        // Translate the logical insert position to a visual one BEFORE mutating
        // the mirror so phantoms before `idx` are counted (mirrors ref
        // insert_child backend/mod.rs:2670-2680).
        let vIndex = visualIndex(parent, idx)
        mirror.add(child.raw, at: idx)
        if (isPhantomChild(child)) {
            return
        }
        try {
            visualInsertAt(handleFor(parent), vIndex, handleFor(child))
        } catch (e: Exception) {
            println("WinUIBackend.insertChild failed: ${e}")
        }
    }

    public func removeChild(parent: ControlId, index: Int64): Unit {
        if (index < 0) {
            return
        }
        // Mirror the reference remove_child (backend/mod.rs:2503-2520): read the
        // phantom flag and the visual index from the CURRENT mirror BEFORE the
        // logical-mirror write, gate ONLY that write on the (possibly
        // already-shrunk) mirror bounds, then perform the visual op
        // unconditionally. The reconciler runs `unmount(old)` BEFORE this call,
        // but destroy does not touch the parent's visual Children; RemoveAt still
        // has to run or the old control stays visible.
        let mirror = childMirror(parent)
        // Phantom check: the ContentDialog at `index` is not in the visual tree,
        // so skip the visual RemoveAt for it (the mirror write still applies).
        var phantom = false
        if (index < mirror.size) {
            match (controls.get(mirror[index])) {
                case Some(ContentDialogH(_)) => phantom = true
                case _ => ()
            }
        }
        let vIndex = visualIndex(parent, index)
        if (index < mirror.size) {
            mirror.remove(at: index)
        }
        if (phantom) {
            return
        }
        try {
            visualRemoveAt(handleFor(parent), vIndex)
        } catch (e: Exception) {
            println("WinUIBackend.removeChild failed: ${e}")
        }
    }

    public func replaceChild(parent: ControlId, index: Int64, newChild: ControlId): Unit {
        if (index < 0) {
            return
        }
        // See removeChild: the reconciler unmounts the old child before calling
        // this, but destroy does not touch the parent's visual Children. Gate only
        // the mirror write on the bounds; always perform the visual op (matching
        // the reference replace_child backend/mod.rs: 2566-2589, which computes
        // the phantom flags + visual index up front and unconditionally touches
        // the visual tree).
        let mirror = childMirror(parent)
        var oldPhantom = false
        if (index < mirror.size) {
            match (controls.get(mirror[index])) {
                case Some(ContentDialogH(_)) => oldPhantom = true
                case _ => ()
            }
        }
        let newPhantom = isPhantomChild(newChild)
        let vIndex = visualIndex(parent, index)
        if (index < mirror.size) {
            mirror[index] = newChild.raw
        }
        try {
            let parentH = handleFor(parent)
            // (old_phantom, new_phantom) cases mirror the reference exactly.
            match ((oldPhantom, newPhantom)) {
                // Both invisible — nothing to do on the visual tree.
                case (true, true) => ()
                // real → phantom: drop the old visual child.
                case (false, true) => visualRemoveAt(parentH, vIndex)
                // phantom → real: insert the new child at the slot the phantom
                // would have occupied if it were real.
                case (true, false) => visualInsertAt(parentH, vIndex, handleFor(newChild))
                // real → real: in-place SetAt.
                case (false, false) => visualSetAt(parentH, vIndex, handleFor(newChild))
            }
        } catch (e: Exception) {
            println("WinUIBackend.replaceChild failed: ${e}")
        }
    }

    public func moveChild(parent: ControlId, fromIndex: Int64, toIndex: Int64): Unit {
        if (fromIndex == toIndex) {
            return
        }
        let mirror = childMirror(parent)
        if (fromIndex < 0 || fromIndex >= mirror.size || toIndex < 0 || toIndex >= mirror.size) {
            return
        }
        // Compute visual indices + phantom flag BEFORE mutating the mirror so
        // phantoms are counted against the pre-move state (mirrors ref move_child
        // backend/mod.rs:2592-2615).
        let vFrom = visualIndex(parent, fromIndex)
        let vTo = visualIndex(parent, toIndex)
        var movedPhantom = false
        match (controls.get(mirror[fromIndex])) {
            case Some(ContentDialogH(_)) => movedPhantom = true
            case _ => ()
        }
        let moved = mirror[fromIndex]
        mirror.remove(at: fromIndex)
        mirror.add(moved, at: toIndex)
        // Phantom moves never touch the visual tree, and a no-op visual move
        // (equal visual indices) is skipped.
        if (movedPhantom || vFrom == vTo) {
            return
        }
        try {
            let parentH = handleFor(parent)
            // Only panel parents support reordering of multiple children;
            // single-content parents have at most one child and need no move.
            match (parentH) {
                case StackPanelH(_) | GridH(_) | CanvasH(_) | RelativePanelH(_) =>
                    let vec = panelChildrenVec(parentH)
                    let element = vec.GetAt(UInt32(vFrom))
                    vec.RemoveAt(UInt32(vFrom))
                    vec.InsertAt(UInt32(vTo), element)
                case TabViewH(tv) =>
                    let items = tv.TabItems
                    var slot = CPointer<Unit>()
                    checkHRESULT(unsafe { items.GetAt(UInt32(vFrom), CPointer<CPointer<Unit>>(inout slot)) }, "TabItems.GetAt")
                    let element = IInspectable.fromAbiTake(slot)
                    try {
                        checkHRESULT(unsafe { items.RemoveAt(UInt32(vFrom)) }, "TabItems.RemoveAt")
                        checkHRESULT(unsafe { items.InsertAt(UInt32(vTo), element.asRaw()) }, "TabItems.InsertAt")
                    } finally {
                        element.close()
                    }
                case _ => ()
            }
        } catch (e: Exception) {
            println("WinUIBackend.moveChild failed: ${e}")
        }
    }

    public func destroy(id: ControlId): Unit {
        // Drop every event registration owned by this control first. Collect the
        // matching keys before mutating the map (avoid invalidating iteration).
        let doomed = ArrayList<EventKey>()
        for ((key, _) in eventRevokers) {
            if (key.idRaw == id.raw) {
                doomed.add(key)
            }
        }
        for (key in doomed) {
            match (eventRevokers.get(key)) {
                case Some(revs) =>
                    for (rev in revs) {
                        rev.close()
                    }
                    eventRevokers.remove(key)
                case None => ()
            }
        }
        // Drop the forwarding slots this control owns (same keying as the
        // eventRevokers just closed).
        let doomedSlots = ArrayList<EventKey>()
        for ((key, _) in eventSlots) {
            if (key.idRaw == id.raw) {
                doomedSlots.add(key)
            }
        }
        for (key in doomedSlots) {
            eventSlots.remove(key)
        }
        // Drop the templated-selection and pointer revokers + theme registry
        // entry this control owns (separate registries from eventRevokers).
        match (templatedSelectionRevokers.get(id.raw)) {
            case Some(rev) =>
                rev.close()
                templatedSelectionRevokers.remove(id.raw)
            case None => ()
        }
        match (pointerRevokers.get(id.raw)) {
            case Some(revs) =>
                for (rev in revs) {
                    rev.close()
                }
                pointerRevokers.remove(id.raw)
            case None => ()
        }
        themeBrushRegistry.remove(id.raw)
        // Drop the stored menu / command-bar click handlers this control owns.
        menuClickHandlers.remove(id.raw)
        commandBarFlyoutHandlers.remove(id.raw)
        // Drop only this control's own logical child list. Parent mirrors are
        // updated by removeChild/replaceChild/moveChild using the reconciler's
        // explicit logical index. Scrubbing this id from every parent here makes
        // those later indexed operations remove or replace the next sibling.
        parentChildren.remove(id.raw)
        match (controls.get(id.raw)) {
            case Some(h) =>
                controls.remove(id.raw)
                if (translationAnimated.contains(id.raw)) {
                    translationAnimated.remove(id.raw)
                    try {
                        animStopLayoutTranslation(h)
                    } catch (_: Exception) {
                        ()
                    }
                }
                match (h) {
                    case NavigationViewH(_) => releaseNavMenuItemsSource(h.asRaw())
                    case _ => ()
                }
                h.close()
            case None => ()
        }
    }

    public func attachEvent(id: ControlId, event: Event, handler: EventHandler): Unit {
        // Menu / command-bar click events are not a single native event: they are
        // synthesised by wiring per-item Click handlers on the (re-buildable) item
        // tree. The handler is stashed in a registry so it can be re-wired on every
        // item rebuild (handled in setProp), mirroring the reference attach_event
        // arms. For MenuBar / CommandBar the items already exist at subscribe time,
        // so the current items are wired immediately as well. These controls live
        // in per-navigation content (never persistent across renders), so revoking
        // + re-stashing the synthesised per-item subscriptions each render is
        // harmless; keep the prior idempotent-rebind behaviour for them.
        match (event) {
            case MenuBarItemClicked | CommandBarClick =>
                detachEvent(id, event)
                menuClickHandlers[id.raw] = handler
                wireMenuClickNow(id, event, handler)
                return
            case MenuFlyoutItemClicked =>
                // No items yet (the flyout is built later by setProp); just stash.
                detachEvent(id, event)
                menuClickHandlers[id.raw] = handler
                return
            case CommandBarFlyoutClick =>
                detachEvent(id, event)
                commandBarFlyoutHandlers[id.raw] = handler
                return
            case _ => ()
        }
        // Regular native event: subscribe ONCE through a stable forwarding handler
        // backed by a mutable slot. On re-render the reconciler hands a fresh
        // Callback identity, but we only swap the slot's handler instead of
        // revoking + re-subscribing — which on a control that persists across
        // renders (the shell NavigationView) would otherwise accumulate detached
        // registrations that break event delivery and leak kernel Event handles.
        let key = EventKey(id, event)
        match (eventSlots.get(key)) {
            case Some(slot) =>
                slot.current = handler
                return
            case None => ()
        }
        let slot = HandlerSlot(handler)
        try {
            let handle = handleFor(id)
            let revs = wireControlEvent(handle, event, makeForwardingHandler(slot))
            if (!revs.isEmpty()) {
                eventRevokers[key] = revs
                eventSlots[key] = slot
            }
        } catch (e: Exception) {
            // FFI registration never panics the render loop (spec §8.3); the
            // delegate wrappers also guard, so this is diagnostics only.
            println("WinUIBackend.attachEvent(#${id.raw}, ${event.tag()}) failed: ${e}")
        }
    }

    // Wire per-item Click handlers on the controls whose items already exist when
    // the click handler is attached (MenuBar / CommandBar). Stores the resulting
    // revokers under (id, event) in the same eventRevokers map detach/destroy
    // sweep so they are released on teardown. MenuFlyout / CommandBarFlyout have
    // no items at attach time, so they are wired only on rebuild (setProp).
    private func wireMenuClickNow(id: ControlId, event: Event, handler: EventHandler): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    let revs = match ((event, h)) {
                        case (MenuBarItemClicked, MenuBarH(mb)) =>
                            wireMenuBarClicks(mb, handler)
                        case (CommandBarClick, CommandBarH(cb)) =>
                            wireCommandBarClicks(cb, handler)
                        case _ => ArrayList<EventRevoker>()
                    }
                    if (!revs.isEmpty()) {
                        eventRevokers[EventKey(id, event)] = revs
                    }
                } catch (e: Exception) {
                    println("WinUIBackend.wireMenuClickNow(#${id.raw}, ${event.tag()}) failed: ${e}")
                }
            case None => ()
        }
    }

    // Re-wire the per-item Click handlers after an item collection has been
    // rebuilt by setProp. Called from setProp for the menu/command-bar rebuild
    // props once the visual item tree has been (re)constructed, mirroring the
    // reference set_prop re-wire blocks. Revokes any prior synthesised
    // subscriptions first (the items they referenced no longer exist), then wires
    // the fresh items and stores the new revokers under (id, synthEvent).
    private func rewireMenuClicks(id: ControlId, which: Prop): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    match (which) {
                        case MenuBarItems =>
                            match (h) {
                                case MenuBarH(mb) =>
                                    match (menuClickHandlers.get(id.raw)) {
                                        case Some(handler) =>
                                            replaceMenuRevokers(id, MenuBarItemClicked, wireMenuBarClicks(mb, handler))
                                        case None => ()
                                    }
                                case _ => ()
                            }
                        case CommandBarPrimaryCommands | CommandBarSecondaryCommands =>
                            // Both primary and secondary commands feed the single
                            // CommandBarClick synthetic event; re-wire the whole bar
                            // so the revoker set stays coherent regardless of which
                            // collection was just rebuilt.
                            match (h) {
                                case CommandBarH(cb) =>
                                    match (menuClickHandlers.get(id.raw)) {
                                        case Some(handler) =>
                                            replaceMenuRevokers(id, CommandBarClick, wireCommandBarClicks(cb, handler))
                                        case None => ()
                                    }
                                case _ => ()
                            }
                        case MenuFlyoutItems =>
                            match (h) {
                                case ButtonH(_) | DropDownButtonH(_) =>
                                    match (menuClickHandlers.get(id.raw)) {
                                        case Some(handler) =>
                                            replaceMenuRevokers(id, MenuFlyoutItemClicked, wireButtonMenuFlyoutClicks(h, handler))
                                        case None => ()
                                    }
                                case _ => ()
                            }
                        case CommandBarFlyoutCommands =>
                            match (h) {
                                case ButtonH(_) =>
                                    match (commandBarFlyoutHandlers.get(id.raw)) {
                                        case Some(handler) =>
                                            replaceMenuRevokers(id, CommandBarFlyoutClick, wireButtonCommandBarFlyoutClicks(h, handler))
                                        case None => ()
                                    }
                                case _ => ()
                            }
                        case _ => ()
                    }
                } catch (e: Exception) {
                    println("WinUIBackend.rewireMenuClicks(#${id.raw}, ${which.tag()}) failed: ${e}")
                }
            case None => ()
        }
    }

    // Replace the synthesised click revokers for (id, synthEvent): close the
    // previous set (the items it referenced were just torn down by the rebuild)
    // and store the new set (only if non-empty, matching the reference's
    // insert-only-when-not-empty behaviour).
    private func replaceMenuRevokers(id: ControlId, synthEvent: Event, revs: ArrayList<EventRevoker>): Unit {
        let key = EventKey(id, synthEvent)
        match (eventRevokers.get(key)) {
            case Some(old) =>
                for (rev in old) {
                    rev.close()
                }
                eventRevokers.remove(key)
            case None => ()
        }
        if (!revs.isEmpty()) {
            eventRevokers[key] = revs
        }
    }

    public func detachEvent(id: ControlId, event: Event): Unit {
        let key = EventKey(id, event)
        match (eventRevokers.get(key)) {
            case Some(revs) =>
                for (rev in revs) {
                    rev.close()
                }
                eventRevokers.remove(key)
            case None => ()
        }
        // Drop the forwarding slot too, so a later re-attach subscribes afresh
        // (no-op for menu/command-bar events, which never own a slot).
        eventSlots.remove(key)
    }

    // ── Backend misc methods (templated / theme / header-pane / richtext /
    //    animation / accessibility) ───────────────────────────────────────────
    // Each is a thin delegate: resolve the control's Handle (and any auxiliary
    // handles) then call the matching family free function. Every call is wrapped
    // in a try-catch so a COM failure prints a diagnostic instead of panicking the
    // render loop (spec §8.3), mirroring setProp / attachEvent.

    public func setTemplatedItemCount(id: ControlId, count: Int64): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    templatedSetItemCount(h, count)
                } catch (e: Exception) {
                    println("WinUIBackend.setTemplatedItemCount(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setTemplatedRowContent(listId: ControlId, rowIdx: Int64, content: ?ControlId): Unit {
        match (controls.get(listId.raw)) {
            case Some(h) =>
                let contentH = resolveOpt(content)
                try {
                    templatedSetRowContent(h, rowIdx, contentH)
                } catch (e: Exception) {
                    println("WinUIBackend.setTemplatedRowContent(#${listId.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setTemplatedSelectedIndex(id: ControlId, index: Int32): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    templatedSetSelectedIndex(h, index)
                } catch (e: Exception) {
                    println("WinUIBackend.setTemplatedSelectedIndex(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setTemplatedSelectionMode(id: ControlId, mode: SelectionMode): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    templatedSetSelectionMode(h, mode)
                } catch (e: Exception) {
                    println("WinUIBackend.setTemplatedSelectionMode(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func scrollTemplatedToIndex(id: ControlId, index: Int32): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    templatedScrollToIndex(h, index)
                } catch (e: Exception) {
                    println("WinUIBackend.scrollTemplatedToIndex(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func attachTemplatedSelectionChanged(id: ControlId, handler: Callback<Int32>): Unit {
        // Re-attaching revokes the old subscription first (idempotent rebind).
        match (templatedSelectionRevokers.get(id.raw)) {
            case Some(rev) =>
                rev.close()
                templatedSelectionRevokers.remove(id.raw)
            case None => ()
        }
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    match (templatedAttachSelectionChanged(h, handler)) {
                        case Some(rev) => templatedSelectionRevokers[id.raw] = rev
                        case None => ()
                    }
                } catch (e: Exception) {
                    println("WinUIBackend.attachTemplatedSelectionChanged(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func attachTemplatedRealization(id: ControlId, realize: (Int64) -> Unit, recycle: (Int64) -> Unit): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    templatedAttachRealization(h, realize, recycle)
                } catch (e: Exception) {
                    println("WinUIBackend.attachTemplatedRealization(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setHeaderElement(id: ControlId, headerId: ?ControlId): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                let headerH = resolveOpt(headerId)
                try {
                    headerSetElement(h, headerH)
                } catch (e: Exception) {
                    println("WinUIBackend.setHeaderElement(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setPaneElement(id: ControlId, paneId: ?ControlId): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                let paneH = resolveOpt(paneId)
                try {
                    paneSetElement(h, paneH)
                } catch (e: Exception) {
                    println("WinUIBackend.setPaneElement(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setThemeBindings(id: ControlId, kind: ControlKind, bindings: Array<(Prop, ThemeRef)>): Unit {
        // Record the bindings so onThemeChanged can re-resolve them, then apply.
        themeBrushRegistry[id.raw] = (kind, bindings)
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    themeApplyBindings(h, kind, bindings)
                } catch (e: Exception) {
                    println("WinUIBackend.setThemeBindings(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func onThemeChanged(): Unit {
        try {
            themeReapplyAll(controls, themeBrushRegistry)
        } catch (e: Exception) {
            println("WinUIBackend.onThemeChanged failed: ${e}")
        }
    }

    public func setImplicitTransitions(id: ControlId, transitions: ?ImplicitTransitions): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    animSetImplicitTransitions(h, transitions)
                } catch (e: Exception) {
                    println("WinUIBackend.setImplicitTransitions(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setLayoutAnimation(id: ControlId, config: ?LayoutAnimationConfig): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    animSetLayout(h, config)
                } catch (e: Exception) {
                    println("WinUIBackend.setLayoutAnimation(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func runLayoutTranslationAnimation(id: ControlId, dx: Float64, dy: Float64,
                                              config: LayoutAnimationConfig): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    animRunLayoutTranslation(h, dx, dy, config)
                    translationAnimated.add(id.raw)
                } catch (e: Exception) {
                    println("WinUIBackend.runLayoutTranslationAnimation(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    // Clear a residual layout-translation offset for a control that is now at rest
    // (its slide has settled / was superseded). No-op unless the control actually
    // ran a translation animation, and it is dropped from the tracking set so this
    // stays one reset per completed slide rather than per render.
    public func snapLayoutTranslationAtRest(id: ControlId): Unit {
        if (!translationAnimated.contains(id.raw)) {
            return
        }
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    animSnapLayoutTranslation(h)
                    translationAnimated.remove(id.raw)
                } catch (e: Exception) {
                    println("WinUIBackend.snapLayoutTranslationAtRest(#${id.raw}) failed: ${e}")
                }
            case None => translationAnimated.remove(id.raw)
        }
    }

    public func runPropertyAnimation(id: ControlId, config: ?AnimationConfig): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    animRunProperty(h, config)
                } catch (e: Exception) {
                    println("WinUIBackend.runPropertyAnimation(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setRichTextParagraphs(id: ControlId, paragraphs: Array<RichTextParagraph>): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    richTextApply(h, paragraphs)
                } catch (e: Exception) {
                    println("WinUIBackend.setRichTextParagraphs(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setAccessibility(id: ControlId, accessibility: AccessibilityModifiers): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    a11ySetAccessibility(h, accessibility)
                } catch (e: Exception) {
                    println("WinUIBackend.setAccessibility(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setKeyboardAccelerators(id: ControlId, accelerators: Array<KeyboardAccelerator>): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    a11ySetKeyboardAccelerators(h, accelerators)
                } catch (e: Exception) {
                    println("WinUIBackend.setKeyboardAccelerators(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setTooltip(id: ControlId, tooltip: ?Tooltip): Unit {
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    a11ySetTooltip(h, tooltip)
                } catch (e: Exception) {
                    println("WinUIBackend.setTooltip(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    public func setPointerHandlers(id: ControlId, handlers: ?PointerHandlers): Unit {
        // Re-wiring revokes the prior pointer subscriptions first.
        match (pointerRevokers.get(id.raw)) {
            case Some(revs) =>
                for (rev in revs) {
                    rev.close()
                }
                pointerRevokers.remove(id.raw)
            case None => ()
        }
        match (controls.get(id.raw)) {
            case Some(h) =>
                try {
                    let revs = a11ySetPointerHandlers(h, handlers)
                    if (!revs.isEmpty()) {
                        pointerRevokers[id.raw] = revs
                    }
                } catch (e: Exception) {
                    println("WinUIBackend.setPointerHandlers(#${id.raw}) failed: ${e}")
                }
            case None => ()
        }
    }

    // Resolve an optional ControlId into an optional live Handle (None when the
    // id is absent or refers to an unknown / destroyed control).
    private func resolveOpt(maybeId: ?ControlId): ?Handle {
        match (maybeId) {
            case Some(cid) => controls.get(cid.raw)
            case None => None
        }
    }

    // Dispatch an event subscription to the matching family wiring function,
    // returning the revoker(s) that own the registration (empty when the event
    // is not yet wired). Exhaustive over every Event variant — the compiler
    // flags any new variant so it can be slotted into a family.
    private func wireControlEvent(handle: Handle, event: Event, handler: EventHandler): ArrayList<EventRevoker> {
        match (event) {
            case Click | SplitButtonClick | MenuFlyoutItemClicked | CommandBarFlyoutClick =>
                wireButtonEvents(handle, event, handler)
            case CheckedChanged | Toggled | ValueChanged | RadioChecked | RatingValueChanged =>
                wireInputEvents(handle, event, handler)
            case TextChanged | PasswordChanged | RichEditBoxTextChanged | AutoSuggestTextChanged
                | AutoSuggestQuerySubmitted | AutoSuggestSuggestionChosen =>
                wireTextEvents(handle, event, handler)
            case ComboSelectionChanged | ListBoxSelectionChanged | TreeViewItemInvoked
                | RadioButtonsSelectionChanged =>
                wireListEvents(handle, event, handler)
            case TabSelectionChanged | TabCloseRequested | AddTabButtonClick | NavSelectionChanged
                | NavBackRequested | NavSearchQuerySubmitted | NavSearchTextChanged
                | NavSearchSuggestionChosen | PivotSelectionChanged | BreadcrumbItemClicked
                | SelectorBarSelectionChanged | MenuBarItemClicked | CommandBarClick
                | SplitViewPaneClosed =>
                wireNavEvents(handle, event, handler)
            case ColorChanged | DateSelected | TimeSelected | CalendarDateSelected
                | CalendarViewSelectionChanged =>
                wirePickerEvents(handle, event, handler)
            case ExpandedChanged | InfoBarClosed | ContentDialogClosed | TeachingTipClosed
                | TeachingTipActionClick | TitleBarBackRequested | TitleBarPaneToggle
                | FlyoutOpened | FlyoutClosed =>
                wireDialogEvents(handle, event, handler)
        }
    }

    // ── child container dispatch ──────────────────────────────────────────────

    private func childMirror(parent: ControlId): ArrayList<UInt32> {
        match (parentChildren.get(parent.raw)) {
            case Some(m) => m
            case None =>
                let m = ArrayList<UInt32>()
                parentChildren[parent.raw] = m
                m
        }
    }

    // Whether this control is a "phantom" child — tracked in the logical mirror
    // but never attached under its parent's visual Children. Only ContentDialog
    // qualifies today (it is hosted modally via ShowAsync, and WinUI rejects a
    // ContentDialog inside a Panel.Children). Mirrors the reference
    // is_phantom_child (backend/mod.rs:199-204).
    private func isPhantomChild(id: ControlId): Bool {
        match (controls.get(id.raw)) {
            case Some(ContentDialogH(_)) => true
            case _ => false
        }
    }

    // Logical→visual child index translation that skips phantom children:
    // the count of NON-phantom children before `logical` in the parent's child
    // list. Mirrors the reference visual_index (backend/mod.rs:206-216).
    private func visualIndex(parent: ControlId, logical: Int64): Int64 {
        let list = childMirror(parent)
        var count = 0
        var i = 0
        while (i < logical && i < list.size) {
            match (controls.get(list[i])) {
                case Some(ContentDialogH(_)) => ()
                case _ => count = count + 1
            }
            i = i + 1
        }
        count
    }

    // The Children IVector wrapper for a panel parent. QI to the high-level Panel
    // projection to read .Children (a UIElementCollection that is itself the
    // IVector<UIElement>).
    private func panelChildrenVec(parentH: Handle): UIElementCollection {
        let panel = Panel.fromAbiTake(
            queryRequired(parentH.asRaw(), Panel.iid(), "Microsoft.UI.Xaml.Controls.IPanel")
        )
        try {
            return panel.Children
        } finally {
            panel.close()
        }
    }

    // The UIElementCollection vector takes the high-level UIElement class (not
    // the IUIElement interface). QI the child's identity to UIElement.
    private func childUIElement(childH: Handle): UIElement {
        UIElement.fromAbiTake(
            queryRequired(childH.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")
        )
    }

    // Insert `child` at visual index `vIndex` under `parentH`. Mirrors the
    // reference visual_insert_at container dispatch.
    private func visualInsertAt(parentH: Handle, vIndex: Int64, childH: Handle): Unit {
        match (parentH) {
            case StackPanelH(_) | GridH(_) | CanvasH(_) | RelativePanelH(_) =>
                let vec = panelChildrenVec(parentH)
                let child = childUIElement(childH)
                try { vec.InsertAt(UInt32(vIndex), child) } finally { child.close() }
            case BorderH(b) =>
                let child = childUIElement(childH)
                try { b.Child = child } finally { child.close() }
            case ViewboxH(v) =>
                let child = childUIElement(childH)
                try { v.SetChild(child) } finally { child.close() }
            case ScrollViewerH(_) | ExpanderH(_) | TabViewItemH(_)
                | NavigationViewH(_) | PivotItemH(_) =>
                // childUIElement returns an OWNED wrapper; close it after the setter AddRefs.
                let child = childUIElement(childH)
                try { setContentControlContent(parentH.asRaw(), child.asIInspectable()) } finally { child.close() }
            case ScrollViewH(sv) =>
                let child = childUIElement(childH)
                try { sv.Content = child } finally { child.close() }
            case TabViewH(tv) =>
                let child = childUIElement(childH)
                try {
                    checkHRESULT(unsafe { tv.TabItems.InsertAt(UInt32(vIndex), child.asRaw()) }, "TabItems.InsertAt")
                } finally {
                    child.close()
                }
            case PivotH(_) =>
                // Pivot pages live in IItemsControl.Items (IVector<IInspectable>),
                // mirroring the TabView arm above and the reference Pivot case.
                let vec = itemsControlItemsVector(parentH)
                let child = childUIElement(childH)
                try {
                    checkHRESULT(unsafe { vec.InsertAt(UInt32(vIndex), child.asRaw()) }, "Pivot.Items.InsertAt")
                } finally {
                    child.close()
                    vec.close()
                }
            case _ =>
                println("WinUIBackend.visualInsertAt: ${parentH.kindName()} is not a container")
        }
    }

    // Remove the child at visual index `vIndex` under `parentH`.
    private func visualRemoveAt(parentH: Handle, vIndex: Int64): Unit {
        match (parentH) {
            case StackPanelH(_) | GridH(_) | CanvasH(_) | RelativePanelH(_) =>
                panelChildrenVec(parentH).RemoveAt(UInt32(vIndex))
            case BorderH(b) =>
                b.Child = UIElement.viewOf(CPointer<Unit>())
            case ViewboxH(v) =>
                v.SetChild(UIElement.viewOf(CPointer<Unit>()))
            case ScrollViewerH(_) | ExpanderH(_) | TabViewItemH(_)
                | NavigationViewH(_) | PivotItemH(_) =>
                clearContentControlContent(parentH.asRaw())
            case ScrollViewH(sv) =>
                sv.Content = UIElement.viewOf(CPointer<Unit>())
            case TabViewH(tv) =>
                checkHRESULT(unsafe { tv.TabItems.RemoveAt(UInt32(vIndex)) }, "TabItems.RemoveAt")
            case PivotH(_) =>
                let vec = itemsControlItemsVector(parentH)
                try {
                    checkHRESULT(unsafe { vec.RemoveAt(UInt32(vIndex)) }, "Pivot.Items.RemoveAt")
                } finally {
                    vec.close()
                }
            case _ =>
                println("WinUIBackend.visualRemoveAt: ${parentH.kindName()} is not a container")
        }
    }

    // In-place replace the child at visual index `vIndex` under `parentH`.
    private func visualSetAt(parentH: Handle, vIndex: Int64, newH: Handle): Unit {
        match (parentH) {
            case StackPanelH(_) | GridH(_) | CanvasH(_) | RelativePanelH(_) =>
                let vec = panelChildrenVec(parentH)
                let child = childUIElement(newH)
                try { vec.SetAt(UInt32(vIndex), child) } finally { child.close() }
            case BorderH(b) =>
                let child = childUIElement(newH)
                try { b.Child = child } finally { child.close() }
            case ViewboxH(v) =>
                let child = childUIElement(newH)
                try { v.SetChild(child) } finally { child.close() }
            case ScrollViewerH(_) | ExpanderH(_) | TabViewItemH(_)
                | NavigationViewH(_) | PivotItemH(_) =>
                let child = childUIElement(newH)
                try { setContentControlContent(parentH.asRaw(), child.asIInspectable()) } finally { child.close() }
            case ScrollViewH(sv) =>
                let child = childUIElement(newH)
                try { sv.Content = child } finally { child.close() }
            case TabViewH(tv) =>
                let newChild = childUIElement(newH)
                try {
                    checkHRESULT(unsafe { tv.TabItems.SetAt(UInt32(vIndex), newChild.asRaw()) }, "TabItems.SetAt")
                } finally {
                    newChild.close()
                }
            case PivotH(_) =>
                let vec = itemsControlItemsVector(parentH)
                let newChild = childUIElement(newH)
                try {
                    checkHRESULT(unsafe { vec.SetAt(UInt32(vIndex), newChild.asRaw()) }, "Pivot.Items.SetAt")
                } finally {
                    newChild.close()
                    vec.close()
                }
            case _ =>
                println("WinUIBackend.visualSetAt: ${parentH.kindName()} is not a container")
        }
    }

    private func setContentControlContent(raw: CPointer<Unit>, content: IInspectable): Unit {
        let cc = ContentControl.fromAbiTake(
            queryRequired(raw, ContentControl.iid(), "Microsoft.UI.Xaml.Controls.IContentControl")
        )
        try {
            cc.Content = content
        } finally {
            cc.close()
        }
    }

    private func clearContentControlContent(raw: CPointer<Unit>): Unit {
        let cc = ContentControl.fromAbiTake(
            queryRequired(raw, ContentControl.iid(), "Microsoft.UI.Xaml.Controls.IContentControl")
        )
        try {
            cc.Content = IInspectable.viewOf(CPointer<Unit>())
        } finally {
            cc.close()
        }
    }

    // QI a control's raw pointer to the high-level UIElement class (the surface
    // carrying the XamlRoot getter/setter). Returns None when the QI fails.
    private func uiElementClassOf(raw: CPointer<Unit>): ?UIElement {
        try {
            Some(UIElement.fromAbiTake(
                queryRequired(raw, UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")
            ))
        } catch (_: Exception) {
            None
        }
    }

    // Open or close a ContentDialog. Mirrors the reference ContentDialogIsOpen
    // arm (backend/mod.rs:1395-1441): on open, discover a XamlRoot from any live
    // sibling element (the dialog itself is out-of-tree / phantom, so it has none
    // yet), assign it to the dialog and ShowAsync; on close, Hide.
    private func setContentDialogOpen(d: ContentDialog, open: Bool): Unit {
        if (!open) {
            try {
                d.Hide()
            } catch (e: Exception) {
                println("WinUIBackend: ContentDialog.Hide failed: ${e}")
            }
            return
        }
        // Find the first non-ContentDialog control's XamlRoot. A control not yet
        // in a live visual tree returns a null XamlRoot, so skip those.
        var root: ?XamlRoot = None
        for ((_, h) in controls) {
            match (h) {
                case ContentDialogH(_) => continue
                case _ => ()
            }
            match (uiElementClassOf(h.asRaw())) {
                case Some(ui) =>
                    try {
                        let xr = ui.XamlRoot
                        if (xr.asRaw().isNotNull()) {
                            root = Some(xr)
                            ui.close()
                            break
                        }
                        xr.close()
                    } catch (_: Exception) {
                        ()
                    }
                    ui.close()
                case None => ()
            }
        }
        match (root) {
            case Some(r) =>
                try {
                    match (uiElementClassOf(d.asRaw())) {
                        case Some(dui) =>
                            try {
                                dui.XamlRoot = r
                            } finally {
                                dui.close()
                            }
                        case None =>
                            println("WinUIBackend: ContentDialog.SetXamlRoot failed: QI to IUIElement")
                    }
                } catch (e: Exception) {
                    println("WinUIBackend: ContentDialog.SetXamlRoot failed: ${e}")
                }
                try {
                    // ShowAsync returns an IAsyncOperation; the result is delivered
                    // through the separately-wired Closed event (matching the
                    // reference, which also fire-and-forgets ShowAsync). Drop the
                    // owned async-op handle immediately.
                    let op = d.ShowAsync()
                    op.close()
                } catch (e: Exception) {
                    println("WinUIBackend: ContentDialog.ShowAsync failed: ${e}")
                }
                r.close()
            case None =>
                // No XamlRoot available — no-op (the reference logs this in debug).
                println("WinUIBackend: ContentDialog.isOpen ignored — no XamlRoot available")
        }
    }

    // ── setProp dispatch layers ───────────────────────────────────────────────

    // Layer 1 — generic FrameworkElement / UIElement props applied via the raw
    // IFrameworkElement / IUIElement HRESULT setters. Unset restores the WinUI
    // default (Width→NaN, MaxWidth/MaxHeight→+inf, Align→Stretch, Opacity→1.0).
    // Returns whether the prop was handled here.
    private func applyGenericElementProp(handle: Handle, which: Prop, value: PropValue): Bool {
        // asFrameworkElement()/asUIElement() return OWNED QI'd wrappers; close in `finally`
        // so layout props don't leak a COM ref per control per mount (part of the
        // per-navigation native leak: the old page's controls stay pinned otherwise).
        match (which) {
            case Width =>
                let fe = handle.asFrameworkElement()
                try {
                    match (value) {
                        case F64(v) => checkHRESULT(unsafe { fe.SetWidth(v) }, "SetWidth")
                        case Unset => checkHRESULT(unsafe { fe.SetWidth(Float64.NaN) }, "SetWidth")
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case Height =>
                let fe = handle.asFrameworkElement()
                try {
                    match (value) {
                        case F64(v) => checkHRESULT(unsafe { fe.SetHeight(v) }, "SetHeight")
                        case Unset => checkHRESULT(unsafe { fe.SetHeight(Float64.NaN) }, "SetHeight")
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case MinWidth =>
                let fe = handle.asFrameworkElement()
                try {
                    match (value) {
                        case F64(v) => checkHRESULT(unsafe { fe.SetMinWidth(v) }, "SetMinWidth")
                        case Unset => checkHRESULT(unsafe { fe.SetMinWidth(0.0) }, "SetMinWidth")
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case MaxWidth =>
                let fe = handle.asFrameworkElement()
                try {
                    match (value) {
                        case F64(v) => checkHRESULT(unsafe { fe.SetMaxWidth(v) }, "SetMaxWidth")
                        case Unset => checkHRESULT(unsafe { fe.SetMaxWidth(Float64.Inf) }, "SetMaxWidth")
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case MinHeight =>
                let fe = handle.asFrameworkElement()
                try {
                    match (value) {
                        case F64(v) => checkHRESULT(unsafe { fe.SetMinHeight(v) }, "SetMinHeight")
                        case Unset => checkHRESULT(unsafe { fe.SetMinHeight(0.0) }, "SetMinHeight")
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case MaxHeight =>
                let fe = handle.asFrameworkElement()
                try {
                    match (value) {
                        case F64(v) => checkHRESULT(unsafe { fe.SetMaxHeight(v) }, "SetMaxHeight")
                        case Unset => checkHRESULT(unsafe { fe.SetMaxHeight(Float64.Inf) }, "SetMaxHeight")
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case Margin =>
                let fe = handle.asFrameworkElement()
                try {
                    match (value) {
                        case ThicknessV(t) => checkHRESULT(unsafe { fe.SetMargin(toXamlThickness(t)) }, "SetMargin")
                        case Unset => checkHRESULT(unsafe { fe.SetMargin(XamlThickness()) }, "SetMargin")
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case HorizontalAlignment =>
                let fe = handle.asFrameworkElement()
                try {
                    match (value) {
                        case HAlign(a) => checkHRESULT(unsafe { fe.SetHorizontalAlignment(Int32(a.tag())) }, "SetHorizontalAlignment")
                        case Unset => checkHRESULT(unsafe { fe.SetHorizontalAlignment(3) }, "SetHorizontalAlignment") // Stretch
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case VerticalAlignment =>
                let fe = handle.asFrameworkElement()
                try {
                    match (value) {
                        case VAlign(a) => checkHRESULT(unsafe { fe.SetVerticalAlignment(Int32(a.tag())) }, "SetVerticalAlignment")
                        case Unset => checkHRESULT(unsafe { fe.SetVerticalAlignment(3) }, "SetVerticalAlignment") // Stretch
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case Opacity =>
                let ui = handle.asUIElement()
                try {
                    match (value) {
                        case F64(v) => checkHRESULT(unsafe { ui.SetOpacity(v) }, "SetOpacity")
                        case Unset => checkHRESULT(unsafe { ui.SetOpacity(1.0) }, "SetOpacity")
                        case _ => return false
                    }
                } finally { ui.close() }
                true
            case _ => false
        }
    }

    // Layer 2 — font props with multi-interface probing. Tries the high-level
    // Control, then TextBlock, then RichTextBlock surface (whichever the control
    // exposes). Returns whether the prop was handled.
    private func applyFontProp(handle: Handle, which: Prop, value: PropValue): Bool {
        match (which) {
            case FontSize =>
                let v = match (value) {
                    case F64(x) => x
                    case Unset => 14.0
                    case _ => return false
                }
                applyFontSizeProbe(handle, v)
                true
            case FontWeight =>
                let w = match (value) {
                    case U16(x) => x
                    case Unset => 400u16
                    case _ => return false
                }
                applyFontWeightProbe(handle, w)
                true
            case FontFamily =>
                let name = match (value) {
                    case Str(s) => s
                    case Unset => "Segoe UI"
                    case _ => return false
                }
                applyFontFamilyProbe(handle, name)
                true
            case _ => false
        }
    }

    private func applyFontSizeProbe(handle: Handle, v: Float64): Unit {
        match (controlSurface(handle)) {
            case Some(c) => try { c.FontSize = v } finally { c.close() }
            case None =>
                match (textBlockSurface(handle)) {
                    case Some(tb) => try { tb.FontSize = v } finally { tb.close() }
                    case None =>
                        match (richTextBlockSurface(handle)) {
                            case Some(rtb) => try { rtb.FontSize = v } finally { rtb.close() }
                            case None => ()
                        }
                }
        }
    }

    private func applyFontWeightProbe(handle: Handle, weight: UInt16): Unit {
        var fw = Windows_UI_Text_FontWeight()
        fw.Weight = weight
        match (controlSurface(handle)) {
            case Some(c) => try { c.FontWeight = fw } finally { c.close() }
            case None =>
                match (textBlockSurface(handle)) {
                    case Some(tb) => try { tb.FontWeight = fw } finally { tb.close() }
                    case None =>
                        match (richTextBlockSurface(handle)) {
                            case Some(rtb) => try { rtb.FontWeight = fw } finally { rtb.close() }
                            case None => ()
                        }
                }
        }
    }

    private func applyFontFamilyProbe(handle: Handle, name: String): Unit {
        let ff = makeFontFamily(name)
        try {
            match (controlSurface(handle)) {
                case Some(c) => try { c.FontFamily = ff } finally { c.close() }
                case None =>
                    match (textBlockSurface(handle)) {
                        case Some(tb) => try { tb.FontFamily = ff } finally { tb.close() }
                        case None =>
                            match (richTextBlockSurface(handle)) {
                                case Some(rtb) => try { rtb.FontFamily = ff } finally { rtb.close() }
                                case None => ()
                            }
                    }
            }
        } finally {
            ff.close()
        }
    }

    // QI the handle to the high-level Control surface (font props on Control
    // derivatives), or None when the control is not Control-derived.
    private func controlSurface(handle: Handle): ?Control {
        match (unsafe { queryInterfaceRaw(handle.asRaw(), Control.iid()) }) {
            case Some(raw) => Some(Control.fromAbiTake(raw))
            case None => None
        }
    }

    private func textBlockSurface(handle: Handle): ?TextBlock {
        match (unsafe { queryInterfaceRaw(handle.asRaw(), TextBlock.iid()) }) {
            case Some(raw) => Some(TextBlock.fromAbiTake(raw))
            case None => None
        }
    }

    private func richTextBlockSurface(handle: Handle): ?RichTextBlock {
        match (unsafe { queryInterfaceRaw(handle.asRaw(), RichTextBlock.iid()) }) {
            case Some(raw) => Some(RichTextBlock.fromAbiTake(raw))
            case None => None
        }
    }

    // Layer 3 — attached layout properties applied to the control via the static
    // attached-property setters on the parent panel type (Grid / Canvas /
    // RelativePanel). The attached prop targets the control itself (`handle`).
    // Returns whether the prop was handled.
    private func applyAttachedProp(handle: Handle, which: Prop, value: PropValue): Bool {
        // frameworkElementOf/uiElementOf return OWNED QI'd wrappers — bind once + close.
        match (which) {
            case AttachedGridRow =>
                let fe = frameworkElementOf(handle)
                try {
                    match (value) {
                        case I32(v) => Grid.SetRow(fe, v)
                        case Unset => Grid.SetRow(fe, 0)
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case AttachedGridColumn =>
                let fe = frameworkElementOf(handle)
                try {
                    match (value) {
                        case I32(v) => Grid.SetColumn(fe, v)
                        case Unset => Grid.SetColumn(fe, 0)
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case AttachedGridRowSpan =>
                let fe = frameworkElementOf(handle)
                try {
                    match (value) {
                        case I32(v) => Grid.SetRowSpan(fe, v)
                        case Unset => Grid.SetRowSpan(fe, 1)
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case AttachedGridColumnSpan =>
                let fe = frameworkElementOf(handle)
                try {
                    match (value) {
                        case I32(v) => Grid.SetColumnSpan(fe, v)
                        case Unset => Grid.SetColumnSpan(fe, 1)
                        case _ => return false
                    }
                } finally { fe.close() }
                true
            case AttachedCanvasLeft =>
                let ui = uiElementOf(handle)
                try {
                    match (value) {
                        case F64(v) => Canvas.SetLeft(ui, v)
                        case Unset => Canvas.SetLeft(ui, 0.0)
                        case _ => return false
                    }
                } finally { ui.close() }
                true
            case AttachedCanvasTop =>
                let ui = uiElementOf(handle)
                try {
                    match (value) {
                        case F64(v) => Canvas.SetTop(ui, v)
                        case Unset => Canvas.SetTop(ui, 0.0)
                        case _ => return false
                    }
                } finally { ui.close() }
                true
            case AttachedCanvasZIndex =>
                let ui = uiElementOf(handle)
                try {
                    match (value) {
                        case I32(v) => Canvas.SetZIndex(ui, v)
                        case Unset => Canvas.SetZIndex(ui, 0)
                        case _ => return false
                    }
                } finally { ui.close() }
                true
            case RelativePanelAlignLeftWithPanel =>
                applyRelAlign(handle, value, { ui, b => RelativePanel.SetAlignLeftWithPanel(ui, b) })
            case RelativePanelAlignRightWithPanel =>
                applyRelAlign(handle, value, { ui, b => RelativePanel.SetAlignRightWithPanel(ui, b) })
            case RelativePanelAlignTopWithPanel =>
                applyRelAlign(handle, value, { ui, b => RelativePanel.SetAlignTopWithPanel(ui, b) })
            case RelativePanelAlignBottomWithPanel =>
                applyRelAlign(handle, value, { ui, b => RelativePanel.SetAlignBottomWithPanel(ui, b) })
            case RelativePanelAlignHCenterWithPanel =>
                applyRelAlign(handle, value, { ui, b => RelativePanel.SetAlignHorizontalCenterWithPanel(ui, b) })
            case RelativePanelAlignVCenterWithPanel =>
                applyRelAlign(handle, value, { ui, b => RelativePanel.SetAlignVerticalCenterWithPanel(ui, b) })
            case _ => false
        }
    }

    private func applyRelAlign(handle: Handle, value: PropValue, set: (UIElement, Bool) -> Unit): Bool {
        let ui = uiElementOf(handle)
        try {
            match (value) {
                case BoolV(b) => set(ui, b)
                case Unset => set(ui, false)
                case _ => return false
            }
        } finally { ui.close() }
        true
    }

    // Layer 4 — Resources dictionary. Fills IFrameworkElement.Resources (an
    // IMap<IInspectable, IInspectable>) with the string key/value pairs. Returns
    // whether the prop was handled. The key/value pairs flow through IReference
    // boxes (string → IReference<HString> → IInspectable) inserted via the IMap's
    // unsafe ABI Insert.
    private func applyResourcesProp(handle: Handle, which: Prop, value: PropValue): Bool {
        // Resources → FrameworkElement.Resources ResourceDictionary population is
        // delegated to the misc/theme free function (resourcesApply). The body is
        // still a stub (filled by the theme family agent), but routing the prop
        // here marks it consumed so the per-family applyControlProp layer does not
        // see it.
        match ((which, value)) {
            case (Resources, ResourcesV(map)) =>
                resourcesApply(handle, map)
                true
            case _ => false
        }
    }

    // Layer 5 — per-family control-specific props. Dispatches to the family free
    // functions by handle variant. The family bodies are filled by follow-up
    // agents; this skeleton routes every handle to its family.
    private func applyControlProp(handle: Handle, which: Prop, value: PropValue): Bool {
        // ContentDialog open/close needs the controls registry (to discover a
        // XamlRoot from a live sibling element) which is only reachable here, not
        // in the stateless applyDialogProps family. Intercept it before delegating
        // (mirrors ref set_prop ContentDialogIsOpen arm, backend/mod.rs:1395-1441).
        match ((handle, which, value)) {
            case (ContentDialogH(d), ContentDialogIsOpen, BoolV(v)) =>
                setContentDialogOpen(d, v)
                return true
            case _ => ()
        }
        match (handle) {
            // text-display
            case TextBlockH(_) | RichTextBlockH(_) =>
                applyTextProps(handle, which, value)
            // buttons
            case ButtonH(_) | RepeatButtonH(_) | DropDownButtonH(_) | SplitButtonH(_)
                | HyperlinkButtonH(_) | ToggleButtonH(_) =>
                applyButtonProps(handle, which, value)
            // value / toggle input
            case CheckBoxH(_) | RadioButtonH(_) | RadioButtonsH(_) | ToggleSwitchH(_)
                | SliderH(_) | NumberBoxH(_) | ProgressBarH(_) | ProgressRingH(_)
                | RatingControlH(_) =>
                applyInputProps(handle, which, value)
            // editable text input
            case TextBoxH(_) | PasswordBoxH(_) | RichEditBoxH(_) =>
                applyTextInputProps(handle, which, value)
            // layout containers
            // SwapChainPanel is a Panel-derived FrameworkElement with no
            // control-specific props of its own; any prop that reaches here (only
            // generic element modifiers, since the widget emits no bindings) is
            // handled by the shared layout/FrameworkElement path.
            case StackPanelH(_) | GridH(_) | CanvasH(_) | RelativePanelH(_)
                | BorderH(_) | ViewboxH(_) | ScrollViewerH(_) | ScrollViewH(_)
                | SwapChainPanelH(_) =>
                applyLayoutProps(handle, which, value)
            // selection / collection
            case ListViewH(_) | GridViewH(_) | ListBoxH(_) | ComboBoxH(_)
                | FlipViewH(_) | TreeViewH(_) =>
                applyListProps(handle, which, value)
            // navigation / shell
            case NavigationViewH(_) | TabViewH(_) | TabViewItemH(_) | PivotH(_)
                | PivotItemH(_) | BreadcrumbBarH(_) | SelectorBarH(_) | MenuBarH(_)
                | CommandBarH(_) =>
                applyNavProps(handle, which, value)
            // pickers
            case DatePickerH(_) | TimePickerH(_) | CalendarDatePickerH(_)
                | CalendarViewH(_) | ColorPickerH(_) =>
                applyPickerProps(handle, which, value)
            // dialogs / surfaces / misc
            case ContentDialogH(_) | InfoBarH(_) | InfoBadgeH(_) | TeachingTipH(_)
                | ExpanderH(_) | PersonPictureH(_) | ImageH(_) | SplitViewH(_)
                | AutoSuggestBoxH(_) | TitleBarH(_) =>
                applyDialogProps(handle, which, value)
            // shapes
            case RectangleH(_) | EllipseH(_) | LineH(_) =>
                applyShapeProps(handle, which, value)
        }
    }

    // ── helper conversions ────────────────────────────────────────────────────

    // High-level FrameworkElement class for the handle (needed by Grid attached
    // setters which take the class, not the interface).
    private func frameworkElementOf(handle: Handle): FrameworkElement {
        FrameworkElement.fromAbiTake(
            queryRequired(handle.asRaw(), FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement")
        )
    }

    // High-level UIElement class for the handle (Canvas / RelativePanel attached
    // setters take the class).
    private func uiElementOf(handle: Handle): UIElement {
        UIElement.fromAbiTake(
            queryRequired(handle.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")
        )
    }
}

// Build a XamlThickness ABI struct from the reactor Thickness value type.
func toXamlThickness(t: Thickness): XamlThickness {
    var x = XamlThickness()
    x.Left = t.left
    x.Top = t.top
    x.Right = t.right
    x.Bottom = t.bottom
    x
}

// Build a XAML Brush from the reactor's solid-colour Brush. CreateInstanceWithColor
// yields a SolidColorBrush; QI it to the IBrush identity so the property setter
// (which expects a Brush) receives the correctly-typed pointer. Shared by the
// family files (props_text / props_layout).
func solidBrush(b: Brush): XamlBrush {
    var color = XamlColor()
    match (b) {
        case Solid(c) =>
            color.A = c.a
            color.R = c.r
            color.G = c.g
            color.B = c.b
    }
    let scb = SolidColorBrush.CreateInstanceWithColor(color)
    try {
        return XamlBrush.fromAbiTake(
            queryRequired(scb.asRaw(), XamlBrush.iid(), "Microsoft.UI.Xaml.Media.IBrush")
        )
    } finally {
        scb.close()
    }
}

// Build a FontFamily projection from a family name via the composable factory.
func makeFontFamily(name: String): FontFamily {
    let hs = HString(name)
    try {
        return FontFamily.CreateInstanceWithName(hs, nullBaseInspectable(), OutSlot<IInspectable>())
    } finally {
        hs.close()
    }
}
