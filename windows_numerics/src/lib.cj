package windows_numerics

import std.math.{cos, sin, sqrt}
import windows_sys.Foundation.Numerics.Matrix4x4 as CommonMatrix4x4
import windows_sys.Foundation.Numerics.Vector2 as CommonVector2
import windows_sys.Foundation.Numerics.Vector3 as CommonVector3

public type Matrix4x4 = CommonMatrix4x4
public type Vector2 = CommonVector2
public type Vector3 = CommonVector3

private let PI_OVER_180: Float32 = 0.017453292519943295f32

private func minScalar(left: Float32, right: Float32): Float32 {
    if (left < right) {
        return left
    }
    return right
}

private func maxScalar(left: Float32, right: Float32): Float32 {
    if (left > right) {
        return left
    }
    return right
}

private func clampScalar(value: Float32, minValue: Float32, maxValue: Float32): Float32 {
    return minScalar(maxScalar(value, minValue), maxValue)
}

private func radiansFromDegrees(degrees: Float32): Float32 {
    return degrees * PI_OVER_180
}

public func vector2(x: Float32, y: Float32): Vector2 {
    var result = Vector2()
    result.X = x
    result.Y = y
    return result
}

public func zeroVector2(): Vector2 {
    return vector2(0.0f32, 0.0f32)
}

public func oneVector2(): Vector2 {
    return vector2(1.0f32, 1.0f32)
}

public func unitXVector2(): Vector2 {
    return vector2(1.0f32, 0.0f32)
}

public func unitYVector2(): Vector2 {
    return vector2(0.0f32, 1.0f32)
}

public func negate(value: Vector2): Vector2 {
    return vector2(-value.X, -value.Y)
}

public func add(left: Vector2, right: Vector2): Vector2 {
    return vector2(left.X + right.X, left.Y + right.Y)
}

public func subtract(left: Vector2, right: Vector2): Vector2 {
    return vector2(left.X - right.X, left.Y - right.Y)
}

public func multiply(left: Vector2, right: Vector2): Vector2 {
    return vector2(left.X * right.X, left.Y * right.Y)
}

public func multiply(value: Vector2, scalar: Float32): Vector2 {
    return vector2(value.X * scalar, value.Y * scalar)
}

public func divide(left: Vector2, right: Vector2): Vector2 {
    return vector2(left.X / right.X, left.Y / right.Y)
}

public func divide(value: Vector2, scalar: Float32): Vector2 {
    return vector2(value.X / scalar, value.Y / scalar)
}

public func equal(left: Vector2, right: Vector2): Bool {
    return left.X == right.X && left.Y == right.Y
}

public func dot(left: Vector2, right: Vector2): Float32 {
    return left.X * right.X + left.Y * right.Y
}

public func lengthSquared(value: Vector2): Float32 {
    return dot(value, value)
}

public func length(value: Vector2): Float32 {
    return sqrt(lengthSquared(value))
}

public func distanceSquared(left: Vector2, right: Vector2): Float32 {
    return lengthSquared(subtract(left, right))
}

public func distance(left: Vector2, right: Vector2): Float32 {
    return length(subtract(left, right))
}

public func normalize(value: Vector2): Vector2 {
    return divide(value, length(value))
}

public func min(left: Vector2, right: Vector2): Vector2 {
    return vector2(minScalar(left.X, right.X), minScalar(left.Y, right.Y))
}

public func max(left: Vector2, right: Vector2): Vector2 {
    return vector2(maxScalar(left.X, right.X), maxScalar(left.Y, right.Y))
}

public func clamp(value: Vector2, minValue: Vector2, maxValue: Vector2): Vector2 {
    return vector2(
        clampScalar(value.X, minValue.X, maxValue.X),
        clampScalar(value.Y, minValue.Y, maxValue.Y)
    )
}

public func lerp(start: Vector2, end: Vector2, amount: Float32): Vector2 {
    return add(start, multiply(subtract(end, start), amount))
}

public func vector3(x: Float32, y: Float32, z: Float32): Vector3 {
    var result = Vector3()
    result.X = x
    result.Y = y
    result.Z = z
    return result
}

public func zeroVector3(): Vector3 {
    return vector3(0.0f32, 0.0f32, 0.0f32)
}

public func oneVector3(): Vector3 {
    return vector3(1.0f32, 1.0f32, 1.0f32)
}

