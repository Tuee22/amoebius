# Phase 21: The per-extension laws L1-L5

> **Purpose**: Mechanically evaluate L1–L5 over one complete extension declaration using bounded, independently
> authored observations.
> **Read this if**: the per-extension law evaluator, its finite evidence boundary, or any L1–L5 gate claim must
> change.

This phase owns the pure L1–L5 observation evaluator and a bounded Register-1 suite over the two Phase-20
declaration fixtures. It does not generate a gate from an arbitrary declaration, prove totality or termination,
certify runtime implementations, state compositional/security/transaction laws, or mint a conformance verdict.
The normative laws remain owned by
[`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md, DEVELOPMENT_PLAN/phase_23_extension_security_laws.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, documents/engineering/extension_conformance_laws.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 21.1: The per-extension laws L1-L5 ✅](#sprint-211-the-per-extension-laws-l1-l5-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All thirteen gate sides passed on natural `arm64`, untranslated: twelve exact
metrics matched and 22 surfaces joined to 24 run-time items. Attestation
`sha256:20d5afb51d7e2e3abeafe1df76232aebb5f2fda2cdbe1031fddb0c3e09de646b` binds source
`sha256:37c11b4d2ffb432d…` over 2,225 files. Repository-conformance attestation
`sha256:4142c31b1f78f5531e96cdee7d80f478646a6683200ea4dd24f4e5262ae07a99` and documentation attestation
`sha256:888489f78c2281245d5ebd53d8b445f760d27bf7c6d96f0f06fe7c3b9c798856` passed on that snapshot.
Termination, scanner completeness, arbitrary-declaration gate generation, runtime correspondence, and a
conformance verdict remain UNVERIFIED.

## Phase Summary

`lib:extension-laws-per-extension` accepts an `ExtensionDeclaration scope` plus explicit observations for
operations, rendered artifacts, budgets, flows, and evidence. It first joins every observation name back to
the declaration's derived workflow, artifact, budget, or evidence set, then reports typed failures separately
for L1 through L5. L4 uses the closed finite relation `RequestFlow < TenantFlow < GlobalFlow`; it admits equal
or narrower sinks and rejects widening.

The executable suite constructs the `infernix` and `jitml` Phase-20 declaration shapes, evaluates six authored
operation inputs without a catch-all arm, renders each declared artifact in two independently seeded child
processes, executes the real budget admission/exhaustion/retention protocol, and constructs real evidence
`Fixture` and `Claim` values. Its 7-subject/35-verdict oracle contains two lawful controls and five subjects
that each fail exactly one of L1–L5. The L1 and L2 defects use independently visible partial-operation and
ambient-environment controls; the other three alter one observation at the law seam.

The gate rebuilds the suite, reruns the Phase-15 compile-fail harness for the L5 claim/fixture type barrier,
executes all five mutant modes, independently validates the authored oracle shape, scans the pure fixture for
known partial/wildcard and ambient-source tokens, and joins 22 authored surfaces to exact observations. The
suite is bounded evidence about those fixtures. It is not a generated per-extension gate, a universal proof,
or a verdict that either namesake runtime conforms. Loop freedom and runtime correspondence remain
UNVERIFIED.

**Phase scope:** two declaration fixtures, six operation inputs, 35 L1–L5 verdicts, two isolated-process render
comparisons, two budget/evidence protocols, one pinned compiler barrier, two finite source scans, and five
single-law mutants. Arbitrary declarations, termination, scanner completeness, generated gates, runtime
correspondence, and a conformance verdict remain outside the claim.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 20](phase_20_extension_declaration.md) — the declaration each law is instantiated over.
**Gate:** `python3 tools/run_phase_gate.py 21` rebuilds the suite and requires twelve
metrics, the 7-by-5 verdict table, six distinct generated inputs, the pinned L5 compiler negative,
five exact red mutants, a 22-surface join, architecture, containment, write guard, ledger, and source-bound
attestation; [Gate integrity](#gate-integrity) owns the anti-tautology apparatus.

## Gate integrity

- **Representative set (§M.7):** two complete declarations exercise every L-law twice; six explicit operation
  inputs include the partial mutant's `panic` arm, and five additional subjects each alter exactly one law.
- **Independent oracle (§M.1/§M.3):** `law_verdicts.tsv` is a 7-by-5 expected-verdict table authored outside
  the evaluator. The Python gate independently requires two all-green rows plus one and only one negative for
  each law; `operation_cases.tsv` independently supplies the six exact operation results.
- **Mutation quota (§M.2):** partial operation, ambient render, missing retained-output reaper, widened scope,
  and missing claim fixture redden `Totality`, `Determinism`, `BudgetHonesty`, `ScopePropagation`, and
  `EvidenceBinding` respectively. Each executable mutant must fail with its exact token and no second red law.
- **Specific-reason negatives (§M.8):** the Phase-15 `claim-names-fixture` legal twin remains green and its
  adjacent illegal twin must fail at pinned GHC code 83865 because `claim` lacks its fixture argument.
- **Finite coverage honesty (§M.4):** the wildcard and ambient scanners recognize a finite token set; generated
  inputs are six authored values; a total Haskell function may still loop. No result is extrapolated to an
  arbitrary declaration or runtime extension.
- **External observation (§M.5/§M.10):** child processes, actual Phase-4/Phase-7 values, authored TSVs, GHC
  diagnostics, and a Python oracle observe the evaluator. The production module cannot write its gate result.
- **Authority/bypass (§§M.11–M.12):** the evaluator rejects missing declaration vocabulary by coverage joins,
  but Phase 24 owns gate generation and verdict sealing. A hand-built observation bundle is evidence input,
  not authority to declare conformance.
- **Fresh challenge (§M.9):** not applicable. This is a pure finite evaluator; independent process seeds test
  byte equality, while authored verdicts and mutation controls provide the challenge apparatus.
- **Extension conformance (§M.13).** Not applicable. This phase implements bounded per-extension predicates;
  it does not generate or seal the complete L/C/S/P conformance gate.

## Doctrine adopted

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the rule behind the per-extension laws L1-L5.

## Sprints

## Sprint 21.1: The per-extension laws L1-L5 ✅

**Status**: Done.
**Implementation**: `src/extension-laws/Amoebius/Extension/Laws/PerExtension.hs`,
`test/{harness,mutant}/extension_laws/*.hs`, `test/spec/extension/ExtensionLawsPerExtensionSpec.hs`,
`test/oracle/extension_laws/*.tsv`, `test/oracle/extension_laws_per_extension_surfaces.tsv`, and
`tools/extension_laws_per_extension_gate.py`.
**Blocked by**: None.
**Independent Validation**: the authored 35-cell verdict grid, six operation cases, isolated render processes,
actual budget/evidence protocols, pinned compiler negative, finite source scanners, and five exact mutants.
**Docs to update**: `documents/engineering/extension_conformance_laws.md` and
`DEVELOPMENT_PLAN/{README,overview,system_components}.md`.

### Objective

Evaluate each L-law mechanically over explicit observations joined to one complete declaration, while keeping
the finite boundary distinct from generated conformance and runtime claims.

### Deliverables

- Pure five-law evaluator with typed failures and declaration-vocabulary coverage joins.
- Two lawful controls, five single-law negative subjects, and 35 authored expected verdicts.
- Finite wildcard/partial and ambient-source scans, with scanner-positive controls.
- Real budget exhaustion/retention and evidence claim/fixture values.
- Pinned compile-fail reuse, five exact executable mutants, and source-bound gate attestation.

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

None.

## Documentation Requirements

**Engineering docs to update after the capability gate passes:**

- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — record the
  bounded evaluator and keep scanner completeness, arbitrary-declaration generation, universal proof, verdict
  sealing, and runtime correspondence explicitly outside the tested claim.

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_laws.md`](../documents/engineering/extension_conformance_laws.md) — the rule behind the per-extension laws L1-L5.
