# `vendor/dual` — migration-only provenance observation

> **Purpose**: Identify the current top-level `dual` copy while Phase 1 removes the transitional `vendor/**`
> root.
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
**Referenced by**: DEVELOPMENT_PLAN/phase_01_toolchain_spike.md
**Generated sections**: none

</details>

## Current observation

The transitional tree contains the released `dual-0.1.1.2` Haskell package plus a local GHC-compatibility
change. Its upstream project is `https://github.com/strake/dual.hs`. These prose fields do not select a
revision or drive a build. `LTD-SRC-009` freezes the current path/mode/blob inventory so new or changed bytes
cannot hide behind the open family.

## Required Phase-1 transition

Phase 1 must remove this file and every other `vendor/**` path. Any maintained behavior moves to tested
Haskell modules beneath `src/vendor/**`; required upstream bytes and generated package descriptions exist only
beneath a fresh `.build/vendor/**` run root. Mutable-ref, top-level-vendor, foreign-package, and patch-program
reintroductions must fail independently before the complete owning gate may close the legacy row.

## Related Documents

- [Legacy tracking for deletion](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) — `LTD-SRC-009`
- [Phase 1](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md) — owns the transition; NOT VALIDATED
- [Repository Layout and Artifact Provenance](../../documents/engineering/repository_layout_doctrine.md) —
  owns the exhaustive target tree
