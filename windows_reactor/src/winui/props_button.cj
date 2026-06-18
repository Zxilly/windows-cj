package windows_reactor.winui

import windows_reactor.core.{
    Prop, PropValue, ButtonStyle, SymbolGlyph, MenuItemDef, CommandBarCommandDef, EventHandler
}
import std.collection.{ArrayList}
import windows_core.{HString, queryInterfaceRaw}
import windows_interface.{IInspectable}
import windows_reference.{IReference, hStringReference, boolReference}
import windows_reactor.bindings.{IReference as Windows_Foundation_IReference_1}
import windows_reactor.bindings.{IVector as IVectorRaw}
import windows_reactor.bindings.{ContentControl, TextBlock, Control, StackPanel, Panel, SymbolIcon, Symbol, Orientation, MenuFlyout, MenuFlyoutItem, MenuFlyoutSubItem, MenuFlyoutItemBase, CommandBarFlyout, Flyout, AppBarButton, ICommandBarElement}
import windows_reactor.bindings.{ButtonBase, FlyoutBase}
import windows_reactor.bindings.{FrameworkElement, Application, Style, UIElement, RoutedEventHandler}
import windows_reactor.bindings.Uri
// ============================================================================
// Per-family property setters for the button controls (Button, RepeatButton,
// DropDownButton, SplitButton, HyperlinkButton, ToggleButton). Returns true
// when the prop was consumed by this family, false otherwise.
//
// Shared / generic props (Width/Height/Margin/Align/Opacity, Font*, attached,
// Resources) are consumed by the earlier dispatch layers in backend.cj and
// never reach here. Only button-family-specific props land in this function.
//
// Projection ABI (spec §8.1, verified against the windows_sys projections):
//   - ButtonContent / CheckBoxLabel: ContentControl.Content (QI to IContentControl,
//     wrap the label string in a TextBlock — behaviourally a text label).
//   - IsEnabled: Control.IsEnabled (QI to IControl).
//   - ButtonStyleVariant: FrameworkElement.Style, looked up by resource key from
//     Application.Current.Resources (an IMap<IInspectable,IInspectable>).
//   - ButtonIcon: SymbolIcon built via CreateInstanceWithSymbol, set as content
//     (icon-only, or an icon+text StackPanel preserving the existing label).
//   - RepeatDelay/RepeatInterval: RepeatButton.Delay / .Interval (high-level
//     Int32 props on the bound Primitives projection).
//   - NavigateUri: HyperlinkButton.NavigateUri (high-level Uri prop).
//   - IsChecked: ToggleButton.IsChecked (a boxed IReference<Bool>; null box = the
//     indeterminate/unset state, mirroring put_IsChecked(None)).
// ============================================================================
func applyButtonProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        // ── label / content text ─────────────────────────────────────────────
        // Applies to Button / RepeatButton / DropDownButton / SplitButton /
        // HyperlinkButton. (ToggleButton uses CheckBoxLabel, below.)
        case ButtonContent => match ((handle, value)) {
            case (ButtonH(b), Str(s)) => setContentControlText(b.asRaw(), s); true
            case (RepeatButtonH(b), Str(s)) => setContentControlText(b.asRaw(), s); true
            case (HyperlinkButtonH(h), Str(s)) => setContentControlText(h.asRaw(), s); true
            case (DropDownButtonH(d), Str(s)) => setContentControlText(d.asRaw(), s); true
            case (DropDownButtonH(d), Unset) => clearContentControlText(d.asRaw()); true
            case (SplitButtonH(sb), Str(s)) => setContentControlText(sb.asRaw(), s); true
            case (SplitButtonH(sb), Unset) => clearContentControlText(sb.asRaw()); true
            case _ => false
        }

        // ── ToggleButton content label ────────────────────────────────────────
        case CheckBoxLabel => match ((handle, value)) {
            case (ToggleButtonH(tb), Str(s)) => setContentControlText(tb.asRaw(), s); true
            case (ToggleButtonH(tb), Unset) => clearContentControlText(tb.asRaw()); true
            case _ => false
        }

        // ── IsEnabled (Control.IsEnabled) — every button family member ────────
        case IsEnabled => match (value) {
            case BoolV(v) => match (handle) {
                case ButtonH(_) | RepeatButtonH(_) | DropDownButtonH(_) | SplitButtonH(_)
                    | HyperlinkButtonH(_) | ToggleButtonH(_) =>
                    setButtonControlEnabled(handle.asRaw(), v); true
                case _ => false
            }
            case Unset => match (handle) {
                case ButtonH(_) | RepeatButtonH(_) | DropDownButtonH(_) | SplitButtonH(_)
                    | HyperlinkButtonH(_) | ToggleButtonH(_) =>
                    setButtonControlEnabled(handle.asRaw(), true); true
                case _ => false
            }
            case _ => false
        }

        // ── Button visual style variant (Accent / Subtle / TextLink) ──────────
        case ButtonStyleVariant => match ((handle, value)) {
            case (ButtonH(b), ButtonStyleV(style)) =>
                applyButtonStyle(b.asRaw(), style); true
            case _ => false
        }

        // ── Button leading icon ───────────────────────────────────────────────
        case ButtonIcon => match ((handle, value)) {
            case (ButtonH(b), SymbolIconV(sym)) =>
                applyButtonIcon(b.asRaw(), sym); true
            case _ => false
        }

        // ── RepeatButton auto-repeat timing (milliseconds) ────────────────────
        case RepeatDelay => match ((handle, value)) {
            case (RepeatButtonH(b), I32(v)) => b.Delay = v; true
            case _ => false
        }
        case RepeatInterval => match ((handle, value)) {
            case (RepeatButtonH(b), I32(v)) => b.Interval = v; true
            case _ => false
        }

        // ── HyperlinkButton navigation target ─────────────────────────────────
        case NavigateUri => match ((handle, value)) {
            case (HyperlinkButtonH(h), Str(s)) =>
                let hs = HString(s)
                try {
                    h.NavigateUri = Uri.CreateUri(hs)
                } finally {
                    hs.close()
                }
                true
            case (HyperlinkButtonH(h), Unset) =>
                h.NavigateUri = Uri.viewOf(CPointer<Unit>())
                true
            case _ => false
        }

        // ── ToggleButton checked state (three-state boxed bool) ───────────────
        case IsChecked => match ((handle, value)) {
            case (ToggleButtonH(tb), BoolV(v)) =>
                // Box the bool, then reinterpret as the projection's reference
                // type (IsChecked is typed Windows_Foundation_IReference_1<Bool>).
                // `box` stays alive across the assignment, which AddRefs.
                let box = boolReference(v)
                try {
                    tb.IsChecked = Windows_Foundation_IReference_1<Bool>.viewOf(box.asRaw())
                } finally {
                    box.close()
                }
                true
            case (ToggleButtonH(tb), Unset) =>
                // Null box = indeterminate / cleared (mirrors put_IsChecked(None)).
                tb.IsChecked = Windows_Foundation_IReference_1<Bool>.viewOf(CPointer<Unit>())
                true
            case _ => false
        }

        // ── MenuFlyout on Button / DropDownButton ─────────────────────────────
        // Build a fresh MenuFlyout from the item defs and attach it as the
        // button's Flyout. Per-item Click handlers are wired separately by the
        // backend after this returns (it owns the menuClickHandlers registry and
        // re-runs wireButtonMenuFlyoutClicks on every rebuild).
        case MenuFlyoutItems => match ((handle, value)) {
            case (ButtonH(_), MenuFlyoutItemsV(items)) =>
                setButtonMenuFlyout(handle, items); true
            case (DropDownButtonH(_), MenuFlyoutItemsV(items)) =>
                setButtonMenuFlyout(handle, items); true
            case _ => false
        }

        // ── CommandBarFlyout on Button ────────────────────────────────────────
        // Build a fresh CommandBarFlyout, populate its primary + secondary
        // command bars, and attach it as the button's Flyout. AppBarButton
        // Click handlers are wired by the backend after this returns.
        case CommandBarFlyoutCommands => match ((handle, value)) {
            case (ButtonH(_), CommandBarFlyoutDefV(primary, secondary)) =>
                setButtonCommandBarFlyout(handle, primary, secondary); true
            case _ => false
        }

        // ── Text Flyout on Button ─────────────────────────────────────────────
        // Build a Flyout wrapping a TextBlock and attach it as the button's
        // Flyout (reference Button::flyout). The button shows the lightweight
        // popup automatically on click via its Flyout property.
        case FlyoutContent => match ((handle, value)) {
            case (ButtonH(_), Str(s)) => setButtonTextFlyout(handle, s); true
            case _ => false
        }

        case _ => false
    }
}

