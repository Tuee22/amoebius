# Phase 46: Generated browser contracts and bundle

> **Purpose**: PureScript contracts, codecs and the one generic bundle become recipes rather than authored source.
> **Read this if**: a browser contract, codec, or bundle is being changed, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make the browser contract surface a recipe rather than authored source.
Its first deliverable is contracts and codecs rendered from the checked public boundary, and this phase sits where the vocabulary it consumes first exists.
The rule behind generated browser contracts and bundle is owned by [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 46.1: Generated browser contracts and bundle ✅](#sprint-461-generated-browser-contracts-and-bundle-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-22. The fourteen-sided Register-1 gate passes on natural `arm64`, untranslated.
Sixteen independently projected public contracts render three PureScript recipes twice with byte-identical
paths and contents. The strict `ui-client-v1` bundle is content-addressed as
`sha256:a7473c3334c797dfa016f404e301da539e42686bc7447146e3da3b81c79ef5b7`; six independent scanner rules are
clean, all three production mutants red at their exact scanner loci, all 11 metrics match, and 47 surfaces
join to 54 enumerated items. Attestation
`sha256:f69a69ebedb305830b6a3d7df83d52fadd87814f7d5a61c7d60b11bd296adb86` binds source
`sha256:59c38520465d4ce0…` over 2,285 files. Protocol and runtime behavior remain UNVERIFIED.

## Phase Summary

The browser contract surface is now a recipe rather than authored source. A dedicated Haskell library
enumerates the closed public `ValueType` boundary, excludes the private `ServerHandle`, and emits public
contract types, total field codecs, and the generic ABI entry point only into a caller-supplied build root.
The gate independently parses the actual `ValueType`, `ClientPlan` encoder, and PureScript `Transition` type
before comparing the result with the authored sixteen-row contract inventory.

Two clean renders and a denied-network render agree. The first clean render is injected into a contained copy
of the one Spago workspace, where strict compilation produces one bundle containing the generated
`ui-client-v1` ABI marker. Its digest is observed at run time rather than committed as an expectation. The
independent scanner rejects raw browser sinks, private server fields, and provider coordinates in generated
source and the built bundle.

**Phase scope:** one cohesive claim — *the browser surface is rendered from the UI types rather than authored beside them*. What stays authored is the oracle each rendered contract is checked against.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 40](phase_40_ui_plan_compiler.md) — the UI plan compiler, whose emitted plan is the
declaration these contracts are rendered from; and [Phase 45](phase_45_encrypted_browser_runtime.md) — the
sealed generic bundle and offline consumer this migration must preserve. Phase 45 is the consumer and numeric
handoff rather than the semantic source of the generated contracts.
**Gate:** `python3 tools/run_phase_gate.py 46` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A hand-authored contract inventory derived from the Haskell boundary types, written apart from the renderer.
- **Committed mutants.** Mutants add a raw sink to the catalog, serialize a server handle, and emit a codec the boundary does not declare.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in an artifact scanner independent of the generator.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a hand-authored contract inventory derived from the Haskell boundary types, written apart from the renderer.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md) — the rule behind generated browser contracts and bundle.

## Sprints

## Sprint 46.1: Generated browser contracts and bundle ✅

**Status**: Done
**Implementation**: `src/ui-contract-generation/Amoebius/Ui/Generate/BrowserContracts.hs`,
`test/spec/ui/UiContractGenerationSpec.hs`, `test/oracle/ui_contract_generation/**`,
`test/mutant/ui_contract_generation/**`, `tools/ui_contract_generation_gate.py`
**Blocked by**: [Phase 45](phase_45_encrypted_browser_runtime.md) gate
**Independent Validation**: A hand-authored contract inventory derived from the Haskell boundary types, written apart from the renderer.
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`

### Objective

Make the browser contract surface a recipe rather than authored source.

### Deliverables

- Contracts and codecs rendered from the checked public boundary.
- One generic bundle per runtime ABI, addressed by content.
- A build that writes only beneath the ignored build tree.
- An artifact scanner independent of the generator.

### Validation

Two renders must agree byte for byte, and the scanner must find no executable inline content or provider coordinate.

### Remaining Work

None. Protocol use and live runtime behavior belong to their later Register-2/3 phases and remain UNVERIFIED.

## Documentation Requirements

**Engineering docs updated with this seal:**

- [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md)

## Related Documents
- [Development Plan](README.md)
- [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md) — the rule behind generated browser contracts and bundle.
