package windows_numerics

import std.unittest.*
import std.unittest.testmacro.*

let TEST_EPSILON: Float32 = 0.0001f32

func absDelta(value: Float32): Float32 {
    if (value < 0.0f32) {
        return -value
    }
    return value
}

func closeTo(actual: Float32, expected: Float32): Bool {
    return absDelta(actual - expected) <= TEST_EPSILON
}

func expectVector2(actual: Vector2, x: Float32, y: Float32): Unit {
    @Expect(closeTo(actual.X, x), true)
    @Expect(closeTo(actual.Y, y), true)
}

func expectVector3(actual: Vector3, x: Float32, y: Float32, z: Float32): Unit {
    @Expect(closeTo(actual.X, x), true)
    @Expect(closeTo(actual.Y, y), true)
    @Expect(closeTo(actual.Z, z), true)
}

func expectMatrixCell(actual: Float32, expected: Float32): Unit {
    @Expect(closeTo(actual, expected), true)
}

@Test
func testVector2ConstructorsAndArithmetic() {
    let a = vector2(3.0f32, 4.0f32)
    let b = vector2(1.0f32, -2.0f32)

    expectVector2(zeroVector2(), 0.0f32, 0.0f32)
    expectVector2(oneVector2(), 1.0f32, 1.0f32)
    expectVector2(unitXVector2(), 1.0f32, 0.0f32)
    expectVector2(unitYVector2(), 0.0f32, 1.0f32)
    expectVector2(add(a, b), 4.0f32, 2.0f32)
    expectVector2(subtract(a, b), 2.0f32, 6.0f32)
    expectVector2(negate(b), -1.0f32, 2.0f32)
    expectVector2(multiply(a, 2.0f32), 6.0f32, 8.0f32)
    expectVector2(divide(a, 2.0f32), 1.5f32, 2.0f32)
    @Expect(equal(a, vector2(3.0f32, 4.0f32)), true)
    @Expect(equal(a, b), false)
}

@Test
func testVector2MathHelpers() {
    let value = vector2(3.0f32, 4.0f32)

    @Expect(closeTo(dot(value, vector2(2.0f32, 5.0f32)), 26.0f32), true)
    @Expect(closeTo(lengthSquared(value), 25.0f32), true)
    @Expect(closeTo(length(value), 5.0f32), true)
    @Expect(closeTo(distance(value, vector2(6.0f32, 8.0f32)), 5.0f32), true)
    @Expect(closeTo(distanceSquared(value, vector2(6.0f32, 8.0f32)), 25.0f32), true)
    expectVector2(normalize(value), 0.6f32, 0.8f32)
    expectVector2(min(value, vector2(2.0f32, 10.0f32)), 2.0f32, 4.0f32)
    expectVector2(max(value, vector2(2.0f32, 10.0f32)), 3.0f32, 10.0f32)
    expectVector2(clamp(vector2(-1.0f32, 6.0f32), zeroVector2(), vector2(4.0f32, 5.0f32)), 0.0f32, 5.0f32)
    expectVector2(lerp(zeroVector2(), vector2(10.0f32, 20.0f32), 0.25f32), 2.5f32, 5.0f32)
}

@Test
func testVector3MathHelpers() {
    let x = unitXVector3()
    let y = unitYVector3()
    let value = vector3(2.0f32, 3.0f32, 6.0f32)

    expectVector3(zeroVector3(), 0.0f32, 0.0f32, 0.0f32)
    expectVector3(oneVector3(), 1.0f32, 1.0f32, 1.0f32)
    expectVector3(unitZVector3(), 0.0f32, 0.0f32, 1.0f32)
    @Expect(closeTo(length(value), 7.0f32), true)
    @Expect(closeTo(dot(value, vector3(1.0f32, 2.0f32, 3.0f32)), 26.0f32), true)
    expectVector3(cross(x, y), 0.0f32, 0.0f32, 1.0f32)
    expectVector3(normalize(value), 0.2857143f32, 0.4285714f32, 0.8571429f32)
    expectVector3(add(value, vector3(1.0f32, 1.0f32, 1.0f32)), 3.0f32, 4.0f32, 7.0f32)
    expectVector3(multiply(value, 2.0f32), 4.0f32, 6.0f32, 12.0f32)
    expectVector3(clamp(vector3(-1.0f32, 4.0f32, 9.0f32), zeroVector3(), vector3(3.0f32, 3.0f32, 8.0f32)), 0.0f32, 3.0f32, 8.0f32)
}

@Test
func testMatrix4x4ConstructorsAndMultiplication() {
    let identity = identityMatrix4x4()
    let offset = translationMatrix4x4(1.0f32, 2.0f32, 3.0f32)
    let scale = scaleMatrix4x4(2.0f32, 3.0f32, 4.0f32)
    let combined = multiply(offset, scale)

    @Expect(isIdentity(identity), true)
    @Expect(equal(multiply(identity, offset), offset), true)
    expectVector3(translation(offset), 1.0f32, 2.0f32, 3.0f32)
    expectMatrixCell(combined.M11, 2.0f32)
    expectMatrixCell(combined.M22, 3.0f32)
    expectMatrixCell(combined.M33, 4.0f32)
    expectMatrixCell(combined.M41, 2.0f32)
    expectMatrixCell(combined.M42, 6.0f32)
    expectMatrixCell(combined.M43, 12.0f32)
    expectMatrixCell(multiply(identity, 2.0f32).M44, 2.0f32)
}

func expectVector4(actual: Vector4, x: Float32, y: Float32, z: Float32, w: Float32): Unit {
    @Expect(closeTo(actual.X, x), true)
    @Expect(closeTo(actual.Y, y), true)
    @Expect(closeTo(actual.Z, z), true)
    @Expect(closeTo(actual.W, w), true)
}

