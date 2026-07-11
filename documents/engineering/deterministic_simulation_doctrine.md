# Deterministic Simulation: the real code, run against a modeled world

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_15_renderer_reconciler.md, DEVELOPMENT_PLAN/phase_17_vault_pki.md, DEVELOPMENT_PLAN/phase_18_platform_services.md, DEVELOPMENT_PLAN/phase_22_pulsar_client.md, DEVELOPMENT_PLAN/phase_23_content_store_workflow.md, DEVELOPMENT_PLAN/phase_24_determinism_kernel.md, DEVELOPMENT_PLAN/phase_29_multicluster_gateway_migration.md, documents/engineering/README.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/conformance_harness_doctrine.md
**Generated sections**: none

> **Purpose**: Single source of truth for **deterministic simulation testing (DST)** in amoebius — running the
> *real* daemon/reconciler code, written once against `io-classes`, under `io-sim`/`IOSimPOR` against a
> **modeled, fault-injectable environment** (fake Pulsar/MinIO/apiserver/route53/Vault/clock), so concurrent
> schedules and environment faults are validated **in-process, deterministically replayable, before any live
> deployment** — and the honest tradeoff this buys: it replaces a large *unvalidated-until-live* surface with a
> small *modeled-environment-fidelity* premise. This is **Register 2.5** of the conformance spine.

---

## 1. Why this doctrine exists

