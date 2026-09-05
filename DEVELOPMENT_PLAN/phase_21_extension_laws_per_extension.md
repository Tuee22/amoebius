# Phase 21: The per-extension laws L1-L5

> **Purpose**: Specify the target Haskell capability to evaluate L1–L5 over bounded Haskell
> extension declarations using independently authored `.hs` controls, oracles, paired negatives, and
> mutants.
> **Read this if**: the per-extension law evaluator, its finite evidence boundary, or any L1–L5 gate claim must
> change.

This document specifies the bound Phase-21 capability. A pass, seal, receipt, or status transition exists only
after the exact integrated gate succeeds for the current source. Current status is owned by
[the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 21.1: The per-extension laws L1-L5](#sprint-211-the-per-extension-laws-l1-l5-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 20 and every earlier gate have current passing receipts. The Phase-21 implementation and compiled
semantic contract are bound below; completion still requires the exact integrated Phase-21 gate.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase has a bound Haskell implementation but does not report a passing result until its complete gate
runs. It evaluates L1–L5 over bounded Haskell extension declarations using independently authored `.hs`
controls, oracles, paired negatives, and changed-production mutants.

The production subject, behavioral controls, independent oracle, fixtures, and mutants are authored as `.hs`.
The former Python gate, serialized law/case/mutation authorities, and test-local mutant module are retired.
Derived result tables and compiler transcripts are created lazily beneath the acquired
`.build/runs/phase-21/**` root and remain run-scoped evidence only.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — evaluate L1–L5 over bounded Haskell extension declarations
using independently authored `.hs` controls, oracles, paired negatives, and mutants. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 20](phase_20_extension_declaration.md)
**Gate:** `pb validate phase 21`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | One pure evaluator returns separate typed L1 totality, L2 determinism, L3 budget-honesty, L4 scope-propagation, and L5 evidence verdicts over observations joined to a complete Phase-20 declaration. Later composition, security, conformance, and runtime claims are excluded. |
| `Subject` | `src/extension-laws/Amoebius/Extension/Laws/PerExtension.hs`, acquired and exercised by the package-hidden Phase-21 supervisor. |
| `Command` | `pb validate phase 21` is the future public spelling. This pre-handoff gate invokes the exact absolute source-bound Haskell executable as `validate phase 21`, then exact Cabal 3.16.1.0 and GHC 9.12.4 paths offline with `--jobs=1`; `pb` is not used. |
| `Oracle` | `test/spec/extension/ExtensionLawsPerExtensionOracle.hs` independently owns six operation cases, 35 law verdicts, and five mutation loci without importing the production evaluator. |
| `Positive controls` | Two lawful declarations yield ten green law verdicts; six authored operations, isolated deterministic renders, refusal-before-materialization budgets with reapers, closed request-flow values, and bound evidence fixtures are observed. |
| `Paired negatives` | Five lawful/one-defect subject pairs fail separately at `Totality`, `Determinism`, `BudgetHonesty`, `ScopePropagation`, and `EvidenceBinding`; the Phase-15 legal/missing-fixture compile pair must retain its pinned diagnostic. |
| `Mutants` | Five Cabal flags change the production evaluator by suppressing exactly one L1–L5 failure. Each changed subject must turn red at its named property. |
| `Discovery` | The acquired source snapshot must equal the exact production evaluator, spec, independent oracle, and law-fixture `.hs` paths in both directions; empty, missing, or extra discovery fails. |
| `Challenge` | All five production mutations are compiled and evaluated after source acquisition before the clean candidate; each exact property changes while the clean corpus remains green. |
| `Observer` | The supervisor retains absolute executable, argv, exit, stdout/stderr, and digest observations for Cabal version, five production mutants, the compile pair, and the clean run. |
| `Authority/bypass` | Authority is limited to exact Cabal/compiler/store paths and the unique run root; every build is offline and serial. `pb`, network, host, container, cluster, service, and hardware arguments are forbidden. |
| `Freshness` | One unique `.build/runs/phase-21/work/candidate-*` root is acquired; clean products are regenerated there and opening/closing Git source identities must match. |
| `Qualification` | The supervisor first kills all five changed-production mutations and verifies the claim/fixture compile pair, then requires the clean independent corpus to pass. |
| `Cleanroom` | The authenticated source-repository cache is copied beneath the unique run root, Cabal builds there, and the clean generated result must exist only below that root. |
| `Legacy closure` | The Python law gate, three serialized law authorities, serialized surface inventory, and test-local mutant module are absent; reintroduction is an exact failure. |
| `Predecessor` | Exact durable `ImmediatePredecessorPass` for Phase 20, projected monotonically onto this candidate's opening source; absent, malformed, wrong-phase, or non-green evidence fails. |
| `Residue` | Compositional and security laws, generated conformance verdicts, decoding, effects, runtimes, host, service, cluster, and hardware claims remain `UNVERIFIED` and later-phase-owned. |
| `Pass criterion` | Every one of the eighteen rows passes in one qualified run for the exact source; that complete pass is sufficient for the mechanical status-only transition. |

