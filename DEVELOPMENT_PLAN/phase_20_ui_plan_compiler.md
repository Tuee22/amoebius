# Phase 20: UI plan compiler

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_21_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_22_ui_server_boundary.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Compile one sealed `BoundUiProgram` deterministically into matching immutable `ClientPlan`,
> `UiServerPlan`, public-contract, content-manifest, route-dispatch, and finite runtime-demand artifacts.

---

## Phase Status

📋 Planned. This phase proves deterministic pure projection and serialization. It does not claim that a
browser or server interprets the artifacts correctly or that a released artifact is live.

## Phase Summary

This phase implements one seam: the pure plan compiler over `BoundUiProgram`. It emits a compact client
instruction/value plan and matching serializable server dispatch/policy manifest, with exact
action/route/contract key parity,
public-only payload schemas, canonical ordering, complete authority/content digests, a per-application content
manifest, a navigation-only projection of the resolved external-link subset, and finite client/server runtime
demand. The generic PureScript bundle is not rebuilt per app; these
immutable plans and manifests are generated Release/content artifacts and are never treated as authored source.

The compiler consumes only private checked/bound values and returns all projections together. The server
manifest carries exact linked-handler identities and codecs, never Haskell functions. There is no API that
compiles a client plan alone, accepts a hand-authored server route, or serializes a trusted handle or private
field into the browser universe.

**Session scope:** one deterministic `BoundUiProgram` plan compiler and canonical serializer; acceptance
command `cabal test ui-plan-compiler-spec`; split immediately if work requires interpreting a plan, serving
HTTP, publishing a Release, a second register, or a substrate.
**Dependency:** Phase 19 — the sealed `BoundUiProgram` with complete effect bindings.
**Substrate:** none — no browser, network, credential, artifact store, provider, or cluster is contacted.
**Register:** 1 — pure/golden.
**Gate:** `cabal test ui-plan-compiler-spec` passes the Phase-0-pinned paired plan goldens, independent
projection/key oracle, canonical-encoding and cache-bypassed determinism checks, private-field negatives, and
all seeded mutants in [Gate integrity](#gate-integrity). Phases 21 and 22 do not open unless the ledger records
Register 1 green and both interpreter fidelities UNVERIFIED.

## Gate integrity

Phase 0 commits the app fixtures, logical projection tables, expected digests, and test goldens before
`Amoebius.Ui.Compile` exists. The committed goldens are independent test oracles; shipped plan output remains
generated and uncommitted.

- **Representative set:** the same minimal single-tenant, multi-tenant, data/form, workflow/subscription, and
  ready-artifact programs exercise every client instruction, public value type, route guard, effect class,
  server dispatch arm, fixed named-link navigation, and manifest entry.
- **Pinned oracles:** `test/fixtures/ui_plan_compiler/projection_rows.tsv` owns the logical client/server/route/
  contract/audit/handler-identity tuples; `client_plan.golden.json`, `ui_server_plan.golden.json`,
  `public_contracts.golden.json`, and `content_manifest.golden.json` own canonical encodings; and
  `digests.tsv` owns expected ABI, authority, contract, external-link-catalog, and content digests;
  `runtime_demand.tsv` owns finite browser/server demand rows.
- **Independent predicates:** one test reader compares serialized key sets and public/private field
  classifications directly from `projection_rows.tsv`; another hand-authored digest input list is fed to a
  distinct reference hash adapter. Neither imports compiler projections, ordering, or digest-source folds.
- **Specific negatives:** a client-only/server-only action, equal-count action swap, missing route guard,
  private field/handle in a public codec, omitted authority source, duplicate manifest path, and noncanonical
  map order each assert a stable `UiPlanError` or golden mismatch. A link destination reused as an effect URL
  or omitted from the digest-source set has a separate pinned failure.
- **Determinism:** two fresh processes compile from independently decoded input with cache disabled and
  randomized insertion order; their bytes and digests must match. A cache hit or reused first-run bytes does
  not satisfy the check.
- **Effect discipline:** a fresh effect challenge and OS-boundary observer are not applicable in Register 1.
  Generated plans are never executed by this gate, and all runtime layers remain UNVERIFIED.
- **Seeded mutants:** `M-drop-server-action` (dropped effect), `M-swap-action-targets` (effect swap),
  `M-emit-private-field` (projection guard deletion), `M-client-only-authority-digest` (invariant-clause
  delete), `M-link-navigation-as-fetch` (effect swap), and `M-preserve-map-insertion-order` (determinism
  violation) are committed and must each turn a distinct pin red.

Passing proves byte-stable projection for the checked corpus and sampled programs. It does not prove either
interpreter, release publication, transport security, or runtime freshness enforcement.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §3 — one checked value, two runtime plans](../documents/engineering/low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans): both plans are inseparable projections of one bound value.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): route and action projections retain mandatory policy references.
- [`low_code_ui_runtime_doctrine.md` §15 — versioning, rollout, and generated artifacts](../documents/engineering/low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts): complete authority/content identities and immutable per-app plans are derived.
- [`generated_artifacts_doctrine.md` §2 — what is generated](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what) and [`§3 — the rule`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule): plans, manifests, codecs, and route projections are generated and never committed as product artifacts.
- [`illegal_state_security.md` §3.79](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration) and [`§3.83`](../documents/illegal_state/illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed): exact projection parity and complete freshness identity are mandatory.

