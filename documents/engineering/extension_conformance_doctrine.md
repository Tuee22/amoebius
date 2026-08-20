# Extension Conformance Doctrine

> **Purpose**: Single source of truth for amoebius as an **open core** — the contract a domain extension or a
> hardware substrate satisfies to join the algebra, the four law families that contract decomposes into, the
> **generated** conformance gate that discharges it, and the closure argument that makes an *arbitrary*
> composition of conforming extensions itself conforming.
> **Read this if**: a new domain, provider, or substrate has to be added, or the guarantee that composing two
> unrelated extensions is safe has to be read precisely.

This document is the hub of the extension family. It owns the obligation surface, the verdict seal, and the
closure argument. The laws themselves are owned by the three slices it names, and the calculi the obligations
are stated over are owned by their own doctrines.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_20_extension_declaration.md, DEVELOPMENT_PLAN/phase_24_conformance_gate_generator.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_52_linux_engine_bringup.md, DEVELOPMENT_PLAN/phase_53_apple_engine_bringup.md, DEVELOPMENT_PLAN/phase_54_windows_engine_bringup.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/README.md, documents/engineering/README.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/extension_conformance_security.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/jit_budget_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md, documents/illegal_state/illegal_state_techniques.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. What an extension is](#2-what-an-extension-is)
- [3. The obligation surface: one component per calculus](#3-the-obligation-surface-one-component-per-calculus)
- [4. The four law families](#4-the-four-law-families)
- [5. The conformance gate is generated, not authored](#5-the-conformance-gate-is-generated-not-authored)
- [6. The verdict seal](#6-the-verdict-seal)
- [7. Link-time union closure](#7-link-time-union-closure)
- [8. A hardware substrate is an extension too](#8-a-hardware-substrate-is-an-extension-too)
- [9. What conformance does not prove](#9-what-conformance-does-not-prove)
- [10. Planning ownership](#10-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

amoebius is not a closed DSL with a fixed list of things it can deploy. It is a **core for distributed systems
that admits extensions carrying arbitrary logic** — new domains, new providers, new hardware. That openness is
the point, and it is also the danger: the central claim is that *arbitrary compositions of pure logic from
these domains are well defined at run time*, and an open set of extensions is an open set of ways to break it.

A closed DSL gets that claim cheaply. Every constructor is known, so every composition is known, and a
reviewer can in principle check them all. An open core cannot enumerate its compositions, so it has to earn
the claim a different way: by fixing an algebra, requiring every extension to be a **lawful instance** of it,
and proving once that lawful instances compose. What this doctrine owns is the contract that makes an
extension lawful, and the mechanism that decides whether a given extension satisfies it.

The alternative — extension *guidelines*, checked by review — fails for the reason review always fails on
compositional properties. A guideline is satisfied by the code somebody read; the property has to hold for
every pair, including the pair nobody thought to compose.

---

## 2. What an extension is

An extension is a **value**, not a directory of source. It is a declaration in the amoebius core's own types
that names, in one place: the domain vocabulary the extension adds, the artifacts it produces, the budgets it
consumes, the layers its effects run at, the workflows it participates in, and the evidence it offers for each
claim. Its implementation is ordinary Haskell that the declaration refers to.

The consequences of extensions being values rather than directories are the ones that matter:

- **The declaration is inspectable before anything runs.** A gate can be derived from it, because it is data.
- **There is exactly one of it.** An extension cannot have a second, informal surface — a configuration file,
  an environment variable, a side channel — because anything not in the declaration is invisible to
  composition and therefore unavailable to it.
- **Composition is an operation on declarations.** Composing two extensions is not linking two programs and
  hoping; it is combining two values, and the combination either has a type or does not.

The two indices every declaration threads are the **resource index** (what capacity a value consumes) and the
**scope index** (whose data a value belongs to). They appear in every calculus below and are the reason the
laws can be stated once rather than once per domain.

---

## 3. The obligation surface: one component per calculus

The core is five calculi, and an extension's declaration has exactly one component per calculus. This is the
whole obligation surface: an extension that has said what it does in these five places has said everything the
core needs, and an extension that has left one empty is not a partial extension but an ill-typed one.

| Calculus | The extension declares | Owned by |
|---|---|---|
| **Artifact** | every non-`.hs` artifact it emits, as a function from its inputs to content | [`jit_artifact_doctrine.md`](./jit_artifact_doctrine.md) |
| **Budget** | the grant each artifact and each retained output is charged against | [`jit_budget_doctrine.md`](./jit_budget_doctrine.md) |
| **Lift** | the layer each of its effects runs at, and the witness each transition consumes | [`lift_and_compose_doctrine.md` §7](./lift_and_compose_doctrine.md#7-the-lift-calculus) |
| **Workflow** | the provision / build / deploy / observe / teardown obligations it takes on | [`workflow_calculus_doctrine.md`](./workflow_calculus_doctrine.md) |
| **Evidence** | the fixture discharging each claim, including a compile-fail fixture per unrepresentability claim | [`evidence_calculus_doctrine.md`](./evidence_calculus_doctrine.md) |

The surface is deliberately small. A domain author's freedom is in the *logic*, which the core never inspects;
the obligations are about the seams where that logic meets everything else.

---

## 4. The four law families

The obligation surface says what an extension must declare. The laws say what those declarations must satisfy.
They are cited by family letter and number throughout the corpus, on the terms
[`documentation_standards.md` §4](../documentation_standards.md#a-law-family-is-cited-by-its-letter-and-number)
fixes.

- **L1–L5, the per-extension laws.** Properties of one extension in isolation: totality, determinism, budget
  honesty, scope propagation, and evidence. Owned by
  [`extension_conformance_laws.md`](./extension_conformance_laws.md).
- **C1–C7, the compositional laws.** Properties of the composition operation: closure, identity,
  associativity, non-interference, budget additivity, scope conjunction, and name disjointness. Owned by
  [`extension_conformance_laws.md`](./extension_conformance_laws.md), because C-laws are stated over the same
  vocabulary the L-laws establish and separating them would split one argument across two files.
- **S1–S6, the security laws.** The subset of the composition guarantee that concerns identity and isolation,
  raised to its own family because the states it forecloses are the ones where a runtime residue is least
  acceptable. Owned by [`extension_conformance_security.md`](./extension_conformance_security.md).
- **P1–P6, the transaction laws.** The relational data plane, where the illegal states are unusually concrete
  and the temptation to install a general query surface is unusually strong. Owned by
  [`extension_conformance_transactions.md`](./extension_conformance_transactions.md).

The families are not ranked, and S and P are not derived. Several of them sharpen an L-law or a C-law at a
particular seam, and where one does, its slice names which law it sharpens. Others state obligations the
algebra does not reach at all. S1 introduces an attested-versus-claimed distinction that no L-law indexes. S4
asks for observational indistinguishability between two refusals, including a timing envelope, which is a
property of what an observer can measure rather than of how an index propagates. S6 declines to foreclose
staleness and asks for a declared bound instead.

This matters for [§7](#7-link-time-union-closure), whose closure argument runs over L and C only. It therefore
does not carry S or P across a seam: two extensions can each satisfy S4 and L1–L5, and the composite can leak a
distinguishing channel that neither part had. **No law in this corpus closes that gap**, and the S family is
the one where a residue is least acceptable. Closing it is owed work, recorded in
[§9](#9-what-conformance-does-not-prove).

---

## 5. The conformance gate is generated, not authored

An extension's gate is **derived from its declaration**, not written beside it. The reason is the one that
governs every generated artifact in this corpus
([`generated_artifacts_doctrine.md`](./generated_artifacts_doctrine.md)): an authored gate is a second
statement of what the extension does, and two statements of one thing diverge silently.

Deriving it also closes the loophole that makes extension guidelines useless in practice. A gate the author
writes tests what the author thought of. A gate the core derives tests what the *laws* require, including the
clauses the author has never read — the composition cases, the cross-scope probes, the budget-exhaustion arm.
An author cannot weaken the **laws**, because there is no gate file to edit.

An author can still weaken the **instantiation**. Every law is instantiated over the extension's own declared
vocabulary, so a surface the declaration omits is a surface no law is applied to. Under-declaration is
therefore the one authoring move that buys a weaker gate, which is why it is an illegal state rather than a
review finding ([§7](#7-link-time-union-closure), *The limit*).

What the derivation emits, per extension: a property suite instantiating every L-law over the extension's own
declared vocabulary; a composition suite pairing the extension with every other conforming extension in the
link set and asserting every C-law over each pair; a compile-fail corpus, one fixture per unrepresentability
claim, each required to fail for its pinned reason and no other; and the S- and P- instances for whichever
seams the extension declares. The suite is generated to `.build/` and is never tracked.

**The honesty residue.** A generated gate tests the laws as the core states them. If a law is too weak, every
extension passes and the composition still breaks. Strengthening a law is therefore a change to the core, it
reddens existing extensions, and that is the intended cost — it is the signal that the law was doing no work.

---

## 6. The verdict seal

Conformance is not a property an extension asserts about itself. The gate produces a **verdict**, and the
verdict is a value: the extension's declaration digest, the core version the laws came from, the emitted
suite's own digest, and the result. A sealed verdict is what admits an extension to a link set.

Two properties follow from making the verdict a content-addressed value rather than a build status, and a
third has to be built rather than derived from it:

1. **It is bound to exactly one declaration.** Change the declaration and the digest changes, so the old
   verdict does not apply to the new extension — there is no "mostly the same" case.
2. **It is bound to exactly one version of the laws.** Strengthening a law invalidates every outstanding
   verdict, which is what makes the previous section's cost visible instead of silent.
3. **It records which suite ran, which is binding rather than authenticity.** A verdict minted from a
   hand-modified suite is a perfectly well-formed value carrying that suite's digest; content addressing
   detects the substitution only for a reader who independently knows the digest the declaration should have
   produced. Unforgeability is a separate obligation: the verdict constructor must be available only to the
   gate, on the terms [`jit_budget_doctrine.md` §2](./jit_budget_doctrine.md#2-the-grant-is-the-authority-to-exist)
   states for a grant. This document specifies that; nothing yet enforces it.

This is the [`release_lifecycle_doctrine.md`](./release_lifecycle_doctrine.md) evidence-gate shape applied to
extensions: a handle that only a passing run can mint, and that every downstream operation demands.

---

## 7. Link-time union closure

Here is the argument the whole doctrine exists to support.

A **link set** is the finite set of extensions compiled into one amoebius binary. Composition is closed over
the link set, so the compositions that can occur are exactly the pairs, triples, and larger combinations drawn
from it. C1 (closure) states that the composition of two conforming extensions is itself conforming. If C1
holds universally, then by induction over the link set every combination is conforming, and that is the sense
in which an arbitrary composition is well defined.

**C1 is specified, not proven, and the induction inherits that.** Stating the argument's standing precisely:

- **The base case is checked per extension**, by the generated gate of [§5](#5-the-conformance-gate-is-generated-not-authored), and the verdict of [§6](#6-the-verdict-seal) records it.
- **C1 is discharged by finite testing, not by proof.** The composition suite instantiates C1–C7 over each
  pair drawn from the link set. Pairwise testing establishes the presence of counterexamples, never their
  absence, so what the gate delivers is a sampled property and not the universally quantified lemma the
  induction consumes.
- **The step the induction actually needs is not the step the gate checks.** The step is `X ∘ c` for an
  arbitrary composite `X`, and the combinations of a link set of size *n* number 2ⁿ, not *n*². A pairwise
  check covers the pairs; it does not cover the step.
- **Nothing enters the link set without a verdict.** An extension with no sealed verdict has no constructor
  that adds it, so no member is unchecked at the base case.

So the honest claim is conditional: *given* C1, closure follows. A proof of C1 — by parametricity over the
declaration type, or by a mechanised argument in the proof stack — is owed and does not exist. Until it does,
the conformance machinery is strong evidence for closure and not a demonstration of it. The link set is finite
because a binary links a finite set of libraries, not because finiteness is what the checking budget can afford.

What C7 (address collision) contributes is the reason the union is a union at all: artifact addresses are
content-derived through one total rendering, so two extensions cannot occupy one address while rendering
different content. Where they render *identical* content they name one artifact, which is the case caching
exists to exploit ([`jit_artifact_doctrine.md` §4](./jit_artifact_doctrine.md#4-the-address-folds-in-the-rendered-text)).
Without C7 the composition would typecheck and the artifacts would collide.

**The limit.** The induction is over the *declared* seams. Two extensions that interact through something
neither declared — a file path, a clock, a global — are outside it. That is not a gap in the proof but a
restatement of what L1 and C4 demand, and it is why an undeclared side channel is an illegal state rather than
a bad practice.

---

## 8. A hardware substrate is an extension too

A new hardware substrate — a different accelerator, a different host operating system, a different frame
technology — is admitted by the same contract, not by a special case. It declares its component in each of the
five calculi exactly as a domain does: which artifacts it needs built, what capacity it grants, which layers
exist on it and which transitions between them have witnesses, which workflow obligations it takes on, and what
evidence it offers.

Two things follow. First, the substrate enumeration stops being a closed union edited by hand and becomes a
link set with the same closure property, so "does this extension run on that substrate" is a question about a
declared relation rather than about a wildcard arm
([`lift_and_compose_doctrine.md` §7](./lift_and_compose_doctrine.md#7-the-lift-calculus)). Second, a substrate
that cannot honestly declare a witness for some transition simply has no constructor for it, and every
extension requiring that transition is statically excluded from it rather than failing there at run time. The
concrete substrate instances are owned by [`substrate_doctrine.md`](./substrate_doctrine.md).

---

## 9. What conformance does not prove

Stated plainly, because a conformance verdict is exactly the kind of artifact that gets read as more than it is
([`documentation_standards.md` §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)):

- **It does not prove the extension's logic is correct.** Conformance is about seams. An extension can compute
  the wrong answer, lawfully, and the gate will pass.
- **It does not prove the running system behaves.** Every `runtime-checked` residue in the illegal-state
  catalogue survives conformance unchanged
  ([`../illegal_state/illegal_state_techniques.md` §6](../illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)).
- **It does not prove closure.** C1 is discharged by pairwise testing, so
  [§7](#7-link-time-union-closure)'s induction is conditional on a lemma this corpus has not proved.
- **It does not carry the security or transaction families across a seam.** The closure argument runs over L
  and C; S and P are checked per extension and are not known to compose ([§4](#4-the-four-law-families)).
- **It does not prove the law set is sufficient.** The laws are a human choice, exactly as the catalogue's
  taxonomy is, and a hazard along a dimension no law names passes every gate
  ([`documentation_standards.md` §16](../documentation_standards.md#16-the-illegal-state-catalogue-is-a-covering-not-a-list)).
- **Nothing here is built yet.** This document specifies a contract; no phase has yet emitted a gate or sealed
  a verdict. Status lives only in the [tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 10. Planning ownership

This document is normative only. Which phase delivers the obligation surface, the law families, the generated
gate, and the verdict seal is owned by [DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md). Normative
shapes are design intent; only explicitly named phase instances are tested amoebius results.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [Extension Conformance Laws](./extension_conformance_laws.md) — L1–L5 and C1–C7, with each law's hazard, guideline, and mechanical discharge
- [Extension Conformance Security](./extension_conformance_security.md) — S1–S6 and the skolem scope
- [Extension Conformance Transactions](./extension_conformance_transactions.md) — P1–P6, the closed transaction vocabulary
- [JIT Artifact Doctrine](./jit_artifact_doctrine.md) — the artifact calculus [§3](#3-the-obligation-surface-one-component-per-calculus) requires a component in
- [JIT Budget Doctrine](./jit_budget_doctrine.md) — the budget calculus, and why a grant carries its ceiling
- [Workflow Calculus Doctrine](./workflow_calculus_doctrine.md) — the workflow calculus, and teardown as a type obligation
- [Lift and Compose](./lift_and_compose_doctrine.md) — the lift calculus and the self-containment rule that makes conformance amoebius's own property to prove
- [Capability Extension Doctrine](./capability_extension_doctrine.md) — the capability seam an extension binds against
- [Substrate Doctrine](./substrate_doctrine.md) — the concrete substrate instances of [§8](#8-a-hardware-substrate-is-an-extension-too)
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md) — why the gate is derived rather than authored
- [Release Lifecycle Doctrine](./release_lifecycle_doctrine.md) — the evidence-gated handle the verdict seal follows
- [Evidence Calculus Doctrine](./evidence_calculus_doctrine.md) — the evidence calculus, and what a claim–fixture binding is
- [Testing Doctrine](./testing_doctrine.md) — the register model the generated suite runs in
- [Illegal-State Catalog](../illegal_state/illegal_state_catalog.md) — the states the laws foreclose
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
