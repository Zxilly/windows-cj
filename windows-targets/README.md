Baseline import archives for Windows GNU linkers.

`windows-cfggen` prefers these archives when they are present so generated workspaces can link the full Win32/WinRT surface without depending on whatever subset of import libraries happens to ship with the local MinGW installation.

Current contents:

- `x86_64_gnu/lib/libwindows.0.53.0.a`
