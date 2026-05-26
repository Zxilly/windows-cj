package windows_interface_macro_generated_fixture

import std.sync.AtomicInt64
import windows_core as windows_core
import windows_core.{HString, InterfaceRef, toRef}
import windows_interface as windows_interface
import windows_interface.IInspectable
import windows_interface.macros.Interface
import windows_interface.macros.Implement
import windows_strings.debugObservedWindowsDeleteStringCount

@C
public struct Example_Foundation_EventRegistrationToken {
    public let value: Int64

    public init() {
        value = 0
    }

    public init(value: Int64) {
        this.value = value
    }
}

@Interface["11111111-2222-3333-4455-66778899aabb", "Example.Foundation.IWidget", "CreateInstance.innerInterface=Com;CreateInstance.result=Com;TryCreate.result=Com;GetTitle.value=HString;GetNames.names=Array<windows_core.HString>;TryAlias.aliasOut=Com;GetAliasText.textOut=HString"]
public interface Example_Foundation_IWidget <: IInspectable {
    func Ping(): Int32
    func CreateInstance(baseInterface: CPointer<Unit>, innerInterface: CPointer<CPointer<Unit>>, result: CPointer<CPointer<Unit>>): Int32
    func add_Completed(handler: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>, result: CPointer<Example_Foundation_EventRegistrationToken>): Int32
    func TryCreate(result: CPointer<CPointer<Unit>>): Int32
    func GetTitle(value: CPointer<CPointer<Unit>>): Int32
    func GetNames(namesSize: CPointer<UInt32>, names: CPointer<CPointer<CPointer<Unit>>>): Int32
    func TryAlias(aliasOut: CPointer<CPointer<Unit>>): Int32
    func GetAliasText(textOut: CPointer<CPointer<Unit>>): Int32
}

let failedOutputReleaseCount = AtomicInt64(0)
var failedOutputObjectHandle = CPointer<CPointer<windows_interface.IUnknownVtbl>>()
var failedOutputVtblHandle = CPointer<windows_interface.IUnknownVtbl>()
var failedOutputArrayRaw = CPointer<Unit>()

@C
func failedOutputReleaseThunk(_: CPointer<Unit>): UInt32 {
    let previous = failedOutputReleaseCount.fetchAdd(1)
    UInt32(previous + 1)
}

func failedOutputVtbl(): windows_interface.IUnknownVtbl {
    var vtbl = windows_interface.IUnknownVtbl()
    vtbl.Release = failedOutputReleaseThunk
    vtbl
}

func resetFailedOutputState(): Unit {
    failedOutputReleaseCount.store(0)
    failedOutputObjectHandle = CPointer<CPointer<windows_interface.IUnknownVtbl>>()
    failedOutputVtblHandle = CPointer<windows_interface.IUnknownVtbl>()
}

func allocateFailedOutputRaw(): CPointer<Unit> {
    failedOutputVtblHandle = unsafe {
        windows_interface.allocateNativeValue<windows_interface.IUnknownVtbl>(failedOutputVtbl())
    }
    failedOutputObjectHandle = unsafe {
        windows_interface.allocateNativeValue<CPointer<windows_interface.IUnknownVtbl>>(failedOutputVtblHandle)
    }
    CPointer<Unit>(failedOutputObjectHandle)
}

func freeFailedOutputRawStorage(): Unit {
    if (failedOutputObjectHandle.isNotNull()) {
        unsafe { windows_interface.freeNativeValue<CPointer<windows_interface.IUnknownVtbl>>(failedOutputObjectHandle) }
        failedOutputObjectHandle = CPointer<CPointer<windows_interface.IUnknownVtbl>>()
    }
    if (failedOutputVtblHandle.isNotNull()) {
        unsafe { windows_interface.freeNativeValue<windows_interface.IUnknownVtbl>(failedOutputVtblHandle) }
        failedOutputVtblHandle = CPointer<windows_interface.IUnknownVtbl>()
    }
}

@Implement[Example_Foundation_IWidget]
public class ThrowingExampleWidget {
    public func Ping(): Int32 {
        windows_core.S_OK.value
    }