// ── flyout build + attach helpers ───────────────────────────────────────────

// Build a MenuFlyout from menu item defs and set it as the button's Flyout.
// `handle` is the button (Button or DropDownButton). The flyout is QI'd to its
// FlyoutBase identity so the setter receives the correctly-typed (IFlyoutBase)
// pointer.
func setButtonMenuFlyout(handle: Handle, items: ArrayList<MenuItemDef>): Unit {
    let flyout = makeComposable(MenuFlyout.CreateInstance)
    try {
        let flyoutItems = flyout.Items
        for (def in items) {
            let fi = buildMenuFlyoutItemBase(def)
            try {
                checkHRESULT(unsafe { flyoutItems.Append(fi.asRaw()) }, "MenuFlyout.Items.Append")
            } finally {
                fi.close()
            }
        }
        setButtonFlyout(handle, flyout.asRaw())
    } finally {
        flyout.close()
    }
}

// Build a CommandBarFlyout, populate primary + secondary commands, attach it.
func setButtonCommandBarFlyout(
    handle: Handle,
    primary: ArrayList<CommandBarCommandDef>,
    secondary: ArrayList<CommandBarCommandDef>
): Unit {
    let flyout = makeComposable(CommandBarFlyout.CreateInstance)
    try {
        let primaryObs = flyout.PrimaryCommands
        try {
            appendCommandBarElements(commandBarVectorFromRaw(primaryObs.asRaw()), primary)
        } finally {
            primaryObs.close()
        }
        let secondaryObs = flyout.SecondaryCommands
        try {
            appendCommandBarElements(commandBarVectorFromRaw(secondaryObs.asRaw()), secondary)
        } finally {
            secondaryObs.close()
        }
        setButtonFlyout(handle, flyout.asRaw())
    } finally {
        flyout.close()
    }
}

