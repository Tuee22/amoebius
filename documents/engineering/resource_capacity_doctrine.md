# Resource Capacity

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/illegal_state_catalog.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md
**Generated sections**: none

> **Purpose**: Single Source of Truth for the amoebius capacity model — the `Capacity` / `Demand` / `Budget`
> types, the total *capacity-accounting fold* that rejects any deploy whose summed demand exceeds its
> enclosing capacity (host → cluster/VM → workload, and storage), the closed `StorageBudget` union that makes
> *unbounded* storage unrepresentable, and the `Growable` / `ScalingPolicy` escape valve that is the **only**
> way a bounded budget grows.

---

## 1. The one idea: capacity is a budget you fold against, and overcommit is a checked rejection

Raw Kubernetes lets you admit a Deployment that requests more memory than any node has, a StatefulSet whose
volumes sum past the disk, or a cluster whose workloads out-total its nodes. Each is well-formed YAML; each
surfaces at runtime as a `Pending` pod, an evicted workload, or a full disk. amoebius lifts that whole class
to *does-not-decode*: a deploy is a **total fold** of typed demands compared against a single-owner capacity,
and a fold that overflows returns `Left Overcommit` — the spec never reaches the interpreter.

This document owns the *capacity arithmetic* and nothing else. It owns:

1. The `Capacity` / `Demand` / `Budget` records and the refined non-zero `Quantity` they are built from ([§3](#3-the-types-quantity-capacity-demand-budget)).
2. The total fold — `fits` / `carve` / `place` — and its nesting (host → cluster/VM → workload) ([§4](#4-the-total-fold-fits-carve-place-and-the-nesting)).
3. The closed `StorageBudget` union — no *unbounded* arm — and how each arm names its single ceiling owner
   ([§5](#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)).
4. The `Growable` / `ScalingPolicy` escape valve: dynamic provisioning owned by amoebius, the only path by
   which a bounded budget grows ([§6](#6-growable--scalingpolicy-the-escape-valve-amoebius-owns)).

It **consumes, never restates**, the domain numbers it folds: the per-host capacity the node inventory
advertises ([substrate_doctrine.md](./substrate_doctrine.md)), the per-volume hard-capped PV sizes
([storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md)), the per-container cpu/ram
([platform_services_doctrine.md §10](./platform_services_doctrine.md#10-every-container-declares-cpu-and-ram)),
the cloud quota ([pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md)), and the Pulsar topic retention
([pulsar_client_doctrine.md](./pulsar_client_doctrine.md)). Each number has exactly one owner elsewhere; this
doc owns only the *sum-does-not-exceed* relation over them. The **catalog** of which capacity states are
illegal and the technique that forecloses them is
[illegal_state_catalog.md §3.17-§3.21 / §4.6](./illegal_state_catalog.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded); this doc is the normative home of
the model that catalog names.

Everything below is **design intent for Phase 3** (the type discipline) with runtime realization in Phases
2/4/7/10. Status and gates live only in
[../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md).

---

## 2. The load-bearing honesty limit: a capacity sum is a grade-2 check, never grade-1

This is the most important sentence in the document, so it gets its own section. **`Σ demand ≤ capacity` is a
grade-2 foreclosure — a total decode-time check — never a grade-1 uninhabitable-by-type proof.** Dhall (and
the GADT-indexed Haskell it decodes into) has **no dependent arithmetic**: capacity is a *value*, not a type
index, so "the sum fits" cannot be a statement about type inhabitance. It is a **total smart constructor / fold**
that inspects a constructible value and rejects it (`Left Overcommit`) at decode. Per the three foreclosure
grades ([illegal_state_catalog.md §6](./illegal_state_catalog.md#6-three-grades-of-foreclosure-and-the-honesty-they-force)),
this is grade (2): a *spec-layer guarantee* (the spec never reaches the interpreter), but a *checked rejection*,
not an absence of inhabitants. Any doc that calls a capacity sum "uninhabitable" is reporting the wrong grade,
and this doc forbids that.

The grade-1 pieces near capacity live elsewhere and are cited, not claimed here: the `StorageBudget` union
having **no unbounded arm** ([§5](#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)) and the `Growable` union having **no bare-unbounded arm** ([§6](#6-growable--scalingpolicy-the-escape-valve-amoebius-owns)) are grade-1
*union shapes* — a value simply cannot name "unbounded" without a policy. The *arithmetic* over those bounded
values is always grade-2.

The grade-3 residue is equally explicit and **not this doc's to assert**: whether the physical host actually
caps bytes/cgroups, whether the scheduler actually places the pods, whether the autoscaler actually grows the
node set, and whether the cloud actually honors the quota are **runtime** facts owned by
[chaos_failover_doctrine.md](./chaos_failover_doctrine.md) and the testing doctrine. [§8](#8-where-the-numbers-come-from-declared-at-decode-cross-checked-at-runtime) states the one
runtime cross-check the model *requires* (declared capacity ≤ real capacity) and honestly grades it (3).

```mermaid
flowchart TD
  spec[amoebius.dhall: declared capacities plus typed demands] -->|Dhall typecheck, well-formed| typed[Well-typed value with StorageBudget and Growable union shapes, grade 1]
  typed -->|Gate 2 decode: total capacity fold| fold{Sum of demand at most capacity?}
  fold -->|yes| ir[Coherent capacity-checked IR, grade 2 proven at decode]
  fold -->|no| reject[Left Overcommit, rejected before any effect]
  ir -->|reconcile| runtime[Live cluster: host caps, scheduler, autoscaler, quota]
  runtime -->|declared at most real capacity cross-check, and actual enforcement| grade3[Runtime residue owned by chaos_failover and testing, grade 3]
```

---

## 3. The types: `Quantity`, `Capacity`, `Demand`, `Budget`

Intuition: every number that can be summed is a **refined non-zero quantity**, every provider of resources
advertises a **`Capacity`**, and every consumer declares a **`Demand`** in the same units, so the fold is a
subtraction that must not underflow.

- **`Quantity`** — a refined non-zero measure with a unit (`cpu` millicores, `mem` bytes, `storage` bytes,
  `gpu` count). A zero or negative quantity is not constructible (the same refined-non-zero discipline the
  storage doctrine uses for PV sizes, [storage_lifecycle_doctrine.md §5](./storage_lifecycle_doctrine.md#5-sizes-are-explicit-hard-capped-and-one-volume-per-claim),
  and platform services for cpu/ram, [platform_services_doctrine.md §10](./platform_services_doctrine.md#10-every-container-declares-cpu-and-ram)).
- **`Capacity`** — what a *provider* offers: a record of `Quantity` per axis. A physical host advertises one
  (from the substrate node inventory, [substrate_doctrine.md](./substrate_doctrine.md)); a VM carves a
  sub-`Capacity` out of its host; a managed provider's node advertises the `Capacity` of its instance type;
  a `StorageBacking` advertises a storage `Capacity` ([§5](#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)).
- **`Demand`** — what a *consumer* needs: the same record shape. A container's cpu/ram request is a `Demand`;
  a StatefulSet's volume claims are a storage `Demand`; a whole workload's `Demand` is the fold of its
  containers and volumes; a VM's `Demand` on its host is the fold of everything the VM runs plus its own
  overhead.
- **`Budget`** — a `Capacity` an owner is *allowed to consume against*, which may be a fixed cap or a
  quota-capped growable ([§5](#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm), [§6](#6-growable--scalingpolicy-the-escape-valve-amoebius-owns)). `Budget` is where capacity meets the escape valve; `Capacity` is the raw
  number, `Budget` is the *policy-wrapped* number the fold checks against.

`Demand` and `Capacity` share one record shape so the fold is defined once and reused at every layer.

---

## 4. The total fold: `fits`, `carve`, `place`, and the nesting

Intuition: don't check "does this one pod fit a node" in isolation — **fold the whole demand of a scope and
compare it once to that scope's capacity**, at every level of nesting, so overcommit is caught wherever it
occurs.

The fold is three total functions (grade-2 checked rejections, [§2](#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-grade-2-check-never-grade-1)):

- **`fits :: Demand -> Capacity -> Either Overcommit Headroom`** — the leaf check: one demand against one
  capacity, returning the leftover headroom or `Left Overcommit` with the offending axis and magnitudes.
- **`carve :: Capacity -> Demand -> Either Overcommit Capacity`** — allocate a sub-capacity (a VM out of a
  host, a namespace budget out of a cluster) by total subtraction; an underflow on any axis is
  `Left Overcommit`.
- **`place :: Topology -> [Workload] -> Either Overcommit Placement`** — the cluster-level fold: the summed
  `Demand` of all workloads against the summed `Capacity` of the topology's nodes
  ([cluster_topology_doctrine.md](./cluster_topology_doctrine.md) owns the topology; this doc owns the sum).
  A workload's placement `Demand` includes its scheduling constraints so the fold composes with the
  schedulability existence check ([illegal_state_catalog.md §3.5](./illegal_state_catalog.md#35-undeployable-pods-taints-tolerations--affinity)).

The nesting is where the illegal states [§3.17](./illegal_state_catalog.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded) (I5/I6/I7) live:

- **Host → engine.** A `kind`/`rke2`/VM compute engine's `Demand` on its host must `fits` the host `Capacity`
  (I5, I6). This is the same fold whether the "host" is a physical machine or a VM carved from one.
- **Host → VM → guest.** A Lima/WSL2 VM `carve`s a sub-`Capacity` from its host; everything the VM runs then
  folds against *that* sub-capacity — nested budgets, so "a VM asking for more than its host" (I6) and "a
  guest asking for more than its VM" are the same relation at different depths.
- **Cluster → workload.** The whole workload set `place`s against the topology capacity (I7). Because every
  container declares cpu/ram ([platform_services_doctrine.md §10](./platform_services_doctrine.md#10-every-container-declares-cpu-and-ram))
  and every durable volume declares a hard-capped size ([storage_lifecycle_doctrine.md §5](./storage_lifecycle_doctrine.md#5-sizes-are-explicit-hard-capped-and-one-volume-per-claim)),
  the sum is exact, not a guess — this is the same soundness the cluster-lifecycle push-back relies on
  ([cluster_lifecycle_doctrine.md §6](./cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-global-dhall)).

The fold is **total and re-runnable**: after any `Growable` policy grows a capacity ([§6](#6-growable--scalingpolicy-the-escape-valve-amoebius-owns)) the fold re-runs
against the new bound, so growth never silently invalidates an earlier check.

---

## 5. `StorageBudget`: bounded by construction, single-owner ceiling per arm

Intuition: there is no such thing as "unbounded storage" — storage is *either* host-level (bounded by a
physical disk) *or* cloud (bounded by a quota). amoebius encodes that as a **closed union with no unbounded
arm**, so "unbounded storage" (I9) has no syntax.

```
StorageBudget = Fixed Capacity | QuotaCapped Quota | Growable ScalingPolicy
```

- **No unbounded constructor** — the union shape is grade-1: a value cannot denote unbounded storage. This is
  the storage-side reading of the illegal-state contract; the closed `StorageBacking` union it pairs with
  (host-disk-bounded | EBS-bounded | cloud-quota-bounded) is owned by
  [storage_lifecycle_doctrine.md §5.2](./storage_lifecycle_doctrine.md#52-the-storage-backing-is-bounded--the-closed-storagebacking-union), and this doc owns the *aggregate
  arithmetic* over it.
- **Single-owner ceiling per arm.** Each arm names exactly one owner of its ceiling number, so "available
  storage" has one definition: a **host-disk** arm's ceiling is owned by
  [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) (the retained-PV host root) and, for the
  content store, [content_addressing_doctrine.md](./content_addressing_doctrine.md) (the MinIO backing); a
  **cloud** arm's ceiling is the quota owned by [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md). The
  aggregate fold `Σ(sizes) ≤ backing` (I10) reads whichever owner the arm names.
- **Both MinIO and Pulsar fold against a `StorageBudget`.** An app's object usage (`<app>/<bucket>` MinIO
  buckets) and a topic's retained bytes ([§7](#7-pulsar-has-two-ceilings-the-hot-tier-and-the-durable-total)) each contribute a storage `Demand`; the sum against the backing
  is the same [§4](#4-the-total-fold-fits-carve-place-and-the-nesting) fold. "An app that can consume more storage than is available" (I10) is therefore
  unrepresentable for both.

---

## 6. `Growable` / `ScalingPolicy`: the escape valve amoebius owns

Intuition: bounded capacity would be a straitjacket if it could never grow — but growth must be *amoebius's
decision under a typed policy*, never a blank "unbounded." So the **only** way a `Budget` exceeds a fixed cap
is a `Growable` arm carrying a `ScalingPolicy`, and the policy's own outer bound is a cloud quota — never
truly unbounded.

```
Growable = Bounded Capacity | Autoscaled ScalingPolicy
```

- **No bare-unbounded arm** (grade-1 union shape): "grow without limit and without a policy" (I12) has no
  constructor. `Autoscaled` *requires* a `ScalingPolicy`.
- **`ScalingPolicy` is arbitrary-but-total, and amoebius owns it.** It is a typed, side-effect-free value —
  capacity thresholds (grow when utilization crosses a mark, drain when it falls), **instance price-shopping**
  (a candidate instance-type set with a price ceiling), and a **quota cap** that bounds the whole policy. It
  carries no logic; the reconciler enacts it. This is the deployment-rules-surface elastic-shape logic already
  named by [cluster_lifecycle_doctrine.md §8](./cluster_lifecycle_doctrine.md#8-dynamic-node-provisioning)
  and realized as Pulumi node provisioning by
  [pulumi_iac_doctrine.md §4](./pulumi_iac_doctrine.md#4-what-pulumi-provisions-the-resource-catalog); this
  doc owns the *type* and its place in the fold.
- **A `ScalingPolicy` grows the rke2 `agents` pool ONLY — the `Rke2Servers` quorum is never autoscaled.** The
  rke2 node topology is two typed pools owned by
  [cluster_topology_doctrine.md §2](./cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm):
  a `Rke2Servers` control-plane quorum (the closed `Single | Ha3 | Ha5` union — the only legal odd etcd
  quorums {1,3,5}) and an `agents : List LinuxHost` worker pool. A `Growable`/`Autoscaled` budget scales the
  **agents** list and nothing else; the server quorum is **fixed by declaration**. A quorum change
  (`Single`→`Ha3`→`Ha5`) is a deliberate **re-provision** — a re-declared topology re-folded through the
  cardinality-by-construction relation
  ([cluster_topology_doctrine.md §4](./cluster_topology_doctrine.md#4-topology-a-cluster-is-a-fold-over-its-nodes-and-cardinality-is-by-construction))
  and enacted by the host reconciler — **never** a `ScalingPolicy`/autoscale action, because etcd membership
  is a consensus decision, not an elastic-capacity one. So the elastic axis and the quorum axis stay
  orthogonal: the price-shopping / threshold policy above ranges over agents; the fold re-runs ([§4](#4-the-total-fold-fits-carve-place-and-the-nesting), below)
  against the grown *agent* set only. This is **Phase-10 design intent** (the `ScalingPolicy` enaction lands
  in Phase 10, [§10](#10-planning-ownership)); the closed-union quorum shape it relies on is grade-1 and owned by cluster topology, not
  claimed here.
- **The fold re-runs after growth ([§4](#4-the-total-fold-fits-carve-place-and-the-nesting)).** A `Growable` budget the fold checked at decode is re-checked
  against the grown capacity when the policy fires — so "unbounded" MinIO/Pulsar is representable **only**
  through such a policy whose ceiling is a quota, and the storage fold still holds against that ceiling.
- **Honesty.** The policy *composing* — a legal `ScalingPolicy` that the fold accepts — is grade-1/2. That
  the autoscaler *actually grows* capacity, and that the cloud *honors* the quota, is grade-3 runtime,
  deferred to [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md) enactment and
  [chaos_failover_doctrine.md](./chaos_failover_doctrine.md).

---

## 7. Pulsar has two ceilings: the hot tier and the durable total

Intuition: a message bus is the one storage consumer where a *single* budget is not enough. Pulsar's hot tier
is BookKeeper (bookies on retained PVs); tiered storage offloads only **closed** ledgers to S3 and does not
free BookKeeper until retention deletes them (there is a deletion lag), and the currently-open ledger can
never be offloaded. So a **time-only** offload trigger does not bound the hot tier: if ingest × offload-lag
exceeds the bookie disk, BookKeeper fills, bookies go read-only, and the topic — often the broker — becomes
**unavailable**. Worse, that overflow would be *representable*, which this model forbids.

So every topic folds against **two** ceilings (the topic-lifecycle *policy* is owned by
[pulsar_client_doctrine.md §6](./pulsar_client_doctrine.md#6-the-declarative-topology-algebra); this doc owns
the *two-ceiling arithmetic*):

- **Hot-tier fit (availability-critical).** The offload trigger is a **size high-water mark** on the primary
  tier, not time (time may offload *sooner* for cost, but is never the sole trigger — a time-only policy is
  uninhabitable, [illegal_state_catalog.md §3.20](./illegal_state_catalog.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)). The per-topic hot cap **plus
  headroom** — the open ledger, in-flight ingest during offload, and the deletion lag — folds against the
  BookKeeper `StorageBacking`: `Σ(hot caps + headroom) ≤ bookie disk`. A hot-tier overflow is a grade-2
  decode rejection.
- **Durable-total fit.** The total retained bytes fold against the selected offload target's ceiling ([§5](#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm)) —
  a provider-S3 quota ([pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md)) for cloud clusters, or the MinIO
  content store ([content_addressing_doctrine.md](./content_addressing_doctrine.md)) for host-bounded ones.
- **Runtime fail-safe (grade-3).** A burst, or a stalled/S3-unreachable offload, can still race the cap at
  runtime — no spec-layer check prevents that. So the topic policy carries a **mandatory backlog quota**
  (`producer_request_hold` / back-pressure at the high-water mark) so overflow degrades to per-topic producer
  throttling, never a disk-full broker outage. The decode-time two-ceiling fit is grade-2; the back-pressure
  actually holding is grade-3.

---

## 8. Where the numbers come from: declared at decode, cross-checked at runtime

Intuition: for overcommit to be *unrepresentable* rather than a runtime error, the capacity the fold checks
against must be a **spec input** — you cannot type-check a demand against a number you only learn at runtime.
So amoebius **declares** capacity in the spec and folds at decode (grade-2), then **cross-checks** the
declaration against reality at reconcile (grade-3).

- **Declared (grade-2).** Each host/node advertises a `Capacity` in the substrate node inventory
  ([substrate_doctrine.md](./substrate_doctrine.md)); each cloud account declares a quota
  ([pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md)); each `StorageBacking` declares its size. The [§4](#4-the-total-fold-fits-carve-place-and-the-nesting) fold
  runs over these declared numbers at decode, so an over-committed spec never decodes.
- **Cross-checked (grade-3).** A reconcile-time check refuses if the *real* probed capacity is **smaller**
  than the declared `Capacity` (a host that claims 64 GiB but has 32 GiB), fail-closed like every other
  `Unreachable → refuse` observation ([cluster_lifecycle_doctrine.md §9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)).
  This keeps the decode-time guarantee honest: the declaration is a *ceiling the fold trusts*, and reality is
  required to be at least that generous or the deploy refuses. Detection of the real number is owned by
  [substrate_doctrine.md §2](./substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads);
  this doc owns only the requirement that the cross-check exist and its grade.

> **Honesty.** This model is Phase-0 design intent, specified before implementation. The fold is a real
> grade-2 spec-layer guarantee *when implemented as specified*; that claim is itself about a design not yet
> built (Phase 3). The grade-3 runtime cross-check and enforcement are deferred by construction. Where the
> capacity arithmetic generalizes the push-back soundness proven in prodbox
> ([cluster_lifecycle_doctrine.md §6](./cluster_lifecycle_doctrine.md#6-push-back-when-teardown-would-break-the-global-dhall)),
> that is sibling evidence, not amoebius proof ([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)).

---

## 9. What this doctrine deliberately does not own

To keep SSoT boundaries crisp:

| Concern | Owned by |
|---|---|
| Per-host / per-node capacity numbers and their detection; the node inventory; taints | [substrate_doctrine.md](./substrate_doctrine.md) |
| The `ComputeEngine` / `Topology` types the `place` fold ranges over | [cluster_topology_doctrine.md](./cluster_topology_doctrine.md) |
| Per-volume hard-capped PV sizing; the `StorageBacking` union shape | [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) |
| Per-container cpu/ram declaration | [platform_services_doctrine.md §10](./platform_services_doctrine.md#10-every-container-declares-cpu-and-ram) |
| Cloud quota provisioning; dynamic node provisioning enaction; per-PV EBS | [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md) |
| The Pulsar topic-lifecycle policy (retention, size-triggered offload, backlog quota) | [pulsar_client_doctrine.md §6](./pulsar_client_doctrine.md#6-the-declarative-topology-algebra) |
| The content-addressed MinIO store as a storage backing | [content_addressing_doctrine.md](./content_addressing_doctrine.md) |
| Which capacity states are illegal and the [§4.6](./illegal_state_catalog.md#46-capacity-accounting-total-fold--σ-demand--capacity-checked) technique that forecloses them | [illegal_state_catalog.md](./illegal_state_catalog.md) |
| Runtime enforcement (host actually caps, scheduler places, autoscaler grows, quota holds) | [chaos_failover_doctrine.md](./chaos_failover_doctrine.md), [testing_doctrine.md](./testing_doctrine.md) |
| Capacity/scaling as a deployment-rules surface, never app logic | [app_vs_deployment_doctrine.md](./app_vs_deployment_doctrine.md) |

---

## 10. Planning ownership

This document is normative capacity doctrine only. Delivery sequencing, completion status, and validation
gates are owned by [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md): the capacity/topology
type discipline lands in **Phase 3** (the fold and the negative `.dhall` gate), with runtime realization of
the storage/pulsar folds in **Phase 2/4**, the host/VM cross-check in **Phase 7**, and the `ScalingPolicy`
enaction in **Phase 10**. This doc never maintains a competing status ledger; it states the target shape and
links back for status, per [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline).

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Illegal State Catalog](./illegal_state_catalog.md) — the catalog ([§3.17](./illegal_state_catalog.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)-[§3.21](./illegal_state_catalog.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy)) and technique ([§4.6](./illegal_state_catalog.md#46-capacity-accounting-total-fold--σ-demand--capacity-checked)) this model realizes
- [Cluster Topology Doctrine](./cluster_topology_doctrine.md) — the `ComputeEngine` / `Topology` the fold ranges over; owns the `Rke2Servers` quorum + `agents` pools ([§2](./cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm)/[§4](./cluster_topology_doctrine.md#4-topology-a-cluster-is-a-fold-over-its-nodes-and-cardinality-is-by-construction)) that [§6](./cluster_topology_doctrine.md#6-where-topology-meets-capacity-and-lifecycle) scales agents-only
- [Substrate Doctrine](./substrate_doctrine.md) — the node inventory + per-host capacity numbers
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md) — per-volume sizing + the `StorageBacking` union
- [Pulsar Client Doctrine](./pulsar_client_doctrine.md) — the topic-lifecycle policy the two-ceiling fold checks
- [Platform Services Doctrine](./platform_services_doctrine.md) — every container declares cpu/ram
- [Pulumi IaC Doctrine](./pulumi_iac_doctrine.md) — cloud quota + dynamic node provisioning enaction
- [Content Addressing Doctrine](./content_addressing_doctrine.md) — the MinIO content store as a storage backing
- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md) — push-back arithmetic + the reconcile cross-check
- [App vs Deployment Doctrine](./app_vs_deployment_doctrine.md) — capacity/scaling is a deployment rule
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
