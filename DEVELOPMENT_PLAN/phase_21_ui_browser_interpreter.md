# Phase 21: UI browser interpreter

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_23_ui_local_composition.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Build the one generic PureScript browser interpreter for immutable `ClientPlan` values and
> validate its bounded view, event, route, navigation, accessibility, and same-origin effect behavior against
> an independent Haskell reference semantics and authored browser observations.

---

## Phase Status

📋 Planned. This phase supplies Register-2 evidence against a fake UI server on no cluster. Live identity,
authorization, provider isolation, release rollout, and HA behavior remain UNVERIFIED.

## Phase Summary

This phase implements one seam: the generic PureScript `ClientPlan` interpreter. It verifies the plan
envelope/digest, decodes only public values, renders the trusted component catalog with escaped text, executes
bounded deterministic state/event/route instructions, and emits typed same-origin port requests. Application
authors contribute no PureScript, JavaScript, HTML, CSS, fetch call, or browser-storage code, and an
application-specific plan never rebuilds the generic bundle.
The fixed online transport is HTTPS for bootstrap/assets/uploads/downloads and one authenticated same-origin
WebSocket for ports, completions, subscriptions, replay outcomes, and cursor control. The browser has no
transport selector, SSE fallback, direct Pulsar client, or Redis knowledge.

The gate joins the generated enumeration of reachable events, routes, links, and ports to independently
authored interactions and expected browser/transport observations. A small test-only Haskell interpreter,
implemented without the PureScript transition helpers, consumes the same generated event traces and must agree
step-for-step on visible state, requested effects, cancellations, and route transitions. It uses a fake UI
server only as a boundary peer; server authorization semantics belong to Phase 22.

