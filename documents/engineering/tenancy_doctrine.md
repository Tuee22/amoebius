# Tenancy

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_23_app_tenancy.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: Single source of truth for the amoebius tenant axis — the first-class `TenantId` orthogonal to the cluster axis, the `TenantSpec`/`UserSpec`/`RoleBinding` types by which a valid `InForceSpec` cannot name a foreign tenant's resource, cross-tenant sharing as an append-only revocable capability edge (never a re-tag), the rule that provider RBAC is derived from the tenant→role graph rather than authored, and the tenant-admin surface that reduces to a scope-narrowed admin mutation.

---

## 1. Why this doctrine exists

A multi-tenant workload keeps more than one customer's data on shared platform services, and the load-bearing obligation is isolation: tenant B must never read, share, or destroy tenant A's data, and the guarantee must hold at the layer where a spec is authored, not only at the layer where a policy is enforced. The failure surfaces at **author time** — a spec that names a cross-tenant grant, or hand-writes a provider ACL that over-grants — and at **runtime** — a rendered policy that leaks.

The obvious alternative — model a tenant as an ordinary application record and enforce isolation with hand-authored Vault policies, Pulsar ACLs, and SQL grants — fails because a hand-authored grant is exactly the surface where a cross-tenant reference becomes representable: the author can write down a binding that names another tenant's bucket, and nothing in the type of that binding forbids it. Isolation then rests entirely on review and runtime enforcement, which the amoebius contract ([dsl_doctrine.md §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)) rejects for exactly this class of invariant.

The rule this doctrine states: **a tenant is an immutable `TenantId`, every tenant-scoped datum and role binding is tagged by that id, and provider RBAC is *derived* from the tenant→role graph — never hand-authored.** A `RoleBinding` in tenant `t` has no constructor that names a resource in tenant `t' ≠ t`, and there is no DSL surface with which to write a Vault policy, a Pulsar ACL, or an SQL grant directly.

