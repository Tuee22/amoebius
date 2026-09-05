# Phase 42: Haskell browser-interpreter semantics and projection

> **Purpose**: Define the one generic `ClientPlan` interpreter in Haskell, lazily project its PureScript source,
> and constrain its bounded view, event, route, navigation, accessibility, and same-origin request semantics
> without starting a browser.
> **Read this if**: phase 42 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_capability_messaging.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 42.1: Generic `ClientPlan` interpreter and Haskell semantic boundary](#sprint-421-generic-clientplan-interpreter-and-haskell-semantic-boundary-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 41 and every earlier numerical predecessor have passed. The pure Haskell interpreter, projection,
independent oracle, nine production-mutant seams, and acquired serial supervisor are implemented; the complete
integrated gate has not yet passed.

## Phase Summary

**Target capability — NOT VALIDATED.** This phase specifies the generic `ClientPlan` interpreter as Haskell
semantics and a Haskell projection that will lazily emit the PureScript implementation beneath `.build/**`.
The target Haskell semantics are to verify the plan envelope/digest,
decode only public values, render the trusted component catalog with escaped text, execute bounded
state/event/route instructions, and emit typed same-origin port requests. Application authors contribute no
tracked PureScript, JavaScript, HTML, CSS, fetch call, or browser-storage code.

The gate is hardware-free: separately authored Haskell expectations consume the same closed Haskell event
traces and compare exact visible state, requested effects, cancellation, route, and transport-plan values. It
is to check generated-source structure and determinism, but does not start Chromium, a browser engine, a UI server,
or a network service. Browser execution belongs to the post-Phase-49 live UI band.

**Phase scope:** one cohesive claim — Haskell semantics and generation define one generic interpreter for every plan without tracking browser-language source; actual browser execution remains UNVERIFIED.
**Substrate:** none — pure Haskell semantics and lazy source projection only; no browser process, container, cluster, or external service.
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))
**Register:** 1 — pure Haskell semantic and generator checks.
**Depends on:** [Phase 41](phase_41_offline_language_plan.md)
**Gate:** `pb validate phase 42`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `pure-generic-ui-browser-interpreter-semantics` |
| `Subject` | `acquired-ui-browser-interpreter-supervisor` |
| `Command` | `pb validate phase 42` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-ui-browser-interpreter-oracle` |
| `Positive controls` | `ui-browser-interpreter-positive-controls` |
| `Paired negatives` | `exact-ui-browser-interpreter-paired-negatives` |
| `Mutants` | `applied-ui-browser-interpreter-production-mutants` |
| `Discovery` | `exact-ui-browser-interpreter-source-discovery` |
| `Challenge` | `post-acquisition-ui-browser-interpreter-challenge` |
| `Observer` | `ui-browser-interpreter-process-observation` |
| `Authority/bypass` | `no-pb-browser-node-python-network-host-hardware-or-parallelism` |
| `Freshness` | `fresh-ui-browser-interpreter-build-root-and-stable-source` |
| `Qualification` | `qualified-ui-browser-interpreter-harness` |
| `Cleanroom` | `ui-browser-interpreter-products-contained-below-build` |
| `Legacy closure` | `retired-ui-browser-interpreter-authorities-absent` |
| `Predecessor` | `exact-phase-forty-one-receipt` |
| `Residue` | `live-browser-server-provider-release-and-ha-owners-explicit` |
| `Pass criterion` | `qualified-phase-forty-two-gate-pass` |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §7 — State, events, and deterministic updates](../documents/engineering/low_code_ui_runtime_doctrine.md#7-state-events-and-deterministic-updates): Haskell models the closed bounded instruction algebra; browser execution is deferred.
- [`low_code_ui_runtime_doctrine.md` §4.4 — External links are names resolved by a trusted catalog](../documents/engineering/low_code_ui_runtime_doctrine.md#44-external-links-are-names-resolved-by-a-trusted-catalog): external navigation is a fixed catalog projection, never a fetch target.
- [`low_code_ui_runtime_doctrine.md` §13 — Generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): Haskell projects one generic bundle and a same-origin typed-request plan; execution is deferred.
- [`low_code_ui_runtime_doctrine.md` §15 — Versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): Haskell models immutable plan identity and `ReloadRequired`; browser behavior is deferred.
- [`testing_doctrine.md` §9 — Derivation: generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): reachable surfaces and transient bytes are generated; separately authored Haskell expectations constrain semantics.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence): OS-boundary nonce recovery is a post-Phase-49 live-browser obligation, not Phase-42 evidence.
- [`low_code_ui_runtime_doctrine.md` §17 — Verification obligations](../documents/engineering/low_code_ui_runtime_doctrine.md#17-verification-obligations): Phase 42 owns only Haskell trace and projection obligations; keyboard, focus, CSP enforcement, and browser fidelity are deferred.
- [`ui_realtime_coordination_doctrine.md` §3 — One browser transport contract](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract): Haskell models the authenticated same-origin WebSocket and reconnect/cursor plan; no socket is opened here.
- [`illegal_state_capability_messaging.md` §3.82 — A browser effect or provider call escaping the server-mediated capability boundary](../documents/illegal_state/illegal_state_capability_messaging.md#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary): the Haskell algebra has no raw-fetch arm; packet capture and browser escape observation are post-barrier obligations.

## Sprints

## Sprint 42.1: Generic `ClientPlan` interpreter and Haskell semantic boundary ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Browser/{Interpreter,Projection}.hs`, typed cases, production CPP seams, and the package-hidden acquired Phase-42 supervisor.
**Blocked by**: [Phase 41](phase_41_offline_language_plan.md) gate pass
**Independent Validation**: pure trace, stale-envelope, trusted-text, accessibility/focus, same-origin transport, challenge, source-structure, calculus, and nine changed-production checks.
**Oracle**: `test/spec/ui/UiBrowserInterpreterReference.hs`, importing no production or case module.
**Legacy IDs**: exact 25-path browser/Node/Python/serialized/materialized-mutant inventory in `UiBrowserInterpreterRun.Internal`.
**Docs to update**: this plan, the tracker/component/substrate maps, and the four doctrine owners named below.