The concurrency-and-failover method ([chaos_failover_doctrine.md §10](./chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim))
adopts io-sim only for the *pure decision core* against hand-built peer stubs (Tier-1, Phase 3) and **defers**
io-sim against the *built daemon* — leaving the daemon's real concurrent schedule, and every interaction with
the real environment (apiserver admission, Pulsar redelivery/partition, DNS propagation, clock skew), to
Register-3 live chaos. Register-3 chaos is the strongest *empirical* instrument but the weakest *logical* one:
it is **sampled** and **late**, and a rare interleaving surfaces once in ten thousand runs, if ever
([chaos_failover_doctrine.md §3](./chaos_failover_doctrine.md#3-the-defect-class--one-shape-two-disguises)).

The industry answer to "make the rare interleaving deterministically reproducible **before** production" is
**deterministic simulation testing** — FoundationDB's *Flow*, TigerBeetle's VOPR, and Antithesis, the peers
`io-sim` was built to be for Haskell (IOG / Well-Typed's `ouroboros-network`). amoebius is unusually
well-positioned to adopt it: the shared daemon spine already forbids `forkIO` and mandates structured
`withAsync`/`bracket` ([daemon_topology_doctrine.md §6](./daemon_topology_doctrine.md#6-the-shared-daemon-spine)),
so the shapes lift cleanly; `render`/`chain` are already pure, so the only effectful surface is a thin,
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

The standing cost is named honestly: making the concurrency-touching signatures polymorphic in `m` is a **tax on
all future change**, not a one-time edit. It is paid deliberately, in exchange for [§5](#5-what-dst-establishes-and-the-one-premise-it-buys).

---

## 3. The simulated environment and its fault model

The marquee limit of a single-daemon io-sim run is that amoebius daemons coordinate through Pulsar + MinIO + the
commit log, **not in-process shared state** ([chaos_failover_doctrine.md §10](./chaos_failover_doctrine.md#10-simulate--the-pure-program-lifted-io-sim)),
so a run rests on stubbed peers. This doctrine's move is to make those substrates **first-class simulated
components with a typed fault model**, rather than inert stubs — the FoundationDB approach. The modeled
environment provides deterministic, in-`IOSim` fakes of:

- **Pulsar** — subscriptions, at-least-once delivery, broker-side dedup, geo-replication; fault knobs: **delay,
  reorder, duplicate, partition (cut a link), broker crash**.
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

---

## 4. Register 2.5 — where deterministic simulation sits

The register *definitions* are owned by [testing_doctrine.md §2](./testing_doctrine.md#2-three-registers-of-amoebius-testing);
this doctrine owns the **shape** of the deterministic-simulation register and how it extends the pre-cluster
spine ([conformance_harness_doctrine.md §4](./conformance_harness_doctrine.md#4-the-spine-decode--validate--render--plan--dry-run)).

- **Register 1 — pure/golden.** Decode → render → plan → dry-run; the formal `Model` explorer + TLC. No effects.
- **Register 2 — boundary integration with fakes.** The real binary over the `[Step]` plan against fake
  subprocess tools recording argv+bytes ([phase_11](../../DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md)).
- **Register 2.5 — deterministic simulation (this doctrine).** The real daemon/reconciler code under
  `IOSim`/`IOSimPOR` against the [§3](#3-the-simulated-environment-and-its-fault-model) modeled environment —
  exercising **concurrent schedules and injected environment faults**, which Registers 1 and 2 structurally
  cannot reach, and which Register 3 reaches only by sampling. Deterministically replayable, no cluster.
- **Register 3 — live infrastructure.** The residue: that the real apiserver/broker/DNS behave as [§3](#3-the-simulated-environment-and-its-fault-model)
  models them; real physics; real chaos.

Register 2.5 is also where **trace validation** ([formal_model_doctrine.md §8](./formal_model_doctrine.md#8-trace-validation-the-earlier-codemodel-bridge))
first runs against the built daemon: the simulated daemon's observed transitions are checked against the emitted
TLA+ `Next` relation, giving the code↔model bridge a deterministic home before Register 3.

---

## 5. What DST establishes, and the one premise it buys

A green DST run is **tested**, not proven: it establishes that *the real code upholds its invariants under the
schedules and faults explored* against the modeled environment. It does **not** establish that the real
Pulsar/apiserver/route53 behave as modeled — that is the boundary [§7](#7-the-boundary--what-stays-register-3)
draws.

The tradeoff is the whole point, and it is honest: DST **replaces** a large *"the code is unvalidated until a
live cluster exists"* surface with a small *"the code is validated against a model of the environment, and the
model's fidelity to the real substrate is assumed"* premise. That is strictly the better place to stand — a
narrow, testable fidelity assumption in place of a broad unverified one — and it matches amoebius's own instinct
everywhere else (make the load-bearing claim small and explicit). The fidelity premise is **discharged, not
waved away**: a small Register-3 **conformance suite** checks each fake's contract against the real system (e.g.
the fake Pulsar's dedup/redelivery semantics against a real broker), and any divergence is a defect in the fake,
recorded in the ledger. Per [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline):
a DST green is quoted as *"the code upholds the invariants under the modeled schedules and faults,"* never as
*"the cluster is correct."*

---

## 6. One determinism substrate, two uses

DST and reproducible ML share **one** determinism substrate. The seed derivation and the `MonadTime`/`MonadTimer`
clock seams that make an ML run bit-reproducible ([content_addressing_doctrine.md](./content_addressing_doctrine.md),
the determinism kernel [phase_24](../../DEVELOPMENT_PLAN/phase_24_determinism_kernel.md)) are the **same** seams
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

## 8. Planning ownership

This document is normative doctrine only. The io-classes environment substrate is built in the pre-cluster
boundary phase ([phase_11](../../DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md)); each concurrency-bearing
live-band phase adds its Register-2.5 validation sprint before its Register-3 gate; the determinism seams are the
[phase_24](../../DEVELOPMENT_PLAN/phase_24_determinism_kernel.md) kernel's. Phase order, status, and gates live
only in [DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md). Every prescriptive statement here is
design intent, never a tested amoebius result.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Chaos & Failover Doctrine](./chaos_failover_doctrine.md) — §10 the io-sim "Simulate" move this doctrine adopts and completes; the R1–R9 hazards the fault model targets
- [Formal Model Doctrine](./formal_model_doctrine.md) — §8 trace validation, which first runs against the simulated daemon here
- [Gateway Migration Model Doctrine](./gateway_migration_model_doctrine.md) — the one model whose runtime fidelity DST bridges before Register 3
- [Testing Doctrine](./testing_doctrine.md) — §2 owns the register definitions, including Register 2.5
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — the pre-cluster spine this register extends
- [Content Addressing & Determinism Doctrine](./content_addressing_doctrine.md) — the shared determinism substrate (seeds + clock seams)
- [Daemon Topology Doctrine](./daemon_topology_doctrine.md) — §6 the structured-concurrency daemon spine that lifts cleanly onto io-classes
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
