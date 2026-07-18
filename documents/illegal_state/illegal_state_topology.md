# Illegal States — Cluster Topology

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: The themed slice of the illegal-state catalog covering compute-engine/substrate
> compatibility, `LinuxHost` witnesses, and rke2 quorum/locality — the cluster-topology states a valid
> `InForceSpec` cannot represent.

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog: the cluster-topology entries —
compute-engine ↔ substrate compatibility (managed providers first-class), the `LinuxHost` witness that
demands an interposed Linux VM on non-Linux hosts, kind's single-host cardinality, and rke2's
host-per-node cardinality plus its etcd quorum shape and `Site`-locality.

It owns nothing but the faithful reproduction of these entries. The catalog **index** and the load-bearing
**honesty limit** (a type-check proves the *spec composes*, not that the *running cluster enforces it*) are
owned by [`illegal_state_catalog.md`](./illegal_state_catalog.md). The **seven typing techniques**, the
**coverage matrix**, the **three foreclosure layers**, and the **validation-locus axis** (the orthogonal
axis — `Gate-1-editor` / `Gate-2-decoder` / `provision-seal` / `rendered-output-golden` / `live-effect` — added
on each entry below; `provision-seal` is post-bind Phase-8 provision returning a `ProvisionError` before any
`ProvisionedSpec`) are owned by [`illegal_state_techniques.md`](./illegal_state_techniques.md). This slice references
them and does not restate them.

Everything below is **design intent**, per the honesty discipline of
[`illegal_state_techniques.md` §6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force):
a green type-check proves the specification composes into something internally coherent; it does not prove
the running deployment enforces it. Each `**Layer:**` tag records where the foreclosure lives, and each
`**Validation-locus:**` line records the gate that catches the state — plus, for most entries, the
`live-effect` residue that only reconcile/runtime can settle.

---

## 2. The cluster-topology illegal states

### 3.13 A compute engine incompatible with its substrates (managed providers first-class)

