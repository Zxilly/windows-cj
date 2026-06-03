package reactor_p3_smoke

import std.collection.*
import std.env.getVariables
import windows_reactor.core.{
    RenderCx,
    Element,
    ControlId,
    RenderHost,
    rootComponent,
    button,
    text_block,
    StackPanel,
    Brush,
    Color,
    check_box,
    toggle_switch,
    slider,
    text_box,
    border
}
import windows_reactor.winui.{
    WinUIBackend,
    WinUIDispatcher,
    WindowHandle,
    ApplicationHost,
    ApplicationCallback,
    startApplication,
    initializeApartmentThreaded,
    uninitializeApartment,
    setProcessDpiAwarenessPerMonitorV2,
    setCurrentDirectoryToExecutableDirectory,
    appSdkInitializeOrThrow,
    appSdkShutdown,
    installXamlControlsResources
}

// ============================================================================
// reactor_p3_smoke — minimal end-to-end smoke test of the reactor pipeline:
//   reconciler -> WinUIBackend -> real WinUI controls, with hooks re-render.
//
// This binary inlines the WinUI host launch (instead of the App wrapper) so it
// can log every lifecycle step and surface any exception thrown during the
// dispatcher-driven render/reconcile — which the DispatcherQueueHandler invoker
// would otherwise swallow into an HRESULT.
//
// Component: a vertical StackPanel of a TextBlock ("count: <n>") and a Button
// ("increment") whose Click bumps a useState<Int64> counter, driving a
// re-render that re-emits the TextBlock text in place.
// ============================================================================

// Pin the live host graph so GC does not collect it while the message loop runs.
var retained = ArrayList<Object>()

// True when the named environment variable is present and not "0"/"".
func envFlag(name: String): Bool {
    for ((k, v) in getVariables()) {
        if (k == name) {
            return v != "" && v != "0"
        }
    }
    false
}

// Reference cell: closures cannot reassign a captured local `var`, so the
// last-attached root id lives in a heap cell the postRender closure mutates.
class AttachedCell {
    var value: ?UInt32 = None
    public init() {}
}