// Build a lightweight text Flyout (a TextBlock wrapped in a Flyout) and attach
// it as the button's Flyout. Mirrors the reference Button::flyout — a click /
// focus popup carrying a contextual message; the button shows it automatically
// on click through its Flyout property (no separate click wiring needed).
func setButtonTextFlyout(handle: Handle, text: String): Unit {
    let flyout = makeComposable(Flyout.CreateInstance)
    try {
        let label = TextBlock.new()
        try {
            label.Text = HString(text)
            flyout.Content = UIElement.viewOf(label.asRaw())
        } finally {
            label.close()
        }
        setButtonFlyout(handle, flyout.asRaw())
    } finally {
        flyout.close()
    }
}

// Append command-bar elements to a (freshly-built, empty) command vector. Unlike
// rebuildCommandBarVector (props_nav.cj) this does not Clear first — the flyout's
// command bars start empty — and closes the vector wrapper when done.
func appendCommandBarElements(vec: IVectorRaw<ICommandBarElement>, cmds: ArrayList<CommandBarCommandDef>): Unit {
    try {
        for (def in cmds) {
            let el = buildCommandBarElement(def)
            try {
                checkHRESULT(unsafe { vec.Append(el.asRaw()) }, "CommandBarFlyout.commands.Append")
            } finally {
                el.close()
            }
        }
    } finally {
        vec.close()
    }
}

