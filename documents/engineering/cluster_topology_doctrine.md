# Cluster Topology

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/illegal_state_catalog.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

> **Purpose**: Single Source of Truth for the amoebius **declared** compute-engine axis — the `ComputeEngine`
> union (`Kind` / `Rke2` / `Managed` EKS / …), the substrate-indexed `LinuxHost` witness that makes
> "rke2 on a host with no Linux node" uninhabitable, the `Topology` fold over a `NonEmpty Node` that pins
> kind to one host and rke2 to one Linux host per node, and the engine↔substrate compatibility relation that
> keeps heterogeneous multi-substrate clusters legal while rejecting an incompatible pairing.

---

## 1. Two axes: the substrate is detected, the engine is declared

amoebius keeps two orthogonal axes strictly apart, and conflating them is the exact bug this doctrine exists
to prevent:

- **The substrate is a *detected fact* about the host** — apple / linux-cpu / linux-cuda / windows, read from
  OS × arch × GPU and never an operator knob. That closed catalog and its detection are owned in full by
  [substrate_doctrine.md §1](./substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob).
- **The compute engine is a *declared choice*** — kind, rke2, or a managed provider (EKS) — the operator
  authors in the `.dhall`. A declared choice cannot live in the substrate doctrine without contradicting its
  "a fact, not a knob" frame, so this document owns it, and links to substrate for the detected axis it
  ranges over.

The two meet in a **compatibility relation**: an engine runs only on the substrates it is compatible with,
and where an engine needs a Linux kernel on a non-Linux host, it consumes the *virtualization provider* the
substrate doctrine already owns (Lima on apple, WSL2 on windows). This document owns that relation and the
topology it induces; it owns **no** substrate names, no detection, no VM-provider mechanics, and no capacity
numbers (those are [substrate_doctrine.md](./substrate_doctrine.md) and
[resource_capacity_doctrine.md](./resource_capacity_doctrine.md)).

Everything below is **design intent for Phase 3** (the type discipline) with runtime realization in Phases
7/9/10. Status and gates live only in [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md).

---

## 2. `ComputeEngine`: a closed union, EKS a first-class arm

The compute engine is a closed union — a product name amoebius does not support has no arm, exactly as the
service-capability union admits no product ([service_capability_doctrine.md](./service_capability_doctrine.md)):

```
ComputeEngine
  = Kind { host : LinuxHost, replicas : Replicas }
  | Rke2 : { servers : Rke2Servers, agents : List LinuxHost }
  | Managed Eks           -- provider-managed, hostless

Rke2Servers            -- CLOSED odd-quorum union: an arm only for a legal etcd quorum {1,3,5}
  = < Single : LinuxHost
    | Ha3    : { s0 : LinuxHost, s1 : LinuxHost, s2 : LinuxHost }
    | Ha5    : { s0 : LinuxHost, s1 : LinuxHost, s2 : LinuxHost, s3 : LinuxHost, s4 : LinuxHost }
    >
```

- **`Kind`** carries **exactly one** `LinuxHost` field. A multi-node kind cluster is `replicas > 1` on that
  *one* host — kind runs every node as a container on a single Docker host, so "a multi-node kind cluster
  spread across hosts" (I3) has no field to express it (§4, [illegal_state_catalog.md §3.15](./illegal_state_catalog.md)).
- **`Rke2`** carries `{ servers : Rke2Servers, agents : List LinuxHost }` — a **control plane** and a **data
  plane**, not a flat node bag. `Rke2Servers` is a **closed odd-quorum union** (`Single` / `Ha3` / `Ha5`), so
  an **even- or zero-server** control plane (no etcd majority / split-brain) has no constructor and is
  **grade-1 unrepresentable** ([illegal_state_catalog.md §3.24](./illegal_state_catalog.md)); it caps HA at
  five by design (a `Ha7` arm is a deliberate future add). Agents are an ordinary `List LinuxHost`. "More
  nodes than hosts" stays uninhabitable and "the same host reused for two nodes" — now over `servers ∪ agents`
  — is a decode-rejected distinctness violation (I4,
  [illegal_state_catalog.md §3.16](./illegal_state_catalog.md)); the cardinality detail is §4.1.
