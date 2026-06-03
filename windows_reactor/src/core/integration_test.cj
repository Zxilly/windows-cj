package windows_reactor.core

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

// ============================================================================
// Integration tests (P2): drive the full Reconciler + RecordingBackend + hooks
// runtime headless and assert on the produced Op stream.
//
//   1. basic tree mount / update / unmount produces the expected Op sequence
//   2. keyed reorder mixing two control kinds keeps every Click binding on its
//      Button (LIS regression; complements reconciler_test.cj's variant)
//   3. hooks useState / useEffect re-render through a RenderHost driven by a
//      RunOnDemandDispatcher
//   4. component update + cleanup: an unmounted child component runs its effect
//      cleanup exactly once
// ============================================================================

// ── Reference-type cells (closures cannot escape capturing a local var) ──────
class IntCell { var n: Int64 = 0 }
class StrLog { let lines = ArrayList<String>(); func push(s: String) { lines.add(s) } }

// Count how many ops of a given discriminant name appear in the stream.
func countOps(backend: RecordingBackend, name: String): Int64 {
    var n: Int64 = 0
    for (op in backend.ops) {
        if (op.name() == name) { n = n + 1 }
    }
    n
}

// First control id minted for a given ControlKind in the recorded stream.
func firstCreatedOf(backend: RecordingBackend, kind: ControlKind): ?ControlId {
    for (op in backend.ops) {
        match (op) {
            case CreateOp(id, k) where k == kind => return Some(id)
            case _ => ()
        }
    }
    None
}

@Test
class IntegrationBasicTreeTests {
    func leaf(label: String): Element { text_block(label).toElement() }

    func panel(children: Array<Element>): Element {
        let s = StackPanel.verticalPanel()
        s.childrenValue = children
        s.toElement()
    }

    // Mount a small tree, assert create + child wiring; then update a single
    // leaf's text and assert exactly one SetProp lands; then unmount the whole
    // tree and assert every created control is destroyed.
    @TestCase
    func mountUpdateUnmountOpSequence() {
        let backend = RecordingBackend()
        let reconciler = Reconciler(backend)
        let noop: () -> Unit = { => () }

        let old = panel([leaf("a"), leaf("b")])

        // ── Mount ──
        let root = reconciler.reconcile(None, old, None, noop).getOrThrow()

        // 1 StackPanel + 2 TextBlock = 3 creates.
        @Expect(countOps(backend, "Create"), 3)
        // Two children appended under the panel.
        @Expect(backend.childrenOf(root).size, 2)
        @Expect(countOps(backend, "AppendChild"), 2)
        @Expect(backend.liveControlCount(), 3)
        // The panel sets Orientation; each TextBlock sets Text => 3 SetProp.
        @Expect(countOps(backend, "SetProp"), 3)

        // ── Update: change only the second leaf's text ──
        backend.clearOps()
        let neu = panel([leaf("a"), leaf("b2")])
        let root2 = reconciler.reconcile(Some(old), neu, Some(root), noop).getOrThrow()
        // Same root, reused in place.
        @Expect(root2 == root, true)
        // Exactly one SetProp (the changed Text); no creates / destroys.
        @Expect(countOps(backend, "Create"), 0)
        @Expect(countOps(backend, "Destroy"), 0)
        @Expect(countOps(backend, "SetProp"), 1)
        match (firstChangedText(backend)) {
            case Some(s) => @Expect(s, "b2")
            case None => @Fail("expected a Text SetProp carrying b2")
        }

        // ── Unmount: every created control is destroyed ──
        backend.clearOps()
        reconciler.unmount(root)
        // 3 controls torn down.
        @Expect(countOps(backend, "Destroy"), 3)
    }

    // Growing / shrinking a positional child list emits append for the new tail
    // and remove for the dropped tail (leaf-first).
    @TestCase
    func positionalGrowAndShrink() {
        let backend = RecordingBackend()
        let reconciler = Reconciler(backend)
        let noop: () -> Unit = { => () }

        let t0 = panel([leaf("a")])
        let root = reconciler.reconcile(None, t0, None, noop).getOrThrow()
        @Expect(backend.childrenOf(root).size, 1)

        // Grow to three children.
        backend.clearOps()
        let t1 = panel([leaf("a"), leaf("b"), leaf("c")])
        reconciler.reconcile(Some(t0), t1, Some(root), noop)
        @Expect(backend.childrenOf(root).size, 3)
        // Two new leaves created + appended.
        @Expect(countOps(backend, "Create"), 2)
        @Expect(countOps(backend, "AppendChild"), 2)

        // Shrink back to one child: two tail leaves removed + destroyed.
        backend.clearOps()
        reconciler.reconcile(Some(t1), t0, Some(root), noop)
        @Expect(backend.childrenOf(root).size, 1)
        @Expect(countOps(backend, "RemoveChild"), 2)
        @Expect(countOps(backend, "Destroy"), 2)
    }

