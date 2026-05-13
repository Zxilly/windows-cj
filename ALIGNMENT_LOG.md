# windows-cj alignment log

## 2026-05-12 23:26:53 +08:00 to 2026-05-13 08:26:53 +08:00

### Round41 - Direct2D/Direct3D numerics remaps

- Added exact full-name remaps from Win32 Direct2D/Direct3D numeric structs to `Windows.Foundation.Numerics` value types.
- Extended dependency selection so production common helper generation selects the remapped numerics types instead of falling back to raw opaque pointers.
- Covered all six remaps and the non-Direct2D same-short-name fallback.
- Verification:
  - `cjpm test -m windows --no-progress`: 90/90 passed before review follow-up, then 90/90 passed after dependency-selection fix.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
- Review:
  - Initial review found dependency selection and coverage gaps.
  - Follow-up review: P0/P1/P2 none.

### Round42 - BSTR native ABI remap

- Mapped exact `Windows.Win32.Foundation.BSTR` native helper surface to `windows_strings.BSTR` while keeping raw ABI as `CPointer<Unit>`.
- Return values that transfer ownership use `windows_strings.BSTR.fromRawTake`.
- Borrowed direct parameters use `asPtr`; `SysFreeString` and `SysReleaseString` transfer ownership with `intoRaw`.
- `BSTR*` and deeper pointer slots remain raw `CPointer<CPointer<Unit>>` style slots and do not import `windows_strings` unless a direct `BSTR` appears in the public helper surface.
- Covered non-Win32 same-short-name fallback.
- Verification:
  - `cjpm test -m windows --no-progress`: 93/93 passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
- Review:
  - Initial review found ownership-transfer and unused-import issues.
  - Follow-up review: P0/P1/P2 none.

### Round43 - COM interface native ABI remap

- Mapped exact `Windows.Win32.System.Com.IUnknown` and `Windows.Win32.System.WinRT.IInspectable` native helper direct surfaces to `windows_interface.IUnknown` and `windows_interface.IInspectable`.
- Kept raw ABI as `CPointer<Unit>` and kept `IUnknown*` / `IInspectable*` pointer slots raw as `CPointer<CPointer<Unit>>`.
- Direct return values use `fromAbiTake`; direct input parameters borrow with `asRaw`.
- Covered non-Win32 same-short-name fallback.
- Verification:
  - `cjpm test -m windows --no-progress`: 95/95 passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
- Review:
  - Review: P0/P1/P2 none.

### Round44 - HSTRING native ABI remap

- Mapped exact `Windows.Win32.System.WinRT.HSTRING` native helper direct surfaces to `windows_core.HString` while keeping raw ABI as `CPointer<Unit>`.
- Direct return values use `windows_core.HString.fromSystemHandleTake`.
- Direct input parameters publish temporary Windows-owned handles with `toSystemHandleCopy`; borrowed calls release those handles in `finally`.
- `WindowsDeleteString` and aliases resolved through `Import.Name = "WindowsDeleteString"` do not release again after the call.
- `HSTRING*` and deeper pointer slots remain raw `CPointer<CPointer<Unit>>` and do not import `windows_core` unless a direct HSTRING appears in the public helper surface.
- Covered non-WinRT same-short-name fallback.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed on the new direct HSTRING remap expectations before implementation.
  - Review follow-up red: alias delete and multi-HSTRING temporary-handle tests failed before the follow-up fix.
  - `cjpm test -m windows --no-progress`: 98/98 passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
- Review:
  - Initial review found alias-consuming double-free and temporary-handle leak risks.
  - Follow-up review: P0/P1/P2 none.

### Round45 - Win32 text pointer native ABI remap

- Mapped exact `Windows.Win32.Foundation.PWSTR`, `PSTR`, `PCWSTR`, and `PCSTR` native helper direct surfaces to `windows_strings.PWSTR`, `PSTR`, `PCWSTR`, and `PCSTR`.
- Kept raw ABI as `CPointer<UInt16>` for wide pointers and `CPointer<UInt8>` for narrow pointers.
- Direct return values use `fromRaw(unsafe { proc(...) })`; direct input parameters pass `asPtr()`.
- `PWSTR*` and `PSTR*` pointer slots stay raw `CPointer<CPointer<UInt16>>` / `CPointer<CPointer<UInt8>>` and do not import `windows_strings` in pointer-only helpers.
- Covered non-Win32 same-short-name fallback.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 97/100 on the new text pointer wrapper/raw ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 100/100 passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed. A parallel run first hit linker output contention; a single-package rerun passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review: P0/P1/P2 none.

### Round46 - BSTR release alias ownership transfer

- Fixed native helper BSTR ownership-transfer detection to use the actual P/Invoke import name instead of the projected method name.
- Aliases whose `Import.Name` is `SysFreeString` or `SysReleaseString` now pass direct `windows_strings.BSTR` arguments with `intoRaw()` instead of borrowed `asPtr()`.
- Kept normal borrowed BSTR arguments on `asPtr()` and kept `BSTR*` pointer slots raw.
- Covered both `SysFreeString` and `SysReleaseString` alias cases.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 99/100 on the new `FreeBstrAlias` `owned.intoRaw()` expectations before implementation.
  - `cjpm test -m windows --no-progress`: 100/100 passed after implementation.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
  - Follow-up `SysReleaseString` alias coverage: `cjpm test -m windows --no-progress`: 100/100 passed.
- Review:
  - Initial review: P0/P1/P2 none.
  - Follow-up review after `SysReleaseString` alias coverage: P0/P1/P2 none.

### Round47 - Win32 text pointer literal constants

- Mapped Win32 `PCWSTR` and `PCSTR` literal constants to lazy runtime string factories instead of compile-time constants.
- Non-ABI structs render `windows_strings.WideStringFactory` / `NarrowStringFactory` static values with `wideStringFactory` / `pcstrLiteral`.
- `@C` ABI structs render these managed factory literals as static functions, avoiding managed static storage inside C ABI value types.
- Generated implementation chunks import `windows_strings` when rendered sources reference string factories.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 100/101 on the new literal factory expectations before implementation.
  - `cjpm test -m windows --no-progress`: 101/101 passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review: P0/P1/P2 none.

### Round48 - Win32 text pointer raw ABI in generated symbols

- Mapped exact `Windows.Win32.Foundation.PWSTR` and `PCWSTR` ABI uses to `CPointer<UInt16>`.
- Mapped exact `Windows.Win32.Foundation.PSTR` and `PCSTR` ABI uses to `CPointer<UInt8>`.
- Applied the mapping to value struct fields, explicit layout properties, delegate C function signatures, and WinRT interface vtable slots, including `Out` / `Retval` pointer-to-pointer shapes.
- Rendered the Win32 text pointer type definitions themselves as raw pointer aliases instead of wrapper `@C struct` definitions.
- Refreshed selected `windows-common` generated implementation chunks so existing generated ABI structs no longer keep text pointer wrapper fields, and updated manifest hashes.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 101/102 on new ABI context expectations before implementation.
  - Review follow-up red: `cjpm test -m windows --no-progress` failed 102/103 on new text pointer type-definition alias expectations before implementation.
  - `cjpm test -m windows --no-progress`: 103/103 passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed. A parallel run first hit linker output contention; a single-package rerun passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
- Review:
  - Initial review found generated `windows-common` chunks still using wrapper ABI fields.
  - Follow-up review after generator/type-alias fix and generated chunk refresh: P0/P1/P2 none.

### Round49 - EventRegistrationToken raw ABI in generated symbols

- Mapped exact `Windows.Foundation.EventRegistrationToken` and `Windows.Win32.System.WinRT.EventRegistrationToken` generated ABI uses to `Int64`.
- Applied the mapping to value struct fields and WinRT interface vtable slots, including `add_*` retval slots as `CPointer<Int64>` and `remove_*` parameters as `Int64`.
- Rendered the two real token type definitions as `public type ... = Int64` instead of wrapper `@C struct` definitions.
- Kept non-Windows same-short-name `EventRegistrationToken` types as normal generated wrappers.
- Refreshed selected `windows-common` generated implementation chunks so existing event slots no longer keep token wrapper ABI fields, and updated manifest hashes.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 103/104 on new EventRegistrationToken ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 104/104 passed.
  - `cjpm build -m windows-common`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
  - `python scripts/check_workspace_setup.py`: passed.
- Review:
  - Review: P0/P1/P2 none.

### Round50 - Win32 scalar typedef raw ABI in generated symbols

- Mapped exact `Windows.Win32.Foundation.BOOL` generated ABI uses to `Int32`.
- Mapped exact `Windows.Win32.Foundation.BOOLEAN` generated ABI uses to `UInt8`.
- Mapped exact `Windows.Win32.Foundation.CHAR` generated ABI uses to `Int8`.
- Applied the mappings to value struct fields, fixed arrays, C function signatures, and WinRT interface slots.
- Rendered the three real type definitions as importable aliases while keeping non-Win32 same-short-name types as normal generated wrappers.
- Refreshed selected `windows-common` generated implementation chunks and updated manifest hashes.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 104/105 on new Win32 scalar typedef ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 105/105 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review: P0/P1/P2 none.

### Round51 - HResult raw ABI in generated symbols

- Mapped exact `Windows.Foundation.HResult` and `Windows.Win32.Foundation.HRESULT` generated ABI uses to `Int32`.
- Applied the mapping to value struct fields, C function signatures, and WinRT interface slots, including retval slots as `CPointer<Int32>`.
- Rendered both real type definitions as importable aliases while keeping non-Windows same-short-name `HResult` types as normal generated wrappers.
- Refreshed selected `windows-common` generated implementation chunks and updated manifest hashes.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 105/106 on new HResult ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 106/106 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review: P0/P1/P2 none.

### Round52 - BSTR/HSTRING raw ABI in generated symbols

- Started this continuation window at `2026-05-12 23:26:53 +08:00`; Round52 completed after second review at `2026-05-13 05:58:15 +08:00`.
- Mapped exact `Windows.Win32.Foundation.BSTR` and `Windows.Win32.System.WinRT.HSTRING` generated ABI uses to `CPointer<Unit>`.
- Rendered both real string-handle type definitions as importable aliases instead of wrapper `@C struct` definitions, while keeping non-Windows same-short-name types as normal generated wrappers.
- Applied the mapping to value struct fields, explicit-layout union properties, and WinRT interface slots, including `Out` / `Retval` pointer-to-pointer shapes.
- Added pointer-to-raw-alias preservation so `BSTR*` / `HSTRING*` render as `CPointer<CPointer<Unit>>` instead of collapsing to `CPointer<Unit>`.
- Refreshed `windows-common` generated BSTR ABI surfaces:
  - `Windows_Win32_Foundation_BSTR` is now `public type ... = CPointer<Unit>`.
  - `EXCEPINFO` BSTR fields use `CPointer<Unit>`.
  - `VARIANT.bstrVal` uses `CPointer<Unit>` and `VARIANT.pbstrVal` uses `CPointer<CPointer<Unit>>`.
- Updated generated `Win32.Foundation` native helpers so direct `Sys*String` BSTR ownership APIs use `windows_strings.BSTR`, while pointer-only `BSTR*` slots remain `CPointer<CPointer<Unit>>`.
- Added `windows_strings` as an explicit `windows_common` dependency and updated workspace dependency checks accordingly.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 106/107 on new BSTR/HSTRING raw alias expectations before implementation.
  - Review follow-up red: `cjpm test -m windows --no-progress` failed 106/107 on `BSTR*` / `HSTRING*` pointer-to-pointer expectations before pointer-layer preservation.
  - `cjpm test -m windows --no-progress`: 107/107 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Initial review found `VARIANT.pbstrVal` losing one pointer level.
  - Follow-up review after pointer-layer preservation and generated chunk refresh: P0/P1/P2 none.

### Round53 - VARIANT_BOOL raw ABI in generated symbols

- Completed at `2026-05-13 06:12:49 +08:00`.
- Confirmed Cangjie docs before editing: type aliases are top-level `type Alias = Original` declarations, and `Int16` is the 2-byte FFI integer type.
- Mapped exact `Windows.Win32.Foundation.VARIANT_BOOL` generated ABI uses to `Int16`.
- Applied the mapping to value struct fields, raw pointer fields (`CPointer<Int16>`), explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name `VARIANT_BOOL` types as normal generated wrappers.
- Refreshed selected `windows-common` generated chunks:
  - `Windows_Win32_Foundation_VARIANT_BOOL` is now `public type ... = Int16`.
  - `VARIANT.boolVal` and `VARIANT.__OBSOLETE__VARIANT_BOOL` use `Int16` plus `windows_polyfill.unionReadInt16` / `unionWriteInt16`.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 107/108 only on new `VARIANT_BOOL` ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 108/108 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Sagan`: P0/P1/P2 none.

### Round54 - NTSTATUS/WIN32_ERROR raw ABI in generated symbols

- Completed at `2026-05-13 06:32:45 +08:00`.
- Confirmed Cangjie docs before editing: type aliases can be used as types, user-defined aliases cannot be used as integer conversion constructors, and integer literals are checked by contextual integer type.
- Mapped exact `Windows.Win32.Foundation.NTSTATUS` generated ABI uses to `Int32`.
- Mapped exact `Windows.Win32.Foundation.WIN32_ERROR` generated ABI uses to `UInt32`.
- Added raw-alias rendering that preserves literal enum constants as typed constants (`public let NAME: Alias = literal`) instead of alias-constructor calls.
- Applied the mapping to value struct fields, raw pointer fields, explicit-layout union properties, C function return slots, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name `WIN32_ERROR` types as normal generated wrappers.
- Refreshed selected `windows-common` generated chunks:
  - `Windows_Win32_Foundation_NTSTATUS` is now `public type ... = Int32`.
  - `Windows_Win32_Foundation_WIN32_ERROR` is now `public type ... = UInt32`.
  - `WIN32_ERROR` constants are preserved as typed alias constants without constructor calls.
  - NTSTATUS fields in selected structs use `Int32`.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 108/109 only on new `NTSTATUS` / `WIN32_ERROR` ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 109/109 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Galileo`: P0/P1/P2 none.

