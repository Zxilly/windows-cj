package windows_time

import std.math.numeric.BigInt
import std.time as std_time
import windows_core as windows_core

public type StdDuration = Duration
public type DateTime = windows_core.DateTime
public type DateTimeAbi = windows_core.DateTimeAbi
public type TimeSpan = windows_core.TimeSpan
public type TimeSpanAbi = windows_core.TimeSpanAbi

public let TICKS_PER_MICROSECOND: Int64 = 10i64
public let TICKS_PER_MILLISECOND: Int64 = 10_000i64
public let TICKS_PER_SECOND: Int64 = 10_000_000i64
public let TICKS_PER_MINUTE: Int64 = 600_000_000i64
public let TICKS_PER_HOUR: Int64 = 36_000_000_000i64
public let TICKS_PER_DAY: Int64 = 864_000_000_000i64
public let UNIX_EPOCH_DIFFERENCE_SECS: Int64 = 11_644_473_600i64
public let UNIX_EPOCH_TICKS: Int64 = 116_444_736_000_000_000i64

public struct TimeRangeError <: ToString & Equatable<TimeRangeError> {
    public init() {}

    public operator func ==(other: TimeRangeError): Bool {
        let _ = other
        true
    }

    public operator func !=(other: TimeRangeError): Bool {
        !(this == other)
    }

    public func toString(): String {
        "value out of range for the target time type"
    }
}

public enum TimeResult<T> {
    | Ok(T)
    | Err(TimeRangeError)

    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    public func isErr(): Bool {
        !isOk()
    }

    public func unwrap(): T {
        match (this) {
            case Ok(value) => value
            case Err(error) => throw Exception("called TimeResult.unwrap() on an Err value: ${error}")
        }
    }

    public func ok(): Option<T> {
        match (this) {
            case Ok(value) => Some(value)
            case Err(_) => None
        }
    }

    public func err(): Option<TimeRangeError> {
        match (this) {
            case Ok(_) => None
            case Err(error) => Some(error)
        }
    }
}

func checkedAddI64(lhs: Int64, rhs: Int64): Option<Int64> {
    if (rhs > 0i64 && lhs > Int64.Max - rhs) {
        return None
    }
    if (rhs < 0i64 && lhs < Int64.Min - rhs) {
        return None
    }
    Some(lhs + rhs)
}

func checkedSubI64(lhs: Int64, rhs: Int64): Option<Int64> {
    if (rhs > 0i64 && lhs < Int64.Min + rhs) {
        return None
    }
    if (rhs < 0i64 && lhs > Int64.Max + rhs) {
        return None
    }
    Some(lhs - rhs)
}

func checkedMulI64(lhs: Int64, rhs: Int64): Option<Int64> {
    if (lhs == 0i64 || rhs == 0i64) {
        return Some(0i64)
    }
    if (lhs > 0i64) {
        if (rhs > 0i64 && lhs > Int64.Max / rhs) {
            return None
        }
        if (rhs < 0i64 && rhs < Int64.Min / lhs) {
            return None
        }
    } else {
        if (rhs > 0i64 && lhs < Int64.Min / rhs) {
            return None
        }
        if (rhs < 0i64 && lhs < Int64.Max / rhs) {
            return None
        }
    }
    Some(lhs * rhs)
}

func checkedDivI64(lhs: Int64, rhs: Int64): Option<Int64> {
    if (rhs == 0i64) {
        return None
    }
    if (lhs == Int64.Min && rhs == -1i64) {
        return None
    }
    Some(lhs / rhs)
}

func saturatingAddI64(lhs: Int64, rhs: Int64): Int64 {
    match (checkedAddI64(lhs, rhs)) {
        case Some(value) => value
        case None => if (rhs > 0i64) { Int64.Max } else { Int64.Min }
    }
}

func saturatingSubI64(lhs: Int64, rhs: Int64): Int64 {
    match (checkedSubI64(lhs, rhs)) {
        case Some(value) => value
        case None => if (rhs > 0i64) { Int64.Min } else { Int64.Max }
    }
}

func saturatingMulI64(lhs: Int64, rhs: Int64): Int64 {
    match (checkedMulI64(lhs, rhs)) {
        case Some(value) => value
        case None =>
            if ((lhs < 0i64 && rhs > 0i64) || (lhs > 0i64 && rhs < 0i64)) {
                Int64.Min
            } else {
                Int64.Max
            }
    }
}

