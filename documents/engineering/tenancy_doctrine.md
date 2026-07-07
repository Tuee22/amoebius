# Multi-Tenancy, Users & RBAC

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/dsl_doctrine.md, documents/engineering/illegal_state_catalog.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/release_lifecycle_doctrine.md
**Generated sections**: none

> **Purpose**: Single source of truth for the amoebius tenant axis — the first-class `TenantId` that is orthogonal to the cluster axis, the `TenantSpec`/`UserSpec`/`RoleBinding` types by which a valid `InForceSpec` cannot name a foreign tenant's resource, the rule that provider RBAC is derived from the tenant→role graph rather than authored, and the tenant-admin surface that reduces to a scope-narrowed admin mutation.

---

## 1. Why this doctrine exists

A multi-tenant workload keeps more than one customer's data on shared platform services, and the load-bearing obligation is isolation: tenant B must never read, share, or destroy tenant A's data, and the guarantee must hold at the layer where a spec is authored, not only at the layer where a policy is enforced. The failure surfaces at **author time** — a spec that names a cross-tenant grant, or hand-writes a provider ACL that over-grants — and at **runtime** — a rendered policy that leaks.

The obvious alternative — model a tenant as an ordinary application record and enforce isolation with hand-authored Vault policies, Pulsar ACLs, and SQL grants — fails because a hand-authored grant is exactly the surface where a cross-tenant reference becomes representable: the author can write down a binding that names another tenant's bucket, and nothing in the type of that binding forbids it. Isolation then rests entirely on review and runtime enforcement, which the amoebius contract ([dsl_doctrine.md §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)) rejects for exactly this class of invariant.

The rule this doctrine states: **a tenant is an immutable `TenantId`, every tenant-scoped datum and role binding is tagged by that id, and provider RBAC is *derived* from the tenant→role graph — never hand-authored.** A `RoleBinding` in tenant `t` has no constructor that names a resource in tenant `t' ≠ t`, and there is no DSL surface with which to write a Vault policy, a Pulsar ACL, or an SQL grant directly.

