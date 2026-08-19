# `pb/stubs` — type stubs for dependencies that ship none

This directory is on `mypy_path`. It is linted and formatted with the rest of the
distribution but is never a type-check *target*: mypy errors on a directory holding no
module, and a stub is a declaration about someone else's code rather than code of ours.

A `.pyi` belongs here when a runtime dependency has no inline types and no published stub
package. Writing one is the sanctioned alternative to a `# type: ignore`, which
`pb.check_code` refuses outright — an ignore hides the gap, a stub states it.

There is nothing here today because `click`, the only runtime dependency, ships `py.typed`.
