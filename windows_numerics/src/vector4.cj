package windows_numerics

import std.math.sqrt

// Windows.Foundation.Numerics.Vector4 — 4 single-precision floats in row order,
// matches the standard #[repr(C)] layout used by Direct2D/WinRT.
@C
public struct Vector4 {
    public var X: Float32 = 0.0
    public var Y: Float32 = 0.0
    public var Z: Float32 = 0.0
    public var W: Float32 = 0.0
}

public func vector4(x: Float32, y: Float32, z: Float32, w: Float32): Vector4 {
    var result = Vector4()
    result.X = x
    result.Y = y
    result.Z = z
    result.W = w
    return result
}

public func zeroVector4(): Vector4 {
    return vector4(0.0f32, 0.0f32, 0.0f32, 0.0f32)
}

public func oneVector4(): Vector4 {
    return vector4(1.0f32, 1.0f32, 1.0f32, 1.0f32)
}

public func unitXVector4(): Vector4 {
    return vector4(1.0f32, 0.0f32, 0.0f32, 0.0f32)
}

public func unitYVector4(): Vector4 {
    return vector4(0.0f32, 1.0f32, 0.0f32, 0.0f32)
}

public func unitZVector4(): Vector4 {
    return vector4(0.0f32, 0.0f32, 1.0f32, 0.0f32)
}

public func unitWVector4(): Vector4 {
    return vector4(0.0f32, 0.0f32, 0.0f32, 1.0f32)
}

public func negate(value: Vector4): Vector4 {
    return vector4(-value.X, -value.Y, -value.Z, -value.W)
}

public func add(left: Vector4, right: Vector4): Vector4 {
    return vector4(
        left.X + right.X,
        left.Y + right.Y,
        left.Z + right.Z,
        left.W + right.W
    )
}

public func subtract(left: Vector4, right: Vector4): Vector4 {
    return vector4(
        left.X - right.X,
        left.Y - right.Y,
        left.Z - right.Z,
        left.W - right.W
    )
}

public func multiply(left: Vector4, right: Vector4): Vector4 {
    return vector4(
        left.X * right.X,
        left.Y * right.Y,
        left.Z * right.Z,
        left.W * right.W
    )
}

public func multiply(value: Vector4, scalar: Float32): Vector4 {
    return vector4(
        value.X * scalar,
        value.Y * scalar,
        value.Z * scalar,
        value.W * scalar
    )
}

public func divide(left: Vector4, right: Vector4): Vector4 {
    return vector4(
        left.X / right.X,
        left.Y / right.Y,
        left.Z / right.Z,
        left.W / right.W
    )
}

public func divide(value: Vector4, scalar: Float32): Vector4 {
    return vector4(
        value.X / scalar,
        value.Y / scalar,
        value.Z / scalar,
        value.W / scalar
    )
}

public func equal(left: Vector4, right: Vector4): Bool {
    return left.X == right.X && left.Y == right.Y && left.Z == right.Z && left.W == right.W
}

public func dot(left: Vector4, right: Vector4): Float32 {
    return left.X * right.X + left.Y * right.Y + left.Z * right.Z + left.W * right.W
}

public func lengthSquared(value: Vector4): Float32 {
    return dot(value, value)
}

public func length(value: Vector4): Float32 {
    return sqrt(lengthSquared(value))
}

public func distanceSquared(left: Vector4, right: Vector4): Float32 {
    return lengthSquared(subtract(left, right))
}

public func distance(left: Vector4, right: Vector4): Float32 {
    return length(subtract(left, right))
}

public func normalize(value: Vector4): Vector4 {
    return divide(value, length(value))
}

public func min(left: Vector4, right: Vector4): Vector4 {
    return vector4(
        if (left.X < right.X) { left.X } else { right.X },
        if (left.Y < right.Y) { left.Y } else { right.Y },
        if (left.Z < right.Z) { left.Z } else { right.Z },
        if (left.W < right.W) { left.W } else { right.W }
    )
}

public func max(left: Vector4, right: Vector4): Vector4 {
    return vector4(
        if (left.X > right.X) { left.X } else { right.X },
        if (left.Y > right.Y) { left.Y } else { right.Y },
        if (left.Z > right.Z) { left.Z } else { right.Z },
        if (left.W > right.W) { left.W } else { right.W }
    )
}

public func clamp(value: Vector4, minValue: Vector4, maxValue: Vector4): Vector4 {
    return min(max(value, minValue), maxValue)
}

public func lerp(start: Vector4, end: Vector4, amount: Float32): Vector4 {
    return add(start, multiply(subtract(end, start), amount))
}
