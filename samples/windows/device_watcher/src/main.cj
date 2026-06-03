package windows_sample_device_watcher

import windows_sample_device_watcher_bindings.Devices.Enumeration.{DeviceInformation, DeviceWatcher}
import windows_sample_device_watcher_bindings.Foundation.TypedEventHandler
import windows_interface.IInspectable
import std.sync.*
import std.time.*

// ============================================================================
// device_watcher — behaviour-equivalent port of the reference sample.
//
// DeviceInformation.CreateWatcher() activates a DeviceWatcher; we register two
// WinRT event handlers on it — Added (fires once per enumerated device) and
// EnumerationCompleted (fires when the initial enumeration sweep finishes) —
// then Start() the watcher and sleep ~10 s so the asynchronous enumeration can
// run. The Added handler prints each device's Name; EnumerationCompleted prints
// "done!". The process then exits.
//
// Paradigm notes (Cangjie vs the reference language):
//   • A WinRT TypedEventHandler is a delegate — a COM object whose Invoke vtbl
//     slot calls back into managed code. The reference builds one from a Rust
//     closure; here TypedEventHandler<TSender, TResult>.new takes a Cangjie
//     closure and wraps it in a generated CCW (a ComObject with an Invoke
//     thunk). This is the exact same ABI: the runtime calls Invoke(this,
//     sender, args) and our closure runs. The closure receives the raw (sender,
//     args) ABI pointers rather than pre-projected wrappers, so we project the
//     args pointer ourselves when we need it.
//   • In the Added handler, `args` is the ABI pointer to the newly-found
//     DeviceInformation. DeviceInformation.viewOf wraps it WITHOUT taking
//     ownership — the WinRT runtime owns that pointer for the duration of the
//     callback (it is borrowed, not transferred), so we must not Release it.
//     The reference's `info.as_ref().expect("info")` is the same borrow: it
//     reads through the argument without consuming it.
//   • DeviceInformation.Name is projected as a `prop` returning an HString
//     (a UTF-16 WinRT string). HString implements ToString, so interpolating it
//     prints the device name directly. The reference debug-prints the HSTRING
//     (`{:?}`, i.e. quoted); we print the plain name, which is the same value.
//   • EnumerationCompleted's args are a bare IInspectable (no payload), matching
//     the generated TypedEventHandler<DeviceWatcher, IInspectable> signature;
//     the closure ignores both arguments and just prints "done!".
//   • DeviceInformation.CreateWatcher / addAdded / addEnumerationCompleted /
//     Start each run the ABI call and .check() the HRESULT internally, throwing
//     a WindowsException on failure — the Cangjie analogue of the reference's
//     `?`. An uncaught throw aborts with a non-zero exit; the happy path falls
//     through to `return 0`.
//   • The DeviceWatcher's COM lifetime is owned by its generated wrapper
//     (Resource); GC reclaims the wrapper after main returns. The registered
//     delegates are likewise kept alive by the watcher's native event source
//     and the GC for the duration of the run — no manual AddRef/Release.
// ============================================================================

main(): Int64 {
    // Activate the watcher over the default device set (CreateWatcher with no
    // filter), mirroring the reference's DeviceInformation::CreateWatcher().
    let watcher = DeviceInformation.CreateWatcher()

    // Register the Added handler. sender is the DeviceWatcher; args is the
    // DeviceInformation that was just enumerated. We view (non-owning) the args
    // pointer and print its Name.
    let added = TypedEventHandler<DeviceWatcher, DeviceInformation>.new({ _, args =>
        let info = DeviceInformation.viewOf(args)
        println(info.Name)
    })
    watcher.addAdded(added)

    // Register the EnumerationCompleted handler. Neither argument carries a
    // payload here, so the closure simply announces completion.
    let completed = TypedEventHandler<DeviceWatcher, IInspectable>.new({ _, _ =>
        println("done!")
    })
    watcher.addEnumerationCompleted(completed)

    // Begin asynchronous enumeration and give it time to run, exactly as the
    // reference does: Start() then sleep for 10 seconds.
    watcher.Start()
    sleep(Duration.second * 10)

    return 0
}
