package windows_numerics

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testVectorDistanceAndComponentDivisionHelpers() {
    let left = Vector3Math.new(6.0, 9.0, 12.0)
    let right = Vector3Math.new(3.0, 3.0, 4.0)
    let divided = Vector3Math.div(left, right)

    @Expect(divided.X, 2.0)
    @Expect(divided.Y, 3.0)
    @Expect(divided.Z, 3.0)
    @Expect(Vector3Math.distanceSquared(left, right), 109.0)
}

@Test
func testMatrixPureHelpersPreserveTranslationAndProjectionEdge() {
    let translated = Matrix3x2Math.translation(2.0, 3.0)
    let scaled = Matrix3x2Math.scale(4.0, 5.0)
    let combined = Matrix3x2Math.mul(translated, scaled)
    let noDepth = Matrix4x4Math.perspectiveProjection(0.0)

    @Expect(combined.M11, 4.0)
    @Expect(combined.M22, 5.0)
    @Expect(combined.M31, 8.0)
    @Expect(combined.M32, 15.0)
    @Expect(noDepth.M34, 0.0)
}