- **`Managed Eks`** is the **first-class** provider arm (I13): a provider-managed cluster with **no host** and
  no `LinuxHost` field at all. Its nodes' capacity comes from the declared instance types, not physical hosts
  ([resource_capacity_doctrine.md §3](./resource_capacity_doctrine.md)), and it is provisioned over the cloud
  API, owned by [pulumi_iac_doctrine.md §4](./pulumi_iac_doctrine.md#4-what-pulumi-provisions-the-resource-catalog).
  Because the `Managed` arm carries no `LinuxHost` / host-worker index, "a host workload (Apple Metal /
  Windows CUDA) on a hostless provider child" is uninhabitable — the hostless-provider honesty already named
  by [cluster_lifecycle_doctrine.md §1](./cluster_lifecycle_doctrine.md#1-two-cluster-kinds-one-lifecycle-shape),
  lifted to the type.

The untyped CLI surface — `amoebius bootstrap --distro={kind,rke2} [--replicas=n]`
([substrate_doctrine.md §6](./substrate_doctrine.md#6-the-bootstrapsh-contract-ensure-a-toolchain-build-the-binary-hand-off))
— is a *projection* of this typed `ComputeEngine`, not a second source of truth.

---

## 3. The `LinuxHost` witness: rke2/kind on a host with no Linux node is uninhabitable

Intuition: kind and rke2 need a **Linux kernel**. On a Linux substrate that is the host itself; on apple or
windows there is no Linux kernel until one is *synthesized* in a VM. So a `LinuxHost` is not a free value — it
is a **witness** that a Linux kernel exists, and on a non-Linux substrate the **only** constructor for it is
the virtualization provider.

- **`LinuxHost` is substrate-indexed and its constructor is gated.** On `linux-cpu`/`linux-cuda` a host *is* a
  `LinuxHost`. On `apple` the only constructor is `limaHost` (a Lima Ubuntu VM); on `windows` the only
  constructor is `wsl2Host` (a WSL2 Ubuntu distro). There is **no** `bareAppleHost : LinuxHost` and no
  `bareWindowsHost : LinuxHost` (§4.3 constructor-gating,
  [illegal_state_catalog.md §3.14](./illegal_state_catalog.md)).
- **So "rke2 on a bare Apple host" (I1) has no inhabitant.** `Rke2`/`Kind` demand a `LinuxHost`; on apple the
  only way to produce one is `limaHost`, so the VM interposition the substrate doctrine describes as reconcile
  behaviour ([substrate_doctrine.md §4](./substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux))
  becomes a *type demand* — you cannot even write the bare-host spec.
- **This is distinct from the Apple-Metal build carve-out.** "No VM for Apple-Metal *builds*"
  ([apple_metal_headless_builds.md](./apple_metal_headless_builds.md)) is about the on-host Metal *bridge
  build*; an rke2/kind *cluster* on an apple host still needs a Lima Linux VM. The two are different
  concerns and this doc states the cluster one; the build one is unchanged.
- **Honesty.** The witness demand is grade-1 (no constructor). That the Lima/WSL2 VM *actually boots* and
  presents a working kernel is grade-3 runtime, owned by
  [substrate_doctrine.md §4](./substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)
  and exercised in Phase 7.

---

## 4. `Topology`: a cluster is a fold over its nodes, and cardinality is by construction

Intuition: a cluster is not a loose bag of settings — it is a **`NonEmpty Node`**, and the engine dictates how
node count relates to host count. Making the count a *structural* property forecloses the topology illegal
states without arithmetic where possible.

```
Topology = { engine : ComputeEngine, nodes : NonEmpty Node }
Node     = { host : Host, substrate : Substrate }   -- Host is a LinuxHost witness or a hostless Provider slot
```

- **Kind: exactly one host (I3, grade-1).** The `Kind` arm's single `host` field *is* the cardinality bound —
  a second host has no field to bind, a Gate-1 type error. Multi-node is `replicas`, which never adds a host.
- **rke2: one Linux host per node, quorum by construction (I4).** `Rke2` no longer carries a flat
  `NonEmpty LinuxHost`; it splits into `{ servers : Rke2Servers, agents : List LinuxHost }` (§2). Every server
  and every agent still *is* a `LinuxHost` value, so "more nodes than hosts" stays grade-1 uninhabitable — but
  the server count is now pinned to a legal odd etcd quorum by the closed `Rke2Servers` union rather than left
  to a runtime check. **Distinctness** ("no host reused for two nodes") now ranges over `servers ∪ agents` and
  is still the one part Dhall cannot express as a type (no Set-distinctness), so it degrades to a **grade-2
  total decode fold** (`mkRke2` rejects a duplicate `HostId`), and the catalog grades §3.16 to that weaker
  floor honestly. Full cardinality treatment is §4.1.
- **Multi-substrate clusters stay legal (I2 carve-out).** A `Topology` may mix nodes of *different*
  substrates — a heterogeneous cluster is explicitly allowed. Compatibility (§5) is checked **elementwise**
  per node, never as a single whole-cluster substrate, so a legal multi-substrate cluster decodes while an
  incompatible pairing does not.

### 4.1 rke2 server/agent cardinality: odd quorum by union, distinctness by fold, taint by derivation

The flat `Rke2.nodes : NonEmpty LinuxHost` treated every rke2 node alike. The typed model (§2) splits the
cluster into a **control plane** (`servers : Rke2Servers`) and a **data plane** (`agents : List LinuxHost`) and
pins three properties at three honest grades.

- **Quorum by closed union (grade-1).** `Rke2Servers = < Single | Ha3 | Ha5 >` has an arm *only* for the legal
  odd etcd quorums {1, 3, 5}. A **0-server** (no control plane) or **2-server** (no majority / split-brain)
  cluster has **no constructor** — grade-1 unrepresentable, the same "no illegal arm" idiom as `StorageBudget`'s
  missing unbounded case ([resource_capacity_doctrine.md §5](./resource_capacity_doctrine.md)). The union
  deliberately caps HA at five; a `Ha7` arm is a future add, not an oversight. This is catalog entry
  [illegal_state_catalog.md §3.24](./illegal_state_catalog.md) (Owner: this doc; Technique: §4.2 closed union).
- **Distinctness by fold over `servers ∪ agents` (grade-2).** Dhall has no Set-distinctness, so "no host reused
  for two nodes" cannot be a type. It degrades to the **grade-2 total decode fold** `mkRke2`, which now ranges
  over the **union of the server set and the agent list** and rejects a duplicate `HostId`. This *generalizes*
  the old single-node-list fold: distinctness must hold across both planes at once, so a host cannot be both a
  server and an agent, nor appear twice in either. The catalog grades
  [illegal_state_catalog.md §3.16](./illegal_state_catalog.md) to this weaker floor honestly and now scopes it
  to `servers ∪ agents`.
- **Control-plane taint by derivation (grade-1 structural, grade-3 residue).** The control-plane node taint and
  its matching workload tolerations are **derived from the server set**, never hand-authored — the same
  derive-don't-author discipline the catalog names for tolerations
  ([illegal_state_catalog.md §3.22](./illegal_state_catalog.md)). Because `servers` is the single source of the
  taint, there is no seam to author an un-derived one; the derivation is grade-1 at the spec layer, with the
  actual kube-level taint/toleration application a grade-3 runtime residue on the reconciler.

**Root cluster.** The zero-secret root is exactly `{ servers = Rke2Servers.Single host, agents = [] }` — one
server, no agents — the single-node base named by the root-single-node rule in
[cluster_lifecycle_doctrine.md §2](./cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap). Growing it is two
different moves, never fused:

- **Agents grow by `ScalingPolicy`.** Adding data-plane capacity extends the `agents` list, enacted as Pulumi
  node provisioning ([resource_capacity_doctrine.md §6](./resource_capacity_doctrine.md),
  [pulumi_iac_doctrine.md §4](./pulumi_iac_doctrine.md#4-what-pulumi-provisions-the-resource-catalog)).
- **Quorum is fixed by declaration.** The server count is *not* an autoscaled quantity: moving `Single → Ha3`
  (or `Ha3 → Ha5`) is a **deliberate re-provision of the control plane**, authored in the `.dhall`, never a
  `ScalingPolicy` outcome. Quorum is pinned by the declared `Rke2Servers` arm; the capacity arithmetic over the
  resulting node set is owned by [resource_capacity_doctrine.md §6](./resource_capacity_doctrine.md).

**Rollout is a lifecycle verb, not a type.** The server/agent bring-up — the first server running etcd
`cluster-init` and minting the join token, further servers and all agents joining by a `server:` URL plus that
token, rejoin idempotent — is a checkpoint-free tag-discovery **host reconcile (reconciler tier (b))** and a
lifecycle *verb*, owned by
[cluster_lifecycle_doctrine.md §2](./cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap) (the reconciler,
not a state machine — [cluster_lifecycle_doctrine.md §9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)).
This doc supplies only the shape those verbs act on (per §6-§7).

**Sibling evidence, not an amoebius result.** prodbox's `Prodbox/CLI/Rke2.hs` proves the **single-node** base
(`rke2-server.service`, `/etc/rancher/rke2/config.yaml`, `registries.yaml`, install markers, uninstall) and its
golden `rke2-reconcile.txt` shows the step-list (`ensure_rke2_server_installed → enable/restart → sync
kubeconfig → wait_for_cluster_nodes_ready`). That is `rke2-server` **only** — the multi-node server/agent
split, the etcd-HA `Ha3`/`Ha5` quorums, and the join-token custody are **net-new** across the sibling family
(hostbootstrap carries zero rke2 code). Sibling evidence, not amoebius proof
([documentation_standards.md §6](../documentation_standards.md)).

---

## 5. The compatibility relation (technique §4.7): only compatible pairs have a constructor

Intuition: "a compute engine not compatible with the available substrates" (I2) should have no way to be
written — so a `Node` is built by a **compatible-pair smart constructor** that only accepts an
`(engine, substrate-indexed host)` pair the relation permits.

This is the catalog's **§4.7 technique — compatibility/topology relations by construction over a collection**
([illegal_state_catalog.md §4.7](./illegal_state_catalog.md)): it composes the phantom-index (§4.2),
constructor-gating (§4.3), and ownership-fold (§4.4) techniques and applies them to a **binary relation over a
collection**.

- **Element-level (grade-1 where structural).** `Managed Eks` pairs only with a hostless provider slot;
  `Rke2`/`Kind` pair only with a `LinuxHost` witness (§3). A pairing outside the relation — e.g. a native
  Apple-Metal engine on a Linux node, or a managed arm carrying a `LinuxHost` — has no constructor.
- **Collection-level (grade-2 fold).** The cluster-wide compatibility check is a **total elementwise fold**
  over `NonEmpty Node`: every node's `(engine, substrate)` pair must satisfy the relation, and the fold
  returns the full list of incompatible nodes (not just the first), like `validateTopology`
  ([pulsar_client_doctrine.md §6](./pulsar_client_doctrine.md#6-the-declarative-topology-algebra)). Because it
  is elementwise, heterogeneous multi-substrate is legal by construction; only the incompatible *pair* is
  rejected.
- **The node inventory is the single owner of "what substrates exist."** The relation reads the closed
  substrate catalog and the per-host node inventory owned by [substrate_doctrine.md](./substrate_doctrine.md)
  (§4.4 ownership index), so the compatibility check is against one authoritative list, never a guess.

```mermaid
flowchart LR
  engine[Declared ComputeEngine: Kind or Rke2 or Managed Eks] -->|needs a host of the right kind| host{Compatible host witness available?}
  host -->|linux-cpu or linux-cuda| direct[LinuxHost is the host itself]
  host -->|apple| lima[LinuxHost only via limaHost, Lima VM]
  host -->|windows| wsl[LinuxHost only via wsl2Host, WSL2 distro]
  host -->|managed| slot[Hostless provider slot, no LinuxHost]
  direct -->|compatible-pair smart ctor| node[Node]
  lima --> node
  wsl --> node
  slot --> node
  node -->|elementwise fold over NonEmpty Node| topo[Topology, incompatible pair yields Left]
  topo -->|capacity fold| cap[resource_capacity place fold]
```

---

## 6. Where topology meets capacity and lifecycle

This doctrine owns the *shape* of a legal cluster; two siblings own what rides on it:

- **Capacity.** `resource_capacity`'s `place` fold ranges over *this* `Topology` — the summed workload demand
  against the summed node capacity ([resource_capacity_doctrine.md §4](./resource_capacity_doctrine.md)).
  Topology owns the node set; capacity owns the arithmetic over it.
- **Lifecycle.** The bring-up, spawn, teardown, and dynamic-provisioning *verbs* over these engines are owned
  by [cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md) (the root-single-node rule in §2, the
  provider-managed vs self-managed split in §1). This doc supplies the *types* those verbs act on; it does not
  restate the verbs. Dynamic growth of the node set is a `ScalingPolicy`
  ([resource_capacity_doctrine.md §6](./resource_capacity_doctrine.md)) enacted as Pulumi node provisioning
  ([pulumi_iac_doctrine.md §4](./pulumi_iac_doctrine.md#4-what-pulumi-provisions-the-resource-catalog)).

> **Honesty.** Everything here is Phase-0 design intent. The type demands (§3-§5) are grade-1/grade-2
> spec-layer properties *when implemented as specified* (Phase 3); the runtime residue — the VM actually
> booting, N rke2 nodes actually joining on N hosts, an EKS cluster actually coming up — is grade-3, owned by
> the Phase 7/9/10 gates and [chaos_failover_doctrine.md](./chaos_failover_doctrine.md). Where a mechanism
> generalizes hostbootstrap's virtualization providers or prodbox's EKS reality, that is sibling evidence,
> not amoebius proof ([documentation_standards.md §6](../documentation_standards.md)).

---

## 7. Planning ownership

This document is normative topology doctrine only. Delivery sequencing, completion status, and validation
gates are owned by [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md): the `ComputeEngine` /
`LinuxHost` / `Topology` types and the compatibility relation land in **Phase 3** (with the negative `.dhall`
gate); the Lima `LinuxHost` witness is exercised on **Phase 7** (`apple`); live multi-node rke2/kind topology
on **Phase 9**; the `Managed Eks` arm on **Phase 10**. This doc never maintains a competing status ledger; it
states the target shape and links back for status, per [documentation_standards.md §6](../documentation_standards.md).

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Substrate Doctrine](./substrate_doctrine.md) — the detected substrate catalog, virtualization providers, and node inventory this axis ranges over
- [Illegal State Catalog](./illegal_state_catalog.md) — the catalog (§3.13-§3.16, §3.24) and technique (§4.7) this doctrine realizes
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md) — the `place` fold over this `Topology`, and the `ScalingPolicy` (§6) that grows the `agents` list while server quorum stays declared
- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md) — the bring-up / spawn / teardown verbs over these engines, including the rke2 server/agent rollout (reconciler tier (b))
- [Pulumi IaC Doctrine](./pulumi_iac_doctrine.md) — provisioning the `Managed Eks` arm and dynamic nodes
- [DSL Doctrine](./dsl_doctrine.md) — the surface that carries the `ComputeEngine` field
- [Apple Metal Headless Builds](./apple_metal_headless_builds.md) — the distinct "no VM for Metal builds" carve-out
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
