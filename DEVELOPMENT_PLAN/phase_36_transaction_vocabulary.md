# Phase 36: The closed transaction vocabulary

> **Purpose**: Make the relational data plane a closed, request-scoped transaction GADT whose row
> declarations generate schema, policies, statements, and additive generation transitions.
> **Read this if**: a relational transaction, row type, row policy, or schema generation has to change, or the
> absence of a raw query surface has to be checked.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/extension_conformance_transactions.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 36.1: Row declarations drive schema and policy ⏸️](#sprint-361-row-declarations-drive-schema-and-policy-)
- [Sprint 36.2: The closed request-scoped transaction GADT ⏸️](#sprint-362-the-closed-request-scoped-transaction-gadt-)
- [Sprint 36.3: Additive schema generations ⏸️](#sprint-363-additive-schema-generations-)
- [Sprint 36.4: Compile barriers, semantic mutants, and calculus evidence ⏸️](#sprint-364-compile-barriers-semantic-mutants-and-calculus-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 35, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** Three private Haskell row declarations are to name documents, jobs,
and releases. Each declaration fixes its table, required
columns, composite primary key, tenant foreign key, and scope column. The schema renderer and row-policy
renderer consume those same values. The emitted SQL is therefore generated output beneath `.build/sql/**`,
while separately reviewed Haskell semantic rows state the exact DDL and policy meaning.

Five private GADT constructors form the whole transaction vocabulary: insert/read document, list jobs,
advance job status, and record release. Their five exported smart constructors all require a generative
`RequestScope scope`, and their result types retain that same phantom index through `Scoped scope`. No raw
statement value, predicate combinator, declaration constructor, or transaction constructor is exported.

Schema evolution is a closed transition between three generations. The two admitted edges retain every old
row coordinate and add one table; current, regressing, and skipped edges refuse with distinct errors. Neither
the transition union nor the generated SQL can express `DROP`, `TRUNCATE`, or `DELETE`.

**Phase scope:** one target claim — every relational operation is a declared, request-scoped Haskell constructor,
and schema, policy, statement, result index, and additive generation follow from closed terms. A live database,
connection role, policy enforcement probe, or destructive-retention lifecycle splits out.

**Substrate:** `none` — declarations, transactions, transitions, SQL projections, and compiler barriers are
values; no database is contacted ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `none` ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure Haskell/generative: Haskell semantic oracles and compiler refusals constrain the closed vocabulary;
generated SQL remains an output rather than authority ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 35](phase_35_image_recipe_generation.md)
**Gate:** `pb validate phase 36`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — every relational operation is a declared request-scoped Haskell constructor; schema, policy, statement, and mutation bytes are lazy `.build/**` projections constrained by Haskell semantics. No live database or policy-enforcement claim is included. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 36` is future public spelling only. Before current reviewer approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 35; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Doctrine adopted

- [`extension_conformance_transactions.md` §3 — Why there is no ORM](../documents/engineering/extension_conformance_transactions.md#3-why-there-is-no-orm):
  the exported API is a closed domain vocabulary rather than a statement language.
- [`extension_conformance_transactions.md` §4 — P1–P6](../documents/engineering/extension_conformance_transactions.md#4-p1p6):
  request scope is required, row declarations drive schema/policy/statements, results retain the scope index,
  and generations have only additive transitions.
- [`generated_artifacts_doctrine.md` §2 — What is generated (and from what)](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what):
  emitted schema, policy, and statement SQL remain generated output constrained by separately authored Haskell
  semantic expectations.

---

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 36.1: Row declarations drive schema and policy ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 35](phase_35_image_recipe_generation.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt P3 and P4; derive schema and policy from one private row declaration rather than two authored texts.

### Deliverables

- Three closed row declarations with no nullable scope-bearing column.
- One shared scope-predicate term consumed by policy and statement rendering.
- Deterministic SQL projection to `.build/sql/**`, with no tracked output copy.

### Validation

1. All row semantics join to the independent Haskell oracle in both directions.
2. The export and source scans prove the declaration and predicate terms remain private and shared.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 36.2: The closed request-scoped transaction GADT ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 36.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt P1, P2, and P5; make the closed transaction arm carry the request scope and preserve it on the result.

### Deliverables

- Five private GADT constructors and five exported request-scope-requiring smart constructors.
- Five `Scoped scope` result shapes indexed by the same generative scope as the transaction.
- Four independent compiler barriers with exact expected reasons.

### Validation

1. Every smart constructor matches its independently authored semantic row.
2. All four illegal programs fail while the same-scope twin compiles and runs.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 36.3: Additive schema generations ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 36.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt P6; replace migration edits with a typed, additive transition union.

### Deliverables

- Three schema generations with exactly two adjacent admitted transitions.
- Retained-row and added-row projections for every admitted edge.
- Exact current, regression, and skipped-transition errors and no destructive verb.

### Validation

1. All five generation cases match the authored verdict and reason.
2. Generated SQL contains no `DROP`, `TRUNCATE`, or `DELETE` token.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 36.4: Compile barriers, semantic mutants, and calculus evidence ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 36.3
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Seal the complete pure transaction boundary with falsifiable negative controls and the re-baselined calculus
projection.

### Deliverables

- Three Haskell-registered changed-subject mutant descriptors and exact red-locus assertions.
- A 20-entry validation-locus ledger over every bounded item.
- One real five-calculus composition and a generated-output/attestation gate.

### Validation

1. Every Haskell compiler negative and changed-subject mutant fails at only its authored reason or locus.
2. All metrics and 39 authored surfaces join completely to runtime enumeration.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

---

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- `documents/engineering/extension_conformance_transactions.md` — the scope section records the tested bounded
  P1–P6 instance while retaining live database enforcement as UNVERIFIED.
- `documents/engineering/generated_artifacts_doctrine.md` — the relational-schema row records the concrete
  declaration module and semantic oracle.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/system_components.md` — add the pure transaction-vocabulary component and keep live
  Postgres ownership with later phases.

---

## Related Documents

- [The Transaction Laws](../documents/engineering/extension_conformance_transactions.md)
- [Generated Artifacts](../documents/engineering/generated_artifacts_doctrine.md)
- [Phase 8](phase_08_scope_index.md)
- [Phase 10](phase_10_calculus_composition.md)
- [Development Plan](README.md)
