# Phase 4: Dhall Gate-1 schema + smart-constructor prelude

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the typed Dhall DSL surfaces and their smart-constructor prelude so that Gate 1 — the
> Dhall typechecker — accepts every positive fixture and rejects every Gate-1-class illegal spec at authoring
> time, before any amoebius binary exists.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 3 gate (the
gateway-migration model) and runs on **no substrate** (`none`) — it stands up no host and no cluster, only the
`dhall` toolchain over text fixtures.

## Phase Summary

This phase delivers the first of the DSL's two typed gates as an in-process, authoring-time proof. It stands
up the Dhall prelude and the typed record/union surfaces — the cluster spec, the app spec, and the
deployment-rules surface — as *data that carries parameters, not logic*, and exposes them only through a
**smart-constructor vocabulary**: a lexicon with no illegal words, in which a whole class of illegal cluster
states has no syntax an author could write. Gate 1 is the Dhall typechecker itself: an expression that does
not match its declared schema simply does not type-check, and the check fires entirely before the amoebius
binary runs — in the operator's editor, in `dhall type`, in CI. The phase assembles the positive corpus that
type-checks and the Gate-1-class negative corpus that fails `dhall type`, and records the honest limit that
binding- and index-shaped foreclosures get only *partial* teeth here (smart-constructor convention) and their
real teeth at the Haskell GADT decoder in Phase 5. This is a **Register 1** (pure/golden, in-process, no
cluster) gate, analogous to the Phase 0 documentation lint: it exercises the `dhall` typechecker over a text
corpus and touches no infrastructure.

**Substrate:** none — no host, no cluster; the gate is an in-process `dhall type` battery over the fixture
corpus.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `dhall type` over the Gate-1 corpus is green — each positive cluster / app / deployment fixture
type-checks, and each Gate-1-class negative fixture fails `dhall type` at authoring time, in the operator's
editor or CI, with no amoebius binary ever run. The gate is bound by the concrete criteria below; a bare
nonzero exit on a negative is not sufficient.

- **Representative set (explicit, §M.7).** The Gate-1-class negative corpus is EXACTLY these seven catalog
  entries, one committed `dhall/examples/illegal_*.dhall` fixture each: product-named capability (§3.12),
  insecure/backdoor ingress arm (§3.7), unbounded storage backing (§3.18), un-tiered / no-retention topic
  (§3.20), capacity-growth-without-scaling-policy (§3.21), even/zero-server rke2 control plane (§3.24), and a
  substrate/topology arm the union does not offer (§3.14/§3.15). The non-CBOR payload entry (§3.23) is a
  layer-2 decode-foreclosure NOT constructible as a Gate-1 `dhall type` fixture; it is recorded in the
  partial-foreclosure ledger as deferred to [Phase 5](phase_05_gadt_decoder_gate2.md)'s Gate 2, never
  counted toward this gate's green. This seven-entry set is the single canonical Gate-1-class membership and
  supersedes any shorter parenthetical elsewhere in this doc.
- **Paired positive per negative (§M.8 / §M.3).** Each `illegal_*.dhall` is a MINIMAL one-construct mutation
  of a named committed green positive (its `legal_*.dhall` sibling): reverting only the single tagged illegal
  construct yields a fixture that type-checks. `tools/dhall_gate1_negatives.sh` asserts BOTH directions per
  fixture — the negative fails `dhall type` AND its reverted paired positive type-checks — and is red if
  either direction is violated.
- **Specific-reason error goldens (§M.8 / §M.1).** For each negative, a golden `dhall type` error transcript
  is authored and COMMITTED IN PHASE 0 (`tests/oracle/gate1/<entry>.err`), pinning the failure to name the
  targeted union/arm/field/record; the harness is red if the observed `dhall type` stderr does not match its
  committed golden (a negative that fails for an unrelated typo/import/field error mismatches and goes red).
- **Arm-inventory oracle, independent of the schema (§M.3).** A committed hand-authored catalog table
  (`tests/oracle/gate1/arm_inventory.csv`, authored in Phase 0 from `illegal_state_catalog` §3.12/§3.24/§3.7,
  NOT derived from the schema modules) pins each union's exact arm set; the harness normalizes each shipped
  schema module and compares its arm inventory byte-exactly against this table, red on any extra (e.g. a
  `Custom : Text` / `Raw : Text` escape arm) or missing arm.
