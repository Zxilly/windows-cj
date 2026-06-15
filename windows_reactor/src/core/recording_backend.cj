package windows_reactor.core

import std.collection.*

// ============================================================================
// Op — recorded backend operation captured by RecordingBackend for headless
// tests. Carries the payload of each Backend call.
// ============================================================================

public enum Op {
    | CreateOp(ControlId, ControlKind)
    | SetPropOp(ControlId, Prop, PropValue)
    | AppendChildOp(ControlId, ControlId)
    | RemoveChildOp(ControlId, Int64)
    | ReplaceChildOp(ControlId, Int64, ControlId)
    | MoveChildOp(ControlId, Int64, Int64)
    | InsertChildOp(ControlId, Int64, ControlId)
    | DestroyOp(ControlId)
    | AttachEventOp(ControlId, Event, EventHandler)
    | DetachEventOp(ControlId, Event)
    | SetTemplatedItemCountOp(ControlId, Int64)
    | MountRowContentOp(ControlId, Int64, ControlId)
    | ClearRowContentOp(ControlId, Int64)
    | SetTemplatedSelectedIndexOp(ControlId, Int32)
    | SetTemplatedSelectionModeOp(ControlId, SelectionMode)
    | SetHeaderElementOp(ControlId, ?ControlId)
    | SetPaneElementOp(ControlId, ?ControlId)
    | ScrollTemplatedToIndexOp(ControlId, Int32)
    | AttachTemplatedSelectionChangedOp(ControlId)
    | AttachTemplatedRealizationOp(ControlId)
    | ApplyThemeBindingsOp(ControlId, ControlKind, Array<(Prop, ThemeRef)>, Bool)
    | OnThemeChangedOp
    | SetImplicitTransitionsOp(ControlId, ?ImplicitTransitions)
    | SetLayoutAnimationOp(ControlId, ?LayoutAnimationConfig)
    | RunLayoutTranslationAnimationOp(ControlId, Float64, Float64, LayoutAnimationConfig)
    | RunPropertyAnimationOp(ControlId, ?AnimationConfig)
    | SetRichTextParagraphsOp(ControlId, Array<RichTextParagraph>)
    | SetAccessibilityOp(ControlId, AccessibilityModifiers)
    | SetKeyboardAcceleratorsOp(ControlId, Array<KeyboardAccelerator>)
    | SetTooltipOp(ControlId, ?Tooltip)
    | SetPointerHandlersOp(ControlId, ?PointerHandlers)

    // Human-readable discriminant name for test assertions and diagnostics.
    public func name(): String {
        match (this) {
            case CreateOp(_, _) => "Create"
            case SetPropOp(_, _, _) => "SetProp"
            case AppendChildOp(_, _) => "AppendChild"
            case RemoveChildOp(_, _) => "RemoveChild"
            case ReplaceChildOp(_, _, _) => "ReplaceChild"
            case MoveChildOp(_, _, _) => "MoveChild"
            case InsertChildOp(_, _, _) => "InsertChild"
            case DestroyOp(_) => "Destroy"
            case AttachEventOp(_, _, _) => "AttachEvent"
            case DetachEventOp(_, _) => "DetachEvent"
            case SetTemplatedItemCountOp(_, _) => "SetTemplatedItemCount"
            case MountRowContentOp(_, _, _) => "MountRowContent"
            case ClearRowContentOp(_, _) => "ClearRowContent"
            case SetTemplatedSelectedIndexOp(_, _) => "SetTemplatedSelectedIndex"
            case SetTemplatedSelectionModeOp(_, _) => "SetTemplatedSelectionMode"
            case SetHeaderElementOp(_, _) => "SetHeaderElement"
            case SetPaneElementOp(_, _) => "SetPaneElement"
            case ScrollTemplatedToIndexOp(_, _) => "ScrollTemplatedToIndex"
            case AttachTemplatedSelectionChangedOp(_) => "AttachTemplatedSelectionChanged"
            case AttachTemplatedRealizationOp(_) => "AttachTemplatedRealization"
            case ApplyThemeBindingsOp(_, _, _, _) => "ApplyThemeBindings"
            case OnThemeChangedOp => "OnThemeChanged"
            case SetImplicitTransitionsOp(_, _) => "SetImplicitTransitions"
            case SetLayoutAnimationOp(_, _) => "SetLayoutAnimation"
            case RunLayoutTranslationAnimationOp(_, _, _, _) => "RunLayoutTranslationAnimation"
            case RunPropertyAnimationOp(_, _) => "RunPropertyAnimation"
            case SetRichTextParagraphsOp(_, _) => "SetRichTextParagraphs"
            case SetAccessibilityOp(_, _) => "SetAccessibility"
            case SetKeyboardAcceleratorsOp(_, _) => "SetKeyboardAccelerators"
            case SetTooltipOp(_, _) => "SetTooltip"
            case SetPointerHandlersOp(_, _) => "SetPointerHandlers"
        }
    }
}

