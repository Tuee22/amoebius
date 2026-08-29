# Deterministic Simulation: the real code, run against a modeled world

> **Purpose**: Single source of truth for **deterministic simulation testing (DST)** in amoebius — running the
> *real* daemon/reconciler code, written once against `io-classes`, under `io-sim`/`IOSimPOR` against a
> **modeled, fault-injectable environment** (fake Pulsar/MinIO/apiserver/route53/Vault/clock), so concurrent
> schedules and environment faults are validated **in-process, deterministically replayable, before any live > deployment** — and the honest tradeoff this buys: it replaces a large *unvalidated-until-live* surface with a
> small *modeled-environment-fidelity* premise — Register 2.5 of the conformance spine.
> **Read this if**: real daemon code has to be exercised against controlled schedules rather than a live cluster.

This document owns the simulation layer: the seam that lets one program run unchanged against modelled time
and modelled failure, and the honest statement of what a passing simulation does and does not establish. It
is an activity rather than a phase gate, and the registers that are gates are owned by
[testing_doctrine.md §2](./testing_doctrine.md#2-the-registers-of-amoebius-testing).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, documents/engineering/README.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Every phase-run or implementation-result statement in this document is permanently invalidated diagnostic history. It cannot establish or reactivate current status, even if a phase later advances. Target doctrine remains normative; current status is solely in the [tracker](../../DEVELOPMENT_PLAN/README.md).

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. The io-classes environment abstraction — build it pure, lift it whole](#2-the-io-classes-environment-abstraction--build-it-pure-lift-it-whole)
- [3. The simulated environment and its fault model](#3-the-simulated-environment-and-its-fault-model)
- [4. Register 2.5 — where deterministic simulation sits](#4-register-25--where-deterministic-simulation-sits)
- [5. What DST establishes, and the one premise it buys](#5-what-dst-establishes-and-the-one-premise-it-buys)
- [6. One determinism substrate, two uses](#6-one-determinism-substrate-two-uses)
- [7. The boundary — what stays Register 3](#7-the-boundary--what-stays-register-3)
- [8. Planning ownership](#8-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

The concurrency-and-failover method ([chaos_failover_doctrine.md §10](./chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim))
offers the io-sim lift as a **conditional** move — taken "where the in-process concurrency is intricate enough
that Extract's purity boundary still leaves real schedule-dependent behaviour." The plan assigns the
*pure-decision-core* target against hand-built peer stubs to Tier-1 Phase 17, while leaving the daemon's real
concurrent schedule and every interaction with the real environment (apiserver
admission, Pulsar redelivery/partition, DNS propagation, clock skew), to Register-3 live chaos. This doctrine
makes the move **standing rather than conditional**, and points it at the production daemon. Register-3 chaos is the strongest *empirical* instrument but the weakest *logical* one:
it is **sampled** and **late**, and a rare interleaving surfaces once in ten thousand runs, if ever
([chaos_failover_doctrine.md §3](./chaos_failover_doctrine.md#3-the-defect-class--one-shape-two-disguises)).

The industry answer to "make the rare interleaving deterministically reproducible **before** production" is
**deterministic simulation testing** — FoundationDB's *Flow*, TigerBeetle's VOPR, and Antithesis, the peers
`io-sim` was built to be for Haskell (IOG / Well-Typed's `ouroboros-network`). amoebius is unusually
well-positioned to adopt it: the shared daemon spine already forbids `forkIO` and mandates structured
`withAsync`/`bracket` ([daemon_topology_doctrine.md §6](./daemon_topology_doctrine.md#6-the-shared-daemon-spine)),
so the shapes lift cleanly; `renderAll`/`chain` are already pure, so the only effectful surface is a thin,
well-typed seam. This doctrine adopts DST for that surface. It **does not** re-open the concentration principle
([chaos_failover_doctrine.md §6](./chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives)):
DST does not re-prove etcd/MinIO/Pulsar/Patroni consensus — it validates **amoebius's own code** that composes
them, against a *model* of how they behave.

---

## 2. The io-classes environment abstraction — build it pure, lift it whole

Every concurrency-touching amoebius component is written **polymorphic over a monad `m`** carrying the
`io-classes` constraints (`MonadSTM`, `MonadAsync`, `MonadFork`, `MonadTimer`, `MonadTime`,
`MonadThrow`/`MonadCatch`), and reaches the outside world only through a **typed effect interface** (a record of
capabilities — publish/consume, put/get-blob, apply-object, write-DNS, vault-op, now/delay), never a concrete
client. Two interpreters are then chosen from one source:

- in production, `m = IO` with the real clients — the real daemon;
- under test, `m = IOSim s` with the modeled environment of [§3](#3-the-simulated-environment-and-its-fault-model)
  — a pure, discrete-event simulator with deterministic scheduling and simulated time.

The **same source** is the implementation *and* the model under test. `IOSimPOR` adds partial-order reduction to
discover races and systematically explore schedules, and drives QuickCheck, so a discovered interleaving returns
as a **minimal, replayable counterexample** rather than a once-a-month flake. This is the "build it pure; lift it
whole" ladder of [chaos_failover_doctrine.md §10](./chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim),
carried to completion: not only the decision, but the whole concurrent program.

The standing cost is named honestly: making the concurrency-touching signatures polymorphic in `m` is a **tax on all future change**, not a one-time edit. It is paid deliberately, in exchange for [§5](#5-what-dst-establishes-and-the-one-premise-it-buys).

The first planned substrate instance belongs to
[Phase 16](../../DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md), which is **NOT VALIDATED**. Its gate
must run one reference reconciler under the injected real-client interface and `IOSim`, while a source gate
excludes bare `IO` signatures and raw concurrency primitives from the simulation surface. The gate must also
construct the actual Phase-10 artifact/budget/lift/workflow/evidence `Composition`, project its ordered names
and exact resource fold, and feed those names to the same reference reconciler under `IOSim`. An independently
authored Haskell semantic oracle must check that projection; the adapter may not invent a parallel calculus
vocabulary. Later phases must run their own production reconcilers on this interface; neither this target nor
its later users have a current complete gate pass.

[Phase 19](../../DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md) owns the first amoebius pre-cluster
subject rather than another substrate demonstration. Its standalone pure planner must run one
three-action world under exactly four authored schedules: baseline, duplicate delivery, crash before apply,
and stale snapshot. All four must converge to the authored inventory under `IOSim` and bounded `IOSimPOR`;
four fresh same-seed encodings must agree and a changed seed must change semantic action order. This is a target Register-2 phase
gate over a modeled versioned store, not a Register-2.5 production-daemon claim. Store fidelity is ASSUMED and
effectful runtime fidelity is UNVERIFIED.

[Phase 58](../../DEVELOPMENT_PLAN/phase_58_object_reconciler.md) owns the first target production-code
adoption. Its real Lease-token, scoped-SSA, serial, host/device-release, Job-terminal, authenticated-delete,
and readiness modules must cover eight fault classes × 256 schedules, bounded `IOSimPOR` exploration,
same-seed byte replay, and seven mutants. This targets Register-2.5 evidence; modeled-apiserver fidelity remains
assumed and requires an independent Register-3 live challenge.

[Phase 59](../../DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md) owns the second target production-code
adoption. Its readiness, execution-admission, reservation, Binding-preparation, recovery, and
modeled-apiserver paths must cover
seven scheduler fault classes × 256 schedules, bounded `IOSimPOR`, byte-identical replay, and seven red
mutants. Modeled-apiserver fidelity remains assumed and must be challenged independently by Phase 59's
Register-3 admission, custom-resource CAS, Binding, UID, resourceVersion, readiness, and cleanup observations.

---

## 3. The simulated environment and its fault model

The principal limit of a single-daemon io-sim run is that amoebius daemons coordinate through Pulsar + MinIO + the
commit log, **not in-process shared state** ([chaos_failover_doctrine.md §10](./chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim)),
so a run rests on stubbed peers. This doctrine's move is to make those substrates **first-class simulated components with a typed fault model**, rather than inert stubs — the FoundationDB approach. The modeled
environment provides deterministic, in-`IOSim` fakes of:

- **Pulsar** — subscriptions, at-least-once delivery, broker-side dedup, geo-replication; fault knobs: **delay, reorder, duplicate, partition (cut a link), broker crash**.
- **MinIO** — the content-addressed store with `If-None-Match`/`412` semantics; fault knobs: latency, partition,
  lost-write-before-ack.
- **kube-apiserver** — server-side apply, admission, resourceVersion conflicts, watch; fault knobs: conflict,
  reject, watch-gap, restart.
- **route53** — a short-TTL record store with **no compare-and-swap** and **propagation delay** (the exact
  shape the gateway migration must tolerate, [gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md)).
- **Vault** — seal/unseal, token/lease, transit; fault knobs: sealed, unreachable, lease-expiry.
- **the clock** — simulated time via `MonadTime`/`MonadTimer`, so timeouts, TTLs, and lease timing are driven,
  not waited on (rule R2, [chaos_failover_doctrine.md §13](./chaos_failover_doctrine.md#13-the-supporting-rules--the-conditions-the-moves-need)).

Each fake models an **interface contract**, not the vendor's internals; the faults are the ones the R1–R9 rules
name as the hazards amoebius's code must survive.

Phase 16 must implement and test the six model contracts: Pulsar partition/heal/redelivery/dedup/reorder,
MinIO `If-None-Match` 412, apiserver version-conflict/watch-gap/crash, route53 stale propagation with no CAS,
Vault sealed rejection, and simulated clock delay. Fidelity to the corresponding real systems remains the
explicit assumed premise of [§5](#5-what-dst-establishes-and-the-one-premise-it-buys).

These per-substrate **fault knobs are a different surface from the five-arm `FaultKind`** union of
[chaos_failover_doctrine.md §11.1](./chaos_failover_doctrine.md#111-the-typed-fault-schedule-chaosschedule--faulttarget),
and are not the same enumeration. `FaultKind` is the **Register-3** injected-fault union a live test topology
schedules against a running forest; the knobs above are the **Register-2.5** modeled-environment surface, finer
because a simulated substrate can perturb its own interface contract in ways a live fault schedule does not
name. The two are related but not equal, so the `FaultKind`→invariant map's totality is a claim about the
Register-3 union alone; a knob with no `FaultKind` counterpart (a MinIO lost-write-before-ack, a watch-gap) is
a modeled-environment perturbation, not a scheduled fault, and the conformance suite that discharges the
fidelity premise ([§5](#5-what-dst-establishes-and-the-one-premise-it-buys)) is what ties a knob back to real
substrate behaviour.

---

## 4. Register 2.5 — where deterministic simulation sits

The register *definitions* are owned by [testing_doctrine.md §2](./testing_doctrine.md#2-the-registers-of-amoebius-testing);
this doctrine owns the **shape** of the deterministic-simulation register and how it extends the pre-cluster
spine ([conformance_harness_doctrine.md §4](./conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply)).

- **Registers 1, 2, and 3** — pure/semantic-oracle, boundary-integration-with-fakes, and live-infrastructure — are
  defined by [testing_doctrine.md §2](./testing_doctrine.md#2-the-registers-of-amoebius-testing); the
  pre-cluster spine they run on is [conformance_harness_doctrine.md §4](./conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply).
- **Register 2.5 — deterministic simulation (this doctrine).** The real daemon/reconciler code under
  `IOSim`/`IOSimPOR` against the [§3](#3-the-simulated-environment-and-its-fault-model) modeled environment —
  exercising **concurrent schedules and injected environment faults**, which Registers 1 and 2 structurally
  cannot reach, and which Register 3 reaches only by sampling. Deterministically replayable, no cluster.

Phase 16 owns the no-cluster substrate serving this activity. Its target Register-2 gate must exercise a
reference reconciler across four oracle-pinned schedules plus an independent semantic projection from the
five-calculus composition; this criterion is scoped to the substrate and cannot pre-claim later Register-2.5
production-code results. Same-seed encoded traces must be compared between two fresh executions and a changed seed must differ.
Those bytes are a run-time determinism control, not a repository-retained generated-output expectation;
schedule verdicts and composition facts are the authored Haskell semantic oracles.

Register 2.5 is also where **trace validation** ([formal_model_doctrine.md §8](./formal_model_doctrine.md#8-trace-validation-the-earlier-codemodel-bridge))
first runs against the built daemon: the simulated daemon's observed transitions are checked against the emitted
TLA+ `Next` relation, giving the code↔model bridge a deterministic home before Register 3.

---

## 5. What DST establishes, and the one premise it buys

A green DST run is **tested**, not proven: it establishes that *the real code upholds its invariants under the
schedules and faults explored* against the modeled environment. It does **not** establish that the real
Pulsar/apiserver/route53 behave as modeled — that is the boundary [§7](#7-the-boundary--what-stays-register-3)
draws.

The tradeoff is deliberate, and it is stated honestly: DST **replaces** a large *"the code is unvalidated until a
live cluster exists"* surface with a small *"the code is validated against a model of the environment, and the
model's fidelity to the real substrate is assumed"* premise. That is strictly the better place to stand — a
narrow, testable fidelity assumption in place of a broad unverified one — and it matches amoebius's own instinct
everywhere else (make the load-bearing claim small and explicit). The fidelity premise is **discharged, not waved away**: a small Register-3 **conformance suite** checks each fake's contract against the real system (e.g.
the fake Pulsar's dedup/redelivery semantics against a real broker), and any divergence is a defect in the fake,
recorded in the ledger. Per [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline):
a DST green is quoted as *"the code upholds the invariants under the modeled schedules and faults,"* never as
*"the cluster is correct."*

---

## 6. One determinism substrate, two uses

DST and reproducible ML share **one** determinism substrate. The seed derivation and the `MonadTime`/`MonadTimer`
clock seams that make an ML run bit-reproducible ([content_addressing_doctrine.md](./content_addressing_doctrine.md), the determinism kernel [phase_80](../../DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md)) are the **same** seams
that make a simulation deterministically replayable. Injecting time and randomness through typed seams rather
than reading wall-clock or ambient entropy (rule R2) is what makes both "deterministic by construction"; the
kernel builds the seams once, and DST and ML reproducibility are two readings of them.

---

## 7. The boundary — what stays Register 3

DST does not abolish Register 3; it **shrinks** it. What remains genuinely live-only:

- **Environment fidelity** — that the real apiserver admits and schedules, the real LB comes up, real etcd forms
  quorum, the real broker offloads, real geo-replication lag and DNS propagation behave as [§3](#3-the-simulated-environment-and-its-fault-model)
  models them. (The conformance suite of [§5](#5-what-dst-establishes-and-the-one-premise-it-buys) samples this.)
- **Real-time / clock-skew physics** — the R8 synchrony premises DST runs in *logical* simulated time and so
  abstracts, never verifies.
- **Faults not injected** — DST samples the fault space; the interleavings and fault combinations it did not
  schedule stay unexercised (though, unlike chaos, any it *did* schedule is replayable).

The blindness between registers stays load-bearing: a green Register-2.5 run says nothing about what Register 3
would find, exactly as a green Register-1 suite says nothing about Register 2.

---

### Phase-61 target fail-closed simulation — NOT VALIDATED

Phase 61 must run the real Vault init/unseal/client decision code against the modeled Vault over 2,000 seeded
fault schedules (500 per named family), 21 combined sequences, and POR samples. No schedule may admit PKI
issuance, DSL acceptance, or secret resolution while sealed or freshness-unproven; replay must be deterministic
and the dropped-freshness mutant must produce the expected counterexample. This targets Register-2.5 evidence;
modeled-service fidelity remains assumed pending an independent Register-3 live Vault challenge on `linux-cpu`.

### Phase-63 target readiness-DAG simulation — NOT VALIDATED

Phase 63 must run the production `Amoebius.Platform.BringUp` orchestration unchanged under `IOSim`: 64 seeds
across healthy, partial-failure, restart-after-failure, and partition families must produce 256 deterministic
schedules. Every fault must fail closed, every healthy replay must be byte-identical and reach all Ready
states, and the MinIO/Percona-operator intervals must supply an independent-chain concurrency witness.
`IOSimPOR` must separately explore the healthy trace under a branching/schedule bound.

### Phase-67 target dedup-fold simulation — NOT VALIDATED

Phase 67 must drive the production `Amoebius.Pulsar.Dedup` fold through 720 deterministic reorder/duplicate
schedules. Every stable work key must apply exactly one effect and the unstable-key twin must turn red;
modeled-broker fidelity remains bounded by a separate Register-3 native-client challenge.

### Phase-69 target workflow-failover simulation — NOT VALIDATED

Phase 69 must run the production `Amoebius.Workflow.Runtime` transitions through 256 deterministic schedules
and a bounded `IOSimPOR` exploration of store-commit/kill/redelivery/partition interleavings. Every baseline
schedule must keep one applied effect, one promoted consumer handle, and the pinned pointer HEAD; the
duplicate-apply and orphan-consumer mutants must turn the simulation red. Modeled-substrate fidelity remains
assumed and requires a separate Register-3 live Failover challenge on the `linux-cpu` baseline at the host's
natural architecture ([substrate_doctrine.md §1.1](./substrate_doctrine.md#11-the-natural-architecture-rule)).

Phase 75 must add a second Register-2.5 instance: `GatewayMigrationSimSpec` must drive both migration traces
through the Phase-17 `interpret` function, validate every edge against the pinned action sequence, check all
five safety predicates, and explore 256 positive-lag schedules. The live companion must cover all sixteen
migration actions in real child clusters. Route53 and WAN fidelity remain named assumptions rather than being
inferred from the simulated delay model.

## 8. Planning ownership

This document is normative doctrine. The io-classes environment substrate is assigned to the pre-cluster
deterministic-simulation phase
([phase_16](../../DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md)); the bounded pure reconcile-core
subject is assigned to
[phase_19](../../DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md). Each concurrency-bearing
live-band phase adds its Register-2.5 validation sprint before its Register-3 gate; the determinism seams are the
[phase_80](../../DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md) kernel's. Phase order, status, and gates live
only in [DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md). Phases 58 and 59 own the target
production-code adoptions for the generic reconciler and capacity scheduler respectively; all prescriptive
claims remain design intent unless the complete qualified gate passes and the tracker records that result.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [Chaos & Failover Doctrine](./chaos_failover_doctrine.md) — [§10](./chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim) the io-sim "Simulate" move this doctrine adopts and completes; the R1–R9 hazards the fault model targets
- [Formal Model Doctrine](./formal_model_doctrine.md) — [§8](./formal_model_doctrine.md#8-trace-validation-the-earlier-codemodel-bridge) trace validation, which first runs against the simulated daemon here
- [Gateway Migration Model Doctrine](./gateway_migration_model_doctrine.md) — the one model whose runtime fidelity DST bridges before Register 3
- [Testing Doctrine](./testing_doctrine.md) — [§2](./testing_doctrine.md#2-the-registers-of-amoebius-testing) owns the register definitions, including Register 2.5
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — the pre-cluster spine this register extends
- [Content Addressing & Determinism Doctrine](./content_addressing_doctrine.md) — the shared determinism substrate (seeds + clock seams)
- [Daemon Topology Doctrine](./daemon_topology_doctrine.md) — [§6](./daemon_topology_doctrine.md#6-the-shared-daemon-spine) the structured-concurrency daemon spine that lifts cleanly onto io-classes
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
