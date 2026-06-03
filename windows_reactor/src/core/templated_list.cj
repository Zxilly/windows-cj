package windows_reactor.core

import std.collection.*

// ============================================================================
// Templated (virtualised) list/grid/flip element. The item type is erased
// behind TemplatedListImpl so the reconciler can drive realization without
// knowing the concrete item type. The reference uses Rc identity for items_ptr
// equality; here the impl carries an identity token (UInt64) allocated per
// builder so same_items_as can compare without a real pointer.
// ============================================================================

public interface TemplatedListImpl {
    func itemCount(): Int64
    func buildItemView(index: Int64): Element
    func itemKey(index: Int64): ?String
    func selectedIndex(): Int32
    func invokeSelectionChanged(index: Int32): Unit
    // Identity token of the backing items collection (replaces Rc::as_ptr).
    func itemsToken(): UInt64
    // Type discriminator token (replaces TypeId) so distinct item types differ.
    func itemTypeToken(): UInt64
    func hasSelectionHandler(): Bool
    func rawSelectionCallback(): ?Callback<Int32>
}

class TemplatedTokenCounter {
    var next: UInt64 = 1
    func allocate(): UInt64 {
        let id = next
        next = next + 1
        id
    }
}
let templatedTokenCounter = TemplatedTokenCounter()

// Concrete generic cell. T is the item type; view builds an Element per item.
public class TemplatedListCell<T> <: TemplatedListImpl {
    let items: Array<T>
    let viewBuilder: (T, Int64) -> Element
    let keySelector: ?(T) -> String
    let onSelectionChanged: ?Callback<Int32>
    let selectedIndexValue: Int32
    let itemsTok: UInt64
    let typeTok: UInt64

    public init(items: Array<T>, viewBuilder: (T, Int64) -> Element,
                keySelector: ?(T) -> String, onSelectionChanged: ?Callback<Int32>,
                selectedIndexValue: Int32, typeTok: UInt64) {
        this.items = items
        this.viewBuilder = viewBuilder
        this.keySelector = keySelector
        this.onSelectionChanged = onSelectionChanged
        this.selectedIndexValue = selectedIndexValue
        this.itemsTok = templatedTokenCounter.allocate()
        this.typeTok = typeTok
    }

    public func itemCount(): Int64 { items.size }

    public func buildItemView(index: Int64): Element {
        if (index < 0 || index >= items.size) {
            return Element.EmptyEl
        }
        viewBuilder(items[index], index)
    }

    public func itemKey(index: Int64): ?String {
        if (index < 0 || index >= items.size) {
            return None
        }
        match (keySelector) {
            case Some(k) => Some(k(items[index]))
            case None => None
        }
    }

    public func selectedIndex(): Int32 { selectedIndexValue }

    public func invokeSelectionChanged(index: Int32): Unit {
        match (onSelectionChanged) {
            case Some(cb) => cb.invoke(index)
            case None => ()
        }
    }

    public func itemsToken(): UInt64 { itemsTok }
    public func itemTypeToken(): UInt64 { typeTok }
    public func hasSelectionHandler(): Bool { onSelectionChanged.isSome() }
    public func rawSelectionCallback(): ?Callback<Int32> { onSelectionChanged }
}

public class TemplatedListElement {
    public var key: ?String = None
    public var kind: TemplatedKind
    public var selectionMode: SelectionMode = SelectionMode.Single
    public var modifiers: Modifiers = Modifiers()
    public let itemsImpl: TemplatedListImpl

    public init(kind: TemplatedKind, itemsImpl: TemplatedListImpl) {
        this.kind = kind
        this.itemsImpl = itemsImpl
    }

    public func sameItemsAs(other: TemplatedListElement): Bool {
        itemsImpl.itemTypeToken() == other.itemsImpl.itemTypeToken() &&
        itemsImpl.itemsToken() == other.itemsImpl.itemsToken()
    }

