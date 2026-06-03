package windows_reactor.core

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.*

// ============================================================================
// Regression: header/pane element subtrees must be unmounted (and their native
// controls destroyed) on teardown.
//
// header_element / pane_element subtrees (Expander header, SplitView pane,
// TitleBar) are tracked in the reconciler's headerElements / paneElements maps,
// NOT in childrenMirror. unmount() collects the teardown set via collectSubtree,
// which only walks childrenMirror — so before the fix these subtrees (their
// XAML handles, component instances, captured closures) were never destroyed
// and leaked on every unmount. In a NavigationView page-switch this accumulated
// per navigation cycle. The fix unmounts headerElements/paneElements entries in
// the unmount loop; these tests assert no control survives teardown.
// ============================================================================

@Test
class ReconcilerHeaderPaneLeakTests {
    func noop(): () -> Unit { { => () } }

    // Expander whose header_element holds a nested StackPanel + three TextBlocks.
    func expanderWithHeader(): Element {
        expander(text_block("body content").toElement())
            .headerContent(
                vstack([
                    text_block("Header item 1").toElement(),
                    text_block("Header item 2").toElement(),
                    text_block("Header item 3").toElement()
                ]).toElement()
            )
            .expanded(true)
            .toElement()
    }

    // A realistic NavigationView page: a vstack containing an Expander with a
    // complex header_element subtree.
    func page(): Element {
        vstack([
            text_block("Page Title").toElement(),
            expanderWithHeader(),
            text_block("Footer").toElement()
        ]).toElement()
    }

    // SplitView whose pane_element holds a nested StackPanel + two TextBlocks.
    func splitViewWithPane(): Element {
        let sv = split_view(text_block("main content").toElement())
        sv.pane = vstack([
            text_block("Pane item 1").toElement(),
            text_block("Pane item 2").toElement()
        ]).toElement()
        sv.toElement()
    }

    // Mounting then unmounting an Expander must destroy the header subtree.
    @TestCase
    func headerElementSubtreeFreedOnUnmount() {
        let backend = RecordingBackend()
        let reconciler = Reconciler(backend)
        let tree = expanderWithHeader()

        let root = reconciler.reconcile(None, tree, None, noop())
        @Expect(root.isSome(), true)

        reconciler.reconcile(Some(tree), Element.EmptyEl, root, noop())

        // Every created control (Expander + header StackPanel + 3 TextBlocks)
        // must be destroyed. Before the fix the 4 header-subtree controls leaked.
        @Expect(backend.liveControlCount(), 0)
    }

    // Mounting then unmounting a SplitView must destroy the pane subtree.
    @TestCase
    func paneElementSubtreeFreedOnUnmount() {
        let backend = RecordingBackend()
        let reconciler = Reconciler(backend)
        let tree = splitViewWithPane()

        let root = reconciler.reconcile(None, tree, None, noop())
        @Expect(root.isSome(), true)

        reconciler.reconcile(Some(tree), Element.EmptyEl, root, noop())
        @Expect(backend.liveControlCount(), 0)
    }

    // Ten mount/unmount cycles (simulating page switches in a NavigationView)
    // must leave no surviving controls — i.e. no per-navigation accumulation.
    @TestCase
    func repeatedNavigationNoLeak() {
        let backend = RecordingBackend()
        let reconciler = Reconciler(backend)

        var cycle = 0
        while (cycle < 10) {
            let p = page()
            let id = reconciler.reconcile(None, p, None, noop())
            reconciler.reconcile(Some(p), Element.EmptyEl, id, noop())
            cycle++
        }

        @Expect(backend.liveControlCount(), 0)
    }
}
