# Example Storage Slice

>
**Purpose**: Fixture catalog entries for storage.
>
**Read this if**: a storage entry has to be read.

This fixture slice owns two storage entries.
Numbering belongs to [the catalog](./illegal_state_catalog.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/illegal_state/illegal_state_catalog.md
**Generated sections**: none

</details>

### 3.1 A claim without a backing volume

**Validation-locus:** `dhall-typecheck`

The claim field is mandatory.

### 3.2 A volume without a ceiling

**Validation-locus:** `gadt-decode`

The ceiling field is mandatory.
