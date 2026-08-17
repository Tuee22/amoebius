# Phase 18: Reconcile decision core under deterministic simulation

> **Purpose**: Build the reconcile decision core as pure code — `(observed inventory, desired index) → typed
> action set` — and run it under `IOSim`/`IOSimPOR` against authored observed-inventory corpora and injected
> fault schedules, so the core's fixed-point and convergence properties are established — and its token and
> reservation behaviour shown consistent with a modelled store — **before** the first live phase rather than
> inside it.
> **Read this if**: phase 18 is next in the queue, or a later phase depends on what its gate establishes.

Phase 18 delivers the reconcile decision core under deterministic simulation; its design is owned by [deterministic_simulation_doctrine.md](../documents/engineering/deterministic_simulation_doctrine.md), [cluster_lifecycle_doctrine.md](../documents/engineering/cluster_lifecycle_doctrine.md), [manifest_generation_doctrine.md](../documents/engineering/manifest_generation_doctrine.md), and the plan for reaching it is owned here.
Register 2: an in-process deterministic-replay battery, no cluster.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_17_dsl_formal_model.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 18.1: The decision core, separated 📋](#sprint-181-the-decision-core-separated-)
- [Sprint 18.2: Replay under injected schedules 📋](#sprint-182-replay-under-injected-schedules-)
- [Sprint 18.3: The token and reservation protocols under simulation 📋](#sprint-183-the-token-and-reservation-protocols-under-simulation-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-17 revalidation — created 2026-08-17 by the ordering re-baseline recorded in
[`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md).

## Phase Summary

[Phase 16](phase_16_deterministic_sim_substrate.md) builds a deterministic-simulation substrate and gates it
on a **toy** reconcile loop, stating plainly that later phases must replay their own reconcilers. Until this
phase existed, none did before the live band: the first simulation of amoebius's own reconciler sat inside the
same phase as its live gate, which that phase concedes is *"not chronologically ahead of it."* This phase is
the missing subject for the instrument Phase 16 builds.

**The architectural cut this requires is one doctrine already makes.**
[formal_model_doctrine.md](../documents/engineering/formal_model_doctrine.md) places the checked
correspondence between the specification and the **decision core**, not the effectful daemon. So the decision
core is separable, and this phase separates it: a pure total function
`(observed inventory, desired index) -> Either Refusal ActionSet`, with the effectful driver — real client,
real apiserver, real waits — left to the live band. The codomain carries `Refusal` because a three-valued
observation must be able to decline rather than act, and a function that can only return actions has nowhere
to put that. The diff is a fold over two values; nothing about it needs a cluster.

**What this phase does not claim.** It does not claim the daemon captures its inputs with the right freshness
or applies the decision faithfully; that is runtime fidelity, and it is UNVERIFIED here. It does not claim the
modelled environment matches a real apiserver. Both belong to the live band, which re-runs *these* properties
against built code instead of establishing them for the first time. Where the simulated loop and the live
driver are different code, the live band establishes those properties anew rather than re-running them; the
ledger must say which of the two it is doing.

**Phase scope:** one cohesive claim — *the reconcile decision core is idempotent, convergent, and protocol-safe
under every injected schedule* — across three sprints and one acceptance command. The split trigger is a real
client: the moment a property needs a live apiserver, it is not this phase's.

**Substrate:** `none` — no host, no cluster ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 2 — boundary integration with fakes, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Gate:** `python3 tools/reconcile_core_simulation_gate.py` replays every authored schedule byte-identically
from its seed, satisfies every property named in [Gate integrity](#gate-integrity), and reddens under every
seeded mutant. Phase 19 does not open unless the ledger records Register 2 green with runtime fidelity and
modelled-environment fidelity both UNVERIFIED.

## Gate integrity

The corpora are **authored, not generated from the implementation**: a set of observed-inventory values paired
with a desired index and the typed action set a human says should follow
([§M](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) clause 3). The
independent oracle is a reference action-planner written against
[manifest_generation_doctrine.md](../documents/engineering/manifest_generation_doctrine.md) and sharing no
code with the decision core — the same independence the live reconciler phase already requires of its own
checker, pulled one band earlier.

Properties, each with its own seeded mutant:

**Established here, against the core itself:**

- **Fixed point** — replaying a converged state produces the empty action set. This is *not* idempotence:
  `f(f(x)) = f(x)` is not even type-correct when `f` returns actions rather than a state, and the idempotence
  a reconciler reader cares about — applying the same action twice equals applying it once — is a property of
  the driver and the apiserver, not of this fold. Mutant: an action that always re-emits.
- **Convergence** — every corpus reaches a fixed point within its authored bound, under a modelled
  environment transition (actions × inventory → inventory) that the corpus supplies. Mutant: an oscillating pair.

**Established only as consistency with a modelled store, and UNVERIFIED against a real one:**

- **Token no-reuse** — a snapshot token is not reusable after any observed transition. This is a property of
  the *store's* compare-and-set across steps; the pure core has no memory of issued tokens, so what the gate
  shows is that the core never *requests* a reuse the modelled store would have to refuse. Mutant: the guard
  removed.
- **Reservation safety** — no double debit across `Reserved → BindingInFlight → Bound`, and a crash between
  any two steps recovers without dropping `Bound`. A pure function does not crash; the crash is the modelled
  environment's, and the claim is that the core's decisions remain safe under it. Mutant: the crash-recovery
  arm dropped.

**Typed, not tested:** `Unreachable` must never be folded into `Absent` — the defect that deletes a live
resource because a probe timed out. If a mutant conflating them can be *written*, the conflation is
representable, and this project's doctrine says to close that in the type: the `Delete` action is indexed on
a `Present` witness, so "delete on `Unreachable`" has no constructor. The corpus still carries an
`Unreachable` row to prove the refusal path is reached, but the foreclosure is Gate-1's, not a property here.

Determinism is a precondition, not a property: the same seed must produce a byte-identical trace, and a
schedule that replays differently fails before any property is evaluated.

## Doctrine adopted

- [deterministic_simulation_doctrine.md](../documents/engineering/deterministic_simulation_doctrine.md): the
  `io-classes` lift, the modelled environment, and the same-seed byte-identical replay contract.
- [cluster_lifecycle_doctrine.md §9 — how bring-up and teardown are implemented](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine):
  the `discover → diff → enact → re-observe` loop and its three-valued observation.
- [manifest_generation_doctrine.md](../documents/engineering/manifest_generation_doctrine.md): desired state is
  `renderAll` of a sealed spec, observed state is an inventory, and actions are typed — which is what makes
  the diff a fold rather than a client.

## Sprints

## Sprint 18.1: The decision core, separated 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Reconcile/Core.hs`, `test/fixture/reconcile_core/**`
**Blocked by**: none within the phase.
**Independent Validation**: a reference action-planner sharing no code with the core, authored from doctrine.
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`

### Objective

Extract the diff as a pure total function and give it an authored corpus. No client, no `IO`, no waits.

### Deliverables
- `(observed inventory, desired index) -> Either Refusal ActionSet`, total over both inputs.
- An authored corpus pairing inputs with the expected action set.
- The independent reference planner.

### Validation
1. **The core is run on every corpus row**, and its action set equals the row's authored expectation. A gate
   that compared the corpus against the reference planner alone would pass with the core unimplemented, which
   is the [§M](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
   stub failure this phase cites.
2. The reference planner agrees with the authored corpus independently. Where planner and corpus disagree the
   **corpus is authoritative** and the run is red: the corpus is the reviewed artifact, the planner is a
   second opinion on it.
3. A structural check confirms the core imports no client, process, or network module.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 18.2: Replay under injected schedules 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Reconcile/Sim.hs`, `test/spec/reconcile/CoreSimSpec.hs`
**Blocked by**: Sprint 18.1
**Independent Validation**: same seed, byte-identical trace, checked before any property is evaluated.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md`

### Objective

Run the core under `IOSim`/`IOSimPOR` against the Phase-16 substrate with partition, redelivery, reorder, and
crash schedules injected, and establish idempotence, convergence, and three-valued refusal.

### Deliverables
- The lifted loop and its schedule set.
- The three properties above, each with its mutant.

### Validation
1. Byte-identical replay per seed.
2. Each of the three mutants reddens its own property and no other.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding.

## Sprint 18.3: The token and reservation protocols under simulation 📋

**Status**: Planned
**Implementation**: `test/spec/reconcile/ProtocolSimSpec.hs`
**Blocked by**: Sprint 18.2
**Independent Validation**: the properties are the ones
[Phase 17](phase_17_dsl_formal_model.md) states formally; agreement between the model and the simulation is
itself reported, and a disagreement fails.
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md`

### Objective

Exercise the snapshot-token/CAS and reservation state machines in code under the same injected schedules,
against the invariants Phase 17 model-checks.

### Deliverables
- The two protocol batteries and their mutants.
- A reported comparison between each simulated property and its Phase-17 model invariant.

### Validation
1. No injected schedule reuses a token after an observed transition, and none double-debits.
2. A crash between any two reservation steps recovers without dropping `Bound`.
3. Each protocol mutant reddens its own property.

### Remaining Work
The whole sprint. Nothing in it is built; every deliverable above is outstanding. Runtime fidelity against a real apiserver, and the modelled environment's fidelity to real
infrastructure, are UNVERIFIED here and owned by the live band.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `cluster_lifecycle_doctrine.md` — the reconcile loop gains a decision-core/driver split (Sprint 18.1).
- `deterministic_simulation_doctrine.md` — the substrate gains its first amoebius-owned subject (Sprint 18.2).
- `resource_capacity_doctrine.md` — the two protocols gain a pre-cluster home (Sprint 18.3).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` Phase Overview links its Phase 18 row to this document.
- The live-band reconciler and scheduler phases cite this phase as where their properties were established.

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 18 row is the source for this phase's objective and gate.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys.
- [phase_16_deterministic_sim_substrate.md](phase_16_deterministic_sim_substrate.md) — the substrate this
  phase is the first amoebius-owned subject for.
- [phase_17_dsl_formal_model.md](phase_17_dsl_formal_model.md) — the Register-1 half; the invariants this
  phase exercises in code.
- [`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md) — the
  replay contract.
- [`cluster_lifecycle_doctrine.md`](../documents/engineering/cluster_lifecycle_doctrine.md) — the reconcile loop.
