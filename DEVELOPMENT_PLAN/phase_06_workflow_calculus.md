# Phase 6: The workflow calculus

> **Purpose**: Specify the target Haskell capability to represent provision, build, deploy, observe,
> and teardown as one Haskell workflow algebra in which teardown remains a type-level obligation.
> **Read this if**: something has to happen to a running system, or teardown has to be reasoned about, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 6.1: The workflow calculus](#sprint-61-the-workflow-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

The complete Phase-5 gate is recorded for the same source identity before this phase may run. The phase remains
Active until its complete integrated gate authorizes the mechanical status projection.

## Phase Summary

This phase implements provision, build, deploy, observe, and teardown as one Haskell workflow algebra in
which teardown remains a type-level obligation. A package-hidden supervisor builds an independent eight-row
Haskell relation, seven changed-production subjects, and three compile-negative pairs directly and serially.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` is not used by this pre-`BOOTSTRAP_HANDOFF` gate. The source-bound Haskell dispatcher invokes the
authenticated compiler directly and synchronously.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — represent provision, build, deploy, observe, and teardown
as one Haskell workflow algebra in which teardown remains a type-level obligation. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 5](phase_05_lift_calculus.md)
**Gate:** `pb validate phase 06`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-6 semantic payload, package-hidden serial
supervisor, independent Haskell relation, three paired compile negatives, and changed-production matrix are
complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The five-arm workflow algebra tracks every provisioned resource as a type-level obligation until teardown or an explicitly conditioned transfer, while preserving typed sequential and disjoint parallel composition. |
| `Subject` | `Amoebius.Calculus.Workflow.{Arm,Ledger,Obligation,Run}` is acquired only through package-hidden `Amoebius.Validation.WorkflowCalculusRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 06`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly, synchronously, and without `-j`. |
| `Oracle` | `test/spec/calculus/WorkflowCalculusSpec.hs` contains a separately authored eight-row Haskell obligation relation and observes only public production interfaces. |
| `Positive controls` | All ten clean predicates pass and the terminal, conditioned-transfer, and held-removal legal compile twins succeed. |
| `Paired negatives` | Ending with an obligation, transferring without a condition, and removing an unheld named resource each fail at their exact type-level reason and locus. |
| `Mutants` | Dropped and double discharge, lost transfer condition, reversed parallel branches, relaxed terminal obligations, optional transfer conditions, and unconstrained removal are each killed at their assigned observation. |
| `Discovery` | The four workflow modules, Haskell oracle, and six compile twins are discovered from the Git snapshot and equal the fixed eleven-file inventory bidirectionally. |
| `Challenge` | All seven changed-production subjects execute after acquisition and must be distinguished at their assigned locus. |
| `Observer` | The supervisor records absolute executable, exact argv, exit, transcript digest, and bounded failure text for every compiler and oracle process. |
| `Authority/bypass` | `pb`, network, hardware, live services, compiler substitution, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-06/work/**` root and the dispatcher requires equal opening/closing source identities. |
| `Qualification` | Clean controls, exact negatives, obligation diagnostics, and all seven mutants pass together; any survivor or wrong-locus failure refuses. |
| `Cleanroom` | Every binary, interface, object, stub, and transcript is generated lazily beneath the fresh run root. |
| `Legacy closure` | Phase 6 owns no legacy-debt identifier; all non-circular prerequisites must pass while later-owned source debt remains residue. |
| `Predecessor` | Consume exactly one durable Phase-5 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Evidence binding, five-calculus composition, actual effects, runtimes, hardware, and live services remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-six-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

**This phase owns its compile-negative evidence.** Each illegal twin below requires a phase-local, source-bound
GHC invocation, a minimally different positive control, and a separately authored exact-diagnostic oracle.
[Phase 15](phase_15_compile_fail_harness.md) later consolidates reusable compile-fail machinery; it is not a
prerequisite of this earlier gate. The local runner owns these pairs until Phase 15 consolidates their reusable machinery.

## Doctrine adopted

- [`workflow_calculus_doctrine.md` §2 — Five arms, one algebra](../documents/engineering/workflow_calculus_doctrine.md#2-five-arms-one-algebra) — the rule behind the workflow calculus.

## Sprints

The sprint seam is bound to the same Haskell-only subject, oracle, and serial supervisor as the gate.

## Sprint 6.1: The workflow calculus ✅

**Status**: Done
**Implementation**: `src/Amoebius/Calculus/Workflow/{Arm,Ledger,Obligation,Run}.hs`; package-hidden supervisor `src/validation-kernel/Amoebius/Validation/WorkflowCalculusRun/Internal.hs`
**Blocked by**: [Phase 5](phase_05_lift_calculus.md) gate pass
**Independent Validation**: ten clean predicates over eight obligations and five workflows; three exact compile-negative pairs; seven assigned changed-production subjects; later effects remain residue
**Oracle**: `test/spec/calculus/WorkflowCalculusSpec.hs`, separately authored in Haskell against public workflow modules
**Legacy IDs**: none; later-owned tracked-source debt remains in the typed central registry
**Docs to update**: this phase file, `DEVELOPMENT_PLAN/README.md`, and `documents/engineering/workflow_calculus_doctrine.md`

### Objective

Make teardown an obligation the type system tracks rather than a step somebody remembers.

### Deliverables

- Five arms — provision, build, deploy, observe, teardown — over one vocabulary.
- Provision returning a handle and a teardown obligation together.
- Discharge by teardown or by explicit transfer to a longer-lived declaration, with no way to drop it.
- Sequential and parallel composition typed by the witnesses each arm consumes.

### Validation

A workflow ending while holding an undischarged obligation must fail to compile; a transferred obligation must name its condition.

**Both are compile-fail pairs, and a third joined them.** Discharging an obligation is discharging a *named*
one, so tearing down something the workflow never provisioned is as much a defect as ending while still owing.
Left to the ordinary machinery that would have been a stuck type family — a diagnostic a reader has to decode
— so `Remove`'s empty case is a `TypeError` that names the resource, and the fixture asserts that message
rather than merely asserting that something failed. Each of the three pairs differs from its twin in exactly
one dimension: whether the obligation is discharged, whether the transfer states a condition, and which
resource is named.

**Each pair carries a weaken-the-constraint mutant.** A foreclosure claim is behavioural logic, so a
compile-fail twin that nothing can move is an assertion rather than a test: it stays red under any defect,
including one that has nothing to do with the constraint. Each of the three constraints therefore carries a
changed-subject mutant that loosens exactly it — the obligation index dropped from the terminal arm, the
transfer's condition made optional, and `Remove`'s `TypeError` case replaced by an unconstrained match. Under
its own mutant the corresponding illegal twin must compile, and under no other. The legal twins and the two
composition positives stay green throughout, and a twin that fails for a parse error, an unbound name, or a
missing import satisfies nothing
([§M.8](development_plan_gate_integrity.md#m8-paired-negatives-assert-an-exact-reason-at-an-exact-locus)).

**The composition deliverable carries its own selector.** Sequential and parallel composition are typed by the
witnesses each arm consumes, which neither of the three obligation pairs reaches; its mutant relaxes the
witness match so a parallel composition accepts an arm whose witness the previous arm never produced.

### Remaining Work

Parallel composition is admitted over disjoint resources and the disjointness is a
constraint rather than a convention, but nothing here executes: what parallel composition asserts is that the
two orders are equally admissible, not that anything ran at once. Binding a claim to the fixture that
discharges it is the evidence calculus's, which is the next phase's and is recorded `UNVERIFIED` here; and a
provider that fails to delete what amoebius asked it to delete remains the `live-effect` residue
[`workflow_calculus_doctrine.md` §3](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation)
names, which no type discipline reaches.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) — **done
  2026-08-20.** §3's "the compile-fail fixture establishing that is owed by the phase that builds the workflow
  calculus; none exists" is replaced by the three that do, and by what they establish: the obligation is a type
  index, and dropping one is unspellable rather than refused.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` and the adjacent Phase 5/7 backlinks remain the phase-order routing authority.

## Related Documents

- [Development Plan](README.md)
- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) — the rule behind the workflow calculus.
