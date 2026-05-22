from __future__ import annotations

import argparse
import dataclasses
import difflib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COLLECTIONS_RUNTIME = ROOT / "windows-runtime" / "src" / "collections_runtime.cj"
RUNTIME_SRC = ROOT / "windows-runtime" / "src"


@dataclasses.dataclass(frozen=True)
class TypeSpec:
    name: str
    zero: str
    first: str
    second: str
    missing: str
    set_value: str
    insert_value: str
    append_value: str

    @property
    def snake(self) -> str:
        result: list[str] = []
        for index, ch in enumerate(self.name):
            if index > 0 and ch.isupper() and (not self.name[index - 1].isupper()):
                result.append("_")
            result.append(ch.lower())
        return "".join(result)

    @property
    def lower_name(self) -> str:
        if self.name.startswith("UInt"):
            return "uint" + self.name[len("UInt"):]
        return self.name[0].lower() + self.name[1:]

    @property
    def value_binding(self) -> str:
        return f"{self.lower_name}Value"


SPECS = {
    "Int16": TypeSpec("Int16", "0i16", "4i16", "6i16", "7i16", "40i16", "50i16", "60i16"),
    "UInt8": TypeSpec("UInt8", "0u8", "4u8", "6u8", "7u8", "40u8", "50u8", "60u8"),
    "UInt16": TypeSpec("UInt16", "0u16", "4u16", "6u16", "7u16", "40u16", "50u16", "60u16"),
    "Int64": TypeSpec("Int64", "0i64", "4i64", "6i64", "7i64", "40i64", "50i64", "60i64"),
    "UInt64": TypeSpec("UInt64", "0u64", "4u64", "6u64", "7u64", "40u64", "50u64", "60u64"),
}


def render_set_at_helper(spec: TypeSpec) -> str:
    return f"""func callVectorSetAt{spec.name}(
    slot: CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>,
    instanceRaw: CPointer<Unit>,
    index: UInt32,
    value: {spec.name}
): Unit {{
    let typedSlot = CFunc<(CPointer<Unit>, UInt32, {spec.name}) -> Int32>(CPointer<Unit>(slot))
    let hr = unsafe {{ typedSlot(instanceRaw, index, value) }}
    HRESULT(hr).check()
}}

"""


def render_insert_at_helper(spec: TypeSpec) -> str:
    return f"""func callVectorInsertAt{spec.name}(
    slot: CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>,
    instanceRaw: CPointer<Unit>,
    index: UInt32,
    value: {spec.name}
): Unit {{
    let typedSlot = CFunc<(CPointer<Unit>, UInt32, {spec.name}) -> Int32>(CPointer<Unit>(slot))
    let hr = unsafe {{ typedSlot(instanceRaw, index, value) }}
    HRESULT(hr).check()
}}

"""


def render_append_helper(spec: TypeSpec) -> str:
    return f"""func callVectorAppend{spec.name}(
    slot: CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32>,
    instanceRaw: CPointer<Unit>,
    value: {spec.name}
): Unit {{
    let typedSlot = CFunc<(CPointer<Unit>, {spec.name}) -> Int32>(CPointer<Unit>(slot))
    let hr = unsafe {{ typedSlot(instanceRaw, value) }}
    HRESULT(hr).check()
}}

"""


