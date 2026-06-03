package windows_reactor.winui

import windows_reactor.core.{Prop, PropValue, Brush}
import windows_common.Microsoft.UI.Xaml.Shapes.Shape

// Per-family property setters for vector shapes (Rectangle, Ellipse, Line).
// Returns true when the prop was consumed.
//
// Ported faithfully from the reactor winui backend set_prop arms for
// Handle::Rectangle / Handle::Ellipse / Handle::Line:
//   - Fill / Stroke / StrokeThickness live on the shared IShape surface for all
//     three shapes. The leaf projection classes only expose asIShape(); the
//     high-level setters live on the Shape class, so we QI the leaf's raw
//     identity to the Shape projection and assign the high-level property
//     (behaviourally identical to IShape::put_Fill / put_Stroke /
//     put_StrokeThickness).
//   - CornerRadius (Rectangle only) maps to RadiusX = RadiusY = v, exposed
//     directly on the Rectangle projection class. Unset restores 0.0.
//   - LineEndpoints (Line only) maps to X1/Y1/X2/Y2, exposed directly on the
//     Line projection class.
// (The Border CornerRadius arm is handled by the layout family, not here.)
func applyShapeProps(handle: Handle, which: Prop, value: PropValue): Bool {
    match (which) {
        case Fill => match ((handle, value)) {
            case (RectangleH(_), BrushV(b)) =>
                setShapeFillRaw(handle.asRaw(), b)
                true
            case (EllipseH(_), BrushV(b)) =>
                setShapeFillRaw(handle.asRaw(), b)
                true
            case _ => false
        }
        case Stroke => match ((handle, value)) {
            case (RectangleH(_), BrushV(b)) =>
                setShapeStrokeRaw(handle.asRaw(), b)
                true
            case (EllipseH(_), BrushV(b)) =>
                setShapeStrokeRaw(handle.asRaw(), b)
                true
            case (LineH(_), BrushV(b)) =>
                setShapeStrokeRaw(handle.asRaw(), b)
                true
            case _ => false
        }
        case StrokeThickness => match ((handle, value)) {
            case (RectangleH(_), F64(v)) =>
                setShapeStrokeThicknessRaw(handle.asRaw(), v)
                true
            case (EllipseH(_), F64(v)) =>
                setShapeStrokeThicknessRaw(handle.asRaw(), v)
                true
            case (LineH(_), F64(v)) =>
                setShapeStrokeThicknessRaw(handle.asRaw(), v)
                true
            case _ => false
        }
        case CornerRadius => match ((handle, value)) {
            case (RectangleH(r), F64(v)) =>
                r.RadiusX = v
                r.RadiusY = v
                true
            case (RectangleH(r), Unset) =>
                r.RadiusX = 0.0
                r.RadiusY = 0.0
                true
            case _ => false
        }
        case LineEndpoints => match ((handle, value)) {
            case (LineH(l), LineEndpointsV(p)) =>
                l.X1 = p.x1
                l.Y1 = p.y1
                l.X2 = p.x2
                l.Y2 = p.y2
                true
            case _ => false
        }
        case _ => false
    }
}

// QI the shape's raw identity to the high-level Shape projection (the IShape
// surface shared by Rectangle/Ellipse/Line) and assign Fill. The SolidColorBrush
// returned by solidBrush is GC-managed; the Shape wrapper holds its own COM ref
// and is released by close().
func setShapeFillRaw(raw: CPointer<Unit>, b: Brush): Unit {
    let shape = Shape.fromAbiTake(
        queryRequired(raw, Shape.iid(), "Microsoft.UI.Xaml.Shapes.IShape")
    )
    try {
        shape.Fill = solidBrush(b)
    } finally {
        shape.close()
    }
}

func setShapeStrokeRaw(raw: CPointer<Unit>, b: Brush): Unit {
    let shape = Shape.fromAbiTake(
        queryRequired(raw, Shape.iid(), "Microsoft.UI.Xaml.Shapes.IShape")
    )
    try {
        shape.Stroke = solidBrush(b)
    } finally {
        shape.close()
    }
}

func setShapeStrokeThicknessRaw(raw: CPointer<Unit>, v: Float64): Unit {
    let shape = Shape.fromAbiTake(
        queryRequired(raw, Shape.iid(), "Microsoft.UI.Xaml.Shapes.IShape")
    )
    try {
        shape.StrokeThickness = v
    } finally {
        shape.close()
    }
}
