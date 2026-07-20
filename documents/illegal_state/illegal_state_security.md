# Illegal States — Security, Ingress & Secrets

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_21_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_23_app_tenancy.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_capacity.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_multicluster.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: The themed slice of the illegal-state catalog covering gateway/DNS/NetworkPolicy wiring,
> backdoor ingress, cross-tenant references and literal secrets, plaintext-at-rest, unsafe workloads, the
> secure-gateway reach, admin mutations, and derived RBAC bindings — the states amoebius makes unrepresentable
> so that ingress, secrets, and the admin surface cannot be misconfigured into a leak.

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog: the security, ingress, and secrets entries,
faithfully reproduced from [`illegal_state_catalog.md`](./illegal_state_catalog.md) and reorganized as their
own doc. It owns nothing new. The **catalog index** (which states are illegal, in full) and the **load-bearing
honesty limit** (a type-check proves the *spec composes*, not that the *running cluster enforces it*) are owned
by [`illegal_state_catalog.md`](./illegal_state_catalog.md). The **seven typing techniques** ([§4](./illegal_state_techniques.md#4-the-typing-techniques)), the
**coverage matrix** ([§5](./illegal_state_techniques.md#5-coverage-matrix--which-technique-forecloses-which-illegal-state)), the **three foreclosure layers** ([§6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)), and the **validation-locus axis** (the
orthogonal `Gate-1-editor` / `Gate-2-decoder` / `provision-seal` / `rendered-output-golden` / `live-effect`
classification each entry below carries) are owned by [`illegal_state_techniques.md`](./illegal_state_techniques.md). This slice
**references** those; it does not restate them.

Everything below is **design intent**, not a tested amoebius result. Per the honesty limit ([§6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)),
a green type-check is a **Decision-layer** proof that the specification composes into something internally
coherent — no illegal value is constructible — and it says nothing about whether the interpreter renders
correct manifests, whether the apiserver admits them, or whether the running cluster enforces them. Read every
"unrepresentable" below as *design intent for the type discipline*, never as a proven runtime behaviour.

---

## 2. The security, ingress & secrets illegal states

Each entry keeps its **original catalog number and heading** (inbound links depend on the slug). The
**Validation-locus** line added to each entry places it on the orthogonal validation-locus axis defined in
[`illegal_state_techniques.md`](./illegal_state_techniques.md): `Gate-1-editor` (fails `dhall type` at
authoring time), `Gate-2-decoder` (the total decoder returns `Left`), `provision-seal` (post-bind Phase-8
provision returns a `ProvisionError` before any `ProvisionedSpec` exists), `rendered-output-golden` (caught by
a golden test on the *rendered* manifest, not a live cluster), and `live-effect` (only observable at
reconcile/runtime — the runtime-checked residue).

### 3.3 Misconfigured gateway

A hand-written Gateway/HTTPRoute can listen on a port nothing serves, terminate TLS with a cert for the
wrong host, or route to a backend that doesn't exist. In amoebius the gateway is not free-form: routes are
emitted from the same value that declares the service, so a route to a non-existent backend, or a listener
with no matching service, cannot be written. **Owner:**
[`platform_services_doctrine.md` §9](../engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path) (Envoy + Gateway API, the single
wild-ingress path). **Technique:** [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (GADT-indexed: a route is constructed *from* a live service handle)
+ [§4.5](./illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content) totality (the cert/host name is a function of the declared identity, not a free string).

**Validation-locus:** `Gate-2-decoder` (a route is constructed only *from* a live service handle, and the
cert/host name is a total function of the declared identity — a route to a non-existent backend or a listener
with no matching service has no inhabitant) + `rendered-output-golden` (the emitted Gateway/HTTPRoute
listeners and backends match the declaring service) + `live-effect` residue (that the LoadBalancer comes up
and TLS actually terminates).

### 3.4 DNS that binds to the wrong IP

Route53 (or any DNS) records are strings; nothing prevents pointing `app.example.com` at an address the
cluster never owned. amoebius never lets the operator *type* the target IP: a DNS binding is a **total
function of the allocated LoadBalancer address** — a name binds to a *service handle*, and the address is
computed from the realized LB, not supplied. A record pointing at an unowned address therefore has no
representation. **Owner:** [`pulumi_iac_doctrine.md`](../engineering/pulumi_iac_doctrine.md) (route53 + zerossl) and
[`platform_services_doctrine.md` §9](../engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path). **Technique:** [§4.5](./illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content) (content-address
totality, applied to the name→address map).

**Validation-locus:** `Gate-2-decoder` (the DNS binding is a total function of a service handle — there is no
free string in which to type an unowned target IP) + `rendered-output-golden` (the emitted DNS record targets
the allocated LB address) + `live-effect` residue (the realized LoadBalancer address is what is actually bound
at reconcile — the enforcement half the type cannot reach).

### 3.6 Blocking NetworkPolicy (services can't reach each other)

NetworkPolicies are deny-by-omission: a forgotten egress rule silently severs a service from
its database, with no error anywhere. amoebius does not let operators hand-author allow/deny rules at all.
Connectivity is **derived** from the declared dependency graph — if service A declares it consumes service
B, the policy permitting A→B is generated, and a declared dependency can never be a connection the
policy blocks. The "service stranded from a dependency it declared" state is not expressible because the
human never writes the policy. **Owner:**
[`platform_services_doctrine.md`](../engineering/platform_services_doctrine.md). **Technique:** [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally) (the dependency
graph is the single owner of connectivity) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (a consumer handle only exists once the dependency edge
does).

**Validation-locus:** `rendered-output-golden` (the derived NetworkPolicy is checked in the emitted objects —
a declared dependency is never a connection the policy blocks) + `Gate-2-decoder` (the consumer handle exists
only once the dependency edge does; the ownership fold over the dependency graph) + `live-effect` residue
(that the CNI actually admits the derived flow).

### 3.7 Accidental insecure / backdoor ingress

The highest-severity entry: a chart that opens its own NodePort to the wild, or an Ingress that skips Keycloak, so
an unauthenticated path exists that nobody meant to ship. amoebius enforces **Keycloak owns all wild
ingress** structurally: an app cannot publish its own wild ingress, because the
only constructor that yields a wild-reachable endpoint routes through the Keycloak-owned edge. The sole
carve-out — host-origin, localhost-only NodePorts with no mTLS — is a *different type* of endpoint
(`HostLocalPeer`, not `WildIngress`), reachable only from the host and never from WAN/LAN, owned by
[`host_cluster_comms_doctrine.md`](../engineering/host_cluster_comms_doctrine.md). There is no constructor that turns a
host-local peer into a wild endpoint, and none that exposes a workload to the wild without the edge.
**Owner:** [`platform_services_doctrine.md` §9](../engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(capability: only the edge holds the "expose-to-wild" capability) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (endpoint kinds are distinct
indices that do not interconvert).

**Validation-locus:** `rendered-output-golden` (the no-backdoor-ingress golden on the emitted objects — no
wild NodePort or Keycloak-skipping Ingress in the rendered manifest) + `Gate-2-decoder` (only the edge holds
the expose-to-wild capability, and endpoint kinds are distinct non-interconverting indices — a self-published
wild endpoint has no constructor) + `live-effect` residue (that the running cluster in fact exposes no
unauthenticated path).

### 3.8 Cross-tenant references and literal secrets

Two locked invariants ride together here. **(a) Secrets are names only** — a literal secret value in Dhall
is unrepresentable; the spec carries a `SecretRef` (a name), and the parent injects the actual material
into the child's Vault. **(b) Tenant isolation** — a child cluster knows
*nothing* about its siblings, so a spec for child *X* must not be able to name
child *Y*'s resources or secrets. Both are foreclosed the same way: references are **tenant-tagged**, and
there is no function that re-tags a reference from one tenant to another ([§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)). A `SecretRef` is a name
under *this* tenant's tag; a cross-tenant reference has no inhabitant. **Owner:**
[`vault_pki_doctrine.md`](../engineering/vault_pki_doctrine.md) (the `SecretRef`-by-name contract, parent→child
injection, the trust tree). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (phantom tenant tags + capabilities).

**Validation-locus:** `Gate-2-decoder` (phantom tenant tags — a literal secret value and a cross-tenant
reference have no inhabitant; a `SecretRef` is only ever a name under *this* tenant's tag, and no function
re-tags across tenants) + `live-effect` residue (that the parent actually injects the referenced material into
the child's Vault at runtime).

### 3.9 A plaintext spec at rest

The `InForceSpec` is sensitive even when it holds no secret *values* — it is the cluster's whole topology.
So the spec has **no plaintext-at-rest representation**: a cluster never holds its own spec as a plaintext
value, only the means to fetch and decrypt it; at runtime the control-plane singleton decrypts the
Vault-Transit MinIO envelope **in-process** and never writes it to a plaintext ConfigMap or to etcd. A spec
materialized to a cluster-legible store is therefore not something a workload's typed inputs can even name
(a workload reads only the unencrypted-basics floor plus the Vault objects its policy allows). **Owner:**
[`vault_pki_doctrine.md` §4](../engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init) (decrypt-in-process, never-plaintext) and
[`pulumi_iac_doctrine.md` §2](../engineering/pulumi_iac_doctrine.md#2-the-backend-every-byte-of-state-is-a-vault-enveloped-object-in-minio) (the enveloped backend). **Technique:** [§4.5](./illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content)
(an envelope/handle, not a plaintext value) — note this row's *enforcement* is partly runtime (per the [§2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)
limit); the type only removes any plaintext-spec input.

**Validation-locus:** `Gate-2-decoder` (a workload's typed inputs can only name an envelope/handle, never a
plaintext-spec value — the plaintext-at-rest input has no inhabitant) + `live-effect` residue (that the
control-plane singleton decrypts the Vault-Transit MinIO envelope in-process and never writes plaintext to a
ConfigMap or etcd — this row's enforcement is explicitly the runtime half).

### 3.10 A child spec that reaches beyond its own subtree

A child cluster's spec is, by construction, a projection of **exactly its own subtree** (its own config
including its children's). There is no field in a `ChildInForceSpec` in which a sibling or ancestor-only branch can
appear, so a parent cannot hand a child anything wider than its subtree, and a child cannot name a sibling's
resources — the [§3.8](#38-cross-tenant-references-and-literal-secrets) tenant-isolation invariant lifted to the whole spec tree, reinforced cryptographically
by per-child Transit keys (a child cannot even *decrypt* a sibling's subtree). **Owner:**
[`cluster_lifecycle_doctrine.md` §3](../engineering/cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest) (the `project(subtree)` handoff),
[`dsl_doctrine.md`](../engineering/dsl_doctrine.md) (the `ChildInForceSpec` type), and
[`vault_pki_doctrine.md` §6](../engineering/vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes) (per-child keys). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (phantom
tenant/subtree tags) + [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally) (ownership indices).

**Validation-locus:** `Gate-2-decoder` (phantom subtree tags + ownership indices — a `ChildInForceSpec` has no
field in which a sibling or ancestor-only branch can appear) + `live-effect` residue (per-child Transit keys —
a child cannot even *decrypt* a sibling's subtree at runtime, the cryptographic reinforcement beyond the type
shape).

### 3.11 An unsafe workload (no resource limits, no hardened securityContext)

In raw k8s a Deployment may omit resource requests/limits — a noisy-neighbour or OOM-the-node risk — and run
as root with a writable root filesystem and full Linux capabilities. amoebius **generates** every workload
object from a typed record that *requires* a complete resource envelope: refined non-zero CPU, memory, and
pod `ephemeral-storage` requests+limits for every app/sidecar/init container; a size bound for every
disk-backed scratch/cache volume; per-container private writable/log allowances covered by that container's
ephemeral request/limit and, with shared volume bounds, by the effective pod request; writer-indexed
memory-backed volumes with access/persistence and exactly one reservation carrier per resident lifecycle epoch;
platform-specific OCI content/snapshot/import metadata routed by the node's closed filesystem layout and
finite pull policy; checked durable claim presentation/usable/raw sizes; and, for the
accelerator-owner pod, a derived integer
extended-resource request/limit on its named owner container plus the pod's required affinity. It also
attaches a hardened (non-root,
no-privilege-escalation, dropped-capabilities, read-only-root-by-default) `securityContext`. Binding and
provisioning must first construct the opaque whole-deployment `ProvisionedSpec`; only deployment-global
`renderAll :: ProvisionedSpec -> [K8sObject]` crosses the seal, so neither an incomplete resource projection nor an
unprovisionable target/workload pair can reach manifest generation. There is nothing to lint because there
was never a renderable value to lint. The
complete-resource-envelope rule is owned by
[`platform_services_doctrine.md` §10](../engineering/platform_services_doctrine.md#10-every-execution-unit-declares-its-complete-resource-envelope);
the generation discipline that makes the unsafe shape unconstructible is owned by
[`manifest_generation_doctrine.md` §3](../engineering/manifest_generation_doctrine.md#3-best-practice-by-construction-an-unsafe-manifest-is-not-constructible). **Owner:**
[`manifest_generation_doctrine.md`](../engineering/manifest_generation_doctrine.md) (best-practice-by-construction) +
[`platform_services_doctrine.md`](../engineering/platform_services_doctrine.md) (the complete resource-envelope
rule) + [`resource_capacity_doctrine.md`](../engineering/resource_capacity_doctrine.md) (the private checked
provision boundary). **Technique:** [§4.1](./illegal_state_techniques.md#41-pvcpv-binding-by-construction)
(required-field-by-construction — a record without the field has no inhabitant).

**Validation-locus:** `Gate-1-editor` (a workload record missing its mandatory resource envelope fails
`dhall type` at authoring) + `provision-seal` (the post-bind resource/capability fold must construct the opaque
whole-deployment `ProvisionedSpec`, returning a `ProvisionError` before that seal when the selected target
cannot supply any demand) +
`rendered-output-golden` (the hardened non-root / no-privilege-escalation / dropped-capabilities /
read-only-root `securityContext` and the exact checked resource projection are present in the emitted
manifest) + `live-effect` residue (the running pod actually enforces the hardened context and resource
ceilings).

### 3.40 A secure-gateway reach collapsing into wild ingress

The new `Gateway` networking arm (`SecureGatewayReach c`, the authenticated secure-gateway wire a non-member host
worker uses to reach the data plane + Vault) must not become a back-door into the wild — "Keycloak owns all wild
ingress" ([§3.7](#37-accidental-insecure--backdoor-ingress)) must survive it. `SecureGatewayReach` is a **distinct
`network_fabric` endpoint index** alongside `FabricPeer`/`ControlPlanePeer`/`HostLocalPeer`/`WildIngress`, with
**no constructor into `WildIngress`**, so a gateway reach cannot collapse into a wild endpoint — the same
endpoint-kinds-do-not-interconvert shape as the host-local-peer carve-out ([§3.7](#37-accidental-insecure--backdoor-ingress)).
The wild-ingress gateway (Keycloak/Envoy) stays wild-only. **Owner:**
[`network_fabric_doctrine.md`](../engineering/network_fabric_doctrine.md) (the endpoint indices) +
[`host_cluster_comms_doctrine.md`](../engineering/host_cluster_comms_doctrine.md) (channel 2 generalized to localhost /
authenticated fabric / authenticated secure gateway). **Technique:**
[§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (only the wild edge holds the
`ExposeToWild` capability — a `SecureGatewayReach` value cannot produce a wild endpoint) +
[§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (endpoint kinds are distinct indices
that do not interconvert). **Layer:** type-foreclosed uninhabitable. *(The K1 `Gateway`-arm authentication constructor itself
is design intent this round names but defers — the witness type `FabricMember c` via `fabricMemberViaGateway` is
named, the constructor not yet inhabited.)*

**Validation-locus:** `Gate-2-decoder` (only the wild edge holds the `ExposeToWild` capability, and
`SecureGatewayReach` is a distinct endpoint index with no constructor into `WildIngress` — the collapse has no
inhabitant) + `rendered-output-golden` (the emitted objects carry no wild endpoint derived from the gateway
reach) + `live-effect` residue (that the authenticated secure-gateway wire actually stays non-wild at
runtime).

### 3.42 An admin mutation without a root-token capability + an unsealed-Vault witness

Raw k8s hands anyone with a kubeconfig a mutating control surface — a new manifest, a config change — with no
proof of authority beyond the cert, and no ordering against secret readiness. amoebius routes **all
post-bootstrap admin through the singleton's REST API** (the singleton being a Deployment `replicas=1` with no
leader election) ([`bootstrap_sequence_doctrine.md` §5](../engineering/bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api)),
and the mutating endpoint (`dhall update`) is constructed **only** from a `RootToken` capability **and** an
`Unsealed`-Vault witness — so "push a new spec to an unsealed-less or unauthenticated cluster" has no
constructor, the same capability + edge-gated-handle discipline as the `PromotionGate`
([§3.26](./illegal_state_lifecycle.md#326-an-unverified-environment-promotion-promote--prod-without-the-required-evidence)) and the
`Readiness` edge ([§3.41](./illegal_state_lifecycle.md#341-a-duration-gated--hand-ordered-bring-up-sequence-a-readiness-race)). Its sibling
— an admin action **bypassing** the singleton — is foreclosed too: channel 1 (host binary ↔ kube-apiserver) is
a **bootstrap-only** privilege with no exported control verb after the host-daemon→singleton handoff, so the
only control-surface constructor is an admin-REST call — and retiring channel 1 does **not** make that surface
*remotely* reachable: the admin-REST call still traverses the singleton's **node-local/private admin channel**
([`bootstrap_sequence_doctrine.md` §5](../engineering/bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api) admin-plane reach class), never the wild edge. **Owner:**
[`bootstrap_sequence_doctrine.md`](../engineering/bootstrap_sequence_doctrine.md) (the admin control plane) +
[`vault_pki_doctrine.md` §4](../engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init) (the
unsealed-Vault precondition). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(the `RootToken` capability — an admin verb has no inhabitant without it) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
(a `dhall update` handle exists only once its `Unsealed`-Vault edge does; channel-1 verbs do not survive the
handoff transition). **Layer:** `type-foreclosed` for the cap-and-witness-gated mutation and the retired
channel-1 verb; `runtime-checked` residue — that the singleton (a Deployment `replicas=1`, no election) actually holds *sole* authority
(no split-brain admin), owned by [`daemon_topology_doctrine.md` §5](../engineering/daemon_topology_doctrine.md#5-single-instance-and-coordination--delegated-not-elected)
and [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md).

**Validation-locus:** `Gate-2-decoder` (the `RootToken` capability plus the `Unsealed`-Vault edge-gated `dhall
update` handle — an unauthenticated or unsealed-less mutation has no inhabitant, and channel-1 control verbs do
not survive the host-daemon→singleton handoff) + `live-effect` residue (that the singleton — a Deployment
`replicas=1` with no election — actually holds *sole* admin authority, no split-brain).

### 3.45 A cross-tenant or hand-authored RBAC binding

Raw k8s (and Keycloak, Vault, Pulsar, and MinIO alongside it) lets an operator hand-write a `RoleBinding`,
a realm-role grant, a Vault policy, a Pulsar ACL, or a bucket policy that grants one tenant reach into
another's resources — or simply mis-scopes a grant — with nothing to catch it but review. amoebius has **no
DSL surface with which to author a grant at all**: every concrete provider policy is the image of one **total
function of the typed tenant→role graph**
(`deriveTenantPolicies :: TenantSpec -> TenantPolicyDerivation`). This is an intermediate, never a renderer:
it carries exact policy outputs plus the source-linked Keycloak SQL/WAL, Vault Raft, Pulsar ZooKeeper, MinIO
system-metadata, and Kubernetes API/etcd persistence operands, along with exact provider action/executor
identities and bounded execution cost, through whole-deployment provision. The pure executor attachment is only
`Dedicated | SharedControlPlaneRole`, never a concrete target. One plural binder resolves and coalesces every
tenant's actions/deltas by target, debits a shared base once, and seals only private provisioned execution
references/capacity witnesses. MinIO policy metadata is globally grouped and may resolve only to a retained
MinIO backing; static reserve is once per store. Desired and observed outputs carry normalized content digests,
so same-size/different-content is `Replace`, never `NoOp`. Observed old state remains charged with rollback/
executor overlap until verified cleanup. A
hand-authored, un-derived binding is not a value that function can return, and
a *cross-tenant* binding has no inhabitant for the same reason [§3.8](#38-cross-tenant-references-and-literal-secrets)'s
cross-tenant reference does — references are tenant-tagged and no function re-tags a grant from one tenant to
another. This is the RBAC lift of the derived-not-authored discipline that [§3.22](./illegal_state_capacity.md#322-a-hand-authored-un-derived-toleration)
applies to tolerations and [§3.6](#36-blocking-networkpolicy-services-cant-reach-each-other) applies to
connectivity: the human never writes the policy, so the mis-scoped policy is unrepresentable. **Owner:**
[`tenancy_doctrine.md` §5](../engineering/tenancy_doctrine.md#5-rbac-is-derived-never-authored) (RBAC is derived, never
authored) + [`vault_pki_doctrine.md`](../engineering/vault_pki_doctrine.md) (the per-tenant policy envelope). **Technique:**
[§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (phantom tenant tags — a
grant is tagged under *this* tenant and no function re-tags it) + [§4.4](./illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally)
(the typed tenant→role graph is the single owner of every derived grant). **Layer:** `type-foreclosed`
uninhabitable for the hand-authored and cross-tenant binding (no constructor); `runtime-checked` residue — that
the derived Keycloak/Vault/Pulsar/MinIO policies *actually* refuse a live cross-tenant access. Source/key-set
equality also makes an output/action whose persistence demand was dropped `decode-foreclosed` at whole
provision ([resource_capacity_doctrine.md §5.1](../engineering/resource_capacity_doctrine.md#51-durable-demand-is-logical-first-physical-only-after-geometry)); only private `ProvisionedSpec` projections
paired with the exact observation-bound `ValidatedLiveTarget` may render or act.

**Validation-locus:** `Gate-2-decoder` (every provider policy is the image of one total derivation of the typed
tenant→role graph, and grants are phantom-tenant-tagged — a hand-authored, un-derived, or cross-tenant binding
has no inhabitant) + `provision-seal` (whole-deployment source equality requires exact policy outputs and their four-store plus
API/etcd demands and executor actions share a source and exact nested identities; independent wrong-digest,
equal-cardinality key-swap, extra-entry, nested-id mismatch, omitted action/executor/old-state, one-short,
drop-demand-while-action-remains, duplicate-target (`DuplicateTenantPolicyExecutionTarget`), uncoalesced-delta
(`UncoalescedTenantPolicyExecutionDelta`), double-base (`TenantPolicyBaseExecutionDoubleDebit`), split-MinIO-
group (`TenantPolicyMinioGroupMismatch`), provider-quota supply
(`UnsupportedTenantPolicyProviderObjectQuota`), MinIO static/dynamic drop/double-add
(`MinioMetadataComponentMismatch`), and same-size/different-content (`PolicyContentDigestMismatch`) mutants
reject before effects) +
`rendered-output-golden` (only private provisioned projections emit a policy set matching the tenant→role
graph, with no grant crossing a tenant tag) + `live-effect` residue (provider-state/action readback matches
normalized content digests, one coalesced target/base witness, store-global MinIO components, and the sealed
transition high-water; the policies refuse a live cross-tenant read).

---

## Cross-references

- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the authoritative catalog: the full index of
  illegal states and the load-bearing honesty limit ([§2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)). This slice is carved from it.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — owns the seven typing techniques ([§4](./illegal_state_techniques.md#4-the-typing-techniques)), the
  coverage matrix ([§5](./illegal_state_techniques.md#5-coverage-matrix--which-technique-forecloses-which-illegal-state)), the foreclosure layers, and the **validation-locus axis** each entry above is
  classified against.
- [`dsl_doctrine.md`](../engineering/dsl_doctrine.md) — the DSL surface and the contract ("a valid `InForceSpec` cannot
  represent illegal state") these entries instantiate.
- Owning doctrines cited by the entries in this slice:
  - [`platform_services_doctrine.md`](../engineering/platform_services_doctrine.md) — the LoadBalancer + single wild-ingress
    path, derived NetworkPolicy, and the complete resource-envelope rule (§3.3, §3.4, §3.6, §3.7, §3.11).
  - [`pulumi_iac_doctrine.md`](../engineering/pulumi_iac_doctrine.md) — route53 + zerossl, and the Vault-enveloped backend
    (§3.4, §3.9).
  - [`host_cluster_comms_doctrine.md`](../engineering/host_cluster_comms_doctrine.md) — the host-local-peer carve-out and
    the channel taxonomy (§3.7, §3.40).
  - [`vault_pki_doctrine.md`](../engineering/vault_pki_doctrine.md) — the `SecretRef`-by-name contract, parent→child
    injection, per-child keys, the fail-closed unsealed-Vault precondition, and the per-tenant policy envelope
    (§3.8, §3.9, §3.10, §3.42, §3.45).
  - [`tenancy_doctrine.md`](../engineering/tenancy_doctrine.md) — RBAC is derived, never authored; the typed tenant→role
    graph as the single owner of every derived grant (§3.45).
  - [`cluster_lifecycle_doctrine.md`](../engineering/cluster_lifecycle_doctrine.md) — the `project(subtree)` handoff
    (§3.10).
  - [`manifest_generation_doctrine.md`](../engineering/manifest_generation_doctrine.md) — best-practice-by-construction, the
    unconstructible unsafe manifest (§3.11).
  - [`network_fabric_doctrine.md`](../engineering/network_fabric_doctrine.md) — the endpoint indices, including
    `SecureGatewayReach` (§3.40).
  - [`bootstrap_sequence_doctrine.md`](../engineering/bootstrap_sequence_doctrine.md) — the admin control plane and the
    singleton REST API (§3.42).
  - [`daemon_topology_doctrine.md`](../engineering/daemon_topology_doctrine.md) and
    [`chaos_failover_doctrine.md`](../engineering/chaos_failover_doctrine.md) — the runtime-checked residue that the
    singleton holds sole admin authority (§3.42).
