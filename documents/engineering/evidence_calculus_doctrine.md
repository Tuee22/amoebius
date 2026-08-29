# Evidence Calculus Doctrine

> **Purpose**: Define claim-to-fixture bindings, the evidence strength each fixture kind permits, oracle
> independence, and the reviewer authorization boundary.
> **Read this if**: an extension or phase makes a claim that must be falsifiable rather than merely asserted.

This document owns the evidence calculus. Execution registers and harness topology belong to
[`testing_doctrine.md`](./testing_doctrine.md); spoof resistance belongs to
[`testing_spoof_resistance.md`](./testing_spoof_resistance.md); current status belongs only to the
[development-plan tracker](../../DEVELOPMENT_PLAN/README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, documents/engineering/README.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/workflow_calculus_doctrine.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

</details>

## Contents

- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. A claim is a value, and it names its fixture](#2-a-claim-is-a-value-and-it-names-its-fixture)
- [3. The four fixture kinds](#3-the-four-fixture-kinds)
- [4. Independence is what makes a fixture worth running](#4-independence-is-what-makes-a-fixture-worth-running)
- [5. What evidence is worth is the register's business](#5-what-evidence-is-worth-is-the-registers-business)
- [6. The residue](#6-the-residue)
- [7. Planning ownership](#7-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

The other calculi describe what a declaration emits, consumes, changes, and must release. The evidence
calculus describes what it is prepared to have falsified.

A prose claim survives when its implementation becomes wrong because prose has no red state. A well-formed
evidence claim therefore carries its falsification boundary as data. This makes missing coverage visible and
prevents “the suite passed” from standing in for the one case that matters.

---

## 2. A claim is a value, and it names its fixture

A claim is a bounded statement paired one-to-one with a fixture capable of falsifying it. Neither half is
admissible alone.

Three rules make the pair well formed:

1. **Every claim names exactly one primary fixture.** Supporting controls may be many, but responsibility for
   the claim cannot disappear into “the suite”.
2. **Every unrepresentability claim names a compile-fail fixture** that fails for its pinned diagnostic code
   and locus, paired with a minimally different compiling case.
3. **The claim cannot be stronger than its fixture kind, register, corpus, observer, or substrate.** Missing
   layers remain `UNVERIFIED`.

The declaration also names the subject entry point, oracle module, reviewer, required changed-subject mutant,
and current residue. Those bindings are Haskell values. Serialized views, fixtures, or reports are generated
only beneath `.build/**` and cannot become an alternate evidence registry.

---

## 3. The four fixture kinds

The kinds are closed:

| Kind | What one qualifying result establishes | What it never establishes |
|---|---|---|
| **Compile-fail** | The named expression is rejected for the pinned reason and locus | That no other expression can inhabit the state |
| **Property** | The explored sample found no counterexample and met its coverage obligations | Universal truth outside that sample |
| **Oracle** | The observed output satisfied a separately reviewed predicate | That the predicate fully captures the requirement |
| **Live probe** | A fresh effect was externally observed once on the named substrate | Repeatability, another substrate, or uncompromised infrastructure |

A fixture that fails for an unrelated reason does not discharge its claim. A live probe without a post-start
challenge and external observer is a subject report, not live evidence. A byte equality without independent
semantics establishes only byte equality.

---

## 4. Independence is what makes a fixture worth running

An expectation derived from the output it checks proves that a program agrees with itself. Independence
therefore requires all of the following:

- the expectation is authored from the requirement;
- the oracle does not import, call, copy, or mechanically translate subject decision logic;
- the oracle is separately reviewed, and its reviewer is not the subject's sole author;
- subject and expectation chronology is known, or an explicit independent review supplies the missing
  provenance; and
- amending the expectation invalidates affected evidence and re-runs its mutants.

Independent oracle logic is `.hs`. A Dhall/JSON/YAML/TSV/golden copy is not made independent by being written
in another format; it is behavioural source outside the closed Haskell boundary. When bytes or another format
are required at an interface, Haskell derives them lazily beneath `.build/**`, while a separate Haskell
semantic predicate states the expectation.

Self-referential gates do not receive a special exemption. Their workflow representation may exercise the
same calculus, but it cannot authorize its own verdict. The independently reviewed oracle/harness must first
reject the fixed sabotage corpus, every mutant must demonstrate a changed production locus, raw observations
must be retained, and an authorized-reviewer external signature is the only promotion authority. Mutation sensitivity
is one falsification technique within that boundary, not a cure for shared authorship.

---

## 5. What evidence is worth is the register's business

The claim-to-fixture binding does not determine the strength of a result. Register 1 establishes value/model
behaviour, Register 2 establishes the protocol presented to an externally observed fake, Register 2.5 tests
real concurrent code against a modeled environment, and Register 3 records a live effect on one real
substrate. The definitions live in
[`testing_doctrine.md` §2](./testing_doctrine.md#2-the-registers-of-amoebius-testing).

A claim inherits the weakest required observation. Supporting lower-register checks cannot promote a live
claim, and hardware success cannot compensate for an unvalidated decode, binding, planning, or rendering
claim. The development plan therefore places a complete no-hardware DSL promotion barrier before host and
hardware gates.

---

## 6. The residue

The calculus makes claims reviewable and falsifiable; it does not make them true.

- It does not prove that an independently authored oracle is correct.
- It does not turn finite sampling into universal proof.
- It does not prove the compiler, kernel, observer, authority, provider, hardware, or reviewer uncompromised.
- It does not let a generated bundle, digest, attestation, or exit code authorize status.
- It does not let prior evidence survive a changed contract, subject, oracle, source boundary, or predecessor.

Every result names these limits as assumptions or `UNVERIFIED` residue. The present reset marks every numbered
phase NOT VALIDATED, so this doctrine carries no current implementation-result instance.

---

## 7. Planning ownership

This doctrine is normative design intent. Phase order, current status, the fixed gate table, qualification,
and delegated promotion live in `DEVELOPMENT_PLAN/`. A phase adopts this calculus by naming its bounded claim,
Haskell subject, independently reviewed Haskell oracle, qualifying controls, changed-subject mutant, register,
and residue.

---

## Related Documents

- [Engineering doctrine index](./README.md)
- [Extension conformance doctrine](./extension_conformance_doctrine.md)
- [Extension conformance laws](./extension_conformance_laws.md)
- [Testing doctrine](./testing_doctrine.md)
- [Testing spoof resistance](./testing_spoof_resistance.md)
- [JIT artifact doctrine](./jit_artifact_doctrine.md)
- [Workflow calculus doctrine](./workflow_calculus_doctrine.md)
- [Development-plan gate integrity](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md)
