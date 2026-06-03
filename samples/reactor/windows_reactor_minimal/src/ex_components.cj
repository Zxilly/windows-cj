package windows_reactor_minimal

import std.collection.ArrayList
import std.sync.*
import windows_reactor.core.*

// ============================================================================
// Group: components
//
// Examples owned by this group (filled into routeComponents):
//   component_props, function_component, render_fn, composition,
//   navigation, theme_brush, type_ramp
//
// Contract (see main.cj):
//   routeComponents(name) -> Some((windowTitle, body)) on a hit, else None.
//   namesComponents()     -> the example names this group owns, for the banner.
// ============================================================================

// ── Per-component type tokens (stable identity across re-renders) ────────────
// Cangjie has no TypeId::of::<C>(); component()/memo() take an explicit stable
// token minted once per component type at module scope (see component_element).
let componentPropsGreetingToken = newComponentTypeToken()
let fnComponentCounterToken = newComponentTypeToken()
let fnComponentGreetingToken = newComponentTypeToken()
let navHomePageToken = newComponentTypeToken()
let navDashboardPageToken = newComponentTypeToken()
let navSettingsPageToken = newComponentTypeToken()

// ============================================================================
// component_props — passing typed props to a child component.
// ============================================================================

// Typed props for the greeting child component. Equatable so the component's
// default shouldUpdate can compare props (== drives re-render skipping).
struct GreetingProps <: Equatable<GreetingProps> {
    let name: String
    let clicks: Int64

    init(name: String, clicks: Int64) {
        this.name = name
        this.clicks = clicks
    }

    public operator func ==(other: GreetingProps): Bool {
        name == other.name && clicks == other.clicks
    }

    public operator func !=(other: GreetingProps): Bool { !(this == other) }
}

// The greeting child component body: renders name + click count.
func greetingComponentBody(props: GreetingProps, _cx: RenderCx): Element {
    vstack([
        text_block("Hello, ${props.name}!").bold().fontSize(20.0).toElement(),
        text_block("You have clicked the button ${props.clicks} times.").toElement()
    ]).spacing(4.0).toElement()
}

func componentPropsExample(cx: RenderCx): Element {
    let (name, _setName) = cx.useState<String>("world")
    let (clicks, setClicks) = cx.useState<Int64>(0)

    vstack([
        title_bar("windows_reactor — component props").toElement(),
        component<GreetingProps>(
            greetingComponentBody,
            GreetingProps(name, clicks),
            componentPropsGreetingToken
        ),
        button("Click me").onClick({ => setClicks.call(clicks + 1) }).toElement()
    ])
        .spacing(12.0)
        .padding(Thickness.uniform(16.0))
        .toElement()
}

// ============================================================================
// function_component — composing function components.
// ============================================================================

// A function component with no props (uses NoProps as the unit-prop carrier).
func fnCounterBody(_props: NoProps, cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(0)

    vstack([
        text_block("count = ${count}").fontSize(24.0).bold().toElement(),
        button("Increment").onClick({ => setCount.call(count + 1) }).toElement()
    ]).spacing(8.0).toElement()
}

// A function component with typed props.
struct FnGreetingProps <: Equatable<FnGreetingProps> {
    let name: String

    init(name: String) { this.name = name }

    public operator func ==(other: FnGreetingProps): Bool { name == other.name }
    public operator func !=(other: FnGreetingProps): Bool { !(this == other) }
}

func fnGreetingBody(props: FnGreetingProps, _cx: RenderCx): Element {
    text_block("Hello, ${props.name}!").fontSize(20.0).bold().toElement()
}

func functionComponentExample(cx: RenderCx): Element {
    let (name, setName) = cx.useState<String>("world")

    vstack([
        component<FnGreetingProps>(
            fnGreetingBody,
            FnGreetingProps(name),
            fnComponentGreetingToken
        ),
        text_box(name)
            .header("Your name")
            .placeholder("Type a name…")
            .onChanged({ s: String => setName.call(s) })
            .toElement(),
        component<NoProps>(fnCounterBody, NoProps(), fnComponentCounterToken)
    ]).spacing(12.0).toElement()
}

