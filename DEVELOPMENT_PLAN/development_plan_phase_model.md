# Development Plan: the phase model

> **Purpose**: Define phase status, strict numerical gate order, the pre-hardware barrier, substrate honesty,
> reopening, and sprint-sized seams.
> **Read this if**: a phase's status, order, dependency, substrate, or scope is being decided.

This slice owns the phase model. [`README.md`](README.md) is the sole current-status tracker;
[`development_plan_gate_integrity.md`](development_plan_gate_integrity.md) owns the validation contract.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_36_transaction_vocabulary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/substrates.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/validation_frame_doctrine.md
**Generated sections**: none

</details>

## Contents

- [C. Status vocabulary](#c-status-vocabulary)
- [E. One canonical phase model](#e-one-canonical-phase-model)
- [K. Honesty (proven / tested / assumed)](#k-honesty-proven--tested--assumed)
- [L. One-substrate discipline](#l-one-substrate-discipline)
- [N. Reopening and amending a phase](#n-reopening-and-amending-a-phase)
- [O. Sprint-sized seams and bounded phase gates](#o-sprint-sized-seams-and-bounded-phase-gates)
- [R. Where the cross-cutting invariants live](#r-where-the-cross-cutting-invariants-live)
- [Related Documents](#related-documents)

---

## C. Status vocabulary

The marker and phrase in the tracker, phase status block, and each sprint must agree.

| Marker | Meaning |
|---|---|
| ✅ **Done** | The complete qualified gate passed for the exact current contract and its status-only result was recorded. |
| 🔄 **Active — NOT VALIDATED** | Work is in progress. No current validation claim is permitted. |
| 📋 **Planned — NOT VALIDATED** | The contract is specified but work has not begun. |
| ⏸️ **Blocked — NOT VALIDATED** | Work is held shut by a named predecessor or external prerequisite. |
| 🧪 **Live-proof pending — NOT VALIDATED** | Candidate code exists, but the required live gate has not passed. |

The literal `NOT VALIDATED` is mandatory on every non-Done current status. It is deliberately redundant: a
reader must not have to infer that Active or Blocked invalidates historical completion language elsewhere in
a large phase document.

A complete qualified phase-gate pass is sufficient to change a phase and its sprints to ✅ Done. A human,
agent, or CI job may record the narrow status projection. The gate-pass contract is defined by
[`development_plan_gate_integrity.md` §M.6](development_plan_gate_integrity.md#m6-candidate-evidence-and-gate-pass).

The pass result binds two explicit source identities: the tested candidate and one exact
status-only projection. The projection may change only the tracker plus the named phase and
sprint status fields. This prevents unrelated edits from borrowing a prior pass while keeping status recording
mechanical. Any other change requires another gate run.

Status and implementation progress are separate axes. A dated inspection uses only these terms:

| Progress term | Meaning |
|---|---|
| **No footprint observed** | No attributable implementation was found inside the stated audit boundary. |
| **Observed footprint** | Attributable source, tests, or prior machinery exists; correctness and completeness are unknown. |
| **Known partial** | The inspection names a missing seam, source-policy violation, observer, target, or validation layer. |
| **Validation candidate** | A Haskell gate produced candidate evidence but has not completed every required row successfully. The phase remains NOT VALIDATED. |

Done is machine-checkable only through the complete qualified phase gate. A source path, compilation, or
partial green command is only an observation.

---

## E. One canonical phase model

- The current numbered plan is the closed contiguous domain `0..95`; fractional identifiers, gaps, and
  identifiers above 95 are prohibited until one coherent plan change deliberately extends the domain.
- The gates are considered strictly in numerical order. Except Phase 0, each candidate binds the immediately
  preceding phase's current gate-pass result. A phase may rely on additional earlier capabilities, but
  those belong in its typed contract or explanatory prose; the structural `Depends on` field contains only the
  exact immediate predecessor and may not skip or append another dependency.
- A sprint belongs to exactly one phase and names only earlier-or-same-phase blockers.
- A new or reordered sequence carries a complete `old id/path → new id/path(s)` audit map, updates every link
  and dependency in the same change, adds any still-active mismatch to the typed Haskell legacy inventory,
  and updates its reader explanation in
  [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md).
- A band is a reading aid over a contiguous ordinal range, never a second identifier.
- `pb/**` is a pre-phase bootstrap boundary, not a delivered language, test framework, or source of validation
  verdicts. It may ensure the Haskell toolchain, build the binary, and hand off; the Haskell binary owns all
  numbered-phase behaviour and verdicts.

The ordering has one non-negotiable semantic cut:

```text
Haskell source closure
  → calculi and proof stack
  → DSL, binders, planners, and lazy generators
  → test-workflow algebra
  → Phase 49 no-hardware gate barrier
  → Phase 50 bounded pb handoff
  → Phase 51 fake-boundary Haskell host ensure
  → Phase 52 first hardware bring-up
  → live platform and domain instances
```

Phase 49 is not satisfied by replaying earlier top-level exit codes. It re-exercises, from an empty generated
tree, the complete Haskell-owned pipeline and its independent oracles. Phase 50 and every later phase remain
blocked until that barrier gate passes. This ordering prevents a working container engine,
GPU, cluster, or cloud resource from being used as proxy evidence that the DSL itself is sound.

“Haskell source closure” is literal at the cut. Phase 49 requires every `LTD-SRC-*` query, including
Phase-0-owned `LTD-SRC-008`, to be zero. The sole remaining non-Haskell behavioral source is the `pb/**`
Python positively accepted by the deny-by-default Haskell grammar as minimal platform discrimination,
contained toolchain establishment, source-bound build, and opaque exec handoff. Phase 50 validates that
already-bounded runtime behavior and owns no source-migration binding. Phase 51 validates the Haskell host-ensure
kernel against fake boundaries with `Substrate: none`; it performs no hardware-specific or live validation.
Phase 52 is the first hardware-bearing validation phase. These numeric roles are fixed: Phase 49 is the
hardware-free DSL barrier, Phase 50 is bounded-`pb` handoff validation, Phase 51 is Haskell host ensure, and
Phase 52 is first hardware validation.

---

## K. Honesty (proven / tested / assumed)

A phase says exactly what one observation supports and no more:

- **Proven for the model** means a checked argument or exhaustive checker establishes a property only within
  the named formal boundary.
- **Tested** means the named cases ran in the named register and no specified counterexample was observed.
- **Assumed** names a premise the run did not observe.
- **UNVERIFIED** names every layer outside the run's register or omitted from its corpus.

Compilation establishes compilation. A property sample establishes that its generated sample found no
counterexample. A fake boundary establishes the protocol presented to that fake. A live run establishes one
observation on one substrate. None silently upgrades to end-to-end correctness.

The register vocabulary is:

| Register | Boundary | Honest claim |
|---|---|---|
| **1** | Pure/in-process Haskell and separately authored semantic oracles; no live infrastructure | Model, decode, bind, plan, render, and other value-level claims only |
| **2** | The real Haskell binary against externally observed fake boundaries; no live infrastructure | Boundary protocol and effect selection, not real-provider fidelity |
| **2.5** | Deterministic simulation activity; never a phase's final gate register | Real concurrent code against a modeled environment; environment fidelity remains assumed |
| **3** | Live infrastructure on one declared substrate/lane | Only the live effects and residue actually observed |

Phase 0 is documentation/source-policy validation and declares no behavioural register. A phase gate otherwise
uses one final register. Supporting lower-register checks remain explicit rows; they do not turn a live gate
into several interchangeable gates.

The current reset permanently invalidates all prior completion evidence. Old seals, receipts, hashes,
attestations, “built”, “validated”, “policy-conformant”, scoped-instance results, or Done prose may remain only
when explicitly labelled `Invalidated historical record`; they cannot be reactivated or cited as a current
candidate. Every phase must satisfy its rewritten gate in numerical order.

A gate writes a generated candidate ledger beneath `.build/runs/**`. The ledger records source, contract,
harness qualification, observations, residue, and the complete pass/fail result. A passing ledger for the
exact current source is sufficient for the status-only transition. The tracker never embeds or manufactures a
run transcript.

---

## L. One-substrate discipline

`Substrate: none` means the claim is decidable without hardware-specific or live infrastructure. It does not
mean “validated inside a container.” Before the Phase-50 gate passes, a pure candidate builds and invokes
the exact source-bound Haskell binary directly from an pinned, network-independent toolchain input;
it does not trust `pb` as transport. The Phase-50 candidate likewise starts the exact Haskell OS supervisor
directly; the supervisor invokes `pb` as its observed child, so the public target cannot validate itself. After
Phase 50 gate pass, later pure work may use that bounded handoff.
Either route precedes every image, container-engine, registry, cluster, GPU, or cloud phase.

A phase that requires a real substrate declares exactly one of `apple`, `linux-cpu`, `linux-cuda`, or
`windows`, plus its natural lane. It proves only the lane actually observed. Emulation, cross-building, or a
baseline result cannot establish a specialized lane.

The closed lane vocabulary also includes `provider`. It is a managed target lane driven from one declared
`linux-cpu` parent, not a substrate/architecture composite. The phase records the parent's natural
architecture as an observation and the managed resources under its Resource-provision contract; neither
`linux-cpu → provider` nor `linux-cpu/amd64 → provider` is a valid field value.

The sequencing rules are strict:

1. Phase 0 declares no behavioural register; Phases 1 through 51 use Register 1 or 2 and `Substrate: none`.
   No phase through Phase 51 may perform hardware-specific or live validation. Phase 52 is the first phase
   permitted to do so.
2. The full DSL pipeline passes its gate before the Phase-51 fake-host takeover or Phase-52 hardware
   bring-up can be validation work.
3. Hardware-specific checks begin only in their numerically owned phase after all predecessor gates pass.
4. A live phase may run supporting pure, fake, or simulated checks, but its final claim remains Register 3 on
   the one declared substrate.
5. A substrate unavailable to the operator blocks that phase; it is never replaced by a mock, another
   architecture, or documentation saying the command would pass.

Container-image replay may later confirm toolchain/runtime parity, but it cannot retroactively strengthen
pre-hardware DSL validation. The retired rule that all language validation must first run inside
`amoebius-base` inverted the dependency order and is prohibited.

---

## N. Reopening and amending a phase

Any phase may be reopened when its contract, subject, oracle, source boundary, or predecessor evidence
changes. Reopening preserves one coherent numerical story:

1. update the current contract in place rather than appending an alternative;
2. move the tracker and phase marker together to a non-Done status carrying `NOT VALIDATED`;
3. reset affected sprints to a non-Done status;
4. invalidate the prior gate result and evidence explicitly;
5. add every current implementation mismatch to the typed Haskell legacy inventory and update its explanation
   in the one reader-facing legacy register; and
6. re-run from that phase forward in numerical order after each predecessor gate passes.

An `Invalidated historical record` block may preserve minimal audit context inside `## Phase Status`. It ends
at the next `##` heading and is always non-normative. It may state what an earlier run claimed, but it may not
contain an operative command, current path, reusable hash, status rule, dependency, or instruction to
restore the result. Git history, not a second Markdown archive, retains detail.

No later phase exists to undo an earlier phase. If new understanding makes Phase N wrong, Phase N is reopened
and the later consumers are updated to the new contract. No finding is deferred out of the phase that owns
its removal merely to allow an earlier green status.

---

## O. Sprint-sized seams and bounded phase gates

A sprint owns one primary implementation seam: one algebra, interpreter, generator, boundary adapter,
runtime transition, or falsifiable operational claim. Supporting tests and documentation may accompany it.

A phase groups only the seams necessary for one cohesive acceptance claim. It splits when it would otherwise
need a second final register, a second real substrate, or a second independently useful capability claim. The
phase gate enumerates every sprint's independent validation result; a broad phase-level success bit cannot
replace missing sprint evidence.

Every sprint has:

- one concrete Haskell implementation target, except documentation-only work;
- one independently stated validation claim and oracle boundary;
- positive and paired-negative cases appropriate to that seam;
- at least one changed-subject mutant for behavioural logic;
- named legacy IDs it must reduce to zero; and
- explicit `UNVERIFIED` residue.

Same-phase implementation readiness and sprint status are separate. As defined by
[`development_plan_standards.md` §F](development_plan_standards.md#f-the-sprint-block-format), observed
deliverables and component diagnostics may unblock the next implementation seam without changing status. They
change no status and cannot substitute for the complete candidate run or parent-gate qualification. Once a
complete phase candidate passes, a human, agent, or CI job may record the narrow status projection and continue
through additional numerically ordered phases without pausing for user confirmation.

A large file is not automatically a large phase, and many files are not automatically several phases. The
unit is the falsifiable seam and its final register.

---

## R. Where the cross-cutting invariants live

| Invariant | Single source of truth |
|---|---|
| Executable cross-cutting policy values and their decision-to-owner map | `Amoebius.Validation.PolicyContract`; the documentation gate checks correspondence with the linked prose sections |
| Current phase and sprint status | [`README.md`](README.md) and the matching phase status blocks |
| Prose definition of status vocabulary, numerical order, pre-hardware barrier, and substrate honesty | This document |
| Fixed gate schema, qualification, source/artifact closure, and pass criterion | [`development_plan_gate_integrity.md`](development_plan_gate_integrity.md) |
| Phase-document shape | [`development_plan_standards.md`](development_plan_standards.md) |
| Active implementation divergence | Typed inventory, owner, observation, and closure bindings in `Amoebius.Validation.Legacy`; [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md) is the documentation-checked reader explanation only |
| Complete repository tree and file classification | [`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md) |
| Test registers and runtime test topology | [`testing_doctrine.md`](../documents/engineering/testing_doctrine.md) |
| Spoof-resistance threat model | [`testing_spoof_resistance.md`](../documents/engineering/testing_spoof_resistance.md) |
| Pre-hardware end-to-end DSL harness | [`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md) |

---

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Gate integrity and repository closure](development_plan_gate_integrity.md)
- [Development-plan tracker](README.md)
- [Substrate map](substrates.md)
- [Active legacy register](legacy_tracking_for_deletion.md)
- [Conformance harness doctrine](../documents/engineering/conformance_harness_doctrine.md)