func absMagnitude(value: Int64): UInt64 {
    if (value >= 0i64) {
        return UInt64(value)
    }
    if (value == Int64.Min) {
        return 0x8000_0000_0000_0000u64
    }
    UInt64(-value)
}

func makeTimeSpan(ticks: Int64): TimeSpan {
    var value = TimeSpan()
    value.Duration = ticks
    value
}

func makeDateTime(ticks: Int64): DateTime {
    var value = DateTime()
    value.UniversalTime = ticks
    value
}

func optionTimeSpan(ticks: Option<Int64>): Option<TimeSpan> {
    match (ticks) {
        case Some(value) => Some(makeTimeSpan(value))
        case None => None
    }
}

func optionDateTime(ticks: Option<Int64>): Option<DateTime> {
    match (ticks) {
        case Some(value) => Some(makeDateTime(value))
        case None => None
    }
}

func padLeft(value: String, width: Int64): String {
    var result = value
    while (result.size < width) {
        result = "0" + result
    }
    result
}

func trimFractionDigits(fraction: UInt64): String {
    var text = padLeft("${fraction}", 7)
    while (text.size > 0 && text[text.size - 1] == UInt8(48)) {
        text = text[0..text.size - 1]
    }
    text
}

func divEuclid(value: Int64, divisor: Int64): (Int64, Int64) {
    var q = value / divisor
    var r = value % divisor
    if (r < 0i64) {
        q -= 1i64
        r += divisor
    }
    (q, r)
}

func civilFromDays(daysSinceUnixEpoch: Int64): (Int64, Int64, Int64) {
    let z = daysSinceUnixEpoch + 719_468i64
    let era = if (z >= 0i64) { z } else { z - 146_096i64 } / 146_097i64
    let doe = z - era * 146_097i64
    let yoe = (doe - doe / 1460i64 + doe / 36_524i64 - doe / 146_096i64) / 365i64
    var y = yoe + era * 400i64
    let doy = doe - (365i64 * yoe + yoe / 4i64 - yoe / 100i64)
    let mp = (5i64 * doy + 2i64) / 153i64
    let d = doy - (153i64 * mp + 2i64) / 5i64 + 1i64
    let m = if (mp < 10i64) { mp + 3i64 } else { mp - 9i64 }
    if (m <= 2i64) {
        y += 1i64
    }
    (y, m, d)
}

