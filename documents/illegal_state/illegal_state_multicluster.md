# Illegal States — Multi-cluster & Fabric

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/gateway_migration_doctrine.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_topology.md
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
  axis** (`Gate-1-editor` / `Gate-2-decoder` / `rendered-output-golden` / `live-effect`) are owned by
  [`illegal_state_techniques.md`](./illegal_state_techniques.md).

Each entry below keeps its existing `**Layer:**` foreclosure tag and adds a new `**Validation-locus:**` line —
the orthogonal axis defined in [`illegal_state_techniques.md`](./illegal_state_techniques.md) — naming *where*
the illegal state is caught (at the Dhall editor, in the total decoder, in a golden test on the rendered
manifest, or only as runtime residue). As throughout the catalog, everything here is **design intent**: a
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
`place`, related only by async Pulsar replication — a deliberate Phase-29 non-goal); it is **not** the stateless
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
enaction (Phase 29).
**Validation-locus:** `Gate-1-editor` (the `place` arity admits exactly one `Topology` — the "no arm" fold shape
has no way to name a second cluster, rejected at authoring by `dhall type`); `live-effect` (the only residue is
the deferred geo-replication enaction, Phase 29).

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
  client-rebind protocol ([§3.44](#344-a-session-that-cannot-rebind-on-gateway-migration)).
- [`readiness_ordering_doctrine.md`](../engineering/readiness_ordering_doctrine.md) — the edge-observed drain residue
  ([§3.44](#344-a-session-that-cannot-rebind-on-gateway-migration)).
