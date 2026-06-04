package windows_canvas

import windows_numerics.Vector2

import windows_canvas_bindings.Win32.Graphics.Direct2D.{
    ID2D1PathGeometry1,
    ID2D1GeometrySink,
    ID2D1Factory1Vtbl,
    ID2D1PathGeometry1Vtbl,
    ID2D1GeometrySinkVtbl
}
import windows_canvas_bindings.Win32.Graphics.Direct2D.Common.D2D1_BEZIER_SEGMENT

import windows_core.HRESULT

// D2D figure-begin / figure-end flags (not surfaced by the facade).
const D2D1_FIGURE_BEGIN_FILLED: Int32 = 0
const D2D1_FIGURE_BEGIN_HOLLOW: Int32 = 1
const D2D1_FIGURE_END_OPEN: Int32 = 0
const D2D1_FIGURE_END_CLOSED: Int32 = 1

// A completed path geometry, ready for drawing or filling.
//
// Created via `PathBuilder`.
public class Path {
    let inner: ID2D1PathGeometry1

    init(inner: ID2D1PathGeometry1) {
        this.inner = inner
    }

    // Access the raw `ID2D1PathGeometry1`.
    func asRaw(): CPointer<Unit> {
        return this.inner.asRaw()
    }
}

// Path builder using D2D geometry sinks.
//
// Cangjie paradigm note (equivalent): the reference encodes the figure state in
// the type (typestate `Empty`/`InFigure`) so misuse is a compile error. Cangjie
// models the same invariants with a run-time `inFigure` flag: starting a figure
// while one is open, adding segments outside a figure, or building with a figure
// still open each throw. The Direct2D call sequence is identical.
public class PathBuilder {
    let sink: ID2D1GeometrySink
    let geometry: ID2D1PathGeometry1
    var inFigure: Bool = false
    var built: Bool = false

    private init(sink: ID2D1GeometrySink, geometry: ID2D1PathGeometry1) {
        this.sink = sink
        this.geometry = geometry
    }

    // Create a new path builder from a device's D2D factory.
    public static func create(device: GpuDevice): PathBuilder {
        let factoryRaw = device.d2dFactoryRaw()
        // geometry = factory.CreatePathGeometry().
        var geometryRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1Factory1Vtbl>>(factoryRaw).read().read()
            // CreatePathGeometry lives on ID2D1Factory (the base of Factory1).
            let hr = vtbl.base_.CreatePathGeometry(
                factoryRaw,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout geometryRaw))
            )
            HRESULT(hr).check()
        }
        let geometry = ID2D1PathGeometry1(geometryRaw, takeOwnership: true)

        // sink = geometry.Open().
        var sinkRaw = CPointer<Unit>()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1PathGeometry1Vtbl>>(geometryRaw).read().read()
            // Open lives on ID2D1PathGeometry (the base of PathGeometry1).
            let hr = vtbl.base_.Open(
                geometryRaw,
                CPointer<Unit>(CPointer<CPointer<Unit>>(inout sinkRaw))
            )
            HRESULT(hr).check()
        }
        let sink = ID2D1GeometrySink(sinkRaw, takeOwnership: true)
        return PathBuilder(sink, geometry)
    }

    // Begin a filled figure at the given start point.
    public func begin(start: Vector2): PathBuilder {
        this.beginFigure(start, D2D1_FIGURE_BEGIN_FILLED)
        return this
    }

    // Begin a hollow (stroke-only) figure at the given start point.
    public func beginHollow(start: Vector2): PathBuilder {
        this.beginFigure(start, D2D1_FIGURE_BEGIN_HOLLOW)
        return this
    }

    private func beginFigure(start: Vector2, figureBegin: Int32): Unit {
        if (this.inFigure) {
            throw Exception("PathBuilder: a figure is already open")
        }
        let raw = this.sink.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1GeometrySinkVtbl>>(raw).read().read()
            // BeginFigure lives on ID2D1SimplifiedGeometrySink (the sink base).
            vtbl.base_.BeginFigure(raw, toProjectedVector2(start), figureBegin)
        }
        this.inFigure = true
    }

    // Add a line segment to the given point.
    public func lineTo(point: Vector2): PathBuilder {
        if (!this.inFigure) {
            throw Exception("PathBuilder: no figure is open")
        }
        let raw = this.sink.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1GeometrySinkVtbl>>(raw).read().read()
            vtbl.AddLine(raw, toProjectedVector2(point))
        }
        return this
    }

    // Add a cubic bezier curve.
    public func bezierTo(control1: Vector2, control2: Vector2, end: Vector2): PathBuilder {
        if (!this.inFigure) {
            throw Exception("PathBuilder: no figure is open")
        }
        var segment = D2D1_BEZIER_SEGMENT()
        segment.point1 = toProjectedVector2(control1)
        segment.point2 = toProjectedVector2(control2)
        segment.point3 = toProjectedVector2(end)
        let raw = this.sink.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1GeometrySinkVtbl>>(raw).read().read()
            vtbl.AddBezier(raw, CPointer<Unit>(CPointer<D2D1_BEZIER_SEGMENT>(inout segment)))
        }
        return this
    }

    // Close the current figure (connects back to the start point).
    public func close(): PathBuilder {
        this.endFigure(D2D1_FIGURE_END_CLOSED)
        return this
    }

    // End the current figure without closing (open-ended stroke).
    public func endOpen(): PathBuilder {
        this.endFigure(D2D1_FIGURE_END_OPEN)
        return this
    }

    private func endFigure(figureEnd: Int32): Unit {
        if (!this.inFigure) {
            throw Exception("PathBuilder: no figure is open")
        }
        let raw = this.sink.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1GeometrySinkVtbl>>(raw).read().read()
            vtbl.base_.EndFigure(raw, figureEnd)
        }
        this.inFigure = false
    }

    // Finalize the path geometry. All figures must be closed before calling this.
    public func build(): Path {
        if (this.inFigure) {
            throw Exception("PathBuilder: a figure is still open")
        }
        if (this.built) {
            throw Exception("PathBuilder: already built")
        }
        let raw = this.sink.asRaw()
        unsafe {
            let vtbl = CPointer<CPointer<ID2D1GeometrySinkVtbl>>(raw).read().read()
            let hr = vtbl.base_.Close(raw)
            HRESULT(hr).check()
        }
        this.built = true
        return Path(this.geometry)
    }
}
