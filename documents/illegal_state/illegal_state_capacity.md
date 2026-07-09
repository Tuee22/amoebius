# Illegal States — Capacity & Placement

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/cluster_topology_doctrine.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_topology.md, documents/engineering/platform_services_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/tenancy_doctrine.md
**Generated sections**: none

> **Purpose**: The themed slice of the illegal-state catalog covering capacity folds, placement /
> bin-packing, tolerations / affinity, and accelerator ownership / VRAM — the states a valid `InForceSpec`
> cannot represent, with the honest limit that a type-check proves the *spec composes*, not that the
> *running cluster enforces it*.

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog. It reproduces the deep treatment of the
capacity / placement / accelerator entries and adds, per entry, the orthogonal **validation-locus** axis.

The material this slice deliberately does **not** restate lives with its owners:

- The **catalog index** (which entries exist, the §1–§2 framing) and the **load-bearing honesty limit**
  (a type-check proves the *spec composes*, not that the *running cluster enforces it*) are owned by
  [`illegal_state_catalog.md`](./illegal_state_catalog.md).
- The **seven typing techniques** ([§4](./illegal_state_techniques.md)), the **coverage matrix** ([§5](./illegal_state_techniques.md)),
  the **three-layer foreclosure** model (type-foreclosed / decode-foreclosed / runtime-checked, [§6](./illegal_state_techniques.md)),
  and the **validation-locus axis** itself are owned by [`illegal_state_techniques.md`](./illegal_state_techniques.md).
  The four loci referenced below — `Gate-1-editor` (fails `dhall type` at authoring time), `Gate-2-decoder`
  (the total decoder returns `Left`), `rendered-output-golden` (caught by a golden test on the *rendered*
  manifest), and `live-effect` (only at reconcile / runtime) — are defined there; this slice only names,
  per entry, where each illegal state is caught.

The validation-locus is **orthogonal** to the foreclosure layer: the `**Layer:**` tag says *which of the
three foreclosure strengths* an entry earns (type-foreclosed vs decode-foreclosed vs runtime-checked), while
the `**Validation-locus:**` line says *at which gate in the pipeline* the check actually fires. Everything
below is **design intent** for the type discipline, not a tested amoebius result: a green type-check proves
the spec composes; it does not prove the cluster enforces it ([`illegal_state_catalog.md` §6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)).

---

## 2. The capacity & placement illegal states

### 3.5 Undeployable pods (taints, tolerations & affinity)

