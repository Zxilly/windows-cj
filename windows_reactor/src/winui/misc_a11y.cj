package windows_reactor.winui

import std.collection.{ArrayList}
import windows_core.HString
import windows_interface.{IInspectable}
import windows_reference.{hStringReference}
import windows_reactor.core.{
    AccessibilityModifiers, KeyboardAccelerator as ReactorKeyboardAccelerator, Tooltip,
    TooltipContent, TooltipPlacement, PointerHandlers, PointerEventInfo,
    LiveSetting, HeadingLevel, KeyboardKey, Element
}
import windows_common.Microsoft.UI.Xaml.{UIElement, DependencyObject}
import windows_common.Microsoft.UI.Xaml.Automation.{AutomationProperties}
import windows_common.Microsoft.UI.Xaml.Input.{
    KeyboardAccelerator as XamlKeyboardAccelerator,
    KeyboardAcceleratorInvokedEventArgs,
    PointerEventHandler, TappedEventHandler, RightTappedEventHandler,
    PointerRoutedEventArgs
}
import windows_common.Microsoft.UI.Input.{PointerPoint}
import windows_common.Microsoft.UI.Xaml.Controls.{TextBlock, StackPanel, Panel, ContentControl, ToolTip, ToolTipService, Image}
import windows_common.Microsoft.UI.Xaml.Media.{ImageSource}
import windows_common.Foundation.{TypedEventHandler}
import windows_common.impl.{
    Microsoft_UI_Xaml_Automation_Peers_AutomationLiveSetting_Off as LiveSetting_Off,
    Microsoft_UI_Xaml_Automation_Peers_AutomationLiveSetting_Polite as LiveSetting_Polite,
    Microsoft_UI_Xaml_Automation_Peers_AutomationLiveSetting_Assertive as LiveSetting_Assertive,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_None as HeadingLevel_None,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_Level1 as HeadingLevel_Level1,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_Level2 as HeadingLevel_Level2,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_Level3 as HeadingLevel_Level3,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_Level4 as HeadingLevel_Level4,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_Level5 as HeadingLevel_Level5,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_Level6 as HeadingLevel_Level6,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_Level7 as HeadingLevel_Level7,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_Level8 as HeadingLevel_Level8,
    Microsoft_UI_Xaml_Automation_Peers_AutomationHeadingLevel_Level9 as HeadingLevel_Level9,
    Windows_System_VirtualKey as XamlVirtualKey,
    Windows_System_VirtualKeyModifiers as XamlVirtualKeyModifiers,
    Microsoft_UI_Xaml_Input_KeyboardAcceleratorPlacementMode_Hidden as AcceleratorPlacement_Hidden,
    Microsoft_UI_Xaml_Controls_Primitives_PlacementMode as XamlPlacementMode,
    Microsoft_UI_Xaml_Controls_Primitives_PlacementMode_Top as Placement_Top,
    Microsoft_UI_Xaml_Controls_Primitives_PlacementMode_Bottom as Placement_Bottom,
    Microsoft_UI_Xaml_Controls_Primitives_PlacementMode_Left as Placement_Left,
    Microsoft_UI_Xaml_Controls_Primitives_PlacementMode_Right as Placement_Right,
    Microsoft_UI_Xaml_Controls_Primitives_PlacementMode_Mouse as Placement_Mouse,
    Microsoft_UI_Xaml_Controls_Orientation_Vertical as Orientation_Vertical,
    Microsoft_UI_Xaml_Controls_Orientation_Horizontal as Orientation_Horizontal,
    Windows_System_VirtualKey_A, Windows_System_VirtualKey_B, Windows_System_VirtualKey_C,
    Windows_System_VirtualKey_D, Windows_System_VirtualKey_E, Windows_System_VirtualKey_F,
    Windows_System_VirtualKey_G, Windows_System_VirtualKey_H, Windows_System_VirtualKey_I,
    Windows_System_VirtualKey_J, Windows_System_VirtualKey_K, Windows_System_VirtualKey_L,
    Windows_System_VirtualKey_M, Windows_System_VirtualKey_N, Windows_System_VirtualKey_O,
    Windows_System_VirtualKey_P, Windows_System_VirtualKey_Q, Windows_System_VirtualKey_R,
    Windows_System_VirtualKey_S, Windows_System_VirtualKey_T, Windows_System_VirtualKey_U,
    Windows_System_VirtualKey_V, Windows_System_VirtualKey_W, Windows_System_VirtualKey_X,
    Windows_System_VirtualKey_Y, Windows_System_VirtualKey_Z,
    Windows_System_VirtualKey_Number0, Windows_System_VirtualKey_Number1,
    Windows_System_VirtualKey_Number2, Windows_System_VirtualKey_Number3,
    Windows_System_VirtualKey_Number4, Windows_System_VirtualKey_Number5,
    Windows_System_VirtualKey_Number6, Windows_System_VirtualKey_Number7,
    Windows_System_VirtualKey_Number8, Windows_System_VirtualKey_Number9,
    Windows_System_VirtualKey_NumberPad0, Windows_System_VirtualKey_NumberPad1,
    Windows_System_VirtualKey_NumberPad2, Windows_System_VirtualKey_NumberPad3,
    Windows_System_VirtualKey_NumberPad4, Windows_System_VirtualKey_NumberPad5,
    Windows_System_VirtualKey_NumberPad6, Windows_System_VirtualKey_NumberPad7,
    Windows_System_VirtualKey_NumberPad8, Windows_System_VirtualKey_NumberPad9,
    Windows_System_VirtualKey_Add, Windows_System_VirtualKey_Subtract,
    Windows_System_VirtualKey_Multiply, Windows_System_VirtualKey_Divide,
    Windows_System_VirtualKey_Decimal,
    Windows_System_VirtualKey_F1, Windows_System_VirtualKey_F2, Windows_System_VirtualKey_F3,
    Windows_System_VirtualKey_F4, Windows_System_VirtualKey_F5, Windows_System_VirtualKey_F6,
    Windows_System_VirtualKey_F7, Windows_System_VirtualKey_F8, Windows_System_VirtualKey_F9,
    Windows_System_VirtualKey_F10, Windows_System_VirtualKey_F11, Windows_System_VirtualKey_F12,
    Windows_System_VirtualKey_Enter, Windows_System_VirtualKey_Escape, Windows_System_VirtualKey_Tab,
    Windows_System_VirtualKey_Space, Windows_System_VirtualKey_Back, Windows_System_VirtualKey_Delete,
    Windows_System_VirtualKey_Insert, Windows_System_VirtualKey_Home, Windows_System_VirtualKey_End,
    Windows_System_VirtualKey_PageUp, Windows_System_VirtualKey_PageDown,
    Windows_System_VirtualKey_Left, Windows_System_VirtualKey_Right,
    Windows_System_VirtualKey_Up, Windows_System_VirtualKey_Down
}