What it forecloses: a cross-tenant data reference or role binding has no inhabitant in a well-typed spec (the phantom-tag mechanism of [illegal_state_catalog.md §4.2](./illegal_state_catalog.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)), and a hand-authored, un-derived provider grant has no syntax. The residue this doctrine does **not** claim to foreclose — that the *derivation* onto Vault/Pulsar/MinIO/Keycloak is faithful — is stated honestly in [§7](#7-two-isolation-layers-and-the-honest-limit).

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

`TenantId` is **minted once and immutable**, and it travels with the bytes it tags: no migration re-tags a datum from `t1` to `t2` (the data-plane form of the absent `Ref t1 a → Ref t2 a` coercion, owned by [illegal_state_catalog.md §4.2](./illegal_state_catalog.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) and the migration invariants of [release_lifecycle_doctrine.md §5](./release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply)). This immutability is the shared boundary between this doctrine (which owns the tenant/user/RBAC surface) and the storage-migration doctrine (which owns the data invariants that ride on the tag).

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

The isolation is the **absent arms**:

- There is **no constructor `Ref t1 a → Ref t2 a`** ([illegal_state_catalog.md §4.2](./illegal_state_catalog.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)). Inside a `RoleBinding t1`, the only resource-reference constructors in scope produce `Ref t1 _`, so a binding that names another tenant's bucket, topic, or secret has no inhabitant.
- There is **no un-indexed `UserSpec`**. Every user is a `UserSpec t` nested in exactly one `TenantSpec t`'s `users` list, so a user belonging to two tenants cannot be typed.
- The projection `project : RootInForceSpec → TenantId → TenantSpec t` yields **only** tenant `t`'s subtree — the tenant analogue of the `ChildInForceSpec` projection ([dsl_doctrine.md §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)). No field admits a sibling-tenant or cluster-scoped branch.

Authentication is **realm-per-tenant**: each `TenantId` maps to a Keycloak realm; a user authenticates to its own realm; the OIDC/JWT realm claim is enforced at the single Envoy ext-authz edge ([platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)), so a realm-`t1` token cannot satisfy a realm-`t2` route.

Secrets stay names, never values, throughout: `credential` and `transitKey` are `SecretRef`s resolved by the parent/singleton into Vault ([vault_pki_doctrine.md §3](./vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)).

## 5. RBAC is derived, never authored

The typed tenant→role graph is the sole source of truth for access; the concrete provider policies are **derived from it**, never hand-written — the same derive-don't-author discipline as generated NetworkPolicies and taint-derived tolerations. A single total function

    render :: TenantSpec t → [ KeycloakRole | VaultPolicy | PulsarAcl | MinioPolicy | NetworkPolicy ]

emits, for each tenant:

- **Keycloak** realm roles + client scopes + the per-route auth rule;
- **Vault** a per-tenant policy over `secret/tenants/<t>/…` granting each user's service account read on exactly its bound paths ([vault_pki_doctrine.md §9](./vault_pki_doctrine.md#9-in-cluster-consumers-authenticate-to-vault-directly));
- **Pulsar** namespace grants on `persistent://<t>/…` ([pulsar_client_doctrine.md §6](./pulsar_client_doctrine.md#6-the-declarative-topology-algebra));
- **MinIO** a bucket policy on `<t>/<bucket>`.

There is no DSL surface with which to hand-author a Vault policy, a Pulsar ACL, or an SQL grant — precisely as there is none for a NetworkPolicy. A hand-authored, un-derived provider grant is catalogued as unrepresentable at [illegal_state_catalog.md §3.45](./illegal_state_catalog.md#345-a-cross-tenant-or-hand-authored-rbac-binding).

## 6. The tenant-admin surface reduces to a scope-narrowed admin mutation

A tenant administrator creates tenants, users, and role bindings through the *same* admin control plane that the operator drives — never through raw SQL or a raw provider grant. Each administrative action (create tenant, create user, bind role) is a typed operation that **emits a well-typed Dhall fragment** (`TenantSpec` / `UserSpec` / `RoleBinding t`) and submits it as a **scope-narrowed `dhall update`** to the singleton admin REST ([bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api)). The fragment faces both gates of [dsl_doctrine.md §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) before any effect, so *if it decodes, it is deployable*, and secrets remain names.

The scoping is the same projection type that bounds a child cluster: a tenant-admin's action is typed `TenantSpec t` and can only append to or modify `project(spec, t)`. Because `Ref t1 a → Ref t2 a` has no constructor, a tenant-admin's mutation **structurally cannot touch another tenant's or the cluster's subtree**. This is the multi-tenant generalization of the single-operator rule that the cluster is driven only through the singleton admin REST: the root operator's `dhall update` mutates the forest; a tenant-admin's scope-narrowed `dhall update` mutates only its own `TenantSpec t`.

A browser front end (a tenancy-administration single-page app) is a *client* of this surface, not a separate doctrine: it renders the typed operations above and submits their fragments through the admin REST. It is distinct from the Phase-12 composition of single-page apps *as deployed workloads* ([../../DEVELOPMENT_PLAN/phase_12_spa_composition.md](../../DEVELOPMENT_PLAN/phase_12_spa_composition.md)); the two share the term "SPA" and nothing else.

**Reach, though, is not the operator's private channel.** The operator's admin NodePort is node-local and never wild ([bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api), the admin-plane reach class); a tenant-admin — and its SPA — is a *remote* principal, so it reaches this surface as an **authenticated, Keycloak-fronted client of the wild edge** ([platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)), whose scope-narrowed `dhall update` is mediated to the singleton by an in-cluster tenant-admin service — **never** by exposing the operator's node-local admin NodePort to the wild. "The *same* admin control plane" therefore means the same typed `dhall update` semantics and the same two DSL gates, **not** the same transport: the operator's reach is private/node-local, the tenant-admin's is Keycloak-authenticated wild ingress narrowed to `project(spec, t)`.

## 7. Two isolation layers, and the honest limit

Cross-tenant isolation holds at two layers, and the strength of each is stated precisely:

- **Type layer.** `Ref t` / `RoleBinding t` cannot name a foreign `t`, and `project : RootInForceSpec → TenantId → TenantSpec t` cannot yield a sibling tenant. Where `t` is a static phantom in the decoded Haskell value this is **type-foreclosed** (Gate 1); where it degrades to a value-level `TenantId` that a total fold checks — every `RoleBinding`'s resource-tenant unifies with its enclosing `TenantSpec`'s tenant — it is **decode-foreclosed** (Gate 2). Dhall has no dependent types, so the statically-distinct index lives in the decode target, not the `.dhall` text; this split is stated rather than overclaimed, per [illegal_state_catalog.md §6](./illegal_state_catalog.md#6-three-layers-of-foreclosure-and-the-honesty-they-force).
- **Cryptographic / runtime layer.** A per-tenant Transit key, a per-tenant Vault policy, broker-enforced Pulsar namespace ACLs, a MinIO bucket policy, and Keycloak realm isolation at the ext-authz edge mean that even a fabricated cross-tenant reference (impossible by type) is refused by the runtime resource.

**The honest limit.** The type layer proves *the spec names no foreign tenant*; it does **not** prove *the `render` derivation of [§5](#5-rbac-is-derived-never-authored) is faithful* — a renderer bug could over-grant. That residue is **runtime-checked**, not foreclosed. In the default shared-service model, tenants share one Vault, one broker set, and one MinIO, so isolation rests on per-tenant *policy within shared services*: a broker/MinIO/Vault privilege-escalation bug crosses tenants there. The **hardening dial** is to promote a hostile or regulated tenant onto its **own child cluster** — the same `TenantId`, now with its own Vault, PKI intermediate, and Transit root, so isolation rests on separate cryptographic roots. Because tenant identity is application logic and isolation shape is a deployment rule ([app_vs_deployment_doctrine.md §1](./app_vs_deployment_doctrine.md#1-two-surfaces-one-app-written-once)), this promotion is a `RolloutPhase` ([release_lifecycle_doctrine.md §5](./release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply)) that moves the tenant's buckets, topics, and database under the same `TenantId` into a new child cluster, with **no change to the tenant/user/RBAC surface** above.

## 8. What this doctrine owns, and what it defers

This doctrine owns the tenant axis: the first-class `TenantId`, the `TenantSpec`/`UserSpec`/`RoleBinding t` types, the derive-don't-author RBAC rule, and the tenant-admin scoped-mutation surface. It defers, and cross-references rather than restates:

- the phantom-tag *mechanism* → [illegal_state_catalog.md §4.2](./illegal_state_catalog.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable);
- the per-app namespace / `<app>/<bucket>` binding it extends → [service_capability_doctrine.md §4](./service_capability_doctrine.md#4-capability--provider--shape-the-binding);
- per-child Transit isolation and the `SecretRef` contract → [vault_pki_doctrine.md §6](./vault_pki_doctrine.md#6-parentchild-unseal-two-sanctioned-modes), [§3](./vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value);
- the `dhall update` admin endpoint the tenant-admin surface targets → [bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api);
- the `InForceSpec` projection it mirrors → [dsl_doctrine.md §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract);
- the data-migration invariants that ride on the immutable `TenantId` → [release_lifecycle_doctrine.md §5](./release_lifecycle_doctrine.md#5-rolloutplan--rolloutphase-the-readiness-gated-apply), [storage_lifecycle_doctrine.md §7](./storage_lifecycle_doctrine.md#7-deleting-durable-data-is-forbidden-under-normal-operation).

> **Honesty.** This doctrine is Phase-N design intent, specified before implementation like the rest of the suite. The status of a Vault-namespace-per-tenant (an Enterprise feature) versus a per-tenant policy-and-prefix on OSS Vault, and the choice of realm-per-tenant versus one realm with per-tenant client scopes, are open and owned by the tenancy phase in [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md); this document specifies the typed surface, not a tested result.
