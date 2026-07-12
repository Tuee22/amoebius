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
inhabitant — together with the fail-closed decoder `decodeCluster :: FilePath -> IO (Either DecodeError ClusterIR)`
built on the native `dhall` library's `Dhall.inputFile auto` wrapped in an exception-catch. Totality here is
defined precisely: every input, well-typed or not, yields `Right` or a structured `Left` *without throwing*.
The pure decode code carries no `error`/`undefined`/partial head (checked non-partial); and because
`Dhall.inputFile auto` alone throws (`DhallErrors`, IO exceptions) rather than returning `Left`, the
exception-catch wrapper catches those and maps them to a structured `Left DecodeError` (fail-closed) so no
throw escapes into a half-applied effect. What is *not* here: the chain
/ reconcile / singleton runtime (Phase 22), the capacity and topology decode-folds (Phase 7), the capability
→ provider binder (Phase 8), and the exhaustive illegal-state corpus with its per-entry validation-locus
ledger and QuickCheck properties (Phase 6). This phase checks the decoder is non-partial, fail-closed, and structurally
rejecting on a representative Gate-2 negative set; the exhaustive corpus rides on top of it next.

**Substrate:** `none` — no host, no cluster; the gate is an in-process `cabal test` battery analogous to the
Phase-0 documentation lint and the Phase-4 `dhall type` corpus.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `cabal test dsl-spec` is green — each positive fixture decodes through the fail-closed `decodeCluster`
into its `ClusterIR`, each Gate-2-class negative fixture **first passes `dhall type` (Gate-1-green
precondition, so its rejection is attributable to the decoder alone, not to Gate 1)** and then returns a
structured `Left DecodeError` with its expected tag, and the decode path is checked non-partial and fail-closed
(deep-NF strict evaluation via an `NFData ClusterIR` instance forced by `evaluate . force` on the decode path;
`-Wall` + a partiality grep proving no `error`/`undefined`/partial match in the pure code; and an
exception-catch wrapper mapping every thrown `DhallError`/IO exception to a structured `Left`) — a
**Register-1** in-process check that runs on no substrate. This checks non-partiality of the pure code and
fail-closure on thrown exceptions; it is not a proof of termination or of exception-freedom of the underlying
`dhall` library.

**Committed oracle, corpus, and mutant (§M clauses 1/2/7/8).** The gate's oracle side is authored and
committed in **Phase 0 before the decoder exists** — never regenerated from `decodeCluster`'s own output. It
comprises: (a) the **representative Gate-2 negative set**, defined concretely as **exactly one negative fixture
per named `DecodeError` failure class** — `SchemaMismatch`, `OutOfDomainArm`, `UnspellableCombination` — each
`illegal_decode_*.dhall` fixture mapped in its committed header to a specific `illegal_state_catalog.md` entry
and pinned to its expected tag; the suite is **red if any of the three tag arms has zero fixtures** (so a
blanket catch-all tag cannot pass) and red if any negative fails its `dhall type` precondition. (b) The
**minimal-pair compile-fail set** for each of §4.2/§4.3/§4.4 (see Sprint 5.2). (c) **>=1 committed seeded
mutant that must go red, committed and re-run** (not run once): the mutant `illegal_decode_schema.dhall`
→ legalized twin (a negative whose Gate-2-illegal index is corrected so it would decode) **must turn the suite
red**, demonstrating the "any illegal fixture decodes ⇒ red" polarity is an executed check, not a restated
assertion. The expected-tag reference table is the committed Phase-0 header set, independent of the decoder's
own fold (§M clause 3).

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
succeed under GHC 9.12.4 / Cabal 3.16.1.0 using the Phase-1 pin. Disambiguation of "no `PATH`-resolved tool"
(the one interpretation both engineers now share, since this validation has no amoebius binary): the harness
resolves `ghc`/`cabal`/`dhall` to the **absolute paths recorded in the Phase-1 pin manifest** and invokes them
by absolute path, and an **OS-boundary argv observer** (an argv-recording shim on `PATH`, per §M clause 5)
records that every toolchain and `dhall` invocation during this sprint's build/test carried an absolute
program path — the shim's own log is red if any invocation resolved a bare name via ambient `PATH`. This is an
external-observer trace, not a self-report by the build script.
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
**Independent Validation**: the catalog's decode-foreclosed classes (§4.2/§4.3/§4.4) have no inhabitant,
proven by **committed minimal-pair compile-fail fixtures** (not absence-by-omission). For each of §4.2 (phantom
tenant), §4.3 (GADT transition index), and §4.4 (ownership index) the phase commits **two source fixtures
differing only in the one index** (tenant tag / state index / owner): the **legal twin must compile** *and*
must be the exact constructor a **named Phase-4 positive fixture demonstrably decodes through** (the fixture
header cites which `legal_*.dhall`), while the **illegal twin must fail `ghc -fno-code` with a type error whose
message names that same constructor/index**. Because the legal twin is a required-to-compile, actually-decoded
constructor, an impoverished vocabulary that spells cross-tenant references freely fails its legal twin (or
fails to decode the cited positive), so the pair cannot be satisfied by a strawman `mkCrossTenantRef` that was
simply never defined. The compile-fail message locus (expected type-error text) is committed in Phase 0
alongside the fixtures. The exhaustive compile-fail corpus is assembled in Phase 6.
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