public func unitXVector3(): Vector3 {
    return vector3(1.0f32, 0.0f32, 0.0f32)
}

public func unitYVector3(): Vector3 {
    return vector3(0.0f32, 1.0f32, 0.0f32)
}

public func unitZVector3(): Vector3 {
    return vector3(0.0f32, 0.0f32, 1.0f32)
}

public func negate(value: Vector3): Vector3 {
    return vector3(-value.X, -value.Y, -value.Z)
}

public func add(left: Vector3, right: Vector3): Vector3 {
    return vector3(left.X + right.X, left.Y + right.Y, left.Z + right.Z)
}

public func subtract(left: Vector3, right: Vector3): Vector3 {
    return vector3(left.X - right.X, left.Y - right.Y, left.Z - right.Z)
}

public func multiply(left: Vector3, right: Vector3): Vector3 {
    return vector3(left.X * right.X, left.Y * right.Y, left.Z * right.Z)
}

public func multiply(value: Vector3, scalar: Float32): Vector3 {
    return vector3(value.X * scalar, value.Y * scalar, value.Z * scalar)
}

public func divide(left: Vector3, right: Vector3): Vector3 {
    return vector3(left.X / right.X, left.Y / right.Y, left.Z / right.Z)
}

public func divide(value: Vector3, scalar: Float32): Vector3 {
    return vector3(value.X / scalar, value.Y / scalar, value.Z / scalar)
}

public func equal(left: Vector3, right: Vector3): Bool {
    return left.X == right.X && left.Y == right.Y && left.Z == right.Z
}

public func dot(left: Vector3, right: Vector3): Float32 {
    return left.X * right.X + left.Y * right.Y + left.Z * right.Z
}

public func lengthSquared(value: Vector3): Float32 {
    return dot(value, value)
}

public func length(value: Vector3): Float32 {
    return sqrt(lengthSquared(value))
}

public func distanceSquared(left: Vector3, right: Vector3): Float32 {
    return lengthSquared(subtract(left, right))
}

public func distance(left: Vector3, right: Vector3): Float32 {
    return length(subtract(left, right))
}

public func normalize(value: Vector3): Vector3 {
    return divide(value, length(value))
}

public func cross(left: Vector3, right: Vector3): Vector3 {
    return vector3(
        left.Y * right.Z - left.Z * right.Y,
        left.Z * right.X - left.X * right.Z,
        left.X * right.Y - left.Y * right.X
    )
}

public func min(left: Vector3, right: Vector3): Vector3 {
    return vector3(
        minScalar(left.X, right.X),
        minScalar(left.Y, right.Y),
        minScalar(left.Z, right.Z)
    )
}

public func max(left: Vector3, right: Vector3): Vector3 {
    return vector3(
        maxScalar(left.X, right.X),
        maxScalar(left.Y, right.Y),
        maxScalar(left.Z, right.Z)
    )
}

public func clamp(value: Vector3, minValue: Vector3, maxValue: Vector3): Vector3 {
    return vector3(
        clampScalar(value.X, minValue.X, maxValue.X),
        clampScalar(value.Y, minValue.Y, maxValue.Y),
        clampScalar(value.Z, minValue.Z, maxValue.Z)
    )
}

public func lerp(start: Vector3, end: Vector3, amount: Float32): Vector3 {
    return add(start, multiply(subtract(end, start), amount))
}

public func matrix4x4(
    m11: Float32,
    m12: Float32,
    m13: Float32,
    m14: Float32,
    m21: Float32,
    m22: Float32,
    m23: Float32,
    m24: Float32,
    m31: Float32,
    m32: Float32,
    m33: Float32,
    m34: Float32,
    m41: Float32,
    m42: Float32,
    m43: Float32,
    m44: Float32
): Matrix4x4 {
    var result = Matrix4x4()
    result.M11 = m11
    result.M12 = m12
    result.M13 = m13
    result.M14 = m14
    result.M21 = m21
    result.M22 = m22
    result.M23 = m23
    result.M24 = m24
    result.M31 = m31
    result.M32 = m32
    result.M33 = m33
    result.M34 = m34
    result.M41 = m41
    result.M42 = m42
    result.M43 = m43
    result.M44 = m44
    return result
}

