package windows_reactor.winui

import windows_reactor.core.{
    Prop, PropValue, NavViewItem, MenuItemDef, MenuBarItemDef, CommandBarCommandDef,
    SelectorBarItemDef, SymbolGlyph, EventHandler
}
import std.collection.{ArrayList, HashMap}
import windows_core.{HString, GUID, queryInterfaceRaw, releaseSystemHStringHandle}
import windows_interface.{IInspectable}
import windows_reference.{hStringReference, IReference}
import windows_collections.{toInspectableVector}
import windows_common.Microsoft.UI.Xaml.Controls.{
    ContentControl, TextBlock, SymbolIcon, Symbol, IconElement, ICommandBarElement,
    NavigationViewItem, NavigationViewItemHeader, MenuBarItem, MenuFlyoutItem,
    MenuFlyoutSeparator, MenuFlyoutSubItem, AppBarButton, AppBarToggleButton,
    AppBarSeparator, SelectorBarItem, AutoSuggestBox,
    NavigationView, TabView, TabViewItem, Pivot, PivotItem,
    MenuBar, CommandBar, SelectorBar, BreadcrumbBar
}
import windows_common.Microsoft.UI.Xaml.{FrameworkElement}
import windows_common.impl.{
    Windows_Foundation_Collections_IVector_1 as IVectorRaw,
    Microsoft_UI_Xaml_Controls_NavigationViewPaneDisplayMode_Auto as PaneAuto,
    Microsoft_UI_Xaml_Controls_NavigationViewPaneDisplayMode_Left as PaneLeft,
    Microsoft_UI_Xaml_Controls_NavigationViewPaneDisplayMode_Top as PaneTop,
    Microsoft_UI_Xaml_Controls_NavigationViewPaneDisplayMode_LeftCompact as PaneLeftCompact,
    Microsoft_UI_Xaml_Controls_NavigationViewPaneDisplayMode_LeftMinimal as PaneLeftMinimal,
    Microsoft_UI_Xaml_Controls_NavigationViewBackButtonVisible_Auto as BackAuto,
    Microsoft_UI_Xaml_Controls_NavigationViewBackButtonVisible_Collapsed as BackCollapsed,
    Microsoft_UI_Xaml_Controls_CommandBarDefaultLabelPosition_Bottom as LabelBottom,
    Microsoft_UI_Xaml_Controls_CommandBarDefaultLabelPosition_Right as LabelRight,
    Microsoft_UI_Xaml_Controls_CommandBarDefaultLabelPosition_Collapsed as LabelCollapsed
}

// Programmatic selections requested before the NavigationView has loaded (template
// applied, ItemsRepeater realized live containers). Setting SelectedItem to a
// pre-realization item makes WinUI's own OnApplyTemplate read it back and AV. We defer:
// record the tag here and apply it from the Loaded handler (event_nav.cj) once realized.
let navPendingSelectTags = HashMap<UIntNative, String>()

// Boxed IReference<HString> Tags retained for each NavigationView owner. A boxed Tag
// is a *Cangjie* ComObject (StockReference); WinUI's AddRef on it does NOT root the
// managed object, so without a live Cangjie reference the StockReference is collected
// and its stored HSTRING freed — while WinUI still template-binds the item's Tag,
// access-violating in WindowsDuplicateString (0xC0000005). We therefore keep an
// explicit Cangjie reference alive for the owner's lifetime (the same explicit-
// retention pattern the codebase uses for delegates). Freed on rebuild (after
// menu.Clear releases WinUI's refs) and on control destroy.
let navTagBoxes = HashMap<UIntNative, ArrayList<IReference<HString>>>()

