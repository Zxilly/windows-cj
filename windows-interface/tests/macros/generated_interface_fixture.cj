package windows_interface_macro_generated_fixture

import windows_core as windows_core
import windows_core.{HString, InterfaceRef, toRef}
import windows_interface as windows_interface
import windows_interface.IInspectable
import windows_interface.macros.Interface

@C
public struct Example_Foundation_EventRegistrationToken {
    public let value: Int64

    public init() {
        value = 0
    }
}

@Interface["11111111-2222-3333-4455-66778899aabb", "Example.Foundation.IWidget"]
public interface Example_Foundation_IWidget <: IInspectable {
    func Ping(): Int32
    func CreateInstance(baseInterface: CPointer<Unit>, innerInterface: CPointer<CPointer<Unit>>, result: CPointer<CPointer<Unit>>): Int32
    func add_Completed(handler: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>, result: CPointer<Example_Foundation_EventRegistrationToken>): Int32
}

func requireRuntimeName(): HString {
    windows_core.runtimeClassNameOf<Example_Foundation_IWidget>()
}

func requireInterface(value: Example_Foundation_IWidget): InterfaceRef<Example_Foundation_IWidget> {
    toRef(value)
}

main(): Int64 {
    if (Example_Foundation_IWidget.runtimeName() != "Example.Foundation.IWidget") {
        return 1
    }
    let descriptor = Example_Foundation_IWidget.descriptor()
    if (descriptor.name != "Example.Foundation.IWidget") {
        return 1
    }
    if (descriptor.ownMethodCount != 3) {
        return 1
    }
    let schema = Example_Foundation_IWidget.descriptorSchema()
    if (schema.interfaceName != "Example.Foundation.IWidget") {
        return 1
    }
    if (schema.methods.size != 3) {
        return 1
    }
    0
}
