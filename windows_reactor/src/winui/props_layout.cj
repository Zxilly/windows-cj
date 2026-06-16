package windows_reactor.winui

import windows_reactor.core.{
    Prop, PropValue, Brush, GridLength, ScrollBarVisibility,
    ScrollViewScrollBarVisibility, ImageStretch
}
import windows_core.queryInterfaceRaw
import windows_sys.Microsoft.UI.Xaml.Controls.{
    Panel, StackPanel, Grid, Border, Viewbox, ScrollViewer, ScrollView, Control,
    RowDefinition, ColumnDefinition
}
import windows_sys.Microsoft.UI.Xaml.{
    CornerRadius as XamlCornerRadius, GridLength as XamlGridLength,
    Thickness as XamlThickness
}
import windows_sys.Microsoft.UI.Xaml.Media.Brush as XamlBrush
import windows_sys.Microsoft.UI.Xaml.{GridUnitType_Auto as Microsoft_UI_Xaml_GridUnitType_Auto, GridUnitType_Pixel as Microsoft_UI_Xaml_GridUnitType_Pixel, GridUnitType_Star as Microsoft_UI_Xaml_GridUnitType_Star}
import windows_sys.Microsoft.UI.Xaml.Controls.{Orientation_Vertical as Microsoft_UI_Xaml_Controls_Orientation_Vertical, Orientation_Horizontal as Microsoft_UI_Xaml_Controls_Orientation_Horizontal, ScrollBarVisibility as ScrollBarVisAbi, ScrollBarVisibility_Auto as Microsoft_UI_Xaml_Controls_ScrollBarVisibility_Auto, ScrollBarVisibility_Visible as Microsoft_UI_Xaml_Controls_ScrollBarVisibility_Visible, ScrollBarVisibility_Hidden as Microsoft_UI_Xaml_Controls_ScrollBarVisibility_Hidden, ScrollBarVisibility_Disabled as Microsoft_UI_Xaml_Controls_ScrollBarVisibility_Disabled, ScrollingScrollBarVisibility as ScrollingScrollBarVisAbi, ScrollingScrollBarVisibility_Auto as Microsoft_UI_Xaml_Controls_ScrollingScrollBarVisibility_Auto, ScrollingScrollBarVisibility_Visible as Microsoft_UI_Xaml_Controls_ScrollingScrollBarVisibility_Visible, ScrollingScrollBarVisibility_Hidden as Microsoft_UI_Xaml_Controls_ScrollingScrollBarVisibility_Hidden}
import windows_sys.Microsoft.UI.Xaml.Media.{Stretch as StretchAbi, Stretch_None as Microsoft_UI_Xaml_Media_Stretch_None, Stretch_Fill as Microsoft_UI_Xaml_Media_Stretch_Fill, Stretch_Uniform as Microsoft_UI_Xaml_Media_Stretch_Uniform, Stretch_UniformToFill as Microsoft_UI_Xaml_Media_Stretch_UniformToFill}

