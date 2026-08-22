# Phase 49: No-hardware DSL promotion barrier + self-referential gate suite

> **Purpose**: Re-exercise the complete Haskell DSL pipeline under independently reviewed oracles and qualify
> its self-referential gate representation before any host or hardware work opens.
> **Read this if**: Phase 49 is next, a later phase wants to touch a host, image, registry, cluster, GPU, or
> cloud, or a gate is represented in the workflow calculus it helps validate.

This phase owns the single promotion cut between language confidence and host work. Its future gate must
compose only the outputs of human-approved Phases 0–48; it does not treat their old exit codes as evidence and
does not claim live-provider fidelity.
The target pipeline is defined by
[`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/workflow_calculus_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 49.1: Freeze the complete semantic surface ⏸️](#sprint-491-freeze-the-complete-semantic-surface-)
- [Sprint 49.2: Compose the production pipeline ⏸️](#sprint-492-compose-the-production-pipeline-)
- [Sprint 49.3: Qualify self-reference and fake apply ⏸️](#sprint-493-qualify-self-reference-and-fake-apply-)
- [Sprint 49.4: Produce the human-review candidate ⏸️](#sprint-494-produce-the-human-review-candidate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 48 and every predecessor's independent validation and human promotion. Every prior
Phase-49 pass, direct-versus-routed comparison, seal, receipt, attestation, completion claim, or implementation
result is invalidated as evidence. Existing implementation is an **Observed footprint / Known partial** only.

---

## Phase Summary

One cleanroom Haskell run exercises the real pipeline:

```text
decode → legality → bind/expand → plan/resolve infrastructure
  → provision → renderAll → plan → dry-run → fake apply
```

Every stage must have a separately reviewed Haskell semantic oracle, positive controls, minimally different
specific-reason negatives, complete non-empty discovery, and changed-production-subject mutants. The final
fake apply must observe the real binary at its effect boundary with fresh challenges. Review and implementation
remain open. No container engine,
registry, image, cluster, hardware accelerator, provider credential, or network service is available to the
run.

The phase also expresses gates as workflow values, but that representation is a subject rather than an
authority. It must agree with the independent gate kernel under the clean corpus and every qualification
sabotage. Haskell may emit candidate evidence; only the human validation authority may approve the barrier.

**Phase scope:** one cohesive claim — the complete Haskell-owned DSL/generator/planner pipeline and its self-referential workflow gate survive independent semantic oracles, changed-subject mutants, and harness qualification without hardware or pre-generated input. It splits if a claim requires Register 3 or a real substrate.
**Substrate:** `none`
**Lane:** `none`
**Register:** 2
**Depends on:** [Phase 48](phase_48_test_workflow_algebra.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 49`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REWRITTEN — NOT VALIDATED; independent oracle review and implementation remain open.

| Key | Phase-49 contract |
|---|---|
| `Claim` | From Haskell semantic source alone, reached through an externally observed ensure/build/exec validation handoff, the complete decode→legality→bind/expand→plan/resolve→provision→renderAll→plan→dry-run→fake-apply path produces the independently specified semantics, rejects its paired invalid cases, and routes the same contract through a qualified workflow value. Live fidelity is excluded. |
| `Subject` | Production entry points in `Amoebius.Dsl.Decode`, `Amoebius.Dsl.Foreclosure`, `Amoebius.Capability.Binding`, `Amoebius.Capacity.Provision`, `Amoebius.Manifest.RenderAll`, `Amoebius.Kernel.Chain`, `Amoebius.Kernel.Plan`, `Amoebius.Exec.Boundary`, and planned `Amoebius.Validation.DslBarrier`; `Amoebius.Gate.SelfReferential` is an additional subject, not the runner. |
| `Command` | `pb validate phase 49`; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged. The Haskell dispatcher runs the qualified kernel, production pipeline, fake boundary, and candidate schema. |
| `Oracle` | Planned `test/Amoebius/Validation/DslBarrierOracle.hs`, separately authored from doctrine and reviewed by humans who are not the sole authors of the stage implementations. Each stage exposes an independent predicate and dependency boundary. Reviewers are unassigned; this blocks validation. |
| `Positive controls` | A closed Haskell corpus covers every declared DSL constructor, legality family, capability/provider/shape arm, infrastructure-plan arm, provision fold, render activation/reconcile class, plan step, dry-run rendering, and fake effect. The oracle states expected semantic facts without using production folds. |
| `Paired negatives` | Each foreclosed axis has a minimally different positive/negative pair with pinned code and locus, including decode shape, illegal state, unbound/ambiguous capability, unsatisfied demand, stale/foreign provision observation, missing render source, wrong plan dependency, dry-run effect, and fake-boundary protocol violation. |
| `Mutants` | At least one applied Haskell production mutation per stage and for self-referential routing: decoder widening, legality drop, bind arm swap, demand omission, provision identity collapse, render omission, plan reorder, dry-run execution, fake-call bypass, workflow observation skip, and teardown leak. Each changed source/binary is witnessed and reddens its named row while unrelated controls remain green. |
| `Discovery` | The run independently derives expected surfaces from reviewed Haskell declarations and runtime surfaces from production entry points, joins them in both directions, and refuses zero/partial/duplicate discovery or an undeclared new arm. It cannot consume the old TSV/Python inventories. |
| `Challenge` | Register-2 fake apply receives a post-start unpredictable challenge carried through the public plan and recovered from raw fake-boundary requests. Pure stages use independently reviewed predicates with human-approved non-applicability of a live challenge. |
| `Observer` | An external fake-boundary observer records exact absolute executable identity, argv, request bytes, order, challenge, and teardown independently of subject logs. Pure-stage oracles read returned semantic values directly. Missing, self-reported, partial, or challenge-mismatched observation fails closed. |
| `Authority/bypass` | The corpus probes forbidden direct effect execution during decode/render/dry-run, alternate unbound providers, caller-authored identity, ambient credentials/network, cache/pre-generated fallbacks, and bypass of the workflow gate. No host or live authority is admissible. |
| `Freshness` | `.build/**`, state roots, old fixtures, and prior evidence are absent initially. The challenge is issued after fake apply starts; independent recomputation uses a fresh content namespace and proves the production compute path ran. |
| `Qualification` | The exact harness first rejects constant success, no-op stage, wrong well-formed value, empty discovery, missing subject/oracle, skipped/no-op mutant, wrong-locus failure, stale evidence, self-observer, bypass, teardown leak, and smuggled generated/legacy input; only then may the clean candidate run. |
| `Cleanroom` | The snapshot contains zero source-boundary debt. Every behavioral tracked source path is `.hs` except Python under `pb/**` that the Phase-0 `PbBootstrapGrammar` check has positively classified into the exact minimal platform-discrimination, toolchain-establishment, build, and opaque exec-handoff roles; `LTD-SRC-008` and every other `LTD-SRC-*` query return zero. Every Dhall, manifest, fake request, serialized fixture, mutation worktree, report, and evidence bundle is generated lazily beneath one `.build/**` run root. Any remaining non-source later-owned finding is matched exactly to its active legacy row and unavailable to the run. Network, container, registry, cluster, GPU/Metal/CUDA, cloud, and condemned legacy paths are unavailable and observed unused. |
| `Legacy closure` | `LTD-VAL-005`, `LTD-SRC-008`, every other source-migration row, and every active legacy row owned by Phases 0–49 must return zero findings under their executable Haskell queries before this barrier may emit a candidate. Reintroduction of foreign tracked source, a widened `pb` role, the image-first rule, or any hardware/network/container dependency fails the barrier. |
| `Predecessor` | The exact external human approval for Phase 48 and the source/contract chain through Phase 0. A historical seal, local hash, or generated receipt cannot satisfy it. |
| `Residue` | `UNVERIFIED`: real tool/provider fidelity; image packaging; host setup; natural-architecture execution; registry operation; cluster admission/convergence; accelerator behaviour; live security authorities; and every Phase 50+ capability. |
| `Human authority` | `human-only`: the reviewed candidate cannot open Phase 50 until the human authority signs the external approval and personally promotes Phase 49. |

## Doctrine adopted

- [`conformance_harness_doctrine.md` §4 — the complete spine](../documents/engineering/conformance_harness_doctrine.md#4-the-spine-decode--legality--bindexpand--planresolve--provision--renderall--plan--dry-run--fake-apply)
- [`conformance_harness_doctrine.md` §5 — the pre-hardware promotion barrier](../documents/engineering/conformance_harness_doctrine.md#5-the-pre-hardware-promotion-barrier)
- [`workflow_calculus_doctrine.md` §5 — the self-referential suite](../documents/engineering/workflow_calculus_doctrine.md#5-the-self-referential-suite)
- [`testing_spoof_resistance.md` §12 — spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence)
- [`evidence_calculus_doctrine.md` §4 — oracle independence](../documents/engineering/evidence_calculus_doctrine.md#4-independence-is-what-makes-a-fixture-worth-running)

## Sprints

## Sprint 49.1: Freeze the complete semantic surface ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `test/Amoebius/Validation/DslBarrierOracle.hs`
**Blocked by**: [Phase 48](phase_48_test_workflow_algebra.md) human approval
**Independent Validation**: A separate Haskell contract audit proves the oracle covers every declared stage/arm in both directions, has paired negatives and no production-logic imports, and rejects empty or duplicated inventory.
**Oracle**: Doctrine-to-Haskell mapping requiring human review; reviewers are unassigned and the review is missing.
**Legacy IDs**: `LTD-VAL-005`
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md`, `documents/engineering/evidence_calculus_doctrine.md`

### Objective

State independently what every stage must mean before composing or changing its implementation.

### Deliverables

- Closed Haskell semantic corpus and per-stage predicates.
- Paired specific-reason negatives and explicit residue.
- Reviewer provenance and dependency boundaries.

### Validation

The contract audit rejects a missing arm, subject import, self-derived expectation, generic failure, unpaired
negative, or empty corpus at a distinct locus.

### Remaining Work

Author and independently review the complete oracle.

## Sprint 49.2: Compose the production pipeline ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Validation/DslBarrier.hs`
**Blocked by**: Sprint 49.1
**Independent Validation**: The integration entry point invokes each named production stage exactly once, passes typed outputs forward, refuses shortcuts, and agrees with the separately authored per-stage oracle on all positives and paired negatives.
**Oracle**: `test/Amoebius/Validation/DslBarrierOracle.hs`; separate authorship and independent review are required in Sprint 49.1 and are currently pending.
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
**Independent Validation**: The independently reviewed kernel and workflow representation agree on clean and sabotaged contracts; the fake observer recovers a post-start challenge and catches direct-call, skipped-observation, self-report, no-op, and teardown-leak mutants.
**Oracle**: `test/Amoebius/Validation/DslBarrierQualification.hs`; independent reviewer required.
**Legacy IDs**: `LTD-VAL-002`, `LTD-VAL-005`
**Docs to update**: `documents/engineering/workflow_calculus_doctrine.md`, `documents/engineering/testing_spoof_resistance.md`

### Objective

Make the self-referential suite exercise the calculus without becoming its own validation authority.

### Deliverables

- Workflow-valued gate declaration and bounded execution.
- External fake observer and fresh challenge.
- Full qualification sabotage corpus over the exact harness build.

### Validation

The workflow route cannot accept any case the independent kernel refuses, and neither can create status or a
human approval receipt.

### Remaining Work

Implement, qualify, and independently review self-reference and fake apply.

## Sprint 49.4: Produce the human-review candidate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: `src/Amoebius/Validation/DslBarrier.hs`, `app/amoebius/Main.hs`
**Blocked by**: Sprint 49.3
**Independent Validation**: From an empty generated tree, a positive complete-pipeline control reaches fake apply, a minimally different forbidden-stage case is refused at its named locus, an applied production mutant reddens its named row, every source-debt query is zero, live-fidelity residue remains explicit, and the run cannot perform promotion.
**Oracle**: Independent review of the stage and qualification oracles is required and currently pending; final authority remains the human reviewer.
**Legacy IDs**: `LTD-VAL-005`
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only after the human decision

### Objective

Produce the last no-hardware candidate and hand it to the human validation authority.

### Deliverables

- Complete raw observations and `UNVERIFIED` residue.
- Candidate provenance bound to Phase 48 approval and the exact source/contract/harness.
- No automatic status mutation.

### Validation

The human reviewer checks the source diff, oracle custody, qualification refusals, clean observations, legacy
closure, and residue; only that human may sign and promote the barrier.

### Remaining Work

All implementation, independent review, qualification, legacy closure, and human decision remain open.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/conformance_harness_doctrine.md` — only if the complete spine changes.
- `documents/engineering/workflow_calculus_doctrine.md` — only if self-referential representation changes.
- `documents/engineering/testing_spoof_resistance.md` — only if qualification or authorization changes.

**Cross-references to add:**

- Phase 50's blocker and every hardware-policy owner link to this promotion barrier.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 48](phase_48_test_workflow_algebra.md)
- [Phase 50](phase_50_host_assert_cli.md)
- [Active legacy register](legacy_tracking_for_deletion.md)
- [No-cluster conformance harness](../documents/engineering/conformance_harness_doctrine.md)
- [Workflow calculus doctrine](../documents/engineering/workflow_calculus_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
