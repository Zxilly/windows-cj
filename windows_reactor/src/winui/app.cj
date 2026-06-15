package windows_reactor.winui

import std.collection.ArrayList
import windows_reactor.core.{RenderHost, ComponentObject, ControlId, RenderCx, Element, rootComponent}

// Carrier-thread pinning, exported by the cjnative runtime (libcangjie-runtime).
// CJ_BindOSThread marries the current cjthread to its carrier OS thread 1:1 so it
// never migrates carriers; the WinUI UI thread must stay OS-thread-stable because
// WinUI/CoreMessaging state is thread-affine. (C symbol CJBindOSThread; Windows
// exports it under the CJ_ prefix.)
foreign func CJ_BindOSThread(): Int32

// ============================================================================
// App — process entry builder that wires the WinUI host to a reactor RenderHost
// and pumps the first render.
//
// Lifecycle (mirrors the reference ReactorHost + App::run):
//   1. STA apartment init + per-monitor DPI + cwd fixup (win32).
//   2. Windows App SDK bootstrap (appsdk).
//   3. ApplicationHost(onLaunched) drives the composed Application; the WinUI
//      runtime calls onLaunched on the UI thread.
//   4. In onLaunched: create the Window, build WinUIDispatcher (UI thread),
//      WinUIBackend + RenderHost, install the postRender hook that puts the
//      root UIElement into Window.Content, kick the first render, activate.
//   5. startApplication blocks running the WinUI message loop until exit.
// ============================================================================

public class App {
    private var titleValue: String = "Reactor"
    // Initial window inner size (logical px). Applied at launch via
    // WindowHandle.setInitialSize (AppWindow.Resize) when both dimensions are set.
    private var innerWidthValue: ?Float64 = None
    private var innerHeightValue: ?Float64 = None
    // Window backdrop material. Applied at launch via WindowHandle.setSystemBackdrop
    // (Mica/Acrylic activated by runtime name; None_ clears it).
    private var backdropValue: Backdrop = Backdrop.None_
    // Whether the reconciler should eagerly realize templated lists up front.
    private var eagerTemplatedValue: Bool = false

    public init() {}

    // Legacy explicit constructor: title + a prebuilt root ComponentObject.
    public init(title: String, root: ComponentObject) {
        this.titleValue = title
        this.rootValue = Some(root)
    }

    private var rootValue: ?ComponentObject = None

    // ── Fluent builder (mirrors App::new().title(..).inner_size(..)...) ──
    public static func new(): App { App() }

    public func title(t: String): App { this.titleValue = t; this }

    public func inner_size(width: Float64, height: Float64): App {
        this.innerWidthValue = Some(width)
        this.innerHeightValue = Some(height)
        this
    }

    public func backdrop(b: Backdrop): App { this.backdropValue = b; this }

    public func eager_templated_realization(v: Bool): App {
        this.eagerTemplatedValue = v
        this
    }

    // Set the root render closure and run the application to completion. Mirrors
    // App::render(component): the closure is the unit-prop root component.
    public func render(body: (RenderCx) -> Element): Unit {
        this.rootValue = Some(rootComponent(body))
        run()
    }

    // Run the application to completion (blocks on the WinUI message loop).
    public func run(): Unit {
        // Pin the UI cjthread to its carrier OS thread before establishing any
        // thread-affine state (STA apartment, DispatcherQueue, message loop). This
        // keeps GetCurrentThreadId stable for the app lifetime so WinUI/CoreMessaging
        // never see the UI work resume on a different OS thread (which fail-fasts
        // CoreMessagingXP, 0xe0464645). Background cjthreads still span other carriers.
        if (unsafe { CJ_BindOSThread() } != 0) {
            println("windows_reactor: CJ_BindOSThread failed; UI thread not pinned")
        }

        let title = titleValue
        let root = match (rootValue) {
            case Some(r) => r
            case None => throw Exception("App.run(): no root component (call .render(...) first)")
        }
        let _ = setProcessDpiAwarenessPerMonitorV2()
        let _ = setCurrentDirectoryToExecutableDirectory()
        appSdkInitializeOrThrow()
        let initHr = initializeApartmentThreaded()
        if (initHr.failed()) {
            throw Exception("CoInitializeEx(STA) failed: ${initHr}")
        }

        let capturedTitle = title
        let capturedRoot = root

        // The composed Application (ApplicationHost) MUST be created INSIDE the
        // ApplicationInitializationCallback that Application.Start invokes.
        // Application.Start establishes the WinUI dispatcher/UI thread and calls
        // this callback ON it; the Application (and the whole XAML composition
        // pipeline) has to be constructed on that thread. Creating it on the
        // caller thread before Start mis-threads composition — the HWND appears
        // but XAML never paints. (Mirrors the proven runtime-only host flow.)
        let hostCell = AppHostCell()
        try {
            let callback = ApplicationCallback({ =>
                let _ = activateApplicationManifestForCurrentThread()
                let host = ApplicationHost({ =>
                    launch(capturedTitle, capturedRoot)
                })
                hostCell.value = Some(host)
            })
            try {
                startApplication(callback)
            } finally {
                callback.close()
            }
        } finally {
            match (hostCell.value) {
                case Some(host) => host.close()
                case None => ()
            }
            appSdkShutdown()
            uninitializeApartment()
        }
    }

