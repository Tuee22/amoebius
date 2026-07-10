# Phase 5: GADT-indexed IR + total decoder (Gate 2)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_04_dhall_gate1_schema.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_07_capacity_topology_folds.md, DEVELOPMENT_PLAN/phase_08_capability_binder.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the GADT-indexed Haskell IR and the total, fail-fast `Dhall.inputFile auto` decoder
> — Gate 2 — that turns a Gate-1-well-typed Dhall value into a legal amoebius world or a structured `Left`,
> in-process, before any real resource exists.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 4 Gate-1 gate
passes and runs on **no substrate** (`none`) in **Register 1** — it stands up no host and no cluster, only an
in-process decode battery. Where a shape below is already exercised in a sibling system (hostbootstrap's
`inputFile auto` decoder and its `Left (ContextDecodeFailed …)` fail-fast discipline), that is **sibling
evidence, not an amoebius result**.

## Phase Summary

This phase builds the second of the DSL's two typed gates. Gate 1 (Phase 4) rejects what is not even
well-typed Dhall; Gate 2 rejects what is well-typed Dhall but is not a legal amoebius world. It delivers the
GADT-indexed Haskell intermediate representation the Dhall surface decodes *into* — sum types, smart
constructors, phantom tenant references, and ownership indices designed so that an illegal combination has no
inhabitant — together with the total decoder `decodeCluster :: FilePath -> IO (Either DecodeError ClusterIR)`
built on the native `dhall` library's `Dhall.inputFile auto`. The decode path is **total and fail-fast**: a
malformed or out-of-domain value surfaces as a structured `Left`, never as a thrown exception into a
half-applied effect, and the path carries no `error`/`undefined`/partial head. What is *not* here: the chain
/ reconcile / singleton runtime (Phase 20), the capacity and topology decode-folds (Phase 7), the capability
→ provider binder (Phase 8), and the exhaustive illegal-state corpus with its per-entry validation-locus
ledger and QuickCheck properties (Phase 6). This phase proves the decoder is total and structurally rejecting
on a representative Gate-2 negative set; the exhaustive corpus rides on top of it next.

**Substrate:** `none` — no host, no cluster; the gate is an in-process `cabal test` battery analogous to the
Phase-0 documentation lint and the Phase-4 `dhall type` corpus.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `cabal test dsl-spec` is green — each positive fixture decodes through the total `decodeCluster`
into its `ClusterIR`, each Gate-2-class negative fixture returns a structured `Left DecodeError` with its
expected tag, and the decode path is provably total (strict evaluation, no `error`/`undefined`, no partial
match) — a **Register-1** in-process check that runs on no substrate.

## Doctrine adopted

