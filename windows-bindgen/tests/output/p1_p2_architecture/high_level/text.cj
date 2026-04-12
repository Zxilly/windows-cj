package windows.data.text

import std.collection.*
import windows_core.*
import windows_interface.*
import windows.win32.foundation.*


@When[feature == "feat_windows_data_text"]
@C
public struct TextSegment {
    public var StartPosition: UInt32 = 0
    public var Length: UInt32 = 0
    public init() {}
}