    public func itemCount(): Int64 { itemsImpl.itemCount() }
    public func buildItemView(index: Int64): Element { itemsImpl.buildItemView(index) }
    public func itemKey(index: Int64): ?String { itemsImpl.itemKey(index) }
    public func selectedIndex(): Int32 { itemsImpl.selectedIndex() }
    public func invokeSelectionChanged(index: Int32): Unit { itemsImpl.invokeSelectionChanged(index) }
    public func hasSelectionHandler(): Bool { itemsImpl.hasSelectionHandler() }
    public func rawSelectionCallback(): ?Callback<Int32> { itemsImpl.rawSelectionCallback() }

    public func fullyKeyed(): Bool {
        var i: Int64 = 0
        let n = itemCount()
        while (i < n) {
            if (itemsImpl.itemKey(i).isNone()) { return false }
            i++
        }
        true
    }

    public func collectKeys(): Array<String> {
        let out = ArrayList<String>()
        var i: Int64 = 0
        let n = itemCount()
        while (i < n) {
            match (itemsImpl.itemKey(i)) {
                case Some(k) => out.add(k)
                case None => out.add("__pos_${i}")
            }
            i++
        }
        out.toArray()
    }

    // Structural equality used by Element diff: same key/kind/mode/modifiers
    // and the same backing items identity (mirrors reference Rc::ptr_eq).
    public func equivalent(other: TemplatedListElement): Bool {
        optStrEq(key, other.key) && kind == other.kind &&
        selectionMode == other.selectionMode &&
        modifiers.equivalent(other.modifiers) &&
        itemsImpl.itemsToken() == other.itemsImpl.itemsToken()
    }
}

// ── Builder + factories ─────────────────────────────────────────────────

public class TemplatedListBuilder<T> {
    let kind: TemplatedKind
    let items: Array<T>
    let viewBuilder: (T, Int64) -> Element
    var keySelector: ?(T) -> String = None
    var onSelectionChangedCb: ?Callback<Int32> = None
    var selectedIndexValue: Int32 = -1
    var selectionModeValue: SelectionMode = SelectionMode.Single
    var modifiersValue: Modifiers = Modifiers()
    var elementKey: ?String = None
    let typeTok: UInt64

    public init(kind: TemplatedKind, items: Array<T>, viewBuilder: (T, Int64) -> Element, typeTok: UInt64) {
        this.kind = kind
        this.items = items
        this.viewBuilder = viewBuilder
        this.typeTok = typeTok
    }

    public func withKeySelector(k: (T) -> String): This { keySelector = Some(k); this }
    public func selectedIndex(i: Int32): This { selectedIndexValue = i; this }
    public func onSelectionChanged(cb: (Int32) -> Unit): This {
        onSelectionChangedCb = Some(Callback<Int32>(cb))
        this
    }
    public func selectionMode(mode: SelectionMode): This { selectionModeValue = mode; this }
    public func withKey(k: String): This { elementKey = Some(k); this }
    public func width(v: Float64): This { modifiersValue.width = Some(v); this }
    public func height(v: Float64): This { modifiersValue.height = Some(v); this }

    public func build(): Element {
        let cell = TemplatedListCell<T>(items, viewBuilder, keySelector, onSelectionChangedCb,
            selectedIndexValue, typeTok)
        let el = TemplatedListElement(kind, cell)
        el.key = elementKey
        el.selectionMode = selectionModeValue
        el.modifiers = modifiersValue
        Element.TemplatedListEl(el)
    }
}

// Per-item-type identity tokens so distinct item types compare unequal in
// same_items_as (replaces TypeId). The caller supplies a stable token per
// element type; the generic factories below allocate one per call which is
// sufficient for headless diff tests.
public func listView<T>(items: Array<T>, view: (T, Int64) -> Element): TemplatedListBuilder<T> {
    TemplatedListBuilder<T>(TemplatedKind.ListView, items, view, templatedTokenCounter.allocate())
}
public func gridView<T>(items: Array<T>, view: (T, Int64) -> Element): TemplatedListBuilder<T> {
    TemplatedListBuilder<T>(TemplatedKind.GridView, items, view, templatedTokenCounter.allocate())
}
public func flipView<T>(items: Array<T>, view: (T, Int64) -> Element): TemplatedListBuilder<T> {
    TemplatedListBuilder<T>(TemplatedKind.FlipView, items, view, templatedTokenCounter.allocate())
}
