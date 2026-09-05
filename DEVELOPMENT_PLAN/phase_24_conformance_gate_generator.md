# Phase 24: The generated conformance gate

> **Purpose**: Specify the target Haskell capability to derive conformance suite manifests and
> coverage grids lazily beneath `.build/**` from Haskell extension declarations, then bind
> observations to a Haskell link-set verdict.
> **Read this if**: declaration-derived gate cases, suite content addressing, verdict verification, or the
> transaction-family deferral must change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 24.1: The generated conformance gate](#sprint-241-the-generated-conformance-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 23, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to derive conformance suite manifests and coverage grids lazily beneath
`.build/**` from Haskell extension declarations, then bind observations to a Haskell link-set
verdict.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — derive conformance suite manifests and coverage grids
lazily beneath `.build/**` from Haskell extension declarations, then bind observations to a Haskell
link-set verdict. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 23](phase_23_extension_security_laws.md)
**Gate:** `pb validate phase 24`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | The pure Haskell kernel derives a closed gate plan and ten run-scoped products from an extension declaration, seals the declaration/core/suite/result tuple in an opaque verdict, and admits only a same-request verified link set. |
| `Subject` | `src/extension-conformance-gate/Amoebius/Extension/Conformance/Gate.hs`, acquired and exercised by the package-hidden Phase-24 supervisor. |
| `Command` | `pb validate phase 24` is the future public spelling. This pre-handoff gate invokes the exact absolute source-bound Haskell executable as `validate phase 24`, then exact Cabal 3.16.1.0 and GHC 9.12.4 paths offline with `--jobs=1`; `pb` is not used. |
| `Oracle` | `test/spec/extension/ExtensionConformanceGateOracle.hs` independently owns nineteen suite tuples, 24 coverage cells, and five verdict outcomes without importing production gate, plan, verdict, or admission types. |
| `Positive controls` | Nineteen exact suite cases, 24 coverage cells, five suite manifests, one coverage grid, three result projections, one verdict projection, and exactly one sealed same-request admission pass. |
| `Paired negatives` | Modified suite bytes, a failed case, a wrong declaration, and a changed core are refused; one legal compiler control runs while forged verdict, omitted verdict, and cross-scope verdict siblings fail at exact type boundaries. |
| `Mutants` | Three Cabal flags change production code by omitting L5, accepting a mismatched suite digest, or bypassing verdict verification. Each changed subject must turn red at its declared locus while the independent oracle remains unchanged. |
| `Discovery` | The acquired source snapshot must equal the production gate, spec, independent oracle, shared law fixture, and compiler sibling in both directions; empty, missing, or extra discovery fails. |
| `Challenge` | All three production mutations are compiled and evaluated after source acquisition before the clean candidate; each exact generator, digest, or admission observation changes. |
| `Observer` | The supervisor retains absolute executable, argv, exit, stdout/stderr, and digest observations for Cabal version, three production mutants, one legal and three illegal compiler siblings, and the clean run. |
| `Authority/bypass` | Authority is limited to exact Cabal/compiler/store paths and the unique run root; every build is offline and serial. `pb`, network, host, container, cluster, service, and hardware arguments are forbidden. |
| `Freshness` | One unique `.build/runs/phase-24/work/candidate-*` root is acquired; all ten clean products are regenerated there and opening/closing Git source identities must match. |
| `Qualification` | The supervisor first kills all three changed-production mutations and verifies all four compiler controls, then requires the clean independent corpus to pass. |
| `Cleanroom` | The authenticated source-repository cache is copied beneath the unique run root, Cabal builds there, and all ten generated products must exist only below that root. |
| `Legacy closure` | The Python gate, four serialized conformance authorities, serialized surface inventory, and test-local mutant module are absent; reintroduction is an exact failure. |
| `Predecessor` | Exact durable `ImmediatePredecessorPass` for Phase 23, projected monotonically onto this candidate's opening source; absent, malformed, wrong-phase, or non-green evidence fails. |
| `Residue` | Transaction instances, observer authenticity, executable semantic harness generation, C1 proof, universal closure, collision absence, decoding, effects, runtimes, host, service, cluster, and hardware claims remain `UNVERIFIED` and later-phase-owned. |
| `Pass criterion` | Every one of the eighteen rows passes in one qualified run for the exact source; that complete pass is sufficient for the mechanical status-only transition. |

## Doctrine adopted

- [`extension_conformance_doctrine.md` §5 — The conformance gate is generated, not authored](../documents/engineering/extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored) — the rule behind the generated conformance gate.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 24.1: The generated conformance gate ✅

**Status**: Done
**Implementation**: `src/extension-conformance-gate/Amoebius/Extension/Conformance/Gate.hs`; package-hidden `Amoebius.Validation.ConformanceGateRun.Internal`.
**Blocked by**: [Phase 23](phase_23_extension_security_laws.md) gate pass
**Independent Validation**: Nineteen suite controls, 24 coverage cells, five verdict cases, ten generated products, four compiler controls, and three changed-production mutants.
**Oracle**: `test/spec/extension/ExtensionConformanceGateOracle.hs`; shared declaration fixture in `test/harness/extension_laws/LawFixtures.hs` and the compiler sibling.
**Legacy IDs**: Phase-local legacy closure for the retired Python gate, five serialized behavioral authorities, and test-local mutant module.
**Docs to update**: `extension_conformance_doctrine.md`; `system_components.md`.

### Objective

Derive the finite gate plan from the declaration, bind its exact bytes into a passing verdict, and retain the
pre-transaction applicability boundary honestly.

### Deliverables

- Five deterministic suite manifests and a coverage grid derived from declaration vocabulary, peers, and the
  current L/C/S law enumerations.
- Explicit P1–P6 not-applicable coverage until the transaction vocabulary can declare an axis.
- Opaque passing verdict sealing declaration digest, core version, generated-suite digest, and result.
- Same-request link-set admission with no constructor or API arm that omits the verdict.

### Validation

1. Match all nineteen suite rows and all 24 coverage cells to independent authored inventories.
2. Independently decode every emitted axis and recompute every case, suite, and verdict digest.
3. Require modified suite bytes and a failed case to refuse sealing, a wrong declaration/changed core to
   refuse verification, and the canonical all-pass run to admit exactly one member.
4. Require direct verdict construction, verdict omission, and cross-request verdict use to fail at their
   pinned compiler reasons.
5. Require every registered mutant to redden exactly its named generator, digest, or admission property.

### Remaining Work

Transaction instances, observer authenticity, executable semantic harness generation, C1 proof, universal
closure, collision absence, decoding, effects, runtime correspondence, and all host/hardware layers remain later
work rather than Phase-24 completion criteria.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — record
  the bounded generator/verdict boundary without upgrading transaction applicability, observer authenticity,
  semantic execution, closure, or runtime fidelity.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/system_components.md` and `documents/engineering/extension_conformance_doctrine.md` — record the bounded generator/verdict kernel, independent oracle, finite residue, and package-hidden Phase-24 supervisor.

## Related Documents

- [Development Plan](README.md)
- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the rule behind the generated conformance gate.
