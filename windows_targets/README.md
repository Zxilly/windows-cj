Baseline import archives for Windows GNU linkers.

This package is a link-time asset bundle, not a source-level dependency.
The root workspace setup gate validates the published target matrix and bundled
archive payload. Source packages should not add `windows_targets` to their
`[dependencies]` table just to reach link assets; link tooling should locate the
package root and consume the archive path or GNU link options exposed by the
helper APIs below.

Legacy generator/link tooling used the archive both to enumerate available
Win32 import symbols and to replace per-DLL `-l...` flags with a single
`-L<lib> -l:libwindows.0.53.0.a` pair. Those historical tool names are not
current workspace package deliverables.

Support matrix:

| Target key | OS | Architecture | Toolchain | Cangjie `env` | Status | Payload | Reason when unsupported |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `x86_64_gnu` | Windows | `x86_64` | GNU | `gnu` | supported | `x86_64_gnu/lib/libwindows.0.53.0.a` | - |
| `i686_gnu` | Windows | `i686` | GNU | `gnu` | unsupported | none | no bundled import library payload exists under `i686_gnu/lib` |
| `aarch64_gnu` | Windows | `aarch64` | GNU | `gnu` | unsupported | none | no bundled import library payload exists under `aarch64_gnu/lib` |
| `x86_64_msvc` | Windows | `x86_64` | MSVC | empty | unsupported | none | no bundled MSVC import library payload exists under `x86_64_msvc/lib` |
| `i686_msvc` | Windows | `i686` | MSVC | empty | unsupported | none | no bundled MSVC import library payload exists under `i686_msvc/lib` |
| `aarch64_msvc` | Windows | `aarch64` | MSVC | empty | unsupported | none | no bundled MSVC import library payload exists under `aarch64_msvc/lib` |

Unsupported targets are known target keys without a bundled payload in this
package. They intentionally do not publish placeholder archive files. Callers
must resolve a linkable target through `requireSupportedImportLibTarget` or
`requireCurrentImportLibTarget`; those APIs throw `UnsupportedTarget` before
link flags or ABI assumptions are used.

Current payload scope: only `x86_64_gnu` ships a bundled import archive. Adding
other target payloads requires real archive assets under the matching target
directory; placeholder files are not considered support.

Helper APIs:

- `ImportLibTarget.archiveRelativePath()` returns the bundled archive path
  relative to the package root, such as
  `x86_64_gnu/lib/libwindows.0.53.0.a`, or `None` when no payload is bundled.
- `ImportLibTarget.requireArchiveRelativePath()` returns the same path for a
  supported target and throws `UnsupportedTarget` for a target without payload.
- `ImportLibTarget.archivePath(root)` and
  `ImportLibTarget.requireArchivePath(root)` prefix the relative path with a
  caller-provided package root.
- `ImportLibTarget.gnuLinkOptions(root)` returns the two linker flags needed
  by GNU-style linkers: `-L<root>/<target-lib-dir>` and
  `-l:<archive-name>`. It returns `None` for unsupported targets.
- `ImportLibTarget.requireGnuLinkOptions(root)` returns those flags for a
  supported GNU target and throws `UnsupportedTarget` otherwise.
- `findImportLibTarget(name)` returns any known target descriptor, including
  unsupported targets, when callers want matrix introspection.
- `findSupportedImportLibTarget(name)` returns `None` instead of throwing
  when callers want probing behavior for linkable payloads only.