### Round55 - Win32 pointer-sized integer raw ABI in generated symbols

- Completed at `2026-05-13 07:00:55 +08:00`.
- Confirmed Cangjie docs before editing: `IntNative` / `UIntNative` are platform-size integer types and map through C FFI as `ssize_t` / `size_t`; top-level aliases can be used as ABI types.
- Mapped exact Win32 pointer-sized integer aliases to native-size integer aliases:
  - `LPARAM`, `LRESULT`, `SHANDLE_PTR` -> `IntNative`.
  - `HANDLE_PTR`, `WPARAM` -> `UIntNative`.
  - Existing canonical aliases `DWORD_PTR`, `INT_PTR`, `LONG_PTR`, `SIZE_T`, `SSIZE_T`, `UINT_PTR`, `ULONG_PTR` use the same signed/native-width mapping.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, WinRT interface slots, and PInvoke native helpers.
- Kept opaque handles such as `HANDLE`, `HWND`, `HMODULE`, and `HGLOBAL` as pointer wrapper structs; kept non-Win32 same-short-name aliases as wrappers.
- Added default/repeat handling so `IntNative` / `UIntNative` generated fields and fixed-array repeat values initialize with numeric `0`.
- Refreshed selected `windows-common` generated chunks:
  - `Windows_Win32_Foundation_HANDLE_PTR` is now `public type ... = UIntNative`.
  - `Windows_Win32_Foundation_LPARAM`, `LRESULT`, and `SHANDLE_PTR` are now `public type ... = IntNative`.
  - `Windows_Win32_Foundation_WPARAM` is now `public type ... = UIntNative`.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 109/110 only on new pointer-sized integer ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 110/110 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Leibniz`: Round55 review clean; no wrong signedness/width, short-name false positives, pointer-layer loss, opaque-handle conversion, default/literal issue, or manifest mismatch found.

### Round56 - NTSTATUS facility/severity code raw ABI in generated symbols

- Completed at `2026-05-13 07:15:45 +08:00`.
- Confirmed Cangjie docs before editing: `UInt32` is a 4-byte FFI integer type and C-style enum aliases can be represented as top-level `public type Alias = UInt32` declarations with typed constants.
- Mapped exact `Windows.Win32.Foundation.NTSTATUS_FACILITY_CODE` and `Windows.Win32.Foundation.NTSTATUS_SEVERITY_CODE` generated ABI uses to `UInt32`.
- Preserved their literal constants as typed alias constants instead of alias-constructor calls.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name `NTSTATUS_FACILITY_CODE` as a normal generated wrapper, and left `NTSTATUS` itself as `Int32`.
- Refreshed selected `windows-common` generated chunks:
  - `Windows_Win32_Foundation_NTSTATUS_FACILITY_CODE` is now `public type ... = UInt32`.
  - `Windows_Win32_Foundation_NTSTATUS_SEVERITY_CODE` is now `public type ... = UInt32`.
  - Both constant groups are typed alias constants without constructor calls.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 110/111 only on new NTSTATUS subcode alias expectations before implementation.
  - `cjpm test -m windows --no-progress`: 111/111 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Erdos`: Round56 review clean; exact full-name matching, typed constants, pointer/interface ABI preservation, `NTSTATUS` separation, and manifest hash all checked.

### Round57 - Win32 Foundation UInt32 scalar raw ABI aliases

- Completed at `2026-05-13 07:29:55 +08:00`.
- Confirmed Cangjie docs before editing: public type aliases can be used as ABI types, alias names are not integer conversion constructors, and `UInt32` is the 4-byte unsigned integer FFI type.
- Mapped exact Win32 Foundation scalar aliases to `UInt32`:
  - `COLORREF`
  - `DUPLICATE_HANDLE_OPTIONS`
  - `GENERIC_ACCESS_RIGHTS`
  - `HANDLE_FLAGS`
  - `OBJECT_ATTRIBUTE_FLAGS`
  - `WAIT_EVENT`
- Preserved their literal constants as typed alias constants instead of alias-constructor calls, including high-bit and all-bits values such as `GENERIC_READ = 2147483648` and `WAIT_FAILED = 4294967295`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.HANDLE_FLAGS` as normal generated wrappers, and left opaque Win32 handles as pointer wrapper structs.
- Refreshed selected `windows-common` generated chunks:
  - `Windows_Win32_Foundation_COLORREF` is now `public type ... = UInt32`.
  - `Windows_Win32_Foundation_DUPLICATE_HANDLE_OPTIONS`, `GENERIC_ACCESS_RIGHTS`, `HANDLE_FLAGS`, `OBJECT_ATTRIBUTE_FLAGS`, and `WAIT_EVENT` are now `public type ... = UInt32`.
  - Their constant groups are typed alias constants without wrapper constructors.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 111/112 only on new Win32 Foundation UInt32 scalar ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 112/112 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Popper`: Round57 review clean; exact full-name matching, typed constants, pointer/union/interface ABI preservation, same-short-name protection, opaque-handle preservation, and manifest hash all checked.

### Round58 - Win32 Security primitive scalar raw ABI aliases

- Completed at `2026-05-13 08:00:46 +08:00`.
- Confirmed Cangjie docs before editing: type aliases are ordinary types, `UInt16` / `UInt32` / `Int32` have the expected fixed integer ranges, and C FFI maps `UInt16` to `uint16_t`, `UInt32` to `uint32_t`, and `Int32` to `int32_t`.
- Mapped exact Win32 Security scalar aliases to primitive ABI aliases:
  - `UInt32`: `ACE_FLAGS`, `ACE_REVISION`, `CLAIM_SECURITY_ATTRIBUTE_FLAGS`, `CREATE_RESTRICTED_TOKEN_FLAGS`, `LOGON32_LOGON`, `LOGON32_PROVIDER`, `OBJECT_SECURITY_INFORMATION`, `SECURITY_AUTO_INHERIT_FLAGS`, `SYSTEM_AUDIT_OBJECT_ACE_FLAGS`, `TOKEN_ACCESS_MASK`, `TOKEN_MANDATORY_POLICY_ID`, `TOKEN_PRIVILEGES_ATTRIBUTES`.
  - `Int32`: `ACL_INFORMATION_CLASS`, `AUDIT_EVENT_TYPE`, `ENUM_PERIOD`, `MANDATORY_LEVEL`, `SECURITY_IMPERSONATION_LEVEL`, `SID_NAME_USE`, `TOKEN_ELEVATION_TYPE`, `TOKEN_INFORMATION_CLASS`, `TOKEN_TYPE`, `WELL_KNOWN_SID_TYPE`.
  - `UInt16`: `CLAIM_SECURITY_ATTRIBUTE_VALUE_TYPE`, `SECURITY_DESCRIPTOR_CONTROL`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including high-bit values such as `SE_PRIVILEGE_USED_FOR_ACCESS = 2147483648` and `SE_SELF_RELATIVE = 32768`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.ACE_FLAGS` as normal generated wrappers and did not convert opaque Security handles.
- Refreshed the existing generated Security section in `windows-common/src/impl/symbols_2.cj` from a `--common --feature Windows.Win32.Security` scratch generation, then updated the `src/impl/symbols_2.cj` manifest hash.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 112/113 only on new Win32 Security scalar ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 113/113 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Hegel`: Round58 review clean.

### Round59 - Win32 Threading primitive scalar raw ABI aliases

- Completed at `2026-05-13 08:19:35 +08:00`.
- Confirmed Cangjie docs before editing: C interop represents fixed-width integer ABI with `UInt32` / `Int32`, and C-style enum-like aliases can be emitted as `public type Alias = UInt32` or `public type Alias = Int32` with typed constants.
- Mapped exact Win32 Threading scalar aliases to primitive ABI aliases:
  - `UInt32`: `CREATE_EVENT`, `CREATE_PROCESS_LOGON_FLAGS`, `GET_GUI_RESOURCES_FLAGS`, `MEMORY_PRIORITY`, `OVERRIDE_PREFETCH_PARAMETER`, `POWER_REQUEST_CONTEXT_FLAGS`, `PROCESSOR_FEATURE_ID`, `PROCESS_ACCESS_RIGHTS`, `PROCESS_AFFINITY_AUTO_UPDATE_FLAGS`, `PROCESS_CREATION_FLAGS`, `PROCESS_DEP_FLAGS`, `PROCESS_NAME_FORMAT`, `PROCESS_PROTECTION_LEVEL`, `PROC_THREAD_ATTRIBUTE_NUM`, `STARTUPINFOW_FLAGS`, `SYNCHRONIZATION_ACCESS_RIGHTS`, `THREAD_ACCESS_RIGHTS`, `THREAD_CREATION_FLAGS`, `WORKER_THREAD_FLAGS`.
  - `Int32`: `AVRT_PRIORITY`, `MACHINE_ATTRIBUTES`, `PROCESS_INFORMATION_CLASS`, `PROCESS_MEMORY_EXHAUSTION_TYPE`, `PROCESS_MITIGATION_POLICY`, `QUEUE_USER_APC_FLAGS`, `RTWQ_WORKQUEUE_TYPE`, `THREAD_INFORMATION_CLASS`, `THREAD_PRIORITY`, `TP_CALLBACK_PRIORITY`, `UMS_THREAD_INFO_CLASS`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including high-bit values such as `CREATE_IGNORE_SYSTEM_DEFAULT = 2147483648` and negative values such as `THREAD_PRIORITY_IDLE = -15`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.PROCESS_CREATION_FLAGS` as normal generated wrappers, and did not convert opaque Threading handles such as `PTP_POOL` / `PTP_WORK` / `AVRT_TASK_HANDLE`.
- Refreshed the existing generated Threading section in `windows-common/src/impl/symbols_3.cj` from a `--common --feature Windows.Win32.System.Threading` scratch generation, then updated the `src/impl/symbols_3.cj` manifest hash.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 113/114 only on new Win32 Threading scalar ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 114/114 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Copernicus`: Round59 review clean.

### Round60 - Win32 Registry primitive scalar raw ABI aliases

- Completed at `2026-05-13 09:23:13 +08:00`.
- Confirmed Cangjie docs before editing: C enum-like values can be represented as `public type Alias = UInt32`, and user-defined integer aliases are not constructor-style integer conversions, so constants must be typed direct assignments rather than alias-constructor calls.
- Mapped exact Win32 Registry scalar aliases to primitive ABI aliases:
  - `UInt32`: `REG_CREATE_KEY_DISPOSITION`, `REG_NOTIFY_FILTER`, `REG_OPEN_CREATE_OPTIONS`, `REG_ROUTINE_FLAGS`, `REG_SAM_FLAGS`, `REG_SAVE_FORMAT`, `REG_VALUE_TYPE`.
  - `Int32`: `REG_RESTORE_KEY_FLAGS`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including larger flag values such as `REG_NOTIFY_THREAD_AGNOSTIC = 268435456`, `RRF_ZEROONFAILURE = 536870912`, and `KEY_ALL_ACCESS = 983103`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.REG_SAM_FLAGS` as normal generated wrappers, and did not convert opaque Registry handles/structs such as `HKEY` or `REG_PROVIDER`.
- Refreshed the existing generated Registry section in `windows-common/src/impl/symbols_3.cj` from a `--common --feature Windows.Win32.System.Registry` scratch generation, then updated the `src/impl/symbols_3.cj` manifest hash.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 114/115 only on new Win32 Registry scalar ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 115/115 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Raman`: Round60 review clean.

### Round61 - Win32 SystemInformation primitive scalar raw ABI aliases

