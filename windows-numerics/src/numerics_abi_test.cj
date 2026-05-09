package windows_numerics

import std.unittest.*
import std.unittest.testmacro.*

@Test
func testNumericsAbiRoundTrip() {
    let vector = Vector2Math.new(9.0, 4.0)
    let vectorAbi = Vector2.projectAbi(vector)
    let vectorProjected = Vector2.assumeInitRef(vectorAbi)
    let matrix = Matrix3x2Math.translation(3.0, 5.0)
    let matrixProjected = Matrix3x2.assumeInitRef(Matrix3x2.projectAbi(matrix))

    @Expect(vectorProjected.X, 9.0)
    @Expect(vectorProjected.Y, 4.0)
    @Expect(matrixProjected.M31, 3.0)
    @Expect(matrixProjected.M32, 5.0)
    @Expect(Vector2.signature(), "struct(Windows.Foundation.Numerics.Vector2;f4;f4)")
}
