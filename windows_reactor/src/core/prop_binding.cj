package windows_reactor.core

import std.collection.*

// One entry of a widget's flat declarative binding list: either a property
// value or an event handler slot (which may be absent when the widget exposes
// the event but no handler is wired).
public enum Binding {
    | PropB(Prop, PropValue)
    | EventB(Event, ?EventHandler)
}

public type PropBindings = ArrayList<Binding>

// First property value bound to `which`, if any.
public func findProp(bindings: PropBindings, which: Prop): ?PropValue {
    for (b in bindings) {
        match (b) {
            case PropB(p, v) where p == which => return Some(v)
            case _ => ()
        }
    }
    None
}

// First event slot bound to `event`, if any. The outer Option distinguishes
// "event not present" (None) from "event present with no handler" (Some(None)).
public func findEvent(bindings: PropBindings, event: Event): ?(?EventHandler) {
    for (b in bindings) {
        match (b) {
            case EventB(e, h) where e == event => return Some(h)
            case _ => ()
        }
    }
    None
}
