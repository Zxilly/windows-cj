package windows_numerics

import std.math.*
import std.unittest.*
import std.unittest.testmacro.*

func expectNear(actual: Float32, expected: Float32, tolerance!: Float32 = 0.0001): Unit {
    @Expect(abs(actual - expected) <= tolerance, true)
}

func expectNaN(value: Float32): Unit {
    @Expect(value.isNaN(), true)
}

@Test
func testVectorSurface() {
    let value = Vector2Math.new(3.0, 4.0)
    let normalized = Vector2Math.normalize(value)
    let scaled = Vector2Math.mulScalar(value, 2.0)

    @Expect(Vector2Math.zero().X, 0.0)
    @Expect(Vector2Math.one().Y, 1.0)
    @Expect(Vector2Math.unitX().X, 1.0)
    @Expect(Vector2Math.unitY().Y, 1.0)
    @Expect(Vector2Math.add(Vector2Math.new(1.0, 2.0), Vector2Math.new(3.0, 5.0)).Y, 7.0)
    @Expect(Vector2Math.divScalar(scaled, 2.0).X, 3.0)
    @Expect(Vector2Math.dot(value, Vector2Math.new(1.0, 2.0)), 11.0)
    expectNear(Vector2Math.length(value), 5.0)
    expectNear(Vector2Math.length(normalized), 1.0)
}

@Test
func testVector3CrossAndVector4Helpers() {
    let left = Vector3Math.unitX()
    let up = Vector3Math.unitY()
    let cross = Vector3Math.cross(left, up)
    let vec4 = Vector4Math.new(1.0, 2.0, 3.0, 4.0)

    @Expect(cross.X, 0.0)
    @Expect(cross.Y, 0.0)
    @Expect(cross.Z, 1.0)
    @Expect(Vector3Math.sub(Vector3Math.one(), Vector3Math.unitZ()).Z, 0.0)
    @Expect(Vector4Math.unitW().W, 1.0)
    @Expect(Vector4Math.mulScalar(vec4, 2.0).Z, 6.0)
    expectNear(Vector4Math.length(Vector4Math.normalize(vec4)), 1.0)
}

@Test
func testNormalizePreservesDivideByLengthSemanticsForNearZeroInputs() {
    let tiny2 = Vector2Math.normalize(Vector2Math.new(0.000001, 0.0))
    let tiny3 = Vector3Math.normalize(Vector3Math.new(0.0, 0.000001, 0.0))
    let tiny4 = Vector4Math.normalize(Vector4Math.new(0.0, 0.0, 0.000001, 0.0))
    let zero2 = Vector2Math.normalize(Vector2Math.zero())
    let zero3 = Vector3Math.normalize(Vector3Math.zero())
    let zero4 = Vector4Math.normalize(Vector4Math.zero())

    expectNear(tiny2.X, 1.0)
    expectNear(tiny3.Y, 1.0)
    expectNear(tiny4.Z, 1.0)
    expectNaN(zero2.X)
    expectNaN(zero2.Y)
    expectNaN(zero3.X)
    expectNaN(zero3.Y)
    expectNaN(zero3.Z)
    expectNaN(zero4.X)
    expectNaN(zero4.Y)
    expectNaN(zero4.Z)
    expectNaN(zero4.W)
}

@Test
func testMatrixSurface() {
    let translation = Matrix3x2Math.translation(5.0, 7.0)
    let scaled = Matrix3x2Math.scaleAround(2.0, 3.0, Vector2Math.new(10.0, 20.0))
    let projection = Matrix4x4Math.perspectiveProjection(2.0)
    let transformed = Matrix4x4Math.mul(Matrix4x4Math.translation(1.0, 2.0, 3.0), Matrix4x4Math.identity())

    @Expect(Matrix3x2Math.identity().M11, 1.0)
    @Expect(translation.M31, 5.0)
    @Expect(translation.M32, 7.0)
    @Expect(scaled.M31, -10.0)
    @Expect(scaled.M32, -40.0)
    @Expect(projection.M34, -0.5)
    @Expect(transformed.M41, 1.0)
    @Expect(transformed.M42, 2.0)
    @Expect(transformed.M43, 3.0)
}

@Test
func testQuaternionPlaneAndRationalHelpers() {
    let quaternion = QuaternionMath.normalize(QuaternionMath.new(0.0, 0.0, 3.0, 4.0))
    let plane = PlaneMath.new(Vector3Math.unitZ(), -5.0)
    let rational = RationalMath.new(16u32, 9u32)

    expectNear(QuaternionMath.length(quaternion), 1.0)
    @Expect(QuaternionMath.identity().W, 1.0)
    @Expect(plane.Normal.Z, 1.0)
    @Expect(plane.D, -5.0)
    @Expect(rational.Numerator, 16u32)
    @Expect(rational.Denominator, 9u32)
}

@Test
func testQuaternionNormalizePreservesDivideByLengthSemanticsForNearZeroInputs() {
    let tiny = QuaternionMath.normalize(QuaternionMath.new(0.0, 0.0, 0.000001, 0.0))
    let zero = QuaternionMath.normalize(QuaternionMath.new(0.0, 0.0, 0.0, 0.0))

    expectNear(tiny.Z, 1.0)
    expectNaN(zero.X)
    expectNaN(zero.Y)
    expectNaN(zero.Z)
    expectNaN(zero.W)
}
