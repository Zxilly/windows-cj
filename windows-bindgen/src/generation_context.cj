package windows_bindgen

import windows_metadata.*

public class BindgenContext {
    public let index: TypeIndex
    public let config: BindgenConfig
    public let references: References
    public let typeMap: TypeMap
    public let warnings: WarningCollector

    public init(
        index: TypeIndex,
        config: BindgenConfig,
        references: References,
        typeMap: TypeMap,
        warnings: WarningCollector
    ) {
        this.index = index
        this.config = config
        this.references = references
        this.typeMap = typeMap
        this.warnings = warnings
    }
}

var activeBindgenContext_: Option<BindgenContext> = None
let currentNamespaceTL_: ThreadLocal<String> = ThreadLocal<String>()
let currentTypeNameTL_: ThreadLocal<String> = ThreadLocal<String>()

public func setBindgenContext(context: BindgenContext): Unit {
    activeBindgenContext_ = Some(context)
}

public func clearBindgenContext(): Unit {
    activeBindgenContext_ = None
    currentNamespaceTL_.set(Option<String>.None)
    currentTypeNameTL_.set(Option<String>.None)
}

public func bindgenContext(): Option<BindgenContext> {
    activeBindgenContext_
}

public func setCurrentNamespace(namespace: String): Unit {
    currentNamespaceTL_.set(Some(namespace))
}

public func currentNamespace(): String {
    match (currentNamespaceTL_.get()) {
        case Some(ns) => ns
        case None => ""
    }
}

public func setCurrentTypeName(name: String): Unit {
    currentTypeNameTL_.set(Some(name))
}

public func clearCurrentTypeName(): Unit {
    currentTypeNameTL_.set(Option<String>.None)
}

public func currentTypeName(): String {
    match (currentTypeNameTL_.get()) {
        case Some(name) => name
        case None => ""
    }
}
