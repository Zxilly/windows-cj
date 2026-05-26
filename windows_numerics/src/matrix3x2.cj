package windows_numerics

import std.math.{cos, sin, tan}

// Windows.Foundation.Numerics.Matrix3x2 — 3x2 affine transform in row order,
// laid out as 6 contiguous f32 values (#[repr(C)] equivalent).
@C
public struct Matrix3x2 {
    public var M11: Float32 = 0.0
    public var M12: Float32 = 0.0
    public var M21: Float32 = 0.0
    public var M22: Float32 = 0.0
    public var M31: Float32 = 0.0
    public var M32: Float32 = 0.0
}

public func matrix3x2(
    m11: Float32,
    m12: Float32,
    m21: Float32,
    m22: Float32,
    m31: Float32,
    m32: Float32
): Matrix3x2 {
    var result = Matrix3x2()
    result.M11 = m11
    result.M12 = m12
    result.M21 = m21
    result.M22 = m22
    result.M31 = m31
    result.M32 = m32
    return result
}

public func identityMatrix3x2(): Matrix3x2 {
    return matrix3x2(1.0f32, 0.0f32, 0.0f32, 1.0f32, 0.0f32, 0.0f32)
}

public func translationMatrix3x2(x: Float32, y: Float32): Matrix3x2 {
    return matrix3x2(1.0f32, 0.0f32, 0.0f32, 1.0f32, x, y)
}

public func translationMatrix3x2(value: Vector2): Matrix3x2 {
    return translationMatrix3x2(value.X, value.Y)
}

public func scaleMatrix3x2(scale: Float32): Matrix3x2 {
    return scaleMatrix3x2(scale, scale)
}

public func scaleMatrix3x2(x: Float32, y: Float32): Matrix3x2 {
    return matrix3x2(x, 0.0f32, 0.0f32, y, 0.0f32, 0.0f32)
}

public func scaleMatrix3x2(value: Vector2): Matrix3x2 {
    return scaleMatrix3x2(value.X, value.Y)
}

public func scaleMatrix3x2(x: Float32, y: Float32, center: Vector2): Matrix3x2 {
    let tx = center.X * (1.0f32 - x)
    let ty = center.Y * (1.0f32 - y)
    return matrix3x2(x, 0.0f32, 0.0f32, y, tx, ty)
}

public func rotationMatrix3x2Radians(radians: Float32): Matrix3x2 {
    let c = cos(radians)
    let s = sin(radians)
    return matrix3x2(c, s, -s, c, 0.0f32, 0.0f32)
}

public func rotationMatrix3x2(degrees: Float32): Matrix3x2 {
    return rotationMatrix3x2Radians(degrees * 0.017453292519943295f32)
}

public func rotationMatrix3x2Radians(radians: Float32, center: Vector2): Matrix3x2 {
    let c = cos(radians)
    let s = sin(radians)
    let tx = center.X * (1.0f32 - c) + center.Y * s
    let ty = center.Y * (1.0f32 - c) - center.X * s
    return matrix3x2(c, s, -s, c, tx, ty)
}

public func rotationMatrix3x2(degrees: Float32, center: Vector2): Matrix3x2 {
    return rotationMatrix3x2Radians(degrees * 0.017453292519943295f32, center)
}

public func skewMatrix3x2Radians(xRadians: Float32, yRadians: Float32): Matrix3x2 {
    let tx = tan(xRadians)
    let ty = tan(yRadians)
    return matrix3x2(1.0f32, ty, tx, 1.0f32, 0.0f32, 0.0f32)
}

public func skewMatrix3x2(xDegrees: Float32, yDegrees: Float32): Matrix3x2 {
    return skewMatrix3x2Radians(
        xDegrees * 0.017453292519943295f32,
        yDegrees * 0.017453292519943295f32
    )
}

public func skewMatrix3x2Radians(xRadians: Float32, yRadians: Float32, center: Vector2): Matrix3x2 {
    let tx = tan(xRadians)
    let ty = tan(yRadians)
    return matrix3x2(
        1.0f32, ty,
        tx, 1.0f32,
        -center.Y * tx,
        -center.X * ty
    )
}

public func skewMatrix3x2(xDegrees: Float32, yDegrees: Float32, center: Vector2): Matrix3x2 {
    return skewMatrix3x2Radians(
        xDegrees * 0.017453292519943295f32,
        yDegrees * 0.017453292519943295f32,
        center
    )
}

public func add(left: Matrix3x2, right: Matrix3x2): Matrix3x2 {
    return matrix3x2(
        left.M11 + right.M11, left.M12 + right.M12,
        left.M21 + right.M21, left.M22 + right.M22,
        left.M31 + right.M31, left.M32 + right.M32
    )
}

public func subtract(left: Matrix3x2, right: Matrix3x2): Matrix3x2 {
    return matrix3x2(
        left.M11 - right.M11, left.M12 - right.M12,
        left.M21 - right.M21, left.M22 - right.M22,
        left.M31 - right.M31, left.M32 - right.M32
    )
}

public func multiply(value: Matrix3x2, scalar: Float32): Matrix3x2 {
    return matrix3x2(
        value.M11 * scalar, value.M12 * scalar,
        value.M21 * scalar, value.M22 * scalar,
        value.M31 * scalar, value.M32 * scalar
    )
}

public func multiply(left: Matrix3x2, right: Matrix3x2): Matrix3x2 {
    return matrix3x2(
        left.M11 * right.M11 + left.M12 * right.M21,
        left.M11 * right.M12 + left.M12 * right.M22,
        left.M21 * right.M11 + left.M22 * right.M21,
        left.M21 * right.M12 + left.M22 * right.M22,
        left.M31 * right.M11 + left.M32 * right.M21 + right.M31,
        left.M31 * right.M12 + left.M32 * right.M22 + right.M32
    )
}

public func equal(left: Matrix3x2, right: Matrix3x2): Bool {
    return left.M11 == right.M11 && left.M12 == right.M12 &&
        left.M21 == right.M21 && left.M22 == right.M22 &&
        left.M31 == right.M31 && left.M32 == right.M32
}

public func isIdentity(value: Matrix3x2): Bool {
    return equal(value, identityMatrix3x2())
}

public func translation(value: Matrix3x2): Vector2 {
    return vector2(value.M31, value.M32)
}
