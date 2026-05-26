from __future__ import annotations

import argparse
import dataclasses
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COLLECTIONS_RUNTIME = ROOT / "windows_collections" / "src" / "collections_runtime.cj"


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
    parser = argparse.ArgumentParser(
        description="Inject one WinRT IVector<T> direct input ABI specialization into the production runtime."
    )
    parser.add_argument(
        "--type",
        choices=sorted(SPECS),
        help="Cangjie scalar type to inject. Omit with --check-* to check every production specialization.",
    )
    parser.add_argument("--collections", action="store_true", help="Update collections_runtime.cj for this one type.")
    parser.add_argument("--check-collections", action="store_true", help="Check collections_runtime.cj contains the injected specialization fragments.")
    parser.add_argument("--check-all", action="store_true", help="Check the injected collections_runtime.cj specialization fragments for every type.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.check_all and args.type is not None:
        raise SystemExit("--check-all checks every specialization; do not combine it with --type")
    if args.type is None:
        if args.collections:
            raise SystemExit("--type is required with --collections")
        if args.check_collections or args.check_all:
            ok = True
            for spec in SPECS.values():
                ok = check_collections_runtime(spec) and ok
            return 0 if ok else 1
        raise SystemExit("choose at least one of --collections, --check-collections, or --check-all")

    spec = SPECS[args.type]
    did_work = False
    if args.collections:
        update_collections_runtime(spec)
        did_work = True
    if args.check_collections or args.check_all:
        did_work = True
        if not check_collections_runtime(spec):
            return 1
    if not did_work:
        raise SystemExit("choose at least one of --collections, --check-collections, or --check-all")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
