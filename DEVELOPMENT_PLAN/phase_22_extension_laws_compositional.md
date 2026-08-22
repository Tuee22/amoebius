# Phase 22: The compositional laws C1-C7

> **Purpose**: Mechanically evaluate C1–C7 over scope-preserving composites of complete extension
> declarations, with bounded counterexample evidence.
> **Read this if**: the composite declaration value, its seven law predicates, or their finite evidence boundary
> must change.

This phase owns a composite value distinct from Phase 20's exactly-five-component declaration and a bounded
Register-1 evaluator for C1–C7. It samples closure; it does not prove universal C1, generate an arbitrary
extension's gate, seal conformance, or certify runtime behavior. The normative laws remain owned by
[`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, documents/engineering/extension_conformance_laws.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 22.1: The compositional laws C1-C7 ✅](#sprint-221-the-compositional-laws-c1-c7-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All thirteen gate sides passed on natural `arm64`, untranslated: thirteen exact
metrics matched and 26 surfaces joined to 28 run-time items. Attestation
`sha256:493b4b435a75e526c73d21e5c9500d29b00f837dad867911284ea940752c1ac7` binds source
`sha256:36c615a921ed637b…` over 2,235 files. Repository-conformance attestation
`sha256:7d871c2f645375aa19d0b434a16b8da58438f53941ec4ecb21e2aa72fe203200` and documentation attestation
`sha256:1ac8bac150916e6f2226ee55a976ca0254c117062ab8a123c109fd4147eb3716` passed on that snapshot. Universal
C1, arbitrary link sets, scanner completeness, SHA-256 collision absence, runtime correspondence, and a
conformance verdict remain UNVERIFIED.

## Phase Summary

`lib:extension-laws-compositional` stores a normalized multiset of complete `ExtensionDeclaration scope`
values. Its private constructor preserves Phase 20's introduction rule, and the shared phantom index prevents
declarations minted by different requests from composing. The empty composite is an identity; composition
sorts concatenated declaration keys, making grouping equal by value. Vocabulary is the Phase-21 set union and
resources are the exact natural-number fold of the member declarations.

The evaluator consumes explicit composite, isolated-part, algebra, resource, flow, and content-address
observations. C1 reruns L1–L5 over each operand and the union vocabulary; C2 and C3 compare observed operator
results by composite value; C4 compares each part's operation/artifact/budget/flow projection with its isolated
run; C5 checks the exact resource sum; C6 rejects a wider sink; and C7 requires exact SHA-256 derivation while
allowing byte-identical outputs to share an address. Collision resistance is ASSUMED.

The bounded corpus contains seven ordered identity/link cases over `none`, `infernix`, and `jitml`, yielding 49
green pair-law cells. A separate 9-by-7 verdict grid has two lawful controls—distinct content and shared
content—and seven seeded defects. The cross-scope defect correctly reddens C1, C4, and C6 because scope
widening both breaks closure and changes one part's projected behavior. This is a finite counterexample search,
not the universal closure proof the doctrine still says is owed.

**Phase scope:** seven composition cases, 49 green pair-law verdicts, 63 authored subject verdicts, fourteen
identity and seven association equalities, seven exact resource folds, four independently recomputed content
addresses, one request-scope compiler barrier, one finite shared-authority scan, and seven executable mutants.
Universal C1, arbitrary link sets, SHA-256 collision absence, runtime correspondence, gate generation, and a
conformance verdict remain outside the claim.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 21](phase_21_extension_laws_per_extension.md) — L1–L5, whose conjunction over a composite is exactly what C1 asserts.
**Gate:** `python3 tools/run_phase_gate.py 22` rebuilds both suites and requires thirteen
metrics, independently checked pair and verdict tables, Python SHA-256 recomputation, the cross-request type
barrier, seven exact mutants, a 26-surface join, architecture, containment, write guard, ledger, and source-
bound attestation; [Gate integrity](#gate-integrity) owns the anti-tautology apparatus.

## Gate integrity

- **Representative set (§M.7):** seven authored cases exercise empty/left/right identity and both orders of the
  two-declaration link. The separate controls cover different bytes/different addresses and identical
  bytes/shared address.
- **Independent oracle (§M.1/§M.3):** `composition_cases.tsv` states normalized part names and four-coordinate
  resource totals. Python re-adds each operand independently. `composition_law_verdicts.tsv` states all 63
  verdicts, and Python recomputes four observed SHA-256 addresses from emitted content.
- **Mutation quota (§M.2):** omitted claim, broken left identity, regrouped association, process-global shared
  state, non-additive budget, widened cross edge, and forced address collision redden their exact declared law
  sets. C4's control uses a real global `IORef` introduced through `unsafePerformIO` only in mutant source.
- **Specific-reason negatives (§M.8):** the same-request composite runs; its adjacent cross-request sibling
  fails at GHC-25897 and the `CompositeDeclaration` index. Different bytes forced to one address fail first as
  `AddressCollision`, while the byte-identical shared-address control remains green.
- **Finite coverage honesty (§M.4):** the link set has two declarations, association uses seven triples, and
  the shared-authority scanner recognizes a finite token list. No universal closure or scanner completeness is
  inferred; SHA-256 collision resistance is ASSUMED.
- **External observation (§M.5/§M.10):** authored TSVs, a separately implemented Python address/resource
  oracle, GHC diagnostics, and executable mutant modes observe the library. The production module cannot write
  its own verdict.
- **Authority/bypass (§§M.11–M.12):** the composite constructor is private and accepts only complete,
  same-request declarations. Observation bundles are evidence inputs, not authority to generate or seal a
  Phase-24 conformance verdict.
- **Fresh challenge (§M.9):** not applicable. This gate is pure; independently authored pair/verdict tables,
  the compiler twin, address recomputation, and mutation controls provide its challenge apparatus.
- **Extension conformance (§M.13).** Not applicable. This phase samples C1–C7 over the bounded corpus; it does
  not produce the generated L/C/S/P gate or its sealed verdict.

## Doctrine adopted

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the rule behind the compositional laws C1-C7.

## Sprints

## Sprint 22.1: The compositional laws C1-C7 ✅

**Status**: Done.
**Implementation**: `src/extension-laws-compositional/Amoebius/Extension/Laws/Compositional.hs`,
`test/{harness,mutant}/extension_laws/*.hs`,
`test/negative/compile_fail/extension_laws_compositional/CompositionScopeCompile.hs`,
`test/spec/extension/ExtensionLawsCompositionalSpec.hs`, `test/oracle/extension_laws/composition_*.tsv`,
`test/oracle/extension_laws_compositional_surfaces.tsv`, and `tools/extension_laws_compositional_gate.py`.
**Blocked by**: None.
**Independent Validation**: authored pair and 63-cell verdict tables, Python resource/address recomputation,
same/cross-request compiler twins, shared-authority scan, shared-content control, and seven exact mutants.
**Docs to update**: `documents/engineering/extension_conformance_laws.md` and
`DEVELOPMENT_PLAN/{README,overview,system_components}.md`.

### Objective

Evaluate all seven compositional laws over a scope-preserving composite value and retain the universal C1 gap
honestly.

### Deliverables

- Private normalized composite over complete same-request declarations, with empty identity.
- C1–C7 evaluator joining union and isolated-part observations to declaration identities.
- Exact resource addition, scope-conjunction checks, and content-derived SHA-256 address comparison.
- Seven composition cases, two lawful address controls, one compiler barrier, and seven exact mutants.

### Validation

1. Require all seven authored composition cases and their 49 C-law cells to pass.
2. Match all 63 cells in the independent two-control/seven-defect verdict table.
3. Compare fourteen identity and seven association results by value and all seven resource sums exactly.
4. Independently recompute four emitted content addresses and admit the identical-content shared-address case.
5. Require the same-request twin to run, the cross-request twin to fail at its exact type reason, and every
   registered mutant to redden only its declared C-law set.

### Remaining Work

None.

## Documentation Requirements

**Engineering docs to update after the capability gate passes:**

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — record the
  bounded C1–C7 evaluator without upgrading sampled closure, finite scanning, collision resistance, generated
  conformance, or runtime fidelity.

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the rule behind the compositional laws C1-C7.