// ============================================================================
// RecordingBackend — in-memory Backend that records every operation as an Op
// and can replay events back into recorded handlers. Deterministic headless
// counterpart to the WinUI backend; used by the test suite.
// ============================================================================

public class RecordingBackend <: Backend {
    public var ops: ArrayList<Op> = ArrayList<Op>()
    var nextId: UInt32 = 0
    let children = HashMap<ControlId, ArrayList<ControlId>>()
    let handlers = HashMap<EventKey, EventHandler>()
    let rowContents = HashMap<ControlId, HashMap<Int64, ControlId>>()
    let itemCounts = HashMap<ControlId, Int64>()
    let realizeHandlers = HashMap<ControlId, (Int64) -> Unit>()
    let recycleHandlers = HashMap<ControlId, (Int64) -> Unit>()
    let selectionHandlers = HashMap<ControlId, Callback<Int32>>()
    let themeStyleCache = HashSet<String>()
    let themeBindingsLive = HashMap<ControlId, Array<(Prop, ThemeRef)>>()

    public init() {}

    public func opCount(): Int64 { ops.size }
    public func clearOps(): Unit { ops = ArrayList<Op>() }

    public func childrenOf(parent: ControlId): Array<ControlId> {
        match (children.get(parent)) {
            case Some(list) => list.toArray()
            case None => Array<ControlId>()
        }
    }

    public func itemCountOf(listId: ControlId): ?Int64 { itemCounts.get(listId) }

    public func themeCacheSize(): Int64 { themeStyleCache.size }

    public func themeBindingsOf(id: ControlId): Array<(Prop, ThemeRef)> {
        match (themeBindingsLive.get(id)) {
            case Some(b) => b
            case None => Array<(Prop, ThemeRef)>()
        }
    }

    // Count of controls created but not yet destroyed.
    public func liveControlCount(): Int64 {
        let alive = HashSet<UInt32>()
        for (op in ops) {
            match (op) {
                case CreateOp(id, _) => alive.add(id.raw)
                case DestroyOp(id) => alive.remove(id.raw)
                case _ => ()
            }
        }
        alive.size
    }

    func handlerFor(id: ControlId, event: Event): EventHandler {
        match (handlers.get(EventKey(id, event))) {
            case Some(h) => h
            case None => throw HandlerMismatchException("no handler for (${id}, event#${event.tag()})")
        }
    }

    // ── Event replay helpers ────────────────────────────────────────────
    public func fireClick(id: ControlId): Unit { handlerFor(id, Event.Click).invoke() }
    public func fire(id: ControlId, event: Event): Unit { handlerFor(id, event).invoke() }
    public func fireBool(id: ControlId, event: Event, v: Bool): Unit { handlerFor(id, event).invokeBool(v) }
    public func fireString(id: ControlId, event: Event, s: String): Unit { handlerFor(id, event).invokeString(s) }
    public func fireF64(id: ControlId, event: Event, v: Float64): Unit { handlerFor(id, event).invokeF64(v) }
    public func fireI32(id: ControlId, event: Event, v: Int32): Unit { handlerFor(id, event).invokeI32(v) }

    public func simulatePrepareRow(listId: ControlId, rowIdx: Int64): Unit {
        match (realizeHandlers.get(listId)) {
            case Some(f) => f(rowIdx)
            case None => throw HandlerMismatchException("no realization handler on ${listId}")
        }
    }
    public func simulateClearRow(listId: ControlId, rowIdx: Int64): Unit {
        match (recycleHandlers.get(listId)) {
            case Some(f) => f(rowIdx)
            case None => throw HandlerMismatchException("no recycle handler on ${listId}")
        }
    }
    public func fireTemplatedSelectionChanged(listId: ControlId, index: Int32): Unit {
        match (selectionHandlers.get(listId)) {
            case Some(cb) => cb.invoke(index)
            case None => throw HandlerMismatchException("no selection handler on ${listId}")
        }
    }

