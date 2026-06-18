package windows_reactor.winui

import std.collection.{HashMap}
import windows_reactor.core.{Prop, ControlKind, ThemeRef}
import windows_core.{HString, queryInterfaceRaw}
import windows_reference.hStringReference
import windows_reactor.bindings.{FrameworkElement, Style}
import windows_reactor.bindings.XamlReader
// ============================================================================
// Theme-binding + Resources family — faithfully ported from the reference
// winui/backend/mod.rs apply_theme_resource_style / style_target_for_handle /
// on_theme_changed (and the (Prop::Resources, …) set_prop arm).
//
// priority: P6-critical. Theme bindings (Background / Foreground / BorderBrush
// bound to {ThemeResource} keys) drive light/dark reactivity across the gallery;
// Resources populates a control's ResourceDictionary. Both are on the critical
// path.
//
// Behaviour-equivalence notes (CLAUDE.md / spec §8.6):
//   - The XAML <Style …> string built in themeStyleTargetFor / themeApplyBindings
//     is the ONE allowed string in the command backend: WinUI's theme mechanism
//     re-resolves {ThemeResource} values natively on Light↔Dark switches only
//     when a Style carrying ThemeResource setters is (re)applied. There is no
//     high-level projection alternative.
//   - put_Style(None) is expressed as `fe.Style = Style.viewOf(CPointer<Unit>())`
//     — a null, non-owning Style view (mirrors the reference `put_Style(None)`).
//     Clearing the style first forces WinUI to re-resolve the {ThemeResource}
//     values when the real Style is then applied.
//   - XamlReader.Load(HString) -> IInspectable; the result is QI'd to the Style
//     identity (mirrors the reference `obj.cast::<Xaml::Style>()`).
//   - FrameworkElement.Resources is a ResourceDictionary whose identity QIs to
//     IMap<IInspectable, IInspectable>; each (key, value) string pair is boxed
//     through IReference<HString> (hStringReference) and inserted via the raw
//     ABI Insert(key, value, out Bool) wrapped in checkHRESULT.
// ============================================================================

// Build and apply a XAML Style with {ThemeResource} setters for the given
// (Prop, ThemeRef) bindings to the control. Mirrors apply_theme_resource_style.
func themeApplyBindings(handle: Handle, kind: ControlKind, bindings: Array<(Prop, ThemeRef)>): Unit {
    // `kind` is unused (the TargetType is derived from the handle variant, which
    // already corresponds to the kind); kept to match the stub signature.
    let _ = kind

    // Only Border / StackPanel / Grid / Button / TextBlock / Canvas have a
    // TargetType mapping (style_target_for_handle); others are a no-op.
    let targetType = match (themeStyleTargetFor(handle)) {
        case Some(t) => t
        case None => return
    }

    let fe = FrameworkElement.fromAbiTake(
        queryRequired(handle.asRaw(), FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement")
    )
    try {
        // Build the Setter fragments for the supported (Prop, ThemeRef) pairs.
        var setters = ""
        for ((propKind, themeRef) in bindings) {
            let dpName = match (propKind) {
                case Background => "Background"
                case Foreground => "Foreground"
                case BorderBrush => "BorderBrush"
                case _ => continue
            }
            let resourceKey = themeRef.resourceKey()
            setters += "<Setter Property='${dpName}' Value='{ThemeResource ${resourceKey}}'/>"
        }

        // No applicable setters: clear any applied style (put_Style(None)).
        if (setters == "") {
            fe.Style = Style.viewOf(CPointer<Unit>())
            return
        }

        let xaml = "<Style xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' TargetType='${targetType}'>${setters}</Style>"

        // Load the Style XAML; on a parse/load failure log and leave the control
        // unstyled (mirrors the reference XamlReader::Load Err arm).
        try {
            let hs = HString(xaml)
            let loaded = XamlReader.Load(hs)
            hs.close()
            try {
                match (unsafe { queryInterfaceRaw(loaded.asRaw(), Style.iid()) }) {
                    case Some(styleRaw) =>
                        let style = Style.fromAbiTake(styleRaw)
                        try {
                            // Clear first to force WinUI to re-resolve {ThemeResource}.
                            fe.Style = Style.viewOf(CPointer<Unit>())
                            fe.Style = style
                        } finally {
                            style.close()
                        }
                    case None => ()
                }
            } finally {
                loaded.close()
            }
        } catch (e: Exception) {
            println("[ThemeStyle] XamlReader.Load failed: ${e} xaml=${xaml}")
        }
    } finally {
        fe.close()
    }
}

// Re-apply every registered theme binding after an app theme change. Mirrors
// on_theme_changed: iterate the registry, and for each control that is still
// live re-apply its theme Style (WinUI re-resolves {ThemeResource} on the
// re-application).
func themeReapplyAll(controls: HashMap<UInt32, Handle>,
                     registry: HashMap<UInt32, (ControlKind, Array<(Prop, ThemeRef)>)>): Unit {
    for ((id, entry) in registry) {
        match (controls.get(id)) {
            case Some(handle) =>
                let (kind, bindings) = entry
                themeApplyBindings(handle, kind, bindings)
            case None => ()
        }
    }
}

// Populate the control's FrameworkElement.Resources ResourceDictionary from the
// string key/value map. Mirrors the reference (Prop::Resources, …) set_prop arm:
// QI Resources to IMap<IInspectable, IInspectable>, then Insert each (key, value)
// boxed through IReference<HString>.
func resourcesApply(handle: Handle, map: HashMap<String, String>): Unit {
    let fe = FrameworkElement.fromAbiTake(
        queryRequired(handle.asRaw(), FrameworkElement.iid(), "Microsoft.UI.Xaml.IFrameworkElement")
    )
    try {
        let rd = fe.Resources
        try {
            let imap = rd.asIMap()
            try {
                for ((k, v) in map) {
                    let keyBox = hStringReference(k)
                    try {
                        let valBox = hStringReference(v)
                        try {
                            var inserted = false
                            checkHRESULT(
                                unsafe {
                                    imap.Insert(keyBox.asRaw(), valBox.asRaw(), CPointer<Bool>(inout inserted))
                                },
                                "FrameworkElement.Resources.Insert"
                            )
                        } finally {
                            valBox.close()
                        }
                    } finally {
                        keyBox.close()
                    }
                }
            } finally {
                imap.close()
            }
        } finally {
            rd.close()
        }
    } finally {
        fe.close()
    }
}

// Get the XAML TargetType name for a Handle. Mirrors style_target_for_handle:
// only Border / StackPanel / Grid / Button / TextBlock / Canvas map; all other
// handles return None (the caller then no-ops). The reference also returns the
// IFrameworkElement, but here the FrameworkElement is QI'd at the call site.
func themeStyleTargetFor(handle: Handle): ?String {
    match (handle) {
        case BorderH(_) => Some("Border")
        case StackPanelH(_) => Some("StackPanel")
        case GridH(_) => Some("Grid")
        case ButtonH(_) => Some("Button")
        case TextBlockH(_) => Some("TextBlock")
        case CanvasH(_) => Some("Canvas")
        case _ => None
    }
}