### Objective

Define the generic client semantics so the bounded checked plan is the entire application-specific UI payload.
The Haskell algebra provides no raw rendering, network, authority, or persistence escape to application
authors.

### Deliverables

- A Haskell `ClientPlan` decoder/interpreter, trusted-component rendering semantics, deterministic
  event/update/route semantics, and typed HTTPS-bootstrap and same-origin WebSocket request-plan values. No
  socket is opened.
- A closed Haskell trace corpus joined two ways to separately authored Haskell expectations for visible state,
  accessibility state, keyboard/focus transitions, navigation, cancellation, reconnect, and cursor values.
- Haskell projection and generated-source structure checks, paired-negative and changed-subject mutation
  declarations, and a lazily rendered `.build/**` honesty ledger. PureScript, JavaScript, HTML, CSS, and every
  other external form are generated only beneath `.build/**`.

### Validation

1. Require two-way equality between the independently declared surface universe and the surfaces discovered
   from the closed Haskell trace corpus. Empty discovery and every omitted event, route, link, or port fail.
2. Compare every pure interpreter trace with a separately authored Haskell expectation. The comparison covers
   exact visible state, accessibility state, keyboard/focus transitions, navigation, cancellation, reconnect,
   cursor, and typed request-plan values without executing projected browser code.
3. Exercise minimally different Haskell pairs for invalid envelopes, private-value disclosure, unknown links,
   raw-fetch attempts, forbidden persistence, stale challenges, and canned responses. Each pair must produce
   its pinned reason and zero forbidden requested effects.
4. Generate the browser-language projection twice from a clean input beneath `.build/**`. A separately authored
   Haskell structure oracle must reject remote imports, inline evaluation, raw provider facilities, forbidden
   persistence APIs, and link-as-fetch reuse while accepting the unchanged control.
5. Witness every changed production Haskell locus before running its named semantic, accessibility, artifact,
   freshness, and request-plan mutant. Each mutant must produce its distinct named Haskell-oracle mismatch,
   while the unaffected control remains equal to its independently declared observation.
6. Record browser execution, browser accessibility fidelity, CSP enforcement, OS network isolation, server
   authority, provider isolation, live edge, release, and HA as post-barrier UNVERIFIED residue.

### Remaining Work

The complete integrated Phase-42 gate and mechanical status projection remain. UI-server authority, real browser fidelity, live provider isolation, release rollout, and HA remain later-phase claims.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record local generic-interpreter evidence without
  claiming live or server enforcement.
- `documents/engineering/generated_artifacts_doctrine.md` — record the generic-bundle build and per-app plan
  boundary.
- `documents/engineering/testing_doctrine.md` — record the independent Haskell trace differential,
  keyboard/focus model, generated-source structure check, and deferred browser-fidelity boundary.
- `documents/illegal_state/illegal_state_capability_messaging.md` — attach the Haskell browser-escape case
  declarations and changed-subject mutations, plus the post-barrier observer and challenge obligations.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, Register 1, `none` substrate, and target modules.
- Phase 44 — consume this interpreter unchanged in the local composed application.

## Related Documents

- [Phase 10](phase_10_calculus_composition.md) — the five-calculus Haskell composition projected by this gate.
- [Phase 40](phase_40_ui_plan_compiler.md) — the required immutable `ClientPlan` and public contracts.
- [Phase 41](phase_41_offline_language_plan.md) — the immediately preceding paired-plan boundary.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — generic-client boundary and verification obligations.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — authored expectations and spoof-resistant evidence.
- [Illegal-State Capability/Messaging Slice](../documents/illegal_state/illegal_state_capability_messaging.md) — browser/provider escape foreclosure.
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — the fixed
  browser wire and cursor-resume semantics interpreted here.
