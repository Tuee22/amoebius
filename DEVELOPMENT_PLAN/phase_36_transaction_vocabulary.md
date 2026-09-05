# Phase 36: The closed transaction vocabulary

> **Purpose**: Make the relational data plane a closed, request-scoped transaction GADT whose row
> declarations generate schema, policies, statements, and additive generation transitions.
> **Read this if**: a relational transaction, row type, row policy, or schema generation has to change, or the
> absence of a raw query surface has to be checked.

This is the active Phase-36 contract. Its implementation is bound below, while completion remains exclusively
owned by the exact integrated gate and the mechanical status projection that follows a pass.

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
- [Sprint 36.1: Row declarations drive schema and policy](#sprint-361-row-declarations-drive-schema-and-policy-)
- [Sprint 36.2: The closed request-scoped transaction GADT](#sprint-362-the-closed-request-scoped-transaction-gadt-)
- [Sprint 36.3: Additive schema generations](#sprint-363-additive-schema-generations-)
- [Sprint 36.4: Compile barriers, semantic mutants, and calculus evidence](#sprint-364-compile-barriers-semantic-mutants-and-calculus-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 35 and every earlier gate have passed in numerical order. The closed transaction GADT, independent Haskell
oracle, four compiler barriers, additive generation model, and three changed-production challenges are bound;
only the complete integrated Phase-36 gate may authorize completion.

---

## Phase Summary

**Target capability — NOT VALIDATED.** Three private Haskell row declarations are to name documents, jobs,
and releases. Each declaration fixes its table, required
columns, composite primary key, tenant foreign key, and scope column. The schema renderer and row-policy
renderer consume those same values. The emitted SQL is therefore generated output beneath `.build/sql/**`,
while separately authored Haskell semantic rows state the exact DDL and policy meaning.

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
**Gate:** `pb validate phase 36`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `pure-closed-transaction-vocabulary` |
| `Subject` | `acquired-transaction-vocabulary-supervisor` |
| `Command` | `pb validate phase 36` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-transaction-vocabulary-oracle` |
| `Positive controls` | `transaction-vocabulary-positive-controls` |
| `Paired negatives` | `transaction-vocabulary-compiler-negatives` |
| `Mutants` | `applied-transaction-vocabulary-production-mutants` |
| `Discovery` | `exact-transaction-vocabulary-source-discovery` |
| `Challenge` | `post-acquisition-transaction-vocabulary-challenge` |
| `Observer` | `transaction-vocabulary-process-observation` |
| `Authority/bypass` | `no-pb-network-database-host-hardware-or-parallelism` |
| `Freshness` | `fresh-transaction-vocabulary-build-root-and-stable-source` |
| `Qualification` | `qualified-transaction-vocabulary-harness` |
| `Cleanroom` | `transaction-vocabulary-products-contained-below-build` |
| `Legacy closure` | `retired-transaction-vocabulary-authorities-absent` |
| `Predecessor` | `exact-phase-thirty-five-receipt` |
| `Residue` | `live-database-policy-runtime-owners-explicit` |
| `Pass criterion` | `qualified-phase-thirty-six-gate-pass` |

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

> **Historical sprint results.** Earlier completion statements in sprint prose are capability inventory only;
> current completion remains owned by the integrated gate.

## Sprint 36.1: Row declarations drive schema and policy ✅

**Status**: Done
**Implementation**: `src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs`, `test/spec/transaction/{TransactionVocabularySpec,TransactionVocabularyOracle}.hs`, the compile-negative program, and the package-hidden Phase-36 supervisor own this sprint surface.
**Blocked by**: [Phase 35](phase_35_image_recipe_generation.md) gate pass
**Independent Validation**: one clean Haskell semantic suite, four compiler-negative rows, and three production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/transaction/TransactionVocabularyOracle.hs` independently fixes three row declarations, five transactions, five generation cases, four calculus projections, four compiler barriers, three mutant loci, and twenty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, six serialized oracle files, and three materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substates.md`, and the linked transaction/generated-artifact doctrines.

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

The complete integrated Phase-36 gate and its mechanical status projection remain. Live database connections, executor roles, policy enforcement, retention lifecycle, services, and hardware remain later-owned residue.

## Sprint 36.2: The closed request-scoped transaction GADT ✅

**Status**: Done
**Implementation**: `src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs`, `test/spec/transaction/{TransactionVocabularySpec,TransactionVocabularyOracle}.hs`, the compile-negative program, and the package-hidden Phase-36 supervisor own this sprint surface.
**Blocked by**: Sprint 36.1
**Independent Validation**: one clean Haskell semantic suite, four compiler-negative rows, and three production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/transaction/TransactionVocabularyOracle.hs` independently fixes three row declarations, five transactions, five generation cases, four calculus projections, four compiler barriers, three mutant loci, and twenty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, six serialized oracle files, and three materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substates.md`, and the linked transaction/generated-artifact doctrines.

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

The complete integrated Phase-36 gate and its mechanical status projection remain. Live database connections, executor roles, policy enforcement, retention lifecycle, services, and hardware remain later-owned residue.

## Sprint 36.3: Additive schema generations ✅

**Status**: Done
**Implementation**: `src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs`, `test/spec/transaction/{TransactionVocabularySpec,TransactionVocabularyOracle}.hs`, the compile-negative program, and the package-hidden Phase-36 supervisor own this sprint surface.
**Blocked by**: Sprint 36.2
**Independent Validation**: one clean Haskell semantic suite, four compiler-negative rows, and three production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/transaction/TransactionVocabularyOracle.hs` independently fixes three row declarations, five transactions, five generation cases, four calculus projections, four compiler barriers, three mutant loci, and twenty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, six serialized oracle files, and three materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substates.md`, and the linked transaction/generated-artifact doctrines.

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

The complete integrated Phase-36 gate and its mechanical status projection remain. Live database connections, executor roles, policy enforcement, retention lifecycle, services, and hardware remain later-owned residue.

## Sprint 36.4: Compile barriers, semantic mutants, and calculus evidence ✅

**Status**: Done
**Implementation**: `src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs`, `test/spec/transaction/{TransactionVocabularySpec,TransactionVocabularyOracle}.hs`, the compile-negative program, and the package-hidden Phase-36 supervisor own this sprint surface.
**Blocked by**: Sprint 36.3
**Independent Validation**: one clean Haskell semantic suite, four compiler-negative rows, and three production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/transaction/TransactionVocabularyOracle.hs` independently fixes three row declarations, five transactions, five generation cases, four calculus projections, four compiler barriers, three mutant loci, and twenty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, six serialized oracle files, and three materialized mutant descriptors.
**Docs to update**: this phase, `system_components.md`, `substates.md`, and the linked transaction/generated-artifact doctrines.

### Objective

Seal the complete pure transaction boundary with falsifiable negative controls and the re-baselined calculus
projection.

### Deliverables

- Three Haskell-registered changed-subject mutant descriptors and exact red-locus assertions.
- A 20-entry validation-locus ledger over every bounded item.
- One real five-calculus composition and a generated-output/source-binding gate.

### Validation

1. Every Haskell compiler negative and changed-subject mutant fails at only its authored reason or locus.
2. All metrics and 39 authored surfaces join completely to runtime enumeration.

### Remaining Work

The complete integrated Phase-36 gate and its mechanical status projection remain. Live database connections, executor roles, policy enforcement, retention lifecycle, services, and hardware remain later-owned residue.

---

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

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