- Completed at `2026-05-13 09:50:24 +08:00`.
- Confirmed Cangjie docs before editing: top-level `public type Alias = UInt32` style aliases are valid, fixed-width integers map to C ABI widths (`UInt16` = 2 bytes, `Int32` / `UInt32` = 4 bytes), and `CPointer<T>` preserves typed pointer ABI.
- Mapped exact Win32 SystemInformation scalar aliases to primitive ABI aliases:
  - `Int32`: `COMPUTER_NAME_FORMAT`, `CPU_SET_INFORMATION_TYPE`, `DEP_SYSTEM_POLICY_TYPE`, `DEVELOPER_DRIVE_ENABLEMENT_STATE`, `FIRMWARE_TYPE`, `LOGICAL_PROCESSOR_RELATIONSHIP`, `OS_DEPLOYEMENT_STATE_VALUES`, `PROCESSOR_CACHE_TYPE`, `RTL_SYSTEM_GLOBAL_DATA_ID`.
  - `UInt32`: `DEVICEFAMILYDEVICEFORM`, `DEVICEFAMILYINFOENUM`, `FIRMWARE_TABLE_PROVIDER`, `OS_PRODUCT_TYPE`, `USER_CET_ENVIRONMENT`, `VER_FLAGS`.
  - `UInt16`: `IMAGE_FILE_MACHINE`, `PROCESSOR_ARCHITECTURE`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including wide values such as `FIRMWARE_TABLE_PROVIDER_RSMB = 1381190978` and `IMAGE_FILE_MACHINE_ARM64 = 43620`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.IMAGE_FILE_MACHINE` as normal generated wrappers.
- Refreshed the generated SystemInformation section in `windows-common/src/impl/symbols_3.cj` from a `--common --feature Windows.Win32.System.SystemInformation` scratch generation, restored the adjacent native-helper `SystemServices` section from matching generated output, then updated the `src/impl/symbols_3.cj` manifest hash.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 115/116 only on new Win32 SystemInformation scalar ABI expectations before implementation.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows --no-progress`: 116/116 passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Boyle`: Round61 review clean.

### Round62 - Win32 Services primitive scalar raw ABI aliases

- Completed at `2026-05-13 10:05:12 +08:00`.
- Confirmed Cangjie docs before editing: top-level type aliases are valid for primitive ABI aliases, `Int32` / `UInt32` keep the required 4-byte C ABI layout, and `CPointer<T>` preserves typed pointer ABI.
- Mapped exact Win32 Services scalar aliases to primitive ABI aliases:
  - `UInt32`: `ENUM_SERVICE_STATE`, `ENUM_SERVICE_TYPE`, `SERVICE_CONFIG`, `SERVICE_ERROR`, `SERVICE_NOTIFY`, `SERVICE_RUNS_IN_PROCESS`, `SERVICE_START_TYPE`, `SERVICE_STATUS_CURRENT_STATE`, `SERVICE_TRIGGER_ACTION`, `SERVICE_TRIGGER_SPECIFIC_DATA_ITEM_DATA_TYPE`, `SERVICE_TRIGGER_TYPE`.
  - `Int32`: `SC_ACTION_TYPE`, `SC_ENUM_TYPE`, `SC_EVENT_TYPE`, `SC_STATUS_TYPE`, `SERVICE_DIRECTORY_TYPE`, `SERVICE_REGISTRY_STATE_TYPE`, `SERVICE_SHARED_DIRECTORY_TYPE`, `SERVICE_SHARED_REGISTRY_STATE_TYPE`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including representative values such as `SERVICE_USER_SHARE_PROCESS = 96` and `SC_ACTION_OWN_RESTART = 4`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.SC_ACTION_TYPE` as normal generated wrappers, and did not convert Services structs/handles such as `SC_HANDLE`, `SERVICE_NOTIFY_1`, `SERVICE_NOTIFY_2A`, `SERVICE_NOTIFY_2W`, `SERVICE_STATUS`, or `SERVICE_STATUS_PROCESS`.
- Refreshed the generated Services section in `windows-common/src/impl/symbols_3.cj` from a `--common --feature Windows.Win32.System.Services` scratch generation, then updated the `src/impl/symbols_3.cj` manifest hash.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 116/117 only on new Win32 Services scalar ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 117/117 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Dalton`: Round62 review clean.

### Round63 - Win32 System.Kernel primitive scalar raw ABI aliases

- Completed at `2026-05-13 10:21:02 +08:00`.
- Confirmed Cangjie docs before editing: top-level type aliases are valid, fixed-width `Int32` keeps the required 4-byte C ABI layout, and `CPointer<T>` preserves typed pointer ABI.
- Mapped exact Win32 System.Kernel scalar aliases to primitive ABI aliases:
  - `Int32`: `COMPARTMENT_ID`, `EVENT_TYPE`, `EXCEPTION_DISPOSITION`, `NT_PRODUCT_TYPE`, `SUITE_TYPE`, `TIMER_TYPE`, `WAIT_TYPE`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including representative values such as `DEFAULT_COMPARTMENT_ID = 1` and `WaitDpc = 4`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.WAIT_TYPE` as normal generated wrappers, and did not convert non-scalar Kernel structs such as `CSTRING`, `STRING`, `SLIST_HEADER`, or `WNF_STATE_NAME`.
- Refreshed the generated Kernel section in `windows-common/src/impl/symbols_3.cj` from a `--common --feature Windows.Win32.System.Kernel` scratch generation, restored the adjacent `System.Ole` section between Kernel and Registry, then updated the `src/impl/symbols_3.cj` manifest hash.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 117/118 only on new Win32 Kernel scalar ABI expectations before implementation.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows --no-progress`: 118/118 passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Banach`: Round63 review clean.

### Round64 - Win32 System one-off primitive scalar raw ABI aliases

- Completed at `2026-05-13 10:35:08 +08:00`.
- Confirmed Cangjie docs before editing: top-level aliases can represent primitive ABI names, `UInt16` / `Int32` / `UInt32` preserve fixed C ABI widths, and `CPointer<T>` keeps typed pointer ABI.
- Mapped exact Win32 System one-off scalar aliases to primitive ABI aliases:
  - `UInt32`: `Diagnostics.Debug.CONTEXT_FLAGS`.
  - `UInt16`: `Ole.PARAMFLAGS`, `Variant.VARENUM`.
  - `Int32`: `SystemServices.RTL_UMS_SCHEDULER_REASON`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including large values such as `CONTEXT_EXCEPTION_REPORTING_AMD64 = 2147483648` and `VT_ILLEGAL = 65535`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.VARENUM` as normal generated wrappers.
- Refreshed only the intended generated sections in `windows-common/src/impl/symbols_3.cj` from a scratch generation covering Diagnostics.Debug, Ole, SystemServices, and Variant, preserving adjacent boundaries:
  - `CONTEXT_FLAGS` remains before `Diagnostics.Debug.EXCEPTION_RECORD`.
  - `PARAMFLAGS` remains before `Registry.DSKTLSYSTEMTIME`.
  - `RTL_UMS_SCHEDULER_REASON` remains before `SystemServices.remoteMETAFILEPICT`.
  - `VARENUM` remains before `Variant.VARIANT`.
- Updated the `src/impl/symbols_3.cj` manifest hash to match the actual file SHA-256.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 118/119 only on new Win32 System one-off scalar ABI expectations before implementation.
  - `cjpm build -m windows`: passed.
  - `cjpm test -m windows --no-progress`: 119/119 passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: first 120s run timed out without failure details; rerun with longer timeout passed 12/12.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Epicurus`: Round64 review clean.

### Round65 - Win32 System.Com first-batch primitive scalar raw ABI aliases

- Completed at `2026-05-13 10:50:39 +08:00`.
- Confirmed Cangjie docs before editing: top-level aliases can represent primitive ABI names, fixed-width `UInt16` / `Int32` / `UInt32` preserve C ABI widths, and aliases do not create distinct wrapper types.
- Mapped exact Win32 System.Com scalar aliases to primitive ABI aliases:
  - `UInt16`: `IDLFLAGS`.
  - `UInt32`: `ROT_FLAGS`, `STGM`.
  - `Int32`: `IMPLTYPEFLAGS`, `INVOKEKIND`, `LOCKTYPE`, `MEMCTX`, `MSHCTX`, `MSHLFLAGS`, `REGCLS`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including values such as `IDLFLAG_FRETVAL = 8`, `REGCLS_MULTIPLEUSE = 1`, and `STGM_SIMPLE = 134217728`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.STGM` as normal generated wrappers, and did not convert adjacent non-scalar Com structs such as `STGMEDIUM`.
- Refreshed the intended generated Com sections in `windows-common/src/impl/symbols_3.cj` from a `--common --feature Windows.Win32.System.Com` scratch generation, then updated the `src/impl/symbols_3.cj` manifest hash.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 119/120 only on new Win32 Com scalar ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 120/120 passed.
  - `cjpm build -m windows`: passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Singer`: Round65 review clean.

### Round66 - Win32 System.Com second-batch primitive scalar raw ABI aliases

- Completed at `2026-05-13 11:06:21 +08:00`.
- Confirmed Cangjie docs before editing: top-level aliases are valid, aliases do not create new wrapper types, and fixed-width `Int32` / `UInt32` preserve C ABI widths.
- Mapped exact Win32 System.Com scalar aliases to primitive ABI aliases:
  - `UInt32`: `RPC_C_AUTHN_LEVEL`, `RPC_C_IMP_LEVEL`, `STREAM_SEEK`, `URI_CREATE_FLAGS`.
  - `Int32`: `RPCOPT_PROPERTIES`, `RPCOPT_SERVER_LOCALITY_VALUES`, `STATFLAG`, `STGC`, `STGTY`, `TYSPEC`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including representative values such as `RPC_C_AUTHN_LEVEL_PKT_PRIVACY = 6`, `STATFLAG_NONAME = 1`, and `Uri_CREATE_ALLOW_RELATIVE = 1`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.STATFLAG` as normal generated wrappers.
- Refreshed exactly the intended generated Com sections in `windows-common/src/impl/symbols_3.cj` from `.generated/round66-com-common/src/impl/symbols_0.cj`, then updated the `src/impl/symbols_3.cj` manifest hash.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 120/121 only on new Win32 Com additional scalar ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 121/121 passed.
  - `cjpm build -m windows`: passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Feynman`: Round66 review clean.

### Round67 - Win32 System.Com remaining symbols_3 primitive scalar raw ABI aliases

- Completed at `2026-05-13 11:20:11 +08:00`.
- Confirmed Cangjie docs before editing: C enum glue can be represented as primitive aliases such as `public type Color = UInt32`, top-level aliases are valid, and aliases do not create distinct wrapper types.
- Mapped exact Win32 System.Com scalar aliases to primitive ABI aliases:
  - `UInt16`: `VARFLAGS`.
  - `Int32`: `MKRREDUCE`, `MKSYS`, `PENDINGMSG`, `PENDINGTYPE`, `SERVERCALL`, `ShutdownType`, `SYSKIND`, `THDTYPE`, `TYMED`, `TYPEKIND`, `Uri_PROPERTY`, `VARKIND`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including representative values such as `TKIND_INTERFACE = 3`, `VARFLAG_FREADONLY = 1`, and `TYMED_HGLOBAL = 1`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.TYPEKIND` as normal generated wrappers.
- Refreshed exactly the intended generated Com sections in `windows-common/src/impl/symbols_3.cj` from `.generated/round67-com-common/src/impl/symbols_0.cj`, then updated the `src/impl/symbols_3.cj` manifest hash.
- Follow-up scan note: after this round, `symbols_3.cj` had no remaining `Windows.Win32.System.Com` enum-like wrappers, but a cross-file scan found additional Com wrappers in other generated symbol files. Those are carried into the next round instead of being treated as complete.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 121/122 only on new Win32 Com remaining scalar ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 122/122 passed.
  - `cjpm build -m windows`: passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Galileo`: Round67 review clean.

### Round68 - Win32 System.Com symbols_2 primitive scalar raw ABI aliases

- Completed at `2026-05-13 11:34:44 +08:00`.
- Confirmed Cangjie docs before editing: C enum glue can be represented as primitive aliases such as `public type Color = UInt32`, and user-defined type aliases cannot be used as primitive constructor wrappers. This supports removing wrapper constructor calls for raw ABI aliases.
- Mapped exact Win32 System.Com scalar aliases to primitive ABI aliases:
  - `UInt16`: `ADVANCED_FEATURE_FLAGS`, `DISPATCH_FLAGS`, `FUNCFLAGS`.
  - `UInt32`: `DVASPECT`, `CLSCTX`.
  - `Int32`: `COINITBASE`, `EXTCONN`, `EOLE_AUTHENTICATION_CAPABILITIES`, `GLOBALOPT_PROPERTIES`, `GLOBALOPT_EH_VALUES`, `GLOBALOPT_RPCTP_VALUES`, `GLOBALOPT_RO_FLAGS`, `GLOBALOPT_UNMARSHALING_POLICY_VALUES`, `DCOM_CALL_STATE`, `APTTYPEQUALIFIER`, `APTTYPE`, `CO_MARSHALING_CONTEXT_ATTRIBUTES`, `BIND_FLAGS`, `ADVF`, `DATADIR`, `CALLTYPE`, `ApplicationType`, `COINIT`, `COMSD`, `COWAIT_FLAGS`, `CWMO_FLAGS`, `BINDINFOF`, `CALLCONV`, `FUNCKIND`, `DESCKIND`.
- Preserved literal constants as typed alias constants without wrapper constructor calls, including representative values such as `FADF_AUTO = 1`, `CLSCTX_LOCAL_SERVER = 4`, and negative `APTTYPE_CURRENT = -1`.
- Applied the mapping to value struct fields, pointer fields, explicit-layout union properties, and WinRT interface slots including `Out` / `Retval` slots.
- Kept non-Win32 same-short-name aliases such as `Example.Native.CLSCTX` as normal generated wrappers.
- Refreshed exactly the intended generated Com sections in `windows-common/src/impl/symbols_2.cj` from `.generated/round68-com-common`, then updated the `src/impl/symbols_2.cj` manifest hash.
- Follow-up scan: all selected `Windows.Win32.System.Com` enum-like wrappers across `windows-common/src/impl/symbols_*.cj` are now primitive aliases; remaining selected Win32 enum-like wrappers across those files: `0`.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 122/123 only on new Win32 Com symbols_2 scalar ABI expectations before implementation.
  - `cjpm test -m windows --no-progress`: 123/123 passed.
  - `cjpm build -m windows`: passed.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `McClintock`: Round68 review clean.

### Round69 - Native helper AssociatedEnum primitive alias arguments

- Completed at `2026-05-13 11:59:45 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` is the C function pointer representation and can be constructed from `CPointer`, while user-defined aliases cannot be used as conversion constructors. This means primitive-alias associated enum arguments must be passed as raw primitives, not through `.value` or alias constructor calls.
- Added generator coverage for Win32 native helper parameters annotated with `AssociatedEnumAttribute` when the associated enum is rendered as a primitive alias:
  - Public helper signatures keep the semantic associated alias, e.g. `dwCoInit: COINIT`.
  - Raw `CFunc` signatures keep the ABI primitive, e.g. `UInt32`.
  - Raw-matching aliases pass directly; raw-mismatching aliases use primitive conversion such as `UInt32(dwCoInit)`.
  - Wrapper-style associated enums still use `.value`, preserving existing non-alias behavior.
