package windows_reactor.core

import windows_time.{DateTime, TimeSpan, formatDateTime, formatTimeSpan}

// Re-export windows_time scalar types under reactor-local aliases, matching
// the reference DateTimeChanged / TimeChanged event payloads. The only
// non-std dependency at this phase, per the headless build constraint.
public type ReactorDateTime = DateTime
public type ReactorTimeSpan = TimeSpan

// Format a picked date/time as a display string. windows_time provides
// DateTime.toString()/TimeSpan.toString() as package-local extensions; those are
// visible here (this package imports windows_time directly) but NOT to gallery /
// page code, which only sees the reactor-local alias across the package boundary.
// These thin re-exports let page code render picked values (reference uses the
// Display impl, e.g. format!("Selected: {date}")).
public func formatReactorDateTime(dt: ReactorDateTime): String { formatDateTime(dt) }
public func formatReactorTimeSpan(ts: ReactorTimeSpan): String { formatTimeSpan(ts) }