- [`dsl_doctrine.md §5 — the illegal-state-unrepresentable contract`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  adopt **Gate 2 — the Haskell typed decoder**. A well-typed Dhall value becomes a Haskell value through the
  native `dhall` library in-process (`Dhall.inputFile auto`); decoding is total and fail-fast (a structured
  `Either`, never a throw), and the ADTs make illegal combinations un-spellable — *because the value cannot
  be constructed, it cannot be decoded, and because it cannot be decoded, it cannot be deployed.*
- [`illegal_state_catalog.md §4`](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed)
  — the typing techniques discharged at the decode boundary: **GADT-indexed state machines** (§4.3, only legal
  transitions are typed), **capability & phantom tenant tags** (§4.2, cross-tenant references are
  uninhabitable), and **ownership indices** (§4.4, single-owner SSoT structurally). This phase builds the IR
  that carries those indices; the capacity-accounting and topology-relation folds (§4.6/§4.7) are deferred to
  Phase 7.
- [`illegal_state_catalog.md §2`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)
  and [`§6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
  — the load-bearing limit and the three layers of foreclosure: layers 1–2 (type-/decode-foreclosed) are
  Register-1 and honestly discharged here; layer 3 (runtime-checked) stays deferred. Honors §2 verbatim: *a
  type-check proves the spec composes, not that the cluster enforces it.*
- [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md) — **Register 1** (pure/golden,
  in-process, no cluster): the register this phase's gate reaches; and [`§4`](../documents/engineering/testing_doctrine.md)
  — the per-run proven/tested/assumed ledger the battery emits, marking model↔runtime correspondence
  UNVERIFIED.

## Sprints

## Sprint 5.1: The amoebius cabal package + `dsl-spec` test-suite skeleton 📋

**Status**: Planned
**Implementation**: `amoebius.cabal`, `cabal.project` (the real package, not the Phase-1 throwaway probe), a
`dsl-spec` test-suite stanza, and an empty `src/Amoebius/Dsl/` module tree — target paths, not yet built.
**Blocked by**: Phase 4 gate (the Gate-1 Dhall schema + smart-constructor prelude the decoder mirrors); the
Phase 1 toolchain spike's recorded `allow-newer`/patch/pin for `dhall` under GHC 9.12.4.
**Independent Validation**: `cabal build` of the empty package and `cabal test dsl-spec` (zero tests)
succeed under GHC 9.12.4 / Cabal 3.16.1.0 using the Phase-1 pin, with no `PATH`-resolved tool.
**Docs to update**: `DEVELOPMENT_PLAN/system_components.md` (register the `amoebius` package + `dsl-spec`
suite), this document.

### Objective
Adopt the pinned toolchain from the Phase 1 spike and stand up the real `amoebius` cabal package with a
`dsl-spec` test-suite target, so every later sprint has a buildable in-process surface — the minimal skeleton
Gate 2 needs, with **no** chain/reconcile/singleton kernel.

### Deliverables
- `amoebius.cabal` + `cabal.project` pinned to GHC 9.12.4 / Cabal 3.16.1.0 with the Phase-1 `allow-newer`
  set, exposing an empty `src/Amoebius/Dsl/` tree and a `dsl-spec` test-suite stanza.

### Validation
1. `cabal build` and `cabal test dsl-spec` (zero tests) succeed on the pinned toolchain.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 5.2: GADT-indexed IR + smart constructors + phantom tenant refs + ownership indices 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Dsl/Types.hs` (the GADT-indexed `ClusterIR` and component ADTs),
`src/Amoebius/Dsl/SmartConstructors.hs`, `src/Amoebius/Dsl/Ref.hs` (the phantom tenant `Ref tenant a` and
ownership indices) — target paths, not yet built.
**Blocked by**: Sprint 5.1.
**Independent Validation**: the catalog's decode-foreclosed classes (§4.2/§4.3/§4.4) have no inhabitant — a
representative typed-hole / `-fno-code` check demonstrates the illegal constructor is absent; the exhaustive
compile-fail corpus is assembled in Phase 6.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (per-entry layer reconciliation — which
entries this IR type-forecloses), `documents/engineering/dsl_doctrine.md` (Phase-5 status backlink),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`illegal_state_catalog.md §4.2/§4.3/§4.4`](../documents/illegal_state/illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed):
build the Haskell types the Dhall decodes into — GADT-indexed so only legal transitions are typed, phantom
tenant-tagged so a cross-tenant reference is uninhabitable, and ownership-indexed so a resource has one
structural owner. These are the ADTs that make an illegal combination un-spellable at the decode boundary.

### Deliverables
- `ClusterIR` and its component ADTs as GADT-indexed types + smart constructors exposing only a legal
  vocabulary; the phantom tenant `Ref tenant a` and ownership indices catalogued at §4.2/§4.4.
- An in-file honesty note that binding/capacity/topology totals (§4.6/§4.7) are *not* foreclosed by these
  types — they are the fold-checked decode residue owned by Phase 7.

### Validation
1. A representative illegal combination from each of §4.2/§4.3/§4.4 has no constructor (a typed-hole /
   `ghc -fno-code` check); the legal vocabulary compiles.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 5.3: The total `Dhall.inputFile auto` decoder + structured `DecodeError` 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Dsl/Decode.hs` (`decodeCluster :: FilePath -> IO (Either DecodeError
ClusterIR)` = `Dhall.inputFile auto`, total/fail-fast) and `src/Amoebius/Dsl/Error.hs` (the tagged
`DecodeError` type) — target paths, not yet built.
**Blocked by**: Sprint 5.2.
**Independent Validation**: the decode path returns `Either DecodeError ClusterIR` and never throws into a
half-applied effect; a `-Wall` + partiality grep gate confirms no `error`/`undefined`/partial head reachable
from `decodeCluster`; strictness forces the decoded value.
**Docs to update**: `documents/engineering/dsl_doctrine.md` (§5 Gate-2 backlink to the in-process decoder),
`documents/engineering/testing_doctrine.md` (the Register-1 in-process ledger variant),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`dsl_doctrine.md §5 — Gate 2, the Haskell typed decoder`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
implement the total, fail-fast in-process decoder that mirrors hostbootstrap's `decodeContextFile = inputFile
auto` and its `Left (ContextDecodeFailed …)` fail-fast return — *sibling evidence, not an amoebius result* —
so nothing is ever reconciled against a config that did not fully decode.

### Deliverables
- `decodeCluster :: FilePath -> IO (Either DecodeError ClusterIR)` over the native `dhall` library, with a
  structured `DecodeError` tagged by the class of failure (schema mismatch, out-of-domain arm, un-spellable
  combination).
- A totality guard: the decode path is strict and provably free of `error`/`undefined`/partial matches.

### Validation
1. A malformed or out-of-domain value returns a structured `Left DecodeError`; the partiality gate reports no
   partial call reachable from `decodeCluster`.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 5.4: The Gate-2 decode battery (`dsl-spec`) — the gate 📋

**Status**: Planned
**Implementation**: `test/dsl/DecodeSpec.hs`; positive fixtures reuse Phase 4's
`dhall/examples/legal_*.dhall`; a representative Gate-2 negative set `dhall/examples/illegal_decode_*.dhall`
— target paths, not yet built.
**Blocked by**: Sprint 5.3, Sprint 5.1; Phase 4 gate (the positive Gate-1 corpus).
**Independent Validation**: `cabal test dsl-spec` is green — each positive fixture decodes to its
`ClusterIR`; each Gate-2 negative returns a structured `Left` with the expected tag; the suite is red if any
Gate-2-illegal fixture decodes.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (backlink: the decode-foreclosed entries
exercised here → layer-2 Register-1), `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/README.md` (flip the Phase-5 status when the gate passes).

### Objective
Adopt [`testing_doctrine.md §2 — Register 1`](../documents/engineering/testing_doctrine.md): assemble the
in-process decode battery that proves the total decoder decodes every positive fixture and returns a
structured `Left` on each representative Gate-2 negative, emitting a Register-1 proven/tested/assumed ledger
with model↔runtime correspondence marked UNVERIFIED (owned by Phase 20). The exhaustive per-catalog-entry
corpus, the QuickCheck closure/round-trip/fold-totality properties, and the per-entry validation-locus ledger
are the front-loaded next phase ([Phase 6](phase_06_illegal_state_corpus.md)); the capacity/topology fold
negatives are [Phase 7](phase_07_capacity_topology_folds.md).

### Deliverables
- `test/dsl/DecodeSpec.hs` asserting: each `legal_*.dhall` positive fixture decodes to its `ClusterIR`; each
  `illegal_decode_*.dhall` Gate-2 negative returns the expected structured `Left DecodeError`.
- A Register-1 ledger led by a Tier-2-UNVERIFIED banner: the decoder is proven total in-process, but no
  runtime-enforcement claim is made.

### Validation
1. `cabal test dsl-spec` is green — positives decode, Gate-2 negatives return the tagged `Left`, and the
   totality assertion holds; the suite is red if any illegal fixture decodes.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/dsl_doctrine.md` — backlink §5's Gate 2 to the in-process Phase-5 decoder; keep the
  runtime-enforcement half as Tier-2 residue owned by Phase 20.
- `documents/illegal_state/illegal_state_catalog.md` — annotate each entry the IR type-/decode-forecloses here
  with its realized foreclosure layer (layers 1–2 → Register-1); keep runtime-checked entries (layer 3)
  deferred, and the capacity/topology fold entries deferred to Phase 7.
- `documents/engineering/testing_doctrine.md` — record the Register-1 in-process ledger variant this gate
  emits (correspondence and runtime fidelity UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-5 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-5 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register the `amoebius` cabal package, `src/Amoebius/Dsl/{Types,
  SmartConstructors,Ref,Decode,Error}.hs`, and the `dsl-spec` test-suite as Phase-5 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL vision
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §5 the two typed gates; Gate 2 is adopted here
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §4 the typing techniques the
  IR carries; §2/§6 the load-bearing limit and the honest foreclosure-layer split
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_04](phase_04_dhall_gate1_schema.md) — Gate 1, the Dhall schema this decoder mirrors
- [phase_06](phase_06_illegal_state_corpus.md) — the exhaustive illegal-state corpus, properties, and
  validation-locus ledger built atop this decoder
- [phase_07](phase_07_capacity_topology_folds.md) — the capacity/topology decode-folds deferred from here
- [phase_20](phase_20_live_dsl_singleton.md) — the Tier-2 runtime-enforcement half of the DSL
