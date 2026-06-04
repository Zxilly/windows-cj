package windows_canvas

// windows_canvas - a Windows 2D graphics library over Direct2D, Direct3D11,
// DXGI, DirectWrite and WIC.
//
// The public surface is defined across the sibling files in this package
// (Cangjie makes same-package declarations visible without re-import):
//
//   color.cj       - ColorF
//   types.cj       - Rect, Ellipse, RoundedRect, GradientStop, Paint,
//                    Brush, LinearGradient, RadialGradient,
//                    CapStyle, LineJoin, DashStyle,
//                    StrokeStyle, StrokeStyleBuilder
//   device.cj      - GpuDevice
//   device_lost.cj - device-lost HRESULT detection (internal)
//   swap_chain.cj  - SwapChain
//   session.cj     - DrawingSession
//   bitmap.cj      - Bitmap
//   geometry.cj    - Path, PathBuilder
//   text.cj        - FontWeight, TextAlignment, ParagraphAlignment, TextFormat
//
// The affine math types used throughout the drawing API are re-exported from
// windows_numerics so callers depend only on this package.
public import windows_numerics.{Matrix3x2, Vector2}

// HRESULT-based error handling is surfaced through windows_core (methods throw
// a WindowsException on COM failure, mirroring the reference's Result-returning
// API at the behaviour level).
public import windows_core.{HRESULT, GUID}
