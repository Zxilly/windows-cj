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

Current contents:

- `x86_64_gnu/lib/libwindows.0.53.0.a`