def render_vtbl_branch(spec: TypeSpec) -> str:
    return f"""        match ({spec.zero} as T) {{
            case Some(_) =>
                let indexOfAbi: CFunc<(CPointer<Unit>, {spec.name}, CPointer<UInt32>, CPointer<Bool>) -> Int32> = {{
                    instanceRaw, arg0, arg1, result__ =>
                    match (unsafe {{ asImplFromRaw<IVector_Impl<{spec.name}>>(instanceRaw) }}) {{
                        case Some(impl) =>
                            if (result__.isNull() || arg1.isNull()) {{
                                E_POINTER.value
                            }} else {{
                                clearCollectionIndexOutSlot(arg1)
                                clearCollectionBoolOutSlot(result__)
                                try {{
                                    match (impl.IndexOf(arg0, arg1)) {{
                                        case Result<Bool>.Ok(value) =>
                                            unsafe {{ result__.write(value) }}
                                            S_OK.value
                                        case Result<Bool>.Err(error) =>
                                            error.code().value
                                    }}
                                }} catch (error: windows_core.WindowsException) {{
                                    error.code().value
                                }} catch (_: Exception) {{
                                    windows_core.E_FAIL.value
                                }}
                            }}
                        case None =>
                            collectionNoInterfaceIndexBoolOut(arg1, result__)
                    }}
                }}
                vtbl.IndexOf = CFunc<(CPointer<Unit>, CPointer<Unit>, CPointer<UInt32>, CPointer<Bool>) -> Int32>(CPointer<Unit>(indexOfAbi))
                let setAtAbi: CFunc<(CPointer<Unit>, UInt32, {spec.name}) -> Int32> = {{
                    instanceRaw, arg0, arg1 =>
                    match (unsafe {{ asImplFromRaw<IVector_Impl<{spec.name}>>(instanceRaw) }}) {{
                        case Some(impl) =>
                            try {{
                                match (impl.SetAt(arg0, arg1)) {{
                                    case Result<Unit>.Ok(_) =>
                                        S_OK.value
                                    case Result<Unit>.Err(error) =>
                                        error.code().value
                                }}
                            }} catch (error: windows_core.WindowsException) {{
                                error.code().value
                            }} catch (_: Exception) {{
                                windows_core.E_FAIL.value
                            }}
                        case None =>
                            E_NOINTERFACE.value
                    }}
                }}
                vtbl.SetAt = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>(CPointer<Unit>(setAtAbi))
                let insertAtAbi: CFunc<(CPointer<Unit>, UInt32, {spec.name}) -> Int32> = {{ instanceRaw, arg0, arg1 =>
                    match (unsafe {{ asImplFromRaw<IVector_Impl<{spec.name}>>(instanceRaw) }}) {{
                        case Some(impl) =>
                            try {{
                                match (impl.InsertAt(arg0, arg1)) {{
                                    case Result<Unit>.Ok(_) =>
                                        S_OK.value
                                    case Result<Unit>.Err(error) =>
                                        error.code().value
                                }}
                            }} catch (error: windows_core.WindowsException) {{
                                error.code().value
                            }} catch (_: Exception) {{
                                windows_core.E_FAIL.value
                            }}
                        case None =>
                            E_NOINTERFACE.value
                    }}
                }}
                vtbl.InsertAt = CFunc<(CPointer<Unit>, UInt32, CPointer<Unit>) -> Int32>(CPointer<Unit>(insertAtAbi))
                let appendAbi: CFunc<(CPointer<Unit>, {spec.name}) -> Int32> = {{ instanceRaw, arg0 =>
                    match (unsafe {{ asImplFromRaw<IVector_Impl<{spec.name}>>(instanceRaw) }}) {{
                        case Some(impl) =>
                            try {{
                                match (impl.Append(arg0)) {{
                                    case Result<Unit>.Ok(_) =>
                                        S_OK.value
                                    case Result<Unit>.Err(error) =>
                                        error.code().value
                                }}
                            }} catch (error: windows_core.WindowsException) {{
                                error.code().value
                            }} catch (_: Exception) {{
                                windows_core.E_FAIL.value
                            }}
                        case None =>
                            E_NOINTERFACE.value
                    }}
                }}
                vtbl.Append = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Int32>(CPointer<Unit>(appendAbi))
            case None => ()
        }}
"""


def render_new_factory(spec: TypeSpec) -> str:
    return f"""    public static func new{spec.name}<Identity>(offset!: Int64 = 0): IVectorVtbl where Identity <: IVector_Impl<{spec.name}> {{
        IVectorVtbl.new<Identity, {spec.name}>(offset: offset)
    }}

"""


def render_index_of_wrapper_case(spec: TypeSpec) -> str:
    return f"            case {spec.value_binding}: {spec.name} => return callVectorViewIndexOf{spec.name}(v.IndexOf, asRaw(), {spec.value_binding}, index)\n"


def render_set_at_wrapper_case(spec: TypeSpec) -> str:
    return f"            case {spec.value_binding}: {spec.name} =>\n                callVectorSetAt{spec.name}(v.SetAt, asRaw(), index, {spec.value_binding})\n                return\n"


def render_insert_at_wrapper_case(spec: TypeSpec) -> str:
    return f"            case {spec.value_binding}: {spec.name} =>\n                callVectorInsertAt{spec.name}(v.InsertAt, asRaw(), index, {spec.value_binding})\n                return\n"


