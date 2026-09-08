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

## Phase Status

⏸️ Blocked — NOT VALIDATED.

The [2026-09-08 reset](README.md#reopened-numeric-sequence) withdraws prior certification. Existing
implementation is an Observed footprint / Known partial. Retained requirements remain obligations; only this
phase's complete qualified gate under the replacement acceptance baseline can authorize Done.

Gate execution remains blocked by the qualified Phase-48 predecessor and its compatible evidence chain.

## Phase Summary

The audit found that the barrier assembled nine `True` flags with literal digest-shaped values, recorded expected apply arguments although the child ran with `--fake`, and exchanged an echo instead of a real derived manifest. These are required adversarial regression cases. The replacement barrier must execute the complete declared semantic surface with actual typed values and external process observations; component passes and stronger receipt formatting cannot substitute for it.

The required cleanroom Haskell run must exercise the real pipeline:

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

**Contract check**: UNRESOLVED — NOT VALIDATED; the replacement certification-generation and accepted-baseline
binding has not been authored in Haskell. Retained rows specify intended scope and supply no execution evidence.

| Key | Contract |
|---|---|
| `Claim` | The complete declared hardware-free language surface traverses one actual typed production path from decode through legality, bind/expand, plan/resolve, provision, renderAll, plan, dry-run and observed fake apply; generated software and workflow-valued gates satisfy independent complete semantic expectations. |
| `Subject` | `acquired-dsl-barrier-supervisor` — The exact source-bound Haskell DSL-barrier supervisor, production stage entry points, and `Amoebius.Gate.SelfReferential`; the workflow value remains a subject and never its own verdict. |
| `Command` | `direct-offline-serial-dsl-barrier-matrix` — Future public spelling: `pb validate phase 49`. The admissible candidate directly invokes the exact absolute source-bound Haskell executable with `validate phase 49`, using authenticated offline inputs and serial compiler rows; Phase 50 has not yet admitted `pb` as transport. |
| `Oracle` | `test/spec/workflow/DslBarrierOracle.hs` independently defines actual stage input/output meanings, identities/resources, manifest/request bytes, workflow observations and complete language/selector assignments; expected booleans, fixture counts and digest-shaped constants cannot serve as observations. |
| `Positive controls` | Every declared hardware-free language family and interaction runs through the actual typed stage handoffs with independent full-value observations, compiled generated-software checks, a readiness-gated fake application and complete workflow cleanup. |
| `Paired negatives` | Minimally alter each real stage value, instruction, ordering, identity/resource, manifest/request, executable/argv, readiness/challenge, workflow observation or teardown condition; require the assigned exact failure with the legal control observed successful. |
| `Mutants` | Change the actual decoder, legality, bind/expand, resolution, provision, renderer, plan/dry-run, process request and workflow execution code, plus every cumulative required validation selector. A checker-only flag or fabricated observation cannot satisfy a production-stage mutation. |
| `Discovery` | Reconcile the complete independently authored language/interaction universe with production constructors, all actual stage handoffs, generated artifact owners, independent cases and cumulative selector/build/impact assignments in both directions; nine stage names and twelve labels cannot establish completeness. |
| `Challenge` | The external fake subject first produces an OS-observed ready event. Only then does the independent supervisor generate and issue a fresh bounded challenge through the actual derived application request; predeclared command-line challenges are not fresh readiness evidence. |
| `Observer` | One acquired external supervisor binds actual stage-value observations and fake child executable identity, argv, environment, stdin request, ready/challenge ordering, result and teardown. It never populates observed fields from oracle constants. |
| `Authority/bypass` | `no-pb-network-host-container-registry-cluster-provider-or-hardware` — The candidate admits no `pb`, network, host mutation, container engine, image, registry, cluster, provider credential, accelerator, or hardware authority and rejects alternate/direct effect paths. |
| `Freshness` | `fresh-dsl-barrier-run-and-stable-source` — Two fresh run identities, post-start challenges, clean build namespaces, opening/closing source snapshots, and the exact Phase-48 receipt prevent replay or stale products. |
| `Qualification` | Run every assigned cumulative selector on its exact case and named locus with an unaffected control, plus deliberate missing-stage, copied-output, no-op, canned-readiness, forged-argv, skipped qualification and wrong-case sabotages against the actual harness. Printed qualification tokens cannot establish execution. |
| `Cleanroom` | `dsl-barrier-products-contained-below-build` — All generated sources, requests, reports, compiler products, and evidence remain under one ignored `.build/**` run root; the tracked source snapshot contains no source-boundary debt. |
| `Legacy closure` | `all-legacy-owners-through-dsl-barrier-closed` — Total compiled analyzers return zero for every source-migration binding and `LTD-VAL-001` through `LTD-VAL-006`, with independent reintroduction cases and no Markdown-derived verdict. |
| `Predecessor` | Authenticated `ImmediatePredecessorPass` for Phase 48 in the admitted certification generation, plus the accepted verifier's current compatibility decision under [§M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass). Missing, forged, revoked, incompatible, or wrong-phase evidence refuses before any phase effect. Historical source identity remains recorded; reuse requires unchanged relevant dependency and acceptance closures. |
| `Residue` | No whole-language mathematical theorem is inferred from a finite corpus. Explicit unproved model/cutoff/solver/renderer assumptions remain named; bootstrap handoff, host/real tool/provider fidelity, images, registry, clusters, accelerators and live browser/security/runtime effects retain their later owners. |
| `Pass criterion` | `qualified-gate-pass` — Every required row succeeds in one qualified run for the exact current source and emits, but does not apply, the verified status projection. |

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

## Sprint 49.1: Freeze the complete semantic surface ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `test/spec/workflow/DslBarrierOracle.hs`
**Blocked by**: [Phase 48](phase_48_test_workflow_algebra.md) gate pass
**Independent Validation**: Independently enumerate the full declared language and stage-value relations; a minimally omitted constructor/interaction fails exact discovery; registry and copied-oracle mutants fail assigned cases; each unproved assumption remains explicit.
**Oracle**: `test/spec/workflow/DslBarrierOracle.hs`; the component oracle is independent of production imports,
while complete gate execution remains required.
**Legacy IDs**: `LTD-VAL-005`
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md`, `documents/engineering/evidence_calculus_doctrine.md`

### Objective

State independently what every stage must mean before composing or changing its implementation.

### Deliverables

- A Haskell-owned complete language/interaction registry joins every pre-barrier schema/IR/capability/calculus/UI/offline/generated artifact arm to its actual stage values, independent semantic obligations and exact negative/mutant cases.
- Classify each claimed result as bounded model proof, compiled type/refinement claim, semantic differential or observed software execution, and retain its explicit assumptions and limits. Stage labels and fixture totals cannot replace this coverage inventory.

- Closed Haskell semantic corpus and per-stage predicates.
- Paired specific-reason negatives and explicit residue.
- Oracle provenance and dependency boundaries.

### Validation

- Add or remove a production language arm while preserving stage and fixture counts; the independent completeness join must identify the exact uncovered surface.

The contract audit rejects a missing arm, subject import, self-derived expectation, generic failure, unpaired
negative, or empty corpus at a distinct locus.

### Remaining Work

Integrate the checked oracle into the acquired Phase-49 supervisor and qualified gate.

## Sprint 49.2: Compose the production pipeline ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/dsl-barrier/Amoebius/Validation/DslBarrier.hs`
**Blocked by**: Sprint 49.1
**Independent Validation**: One real production pipeline yields independently expected typed outputs; a same-count value substitution or skipped handoff fails exactly; actual stage mutants fail their assigned case; live fidelity remains excluded.
**Oracle**: `test/spec/workflow/DslBarrierOracle.hs`; its complete independent semantic declarations and actual integrated observation remain required.
**Legacy IDs**: `LTD-VAL-005`
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md`

### Objective

Exercise one real end-to-end Haskell path without live infrastructure or pre-generated artifacts.

### Deliverables

- Replace observation-only admission with a pipeline that invokes each actual owning stage and passes its opaque typed output directly to the next stage. Preserve source identity, ownership, resources, plan semantics and generated request bytes across the entire run.
- Acquire actual full stage outputs before deriving any summaries or digests. A digest binds observed meaning only after the independent semantic comparison; neither literal digests nor caller-supplied pass flags can mint a stage result.

- Production-stage composition and typed handoffs.
- Cleanroom lazy generation for all serialized interface formats.
- One applied production mutant and unaffected controls per stage.

### Validation

- Recreate the historical nine-True/literal-digest input without running stages; require an exact missing-acquisition refusal. A separately executed component suite cannot fill in that missing pipeline observation.
- Apply mutations to the real stage entry points and run the complete unchanged pipeline on the assigned case. Mutating only `validateDslBarrier` bookkeeping cannot satisfy a decode/provision/render semantic mutant.

Observe every stage transition, mutation change, intended red row, and clean restoration; a skipped stage,
copied output, ignored input, or live dependency refuses the run.

### Remaining Work

Implement and qualify the composition.

## Sprint 49.3: Qualify self-reference and fake apply ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/self-referential-gates/Amoebius/Gate/SelfReferential.hs`, `src/dsl-barrier/Amoebius/Validation/DslBarrier.hs`, `test/spec/workflow/SelfReferentialGatesSpec.hs`
**Blocked by**: Sprint 49.2
**Independent Validation**: Observe an actual derived apply request after readiness and compare workflow execution to the independent kernel; wrong argv, echoed-only payload, pre-issued challenge and wrong-case qualification pairs fail exactly; actual boundary/workflow/harness mutants are detected; live tools remain unverified.
**Oracle**: `test/spec/workflow/DslBarrierOracle.hs`; actual external process custody and complete acquired qualification remain required.
**Legacy IDs**: `LTD-VAL-001`, `LTD-VAL-002`, `LTD-VAL-003`, `LTD-VAL-004`, `LTD-VAL-005`, `LTD-VAL-006`
**Docs to update**: `documents/engineering/workflow_calculus_doctrine.md`, `documents/engineering/testing_spoof_resistance.md`

### Objective

Make the universal self-referential suite exercise every hardware-free phase-owned selector and the calculus
without being able to pass itself.

### Deliverables

- The fake application child accepts the production apply invocation and consumes the actual manifest/request bytes derived from the pipeline. Its observer reads actual process argv and input, never substitutes `expectedFakeArgv` or a fixed challenge echo.
- Generate challenge bytes only after observed child readiness and bind them to the application request, raw response, process identity and zero-owned-residue teardown.
- Execute the complete cumulative qualification sabotage corpus against the exact candidate harness; retain acquired per-case observations, source-change witnesses, exact reasons and unaffected controls. A synthesized success string cannot qualify the harness.

- Workflow-valued gate declaration and bounded execution.
- External fake observer and fresh challenge.
- Complete cumulative selector reconciliation through this barrier and the full qualification sabotage corpus
  over the exact harness build.

### Validation

- Reproduce the historical child invocation `--fake` with an observed record claiming apply flags; reject it from actual argv custody. Send only the old challenge echo with no derived manifest and require the exact request-semantic failure.
- Reject preselected command-line challenges, ready events copied from a prior process, skipped sabotage execution and aggregate failure occurring outside a selector’s assigned case.
- Derive workflow evidence from actual bounded gate execution and external observations; passing `GatePassed` into a constructor cannot supply that evidence.

The workflow route cannot accept any case the independent kernel refuses; a missing, duplicate, future-owned,
unassigned, or unexecuted selector fails at its exact owner. Neither route can create status or a gate-pass
receipt.

### Remaining Work

Implement, qualify, and independently check self-reference and fake apply.

## Sprint 49.4: Produce the documentation-gate candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/validation-kernel/Amoebius/Validation/DslBarrierRun/Internal.hs`, `src/validation-kernel/Amoebius/Validation/Dispatch/Internal.hs`, `app/amoebius/Main.hs`
**Blocked by**: Sprint 49.3
**Independent Validation**: From a fresh generated-run tree plus the exact read-only Phase-48 receipt, a positive complete-pipeline control reaches fake apply, a minimally different forbidden-stage case is refused at its named locus, an applied production mutant reddens its named row, every source-debt query is zero, live-fidelity residue remains explicit, and the validator emits but does not apply the verified status patch.
**Oracle**: `test/spec/workflow/DslBarrierOracle.hs` plus the independent validation-selector oracles; the complete qualified gate result is final.
**Legacy IDs**: `LTD-VAL-001`, `LTD-VAL-002`, `LTD-VAL-003`, `LTD-VAL-004`, `LTD-VAL-005`, `LTD-VAL-006`
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only after the complete gate result

### Objective

Produce and run the last no-hardware qualified candidate.

### Deliverables

- The candidate consumes acquired observations from the real full-surface pipeline, qualified generated software and cumulative sabotage executions, each bound to exact source and predecessor identities.

- Complete raw observations and `UNVERIFIED` residue.
- Candidate provenance bound to Phase 48 gate pass and the exact source/contract/harness.
- Canonical verified status patch beneath `.build/**`; the validator performs no tracked status mutation.

### Validation

- Missing any actual semantic output, generated software execution, assignment-specific mutant kill, acquired qualification case or external boundary observation must fail the complete phase gate; a component diagnostic cannot trigger status projection.
- After a complete qualified pass, the mechanical status update and ordinary numeric continuation remain automatic under repository instructions; the review reset adds no intermediate approval seam.

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
