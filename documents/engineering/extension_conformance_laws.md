# Extension Conformance — The Laws

> **Purpose**: The slice of the extension family owning the two structural law families: **L1–L5**, which every
> extension satisfies in isolation, and **C1–C7**, which the composition operation satisfies over any pair of
> conforming extensions. Each law is given as a hazard it forecloses, a guideline its author can act on, and
> the mechanical discharge the generated gate performs.
> **Read this if**: an extension is being written, or a claim that two extensions compose safely has to be
> traced to the law that carries it.

This slice owns the L and C families. The obligation surface they are stated over, the generated gate that
discharges them, and the closure argument that consumes C1 are owned by the hub,
[`extension_conformance_doctrine.md`](./extension_conformance_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md, DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, documents/README.md, documents/engineering/README.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_security.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/jit_budget_doctrine.md, documents/reading_order.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Every phase-run or implementation-result statement in this document is permanently invalidated diagnostic history. It cannot establish or reactivate current status, even if a phase later advances. Target doctrine remains normative; current status is solely in the [tracker](../../DEVELOPMENT_PLAN/README.md).

## Contents
- [1. Scope](#1-scope)
- [2. How to read a law](#2-how-to-read-a-law)
- [3. L1–L5: the per-extension laws](#3-l1l5-the-per-extension-laws)
- [4. C1–C7: the compositional laws](#4-c1c7-the-compositional-laws)
- [5. Why these twelve](#5-why-these-twelve)
- [Related Documents](#related-documents)

---

## 1. Scope

This document is a **family slice**. It owns the statement, justification, and discharge of L1–L5 and C1–C7,
and nothing else: the five-component obligation surface, the verdict seal, and link-time union closure belong
to the hub, and the security and transaction families — which are *instances* of these laws at particular
seams — belong to [`extension_conformance_security.md`](./extension_conformance_security.md) and
[`extension_conformance_transactions.md`](./extension_conformance_transactions.md).

[Phase 10](../../DEVELOPMENT_PLAN/phase_10_calculus_composition.md) owns the target base five-calculus operation
and finite Register-1 instances of C2, C3, C5, and C6: five component arms, 25 ordered pairs, 125 kind triples,
exact resource addition, and a request-scope compiler barrier. That result is not an extension-law verdict.
[Phase 20](../../DEVELOPMENT_PLAN/phase_20_extension_declaration.md) owns the complete five-component
declaration that law observations name.

[Phase 21](../../DEVELOPMENT_PLAN/phase_21_extension_laws_per_extension.md) owns a target pure L1–L5 evaluator
over explicit operation, artifact, budget, flow, and claim observations joined to that declaration. Its bounded
Register-1 suite covers two declaration shapes, six authored operation inputs, two independently seeded child-
process render comparisons, actual budget and evidence values, and five single-law negative subjects. Finite
source scanners and the Phase-15 pinned claim/fixture compiler negative supplement those observations. This
does not prove termination or scanner completeness, generate a gate for an arbitrary declaration, certify a
runtime extension, or mint a conformance verdict.

[Phase 22](../../DEVELOPMENT_PLAN/phase_22_extension_laws_compositional.md) must implement a separate normalized
composite value and a bounded C1–C7 evaluator. Seven ordered identity/link cases over the two declaration
fixtures must yield 49 accepted pair-law cells; a separate 63-cell table must cover two lawful address controls
and seven exact negative subjects. Composition must preserve one request-scope index, union Phase-21
vocabularies, and fold exact resource vectors. An independent Haskell oracle must check pair sums and four
SHA-256 addresses. These samples
do not prove universal C1, arbitrary-link closure, scanner completeness, collision absence, or runtime
correspondence. Gate generation, verdict sealing, and the universal C1 proof remain owned by Phase 24 and
later proof work. Current status lives only in the [tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 2. How to read a law

Each law below has three parts, and they do different jobs:

- **Hazard** — the concrete thing that goes wrong when the law does not hold. A law with no hazard is a
  preference, and preferences do not belong in a conformance gate.
- **Guideline** — what the law asks of an extension author, in terms an author can act on while writing code.
  This is the "extension guidelines" half of an open core, and it is deliberately written as prose an author
  reads once rather than as a rule an author looks up.
- **Discharge** — what the generated gate actually does to decide the law holds. A law whose discharge is
  "review" is not in this list; it is either sharpened until it has a mechanical discharge, or it is dropped.

Where a discharge is partial, the law says so and names the residue. That is the honesty discipline
([`../documentation_standards.md` §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline))
applied to the gate rather than to prose.

---

## 3. L1–L5: the per-extension laws

### L1 Totality

**Hazard.** A partial function in an extension is a run-time failure in a composition that never mentioned it.
Every fallback arm, catch-all pattern, and undeclared exception is a state the composition proof does not
cover, because the proof reasons about the declared return type.

**Guideline.** Every operation you declare is total in its declared inputs. Failure is a value in the return
type, not an escape from it. If a case cannot arise, do not handle it defensively — remove its constructor, so
the impossibility is a property of the type rather than of a branch nobody exercises.

**Discharge.** The gate instantiates each declared operation over generated inputs and requires no exception
escapes; a wildcard-arm scan over the extension's own pattern matches reports any dispatch closed by a fallback
rather than by exhaustion; and any operation typed to throw has no constructor in the declaration language.
**Residue:** a total function can still loop, which the type does not exclude.

### L2 Determinism

**Hazard.** Two runs of one extension producing different artifacts from one input makes every content address
a lie, which in turn makes caching, reaping, and the whole artifact calculus unsound
([`content_addressing_determinism.md`](./content_addressing_determinism.md)).

**Guideline.** Your pure core is a function. Anything that is not — a clock, a random source, a directory
listing, an environment variable, an unordered map traversal — is an effect, and an effect is declared in the
lift component where the core can see it, not read where it is convenient.

**Discharge.** The gate renders each declared artifact twice in independently seeded processes and requires
byte equality; an ambient-source scan rejects the known non-deterministic primitives from the pure core; and
seeded generators exercise the map and set traversals whose iteration order is the usual carrier of the defect.

### L3 Budget honesty

**Hazard.** An artifact materialized without a grant is unbounded growth on a shared substrate, and a retained
artifact with no reaper is a leak with a long fuse. Both are invisible until the disk fills, at which point
every extension on the substrate fails together.

**Guideline.** Every byte you cause to exist is charged to a grant you hold, and every byte you keep names the
condition under which it goes away. "Deleted once no longer needed" is a type obligation, not an intention:
state the condition, and the calculus will hold you to it.

**Discharge.** The gate derives the declared artifact set, requires each to be reachable from a grant, and
requires each retained output to carry a reaper; a budget-exhaustion arm drives the grant to its ceiling and
requires a refusal before materialization rather than a partial write.

### L4 Scope propagation

**Hazard.** A value derived from scoped input that loses its scope index is a cross-tenant leak waiting for a
sink. The loss is usually incidental — a `Text`, a map key, a log line — which is why it survives review.

**Guideline.** Anything you derive from a scoped value stays at that scope. You cannot widen a scope by
computing; widening is a distinct, policy-owned edge with its own constructor, and if you find yourself wanting
to strip an index to make a type fit, the type is telling you the value is going somewhere it should not.

**Discharge.** The gate requires every declared operation's result index to be derivable from its argument
indices, and instantiates a flow relation over the extension's declared sources and sinks, reporting every path
that reaches a sink at a wider scope than its source. The S-family
([`extension_conformance_security.md`](./extension_conformance_security.md)) is this law at the identity seam.

### L5 Evidence

**Hazard.** A claim in a declaration that nothing checks is a claim the composition proof rests on and reality
does not. An unrepresentability claim is the acute case: "this cannot be expressed" is either witnessed by a
fixture that fails to compile, or it is commentary.

**Guideline.** Every claim in a declaration names the Haskell fixture/oracle value that discharges it. For
each thing said to be unrepresentable, commit a `.hs` declaration that generates the attempted value beneath
`.build/**` and pin the reason it fails — so a later change which admits it turns the case green and the gate
red. No serialized compile input or expected diagnostic is tracked.

**Discharge.** The gate requires a Haskell fixture/oracle reference per claim, lazily renders and runs each
compile-fail case and requires failure *for its pinned reason* rather than any failure, and requires each
reviewed `.hs` mutant operator to redden a named assertion. This is the [`testing_doctrine.md`](./testing_doctrine.md) evidence discipline applied per
extension.

### Target discharge boundary — NOT VALIDATED

The Phase-21 evaluator must make each L-law a separate typed verdict. Before deciding a verdict, it must require the
observed operation, artifact, budget, flow, or claim names to cover the corresponding sets derived from the
Phase-20 declaration. The executable case inventory and expected outcomes are a separately reviewed Haskell
`NonEmpty LawVerdictCase`; neither this list nor an encoded table supplies a verdict. Each case carries its
subject, expected per-law verdict vector, required negative control, and stable identity. The evaluator joins
actual results to that Haskell inventory by identity and refuses missing, duplicate, or extra cases. Any
serialized corpus or report is generated only beneath `.build/test-corpora/**` or `.build/docs/**`. Its target
executable corpus is deliberately finite:

- L1 catches exceptions over six authored inputs and scans one pure fixture for known partial tokens and
  wildcard dispatch; looping and scanner completeness remain UNVERIFIED.
- L2 compares bytes from two differently seeded child processes and scans that fixture for known ambient
  clock, randomness, environment, and directory primitives; arbitrary hidden effects remain UNVERIFIED.
- L3 drives two real grants to refusal before a third materialization and constructs two retained values with
  reapers.
- L4 evaluates the closed test relation `RequestFlow < TenantFlow < GlobalFlow` and rejects the seeded widening
  from request to tenant flow.
- L5 constructs two real evidence claims bound to fixtures and reuses the Phase-15 legal/illegal compiler pair
  for a claim with its fixture argument omitted.

The Haskell `LawVerdictCase` inventory must project a 7-by-5 reader-facing verdict table with two all-green
controls and five subjects that each fail exactly one law. Human review of a Markdown or serialized table
cannot add or alter a case. Those target verdicts can establish the evaluator's behavior only over this corpus; they are not extension conformance seals
and make no claim about the namesake `infernix` or `jitml` runtimes.

---

## 4. C1–C7: the compositional laws

The C-family is stated over the composition operation `∘`, which combines two extension declarations into one.
Where an L-law constrains a single extension, a C-law constrains what composition may do to two extensions that
already satisfy the L-laws.

### C1 Closure

**Hazard.** Without closure there is no induction, and without the induction the central claim — that arbitrary
compositions are well defined — has to be checked per combination, which is not possible for an open core.

**Statement.** If `a` and `b` each satisfy L1–L5, then `a ∘ b` satisfies L1–L5.

**Discharge.** The generated composition suite instantiates every L-law over the composite declaration for each
pair in the link set. That is a **sample**, not a proof: it exhibits counterexamples where they exist and
establishes nothing where they do not.

C1 is therefore the one law in this document whose discharge does not meet [§2](#2-how-to-read-a-law)'s bar,
and it is stated as a law rather than dropped because the whole architecture is built to make it true. C2–C7
each close one identified way a composite can fail a law its parts satisfy; they are not known to be jointly
sufficient for C1, and no argument here claims they are. A proof of C1 — by parametricity over the declaration
type, or discharged in the proof stack — is owed
([`extension_conformance_doctrine.md` §7](./extension_conformance_doctrine.md#7-link-time-union-closure)).

### C2 Identity

**Hazard.** Without an identity element, "compose these extensions" has no meaning for a set of one or zero,
and every fold over a link set needs a special case — which is where composition-order bugs live.

**Statement.** There is an empty extension `ε` with `ε ∘ a = a ∘ ε = a`, declaring no vocabulary, no artifact,
no budget, no layer, and no workflow obligation.

**Discharge.** The gate composes each extension with `ε` in both directions and requires the composite
declaration to be equal to the original, by value.

### C3 Associativity

**Hazard.** If grouping matters, then composition order is a hidden parameter of the system's behaviour, and
the link set's meaning depends on the order somebody happened to list it in.

**Statement.** `(a ∘ b) ∘ c = a ∘ (b ∘ c)`.

**Discharge.** The gate checks the equation over triples drawn from the link set by value equality of the
resulting declarations. Note that associativity is a property of the *declaration* combination; it does not
assert that effects commute, which is C4's concern.

### C4 Non-interference

**Hazard.** Two extensions that touch shared mutable state outside their declared edges compose into something
neither describes. This is the failure mode that makes plugin systems unreliable, and it is invisible to a
per-extension gate by construction.

**Statement.** The observable behaviour of `a ∘ b` restricted to `a`'s declared surface equals the behaviour of
`a` alone. Interaction occurs only through declared edges.

**Discharge.** The gate runs each extension's own property suite against the composite and requires identical
results; an ambient-authority scan rejects the shared-state primitives — global mutable references, unscoped
filesystem paths, fixed ports, process-wide environment mutation — from an extension's pure core. **Residue:**
interaction through a genuinely external system that neither extension declared is outside the check, which is
the same limit [`extension_conformance_doctrine.md` §7](./extension_conformance_doctrine.md#7-link-time-union-closure)
records.

### C5 Budget additivity

**Hazard.** If a composite's demand is not the sum of its parts', then one extension can spend another's
headroom, and the first symptom is an unrelated extension failing to materialize an artifact it had a grant
for.

**Statement.** The grant `a ∘ b` requires is the sum of the grants `a` and `b` require, and the composite is
admitted only if that sum fits within the offered capacity.

**Discharge.** The gate folds the declared demands and compares against the composite's derived requirement,
then drives the composite to its ceiling and requires refusal at the point the sum is exceeded rather than at
the point some part happens to notice. The capacity vocabulary is owned by
[`resource_capacity_doctrine.md`](./resource_capacity_doctrine.md).

### C6 Scope conjunction

**Hazard.** A composite that can produce a value at a scope neither part could produce is a cross-tenant leak
manufactured by composition itself — the most dangerous kind, because each part is individually correct.

**Statement.** For every value the composite produces at scope `s`, some part produces a value at `s` from
inputs at `s`. Composition never widens.

**Discharge.** The gate instantiates the L4 flow relation over the composite's combined source and sink set,
including the cross edges that exist only in the composite, and requires no path from a narrower source to a
wider sink. S2 and S3 are this law at the request seam.

### C7 Name disjointness

**Hazard.** Two extensions emitting artifacts to one address collide silently: the second write wins, the first
extension serves the second's bytes, and both gates pass. The same hazard at a keyspace is a cross-tenant read
([`../illegal_state/illegal_state_tenancy.md` §3.97](../illegal_state/illegal_state_tenancy.md#397-a-scope-key-whose-rendering-is-not-injective)).

**Statement.** No two conforming extensions render *different* content to one address. Where two render
identical content they name one artifact, and the composite's artifact set is the union of its parts' with
those coincidences shared rather than duplicated.

Disjointness would be the wrong statement here. Two extensions that render byte-identical content to one
address are not colliding; they are hitting the same cache entry, which is what content addressing is for
([`jit_artifact_doctrine.md` §4](./jit_artifact_doctrine.md#4-the-address-folds-in-the-rendered-text)). A gate
asserting set disjointness would redden on the good case.

**Discharge.** Addresses are content-derived through one **total** rendering
([§4.5](../illegal_state/illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content)),
so equal addresses follow from equal content. The converse — that different content yields different addresses
— is collision resistance, a cryptographic assumption rather than a type property, and it is the assumption
this law rests on. The gate asserts the law over the link set's declared artifact sets, pairing each shared
address with a content comparison.

### Target compositional discharge boundary — NOT VALIDATED

The Phase-22 evaluator must return one typed verdict per C-law over a scope-preserving composite of complete
Phase-20 declarations:

- C1 evaluates Phase-21 L1–L5 over each operand and the composite vocabulary. Its current seven cases are a
  counterexample search, not the universal implication [C1](#c1-closure) requires.
- C2 compares both empty-composite identities by value; C3 compares both groupings after declaration-key
  normalization.
- C4 restricts the composite operation, artifact, budget, and flow observations to each part and compares them
  with its isolated observations. A reviewed Haskell fixture value is scanned for a finite set of
  shared-authority primitives; a separately reviewed `.hs` mutation operator introduces a real process-global
  `IORef` through `unsafePerformIO`. Any rendered diagnostic or compiler transcript is emitted lazily beneath
  `.build/**` and remains untracked.
- C5 compares the observed composite resource vector with the exact natural-number sum of its operands.
- C6 rejects a sink wider than its source. The seeded widening also reddens C1 and C4, because it breaks L4
  closure and changes the affected part's projected behavior.
- C7 recomputes addresses from bytes, admits two byte-identical artifacts sharing one address, and rejects
  different bytes forced to one address. A separately authored Haskell oracle recomputes the four SHA-256
  results directly from the raw bytes without consuming the subject's address projection; collision resistance
  remains ASSUMED.

The cross-request compiler sibling fails at the composite's phantom request index. These observations cover
only `infernix`, `jitml`, and the empty composite; they are not a generated conformance verdict for either
runtime.

---

## 5. Why these twelve

The families are not arbitrary. Each L-law names a way a single extension can fail to be a *function* of its
declared inputs — untotal, unpredictable, unbounded, scope-losing, unwitnessed — and each C-law names a way
composition can destroy a property its parts had. The count is what it is because the calculi are five and the
indices are two: L1–L3 are the calculus obligations (total, deterministic, budgeted), L4 is the scope index,
L5 is the evidence calculus ([`evidence_calculus_doctrine.md`](./evidence_calculus_doctrine.md)) turned on the extension itself; C1–C3 make composition an algebraic operation at
all, C4 makes it faithful, and C5–C7 preserve the two indices and the naming through it.

One of the twelve does not stand as the others do. C1 is a stated requirement discharged by sampling, and
every claim resting on it inherits that standing. A thirteenth law is admissible and expected. The test for one is the test [§2](#2-how-to-read-a-law) states: it must name a hazard, be
actionable by an author, and have a mechanical discharge. A proposed law failing any of the three is a
guideline, and belongs in prose rather than in a gate.

---

## Related Documents
- [Extension Conformance Doctrine](./extension_conformance_doctrine.md) — the hub: the obligation surface, the generated gate, the verdict seal, and the closure argument that consumes [C1](#c1-closure)
- [Extension Conformance Security](./extension_conformance_security.md) — S1–S6, the instances of [L4](#l4-scope-propagation) and [C6](#c6-scope-conjunction) at the identity seam
- [Extension Conformance Transactions](./extension_conformance_transactions.md) — P1–P6, the instances at the relational seam
- [JIT Artifact Doctrine](./jit_artifact_doctrine.md) — the artifact calculus [L2](#l2-determinism) and [C7](#c7-name-disjointness) constrain
- [JIT Budget Doctrine](./jit_budget_doctrine.md) — the grant [L3](#l3-budget-honesty) and [C5](#c5-budget-additivity) are stated over
- [Workflow Calculus Doctrine](./workflow_calculus_doctrine.md) — the workflow obligations an extension declares
- [Resource Capacity Doctrine](./resource_capacity_doctrine.md) — the capacity vocabulary [C5](#c5-budget-additivity) folds
- [Content Addressing Determinism](./content_addressing_determinism.md) — the determinism discipline [L2](#l2-determinism) enforces
- [Testing Doctrine](./testing_doctrine.md) — the evidence and mutant discipline [L5](#l5-evidence) applies per extension
- [Illegal-State Techniques](../illegal_state/illegal_state_techniques.md) — the construction techniques the discharges rest on
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