def render_append_wrapper_case(spec: TypeSpec) -> str:
    return f"            case {spec.value_binding}: {spec.name} =>\n                callVectorAppend{spec.name}(v.Append, asRaw(), {spec.value_binding})\n                return\n"


def insert_before(text: str, needle: str, snippet: str, exists_marker: str) -> str:
    if exists_marker in text:
        return text
    index = text.find(needle)
    if index < 0:
        raise RuntimeError(f"anchor not found: {needle!r}")
    return text[:index] + snippet + text[index:]


def insert_after(text: str, needle: str, snippet: str, exists_marker: str) -> str:
    if exists_marker in text:
        return text
    index = text.find(needle)
    if index < 0:
        raise RuntimeError(f"anchor not found: {needle!r}")
    index += len(needle)
    return text[:index] + snippet + text[index:]


def find_region(text: str, start_marker: str, end_marker: str) -> tuple[int, int]:
    start_index = text.find(start_marker)
    if start_index < 0:
        raise RuntimeError(f"region start not found: {start_marker!r}")
    end_index = text.find(end_marker, start_index + len(start_marker))
    if end_index < 0:
        raise RuntimeError(f"region end not found after {start_marker!r}: {end_marker!r}")
    return start_index, end_index


def insert_before_in_region(
    text: str,
    start_marker: str,
    end_marker: str,
    needle: str,
    snippet: str,
    exists_marker: str,
) -> str:
    start_index, end_index = find_region(text, start_marker, end_marker)
    region = text[start_index:end_index]
    if exists_marker in region:
        return text
    needle_index = region.find(needle)
    if needle_index < 0:
        raise RuntimeError(f"anchor not found in region {start_marker!r}: {needle!r}")
    absolute_index = start_index + needle_index
    return text[:absolute_index] + snippet + text[absolute_index:]


def method_bounds(text: str, method_name: str) -> tuple[int, int]:
    class_marker = "public class IVector<T>"
    class_index = text.find(class_marker)
    if class_index < 0:
        raise RuntimeError(f"class not found: {class_marker}")
    method_marker = f"    public unsafe func {method_name}"
    method_index = text.find(method_marker, class_index)
    if method_index < 0:
        raise RuntimeError(f"method not found: {method_name}")
    next_markers = [
        "\n    public unsafe func ",
        "\n    public func ",
        "\n    public prop ",
        "\n}",
    ]
    candidates = [
        index for marker in next_markers
        if (index := text.find(marker, method_index + len(method_marker))) >= 0
    ]
    if len(candidates) == 0:
        raise RuntimeError(f"method end not found: {method_name}")
    return method_index, min(candidates)


def add_wrapper_case(text: str, method_name: str, anchor_case: str, snippet: str, exists_marker: str) -> str:
    method_index, method_end = method_bounds(text, method_name)
    method_text = text[method_index:method_end]
    if exists_marker in method_text:
        return text
    anchor_offset = method_text.find(anchor_case)
    if anchor_offset < 0:
        raise RuntimeError(f"wrapper anchor not found in {method_name}: {anchor_case!r}")
    anchor_index = method_index + anchor_offset
    if anchor_index < 0:
        raise RuntimeError(f"wrapper anchor not found in {method_name}: {anchor_case!r}")
    return text[:anchor_index] + snippet + text[anchor_index:]


