package windows_time

import std.unittest.*
import std.unittest.testmacro.*

func timeSpanOptionTicks(value: Option<TimeSpan>): Option<Int64> {
    match (value) {
        case Some(span) => Some(span.ticks())
        case None => None
    }
}

@Test
func testTimeSpanConstructorsAndDisplay() {
    @Expect(TimeSpan.from_seconds(1).ticks(), 10_000_000i64)
    @Expect(TimeSpan.from_millis(1500i64).toString(), "PT1.5S")
    @Expect((TimeSpan.from_days(1) + TimeSpan.from_hours(2) + TimeSpan.from_minutes(3) + TimeSpan.from_seconds(4) + TimeSpan.from_millis(500)).ticks(), 937_845_000_000i64)
    @Expect((TimeSpan.from_seconds(10) / 2i64).ticks(), 50_000_000i64)
    @Expect(TimeSpan.from_seconds(-1).toString(), "-PT1S")
    @Expect(TimeSpan.from_ticks(1).toString(), "PT0.0000001S")
}

@Test
func testTimeSpanOverflowHelpers() {
    @Expect(TimeSpan.MAX.checked_add(TimeSpan.from_ticks(1)).isNone(), true)
    @Expect(TimeSpan.MIN.checked_sub(TimeSpan.from_ticks(1)).isNone(), true)
    @Expect(TimeSpan.MIN.checked_neg().isNone(), true)
    @Expect(TimeSpan.MAX.checked_mul(2i64).isNone(), true)
    @Expect(TimeSpan.from_ticks(10).checked_div(0i64).isNone(), true)
    @Expect(TimeSpan.MIN.saturating_neg().ticks(), TimeSpan.MAX.ticks())
}

@Test
func testDateTimeUnixRoundTripAndDisplay() {
    @Expect(DateTime.UNIX_EPOCH.ticks(), 116_444_736_000_000_000i64)
    @Expect(DateTime.UNIX_EPOCH.unix_secs(), 0i64)
    @Expect(DateTime.UNIX_EPOCH.toString(), "1970-01-01T00:00:00Z")
    @Expect(DateTime.from_ticks(0).toString(), "1601-01-01T00:00:00Z")
    @Expect((DateTime.UNIX_EPOCH + TimeSpan.from_millis(500)).toString(), "1970-01-01T00:00:00.5Z")
    @Expect((DateTime.UNIX_EPOCH + TimeSpan.from_ticks(1)).toString(), "1970-01-01T00:00:00.0000001Z")
    @Expect(DateTime.from_unix_secs(1_681_562_096i64).toString(), "2023-04-15T12:34:56Z")
    @Expect(DateTime.from_unix_secs(-1i64).toString(), "1969-12-31T23:59:59Z")
}

@Test
func testDateTimeArithmetic() {
    let a = DateTime.from_unix_secs(100i64)
    let b = DateTime.from_unix_secs(50i64)
    @Expect(timeSpanOptionTicks(a.checked_duration_since(b)), Some(TimeSpan.from_seconds(50).ticks()))
    @Expect(DateTime.MAX.checked_add(TimeSpan.from_ticks(1)).isNone(), true)
    @Expect(DateTime.MIN.checked_sub(TimeSpan.from_ticks(1)).isNone(), true)
    @Expect((DateTime.UNIX_EPOCH + TimeSpan.from_seconds(60)).unix_secs(), 60i64)
    @Expect((DateTime.UNIX_EPOCH - TimeSpan.from_seconds(60)).unix_secs(), -60i64)
}
