package windows_reactor.winui

import windows_core.GUID

// Hand-maintained WinUI interop metadata that is not represented by the
// bundled Windows.Win32 metadata set. The Windows.Win32.System.WinRT.Xaml
// ISwapChainPanelNative projection belongs to the Windows.UI.Xaml/UWP family;
// WinUI 3's Microsoft.UI.Xaml SwapChainPanel uses the same SetSwapChain ABI
// shape but answers QueryInterface for this Microsoft.UI.Xaml native IID.
public let IID_WINUI3_ISWAPCHAINPANEL_NATIVE = GUID.from_values(
    0x63aad0b8u32, 0x7c24u16, 0x40ffu16, 0x85u8, 0xa8u8, 0x64u8, 0x0du8, 0x94u8, 0x4cu8, 0xc3u8, 0x25u8)