- Patched the checked-in common helper outputs for the selected associated enum sites:
  - `CoInitializeEx`: `COINIT`.
  - `CoGetClassObject` / `CoRegisterClassObject`: `CLSCTX`, `REGCLS`.
  - `CoInitializeSecurity` / `CoSetProxyBlanket`: `EOLE_AUTHENTICATION_CAPABILITIES`.
  - `RegRestoreKeyA` / `RegRestoreKeyW`: `REG_RESTORE_KEY_FLAGS`.
- Updated the `src/Win32/System/Com/native_helpers.cj` and `src/Win32/System/Registry/native_helpers.cj` manifest hashes.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 123/124 only on the new raw-alias AssociatedEnum helper expectation before implementation.
  - `cjpm test -m windows --no-progress`: 124/124 passed.
  - `cjpm build -m windows`: passed.
  - `cjpm build -m windows-common`: first 120s run timed out without failure details; rerun with longer timeout passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Bohr`: Round69 review clean.

### Round70 - Win32 Foundation native helper string, BOOL, and pointer-wrapper ABI projections

- Completed at `2026-05-13 12:24:12 +08:00`.
- Confirmed Cangjie docs before editing: `Bool` is the Cangjie boolean type, `if (...) { ... } else { ... }` is an expression form, and `CFunc` is the C function pointer representation whose calls must preserve C ABI parameter and return types.
- Aligned the checked-in `Windows.Win32.Foundation` native helper output with the current generator behavior:
  - `SysAllocString`, `SysReAllocString`, `SysAllocStringLen`, and `SysReAllocStringLen` now expose `windows_strings.PWSTR` and pass `.asPtr()` to raw `CPointer<UInt16>` ABI slots.
  - `SysAllocStringByteLen` now exposes `windows_strings.PSTR` and passes `.asPtr()` to the raw `CPointer<UInt8>` ABI slot.
  - `CloseHandle`, `DuplicateHandle`, `CompareObjectHandles`, `GetHandleInformation`, `SetHandleInformation`, and `FreeLibrary` now expose Cangjie `Bool` while keeping raw `CFunc` returns as `Int32` and comparing against zero.
  - `DuplicateHandle` converts `bInheritHandle: Bool` to `1` / `0` for the raw `BOOL` argument.
- Found and fixed a generator bug while verifying the checked-in output:
  - Before the fix, pointer parameters such as `CPointer<HANDLE>` where `HANDLE` is a transparent wrapper were lowered as `lpTargetHandle.Value`, but `lpTargetHandle` is a pointer and has no `Value` field.
  - Added regression coverage using `DuplicateThing(source: HTHING, target: CPointer<HTHING>): Bool`.
  - Updated `nativeArgumentExpression` so pointer / by-reference parameters whose public and raw forms are both `CPointer<...>` but differ are cast as the pointer itself, e.g. `CPointer<CPointer<Unit>>(target)`, while value wrapper parameters still use `.Value`.
- Refreshed the `src/Win32/Foundation/native_helpers.cj` manifest hash.
- Verification:
  - Red: `cjpm test -m windows --no-progress` failed 123/124 only on the new `DuplicateThing` pointer conversion expectations before implementation.
  - `cjpm test -m windows --no-progress`: 124/124 passed.
  - `cjpm build -m windows`: passed.
  - `cjv exec target\release\bin\windows.exe --input-json .generated\winmd-json-all\Windows.Win32.json --common --out .generated\round70-foundation-common --clean --feature Windows.Win32.Foundation`: passed with `cjHeapSize=32GB`; checked-in Foundation helper differed from scratch only by a trailing blank line.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-core --no-progress`: 15/15 passed.
  - `cjpm test -m windows-runtime --no-progress`: 12/12 passed.
  - `cjpm test -m windows-implement --no-progress`: 18/18 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Hypatia`: initial code/ABI review found no ABI issues but flagged the two helper files as untracked.
  - Added the two helper files to the index so the generator fix and checked-in Foundation output are included in the staged change set.
  - Review agent `Hypatia`: re-review clean.

### Round71 - Win32 System.Kernel native helper string and BOOL projections

- Completed at `2026-05-13 12:36:52 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` preserves C ABI signatures and unsafe call boundaries, `Bool` is the Cangjie boolean type, and `if (...) { ... } else { ... }` is the correct conditional expression form for boolean-to-integer ABI conversion.
- Regenerated a fresh Kernel scratch output with dependency context:
  - Rejected a single-feature Kernel scratch because missing Foundation/Security context degraded `HANDLE` and `SECURITY_ATTRIBUTES` to raw pointers.
  - Used `Windows.Win32.Foundation`, `Windows.Win32.Security`, and `Windows.Win32.System.Kernel` together, preserving typed `HANDLE` and `SECURITY_ATTRIBUTES` projections.
- Aligned `windows-common/src/Win32/System/Kernel/native_helpers.cj` with the non-degraded scratch output:
  - Added `windows_strings` import.
  - `CreateTransaction` now exposes `description: windows_strings.PWSTR` and passes `description.asPtr()` to the raw `CPointer<UInt16>` ABI slot.
  - `CommitTransaction` now exposes a `Bool` return while keeping raw `CFunc<(CPointer<Unit>) -> Int32>` and comparing the result with zero.
- Refreshed the `src/Win32/System/Kernel/native_helpers.cj` manifest hash.
- Verification:
  - `cjv exec target\release\bin\windows.exe --input-json .generated\winmd-json-all\Windows.Win32.json --common --out .generated\round71-kernel-full-common --clean --feature Windows.Win32.Foundation --feature Windows.Win32.Security --feature Windows.Win32.System.Kernel`: passed with `cjHeapSize=32GB`; checked-in Kernel helper differed from scratch only by a trailing blank line.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows --no-progress`: 124/124 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Nash`: code/ABI review found no ABI issues, but flagged the manifest update as unstaged and this Round71 log entry as missing.
  - Staged the manifest and added this Round71 log record for re-review.
  - Review agent `Nash`: re-review clean.

### Round72 - Win32 SystemInformation native helper generated output alignment

- Completed at `2026-05-13 12:47:23 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` preserves raw C ABI signatures and requires unsafe calls, and `Bool` / `if (...) { ... } else { ... }` are the correct Cangjie forms for projecting Win32 `BOOL` values and boolean arguments.
- Regenerated a fresh `SystemInformation` helper scratch with `Windows.Win32.Foundation` dependency context, preserving `FILETIME`, `HANDLE`, and `SYSTEMTIME` instead of degrading them to raw pointers.
- Mechanically replaced `windows-common/src/Win32/System/SystemInformation/native_helpers.cj` with the fresh generated output:
  - Win32 `BOOL` returns now expose `Bool` while raw `CFunc` returns remain `Int32` and compare against zero.
  - Win32 `BOOL` arguments such as time-adjustment flags now expose `Bool` and convert to `1` / `0` at the raw call boundary.
  - Narrow and wide string buffers now expose `windows_strings.PSTR` / `windows_strings.PWSTR` and pass `.asPtr()` into raw `CPointer<UInt8>` / `CPointer<UInt16>` ABI slots.
  - Existing generated reserved/default parameter behavior is preserved from the current generator, including defaulted `Flags` handling where present.
- Refreshed the `src/Win32/System/SystemInformation/native_helpers.cj` manifest hash and staged the helper plus manifest.
- Verification:
  - `cjv exec target\release\bin\windows.exe --input-json .generated\winmd-json-all\Windows.Win32.json --common --out .generated\round72-systeminformation-common --clean --feature Windows.Win32.Foundation --feature Windows.Win32.System.SystemInformation`: passed with `cjHeapSize=32GB`.
  - Checked-in `SystemInformation` helper matches the fresh scratch exactly.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows --no-progress`: 124/124 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Pauli`: Round72 review clean.

### Round73 - Win32 System.Threading native helper generated output alignment

- Completed at `2026-05-13 16:36:57 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` is the C function pointer representation and calls require `unsafe`; `Bool` is the Cangjie boolean type; `if (...) { ... } else { ... }` is the correct expression form for converting Bool values into raw Win32 integer ABI slots.
- Regenerated a fresh `Threading` helper scratch with `Windows.Win32.Foundation`, `Windows.Win32.Security`, `Windows.Win32.System.Kernel`, and `Windows.Win32.System.Threading` dependency context, preserving typed `HANDLE`, `SECURITY_ATTRIBUTES`, `PSID`, and kernel structs instead of degrading them to raw pointers.
- Mechanically replaced `windows-common/src/Win32/System/Threading/native_helpers.cj` with the fresh generated output:
  - Win32 `BOOL` and `BOOLEAN` returns now expose `Bool` while raw `CFunc` returns remain `Int32` / `UInt8` and compare against zero.
  - Win32 boolean parameters such as alertable waits, initial-owner flags, inherit-handle flags, and timer preference flags now expose `Bool` and convert to `1` / `0` at the raw call boundary.
  - Narrow and wide string parameters now expose `windows_strings.PSTR` / `windows_strings.PWSTR` and pass `.asPtr()` into raw `CPointer<UInt8>` / `CPointer<UInt16>` ABI slots.
  - Pointer-to-transparent-wrapper parameters such as `CPointer<HANDLE>` now cast to raw pointer ABI forms like `CPointer<CPointer<Unit>>`, preserving the native pointer layout without using `.Value` on pointer parameters.
  - Existing generated reserved/default parameter behavior is preserved from the current generator, including defaulted zero `dwFlags` where metadata marks the parameter as reserved.
- Refreshed the `src/Win32/System/Threading/native_helpers.cj` manifest hash.
- Verification:
  - `cjv exec target\release\bin\windows.exe --input-json .generated\winmd-json-all\Windows.Win32.json --common --out .generated\round73-threading-common --clean --feature Windows.Win32.Foundation --feature Windows.Win32.Security --feature Windows.Win32.System.Kernel --feature Windows.Win32.System.Threading`: passed with `cjHeapSize=32GB`.
  - Checked-in `Threading` helper matches the fresh scratch exactly.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows --no-progress`: 124/124 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Bernoulli`: initial review found no ABI issues and flagged a Round73 log copy/paste error.
  - Corrected the log ordering and stale round references.
  - Review agent `Bernoulli`: re-review clean.

### Round74 - Win32 System.Services native helper generated output alignment

- Completed at `2026-05-13 17:01:59 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` is the C function pointer representation and calls require `unsafe`; `Bool` is the Cangjie boolean type; `if (...) { ... } else { ... }` is the correct expression form for converting Bool values into raw Win32 integer ABI slots.
- Regenerated a fresh `Services` helper scratch with `Windows.Win32.Foundation`, `Windows.Win32.Security`, and `Windows.Win32.System.Services` dependency context, preserving typed `SC_HANDLE`, `SERVICE_STATUS_HANDLE`, security descriptors, and registry handles instead of degrading them to raw pointers.
- Mechanically replaced `windows-common/src/Win32/System/Services/native_helpers.cj` with the fresh generated output:
  - Win32 `BOOL` returns now expose `Bool` while raw `CFunc` returns remain `Int32` and compare against zero.
  - Win32 boolean parameters such as service-bit flags and boot-configuration status now expose `Bool` and convert to `1` / `0` at the raw call boundary.
  - Narrow and wide service string parameters now expose `windows_strings.PSTR` / `windows_strings.PWSTR` and pass `.asPtr()` into raw `CPointer<UInt8>` / `CPointer<UInt16>` ABI slots.
  - Existing handle wrappers remain typed at the public boundary while raw calls pass their `Value` field into native pointer ABI slots.
- Refreshed the `src/Win32/System/Services/native_helpers.cj` manifest hash.
- Verification:
  - `cjv exec target\release\bin\windows.exe --input-json .generated\winmd-json-all\Windows.Win32.json --common --out .generated\round74-services-common --clean --feature Windows.Win32.Foundation --feature Windows.Win32.Security --feature Windows.Win32.System.Services`: passed with `cjHeapSize=32GB`.
  - Checked-in `Services` helper matches the fresh scratch exactly.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows --no-progress`: 124/124 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Lorentz`: Round74 review clean.

### Round75 - Win32 Security native helper generated output alignment

- Completed at `2026-05-13 17:21:07 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` maps to raw C function pointers and calls require `unsafe`; `Bool` is the language boolean type; `if (...) { ... } else { ... }` is the documented conditional expression form for projecting Bool values into raw Win32 integer ABI slots.
- Regenerated a fresh `Security` helper scratch with `Windows.Win32.Foundation` and `Windows.Win32.Security` dependency context, preserving typed `HANDLE`, `PSID`, `PSECURITY_DESCRIPTOR`, `GUID`, `LUID`, and fixed-array SID authority forms instead of degrading them to raw pointers.
- Mechanically replaced `windows-common/src/Win32/Security/native_helpers.cj` with the fresh generated output:
  - Win32 `BOOL` returns now expose `Bool` while raw `CFunc` returns remain `Int32` and compare against zero.
  - Win32 boolean parameters such as audit/object-creation flags and token adjustment flags now expose `Bool` and convert to `1` / `0` at the raw call boundary.
  - Wide audit/name string parameters now expose `windows_strings.PWSTR` and pass `.asPtr()` into raw `CPointer<UInt16>` ABI slots.
  - Pointer-to-transparent-wrapper out parameters such as `CPointer<PSID>` now cast to the raw pointer ABI form (`CPointer<CPointer<Unit>>`) instead of treating the pointer parameter as a wrapper value.
- Refreshed the `src/Win32/Security/native_helpers.cj` manifest hash.
- Verification:
  - `cjv exec target\release\bin\windows.exe --input-json .generated\winmd-json-all\Windows.Win32.json --common --out .generated\round75-security-common --clean --feature Windows.Win32.Foundation --feature Windows.Win32.Security`: passed with `cjHeapSize=32GB`.
  - Checked-in `Security` helper matches the fresh scratch exactly.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows --no-progress`: 124/124 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Erdos`: Round75 review clean.

### Round76 - Win32 System.Registry native helper generated output alignment

- Completed at `2026-05-13 17:31:58 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` maps to raw C function pointers and calls require `unsafe`; `CPointer` values can be converted to raw pointer ABI forms; `if (...) { ... } else { ... }` remains the documented conditional expression form for boolean conversion.
- Regenerated a fresh `Registry` helper scratch with `Windows.Win32.Foundation`, `Windows.Win32.Security`, and `Windows.Win32.System.Registry` dependency context, preserving typed `HKEY`, `HANDLE`, `FILETIME`, and security structs instead of degrading them to raw pointers.
- Mechanically replaced `windows-common/src/Win32/System/Registry/native_helpers.cj` with the fresh generated output:
  - Registry string parameters now expose `windows_strings.PSTR` / `windows_strings.PWSTR` and pass `.asPtr()` into raw `CPointer<UInt8>` / `CPointer<UInt16>` ABI slots.
  - `CPointer<HKEY>` out parameters now cast to raw `CPointer<CPointer<Unit>>` ABI slots instead of treating pointer parameters as wrapper values.
  - Metadata-reserved parameters such as `Reserved`, `lpReserved`, and extended transaction parameters are removed from the public helper surface and passed as zero/null at the raw call boundary.
  - Existing typed handle/value wrappers remain typed at the public boundary while raw calls pass their `Value` field or a raw pointer cast as appropriate.
- Refreshed the `src/Win32/System/Registry/native_helpers.cj` manifest hash.
- Verification:
  - `cjv exec target\release\bin\windows.exe --input-json .generated\winmd-json-all\Windows.Win32.json --common --out .generated\round76-registry-common --clean --feature Windows.Win32.Foundation --feature Windows.Win32.Security --feature Windows.Win32.System.Registry`: passed with `cjHeapSize=32GB`.
  - Checked-in `Registry` helper matches the fresh scratch exactly.
  - `cjpm build -m windows-common`: passed.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows --no-progress`: 124/124 passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Bacon`: Round76 review clean.

### Round77 - Win32 System.Com native helper generated output alignment

- Completed at `2026-05-13 18:04:33 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` maps to raw C function pointers and calls require `unsafe`; `CPointer` conversions are the correct raw ABI bridge; type aliases are ordinary aliases of their underlying type; structs without all defaulted members do not receive an automatic no-arg constructor.
- Regenerated a fresh `Com` helper scratch with `Windows.Win32.Foundation`, `Windows.Win32.System.Com`, `Windows.Win32.System.Ole`, `Windows.Win32.System.Variant`, and `Windows.Win32.System.Com.StructuredStorage` dependency context.
- Fixed a generator gap found during this round:
  - Real metadata can encode pointer-sized integer parameters as primitive `UIntPtr` / `IntPtr`, not only as `System.UIntPtr` / `System.IntPtr` or `Windows.Win32.Foundation.SIZE_T`.
  - Native helper rendering now maps primitive `UIntPtr` / `IntPtr` to `UIntNative` / `IntNative` for both public and raw ABI signatures.
  - Added regression coverage so a primitive `UIntPtr` native parameter cannot regress to `CPointer<Unit>`.
- Mechanically replaced `windows-common/src/Win32/System/Com/native_helpers.cj` with the fresh generated output:
  - COM interface parameters expose `windows_interface.IUnknown` where metadata identifies that interface, while raw calls pass `.asRaw()`.
  - Wide/narrow string parameters expose `windows_strings.PWSTR` / `PSTR` and pass `.asPtr()` into raw pointer ABI slots.
  - Win32 `BOOL` returns and parameters expose `Bool` where applicable, keeping raw `Int32` slots and converting at the boundary.
  - Reserved/null parameters such as `CoInitialize`/`CoInitializeEx` reserved pointers are removed from the public helper surface and passed as null raw pointers.
  - Pointer-sized allocation sizes such as `CoTaskMemAlloc` / `CoTaskMemRealloc` now expose `UIntNative`.
- Updated WinUI support code to match the corrected common helpers:
  - `windows-winui3/src/win32/mod.cj` now calls `Win32Com.CoInitializeEx(coInit)` and no longer passes a public reserved pointer.
  - `windows-winui3/src/xaml/mod.cj` initializes the `EventRegistrationToken` alias as an `Int64` zero value instead of calling a nonexistent constructor.
- Refreshed the `src/Win32/System/Com/native_helpers.cj` manifest hash.
- Verification:
  - `cjpm build -m windows`: passed with `cjHeapSize=32GB`.
  - `cjv exec target\release\bin\windows.exe --input-json .generated\winmd-json-all\Windows.Win32.json --common --out .generated\round77-com-common --clean --feature Windows.Win32.Foundation --feature Windows.Win32.System.Com --feature Windows.Win32.System.Ole --feature Windows.Win32.System.Variant --feature Windows.Win32.System.Com.StructuredStorage`: passed with `cjHeapSize=32GB`.
  - Checked-in `Com` helper matches the fresh scratch exactly.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows --no-progress`: 124/124 passed.
  - `cjpm build -m windows-common`: passed.
  - `cjpm build -m windows-winui3`: passed.
  - `cjpm test -m windows-strings --no-progress`: 8/8 passed.
