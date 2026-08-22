# Phase 81: Single-tenant low-code UI live path

> **Purpose**: Prove one generic low-code application through the real authenticated edge, data capabilities,
> workflow runtime, projection path, and infernix interaction without any application-specific browser code.
> **Read this if**: phase 81 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: DEVELOPMENT_PLAN/phase_69_spa_live_deploy.md (single-tenant portion)
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 81.1: Complete single-tenant UI slice ⏸️](#sprint-811-complete-single-tenant-ui-slice-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 80, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** This phase must become the first complete live application slice. One
checked UI program must run in the generic browser interpreter and UI-server responsibility behind Keycloak
and Envoy. Its typed ports must exercise SQL, object storage, Pulsar-backed workflow state, owner-scoped
projections, and a ready infernix artifact. The future gate tests the
single-tenant path only; multiple tenants, rollout continuity, and failure-domain redundancy remain separate
phases.
The target topology must use at least two ready UI-server replicas without sticky routing. The future gate pins a browser socket
to replica A, originates a projection event and command receipt through replica B, and requires scoped Redis
fanout plus durable cursor/receipt repair to deliver them to A. That candidate may establish bounded cross-pod
routing only, not HA, and cannot promote itself.

**Supporting observation:** a phase-number-neutral Haskell single-tenant live suite may exercise the seam; the
sole acceptance command is `pb validate phase 81`. Split if completion requires a second tenant, a release
transition, or a replica/failure-domain fault claim.

**Phase scope:** one cohesive target claim — *one generic application must run end to end with no
application-specific browser code*. Everything the application needs must be a plan supported by the future
human-approved predecessor interpreter.

**Substrate:** `linux-cpu` ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 80](phase_80_determinism_jitcache.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 81`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | one cohesive claim — *one generic application runs end to end with no application-specific browser code*. Everything the application needs must be a plan supported by the human-approved predecessor interpreter. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 81` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | MISSING — blocks validation: the current Phase 80 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6) — single-tenant low-code UI live path carries an identity boundary, and S1-S6 are what make crossing it unrepresentable.
- Adopt [`low_code_ui_runtime_doctrine.md` §13 — Generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server)
  and [`low_code_ui_runtime_doctrine.md` §14 — Runtime role, deployment, and high availability](../documents/engineering/low_code_ui_runtime_doctrine.md#14-runtime-role-deployment-and-high-availability): run one checked program without a bespoke frontend or server.
- Adopt [`platform_services_doctrine.md` §9 — The LoadBalancer and the single wild-ingress path](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path): every browser request crosses Keycloak and Envoy.
- Adopt [`content_addressing_determinism.md` §4.5 — The ML-asset lifecycle: one bounded content-addressed cache, resolved on first miss](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss): expose only an authorized ready infernix handle.
- Adopt [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): bind success to fresh provider-observed effects.
- Adopt [`ui_realtime_coordination_doctrine.md` §4 — Typed routing and resume envelope](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope),
  [`ui_realtime_coordination_doctrine.md` §5 — Redis is ephemeral platform-internal coordination](../documents/engineering/ui_realtime_coordination_doctrine.md#5-redis-is-ephemeral-platform-internal-coordination),
  and [`ui_realtime_coordination_doctrine.md` §6 — Durable commands, receipts, and replay](../documents/engineering/ui_realtime_coordination_doctrine.md#6-durable-commands-receipts-and-replay): force cross-pod WebSocket delivery while durable cursors and receipts remain outside Redis.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.

## Sprint 81.1: Complete single-tenant UI slice ⏸️

**Status**: Blocked — NOT VALIDATED

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

1. Rejected historical observation: the `phase55-ui-single-tenant-live` Cabal suite expected all canonical
   observations green on `linux-cpu` and
   each named mutant red for its pinned reason.
2. Force the browser WebSocket onto replica A and event/receipt production through replica B, then flush Redis
   between publish and response. Reconnect/cursor/receipt lookup must recover the authoritative outcome once,
   and neither local-only routing nor Redis-as-receipt may pass.

### Remaining Work

The portable and local cross-replica slice is implemented; the full provider/browser Register-3 topology remains UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