// ============================================================================
// Per-family property setters for layout containers: StackPanel, Grid, Canvas,
// RelativePanel, Border, Viewbox, ScrollViewer, ScrollView. Returns true when
// the prop was consumed by this family.
//
// Ported faithfully from the reference set_prop dispatch (the Handle::StackPanel
// / Grid / Canvas / RelativePanel / Border / Viewbox / ScrollViewer / ScrollView
// arms). Generic FrameworkElement/UIElement props (Width/Height/Margin/Align/
// Opacity), font props, attached props and Resources are handled by the shared
// backend layers BEFORE this function and are not duplicated here.
//
// Property ABI (spec §8.1, verified against windows_sys):
//   - StackPanel.Orientation / .Spacing, Grid.RowSpacing / .ColumnSpacing,
//     Border.{Padding,Background,CornerRadius,BorderBrush,BorderThickness,Child},
//     Grid.RowDefinitions / .ColumnDefinitions (collections),
//     ScrollViewer.{Horizontal,Vertical}ScrollBarVisibility,
//     ScrollView.{Horizontal,Vertical}ScrollBarVisibility
//       are all high-level `mut prop` setters on the variant-bound class.
//   - Viewbox.Stretch is a SetStretch(value) method (no mut prop).
//   - Panel.Background (StackPanel/Grid/Canvas/RelativePanel) is QI'd to the
//     shared Panel projection (setPanelBackgroundRaw / clearPanelBackgroundRaw).
//   - Control.Padding fallback (for Control-derived layout containers such as
//     ScrollViewer / ScrollView) mirrors the reference generic (Padding, _, _)
//     arm: QI to Control on success, no-op otherwise.
// ============================================================================
func applyLayoutProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        case Orientation => match ((handle, value)) {
            case (StackPanelH(sp), Vertical(vert)) =>
                sp.Orientation = if (vert) {
                    Microsoft_UI_Xaml_Controls_Orientation_Vertical
                } else {
                    Microsoft_UI_Xaml_Controls_Orientation_Horizontal
                }
                true
            case _ => false
        }
        case Spacing => match ((handle, value)) {
            case (StackPanelH(sp), F64(v)) =>
                sp.Spacing = v
                true
            case (StackPanelH(sp), Unset) =>
                sp.Spacing = 0.0
                true
            case _ => false
        }
        case Background => match ((handle, value)) {
            // Panel-derived containers route Background through the shared Panel
            // projection (Panel.Background, an IBrush surface).
            case (StackPanelH(_), BrushV(b)) =>
                setPanelBackgroundRaw(handle.asRaw(), b)
                true
            case (GridH(_), BrushV(b)) =>
                setPanelBackgroundRaw(handle.asRaw(), b)
                true
            case (CanvasH(_), BrushV(b)) =>
                setPanelBackgroundRaw(handle.asRaw(), b)
                true
            case (RelativePanelH(_), BrushV(b)) =>
                setPanelBackgroundRaw(handle.asRaw(), b)
                true
            case (StackPanelH(_), Unset) =>
                clearPanelBackgroundRaw(handle.asRaw())
                true
            case (GridH(_), Unset) =>
                clearPanelBackgroundRaw(handle.asRaw())
                true
            case (CanvasH(_), Unset) =>
                clearPanelBackgroundRaw(handle.asRaw())
                true
            case (RelativePanelH(_), Unset) =>
                clearPanelBackgroundRaw(handle.asRaw())
                true
            // Border carries Background directly on its high-level projection.
            case (BorderH(b), BrushV(br)) =>
                b.Background = solidBrush(br)
                true
            case (BorderH(b), Unset) =>
                b.Background = nullLayoutBrush()
                true
            case _ => false
        }
        case Padding => match ((handle, value)) {
            case (BorderH(b), ThicknessV(t)) =>
                b.Padding = toXamlThickness(t)
                true
            case (BorderH(b), Unset) =>
                b.Padding = XamlThickness()
                true
            // Generic Control fallback (reference's (Padding, _, _) arm): applies
            // to Control-derived layout containers (ScrollViewer / ScrollView).
            // Non-Control panels QI-fail and fall through to a no-op.
            case (_, ThicknessV(t)) =>
                setControlPaddingRaw(handle.asRaw(), toXamlThickness(t))
                true
            case (_, Unset) =>
                setControlPaddingRaw(handle.asRaw(), XamlThickness())
                true
            case _ => false
        }
        case CornerRadius => match ((handle, value)) {
            case (BorderH(b), F64(v)) =>
                b.CornerRadius = uniformCornerRadius(v)
                true
            case (BorderH(b), Unset) =>
                b.CornerRadius = XamlCornerRadius()
                true
            case _ => false
        }
        case BorderBrush => match ((handle, value)) {
            case (BorderH(b), BrushV(br)) =>
                b.BorderBrush = solidBrush(br)
                true
            case (BorderH(b), Unset) =>
                b.BorderBrush = nullLayoutBrush()
                true
            case _ => false
        }
        case BorderThickness => match ((handle, value)) {
            case (BorderH(b), ThicknessV(t)) =>
                b.BorderThickness = toXamlThickness(t)
                true
            case (BorderH(b), Unset) =>
                b.BorderThickness = XamlThickness()
                true
            case _ => false
        }
        case GridRows => match ((handle, value)) {
            case (GridH(g), GridLengths(rows)) =>
                let defs = g.RowDefinitions
                try {
                    defs.Clear()
                    for (r in rows) {
                        let rd = RowDefinition.new()
                        rd.Height = toXamlGridLength(r)
                        defs.Append(rd)
                    }
                } finally {
                    defs.close()
                }
                true
            case _ => false
        }
        case GridColumns => match ((handle, value)) {
            case (GridH(g), GridLengths(cols)) =>
                let defs = g.ColumnDefinitions
                try {
                    defs.Clear()
                    for (c in cols) {
                        let cd = ColumnDefinition.new()
                        cd.Width = toXamlGridLength(c)
                        defs.Append(cd)
                    }
                } finally {
                    defs.close()
                }
                true
            case _ => false
        }
        case GridRowSpacing => match ((handle, value)) {
            case (GridH(g), F64(v)) =>
                g.RowSpacing = v
                true
            case (GridH(g), Unset) =>
                g.RowSpacing = 0.0
                true
            case _ => false
        }
        case GridColumnSpacing => match ((handle, value)) {
            case (GridH(g), F64(v)) =>
                g.ColumnSpacing = v
                true
            case (GridH(g), Unset) =>
                g.ColumnSpacing = 0.0
                true
            case _ => false
        }
        case HorizontalScrollBarVisibility => match ((handle, value)) {
            case (ScrollViewerH(s), ScrollVis(v)) =>
                s.HorizontalScrollBarVisibility = toXamlScrollVisibility(v)
                true
            case (ScrollViewH(sv), ScrollViewScrollBarVisV(v)) =>
                sv.HorizontalScrollBarVisibility = toXamlScrollingScrollVisibility(v)
                true
            case _ => false
        }
        case VerticalScrollBarVisibility => match ((handle, value)) {
            case (ScrollViewerH(s), ScrollVis(v)) =>
                s.VerticalScrollBarVisibility = toXamlScrollVisibility(v)
                true
            case (ScrollViewH(sv), ScrollViewScrollBarVisV(v)) =>
                sv.VerticalScrollBarVisibility = toXamlScrollingScrollVisibility(v)
                true
            case _ => false
        }
        case ImageStretch => match ((handle, value)) {
            case (ViewboxH(vb), ImageStretchV(s)) =>
                vb.SetStretch(toXamlStretch(s))
                true
            case _ => false
        }
        case _ => false
    }
}

