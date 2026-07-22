# Phase 27: App tenancy + `TenantSpec`

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_26_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_28_pulsar_client.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Realize an app's tenant slice live — its own namespace, the `<app>/<bucket>` ObjectStore prefix,
> and a one-member in-namespace `Sql` database — behind the `TenantSpec`/`UserSpec`/`RoleBinding` typed surface
> whose absent arms make a spec that names a foreign tenant's resource unrepresentable.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 26 gate (the live DSL deploy
via the Deployment-`replicas=1` control-plane singleton, no election) and runs on the **linux-cpu** substrate in
**Register 3** — live infrastructure: the single-node `kind` cluster assembled through Phases 17–26, including
root Vault in Phase 22, the platform stack in Phases 23–24, and the Keycloak-owned edge in Phase 25. The
tenant-axis type discipline it rests on — the phantom
`Ref t` tag and the absent `Ref t1 a → Ref t2 a` coercion — was **authored and proven in-process in the
pre-cluster band** (the Phase-6 illegal-state corpus, a Register-1 amoebius result); Dhall has no dependent
types, so the multi-tenant realm/policy shape specified here is a design intent, not yet a tested amoebius
result.

## Phase Summary

This phase makes the **tenant axis run live**. It takes an app spec nested in the cluster spec and projects the
app's tenant slice onto real providers: a per-app Kubernetes **namespace**, the declared `ObjectStore` buckets
rendered as the canonical MinIO **`<app>/<bucket>` prefix**, and a one-member in-namespace **Patroni `Sql`**
database — never a bare `postgres` Pod — all reconciled to ready by the Deployment-`replicas=1` control-plane
singleton (single-instance delegated to k8s/etcd, no bespoke election). It stands up the
`TenantSpec (t : TenantId)` / `UserSpec (t : TenantId)` / `RoleBinding (t : TenantId)` typed surface whose
isolation is its **absent arms**: inside a `RoleBinding t` the only resource-reference constructors in scope
produce `Ref t _`, so a binding that names another tenant's bucket, topic, or secret has no inhabitant, and the
projection `project : RootInForceSpec → TenantId → TenantSpec t` yields only tenant `t`'s subtree. Provider RBAC
is **derived** from the tenant→role graph by the single total
`deriveTenantPolicies :: TenantSpec -> TenantPolicyDerivation`; that intermediate contains the exact
per-tenant Keycloak, Vault, Pulsar, MinIO, Kubernetes-API/NetworkPolicy, and Postgres policy outputs together
with their durable-store/API demand — never passed raw to `renderAll` and never hand-authored. Secrets stay
names throughout:
`credential` and `transitKey` are `SecretRef`s resolved in-cluster via the Phase-22 built-in Vault client.