- Review:
  - Review agent `Sagan`: Round77 review clean.

### Round78 - Threading and runtime native helper call-site alignment

- Completed at `2026-05-13 18:28:33 +08:00`.
- Confirmed Cangjie docs before editing: `Bool` is a distinct boolean type and `if` conditions require `Bool`; function calls must match parameter lists; type aliases use their underlying type values; `PWSTR()` is available as a no-arg wrapper value from the string support package.
- Adapted `windows-threading` to the current `Win32.System.Threading` native helper surface:
  - `TrySubmitThreadpoolCallback` and `SetThreadpoolThreadMinimum` return `Bool`, so failure checks now use `!success` instead of comparing with integer zero.
  - `CreateThreadpool` now defaults its reserved pointer at the helper boundary, so the call site no longer passes `CPointer<Unit>()`.
  - `CloseThreadpoolCleanupGroupMembers` now accepts `Bool` for `fCancelPendingCallbacks`; call sites pass `false` instead of `0`.
- Adapted `windows-runtime` async event creation to the current threading helper:
  - `CreateEventW` now receives `true` / `false` for manual-reset and initial-state flags.
  - The unnamed event name is passed as an empty `windows_strings.PWSTR()` wrapper instead of a raw `CPointer<UInt16>()`.
  - Added the direct `windows_strings` dependency and updated the workspace dependency checker so package boundaries remain explicit.
- Verification:
  - `cjpm build -m windows-threading`: passed with `cjHeapSize=32GB`.
  - `cjpm build -m windows-runtime`: passed with `cjHeapSize=32GB`.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-runtime --no-progress`: passed with 0 tests.
  - `cjpm test -m windows-threading --no-progress`: timed out after 5 minutes; the timed-out `cjpm` process was stopped.
  - Full `cjpm build`: no longer reports the previous Threading/Runtime errors; remaining failures are in `windows-version`, `windows-registry`, and `windows-services`.
- Review:
  - Review agent `Leibniz`: Round78 review clean; retained the `windows-threading` test timeout as a verification gap without finding a static code bug.

### Round79 - Registry and version native helper call-site alignment

- Completed at `2026-05-13 18:52:58 +08:00`.
- Confirmed Cangjie docs before editing: typed lambda parameters are valid when inference is insufficient; `CString.getChars()` returns the `CPointer<UInt8>` needed for raw C string interop; type aliases use their underlying values but user-defined type aliases are not type-conversion constructors.
- Adapted `windows-registry` to the current `Win32.System.Registry` helper surface:
  - `withWideString` now passes `PWSTR` wrappers while continuing to own the temporary UTF-16 storage for the callback duration.
  - Registry create/open/query/enumeration/value helpers no longer pass metadata-reserved pointer parameters removed by the generated helpers.
  - Registry wide string buffers and names are wrapped with `PWSTR.fromRaw(...)` where the buffer remains owned by the local array handle.
  - `CommitTransaction` now uses the projected `Bool` return directly.
- Adapted `windows-version` to the current `RegGetValueA` surface:
  - `CString` resources are converted with `getChars()` and then wrapped as `PSTR`.
  - Added the direct `windows_strings` dependency and updated the workspace dependency checker accordingly.
- Verification:
  - `cjpm build -m windows-registry`: passed with `cjHeapSize=32GB`.
  - `cjpm build -m windows-version`: passed with `cjHeapSize=32GB`.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-registry --no-progress`: 6/6 passed.
  - `cjpm test -m windows-version --no-progress`: 2/2 passed.
  - Full `cjpm build`: no longer reports the previous Version/Registry errors; remaining failures are in `windows-services`.
- Review:
  - Review agent `Sartre`: Round79 review clean; no actionable Registry/Version ABI, lifetime, dependency, manifest, or log issues found.

### Round80 - Services native helper call-site alignment

- Completed at `2026-05-13 19:06:24 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` represents C-compatible function pointers and can be backed by `@C` functions; `CPointer<T>` is the FFI pointer type; conditions and `Bool` values are used directly in `if` expressions.
- Adapted `windows-services` to the current `Win32.System.Services` helper surface:
  - Service table entries now assign the raw `CPointer<UInt16>` field directly instead of using an obsolete wrapper field.
  - `serviceMainThunk` now matches the generated wide service-main callback type `CFunc<(UInt32, CPointer<CPointer<UInt16>>) -> Unit>`.
  - `StartServiceCtrlDispatcherW` now uses the generated `Bool` return directly.
  - `RegisterServiceCtrlHandlerExW` now uses the projected `PWSTR` parameter type and the direct `windows_strings` dependency.
  - Updated the workspace dependency checker so the new package boundary stays explicit.
- Verification:
  - `cjpm build -m windows-services`: passed with `cjHeapSize=32GB`.
  - `python scripts/check_workspace_setup.py`: passed.
  - `cjpm test -m windows-services --no-progress`: 5/5 passed.
  - Full `cjpm build`: passed with `cjHeapSize=32GB`.
  - Manifest consistency: `missing 0`, `work_mismatch 0`, `index_mismatch 0`.
- Review:
  - Review agent `Pasteur`: Round80 review clean; no actionable Services ABI, pointer lifetime, dependency, or log issues found. Residual risk remains that live SCM behavior is not covered by this local test suite.

### Round81 - Core task memory realloc helper

- Completed at `2026-05-13 19:53:16 +08:00`.
- Confirmed Cangjie docs before editing: `CFunc` is the C-compatible function pointer bridge for dynamically resolved symbols, `CFunc` calls must occur in `unsafe` context, and `CPointer<T>` supports typed `read` / `write` and pointer arithmetic for ABI memory checks.
- Added the missing `windows_core` task memory reallocation surface:
  - `CoTaskMemRealloc(pv: CPointer<Unit>, cb: UIntNative)` resolves and calls the native COM task allocator reallocation entry point.
  - `coTaskMemRealloc(...)` exposes it beside the existing public `coTaskMemAlloc` / `coTaskMemFree` helpers.
- Added TDD coverage:
  - Initial RED: `cjpm test -m windows-core --no-progress` failed because `coTaskMemRealloc` was undeclared.
  - GREEN: new test reallocates a 2-byte task memory block to 4 bytes and verifies the prefix bytes survive the resize.
- Verification:
  - `cjpm test -m windows-core --no-progress`: 16/16 passed with `cjHeapSize=32GB` after the review-driven test fail-fast refinement.
  - Full `cjpm build`: passed with `cjHeapSize=32GB` after the review-driven test fail-fast refinement.
  - `python scripts/check_workspace_setup.py`: passed.
  - `git diff --check -- windows-core/src/abi_array_test.cj windows-core/src/array.cj windows-core/src/native.cj ALIGNMENT_LOG.md`: passed.
- Scope note:
  - `windows-core/src/native.cj` and `windows-core/src/abi_array_test.cj` already contained unrelated working-tree edits before Round81; this round only adds the realloc helper and its direct coverage.
- Review:
  - Review agent `Zeno`: initial review found null-allocation paths in the new test could continue after `@Expect`; test was refined to fail fast before any null pointer access, then Zeno's re-review was clean with no remaining ABI or lifetime issues.

### Round82 - Stock collection GetMany null-buffer ABI guard

- Completed at `2026-05-13 20:44:58 +08:00`.
- Confirmed Cangjie docs before editing: `CPointer.isNull()` / `isNotNull()` are the pointer null checks, `CFunc` calls require `unsafe`, and `Result.Ok` / `Result.Err` are the enum result paths used by the thunk boundary.
- Review-driven scope correction:
  - A first attempt to broaden stock `IVectorView` / `IMapView` to scalar copy generic inputs was rejected during review because the generated vtable input ABI still routes generic inputs through pointer slots.
  - That attempt was reverted; scalar copy collection support remains intentionally deferred until generic input vtables can expose true scalar ABI slots.
- Added a smaller ABI guard that does not broaden the generic surface:
  - Shared stock `GetMany` range writing now treats `itemsSize == 0` with a null buffer as a successful zero-length transfer.
  - Nonzero `itemsSize` with a null `items` buffer now returns `E_POINTER` instead of silently succeeding and writing count `0`.
