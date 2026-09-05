# Substrate node inventory

> **Purpose**: Define the node inventory — the typed projection of host facts that owns which hosts and
> substrates exist, how much each advertises, which taints each node carries, and where each sits.
> **Read this if**: a fold, a topology relation, or a scheduler has to read what a host offers.

This document owns the node inventory and nothing else: the declaration, its closed `NodeTaintKind` set,
the physical-host total behind a host worker, the accelerator-memory shape, and the declared `Site`. It does
not own the substrate itself — what a substrate is, how it is detected, and the tool-ensure contract that
follows — owned by [substrate_doctrine.md](./substrate_doctrine.md), of which this is a slice.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Every phase-run or implementation-result statement in this document is permanently invalidated diagnostic history. It cannot establish or reactivate current status, even if a phase later advances. Target doctrine remains normative; current status is solely in the [tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 8. The node inventory: the single owner of hosts, capacity, and taints

The substrate is a *fact about the host* ([§1](./substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)); the **node inventory** is the typed projection of those facts
that the rest of amoebius reads. It is the **single owner** (an ownership index,
[illegal_state_catalog.md §4.4](../illegal_state/illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally)) of three things no other doc may re-declare:
*which hosts/substrates exist*, *how much each host advertises*, and *which taints a node carries*. Three
consumers read it, and each is a foreclosure that depends on there being exactly one such list.

**Phase-9 read-side bound contract.** The
[Phase 9 gate](../../DEVELOPMENT_PLAN/phase_09_resource_index.md) validates the capacity/topology fold
against authored in-process `NodeCapacity`, host, candidate-class, taint, and quota values.
It performs no live inventory read. The required `declared allocatable ≤ observed allocatable` cross-check,
filesystem/runtime metadata observation, VM boot, and node join therefore remain **UNVERIFIED** until their
owning live phases.

### Per-host/node `Capacity` (allocatable)

Each inventory entry advertises declared CPU, memory, logical pod-local ephemeral storage, and a closed
`KubeletFilesystemLayout` with named physical backing(s): `Unified` means `nodefs=imagefs=containerfs`;
`SplitRuntime` means separate nodefs and `imagefs=containerfs`; `SplitImage` means separate imagefs and
`containerfs=nodefs`. The inventory also pins `NodeImageStorageModelVersion`,
`KubeletRuntimeMetadataModelVersion`, and finite `CpuOvercommitPolicy = NoCpuOvercommit |
BoundedCpuOvercommit RatioAtLeastOne` used to bound summed rendered CPU limits. The runtime-metadata model
is part of `NodeCapacity.localStorage`: it is the authoritative kubelet/CRI versioned supply-side model
under which provisioning derives sandbox, pod-directory, runtime, CNI, volume, and mount components for each
planned slot and distinct live Pod UID. The model assigns each component a closed kubelet-nodefs or
CRI-runtime-root role; the layout resolves that role to its actual backing. It is not a pod-authored byte
reserve or route. Every elastic `PerInstanceNodeLocalStorageTemplate` pins the same field, which becomes the
materialized node's model and must match the live kubelet/CRI observation after that node joins. A
Kubernetes node carries `None | CudaOffering { devices : NonEmpty AcceleratorDevice, links : List
AcceleratorLink }`; a physical host additionally admits `AppleMetalOffering MetalProfile`. CUDA devices
carry stable identity/profile plus per-device raw/reserved/net-allocatable VRAM plus the endpoint-validated
peer/NVLink graph, while `currentFreeVram : Residual Bytes` (including `Zero`) is observed for live
admission; the Apple offering carries no separate memory pool because its demand is charged to physical-host
memory. The accelerator-memory shape is
[§8.2](#82-accelerator-memory-vram-unified-on-apple-per-device-on-cudawindows); the physical-host total
behind a host worker is
[§8.1](#81-the-physical-host-total-vs-the-vms-allocatable-the-host-worker-fold-operand). Kubernetes image
bytes are not part of a pod's logical `ephemeral-storage` request, but they do consume the layout's physical
filesystem. The platform-selected OCI index/manifest/config/compressed-layer objects are deduplicated by
digest, snapshotter bytes by chain id, and pull/import workspace by the declared concurrency policy;
writable layers are routed to imagefs for `SplitRuntime` and nodefs otherwise. Per-Pod CRI components follow
the model-selected runtime role: on `SplitRuntime` the persistent CRI root resolves to
`containerfs=imagefs`, while kubelet/CNI/pod-directory components resolve to nodefs. `Unified` and
`SplitImage` resolve containerfs to nodefs. Distinct components whose roles alias are summed, then the one
physical backing is checked once. A node-level ownership witness proves the Pod metadata model and image
storage model partition runtime component ids exactly and disjointly. Each advertised quantity is the
**allocatable** (schedulable) capacity — the raw hardware total with kube/system-reserved and the eviction
threshold already netted out — **not** the raw figure, so the fold never trusts more than the scheduler can
hand out. This is the number the capacity fold
([resource_capacity_doctrine.md §4](./resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting))
packs a workload/VM/engine `Demand` against, and the number the detection classifier
([§2](./substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads)) cross-checks against reality at runtime —
*allocatable against allocatable* (the declared value is a ceiling the fold trusts; a host whose real
allocatable is smaller than its declaration refuses,
[resource_capacity_doctrine.md §8](./resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime)).
Detection reads the *real* numbers; the inventory *declares* them; the fold trusts the declaration and the
reconcile checks it. The CPU-overcommit arm is declared policy rather than a probed hardware fact, but its
ratio is finite and enters the same pure fold.

### The filesystem layout is an observed fact

At bootstrap and every live preflight, the inventory records the kubelet/CRI-reported layout together with
each role's mount id, device/filesystem id, project/quota id where used, allocatable bytes, containerd
content root, snapshotter root, configured pull concurrency, the active
`KubeletRuntimeMetadataModelVersion`, its component→role catalog, and the disjoint Pod-metadata/image-model
ownership domains. Only the aliases required by the selected constructor are legal. An unexpected alias,
swapped root, unknown capacity, untracked extra mount below `/var/lib/kubelet`, `/var/log`, or the runtime
root, or a hard-cap probe that escapes its carve is `FilesystemLayoutMismatch`, never spare capacity.
Current v1 containerd engines can witness only `Unified` or `SplitRuntime`; `SplitImage` requires a
runtime/feature witness that containerd cannot provide.

### A closed `NodeTaintKind` set

Taints are not free strings — the set of taint kinds a node may carry is a
**closed union** owned here, exactly as the substrate catalog and `HostTool` enum are closed ([§1](./substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob), [§3](./substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)). This
is what lets a **`Toleration` be *derived*, never hand-authored**: the platform derives a workload's
tolerations from the declared node taints ([platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)),
so "a toleration for a taint no node declares" is unrepresentable and "a taint no workload tolerates" leaves
the schedulability existence fold with no landable node
([illegal_state_catalog.md §3.5, §3.22](../illegal_state/illegal_state_capacity.md#35-undeployable-pods-taints-tolerations--affinity)).

```text
NodeTaintKind =
  < ControlPlane
  | ManagedCapacity
  >

NodeTaint =
  { kind   : NodeTaintKind
  , key    : KubernetesTaintKey
  , value  : KubernetesTaintValue
  , effect : < NoSchedule >
  }

nodeTaint ControlPlane =
  { kind = ControlPlane, key = platform control-plane key, value = "true", effect = NoSchedule }
nodeTaint ManagedCapacity =
  { kind = ManagedCapacity, key = "amoebius.dev/managed-capacity",
    value = "reserved", effect = NoSchedule }
```

The constructors, keys, values, and effects are a single mapping. In particular, `ManagedCapacity` is not a
second scheduler-local string: the capacity scheduler's taint projection, its derived toleration, admission
rule, and live Node readback all carry this exact `NodeTaint` value.

### The `LinuxHost` witnesses and substrate tags the topology relation reads

The declared compute-engine axis ([cluster_topology_doctrine.md](./cluster_topology_doctrine.md)) pairs an
engine with a node only when the relation permits it, and it reads *this* inventory for "what substrates
exist" — so the compatibility fold (I2) and the `LinuxHost`-witness gating (I1) are checked against one
authoritative list. On apple and windows the only `LinuxHost` constructor is the virtualization provider
([§4](./substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)), which is why an
rke2/kind cluster on those hosts must interpose a Lima/WSL2 Linux VM. Linux hardware may construct the witness
natively, but a pristine-host gate constructs it through Incus.

This document owns the inventory *record*, the closed `NodeTaintKind` set, and the per-host `Capacity`
*declaration* — including the **physical-host total and disjoint disk-pool partition** behind a host worker
([§8.1](#81-the-physical-host-total-vs-the-vms-allocatable-the-host-worker-fold-operand)),
the unified-vs-discrete accelerator-device/**`vram`** shape ([§8.2](#82-accelerator-memory-vram-unified-on-apple-per-device-on-cudawindows)),
and the declared **`Site`** ([§8.3](#83-site-the-declared-network-locality-axis-cluster-nodes-and-host-worker-hosts));
it does **not** own the capacity arithmetic ([resource_capacity_doctrine.md](./resource_capacity_doctrine.md)),
the compute-engine relation ([cluster_topology_doctrine.md](./cluster_topology_doctrine.md)), or the
toleration-derivation rule ([platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)). It is the
single list they all read.

### 8.1 The physical-host total vs the VM's allocatable (the host-worker fold operand)

The per-host `Capacity` above is the number the **in-cluster** bin-pack trusts, and on apple/windows the only
`LinuxHost` it describes is the Lima/WSL2 **VM's** kube-allocatable ([§4](./substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)).
A host that *also* runs a **host worker** ([§5](./substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-cannot-be-containerized))
needs a second, larger declaration: the **physical-host total** — the whole bare machine's allocatable
CPU, memory, and local storage — against which the host-tier fold packs *both* the VM's carve and the host
worker's `Demand`. Local storage is partitioned by identity into disjoint top-level pools: system reserve, VM
  disk backings, retained-PV backing, host-shared/build cache, purpose-tagged
  `HostWorkerLocal`/`BuildScratch`/`ToolInstall` pools, and, on direct Linux, separate kubelet pod-ephemeral and
  image storage **only when the selected layout actually separates their backing**. `Unified` has one nodefs
  carve; `SplitRuntime`/`SplitImage` have distinct nodefs/imagefs carves, with containerfs an alias rather than
  a third pool. Each typed logical backing id resolves to exactly one correctly tagged physical carve.
  For Lima/WSL2, guest layout filesystem carves are sub-budgets of the VM disk
  (`guest OS/system reserve + Σ unique layout usable parent debits ≤ VM requiredUsableBytes`); presentation
  and allocation geometry then derive the VM's raw `provisionedBytes`, which is charged once to physical
storage. `PhysicalDiskPartition.allocatableRawBytes` is the finite raw physical boundary after unmanaged-host
reserve and before every amoebius child carve, including `systemReserve`. The top-level sum that packs those
debits — systemReserve, the VM `provisionedBytes`, and the direct-node/retained/cache/host-storage raw parent
debits — against `allocatableRawBytes` is owned by [resource_capacity_doctrine.md §4](./resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting).
A parent-indexed `NamedDiskCarve PhysicalRawExtent` contributes a
private raw parent debit; a `NamedDiskCarve VmGuestUsableExtent` contributes only to the separate nested VM
usable-byte proof and cannot enter the physical sum. No child may be deducted once to manufacture the
boundary and again in that sum. The same physical byte cannot appear in two top-level pools, and every child
carve must fit its correctly typed parent boundary. This
inventory declares that physical-host total as a distinct per-host figure, and the host binary's **own**
footprint is **netted into system-reserved** on it (exactly as kube/system-reserved is netted out of the VM's
allocatable), so the physical-host fold stays two-claimant — VM carve + worker `Demand` ≤ physical-host
allocatable — and the host binary is never a third un-owned claimant. This doc owns the **declaration** of the
physical-host total and the system-reserved netting; the **fold arithmetic** (a checked `Left Overcommit` at
the post-bind provision seal) is [resource_capacity_doctrine.md §4](./resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)'s,
and the host-worker `Demand` it consumes is declared by
[platform_services_doctrine.md §10](./platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope).

<a id="82-accelerator-memory-vram-unified-on-apple-discrete-on-cudawindows"></a>

### 8.2 Accelerator memory (`vram`): unified on apple, per-device on cuda/windows

A worker that serves models needs an **accelerator-memory** figure, and the **shape** of that figure is
substrate-specific — a fact this inventory declares so the capacity fold downstream stays branch-free:

- **apple (Metal, unified memory).** GPU and CPU share **one** pool, so the per-host `Capacity` declares
  an `AppleMetalOffering` with a compatible `MetalProfile` but **no separate `vram`**. Downstream
  provisioning derives every allowed coexistence epoch of the identity-complete `MetalOwnerDemand`; each
  epoch's co-resident components are debited from the same physical-host `mem` as the VM, the worker's
  non-accelerator runtime memory, and system reserve
  ([§8.1](#81-the-physical-host-total-vs-the-vms-allocatable-the-host-worker-fold-operand)). It is a distinct
  demand field for explanation and validation, never a second supply pool.
  An `apple` host declaring a separate `vram` Capacity is an **uninhabitable per-host `Capacity` shape — type-foreclosed** (there is no unified-pool `vram` field to fill; the constructor does not exist).
- **linux-cuda / windows (CUDA, discrete memory).** The accelerator carries its own memory, not contended
  with the WSL2/Lima VM, so the per-host `Capacity` declares host `mem` plus a **non-empty device vector**.
  Every device entry carries a stable UUID/profile, `rawVram`, a non-optional
  `driverRuntimeReserve`, and `allocatableVram`, with
  `driverRuntimeReserve + allocatableVram ≤ rawVram`. The reserve covers driver/runtime/allocator and
  profile-specific safety headroom; it cannot be zeroed by omitting the field. Only `allocatableVram` enters
  the pure fold. Total allocatable VRAM is derived, never the only schedulability fact: two 24-GiB devices do
  not satisfy one 40-GiB `Unsharded` residency. A `CudaOwnerDemand` spanning devices must carry structural
  `ReplicatedPerDevice` or explicit `Sharded` placement whose complete epoch assignment fits each device and
  the requested interconnect.

This inventory is the **sole owner** of the per-host accelerator device vector/per-device `vram` **numbers**
and of the unified-vs-discrete `Capacity` **shape**. It does **not** own the fold that spends `vram` or host
memory: identity-complete `CudaOwnerDemand`/`MetalOwnerDemand` source and workload maps, structural
residencies, exact policy-class domains, and every derived coexistence epoch are owned downstream
([resource_capacity_doctrine.md §4](./resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting)),
**count** and **`vram`** are **cross-checked at runtime** against the [§2](./substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads)
`nvidia-smi` probe: a host over-declaring device count/profile, raw VRAM, or allocatable VRAM after its
mandatory reserve **refuses**
(`discover = Mismatch → refuse`, [cluster_lifecycle_doctrine.md §9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)),
keeping these axes declared-at-decode / cross-checked-at-runtime. The probe's `memory.free` is a separate,
time-varying live-admission operand: desired demand must fit the declared residual and observed
free-at-admission; unexplained use fails closed instead of being silently subtracted from the reserve.

### 8.3 `Site`: the declared network-locality axis (cluster nodes and host-worker hosts)

`Site` is a declared per-host inventory field — an opaque network-locality label answering *where the host
sits on the network* — and it is **orthogonal to the detected substrate** ([§1](./substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)):
a machine's `Site` is *where it is*, not *what it is*. It follows the same **declared-at-decode / cross-checked-at-runtime** discipline as the rest of the `Capacity` above: the inventory declares each host's
`Site`, and a host declaring a `Site` its reachability contradicts (a remote host mis-declared local) surfaces
at reconcile as the three-valued `discover = Unreachable → refuse`
([cluster_lifecycle_doctrine.md §9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine))
— so a declared-vs-real `Site` mismatch is runtime-checked residue, the ceiling every [§8](#8-the-node-inventory-the-single-owner-of-hosts-capacity-and-taints) declared fact lives
at. Crucially this inventory carries a `Site` for **both** kinds of host it lists: **in-cluster cluster `Node`s** *and* the **host-worker physical hosts** ([§5](./substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-cannot-be-containerized), whose per-host `Capacity` is [§8.1](#81-the-physical-host-total-vs-the-vms-allocatable-the-host-worker-fold-operand)'s operand). The fold that **classifies stretchedness** from these declared `Site`s — which node or host worker
is remote, and what reachability witness that demands — runs over **both** inventories and is owned by
[cluster_topology_doctrine.md §4.1](./cluster_topology_doctrine.md#41-rke2-serveragent-cardinality-odd-quorum-by-union-distinctness-by-fold-taint-by-derivation);
this doc owns only the declared `Site` **fact**, not the classification.

---

## Related Documents
- [Substrate Doctrine](./substrate_doctrine.md)
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md)
- [Cluster Topology Doctrine](./cluster_topology_doctrine.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