// ── private helpers ─────────────────────────────────────────────────────────

// Set a Panel's Background via the high-level Panel projection (QI'd from the
// control's default interface). Generalised to any panel raw pointer.
func setPanelBackgroundRaw(raw: CPointer<Unit>, b: Brush): Unit {
    let panel = Panel.fromAbiTake(
        queryRequired(raw, Panel.iid(), "Microsoft.UI.Xaml.Controls.IPanel")
    )
    try {
        panel.Background = solidBrush(b)
    } finally {
        panel.close()
    }
}

// Clear a Panel's Background (set to null) — mirrors the reference Unset arm
// `put_Background(None)`.
func clearPanelBackgroundRaw(raw: CPointer<Unit>): Unit {
    let panel = Panel.fromAbiTake(
        queryRequired(raw, Panel.iid(), "Microsoft.UI.Xaml.Controls.IPanel")
    )
    try {
        panel.Background = nullLayoutBrush()
    } finally {
        panel.close()
    }
}

// Set Control.Padding on a Control-derived control, no-op when the handle does
// not expose the IControl surface (mirrors the reference cast-on-success arm).
func setControlPaddingRaw(raw: CPointer<Unit>, t: XamlThickness): Unit {
    match (unsafe { queryInterfaceRaw(raw, Control.iid()) }) {
        case Some(ctrlRaw) =>
            let ctrl = Control.fromAbiTake(ctrlRaw)
            try {
                ctrl.Padding = t
            } finally {
                ctrl.close()
            }
        case None => ()
    }
}