    public func CreateInstance(
        baseInterface: CPointer<Unit>,
        innerInterface: CPointer<CPointer<Unit>>,
        result: CPointer<CPointer<Unit>>
    ): Int32 {
        let _ = baseInterface
        let _ = innerInterface
        let _ = result
        throw Exception("CreateInstance failure")
    }

    public func add_Completed(
        handler: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>,
        result: CPointer<Example_Foundation_EventRegistrationToken>
    ): Int32 {
        let _ = handler
        let _ = result
        throw windows_core.WindowsException(windows_core.E_INVALIDARG)
    }

    public func TryCreate(result: CPointer<CPointer<Unit>>): Int32 {
        if (result.isNotNull()) {
            unsafe { result.write(allocateFailedOutputRaw()) }
        }
        windows_core.E_FAIL.value
    }

    public func GetTitle(value: CPointer<CPointer<Unit>>): Int32 {
        if (value.isNotNull()) {
            let title = HString("macro-partial-title")
            unsafe { value.write(title.toSystemHandleCopy()) }
        }
        windows_core.E_FAIL.value
    }

    public func GetNames(namesSize: CPointer<UInt32>, names: CPointer<CPointer<CPointer<Unit>>>): Int32 {
        if (namesSize.isNotNull() && names.isNotNull()) {
            let raw = windows_core.coTaskMemAlloc(sizeOf<CPointer<Unit>>())
            if (raw.isNull()) {
                return windows_core.E_OUTOFMEMORY.value
            }
            failedOutputArrayRaw = raw
            let handles = CPointer<CPointer<Unit>>(raw)
            let text = HString("macro-array-name")
            unsafe { handles.write(text.toSystemHandleCopy()) }
            unsafe { namesSize.write(1u32) }
            unsafe { names.write(handles) }
        }
        windows_core.E_FAIL.value
    }

    public func TryAlias(aliasOut: CPointer<CPointer<Unit>>): Int32 {
        if (aliasOut.isNotNull()) {
            unsafe { aliasOut.write(allocateFailedOutputRaw()) }
        }
        windows_core.E_FAIL.value
    }

    public func GetAliasText(textOut: CPointer<CPointer<Unit>>): Int32 {
        if (textOut.isNotNull()) {
            let title = HString("macro-atypical-title")
            unsafe { textOut.write(title.toSystemHandleCopy()) }
        }
        windows_core.E_FAIL.value
    }
}

func requireRuntimeName(): HString {
    windows_core.runtimeClassNameOf<Example_Foundation_IWidget>()
}

func requireInterface(value: Example_Foundation_IWidget): InterfaceRef<Example_Foundation_IWidget> {
    toRef(value)
}

func bridgeKindIsValue(value: windows_interface.InterfaceParameterBridgeKind): Bool {
    match (value) {
        case windows_interface.InterfaceParameterBridgeKind.Value => true
        case _ => false
    }
}

func bridgeKindIsOutSlot(value: windows_interface.InterfaceParameterBridgeKind): Bool {
    match (value) {
        case windows_interface.InterfaceParameterBridgeKind.OutSlot => true
        case _ => false
    }
}

func requireVtblNoneBranchClearsOutSlots(): Int64 {
    let staleHandle = unsafe { windows_interface.allocateNativeValue<Int32>(123i32) }
    var innerInterface = CPointer<Unit>(staleHandle)
    var result = CPointer<Unit>(staleHandle)
    var token = Example_Foundation_EventRegistrationToken(99i64)
    let handler: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit> = { _, _ => () }
    var status = 0
    try {
        var vtbl = Example_Foundation_IWidgetVtbl.new()
        let createHr = unsafe {
            vtbl.CreateInstance(
                CPointer<Unit>(),
                CPointer<Unit>(),
                CPointer<CPointer<Unit>>(inout innerInterface),
                CPointer<CPointer<Unit>>(inout result)
            )
        }
        let tokenHr = unsafe {
            vtbl.add_Completed(
                CPointer<Unit>(),
                handler,
                CPointer<Example_Foundation_EventRegistrationToken>(inout token)
            )
        }
        if (createHr != windows_core.E_NOINTERFACE.value) {
            status = 10
        } else if (!innerInterface.isNull()) {
            status = 11
        } else if (!result.isNull()) {
            status = 12
        } else if (tokenHr != windows_core.E_NOINTERFACE.value) {
            status = 13
        } else if (token.value != 0) {
            status = 14
        }
    } finally {
        unsafe { windows_interface.freeNativeValue<Int32>(staleHandle) }
    }
    status
}

