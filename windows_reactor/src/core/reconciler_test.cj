package windows_reactor.core

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

// ============================================================================
// Reconciler tests: the LIS unit tests (self-contained) and the keyed-reorder
// regression test that guards against pushing a Button's Click binding onto a
// TextBlock control during a mixed-kind keyed shuffle (reference:
// reconciler/child.rs tests). The keyed-reorder test drives only widget
// elements, so it does not depend on the RenderCx/component wiring owned by the
// hooks phase; it runs against the RecordingBackend.
// ============================================================================

@Test
class ReconcilerLisTests {
    @TestCase
    func lisEmpty() {
        @Expect(computeLis(Array<Int64>()).size, 0)
    }

    @TestCase
    func lisSingle() {
        let s = computeLis([5])
        @Expect(s.size, 1)
        @Expect(s.contains(0), true)
    }

    @TestCase
    func lisSorted() {
        @Expect(computeLis([1, 2, 3, 4, 5]).size, 5)
    }

    @TestCase
    func lisReversed() {
        @Expect(computeLis([5, 4, 3, 2, 1]).size, 1)
    }

    @TestCase
    func lisWithUnmapped() {
        // -1 entries are skipped; LIS of {2,4} = length 2.
        @Expect(computeLis([-1, 2, -1, 4, -1]).size, 2)
    }

    @TestCase
    func lisAllUnmapped() {
        @Expect(computeLis([-1, -1, -1]).size, 0)
    }

    @TestCase
    func lisMixed() {
        @Expect(computeLis([3, 1, 2, 4]).size, 3)
    }

    @TestCase
    func lisStrictlyIncreasingValues() {
        let arr: Array<Int64> = [5, 1, 4, 2, 3]
        let s = computeLis(arr)
        let ordered = ArrayList<Int64>()
        for (i in s) { ordered.add(i) }
        sortInt64(ordered)
        var i = 1
        while (i < ordered.size) {
            @Expect(arr[ordered[i]] > arr[ordered[i - 1]], true)
            i++
        }
    }

    @TestCase
    func lisReconcileShiftOne() {
        @Expect(computeLis([2, 0, 1, 3]).size, 3)
    }
}

@Test
class ReconcilerKeyedReorderTests {
    func tile(label: String): Element {
        let b = button(label).keyOf(label).onClick({ => () })
        b.toElement()
    }

    func emptyTile(): Element {
        let t = TextBlock("")
        t.keyValue = Some("empty")
        t.toElement()
    }

    func stack(children: Array<Element>): Element {
        let s = StackPanel.verticalPanel()
        s.childrenValue = children
        s.toElement()
    }

    // Regression: a keyed reorder of mixed-kind children must keep every Click
    // binding on a Button control (never a TextBlock). See the reference test
    // keyed_reorder_with_mixed_kinds_keeps_controls_aligned.
    @TestCase
    func keyedReorderKeepsControlsAligned() {
        let old = stack([
            emptyTile(),
            tile("tile-X"),
            tile("tile-A"),
            tile("tile-B"),
            tile("tile-C")
        ])
        let neu = stack([
            tile("tile-X"),
            tile("tile-A"),
            emptyTile(),
            tile("tile-B"),
            tile("tile-C")
        ])

        let backend = RecordingBackend()
        let reconciler = Reconciler(backend)
        let noop: () -> Unit = { => () }

        let root = reconciler.reconcile(None, old, None, noop).getOrThrow()

        // Snapshot id -> kind from the mount-phase ops.
        let kindOf = HashMap<UInt32, ControlKind>()
        for (op in backend.ops) {
            match (op) {
                case CreateOp(id, kind) => kindOf.add(id.raw, kind)
                case _ => ()
            }
        }

        backend.clearOps()
        reconciler.reconcile(Some(old), neu, Some(root), noop)

        // Pick up any ids minted by the update (there should be none).
        for (op in backend.ops) {
            match (op) {
                case CreateOp(id, kind) => kindOf.add(id.raw, kind)
                case _ => ()
            }
        }

        // No Click attach should land on a non-Button control.
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
    }
}
