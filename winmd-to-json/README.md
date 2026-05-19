# winmd-to-json

WinMD to JSON converter for the windows-cj bindgen pipeline. This C#/.NET tool
is the only WinMD reader in the active toolchain. `windows-bindgen`
(`windows_bindgen`) consumes the JSON emitted by this converter; no native
Cangjie `.winmd` reader is planned.

Vendored from [ynkdir/winmd-printer](https://github.com/ynkdir/winmd-printer)
(MIT, copyright Yukihiro Nakadaira).

## Acknowledgement

This tool is built on top of `winmd-printer` by **Yukihiro Nakadaira**. The
upstream `Program.cs` provides the bulk of the WinMD parsing and JSON serialization
logic via .NET `System.Reflection.Metadata`. We thank ynkdir for releasing it
under MIT.

Upstream: <https://github.com/ynkdir/winmd-printer>

## What's different from upstream

The upstream tool is general-purpose. This fork defines the converter contract
used by the JSON-backed bindgen pipeline:

- top-level metadata fields: `winmd_file`, `winmd_sha256`, `tool_version`,
  `schema_version`, and `source_set`
- per-type `source_set` propagation for split namespace output
- a portable deployment csproj using `PublishSingleFile` + `SelfContained`

Quality gates validate the `winmd_file` / `winmd_sha256` header against the raw
WinMD source used for conversion.

Keep WinMD parsing changes here. Cangjie packages should depend on converted
JSON and should not grow a separate native metadata reader.

## Build

```pwsh
python scripts/build_and_publish.py
```

This produces `bin/winmd-to-json.exe` (self-contained Windows x64).

## Usage

```pwsh
.\bin\winmd-to-json.exe <path-to-winmd> > out.json
```

Example:

```pwsh
.\bin\winmd-to-json.exe ..\..\winmd\Windows.Win32.winmd > /tmp/win32.json
```

## License

MIT (see LICENSE for full text including upstream copyright).
