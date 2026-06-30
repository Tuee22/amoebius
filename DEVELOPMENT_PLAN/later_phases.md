# Later Phases

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, overview.md
**Generated sections**: none

> **Purpose**: The holding pen for the in-scope, high-numbered phases that are real commitments but do not
> yet warrant their own `phase_NN_<slug>.md` — each a one-line scope and a provisional gate, all 📋 Planned
> design intent until promoted to a numbered phase.

---

Phases 0–12 each own a dedicated `phase_NN_<slug>.md`. Everything past Phase 12 is *in scope* but not yet
detailed: the README phase index lists it as the single row **`13+ — Later phases`**. This document is that
row, expanded into a candidate pool.

Read it as a **backlog of confirmed-but-unscheduled work**, governed by the same disciplines as the rest of
the suite:

- **All 📋 Planned, all design intent.** Nothing here is implemented; every scope line and every gate is a
  target shape, never a tested amoebius result (honesty rule,
  [development_plan_standards.md §K](development_plan_standards.md)). Where a candidate leans on the sibling
  prodbox or hostbootstrap projects, that is *sibling evidence*, not amoebius proof.
- **Promotion means a contiguous number.** When a candidate is picked up, it is appended as the next
  `phase_NN_<slug>.md` with a full skeleton ([development_plan_standards.md §D](development_plan_standards.md)),
  a concrete single-substrate gate ([§L](development_plan_standards.md)), and a contiguous id — Phase 13, 14,
  … with no gaps or fractional ids ([§E](development_plan_standards.md)). The provisional numbers below are
  *ordering hints only*; the real id is assigned at promotion.
- **No forward dependencies.** A later phase consumes earlier phases; nothing in Phases 0–12 is allowed to
  declare a `Blocked by` that points here ([§E](development_plan_standards.md)). These candidates sit strictly
  *after* the SPA-composition gate of Phase 12.
- **One substrate per gate.** Each candidate names at most one provisional acceptance substrate; a candidate
  that would need more than one is split before promotion ([§L](development_plan_standards.md)).

The candidates are independent of one another and may be promoted in any order relative to each other; the
provisional ids reflect a *likely* sequencing, not a dependency chain.

---

## Candidate phase: GHC 9.14.1 toolchain bump

**Status**: 📋 Planned (provisional Phase 13)
**Provisional substrate**: none (a toolchain/build-graph change, validated by rebuild + the full suite)
**Scope** (one line): move the single shared pin from GHC **9.12.4** to **9.14.1** across every package, and
re-derive the `allow-newer` set the `dhall` library's transitive deps require on the new compiler.
**Provisional gate**: the whole workspace builds clean on GHC 9.14.1 under the new pin, and every prior
phase's acceptance gate still passes unchanged on the bumped toolchain (no behavioural regression).