- **Committed seeded mutant (§M.2).** At least one committed seeded mutant MUST turn the harness red and is
  re-run every gate: `mutants/gate1_capability_custom_arm.dhall` adds a `Custom : Text` arm to `Capability`
  (union-arm-addition operator). The gate is invalid if that mutant type-checks the product-named negative or
  passes the arm-inventory oracle.
- **Oracle-pinning (§M.1).** All goldens, the arm-inventory table, and the seeded mutant above are committed
  in Phase 0 before any schema module exists; none is regenerated from the shipped schema's own output.

This gate is Register 1 (pure/golden, in-process, no cluster). It still emits the [§K](development_plan_standards.md#k-honesty-proven--tested--assumed)
proven/tested/assumed ledger (below), marks binding/index (layer-2/3) foreclosures UNVERIFIED here, and
carries the acceptance token *spec-composition proven*, never *runtime proven*.

## Doctrine adopted

- [`dsl_doctrine.md §2 — Dhall carries params, Haskell carries logic`](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
  the hard split between the two languages. This phase authors the **Dhall data** half — typed, total,
  side-effect-free surfaces that carry the desired world's parameters — deliberately holding back the Haskell
  chain/Step logic that acts on them (that decode-and-act half is Phase 5 and later). The Dhall never "runs";
  it is authored, type-checked, and (from Phase 5 on) decoded.
- [`dsl_doctrine.md §5 — the illegal-state-unrepresentable contract`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  specifically **Gate 1 — the Dhall typechecker**, stood up here as the authoring-time boundary of *"if it
  decodes, it is deployable."* A union with no arm for insecure ingress gives no syntax to request it; a
  record that requires a reference gives no way to omit it. Gate 2 (the in-process typed decoder) is the
  companion boundary and is deferred to [Phase 5](phase_05_gadt_decoder_gate2.md).
- [`illegal_state_catalog.md §1/§2/§3/§6`](../documents/illegal_state/illegal_state_catalog.md): the catalog of
  illegal states and the typing techniques that foreclose each, adopted **at the honest foreclosure layer**.
  The layer-1 type-foreclosed entries — closed unions, required fields, no-arm — are discharged at Gate 1
  here; the decode-foreclosed (layer 2) and runtime-checked (layer 3) entries stay deferred to Phase 5 and the
  live band. The catalog's §2 limit is honored verbatim: *a type-check proves the spec composes, not that the
  cluster enforces it.*

## Sprints

## Sprint 4.1: Dhall prelude + typed surfaces + smart constructors 📋

**Status**: Planned
**Implementation**: `dhall/amoebius/{prelude,Cluster,App,Deployment,Capability,Topology,Capacity,Storage,Retention}.dhall`
(typed surfaces + smart constructors) — target paths, not yet built.
**Blocked by**: Phase 3 gate. External prerequisite: the `dhall` CLI only — this sprint needs **no** Haskell
skeleton (that arrives with the Gate-2 decoder in Phase 5).
**Independent Validation**: `dhall type` / `dhall lint` accept every schema module on its own — each surface
type is well-formed and every smart constructor elaborates to a value of its declared type — AND each shipped
union's arm inventory and each surface record's required-field set match their committed Phase-0 oracle tables
(`arm_inventory.csv`, `surface_fields.csv`) byte-exactly, so no freeform escape arm and no missing foreclosing
field passes.
**Docs to update**: `documents/engineering/dsl_doctrine.md` (Gate-1 status backlink),
`DEVELOPMENT_PLAN/system_components.md` (DSL schema inventory).

### Objective
Adopt [`dsl_doctrine.md §2/§5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
stand up the three typed Dhall surfaces (cluster, app-spec, deployment-rules) as *data* carrying parameters
not logic, and expose them only through smart constructors so that Gate 1 — the Dhall typechecker — becomes
an authoring-time boundary that fires before any binary runs.

### Deliverables
- A Dhall prelude and record/union types exposing only *smart constructors* — a vocabulary with no illegal
  words: the 8-arm no-product `Capability` union (catalog §3.12); no-unbounded-arm `StorageBacking` /
  `Growable` (catalog §3.18/§3.21); the odd-quorum `Rke2Servers = ⟨Single|Ha3|Ha5⟩` (catalog §3.24); the
  mandatory size-triggered `RetentionPolicy` (catalog §3.20); and a `Ingress`/route surface with **no**
  insecure/backdoor arm (catalog §3.7) — each encoded as a closed union, a required field, or a no-arm shape.
- An in-file **honesty caveat**: because Dhall has no opaque types, binding- and phantom-index foreclosures
  (catalog §4.1–§4.3) are only *partially* Gate-1-foreclosed by smart-constructor convention and get real
  teeth at the Haskell GADT decoder in [Phase 5](phase_05_gadt_decoder_gate2.md) (Gate 2).
- **Wired surfaces (forecloses detached-ornament stubs).** The three surface records carry the foreclosing
  types as REQUIRED fields, not as standalone unreferenced modules: `App` demands `caps : List Capability`
  and storage via `StorageBacking` + `RetentionPolicy`; `Cluster` demands `Rke2Servers` for an rke2 engine
  and `Ingress` for every route. A committed schema-shape oracle (`tests/oracle/gate1/surface_fields.csv`,
  hand-authored in Phase 0) pins these required field-name→type bindings; Sprint 4.1 validation compares the
  shipped record types against it byte-exactly.

### Validation
1. `dhall type` accepts each schema module. A smart constructor cannot be applied to an out-of-schema argument
   without a type error — discharged by a named committed fixture set `tests/gate1/ctor_reject/*.dhall`
   (≥1 expect-fail application fixture per smart constructor, enumerated in the harness manifest), each of
   which MUST fail `dhall type`; this is not discharged by appeal to Dhall function typing alone.
2. The shipped record types match the committed `surface_fields.csv` oracle byte-exactly (the wiring above),
   red on any missing required foreclosing field.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 4.2: Gate-1 positive corpus 📋

**Status**: Planned
**Implementation**: `dhall/examples/legal_*.dhall` (worked-example cluster / app / deployment specs);
`tools/dhall_gate1.sh` (a `dhall type` corpus harness) — target paths, not yet built.
**Blocked by**: Sprint 4.1.
**Independent Validation**: every positive fixture type-checks under `dhall type` against the Sprint-4.1
schema; the harness exit code is a single green/red over the whole positive set.
**Docs to update**: `DEVELOPMENT_PLAN/system_components.md` (positive corpus inventory),
`documents/engineering/dsl_doctrine.md` (Gate-1 corpus backlink).

### Objective
Adopt [`illegal_state_catalog.md §1`](../documents/illegal_state/illegal_state_catalog.md): assemble the
positive fixtures that a legal amoebius world is authored from and prove they pass the Gate-1 typechecker —
the authoring-time demonstration that the schema *admits* every intended world.

### Deliverables
- Positive fixtures — the explicit representative set `legal_multisubstrate_cluster`, `legal_managed_eks`,
  `trivial_app`, and `legal_deployment_rules` — each a well-typed Dhall value built entirely through the
  Sprint-4.1 smart constructors, and each populating every REQUIRED foreclosing field of its surface record
  (a `Cluster` carrying `Rke2Servers` + `Ingress`; an `App` carrying `List Capability` + `StorageBacking` +
  `RetentionPolicy`). A positive that routes through none of the foreclosing types does not satisfy this set.
- Each of the seven Gate-1 negatives of Sprint 4.3 names one of these positives as its paired sibling (the
  fixture it is a one-construct mutation of); this set is the source of those paired positives.
- A corpus harness that runs `dhall type` over the positive set and reports one aggregate result.

### Validation
1. Every positive fixture type-checks; the harness is red if any positive fixture fails `dhall type`.
2. Each positive fixture's surface record instantiates every required foreclosing field named in
   `surface_fields.csv` (checked by the harness against the committed oracle), so the positives exercise the
   Sprint-4.1 foreclosures rather than a toy `{ name : Text }` skeleton.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 4.3: Gate-1-class negative corpus + partial-foreclosure ledger 📋

**Status**: Planned
**Implementation**: `dhall/examples/illegal_*.dhall` (the Gate-1 subset); `tools/dhall_gate1_negatives.sh`
(an expect-fail `dhall type` harness) — target paths, not yet built.
**Blocked by**: Sprint 4.1, Sprint 4.2.
**Independent Validation**: every one of the seven canonical Gate-1-class negative fixtures **fails** `dhall
type` at authoring time for the pinned reason (its stderr matches the committed `<entry>.err` golden) while
its reverted paired positive type-checks; the committed seeded mutant goes red; and the committed
partial-foreclosure ledger maps each negative to its catalog entry and foreclosure layer (fully vs. residue
owned by Phase 5's Gate 2), with the non-CBOR §3.23 entry recorded as deferred, not counted green.
**Docs to update**: `documents/illegal_state/illegal_state_catalog.md` (per-entry Gate-1 foreclosure-layer
annotation), `DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md` (backlink: the decode-foreclosed residue lands
there).

### Objective
Adopt [`illegal_state_catalog.md §2/§3/§6`](../documents/illegal_state/illegal_state_catalog.md): assemble the
Gate-1-class negative corpus — the fixtures the schema makes unspellable — and prove each fails `dhall type`,
honestly recording which foreclosures are complete at Gate 1 and which are only conventional here and finished
at Gate 2.

### Deliverables
- The seven canonical Gate-1 negatives named in the **Gate** representative set, one committed
  `illegal_*.dhall` each, MUST fail `dhall type`: product-named capability (§3.12), insecure/backdoor ingress
  arm (§3.7), unbounded storage backing (§3.18), un-tiered / no-retention topic (§3.20), capacity-growth-
  without-scaling-policy (§3.21), even/zero-server rke2 control plane (§3.24), and an un-offered
  substrate/topology arm (§3.14/§3.15). Each is a MINIMAL one-construct mutation of its named `legal_*.dhall`
  paired positive, and each embeds its illegal construct inside a full positive-derived cluster/app spec —
  NOT a detached import of an ornamental type — so the illegal state is exercised in a wired surface.
- The non-CBOR payload entry (§3.23) is explicitly NOT authored as a Gate-1 fixture: it is layer-2
  decode-foreclosed, unconstructible at `dhall type`, and appears in the ledger only as a deferred row owned
  by [Phase 5](phase_05_gadt_decoder_gate2.md)'s Gate 2.
- A committed per-negative golden `dhall type` error transcript (`tests/oracle/gate1/<entry>.err`, authored
  in Phase 0) pinning each failure's targeted union/arm/field.
- The committed seeded mutant `mutants/gate1_capability_custom_arm.dhall` (union-arm-addition operator) that
  the harness re-runs and MUST report red.
- The **partial-foreclosure ledger** is the §K proven/tested/assumed artifact this phase emits — a committed
  file at `DEVELOPMENT_PLAN/ledgers/phase_04_gate1.md`, schema per `testing_doctrine.md`. It names Register 1,
  carries the acceptance token *spec-composition proven*, maps each of the seven negatives to its catalog
  entry and foreclosure layer (fully no-arm/required-field vs. conventional binding/index residue), marks
  layer-2/3 residue UNVERIFIED, and routes that residue to [Phase 5](phase_05_gadt_decoder_gate2.md). This
  ledger is the single §K artifact the Definition of Done requires; there is no separate coverage note.

### Validation
1. Every one of the seven canonical Gate-1-class negatives fails `dhall type` at authoring time with no
   binary run; `tools/dhall_gate1_negatives.sh` is red if any tagged negative type-checks.
2. Per negative, the harness asserts the paired positive (the fixture with only the tagged illegal construct
   reverted) type-checks (§M.8/§M.3), AND the observed `dhall type` stderr matches the committed per-entry
   `<entry>.err` golden naming the targeted type/arm/field (§M.8); red if either the paired positive fails or
   the error text diverges from its golden.
3. The harness re-runs the committed seeded mutant `mutants/gate1_capability_custom_arm.dhall` and is red
   unless the mutant is detected (its product-named negative type-checks or the arm-inventory oracle passes)
   (§M.2).
4. The partial-foreclosure ledger at `DEVELOPMENT_PLAN/ledgers/phase_04_gate1.md` maps all seven negatives to
   a catalog entry and a foreclosure layer and is committed; the gate is incomplete without it.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/dsl_doctrine.md` — backlink §5's Gate 1 to this in-process Phase-4 proof; keep Gate 2
  (the typed decoder) as the companion boundary owned by Phase 5, and runtime enforcement as the deferred
  live-band residue.
- `documents/illegal_state/illegal_state_catalog.md` — annotate each entry exercised here with its realized
  Gate-1 foreclosure layer (type-foreclosed → layer 1); keep decode-foreclosed (layer 2) and runtime-checked
  (layer 3) entries deferred.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase 4 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-4 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `dhall/amoebius/` and `dhall/examples/` as Phase-4
  design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL vision
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §2 the two languages, §5 the two typed gates and
  the illegal-state contract
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — the catalog, the typing
  techniques, and the honest foreclosure-layer split
- [phase_05](phase_05_gadt_decoder_gate2.md) — Gate 2, the GADT-indexed IR and total decoder, the companion boundary
