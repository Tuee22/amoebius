# `vendor/supernova` — migration-only provenance observation

> **Purpose**: Identify the current top-level `supernova` copy while Phase 1 removes the transitional
> `vendor/**` root.
> **Read this if**: You are closing `LTD-SRC-009` or reviewing why this path is still tracked.

This file is reader-facing migration inventory only. It is not an authoritative build input, provenance
oracle, permission to retain top-level vendored source, or validation evidence. The canonical target is
[`repository_layout_doctrine.md` §4.1](../../documents/engineering/repository_layout_doctrine.md#41-a-compatibility-edit-is-fixed-source-not-a-patch-against-a-moving-head):
maintained Haskell is re-derived beneath `src/vendor/**/*.hs`; upstream foreign inputs are acquired at an
immutable identity beneath `.build/vendor/**`; provenance and transformations are authored Haskell values.

<details>
<summary>Link-graph metadata</summary>

**Status**: Migration-only observation — NOT VALIDATED
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, documents/engineering/pulsar_client_doctrine.md
**Generated sections**: none

</details>

## Current observation

The transitional tree contains Haskell from `https://github.com/cr-org/supernova`, foreign Cabal/build inputs,
and `pulsar_api.proto`. It carries local GHC compatibility and generated-binding changes. These prose fields do
not select a revision or drive a build. The Proto path is accounted under `LTD-SRC-009`, not again under
`LTD-SRC-003`; the frozen family fingerprint prevents a new or modified vendor path from riding the open row.

## Required Phase-1 transition

Phase 1 must remove this file and every other `vendor/**` path. Maintained client behavior moves to tested
Haskell modules beneath `src/vendor/**`. The immutable upstream acquisition, Proto schema, generated bindings,
package descriptions, transformations, and diagnostic provenance are materialized only beneath a fresh
`.build/vendor/**` run root. Mutable-ref, top-level-vendor, tracked-Proto, foreign-package, and patch-program
reintroductions must each fail at their exact locus before the complete owning gate may close `LTD-SRC-009`.

## Related Documents

- [Legacy tracking for deletion](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) — `LTD-SRC-009`
- [Phase 1](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md) — owns the transition; NOT VALIDATED
- [Pulsar Client Doctrine](../../documents/engineering/pulsar_client_doctrine.md) — owns the target client
- [Repository Layout and Artifact Provenance](../../documents/engineering/repository_layout_doctrine.md) —
  owns the exhaustive target tree
