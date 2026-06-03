package windows_reactor.winui

import windows_reactor.core.{ColorScheme, setCurrentColorScheme}

// ============================================================================
// Window backdrop material + app requested-theme surface.
//
// These mirror the declarative knobs the App builder exposes (backdrop material
// for the window, requested theme for the whole app). The window-size / material
// composition wiring is not yet plumbed through WindowHandle, so `Backdrop` is
// currently a declarative flag carried by the App builder; `RequestedTheme` /
// setRequestedTheme drive the per-UI-thread color scheme that useColorScheme
// observes, so a theme toggle re-renders the tree light↔dark (behaviour
// equivalent to flipping the app RequestedTheme).
// ============================================================================

// Window backdrop material. MicaAlt is the BaseAlt tint of Mica (a stronger
// desktop-tinted variant). None disables a system backdrop (plain surface).
public enum Backdrop <: Equatable<Backdrop> {
    | Mica | MicaAlt | Acrylic | None_

    public func tag(): Int64 {
        match (this) {
            case Mica => 0
            case MicaAlt => 1
            case Acrylic => 2
            case None_ => 3
        }
    }

    public operator func ==(other: Backdrop): Bool { tag() == other.tag() }
    public operator func !=(other: Backdrop): Bool { tag() != other.tag() }
}

// App-level requested theme. Default follows the system.
public enum RequestedTheme <: Equatable<RequestedTheme> {
    | Light | Dark | Default

    public func tag(): Int64 {
        match (this) {
            case Light => 0
            case Dark => 1
            case Default => 2
        }
    }

    public operator func ==(other: RequestedTheme): Bool { tag() == other.tag() }
    public operator func !=(other: RequestedTheme): Bool { tag() != other.tag() }
}

// Apply an app-level requested theme. Light/Dark set the current color scheme so
// the next render observes the new value through useColorScheme; Default leaves
// the current scheme in place (system-followed).
public func setRequestedTheme(theme: RequestedTheme): Unit {
    match (theme) {
        case Light => setCurrentColorScheme(ColorScheme.Light)
        case Dark => setCurrentColorScheme(ColorScheme.Dark)
        case Default => ()
    }
}

// ── Runtime backdrop switching ───────────────────────────────────────────────
// The active top-level window, registered once at launch so page-level code can
// switch the system backdrop material at runtime (reference host::ROOT_WINDOW
// thread_local). WindowHandle lives in the same winui package (host.cj).
var activeWindowHandle: ?WindowHandle = None

// Register the process's active window. Called once in App.launch after the
// window is created (on the UI thread).
public func registerActiveWindow(handle: WindowHandle): Unit {
    activeWindowHandle = Some(handle)
}

// Switch the active window's system backdrop material at runtime. No-op when no
// window is registered (e.g. headless). Must be called on the UI thread (render
// callbacks run there), mirroring the reference module-level set_backdrop.
public func setBackdrop(backdrop: Backdrop): Unit {
    match (activeWindowHandle) {
        case Some(h) => h.setSystemBackdrop(backdrop)
        case None => ()
    }
}

// Select the active window's custom title-bar height (Tall vs Standard). No-op
// when no window is registered (e.g. headless). Drives the TitleBarTall prop
// (TitleBar.tall(..)), mirroring the reference host::set_titlebar_height routed
// from the backend's Prop::TitleBarTall arm.
public func applyTitlebarHeight(tall: Bool): Unit {
    match (activeWindowHandle) {
        case Some(h) => h.setTitlebarHeight(tall)
        case None => ()
    }
}
