# Phase 20: The extension declaration

> **Purpose**: Make an extension one complete, inspectable value with a mandatory component from each core
> calculus, one request-scope index, exact resource accounting, and a content-derived identity.
> **Read this if**: the extension value, its five readers, its canonical identity, or the boundary between a
> declaration and later conformance-law machinery must change.

This phase owns `lib:extension-declaration`, the complete declaration shape, and its bounded Register-1
evidence. It consumes the five-component algebra from Phase 10. It does not state or discharge L-, C-, S-, or
P-laws, generate a conformance suite, mint a verdict, prove declaration uniqueness within a linked library, or
claim that the two fixture declarations are conforming domain extensions.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, documents/engineering/extension_conformance_laws.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 20.1: Complete indexed declaration ✅](#sprint-201-complete-indexed-declaration-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All thirteen gate sides passed on natural `arm64`, untranslated: ten exact
metrics matched and 18 surfaces joined to 20 run-time items. Attestation
`sha256:8fda8331662847891e69173fe8ea43b041c4aa43ef688638b921085ff62c8d99` binds source
`sha256:fedf29ba024d1e10…` over 2,216 files. Repository-conformance attestation
`sha256:e75686f058eebb27e43c237b5f2895ce30cd619dfdcb6694790a1604dc18723b` and documentation attestation
`sha256:4de39c603a98df36753941c11af1766f33b392458f1844f4dc86d0a34f8ac986` passed on that snapshot. The
declaration boundary and canonical identities are tested only over the declared corpus; SHA-256 collision
absence is ASSUMED, and law conformance plus runtime fidelity remain UNVERIFIED.

## Phase Summary

`lib:extension-declaration` exports an opaque `ExtensionDeclaration scope`. Its only normal constructor takes
an extension name and exactly five `Component scope` arguments in artifact, budget, lift, workflow, and
evidence order. It rejects an empty extension name and a component occupying the wrong calculus slot. Because
all five arguments share the same generative request-scope variable, components minted by different requests
do not typecheck together. Each component retains its own resource vector; the declaration's resource index is
the exact Phase-10 natural-number composition fold.

Five calculus-specific readers derive singleton sets from the stored components. A canonical payload
projection maps recipes, allowances, layers, structured workflow ledgers, and evidence registers to explicit
semantic fields without `Show`; the declaration digest is SHA-256 over the version, extension name, calculus
tag, component name, four resource coordinates, and those payload fields, each independently length-framed.
Collision resistance is assumed, not proven.

The bounded corpus contains two fixture declarations, `infernix` and `jitml`, with ten independently authored
semantic rows. They are declaration-shape fixtures only: neither is a Phase-21 law verdict nor the later live
re-derivation of its namesake seed. The Haskell suite compares all readers to the table, checks exact calculus
order and resource totals, and emits observations beneath `.build/**`. Python independently recomputes both
digests from the authored fields. A legal five-component/same-scope program compiles; the adjacent missing-
component and cross-request programs fail at constructor arity and request-scope equality. Three mutations
make one component optional, erase the scope index, or omit the declared recipe from its reader, and each is
observed at its named locus.

**Phase scope:** Two concrete declaration-shape fixtures, ten mandatory components, five exact readers, two
semantic refusals, two compiler barriers, two independently recomputed identities, and three mutants; a law
property, conformance verdict, link-set rule, runtime extension, or additional calculus belongs to its owning
later phase.
**Substrate:** none
**Lane:** none
**Register:** 1 — pure declaration construction, authored semantic oracles, compiler negatives, and mutation.
**Depends on:** [Phase 10](phase_10_calculus_composition.md) — supplies the closed five-calculus component sum,
same-request index, component resource vectors, exact composition fold, and canonical payload projections.
**Gate:** `python3 tools/run_phase_gate.py 20` passes ten exact metrics, two-declaration/ten-component
inventory agreement, independent SHA-256 recomputation, two typed barriers, three exact mutants, an
18-surface/20-item join, architecture, containment, write guard, ledger, and source-bound attestation; [Gate
integrity](#gate-integrity) owns the anti-tautology apparatus.

## Gate integrity

- **Representative set (§M.7):** two fixture declarations each carry exactly one artifact, budget, lift,
  workflow, and evidence component; their ten rows vary every payload kind and both declaration identities.
- **Independent oracle (§M.1/§M.3):** `inventory.tsv` is authored from the two fixture definitions. The gate's
  Python implementation separately length-frames those semantic fields and recomputes SHA-256; no digest or
  generated output is committed as an oracle.
- **Mutation quota (§M.2):** optional evidence, erased request-scope equality, and omitted artifact-reader
  output redden `RequiredComponents`, `ScopeIndexPreserved`, and `ArtifactReaderComplete` respectively.
- **Specific-reason negatives (§M.8):** the legal five-component/same-scope program runs first. Its four-
  component sibling fails because `declareExtension` still awaits a component; its mixed-request sibling fails
  at the `RequestScope` equality. Each production mutation makes only its corresponding forbidden program run.
- **Finite coverage honesty (§M.4):** exactly two names, ten components, two semantic refusals, and the empty
  workflow-ledger payload are tested. Arbitrary extensions, non-empty workflow-ledger payloads, SHA-256
  collision absence, and runtime fidelity are not inferred.
- **External observation (§M.5/§M.10):** the authored table, independent Python digest, and GHC diagnostics
  observe the library. The production module does not decide its own verdict.
- **Authority/bypass (§§M.11–M.12):** the constructor is private and its checked smart constructor is the only
  normal introduction rule. Whether a linked extension has an undeclared side channel or multiple competing
  declaration values is a later law/admission question and remains UNVERIFIED.
- **Fresh challenge (§M.9):** not applicable. This is a pure value boundary and accepts no effectful response;
  the independently authored predicate and changed-name digest control are the challenge.
- **Extension conformance (§M.13).** Not applicable: this phase builds the contract. It does not
  claim either fixture has a conformance verdict.

## Doctrine adopted

- [`extension_conformance_doctrine.md` §2](../documents/engineering/extension_conformance_doctrine.md#2-what-an-extension-is): the extension boundary is an inspectable value.
- [`extension_conformance_doctrine.md` §3](../documents/engineering/extension_conformance_doctrine.md#3-the-obligation-surface-one-component-per-calculus): the value has one mandatory component per calculus.
- [`extension_conformance_doctrine.md` §6](../documents/engineering/extension_conformance_doctrine.md#6-the-verdict-seal): declaration identity is content-derived; verdict construction remains later work.

## Sprints

## Sprint 20.1: Complete indexed declaration ✅

**Status**: Done.
**Implementation**: `src/extension-declaration/Amoebius/Extension/Declaration.hs`,
`src/calculus-composition/Amoebius/Calculus/Composition.hs`,
`test/spec/extension/ExtensionDeclarationSpec.hs`,
`test/negative/compile_fail/extension_declaration/DeclarationCompile.hs`,
`test/mutant/extension_declaration/ExtensionDeclarationMutants.hs`,
`test/oracle/extension_declaration/{inventory,mutation_catalog}.tsv`,
`test/oracle/extension_declaration_surfaces.tsv`, and `tools/extension_declaration_gate.py`.
**Blocked by**: None.
**Independent Validation**: the ten-row authored inventory and independent Python digest implementation agree
with the actual readers; GHC rejects both adjacent illegal programs at their pinned reasons.
**Docs to update**: `documents/engineering/extension_conformance_doctrine.md` and
`DEVELOPMENT_PLAN/{README,overview,system_components}.md`.

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

None.

## Documentation Requirements

Update [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) only
after the capability gate passes, distinguishing the tested declaration boundary from unimplemented law,
gate-generation, verdict, and runtime claims.

## Related Documents
- [Development Plan](README.md)
- [Phase 10](phase_10_calculus_composition.md) — the component and index algebra this phase stores.
- [Phase 21](phase_21_extension_laws_per_extension.md) — the first laws instantiated over this value.
- [`extension_conformance_doctrine.md`](../documents/engineering/extension_conformance_doctrine.md) — the
  normative extension contract and honesty boundary.
