package windows_bindgen

import std.collection.*

// Support-package symbol tracking. The bindgen records every support-package
// reference it emits via `useSupportSymbol(pkg, name)`. At prelude time the
// per-namespace record drives precise import statements, replacing the
// historic wildcard imports that made Cangjie compilation prohibitively slow.

let supportSymbolUsage_: HashMap<String, HashMap<String, HashSet<String>>> =
    HashMap<String, HashMap<String, HashSet<String>>>()

public func useSupportSymbol(packageName: String, symbol: String): Unit {
    let ns = currentNamespace()
    if (ns.isEmpty() || symbol.isEmpty() || packageName.isEmpty()) {
        return
    }
    if (!supportSymbolUsage_.contains(ns)) {
        supportSymbolUsage_[ns] = HashMap<String, HashSet<String>>()
    }
    let perNamespace = supportSymbolUsage_[ns]
    if (!perNamespace.contains(packageName)) {
        perNamespace[packageName] = HashSet<String>()
    }
    perNamespace[packageName].add(symbol)
}

public func resetSupportSymbolUsage(): Unit {
    supportSymbolUsage_.clear()
}

public func supportSymbolsFor(namespace: String, packageName: String): ArrayList<String> {
    let result = ArrayList<String>()
    match (supportSymbolUsage_.get(namespace)) {
        case Some(perNamespace) =>
            match (perNamespace.get(packageName)) {
                case Some(symbols) =>
                    for (sym in symbols) {
                        result.add(sym)
                    }
                case None => ()
            }
        case None => ()
    }
    sortStrings(result)
    return result
}