// Set a button's Flyout (FlyoutBase) on the IButton surface. `flyoutRaw` is the
// flyout's identity pointer; it is QI'd to FlyoutBase so the setter gets the
// IFlyoutBase pointer the ABI expects. The Button projection exposes a
// high-level Flyout setter; DropDownButton reaches it via its IButton interface.
func setButtonFlyout(handle: Handle, flyoutRaw: CPointer<Unit>): Unit {
    let base = FlyoutBase.fromAbiTake(
        queryRequired(flyoutRaw, FlyoutBase.iid(), "Microsoft.UI.Xaml.Controls.Primitives.IFlyoutBase")
    )
    try {
        match (handle) {
            case ButtonH(b) => b.Flyout = base
            case DropDownButtonH(d) =>
                let iface = d.asIButton()
                checkHRESULT(unsafe { iface.SetFlyout(base.asRaw()) }, "IButton.SetFlyout")
            case _ => ()
        }
    } finally {
        base.close()
    }
}

// Read a button's current Flyout as an owned FlyoutBase wrapper, or None when no
// flyout is set. Button uses the high-level getter; DropDownButton reaches it via
// its IButton interface. The returned wrapper owns the reference (caller closes).
func buttonFlyout(handle: Handle): ?FlyoutBase {
    match (handle) {
        case ButtonH(b) =>
            // The high-level Flyout getter raises E_POINTER when no flyout is set
            // (null result); treat that as "no flyout" rather than an error.
            let fb = try {
                b.Flyout
            } catch (_: Exception) {
                return None
            }
            if (fb.asRaw().isNull()) {
                fb.close()
                return None
            }
            return Some(fb)
        case DropDownButtonH(d) =>
            let iface = d.asIButton()
            var raw = CPointer<Unit>()
            checkHRESULT(unsafe { iface.Flyout(CPointer<CPointer<Unit>>(inout raw)) }, "IButton.Flyout")
            if (raw.isNull()) {
                return None
            }
            return Some(FlyoutBase.fromAbiTake(raw))
        case _ => return None
    }
}

// ── per-item Click wiring (called by the backend after a flyout rebuild) ──────

// Wire Click handlers on every MenuFlyoutItem within the button's current
// MenuFlyout, recursing into sub-items. Returns the collected revokers. No-op
// (empty) when the button carries no MenuFlyout. Mirrors the reference
// wire_flyout_clicks + wire_flyout_items_click.
func wireButtonMenuFlyoutClicks(handle: Handle, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    match (buttonFlyout(handle)) {
        case Some(fb) =>
            try {
                // The button's Flyout may be any FlyoutBase; only a MenuFlyout
                // carries MenuFlyoutItems. QI to MenuFlyout; bail otherwise.
                match (unsafe { queryInterfaceRaw(fb.asRaw(), MenuFlyout.iid()) }) {
                    case Some(menuRaw) =>
                        let menu = MenuFlyout.fromAbiTake(menuRaw)
                        try {
                            let items = menu.Items
                            wireFlyoutItemsClick(items, handler, revokers)
                        } finally {
                            menu.close()
                        }
                    case None => ()
                }
            } finally {
                fb.close()
            }
        case None => ()
    }
    revokers
}

