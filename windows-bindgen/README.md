# windows-bindgen

`windows-cj/windows-bindgen` is the executable Cangjie binding generator.
Its Cangjie package name is `windows_bindgen`; the user-facing CLI name is
`windows-bindgen`.

The generator reads `.winmd` metadata directly: a Cangjie-native `.winmd`
reader is built into this package (`src/winmd/`, `src/winmd_adapter.cj`) and is
the default and only path. It can also read already-converted WinMD JSON. The
legacy C#/.NET `winmd-to-json` converter has been retired and removed.

## Delivery boundary

This package is an executable generator CLI. It is not the consumer `windows`
projection package.

The checked-in importable generated surface is currently `windows-common`,
whose Cangjie package name is `windows_common`. Its manifest records a selected
feature set, not a full Windows API projection. Consumers import `windows_common`
(and the runtime support packages) directly; there is no separate consumer facade
package.

The active workspace no longer contains `windows-sys` / `windows_sys`. Cangjie
compile speed makes a full raw sys package the wrong deliverable for this
project. Prefer selected generated/common support, expanded through explicit
feature sets and validated manifests, instead of a monolithic raw package.

A small package alias is not the right near-term fix: Cangjie import aliases are
source imports, not replacement package artifacts. The delivery roadmap is:

1. Keep the generator role under `windows-bindgen` / `windows_bindgen`.
2. Promote `windows_common` toward a stable consumer-facing projection package.
3. Expand selected generated/common support through deliberate feature sets.
4. Add feature or package slicing so broad metadata does not force one
   monolithic compile unit.

## Supported inputs

The bindgen input contract accepts raw `.winmd` and converted JSON:

- A positional `metadata.winmd` file or a directory of `.winmd` files is parsed
  natively by the built-in Cangjie reader.
- `default` parses the bundled `.winmd` metadata under `../winmd`.
- `--input-json <file>` loads one already-converted metadata JSON file.
- `--input-dir <dir>` loads all `.json` files from a directory, sorted by file name.
- Positional `metadata.json` is shorthand for `--input-json metadata.json`.
- Positional JSON directories are shorthand for `--input-dir <dir>` when the directory contains `.json` files.

The native reader is the default and only `.winmd` path; there is no external
converter. Use `--input-json` / `--input-dir` only to feed already-converted
JSON (for example a checked-in offline metadata cache).

To emit the same split JSON metadata that the gate consumes, use the built-in
`--emit-winmd-json` mode:

```pwsh
$env:cjHeapSize = "32GB"
cjpm run -m windows-bindgen -- --emit-winmd-json .\winmd -d .generated\winmd-json
```

## WinMD workflow

Run commands from the `windows-cj` repository root. Generate directly from raw
`.winmd`:

```pwsh
$env:cjHeapSize = "32GB"
cjpm run -m windows-bindgen -- .\winmd --feature Windows.Foundation --out .generated\windows
```

Or build a reusable offline JSON input directory once, then generate from it:

```pwsh
$env:cjHeapSize = "32GB"
cjpm run -m windows-bindgen -- --emit-winmd-json .\winmd -d .generated\winmd-json
cjpm test -m windows-bindgen
```

For `scripts/check_windows_common_codegen.py`, the default offline input remains
`.generated/winmd-json` from the repository root and only covers the checked-in
Windows/Win32/Wdk metadata.

### Optional WinUI/WindowsAppSDK metadata

WinUI/WindowsAppSDK metadata must be provided as converted JSON plus the matching
raw `.winmd` files used for hash validation. The gate accepts:

- `--winui-winmd-json-dir <dir>` or `WINDOWS_CJ_WINUI_WINMD_JSON_DIRS`
- `--winui-winmd-root <file-or-dir>` or `WINDOWS_CJ_WINUI_WINMD_ROOTS`

The environment variables are path lists, so use `;` between paths on Windows.
Emit the JSON from an explicit raw root with the native reader so the gate can
validate the JSON against the same `.winmd` source:

```pwsh
$env:cjHeapSize = "32GB"
cjpm run -m windows-bindgen -- --emit-winmd-json <raw-root> -d <json-dir>
```

Typical explicit roots are:

- `%USERPROFILE%\.nuget\packages\microsoft.windowsappsdk\<version>\lib\uap10.0`
- `%USERPROFILE%\.nuget\packages\microsoft.windowsappsdk\<version>\lib\uap10.0.18362`
- `%USERPROFILE%\.nuget\packages\microsoft.ui.xaml\<version>\lib\uap10.0`
- `%USERPROFILE%\.nuget\packages\microsoft.ui.winui\<version>\lib\uap10.0`