def update_collections_runtime(spec: TypeSpec) -> None:
    text = COLLECTIONS_RUNTIME.read_text(encoding="utf-8")
    text = insert_before(
        text,
        "func callVectorSetAtBool(",
        render_set_at_helper(spec),
        f"func callVectorSetAt{spec.name}(",
    )
    text = insert_before(
        text,
        "func callVectorInsertAtBool(",
        render_insert_at_helper(spec),
        f"func callVectorInsertAt{spec.name}(",
    )
    text = insert_before(
        text,
        "func callVectorAppendBool(",
        render_append_helper(spec),
        f"func callVectorAppend{spec.name}(",
    )
    text = insert_before_in_region(
        text,
        "    public static func new<Identity, T>(offset!: Int64 = 0): IVectorVtbl",
        "    public static func newInt32<Identity>",
        "        match (true as T) {",
        render_vtbl_branch(spec),
        f"match ({spec.zero} as T)",
    )
    text = insert_before_in_region(
        text,
        "public struct IVectorVtbl",
        "public interface IVector_ImplErased",
        "    public static func newBool<Identity>",
        render_new_factory(spec),
        f"public static func new{spec.name}<Identity>",
    )

    text = add_wrapper_case(
        text,
        "IndexOf(value: T, index: CPointer<UInt32>): Bool",
        "            case boolValue: Bool => return callVectorViewIndexOfBool",
        render_index_of_wrapper_case(spec),
        f"case {spec.value_binding}: {spec.name} => return callVectorViewIndexOf{spec.name}",
    )
    text = add_wrapper_case(
        text,
        "SetAt(index: UInt32, value: T): Unit",
        "            case boolValue: Bool =>",
        render_set_at_wrapper_case(spec),
        f"callVectorSetAt{spec.name}(v.SetAt",
    )
    text = add_wrapper_case(
        text,
        "InsertAt(index: UInt32, value: T): Unit",
        "            case boolValue: Bool =>",
        render_insert_at_wrapper_case(spec),
        f"callVectorInsertAt{spec.name}(v.InsertAt",
    )
    text = add_wrapper_case(
        text,
        "Append(value: T): Unit",
        "            case boolValue: Bool =>",
        render_append_wrapper_case(spec),
        f"callVectorAppend{spec.name}(v.Append",
    )

    COLLECTIONS_RUNTIME.write_text(text, encoding="utf-8")


