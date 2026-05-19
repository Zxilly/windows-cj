# windows-projection

This is a scaffold consumer projection package. Its Cangjie package name is
`windows_projection` because `windows` is already the generator executable
package in this workspace.

Current scope:

- prove a consumer package can import checked-in generated `windows_common`
- expose tiny `windows_projection.Win32.Foundation` and
  `windows_projection.Win32.System.Threading` facades for smoke tests
- avoid claiming the full future `windows` projection package is shipped
- keep documenting that `windows` remains occupied by the generator executable

Future work can either rename the generator package or keep this package as the
stable consumer package and expand its generated facade surface. Until that
happens, full projection delivery and feature slicing remain open.
