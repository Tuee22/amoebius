# Amoebius Engineering Doctrine

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: README.md, DEVELOPMENT_PLAN/README.md, documents/documentation_standards.md, documents/engineering/apple_metal_headless_builds.md
**Generated sections**: none

> **Purpose**: Index of amoebius engineering and architecture doctrine. This enumerates the complete
> Phase 0 documentation suite — the whole DSL, specified before implementation.

Phase order, status, and validation gates live only in
[`DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md). The documents below are stable doctrine;
when the plan changes the supported design, the affected doctrine is updated in the same change.

All docs follow [documentation_standards.md](../documentation_standards.md). Status legend below: ✅ = the
authoring of this doc is itself complete; 📝 = a Phase 0 deliverable still to be authored.

## The DSL (the core)

| Document | Purpose | |
|----------|---------|--|
| [dsl_doctrine.md](./dsl_doctrine.md) | The amoebius Dhall DSL: the orchestration surface, total composability, secrets-by-name, and the illegal-state-unrepresentable contract (PVC↔PV, gateway, DNS, certs, taints/tolerations/affinity, NetworkPolicy, ingress, resource capacity, compute-engine/topology, bounded storage) | ✅ |
| [app_vs_deployment_doctrine.md](./app_vs_deployment_doctrine.md) | The hard split between **application logic** (UI, user lifecycles, durable storage, shared-library use) and **deployment rules** (HA replicas, chaos testing, geo-replication, failover) — write the app once, configure its distribution separately | ✅ |
| [illegal_state_catalog.md](./illegal_state_catalog.md) | The catalog of illegal states ([§3.1](./illegal_state_catalog.md#31-bad--illegal-durable-storage)–[§3.22](./illegal_state_catalog.md#322-a-hand-authored-un-derived-toleration)) and the typing techniques that make each unrepresentable (capability/phantom tenant tags, GADT-indexed state machines, ownership indices, content-address totality, the capacity-accounting total fold, topology relations over a collection) | ✅ |
| [service_capability_doctrine.md](./service_capability_doctrine.md) | Services as abstract **capabilities** (ObjectStore · SecretStore · MessageBus · Sql · Identity · Observability · Registry · Edge), one canonical provider each (type admits alternates), bound to a per-cluster deployment **shape** — app-logic names capabilities, never products | ✅ |

## Platform & cluster

| Document | Purpose | |
|----------|---------|--|
| [platform_services_doctrine.md](./platform_services_doctrine.md) | The standard services every cluster runs (Registry/`distribution` · MinIO · Vault · Pulsar · Prometheus/Grafana · Percona/Patroni Postgres · Envoy/Gateway-API · Keycloak · LB) — the concrete providers behind the capabilities; HA-always, Keycloak-owns-all-ingress | ✅ |
| [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) | `no-provisioner` retained PVs (`<ns>/<sts>/pv_<n>`, sized, host/EBS-bound), ephemeral-cluster/durable-storage, deterministic rebind, shrink-without-data-destruction | ✅ |
| [cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md) | kind/rke2/provider clusters; bootstrap; **amoebic spawning** (parent/child); teardown-with-cleanup vs chaos-failover; push-back on unsatisfiable `.dhall`; dynamic node provisioning | ✅ |
| [single_logical_data_plane_doctrine.md](./single_logical_data_plane_doctrine.md) | One data plane reached from many compute locations vs many data planes reached by gateway migration — remote elastic compute (spot ML) as **Pulsar/MinIO clients of the home cluster's one store over the fabric, not a second cluster**; the `DataPlane`/`FabricMember` binding that makes an unreachable store uninhabitable | ✅ |
| [cluster_topology_doctrine.md](./cluster_topology_doctrine.md) | The **declared** compute-engine axis: `ComputeEngine` (Kind/Rke2/**Managed EKS**), the substrate-indexed `LinuxHost` witness (apple/windows only via Lima/WSL2), the `Topology` fold (one host for kind, one Linux host per rke2 node), and the engine↔substrate compatibility relation (multi-substrate clusters legal) — [§3.13](./illegal_state_catalog.md#313-a-compute-engine-incompatible-with-its-substrates-managed-providers-first-class)–[§3.16](./illegal_state_catalog.md#316-a-multi-node-rke2-cluster-with-fewer-linux-hosts-than-nodes-or-a-host-reused) / [§4.7](./illegal_state_catalog.md#47-compatibility--topology-relations-by-construction-over-a-collection) | ✅ |
| [resource_capacity_doctrine.md](./resource_capacity_doctrine.md) | The capacity model: `Capacity`/`Demand`/`Budget`, the [§4.6](./illegal_state_catalog.md#46-capacity-accounting-total-fold--σ-demand--capacity-checked) total fold (Σ demand ≤ capacity; host→VM→workload), the closed `StorageBudget` (no unbounded arm), the two-ceiling Pulsar fold, and the `Growable`/`ScalingPolicy` escape valve — [§3.17](./illegal_state_catalog.md#317-an-over-committed-deploy-or-workload-host--vm--cluster-capacity-exceeded)–[§3.21](./illegal_state_catalog.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy), all honestly grade-(2) | ✅ |
| [substrate_doctrine.md](./substrate_doctrine.md) | Substrates (apple / linux-cpu / linux-cuda / windows), virtualized substrates (Lima/WSL2), host worker nodes for substrate-specific hardware, the no-env/no-PATH lazy-tool-ensure contract, and `bootstrap.sh` | ✅ |
| [apple_metal_headless_builds.md](./apple_metal_headless_builds.md) | The Apple-Metal host worker's headless, on-host build/run shape: a fixed `/usr/bin/clang`-built Metal bridge + runtime MSL compilation via `MTLDevice.makeLibrary(source:options:)` — the hard **no-Tart / no-VM / no-keychain / no-full-Xcode / no-per-kernel-Swift-build** commitment and its rationale | ✅ |
| [image_build_doctrine.md](./image_build_doctrine.md) | Baked multi-arch service binaries (apt→binary→source) + the `distribution` registry (replaces Harbor); buildx amd64/arm64 amoebius images; versioning vs `:latest`; host vs in-pod builds | ✅ |
| [manifest_generation_doctrine.md](./manifest_generation_doctrine.md) | Generating the full k8s object set (Deployment/StatefulSet/Service/Secret/RBAC/NetworkPolicy/CRD/CR) from pure typed Haskell — **no Helm, no third-party charts** — + the idempotent typed reconciler (server-side apply, ApplySet prune, wait, rollback) and its desired=spec / observed=etcd state model | ✅ |

## Secrets, identity, IaC

| Document | Purpose | |
|----------|---------|--|
| [vault_pki_doctrine.md](./vault_pki_doctrine.md) | Vault as the fail-closed secrets root; root password-encrypted unseal; parent/child unseal + secret injection; the root PKI trust anchor; the SecretRef-by-name contract | ✅ |
| [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md) | Pulumi deploys only from within an amoebius cluster (MinIO backend + Vault-envelope encryption); DNS (route53) + TLS (zerossl); provider clusters; the EBS create-vs-delete credential model | ✅ |

## Runtime, transport, determinism

| Document | Purpose | |
|----------|---------|--|
| [daemon_topology_doctrine.md](./daemon_topology_doctrine.md) | The one binary's contexts (CLI / sudo host-daemon / in-cluster singleton); the **control-plane singleton** (elected, total cluster + secret authority); worker roles (web hosts, Pulsar topic-lifecycle coordinators, ML batch, inference); leadership election | ✅ |
| [host_cluster_comms_doctrine.md](./host_cluster_comms_doctrine.md) | Host↔cluster communication: a host compute daemon is a **Pulsar + MinIO peer over host-only NodePorts (no mTLS)**; host binary ↔ kubeapi via distro mTLS; the host-only network restriction ([§5.1](./host_cluster_comms_doctrine.md#51-the-generalization-localhost-or-the-authenticated-wireguard-fabric) generalizes it to the authenticated WireGuard fabric) | ✅ |
| [network_fabric_doctrine.md](./network_fabric_doctrine.md) | The inter-node/inter-cluster fabric: **raw kernel WireGuard configured by amoebius (not Netmaker)**, Vault-KV peer keys, rendered peer config, hub = gateway role; the localhost→authenticated-fabric generalization; and the **no-Linkerd-for-v1** service-mesh verdict | ✅ |
| [pulsar_client_doctrine.md](./pulsar_client_doctrine.md) | The native-protocol Haskell Pulsar client (`amoebius-pulsar`, forked from supernova): TCP binary protocol, **no WebSockets**, the declarative topology algebra, at-least-once + dedup | ✅ |
| [content_addressing_doctrine.md](./content_addressing_doctrine.md) | The content-addressed MinIO store (pointers→manifests→blobs), `experimentHash = sha256(dhall‖substrate)` identity, and seed-derivation determinism — applied to **both** infernix and jitML | ✅ |
| [release_lifecycle_doctrine.md](./release_lifecycle_doctrine.md) | Delivery as typed composition on primitives amoebius already owns — **no external CI/CD control plane** (no Argo/Flux/Tekton): the immutable `Release` ledger (`releaseHash`), the per-`Environment` (Dev/Staging/Prod) ETag-CAS promotion pointer, the `PromotionGate` that makes promote-unverified→prod unrepresentable, and the readiness-gated `RolloutPlan`/`RolloutPhase` apply (schema-migration as a phase, canary, rollback) on the in-cluster SSA reconciler | ✅ |

## Verification

| Document | Purpose | |
|----------|---------|--|
| [chaos_failover_doctrine.md](./chaos_failover_doctrine.md) | The Extract→Model→Inject methodology + the proven/tested/assumed ledger; the invariant-confluence "Second Axis" that governs **async cross-cluster geo-replication & failover** — the one place a per-system proof obligation concentrates (intra-cluster consensus is delegated to MinIO/Pulsar/Postgres/Patroni). Generalized from prodbox's `chaos_hardening_doctrine.md` | ✅ |
| [testing_doctrine.md](./testing_doctrine.md) | Testing as an `.dhall` topology (spin up → run → always tear down); `suggest-test`; flagged test credentials; storage deletion only by the elevated harness; the per-run ledger artifact; leak-free cycles | ✅ |
| [tla_modelling_assumptions.md](./tla_modelling_assumptions.md) | (Scheduled, Phase 9) The formal-model assumptions, correspondence, and divergences for the cross-cluster failover spec | ✅ |

## Cross-references
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
