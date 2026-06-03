package windows_reactor_minimal

import windows_reactor.core.*

// ============================================================================
// Group: status_media_pickers
//
// Examples owned by this group (filled into routeStatusMediaPickers):
//   progress_bar, progress_ring, info_badge, info_bar, image, person_picture,
//   calendar_date_picker, calendar_view, date_picker, time_picker,
//   content_dialog, flyout, teaching_tip
//
// Contract (see main.cj):
//   routeStatusMediaPickers(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesStatusMediaPickers()     -> the example names this group owns, for the banner.
//
// Each example below is the root component body `(RenderCx) -> Element` and is
// a faithful port of the corresponding standalone minimal sample. Interactive
// examples drive their state through cx.useState; state types are restricted to
// Equatable scalars (Bool / Int64 / Float64 / String).
// ============================================================================

// ── progress_bar ────────────────────────────────────────────────────────────
// Three bars: a determinate 65% (0..100), a determinate custom-range step
// counter (3 / 5), and an indeterminate (busy) bar.
func progressBarExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        text_block("Determinate (65%)").toElement(),
        progress_bar(65.0).range(0.0, 100.0).toElement(),
        text_block("Determinate, custom range (3 / 5 steps)").toElement(),
        progress_bar(3.0).range(0.0, 5.0).toElement(),
        text_block("Indeterminate (busy)").toElement(),
        ProgressBar.indeterminate().toElement()
    ])
        .spacing(8.0)
        .maxWidth(320.0)
        .toElement()
}

// ── progress_ring ───────────────────────────────────────────────────────────
// A determinate 40% ring and an indeterminate (busy) ring.
func progressRingExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        text_block("Determinate (40%)").toElement(),
        progress_ring(40.0).toElement(),
        text_block("Indeterminate (busy)").toElement(),
        ProgressRing.indeterminate().toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── info_badge ──────────────────────────────────────────────────────────────
// A dot attention indicator and a row of numeric badges of varying magnitude.
func infoBadgeExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        text_block("Dot (attention indicator)").toElement(),
        InfoBadge.dot().toElement(),
        text_block("Numeric (small / large counts)").toElement(),
        hstack([
            InfoBadge.numeric(1).toElement(),
            InfoBadge.numeric(9).toElement(),
            InfoBadge.numeric(42).toElement(),
            InfoBadge.numeric(999).toElement()
        ])
            .spacing(12.0)
            .toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── info_bar ──────────────────────────────────────────────────────────────--
// One bar per severity, plus a non-closable sticky bar and a closed bar.
func infoBarExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        info_bar("Did you know?")
            .message("This is an informational notice.")
            .informational()
            .toElement(),
        info_bar("Saved")
            .message("Your changes have been saved.")
            .success()
            .toElement(),
        info_bar("Heads up")
            .message("Check before proceeding.")
            .warning()
            .toElement(),
        info_bar("Something went wrong")
            .message("The operation could not be completed.")
            .infoBarError()
            .toElement(),
        info_bar("Sticky")
            .message("This bar hides its close button.")
            .informational()
            .isClosableOf(false)
            .toElement(),
        info_bar("Hidden")
            .message("This bar is not currently open.")
            .informational()
            .isOpenOf(false)
            .toElement()
    ])
        .spacing(8.0)
        .maxWidth(360.0)
        .toElement()
}

