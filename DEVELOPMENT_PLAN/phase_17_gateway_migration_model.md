# Phase 17: Gateway-migration model (both branches)

> **Purpose**: Specify the target Haskell capability to express the planned and failover
> gateway-migration branches as one Haskell model and compare bounded semantic, explorer, and
> simulation readings, with every foreign model-checker product generated only beneath `.build/**`.
> **Read this if**: the cross-cluster gateway protocol, its proof boundary, or its per-spec cutoff must be
> changed or checked.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot satisfy a gate through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/gateway_migration_model_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 17.1: Concrete model, semantic renderer, and calculus projection](#sprint-171-concrete-model-semantic-renderer-and-calculus-projection-)
- [Sprint 17.2: Explorer and TLC proof battery](#sprint-172-explorer-and-tlc-proof-battery-)
- [Sprint 17.3: Historical schedule/cutoff gate work](#sprint-173-schedule-agreement-structural-cutoff-and-sealed-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done.

Phase 16 has a durable passing receipt for the current source lineage. The Phase-17 implementation and
compiled semantic contract are bound below, but no completion claim exists until the exact integrated gate
passes and authorizes the mechanical status projection.

> **Reset contract interpretation.** The phase-specific gate check below is UNRESOLVED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and the complete qualified gate passes, the summary and work breakdown are a capability inventory, not an executable contract. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is historical and non-operative.

## Phase Summary

This phase has a bound Haskell implementation but does not report a passing result until its complete gate
runs. It expresses the planned and failover gateway-migration branches as one Haskell model and compares
bounded semantic, explorer, TLC, and simulation readings, with every foreign model-checker product generated
only beneath `.build/**`.

The production subject, behavioral controls, independent oracle, fixtures, and mutants must be authored as
`.hs`. Except for the `pb/**` bootstrap, no non-`.hs` behavioral source, fixture, oracle, or mutant may be
tracked. Any foreign representation, rendered specification, compiler transcript, suite manifest, generated
code, or other derived product must be created lazily beneath `.build/**` and remain run-scoped evidence only.
`pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec that exact Haskell verdict binary with argv unchanged. Before `BOOTSTRAP_HANDOFF`, the
bound gate invokes the exact source-bound Haskell validator directly.

This phase precedes Phase 49 and is confined to pure, build, compiler, or model-level Register-1
behavior only. It cannot use host, hardware, live-service, or cluster observations to make its claim pass.

**Phase scope:** Bound capability — express the planned and failover gateway-migration branches as one
Haskell model and compare bounded semantic, explorer, TLC, and simulation readings, with every foreign
model-checker product generated only beneath `.build/**`. NOT VALIDATED.

**Substrate:** `none` — pre-Phase-49; no host, hardware, live service, or cluster observation.

**Lane:** `none`.

**Register:** 1 — Haskell-only pure/build/model target. NOT VALIDATED.

**Depends on:** [Phase 16](phase_16_deterministic_sim_substrate.md)
**Gate:** `pb validate phase 17`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: BOUND — NOT VALIDATED. The compiled Phase-17 semantic payload, package-hidden serial
supervisor, pure model and structural-fit subject, independently authored Haskell oracle, digest-pinned
offline JVM/TLC inputs, and three changed-production subjects are complete; only a fresh integrated run may
authorize status.

| Key | Contract |
|---|---|
| `Claim` | One reifiable Haskell `GatewayMigration` model expresses planned and failover branches; the in-process explorer, generated TLC projection, bounded `IOSimPOR` reading, and total structural-fit fold agree within the declared finite envelope. |
| `Subject` | `Amoebius.Formal.GatewayMigration` and `Amoebius.Multicluster.StructuralFit` are acquired only through package-hidden `Amoebius.Validation.GatewayMigrationModelRun.Internal`. |
| `Command` | Future public spelling is `pb validate phase 17`; before `BOOTSTRAP_HANDOFF`, the exact source-bound Haskell executable invokes absolute Cabal 3.16.1.0 and authenticated GHC 9.12.4 directly, offline, serially, with digest-pinned Java 21.0.9 and TLA+ 1.8.0 inputs. |
| `Oracle` | `GatewayMigrationOracle.hs` independently authors model constants/actions/obligations, twelve renderer facts, calculus facts, five invariant mutations, eleven cutoff cases, and eight cutoff deletions as Haskell values. |
| `Positive controls` | Exactly 53 explorer/TLC states agree; five safety invariants and three fair liveness properties pass; all twenty actions and both branches are reachable; IOSimPOR bound 20, the calculus projection, and shared-resource model are green. |
| `Paired negatives` | Five exact invariant mutants, five mechanical safety mutants, three fairness deletions, eight structural-fit deletions, two renderer mutations, and the dual-owner stress model establish minimally different red boundaries. |
| `Mutants` | CPP-selected ownership-fence removal, cutoff-budget bypass, and fairness deletion change production loci and turn the full suite red at their exact independent-oracle loci. |
| `Discovery` | The two production modules and three Haskell oracle/harness modules equal the fixed five-file Phase-17 inventory bidirectionally. |
| `Challenge` | All three compiled production mutations run before the clean candidate and must be distinguished at explorer safety, cutoff rejection, and renderer fairness. |
| `Observer` | The supervisor records absolute executable, argv, exit, stdout/stderr, and transcript digest for Cabal/JVM/TLC identity probes, all mutants, and the clean process. |
| `Authority/bypass` | `pb`, PATH discovery, gate-time network, host/hardware/live-service effects, external credentials, and compiler/linker overlap are forbidden; this phase owns no external resource provision. |
| `Freshness` | Every run creates a fresh `.build/runs/phase-17/work/**` root, regenerates every TLA/CFG/DOT/log/result product there, and requires equal opening/closing source identities. |
| `Qualification` | Exact tool digests, three production-mutant deaths, closed source inventory, source discipline, Haskell oracle controls, generated-product inventory, and legacy closure qualify the harness. |
| `Cleanroom` | Cabal products, copied source-repository cache, rendered foreign products, logs, and results stay below the fresh run root; shared package/JVM/TLC stores are read-only authenticated inputs. |
| `Legacy closure` | The Python Phase-17 gate and all eight serialized gateway contract/surface/oracle manifests are absent. |
| `Predecessor` | Consume exactly one durable Phase-16 receipt for this opening source; absent, stale, replayed, malformed, or ambiguous receipts refuse. |
| `Residue` | Runtime fidelity remains `UNVERIFIED`; the decomposition lemma remains `OPEN`; live gateway effects remain Phase-75-owned. |
| `Pass criterion` | `qualified-phase-seventeen-gate-pass`: all eighteen rows are execution-derived green in one stable-source candidate with exact predecessor and empty mandatory residue. |

## Doctrine adopted

- [`gateway_migration_model_doctrine.md` §3 — The `Model`](../documents/engineering/gateway_migration_model_doctrine.md#3-the-model): both branches are one reifiable value with named safety and liveness obligations.
- [`gateway_migration_model_doctrine.md` §4 — Simulate and prove](../documents/engineering/gateway_migration_model_doctrine.md#4-simulate-and-prove): explorer, TLC, and bounded schedule readings have distinct scopes.
- [`gateway_migration_model_doctrine.md` §5 — One-and-done, plus a per-`InForceSpec` structural fit](../documents/engineering/gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit): decode-time structural fit transfers only the admitted bounded envelope.
- [`formal_model_doctrine.md` §4.1 — The reference model and its semantic oracle](../documents/engineering/formal_model_doctrine.md#41-the-reference-model-and-its-semantic-oracle): semantic renderer facts replace generated-output snapshots.
- [`formal_model_doctrine.md` §6 — What a green model-check proves, and what it does not](../documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not): only a future independently accepted bounded result could support the bounded model claim; no current result or runtime-fidelity claim exists.

## Sprints

> **Reset validation check.** Every pre-reset `Independent Validation` and `### Validation` below is historical context rather than a current criterion. It is retained only to inventory the capability while the fixed Haskell subject/oracle/mutant/legacy contract is rewritten.

## Sprint 17.1: Concrete model, semantic renderer, and calculus projection ✅

**Status**: Done
**Implementation**: `src/Amoebius/Formal/GatewayMigration.hs`, `test/spec/formal/gateway/{GatewayMigrationSpec,GatewayMigrationOracle}.hs`, and `test/harness/deterministic_simulation/CalculusProjection.hs`
**Blocked by**: [Phase 16](phase_16_deterministic_sim_substrate.md) gate pass
**Independent Validation**: structural problems empty, exact 53-state exploration, twelve semantic renderer facts, two renderer mutants, and exact five-calculus projection
**Oracle**: the separately authored values in `GatewayMigrationOracle.hs`; production never reads rendered or documented expectations
**Legacy IDs**: none; the retired Python gate and serialized model-oracle files are checked absent directly
**Docs to update**: this phase file, `gateway_migration_model_doctrine.md`, `formal_model_doctrine.md`, and `system_components.md`

### Objective

Make the gateway protocol and every formal input it consumes one inspectable semantic value rather than a
hand-maintained TLA+ source or generated byte fixture.

### Deliverables

- One structurally valid `GatewayMigration` `Model` containing both branches and all named obligations.
- A separately authored Haskell semantic-fact oracle; generated TLA+/CFG output exists only beneath `.build/**`.
- Focused harness adapter from the actual Phase-10 composition to Phase 11's `compositionModel`.

### Validation

1. Require exact constants, action names, invariants, properties, and the 53-state expectation.
2. Compare the twelve semantic renderer rows in both directions and redden two meaning-changing mutations.
3. Require exact calculus kinds, count, resource totals, and one-state formal safety result.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 17.2: Explorer and TLC proof battery ✅

**Status**: Done
**Implementation**: `Amoebius.Formal.{GatewayMigration,Explore,EmitTLA}` plus the Phase-17 Haskell oracle and digest-pinned run-scoped TLC invocation
**Blocked by**: Sprint 17.1
**Independent Validation**: explorer/TLC fingerprint equality, five exact invariant deaths, five mechanical deaths, three fairness deaths, and complete action/antecedent reachability
**Oracle**: `GatewayMigrationOracle.hs` names the independent obligations; explorer and TLC provide distinct semantic readings
**Legacy IDs**: none; handwritten TLA/CFG and serialized model contracts are forbidden and checked absent
**Docs to update**: this phase file, `gateway_migration_model_doctrine.md`, `formal_model_doctrine.md`, and `system_components.md`

### Objective

Establish the bounded safety and liveness claims and demonstrate that every named obligation is reachable and
load-bearing.

### Deliverables

- Exact explorer/TLC agreement over 53 reachable states.
- Five safety invariants green and three temporal properties green under weak fairness.
- Five exact invariant mutants, five mechanical safety mutants, and three fairness-drop mutants red.

### Validation

1. Require every action, both branches, and each antecedent-bearing safety path to be reachable.
2. Compare explorer and TLC fingerprint sets and exact state counts.
3. Require every invariant mutant to violate exactly its authored invariant, every mechanical mutant to
   violate safety, and every fairness deletion to invalidate its temporal property.

### Remaining Work

The pre-reset record said `None`; that statement cannot support a gate pass. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor gate pass, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 17.3: Schedule agreement, structural cutoff, and sealed gate ✅

**Status**: Done
**Implementation**: `src/Amoebius/Multicluster/StructuralFit.hs`, the IOSimPOR/cutoff/stress sections of `GatewayMigrationSpec.hs`, and package-hidden `GatewayMigrationModelRun.Internal`
**Blocked by**: Sprint 17.2
**Independent Validation**: IOSimPOR safety agreement, eleven cutoff cases, 500 covered equivalence cases, 500 totality cases, eight clause deletions, shared-resource correct/mutant pair, and three compiled production mutants
**Oracle**: Haskell cutoff and production-mutant expectations, independently bound to exact rejection loci by the supervisor
**Legacy IDs**: none; the eight retired Phase-17 behavioral files are enumerated and checked absent
**Docs to update**: this phase file, `gateway_migration_model_doctrine.md`, `formal_model_doctrine.md`, and `system_components.md`

### Objective

Bound the schedule claim, enforce the per-spec proof envelope without running TLC at decode time, and package
the result as a source-bound phase-gate result.

### Deliverables

- Safety agreement inside an explicit `IOSimPOR` schedule bound of 20.
- Total structural-fit fold and independent equivalence predicate over all eight envelope clauses.
- Green scope-3 shared-resource model, red dual-owner mutant, and honestly OPEN decomposition lemma.
- Fourteen exact metrics, 17-surface/19-item join, containment, write guard, ledger, and exact run binding.

### Validation

1. Require bounded simulated safety agreement for the correct model and red invariant mutants.
2. Run the exact cutoff corpus, 500 covered equivalence cases, 500 totality cases, and all eight deletion
   mutations.
3. Require every shared-resource action reachable, the correct stress model green, and its mutant red.
4. Run the ten-sided gate on the natural architecture and bind its evidence to the complete source snapshot.

### Remaining Work

The pre-reset `None` claim is permanently invalid; the phase remains blocked and NOT VALIDATED. Runtime fidelity is UNVERIFIED and the decomposition lemma remains OPEN by design.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `gateway_migration_model_doctrine.md` — record the current semantic renderer and actual-calculus projection,
  and preserve the bounded proof/runtime distinction.
- `formal_model_doctrine.md` — record the concrete Phase-17 use of the semantic renderer rule and formal
  composition bridge.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md`, `overview.md`, and `system_components.md` — reconcile order, evidence, and
  implementation paths; update the reader-facing `legacy_tracking_for_deletion.md` explanation only after the
  corresponding typed Haskell byte-expectation and pre-rebaseline-body bindings close.

## Related Documents

- [Development Plan Tracker](README.md) — numeric order and current phase status.
- [Development Plan Standards](development_plan_standards.md) — phase shape, honesty, and artifact rules.
- [Architecture Overview](overview.md) — the verification-band role of this phase.
- [Phase 11](phase_11_formal_model_kernel.md) — the formal kernel and `compositionModel` projection.
- [Phase 16](phase_16_deterministic_sim_substrate.md) — deterministic schedule and harness substrate.
- [Canonical Phase Model](development_plan_phase_model.md) — status and reopening semantics.
- [Gate Integrity Standard](development_plan_gate_integrity.md) — oracle, mutation, and generated-artifact rules.
- [Gateway Migration Model Doctrine](../documents/engineering/gateway_migration_model_doctrine.md) — protocol, cutoff, and honesty owner.
- [Formal Model Doctrine](../documents/engineering/formal_model_doctrine.md) — model, renderer, and proof-semantics owner.
- [Backup and Recovery Doctrine](../documents/engineering/backup_recovery_doctrine.md) — cold-seed freshness boundary.
- [Chaos and Failover Doctrine](../documents/engineering/chaos_failover_doctrine.md) — model/simulate/inject evidence ladder.
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — Register-1 boundary.
- [Daemon Topology Doctrine](../documents/engineering/daemon_topology_doctrine.md) — delegated single-instance authority.
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — transient TLA+/CFG policy.
- [Illegal Multicluster States](../documents/illegal_state/illegal_state_multicluster.md) — rejected gateway graph states.