**Session scope:** one generic `ClientPlan` browser interpreter and its differential/Playwright conformance harness;
acceptance command `cabal test ui-browser-interpreter-spec`; split immediately if work requires server policy
evaluation, a second production interpreter, a live identity/provider service, release publication, a second
register, or a substrate.
**Dependency:** Phase 20 — canonical immutable `ClientPlan` encoding and public contracts.
**Substrate:** none — local Chromium and harness-owned fake processes only; no cluster or external service.
**Register:** 2 — boundary integration with fakes.
**Gate:** `cabal test ui-browser-interpreter-spec` builds the generic bundle and passes the Phase-0-pinned
plans/interactions, complete generated-enumeration join, post-start fresh-challenge round trip, independent DOM
and OS-boundary network observations, differential traces, keyboard/focus sequences, built-artifact/CSP
checks, bypass negatives, and every seeded mutant in
[Gate integrity](#gate-integrity). Phase 23 does not open on the browser branch unless this one command emits a
green Register-2 ledger with live layers UNVERIFIED.

## Gate integrity

Phase 0 commits all plans, interactions, expected state traces, DOM/accessibility snapshots, keyboard/focus
sequences, transport rows, security-header policy, artifact allowlist, and mutant expectations before the
interpreter exists. Expected outcomes are authored independently; they are never generated from `ClientPlan`
or renderer output.

- **Representative set:** minimal single-tenant and multi-tenant plans cover text/number/bool/optional/record/
  variant values; forms and validation; bounded lists/tables; modal/error/progress states; nested routes;
  every event instruction; cancellation; one fixed named external-link navigation; and one request for each
  public effect class.
- **Pinned oracles:** `test/fixtures/ui_browser/plans/`, `interactions.tsv`, `expected_dom/`,
  `expected_accessibility.tsv`, `expected_keyboard_focus.tsv`, `reference_traces.tsv`,
  `expected_transport.tsv`, `test/fixtures/ui_security/production_headers.tsv`, and
  `artifact_allowlist.tsv` own the inputs and
  outcomes. Every generated event/route/link/port identity must join one authored interaction and expectation;
  an unmatched identity emits UNVERIFIED and fails the gate.
- **Differential semantics:** a separately implemented test-only Haskell interpreter consumes each generated
  event trace and emits the expected visible-state, effect-request, cancellation, and route-transition tuple
  for every step. The Playwright/OS observations of the PureScript interpreter must match exactly; the
  reference side imports no production compiler or PureScript transition implementation.
- **Independent observation:** Playwright reads the browser DOM/accessibility tree. A harness-owned loopback
  proxy plus OS network-namespace packet capture, outside the bundle and fake server, records every destination,
  method, path, and body digest; self-emitted client “sent” traces are ignored.
- **Accessibility and browser hardening:** authored keyboard-only sequences pin focus entry, trap, restoration,
  error-summary navigation, and route-change focus. An independent scanner inspects the built bundle for
  inline/eval-like code, dynamic remote imports, forbidden storage/network APIs, provider strings, secrets,
  and server-handle codecs. The harness serves the exact pinned production CSP/security-header set and proves
  in Chromium that inline/eval/canary execution is blocked; a header string comparison alone cannot pass.
- **Fresh challenge:** after Chromium and the fake server report ready, the harness issues an unpredictable
  nonce in a fake public response. An authored interaction carries it through state, rendering, and one typed
  port request; the OS-boundary observer must recover the same nonce. Fixed output, stale state, or a replayed
  transcript cannot pass.
- **Specific negatives and bypass probes:** malformed/over-bound/unknown plans, unescaped hostile text,
  forbidden persistence, stale digest, unknown route/event/port, direct provider URL, and a blocked canary
  endpoint each have a paired positive and pinned failure. The one catalog-resolved external link may cause
  only a user-initiated top-level navigation to its exact HTTPS destination with fixed `noopener`/`noreferrer`;
  it cannot be reused as fetch/media/form transport or receive app/session data. Packet capture must otherwise
  show only the sanctioned same-origin fake-server edge and zero canary/provider connections.
- **Seeded mutants:** `M-raw-html-sink` (trusted-sink guard deletion), `M-drop-event-effect` (dropped effect),
  `M-swap-route-target` (effect swap), `M-accept-stale-plan` (freshness guard deletion), and
  `M-direct-provider-fetch` (escape-arm addition), plus `M-sequential-state-writes` (semantic-order change),
  `M-break-focus-return` (accessibility transition deletion), `M-unsafe-inline-build` (artifact/CSP escape),
  and `M-hardcoded-response` (fresh-challenge bypass), are committed and must each turn the gate red.

The fake server does not establish server authorization truth. No real credentials are used in this phase;
authority-paired own/foreign enforcement is owned by the UI-server boundary and later live gates.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §7 — state, events, and deterministic updates](../documents/engineering/low_code_ui_runtime_doctrine.md#7-state-events-and-deterministic-updates): the browser executes the closed bounded instruction algebra.
- [`low_code_ui_runtime_doctrine.md` §4.4 — trusted external-link catalog](../documents/engineering/low_code_ui_runtime_doctrine.md#44-external-links-are-names-resolved-by-a-trusted-catalog): external navigation is a fixed catalog projection, never a fetch target.
- [`low_code_ui_runtime_doctrine.md` §13 — generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server): one generic bundle interprets per-app plans and emits only same-origin typed requests.
- [`low_code_ui_runtime_doctrine.md` §15 — versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): the client verifies immutable plan identity and returns `ReloadRequired` behavior on incompatibility.
- [`testing_doctrine.md` §9 — generated enumeration, authored expectation](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation): reachable surfaces are generated; interactions and expected outcomes are committed independent source.
- [`testing_doctrine.md` §12 — spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect): the post-start nonce is recovered from an external OS-boundary observer.
- [`low_code_ui_runtime_doctrine.md` §17 — verification obligations](../documents/engineering/low_code_ui_runtime_doctrine.md#17-verification-obligations): the Haskell/PureScript traces, keyboard/focus behavior, CSP, and artifact surface agree with independent pins.
- [`ui_realtime_coordination_doctrine.md §3 — one browser transport contract`](../documents/engineering/ui_realtime_coordination_doctrine.md#3-one-browser-transport-contract): the interpreter uses the fixed authenticated same-origin WebSocket and reconnect/cursor protocol.
- [`illegal_state_capability_messaging.md` §3.82](../documents/illegal_state/illegal_state_capability_messaging.md#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary): packet capture and the direct-fetch mutant cover the browser escape residue.

## Sprints

## Sprint 21.1: Generic `ClientPlan` interpreter and browser boundary gate 📋

**Status**: Planned
**Implementation**: `ui-runtime/src/Amoebius/Ui/{Interpreter,Components}.purs`,
`test/ui/{Phase21UiBrowserInterpreterSpec,ReferenceClientPlan}.hs`, `test/ui/browser/`, and
`test/ui/scan-ui-artifact` (target authored sources; not yet built)
**Blocked by**: Phase 20
**Independent Validation**: `cabal test ui-browser-interpreter-spec` builds via `spago`, drives Chromium with
authored Playwright interactions, reads DOM plus OS-boundary traffic, and requires every named mutant to fail.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`,
`documents/illegal_state/illegal_state_capability_messaging.md`

### Objective

Adopt the fixed browser runtime so the bounded checked plan is the entire application-specific UI payload and
no raw rendering, network, authority, or persistence escape is available to app authors.

### Deliverables

- Generic plan decoder/interpreter, trusted component renderer, deterministic event/update engine, route
  machine, HTTPS bootstrap path, and authenticated same-origin WebSocket transport with bounded reconnect and
  cursor-resume control frames.
- Generated surface enumerator joined to authored interactions, fresh-challenge fake server, Playwright DOM/
  accessibility/keyboard reader, independent Haskell trace interpreter, and OS-boundary network observer.
- Built-bundle scanner, exact CSP/security-header browser harness, boundary corpus, bypass probes, mutant
  configurations, and Register-2 honesty ledger.

### Validation

1. Run `cabal test ui-browser-interpreter-spec`; every enumerated event/route/link/port is covered by an authored
   interaction and expected state/DOM/accessibility/keyboard/transport row, with no UNVERIFIED coverage entry.
2. Require every PureScript step to match the independent Haskell trace tuple and execute the pinned keyboard
   focus sequences without a divergence.
3. Recover the post-start nonce from the externally observed request and assert packet capture contains no
   provider/canary connection, unknown destination, or forbidden persistence path.
4. Scan the built bundle, enforce the pinned CSP in Chromium, and exercise the exact named-link navigation;
   inline/eval/canary execution, remote imports, forbidden APIs, and link-as-fetch reuse stay absent.
   The network trace contains the one expected same-origin WebSocket upgrade and no SSE, Redis, Pulsar, or
   provider connection.
5. Run every named semantic, accessibility, artifact, freshness, network, and canned-response mutant; each
   turns its distinct authored expectation red.
6. Verify the ledger says browser behavior tested with fakes and leaves server authority, provider isolation,
   live edge, release, and HA UNVERIFIED.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record local generic-interpreter evidence without
  claiming live or server enforcement.
- `documents/engineering/generated_artifacts_doctrine.md` — record the generic-bundle build and per-app plan
  boundary.
- `documents/engineering/testing_doctrine.md` — record the independent differential, keyboard/focus,
  artifact-scan, and browser-enforced CSP evidence.
- `documents/illegal_state/illegal_state_capability_messaging.md` — attach browser escape fixtures, observer,
  challenge, and mutants.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, Register 2, `none` substrate, and target modules.
- Phase 23 — consume this interpreter unchanged in the local composed application.

## Related Documents

- [Phase 20](phase_20_ui_plan_compiler.md) — the required immutable `ClientPlan` and public contracts.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — generic-client boundary and verification obligations.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — authored expectations and spoof-resistant evidence.
- [Illegal-State Capability/Messaging Slice](../documents/illegal_state/illegal_state_capability_messaging.md) — browser/provider escape foreclosure.
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — the fixed
  browser wire and cursor-resume semantics interpreted here.
