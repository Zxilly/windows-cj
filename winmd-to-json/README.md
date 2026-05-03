# winmd-to-json

WinMD → JSON converter for the windows-cj VPGC bindgen pipeline. Vendored from
[ynkdir/winmd-printer](https://github.com/ynkdir/winmd-printer) (MIT, copyright
Yukihiro Nakadaira).

## Acknowledgement

This tool is built on top of `winmd-printer` by **Yukihiro Nakadaira**. The
upstream `Program.cs` provides the bulk of the WinMD parsing and JSON serialization
logic via .NET `System.Reflection.Metadata`. We thank ynkdir for releasing it
under MIT.

Upstream: <https://github.com/ynkdir/winmd-printer>

## What's different from upstream

The upstream tool is general-purpose. We may add windows-cj specific output
fields in later milestones (e.g., explicit `supported_architectures` array,
`source_set` discriminator). At M0.7 the only delta is the csproj — we use
`PublishSingleFile` + `SelfContained` for portable deployment.

## Build

```pwsh
pwsh scripts/build_and_publish.ps1
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
