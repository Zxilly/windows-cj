package Windows.Foundation.Numerics

import std.collection.*
import windows_core.*
import windows_interface.*
import Windows.Win32.Foundation as Win32_Foundation
import Windows.Win32.Foundation.*


@When[Windows_Foundation_Numerics == "on"]
@C
public struct Matrix3x2 {
    public var M11: Float32 = 0.0
    public var M12: Float32 = 0.0
    public var M21: Float32 = 0.0
    public var M22: Float32 = 0.0
    public var M31: Float32 = 0.0
    public var M32: Float32 = 0.0
    public init() {}
}

@When[Windows_Foundation_Numerics == "on"]
@C
public struct Matrix4x4 {
    public var M11: Float32 = 0.0
    public var M12: Float32 = 0.0
    public var M13: Float32 = 0.0
    public var M14: Float32 = 0.0
    public var M21: Float32 = 0.0
    public var M22: Float32 = 0.0
    public var M23: Float32 = 0.0
    public var M24: Float32 = 0.0
    public var M31: Float32 = 0.0
    public var M32: Float32 = 0.0
    public var M33: Float32 = 0.0
    public var M34: Float32 = 0.0
    public var M41: Float32 = 0.0
    public var M42: Float32 = 0.0
    public var M43: Float32 = 0.0
    public var M44: Float32 = 0.0
    public init() {}
}

@When[Windows_Foundation_Numerics == "on"]
@C
public struct Plane {
    public var Normal: Vector3 = Vector3()
    public var D: Float32 = 0.0
    public init() {}
}

@When[Windows_Foundation_Numerics == "on"]
@C
public struct Quaternion {
    public var X: Float32 = 0.0
    public var Y: Float32 = 0.0
    public var Z: Float32 = 0.0
    public var W: Float32 = 0.0
    public init() {}
}

@When[Windows_Foundation_Numerics == "on"]
@C
public struct Rational {
    public var Numerator: UInt32 = 0
    public var Denominator: UInt32 = 0
    public init() {}
}

@When[Windows_Foundation_Numerics == "on"]
@C
public struct Vector2 {
    public var X: Float32 = 0.0
    public var Y: Float32 = 0.0
    public init() {}
}

@When[Windows_Foundation_Numerics == "on"]
@C
public struct Vector3 {
    public var X: Float32 = 0.0
    public var Y: Float32 = 0.0
    public var Z: Float32 = 0.0
    public init() {}
}

@When[Windows_Foundation_Numerics == "on"]
@C
public struct Vector4 {
    public var X: Float32 = 0.0
    public var Y: Float32 = 0.0
    public var Z: Float32 = 0.0
    public var W: Float32 = 0.0
    public init() {}
}
