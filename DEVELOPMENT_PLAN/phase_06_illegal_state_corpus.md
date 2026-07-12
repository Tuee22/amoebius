# Phase 6: Illegal-state corpus + property tests + validation-locus ledger

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_07_capacity_topology_folds.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Assemble the exhaustive illegal-state corpus — every negative fixture split by the locus that
> rejects it — plus the QuickCheck property suite and the per-entry validation-locus ledger, in-process,
> before any real resource exists.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 5 Gate-2 gate passes and
runs on **no substrate** (`none`) in **Register 1** — it stands up no host and no cluster, only an in-process
corpus battery over the `dhall` typechecker, the Phase-5 decoder, a pinned `ghc -fno-code` expect-fail
harness, and QuickCheck. Where a shape below is already exercised in a sibling system (prodbox's single-owner
SSoT, Keycloak-owns-ingress; hostbootstrap's `inputFile auto` fail-fast decode), that is **sibling evidence,
not an amoebius result**.

## Phase Summary

This phase turns the two typed gates stood up in Phases 4 and 5 into an *exhaustive*, honestly-classified
proof. Phase 4 proved Gate 1 rejects a representative Gate-1-class negative set; Phase 5 proved the total
decoder rejects a representative Gate-2-class negative set. This phase assembles the **whole** illegal-state
corpus — one negative fixture per catalog entry that Register 1 can settle — and requires each to be rejected
at exactly the locus its catalog classification names: a Gate-1 negative must fail `dhall type`, a Gate-2
negative must pass `dhall type` and then decode to a structured `Left`, and a GADT-index (type-foreclosed)
negative must fail to compile under a pinned `ghc -fno-code` expect-fail golden. It adds the QuickCheck
property suite that establishes closure, round-trip, fold-totality, and composition-preservation over the
smart-constructor vocabulary, sampled where the domain is infinite and exhausted where it is finite (the three
`Rke2Servers` arms). It then emits the **per-entry validation-locus ledger**: a map from every catalog entry
to the one truth-maker locus that settles it — `Gate-1-editor`, `Gate-2-decoder`, `rendered-output-golden`,
or `live-effect` — asserting that the two Register-1 loci actually carry a rejecting fixture here and recording
the other two as deferred to their owning phase. What is *not* here: the capacity/topology decode-folds and
their negatives (Phase 7), the rendered-output goldens the `rendered-output-golden` locus points at (Phase 9),
the representational SPA-composition corpus (Phase 13), and every `live-effect` residue (the live band).

**Substrate:** `none` — no host, no cluster; the gate is an in-process `cabal test` + `dhall type` +
`ghc -fno-code` corpus battery analogous to the Phase-0 documentation lint.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** every negative fixture is rejected at its tagged locus — each Gate-1-class negative fails
`dhall type` at authoring time with the error pinned to a **Phase-0-committed** `dhall type` error-locus golden
naming the foreclosing union/field (§8 specific-reason), each Gate-2-class negative passes `dhall type` and
decodes to a structured `Left DecodeError` whose tag equals a **Phase-0-committed** expected-`DecodeError`-tag
golden, and each GADT-index negative fails to compile under the pinned `ghc -fno-code` expect-fail golden with a
GHC **type** error (not a scope/parse error) pinned to a committed expected-error-locus golden — the suite is
red if any illegal fixture is admitted at or past its locus; QuickCheck is green under `checkCoverage`
(closure / round-trip / fold-totality / composition-preservation) with the coverage minima of Sprint 6.3 met;
and the per-entry validation-locus ledger (`Gate-1-editor` / `Gate-2-decoder` / `rendered-output-golden` /
`live-effect` / `deferred-to-Phase-7`) is emitted with every catalog entry mapped to its truth-maker locus and
that map **reconciled against the catalog's own committed per-entry `**Validation-locus:**` tags** (the
independent oracle of §3), red on any divergence — a **Register-1** in-process check that runs on no substrate.

**Gate integrity (§M).** This gate satisfies the eight §M clauses through the following committed apparatus,
all authored and committed in Phase 0 **before** the corpus implementation exists (§1 oracle-pinning):