// ============================================================================
// render_fn — the simplest app: just a render function with local state.
// ============================================================================

func renderFnExample(cx: RenderCx): Element {
    let (count, setCount) = cx.useState<Int64>(0)

    vstack([
        text_block("Count: ${count}").fontSize(24.0).bold().toElement(),
        hstack([
            button("-").onClick({ => setCount.call(count - 1) }).toElement(),
            button("+").onClick({ => setCount.call(count + 1) }).toElement()
        ]).spacing(8.0).toElement()
    ]).spacing(12.0).toElement()
}

// ============================================================================
// composition — Element.Group (fragments) + a CustomElement.
// ============================================================================

// A fragment that contributes two siblings (label + value) directly into the
// parent's child list, with no wrapping container (Element.Group).
func labeledRow(label: String, value: Element): Element {
    group([
        text_block(label).foreground(Brush.Solid(Color.rgb(120, 120, 120))).toElement(),
        value
    ])
}

// Stable per-custom-type identity for the BadgeButton custom element.
let badgeButtonTypeToken = newCustomTypeToken()

// Local ?String equality (the core util helper is package-private).
func optKeyEq(a: ?String, b: ?String): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x == y
        case (None, None) => true
        case _ => false
    }
}

// A user-defined custom widget: a Button whose content is "<label> (<count>)".
// Demonstrates the imperative extension hatch (mount / update / diff).
class BadgeButton <: CustomElement {
    let keyValue: ?String
    let label: String
    let count: Int64

    init(label: String, count: Int64) {
        this.keyValue = None
        this.label = label
        this.count = count
    }

    init(keyValue: ?String, label: String, count: Int64) {
        this.keyValue = keyValue
        this.label = label
        this.count = count
    }

    func rendered(): String { "${label} (${count})" }

    public func kindName(): String { "BadgeButton" }
    public func key(): ?String { keyValue }
    public func customTypeId(): UInt64 { badgeButtonTypeToken }

    public func mount(backend: Backend): ControlId {
        let id = backend.create(ControlKind.Button)
        backend.setProp(id, Prop.ButtonContent, PropValue.Str(rendered()))
        id
    }

    public func update(prev: CustomElement, id: ControlId, backend: Backend): Unit {
        match (prev) {
            case p: BadgeButton =>
                if (p.rendered() != rendered()) {
                    backend.setProp(id, Prop.ButtonContent, PropValue.Str(rendered()))
                }
            case _ =>
                backend.setProp(id, Prop.ButtonContent, PropValue.Str(rendered()))
        }
    }

    public func eqDyn(other: CustomElement): Bool {
        match (other) {
            case o: BadgeButton =>
                optKeyEq(keyValue, o.keyValue) && label == o.label && count == o.count
            case _ => false
        }
    }

    public func cloneDyn(): CustomElement {
        BadgeButton(keyValue, label, count)
    }

    func toElement(): Element { Element.CustomEl(this) }
}

func compositionExample(cx: RenderCx): Element {
    let (inboxCount, setInbox) = cx.useState<Int64>(3)
    let (draftsCount, setDrafts) = cx.useState<Int64>(1)

    vstack([
        title_bar("windows_reactor — composition sample")
            .subtitleOf("Group + CustomElement")
            .toElement(),
        text_block("Settings (LabeledRow uses Element::Group)")
            .bold()
            .fontSize(20.0)
            .toElement(),
        // Each labeledRow contributes two children directly into this vstack.
        vstack([
            labeledRow("Username", text_block("alice").toElement()),
            labeledRow("Theme", text_block("Dark").toElement()),
            labeledRow("Notifications", text_block("Enabled").toElement())
        ]).spacing(6.0).toElement(),
        text_block("Custom widgets (BadgeButton is a CustomElement)")
            .bold()
            .fontSize(20.0)
            .toElement(),
        hstack([
            BadgeButton("Inbox", inboxCount).toElement(),
            BadgeButton("Drafts", draftsCount).toElement(),
            button("+ Inbox").onClick({ => setInbox.call(inboxCount + 1) }).toElement(),
            button("+ Drafts").onClick({ => setDrafts.call(draftsCount + 1) }).toElement()
        ]).spacing(8.0).toElement()
    ])
        .spacing(12.0)
        .padding(Thickness.uniform(16.0))
        .toElement()
}

