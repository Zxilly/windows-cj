package windows_reactor.winui

import std.collection.{ArrayList}
import windows_reactor.core.{Event, EventHandler}
import windows_core.{DateTime, TimeSpan, queryInterfaceRaw}
import windows_reference.{IReference}
import windows_sys.Foundation.{TypedEventHandler}
import windows_sys.Microsoft.UI.Xaml.Controls.{
    ColorPicker, ColorChangedEventArgs,
    DatePicker, DatePickerSelectedValueChangedEventArgs,
    TimePicker, TimePickerSelectedValueChangedEventArgs,
    CalendarDatePicker, CalendarDatePickerDateChangedEventArgs,
    CalendarView, CalendarViewSelectedDatesChangedEventArgs
}

// ============================================================================
// Picker event family.
//
// wirePickerEvents subscribes the reconciler's handler to a date/time/colour
// picker control and returns the EventRevokers that own the registration(s).
// Mirrors the (Event, Handle) arms of the reference backend's attach_event for
// the picker family. The returned ArrayList is empty when the event is not
// wired (the backend then stores nothing for that key).
//
// Every picker exposes its change event as a high-level addX(delegate): token /
// removeX(token) accessor directly on its bound projection class, so the
// control's identity is QI'd to that class and the projection delegate is
// registered through it — the exact shape of the Click sample in
// event_button.cj. The delegate is captured in the revoke closure so it
// outlives the registration; revoke removes the handler and releases the
// captured projections.
//
// Implemented:
//   - ColorChanged              ColorPicker        → ColorChanged
//         → args.NewColor (Windows.UI.Color A/R/G/B)        → invokeColor
//   - DateSelected              DatePicker         → SelectedDateChanged
//         → args.NewDate (boxed IReference<DateTime>)        → invokeDateTime
//   - TimeSelected              TimePicker         → SelectedTimeChanged
//         → args.NewTime (boxed IReference<TimeSpan>)        → invokeTimeSpan
//   - CalendarDateSelected      CalendarDatePicker → DateChanged
//         → args.NewDate (boxed IReference<DateTime>)        → invokeDateTime
//   - CalendarViewSelectionChanged CalendarView    → SelectedDatesChanged
//         → no payload (the reference invokes the bare handler)→ invoke
//
// ColorChanged / SelectedDateChanged / SelectedTimeChanged / DateChanged /
// SelectedDatesChanged are TypedEventHandler<TSender, TArgs> on the projection;
// each delegate receives the raw (sender, args) ABI pointers, from which the new
// value is read by wrapping the args pointer in its EventArgs projection (the
// boxed DateTime/TimeSpan values are unboxed through IReference<T>.Value()).
// ============================================================================
func wirePickerEvents(handle: Handle, event: Event, handler: EventHandler): ArrayList<EventRevoker> {
    let revokers = ArrayList<EventRevoker>()
    match (event) {
        case ColorChanged =>
            // ColorPicker.ColorChanged: TypedEventHandler<ColorPicker, ColorChangedEventArgs>.
            let target = ColorPicker.fromAbiTake(
                queryRequired(handle.asRaw(), ColorPicker.iid(),
                    "Microsoft.UI.Xaml.Controls.IColorPicker")
            )
            let delegate = TypedEventHandler<ColorPicker, ColorChangedEventArgs>.new({ _, args =>
                try {
                    let (a, r, g, b) = colorChangedNewColor(args)
                    handler.invokeColor(a, r, g, b)
                } catch (_: Exception) {
                    // invokeColor may throw HandlerMismatchException for a
                    // misrouted variant; never let it cross the Invoke boundary.
                    ()
                }
            })
            let token = target.addColorChanged(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeColorChanged(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case DateSelected =>
            // DatePicker.SelectedDateChanged: TypedEventHandler<DatePicker, args>.
            // args.NewDate is a boxed IReference<DateTime>; skip when unset.
            let target = DatePicker.fromAbiTake(
                queryRequired(handle.asRaw(), DatePicker.iid(),
                    "Microsoft.UI.Xaml.Controls.IDatePicker")
            )
            let delegate = TypedEventHandler<DatePicker, DatePickerSelectedValueChangedEventArgs>.new({ _, args =>
                try {
                    match (datePickerNewDate(args)) {
                        case Some(dt) => handler.invokeDateTime(dt)
                        case None => ()
                    }
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addSelectedDateChanged(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeSelectedDateChanged(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case TimeSelected =>
            // TimePicker.SelectedTimeChanged: TypedEventHandler<TimePicker, args>.
            // args.NewTime is a boxed IReference<TimeSpan>; skip when unset.
            let target = TimePicker.fromAbiTake(
                queryRequired(handle.asRaw(), TimePicker.iid(),
                    "Microsoft.UI.Xaml.Controls.ITimePicker")
            )
            let delegate = TypedEventHandler<TimePicker, TimePickerSelectedValueChangedEventArgs>.new({ _, args =>
                try {
                    match (timePickerNewTime(args)) {
                        case Some(ts) => handler.invokeTimeSpan(ts)
                        case None => ()
                    }
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addSelectedTimeChanged(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeSelectedTimeChanged(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case CalendarDateSelected =>
            // CalendarDatePicker.DateChanged: TypedEventHandler<CalendarDatePicker, args>.
            // args.NewDate is a boxed IReference<DateTime>; skip when unset.
            let target = CalendarDatePicker.fromAbiTake(
                queryRequired(handle.asRaw(), CalendarDatePicker.iid(),
                    "Microsoft.UI.Xaml.Controls.ICalendarDatePicker")
            )
            let delegate = TypedEventHandler<CalendarDatePicker, CalendarDatePickerDateChangedEventArgs>.new({ _, args =>
                try {
                    match (calendarDatePickerNewDate(args)) {
                        case Some(dt) => handler.invokeDateTime(dt)
                        case None => ()
                    }
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addDateChanged(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeDateChanged(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case CalendarViewSelectionChanged =>
            // CalendarView.SelectedDatesChanged: TypedEventHandler<CalendarView, args>.
            // The reference invokes the bare handler (no payload extraction).
            let target = CalendarView.fromAbiTake(
                queryRequired(handle.asRaw(), CalendarView.iid(),
                    "Microsoft.UI.Xaml.Controls.ICalendarView")
            )
            let delegate = TypedEventHandler<CalendarView, CalendarViewSelectedDatesChangedEventArgs>.new({ _, _ =>
                try {
                    handler.invoke()
                } catch (_: Exception) {
                    ()
                }
            })
            let token = target.addSelectedDatesChanged(delegate)
            revokers.add(EventRevoker({ =>
                try {
                    target.removeSelectedDatesChanged(token)
                } catch (_: Exception) {
                    ()
                }
                delegate.close()
                target.close()
            }))
        case _ =>
            // Not a picker-family event.
            let _ = handle
            let _ = handler
    }
    revokers
}

// ── args extraction helpers ─────────────────────────────────────────────────
//
// Each helper wraps the borrowed args ABI pointer in its EventArgs projection
// (non-owning view; the caller owns the args reference) and reads the new value.
// The boxed DateTime / TimeSpan payloads are unboxed by QI-ing the box's
// identity to IReference<T> and calling Value() — the same path props_nav uses
// for boxed Tag strings. A null box (no selection) yields None so the handler is
// not invoked, mirroring the reference `if let Some(a) && let Ok(v)` guards.

// ColorChanged → Windows.UI.Color (A, R, G, B). Falls back to opaque black when
// the args pointer is null, mirroring the reference unwrap_or default colour.
func colorChangedNewColor(args: CPointer<Unit>): (UInt8, UInt8, UInt8, UInt8) {
    if (args.isNull()) {
        return (255u8, 0u8, 0u8, 0u8)
    }
    let argObj = ColorChangedEventArgs.viewOf(args)
    let color = argObj.NewColor
    (color.A, color.R, color.G, color.B)
}

// SelectedDateChanged → DateTime (or None when the args / boxed reference is
// null, i.e. the selection was cleared).
func datePickerNewDate(args: CPointer<Unit>): ?DateTime {
    if (args.isNull()) {
        return None
    }
    let argObj = DatePickerSelectedValueChangedEventArgs.viewOf(args)
    let boxed = argObj.NewDate
    try {
        return dateTimeReferenceValue(boxed.asRaw())
    } finally {
        boxed.close()
    }
}

// CalendarDatePicker.DateChanged → DateTime (or None when cleared).
func calendarDatePickerNewDate(args: CPointer<Unit>): ?DateTime {
    if (args.isNull()) {
        return None
    }
    let argObj = CalendarDatePickerDateChangedEventArgs.viewOf(args)
    let boxed = argObj.NewDate
    try {
        return dateTimeReferenceValue(boxed.asRaw())
    } finally {
        boxed.close()
    }
}

// SelectedTimeChanged → TimeSpan (or None when cleared).
func timePickerNewTime(args: CPointer<Unit>): ?TimeSpan {
    if (args.isNull()) {
        return None
    }
    let argObj = TimePickerSelectedValueChangedEventArgs.viewOf(args)
    let boxed = argObj.NewTime
    try {
        return timeSpanReferenceValue(boxed.asRaw())
    } finally {
        boxed.close()
    }
}

// Unbox a boxed IReference<DateTime> raw pointer to its DateTime value. Returns
// None when the box is null or does not carry a DateTime reference.
func dateTimeReferenceValue(raw: CPointer<Unit>): ?DateTime {
    if (raw.isNull()) {
        return None
    }
    match (unsafe { queryInterfaceRaw(raw, IReference<DateTime>.iid()) }) {
        case Some(refRaw) =>
            let box = IReference<DateTime>.fromAbiTake(refRaw)
            try {
                return Some(unsafe { box.Value() })
            } catch (_: Exception) {
                return None
            } finally {
                box.close()
            }
        case None => return None
    }
}

// Unbox a boxed IReference<TimeSpan> raw pointer to its TimeSpan value. Returns
// None when the box is null or does not carry a TimeSpan reference.
func timeSpanReferenceValue(raw: CPointer<Unit>): ?TimeSpan {
    if (raw.isNull()) {
        return None
    }
    match (unsafe { queryInterfaceRaw(raw, IReference<TimeSpan>.iid()) }) {
        case Some(refRaw) =>
            let box = IReference<TimeSpan>.fromAbiTake(refRaw)
            try {
                return Some(unsafe { box.Value() })
            } catch (_: Exception) {
                return None
            } finally {
                box.close()
            }
        case None => return None
    }
}
