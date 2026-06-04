package windows_reactor.core

// ============================================================================
// Widget — adapter implemented by every built-in widget class so the
// reconciler can drive backend prop / child operations uniformly. The no-arg
// accessors that have a sensible fallback carry interface default bodies
// (verified available in P2 probe). The builder chain methods (.fontSize(),
// .gridRow(), ...) live on each widget CLASS, not on this interface, because
// `This` returns are not allowed in interface methods.
// ============================================================================

// ============================================================================
// NativeElement — backend-neutral opaque handle to a mounted control's
// underlying platform element. The core layer is intentionally decoupled from
// any WinRT / COM types (it depends only on std + windows_time), so this type
// carries the platform element address as a plain UIntNative token rather than
// a CPointer<Unit> / IInspectable. The winui layer produces it from a live
// control's raw IUIElement pointer (CPointer.toUIntNative) and reconstitutes it
// for interop (CPointer<Unit>(token)).
//
// Behaviour-equivalent to the reference, where the on-mounted callback receives
// a `windows_core::IInspectable` directly; here the WinRT-typed view is rebuilt
// in the winui layer (see winui/swap_chain.cj `SwapChainPanelHandle`) so core
// stays backend-agnostic. The token is opaque and non-owning: the live control
// (kept alive by the backend's Handle map) owns the underlying COM ref.
public struct NativeElement {
    public let raw: UIntNative
    public init(raw: UIntNative) { this.raw = raw }
    // True when this token refers to no element (a null platform pointer).
    public func isNull(): Bool { raw == 0 }
}

public interface Widget {
    func kind(): ControlKind
    func key(): ?String
    func modifiers(): Modifiers
    func bindings(): PropBindings

    func children(): Children { Children.NoneCh }
    func headerElement(): ?Element { None }
    func paneElement(): ?Element { None }
    // Callback invoked once, immediately after the native control is created and
    // its children/header/pane are mounted, receiving the control's opaque
    // NativeElement token. Default None (no current widget needs it). The
    // SwapChainPanel widget overrides this to hand its native element to user
    // code (e.g. to attach a DXGI swap chain). Mirrors the reference
    // Widget::on_mounted_callback.
    func onMountedCallback(): ?Callback<NativeElement> { None }
    // Lower this widget to its Element variant. Also used by equivalent() to
    // recover the concrete widget type from a Widget reference (downcast via a
    // single match on the returned Element variant).
    func toElement(): Element
    func asConcreteElement(): ?Element
    // Replaces derive(PartialEq); compares against another widget of (assumed)
    // matching kind. Implementations downcast via kind/field comparison.
    func equivalent(other: Widget): Bool
}

// ============================================================================
// Children — how a widget exposes its children to the child reconciler.
// Decides which child-diff path runs.
// ============================================================================

public enum Children {
    | NoneCh
    | PositionalSingle(Element)
    | Keyed(Array<Element>)
    | Tabs(Array<TabItem>)
    | PivotItems(Array<PivotItem>)
}

// A single tab in a TabView. Content is an Element subtree.
public class TabItem {
    public var key: ?String = None
    public var header: String
    public var content: Element
    public var isClosable: ?Bool = None

    public init(header: String, content: Element) {
        this.header = header
        this.content = content
    }

    public func equivalent(other: TabItem): Bool {
        optStrEq(key, other.key) && header == other.header &&
        optBoolEq(isClosable, other.isClosable) &&
        elementEquivalent(content, other.content)
    }
}

// A single page in a Pivot. Content is an Element subtree.
public class PivotItem {
    public var key: ?String = None
    public var header: String
    public var content: Element

    public init(header: String, content: Element) {
        this.header = header
        this.content = content
    }

    public func equivalent(other: PivotItem): Bool {
        optStrEq(key, other.key) && header == other.header &&
        elementEquivalent(content, other.content)
    }
}