// ============================================================================
// Accessibility / keyboard / tooltip / pointer family — free-function impls.
//
// priority: polish (off the parity critical path). UI Automation properties,
// keyboard accelerators, tooltips and pointer handlers are universal element
// decorations applied via attached properties / the IUIElement event surface.
//
// Ported faithfully from the reference backend's set_accessibility /
// set_keyboard_accelerators / set_tooltip / set_pointer_handlers.
//
// Projection ABI (verified against windows_common):
//   - AutomationProperties.SetName / SetAutomationId / SetHelpText are statics
//     taking (DependencyObject, HString); SetLiveSetting / SetHeadingLevel take
//     the corresponding Automation.Peers enum. Every backend-creatable control
//     QIs to DependencyObject (it derives FrameworkElement → UIElement →
//     DependencyObject), so the cast always succeeds.
//   - UIElement.KeyboardAccelerators is a get-only IVector<KeyboardAccelerator>
//     (Clear() / Append(ka), both `unsafe`). KeyboardAccelerator is composable
//     (CreateInstance); IKeyboardAccelerator exposes Key (VirtualKey) /
//     Modifiers (VirtualKeyModifiers) mut props and addInvoked/removeInvoked
//     (a TypedEventHandler<KeyboardAccelerator, KeyboardAcceleratorInvokedEventArgs>).
//     UIElement.KeyboardAcceleratorPlacementMode is set to Hidden to suppress
//     the default accelerator tooltip (mirrors the reference).
//   - ToolTipService.SetToolTip is a static (DependencyObject, IInspectable);
//     a plain string is boxed via hStringReference (auto-unwrapped by WinUI), a
//     rich element is mounted into a ToolTip ContentControl. SetPlacement takes
//     the Primitives.PlacementMode enum; cleared placement falls back to Top.
//   - Pointer / tap handlers are wired on the high-level UIElement event surface
//     (addTapped/addRightTapped/addPointerPressed/addPointerReleased/
//     addPointerExited), each returning a token managed by an EventRevoker.
// ============================================================================