// ============================================================================
// Per-family property setters for navigation / shell controls (NavigationView,
// TabView, TabViewItem, Pivot, PivotItem, BreadcrumbBar, SelectorBar, MenuBar,
// CommandBar). Returns true when the prop was consumed by this family.
//
// Shared / generic props (Width/Height/Margin/Align/Opacity, Font*, attached,
// Resources) are consumed by the earlier dispatch layers in backend.cj and never
// reach here. Only navigation-family-specific props land in this function.
//
// Projection ABI (spec §8.1, verified against the windows_common projections):
//   - High-level leaf props on the variant-bound class: TabView.SelectedIndex /
//     .CanReorderTabs, TabViewItem.Header / .IsClosable, Pivot.SelectedIndex /
//     .Title, PivotItem.Header, NavigationView.IsPaneOpen / .IsSettingsVisible /
//     .Header / .SelectedItem / .IsPaneToggleButtonVisible / .AutoSuggestBox,
//     CommandBar.DefaultLabelPosition.
//   - Base-interface props reached by QI to the interface wrapper (form b): the
//     INavigationView2 surface (PaneDisplayMode / IsBackEnabled / PaneTitle /
//     IsBackButtonVisible) which is not on the default INavigationView interface.
//   - Collection rebuilds (clear + repopulate): NavMenuItems (NavigationView),
//     MenuBarItems (MenuBar), CommandBarPrimaryCommands / CommandBarSecondaryCommands
//     (CommandBar), SelectorBarItems (SelectorBar), NavAutoSuggestItems.
//
// Header / Title / SelectedItem are IInspectable-typed projection properties: a
// plain-text label is wrapped in a TextBlock and assigned through .asIInspectable().
//
// NEEDS BACKEND STATE (deferred to the integration phase — see report): the
// MenuBarItems and CommandBarPrimaryCommands/CommandBarSecondaryCommands rebuilds
// here only construct the visual item tree. Re-wiring the stored per-item click
// handlers after a rebuild requires the menuClickHandlers registry on
// WinUIBackend and is wired by backend.cj after this function returns true.
// ============================================================================
func applyNavProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        // ── TabView ───────────────────────────────────────────────────────────
        case SelectedIndex => match ((handle, value)) {
            case (TabViewH(tv), I32(v)) => tv.SelectedIndex = v; true
            case (PivotH(p), I32(v)) => p.SelectedIndex = v; true
            case _ => false
        }
        case CanReorderTabs => match ((handle, value)) {
            case (TabViewH(tv), BoolV(v)) => tv.CanReorderTabs = v; true
            case _ => false
        }
        case IsAddTabButtonVisible => match ((handle, value)) {
            case (TabViewH(tv), BoolV(v)) => tv.IsAddTabButtonVisible = v; true
            case _ => false
        }

        // ── TabViewItem ─────────────────────────────────────────────────────────
        case TabHeader => match ((handle, value)) {
            case (TabViewItemH(ti), Str(s)) => assignTextLabel(s, { insp => ti.Header = insp }); true
            case _ => false
        }
        case TabItemKey => match ((handle, value)) {
            case (TabViewItemH(ti), Str(s)) => setTagString(ti.asRaw(), s); true
            case _ => false
        }
        case IsClosable => match ((handle, value)) {
            case (TabViewItemH(ti), BoolV(v)) => ti.IsClosable = v; true
            case _ => false
        }

        // ── Pivot / PivotItem ─────────────────────────────────────────────────
        case PivotTitle => match ((handle, value)) {
            case (PivotH(p), Str(s)) => assignTextLabel(s, { insp => p.Title = insp }); true
            case (PivotH(p), Unset) => p.Title = IInspectable.viewOf(CPointer<Unit>()); true
            case _ => false
        }
        case PivotItemHeader => match ((handle, value)) {
            case (PivotItemH(pi), Str(s)) => assignTextLabel(s, { insp => pi.Header = insp }); true
            case _ => false
        }

        // ── NavigationView: menu item tree (recursive rebuild) ────────────────
        case NavMenuItems => match ((handle, value)) {
            case (NavigationViewH(nv), NavMenuItems(items)) =>
                let ownerKey = nv.asRaw().toUIntNative()
                // Mirror the reference: append live NavigationViewItem containers
                // directly into nv.MenuItems (NOT MenuItemsSource). WinUI's
                // MenuItems holds each appended item; closing the wrapper after
                // Append leaves WinUI as sole owner. On the next rebuild,
                // menu.Clear() releases WinUI's refs.
                let menu = nv.MenuItems
                try {
                    checkHRESULT(unsafe { menu.Clear() }, "NavigationView.MenuItems.Clear")
                    // WinUI has now released the previous render's items (and their
                    // Tags), so the previously-retained boxed Tags can be freed before
                    // building the new ones — no leak, no premature free.
                    releaseNavTagBoxes(ownerKey)
                    for (item in items) {
                        let navItem = buildNavViewItem(item, ownerKey)
                        try {
                            checkHRESULT(unsafe { menu.Append(navItem.asRaw()) }, "NavigationView.MenuItems.Append")
                        } finally {
                            navItem.close()
                        }
                    }
                } finally {
                    menu.close()
                }
                true
            case _ => false
        }
        case IsPaneOpen => match ((handle, value)) {
            case (NavigationViewH(nv), BoolV(v)) => nv.IsPaneOpen = v; true
            case _ => false
        }
        case PaneDisplayMode => match ((handle, value)) {
            case (NavigationViewH(nv), NavPaneDisplayMode(mode)) =>
                let mapped = match (mode) {
                    case Auto => PaneAuto
                    case Left => PaneLeft
                    case Top => PaneTop
                    case LeftCompact => PaneLeftCompact
                    case LeftMinimal => PaneLeftMinimal
                }
                let iface = nv.asINavigationView2()
                checkHRESULT(unsafe { iface.SetPaneDisplayMode(mapped.value) }, "INavigationView2.SetPaneDisplayMode")
                true
            case _ => false
        }
        case IsBackEnabled => match ((handle, value)) {
            case (NavigationViewH(nv), BoolV(v)) =>
                let iface = nv.asINavigationView2()
                checkHRESULT(unsafe { iface.SetIsBackEnabled(v) }, "INavigationView2.SetIsBackEnabled")
                true
            case _ => false
        }
        case IsSettingsVisible => match ((handle, value)) {
            case (NavigationViewH(nv), BoolV(v)) => nv.IsSettingsVisible = v; true
            case _ => false
        }
        case PaneTitle => match ((handle, value)) {
            case (NavigationViewH(nv), Str(s)) => setNavPaneTitle(nv, s); true
            case (NavigationViewH(nv), Unset) => setNavPaneTitle(nv, ""); true
            case _ => false
        }
        case NavHeaderString => match ((handle, value)) {
            case (NavigationViewH(nv), Str(s)) => assignTextLabel(s, { insp => nv.Header = insp }); true
            case (NavigationViewH(nv), Unset) => nv.Header = IInspectable.viewOf(CPointer<Unit>()); true
            case _ => false
        }
        case NavSelectedTag => match ((handle, value)) {
            case (NavigationViewH(nv), Str(tag)) => selectNavItemByTag(nv, tag); true
            case (NavigationViewH(nv), Unset) =>
                nv.SelectedItem = IInspectable.viewOf(CPointer<Unit>()); true
            case _ => false
        }
        case NavAutoSuggestBox => match ((handle, value)) {
            case (NavigationViewH(nv), BoolV(true)) =>
                let asb = AutoSuggestBox.new()
                try {
                    nv.AutoSuggestBox = asb
                } finally {
                    asb.close()
                }
                true
            case (NavigationViewH(nv), BoolV(false)) =>
                nv.AutoSuggestBox = AutoSuggestBox.viewOf(CPointer<Unit>())
                true
            case _ => false
        }
        case NavAutoSuggestPlaceholder => match ((handle, value)) {
            case (NavigationViewH(nv), Str(s)) =>
                let asb = nv.AutoSuggestBox
                try {
                    if (asb.asRaw().isNotNull()) {
                        asb.PlaceholderText = HString(s)
                    }
                } finally {
                    asb.close()
                }
                true
            case _ => false
        }
        case NavAutoSuggestItems => match ((handle, value)) {
            case (NavigationViewH(nv), StrList(items)) => setNavAutoSuggestItems(nv, items); true
            case _ => false
        }
        case IsBackButtonVisible => match ((handle, value)) {
            case (NavigationViewH(nv), BoolV(v)) =>
                let vis = if (v) { BackAuto } else { BackCollapsed }
                let iface = nv.asINavigationView2()
                checkHRESULT(unsafe { iface.SetIsBackButtonVisible(vis.value) }, "INavigationView2.SetIsBackButtonVisible")
                true
            case _ => false
        }
        case IsPaneToggleButtonVisible => match ((handle, value)) {
            case (NavigationViewH(nv), BoolV(v)) => nv.IsPaneToggleButtonVisible = v; true
            case _ => false
        }

        // ── BreadcrumbBar ─────────────────────────────────────────────────────
        // Populate BreadcrumbBar.ItemsSource with the crumb labels. (The reference
        // backend no-ops this arm; the Cangjie projection fully supports ItemsSource,
        // so we populate it here to make the crumbs visible — a control with no
        // ItemsSource renders nothing and has zero footprint.)
        case BreadcrumbItems => match ((handle, value)) {
            case (BreadcrumbBarH(bb), StrList(items)) => setBreadcrumbItems(bb, items); true
            case _ => false
        }

        // ── MenuBar (recursive flyout-item tree rebuild) ──────────────────────
        case MenuBarItems => match ((handle, value)) {
            case (MenuBarH(mb), MenuBarItemsV(items)) => rebuildMenuBar(mb, items); true
            case _ => false
        }

        // ── CommandBar ────────────────────────────────────────────────────────
        case CommandBarPrimaryCommands => match ((handle, value)) {
            case (CommandBarH(cb), CommandBarCommandsV(cmds)) =>
                let obs = cb.PrimaryCommands
                try {
                    rebuildCommandBarVector(commandBarVectorFromRaw(obs.asRaw()), cmds)
                } finally {
                    obs.close()
                }
                true
            case _ => false
        }
        case CommandBarSecondaryCommands => match ((handle, value)) {
            case (CommandBarH(cb), CommandBarCommandsV(cmds)) =>
                let obs = cb.SecondaryCommands
                try {
                    rebuildCommandBarVector(commandBarVectorFromRaw(obs.asRaw()), cmds)
                } finally {
                    obs.close()
                }
                true
            case _ => false
        }
        case CommandBarDefaultLabelPosition => match ((handle, value)) {
            case (CommandBarH(cb), CommandBarLabelPositionV(pos)) =>
                cb.DefaultLabelPosition = match (pos) {
                    case Bottom => LabelBottom
                    case Right => LabelRight
                    case Collapsed => LabelCollapsed
                }
                true
            case _ => false
        }

        // ── SelectorBar ───────────────────────────────────────────────────────
        case SelectorBarItems => match ((handle, value)) {
            case (SelectorBarH(sb), SelectorBarItemsV(items)) =>
                let vec = sb.Items
                try {
                    checkHRESULT(unsafe { vec.Clear() }, "SelectorBar.Items.Clear")
                    for (def in items) {
                        let item = makeComposable(SelectorBarItem.CreateInstance)
                        try {
                            item.Text = HString(def.text)
                            match (def.icon) {
                                case Some(sym) =>
                                    let ic = makeSymbolIcon(sym)
                                    try {
                                        item.Icon = IconElement.viewOf(ic.asRaw())
                                    } finally {
                                        ic.close()
                                    }
                                case None => ()
                            }
                            checkHRESULT(unsafe { vec.Append(item.asRaw()) }, "SelectorBar.Items.Append")
                        } finally {
                            item.close()
                        }
                    }
                } finally {
                    vec.close()
                }
                true
            case _ => false
        }

        case _ => false
    }
}

