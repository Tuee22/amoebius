# `pb/stubs` — condemned migration footprint

> **Purpose**: Prevent this legacy directory from being mistaken for a sanctioned source location.
> **Read this if**: a type stub or Python dependency appears necessary for the bootstrap package.

This directory is reference-only migration residue governed by `LTD-SRC-008` in the
[single active legacy register](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md). It grants no
exception beyond the bounded Python handoff owned by
[`repository_layout_doctrine.md` §2](../../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure).

<details>
<summary>Link-graph metadata</summary>

**Status**: Deprecated
**Supersedes**: N/A
**Referenced by**: pb/README.md
**Generated sections**: none

</details>

No `.pyi` or other behavioral source may be added here. The bounded bootstrap must avoid an untyped
dependency or consume types supplied by its external package environment; amoebius does not maintain a
second tracked interface implementation. Any diagnostic projection needed while migrating the package is
generated lazily beneath `.build/**`.

The directory is removed when `LTD-SRC-008` closes. Its presence is **NOT VALIDATED** and is not evidence
that a stub exception exists.

## Related Documents

- [`pb` boundary](../README.md)
- [Repository layout doctrine](../../documents/engineering/repository_layout_doctrine.md)
- [Single active legacy register](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md)