    // A kind change at a child slot must rebuild (destroy old + create new +
    // replace), never set props on the wrong control.
    @TestCase
    func kindChangeRebuildsChild() {
        let backend = RecordingBackend()
        let reconciler = Reconciler(backend)
        let noop: () -> Unit = { => () }

        let t0 = panel([leaf("x")])
        let root = reconciler.reconcile(None, t0, None, noop).getOrThrow()

        backend.clearOps()
        // Replace the TextBlock child with a Button.
        let s = StackPanel.verticalPanel()
        s.childrenValue = [button("press").toElement()]
        let t1 = s.toElement()
        reconciler.reconcile(Some(t0), t1, Some(root), noop)

        @Expect(countOps(backend, "Destroy"), 1)
        @Expect(countOps(backend, "Create"), 1)
        @Expect(countOps(backend, "ReplaceChild"), 1)
        // The new control is a Button.
        match (firstCreatedOf(backend, ControlKind.Button)) {
            case Some(_) => @Expect(true, true)
            case None => @Fail("expected a Button to be created")
        }
    }

    func firstChangedText(backend: RecordingBackend): ?String {
        for (op in backend.ops) {
            match (op) {
                case SetPropOp(_, p, v) where p == Prop.Text =>
                    match (v) {
                        case Str(s) => return Some(s)
                        case _ => ()
                    }
                case _ => ()
            }
        }
        None
    }
}

@Test
class IntegrationKeyedReorderTests {
    func btn(k: String): Element { button(k).keyOf(k).onClick({ => () }).toElement() }
    func txt(k: String): Element {
        let t = TextBlock(k)
        t.keyValue = Some(k)
        t.toElement()
    }
    func stack(children: Array<Element>): Element {
        let s = StackPanel.verticalPanel()
        s.childrenValue = children
        s.toElement()
    }

    // Mixed-kind keyed shuffle: after a reorder that interleaves Buttons and
    // TextBlocks, every Click handler must still be attached to a Button (the
    // LIS / keyed-middle alignment bug otherwise lands a Click on a TextBlock).
    @TestCase
    func mixedKindShuffleKeepsClicksOnButtons() {
        let old = stack([
            btn("b1"), txt("t1"), btn("b2"), txt("t2"), btn("b3")
        ])
        // Reorder: move b3 to the front, t2 ahead of b2, drop nothing.
        let neu = stack([
            btn("b3"), txt("t2"), btn("b1"), txt("t1"), btn("b2")
        ])

        let backend = RecordingBackend()
        let reconciler = Reconciler(backend)
        let noop: () -> Unit = { => () }

        let root = reconciler.reconcile(None, old, None, noop).getOrThrow()

        // Snapshot id -> kind.
        let kindOf = HashMap<UInt32, ControlKind>()
        for (op in backend.ops) {
            match (op) {
                case CreateOp(id, kind) => kindOf.add(id.raw, kind)
                case _ => ()
            }
        }

        backend.clearOps()
        reconciler.reconcile(Some(old), neu, Some(root), noop)

        // No control should have been recreated (keyed reuse).
        @Expect(countOps(backend, "Create"), 0)

        // Every Click attach lands on a Button control.
        for (op in backend.ops) {
            match (op) {
                case AttachEventOp(id, ev, _) where ev == Event.Click =>
                    match (kindOf.get(id.raw)) {
                        case Some(k) => @Expect(k == ControlKind.Button, true)
                        case None => @Fail("Click attach on unknown control ${id}")
                    }
                case _ => ()
            }
        }

        // Live control count stable across the reorder (same 5 controls).
        // (mount created 6: panel + 5 children.)
        @Expect(backend.childrenOf(root).size, 5)
    }
}