def render_vector_test(spec: TypeSpec) -> str:
    return f"""package windows_runtime

import windows_interface as windows_interface
import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import windows_core.{{E_POINTER, Result, S_OK, WinError, createComObjectFromSchemas}}

class {spec.name}VectorAbiTestImpl <: IVector_Impl<{spec.name}> & Resource {{
    private let items: ArrayList<{spec.name}>
    private let vtblHandle: CPointer<IVectorVtbl>
    private let iterableVtblHandle: CPointer<IIterableVtbl>
    private var closed: Bool = false

    public init(items: ArrayList<{spec.name}>) {{
        this.items = items
        this.vtblHandle = unsafe {{
            windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.new{spec.name}<{spec.name}VectorAbiTestImpl>())
        }}
        this.iterableVtblHandle = unsafe {{
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<{spec.name}VectorAbiTestImpl, {spec.name}>())
        }}
    }}

    public static func withGenericVtbl(items: ArrayList<{spec.name}>): {spec.name}VectorAbiTestImpl {{
        {spec.name}VectorAbiTestImpl(items, genericVtbl: true)
    }}

    private init(items: ArrayList<{spec.name}>, genericVtbl!: Bool) {{
        this.items = items
        this.vtblHandle = unsafe {{
            if (genericVtbl) {{
                windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.new<{spec.name}VectorAbiTestImpl, {spec.name}>())
            }} else {{
                windows_interface.allocateNativeValue<IVectorVtbl>(IVectorVtbl.new{spec.name}<{spec.name}VectorAbiTestImpl>())
            }}
        }}
        this.iterableVtblHandle = unsafe {{
            windows_interface.allocateNativeValue<IIterableVtbl>(IIterableVtbl.new<{spec.name}VectorAbiTestImpl, {spec.name}>())
        }}
    }}

    public func vtblPtr(): CPointer<Unit> {{
        CPointer<Unit>(vtblHandle)
    }}

    public func iterableVtblPtr(): CPointer<Unit> {{
        CPointer<Unit>(iterableVtblHandle)
    }}

    public func close(): Unit {{
        if (closed) {{
            return
        }}
        unsafe {{
            windows_interface.freeNativeValue(iterableVtblHandle)
            windows_interface.freeNativeValue(vtblHandle)
        }}
        closed = true
    }}

    public func isClosed(): Bool {{
        closed
    }}

    ~init() {{
        if (closed) {{
            return
        }}
        closed = true
    }}

    public func First(): Result<IIterator<{spec.name}>> {{
        Result<IIterator<{spec.name}>>.Ok(toIterator<{spec.name}>(items))
    }}

    public func GetAt(index: UInt32): Result<{spec.name}> {{
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {{
            return Result<{spec.name}>.Err(stockBoundsError())
        }}
        match (items.get(resolved)) {{
            case Some(value) => Result<{spec.name}>.Ok(value)
            case None => Result<{spec.name}>.Err(stockBoundsError())
        }}
    }}

    public func Size(): Result<UInt32> {{
        Result<UInt32>.Ok(UInt32(items.size))
    }}

    public func GetView(): Result<IVectorView<{spec.name}>> {{
        Result<IVectorView<{spec.name}>>.Ok(create{spec.name}VectorViewAbiTest(items))
    }}

    public func IndexOf(value: {spec.name}, indexSlot: CPointer<UInt32>): Result<Bool> {{
        var offset = 0
        while (offset < items.size) {{
            match (items.get(offset)) {{
                case Some(candidate) =>
                    if (candidate == value) {{
                        if (indexSlot.isNotNull()) {{
                            unsafe {{ indexSlot.write(UInt32(offset)) }}
                        }}
                        return Result<Bool>.Ok(true)
                    }}
                case None => ()
            }}
            offset += 1
        }}
        if (indexSlot.isNotNull()) {{
            unsafe {{ indexSlot.write(0u32) }}
        }}
        Result<Bool>.Ok(false)
    }}

    public func SetAt(index: UInt32, value: {spec.name}): Result<Unit> {{
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {{
            return Result<Unit>.Err(stockBoundsError())
        }}
        items[resolved] = value
        Result<Unit>.Ok(())
    }}

    public func InsertAt(index: UInt32, value: {spec.name}): Result<Unit> {{
        let resolved = Int64(index)
        if (resolved < 0 || resolved > items.size) {{
            return Result<Unit>.Err(stockBoundsError())
        }}
        items.add(value, at: resolved)
        Result<Unit>.Ok(())
    }}

    public func RemoveAt(index: UInt32): Result<Unit> {{
        let resolved = Int64(index)
        if (resolved < 0 || resolved >= items.size) {{
            return Result<Unit>.Err(stockBoundsError())
        }}
        items.remove(at: resolved)
        Result<Unit>.Ok(())
    }}

    public func Append(value: {spec.name}): Result<Unit> {{
        items.add(value)
        Result<Unit>.Ok(())
    }}

    public func RemoveAtEnd(): Result<Unit> {{
        if (items.size == 0) {{
            return Result<Unit>.Err(stockBoundsError())
        }}
        items.remove(at: items.size - 1)
        Result<Unit>.Ok(())
    }}

    public func Clear(): Result<Unit> {{
        items.clear()
        Result<Unit>.Ok(())
    }}

    public func GetMany(startIndex: UInt32, itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<UInt32> {{
        writeGenericManyRange<{spec.name}>(itemsSize, itemsBuffer, items, Int64(startIndex))
    }}

    public func ReplaceAll(itemsSize: UInt32, itemsBuffer: CPointer<Unit>): Result<Unit> {{
        if (itemsSize > 0u32 && itemsBuffer.isNull()) {{
            return Result<Unit>.Err(WinError(E_POINTER))
        }}
        items.clear()
        let typed = CPointer<{spec.name}>(itemsBuffer)
        var offset = 0u32
        while (offset < itemsSize) {{
            items.add(unsafe {{ (typed + Int64(offset)).read() }})
            offset += 1u32
        }}
        Result<Unit>.Ok(())
    }}
}}

class {spec.name}VectorAbiTestFixture <: Resource {{
    public let vector: IVector<{spec.name}>
    private let impl: {spec.name}VectorAbiTestImpl
    private var closed: Bool = false

    public init(items: ArrayList<{spec.name}>, useGenericVtbl!: Bool = false) {{
        impl = if (useGenericVtbl) {{
            {spec.name}VectorAbiTestImpl.withGenericVtbl(items)
        }} else {{
            {spec.name}VectorAbiTestImpl(items)
        }}

        let schemas = [IIterable<{spec.name}>.descriptorSchema(), IVector<{spec.name}>.descriptorSchema()]
        let vtbls = [impl.iterableVtblPtr(), impl.vtblPtr()]
        let object = createComObjectFromSchemas(impl, schemas, vtbls)
        vector = object.toInterface(IVector<{spec.name}>.descriptor())
        object.close()
    }}

    public func innerClosed(): Bool {{
        impl.isClosed()
    }}

    public func isClosed(): Bool {{
        closed
    }}

    public func close(): Unit {{
        if (!closed) {{
            vector.close()
            closed = true
        }}
    }}
}}

func create{spec.name}VectorAbiTest(items: ArrayList<{spec.name}>): {spec.name}VectorAbiTestFixture {{
    {spec.name}VectorAbiTestFixture(items)
}}

func createGenericBuilder{spec.name}VectorAbiTest(items: ArrayList<{spec.name}>): {spec.name}VectorAbiTestFixture {{
    {spec.name}VectorAbiTestFixture(items, useGenericVtbl: true)
}}

@Test
func test{spec.name}VectorUsesDirectValueAbiForMutableSlots() {{
    let fixture = create{spec.name}VectorAbiTest(ArrayList<{spec.name}>([{spec.first}, {spec.second}]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    @Expect(unsafe {{ vector.GetAt(1u32) }}, {spec.second})
    var wrapperIndex = 99u32
    @Expect(unsafe {{ vector.IndexOf({spec.first}, CPointer<UInt32>(inout wrapperIndex)) }}, true)
    @Expect(wrapperIndex, 0u32)

    let vtbl = unsafe {{ vector.vtbl() }}
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, {spec.name}, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe {{ directIndexOf(
        vector.asRaw(),
        {spec.second},
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }}
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {{
        directIndexOf(vector.asRaw(), {spec.second}, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }}
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directSetAt = CFunc<(CPointer<Unit>, UInt32, {spec.name}) -> Int32>(CPointer<Unit>(vtbl.SetAt))
    let setAtHr = unsafe {{ directSetAt(vector.asRaw(), 0u32, {spec.set_value}) }}
    @Expect(setAtHr, S_OK.value)
    @Expect(unsafe {{ vector.GetAt(0u32) }}, {spec.set_value})

    let directInsertAt = CFunc<(CPointer<Unit>, UInt32, {spec.name}) -> Int32>(CPointer<Unit>(vtbl.InsertAt))
    let insertAtHr = unsafe {{ directInsertAt(vector.asRaw(), 1u32, {spec.insert_value}) }}
    @Expect(insertAtHr, S_OK.value)
    @Expect(unsafe {{ vector.GetAt(1u32) }}, {spec.insert_value})

    let directAppend = CFunc<(CPointer<Unit>, {spec.name}) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe {{ directAppend(vector.asRaw(), {spec.append_value}) }}
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe {{ vector.GetAt(3u32) }}, {spec.append_value})

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}}

@Test
func testGeneric{spec.name}VectorBuilderUsesDirectValueAbiForSpecialization() {{
    let fixture = createGenericBuilder{spec.name}VectorAbiTest(ArrayList<{spec.name}>([{spec.first}, {spec.second}]))
    let vector = fixture.vector
    @Expect(fixture.innerClosed(), false)

    let vtbl = unsafe {{ vector.vtbl() }}
    var directIndex = 99u32
    var directFound = false
    let directIndexOf = CFunc<(CPointer<Unit>, {spec.name}, CPointer<UInt32>, CPointer<Bool>) -> Int32>(
        CPointer<Unit>(vtbl.IndexOf)
    )
    let indexOfHr = unsafe {{ directIndexOf(
        vector.asRaw(),
        {spec.second},
        CPointer<UInt32>(inout directIndex),
        CPointer<Bool>(inout directFound)
    ) }}
    @Expect(indexOfHr, S_OK.value)
    @Expect(directFound, true)
    @Expect(directIndex, 1u32)

    var nullIndexFound = true
    let nullIndexHr = unsafe {{
        directIndexOf(vector.asRaw(), {spec.second}, CPointer<UInt32>(), CPointer<Bool>(inout nullIndexFound))
    }}
    @Expect(nullIndexHr, E_POINTER.value)
    @Expect(nullIndexFound, true)

    let directAppend = CFunc<(CPointer<Unit>, {spec.name}) -> Int32>(CPointer<Unit>(vtbl.Append))
    let appendHr = unsafe {{ directAppend(vector.asRaw(), {spec.missing}) }}
    @Expect(appendHr, S_OK.value)
    @Expect(unsafe {{ vector.GetAt(2u32) }}, {spec.missing})

    fixture.close()
    @Expect(fixture.innerClosed(), true)
}}
"""

