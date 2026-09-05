# Phase 38: UI authorization kernel

> **Purpose**: Make one sealed action registry and current-authority transition decide whether a scoped UI
> action may produce an effect.
> **Read this if**: action declarations, client/server projection parity, authorization freshness, or the
> `AuthorizedAction` boundary has to change.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 38.1: Sealed registry and parity](#sprint-381-sealed-registry-and-parity-)
- [Sprint 38.2: Current-authority decision and negative controls](#sprint-382-current-authority-decision-and-negative-controls-)
- [Sprint 38.3: Calculus projection and phase seal](#sprint-383-calculus-projection-and-phase-seal-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Blocked by redesigned Phase 37, its independent validation, and gate pass; every earlier
gate barrier must also be satisfied in numerical order. Every earlier completion claim and implementation result in this document is historical rather than a current gate result, even
where the surrounding prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

---

## Phase Summary

**Target capability — NOT VALIDATED.** Five Haskell `ActionSpec` values are to form a sealed
`BoundActionRegistry`. Each action fixes its closed effect arm,
permission, presentation visibility, and idempotence bit. Client and server projections come from that same
registry and must match a separately authored Haskell projection. Missing, unexpected, duplicate, and
equal-cardinality permission-swapped registries retain distinct refusal constructors. Any serialized case or
mutation is generated lazily beneath `.build/**`.

The target authorization function combines the sealed registry, a scoped request context, subject/tenant ownership, requested
permission, and an `AuthoritySnapshot`. The snapshot and presented authority must agree on policy,
membership, grant, and scope epochs. Only a current, matching decision creates private `CanRead`/`CanInvoke`
witnesses inside a constructor-private `AuthorizedAction`; the pure effect interpreter accepts no weaker
input. Client visibility never enters the authorization predicate.

**Phase scope:** one target claim — presentation, client/server declaration, modeled current policy, request scope,
and effect admission have one pure decision boundary. Live identity truth, HTTP routing, handler binding,
provider policy, or tenant-isolation observation splits out.

**Substrate:** `none` — registry construction, reference evaluation, Haskell properties, epoch replay, and
calculus composition are pure; the canonical Haskell gate has no credentials or network
([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Lane:** `none` ([§L](development_plan_phase_model.md#l-one-substrate-discipline)).

**Register:** 1 — pure Haskell/generative: separately authored Haskell rows and paired controls constrain the decision
relation; identity-provider truth and runtime/provider enforcement remain UNVERIFIED
([§K](development_plan_phase_model.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 37](phase_37_ui_program_schema.md)
**Gate:** `pb validate phase 38`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `pure-sealed-ui-authorization-kernel` |
| `Subject` | `acquired-ui-authorization-supervisor` |
| `Command` | `pb validate phase 38` (future public spelling); the pre-handoff gate directly executes the exact source-bound Haskell supervisor and its offline serial matrix. |
| `Oracle` | `independent-ui-authorization-oracle` |
| `Positive controls` | `ui-authorization-positive-controls` |
| `Paired negatives` | `exact-ui-authorization-paired-negatives` |
| `Mutants` | `applied-ui-authorization-production-mutants` |
| `Discovery` | `exact-ui-authorization-source-discovery` |
| `Challenge` | `post-acquisition-ui-authorization-challenge` |
| `Observer` | `ui-authorization-process-observation` |
| `Authority/bypass` | `no-pb-network-identity-provider-host-hardware-or-parallelism` |
| `Freshness` | `fresh-ui-authorization-build-root-and-stable-source` |
| `Qualification` | `qualified-ui-authorization-harness` |
| `Cleanroom` | `ui-authorization-products-contained-below-build` |
| `Legacy closure` | `retired-ui-authorization-authorities-absent` |
| `Predecessor` | `exact-phase-thirty-seven-receipt` |
| `Residue` | `ui-effect-runtime-and-provider-owners-explicit` |
| `Pass criterion` | `qualified-phase-thirty-eight-gate-pass` |

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6):
  claimed identity, request scope, exact permissions, and current authority remain distinct inputs.
- [`low_code_ui_runtime_doctrine.md` §8 — Effects are typed ports, not network operations](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations):
  the registry owns action/effect meaning and the interpreter consumes only authorization evidence.
- [`low_code_ui_runtime_doctrine.md` §9 — Routes, identity, authorization, and the edge](../documents/engineering/low_code_ui_runtime_doctrine.md#9-routes-identity-authorization-and-the-edge):
  presentation never grants authority and stale decisions cannot execute.
- [`illegal_state_security.md` §3.79 — A UI action whose server authorization does not match its declaration](../documents/illegal_state/illegal_state_security.md#379-a-ui-action-whose-server-authorization-does-not-match-its-declaration):
  default-deny and visibility independence remain explicit negative controls.

---

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 38.1: Sealed registry and parity ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Security/Authorization.hs`, `test/spec/ui/{AuthorizationCases,AuthorizationSpec,AuthorizationOracle}.hs`, and the package-hidden Phase-38 supervisor own this sprint surface.
**Blocked by**: [Phase 37](phase_37_ui_program_schema.md) gate pass
**Independent Validation**: one clean Haskell semantic suite and two production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/ui/AuthorizationOracle.hs` independently fixes five registry rows, six decisions, four parity refusals, four epoch refusals, four calculus rows, two mutant loci, and thirty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, seven serialized oracle/fixture tables, two materialized mutant descriptors, and the retired test-local evaluator.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked UI/security/testing doctrines.

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

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 38.2: Current-authority decision and negative controls ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Security/Authorization.hs`, `test/spec/ui/{AuthorizationCases,AuthorizationSpec,AuthorizationOracle}.hs`, and the package-hidden Phase-38 supervisor own this sprint surface.
**Blocked by**: Sprint 38.1
**Independent Validation**: one clean Haskell semantic suite and two production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/ui/AuthorizationOracle.hs` independently fixes five registry rows, six decisions, four parity refusals, four epoch refusals, four calculus rows, two mutant loci, and thirty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, seven serialized oracle/fixture tables, two materialized mutant descriptors, and the retired test-local evaluator.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked UI/security/testing doctrines.

### Objective

Adopt one current-authority transition whose successful result is the only representable input to the effect
interpreter.

### Deliverables

- A total authorization transition over registry, policy, scope, owner, permission, and four epochs.
- Hidden-but-invocable and visible-but-unauthorized canaries plus empty denial traces.
- Nine generated coverage classes and two paired Haskell semantic changed-subject mutants.

### Validation

1. All six matrix decisions agree with the independent evaluator and pinned verdict.
2. Each single-epoch replay fails with its own constructor before an effect is recorded.
3. Both Haskell changed-subject mutants redden at their exact authored loci.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 38.3: Calculus projection and phase seal ✅

**Status**: Done
**Implementation**: `src/Amoebius/Ui/Security/Authorization.hs`, `test/spec/ui/{AuthorizationCases,AuthorizationSpec,AuthorizationOracle}.hs`, and the package-hidden Phase-38 supervisor own this sprint surface.
**Blocked by**: Sprint 38.2
**Independent Validation**: one clean Haskell semantic suite and two production CPP mutations execute serially from one acquired fresh build root.
**Oracle**: `test/spec/ui/AuthorizationOracle.hs` independently fixes five registry rows, six decisions, four parity refusals, four epoch refusals, four calculus rows, two mutant loci, and thirty validation loci without importing production.
**Legacy IDs**: Phase-local closure covers the retired Python gate, seven serialized oracle/fixture tables, two materialized mutant descriptors, and the retired test-local evaluator.
**Docs to update**: this phase, `system_components.md`, `substrates.md`, and the linked UI/security/testing doctrines.

### Objective

Test the pure authorization claim with current calculus, architecture, surface, containment, and exact run
observations.

### Deliverables

- A real five-calculus composition over the phase's bounded sets.
- Linux and Darwin network-denial observers plus a natural-architecture declaration.
- A complete surface/ledger join with live identity/provider residues retained as UNVERIFIED.

### Validation

1. Calculus order, names, counts, and resource vector match the authored table.
2. Normal and isolated runs accept and both explicit Haskell changed-subject mutant executions fail at their
   named loci; any external representation is generated lazily beneath `.build/**`.
3. All universal gate sides pass without changing an authored path.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

---

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — record pure registry/current-authority evidence
  without claiming live enforcement.
- `documents/illegal_state/illegal_state_security.md` — attach the exact default-deny, visibility, and stale
  controls.
- `documents/engineering/testing_doctrine.md` — record the independent authorization-reference pattern.

**Cross-references to add:**

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
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — independently authored Haskell expectations.
- [Illegal-State Security Slice](../documents/illegal_state/illegal_state_security.md) — authorization-parity and visibility-bypass failures.