func requireDefaultVtblConstructorClearsOutSlotsBeforeNotImpl(): Int64 {
    let staleHandle = unsafe { windows_interface.allocateNativeValue<Int32>(321i32) }
    var innerInterface = CPointer<Unit>(staleHandle)
    var result = CPointer<Unit>(staleHandle)
    var token = Example_Foundation_EventRegistrationToken(99i64)
    let handler: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit> = { _, _ => () }
    var status = 0
    try {
        var vtbl = Example_Foundation_IWidgetVtbl()
        let createHr = unsafe {
            vtbl.CreateInstance(
                CPointer<Unit>(),
                CPointer<Unit>(),
                CPointer<CPointer<Unit>>(inout innerInterface),
                CPointer<CPointer<Unit>>(inout result)
            )
        }
        let tokenHr = unsafe {
            vtbl.add_Completed(
                CPointer<Unit>(),
                handler,
                CPointer<Example_Foundation_EventRegistrationToken>(inout token)
            )
        }
        if (createHr != windows_core.E_NOTIMPL.value) {
            status = 42
        } else if (!innerInterface.isNull()) {
            status = 43
        } else if (!result.isNull()) {
            status = 44
        } else if (tokenHr != windows_core.E_NOTIMPL.value) {
            status = 45
        } else if (token.value != 0) {
            status = 46
        }
    } finally {
        unsafe { windows_interface.freeNativeValue<Int32>(staleHandle) }
    }
    status
}

func requireVtblSomeBranchClearsOutSlotsAndTranslatesThrownExceptions(): Int64 {
    let staleHandle = unsafe { windows_interface.allocateNativeValue<Int32>(456i32) }
    var innerInterface = CPointer<Unit>(staleHandle)
    var result = CPointer<Unit>(staleHandle)
    var token = Example_Foundation_EventRegistrationToken(99i64)
    let handler: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit> = { _, _ => () }
    let object = ThrowingExampleWidget().toComObject()
    var status = 0
    try {
        var vtbl = Example_Foundation_IWidgetVtbl.new()
        let raw = object.asRaw()
        let createHr = unsafe {
            vtbl.CreateInstance(
                raw,
                CPointer<Unit>(),
                CPointer<CPointer<Unit>>(inout innerInterface),
                CPointer<CPointer<Unit>>(inout result)
            )
        }
        let tokenHr = unsafe {
            vtbl.add_Completed(
                raw,
                handler,
                CPointer<Example_Foundation_EventRegistrationToken>(inout token)
            )
        }
        if (createHr != windows_core.E_FAIL.value) {
            status = 20
        } else if (!innerInterface.isNull()) {
            status = 21
        } else if (!result.isNull()) {
            status = 22
        } else if (tokenHr != windows_core.E_INVALIDARG.value) {
            status = 23
        } else if (token.value != 0) {
            status = 24
        }
    } finally {
        object.close()
        unsafe { windows_interface.freeNativeValue<Int32>(staleHandle) }
    }
    status
}

func requireVtblFailedHRESULTReleasesPartialOutSlots(): Int64 {
    resetFailedOutputState()
    var result = CPointer<Unit>()
    let object = ThrowingExampleWidget().toComObject()
    var status = 0
    try {
        var vtbl = Example_Foundation_IWidgetVtbl.new()
        let raw = object.asRaw()
        let createHr = unsafe {
            vtbl.TryCreate(
                raw,
                CPointer<CPointer<Unit>>(inout result)
            )
        }
        if (createHr != windows_core.E_FAIL.value) {
            status = 32
        } else if (failedOutputReleaseCount.load() != 1) {
            status = 33
        } else if (!result.isNull()) {
            status = 34
        }
    } finally {
        object.close()
        freeFailedOutputRawStorage()
        resetFailedOutputState()
    }
    status
}

