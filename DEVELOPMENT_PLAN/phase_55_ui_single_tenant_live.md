# Phase 55: Single-tenant low-code UI live path

**Status**: Authoritative source
**Supersedes**: DEVELOPMENT_PLAN/phase_43_spa_live_deploy.md (single-tenant portion)
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_56_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Prove one generic low-code application through the real authenticated edge, data capabilities,
> workflow runtime, projection path, and infernix interaction without any application-specific browser code.

---

## Phase Status

📋 Planned. No implementation or live evidence exists; every statement below is design intent until the
Register-3 gate records its command, date, substrate, and ledger hash.

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

**Substrate:** `linux-cpu` ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Gate:** `cabal test phase55-ui-single-tenant-live` deploys the concrete representative topology and satisfies
every fixture, external observation, paired authority check, fresh challenge, bypass probe, and mutant in
[Gate integrity](#gate-integrity). A browser screenshot, app-emitted compliance event, or `replicas=1` topology
cannot satisfy the gate.

## Gate integrity

**Representative set.** The committed topology contains one `AppId`, one Keycloak realm/tenant, two real
subjects (`owner` and `other`), one generic UI-server Deployment, one UI projector, one Patroni database,
one MinIO bucket/prefix, one Pulsar workflow plus owner-keyed projection, and one Phase-49 infernix workflow
whose committed output is converted to a `ReadyArtifactHandle`. Playwright enters only through the public
Keycloak/Envoy origin. No fake provider or direct in-cluster browser route participates.
The UI-server Deployment has at least two replicas. A harness-controlled backend selection proves the socket
owner and event/receipt origin are different pods; a one-replica or local-only connection-map mutant fails.

**Pinned oracles.** Phase 0 commits `test/golden/phase_55_single_tenant_access.tbl`,
`test/golden/phase_55_effect_observations.json`, `test/golden/phase_55_origin_csrf.tbl`, and
`test/golden/phase_55_network_edges.tbl` before the UI runtime implementation. They independently state the
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
`test/mutants/phase_55_canned_ui_response.dhall`,
`test/mutants/phase_55_open_provider_edge.dhall`, and
`test/mutants/phase_55_drop_ui_networkpolicy.dhall`, plus
`test/mutants/phase_55_disable_csrf_check.patch` and
`test/mutants/phase_55_dispatch_artifact_before_auth.patch`, plus
`test/mutants/phase_55_local_socket_map_only.patch` and
`test/mutants/phase_55_redis_receipt_authority.patch`. The first cannot echo the post-start nonce from
all provider observations; the edge mutants fail the independently observed forbidden-edge table; and the
CSRF/dispatch mutants create forbidden handler or audit bytes even if the public denial is forged.

## Doctrine adopted

- Adopt [`low_code_ui_runtime_doctrine.md` §§13–14 — the generic client/server and HA boundary](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): run one checked program without a bespoke frontend or server.
- Adopt [`platform_services_doctrine.md` §9 — the single authenticated ingress](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path): every browser request crosses Keycloak and Envoy.
- Adopt [`content_addressing_doctrine.md` §4.5 — ready artifact lifecycle](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss): expose only an authorized ready infernix handle.
- Adopt [`testing_doctrine.md` §12 — spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): bind success to fresh provider-observed effects.
- Adopt [`ui_realtime_coordination_doctrine.md` §§4–6](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): force cross-pod WebSocket delivery while durable cursors and receipts remain outside Redis.

## Sprints

## Sprint 55.1: Complete single-tenant UI slice 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Ui/Live/SingleTenant.hs`, `src/Amoebius/Ui/Realtime/RedisCoordination.hs`, `test/live/Phase55UiSingleTenantSpec.hs` (planned; not built)
**Blocked by**: Phases 32, 33, 38, 40, and 50
**Independent Validation**: `cabal test phase55-ui-single-tenant-live` against the pinned tables and provider-owned observations
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/platform_services_doctrine.md`, `documents/engineering/ui_realtime_coordination_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Deliver the one-tenant generic UI runtime path and its externally observed security/effect evidence.

### Deliverables

- The resource-complete live topology and exact bound `ClientPlan`/`UiServerPlan` release.
- At least two UI-server replicas, authenticated WebSocket connection ownership, cross-pod scoped Redis
  fanout, cursor-gap repair, and durable provider/Pulsar receipt lookup without sticky sessions.
- Real OIDC Playwright flow, owner/other-subject matrix, valid-session origin/CSRF negatives, and
  direct-provider denial probes.
- Fresh-nonce SQL/S3/Pulsar/Envoy plus artifact-request/infernix-dispatch evidence capture and committed ledger.
- Five committed mutants that demonstrate the oracle cannot be passed by a canned UI, forged denial, or open
  edge.

### Validation

1. Run `cabal test phase55-ui-single-tenant-live` on `linux-cpu`; require all canonical observations green and
   each named mutant red for its pinned reason.
2. Force the browser WebSocket onto replica A and event/receipt production through replica B, then flush Redis
   between publish and response. Reconnect/cursor/receipt lookup must recover the authoritative outcome once,
   and neither local-only routing nor Redis-as-receipt may pass.

### Remaining Work

The whole sprint is planned; no amoebius implementation or Register-3 result exists.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the single-tenant runtime evidence.
- `documents/engineering/platform_services_doctrine.md` — record the observed authenticated and forbidden edges.
- `documents/engineering/testing_doctrine.md` — link the challenge-bound evidence ledger.

**Cross-references to add:**
- The phase tracker, substrate map, and component inventory must link this gate and its evidence.

## Related Documents

- [Development Plan](README.md)
- [Phase 50 — infernix UI lift](phase_50_infernix_ui_lift.md)
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md)
