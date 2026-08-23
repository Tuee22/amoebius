# Phase 23: The security laws S1-S6

> **Purpose**: Specify the target Haskell capability to evaluate S1–S6 over a bounded pure Haskell
> security kernel with typed identity and request-scope boundaries using independently authored
> `.hs` evidence.
> **Read this if**: the attested identity, scoped operation, derived namespace, revocation-policy value, or its
> finite evidence boundary must change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 23.1: The security laws S1-S6 ⏸️](#sprint-231-the-security-laws-s1-s6-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 22, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to evaluate S1–S6 over a bounded pure Haskell security kernel with typed
identity and request-scope boundaries using independently authored `.hs` evidence.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to validate or
promote its claim.

**Phase scope:** Target capability only — evaluate S1–S6 over a bounded pure Haskell security kernel
with typed identity and request-scope boundaries using independently authored `.hs` evidence.
NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 22](phase_22_extension_laws_compositional.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 23`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target capability only — evaluate S1–S6 over a bounded pure Haskell security kernel with typed identity and request-scope boundaries using independently authored `.hs` evidence. NOT VALIDATED. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 23` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 22 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6) — the rule behind the security laws S1-S6.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 23.1: The security laws S1-S6 ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Evaluate S1–S6 over the bounded pure kernel while retaining the persistence, timing, cryptographic-runtime,
and compositional residues honestly.

### Deliverables

- Opaque claimed/attested identity index and fixture verification introduction.
- Phase-8 rank-2 scope elimination at every operation and derived-key boundary.
- Mandatory scoped resolution with one public refusal for foreign and absent resources.
- One length-framed renderer for row, object, topic, cache, and replay keyspaces.
- Revocation-edge-or-positive-bound authority-layer value and S1–S6 evaluator.
- Authored finite corpus, four compiler barriers, and six exact executable mutants.

### Validation

1. Match all fifteen operation cases and all 42 authored law verdicts.
2. Require all five foreign/absent pairs to return identical bytes with no mutation and equal modeled steps.
3. Independently recompute all five namespace pairs and the one fixture signature.
4. Require claimed use, promotion, missing scope, and cross-request key programs to fail at their pinned type
   reasons while the legal twin runs.
5. Require every registered mutant to redden exactly its declared S-law.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. Production cryptography, wall-clock timing, persisted-value re-entry, compositional S closure, runtime
integration, and a generated conformance verdict remain later work rather than Phase-23 completion criteria.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — record
  the bounded S1–S6 evaluator without upgrading production cryptography, wall-clock timing, persisted-value
  re-entry, compositional closure, or runtime fidelity.

**Cross-references to add:**

- UNRESOLVED — no cross-reference update set has been accepted for this reset contract.

## Related Documents

- [Development Plan](README.md)
- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — the rule behind the security laws S1-S6.
