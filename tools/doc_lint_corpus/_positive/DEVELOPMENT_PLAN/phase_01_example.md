# Phase 1: Example

>
**Purpose**: Fixture phase document.
>
**Read this if**: the example phase is next in the queue.

This fixture phase owns one gate and one sprint.
Its design belongs to [example_doctrine.md](../documents/engineering/example_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md
**Generated sections**: none

</details>

## Phase Status

📋 Planned. Specified before implementation.

## Phase Summary

The reconciler observes the live shape and enacts only the typed actions its stage admits.

**Substrate:** none
**Lane:** none
**Register:** 1
**Requires**: `host-floor`
**Gate:** `cabal test example-spec` is green — the committed golden corpus decodes against an independent oracle and one committed seeded mutant turns it red (Gate; 1.2 V1).

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`; negatives under `test/negative/example/`.

## Doctrine adopted

- [example_doctrine.md §2](../documents/engineering/example_doctrine.md#2-the-bound-shape)
- `extension_conformance_doctrine.md` — the example extension is admitted by satisfying the contract.

## Sprints

## Sprint 1.1: The example sprint 📋

Bound shapes are owned by [example_doctrine.md](../documents/engineering/example_doctrine.md).
The seam is recorded tested against a modeled environment.
