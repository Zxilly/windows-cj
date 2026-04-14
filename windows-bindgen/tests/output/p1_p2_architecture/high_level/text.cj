package Windows.Data.Text

import std.collection.*
import windows_core.*
import windows_interface.*
import Windows.Win32.Foundation as Win32_Foundation
import Windows.Win32.Foundation.*


@When[Windows_Data_Text == "on"]
@C
public struct TextSegment {
    public var StartPosition: UInt32 = 0
    public var Length: UInt32 = 0
    public init() {}
}