## Doctrine adopted

- [`extension_conformance_laws.md` §3 — L1–L5: the per-extension laws](../documents/engineering/extension_conformance_laws.md#3-l1l5-the-per-extension-laws) — the rule behind the per-extension laws L1-L5.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 21.1: The per-extension laws L1-L5 ✅

**Status**: Done
**Implementation**: `src/extension-laws/Amoebius/Extension/Laws/PerExtension.hs`; package-hidden `Amoebius.Validation.ExtensionLawsRun.Internal`.
**Blocked by**: [Phase 20](phase_20_extension_declaration.md) gate pass
**Independent Validation**: Two lawful controls, five single-law negatives, six generated-operation cases, 35 exact verdicts, the Phase-15 compile pair, and five changed-production mutants.
**Oracle**: `test/spec/extension/ExtensionLawsPerExtensionOracle.hs`; compile fixtures owned by `test/harness/extension_laws/LawFixtures.hs` and the Phase-15 compile-fail harness.
**Legacy IDs**: Phase-local legacy closure for the retired Python gate, four serialized behavioral authorities, and test-local mutant module.
**Docs to update**: `extension_conformance_laws.md`; `system_components.md`.

### Objective

Evaluate each L-law mechanically over explicit observations joined to one complete declaration, while keeping
the finite boundary distinct from generated conformance and runtime claims.

### Deliverables

- Pure five-law evaluator with typed failures and declaration-vocabulary coverage joins.
- Two lawful controls, five single-law negative subjects, and 35 authored expected verdicts.
- Finite wildcard/partial and ambient-source scans, with scanner-positive controls.
- Real budget exhaustion/retention and evidence claim/fixture values.
- Pinned compile-fail reuse, five exact executable mutants, and source-bound gate result.

### Validation

1. Require all ten lawful-control verdicts to pass and each of five negative subjects to fail only its named
   law.
2. Require six authored operation results, byte-identical isolated renders, exact refusal-before-materializing
   budget outcomes with reapers, and bound claim/fixture values.
3. Require pure-source scans to stay green while exact partial and ambient mutant controls remain visible.
4. Reuse the Phase-15 positive/negative compiler pair and require the illegal claim to fail for its pinned
   reason.
5. Require all five registered mutant modes to exit red at exactly their declared property.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — record the
  bounded evaluator and keep scanner completeness, arbitrary-declaration generation, universal proof, verdict
  sealing, and runtime correspondence explicitly outside the tested claim.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/system_components.md` and `documents/engineering/extension_conformance_laws.md` — record the exact evaluator, independent oracle, finite residue, and package-hidden Phase-21 supervisor.

## Related Documents

- [Development Plan](README.md)
- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the rule behind the per-extension laws L1-L5.