// Called on NavigationView destroy. WinUI owns the appended MenuItems and frees
// them when the control is destroyed, so there is no item state to close here —
// only the per-owner selected-tag record needs clearing.
func releaseNavMenuItemsSource(raw: CPointer<Unit>): Unit {
    if (raw.isNotNull()) {
        let key = raw.toUIntNative()
        navPendingSelectTags.remove(key)
        // WinUI frees its MenuItems (and their Tags) when the control is destroyed,
        // so the retained boxed Tags can be released here.
        releaseNavTagBoxes(key)
    }
}

// ── shared private helpers ──────────────────────────────────────────────────

func navViewItemTag(item: NavViewItem): String {
    match (item.tag) {
        case Some(t) => t
        case None => item.content
    }
}

// Retain a boxed Tag (IReference<HString>) for the owner's lifetime so its backing
// StockReference / HSTRING is not GC-collected while WinUI still references the Tag.
func retainNavTagBox(ownerKey: UIntNative, box: IReference<HString>): Unit {
    match (navTagBoxes.get(ownerKey)) {
        case Some(list) => list.add(box)
        case None =>
            let list = ArrayList<IReference<HString>>()
            list.add(box)
            navTagBoxes[ownerKey] = list
    }
}

// Release all retained boxed Tags for an owner (refcount -> 0 frees the value cleanly).
// Only call AFTER WinUI has released its refs to the items (e.g. after menu.Clear or on
// control destroy), so the value is never freed out from under a live WinUI reference.
func releaseNavTagBoxes(ownerKey: UIntNative): Unit {
    match (navTagBoxes.get(ownerKey)) {
        case Some(list) =>
            for (b in list) {
                b.close()
            }
            navTagBoxes.remove(ownerKey)
        case None => ()
    }
}