public func identityMatrix4x4(): Matrix4x4 {
    return matrix4x4(
        1.0f32, 0.0f32, 0.0f32, 0.0f32,
        0.0f32, 1.0f32, 0.0f32, 0.0f32,
        0.0f32, 0.0f32, 1.0f32, 0.0f32,
        0.0f32, 0.0f32, 0.0f32, 1.0f32
    )
}

public func translationMatrix4x4(x: Float32, y: Float32, z: Float32): Matrix4x4 {
    var result = identityMatrix4x4()
    result.M41 = x
    result.M42 = y
    result.M43 = z
    return result
}

public func translationMatrix4x4(value: Vector3): Matrix4x4 {
    return translationMatrix4x4(value.X, value.Y, value.Z)
}

public func scaleMatrix4x4(scale: Float32): Matrix4x4 {
    return scaleMatrix4x4(scale, scale, scale)
}

public func scaleMatrix4x4(x: Float32, y: Float32, z: Float32): Matrix4x4 {
    var result = identityMatrix4x4()
    result.M11 = x
    result.M22 = y
    result.M33 = z
    return result
}

public func scaleMatrix4x4(value: Vector3): Matrix4x4 {
    return scaleMatrix4x4(value.X, value.Y, value.Z)
}

public func rotationXMatrix4x4Radians(radians: Float32): Matrix4x4 {
    let c = cos(radians)
    let s = sin(radians)
    return matrix4x4(
        1.0f32, 0.0f32, 0.0f32, 0.0f32,
        0.0f32, c, s, 0.0f32,
        0.0f32, -s, c, 0.0f32,
        0.0f32, 0.0f32, 0.0f32, 1.0f32
    )
}

public func rotationYMatrix4x4Radians(radians: Float32): Matrix4x4 {
    let c = cos(radians)
    let s = sin(radians)
    return matrix4x4(
        c, 0.0f32, -s, 0.0f32,
        0.0f32, 1.0f32, 0.0f32, 0.0f32,
        s, 0.0f32, c, 0.0f32,
        0.0f32, 0.0f32, 0.0f32, 1.0f32
    )
}

public func rotationZMatrix4x4Radians(radians: Float32): Matrix4x4 {
    let c = cos(radians)
    let s = sin(radians)
    return matrix4x4(
        c, s, 0.0f32, 0.0f32,
        -s, c, 0.0f32, 0.0f32,
        0.0f32, 0.0f32, 1.0f32, 0.0f32,
        0.0f32, 0.0f32, 0.0f32, 1.0f32
    )
}

public func rotationXMatrix4x4(degrees: Float32): Matrix4x4 {
    return rotationXMatrix4x4Radians(radiansFromDegrees(degrees))
}

public func rotationYMatrix4x4(degrees: Float32): Matrix4x4 {
    return rotationYMatrix4x4Radians(radiansFromDegrees(degrees))
}

public func rotationZMatrix4x4(degrees: Float32): Matrix4x4 {
    return rotationZMatrix4x4Radians(radiansFromDegrees(degrees))
}

public func perspectiveProjectionMatrix4x4(depth: Float32): Matrix4x4 {
    let projection = if (depth > 0.0f32) {
        -1.0f32 / depth
    } else {
        0.0f32
    }
    var result = identityMatrix4x4()
    result.M34 = projection
    return result
}

public func add(left: Matrix4x4, right: Matrix4x4): Matrix4x4 {
    return matrix4x4(
        left.M11 + right.M11, left.M12 + right.M12, left.M13 + right.M13, left.M14 + right.M14,
        left.M21 + right.M21, left.M22 + right.M22, left.M23 + right.M23, left.M24 + right.M24,
        left.M31 + right.M31, left.M32 + right.M32, left.M33 + right.M33, left.M34 + right.M34,
        left.M41 + right.M41, left.M42 + right.M42, left.M43 + right.M43, left.M44 + right.M44
    )
}

public func subtract(left: Matrix4x4, right: Matrix4x4): Matrix4x4 {
    return matrix4x4(
        left.M11 - right.M11, left.M12 - right.M12, left.M13 - right.M13, left.M14 - right.M14,
        left.M21 - right.M21, left.M22 - right.M22, left.M23 - right.M23, left.M24 - right.M24,
        left.M31 - right.M31, left.M32 - right.M32, left.M33 - right.M33, left.M34 - right.M34,
        left.M41 - right.M41, left.M42 - right.M42, left.M43 - right.M43, left.M44 - right.M44
    )
}