### Deliverables
- The committed minimal-pair compile-fail fixtures: for each of §4.2/§4.3/§4.4, a legal twin (compiles; cited
  to a named `legal_*.dhall` positive it decodes through) and an illegal twin (fails `ghc -fno-code` with a
  type error naming the same constructor/index), plus each pair's committed expected type-error locus.

### Validation
1. For each of §4.2/§4.3/§4.4, the committed minimal pair holds: the legal twin compiles **and** is the
   constructor a named Phase-4 positive fixture decodes through, and the illegal twin fails `ghc -fno-code`
   with a type error naming that same constructor/index (matching the committed locus). The check is red if the
   legal twin fails to compile or to decode its cited positive (foreclosing absence-by-omission), or if the
   illegal twin's failure locus does not match. The legal vocabulary compiles.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 5.3: The fail-closed decoder (`Dhall.inputFile auto` + exception-catch) + structured `DecodeError` 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Dsl/Decode.hs` (`decodeCluster :: FilePath -> IO (Either DecodeError
ClusterIR)` = `Dhall.inputFile auto` wrapped in an exception-catch that maps thrown `DhallErrors`/IO
exceptions to `Left DecodeError`; non-partial + fail-closed) and `src/Amoebius/Dsl/Error.hs` (the tagged
`DecodeError` type) — target paths, not yet built.
**Blocked by**: Sprint 5.2.
**Independent Validation**: the decode path returns `Either DecodeError ClusterIR` and never throws into a
half-applied effect; a `-Wall` + partiality grep gate confirms no `error`/`undefined`/partial head reachable
from `decodeCluster`; and "strictness forces the decoded value" is disambiguated to **deep normal form**: an
`NFData ClusterIR` instance is derived and the decode path runs `evaluate . force` on the `Right` value, so a
hidden unevaluated bottom in any field surfaces as a caught exception mapped to `Left` rather than passing a
shallow `Right _` match. `DecodeError` distinguishes at least the three named failure classes as distinct
constructors — `SchemaMismatch`, `OutOfDomainArm`, `UnspellableCombination` — so a blanket catch-all tag is a
type-level regression, not a passing implementation.
**Docs to update**: `documents/engineering/dsl_doctrine.md` (§5 Gate-2 backlink to the in-process decoder),
`documents/engineering/testing_doctrine.md` (the Register-1 in-process ledger variant),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`dsl_doctrine.md §5 — Gate 2, the Haskell typed decoder`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
implement the fail-closed in-process decoder that mirrors hostbootstrap's `decodeContextFile = inputFile
auto` and its `Left (ContextDecodeFailed …)` fail-fast return — *sibling evidence, not an amoebius result* —
so nothing is ever reconciled against a config that did not fully decode.

### Deliverables
- `decodeCluster :: FilePath -> IO (Either DecodeError ClusterIR)` over the native `dhall` library, with a
  structured `DecodeError` whose class of failure is carried by **distinct constructors** — `SchemaMismatch`,
  `OutOfDomainArm`, `UnspellableCombination` — not a single catch-all arm; and an `NFData ClusterIR` instance
  the decode path forces with `evaluate . force` so the `Right` value is proven deep-NF-total, not merely WHNF.
- An exception-catch wrapper around `Dhall.inputFile auto`: because `Dhall.inputFile auto` alone throws
  (`DhallErrors`, IO exceptions) rather than returning `Left`, it does not satisfy the never-throw contract on
  its own; the wrapper catches those and maps them to a structured `Left DecodeError` (fail-closed).
- A non-partiality guard: the pure decode code is strict and, under `-Wall` + a partiality grep, free of
  `error`/`undefined`/partial matches. Together with the wrapper this delivers a checked-non-partial,
  fail-closed decode — not a proof of termination or of exception-freedom of the underlying `dhall` library.

### Validation
1. A malformed or out-of-domain value returns a structured `Left DecodeError` — including inputs on which
   `Dhall.inputFile auto` throws, which the wrapper catches and tags rather than propagating; the partiality
   gate reports no partial call reachable from the pure decode code; and the `evaluate . force` on the decoded
   value converts any hidden bottom into a caught `Left` (deep-NF check, not a shallow `Right _` match).
2. The three named failure classes are **distinct constructors** and each is reachable: a decode reproducing a
   thunked/bottom field is caught as `Left` rather than escaping — proving the deep force is on the live path.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 5.4: The Gate-2 decode battery (`dsl-spec`) — the gate 📋

**Status**: Planned
**Implementation**: `test/dsl/DecodeSpec.hs`; positive fixtures reuse Phase 4's
`dhall/examples/legal_*.dhall`; a representative Gate-2 negative set `dhall/examples/illegal_decode_*.dhall`
— target paths, not yet built.
**Blocked by**: Sprint 5.3, Sprint 5.1; Phase 4 gate (the positive Gate-1 corpus).
**Independent Validation**: `cabal test dsl-spec` is green — each positive fixture decodes to its
`ClusterIR`; **each `illegal_decode_*.dhall` negative first passes `dhall type` (Gate-1-green precondition)
and then** returns a structured `Left` with the expected tag pinned in its committed header; the suite is red
if any negative fails `dhall type` (so the rejection is Gate-2's, not Gate-1's — foreclosing negatives that
are merely ill-typed Dhall), red if any Gate-2-illegal fixture decodes, and red if any of the three
`DecodeError` tag arms has zero fixtures. The "red if any illegal fixture decodes" polarity is proven by an
**executed committed mutant** (below), not a restated assertion. The expected-tag oracle is the committed
Phase-0 fixture-header table, independent of the decoder's own fold (§M clause 3).
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (backlink: the decode-foreclosed entries
exercised here → layer-2 Register-1), `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/README.md` (flip the Phase-5 status when the gate passes).

### Objective
Adopt [`testing_doctrine.md §2 — Register 1`](../documents/engineering/testing_doctrine.md): assemble the
in-process decode battery that exercises the fail-closed decoder over every positive fixture and confirms it
returns a structured `Left` on each representative Gate-2 negative, emitting a Register-1 proven/tested/assumed ledger
with model↔runtime correspondence marked UNVERIFIED (owned by Phase 22). The exhaustive per-catalog-entry
corpus, the QuickCheck closure/round-trip/fold-totality properties, and the per-entry validation-locus ledger
are the front-loaded next phase ([Phase 6](phase_06_illegal_state_corpus.md)); the capacity/topology fold
negatives are [Phase 7](phase_07_capacity_topology_folds.md).

### Deliverables
- `test/dsl/DecodeSpec.hs` asserting: each `legal_*.dhall` positive fixture decodes to its `ClusterIR`; each
  `illegal_decode_*.dhall` Gate-2 negative first passes `dhall type` then returns the expected structured
  `Left DecodeError` whose tag matches its committed header.
- The **concretely named representative Gate-2 negative set** (§M clause 7), committed in Phase 0: **exactly
  one `illegal_decode_*.dhall` fixture per named `DecodeError` class** — `illegal_decode_schema.dhall`
  (`SchemaMismatch`), `illegal_decode_domain.dhall` (`OutOfDomainArm`), `illegal_decode_unspellable.dhall`
  (`UnspellableCombination`) — each header citing the `illegal_state_catalog.md` entry it targets and each
  paired with a positive `legal_*.dhall` differing only in the foreclosed dimension (§M clause 8). Every one
  passes `dhall type` (Gate-1-green) by construction.
- **A committed seeded mutant** (§M clause 2), committed and re-run: a legalized twin of
  `illegal_decode_schema.dhall` whose Gate-2-illegal index is corrected so the value would decode; the suite
  **must go red** when the mutant replaces its negative, demonstrating the "any illegal fixture decodes ⇒ red"
  check actually executes.
- A Register-1 ledger led by a Tier-2-UNVERIFIED banner: the decoder is checked non-partial and fail-closed
  in-process, but no runtime-enforcement claim is made.

### Validation
1. `cabal test dsl-spec` is green — positives decode; every `illegal_decode_*.dhall` negative first passes
   `dhall type` (suite red otherwise) and then returns the tagged `Left` matching its committed header; all
   three `DecodeError` tag arms have >=1 fixture (suite red if any arm is empty); and the deep-NF force and
   fail-closed assertions hold.
2. The committed seeded mutant (the legalized twin of `illegal_decode_schema.dhall`) turns the suite **red**
   when substituted — a re-run, executed demonstration that "any illegal fixture decodes ⇒ red" is a live
   check, not a tautological restatement of the assertion's polarity.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/dsl_doctrine.md` — backlink §5's Gate 2 to the in-process Phase-5 decoder; keep the
  runtime-enforcement half as Tier-2 residue owned by Phase 22.
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
- [phase_22](phase_22_live_dsl_singleton.md) — the Tier-2 runtime-enforcement half of the DSL
