# Illegal States — Storage

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/content_addressing_doctrine.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_topology.md, documents/engineering/monitoring_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md
**Generated sections**: none

> **Purpose**: The themed slice of the illegal-state catalog covering durable storage, bounded backing, and
> Pulsar retention — the states a valid `InForceSpec` cannot represent for how data is stored, sized, and
> retained.

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog: the durable-storage, bounded-backing, and
Pulsar-retention entries, faithfully reproduced with their original numbers and headings so inbound links
stay stable. It is not self-contained framing — it owns only the deep treatment of its entries.

- The **catalog index** (which states are illegal, the full §3.x list) and the **honesty limit** (a
  type-check proves the *spec composes*, not that the *running cluster enforces it*) are owned by
  [`illegal_state_catalog.md`](./illegal_state_catalog.md) — referenced here, not restated.
- The **seven typing techniques** (§4), the **coverage matrix** (§5), the **three-layer foreclosure**
  (§6), and the **validation-locus axis** (the orthogonal question of *where* each state is caught —
  `Gate-1-editor`, `Gate-2-decoder`, `rendered-output-golden`, `live-effect`) are owned by
  [`illegal_state_techniques.md`](./illegal_state_techniques.md) — referenced here, not restated.

Everything below is **design intent** (per [`illegal_state_techniques.md` §6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)):
a type-check proves the spec composes into something internally coherent; it does **not** prove the running
cluster's PVC is bound, its disk is unfilled, or its bookies are healthy. Each entry names a **Layer** (the
foreclosure layer, from [`illegal_state_techniques.md`](./illegal_state_techniques.md) §6) and a
**Validation-locus** (the new orthogonal axis — where authoring/decoding/rendering/runtime catches it).

---

## 2. The storage illegal states

### 3.1 Bad / illegal durable storage

Raw k8s permits mixing arbitrary storage classes, dynamic provisioners, and unsized claims, so "durable"
data can quietly live on an ephemeral, auto-provisioned volume that vanishes with the node. amoebius admits
**only** `no-provisioner`, explicitly-sized, retained PVs — the dynamic-provisioner
path, the unsized claim, and the un-selected default storage class are simply not constructible.
**Owner:** [`storage_lifecycle_doctrine.md`](../engineering/storage_lifecycle_doctrine.md). **Technique:** [§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction)
(PVC↔PV binding by construction) + refined non-zero sizes.
**Validation-locus:** `Gate-1-editor` (the dynamic-provisioner path, the unsized claim, and the un-selected
default class are non-constructible — required-field / no-arm shapes that fail `dhall type` at authoring) +
`live-effect` residue (that the retained PV actually binds at reconcile, owned by the runtime-enforcement proof).

### 3.2 PVCs that don't bind PVs

The canonical k8s silent-failure hazard: a StatefulSet's `volumeClaimTemplate` and the cluster's PVs are two independent
objects that bind only if their sizes, access modes, and selectors happen to match — and a typo means a pod
hangs in `Pending` forever. amoebius removes the independence: there is no way to declare a claim *without*
its exactly-matching PV ([§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction)). The mismatched pair has no inhabitant. **Owner:**
[`storage_lifecycle_doctrine.md`](../engineering/storage_lifecycle_doctrine.md). **Technique:** [§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction).
**Validation-locus:** `Gate-1-editor` (the mismatched claim/PV pair has no inhabitant — the required
exactly-matching PV field fails `dhall type` at authoring) + `live-effect` residue (that the running PVC
actually binds its PV at reconcile, owned by the runtime-enforcement proof).

### 3.18 Unbounded storage anywhere

