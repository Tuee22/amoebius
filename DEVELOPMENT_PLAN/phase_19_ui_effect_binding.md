# Phase 19: UI effect binding

> **Purpose**: Bind every checked UI port to exactly one trusted, scope-compatible handler, public contract,
> capability, and retry/audit policy before sealing a `BoundUiProgram`.
> **Read this if**: phase 19 is next in the queue, or a later phase depends on what its gate establishes.

Phase 19 delivers the UI effect binding; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [service_capability_doctrine.md](../documents/engineering/service_capability_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
No gate has run.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_20_ui_plan_compiler.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 19.1: Seal the effect-handler-capability relation 📋](#sprint-191-seal-the-effect-handler-capability-relation-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

📋 Planned. This is a pure provision-seal proof over declared registries. It does not establish that a live
handler or provider enforces its declared authorization, tenancy, idempotency, or storage behavior.

## Phase Summary

This phase implements one seam: the total binder from the Phase-18 checked authorization program and trusted
handler/capability/external-link catalogs to a constructor-private `BoundUiProgram`. Every `PortId` must resolve to exactly
one compatible handler, request/response public codec, semantic capability, scope requirement, audit class,
and idempotency/conflict contract. Every `ExternalLinkId` must independently resolve exactly once to a canonical
fixed-HTTPS trusted catalog entry. Data, workflow, subscription, upload, and ready-artifact ports use the same
closed binding boundary; no application-authored URL, provider endpoint, secret, raw resource id, or
caller-selected tenant can enter it.

The binder validates exact key-set parity and produces no partial plan on failure. It consumes the action and
current-authority kernel from Phase 18; it does not reproduce policy evaluation, compile plans, or run effects.

**Session scope:** one pure UI requirement-to-trusted-catalog binder producing `BoundUiProgram`; acceptance command
`cabal test ui-effect-binding-spec`; split immediately if work requires plan encoding, HTTP, a browser/server
interpreter, a live provider, a second register, or a substrate.
**Dependency:** Phase 18 — the sealed action registry, scoped authority transition, and stale-authority refusal.
**Substrate:** none — no network, credential, provider process, browser, or cluster is contacted.
**Register:** 1 — pure/golden.
**Gate:** `cabal test ui-effect-binding-spec` passes the Phase-0-pinned port/handler/capability corpus,
independent binding relation, exact-key checks, negative tags, coverage floors, and every seeded mutant in
[Gate integrity](#gate-integrity). Phase 20 does not open unless the ledger records Register 1 green and
handler/provider runtime enforcement UNVERIFIED.

## Gate integrity

Phase 0 commits the catalogs, expected joins, and diagnostics before `Amoebius.Ui.Bind` exists. The oracle side
may not import the binder, registry normalizer, contract matcher, scope checker, or capability resolver under
test.

- **Representative set:** `ReadData`, `MutateData`, `StartWorkflow`, `ObserveWorkflow`, `Subscribe`,
  `UploadBounded`, and `UseReadyArtifact` ports span read, mutation, workflow, stream, upload, and artifact
  effects in single-tenant and multi-tenant programs. Two named-link requirements resolve against a separately
  authored trusted catalog without becoming effect destinations.
- **Pinned oracles:** `test/fixtures/ui_effect_binding/ports.tsv`, `handlers.tsv`, and `capabilities.tsv` own
  the inputs; `expected_bindings.tsv` owns the exact handler/codec/capability/scope/audit/idempotency tuple for
  each port; `external_link_catalog.tsv` and `expected_external_links.tsv` own fixed canonical link joins; and
  `bind_errors.tsv` owns every rejection tag and offending key.
- **Independent predicates:** a hand-authored finite relational join reads the TSV columns directly and
  compares serialized outcomes. It shares no production lookup, compatibility, set-equality, or digest helper.
- **Specific negatives:** missing and duplicate handlers, request/response codec mismatch, absent capability,
  scope/audience mismatch, unbounded upload/subscription, mutation retry without idempotency, and non-ready
  artifact use each pair with a valid twin and assert one stable `UiBindError`. Missing, duplicate, HTTP,
  userinfo-bearing, wildcard, noncanonical, and caller-templated external-link entries have distinct paired
  `UiLinkBindError` rows.
- **Generator coverage:** QuickCheck covers every effect arm and requires at least 5% for missing, duplicate,
  mismatched-contract, mismatched-scope, missing-capability, and unsafe-retry rejections.
- **Effect discipline:** fresh challenges, authority credentials, and OS-boundary observers are not applicable
  to this Register-1 relation. The pure denied-effect trace must remain empty, while live handler truth and
  provider isolation remain UNVERIFIED.
- **Seeded mutants:** `M-first-handler-wins` (quantifier weakening), `M-drop-capability` (guard deletion),
  `M-erase-handler-scope` (scope guard deletion), `M-swap-response-codec` (effect/type swap), and
  `M-retry-without-idempotency` (invariant-clause delete), plus `export_raw_topic` (provider-coordinate escape),
  and `M-link-id-as-url` (escape-arm addition) are committed and must each turn a distinct pin red.

Passing proves binding completeness and sampled agreement with an independent finite relation. It does not
prove a handler's implementation, current provider state, live authorization, or end-to-end tenant isolation.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §8 — effects are typed ports](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations): all effects resolve through one sealed server-side registry.
- [`low_code_ui_runtime_doctrine.md` §10 — single-tenant and multi-tenant applications](../documents/engineering/low_code_ui_runtime_doctrine.md#10-single-tenant-and-multi-tenant-applications): handler scope is retained in both modes and cannot come from the client.
- [`low_code_ui_runtime_doctrine.md` §11 — data, forms, and storage](../documents/engineering/low_code_ui_runtime_doctrine.md#11-data-forms-and-storage): storage is reached through typed bounded ports and opaque handles.
- [`low_code_ui_runtime_doctrine.md` §12 — workflows and artifact lifting](../documents/engineering/low_code_ui_runtime_doctrine.md#12-workflows-and-artifact-lifting-into-the-ux): workflow and ready-artifact handles bind like every other scoped effect.
- [`low_code_ui_runtime_doctrine.md` §4.4 — external links are trusted names](../documents/engineering/low_code_ui_runtime_doctrine.md#44-external-links-are-names-resolved-by-a-trusted-catalog): named requirements exact-join a linked fixed-HTTPS catalog and cannot become effect URLs.
- [`service_capability_doctrine.md` §2 — the capability set](../documents/engineering/service_capability_doctrine.md#2-the-capability-set): application ports bind semantic capabilities, never provider product coordinates.
- [`illegal_state_capability_messaging.md` §3.82](../documents/illegal_state/illegal_state_capability_messaging.md#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary): no direct browser/provider escape enters the bound program.

## Sprints

## Sprint 19.1: Seal the effect-handler-capability relation 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Ui/{Bind,ExternalLinkCatalog}.hs`,
`test/ui/Phase19UiEffectBindingSpec.hs`, and `test/ui/EffectBindingReference.hs` (target authored sources;
not yet built)
**Blocked by**: Phase 18
**Independent Validation**: `cabal test ui-effect-binding-spec`
compares the private binder's serialized result with the Phase-0 finite relation, verifies empty failure
traces, and requires every named mutant to fail.
**Docs to update**:
`documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/service_capability_doctrine.md`,
`documents/illegal_state/illegal_state_capability_messaging.md`

### Objective

Adopt the sole effect-binding boundary so a checked UI cannot become runnable until every port has one and only
one compatible trusted implementation and every effect invariant is present in the sealed value.

### Deliverables

- Private `BoundUiProgram` and total handler, codec, capability, external-link, scope, audit, and retry-policy binder.
- Structured `UiBindError` values with complete offending keys and no partially usable result.
- Independent relation reader, paired corpus, property coverage, mutant configurations, and Register-1 ledger.

### Validation

1. Run `cabal test ui-effect-binding-spec`; every valid port maps to the exact pinned tuple and every invalid
   twin rejects with its pinned tag/key before a pure effect can be recorded.
2. Compare normalized port, handler, capability, and bound key sets for exact equality, including equal-count
   swaps and duplicates rather than cardinality alone.
3. Run `M-first-handler-wins`, `M-drop-capability`, `M-erase-handler-scope`,
   `M-swap-response-codec`, `M-retry-without-idempotency`, `export_raw_topic`, and `M-link-id-as-url`; each
   turns a distinct oracle row red.
4. Verify the ledger reports only pure binding evidence and leaves browser, server, authority, and provider
   enforcement UNVERIFIED.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record pure bind evidence without claiming handler
  or provider enforcement.
- `documents/engineering/service_capability_doctrine.md` — record the semantic UI-port binding consumer.
- `documents/illegal_state/illegal_state_capability_messaging.md` — attach binder fixtures and mutants to the
  browser-effect escape locus.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, `none` substrate, gate, and target modules.
- Phase 20 — consume only the sealed `BoundUiProgram`.

## Related Documents

- [Phase 18](phase_18_ui_authorization_kernel.md) — the required action registry and authority transition.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — the effect and binding contract implemented here.
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — semantic capability ownership.
- [Illegal-State Capability/Messaging Slice](../documents/illegal_state/illegal_state_capability_messaging.md) — direct browser/provider escape foreclosure.