- Added TDD coverage:
  - Initial RED: direct vtable calls to stock `IVectorView<HString>.GetMany` and `IIterator<HString>.GetMany` with nonzero capacity and null buffer returned `S_OK` and wrote `0`.
  - GREEN: both vtable paths now return `E_POINTER` and leave the caller's count slot unchanged; zero-capacity null-buffer calls still return `S_OK` with count `0`.
- Verification:
  - `cjpm test -m windows-runtime --no-progress`: 13/13 passed with `cjHeapSize=32GB`.
  - `cjpm build -m windows-runtime`: passed with `cjHeapSize=32GB`.
  - `python scripts/check_workspace_setup.py`: passed.
  - `git diff --check -- ALIGNMENT_LOG.md windows-runtime/src/stock.cj windows-runtime/src/stock_helpers_test.cj`: passed.
  - Full `cjpm test --no-progress`: 292/292 passed with `cjHeapSize=32GB`.
  - Full `cjpm build`: passed with `cjHeapSize=32GB`.
- Review:
  - Review agent `Hegel`: Round82 review clean. No ABI, lifetime, HRESULT, scalar-reversion, or log accuracy issues found. Residual risk noted: zero-capacity null-buffer success is asserted directly for `IVectorView`; `IIterator` reaches the same shared helper but does not have a separate zero-capacity assertion.

### Round83 - Stock iterator zero-capacity null-buffer coverage

- Completed at `2026-05-13 21:22:24 +08:00`.
- Confirmed Cangjie docs before editing:
  - `@When[test]` is the test conditional compilation flag.
  - `CFunc` represents C-compatible function pointers, supports CFunc-to-`CPointer<T>` conversion, and all CFunc parameter/return types must satisfy `CType`.
  - `@C struct` fields must satisfy `CType`; `@C struct` cannot implement interfaces and cannot have generic parameters.
- Stabilization after batching commits:
  - The pre-existing working tree was split into four commits before this round:
    - `be83be9b Build core WinRT runtime infrastructure`
    - `75131dda Consolidate WinRT support into runtime package`
    - `261d54c9 Regenerate common helpers and call sites`
    - `52a66b6d Record alignment progress`
  - A first post-commit full test run had reported `windows-libloading` undeclared-helper compile errors plus cascading link errors, but the failure did not reproduce after rerunning the targeted package and full workspace tests.
- Closed the Round82 residual test gap:
  - `windows-runtime/src/stock_helpers_test.cj` now directly calls `IIterator<HString>.GetMany` with `itemsSize == 0`, `items == null`, and a live count slot.
  - The assertion requires `S_OK` and count `0`, matching the shared `writeGenericManyRange` zero-capacity behavior already covered for `IVectorView`.
- Analysis note:
  - The remaining collection scalar-input gap is real but larger: current generated generic input vtable slots erase inputs as `CPointer<Unit>`, while the reference ABI uses the type-specific ABI value for inputs such as `IVectorView<T>.IndexOf` and `IMapView<K, V>.Lookup`.
  - Because Cangjie `@C struct` cannot be generic, fixing this correctly requires a raw function-pointer or generated type-specific bridge design rather than mechanically adding Rust-style associated ABI types.
- Verification:
  - `cjpm test -m windows-libloading --no-progress`: 9/9 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 292/292 passed with `cjHeapSize=32GB` before the coverage-only edit.
  - `cjpm test -m windows-runtime --no-progress`: 13/13 passed with `cjHeapSize=32GB` after the coverage edit.

### Round84 - Stock Int32 vector view direct input ABI

- Completed at `2026-05-13 21:38:28 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` represents C ABI function pointers, supports both `CFunc` to `CPointer<T>` and `CPointer<T>` to concrete `CFunc` conversion, and all CFunc parameter/return types must satisfy `CType`.
  - `@C struct` cannot have generic parameters, so collection vtables cannot be made generic over ABI argument types.
  - Generic function overload constraints do not participate in overload identity, so a second generic `toVectorView<T>` cannot be distinguished only by `CopyWinrtType` vs `HandleWinrtType` constraints.
- Fixed the first concrete scalar input ABI path:
  - Added `IVectorViewVtbl.newInt32`, whose `IndexOf` slot stores a direct-value `CFunc<(this, Int32, index*, found*) -> HRESULT>` behind the existing non-generic vtable field.
  - Added `StockInt32VectorViewImpl` and a concrete `toVectorView(source: Iterable<Int32>)` overload, preserving the existing handle-based generic `toVectorView<T>` path for `HString` and other handle WinRT types.
  - Updated `IVectorView<T>.IndexOf` to dispatch `Int32` values through the direct-value ABI function pointer, while other types continue through the existing generic input borrow path.
- Added TDD coverage:
  - `testStockCopyVectorViewIndexOfUsesDirectValueAbi` creates a stock `IVectorView<Int32>`, verifies the normal wrapper `IndexOf` path, then casts the vtable slot to a direct `Int32` CFunc and verifies an external ABI-style call returns `S_OK`, `found == true`, and index `0`.
- Debugging note:
  - A generic core-level `WinrtOutputBridge.callIndexOf` attempt triggered a reproducible `windows_core` compiler ICE (`std::out_of_range: stoi: out of range`).
  - The root cause was narrowed to the new core generic virtual CFunc shape by rebuilding `windows-core` alone; that approach was removed and replaced with a runtime-side concrete `Int32` ABI branch.
  - A second attempt to make the vtable builder generic over `A <: CType` failed normally because `CFunc` argument positions require concrete `CType` instantiations, not constrained type parameters.
- Verification:
  - `git diff --check`: passed.
  - `cjpm build -m windows-core`: passed with `cjHeapSize=32GB` after removing the ICE-triggering core path.
  - `cjpm test -m windows-runtime --no-progress`: 14/14 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 293/293 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other scalar collection inputs still need concrete ABI thunks (`Bool`, integer widths, floats, projected-copy structs) and map/vector mutable slots (`IMapView.Lookup`, `IMap.HasKey/Insert/Remove`, `IVector.SetAt/InsertAt/Append`, observable variants). The generic CFunc restriction means these should be generated as concrete ABI bridges rather than modeled with a single generic vtable.

### Round85 - Stock Int32 map view direct key ABI

- Completed at `2026-05-13 21:47:04 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` is the C-compatible function pointer representation; calls require `unsafe`, arguments/returns must satisfy `CType`, and conversions through `CPointer<T>` are supported for concrete function signatures.
  - Function overload identity is based on parameter shapes; generic constraints alone do not distinguish overloads, so concrete scalar overloads are used for stock helpers.
- Fixed another concrete scalar collection ABI path:
  - Added `IMapViewVtbl.newInt32Int32`, whose `Lookup` slot is a direct `CFunc<(this, Int32, Int32*) -> HRESULT>` and whose `HasKey` slot is a direct `CFunc<(this, Int32, Bool*) -> HRESULT>`, stored behind the existing non-generic vtable fields.
  - Added `StockInt32MapViewImpl` plus `toMapView(source: Iterable<(Int32, Int32)>)`, with a distinct `IIterable<IKeyValuePair<Int32, Int32>>` required-ancestor vtable.
  - Updated `IMapView<K, V>.Lookup` / `HasKey` to use the direct key path only for the concrete `Int32 -> Int32` map view surface added in this round; other map views keep the existing generic input path until their concrete ABI bridges exist.
- Added TDD coverage:
  - `testStockInt32MapViewUsesDirectKeyAbi` verifies normal wrapper `Size`, `HasKey`, and `Lookup`, then casts `Lookup` and `HasKey` vtable slots to direct `Int32` CFunc signatures and validates external ABI-style calls.
- Review fix:
  - Added a closed-flagged `~init()` cleanup path to `StockInt32MapViewImpl` so both `acquireArrayRawData` vtable handles are released with `releaseArrayRawData` when the implementation object is collected.
- Verification:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 15/15 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 294/294 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - `IMapView<Int32, V>` for non-`Int32` values, other scalar key/value types, mutable `IMap`, mutable/observable `IVector`, and generated WinRT collection projections still require concrete ABI bridge generation.

### Round86 - Stock vtable handle finalization

- Completed at `2026-05-13 22:27:59 +08:00`.
- Confirmed Cangjie docs before editing:
  - `acquireArrayRawData<T>` returns a `CPointerHandle<T>` that must be paired with `releaseArrayRawData`.
  - Not releasing acquired array raw data can cause GC/runtime diagnostics.
  - Class finalizers use `~init()` to release resources during GC.
- Fixed the stock helper lifecycle pattern exposed by Round85 review:
  - Every stock impl that owns vtable raw-array handles now releases those handles in `~init()`.
  - The stock impls intentionally do not expose `Resource.close()`: COM slots copy these vtable pointers at object creation, so external manual close could free storage while live interface pointers still route through it.
  - Covered single-handle implementations (`StockIteratorImpl`, `StockIterableImpl`, `StockKeyValuePairImpl`) and two-handle implementations (`StockVectorViewImpl`, `StockInt32VectorViewImpl`, `StockMapViewImpl`, `StockInt32MapViewImpl`).
- Verification:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 15/15 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 294/294 passed with `cjHeapSize=32GB`.
- Residual risk:
  - Finalizer cleanup is compile-verified and reviewable, but deterministic GC/finalizer execution is not asserted by the local test.

### Round87 - Int32-to-HString map view key ABI

- Completed at `2026-05-13 22:40:25 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` represents C-callable function pointers, its parameter and return types must satisfy `CType`, and invoking it requires `unsafe`.
  - `CPointer<T>.write` is unsafe and requires the pointer to be valid.
  - Function overloads depend on non-generic parameter shape; generic constraints do not create overloads.
- Extended the scalar collection input bridge:
  - Added `IMapViewVtbl.newInt32HString` so `IMapView<Int32, HString>.Lookup` accepts the key as direct `Int32` ABI and returns an `HSTRING` handle out-param.
  - Updated `IMapView<K, V>.Lookup` / `HasKey` dispatch to use the direct `Int32` key path for `V == HString`, matching the concrete vtable.
  - Added `StockInt32HStringMapViewImpl` plus `toMapView(source: Iterable<(Int32, HString)>)`, including the independent `IIterable<IKeyValuePair<Int32, HString>>` ancestor slot and finalizer-only vtable handle release.
- Added coverage:
  - `testStockInt32HStringMapViewUsesDirectKeyAbi` verifies wrapper `Lookup`/`HasKey`, then casts the vtable slots to direct `Int32` ABI signatures and validates external ABI-style calls.
- Verification:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 16/16 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 295/295 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other scalar key/value combinations still need concrete ABI thunks, especially non-`Int32` scalar keys, copy-struct values, mutable `IMap`, mutable/observable `IVector`, and generator-emitted collection projections.

### Round88 - Int32 vector mutable input ABI

- Completed at `2026-05-13 22:55:12 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` values model C function pointers, require `CType` parameters/returns, and calls are `unsafe`.
  - `ArrayList` supports indexed assignment, `get`, `add(value, at:)`, `remove(at:)`, `clear`, and `size`.
  - Generic constraints do not distinguish overloaded functions, so scalar ABI variants must use distinct concrete helpers.
- Extended the mutable vector scalar input bridge:
  - Added `IVectorVtbl.newInt32`, whose `IndexOf`, `SetAt`, `InsertAt`, and `Append` slots accept direct `Int32` values behind the existing erased vtable field types.
  - Updated `IVector<T>.IndexOf`, `SetAt`, `InsertAt`, and `Append` to dispatch `Int32` values through those direct-value ABI slots.
  - Left non-input and array-buffer slots (`GetAt`, `GetMany`, `ReplaceAll`) on the existing erased pointer fields because their current bridge already writes/reads the concrete `Int32` buffer representation through typed pointers.
- Added coverage:
  - `testInt32VectorUsesDirectValueAbiForMutableSlots` builds a minimal `IVector_Impl<Int32>` with `IVectorVtbl.newInt32`, verifies wrapper calls, then casts `IndexOf`, `SetAt`, `InsertAt`, and `Append` to direct `Int32` CFunc signatures and validates external ABI-style calls.
- Verification:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 17/17 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 296/296 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Mutable `IMap` direct scalar key/value slots, observable vector/map ancestor vtables, non-`Int32` scalar inputs, copy-struct values, and generator-emitted collection projections still need concrete ABI thunks.

### Round89 - Int32 map mutable input ABI

- Completed at `2026-05-13 23:12:03 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` values are C-compatible function pointers, require `CType` parameters/returns, can be cast through `CPointer`, and must be called in `unsafe`.
  - `ArrayList` supports indexed assignment, `get`, `add`, `remove(at:)`, `clear`, and `size`, which is enough for a mutable map test double.
- Extended the mutable map scalar bridge:
  - Added `IMapVtbl.newInt32Int32`, whose `Lookup`, `HasKey`, `Insert`, and `Remove` slots accept direct `Int32` key/value ABI behind the existing erased vtable field types.
  - Updated `IMap<K, V>.Lookup`, `HasKey`, `Insert`, and `Remove` to use the direct path only when the wrapper is `IMap<Int32, Int32>`; all other maps retain the generic borrow/project path.
  - Kept `Size`, `GetView`, and `Clear` on the existing erased thunks because they do not take generic input values.
- Added TDD coverage:
  - `testInt32MapUsesDirectValueAbiForMutableSlots` first failed because `IMapVtbl.newInt32Int32` did not exist, then passed after the implementation.
  - The test verifies wrapper calls and external ABI-style direct calls by casting `Lookup`, `HasKey`, `Insert`, and `Remove` slots to concrete `Int32` CFunc signatures.
