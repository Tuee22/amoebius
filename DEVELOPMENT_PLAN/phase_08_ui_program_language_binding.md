# Phase 8: UI program language, binding, and plans

> **Purpose**: Give the bounded UI program a typed expression and update algebra, join the checked program to its effect-port binding, and compile it into paired client and server plans equal to an independent oracle.
> **Read this if**: business logic must be authored as tenant-parameterised rules rather than linked Haskell, or the UI runtime phases need to know what checked value they consume.

This phase owns the language: the typed effect-port catalog, the expression and update algebra with its
checker, the program-joined binding, and the plan compiler. It does not own the browser runtime, the UI server
boundary, local composition, or the generated bundle, which
[Phase 70](phase_70_ui_projection_runtime.md) and [Phase 72](phase_72_ui_program_release.md) own. Its
predecessor is [Phase 7](phase_07_child_clusters_obligation_teardown.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_07_child_clusters_obligation_teardown.md, DEVELOPMENT_PLAN/phase_09_dsl_barrier.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/system_components.md, documents/decision_log.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/ui_realtime_coordination_doctrine.md, documents/illegal_state/illegal_state_capability_messaging.md, documents/illegal_state/illegal_state_security.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 8.1: The typed effect-port catalog](#sprint-81-the-typed-effect-port-catalog-)
- [Sprint 8.2: The expression and update algebra](#sprint-82-the-expression-and-update-algebra-)
- [Sprint 8.3: Program-joined binding and plans](#sprint-83-program-joined-binding-and-plans-)
- [Sprint 8.4: The Phase-8 gate specification](#sprint-84-the-phase-8-gate-specification-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Gate execution is held shut by the Phase-7 predecessor receipt in certification generation 2. Hardware-free
implementation may proceed ahead of the frontier as component diagnostics under
[§O](development_plan_phase_model.md#o-sprint-sized-seams-and-bounded-phase-gates); it mints no evidence.

## Phase Summary

Phase 8 gives business logic its admissible form
([DL-0003](../documents/decision_log.md#dl-0003--business-logic-is-defined)): tenant-parameterised, total,
first-order rules over typed application state and events, expressed as `UiSource` update rules and
expressions over a closed pure-function catalog, realised through the typed effect-port catalog. The checked
program is joined to its binding — a port node in the program is a requirement the binding must satisfy —
and compiled into paired plans that an independent oracle reproduces from the approval-threshold example.

The corpus example is an approval workflow: a threshold is a tenant parameter, a submission is an event, the
update rule is total over its guard partition, and the effect it raises is a typed port bound to a trusted
handler. The `ui-server` Deployment and the program ConfigMap render on the wire through the same spine as
every other example, so the UI is a deployment fact and not a separate pipeline.

**Phase scope:** One cohesive claim — the approval-threshold program typechecks, binds, and compiles into plans equal to the oracle over every `EffectClass` arm, and renders on the wire; it splits if a browser, a server process, or a live tenant is needed to settle it.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 7](phase_07_child_clusters_obligation_teardown.md)
**Forward-deferred:** the browser runtime projection, the UI-server boundary, local composition, and the generated bundle — [Phase 70](phase_70_ui_projection_runtime.md) `ui_projection_runtime` and [Phase 72](phase_72_ui_program_release.md) `ui_program_release` / `LTD-UI-001`
**Gate:** `pb validate phase 08`; see [Gate integrity](#gate-integrity).

### Corpus

The corpus module is `Amoebius.Dsl.Examples.Ui`, which contains the Phase-7 corpus and adds at least two
distinguishing pairs:

| Example | Distinguishes | Expected delta or refusal |
|---|---|---|
| approval-threshold program | a bound program versus the same program with a changed threshold parameter | the compiled plan's guard literal changes and nothing else; the `ui-server` Deployment and ConfigMap render |
| unbound-port refusal | a program whose port has a binding versus one whose port has none | `UnboundPort` at the binding stage with the exact port name |

Refused set: non-total match (`GuardGap`), ill-typed comparison (`TypeMismatch`), unbounded list operation
(`UnboundedFuel`), unknown function (`UnknownFunction`), and `RequirementWithoutPort`. New tags: `ui`, `port`.

### Gate specification

```gate-spec
capability: ui_program_language_binding
subjects:
  - Amoebius.Ui.Effect.Catalog
  - Amoebius.Ui.Expr
  - Amoebius.Ui.Check
  - Amoebius.Ui.Bind
  - Amoebius.Ui.Plan
  - Amoebius.Dsl.Lower
suite: ui-suite
oracle: oracle-dsl
positives: [approval-threshold, approval-threshold-sibling]
negatives: [UnboundPort, RequirementWithoutPort, GuardGap, TypeMismatch, UnboundedFuel, UnknownFunction]
mutants: { perModule: 8, perGateCap: 40, killRatio: 0.6 }
binaryFact:
  command: amoebius compile
  perturbation: sentinel-to-nonce
  outputs: [client-plan, server-plan, manifest]
substrate: HardwareFree
corpus: { module: Amoebius.Dsl.Examples.Ui, minimumPairs: 2 }
```

## Gate integrity

**Contract check**: BOUND — the gate specification above is the compiled value the runner executes; the
documentation checker refuses a block that differs from it. Execution evidence remains phase-local.

| Key | Contract |
|---|---|
| `Claim` | `checkExpr`, `bindUiProgram`, and the plan compiler on the approval-threshold example produce client and server plans equal to the oracle's rows over every `EffectClass` arm; the `ui-server` Deployment and the program ConfigMap render on the wire through `amoebius compile`; the six refusals are refused by name at their stage. The browser runtime, the server process, and live tenants are excluded. |
| `Subject` | `Amoebius.Ui.Effect.Catalog`, `Amoebius.Ui.Expr`, `Amoebius.Ui.Check`, `Amoebius.Ui.Bind`, `Amoebius.Ui.Plan`, and `Amoebius.Dsl.Lower`, all inside the closure of `executable amoebius`. |
| `Command` | Future public spelling is `pb validate phase 08`, inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs `amoebius-validate preview phase 08`; then `amoebius-validate accept --phase 08` records the receipt and applies one phase's status patch. The runner spawns the shipped binary for `compile` and reads the two plans and the manifest. |
| `Oracle` | `test/oracle/dsl/Main.hs` holds the expected plans as literal rows over `[minBound..maxBound] :: [EffectClass]` — dispatch row, permission, audit class each — and depends on no `amoebius` library. |
| `Positive controls` | The approval-threshold program and its parameter sibling: plans equal to the oracle rows; the `ui-server` Deployment and ConfigMap present in the manifest with the program digest. |
| `Paired negatives` | `UnboundPort`, `RequirementWithoutPort`, `GuardGap`, `TypeMismatch`, `UnboundedFuel`, and `UnknownFunction`, each refused at its exact stage and name with the accepted twin; `Apply CmpNat` over a text value is a compile-negative twin. |
| `Mutants` | Runner-generated over the six subjects, eight per module, at most forty per gate, kill ratio at least 0.6; a mutant that drops an `EffectClass` arm from dispatch is killed by the plan comparison; a mutant that skips the guard-partition check is killed by `GuardGap`. |
| `Discovery` | The stanza module map is compared two-way with the subjects; every `EffectClass` arm has an oracle row; empty discovery refuses. |
| `Challenge` | The runner plants a nonce in the program's threshold parameter after the run starts; the nonce must appear in the server plan's guard literal and in the ConfigMap. |
| `Observer` | `ProcessObserver` over the shipped binary; plans and manifest are read from its output files. |
| `Authority/bypass` | `SUBJECT-NOT-SHIPPED` and oracle stanza hygiene as in Phase 3; no `HandlerImpl` may carry `IO`, checked by a compile-negative twin; every `PortContract` carries a non-optional `AuthPolicyRef`. |
| `Freshness` | A unique run root; a fresh render every run; the verifier digest equals the seed's. |
| `Qualification` | The generated-mutant matrix precedes the clean candidate in the same run. |
| `Cleanroom` | `.build/runs/phase-08/**`, absent afterward; the kernel ratchet is recorded. |
| `Legacy closure` | `LTD-DSL-006` closes here. `LTD-SRC-004` closes its language share here; its generated-artifact share is re-homed to Phase 72 under `LTD-UI-001`. |
| `Predecessor` | The Phase-7 receipt in certification generation 2, chained by the digest of Phase 7's product closure plus the verifier and governance digests. |
| `Residue` | Phase 9 and every phase from 50 onward remain explicit limitations; `LTD-UI-001` is visible residue until Phases 70 and 72. |
| `Pass criterion` | `qualified-gate-pass` — every row succeeds in one serial run for the exact current source, and `accept` records it. |

## Doctrine adopted

- [`app_vs_deployment_doctrine.md` §2 — the application-logic surface](../documents/engineering/app_vs_deployment_doctrine.md#2-the-application-logic-surface--what-an-app-is) — the definition of business logic.
- [`low_code_ui_runtime_doctrine.md` §3 — one checked value, two runtime plans](../documents/engineering/low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans) — the paired plans.
- [`low_code_ui_runtime_doctrine.md` §7 — state, events, and deterministic updates](../documents/engineering/low_code_ui_runtime_doctrine.md#7-state-events-and-deterministic-updates) — the update algebra.
- [`low_code_ui_runtime_doctrine.md` §8 — effects are typed ports](../documents/engineering/low_code_ui_runtime_doctrine.md#8-effects-are-typed-ports-not-network-operations) — the effect-port catalog.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the `BinaryFact` this phase carries.

## Sprints

## Sprint 8.1: The typed effect-port catalog ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/ui-core/Amoebius/Ui/Effect/Catalog.hs`
**Blocked by**: [Phase 7](phase_07_child_clusters_obligation_teardown.md) gate pass
**Independent Validation**: The closed `EffectClass` with its eleven arms, `PortContract` with a non-optional `AuthPolicyRef`, and `HandlerEntry` with a closed `HandlerImpl` are the positive control; a `HandlerImpl` carrying `IO` is a compile-negative twin; the three former effect vocabularies are absent from `src/`, checked by the hygiene row.
**Oracle**: `test/oracle/dsl/Main.hs` states the dispatch row, permission, and audit class per arm from literals.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`

### Objective

Make one typed effect-port catalog the projection every other effect vocabulary derives from.

### Deliverables

- `EffectClass`, `PortContract`, `HandlerEntry`, and `HandlerImpl`.
- `PortEffect`, `ActionEffect`, the offline operation, and the bound-handler table as projections of `EffectClass`.

### Validation

Write the projection over every arm from the suite and compare with the oracle; require the twin to fail.

### Remaining Work

Implement the catalog and delete the duplicate vocabularies.

## Sprint 8.2: The expression and update algebra ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/ui-core/Amoebius/Ui/Expr.hs` and `src/ui-core/Amoebius/Ui/Check.hs`
**Blocked by**: Sprint 8.1
**Independent Validation**: `checkExpr` accepts the approval-threshold program; `GuardGap`, `TypeMismatch`, `UnboundedFuel`, and `UnknownFunction` are refused by name; `Apply CmpNat` over a text value is a compile-negative twin; a mutant that skips the guard-partition check is killed.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected checked program encoding from literals.
**Legacy IDs**: `LTD-DSL-006` — `UiSource` has no expression or update language
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md` and `documents/engineering/app_vs_deployment_doctrine.md`

### Objective

Give `UiSource` a total, first-order, tenant-parameterised algebra with a checker.

### Deliverables

- `UiType`, `CheckedExpr (t :: UiType)` with literal, state, prop, event, parameter, field, construct, apply, and total match arms over a closed `PureFn` catalog with static fuel.
- `UpdateRule` with guard-partition totality and `TenantParamDecl`.
- `checkExpr` with the four named refusals.

### Validation

Check the example and its refused twins; compare the checked encoding with the oracle.

### Remaining Work

Implement the two modules and the compile-negative twin.

## Sprint 8.3: Program-joined binding and plans ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/ui-core/Amoebius/Ui/Bind.hs`, `src/ui-core/Amoebius/Ui/Plan.hs`, and `src/Amoebius/Dsl/Lower.hs`
**Blocked by**: Sprint 8.2
**Independent Validation**: `bindUiProgram` derives requirements from the program's port nodes and refuses `UnboundPort` and `RequirementWithoutPort` by name; the plan compiler's output equals the oracle rows over every arm; `appUi` is decoded through `decodeFrozen` and lowered so the `ui-server` Deployment and ConfigMap render on the wire.
**Oracle**: `test/oracle/dsl/Main.hs` states the expected plans and the expected manifest objects from literals.
**Legacy IDs**: `LTD-SRC-004` — language share; the generated-artifact share is `LTD-UI-001` at Phase 72
**Docs to update**: `documents/engineering/low_code_ui_runtime_doctrine.md`

### Objective

Join the checked program to its binding and to the spine.

### Deliverables

- `bindUiProgram` with port-derived requirements.
- The plan compiler over the bound program.
- `appUi` on `AppSpec`, decoded through the one front door and rendered by the spine.

### Validation

Bind and compile the example; compare plans and manifest with the oracle; refuse the two binding twins.

### Remaining Work

Implement the three edits.

## Sprint 8.4: The Phase-8 gate specification ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Ui.hs`
**Blocked by**: Sprint 8.3
**Independent Validation**: The compiled specification equals the fenced block above; `verifySpec` accepts it; the corpus contains the Phase-7 corpus and at least two new pairs.
**Oracle**: `test/oracle/runner/Main.hs` states the expected specification digest from literals.
**Legacy IDs**: none
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Author the specification the runner executes for this phase.

### Deliverables

- The Phase-8 `GateSpec` with its `BinaryFact`.

### Validation

Run `preview phase 08` and require every row green; require `accept` to record exactly one
phase's patch.

### Remaining Work

Everything above. The `accept` ends this phase.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/low_code_ui_runtime_doctrine.md` — only if the algebra or the catalog changes.
- `documents/engineering/app_vs_deployment_doctrine.md` — only if the definition of business logic changes.

**Cross-references to add:**

- Phase 7 predecessor gate pass, Phase 9 consumer link, and the Phase 70/72 forward deferral.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 7 child clusters](phase_07_child_clusters_obligation_teardown.md) — the predecessor
- [Phase 9 DSL barrier](phase_09_dsl_barrier.md) — re-runs this corpus
- [Phase 70 UI projection runtime](phase_70_ui_projection_runtime.md) — consumes the checked program
- [Phase 72 UI program release](phase_72_ui_program_release.md) — owns the generated bundle
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Low-code UI runtime doctrine](../documents/engineering/low_code_ui_runtime_doctrine.md)
- [App versus deployment doctrine](../documents/engineering/app_vs_deployment_doctrine.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
