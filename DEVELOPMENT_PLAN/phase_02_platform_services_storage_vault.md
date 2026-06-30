# Phase 2: Platform services + retained storage + root Vault/PKI

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, later_phases.md, legacy_tracking_for_deletion.md, overview.md, system_components.md
**Generated sections**: none

> **Purpose**: Stand up the full standard-service stack on a single-node linux-cpu cluster — rendered as
> typed manifests by amoebius's own reconciler, run from baked-binary images in the in-cluster registry,
> on no-provisioner retained storage, fronted by a Keycloak-owned ingress, rooted in a password-encrypted
> single-node Vault and its self-signed PKI anchor.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is design intent. The platform-service
stack, the typed reconciler, the baked-binary image pipeline, retained storage, and the root Vault/PKI are
all target shapes inherited as *evidence* from the sibling prodbox project, not yet amoebius results. Status
transitions are recorded reverse-chronologically here once work begins.

## Phase Summary

This phase turns the empty kind cluster delivered by Phase 1 into a fully-provisioned amoebius cluster
carrying the complete **standard platform-service set** ([README.md](README.md) → *Standard platform
services*): the `distribution` registry (replacing Harbor), MinIO, Vault, Pulsar, Prometheus/Grafana,
Percona/Patroni Postgres + pgAdmin, Envoy / Gateway API, Keycloak, and MetalLB. Every one of those services
is rendered as **typed Kubernetes manifests from pure Haskell** (no Helm, no third-party charts) and applied
by amoebius's own **server-side-apply reconciler**; every image is **pulled only from the in-cluster
registry**, served from binaries **baked into the multi-arch base container** rather than pulled from any
public registry; every durable byte lives on a **`no-provisioner` retained PV** that rebinds deterministically
across a cluster delete + recreate; the secrets root is a **single-node, password-encrypted Vault** that a
human unseals, and that Vault holds the **self-signed PKI trust anchor** for the forest. Ingress is the
single Keycloak-owned door; no workload opens its own wild path.

The scope deliberately stops at *standing the stack up and proving it rebinds*. The orchestration Dhall DSL,
the service-capability abstraction, and the elected in-cluster control-plane singleton that will eventually
*own* the reconciler are Phase 3 concerns; this phase exercises the reconciler from the host binary against a
fixed, hand-assembled service set so the platform exists before the DSL that will describe it. Pulsar is new
relative to prodbox and is therefore the least evidence-backed service in the set.

**Substrate:** linux-cpu (§L) — the whole gate runs on a single-node `kind` cluster on a linux-cpu host; no
apple, linux-cuda, or windows substrate is touched in Phase 2.

**Gate:** all standard services are up (from generated manifests + baked-binary images, with **no
public-registry pulls**), HA-shaped, and reachable; **ingress is reachable only via Keycloak**; and durable
**storage rebinds after a cluster delete + recreate with no data loss** — demonstrated by writing a marker
row/object into a Postgres cluster and a MinIO bucket, tearing the cluster down, recreating it, and reading
the same bytes back.

```text
phase 1 empty kind cluster (external prereq)
  -> 2.1 base container + distribution registry  (image source exists)
  -> 2.2 typed renderer + SSA reconciler          (apply engine exists)
  -> 2.3 no-provisioner retained storage          (durable land exists)
  -> 2.4 root Vault + PKI anchor                  (secrets root + trust anchor)
  -> 2.5 standard service stack (MinIO/Pulsar/Postgres/observability/MetalLB)
  -> 2.6 Keycloak-owned ingress + lossless-rebind gate
```

## Doctrine adopted

This phase is the first implementation of five doctrines. Each bullet names the section this phase realizes;
individual sprints cite the same sections where they adopt them.

- [`platform_services_doctrine.md` §1 — The Invariant: every cluster is the same cluster](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster):
  Phase 2 materializes the fixed standard service set on the linux-cpu substrate, each service
  **HA-always even at `replicas=1`** ([§2 — HA always, including `replicas=1`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1)),
  with **every container declaring CPU and RAM**, the single **Keycloak-owned wild-ingress door**
  ([§9 — the LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)),
  and the hard bring-up ordering edges of
  [§11 — Bring-up and dependency ordering](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering).
