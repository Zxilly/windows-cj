package windows_reactor.winui

import windows_reactor.core.{Prop, PropValue, ImageStretch, InfoBarSeverity, TeachingTipPlacement}
import std.collection.{ArrayList}
import windows_core.{HString}
import windows_interface.{IInspectable}
import windows_reference.{hStringReference, IReference}
import windows_collections.{toInspectableVector}
import windows_sys.Foundation.{Uri}
import windows_sys.Microsoft.UI.Xaml.Controls.{
    ContentControl, Control, TextBlock
}
import windows_sys.Microsoft.UI.Xaml.Media.{ImageSource}
import windows_sys.Microsoft.UI.Xaml.Media.Imaging.{BitmapImage}
import windows_sys.impl.Microsoft_UI_Xaml_Controls.{Microsoft_UI_Xaml_Controls_InfoBarSeverity_Informational, Microsoft_UI_Xaml_Controls_InfoBarSeverity_Success, Microsoft_UI_Xaml_Controls_InfoBarSeverity_Warning, Microsoft_UI_Xaml_Controls_InfoBarSeverity_Error, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Auto, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Top, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Bottom, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Left, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Right, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_TopRight, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_TopLeft, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_BottomRight, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_BottomLeft, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_LeftTop, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_LeftBottom, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_RightTop, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_RightBottom, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Center, Microsoft_UI_Xaml_Controls_SplitViewDisplayMode, Microsoft_UI_Xaml_Controls_InfoBarSeverity, Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode}
import windows_sys.impl.Microsoft_UI_Xaml_Media.{Microsoft_UI_Xaml_Media_Stretch_None, Microsoft_UI_Xaml_Media_Stretch_Fill, Microsoft_UI_Xaml_Media_Stretch_Uniform, Microsoft_UI_Xaml_Media_Stretch_UniformToFill, Microsoft_UI_Xaml_Media_Stretch}