    // ── Backend implementation ──────────────────────────────────────────
    public func create(kind: ControlKind): ControlId {
        nextId = nextId + 1
        let id = ControlId(nextId)
        ops.add(Op.CreateOp(id, kind))
        id
    }

    public func setProp(id: ControlId, which: Prop, value: PropValue): Unit {
        ops.add(Op.SetPropOp(id, which, value))
    }

    func childList(parent: ControlId): ArrayList<ControlId> {
        match (children.get(parent)) {
            case Some(list) => list
            case None =>
                let list = ArrayList<ControlId>()
                children.add(parent, list)
                list
        }
    }

    public func appendChild(parent: ControlId, child: ControlId): Unit {
        childList(parent).add(child)
        ops.add(Op.AppendChildOp(parent, child))
    }

    public func insertChild(parent: ControlId, index: Int64, child: ControlId): Unit {
        let list = childList(parent)
        if (index < 0 || index > list.size) {
            throw IndexOutOfBoundsException("insertChild index ${index} out of bounds (len=${list.size})")
        }
        list.add(child, at: index)
        ops.add(Op.InsertChildOp(parent, index, child))
    }

    public func removeChild(parent: ControlId, index: Int64): Unit {
        let list = childList(parent)
        if (index < 0 || index >= list.size) {
            throw IndexOutOfBoundsException("removeChild index ${index} out of bounds (len=${list.size})")
        }
        list.remove(at: index)
        ops.add(Op.RemoveChildOp(parent, index))
    }

    public func replaceChild(parent: ControlId, index: Int64, newChild: ControlId): Unit {
        let list = childList(parent)
        if (index < 0 || index >= list.size) {
            throw IndexOutOfBoundsException("replaceChild index ${index} out of bounds (len=${list.size})")
        }
        list[index] = newChild
        ops.add(Op.ReplaceChildOp(parent, index, newChild))
    }

    public func moveChild(parent: ControlId, fromIndex: Int64, toIndex: Int64): Unit {
        let list = childList(parent)
        if (fromIndex < 0 || fromIndex >= list.size) {
            throw IndexOutOfBoundsException("moveChild from ${fromIndex} out of bounds (len=${list.size})")
        }
        if (toIndex < 0 || toIndex >= list.size) {
            throw IndexOutOfBoundsException("moveChild to ${toIndex} out of bounds (len=${list.size})")
        }
        if (fromIndex != toIndex) {
            let item = list[fromIndex]
            list.remove(at: fromIndex)
            list.add(item, at: toIndex)
        }
        ops.add(Op.MoveChildOp(parent, fromIndex, toIndex))
    }

    public func destroy(id: ControlId): Unit {
        children.remove(id)
        // Drop any handlers registered for this control.
        let toRemove = ArrayList<EventKey>()
        for ((k, _) in handlers) {
            if (k.idRaw == id.raw) { toRemove.add(k) }
        }
        for (k in toRemove) { handlers.remove(k) }
        ops.add(Op.DestroyOp(id))
    }

    public func attachEvent(id: ControlId, event: Event, handler: EventHandler): Unit {
        handlers.add(EventKey(id, event), handler)
        ops.add(Op.AttachEventOp(id, event, handler))
    }

    public func detachEvent(id: ControlId, event: Event): Unit {
        handlers.remove(EventKey(id, event))
        ops.add(Op.DetachEventOp(id, event))
    }

    public func setTemplatedItemCount(id: ControlId, count: Int64): Unit {
        itemCounts.add(id, count)
        ops.add(Op.SetTemplatedItemCountOp(id, count))
    }

    public func setTemplatedRowContent(listId: ControlId, rowIdx: Int64, content: ?ControlId): Unit {
        let slot = match (rowContents.get(listId)) {
            case Some(m) => m
            case None =>
                let m = HashMap<Int64, ControlId>()
                rowContents.add(listId, m)
                m
        }
        match (content) {
            case Some(c) =>
                slot.add(rowIdx, c)
                ops.add(Op.MountRowContentOp(listId, rowIdx, c))
            case None =>
                slot.remove(rowIdx)
                ops.add(Op.ClearRowContentOp(listId, rowIdx))
        }
    }

    public func setTemplatedSelectedIndex(id: ControlId, index: Int32): Unit {
        ops.add(Op.SetTemplatedSelectedIndexOp(id, index))
    }

