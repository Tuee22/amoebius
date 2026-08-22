# Phase 23: The security laws S1-S6

> **Purpose**: Mechanically evaluate S1–S6 over a bounded pure security kernel with typed identity and request
> scope boundaries.
> **Read this if**: the attested identity, scoped operation, derived namespace, revocation-policy value, or its
> finite evidence boundary must change.

This phase owns a Register-1 evaluator and a small two-tenant/two-subject model for the six security laws. It
reuses Phase 8's lexical rank-2 request scope; it does not claim that arbitrary application states are
unrepresentable, provide the persisted-value re-entry back door, prove timing indistinguishability, verify a
production identity provider, or close the S family under composition. The normative laws remain owned by
[`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, DEVELOPMENT_PLAN/phase_95_webapp_rederivation.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 23.1: The security laws S1-S6 ✅](#sprint-231-the-security-laws-s1-s6-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. All thirteen gate sides passed on natural `arm64`, untranslated: thirteen exact
metrics matched and 26 surfaces joined to 30 run-time items. Attestation
`sha256:d93277812867d29982bdead0f3af23f29f698672eb4aa229bb0a0cddb63547dd` binds source
`sha256:e1cf7fa2dbb2d06e…` over 2,247 files. Repository-conformance attestation
`sha256:76a767b39cc3654c99721671c336780b30539a3deb881567f4933dc70759d9e7` and documentation lint passed on
that snapshot. Production cryptography, wall-clock timing, persisted-value re-entry, compositional S closure,
runtime correspondence, and a conformance verdict remain UNVERIFIED.

## Phase Summary

`lib:extension-security-laws` distinguishes `Identity 'Claimed` from `Identity 'Attested`; only the fixture
verification boundary introduces the latter. Eliminating an attested identity delegates to Phase 8's rank-2
`withRequestScope`, so every scoped operation and derived key requires the fresh request index. Opaque stores
resolve tenant, subject, and resource together, use one public refusal for absent and foreign resources, and
expose no unscoped operation arm. The five derived keyspaces use one length-framed renderer and a scope-indexed
key. Authority layers have only two constructors: an observed revocation edge or a declared positive staleness
bound.

The evaluator consumes explicit observations for all six laws. Its finite corpus covers five operations over
own, foreign, and absent targets; five adversarial namespace component transpositions; one observed edge and
one enforced modeled bound; one lawful six-law subject and six one-law defects. Four compiler negatives pin
claimed-as-attested use, a promotion function, missing request scope, and a key minted under a different
request. Six executable mutants redden the exact corresponding law loci.

**Phase scope:** one valid and one tampered fixture envelope, fifteen scoped operation cases, five
foreign/absent refusal pairs, five modeled equal-step observations, five injective namespace pairs, two
authority-layer policies, 42 authored S-law verdicts, four exact compiler barriers, one finite constructor and
unsafe-token scan, one independently recomputed fixture SHA-256 signature, and six executable mutants.
Production cryptographic verification, wall-clock timing, persisted-value re-entry, arbitrary application
surfaces, compositional S closure, and the Phase-24 conformance verdict remain outside the claim.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 21](phase_21_extension_laws_per_extension.md) — L1–L5, which S2, S3 and S5 sharpen at a particular seam. The other three add obligations no per-extension law reaches, so this phase is not a corollary of its predecessor.
**Gate:** `python3 tools/run_phase_gate.py 23` rebuilds both suites and requires thirteen
metrics, independent Python signature and namespace framing, authored operation/revocation/verdict tables,
four specific compiler failures, six exact mutants, the complete surface join, architecture, containment,
write guard, ledger, and source-bound attestation; [Gate integrity](#gate-integrity) owns the anti-tautology
apparatus.

## Gate integrity

- **Representative set (§M.7):** the store names two tenants and two subjects. Read, update, delete, replay,
  and cache lookup each run against own, foreign, and absent targets. All five keyspace constructors receive a
  component-transposition pair, and the authority table contains one connected and one disconnected layer.
- **Independent oracle (§M.1/§M.3):** authored TSVs state all fifteen operation outcomes, five namespace
  pairs, two authority policies, and 42 verdicts. Python independently checks their shapes, recomputes every
  emitted length-framed namespace, and recomputes the fixture SHA-256 signature from an eight-byte big-endian
  framing implementation separate from the Haskell fixture.
- **Mutation quota (§M.2):** tampered-identity acceptance, caller-supplied scope, an unscoped arm,
  distinguishable refusal, resource-only namespace, and missing revocation policy each redden exactly S1,
  S2, S3, S4, S5, and S6 respectively.
- **Specific-reason negatives (§M.8):** the legal claimed identity compiles. Claimed-as-attested use, an
  explicit promotion, and missing scope fail at GHC-83865 on their named types/call; a cross-request key fails
  at GHC-25897 on the rigid request indices.
- **Finite coverage honesty (§M.4):** the signature is a fixture SHA-256 check rather than a production
  cryptographic identity provider. Refusal timing compares modeled step counts with a declared zero-step
  difference, not wall-clock observations. The unsafe/source scanner recognizes a finite token set, and the
  two authority layers do not stand for a runtime inventory.
- **External observation (§M.5/§M.10):** authored TSVs, a separately implemented Python framing/signature
  oracle, GHC diagnostics, and executable mutant modes observe the library. The production evaluator does not
  author its expected verdict table.
- **Authority/bypass (§§M.11–M.12):** attested identity, verification key, store, scoped key, staleness bound,
  and authority-layer constructors are private. Observation bundles decide bounded law evidence; they do not
  mint scopes, decrypt persisted values, or seal a conformance verdict. Phase 8 still has no persisted-value
  re-entry combinator, so the doctrine's single audited back door remains owed.
- **Fresh challenge (§M.9):** not applicable. This gate is pure; independent authored tables, Python
  recomputation, compiler twins, and executable mutants supply its challenge apparatus.
- **Extension conformance (§M.13).** Not applicable. This phase implements bounded S1–S6 evidence; Phase 24
  still owns generation and sealing of an extension conformance verdict.

## Doctrine adopted

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — the rule behind the security laws S1-S6.

## Sprints

## Sprint 23.1: The security laws S1-S6 ✅

**Status**: Done.
**Implementation**: `src/extension-security-laws/Amoebius/Extension/Laws/Security.hs`,
`test/{harness,mutant}/extension_security/*.hs`,
`test/negative/compile_fail/extension_security/SecurityCompile.hs`,
`test/spec/extension/ExtensionSecurityLawsSpec.hs`, `test/oracle/extension_security/*.tsv`,
`test/oracle/extension_security_laws_surfaces.tsv`, and `tools/extension_security_laws_gate.py`.
**Blocked by**: None.
**Independent Validation**: authored operation, namespace, authority, and 42-cell verdict tables; independent
Python framing/signature checks; legal/illegal compiler twins; finite source scan; and six exact mutants.
**Docs to update**: `documents/engineering/extension_conformance_security.md`

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

None. Production cryptography, wall-clock timing, persisted-value re-entry, compositional S closure, runtime
integration, and a generated conformance verdict remain later work rather than Phase-23 completion criteria.

## Documentation Requirements

**Engineering docs to update after the capability gate passes:**

- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — record
  the bounded S1–S6 evaluator without upgrading production cryptography, wall-clock timing, persisted-value
  re-entry, compositional closure, or runtime fidelity.

## Related Documents
- [Development Plan](README.md)
- [`extension_conformance_security.md`](../documents/engineering/extension_conformance_security.md) — the rule behind the security laws S1-S6.