// Per-family property setters for dialogs / surfaces / misc content controls
// (ContentDialog, InfoBar, InfoBadge, TeachingTip, Expander, PersonPicture,
// Image, SplitView, AutoSuggestBox, TitleBar). Returns true when the prop was
// consumed.
//
// All props use the high-level projection-class property accessors directly on
// the variant-bound class, except:
//   - ContentDialogBody / Expander.Header  → live on IContentControl (QI to
//     the ContentControl high-level class, set its Content).
//   - AutoSuggestBox.IsEnabled            → lives on IControl (QI to Control).
//   - Image.Source                        → built from a Uri via BitmapImage,
//     then QI'd to the ImageSource class the Source setter expects.
//   - ContentDialog.Title / TeachingTip.*ButtonContent / AutoSuggestBox.Header
//     are IInspectable-typed: box the string through IReference<HString>.
//
// TitleBarTall is handled here too, but is host-level state rather than a
// control property: it routes through applyTitlebarHeight (the registered active
// window's AppWindow PreferredHeightOption), mirroring the reference backend
// Prop::TitleBarTall → host::set_titlebar_height.
//
// AutoSuggestItems builds a managed IVector<IInspectable> of boxed HStrings
// (the stock collection-building shared with the list/nav families) and assigns
// it as the AutoSuggestBox's ItemsSource via IItemsControl, mirroring
// setNavAutoSuggestItems in props_nav.cj.
//
// DEFERRED to backend-state handling (see report): ContentDialogIsOpen
// (ShowAsync/Hide + XamlRoot discovery + open-state tracking).
func applyDialogProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        // ── ContentDialog ────────────────────────────────────────────────
        case ContentDialogTitle => match ((handle, value)) {
            case (ContentDialogH(d), Str(s)) =>
                let box = hStringReference(s)
                try {
                    d.Title = box.asIInspectable()
                } finally {
                    box.close()
                }
                true
            case (ContentDialogH(d), Unset) =>
                d.Title = IInspectable.viewOf(CPointer<Unit>())
                true
            case _ => false
        }
        case ContentDialogBody => match ((handle, value)) {
            case (ContentDialogH(d), Str(s)) =>
                setContentControlText(d.asRaw(), s)
                true
            case (ContentDialogH(d), Unset) =>
                clearContentControlContentRaw(d.asRaw())
                true
            case _ => false
        }
        case ContentDialogPrimaryText => match ((handle, value)) {
            case (ContentDialogH(d), Str(s)) =>
                setHStringProp({ h => d.PrimaryButtonText = h }, s)
                true
            case (ContentDialogH(d), Unset) =>
                setHStringProp({ h => d.PrimaryButtonText = h }, "")
                true
            case _ => false
        }
        case ContentDialogSecondaryText => match ((handle, value)) {
            case (ContentDialogH(d), Str(s)) =>
                setHStringProp({ h => d.SecondaryButtonText = h }, s)
                true
            case (ContentDialogH(d), Unset) =>
                setHStringProp({ h => d.SecondaryButtonText = h }, "")
                true
            case _ => false
        }
        case ContentDialogCloseText => match ((handle, value)) {
            case (ContentDialogH(d), Str(s)) =>
                setHStringProp({ h => d.CloseButtonText = h }, s)
                true
            case (ContentDialogH(d), Unset) =>
                setHStringProp({ h => d.CloseButtonText = h }, "")
                true
            case _ => false
        }
        case ContentDialogPrimaryEnabled => match ((handle, value)) {
            case (ContentDialogH(d), BoolV(v)) =>
                d.IsPrimaryButtonEnabled = v
                true
            case _ => false
        }
        case ContentDialogSecondaryEnabled => match ((handle, value)) {
            case (ContentDialogH(d), BoolV(v)) =>
                d.IsSecondaryButtonEnabled = v
                true
            case _ => false
        }
        // ── InfoBar ──────────────────────────────────────────────────────
        case InfoBarTitle => match ((handle, value)) {
            case (InfoBarH(ib), Str(s)) =>
                setHStringProp({ h => ib.Title = h }, s)
                true
            case (InfoBarH(ib), Unset) =>
                setHStringProp({ h => ib.Title = h }, "")
                true
            case _ => false
        }
        case InfoBarMessage => match ((handle, value)) {
            case (InfoBarH(ib), Str(s)) =>
                setHStringProp({ h => ib.Message = h }, s)
                true
            case (InfoBarH(ib), Unset) =>
                setHStringProp({ h => ib.Message = h }, "")
                true
            case _ => false
        }
        case InfoBarSeverity => match ((handle, value)) {
            case (InfoBarH(ib), InfoBarSev(v)) =>
                ib.Severity = toWinuiInfoBarSeverity(v)
                true
            case _ => false
        }
        case InfoBarIsOpen => match ((handle, value)) {
            case (InfoBarH(ib), BoolV(v)) =>
                ib.IsOpen = v
                true
            case _ => false
        }
        case IsClosable => match ((handle, value)) {
            case (InfoBarH(ib), BoolV(v)) =>
                ib.IsClosable = v
                true
            case _ => false
        }
        // ── InfoBadge ────────────────────────────────────────────────────
        case InfoBadgeValue => match ((handle, value)) {
            case (InfoBadgeH(ib), I32(v)) =>
                ib.Value = if (v < 0) { -1i32 } else { v }
                true
            case _ => false
        }
        // ── PersonPicture ────────────────────────────────────────────────
        case PersonDisplayName => match ((handle, value)) {
            case (PersonPictureH(p), Str(s)) =>
                setHStringProp({ h => p.DisplayName = h }, s)
                true
            case (PersonPictureH(p), Unset) =>
                setHStringProp({ h => p.DisplayName = h }, "")
                true
            case _ => false
        }
        case PersonInitials => match ((handle, value)) {
            case (PersonPictureH(p), Str(s)) =>
                setHStringProp({ h => p.Initials = h }, s)
                true
            case (PersonPictureH(p), Unset) =>
                setHStringProp({ h => p.Initials = h }, "")
                true
            case _ => false
        }
        // ── Expander ─────────────────────────────────────────────────────
        case Header => match ((handle, value)) {
            case (ExpanderH(e), Str(s)) =>
                let label = TextBlock.new()
                try {
                    label.Text = HString(s)
                    // The setter AddRefs the TextBlock; keep it alive across
                    // the assignment, then drop our reference.
                    e.Header = label.asIInspectable()
                } finally {
                    label.close()
                }
                true
            case (ExpanderH(e), Unset) =>
                e.Header = IInspectable.viewOf(CPointer<Unit>())
                true
            case (AutoSuggestBoxH(asb), Str(s)) =>
                let box = hStringReference(s)
                try {
                    asb.Header = box.asIInspectable()
                } finally {
                    box.close()
                }
                true
            case _ => false
        }
        case IsExpanded => match ((handle, value)) {
            case (ExpanderH(e), BoolV(v)) =>
                e.IsExpanded = v
                true
            case _ => false
        }
        // ── Image ────────────────────────────────────────────────────────
        case ImageSource => match ((handle, value)) {
            case (ImageH(img), Str(s)) =>
                img.Source = bitmapImageSourceFromUri(s)
                true
            case (ImageH(img), Unset) =>
                img.Source = ImageSource.viewOf(CPointer<Unit>())
                true
            case _ => false
        }
        case ImageStretch => match ((handle, value)) {
            case (ImageH(img), ImageStretchV(s)) =>
                img.Stretch = toWinuiStretch(s)
                true
            case _ => false
        }
        // ── SplitView ────────────────────────────────────────────────────
        case SplitViewDisplayMode => match ((handle, value)) {
            case (SplitViewH(sv), I32(m)) =>
                sv.DisplayMode = Microsoft_UI_Xaml_Controls_SplitViewDisplayMode(m)
                true
            case _ => false
        }
        case SplitViewIsPaneOpen => match ((handle, value)) {
            case (SplitViewH(sv), BoolV(v)) =>
                sv.IsPaneOpen = v
                true
            case _ => false
        }
        case SplitViewOpenPaneLength => match ((handle, value)) {
            case (SplitViewH(sv), F64(v)) =>
                sv.OpenPaneLength = v
                true
            case _ => false
        }
        case SplitViewCompactPaneLength => match ((handle, value)) {
            case (SplitViewH(sv), F64(v)) =>
                sv.CompactPaneLength = v
                true
            case _ => false
        }
        // ── TeachingTip ──────────────────────────────────────────────────
        case TeachingTipTitle => match ((handle, value)) {
            case (TeachingTipH(tt), Str(s)) =>
                setHStringProp({ h => tt.Title = h }, s)
                true
            case _ => false
        }
        case TeachingTipSubtitle => match ((handle, value)) {
            case (TeachingTipH(tt), Str(s)) =>
                setHStringProp({ h => tt.Subtitle = h }, s)
                true
            case _ => false
        }
        case TeachingTipIsOpen => match ((handle, value)) {
            case (TeachingTipH(tt), BoolV(v)) =>
                tt.IsOpen = v
                true
            case _ => false
        }
        case TeachingTipIsLightDismiss => match ((handle, value)) {
            case (TeachingTipH(tt), BoolV(v)) =>
                tt.IsLightDismissEnabled = v
                true
            case _ => false
        }
        case TeachingTipPlacement => match ((handle, value)) {
            case (TeachingTipH(tt), TeachingTipPlacementV(p)) =>
                tt.PreferredPlacement = toWinuiTeachingTipPlacement(p)
                true
            case _ => false
        }
        case TeachingTipActionButton => match ((handle, value)) {
            case (TeachingTipH(tt), Str(s)) =>
                let box = hStringReference(s)
                try {
                    tt.ActionButtonContent = box.asIInspectable()
                } finally {
                    box.close()
                }
                true
            case _ => false
        }
        case TeachingTipCloseButton => match ((handle, value)) {
            case (TeachingTipH(tt), Str(s)) =>
                let box = hStringReference(s)
                try {
                    tt.CloseButtonContent = box.asIInspectable()
                } finally {
                    box.close()
                }
                true
            case _ => false
        }
        // ── AutoSuggestBox ───────────────────────────────────────────────
        case AutoSuggestText => match ((handle, value)) {
            case (AutoSuggestBoxH(asb), Str(s)) =>
                // Skip SetText when the control already holds this value —
                // re-setting during a user TextChanged cycle steals focus.
                let current = asb.Text
                let same = current.toString() == s
                current.close()
                if (!same) {
                    setHStringProp({ h => asb.Text = h }, s)
                }
                true
            case _ => false
        }
        case AutoSuggestItems => match ((handle, value)) {
            case (AutoSuggestBoxH(asb), StrList(items)) =>
                // Each string is boxed into an IReference<HString>, gathered into
                // a managed IVector<IInspectable>, and assigned as ItemsSource via
                // IItemsControl. Boxes/vec are GC objects but hold native COM refs,
                // so release them (close) once the setter has AddRef'd what it keeps.
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
                true
            case _ => false
        }
        case Placeholder => match ((handle, value)) {
            case (AutoSuggestBoxH(asb), Str(s)) =>
                setHStringProp({ h => asb.PlaceholderText = h }, s)
                true
            case (AutoSuggestBoxH(asb), Unset) =>
                setHStringProp({ h => asb.PlaceholderText = h }, "")
                true
            case _ => false
        }
        case IsEnabled => match ((handle, value)) {
            case (AutoSuggestBoxH(asb), BoolV(v)) =>
                setControlIsEnabled(asb.asRaw(), v)
                true
            case _ => false
        }
        // ── TitleBar ─────────────────────────────────────────────────────
        case TitleBarTitle => match ((handle, value)) {
            case (TitleBarH(tb), Str(s)) =>
                setHStringProp({ h => tb.Title = h }, s)
                true
            case _ => false
        }
        case TitleBarSubtitle => match ((handle, value)) {
            case (TitleBarH(tb), Str(s)) =>
                setHStringProp({ h => tb.Subtitle = h }, s)
                true
            case (TitleBarH(tb), Unset) =>
                setHStringProp({ h => tb.Subtitle = h }, "")
                true
            case _ => false
        }
        case IsBackButtonVisible => match ((handle, value)) {
            case (TitleBarH(tb), BoolV(v)) =>
                tb.IsBackButtonVisible = v
                true
            case _ => false
        }
        case IsBackEnabled => match ((handle, value)) {
            case (TitleBarH(tb), BoolV(v)) =>
                tb.IsBackButtonEnabled = v
                true
            case _ => false
        }
        case IsPaneToggleButtonVisible => match ((handle, value)) {
            case (TitleBarH(tb), BoolV(v)) =>
                tb.IsPaneToggleButtonVisible = v
                true
            case _ => false
        }
        // TitleBarTall is host-level state, not a TitleBar control property: it
        // selects the window AppWindow's PreferredHeightOption (Tall/Standard)
        // via the registered active window, mirroring the reference backend
        // Prop::TitleBarTall arm → host::set_titlebar_height. The TitleBarH
        // handle gates the arm (the prop only ever rides on a TitleBar widget),
        // but the effect targets the window, not the control.
        case TitleBarTall => match ((handle, value)) {
            case (TitleBarH(_), BoolV(v)) =>
                applyTitlebarHeight(v)
                true
            case _ => false
        }
        case _ => false
    }
}

