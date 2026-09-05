# Phase 44: Hardware-free Haskell UI composition

> **Purpose**: Compose external/untracked low-code shapes through the Haskell client semantics, UI-server
> boundary, and fake domain ports, modeling authorization and tenant-scope plans without browser or hardware.
> **Read this if**: phase 44 is next in the queue, or a later phase depends on what its gate establishes.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, documents/engineering/app_vs_deployment_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 44.1: Single-/multi-tenant workflow-to-artifact composition gate](#sprint-441-single-multi-tenant-workflow-to-artifact-composition-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 43 and every earlier numerical predecessor have passed. The pure Haskell composition, typed cases,
independent oracle, five production-mutant seams, and acquired serial supervisor are implemented; the complete
integrated gate has not yet passed.

## Phase Summary

**Target capability — NOT VALIDATED.** This phase is to compose external/untracked `UiSource` values and
Haskell-generated cases through checking,
scope/authorization, effect binding, paired-plan compilation, the Phase-42 Haskell interpreter semantics, and
the Phase-43 Haskell server boundary. Representative Haskell values query scoped data, start and observe a
workflow, receive a `ReadyArtifactHandle`, and lift the result into a user interaction under one- and
two-tenant cases.

Separately authored Haskell fake adapters are to implement the typed data/workflow/artifact ports. The target gate is to check
composition and exact boundary requests without starting a browser, a domain provider, or live
infrastructure. Any external-language encoding or fake executable is generated run-locally beneath
`.build/**`.

**Phase scope:** one hardware-free composition claim over the Haskell UI semantics and fake server/domain boundaries; actual browser, identity, provider, cluster, deployment, and HA behavior remain UNVERIFIED.
**Substrate:** none — Haskell values and run-local fake boundaries only; no browser, container, cluster, or hardware-specific process.
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 2 — boundary integration with fakes.
**Depends on:** [Phase 43](phase_43_ui_server_boundary.md)
**Gate:** `pb validate phase 44`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `hardware-free-haskell-ui-composition` |
| `Subject` | `acquired-ui-local-composition-supervisor` |
| `Command` | `pb validate phase 44` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-ui-local-composition-oracle` |
| `Positive controls` | `ui-local-composition-positive-controls` |
| `Paired negatives` | `exact-ui-local-composition-paired-negatives` |
| `Mutants` | `applied-ui-local-composition-production-mutants` |
| `Discovery` | `exact-ui-local-composition-source-discovery` |
| `Challenge` | `post-acquisition-ui-local-composition-challenge` |
| `Observer` | `ui-local-composition-process-observation` |
| `Authority/bypass` | `no-pb-node-dhall-network-live-provider-host-hardware-or-parallelism` |
| `Freshness` | `fresh-ui-local-composition-build-root-and-stable-source` |
| `Qualification` | `qualified-ui-local-composition-harness` |
| `Cleanroom` | `ui-local-composition-products-contained-below-build` |
| `Legacy closure` | `retired-ui-local-composition-authorities-absent` |
| `Predecessor` | `exact-phase-forty-three-receipt` |
| `Residue` | `live-workflow-provider-browser-deployment-release-and-ha-owners-explicit` |
| `Pass criterion` | `qualified-phase-forty-four-gate-pass` |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §6 — Modules and total composition](../documents/engineering/low_code_ui_runtime_doctrine.md#6-modules-and-total-composition): modules compose by qualified typed identities and explicit ports.
- [`low_code_ui_workflow_lifting.md` §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux): only ready, scoped, compatible server-issued handles enter interaction state.
- [`low_code_ui_runtime_doctrine.md` §13 — Generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): Haskell client semantics and server policy compose without application-specific tracked browser code or another binary; browser execution is deferred.
- [`low_code_ui_runtime_doctrine.md` §17 — Verification obligations](../documents/engineering/low_code_ui_runtime_doctrine.md#17-verification-obligations): Phase 44 owns Haskell semantic composition only; real browser/server, tenant, workflow, and artifact observations are post-barrier obligations.
- [`app_vs_deployment_doctrine.md` §10 — Application-authored expectations are application logic](../documents/engineering/app_vs_deployment_doctrine.md#10-application-authored-expectations-are-application-logic): authored interactions travel with the app but cannot select chaos, replicas, or failover.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) and [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): Haskell-generated enumeration joins separately authored Haskell expectations; fresh external effects are deferred beyond Phase 49.

## Sprints

## Sprint 44.1: Single-/multi-tenant workflow-to-artifact composition gate ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/LocalComposition.hs`, typed cases, production CPP seams, and the package-hidden acquired Phase-44 supervisor.
**Blocked by**: [Phase 43](phase_43_ui_server_boundary.md) gate pass
**Independent Validation**: two application shapes, visible/effect/access/denial rows, plan identity, direct bypass, calculus, and five changed-production checks.
**Oracle**: `test/spec/ui/UiLocalCompositionReference.hs`, importing no production or case module.
**Legacy IDs**: exact 15-path Node/Python/serialized/materialized-mutant inventory in `UiLocalCompositionRun.Internal`.
**Docs to update**: this plan, tracker/component/substrate maps, and the three doctrine owners named below.

### Objective

Define the first complete hardware-free low-code composition over Haskell client semantics, Haskell server
policy, and typed fake data/workflow/artifact ports. The composition must preserve authorization, scope,
public projection, and application/deployment separation.

### Deliverables

- Two bounded Haskell-authored applications, their Haskell-authored interaction sets, and typed Haskell fake
  domain handlers. Separately authored Haskell expectations share no subject code with the composed runtimes.
- An in-process Haskell composition harness with run-scoped credential values, a challenge injected after fake
  initialization, append-only typed effect observations, a two-way surface join, and authority-bypass probes.
- Haskell-authored tenant/subject/artifact paired negatives and mutation declarations, plus a lazily rendered
  `.build/**` Register-2 honesty ledger.

### Validation

1. Require both Haskell applications to reach every declared visible state and exact typed fake-effect
   sequence. Two-way discovery must cover every generated surface, and the independent observer must recover
   the challenge injected after fake initialization.
2. Replay equal-shaped values under foreign-subject and foreign-tenant credentials and copied or non-ready
   handles. Require the pinned refusal, zero forbidden fake-domain effect, and no foreign bytes in Haskell
   client state, server responses, or fake caches.
3. Run `M-drop-handle-tenant`, `M-direct-workflow-fetch`, `M-mix-client-server-plan`,
   `M-ready-before-receipt`, and `owner_key_swap`. Each changed production Haskell locus must be witnessed and
   produce its distinct named Haskell-oracle mismatch. The unaffected control must remain equal to its
   independently declared observation.
4. Require every client request-plan value to address only the typed UI-server fake port. No network traffic is
   generated. Actual browser/server execution, infernix/jitML, Keycloak, provider storage, release,
   replica-loss, and HA behavior remain post-barrier UNVERIFIED residue.

### Remaining Work

The complete integrated Phase-44 gate and mechanical status projection remain. Live infernix/jitML adapters, Keycloak/edge, provider storage isolation, release rollout, replica loss,
and HA remain explicitly UNVERIFIED for their owning later phases.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record local composed evidence without claiming
  live workflow/provider or HA behavior.
- `documents/engineering/app_vs_deployment_doctrine.md` — record application-authored expectation evidence
  while preserving the deployment-rule exclusion.
- `documents/engineering/testing_doctrine.md` — register the generated-surface/authored-interaction join and
  fresh Haskell fake-boundary challenge and independent typed-effect observer.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, Register 2, `none` substrate, and harness ownership.
- Later infernix, jitML, live single-/multi-tenant, rollout, isolation, and HA phases — reuse these typed ports
  and expectations without inheriting this fake-only evidence.

## Related Documents

- [Development Plan Tracker](README.md) — numeric order and current status.
- [Phase 42](phase_42_ui_browser_interpreter.md) — the required generic Haskell client semantics and lazy
  runtime projection.
- [Phase 43](phase_43_ui_server_boundary.md) — the required authenticated scoped server boundary.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — composition, workflow/artifact, tenancy, and honesty contract.
- [Application vs Deployment Doctrine](../documents/engineering/app_vs_deployment_doctrine.md) — authored expectations remain app logic; topology remains operator logic.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — independent Haskell oracle, fresh fake
  challenge, and typed-effect observer rules.