func requireVtblFailedHRESULTReleasesPartialHStringOutSlot(): Int64 {
    var value = CPointer<Unit>()
    let object = ThrowingExampleWidget().toComObject()
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    var status = 0
    try {
        var vtbl = Example_Foundation_IWidgetVtbl.new()
        let raw = object.asRaw()
        let titleHr = unsafe {
            vtbl.GetTitle(
                raw,
                CPointer<CPointer<Unit>>(inout value)
            )
        }
        if (titleHr != windows_core.E_FAIL.value) {
            status = 37
        } else if (debugObservedWindowsDeleteStringCount() - deleteBefore != 1) {
            status = 38
        } else if (!value.isNull()) {
            status = 39
        }
    } finally {
        if (value.isNotNull()) {
            windows_core.releaseSystemHStringHandle(value)
        }
        object.close()
    }
    status
}

func requireVtblFailedHRESULTReleasesPartialHStringArrayOutSlot(): Int64 {
    failedOutputArrayRaw = CPointer<Unit>()
    var namesSize = 99u32
    var names = CPointer<CPointer<Unit>>()
    let object = ThrowingExampleWidget().toComObject()
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    var status = 0
    try {
        var vtbl = Example_Foundation_IWidgetVtbl.new()
        let raw = object.asRaw()
        let namesHr = unsafe {
            vtbl.GetNames(
                raw,
                CPointer<UInt32>(inout namesSize),
                CPointer<CPointer<CPointer<Unit>>>(inout names)
            )
        }
        if (namesHr != windows_core.E_FAIL.value) {
            status = 47
        } else if (debugObservedWindowsDeleteStringCount() - deleteBefore != 1) {
            status = 48
        } else if (!names.isNull()) {
            status = 49
        } else if (namesSize != 0u32) {
            status = 50
        } else if (failedOutputArrayRaw.isNull()) {
            status = 51
        } else if (!windows_core.coTaskMemAllocationSize(failedOutputArrayRaw).isNone()) {
            status = 52
        }
    } finally {
        if (names.isNotNull()) {
            windows_core.winrtReleaseGenericArrayOut<HString>(CPointer<Unit>(names), namesSize)
        }
        if (failedOutputArrayRaw.isNotNull() && !windows_core.coTaskMemAllocationSize(failedOutputArrayRaw).isNone()) {
            windows_core.coTaskMemFree(failedOutputArrayRaw)
        }
        failedOutputArrayRaw = CPointer<Unit>()
        object.close()
    }
    status
}

func requireExplicitComCleanupSpecMarksAtypicalOutSlot(): Int64 {
    resetFailedOutputState()
    var aliasOut = CPointer<Unit>()
    let object = ThrowingExampleWidget().toComObject()
    var status = 0
    try {
        var vtbl = Example_Foundation_IWidgetVtbl.new()
        let raw = object.asRaw()
        let aliasHr = unsafe {
            vtbl.TryAlias(
                raw,
                CPointer<CPointer<Unit>>(inout aliasOut)
            )
        }
        if (aliasHr != windows_core.E_FAIL.value) {
            status = 54
        } else if (failedOutputReleaseCount.load() != 1) {
            status = 55
        } else if (!aliasOut.isNull()) {
            status = 56
        }
    } finally {
        object.close()
        freeFailedOutputRawStorage()
        resetFailedOutputState()
    }
    status
}

func requireExplicitHStringCleanupSpecMarksAtypicalOutSlot(): Int64 {
    var textOut = CPointer<Unit>()
    let object = ThrowingExampleWidget().toComObject()
    let deleteBefore = debugObservedWindowsDeleteStringCount()
    var status = 0
    try {
        var vtbl = Example_Foundation_IWidgetVtbl.new()
        let raw = object.asRaw()
        let textHr = unsafe {
            vtbl.GetAliasText(
                raw,
                CPointer<CPointer<Unit>>(inout textOut)
            )
        }
        if (textHr != windows_core.E_FAIL.value) {
            status = 57
        } else if (debugObservedWindowsDeleteStringCount() - deleteBefore != 1) {
            status = 58
        } else if (!textOut.isNull()) {
            status = 59
        }
    } finally {
        if (textOut.isNotNull()) {
            windows_core.releaseSystemHStringHandle(textOut)
        }
        object.close()
    }
    status
}

