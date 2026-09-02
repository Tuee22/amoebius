# Phase 49: No-hardware DSL gate barrier + self-referential gate suite

> **Purpose**: Re-exercise the complete Haskell DSL pipeline under separately authored oracles and qualify
> its self-referential gate representation before any host or hardware work opens.
> **Read this if**: Phase 49 is next, a later phase wants to touch a host, image, registry, cluster, GPU, or
> cloud, or a gate is represented in the workflow calculus it helps validate.

This phase owns the single gate boundary between language confidence and host work. Its future gate must
compose only the outputs of gate-passed Phases 0–48; it does not treat their old exit codes as evidence and
does not claim live-provider fidelity.
The target pipeline is defined by
[`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/workflow_calculus_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 49.1: Freeze the complete semantic surface](#sprint-491-freeze-the-complete-semantic-surface-)
- [Sprint 49.2: Compose the production pipeline](#sprint-492-compose-the-production-pipeline-)
- [Sprint 49.3: Qualify self-reference and fake apply](#sprint-493-qualify-self-reference-and-fake-apply-)
- [Sprint 49.4: Produce the documentation-gate candidate](#sprint-494-produce-the-documentation-gate-candidate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 48 and every predecessor's independent validation and gate pass. Every prior
Phase-49 completion claim or implementation result is invalidated as a current gate result. Existing
implementation is an **Observed footprint / Known partial** only.

Because this phase is `Substrate: none`, its exact typed contracts, independent oracles, and hardware-free
implementation may be prepared ahead of the validation frontier. That preparation cannot run this gate, mint
candidate evidence, consume the Phase-48 receipt, use `pb`, or touch host, image, container, cluster,
accelerator, provider, or other live state; this status remains unchanged.

---

## Phase Summary

One cleanroom Haskell run exercises the real pipeline:

```text
decode → legality → bind/expand → plan/resolve infrastructure
  → provision → renderAll → plan → dry-run → fake apply
```

Every stage must have a separately authored Haskell semantic oracle, positive controls, minimally different
specific-reason negatives, complete non-empty discovery, and changed-production-subject mutants. The final
fake apply must observe the real binary at its effect boundary with fresh challenges. Check and implementation
remain open. No container engine,
registry, image, cluster, hardware accelerator, provider credential, or network service is available to the
run.

The phase also expresses gates as workflow values, but that representation is a subject rather than the
verdict. It must agree with the independent gate kernel under the clean corpus and every qualification
sabotage. This is the first complete hardware-free universal/self-referential selector and qualification
corpus: earlier phases own finite partitions through their own typed frontier, so adding a later selector never
reopens Phase 0. The complete qualified Haskell gate pass is sufficient for the barrier to pass.

**Phase scope:** one cohesive claim — the complete Haskell-owned DSL/generator/planner pipeline and its self-referential workflow gate survive independent semantic oracles, changed-subject mutants, and harness qualification without hardware or pre-generated input. It splits if a claim requires Register 3 or a real substrate.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 48](phase_48_test_workflow_algebra.md)
**Gate:** `pb validate phase 49`; see [Gate integrity](#gate-integrity).

## Gate integrity

**Contract check**: REWRITTEN — NOT VALIDATED; independent oracle check and implementation remain open.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: From Haskell semantic source alone, the complete decode→legality→bind/expand→plan/resolve→provision→renderAll→plan→dry-run→fake-apply path produces the independently specified semantics, rejects its paired invalid cases, and routes the same contract through a qualified workflow value. `pb` transport, live fidelity, host, network, container, registry, cluster, cloud, and hardware claims are excluded. |
| `Subject` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Production entry points in `Amoebius.Dsl.Decode`, `Amoebius.Dsl.Foreclosure`, `Amoebius.Capability.Binding`, `Amoebius.Capacity.Provision`, `Amoebius.Manifest.RenderAll`, `Amoebius.Kernel.Chain`, `Amoebius.Kernel.Plan`, `Amoebius.Exec.Boundary`, and planned `Amoebius.Validation.DslBarrier`; `Amoebius.Gate.SelfReferential` is an additional subject, not the runner. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Future public target: `pb validate phase 49`. The admissible Phase-49 candidate directly invokes the exact absolute source-bound Haskell executable, built from an authenticated network-independent toolchain input, with `validate phase 49`. Invoking `pb` cannot evidence this phase because Phase 50 has not yet validated that transport. The Haskell dispatcher runs the qualified kernel, production pipeline, fake boundary, and candidate schema. |
| `Oracle` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Planned `test/Amoebius/Validation/DslBarrierOracle.hs`, separately authored from the stage implementations. Each stage exposes an independent predicate and dependency boundary. |
| `Positive controls` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: A closed Haskell corpus covers every declared DSL constructor, legality family, capability/provider/shape arm, infrastructure-plan arm, provision fold, render activation/reconcile class, plan step, dry-run rendering, and fake effect. The oracle states expected semantic facts without using production folds. |
| `Paired negatives` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Each foreclosed axis has a minimally different positive/negative pair with pinned code and locus, including decode shape, illegal state, unbound/ambiguous capability, unsatisfied demand, stale/foreign provision observation, missing render source, wrong plan dependency, dry-run effect, and fake-boundary protocol violation. |
| `Mutants` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing. This universal owner includes the complete broad validation-infrastructure families `VALIDATION_PHASE_CONTRACT_PUBLIC`, `VALIDATION_PHASE_CONTRACT_INTERNAL`, `VALIDATION_POLICY`, `VALIDATION_PHASE_SEMANTIC`, `VALIDATION_DOCUMENTATION`, and `VALIDATION_DOCUMENTATION_INTERNAL`; none is Phase-0-owned. Prior prose also requires at least one applied Haskell production mutation per pipeline stage and for self-referential routing: decoder widening, legality drop, bind arm swap, demand omission, provision identity collapse, render omission, plan reorder, dry-run execution, fake-call bypass, workflow observation skip, and teardown leak. Each changed source/binary is witnessed and reddens its named row while unrelated controls remain green. |
| `Discovery` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: The run independently derives expected surfaces from checked Haskell declarations and runtime surfaces from production entry points, joins them in both directions, and refuses zero/partial/duplicate discovery or an undeclared new arm. It cannot consume the old TSV/Python inventories. |
| `Challenge` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: Register-2 fake apply receives a post-start unpredictable challenge carried through the public plan and recovered from raw fake-boundary requests. Pure stages use separately authored predicates with gate-passed non-applicability of a live challenge. |
| `Observer` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: An external fake-boundary observer records exact absolute executable identity, argv, request bytes, order, challenge, and teardown independently of subject logs. Pure-stage oracles read returned semantic values directly. Missing, self-reported, partial, or challenge-mismatched observation fails closed. |
| `Authority/bypass` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: The corpus probes forbidden direct effect execution during decode/render/dry-run, alternate unbound providers, caller-authored identity, ambient credentials/network, cache/pre-generated fallbacks, and bypass of the workflow gate. No host or live authority is admissible. |
| `Freshness` | UNRESOLVED — blocks validation: the current run, build/cache, state, old-fixture, and generated-product roots are absent initially. The sole retained input is the exact read-only content-addressed Phase-48 receipt whose projected postimage equals the opening source. The challenge is issued after fake apply starts; independent recomputation uses a fresh content namespace and proves the production compute path ran. |
| `Qualification` | UNRESOLVED — blocks validation: this phase owns the complete hardware-free universal/self-referential corpus. The exact harness first reconciles every selector whose typed owner is at or before this barrier, then rejects constant success, no-op stage, wrong well-formed value, empty discovery, missing subject/oracle, skipped/no-op mutant, wrong-locus failure, stale evidence, self-observer, bypass, teardown leak, and smuggled generated/legacy input; only then may the clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: The snapshot contains zero source-boundary debt. Every behavioral tracked source path is `.hs` except Python under `pb/**` admitted by Phase 0's finite current-bytes check and then fully qualified by Phase 2's `VALIDATION_PB_GRAMMAR` suite and owner-level closure into the exact minimal platform-discrimination, toolchain-establishment, build, and opaque exec-handoff roles; the typed Haskell binding explained as `LTD-SRC-008` and every other `LTD-SRC-*` entry return zero. Every Dhall, manifest, fake request, serialized fixture, mutation worktree, report, and evidence bundle is generated lazily beneath one `.build/**` run root. Any remaining non-source finding joins exactly to a strictly-later typed Haskell legacy binding and is unavailable to the run. The reader-facing register is not a join input. Network, container, registry, cluster, GPU/Metal/CUDA, cloud, and condemned legacy paths are unavailable and observed unused. |
| `Legacy closure` | UNRESOLVED — blocks validation: Phase 49 owns `LTD-VAL-001` through `LTD-VAL-006`: universal qualification, phase-contract correspondence, evidence/status projection, gate completion, hardware-free barrier closure, and clean run-input closure. Those six IDs, Phase-2-owned `LTD-SRC-008`, every other source-migration ID, and every binding owned through this barrier must return zero findings under total compiled closure logic before a candidate may be emitted. The independent oracle pins the typed ID universe, owners, closures, reintroduction cases, and cumulative selector partition. Editing Markdown cannot alter the result; reintroducing foreign tracked source, widening `pb`, using image-first validation, or depending on hardware/network/container state fails the barrier. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: Exact `ImmediatePredecessorPass` for Phase 48; candidate execution refuses an absent, stale, replayed, or different-source result. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and gate evidence missing; prior prose: `UNVERIFIED`: real tool/provider fidelity; image packaging; host setup; natural-architecture execution; registry operation; cluster admission/convergence; accelerator behaviour; live security authorities; and every Phase 50+ capability. |
| `Pass criterion` | UNRESOLVED — blocks validation: typed semantic payload and complete gate execution missing; prior prose: `qualified-gate-pass` — every required gate row must succeed in one qualified run for the exact current source; that complete pass is sufficient for the status-only transition. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation may begin. The owner marker, preflight, complete
> allowed/forbidden mutations, external observer, scoped cleanup, and zero-owned-residue contract are absent.

## Doctrine adopted

- [`conformance_harness_doctrine.md` §4 — the complete spine](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply)
- [`conformance_harness_doctrine.md` §5 — the pre-hardware gate barrier](../documents/engineering/conformance_harness_doctrine.md#5-the-pre-hardware-gate-barrier)
- [`workflow_calculus_doctrine.md` §5 — the self-referential suite](../documents/engineering/workflow_calculus_doctrine.md#5-the-self-referential-suite)
- [`testing_spoof_resistance.md` §12 — spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence)
- [`evidence_calculus_doctrine.md` §4 — oracle independence](../documents/engineering/evidence_calculus_doctrine.md#4-independence-is-what-makes-a-fixture-worth-running)

## Sprints

## Sprint 49.1: Freeze the complete semantic surface ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `test/Amoebius/Validation/DslBarrierOracle.hs`
**Blocked by**: [Phase 48](phase_48_test_workflow_algebra.md) gate pass
**Independent Validation**: A separate Haskell contract audit proves the oracle covers every declared stage/arm in both directions, has paired negatives and no production-logic imports, and rejects empty or duplicated inventory.
**Oracle**: Doctrine-to-Haskell mapping requiring complete gate execution; oracle independence is unresolved.
**Legacy IDs**: `LTD-VAL-005`
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md`, `documents/engineering/evidence_calculus_doctrine.md`

### Objective

State independently what every stage must mean before composing or changing its implementation.

### Deliverables

- Closed Haskell semantic corpus and per-stage predicates.
- Paired specific-reason negatives and explicit residue.
- Oracle provenance and dependency boundaries.

### Validation

The contract audit rejects a missing arm, subject import, self-derived expectation, generic failure, unpaired
negative, or empty corpus at a distinct locus.

### Remaining Work

Author and independently check the complete oracle.

## Sprint 49.2: Compose the production pipeline ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Validation/DslBarrier.hs`
**Blocked by**: Sprint 49.1
**Independent Validation**: The integration entry point invokes each named production stage exactly once, passes typed outputs forward, refuses shortcuts, and agrees with the separately authored per-stage oracle on all positives and paired negatives.
**Oracle**: `test/Amoebius/Validation/DslBarrierOracle.hs`; separate authorship and independent check are required in Sprint 49.1 and are currently pending.
**Legacy IDs**: `LTD-VAL-005`
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md`

### Objective

Exercise one real end-to-end Haskell path without live infrastructure or pre-generated artifacts.

### Deliverables

- Production-stage composition and typed handoffs.
- Cleanroom lazy generation for all serialized interface formats.
- One applied production mutant and unaffected controls per stage.

### Validation

Observe every stage transition, mutation change, intended red row, and clean restoration; a skipped stage,
copied output, ignored input, or live dependency refuses the run.

### Remaining Work

Implement and qualify the composition.

## Sprint 49.3: Qualify self-reference and fake apply ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Gate/SelfReferential.hs`, `src/Amoebius/Validation/DslBarrier.hs`, `test/Amoebius/Validation/DslBarrierQualification.hs`
**Blocked by**: Sprint 49.2
**Independent Validation**: The separately authored kernel and workflow representation agree on clean and sabotaged contracts; the cumulative registry reconciles and executes every selector owned through this hardware-free frontier exactly once; the fake observer recovers a post-start challenge and catches direct-call, skipped-observation, self-report, no-op, and teardown-leak mutants.
**Oracle**: `test/Amoebius/Validation/DslBarrierQualification.hs`; oracle independence required.
**Legacy IDs**: `LTD-VAL-001`, `LTD-VAL-002`, `LTD-VAL-003`, `LTD-VAL-004`, `LTD-VAL-005`, `LTD-VAL-006`
**Docs to update**: `documents/engineering/workflow_calculus_doctrine.md`, `documents/engineering/testing_spoof_resistance.md`

### Objective

Make the universal self-referential suite exercise every hardware-free phase-owned selector and the calculus
without being able to pass itself.

### Deliverables

- Workflow-valued gate declaration and bounded execution.
- External fake observer and fresh challenge.
- Complete cumulative selector reconciliation through this barrier and the full qualification sabotage corpus
  over the exact harness build.

### Validation

The workflow route cannot accept any case the independent kernel refuses; a missing, duplicate, future-owned,
unassigned, or unexecuted selector fails at its exact owner. Neither route can create status or a gate-pass
receipt.

### Remaining Work

Implement, qualify, and independently check self-reference and fake apply.

## Sprint 49.4: Produce the documentation-gate candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Validation/DslBarrier.hs`, `app/amoebius/Main.hs`
**Blocked by**: Sprint 49.3
**Independent Validation**: From a fresh generated-run tree plus the exact read-only Phase-48 receipt, a positive complete-pipeline control reaches fake apply, a minimally different forbidden-stage case is refused at its named locus, an applied production mutant reddens its named row, every source-debt query is zero, live-fidelity residue remains explicit, and the validator emits but does not apply the verified status patch.
**Oracle**: Separate authorship of the stage and qualification oracles is required and currently pending; the complete qualified gate result is final.
**Legacy IDs**: `LTD-VAL-001`, `LTD-VAL-002`, `LTD-VAL-003`, `LTD-VAL-004`, `LTD-VAL-005`, `LTD-VAL-006`
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only after the complete gate result

### Objective

Produce and run the last no-hardware qualified candidate.

### Deliverables

- Complete raw observations and `UNVERIFIED` residue.
- Candidate provenance bound to Phase 48 gate pass and the exact source/contract/harness.
- Canonical verified status patch beneath `.build/**`; the validator performs no tracked status mutation.

### Validation

The gate checks the source diff, oracle independence, qualification refusals, clean observations, legacy
closure, and residue; a complete pass makes the barrier pass.

### Remaining Work

All implementation, independent check, qualification, legacy closure, and complete gate result remain open.

## Documentation Requirements

**Engineering docs to update (after the complete gate passes):**

- `documents/engineering/conformance_harness_doctrine.md` — only if the complete spine changes.
- `documents/engineering/workflow_calculus_doctrine.md` — only if self-referential representation changes.
- `documents/engineering/testing_spoof_resistance.md` — only if qualification or gate semantics change.

**Cross-references to add:**

- Phase 50's blocker and every hardware-policy owner link to this gate barrier.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 48](phase_48_test_workflow_algebra.md)
- [Phase 50](phase_50_host_assert_cli.md)
- [Reader-facing legacy register](legacy_tracking_for_deletion.md) — explanatory prose, never a closure input
- [No-cluster conformance harness](../documents/engineering/conformance_harness_doctrine.md)
- [Workflow calculus doctrine](../documents/engineering/workflow_calculus_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
