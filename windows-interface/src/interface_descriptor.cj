package windows_interface

import std.collection.*

func containsGuid(values: ArrayList<GUID>, candidate: GUID): Bool {
    for (value in values) {
        if (value == candidate) {
            return true
        }
    }
    false
}

func appendUniqueGuid(values: ArrayList<GUID>, candidate: GUID): Unit {
    if (!containsGuid(values, candidate)) {
        values.add(candidate)
    }
}

func expandedAncestorIids(baseDescriptor: InterfaceDescriptorBase): Array<GUID> {
    let values = ArrayList<GUID>()
    appendUniqueGuid(values, baseDescriptor.descriptorIid())
    for (ancestor in baseDescriptor.descriptorAncestorIids()) {
        appendUniqueGuid(values, ancestor)
    }
    values.toArray()
}

public interface AbiPointerBacked {
    func asAbiPointer(): CPointer<Unit>
}

public interface ComInterface <: AbiPointerBacked {
    static func iid(): GUID
    func asRaw(): CPointer<Unit>
    func asAbiPointer(): CPointer<Unit> {
        asRaw()
    }
}

public interface InterfaceDescriptorBase {
    func descriptorName(): String
    func descriptorIid(): GUID
    func descriptorAncestorIids(): Array<GUID>
    func descriptorDirectBaseName(): Option<String>
    func descriptorDirectBase(): Option<InterfaceDescriptorBase>
    func descriptorOwnMethodCount(): Int64
}

public interface AbiReferenceDescriptorBase<T> {
    func descriptorName(): String
    func takeFromAbi(raw: CPointer<Unit>): T
    func viewOf(raw: CPointer<Unit>): T
    func addRefPointer(raw: CPointer<Unit>): UInt32
    func releasePointer(raw: CPointer<Unit>): UInt32
}

public class AbiReferenceDescriptor<T> <: AbiReferenceDescriptorBase<T> {
    public let name: String
    private let takeFromAbi_: (CPointer<Unit>) -> T
    private let viewOf_: (CPointer<Unit>) -> T
    private let addRefPointer_: (CPointer<Unit>) -> UInt32
    private let releasePointer_: (CPointer<Unit>) -> UInt32

    public init(name: String, wrap: (CPointer<Unit>) -> T) {
        this.name = name
        this.takeFromAbi_ = wrap
        this.viewOf_ = wrap
        this.addRefPointer_ = { _ => 0u32 }
        this.releasePointer_ = { _ => 0u32 }
    }

    public init(
        name: String,
        takeFromAbi: (CPointer<Unit>) -> T,
        viewOf: (CPointer<Unit>) -> T
    ) {
        this.name = name
        this.takeFromAbi_ = takeFromAbi
        this.viewOf_ = viewOf
        this.addRefPointer_ = { _ => 0u32 }
        this.releasePointer_ = { _ => 0u32 }
    }

    public init(
        name: String,
        takeFromAbi: (CPointer<Unit>) -> T,
        viewOf: (CPointer<Unit>) -> T,
        addRefPointer: (CPointer<Unit>) -> UInt32,
        releasePointer: (CPointer<Unit>) -> UInt32
    ) {
        this.name = name
        this.takeFromAbi_ = takeFromAbi
        this.viewOf_ = viewOf
        this.addRefPointer_ = addRefPointer
        this.releasePointer_ = releasePointer
    }

    public func descriptorName(): String {
        name
    }

    public func takeFromAbi(raw: CPointer<Unit>): T {
        takeFromAbi_(raw)
    }

    public func viewOf(raw: CPointer<Unit>): T {
        viewOf_(raw)
    }

    public func addRefPointer(raw: CPointer<Unit>): UInt32 {
        addRefPointer_(raw)
    }

    public func releasePointer(raw: CPointer<Unit>): UInt32 {
        releasePointer_(raw)
    }
}

// InterfaceDescriptor is the stable call-side contract: it names an interface,
// ties it to an IID, and knows how to wrap a successful QueryInterface result
// without taking ownership beyond the COM AddRef done by QueryInterface itself.
public class InterfaceDescriptor<T> <: InterfaceDescriptorBase & AbiReferenceDescriptorBase<T> {
    public let name: String
    public let iid: GUID
    public let ancestorIids: Array<GUID>
    public let ownMethodCount: Int64
    public var methods: Array<InterfaceMethodSchema> = []
    public var runtimeTypeContract: Option<RuntimeTypeContract> = None
    private let directBaseName_: Option<String>
    private let directBaseDescriptor_: Option<InterfaceDescriptorBase>
    private let takeFromAbi_: (CPointer<Unit>) -> T
    private let viewOf_: (CPointer<Unit>) -> T

    public prop baseIid: Option<GUID> {
        get() {
            if (ancestorIids.size == 0) {
                return None
            }
            Some(ancestorIids[0])
        }
    }

    public init(name: String, iid: GUID, wrap: (CPointer<Unit>) -> T) {
        this.name = name
        this.iid = iid
        this.ancestorIids = []
        this.ownMethodCount = 0
        this.directBaseName_ = None
        this.directBaseDescriptor_ = None
        this.takeFromAbi_ = wrap
        this.viewOf_ = wrap
    }

    public init(name: String, iid: GUID, baseIid: GUID, wrap: (CPointer<Unit>) -> T) {
        this.name = name
        this.iid = iid
        this.ancestorIids = [baseIid]
        this.ownMethodCount = 0
        this.directBaseName_ = None
        this.directBaseDescriptor_ = None
        this.takeFromAbi_ = wrap
        this.viewOf_ = wrap
    }