What this phase deliberately does **not** do: the tenant-admin scope-narrowed `dhall update` surface and its
Keycloak-fronted browser client ([`tenancy_doctrine.md §6`](../documents/engineering/tenancy_doctrine.md#6-the-tenant-admin-surface-reduces-to-a-scope-narrowed-admin-mutation)), the
promotion of a hostile or regulated tenant onto its **own child cluster** (the cryptographic-isolation hardening
dial, owned by the amoebic-spawning/federation phases), and any claim that `deriveTenantPolicies` is faithful
(that residue is runtime-checked, per the honest limit) are all out of scope here. Only the single root
cluster's app-tenant projection and its author-time no-foreign-tenant foreclosure are gated in this phase.

**Substrate:** linux-cpu — the whole gate runs on the single-node `kind` cluster assembled through Phases 17–26; no apple,
linux-cuda, or windows substrate is touched.

**Register:** 3 — live infrastructure (§K).

**Gate:** on a single-node linux-cpu cluster a `.dhall` app spec is decoded and reconciled by the
Deployment-`replicas=1` singleton (no election) so the app receives its own **namespace**, its declared
bounded `ObjectStoreBucketNeed`s rendered under the **`<app>/<bucket>`** MinIO prefix, and a one-member in-namespace Patroni
**`Sql`** database, all converging to ready and — under the **tenant `t1`'s own derived credentials** (never
admin/root) — reachable through the sole object-write gateway via an authenticated data round-trip (object
PUT then GET on `<t1>/<bucket>`, plus a Vault read of `secret/tenants/<t1>/…`), with exact provider-policy
apply/readback for Keycloak, Vault, Pulsar, MinIO, Kubernetes API, and Postgres and a
**provider-inventory-diff** teardown (pre-run vs post-run set
equality across Kubernetes API, MinIO, Vault, Pulsar, Keycloak, and Postgres, independent of harness tagging);
and, as a live regression
guard, each of the three Phase-0-committed negative fixtures (`illegal_cross_tenant_ref`,
`illegal_cross_tenant_user`, `illegal_handauthored_grant`) **fails at Gate 1 / Gate 2 before any binary acts**
**carrying its committed expected reason tag** (`CrossTenantRef{enclosing=t1, foreign=t2}`, `TwoTenantUser`,
`HandAuthoredGrant`) matched against the Phase-0 hand-authored expected-tag table, **each paired with its
minimal positive twin** (differing only in its foreclosed dimension — the foreign id corrected to `t1` for
`illegal_cross_tenant_ref` and `illegal_cross_tenant_user`, the hand-authored grant replaced by its derived
`deriveTenantPolicies` form for `illegal_handauthored_grant`) that must decode and deploy;
and the committed seeded mutant of the tenant-unification fold (guard-negation: the `RoleBinding`
resource-tenant vs enclosing-tenant equality inverted) is re-run and **must turn the gate red** — a
**Register-3** live-infrastructure check (the author-time foreclosure itself was already proven in-process in
the pre-cluster band).

Phase 27 applies and reads back the **Pulsar provider's administrative tenant/namespace/ACL state only**. It
does not claim a Pulsar application-client round trip: the native `amoebius-pulsar` protocol client does not
land until Phase 28, whose gate owns the authenticated tenant-credential produce/consume assertion. This
ordering is deliberate; provider-policy convergence may precede the client that exercises the resulting grant.

## Resource provision — tenant projection, policy transaction, and MinIO metadata seal

This phase instantiates the canonical resource matrix and sealed whole-deployment provision boundary from
[`resource_capacity_doctrine.md §3.1`](../documents/engineering/resource_capacity_doctrine.md#31-the-systematic-provision-matrix)
and [`§4`](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting);
tenant projection partitions ownership but does not create a second capacity vocabulary.

The tenant projection binds resources as well as names. Each app Deployment/sidecar/init container and each
tenant-facing object-write admission path carries a complete `PodResourceEnvelope`: immutable image and OCI
image-store/import footprint; CPU, memory, and ephemeral-storage requests and limits; runtime working set;
writable-root and log headroom; disk-/memory-backed local volumes and projected ConfigMap/Secret/downward-API/
service-account-token bytes; durable and explicit bounded-or-`None` cache arms and `accelerator = None` on
linux-cpu; replicas plus old/new/surge/terminating rollout overlap. Provider policy objects themselves do not
invent Pods, but any controller or gateway that materializes them is charged through its private
controller-child/admission envelope.

The `Sql` binding is a pure `PatroniSqlDemand`, not the string "one-member" and not a scalar disk size.
`ProvisionedPatroniSql` is private and retains `ProvisionedControllerChildren` with its operator-derived
`ControllerChildEnvelope`, complete consumer-facing and Patroni/Postgres child execution, the exact non-empty
`SchemaObjectDemand` set, WAL, checkpoint, failover-replay and recovery workspace, `DeclaredVolumeDemand`,
rollout/failover overlap, `StorageBudgetId`, `SqlMutationAdmission`, per-backing debit, and geometry witness.
The private result includes the complete SQL admission-proxy envelope and witness; direct or over-budget
mutating DB connections are denied.
The single-node shape has one database member, but
replacement/upgrade and failed recovery still debit old + new + WAL/workspace
until verification. No successful SQL migration, checkpoint, or cleanup is presumed during capacity checking.

Each bucket remains the `AppBucket` arm of the closed six-arm `ObjectStoreProducerDemand` inventory. Its exact
`ObjectStoreDemand` is joined by full store/tenant/bucket/key identity, resolves one `StorageBudgetId`, and
retains resident, future-retained, concurrent, failed, multipart, and orphan extents plus
`ObjectStoreMutationAdmission`; the admission gateway's execution envelope is included in the deployment.
After Gate 2, binding and whole-deployment provision check the app Pod, Patroni expansion, bucket producers,
gateway, namespace quota, pod/CSI slots, kubelet stores, and live-snapshot residual before creating a
namespace, policy, bucket, claim, or database. The exhaustive post-controller-expansion
desired/live/old/new/apply identity map gives every Kubernetes object a `KubernetesApiObjectDemand`.
`EtcdLogicalDemand { desiredObjects, churn, model }` derives the private logical peak, which must fit
`ControlPlaneStorageDemand.etcd.backendQuotaBytes`; the backend-at-quota plus WAL/snapshot/serialized-defrag
peak separately fits its physical backing.

Tenant policy materialization is part of that same seal, following the
[platform-services provider-indexed transaction](../documents/engineering/platform_services_doctrine.md#tenant-policy-persistence-is-one-provider-indexed-transaction).
The pure `deriveTenantPolicies :: TenantSpec -> TenantPolicyDerivation` intermediate carries one immutable
source digest, exact nested output/persistence/apply/executor identities, canonical sizes **and canonical content
digests**, retention/churn, provider targets, and bounded executor concurrency/failure/cost operands — never
capacity supply or a witness. The provider index is closed and exhaustive: **Keycloak, Vault, Pulsar, MinIO,
Kubernetes API, and Postgres**. Kubernetes NetworkPolicies are payloads of the Kubernetes-API arm; Postgres SQL
roles/grants are first-class provider outputs rather than being hidden inside the app database demand. Each arm
has its own canonical payload and exact persistence projection: Keycloak and Postgres schema rows/indexes plus
WAL, Vault records/versions plus Raft logs/snapshots, Pulsar znodes plus transaction logs/snapshots, MinIO
IAM/service-account/bucket-policy metadata, and Kubernetes API objects plus etcd revisions/Events. An output,
apply intent, persistence row, or executor whose source and provider do not join has no provisioned form.

All global keys are tenant-qualified: `(TenantId, TenantPolicyOutputId)`, `(TenantId,
TenantPolicyActionId)`, `(TenantId, TenantPolicyExecutorId)`, and `(TenantId, MinioSystemMetadataId)`. The
nested source tenant must equal the outer map key, so an equal-cardinality swap between two tenants cannot
authenticate. The planner takes `Map TenantId TenantPolicyDerivation`, not a non-empty map, and constructs one
transaction over `keys desired ∪ keys observed`. Each transaction row has `desired : Optional
TenantPolicyDerivation`; therefore an observed-only tenant yields authenticated deletes, deleting the final
tenant is representable, and the empty desired/empty observed inventory is the exact no-op transaction. No
cleanup is inferred from absence alone: observed-only outputs retain their observed source, target, apply, and
executor provenance in the generated delete action.

Executor resolution is also whole-deployment. Observed executors live once in one target-keyed global map,
outside per-tenant observed state; tenant-qualified actions carry membership references into it. Binding resolves
the abstract `< Dedicated | SharedControlPlaneRole >` attachments and groups every desired and delete delta by
resolved `ExecutionUnitId` across **all** tenants. Each complete `TenantPolicyExecutionResourceDelta` carries
source-level container resources, structural mounts/attachments, volumes, caches, and accelerator work—never
pre-derived runtime-component bytes—and is summed under its identity/model algebra. Gate 2 re-derives every
physical axis, then the shared base singleton/controller is replaced exactly once in `BoundExecutionSet`; a dedicated target
has one member and no shared base. Neither a per-tenant executor copy nor a per-tenant base debit is accepted.

Provider targets are transition coordinates, not timeless names. Each operation-indexed
create/replace/delete/no-op command has only the old/new target and payload fields legal for that operation;
there is no operation × optional-fields product. The high-water is a provider-indexed target map
that retains both sides of a target change: old and new Keycloak databases, Vault backings, Pulsar metadata
stores, MinIO store/budget/geometry/model tuples, Kubernetes clusters/namespaces/etcd models, and Postgres
cluster/database/schema/model tuples, plus both executor epochs and failed/rollback residents. A provider move
therefore cannot be costed as an in-place content rewrite or forget the old target before authenticated cleanup.

MinIO IAM/service-account/bucket-policy state uses a named `StorageBudgetId` as storage-system metadata; it is
not an application object and does not add a seventh arm to the closed six-arm `ObjectStoreProducerDemand`.
Before provisioning, the global binder groups tenant-qualified dynamic metadata by exact
`(store, budget, geometry, model)`, including **both old and new** groups, and merges entry identities and
concurrent/failure journal extents structurally. Each group resolves only to the selected MinIO retained backing;
`ProviderObjectQuota` is rejected because that supply needs a distinct provider-object-store policy arm.
Store-level physical planning consumes every group for that store in one call, preserves the observed and
planned metadata-model equality witness, adds `metadataReservePerDrive` once per concurrently resident store,
and adds every dynamic group once. Readback reports static reserve and dynamic metadata separately per drive;
neither a static-per-tenant debit nor a dynamic zero/double debit can normalize.

The seal does not stop at capacity witnesses. `ProvisionedTenantPolicyPersistence` contains a private,
provider-indexed `ProvisionedTenantPolicyAction` for every action: tenant-qualified identity/source, canonical
payload digest, operation, old and desired target, exact persistence high-water, provisioned executor reference,
failure/rollback retention, and cleanup predicate. The provider enactors accept only those actions paired with a
fresh `ValidatedLiveTarget`; they never accept `TenantSpec`, `TenantPolicyDerivation`, or a binder-stage target.
Read-only observers and provider-specific readback normalize source, payload, target, provider object version,
persistence components, and executor assignment. `NoOp` requires identity/source/provider/target/content-digest
equality. Create/replace/delete may release old persistence and execution only after action readback proves the
desired result (or authenticated absence for delete) and cleanup readback proves the old target gone. A failed
apply keeps old, new, failed-action, rollback, and executor capacity charged. The observation and action-set
fingerprints are bound into the single-use live target; no caller-authored prior `Provisioned*` value is input.

The boundary corpus makes every execution, data/WAL/recovery, attachment, object-count/size,
retention/failure, budget, rollout, API-object/revision/Event, and etcd term one unit short. Provider-indexed
mutants keep an action while dropping its Keycloak, Vault, Pulsar, MinIO, Kubernetes-API, or Postgres persistence
arm; target-move mutants drop either old or new target high-water; tenant-domain mutants swap an outer key,
omit an observed-only delete, or make final-tenant deletion uninhabitable. Execution mutants nest the global
executor map per tenant, leave shared deltas uncoalesced, or debit the base twice. MinIO mutants change only the
model, split one group, plan physical capacity per tenant, or drop/double the static or dynamic component. Every
mutant rejects before an enactor runs.

## Doctrine adopted

- [`tenancy_doctrine.md §4`](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--userspec--rolebinding) — *the typed shapes:
  `TenantSpec` / `UserSpec` / `RoleBinding`*: the three phantom-tagged types nested in the `InForceSpec`, whose
  isolation is the **absent arms** — no `Ref t1 a → Ref t2 a` constructor, no un-indexed `UserSpec`, and a
  `project` that yields only tenant `t`'s subtree — so a cross-tenant reference has no inhabitant in a well-typed
  spec. This phase decodes that surface and reconciles its data slice live.
- [`tenancy_doctrine.md §5`](../documents/engineering/tenancy_doctrine.md#5-rbac-is-derived-never-authored) —
  *RBAC is derived, never authored*: the typed tenant→role graph is the sole source of truth, and the single
  total `deriveTenantPolicies :: TenantSpec -> TenantPolicyDerivation` produces exact policy outputs plus their
  durable-store/API operands. Whole-deployment provision seals them before `renderAll` privately renders only
  their provisioned projections —
  the same derive-don't-author discipline as generated NetworkPolicies and taint-derived tolerations; there is
  no DSL surface with which to hand-author a Vault policy, a Pulsar ACL, or an SQL grant.
- [`tenancy_doctrine.md §3`](../documents/engineering/tenancy_doctrine.md#3-what-a-tenant-is) — *what a tenant
  is*: the immutable `TenantId` bundles a Keycloak realm, a Vault policy over `secret/tenants/<t>/…`, Pulsar
  tenant-namespaces, the `<t>/<bucket>` MinIO prefix (extending the per-app `<app>/<bucket>` binding — for this
  single-root app-tenancy projection the app *is* its own data-tenant, so `<t>` is the app's tenant id and the
  `<t>/<bucket>` policy scopes exactly the `<app>/<bucket>` bytes Sprint 27.1 stores), and an
  optional co-located Postgres database — minted once and travelling with the bytes it tags, so no migration
  re-tags a datum from `t1` to `t2`.
- [`tenancy_doctrine.md §7`](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit)
  — *two isolation layers, and the honest limit*: the type layer proves *the spec names no foreign tenant* (and
  where `t` degrades to a value-level id, a total decode-time fold checks it); it does **not** prove the policy
  derivation is faithful — that residue is runtime-checked, not foreclosed, and is stated rather than overclaimed.
- [`service_capability_doctrine.md §4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
  and [`§2`](../documents/engineering/service_capability_doctrine.md#2-the-capability-set) — *capability →
  provider → shape: the binding* and *the capability set*: the app names an abstract `ObjectStore` / `Sql`
  capability (never a product — `minio` has no syntax), and the deployment rules bind the canonical provider at a
  per-cluster shape. `renderAll` renders only provisioned projections of those bound services: the `ObjectStore`
  projection as the `<app>/<bucket>` MinIO prefix and the `Sql` projection as a one-member Patroni cluster. It
  never consumes either raw bound value.
- [`illegal_state_catalog.md §4.2`](../documents/illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
  and [`§3.45`](../documents/illegal_state/illegal_state_security.md#345-a-cross-tenant-or-hand-authored-rbac-binding)
  — *capability and phantom tenant tags* and *a cross-tenant or hand-authored RBAC binding*: the phantom-tag
  mechanism that makes cross-tenant refs uninhabitable, and the catalog entry that makes a hand-authored,
  un-derived provider grant have no syntax — both **built and proven in-process in the pre-cluster band**
  (the Phase-6 corpus); this phase re-runs their negatives against the live deploy path as a regression guard.
- [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)
  — *the control-plane singleton*: the tenant projection is reconciled by the Deployment-`replicas=1` singleton
  whose single-writer guarantee is **delegated to k8s/etcd through the mandatory reconciler `Lease`** — there
  is no election here; the singleton is stateless, its durable state exclusively the Vault-enveloped MinIO bucket.
- [`vault_pki_doctrine.md §3`](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)
  — *the `SecretRef` contract, a name never a value*: a tenant's `credential` and `transitKey`, and each
  provider credential, are carried as typed `SecretRef` names resolved in-cluster by the Phase-22 built-in Vault
  client — never a literal in Dhall.

## Sprints

## Sprint 27.1: The app data-tenant projection — namespace + `<app>/<bucket>` ObjectStore + in-namespace `Sql` 📋

**Status**: Planned
**Implementation**: `src/Amoebius/App/Tenancy.hs` (the per-app namespace + tenant-tagged resource projection: the
`<app>/<bucket>` `ObjectStore` resources against the canonical MinIO provider, and a one-member in-namespace
Patroni `Sql` instance) — target path, not yet built.
**Blocked by**: Phase 26 gate (the live DSL deploy via the `replicas=1` singleton — the deploy path this
projection is reconciled onto); Phases 23–24 (the standard MinIO + Patroni platform services this binds to, an
external earlier-phase prereq).
**Independent Validation**: decoding a trivial app `.dhall` yields exactly one namespace, the declared
`ObjectStore` buckets each rendered under the `<app>/<bucket>` MinIO prefix, and one one-member Patroni `Sql`
cluster in that namespace; the `replicas=1` singleton reconciles all three to ready and a re-run is a no-op; no
bare `postgres` Pod and no cross-namespace bucket is produced.
**Docs to update**: `documents/engineering/tenancy_doctrine.md`, `documents/engineering/service_capability_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`service_capability_doctrine.md §4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding),
[`§2`](../documents/engineering/service_capability_doctrine.md#2-the-capability-set), and
[`tenancy_doctrine.md §3`](../documents/engineering/tenancy_doctrine.md#3-what-a-tenant-is): realize an app's
capability resources — its own namespace, `ObjectStore` buckets `<app>/<bucket>`, and an in-namespace `Sql`
database — as a tenant-tagged projection of the app spec nested inside the cluster spec, reconciled against live
providers by the `replicas=1` singleton.

### Deliverables
- A per-app namespace and a tenant-tagged resource projection built on the pre-cluster-proven `Ref tenant a`
  (Phase 6), so an app's resources are located by its own tenant and cannot name another tenant's.
- `ObjectStore` bucket resources rendered as `<app>/<bucket>` against the canonical MinIO provider at its bound
  shape. Every `ObjectStoreBucketNeed` carries initial-object metadata plus structural
  additional-resident retention and concurrent/failure/orphan write bounds; binding joins observed objects to
  full store/tenant/bucket/key identities, creates an `AppBucket` producer, and merges its private structured
  peak with all MinIO producers before apply. Its deployment binding supplies exactly one closed
  `StorageBudget`/owner for the bucket. The sole-routable object-write gateway enforces the witness and
  direct tenant-credential S3 PUT is denied. An in-namespace `Sql` database is a **one-member Patroni
  cluster** (the honest single-node shape, never a bare `postgres` Pod).
- A complete app-service/rollout `PodResourceEnvelope` and a pure `PatroniSqlDemand`; the latter expands to a
  private `ProvisionedPatroniSql` retaining exact operator children, database execution, schema objects,
  WAL/checkpoint/recovery, claim geometry, failure/transition high-water, and the SQL admission-proxy
  envelope/witness. The resource-bearing SQL and object-write gateways are included rather than treated as
  free middleware.
- Provider credentials carried as typed `SecretRef` names (never literals), resolved in-cluster via the Phase-22
  built-in Vault client (mechanism owned by the Vault/PKI doctrine, not restated here).

### Validation
1. A trivial app `.dhall` with a complete bounded `ObjectStoreBucketNeed` decodes and the singleton reconciles
   its namespace, `<app>/<bucket>` `ObjectStore`
   bucket, and one-member Patroni `Sql` database to ready on the linux-cpu cluster; **a re-run is a no-op,
   defined observationally as: zero mutating (non-GET/-WATCH) apiserver calls attributable to the singleton in
   the kube-apiserver audit log during the second reconcile, AND every reconciled object's `resourceVersion`
   unchanged between the two runs** — an exit-0 or still-ready check alone does not satisfy this. The audit log
   is the OS-boundary observer (§M.5); a self-emitted "no changes" reconcile log does not count.
   A bucket name with no retention/write demand fails Gate 1. Same-total-byte fixtures with different object
   counts produce different stripe-rounded MinIO demands; object size/count/concurrency/retention overdraw and
   a one-byte physical shortfall reject before writes. A direct S3 PUT under the tenant credential is denied,
   while the snapshot-bound gateway accepts an in-envelope write; a fragmented-too-many-objects write is
   rejected before backing usage grows.
   Repeat the same demand against fitting `Fixed`, `QuotaCapped`, and `Growable` budget arms; a missing budget,
   duplicate id, wrong backing/account owner, or one-byte-short ceiling rejects before bucket/gateway writes.
2. The **app-surface slice of the decoded IR** is byte-identical when the bound shape is switched single-node
   vs distributed, while each shape first fully binds and provisions against its own declared sufficient
   topology and its rendered app-owned object manifests (namespace, `<app>/<bucket>` bucket resource, `Sql`
   StatefulSet/manifest) match the corresponding independently committed shape golden. The distributed shape
   is exercised **only through `provision` and `renderAll`** against a declared distributed topology (no live
   distributed deploy, since this phase's substrate is single-node `kind`), confirming the app travels while the binding
   varies structurally; the `Sql` is a Patroni cluster and no bare `postgres` Pod appears in the live namespace.
3. Run exact-fit/one-short and omission fixtures over the app Pod, admission gateway, Patroni children,
   schema-object/WAL/checkpoint/recovery workspace, SQL proxy/admission, claim/attachment, rollout overlap, and
   `AppBucket` object demand.
   Each negative returns a specific `ProvisionError` with zero apiserver, MinIO, or SQL mutation. For the
   exact-fit twin, normalized live requests/limits/images/local storage, generated Patroni children/PVCs, and
   full MinIO object identities equal the private provisioned projection.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 27.2: The `TenantSpec`/`UserSpec`/`RoleBinding` typed surface + no-foreign-tenant foreclosure 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/Tenant.dhall` (the `TenantSpec` / `UserSpec` / `RoleBinding` record + union
types with only tenant-`t` reference constructors); `src/Amoebius/Tenancy/Types.hs` (the phantom-tagged
`TenantId` / `TenantSpec t` / `UserSpec t` / `RoleBinding t` IR); `src/Amoebius/Tenancy/Project.hs` (the total
`project : RootInForceSpec → TenantId → TenantSpec t` fold and the value-level tenant-unification check) —
target paths, not yet built.
**Blocked by**: Sprint 27.1 (the tenant-tagged data projection these bindings reference); the Phase-6
illegal-state corpus (the phantom-tag `Ref t` mechanism + the cross-tenant-ref negative, proven in-process — an
external earlier-phase prereq).
**Independent Validation**: decoding a `TenantSpec t` fixture yields only tenant `t`'s subtree; a well-typed
fixture whose `RoleBinding` names a `Ref t' (t' ≠ t)` resource returns a structured decode `Left` (Gate 2),
or fails `dhall type` where the tag is a static phantom (Gate 1) — exercising the cross-tenant-ref foreclosure
whose mechanism and corpus were proven in-process in the Phase-6 pre-cluster band, here re-run against the live
decode path (the Phase-27 gate `.dhall` fixture and its `expected_tags.dhall` oracle are themselves
Phase-0-pinned, §M.1); a user belonging to two tenants cannot be typed.
**Docs to update**: `documents/engineering/tenancy_doctrine.md`, `documents/illegal_state/illegal_state_catalog.md`
(per-entry layer reconciliation for §4.2), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`tenancy_doctrine.md §4`](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--userspec--rolebinding) (the typed shapes) and
[`illegal_state_catalog.md §4.2`](../documents/illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable):
stand up the `TenantSpec`/`UserSpec`/`RoleBinding` surface whose **absent arms** make a foreign-tenant reference
unrepresentable, and prove the deploy path never admits one — the author-time foreclosure was proven in-process
in the pre-cluster band; here it becomes a live regression guard.

### Deliverables
- The `TenantSpec (t : TenantId)` / `UserSpec (t : TenantId)` / `RoleBinding (t : TenantId)` types nested in the
  `InForceSpec`, carrying the immutable `tenantId`, the realm ref, the derived `dataNs`, the `SecretRef`
  transit key, and the `roles`/`users` lists.
- The isolating absence: **no** `Ref t1 a → Ref t2 a` constructor (inside a `RoleBinding t` only `Ref t _`
  constructors are in scope), **no** un-indexed `UserSpec`, and a `project : RootInForceSpec → TenantId →
  TenantSpec t` that admits no sibling-tenant or cluster-scoped branch.
- The honest type/decode split ([`tenancy_doctrine.md §7`](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit)):
  where `t` is a static phantom the cross-tenant ref is **type-foreclosed** (Gate 1); where it degrades to a
  value-level `TenantId`, a total decode-time fold unifies every `RoleBinding`'s resource-tenant with its
  enclosing `TenantSpec`'s tenant — **decode-foreclosed** (Gate 2) — each annotated with its foreclosure layer.

### Validation
1. `project` over a two-tenant root spec returns only the requested tenant's subtree; no field yields a
   sibling-tenant or cluster-scoped branch.
2. **One committed negative fixture per resource-reference arm the unification fold checks — `Ref` to a foreign
   tenant's bucket, topic, AND secret (three fixtures, not one of any kind)** — is rejected at Gate 1 or Gate 2,
   and the returned structured error **carries the committed reason tag `CrossTenantRef{enclosing=t1,
   foreign=t2}`** (or, on the static-phantom arm, the `dhall type` error locus), which the test asserts equal to
   the value in the **Phase-0-committed hand-authored expected-tag table** (`test/fixtures/phase23/expected_tags.dhall`) —
   the reference side authored independently of the fold, never read back from the fold's own output (§M.3, §M.8).
   **Each negative ships a minimal positive twin, byte-identical except the foreign tenant id corrected to the
   enclosing `t1`, that must decode successfully** — so a rejection is attributable to cross-tenancy alone and
   not an unrelated field/typo. An attempt to place one user in two tenants likewise returns the `TwoTenantUser`
   tag. The suite is red if any negative decodes, if any positive twin fails, **or if any negative fails
   carrying a tag other than its committed one**. The value-level unification fold additionally carries a
   QuickCheck `cover` obligation forcing the cross-tenant-reject branch to fire in **≥ 20%** of generated
   `RoleBinding` cases (§M.4), and the committed guard-negation mutant of the fold (Sprint 27.4) is run here and
   must turn this suite red.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 27.3: One provider-indexed tenant-policy transaction from the tenant→role graph 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Tenancy/{Rbac,Observe,Plan,Bind,Provisioned,Validate,Readback}.hs` (pure
derivation, whole-deployment observation/planning/binding, sealed actions, live-target validation, and exact
readback) and
`src/Amoebius/Tenancy/Provider/{Keycloak,Vault,Pulsar,Minio,KubernetesApi,Postgres}.hs` (provider-specific
enactors and normalizers) — target paths, not yet built.
**Blocked by**: Sprint 27.1, Sprint 27.2; Phase 22 (the root Vault + built-in client that hosts the derived
per-tenant policies), Phases 23–24 (MinIO, Pulsar, and Patroni persistence), and Phase 25 (the Keycloak-owned
edge) — external earlier-phase prerequisites. Phase 28 is deliberately **not** a prerequisite: Phase 27 uses
Pulsar's administrative policy adapter only; Phase 28 owns the native-client data-path gate.
**Independent Validation**: for a two-tenant fixture, observation plus derivation produces one exhaustive,
tenant-qualified transaction covering Keycloak, Vault, Pulsar, MinIO, Kubernetes API, and Postgres. Whole
provision seals exact provider actions before any private enactor runs; a shared-role fixture globally coalesces
both executor deltas onto one target, old→new target moves retain both high-waters, and store-level MinIO
planning adds static reserve once plus each model-equal dynamic group once. An observed-only final tenant yields
deletes and then the exact empty transaction. Readback must discharge each action and cleanup predicate. Pulsar
validation here is exact administrative tenant/namespace/ACL apply/readback, **not** produce/consume.
**Docs to update**: `documents/engineering/tenancy_doctrine.md`, `documents/engineering/vault_pki_doctrine.md`,
`documents/engineering/platform_services_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`tenancy_doctrine.md §5`](../documents/engineering/tenancy_doctrine.md#5-rbac-is-derived-never-authored)
and [`illegal_state_catalog.md §3.45`](../documents/illegal_state/illegal_state_security.md#345-a-cross-tenant-or-hand-authored-rbac-binding):
derive every concrete provider policy from the typed tenant→role graph with one total function, plan all desired
and observed tenants in one provider-indexed transaction, and make only sealed provisioned actions enactable.
The transaction must represent creation, replacement, target migration, ordinary deletion, deletion of the
final tenant, and exact-empty no-op without losing persistence or executor capacity before verified cleanup.

### Deliverables
- The total `deriveTenantPolicies :: TenantSpec -> TenantPolicyDerivation` intermediate returns provider-indexed
  canonical payloads for Keycloak realm roles/scopes/routes, Vault policy/auth objects, Pulsar
  tenant/namespace/ACL objects, MinIO IAM/service-account/bucket-policy objects, Kubernetes NetworkPolicy/RBAC
  API objects, and Postgres roles/grants. Every local output/action/executor/MinIO-metadata id becomes globally
  qualified by its immutable `TenantId`; nested source tenant and outer key equality is mandatory.
- The same derivation carries exact persistence identities, sizes, content digests, targets, retention, failure,
  and churn operands: separate Keycloak and Postgres schema/WAL demands; Vault persisted versions and Raft
  high-water; Pulsar ZooKeeper objects/logs/snapshots; MinIO dynamic system metadata through a named budget,
  geometry, and model; and Kubernetes objects/etcd revisions/Events. MinIO system metadata remains outside the
  closed application-object producer union.
- `Observe` constructs one `ObservedTenantPolicyWholeDeploymentInventory`: tenant state is keyed by `TenantId`,
  while observed execution targets are held once in a separate global target-keyed map with tenant action
  memberships. Every observed output records tenant/source, provider, payload digest, target, apply/action, and
  executor provenance; MinIO readback separates static and dynamic per-drive components and records the model.
- `Plan` takes a possibly empty desired map. Its domain is exactly `desired ∪ observed`, and each tenant row has
  optional desired state. Observed-only rows generate authenticated provider deletes; this represents zero
  tenants and deletion of the final tenant. Every action carries optional old and desired targets, and the
  provider-target-keyed high-water includes both sides of changes for all six providers.
- `Bind` resolves abstract `< Dedicated | SharedControlPlaneRole >` attachments and globally coalesces complete
  execution-resource deltas by resolved target across all tenant memberships. A shared base is replaced once;
  dedicated targets are unique. The binder also exact-joins every provider payload/action/persistence projection.
- MinIO dynamic groups are keyed by `(store,budget,geometry,model)` and by tenant-qualified entry ids. One
  store-level physical fold considers concurrent old and new groups, charges static reserve once per resident
  store and every dynamic group once, and rejects a model mismatch, split group, unsupported provider quota,
  or static/dynamic ownership hole/overlap.
- `ProvisionedTenantPolicyPersistence` owns provider-indexed opaque `ProvisionedTenantPolicyAction`s containing
  exact source/payload/operation/old+desired target/persistence/executor/retention/cleanup witnesses. Only the
  corresponding provider adapter plus a fresh fingerprint-matching `ValidatedLiveTarget` may enact one. The
  `Readback` modules validate action result and old-target cleanup before releasing any retained capacity.
- The **derive-don't-author** enforcement: no DSL surface hand-authors a Vault policy, Pulsar ACL, or SQL grant —
  precisely as none exists for a NetworkPolicy — so an un-derived provider grant has no syntax (catalog §3.45).
- The **honest limit** recorded ([`tenancy_doctrine.md §7`](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit)):
  this sprint does **not** prove the policy derivation is faithful; an over-grant is a runtime-checked
  residue, not a foreclosed one, and the default shared-service model's tenant isolation rests on per-tenant
  policy within shared Vault/broker/MinIO — the own-child-cluster hardening dial stays deferred to federation.

### Validation
1. `deriveTenantPolicies` over two tenants returns all six provider arms with tenant-qualified keys and exact
   source-equal payload/persistence/action/executor maps. Independent mutants change one outer tenant key, swap
   equal-cardinality tenant maps, change a nested source, drop each provider persistence arm in turn, or orphan
   an action/executor. Each rejects before effects; every unmodified twin provisions. No app/tenant arm can
   hand-author an output.
2. A positive two-tenant fixture sharing a control-plane role resolves one `ExecutionUnitId`, sums both complete
   deltas, and replaces the singleton base exactly once. Mutants duplicate the observed executor inside each
   tenant, duplicate a dedicated target, leave shared deltas uncoalesced, or debit the base twice; each fails
   before a provider action. The sealed value contains provisioned references, not binder-stage targets.
3. Empty desired/empty observed is an exact no-op. Desired-empty/observed-one generates six authenticated delete
   actions for the final tenant, provisions their old-state/executor retention, and becomes empty only after
   provider absence and cleanup readback. Mutants require `NonEmpty`, omit an observed-only output, erase its
   source/action/executor provenance, or release on desired absence; each turns the gate red.
4. For each provider independently, a target-change fixture charges a target-keyed old+new high-water and keeps
   both executor epochs plus failure/rollback residents until cutover and cleanup. Dropping either Keycloak,
   Vault, Pulsar, MinIO, Kubernetes-API, or Postgres old/new target component rejects. Equal size with a different
   digest is `Replace`; equal digest with only a provider object-version change is `NoOp` after snapshot validation.
5. MinIO fixtures reject missing/duplicate/wrong-owner/stale budgets, unsupported provider quota, wrong geometry,
   and wrong model. A concurrent old-store/new-store two-tenant positive makes one physical call per store,
   charges static reserve once per store and each tenant-qualified dynamic group once, and matches observed
   static/dynamic per-drive readback. Split-group, per-tenant static, and component drop/double mutants reject.
6. Each provider enactor is negative-tested against raw derivations, wrong provider projections, stale live
   fingerprints, missing sealed actions, mismatched targets, and cleanup-before-readback. Only the matching
   `ProvisionedTenantPolicyAction` plus `ValidatedLiveTarget` acts; failed actions preserve all charged residents.
7. The live Phase-27 gate checks MinIO and Vault same-tenant success paired with cross-tenant refusal, and exact
   administrative apply/readback of Keycloak roles/scopes, Vault policies, Pulsar tenant/namespace/ACL state,
   MinIO policies, Kubernetes objects, and Postgres roles/grants. It performs **no Pulsar produce/consume**.
   Phase 28 must later pair the Pulsar cross-tenant refusal with a same-credential native-client round trip; until
   that gate passes, Pulsar data-path isolation remains unverified rather than being inferred from admin readback.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 27.4: Phase gate harness — deploy-a-tenant-app + reject-the-foreign-tenant-spec 📋

**Status**: Planned
**Implementation**: `dhall/examples/{tenant_app,illegal_cross_tenant_ref,illegal_cross_tenant_user,
illegal_handauthored_grant}.dhall` (gate fixtures); `test/integration/{Phase23Gate,
Phase23TenantPolicyLifecycle}.hs` (linux-cpu spin-up/reconcile/final-tenant deletion/teardown, provider readback,
negative decode assertions, and the Register-3 ledger) — target paths, not yet built.
**Blocked by**: Sprint 27.1, Sprint 27.2, Sprint 27.3.
**Independent Validation**: the harness deploys a tenant app from one `.dhall` on linux-cpu — the app gets its
namespace, `<app>/<bucket>` `ObjectStore`, and one-member in-namespace Patroni `Sql`, reconciled to ready by the
`replicas=1` singleton — then removes the final tenant through sealed delete actions and tears down leak-free
(postflight sweep empty); it then asserts each
deliberately-illegal fixture (a foreign-tenant `Ref`, a two-tenant user, a hand-authored provider grant) fails
to type-check or decode; the run emits a Register-3 proven/tested/assumed ledger.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (flip the Phase-27 status when the gate passes),
`DEVELOPMENT_PLAN/substrates.md` (the Phase-27 linux-cpu gate row), `documents/engineering/testing_doctrine.md`,
`documents/engineering/tenancy_doctrine.md`.

### Objective
Adopt [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
and [`tenancy_doctrine.md §4`](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--userspec--rolebinding): assemble the phase's single **live**
acceptance gate — one `.dhall` deploys a tenant app whose namespace, `<app>/<bucket>` `ObjectStore`, and
in-namespace `Sql` the `replicas=1` singleton reconciles to ready and tears down leak-free; and, as a regression
guard, the pre-cluster no-foreign-tenant corpus is re-run so a spec naming a foreign tenant's resource still
fails before any binary acts.

### Deliverables
- A positive gate `.dhall` (`tenant_app`) composing the platform spec + a tenant app (Sprints 23.1–23.3) that
  the singleton reconciles to ready and then tears down leak-free, authored as a test-topology `.dhall` with a
  teardown obligation and a **full pre-run-vs-post-run provider-inventory diff** (asserting set equality across
  Kubernetes API, MinIO, Vault, Pulsar, Keycloak, and Postgres, independent of test-owned tagging) — never a
  tag-scoped sweep alone.
- The complete provision input for that fixture: app and gateway Pod envelopes, exact `AppBucket` producer,
  app `PatroniSqlDemand`, and tenant-qualified `TenantPolicyDerivation`s merged source-exactly into separate
  Keycloak and Postgres SQL/WAL, Vault Raft, Pulsar ZooKeeper, MinIO internal-metadata, and Kubernetes API/etcd
  demands; resolved MinIO budget/supply/model; one global provider-executor inventory; globally grouped MinIO
  old+new dynamic metadata; and provider-target-keyed transition high-waters, all snapshot-bound and proven to
  fit before namespace creation. A raw-bound-to-`renderAll` bypass, per-term omission/one-short mutants, the six
  drop-demand-while-action-remains mutants, cross-tenant key/source swaps, execution coalescing/base-debit
  mutants, old/new target mutants, MinIO model/group/component mutants, and the same-size/different-digest mutant
  must turn the gate red without effects.
- A lifecycle fixture starts with two tenants, deletes one, then deletes the final tenant. The planner's domain is
  always `desired ∪ observed`; each observed-only row retains source/action/executor provenance; old capacity is
  released only after provider absence and cleanup readback; and the final result is the exact empty transaction.
  A matching empty-desired/empty-observed fixture is a no-op and executes no provider call.
- Negative gate fixtures — re-run as a live regression guard, **authored and committed in Phase 0 before the
  implementation** (§M.1) — `illegal_cross_tenant_ref` (three arms: a `RoleBinding` naming a `Ref t' ≠ t`
  bucket, topic, and secret, catalog §4.2), `illegal_cross_tenant_user` (a `UserSpec` in two tenants), and
  `illegal_handauthored_grant` (a hand-authored provider policy, catalog §3.45) — each asserted to fail at
  Gate 1 or Gate 2, annotated with its foreclosure layer, and each **carrying its committed expected reason
  tag**. Each negative ships its **minimal positive twin**, differing only in its foreclosed dimension (the
  foreign id corrected to `t1` for the two cross-tenant fixtures; the hand-authored grant replaced by its
  derived `deriveTenantPolicies` form for `illegal_handauthored_grant`), that must decode and deploy.
- The **Phase-0-committed independent oracle** `test/fixtures/phase23/expected_tags.dhall` — a hand-authored
  table mapping each negative fixture to its expected reason tag (`CrossTenantRef{enclosing, foreign}`,
  `TwoTenantUser`, `HandAuthoredGrant`), authored independently of the `project`/unification fold, never
  regenerated from it (§M.3).
- At least one **committed seeded mutant** (§M.2), drawn from the defined operator set: the guard-negation
  mutant `mutants/phase23/fold_tenant_eq_inverted` of the tenant-unification fold (the `RoleBinding`
  resource-tenant vs enclosing-tenant equality inverted, so a cross-tenant ref decodes clean), committed and
  re-run by the gate, which **must** turn the negative suite and the gate red.
- A **Register-3** proven/tested/assumed ledger recording the live-realization result (namespace + bucket + Sql
  converged; all six provider policy actions and cleanup read back; MinIO/Vault cross-tenant reads refused) and
  explicitly marking the deferred surfaces — the Phase-28 Pulsar native-client round trip, tenant-admin
  scope-narrowed `dhall update`, own-child-cluster hardening, and policy-derivation fidelity — as UNVERIFIED.

### Validation
1. The positive `.dhall` brings the tenant app up on the linux-cpu cluster; **reachability is defined as an
   authenticated tenant-credential data round-trip under `t1`'s own derived credentials** (never admin/root,
   never endpoint-liveness or an admin listing): an admitted object gateway-PUT-then-GET on
   `<app>/<bucket>` with direct S3 PUT denied, and an in-namespace
   `Sql` connect-write-read under the derived `SecretRef` credential must all succeed. Teardown then uses a
   **full provider-inventory diff — pre-run snapshot vs post-run snapshot, asserting set equality — in every
   provider the phase touches (Kubernetes namespaces/RBAC/NetworkPolicies/PVs, MinIO buckets/policies, Vault
   policies under `secret/tenants/`, Pulsar administrative tenants/namespaces/ACLs, Keycloak realms, and
   Postgres roles/grants), independent of the harness's own
   test-owned tagging**; a tag-scoped sweep alone does not satisfy this (§M.5). Any resource present post-run
   and absent pre-run fails the gate.
2. Every illegal `.dhall` fixture is rejected before any binary acts **carrying its committed expected reason
   tag** (`CrossTenantRef{enclosing=t1, foreign=t2}` for `illegal_cross_tenant_ref`, `TwoTenantUser` for
   `illegal_cross_tenant_user`, `HandAuthoredGrant` for `illegal_handauthored_grant`) matched against the
   Phase-0 hand-authored expected-tag table `test/fixtures/phase23/expected_tags.dhall`, **each paired with its
   minimal positive twin** differing only in its foreclosed dimension (the foreign id corrected to `t1` for the
   two cross-tenant fixtures; the hand-authored grant replaced by its derived form for
   `illegal_handauthored_grant`) that decodes and deploys — a rejection carrying
   the wrong tag, or a positive twin that fails, fails the gate. The committed guard-negation mutant of the
   tenant-unification fold is re-run and **must turn the gate red**. The Register-3 ledger is present and
   honestly classifies each foreclosure and each deferred residue (no runtime-checked claim reported as proven).
3. Assert the resource-boundary corpus rejects before any provider mutation and that the positive run's live
   app Pods, Patroni operator children/claims, SQL proxy/admission, object gateway, and exact bucket objects
   normalize to the opaque provisioned values. Also assert exact tenant/source-equal readback of separate
   Keycloak and Postgres rows/WAL, Vault persisted records/Raft high-water, Pulsar administrative ZooKeeper
   paths/logs/snapshots, MinIO IAM/policy metadata and per-drive static-versus-dynamic component high-water, API
   objects/etcd high-water, sealed actions, and the one global executor set. Assert that two tenants sharing the
   controller role produce one target-keyed coalesced execution witness and one base debit, and that all old/new
   tenant MinIO metadata is globally grouped by store/budget/geometry/model before one physical call per store
   with static reserve once. The observed transition fingerprint, exact desired∪observed tenant domain,
   qualified action identities/content digests, provider-target-keyed old+new high-water, executor overlap, and
   rollback/cleanup retention must match `ValidatedLiveTarget`. Deleting the final tenant must execute sealed
   deletes, prove absence/cleanup, and converge to the exact empty inventory. A `Ready` database with
   an omitted WAL/recovery/proxy/rollout debit, a surviving policy action with any demand/executor dropped, an
   omitted old policy, uncoalesced/double-base execution, provider-quota-backed MinIO policy metadata,
   per-tenant static reserve, a MinIO model mismatch, a static/dynamic component counted zero/twice,
   early cleanup, an unqualified tenant id, an unplanned observed-only output, or digest-different content treated
   as `NoOp` is a failed gate. Pulsar success here is administrative ACL convergence only; authenticated
   produce/consume remains a Phase-28 gate.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/tenancy_doctrine.md` — the §4 typed-shape, §5 derived-RBAC, and §7 honest-limit notes
  flip from "Phase-N design intent" to a delivered app-tenant projection with its Register-3 ledger attached; the
  open choices it names (realm-per-tenant vs one realm with per-tenant client scopes; OSS Vault per-tenant policy
  vs Enterprise namespace) are recorded as pinned to what this gate realized.
- `documents/engineering/service_capability_doctrine.md` — backlink the §4 `<app>/<bucket>` binding and the §2
  capability set to the realized `ObjectStore`/`Sql` projection.
- `documents/illegal_state/illegal_state_catalog.md` — annotate the §4.2 phantom-tenant-tag and §3.45
  hand-authored-grant entries as re-run against the live deploy path (type-/decode-foreclosed layers already
  proven in-process in Phase 6; the runtime-refusal layer gains its first live check).
- `documents/engineering/vault_pki_doctrine.md`, `documents/engineering/platform_services_doctrine.md` — record
  all six provider-indexed policy arms as derived, not hand-authored, outputs whose persistence, execution,
  old+new target high-water, action, and cleanup pass through whole-deployment provision.
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (the
  Phase-28 Pulsar client data path, tenant-admin surface, child-cluster promotion, and derivation fidelity
  UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-27 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 27's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/App/Tenancy.hs`,
  `src/Amoebius/Tenancy/{Types,Project,Rbac,Observe,Plan,Bind,Provisioned,Validate,Readback}.hs`, and the six
  `src/Amoebius/Tenancy/Provider/*.hs` adapters (with `dhall/amoebius/Tenant.dhall`) as Phase-27 rows; keep the
  authenticated native Pulsar client gate assigned to Phase 28.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Multi-Tenancy, Users & RBAC](../documents/engineering/tenancy_doctrine.md) — the `TenantId`, the
  `TenantSpec`/`UserSpec`/`RoleBinding` typed surface, the derive-don't-author RBAC rule, and the honest limit
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — the `<app>/<bucket>`
  binding and the capability set this phase realizes
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — the six provider
  persistence targets and sealed administrative action boundary
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — the phantom-tenant-tag mechanism
  (§4.2) and the hand-authored-grant entry (§3.45) re-run as a live guard
- [Vault, PKI & Secret Injection](../documents/engineering/vault_pki_doctrine.md) — the `SecretRef` contract for
  tenant credentials and the derived per-tenant Vault policy
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — the Deployment-`replicas=1`
  control-plane singleton (no election) that reconciles this projection
- [phase_26](phase_26_live_dsl_singleton.md) — the live DSL deploy via the `replicas=1` singleton this phase builds on
- [phase_28](phase_28_pulsar_client.md) — owns the authenticated Pulsar native-client produce/consume gate that
  Phase 27's administrative ACL readback deliberately does not claim