// Apply UI Automation properties to the control. Mirrors set_accessibility:
// resolve to a DependencyObject, then set Name / AutomationId / HelpText
// (None → ""), LiveSetting (None | Off → Off) and HeadingLevel (None → None).
func a11ySetAccessibility(handle: Handle, accessibility: AccessibilityModifiers): Unit {
    let dep = handleDependencyObject(handle)
    try {
        a11ySetAutomationString({ s => AutomationProperties.SetName(dep, s) }, accessibility.automationName)
        a11ySetAutomationString({ s => AutomationProperties.SetAutomationId(dep, s) }, accessibility.automationId)
        a11ySetAutomationString({ s => AutomationProperties.SetHelpText(dep, s) }, accessibility.helpText)

        let live = match (accessibility.liveSetting) {
            case Some(LiveSetting.Polite) => LiveSetting_Polite
            case Some(LiveSetting.Assertive) => LiveSetting_Assertive
            case _ => LiveSetting_Off
        }
        AutomationProperties.SetLiveSetting(dep, live)

        let heading = match (accessibility.headingLevel) {
            case Some(HeadingLevel.Level1) => HeadingLevel_Level1
            case Some(HeadingLevel.Level2) => HeadingLevel_Level2
            case Some(HeadingLevel.Level3) => HeadingLevel_Level3
            case Some(HeadingLevel.Level4) => HeadingLevel_Level4
            case Some(HeadingLevel.Level5) => HeadingLevel_Level5
            case Some(HeadingLevel.Level6) => HeadingLevel_Level6
            case Some(HeadingLevel.Level7) => HeadingLevel_Level7
            case Some(HeadingLevel.Level8) => HeadingLevel_Level8
            case Some(HeadingLevel.Level9) => HeadingLevel_Level9
            case None => HeadingLevel_None
        }
        AutomationProperties.SetHeadingLevel(dep, heading)
    } finally {
        dep.close()
    }
}

// Rebuild the control's KeyboardAccelerators collection. Mirrors
// set_keyboard_accelerators: clear the IVector, suppress the default accelerator
// tooltip (placement = Hidden), then for each accelerator create a
// KeyboardAccelerator, set Key/Modifiers, wire its Invoked event (Handled = true
// then invoke the callback), and append it.
func a11ySetKeyboardAccelerators(handle: Handle, accelerators: Array<ReactorKeyboardAccelerator>): Unit {
    let ui = handleUIElementOwned(handle)
    try {
        ui.KeyboardAcceleratorPlacementMode = AcceleratorPlacement_Hidden
        let vec = ui.KeyboardAccelerators
        try {
            unsafe { vec.Clear() }
            for (accel in accelerators) {
                let ka = makeComposable(XamlKeyboardAccelerator.CreateInstance)
                ka.Key = reactorKeyToVirtualKey(accel.key)
                ka.Modifiers = XamlVirtualKeyModifiers(accel.modifiers.bits)
                let cb = accel.onInvoked
                // The delegate is owned by the KeyboardAccelerator once appended
                // (the IVector AddRefs through the borrowed raw), so it stays
                // alive for the lifetime of the accelerator in the collection.
                let delegate = TypedEventHandler<XamlKeyboardAccelerator, KeyboardAcceleratorInvokedEventArgs>.new({ _, args =>
                    try {
                        if (args.isNotNull()) {
                            let ia = KeyboardAcceleratorInvokedEventArgs.viewOf(args)
                            ia.Handled = true
                        }
                        cb.invoke(())
                    } catch (_: Exception) {
                        // Never let a handler exception cross the Invoke FFI boundary.
                        ()
                    }
                })
                ka.addInvoked(delegate)
                unsafe { vec.Append(ka.asRaw()) }
            }
        } finally {
            vec.close()
        }
    } finally {
        ui.close()
    }
}

