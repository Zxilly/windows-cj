package windows_reactor.core

import std.collection.*

// ============================================================================
// Diff helpers + prop apply/diff. These are the reference's
// reconciler/diff_helpers.rs `impl Reconciler` methods, lowered to free
// functions over a Backend (they only ever touch backend.setProp /
// attachEvent / detachEvent). Modifier-diff support helpers (option/animation
// comparison + clearing) also live here.
// ============================================================================

// diffOpt* — emit setProp(value) when changed, setProp(Unset) on Some -> None.

func diffOptF64(backend: Backend, id: ControlId, which: Prop, old: ?Float64, neu: ?Float64): Unit {
    if (optF64Eq(old, neu)) { return }
    match (neu) {
        case Some(v) => backend.setProp(id, which, PropValue.F64(v))
        case None => backend.setProp(id, which, PropValue.Unset)
    }
}

func diffOptThickness(backend: Backend, id: ControlId, which: Prop, old: ?Thickness, neu: ?Thickness): Unit {
    if (optEq<Thickness>(old, neu)) { return }
    match (neu) {
        case Some(v) => backend.setProp(id, which, PropValue.ThicknessV(v))
        case None => backend.setProp(id, which, PropValue.Unset)
    }
}

func diffOptHAlign(backend: Backend, id: ControlId, which: Prop, old: ?HorizontalAlignment, neu: ?HorizontalAlignment): Unit {
    if (optEq<HorizontalAlignment>(old, neu)) { return }
    match (neu) {
        case Some(v) => backend.setProp(id, which, PropValue.HAlign(v))
        case None => backend.setProp(id, which, PropValue.Unset)
    }
}

func diffOptVAlign(backend: Backend, id: ControlId, which: Prop, old: ?VerticalAlignment, neu: ?VerticalAlignment): Unit {
    if (optEq<VerticalAlignment>(old, neu)) { return }
    match (neu) {
        case Some(v) => backend.setProp(id, which, PropValue.VAlign(v))
        case None => backend.setProp(id, which, PropValue.Unset)
    }
}

func diffOptBrush(backend: Backend, id: ControlId, which: Prop, old: ?Brush, neu: ?Brush): Unit {
    if (optEq<Brush>(old, neu)) { return }
    match (neu) {
        case Some(v) => backend.setProp(id, which, PropValue.BrushV(v))
        case None => backend.setProp(id, which, PropValue.Unset)
    }
}

func diffOptStr(backend: Backend, id: ControlId, which: Prop, old: ?String, neu: ?String): Unit {
    if (optStrEq(old, neu)) { return }
    match (neu) {
        case Some(v) => backend.setProp(id, which, PropValue.Str(v))
        case None => backend.setProp(id, which, PropValue.Unset)
    }
}

// applyProps — lower a widget's binding list to setProp / attachEvent on mount.
func applyProps(backend: Backend, id: ControlId, bindings: PropBindings): Unit {
    for (b in bindings) {
        match (b) {
            case PropB(p, v) => backend.setProp(id, p, v)
            case EventB(e, hopt) =>
                match (hopt) {
                    case Some(h) => backend.attachEvent(id, e, h)
                    case None => ()
                }
        }
    }
}

// diffProps — emit setProp/attach/detach for new bindings that changed, then
// clear (Unset/detach) bindings that disappeared from the old list.
func diffProps(backend: Backend, id: ControlId, old: PropBindings, neu: PropBindings): Unit {
    for (b in neu) {
        match (b) {
            case PropB(p, v) =>
                match (findProp(old, p)) {
                    case Some(ov) => if (!ov.equals(v)) { backend.setProp(id, p, v) }
                    case None => backend.setProp(id, p, v)
                }
            case EventB(e, newH) =>
                let oldInner: ?EventHandler = match (findEvent(old, e)) {
                    case Some(h) => h
                    case None => None
                }
                if (eventHandlerOptEq(oldInner, newH)) { continue }
                match (newH) {
                    case Some(h) => backend.attachEvent(id, e, h)
                    case None => backend.detachEvent(id, e)
                }
        }
    }
    for (b in old) {
        match (b) {
            case PropB(p, _) =>
                match (findProp(neu, p)) {
                    case Some(_) => ()
                    case None => backend.setProp(id, p, PropValue.Unset)
                }
            case EventB(e, oldH) =>
                let stillPresent = match (findEvent(neu, e)) {
                    case Some(_) => true
                    case None => false
                }
                if (!stillPresent && oldH.isSome()) { backend.detachEvent(id, e) }
        }
    }
}

func eventHandlerOptEq(a: ?EventHandler, b: ?EventHandler): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.equals(y)
        case (None, None) => true
        case _ => false
    }
}

// ── Modifier-diff support helpers ───────────────────────────────────────────

func cloneStrMap(m: HashMap<String, String>): HashMap<String, String> {
    let out = HashMap<String, String>()
    for ((k, v) in m) { out.add(k, v) }
    out
}

// Flatten a themeBindings map into the (Prop, ThemeRef) array the backend wants.
func themeBindingArray(m: HashMap<Prop, ThemeRef>): Array<(Prop, ThemeRef)> {
    let out = ArrayList<(Prop, ThemeRef)>()
    for ((p, t) in m) { out.add((p, t)) }
    out.toArray()
}

// Extract the nested optional fields from an outer ?AnimationModifiers.
func optAnimImplicit(a: ?AnimationModifiers): ?ImplicitTransitions {
    match (a) { case Some(x) => x.implicitTransitions; case None => None }
}
func optAnimLayout(a: ?AnimationModifiers): ?LayoutAnimationConfig {
    match (a) { case Some(x) => x.layoutAnimation; case None => None }
}
func optAnimProperty(a: ?AnimationModifiers): ?AnimationConfig {
    match (a) { case Some(x) => x.propertyAnimation; case None => None }
}

func optAnimTransEq(a: ?ImplicitTransitions, b: ?ImplicitTransitions): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.equals(y)
        case (None, None) => true
        case _ => false
    }
}
func optLayoutEq(a: ?LayoutAnimationConfig, b: ?LayoutAnimationConfig): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.equals(y)
        case (None, None) => true
        case _ => false
    }
}
func optAnimCfgEq(a: ?AnimationConfig, b: ?AnimationConfig): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.equals(y)
        case (None, None) => true
        case _ => false
    }
}

// Drop an implicit-transitions value that is empty (mirrors filter(|t|!t.is_empty())).
func filterNonEmptyTransitions(t: ?ImplicitTransitions): ?ImplicitTransitions {
    match (t) {
        case Some(x) => if (x.isEmpty()) { None } else { Some(x) }
        case None => None
    }
}

func filterNonEmptyPointers(p: ?PointerHandlers): ?PointerHandlers {
    match (p) {
        case Some(x) => if (x.isEmpty()) { None } else { Some(x) }
        case None => None
    }
}

func tooltipOptEq(a: ?Tooltip, b: ?Tooltip): Bool {
    match ((a, b)) {
        case (Some(x), Some(y)) => x.equals(y)
        case (None, None) => true
        case _ => false
    }
}

func gridOrDefault(p: ?GridPlacement): GridPlacement {
    match (p) { case Some(g) => g; case None => GridPlacement.default() }
}
func canvasOrDefault(p: ?CanvasPosition): CanvasPosition {
    match (p) { case Some(c) => c; case None => CanvasPosition.default() }
}
func relativeOrDefault(p: ?RelativePanelAlignment): RelativePanelAlignment {
    match (p) { case Some(r) => r; case None => RelativePanelAlignment.default() }
}