Raw tooling permits pointing kind, rke2, or a managed cluster at a substrate that cannot run it, and lets a
managed provider (EKS) be a bolt-on afterthought rather than a first-class citizen. amoebius makes the
compute engine a **declared axis** distinct from the *detected* substrate, and a `Node` is built by a
compatible-pair smart constructor: only an `(engine, substrate-indexed host | hostless provider)` pair the
relation permits has a constructor, checked **elementwise** so heterogeneous **multi-substrate clusters stay
legal** while an incompatible pairing has no inhabitant. EKS is a first-class `Managed` arm of the closed
`ComputeEngine` union (a product/unknown engine is uninhabitable). **Owner:**
[`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) (+ the node inventory in
[`substrate_doctrine.md`](../engineering/substrate_doctrine.md)). **Technique:** [§4.7](./illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) (relation over a collection) + [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(closed union, EKS arm present) + [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally) (the node inventory the compatibility reads). **Layer:** decode-foreclosed for the
elementwise compatibility fold; type-foreclosed sub-part (EKS is a union arm; a product/unknown engine is
uninhabitable).
**Validation-locus:** `Gate-1-editor` (the closed `ComputeEngine` union — the EKS `Managed` arm is present, a product/unknown engine is uninhabitable) + `Gate-2-decoder` (the elementwise engine↔substrate compatibility fold over the node inventory returns `Left` on an incompatible pairing).

### 3.14 rke2/kind on a host with no Linux node (apple/windows without an interposed Linux VM)

kind and rke2 need a Linux kernel; on a bare apple or windows host there is none until one is synthesized in
a VM. amoebius makes a `LinuxHost` a **witness** whose only constructor on a non-Linux substrate is the
virtualization provider (`limaHost` on apple, `wsl2Host` on windows), so "rke2/kind on a bare Apple host"
(the VM interposition [`substrate_doctrine.md` §4](../engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)
describes as reconcile behaviour) becomes a *type demand* — the bare-host spec has no inhabitant. (Distinct
from the Apple-Metal *build* carve-out, which is on-host by design,
[`apple_metal_headless_builds.md`](../engineering/apple_metal_headless_builds.md).) **Owner:**
[`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) (+ substrate [§4](../engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux) for the synthesis).
**Technique:** [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (a distro GADT indexed by a required `LinuxHost` witness). **Layer:** type-foreclosed uninhabitable;
runtime-checked residue — that the Lima/WSL2 VM actually boots.
**Validation-locus:** `Gate-2-decoder` (the distro GADT indexed by the required `LinuxHost` witness — a bare-host distro has no inhabitant once decoded) + `live-effect` (that the interposed Lima/WSL2 VM actually boots).

### 3.15 A multi-node kind cluster not on a single Linux host

kind runs every node as a container on one Docker host, so a multi-node kind cluster spanning machines is a
category error. amoebius's `Kind` arm carries **exactly one** `LinuxHost` field; multi-node is `replicas` on
that one host, and a second host has no field to bind. **Owner:**
[`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md). **Technique:** [§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction) (required-field: one
`host`; `replicas` never adds a host). **Layer:** type-foreclosed uninhabitable.
**Validation-locus:** `Gate-1-editor` (the `Kind` arm's single required `host` field — a second host has no field to bind, so `dhall type` rejects it at authoring time).

### 3.16 A multi-node rke2 cluster with fewer Linux hosts than nodes (or a host reused)

A multi-node rke2 cluster needs one distinct Linux host per node; raw tooling permits asking for five nodes with
three machines, or reusing one machine for two nodes. amoebius's `Rke2` arm carries
`{ servers : Rke2Servers, agents : Fixed (List LinuxHost) | Autoscaled { floor, policy } }`: the server arm
fixes the server count structurally (`Single`/`Ha3`/`Ha5`,
[§3.24](#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain)), and every fixed/floor agent
binds one `LinuxHost`; future agents are represented by the policy's non-empty candidate classes and finite
quota, not by fictitious host values. **Distinctness** ("no declared host reused") is the one part Dhall cannot
express as a type (no Set-distinctness), so it degrades to the total post-bind provision fold that rejects a
duplicate `HostId` **over `servers ∪ agentFloor`** — a server host reused as an agent, or two declared agents on
one machine, is caught alongside two servers on one machine. This **generalizes** the original "the node list
*is* the host list" cardinality to the split fixed/elastic server-agent inventory (the quorum shape itself is
[§3.24](#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain)). **Owner:**
[`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md). **Technique:** [§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction) (`node == host`
cardinality) + [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally) (distinctness fold over `servers ∪ agentFloor`). **Layer:** decode-foreclosed — assigned to its weaker
distinctness floor; the cardinality sub-part is type-foreclosed.
**Validation-locus:** `provision-seal` (the post-bind distinctness fold over `servers ∪ agentFloor` returns a
`ProvisionError` before any `ProvisionedSpec` exists on a reused `HostId`) + `Gate-1-editor` (the fixed-node cardinality
sub-part — one required `host` field per declared node; an elastic candidate is a capacity/substrate class, not
a host).

### 3.24 An even/zero-server rke2 control plane (no etcd quorum / split-brain)

Raw rke2 HA permits standing up a **two**-server control plane — two etcd voters can never form a majority, so
the first partition is a split-brain — or a **zero**-server "cluster" of agents with nowhere to join. amoebius
makes the server set a **closed union** `Rke2Servers = < Single : LinuxHost | Ha3 : {…} | Ha5 : {…} >` whose
only arms are the legal **odd etcd quorums {1, 3, 5}**: a 0- or 2-server control plane has no constructor. This
is the same "no unbounded arm" idiom as the `StorageBacking`/`Growable` unions ([§3.18](./illegal_state_storage.md#318-unbounded-storage-anywhere), [§3.21](./illegal_state_storage.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy)) — the illegal
cardinality is not rejected, it is *unrepresentable*. The root cluster is
`{ servers = Rke2Servers.Single host, agents = Fixed [] }` (the existing zero-secret single node); HA is capped at 5
by design, and a `Ha7` arm is a deliberate future add, not an omission. A quorum change (`Single` → `Ha3`) is a
deliberate re-provision, **never** a `ScalingPolicy`/autoscale — `ScalingPolicy` exists only inside the
`Autoscaled` agent arm and grows that data plane.
The control-plane taint and its tolerations are **derived** from the server set, never hand-authored (the
[§3.5](./illegal_state_capacity.md#35-undeployable-pods-taints-tolerations--affinity)/[§3.22](./illegal_state_capacity.md#322-a-hand-authored-un-derived-toleration) derive-don't-author discipline). **Owner:**
[`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (closed `Rke2Servers`
union — the even/zero arm has no constructor). **Layer:** type-foreclosed uninhabitable; runtime-checked residue — that etcd
actually forms and holds quorum, owned by [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md).
**Validation-locus:** `Gate-1-editor` (the closed `Rke2Servers` union — the even/zero-server cardinality has no arm, so `dhall type` rejects it before any binary runs) + `live-effect` (that etcd actually forms and holds quorum, owned by [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md)).

### 3.37 A full stretched node on a managed EKS control plane without a provider-native hybrid arm

A managed control plane (EKS) is deliberately **hostless** — no `LinuxHost` field to hang a node off, no
channel-1 mTLS — so a full **member** node stretched onto a `Managed Eks` control plane is representable **only**
if the provider natively supports it (**EKS Hybrid Nodes**). Absent that provider-native arm it has **no
constructor** — **type-foreclosed uninhabitable**, the identical closed-union "no arm = not supported" idiom as a
2/0-server quorum ([§3.24](#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain)), a `Ha7` arm,
and `StorageBacking`'s missing unbounded case ([§3.18](./illegal_state_storage.md#318-unbounded-storage-anywhere)). amoebius must **not**
build a second WireGuard + distro-mTLS control-plane fabric to fake it — that is the "autonomous substrate
authority beside the control-plane singleton" shape the doctrine rejects; when/if EKS Hybrid Nodes lands it enters as a
**new provider-native arm the `Managed` arm surfaces** (provisioned over the cloud API), never amoebius-built
machinery. A stretched **host worker** on EKS needs no such arm — it is control-plane-free
([§3.35](./illegal_state_multicluster.md#335-a-stretched-host-worker-with-no-declared-networking-capability)). **Owner:**
[`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) §2/§4.1 (the hostless `Managed` arm), on the
surface-provider-vs-build discipline owned by [`cluster_lifecycle_doctrine.md`](../engineering/cluster_lifecycle_doctrine.md)
§1 + [`pulumi_iac_doctrine.md`](../engineering/pulumi_iac_doctrine.md). **Technique:**
[§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (closed provider-arm union —
the hybrid arm is absent, so the state has no inhabitant). **Layer:** type-foreclosed uninhabitable until a provider-native
arm is surfaced; runtime-checked residue — that the provider's hybrid mechanism actually joins the node.
**Validation-locus:** `Gate-1-editor` (the closed provider-arm union — the hybrid arm is absent, so a full member node on a hostless `Managed Eks` control plane has no constructor and fails `dhall type`) + `live-effect` (that the provider's hybrid mechanism actually joins the node, once a provider-native arm is surfaced).

### 3.39 A split-Site etcd quorum

An etcd quorum split across network-localities loses its low-latency majority and risks partition on the WAN
link. This round keeps all rke2 servers **`Site`-co-located** by indexing the server set on one `Site`:
`Rke2Servers (s :: Site) = Single (HostAt s) | Ha3 … | Ha5 …` forces every server onto **one** `Site s`, so a
split-`Site` quorum has **no inhabitant** — a **type-foreclosed phantom-`Site` unification**, **explicitly not** the
odd-quorum count union of [§3.24](#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain) (that
entry forecloses even/zero *cardinalities*; this forecloses a *split locality* at a legal cardinality).
Control-plane machinery (the co-located quorum, `mkStretchedAgent`) is full-node-only; host workers carry no
quorum. **Owner:** [`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) §4.1 (the `Site`-indexed
`Rke2Servers`); the `Site` axis owned by [`substrate_doctrine.md`](../engineering/substrate_doctrine.md) §8. **Technique:**
[§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (a phantom `Site` index the server arms
must unify on) + [§4.7](./illegal_state_techniques.md#47-compatibility--topology-relations-by-construction-over-a-collection) (the
servers/agents collection shape). **Layer:** type-foreclosed uninhabitable; runtime-checked residue — that the co-located members
actually keep a low-latency majority.
**Validation-locus:** `Gate-2-decoder` (the phantom `Site` index that every server arm must unify on — a split-`Site` server set has no inhabitant once decoded into the `Site`-indexed GADT) + `live-effect` (that the co-located members actually keep a low-latency majority).

---

## Cross-references

- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the catalog index, the honesty limit
  ([§2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)),
  and the three foreclosure layers ([§6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)).
  This document is one themed slice of it.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the seven typing techniques ([§4](./illegal_state_techniques.md#4-the-typing-techniques)), the
  coverage matrix ([§5](./illegal_state_techniques.md#5-coverage-matrix--which-technique-forecloses-which-illegal-state)), the foreclosure layers, and the **validation-locus axis** used on every entry above.
- [`dsl_doctrine.md`](../engineering/dsl_doctrine.md) — the DSL surface and the contract ("a valid `InForceSpec` cannot
  represent illegal state") these topology entries instantiate.
- [`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) — the owning doctrine for every entry
  here: the `ComputeEngine`/`Node` compatibility relation, the `Kind`/`Rke2` arms, the `Rke2Servers` quorum
  union, the hostless `Managed` arm, the node fold, and the `Site`-indexed server set.
- [`substrate_doctrine.md`](../engineering/substrate_doctrine.md) — the node inventory and detected substrates
  ([§3.13](#313-a-compute-engine-incompatible-with-its-substrates-managed-providers-first-class)), the
  Linux-VM synthesis (§4, [§3.14](#314-rke2kind-on-a-host-with-no-linux-node-applewindows-without-an-interposed-linux-vm)),
  and the `Site` axis (§8, [§3.39](#339-a-split-site-etcd-quorum)).
- [`cluster_lifecycle_doctrine.md`](../engineering/cluster_lifecycle_doctrine.md) and
  [`pulumi_iac_doctrine.md`](../engineering/pulumi_iac_doctrine.md) — the surface-provider-vs-build discipline behind the
  hostless `Managed` arm ([§3.37](#337-a-full-stretched-node-on-a-managed-eks-control-plane-without-a-provider-native-hybrid-arm)).
- [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md) — the runtime-enforcement owner for the
  quorum/locality `live-effect` residue ([§3.24](#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain),
  [§3.39](#339-a-split-site-etcd-quorum)).
- [`apple_metal_headless_builds.md`](../engineering/apple_metal_headless_builds.md) — the on-host Apple-Metal *build*
  carve-out, distinct from the `LinuxHost` witness demand
  ([§3.14](#314-rke2kind-on-a-host-with-no-linux-node-applewindows-without-an-interposed-linux-vm)).
