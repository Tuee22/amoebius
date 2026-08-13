# Phase 23: Local UI composition

> **Purpose**: Compose authored low-code applications through the generic browser and UI-server runtimes and
> test locally that data, workflow, and ready-artifact interactions preserve authorization and tenant scope.
> **Read this if**: phase 23 is next in the queue, or a later phase depends on what its gate establishes.

Phase 23 delivers the UI local composition; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [app_vs_deployment_doctrine.md](../documents/engineering/app_vs_deployment_doctrine.md), [testing_doctrine.md](../documents/engineering/testing_doctrine.md), and the plan for reaching it is owned here.
Register 2: a real boundary against fake tools.
Gate passed on 2026-08-09 with ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 23.1: Single-/multi-tenant workflow-to-artifact composition gate ✅](#sprint-231-single-multi-tenant-workflow-to-artifact-composition-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-13. The migrated gate passed against source snapshot `sha256:d08a350888547a54…`
(1946 non-ignored files) and published verified external attestation
`sha256:363ae0c7c14e334f0455a1ffb67c9ce14eae0f33c736ca555187b076f596bc1a`.

**Observed progress — 2026-08-13:** **Policy-conformant.** Two Dhall-typed applications drive one generic
browser bundle against the real `serve-ui` boundary and two separately started domain-shaped fake processes:
five interactions join the generated action set, four visible states and the ordered three-step effect
sequence match their pins with the fresh nonce reaching both the DOM and the raw effect log, four denials
return their pinned status and tag with zero private bytes, the direct-to-backend probe is refused at the
network, and all five mutants redden. Evidence and the ledger move into `gen/runs/phase_23/<run-id>/`, and 58
surfaces join two-way to 71 run-time enumerated items.

**The composition only became runnable when Phase 22's ABI landed.** `use-artifact` had no row in the closed
action table, so the third step of the workflow returned the non-enumerating refusal and the artifact result
never appeared. The table now carries one row per Phase-19 port effect.

**One mutant detector was looking for the wrong success code.** `M-drop-handle-tenant` reports the foreign
tenant's copied handle being accepted, and the harness tested for status 200 exactly. `use-artifact` is a
mutation, so the boundary answers 202 — the attack landed and the detector called it a miss. It now tests for
any 2xx, which is what "accepted" means.

**The suite stopped naming one machine.** It resolved the amoebius binary through an absolute
`~/.ghcup/bin/cabal-3.16.1.0` and typechecked its Dhall through an absolute `~/.local/bin/dhall`. Both now
come from the gate's resolution, with PATH as the fallback.

**Invalidated historical record:**

✅ Done. Two Dhall-authored applications reuse one generic bundle and the `serve-ui` boundary in real Chrome.
Five interactions join all three generated workflow surfaces; four visible pins, four ordered-effect rows,
three access rows, five denials, a fresh workflow-to-artifact nonce, 36 loopback network syscalls, and all five
mutants pass. This is Register-2 evidence with separate infernix-/jitML-shaped fakes, not live adapters,
Keycloak, provider storage, release, replica-loss, or HA evidence. See the
Phase-23 ledger.

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

**Session scope:** one local end-to-end composition harness over the already built browser and server seams;
acceptance command `python3 tools/phase23_gate.py`; split immediately if work requires a production
domain adapter, live identity/provider/cluster, deployment/HA, a second register, or a substrate.
**Dependencies:** Phase 21 — generic browser interpreter; Phase 22 — authenticated scoped UI-server boundary.
**Substrate:** none — local browser, authority, server, and fake data/workflow/artifact processes only.
**Register:** 2 — boundary integration with fakes.
**Gate:** `python3 tools/phase23_gate.py` passes the Phase-0-pinned single-/multi-tenant apps and authored
interactions, complete generated-surface join, post-start workflow/artifact challenge, own/foreign scope pairs,
independent DOM and OS-boundary effect observations, direct-bypass probes, and every seeded mutant in
[Gate integrity](#gate-integrity). Phase 24 does not open unless this command emits a green Register-2 ledger
with all live/domain/HA layers UNVERIFIED.

## Gate integrity

Phase 0 commits both application programs, authored interactions/expectations, access matrix, expected visible
states, raw effect sequence, denial tags, and mutant outcomes before the composition harness exists. The
expected story is not generated from either plan or interpreter.

- **Representative set:** `single_tenant_workflow.dhall` and `multi_tenant_workflow.dhall` compose scoped data
  read/mutation, workflow start/progress/cancel, ready-artifact appearance/use, retry, sign-out, and plan reload.
  One module uses the infernix-shaped fake and one uses the jitML-shaped fake. The multi-tenant case uses
  equal-shaped resources for tenant A and tenant B plus two subjects in tenant A.
- **Pinned oracles:** `test/fixtures/ui_local_composition/interactions.tsv` and
  `expected_visible_states.tsv` are application-authored; `access_matrix.tsv` owns own/foreign decisions;
  `expected_effect_sequence.tsv` owns the ordered typed port calls; and `expected_denials.tsv` owns exact
  sanitized responses. Every generated event/route/port must join one authored expectation or fail UNVERIFIED.
- **Independent observation:** Playwright reads DOM/accessibility state. Separate fake data/workflow/artifact
  processes write raw requests and state transitions to harness-owned append-only descriptors, while `strace`
  records browser/server/backend `connect`/`sendto` calls. Runtime self-reports are not an
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

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §6 — modules and total composition](../documents/engineering/low_code_ui_runtime_doctrine.md#6-modules-and-total-composition): modules compose by qualified typed identities and explicit ports.
- [`low_code_ui_runtime_doctrine.md` §12 — workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux): only ready, scoped, compatible server-issued handles enter interaction state.
- [`low_code_ui_runtime_doctrine.md` §13 — generic client and UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): the two existing runtimes compose without application-specific browser code or a separate server binary.
- [`low_code_ui_runtime_doctrine.md` §17 — verification obligations](../documents/engineering/low_code_ui_runtime_doctrine.md#17-verification-obligations): local browser/server, tenant, workflow, and artifact obligations receive one bounded gate.
- [`app_vs_deployment_doctrine.md` §10 — application-authored expectations](../documents/engineering/app_vs_deployment_doctrine.md#10-application-authored-expectations-are-application-logic): authored interactions travel with the app but cannot select chaos, replicas, or failover.
- [`testing_doctrine.md` §9](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) and [`§12`](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): complete generated enumeration joins an independent authored oracle and a fresh externally observed effect.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 23.1: Single-/multi-tenant workflow-to-artifact composition gate ✅

**Status**: Done — the composition runs end to end on the Phase-22 boundary; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `test/ui/Phase23LocalCompositionSpec.hs`,
`test/ui/local/phase23_local_composition.mjs`, `test/fixtures/ui_local_composition/`, and
`tools/phase23_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `python3 tools/phase23_gate.py` drives authored Playwright
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

- [Phase 21](phase_21_ui_browser_interpreter.md) — the required generic browser runtime.
- [Phase 22](phase_22_ui_server_boundary.md) — the required authenticated scoped server boundary.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — composition, workflow/artifact, tenancy, and honesty contract.
- [Application vs Deployment Doctrine](../documents/engineering/app_vs_deployment_doctrine.md) — authored expectations remain app logic; topology remains operator logic.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — independent oracle, fresh challenge, and external observer rules.