- Review fix:
  - Added `testGenericInt32MapBuilderUsesDirectValueAbiForSpecialization` after review found that `IMapVtbl.new<..., Int32, Int32>` could still create erased slots that the wrapper would later call as direct ABI.
  - Updated the generic `IMapVtbl.new` construction path to override `Lookup`, `HasKey`, `Insert`, and `Remove` with concrete direct `Int32` slots whenever `K/V` are `Int32/Int32`, keeping old erased slots only for other generic instantiations.
  - Avoided generic `CFunc` closure casts after they triggered a Cangjie compiler ICE; the final bridge uses concrete `IMap_Impl<Int32, Int32>` slot bodies.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 19/19 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 298/298 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other mutable map scalar combinations (`Int32 -> HString`, non-`Int32` keys, copy-struct values), observable collection surfaces, and generator-emitted collection projections still need concrete ABI thunks.

### Round90 - Generic Int32 map view builder direct ABI

- Completed at `2026-05-13 23:46:58 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` values are C-compatible function pointers; parameter and return types must satisfy `CType`; calls and pointer casts require `unsafe` care.
  - Type patterns and `Option` pattern matching are the supported way to branch on concrete runtime/generic values in this codebase.
- Fixed a construction consistency bug left by earlier map-view direct ABI work:
  - `IMapView<K, V>.Lookup` / `HasKey` already dispatch `Int32 -> Int32` and `Int32 -> HString` through direct ABI slots.
  - Generic `IMapViewVtbl.new<Identity, K, V>` could still construct erased slots for those exact specializations, so wrapper or external direct calls could pass an `Int32` where the erased thunk expected `CPointer<Unit>`.
  - The generic builder now overrides `Lookup` and `HasKey` with concrete direct slots for `IMapView<Int32, Int32>` and `IMapView<Int32, HString>`, while leaving other generic instantiations on the erased path.
- Added TDD coverage:
  - `testGenericInt32MapViewBuilderUsesDirectValueAbiForSpecialization`.
  - `testGenericInt32HStringMapViewBuilderUsesDirectKeyAbiForSpecialization`.
  - The red run timed out with a stuck `windows_runtime` test process, matching the ABI-corruption failure mode; after the fix, both wrapper calls and direct slot casts pass.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 21/21 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 300/300 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Mutable `IMap<Int32, HString>`, observable collection surfaces, non-`Int32` scalar keys, copy-struct values, and generator-emitted collection projections still need concrete ABI thunks.

### Round91 - Generic Int32 vector builder direct ABI

- Completed at `2026-05-13 23:58:59 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` values are concrete C-callable function pointers, can be stored behind erased field types through `CPointer` casts, and must be invoked in `unsafe`.
  - `ArrayList` supports indexed assignment, insert, append, remove, clear, and size, which is enough for mutable vector test doubles.
- Fixed the same construction consistency issue for vectors:
  - `IVectorView<T>.IndexOf` and `IVector<T>.IndexOf` / `SetAt` / `InsertAt` / `Append` already dispatch `Int32` values through direct ABI slots.
  - Generic `IVectorViewVtbl.new<Identity, T>` and `IVectorVtbl.new<Identity, T>` could still build erased slots for `T == Int32`, so wrapper or external direct calls could pass `Int32` where the erased thunk expected `CPointer<Unit>`.
  - The generic builders now override the relevant slots with concrete `Int32` direct ABI when `T == Int32`; all other generic instantiations retain the erased path.
- Added TDD coverage:
  - `testGenericInt32VectorBuilderUsesDirectValueAbiForSpecialization`.
  - `testGenericInt32VectorViewBuilderUsesDirectValueAbiForSpecialization`.
  - The red run timed out with a stuck `windows_runtime` process; after the fix, wrapper calls and direct slot casts both pass.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 23/23 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 302/302 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Observable vector/map surfaces, mutable `IMap<Int32, HString>`, non-`Int32` scalar inputs, copy-struct values, and generator-emitted collection projections still need concrete ABI thunks.

### Round92 - Int32 HString map mutable input ABI

- Completed at `2026-05-14 00:15:20 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` values are C-compatible function pointers, require `CType` parameters/returns, can be cast through `CPointer`, and must be invoked from `unsafe`.
  - Type patterns and `Option` matching are the supported way to branch on concrete runtime/generic values without introducing Rust-style associated ABI types.
- Extended the mutable map `Int32 -> HString` bridge:
  - Added `IMapVtbl.newInt32HString`, whose `Lookup`, `HasKey`, `Insert`, and `Remove` slots use direct `Int32` key ABI while preserving HSTRING ownership through the existing HString generic bridges.
  - Updated generic `IMapVtbl.new<..., Int32, HString>` to build the same direct slots so wrapper dispatch and vtable construction stay consistent.
  - Updated `IMap<K, V>.Lookup`, `HasKey`, `Insert`, and `Remove` to use the direct path only for `IMap<Int32, HString>`; all other map instantiations retain the erased generic input/output bridge.
- Added TDD coverage:
  - `testInt32HStringMapUsesDirectKeyAndHStringValueAbiForMutableSlots` first failed because `IMapVtbl.newInt32HString` did not exist, then passed after the implementation.
  - `testGenericInt32HStringMapBuilderUsesDirectAbiForSpecialization` verifies the generic builder also emits direct ABI slots for this specialization.
  - Both tests validate wrapper calls and external ABI-style calls by casting slots to concrete `Int32`/HSTRING CFunc signatures.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 25/25 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 304/304 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Observable vector/map surfaces, non-`Int32` scalar inputs, copy-struct values, and generator-emitted collection projections still need concrete ABI thunks.

### Round93 - Observable vector inherited operation forwarding

- Completed at `2026-05-14 00:26:26 +08:00`.
- Confirmed Cangjie docs before editing:
  - Public class member functions are the normal way to expose inherited convenience operations on wrapper classes.
  - Interfaces use `<:` implementation syntax, and type-safe wrapper forwarding can stay within Cangjie object/resource semantics.
- Fixed an observable collection surface gap:
  - `IObservableVector<T>` already supported `asIVector()` and the COM object model already exposes `IVector<T>` as an ancestor interface.
  - The wrapper itself only exposed `VectorChanged` / `RemoveVectorChanged`, so callers could not use inherited vector operations directly from an `IObservableVector<T>` value.
  - Added forwarding methods for `GetAt`, `Size`, `GetView`, `IndexOf`, `SetAt`, `InsertAt`, `RemoveAt`, `Append`, `RemoveAtEnd`, `Clear`, `GetMany`, and `ReplaceAll`.
  - Each forwarding call queries `asIVector()` and scopes the temporary wrapper with `try` resource cleanup instead of changing vtable layout or inventing Rust-style trait machinery.
- Added TDD coverage:
  - `testObservableVectorForwardsInheritedVectorOperations` first failed because `IObservableVector<Int32>` had no inherited vector operation members.
  - After the forwarding methods were added, the test validates direct calls on `IObservableVector<Int32>` for mutation, lookup, index search, size, and clear.
- Verification so far:
  - `cjpm test -m windows-runtime --no-progress`: 26/26 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - `IObservableMap<K, V>` still needs direct inherited map operation forwarding, and observable event args may need scalar/HString direct ABI specializations.

### Round94 - Observable map inherited operation forwarding

- Completed at `2026-05-14 00:33:47 +08:00`.
- Confirmed Cangjie docs before editing:
  - Public generic class member functions are the right shape for inherited convenience methods.
  - `try` resource scopes require `Resource` implementations and close them when the scope exits, matching the existing COM wrapper lifetime model.
- Fixed the matching observable map surface gap:
  - `IObservableMap<K, V>` already supported `asIMap()` and advertises `IMap<K, V>` as an ancestor interface through descriptors/QI.
  - The wrapper only exposed event subscription methods, so callers could not call inherited `IMap` operations directly from an `IObservableMap` value.
  - Added forwarding methods for `Lookup`, `Size`, `HasKey`, `GetView`, `Insert`, `Remove`, and `Clear`.
  - Each forwarding call uses a scoped `asIMap()` wrapper and preserves the already-correct concrete map ABI paths underneath, including `IMap<Int32, HString>`.
- Added TDD coverage:
  - `testObservableMapForwardsInheritedMapOperations` first failed because `IObservableMap<Int32, HString>` had no `HasKey`, `Lookup`, `Insert`, `Size`, `GetView`, `Remove`, or `Clear` members.
  - After the forwarding methods were added, the test validates direct calls on `IObservableMap<Int32, HString>` for lookup, insert/replace, view retrieval, removal, and clear.
- Verification so far:
  - `cjpm test -m windows-runtime --no-progress`: 27/27 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Observable event args direct ABI specializations, non-`Int32` scalar inputs, copy-struct values, and generator-emitted collection projections still need focused passes.

### Round95 - UInt32 vector mutable input ABI

- Completed at `2026-05-14 00:49:31 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` is the C-callable function pointer representation, can be cast through `CPointer`, and calls require `unsafe`.
  - `UInt32` literals use the `u32` suffix, and type patterns are the supported way to branch generic wrapper calls by concrete scalar type.
- Extended vector scalar-input ABI coverage beyond `Int32`:
  - Added direct `UInt32` slot dispatch for `IVectorView<UInt32>.IndexOf`.
  - Added direct `UInt32` slot dispatch for `IVector<UInt32>.IndexOf`, `SetAt`, `InsertAt`, and `Append`.
  - Added `IVectorViewVtbl.newUInt32` and `IVectorVtbl.newUInt32`, and made the generic `new<..., UInt32>` builders override the same direct ABI slots.
  - Kept non-`UInt32` cases on the existing generic borrow/project path.
- Added TDD coverage:
  - `testUInt32VectorUsesDirectValueAbiForMutableSlots` first failed because `IVectorVtbl.newUInt32` did not exist.
  - `testGenericUInt32VectorBuilderUsesDirectValueAbiForSpecialization` verifies the generic mutable vector builder emits direct `UInt32` value ABI.
  - `testGenericUInt32VectorViewBuilderUsesDirectValueAbiForSpecialization` verifies the vector-view builder emits direct `UInt32` value ABI for `IndexOf`.
- Verification so far:
  - `cjpm test -m windows-runtime --no-progress`: 30/30 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other scalar input families (`Bool`, signed/unsigned 8/16/64-bit, floating point), map key/value scalar combinations, event args review, and generator-emitted collection projections still need focused passes.

### Round96 - UInt32 map input ABI

- Completed at `2026-05-14 01:08:33 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` slots can be cast through `CPointer` to concrete C-callable signatures and must be invoked from `unsafe`.
  - `UInt32` literals use the `u32` suffix, and pattern/type matching is the current way to specialize generic wrappers by concrete scalar type.
- Extended map scalar-input ABI coverage beyond `Int32`:
  - Added direct `UInt32 -> UInt32` slot dispatch for `IMapView<UInt32, UInt32>.Lookup` and `HasKey`.
  - Added direct `UInt32 -> UInt32` slot dispatch for mutable `IMap<UInt32, UInt32>.Lookup`, `HasKey`, `Insert`, and `Remove`.
  - Added `IMapVtbl.newUInt32UInt32`, and made generic `IMapViewVtbl.new<..., UInt32, UInt32>` / `IMapVtbl.new<..., UInt32, UInt32>` emit the same direct ABI slots.
  - Kept all other map instantiations on the existing generic borrow/project path.
- Added TDD coverage:
  - `testGenericUInt32MapViewBuilderUsesDirectValueAbiForSpecialization` verifies the map-view generic builder exposes direct `UInt32` key and result ABI.
  - `testUInt32MapUsesDirectValueAbiForMutableSlots` first failed because `IMapVtbl.newUInt32UInt32` did not exist, then validated wrapper and external ABI-style calls for mutable operations.
  - `testGenericUInt32MapBuilderUsesDirectValueAbiForSpecialization` verifies the mutable generic builder emits direct `UInt32` value ABI for lookup and insert.
- Debugging notes:
  - One intermediate run timed out after a builder-specialization block was accidentally placed on the map-view builder instead of the mutable map builder.
  - The follow-up failure where wrapper lookup returned the default value traced to `IMap<K, V>.Lookup` missing the matching direct dispatch branch.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 33/33 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other scalar input families (`Bool`, signed/unsigned 8/16/64-bit, floating point), mixed scalar/HString map combinations such as `UInt32 -> HString`, event args review, and generator-emitted collection projections still need focused passes.

### Round97 - UInt32 HString map input ABI

- Completed at `2026-05-14 02:11:27 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` is the C-callable function pointer representation, can be cast from `CPointer`, and calls require `unsafe`.
  - Type patterns and `u32` literals are the supported way to specialize generic wrapper calls for `UInt32` without adding Rust-style ABI associated types.
- Extended mixed scalar/HSTRING map coverage:
  - Added direct `UInt32` key + HSTRING output slot dispatch for `IMapView<UInt32, HString>.Lookup` and `HasKey`.
  - Added direct `UInt32` key + HSTRING value slot dispatch for mutable `IMap<UInt32, HString>.Lookup`, `HasKey`, `Insert`, and `Remove`.
  - Added `IMapViewVtbl.newUInt32HString` and `IMapVtbl.newUInt32HString`, both delegating through the generic builders now that the generic specialization emits direct ABI slots.
  - Preserved HSTRING ownership through `winrtStoreGenericOut`, `fromSystemHandleTake`, and scoped `winrtBorrowGenericIn`.
