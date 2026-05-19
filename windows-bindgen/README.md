# windows-bindgen

`windows-cj/windows-bindgen` is the executable Cangjie binding generator.
Its Cangjie package name is `windows_bindgen`; the user-facing CLI name is
`windows-bindgen`.

The generator consumes converted WinMD JSON metadata only. The only WinMD
reader in the toolchain is the C#/.NET `winmd-to-json` converter. A native
Cangjie `.winmd` reader is not planned.

## Delivery boundary

This package is an executable generator CLI. It is not the consumer `windows`
projection package.

The checked-in importable generated surface is currently `windows-common`,
whose Cangjie package name is `windows_common`. Its manifest records a selected
feature set, not a full Windows API projection.

- `windows-projection` / `windows_projection` is a tiny consumer facade over the
  checked-in `windows_common` subset.

The active workspace no longer contains `windows-sys` / `windows_sys`. Cangjie
compile speed makes a full raw sys package the wrong deliverable for this
project. Prefer selected generated/common support, expanded through explicit
feature sets and validated manifests, instead of a monolithic raw package.

A small package alias is not the right near-term fix: Cangjie import aliases are
source imports, not replacement package artifacts. The delivery roadmap is:

1. Keep the generator role under `windows-bindgen` / `windows_bindgen`.
2. Expand the high-level projection package beyond the scaffold facade.
3. Expand selected generated/common support through deliberate feature sets.
4. Add feature or package slicing so broad metadata does not force one
   monolithic compile unit.

## Supported inputs

The bindgen input contract is JSON:

- `--input-json <file>` loads one converted metadata JSON file.
- `--input-dir <dir>` loads all `.json` files from a directory, sorted by file name.
- Positional `metadata.json` is shorthand for `--input-json metadata.json`.
- Positional JSON directories are shorthand for `--input-dir <dir>` when the directory contains `.json` files.

Do not add a native `.winmd` parser to this package. `.winmd` inputs must be
converted by `winmd-to-json` before `windows-bindgen` reads them. Any helper that
accepts raw `.winmd` files is only allowed to orchestrate the C#/.NET converter
and then pass JSON to bindgen.

## WinMD conversion workflow

Run commands from the `windows-cj` repository root. The Python helper calls the
local `winmd-to-json` dotnet project with `dotnet publish --no-restore`; it does
not restore packages, parse WinMD in Cangjie, or choose a NuGet cache path
implicitly.

Create a reusable offline JSON input directory, then run bindgen against that
directory:

```pwsh
python .\scripts\convert_winmd_to_json.py --winmd-root .\winmd --json-dir .generated\winmd-json --dry-run
python .\scripts\convert_winmd_to_json.py --winmd-root .\winmd --json-dir .generated\winmd-json --overwrite
$env:cjHeapSize = "32GB"
cjpm test -m windows-bindgen
```

For `scripts/check_windows_common_codegen.py`, the default offline input remains
`.generated/winmd-json` from the repository root and only covers the checked-in
Windows/Win32/Wdk metadata. Native `.winmd` parsing is intentionally out of
scope for the generator and the gate.

### Optional WinUI/WindowsAppSDK metadata

WinUI/WindowsAppSDK metadata must be provided as converted JSON plus the matching
raw `.winmd` files used for hash validation. The gate accepts:

- `--winui-winmd-json-dir <dir>` or `WINDOWS_CJ_WINUI_WINMD_JSON_DIRS`
- `--winui-winmd-root <file-or-dir>` or `WINDOWS_CJ_WINUI_WINMD_ROOTS`

The environment variables are path lists, so use `;` between paths on Windows.
The helper requires explicit roots for reproducibility. To inspect likely local
NuGet cache roots without using them automatically:

```pwsh
python .\scripts\convert_winmd_to_json.py --list-candidates
```

Typical explicit roots are:

- `%USERPROFILE%\.nuget\packages\microsoft.windowsappsdk\<version>\lib\uap10.0`
- `%USERPROFILE%\.nuget\packages\microsoft.windowsappsdk\<version>\lib\uap10.0.18362`
- `%USERPROFILE%\.nuget\packages\microsoft.ui.xaml\<version>\lib\uap10.0`

Example from the `windows-cj` repository root, using an already-restored local
WindowsAppSDK package and avoiding network restore:

```pwsh
$appsdk = "$env:USERPROFILE\.nuget\packages\microsoft.windowsappsdk\1.4.231219000"
$jsonDir = ".generated\winui-winmd-json"
$rootA = (Resolve-Path "$appsdk\lib\uap10.0").Path
$rootB = (Resolve-Path "$appsdk\lib\uap10.0.18362").Path

python .\scripts\convert_winmd_to_json.py --winmd-root $rootA --winmd-root $rootB --json-dir $jsonDir --dry-run
python .\scripts\convert_winmd_to_json.py --winmd-root $rootA --winmd-root $rootB --json-dir $jsonDir --overwrite

$jsonDirFull = (Resolve-Path $jsonDir).Path
$env:WINDOWS_CJ_WINUI_WINMD_JSON_DIRS = $jsonDirFull
$env:WINDOWS_CJ_WINUI_WINMD_ROOTS = "$rootA;$rootB"
python .\scripts\check_windows_common_codegen.py --mode full
```

If these variables are unset, WinUI requested features remain
`BLOCKED/SKIPPED` and the full gate compares the available Windows/Win32/Wdk
metadata subset only.

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
Windows/Win32/Wdk subset diff: full WinUI/WindowsAppSDK regeneration needs
external converted metadata JSON plus matching raw `.winmd` files, and this
generator will continue to consume only converted JSON.
