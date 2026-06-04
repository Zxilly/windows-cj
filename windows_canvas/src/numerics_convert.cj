package windows_canvas

import windows_numerics.{Vector2, Matrix3x2}
import windows_canvas_bindings.Foundation.Numerics.{Vector2 as ProjectedVector2, Matrix3x2 as ProjectedMatrix3x2}

// The drawing facade and the binding's projected ABI both define a
// `Foundation.Numerics.Vector2` / `Matrix3x2` with the identical f32 layout,
// but they are distinct nominal types to the type checker. The public canvas
// API speaks `windows_numerics`'s types; these helpers translate to the
// projected types the generated D2D vtables expect at the ABI boundary. The
// memory layout is the same, so this is a pure field copy (no reinterpretation).

func toProjectedVector2(v: Vector2): ProjectedVector2 {
    var p = ProjectedVector2()
    p.X = v.X
    p.Y = v.Y
    return p
}

func toProjectedMatrix3x2(m: Matrix3x2): ProjectedMatrix3x2 {
    var p = ProjectedMatrix3x2()
    p.M11 = m.M11
    p.M12 = m.M12
    p.M21 = m.M21
    p.M22 = m.M22
    p.M31 = m.M31
    p.M32 = m.M32
    return p
}

func fromProjectedMatrix3x2(p: ProjectedMatrix3x2): Matrix3x2 {
    var m = Matrix3x2()
    m.M11 = p.M11
    m.M12 = p.M12
    m.M21 = p.M21
    m.M22 = p.M22
    m.M31 = p.M31
    m.M32 = p.M32
    return m
}