// Set (or clear) the control's tooltip via ToolTipService. Mirrors set_tooltip:
// a Text tooltip is boxed (auto-unwrapped by WinUI); a Rich tooltip mounts its
// element into a ToolTip. Clearing assigns a null IInspectable. Placement falls
// back to Top so a cleared placement actually resets the slot.
func a11ySetTooltip(handle: Handle, tooltip: ?Tooltip): Unit {
    let dep = handleDependencyObject(handle)
    try {
        match (tooltip) {
            case None =>
                ToolTipService.SetToolTip(dep, IInspectable.viewOf(CPointer<Unit>()))
            case Some(t) =>
                match (t.content) {
                    case Text(s) =>
                        // Box the string; ToolTipService auto-unwraps an
                        // IReference<HSTRING> to a text tooltip.
                        let boxed = hStringReference(s)
                        try {
                            ToolTipService.SetToolTip(dep, boxed.asIInspectable())
                        } finally {
                            boxed.close()
                        }
                    case Rich(elem) =>
                        let tt = makeComposable(ToolTip.CreateInstance)
                        try {
                            match (mountStaticTooltipElement(elem)) {
                                case Some(ui) =>
                                    // ToolTip derives ContentControl; QI to the
                                    // ContentControl surface and set Content to the
                                    // mounted element view (the setter AddRefs).
                                    let cc = ContentControl.fromAbiTake(
                                        queryRequired(tt.asRaw(), ContentControl.iid(),
                                            "Microsoft.UI.Xaml.Controls.IContentControl"))
                                    try {
                                        cc.Content = ui.asIInspectable()
                                    } finally {
                                        cc.close()
                                        ui.close()
                                    }
                                case None => ()
                            }
                            ToolTipService.SetToolTip(dep, tt.asIInspectable())
                        } finally {
                            tt.close()
                        }
                }
        }

        let placement = match (tooltip) {
            case Some(t) =>
                match (t.placement) {
                    case Some(p) => mapPlacement(p)
                    case None => Placement_Top
                }
            case None => Placement_Top
        }
        ToolTipService.SetPlacement(dep, placement)
    } finally {
        dep.close()
    }
}