public func multiply(value: Matrix4x4, scalar: Float32): Matrix4x4 {
    return matrix4x4(
        value.M11 * scalar, value.M12 * scalar, value.M13 * scalar, value.M14 * scalar,
        value.M21 * scalar, value.M22 * scalar, value.M23 * scalar, value.M24 * scalar,
        value.M31 * scalar, value.M32 * scalar, value.M33 * scalar, value.M34 * scalar,
        value.M41 * scalar, value.M42 * scalar, value.M43 * scalar, value.M44 * scalar
    )
}

public func multiply(left: Matrix4x4, right: Matrix4x4): Matrix4x4 {
    return matrix4x4(
        left.M11 * right.M11 + left.M12 * right.M21 + left.M13 * right.M31 + left.M14 * right.M41,
        left.M11 * right.M12 + left.M12 * right.M22 + left.M13 * right.M32 + left.M14 * right.M42,
        left.M11 * right.M13 + left.M12 * right.M23 + left.M13 * right.M33 + left.M14 * right.M43,
        left.M11 * right.M14 + left.M12 * right.M24 + left.M13 * right.M34 + left.M14 * right.M44,
        left.M21 * right.M11 + left.M22 * right.M21 + left.M23 * right.M31 + left.M24 * right.M41,
        left.M21 * right.M12 + left.M22 * right.M22 + left.M23 * right.M32 + left.M24 * right.M42,
        left.M21 * right.M13 + left.M22 * right.M23 + left.M23 * right.M33 + left.M24 * right.M43,
        left.M21 * right.M14 + left.M22 * right.M24 + left.M23 * right.M34 + left.M24 * right.M44,
        left.M31 * right.M11 + left.M32 * right.M21 + left.M33 * right.M31 + left.M34 * right.M41,
        left.M31 * right.M12 + left.M32 * right.M22 + left.M33 * right.M32 + left.M34 * right.M42,
        left.M31 * right.M13 + left.M32 * right.M23 + left.M33 * right.M33 + left.M34 * right.M43,
        left.M31 * right.M14 + left.M32 * right.M24 + left.M33 * right.M34 + left.M34 * right.M44,
        left.M41 * right.M11 + left.M42 * right.M21 + left.M43 * right.M31 + left.M44 * right.M41,
        left.M41 * right.M12 + left.M42 * right.M22 + left.M43 * right.M32 + left.M44 * right.M42,
        left.M41 * right.M13 + left.M42 * right.M23 + left.M43 * right.M33 + left.M44 * right.M43,
        left.M41 * right.M14 + left.M42 * right.M24 + left.M43 * right.M34 + left.M44 * right.M44
    )
}

public func transpose(value: Matrix4x4): Matrix4x4 {
    return matrix4x4(
        value.M11, value.M21, value.M31, value.M41,
        value.M12, value.M22, value.M32, value.M42,
        value.M13, value.M23, value.M33, value.M43,
        value.M14, value.M24, value.M34, value.M44
    )
}

public func transform(value: Vector3, matrix: Matrix4x4): Vector3 {
    return vector3(
        value.X * matrix.M11 + value.Y * matrix.M21 + value.Z * matrix.M31 + matrix.M41,
        value.X * matrix.M12 + value.Y * matrix.M22 + value.Z * matrix.M32 + matrix.M42,
        value.X * matrix.M13 + value.Y * matrix.M23 + value.Z * matrix.M33 + matrix.M43
    )
}

public func translation(value: Matrix4x4): Vector3 {
    return vector3(value.M41, value.M42, value.M43)
}

public func equal(left: Matrix4x4, right: Matrix4x4): Bool {
    return left.M11 == right.M11 && left.M12 == right.M12 &&
        left.M13 == right.M13 && left.M14 == right.M14 &&
        left.M21 == right.M21 && left.M22 == right.M22 &&
        left.M23 == right.M23 && left.M24 == right.M24 &&
        left.M31 == right.M31 && left.M32 == right.M32 &&
        left.M33 == right.M33 && left.M34 == right.M34 &&
        left.M41 == right.M41 && left.M42 == right.M42 &&
        left.M43 == right.M43 && left.M44 == right.M44
}

public func isIdentity(value: Matrix4x4): Bool {
    return equal(value, identityMatrix4x4())
}
