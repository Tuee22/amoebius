# Phase 21: Generic browser interpreter

> **Purpose**: Build the one generic PureScript browser interpreter for immutable `ClientPlan` values and
> validate its bounded view, event, route, navigation, accessibility, and same-origin effect behavior against
> an independent Haskell reference semantics and authored browser observations.
> **Read this if**: phase 21 is next in the queue, or a later phase depends on what its gate establishes.

Phase 21 delivers the UI browser interpreter; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [testing_doctrine.md](../documents/engineering/testing_doctrine.md), [ui_realtime_coordination_doctrine.md](../documents/engineering/ui_realtime_coordination_doctrine.md), and the plan for reaching it is owned here.
Register 2: a real boundary against fake tools.
Gate passed on 2026-08-09 with ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_23_ui_local_composition.md, DEVELOPMENT_PLAN/phase_25_base_image_registry.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_capability_messaging.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 21.1: Generic `ClientPlan` interpreter and browser boundary gate ✅](#sprint-211-generic-clientplan-interpreter-and-browser-boundary-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — resealed 2026-08-15. `python3 tools/ui_browser_interpreter_gate.py` passed all eleven sides in
resolved Chrome: two plans, five event arms, four independently derived traces, two DOM snapshots, three
accessibility rows, five focus rows, four transport rows, CSP and WebSocket checks, all nine mutants, and all
sixteen metrics pass; 66 surfaces join to 84 enumerated items. The project-contained attestation is
`sha256:9813b93d168470d07173b797177ef225e38f619edf9320865fa8c9c1ef48a47b`, bound to source snapshot
`sha256:a70b1cd50e69733b…`; Phase 21 owns no remaining migration deferral.

**Pre-containment status record (invalidated where it claims completion):**

✅ Done — sealed 2026-08-13. The migrated gate passed against source snapshot `sha256:05f7d7c56b159a83…`
(1944 non-ignored files) and published a verified pre-containment external attestation
`sha256:9494bf7e55160959786c7028baa5d9e0dad2ecb7227e541a03164cd08e6ed3e8`.

**Observed progress — 2026-08-13:** **Policy-conformant.** The browser-boundary result is unchanged and
re-run: two per-app plans drive one generic bundle in real headless Chrome, five interactions join the
generated event set exactly, four differential trace steps agree with the independent Haskell semantics, two
DOM snapshots, three accessibility rows, five keyboard/focus rows, and four transport rows match their pins, a
fresh post-ready nonce carries through, the built-artifact scanner and browser CSP canary hold, the OS
observer sees only loopback, and all nine mutants redden. Evidence and the ledger move into
`.build/runs/phase_21/<run-id>/`, and 66 surfaces join two-way to 84 run-time enumerated items.

**`reference_traces.tsv` is deleted, which is what this phase owed.** The table held exactly what
`ReferenceClientPlan.referenceTraces` returns from the authored interactions, so the assertion that compared
them proved only that a file agreed with the function that generated it. The suite now derives that side at
run time, the comparison that matters — browser against independent semantics — is unchanged, and a
`derived-trace-table-untracked` check refuses any tracked fixture whose header names the trace columns.

**The route join stopped agreeing with every corpus.** `authoredRouteRows` ignored its argument and returned
two constant rows, so the generated/authored route join passed for any interaction table at all. It now
derives the authored side from the same independent semantics, and a route added to a plan has to appear in an
interaction before the join can cover it.

**The browser driver resolves instead of being typed in.** The gate carried the literal `1.62.1` in two
places and refused anything else. `playwright` is now an entry in `tools/toolchain_requirements.json` with a
`>=1.55 <2` range, resolved per run like every other tool.

**Three enumeration names were collapsed into the observations that decide them.** `home-route`,
`workflow-route`, and `choose-tenant-route` named the route column of one four-step differential trace;
`external-request-body-observation` named the body the same-origin action request already carries;
`atomic-state-transition` named what the sequential-state-writes mutant proves. One observation reported under
three surfaces reads as three independent results.

**Invalidated historical record:**

✅ Done. Two immutable plans run through one generic PureScript bundle in real Chrome and agree with an
independent Haskell transition oracle. Five interactions, four differential trace steps, two DOM snapshots,
three accessibility rows, five keyboard/focus rows, four transport rows, a fresh nonce, browser-enforced CSP,
the built-artifact scanner, the OS network observer, and all nine mutants pass. Live identity, server
authorization, provider isolation, release rollout, and HA behavior remain UNVERIFIED. See the
Phase-21 ledger.

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
acceptance command `python3 tools/ui_browser_interpreter_gate.py`; split immediately if work requires server policy
evaluation, a second production interpreter, a live identity/provider service, release publication, a second
register, or a substrate.
**Dependency:** Phase 20 — canonical immutable `ClientPlan` encoding and public contracts.
**Substrate:** none — local Chromium and harness-owned fake processes only; no cluster or external service.
**Register:** 2 — boundary integration with fakes.
**Gate:** `python3 tools/ui_browser_interpreter_gate.py` builds the generic bundle and passes every check and seeded mutant
in [Gate integrity](#gate-integrity), emitting a Register-2 ledger whose live layers stay UNVERIFIED. Phase 23
does not open on the browser branch until it does.

## Gate integrity

That one command exercises every leg below — the Phase-0-pinned plans and interactions, the complete
generated-enumeration join, the post-start fresh-challenge round trip, the independent DOM and OS-boundary
network observations, the differential traces, the keyboard/focus sequences, the built-artifact and CSP
checks, the bypass negatives, and every seeded mutant. A leg that does not run leaves the gate red.

Phase 0 commits all plans, interactions, expected state traces, DOM/accessibility snapshots, keyboard/focus
sequences, transport rows, security-header policy, artifact allowlist, and mutant expectations before the
interpreter exists. Expected outcomes are authored independently; they are never generated from `ClientPlan`
or renderer output.

- **Representative set:** minimal single-tenant and multi-tenant plans cover text/number/bool/optional/record/
  variant values; forms and validation; bounded lists/tables; modal/error/progress states; nested routes;
  every event instruction; cancellation; one fixed named external-link navigation; and one request for each
  public effect class.
- **Pinned oracles:** `test/fixtures/ui_browser/plans/`, `interactions.tsv`, `expected_dom/`,
  `expected_accessibility.tsv`, `expected_keyboard_focus.tsv`,
  `expected_transport.tsv`, `test/fixtures/ui_security/production_headers.tsv`, and
  `artifact_allowlist.tsv` own the inputs and
  outcomes. Every generated event/route/link/port identity must join one authored interaction and expectation;
  an unmatched identity emits UNVERIFIED and fails the gate.
- **Differential semantics:** a separately implemented test-only Haskell interpreter consumes each generated
  event trace and emits the expected visible-state, effect-request, cancellation, and route-transition tuple
  for every step. The Playwright/OS observations of the PureScript interpreter must match exactly; the
  reference side imports no production compiler or PureScript transition implementation.
- **Independent observation:** Playwright reads the browser DOM and focus state. The harness-owned loopback
  server records the HTTP method, path, and body outside the bundle, while `strace` observes browser-process
  `connect`/`sendto` calls. Only loopback connections establish; Chrome's two IPv6 reachability probes hard-fail
  with `ENETUNREACH`. Self-emitted client “sent” traces are ignored.
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

> **Current validation record.** Every sprint is covered by the 2026-08-15 reseal. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure was
> established by the current phase gate plus universal artifact hygiene.

## Sprint 21.1: Generic `ClientPlan` interpreter and browser boundary gate ✅

**Status**: Done — the capability is re-established by the migrated gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `ui-runtime/src/Amoebius/Ui/{Interpreter,Components}.purs`, `ui-runtime/src/Main.{purs,js}`,
`test/ui/{UiBrowserInterpreterSpec,ReferenceClientPlan}.hs`,
`test/harness/ui_browser/browser.mjs`, `test/harness/ui_browser/scan_artifact.py`, and `tools/ui_browser_interpreter_gate.py`
**Blocked by**: None.
**Independent Validation**: `python3 tools/ui_browser_interpreter_gate.py` builds via `spago`, drives Chromium with authored
Playwright interactions, reads DOM plus OS-boundary traffic, and requires every named mutant to fail.
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

None. The UI-server authorization/runtime, real provider isolation, release rollout, and HA layers remain
explicitly UNVERIFIED for their owning later phases.

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
