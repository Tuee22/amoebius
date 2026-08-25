# Phase 10: The host claim ledger

> **Purpose**: Make amoebius a conforming participant in the operator-owned host claim ledger, so it cannot spend host capacity another program has already claimed.
> **Read this if**: a claim record, admission decision, or charge conversion is being changed, or this gate has to be read precisely.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_calculus_composition.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/host_resource_research.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 10.1: The claim record — encoding and total decoding ⏸️](#sprint-101-the-claim-record--encoding-and-total-decoding-)
- [Sprint 10.2: Admission — domain conflict, budget arithmetic, distinct refusals ⏸️](#sprint-102-admission--domain-conflict-budget-arithmetic-distinct-refusals-)
- [Sprint 10.3: Charge derivation from the resource index ⏸️](#sprint-103-charge-derivation-from-the-resource-index-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by Phase 9, its independent validation, and human promotion; every earlier promotion barrier must
also be satisfied in numerical order. No prior pass, seal, receipt, attestation, or completion claim exists
for this phase, and none may be manufactured by a status edit. No participation, conformance, or coordination
with any other program may be claimed from this document.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-50 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** Haskell is to own a total decoder and encoder for the 4096-byte claim
record, the admission arithmetic over frozen dimensions and opaque domains, and one total conversion from the
Phase-9 resource index to a declared charge. Free must be a positive value a writer deliberately produces, so
that a torn write, a truncated file, an unfamiliar revision, and a corrupted byte all decode as *occupied* and
no failure of the encoding can release capacity.

This phase is hardware-free and reads no hardware. It builds no root, probes no device, and observes no host:
the observed host and the budget are supplied inputs. Deriving either from real hardware is later work and is
named in [`host_resource_research.md` §9](../documents/engineering/host_resource_research.md#9-where-this-work-lands).

This phase is **not** a sixth calculus. It consumes the resource index; Phase 11 composes it only insofar as
the charge conversion is total.

**Phase scope:** one target claim — a conforming reader and writer of the ledger's frozen surface, with the
charge derived once from arithmetic amoebius already owns.
**Substrate:** none — no host, cluster, browser, device, or hardware; no ledger root is created or read.
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure/semantic-oracle, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).
**Depends on:** [Phase 9](phase_09_resource_index.md)
**Gate:** `pb validate phase 10`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — Haskell totally decodes every 4096-byte string into exactly one of free, held, or occupied-by-unknown-holder; admission refuses on prefix-conflicting domains and on any dimension whose reserve plus live charges plus request exceeds budget. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 10` is future public spelling only. Before current human approval of Phase 51, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. The specification requires a *separately written implementation* rather than a checker; that independence has not been established. |
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
| `Legacy closure` | UNRESOLVED — blocks validation: Phase-10-owned `LTD-HOST-003` remains active. Its typed Haskell binding, zero-finding check, reintroduction negative, and sprint-level owner assignment have not been accepted. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 9; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — no real root is opened, no lock is taken, no hardware is observed, and no coordination with another program is established by this phase. |
| `Human authority` | UNRESOLVED — blocks validation: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`hostclaim_spec.md` §4 — The claim record](../documents/engineering/hostclaim_spec.md#4-the-claim-record) — the fixed-size encoding and the totality of decoding.
- [`hostclaim_spec.md` §5 — Dimensions and domains](../documents/engineering/hostclaim_spec.md#5-dimensions-and-domains) — frozen dimensions, opaque domains, and the prefix rule.
- [`hostclaim_spec.md` §6 — Admission](../documents/engineering/hostclaim_spec.md#6-admission) — the single serializing section and the three distinct refusals.
- [`host_resource_research.md` §6 — Composing with a participant's own capacity arithmetic](../documents/engineering/host_resource_research.md#6-composing-with-a-participants-own-capacity-arithmetic) — the rule behind deriving the charge exactly once.

## Sprints

> **Reset validation review.** Every `Independent Validation` and `Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 10.1: The claim record — encoding and total decoding ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 9](phase_09_resource_index.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Make free a positive value, so nothing unreadable can release capacity.

### Deliverables

- A total decoder from any 4096 bytes to exactly one of free, held, or occupied-by-unknown-holder.
- An encoder whose output the decoder classifies as the value that produced it.
- A checksum over the payload remainder, and a fixed record size with no variable-length framing.
- An unknown-holder record that charges nothing while still naming the participant directory that owns it.

### Validation

Every byte string decodes to exactly one classification, and no corrupted, truncated, or unfamiliar record decodes as free.

### Remaining Work

Every `UNRESOLVED` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the gate.

## Sprint 10.2: Admission — domain conflict, budget arithmetic, distinct refusals ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 10.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Decide admission over supplied records without interpreting what any domain means.

### Deliverables

- A segment-boundary prefix test, so a whole device and one of its partitions conflict without either side knowing what a partition is.
- Budget arithmetic per dimension over reserve, live charges, and the request.
- `Busy`, `Insufficient`, and `Unsupported` kept distinct in whatever the participant reports.
- Growth expressed as a second independent claim rather than an edit to a live one.

### Validation

A participant that has never heard of a resource family still refuses its conflicting domains and still charges its consumption.

### Remaining Work

Every `UNRESOLVED` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the gate.

## Sprint 10.3: Charge derivation from the resource index ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 10.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Derive the declared charge once, from arithmetic amoebius already owns, and never author it a second time.

### Deliverables

- One total conversion from the Phase-9 resource index to a set of dimension charges.
- Memory physically shared with the host charged to host memory and never to a device dimension.
- A refusal rather than a silent under-charge when a source of growth is outside the inner system.
- A granted claim and a completed workload kept separate: neither is evidence of the other.

### Validation

A physical-capacity figure is never reinterpreted as an allocation, and every source of growth is either charged or explicitly refused.

### Remaining Work

Every `UNRESOLVED` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the gate.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- [`hostclaim_spec.md`](../documents/engineering/hostclaim_spec.md)
- [`host_resource_research.md`](../documents/engineering/host_resource_research.md)

**Cross-references to add:**

- UNRESOLVED — no cross-reference update set has been accepted for this reset contract.

## Related Documents

- [Development Plan](README.md)
- [`hostclaim_spec.md`](../documents/engineering/hostclaim_spec.md) — the frozen shared surface this phase implements.
- [`host_resource_research.md`](../documents/engineering/host_resource_research.md) — enforcement, coverage, and recovery, which this phase does not own.
- [`resource_capacity_doctrine.md`](../documents/engineering/resource_capacity_doctrine.md) — the arithmetic the charge is derived from.