def write_vector_test(spec: TypeSpec) -> None:
    path = RUNTIME_SRC / f"vector_{spec.snake}_abi_test.cj"
    path.write_text(render_vector_test(spec), encoding="utf-8")


def check_vector_test(spec: TypeSpec) -> bool:
    path = RUNTIME_SRC / f"vector_{spec.snake}_abi_test.cj"
    expected = render_vector_test(spec)
    if not path.exists():
        print(f"missing generated test: {path}")
        return False
    actual = path.read_text(encoding="utf-8")
    if actual == expected:
        return True
    diff = difflib.unified_diff(
        actual.splitlines(),
        expected.splitlines(),
        fromfile=str(path),
        tofile=f"{path} (generated)",
        lineterm="",
    )
    print("\n".join(diff))
    return False


def collections_runtime_fragments(spec: TypeSpec) -> list[tuple[str, str]]:
    return [
        (f"callVectorSetAt{spec.name}", render_set_at_helper(spec)),
        (f"callVectorInsertAt{spec.name}", render_insert_at_helper(spec)),
        (f"callVectorAppend{spec.name}", render_append_helper(spec)),
        (f"IVectorVtbl.new<{spec.name}> branch", render_vtbl_branch(spec)),
        (f"IVectorVtbl.new{spec.name}", render_new_factory(spec)),
        (f"IndexOf wrapper case for {spec.name}", render_index_of_wrapper_case(spec)),
        (f"SetAt wrapper case for {spec.name}", render_set_at_wrapper_case(spec)),
        (f"InsertAt wrapper case for {spec.name}", render_insert_at_wrapper_case(spec)),
        (f"Append wrapper case for {spec.name}", render_append_wrapper_case(spec)),
    ]


