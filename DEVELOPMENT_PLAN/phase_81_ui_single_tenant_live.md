# Phase 81: Single-tenant low-code UI live path

> **Purpose**: Prove one generic low-code application through the real authenticated edge, data capabilities,
> workflow runtime, projection path, and infernix interaction without any application-specific browser code.
> **Read this if**: phase 81 is next in the queue, or a later phase depends on what its gate establishes.

Phase 81 delivers the single-tenant low-code UI live path; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [platform_services_doctrine.md](../documents/engineering/platform_services_doctrine.md), [content_addressing_doctrine.md](../documents/engineering/content_addressing_doctrine.md), and the plan for reaching it is owned here.
Register 3, scoped live, on the `linux-cpu` substrate.
The scoped gate passed on 2026-08-11; the full browser/identity/provider topology remains `UNVERIFIED`.

> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: DEVELOPMENT_PLAN/phase_69_spa_live_deploy.md (single-tenant portion)
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 81.1: Complete single-tenant UI slice ⏸️](#sprint-811-complete-single-tenant-ui-slice-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-80 revalidation. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Blocked (superseded) — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

Blocked (superseded) by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Invalidated historical record:**

🟡 **Scoped gate passed 2026-08-11.** Pinned access/Origin/CSRF/network oracles, authorization-before-dispatch,
fresh-challenge propagation, cross-replica routing, durable receipt authority, a real two-endpoint loopback
socket/temporary receipt probe, and seven mutants pass. Fresh OIDC/browser, Keycloak/Envoy, Kubernetes UI
replicas, retained Redis/PostgreSQL/MinIO/Pulsar, infernix, and provider network observers remain
**UNVERIFIED**. Ledger `external-run-reference`.

## Phase Summary

This phase is the first complete live application slice. One checked UI program runs in the generic browser
interpreter and UI-server responsibility behind Keycloak and Envoy. Its typed ports exercise SQL, object
storage, Pulsar-backed workflow state, owner-scoped projections, and a ready infernix artifact. It tests the
single-tenant path only; multiple tenants, rollout continuity, and failure-domain redundancy remain separate
phases.
The topology uses at least two ready UI-server replicas without sticky routing. The gate pins a browser socket
to replica A, originates a projection event and command receipt through replica B, and requires scoped Redis
fanout plus durable cursor/receipt repair to deliver them to A. This establishes cross-pod routing, not HA.

**Session scope:** Wire and validate one single-tenant end-to-end topology with the acceptance command
`cabal test phase55-ui-single-tenant-live`; split if completion requires a second tenant, a release transition,
or a replica/failure-domain fault claim.

**Phase scope:** one cohesive claim — *one generic application runs end to end with no application-specific browser code*. Everything the application needs is a plan the generic interpreter already runs.

**Substrate:** `linux-cpu` ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 70](phase_70_ui_projection_runtime.md) — the owner-scoped projection runtime, and [Phase 72](phase_72_ui_program_release.md), the released plan the generic interpreter runs.

