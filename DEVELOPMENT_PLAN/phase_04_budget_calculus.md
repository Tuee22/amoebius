# Phase 4: The budget calculus

> **Purpose**: Specify the target Haskell capability to represent storage authority, concurrency,
> admission, and reaping as one typed Haskell budget calculus in which no allocation lacks a prior
> bound.
> **Read this if**: a byte has to be accounted for before it is written, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, documents/engineering/jit_budget_doctrine.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 4.1: The budget calculus](#sprint-41-the-budget-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

The complete Phase-3 gate is recorded for the same source identity before this phase may run. The phase remains
Active until its complete integrated gate authorizes the mechanical status projection.

## Phase Summary

This phase implements storage authority, concurrency, admission, and reaping as one typed Haskell budget
calculus in which no allocation lacks a prior bound. A package-hidden supervisor builds the independent Haskell
oracle and five changed-production subjects and compiles both constructor/reaper pairs serially.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` is not used by this pre-`BOOTSTRAP_HANDOFF` gate. The source-bound Haskell dispatcher invokes the
authenticated compiler directly and synchronously.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — represent storage authority, concurrency, admission, and
reaping as one typed Haskell budget calculus in which no allocation lacks a prior bound.
NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 3](phase_03_artifact_calculus.md)
**Gate:** `pb validate phase 04`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-4 semantic payload, package-hidden serial
supervisor, independent Haskell relation, paired compile negatives, and changed-production matrix are complete;
only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | The finite issuer, paired ceiling/concurrency allowance, pre-write admission, staging store, and reaper-bearing retention grant satisfy one source-bound budget calculus contract. |
| `Subject` | `Amoebius.Calculus.Budget.{Grant,Admission,Store,Retention}` is acquired only through package-hidden `Amoebius.Validation.BudgetCalculusRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 04`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly, synchronously, and without `-j`. |
| `Oracle` | `test/spec/calculus/BudgetCalculusSpec.hs` contains the separately authored 24-row admission relation and observes only public production interfaces. |
| `Positive controls` | All ten clean predicates pass, clean refusal leaves both store images identical, and both legal compile twins succeed. |
| `Paired negatives` | A forged grant is refused because hidden constructors are not in scope; reaper omission is refused by the exact `Reaper` function/result mismatch. |
| `Mutants` | Partial-write, unbounded-default, dropped-concurrency, exposed-constructor, and omitted-reaper selectors each change production and are killed by their assigned exact observation. |
| `Discovery` | The four budget modules, Haskell oracle, and four compile twins are discovered from the Git snapshot and equal the fixed inventory bidirectionally. |
| `Challenge` | All five changed-production subjects execute after acquisition and must be distinguished at their assigned locus. |
| `Observer` | The supervisor records absolute executable, exact argv, exit, transcript digest, and bounded failure text for every compiler and oracle process. |
| `Authority/bypass` | `pb`, network, hardware, live services, compiler substitution, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-04/work/**` root and the dispatcher requires equal opening/closing source identities. |
| `Qualification` | Clean controls, exact negatives, and all five mutants pass together; any survivor or wrong-locus failure refuses. |
| `Cleanroom` | Every binary, interface, object, stub, and transcript is generated lazily beneath the fresh run root. |
| `Legacy closure` | Phase 4 owns no legacy-debt identifier; all non-circular prerequisites must pass while later-owned source debt remains residue. |
| `Predecessor` | Consume exactly one durable Phase-3 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Calculus composition, actual free-space observation, effects, runtimes, hardware, and live services remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-four-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

## Doctrine adopted

- [`jit_budget_doctrine.md` §2 — The grant is the authority to exist](../documents/engineering/jit_budget_doctrine.md#2-the-grant-is-the-authority-to-exist) — the rule behind the budget calculus.

## Sprints

The sprint seam is bound to the same Haskell-only subject, oracle, and serial supervisor as the gate.

## Sprint 4.1: The budget calculus ✅

**Status**: Done
**Implementation**: `src/Amoebius/Calculus/Budget/{Grant,Admission,Store,Retention}.hs`; package-hidden supervisor `src/validation-kernel/Amoebius/Validation/BudgetCalculusRun/Internal.hs`
**Blocked by**: [Phase 3](phase_03_artifact_calculus.md) gate pass
**Independent Validation**: ten clean predicates and identical refusal store images; exact constructor/reaper compile negatives; five assigned changed-production mutants; composition and live free-space remain residue
**Oracle**: `test/spec/calculus/BudgetCalculusSpec.hs`, separately authored against public calculus modules with its 24-row expectation relation in Haskell
**Legacy IDs**: none; later-owned tracked-source debt remains in the typed central registry
**Docs to update**: this phase file, `DEVELOPMENT_PLAN/README.md`, and `documents/engineering/jit_budget_doctrine.md`

### Objective

Make a byte unable to exist without a grant that carries both its ceiling and the concurrency it is shared across.

### Deliverables

- A `Grant` value issued from a finite pool, specific to a location and purpose, with no unbounded constructor.
- A ceiling and a concurrency bound that share one constructor, so neither can be stated alone.
- `admit` and `admitFirst` returning a reservation or a refusal, writing nothing on the refusal path.
- A retention grant that has no constructor without a reaper.

### Validation

Driving a grant to its ceiling must refuse at admission with the store byte-identical to its prior state, never mid-write.

**Both halves of that sentence are checked, and only the second one can fail.** `admit` has no store in its
type, so the ceiling refusal cannot touch one; the run reports the image on either side of it because a
contract that states the claim should be able to point at the observation, not because the observation could
come out otherwise. The mid-write refusal is the one with a store in reach: a demand admitted against a
declared worst case its rendering then exceeds is refused by `materializeUnder`, which returns the store on
both paths so that a seeded defect can move it. The seeded `admit-after-partial-write` mutant does exactly
that, and leaves every in-process check green — which is why the store image is read from a second invocation
of the suite rather than asserted inside it.

The refusal's *reason* is checked as well as its verdict. The authored capacity table names one of five
admission reasons per refused row, and the order the reasons are tested in is part of the expectation: three
rows are wrong in two ways at once and each names the earlier reason, so a refusal stays attributable to one
arm rather than to whichever check happened to run first
([§M.8](development_plan_gate_integrity.md#m8-paired-negatives-assert-an-exact-reason-at-an-exact-locus)).

**Each remaining deliverable carries its own selector.** `admit-after-partial-write` settles one deliverable;
the other three are unobserved without their own, which
[§M.3](development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject) forbids. The
pool-specificity claim carries a mutant admitting a grant at a foreign location or purpose. The shared
ceiling/concurrency constructor carries a weaken-the-constraint mutant that splits it into two independently
statable fields, under which the illegal twin — a ceiling stated without its bound — must compile and only
then. The reaper-less retention grant carries the same shape of weaken-the-constraint mutant. A twin that
fails for a parse error, an unbound name, or a missing import satisfies none of them.

### Remaining Work

The implementation and phase-local evidence contract are complete. The phase remains Active until the exact
Phase-3 receipt is refreshed for the final source and the integrated Phase-4 gate passes. Whether a
composition's grant is the sum of its parts is C5's later claim; nothing here observes a running system, so
the substrate's actual free space remains the live-effect observation
[`jit_budget_doctrine.md` §7](../documents/engineering/jit_budget_doctrine.md#7-the-residue) says it is.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) — **historical pre-reset note from 2026-08-20 — cannot support a gate pass.** §7's
  "nothing here is built" is replaced by what is: the grant, admission, the staging rule, and the reaper, as
  pure values in Register 1. What stays unbuilt is named rather than dropped — §6's additivity is stated over
  the lift calculus above this one, and §7's free-space observation is not a decision result at all.

**Cross-references to add:**

- None beyond the doctrine update above. Generator/output ownership is a checked Haskell declaration; any
  registry projection or generated grant artifact is lazy output beneath `.build/**`, never a tracked table
  or Python gate.

## Related Documents

- [Development Plan](README.md)
- [`jit_budget_doctrine.md`](../documents/engineering/jit_budget_doctrine.md) — the rule behind the budget calculus.
