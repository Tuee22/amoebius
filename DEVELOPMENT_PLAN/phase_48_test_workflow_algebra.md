# Phase 48: The test-workflow algebra

> **Purpose**: Specify the pure test-workflow algebra target: a phantom-state teardown obligation, deterministic
> `suggest-test` projections, named flagged-authority values, and an honest evidence model.
> **Read this if**: phase 48 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 48.1: The test-topology type — a deployment-rules layer that always tears down ⏸️](#sprint-481-the-test-topology-type--a-deployment-rules-layer-that-always-tears-down-)
- [Sprint 48.2: Pure `suggestTest` over supplied models and lazy proposal projection ⏸️](#sprint-482-pure-suggesttest-over-supplied-models-and-lazy-proposal-projection-)
- [Sprint 48.3: Flagged-authority and test-owned tagging vocabulary ⏸️](#sprint-483-flagged-authority-and-test-owned-tagging-vocabulary-)
- [Sprint 48.4: Phase-90 transfer for destructive cleanup and leak observation ⏸️](#sprint-484-phase-90-transfer-for-destructive-cleanup-and-leak-observation-)
- [Sprint 48.5: Pure evidence algebra and Phase-90 failover transfer ⏸️](#sprint-485-pure-evidence-algebra-and-phase-90-failover-transfer-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 47, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** Phase 48 owns only a pure Haskell `TestTopology` algebra. Its
phantom states require a teardown continuation, its bounded fault/expectation schedule is deployment-rules
data, and its `suggestTest` function maps a supplied Haskell capacity/authority model to either a proposed
topology or a structured refusal. Haskell declarations own all representative cases and expectations. If an
external Dhall proposal or other serialized form is useful, Haskell generates it lazily beneath
`.build/test-corpora/**`; no `.dhall`, fixture, golden, mutant, script, credential, or evidence file is tracked.

Phase 48 performs no substrate detection, credential probe, resource creation, fault injection, teardown,
inventory readback, browser action, hardware observation, or cluster validation. Those effectful and
destructive responsibilities belong to Phase 90 after the Phase-49 hardware-free DSL promotion barrier and
after their own numerical predecessors. The pure types may describe those later epochs, but a modeled
inventory or capacity value is never represented here as a live observation.

**Phase scope:** one target claim — a Haskell test-topology value cannot reach its terminal state without a
typed teardown continuation, and `suggestTest` is a pure proposal function over supplied model values.

**Substrate:** `none` — Haskell values only; no host, browser, provider, cluster, credential, or hardware.

**Lane:** `none` — live per-test lanes belong to Phase 90.

**Register:** 1 target only; live execution, cleanup, and evidence remain UNVERIFIED.
**Depends on:** [Phase 47](phase_47_tool_and_mutant_generation.md)
**Gate:** `pb validate phase 48`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — a pure Haskell test-topology value carries a typed teardown continuation, and pure Haskell `suggestTest` maps supplied model values to a proposal or structured refusal. Generated external forms remain beneath `.build/**`; live execution, deletion, and observation belong to Phase 90. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 48` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 47; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`jit_artifact_doctrine.md` §2 — The rule, and the closed exception list](../documents/engineering/jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list) — every serialized test
  topology is a lazy content-addressed projection beneath `.build/**`, never authored repository source.
- [`testing_doctrine.md` §1 — A test is an amoebius spec](../documents/engineering/testing_doctrine.md#1-a-test-is-an-amoebius-spec) and
  [`testing_doctrine.md` §3 — The test-topology contract: spin up → run → always tear down](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down)
  — Phase 48 owns the Haskell algebra and typed teardown obligation only; Phase 90 owns spin-up, run, teardown,
  and leak observation.
- [`testing_doctrine.md` §5 — `suggest-test`: detect the world, emit a representative test `.dhall`](../documents/engineering/testing_doctrine.md#5-suggest-test-detect-the-world-emit-a-representative-test-dhall)
  — `suggestTest` is pure over supplied Haskell model values here. Live detection and authority inspection are
  Phase-90 work; any Dhall proposal is generated under `.build/test-corpora/**` for human review.
- [`testing_doctrine.md` §6 — Flagged test credentials](../documents/engineering/testing_doctrine.md#6-flagged-test-credentials) and
  [`testing_doctrine.md` §7 — The elevated harness is the sole automated deleter of test-owned durable storage; leak-free cycles](../documents/engineering/testing_doctrine.md#7-the-elevated-harness-is-the-sole-automated-deleter-of-test-owned-durable-storage-leak-free-cycles)
  — flagged authority, destructive cleanup, and independent inventory are represented as closed Haskell
  terms but are not exercised before the post-barrier live phase.
- [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)
  — Phase 48 may compose pure capacity terms over supplied model values; it cannot establish live fit.
- [`testing_doctrine.md` §8 — One substrate per validation](../documents/engineering/testing_doctrine.md#8-one-substrate-per-validation)
  — Phase 48 has no substrate. Phase 90 must name and observe exactly one live substrate when it eventually
  seeks promotion.

## Sprints

Every sprint below is hardware-free. Its subject, cases, expectations, and changed-production-subject mutants
are Haskell; any serialized projection is generated lazily beneath `.build/test-corpora/**`. Phase 48 has no
effect interpreter and cannot establish that any modeled host, authority, inventory, teardown, or failover
event occurred. Phase 90 owns those live obligations after all numerical predecessors are human-approved.

## Sprint 48.1: The test-topology type — a deployment-rules layer that always tears down ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 47](phase_47_tool_and_mutant_generation.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`testing_doctrine.md §3 — the test-topology contract: spin up → run → always tear down`](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down)
and the framing of [`§1 — a test is an amoebius spec`](../documents/engineering/testing_doctrine.md#1-a-test-is-an-amoebius-spec):
define the pure Haskell `TestTopology` and workflow-state algebra that a later interpreter must consume. The
algebra adds a bounded fault-intent schedule, typed expectations, and a non-optional teardown continuation to a
production app/platform specification. Its phantom states make a terminal workflow result unavailable until a
teardown outcome has been supplied to the pure transition fold. Phase 48 does not spin up, interrupt, or tear
down anything.

### Deliverables

- A Haskell `TestTopology` type wrapping an app/platform specification with exactly three test-only values:
  `FaultIntentSchedule`, typed `Expectation` declarations, and `TeardownObligation`. These are descriptions,
  not effects or observations.
- Phantom workflow states and a pure transition fold that accepts declared workflow and teardown outcomes,
  preserves the primary workflow failure when both outcomes fail, and cannot construct a terminal success
  from a state whose teardown obligation is outstanding.
- A closed Haskell case corpus and separately authored Haskell transition oracle covering success, workflow
  failure, modeled interruption, teardown failure, and repeated modeled teardown. Any human-readable trace is
  a lazy `.build/test-corpora/**` projection of those Haskell values.
- Changed-production-subject Haskell mutants that omit the teardown transition, convert cleanup failure to
  success, or replace the primary failure; each must turn the independent transition oracle red while an
  unaffected control remains green.

### Validation

1. The independently authored Haskell oracle enumerates the accepted transition graph and proves by complete
   constructor discovery that every terminal result follows a supplied teardown outcome; empty discovery is a
   refusal, not a pass.
2. Paired Haskell cases differing only in the teardown outcome preserve success versus cleanup failure at the
   exact result field. A second modeled teardown is classified idempotently without invoking an effect.
3. Each changed-production-subject mutant named above is observed applied at its production locus and makes
   the oracle fail for the expected reason. Merely replaying expected output, changing only a fixture, or
   reporting a mutant count cannot satisfy this criterion.
4. The generated projection is derived twice from the same Haskell value with the projection cache bypassed;
   the bytes agree, the second derivation is observed to execute, and both outputs remain beneath `.build/**`.
   This validates projection determinism only, not live teardown.

### Remaining Work

This sprint remains blocked and NOT VALIDATED. Phase 90 owns workflow execution, interruption handling,
resource reclamation, and external confirmation that teardown occurred.

## Sprint 48.2: Pure `suggestTest` over supplied models and lazy proposal projection ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 48.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`testing_doctrine.md §5 — suggest-test: detect the world, emit a representative test .dhall`](../documents/engineering/testing_doctrine.md#5-suggest-test-detect-the-world-emit-a-representative-test-dhall):
define `suggestTest` as a total, pure proposal function over explicitly supplied Haskell model values. Phase 48
does not discover a substrate, inventory capacity, inspect hardware, probe authority, resolve a secret, or
contact a provider. A supplied value is unauthenticated model input here even if a later phase can populate the
same type from live observation.

### Deliverables

- A pure
  `suggestTest :: SuppliedTestModel -> Either SuggestionRefusal (TestTopology TeardownRequired)` whose input
  contains modeled substrate class, capacity, capability, authority names, and provider quotas. The type and
  function do not claim those values were observed.
- Closed Haskell resource branches for registry publication, Pulumi execution, storage migration, runtime
  metadata, and optional accelerator demand. Exact-fit and one-short results are computed solely by the pure
  resource fold over the supplied model.
- A symbolic delegated-failover `FaultIntent` and named authority references only. Phase 48 neither resolves
  those references nor injects the intent.
- A deterministic Dhall or other serialized proposal generated only beneath `.build/test-corpora/**`. The
  projection is review material, never repository source, a semantic oracle, or proof that its modeled target
  exists.

### Validation

1. A closed, independently authored Haskell case matrix covers every constructor of `SuppliedTestModel` and
   every optional resource branch. Runtime discovery must equal the expected constructor set in both
   directions, and empty discovery refuses validation.
2. Exact-fit positives and minimally different one-short negatives return the independently expected topology
   or the exact `SuggestionRefusal` locus for CPU, memory, storage, runtime metadata, accelerator, and provider
   quota model fields. These are arithmetic claims over supplied values, not hardware validation.
3. Named changed-production-subject mutants that drop a resource branch, a debit, a teardown obligation, or a
   refusal path each turn the independent Haskell oracle red; an unaffected control stays green and the gate
   records the applied production locus.
4. No result or projection contains secret material: authority is represented only by a symbolic name. This
   validates the pure representation, not credential existence or permissions.
5. Two cache-bypassed projections from the same Haskell proposal are byte-identical, are derived during the
   candidate run, and exist only beneath `.build/test-corpora/**`. Neither output is used as its own oracle.

### Remaining Work

This sprint remains blocked and NOT VALIDATED. Phase 90 owns substrate and hardware discovery, inventory and
quota readback, credential probing, provider access, allocation, and comparison of a proposal with the live
world.

## Sprint 48.3: Flagged-authority and test-owned tagging vocabulary ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 48.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`testing_doctrine.md §6 — flagged test credentials`](../documents/engineering/testing_doctrine.md#6-flagged-test-credentials):
define the Haskell vocabulary that distinguishes ordinary authority intent from flagged test authority intent
and ordinary ownership from test-owned ownership. These values describe a later interpreter's required policy;
they are not credentials, permissions, tags applied to resources, or proof of authorization.

### Deliverables

- Closed Haskell `AuthorityIntent` and `OwnershipIntent` types whose flagged/test-owned constructors cannot be
  confused with ordinary-operation constructors.
- A pure rule requiring every modeled allocatable item in a test topology to carry `TestOwnedIntent`, while
  forbidding credential material and destructive operations from the topology language.
- Symbolic authority references by name only, plus an explicit `AuthorityUnverified` state that Phase 48 cannot
  promote. Secret resolution, permission checks, and application of ownership metadata belong to Phase 90.
- Haskell positives, paired negatives, and changed-production-subject mutants for constructor confusion,
  missing ownership intent, secret inlining, and an exposed deletion primitive.

### Validation

1. The Haskell type checker or pure decoder rejects ordinary/flagged authority confusion at the exact field,
   paired with a positive differing only in that constructor. No runtime identity is used.
2. Complete Haskell constructor discovery proves that every modeled allocatable item requires ownership intent;
   the paired missing-intent negative and each bypass mutant fail at the independently expected locus.
3. The Haskell language and every lazy `.build/**` projection contain authority names only. A secret-bearing
   changed-subject mutant turns the independent oracle red, while no credential store is contacted.
4. A production mutant that adds a delete operation to the Phase-48 topology language turns the gate red. This
   is a language-boundary check only; Phase 48 performs no deletion or permission probe.

### Remaining Work

This sprint remains blocked and NOT VALIDATED. Phase 90 owns acquiring and resolving credentials, verifying
their external permissions, applying test-owned metadata during allocation, and observing that metadata at the
live boundary.

## Sprint 48.4: Phase-90 transfer for destructive cleanup and leak observation ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 48.3
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`testing_doctrine.md §7 — the elevated harness is the sole automated deleter of test-owned durable storage; leak-free cycles`](../documents/engineering/testing_doctrine.md#7-the-elevated-harness-is-the-sole-automated-deleter-of-test-owned-durable-storage-leak-free-cycles),
the named exception delegated by
[`storage_lifecycle_doctrine.md §7.1 — the single exception: the elevated test harness`](../documents/engineering/storage_lifecycle_doctrine.md#71-the-single-exception-the-elevated-test-harness):
keep destructive cleanup and leak observation outside Phase 48 while defining the pure teardown-result and
modeled-inventory-difference vocabulary that Phase 90 must interpret. The Phase-48 DSL exposes no deletion
primitive, holds no destroy authority, and cannot turn modeled inventory values into live evidence.

### Deliverables

- Haskell `TeardownObligation`, `TeardownOutcome`, `InventoryModel`, and `ResidueClassification` types. Every
  inventory value is explicitly modeled and unauthenticated in this phase.
- A pure, total inventory-difference fold that distinguishes a resource modeled both before and after from one
  modeled only after. It accepts a closed set of declared inventory domains so dropping a domain cannot produce
  an empty-result pass.
- A result rule that refuses workflow success when teardown failed, inventory-domain coverage is incomplete,
  or modeled post-run residue is non-empty. It proves only the algebra's response to supplied values.
- No delete path, resource selector, credential operation, API command, provider operation, host path, or live
  inventory collector. Phase 90 owns their implementation and independent observation.

### Validation

1. Independently authored Haskell cases cover clean modeled teardown, teardown failure, retained-in-both-models,
   post-only residue, and missing inventory-domain coverage. Each has an exact expected constructor and reason.
2. Paired cases differing only by one modeled resource distinguish retained-in-both from post-only residue;
   paired cases differing only by one inventory-domain declaration distinguish complete from incomplete
   coverage.
3. Changed-production-subject mutants that ignore post-only residue, compare only ownership-marked items, drop
   an inventory domain, or convert teardown failure to success each turn the independent oracle red. The gate
   records the applied production locus and keeps an unaffected control green.
4. The candidate output labels every result as a pure model result and leaves live cleanup, authority, and leak
   evidence UNVERIFIED. No modeled case may be reported as a successful external sweep.

### Remaining Work

This sprint remains blocked and NOT VALIDATED. Phase 90 owns allocation tracking, credentials, destructive
cleanup, complete live inventory collection, backing-store inspection, leak observation, and independent
confirmation that cleanup reached the external substrate or provider.

## Sprint 48.5: Pure evidence algebra and Phase-90 failover transfer ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 48.4
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`testing_doctrine.md §4 — no skips, fail fast, and the per-run ledger artifact`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
and [`§8 — one substrate per validation`](../documents/engineering/testing_doctrine.md#8-one-substrate-per-validation):
define the pure Haskell evidence-ledger grammar and refusal rules. The ledger's Extract → Model → Inject moves
and proven/tested/assumed strengths are owned by
[`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
and the live-fault Inject move by [`§11`](../documents/engineering/chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose).
Phase 48 can validate only derivation over supplied Haskell declarations. It cannot award Runtime strength,
execute a topology, perform preflight, inject a fault, or observe failover.

### Deliverables

- A Haskell `Ledger` algebra whose applicable-move set is derived from the topology's declared
  `FaultIntentSchedule` and the closed `FaultKind`-to-invariant map, never supplied by the ledger emitter.
- Separate evidence constructors for pure proof/model results and future authenticated Runtime observations.
  The Phase-48 evaluator cannot construct or promote the latter; applicable runtime moves remain UNVERIFIED.
- A pure refusal when a required declaration, expected move, independent oracle entry, or inventory-domain
  declaration is absent. Missing input never becomes a skip or pass.
- A separately authored Haskell expected-move declaration and changed-production-subject ledger mutants. Any
  serialized ledger table is generated lazily beneath `.build/test-corpora/**` and is not an oracle.
- An explicit Phase-90 handoff contract for live preflight, allocation, credential and tool checks, topology
  execution, fault injection, failover observation, teardown, leak observation, and Runtime evidence.

### Validation

1. Complete Haskell discovery equates the expected and derived move sets in both directions. An empty discovered
   set, an unknown fault intent, or a missing expected-move declaration refuses validation.
2. Paired pure cases differing only by one declared fault intent produce the exact additional applicable move;
   a declared-but-unperformed Runtime move remains UNVERIFIED. No Phase-48 case can classify it as tested.
3. Changed-production-subject mutants that let the emitter declare applicability, mark every move tested,
   upgrade tested or assumed to proven, or omit an applicable move each fail the independent Haskell oracle at
   the expected field. Applied-locus witnesses and unaffected controls are required.
4. A Haskell case with a missing modeled prerequisite returns the exact refusal rather than a skip. This does
   not validate any live prerequisite check; Phase 90 must probe and observe the real boundary.
5. Two cache-bypassed ledger projections agree byte-for-byte beneath `.build/test-corpora/**`, while the Haskell
   oracle—not either projection—determines the verdict.

> **Honesty.** Phase 48 validates no intra-cluster or cross-cluster failover. It represents delegated-failover
> intent and evidence strengths as pure Haskell values only. Phase 90 owns live test-topology execution and
> failover observation after its predecessors; the component-specific phase chain remains responsible for
> making the delegated service available first.

### Remaining Work

This sprint remains blocked and NOT VALIDATED. Phase 90 owns authenticated Runtime evidence, live topology and
preflight, provider or hardware execution, fault injection, failover observation, teardown, and the live ledger
artifact.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/testing_doctrine.md` — record the pure teardown, suggestion, credential, and evidence
  module and leave generated/live topology, harness, sweep, and per-run evidence explicitly to Phase 90.
- `documents/engineering/app_vs_deployment_doctrine.md` — retain the deployment-rules target while recording
  that Phase 48 validates only its pure workflow value.
- `documents/engineering/resource_capacity_doctrine.md` — retain the full live provision target while
  distinguishing Phase 48's nine-axis pure suggestion projection from Phase 90's allocation/readback proof.
- `documents/engineering/storage_lifecycle_doctrine.md` — leave §7.1's automated test-reclaim owner UNVERIFIED
  until Phase 90; Phase 48 owns no delete authority.
- `documents/engineering/pulumi_iac_doctrine.md` — record only Phase 48's pure flagged-authority and ownership
  vocabulary. Leave credential resolution, permission checks, allocation metadata, and destroy authority
  UNVERIFIED for Phase 90.
- `documents/engineering/chaos_failover_doctrine.md` — record Phase 48's pure ledger grammar and explicit
  inability to award Runtime strength. Leave live fault injection and failover observation to Phase 90; the
  cross-cluster gateway-migration obligation stays in Phase 75.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-48 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/system_components.md` — record `lib:test-workflow-algebra-core` as Phase 48's Decision-layer
  component and keep live `Amoebius.Test` module-namespace ownership at Phase 90.
- `DEVELOPMENT_PLAN/substrates.md` — retain Phase 48 at `none`/`none`; Phase 90 owns the generated test's live substrate.

## Related Documents

- [README.md](README.md) — the live tracker; Phase 48 objective, gate, and substrate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (skeleton, sprint format, the doctrine-citation rule, the register + honesty + one-substrate disciplines)
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (no bespoke election; single-instance delegated to k8s/etcd; the no-normal-operation-deletion storage rule)
- [system_components.md](system_components.md) — the target component inventory for the `Amoebius.Test` modules
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — the test-as-a-topology contract,
  whose pure topology, suggestion, authority-intent, teardown-result, and ledger vocabulary Phase 48 defines;
  Phase 90 owns the live harness
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — the retained PV model,
  the no-normal-operation-deletion rule, and the elevated-harness exception that remains deferred to Phase 90
- [Chaos / Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — the proven/tested/assumed
  ledger grammar Phase 48 models without performing either fault injection or failover observation
- [Chaos / Failover Second Axis](../documents/engineering/chaos_failover_second_axis.md) — the separate
  intra-cluster and cross-cluster evidence axes represented by the pure ledger; their live exercise remains
  outside Phase 48
- [Application Logic vs Deployment Rules](../documents/engineering/app_vs_deployment_doctrine.md) — the
  deployment-rules surface on which Phase 48 represents fault intent as data for a later interpreter
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md) — the `SecretRef`-by-name contract the
  pure authority reference obeys; Phase 48 does not resolve it
- [Pulumi EBS Credential Model](../documents/engineering/pulumi_ebs_credential_model.md) — the authority and
  ownership vocabulary Phase 48 can model without resolving credentials, provisioning storage, or observing
  provider state
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — single-instance delegated
  to k8s/etcd and worker takeover delegated to Pulsar, never a bespoke election
- [phase_69](phase_69_content_store_workflow.md) — the delegated Pulsar capability that must exist before a
  later live test can exercise the modeled failover intent
- [phase_75](phase_75_gateway_migration_drills.md) — the distinct cross-cluster gateway-migration obligation;
  Phase 48 executes neither axis
- [phase_79](phase_79_provider_dynamic_nodes.md) — the provider behavior that remains input to Phase 90's live
  test cycle, not Phase-48 evidence
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
