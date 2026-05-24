package windows_core

// Foundation value types (DateTime / Point / Rect / Size / TimeSpan) plus their
// ABI structs and projection extensions. These live in windows_core so that both
// the collections and foundation projection packages can depend on them without
// forming a dependency cycle. All referenced symbols (CopyType, RuntimeType,
// Type, WinrtGenericType, TypeKind, WinrtOutputBridge, ProjectedCopyWinrtOutputBridge,
// Result) are defined in / re-exported by windows_core, so they are referenced by
// bare name here.

public struct DateTime {
    public var UniversalTime: Int64 = 0i64
    public init() {}
}

@C
public struct DateTimeAbi {
    public var UniversalTime: Int64 = 0i64
    public init() {}
}

extend DateTime <: CopyType & RuntimeType & Type<DateTime, DateTimeAbi, DateTime> & WinrtGenericType<DateTime> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "DateTimeAbi" }
    public static func signature(): String { "struct(Windows.Foundation.DateTime;i8)" }
    public static func projectAbi(value: DateTime): DateTimeAbi {
        var abi = DateTimeAbi()
        abi.UniversalTime = value.UniversalTime
        return abi
    }
    public static func assumeInitRef(abi: DateTimeAbi): DateTime {
        var value = DateTime()
        value.UniversalTime = abi.UniversalTime
        return value
    }
    public static func fromAbi(abi: DateTimeAbi): Result<DateTime> { Result<DateTime>.Ok(DateTime.assumeInitRef(abi)) }
    public static func fromDefault(defaultValue: DateTime): Result<DateTime> { Result<DateTime>.Ok(defaultValue) }
    public static func winrtOutputBridge(): WinrtOutputBridge<DateTime> {
        ProjectedCopyWinrtOutputBridge<DateTime, DateTimeAbi, DateTime>()
    }
}

public struct Point {
    public var X: Float32 = 0.0f32
    public var Y: Float32 = 0.0f32
    public init() {}
}

@C
public struct PointAbi {
    public var X: Float32 = 0.0f32
    public var Y: Float32 = 0.0f32
    public init() {}
}

extend Point <: CopyType & RuntimeType & Type<Point, PointAbi, Point> & WinrtGenericType<Point> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "PointAbi" }
    public static func signature(): String { "struct(Windows.Foundation.Point;f4;f4)" }
    public static func projectAbi(value: Point): PointAbi {
        var abi = PointAbi()
        abi.X = value.X
        abi.Y = value.Y
        return abi
    }
    public static func assumeInitRef(abi: PointAbi): Point {
        var value = Point()
        value.X = abi.X
        value.Y = abi.Y
        return value
    }
    public static func fromAbi(abi: PointAbi): Result<Point> { Result<Point>.Ok(Point.assumeInitRef(abi)) }
    public static func fromDefault(defaultValue: Point): Result<Point> { Result<Point>.Ok(defaultValue) }
    public static func winrtOutputBridge(): WinrtOutputBridge<Point> {
        ProjectedCopyWinrtOutputBridge<Point, PointAbi, Point>()
    }
}

public struct Rect {
    public var X: Float32 = 0.0f32
    public var Y: Float32 = 0.0f32
    public var Width: Float32 = 0.0f32
    public var Height: Float32 = 0.0f32
    public init() {}
}

@C
public struct RectAbi {
    public var X: Float32 = 0.0f32
    public var Y: Float32 = 0.0f32
    public var Width: Float32 = 0.0f32
    public var Height: Float32 = 0.0f32
    public init() {}
}

extend Rect <: CopyType & RuntimeType & Type<Rect, RectAbi, Rect> & WinrtGenericType<Rect> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "RectAbi" }
    public static func signature(): String { "struct(Windows.Foundation.Rect;f4;f4;f4;f4)" }
    public static func projectAbi(value: Rect): RectAbi {
        var abi = RectAbi()
        abi.X = value.X
        abi.Y = value.Y
        abi.Width = value.Width
        abi.Height = value.Height
        return abi
    }
    public static func assumeInitRef(abi: RectAbi): Rect {
        var value = Rect()
        value.X = abi.X
        value.Y = abi.Y
        value.Width = abi.Width
        value.Height = abi.Height
        return value
    }
    public static func fromAbi(abi: RectAbi): Result<Rect> { Result<Rect>.Ok(Rect.assumeInitRef(abi)) }
    public static func fromDefault(defaultValue: Rect): Result<Rect> { Result<Rect>.Ok(defaultValue) }
    public static func winrtOutputBridge(): WinrtOutputBridge<Rect> {
        ProjectedCopyWinrtOutputBridge<Rect, RectAbi, Rect>()
    }
}

public struct Size {
    public var Width: Float32 = 0.0f32
    public var Height: Float32 = 0.0f32
    public init() {}
}

@C
public struct SizeAbi {
    public var Width: Float32 = 0.0f32
    public var Height: Float32 = 0.0f32
    public init() {}
}