    public func setTemplatedSelectionMode(id: ControlId, mode: SelectionMode): Unit {
        ops.add(Op.SetTemplatedSelectionModeOp(id, mode))
    }

    public func scrollTemplatedToIndex(id: ControlId, index: Int32): Unit {
        ops.add(Op.ScrollTemplatedToIndexOp(id, index))
    }

    public func attachTemplatedSelectionChanged(id: ControlId, handler: Callback<Int32>): Unit {
        selectionHandlers.add(id, handler)
        ops.add(Op.AttachTemplatedSelectionChangedOp(id))
    }

    public func attachTemplatedRealization(id: ControlId, realize: (Int64) -> Unit, recycle: (Int64) -> Unit): Unit {
        realizeHandlers.add(id, realize)
        recycleHandlers.add(id, recycle)
        ops.add(Op.AttachTemplatedRealizationOp(id))
    }

    public func setHeaderElement(id: ControlId, headerId: ?ControlId): Unit {
        ops.add(Op.SetHeaderElementOp(id, headerId))
    }

    public func setPaneElement(id: ControlId, paneId: ?ControlId): Unit {
        ops.add(Op.SetPaneElementOp(id, paneId))
    }

    public func setThemeBindings(id: ControlId, kind: ControlKind, bindings: Array<(Prop, ThemeRef)>): Unit {
        // Canonicalise by prop tag for a deterministic cache key.
        let key = themeCacheKey(kind, bindings)
        let cacheHit = themeStyleCache.contains(key)
        if (!cacheHit) { themeStyleCache.add(key) }
        themeBindingsLive.add(id, bindings)
        ops.add(Op.ApplyThemeBindingsOp(id, kind, bindings, cacheHit))
    }

    public func onThemeChanged(): Unit {
        themeStyleCache.clear()
        ops.add(Op.OnThemeChangedOp)
    }

    public func setImplicitTransitions(id: ControlId, transitions: ?ImplicitTransitions): Unit {
        ops.add(Op.SetImplicitTransitionsOp(id, transitions))
    }

    public func setLayoutAnimation(id: ControlId, config: ?LayoutAnimationConfig): Unit {
        ops.add(Op.SetLayoutAnimationOp(id, config))
    }

    public func runLayoutTranslationAnimation(id: ControlId, dx: Float64, dy: Float64,
                                              config: LayoutAnimationConfig): Unit {
        ops.add(Op.RunLayoutTranslationAnimationOp(id, dx, dy, config))
    }

    public func runPropertyAnimation(id: ControlId, config: ?AnimationConfig): Unit {
        ops.add(Op.RunPropertyAnimationOp(id, config))
    }

    public func setRichTextParagraphs(id: ControlId, paragraphs: Array<RichTextParagraph>): Unit {
        ops.add(Op.SetRichTextParagraphsOp(id, paragraphs))
    }

    public func setAccessibility(id: ControlId, accessibility: AccessibilityModifiers): Unit {
        ops.add(Op.SetAccessibilityOp(id, accessibility))
    }

    public func setKeyboardAccelerators(id: ControlId, accelerators: Array<KeyboardAccelerator>): Unit {
        ops.add(Op.SetKeyboardAcceleratorsOp(id, accelerators))
    }

    public func setTooltip(id: ControlId, tooltip: ?Tooltip): Unit {
        ops.add(Op.SetTooltipOp(id, tooltip))
    }

    public func setPointerHandlers(id: ControlId, handlers: ?PointerHandlers): Unit {
        ops.add(Op.SetPointerHandlersOp(id, handlers))
    }
}

func themeCacheKey(kind: ControlKind, bindings: Array<(Prop, ThemeRef)>): String {
    // Sort prop tags so equivalent binding sets canonicalise identically.
    let tags = ArrayList<Int64>()
    for (b in bindings) { tags.add(b[0].tag()) }
    sortInt64(tags)
    var s = "k${kind.tag()}"
    for (t in tags) { s = s + ":${t}" }
    s
}

func sortInt64(list: ArrayList<Int64>): Unit {
    // Simple insertion sort (binding lists are tiny).
    var i = 1
    while (i < list.size) {
        let v = list[i]
        var j = i - 1
        while (j >= 0 && list[j] > v) {
            list[j + 1] = list[j]
            j--
        }
        list[j + 1] = v
        i++
    }
}
