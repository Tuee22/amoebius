# Phase 2: Repository layout conformance and de-phased naming

> **Purpose**: Move the authored tree to the target layout [repository_layout_doctrine.md §2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure)
> declares, collapse `test/`'s second level to its seven role nouns, and strip the phase ordinal from every
> authored name outside this plan suite — so that every later phase is written against the tree it will
> actually run on, and a re-baseline stays documentation-only.
> **Read this if**: phase 2 is next in the queue, or a later phase depends on what its gate establishes.

Phase 2 delivers repository layout conformance; its design is owned by [repository_layout_doctrine.md](../documents/engineering/repository_layout_doctrine.md), [generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md), and the plan for reaching it is owned here.
Register 1: a pure tree-and-resolution gate, no host and no cluster.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 2.1: `test/`'s second level collapses to the seven role nouns 📋](#sprint-21-tests-second-level-collapses-to-the-seven-role-nouns-)
- [Sprint 2.2: One mutant record format, one registry 📋](#sprint-22-one-mutant-record-format-one-registry-)
- [Sprint 2.3: The package-only roots become cabal stanzas 📋](#sprint-23-the-package-only-roots-become-cabal-stanzas-)
- [Sprint 2.4: `ui-runtime/` merges into `ui/` 📋](#sprint-24-ui-runtime-merges-into-ui-)
- [Sprint 2.5: Every authored name loses its phase ordinal 📋](#sprint-25-every-authored-name-loses-its-phase-ordinal-)
- [Sprint 2.6: The allowlist and the register reconcile 📋](#sprint-26-the-allowlist-and-the-register-reconcile-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-1 revalidation — created 2026-08-17 by the one-binary/ordering re-baseline recorded in
[`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md).

## Phase Summary

This phase makes the authored tree **be** the target tree. Today it is not, and the gap is not a backlog of
small divergences: `test/`'s second level carries twenty-seven names where
[§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) declares seven,
with singular and plural living side by side as separate directories; fourteen roots carry a package
declaration and little else — four of them hold nothing but it; and several hundred authored paths carry a phase ordinal, which
[§U](development_plan_gate_integrity.md#u-the-final-repository-layout) clause 3 forbids precisely so that a
re-baseline stays documentation-only.

**Why this is a phase and not a sprint of Phase 0.** Four rows of the legacy register state a closure
predicate quantified over the *whole tree* — no plural sibling anywhere under `test/`, no package-only root,
no ordinal-bearing authored path — and assign it to a *distributed* owner ("each owning phase, at its rerun").
[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 5 forbids deferring a
finding out of the phase that owns it, and [§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase)
names the owner as the phase whose gate must clear it, never a later one. A whole-tree predicate has exactly
one legitimate owner: a phase whose scope is the whole tree. This is that phase.

**A relocation is not a deletion.** The migration allowlist attributes a shared-surface finding to the phase
whose closure retires it, which for a *deletion* is genuinely the last consumer — a root cannot be deleted
while a phase still builds from it. A **relocation** is a rename plus its reference update performed as one
edit, so no consumer ever reads the old path and there is no last consumer to wait for. Conflating the two is
what scheduled `git mv test/fixtures` behind forty-four phases. This phase takes the relocations; the
deletions stay with their last consumer.

**Phase scope:** one cohesive claim — *the authored tree is the target tree, and every consumer resolves at
it* — across six seams, one acceptance command, and no behavioural change to any module. A second claim (that
a moved module still *does* what it did) is not this phase's; the phases that own those modules re-establish
it when they rerun.

**Substrate:** `none` — no host, no cluster, no engine ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 1 — pure/golden, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Requires**: `host-floor`

**Gate:** `python3 tools/repository_conformance_gate.py` passes every check named in
[Gate integrity](#gate-integrity). Phase 3 does not open unless the ledger records Register 1 green, the
artifact audit reports zero `r13` and `r15` findings, and the seeded mutants are red.

## Gate integrity

The gate's independent oracle is **not this phase's code**: it is `parse_target_tree` / `offending_prefix` in
`tools/artifact_policy.py`, which read the target tree out of
[repository_layout_doctrine.md §2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure)
— a document Phase 0 owns and this phase does not edit
([§M](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 3). The
authored fixture is `tools/layout_relocation_map.tsv`, one row per moved prefix carrying its old prefix, its
new prefix, and the [§2.2](../documents/engineering/repository_layout_doctrine.md#22-present-day-roots-and-their-required-destination) destination cell that licenses the move; it is authored **before** the move, so the
gate compares the tree against a plan rather than against itself.

Six committed mutants, each of which must redden its own named rule and no other:

- **m1** reintroduces a `test/fixtures/` path — `r13`.
- **m2** reintroduces a `tools/phase31_gate.py`-shaped name — `r15`.
- **m3** adds a relocation-map row whose destination the target tree does not admit — the map itself is
  checked against [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure), so a map that lies is caught before the tree is touched.
- **m4** moves a file while leaving one tracked consumer naming its old path — the dangling-reference check.
- **m5** renames a cabal stanza but leaves its `hs-source-dirs` at the old path — resolution, not text.
- **m6** restores a case-collision pair (`test/ui/` beside `test/Ui/`).

**m6 is not decoration.** Two of the four substrates reach the tree case-insensitively, so a plural/singular
pair that differs only in case cannot be resolved by a bulk move — one side silently overwrites the other.
The collision check therefore runs **before** any relocation sprint, and its mutant proves it can fail.

## Doctrine adopted

- [repository_layout_doctrine.md §2 — complete repository structure](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure):
  the target tree, its fixed second levels, and the seven singular `test/` role nouns.
- [repository_layout_doctrine.md §2.1 — when a unit warrants its own build package](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package):
  the criterion a package-only root fails.
- [repository_layout_doctrine.md §2.2 — present-day roots and their required destination](../documents/engineering/repository_layout_doctrine.md#22-present-day-roots-and-their-required-destination):
  the per-root destination this phase realises.
- [generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md): the rule that
  separates a relocation from a deletion — a generated destination cannot hold bytes until its generator runs.

## Sprints

## Sprint 2.1: `test/`'s second level collapses to the seven role nouns 📋

**Status**: Planned
**Implementation**: `test/**`, `tools/layout_relocation_map.tsv`
**Blocked by**: none within the phase.
**Independent Validation**: `git ls-files test/ | cut -d/ -f2 | sort -u` equals exactly the seven nouns [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure)
declares; m1 and m6 each redden their own rule.
**Docs to update**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

Fold twenty prefixes into `spec`, `fixture`, `golden`, `negative`, `oracle`, `mutant`, and `harness`, closing
the singular/plural pairs first because they are the ones a case-insensitive filesystem cannot hold apart.

### Deliverables
- The case-collision check and its mutant, run before any move.
- Every `test/` second-level name one of the seven, with module hierarchy below `test/spec/`, never at the
  second level.
- Every tracked consumer of a moved path updated in the same edit.

### Validation
1. The seven-noun assertion above, plus a dangling-reference scan over the whole tree.
2. m1 and m6 redden `r13` and the collision check respectively, and no other rule.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 2.2: One mutant record format, one registry 📋

**Status**: Planned
**Implementation**: `test/mutant/**`
**Blocked by**: Sprint 2.1
**Independent Validation**: every mutation is a registry row; no mutation is carried by a build flag alone.
**Docs to update**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

`mutants/`, `test/mutants/`, and `test/host/mutants/` become one `test/mutant/**` with one record format, and
the mutations currently carried as build flags become registry fields.

### Deliverables
- One mutant root, one record format, one registry.
- Each former build-flag mutation expressed as a registry row.

### Validation
1. The registry enumerates every mutation, and every mutant resolves through it.
2. A mutation reachable only by a build flag fails the gate.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 2.3: The package-only roots become cabal stanzas 📋

**Status**: Planned
**Implementation**: `amoebius.cabal`, `cabal.project`, `src/**`, `test/**`
**Blocked by**: Sprint 2.1
**Independent Validation**: `cabal build all` and `cabal test --dry-run` resolve; no root outside the target
tree holds a package declaration.
**Docs to update**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

Fourteen roots carry a package declaration and little else. Each becomes a stanza in the one authored package,
against the criterion [§2.1](../documents/engineering/repository_layout_doctrine.md#21-when-a-unit-warrants-its-own-build-package)
already states; the two out-of-tree `hs-source-dirs` become `source-repository-package` entries.

### Deliverables
- Sources under `src/**`, `test/**`, `proto/**`, `dhall/**` as [§2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure) places them.
- No `hs-source-dirs` reaching outside the repository.

### Validation
1. Resolution and dry-run test discovery both succeed at the new names.
2. m5 reddens: a stanza renamed without its source directory fails.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 2.4: `ui-runtime/` merges into `ui/` 📋

**Status**: Planned
**Implementation**: `ui/**`
**Blocked by**: Sprint 2.3
**Independent Validation**: one spago project; every authored PureScript module is reachable from it.
**Docs to update**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

One PureScript root, and no authored module outside a build.

### Deliverables
- A single `ui/**` root under one spago project.
- The ignore contract naming no departed root.

### Validation
1. Every authored PureScript module is reachable from the one project.
2. No ignore rule names a root the tree no longer has.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 2.5: Every authored name loses its phase ordinal 📋

**Status**: Planned
**Implementation**: `tools/**`, `test/**`, `src/**`, `amoebius.cabal`
**Blocked by**: Sprint 2.3
**Independent Validation**: the `r15` audit reports zero findings; the only ordinal-bearing names left are
this plan suite's own `phase_NN_*.md`.
**Docs to update**: every phase document whose `Implementation` names a renamed path

### Objective

Strip the ordinal from every authored path, build flag, suite name, and ignore rule outside
`DEVELOPMENT_PLAN/`, replacing it with a capability name derived from the owning phase's slug. This is what
makes [§U](development_plan_gate_integrity.md#u-the-final-repository-layout) clause 3 true, and therefore what
makes every future re-baseline documentation-only.

### Deliverables
- Capability-derived names for every ordinal-bearing authored path.
- Every phase document's `Implementation`, oracle, mutant, golden, and gate command naming the new path.

### Validation
1. `r15` reports zero findings.
2. m2 reddens: a reintroduced ordinal-bearing tool name fails.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 2.6: The allowlist and the register reconcile 📋

**Status**: Planned
**Implementation**: `tools/migration_allowlist.tsv`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`
**Blocked by**: Sprint 2.5
**Independent Validation**: the allowlist is shrink-only, so a deleted row *is* the closure evidence; the
audit refuses to run with a row matching nothing.
**Docs to update**: `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`

### Objective

Delete every `r13` and `r15` row, re-own each remaining row under the re-baseline's audit map, and narrow the
rows whose residue is behavioural rather than positional.

### Deliverables
- Zero `r13` and `r15` rows.
- Each residue row narrowed to the behavioural half its subject-matter phase owns.

### Validation
1. The artifact audit reports zero `r13`/`r15` findings and refuses no row.
2. The deferral total falls to the deletion class alone.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `repository_layout_doctrine.md` — §2.2's destination cells become history once realised (Sprint 2.6).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` Phase Overview links its Phase 2 row to this document.
- Each moved path's owning phase document names the new path (Sprint 2.5).

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 2 row is the source for this phase's objective and gate.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys.
- [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) — the register whose whole-tree rows this
  phase exists to make satisfiable.
- [`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md) — the target tree
  this phase realises.
- [`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md) — the
  emit-from-source, never-commit rule that separates a relocation from a deletion.