- **Oracle-pinning (§1) + specific-reason negatives (§8).** Each negative fixture ships a committed expected-failure
  golden authored by hand, not regenerated from the implementation: `dhall/examples/goldens/<name>.typeerr`
  (the `dhall type` error, naming the offending union/field) for each `illegal_gate1_*`;
  `test/dsl/goldens/<name>.tag` (the expected `DecodeError` constructor tag) for each `illegal_decode_*`;
  `test/dsl/compilefail/<name>.expected` (the expected GHC type-error class + locus) for each compile-fail golden.
  The suite asserts the observed failure **equals** its golden, not merely that some failure occurred.
- **Independent reference predicate (§3).** The validation-locus reference side is the catalog's committed
  per-entry `**Validation-locus:**` tags in `documents/illegal_state/illegal_state_*.md` (reconciled by the
  Phase-0 lint into `dhall/examples/locus_registry.tsv`), authored independently of `ValidationLocusLedger.hs`;
  the coverage assertion reads that registry, never the emitter's own classification.
- **Committed mutation quota (§2).** Four committed seeded mutants (from the §M operator set) MUST turn the gate
  red, re-run each gate run: (a) a **union-arm-addition** schema mutant admitting a product-named capability →
  `CorpusSpec` red; (b) a **dropped-fold** decoder mutant deleting the rke2 host-distinctness check → the §3.16
  Gate-2 negative admitted → `CorpusSpec` red; (c) a **guard-weakening** GADT-index mutant widening one index →
  a compile-fail golden compiles → `compile_fail.sh` red; (d) a **broken-smart-constructor / partialized-fold**
  mutant → each of the four QuickCheck properties red. The gate is itself red if any mutant survives.
- **Generator coverage (§4).** Sprint 6.3's `checkCoverage` minima (below) force the nontrivial reject/boundary
  arms to fire.
- **Concrete corpus (§7).** The representative set is enumerated explicitly in the Sprint 6.1/6.2 Deliverables
  and the committed `locus_registry.tsv`, not left to "representative".

## Doctrine adopted

- [`illegal_state_catalog.md §6 — Three layers of foreclosure (and the honesty they force)`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force):
  the three foreclosure layers (`type-foreclosed` / `decode-foreclosed` / `runtime-checked`) and the
  **Gate-1-vs-Gate-2 caveat** — Dhall has no opaque types, so the corpus must **split** its negatives into
  *Gate-1-must-fail-`dhall type`* and *Gate-2-must-fail-decode*, and never bill a Gate-2-only foreclosure as a
  Gate-1 type-check failure. This phase reifies that split as fixtures.