    public init(
        name: String,
        iid: GUID,
        baseDescriptor: InterfaceDescriptorBase,
        wrap: (CPointer<Unit>) -> T
    ) {
        this.name = name
        this.iid = iid
        this.ancestorIids = expandedAncestorIids(baseDescriptor)
        this.ownMethodCount = 0
        this.directBaseName_ = Some(baseDescriptor.descriptorName())
        this.directBaseDescriptor_ = Some(baseDescriptor)
        this.takeFromAbi_ = wrap
        this.viewOf_ = wrap
    }

    public init(
        name: String,
        iid: GUID,
        baseDescriptor: InterfaceDescriptorBase,
        wrap: (CPointer<Unit>) -> T,
        ownMethodCount!: Int64
    ) {
        this.name = name
        this.iid = iid
        this.ancestorIids = expandedAncestorIids(baseDescriptor)
        this.ownMethodCount = ownMethodCount
        this.directBaseName_ = Some(baseDescriptor.descriptorName())
        this.directBaseDescriptor_ = Some(baseDescriptor)
        this.takeFromAbi_ = wrap
        this.viewOf_ = wrap
    }

    public init(
        name: String,
        iid: GUID,
        ancestorIids: Array<GUID>,
        wrap: (CPointer<Unit>) -> T
    ) {
        this.name = name
        this.iid = iid
        this.ancestorIids = ancestorIids
        this.ownMethodCount = 0
        this.directBaseName_ = None
        this.directBaseDescriptor_ = None
        this.takeFromAbi_ = wrap
        this.viewOf_ = wrap
    }

    public init(
        name: String,
        iid: GUID,
        takeFromAbi: (CPointer<Unit>) -> T,
        viewOf: (CPointer<Unit>) -> T
    ) {
        this.name = name
        this.iid = iid
        this.ancestorIids = []
        this.ownMethodCount = 0
        this.directBaseName_ = None
        this.directBaseDescriptor_ = None
        this.takeFromAbi_ = takeFromAbi
        this.viewOf_ = viewOf
    }

    public init(
        name: String,
        iid: GUID,
        baseIid: GUID,
        takeFromAbi: (CPointer<Unit>) -> T,
        viewOf: (CPointer<Unit>) -> T
    ) {
        this.name = name
        this.iid = iid
        this.ancestorIids = [baseIid]
        this.ownMethodCount = 0
        this.directBaseName_ = None
        this.directBaseDescriptor_ = None
        this.takeFromAbi_ = takeFromAbi
        this.viewOf_ = viewOf
    }

    public init(
        name: String,
        iid: GUID,
        baseDescriptor: InterfaceDescriptorBase,
        takeFromAbi: (CPointer<Unit>) -> T,
        viewOf: (CPointer<Unit>) -> T
    ) {
        this.name = name
        this.iid = iid
        this.ancestorIids = expandedAncestorIids(baseDescriptor)
        this.ownMethodCount = 0
        this.directBaseName_ = Some(baseDescriptor.descriptorName())
        this.directBaseDescriptor_ = Some(baseDescriptor)
        this.takeFromAbi_ = takeFromAbi
        this.viewOf_ = viewOf
    }

    public init(
        name: String,
        iid: GUID,
        baseDescriptor: InterfaceDescriptorBase,
        takeFromAbi: (CPointer<Unit>) -> T,
        viewOf: (CPointer<Unit>) -> T,
        ownMethodCount!: Int64
    ) {
        this.name = name
        this.iid = iid
        this.ancestorIids = expandedAncestorIids(baseDescriptor)
        this.ownMethodCount = ownMethodCount
        this.directBaseName_ = Some(baseDescriptor.descriptorName())
        this.directBaseDescriptor_ = Some(baseDescriptor)
        this.takeFromAbi_ = takeFromAbi
        this.viewOf_ = viewOf
    }

    public init(
        name: String,
        iid: GUID,
        ancestorIids: Array<GUID>,
        takeFromAbi: (CPointer<Unit>) -> T,
        viewOf: (CPointer<Unit>) -> T
    ) {
        this.name = name
        this.iid = iid
        this.ancestorIids = ancestorIids
        this.ownMethodCount = 0
        this.directBaseName_ = None
        this.directBaseDescriptor_ = None
        this.takeFromAbi_ = takeFromAbi
        this.viewOf_ = viewOf
    }

    public func descriptorIid(): GUID {
        iid
    }

    public func descriptorAncestorIids(): Array<GUID> {
        ancestorIids
    }

    public func descriptorDirectBaseName(): Option<String> {
        directBaseName_
    }

    public func descriptorDirectBase(): Option<InterfaceDescriptorBase> {
        directBaseDescriptor_
    }

    public func descriptorOwnMethodCount(): Int64 {
        if (methods.size > 0) {
            return methods.size
        }
        ownMethodCount
    }

    public func descriptorName(): String {
        name
    }

    public prop directBaseName: Option<String> {
        get() {
            directBaseName_
        }
    }

    public func directBaseDescriptor(): Option<InterfaceDescriptorBase> {
        directBaseDescriptor_
    }

    public func takeFromAbi(raw: CPointer<Unit>): T {
        takeFromAbi_(raw)
    }

    public func viewOf(raw: CPointer<Unit>): T {
        viewOf_(raw)
    }

    public func addRefPointer(raw: CPointer<Unit>): UInt32 {
        addRefRaw(raw)
    }

    public func releasePointer(raw: CPointer<Unit>): UInt32 {
        releaseRaw(raw)
    }

    public func matches(iid: GUID): Bool {
        if (this.iid == iid) {
            return true
        }
        for (ancestor in ancestorIids) {
            if (ancestor == iid) {
                return true
            }
        }
        false
    }
}
