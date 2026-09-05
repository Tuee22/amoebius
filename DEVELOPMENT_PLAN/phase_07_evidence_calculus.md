# Phase 7: The evidence calculus

> **Purpose**: Specify the target Haskell capability to represent claims, Haskell evidence fixtures,
> fixture kinds, and mutation records so a claim without a falsifiable evidence binding is not
> expressible.
> **Read this if**: a claim has to be tied to something that could falsify it, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_15_compile_fail_harness.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 7.1: The evidence calculus](#sprint-71-the-evidence-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

The complete Phase-6 gate is recorded for the same source identity before this phase may run. The phase remains
Active until its complete integrated gate authorizes the mechanical status projection.

## Phase Summary

This phase implements claims, Haskell evidence fixtures, fixture kinds, mutation records, and the register
model so a claim without a falsifiable evidence binding is not expressible. A package-hidden supervisor builds
an independent seven-claim Haskell inventory, eight changed-production subjects, and two compile-negative
pairs directly and serially.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` is not used by this pre-`BOOTSTRAP_HANDOFF` gate. The source-bound Haskell dispatcher invokes the
authenticated compiler directly and synchronously.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — represent claims, Haskell evidence fixtures, fixture
kinds, and mutation records so a claim without a falsifiable evidence binding is not expressible.
NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 6](phase_06_workflow_calculus.md)
**Gate:** `pb validate phase 07`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-7 semantic payload, package-hidden serial
supervisor, independent Haskell inventory, paired compile negatives, and changed-production matrix are
complete; only a fresh integrated run may authorize status.

| Key | Contract |
|---|---|
| `Claim` | Claims carry one named fixture and bounded strength; mutation records carry one reachable carrier and red locus; gates declare only a register their fixtures reached. |
| `Subject` | `Amoebius.Calculus.Evidence.{Claim,Fixture,Mutant,Register}` is acquired only through package-hidden `Amoebius.Validation.EvidenceCalculusRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 07`; before `BOOTSTRAP_HANDOFF`, the exact absolute Haskell executable and authenticated GHC 9.12.4 compiler run directly, synchronously, and without `-j`. |
| `Oracle` | `test/spec/calculus/EvidenceCalculusSpec.hs` contains a separately authored seven-claim and three-mutation Haskell inventory and observes only public production interfaces. |
| `Positive controls` | All twelve clean predicates pass and both fixture-bound-claim and declared-register legal compile twins succeed. |
| `Paired negatives` | A claim without a fixture and a gate without a register fail at the exact `Fixture` and `GateRegister` type loci. |
| `Mutants` | Empty fixture admission, wrong red locus, second registry, weakened oracle strength, simulation as gate register, ignored reached register, optional claim fixture, and optional gate register are killed at assigned observations. |
| `Discovery` | The four evidence modules, Haskell oracle, and four compile twins are discovered from the Git snapshot and equal the fixed nine-file inventory bidirectionally. |
| `Challenge` | All eight changed-production subjects execute after acquisition and must be distinguished at their assigned locus. |
| `Observer` | The supervisor records absolute executable, exact argv, exit, transcript digest, and bounded failure text for every compiler and oracle process. |
| `Authority/bypass` | `pb`, network, hardware, live services, compiler substitution, and compiler/linker overlap are forbidden. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-07/work/**` root and the dispatcher requires equal opening/closing source identities. |
| `Qualification` | Clean controls, exact negatives, strength/register checks, and all eight mutants pass together; any survivor or wrong-locus failure refuses. |
| `Cleanroom` | Every binary, interface, object, stub, and transcript is generated lazily beneath the fresh run root. |
| `Legacy closure` | Phase 7 owns no legacy-debt identifier; all non-circular prerequisites must pass while later-owned source debt remains residue. |
| `Predecessor` | Consume exactly one durable Phase-6 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Oracle correctness, finite-sampling limits, five-calculus composition, actual effects, runtimes, hardware, and live services remain explicitly later-owned. |
| `Pass criterion` | `qualified-phase-seven-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

**This phase owns its compile-negative evidence.** Each illegal twin below requires a phase-local, source-bound
GHC invocation, a minimally different positive control, and a separately authored exact-diagnostic oracle.
[Phase 15](phase_15_compile_fail_harness.md) later consolidates reusable compile-fail machinery; it is not a
prerequisite of this earlier gate. The local runner owns these pairs until Phase 15 consolidates their reusable machinery.

## Doctrine adopted

- [`evidence_calculus_doctrine.md` §2 — A claim is a value, and it names its fixture](../documents/engineering/evidence_calculus_doctrine.md#2-a-claim-is-a-value-and-it-names-its-fixture) — the rule behind the evidence calculus.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) — the register model a declared fixture runs at.

## Sprints

The sprint seam is bound to the same Haskell-only subject, oracle, and serial supervisor as the gate.

## Sprint 7.1: The evidence calculus ✅

**Status**: Done
**Implementation**: `src/Amoebius/Calculus/Evidence/{Claim,Fixture,Mutant,Register}.hs`; package-hidden supervisor `src/validation-kernel/Amoebius/Validation/EvidenceCalculusRun/Internal.hs`
**Blocked by**: [Phase 6](phase_06_workflow_calculus.md) gate pass
**Independent Validation**: twelve clean predicates over seven claims and three mutation records; two exact compile-negative pairs; eight assigned changed-production subjects; later effects remain residue
**Oracle**: `test/spec/calculus/EvidenceCalculusSpec.hs`, separately authored in Haskell against public evidence modules
**Legacy IDs**: none; later-owned tracked-source debt remains in the typed central registry
**Docs to update**: this phase file, `DEVELOPMENT_PLAN/README.md`, and `documents/engineering/evidence_calculus_doctrine.md`

### Objective

Bind every claim a phase makes to the fixture that discharges it, so an unchecked claim is not expressible.

### Deliverables

- A claim type carrying its discharge, so a claim with no fixture has no constructor.
- A mutant record naming its operator, its change, and the locus the gate must redden.
- One registry for the mutant corpus, with a carrier field rather than a second registry.
- The register model as a value, so a gate declares which register its evidence reaches.

### Validation

A claim without a fixture reference must fail to construct, and every registered mutant must redden its named locus.

**"Fail to construct" is two claims and both are checked.** That the constructor takes a fixture at all is a
claim about an export list, so it is a checked `.hs` compile-fail pair — omitting the argument leaves a
function waiting for a `Fixture`, and the separately authored Haskell oracle requires the rejection to name
it. That a fixture naming *nothing* is refused is a claim
about a value, so it is an in-process check, and it is where the seeded binding-erasure mutant lands: a `Text`
has no non-empty arm, so this is the one door the type could not close.

**The registry is Haskell, not serialized input.** The join consumes three checked values from the canonical
Haskell mutation registry through the carrier rule rather than re-listing them here. Offering the calculus a
second registry source is refused rather than merged. Any TSV rendering is a diagnostic beneath `.build/**`
and cannot influence the verdict.

### Remaining Work

The residue is the doctrine's own. This calculus does not make a claim true; it makes
a claim falsifiable and binds it to the thing that would falsify it, so a well-formed claim with a weak fixture
satisfies it completely. It does not choose the fixtures. And it does not close the self-referential gap —
which is stated here rather than left implicit, because this is the phase where that gap is nearest.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md) — **done
  2026-08-20.** §6's "nothing here is built" is replaced by what is — the claim value, the fixture binding, the
  register declaration — and by the three residues that remain true of it regardless.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` and the adjacent Phase 6/8 backlinks remain the phase-order routing authority.

## Related Documents

- [Development Plan](README.md)
- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md) — the rule behind the evidence calculus.
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the register model a declared fixture runs at.