extend TimeSpan {
    public static prop ZERO: TimeSpan {
        get() { makeTimeSpan(0i64) }
    }

    public static prop MIN: TimeSpan {
        get() { makeTimeSpan(Int64.Min) }
    }

    public static prop MAX: TimeSpan {
        get() { makeTimeSpan(Int64.Max) }
    }

    public static func from_ticks(ticks: Int64): TimeSpan {
        makeTimeSpan(ticks)
    }

    public static func from_micros(micros: Int64): TimeSpan {
        makeTimeSpan(saturatingMulI64(micros, TICKS_PER_MICROSECOND))
    }

    public static func from_millis(millis: Int64): TimeSpan {
        makeTimeSpan(saturatingMulI64(millis, TICKS_PER_MILLISECOND))
    }

    public static func from_seconds(seconds: Int64): TimeSpan {
        makeTimeSpan(saturatingMulI64(seconds, TICKS_PER_SECOND))
    }

    public static func from_minutes(minutes: Int64): TimeSpan {
        makeTimeSpan(saturatingMulI64(minutes, TICKS_PER_MINUTE))
    }

    public static func from_hours(hours: Int64): TimeSpan {
        makeTimeSpan(saturatingMulI64(hours, TICKS_PER_HOUR))
    }

    public static func from_days(days: Int64): TimeSpan {
        makeTimeSpan(saturatingMulI64(days, TICKS_PER_DAY))
    }

    public static func try_from_duration(value: StdDuration): TimeResult<TimeSpan> {
        let nanos = value.toNanoseconds()
        if (nanos < 0i64) {
            return TimeResult<TimeSpan>.Err(TimeRangeError())
        }
        TimeResult<TimeSpan>.Ok(makeTimeSpan(nanos / 100i64))
    }

    public func try_to_duration(): TimeResult<StdDuration> {
        if (Duration < 0i64) {
            return TimeResult<Duration>.Err(TimeRangeError())
        }
        match (checkedMulI64(Duration, 100i64)) {
            case Some(nanos) => TimeResult<StdDuration>.Ok(StdDuration.nanosecond * nanos)
            case None => TimeResult<StdDuration>.Err(TimeRangeError())
        }
    }

    public func ticks(): Int64 {
        Duration
    }

    public func whole_micros(): Int64 {
        Duration / TICKS_PER_MICROSECOND
    }

    public func whole_millis(): Int64 {
        Duration / TICKS_PER_MILLISECOND
    }

    public func whole_seconds(): Int64 {
        Duration / TICKS_PER_SECOND
    }

    public func whole_minutes(): Int64 {
        Duration / TICKS_PER_MINUTE
    }

    public func whole_hours(): Int64 {
        Duration / TICKS_PER_HOUR
    }

    public func whole_days(): Int64 {
        Duration / TICKS_PER_DAY
    }

    public func whole_nanos(): BigInt {
        BigInt(Duration) * BigInt(100i64)
    }

    public func is_zero(): Bool {
        Duration == 0i64
    }

    public func is_negative(): Bool {
        Duration < 0i64
    }

    public func is_positive(): Bool {
        Duration > 0i64
    }

    public func abs(): TimeSpan {
        if (Duration == Int64.Min) {
            return TimeSpan.MAX
        }
        if (Duration < 0i64) {
            return makeTimeSpan(-Duration)
        }
        this
    }

    public func signum(): Int64 {
        if (Duration < 0i64) {
            return -1i64
        }
        if (Duration > 0i64) {
            return 1i64
        }
        0i64
    }

    public func checked_add(rhs: TimeSpan): Option<TimeSpan> {
        optionTimeSpan(checkedAddI64(Duration, rhs.Duration))
    }

    public func checked_sub(rhs: TimeSpan): Option<TimeSpan> {
        optionTimeSpan(checkedSubI64(Duration, rhs.Duration))
    }

    public func checked_neg(): Option<TimeSpan> {
        if (Duration == Int64.Min) {
            return None
        }
        Some(makeTimeSpan(-Duration))
    }

    public func checked_mul(rhs: Int64): Option<TimeSpan> {
        optionTimeSpan(checkedMulI64(Duration, rhs))
    }

    public func checked_div(rhs: Int64): Option<TimeSpan> {
        optionTimeSpan(checkedDivI64(Duration, rhs))
    }

    public func saturating_add(rhs: TimeSpan): TimeSpan {
        makeTimeSpan(saturatingAddI64(Duration, rhs.Duration))
    }

    public func saturating_sub(rhs: TimeSpan): TimeSpan {
        makeTimeSpan(saturatingSubI64(Duration, rhs.Duration))
    }

    public func saturating_neg(): TimeSpan {
        if (Duration == Int64.Min) {
            return TimeSpan.MAX
        }
        makeTimeSpan(-Duration)
    }

    public operator func +(rhs: TimeSpan): TimeSpan {
        match (checked_add(rhs)) {
            case Some(value) => value
            case None => throw ArithmeticException("overflow when adding TimeSpan values")
        }
    }

    public operator func -(rhs: TimeSpan): TimeSpan {
        match (checked_sub(rhs)) {
            case Some(value) => value
            case None => throw ArithmeticException("overflow when subtracting TimeSpan values")
        }
    }

    public operator func -(): TimeSpan {
        match (checked_neg()) {
            case Some(value) => value
            case None => throw ArithmeticException("overflow when negating TimeSpan value")
        }
    }

    public operator func *(rhs: Int64): TimeSpan {
        match (checked_mul(rhs)) {
            case Some(value) => value
            case None => throw ArithmeticException("overflow when multiplying TimeSpan value")
        }
    }

    public operator func /(rhs: Int64): TimeSpan {
        match (checked_div(rhs)) {
            case Some(value) => value
            case None =>
                if (rhs == 0i64) {
                    throw ArithmeticException("attempt to divide TimeSpan by zero")
                }
                throw ArithmeticException("overflow when dividing TimeSpan value")
        }
    }

    public operator func ==(other: TimeSpan): Bool {
        Duration == other.Duration
    }

    public operator func !=(other: TimeSpan): Bool {
        Duration != other.Duration
    }

    public operator func <(other: TimeSpan): Bool {
        Duration < other.Duration
    }

    public operator func <=(other: TimeSpan): Bool {
        Duration <= other.Duration
    }

    public operator func >(other: TimeSpan): Bool {
        Duration > other.Duration
    }

    public operator func >=(other: TimeSpan): Bool {
        Duration >= other.Duration
    }

    public func compare(other: TimeSpan): Ordering {
        if (Duration < other.Duration) {
            return Ordering.LT
        }
        if (Duration > other.Duration) {
            return Ordering.GT
        }
        Ordering.EQ
    }

    public func hashCode(): Int64 {
        Duration.hashCode()
    }

    public func toString(): String {
        if (Duration == 0i64) {
            return "PT0S"
        }

        let sign = if (Duration < 0i64) { "-" } else { "" }
        let ticks = absMagnitude(Duration)
        let totalSeconds = ticks / UInt64(TICKS_PER_SECOND)
        let fraction = ticks % UInt64(TICKS_PER_SECOND)
        let days = totalSeconds / 86_400u64
        var remainder = totalSeconds % 86_400u64
        let hours = remainder / 3_600u64
        remainder = remainder % 3_600u64
        let minutes = remainder / 60u64
        let seconds = remainder % 60u64

        let sb = StringBuilder()
        sb.append(sign)
        sb.append("P")
        if (days != 0u64) {
            sb.append("${days}D")
        }
        let needTime = hours != 0u64 || minutes != 0u64 || seconds != 0u64 || fraction != 0u64 || days == 0u64
        if (needTime) {
            sb.append("T")
            if (hours != 0u64) {
                sb.append("${hours}H")
            }
            if (minutes != 0u64) {
                sb.append("${minutes}M")
            }
            if (seconds != 0u64 || fraction != 0u64 || (hours == 0u64 && minutes == 0u64)) {
                if (fraction != 0u64) {
                    sb.append("${seconds}.")
                    sb.append(trimFractionDigits(fraction))
                    sb.append("S")
                } else {
                    sb.append("${seconds}S")
                }
            }
        }
        sb.toString()
    }
}