// Wrap a plain-text label in a TextBlock and hand its IInspectable view to the
// given setter (an IInspectable-typed projection property assignment, e.g.
// nv.Header / pivot.Title / item.Content). The assignment AddRefs the TextBlock
// through the target, so the temporary wrapper is only closed AFTER the setter
// runs — closing before assignment would free the object the view points at.
func assignTextLabel(s: String, set: (IInspectable) -> Unit): Unit {
    let tb = TextBlock.new()
    try {
        tb.Text = HString(s)
        set(tb.asIInspectable())
    } finally {
        tb.close()
    }
}

// Build a SymbolIcon for a glyph. Caller owns the returned wrapper (close()).
func makeSymbolIcon(sym: SymbolGlyph): SymbolIcon {
    SymbolIcon.CreateInstanceWithSymbol(Symbol(sym.toRaw()))
}

// Set FrameworkElement.Tag (QI'd from the control's raw pointer) to a boxed
// string (IReference<HString>), used as the navigation/tab item key for
// tag-based selection lookups.
func setTagString(raw: CPointer<Unit>, s: String): Unit {
    let fe = FrameworkElement.fromAbiTake(
        queryRequired(raw, FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement")
    )
    try {
        let box = hStringReference(s)
        try {
            fe.Tag = box.asIInspectable()
        } finally {
            box.close()
        }
    } finally {
        fe.close()
    }
}

// Set a NavigationViewItem's Tag and RETAIN the boxed IReference<HString> for the
// owner's lifetime. WinUI's AddRef on this Cangjie ComObject (the StockReference
// backing the box) does NOT keep it rooted, so without a live Cangjie reference the
// stored HSTRING is freed while WinUI still template-binds it (0xC0000005 in
// WindowsDuplicateString during SetTemplateBinding). The retained box is freed by
// releaseNavTagBoxes on rebuild / destroy. Mirrors the explicit retention the
// codebase already uses for delegates. (Distinct from the shared setTagString, which
// closes the box immediately — fine for promptly-read keys like TabItemKey, but not
// for nav items whose Tag WinUI template-binds during a deferred layout pass.)
func setNavItemTagRetained(raw: CPointer<Unit>, s: String, ownerKey: UIntNative): Unit {
    let fe = FrameworkElement.fromAbiTake(
        queryRequired(raw, FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement")
    )
    try {
        let box = hStringReference(s)
        fe.Tag = box.asIInspectable()
        retainNavTagBox(ownerKey, box)   // do NOT close — keep it alive for WinUI
    } finally {
        fe.close()
    }
}

// Set NavigationView.PaneTitle (INavigationView2, takes a borrowed [in] HSTRING). Pass a
// genuine SYSTEM HSTRING (WindowsCreateString) rather than our Cangjie-fabricated HSTRING
// header: WinUI may retain/duplicate the value (PaneTitle is template-bound into the pane
// header), and a system HSTRING is one WinUI can safely WindowsDuplicateString later. We
// delete OUR system copy after the call; WinUI holds its own independent duplicate.
func setNavPaneTitle(nv: NavigationView, s: String): Unit {
    let hs = HString(s)
    try {
        let sysHandle = hs.toSystemHandleCopy()
        try {
            let iface = nv.asINavigationView2()
            checkHRESULT(unsafe { iface.SetPaneTitle(sysHandle) }, "INavigationView2.SetPaneTitle")
        } finally {
            releaseSystemHStringHandle(sysHandle)
        }
    } finally {
        hs.close()
    }
}

// Set the content of a ContentControl-derived item (NavigationViewItem /
// NavigationViewItemHeader) to a plain-text label via IContentControl.Content.
func setItemContentText(raw: CPointer<Unit>, text: String): Unit {
    let cc = ContentControl.fromAbiTake(
        queryRequired(raw, ContentControl.iid(), "Microsoft.UI.Xaml.Controls.IContentControl")
    )
    try {
        assignTextLabel(text, { insp => cc.Content = insp })
    } finally {
        cc.close()
    }
}

func ownedInspectable(raw: CPointer<Unit>, name: String): IInspectable {
    IInspectable.fromAbiTake(queryRequired(raw, IInspectable.iid(), name))
}

// Build a NavigationView menu entry from a NavViewItem def. Headers become a
// NavigationViewItemHeader; leaf/parent items become a NavigationViewItem with
// content, tag (defaulting to the content text), optional symbol icon, and a
// recursively-built child MenuItems collection. Caller owns the returned wrapper.
func buildNavViewItem(item: NavViewItem, ownerKey: UIntNative): IInspectable {
    if (item.isHeader) {
        let h = makeComposable(NavigationViewItemHeader.CreateInstance)
        try {
            setItemContentText(h.asRaw(), item.content)
            return ownedInspectable(h.asRaw(), "NavigationViewItemHeader.IInspectable")
        } finally {
            h.close()
        }
    }
    let nvItem = makeComposable(NavigationViewItem.CreateInstance)
    try {
        setItemContentText(nvItem.asRaw(), item.content)
        let tag = navViewItemTag(item)
        setNavItemTagRetained(nvItem.asRaw(), tag, ownerKey)
        match (item.icon) {
            case Some(sym) =>
                let icon = makeSymbolIcon(sym)
                try {
                    nvItem.Icon = IconElement.viewOf(icon.asRaw())
                } finally {
                    icon.close()
                }
            case None => ()
        }
        if (item.children.size > 0) {
            let iface = nvItem.asINavigationViewItem2()
            var menuRaw = CPointer<Unit>()
            checkHRESULT(
                unsafe { iface.MenuItems(CPointer<CPointer<Unit>>(inout menuRaw)) },
                "INavigationViewItem2.MenuItems"
            )
            let menu = IVectorRaw<IInspectable>.fromAbiTake(menuRaw)
            try {
                for (child in item.children) {
                    // After Append, WinUI's MenuItems owns the child; close our
                    // wrapper so WinUI is the sole owner (mirrors the reference,
                    // which drops nv_item after Append). menu.Clear()/destroy
                    // releases WinUI's refs.
                    let childObj = buildNavViewItem(child, ownerKey)
                    try {
                        checkHRESULT(unsafe { menu.Append(childObj.asRaw()) }, "NavigationViewItem.MenuItems.Append")
                    } finally {
                        childObj.close()
                    }
                }
            } finally {
                menu.close()
            }
        }
        return ownedInspectable(nvItem.asRaw(), "NavigationViewItem.IInspectable")
    } finally {
        nvItem.close()
    }
}

// Select a NavigationView menu item whose Tag equals `tag`. Defers the SelectedItem write
// until the control is Loaded (template applied, realized containers) — writing it during
// prophase makes WinUI's own OnApplyTemplate read a pre-realization item and AV. Once
// loaded, selects immediately by re-walking the live containers.
func selectNavItemByTag(nv: NavigationView, tag: String): Unit {
    let ownerKey = nv.asRaw().toUIntNative()
    if (!navIsLoaded(ownerKey)) {
        navPendingSelectTags[ownerKey] = tag
        return
    }
    navPendingSelectTags.remove(ownerKey)
    selectNavItemByTagNow(nv, tag)
}

// Apply a deferred programmatic selection once the NavigationView Loaded event has fired
// (event_nav.cj calls this). No-op when nothing was deferred for the owner.
func applyDeferredNavSelection(nv: NavigationView, ownerKey: UIntNative): Unit {
    match (navPendingSelectTags.get(ownerKey)) {
        case Some(tag) =>
            navPendingSelectTags.remove(ownerKey)
            selectNavItemByTagNow(nv, tag)
        case None => ()
    }
}

// Re-walk the LIVE nv.MenuItems (mirrors the reference select_nav_item_by_tag, convert.rs):
// match top-level by FrameworkElement.Tag, else descend one level of child MenuItems,
// assigning the live realized container as SelectedItem.
func selectNavItemByTagNow(nv: NavigationView, tag: String): Unit {
    let menu = nv.MenuItems
    try {
        var size = 0u32
        checkHRESULT(unsafe { menu.Size(CPointer<UInt32>(inout size)) }, "NavigationView.MenuItems.Size")
        var i = 0u32
        while (i < size) {
            var slot = CPointer<Unit>()
            checkHRESULT(unsafe { menu.GetAt(i, CPointer<CPointer<Unit>>(inout slot)) }, "NavigationView.MenuItems.GetAt")
            if (slot.isNotNull()) {
                let item = IInspectable.fromAbiTake(slot)
                try {
                    if (navItemTagEquals(item.asRaw(), tag)) {
                        nv.SelectedItem = IInspectable.viewOf(item.asRaw())
                        return
                    }
                    if (selectNavChildByTag(nv, item.asRaw(), tag)) {
                        return
                    }
                } finally {
                    item.close()
                }
            }
            i++
        }
    } finally {
        menu.close()
    }
}

// Search one level of child MenuItems of a NavigationViewItem (raw pointer) for a
// matching tag; on hit assign the child as SelectedItem. Returns whether matched.
func selectNavChildByTag(nv: NavigationView, parentRaw: CPointer<Unit>, tag: String): Bool {
    let item = NavigationViewItem.viewOf(parentRaw)
    let iface = item.asINavigationViewItem2()
    var childRaw = CPointer<Unit>()
    checkHRESULT(
        unsafe { iface.MenuItems(CPointer<CPointer<Unit>>(inout childRaw)) },
        "INavigationViewItem2.MenuItems"
    )
    if (childRaw.isNull()) {
        return false
    }
    let children = IVectorRaw<IInspectable>.fromAbiTake(childRaw)
    try {
        var size = 0u32
        checkHRESULT(unsafe { children.Size(CPointer<UInt32>(inout size)) }, "NavigationViewItem.MenuItems.Size")
        var j = 0u32
        while (j < size) {
            var slot = CPointer<Unit>()
            checkHRESULT(unsafe { children.GetAt(j, CPointer<CPointer<Unit>>(inout slot)) }, "NavigationViewItem.MenuItems.GetAt")
            if (slot.isNotNull()) {
                let child = IInspectable.fromAbiTake(slot)
                try {
                    if (navItemTagEquals(child.asRaw(), tag)) {
                        nv.SelectedItem = IInspectable.viewOf(child.asRaw())
                        return true
                    }
                } finally {
                    child.close()
                }
            }
            j++
        }
    } finally {
        children.close()
    }
    false
}

// Whether the item at `raw` is a FrameworkElement whose Tag (a boxed HString)
// equals `tag`.
func navItemTagEquals(raw: CPointer<Unit>, tag: String): Bool {
    let fe = FrameworkElement.fromAbiTake(
        queryRequired(raw, FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement")
    )
    try {
        // Tag is boxed as IReference<HString>; read it back through an HString view.
        let boxed = fe.Tag
        try {
            return hStringReferenceValue(boxed.asRaw()) == tag
        } finally {
            boxed.close()
        }
    } finally {
        fe.close()
    }
}

// Unbox a Tag IInspectable raw pointer (a boxed IReference<HString>) to its
// String value (empty when the box is null or not a string reference). The Tag
// object's identity QIs to IReference<HString>; viewOf wraps it non-owningly and
// Value() performs the boxed read (the returned HString is GC-managed).
func hStringReferenceValue(raw: CPointer<Unit>): String {
    if (raw.isNull()) {
        return ""
    }
    match (unsafe { queryInterfaceRaw(raw, IReference<HString>.iid()) }) {
        case Some(refRaw) =>
            let box = IReference<HString>.fromAbiTake(refRaw)
            try {
                let hs = unsafe { box.Value() }
                return hs.toString()
            } finally {
                box.close()
            }
        case None => return ""
    }
}

// Populate the AutoSuggestBox's ItemsSource with boxed strings. No-op when the
// NavigationView has no AutoSuggestBox set. The items flow through a managed
// IVector<IInspectable> of boxed HStrings assigned via IItemsControl.ItemsSource.
func setNavAutoSuggestItems(nv: NavigationView, items: ArrayList<String>): Unit {
    let asb = nv.AutoSuggestBox
    try {
        if (asb.asRaw().isNull()) {
            return
        }
        let boxes = ArrayList<IReference<HString>>()
        let seed = ArrayList<IInspectable>()
        for (s in items) {
            let box = hStringReference(s)
            boxes.add(box)
            seed.add(box.asIInspectable())
        }
        let vec = toInspectableVector(seed)
        try {
            let itemsControl = asb.asIItemsControl()
            checkHRESULT(unsafe { itemsControl.SetItemsSource(vec.asRaw()) }, "IItemsControl.SetItemsSource")
        } finally {
            vec.close()
            for (box in boxes) {
                box.close()
            }
        }
    } finally {
        asb.close()
    }
}

// Populate BreadcrumbBar.ItemsSource with boxed crumb strings. The items flow
// through a managed IVector<IInspectable> of boxed HStrings assigned via the
// high-level ItemsSource (IInspectable) projection property — the same boxing +
// vector seeding the AutoSuggestBox path uses. The vector + its boxes are held
// live until AFTER the setter runs (the control AddRefs the vector through the
// assignment), then closed; closing earlier would free the value the projection
// just borrowed. Mirrors setNavAutoSuggestItems.
func setBreadcrumbItems(bb: BreadcrumbBar, items: ArrayList<String>): Unit {
    let boxes = ArrayList<IReference<HString>>()
    let seed = ArrayList<IInspectable>()
    for (s in items) {
        let box = hStringReference(s)
        boxes.add(box)
        seed.add(box.asIInspectable())
    }
    let vec = toInspectableVector(seed)
    try {
        bb.ItemsSource = vec.asIInspectable()
    } finally {
        vec.close()
        for (box in boxes) {
            box.close()
        }
    }
}

// Rebuild a MenuBar's items: each MenuBarItemDef becomes a MenuBarItem (title +
// recursively-built flyout items). The visual tree is rebuilt statelessly here;
// click-handler re-wiring is performed by backend.cj using its menuClickHandlers
// registry after this returns true (see NEEDS BACKEND STATE).
func rebuildMenuBar(mb: MenuBar, items: ArrayList<MenuBarItemDef>): Unit {
    let barItems = mb.Items
    try {
        checkHRESULT(unsafe { barItems.Clear() }, "MenuBar.Items.Clear")
        for (barDef in items) {
            let mbi = makeComposable(MenuBarItem.CreateInstance)
            try {
                mbi.Title = HString(barDef.title)
                let flyoutItems = mbi.Items
                try {
                    for (menuDef in barDef.items) {
                        let fi = buildMenuFlyoutItemBase(menuDef)
                        try {
                            checkHRESULT(unsafe { flyoutItems.Append(fi.asRaw()) }, "MenuBarItem.Items.Append")
                        } finally {
                            fi.close()
                        }
                    }
                } finally {
                    flyoutItems.close()
                }
                checkHRESULT(unsafe { barItems.Append(mbi.asRaw()) }, "MenuBar.Items.Append")
            } finally {
                mbi.close()
            }
        }
    } finally {
        barItems.close()
    }
}

// Recursively build a MenuFlyoutItemBase from a MenuItemDef. Returns an
// IInspectable view of the built item (its raw pointer is appended into a
// MenuFlyoutItemBase collection). Caller owns the returned wrapper.
func buildMenuFlyoutItemBase(def: MenuItemDef): IInspectable {
    match (def) {
        case Item(text) =>
            let item = makeComposable(MenuFlyoutItem.CreateInstance)
            try {
                item.Text = HString(text)
                return ownedInspectable(item.asRaw(), "MenuFlyoutItem.IInspectable")
            } finally {
                item.close()
            }
        case Separator =>
            let sep = makeComposable(MenuFlyoutSeparator.CreateInstance)
            try {
                return ownedInspectable(sep.asRaw(), "MenuFlyoutSeparator.IInspectable")
            } finally {
                sep.close()
            }
        case SubItem(text, children) =>
            let sub = MenuFlyoutSubItem.new()
            try {
                sub.Text = HString(text)
                let subItems = sub.Items
                try {
                    for (child in children) {
                        let childItem = buildMenuFlyoutItemBase(child)
                        try {
                            checkHRESULT(unsafe { subItems.Append(childItem.asRaw()) }, "MenuFlyoutSubItem.Items.Append")
                        } finally {
                            childItem.close()
                        }
                    }
                } finally {
                    subItems.close()
                }
                return ownedInspectable(sub.asRaw(), "MenuFlyoutSubItem.IInspectable")
            } finally {
                sub.close()
            }
    }
}

// Canonical PIID for Windows.Foundation.Collections.IVector<ICommandBarElement>.
//
// Same mis-hash defect already worked around for IVector<Object>/IMap<Object,Object>
// (see util.cj inspectableVectorIid): the generated
// Windows_Foundation_Collections_IVector_1<ICommandBarElement>.iid() builds the
// parameterized signature "pinterface({913337e9-…};" + T.signature() + ")", but the
// element token T.signature() is taken through the windows_core.RuntimeType static
// witness, which for a plain WinRT interface resolves to the inherited RuntimeName
// default (the interface's *runtime class name*, e.g.
// "Microsoft.UI.Xaml.Controls.ICommandBarElement") instead of the WinRT
// interface-parameter form ("{<iid>}"). The wrong element token hashes to a wrong
// v5 PIID, so QueryInterface against the real CommandBar / CommandBarFlyout command
// collections (which only answer the canonical IID) returns E_NOINTERFACE and the
// AppBarButtons never get appended — the bar renders empty.
//
// We rebuild the signature with the element token spelled explicitly as the
// interface's IID in braces (the correct WinRT interface-parameter form, derived
// from ICommandBarElement.iid() so it cannot drift) and hash that, reproducing the
// canonical IID the runtime collection actually exposes.
func commandBarElementVectorIid(): GUID {
    let elem = ICommandBarElement.iid().toSignatureString()
    GUID.from_signature("pinterface({913337e9-11a1-4345-a3a2-4e7f956e222d};{${elem}})")
}

// Wrap a CommandBar PrimaryCommands/SecondaryCommands raw pointer (an
// IObservableVector) as its IVector<ICommandBarElement> base so mutating methods
// (Clear/Append) are reachable. The IObservableVector wrapper only exposes the
// observable surface; the mutators live on the IVector base.
func commandBarVectorFromRaw(raw: CPointer<Unit>): IVectorRaw<ICommandBarElement> {
    IVectorRaw<ICommandBarElement>.fromAbiTake(
        queryRequired(raw, commandBarElementVectorIid(), "Windows.Foundation.Collections.IVector<ICommandBarElement>")
    )
}

// Clear and repopulate a command-bar element vector. Click-handler re-wiring is
// done by backend.cj (menuClickHandlers registry) after this returns.
func rebuildCommandBarVector(vec: IVectorRaw<ICommandBarElement>, cmds: ArrayList<CommandBarCommandDef>): Unit {
    try {
        checkHRESULT(unsafe { vec.Clear() }, "CommandBar.commands.Clear")
        for (def in cmds) {
            let el = buildCommandBarElement(def)
            try {
                checkHRESULT(unsafe { vec.Append(el.asRaw()) }, "CommandBar.commands.Append")
            } finally {
                el.close()
            }
        }
    } finally {
        vec.close()
    }
}

// ── per-item Click wiring (driven by the backend menuClickHandlers registry) ──
//
// These mirror the reference wire_menu_bar_clicks / wire_command_bar_clicks. The
// backend stores the reconciler's EventHandler per control and calls these after
// every MenuBar / CommandBar item rebuild (and once at attach time for controls
// whose items already exist), re-attaching a Click subscription on each leaf
// item. The per-leaf wiring itself reuses the shared workers in props_button.cj
// (wireFlyoutItemsClick / wireCommandBarElementsClick) so the MenuBar, MenuFlyout,
// CommandBar and CommandBarFlyout paths stay behaviourally identical.

// Wire Click on every MenuFlyoutItem within a MenuBar (each MenuBarItem owns a
// MenuFlyoutItemBase collection), recursing into sub-items. Returns the
// collected revokers.
func wireMenuBarClicks(mb: MenuBar, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    let barItems = mb.Items
    try {
        var size = 0u32
        checkHRESULT(unsafe { barItems.Size(CPointer<UInt32>(inout size)) }, "MenuBar.Items.Size")
        var i = 0u32
        while (i < size) {
            var slot = CPointer<Unit>()
            checkHRESULT(unsafe { barItems.GetAt(i, CPointer<CPointer<Unit>>(inout slot)) }, "MenuBar.Items.GetAt")
            if (slot.isNotNull()) {
                let mbi = MenuBarItem.fromAbiTake(slot)
                try {
                    let flyoutItems = mbi.Items
                    wireFlyoutItemsClick(flyoutItems, handler, revokers)
                } finally {
                    mbi.close()
                }
            }
            i++
        }
    } finally {
        barItems.close()
    }
    revokers
}

// Wire Click on every AppBarButton in a CommandBar's primary + secondary command
// collections. Returns the collected revokers.
func wireCommandBarClicks(cb: CommandBar, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    let primary = cb.PrimaryCommands
    try {
        wireCommandBarElementsClick(primary.asRaw(), handler, revokers)
    } finally {
        primary.close()
    }
    let secondary = cb.SecondaryCommands
    try {
        wireCommandBarElementsClick(secondary.asRaw(), handler, revokers)
    } finally {
        secondary.close()
    }
    revokers
}

// Build a command-bar element (AppBarButton / AppBarToggleButton / AppBarSeparator)
// from a CommandBarCommandDef. Returns an IInspectable view; caller owns it.
func buildCommandBarElement(def: CommandBarCommandDef): IInspectable {
    match (def) {
        case Button(label, icon) =>
            let btn = makeComposable(AppBarButton.CreateInstance)
            try {
                btn.Label = HString(label)
                match (icon) {
                    case Some(sym) =>
                        let ic = makeSymbolIcon(sym)
                        try {
                            btn.Icon = IconElement.viewOf(ic.asRaw())
                        } finally {
                            ic.close()
                        }
                    case None => ()
                }
                return ownedInspectable(btn.asRaw(), "AppBarButton.IInspectable")
            } finally {
                btn.close()
            }
        case Toggle(label, icon) =>
            let btn = makeComposable(AppBarToggleButton.CreateInstance)
            try {
                btn.Label = HString(label)
                match (icon) {
                    case Some(sym) =>
                        let ic = makeSymbolIcon(sym)
                        try {
                            btn.Icon = IconElement.viewOf(ic.asRaw())
                        } finally {
                            ic.close()
                        }
                    case None => ()
                }
                return ownedInspectable(btn.asRaw(), "AppBarToggleButton.IInspectable")
            } finally {
                btn.close()
            }
        case Separator =>
            let sep = makeComposable(AppBarSeparator.CreateInstance)
            try {
                return ownedInspectable(sep.asRaw(), "AppBarSeparator.IInspectable")
            } finally {
                sep.close()
            }
    }
}
