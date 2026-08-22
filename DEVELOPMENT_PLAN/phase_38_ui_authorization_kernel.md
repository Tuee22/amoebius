# Phase 38: UI authorization kernel

> **Purpose**: Make one sealed action registry and current-authority transition decide whether a scoped UI
> action may produce an effect.
> **Read this if**: action declarations, client/server projection parity, authorization freshness, or the
> `AuthorizedAction` boundary has to change.

This phase owns the pure UI authorization decision. It does not authenticate a live identity, route HTTP,
dispatch a handler, install provider policy, or prove tenant isolation. Those effects belong to later binding,
server, identity-provider, and live-tenancy phases.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/testing_doctrine.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 38.1: Sealed registry and parity ✅](#sprint-381-sealed-registry-and-parity-)
- [Sprint 38.2: Current-authority decision and negative controls ✅](#sprint-382-current-authority-decision-and-negative-controls-)
- [Sprint 38.3: Calculus projection and phase seal ✅](#sprint-383-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — sealed 2026-08-21. The complete thirteen-sided gate passes on natural `darwin/arm64`, untranslated.
Five exact actions, six decisions, four parity errors, four stale-epoch refusals, nine coverage classes, and
both paired mutants pass; the real five-calculus composition projects counts `5,6,8,9,2` to resource vector
`5,30,0,0`. All 15 metrics match and 46 surfaces join to 63 enumerated items. Attestation
`sha256:ab73be4f6ad8cf16be617c7f4681f880241612da3aa01d6bf56d4715a43bfd1f` binds source
`sha256:43020e5e808f2ef4…` over 2,261 files. Live edge, identity-provider, UI-server, and provider-policy
enforcement remains UNVERIFIED.

**Activated 2026-08-21** when Phase 37 sealed. The generative re-baseline invalidated the earlier seal because
it had no calculus projection or natural-architecture record.

---

## Phase Summary

Five `ActionSpec` values form a sealed `BoundActionRegistry`. Each action fixes its closed effect arm,
permission, presentation visibility, and idempotence bit. Client and server projections come from that same
registry and must match an independently authored projection. Missing, unexpected, duplicate, and
equal-cardinality permission-swapped registries retain distinct refusal constructors.

Authorization combines the sealed registry, a scoped request context, subject/tenant ownership, requested
permission, and an `AuthoritySnapshot`. The snapshot and presented authority must agree on policy,
membership, grant, and scope epochs. Only a current, matching decision creates private `CanRead`/`CanInvoke`
witnesses inside a constructor-private `AuthorizedAction`; the pure effect interpreter accepts no weaker
input. Client visibility never enters the authorization predicate.

**Phase scope:** one cohesive claim — presentation, client/server declaration, current policy, request scope,
and effect admission have one pure decision boundary. Live identity truth, HTTP routing, handler binding,
provider policy, or tenant-isolation observation splits out.

**Substrate:** `none` — registry construction, reference evaluation, QuickCheck coverage, epoch replay, and
calculus composition are pure host processes with credentials scrubbed and networking denied
([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `none` ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure/generative: independently authored rows and paired controls constrain the decision
relation; identity-provider truth and runtime/provider enforcement remain UNVERIFIED
([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 8](phase_08_scope_index.md) — trusted scoped identity and request contexts; [Phase
10](phase_10_calculus_composition.md) — the actual five-calculus composition; [Phase
37](phase_37_ui_program_schema.md) — the constructor-private checked program that is scoped before registry
binding.

**Gate:** `python3 tools/run_phase_gate.py 38` passes the exact registry, independent decision, parity,
epoch, generated-coverage, five-calculus, paired-mutant, network-observer, natural-architecture, surface,
containment, and attestation checks in [Gate integrity](#gate-integrity).

---

## Gate integrity

`action_registry.tsv` names all five action/effect/permission/visibility/idempotence tuples. The suite builds
the production registry and compares both projections with `AuthorizationReference`, which does not import the
production module. Source checks enumerate the exact five `ActionEffect` arms and three `Permission` arms and
prove the seven witness/registry/snapshot constructors remain private.

`authorization_matrix.tsv` has two allows and four refusals, including the two required canaries. A hidden
action remains invocable when current policy allows it; an action with no policy remains denied even when it
is visible. Every refusal produces an empty effect trace. The independent evaluator reads explicit fields and
does not call the production authorization transition.

Four parity mutations retain exact `MissingAction`, `UnexpectedAction`, `DuplicateAction`, and
`ProjectionMismatch` errors. Four replay rows change exactly one of policy, membership, grant, or scope epoch
and retain distinct stale errors. QuickCheck selects those four refusal dimensions and all five effect arms at
a 5% minimum per-class floor.

The `default_allow` control must turn the absent-policy row red at `default-deny`. The
`visibility_is_authorization` control must turn the hidden-allow and stale-visible decisions red at
`hidden-invocable+stale`. The subject matches its oracle before mutation, each mutant runs in a separate
process, and a generic non-zero exit does not satisfy the locus check.

The artifact, budget, lift, workflow, and evidence components carry the `5,6,8,9,2`
registry/decision/refusal/property/mutant counts and compose to resource vector `5,30,0,0`. Normal and
network-denied executions must both report the calculus and authorization tokens. Generated records remain
beneath `.build/**`.

Passing proves the pure closed authorization relation for this bounded corpus. Identity-provider truth,
HTTP/server enforcement, live policy updates, and provider-side tenant isolation remain UNVERIFIED.

- **Extension conformance (§M.13).** Not applicable: this phase declares no extension and consumes no linked
  extension set. Its authorization boundary follows the security-law shape, but it mints no Phase-24
  extension-conformance verdict.

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6):
  claimed identity, request scope, exact permissions, and current authority remain distinct inputs.
- [`low_code_ui_runtime_doctrine.md` §8 — effects are typed ports, not network operations](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations):
  the registry owns action/effect meaning and the interpreter consumes only authorization evidence.
- [`low_code_ui_runtime_doctrine.md` §9 — routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge):
  presentation never grants authority and stale decisions cannot execute.
- [`illegal_state_security.md` §3.79 — a UI action whose server authorization does not match its declaration](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration):
  default-deny and visibility independence remain explicit negative controls.

---

## Sprints

## Sprint 38.1: Sealed registry and parity ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Security/Authorization.hs`, `test/fixture/ui_authorization/{action_registry,decode_errors}.tsv`, `test/spec/ui/AuthorizationReference.hs`
**Blocked by**: [Phase 37](phase_37_ui_program_schema.md) gate
**Independent Validation**: five exact declarations produce equal client/server/reference projections and four one-dimension registry defects retain distinct errors
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/illegal_state/illegal_state_security.md`

### Objective

Adopt one closed action registry as the source for presentation, server dispatch, permission, and audit
identity.

### Deliverables

- Five closed action/effect declarations and three closed permission arms.
- Seven private identifiers, registries, snapshots, actions, and witnesses.
- Equal client/server projections and four exact registry-parity refusals.

### Validation

1. Both production projections equal the independently parsed five-row table.
2. Missing, extra, duplicate, and swapped-permission registries fail distinctly.
3. Closed-union and constructor-export scans match every owned type.

### Remaining Work

None.

## Sprint 38.2: Current-authority decision and negative controls ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Security/Authorization.hs`, `test/fixture/ui_authorization/{authorization_matrix,stale_decision_cases}.tsv`, `test/spec/ui/AuthorizationSpec.hs`, `test/mutant/ui_authorization/**`
**Blocked by**: Sprint 38.1
**Independent Validation**: six decisions and four single-epoch replays match an independent evaluator with empty denial traces; nine generated classes and two paired mutants pass
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/testing_doctrine.md`, `documents/illegal_state/illegal_state_security.md`

### Objective

Adopt one current-authority transition whose successful result is the only representable input to the effect
interpreter.

### Deliverables

- A total authorization transition over registry, policy, scope, owner, permission, and four epochs.
- Hidden-but-invocable and visible-but-unauthorized canaries plus empty denial traces.
- Nine generated coverage classes and two paired semantic mutants.

### Validation

1. All six matrix decisions agree with the independent evaluator and pinned verdict.
2. Each single-epoch replay fails with its own constructor before an effect is recorded.
3. Both mutants redden at their exact authored loci.

### Remaining Work

None.

## Sprint 38.3: Calculus projection and phase seal ✅

**Status**: Done
**Implementation**: `test/oracle/ui_authorization/{calculus_projection,validation_locus}.tsv`, `test/oracle/ui_authorization_surfaces.tsv`, `tools/ui_authorization_gate.py`
**Blocked by**: Sprint 38.2
**Independent Validation**: the real five-calculus values match all four projection rows and normal/network-denied suite executions report both acceptance tokens
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective

Seal the pure authorization claim with current calculus, architecture, surface, containment, and attestation
evidence.

### Deliverables

- A real five-calculus composition over the phase's bounded sets.
- Linux and Darwin network-denial observers plus a natural-architecture declaration.
- A complete surface/ledger join with live identity/provider residues retained as UNVERIFIED.

### Validation

1. Calculus order, names, counts, and resource vector match the authored table.
2. Normal and isolated runs pass and both explicit mutant processes fail exactly.
3. All universal gate sides pass without changing an authored path.

### Remaining Work

None.

---

## Documentation Requirements

**Engineering docs to update when the gate seals:**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record pure registry/current-authority evidence
  without claiming live enforcement.
- `documents/illegal_state/illegal_state_security.md` — attach the exact default-deny, visibility, and stale
  controls.
- `documents/engineering/testing_doctrine.md` — record the independent authorization-reference pattern.

**Cross-references to update:**

- `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`, and
  `DEVELOPMENT_PLAN/system_components.md` — record the seal and honest live residues.

---

## Related Documents

- [Development Plan Tracker](README.md) — phase order and current status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, register honesty, and gate integrity.
- [Phase 8](phase_08_scope_index.md) — trusted scoped identity.
- [Phase 10](phase_10_calculus_composition.md) — five-calculus composition.
- [Phase 37](phase_37_ui_program_schema.md) — checked program admission.
- [Low-Code UI Runtime Doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md) — action ownership and authorization freshness.
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — independent authored expectations.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — authorization-parity and visibility-bypass failures.
