# Phase 41: Live subject/tenant isolation

> **Purpose**: Prove on live `linux-cpu` infrastructure that authenticated subject and tenant scope is injected
> by amoebius and enforced across SQL, object, and message data paths with zero foreign-scope effects.
> **Read this if**: phase 41 is next in the queue, or a later phase depends on what its gate establishes.

Phase 41 delivers the live subject/tenant isolation; its design is owned by [tenancy_doctrine.md](../documents/engineering/tenancy_doctrine.md), [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [testing_doctrine.md](../documents/engineering/testing_doctrine.md), and the plan for reaching it is owned here.
Register 3, live, on the `linux-cpu` substrate.
Validated 2026-08-10 with `python3 tools/user_tenant_isolation_gate.py
--reuse-fresh-live`; ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_39_app_tenancy.md, DEVELOPMENT_PLAN/phase_43_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_58_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/tenancy_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — scoped live probe](#resource-provision--scoped-live-probe)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 41.1: Live scoped request and provider-isolation gate ⏸️](#sprint-411-live-scoped-request-and-provider-isolation-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-40 revalidation — **reopened 2026-08-16 by the natural-architecture amendment.**
[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15 requires a run to record
the natural architecture it proved and to execute no artifact of another. This phase's last gate recorded no
architecture, so its seal is invalidated as a current result and stands only as history; the rerun differs from
it by naming the lane and architecture the run actually used. A sprint marker below records what that sprint achieved before the amendment; under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) it is a diagnostic, not surviving closure.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Blocked (superseded) — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

Blocked (superseded) by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Invalidated historical record:**

Done (invalidated). The Register-3 gate uses three real Keycloak credentials, a private Haskell request-context adapter,
live Postgres RLS, derived MinIO keys, native Haskell Pulsar traffic, enforcing NetworkPolicy, independent
provider observers, cleanup equality, and two red source mutants. Browser tenant switching remains Phase 58;
cross-cluster isolation and complete provider-audit-log correspondence remain explicitly `UNVERIFIED`.

## Phase Summary

This phase owns one live seam: current Keycloak identity and the derived `TenantSpec` policy become the trusted
`RequestContext` consumed by scoped handlers and provider policies. A minimal bound server probe exercises
subject-owned and tenant-owned Postgres rows, MinIO objects, and Pulsar messages without exposing provider
coordinates or credentials to the caller. The phase tests enforcement, not a full browser UX; Phase 58 owns
multi-tenant UI scope switching.

**Session scope:** one live request-context-to-provider isolation claim and one acceptance command,
`cabal test user-tenant-isolation-live`; split if a browser interaction, UI-plan rollout, HA failure, second
substrate, or independently useful provider feature is required.
**Depends on:** Phases 37, 39, and 40 — respectively Keycloak-owned ingress, delivered and independently read
six-provider administrative policy, and the native Pulsar client. Phase 39 supplies readiness only; this phase
must still establish the real-credential application-effect matrix. All three gates must be green.
**Substrate:** `linux-cpu` — one live `kind` cluster; no accelerator or multicluster claim. Every hardware
substrate can always run this baseline. When a pristine Linux host is required, use Incus on Linux or
Linux-CUDA hardware, Lima on Apple hardware, and WSL2 on Windows hardware.
**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure.
**Gate:** `cabal test user-tenant-isolation-live` passes the real-credential paired matrix and committed
mutants. Authenticated external observations establish zero forbidden SQL, MinIO, and Pulsar effects; a public
denial alone cannot pass. The phase gate repeats the sealed reader, mutants, documentation lint, and ledger lint.

## Gate integrity

The expected access relation is pinned in Phase 0 before the live adapter exists. Runtime secrets are never
fixtures: the authority under test creates them after the gate starts, and the ledger retains only identities,
epochs, and evidence hashes.

- **Representative set:** tenants `t-a` and `t-b`; subjects `alice-a` and `bob-a` in `t-a`, and `carol-b` in
  `t-b`; equal-shaped subject-owned rows/objects/messages; one tenant-wide resource; and one revocable grant.
  Each own-scope success is paired with same-tenant/foreign-subject and foreign-tenant attempts differing only
  in the authenticated subject/scope or supplied opaque handle.
- **Pinned matrix:** `test/fixture/live_isolation/user_tenant_access_matrix.tsv` fixes operation, authority,
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
`src/Amoebius/Test/{Harness,Sweep}.hs` that [Phase 56](phase_56_test_topology_dsl.md) later consolidates these
per-phase observers into — compares authenticated pre/post inventories; a leaked test credential or resource
fails the phase.

## Resource provision — scoped live probe

- One minimal same-binary server worker behind the Phase-37 Keycloak/Envoy edge, with a sealed action registry
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

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 41.1: Live scoped request and provider-isolation gate ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/Ui/Server/ScopedAuthority.hs`,
`test/spec/live/UserTenantIsolationSpec.hs`, `tools/user_tenant_isolation_live.py`, `tools/user_tenant_isolation_gate.py`,
`test/fixture/live_isolation/{user_tenant_access_matrix,public_errors,expected_audit}.tsv` (built and validated)
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: the one gate command executes every pinned matrix row using
Keycloak-minted credentials and checks fresh nonces plus read/access attempts through independent
provider/audit/API/CNI observers; both mutants go red.
**Docs to update**:
`documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/tenancy_doctrine.md`,
`documents/illegal_state/illegal_state_security.md`, `documents/engineering/testing_doctrine.md`

### Objective

Connect authenticated identity to the Phase-20/21 scoped authorization values and test that provider effects
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

None in this phase. Browser tenant switching is deliberately deferred to Phase 57. Cross-cluster isolation and
complete provider-audit-log correspondence remain `UNVERIFIED` and are not claimed by this single-cluster gate.

## Documentation Requirements

**Engineering docs updated by the completed gate:**

- `documents/engineering/low_code_ui_runtime_doctrine.md` and `documents/engineering/tenancy_doctrine.md`
  record the tested live request-context/provider-isolation residue.
- `documents/illegal_state/illegal_state_security.md` attaches §3.80's paired real-credential evidence.
- `documents/engineering/testing_doctrine.md` records the provider-side zero-effect observer instance.

**Cross-references completed:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the gate, `linux-cpu` substrate, and adapter ownership.
- `DEVELOPMENT_PLAN/phase_58_ui_multi_tenant_live.md` — consume this provider-isolation result unchanged.

## Related Documents

- [Phase 39](phase_39_app_tenancy.md) — tenant policy derivation and provider materialization.
- [Phase 40](phase_40_pulsar_client.md) — native authenticated message path used by this gate.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — trusted request-context and scoped data rules.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — live authority, challenge, observer, and teardown rules.
