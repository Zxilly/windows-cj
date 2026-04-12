package windows_bindgen

import std.collection.*
import std.sync.*
import windows_metadata.*

public class Warnings {
    private let messages_: ArrayList<String>

    public init() {
        this.messages_ = ArrayList<String>()
    }

    public init(messages: ArrayList<String>) {
        this.messages_ = ArrayList<String>()
        for (message in messages) {
            this.messages_.add(message)
        }
    }

    public func isEmpty(): Bool {
        messages_.isEmpty()
    }

    public func unwrap(): Unit {
        if (!isEmpty()) {
            throw Exception(toString())
        }
    }

    public func all(): ArrayList<String> {
        let result = ArrayList<String>()
        for (message in messages_) {
            result.add(message)
        }
        return result
    }

    public func toString(): String {
        return joinStrings(messages_, "\n")
    }
}

public class WarningCollector {
    private let messages_: ArrayList<String>
    private let mutex_: Mutex = Mutex()

    public init() {
        this.messages_ = ArrayList<String>()
    }

    public func add(message: String): Unit {
        mutex_.lock()
        messages_.add(message)
        mutex_.unlock()
    }

    public func skipMethod(
        method: MethodDefRef,
        dependencies: ArrayList<TypeName>,
        typeMap: TypeMap,
        config: BindgenConfig
    ): Unit {
        let missing = ArrayList<TypeName>()
        let references = config.references(method.attributeIndex())
        for (dependency in dependencies) {
            let dependencyName = dependency.definition()
            if (typeMap.containsType(dependencyName) || references.containsType(dependencyName.namespace, trimTick(dependencyName.name))) {
                continue
            }
            if (!containsTypeName(missing, dependencyName)) {
                missing.add(dependencyName)
            }
        }

        if (missing.isEmpty()) {
            return
        }

        sortTypeNames(missing)

        var sb = StringBuilder()
        sb.append("skipping `${method.owner().typeName()}.${method.name()}`")
        sb.append(" due to missing dependencies:")
        for (dependency in missing) {
            sb.append("\n  ")
            sb.append(dependency.toString())
        }
        add(sb.toString())
    }

    public func isEmpty(): Bool {
        messages_.isEmpty()
    }

    public func build(): Warnings {
        return Warnings(messages_)
    }

    public func contains(message: String): Bool {
        for (item in messages_) {
            if (item == message) {
                return true
            }
        }
        return false
    }

    public func all(): ArrayList<String> {
        let result = ArrayList<String>()
        for (message in messages_) {
            result.add(message)
        }
        return result
    }

    public func toString(): String {
        return joinStrings(messages_, "\n")
    }
}
