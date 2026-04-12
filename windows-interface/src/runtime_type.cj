package windows_interface

import windows_strings.*

// RuntimeTypeContract gives windows-implement a stable place to hang WinRT
// runtime-name and signature metadata once projection generation starts
// threading that information through descriptors.
public class RuntimeTypeContract {
    public let runtimeName: String
    public let signature: String
    public let defaultInterfaceIid: Option<GUID>

    public init(runtimeName: String, signature: String) {
        this.runtimeName = runtimeName
        this.signature = signature
        this.defaultInterfaceIid = None
    }

    public init(runtimeName: String, signature: String, defaultInterfaceIid: GUID) {
        this.runtimeName = runtimeName
        this.signature = signature
        this.defaultInterfaceIid = Some(defaultInterfaceIid)
    }
}

public interface RuntimeType {
    static func signature(): String

    static func runtimeType(): RuntimeTypeContract {
        let value = signature()
        RuntimeTypeContract(value, value)
    }
}

public interface RuntimeName <: RuntimeType {
    static func runtimeName(): String {
        ""
    }

    static func signature(): String {
        runtimeName()
    }

    static func runtimeType(): RuntimeTypeContract {
        let name = runtimeName()
        RuntimeTypeContract(name, signature())
    }
}

public func runtimeTypeFromName<T>(): RuntimeTypeContract where T <: RuntimeName {
    T.runtimeType()
}

public func runtimeClassNameOf<T>(): HString where T <: RuntimeName {
    HString(T.runtimeName())
}
