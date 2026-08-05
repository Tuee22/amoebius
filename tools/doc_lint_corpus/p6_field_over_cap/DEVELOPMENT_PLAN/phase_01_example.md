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
**Register:** 1
**Blocked by**: nothing, and the whole justification is restated in the field rather than moved into a numbered Validation list: no cluster is stood up, no host is touched, no credential is read, no external service is contacted, no registry is pulled from, and every artifact the run consumes is committed beforehand and then re-read from the working tree on each and every run, so that the whole justification sits in one field instead of a list.
**Gate:** `cabal test example-spec` is green — the committed golden corpus decodes against an independent oracle and one committed seeded mutant turns it red (Gate; 1.2 V1).

## Doctrine adopted

- [example_doctrine.md §2](../documents/engineering/example_doctrine.md#2-the-bound-shape)

## Sprints

## Sprint 1.1: The example sprint 📋

Bound shapes are owned by [example_doctrine.md](../documents/engineering/example_doctrine.md).
The seam is recorded tested against a modeled environment.