**Gate:** `python3 tools/run_phase_gate.py 81` deploys the concrete representative topology and satisfies
every fixture, external observation, paired authority check, fresh challenge, bypass probe, and mutant in
[Gate integrity](#gate-integrity). A browser screenshot, app-emitted compliance event, or `replicas=1` topology
cannot satisfy the gate.

## Gate integrity

**Representative set.** The committed topology contains one `AppId`, one Keycloak realm/tenant, two real
subjects (`owner` and `other`), one generic UI-server Deployment, one UI projector, one Patroni database,
one MinIO bucket/prefix, one Pulsar workflow plus owner-keyed projection, and one Phase-91 infernix workflow
whose committed output is converted to a `ReadyArtifactHandle`. Playwright enters only through the public
Keycloak/Envoy origin. No fake provider or direct in-cluster browser route participates.
The UI-server Deployment has at least two replicas. A harness-controlled backend selection proves the socket
owner and event/receipt origin are different pods; a one-replica or local-only connection-map mutant fails.

**Pinned oracles.** Phase 0 commits `test/golden/ui_single_tenant_live/single_tenant_access.tbl`,
`test/golden/ui_single_tenant_live/effect_observations.json`, `test/golden/ui_single_tenant_live/origin_csrf.tbl`, and
`test/golden/ui_single_tenant_live/network_edges.tbl` before the UI runtime implementation. They independently state the
subject/action matrix, required cross-system nonce and artifact dispatch/read observations, valid-session
origin/CSRF outcomes, and intended plus forbidden network edges; the test never regenerates them from a bound
plan.

**Fresh effect and external custody.** After all workloads report ready, the harness generates an unpredictable
nonce. The owner enters it through the real browser UI, starts the workflow, and invokes the ready infernix
artifact. Observers outside the UI runtime recover the nonce from PostgreSQL using a pinned read-only audit
identity, from MinIO through its authenticated S3 API, from Pulsar with a separately provisioned native audit
consumer, and from Envoy/CNI access-flow logs. MinIO request audit and an independent infernix worker
execution/action-journal observer bind the artifact read and dispatch to the same trace/challenge. The evidence
ledger hashes those raw observations. Missing, unauthenticated, incomplete, or nonce-mismatched evidence fails
closed.

**Paired security and bypass checks.** The owner succeeds; the `other` subject repeats the same handle and
payload and receives a denial while the external SQL/S3/Pulsar observers record zero foreign mutation, MinIO
request audit records no artifact GET/HEAD, and the infernix execution/action observer records no dispatch.
With an otherwise valid owner session, wrong `Origin`, missing CSRF, and invalid CSRF requests are sent directly
to the mutation and artifact endpoints; each must fail before handler bytes, provider access, or dispatch.
Unauthenticated requests, caller-authored tenant/subject headers, guessed handles, direct service addresses,
and browser attempts to reach SQL, MinIO, Pulsar, Vault, or inference endpoints are probed independently and
must fail. Hiding a control is not authorization evidence.

**Committed mutants.** The same gate must turn red for
`test/mutant/ui_single_tenant_live/canned_ui_response.dhall`,
`test/mutant/ui_single_tenant_live/open_provider_edge.dhall`, and
`test/mutant/ui_single_tenant_live/drop_ui_networkpolicy.dhall`, plus
`test/mutant/ui_single_tenant_live/disable_csrf_check.patch` and
`test/mutant/ui_single_tenant_live/dispatch_artifact_before_auth.patch`, plus
`test/mutant/ui_single_tenant_live/local_socket_map_only.patch` and
`test/mutant/ui_single_tenant_live/redis_receipt_authority.patch`. The first cannot echo the post-start nonce from
all provider observations; the edge mutants fail the independently observed forbidden-edge table; and the
CSRF/dispatch mutants create forbidden handler or audit bytes even if the public denial is forged.

- **Extension conformance (§M.13).** `L1`–`L5`, `C1`–`C7`, `S1`–`S6`; negatives under `test/negative/ui_single_tenant_live/`.

## Doctrine adopted

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — single-tenant low-code UI live path carries an identity boundary, and S1-S6 are what make crossing it unrepresentable.
- Adopt [`low_code_ui_runtime_doctrine.md` §§13–14 — the generic client/server and HA boundary](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): run one checked program without a bespoke frontend or server.
- Adopt [`platform_services_doctrine.md` §9 — the single authenticated ingress](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path): every browser request crosses Keycloak and Envoy.
- Adopt [`content_addressing_determinism.md` §4.5 — ready artifact lifecycle](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss): expose only an authorized ready infernix handle.
- Adopt [`testing_spoof_resistance.md` §12](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): bind success to fresh provider-observed effects.
- Adopt [`ui_realtime_coordination_doctrine.md` §§4–6](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): force cross-pod WebSocket delivery while durable cursors and receipts remain outside Redis.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 81.1: Complete single-tenant UI slice ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/Ui/Live/SingleTenant.hs`,
`src/Amoebius/Ui/Realtime/RedisCoordination.hs`, `test/spec/live/UiSingleTenantSpec.hs` (planned; not
built)
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `cabal test
phase55-ui-single-tenant-live` against the pinned tables and provider-owned observations
**Docs to update**:
`documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/platform_services_doctrine.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Deliver the one-tenant generic UI runtime path and its externally observed security/effect evidence.

### Deliverables

- The resource-complete live topology and exact bound `ClientPlan`/`UiServerPlan` release.
- At least two UI-server replicas, authenticated WebSocket connection ownership, cross-pod scoped Redis
  fanout, cursor-gap repair, and durable provider/Pulsar receipt lookup without sticky sessions.
- Real OIDC Playwright flow, owner/other-subject matrix, valid-session origin/CSRF negatives, and
  direct-provider denial probes.
- Fresh-nonce SQL/S3/Pulsar/Envoy plus artifact-request/infernix-dispatch evidence capture and a generated,
  externally attested run ledger under `.build/runs/`.
- Five committed mutants that demonstrate the oracle cannot be passed by a canned UI, forged denial, or open
  edge.

### Validation

1. Run `cabal test phase55-ui-single-tenant-live` on `linux-cpu`; require all canonical observations green and
   each named mutant red for its pinned reason.
2. Force the browser WebSocket onto replica A and event/receipt production through replica B, then flush Redis
   between publish and response. Reconnect/cursor/receipt lookup must recover the authoritative outcome once,
   and neither local-only routing nor Redis-as-receipt may pass.

### Remaining Work

The portable and local cross-replica slice is implemented; the full provider/browser Register-3 topology remains UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the single-tenant runtime evidence.
- `documents/engineering/platform_services_doctrine.md` — record the observed authenticated and forbidden edges.
- `documents/engineering/testing_doctrine.md` — link the challenge-bound evidence ledger.

**Cross-references to add:**
- The phase tracker, substrate map, and component inventory must link this gate and its evidence.

## Related Documents

- [Development Plan](README.md)
- [Phase 92 — infernix UI lift](phase_92_infernix_ui_rederivation.md)
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