- Added TDD coverage:
  - `testGenericUInt32HStringMapViewBuilderUsesDirectKeyAbiForSpecialization` covers wrapper lookup plus direct vtable calls with `CFunc<(CPointer<Unit>, UInt32, ...)>`.
  - `testUInt32HStringMapUsesDirectKeyAndHStringValueAbiForMutableSlots` first failed because `IMapVtbl.newUInt32HString` was missing, then validated lookup, has-key, insert, remove, and HSTRING handle ownership.
  - `testGenericUInt32HStringMapBuilderUsesDirectAbiForSpecialization` verifies the generic mutable map builder emits the same direct ABI slots.
- Debugging notes:
  - After the first implementation, mutable `Remove` still used the generic path for `V=HString` because the `UInt32` key wrapper branch was placed under `V=Int32`; moving that branch under the HSTRING specialization fixed the failed `HasKey` / `Size` assertions.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 36/36 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 315/315 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other scalar input families (`Bool`, signed/unsigned 8/16/64-bit, floating point), additional mixed scalar/HSTRING combinations, stock helper specializations, event args review, and generator-emitted collection projections still need focused passes.

### Round98 - Bool vector input ABI

- Completed at `2026-05-14 02:23:16 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` is the C-callable function pointer representation, can be cast from `CPointer`, and calls require `unsafe`.
  - `Bool` literals are `true` / `false`, and type patterns are the supported way to specialize generic wrapper calls by concrete runtime type.
- Extended vector scalar-input ABI coverage for `Bool`:
  - Added direct `Bool` slot dispatch for `IVectorView<Bool>.IndexOf`.
  - Added direct `Bool` slot dispatch for mutable `IVector<Bool>.IndexOf`, `SetAt`, `InsertAt`, and `Append`.
  - Added `IVectorViewVtbl.newBool` and `IVectorVtbl.newBool`, and made generic `new<..., Bool>` builders emit the same direct ABI slots.
  - Kept non-`Bool` cases on the existing generic borrow/project path.
- Added TDD coverage:
  - `testBoolVectorUsesDirectValueAbiForMutableSlots` first failed because `IVectorVtbl.newBool` did not exist, then validated wrapper calls and direct vtable calls with concrete `Bool` CFunc signatures.
  - `testGenericBoolVectorBuilderUsesDirectValueAbiForSpecialization` verifies the mutable generic builder emits direct `Bool` input slots.
  - `testGenericBoolVectorViewBuilderUsesDirectValueAbiForSpecialization` verifies the vector-view generic builder emits direct `Bool` input slots for `IndexOf`.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 39/39 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 318/318 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other scalar input families (`Int8`/`UInt8`/`Int16`/`UInt16`/`Int64`/`UInt64`, `Float32`/`Float64`), additional map scalar/HSTRING combinations, stock helper specializations, event args verification, and generator-emitted collection projections still need focused passes.

### Round99 - Float32 vector input ABI

- Completed at `2026-05-14 02:32:20 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` is the C-callable function pointer representation, can be cast from `CPointer`, and calls require `unsafe`.
  - `Float32` literals use the `f32` suffix, and `Float32` is valid in C-callable signatures that satisfy `CType`.
- Extended vector scalar-input ABI coverage for `Float32`:
  - Added direct `Float32` slot dispatch for `IVectorView<Float32>.IndexOf`.
  - Added direct `Float32` slot dispatch for mutable `IVector<Float32>.IndexOf`, `SetAt`, `InsertAt`, and `Append`.
  - Added `IVectorViewVtbl.newFloat32` and `IVectorVtbl.newFloat32`, and made generic `new<..., Float32>` builders emit the same direct ABI slots.
  - Kept non-`Float32` cases on the existing generic borrow/project path.
- Added TDD coverage:
  - `testFloat32VectorUsesDirectValueAbiForMutableSlots` first failed because `IVectorVtbl.newFloat32` did not exist, then validated wrapper calls and direct vtable calls with concrete `Float32` CFunc signatures.
  - `testGenericFloat32VectorBuilderUsesDirectValueAbiForSpecialization` verifies the mutable generic builder emits direct `Float32` input slots.
  - `testGenericFloat32VectorViewBuilderUsesDirectValueAbiForSpecialization` verifies the vector-view generic builder emits direct `Float32` input slots for `IndexOf`.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 42/42 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 321/321 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other scalar input families (`Int8`/`UInt8`/`Int16`/`UInt16`/`Int64`/`UInt64`, `Float64`), additional map scalar/HSTRING combinations, stock helper specializations, event args verification, and generator-emitted collection projections still need focused passes.

### Round100 - Float64 vector input ABI

- Completed at `2026-05-14 02:42:04 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` is the C-callable function pointer representation, can be cast from `CPointer`, and calls require `unsafe`.
  - `Float64` literals use the `f64` suffix, and floating-point types are valid in C-callable signatures that satisfy `CType`.
- Extended vector scalar-input ABI coverage for `Float64`:
  - Added direct `Float64` slot dispatch for `IVectorView<Float64>.IndexOf`.
  - Added direct `Float64` slot dispatch for mutable `IVector<Float64>.IndexOf`, `SetAt`, `InsertAt`, and `Append`.
  - Added `IVectorViewVtbl.newFloat64` and `IVectorVtbl.newFloat64`, and made generic `new<..., Float64>` builders emit the same direct ABI slots.
  - Kept non-`Float64` cases on the existing generic borrow/project path.
- Added TDD coverage:
  - `testFloat64VectorUsesDirectValueAbiForMutableSlots` first failed because `IVectorVtbl.newFloat64` did not exist, then validated wrapper calls and direct vtable calls with concrete `Float64` CFunc signatures.
  - `testGenericFloat64VectorBuilderUsesDirectValueAbiForSpecialization` verifies the mutable generic builder emits direct `Float64` input slots.
  - `testGenericFloat64VectorViewBuilderUsesDirectValueAbiForSpecialization` verifies the vector-view generic builder emits direct `Float64` input slots for `IndexOf`.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 45/45 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 324/324 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other scalar input families (`Int8`/`UInt8`/`Int16`/`UInt16`/`Int64`/`UInt64`), additional map scalar/HSTRING combinations, stock helper specializations, event args verification, and generator-emitted collection projections still need focused passes.

### Round101 - Int64 vector-view input ABI

- Completed at `2026-05-14 02:51:25 +08:00`.
- Confirmed Cangjie docs before editing:
  - `CFunc` is the C-callable function pointer representation, can be cast from `CPointer`, and calls require `unsafe`.
  - Integer literal suffixes include `i64`, and integer types are valid in C-callable signatures that satisfy `CType`.
- Extended vector-view scalar-input ABI coverage for `Int64`:
  - Added direct `Int64` slot dispatch for `IVectorView<Int64>.IndexOf`.
  - Added `IVectorViewVtbl.newInt64`, and made generic `new<..., Int64>` builders emit the same direct ABI slot.
  - Kept non-`Int64` cases on the existing generic borrow/project path.
  - Deliberately kept this round view-only because the reference scan found real `IVectorView<i64>` projections but no matching mutable `IVector<i64>` use to justify adding mutable slots mechanically.
- Added TDD coverage:
  - `testInt64VectorViewUsesDirectValueAbiForIndexOf` first failed because `IVectorViewVtbl.newInt64` did not exist, then validated wrapper calls and direct vtable calls with a concrete `Int64` CFunc signature.
  - `testGenericInt64VectorViewBuilderUsesDirectValueAbiForSpecialization` verifies the generic vector-view builder emits the same direct `Int64` input slot for `IndexOf`.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress`: 47/47 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 326/326 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other view scalar families (`Int16`/`UInt8`/`UInt16`/`UInt64`), additional map scalar/HSTRING combinations, stock helper specializations, event args verification, and generator-emitted collection projections still need focused passes.

### Round102 - Int16 vector-view input ABI

- Completed at `2026-05-14 03:07:10 +08:00`.
- Confirmed Cangjie docs before editing:
  - Integer literal suffixes include `i16`, `u8`, `u16`, and `u64`, and integer literals are range-checked against their contextual type.
  - `CFunc` maps to C-callable function pointers, its parameter and return types must satisfy `CType`, `CPointer<T>` can be cast to a concrete `CFunc`, and calling it requires `unsafe`.
- Extended vector-view scalar-input ABI coverage for `Int16`:
  - Added direct `Int16` slot dispatch for `IVectorView<Int16>.IndexOf`.
  - Added `IVectorViewVtbl.newInt16`, and made generic `new<..., Int16>` builders emit the same direct ABI slot.
  - Kept non-`Int16` cases on the existing generic borrow/project path.
  - Deliberately kept this round view-only because the reference scan found real `IVectorView<i16>` projections but no matching mutable `IVector<i16>` use.
- Added TDD coverage:
  - `testInt16VectorViewUsesDirectValueAbiForIndexOf` first failed because `IVectorViewVtbl.newInt16` did not exist, then validated wrapper calls and direct vtable calls with a concrete `Int16` CFunc signature.
  - `testGenericInt16VectorViewBuilderUsesDirectValueAbiForSpecialization` verifies the generic vector-view builder emits the same direct `Int16` input slot for `IndexOf`.
- Debugging notes:
  - One module-test run timed out and left `std.testrunner.exe` / `windows_runtime.exe` locking `target/release/unittest_bin`; after cleaning the stale processes, the implementation compiled and tests ran normally.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress --parallel 1 --timeout-each=30s --no-capture-output`: 49/49 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 328/328 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other view scalar families (`UInt8`/`UInt16`/`UInt64`), additional map scalar/HSTRING combinations, stock helper specializations, event args verification, and generator-emitted collection projections still need focused passes.

### Round103 - UInt8 vector-view input ABI

- Completed at `2026-05-14 03:38:40 +08:00`.
- Confirmed Cangjie docs before editing:
  - Integer literal suffixes include `u8`, and integer literals are range-checked against their contextual type.
  - `CFunc` maps to C-callable function pointers, its parameter and return types must satisfy `CType`, `CPointer<T>` can be cast to a concrete `CFunc`, and calling it requires `unsafe`.
- Extended vector-view scalar-input ABI coverage for `UInt8`:
  - Added direct `UInt8` slot dispatch for `IVectorView<UInt8>.IndexOf`.
  - Added `IVectorViewVtbl.newUInt8`, and made generic `new<..., UInt8>` builders emit the same direct ABI slot.
  - Kept non-`UInt8` cases on the existing generic borrow/project path.
  - Deliberately kept this round view-only because the reference scan found real `IVectorView<u8>` projections but no matching mutable `IVector<u8>` use.
- Added TDD coverage:
  - `testUInt8VectorViewUsesDirectValueAbiForIndexOf` first failed because `IVectorViewVtbl.newUInt8` did not exist, then validated wrapper calls and direct vtable calls with a concrete `UInt8` CFunc signature.
  - `testGenericUInt8VectorViewBuilderUsesDirectValueAbiForSpecialization` verifies the generic vector-view builder emits the same direct `UInt8` input slot for `IndexOf`.
- Debugging notes:
  - Individual wrapper and generic-builder `UInt8` tests both passed.
  - One full-workspace run left `windows_runtime.exe` busy under `target/release/unittest_bin`; deleting that generated unittest output directory and rebuilding made the full suite pass. This was treated as generated test-runner state, not a source change.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress --parallel 1 --timeout-each=30s`: 51/51 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress`: 330/330 passed with `cjHeapSize=32GB` after regenerating `target/release/unittest_bin`.
- Remaining related gap:
  - Other view scalar families (`UInt16`/`UInt64`), additional map scalar/HSTRING combinations, stock helper specializations, event args verification, and generator-emitted collection projections still need focused passes.

### Round104 - UInt16 vector-view input ABI

- Completed at `2026-05-14 04:05:26 +08:00`.
- Confirmed Cangjie docs before editing:
  - Integer literal suffixes include `u16`, and integer literals are range-checked against their contextual type.
  - `CFunc` maps to C-callable function pointers, its parameter and return types must satisfy `CType`, `CPointer<T>` can be cast to a concrete `CFunc`, and calling it requires `unsafe`.
- Extended vector-view scalar-input ABI coverage for `UInt16`:
  - Added direct `UInt16` slot dispatch for `IVectorView<UInt16>.IndexOf`.
  - Added `IVectorViewVtbl.newUInt16`, and made generic `new<..., UInt16>` builders emit the same direct ABI slot.
  - Kept non-`UInt16` cases on the existing generic borrow/project path.
  - Deliberately kept this round view-only because the reference scan found a real `IVectorView<u16>` projection but no matching mutable `IVector<u16>` use.
- Added TDD coverage:
  - `testUInt16VectorViewUsesDirectValueAbiForIndexOf` first failed because `IVectorViewVtbl.newUInt16` did not exist, then validated wrapper calls and direct vtable calls with a concrete `UInt16` CFunc signature.
  - `testGenericUInt16VectorViewBuilderUsesDirectValueAbiForSpecialization` verifies the generic vector-view builder emits the same direct `UInt16` input slot for `IndexOf`.
- Debugging notes:
  - `windows-runtime` module tests passed directly.
  - Full-workspace default output-capture mode twice left `windows_runtime.exe` busy; running the same full suite with `--no-capture-output` completed successfully, so the recorded full verification uses the non-capturing runner mode.
- Verification so far:
  - `git diff --check`: passed.
  - `cjpm test -m windows-runtime --no-progress --parallel 1 --timeout-each=30s`: 53/53 passed with `cjHeapSize=32GB`.
  - Full `cjpm test --no-progress --timeout-each=30s --no-capture-output`: 332/332 passed with `cjHeapSize=32GB`.
- Remaining related gap:
  - Other view scalar family (`UInt64`), additional map scalar/HSTRING combinations, stock helper specializations, event args verification, and generator-emitted collection projections still need focused passes.
