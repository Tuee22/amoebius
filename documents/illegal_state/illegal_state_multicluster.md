# Illegal States — Multi-cluster & Fabric

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_topology.md
**Generated sections**: none

> **Purpose**: The themed slice of the illegal-state catalog covering cross-cluster capacity folds,
> stretched host workers / remote agents / member witnesses across the network fabric, and the session
> rebind that survives a gateway migration.

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog: the deep treatment of the multi-cluster and
network-fabric illegal states. It carries only the catalog entries listed in [§2](#2-the-multi-cluster--fabric-illegal-states),
reproduced faithfully with their original numbers and headings.

The surrounding framing is owned elsewhere and is **referenced, not restated** here:

- The **catalog index** (which entries exist, the ordering of the enumeration) and the **honesty limit** (a
  type-check proves the *spec composes*, not that the *running cluster enforces it*) are owned by
  [`illegal_state_catalog.md`](./illegal_state_catalog.md).
- The **seven typing techniques** (§4.1–§4.7 of the catalog), the **coverage matrix**, the **three-layer
  foreclosure** model (`type-foreclosed` / `decode-foreclosed` / `runtime-checked`), and the **validation-locus
  axis** (`Gate-1-editor` / `Gate-2-decoder` / `provision-seal` / `rendered-output-golden` / `live-effect`;
  `provision-seal` is post-bind Phase-8 provision returning a `ProvisionError` before any `ProvisionedSpec`
  exists) are owned by
  [`illegal_state_techniques.md`](./illegal_state_techniques.md).

Each entry below keeps its existing `**Layer:**` foreclosure tag and adds a new `**Validation-locus:**` line —
the orthogonal axis defined in [`illegal_state_techniques.md`](./illegal_state_techniques.md) — naming *where*
the illegal state is caught (at the Dhall editor, in the total decoder, at the post-bind provision seal, in a
golden test on the rendered manifest, or only as runtime residue). As throughout the catalog, everything here is **design intent**: a
type-check proves the specification composes into something internally coherent, not that the running
deployment enforces it (the load-bearing limit owned by [`illegal_state_catalog.md`](./illegal_state_catalog.md) §2).

---

## 2. The multi-cluster & fabric illegal states

### 3.31 A capacity or workload fold spanning two clusters

Distributing one workload across clusters looks like "just fold capacity over both," but
`place :: Topology -> [Workload]` admits exactly **one** `Topology`, and a `Topology` is one cluster
([`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) §4). A multi-cluster / fleet capacity fold
therefore has **no constructor** — the same type-foreclosed "no arm" idiom that forecloses the worker pool as a fourth
`ComputeEngine`. Distributing across clusters is **geo-replication** (N independent clusters, each its own
`place`, related only by async Pulsar replication — outside the single-cluster `place` fold and enacted by
Phase 28); it is **not** the stateless
attach pool, which is single-cluster and already **inside** `place`'s elastic branch
([`single_logical_data_plane_doctrine.md`](../engineering/single_logical_data_plane_doctrine.md) §4 re-runs the same `place`
fold on the enlarged topology) — modeling the attach pool as cross-cluster machinery is the category error §5 of
that doctrine forecloses. A single **stretched** cluster ([§3.35](#335-a-stretched-host-worker-with-no-declared-networking-capability)–[§3.39](./illegal_state_topology.md#339-a-split-site-etcd-quorum))
is the canonical *legal* foil: it is **one** `Topology` whose nodes span two `Site`s and `place` runs **once**;
folding its capacity as *two* `Topology`s is precisely this uninhabitable cross-cluster fold. **Owner:**
[`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) (owns `place` and states the
single-cluster-by-arity non-goal in its own subsection), cross-referencing
[`single_logical_data_plane_doctrine.md`](../engineering/single_logical_data_plane_doctrine.md) for the *why* (a cluster is
the consistency boundary). **Technique:** [§4.7](./illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection)
(the relation/collection is over one cluster's `NonEmpty Node`; a second `Topology` has no place in the fold's
arity). **Layer:** type-foreclosed uninhabitable-by-arity; runtime-checked residue lives only in the deferred geo-replication
enaction (Phase 28).
**Validation-locus:** `Gate-1-editor` (the `place` arity admits exactly one `Topology` — the "no arm" fold shape
has no way to name a second cluster, rejected at authoring by `dhall type`); `live-effect` (the only residue is
the deferred geo-replication enaction, Phase 28).

### 3.35 A stretched host worker with no declared networking capability

A host worker whose declared network-locality `Site` differs from the control plane's is reached across the WAN,
and reaching the data plane (MinIO/Pulsar) + Vault over an untrusted network with no declared secure transport
is the silent-exposure hazard. This round makes a **networking capability mandatory**: the host-worker
attach carrier requires `ewpNetworking :: Networking c = Gateway (SecureGatewayReach c) | Vpn (VpnFabric c)`
(generalizing the already-mandatory `ewpFabric :: VpnFabric c`), so a stretched host worker with **no** declared
`Networking` has **no constructor**. Which path a host worker takes is **fold-derived from its declared `Site`**,
read off the host-worker inventory — `Site = s` → the co-located localhost channel-2 path; `Site ≠ s` → the
stretched attach constructor demanding `Networking c` and minting `FabricMember c` through it — so a caller
**cannot** smuggle a remote worker onto the localhost path. A K1 host worker is control-plane-free and therefore
representable on **any** `ComputeEngine`, including `Managed Eks`. **Owner:**
[`single_logical_data_plane_doctrine.md`](../engineering/single_logical_data_plane_doctrine.md) §4 (the attach carrier +
`ewpNetworking`); the `Networking` sum owned by [`network_fabric_doctrine.md`](../engineering/network_fabric_doctrine.md); the
`Site` axis by [`substrate_doctrine.md`](../engineering/substrate_doctrine.md) §8. **Technique:**
[§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction) (the mandatory `ewpNetworking` field — a carrier without it has no
inhabitant) + [§4.7](./illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) (the
host-worker-inventory `Site` fold routing an off-localhost worker onto the attach path). **Layer:** type-foreclosed
networking-field presence; decode-foreclosed the `Site` fold; runtime-checked residue — the physical link up and the declared `Site`
matching reality (`discover = Unreachable → refuse`).
**Validation-locus:** `Gate-1-editor` (the mandatory `ewpNetworking` field — a required-field carrier without it
fails `dhall type`); `Gate-2-decoder` (the total host-worker-inventory `Site` fold that routes an off-localhost
worker onto the demanding attach constructor); `live-effect` (the physical link actually being up and the
declared `Site` matching reality, `discover = Unreachable → refuse`).

### 3.36 A declared-remote full agent with no control-plane witness

A full k8s node (a kubelet member) whose `Site` differs from the control plane's must reach the one
apiserver/etcd across the WAN; raw tooling permits registering such an agent with no secure control-plane path,
surfacing the split at reconcile. This round's node fold routes a declared-remote (`Site ≠ s_cp`) self-managed-rke2
agent to `mkStretchedAgent`, which **demands** a `ReachesControlPlane c` witness minted **from** the declared
`Networking`'s `VpnFabric` (a rendered `ControlPlanePeer` covering the apiserver VPN-IP + distro-mTLS over the
tunnel). A stretched agent with no control-plane witness has **no constructor**. **Owner:**
[`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) §4.1 (the node fold + `mkStretchedAgent`),
reading the witness minted by [`network_fabric_doctrine.md`](../engineering/network_fabric_doctrine.md). **Technique:**
[§4.7](./illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) (the `NonEmpty Node` `Site` fold)
+ [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked) (the
`render()` that must cover the apiserver VPN-IP) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
(the `ReachesControlPlane c` witness gating). **Layer:** demand decode-foreclosed (the `Site` fold + `render()`); witness
presence type-foreclosed (no off-networking constructor); runtime-checked residue — the kubelet session actually established
over the WAN. This is the prior stretched-cluster witness, now scoped to the **full-node** kind.
**Validation-locus:** `Gate-2-decoder` (the total `NonEmpty Node` `Site` fold routes the declared-remote agent to
`mkStretchedAgent`, whose `render()` must cover the apiserver VPN-IP and whose `ReachesControlPlane c` witness
gate has no off-networking constructor); `live-effect` (the kubelet session actually established over the WAN).

### 3.38 A host worker granted a control-plane witness or treated as a member

The two stretched kinds must not blur — a host worker is a non-member data-plane/Vault client and must never be
handed control-plane reach or counted as a kubelet member. This round's total `witness` fold yields, on its
host-worker arms, **only** `DataPlaneOnly (FabricMember c)`; the `Reach` sum has **no** path taking a
`K1_HostWorker` into `ControlPlaneToo (ReachesControlPlane c)` — no constructor crosses the kinds. **Owner:**
[`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) §4.1 (the `witness` fold) /
[`single_logical_data_plane_doctrine.md`](../engineering/single_logical_data_plane_doctrine.md) §4 (the host worker as
attach-pool client, never a member). **Technique:** [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
(the `Reach` sum's kind-indexed constructors do not interconvert — the host-worker → `ControlPlaneToo` transition
has no constructor) + [§4.7](./illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) (the
per-kind `witness` dispatch). **Layer:** type-foreclosed uninhabitable.
**Validation-locus:** `Gate-2-decoder` (the total per-kind `witness` fold and the kind-indexed `Reach` GADT whose
`K1_HostWorker` arm has no `ControlPlaneToo` constructor — the crossing value never survives decode).

### 3.44 A session that cannot rebind on gateway migration

Raw DNS failover treats a gateway move as "repoint the record and hope": TTL and resolver caching leave a
window in which a live client still resolves the old gateway address, and if the old ingress is hard-stopped a
mid-session client is stranded with no working endpoint. amoebius models a `Planned` gateway migration
([`gateway_migration_doctrine.md`](../engineering/gateway_migration_doctrine.md)) as an **ordered, edge-observed state
machine** — `stand-up-replica → quiesce → drain/verify-caught-up → promote → (old-ingress = proxy + repoint
DNS) → unfreeze → drain-monitor → decommission(old-ingress)` — in which `decommission(old-ingress)` is
reachable **only** from an observed `drain-monitor` edge (old-gateway traffic ≈ 0). No transition removes the
last working endpoint for a live session: while DNS drains, the old gateway survives as a transparent reverse
proxy to the new, and the per-cluster stable address never migrates — so "a session in limbo that cannot
rebind" has no representable path. On the `Failover` path (the active has vanished, no proxy) the guarantee
weakens honestly to bounded rebind: clients error, re-resolve within the already-low TTL, and rebind to the
survivor. **Owner:** [`gateway_migration_doctrine.md`](../engineering/gateway_migration_doctrine.md) (the migration state
machine and the client-rebind protocol). **Technique:** [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
(the migration GADT — the `decommission` handle exists only from a `drain-complete` index). **Layer:**
`type-foreclosed` for the transition ordering (no path decommissions the last endpoint); `runtime-checked`
residue — that the `drain-complete` edge (old-gateway traffic ≈ 0) is truthfully observed, owned by
[`gateway_migration_doctrine.md`](../engineering/gateway_migration_doctrine.md) and
[`readiness_ordering_doctrine.md`](../engineering/readiness_ordering_doctrine.md).
**Validation-locus:** `Gate-2-decoder` (the migration GADT — the `decommission` handle exists only from a
`drain-complete` index, so no path that would strand a live session survives decode); `live-effect` (that the
`drain-complete` edge, old-gateway traffic ≈ 0, is truthfully observed at reconcile time).

### 3.47 A failover data-loss budget authored below the replication-lag bound

Raw failover configuration lets an operator promise a recovery-point objective smaller than the asynchronous
replication lag can actually lose, so the declared budget is a fiction the physics violates at the first
partition: up to a full lag-window of acknowledged-but-un-replicated writes is gone at the instant of failover.
amoebius carries **no independent RPO field**. The data-loss window is derived by construction from the one R8
`lagBound` on the standing `ReplicationLink` — `dataLossWindow := lagBound` — the binding-by-construction idiom
that emits a matched pair from a single declared quantity rather than two fields that can disagree
([`consistency_pacelc_doctrine.md` §3.2](../engineering/consistency_pacelc_doctrine.md#32-the-typed-surface-dhall)).
"An RPO authored below the lag" therefore has no field to write. The residual question — whether the declared
`lagBound` itself holds against the monitored live lag — is not a type fact; it is the upload-time feasibility
push-back ([`consistency_pacelc_doctrine.md` §3.5](../engineering/consistency_pacelc_doctrine.md#35-the-upload-time-feasibility-push-back)),
a hybrid decode+runtime gate. **Owner:** [`consistency_pacelc_doctrine.md`](../engineering/consistency_pacelc_doctrine.md),
realizing R9's rule that the data-loss window *is* the R8 replication-lag bound at the instant of failover, not a
separately-derived quantity ([`chaos_failover_doctrine.md` §18](../engineering/chaos_failover_doctrine.md#18-the-rules-scale-to-the-boundary)).
**Technique:** [§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction) (one `lagBound` emits both
the monitored premise and the derived loss window; there is no separate RPO field to under-declare). **Layer:**
`type-foreclosed` for the absent below-lag field; `runtime-checked` residue — the declared `lagBound` holding
against monitored live lag (the feasibility push-back).
**Validation-locus:** `Gate-1-editor` (there is no RPO field to set below the lag); `live-effect` (the
upload-time push-back of the declared bound against monitored lag).

### 3.48 A geo-replication pair whose active and standby are the same cluster

A failover pairing that names one cluster as both `active` and `standby` crosses no asynchronous boundary yet
owes a failover budget — a degenerate "geo pair" raw configuration admits, and whose failover can never execute
because there is no second cluster to promote. amoebius rejects `active == standby` on the parent-owned
`GatewayFailover` relation with a total decode-time distinctness fold — the weaker floor `mkRke2` applies to
reject a reused host across `servers ∪ agentFloor` (fixed agents, or the concrete floor of an autoscaled pool)
([`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md)). **Owner:**
[`consistency_pacelc_doctrine.md` §3.3](../engineering/consistency_pacelc_doctrine.md#33-the-ir-and-its-decode-foreclosures-haskell-gate-2),
cross-referencing the parent-owned relation of [`gateway_migration_doctrine.md` §6](../engineering/gateway_migration_doctrine.md#6-honesty-and-layer-markers).
**Technique:** [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally) (the
value-level distinctness fold, the same shape as the rke2 host-distinctness check of
[§3.16](./illegal_state_topology.md#316-a-multi-node-rke2-cluster-with-fewer-linux-hosts-than-nodes-or-a-host-reused)).
**Layer:** `decode-foreclosed` (a total decode-time rejection of a constructible value).
**Validation-locus:** `Gate-2-decoder` (the total `active ≠ standby` fold returns `Left`).

### 3.49 A child spec that authors its own gateway-failover pairing

The failover pairing is a forest relation with two endpoints (an `active` and a `standby` cluster); raw
configuration would let a child author a pairing naming a sibling or ancestor, minting cross-cluster authority a
single child cannot own — the same class as a child spec reaching beyond its subtree
([§3.10](./illegal_state_security.md#310-a-child-spec-that-reaches-beyond-its-own-subtree)). amoebius makes the
`GatewayFailover` relation a parent-scope-indexed value (a phantom `Scope` tag) in the `RootInForceSpec`,
projected read-only into a `ChildInForceSpec` as a handle; a child has no constructor that produces one — the
derive-don't-author, relations-owned-by-the-enclosing-scope pattern the fabric peer graph uses. **Owner:**
[`gateway_migration_doctrine.md` §6](../engineering/gateway_migration_doctrine.md#6-honesty-and-layer-markers)
(the parent-owned relation), typed on the surface of
[`consistency_pacelc_doctrine.md` §3.3](../engineering/consistency_pacelc_doctrine.md#33-the-ir-and-its-decode-foreclosures-haskell-gate-2).
**Technique:** [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally)
(parent-scope ownership index) + [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(the phantom `Scope` tag). **Layer:** `type-foreclosed` uninhabitable (a child has no constructor for the
parent-scoped relation).
**Validation-locus:** `Gate-2-decoder` (the parent-scope-indexed handle has no child-authored inhabitant that
survives decode).

### 3.50 A standing spec that authors an emergency `Failover` as desired state

Treating a gateway change as a free choice of posture, raw configuration would let an operator declare "prefer
`Failover` / availability-first" as standing desired state on any gateway change — licensing an availability-first
cutover, with its bounded data loss, where a lossless `Planned` handover was possible, and encoding a mode a live
source cannot execute (a `Failover` has no quiesce/drain). amoebius carries **no `mode` field** on the
`GatewayFailover` relation; `Planned` and `Failover` are an event classified at the gateway-change edge from
observed world state — both clusters up (author- or `ScalingPolicy`-driven) yields `Planned`, a vanished active
yields the automatic, availability-first `Failover`
([`gateway_migration_doctrine.md` §1](../engineering/gateway_migration_doctrine.md#1-why-this-doctrine-exists)).
A standing spec that authors an emergency `Failover` has no field to write. **Owner:**
[`consistency_pacelc_doctrine.md` §3.4](../engineering/consistency_pacelc_doctrine.md#34-the-mode-is-world-triggered-not-authored)
+ [`gateway_migration_doctrine.md` §1](../engineering/gateway_migration_doctrine.md#1-why-this-doctrine-exists).
**Technique:** [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
(the mode is an observed edge in the migration state machine, not a decoded field) +
[§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction) (no authored `mode` field on the relation).
**Layer:** `type-foreclosed` for the absent field; `runtime-checked` residue — the trigger edge (active
reachable vs vanished) observed at reconcile time.
**Validation-locus:** `Gate-1-editor` (there is no `mode` field to author); `live-effect` (the trigger edge
observed at the gateway-change moment).

### 3.51 An operator-authored `Confluent` cross-boundary disposition

Raw configuration would let an operator label a genuinely non-confluent cross-cluster invariant — a global
floor, global uniqueness, or a sum-to-whole — as "confluent", so it is merged active-active and diverges; the
false claim type-checks, because confluence (closed-under-merge) is undecidable in Dhall. amoebius's authorable
`CrossBoundaryDisposition` union has **no `Confluent` arm**: an unclassified mutable multi-record invariant folds
to non-confluent held by bounded authority, and the authorable arms are the bounded-authority mechanisms only
(single-writer, escrow, disjoint-namespace, downgrade, restructure). The confluent classification is a proven,
design-time model property carried by the model, never a spec value
([`consistency_pacelc_doctrine.md` §3.6](../engineering/consistency_pacelc_doctrine.md#36-the-cross-boundary-disposition)).
**Owner:** [`consistency_pacelc_doctrine.md` §3.6](../engineering/consistency_pacelc_doctrine.md#36-the-cross-boundary-disposition),
realizing the I-confluence classifier of [`chaos_failover_doctrine.md` §17](../engineering/chaos_failover_doctrine.md#17-the-boundary-and-its-classifier).
**Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(a closed union whose vocabulary omits the `Confluent` arm — a false confluence claim has no word). **Layer:**
`type-foreclosed` for the arm absence; the confluence classification itself is an `assumed` model obligation (the
honest limit — a genuinely-confluent invariant's confluence is proven at design time, not decidable in the spec).
**Validation-locus:** `Gate-1-editor` (no `Confluent` arm exists in the authorable union); `live-effect` residue
— the model's confluence classification actually holding under merge.

### 3.52 A gateway-failover graph reusing one cluster across two DNS records

A forest with two geo-replicated pairs could name one survivor cluster as the `standby` of two distinct
`dnsRecord`s — the shared-survivor topology. Its migrations are graph-independent (distinct records, no vertex
holds the wild-ingress role for two records at once), so a fold checking only graph shape would admit it. But
the scope-2 gateway-migration proof reduces an N-cluster forest to independent 2-cluster instances only under
**resource** independence, and a shared survivor interacts through infrastructure the graph does not model,
resting the reduction on an assumed shared-resource premise rather than a proven one. amoebius's structural-fit
fold therefore requires resource independence as well as graph independence: **no cluster is reused as `active`
or `standby` across two `dnsRecord`s**, so the shared-survivor graph decodes to a `DecodeError`. The excluded
topology is a named deferred obligation gated on the decomposition lemma, revisitable only once that lemma is
discharged; until then the shape is unavailable, not unsound. **Owner:**
[`gateway_migration_model_doctrine.md` §5](../engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)
(the structural-fit fold and its independence predicate), realized on the authorable surface by
[`consistency_pacelc_doctrine.md` §3.3](../engineering/consistency_pacelc_doctrine.md#33-the-ir-and-its-decode-foreclosures-haskell-gate-2)
(the third decode fold). **Technique:** [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally)
(a distinctness fold over the cluster identities projected across the migration graph — the same fold family that
rejects a reused host or an `active == standby` pair, lifted from one edge to the whole graph). **Layer:**
`decode-foreclosed` — the constraint is a cross-record fold over the decoded graph, not a single-field type
index, so a total decoder returns `Left` rather than the shape being uninhabitable. **Validation-locus:**
`Gate-2-decoder` (the structural-fit fold returns `DecodeError` on a graph reusing a cluster across records,
before any `ProvisionedSpec` exists); the over-scope stress run that *models* a shared survivor in is a
`live-effect`/model residue, not an authorable shape.

### 3.69 A cold-seeded secondary taking the gateway without proven freshness

When a primary is down and a `ColdSeedFromBackup` secondary is stood up on demand and seeded from backups, a
secondary that took the wild-ingress gateway before its seeded data was proven fresh would serve stale or
divergent data — the availability-over-consistency error the cold-seed posture exists to refuse. The gateway
migration model generalizes the `verify-caught-up` precondition into a `FreshnessWitness` guard on the
gateway-take transition, and the safety invariant `NoTakeWithoutProvenFreshness` holds that no cluster takes
the wild-ingress role from a data plane whose freshness is unproven; a stalled zero-owner state is safe, and
only liveness convergence requires freshness to become reachable, so amoebius stays down rather than serving
stale data. **Owner:** [`gateway_migration_model_doctrine.md`](../engineering/gateway_migration_model_doctrine.md)
(the guard and invariant), realized on the authorable surface by
[`consistency_pacelc_doctrine.md` §3](../engineering/consistency_pacelc_doctrine.md#3-the-one-configurable-axis--the-deployment-rules-pacelc-surface)
and the seed posture of [`backup_recovery_doctrine.md` §8](../engineering/backup_recovery_doctrine.md#8-the-gateway-dovetail-seed-from-backup-under-consistency-over-availability).
**Technique:** [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
(the gateway-take handle exists only from a `FreshnessProven` index). **Layer:** the ordering is
type-foreclosed; the caught-up/fresh edge is a runtime-observed witness, proven for the model and tested by
drill, never a constructive proof at reconcile. **Validation-locus:** `live-effect`, backed by the Register-1
model check.

### 3.70 A `ColdSeedFromBackup` whose freshness bound is below the backup cadence

A cold-seed recovery whose declared `freshnessBound` is shorter than the backup `cadence` is statically
unsatisfiable: a seed can never be fresher than the newest generation, so no seed could ever satisfy the
bound and the secondary could never be promoted. The decoder rejects `freshnessBound < cadence` at Gate 2,
the same total checked-rejection shape as the existing `rto ≥ dnsTtl + headroom` relation, before any live
signal is consulted. **Owner:** [`backup_recovery_doctrine.md` §8](../engineering/backup_recovery_doctrine.md#8-the-gateway-dovetail-seed-from-backup-under-consistency-over-availability)
(realized on the PACELC surface by [`consistency_pacelc_doctrine.md` §3.5](../engineering/consistency_pacelc_doctrine.md#35-the-upload-time-feasibility-push-back)).
**Technique:** [§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction)
(binding-by-construction — the bound and cadence relation is checked at decode, not a separate authored field).
**Layer:** `decode-foreclosed`. **Validation-locus:** `Gate-2-decoder`.

### 3.71 A freshness watermark asserted rather than derived from captured content

If the freshness gate read an operator-asserted watermark instead of one derived from the backup's captured
content, the consistency-over-availability guarantee would be spoofable: a stale backup could claim a freshness
it never captured and be promoted. A `BackupArtifact`'s `watermark` is a total function of its content-addressed
digest, never an asserted field, so the freshness witness the gateway-take guard consumes cannot be forged.
**Owner:** [`backup_recovery_doctrine.md` §6](../engineering/backup_recovery_doctrine.md#6-the-verified-content-addressed-backupartifact)
(content addressing owned by [`content_addressing_doctrine.md` §4.5](../engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)).
**Technique:** [§4.5](./illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content)
(names are total functions of content). **Layer:** `decode-foreclosed` (the watermark is derived, not an
authorable field) + `live-effect` residue (that the derived watermark reflects real lag). **Validation-locus:**
`Gate-2-decoder` + `provision-seal`.

---

## Cross-references

- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the authoritative catalog index and the honesty
  limit (a type-check proves the spec composes, not that the cluster enforces it); this document is one themed
  slice of that catalog.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the seven typing techniques (§4.1–§4.7), the
  coverage matrix, the three-layer foreclosure model, and the validation-locus axis referenced by every entry
  above.
- [`dsl_doctrine.md`](../engineering/dsl_doctrine.md) — the DSL surface and the contract that a valid `InForceSpec` cannot
  represent illegal state.

Owning doctrines cited by the entries in this slice:

- [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) — owns `place` and the
  single-cluster-by-arity non-goal ([§3.31](#331-a-capacity-or-workload-fold-spanning-two-clusters)).
- [`single_logical_data_plane_doctrine.md`](../engineering/single_logical_data_plane_doctrine.md) — the attach carrier +
  `ewpNetworking`, the cluster as consistency boundary, and the host worker as attach-pool client
  ([§3.31](#331-a-capacity-or-workload-fold-spanning-two-clusters), [§3.35](#335-a-stretched-host-worker-with-no-declared-networking-capability), [§3.38](#338-a-host-worker-granted-a-control-plane-witness-or-treated-as-a-member)).
- [`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) — the `Topology` shape, the node fold +
  `mkStretchedAgent`, and the `witness` fold ([§3.31](#331-a-capacity-or-workload-fold-spanning-two-clusters), [§3.36](#336-a-declared-remote-full-agent-with-no-control-plane-witness), [§3.38](#338-a-host-worker-granted-a-control-plane-witness-or-treated-as-a-member)).
- [`network_fabric_doctrine.md`](../engineering/network_fabric_doctrine.md) — the `Networking` sum and the minted fabric /
  control-plane witnesses ([§3.35](#335-a-stretched-host-worker-with-no-declared-networking-capability), [§3.36](#336-a-declared-remote-full-agent-with-no-control-plane-witness)).
- [`substrate_doctrine.md`](../engineering/substrate_doctrine.md) §8 — the `Site` axis
  ([§3.35](#335-a-stretched-host-worker-with-no-declared-networking-capability)).
- [`gateway_migration_doctrine.md`](../engineering/gateway_migration_doctrine.md) — the migration state machine and the
  client-rebind protocol ([§3.44](#344-a-session-that-cannot-rebind-on-gateway-migration)); the parent-owned
  `GatewayFailover` pairing relation ([§3.48](#348-a-geo-replication-pair-whose-active-and-standby-are-the-same-cluster), [§3.49](#349-a-child-spec-that-authors-its-own-gateway-failover-pairing)); the world-triggered mode ([§3.50](#350-a-standing-spec-that-authors-an-emergency-failover-as-desired-state)).
- [`consistency_pacelc_doctrine.md`](../engineering/consistency_pacelc_doctrine.md) — the PACELC deployment-rules
  surface: the derived-RPO rule ([§3.47](#347-a-failover-data-loss-budget-authored-below-the-replication-lag-bound)), the `active ≠ standby` fold ([§3.48](#348-a-geo-replication-pair-whose-active-and-standby-are-the-same-cluster)), the world-triggered mode ([§3.50](#350-a-standing-spec-that-authors-an-emergency-failover-as-desired-state)), and the no-`Confluent`-arm disposition ([§3.51](#351-an-operator-authored-confluent-cross-boundary-disposition)).
- [`readiness_ordering_doctrine.md`](../engineering/readiness_ordering_doctrine.md) — the edge-observed drain residue
  ([§3.44](#344-a-session-that-cannot-rebind-on-gateway-migration)).