// Recursively wire Click on every MenuFlyoutItem in a MenuFlyoutItemBase vector,
// recursing into MenuFlyoutSubItem children. Each item's stored handler is
// invoked with the item's Text (invokeString), mirroring the reference.
func wireFlyoutItemsClick(
    items: IVectorRaw<MenuFlyoutItemBase>,
    handler: EventHandler,
    revokers: ArrayList<EventRevoker>
): Unit {
    var size = 0u32
    checkHRESULT(unsafe { items.Size(CPointer<UInt32>(inout size)) }, "MenuFlyout.Items.Size")
    var i = 0u32
    while (i < size) {
        var slot = CPointer<Unit>()
        checkHRESULT(unsafe { items.GetAt(i, CPointer<CPointer<Unit>>(inout slot)) }, "MenuFlyout.Items.GetAt")
        if (slot.isNotNull()) {
            // A leaf MenuFlyoutItem owns a Click; a MenuFlyoutSubItem recurses.
            match (unsafe { queryInterfaceRaw(slot, MenuFlyoutItem.iid()) }) {
                case Some(itemRaw) =>
                    // slot was an owned ref from GetAt; the QI'd itemRaw is a
                    // second owned ref. Release slot's owner, keep the typed item.
                    releaseSlotOwner(slot)
                    let item = MenuFlyoutItem.fromAbiTake(itemRaw)
                    wireOneFlyoutItemClick(item, handler, revokers)
                case None =>
                    match (unsafe { queryInterfaceRaw(slot, MenuFlyoutSubItem.iid()) }) {
                        case Some(subRaw) =>
                            releaseSlotOwner(slot)
                            let sub = MenuFlyoutSubItem.fromAbiTake(subRaw)
                            try {
                                let subItems = sub.Items
                                wireFlyoutItemsClick(subItems, handler, revokers)
                            } finally {
                                sub.close()
                            }
                        case None =>
                            // A MenuFlyoutSeparator (or other base) — no Click.
                            releaseSlotOwner(slot)
                    }
            }
        }
        i++
    }
}

// Subscribe one MenuFlyoutItem's Click to the stored handler, pushing the
// revoker. The item's Text is captured per-item so each closure reports its own
// label; the captured `item` keeps the projection alive across the revoke.
func wireOneFlyoutItemClick(item: MenuFlyoutItem, handler: EventHandler, revokers: ArrayList<EventRevoker>): Unit {
    let label = item.Text.toString()
    let delegate = RoutedEventHandler.new({ _, _ =>
        try {
            handler.invokeString(label)
        } catch (_: Exception) {
            ()
        }
    })
    let token = item.addClick(delegate)
    revokers.add(EventRevoker({ =>
        try {
            item.removeClick(token)
        } catch (_: Exception) {
            ()
        }
        delegate.close()
        item.close()
    }))
}

// Wire Click handlers on every AppBarButton in the button's CommandBarFlyout
// (primary + secondary), invoking the handler with the button's Label. Returns
// the collected revokers; empty when the button carries no CommandBarFlyout.
func wireButtonCommandBarFlyoutClicks(handle: Handle, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    match (buttonFlyout(handle)) {
        case Some(fb) =>
            try {
                match (unsafe { queryInterfaceRaw(fb.asRaw(), CommandBarFlyout.iid()) }) {
                    case Some(cbfRaw) =>
                        let cbf = CommandBarFlyout.fromAbiTake(cbfRaw)
                        try {
                            let primaryObs = cbf.PrimaryCommands
                            try {
                                wireCommandBarElementsClick(primaryObs.asRaw(), handler, revokers)
                            } finally {
                                primaryObs.close()
                            }
                            let secondaryObs = cbf.SecondaryCommands
                            try {
                                wireCommandBarElementsClick(secondaryObs.asRaw(), handler, revokers)
                            } finally {
                                secondaryObs.close()
                            }
                        } finally {
                            cbf.close()
                        }
                    case None => ()
                }
            } finally {
                fb.close()
            }
        case None => ()
    }
    revokers
}

// Release the owned reference returned by an IVector GetAt slot (it was wrapped
// non-owningly in `slot`; take ownership transiently and close to drop the ref).
func releaseSlotOwner(slot: CPointer<Unit>): Unit {
    let owner = IInspectable.fromAbiTake(slot)
    owner.close()
}

