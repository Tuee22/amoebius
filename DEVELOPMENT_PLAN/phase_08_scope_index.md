# Phase 8: Scoped identity kernel

> **Purpose**: Build the pure scope, audience, provenance, and information-flow kernel that prevents UI data
> or authority from being retagged across subjects or tenants.
> **Read this if**: phase 8 is next in the queue, or a later phase depends on what its gate establishes.

Phase 8 delivers the scoped identity kernel; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
Gate passed on 2026-08-09 with ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/testing_doctrine.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 8.1: Scope-indexed handles and total flow checking 📋](#sprint-81-scope-indexed-handles-and-total-flow-checking-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

🔄 Active — Phase 7 sealed on 2026-08-20, so this is the open contract. Reopened 2026-08-19 by the generative re-baseline: the artifact, budget, lift, workflow and evidence calculi change what this phase's gate must cover, so any earlier seal is history and no longer presents completion evidence. All five now exist, which is what makes this contract's coverage decidable rather than pending.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Done (invalidated) — resealed 2026-08-15. `python3 tools/scoped_identity_gate.py` passed all twelve sides: all owner
joins/swaps, the independent flow matrix, three compile loci, six coverage classes, the owner-equality mutant,
all ten metrics, and nine constructor-privacy checks pass; 40 surfaces join to 47 enumerated items. The
project-contained attestation is `sha256:9aeed4fb73be7214c732f671f86c14a0f376f50ffd5197b980f7ad5f2df1ab58`,
bound to source snapshot `sha256:823a8dffbc72114a…`; Phase 8 owns no remaining migration deferral.

**Pre-containment status record (invalidated where it claims completion):**

Done (invalidated) — sealed 2026-08-13. The migrated gate passed against source snapshot `sha256:f6ee1e7d69f37a07…`
(1942 non-ignored files) and published a verified pre-containment external attestation
`sha256:45ba0ed3a546b6dd436f611f2d12e80378bc64c5d349d8f9fdf44f32c727b18a`.

**Observed progress — 2026-08-13:** **Policy-conformant.** The scoped-identity result is unchanged and
re-run: six owner-join rows and two swap rows match the independent tables at their exact `ScopeError` tags,
four flow rows agree with a reference relation that shares no helper with the kernel, three compile loci hold,
six generated classes clear their 5% floor, and the owner-equality mutant reddens on both swap pins. Evidence
and the ledger move into `.build/runs/phase_33/<run-id>/`, and 40 surfaces join two-way to 47 run-time enumerated
items.

**Every cabal invocation now carries the resolved compiler.** The pre-migration gate ran `cabal exec ghc`
bare, so on a host offering a newer GHC than the authored range the compile-fail battery failed to resolve
`base` and reported a drifted locus — a toolchain mismatch wearing the costume of a capability regression.
The gate resolves `ghc` and passes it to every cabal call, as Phase 9 established.

**Constructor opacity is nine checks, not one.** Each private type — `Tenant`, `Subject`, `Membership`,
`RequestContext`, `ScopeWitness`, `ScopedHandle`, `ResourceId`, `FlowLabel`, `CanFlowTo` — has its own check
id and its own surface, because a single "the constructors are private" bit stays green while one of them
quietly opens. The scan also no longer assumes the author's spacing: `Tenant(..)` opens a constructor exactly
as `Tenant (..)` does.

**Three contract surfaces have no recorded observation and are honestly UNVERIFIED.** The kernel declares
`TenantFlowMismatch`, a cycle diagnostic, and `MissingFlowMember`, but the committed four-row flow matrix
decides audience widening, integrity elevation, and one transitive leak — and nothing else. `tenant-flow-preservation`,
`cycle-diagnostic`, and `missing-member-diagnostic` therefore carry no id, and the gap is recorded against
Phase 8 in the legacy register rather than asserted away.

**Invalidated historical record:**

Done (invalidated). The owner/grant and flow relations, constructor-closure compile failures, generated coverage, and
owner-equality mutant pass. Identity-provider and provider-runtime enforcement remain UNVERIFIED. See the
Phase-8 ledger.

## Phase Summary

This phase implements one seam: the constructor-private Haskell kernel for `Tenant`, `Subject`, `Membership`,
`Owner`, `RequestContext`, `ScopeWitness`, `Audience`, scoped handles, provenance, `FlowLabel`, and `CanFlowTo`.
It consumes the Phase-37 checked UI
IR and makes tenant, subject, audience, and integrity preservation explicit before authorization or effects are
introduced. Single-tenant programs retain the tenant index and receive one fixed server-supplied witness; they
do not use a weaker unscoped representation.

**Session scope:** one pure scoped-identity/flow algebra and its total checker; acceptance command
`cabal test ui-scope-spec`; split immediately if work requires a server interpreter, live credentials, a second
register, or a substrate.
**Depends on:** [Phase 7](phase_07_evidence_calculus.md) — the evidence calculus, which binds each claim below to its fixture. The edge to the UI program schema is **reversed** by the re-baseline: the scope index is a pure type-level construct that the UI schema is indexed *by*, so the schema now depends on this phase rather than the other way round.
**Phase scope:** one cohesive claim — *a value cannot acquire an audience it did not arrive with*. Scope, provenance and information flow are one index, and the kernel is where it becomes a type rather than a convention.

**Substrate:** none — no host, browser, identity provider, provider service, or cluster is contacted.
**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/golden.
**Gate:** `python3 tools/scoped_identity_gate.py` passes the paired scope corpus, independent
flow relation, three compile failures, six coverage floors, isolated execution, explicit mutant-red run, and
ledger check.

## Gate integrity

All reference material below is authored and committed in Phase 0 before `Amoebius.Ui.Security.Scope` exists. The test
must parse the pins independently; it may not call the kernel under test to manufacture expected decisions.


- **Representative set:** two tenants (`t-a`, `t-b`), two subjects in `t-a`, one subject in `t-b`, and
  equal-shaped subject-owned, tenant-wide, role-shared, and explicitly granted resources. Every allowed row has
  a paired denial differing only in subject, tenant, audience, integrity, or grant state.
- **Pinned oracles:** `test/fixture/ui_scope/owner_join_table.tsv` owns the independent
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
  Register-1 phase. Denied cases must nevertheless leave the independent pure effect trace empty; Phase 68 owns
  the corresponding real-credential and external-observer claim.
- **Seeded mutant:** `drop_owner_equality` deletes the owner-equality guard from the join. It is committed and
  must turn the gate red on both the same-tenant owner swap and the cross-tenant owner swap pins.

The gate therefore proves sampled agreement with an independent finite relation and constructor closure. It
does not prove Keycloak truth, provider row policy, network isolation, or noninterference of future handlers.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §4.2 — the client-safe value universe](../documents/engineering/low_code_ui_runtime_doctrine.md#42-the-client-safe-value-universe): opaque handles cannot be made from public identifiers.
- [`low_code_ui_runtime_doctrine.md` §5 — gadt-decode and the checked Haskell IR](../documents/engineering/low_code_ui_runtime_doctrine.md#5-gadt-decode-and-the-checked-haskell-ir): scope and flow evidence is constructor-private.
- [`low_code_ui_runtime_doctrine.md` §10 — single-tenant and multi-tenant applications](../documents/engineering/low_code_ui_runtime_doctrine.md#10-single-tenant-and-multi-tenant-applications): both modes retain trusted scope indices.
- [`low_code_ui_runtime_doctrine.md` §10.3 — information-flow labels](../documents/engineering/low_code_ui_runtime_doctrine.md#103-information-flow-labels): the total graph relation preserves confidentiality and integrity.
- [`illegal_state_catalog.md` §3.80](../documents/illegal_state/illegal_state_security.md#380-a-subject-resolving-or-mutating-another-subjects-resource-without-a-grant) and [`§3.81`](../documents/illegal_state/illegal_state_security.md#381-a-ui-value-flowing-to-an-incompatible-tenant-subject-or-audience-scope): the paired oracle and mutants are the phase's explicit foreclosure obligations.

## Sprints

> **Current validation record.** Every sprint is covered by the 2026-08-15 reseal. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure was
> established by the current phase gate plus universal artifact hygiene.

## Sprint 8.1: Scope-indexed handles and total flow checking 📋
**Status**: Planned
**Implementation**: `src/Amoebius/Ui/Security/{Scope,Flow}.hs`, `test/spec/ui/ScopeSpec.hs`,
and `test/fixture/ui_scope/compile_fail/` — built and validated.
**Blocked by**: None.
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

Done for the pure kernel. Live identity and provider enforcement remain UNVERIFIED, and so do the three flow
diagnostics no committed row exercises — tenant-flow preservation, the cycle diagnostic, and the missing-member
diagnostic.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record the Phase-8 pure scope/flow kernel evidence
  without changing the runtime-enforcement honesty boundary.
- `documents/illegal_state/illegal_state_security.md` — attach the §3.80/§3.81 Register-1 fixture and mutant
  evidence to their gadt-decode loci.
- `documents/engineering/testing_doctrine.md` — register the independent scope/access-matrix pattern.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, `none` substrate, gate, and target module.
- `DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md` — retain Phase 8 as its exact dependency.

## Related Documents

- [Development Plan Standards](development_plan_standards.md) — phase shape, Register-1 honesty, and gate integrity.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — the scoped value and flow contract implemented here.
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md) — authoritative tenant, subject, membership, ownership, and grant model.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — subject ownership and information-flow illegal states.
