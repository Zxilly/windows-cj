package windows_sync

import std.collection.*
import std.fs.*

public func writeCfg(path: String, resolved: ArrayList<FeatureSpec>): Unit {
    ensureParentDir(path)
    let cfgText = buildCfgText(resolved)
    File.writeTo(path, cfgText.toArray())
}

public func formatLinkOptions(resolved: ArrayList<FeatureSpec>): String {
    let items = ArrayList<String>()
    let seen = HashMap<String, Bool>()

    for (spec in resolved) {
        for (link in spec.links) {
            if (!seen.contains(link)) {
                seen.add(link, true)
                items.add(link)
            }
        }
    }

    return joinWithSpace(items)
}

func buildCfgText(resolved: ArrayList<FeatureSpec>): String {
    var text = ""
    for (spec in resolved) {
        text += "${spec.cfg} = \"on\"\n"
    }
    return text
}

func joinWithSpace(items: ArrayList<String>): String {
    var text = ""
    var i: Int64 = 0
    while (i < Int64(items.size)) {
        if (i > 0) {
            text += " "
        }
        text += items[i]
        i += 1
    }
    return text
}

func ensureParentDir(path: String): Unit {
    let dir = directoryOf(path)
    if (!exists(dir)) {
        Directory.create(dir, recursive: true)
    }
}

func directoryOf(path: String): String {
    let bytes = path.toArray()
    var lastSep: Int64 = -1
    var i: Int64 = 0
    while (i < Int64(bytes.size)) {
        if (bytes[i] == b'/' || bytes[i] == b'\\') {
            lastSep = i
        }
        i += 1
    }
    if (lastSep >= 0) {
        return String.fromUtf8(bytes[0..lastSep])
    }
    return "."
}

public func joinPath(base: String, child: String): String {
    if (base.isEmpty()) {
        return child
    }
    let last = base[base.size - 1]
    if (last == b'/' || last == b'\\') {
        return "${base}${child}"
    }
    return "${base}/${child}"
}