extend Size <: CopyType & RuntimeType & Type<Size, SizeAbi, Size> & WinrtGenericType<Size> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "SizeAbi" }
    public static func signature(): String { "struct(Windows.Foundation.Size;f4;f4)" }
    public static func projectAbi(value: Size): SizeAbi {
        var abi = SizeAbi()
        abi.Width = value.Width
        abi.Height = value.Height
        return abi
    }
    public static func assumeInitRef(abi: SizeAbi): Size {
        var value = Size()
        value.Width = abi.Width
        value.Height = abi.Height
        return value
    }
    public static func fromAbi(abi: SizeAbi): Result<Size> { Result<Size>.Ok(Size.assumeInitRef(abi)) }
    public static func fromDefault(defaultValue: Size): Result<Size> { Result<Size>.Ok(defaultValue) }
    public static func winrtOutputBridge(): WinrtOutputBridge<Size> {
        ProjectedCopyWinrtOutputBridge<Size, SizeAbi, Size>()
    }
}

public struct TimeSpan {
    public var Duration: Int64 = 0i64
    public init() {}
}

@C
public struct TimeSpanAbi {
    public var Duration: Int64 = 0i64
    public init() {}
}

extend TimeSpan <: CopyType & RuntimeType & Type<TimeSpan, TimeSpanAbi, TimeSpan> & WinrtGenericType<TimeSpan> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "TimeSpanAbi" }
    public static func signature(): String { "struct(Windows.Foundation.TimeSpan;i8)" }
    public static func projectAbi(value: TimeSpan): TimeSpanAbi {
        var abi = TimeSpanAbi()
        abi.Duration = value.Duration
        return abi
    }
    public static func assumeInitRef(abi: TimeSpanAbi): TimeSpan {
        var value = TimeSpan()
        value.Duration = abi.Duration
        return value
    }
    public static func fromAbi(abi: TimeSpanAbi): Result<TimeSpan> { Result<TimeSpan>.Ok(TimeSpan.assumeInitRef(abi)) }
    public static func fromDefault(defaultValue: TimeSpan): Result<TimeSpan> { Result<TimeSpan>.Ok(defaultValue) }
    public static func winrtOutputBridge(): WinrtOutputBridge<TimeSpan> {
        ProjectedCopyWinrtOutputBridge<TimeSpan, TimeSpanAbi, TimeSpan>()
    }
}

public struct EventRegistrationToken {
    public var Value: Int64 = 0i64
    public init() {}
}

@C
public struct EventRegistrationTokenAbi {
    public var Value: Int64 = 0i64
    public init() {}
}

extend EventRegistrationToken <: CopyType & RuntimeType & Type<EventRegistrationToken, EventRegistrationTokenAbi, EventRegistrationToken> & WinrtGenericType<EventRegistrationToken> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "EventRegistrationTokenAbi" }
    public static func signature(): String { "struct(Windows.Foundation.EventRegistrationToken;i8)" }
    public static func projectAbi(value: EventRegistrationToken): EventRegistrationTokenAbi {
        var abi = EventRegistrationTokenAbi()
        abi.Value = value.Value
        return abi
    }
    public static func assumeInitRef(abi: EventRegistrationTokenAbi): EventRegistrationToken {
        var value = EventRegistrationToken()
        value.Value = abi.Value
        return value
    }
    public static func fromAbi(abi: EventRegistrationTokenAbi): Result<EventRegistrationToken> { Result<EventRegistrationToken>.Ok(EventRegistrationToken.assumeInitRef(abi)) }
    public static func fromDefault(defaultValue: EventRegistrationToken): Result<EventRegistrationToken> { Result<EventRegistrationToken>.Ok(defaultValue) }
    public static func winrtOutputBridge(): WinrtOutputBridge<EventRegistrationToken> {
        ProjectedCopyWinrtOutputBridge<EventRegistrationToken, EventRegistrationTokenAbi, EventRegistrationToken>()
    }
}

// HResult: the Windows.Foundation.HResult value type. Lives in windows_core
// so that both the foundation and future async projection packages can use it
// without a dependency cycle.
public struct HResult {
    public var Value: Int32 = 0i32
    public init() {}
}

@C
public struct HResultAbi {
    public var Value: Int32 = 0i32
    public init() {}
}

extend HResult <: CopyType & RuntimeType & Type<HResult, HResultAbi, HResult> & WinrtGenericType<HResult> {
    public static func typeKind(): TypeKind { TypeKind.Copy }
    public static func abiType(): String { "HResultAbi" }
    public static func signature(): String { "struct(Windows.Foundation.HResult;i4)" }
    public static func projectAbi(value: HResult): HResultAbi {
        var abi = HResultAbi()
        abi.Value = value.Value
        return abi
    }
    public static func assumeInitRef(abi: HResultAbi): HResult {
        var value = HResult()
        value.Value = abi.Value
        return value
    }
    public static func fromAbi(abi: HResultAbi): Result<HResult> { Result<HResult>.Ok(HResult.assumeInitRef(abi)) }
    public static func fromDefault(defaultValue: HResult): Result<HResult> { Result<HResult>.Ok(defaultValue) }
    public static func winrtOutputBridge(): WinrtOutputBridge<HResult> {
        ProjectedCopyWinrtOutputBridge<HResult, HResultAbi, HResult>()
    }
}
