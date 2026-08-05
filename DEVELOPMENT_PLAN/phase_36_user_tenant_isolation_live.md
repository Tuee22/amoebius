# Phase 36: Live subject/tenant isolation

> **Purpose**: Prove on live `linux-cpu` infrastructure that authenticated subject and tenant scope is injected
> by amoebius and enforced across SQL, object, and message data paths with zero foreign-scope effects.
> **Read this if**: phase 36 is next in the queue, or a later phase depends on what its gate establishes.

Phase 36 delivers the live subject/tenant isolation; its design is owned by [tenancy_doctrine.md](../documents/engineering/tenancy_doctrine.md), [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [testing_doctrine.md](../documents/engineering/testing_doctrine.md), and the plan for reaching it is owned here.
Register 3, live, on the `linux-cpu` substrate.
No gate has run.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_34_app_tenancy.md, DEVELOPMENT_PLAN/phase_38_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_56_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — scoped live probe](#resource-provision--scoped-live-probe)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 36.1: Live scoped request and provider-isolation gate 📋](#sprint-361-live-scoped-request-and-provider-isolation-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

📋 Planned. Nothing in this phase is implemented or tested; its security result exists only after the
Register-3 gate runs with authority-minted credentials and records its evidence ledger.

## Phase Summary

This phase owns one live seam: current Keycloak identity and the derived `TenantSpec` policy become the trusted
`RequestContext` consumed by scoped handlers and provider policies. A minimal bound server probe exercises
subject-owned and tenant-owned Postgres rows, MinIO objects, and Pulsar messages without exposing provider
coordinates or credentials to the caller. The phase tests enforcement, not a full browser UX; Phase 56 owns
multi-tenant UI scope switching.

**Session scope:** one live request-context-to-provider isolation claim and one acceptance command,
`cabal test user-tenant-isolation-live`; split if a browser interaction, UI-plan rollout, HA failure, second
substrate, or independently useful provider feature is required.
**Dependency:** Phases 32, 34, and 35 — respectively Keycloak-owned ingress, derived tenant/provider policy,
and the native Pulsar client. All three gates must be green.
**Substrate:** linux-cpu — one live `kind` cluster; no CUDA, Apple, Windows, provider-cloud, or multicluster claim.
**Register:** 3 — live infrastructure.
**Gate:** `cabal test user-tenant-isolation-live` passes the real-credential, fresh-challenge, paired own/
foreign-scope matrix and every committed mutant defined in [Gate integrity](#gate-integrity). Each forbidden row
must have authenticated external pre/post observations establishing zero SQL, MinIO, and Pulsar effect; an HTTP denial
or hidden control alone cannot pass.

## Gate integrity

The expected access relation is pinned in Phase 0 before the live adapter exists. Runtime secrets are never
fixtures: the authority under test creates them after the gate starts, and the ledger retains only identities,
epochs, and evidence hashes.

- **Representative set:** tenants `t-a` and `t-b`; subjects `alice-a` and `bob-a` in `t-a`, and `carol-b` in
  `t-b`; equal-shaped subject-owned rows/objects/messages; one tenant-wide resource; and one revocable grant.
  Each own-scope success is paired with same-tenant/foreign-subject and foreign-tenant attempts differing only
  in the authenticated subject/scope or supplied opaque handle.
- **Pinned matrix:** `test/fixtures/live_isolation/user_tenant_access_matrix.tsv` fixes operation, authority,
  resource audience, expected public result, and expected provider delta. `public_errors.tsv` fixes the
  indistinguishable denial shape; `expected_audit.tsv` fixes required audit classes. None is emitted by the SUT.
- **Real authority:** the gate creates a dedicated Keycloak test realm and asks Keycloak to mint least-privilege
  credentials for the three subjects. The server derives tenant/membership from the authenticated session;
  caller `X-Tenant`, subject, owner, role, or grant fields are hostile variants and never oracle inputs.
- **Fresh challenges:** after every process is ready, the harness generates unpredictable per-row nonces.
  Allowed writes recover their nonce through an independently authenticated provider observer. Forbidden
  writes use distinct nonces that must be absent from every provider and audit payload after quiescence.
- **External observers:** separate read-only test principals query Postgres rows/WAL-visible state and its
  statement/audit stream, MinIO object keys/digests and authenticated GET/HEAD request audit, Pulsar topic
  offsets/payload digests plus broker authorization/consumer/delivery evidence, and Keycloak membership/events.
  An edge-side response-byte observer checks that no foreign challenge was disclosed. Kubernetes audit and a
  foreign-pod CNI probe observe attempted direct Service/provider bypass. Missing, disabled, stale,
  unauthenticated, or challenge-mismatched evidence fails closed; server self-report is ignored.
- **Paired zero-effect checks:** read, create, update, delete, object upload/download, produce, and consume are
  exercised where meaningful. A denied read/download/consume earns credit only when statement/request/broker
  evidence shows no unauthorized SELECT, GET/HEAD, subscription, or delivery and the edge response contains no
  foreign nonce. A denied mutation additionally requires provider snapshots with no forbidden version, object,
  message, cursor advance, or existence side channel.
- **Bypass probes:** the caller's Keycloak credential is tried directly against SQL, MinIO, and Pulsar and must
  confer no provider authority; a forged tenant header and swapped opaque handle are sent directly to the bound
  server action, bypassing any presentation guard.
- **Seeded mutants:** `drop_user_predicate` deletes only the subject/owner predicate, and
  `accept_body_tenant` trusts the caller's tenant field instead of server context. Both are committed from the
  adopted live-isolation brief and must admit a forbidden nonce, turning the provider-side oracle red.

The gate tears down the test realm, subjects, tenant data, observer grants, and namespaces. An **elevated
observer provisioned in this phase** — credentialed outside the subject under test, not the shared
`src/Amoebius/Test/{Harness,Sweep}.hs` that [Phase 54](phase_54_test_topology_dsl.md) later consolidates these
per-phase observers into — compares authenticated pre/post inventories; a leaked test credential or resource
fails the phase.

## Resource provision — scoped live probe

- One minimal same-binary server worker behind the Phase-32 Keycloak/Envoy edge, with a sealed action registry
  and no direct wild provider route.
- Two tenant policy projections, three subject memberships, one grant/revocation sequence, and isolated
  Postgres, MinIO, and Pulsar fixture resources with equal-shaped identifiers.
- Separate least-privilege SUT identities and read-only observer identities; no shared credential may serve both.
- Complete pod/image/slot/API/etcd/storage/message demand plus probe and observer envelopes admitted before the
  first realm, row, object, or topic mutation.

## Doctrine adopted

- [`tenancy_doctrine.md` §4 — typed tenant and subject shapes](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding) and [`§5 — RBAC is derived`](../documents/engineering/tenancy_doctrine.md#5-rbac-is-derived-never-authored): live authority comes from the declared graph, not request fields.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): every action is reauthorized server-side.
- [`low_code_ui_runtime_doctrine.md` §11 — data, forms, and storage](../documents/engineering/low_code_ui_runtime_doctrine.md#11-data-forms-and-storage): tenant/subject constraints are server-injected.
- [`illegal_state_catalog.md` §3.80](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant): the live paired matrix and mutants discharge its runtime residue.
- [`testing_doctrine.md` §12 — spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): fresh effects, real authority, and external observers are mandatory.

## Sprints

## Sprint 36.1: Live scoped request and provider-isolation gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Ui/Server/ScopedAuthority.hs`,
`test/live/UserTenantIsolationSpec.hs` (target authored sources; not yet built)
**Blocked by**: Phase 32;
Phase 34; Phase 35
**Independent Validation**: the one gate command executes every pinned matrix row using
Keycloak-minted credentials and checks fresh nonces plus read/access attempts through independent
provider/audit/API/CNI observers; both mutants go red.
**Docs to update**:
`documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/tenancy_doctrine.md`,
`documents/illegal_state/illegal_state_security.md`, `documents/engineering/testing_doctrine.md`

### Objective

Connect authenticated identity to the Phase-17/18 scoped authorization values and test that provider effects
remain tenant- and subject-confined even when a hostile caller swaps identifiers, headers, handles, or grants.

### Deliverables

- The server-side adapter from verified Keycloak session plus current tenant policy to private
  `RequestContext tenant subject`; public request fields cannot construct or override it.
- Scoped SQL/object/message probe handlers using server-held capabilities and provider-derived predicates.
- The live authority fixture, runtime nonce protocol, provider state and request/audit observer clients,
  edge-response observer, CNI bypass probe, cleanup inventory, explicit mutant suite, and schema-checked
  Register-3 evidence ledger.

### Validation

1. Run `cabal test user-tenant-isolation-live`; all allowed nonces appear exactly once and all forbidden nonces
   remain absent across Postgres, MinIO, Pulsar, edge-response, and audit observations; denied reads also have
   no matching provider statement/request/delivery record.
2. Confirm same-tenant/foreign-subject, foreign-tenant, forged-header, swapped-handle, direct-provider, and
   post-revocation attempts return the pinned public denial without disclosing resource existence.
3. Run `drop_user_predicate` and `accept_body_tenant`; require a distinct matrix/observer failure for each.
4. Always tear down; authenticated provider and Kubernetes inventories return to their preflight sets, and the
   ledger records `linux-cpu`, Register 3, challenge hashes, authority source, and raw-observation digests.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` and `documents/engineering/tenancy_doctrine.md` —
  record the tested live request-context/provider-isolation residue.
- `documents/illegal_state/illegal_state_security.md` — attach §3.80's real-credential, paired-scope evidence.
- `documents/engineering/testing_doctrine.md` — register the provider-side zero-effect observer pattern.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the gate, `linux-cpu` substrate, and adapter ownership.
- `DEVELOPMENT_PLAN/phase_56_ui_multi_tenant_live.md` — consume this provider-isolation result unchanged.

## Related Documents

- [Phase 34](phase_34_app_tenancy.md) — tenant policy derivation and provider materialization.
- [Phase 35](phase_35_pulsar_client.md) — native authenticated message path used by this gate.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — trusted request-context and scoped data rules.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — live authority, challenge, observer, and teardown rules.
