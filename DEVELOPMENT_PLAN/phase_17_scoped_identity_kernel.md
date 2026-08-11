# Phase 17: Scoped identity kernel

> **Purpose**: Build the pure scope, audience, provenance, and information-flow kernel that prevents UI data
> or authority from being retagged across subjects or tenants.
> **Read this if**: phase 17 is next in the queue, or a later phase depends on what its gate establishes.

Phase 17 delivers the scoped identity kernel; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
Gate passed on 2026-08-09 with ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/ledgers/phase_17_scoped_identity_kernel.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_18_ui_authorization_kernel.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/testing_doctrine.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 17.1: Scope-indexed handles and total flow checking ⏸️](#sprint-171-scope-indexed-handles-and-total-flow-checking-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate from a clean committed tree and publish external evidence without changing an authored path.

**Invalidated historical record:**

✅ Done. The owner/grant and flow relations, constructor-closure compile failures, generated coverage, and
owner-equality mutant pass. Identity-provider and provider-runtime enforcement remain UNVERIFIED. See the
[Phase-17 ledger](ledgers/phase_17_scoped_identity_kernel.md).

## Phase Summary

This phase implements one seam: the constructor-private Haskell kernel for `Tenant`, `Subject`, `Membership`,
`Owner`, `RequestContext`, `ScopeWitness`, `Audience`, scoped handles, provenance, `FlowLabel`, and `CanFlowTo`.
It consumes the Phase-16 checked UI
IR and makes tenant, subject, audience, and integrity preservation explicit before authorization or effects are
introduced. Single-tenant programs retain the tenant index and receive one fixed server-supplied witness; they
do not use a weaker unscoped representation.

**Session scope:** one pure scoped-identity/flow algebra and its total checker; acceptance command
`cabal test ui-scope-spec`; split immediately if work requires a server interpreter, live credentials, a second
register, or a substrate.
**Dependency:** Phase 16 — the checked low-code UI program and its reified public value universe.
**Substrate:** none — no host, browser, identity provider, provider service, or cluster is contacted.
**Register:** 1 — pure/golden.
**Gate:** `python3 tools/phase17_gate.py` passes the paired scope corpus, independent
flow relation, three compile failures, six coverage floors, isolated execution, explicit mutant-red run, and
ledger check.

## Gate integrity

All reference material below is authored and committed in Phase 0 before `Amoebius.Ui.Security.Scope` exists. The test
must parse the pins independently; it may not call the kernel under test to manufacture expected decisions.

- **Representative set:** two tenants (`t-a`, `t-b`), two subjects in `t-a`, one subject in `t-b`, and
  equal-shaped subject-owned, tenant-wide, role-shared, and explicitly granted resources. Every allowed row has
  a paired denial differing only in subject, tenant, audience, integrity, or grant state.
- **Pinned oracles:** `test/fixtures/ui_scope/owner_join_table.tsv` owns the independent
  `Tenant`/`Subject`/`Membership`/`Owner` join; `owner_tenant_swaps.tsv` owns paired rejection cases;
  `flow_matrix.tsv` owns direct and transitive source-to-sink decisions; `decode_errors.tsv` owns exact error
  tags; and `compile_fail/` proves that raw `ResourceId`, scope retagging, and general declassification do not
  type-check.
- **Independent predicates:** the matrix reader implements the finite reference relation directly from its
  columns. It shares no `CanFlowTo`, handle resolver, graph walk, or normalization helper with the subject.
- **Specific negatives:** own-subject success is paired with same-tenant/foreign-subject denial and
  foreign-tenant denial; an active grant is paired with its revoked twin; each rejection asserts its committed
  `ScopeError` or `FlowError` tag rather than merely observing `Left`.
- **Generator coverage:** QuickCheck classifies tenant mismatch, subject mismatch, absent/revoked grant,
  audience widening, integrity elevation, and transitive-only leak, with each reject class meeting a 5% floor.
- **Effect discipline:** a fresh effect challenge and real authority credentials are not applicable in this
  Register-1 phase. Denied cases must nevertheless leave the independent pure effect trace empty; Phase 36 owns
  the corresponding real-credential and external-observer claim.
- **Seeded mutant:** `drop_owner_equality` deletes the owner-equality guard from the join. It is committed and
  must turn the gate red on both the same-tenant owner swap and the cross-tenant owner swap pins.

The gate therefore proves sampled agreement with an independent finite relation and constructor closure. It
does not prove Keycloak truth, provider row policy, network isolation, or noninterference of future handlers.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §4.2 — the client-safe value universe](../documents/engineering/low_code_ui_runtime_doctrine.md#42-the-client-safe-value-universe): opaque handles cannot be made from public identifiers.
- [`low_code_ui_runtime_doctrine.md` §5 — Gate 2 and the checked Haskell IR](../documents/engineering/low_code_ui_runtime_doctrine.md#5-gate-2-and-the-checked-haskell-ir): scope and flow evidence is constructor-private.
- [`low_code_ui_runtime_doctrine.md` §10 — single-tenant and multi-tenant applications](../documents/engineering/low_code_ui_runtime_doctrine.md#10-single-tenant-and-multi-tenant-applications): both modes retain trusted scope indices.
- [`low_code_ui_runtime_doctrine.md` §10.3 — information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels): the total graph relation preserves confidentiality and integrity.
- [`illegal_state_catalog.md` §3.80](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant) and [`§3.81`](../documents/illegal_state/illegal_state_security.md#381-a-ui-value-flowing-to-an-incompatible-tenant-subject-or-audience-scope): the paired oracle and mutants are the phase's explicit foreclosure obligations.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 17.1: Scope-indexed handles and total flow checking ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**: `src/Amoebius/Ui/Security/{Scope,Flow}.hs`, `test/ui/ScopeSpec.hs`,
and `test/fixtures/ui_scope/compile_fail/` — built and validated.
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `ui-scope-spec` matches all owner/swap and flow rows, and six generated reject
classes meet their floors. Three external construction attempts fail to compile; the committed mutant fails.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/illegal_state/illegal_state_security.md`, `documents/engineering/testing_doctrine.md`

### Objective

Adopt the low-code runtime's scoped Haskell IR and information-flow rules: make it impossible for public UI
data to construct or retag trusted tenant/subject authority, and reject every incompatible direct or transitive
flow before a `CheckedUiProgram` can proceed to authorization binding.

### Deliverables

- Private constructors and smart constructors for scoped request context, audiences, grants, handles,
  provenance, labels, and flow witnesses; there is no unscoped/global-resource provider input.
- A total scope resolver and transitive flow checker returning stable structured errors with complete offending
  paths, including cycles or missing graph members as failures rather than partial traversal.
- Compile-fail coverage for raw identifier use, scope coercion, label erasure, and general declassification.
- Property tests, matrix parser, coverage floors, committed mutant configurations, and a Register-1
  proven/tested/assumed ledger marking all live enforcement layers UNVERIFIED.

### Validation

1. Run `cabal test ui-scope-spec`; every own/foreign and active/revoked pair matches the independently authored
   matrices, every negative reports its pinned tag/path, and every coverage floor is met.
2. Compile-fail cases demonstrate that raw identifiers, browser-derived scope, foreign-scope handles, and
   unlabelled authority sinks cannot inhabit the trusted APIs.
3. Run `drop_owner_equality`; both pinned owner/tenant swap families must expose it and turn the gate red.
4. Verify the test process makes no network or credential access and the ledger says “spec-composition
   proven,” never “runtime proven.”

### Remaining Work

Done. Live identity and provider enforcement remain UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the Phase-17 pure scope/flow kernel evidence
  without changing the runtime-enforcement honesty boundary.
- `documents/illegal_state/illegal_state_security.md` — attach the §3.80/§3.81 Register-1 fixture and mutant
  evidence to their Gate-2 loci.
- `documents/engineering/testing_doctrine.md` — register the independent scope/access-matrix pattern.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, `none` substrate, gate, and target module.
- `DEVELOPMENT_PLAN/phase_18_ui_authorization_kernel.md` — retain Phase 17 as its exact dependency.

## Related Documents

- [Development Plan Standards](development_plan_standards.md) — phase shape, Register-1 honesty, and gate integrity.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — the scoped value and flow contract implemented here.
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md) — authoritative tenant, subject, membership, ownership, and grant model.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — subject ownership and information-flow illegal states.