    // UI-thread launch: build the window, dispatcher, backend, render host.
    private func launch(title: String, root: ComponentObject): Unit {
        let window = WindowHandle.create()
        window.setTitle(title)

        // Register the active window so page-level code can switch the system
        // backdrop material at runtime via setBackdrop (reference ROOT_WINDOW).
        registerActiveWindow(window)

        // Apply the declarative window knobs (inner size + system backdrop) now
        // that the Window exists. Both are best-effort: setInitialSize resizes via
        // the AppWindow, setSystemBackdrop activates a Mica/Acrylic material (or
        // clears it for Backdrop.None_). Unsupported cases degrade to no-ops.
        match ((innerWidthValue, innerHeightValue)) {
            case (Some(w), Some(h)) => window.setInitialSize(w, h)
            case _ => ()
        }
        window.setSystemBackdrop(backdropValue)

        let dispatcher = WinUIDispatcher.forCurrentThread()
        let backend = WinUIBackend()
        let renderHost = RenderHost(backend, root, dispatcher)
        renderHost.setMarshaller(Some(dispatcher.marshaller()))
        // Plumb the declarative eager-realization knob into the reconciler so
        // templated lists (card grids, ListView/GridView) realize their rows up
        // front rather than staying empty without a scroll/virtualization driver.
        renderHost.setEagerTemplatedRealization(eagerTemplatedValue)

        // postRender: attach the (possibly new) root UIElement to the window.
        let lastAttached = LastAttachedCell()
        renderHost.setPostRender({ newId: ?ControlId =>
            match (newId) {
                case Some(rid) =>
                    if (!lastAttached.equalsTo(rid)) {
                        match (backend.uiElementRawOf(rid)) {
                            case Some(rawElement) =>
                                window.setContent(rawElement)
                                lastAttached.set(rid)

                                // Wire the custom TitleBar (if any) into the window
                                // caption / drag region on every root change. The
                                // mounted TitleBar is otherwise inert — its props
                                // apply but it never drives the window chrome, and
                                // SetPreferredHeightOption(Tall) is silently dropped
                                // unless ExtendsContentIntoTitleBar is already true.
                                // Mirrors the reference post_render find_titlebar
                                // block.
                                match (backend.titleBarUiElementRaw()) {
                                    case Some(tbRaw) =>
                                        window.setExtendsContentIntoTitleBar(true)
                                        window.setTitleBar(tbRaw)
                                    case None => ()
                                }
                            case None => ()
                        }
                    }
                case None => lastAttached.clear()
            }
        })

        // Render the first frame synchronously on this (UI) thread so the root
        // UIElement is materialized and attached to Window.Content BEFORE
        // Activate(), guaranteeing content is present for the first layout /
        // composition pass. Subsequent re-renders coalesce onto the dispatcher.
        renderHost.kickSync()
        window.activate()

        // Keep the window/backend/host alive for the process lifetime.
        retainHost(renderHost, window, backend)
    }
}

// Tracks the last root ControlId attached to the window so re-renders that
// produce the same root skip a redundant put_Content (mirrors the reference
// last_attached guard).
class LastAttachedCell {
    private var value: ?UInt32 = None
    public init() {}
    public func equalsTo(id: ControlId): Bool {
        match (value) {
            case Some(v) => v == id.raw
            case None => false
        }
    }
    public func set(id: ControlId): Unit { value = Some(id.raw) }
    public func clear(): Unit { value = None }
}

// Heap cell holding the composed ApplicationHost created inside the Start
// callback, so App.run's outer cleanup can close it after the loop exits.
class AppHostCell {
    var value: ?ApplicationHost = None
    public init() {}
}

// Pin the live host graph so GC does not collect the RenderHost / Window /
// backend while the WinUI message loop is still pumping renders into them.
var retainedHosts = ArrayList<Object>()

func retainHost(host: RenderHost, window: WindowHandle, backend: WinUIBackend): Unit {
    retainedHosts.add(host)
    retainedHosts.add(window)
    retainedHosts.add(backend)
}
