# Phase 38: Owner-scoped UI projection runtime

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_40_ui_program_release.md, DEVELOPMENT_PLAN/phase_50_infernix_ui_lift.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Materialize bounded workflow events into owner-qualified UI read models and test on live
> infrastructure that neither projection keys, subscriptions, nor query handles can collapse subject or tenant
> scope.

---

## Phase Status

📋 Planned. Phase 20 owns client/server plan compilation and Phase 23 owns local interpreter composition. This
phase adds only the live owner-scoped projection seam. No release rollout, ML artifact lift, browser UX, or HA
claim is made here.

## Phase Summary

`UiProjectionWorker` consumes canonical CBOR workflow events through the native Phase-35 Pulsar client and
builds a compacted latest-value projection. Every message key, subscription, stored row, watermark, opaque
query handle, and audit identity retains `(AppId, TenantId, Owner, ProjectionId)`. The worker receives a private
`UiServerPlan` projection and server-held capabilities; the browser or caller never supplies a topic,
subscription, tenant, owner, provider coordinate, or provider credential.
Every owner stream also carries a monotonic `StreamCursor` and program/scope epochs suitable for WebSocket
delivery. Redis may later wake a connection owner, but only this Pulsar-backed sequence/watermark can detect a
gap and repair it.

The live gate drives equal-shaped workflows for two subjects in one tenant and a third subject in a second
tenant. It verifies current values and resume watermarks through a scoped server query while a separately
authenticated native client and broker-admin observer inspect the underlying compacted topic. Same-tenant
foreign-owner and foreign-tenant handles yield the same public denial and cannot disclose the other challenge.

**Session scope:** one owner-keyed workflow-event-to-query projection and the command
`cabal test ui-projection-runtime-live`; split if work adds a browser interaction, release transition, ML
adapter, another substrate, HA fault, or a second acceptance command.

**Dependency:** Phase 22, Phase 36, and Phase 37. Phase 22 supplies sealed server dispatch, Phase 36 supplies
the live trusted request context and scoped authorization result, and Phase 37 supplies the live workflow/event
path. Phase 35 is transitive through Phases 36 and 37.

**Substrate:** linux-cpu — one live single-node `kind` cluster. No linux-cuda, Apple, Windows, multicluster, or
redundancy claim.

**Register:** 3 — live infrastructure.