// A null Brush view (non-owning) used to clear brush-typed properties — the
// projection setter borrows a null pointer, matching `put_X(None)`. Locally
// named to avoid colliding with sibling family files that define their own.
func nullLayoutBrush(): XamlBrush {
    XamlBrush.viewOf(CPointer<Unit>())
}

// Build a uniform XAML CornerRadius (all four corners equal) from a scalar.
func uniformCornerRadius(v: Float64): XamlCornerRadius {
    var cr = XamlCornerRadius()
    cr.TopLeft = v
    cr.TopRight = v
    cr.BottomRight = v
    cr.BottomLeft = v
    cr
}

// Convert a reactor GridLength to the XAML GridLength ABI struct
// (Value + GridUnitType code). Mirrors the reference to_xaml_gridlength.
func toXamlGridLength(g: GridLength): XamlGridLength {
    var x = XamlGridLength()
    match (g) {
        case Auto =>
            x.Value = 0.0
            x.GridUnitType = Microsoft_UI_Xaml_GridUnitType_Auto.value
        case Pixel(v) =>
            x.Value = v
            x.GridUnitType = Microsoft_UI_Xaml_GridUnitType_Pixel.value
        case Star(v) =>
            x.Value = v
            x.GridUnitType = Microsoft_UI_Xaml_GridUnitType_Star.value
    }
    x
}

// Convert a reactor ScrollBarVisibility (ScrollViewer) to the XAML
// ScrollBarVisibility wrapper. Mirrors to_xaml_scroll_visibility.
func toXamlScrollVisibility(v: ScrollBarVisibility): ScrollBarVisAbi {
    match (v) {
        case Auto => Microsoft_UI_Xaml_Controls_ScrollBarVisibility_Auto
        case Visible => Microsoft_UI_Xaml_Controls_ScrollBarVisibility_Visible
        case Hidden => Microsoft_UI_Xaml_Controls_ScrollBarVisibility_Hidden
        case Disabled => Microsoft_UI_Xaml_Controls_ScrollBarVisibility_Disabled
    }
}

// Convert a reactor ScrollViewScrollBarVisibility (ScrollView) to the XAML
// ScrollingScrollBarVisibility wrapper (W19 arm).
func toXamlScrollingScrollVisibility(v: ScrollViewScrollBarVisibility): ScrollingScrollBarVisAbi {
    match (v) {
        case Auto => Microsoft_UI_Xaml_Controls_ScrollingScrollBarVisibility_Auto
        case Visible => Microsoft_UI_Xaml_Controls_ScrollingScrollBarVisibility_Visible
        case Hidden => Microsoft_UI_Xaml_Controls_ScrollingScrollBarVisibility_Hidden
    }
}

// Convert a reactor ImageStretch to the XAML Stretch wrapper (used by Viewbox
// and Image; the layout family covers the Viewbox arm).
func toXamlStretch(s: ImageStretch): StretchAbi {
    match (s) {
        case Uniform => Microsoft_UI_Xaml_Media_Stretch_Uniform
        case UniformToFill => Microsoft_UI_Xaml_Media_Stretch_UniformToFill
        case Fill => Microsoft_UI_Xaml_Media_Stretch_Fill
        case NoneStretch => Microsoft_UI_Xaml_Media_Stretch_None
    }
}
