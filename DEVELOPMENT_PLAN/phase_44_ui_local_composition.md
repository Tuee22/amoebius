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

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

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
**Gate:** `pb validate phase 44`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — Haskell client semantics, server policy, and generated fake domain ports compose over Haskell cases without a browser or live service. Any external-language bytes are lazy `.build/**` output; identity/provider/cluster/deployment behavior is not claimed. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 44` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 43; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §6 — Modules and total composition](../documents/engineering/low_code_ui_runtime_doctrine.md#6-modules-and-total-composition): modules compose by qualified typed identities and explicit ports.
- [`low_code_ui_workflow_lifting.md` §12 — Workflows and artifact lifting into the UX](../documents/engineering/low_code_ui_workflow_lifting.md#12-workflows-and-artifact-lifting-into-the-ux): only ready, scoped, compatible server-issued handles enter interaction state.
- [`low_code_ui_runtime_doctrine.md` §13 — Generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): Haskell client semantics and server policy compose without application-specific tracked browser code or another binary; browser execution is deferred.
- [`low_code_ui_runtime_doctrine.md` §17 — Verification obligations](../documents/engineering/low_code_ui_runtime_doctrine.md#17-verification-obligations): Phase 44 owns Haskell semantic composition only; real browser/server, tenant, workflow, and artifact observations are post-barrier obligations.
- [`app_vs_deployment_doctrine.md` §10 — Application-authored expectations are application logic](../documents/engineering/app_vs_deployment_doctrine.md#10-application-authored-expectations-are-application-logic): authored interactions travel with the app but cannot select chaos, replicas, or failover.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) and [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): Haskell-generated enumeration joins separately reviewed Haskell expectations; fresh external effects are deferred beyond Phase 49.

## Sprints

> **Reset validation review.** This sprint remains REJECTED — NOT VALIDATED until its fixed Haskell
> subject/oracle/reviewer/mutant/legacy contract is complete and independently reviewed. The target boundaries
> below use Haskell fake interpreters and authorize no browser, OS, network, provider, or hardware process.

## Sprint 44.1: Single-/multi-tenant workflow-to-artifact composition gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 43](phase_43_ui_server_boundary.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Define the first complete hardware-free low-code composition over Haskell client semantics, Haskell server
policy, and typed fake data/workflow/artifact ports. The composition must preserve authorization, scope,
public projection, and application/deployment separation.

### Deliverables

- Two bounded Haskell-authored applications, their Haskell-authored interaction sets, and typed Haskell fake
  domain handlers. Separately reviewed Haskell expectations share no subject code with the composed runtimes.
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

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. Live infernix/jitML adapters, Keycloak/edge, provider storage isolation, release rollout, replica loss,
and HA remain explicitly UNVERIFIED for their owning later phases.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
