# Phase 6: The workflow calculus

> **Purpose**: Provision, build, deploy, observe and teardown as one algebra, with teardown a type obligation.
> **Read this if**: something has to happen to a running system, or teardown has to be reasoned about, or this gate has to be read precisely.

Before the generative re-baseline nothing in the plan owned this: make teardown an obligation the type system tracks rather than a step somebody remembers.
Its first deliverable is five arms — provision, build, deploy, observe, teardown — over one vocabulary, and this phase sits where the vocabulary it consumes first exists.
The rule behind the workflow calculus is owned by [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md), which this contract implements rather than restates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, documents/engineering/workflow_calculus_doctrine.md
**Generated sections**: none

</details>

---

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 6.1: The workflow calculus ✅](#sprint-61-the-workflow-calculus-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

✅ Done — built and sealed 2026-08-20, the fourth of the five inserted calculi to be built. `python3
tools/workflow_calculus_gate.py` passes all thirteen sides on substrate `none`, lane `none`, natural `arm64`,
untranslated. An independently authored obligation ledger names eight obligations over five workflows and
every one is replayed against what the run actually recorded; the four calculus modules carry no ambient read
and no partial token; the suite reaches its acceptance token with ten checks green; three compile-fail pairs
are red at the reason each asserts; and all three seeded mutants redden their own locus and no other.
Attestation `sha256:7f3b34a513bdad679fafa266b46e4e6509a8d038687911dc493b63216dc6c855` binds to a 2,127-file source snapshot; as everywhere here, the
reference names the run and this record follows it.

**Why the ledger asks three questions instead of one.** A single "the accounting is correct" check would have
been cheaper and worth less, because the three ways an obligation can be mishandled are invisible to each
other. Dropping one breaks the equality of the provisioned and released *sets* and leaves the multiplicity
intact. Discharging one twice does the reverse — the sets stay equal, and only a count notices. And a transfer
recorded as a teardown leaves both untouched while losing the only statement of when the resource actually
goes away. Each seeded mutant reddens exactly one of the three, which is what makes the three questions
separate claims rather than three spellings of one.

**What the type system carries, and what it does not.** The outstanding-obligation set is the workflow's type
index: `provision` adds a name, `teardown` and `transfer` remove one, and `runWorkflow` accepts only a
workflow that begins and ends owing nothing. There is no combinator that shrinks the set any other way, which
is what [`workflow_calculus_doctrine.md` §3](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation)'s
"no discard rule" means here — dropping an obligation is not refused at run time, it is unspellable. What the
type does not carry is whether the provider actually deleted anything, which that same section already
records as a `live-effect` observation and this register does not reach.

## Phase Summary

Make teardown an obligation the type system tracks rather than a step somebody remembers.

**Phase scope:** one cohesive claim — *a workflow cannot end while it still owes a teardown*. Five arms share one vocabulary precisely so that obligation can be stated across them at all.
**Substrate:** `none`
**Lane:** `none`
**Register:** 1
**Depends on:** [Phase 5](phase_05_lift_calculus.md) — the lift calculus, whose layers and witnesses each arm is placed at, and through it the budget calculus the build arm spends against.
**Gate:** `python3 tools/run_phase_gate.py 06` passes: the independent oracle agrees and every committed mutant reddens its named locus. See [Gate integrity](#gate-integrity).

## Gate integrity

- **Independent oracle.** A resource-ledger oracle authored independently, replaying a workflow trace and requiring the provisioned and released sets to be equal.
- **Committed mutants.** Mutants drop an obligation, discharge one twice, and transfer without a stated condition.
- **Specific-reason negatives.** Each negative fixture asserts the reason it fails, paired with a positive differing only in sequential and parallel composition typed by the witnesses each arm consumes.
- **Fresh challenge.** Not applicable — this gate is pure, so the separately authored predicate stands in for it: a resource-ledger oracle authored independently, replaying a workflow trace and requiring the provisioned and released sets to be equal.
- **Extension conformance (§M.13).** Not applicable: this gate delivers no extension.

## Doctrine adopted

- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) — the rule behind the workflow calculus.

## Sprints

## Sprint 6.1: The workflow calculus ✅

**Status**: Done — 2026-08-20.
**Implementation**: `src/Amoebius/Calculus/Workflow/{Arm,Obligation,Ledger,Run}.hs`,
`tools/workflow_calculus_gate.py`, `test/spec/calculus/WorkflowCalculusSpec.hs`,
`test/oracle/workflow_calculus/obligation_ledger.tsv`, `test/oracle/workflow_calculus_surfaces.tsv`,
`test/negative/compile_fail/workflow_calculus/{workflow_discharges_its_obligation,workflow_ends_owing_a_teardown,transfer_names_its_condition,transfer_without_a_condition,teardown_discharges_what_was_provisioned,teardown_of_an_unheld_obligation}.hs`
**Blocked by**: None.
**Independent Validation**: A resource-ledger oracle authored independently, replaying a workflow trace and requiring the provisioned and released sets to be equal.
**Docs to update**: `documents/engineering/workflow_calculus_doctrine.md`

### Objective

Make teardown an obligation the type system tracks rather than a step somebody remembers.

### Deliverables

- Five arms — provision, build, deploy, observe, teardown — over one vocabulary.
- Provision returning a handle and a teardown obligation together.
- Discharge by teardown or by explicit transfer to a longer-lived declaration, with no way to drop it.
- Sequential and parallel composition typed by the witnesses each arm consumes.

### Validation

A workflow ending while holding an undischarged obligation must fail to compile; a transferred obligation must name its condition.

**Both are compile-fail pairs, and a third joined them.** Discharging an obligation is discharging a *named*
one, so tearing down something the workflow never provisioned is as much a defect as ending while still owing.
Left to the ordinary machinery that would have been a stuck type family — a diagnostic a reader has to decode
— so `Remove`'s empty case is a `TypeError` that names the resource, and the fixture asserts that message
rather than merely asserting that something failed. Each of the three pairs differs from its twin in exactly
one dimension: whether the obligation is discharged, whether the transfer states a condition, and which
resource is named.

### Remaining Work

None for this phase. Parallel composition is admitted over disjoint resources and the disjointness is a
constraint rather than a convention, but nothing here executes: what parallel composition asserts is that the
two orders are equally admissible, not that anything ran at once. Binding a claim to the fixture that
discharges it is the evidence calculus's, which is the next phase's and is recorded `UNVERIFIED` here; and a
provider that fails to delete what amoebius asked it to delete remains the `live-effect` residue
[`workflow_calculus_doctrine.md` §3](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation)
names, which no type discipline reaches.

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**

- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) — **done
  2026-08-20.** §3's "the compile-fail fixture establishing that is owed by the phase that builds the workflow
  calculus; none exists" is replaced by the three that do, and by what they establish: the obligation is a type
  index, and dropping one is unspellable rather than refused.

## Related Documents
- [Development Plan](README.md)
- [`workflow_calculus_doctrine.md`](../documents/engineering/workflow_calculus_doctrine.md) — the rule behind the workflow calculus.
