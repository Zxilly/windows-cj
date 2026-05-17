Baseline import archives for Windows GNU linkers.

This package is a link-time asset bundle, not a source-level dependency.
Two pipeline stages locate the archive by relative path; therefore no
`cjpm` consumer adds `windows_targets` to its `[dependencies]` table.

- `windows-bindgen` runs `nm` / `llvm-nm` against the archive to enumerate
  the universe of Win32 import symbols it can validly emit bindings for.
- `windows-cfggen` substitutes a single `-L<lib> -l:libwindows.0.53.0.a`
  pair for the per-DLL `-l...` link flags whenever the archive is present,
  freeing consumers from depending on whatever subset of import libraries
  ships with the local MinGW installation.

Support matrix:

| Target key | OS | Architecture | Toolchain | Cangjie `env` | Status | Payload |
| --- | --- | --- | --- | --- | --- | --- |
| `x86_64_gnu` | Windows | `x86_64` | GNU | `gnu` | supported | `x86_64_gnu/lib/libwindows.0.53.0.a` |
| `i686_gnu` | Windows | `i686` | GNU | `gnu` | planned | none |
| `aarch64_gnu` | Windows | `aarch64` | GNU | `gnu` | planned | none |
| `x86_64_msvc` | Windows | `x86_64` | MSVC | empty | planned | none |
| `i686_msvc` | Windows | `i686` | MSVC | empty | planned | none |
| `aarch64_msvc` | Windows | `aarch64` | MSVC | empty | planned | none |

Planned targets intentionally do not publish placeholder archive files.
Callers must resolve a target through `requireSupportedImportLibTarget` or
`requireCurrentImportLibTarget` so unsupported targets fail before link flags
or ABI assumptions are used.

Helper APIs:

- `ImportLibTarget.archiveRelativePath()` returns the bundled archive path
  relative to the package root, such as
  `x86_64_gnu/lib/libwindows.0.53.0.a`.
- `ImportLibTarget.archivePath(root)` prefixes that relative path with a
  caller-provided package root.
- `ImportLibTarget.gnuLinkOptions(root)` returns the two linker flags needed
  by GNU-style linkers: `-L<root>/<target-lib-dir>` and
  `-l:<archive-name>`.
- `findSupportedImportLibTarget(name)` returns `None` instead of throwing
  when callers want probing behavior.
