# Later Phases

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/resource_capacity_doctrine.md
**Generated sections**: none

> **Purpose**: The candidate pool of in-scope, high-numbered phases that are real commitments but do not
> yet warrant their own `phase_NN_<slug>.md` — each a one-line scope and a provisional gate, all 📋 Planned
> design intent until promoted to a numbered phase.

---

Phases 0–43 each own a dedicated `phase_NN_<slug>.md`. Everything past Phase 43 is *in scope* but not yet
detailed: the README phase index lists it as the single row **`44+ — Later phases`**. This document is that
row, expanded into a candidate pool.

Read it as a **backlog of confirmed-but-unscheduled work**, governed by the same disciplines as the rest of
the suite:

- **All 📋 Planned, all design intent.** Nothing here is implemented; every scope line and every gate is a
  target shape, never a tested amoebius result (honesty rule,
  [development_plan_standards.md §K](development_plan_standards.md#k-honesty-proven--tested--assumed)). Where a candidate leans on the sibling
  prodbox or hostbootstrap projects, that is *sibling evidence*, not amoebius proof.
- **Promotion means a contiguous number.** When a candidate is picked up, it is appended as the next
  `phase_NN_<slug>.md` with a full skeleton ([development_plan_standards.md §D](development_plan_standards.md#d-the-per-phase-document-skeleton)),
  a concrete single-substrate gate ([§L](development_plan_standards.md#l-one-substrate-discipline)), and a contiguous id — Phase 44, 45,
  … with no gaps or fractional ids ([§E](development_plan_standards.md#e-one-canonical-phase-model)). The provisional numbers below are
  *ordering hints only*; the real id is assigned at promotion.
- **No forward dependencies.** A later phase consumes earlier phases; nothing in Phases 0–43 is allowed to
  declare a `Blocked by` that points here ([§E](development_plan_standards.md#e-one-canonical-phase-model)). These candidates sit strictly
  *after* the live-SPA-deploy gate of Phase 43.
- **One substrate per gate.** Each candidate names at most one provisional acceptance substrate; a candidate
  that would need more than one is split before promotion ([§L](development_plan_standards.md#l-one-substrate-discipline)).

The candidates are independent of one another and may be promoted in any order relative to each other; the
provisional ids reflect a *likely* sequencing, not a dependency chain.

---

## Candidate phase: GHC 9.14.1 toolchain bump

**Status**: 📋 Planned (provisional Phase 44)
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

**Status**: 📋 Planned (provisional Phase 45)
**Provisional substrate**: linux-cpu
**Scope** (one line): a typed, ordered, idempotent schema-migration engine for the Patroni-via-Percona
Postgres clusters, unified with a precise account of what a *manifest change* means when the desired object
already exists in etcd (patch vs. immutable-field recreate vs. forbidden destructive change).
**Provisional gate**: an `InForceSpec` topology that evolves an app's declared schema across two revisions migrates
a populated database forward idempotently (re-apply is a no-op), and a manifest change touching an immutable
field is reconciled by the typed diff with **zero silent data loss**.

The reconcile half of this is a hardening of the typed reconciler's state model:
[`manifest_generation_doctrine.md` §6 — the reconcile state model (desired is the pure
`bind/expand → plan/resolve infrastructure → provision → renderAll` result for the authenticated
materialization, observed is
etcd, a diff is typed)](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed)
already frames the diff as a *typed* value; this candidate extends that diff to classify schema-affecting and
immutable-field changes so a change that would otherwise drop rows cannot be applied as a silent replace. The
database half adds the migration ordering and idempotence on top of the per-consumer Postgres model. It is a
later phase because it presupposes a working app-with-Postgres deployment from Phase 27 and the storage-safety
guarantees from Phase 42 (durable bytes are not destroyed under normal credentials) — a schema migration must
move data *without* representing destruction.

**Folded into the release lifecycle (forward pointer).** The migration half of this candidate is now positioned
as a *phase of the delivery doctrine* rather than a standalone engine: a DB-schema migration is a
**`RolloutPhase`** — an ordered, readiness-gated phase obeying create-new → verified-migrate → retire-old,
enacted as one step of a `RolloutPlan` on the in-cluster SSA/ApplySet reconciler
([`release_lifecycle_doctrine.md` §5 — `RolloutPlan` / `RolloutPhase`](../documents/engineering/release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply)).
Its "zero silent data loss" gate is exactly the `storage_lifecycle` create-new→migrate→retire discipline carried
on that phase, so the migration *ordering + idempotence* work belongs to the release rollout, not to a separate
mechanism. The manifest-change-correctness half stays as stated — the hardening of the typed reconcile diff
([`manifest_generation_doctrine.md` §6, above](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderallprovisionedspec-observed-is-live-inventory-actions-are-typed)) — because a typed diff that refuses a destructive
immutable-field replace is a precondition the `RolloutPlan`'s phases depend on. This remains 📋 Planned design
intent: jitML's `Bootstrap.hs` schema-grant pre/post-migration phase is *sibling evidence* that the phased shape
runs in a sibling, not an amoebius result.

## Candidate phase: Haskell extension DSL + custom AST checker + native JIT

**Status**: 📋 Planned (provisional Phase 46)
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

## Candidate phase: Niche substrate — dual-boot same-cluster

**Status**: 📋 Planned (provisional Phase 47)
**Provisional substrate**: windows.
**Scope** (one line): admit a *dual-boot, same-cluster* host into the substrate model.
**Provisional gate**: a dual-boot host joins and rejoins the same cluster across an OS switch without
violating the retained-PV rebind guarantees.

This is deferred because it probes the edge of one locked invariant. The substrate
model treats the substrate as a *fact about the host, not a knob*
([`substrate_doctrine.md` §1 — the substrate is a fact about the host, not a knob](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob));
a dual-boot host is a host whose *fact* changes under it, which is exactly the case the detection model does
not yet cover. WireGuard is already adopted in Phase 31 and the no-Linkerd service-mesh verdict is normative;
neither belongs in this candidate's gate.

## Candidate phase: Surgical proof-assistant track (`emitTLA` faithfulness + fold-closure)

**Status**: 📋 Planned (provisional Phase 48)
**Provisional substrate**: none (a pure-proof track, validated by the proof checker + the existing suite)
**Scope** (one line): discharge — machine-checked — the **two** load-bearing meta-properties the rest of the
suite currently only *tests*: (a) the `emitTLA`/`interpret` **faithfulness meta-theorem** (each `Expr`/`Temporal`
constructor's `interpret`-denotation equals the TLA+ denotation `emitTLA` targets), and (b) the **fold-closure**
laws (commutativity/associativity/idempotence) for the capacity folds, the Pulsar dedup fold, and the CAS-pointer
merge that the I-confluence ledger rests on.
**Provisional gate**: the two meta-properties are machine-checked green by the chosen proof tool, and a
deliberately broken variant (a mistranslated quantifier in `emitTLA`; a non-commutative merge) fails the check —
after which the corresponding
[`chaos_failover_doctrine.md §19`](../documents/engineering/chaos_failover_doctrine.md#19-the-cross-boundary-ledger-and-conformance-rows)
confluence ledger rows and the
[`formal_model_doctrine.md §4`](../documents/engineering/formal_model_doctrine.md#4-correspondence-by-construction)
faithfulness claim may move from **tested** to **proven**.

This is a **surgical** track, not a broad proof-assistant layer — those two properties are the only places a
proof assistant earns its keep, precisely because they are small, closed, and load-bearing, and are today only
property-tested ([`formal_model_doctrine.md §4`](../documents/engineering/formal_model_doctrine.md#4-correspondence-by-construction); the confluence ledger's own rule that a closure claim "is proof
only when its closure argument is shown"). It is explicitly deferred because it *hardens* claims the Phase-2/3/7
differential and closure property-tests already exercise; the property tests are the affordable first line, and
this candidate upgrades them to proof only where the payoff is a genuine ledger promotion. A first sprint is an
**evaluation**: **Liquid Haskell vs Lean** — Liquid Haskell checks refinement types on the *actual* Haskell and
so introduces no second artifact to drift (the drift the whole `Model`-as-data pattern exists to foreclose),
while Lean/Agda offers a fuller metatheory; the verdict picks the tool the two proofs are written in. A broad
adoption is out of scope by design.

The "one base container with everything" packaging question is sometimes mistaken for deferred work. It is
**not**. It is **resolved and adopted in Phase 18**: every third-party service binary (the registry, MinIO,
Vault, Pulsar, Postgres tooling, a Temurin JRE for the JVM services, …) is baked into the multi-arch base
container, and clusters pull images only from the in-cluster `distribution` registry — never from a public
registry. That is the standing doctrine,
[`image_build_doctrine.md` §2 — the single distribution rule (bake the binaries, build the amoebius image,
pull only in-cluster)](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster),
delivered by [phase_18_base_image_registry.md](phase_18_base_image_registry.md) and
recorded as resolved in the README "Later phases" note. It is named here only to close the question: do not
re-open it as a candidate phase.

---

## Candidate phase: Live backup / restore / cold-DR seed

**Status**: 📋 Planned (provisional Phase 49)
**Provisional substrate**: linux-cpu → provider (the write-but-never-delete cloud credential is enacted on the
provider substrate, as with the durable-EBS create-vs-delete model)
**Scope** (one line): the live enactment of the backup surface — the put-only backup credential, the
copy/verify `Job` that emits a verified `BackupArtifact` to a remote / append-only-WORM / air-gapped medium,
the restore that seeds a fresh coordinate, and the `ColdSeedFromBackup` down-primary drill.
**Provisional gate**: an `InForceSpec` topology backs a durable coordinate up to a bounded medium under a
credential that is denied delete/expire at the cloud API, verifies the artifact, then loses the source backing
and **seeds a fresh secondary from the backup**; the secondary takes the wild-ingress gateway only after its
seeded state proves fresh within `freshnessBound`, and an over-medium backup, an auto-restore from a `Manual`
air-gap medium, and a delete-a-backup attempt each perform zero effects.

The **representation** half of backup is **not** a later phase — like the capacity / bounded-storage discipline
below, it is folded into the pure band: the closed `BackupPolicy` / `BackupMedium` / `WriteRegime` /
`BackupRetention` shapes and the `freshnessBound ≥ cadence` fold land in **Phase 4/5**, the no-overcommit sizing
fold in **Phase 7/10**, the illegal-state corpus (`illegal_state_storage.md` §3.53–§3.68 /
`illegal_state_multicluster.md` §3.69–§3.71) in **Phase 6**, and the `FreshnessWitness` /
`NoTakeWithoutProvenFreshness` guard extending the one formal obligation in **Phase 3**
([`gateway_migration_model_doctrine.md`](../documents/engineering/gateway_migration_model_doctrine.md)). Only
the **live** enactment is this candidate, and its runtime residues distribute to the phases that already own
each substrate: the Vault-Transit envelope to Phase 22, the MinIO remote target to Phase 23, the cross-cluster
cold-seed drill to Phases 32/33, the write-but-never-delete cloud credential to Phase 36, and the air-gap
manual/automatic handling drill to the test-topology harness of Phase 42. The standing doctrine is
[`backup_recovery_doctrine.md`](../documents/engineering/backup_recovery_doctrine.md); the deletion of any
backup remains out of band and outside amoebius automation, exactly as durable-backing reclaim is.

---

## Resolved — *not* a later phase: capacity / topology / bounded-storage type discipline

Foreclosing dysfunctional deployment states — resource overcommit (host / VM / cluster), compute-engine ↔
substrate incompatibility, illegal cluster topology (rke2-on-bare-apple, multi-node kind on two hosts,
multi-node rke2 with fewer hosts than nodes), unbounded storage, un-tiered Pulsar topics, and policy-less
capacity growth — is **not** a new phase. Two honesty layers apply. Closed union and topology shapes with no
illegal constructor are type-foreclosed; quantitative capacity sums, placements, and inventory-dependent
compatibility are total decode/provision checks, never dependent-type proofs. Raw incompatible values may
exist, but `provision` returns `Left` and therefore cannot construct the opaque `ProvisionedSpec`, the sole
deployable representation. The discipline is **folded into Phase 4** for source/schema shapes, **Phase 7** for
the pure fold implementation and generated properties, **Phase 10** for full bind/expansion plus the opaque
provision seal, and **Phase 13** for the closed `renderAll` consumer. None requires an external effect or a
forward live-phase dependency ([development_plan_standards.md §E](development_plan_standards.md#e-one-canonical-phase-model) one-canonical-phase). Its **runtime**
residues distribute to the phases that already own each substrate: the Pulsar two-ceiling offload to Phase
19, the Lima `LinuxHost` witness + host/VM capacity cross-check to Phase 41, live kind topology to Phases
14/28, and the `Managed EKS` arm + `ScalingPolicy` enaction + cloud quota to Phases 34/37. So there is **zero phase renumber**:
the discipline is owned by two new doctrines
([`resource_capacity_doctrine.md`](../documents/engineering/resource_capacity_doctrine.md),
[`cluster_topology_doctrine.md`](../documents/engineering/cluster_topology_doctrine.md)) and catalogued in
[`illegal_state_catalog.md`](../documents/illegal_state/illegal_state_catalog.md) §3.13–§3.22 / §4.6 / §4.7,
delivered without inserting a phase. Named here only to close the question: do not re-open it as a candidate
phase.

Live multi-node rke2 remains **unassigned Phase-N work**: Phases 4–9 define/prove its server/agent topology,
role reserves, and elastic templates, but no current Register-3 gate may claim host admission, join, or
enforcement. Promoting that gate is required before an rke2 mutation continuation exists.

---

## Related Documents

- [README.md](README.md) — the live tracker; the `44+ — Later phases` row this document expands
- [development_plan_standards.md](development_plan_standards.md) — the rulebook (§D skeleton, §E one-phase
  model, §K honesty, §L one-substrate) every candidate obeys at promotion
- [overview.md](overview.md) — target architecture and constraints these candidates extend
- [system_components.md](system_components.md) — target component inventory a promoted candidate adds to
- [substrates.md](substrates.md) — substrate registry; each candidate's provisional substrate is recorded here
  at promotion
- [phase_18_base_image_registry.md](phase_18_base_image_registry.md) — where the "one
  base container with everything" question is resolved (not deferred)
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §8 the extension-DSL forward pointer, §9 the
  deferred GHC 9.14.1 toolchain bump
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — §6 the typed
  reconcile state model the manifest-change correctness candidate extends
- [Image Build Doctrine](../documents/engineering/image_build_doctrine.md) — §2 the baked-binary base
  container (Phase 18, resolved)
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — §1 the substrate-is-a-fact model the
  niche-substrate candidate probes
- [Release Lifecycle Doctrine](../documents/engineering/release_lifecycle_doctrine.md) — §5 `RolloutPlan` /
  `RolloutPhase`, where this backlog candidate's DB schema-migration half is folded into Phase 30 as a
  readiness-gated phase (create-new→verified-migrate→retire-old)
- [Network Fabric Doctrine](../documents/engineering/network_fabric_doctrine.md) — Phase 31 WireGuard and the
  no-Linkerd verdict are resolved inputs, not Phase-41 work
