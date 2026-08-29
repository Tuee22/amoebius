# Phase 7: The evidence calculus

> **Purpose**: Specify the target Haskell capability to represent claims, Haskell evidence fixtures,
> fixture kinds, and mutation records so a claim without a falsifiable evidence binding is not
> expressible.
> **Read this if**: a claim has to be tied to something that could falsify it, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
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
- [Sprint 7.1: The evidence calculus ⏸️](#sprint-71-the-evidence-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 6, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to represent claims, Haskell evidence fixtures, fixture kinds, and mutation
records so a claim without a falsifiable evidence binding is not expressible.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to validate or
promote its claim.

**Phase scope:** Target capability only — represent claims, Haskell evidence fixtures, fixture
kinds, and mutation records so a claim without a falsifiable evidence binding is not expressible.
NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 6](phase_06_workflow_calculus.md)
**Gate:** `pb validate phase 07`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target capability only — represent claims, Haskell evidence fixtures, fixture kinds, and mutation records so a claim without a falsifiable evidence binding is not expressible. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 07` is future public spelling only. Before current reviewer approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 06; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Doctrine adopted

- [`evidence_calculus_doctrine.md` §2 — A claim is a value, and it names its fixture](../documents/engineering/evidence_calculus_doctrine.md#2-a-claim-is-a-value-and-it-names-its-fixture) — the rule behind the evidence calculus.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) — the register model a declared fixture runs at.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 7.1: The evidence calculus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 6](phase_06_workflow_calculus.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

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
claim about an export list, so it is a reviewed `.hs` compile-fail pair — omitting the argument leaves a
function waiting for a `Fixture`, and the separately authored Haskell oracle requires the rejection to name
it. That a fixture naming *nothing* is refused is a claim
about a value, so it is an in-process check, and it is where the seeded binding-erasure mutant lands: a `Text`
has no non-empty arm, so this is the one door the type could not close.

**The registry is Haskell, not serialized input.** The join consumes three reviewed values from the canonical
Haskell mutation registry through the carrier rule rather than re-listing them here. Offering the calculus a
second registry source is refused rather than merged. Any TSV rendering is a diagnostic beneath `.build/**`
and cannot influence the verdict.

### Remaining Work

The pre-reset `None` claim is permanently invalid; the phase remains blocked and NOT VALIDATED. The residue is the doctrine's own. This calculus does not make a claim true; it makes
a claim falsifiable and binds it to the thing that would falsify it, so a well-formed claim with a weak fixture
satisfies it completely. It does not choose the fixtures. And it does not close the self-referential gap —
which is stated here rather than left implicit, because this is the phase where that gap is nearest.

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md) — **done
  2026-08-20.** §6's "nothing here is built" is replaced by what is — the claim value, the fixture binding, the
  register declaration — and by the three residues that remain true of it regardless.

**Cross-references to add:**

- UNRESOLVED — no cross-reference update set has been accepted for this reset contract.

## Related Documents

- [Development Plan](README.md)
- [`evidence_calculus_doctrine.md`](../documents/engineering/evidence_calculus_doctrine.md) — the rule behind the evidence calculus.
- [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) — the register model a declared fixture runs at.