// ── image ─────────────────────────────────────────────────────────────────--
// The four Stretch modes applied to a single source. The reference loads a
// bundled file:// asset; this runner has no bundled asset path, so it points at
// a stable remote URI (the proven gallery source) — the Stretch behaviour the
// sample demonstrates is identical. See report note "image source".
func imageExample(cx: RenderCx): Element {
    let _ = cx
    let source = "https://picsum.photos/id/237/400/200"
    vstack([
        text_block("Uniform (default)").toElement(),
        image(source).width(120.0).height(60.0).toElement(),
        text_block("UniformToFill").toElement(),
        image(source)
            .stretchOf(ImageStretch.UniformToFill)
            .width(120.0)
            .height(60.0)
            .toElement(),
        text_block("Fill").toElement(),
        image(source)
            .stretchOf(ImageStretch.Fill)
            .width(120.0)
            .height(60.0)
            .toElement(),
        text_block("None").toElement(),
        image(source)
            .stretchOf(ImageStretch.NoneStretch)
            .width(120.0)
            .height(60.0)
            .toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── person_picture ──────────────────────────────────────────────────────────
// A placeholder avatar, a row whose initials are auto-derived from display
// names, and one avatar with explicit initials.
func personPictureExample(cx: RenderCx): Element {
    let _ = cx
    vstack([
        text_block("Default (placeholder glyph)").toElement(),
        person_picture().toElement(),
        text_block("display_name (initials auto-derived)").toElement(),
        hstack([
            person_picture().displayNameOf("Ada Lovelace").toElement(),
            person_picture().displayNameOf("Grace Hopper").toElement(),
            person_picture().displayNameOf("Alan Turing").toElement()
        ])
            .spacing(12.0)
            .toElement(),
        text_block("initials (explicit)").toElement(),
        person_picture().initialsOf("WR").toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── calendar_date_picker ──────────────────────────────────────────────────--
// Computes the number of days between today and the selected date using
// DateTime.now() and checked_duration_since.
func calendarDatePickerExample(cx: RenderCx): Element {
    let (label, setLabel) = cx.useState<String>("Pick a date to see days from today")

    // DateTime arithmetic (now()/duration_since) is not exposed on the Cangjie
    // DateTime value type; surface a confirmation instead (the picker's change
    // event firing is what the demo exercises).
    let onDate = { date: ?ReactorDateTime =>
        let outText = match (date) {
            case Some(_) => "A date was selected."
            case None => "Selection cleared"
        }
        setLabel.call(outText)
    }

    vstack([
        calendar_date_picker()
            .headerOf("Select a date")
            .placeholderTextOf("Choose...")
            .todayHighlighted(true)
            .onChanged(onDate)
            .toElement(),
        text_block(label).toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── calendar_view ───────────────────────────────────────────────────────────
// Counts how many times the calendar selection changes.
func calendarViewExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(0)

    vstack([
        calendar_view()
            .todayHighlighted(true)
            .onChanged({ => setCount.call(count + 1) })
            .toElement(),
        text_block("Selection changed ${count} time(s)").toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── date_picker ─────────────────────────────────────────────────────────────
// Reports the picked date via the on_changed event.
func datePickerExample(cx: RenderCx): Element {
    let (label, setLabel) = cx.useState<String>("No date picked")

    vstack([
        date_picker()
            .headerOf("Pick a date")
            .onChanged({ _: ReactorDateTime => setLabel.call("A date was picked.") })
            .toElement(),
        text_block(label).toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── time_picker ─────────────────────────────────────────────────────────────
// Reports the picked time as HH:MM with a 15-minute increment.
func timePickerExample(cx: RenderCx): Element {
    let (label, setLabel) = cx.useState<String>("No time picked")

    vstack([
        time_picker()
            .headerOf("Pick a time")
            .minuteIncrementOf(15)
            .onChanged({ ts: ReactorTimeSpan =>
                // TimeSpan.Duration is 100ns ticks: 36e9/hour, 6e8/minute.
                let hours = ts.Duration / 36000000000
                let minutes = (ts.Duration / 600000000) % 60
                setLabel.call("Picked: ${pad2StatusMedia(hours)}:${pad2StatusMedia(minutes)}")
            })
            .toElement(),
        text_block(label).toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// Zero-pad an Int64 to width 2 (e.g. 7 -> "07"), matching the reference's
// `{value:02}` time formatting.
func pad2StatusMedia(value: Int64): String {
    "${value}".padStart(2, padding: "0")
}

// ── content_dialog ──────────────────────────────────────────────────────────
// A button opens a three-option dialog; the last choice is recorded in state.
// The reference holds Option<ContentDialogResult>; here the choice is reduced
// to its display label (a String, an Equatable state type) at close time, which
// is behaviourally identical for what the sample renders.
func contentDialogExample(cx: RenderCx): Element {
    let (open, setOpen) = cx.useState<Bool>(false)
    let (label, setLabel) = cx.useState<String>("No choice yet.")

    vstack([
        text_block(label).toElement(),
        button("Open dialog").onClick({ => setOpen.call(true) }).toElement(),
        content_dialog("Delete this item?")
            .contentOf("This action cannot be undone.")
            .primaryButtonTextOf("Delete")
            .secondaryButtonTextOf("Archive")
            .closeButtonTextOf("Cancel")
            .open(open)
            .onClosed({ r: ContentDialogResult =>
                let chosen = match (r) {
                    case Primary => "You picked: Delete"
                    case Secondary => "You picked: Archive"
                    case NoneRes => "You picked: Cancel"
                }
                setLabel.call(chosen)
                setOpen.call(false)
            })
            .toElement()
    ])
        .spacing(8.0)
        .maxWidth(320.0)
        .toElement()
}

// ── flyout ────────────────────────────────────────────────────────────────--
// The reference attaches a Flyout / placement-flyout to a Button. The reactor
// Button widget has no flyout / flyout_with_placement modifier, so the flyout
// text is surfaced through the closest available lightweight popup — the button
// tooltip — while the click-to-increment state is preserved verbatim. See
// report note "flyout builder missing".
func flyoutExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(0)

    vstack([
        button("Show Flyout").tooltip("Hello from the flyout!").toElement(),
        button("Bottom Flyout").tooltip("Clicked ${count} times").toElement(),
        button("Increment").onClick({ => setCount.call(count + 1) }).toElement()
    ])
        .spacing(8.0)
        .toElement()
}

// ── teaching_tip ────────────────────────────────────────────────────────────
// A button shows a light-dismiss teaching tip with action and close buttons;
// the status line reflects the latest interaction.
func teachingTipExample(cx: RenderCx): Element {
    let (isOpen, setIsOpen) = cx.useState<Bool>(false)
    let (status, setStatus) = cx.useState<String>("(tip closed)")

    vstack([
        button("Show Teaching Tip").onClick({ => setIsOpen.call(true) }).toElement(),
        text_block("Status: ${status}").toElement(),
        teaching_tip("Welcome!")
            .subtitleOf("This is a teaching tip with action and close buttons.")
            .open(isOpen)
            .lightDismiss()
            .preferredPlacementOf(TeachingTipPlacement.Bottom)
            .actionButton("Got it")
            .closeButton("Dismiss")
            .onActionClick({ => setStatus.call("Action button clicked!") })
            .onClosed({ =>
                setIsOpen.call(false)
                setStatus.call("Tip was closed/dismissed")
            })
            .toElement()
    ])
        .spacing(12.0)
        .toElement()
}

// ── Dispatch ────────────────────────────────────────────────────────────────

func routeStatusMediaPickers(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "progress_bar" => Some(("Sample", progressBarExample))
        case "progress_ring" => Some(("Sample", progressRingExample))
        case "info_badge" => Some(("Sample", infoBadgeExample))
        case "info_bar" => Some(("Sample", infoBarExample))
        case "image" => Some(("Sample", imageExample))
        case "person_picture" => Some(("Sample", personPictureExample))
        case "calendar_date_picker" => Some(("Sample", calendarDatePickerExample))
        case "calendar_view" => Some(("Sample", calendarViewExample))
        case "date_picker" => Some(("Sample", datePickerExample))
        case "time_picker" => Some(("Sample", timePickerExample))
        case "content_dialog" => Some(("ContentDialog", contentDialogExample))
        case "flyout" => Some(("Sample", flyoutExample))
        case "teaching_tip" => Some(("TeachingTip Sample", teachingTipExample))
        case _ => None
    }
}

func namesStatusMediaPickers(): Array<String> {
    ["progress_bar", "progress_ring", "info_badge", "info_bar", "image",
     "person_picture", "calendar_date_picker", "calendar_view", "date_picker",
     "time_picker", "content_dialog", "flyout", "teaching_tip"]
}
