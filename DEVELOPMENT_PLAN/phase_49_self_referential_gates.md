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
- [Resource provision](#resource-provision)
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

✅ Done.

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

**Contract check**: BOUND — NOT VALIDATED; the typed contract and independent oracle are implemented, while
the complete integrated gate execution remains open.

| Key | Contract |
|---|---|
| `Claim` | `complete-hardware-free-dsl-barrier-and-self-referential-gate` — From Haskell semantic source alone, the complete decode→legality→bind/expand→plan/resolve→provision→renderAll→plan→dry-run→fake-apply path agrees with independent expectations and the workflow-valued gate agrees with the independent gate kernel. |
| `Subject` | `acquired-dsl-barrier-supervisor` — The exact source-bound Haskell DSL-barrier supervisor, production stage entry points, and `Amoebius.Gate.SelfReferential`; the workflow value remains a subject and never its own verdict. |
| `Command` | `direct-offline-serial-dsl-barrier-matrix` — Future public spelling: `pb validate phase 49`. The admissible candidate directly invokes the exact absolute source-bound Haskell executable with `validate phase 49`, using authenticated offline inputs and serial compiler rows; Phase 50 has not yet admitted `pb` as transport. |
| `Oracle` | `independent-dsl-barrier-and-qualification-oracles` — Separately authored Haskell oracles pin the nine ordered stages, exact fake-boundary protocol, self-referential workflow arms, selector assignments, and qualification refusals without importing production folds. |
| `Positive controls` | `complete-dsl-spine-positive-controls` — The closed corpus exercises all nine ordered stages, five workflow arms, an external fake apply, teardown, and every hardware-free validation selector owned through this barrier. |
| `Paired negatives` | `exact-dsl-barrier-paired-negatives` — Minimally different cases refuse stage loss/reorder/failure, invalid digest, fake identity/argv/request/challenge/order/observer/teardown, missing workflow evidence, and unbalanced workflow cleanup at their exact loci. |
| `Mutants` | `applied-dsl-barrier-and-universal-validation-mutants` — Applied Haskell production mutations cover every DSL-barrier stage and self-referential routing, plus every reconciled hardware-free validation selector; each changed binary must redden an assigned row while its declared unaffected control stays green. |
| `Discovery` | `exact-dsl-stage-selector-and-source-discovery` — Independent declarations reconcile exactly against nine runtime stages, twelve Phase-49 mutants, the cumulative typed selector assignments, and the exact Haskell source/oracle/compile-witness set in both directions. |
| `Challenge` | `post-start-fake-boundary-challenge` — The external fake child first signals readiness; only then does the supervisor issue a fresh bounded challenge that must round-trip through the raw request. |
| `Observer` | `external-fake-boundary-and-process-observation` — Parent-side process observation records absolute executable identity, exact argv, request, challenge, readiness, exit, and teardown independently of subject-authored success output. |
| `Authority/bypass` | `no-pb-network-host-container-registry-cluster-provider-or-hardware` — The candidate admits no `pb`, network, host mutation, container engine, image, registry, cluster, provider credential, accelerator, or hardware authority and rejects alternate/direct effect paths. |
| `Freshness` | `fresh-dsl-barrier-run-and-stable-source` — Two fresh run identities, post-start challenges, clean build namespaces, opening/closing source snapshots, and the exact Phase-48 receipt prevent replay or stale products. |
| `Qualification` | `complete-hardware-free-universal-qualification` — The acquired serial harness reconciles and executes every selector owned through this barrier, proves assigned impact and an unaffected control, rejects the sabotage corpus, and only then admits the clean candidate. |
| `Cleanroom` | `dsl-barrier-products-contained-below-build` — All generated sources, requests, reports, compiler products, and evidence remain under one ignored `.build/**` run root; the tracked source snapshot contains no source-boundary debt. |
| `Legacy closure` | `all-legacy-owners-through-dsl-barrier-closed` — Total compiled analyzers return zero for every source-migration binding and `LTD-VAL-001` through `LTD-VAL-006`, with independent reintroduction cases and no Markdown-derived verdict. |
| `Predecessor` | `exact-phase-forty-eight-receipt` — An exact `ImmediatePredecessorPass` for Phase 48 matches the candidate’s opening source; absent, stale, replayed, or different-source evidence refuses execution. |
| `Residue` | `phase-fifty-and-later-live-fidelity-owners-explicit` — `UNVERIFIED`: `pb` handoff, real tool/provider fidelity, image packaging, host setup, natural-architecture execution, registry operation, cluster admission/convergence, accelerator behaviour, live security authorities, and every Phase-50+ capability. |
| `Pass criterion` | `qualified-phase-forty-nine-gate-pass` — Every required row succeeds in one qualified run for the exact current source and emits, but does not apply, the verified status projection. |

## Resource provision

The only provisioned resource is a run-local external fake child beneath the Phase-49 `.build/**` root. Its
owner marker is the candidate identity; preflight proves an absolute source-bound executable and empty child
state; allowed mutation is limited to creating the child process and its private pipes after readiness;
forbidden mutations include `pb`, network, host, container, registry, cluster, provider, image, and hardware
effects; the parent process is the external observer; cleanup waits for and closes the exact child; and the
closing inventory requires zero owned processes or files outside the run root. The typed resource contract is
gate-ready, but only the complete integrated run may supply its evidence.

## Doctrine adopted

- [`conformance_harness_doctrine.md` §4 — the complete spine](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply)
- [`conformance_harness_doctrine.md` §5 — the pre-hardware gate barrier](../documents/engineering/conformance_harness_doctrine.md#5-the-pre-hardware-gate-barrier)
- [`workflow_calculus_doctrine.md` §5 — the self-referential suite](../documents/engineering/workflow_calculus_doctrine.md#5-the-self-referential-suite)
- [`testing_spoof_resistance.md` §12 — spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence)
- [`evidence_calculus_doctrine.md` §4 — oracle independence](../documents/engineering/evidence_calculus_doctrine.md#4-independence-is-what-makes-a-fixture-worth-running)

## Sprints

## Sprint 49.1: Freeze the complete semantic surface ✅

**Status**: Done
**Implementation**: `test/spec/workflow/DslBarrierOracle.hs`
**Blocked by**: [Phase 48](phase_48_test_workflow_algebra.md) gate pass
**Independent Validation**: A separate Haskell contract audit proves the oracle covers every declared stage/arm in both directions, has paired negatives and no production-logic imports, and rejects empty or duplicated inventory.
**Oracle**: `test/spec/workflow/DslBarrierOracle.hs`; the component oracle is independent of production imports,
while complete gate execution remains required.
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

Integrate the checked oracle into the acquired Phase-49 supervisor and qualified gate.

## Sprint 49.2: Compose the production pipeline ✅

**Status**: Done
**Implementation**: `src/dsl-barrier/Amoebius/Validation/DslBarrier.hs`
**Blocked by**: Sprint 49.1
**Independent Validation**: The integration entry point invokes each named production stage exactly once, passes typed outputs forward, refuses shortcuts, and agrees with the separately authored per-stage oracle on all positives and paired negatives.
**Oracle**: `test/spec/workflow/DslBarrierOracle.hs`; separate authorship is implemented and complete integrated execution remains pending.
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

## Sprint 49.3: Qualify self-reference and fake apply ✅

**Status**: Done
**Implementation**: `src/self-referential-gates/Amoebius/Gate/SelfReferential.hs`, `src/dsl-barrier/Amoebius/Validation/DslBarrier.hs`, `test/spec/workflow/SelfReferentialGatesSpec.hs`
**Blocked by**: Sprint 49.2
**Independent Validation**: The separately authored kernel and workflow representation agree on clean and sabotaged contracts; the cumulative registry reconciles and executes every selector owned through this hardware-free frontier exactly once; the fake observer recovers a post-start challenge and catches direct-call, skipped-observation, self-report, no-op, and teardown-leak mutants.
**Oracle**: `test/spec/workflow/DslBarrierOracle.hs`; the external fake-process component is implemented and universal qualification remains pending.
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

## Sprint 49.4: Produce the documentation-gate candidate ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/DslBarrierRun/Internal.hs`, `src/validation-kernel/Amoebius/Validation/Dispatch/Internal.hs`, `app/amoebius/Main.hs`
**Blocked by**: Sprint 49.3
**Independent Validation**: From a fresh generated-run tree plus the exact read-only Phase-48 receipt, a positive complete-pipeline control reaches fake apply, a minimally different forbidden-stage case is refused at its named locus, an applied production mutant reddens its named row, every source-debt query is zero, live-fidelity residue remains explicit, and the validator emits but does not apply the verified status patch.
**Oracle**: `test/spec/workflow/DslBarrierOracle.hs` plus the independent validation-selector oracles; the complete qualified gate result is final.
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