main(): Int64 {
    eprintln("[p3] main entered")

    // Diagnostic toggle: P3_ROOT_TEXTBLOCK=1 renders a bare TextBlock root
    // (default-activated via TextBlock.new(), the non-composable path) to isolate
    // whether the StackPanel/Button composable CreateInstance path is what fails
    // to paint. Default mode renders the full StackPanel counter.
    let rootTextBlockOnly = envFlag("P3_ROOT_TEXTBLOCK")
    eprintln("[p3] rootTextBlockOnly=${rootTextBlockOnly}")

    let root = rootComponent({ cx: RenderCx =>
        let (count, setCount) = cx.useState<Int64>(0)
        let (checked, setChecked) = cx.useState<Bool>(true)
        eprintln("[p3] render closure count=${count} checked=${checked}")
        // Explicit colours so the content is unambiguously visible (not
        // white-on-white): a light-grey panel background and near-black text.
        let darkText = Brush.solid(Color.rgb(16u8, 16u8, 16u8))
        let panelBg = Brush.solid(Color.rgb(230u8, 230u8, 230u8))
        if (rootTextBlockOnly) {
            return text_block("count: ${count}").fontSize(28.0).foreground(darkText).toElement()
        }
        let label = text_block("count: ${count}").fontSize(28.0).foreground(darkText)
        let incrementButton = button("increment").onClick({ => setCount.call(count + 1) })

        // ── P4b multi-control showcase: validates create + setProp across new
        // control families (Border/CheckBox/ToggleSwitch/Slider/TextBox). The
        // CheckBox is a CONTROLLED component — its onChanged (a CheckedChanged
        // event, NOT a Click) drives useState, which re-renders the status
        // TextBlock below. This validates the non-Click event → hook → reconcile
        // round-trip end to end.
        let cardBg = Brush.solid(Color.rgb(200u8, 220u8, 245u8))
        let card = border(text_block("P4b widget showcase").fontSize(18.0).foreground(darkText).toElement())
            .background(cardBg)
            .cornerRadius(8.0)
        let statusLabel = if (checked) { "feature: ON" } else { "feature: OFF" }
        let status = text_block(statusLabel).fontSize(18.0).foreground(darkText)
        let check = check_box(checked).label("enable feature").onChanged({ b: Bool => setChecked.call(b) })
        let toggle = toggle_switch(true)
        let level = slider(42.0)
        let entry = text_box("").placeholder("type something here")

        let panel = StackPanel.verticalPanel()
        panel.spacing(16.0)
        panel.background(panelBg)
        panel.childrenValue = [
            label.toElement(),
            incrementButton.toElement(),
            card.toElement(),
            check.toElement(),
            status.toElement(),
            toggle.toElement(),
            level.toElement(),
            entry.toElement()
        ]
        panel.toElement()
    })

    eprintln("[p3] process bootstrap (DPI/cwd/STA/AppSDK)")
    let _ = setProcessDpiAwarenessPerMonitorV2()
    let _ = setCurrentDirectoryToExecutableDirectory()
    let initHr = initializeApartmentThreaded()
    if (initHr.failed()) {
        eprintln("[p3] CoInitializeEx(STA) failed: ${initHr}")
        return 1
    }
    appSdkInitializeOrThrow()
    eprintln("[p3] AppSDK initialized; building composed Application host")

    // The composed Application (ApplicationHost) MUST be created INSIDE the
    // ApplicationInitializationCallback that Application.Start invokes — Start
    // spins up the WinUI dispatcher/UI thread and calls this callback ON it, and
    // the Application (and thus the whole XAML composition pipeline) has to be
    // constructed on that thread. Creating it on the main thread before Start
    // mis-threads composition: the HWND appears but XAML never paints (blank
    // client area). The onLaunched body below runs on the UI thread once the
    // Application launches.
    let onLaunched: () -> Unit = { =>
        eprintln("[p3] OnLaunched entered (UI thread)")
        try {
            // NOTE: the WinUI host (applicationOverridesOnLaunched) already merges
            // XamlControlsResources into Application.Resources before this handler
            // runs. Calling installXamlControlsResources() again here would append
            // a SECOND XamlControlsResources to MergedDictionaries, which corrupts
            // the theme dictionary lookup and strips controls of their default
            // styles/templates (button chrome + theme-brush foregrounds vanish),
            // rendering the client area blank. So we do NOT install it here.
            eprintln("[p3] (XamlControlsResources already installed by host)")

            let window = WindowHandle.create()
            eprintln("[p3] window created")
            window.setTitle("Reactor P3 Counter")

            let dispatcher = WinUIDispatcher.forCurrentThread()
            eprintln("[p3] dispatcher captured")
            let backend = WinUIBackend()
            let renderHost = RenderHost(backend, root, dispatcher)
            renderHost.setMarshaller(Some(dispatcher.marshaller()))

            let lastAttached = AttachedCell()
            renderHost.setPostRender({ newId: ?ControlId =>
                eprintln("[p3] postRender fired; rootId present=${newId.isSome()}")
                match (newId) {
                    case Some(rid) =>
                        let same = match (lastAttached.value) { case Some(v) => v == rid.raw; case None => false }
                        if (!same) {
                            match (backend.uiElementRawOf(rid)) {
                                case Some(rawElement) =>
                                    eprintln("[p3] attaching root UIElement #${rid.raw} as Window.Content")
                                    try {
                                        window.setContent(rawElement)
                                        lastAttached.value = Some(rid.raw)
                                        eprintln("[p3] Window.Content set OK")
                                    } catch (e: Exception) {
                                        eprintln("[p3] setContent threw: ${e}")
                                    }
                                case None => eprintln("[p3] uiElementRawOf returned None for #${rid.raw}")
                            }
                        }
                    case None => eprintln("[p3] postRender newId=None")
                }
            })

            eprintln("[p3] kicking first render (synchronous, before activate)")
            try {
                renderHost.kickSync()
                eprintln("[p3] kickSync returned; rootId=${renderHost.rootIdValue().isSome()}")
            } catch (e: Exception) {
                eprintln("[p3] kickSync threw: ${e}")
            }
            // Diagnostic readback (H3): confirm props/children landed on the COM
            // objects after the synchronous first render.
            match (renderHost.rootIdValue()) {
                case Some(rid) =>
                    eprintln("[p3] root #${rid.raw} -> ${backend.debugDescribe(rid)}")
                case None => eprintln("[p3] no rootId after kickSync")
            }
            window.activate()
            eprintln("[p3] window activated")

            retained.add(renderHost)
            retained.add(window)
            retained.add(backend)
        } catch (e: Exception) {
            eprintln("[p3] OnLaunched threw: ${e}")
        }
    }

    eprintln("[p3] starting application message loop")
    var exit: Int64 = 0
    // Create the ApplicationHost (composed Application) inside the Start callback
    // so it lands on the UI thread Start establishes. Pin it so GC keeps it alive
    // for the message-loop lifetime; close it after the loop returns.
    let hostCell = HostCell()
    try {
        let callback = ApplicationCallback({ =>
            eprintln("[p3] ApplicationInitializationCallback (UI thread): creating ApplicationHost")
            let host = ApplicationHost(onLaunched)
            hostCell.value = Some(host)
            retained.add(host)
        })
        try {
            startApplication(callback)
        } finally {
            callback.close()
        }
    } catch (e: Exception) {
        eprintln("[p3] startApplication threw: ${e}")
        exit = 1
    } finally {
        match (hostCell.value) {
            case Some(h) => h.close()
            case None => ()
        }
        appSdkShutdown()
        uninitializeApartment()
    }
    eprintln("[p3] message loop exited")
    return exit
}

// Heap cell holding the composed ApplicationHost created inside the Start
// callback, so the outer cleanup can close it after the message loop exits.
class HostCell {
    var value: ?ApplicationHost = None
    public init() {}
}
