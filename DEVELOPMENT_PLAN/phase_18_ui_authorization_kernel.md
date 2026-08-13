# Phase 18: UI authorization kernel

> **Purpose**: Build the pure action-registry and current-authority transition that keeps client presentation,
> server dispatch, policy, scope, audit, and plan freshness in exact agreement.
> **Read this if**: phase 18 is next in the queue, or a later phase depends on what its gate establishes.

Phase 18 delivers the UI authorization kernel; its design is owned by [low_code_ui_runtime_doctrine.md](../documents/engineering/low_code_ui_runtime_doctrine.md), and the plan for reaching it is owned here.
Register 1: an in-process battery, no cluster.
Gate passed on 2026-08-09 with ledger `external-run-reference`.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_19_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_34_app_tenancy.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/testing_doctrine.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 18.1: Sealed action registry and authorized-action transition ✅](#sprint-181-sealed-action-registry-and-authorized-action-transition-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-13. The migrated gate passed against source snapshot `sha256:5397884a3bd5b8ad…`
(1943 non-ignored files) and published verified external attestation
`sha256:409c13f0c41aec877a4f3f72c3509fd1c17322523920e1deff0abac0b1cca88a`.

**Observed progress — 2026-08-13:** **Policy-conformant.** The authorization result is unchanged and re-run:
five registry rows normalize exactly, six matrix rows agree with a reference evaluator that does not import
the module under test, four parity diagnostics and four authority-epoch refusals hold at their pinned tags
with empty effect traces, nine generated classes clear their 5% floor, and both seeded mutants redden.
Evidence and the ledger move into `gen/runs/phase_18/<run-id>/`, and 40 surfaces join two-way to 57 run-time
enumerated items with every surface carrying at least one id.

**The closed sums are now checked as sums, not implied by their rows.** `ActionEffect` and `Permission` each
have a check that reads the declaration, compares the arms against the contract's list, and requires the
`Bounded`/`Enum` deriving that makes the union enumerably closed. Five pinned registry rows say the five arms
work; they say nothing about a sixth arm being added beside them.

**The two mutants keep their own surfaces.** The pinned row proves the refusal happens and the mutant proves
the check that refuses has teeth, so `default-allow-mutant` and `visibility-authorization-mutant` join to the
mutants rather than riding inside `default-deny` and `hidden-action-invocable`. A reader can then see which of
the two halves went missing.

**Invalidated historical record:**

✅ Done. The sealed five-action registry, independent authorization matrix, exact parity and stale-epoch errors,
coverage floors, empty denial traces, and both authority mutants pass. This proves the closed authorization
relation in process; it makes no claim that a live edge, identity provider, or UI-server deployment enforces
the relation. See the Phase-18 ledger.

## Phase Summary

This phase implements one seam: checked action declarations form a sealed authorization registry, the
independently checkable `CanRead`/`CanInvoke` relation, and the only `RequestContext` + current-policy transition
that can construct `AuthorizedAction`. Client visibility is an advisory projection of that relation, never its
input. A cached decision cannot cross a policy, membership, grant, or scope epoch before the pure effect
interpreter records an effect.

**Session scope:** one pure authorization/action-registry algebra and reference test interpreter; acceptance
command `cabal test ui-authorization-spec`; split on any HTTP server, browser runtime, live credential, second
register, or substrate requirement.
**Dependency:** Phase 17 — scope-indexed request contexts, handles, audiences, and flow witnesses.
**Substrate:** none — the gate runs hermetically with credential variables scrubbed and network unavailable.
**Register:** 1 — pure/golden.
**Gate:** `python3 tools/phase18_gate.py` passes the Phase-0-pinned action/access matrices, current-authority
replay cases, coverage floors, isolated execution, and both seeded mutants in
[Gate integrity](#gate-integrity). Live enforcement remains UNVERIFIED until its owning Register-3 phases.

## Gate integrity

Phase 0 commits every expected decision and projection before `Amoebius.Ui.Security.Authorization` exists. The oracle
side is hand-authored and cannot import the action binder, policy evaluator, plan-digest fold, or projection
functions under test.

- **Representative set:** `ReadData`, `MutateData`, `StartWorkflow`, `ObserveWorkflow`, and `EndSession` ports,
  with tenant-wide, role-shared, subject-owned, and grant-mediated policies. Each allow has a same-action denial
  differing only in subject, tenant, role, grant, or authority epoch.
- **Pinned oracles:** `test/fixtures/ui_authorization/action_registry.tsv` owns the exact normalized action
  tuples; `authorization_matrix.tsv` owns `CanRead`/`CanInvoke` allow/deny decisions, including explicit
  hidden-but-invocable and default-deny rows; `stale_decision_cases.tsv` owns policy/membership/grant/scope
  epoch outcomes; and `decode_errors.tsv` pins failures.
- **Independent checks:** a small reference evaluator reads the matrix's explicit predicates and authority
  version. A separate set comparison reads serialized sealed projections; neither reuses the production
  evaluator or registry extractor.
- **Specific negatives:** missing/extra/duplicate action, equal-cardinality permission swap, absent policy,
  foreign scope, revoked grant, and stale membership/policy/scope epoch each assert a distinct committed
  `AuthorizationError`.
- **Generator coverage:** QuickCheck classifies every mismatch class and requires at least 5% denial coverage
  for absent policy, wrong scope, wrong permission, and stale epoch, plus positive coverage for every effect arm.
- **Effect discipline:** the pure reference interpreter records an effect only after `AuthorizedAction` exists;
  every denial and stale replay has an empty trace. Fresh external challenges and real credentials are not
  applicable in Register 1 and are deliberately deferred to Phases 36 and 56.
- **Seeded mutants:** `default_allow` changes absent-policy refusal to allow, and
  `visibility_is_authorization` substitutes the client visibility projection for current server policy. Both
  are committed from the adopted authorization brief and must turn the matrix red.

Passing proves correspondence for the checked corpus and properties. It does not prove Keycloak identity truth,
HTTP routing, handler implementation correctness, or provider-side isolation.

## Doctrine adopted

- [`low_code_ui_runtime_doctrine.md` §3 — one checked value, two runtime plans](../documents/engineering/low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans): both projections come from one private bound value.
- [`low_code_ui_runtime_doctrine.md` §8 — effects are typed ports](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations): the action registry is the sole effect owner.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge): presentation never grants authority.
- [`illegal_state_catalog.md` §3.79](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration): default-deny and visibility-independence mutants are mandatory.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 18.1: Sealed action registry and authorized-action transition ✅

**Status**: Done — the capability is re-established by the migrated gate; the sprint's committed-ledger, pinned-toolchain, and repository-resident evidence mechanics are superseded
**Implementation**: `src/Amoebius/Ui/Security/Authorization.hs`,
`test/ui/AuthorizationSpec.hs`, `test/ui/AuthorizationReference.hs`, and `tools/phase18_gate.py`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: `cabal test ui-authorization-spec` compares
production results with Phase-0 pins and the separate reference evaluator, verifies empty denied traces, and
requires each named mutant to fail. The full hermetic gate is
`python3 tools/phase18_gate.py`.
**Docs to update**:
`documents/engineering/low_code_ui_runtime_doctrine.md`,
`documents/illegal_state/illegal_state_security.md`, `documents/engineering/testing_doctrine.md`

### Objective

Adopt the low-code runtime's single action-registry ownership and state-indexed authorization transition so no
effect can be represented by a raw action id, client visibility decision, absent policy, mismatched projection,
or stale authority snapshot.

### Deliverables

- Private `BoundActionRegistry`, current `AuthoritySnapshot`, and `AuthorizedAction` types with total bind,
  projection-parity, policy-evaluation, and freshness checks returning stable structured errors.
- A total `CanRead`/`CanInvoke` decision that requires current subject, scope, policy, membership, and grant
  epochs and cannot be reconstructed from visibility state.
- A tiny pure effect interpreter whose input requires `AuthorizedAction`, used only to establish zero trace on
  denial and not as the independent decision oracle.
- Matrix/golden readers, property coverage, stale replay corpus, mutant configurations, and a Register-1 ledger.

### Validation

1. Run `cabal test ui-authorization-spec`; exact registry/projection sets and every allow/deny row match their
   independent pins, including paired own/foreign scope and active/revoked grant cases.
2. Evaluate under authority A, change one policy/membership/grant/scope epoch to B, and try to reuse A's
   decision; the pinned cases require recomputation or precise denial and an empty pure effect trace.
3. Run `default_allow` and `visibility_is_authorization`; the default-deny and hidden-but-invocable rows must
   turn red respectively.
4. Verify network and credential access are impossible in the gate process and the ledger marks runtime policy
   and provider enforcement UNVERIFIED.

### Remaining Work

None in Phase 18. Live identity, UI-server, policy-provider, and tenant-isolation enforcement remains owned by
the later Register-3 phases and is UNVERIFIED here.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record pure action-registry and authorization
  evidence without claiming live enforcement.
- `documents/illegal_state/illegal_state_security.md` — attach §3.79 Gate-2 fixture and mutant evidence.
- `documents/engineering/testing_doctrine.md` — register the independent authorization-matrix and stale-replay
  oracle pattern.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — index the phase, gate, `none` substrate, and module ownership.
- Later UI server/boundary phases — consume `AuthorizedAction`; do not reproduce the policy evaluator.

## Related Documents

- [Phase 17](phase_17_scoped_identity_kernel.md) — the required scoped identity and flow kernel.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — action ownership, server authorization, and freshness contract.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — independent authored expectations and evidence registers.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — authorization parity and visibility-bypass failures.