// ============================================================================
// navigation — multi-page routing driven by state + a NavigationView.
// ============================================================================

// Map a route tag to itself / a default; mirrors the reference Page tag/from_tag.
func navTagOf(tag: String): String {
    if (tag == "dashboard") {
        "dashboard"
    } else if (tag == "settings") {
        "settings"
    } else {
        "home"
    }
}

func navHomePageBody(_props: NoProps, _cx: RenderCx): Element {
    vstack([
        text_block("Welcome Home").fontSize(28.0).bold().toElement(),
        text_block("This is the landing page of the app.").toElement(),
        text_block("Use the navigation pane to switch between pages.").opacity(0.6).toElement()
    ]).spacing(8.0).toElement()
}

// Equatable wrapper around the fetched stat lines so it can back a Resource<T>
// (useResource requires T <: Equatable; raw Array<String> is not Equatable).
struct StatLines <: Equatable<StatLines> {
    let lines: Array<String>

    init(lines: Array<String>) { this.lines = lines }

    public operator func ==(other: StatLines): Bool {
        if (lines.size != other.lines.size) { return false }
        var i = 0
        while (i < lines.size) {
            if (lines[i] != other.lines[i]) { return false }
            i++
        }
        true
    }

    public operator func !=(other: StatLines): Bool { !(this == other) }
}

// Background fetch (runs off the UI thread inside useResource's worker).
func fetchStats(_deps: NoProps): FetchResult<StatLines> {
    sleep(500 * Duration.millisecond)
    FetchResult<StatLines>.Ok(StatLines([
        "Users online: 1,234",
        "CPU usage: 42%",
        "Memory: 8.2 / 16 GB",
        "Disk: 120 GB free"
    ]))
}

func navDashboardPageBody(_props: NoProps, cx: RenderCx): Element {
    let stats = cx.useResource<StatLines, NoProps>(fetchStats, NoProps())

    let content: Element = match (stats.data()) {
        case Some(s) =>
            let rows = ArrayList<Element>()
            for (line in s.lines) {
                rows.add(text_block(line).toElement())
            }
            vstack(rows.toArray()).spacing(4.0).toElement()
        case None =>
            if (stats.isLoading()) {
                text_block("Loading…").opacity(0.6).toElement()
            } else {
                match (stats.errorMessage()) {
                    case Some(e) => text_block("Error: ${e}").toElement()
                    case None => text_block("").toElement()
                }
            }
    }

    vstack([
        text_block("Dashboard").fontSize(28.0).bold().toElement(),
        text_block("Live stats (loaded via useResource):").toElement(),
        content
    ]).spacing(8.0).toElement()
}

func navSettingsPageBody(_props: NoProps, cx: RenderCx): Element {
    let (darkMode, setDark) = cx.useState<Bool>(false)
    let (notifications, setNotif) = cx.useState<Bool>(true)

    let darkLabel = if (darkMode) { "on" } else { "off" }
    let notifLabel = if (notifications) { "on" } else { "off" }

    vstack([
        text_block("Settings").fontSize(28.0).bold().toElement(),
        toggle_switch(darkMode)
            .header("Dark mode")
            .onChanged({ v: Bool => setDark.call(v) })
            .toElement(),
        toggle_switch(notifications)
            .header("Notifications")
            .onChanged({ v: Bool => setNotif.call(v) })
            .toElement(),
        text_block("Dark: ${darkLabel} | Notifications: ${notifLabel}")
            .opacity(0.6)
            .toElement()
    ]).spacing(12.0).toElement()
}

