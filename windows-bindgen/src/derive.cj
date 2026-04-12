package windows_bindgen

public func writeDeriveAttributes(w: CodeWriter, namespace: String, name: String): Unit {
    match (bindgenContext()) {
        case Some(context) =>
            let derives = context.config.derivesForType(namespace, name)
            if (!derives.isEmpty()) {
                w.writeLine("@Derive[${joinArray(derives, ", ")}]")
            }
        case None => ()
    }
}

public func typeHasDerive(namespace: String, name: String, traitName: String): Bool {
    match (bindgenContext()) {
        case Some(context) =>
            return context.config.typeHasDerive(namespace, name, traitName)
        case None =>
            return false
    }
}

func joinArray(values: Array<String>, separator: String): String {
    if (values.isEmpty()) {
        return ""
    }

    var sb = StringBuilder()
    var i: Int64 = 0
    while (i < Int64(values.size)) {
        if (i > 0) {
            sb.append(separator)
        }
        sb.append(values[i])
        i += 1
    }
    return sb.toString()
}