// Wire (or clear) the per-element pointer / tap handlers on the IUIElement event
// surface. `handlers` is None to clear (the backend already revoked the prior
// set before calling). Returns the owning revokers (empty when nothing wired).
//
// Mirrors set_pointer_handlers: each present callback subscribes the matching
// UIElement event; pressed/released read the button state from the args.
func a11ySetPointerHandlers(handle: Handle, handlers: ?PointerHandlers): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    let h = match (handlers) {
        case Some(v) => v
        case None => return revokers
    }
    if (h.isEmpty()) {
        return revokers
    }
    let ui = handleUIElementOwned(handle)
    var keptUi = false
    try {
        match (h.onTapped) {
            case Some(cb) =>
                let delegate = TappedEventHandler.new({ _, _ =>
                    try { cb.invoke(()) } catch (_: Exception) { () }
                })
                let token = ui.addTapped(delegate)
                revokers.add(EventRevoker({ =>
                    try { ui.removeTapped(token) } catch (_: Exception) { () }
                    delegate.close()
                }))
            case None => ()
        }
        match (h.onRightTapped) {
            case Some(cb) =>
                let delegate = RightTappedEventHandler.new({ _, _ =>
                    try { cb.invoke(()) } catch (_: Exception) { () }
                })
                let token = ui.addRightTapped(delegate)
                revokers.add(EventRevoker({ =>
                    try { ui.removeRightTapped(token) } catch (_: Exception) { () }
                    delegate.close()
                }))
            case None => ()
        }
        match (h.onPointerPressed) {
            case Some(cb) =>
                let delegate = PointerEventHandler.new({ sender, args =>
                    try { cb.invoke(pointerEventInfo(sender, args)) } catch (_: Exception) { () }
                })
                let token = ui.addPointerPressed(delegate)
                revokers.add(EventRevoker({ =>
                    try { ui.removePointerPressed(token) } catch (_: Exception) { () }
                    delegate.close()
                }))
            case None => ()
        }
        match (h.onPointerReleased) {
            case Some(cb) =>
                let delegate = PointerEventHandler.new({ sender, args =>
                    try { cb.invoke(pointerEventInfo(sender, args)) } catch (_: Exception) { () }
                })
                let token = ui.addPointerReleased(delegate)
                revokers.add(EventRevoker({ =>
                    try { ui.removePointerReleased(token) } catch (_: Exception) { () }
                    delegate.close()
                }))
            case None => ()
        }
        match (h.onPointerExited) {
            case Some(cb) =>
                let delegate = PointerEventHandler.new({ _, _ =>
                    try { cb.invoke(()) } catch (_: Exception) { () }
                })
                let token = ui.addPointerExited(delegate)
                revokers.add(EventRevoker({ =>
                    try { ui.removePointerExited(token) } catch (_: Exception) { () }
                    delegate.close()
                }))
            case None => ()
        }
        // The shared `ui` view is captured by the revoke closures, so it must
        // outlive this call; do not close it here when handlers were wired.
        keptUi = !revokers.isEmpty()
    } finally {
        if (!keptUi) {
            ui.close()
        }
    }
    revokers
}

// ── private helpers ─────────────────────────────────────────────────────────

// QI a handle's identity to the high-level DependencyObject class (the type the
// AutomationProperties / ToolTipService statics accept). Caller owns it.
func handleDependencyObject(h: Handle): DependencyObject {
    DependencyObject.fromAbiTake(
        queryRequired(h.asRaw(), DependencyObject.iid(), "Microsoft.UI.Xaml.IDependencyObject")
    )
}