## Sprints

## Sprint 20.1: Deterministic paired-plan projection 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Ui/Compile/{ClientPlan,ServerPlan,Manifest,Demand}.hs` and
`test/ui/Phase20UiPlanCompilerSpec.hs` (target authored sources; not yet built)
**Blocked by**: Phase 19
**Independent Validation**: `cabal test ui-plan-compiler-spec` compares fresh compiler output with the
Phase-0 tables/goldens and requires every named projection/determinism mutant to fail.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`,
`documents/illegal_state/illegal_state_security.md`

### Objective

Adopt the single-source paired-plan compiler so no client/server drift, private browser projection, incomplete
freshness identity, or per-application client build is representable in the emitted artifact set.

### Deliverables

- Total paired compiler, canonical codecs, complete digest-source fold, finite demand projection, and
  structured `UiPlanError` values.
- Exact key-set and public-projection checks performed before any artifact is returned.
- Phase-0 golden/table readers, fresh-process determinism harness, mutant configurations, and Register-1 ledger.

### Validation

1. Run `cabal test ui-plan-compiler-spec`; each emitted byte stream and digest matches its independent pin and
   all client/server/route/contract/audit key sets are exactly equal where required.
2. Recompile in a fresh process with randomized source insertion order and cache bypass; output remains
   byte-identical while one authority-bearing input change changes the authority digest.
3. Run `M-drop-server-action`, `M-swap-action-targets`, `M-emit-private-field`,
   `M-client-only-authority-digest`, `M-link-navigation-as-fetch`, and
   `M-preserve-map-insertion-order`; every mutant turns a pin red.
4. Verify the ledger says projection/serialization tested in Register 1 and leaves interpretation, release,
   edge, and provider behavior UNVERIFIED.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record paired-plan compiler evidence without
  claiming runtime interpretation.
- `documents/engineering/generated_artifacts_doctrine.md` — record concrete generated artifacts and their
  never-commit/build-boundary treatment.
- `documents/illegal_state/illegal_state_security.md` — attach projection/digest fixtures and mutants.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, `none` substrate, gate, and target modules.
- Phases 21 and 22 — consume the paired artifacts independently; neither may recompile or reinterpret source.

## Related Documents

- [Phase 19](phase_19_ui_effect_binding.md) — the required sealed bound program.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — paired-plan and versioning contract.
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — generated-vs-authored boundary.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — projection parity and stale-plan foreclosure.