In raw k8s a nodeSelector / affinity can match **no** node, *or* a taint no workload
tolerates, *or* a toleration for a taint no node declares — the pod is admitted and then never schedules.
amoebius constrains placement so that a workload's substrate/affinity requirement **and** its taint
tolerations are checked against the *declared* node inventory of the cluster spec: the decode rejects a
workload unless **there exists** a node satisfying its affinity **and** tolerating all its taints — a
schedulability *existence fold* over the single node inventory. Placement is expressed as a capability the
workload *requests* and a node *offers*, and an unmatchable request is uninhabitable; a **toleration is never
hand-authored** — it is *derived* from a declared node taint (the same "derived, never written" discipline as
NetworkPolicy, [§3.6](./illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)), so "a toleration for a taint no node declares" is unrepresentable and "a taint no
workload tolerates" leaves the existence fold with no landable node. This strengthens the original
affinity-only entry to cover taints and tolerations. This entry checks placement *constraints*
(affinity/taints); the complementary *resource-fit* existence check — that a matching node also has enough
allocatable room once every other pod is placed, **and** that any accelerator demand is met by the node's
**wholesale accelerator owner** rather than a per-pod GPU claim — is [§3.27](#327-a-schedulable-in-aggregate-but-unplaceable-workload-atomic-pod--gpu-bin-packing),
and the two compose in `place`'s `podFits`: **substrate/affinity-capability existence** (this entry) ∘
**resource-fit existence** ([§3.27](#327-a-schedulable-in-aggregate-but-unplaceable-workload-atomic-pod--gpu-bin-packing)),
the latter now reading accelerator fit through the wholesale-per-node owner ([§3.28](#328-two-accelerator-owners-on-one-node-or-a-fractional-accelerator-claim)),
never a per-pod `gpu` axis. **Owner:**
[`substrate_doctrine.md`](../engineering/substrate_doctrine.md) (substrate/arch capabilities, the closed node-taint set +
node inventory) and [`platform_services_doctrine.md` §9](../engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) (the
derived-toleration rule, parallel to derived NetworkPolicy). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (capability tags) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (a
derived toleration handle exists only once its taint edge does) + [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally) (the node inventory is the single
owner of "what substrates and taints exist"), the existence check itself being a [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally) value-level fold. **Layer:**
decode-foreclosed for the existence fold; the derived-toleration shape is type-foreclosed ([§3.22](#322-a-hand-authored-un-derived-toleration)).
**Validation-locus:** `Gate-2-decoder` (the schedulability existence fold returns `Left` when no node satisfies
affinity and tolerates every taint) + `Gate-1-editor` (the derived-toleration shape has no hand-author
constructor, [§3.22](#322-a-hand-authored-un-derived-toleration)) + `live-effect` (residue — that the scheduler actually lands the pod on the
witnessed node).

### 3.17 An over-committed deploy or workload (host / VM / cluster capacity exceeded)

Raw k8s admits a workload requesting more cpu/mem than any node has, a VM or engine asking for more than its
host, or a cluster whose workloads out-total its nodes — each surfaces at runtime as `Pending`, eviction, or
a full disk. amoebius folds the typed `Demand` against the enclosing `Capacity` at every nesting level
(host → VM → guest; cluster → workload) and rejects an overflow at decode. Because capacity is a *value* not a
type index (Dhall has no dependent arithmetic), this is a **total decode-time check**, honestly decode-foreclosed —
never claimed uninhabitable. This entry is the **aggregate** overcommit (Σ demand exceeds Σ capacity); the
distinct case where a set fits in aggregate but an *atomic pod* fits no single node (bin-packing / indivisible
GPU) is [§3.27](#327-a-schedulable-in-aggregate-but-unplaceable-workload-atomic-pod--gpu-bin-packing), caught by
the same [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
placement fold. **Owner:** [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md)
(consuming the host numbers in [`substrate_doctrine.md`](../engineering/substrate_doctrine.md), the cpu/ram in
[`platform_services_doctrine.md` §10](../engineering/platform_services_doctrine.md#10-every-container-declares-cpu-and-ram),
and the PV sizes in [`storage_lifecycle_doctrine.md`](../engineering/storage_lifecycle_doctrine.md)). **Technique:** [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
(capacity-accounting total fold). **Layer:** decode-foreclosed.
**Validation-locus:** `Gate-2-decoder` (the `Σ Demand ≤ Capacity` fold at every nesting level returns `Left
Overcommit` on overflow) + `live-effect` (residue — that the running cluster stays within capacity: no
`Pending`, eviction, or full disk).

### 3.22 A hand-authored (un-derived) toleration

A free-text toleration is how a pod "tolerates" a taint no node carries (or fails to tolerate the one it
must). amoebius never lets an operator *write* a toleration: a `Toleration` handle has no exported
constructor and is **projected** only from a declared node taint against the single node inventory — the same
derive-don't-author discipline as NetworkPolicy ([§3.6](./illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)). So a toleration for a nonexistent taint is
unrepresentable, and the schedulability existence fold ([§3.5](#35-undeployable-pods-taints-tolerations--affinity)) does the rest. **Owner:**
[`substrate_doctrine.md`](../engineering/substrate_doctrine.md) (the closed `NodeTaintKind` set + node inventory) +
[`platform_services_doctrine.md` §9](../engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) (the derivation rule). **Technique:**
[§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally) (the node inventory is the single owner of what taints exist) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (a `Toleration` handle exists only
once its taint edge does). **Layer:** type-foreclosed uninhabitable.
**Validation-locus:** `Gate-1-editor` (the `Toleration` handle exports no hand-author constructor, so a
free-text toleration fails `dhall type` before any binary runs) + `rendered-output-golden` (the derived
toleration must appear correctly in the emitted pod spec, exactly as a golden test checks the derived
NetworkPolicy, [§3.6](./illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)).

### 3.27 A schedulable-in-aggregate but unplaceable workload (atomic-pod / GPU bin-packing)

Raw k8s admits a workload whose demand fits a cluster *in aggregate* but whose individual pods cannot be packed
onto individual nodes — a 5-CPU pod on a cluster of 4-CPU nodes (aggregate CPU sufficient, no single node big
enough). It is well-formed and admits, then hangs `Pending`
forever, because **pods are atomic and cannot straddle nodes**. (This round **retires** the companion
2-GPU-pod example: accelerators are no longer a per-pod bin-pack axis at all — a node's accelerators are owned
**wholesale** by that node's single accelerator worker ([§3.28](#328-two-accelerator-owners-on-one-node-or-a-fractional-accelerator-claim)),
reached only through that owner, so there is no per-pod `gpu` request that could fail to pack.) This is the resource-fit
generalization of [§3.5](#35-undeployable-pods-taints-tolerations--affinity): §3.5 asks whether *a node
matching affinity + tolerating taints exists*; this entry adds *with enough allocatable room, given everything
else placed*. amoebius makes the cluster check a **placement**, not a sum: for a **fixed** node set the decode
computes a concrete pod→node witness by bin-pack (`place`) and rejects `Left Unschedulable` if none exists; for
an **elastic** (autoscaled / `Managed Eks`) set it checks a growth envelope — every pod fits the largest
candidate instance and Σ-at-max-scale ≤ quota — that the autoscaler can always satisfy. The old aggregate-sum
([§3.17](#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)) does not catch this;
the placement does. **Owner:** [`resource_capacity_doctrine.md` §4.1](../engineering/resource_capacity_doctrine.md#41-place-branches-static-proves-a-placement-dynamic-proves-a-growth-envelope)
(the `place` witness/envelope; `Capacity` is *allocatable*, cpu/mem divisible; there is **no** per-pod `gpu` axis
— `ResourceVec = { cpu, mem }` and accelerators are reached only through the node's wholesale accelerator owner,
[§3.28](#328-two-accelerator-owners-on-one-node-or-a-fractional-accelerator-claim))
+ [`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) (the fixed-vs-elastic `Topology` shape that
selects the branch). **Technique:** [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
(the placement upgrade of the capacity fold). **Layer:** decode-foreclosed — a checked construction of a placement witness /
envelope proof, **sound-not-complete** (may reject a packable spec, never admits an unplaceable one); runtime-checked
residue — that the scheduler actually reproduces a feasible placement and the autoscaler actually grows, owned
by [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md).
**Validation-locus:** `Gate-2-decoder` (`place` constructs the pod→node bin-pack witness / growth envelope and
returns `Left Unschedulable` when none exists) + `live-effect` (residue — that the real scheduler reproduces a
feasible placement and the autoscaler actually grows the elastic set).

### 3.28 Two accelerator owners on one node, or a fractional accelerator claim

Raw k8s device-plugin scheduling lets two pods each claim a share of a node's accelerators, or a pod claim a
fraction, so ownership of a node's GPUs is diffuse and contended. This round **reframes** a node's accelerators
as owned **wholesale** by that node's **single accelerator worker** (`Cuda` or `AppleMetal`) — every other pod
uses the node's leftover cpu/mem but never its accelerators — and **introduces** a typed **per-node-singleton
accelerator-owner worker kind** (a DaemonSet-like node-affinity worker) in the daemon taxonomy, the witness type
the earlier N-replica unelected Deployment model lacked. So "two accelerator owners on one node" and "a per-pod
fractional accelerator claim" have **no constructor**. The one owner *multiplexes* train + serve + Tier-3 JIT on
the node, which is what lets a continuous job train while it serves ([§3.32](./illegal_state_ml_asset.md#332-a-continuous-training-run-with-no-checkpoint-cadence-or-a-feed-with-no-bounded-retention)).
**Owner:** [`daemon_topology_doctrine.md`](../engineering/daemon_topology_doctrine.md) (the worker taxonomy + the per-node
singleton kind), consumed by [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) (which this round
drops the per-pod `gpu` axis from — `ResourceVec = { cpu, mem }`). **Technique:** [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally)
(a per-node ownership index — one owner per node's accelerators) + [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(the closed accelerator-owner worker-kind union — no fractional-claim arm). **Layer:** type-foreclosed — the typed per-node
singleton gives the two-owner / fractional-claim state no inhabitant; runtime-checked residue — that the one owner
actually holds the devices at runtime.
**Validation-locus:** `Gate-1-editor` (the closed accelerator-owner worker-kind union has no fractional-claim
arm — a fractional claim fails `dhall type`) + `Gate-2-decoder` (the per-node ownership index — the fold rejects
a second accelerator owner on one node) + `live-effect` (residue — that the one owner actually holds the node's
devices at runtime).

### 3.29 A host worker whose Demand overflows its physical host

A host-level accelerator worker (an Apple-Metal or Windows-CUDA native subprocess,
[`substrate_doctrine.md`](../engineering/substrate_doctrine.md) §5) runs beside the Lima/WSL2 VM that backs the in-cluster
node, both drawing on the same **physical host**; raw tooling accounts neither, so a host binary that
over-subscribes surfaces at runtime as thrash or OOM. This round adds a **host → host-worker** arm to the
capacity nesting: a host worker's cpu/mem `Demand` folds against its **physical-host `Capacity`** (distinct from
the VM's kube-allocatable) alongside the VM carve, with the host binary's own footprint **netted into
system-reserved** so the fold stays two-claimant. VM-carve + host-worker Demand exceeding the physical host is a
**decode-foreclosed `Left Overcommit`** at decode — the host-tier analogue of the pod-tier aggregate overcommit
([§3.17](#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)); a host running a host
worker with **no** declared physical-host `Capacity` leaves the Demand unfoldable and is likewise a decode-foreclosed
decode rejection. **Owner:** [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) (the
host→host-worker fold arithmetic), consuming the host-worker `Demand` owned by
[`platform_services_doctrine.md` §10](../engineering/platform_services_doctrine.md#10-every-container-declares-cpu-and-ram)
(extended to "every container **and every host-level worker subprocess**") and the physical-host `Capacity` +
system-reserved netting owned by [`substrate_doctrine.md`](../engineering/substrate_doctrine.md) §8. **Technique:**
[§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
(the capacity-accounting total fold, host→host-worker arm). **Layer:** decode-foreclosed — a checked rejection of a
constructible value, never "unrepresentable" (a capacity check is decode-foreclosed, [§2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it));
runtime-checked residue — that the host kernel actually caps the subprocess.
**Validation-locus:** `Gate-2-decoder` (the host→host-worker fold returns `Left Overcommit` when VM-carve +
host-worker Demand exceeds the physical host, and `Left` when a host worker declares no physical-host
`Capacity`) + `live-effect` (residue — that the host kernel actually caps the subprocess).

### 3.30 A served model whose VRAM footprint exceeds node VRAM

Accelerator memory is finite and a served model's weights + KV-cache must fit in it, but raw serving permits
pointing an oversized model at a GPU, and the shortfall surfaces as a runtime OOM. Because the one accelerator worker
owns the node's accelerators wholesale ([§3.28](#328-two-accelerator-owners-on-one-node-or-a-fractional-accelerator-claim)),
VRAM is modeled **like storage, not like a `ResourceVec` request axis** — a per-node accelerator sub-capacity the
worker carves among the models it serves, a new **accelerator-worker → served-model** nesting arm folding
`Σ served-model VRAM ≤ node vram`. Memory topology is substrate-aware and pushed into **how the per-host
`Capacity` is declared** so the fold stays branch-free: `apple` (Metal, unified memory) declares **no** separate
`vram` (accelerator demand IS `mem` demand); `linux-cuda`/`windows` (CUDA, discrete) declare a separate `vram`
not contended with the VM. A served model whose declared footprint overflows node `vram` is a **decode-foreclosed** Σ
rejection; an accelerator model with an **undeclared** footprint passing the Σ vacuously is foreclosed
(accelerator models must declare a footprint, decode-foreclosed); an `apple` node declaring a separate `vram` violates
the unified pool and is an uninhabitable per-host `Capacity` shape (**type-foreclosed**). A model's producing-node
footprint does **not** transfer as the serving-node demand — the serve landing recomputes fit in the **serving
node's** memory topology. **Owner:** [`substrate_doctrine.md`](../engineering/substrate_doctrine.md) §8 (the per-host `vram`
number + unified-vs-discrete `Capacity` shape, sole owner) + [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md)
(the Σ arithmetic) + [`service_capability_doctrine.md`](../engineering/service_capability_doctrine.md) /
[`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) (the per-model VRAM footprint field, the Σ's
left operand). **Technique:** [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
(the accelerator-worker → served-model Σ sub-budget) + [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(the unified-vs-discrete `Capacity` shape closed by substrate). **Layer:** decode-foreclosed for the declared-footprint Σ;
**runtime-checked** residue — that the model **actually fits in VRAM at runtime** under real batch/context (dynamic
KV-cache / fragmentation), mirroring the `mem` cgroup ceiling behind the `mem` Σ; the unified-pool shape sub-part
is type-foreclosed.
**Validation-locus:** `Gate-2-decoder` (the `Σ served-model VRAM ≤ node vram` sub-budget fold returns `Left`,
and an undeclared accelerator footprint is rejected rather than passing the Σ vacuously) + `Gate-1-editor` (an
`apple` node declaring a separate `vram` is an uninhabitable per-host `Capacity` shape that fails `dhall type`) +
`live-effect` (residue — that the model actually fits in VRAM at runtime under real batch/context).

---

## Cross-references

- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the parent catalog: the full entry index, the
  §1–§2 framing, and the load-bearing honesty limit ([§6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)).
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the seven typing techniques ([§4](./illegal_state_techniques.md)),
  the coverage matrix ([§5](./illegal_state_techniques.md)), the three-layer foreclosure model ([§6](./illegal_state_techniques.md)),
  and the **validation-locus axis** the per-entry `**Validation-locus:**` lines above draw on.
- [`dsl_doctrine.md`](../engineering/dsl_doctrine.md) — the DSL surface and the contract that a valid `InForceSpec` cannot
  represent illegal state.
- [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) — the capacity-accounting folds and the
  `place` witness / growth-envelope (owner of [§3.17](#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded),
  [§3.27](#327-a-schedulable-in-aggregate-but-unplaceable-workload-atomic-pod--gpu-bin-packing),
  [§3.29](#329-a-host-worker-whose-demand-overflows-its-physical-host), and the Σ arithmetic for [§3.30](#330-a-served-model-whose-vram-footprint-exceeds-node-vram)).
- [`substrate_doctrine.md`](../engineering/substrate_doctrine.md) — substrate/arch capabilities, the closed node-taint set +
  node inventory, per-host `Capacity` (incl. §8 physical-host / VRAM numbers) cited by [§3.5](#35-undeployable-pods-taints-tolerations--affinity),
  [§3.17](#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded),
  [§3.22](#322-a-hand-authored-un-derived-toleration), [§3.29](#329-a-host-worker-whose-demand-overflows-its-physical-host), and [§3.30](#330-a-served-model-whose-vram-footprint-exceeds-node-vram).
- [`platform_services_doctrine.md`](../engineering/platform_services_doctrine.md) — the derived-toleration rule (parallel to
  derived NetworkPolicy) and the cpu/ram-per-container rule ([§10](../engineering/platform_services_doctrine.md#10-every-container-declares-cpu-and-ram),
  extended to host-level worker subprocesses), cited by [§3.5](#35-undeployable-pods-taints-tolerations--affinity),
  [§3.17](#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded),
  [§3.22](#322-a-hand-authored-un-derived-toleration), and [§3.29](#329-a-host-worker-whose-demand-overflows-its-physical-host).
- [`storage_lifecycle_doctrine.md`](../engineering/storage_lifecycle_doctrine.md) — the PV sizes consumed by the aggregate
  overcommit fold ([§3.17](#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)).
- [`cluster_topology_doctrine.md`](../engineering/cluster_topology_doctrine.md) — the fixed-vs-elastic `Topology` shape that
  selects the `place` branch ([§3.27](#327-a-schedulable-in-aggregate-but-unplaceable-workload-atomic-pod--gpu-bin-packing)).
- [`daemon_topology_doctrine.md`](../engineering/daemon_topology_doctrine.md) — the worker taxonomy and the per-node-singleton
  accelerator-owner worker kind ([§3.28](#328-two-accelerator-owners-on-one-node-or-a-fractional-accelerator-claim)).
- [`service_capability_doctrine.md`](../engineering/service_capability_doctrine.md) /
  [`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) — the per-model VRAM footprint field, the
  Σ's left operand for [§3.30](#330-a-served-model-whose-vram-footprint-exceeds-node-vram).
- [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md) — the runtime-enforcement proof for the
  placement / capacity residue (the scheduler reproducing a feasible placement, the autoscaler growing), owed by
  [§3.27](#327-a-schedulable-in-aggregate-but-unplaceable-workload-atomic-pod--gpu-bin-packing).
