# Phase 46: Haskell-generated browser contracts and bundle

> **Purpose**: PureScript contracts, codecs and the one generic bundle become recipes rather than authored source.
> **Read this if**: a browser contract, codec, or bundle is being changed, or this gate has to be read precisely.

This plan owns the hardware-free Haskell browser-contract and bundle-recipe generation gate.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 46.1: Generated browser contracts and bundle](#sprint-461-generated-browser-contracts-and-bundle-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

✅ Done.

The [2026-09-08 reset](README.md#reopened-numeric-sequence) withdraws prior certification. Existing
implementation is an Observed footprint / Known partial. Retained requirements remain obligations; only this
phase's complete qualified gate under the replacement acceptance baseline can authorize Done.

Gate execution remains blocked by the qualified Phase-45 predecessor and its compatible evidence chain.

## Phase Summary

The audit found that deterministic source generation and forbidden-token scanning did not establish a working bundle. This phase must compile and execute the generated software with authenticated offline toolchains and isolated fake facilities before the DSL barrier. Such execution needs no specialized substrate and cannot be deferred as browser or hardware fidelity.

**Target capability — NOT VALIDATED.** A dedicated Haskell library is to be the sole tracked source for the
closed public `ValueType` boundary, public contract types, total field codecs, generic ABI entry point, package
description, build description, and browser bundle source. It must lazily emit every PureScript, JavaScript,
JSON, YAML, and other browser-build byte beneath `.build/ui/**`; private `ServerHandle` values and provider
coordinates must have no public projection. Separately authored Haskell semantic rows must constrain the
public boundary without parsing or trusting generated output as their authority. Compilation and bundle
inspection remain unresolved target observations; no successful render, compile, or scan is asserted here.

**Phase scope:** one target claim — Haskell generates the complete generic browser bundle, which compiles
offline and executes against isolated fake software facilities with independently expected semantics.
Actual browser and live network/storage fidelity remain later-owned.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2 — generated software execution against externally observed fake facilities
**Depends on:** [Phase 45](phase_45_encrypted_browser_runtime.md)
**Gate:** `pb validate phase 46`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — the replacement certification generation, protected accepted baseline,
authenticated phase receipt, and current compatibility closure are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

| Key | Contract |
|---|---|
| `Claim` | Haskell generates a complete generic browser contract/runtime bundle that compiles offline and executes actual compiled ClientPlans and offline operations under isolated fake software facilities with results matching independent semantics. |
| `Subject` | `Amoebius.Ui.Generate.BrowserContracts`, the Phase-42 generic projection, Phase-45 offline projection, actual compiler-produced plans and the acquired Phase-46 serial build/execution supervisor. |
| `Command` | `pb validate phase 46` (future public spelling); before Phase 50, invoke the exact source-bound Haskell executable directly and let its acquired supervisor run the offline serial matrix. |
| `Oracle` | `test/spec/ui/UiContractGenerationReference.hs` independently specifies codec/ABI meaning, full plan outputs and fake-facility requests/results, using Haskell-authored inputs and expectations rather than production source substrings. |
| `Positive controls` | Generate and compile the complete bundle with authenticated offline toolchain input, load its actual exports, decode/interpret distinct compiled plans and execute codec/offline operations under deterministic local fake facilities. |
| `Paired negatives` | Pair legal artifacts with missing implementations/exports, malformed generated code, ABI/codec drift, constant output, wrong plan interpretation, forbidden facility access and altered ciphertext/fence requests; require exact compile or semantic failures. |
| `Mutants` | Mutate actual Haskell generators to emit no-op or incorrect bodies, wrong imports/exports/codecs, stale plan values or forbidden calls. Each resulting built artifact must fail its assigned independent compile/execution case. |
| `Discovery` | Reconcile all public contracts, generated modules/exports/codecs, browser/offline operations, actual plan instructions, toolchain inputs and independent case/selector/build assignments in both directions. |
| `Challenge` | `post-acquisition-ui-contract-generation-challenge` |
| `Observer` | The Haskell supervisor records actual compiler/linker/runtime executable identities, exact argv/environment/inputs, exits and emitted semantic observations, including all fake-facility requests and cleanup. |
| `Authority/bypass` | Direct source-bound Haskell supervision only before bootstrap handoff. Authenticated offline compilers and an isolated software runtime may execute generated products; no browser engine, network, container, cluster, provider or hardware discovery is admitted. All compiler/linker work is fixed serial. |
| `Freshness` | `fresh-ui-contract-generation-build-root-and-stable-source` |
| `Qualification` | Complete generated compilation, actual artifact loading/execution, full independent semantic agreement, negative compile/runtime cases and every assigned changed-generator subject must pass together. Determinism and token scanning alone cannot qualify the bundle. |
| `Cleanroom` | All generated browser-language source, package inputs, build products, fake-facility adapters and execution records remain beneath a fresh ignored `.build/**` root; Haskell is their sole tracked behavioral source. |
| `Legacy closure` | `retired-ui-contract-generation-authorities-absent` |
| `Predecessor` | Authenticated `ImmediatePredecessorPass` for Phase 45 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | Actual DOM/browser accessibility, browser cryptography/storage/network behavior, deployment, protocol publication and live release/HA remain later-owned. Generated source compilation and isolated software semantics are required here, not deferred. |
| `Pass criterion` | `qualified-gate-pass` |

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §13 — Generic PureScript client and amoebius UI server](../documents/engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server) — the rule behind generated browser contracts and bundle.

## Sprints

## Sprint 46.1: Generated browser contracts and bundle ✅

**Status**: Done
**Implementation**: `src/ui-contract-generation/Amoebius/Ui/Generate/BrowserContracts.hs`, typed cases, CPP seams, and package-hidden acquired Phase-46 supervisor.
**Blocked by**: [Phase 45](phase_45_encrypted_browser_runtime.md) gate pass
**Independent Validation**: Compile and execute actual generated exports with real compiled plans against independent Haskell expectations; missing bodies, ABI drift and altered semantic requests fail precisely; assigned generator mutants fail their exact artifact cases; live browser behavior remains unverified.
**Oracle**: `test/spec/ui/UiContractGenerationReference.hs`, importing no production or case module.
**Legacy IDs**: exact 15-path root-package/Python/PureScript/JavaScript/serialized/materialized-mutant inventory in `UiContractGenerationRun.Internal`.
**Docs to update**: this plan, tracker/component/substrate maps, low-code UI and generated-artifact doctrines.

### Objective

Make the browser contract surface a recipe rather than authored source.

### Deliverables

- An acquired Haskell supervisor generates, compiles, links/loads and executes the complete generic bundle offline, using authenticated exact compiler/runtime/package inputs and fixed serial compiler/linker execution.
- Haskell-authored fake DOM/storage/crypto/worker/lock/channel/transport boundaries expose deterministic operations and capture actual requests. They execute only in the isolated software runtime and make no browser, network or live-provider claim.
- End-to-end software cases consume actual Phase-40/41 compiled plans and the Phase-42/45 generated interpreter implementations, comparing full visible/accessibility/request/offline outputs with independently authored expectations.

- Contracts and codecs rendered from the checked public boundary.
- One generic bundle per runtime ABI, addressed by content.
- A build that writes only beneath the ignored build tree.
- An artifact scanner independent of the generator.

### Validation

- Reject generated PureScript/JavaScript that merely declares hooks or returns constant outputs, even when token scans and repeated render hashes pass. Require actual exported functions to execute the varied plan/operation inputs.
- Change a view binding, event argument, route, port request, envelope or fence value while preserving all artifact/fixture counts; the compiled generated runtime must produce the corresponding independently expected change.
- Run malformed-code, missing-export, wrong-ABI, no-op, wrong-body and forbidden-facility mutants through the actual generated build and exact assigned execution case; record real compile/runtime failures rather than selector labels.

Two renders must agree byte for byte, and the scanner must find no executable inline content or provider coordinate.
These are additional hygiene controls; the compiled artifact execution and semantic obligations above must
also pass.

### Remaining Work

Run the complete integrated gate and apply only its emitted status projection after a qualified pass. Protocol
use and live runtime behavior belong to later Register-2/3 phases and remain unverified.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md)

**Cross-references to add:**

- The tracker, substrate map, component inventory, low-code UI doctrine, and generated-artifact doctrine.

## Related Documents

- [Development Plan](README.md)
- [`low_code_ui_runtime_doctrine.md`](../documents/engineering/low_code_ui_runtime_doctrine.md) — the rule behind generated browser contracts and bundle.
