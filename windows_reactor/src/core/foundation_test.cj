package windows_reactor.core

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

// Headless smoke tests for the reactor core foundation: Widget -> bindings ->
// RecordingBackend op stream, event replay, and structural equivalence. The
// reconciler is not yet implemented (Engines phase), so we drive the backend
// with a minimal mountWidget helper that mirrors the bindings -> setProp /
// attachEvent lowering the reconciler will perform.

func mountWidget(backend: RecordingBackend, w: Widget): ControlId {
    let id = backend.create(w.kind())
    for (b in w.bindings()) {
        match (b) {
            case PropB(p, v) => backend.setProp(id, p, v)
            case EventB(e, hopt) =>
                match (hopt) {
                    case Some(h) => backend.attachEvent(id, e, h)
                    case None => ()
                }
        }
    }
    id
}

@Test
class FoundationTests {
    @TestCase
    func textBlockBindings() {
        let tb = text_block("hello").fontSize(18.0).bold().wrap()
        let bs = tb.bindings()
        // Text + FontSize + FontWeight + TextWrappingWrap
        @Expect(bs.size, 4)
        @Expect(matchProp(bs, Prop.Text, PropValue.Str("hello")), true)
        @Expect(matchProp(bs, Prop.FontSize, PropValue.F64(18.0)), true)
        @Expect(matchProp(bs, Prop.FontWeight, PropValue.U16(700)), true)
        @Expect(matchProp(bs, Prop.TextWrappingWrap, PropValue.BoolV(true)), true)
    }

    @TestCase
    func textBlockOmitsUnsetOptionals() {
        let tb = text_block("plain")
        // Only the Text binding when no optional modifiers are set.
        @Expect(tb.bindings().size, 1)
    }

    @TestCase
    func buttonClickReplay() {
        let backend = RecordingBackend()
        let counter = ClickCounter()
        let b = button("OK").onClick({ => counter.n = counter.n + 1 })
        let id = mountWidget(backend, b)
        // Create + ButtonContent + Click(attach)
        @Expect(backend.opCount(), 3)
        @Expect(counter.n, 0)
        backend.fireClick(id)
        backend.fireClick(id)
        @Expect(counter.n, 2)
    }

    @TestCase
    func buttonDisabledAndStyleBindings() {
        let b = button("X").enabled(false).accent().withIcon(SymbolGlyph.Add)
        let bs = b.bindings()
        // ButtonContent + IsEnabled(false) + ButtonStyleVariant + ButtonIcon + Click(none)
        @Expect(bs.size, 5)
        @Expect(matchProp(bs, Prop.IsEnabled, PropValue.BoolV(false)), true)
        @Expect(matchProp(bs, Prop.ButtonStyleVariant, PropValue.ButtonStyleV(ButtonStyle.Accent)), true)
        @Expect(matchProp(bs, Prop.ButtonIcon, PropValue.SymbolIconV(SymbolGlyph.Add)), true)
        // Click present but with no handler.
        match (findEvent(bs, Event.Click)) {
            case Some(None) => @Expect(true, true)
            case _ => @Fail("expected Click event slot with no handler")
        }
    }

    @TestCase
    func checkBoxChangedReplay() {
        let backend = RecordingBackend()
        let cell = BoolCell()
        let cb = check_box(false).label("Agree").onChanged({ v => cell.value = v })
        let id = mountWidget(backend, cb)
        backend.fireBool(id, Event.CheckedChanged, true)
        @Expect(cell.value, true)
        let bs = cb.bindings()
        @Expect(matchProp(bs, Prop.IsChecked, PropValue.BoolV(false)), true)
        @Expect(matchProp(bs, Prop.CheckBoxLabel, PropValue.Str("Agree")), true)
    }

    @TestCase
    func stackPanelKeyedChildren() {
        let sp = stack_panel([text_block("a").toElement(), button("b").toElement()]).spacing(8.0)
        match (sp.children()) {
            case Keyed(arr) => @Expect(arr.size, 2)
            case _ => @Fail("StackPanel should expose Keyed children")
        }
        // Orientation + Spacing
        @Expect(sp.bindings().size, 2)
    }

    @TestCase
    func gridConditionalBindings() {
        let g = grid([]).rowSpacing(4.0)
        // No rows/columns set -> only GridRowSpacing emitted.
        @Expect(g.bindings().size, 1)
        let g2 = Grid()
        g2.rowsOf([GridLength.Auto, GridLength.star(1.0)])
        g2.columnsOf([GridLength.pixel(100.0)])
        // GridRows + GridColumns
        @Expect(g2.bindings().size, 2)
    }

    @TestCase
    func scrollViewerPositionalSingle() {
        let sv = scroll_viewer(text_block("body").toElement())
            .verticalScrollBar(ScrollBarVisibility.Auto)
        match (sv.children()) {
            case PositionalSingle(_) => @Expect(true, true)
            case _ => @Fail("ScrollViewer should expose a single positional child")
        }
        @Expect(sv.bindings().size, 2)
    }

    @TestCase
    func gridRowModifierChain() {
        let tb = text_block("cell").gridRow(2).gridColumn(3)
        match (tb.mods.grid) {
            case Some(p) =>
                @Expect(p.row, 2)
                @Expect(p.column, 3)
                @Expect(p.rowSpan, 1)
                @Expect(p.columnSpan, 1)
            case None => @Fail("grid placement should be set")
        }
    }