// Wire Click on every AppBarButton in an ICommandBarElement vector (the raw
// pointer is an IObservableVector; QI to the IVector base for GetAt/Size). Each
// AppBarButton is QI'd to ButtonBase (which owns the Click accessors) and its
// Label is captured for the handler payload. Shared by the CommandBarFlyout
// path (above) and the CommandBar control path (wireCommandBarClicks, props_nav).
// Mirrors the reference wire_command_bar_clicks.
func wireCommandBarElementsClick(obsRaw: CPointer<Unit>, handler: EventHandler, revokers: ArrayList<EventRevoker>): Unit {
    let vec = commandBarVectorFromRaw(obsRaw)
    try {
        var size = 0u32
        checkHRESULT(unsafe { vec.Size(CPointer<UInt32>(inout size)) }, "CommandBar.commands.Size")
        var i = 0u32
        while (i < size) {
            var slot = CPointer<Unit>()
            checkHRESULT(unsafe { vec.GetAt(i, CPointer<CPointer<Unit>>(inout slot)) }, "CommandBar.commands.GetAt")
            if (slot.isNotNull()) {
                match (unsafe { queryInterfaceRaw(slot, AppBarButton.iid()) }) {
                    case Some(btnRaw) =>
                        releaseSlotOwner(slot)
                        let btn = AppBarButton.fromAbiTake(btnRaw)
                        wireOneAppBarButtonClick(btn, handler, revokers)
                    case None =>
                        // AppBarToggleButton / AppBarSeparator carry no plain Click.
                        releaseSlotOwner(slot)
                }
            }
            i++
        }
    } finally {
        vec.close()
    }
}

// Subscribe one AppBarButton's Click (via its ButtonBase identity) to the stored
// handler, reporting the button's Label. The AppBarButton wrapper's lifetime is
// only needed to read the Label and QI ButtonBase; the captured ButtonBase keeps
// the registration target alive across the revoke.
func wireOneAppBarButtonClick(btn: AppBarButton, handler: EventHandler, revokers: ArrayList<EventRevoker>): Unit {
    try {
        let label = btn.Label.toString()
        let bb = ButtonBase.fromAbiTake(
            queryRequired(btn.asRaw(), ButtonBase.iid(), "Microsoft.UI.Xaml.Controls.Primitives.IButtonBase")
        )
        let delegate = RoutedEventHandler.new({ _, _ =>
            try {
                handler.invokeString(label)
            } catch (_: Exception) {
                ()
            }
        })
        let token = bb.addClick(delegate)
        revokers.add(EventRevoker({ =>
            try {
                bb.removeClick(token)
            } catch (_: Exception) {
                ()
            }
            delegate.close()
            bb.close()
        }))
    } finally {
        btn.close()
    }
}

// ── shared private helpers ──────────────────────────────────────────────────

// Set a content-control's content to a plain text label by wrapping the string
// in a TextBlock and assigning it through the high-level ContentControl.Content.
// Shared by the button family (and reusable by other ContentControl-derived
// families as they fill in).
func setContentControlText(raw: CPointer<Unit>, text: String): Unit {
    let cc = ContentControl.fromAbiTake(
        queryRequired(raw, ContentControl.iid(), "Microsoft.UI.Xaml.Controls.IContentControl")
    )
    try {
        let label = TextBlock.new()
        try {
            label.Text = HString(text)
            cc.Content = label.asIInspectable()
        } finally {
            label.close()
        }
    } finally {
        cc.close()
    }
}

// Clear a content-control's content (Content := null), mirroring put_Content(None).
func clearContentControlText(raw: CPointer<Unit>): Unit {
    let cc = ContentControl.fromAbiTake(
        queryRequired(raw, ContentControl.iid(), "Microsoft.UI.Xaml.Controls.IContentControl")
    )
    try {
        cc.Content = IInspectable.viewOf(CPointer<Unit>())
    } finally {
        cc.close()
    }
}

