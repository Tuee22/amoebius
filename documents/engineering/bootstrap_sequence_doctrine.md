# The Bootstrap Sequence & the Admin Control Plane

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/illegal_state_catalog.md, documents/engineering/monitoring_doctrine.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Single Source of Truth for the ordered path from a bare host to a reconciling cluster — the
> host-daemon→singleton handoff — and for the **admin control plane** that takes over at handoff: after
> bootstrap the operator CLI drives the cluster **exclusively through the amoebius NodePort REST service on
> the in-cluster singleton** (`vault init/unseal`, `dhall update`), never by touching kube-apiserver again.

---

## 1. Why this doctrine exists

Two questions in the vision are left unowned by the docs that touch them:

> *"when the host daemon is bootstrapping a cluster, what is the exact sequence, and handoff of control to
> the cluster daemon?"* — and — *"how does a new `.dhall` get implemented or unlock keys provided in the root
> node? does the project binary provide a thin cli tool to interact with the amoebius daemon api?"*

The bring-up *pieces* exist — `bootstrap.sh` ([`substrate_doctrine.md` §6](./substrate_doctrine.md#6-the-bootstrapsh-contract-ensure-a-toolchain-build-the-binary-hand-off)),
"init follows readiness" ([`cluster_lifecycle_doctrine.md` §2](./cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap)),
the "midwife, not the brain" host daemon ([`daemon_topology_doctrine.md` §2](./daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid)),
Vault init/unseal ([`vault_pki_doctrine.md` §4](./vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init)),
and the handoff *trigger* ([`readiness_ordering_doctrine.md` §5](./readiness_ordering_doctrine.md#5-the-bootstrap-tier-local-observed-witnesses-never-timers))
— but the **ordered sequence** was derivable-across-five-docs, never written, and the **admin control plane**
the handoff hands *to* did not exist in doctrine at all. This doc owns both: the sequence ([§3](#3-the-ordered-bootstrap-sequence)),
the handoff mechanics ([§4](#4-the-host-daemon--singleton-handoff)), and the admin REST surface ([§5](#5-the-admin-control-plane-the-cli--the-singleton-rest-api)).
It resolves `notes.txt` lines 27/31/33.

---

## 2. Two régimes: host-driven bootstrap, then singleton-driven steady state

A cluster's life has **two régimes with a single, one-way handoff between
them**, and *who may touch the cluster's control surface* differs across them:

- **Bootstrap régime — the host binary drives.** Before an in-cluster brain exists, the sudo host daemon is
  the only actor that can stand the cluster up. It talks to `kube-apiserver` directly over the distro's
  default mTLS — **channel 1** of [`host_cluster_comms_doctrine.md` §4](./host_cluster_comms_doctrine.md#4-channel-1--the-host-binary--kube-apiserver-via-distro-mtls)
  — to install the distro, apply the platform manifests, and bring up the in-cluster singleton. It is the
  *midwife*, acting on behalf of the future singleton ([`daemon_topology_doctrine.md` §2](./daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid)).
- **Steady-state régime — the singleton drives.** Once the platform services **and** the elected
  control-plane singleton are up and reachable, the host binary **defers**. From that instant — *even before
  Vault is initialised* — every operator interaction flows through the **admin control plane**
  ([§5](#5-the-admin-control-plane-the-cli--the-singleton-rest-api)): the operator CLI → the amoebius NodePort
  REST service → the singleton. **Channel 1 is bootstrap-only**; the host binary does not resume direct
  kube-apiserver control after handoff.

This is the shape the vision specified: *"the host binary only directly interacts with the cluster and
k8s control plane during initial bootstrap … once all services are up (even before vault init) all further
interactions occur through the [amoebius] NodePort."* The one-way handoff is [§4](#4-the-host-daemon--singleton-handoff).

```mermaid
flowchart TD
  sh[bootstrap.sh: toolchain, build, exec binary] --> hb[Host binary / sudo host daemon]
  hb -->|channel 1: distro mTLS, BOOTSTRAP ONLY| api[kube-apiserver: install distro + apply platform manifests]
  api --> svc[Platform services up in the readiness DAG order]
  svc --> singleton[In-cluster singleton pod up + elected]
  singleton -->|exposes| rest[amoebius NodePort REST admin API]
  singleton -.->|HANDOFF: /readyz + election-commit observed| hb
  cli[Operator CLI] -->|vault init/unseal, then dhall update| rest
  rest --> reconcile[Singleton reconciles the cluster toward its InForceSpec]
```

---

## 3. The ordered bootstrap sequence

The sequence is a [`readiness_ordering_doctrine.md`](./readiness_ordering_doctrine.md) DAG — **every edge is
an observed condition, never an elapsed wait** — enacted by the reconciler
([`cluster_lifecycle_doctrine.md` §9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)).
The ordered steps, each gated on the prior step's readiness:

1. **`bootstrap.sh`** ensures the toolchain, builds the binary, and `exec`s `amoebius bootstrap
   --distro={kind,rke2}` ([`substrate_doctrine.md` §6](./substrate_doctrine.md#6-the-bootstrapsh-contract-ensure-a-toolchain-build-the-binary-hand-off)).
2. **The host daemon brings up the distro** — the zero-secret single-node root (`kind`, or
   `Rke2Servers.Single`) — and waits on `discover = Present` for `kube-apiserver` (a successful mTLS call,
   not a timer; [`readiness_ordering_doctrine.md` §5](./readiness_ordering_doctrine.md#5-the-bootstrap-tier-local-observed-witnesses-never-timers)).
3. **Platform services come up** in the derived bring-up DAG order — registry → …, LB → edge, everything
   Vault-sealed for now ([`platform_services_doctrine.md` §11](./platform_services_doctrine.md#11-bring-up-and-dependency-ordering)),
   applied by the tier-(c) SSA reconciler once the apiserver answers
   ([`manifest_generation_doctrine.md` §5](./manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait)).
4. **The control-plane singleton pod comes up and is elected** ([`daemon_topology_doctrine.md` §3](./daemon_topology_doctrine.md#3-the-control-plane-singleton--exactly-one-elected))
   and **exposes the admin REST service** ([§5](#5-the-admin-control-plane-the-cli--the-singleton-rest-api)). This is the **handoff point** ([§4](#4-the-host-daemon--singleton-handoff)).
5. **The operator initialises/unseals Vault through the admin REST** — `vault init/unseal`, authenticated by
   the operator password; init-once / unseal-on-rebuild ([`vault_pki_doctrine.md` §4](./vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init),
   [§5](./vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal)). No secret consumer ran before this — Vault fails closed until unsealed.
6. **The operator delivers the `InForceSpec`** — `dhall update` (requires an **unsealed Vault + root token**,
   [§5](#5-the-admin-control-plane-the-cli--the-singleton-rest-api)) — the spec delivery of
   [`vault_pki_doctrine.md` §4](./vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init). The singleton decrypts it in-process and reconciles the cluster toward it.

This is the **root** bootstrap; a *child* cluster is spawned by a parent (the Pulumi handoff,
[`cluster_lifecycle_doctrine.md` §3](./cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)),
which injects the child's scoped `InForceSpec` + secrets rather than prompting a human. This ordered sequence **retires
the open question** [`cluster_lifecycle_doctrine.md` §2](./cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap)
recorded (bootstrap config / first-manifest delivery): the first manifest is delivered by step 6's `dhall
update`, and the transient bootstrap config is the binary-sibling `amoebius.dhall` `bootstrap.sh` establishes.

---

## 4. The host-daemon → singleton handoff

The handoff is **one-way, observed-gated, and transfers control-surface authority only**:

- **The trigger is an edge, never a delay.** The host daemon hands off once it observes the singleton
  **`/readyz` (a `Serving` edge)** *and* **the election commit on the coordination log (a `Committed` edge)**
  — the gate owned by [`readiness_ordering_doctrine.md` §5](./readiness_ordering_doctrine.md#5-the-bootstrap-tier-local-observed-witnesses-never-timers).
  Never "sleep, then assume the pod is up."
- **What transfers: the cluster control surface.** After handoff, amoebius-level control (Vault
  init/unseal, spec delivery, reconcile triggers) is the **elected singleton's** sole authority
  ([`daemon_topology_doctrine.md` §3](./daemon_topology_doctrine.md#3-the-control-plane-singleton--exactly-one-elected)),
  reached only through the admin REST ([§5](#5-the-admin-control-plane-the-cli--the-singleton-rest-api)).
  Channel 1 (host binary ↔ kube-apiserver) is **retired** — a bootstrap-only privilege.
- **What does *not* transfer: host-worker supervision.** The sudo host daemon keeps supervising host-level
  worker subprocesses (Apple-Metal / Windows-CUDA inference), which remain Pulsar/MinIO peers on **channel
  2** ([`host_cluster_comms_doctrine.md` §3](./host_cluster_comms_doctrine.md#3-there-is-no-bespoke-control-channel--coordination-is-pulsar--minio)).
  "Midwife then defers" is about the *control* surface, not the host daemon's whole existence.
- **Re-running is a no-op.** Because bring-up is a reconcile
  ([`cluster_lifecycle_doctrine.md` §9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)),
  a crashed bootstrap re-runs and converges; a handoff already done is observed and skipped.

---

## 5. The admin control plane: the CLI ↔ the singleton REST API

After handoff, the operator drives the cluster through **one surface**: the operator CLI (`pb`) → the
**amoebius NodePort service** → a **REST API on the in-cluster singleton**. This is the vision's *"thin cli
tool [that] interact[s] with the amoebius daemon api"* — and the answer is a typed REST control plane, not a
second binary.

- **The endpoints.** The two load-bearing ones:
  - **`vault init/unseal`** — authenticated by the **operator password** (Argon2id→AEAD unlock material,
    [`vault_pki_doctrine.md` §5](./vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal));
    this is the concrete channel that fills the *pluggable pre-Vault unseal seam* that doctrine explicitly
    left open. The operator password crosses CLI → NodePort → singleton and is never persisted.
  - **`dhall update`** — deliver a new `InForceSpec` to a running cluster. It **requires an unsealed Vault
    and a root token**; the singleton decrypts/stores the envelope in-process
    ([`vault_pki_doctrine.md` §4](./vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init))
    and reconciles toward it. This is how a new desired-state Dhall value reaches an already-running root — the operator flow
    the reconcile mechanics ([`daemon_topology_doctrine.md` §6](./daemon_topology_doctrine.md#6-the-shared-daemon-spine) hot-reload) only hinted at.
- **This is the admin plane, distinct from the workload plane.** [`host_cluster_comms_doctrine.md` §3](./host_cluster_comms_doctrine.md#3-there-is-no-bespoke-control-channel--coordination-is-pulsar--minio)'s
  "no bespoke control channel — coordination *is* Pulsar + MinIO" governs the **worker/workload** plane (host
  compute daemons + the host binary *coordinating* with workers). It is **not** an admin-plane rule: operator
  administration of the cluster's own configuration is a *control* concern, not worker coordination, and rides
  this REST channel. That doc's scope is clarified accordingly; this doc owns the admin channel.
- **Privileged, not wild — so not a Keycloak bypass.** The admin REST is authenticated (operator password →
  then root token + unsealed Vault) and **network-restricted to the operator's trusted reach** (host-local
  during bootstrap; the authenticated WireGuard fabric thereafter,
  [`host_cluster_comms_doctrine.md` §5.1](./host_cluster_comms_doctrine.md#51-the-generalization-localhost-or-the-authenticated-wireguard-fabric)),
  never the wild LB→Envoy→Keycloak door ([`platform_services_doctrine.md` §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)).
  Like channel 1, it is a privileged operator path, not wild ingress — so "Keycloak owns all *wild* ingress"
  is untouched. Its transport trust before the root PKI anchor exists rides the chicken-and-egg floor
  ([`vault_pki_doctrine.md` §10](./vault_pki_doctrine.md#10-the-chicken-and-egg-floor-what-stays-outside-vault)).

---

## 6. What this forecloses, and the honest limits

The admin plane is a place to make illegal control actions **unrepresentable**, on the catalog's
[three layers](./illegal_state_catalog.md#6-three-layers-of-foreclosure-and-the-honesty-they-force):

- **A `dhall update` without an unsealed Vault + root token has no constructor** — the mutation is
  `type-foreclosed`: its handle is built only *from* a `RootToken` capability and an `Unsealed` witness
  ([`illegal_state_catalog.md` §3.42](./illegal_state_catalog.md#342-an-admin-mutation-without-a-root-token-capability--an-unsealed-vault-witness),
  the same capability + `.ready`-style edge discipline as the `PromotionGate` and the `Readiness` edge).
- **An admin action bypassing the singleton is unrepresentable** by construction: post-handoff there is no
  exported channel-1 verb; the only control-surface constructor is an admin-REST call.
- **The honest limit** ([`illegal_state_catalog.md` §2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)):
  the type forecloses the *shape* of the control surface; that the singleton *actually* holds sole authority
  at runtime (single-writer, no split-brain admin) is `runtime-checked`, owned by the election safety of
  [`daemon_topology_doctrine.md` §5](./daemon_topology_doctrine.md#5-leadership-election--the-mechanism-the-proof-lives-elsewhere)
  and [`chaos_failover_doctrine.md`](./chaos_failover_doctrine.md).

**Still open (deliberately, scoped narrower by this doc):** whether the **root may ever be multi-node**
(unchanged from [`cluster_lifecycle_doctrine.md` §2](./cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap)) —
this doc specifies the single-node-root answer the plan adopts and does not settle the multi-node question.

---

## 7. Planning ownership

This document is normative bootstrap-sequence + admin-control-plane doctrine only. Delivery sequencing,
status, and gates are owned by [`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md), never
restated here. For orientation only (the plan is authoritative): the **ordered sequence + host→singleton
handoff** ride **Phase 1** (bootstrap + kernel + kind); the **`vault init/unseal` admin endpoint** rides
**Phase 2** (root Vault/PKI); the **`dhall update` endpoint + the elected singleton REST surface** ride
**Phase 3** (the control-plane singleton). This doc states the target shape and links back for status.

> **Honesty.** Everything here is Phase 0 design intent, specified before implementation. The "midwife then
> defers" host-daemon model and the reconcile-driven bring-up are *proven in the prodbox / hostbootstrap
> siblings* and inherited as evidence, not a tested amoebius result
> ([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)).

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md) — [§2](./cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap) the bring-up this sequences (its open question retired here), [§9](./cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine) the reconciler that enacts each edge
- [Daemon Topology Doctrine](./daemon_topology_doctrine.md) — [§2](./daemon_topology_doctrine.md#2-context--role-an-orthogonal-grid) midwife-then-defers, [§3](./daemon_topology_doctrine.md#3-the-control-plane-singleton--exactly-one-elected) the singleton that exposes the admin REST
- [Vault / PKI Doctrine](./vault_pki_doctrine.md) — [§4](./vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init) init-follows-readiness, [§5](./vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal) the operator-password unseal the admin endpoint carries, [§10](./vault_pki_doctrine.md#10-the-chicken-and-egg-floor-what-stays-outside-vault) the pre-Vault trust floor
- [Host ↔ Cluster Comms Doctrine](./host_cluster_comms_doctrine.md) — [§3](./host_cluster_comms_doctrine.md#3-there-is-no-bespoke-control-channel--coordination-is-pulsar--minio) the workload-plane rule this admin plane is distinct from; [§4](./host_cluster_comms_doctrine.md#4-channel-1--the-host-binary--kube-apiserver-via-distro-mtls) channel 1 (bootstrap-only)
- [Readiness Ordering Doctrine](./readiness_ordering_doctrine.md) — [§5](./readiness_ordering_doctrine.md#5-the-bootstrap-tier-local-observed-witnesses-never-timers) the handoff trigger (/readyz + election-commit)
- [Substrate Doctrine](./substrate_doctrine.md) — [§6](./substrate_doctrine.md#6-the-bootstrapsh-contract-ensure-a-toolchain-build-the-binary-hand-off) the `bootstrap.sh` igniter
- [Platform Services Doctrine](./platform_services_doctrine.md) — [§11](./platform_services_doctrine.md#11-bring-up-and-dependency-ordering) the derived platform bring-up DAG
- [Illegal State Catalog](./illegal_state_catalog.md) — [§3.42](./illegal_state_catalog.md#342-an-admin-mutation-without-a-root-token-capability--an-unsealed-vault-witness) an unauthenticated admin mutation foreclosed
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