def check_collections_runtime(spec: TypeSpec) -> bool:
    if not COLLECTIONS_RUNTIME.exists():
        print(f"missing collections runtime: {COLLECTIONS_RUNTIME}")
        return False
    actual = COLLECTIONS_RUNTIME.read_text(encoding="utf-8")
    ok = True
    seen_labels: set[str] = set()
    seen_snippets: set[str] = set()
    for label, snippet in collections_runtime_fragments(spec):
        if not label or label in seen_labels:
            print(f"duplicate or empty collections runtime fragment label for {spec.name}: {label!r}")
            ok = False
        seen_labels.add(label)
        if not snippet or snippet in seen_snippets:
            print(f"duplicate or empty collections runtime fragment body for {spec.name}: {label}")
            ok = False
        seen_snippets.add(snippet)
        count = actual.count(snippet) if snippet else 0
        if count == 0:
            print(f"missing generated collections runtime fragment for {spec.name}: {label}")
            ok = False
        elif count > 1 and "wrapper case" not in label:
            print(f"duplicated generated collections runtime fragment for {spec.name}: {label} ({count} copies)")
            ok = False
    return ok


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate one WinRT IVector<T> direct input ABI specialization.")
    parser.add_argument(
        "--type",
        choices=sorted(SPECS),
        help="Cangjie scalar type to generate. Omit with --check-* to check every generated vector ABI specialization.",
    )
    parser.add_argument("--collections", action="store_true", help="Update collections_runtime.cj for this one type.")
    parser.add_argument("--test", action="store_true", help="Generate the vector ABI test file for this one type.")
    parser.add_argument("--check-test", action="store_true", help="Check that the vector ABI test file matches the generator.")
    parser.add_argument("--check-collections", action="store_true", help="Check collections_runtime.cj contains the generated specialization fragments.")
    parser.add_argument("--check-all", action="store_true", help="Check both collections_runtime.cj and generated vector ABI tests.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.check_all and args.type is not None:
        raise SystemExit("--check-all checks every specialization; do not combine it with --type")
    if args.type is None:
        if args.collections or args.test:
            raise SystemExit("--type is required with --collections or --test")
        if args.check_test or args.check_collections or args.check_all:
            ok = True
            for spec in SPECS.values():
                if args.check_test or args.check_all:
                    ok = check_vector_test(spec) and ok
                if args.check_collections or args.check_all:
                    ok = check_collections_runtime(spec) and ok
            return 0 if ok else 1
        raise SystemExit("choose at least one of --collections, --test, --check-test, --check-collections, or --check-all")

    spec = SPECS[args.type]
    did_work = False
    if args.collections:
        update_collections_runtime(spec)
        did_work = True
    if args.test:
        write_vector_test(spec)
        did_work = True
    if args.check_test:
        did_work = True
        if not check_vector_test(spec):
            return 1
    if args.check_collections:
        did_work = True
        if not check_collections_runtime(spec):
            return 1
    if args.check_all:
        did_work = True
        if not check_vector_test(spec) or not check_collections_runtime(spec):
            return 1
    if not did_work:
        raise SystemExit("choose at least one of --collections, --test, --check-test, --check-collections, or --check-all")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