Example from the `windows-cj` repository root, using an already-restored local
WindowsAppSDK package:

```pwsh
$appsdk = "$env:USERPROFILE\.nuget\packages\microsoft.windowsappsdk\1.4.231219000"
$jsonDir = ".generated\winui-winmd-json"
$rootA = (Resolve-Path "$appsdk\lib\uap10.0").Path

$env:cjHeapSize = "32GB"
cjpm run -m windows-bindgen -- --emit-winmd-json $rootA -d $jsonDir

$jsonDirFull = (Resolve-Path $jsonDir).Path
$env:WINDOWS_CJ_WINUI_WINMD_JSON_DIRS = $jsonDirFull
$env:WINDOWS_CJ_WINUI_WINMD_ROOTS = $rootA
python .\scripts\check_windows_common_codegen.py --mode full
```

If these variables are unset, WinUI requested features remain
`BLOCKED/SKIPPED` and the full gate compares the available Windows/Win32/Wdk
metadata subset only.

If WinUI metadata is supplied but does not contain checked-in WinUI selected
symbols, the full gate fails before regeneration with an `input metadata does
not contain checked-in selected symbols` message and an inline compact
`WINUI_MISSING_SELECTED_SYMBOL` report. Use the report to find a metadata root
that contains the missing symbols, then emit JSON from only the matching
explicit root(s). Mixing additional TFM roots can expand the selected surface
and produce unrelated extra symbols/files.

To inspect exactly which supplied JSON/root contributes a checked-in selected
symbol, use the provenance reports:

```pwsh
python .\scripts\check_windows_common_codegen.py --report-missing-winui-selected-symbols
```

When optional WinUI metadata is present, this prints only checked-in WinUI
selected symbols missing from the supplied WinUI feature roots, plus any
same-short-name candidates and their source JSON/root/hash/contract details. If
no WinUI metadata root is present, it reports the blocked requested features
instead of dumping the whole checked-in WinUI closure.

```pwsh
python .\scripts\check_windows_common_codegen.py `
  --provenance-symbol Microsoft.UI.Xaml.IApplication3 `
  --provenance-symbol Windows.UI.Xaml.IApplication3
```

The per-symbol report prints `PROVENANCE FOUND/MISSING`, source JSON, raw
`.winmd` hash, `SourceSet`, contract/version attributes, and the matching raw
root path. This is useful when a Windows SDK type with the same short name
exists but does not match a checked-in `Microsoft.UI.Xaml` type.

Generate from converted metadata:

```pwsh
$env:cjHeapSize = "32GB"
cjpm run -m windows-bindgen -- --input-dir .generated/winmd-json --feature Windows.Foundation --out .generated/windows
```

## windows-common codegen gate

`../scripts/check_windows_common_codegen.py --mode full` regenerates the available
metadata subset into a temporary package and compares it with checked-in
`windows-common`.

Current gate status:

- `scripts/check_workspace_setup.py` passes the active workspace setup and
  generated-output invariant checks for `windows-common`.
- `scripts/check_windows_common_codegen.py --mode quick` passes for the checked-in
  manifest/file hashes and WinMD JSON source checksums.
- `scripts/check_windows_common_codegen.py --mode full` passes for the available
  Windows/Win32/Wdk metadata subset. Older available-subset drift reports are
  closed: MsXml extra symbols (closed), DEVPROPKEY/PROPERTYKEY/BINDINFO GUID
  layout (closed), `SetLastError` checked helpers (closed), and
  Com/Ole/Threading vtable aliases (closed).

The remaining generation limit is input coverage, not a current
Windows/Win32/Wdk subset diff: full WinUI/WindowsAppSDK regeneration needs the
external WinUI/WindowsAppSDK `.winmd` metadata (or JSON emitted from it) that is
not bundled in this repository.

## Native wrapper return-value classification

A native function's raw return value does not, by itself, tell you whether it is
a status code, a sentinel, or an ordinary value. The same `UInt32`/`Int32`/`BOOL`
ABI is used for all three across Win32. The generator therefore classifies each
P/Invoke export's return convention and only then decides what `Result` shape (if
any) to expose.

### Opt-in model: raw default plus an appended checked wrapper

Every P/Invoke renders first as a thin function that returns the native value
verbatim (`renderNativeFunction` in `src/native_helpers.cj`). A checked
`...Checked` overload returning `windows_core.Result<...>` is *appended* only when
the method matches a return-convention allowlist. An export that matches no
allowlist keeps the raw value, which is always safe: the caller receives the
exact native return and interprets it. Because of this, the failure mode to guard
against is not "a missing wrapper" but "a wrong wrapper" — for example, collapsing
a status that has a non-error success value into a `Result<Unit>` that rejects
that value.