main(): Int64 {
    if (Example_Foundation_IWidget.runtimeName() != "Example.Foundation.IWidget") {
        return 1
    }
    let descriptor = Example_Foundation_IWidget.descriptor()
    if (descriptor.name != "Example.Foundation.IWidget") {
        return 1
    }
    if (descriptor.ownMethodCount != 8) {
        return 1
    }
    let schema = Example_Foundation_IWidget.descriptorSchema()
    if (schema.interfaceName != "Example.Foundation.IWidget") {
        return 1
    }
    if (schema.methods.size != 8) {
        return 1
    }
    if (schema.methods[1].name != "CreateInstance") {
        return 25
    }
    if (!bridgeKindIsValue(schema.methods[1].parameters[0].bridgeKind)) {
        return 26
    }
    if (!bridgeKindIsOutSlot(schema.methods[1].parameters[1].bridgeKind)) {
        return 27
    }
    if (!bridgeKindIsOutSlot(schema.methods[1].parameters[2].bridgeKind)) {
        return 28
    }
    if (schema.methods[2].name != "add_Completed") {
        return 29
    }
    if (!bridgeKindIsValue(schema.methods[2].parameters[0].bridgeKind)) {
        return 30
    }
    if (!bridgeKindIsOutSlot(schema.methods[2].parameters[1].bridgeKind)) {
        return 31
    }
    if (schema.methods[3].name != "TryCreate") {
        return 35
    }
    if (!bridgeKindIsOutSlot(schema.methods[3].parameters[0].bridgeKind)) {
        return 36
    }
    if (schema.methods[4].name != "GetTitle") {
        return 40
    }
    if (!bridgeKindIsOutSlot(schema.methods[4].parameters[0].bridgeKind)) {
        return 41
    }
    if (schema.methods[5].name != "GetNames") {
        return 53
    }
    if (schema.methods[6].name != "TryAlias") {
        return 60
    }
    if (!bridgeKindIsOutSlot(schema.methods[6].parameters[0].bridgeKind)) {
        return 61
    }
    if (schema.methods[7].name != "GetAliasText") {
        return 62
    }
    if (!bridgeKindIsOutSlot(schema.methods[7].parameters[0].bridgeKind)) {
        return 63
    }
    let outSlotStatus = requireVtblNoneBranchClearsOutSlots()
    if (outSlotStatus != 0) {
        return outSlotStatus
    }
    let defaultVtblStatus = requireDefaultVtblConstructorClearsOutSlotsBeforeNotImpl()
    if (defaultVtblStatus != 0) {
        return defaultVtblStatus
    }
    let liveOutSlotStatus = requireVtblSomeBranchClearsOutSlotsAndTranslatesThrownExceptions()
    if (liveOutSlotStatus != 0) {
        return liveOutSlotStatus
    }
    let failedHRESULTStatus = requireVtblFailedHRESULTReleasesPartialOutSlots()
    if (failedHRESULTStatus != 0) {
        return failedHRESULTStatus
    }
    let failedHStringStatus = requireVtblFailedHRESULTReleasesPartialHStringOutSlot()
    if (failedHStringStatus != 0) {
        return failedHStringStatus
    }
    let failedHStringArrayStatus = requireVtblFailedHRESULTReleasesPartialHStringArrayOutSlot()
    if (failedHStringArrayStatus != 0) {
        return failedHStringArrayStatus
    }
    let explicitComStatus = requireExplicitComCleanupSpecMarksAtypicalOutSlot()
    if (explicitComStatus != 0) {
        return explicitComStatus
    }
    let explicitHStringStatus = requireExplicitHStringCleanupSpecMarksAtypicalOutSlot()
    if (explicitHStringStatus != 0) {
        return explicitHStringStatus
    }
    0
}