@Test
func testVector4ConstructorsAndArithmetic() {
    let a = vector4(1.0f32, 2.0f32, 3.0f32, 4.0f32)
    let b = vector4(2.0f32, 0.5f32, 1.0f32, 0.0f32)

    expectVector4(zeroVector4(), 0.0f32, 0.0f32, 0.0f32, 0.0f32)
    expectVector4(oneVector4(), 1.0f32, 1.0f32, 1.0f32, 1.0f32)
    expectVector4(unitXVector4(), 1.0f32, 0.0f32, 0.0f32, 0.0f32)
    expectVector4(unitYVector4(), 0.0f32, 1.0f32, 0.0f32, 0.0f32)
    expectVector4(unitZVector4(), 0.0f32, 0.0f32, 1.0f32, 0.0f32)
    expectVector4(unitWVector4(), 0.0f32, 0.0f32, 0.0f32, 1.0f32)
    expectVector4(add(a, b), 3.0f32, 2.5f32, 4.0f32, 4.0f32)
    expectVector4(subtract(a, b), -1.0f32, 1.5f32, 2.0f32, 4.0f32)
    expectVector4(negate(a), -1.0f32, -2.0f32, -3.0f32, -4.0f32)
    expectVector4(multiply(a, 2.0f32), 2.0f32, 4.0f32, 6.0f32, 8.0f32)
    expectVector4(divide(a, 2.0f32), 0.5f32, 1.0f32, 1.5f32, 2.0f32)
    @Expect(equal(a, vector4(1.0f32, 2.0f32, 3.0f32, 4.0f32)), true)
    @Expect(equal(a, b), false)
}

@Test
func testVector4MathHelpers() {
    let value = vector4(1.0f32, 2.0f32, 2.0f32, 0.0f32)

    @Expect(closeTo(dot(value, vector4(2.0f32, 3.0f32, 1.0f32, 4.0f32)), 10.0f32), true)
    @Expect(closeTo(lengthSquared(value), 9.0f32), true)
    @Expect(closeTo(length(value), 3.0f32), true)
    expectVector4(normalize(vector4(2.0f32, 0.0f32, 0.0f32, 0.0f32)), 1.0f32, 0.0f32, 0.0f32, 0.0f32)
    expectVector4(min(vector4(1.0f32, 5.0f32, 3.0f32, 7.0f32), vector4(2.0f32, 4.0f32, 1.0f32, 8.0f32)),
        1.0f32, 4.0f32, 1.0f32, 7.0f32)
    expectVector4(max(vector4(1.0f32, 5.0f32, 3.0f32, 7.0f32), vector4(2.0f32, 4.0f32, 1.0f32, 8.0f32)),
        2.0f32, 5.0f32, 3.0f32, 8.0f32)
    expectVector4(lerp(zeroVector4(), vector4(4.0f32, 8.0f32, 12.0f32, 16.0f32), 0.25f32),
        1.0f32, 2.0f32, 3.0f32, 4.0f32)
}

@Test
func testMatrix3x2BasicConstructors() {
    let id = identityMatrix3x2()
    let t = translationMatrix3x2(3.0f32, 4.0f32)
    let s = scaleMatrix3x2(2.0f32, 5.0f32)
    let composed = multiply(t, s)

    @Expect(isIdentity(id), true)
    @Expect(equal(translation(t), vector2(3.0f32, 4.0f32)), true)
    expectMatrixCell(composed.M11, 2.0f32)
    expectMatrixCell(composed.M22, 5.0f32)
    expectMatrixCell(composed.M31, 6.0f32)
    expectMatrixCell(composed.M32, 20.0f32)
    expectMatrixCell(multiply(id, 3.0f32).M11, 3.0f32)
}

@Test
func testMatrix3x2RotationAndSkew() {
    let rot = rotationMatrix3x2(90.0f32)
    let skew = skewMatrix3x2(45.0f32, 0.0f32)

    expectMatrixCell(rot.M11, 0.0f32)
    expectMatrixCell(rot.M12, 1.0f32)
    expectMatrixCell(rot.M21, -1.0f32)
    expectMatrixCell(rot.M22, 0.0f32)
    expectMatrixCell(skew.M21, 1.0f32)
    expectMatrixCell(skew.M12, 0.0f32)
}

@Test
func testMatrix4x4TransposeRotationProjectionAndTransform() {
    let value = matrix4x4(
        1.0f32, 2.0f32, 3.0f32, 4.0f32,
        5.0f32, 6.0f32, 7.0f32, 8.0f32,
        9.0f32, 10.0f32, 11.0f32, 12.0f32,
        13.0f32, 14.0f32, 15.0f32, 16.0f32
    )
    let transposed = transpose(value)
    let rotation = rotationYMatrix4x4(90.0f32)
    let projection = perspectiveProjectionMatrix4x4(2.0f32)
    let transformed = transform(vector3(4.0f32, 5.0f32, 6.0f32), translationMatrix4x4(1.0f32, 2.0f32, 3.0f32))

    expectMatrixCell(transposed.M12, 5.0f32)
    expectMatrixCell(transposed.M21, 2.0f32)
    expectMatrixCell(rotation.M11, 0.0f32)
    expectMatrixCell(rotation.M13, -1.0f32)
    expectMatrixCell(rotation.M31, 1.0f32)
    expectMatrixCell(rotation.M33, 0.0f32)
    expectMatrixCell(projection.M34, -0.5f32)
    expectVector3(transformed, 5.0f32, 7.0f32, 9.0f32)
}