extend DateTime {
    public static prop UNIX_EPOCH: DateTime {
        get() { makeDateTime(UNIX_EPOCH_TICKS) }
    }

    public static prop MIN: DateTime {
        get() { makeDateTime(Int64.Min) }
    }

    public static prop MAX: DateTime {
        get() { makeDateTime(Int64.Max) }
    }

    public static func from_ticks(ticks: Int64): DateTime {
        makeDateTime(ticks)
    }

    public static func from_unix_secs(secs: Int64): DateTime {
        let total = saturatingAddI64(secs, UNIX_EPOCH_DIFFERENCE_SECS)
        makeDateTime(saturatingMulI64(total, TICKS_PER_SECOND))
    }

    public static func from_unix_millis(millis: Int64): DateTime {
        let unixTicks = saturatingMulI64(millis, TICKS_PER_MILLISECOND)
        makeDateTime(saturatingAddI64(unixTicks, UNIX_EPOCH_TICKS))
    }

    public static func now(): DateTime {
        let stamp = std_time.DateTime.now().toUnixTimeStamp()
        let nanos = stamp.toNanoseconds()
        makeDateTime(UNIX_EPOCH_TICKS + nanos / 100i64)
    }

    public func ticks(): Int64 {
        UniversalTime
    }

    public func unix_secs(): Int64 {
        UniversalTime / TICKS_PER_SECOND - UNIX_EPOCH_DIFFERENCE_SECS
    }

    public func unix_millis(): Int64 {
        UniversalTime / TICKS_PER_MILLISECOND - UNIX_EPOCH_DIFFERENCE_SECS * 1000i64
    }

    public func unix_nanos(): BigInt {
        BigInt(UniversalTime) * BigInt(100i64) - BigInt(UNIX_EPOCH_DIFFERENCE_SECS) * BigInt(1_000_000_000i64)
    }

    public func checked_add(rhs: TimeSpan): Option<DateTime> {
        optionDateTime(checkedAddI64(UniversalTime, rhs.Duration))
    }

    public func checked_sub(rhs: TimeSpan): Option<DateTime> {
        optionDateTime(checkedSubI64(UniversalTime, rhs.Duration))
    }

    public func checked_duration_since(earlier: DateTime): Option<TimeSpan> {
        optionTimeSpan(checkedSubI64(UniversalTime, earlier.UniversalTime))
    }

    public func saturating_add(rhs: TimeSpan): DateTime {
        makeDateTime(saturatingAddI64(UniversalTime, rhs.Duration))
    }

    public func saturating_sub(rhs: TimeSpan): DateTime {
        makeDateTime(saturatingSubI64(UniversalTime, rhs.Duration))
    }

    public operator func +(rhs: TimeSpan): DateTime {
        match (checked_add(rhs)) {
            case Some(value) => value
            case None => throw ArithmeticException("overflow when adding TimeSpan to DateTime")
        }
    }

    public operator func -(rhs: TimeSpan): DateTime {
        match (checked_sub(rhs)) {
            case Some(value) => value
            case None => throw ArithmeticException("overflow when subtracting TimeSpan from DateTime")
        }
    }

    public operator func -(rhs: DateTime): TimeSpan {
        match (checked_duration_since(rhs)) {
            case Some(value) => value
            case None => throw ArithmeticException("overflow when subtracting DateTime values")
        }
    }

    public operator func ==(other: DateTime): Bool {
        UniversalTime == other.UniversalTime
    }

    public operator func !=(other: DateTime): Bool {
        UniversalTime != other.UniversalTime
    }

    public operator func <(other: DateTime): Bool {
        UniversalTime < other.UniversalTime
    }

    public operator func <=(other: DateTime): Bool {
        UniversalTime <= other.UniversalTime
    }

    public operator func >(other: DateTime): Bool {
        UniversalTime > other.UniversalTime
    }

    public operator func >=(other: DateTime): Bool {
        UniversalTime >= other.UniversalTime
    }

    public func compare(other: DateTime): Ordering {
        if (UniversalTime < other.UniversalTime) {
            return Ordering.LT
        }
        if (UniversalTime > other.UniversalTime) {
            return Ordering.GT
        }
        Ordering.EQ
    }

    public func hashCode(): Int64 {
        UniversalTime.hashCode()
    }

    public func toString(): String {
        let unixTicks = UniversalTime - UNIX_EPOCH_TICKS
        let (days, intradayTicks) = divEuclid(unixTicks, TICKS_PER_DAY)
        let (year, month, day) = civilFromDays(days)
        let secondsInDay = intradayTicks / TICKS_PER_SECOND
        let fraction = UInt64(intradayTicks % TICKS_PER_SECOND)
        let hour = secondsInDay / 3600i64
        let minute = (secondsInDay % 3600i64) / 60i64
        let second = secondsInDay % 60i64

        let sb = StringBuilder()
        if (year < 0i64) {
            sb.append("-")
            sb.append(padLeft("${-year}", 4))
        } else {
            sb.append(padLeft("${year}", 4))
        }
        sb.append("-")
        sb.append(padLeft("${month}", 2))
        sb.append("-")
        sb.append(padLeft("${day}", 2))
        sb.append("T")
        sb.append(padLeft("${hour}", 2))
        sb.append(":")
        sb.append(padLeft("${minute}", 2))
        sb.append(":")
        sb.append(padLeft("${second}", 2))
        if (fraction != 0u64) {
            sb.append(".")
            sb.append(trimFractionDigits(fraction))
        }
        sb.append("Z")
        sb.toString()
    }
}

// Free-function renderers for DateTime / TimeSpan. The toString() above lives in
// a *direct* extension, which is visible only inside this package — other
// packages (windows_reactor, gallery) cannot call dt.toString() across the
// boundary. These public top-level wrappers ARE cross-package visible, so
// dependents can render picked date/time values (reference uses the Display
// impl, e.g. format!("Selected: {date}")).
public func formatDateTime(dt: DateTime): String { dt.toString() }
public func formatTimeSpan(ts: TimeSpan): String { ts.toString() }
