# Phase 21: App tenancy + `TenantSpec`

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_20_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_22_pulsar_client.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Realize an app's tenant slice live — its own namespace, the `<app>/<bucket>` ObjectStore prefix,
> and a one-member in-namespace `Sql` database — behind the `TenantSpec`/`UserSpec`/`RoleBinding` typed surface
> whose absent arms make a spec that names a foreign tenant's resource unrepresentable.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 20 gate (the live DSL deploy
via the Deployment-`replicas=1` control-plane singleton, no election) and runs on the **linux-cpu** substrate in
**Register 3** — live infrastructure: the single-node `kind` cluster whose platform stack, root Vault, and
Keycloak-owned edge were stood up in Phases 17–20. The tenant-axis type discipline it rests on — the phantom
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
is **derived** from the tenant→role graph — a single total `render` emits the per-tenant Vault policy, MinIO
bucket policy, Pulsar namespace grant, and Keycloak realm — never hand-authored. Secrets stay names throughout:
`credential` and `transitKey` are `SecretRef`s resolved in-cluster via the Phase-17 built-in Vault client.

What this phase deliberately does **not** do: the tenant-admin scope-narrowed `dhall update` surface and its
Keycloak-fronted browser client ([`tenancy_doctrine.md §6`](../documents/engineering/tenancy_doctrine.md)), the
promotion of a hostile or regulated tenant onto its **own child cluster** (the cryptographic-isolation hardening
dial, owned by the amoebic-spawning/federation phases), and any claim that the derived `render` is faithful
(that residue is runtime-checked, per the honest limit) are all out of scope here. Only the single root
cluster's app-tenant projection and its author-time no-foreign-tenant foreclosure are gated in this phase.

**Substrate:** linux-cpu — the whole gate runs on the single-node `kind` cluster from Phases 17–20; no apple,
linux-cuda, or windows substrate is touched.

**Register:** 3 — live infrastructure (§K).

**Gate:** on a single-node linux-cpu cluster a `.dhall` app spec is decoded and reconciled by the
Deployment-`replicas=1` singleton (no election) so the app receives its own **namespace**, its declared
`ObjectStore` buckets rendered under the **`<app>/<bucket>`** MinIO prefix, and a one-member in-namespace Patroni
**`Sql`** database, all converging to ready with a leak-free teardown; and, as a live regression guard, a
well-typed fixture whose `RoleBinding` names a **foreign tenant's** resource **fails at Gate 1 / Gate 2 before
any binary acts** — a **Register-3** live-infrastructure check (the author-time foreclosure itself was already
proven in-process in the pre-cluster band).

## Doctrine adopted

- [`tenancy_doctrine.md §4`](../documents/engineering/tenancy_doctrine.md) — *the typed shapes:
  `TenantSpec` / `UserSpec` / `RoleBinding`*: the three phantom-tagged types nested in the `InForceSpec`, whose
  isolation is the **absent arms** — no `Ref t1 a → Ref t2 a` constructor, no un-indexed `UserSpec`, and a
  `project` that yields only tenant `t`'s subtree — so a cross-tenant reference has no inhabitant in a well-typed
  spec. This phase decodes that surface and reconciles its data slice live.
