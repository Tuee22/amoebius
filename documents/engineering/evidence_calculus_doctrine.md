# Evidence Calculus Doctrine

> **Purpose**: Single source of truth for the **evidence calculus** — the fifth component of an extension's
> declaration, in which every claim an extension makes names the fixture that discharges it, unrepresentability
> claims carry a compile-fail fixture apiece, and an expectation is authored from the requirement rather than
> derived from the output it checks. It fixes what a claim–fixture binding is and when one is well formed.
> **Read this if**: an extension is being declared, or a claim has to be tied to something that could falsify it.

This document owns the evidence calculus. The machinery that *runs* fixtures — the register model, the test
topology, the ledger, the harness — is owned by [`testing_doctrine.md`](./testing_doctrine.md) and referenced
rather than restated. This document is about the shape of the obligation, not about how a suite executes.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/phase_07_evidence_calculus.md, documents/engineering/README.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/illegal_state/illegal_state_techniques.md
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

The other four calculi describe what an extension *does*: what it emits, what it charges, where it runs, what
it changes. This one describes what an extension is prepared to have **falsified**.

Without it the obligation surface has a hole shaped exactly like the failure the whole corpus is built against.
An extension can declare a total artifact function, a bounded grant, a closed layer set and a discharged
teardown obligation, and still assert — in prose, in a comment, in a design document — that some state is
impossible. Prose does not redden. The claim survives every gate, gets cited by the next document, and is
believed until the state occurs in production.

So the fifth component exists to make a claim into a value that carries its own refutation condition. An
extension that says "this cannot happen" and names nothing that would fail if it did has not made a claim; it
has expressed a hope, and [`../documentation_standards.md` §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)
is the standing rule that such a sentence may not be written in the indicative.

---

## 2. A claim is a value, and it names its fixture

A **claim** is a declared statement about the extension's behaviour paired with the fixture that would falsify
it. The pairing is the point: neither half is admissible alone. A fixture with no claim is a test nobody can
interpret, and a claim with no fixture is prose.

Three rules make the binding well formed.

- **Every claim names exactly one fixture.** A claim discharged by "the suite" is discharged by nothing in
  particular, and stays green when the one relevant case is deleted.