// ── private helpers ───────────────────────────────────────────────────────

// Assign an HString-typed projection prop, owning the HString lifetime around
// the setter call (the setter borrows the HSTRING via winrtBorrow internally).
func setHStringProp(set: (HString) -> Unit, text: String): Unit {
    let hs = HString(text)
    try {
        set(hs)
    } finally {
        hs.close()
    }
}

// Clear an IContentControl's Content to null via the high-level ContentControl.
func clearContentControlContentRaw(raw: CPointer<Unit>): Unit {
    let cc = ContentControl.fromAbiTake(
        queryRequired(raw, ContentControl.iid(), "Microsoft.UI.Xaml.Controls.IContentControl")
    )
    try {
        cc.Content = IInspectable.viewOf(CPointer<Unit>())
    } finally {
        cc.close()
    }
}

// Set a Control's IsEnabled via the high-level Control class (QI'd from the
// control's default interface). Mirrors the Rust `cast::<IControl>().put_IsEnabled`.
func setControlIsEnabled(raw: CPointer<Unit>, enabled: Bool): Unit {
    let ctrl = Control.fromAbiTake(
        queryRequired(raw, Control.iid(), "Microsoft.UI.Xaml.Controls.IControl")
    )
    try {
        ctrl.IsEnabled = enabled
    } finally {
        ctrl.close()
    }
}

