# Consistency, Availability & the PACELC Posture

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_29_gateway_migration_drills.md, documents/engineering/README.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: Single Source of Truth for amoebius's PACELC posture — which consistency / availability /
> latency directions are fixed by construction and which are configurable magnitudes on the one boundary that
> admits a tradeoff (the asynchronous cross-cluster gateway) — and the unified deployment-rules surface that
> carries those magnitudes into the `InForceSpec`.

---

## 1. Why this doctrine exists

**The problem this doctrine prevents.** amoebius has already fixed its position on every PACELC axis (Abadi
2010/2012: under a **P**artition choose **A**vailability or **C**onsistency; **E**lse, in the healthy case,
choose **L**atency or **C**onsistency), but the choices are scattered across five doctrines that never meet.
An author or reviewer asking "under partition, does amoebius choose availability or consistency, and where?"
must reconstruct the answer from R7/R8/R9 ([`chaos_failover_doctrine.md` §13](./chaos_failover_doctrine.md#13-the-supporting-rules--the-conditions-the-moves-need),
[§18](./chaos_failover_doctrine.md#18-the-rules-scale-to-the-boundary)), the `<Planned | Failover>` taxonomy
([`gateway_migration_doctrine.md`](./gateway_migration_doctrine.md)), the consistency-boundary invariant
([`single_logical_data_plane_doctrine.md` §1](./single_logical_data_plane_doctrine.md#1-why-this-doctrine-exists-two-ways-to-say-run-this-elsewhere)),
fail-closed Vault ([`vault_pki_doctrine.md`](./vault_pki_doctrine.md)), and the odd-quorum union
([`cluster_topology_doctrine.md`](./cluster_topology_doctrine.md)). No document states which leg is fixed and
which is an operator magnitude. The defect surfaces at author time (a spec author reaches for a knob that does
not exist, e.g. an in-cluster "eventual" consistency level) and at review time (a reviewer cannot tell whether
a proposed knob would re-admit a CAP-impossible state). `chaos_failover_doctrine.md` records "PACELC: async
posture chosen" in its cross-boundary ledger, but the whole-stance statement has no home.

**Why the obvious alternatives fail.** Hardcoding the entire posture with no surface contradicts R9, which
requires the data-loss and recovery budgets to be **declared as deployment-rules values** — amoebius has no
basis to pick a given business's tolerance for lost work
([`chaos_failover_doctrine.md` §18](./chaos_failover_doctrine.md#18-the-rules-scale-to-the-boundary)).
Exposing a general "consistency level" knob fails the opposite way: it re-admits the states physics and the
delegated substrates forbid — a strongly-consistent store spanning two clusters, a synchronous cross-cluster
write, an even-quorum control plane, a plaintext-fallback Vault — breaking the "if it decodes, it is
deployable" contract ([`dsl_doctrine.md`](./dsl_doctrine.md)).

**The chosen rule.** amoebius applies R7's classification once, per boundary
([`chaos_failover_doctrine.md` §13](./chaos_failover_doctrine.md#13-the-supporting-rules--the-conditions-the-moves-need)):
it **fixes the direction of every PACELC leg by construction**, and **exposes only the magnitudes and topology
of the single boundary that genuinely trades consistency for availability — the asynchronous cross-cluster
gateway**. The direction is doctrine; the magnitudes are the operator's. (Shorthand: amoebius fixes the shape,
the operator sets the scalars.)

**What it forecloses.** A per-deployment choice of consistency *direction*. An operator cannot weaken
in-cluster consistency, make the cross-cluster link synchronous, or select availability-first as a standing
posture; the only levers are the failover budgets, the pairing topology, and whether an app's data plane
participates in a geo-replicated pair ([§3](#3-the-one-configurable-axis--the-deployment-rules-pacelc-surface)).
The residual tension, stated honestly ([§4](#4-honesty-proven--tested--assumed)): the surface proves a budget
is *declared and bounded*, never that the running system *meets* it.

---

## 2. The R7 classification, applied once per boundary

Each leg's normative rule stays with its owning doctrine; this section states the posture and cites — it never
restates ([`documentation_standards.md` §5](../documentation_standards.md#5-duplication-rules)).

| PACELC leg | Direction (fixed) | Foreclosure of the alternative | Owning doctrine |
|---|---|---|---|
| **In-cluster** (P and E) | **Consistency** (PC/EC), delegated to MinIO / Pulsar-BookKeeper / Patroni Postgres / etcd | No arm weakens it — there is no in-cluster consistency-level field | [`single_logical_data_plane_doctrine.md` §1](./single_logical_data_plane_doctrine.md#1-why-this-doctrine-exists-two-ways-to-say-run-this-elsewhere) |
| **Vault** (P) | **Consistency over Availability** (fail-closed) | No plaintext-fallback constructor — a sealed Vault bricks the cluster | [`vault_pki_doctrine.md`](./vault_pki_doctrine.md) |
| **Control-plane quorum** (E) | **Consistency** at a bounded write-latency cost | Closed odd-quorum union `<Single \| Ha3 \| Ha5>`; even/zero split-brain has no arm | [`cluster_topology_doctrine.md`](./cluster_topology_doctrine.md) |
| **Cross-cluster** (E) | **Latency** — asynchronous replication only | No synchronous-strong cross-cluster arm; sync cross-cluster RPC is anti-doctrinal | [`chaos_failover_doctrine.md` Appendix B](./chaos_failover_doctrine.md#appendix-b--worked-example-fenced-cross-cluster-geo-replication-failover-the-open-cross-cluster-failover-question), [`network_fabric_doctrine.md`](./network_fabric_doctrine.md) |
| **Cross-cluster gateway** (P) | **Availability-first**, bounded and self-healing | The one boundary amoebius owns; realized as `<Planned \| Failover>` | [`chaos_failover_doctrine.md` §13](./chaos_failover_doctrine.md#13-the-supporting-rules--the-conditions-the-moves-need) (R7) + [`gateway_migration_doctrine.md`](./gateway_migration_doctrine.md) |
| **Cross-cluster cold-DR seed** (P) | **Consistency over Availability** — a `ColdSeedFromBackup` secondary stays down until its seeded state is proven fresh | No availability-first arm; the gateway-take guard admits only a proven-fresh seed ([§3.7](#37-the-cold-dr-seed-recovery-source)) | [`backup_recovery_doctrine.md` §8](./backup_recovery_doctrine.md#8-the-gateway-dovetail-seed-from-backup-under-consistency-over-availability) + [`gateway_migration_model_doctrine.md`](./gateway_migration_model_doctrine.md) |

The first four rows are fixed because their alternative is either **physics** (one strongly-consistent store
cannot span two clusters without unbounded latency or divergence — a realtime hop cannot pay cross-cluster RTT
per publish) or a **security invariant** (an available-while-sealed Vault would serve or fabricate secrets).
The fifth row is the only PACELC leg an `InForceSpec` parameterizes, and it parameterizes **magnitude**, not
direction: the direction (availability-first, bounded) is R7-fixed; the operator declares how much staleness
and downtime the boundary may cost.

---

## 3. The one configurable axis — the deployment-rules PACELC surface

This is the only PACELC surface an `InForceSpec` carries. It is a **deployment rule** — how robustly an app's
data plane runs — never app logic ([`app_vs_deployment_doctrine.md`](./app_vs_deployment_doctrine.md)). The
cross-cluster budget and pairing are a **parent-owned forest relation** on the `RootInForceSpec`, projected
read-only into each `ChildInForceSpec`; the per-app knob carries only a participation flag.

### 3.1 The shape-vs-scalar rule

amoebius fixes the shape; the operator sets bounded scalars. Every scalar is a refined non-zero `Quantity`
([`resource_capacity_doctrine.md`](./resource_capacity_doctrine.md)) with **no unbounded arm**, mirroring the
closed `StorageBudget` idiom that has no keep-forever constructor. The presence and finiteness of a budget are
doctrine; only its number is the operator's.

### 3.2 The typed surface (Dhall)

```dhall
let PosDuration = …            -- smart ctor rejects 0 and enforces an upper cap at decode (reuses Quantity)

-- R8: the replication lag is a STANDING synchrony premise on the live pairing — named, bounded, monitored,
-- and the gate on the fail-closed freshness promotion. It is NOT specific to a failover event.
let ReplicationLink = { lagBound : PosDuration }

-- R9: the recovery-time bound is the one budget dimension specific to the failover event.
-- The data-loss window (RPO) is DERIVED, not authored: dataLossWindow := link.lagBound
-- (the R9 rule: the loss window "is the R8 replication-lag bound at the instant of failover,
--  not a separately-derived quantity").
let FailoverBudget = { rto : PosDuration }

-- Parent-owned, cluster-pair-scoped forest relation (RootInForceSpec), projected READ-ONLY into children.
-- The relation shape { active, standby, dnsRecord, hubRole } is owned by gateway_migration_doctrine.md;
-- this surface gathers it with the R8 link and the R9 budget. There is NO `mode` field — the Planned/Failover
-- distinction is an event classified at the gateway-change edge, not authored desired state (§3.4).
let GatewayFailover =
      { active    : ClusterId
      , standby   : ClusterId       -- decode folds: active ≠ standby, and no cluster reused as active/standby
                                     --   across two dnsRecords (resource independence) (§3.3)
      , dnsRecord : DnsName
      , hubRole   : HubRole
      , dnsTtl    : PosDuration      -- must already be low; bounds the client-rebind split window
      , link      : ReplicationLink  -- R8 standing lag bound
      , budget    : FailoverBudget   -- R9 RTO; loss window := link.lagBound
      }

-- Per-app deployment knob: ONLY whether this app's data plane joins the parent-owned geo-replicated pair.
let Distribution = < SingleCluster | GeoReplicated >
```

### 3.3 The IR and its decode-foreclosures (Haskell, Gate 2)

```haskell
-- Ownership index (a phantom parent-scope tag): a child cannot author the pairing — the same
-- ownership-index / phantom-tag technique that indexes DataPlane c and Ref t.
data Scope = Parent | Child
data GatewayFailover (s :: Scope) where
  MkGatewayFailover :: … -> GatewayFailover 'Parent   -- projected read-only into a ChildInForceSpec as a handle

-- The migration mode is an EVENT classified at the gateway-change edge from observed world state,
-- never a decoded field (§3.4). Honesty: Planned's RPO=0 rides a runtime-observed CaughtUpWitness,
-- NOT a constructive type-level proof (§4).
data MigrationMode = Planned | Failover
```

Three total decode-time folds (`Dhall.inputFile auto -> Either DecodeError`): (a) **`active ≠ standby`**
distinctness — the weaker floor `mkRke2` already uses to reject a reused host
([`cluster_topology_doctrine.md`](./cluster_topology_doctrine.md)); a degenerate one-cluster "geo pair" owing
a budget but crossing no boundary is rejected. (b) **`GeoReplicated` ⇒ the app's parent owns a
`GatewayFailover` relation** — an app cannot elect geo-replication into a pairing that does not exist. (c)
**resource independence** — no cluster is reused as `active` or `standby` across two `dnsRecord`s. This is the
strict reading of the structural-fit fold's independence predicate
([`gateway_migration_model_doctrine.md §5`](./gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)):
a shared survivor would rest on the assumed shared-resource premise, so the fold admits only what the scope-2
proof reaches, and the excluded shared-survivor topology is a deferred obligation catalogued at
[`illegal_state_multicluster.md §3.52`](../illegal_state/illegal_state_multicluster.md#352-a-gateway-failover-graph-reusing-one-cluster-across-two-dns-records).

### 3.4 The mode is world-triggered, not authored

`Planned` and `Failover` are not a defaultable posture an operator selects; they are an event classification
keyed on the trigger. `Planned` is the both-clusters-up coordinated handover an operator initiates by editing
the parent-owned pairing (or that a `ScalingPolicy` initiates on a home→cloud move); `Failover` is the
automatic, availability-first response to a vanished active gateway. The relation carries no `mode` field, so
"a standing `InForceSpec` that authors an emergency `Failover` as desired state" has no representable path, and
an operator can never select availability-first on a change a lossless `Planned` handover could serve. The
guarantee mapping is owned by
[`gateway_migration_doctrine.md` §1](./gateway_migration_doctrine.md#1-why-this-doctrine-exists).

### 3.5 The upload-time feasibility push-back

The `PosDuration > 0` refinement is a cheap conservative pre-check, **not** the foreclosure of a
physically-unsatisfiable budget: a 1 ms declared window against a 500 ms live replication lag is as
unsatisfiable as 0 ms, yet decodes. The genuine gate is an **upload-time push-back**: the `dhall update`
endpoint refuses a root `InForceSpec` whose declared `lagBound` / budget cannot hold against the monitored
live lag — the same refuse-on-unsatisfiable posture the reconciler applies to a capacity-infeasible spec
([`cluster_lifecycle_doctrine.md`](./cluster_lifecycle_doctrine.md)). This is a **hybrid decode+runtime**
foreclosure (the declared budget is decode-checked for shape; its feasibility is checked against a monitored,
therefore **assumed**, live signal), not a type-level impossibility, and it is stated as such per
[§4](#4-honesty-proven--tested--assumed). RPO=0 stays reachable through `SingleCluster` (no async boundary) or
the `Planned` caught-up handover, never through a `Failover` budget.

One relation on this surface **is** statically checkable and is therefore a genuine **decode fold**, not a
runtime push-back: the failover `rto` must exceed the client-rebind floor — `dnsTtl` plus a
failure-detection budget plus a DNS-propagation budget. A spec whose `rto < dnsTtl` (or whose `rto` is below
that sum) is statically unsatisfiable — a survivor cannot be rebindable within the RTO if clients cannot even
re-resolve within it — and the decoder rejects it at Gate 2, the same shape as the capacity fold, before any
live signal is consulted (the illegal state is [illegal_state_multicluster.md](../illegal_state/illegal_state_multicluster.md)).
It shares the capacity fold's *total checked-rejection* technique, not its locus: this local scalar relation is
Gate 2, whereas whole-deployment capacity is post-bind `provision-seal`.
This complements the `lagBound` feasibility push-back above, which needs a monitored signal; the
`rto ≥ dnsTtl + headroom` relation needs none. The premise that clients and resolvers actually **honor the
record TTL** — JVM/OS resolver caches, clamping resolvers, and pinned connections can all exceed it — is a
named **R8 assumed** premise, monitored, never proven by the fold.

### 3.6 The cross-boundary disposition

A mutable multi-record invariant that crosses the boundary active-active carries a disposition drawn from a
closed union, defaulting an unclassified invariant to non-confluent held by bounded authority
([`chaos_failover_doctrine.md` §17](./chaos_failover_doctrine.md#17-the-boundary-and-its-classifier)):

```dhall
let CrossBoundaryDisposition =
      < SingleWriter
      | Escrow            : { allowance : Quantity }
      | DisjointNamespace : { block : IdBlock }
      | Downgrade
      | Restructure
      >   -- NO operator-authorable `Confluent` arm; NO raw active-active arm.
```

There is deliberately no operator-authorable `Confluent` arm. Confluence — closed-under-merge — is a
**proven, design-time property**, undecidable in Dhall; a spec that labelled a genuinely non-confluent
invariant (a global floor, global uniqueness, a sum-to-whole) as confluent would decode cleanly and then
diverge under merge, breaking "if it decodes, it is deployable". The confluent classification is therefore
carried by the model, not the spec; the spec's authorable arms are the bounded-authority mechanisms only.

### 3.7 The cold-DR seed recovery source

The `<Planned | Failover>` taxonomy assumes the standby is already deployed and asynchronously replicating.
A distinct case is the down-primary recovery where the secondary is **not deployed until needed** and must be
seeded from backups ([`backup_recovery_doctrine.md`](./backup_recovery_doctrine.md)). This surface carries the
recovery-source choice as a per-pairing deployment rule:

```dhall
let RecoverySource =
      < WarmReplica                                              -- a standby already deployed + async-replicating
      | ColdSeedFromBackup : { backup : BackupPolicyRef, freshnessBound : PosDuration }
      >
```

- **The posture is consistency over availability.** A `ColdSeedFromBackup` secondary is stood up on demand,
  its fresh backing seeded from the latest `Verified` `BackupArtifact`, and it may take the wild-ingress
  gateway **only** after its seeded state is proven fresh within `freshnessBound`. If freshness cannot be
  proven, the pairing stays down rather than serving stale data — the opposite choice from `Failover`'s
  availability-first bounded divergence. This is the `NoTakeWithoutProvenFreshness` guarantee owned by
  [`gateway_migration_model_doctrine.md`](./gateway_migration_model_doctrine.md).
- **The mode is world-triggered, not authored.** The `Seed` recovery is an event classified at the recovery
  edge when a `ColdSeedFromBackup` standby must come up, never a `mode` field on desired state — the same
  rule as [§3.4](#34-the-mode-is-world-triggered-not-authored).
- **`freshnessBound ≥ cadence` is a decode fold.** A `freshnessBound` below the backup `cadence` is statically
  unsatisfiable — a seed can never be fresher than the newest generation — and is rejected at Gate 2, the same
  total checked-rejection shape as the [§3.5](#35-the-upload-time-feasibility-push-back) `rto ≥ dnsTtl + headroom`
  relation, before any live signal is consulted.

The `BackupPolicy` surface, the verified `BackupArtifact`, and the seed enactment are owned by
[`backup_recovery_doctrine.md`](./backup_recovery_doctrine.md); this surface owns only the `RecoverySource`
deployment rule and the consistency-over-availability posture it selects.

---

## 4. Honesty (proven / tested / assumed)

Per the proven/tested/assumed discipline
([`documentation_standards.md` §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)):

- **The type proves a budget is declared and bounded, never met.** The surface makes an unbounded or absent
  failover budget unrepresentable; it cannot prove the field lag stays within the declared `lagBound`.
- **`lagBound` and the derived RPO window are `assumed`** — named, bounded, and monitored (the observed maximum
  is exported), never proven, under real disaster; **RTO is `tested`** — validated by failover drill, not
  assertion (R8/R9, [`chaos_failover_doctrine.md` §18](./chaos_failover_doctrine.md#18-the-rules-scale-to-the-boundary)).
- **`Planned`'s RPO=0 is a `runtime-observed` caught-up edge, not a constructive proof** — the ordering is
  type-foreclosed, but the caught-up edge is observed at reconcile time
  ([`gateway_migration_doctrine.md` §6](./gateway_migration_doctrine.md#6-honesty-and-layer-markers)).
- **The async cross-cluster posture is the recorded price**, not a defect: synchronous cross-cluster
  replication would pay cross-cluster RTT per publish
  ([`chaos_failover_doctrine.md` Appendix B](./chaos_failover_doctrine.md#appendix-b--worked-example-fenced-cross-cluster-geo-replication-failover-the-open-cross-cluster-failover-question)).
- Everything here is **design intent** (Phase 0). The Dhall types land at Gate 1 (`dhall type`) and the
  GADT-indexed decoder + folds at Gate 2; the upload-time feasibility push-back and the availability-first
  failover are the one cross-cluster proof obligation. Phase order and status live only in
  [`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md).

---

## 5. Boundaries this doc owns vs defers

| Owned here (SSoT) | Owned elsewhere (referenced) |
|---|---|
| The whole-stance PACELC posture statement (the [§2](#2-the-r7-classification-applied-once-per-boundary) four-leg table) | Each leg's normative rule — the consistency boundary, fail-closed Vault, the odd quorum, the async substrate — stays with its owner |
| The **unified deployment-rules PACELC surface** ([§3](#3-the-one-configurable-axis--the-deployment-rules-pacelc-surface)): the `ReplicationLink` / `FailoverBudget` / `Distribution` types and the derived-RPO rule | The `GatewayFailover` pairing relation shape and the `<Planned \| Failover>` taxonomy → [`gateway_migration_doctrine.md`](./gateway_migration_doctrine.md) |
| That the mode is world-triggered, not an authored field ([§3.4](#34-the-mode-is-world-triggered-not-authored)) | R7/R8/R9, the I-confluence classifier, and the failover proof obligation → [`chaos_failover_doctrine.md` §13](./chaos_failover_doctrine.md#13-the-supporting-rules--the-conditions-the-moves-need), [§16–§19](./chaos_failover_doctrine.md#16-the-second-axis--when-one-cluster-becomes-a-forest) |
| The upload-time feasibility push-back as a hybrid decode+runtime gate ([§3.5](#35-the-upload-time-feasibility-push-back)) | The refuse-on-unsatisfiable reconciler posture it mirrors → [`cluster_lifecycle_doctrine.md`](./cluster_lifecycle_doctrine.md) |
| The no-`Confluent`-arm rule on the authorable disposition ([§3.6](#36-the-cross-boundary-disposition)) | The confluence classification itself (a model obligation) → [`chaos_failover_doctrine.md` §17](./chaos_failover_doctrine.md#17-the-boundary-and-its-classifier) |

---

## Cross-references

- [`chaos_failover_doctrine.md`](./chaos_failover_doctrine.md) — R7/R8/R9, the Second-Axis classifier, and the availability-first posture this doc states once.
- [`gateway_migration_doctrine.md`](./gateway_migration_doctrine.md) — the `<Planned \| Failover>` taxonomy and the parent-owned `GatewayFailover` relation this surface gathers.
- [`single_logical_data_plane_doctrine.md`](./single_logical_data_plane_doctrine.md) — a cluster is *the* consistency boundary (the in-cluster leg).
- [`vault_pki_doctrine.md`](./vault_pki_doctrine.md) — fail-closed Vault (the secrets-root leg).
- [`cluster_topology_doctrine.md`](./cluster_topology_doctrine.md) — the closed odd-quorum `Rke2Servers` union (the control-plane leg).
- [`app_vs_deployment_doctrine.md`](./app_vs_deployment_doctrine.md) — the PACELC surface is a deployment rule, never app logic.
- [`resource_capacity_doctrine.md`](./resource_capacity_doctrine.md) — the refined non-zero `Quantity` / no-unbounded-arm budget idiom this surface mirrors.
- [`network_fabric_doctrine.md`](./network_fabric_doctrine.md) — the no-synchronous-cross-cluster-RPC verdict behind the fixed Else=Latency leg.
- [`cluster_lifecycle_doctrine.md`](./cluster_lifecycle_doctrine.md) — the refuse-on-unsatisfiable push-back the feasibility gate mirrors.
- [`dsl_doctrine.md`](./dsl_doctrine.md) — the `InForceSpec` surface and the "if it decodes, it is deployable" contract.
- [`illegal_state_multicluster.md`](../illegal_state/illegal_state_multicluster.md) — the PACELC illegal states this posture forecloses (§3.47–§3.51).
- [Development Plan](../../DEVELOPMENT_PLAN/README.md) — phase order, status, and the cross-cluster proof obligation.
- [Documentation Standards](../documentation_standards.md) — header, SSoT, and the proven/tested/assumed honesty rule.
</content>
</invoke>