@Test
class IntegrationHooksTests {
    // useState drives a re-render: clicking a button increments a counter cell
    // and the next render emits a SetProp(Text) carrying the new count. The
    // render loop runs through the RunOnDemandDispatcher.
    @TestCase
    func useStateReRendersThroughDispatcher() {
        let backend = RecordingBackend()
        let dispatcher = RunOnDemandDispatcher()

        // Capture the latest setter through a reference cell so the test can
        // fire it from outside the render closure.
        let root = rootComponent({ cx: RenderCx =>
            let (n, setN) = cx.useState<Int64>(0)
            // Increment on click.
            let b = button("inc").onClick({ => setN.call(n + 1) })
            let label = text_block("count=${n}")
            let s = StackPanel.verticalPanel()
            s.childrenValue = [label.toElement(), b.toElement()]
            s.toElement()
        })

        let host = RenderHost(backend, root, dispatcher)
        host.kick()
        dispatcher.drain()
        // First render done.
        @Expect(host.renderCountValue(), 1)
        @Expect(currentCountText(backend), "count=0")

        // Fire the Button's Click; the setter marks state dirty + requests a
        // render, which the dispatcher then runs.
        let btnId = firstCreatedOf(backend, ControlKind.Button).getOrThrow()
        backend.clearOps()
        backend.fireClick(btnId)
        dispatcher.drain()
        @Expect(host.renderCountValue(), 2)
        // The TextBlock's Text was updated to count=1 (in place, no rebuild).
        @Expect(countOps(backend, "Create"), 0)
        @Expect(currentCountText(backend), "count=1")

        // Fire again: count=2.
        backend.clearOps()
        backend.fireClick(btnId)
        dispatcher.drain()
        @Expect(host.renderCountValue(), 3)
        @Expect(currentCountText(backend), "count=2")
    }

    // useEffect runs after each render whose deps changed; cleanup runs before
    // the next effect when deps change. Drive several state-changing renders and
    // observe the effect / cleanup log order.
    @TestCase
    func useEffectRunsAndCleansUpOnDepsChange() {
        let backend = RecordingBackend()
        let dispatcher = RunOnDemandDispatcher()
        let log = StrLog()
        let setterCell = SetterHolder()

        let root = rootComponent({ cx: RenderCx =>
            let (n, setN) = cx.useState<Int64>(0)
            setterCell.set = Some({ => setN.call(n + 1) })
            cx.useEffectWithCleanup<Int64>(n, { =>
                log.push("effect:${n}")
                return Option<() -> Unit>.Some({ => log.push("cleanup:${n}") })
            })
            text_block("n=${n}").toElement()
        })

        let host = RenderHost(backend, root, dispatcher)
        host.kick()
        dispatcher.drain()
        // First effect ran, no cleanup yet.
        @Expect(log.lines.size, 1)
        @Expect(log.lines[0], "effect:0")

        // Bump state: cleanup:0 then effect:1.
        fireSetter(setterCell)
        dispatcher.drain()
        @Expect(log.lines.size, 3)
        @Expect(log.lines[1], "cleanup:0")
        @Expect(log.lines[2], "effect:1")

        // Bump again: cleanup:1 then effect:2.
        fireSetter(setterCell)
        dispatcher.drain()
        @Expect(log.lines.size, 5)
        @Expect(log.lines[3], "cleanup:1")
        @Expect(log.lines[4], "effect:2")
    }

    func currentCountText(backend: RecordingBackend): String {
        // Find the last Text SetProp in the stream.
        var found: ?String = None
        for (op in backend.ops) {
            match (op) {
                case SetPropOp(_, p, v) where p == Prop.Text =>
                    match (v) {
                        case Str(s) => found = Some(s)
                        case _ => ()
                    }
                case _ => ()
            }
        }
        found ?? "<none>"
    }

    func fireSetter(holder: SetterHolder): Unit {
        match (holder.set) {
            case Some(f) => f()
            case None => @Fail("setter not captured")
        }
    }
}

class SetterHolder { var set: ?(() -> Unit) = None }

// A child component that records its mount/effect/cleanup lifecycle into a log
// via useEffectWithCleanup. Used to prove that unmounting a component runs its
// cleanup exactly once.
class ChildComponent <: Component<Int64> {
    let log: StrLog
    public init(log: StrLog) { this.log = log }

    public func render(props: Int64, cx: RenderCx): Element {
        let id = props
        cx.useEffectWithCleanup<Int64>(0, { =>
            log.push("mount:${id}")
            return Option<() -> Unit>.Some({ => log.push("unmount:${id}") })
        })
        text_block("child#${id}").toElement()
    }
}

