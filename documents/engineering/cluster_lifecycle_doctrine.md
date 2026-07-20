# Cluster Lifecycle

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_14_midwife_bootstrap_kind.md, DEVELOPMENT_PLAN/phase_17_retained_storage.md, DEVELOPMENT_PLAN/phase_28_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_29_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_30_provider_clusters.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_techniques.md, documents/illegal_state/illegal_state_topology.md
**Generated sections**: none

> **Purpose**: Single Source of Truth for amoebius cluster bring-up and teardown across kind / rke2 / provider clusters — bootstrap, recursive **amoebic spawning**, graceful teardown-with-cleanup versus chaos-failover, push-back on an unsatisfiable root `InForceSpec`, dynamic node provisioning, and ephemeral spin-up/down with deterministic rebind.

---

## 1. Two cluster kinds, one lifecycle shape

There are exactly **two** kinds of cluster amoebius drives, and they share **one** lifecycle vocabulary
— *bring-up → init → reconcile → teardown* — even though the bring-up mechanics differ underneath.

| | **Self-managed** (`kind` / `rke2`) | **Provider-managed** (EKS — prodbox's reality) |
|---|---|---|
| Host binary present? | **Yes** — the binary lives on the host and owns bring-up | **No** — there is no direct host access |
| How it comes up | the midwife CLI on the host → `bootstrap --distro={kind,rke2}` ([§2](#2-bring-up-and-bootstrap)) | Provisioned **via cloud keys over the API, from inside an existing amoebius cluster** (Pulumi) |
| Host-level worker daemons | Supported (e.g. Apple-Metal inference) | **Not** supported — no host or Apple substrate; the child still runs distinct in-cluster singleton and capacity-scheduler roles |
| Typical role | Any tier, including the **root** (an admin's laptop kind, or a single-node rke2) | A **child** spawned by a parent; never the root |

The shared shape is what lets the rest of this document treat "a cluster" uniformly: a child spawned on
EKS and a kind cluster on a laptop converge to the **same fungible shape** — the same nine standard
services, wired the same way — owned by
[platform_services_doctrine.md §1](./platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster). The *substrate-specific* mechanics —
substrate detection, the midwife CLI, the LoadBalancer choice, host worker nodes, and the
no-environment-variables / no-`PATH` lazy-tool-ensure contract — are owned by
[substrate_doctrine.md](./substrate_doctrine.md). The Pulumi spawn mechanism and the cloud-credential
model are owned by [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md). The **declared compute-engine axis** —
the `Kind` / `Rke2` / `Managed Eks` types and their node topology (one host for kind, one Linux host per rke2
node, hostless for EKS) — is owned by [cluster_topology_doctrine.md](./cluster_topology_doctrine.md). This doc
owns the **lifecycle verbs** that ride on top.

**Self-managed clusters amoebius *builds*; provider-managed clusters amoebius *surfaces*.** The split in the
table above is precisely a *build-vs-surface* axis, and it is the axis the stretched-cluster question — can a
full member node hang off a provider-managed control plane? — rests on. A self-managed `kind`/`rke2` cluster
is one amoebius **builds** end to end: the host binary owns bring-up from the midwife CLI through `bootstrap`
([§2](#2-bring-up-and-bootstrap)) and every node beneath it. A provider-managed cluster is one amoebius
**surfaces** over the cloud provider's API — provisioned via Pulumi from inside an existing cluster, never
touching a host amoebius does not have; amoebius wires up only what the provider itself exposes and **builds
no capability the provider does not**, the same *surface, don't build* discipline owned by
[pulumi_iac_doctrine.md §0/§4](./pulumi_iac_doctrine.md#0-decision-record-why-pulumi-stays--and-why-that-is-not-the-helm-decision).
One consequence rides on this axis: because a provider-managed control plane is **hostless** (no `LinuxHost`,
and no host-level worker daemons — the table above), a **full member node stretched onto a provider-managed
control plane** is representable only through a provider-native capability the `Managed` arm *surfaces* (e.g.
EKS Hybrid Nodes, over the cloud API), never through an amoebius-built second control-plane fabric — which is
why [cluster_topology_doctrine.md §2](./cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm)/[§4.1](./cluster_topology_doctrine.md#41-rke2-serveragent-cardinality-odd-quorum-by-union-distinctness-by-fold-taint-by-derivation)
forecloses that node absent such an arm. A host-level *worker* is the other case entirely: a non-member on its
own physical host (the host-worker row above), unaffected by the control plane's hostlessness.

---

## 2. Bring-up and bootstrap

**Bring-up is the journey from nothing to a fungible cluster.** The very first cluster is *bootstrapped* on
a host; every later cluster is *spawned* by a parent ([§3](#3-amoebic-spawning--the-recursive-forest)). Both end in the same place — a cluster running
the standard service set, initialized, and reconciling toward its `.dhall`.

- **The midwife CLI is a thin igniter, not the orchestrator.** Its only job is to ensure the package
  manager, ensure `ghcup`, install the pinned toolchain (GHC **9.12.4**, Cabal 3.16.1.0 — the
  [DEVELOPMENT_PLAN](../../DEVELOPMENT_PLAN/README.md) toolchain pin; 9.14.1 is a deferred, later-phase bump per the plan's Toolchain section),
  build the binary, and call `bootstrap`. From that call onward the **binary** owns everything. The script
  itself and substrate detection are owned by [substrate_doctrine.md](./substrate_doctrine.md);
  this doc owns the lifecycle ordering the binary then drives. Bootstrap also establishes the
  binary-sibling `.dhall` configuration the rest of bring-up consumes — selecting the cluster distro and
  **naming** (never embedding) every credential the cluster needs to provision nodes: SSH keys for
  self-managed kind/rke2 nodes, cloud API keys for provider clusters.
- **`bootstrap --distro={kind,rke2}`**, with `kind` accepting `--replicas=n` (default `1`). The replica
  count is a deployment-rules knob; the HA charts are identical across values of `n`
  ([platform_services_doctrine.md §2](./platform_services_doctrine.md#2-ha-always--including-replicas1)).
- **The root cluster is single-node, on purpose.** A multi-node bring-up would need secrets — SSH keys or
  cloud credentials for the additional nodes — and that would violate the secrets-never-in-Dhall rule. Constraining the root to a single node lets it be bootstrapped with **zero
  secrets**, after which a small set of *root init commands* take over. (Whether the root may ever be multi-node is an open design question; this doctrine specifies
  the single-node answer the plan adopts.) The root's single-node init-to-password-encrypted-Vault-and-failover behaviour is the
  **prodbox** constituent behaviour ([DEVELOPMENT_PLAN](../../DEVELOPMENT_PLAN/README.md): *prodbox = the
  root single-node control-plane behaviour*).
- **Init follows readiness, never precedes it.** Once the standard services are up and reachable, the
  cluster is *initialized*: init Vault, then hand it its `.dhall`. The
  fail-closed Vault init, the root password-encrypted unseal that requires a human on first bring-up, and
  the PKI trust anchor are all owned by [vault_pki_doctrine.md](./vault_pki_doctrine.md). The
  platform-service bring-up ordering edges (LB before edge, the registry before later pulls, Vault before
  secret-dependent startup) are owned by
  [platform_services_doctrine.md §11](./platform_services_doctrine.md#11-bring-up-and-dependency-ordering).
  "Follows readiness" is the *event-driven* discipline, never a timer: each init step gates on an **observed
  condition** — a successful call, a `/readyz`, an unsealed Vault — not an elapsed wait, and the general
  readiness-edge rule (a condition never a duration; the bootstrap tier's `discover`/`RuntimeWitness` gates)
  is owned by [readiness_ordering_doctrine.md](./readiness_ordering_doctrine.md).
- **Bring-up is itself a reconcile.** "Come up" is not a one-shot script; it is the [§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine) reconciler driving
  the world toward the `.dhall`. Host-level idempotent cluster bring-up is first accepted in Phase 14; the
  Phase-16 SSA reconciler, driven from the `.dhall` by the Phase-22 singleton, owns in-cluster convergence.
- **A stretched rke2 agent joins only once it is reachable.** Growing a cluster with a **stretched** agent —
  a full member node whose declared network-locality `Site` differs from the control-plane servers' `Site`
  ([substrate_doctrine.md §8.3](./substrate_doctrine.md#83-site-the-declared-network-locality-axis-cluster-nodes-and-host-worker-hosts)) —
  adds a **reachability precondition** to the agent-join reconcile ([§11](#11-rke2-rollout-as-a-reconcile)):
  the remote node may present its `Rke2NodeToken` only across an established control-plane fabric reach (the
  `ReachesControlPlane` witness owned by
  [cluster_topology_doctrine.md §4.1](./cluster_topology_doctrine.md#41-rke2-serveragent-cardinality-odd-quorum-by-union-distinctness-by-fold-taint-by-derivation)),
  and a node declared remote but observed `Unreachable` is refused by the same
  [§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine) `Unreachable → refuse`
  gate. A **co-located** agent (same `Site` as the servers) keeps the plain
  [§11](#11-rke2-rollout-as-a-reconcile) `server:` URL + token join with no added precondition.

> **Resolved — the bootstrap sequence.** The shape of the root bootstrap config + first-manifest delivery is
> owned by [bootstrap_sequence_doctrine.md §3](./bootstrap_sequence_doctrine.md#3-the-ordered-bootstrap-sequence):
> the initial in-force manifest is supplied **separately**, via the admin control plane's `dhall update`
> **after** the singleton is up (never embedded in the igniter config), and the transient root config is the
> binary-sibling `.dhall` the midwife establishes. Every deeper **child-frame** config is delivered by
> in-place `stdin` streaming rather than a persistent file, per
> [dsl_doctrine.md §3](./dsl_doctrine.md#3-the-orchestration-surface-parameters-context-witness). (Whether the
> root may ever be **multi-node** remains the one open sub-question, [§2](#2-bring-up-and-bootstrap) above.)

---

## 3. Amoebic spawning — the recursive forest

This is the feature that **names the project**. A cluster can spawn one or more child clusters; those
children can in turn spawn children of their own; and so on, recursively. The
result is a *forest*: a root at the top, an arbitrary tree of descendants below.

```mermaid
flowchart TD
  root[Root cluster: single-node kind or rke2, owns the PKI trust anchor] -->|spawns via Pulumi, injects ChildInForceSpec and secrets| childa[Child cluster A: kind or rke2 or provider]
  root -->|spawns via Pulumi, injects ChildInForceSpec and secrets| childb[Child cluster B]
  childa -->|spawns its own child, injects GrandchildInForceSpec| grand[Grandchild cluster]
  root -->|self-signed trust anchor flows down the tree| childa
  root -->|self-signed trust anchor flows down the tree| childb
```

**Spawning is a Pulumi deploy from inside an existing cluster.** A parent provisions a child — `kind` or
`rke2` via one or more SSH keys, or a provider cluster via cloud keys — tracking the deploy in Pulumi with
a **MinIO backend, locally encrypted via the Vault transport engine**. The
spawn mechanism, the backend encryption, and the create-vs-delete credential model are owned by
[pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md); this doc owns only the *lifecycle* meaning of a spawn.
This cross-cluster spawn is a distinct **transport** from the intra-host **frame descent** that streams a
child-frame `amoebius.dhall` `FrameConfig` on the lift's `stdin` ([dsl_doctrine.md §3](./dsl_doctrine.md#3-the-orchestration-surface-parameters-context-witness)): both hand a child only
its own projection and both mint strictly from the parent, but the spawn crosses a cluster boundary under a
per-child Vault Transit envelope where the frame descent crosses a process boundary on `stdin`.

**Spawn injection is one-time; subsequent reach is the `ParentReachChannel`.** The Pulumi spawn injects the
child's *first* `ChildInForceSpec` and secrets. Every *later* update — a new `ChildInForceSpec`, or driving the
child's own `vault init/unseal` — reaches the child's **admin REST** over the parent's typed
**`ParentReachChannel`** (projected from the child's `ComputeEngine`: SSH for self-managed, cloud-API for
managed), hitting the child's **node-local** admin NodePort independent of the child's gateway/vpn/mesh state,
and **never** the child's public gateway. That channel and its "no unreachable child" foreclosure are owned by
[bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api); a mode-(b) child's unseal-authority reach rides this same floor channel
([vault_pki_doctrine.md §6](./vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes)), never the data-plane fabric.

Two encapsulation rules make the forest safe to reason about:

- **A child gets only its own `ChildInForceSpec` — a structural subtree projection.** Each child is handed exactly
  its own subtree's spec — its own configuration *including its children's* — and **nothing else**. This is
  not a convention the parent is trusted to honour: the value a child receives is, by construction,
  `project(subtree)` — a typed `ChildInForceSpec` ([dsl_doctrine.md](./dsl_doctrine.md)) with no field in which a
  sibling or ancestor-only branch can appear, so handing a child anything beyond its own subtree is
  *unrepresentable* ([illegal_state_catalog.md](../illegal_state/illegal_state_catalog.md)), exactly as a cross-tenant
  secret already is. The projection is enforced *cryptographically* as well: the spawn envelopes each
  child's subtree under its **own per-child Vault Transit key**, so a child cannot decrypt a sibling's
  subtree even under an unsealed parent
  ([vault_pki_doctrine.md §6](./vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes)). It knows
  nothing about its siblings or any wider part of the forest: a child that has never been
  inspected is the same machine as any other cluster, and it cannot reach into state it was never
  given.
- **Trust flows down from the root, never sideways.** The root cluster — typically a kind cluster on the
  admin's laptop — owns the **self-signed PKI trust anchor** for everything below it. Children derive trust from above; they do not mint independent anchors. The trust tree, the
  parent/child Vault unseal modes (a child either self-unseals via a k8s secret, **or** the parent owns
  the unseal secret and the child requests an unlock), and the **parent-injects-secrets-into-the-child's-Vault**
  contract are all owned by [vault_pki_doctrine.md](./vault_pki_doctrine.md). Dhall carries only *names*
  for secrets; the bytes are injected out-of-band into the child's Vault.
- **Monitoring does not flow up, either.** The same downward-only projection forecloses in-cluster parent→child
  telemetry: a `ChildInForceSpec` has no ancestor-referencing field to replicate monitoring to, and a parent
  reaching across the boundary to pull a child's metrics is the synchronous cross-cluster RPC ruled actively
  anti-doctrinal ([network_fabric_doctrine.md](./network_fabric_doctrine.md)). Peer/sibling monitoring rides the
  existing async geo-replication a peer already consumes; the accepted cross-forest viewer is the out-of-forest
  human operator reaching each cluster's own Grafana and `pb` admin plane through Keycloak — a privileged admin
  path, not a forest data edge. The full parent-monitoring posture is owned by
  [monitoring_doctrine.md](./monitoring_doctrine.md).

> **Honesty.** Amoebic spawning, per-child unseal, and geo-replicated children are *specified* here and
> scheduled for Phase 28; nothing in this section is a tested amoebius result. Status and gates live only in
> [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md) (per
> [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline) and
> [chaos_failover_doctrine.md](./chaos_failover_doctrine.md)).

---

## 4. The root `InForceSpec` is the persistent contract

There is **one root desired-state spec — the root `InForceSpec`** — and it **outlives any individual cluster**.
This is the load-bearing invariant for everything below: tearing a cluster down does **not** edit the
root `InForceSpec`; the spec still applies, and the remaining forest reconciles toward it.

- **Always rolled out from the root.** A new root `InForceSpec` is rolled out from the root cluster (the
  laptop kind), never from a leaf. The root is the single point from which the
  forest's desired state changes.
- **Teardown is a capacity event, not a spec change.** When a cluster goes away ([§5](#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)), the root `InForceSpec`
  is untouched. The forest's *desired* shape is the same; only its *available* capacity dropped. The
  reconciler ([§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)) then drives the surviving clusters toward the unchanged spec as far as their capacity
  allows.
- **This is precisely what makes ephemeral teardown safe and push-back well-defined.** Because the
  contract persists, "can the forest still satisfy the spec after this teardown?" is a *decidable*
  question ([§6](#6-push-back-when-teardown-would-break-the-root-inforcespec)), and "spin the cluster back up later" reconciles to the *same* target ([§7](#7-ephemeral-spin-updown-with-deterministic-rebind)).

Application logic and deployment rules are separate DSL surfaces: the spawn topology, teardown policy,
push-back thresholds, and dynamic-provisioning logic in this doctrine all live on the **deployment-rules**
surface, never inside an app's logic ([app_vs_deployment_doctrine.md](./app_vs_deployment_doctrine.md)).

---

## 5. Teardown-with-cleanup vs chaos-failover (the central distinction)

There are two completely different ways a cluster can stop being the lead — one **polite**, one **violent**
— and conflating them is the bug this section exists to prevent:

> **Graceful teardown cleans up first; chaos-failover does not.**

| | **Graceful teardown-with-cleanup** (this doc) | **Chaos-failover** ([chaos_failover_doctrine.md](./chaos_failover_doctrine.md)) |
|---|---|---|
| Trigger | A **deliberate** operator/declarative action to turn a cluster off | An **unplanned** loss — the lead's gateway dies |
| Cleanup before exit | **Yes** — the cluster gets to clean up before going away | **None** — the cluster just disappears |
| Synchronization | Can be scheduled to **coincide with a sync event** (Pulsar / MinIO), so nothing in flight is lost | No coordination; recovery is after-the-fact |
| Data-loss guarantee | **Lossless by construction** (rides a synchronization event) | Bounded by the declared **data-loss budget**, not zero |
| Who proves correctness | The reconciler's idempotent cleanup ordering ([§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)) | A **separate proof obligation** — the async cross-cluster "Second Axis" |

**Graceful teardown, concretely.** A graceful teardown is a controlled handoff. Before any compute is
released, the cluster (driven by its control-plane singleton, [§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)):

1. **Drains workloads** and quiesces in-flight work.
2. **Flushes / checkpoints synchronization** — lets Pulsar topics drain and acknowledge and MinIO / Postgres
   replication catch up — so the teardown can be timed to a synchronization event and lose nothing. The Pulsar side rides the **native binary protocol — no WebSockets**
   ([pulsar_client_doctrine.md](./pulsar_client_doctrine.md)).
3. **Deregisters from geo-replication and hands off the gateway** cleanly, so siblings take over the wild
   ingress (which Keycloak owns, [platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)) and
   DNS repoints in an orderly way rather than as an emergency.
4. **Releases ephemeral cluster resources, never durable backing.** Compute, control-plane infrastructure,
   and cluster-local API objects are removed; durable backing is **preserved, never deleted by routine
   teardown** ([§7](#7-ephemeral-spin-updown-with-deterministic-rebind);
   [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md)).

**Chaos-failover, concretely.** A chaos-failover is what happens when the lead *vanishes* — no
drain, no flush, no handoff. Surviving siblings with the same parent **detect the dead gateway and fail
over on their own, repointing DNS (e.g. route53 migrations)**. Because there was
no synchronization event, the outcome is **not** lossless-by-construction: it is bounded by the declared
data-loss budget, and proving that the behaviour is always well-defined — especially the case where a
cluster goes down mid geo-sync and the gateway is failed over to it — is the one place a
per-system proof obligation concentrates. That entire **async cross-cluster boundary** (the invariant-
confluence "Second Axis", with its proven/tested/assumed ledger) is owned by
[chaos_failover_doctrine.md](./chaos_failover_doctrine.md). Intra-cluster synchronous HA is *delegated* to
MinIO / Pulsar / Postgres-Patroni, which do their own consensus
([platform_services_doctrine.md §6, §8](./platform_services_doctrine.md#6-pulsar--the-event-and-workflow-backbone-new-vs-prodbox)).

The distinction matters because it tells the operator and the code which guarantee is in force: a graceful
teardown that *skips* the cleanup steps is silently downgrading itself to a chaos event and forfeiting the
lossless guarantee — the kind of "tested/assumed reported as proven" confusion the honesty rule
([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)) forbids.

**Where the gateway itself goes is a `GatewayMigration`.** The gateway handoff in a graceful teardown (step 3
above) is the *source-is-departing* case of a broader operation: moving wild-ingress ownership between
clusters. That operation — the typed `GatewayMigration = <Planned | Failover>` taxonomy, the live-to-live
handover between two running clusters, its quiesce → drain → cutover consistency protocol, and the
client-rebind protocol — is owned by
[gateway_migration_doctrine.md](./gateway_migration_doctrine.md). This section owns only *when and why a
teardown hands the gateway off*; that handoff is one `Planned` trigger.

---

## 6. Push-back when teardown would break the root `InForceSpec`

Teardown is meant to be a safe way to turn a cluster off **any time** — but some clusters are
load-bearing. A cluster might hold the *only* nodes of a particular hardware substrate (say, the only
Apple-Metal inference nodes), which cannot be independently failed over. Tearing that cluster down would
make the root `InForceSpec` **unsatisfiable**. amoebius refuses to do that silently.

```mermaid
flowchart TD
  start[Operator requests graceful teardown of cluster C] --> check{Can the remaining forest still satisfy the root InForceSpec without C?}
  check -->|yes| proceed[Proceed: clean up, hand off, release compute, preserve storage]
  check -->|no| pushback[Push back: warn what stops working and which .dhall failback applies]
  pushback --> override{Operator issues the explicit override?}
  override -->|no| abort[Abort: cluster stays up, root InForceSpec stays satisfied]
  override -->|yes| degrade[Proceed under override: fall back to the declared .dhall failback]
```

- **Push-back, not a hard wall.** When a teardown would stop the root `InForceSpec` from being satisfied, the
  command **pushes back with a warning**: it names what is going to stop working and the `.dhall`
  *failback* it will fall to. It does not just succeed-and-break.
- **An explicit override exists.** There is an override command to proceed anyway, accepting the named
  degradation. The override is deliberate and explicit — never the default.
- **The thresholds are declarative.** CPU, memory, pod-ephemeral storage (including nested in-cluster cache),
  durable/native-host-cache backing,
  accelerator family/count, and accelerator memory are `.dhall`-configurable and govern *whether* push-back
  fires. Because every execution unit carries a complete resource envelope
  ([platform_services_doctrine.md §10](./platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope)),
  the question “does the surviving forest have a resource-capable placement for what C was running?” is
  answered by the same post-bind placement, named-pool, finite-limit/physical-peak, and accelerator folds owned by
  [resource_capacity_doctrine.md](./resource_capacity_doctrine.md), rather than by a CPU/RAM sum or guesswork.
- **Same fail-closed posture as the reconciler.** Refusing-by-default on an unsatisfiable spec is the
  lifecycle analogue of the [§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine) `Unreachable → refuse` rule: a state the system cannot safely reach is
  refused, and only an explicit operator override overrides it.

---

## 7. Ephemeral spin-up/down with deterministic rebind

Ephemeral is a **replaceability property**, not a scheduling policy: it imposes neither a TTL nor mandatory
production teardown. A cluster's compute, control-plane infrastructure, and cluster-local API objects can be
gracefully reconciled absent and reconstructed. The rebuilt cluster converges toward the persistent root
`InForceSpec` and reattaches retained backing through deterministically recreated PV bindings. This graceful
round-trip has zero durable-byte loss when the backing remains attachable and the deterministic-rebind
preconditions hold. (Shorthand: clusters are cattle; their storage is not.)

- **Deterministic rebind is owned elsewhere — referenced, not restated.** The mechanism that guarantees a
  rebuilt cluster reattaches the *same* data is the `no-provisioner` retained-PV policy
  (`<namespace>/<statefulset>/pv_<integer>`, sized, host/EBS-bound), owned in full by
  [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md). This doc owns only the *lifecycle
  consequence*: spin-down then spin-up converges to the identical shape **and** the identical bytes.
- **Teardown removes ephemeral infrastructure, never durable backing.** This is the critical caveat: the
  durable storage **must remain** or a later spin-up fails. So a graceful teardown ([§5](#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)) releases compute
  and **leaves the durable backing intact**; cluster-local PV API objects may disappear and are freshly
  rendered on the next bring-up. The default posture is *"durable storage exists forever"*; deleting it is
  forbidden under normal credentials. Automated test-owned reclamation uses the elevated harness; any
  deliberate production reclaim is a separate, human-operated external break-glass action. That
  storage-deletion safety model is owned by
  [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) and
  [testing_doctrine.md](./testing_doctrine.md).
- **This is what makes [§3](#3-amoebic-spawning--the-recursive-forest) and [§5](#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction) compose.** A child gracefully torn down and later spun back up rebinds to the same shape and
  the same data; a cluster torn down to free compute returns lossless. Fungibility
  ([platform_services_doctrine.md §1](./platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster)) plus durable rebind is the
  precondition for ephemeral teardown being *safe*, not just *possible*.

---

## 8. Dynamic node provisioning

A cluster's **node set is itself declarative and reactive** — it grows and shrinks by *logic*, not by hand. The root `InForceSpec` can express dynamic node provisioning driven by arbitrary
conditions:

- **Load** — provision nodes when demand rises, release them when it falls.
- **Spot-instance compute cost** — provision when capacity is cheap, drain when it is not.
- **Workflow completion** — provision a node for a specific workflow and reclaim it when the workflow
  finishes.

This lives on the **deployment-rules** surface, orthogonal to application logic
([app_vs_deployment_doctrine.md](./app_vs_deployment_doctrine.md)): an app never asks for nodes; the
deployment rules decide the cluster's elastic shape. That elastic shape is a typed **`ScalingPolicy`**
(capacity thresholds + price-shopping across named candidate classes, bounded by a quota). Every candidate
declares the exact `ProviderNodeClass { name, sku, allocatable, quotaVcpu, zones, price, baseCount, maxCount }`
shape. Its `allocatable` is the complete
`ProviderNodeCapacityTemplate { allocatableCpu, allocatableMemory, podSlots, cniSlots, attachableVolumes, localDisks,
cpuOvercommit, localStorage, accelerator }`; `localStorage` retains
`{ podEphemeralAllocatable, filesystems, imageStorageModel, imagePullConcurrency }`, and each `localDisks`
entry is a `PerInstanceDiskTemplate` with either
`InstanceStore { skuDevice, provisionedRawBytes, presentation }` raw supply or
`EphemeralRootEbs { policy }`, plus a `ProviderUsableDiskCarveTemplate` system reserve and non-empty usable
carves. For each selected instance, private provisioning derives `ProvisionedPerInstanceDiskTemplate`:
instance-store `provisionedRawBytes` is checked against the SKU raw device, while an ephemeral-root policy
derives its provider-rounded raw request from the usable demand; the presentation model then derives
`mountedUsableBytes` and proves the system reserve plus unique layout-carve `requiredUsableBytes` fit it.
Raw supply and usable carve bytes never enter the same sum. The managed target
also supplies the `CloudAccountId` that exact-joins the shared provider ledger and the complete
`ProviderQuota { maxInstances, maxVcpu, acceleratorCaps, nodeRootStorage, durable }`.
Before growth, every atomic pending envelope must fit a compatible candidate and the worst-case instance count,
provider vCPU, accelerator allocation, node-root EBS bytes/count, and durable bytes/count must remain within
their distinct quota fields; pod/CNI and driver-indexed CSI attachment slots must also fit. A missing or
mismatched account key, unknown quota field, or one-short slot/quota observation makes growth refuse
before mutation. This is the escape valve that lets a bounded
budget grow, owned by [resource_capacity_doctrine.md §6](./resource_capacity_doctrine.md#6-growable--scalingpolicy-the-escape-valve-amoebius-owns); "unbounded" node or
storage growth is representable **only** through such a policy. The provider-side mechanics — provisioning EC2/managed
nodes via Pulsar-driven Pulumi, and one provider-rounded per-PV EBS whose raw size matches the private PVC/PV
provision (identity/cardinality 1:1:1, not logical-byte equality) and is **decoupled from the
EC2/node lifecycle** so storage outlives the node — are owned by
[pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md) and
[storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md). Mechanically, **node provisioning is just
another reconcile** ([§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)): the desired node set is part of the `.dhall`, and the engine drives the live node
set toward it.

---

## 9. How bring-up and teardown are implemented: the reconciler, not a state machine

Every lifecycle action in this document — bring-up ([§2](#2-bring-up-and-bootstrap)), spawn ([§3](#3-amoebic-spawning--the-recursive-forest)), dynamic provisioning ([§8](#8-dynamic-node-provisioning)), and
teardown ([§5](#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)) — is the **same shape**: *observe the world, compare it to the `.dhall`, enact the diff,
re-observe.* There is no giant lifecycle state machine. This pattern is **generalized from the prodbox
sibling's** reconciler-with-predicates doctrine
(`/home/matthewnowak/prodbox/documents/engineering/lifecycle_reconciliation_doctrine.md`), lifted from
"AWS-resource-leak prevention" to "any cluster / child / node / stack / PV the forest can create."

- **`discover → diff → enact → re-observe`, idempotent by construction.** The loop runs until stable or it
  times out. Re-running a half-finished bring-up or teardown **converges** instead of erroring — crash
  recovery is just "run the reconciler again." This is the same idempotent-reconcile shape `bootstrap`
  re-runs as a no-op ([§2](#2-bring-up-and-bootstrap)).
- **Three-valued observation, fail-closed.** Each resource's `discover` returns **Present**, **Absent**, or
  **Unreachable**, and **`Unreachable → refuse`**: *"this could not be observed"* is never silently collapsed
  to *"it is gone."* A teardown that cannot confirm a resource is absent refuses rather than charging ahead
  and stranding live state — the same soundness rule as the [§6](#6-push-back-when-teardown-would-break-the-root-inforcespec) push-back and as the prodbox sibling's
  Sprint-4.19 gate.
- **A stretched `Site` cross-checks through this same three-valued gate.** A cluster node or host worker
  carries a declared network-locality `Site`
  ([substrate_doctrine.md §8.3](./substrate_doctrine.md#83-site-the-declared-network-locality-axis-cluster-nodes-and-host-worker-hosts))
  on a *declared-at-decode / cross-checked-at-runtime* discipline: a host declared at a remote `Site` that
  `discover` cannot actually reach over the fabric surfaces as **Unreachable**, so **`Unreachable → refuse`
  applies unchanged** — a remote entity mis-declared local, or a stretched host whose WAN link is down, is
  caught here, never silently admitted. This is the runtime residue behind the stretched-node reach witness
  ([cluster_topology_doctrine.md §4.1](./cluster_topology_doctrine.md#41-rke2-serveragent-cardinality-odd-quorum-by-union-distinctness-by-fold-taint-by-derivation));
  the declared `Site` and the fabric wiring are owned by
  [substrate §8.3](./substrate_doctrine.md#83-site-the-declared-network-locality-axis-cluster-nodes-and-host-worker-hosts)
  and the network-fabric doctrine, while this reconcile loop only classifies reachability.
- **A lifetime-aware managed-resource registry, not ad-hoc cleanup.** The set of things the system can
  create — clusters, children, dynamic nodes, Pulumi stacks, retained-PV API bindings, and durable backing
  stores — is a **single pure list of typed managed resources**. Each entry carries lifecycle metadata from
  its owning doctrine, `discover`, and its permitted absence action; a retained-PV API object and its backing
  store are separate resources. *Totality:* no code path may create a resource that is not in the registry
  with those operations, so "a creatable-but-unobservable resource" is unrepresentable. Ordinary teardown
  runs `reconcileAbsent` only over the owned **ephemeral** subset: *Present → destroy → re-observe; Absent →
  skip; Unreachable → refuse.* The lifetime and credential rules consumed here are owned by
  [pulumi_iac_doctrine.md §3](./pulumi_iac_doctrine.md#3-state-lifetime-matches-resource-lifetime-per-class),
  [storage_lifecycle_doctrine.md §7](./storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation),
  and [testing_doctrine.md §7](./testing_doctrine.md#7-the-elevated-harness-is-the-sole-automated-deleter-of-test-owned-durable-storage-leak-free-cycles).
- **Why not a global state machine.** The authoritative state lives in **external systems** — the kube API,
  the cloud API, MinIO — that this program cannot refresh transactionally. Any in-memory cross-product
  model goes stale the moment an eventually-consistent API answers, and crash recovery forces a re-discover
  anyway. "Data in, data out" — each `discover` queries the right authority *at the moment of use* — adds
  safety without the coupling a state machine would impose.
- **Driven by the control-plane singleton.** The reconcile loop is run by the in-cluster
  control-plane singleton (total cluster + secret authority), whose single-instance delegation and worker-role model
  are owned by [daemon_topology_doctrine.md](./daemon_topology_doctrine.md).

> **Honesty.** This reconciler model is *proven in prodbox* for AWS teardown; that is **evidence from a
> sibling system, not proof in amoebius**, which has not built Phases 2–3/9–10. Read every prescriptive
> statement here as design intent, never as a tested amoebius result
> ([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)).

---

## 10. Planning ownership

This document is normative cluster-lifecycle doctrine only. Delivery sequencing, completion status,
validation gates, and remaining work are owned by
[../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md), never restated here. For orientation
only (the plan is authoritative): bootstrap + a single kind cluster land in **Phase 14**; the baked image in
**Phase 15**; the SSA reconciler in **Phase 16**; retained storage in **Phase 17**; root Vault/PKI in
**Phase 18**; platform services in **Phases 19–20**; the control-plane singleton in **Phase 22**; amoebic
spawning + geo-replication in **Phase 28**; gateway failover + Route53 repoint in **Phase 29**;
provider-managed clusters + dynamic node provisioning in **Phase 30**; and the test-only teardown safety
harness in **Phase 36**. This doc states the target shape and links back for status.

---

## 11. RKE2 rollout as a reconcile

A multi-node `rke2` cluster does not come up by a bespoke bring-up script — it comes up the same way
everything else in this doctrine does: as a **reconcile** ([§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)) that drives the live node set toward a
**declared, typed server/agent topology**. That topology — the closed `Rke2Servers` union
`< Single | Ha3 | Ha5 >` (the only legal odd etcd quorums {1,3,5}) plus
`agents : Fixed [Rke2AgentNode] | Autoscaled { floor : [Rke2AgentNode], policy : ScalingPolicy }` — is owned
by [cluster_topology_doctrine.md §2/§4](./cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm); this doc owns only the lifecycle
verbs that stand it up. There is no rke2 state machine, exactly as there is no lifecycle state machine ([§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)).

This section is normative design, not a delivered live claim. Phases 4–7 own the pure node/reserve/template
model; live multi-node rke2 host admission, snapshot-bound join, and enforcement remain an explicitly
unassigned Phase-N gate. Phase 28's acceptance forest uses child `kind` clusters only.

- **Root = the zero-secret degenerate.** The root cluster is
  `{ servers = Rke2Servers.Single { host, capacity, systemReserve }, agents = Fixed [] }` — the target
  single-node rke2 shape of [§2](#2-bring-up-and-bootstrap). One server, an empty
  fixed agent pool, no join token minted, no SSH key required: the same **zero-secret** bring-up [§2](#2-bring-up-and-bootstrap) already depends
  on. Every larger cluster is this base plus a reconcile that adds nodes; the base is not a special case but
  the `Single`/`[]` corner of the general shape.
- **First server: `etcd cluster-init`, then mint the token.** On an empty control plane the reconcile's
  first enacted step is `etcd cluster-init` on the first server, which brings up the single-member etcd
  quorum and the kube-apiserver. **Only then** does the parent MINT the `Rke2NodeToken` — the shared join
  secret — and inject it (below).
- **Every later node joins via `server:` URL + token.** The further servers (the `Ha3`/`Ha5` arms) and all
  `agents` join by pointing their config at the first server's `server:` URL and presenting the minted token.
  Server-join grows the etcd quorum; agent-join adds a worker. **Rejoin is idempotent**: a node already
  joined is a no-op; a node that dropped re-presents the same token and re-attaches — the [§9](#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
  `discover → diff → enact → re-observe` loop, keyed by node identity/tag, applied to rke2 membership.
- **`config.yaml` is RENDERED read-only, not managed.** Each node's `/etc/rancher/rke2/config.yaml` is
  `render(nodeInventory)` — computed wholesale by the parent from the typed topology and written **read-only,
  never edited in place** — the same *render-not-manage* discipline as the WireGuard peer config. It is
  delivered on the lift's **`stdin`** for the intra-host frame descent ([dsl_doctrine.md §3](./dsl_doctrine.md#3-the-orchestration-surface-parameters-context-witness)),
  or as a **ConfigMap** for the in-cluster pod frame. The token appears in that rendered config as a
  name-resolved value **at render time**, never as a literal in any `.dhall`.
- **The join secret is `Rke2NodeToken`.** A parent-minted, parent-injected **Vault-KV `SecretRef`**,
  referenced strictly **by name** (never a value in `.dhall`) and rotatable — the same custody family as the
  SSH keys and Curve25519 WireGuard keys, owned by [vault_pki_doctrine.md](./vault_pki_doctrine.md). Dhall
  carries only the name; the bytes are injected out-of-band into the child's Vault, exactly as [§3](#3-amoebic-spawning--the-recursive-forest) already
  requires for every secret.
- **Two enactors, one reconciler tier — tier (b).** The rke2 host rollout is the **checkpoint-free
  tag-discovery HOST reconciler** — tier **(b)** of the reconciler taxonomy (create→tag→join-fabric→drain-by-tag),
  whose home is the spot-fleet reconciler in [pulumi_iac_doctrine.md §0](./pulumi_iac_doctrine.md#0-decision-record-why-pulumi-stays--and-why-that-is-not-the-helm-decision). It has
  **two enactors**: the **sudo host daemon** installs the *root* server on the host; the
  Deployment-`replicas=1` **in-cluster
  singleton** rolls out *child* servers and agents **over SSH** (the singleton's total cluster + secret
  authority is owned by [daemon_topology_doctrine.md](./daemon_topology_doctrine.md)). It is **not** the
  tier-(a) Pulumi-checkpointed cloud reconciler and **not** the tier-(c) SSA reconciler.
- **The SSA reconciler only fills the cluster *after* kube-apiserver is up.** The tier-(c) in-cluster
  **SSA/ApplySet** manifest reconciler ([manifest_generation_doctrine.md §5](./manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions))
  does **not** install rke2 — it applies workloads once the apiserver answers. The two tiers **compose in
  sequence**: tier (b) stands up the machines + the etcd/apiserver control plane; tier (c) then fills the
  running cluster. Neither is a state machine; each is `discover → diff → enact`.
- **A quorum change is a deliberate re-provision, never autoscale.** Changing the server arm
  (`Single`→`Ha3`, `Ha3`→`Ha5`) is a **declared topology change** reconciled toward — a deliberate
  re-provision, **never** triggered by a `ScalingPolicy`. The `ScalingPolicy` escape valve ([§8](#8-dynamic-node-provisioning);
  [resource_capacity_doctrine.md §6](./resource_capacity_doctrine.md#6-growable--scalingpolicy-the-escape-valve-amoebius-owns)) exists only in
  `Rke2AgentPool.Autoscaled` and grows the **agent pool beyond its declared floor within its finite quota**; it
  can never mint or drop an etcd voter. A 0- or 2-server (no-quorum / split-brain) control plane has no
  constructor at all — **type-foreclosed unrepresentable** via the closed `Rke2Servers` union
  ([cluster_topology_doctrine.md §2/§4](./cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm);
  [illegal_state_catalog.md §3.24](../illegal_state/illegal_state_topology.md#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain)). Host distinctness across `servers ∪ agentFloor`
  is the **decode-foreclosed** `mkRke2` decode fold, likewise owned by cluster_topology.
- **The server/agent axis is orthogonal.** Whether a host is a server or an agent is **DECLARED**, and it is
  independent of the **DETECTED** substrate and the selected runtime role (singleton, capacity scheduler, or
  worker) — orthogonal typed axes
  ([daemon_topology_doctrine.md](./daemon_topology_doctrine.md)), never fused: an rke2 server can run on any
  substrate, and the singleton's single-instance is delegated to k8s/etcd independently of a node's server/agent role.

> **Honesty (sibling evidence, not an amoebius result).** prodbox proves the **single-node base only**:
> `~/prodbox/src/Prodbox/CLI/Rke2.hs` installs `rke2-server.service`, writes
> `/etc/rancher/rke2/config.yaml` + `registries.yaml`, and tracks install markers, an inotify drop-in, and
> `uninstall.sh`; the golden plan `~/prodbox/test/golden/plans/rke2-reconcile.txt` is exactly the STEP-list
> `ensure_rke2_server_installed → enable/restart_rke2_service → sync_user_kubeconfig →
> wait_for_cluster_nodes_ready`. That is single-node `rke2-server` **only**. Multi-node server/agent +
> etcd-HA + the `Rke2NodeToken` join is **net-new across the whole sibling family** — hostbootstrap has
> **zero** rke2 code (its `HostTool` enum is Kubectl/Helm/Kind). Read this section as **design intent**, not
> a tested amoebius result; the plan owns sequencing ([§10](#10-planning-ownership),
> [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md)).

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Platform Services Doctrine](./platform_services_doctrine.md)
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md)
- [Substrate Doctrine](./substrate_doctrine.md)
- [Cluster Topology Doctrine](./cluster_topology_doctrine.md) — the `Kind` / `Rke2` / `Managed Eks` engine types and their topology; [§2](./cluster_topology_doctrine.md#2-computeengine-a-closed-union-eks-a-first-class-arm)/[§4](./cluster_topology_doctrine.md#4-topology-a-cluster-is-a-fold-over-its-nodes-and-cardinality-is-by-construction) own the closed `Rke2Servers` server/agent union ([§11](#11-rke2-rollout-as-a-reconcile))
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md) — the push-back capacity fold and the `ScalingPolicy` escape valve (grows the `agents` list only, [§11](#11-rke2-rollout-as-a-reconcile))
- [Vault / PKI Doctrine](./vault_pki_doctrine.md) — the `Rke2NodeToken` join secret's custody ([§11](./vault_pki_doctrine.md#11-error-model-and-no-leak-logging))
- [Chaos / Failover Doctrine](./chaos_failover_doctrine.md)
- [Gateway Migration Doctrine](./gateway_migration_doctrine.md) — the `GatewayMigration = <Planned | Failover>` taxonomy and the live-to-live migration protocol; a teardown's gateway handoff ([§5](#5-teardown-with-cleanup-vs-chaos-failover-the-central-distinction)) is one `Planned` trigger
- [Pulumi IaC Doctrine](./pulumi_iac_doctrine.md) — [§0](./pulumi_iac_doctrine.md#0-decision-record-why-pulumi-stays--and-why-that-is-not-the-helm-decision) is the home of the checkpoint-free tag-discovery host reconciler, tier (b) ([§11](#11-rke2-rollout-as-a-reconcile))
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — [§5](./manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions), the in-cluster SSA/ApplySet reconciler, tier (c), that fills the cluster after the apiserver is up ([§11](#11-rke2-rollout-as-a-reconcile))
- [Illegal State Catalog](../illegal_state/illegal_state_catalog.md) — [§3.24](../illegal_state/illegal_state_topology.md#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain), an even/zero-server rke2 control plane as type-foreclosed unrepresentable ([§11](#11-rke2-rollout-as-a-reconcile))
- [App vs Deployment Doctrine](./app_vs_deployment_doctrine.md)
- [Daemon Topology Doctrine](./daemon_topology_doctrine.md) — the sudo host daemon and in-cluster singleton enactors of the rke2 rollout ([§11](#11-rke2-rollout-as-a-reconcile))
- [Pulsar Client Doctrine](./pulsar_client_doctrine.md)
- [Testing Doctrine](./testing_doctrine.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