// QI a handle's identity to the high-level UIElement class (KeyboardAccelerators
// / pointer-event surface). Caller owns it.
func handleUIElementOwned(h: Handle): UIElement {
    UIElement.fromAbiTake(
        queryRequired(h.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")
    )
}

// Apply an automation string property: None → "" (matches the reference
// `as_deref().unwrap_or("")`). The boxed HString is released after the call.
func a11ySetAutomationString(setter: (HString) -> Unit, value: ?String): Unit {
    let text = match (value) {
        case Some(s) => s
        case None => ""
    }
    let hs = HString(text)
    try {
        setter(hs)
    } finally {
        hs.close()
    }
}

// Map the reactor keyboard key to the WinRT VirtualKey, mirroring
// reactor_key_to_virtual_key.
func reactorKeyToVirtualKey(k: KeyboardKey): XamlVirtualKey {
    match (k) {
        case A => Windows_System_VirtualKey_A
        case B => Windows_System_VirtualKey_B
        case C => Windows_System_VirtualKey_C
        case D => Windows_System_VirtualKey_D
        case E => Windows_System_VirtualKey_E
        case F => Windows_System_VirtualKey_F
        case G => Windows_System_VirtualKey_G
        case H => Windows_System_VirtualKey_H
        case I => Windows_System_VirtualKey_I
        case J => Windows_System_VirtualKey_J
        case K => Windows_System_VirtualKey_K
        case L => Windows_System_VirtualKey_L
        case M => Windows_System_VirtualKey_M
        case N => Windows_System_VirtualKey_N
        case O => Windows_System_VirtualKey_O
        case P => Windows_System_VirtualKey_P
        case Q => Windows_System_VirtualKey_Q
        case R => Windows_System_VirtualKey_R
        case S => Windows_System_VirtualKey_S
        case T => Windows_System_VirtualKey_T
        case U => Windows_System_VirtualKey_U
        case V => Windows_System_VirtualKey_V
        case W => Windows_System_VirtualKey_W
        case X => Windows_System_VirtualKey_X
        case Y => Windows_System_VirtualKey_Y
        case Z => Windows_System_VirtualKey_Z
        case Num0 => Windows_System_VirtualKey_Number0
        case Num1 => Windows_System_VirtualKey_Number1
        case Num2 => Windows_System_VirtualKey_Number2
        case Num3 => Windows_System_VirtualKey_Number3
        case Num4 => Windows_System_VirtualKey_Number4
        case Num5 => Windows_System_VirtualKey_Number5
        case Num6 => Windows_System_VirtualKey_Number6
        case Num7 => Windows_System_VirtualKey_Number7
        case Num8 => Windows_System_VirtualKey_Number8
        case Num9 => Windows_System_VirtualKey_Number9
        case NumPad0 => Windows_System_VirtualKey_NumberPad0
        case NumPad1 => Windows_System_VirtualKey_NumberPad1
        case NumPad2 => Windows_System_VirtualKey_NumberPad2
        case NumPad3 => Windows_System_VirtualKey_NumberPad3
        case NumPad4 => Windows_System_VirtualKey_NumberPad4
        case NumPad5 => Windows_System_VirtualKey_NumberPad5
        case NumPad6 => Windows_System_VirtualKey_NumberPad6
        case NumPad7 => Windows_System_VirtualKey_NumberPad7
        case NumPad8 => Windows_System_VirtualKey_NumberPad8
        case NumPad9 => Windows_System_VirtualKey_NumberPad9
        case NumPadAdd => Windows_System_VirtualKey_Add
        case NumPadSubtract => Windows_System_VirtualKey_Subtract
        case NumPadMultiply => Windows_System_VirtualKey_Multiply
        case NumPadDivide => Windows_System_VirtualKey_Divide
        case NumPadDecimal => Windows_System_VirtualKey_Decimal
        case F1 => Windows_System_VirtualKey_F1
        case F2 => Windows_System_VirtualKey_F2
        case F3 => Windows_System_VirtualKey_F3
        case F4 => Windows_System_VirtualKey_F4
        case F5 => Windows_System_VirtualKey_F5
        case F6 => Windows_System_VirtualKey_F6
        case F7 => Windows_System_VirtualKey_F7
        case F8 => Windows_System_VirtualKey_F8
        case F9 => Windows_System_VirtualKey_F9
        case F10 => Windows_System_VirtualKey_F10
        case F11 => Windows_System_VirtualKey_F11
        case F12 => Windows_System_VirtualKey_F12
        case Enter => Windows_System_VirtualKey_Enter
        case Escape => Windows_System_VirtualKey_Escape
        case Tab => Windows_System_VirtualKey_Tab
        case Space => Windows_System_VirtualKey_Space
        case Backspace => Windows_System_VirtualKey_Back
        case Delete => Windows_System_VirtualKey_Delete
        case Insert => Windows_System_VirtualKey_Insert
        case Home => Windows_System_VirtualKey_Home
        case End => Windows_System_VirtualKey_End
        case PageUp => Windows_System_VirtualKey_PageUp
        case PageDown => Windows_System_VirtualKey_PageDown
        case Left => Windows_System_VirtualKey_Left
        case Right => Windows_System_VirtualKey_Right
        case Up => Windows_System_VirtualKey_Up
        case Down => Windows_System_VirtualKey_Down
    }
}

// Map the reactor tooltip placement to the WinRT PlacementMode (mirrors
// map_placement).
func mapPlacement(p: TooltipPlacement): XamlPlacementMode {
    match (p) {
        case Top => Placement_Top
        case Bottom => Placement_Bottom
        case Left => Placement_Left
        case Right => Placement_Right
        case Mouse => Placement_Mouse
    }
}

// Read the pressed-button state for a PointerPressed / PointerReleased callback,
// mirroring pointer_event_info: the sender (the source UIElement) is the
// relativeTo for GetCurrentPoint on the args; the resulting PointerPoint's
// Properties carry the left/right/middle button flags. Any null hop or QI
// failure collapses to the all-false default (matching the reference's
// `unwrap_or(false)` chain). sender / args are borrowed for the Invoke
// duration, so they are wrapped non-owning (viewOf) and not released here.
func pointerEventInfo(sender: CPointer<Unit>, args: CPointer<Unit>): PointerEventInfo {
    if (args.isNull()) {
        return PointerEventInfo()
    }
    try {
        let wrappedArgs = PointerRoutedEventArgs.viewOf(args)
        // relativeTo = the sender UIElement when present, else null (the args
        // accept a null relativeTo, returning a window-relative point).
        let point: PointerPoint = if (sender.isNotNull()) {
            wrappedArgs.GetCurrentPoint(UIElement.viewOf(sender))
        } else {
            wrappedArgs.GetCurrentPoint(UIElement.viewOf(CPointer<Unit>()))
        }
        try {
            let props = point.Properties
            try {
                return PointerEventInfo(
                    props.IsLeftButtonPressed,
                    props.IsRightButtonPressed,
                    props.IsMiddleButtonPressed)
            } finally {
                props.close()
            }
        } finally {
            point.close()
        }
    } catch (_: Exception) {
        return PointerEventInfo()
    }
}

// Best-effort static mount for rich tooltip content. Supports TextBlock,
// (recursively) linear StackPanel and Image; unsupported kinds fall back to a
// TextBlock showing kindName(). Mirrors mount_static_tooltip_element. Returns the
// mounted element as an owned UIElement view (caller closes), or None on failure.
func mountStaticTooltipElement(el: Element): ?UIElement {
    match (el) {
        case TextBlockEl(t) =>
            let tb = TextBlock.new()
            let hs = HString(t.content)
            try {
                tb.Text = hs
            } finally {
                hs.close()
            }
            Some(UIElement.fromAbiTake(
                queryRequired(tb.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")))
        case StackPanelEl(s) =>
            let sp = makeComposable(StackPanel.CreateInstance)
            sp.Orientation = if (s.vertical) {
                Orientation_Vertical
            } else {
                Orientation_Horizontal
            }
            match (s.spacingValue) {
                case Some(sv) => sp.Spacing = sv
                case None => ()
            }
            // StackPanel.Children lives on the Panel surface (a UIElementCollection
            // taking the high-level UIElement); append each recursive child.
            let panel = Panel.fromAbiTake(
                queryRequired(sp.asRaw(), Panel.iid(), "Microsoft.UI.Xaml.Controls.IPanel"))
            try {
                let children = panel.Children
                try {
                    for (child in s.childrenValue) {
                        match (mountStaticTooltipElement(child)) {
                            case Some(cui) =>
                                try {
                                    children.Append(cui)
                                } finally {
                                    cui.close()
                                }
                            case None => ()
                        }
                    }
                } finally {
                    children.close()
                }
            } finally {
                panel.close()
            }
            Some(UIElement.fromAbiTake(
                queryRequired(sp.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")))
        case ImageEl(img) =>
            // Mirrors the reference Image case: create an Image, and when a
            // source URI is present build a BitmapImage (UriSource) QI'd to
            // ImageSource and assign it as Image.Source. An empty source leaves
            // the Source unset (matching `!img.source.is_empty()`).
            let i = Image.new()
            if (img.source.size > 0) {
                i.Source = bitmapImageSourceFromUri(img.source)
            }
            Some(UIElement.fromAbiTake(
                queryRequired(i.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")))
        case _ =>
            // Fallback: surface kindName so the developer sees a hint rather than
            // an empty popup (matches the reference fallback arm).
            let tb = TextBlock.new()
            let hs = HString(el.kindName())
            try {
                tb.Text = hs
            } finally {
                hs.close()
            }
            Some(UIElement.fromAbiTake(
                queryRequired(tb.asRaw(), UIElement.iid(), "Microsoft.UI.Xaml.IUIElement")))
    }
}