### Why some status APIs become `Result<Unit>` and others preserve the value

Some DLLs return a Win32/WSA error code *directly* in the return value (not via a
thread last-error). For those, the classification splits two ways:

- `Result<Unit>` when `ERROR_SUCCESS` (`0`) is the only success value. Examples:
  `HttpInitialize`, `WinHttpReadDataEx`, `DnsSetApplicationSettings`
  (the `...UsesDirectErrorCodeUnit` allowlists).
- `Result<UInt32>`/`Result<Int32>` preserving a closed set of non-error statuses
  when the API documents probe/async/timeout success codes. Examples:
  `WinHttpWebSocketQueryCloseStatus` keeps `0`/`122`, `ProcessSocketNotifications`
  keeps `0`/`258`, `DnsValidateName_*` keeps `0`/`9556`, `HttpReceiveHttpRequest`
  keeps `0`/`997`/`234`/`38` (the `...UsesDirectErrorCodeStatus` allowlists).

Collapsing the second group to `Result<Unit>` would turn `ERROR_INSUFFICIENT_BUFFER`
(`122`), `ERROR_IO_PENDING` (`997`), `WAIT_TIMEOUT` (`258`), or a DNS warning into a
spurious failure. That is why a status return is never auto-mapped on the return
type alone; the success-value set must be proven first.

### WinSock has several incompatible conventions, kept separate on purpose

A WS2_32 export can use any of these, and the generator routes each to a distinct
wrapper:

- `SOCKET_ERROR` (`-1`) sentinel, then the real error comes from `WSAGetLastError`
  (`renderNativeWinSockSocketErrorInt32CheckedWrapper`): `bind`, `connect`, `recv`,
  `send`, ...
- direct WSA error code *in the return value* — the return is the error, no
  `WSAGetLastError` call (`renderNativeWinSockDirectErrorInt32CheckedWrapper`).
- error in an `lpErrno` out-parameter, read on `-1`
  (`renderNativeWinSockLpErrnoInt32CheckedWrapper`).
- `INVALID_SOCKET` / `WSA_INVALID_EVENT` handle sentinels.
- `BOOL`-style success/failure.

Treating a direct-error return as if it were `SOCKET_ERROR` (or vice versa) reads
the wrong error source and reports a wrong or stale error. The conventions must
stay separate even though they share the `Int32` ABI.

### Returns that are values, not statuses

Some integer returns are ordinary values and must keep the raw type — wrapping
them in a `Result` would be wrong. Examples: `htonl`/`ntohl` (byte-swapped value),
`inet_addr` (packed address with an `INADDR_NONE` sentinel), `__WSAFDIsSet` (a
predicate). Type-driven returns (`HRESULT`, `NTSTATUS`, `BOOL` via last-error
families) are handled by their own type rules, not by these per-name allowlists.

### Proving a classification before adding an allowlist entry

Adding an unproven entry is the wrong-wrapper risk above, so a new classification
needs evidence, in roughly this order of strength: metadata (DLL, return type,
parameter shape), official documentation success-value text, SDK header
declarations, and a runtime probe where one is safe. When the evidence is
incomplete or internally ambiguous, do not guess — leave the export on the safe
raw default and record it as a watchlist item with the documented gap.

`scripts/scan_native_return_classification.py` enumerates every P/Invoke export
over `.generated/winmd-json`, buckets the return type, and flags high-confidence
unclassified status candidates (integer returns from the direct-status /
sentinel-convention DLLs that are not yet special-cased). Reviewed candidates that
intentionally keep the raw default are recorded in
`scripts/native_return_classification_baseline.json`, so
`scan_native_return_classification.py --check --baseline <file>` ratchets only on
newly introduced unclassified status exports.

### Evidence sources are different for syntax vs behavior

These are separate obligations:

- Cangjie syntax and stdlib APIs used in generator or generated code must be
  confirmed against the Cangjie documentation, not written from memory.
- Win32/WinRT *behavior* (success-value sets, error sources, ownership) must be
  backed by metadata, official docs, SDK headers, or runtime proof.

### Stay in the Cangjie paradigm

The classification exists to reproduce Win32 ABI behavior, not to recreate an
external language's type system. Do not introduce ownership/borrow/lifetime
markers, value-vs-reference rewrites, or trait shapes from another language to
"match" a reference implementation. Behavior equivalence at the ABI boundary is
the goal; API surface differences that preserve that behavior are not bugs.
