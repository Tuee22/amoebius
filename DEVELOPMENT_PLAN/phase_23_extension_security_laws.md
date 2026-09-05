# Phase 23: The security laws S1-S6

> **Purpose**: Specify the target Haskell capability to evaluate S1–S6 over a bounded pure Haskell
> security kernel with typed identity and request-scope boundaries using independently authored
> `.hs` evidence.
> **Read this if**: the attested identity, scoped operation, derived namespace, revocation-policy value, or its
> finite evidence boundary must change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md
**Generated sections**: none

</details>

---

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 23.1: The security laws S1-S6](#sprint-231-the-security-laws-s1-s6-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 22, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase specifies a Haskell target capability; it does not report a current implementation or
result. The target is to evaluate S1–S6 over a bounded pure Haskell security kernel with typed
identity and request-scope boundaries using independently authored `.hs` evidence.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged; that entry point and its independent
evidence contract remain UNRESOLVED and block validation.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Target capability only — evaluate S1–S6 over a bounded pure Haskell security kernel
with typed identity and request-scope boundaries using independently authored `.hs` evidence.
NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 22](phase_22_extension_laws_compositional.md)
**Gate:** `pb validate phase 23`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | One bounded pure Haskell kernel evaluates S1–S6 over opaque claimed/attested identities, rank-2 request scopes, mandatory scoped operations, indistinguishable refusal observations, framed namespaces, and explicit revocation-edge-or-positive-bound authority policies. |
| `Subject` | `src/extension-security-laws/Amoebius/Extension/Laws/Security.hs`, acquired and exercised by the package-hidden Phase-23 supervisor. |
| `Command` | `pb validate phase 23` is the future public spelling. This pre-handoff gate invokes the exact absolute source-bound Haskell executable as `validate phase 23`, then exact Cabal 3.16.1.0 and GHC 9.12.4 paths offline with `--jobs=1`; `pb` is not used. |
| `Oracle` | `test/spec/extension/ExtensionSecurityLawsOracle.hs` independently owns fifteen operation outcomes, five namespace pairs, two policy cases, 42 verdict cells, six mutation loci, the fixture signature, and a separate SHA-256 implementation without importing production security types or evaluator. |
| `Positive controls` | Fifteen exact operation cases, five byte/step/state-equal refusal pairs, five injective round-trip namespaces, two edge-or-bound policy layers, one independently recomputed fixture signature, 42 verdict cells, and four independent addresses pass. |
| `Paired negatives` | Six lawful-versus-one-law-defect subjects cover S1–S6; one legal compiler control runs while claimed-as-attested, identity promotion, missing request scope, and cross-request scoped-key siblings each fail at their exact type boundary. |
| `Mutants` | Six Cabal flags change the production evaluator by suppressing exactly one S1–S6 failure. Each changed subject must turn red at its declared failure locus while the independent oracle remains unchanged. |
| `Discovery` | The acquired source snapshot must equal the production evaluator, spec, independent oracle, fixture module, and compiler sibling in both directions; empty, missing, or extra discovery fails. |
| `Challenge` | All six production mutations are compiled and evaluated after source acquisition before the clean candidate; each exact security-law observation changes while the clean corpus remains green. |
| `Observer` | The supervisor retains absolute executable, argv, exit, stdout/stderr, and digest observations for Cabal version, six production mutants, one legal and four illegal compiler siblings, and the clean run. |
| `Authority/bypass` | Authority is limited to exact Cabal/compiler/store paths and the unique run root; every build is offline and serial. `pb`, network, host, container, cluster, service, and hardware arguments are forbidden. |
| `Freshness` | One unique `.build/runs/phase-23/work/candidate-*` root is acquired; clean result/address products are regenerated there and opening/closing Git source identities must match. |
| `Qualification` | The supervisor first kills all six changed-production mutations and verifies all five compiler controls, then requires the clean independent corpus to pass. |
| `Cleanroom` | The authenticated source-repository cache is copied beneath the unique run root, Cabal builds there, and both clean generated products must exist only below that root. |
| `Legacy closure` | The Python security gate, five serialized security authorities, serialized surface inventory, and test-local mutant module are absent; reintroduction is an exact failure. |
| `Predecessor` | Exact durable `ImmediatePredecessorPass` for Phase 22, projected monotonically onto this candidate's opening source; absent, malformed, wrong-phase, or non-green evidence fails. |
| `Residue` | Production cryptography, wall-clock timing, persisted-value re-entry, compositional security closure, generated conformance verdicts, decoding, effects, runtimes, host, service, cluster, and hardware claims remain `UNVERIFIED` and later-phase-owned. |
| `Pass criterion` | Every one of the eighteen rows passes in one qualified run for the exact source; that complete pass is sufficient for the mechanical status-only transition. |

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6) — the rule behind the security laws S1-S6.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 23.1: The security laws S1-S6 ✅

**Status**: Done
**Implementation**: `src/extension-security-laws/Amoebius/Extension/Laws/Security.hs`; package-hidden `Amoebius.Validation.ExtensionSecurityRun.Internal`.
**Blocked by**: [Phase 22](phase_22_extension_laws_compositional.md) gate pass
**Independent Validation**: Fifteen operation controls, five refusal pairs, five namespaces, two authority policies, 42 verdicts, one fixture signature, four content addresses, four compiler barriers, and six changed-production mutants.
**Oracle**: `test/spec/extension/ExtensionSecurityLawsOracle.hs`; fixture in `test/harness/extension_security/SecurityFixtures.hs` and the compiler sibling.
**Legacy IDs**: Phase-local legacy closure for the retired Python gate, six serialized behavioral authorities, and test-local mutant module.
**Docs to update**: `extension_conformance_security.md`; `system_components.md`.

### Objective

Evaluate S1–S6 over the bounded pure kernel while retaining the persistence, timing, cryptographic-runtime,
and compositional residues honestly.

### Deliverables

- Opaque claimed/attested identity index and fixture verification introduction.
- Phase-8 rank-2 scope elimination at every operation and derived-key boundary.
- Mandatory scoped resolution with one public refusal for foreign and absent resources.
- One length-framed renderer for row, object, topic, cache, and replay keyspaces.
- Revocation-edge-or-positive-bound authority-layer value and S1–S6 evaluator.
- Authored finite corpus, four compiler barriers, and six exact executable mutants.

### Validation

1. Match all fifteen operation cases and all 42 authored law verdicts.
2. Require all five foreign/absent pairs to return identical bytes with no mutation and equal modeled steps.
3. Independently recompute all five namespace pairs and the one fixture signature.
4. Require claimed use, promotion, missing scope, and cross-request key programs to fail at their pinned type
   reasons while the legal twin runs.
5. Require every registered mutant to redden exactly its declared S-law.

### Remaining Work

Production cryptography, wall-clock timing, persisted-value re-entry, compositional S closure, runtime
integration, and a generated conformance verdict remain later work rather than Phase-23 completion criteria.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — record
  the bounded S1–S6 evaluator without upgrading production cryptography, wall-clock timing, persisted-value
  re-entry, compositional closure, or runtime fidelity.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/system_components.md` and `documents/engineering/extension_conformance_security.md` — record the bounded kernel, independent oracle, finite residue, and package-hidden Phase-23 supervisor.

## Related Documents

- [Development Plan](README.md)
- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — the rule behind the security laws S1-S6.