- [`tenancy_doctrine.md §5`](../documents/engineering/tenancy_doctrine.md#5-rbac-is-derived-never-authored) —
  *RBAC is derived, never authored*: the typed tenant→role graph is the sole source of truth, and a single total
  `render :: TenantSpec t → [ KeycloakRole | VaultPolicy | PulsarAcl | MinioPolicy | NetworkPolicy ]` emits the
  concrete provider policies — the same derive-don't-author discipline as generated NetworkPolicies and
  taint-derived tolerations; there is no DSL surface with which to hand-author a Vault policy, a Pulsar ACL, or an
  SQL grant.
- [`tenancy_doctrine.md §3`](../documents/engineering/tenancy_doctrine.md#3-what-a-tenant-is) — *what a tenant
  is*: the immutable `TenantId` bundles a Keycloak realm, a Vault policy over `secret/tenants/<t>/…`, Pulsar
  tenant-namespaces, the `<t>/<bucket>` MinIO prefix (extending the per-app `<app>/<bucket>` binding — for this
  single-root app-tenancy projection the app *is* its own data-tenant, so `<t>` is the app's tenant id and the
  `<t>/<bucket>` policy scopes exactly the `<app>/<bucket>` bytes Sprint 21.1 stores), and an
  optional co-located Postgres database — minted once and travelling with the bytes it tags, so no migration
  re-tags a datum from `t1` to `t2`.
- [`tenancy_doctrine.md §7`](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit)
  — *two isolation layers, and the honest limit*: the type layer proves *the spec names no foreign tenant* (and
  where `t` degrades to a value-level id, a total decode-time fold checks it); it does **not** prove the `render`
  derivation is faithful — that residue is runtime-checked, not foreclosed, and is stated rather than overclaimed.
- [`service_capability_doctrine.md §4`](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding)
  and [`§2`](../documents/engineering/service_capability_doctrine.md#2-the-capability-set) — *capability →
  provider → shape: the binding* and *the capability set*: the app names an abstract `ObjectStore` / `Sql`
  capability (never a product — `minio` has no syntax), and the deployment rules bind the canonical provider at a
  per-cluster shape; this phase renders the bound `ObjectStore` as the `<app>/<bucket>` MinIO prefix and the
  bound `Sql` as a one-member Patroni cluster.
- [`illegal_state_catalog.md §4.2`](../documents/illegal_state/illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
  and [`§3.45`](../documents/illegal_state/illegal_state_security.md#345-a-cross-tenant-or-hand-authored-rbac-binding)
  — *capability and phantom tenant tags* and *a cross-tenant or hand-authored RBAC binding*: the phantom-tag
  mechanism that makes cross-tenant refs uninhabitable, and the catalog entry that makes a hand-authored,
  un-derived provider grant have no syntax — both **built and proven in-process in the pre-cluster band**
  (the Phase-6 corpus); this phase re-runs their negatives against the live deploy path as a regression guard.
- [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton)
  — *the control-plane singleton*: the tenant projection is reconciled by the Deployment-`replicas=1` singleton
  whose single-instance guarantee is **delegated to k8s/etcd (a `Lease` only if a hard lock is needed)** — there
  is no election here; the singleton is stateless, its durable state exclusively the Vault-enveloped MinIO bucket.
- [`vault_pki_doctrine.md §3`](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)
  — *the `SecretRef` contract, a name never a value*: a tenant's `credential` and `transitKey`, and each
  provider credential, are carried as typed `SecretRef` names resolved in-cluster by the Phase-17 built-in Vault
  client — never a literal in Dhall.

## Sprints

## Sprint 21.1: The app data-tenant projection — namespace + `<app>/<bucket>` ObjectStore + in-namespace `Sql` 📋

**Status**: Planned
**Implementation**: `src/Amoebius/App/Tenancy.hs` (the per-app namespace + tenant-tagged resource projection: the
`<app>/<bucket>` `ObjectStore` resources against the canonical MinIO provider, and a one-member in-namespace
Patroni `Sql` instance) — target path, not yet built.
**Blocked by**: Phase 20 gate (the live DSL deploy via the `replicas=1` singleton — the deploy path this
projection is reconciled onto); Phase 18 (the standard MinIO + Patroni platform services this binds to, an
external earlier-phase prereq).
**Independent Validation**: decoding a trivial app `.dhall` yields exactly one namespace, the declared
`ObjectStore` buckets each rendered under the `<app>/<bucket>` MinIO prefix, and one one-member Patroni `Sql`
cluster in that namespace; the `replicas=1` singleton reconciles all three to ready and a re-run is a no-op; no
bare `postgres` Pod and no cross-namespace bucket is produced.
**Docs to update**: `documents/engineering/tenancy_doctrine.md`, `documents/engineering/service_capability_doctrine.md`,
`documents/engineering/app_vs_deployment_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

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
  shape; an in-namespace `Sql` database as a **one-member Patroni cluster** (the honest single-node shape, never
  a bare `postgres` Pod).
- Provider credentials carried as typed `SecretRef` names (never literals), resolved in-cluster via the Phase-17
  built-in Vault client (mechanism owned by the Vault/PKI doctrine, not restated here).

### Validation
1. A trivial app `.dhall` decodes and the singleton reconciles its namespace, `<app>/<bucket>` `ObjectStore`
   bucket, and one-member Patroni `Sql` database to ready on the linux-cpu cluster; a re-run is a no-op.
2. The app-surface bytes are unchanged when the bound shape changes (single-node vs distributed), confirming the
   app travels and only the binding varies; the `Sql` is a Patroni cluster and no bare `postgres` Pod appears.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 21.2: The `TenantSpec`/`UserSpec`/`RoleBinding` typed surface + no-foreign-tenant foreclosure 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/Tenant.dhall` (the `TenantSpec` / `UserSpec` / `RoleBinding` record + union
types with only tenant-`t` reference constructors); `src/Amoebius/Tenancy/Types.hs` (the phantom-tagged
`TenantId` / `TenantSpec t` / `UserSpec t` / `RoleBinding t` IR); `src/Amoebius/Tenancy/Project.hs` (the total
`project : RootInForceSpec → TenantId → TenantSpec t` fold and the value-level tenant-unification check) —
target paths, not yet built.
**Blocked by**: Sprint 21.1 (the tenant-tagged data projection these bindings reference); the Phase-6
illegal-state corpus (the phantom-tag `Ref t` mechanism + the cross-tenant-ref negative, proven in-process — an
external earlier-phase prereq).
**Independent Validation**: decoding a `TenantSpec t` fixture yields only tenant `t`'s subtree; a well-typed
fixture whose `RoleBinding` names a `Ref t' (t' ≠ t)` resource returns a structured decode `Left` (Gate 2),
or fails `dhall type` where the tag is a static phantom (Gate 1) — the same negative fixture proven in-process
in the pre-cluster band, here re-run against the live decode path; a user belonging to two tenants cannot be
typed.
**Docs to update**: `documents/engineering/tenancy_doctrine.md`, `documents/illegal_state/illegal_state_catalog.md`
(per-entry layer reconciliation for §4.2), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`tenancy_doctrine.md §4`](../documents/engineering/tenancy_doctrine.md) (the typed shapes) and
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
2. A well-typed fixture naming a foreign tenant's bucket/topic/secret in a `RoleBinding` is rejected at Gate 1 or
   Gate 2 (annotated with its layer), and an attempt to place one user in two tenants does not type — the suite
   is red if any such fixture decodes.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 21.3: Derived provider RBAC — Keycloak / Vault / Pulsar / MinIO policies from the tenant→role graph 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Tenancy/Rbac.hs` (the total
`render :: TenantSpec t → [ KeycloakRole | VaultPolicy | PulsarAcl | MinioPolicy | NetworkPolicy ]` derivation)
— target path, not yet built.
**Blocked by**: Sprint 21.1, Sprint 21.2; Phase 17 (the root Vault + built-in client that hosts the derived
per-tenant policies) and Phase 19 (the Keycloak-owned edge whose realms these roles populate) — external
earlier-phase prereqs.
**Independent Validation**: the total `render` emits, for a two-tenant fixture, a per-tenant Vault policy over
`secret/tenants/<t>/…`, a MinIO bucket policy on `<t>/<bucket>` (which — the app being its own data-tenant —
guards the same path the Sprint-21.1 store keys under as `<app>/<bucket>`), a Pulsar namespace grant on
`persistent://<t>/…`, and a Keycloak realm role set; a live cross-tenant read is refused by the derived provider
policy; there is **no** DSL surface with which to hand-author any of these grants (a hand-authored grant has no
syntax, catalog §3.45).
**Docs to update**: `documents/engineering/tenancy_doctrine.md`, `documents/engineering/vault_pki_doctrine.md`,
`documents/engineering/platform_services_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`tenancy_doctrine.md §5`](../documents/engineering/tenancy_doctrine.md#5-rbac-is-derived-never-authored)
and [`illegal_state_catalog.md §3.45`](../documents/illegal_state/illegal_state_security.md#345-a-cross-tenant-or-hand-authored-rbac-binding):
derive every concrete provider policy from the typed tenant→role graph with one total function, and confirm the
runtime resources refuse a cross-tenant access — the cryptographic/runtime isolation layer that backs the
author-time foreclosure of Sprint 21.2.

### Deliverables
- The total `render :: TenantSpec t → [KeycloakRole | VaultPolicy | PulsarAcl | MinioPolicy | NetworkPolicy]`
  emitting, per tenant: Keycloak realm roles + the per-route auth rule; a Vault policy over
  `secret/tenants/<t>/…` granting each user's service account read on exactly its bound paths; Pulsar namespace
  grants on `persistent://<t>/…`; a MinIO bucket policy on `<t>/<bucket>`.
- The **derive-don't-author** enforcement: no DSL surface hand-authors a Vault policy, Pulsar ACL, or SQL grant —
  precisely as none exists for a NetworkPolicy — so an un-derived provider grant has no syntax (catalog §3.45).
- The **honest limit** recorded ([`tenancy_doctrine.md §7`](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit)):
  this sprint does **not** prove the `render` derivation is faithful; a renderer over-grant is a runtime-checked
  residue, not a foreclosed one, and the default shared-service model's tenant isolation rests on per-tenant
  policy within shared Vault/broker/MinIO — the own-child-cluster hardening dial stays deferred to federation.

### Validation
1. `render` over a two-tenant fixture emits the four provider policy sets plus the derived NetworkPolicy, each
   scoped to its own `<t>`; an assertion confirms no arm of the app/tenant surface can hand-author any of them.
2. On the live cluster a tenant-`t1` principal is **refused** a read of a `<t2>` bucket / topic / secret path by
   the derived provider policy; the residue (derivation fidelity) is recorded as runtime-checked, never marked
   green as a type result.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 21.4: Phase gate harness — deploy-a-tenant-app + reject-the-foreign-tenant-spec 📋

**Status**: Planned
**Implementation**: `dhall/examples/{tenant_app,illegal_cross_tenant_ref,illegal_cross_tenant_user,
illegal_handauthored_grant}.dhall` (gate fixtures); `test/integration/Phase21Gate.hs` (linux-cpu spin-up /
reconcile / teardown + negative decode assertions + the Register-3 ledger) — target paths, not yet built.
**Blocked by**: Sprint 21.1, Sprint 21.2, Sprint 21.3.
**Independent Validation**: the harness deploys a tenant app from one `.dhall` on linux-cpu — the app gets its
namespace, `<app>/<bucket>` `ObjectStore`, and one-member in-namespace Patroni `Sql`, reconciled to ready by the
`replicas=1` singleton — then tears down leak-free (postflight sweep empty); it then asserts each
deliberately-illegal fixture (a foreign-tenant `Ref`, a two-tenant user, a hand-authored provider grant) fails
to type-check or decode; the run emits a Register-3 proven/tested/assumed ledger.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (flip the Phase-21 status when the gate passes),
`DEVELOPMENT_PLAN/substrates.md` (the Phase-21 linux-cpu gate row), `documents/engineering/testing_doctrine.md`,
`documents/engineering/tenancy_doctrine.md`.

### Objective
Adopt [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)
and [`tenancy_doctrine.md §4`](../documents/engineering/tenancy_doctrine.md): assemble the phase's single **live**
acceptance gate — one `.dhall` deploys a tenant app whose namespace, `<app>/<bucket>` `ObjectStore`, and
in-namespace `Sql` the `replicas=1` singleton reconciles to ready and tears down leak-free; and, as a regression
guard, the pre-cluster no-foreign-tenant corpus is re-run so a spec naming a foreign tenant's resource still
fails before any binary acts.

### Deliverables
- A positive gate `.dhall` (`tenant_app`) composing the platform spec + a tenant app (Sprints 21.1–21.3) that
  the singleton reconciles to ready and then tears down leak-free, authored as a test-topology `.dhall` with a
  teardown obligation and a postflight sweep.
- Negative gate fixtures — re-run as a live regression guard — `illegal_cross_tenant_ref` (a `RoleBinding`
  naming a `Ref t' ≠ t` resource, catalog §4.2), `illegal_cross_tenant_user` (a `UserSpec` in two tenants), and
  `illegal_handauthored_grant` (a hand-authored provider policy, catalog §3.45) — each asserted to fail at
  Gate 1 or Gate 2, annotated with its foreclosure layer.
- A **Register-3** proven/tested/assumed ledger recording the live-realization result (namespace + bucket + Sql
  converged, cross-tenant read refused by the derived policy) and explicitly marking the deferred surfaces — the
  tenant-admin scope-narrowed `dhall update` surface, the own-child-cluster hardening dial, and the `render`
  derivation-fidelity residue — as UNVERIFIED, never green.

### Validation
1. The positive `.dhall` brings the tenant app up on the linux-cpu cluster, its `<app>/<bucket>` `ObjectStore`
   and in-namespace `Sql` are reachable, and teardown leaves no leaked resource (postflight sweep empty).
2. Every illegal `.dhall` fixture is rejected before any binary acts; the Register-3 ledger is present and
   honestly classifies each foreclosure and each deferred residue (no runtime-checked claim reported as proven).

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
  the per-tenant Vault policy / MinIO bucket policy / Pulsar namespace grant / Keycloak realm as derived, not
  hand-authored, outputs of the tenancy `render`.
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (the
  tenant-admin surface, child-cluster promotion, and derivation fidelity UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-21 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 21's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/App/Tenancy.hs` and
  `src/Amoebius/Tenancy/{Types,Project,Rbac}.hs` (with `dhall/amoebius/Tenant.dhall`) as Phase-21 design-first
  rows against the component inventory.

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
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — the phantom-tenant-tag mechanism
  (§4.2) and the hand-authored-grant entry (§3.45) re-run as a live guard
- [Vault, PKI & Secret Injection](../documents/engineering/vault_pki_doctrine.md) — the `SecretRef` contract for
  tenant credentials and the derived per-tenant Vault policy
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — the Deployment-`replicas=1`
  control-plane singleton (no election) that reconciles this projection
- [phase_20](phase_20_live_dsl_singleton.md) — the live DSL deploy via the `replicas=1` singleton this phase builds on
