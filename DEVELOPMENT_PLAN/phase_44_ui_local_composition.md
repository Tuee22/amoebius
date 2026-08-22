# Phase 44: Hardware-free Haskell UI composition

> **Purpose**: Compose external/untracked low-code shapes through the Haskell client semantics, UI-server
> boundary, and fake domain ports, modeling authorization and tenant-scope plans without browser or hardware.
> **Read this if**: phase 44 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

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
- [Sprint 44.1: Single-/multi-tenant workflow-to-artifact composition gate ⏸️](#sprint-441-single-multi-tenant-workflow-to-artifact-composition-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 43, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, a checked-in generated fixture/oracle/mutant, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

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
**Depends on:** [Phase 43](phase_43_ui_server_boundary.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 44`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | Target only — Haskell client semantics, server policy, and generated fake domain ports compose over Haskell cases without a browser or live service. Any external-language bytes are lazy `.build/**` output; identity/provider/cluster/deployment behavior is not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 44` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 43 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §6 — Modules and total composition](../documents/engineering/low_code_ui_runtime_doctrine.md#6-modules-and-total-composition): modules compose by qualified typed identities and explicit ports.
- [`low_code_ui_workflow_lifting.md` §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux): only ready, scoped, compatible server-issued handles enter interaction state.
- [`low_code_ui_runtime_doctrine.md` §13 — Generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): Haskell client semantics and server policy compose without application-specific tracked browser code or another binary; browser execution is deferred.
- [`low_code_ui_runtime_doctrine.md` §17 — Verification obligations](../documents/engineering/low_code_ui_runtime_doctrine.md#17-verification-obligations): Phase 44 owns Haskell semantic composition only; real browser/server, tenant, workflow, and artifact observations are post-barrier obligations.
- [`app_vs_deployment_doctrine.md` §10 — Application-authored expectations are application logic](../documents/engineering/app_vs_deployment_doctrine.md#10-application-authored-expectations-are-application-logic): authored interactions travel with the app but cannot select chaos, replicas, or failover.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) and [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): Haskell-generated enumeration joins separately reviewed Haskell expectations; fresh external effects are deferred beyond Phase 49.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 44.1: Single-/multi-tenant workflow-to-artifact composition gate ⏸️

**Status**: Blocked — NOT VALIDATED

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

1. Rejected historical observation: the `ui-local-composition-spec` Cabal suite expected both applications to
   reach every authored visible state and exact
   typed effect sequence, with every generated surface covered and the fresh nonce recovered end to end.
2. Replay equal-shaped requests under foreign-subject and foreign-tenant credentials and copied/non-ready
   handles; observe the pinned refusal, zero forbidden backend effect, and no foreign bytes in browser/server
   output or caches.
3. Run `M-drop-handle-tenant`, `M-direct-workflow-fetch`, `M-mix-client-server-plan`,
   `M-ready-before-receipt`, and `owner_key_swap`; each turns a distinct independent oracle red.
4. Verify all browser traffic uses the UI-server edge and the ledger leaves live infernix/jitML, Keycloak,
   provider storage, release, replica-loss, and HA behavior UNVERIFIED.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. Live infernix/jitML adapters, Keycloak/edge, provider storage isolation, release rollout, replica loss,
and HA remain explicitly UNVERIFIED for their owning later phases.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