// Toggle the control's enabled state via the Control.IsEnabled high-level prop.
// Named with a button-family prefix to avoid colliding with the identical helper
// in sibling per-family props files (free funcs share the package namespace).
func setButtonControlEnabled(raw: CPointer<Unit>, enabled: Bool): Unit {
    let c = Control.fromAbiTake(
        queryRequired(raw, Control.iid(), "Microsoft.UI.Xaml.Controls.IControl")
    )
    try {
        c.IsEnabled = enabled
    } finally {
        c.close()
    }
}

// Apply a named button style from the application resource dictionary to the
// control's FrameworkElement.Style. Accent/Subtle/TextLink map to the framework
// resource keys; Default clears the explicit style (null), letting WinUI use the
// implicit default. Resolution failures (missing key / not running under an
// Application) leave the control unstyled rather than throwing.
func applyButtonStyle(raw: CPointer<Unit>, style: ButtonStyle): Unit {
    let fe = FrameworkElement.fromAbiTake(
        queryRequired(raw, FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement")
    )
    try {
        let keyOpt: ?String = match (style) {
            case Accent => Some("AccentButtonStyle")
            case Subtle => Some("SubtleButtonStyle")
            case TextLink => Some("TextBlockButtonStyle")
            case Default => None
        }
        match (keyOpt) {
            case Some(key) =>
                match (lookupStyleResource(key)) {
                    case Some(s) =>
                        try {
                            fe.Style = s
                        } finally {
                            s.close()
                        }
                    case None => ()
                }
            case None =>
                fe.Style = Style.viewOf(CPointer<Unit>())
        }
    } finally {
        fe.close()
    }
}

// Look up a Style from Application.Current.Resources by string key. Returns None
// when there is no current Application, the key is absent, or the value is not a
// Style. The Resources dictionary is an IMap<IInspectable, IInspectable>; the key
// is a boxed HString (IReference<HString>).
func lookupStyleResource(key: String): ?Style {
    let app = Application.Current()
    if (app.asRaw().isNull()) {
        return None
    }
    try {
        let resources = app.Resources
        try {
            // QI the ResourceDictionary to IMap<Object, Object> using the
            // canonical PIID (the generated asIMap() mis-hashes the IID — see
            // util.cj/inspectableMapIid — and would throw E_NOINTERFACE here).
            let map = takeInspectableMap(resources.asRaw())
            try {
                let keyBox = hStringReference(key)
                try {
                    var has = false
                    checkHRESULT(unsafe { map.HasKey(keyBox.asRaw(), CPointer<Bool>(inout has)) }, "Resources.HasKey")
                    if (!has) {
                        return None
                    }
                    var slot = CPointer<Unit>()
                    checkHRESULT(
                        unsafe { map.Lookup(keyBox.asRaw(), CPointer<CPointer<Unit>>(inout slot)) },
                        "Resources.Lookup"
                    )
                    if (slot.isNull()) {
                        return None
                    }
                    let value = IInspectable.fromAbiTake(slot)
                    try {
                        match (unsafe { queryInterfaceRaw(value.asRaw(), Style.iid()) }) {
                            case Some(styleRaw) => return Some(Style.fromAbiTake(styleRaw))
                            case None => return None
                        }
                    } finally {
                        value.close()
                    }
                } finally {
                    keyBox.close()
                }
            } finally {
                map.close()
            }
        } finally {
            resources.close()
        }
    } finally {
        app.close()
    }
}

// Build a SymbolIcon for `sym` and set it as the button content. If the button
// already carries an icon+text StackPanel layout, replace just the icon child so
// the label survives; if it carries a visible text label, build an icon+text
// StackPanel; otherwise set the icon alone. Mirrors the reference ButtonIcon arm.
func applyButtonIcon(raw: CPointer<Unit>, sym: SymbolGlyph): Unit {
    let icon = SymbolIcon.CreateInstanceWithSymbol(Symbol(sym.toRaw()))
    try {
        let cc = ContentControl.fromAbiTake(
            queryRequired(raw, ContentControl.iid(), "Microsoft.UI.Xaml.Controls.IContentControl")
        )
        try {
            // The Content getter throws E_POINTER when the control has no content;
            // treat that as "no existing content" rather than an error.
            let existingOpt = readButtonContent(cc)
            match (existingOpt) {
                case Some(existing) =>
                    try {
                        applyButtonIconWithExisting(cc, icon, existing)
                    } finally {
                        existing.close()
                    }
                case None =>
                    // Case 3: icon-only.
                    cc.Content = icon.asIInspectable()
            }
        } finally {
            cc.close()
        }
    } finally {
        icon.close()
    }
}

// Apply `icon` against a present `existing` content. Replaces the icon child of
// an existing icon+text StackPanel, builds an icon+text StackPanel around an
// existing visible label, or falls back to icon-only.
func applyButtonIconWithExisting(cc: ContentControl, icon: SymbolIcon, existing: IInspectable): Unit {
    // Case 1: existing icon+text StackPanel — swap icon child (index 0).
    match (buttonContentAsPanel(existing)) {
        case Some(panel) =>
            try {
                let children = panel.Children
                if (children.Size >= 2) {
                    children.SetAt(0u32, buttonIconAsUIElement(icon))
                    return
                }
            } finally {
                panel.close()
            }
        case None => ()
    }
    // Case 2: there is an existing visible label — build an icon+text panel.
    if (buttonContentHasVisibleText(existing)) {
        let panel = makeComposable(StackPanel.CreateInstance)
        try {
            // Orientation wraps an Int32; the WinUI Horizontal value is 1.
            panel.Orientation = Orientation(1)
            panel.Spacing = 8.0
            let p = Panel.fromAbiTake(
                queryRequired(panel.asRaw(), Panel.iid(), "Microsoft.UI.Xaml.Controls.IPanel")
            )
            try {
                let children = p.Children
                children.Append(buttonIconAsUIElement(icon))
                children.Append(buttonContentAsUIElement(existing))
            } finally {
                p.close()
            }
            cc.Content = panel.asIInspectable()
        } finally {
            panel.close()
        }
    } else {
        // Case 3: icon-only.
        cc.Content = icon.asIInspectable()
    }
}

// Read a content-control's current content, or None when it is empty (the
// high-level getter raises E_POINTER for a null content pointer).
func readButtonContent(cc: ContentControl): ?IInspectable {
    try {
        let c = cc.Content
        if (c.asRaw().isNull()) {
            return None
        }
        return Some(c)
    } catch (_: Exception) {
        return None
    }
}

// QI the SymbolIcon to the UIElement class accepted by a Panel's Children vector.
func buttonIconAsUIElement(icon: SymbolIcon): UIElement {
    UIElement.fromAbiTake(
        queryRequired(icon.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")
    )
}

// QI an existing content IInspectable to the UIElement class for re-parenting.
func buttonContentAsUIElement(content: IInspectable): UIElement {
    UIElement.fromAbiTake(
        queryRequired(content.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")
    )
}

// If `content` is a Panel (StackPanel layout), project it to Panel; else None.
// Caller owns and must close the returned Panel.
func buttonContentAsPanel(content: IInspectable): ?Panel {
    if (content.asRaw().isNull()) {
        return None
    }
    match (unsafe { queryInterfaceRaw(content.asRaw(), Panel.iid()) }) {
        case Some(raw) => Some(Panel.fromAbiTake(raw))
        case None => None
    }
}

// Whether `content` is a non-empty TextBlock label (so an icon should be paired
// with it in a StackPanel rather than replacing it).
func buttonContentHasVisibleText(content: IInspectable): Bool {
    if (content.asRaw().isNull()) {
        return false
    }
    match (unsafe { queryInterfaceRaw(content.asRaw(), TextBlock.iid()) }) {
        case Some(raw) =>
            let tb = TextBlock.fromAbiTake(raw)
            try {
                return tb.Text.toString().size > 0
            } finally {
                tb.close()
            }
        case None => false
    }
}
