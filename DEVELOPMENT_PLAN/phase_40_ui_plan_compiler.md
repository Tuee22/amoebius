# Phase 40: UI plan compiler

> **Purpose**: Compile one sealed `BoundUiProgram` deterministically into matching immutable client, server,
> public-contract, content-manifest, digest, and finite-demand projections.
> **Read this if**: the paired-plan compiler, its canonical artifact boundary, or its Register-1 evidence has
> to change.

This phase owns the pure compilation decision from one constructor-private bound program to one inseparable
artifact set. It does not interpret either plan, serve HTTP, publish a release, enforce current authority at
runtime, or prove browser, provider, or edge behavior.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_46_ui_contract_generation.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 40.1: Paired semantic projection ✅](#sprint-401-paired-semantic-projection-)
- [Sprint 40.2: Canonical artifacts, digests, and demand ✅](#sprint-402-canonical-artifacts-digests-and-demand-)
- [Sprint 40.3: Calculus projection and phase seal ✅](#sprint-403-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. The complete twelve-sided gate passes on natural `darwin/arm64`, untranslated.
Four logical projections match an independent relation; four canonical regression artifacts and their four
run-time-derived digests are byte-exact; six demand cells, four pinned negatives, two fresh-process runs, and
all six exact-locus mutants pass. The real five-calculus composition projects counts `4,6,14,2,6` to resource
vector `5,32,0,0`. All 17 metrics match and 61 surfaces join to 72 enumerated items. Attestation
`sha256:9dde7747671bfbc30e18c84853a2c940e91bd01ad0ee2c314da6891433ab4010` binds source
`sha256:6fdf9fdecbff0cb8…` over 2,263 files.

**Activated 2026-08-21** when Phase 39 sealed. The generative re-baseline invalidated the earlier result because
it had no calculus projection or natural-architecture record.

---

## Phase Summary

One private `BoundUiProgram` produces public client instructions, a serializable private server dispatch
manifest, public contracts, a content manifest, complete authority/content identities, and finite client/server
runtime demand together. Exact action, route, contract, audit, handler, and resolved-link projections cannot
drift between halves. Public output excludes private fields, handles, policies, provider coordinates, and raw
effect destinations.

The compiler exposes no client-only or server-only entry point. Canonical ordering and encoding make repeated
fresh compilation stable, while changing or omitting an authority-bearing source changes the authority digest.
The outputs remain generated release/content artifacts; the four committed JSON files are regression fixtures,
not independently authored statements of intended semantics.

**Phase scope:** one cohesive claim — one sealed program compiles purely and deterministically to one matching,
finite artifact set. Interpretation, publication, serving, and live freshness split out.

**Substrate:** `none` — compilation, reference comparison, calculus composition, and mutants are pure host
processes with credentials scrubbed and networking denied.

**Lane:** `none` ([§L](development_plan_standards.md#l-one-substrate-discipline)).

**Register:** 1 — pure/golden. Logical projection is independently constrained; interpreter fidelity, release
publication, edge enforcement, and live authority freshness remain UNVERIFIED.

**Depends on:** [Phase 10](phase_10_calculus_composition.md) — actual five-calculus composition; [Phase
39](phase_39_ui_effect_binding.md) — the sealed `BoundUiProgram` accepted by the compiler.

**Gate:** `python3 tools/run_phase_gate.py 40` passes the independent semantic projection, canonical
regression, digest, demand, refusal, fresh-process, five-calculus, paired-mutant, network-observer,
natural-architecture, surface, containment, and attestation checks in [Gate integrity](#gate-integrity).

---

## Gate integrity

`projection_rows.tsv` states four logical client/server/route/contract projections. The Haskell suite compares
production output with `PlanCompilerReference`, which imports neither the production binder nor compiler.
Client/server action key parity is checked directly, and authority inputs are assembled independently.

The four canonical JSON goldens were committed with the implementation. They therefore detect byte drift but
do not establish preimplementation semantic intent; the gate credits the independent logical rows for meaning
and the goldens only for regression and canonical encoding. Concrete digest values are not committed: the gate
hashes the goldens at run time through the distinct reference adapter, records the observations beneath
`.build/**`, and rejects a second tracked digest table.

Four specific negatives cover private-field projection, link-as-effect escape, changed authority input, and
omitted authority input. Two cache-disabled fresh processes compile opposite insertion orders and must emit
identical bytes. Each of six mutants reports its exact locus: dropped server action, swapped action targets,
private-field emission, client-only authority digest, link navigation treated as fetch, or preserved insertion
order. A generic non-zero exit is insufficient.

Artifact, budget, lift, workflow, and evidence components carry the `4,6,14,2,6`
artifact/demand/check/workflow/mutant counts and compose to resource vector `5,32,0,0`. Normal and Darwin
network-denied executions report both acceptance tokens. Generated plans, results, ledgers, traces, and Cabal
state remain beneath `.build/**`.

Passing proves pure paired projection, canonical regression stability, finite demand, and determinism for this
bounded corpus. Browser and server interpretation, release publication, edge enforcement, provider behavior,
and request-time freshness remain UNVERIFIED.

- **Extension conformance (§M.13).** Not applicable. This core paired-plan compiler declares no extension or
  linked set.

## Doctrine adopted

- [`jit_artifact_doctrine.md` §3 — targets and recipes](../documents/engineering/jit_artifact_doctrine.md#3-targets-and-recipes): each emitted plan is generated from typed source rather than authored as product input.
- [`low_code_ui_runtime_doctrine.md` §3 — one checked value, two runtime plans](../documents/engineering/low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans): both plan halves are inseparable projections of one bound value.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): route and action projections retain mandatory policy references.
- [`low_code_ui_runtime_doctrine.md` §15 — versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): complete authority/content identities and immutable per-app plans are derived.
- [`ui_realtime_coordination_doctrine.md` §4 — typed routing and resume envelope](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): both halves carry the scoped routing identity while Redis remains platform-internal.
- [`generated_artifacts_doctrine.md` §2 — what is generated](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what): plan and manifest output remains generated and uncommitted.
- [`illegal_state_security.md` §3.83](../documents/illegal_state/illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed): complete freshness identity is mandatory.

---

## Sprints

## Sprint 40.1: Paired semantic projection ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Compile/{ClientPlan,ServerPlan,Manifest}.hs`, `test/fixture/ui_plan_compiler/projection_rows.tsv`, `test/spec/ui/PlanCompilerReference.hs`
**Blocked by**: [Phase 39](phase_39_ui_effect_binding.md) gate
**Independent Validation**: four normalized production projections equal the separately authored logical relation, and client/server action keys agree exactly
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/illegal_state/illegal_state_security.md`

### Objective

Adopt one compiler entry point whose only successful result contains both public and private plan halves.

### Deliverables

- Constructor-private `ClientPlan`, `UiServerPlan`, and combined result values.
- Four exact logical projections and direct action-key parity.
- Public allowlisting and authority-source change/omission refusals.

### Validation

1. All four production projections equal the independent reference relation.
2. Client and server action keys agree exactly.
3. Private-field, link-as-effect, changed-authority, and omitted-authority controls retain distinct loci.

### Remaining Work

None.

## Sprint 40.2: Canonical artifacts, digests, and demand ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Compile/{Manifest,Demand}.hs`, `test/fixture/ui_plan_compiler/{client_plan,ui_server_plan,public_contracts,content_manifest}.golden.json`, `test/spec/ui/UiPlanCompilerSpec.hs`
**Blocked by**: Sprint 40.1
**Independent Validation**: four regression artifacts are canonical and byte-stable, four digests are derived independently at run time, six demand cells are exact, and opposite insertion orders agree across fresh processes
**Docs to update**: `documents/engineering/generated_artifacts_doctrine.md`, `documents/engineering/ui_realtime_coordination_doctrine.md`

### Objective

Make compilation finite and reproducible without mistaking generated bytes or digest observations for authored
semantic intent.

### Deliverables

- Four canonical JSON regression artifacts and four run-time-derived digest observations.
- Six finite client/server demand cells.
- Cache-disabled fresh-process determinism and insertion-order sensitivity control.

### Validation

1. Every regression artifact is canonical JSON and byte-exact; no committed digest table exists.
2. The independent adapter derives the four matching digests from the current golden bytes.
3. Two fresh processes with opposite insertion order emit identical artifacts, while the deliberately ordered
   control differs.

### Remaining Work

None. The same-commit goldens remain regression fixtures and are not credited as independent semantic oracles.

## Sprint 40.3: Calculus projection and phase seal ✅

**Status**: Done
**Implementation**: `test/oracle/ui_plan_compiler/{calculus_projection,validation_locus}.tsv`, `test/oracle/ui_plan_compiler_surfaces.tsv`, `test/mutant/ui_plan_compiler/**`, `tools/ui_plan_compiler_gate.py`
**Blocked by**: Sprint 40.2
**Independent Validation**: real five-calculus values match all four projection rows; normal and Darwin network-denied executions report both acceptance tokens; six mutant processes report exact loci
**Docs to update**: `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, `DEVELOPMENT_PLAN/system_components.md`

### Objective

Seal the pure compiler claim with current calculus, architecture, surface, containment, and attestation
evidence.

### Deliverables

- A real five-calculus composition over the phase's observed sets.
- Six paired mutants with exact red tokens.
- A complete natural-architecture, surface, ledger, containment, write-guard, and attestation record.

### Validation

1. The authored calculus rows fix kind order, component names, count vector, and resource sum.
2. Ordinary and Darwin-denied executions accept; all six mutant executions fail at their own loci.
3. All 17 metrics and the 61-surface/72-item join pass in the attested run.

### Remaining Work

None.

---

## Documentation Requirements

**Engineering docs updated with this seal:**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — pure paired projection, calculus evidence, and
  honest runtime residues.
- `documents/engineering/generated_artifacts_doctrine.md` — generated artifact boundary and regression-golden
  limitation.
- `documents/engineering/ui_realtime_coordination_doctrine.md` — finite routing-envelope compilation without
  runtime claims.
- `documents/illegal_state/illegal_state_security.md` — authority/refusal evidence and exact mutants.

**Cross-references updated:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — seal, substrate, gate, and owned modules.

---

## Related Documents

- [Development Plan Tracker](README.md) — phase order and current status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, register honesty, and gate integrity.
- [Phase 10](phase_10_calculus_composition.md) — five-calculus composition.
- [Phase 39](phase_39_ui_effect_binding.md) — sealed bound program.
- [JIT Artifact Doctrine](../documents/engineering/jit_artifact_doctrine.md) — generated recipe/address ownership.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — paired-plan and versioning contract.
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — generated-vs-authored boundary.
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — typed routing envelope.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — projection parity and stale-plan foreclosure.