**Gate:** `cabal test ui-projection-runtime-live` runs the Phase-0-pinned own-owner/foreign-owner/foreign-tenant
matrix with real Keycloak sessions and post-ready event challenges. It passes only when the scoped server
response, independent Pulsar consumer, broker watermark, and audit transcript agree on the exact owner-qualified
projection and both committed mutants turn the unchanged gate red. The fixtures, authorities, observers,
bypass probes, and mutants are delegated to [Gate integrity](#gate-integrity).

## Gate integrity

- **Representative set:** app `a`, tenants `t-a` and `t-b`, owners `alice-a`, `bob-a`, and `carol-b`, one
  projection id, equal local entity ids, an update/tombstone/recreate sequence, and disconnect/resume from a
  non-final watermark. Equal shapes force the tenant and owner dimensions to carry the isolation.
- **Pinned oracle:** Phase 0 commits `test/fixtures/phase_38/projection_matrix.tsv`,
  `expected_latest_values.tsv`, and `expected_watermarks.tsv`. The tables are hand-authored from the published
  projection fold and scope relation; the worker, handler, Pulsar client, and renderer do not generate them.
- **Real authority:** Keycloak mints least-privilege sessions after gate start. Tenant, subject, owner,
  membership, and grants are derived by the server. Caller headers, body fields, query strings, opaque-handle
  payloads, and browser state are hostile variants, never oracle inputs.
- **Fresh challenges:** after Keycloak, Pulsar, worker, query handler, and observers are ready, the harness
  creates unpredictable per-owner nonces and emits them through the Phase-37 workflow boundary. Each permitted
  query must recover only its nonce and correct watermark; a static row, canned response, or prior run cannot
  pass.
- **External observers:** a separate read-only native Pulsar principal consumes the compacted topic and a
  broker-admin principal observes subscription names, keys, offsets, compaction state, and watermarks. An
  edge-side OS transcript records the scoped query/response bytes, and Keycloak/audit observers attest session
  identity. Worker/server logs, metrics, desired state, and self-reported traces are ignored as evidence.
- **Paired scope checks:** each own-owner success is paired with the same-tenant foreign-owner and foreign-
  tenant handle swap differing only in authenticated session or opaque handle. Denials are indistinguishable,
  contain no foreign nonce/existence bit, and do not advance, create, or retarget a foreign subscription.
- **Bypass probes:** user credentials are tried directly against Pulsar and must grant no broker access. The
  harness bypasses presentation logic and sends forged tenant/owner headers, a swapped handle, a guessed local
  entity id, and a stale request epoch directly to the sealed query action.
- **Committed mutants:** `drop_owner_key` removes `Owner` from the compacted message key, and
  `drop_owner_subscription` removes `Owner` from the subscription identity. Equal-shaped owners make each
  mutant leak, overwrite, or advance foreign state, and the independent key/value/watermark oracle must turn
  red.
- **Honest boundary:** the gate tests the pinned live projection and query matrix only. It does not establish all
  handlers noninterfering, browser presentation safe, release compatibility, or availability.

Teardown deletes challenge projections, subscriptions, observer grants, test identities, and namespaces. Each
external observer compares authenticated pre/post inventory; any challenge residue or credential sharing fails
the gate. The ledger stores only identities/epochs and hashes of challenges, fixtures, raw observations, and
mutant results.

## Resource provision — bounded owner projections

- Projection demand is finite per `(AppId, TenantId, Owner, ProjectionId)`: event rate and size, compacted key
  count/value bound, cursor and replay window, consumer buffer, worker concurrency, old/new overlap, failed
  compaction/replay retention, audit bytes, and query-handler envelope all enter whole-deployment provision.
- Owner-qualified projection messages are the only input to the private fold. A compacted `TableView` is a
  read model, never an authorization decision or source of membership truth.
- Worker and query handler use distinct least-authority service identities. Browser/user credentials carry no
  Pulsar permission, and the public plan contains no topic or subscription coordinate.
- A projection cannot be served until caught up to the release-required watermark. Phase 40 pins that
  watermark/ABI in the immutable UI release; this phase establishes the live primitive only.

## Doctrine adopted

- [`pulsar_client_doctrine.md` §5.1 — derived compaction and TableView](../documents/engineering/pulsar_client_doctrine.md#51-two-derived-capabilities-read-model-and-two-deliberately-absent-ones): use the native client for a bounded
  read model without making it an authority source.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): derive current identity and scope at the trusted server edge.
- [`low_code_ui_runtime_doctrine.md` §11 — data, forms, and storage](../documents/engineering/low_code_ui_runtime_doctrine.md#11-data-forms-and-storage): expose only scoped public contracts and opaque handles.
- [`tenancy_doctrine.md` §4 — typed tenant and subject shapes](../documents/engineering/tenancy_doctrine.md#4-the-typed-shapes-tenantspec--subjectspec--membership--owner--rolebinding): retain app, tenant, and owner identity in every read-model coordinate.
- [`testing_doctrine.md` §12 — spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): require fresh challenges, real authority,
  external raw observation, paired negatives, direct bypass probes, and killed mutants.
- [`ui_realtime_coordination_doctrine.md §4 — typed routing and resume envelope`](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): produce the authoritative sequenced cursor stream from which lossy WebSocket fanout repairs gaps.

## Sprints

## Sprint 38.1: Build and independently verify the owner-scoped live projection 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Ui/Projection/{Worker,OwnerKey,Watermark,StreamCursor}.hs` and
`test/live/Phase38UiProjectionRuntimeSpec.hs` (target authored sources; not yet built)
**Blocked by**: Phase 22; Phase 36; Phase 37
**Independent Validation**: one command recovers fresh per-owner challenges through a scoped server query and
separately authenticated Pulsar/broker/edge observers, establishes foreign-scope non-disclosure and zero subscription
effect, and kills both owner-collapse mutants.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/pulsar_client_doctrine.md`, `documents/engineering/tenancy_doctrine.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`, and
`documents/engineering/testing_doctrine.md`

### Objective

Establish the one live event-to-read-model seam needed by composable low-code workflows while preserving
issuer-qualified subject, tenant, and owner scope end to end.

### Deliverables

- Private owner-qualified projection keys, subscription identities, watermarks, and opaque scoped handles.
- Bounded compacted-topic worker and sealed scoped-query adapter over server-held capabilities.
- Phase-0 matrices/oracles, real-identity fixture, post-ready challenge protocol, native/broker/edge observers,
  bypass corpus, teardown inventory, evidence ledger, and both committed mutants.

### Validation

1. Run `cabal test ui-projection-runtime-live`; recover exactly the pinned latest value and watermark for each
   own-owner session after update, tombstone, recreate, disconnect, and resume.
2. Require foreign-owner, foreign-tenant, forged-scope, guessed-id, direct-Pulsar, and stale-epoch attempts to
   expose no foreign nonce and cause no foreign subscription/key/watermark change.
3. Run `drop_owner_key` and `drop_owner_subscription`; require the unchanged external oracle to fail on the
   intended overwrite/leak or cursor-crossing row.
4. Tear down to the authenticated preflight inventories and persist a Register-3 ledger that leaves browser,
   release, ML-lift, and HA claims UNVERIFIED.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/pulsar_client_doctrine.md` and `low_code_ui_runtime_doctrine.md` — attach tested live
  owner-key/subscription/watermark evidence only.
- `documents/engineering/tenancy_doctrine.md` — record the live owner-qualified projection residue.
- `documents/engineering/testing_doctrine.md` — register the broker/native/edge multi-observer pattern.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, `substrates.md`, and `system_components.md` — index the live seam.
- `DEVELOPMENT_PLAN/phase_40_ui_program_release.md` and `phase_50_infernix_ui_lift.md` — consume its caught-up
  watermark/read-model result without expanding its claim.

## Related Documents

- [Phase 22 — UI server boundary](phase_22_ui_server_boundary.md)
- [Phase 36 — live subject/tenant isolation](phase_36_user_tenant_isolation_live.md)
- [Phase 37 — content store and workflow runtime](phase_37_content_store_workflow.md)
- [Phase 40 — atomic UI-program release](phase_40_ui_program_release.md)
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Native Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