@Test
class IntegrationComponentLifecycleTests {
    // Conditionally render a child component; toggling the condition off must
    // unmount the child and run its effect cleanup exactly once.
    @TestCase
    func childComponentCleanupOnUnmount() {
        let backend = RecordingBackend()
        let dispatcher = RunOnDemandDispatcher()
        let log = StrLog()
        let showCell = BoolHolder()
        showCell.value = true
        let toggle = SetterHolder()

        let childToken = newComponentTypeToken()

        let root = rootComponent({ cx: RenderCx =>
            let (show, setShow) = cx.useState<Bool>(true)
            toggle.set = Some({ => setShow.call(!show) })
            let kids = ArrayList<Element>()
            kids.add(text_block("header").toElement())
            if (show) {
                kids.add(component<Int64>(ChildComponent(log), 7, childToken))
            }
            let s = StackPanel.verticalPanel()
            s.childrenValue = kids.toArray()
            s.toElement()
        })

        let host = RenderHost(backend, root, dispatcher)
        host.kick()
        dispatcher.drain()
        // Child mounted: its effect ran once.
        @Expect(log.lines.size, 1)
        @Expect(log.lines[0], "mount:7")

        // Toggle off: child unmounts, cleanup runs exactly once.
        match (toggle.set) { case Some(f) => f(); case None => @Fail("no toggle") }
        dispatcher.drain()
        @Expect(log.lines.size, 2)
        @Expect(log.lines[1], "unmount:7")

        // Toggle back on: child re-mounts (fresh instance), effect runs again.
        match (toggle.set) { case Some(f) => f(); case None => @Fail("no toggle") }
        dispatcher.drain()
        @Expect(log.lines.size, 3)
        @Expect(log.lines[2], "mount:7")
    }

    // A component whose props change re-renders and updates its child's prop in
    // place (no rebuild); cleanup only fires on final unmount.
    @TestCase
    func componentPropChangeUpdatesInPlace() {
        let backend = RecordingBackend()
        let dispatcher = RunOnDemandDispatcher()
        let log = StrLog()
        let bump = SetterHolder()
        let childToken = newComponentTypeToken()

        let root = rootComponent({ cx: RenderCx =>
            let (v, setV) = cx.useState<Int64>(1)
            bump.set = Some({ => setV.call(v + 1) })
            component<Int64>(ChildComponent(log), v, childToken)
        })

        let host = RenderHost(backend, root, dispatcher)
        host.kick()
        dispatcher.drain()
        @Expect(log.lines.size, 1)
        @Expect(log.lines[0], "mount:1")
        let childTextId = firstCreatedOf(backend, ControlKind.TextBlock).getOrThrow()

        // Bump the prop: child re-renders, TextBlock text updated in place, no
        // new control, and (deps are constant 0) the effect does NOT re-run.
        backend.clearOps()
        match (bump.set) { case Some(f) => f(); case None => @Fail("no bump") }
        dispatcher.drain()
        @Expect(countOps(backend, "Create"), 0)
        @Expect(countOps(backend, "Destroy"), 0)
        // The same TextBlock got its Text set to child#2.
        var sawUpdate = false
        for (op in backend.ops) {
            match (op) {
                case SetPropOp(id, p, v) where p == Prop.Text && id == childTextId =>
                    match (v) {
                        case Str(s) => if (s == "child#2") { sawUpdate = true }
                        case _ => ()
                    }
                case _ => ()
            }
        }
        @Expect(sawUpdate, true)
        // Effect did not re-run (deps unchanged).
        @Expect(log.lines.size, 1)

        // Tear down the whole host tree: cleanup fires exactly once. The
        // reconciler is an in-package (internal) field, reachable from this
        // same-package test. Because the child's effect deps are a constant 0,
        // the effect never re-ran, so the surviving cleanup is the one captured
        // at mount time (props=1) — correct React semantics: a stable-deps
        // cleanup closes over the values from when it was created, not the
        // latest props.
        match (host.rootIdValue()) {
            case Some(rid) => host.reconciler.unmount(rid)
            case None => @Fail("no root id")
        }
        @Expect(log.lines.size, 2)
        @Expect(log.lines[1], "unmount:1")
    }
}

class BoolHolder { var value: Bool = false }