- **Every unrepresentability claim names a compile-fail fixture**, and that fixture must fail **for its pinned
  reason and no other**. A fixture that fails because of a typo also fails when the type it was testing is
  weakened, so an unpinned compile-fail fixture is worse than none — it is a green light wired to a loose
  connection. This is L5 in [`extension_conformance_laws.md`](./extension_conformance_laws.md#3-l1l5-the-per-extension-laws).
- **A claim's strength is bounded by its fixture's kind.** The claim may not be stated more strongly than
  [§3](#3-the-four-fixture-kinds) allows for the fixture discharging it, which is what stops "the property test
  passed" from being written down as "the property holds".

What this forecloses is the drift that no review catches: a claim strengthened over successive edits while the
fixture beneath it stays where it was.

---

## 3. The four fixture kinds

The kinds are closed, and each fixes what a passing run entitles the claim to say.

| Kind | What a pass establishes | What it never establishes |
|---|---|---|
| **Compile-fail** | the specific expression does not typecheck, for the pinned reason | that no expression of that state exists — only that this one is rejected |
| **Property** | no counterexample was found in the generated sample | that none exists; a property test exhibits counterexamples and cannot certify absence |
| **Oracle** | the output satisfies an independently authored predicate | that the predicate captures the requirement |
| **Live probe** | the running system did this, once, in this environment | that it will do it again, or anywhere else |

Two consequences are worth stating because they are routinely got wrong in this corpus and elsewhere.

A **compile-fail corpus is not an exhaustiveness proof.** Foreclosing a state means the type admits no
inhabitant; a fixture demonstrates one rejected expression. The gap between them is closed by the argument that
the type is right, not by adding fixtures, and that argument is a human one
([`../illegal_state/illegal_state_techniques.md` §6](../illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)).

A **property suite is evidence of presence, never of absence.** Any claim of universal quantification
discharged by property testing is conditional, and must be written as conditional. C1 in the law family is the
worked example ([`extension_conformance_laws.md` §4](./extension_conformance_laws.md#4-c1c7-the-compositional-laws)).

---

## 4. Independence is what makes a fixture worth running

A fixture derived from the thing it checks tests that a program agrees with itself.

This is the one place the generative rule of [`jit_artifact_doctrine.md` §2](./jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list)
stops short, and it stops short deliberately: expectations are on the exception list. A fixture's *mechanism*
may be generated — how it walks a tree, parses a document, drives a browser. Its *expectation* is authored from
the requirement, by a path that does not run through the machinery under test.

The test has a sharp form. **If the generator were wrong, would this fixture still be red?** An oracle written
from the requirement stays red. A golden captured from last week's output goes green the moment the wrong
output becomes the new golden, which is why byte goldens of generated output were replaced by semantic oracles
([`jit_artifact_doctrine.md` §7](./jit_artifact_doctrine.md#7-goldens-become-oracles)).

The self-referential case is the hard one, and it is not fully soluble. amoebius's own gates are workflows in
the algebra those gates validate ([`workflow_calculus_doctrine.md` §5](./workflow_calculus_doctrine.md#5-the-self-referential-suite)),
so a fixture cannot always be authored by a path outside the machinery. What is available is a **mutation
argument**: a corpus of deliberately broken inputs, each of which the gate must reject for a named reason. A
gate that passes its mutants is not proved correct, but a gate that is consistently wrong in the same direction
as its subject will pass a mutant it should have caught. The corpus is owned by
[`testing_doctrine.md` §12](./testing_doctrine.md#12-spoof-resistant-evidence).

---

## 5. What evidence is worth is the register's business

This calculus fixes the *binding*. It does not fix what a discharged claim is worth, because that depends on
where the fixture ran: a pure property suite, a boundary run against fakes, and a live run on real hardware
discharge the same claim to three different strengths.

That scale is the register model, owned by
[`testing_doctrine.md` §2](./testing_doctrine.md#2-the-registers-of-amoebius-testing). An extension's evidence
component declares the register each fixture runs at, and a claim inherits the weakest register among the
fixtures discharging it. Declaring a register the fixture cannot reach is itself an illegal state — it is the
same defect as an unpinned compile-fail fixture, one level up.

---

## 6. The residue

Stated plainly, because an evidence calculus is exactly the kind of machinery that reads as a guarantee:

- **It does not make a claim true.** It makes a claim falsifiable and binds it to the thing that would falsify
  it. A well-formed claim with a passing fixture can still be false, if the fixture is weak.
- **It does not choose the fixtures.** Which cases are worth a fixture is a design judgement, and an extension
  that declares an easy fixture for a hard claim satisfies this calculus completely.
- **It does not close the self-referential gap.** [§4](#4-independence-is-what-makes-a-fixture-worth-running)'s
  mutation argument reduces the risk; it does not eliminate it, and a gate and its subject sharing an author
  share that author's blind spots.
- **Nothing here is built.** No phase has yet delivered a claim value, a fixture binding, or a register
  declaration. Status lives only in the [tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 7. Planning ownership

This document is normative only. Which phase delivers the claim value, the fixture kinds, and the register
declaration is owned by [DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md). Normative shapes are
design intent; only explicitly named phase instances are tested amoebius results.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [Extension Conformance Doctrine](./extension_conformance_doctrine.md) — the hub, whose [§3](#2-a-claim-is-a-value-and-it-names-its-fixture) obligation surface this calculus is the fifth component of
- [Extension Conformance Laws](./extension_conformance_laws.md) — L5, the per-extension law this calculus states in full
- [Testing Doctrine](./testing_doctrine.md) — the register model, the harness, and the mutant corpus this calculus defers to
- [JIT Artifact Doctrine](./jit_artifact_doctrine.md) — the generative rule, and why expectations are excepted from it
- [Workflow Calculus Doctrine](./workflow_calculus_doctrine.md) — the self-referential suite that makes independence hard
- [Illegal-State Techniques](../illegal_state/illegal_state_techniques.md) — the foreclosure layers a compile-fail fixture reports against