    @TestCase
    func elementEquivalenceAndSkip() {
        let a = text_block("same").fontSize(12.0).toElement()
        let b = text_block("same").fontSize(12.0).toElement()
        let c = text_block("diff").fontSize(12.0).toElement()
        @Expect(elementEquivalent(a, b), true)
        @Expect(elementEquivalent(a, c), false)
        @Expect(canSkipUpdate(a, b), true)
        @Expect(canSkipUpdate(a, c), false)
        // Theme binding present -> cannot skip even if equivalent.
        let t1 = text_block("t").backgroundTheme(ThemeRef.Accent).toElement()
        let t2 = text_block("t").backgroundTheme(ThemeRef.Accent).toElement()
        @Expect(elementEquivalent(t1, t2), true)
        @Expect(canSkipUpdate(t1, t2), false)
    }

    @TestCase
    func kindMatchesAndCanUpdate() {
        let a = button("a").toElement()
        let b = button("b").toElement()
        let tb = text_block("x").toElement()
        @Expect(a.kindMatches(b), true)
        @Expect(a.kindMatches(tb), false)
        @Expect(a.canUpdate(b), true)
        @Expect(a.kindName(), "Button")
        @Expect(tb.kindName(), "TextBlock")
    }

    @TestCase
    func templatedListBuilder() {
        let items: Array<String> = ["x", "y", "z"]
        let el = listView<String>(items, { s, _ => text_block(s).toElement() })
            .selectedIndex(1)
            .withKeySelector({ s => s })
            .build()
        match (el) {
            case TemplatedListEl(tl) =>
                @Expect(tl.itemCount(), 3)
                @Expect(tl.kind == TemplatedKind.ListView, true)
                @Expect(tl.selectedIndex(), 1)
                @Expect(tl.fullyKeyed(), true)
                @Expect(tl.collectKeys().size, 3)
                // Build the view for item 1; should be a TextBlock element.
                @Expect(tl.buildItemView(1).kindName(), "TextBlock")
            case _ => @Fail("listView should produce a TemplatedListEl")
        }
    }

    @TestCase
    func recordingBackendChildOps() {
        let backend = RecordingBackend()
        let parent = backend.create(ControlKind.StackPanel)
        let c1 = backend.create(ControlKind.TextBlock)
        let c2 = backend.create(ControlKind.Button)
        backend.appendChild(parent, c1)
        backend.appendChild(parent, c2)
        @Expect(backend.childrenOf(parent).size, 2)
        backend.removeChild(parent, 0)
        let kids = backend.childrenOf(parent)
        @Expect(kids.size, 1)
        @Expect(kids[0] == c2, true)
        @Expect(backend.liveControlCount(), 3)
        backend.destroy(c1)
        @Expect(backend.liveControlCount(), 2)
    }

    @TestCase
    func recordingBackendThemeCache() {
        let backend = RecordingBackend()
        let id1 = backend.create(ControlKind.Border)
        let id2 = backend.create(ControlKind.Border)
        let bindings: Array<(Prop, ThemeRef)> = [(Prop.Background, ThemeRef.Accent)]
        backend.setThemeBindings(id1, ControlKind.Border, bindings)
        @Expect(backend.themeCacheSize(), 1)
        // Same kind + bindings -> cache hit, no new cache entry.
        backend.setThemeBindings(id2, ControlKind.Border, bindings)
        @Expect(backend.themeCacheSize(), 1)
        @Expect(backend.themeBindingsOf(id1).size, 1)
        backend.onThemeChanged()
        @Expect(backend.themeCacheSize(), 0)
    }

    @TestCase
    func controlIdIdentityAndKey() {
        let a = ControlId(5)
        let b = ControlId(5)
        let c = ControlId(6)
        @Expect(a == b, true)
        @Expect(a == c, false)
        let m = HashMap<ControlId, String>()
        m[a] = "five"
        @Expect(m.get(b) ?? "?", "five")
        // EventKey composite key round-trips.
        let k1 = EventKey(a, Event.Click)
        let k2 = EventKey(b, Event.Click)
        @Expect(k1 == k2, true)
        @Expect(k1 == EventKey(a, Event.Toggled), false)
    }

    @TestCase
    func callbackIdentity() {
        let cb1 = Callback<Unit>({ _ => () })
        let cb2 = Callback<Unit>({ _ => () })
        @Expect(cb1.sameAs(cb1), true)
        @Expect(cb1.sameAs(cb2), false)
        // EventHandler equality follows callback identity.
        let h1 = EventHandler.ClickH(cb1)
        let h1b = EventHandler.ClickH(cb1)
        let h2 = EventHandler.ClickH(cb2)
        @Expect(h1.equals(h1b), true)
        @Expect(h1.equals(h2), false)
    }
}

// Reference-type state cells used by closures in tests (closures cannot escape
// capturing a local var; they capture these class instances instead).
class ClickCounter { var n: Int64 = 0 }
class BoolCell { var value: Bool = false }

func matchProp(bs: PropBindings, p: Prop, expected: PropValue): Bool {
    match (findProp(bs, p)) {
        case Some(v) => v.equals(expected)
        case None => false
    }
}