- [`manifest_generation_doctrine.md` §5 — the apply/reconcile engine: server-side apply, owned field manager, prune, wait](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait):
  Phase 2 builds the pure
  [§2 typed `render :: ServiceSpec -> [K8sObject]`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects)
  and the `discover → diff → enact` reconciler — server-side apply under a fixed `amoebius` field manager,
  ApplySet pruning, and wait-for-ready — that replaces Helm; **no third-party charts**, with operators
  *generated*
  ([§4](../documents/engineering/manifest_generation_doctrine.md#4-no-third-party-charts--no-third-party-software-operators-are-generated)).
- [`image_build_doctrine.md` §2 — the single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster):
  Phase 2 produces the **multi-arch base container** with every third-party service binary baked
  (apt → official binary → build-from-source, incl. a Temurin JRE), published as one
  [§3 buildx manifest list](../documents/engineering/image_build_doctrine.md#3-buildx-multi-arch--amd64-and-arm64-one-manifest-list)
  into the single-binary `distribution` registry, so nothing in-cluster ever pulls from a public registry.
- [`storage_lifecycle_doctrine.md` §2 — one storage class, and it provisions nothing](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing):
  Phase 2 installs the single inert `no-provisioner` / `Retain` StorageClass, deterministic
  [§4 `<namespace>/<statefulset>/pv_<integer>` naming with explicit `claimRef`](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind),
  and proves the
  [§6 lossless-teardown guarantee](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind)
  — durable bytes rebind across a cluster delete + recreate.
- [`vault_pki_doctrine.md` §5 — the root cluster: single-node, password-encrypted unseal](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal):
  Phase 2 brings up the root Vault as a single-node, password-encrypted (Argon2id + AEAD, never raw SHA-256),
  human-gated, **fail-closed**
  ([§4 init follows readiness](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init))
  secrets root, init-once / unseal-on-rebuild, that owns the self-signed
  [§8 PKI trust anchor](../documents/engineering/vault_pki_doctrine.md#8-the-root-cluster-owns-the-pki-trust-anchor),
  with in-cluster consumers authenticating
  [§9 directly via Vault Kubernetes auth](../documents/engineering/vault_pki_doctrine.md#9-in-cluster-consumers-authenticate-to-vault-directly).

## Sprints

## Sprint 2.1: Multi-arch base container + `distribution` registry 📋

**Status**: Planned
**Implementation**: `docker/base/Dockerfile`, `src/Amoebius/Image/Build.hs`, `src/Amoebius/Image/Registry.hs` (target paths; not yet built)
**Blocked by**: Phase 1 gate (external prereq — an empty single-node `kind` cluster brought up idempotently)
**Independent Validation**: the published tag resolves as one OCI manifest list covering `amd64` and `arm64`; a node-side pull of every platform image succeeds against the in-cluster registry with **zero** requests leaving for a public registry (verified by a deny-all egress test to `docker.io`/`quay.io`).
**Docs to update**: `documents/engineering/image_build_doctrine.md`, `documents/engineering/platform_services_doctrine.md`

### Objective

Adopt [`image_build_doctrine.md` §2 — the single distribution rule](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster)
and [§7 — what amoebius bakes vs builds](../documents/engineering/image_build_doctrine.md#7-what-amoebius-bakes-vs-builds--the-base-container-is-the-supply-chain):
bake every third-party service binary into one multi-arch base container and stand up the single-binary
`distribution` registry as the sole in-cluster pull source ([`platform_services_doctrine.md` §3 — the
registry, the single image source](../documents/engineering/platform_services_doctrine.md#3-the-registry--the-single-image-source)).

### Deliverables

- A multi-arch base `Dockerfile` baking each platform binary by the supply-chain preference order
  (apt → official binary/tarball → build-from-source), including a Temurin JRE for the JVM services
  (Keycloak, Pulsar) and the `distribution` (`registry:2`), MinIO, Vault, Pulsar, Prometheus, Grafana,
  Envoy, the Percona operator, and MetalLB binaries.
- A `docker buildx --platform linux/amd64,linux/arm64` build that publishes **one** OCI manifest list per
  tag, with **atomic publication** — a partial multi-arch push is recorded as a failed, un-advertised tag
  ([§4 — atomic publication](../documents/engineering/image_build_doctrine.md#4-atomic-publication--a-partial-multi-arch-upload-is-a-failed-upload)).
- The `distribution` registry rendered as a standard service (no Patroni DB; blobs on a retained PV) and
  reachable at the host-only registry endpoint, with the per-distro plumbing that makes that endpoint
  resolve on the kind node.
- Immutable, content-pinned image refs (never `:latest`) shared identically across both arches.

### Validation

1. Build the base image; assert `docker buildx imagetools inspect <tag>` lists both `linux/amd64` and
   `linux/arm64` under one manifest list.
2. Bring the registry up on the kind node; pull each platform image from it; assert every pull resolves
   in-cluster and a network policy denying egress to public registries does not break any pull.
3. Re-run the build against a fully-published tag and assert a no-op (idempotent publication).

### Remaining Work

The whole sprint.

## Sprint 2.2: Typed renderer + server-side-apply reconciler 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/Types.hs`, `src/Amoebius/Manifest/Render.hs`, `src/Amoebius/Manifest/Reconcile.hs` (target paths; not yet built)
**Blocked by**: Sprint 2.1 (the reconciler applies workloads whose images resolve only against the in-cluster registry)
**Independent Validation**: `render` is pure and total, so unit tests assert properties of the emitted `[K8sObject]` (every container has requests+limits, no `LoadBalancer` Service outside the edge, RBAC grants exactly the declared verbs) **without a cluster**; the reconciler is then proven against a throwaway namespace on the kind cluster.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md`, `documents/engineering/platform_services_doctrine.md`

### Objective

Adopt [`manifest_generation_doctrine.md` §2 — the typed manifest model](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects)
and [§5 — the apply/reconcile engine](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait):
build the pure `render :: ServiceSpec -> [K8sObject]` and the `discover → diff → enact` reconciler that
replaces Helm — and the [§4 generate-don't-chart treatment of operators](../documents/engineering/manifest_generation_doctrine.md#4-no-third-party-charts--no-third-party-software-operators-are-generated)
whose CRDs, controller Deployments, and CR instances are emitted as typed objects.

### Deliverables

- A typed `K8sObject` model (Deployment / StatefulSet / Service / RBAC triple / NetworkPolicy / HTTPRoute /
  Gateway / ConfigMap / CRD / CR instance) serialized to JSON via Aeson — the record *is* the manifest, no
  text template, no `values.yaml`.
- `render`, a pure total function producing best-practice-by-construction objects: required non-zero
  CPU/RAM requests+limits, a hardened `securityContext` on every pod, least-privilege per-workload RBAC,
  and default-deny + derived-allow NetworkPolicies.
- The reconciler: **server-side apply under a fixed `amoebius` field manager**, an `amoebius/owner`
  label on every object, **ApplySet pruning** of prior-owned objects no longer desired, and
  **wait-for-ready** observed from the live object (never a `threadDelay`).
- Desired state recomputed as `render(spec)` with **no release store** to desync
  ([§6 — the reconcile state model](../documents/engineering/manifest_generation_doctrine.md#6-the-reconcile-state-model-desired-is-renderdhall-observed-is-etcd-a-diff-is-typed)).

### Validation

1. Pure unit tests over the emitted `[K8sObject]` for a representative service, asserting the
   best-practice invariants — no kind cluster required.
2. Apply a generation to a scratch namespace; mutate a field amoebius owns; re-apply and assert drift
   self-heals; remove a service from the desired set and assert its objects are pruned.
3. `amoebius … --dry-run` prints exactly the object set a subsequent apply enacts.

### Remaining Work

The whole sprint.

## Sprint 2.3: No-provisioner retained storage 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Storage/StorageClass.hs`, `src/Amoebius/Storage/RetainedPV.hs` (target paths; not yet built)
**Blocked by**: Sprint 2.2 (the StorageClass, the retained PVs, and their `claimRef` pins are rendered and applied through the reconciler)
**Independent Validation**: after bring-up there is exactly one StorageClass (`no-provisioner` / `Retain` / `WaitForFirstConsumer`) and no other default class; a StatefulSet ordinal binds to the `claimRef`-pinned PV named `<namespace>/<statefulset>/pv_<integer>`; deleting the PVC leaves the PV `Released` with bytes intact.
**Docs to update**: `documents/engineering/storage_lifecycle_doctrine.md`, `documents/engineering/platform_services_doctrine.md`

### Objective

Adopt [`storage_lifecycle_doctrine.md` §2 — one storage class, and it provisions nothing](../documents/engineering/storage_lifecycle_doctrine.md#2-one-storage-class-and-it-provisions-nothing)
and [§4 — deterministic PV naming and the explicit bind](../documents/engineering/storage_lifecycle_doctrine.md#4-deterministic-pv-naming-and-the-explicit-bind):
make durable storage a *different kind of thing* from the cluster — one inert StorageClass, retained PVs
pinned by identity, host-path-backed on linux-cpu, sized explicitly per [§5](../documents/engineering/storage_lifecycle_doctrine.md#5-sizes-are-explicit-hard-capped-and-one-volume-per-claim).

### Deliverables

- A single rendered StorageClass: `provisioner: kubernetes.io/no-provisioner`, `reclaimPolicy: Retain`,
  `volumeBindingMode: WaitForFirstConsumer`; every other StorageClass removed and any competing default
  annotation stripped.
- Deterministic PV generation from `(namespace, statefulset, ordinal)`: PV name
  `<namespace>/<statefulset>/pv_<integer>`, explicit `claimRef` to the exact `(namespace, PVC-name)`, and
  node affinity to the host-path node for host-backed volumes.
- The invariant that **a PVC is only ever born from a StatefulSet `volumeClaimTemplate`** — no bare PVCs,
  no Deployment- or Job-mounted claims.
- Explicit per-PVC minimum size and per-PV capacity, one volume per claim (the host-side hard-cap
  enforcement mechanism is flagged as design intent, not built).

### Validation

1. Assert post-bring-up there is exactly one StorageClass and it provisions nothing.
2. Deploy a one-ordinal StatefulSet; assert its claim binds to the identity-named, `claimRef`-pinned PV.
3. Delete the PVC; assert the PV drops to `Released`, retains its bytes, and is re-bindable.

### Remaining Work

The whole sprint.

## Sprint 2.4: Root Vault + PKI trust anchor 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Vault/Init.hs`, `src/Amoebius/Vault/Unseal.hs`, `src/Amoebius/Vault/Pki.hs` (target paths; not yet built)
**Blocked by**: Sprint 2.2 (Vault is rendered + applied through the reconciler), Sprint 2.3 (Vault's durable KV lives on a retained PV so a rebuild *unseals* rather than re-initializes)
**Independent Validation**: a sealed Vault fails secret-dependent startup *closed* with no plaintext fallback; `vault init` runs exactly once on the empty PV and a subsequent bring-up only unseals; the operator password (Argon2id + AEAD, never raw SHA-256) is the sole human-supplied secret and is persisted nowhere; the `pki/` engine serves a self-signed root CA.
**Docs to update**: `documents/engineering/vault_pki_doctrine.md`, `documents/engineering/platform_services_doctrine.md`, `documents/engineering/storage_lifecycle_doctrine.md`

### Objective

Adopt [`vault_pki_doctrine.md` §5 — the root cluster: single-node, password-encrypted unseal](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal)
and [§8 — the root cluster owns the PKI trust anchor](../documents/engineering/vault_pki_doctrine.md#8-the-root-cluster-owns-the-pki-trust-anchor):
bring up the single-node, password-encrypted, human-gated, **fail-closed** secrets root
([§4 — init follows readiness](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init))
and make its Vault `pki/` the one self-signed trust anchor, with in-cluster consumers reading secrets
[§9 directly via Vault Kubernetes auth](../documents/engineering/vault_pki_doctrine.md#9-in-cluster-consumers-authenticate-to-vault-directly).

### Deliverables

- Root Vault in Shamir seal mode, deployed against the retained PV from Sprint 2.3; **init-once /
  unseal-on-rebuild** — `vault init` runs exactly once when the PV is empty, and every later bring-up only
  unseals against existing data (no key regeneration).
- Password-encrypted unlock material: the first-ever init's unseal/recovery keys + root token sealed under
  the operator's password with a real KDF (Argon2id) feeding an AEAD (ChaCha20-Poly1305 / AES-256-GCM) —
  the password memorized, supplied at the prompt, persisted nowhere; raw keys never printed.
- Fail-closed startup ordering: no secret-dependent workload runs before Vault reports reachable,
  initialized, and unsealed; a consumer reaching a sealed Vault fails closed.
- The Vault `pki/` engine holding a self-signed **root CA** as the forest trust anchor; in-cluster
  consumers authenticate via Vault Kubernetes auth (no Dhall-mounted credential fragment, no environment
  variable).

### Validation

1. On an empty PV, run init; capture that init produced password-sealed unlock material and never printed
   raw keys; delete + recreate the cluster and assert the bring-up *unseals* the same Vault (no re-init).
2. Start a secret-dependent workload against a sealed Vault and assert it fails closed.
3. Issue an internal leaf cert from `pki/` and assert it chains to the self-signed root CA.

### Remaining Work

The whole sprint.

## Sprint 2.5: Standard platform-service stack 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Services.hs`, `src/Amoebius/Platform/Minio.hs`, `src/Amoebius/Platform/Pulsar.hs`, `src/Amoebius/Platform/Postgres.hs`, `src/Amoebius/Platform/Observability.hs`, `src/Amoebius/Platform/LoadBalancer.hs` (target paths; not yet built)
**Blocked by**: Sprint 2.1 (images), Sprint 2.2 (reconciler), Sprint 2.3 (retained storage), Sprint 2.4 (Vault-backed secrets)
**Independent Validation**: each service is the HA chart even at `replicas=1` (Postgres is a Patroni-via-Percona cluster, never a bare Pod); every container declares CPU/RAM; the Percona operator reconciles a per-consumer `PerconaPGCluster`; MinIO/Pulsar round-trip a put/get and a produce/consume; the bring-up obeys the §11 hard ordering edges.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/manifest_generation_doctrine.md`

### Objective

Adopt [`platform_services_doctrine.md` §1 — every cluster is the same cluster](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster)
with [§2 — HA always, including `replicas=1`](../documents/engineering/platform_services_doctrine.md#2-ha-always--including-replicas1),
[§8 — Postgres, Patroni-via-Percona, one cluster per consumer, with pgAdmin](../documents/engineering/platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin),
and the [§11 bring-up ordering edges](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering):
render and reconcile MinIO, Pulsar, Prometheus/Grafana, the Percona operator + per-service Patroni clusters
with pgAdmin, and MetalLB — all from baked-binary images, all HA-shaped.

### Deliverables

- MinIO (HA / distributed) as the S3 object substrate on retained PVs; a put/get round-trips.
- Pulsar (new vs prodbox — least evidence-backed) over its native TCP binary protocol, on retained
  bookie/broker storage; a produce/consume round-trips.
- Prometheus + Grafana, scraping platform workloads, reachable only through the (Sprint 2.6) edge.
- The Percona operator as a cluster-wide platform component, reconciling a per-consumer `PerconaPGCluster`
  (HA Patroni even at one replica) each paired with its own pgAdmin; `distribution` takes **no** database.
- MetalLB as the linux-cpu LoadBalancer, publishing an address before the Envoy/Gateway edge needs one.
- Every rendered container carrying explicit CPU/RAM requests+limits.

### Validation

1. Bring the stack up in dependency order; assert MetalLB → edge address, registry-before-pulls, Percona
   operator → Patroni cluster, Vault-unsealed → secret-dependent startup.
2. Round-trip MinIO put/get and Pulsar produce/consume.
3. Assert every platform pod declares CPU/RAM and Postgres is a Patroni cluster, never a bare Pod.

### Remaining Work

The whole sprint.

## Sprint 2.6: Keycloak-owned ingress + lossless-rebind gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Platform/Edge.hs`, `src/Amoebius/Platform/Keycloak.hs` (target paths; not yet built)
**Blocked by**: Sprint 2.4 (Keycloak's DB password and edge TLS material are Vault secrets), Sprint 2.5 (MetalLB address + the Keycloak Patroni DB), Sprint 2.3 (the rebind proof reuses retained storage)
**Independent Validation**: the only reachable wild path is LoadBalancer → Envoy/Gateway API → Keycloak; an unauthenticated request to any platform surface is rejected at the edge and no service exposes a backdoor NodePort to the wild; the marker-bytes round-trip survives a cluster delete + recreate.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`, `documents/engineering/storage_lifecycle_doctrine.md`

### Objective

Adopt [`platform_services_doctrine.md` §9 — the LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path):
make Keycloak the sole bouncer in front of all wild traffic via Envoy + the Gateway API, and close the
phase by proving the [`storage_lifecycle_doctrine.md` §6 lossless-teardown guarantee](../documents/engineering/storage_lifecycle_doctrine.md#6-the-lossless-teardown-guarantee-deterministic-rebind).

### Deliverables

- Envoy + Gateway API rendered as the L7 edge, terminating TLS and routing; Keycloak owning OIDC/JWT
  enforcement so no workload publishes its own ingress and no chart opens a wild NodePort.
- Public-edge TLS (ZeroSSL via DNS, route53) wired through the edge — provisioning owned by the Pulumi/IaC
  doctrine and referenced, not re-specified here; the EAB material is a Vault `SecretRef`.
- The east-west NetworkPolicy posture: default-deny with allow-edges derived from the declared dependency
  graph, rendered by the Sprint 2.2 reconciler.
- The phase-gate harness: write a marker row into the Keycloak Patroni DB and a marker object into a MinIO
  bucket, `cluster delete` (claims released, PVs Retained), `cluster recreate`, then read the same bytes
  back — proving deterministic rebind with no data loss.

### Validation

1. Assert an unauthenticated request to a platform surface is rejected at the edge and there is no
   non-Keycloak wild path (no exposed backdoor NodePort).
2. Run the marker-bytes write → delete → recreate → read cycle and assert the bytes are unchanged.
3. Assert the full standard service set is up, reachable, and HA-shaped, from generated manifests and
   baked-binary images, with no public-registry pull recorded during bring-up.

### Remaining Work

The whole sprint.

## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/platform_services_doctrine.md` — when this phase lands, its §13 planning-ownership
  pointer resolves to delivered Phase 2 sprints; the per-service "which standard services take a database"
  detail (§8) is filled in from Sprint 2.5.
- `documents/engineering/manifest_generation_doctrine.md` — the §5/§8 honesty notes flip from "design intent
  for Phase 2" to a delivered reconciler with the proven/tested ledger attached.
- `documents/engineering/image_build_doctrine.md` — the §2/§4 fail-closed-publication claims gain their first
  amoebius validation; the open §5 (versioning) / §6 (host vs in-pod builder) decisions are recorded as
  taken.
- `documents/engineering/storage_lifecycle_doctrine.md` — the §6 lossless-rebind guarantee gains its first
  amoebius proof on linux-cpu; the §5 host-side hard-cap enforcement mechanism is recorded as still design
  intent or as delivered.
- `documents/engineering/vault_pki_doctrine.md` — the §5 root-unseal and §8 PKI-anchor honesty notes are
  updated to reflect the delivered single-node root Vault.

**Cross-references to add:**
- [README.md](README.md) Phase index — flip the Phase 2 row from "not started" to its delivered status and
  link this document.
- [substrates.md](substrates.md) — record Phase 2's gate substrate (linux-cpu) in the per-phase substrate
  map.
- [system_components.md](system_components.md) — reconcile the `src/Amoebius/...` target module paths named
  in each sprint against the component inventory once they become concrete.

## Related Documents

- [README.md](README.md) — the live tracker and phase ordering this document sits under
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [overview.md](overview.md) — the target architecture and cross-cutting invariants
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — the standard service set adopted here
- [Manifest Generation & the Typed Reconciler](../documents/engineering/manifest_generation_doctrine.md) — the renderer + SSA engine adopted here
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md) — the baked-binary base container + `distribution` registry adopted here
- [Storage Lifecycle](../documents/engineering/storage_lifecycle_doctrine.md) — the no-provisioner retained-PV model adopted here
- [Vault, PKI & Secret Injection](../documents/engineering/vault_pki_doctrine.md) — the root Vault + PKI trust anchor adopted here
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — the bring-up/teardown the rebind gate exercises (cross-reference, not adopted in Phase 2)
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
