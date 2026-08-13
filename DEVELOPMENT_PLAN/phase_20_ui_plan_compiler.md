# Phase 20: UI plan compiler

> **Purpose**: Compile one sealed `BoundUiProgram` deterministically into matching immutable `ClientPlan`,
> `UiServerPlan`, public-contract, content-manifest, route-dispatch, and finite runtime-demand artifacts.
> **Read this if**: phase 20 is next in the queue, or a later phase depends on what its gate establishes.

Phase 20 delivers the UI plan compiler; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), [ui_realtime_coordination_doctrine.md](../documents/engineering/ui_realtime_coordination_doctrine.md), [generated_artifacts_doctrine.md](../documents/engineering/generated_artifacts_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
Gate passed on 2026-08-09 with ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_21_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_22_ui_server_boundary.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 20.1: Deterministic paired-plan projection ✅](#sprint-201-deterministic-paired-plan-projection-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-13. The migrated gate passed against source snapshot `sha256:3587049c696ded8e…`
(1944 non-ignored files) and published verified external attestation
`sha256:6e567d5b9a009a424ba1974e7d62957e579bd56f928e9bc1076365584aaaa8be`.

**Observed progress — 2026-08-13:** **Policy-conformant.** The paired-plan result is unchanged and re-run:
four logical projections match a reference relation that imports no production projection code, four canonical
artifacts are byte-exact, four digests agree with an independent adapter, six demand cells are finite and
exact, two fresh cache-disabled processes with reversed insertion order emit identical bytes, and all six
seeded mutants redden. Evidence and the ledger move into `gen/runs/phase_20/<run-id>/`, and 55 surfaces join
two-way to 66 run-time enumerated items.

**`expected_digests.tsv` is deleted, which is what this phase owed.** A table of four SHA-256 values over
bytes the goldens already pin is not an expectation anyone can author or review — it is a reproducible
observation, and a second copy of a fact can only agree or be wrong. The suite now derives that side at run
time by hashing the authored goldens with the independent adapter, the run bundle records the derived table,
and a `derived-digest-table-untracked` check refuses to let any tracked fixture other than the four goldens
carry a `sha256:` literal again. The Phase-0 gate was re-run green after its manifest row was removed.

**The four plan goldens remain regression fixtures, and this seal does not change that.** They were first
committed alongside the implementation, so Git establishes no chronology between fixture and subject
([development_plan_standards.md §M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
clause 1). They hold byte-exactly and the mutants prove the comparison has teeth; what they cannot do is prove
the intended output was authored before the observed one. Only an independent human reviewer can discharge
that, and the obligation stays open in the legacy register rather than being absorbed by a green run.

**Invalidated historical record:**

✅ Done. Four logical rows compile inseparably into four canonical artifacts, four concrete SHA-256 identities,
and six finite-demand cells; reversed source insertion in two cache-disabled fresh processes is byte-identical,
and six mutants turn red. This proves pure projection and serialization only. It does not claim interpreter
correctness or a live release. See the Phase-20 ledger.

## Phase Summary

This phase implements one seam: the pure plan compiler over `BoundUiProgram`. It emits a compact client
instruction/value plan and matching serializable server dispatch/policy manifest, with exact
action/route/contract key parity,
public-only payload schemas, canonical ordering, complete authority/content digests, a per-application content
manifest, a navigation-only projection of the resolved external-link subset, and finite client/server runtime
demand. Subscription/port projections include the complete application/session/scope/program/ABI/stream/cursor
routing envelope required by the authenticated WebSocket and cross-pod dispatcher; no Redis key or product
choice enters either application plan. The generic PureScript bundle is not rebuilt per app; these
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
**Gate:** `python3 tools/phase20_gate.py` passes the projection/key oracle, run-time-derived reference
digests, canonical-encoding and cache-bypassed determinism checks, private-field negatives, isolated
execution, and all seeded mutants in [Gate integrity](#gate-integrity). Both interpreter fidelities stay
UNVERIFIED.

## Gate integrity

The app fixtures and logical projection tables remain authored source only after Phase 0 records independent
review. Existing same-commit plan goldens are regression fixtures until reviewed or replaced. Concrete digests
are recomputed during the gate by the distinct reference adapter and remain generated run evidence; shipped
plan output is likewise generated and uncommitted.

- **Representative set:** the same minimal single-tenant, multi-tenant, data/form, workflow/subscription, and
  ready-artifact programs exercise every client instruction, public value type, route guard, effect class,
  server dispatch arm, fixed named-link navigation, and manifest entry.
- **Oracle candidates:** after independent review, `test/fixtures/ui_plan_compiler/projection_rows.tsv` owns
  the logical client/server/route/contract/audit/handler-identity tuples. The four existing plan goldens must
  be reviewed or replaced before serving as canonical-encoding oracles. `expected_digests.tsv` is removed;
  concrete authority, client, server, and contract digests are generated at run time from separately authored
  digest-source expectations. Finite demand is independently counted from the reviewed projection rows.
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
- [`ui_realtime_coordination_doctrine.md §4 — typed routing and resume envelope`](../documents/engineering/ui_realtime_coordination_doctrine.md#4-typed-routing-and-resume-envelope): both plan halves project the complete scoped routing/cursor identity while Redis remains platform-internal.
- [`generated_artifacts_doctrine.md` §2 — what is generated](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what) and [`§3 — the rule`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule): plans, manifests, codecs, and route projections are generated and never committed as product artifacts.
- [`illegal_state_security.md` §3.79](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration) and [`§3.83`](../documents/illegal_state/illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed): exact projection parity and complete freshness identity are mandatory.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 20.1: Deterministic paired-plan projection ✅

**Status**: Done — the capability is re-established by the migrated gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `src/Amoebius/Ui/Compile/{ClientPlan,ServerPlan,Manifest,Demand}.hs`
and `test/ui/{Phase20UiPlanCompilerSpec,PlanCompilerReference}.hs`, plus `tools/phase20_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `cabal test ui-plan-compiler-spec` compares fresh compiler output with the
Phase-0 tables/goldens and requires every named projection/determinism mutant to fail. The full hermetic gate
is `python3 tools/phase20_gate.py`.
**Docs to update**:
`documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/engineering/ui_realtime_coordination_doctrine.md`,
`documents/engineering/generated_artifacts_doctrine.md`, `documents/illegal_state/illegal_state_security.md`

### Objective

Adopt the single-source paired-plan compiler so no client/server drift, private browser projection, incomplete
freshness identity, or per-application client build is representable in the emitted artifact set.

### Deliverables

- Total paired compiler, canonical WebSocket routing/cursor codecs, complete digest-source fold, finite demand projection, and
  structured `UiPlanError` values.
- Exact key-set and public-projection checks performed before any artifact is returned.
- Reviewed golden/table readers, run-time reference-digest generation, a fresh-process determinism harness,
  mutant configurations, and a generated Register-1 ledger.

### Validation

1. Run `cabal test ui-plan-compiler-spec`; each emitted byte stream matches an independently reviewed
   expectation, each digest matches a fresh distinct-reference computation, and all required key sets match.
2. Recompile in a fresh process with randomized source insertion order and cache bypass; output remains
   byte-identical while one authority-bearing input change changes the authority digest.
3. Run `M-drop-server-action`, `M-swap-action-targets`, `M-emit-private-field`,
   `M-client-only-authority-digest`, `M-link-navigation-as-fetch`, and
   `M-preserve-map-insertion-order`; every mutant turns a pin red.
4. Verify the ledger says projection/serialization tested in Register 1 and leaves interpretation, release,
   edge, and provider behavior UNVERIFIED.

### Remaining Work

Done for the compiler. `expected_digests.tsv` is removed, the reference digests are derived at run time and
recorded in the run bundle, and the gate ran under universal artifact hygiene. One obligation stays open and
is not this gate's to close: the four plan goldens are same-commit regression fixtures until an independent
human reviewer validates or replaces them. Browser/server interpretation, release publication, edge
enforcement, and live freshness remain UNVERIFIED and belong to later gates.

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
- [UI Realtime Coordination](../documents/engineering/ui_realtime_coordination_doctrine.md) — typed
  WebSocket/cross-pod routing envelope compiled without exposing Redis in application data.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — projection parity and stale-plan foreclosure.