func navigationExample(cx: RenderCx): Element {
    let (page, setPage) = cx.useState<String>("home")

    let menuItems = ArrayList<NavViewItem>()
    menuItems.add(NavViewItem("Home").tagOf("home").iconOf(SymbolGlyph.Home))
    menuItems.add(NavViewItem("Dashboard").tagOf("dashboard").iconOf(SymbolGlyph.World))
    menuItems.add(NavViewItem("Settings").tagOf("settings").iconOf(SymbolGlyph.Setting))

    let body: Element = if (page == "dashboard") {
        component<NoProps>(navDashboardPageBody, NoProps(), navDashboardPageToken)
    } else if (page == "settings") {
        component<NoProps>(navSettingsPageBody, NoProps(), navSettingsPageToken)
    } else {
        component<NoProps>(navHomePageBody, NoProps(), navHomePageToken)
    }

    navigation_view(menuItems, body)
        .selectedTagOf(page)
        .onSelectionChanged({ tag: String => setPage.call(navTagOf(tag)) })
        .paneDisplayModeOf(NavViewPaneDisplayMode.Left)
        .paneTitle("My App")
        .toElement()
}

// ============================================================================
// theme_brush — theme-resource brush bindings (track light/dark switches).
// ============================================================================

// One swatch: a label in `fg` on a `bg` background, both symbolic theme refs.
func themeSwatch(label: String, bg: ThemeRef, fg: ThemeRef): Element {
    border(
        text_block(label)
            .fontSize(13.0)
            .foregroundTheme(fg)
            .padding(Thickness.uniform(10.0))
            .toElement()
    )
        .backgroundTheme(bg)
        .padding(Thickness.uniform(4.0))
        .minWidth(200.0)
        .toElement()
}

func themeBrushExample(_cx: RenderCx): Element {
    vstack([
        themeSwatch("Accent / AccentText", ThemeRef.Accent, ThemeRef.AccentText),
        themeSwatch("Card / Primary text", ThemeRef.CardBackground, ThemeRef.PrimaryText),
        themeSwatch(
            "SystemCritical background / foreground",
            ThemeRef.SystemCriticalBackground,
            ThemeRef.SystemCritical
        )
    ])
        .spacing(6.0)
        .maxWidth(420.0)
        .toElement()
}

// ============================================================================
// type_ramp — the WinUI type-ramp presets.
//
// The reference exposes title()/subtitle()/body_large()/body_strong()/body()/
// caption() factory functions; those do not exist in this framework, so each is
// expressed directly as the equivalent text_block with the documented size +
// weight (28/Semibold, 20/Semibold, 18/Normal, 14/Semibold, 14/Normal,
// 12/Normal). Behaviourally identical output.
// ============================================================================

func typeRampExample(_cx: RenderCx): Element {
    vstack([
        text_block("Title — 28px Semibold").fontSize(28.0).semibold().toElement(),
        text_block("Subtitle — 20px Semibold").fontSize(20.0).semibold().toElement(),
        text_block("BodyLarge — 18px Normal").fontSize(18.0).toElement(),
        text_block("BodyStrong — 14px Semibold").fontSize(14.0).semibold().toElement(),
        text_block("Body — 14px Normal").fontSize(14.0).toElement(),
        text_block("Caption — 12px Normal").fontSize(12.0).toElement(),
        text_block("Custom weight").fontWeight(300).toElement()
    ]).spacing(8.0).toElement()
}

// ============================================================================
// Dispatch + name source.
// ============================================================================

func routeComponents(name: String): ?(String, (RenderCx) -> Element) {
    match (name) {
        case "component_props" =>
            Some(("windows_reactor — component_props", componentPropsExample))
        case "function_component" =>
            Some(("function_component", functionComponentExample))
        case "render_fn" =>
            Some(("Render Function Demo", renderFnExample))
        case "composition" =>
            Some(("windows_reactor — composition", compositionExample))
        case "navigation" =>
            Some(("Navigation Pattern", navigationExample))
        case "theme_brush" =>
            Some(("Sample", themeBrushExample))
        case "type_ramp" =>
            Some(("Type Ramp", typeRampExample))
        case _ => None
    }
}

func namesComponents(): Array<String> {
    [
        "component_props",
        "function_component",
        "render_fn",
        "composition",
        "navigation",
        "theme_brush",
        "type_ramp"
    ]
}