What it forecloses: a cross-tenant data reference or role binding has no inhabitant in a well-typed spec (catalogued at [illegal_state_catalog.md §3.8](../illegal_state/illegal_state_security.md#38-cross-tenant-references-and-literal-secrets), foreclosed by the phantom-tag mechanism of [§4.2](../illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)), and a hand-authored, un-derived provider grant has no syntax. Deliberate cross-tenant *sharing* is not foreclosed — it survives as an explicit, append-only, revocable capability edge ([§5.4](#54-cross-tenant-sharing-is-an-append-only-revocable-capability-edge)), never a re-tag. The residue this doctrine does **not** claim to foreclose — that the derivation onto Keycloak, Vault, Pulsar, MinIO, Kubernetes API, and Postgres is faithful — is stated honestly in [§7](#7-two-isolation-layers-and-the-honest-limit).

## 2. The tenant axis is orthogonal to the cluster axis

The data plane is already typed with two phantom indices — `DataPlane (c :: ClusterId) t` ([single_logical_data_plane_doctrine.md §3](./single_logical_data_plane_doctrine.md#3-the-binding-reachability-is-a-type-not-a-runtime-probe)) — where `c` is the cluster/forest axis and `t` is the tenant axis. This doctrine disambiguates `t` into a first-class `TenantId`; it introduces no new isolation primitive.

- **`c` — the cluster axis** — is owned by the recursive forest: a parent spawns children, each child's subtree spec is enveloped under a per-child Vault Transit key, and a child cannot decrypt a sibling's subtree ([cluster_lifecycle_doctrine.md §3](./cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest), [vault_pki_doctrine.md §6](./vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes)). Per-child cryptographic isolation is a property of this axis.
- **`t` — the tenant axis** — is *within and across* a cluster: many tenants share one cluster's platform services, keyed by `TenantId`.

The two axes compose and never fuse: `c` and `t` unify independently, and a datum is located by both. `TenantId` is not a `ClusterId`, and promoting a tenant onto its own cluster ([§7](#7-two-isolation-layers-and-the-honest-limit)) changes the tenant's `c`, never its `t`.

## 3. What a tenant is

A tenant is an immutable `TenantId` that bundles the per-tenant slice of each service that carries native tenancy:

- a **Keycloak realm** (the tenant's identity boundary — [platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path));
- a **Vault policy / mount** scoped to `secret/tenants/<t>/…` (the tenant's secret boundary — [vault_pki_doctrine.md §3](./vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value));
- a set of **Pulsar tenant-namespaces** `persistent://<t>/<ns>/…` ([pulsar_client_doctrine.md §6](./pulsar_client_doctrine.md#6-the-declarative-topology-algebra));
- a **MinIO bucket prefix** `<t>/<bucket>` (extending the per-app `<app>/<bucket>` binding of [service_capability_doctrine.md §4](./service_capability_doctrine.md#4-capability--provider--shape-the-binding));
- optionally one **Postgres database**, co-located in its consuming service's namespace ([platform_services_doctrine.md §8](./platform_services_doctrine.md#8-postgres--patroni-via-percona-one-cluster-per-consumer-with-pgadmin)).

`TenantId` is **minted once and immutable**, and it travels with the bytes it tags: no migration re-tags a datum from `t1` to `t2` (the data-plane form of the absent `Ref t1 a → Ref t2 a` coercion, owned by [illegal_state_catalog.md §4.2](../illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) and the migration invariants of [release_lifecycle_doctrine.md §5](./release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply)). This immutability is the shared boundary between this doctrine (which owns the tenant/user/RBAC surface) and the storage-migration doctrine (which owns the data invariants that ride on the tag — [inforcespec_migration_doctrine.md](./inforcespec_migration_doctrine.md)).

The recommended default is one `TenantId` per tenant on shared cluster services, which scales to many tenants; a tenant's *own child cluster* is the hardening projection, not the default ([§7](#7-two-isolation-layers-and-the-honest-limit)).

## 4. The typed shapes: `TenantSpec` / `UserSpec` / `RoleBinding`

The tenant surface is three phantom-tagged types nested in the `InForceSpec` — a composition axis alongside app-in-cluster and extension-in-app ([dsl_doctrine.md §4](./dsl_doctrine.md#4-total-composability)), which *carries* these fields and defers their unrepresentability here:

    TenantSpec (t : TenantId) :
      { tenantId   : TenantId              -- == t; minted once, immutable
      , realm      : KeycloakRealmRef t    -- the tenant's OIDC realm
      , dataNs     : TenantNamespaces t     -- DERIVED: Pulsar ns, MinIO prefix, Vault path, optional Sql db
      , transitKey : SecretRef              -- per-tenant Transit key, named not held
      , roles      : List (RoleSpec t)
      , users      : List (UserSpec t)
      }
    UserSpec (t : TenantId) :
      { userName   : Text
      , credential : SecretRef              -- password / token, by name only
      , bindings   : List (RoleBinding t)
      }
    RoleBinding (t : TenantId) :
      { role : RoleRef t , resource : Ref t Resource , caps : List Capability }

The isolation is the **absent arms** ([illegal_state_catalog.md §3.8](../illegal_state/illegal_state_security.md#38-cross-tenant-references-and-literal-secrets), technique [§4.2](../illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)):

- There is **no constructor `Ref t1 a → Ref t2 a`**. Inside a `RoleBinding t1`, the only resource-reference constructors in scope produce `Ref t1 _`, so a binding that names another tenant's bucket, topic, or secret has no inhabitant.
- There is **no un-indexed `UserSpec`**. Every user is a `UserSpec t` nested in exactly one `TenantSpec t`'s `users` list, so a user belonging to two tenants cannot be typed.
- The projection `project : RootInForceSpec → TenantId → TenantSpec t` yields **only** tenant `t`'s subtree — the tenant analogue of the `ChildInForceSpec` projection ([dsl_doctrine.md §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)). No field admits a sibling-tenant or cluster-scoped branch.

Authentication is **realm-per-tenant**: each `TenantId` maps to a Keycloak realm; a user authenticates to its own realm; the OIDC/JWT realm claim is enforced at the single Envoy ext-authz edge ([platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)), so a realm-`t1` token cannot satisfy a realm-`t2` route.

Secrets stay names, never values, throughout: `credential` and `transitKey` are `SecretRef`s resolved by the parent/singleton into Vault ([vault_pki_doctrine.md §3](./vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)).

## 5. RBAC is derived, never authored

The typed tenant→role graph is the sole source of truth for access; the concrete provider policies are
**derived from it**, never hand-written — the same derive-don't-author discipline as generated NetworkPolicies
and taint-derived tolerations. The single total boundary is an intermediate derivation, never a renderer:

    deriveTenantPolicies :: TenantSpec -> TenantPolicyDerivation

`TenantPolicyDerivation` is pure. It carries one immutable tenant/role-graph source digest, exact canonical
payloads and content digests, persistent-source/retention/churn operands, provider targets, apply-action and
executor intents, and bounded execution cost operands. Its executor attachment is only
`< Dedicated | SharedControlPlaneRole >`; it contains no concrete `ExecutionUnitId`, supply, observation,
placement, or provision witness. The closed provider index is:

- **Keycloak** — realm roles, client scopes, and route-auth rules;
- **Vault** — policy/auth objects over `secret/tenants/<t>/…`;
- **Pulsar** — tenant, namespace, and ACL objects for `persistent://<t>/…`;
- **MinIO** — IAM, service-account, and bucket-policy objects on `<t>/<bucket>`;
- **Kubernetes API** — generated NetworkPolicy/RBAC objects; and
- **Postgres** — database roles and grants for the tenant's optional database.

Every provider output is resource-bearing. Keycloak and Postgres have distinct schema/index/WAL projections;
Vault has persisted versions and Raft logs/snapshots; Pulsar has ZooKeeper entries and transaction
logs/snapshots; MinIO has dynamic storage-system metadata under an explicit budget, geometry, and model; and
Kubernetes objects have etcd revisions/Events. MinIO metadata is not an application object and does not add an
arm to `ObjectStoreProducerDemand`. Exact source/provider/key-set equality joins each payload, apply intent,
persistence row, and executor. These capacity shapes are owned by
[resource_capacity_doctrine.md §5.1](./resource_capacity_doctrine.md#51-durable-demand-is-logical-first-physical-only-after-geometry).

### 5.1 The transaction is tenant-qualified, exhaustive, and may become empty

Every global identity is qualified: `(TenantId, outputId)`, `(TenantId, actionId)`, `(TenantId, executorId)`,
and `(TenantId, minioMetadataId)`. The nested `TenantPolicySourceIdentity.tenant` must equal the outer key. This
is not cosmetic namespacing: it prevents equal-cardinality maps belonging to two tenants from authenticating a
swap.

The live planner consumes a possibly empty desired `Map TenantId TenantPolicyDerivation` and a read-only
observed whole-deployment inventory. Its domain is exactly `keys desired ∪ keys observed`; each tenant row has
optional desired state. An observed-only tenant therefore produces authenticated deletes, deletion of the final
tenant is representable, and empty desired plus empty observed is the exact no-op. Observed output records retain
tenant/source, provider, canonical digest, target, action, and executor provenance, so absence from desired can
never authorize deletion by itself.

Observed execution is one target-keyed map for the whole deployment, outside per-tenant state. Tenant-qualified
actions point into it. Binding resolves abstract attachments and coalesces complete execution-resource deltas by
resolved `ExecutionUnitId` across every tenant. A shared base is replaced once after all deltas are summed; a
dedicated target is unique. Per-tenant copies of an observed executor, uncoalesced deltas, and a repeated base
debit are invalid.

### 5.2 Provider targets and MinIO physical accounting are transition state

Each provider action carries optional old and desired targets. Target changes retain a map of **both** old and
new Keycloak databases, Vault backings, Pulsar metadata stores, MinIO `(store,budget,geometry,model)` tuples,
Kubernetes cluster/namespace/etcd models, and Postgres cluster/database/schema/models, together with their
executor epochs and failure/rollback residents. Cleanup may release the old target only after provider readback
proves cutover or authenticated delete absence.

MinIO dynamic entries are tenant-qualified and grouped globally by `(store,budget,geometry,model)`, including
concurrent old and new groups. Only a retained MinIO backing is legal; `ProviderObjectQuota` needs another supply
arm. One physical fold per store adds `metadataReservePerDrive` once per concurrently resident store and every
dynamic group once. Planned and observed metadata models must match, and readback separates static reserve from
dynamic metadata per drive. Static-per-tenant, dynamic zero/double, split-group, and model-mismatch shapes cannot
produce a witness.

### 5.3 Only sealed actions may touch providers

The seal produces private provider-indexed `ProvisionedTenantPolicyAction`s, not only capacity witnesses. Each
action contains tenant/source, canonical payload/digest, operation, old and desired target, exact persistence
high-water, a provisioned executor reference, failure/rollback retention, and a cleanup predicate. A
provider-specific enactor accepts only its matching action paired with a fresh fingerprint-equal
`ValidatedLiveTarget`; it cannot accept `TenantSpec`, `TenantPolicyDerivation`, or a binder-stage target.

Read-only observers and provider readback normalize exact source, payload, provider target/version, persistence
components, executor assignment, and cleanup. `NoOp` requires identity/source/provider/target/content-digest
equality; equal bytes or a provider version alone never establish content equality. Create/replace/delete retain
old, new, failed-action, rollback, and execution capacity until action readback and old-target cleanup succeed.
No caller-authored prior `Provisioned*` value is transition input.

Phase 23 implements and gates provider **administrative** apply/readback for all six arms. For Pulsar this means
tenant/namespace/ACL state only. The authenticated native-client produce/consume round trip belongs to Phase 24,
after `amoebius-pulsar` exists; Phase 23 must record that data-path check as unverified rather than inferring it
from administrative convergence.

There is no DSL surface with which to hand-author a Vault policy, a Pulsar ACL, or an SQL grant — precisely as there is none for a NetworkPolicy. A hand-authored, un-derived provider grant is the RBAC face of the derive-don't-author discipline catalogued for NetworkPolicies and tolerations ([illegal_state_catalog.md §4.4](../illegal_state/illegal_state_techniques.md#44-ownership-indices--single-owner-ssot-structurally), [§3.22](../illegal_state/illegal_state_capacity.md#322-a-hand-authored-un-derived-toleration)); a *cross-tenant* binding is foreclosed as a cross-tenant reference ([§3.8](../illegal_state/illegal_state_security.md#38-cross-tenant-references-and-literal-secrets), technique [§4.2](../illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)).

### 5.4 Cross-tenant sharing is an append-only, revocable capability edge

Isolation forecloses an *accidental* cross-tenant reference, not a *deliberate* one. A tenant that intends to share a resource with another does so through exactly one sanctioned shape, and that shape is **not** a re-tag. There is no `Ref t1 a → Ref t2 a` and no ownership transfer ([§4](#4-the-typed-shapes-tenantspec--userspec--rolebinding), [illegal_state_catalog.md §3.8](../illegal_state/illegal_state_security.md#38-cross-tenant-references-and-literal-secrets)): the shared resource stays owned by, and tagged to, its minting tenant, and its single-owner index is byte-stable.

Sharing is instead an **explicit capability grant** — the capability-as-a-held-token mechanism of [illegal_state_catalog.md §4.2](../illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable). Tenant `t1` grants `t2` a capability scoped to a specific `Ref t1 r` with a specific `List Capability`, recorded as an **append-only, revocable edge** in the tenant→role graph: the grant is additive (a new edge, never a mutation of the owner index), and a revocation is a further append (a revoke entry, never a byte-rewrite of history). The derivation of [§5](#5-rbac-is-derived-never-authored) includes the corresponding cross-realm provider grant and its persistence demand from that edge — still derived, never hand-authored — and a revoked edge removes both from the next provisioned reconcile. The append-only migration machinery that realizes such an edge without ever representing an owner change or a data destruction is owned by [inforcespec_migration_doctrine.md](./inforcespec_migration_doctrine.md); this doctrine owns only that a cross-tenant grant is a capability edge over a fixed owner, never a re-tag.

## 6. The tenant-admin surface reduces to a scope-narrowed admin mutation

A tenant administrator creates tenants, users, and role bindings through the *same* admin control plane that the operator drives — never through raw SQL or a raw provider grant. Each administrative action (create tenant, create user, bind role) is a typed operation that **emits a well-typed Dhall fragment** (`TenantSpec` / `UserSpec` / `RoleBinding t`) and submits it as a **scope-narrowed `dhall update`** to the singleton admin REST ([bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api)). The fragment faces both structural gates of [dsl_doctrine.md §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract), then the whole-deployment tenant plan is rebound and reprovisioned before any effect. A capacity- or target-incompatible update returns `Left` and cannot construct the opaque `ProvisionedSpec`; secrets remain names throughout.

The scoping is the same projection type that bounds a child cluster: a tenant-admin's action is typed `TenantSpec t` and can only append to or modify `project(spec, t)`. Because `Ref t1 a → Ref t2 a` has no constructor, a tenant-admin's mutation **structurally cannot touch another tenant's or the cluster's subtree**. This is the multi-tenant generalization of the single-operator rule that the cluster is driven only through the singleton admin REST: the root operator's `dhall update` mutates the forest; a tenant-admin's scope-narrowed `dhall update` mutates only its own `TenantSpec t`.

A browser front end (a tenancy-administration single-page app) is a *client* of this surface, not a separate doctrine: it renders the typed operations above and submits their fragments through the admin REST. It is distinct from the Phase-13 composition of single-page apps *as deployed workloads* ([../../DEVELOPMENT_PLAN/phase_13_spa_composition_representational.md](../../DEVELOPMENT_PLAN/phase_13_spa_composition_representational.md)); the two share the term "SPA" and nothing else.

**Reach, though, is not the operator's private channel.** The operator's admin NodePort is node-local and never wild ([bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api), the admin-plane reach class); a tenant-admin — and its SPA — is a *remote* principal, so it reaches this surface as an **authenticated, Keycloak-fronted client of the wild edge** ([platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)), whose scope-narrowed `dhall update` is mediated to the singleton by an in-cluster tenant-admin service — **never** by exposing the operator's node-local admin NodePort to the wild. "The *same* admin control plane" therefore means the same typed `dhall update` semantics and the same two DSL gates, **not** the same transport: the operator's reach is private/node-local, the tenant-admin's is Keycloak-authenticated wild ingress narrowed to `project(spec, t)`.

## 7. Two isolation layers, and the honest limit

Cross-tenant isolation holds at two layers, and the strength of each is stated precisely:

- **Type layer.** `Ref t` / `RoleBinding t` cannot name a foreign `t`, and `project : RootInForceSpec → TenantId → TenantSpec t` cannot yield a sibling tenant. Where `t` is a static phantom in the decoded Haskell value this is **type-foreclosed** (Gate 1); where it degrades to a value-level `TenantId` that a total fold checks — every `RoleBinding`'s resource-tenant unifies with its enclosing `TenantSpec`'s tenant — it is **decode-foreclosed** (Gate 2). Dhall has no dependent types, so the statically-distinct index lives in the decode target, not the `.dhall` text; this split is stated rather than overclaimed, per [illegal_state_catalog.md §6](../illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force).
- **Cryptographic / runtime layer.** A per-tenant Transit key and Vault policy, broker-enforced Pulsar namespace
  ACLs, a MinIO bucket policy, generated Kubernetes RBAC/NetworkPolicy, Postgres roles/grants, and Keycloak realm
  isolation at the ext-authz edge mean that even a fabricated cross-tenant reference (impossible by type) is
  refused by the runtime resource. The per-tenant Transit key is the tenant-axis application of the per-child
  key mechanism owned by [vault_pki_doctrine.md §6](./vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes).

**The honest limit.** The type layer proves *the spec names no foreign tenant*; it does **not** prove *the
`deriveTenantPolicies` result of [§5](#5-rbac-is-derived-never-authored) is faithful* — a derivation bug could
over-grant. That residue is **runtime-checked**, not foreclosed. In the default shared-service model, tenants
share one Vault, one broker set, one MinIO, and one Kubernetes control plane, so isolation rests on per-tenant
*policy within shared services*: a broker/MinIO/Vault/Kubernetes privilege-escalation bug crosses tenants there.
The **hardening dial** is to promote a
hostile or regulated tenant onto its **own child cluster** — the same `TenantId`, now with its own Vault, PKI
intermediate, and Transit root, so isolation rests on separate cryptographic roots. Because tenant identity is
application logic and isolation shape is a deployment rule ([app_vs_deployment_doctrine.md §1](./app_vs_deployment_doctrine.md#1-two-surfaces-one-app-written-once)), this promotion is a `RolloutPhase` ([release_lifecycle_doctrine.md §5](./release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply)) that moves the tenant's buckets, topics, and database under the same `TenantId` into a new child cluster, with **no change to the tenant/user/RBAC surface** above.

## 8. What this doctrine owns, and what it defers

This doctrine owns the tenant axis: the first-class `TenantId`, the `TenantSpec`/`UserSpec`/`RoleBinding t`
types, the cross-tenant capability-edge sharing shape, the derive-don't-author rule, tenant qualification and
desired∪observed lifecycle of the six-provider transaction, sealed-action authority, and the tenant-admin
scoped-mutation surface. It defers, and cross-references rather than restates:

- the phantom-tag *mechanism* and the cross-tenant-reference catalog entry → [illegal_state_catalog.md §3.8](../illegal_state/illegal_state_security.md#38-cross-tenant-references-and-literal-secrets), [§4.2](../illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable);
- the per-app namespace / `<app>/<bucket>` binding it extends → [service_capability_doctrine.md §4](./service_capability_doctrine.md#4-capability--provider--shape-the-binding);
- per-child Transit isolation and the `SecretRef` contract → [vault_pki_doctrine.md §6](./vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes), [§3](./vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value);
- the `dhall update` admin endpoint the tenant-admin surface targets → [bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api);
- the `InForceSpec` projection it mirrors → [dsl_doctrine.md §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract);
- the append-only migration diff that realizes a capability edge or a tenant promotion without representing destruction → [inforcespec_migration_doctrine.md](./inforcespec_migration_doctrine.md), [release_lifecycle_doctrine.md §5](./release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply), [storage_lifecycle_doctrine.md §7](./storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation).

## 9. Planning ownership

This document is normative tenancy doctrine only: it states the target shape of the tenant axis and every statement in it is design intent, specified before implementation. Delivery sequencing, completion status, validation gates, and remaining work are owned by [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md) and by the tenancy phase it schedules; this doc never maintains a competing status ledger and links back for status.

Several choices are open and owned by the plan, not fixed here: whether a Vault-namespace-per-tenant (an Enterprise feature) or a per-tenant policy-and-prefix on OSS Vault backs the tenant's secret boundary ([§3](#3-what-a-tenant-is)); whether authentication is realm-per-tenant or one realm with per-tenant client scopes ([§4](#4-the-typed-shapes-tenantspec--userspec--rolebinding)); and exactly which cross-tenant invariants are type-foreclosed (a static phantom `t` in the decoded Haskell IR) versus decode-foreclosed (a value-level `TenantId` fold), stated honestly because Dhall lacks dependent types ([§7](#7-two-isolation-layers-and-the-honest-limit)).

Per [documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline), no statement here is a proven amoebius result. The service-native tenancy shapes this doctrine composes — Keycloak realms, a per-tenant Vault policy, Pulsar tenant-namespaces, a MinIO bucket policy, Kubernetes RBAC/NetworkPolicy, and Postgres roles/grants — have sibling precedents and are **sibling evidence, not an amoebius result**; amoebius has not built the tenant axis, and this document specifies the typed surface it intends to satisfy.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [DSL Doctrine](./dsl_doctrine.md) — the `InForceSpec` projection and the two illegal-state-unrepresentable gates the tenant surface rides
- [Illegal State Catalog](../illegal_state/illegal_state_catalog.md) — the cross-tenant-reference entry ([§3.8](../illegal_state/illegal_state_security.md#38-cross-tenant-references-and-literal-secrets)) and the capability/phantom-tenant-tag technique ([§4.2](../illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable))
- [Single Logical Data Plane Doctrine](./single_logical_data_plane_doctrine.md) — the two-index `DataPlane (c :: ClusterId) t` this doctrine disambiguates
- [Service Capability Doctrine](./service_capability_doctrine.md) — the per-app `<app>/<bucket>` binding the tenant prefix extends
- [Vault / PKI Doctrine](./vault_pki_doctrine.md) — the `SecretRef`-by-name contract and the per-tenant/per-child Transit key isolation
- [Platform Services Doctrine](./platform_services_doctrine.md) — Keycloak realms, the single wild-ingress ext-authz edge, and the per-consumer Postgres database
- [Pulsar Client Doctrine](./pulsar_client_doctrine.md) — the tenant-namespace topology algebra
- [Bootstrap Sequence Doctrine](./bootstrap_sequence_doctrine.md) — the singleton admin REST the scope-narrowed `dhall update` targets, and the admin-plane reach class
- [InForceSpec Migration Doctrine](./inforcespec_migration_doctrine.md) — cross-tenant sharing as an append-only revocable capability edge, and the diff that realizes a tenant promotion without representing destruction
- [Release Lifecycle Doctrine](./release_lifecycle_doctrine.md) — the `RolloutPlan`/`RolloutPhase` apply that realizes a tenant promotion under the same `TenantId`
- [App vs Deployment Doctrine](./app_vs_deployment_doctrine.md) — tenant identity is application logic; isolation shape is a deployment rule
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