- [`illegal_state_catalog.md §5 — Coverage matrix`](../documents/illegal_state/illegal_state_techniques.md#5-coverage-matrix--which-technique-forecloses-which-illegal-state)
  and [`§2 — the load-bearing limit`](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it):
  the coverage matrix is the checklist the corpus must exhaust — one fixture per Register-1-settleable entry —
  and §2's limit is honored verbatim: *a type-check proves the spec composes, not that the cluster enforces
  it.* Entries whose truth-maker is the running cluster are ledgered `live-effect`, never claimed here.
- [`dsl_doctrine.md §5 — the illegal-state-unrepresentable contract`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  the **two typed gates** — Gate 1 (the Dhall typechecker) and Gate 2 (the in-process `Dhall.inputFile auto`
  decoder). This phase exercises both against the exhaustive negative corpus and pins the type-foreclosed
  residue with the compile-fail golden that gives the GADT indices their teeth.
- [`testing_doctrine.md §2 — three registers`](../documents/engineering/testing_doctrine.md) — **Register 1**
  (pure/golden, in-process, no cluster): the register this phase's gate reaches; and
  [`§4 — the per-run ledger`](../documents/engineering/testing_doctrine.md) — the proven/tested/assumed ledger
  the battery emits, the validation-locus ledger being its per-catalog-entry specialization with model↔runtime
  correspondence marked UNVERIFIED.
- [`conformance_harness_doctrine.md §2 — the registers`](../documents/engineering/conformance_harness_doctrine.md)
  and [`§5 — honesty`](../documents/engineering/conformance_harness_doctrine.md): Register 1 is the pure/golden
  no-cluster band, and a green Register-1 corpus establishes the spec composes and the foreclosures fire —
  **nothing** about whether the physical effects converge, which is the deferred `live-effect` locus.

## Sprints

## Sprint 6.1: Exhaustive negative/positive corpus split by foreclosure locus 📋

**Status**: Planned
**Implementation**: `dhall/examples/{legal_*,illegal_gate1_*,illegal_decode_*}.dhall` (extending the Phase-4
positive + Gate-1 corpus and the Phase-5 Gate-2 set to one fixture per Register-1-settleable catalog entry);
`test/dsl/CorpusSpec.hs` (per-case exhaustive, tagged by locus) — target paths, not yet built.
**Blocked by**: Phase 5 gate (the total decoder + GADT-indexed IR); Phase 4 gate (the Gate-1 schema + positive
corpus). External prerequisite: the `dhall` CLI and the Phase-1 `allow-newer`/pin.
**Independent Validation**: every Gate-1-tagged negative fails `dhall type` **with the error matching its
committed `<name>.typeerr` golden** (naming the foreclosing union/field), and its legal near-miss twin passes
`dhall type`; every Gate-2-tagged negative passes `dhall type` and then decodes to a `Left DecodeError` **whose
tag equals its committed `<name>.tag` golden**, and its legal twin decodes; every positive fixture decodes; the
coverage note maps each fixture to its catalog entry and layer and is reconciled against the committed
`locus_registry.tsv`; the committed union-arm-addition schema mutant (a) and the dropped-fold decoder mutant
(b) each turn `CorpusSpec` red when re-applied; and `CorpusSpec` is red if any illegal fixture is admitted at or
past its tagged locus, if any twin fails, or if any observed error diverges from its golden.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (per-entry gate-case backlink),
`DEVELOPMENT_PLAN/system_components.md` (corpus inventory), this document.

### Objective
Adopt [`illegal_state_catalog.md §5/§6`](../documents/illegal_state/illegal_state_techniques.md#5-coverage-matrix--which-technique-forecloses-which-illegal-state):
assemble the corpus that exercises the type discipline exhaustively over the coverage matrix, **honestly split
by the locus that rejects each fixture** — Gate-1 negatives that must fail `dhall type`, Gate-2 negatives that
must pass `dhall type` and decode-reject — never billing a Gate-2-only foreclosure as a Gate-1 failure.

### Deliverables
- Positive fixtures (`legal_multisubstrate_cluster`, `legal_managed_eks`, `trivial_app`, a deployment-rules
  fixture) that decode, carried forward from Phase 4/5.
- Gate-1 negatives (`illegal_gate1_*`, must fail `dhall type`): product-named capability (§3.12), insecure /
  backdoor ingress arm (§3.7), unbounded storage backing / un-tiered topic (§3.18/§3.20), growth with no
  scaling policy (§3.21), even/zero-server rke2 control plane (§3.24), non-CBOR payload (§3.23), and a
  substrate/topology arm the union does not offer (§3.14/§3.15).
- Gate-2 negatives (`illegal_decode_*`, must pass `dhall type`, then decode-reject): rke2 host-distinctness /
  reused host (§3.16). The **complete, enumerated** Gate-2 fixture set owed by this phase is exactly the catalog
  entries whose committed `**Validation-locus:**` tag is `Gate-2-decoder` **and** which are NOT on the explicit
  `deferred-to-Phase-7` list below — the set is fixed by the committed `locus_registry.tsv`, not by the
  implementer's reading of "whose fold is present". The capacity/topology aggregate negatives
  (§3.13/§3.17–§3.19) are the enumerated `deferred-to-Phase-7` set: they are named here explicitly, carry no
  fixture in this phase, and MUST be marked `deferred-to-Phase-7` in the ledger (never reclassified to
  `live-effect` or `rendered-output-golden`) — deferral to [Phase 7](phase_07_capacity_topology_folds.md).
- **Near-miss twinning (forecloses wrong-reason negatives, §8).** Each Gate-1 negative is a **single-construct
  mutation** of a named committed legal fixture (its `legal_*` twin, differing only in the one foreclosed
  dimension), and that twin MUST pass `dhall type`; the negative's `dhall type` error MUST equal the committed
  `<name>.typeerr` golden that names the foreclosing union/field, so a fixture that fails for an unrelated
  reason (typo, missing field, syntax error) does not pass. Each `illegal_decode_*` negative is likewise a
  single-field mutation of a legal twin that decodes, and asserts its committed expected `DecodeError` tag.
- **Per-Register-1-locus fixtures (disambiguation).** A catalog entry carrying more than one Register-1 locus
  (e.g. §3.16 = `Gate-1-editor` cardinality sub-part + `Gate-2-decoder` distinctness fold) owes **one fixture
  per Register-1 locus it carries**, each rejected at its own locus — not one fixture total. The ledger's
  single "truth-maker locus" per entry is the earliest-sufficient among the loci it carries (§8 tie-break:
  `Gate-1-editor` < `Gate-2-decoder`), but the corpus still supplies every Register-1 sub-fixture.

### Validation
1. Every negative fixture is rejected at its tagged locus (Gate 1 / Gate 2) with its observed failure matching
   its committed expected-error golden (`<name>.typeerr` / `<name>.tag`) and its legal near-miss twin passing;
   the suite is red if any illegal fixture is admitted, if any twin fails, or if any observed error diverges
   from its golden; every positive fixture decodes; the coverage note maps each fixture to a catalog entry and
   is reconciled against the committed `locus_registry.tsv`; and the committed seeded mutants (a) and (b) each
   turn `CorpusSpec` red.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 6.2: GADT-index compile-fail goldens (type-foreclosed layer) 📋

**Status**: Planned
**Implementation**: `test/dsl/compilefail/*.hs` (each a minimal module that spells an illegal combination) +
`tools/compile_fail.sh` (a pinned `ghc -fno-code` expect-fail harness) — target paths, not yet built.
**Blocked by**: Sprint 6.1; Phase 5 gate (the GADT-indexed IR whose indices these goldens probe).
**Independent Validation**: each compile-fail golden imports **only the real exported vocabulary**, is
scope-clean and parse-clean, and **fails to compile** under the pinned `ghc -fno-code` harness with a GHC
**type** error (error-class checked via structured diagnostics / `-fdiagnostics-as-json` or a pinned
`--json`-derived tag — a scope/parse/name error does NOT satisfy the golden) whose class and locus **match the
committed `test/dsl/compilefail/<name>.expected` golden**; each golden has a **one-token legal twin** that
compiles (the twin differs only in the single foreclosed index); the harness is red if any golden compiles, if
any golden fails for a non-type reason, or if any observed diagnostic diverges from its `.expected` golden; the
committed guard-weakening GADT-index mutant (c) makes at least one golden compile and thereby turns the harness
red; and a companion positive module (the legal vocabulary) compiles.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (per-entry type-foreclosed annotation for
the entries pinned here), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt the [`illegal_state_catalog.md §6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
`type-foreclosed` layer at its strongest: give the GADT indices their teeth by proving the illegal value has
**no inhabitant** — it does not merely decode to a `Left`, it does not compile at all. This is the residue the
Phase-4 honesty caveat routed here, since Dhall has no opaque types.

### Deliverables
- Compile-fail goldens for the type-foreclosed entries the IR indices foreclose: a cross-tenant `Ref`
  (§3.8/§3.10), a PVC with no matching PV (§3.2), an endpoint-kind interconversion (§3.7), and a route built
  from no live service handle (§3.3) — each an expect-fail module that must not compile.
- A pinned `ghc -fno-code` expect-fail harness reporting one aggregate green/red over the golden set, plus a
  positive control module that compiles. Each golden ships a committed `test/dsl/compilefail/<name>.expected`
  golden (expected GHC error class = type-error, plus locus) authored in Phase 0, and a one-token legal twin.
- The committed guard-weakening GADT-index mutant (c) — used to prove the harness actually rejects.

### Validation
1. Every compile-fail golden imports only real exported vocabulary, is scope/parse-clean, and fails to compile
   with a GHC **type** error (error-class asserted, not merely "fails") matching its committed `.expected`
   golden; its one-token legal twin compiles; the harness is red if any golden compiles, fails for a non-type
   reason, or diverges from its golden; the seeded mutant (c) turns the harness red; the positive control
   compiles.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 6.3: QuickCheck property suite 📋

**Status**: Planned
**Implementation**: `test/dsl/DecisionPropSpec.hs` (`prop_smartCtorClosure`, `prop_decodeRoundTrip`,
`prop_foldTotal`, `prop_compositionPreservesWellFormedness`) — target paths, not yet built.
**Blocked by**: Sprint 6.1; Phase 5 gate (the decoder + smart constructors under test).
**Independent Validation**: `cabal test` runs the property suite green **under `checkCoverage`** — closure holds
over the smart-ctor vocabulary, decode round-trips, every fold is total on generated input, and composition
preserves well-formedness; each property declares `cover`/`classify` obligations with the minima below and the
run fails if a minimum is not met (so a generator emitting one trivial value cannot pass); each property is
labelled TESTED (sampled) or PROVEN (exhausted finite domain); and the committed
broken-smart-constructor / partialized-fold mutant (d) makes **each** of the four properties red when applied —
the suite is red if that mutant survives any property.
**Docs to update**: `documents/engineering/testing_doctrine.md` (the sampled-vs-exhausted label discipline),
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`illegal_state_catalog.md §6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
and [`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md): establish the
closure / round-trip / fold-totality / composition-preservation properties of the type discipline, labelled
honestly — **TESTED (sampled)** for infinite domains, upgraded to **PROVEN** only where a finite domain is
exhausted (the three `Rke2Servers` arms).

### Deliverables
- `prop_smartCtorClosure` (a smart constructor never yields an illegal value), `prop_decodeRoundTrip`
  (encode∘decode is identity on well-formed IR), `prop_foldTotal` (every decode-time fold terminates on
  generated input without partiality), and `prop_compositionPreservesWellFormedness` (composing two
  well-formed fragments yields a well-formed value).
- A per-property label: TESTED (sampled) by default; PROVEN for the exhausted `Rke2Servers` finite domain.
- **Declared coverage minima (forecloses vacuous generators, §4).** Each property runs under `checkCoverage`
  with explicit `cover` obligations forcing its nontrivial arms: `prop_smartCtorClosure` covers each
  smart-constructor family (≥ 15% each, ≥ 3 distinct families); `prop_decodeRoundTrip` covers non-empty
  multi-substrate and multi-service IR (≥ 20% multi-substrate, ≥ 20% ≥2-service); `prop_foldTotal` covers each
  distinct fold with a boundary/near-illegal-but-legal input (≥ 10% per fold); `prop_compositionPreservesWell-
  formedness` covers non-identity compositions of two distinct non-trivial fragments (≥ 25%). Generators that
  emit a single trivial value fail the coverage check and the suite is red.
- The committed broken-smart-constructor / partialized-fold seeded mutant (d) that must turn each property red.

### Validation
1. The property suite is green under `checkCoverage` with every declared `cover` minimum met (a generator
   emitting one trivial value fails); the exhausted-domain properties are marked PROVEN, the sampled ones
   TESTED — no sampled property is billed as a proof; and the seeded mutant (d) turns each of the four
   properties red.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 6.4: The per-entry validation-locus ledger — the gate 📋

**Status**: Planned
**Implementation**: `test/dsl/ValidationLocusLedger.hs` (the ledger emitter + the coverage assertion, run as
part of `dsl-spec`) — target paths, not yet built. The emitted ledger artifact is a **generated** Register-1
output and is **never committed** ([`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md)).
**Blocked by**: Sprint 6.1, Sprint 6.2, Sprint 6.3.
**Independent Validation**: the emitter maps every catalog entry to exactly one truth-maker locus
(`Gate-1-editor` / `Gate-2-decoder` / `rendered-output-golden` / `live-effect` / `deferred-to-Phase-7`), and the
coverage assertion **reconciles that map against the catalog's committed per-entry `**Validation-locus:**` tags
(the independent oracle in `documents/illegal_state/illegal_state_*.md`, lint-reconciled into the committed
`dhall/examples/locus_registry.tsv`)** — it is red on ANY entry whose emitter locus differs from the registry
tag, so the emitter cannot itself decide which class owes a fixture. It is further red unless: every entry the
registry tags `Gate-1-editor` or `Gate-2-decoder` (and NOT on the enumerated `deferred-to-Phase-7` list) has a
**passing rejecting fixture present in this phase**; every `rendered-output-golden` entry names Phase 9 and
every `live-effect` entry names the live band as deferred; and every §3.13/§3.17–§3.19 entry is marked
`deferred-to-Phase-7` (never reclassified to `live-effect`/`rendered-output-golden`). The registry is
Phase-0-committed and independent of `ValidationLocusLedger.hs`.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (per-entry realized-locus annotation),
`documents/engineering/testing_doctrine.md` (the validation-locus ledger variant),
`DEVELOPMENT_PLAN/README.md` (flip the Phase-6 status when the gate passes).

### Objective
Adopt [`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md) and
[`illegal_state_catalog.md §6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force):
emit the per-entry validation-locus ledger — the honest map from every catalog entry to the one locus that
settles it — and gate on it, so no entry is silently unvalidated and no deferred entry is silently claimed.
The two Register-1 loci (`Gate-1-editor`, `Gate-2-decoder`) are discharged here; `rendered-output-golden` is
recorded as owned by [Phase 9](phase_09_render_manifest_goldens.md) and `live-effect` by the live band.

### Deliverables
- A ledger emitter that classifies each catalog entry into its earliest-sufficient truth-maker locus:
  `Gate-1-editor` (fails `dhall type`, authoring-time), `Gate-2-decoder` (compile-fail golden or decode
  `Left`), `rendered-output-golden` (settled on emitted bytes in Phase 9), `live-effect` (settled only by a
  running cluster, deferred to Register 3), or `deferred-to-Phase-7` (a `Gate-2-decoder`-tagged capacity/
  topology aggregate whose fold lands in Phase 7 — §3.13/§3.17–§3.19). Tie-break for a multi-locus entry: the
  earliest-sufficient Register-1 locus (`Gate-1-editor` < `Gate-2-decoder`), but every Register-1 sub-fixture
  the entry carries is still supplied by Sprint 6.1 (§3.16 → both a Gate-1 and a Gate-2 fixture).
- The committed independent oracle: `dhall/examples/locus_registry.tsv`, reconciled by the Phase-0 lint from
  the catalog's per-entry `**Validation-locus:**` tags, authored independently of the emitter. The enumerated
  `deferred-to-Phase-7` set (§3.13, §3.17, §3.18, §3.19) is listed literally in this phase doc and in the
  registry.
- A coverage assertion that **reconciles the emitter's locus for every entry against the registry** and goes
  red on any divergence, then requires: every non-deferred `Gate-1-editor` / `Gate-2-decoder` entry has its
  rejecting fixture present and passing here; every `rendered-output-golden` / `live-effect` / `deferred-to-
  Phase-7` entry is marked deferred with its owning phase. The emitted ledger leads with a Register-1-only,
  Tier-2-UNVERIFIED banner.

### Validation
1. The ledger emits with every catalog entry mapped to exactly one locus, that map reconciled against the
   committed `locus_registry.tsv` (red on any emitter-vs-registry divergence); the coverage assertion is green —
   every non-deferred Register-1 locus carries a passing rejecting fixture and every deferred locus
   (`rendered-output-golden` → Phase 9, `live-effect` → live band, `deferred-to-Phase-7` → Phase 7 for
   §3.13/§3.17–§3.19) names its owning phase; the suite is red if any entry is unmapped, misclassified relative
   to the registry, or any deferred entry is claimed settled here.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/illegal_state/illegal_state_catalog.md` — annotate each entry with its realized validation locus
  (`Gate-1-editor` / `Gate-2-decoder` → Register-1, discharged here; `rendered-output-golden` → Phase 9;
  `live-effect` → the live band), and confirm the §5 coverage matrix is exhausted for the Register-1 band.
- `documents/engineering/dsl_doctrine.md` — backlink §5's two gates to the exhaustive Phase-6 corpus and the
  compile-fail golden that pins the type-foreclosed layer.
- `documents/engineering/testing_doctrine.md` — record the validation-locus ledger variant and the
  sampled-vs-exhausted QuickCheck label discipline this gate emits (correspondence and runtime fidelity
  UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-6 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-6 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `dhall/examples/illegal_*`, `test/dsl/CorpusSpec.hs`,
  `test/dsl/compilefail/`, `test/dsl/DecisionPropSpec.hs`, and `test/dsl/ValidationLocusLedger.hs` as Phase-6
  design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL vision
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §5 the coverage matrix this
  corpus exhausts; §6 the three foreclosure layers and the honest Gate-1-vs-Gate-2 split
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §5 the two typed gates exercised against the corpus
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger the
  validation-locus ledger specializes
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — §2 the registers,
  §5 the honesty limit (a green Register-1 corpus is not a live-effect claim)
- [phase_04](phase_04_dhall_gate1_schema.md) — Gate 1, the Dhall schema + positive corpus this phase extends
- [phase_05](phase_05_gadt_decoder_gate2.md) — Gate 2, the GADT-indexed IR + decoder this corpus rides atop
- [phase_07](phase_07_capacity_topology_folds.md) — the capacity/topology fold negatives deferred from here
- [phase_09](phase_09_render_manifest_goldens.md) — the `rendered-output-golden` locus this ledger points at
- [phase_22](phase_22_live_dsl_singleton.md) — the live band where the `live-effect` locus is discharged
