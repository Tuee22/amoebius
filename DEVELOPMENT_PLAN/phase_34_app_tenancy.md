# Phase 34: Tenant/provider provisioning

> **Purpose**: Materialize one checked tenant graph as tenant-qualified control-plane objects in every required
> provider, and establish by independent provider readback that no arm was omitted, collapsed, or hand-authored.
> **Read this if**: phase 34 is next in the queue, or a later phase depends on what its gate establishes.

Phase 34 delivers the tenant/provider provisioning; its design is owned by [tenancy_doctrine.md](../documents/engineering/tenancy_doctrine.md), [service_capability_doctrine.md](../documents/engineering/service_capability_doctrine.md), [platform_services_doctrine.md](../documents/engineering/platform_services_doctrine.md), and the plan for reaching it is owned here.
Register 3, live, on the `linux-cpu` substrate.
Validated 2026-08-10 with `python3 tools/phase34_gate.py --reuse-fresh-live`;
ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_33_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_35_pulsar_client.md, DEVELOPMENT_PLAN/phase_36_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — one sealed provider transaction](#resource-provision--one-sealed-provider-transaction)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 34.1: Derive, apply, and externally read back tenant provider policy ⏸️](#sprint-341-derive-apply-and-externally-read-back-tenant-provider-policy-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish external evidence without changing an authored path.

**Invalidated historical record:**

✅ **Done.** The checked two-tenant graph is derived into a sealed, closed six-provider transaction and
live-applied to Keycloak, Vault, Pulsar, MinIO, Kubernetes API, and Postgres. Distinct provider-native or
scoped ServiceAccount observers recovered the fresh challenge, both illegal twins produced zero effects, both
mutants turned red, and authenticated target inventories returned to preflight. Application-data-path,
per-user enforcement, browser, UI-runtime, and HA claims remain explicitly UNVERIFIED.

Every hardware substrate can always run the `linux-cpu` lane. When a validation needs a pristine Linux host,
use Incus on Linux or Linux-CUDA, Lima on Apple, and WSL2 on Windows; specialized lanes are additive.

## Phase Summary

Phase 34 binds a checked `TenantSpec` containing issuer-qualified `SubjectSpec`, `Membership`, `Owner`, and
`RoleBinding` references to one total `TenantPolicyDerivation`. The derivation has a closed provider index:
Keycloak, Vault, Pulsar, MinIO, Kubernetes API (including NetworkPolicy), and Postgres. Each provider object,
target, executor attachment, persistence demand, and cleanup action retains its `AppId` and `TenantId`; there
is no unqualified resource coordinate and no DSL constructor for a provider-native grant.

The phase then applies that sealed derivation to the live Phase-33 cluster and reads each provider back through
a separately authenticated observer. The boundary tests whether checked policy was projected completely and
faithfully for the representative corpus. It does **not** establish that a user request is confined by those
policies: Phase 36 owns the real-credential, own-subject/foreign-subject and own-tenant/foreign-tenant
application-data-path gate.

**Session scope:** one provider-projection transaction and one acceptance command,
`cabal test tenant-provider-provisioning-live`. Split the phase if work adds an application data operation, UI
interaction, another cluster, HA failover, a second substrate, or a separately useful provider feature.

**Dependency:** Phase 18 and Phase 33. Phase 18 supplies the closed authorization graph and derive-not-author
boundary; Phase 33 supplies the live checked-spec singleton. Phase 17 is transitive through Phase 18.

**Substrate:** linux-cpu — the single-node `kind` cluster assembled through Phase 33. No linux-cuda, Apple,
Windows, provider-cloud, multicluster, or availability claim is made.

**Register:** 3 — live infrastructure.

**Gate:** `cabal test tenant-provider-provisioning-live` passes the pinned six-arm projection relation, the
paired illegal twins, the bypass probes, the teardown inventory, and both committed mutants of
[Gate integrity](#gate-integrity) — Register 3 green, the application data path UNVERIFIED until Phase 36.

## Gate integrity

That one command creates two challenge-qualified tenant projections, applies their sealed provider
transactions, and passes only when separately authenticated provider APIs expose the exact oracle-pinned
object/policy relation for all six provider arms. A missing arm, a tenant-key collapse, a caller-authored
grant, incomplete teardown, or either committed mutant makes it fail. Application round trips are
deliberately absent.

The harness may coordinate the gate but may not be its oracle. Expected relations, authority, challenges, and
observations are independent of the policy renderer and enactor under test.

- **Representative set:** Phase 0 pins one app, two equal-shaped tenants, two issuer-qualified subjects per
  tenant, one membership and owner relation, one derived read role, one object bucket, one Pulsar namespace,
  one Vault prefix, one Postgres role/schema projection, and the corresponding Kubernetes namespace and
  NetworkPolicy. Equal-shaped tenants expose accidental unqualified-key coalescing.
- **Pinned oracle:** `test/fixtures/phase_34/provider_projection_matrix.tsv` is hand-authored before the
  renderer. It names each logical input relation and the required normalized provider object type, parent,
  tenant qualifier, permission class, and absence rule. It contains symbolic challenge slots, not golden bytes
  generated by the SUT.
- **Fresh challenge:** after the singleton, enactor, and observers report ready, the harness generates an
  unpredictable run nonce and distinct tenant suffixes. Those values enter through the checked test spec and
  must be recovered from every provider's authenticated readback. Pre-recorded objects cannot satisfy the
  oracle.
- **Authority separation:** the enactor has only the provider mutation rights required for the transaction.
  Six read-only observer principals, minted or scoped after the run begins, query Keycloak, Vault, Pulsar,
  MinIO, Kubernetes, and Postgres control-plane APIs. The SUT's success response, logs, metrics, desired-state
  cache, and rendered payload are not evidence.
- **Paired cases:** the legal derived graph is paired with (1) the same graph containing one provider-native
  hand-authored grant and (2) the same graph with a tenant-mismatched reference. Both illegal twins must be
  rejected before provider mutation, while the legal twin produces the fresh observed objects.
- **Zero-effect evidence:** authenticated pre/post provider inventories establish that each rejected twin
  creates no object, grant, role, namespace, prefix, policy, or audit-side payload carrying its distinct
  forbidden nonce.
  A decode error without the external zero-effect observation cannot pass.
- **Bypass probes:** the gate submits a provider grant directly to the public checked-spec decoder, swaps an
  outer tenant key around an otherwise valid inner projection, and calls the enactor with an unsealed
  derivation. No route may construct a provisioned action or cause a provider effect.
- **Committed mutants:** `drop_provider_arm` removes the Pulsar arm after successful derivation;
  `collapse_tenant_key` keys provider actions by unqualified local id. The first must fail exact provider
  readback and the second must collide the equal-shaped tenants or produce the wrong tenant parent. Each mutant
  must turn the unchanged gate red for its intended reason.
- **Cleanup observation:** teardown uses the sealed delete transaction, then the read-only observers compare
  complete authenticated inventories with preflight. Challenge-qualified residue, observer/enactor credential
  reuse, missing observations, stale epochs, or a mismatched nonce fails closed.

The evidence ledger records the Phase-0 oracle digest, checked-spec and derivation digests, nonce hash,
authority identities and epochs, normalized raw-observation digests, paired-case outcomes, mutant outcomes,
cleanup inventories, substrate, and Register. It records no credential material.

## Resource provision — one sealed provider transaction

- Whole-deployment binding admits the app namespace, provider persistence, provider executor, API-object,
  etcd, object-metadata, SQL-role, Pulsar-metadata, observer, teardown, and failure-retention demands before the
  first live mutation.
- `TenantPolicyDerivation` is an immutable pure intermediate. Private `ProvisionedTenantPolicyAction` values
  retain source digest, `AppId`, `TenantId`, provider, operation, old/new target, canonical payload digest,
  executor identity, persistence high-water, rollback retention, and cleanup predicate.
- The provider index is closed and exhaustive. NetworkPolicy is a Kubernetes-API payload; Postgres roles and
  grants are Postgres provider outputs; MinIO IAM and bucket policy are provider metadata rather than app
  objects. Pulsar application produce/consume is owned by Phase 35 and scoped end-to-end enforcement by Phase
  36.
- The enactors accept only provisioned actions paired with a fresh validated live target. They do not accept a
  `TenantSpec`, caller-authored policy, raw provider coordinate, or previously serialized `Provisioned*` value.
- Deletes are explicit actions over desired and observed identity, including observed-only tenants. Old and
  new targets remain charged until authenticated readback confirms the replacement and cleanup confirms the old
  object absent.

## Doctrine adopted

- [`tenancy_doctrine.md` §4 — typed tenant and subject shapes](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding): consume the Phase-17 identity
  values without reintroducing an unqualified subject, tenant, owner, membership, or resource reference.
- [`tenancy_doctrine.md` §5 — RBAC is derived](../documents/engineering/tenancy_doctrine.md#5-rbac-is-derived-never-authored): a checked tenant/role graph is the only source of provider policy.
- [`service_capability_doctrine.md` §4 — capability, provider, shape](../documents/engineering/service_capability_doctrine.md#4-capability--provider--shape-the-binding): provider bindings supply mechanism, never caller authority.
- [`platform_services_doctrine.md`](../documents/engineering/platform_services_doctrine.md): apply the
  provider-indexed transaction through least-authority enactors and authenticated readback.
- [`testing_doctrine.md` §12 — spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): bind the claim to post-ready challenges,
  authority separation, raw external observations, paired cases, bypass probes, and killed mutants.
- [`illegal_state_security.md` §3.80](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant): Phase 34 provisions the policy
  precondition but leaves its live request-enforcement residue to Phase 36.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 34.1: Derive, apply, and externally read back tenant provider policy ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
zero-effect rejects, complete target inventory, and two mutation checks are validated at Register 3.
**Implementation**: `src/Amoebius/Tenancy/ProviderProjection.hs`,
`src/Amoebius/Tenancy/ProviderTransaction.hs`,
`src/Amoebius/Tenancy/Provider/{Keycloak,Vault,Pulsar,Minio,KubernetesApi,Postgres}.hs`, and
`test/live/TenantProviderProvisioningSpec.hs`, and `tools/phase34_tenant_provider_live.py` — delivered
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: one command instantiates the pinned relation with fresh tenant
challenges, observes all six control planes using read-only identities, establishes that both illegal twins
have zero provider effects, kills both committed mutants, and verifies teardown inventory.
**Docs to update**: `documents/engineering/tenancy_doctrine.md`,
`documents/engineering/platform_services_doctrine.md`, `documents/engineering/testing_doctrine.md`, and
`documents/illegal_state/illegal_state_security.md`

### Objective

Turn one sealed checked tenant graph into a complete live provider transaction without claiming that provider
provisioning alone establishes application request isolation.

### Deliverables

- The closed, total tenant-policy derivation and private provisioned-action boundary.
- Provider enactors for the six required arms plus independent normalized read-only observers.
- Phase-0 projection/oracle fixtures, paired illegal inputs, post-ready challenge protocol, zero-effect checks,
  authenticated cleanup inventory, and schema-checked Register-3 ledger.
- Committed `drop_provider_arm` and `collapse_tenant_key` mutants.

### Validation

1. Run `cabal test tenant-provider-provisioning-live`; require every challenge-qualified object and relation in
   `provider_projection_matrix.tsv` exactly once under the correct app/tenant parent.
2. Require the hand-authored-grant and tenant-mismatched twins to fail before mutation and externally establish their distinct
   forbidden nonces absent through every provider observer.
3. Run both committed mutants against the unchanged gate and require the pinned missing-arm and tenant-key
   failures.
4. Tear down and require authenticated provider inventories to equal preflight; persist only hashed evidence
   and explicitly mark application data-path isolation `UNVERIFIED (Phase 36)`.

### Remaining Work

None. Phase 36 retains the application request-isolation residue.

## Documentation Requirements

**Engineering docs to update (when the gate runs, never before):**

- `documents/engineering/tenancy_doctrine.md` and `platform_services_doctrine.md` — record tested provider
  projection/readback only.
- `documents/engineering/testing_doctrine.md` — register the six-observer transaction pattern.
- `documents/illegal_state/illegal_state_security.md` — attach the killed hand-authored/tenant-collapse evidence
  while retaining Phase 36's live enforcement residue.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — index the narrowed
  provider-provisioning claim.
- `DEVELOPMENT_PLAN/phase_35_pulsar_client.md` and `phase_36_user_tenant_isolation_live.md` — consume provider
  readiness without treating it as user authorization evidence.

## Related Documents

- [Phase 18 — UI authorization kernel](phase_18_ui_authorization_kernel.md)
- [Phase 33 — live DSL singleton](phase_33_live_dsl_singleton.md)
- [Phase 35 — Pulsar client](phase_35_pulsar_client.md)
- [Phase 36 — live subject/tenant isolation](phase_36_user_tenant_isolation_live.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