The current plan deliberately ships on GHC **9.12.4**, with GHC 9.14.1 marked a *deferred,
later-phase bump* — this is stated as doctrine in the DSL toolchain note,
[`dsl_doctrine.md` §9 — Toolchain note](../documents/engineering/dsl_doctrine.md#9-toolchain-note), and in the
README "Toolchain" line. The bump is its own phase precisely because the binding cost is not the language
version but the Hackage version skew: amoebius decodes Dhall in-process via `Dhall.inputFile auto`, and the
`dhall` library's transitive dependency closure needs an `allow-newer` set that has to be re-pinned and
re-proven on 9.14.1. This candidate owns that re-pin and its validation, not any feature work.

## Candidate phase: DB schema-migration automation + manifest-change correctness semantics

**Status**: 📋 Planned (provisional Phase 14)
**Provisional substrate**: linux-cpu
**Scope** (one line): a typed, ordered, idempotent schema-migration engine for the Patroni-via-Percona
Postgres clusters, unified with a precise account of what a *manifest change* means when the desired object
already exists in etcd (patch vs. immutable-field recreate vs. forbidden destructive change).
**Provisional gate**: an `amoebius.dhall` that evolves an app's declared schema across two revisions migrates
a populated database forward idempotently (re-apply is a no-op), and a manifest change touching an immutable
field is reconciled by the typed diff with **zero silent data loss**.

The reconcile half of this is a hardening of the typed reconciler's state model:
[`manifest_generation_doctrine.md` §6 — the reconcile state model (desired is `render(.dhall)`, observed is
etcd, a diff is typed)](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderdhall-observed-is-etcd-a-diff-is-typed)
already frames the diff as a *typed* value; this candidate extends that diff to classify schema-affecting and
immutable-field changes so a change that would otherwise drop rows cannot be applied as a silent replace. The
database half adds the migration ordering and idempotence on top of the per-consumer Postgres model. It is a
later phase because it presupposes a working app-with-Postgres deployment from Phase 3 and the storage-safety
guarantees from Phase 11 (durable bytes are not destroyed under normal credentials) — a schema migration must
move data *without* representing destruction.

## Candidate phase: Haskell extension DSL + custom AST checker + native JIT

**Status**: 📋 Planned (provisional Phase 15)
**Provisional substrate**: linux-cuda (the JIT path exercises the GPU compute substrate)
**Scope** (one line): the second, *extension* language of the vision — Haskell-as-DSL validated by a custom
AST checker, with full access to the amoebius libraries and a native JIT, into which jitML is absorbed as
amoebius's own JIT.
**Provisional gate**: an extension written in the constrained Haskell surface passes the custom AST checker,
is rejected with a precise diagnostic when it reaches outside the sanctioned API, and a representative ML
extension runs through the amoebius-native JIT (replacing jitML) producing the bit-deterministic result its
determinism contract requires.

This is the explicitly **v2** language. The grand vision draws the line — *"orchestration DSL lives in
.dhall, extension DSL is Haskell that is (a) validated by a custom AST checker, and (b) has access to all
amoebius libraries + jit features"*, and *"jit stuff is probably amoebius v2; v1 can be an orchestrator for
arbitrary containers"*. The DSL doctrine is the SSoT for
the *orchestration* Dhall surface and forwards the extension language to this later phase by name:
[`dsl_doctrine.md` §8 — The Haskell extension DSL (forward pointer only)](../documents/engineering/dsl_doctrine.md#8-the-haskell-extension-dsl-forward-pointer-only).
This candidate is where that forward pointer is redeemed — the custom AST checker, the library-access surface,
and the JIT that subsumes jitML — and it is correctly a later phase because the README treats v1 as a complete
orchestrator for arbitrary containers without it.

## Candidate phase: Niche substrates (dual-boot same-cluster; WireGuard / Linkerd vs Envoy)

**Status**: 📋 Planned (provisional Phase 16)
**Provisional substrate**: windows (the dual-boot case is the substrate-distinguishing one; the mesh
evaluation is substrate-agnostic and rides along)
**Scope** (one line): two niche substrate questions — admitting a *dual-boot, same-cluster* host into the
substrate model, and a designed evaluation of WireGuard / Linkerd against the existing Envoy + Gateway API
path to decide whether either earns a place or is redundant.
**Provisional gate**: a dual-boot host joins and rejoins the same cluster across an OS switch without violating
the retained-PV rebind guarantees; **and** the mesh evaluation lands a written verdict (adopt-with-scope or
reject-as-redundant) backed by a reproducible comparison against the Envoy baseline — not a code merge for its
own sake.

These are deferred because they probe the *edges* of two locked invariants rather than the core. The substrate
model treats the substrate as a *fact about the host, not a knob*
([`substrate_doctrine.md` §1 — the substrate is a fact about the host, not a knob](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob));
a dual-boot host is a host whose *fact* changes under it, which is exactly the case the detection model does
not yet cover. The mesh question probes the single wild-ingress path: Keycloak owns all wild ingress via the
LoadBalancer + Gateway API
([`platform_services_doctrine.md` §9 — the LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)),
so any WireGuard/Linkerd adoption must justify itself *against* that path rather than alongside it — and the
honest default outcome of the evaluation may well be "redundant, do not adopt." Stating the gate as a *verdict*
rather than a feature keeps that outcome admissible.

Cross-cluster failover is especially valuable for a VPN host that flattens the node-network topology: when the
cluster carrying that role fails over, the flattened mesh moves with it, so peers keep a single, stable view of
the network. If first-class VPN/mesh is adopted, the proposed semantics are: the root node deploys an HA
cluster; that cluster configures a WireGuard gateway; every cluster (root included) receives a VPN IP from that
gateway; and a Linkerd service mesh then becomes active across the VPN.

---

## Resolved — *not* a later phase: one base container with everything

The "one base container with everything" packaging question is sometimes mistaken for deferred work. It is
**not**. It is **resolved and adopted in Phase 2**: every third-party service binary (the registry, MinIO,
Vault, Pulsar, Postgres tooling, a Temurin JRE for the JVM services, …) is baked into the multi-arch base
container, and clusters pull images only from the in-cluster `distribution` registry — never from a public
registry. That is the standing doctrine,
[`image_build_doctrine.md` §2 — the single distribution rule (bake the binaries, build the amoebius image,
pull only in-cluster)](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster),
delivered by [phase_02_platform_services_storage_vault.md](phase_02_platform_services_storage_vault.md) and
recorded as resolved in the README "Later phases" note. It is named here only to close the question: do not
re-open it as a candidate phase.

---

## Related Documents

- [README.md](README.md) — the live tracker; the `13+ — Later phases` row this document expands
- [development_plan_standards.md](development_plan_standards.md) — the rulebook (§D skeleton, §E one-phase
  model, §K honesty, §L one-substrate) every candidate obeys at promotion
- [overview.md](overview.md) — target architecture and constraints these candidates extend
- [system_components.md](system_components.md) — target component inventory a promoted candidate adds to
- [substrates.md](substrates.md) — substrate registry; each candidate's provisional substrate is recorded here
  at promotion
- [phase_02_platform_services_storage_vault.md](phase_02_platform_services_storage_vault.md) — where the "one
  base container with everything" question is resolved (not deferred)
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §8 the extension-DSL forward pointer, §9 the
  deferred GHC 9.14.1 toolchain bump
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — §6 the typed
  reconcile state model the manifest-change correctness candidate extends
- [Image Build Doctrine](../documents/engineering/image_build_doctrine.md) — §2 the baked-binary base
  container (Phase 2, resolved)
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — §1 the substrate-is-a-fact model the
  niche-substrate candidate probes
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — §9 the single
  wild-ingress path the WireGuard/Linkerd evaluation measures against
