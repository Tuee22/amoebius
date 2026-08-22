# Phase 44: Local UI composition

> **Purpose**: Compose authored low-code applications through the generic browser and UI-server runtimes and
> test locally that data, workflow, and ready-artifact interactions preserve authorization and tenant scope.
> **Read this if**: phase 44 is next in the queue, or a later phase depends on what its gate establishes.

Phase 44 delivers the UI local composition; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [app_vs_deployment_doctrine.md](../documents/engineering/app_vs_deployment_doctrine.md), [testing_doctrine.md](../documents/engineering/testing_doctrine.md), and the plan for reaching it is owned here.
Register 2: a real boundary against fake tools.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 44.1: Single-/multi-tenant workflow-to-artifact composition gate ✅](#sprint-441-single-multi-tenant-workflow-to-artifact-composition-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-22. `python3 tools/local_ui_composition_gate.py` passes all fourteen sides on
natural `arm64`, untranslated. Two applications, five interactions, four visible-state rows, four ordered
effect rows, three access rows, five denials, the post-ready workflow challenge, and all five production
mutants pass. Real Chrome and the Darwin loopback-only observer recover the challenge without permitting a
browser/backend bypass. The real five-calculus projection accounts for 55 units, all 20 metrics match, and 65
surfaces join to 78 run-time items. Attestation
`sha256:b459d8ef68ad02e09c56731b1ab0423c28b02ef22cda8ef7db559140c15b8812` binds source
`sha256:08324edd25df15c0…` over 2,269 files. Live infernix/jitML adapters, Keycloak/Envoy, provider storage,
release rollout, replica loss, and HA remain UNVERIFIED.

## Phase Summary

This phase implements one seam: the local composition harness that takes authored `UiSource` applications
through checking, scope/authorization, effect binding, paired-plan compilation, the generic PureScript
interpreter, and the amoebius UI-server boundary. The representative flow queries scoped data, starts and
observes a workflow, receives a server-issued `ReadyArtifactHandle`, and lifts the ready result into a user
interaction. It runs once in fixed single-tenant mode and once with two tenants and two subjects.

The domain handlers are separately authored infernix-shaped and jitML-shaped fakes implementing the same typed
data/workflow/artifact ports that the later real lift phases consume. This gate tests composition of the
amoebius contracts and runtimes, not ML semantics. Application-authored expectations travel with the app;
replica counts, topology, fault schedules, and failover remain absent from app logic.

**Phase scope:** one local end-to-end composition harness over the already built browser and server seams,
accepted by `python3 tools/local_ui_composition_gate.py`; split immediately if work requires a production
domain adapter, live identity/provider/cluster, deployment/HA, a second register, or a substrate.
**Substrate:** none — local browser, authority, server, and fake data/workflow/artifact processes only.
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 2 — boundary integration with fakes.
**Depends on:** [Phase 42](phase_42_ui_browser_interpreter.md) — the generic browser interpreter;
[Phase 43](phase_43_ui_server_boundary.md) — the authenticated scoped UI-server boundary.
**Gate:** `python3 tools/run_phase_gate.py 44` passes the Phase-0-pinned apps, authored interactions,
generated-surface join, fresh challenge, scope pairs, external observations, bypass probes, and seeded mutants
of [Gate integrity](#gate-integrity). It emits a green Register-2 ledger with all live/domain/HA layers
UNVERIFIED.

## Gate integrity

Phase 0 commits both application programs, authored interactions/expectations, access matrix, expected visible
states, raw effect sequence, denial tags, and mutant outcomes before the composition harness exists. The
expected story is not generated from either plan or interpreter.


- **Representative set:** `single_tenant_workflow.dhall` and `multi_tenant_workflow.dhall` compose scoped data
  read/mutation, workflow start/progress/cancel, ready-artifact appearance/use, retry, sign-out, and plan reload.
  One module uses the infernix-shaped fake and one uses the jitML-shaped fake. The multi-tenant case uses
  equal-shaped resources for tenant A and tenant B plus two subjects in tenant A.
- **Pinned oracles:** `test/fixture/ui_local_composition/interactions.tsv` and
  `expected_visible_states.tsv` are application-authored; `access_matrix.tsv` owns own/foreign decisions;
  `expected_effect_sequence.tsv` owns the ordered typed port calls; and `expected_denials.tsv` owns exact
  sanitized responses. Every generated event/route/port must join one authored expectation or fail UNVERIFIED.
- **Independent observation:** Playwright reads DOM/accessibility state. Separate fake data/workflow/artifact
  processes write raw requests and state transitions to harness-owned append-only descriptors, while the OS
  boundary records browser/server/backend network access (`sandbox-exec` on Darwin and `strace` on Linux).
  Runtime self-reports are not an
  oracle.
- **Fresh challenge:** after every process reports ready, the harness creates an unpredictable nonce as tenant
  A's fake workflow input. The browser starts the workflow, the server dispatches it, the fake workflow emits a
  nonce-tagged ready result, and an authored interaction exposes the result. The DOM and raw external effect
  sequence must recover the same nonce and scope.
- **Authority pair and bypass probes:** cryptographically signed own-scope credentials succeed; a credential
  differing only by subject or tenant, a caller-supplied tenant header, a copied tenant-A handle used by tenant
  B, a non-ready handle, and direct browser-to-workflow/data endpoints all refuse with zero forbidden effect
  and no foreign value in DOM, response bytes, cache, or observer logs.
- **Seeded mutants:** `M-drop-handle-tenant` (scope guard deletion), `M-direct-workflow-fetch` (escape-arm
  addition), `M-mix-client-server-plan` (effect/digest swap), `M-ready-before-receipt` (transition guard
  deletion), and `owner_key_swap` (tenant/owner-key swap) are committed and must each turn a distinct
  authored expectation or external observation red.

Passing tests the local composed contract against independent fakes. Infernix/jitML adapters, provider data
isolation, live ingress/identity, release rollout, replica failure, and HA remain UNVERIFIED.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §6 — modules and total composition](../documents/engineering/low_code_ui_runtime_doctrine.md#6-modules-and-total-composition): modules compose by qualified typed identities and explicit ports.
- [`low_code_ui_workflow_lifting.md` §12 — workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux): only ready, scoped, compatible server-issued handles enter interaction state.
- [`low_code_ui_runtime_doctrine.md` §13 — generic client and UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): the two existing runtimes compose without application-specific browser code or a separate server binary.
- [`low_code_ui_runtime_doctrine.md` §17 — verification obligations](../documents/engineering/low_code_ui_runtime_doctrine.md#17-verification-obligations): local browser/server, tenant, workflow, and artifact obligations receive one bounded gate.
- [`app_vs_deployment_doctrine.md` §10 — application-authored expectations](../documents/engineering/app_vs_deployment_doctrine.md#10-application-authored-expectations-are-application-logic): authored interactions travel with the app but cannot select chaos, replicas, or failover.
- [`testing_doctrine.md` §9](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) and [`§12`](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): complete generated enumeration joins an independent authored oracle and a fresh externally observed effect.

## Sprints

## Sprint 44.1: Single-/multi-tenant workflow-to-artifact composition gate ✅

**Status**: Done
**Implementation**: `test/spec/ui/LocalCompositionSpec.hs`,
`test/harness/local_ui_composition/composition.mjs`, `test/fixture/ui_local_composition/`, and
`tools/local_ui_composition_gate.py`
**Blocked by**: [Phase 43](phase_43_ui_server_boundary.md) gate
**Independent Validation**: `python3 tools/local_ui_composition_gate.py` drives authored Playwright
interactions, joins every generated surface, reads raw fake-process/network observations, and requires every
named mutant to fail.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/app_vs_deployment_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Adopt the first complete local low-code application path and demonstrate that generic data/workflow/artifact
ports interoperate without weakening current authorization, scope, public projection, or app/deployment
separation.

### Deliverables

- Two bounded authored applications, their authored interaction/expectation sets, and fake typed domain
  handlers sharing no oracle code with the runtimes.
- End-to-end harness with ephemeral credentials, post-start workflow challenge, Playwright observer,
  append-only raw effect observers, OS network capture, surface-enumeration join, and bypass probes.
- Tenant/subject/artifact paired negatives, mutant configurations, and Register-2 honesty ledger.

### Validation

1. Run `cabal test ui-local-composition-spec`; both applications reach every authored visible state and exact
   typed effect sequence, with every generated surface covered and the fresh nonce recovered end to end.
2. Replay equal-shaped requests under foreign-subject and foreign-tenant credentials and copied/non-ready
   handles; observe the pinned refusal, zero forbidden backend effect, and no foreign bytes in browser/server
   output or caches.
3. Run `M-drop-handle-tenant`, `M-direct-workflow-fetch`, `M-mix-client-server-plan`,
   `M-ready-before-receipt`, and `owner_key_swap`; each turns a distinct independent oracle red.
4. Verify all browser traffic uses the UI-server edge and the ledger leaves live infernix/jitML, Keycloak,
   provider storage, release, replica-loss, and HA behavior UNVERIFIED.

### Remaining Work

None. Live infernix/jitML adapters, Keycloak/edge, provider storage isolation, release rollout, replica loss,
and HA remain explicitly UNVERIFIED for their owning later phases.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record local composed evidence without claiming
  live workflow/provider or HA behavior.
- `documents/engineering/app_vs_deployment_doctrine.md` — record application-authored expectation evidence
  while preserving the deployment-rule exclusion.
- `documents/engineering/testing_doctrine.md` — register the generated-surface/authored-interaction join and
  fresh external workflow observer.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, Register 2, `none` substrate, and harness ownership.
- Later infernix, jitML, live single-/multi-tenant, rollout, isolation, and HA phases — reuse these typed ports
  and expectations without inheriting this fake-only evidence.

## Related Documents

- [Development Plan Tracker](README.md) — numeric order and current status.
- [Phase 42](phase_42_ui_browser_interpreter.md) — the required generic browser runtime.
- [Phase 43](phase_43_ui_server_boundary.md) — the required authenticated scoped server boundary.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — composition, workflow/artifact, tenancy, and honesty contract.
- [Application vs Deployment Doctrine](../documents/engineering/app_vs_deployment_doctrine.md) — authored expectations remain app logic; topology remains operator logic.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — independent oracle, fresh challenge, and external observer rules.
