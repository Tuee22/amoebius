# Phase 36: The closed transaction vocabulary

> **Purpose**: Make the relational data plane a closed, request-scoped transaction GADT whose row
> declarations generate schema, policies, statements, and additive generation transitions.
> **Read this if**: a relational transaction, row type, row policy, or schema generation has to change, or the
> absence of a raw query surface has to be checked.

This phase owns the pure relational vocabulary and its generated SQL projection. It does not connect to
Postgres, install the emitted schema, choose an application role, or claim live row-level-security behavior.
Those effects belong to later live storage and platform phases. The six transaction laws are owned by
[`extension_conformance_transactions.md`](../documents/engineering/extension_conformance_transactions.md);
this contract supplies their first bounded Haskell instance.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/generated_artifacts_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 36.1: Row declarations drive schema and policy ✅](#sprint-361-row-declarations-drive-schema-and-policy-)
- [Sprint 36.2: The closed request-scoped transaction GADT ✅](#sprint-362-the-closed-request-scoped-transaction-gadt-)
- [Sprint 36.3: Additive schema generations ✅](#sprint-363-additive-schema-generations-)
- [Sprint 36.4: Compile barriers, semantic mutants, and calculus evidence ✅](#sprint-364-compile-barriers-semantic-mutants-and-calculus-evidence-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21 by the new closed-transaction Register-1 gate.

**Validation record.** The thirteen-sided gate passed on natural `darwin/arm64`, untranslated. All four
compiler barriers failed at their exact reasons; all three semantic mutants reddened at their exact loci; all
26 metrics matched; and 39 surfaces joined to 56 enumerated items. Generated SQL remained beneath
`.build/**`. Attestation `sha256:b495878926a33fddd6683321a73fe2e7234c3b5d80c49700c7e027730ecfa58d`
binds source `sha256:fb0977c3af96a99e…` over 2,259 files. Live catalog installation, row-policy
enforcement, and executor-role fidelity remain UNVERIFIED.

**Activated 2026-08-21** when Phase 35 sealed. The generative re-baseline invalidated the older skeletal
contract: it had no gate script, no concrete implementation path, and no five-calculus projection.

---

## Phase Summary

Three private row declarations name documents, jobs, and releases. Each declaration fixes its table, required
columns, composite primary key, tenant foreign key, and scope column. The schema renderer and row-policy
renderer consume those same values. The emitted SQL is therefore generated output beneath `.build/sql/**`,
while independently authored semantic rows state the exact DDL and policy meaning.

Five private GADT constructors form the whole transaction vocabulary: insert/read document, list jobs,
advance job status, and record release. Their five exported smart constructors all require a generative
`RequestScope scope`, and their result types retain that same phantom index through `Scoped scope`. No raw
statement value, predicate combinator, declaration constructor, or transaction constructor is exported.

Schema evolution is a closed transition between three generations. The two admitted edges retain every old
row coordinate and add one table; current, regressing, and skipped edges refuse with distinct errors. Neither
the transition union nor the generated SQL can express `DROP`, `TRUNCATE`, or `DELETE`.

**Phase scope:** one cohesive claim — every relational operation is a declared, request-scoped constructor,
and schema, policy, statement, result index, and additive generation follow from closed terms. A live database,
connection role, policy enforcement probe, or destructive-retention lifecycle splits out.

**Substrate:** `none` — declarations, transactions, transitions, SQL projections, and compiler barriers are
values; no database is contacted ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `none` ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure/generative: semantic oracles and compiler refusals constrain the closed vocabulary;
generated SQL remains an output rather than authority ([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 8](phase_08_scope_index.md) — the generative request-scope index every transaction and
result preserves; [Phase 10](phase_10_calculus_composition.md) — the five-calculus composition projected by
the gate. Phase 35 supplies no value consumed here.

**Gate:** `python3 tools/run_phase_gate.py 36` passes the semantic, compiler-barrier,
five-calculus, mutant, generated-output, ledger, containment, and attestation checks in [Gate integrity](#gate-integrity).

---

## Gate integrity

The gate is `python3 tools/transaction_vocabulary_gate.py`. Its representative set is small enough to be
exhaustive over every constructor this phase introduces.

**The row/schema/policy oracle is independent.**
`test/oracle/transaction_vocabulary/rows.tsv` names all three tables, all ten required columns, each composite
primary key, each scope foreign key, and the exact policy column and parameter. The suite joins those rows to
the real private declarations in both directions. Source checks additionally prove that the schema, policy,
and statement projections call the same scope-predicate fold and that the declaration terms are not exported.

**The transaction oracle covers the entire closed GADT.**
`transactions.tsv` names all five smart-constructor projections in order: operation, table, required tenant
scope predicate, and scope-indexed result shape. The positive compile twin constructs two transactions at one
request scope. Four separately compiled negatives omit the scope, ask for a raw statement, ask for a predicate
constructor, and try to combine two rank-n request scopes; each must fail for its pinned GHC reason.

**The generation oracle separates additions from refusals.**
`generations.tsv` admits `1→2` and `2→3`, retaining all earlier rows and adding one table. It rejects `2→1`,
`1→3`, and `3→3` as regression, skipped, and current respectively. The generated SQL is rendered twice,
contains all three policies and five transaction statements, and contains zero destructive verbs. It remains
beneath `.build/**`; no SQL-output golden is admitted.

**Three paired mutants divide the semantic boundary.** An optional scope reddens `required-scope`; an
always-true replacement reddens `exact-scope-predicate`; and a policy derived from `subject_id` reddens
`shared-declaration`. Each original must first match its authored oracle, each mutation must fail, and each
process must exit red at only its named locus. The 20-row locus ledger joins all rows, transactions, generation
cases, compile barriers, and mutants.

**The five calculi reach actual values.** The artifact, budget, lift, workflow, and evidence components carry
the `3,5,4,5,3` row/transaction/compiler/generation/mutant counts and compose to resource vector `5,20,0,0`.
The test compares those real values with the independently authored calculus projection.

- **Extension conformance (§M.13).** L1–L5 and C1–C7 are not applicable to this standalone vocabulary, which
  declares no extension or composition peer. This phase instead builds the P1–P6 transaction contract. Its
  closed constructors, compiler negatives, shared-declaration check, indexed results, and additive-transition
  oracle are the conformance surface; the compiler fixtures live under
  `test/negative/compile_fail/transaction_vocabulary/`. Live P3/P4 enforcement remains UNVERIFIED.

## Doctrine adopted

- [`extension_conformance_transactions.md` §3 — why there is no ORM](../documents/engineering/extension_conformance_transactions.md#3-why-there-is-no-orm):
  the exported API is a closed domain vocabulary rather than a statement language.
- [`extension_conformance_transactions.md` §4 — P1–P6](../documents/engineering/extension_conformance_transactions.md#4-p1p6):
  request scope is required, row declarations drive schema/policy/statements, results retain the scope index,
  and generations have only additive transitions.
- [`generated_artifacts_doctrine.md` §2 — what is generated (and from what)](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what):
  emitted schema, policy, and statement SQL remain generated output constrained by semantic oracles.

---

## Sprints

## Sprint 36.1: Row declarations drive schema and policy ✅

**Status**: Done
**Implementation**: `src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs`, `test/oracle/transaction_vocabulary/rows.tsv`
**Blocked by**: none within the phase
**Independent Validation**: three declaration projections join exactly to ten required columns, three keys, three foreign keys, and three policies
**Docs to update**: `documents/engineering/extension_conformance_transactions.md`, `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Adopt P3 and P4; derive schema and policy from one private row declaration rather than two authored texts.

### Deliverables

- Three closed row declarations with no nullable scope-bearing column.
- One shared scope-predicate term consumed by policy and statement rendering.
- Deterministic SQL projection to `.build/sql/**`, with no tracked output copy.

### Validation

1. All row semantics join to the independent oracle in both directions.
2. The export and source scans prove the declaration and predicate terms remain private and shared.

### Remaining Work

None.

## Sprint 36.2: The closed request-scoped transaction GADT ✅

**Status**: Done
**Implementation**: `src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs`, `test/oracle/transaction_vocabulary/transactions.tsv`, `test/negative/compile_fail/transaction_vocabulary/TransactionCompile.hs`
**Blocked by**: Sprint 36.1
**Independent Validation**: five exact projections pass while unscoped, raw-query, predicate, and cross-scope programs fail to compile
**Docs to update**: `documents/engineering/extension_conformance_transactions.md`

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

None.

## Sprint 36.3: Additive schema generations ✅

**Status**: Done
**Implementation**: `src/transaction-vocabulary/Amoebius/Transaction/Vocabulary.hs`, `test/oracle/transaction_vocabulary/generations.tsv`
**Blocked by**: Sprint 36.2
**Independent Validation**: two adjacent additions admit and current, regression, and skipped edges retain distinct refusals
**Docs to update**: `documents/engineering/extension_conformance_transactions.md`

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

None.

## Sprint 36.4: Compile barriers, semantic mutants, and calculus evidence ✅

**Status**: Done
**Implementation**: `test/spec/transaction/TransactionVocabularySpec.hs`, `test/mutant/transaction_vocabulary/**`, `test/oracle/transaction_vocabulary/{calculus_projection,validation_locus}.tsv`, `tools/transaction_vocabulary_gate.py`
**Blocked by**: Sprint 36.3
**Independent Validation**: four compiler negatives and three semantic mutants fail separately; all five calculi compose to the authored vector
**Docs to update**: `documents/engineering/extension_conformance_transactions.md`, `documents/engineering/generated_artifacts_doctrine.md`

### Objective

Seal the complete pure transaction boundary with falsifiable negative controls and the re-baselined calculus
projection.

### Deliverables

- Three registered mutant descriptors and exact red-locus assertions.
- A 20-entry validation-locus ledger over every bounded item.
- One real five-calculus composition and a generated-output/attestation gate.

### Validation

1. Every compiler negative and mutant fails at only its authored reason or locus.
2. All metrics and 39 authored surfaces join completely to runtime enumeration.

### Remaining Work

None.

---

## Documentation Requirements

**Engineering docs to update when the gate seals:**
- `documents/engineering/extension_conformance_transactions.md` — the scope section records the tested bounded
  P1–P6 instance while retaining live database enforcement as UNVERIFIED.
- `documents/engineering/generated_artifacts_doctrine.md` — the relational-schema row records the concrete
  declaration module and semantic oracle.

**Cross-references to update:**
- `DEVELOPMENT_PLAN/system_components.md` — add the pure transaction-vocabulary component and keep live
  Postgres ownership with later phases.

---

## Related Documents
- [The Transaction Laws](../documents/engineering/extension_conformance_transactions.md)
- [Generated Artifacts](../documents/engineering/generated_artifacts_doctrine.md)
- [Phase 8](phase_08_scope_index.md)
- [Phase 10](phase_10_calculus_composition.md)
- [Development Plan](README.md)
