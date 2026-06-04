package windows_canvas

import windows_canvas_bindings.Win32.Graphics.Direct2D.Common.D2D1_COLOR_F

// An RGBA color with f32 components in the 0.0-1.0 range.
//
// This is the floating-point color representation used by Direct2D
// (`D2D1_COLOR_F`).
//
// Cangjie paradigm note (equivalent): the reference exposes this as a value
// type with const constructors and const associated color constants. Cangjie
// has no const fn; `struct` is already a value type, and the named colors are
// surfaced as static factory functions on the type (same observable values).
public struct ColorF {
    public let r: Float32
    public let g: Float32
    public let b: Float32
    public let a: Float32

    // Create a color from floating-point RGBA (0.0-1.0).
    public init(r: Float32, g: Float32, b: Float32, a: Float32) {
        this.r = r
        this.g = g
        this.b = b
        this.a = a
    }

    // Create an opaque color from floating-point RGB.
    public static func rgb(r: Float32, g: Float32, b: Float32): ColorF {
        return ColorF(r, g, b, 1.0)
    }

    // Create a color from u8 RGBA (0-255).
    public static func fromRgba8(r: UInt8, g: UInt8, b: UInt8, a: UInt8): ColorF {
        return ColorF(
            Float32(r) / 255.0,
            Float32(g) / 255.0,
            Float32(b) / 255.0,
            Float32(a) / 255.0
        )
    }

    // Create an opaque color from u8 RGB (0-255).
    public static func fromRgb8(r: UInt8, g: UInt8, b: UInt8): ColorF {
        return ColorF.fromRgba8(r, g, b, 255)
    }

    public static func transparent(): ColorF {
        return ColorF(0.0, 0.0, 0.0, 0.0)
    }

    public static func black(): ColorF {
        return ColorF.rgb(0.0, 0.0, 0.0)
    }

    public static func white(): ColorF {
        return ColorF.rgb(1.0, 1.0, 1.0)
    }

    public static func red(): ColorF {
        return ColorF.rgb(1.0, 0.0, 0.0)
    }

    public static func green(): ColorF {
        return ColorF.rgb(0.0, 1.0, 0.0)
    }

    public static func blue(): ColorF {
        return ColorF.rgb(0.0, 0.0, 1.0)
    }

    public static func cornflowerBlue(): ColorF {
        return ColorF.rgb(0.392, 0.584, 0.929)
    }

    public static func darkSlateBlue(): ColorF {
        return ColorF.rgb(0.05, 0.05, 0.1)
    }

    // Convert to the Direct2D ABI color struct.
    func toAbi(): D2D1_COLOR_F {
        var c = D2D1_COLOR_F()
        c.r = this.r
        c.g = this.g
        c.b = this.b
        c.a = this.a
        return c
    }
}
