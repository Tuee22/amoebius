# Phase 20: The extension declaration

> **Purpose**: Specify the target Haskell capability to represent an extension as one complete
> Haskell value with every core-calculus component, one request-scope index, exact resource
> accounting, and a content-derived identity.
> **Read this if**: the extension value, its five readers, its canonical identity, or the boundary between a
> declaration and later conformance-law machinery must change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 20.1: Complete indexed declaration](#sprint-201-complete-indexed-declaration-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 19 and every earlier gate have current passing receipts. The Phase-20 implementation and compiled
semantic contract are bound below; completion still requires the exact integrated Phase-20 gate.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase has a bound Haskell implementation but does not report a passing result until its complete gate
runs. It represents an extension as one complete Haskell value with every
core-calculus component, one request-scope index, exact resource accounting, and a content-derived
identity.

The production subject, behavioral controls, independent oracle, compile witnesses, and mutants are authored
as `.hs`. The former Python gate, serialized declaration/mutation tables, and test-local mutant are retired.
Derived result tables and compiler transcripts are created lazily beneath the acquired
`.build/runs/phase-20/**` root and remain run-scoped evidence only.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — represent an extension as one complete Haskell value with
every core-calculus component, one request-scope index, exact resource accounting, and a
content-derived identity. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 19](phase_19_reconcile_core_simulation.md)
**Gate:** `pb validate phase 20`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | One complete opaque declaration carries five mandatory calculus components at one generative request scope, preserves component resources, exposes five derived readers, and has a canonical content-derived identity. Later law and runtime claims are excluded. |
| `Subject` | `src/extension-declaration/Amoebius/Extension/Declaration.hs`, acquired and exercised by the package-hidden Phase-20 supervisor. |
| `Command` | `pb validate phase 20` is the future public spelling. This pre-handoff gate invokes the exact absolute source-bound Haskell executable as `validate phase 20`, then exact Cabal 3.16.1.0 and GHC 9.12.4 paths offline with `--jobs=1`; `pb` is not used. |
| `Oracle` | `test/spec/extension/ExtensionDeclarationOracle.hs` independently owns two declarations, ten semantic component rows, exact resource vectors, and a separate length-framed SHA-256 calculation without importing the production declaration or composition module. |
| `Positive controls` | Two declarations contain all ten mandatory components in closed calculus order; five readers each return one component; two natural-resource folds and two independently recomputed digests match; the legal five-component same-scope compile twin runs. |
| `Paired negatives` | Correct/wrong calculus, nonempty/empty name, five/four components, and same/cross request scope are minimally different pairs; the latter two clean-production siblings must fail at exact arity and `RequestScope` type loci. |
| `Mutants` | Three Cabal flags change the production declaration: optional evidence, erased request-scope equality, and omitted artifact reader. Their forbidden witnesses or red tests must identify `RequiredComponents`, `ScopeIndexPreserved`, and `ArtifactReaderComplete`. |
| `Discovery` | The acquired source snapshot must equal the exact one production and three oracle/test `.hs` paths in both directions; empty, missing, or extra discovery fails. |
| `Challenge` | All three production mutations are compiled and evaluated after source acquisition before the clean candidate; each exact property changes while the legal controls remain green. |
| `Observer` | The supervisor retains absolute executable, argv, exit, stdout/stderr, and digest observations for Cabal version, three production mutants, two illegal siblings, the legal twin, and the clean run. |
| `Authority/bypass` | Authority is limited to exact Cabal/compiler/store paths and the unique run root; every build is offline and serial. `pb`, network, host, container, cluster, service, and hardware arguments are forbidden. |
| `Freshness` | One unique `.build/runs/phase-20/work/candidate-*` root is acquired; both clean products are regenerated there and opening/closing Git source identities must match. |
| `Qualification` | The supervisor first kills all three changed-production mutations and checks both illegal compile siblings, then requires the legal twin and clean independent corpus to pass. |
| `Cleanroom` | The authenticated source-repository cache is copied beneath the unique run root, Cabal builds there, and the two clean generated products must exist only below that root. |
| `Legacy closure` | The Python declaration gate, two serialized declaration authorities, and test-local reader mutant are absent; reintroduction is an exact failure. |
| `Predecessor` | Exact durable `ImmediatePredecessorPass` for Phase 19 on the current source snapshot; absent, stale, replayed, or different-source evidence fails. |
| `Residue` | Extension laws, conformance verdicts, decoding, effects, runtimes, host, service, cluster, and hardware claims remain `UNVERIFIED` and later-phase-owned. |
| `Pass criterion` | Every one of the eighteen rows passes in one qualified run for the exact source; that complete pass is sufficient for the mechanical status-only transition. |

## Doctrine adopted

- [`extension_conformance_doctrine.md` §2 — What an extension is](../documents/engineering/extension_conformance_doctrine.md#2-what-an-extension-is): the target extension boundary is an inspectable Haskell value.
- [`extension_conformance_doctrine.md` §3 — The obligation surface: one component per calculus](../documents/engineering/extension_conformance_doctrine.md#3-the-obligation-surface-one-component-per-calculus): the target value must have one mandatory component per calculus.
- [`extension_conformance_doctrine.md` §6 — The verdict seal](../documents/engineering/extension_conformance_doctrine.md#6-the-verdict-seal): the target declaration identity is content-derived; verdict construction remains later work.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 20.1: Complete indexed declaration ✅

**Status**: Done
**Implementation**: `src/extension-declaration/Amoebius/Extension/Declaration.hs`; package-hidden `Amoebius.Validation.ExtensionDeclarationRun.Internal`.
**Blocked by**: [Phase 19](phase_19_reconcile_core_simulation.md) gate pass
**Independent Validation**: Two declaration/ten reader rows, two independent digests, two exact resource folds, two semantic refusal pairs, two compile barriers, and three production mutants.
**Oracle**: `test/spec/extension/ExtensionDeclarationOracle.hs`; compile siblings in `test/negative/compile_fail/extension_declaration/DeclarationCompile.hs`.
**Legacy IDs**: Phase-local legacy closure for the retired Python gate, two TSV authorities, and test-local mutant.
**Docs to update**: `extension_conformance_doctrine.md`; `system_components.md`.

### Objective

Make an extension a complete value whose five calculus obligations and two indices are inspectable before any
effect runs.

### Deliverables

- Opaque five-component declaration with exact calculus-slot validation.
- Same-request scope index, preserved component resources, and exact aggregate resource fold.
- Canonical, length-framed declaration identity independent of diagnostic rendering.
- Five derived readers, two fixture declarations, two compile barriers, and three exact mutants.

### Validation

1. Match all ten actual reader rows to the authored inventory.
2. Independently recompute both declaration digests from canonical semantic fields.
3. Require the legal compile twin to run and both illegal siblings to fail for their pinned type reasons.
4. Require every registered mutation to redden only its declared property.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — after
  promotion, distinguish the accepted declaration boundary from unimplemented law, gate-generation, verdict,
  and runtime claims.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/system_components.md` and `documents/engineering/extension_conformance_doctrine.md` — record the exact declaration boundary, oracle, and package-hidden Phase-20 supervisor.

## Related Documents

- [Development Plan](README.md)
- [Phase 10](phase_10_calculus_composition.md) — the component and index algebra this phase stores.
- [Phase 21](phase_21_extension_laws_per_extension.md) — the first laws instantiated over this value.
- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the
  normative extension contract and honesty boundary.