// Build an ImageSource from a URI string: Uri -> BitmapImage(UriSource) -> QI to
// the ImageSource class the Image.Source setter expects.
func bitmapImageSourceFromUri(uriStr: String): ImageSource {
    let hs = HString(uriStr)
    let uri = Uri.CreateUri(hs)
    hs.close()
    try {
        let bmp = BitmapImage.new()
        try {
            bmp.UriSource = uri
            return ImageSource.fromAbiTake(
                queryRequired(bmp.asRaw(), ImageSource.iid(), "Microsoft.UI.Xaml.Media.IImageSource")
            )
        } finally {
            bmp.close()
        }
    } finally {
        uri.close()
    }
}

func toWinuiInfoBarSeverity(v: InfoBarSeverity): Microsoft_UI_Xaml_Controls_InfoBarSeverity {
    match (v) {
        case Informational => Microsoft_UI_Xaml_Controls_InfoBarSeverity_Informational
        case Success => Microsoft_UI_Xaml_Controls_InfoBarSeverity_Success
        case Warning => Microsoft_UI_Xaml_Controls_InfoBarSeverity_Warning
        case Error => Microsoft_UI_Xaml_Controls_InfoBarSeverity_Error
    }
}

func toWinuiStretch(v: ImageStretch): Microsoft_UI_Xaml_Media_Stretch {
    match (v) {
        case NoneStretch => Microsoft_UI_Xaml_Media_Stretch_None
        case Fill => Microsoft_UI_Xaml_Media_Stretch_Fill
        case Uniform => Microsoft_UI_Xaml_Media_Stretch_Uniform
        case UniformToFill => Microsoft_UI_Xaml_Media_Stretch_UniformToFill
    }
}

func toWinuiTeachingTipPlacement(p: TeachingTipPlacement): Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode {
    match (p) {
        case Auto => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Auto
        case Top => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Top
        case Bottom => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Bottom
        case Left => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Left
        case Right => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Right
        case TopRight => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_TopRight
        case TopLeft => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_TopLeft
        case BottomRight => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_BottomRight
        case BottomLeft => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_BottomLeft
        case LeftTop => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_LeftTop
        case LeftBottom => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_LeftBottom
        case RightTop => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_RightTop
        case RightBottom => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_RightBottom
        case Center => Microsoft_UI_Xaml_Controls_TeachingTipPlacementMode_Center
    }
}