Raw k8s lets a volume grow until it fills the disk; "unbounded" is the default. amoebius admits storage that
is **either** host-level (bounded by a physical disk) **or** cloud (bounded by a quota) — the closed
`StorageBacking` union has **no unbounded arm**, so unbounded storage has no syntax, and the aggregate
`Σ(sizes) ≤ backing` fold bounds the total. **Owner:**
[`storage_lifecycle_doctrine.md` §5.2](../engineering/storage_lifecycle_doctrine.md#52-the-storage-backing-is-bounded--the-closed-storagebacking-union) (the union shape) +
[`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) (the aggregate). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(closed `StorageBacking` union — type-foreclosed) + [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked) (aggregate backing fold — decode-foreclosed). **Layer:** decode-foreclosed aggregate;
the union shape is type-foreclosed.
**Validation-locus:** `Gate-1-editor` (the closed `StorageBacking` union with no unbounded arm fails
`dhall type` at authoring) + `Gate-2-decoder` (the aggregate `Σ(sizes) ≤ backing` fold returns `Left` in the
total decoder).

### 3.19 An application consuming more storage than its backing (MinIO and Pulsar)

Even with each volume bounded, the *sum* of an app's object usage and a topic's retained bytes can exceed the
backing. amoebius folds cumulative store size against the selected `StorageBacking` for **both** MinIO
(`<app>/<bucket>` buckets) and Pulsar (retained topic bytes); "unbounded" is representable only through a
`Growable` scaling policy whose ceiling is itself a quota ([§3.21](#321-capacity-growth-without-an-amoebius-owned-scaling-policy)). **Owner:**
[`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) +
[`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) (the MinIO store) +
[`pulsar_client_doctrine.md`](../engineering/pulsar_client_doctrine.md) (topic retention). **Technique:** [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
(cumulative-size ≤ backing fold) + [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (the `Growable` arm gates unboundedness). **Layer:** decode-foreclosed.
**Validation-locus:** `Gate-2-decoder` (the cumulative-size ≤ backing fold over MinIO buckets and retained
Pulsar bytes returns `Left` in the total decoder) + `Gate-1-editor` (the `Growable` arm that gates
unboundedness is a closed union checked at authoring).

### 3.20 A Pulsar topic without a bounded / tiered / retained lifecycle

Raw Pulsar lets a topic keep bytes forever, or offload on a **time-only** trigger that never bounds the hot
tier — so if ingest outpaces the offload lag, BookKeeper fills, bookies go read-only, and the topic (often
the broker) goes **unavailable**. amoebius makes a topic's `RetentionPolicy` a **mandatory, non-optional**
field with a **mandatory size-triggered S3 offload** (time may offload *sooner* for cost but is never the
sole trigger — a time-only policy is uninhabitable), and folds two ceilings: the hot-tier cap **plus
headroom** against the BookKeeper backing (the availability fit) and the retained total against the offload
target (the durability fit). A mandatory backlog quota is the runtime fail-safe. **Owner:**
[`pulsar_client_doctrine.md` §6](../engineering/pulsar_client_doctrine.md#6-the-declarative-topology-algebra) (the policy
shape) + [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) (the two-ceiling fold).
**Technique:** [§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction) (mandatory `RetentionPolicy` + mandatory size offload — no forever-local arm) + [§4.6](./illegal_state_techniques.md#46-capacity-accounting--placement-witness-compute-and-summed-demand-within-capacity-storage-checked)
(retention-budget room-fit). **Layer:** type-foreclosed for the mandatory shape; decode-foreclosed for both room-fits; runtime-checked residue
— the burst back-pressure actually holding.
**Validation-locus:** `Gate-1-editor` (the mandatory `RetentionPolicy` with a mandatory size-triggered
offload — no forever-local / time-only arm — fails `dhall type` at authoring) + `Gate-2-decoder` (both
room-fit ceilings, the availability fit and the durability fit, are total decoder folds) + `live-effect`
residue (the burst back-pressure and backlog quota actually holding at runtime).

### 3.21 Capacity growth without an amoebius-owned scaling policy

"Just let it autoscale to infinity" is how a bounded budget quietly becomes unbounded. amoebius makes growth
representable **only** through a `Growable = Bounded | Autoscaled ScalingPolicy` union with **no
bare-unbounded arm**: the sole path past a fixed cap carries a typed `ScalingPolicy` (capacity thresholds,
instance price-shopping, a quota cap), and amoebius owns that logic. The fold re-runs against the grown bound,
so "unbounded" storage/compute exists only behind a policy whose ceiling is a quota. **Owner:**
[`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) (with enaction owned by
[`cluster_lifecycle_doctrine.md` §8](../engineering/cluster_lifecycle_doctrine.md#8-dynamic-node-provisioning) and
[`pulumi_iac_doctrine.md` §4](../engineering/pulumi_iac_doctrine.md#4-what-pulumi-provisions-the-resource-catalog)).
**Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (closed `Growable` union, no unbounded arm). **Layer:** type-foreclosed representation; runtime-checked that
the autoscaler actually grows capacity and the cloud honors the quota.
**Validation-locus:** `Gate-1-editor` (the closed `Growable = Bounded | Autoscaled ScalingPolicy` union with
no bare-unbounded arm fails `dhall type` at authoring) + `live-effect` residue (that the autoscaler actually
grows capacity and the cloud honors the quota).

---

## Cross-references

- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the authoritative catalog index (the full §3.x
  list) and the load-bearing honesty limit (a type-check proves the spec composes, not that the cluster
  enforces it); this document is the storage slice carved from it.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the seven typing techniques (§4), the
  coverage matrix (§5), the three-layer foreclosure (§6), and the validation-locus axis referenced by every
  entry above.
- [`dsl_doctrine.md`](../engineering/dsl_doctrine.md) — the DSL surface and the contract that a valid `InForceSpec`
  cannot represent illegal state.
- [`storage_lifecycle_doctrine.md`](../engineering/storage_lifecycle_doctrine.md) — owner of the no-provisioner /
  explicitly-sized / retained-PV rule and the PVC↔PV binding-by-construction discipline ([§3.1](#31-bad--illegal-durable-storage), [§3.2](#32-pvcs-that-dont-bind-pvs)),
  and the closed `StorageBacking` union shape ([§3.18](#318-unbounded-storage-anywhere)).
- [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) — owner of the aggregate `Σ ≤ backing`
  capacity-accounting folds and the `Growable` scaling-policy discipline ([§3.18](#318-unbounded-storage-anywhere), [§3.19](#319-an-application-consuming-more-storage-than-its-backing-minio-and-pulsar), [§3.20](#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle), [§3.21](#321-capacity-growth-without-an-amoebius-owned-scaling-policy)).
- [`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) — owner of the MinIO content store
  whose per-bucket usage the storage fold sums ([§3.19](#319-an-application-consuming-more-storage-than-its-backing-minio-and-pulsar)).
- [`pulsar_client_doctrine.md`](../engineering/pulsar_client_doctrine.md) — owner of topic retention and the
  `RetentionPolicy` shape with its mandatory size-triggered offload ([§3.19](#319-an-application-consuming-more-storage-than-its-backing-minio-and-pulsar), [§3.20](#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)).
- [`cluster_lifecycle_doctrine.md`](../engineering/cluster_lifecycle_doctrine.md) and
  [`pulumi_iac_doctrine.md`](../engineering/pulumi_iac_doctrine.md) — owners of the enaction of a `ScalingPolicy` (dynamic
  node provisioning, the provisioned resource catalog) that [§3.21](#321-capacity-growth-without-an-amoebius-owned-scaling-policy) gates.
