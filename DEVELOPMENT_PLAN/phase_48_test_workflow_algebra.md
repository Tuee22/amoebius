# Phase 48: The test-workflow algebra

> **Purpose**: Establish the pure Haskell test-workflow algebra: typed teardown, supplied-model suggestions,
> symbolic test authority, modeled inventory classification, and honest evidence strengths.
> **Read this if**: a test topology is being proposed, projected, or transferred to the later live harness.

This plan owns only the hardware-free decision algebra. Phase 90 owns every live test effect.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 48.1: Typed teardown workflow](#sprint-481-typed-teardown-workflow-)
- [Sprint 48.2: Pure supplied-model suggestion](#sprint-482-pure-supplied-model-suggestion-)
- [Sprint 48.3: Symbolic flagged authority](#sprint-483-symbolic-flagged-authority-)
- [Sprint 48.4: Modeled inventory classification](#sprint-484-modeled-inventory-classification-)
- [Sprint 48.5: Honest evidence and live handoff](#sprint-485-honest-evidence-and-live-handoff-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 47 and every earlier numerical predecessor are recorded Done. The complete qualified Phase-48 gate and
its exact emitted status projection remain required.

## Phase Summary

`Amoebius.Test.WorkflowAlgebra` defines a pure `TestTopology state`. `suggestTest` consumes only an explicitly
supplied model and returns a `TestTopology TeardownPending` or a structured refusal. Only `observeTeardown`
can produce `TestTopology TeardownObserved`, and only that state is accepted by `terminalResult`. The same
module owns closed resource, authority, ownership, fault, expectation, modeled-inventory, and evidence terms.
It can describe a later live run but cannot claim one happened.

Suggested topology bytes are deterministic Haskell projections written lazily under
`.build/test-corpora/test-workflow-algebra/**`. They are neither tracked source nor an oracle. Phase 48 does
not inspect a host, resolve a credential, allocate a resource, execute a workflow, inject a fault, perform a
deletion, observe inventory, or award Runtime evidence.

**Phase scope:** one target claim — pure Haskell terms enforce teardown observation before a terminal result and total, honest suggestion/inventory/evidence folds over supplied model values.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 47](phase_47_tool_and_mutant_generation.md)
**Forward-deferred:** [Phase 90](phase_90_test_topology_live.md) owns live test execution, authority resolution, allocation, teardown, inventory readback, Runtime evidence, and hardware under `phase-90-live-test-topology`.
**Gate:** `pb validate phase 48`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | `pure-test-workflow-teardown-suggestion-inventory-and-evidence-algebra` |
| `Subject` | `acquired-test-workflow-algebra-supervisor` |
| `Command` | `pb validate phase 48` (future public spelling); before Phase 50, invoke the exact source-bound Haskell executable directly for the offline serial test-workflow-algebra matrix |
| `Oracle` | `independent-test-workflow-algebra-oracle` |
| `Positive controls` | `closed-test-workflow-algebra-positive-controls` |
| `Paired negatives` | `exact-test-workflow-algebra-paired-negatives` |
| `Mutants` | `applied-test-workflow-algebra-production-mutants` |
| `Discovery` | `exact-test-workflow-algebra-source-and-projection-discovery` |
| `Challenge` | `post-acquisition-test-workflow-algebra-challenge` |
| `Observer` | `test-workflow-algebra-process-and-filesystem-observation` |
| `Authority/bypass` | `no-pb-network-live-provider-host-hardware-or-parallelism` |
| `Freshness` | `fresh-test-workflow-algebra-run-and-stable-source` |
| `Qualification` | `qualified-test-workflow-algebra-harness` |
| `Cleanroom` | `test-workflow-algebra-products-contained-below-build` |
| `Legacy closure` | `no-phase-forty-eight-legacy-authorities` |
| `Predecessor` | `exact-phase-forty-seven-receipt` |
| `Residue` | `live-test-execution-teardown-inventory-runtime-evidence-and-hardware-owners-explicit` |
| `Pass criterion` | `qualified-phase-forty-eight-gate-pass` |

The future public spelling is `pb validate phase 48`. Before Phase 50 passes, validation invokes the exact
source-bound Haskell executable directly. Its acquired supervisor runs every compiler-bearing row serially,
offline, with `--jobs=1` and the pinned compiler/store.

## Doctrine adopted

- [`testing_doctrine.md` §3](../documents/engineering/testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down) — the pure state transition makes teardown observation mandatory; execution stays deferred.
- [`testing_doctrine.md` §5](../documents/engineering/testing_doctrine.md#5-suggest-test-detect-the-world-emit-a-representative-test-dhall) — Phase 48 accepts supplied model values and emits only a generated proposal.
- [`testing_doctrine.md` §6](../documents/engineering/testing_doctrine.md#6-flagged-test-credentials) — authority is a symbolic name and must be explicitly flagged for testing.
- [`testing_doctrine.md` §7](../documents/engineering/testing_doctrine.md#7-the-elevated-harness-is-the-sole-automated-deleter-of-test-owned-durable-storage-leak-free-cycles) — deletion and external residue observation remain Phase-90 effects.
- [`chaos_failover_doctrine.md` §12](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed) — pure evidence cannot upgrade a future Runtime move.

## Sprints

## Sprint 48.1: Typed teardown workflow ✅

**Status**: Done
**Implementation**: `src/test-workflow-algebra/Amoebius/Test/WorkflowAlgebra.hs`, `test/negative/test_workflow_algebra/legal_teardown.hs`, and `test/negative/test_workflow_algebra/missing_teardown.hs`
**Blocked by**: [Phase 47](phase_47_tool_and_mutant_generation.md) gate pass
**Independent Validation**: six exact terminal-fold cases, the legal compiler witness, the teardown-pending compiler refusal, and three terminal/teardown changed-production subjects.
**Oracle**: `test/spec/workflow/TestWorkflowAlgebraOracle.hs`, which imports no production module.
**Legacy IDs**: none
**Docs to update**: `documents/engineering/testing_doctrine.md`

### Objective

Make a terminal result unconstructible until a teardown outcome has been supplied, while preserving the
primary workflow failure when workflow and cleanup both fail.

### Deliverables

- Phantom `TeardownPending` and `TeardownObserved` states.
- `observeTeardown` as the only state transition to the terminal-input state.
- Total terminal results for success, primary failure, cleanup failure, and repeated teardown.
- Legal and minimally different illegal compiler witnesses.

### Validation

The legal witness compiles; the missing-teardown witness is rejected with both phantom-state names. The
independent six-row terminal oracle covers the complete two-by-three outcome product. Optional-teardown,
cleanup-success, and primary-replacement mutants each turn red at a distinct production locus.

### Remaining Work

Run the complete integrated gate. Live execution and teardown remain Phase-90 work.

## Sprint 48.2: Pure supplied-model suggestion ✅

**Status**: Done
**Implementation**: `src/test-workflow-algebra/Amoebius/Test/WorkflowAlgebra.hs` and `test/spec/workflow/TestWorkflowAlgebraSpec.hs`
**Blocked by**: Sprint 48.1
**Independent Validation**: exact-fit and one-short comparisons over five branches and all nine resource axes.
**Oracle**: `test/spec/workflow/TestWorkflowAlgebraOracle.hs`
**Legacy IDs**: none
**Docs to update**: `documents/engineering/resource_capacity_doctrine.md`

### Objective

Compute a representative topology solely from a supplied Haskell model, without discovery or live claims.

### Deliverables

- Five closed branches and nine-axis demand vectors.
- Pure `suggestTest` exact-fit acceptance and structured one-short refusal.
- Deterministic content-addressed proposal paths and bytes below `.build/test-corpora/**`.

### Validation

The independent oracle restates every branch demand. Every axis is shortened by exactly one from an accepted
case. A provider-debit mutant is killed. Two independently executed projection writes yield identical bytes.

### Remaining Work

Run the complete integrated gate. Host, quota, and provider observation remain Phase-90 work.

## Sprint 48.3: Symbolic flagged authority ✅

**Status**: Done
**Implementation**: `src/test-workflow-algebra/Amoebius/Test/WorkflowAlgebra.hs`
**Blocked by**: Sprint 48.2
**Independent Validation**: flagged/ordinary and test-owned/ordinary/missing pairs plus inline-secret refusals.
**Oracle**: `test/spec/workflow/TestWorkflowAlgebraOracle.hs`
**Legacy IDs**: none
**Docs to update**: `documents/engineering/testing_doctrine.md`, `documents/engineering/pulumi_iac_doctrine.md`

### Objective

Represent test authority and ownership intent without credentials, permissions, or destructive operations.

### Deliverables

- Closed `AuthorityIntent` and `OwnershipIntent` terms.
- Symbolic `AuthorityRef` validation that rejects secret-like inline material.
- Test-owned output enforced by the suggestion fold.

### Validation

Minimally different authority and ownership pairs reach exact refusal constructors. The inline-secret mutant
turns red without contacting any credential store.

### Remaining Work

Run the complete integrated gate. Credential resolution and permission checks remain Phase-90 work.

## Sprint 48.4: Modeled inventory classification ✅

**Status**: Done
**Implementation**: `src/test-workflow-algebra/Amoebius/Test/WorkflowAlgebra.hs`
**Blocked by**: Sprint 48.3
**Independent Validation**: exact five-domain discovery, retained/post-only pairs, and incomplete-domain refusal.
**Oracle**: `test/spec/workflow/TestWorkflowAlgebraOracle.hs`
**Legacy IDs**: none
**Docs to update**: `documents/engineering/storage_lifecycle_doctrine.md`

### Objective

Classify supplied before/after inventory models without representing them as authenticated observation.

### Deliverables

- Five closed modeled inventory domains.
- Total classification of clean, incomplete-domain, and post-only-residue cases.
- No deletion operation or external collector.

### Validation

Constructor discovery equals the independent domain list in both directions. Retained and post-only cases
differ by one modeled resource. The dropped-domain mutant turns incomplete coverage red.

### Remaining Work

Run the complete integrated gate. External inventory readback and deletion remain Phase-90 work.

## Sprint 48.5: Honest evidence and live handoff ✅

**Status**: Done
**Implementation**: `src/test-workflow-algebra/Amoebius/Test/WorkflowAlgebra.hs` and `src/validation-kernel/Amoebius/Validation/TestWorkflowAlgebraRun/Internal.hs`
**Blocked by**: Sprint 48.4
**Independent Validation**: exact Extract/Model/Inject move derivation and Runtime-unverified strengths.
**Oracle**: `test/spec/workflow/TestWorkflowAlgebraOracle.hs`
**Legacy IDs**: none
**Docs to update**: `documents/engineering/chaos_failover_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`, `DEVELOPMENT_PLAN/substrates.md`

### Objective

Derive evidence applicability from declared fault intent and keep every unperformed Runtime move unverified.

### Deliverables

- Closed Extract, Model, and fault-specific Inject moves.
- Pure/Model strengths distinct from `RuntimeUnverified`.
- Exact Phase-90 forward handoff and zero live effects in the Phase-48 runner.

### Validation

Complete fault discovery produces the exact move set. The runtime-upgrade mutant turns red. Process receipts,
source discovery, generated-output discovery, stable source, and authority boundaries qualify the whole gate.

### Remaining Work

Run the complete integrated gate. Phase 90 owns live preflight, allocation, execution, fault injection,
teardown, inventory observation, and Runtime evidence.

## Documentation Requirements

After the complete gate passes, record the pure algebra and Phase-90 boundary in testing, capacity, storage,
Pulumi, and chaos/failover doctrine. Add the Decision-layer component to `system_components.md` and retain
Phase 48 at `none`/`none` in `substrates.md`.

## Related Documents

- [Development Plan](README.md)
- [Development-plan overview](overview.md)
- [Development-plan standards](development_plan_standards.md)
- [System components](system_components.md)
- [Phase 69 — Content-store workflow](phase_69_content_store_workflow.md)
- [Phase 75 — Gateway migration drills](phase_75_gateway_migration_drills.md)
- [Phase 79 — Provider-dynamic nodes](phase_79_provider_dynamic_nodes.md)
- [Phase 90 — Live test topology](phase_90_test_topology_live.md)
- [Engineering doctrine index](../documents/engineering/README.md)
- [App-vs-deployment doctrine](../documents/engineering/app_vs_deployment_doctrine.md)
- [Chaos/failover second axis](../documents/engineering/chaos_failover_second_axis.md)
- [Daemon-topology doctrine](../documents/engineering/daemon_topology_doctrine.md)
- [JIT-artifact doctrine](../documents/engineering/jit_artifact_doctrine.md)
- [Pulumi EBS credential model](../documents/engineering/pulumi_ebs_credential_model.md)
- [Vault PKI doctrine](../documents/engineering/vault_pki_doctrine.md)
- [Testing doctrine](../documents/engineering/testing_doctrine.md)
- [Resource-capacity doctrine](../documents/engineering/resource_capacity_doctrine.md)
- [Storage-lifecycle doctrine](../documents/engineering/storage_lifecycle_doctrine.md)
- [Chaos/failover doctrine](../documents/engineering/chaos_failover_doctrine.md)
