# Lift and Compose, Don't Depend

> **Purpose**: Single source of truth for amoebius's relationship to the five seed projects (`hostbootstrap`,
> `prodbox`, `jitML`, `infernix`, `mattandjames`) — that amoebius **depends on none of them and none of them
> depends on amoebius**, that they are **reference implementations** whose pure structures amoebius
> **re-derives** under stronger obligations, and that a re-derivation is admissible only once the guarantee
> amoebius must add has been named. It also owns the **lift calculus**: the algebra that gives the word "lift"
> a meaning a type can check.
> **Read this if**: a seed already implements something amoebius needs, and the question is what amoebius is
> allowed to do about it.

This document owns the self-containment rule, the re-derivation discipline, and the lift calculus. It owns no
seed code and no seam: each seam is owned by its own doctrine, and each re-derived structure is owned by the
amoebius doctrine that specifies it.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/engineering/README.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_security.md, documents/engineering/formal_model_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/substrate_doctrine.md, documents/glossary.md, documents/reading_order.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Every phase-run or implementation-result statement in this document is permanently invalidated diagnostic history. It cannot establish or reactivate current status, even if a phase later advances. Target doctrine remains normative; current status is solely in the [tracker](../../DEVELOPMENT_PLAN/README.md).

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. The two non-dependencies](#2-the-two-non-dependencies)
- [3. A seed is a reference implementation](#3-a-seed-is-a-reference-implementation)
- [4. The re-derivation rule: name the guarantee you are adding](#4-the-re-derivation-rule-name-the-guarantee-you-are-adding)
- [5. The re-derivation map](#5-the-re-derivation-map)
- [6. Convergence is the evidence](#6-convergence-is-the-evidence)
- [7. The lift calculus](#7-the-lift-calculus)
- [8. What the lift-era phases established, and why it is superseded](#8-permanently-invalidated-lift-era-run-history)
- [9. Planning ownership](#9-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

An earlier version of this document said the opposite of what follows. It held that amoebius should **lift the
proven primitives** of the sibling projects and re-home them onto amoebius seams, on the reasonable grounds
that rewriting tested code reintroduces its bugs. The reasoning was sound and the conclusion was wrong, for a
reason that only became visible once the target architecture was stated.

The reason is **not** that amoebius is a closed corpus. It is not one: it is an open core that admits
third-party extensions carrying arbitrary logic
([`extension_conformance_doctrine.md` §1](./extension_conformance_doctrine.md#1-why-this-doctrine-exists)), and
a structure amoebius does not own can be admitted the same way any extension is — by a conforming declaration
and a sealed verdict. What a seed cannot do is hold that verdict *while remaining a seed*. A verdict binds one
declaration and one version of the laws, so it is invalidated by the next upstream release and by every
strengthened law; a seed under other maintainers, with its own cadence and its own users, is a dependency whose
conformance expires on a schedule amoebius does not set.

That is a **governance** argument, and it is the one that holds. The obligation is continuous where the
verdict is a snapshot, and only ownership makes the two coincide.

Depending on a seed also inverts the direction of gravity. A seed is a working system with its own users, its
own release cadence, and its own reasons to change; a dependency edge into amoebius makes every one of those
decisions an amoebius decision too. The same argument decided the Pulsar client
([`pulsar_client_doctrine.md` §1](./pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets)) and decides
the proof stack ([`formal_model_doctrine.md`](./formal_model_doctrine.md)): where a guarantee is load-bearing,
amoebius owns the thing that carries it.

So the rule inverts. **amoebius reimplements what it must prove, and depends on nothing it must prove.** What
survives from the old doctrine is the part that was always right: a seed's working implementation is enormously
valuable *as a specification*. It shows the shape, the edge cases, and the failure modes, and it does so with
the authority of something that has actually run.

---

## 2. The two non-dependencies

Both directions are normative. Only the first is mechanically checkable, and the asymmetry is stated rather
than glossed.

1. **amoebius depends on no seed.** No `source-repository-package` entry, no vendored seed tree, no
   `build-depends` on a seed package, no import of a seed module, no runtime call into a seed service. The
   check is a property of the dependency graph, not of a review: the build plan names only amoebius packages
   and third-party libraries amoebius has no obligation to prove. A gate in this repository decides it.
2. **No seed depends on amoebius.** amoebius does not become infrastructure for the seeds. They keep running
   as they are, and their evolution stays their own. **This one amoebius cannot check**: it is a property of
   five repositories amoebius neither owns nor builds. It is a commitment about what amoebius will not publish
   or ask for — no seed is asked to adopt an amoebius interface, and no amoebius phase lists a change to a seed
   as a deliverable — and it is enforced by that discipline rather than by a gate.

The two together mean the seeds and amoebius can be read as one body of work while remaining two bodies of
code. That is the property that makes a seed usable as evidence at all: if amoebius linked it, its behaviour
would no longer be an independent observation.

**The residue.** Third-party libraries are still dependencies, and this rule does not pretend otherwise. What
distinguishes them is the obligation: amoebius does not claim to prove `bytestring` correct, and does claim to
prove its own composition laws. Anything the composition proof rests on is amoebius-owned — which is why the
model checker, the refinement checker, and the message client are forked rather than consumed
([`formal_model_doctrine.md`](./formal_model_doctrine.md)).

---

## 3. A seed is a reference implementation

A seed's standing in the amoebius corpus is precisely that of a reference implementation:

- **It is authoritative about the problem.** What the domain actually requires, which cases occur, and where
  the sharp edges are: the seed knows, because it ran into them.
- **It is not authoritative about the solution.** Its type discipline is whatever its own goals demanded, which
  is generally weaker than the one amoebius has to hold to.
- **It is evidence, never proof.** That a shape works in a seed argues the amoebius design is achievable. It is
  not an amoebius result until an amoebius phase passes its own gate
  ([`documentation_standards.md` §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)).

The five seeds and what each is a reference for: `hostbootstrap`, the host-lift algebra and substrate
detection; `prodbox`, typed manifest rendering and schema reflected from Haskell types; `jitML`, the numerical
core, determinism kernel, and content-addressed checkpoint store; `infernix`, inference orchestration, durable
context, and a generation discipline that keeps zero generated files tracked; `mattandjames`, the multi-tenant
web shape — gateway, identity, offline-first command queue, cached stateless sockets, and a relational data
plane holding more than one tenant's rows.

---

## 4. The re-derivation rule: name the guarantee you are adding

Re-deriving a structure that already exists is expensive, and the expense is only justified by a guarantee the
existing version does not carry. So the rule is a precondition, not a permission:

> **A re-derivation is admissible only once the doctrine that specifies it states, in one sentence, the
> guarantee amoebius must add that the seed's version does not carry.**

If no such sentence can be written, the honest conclusion is that amoebius does not need the structure at all —
not that it should copy it. The rule is deliberately hard to satisfy by restatement: "typed more strongly" is
not a guarantee, because it names no state that stops being representable. A satisfying sentence **names the
illegal state**, and **names where it is foreclosed** — a catalogue entry where one exists, the law or
technique that forecloses it otherwise
([`../illegal_state/illegal_state_catalog.md`](../illegal_state/illegal_state_catalog.md)). Naming a technique
alone does not satisfy the rule: a technique is how a state is foreclosed, and the rule is about which state.

The map in [§5](#5-the-re-derivation-map) records each guarantee for reference. **The discharge is the owning
doctrine's**, not the map's: a row here does not authorise a re-derivation whose own doctrine has said nothing,
because a summary table is exactly the second statement [§2](#2-the-two-non-dependencies) of
[`documentation_standards.md`](../documentation_standards.md) forbids.

What this forecloses is the failure mode the old doctrine invited from the other side: a wholesale rewrite
justified by taste, producing a second implementation with the same guarantees and a new set of bugs.

---

## 5. The re-derivation map

One row per seed, summarising the guarantee its owning doctrine states. The map is a reading aid; the
precondition of [§4](#4-the-re-derivation-rule-name-the-guarantee-you-are-adding) is discharged where the
structure is specified, and the fourth column names where that is.

| Seed | Structure amoebius re-derives | The guarantee amoebius must add |
|---|---|---|
| `hostbootstrap` | the host-lift algebra (`chain` / `Step` / `Lift` / `Context`), substrate detection, and the encode/decode codec witness | **Totality of the lift relation.** The seed's dispatch has a fallback arm, so an unhandled frame is a run-time surprise; amoebius makes frame × engine a total function whose absent pairs have no constructor, and extends the codec witness from configuration to *every* generated artifact |
| `prodbox` | typed manifest rendering, Dhall decode behind smart constructors, schema reflected from Haskell types, and the generated-path registry | **No tracked generated file exists to reconcile.** The seed tracks generated output and reconciles it four ways; amoebius deletes the tracked copy, so drift between a generator and its output is not detected but unrepresentable ([`generated_artifacts_doctrine.md`](./generated_artifacts_doctrine.md)) |
| `jitML` | the numerical core, autodiff, JIT codegen, the determinism kernel, and the content-addressed checkpoint store | **The budget is inseparable from the store.** The seed's cache grows without a type that bounds it; amoebius makes the storage grant carry its ceiling and its concurrency together, and makes reaping an obligation the type system tracks ([`jit_budget_doctrine.md`](./jit_budget_doctrine.md)) |
| `infernix` | inference orchestration, engine-pool routing, durable-context event sourcing, and the zero-tracked-generation discipline | **Two scope identifiers exchangeable at a call site stop being representable.** The seed scopes a *resource* with a rank-2 region and leaves tenancy to a comparison a caller can transpose; amoebius skolemises the identity itself, so the transposed call does not typecheck ([`../illegal_state/illegal_state_tenancy.md` §3.94](../illegal_state/illegal_state_tenancy.md#394-two-same-typed-scope-identifiers-exchangeable-at-a-call-site), by the skolem scope of [`../illegal_state/illegal_state_techniques.md` §4.8](../illegal_state/illegal_state_techniques.md#48-the-skolem-scope--a-runtime-tenant-becomes-a-compile-time-index)) |
| `mattandjames` | the multi-tenant web shape — gateway, identity, offline-first intent queue, cached stateless sockets, and the relational data plane | **Insecure states stop being representable.** The seed can express an unauthenticated route taking its scope from the caller, a match-all filter default, and a locally rebuilt session; under the security laws each of those has no inhabitant ([`extension_conformance_security.md`](./extension_conformance_security.md), [`../illegal_state/illegal_state_tenancy.md`](../illegal_state/illegal_state_tenancy.md)) |

---

## 6. Convergence is the evidence

The strongest argument that this architecture is right is not that it sounds principled. It is that the seeds
**arrived at the same shapes independently**, with no code dependency between them and no shared plan. Three
observations from the seed trees:

- **The same four-constructor lift layer, written twice.** Two seeds independently model "where does this step
  run" as a four-arm sum with the same four arms. Neither imports the other.
- **The same five-constructor substrate enumeration, written twice.** Two seeds independently close the set of
  hardware substrates at the same five values, in the same order of generality.
- **"The binary writes its own configuration during the image build", invented twice.** Two seeds independently
  concluded that a configuration file should be produced by the program that consumes it, at build time, rather
  than authored beside it.

A shape reached twice without a code dependency is a candidate for a shape the problem forced rather than one a
designer preferred. **The independence here is between codebases, not between designers** — the seeds share
authorship, so the convergence is common-cause as easily as it is forced, and the inference is correspondingly
weaker than "the problem forced it". What survives is that the shape was reached twice under different
pressures, in different domains, without one being able to borrow from the other.

At that strength it still does the work asked of it: the convergent shapes are the candidates for the fixed
algebra, and the divergent ones are the candidates for extension points. The convergence is *evidence*, on the
terms of [§3](#3-a-seed-is-a-reference-implementation) — it argues the algebra is discoverable, and proves
nothing about amoebius until an amoebius gate says so.

---

## 7. The lift calculus

"Lift" survives the inversion as a technical term, and this section is its owner. A lift is not a decision to
reuse code; it is the answer to a question with a closed set of answers: **where does an effect run, and what
does the caller have to hold to make it run there?**

The calculus has three parts:

- **A closed layer set.** Every effect executes at exactly one layer — on the host, inside a frame the host
  provides, inside a container that frame runs, and so on outward. The set is closed, so "somewhere else" has
  no constructor, and the layer at which a step runs is part of its type rather than part of its documentation.
- **A total transition relation.** Moving an effect from one layer to another is a relation over the layer set,
  and it is total: every pair either has a constructor that performs the transition or has no inhabitant at
  all. There is no fallback arm, which is the guarantee [§5](#5-the-re-derivation-map) records against `hostbootstrap`.
- **A witness for each transition.** A transition consumes evidence that its precondition holds — that the
  frame exists, that the engine is present, that the image is resolved. The witness is produced by observation
  and cannot be asserted, so a step cannot claim to have crossed a boundary it did not cross.

Composition follows from the three: two lifts compose exactly when the inner one's target layer is the outer
one's source layer, which is a type equation rather than a check. The substrate-specific instances of this
calculus — which frames exist on which hardware, and which engine each frame provides — are owned by
[`substrate_doctrine.md`](./substrate_doctrine.md), which reads this algebra rather than restating it.

**Phase-5 target boundary — NOT VALIDATED.** [Phase 5](../../DEVELOPMENT_PLAN/phase_05_lift_calculus.md) must
cover all three parts as pure values in Register 1: the layer set closed at three members, the relation total over all
nine ordered pairs with no fallback arm, a witness per transition that only an observation produces, and
composition as the type equation above. Three things it did not settle. The set is closed *at three* — the
"and so on outward" this section allows for is a change to that module rather than something the code already
carries. The relation is over primitive transitions and is deliberately not transitive, so reaching a
container from the host is a composition and not a relation arm. And nothing in that register enters a frame
or asks an engine, so every witness there is produced from an observation the suite hands it; the live
observation is the substrate doctrine's. Status lives only in the
[tracker](../../DEVELOPMENT_PLAN/README.md).

---

## 8. Permanently invalidated lift-era run history

Four phases ran under the old doctrine. Their pre-reset reports are retained only as permanently invalidated
diagnostic history and cannot establish any current result. Those reports attributed scoped Vault challenges,
native Pulsar duplicate collapse, object-store publication equality, cache and compute observations, cleanup,
and mutants to Phase 91; handle/receipt composition and Chrome observations to Phase 92; CUDA code generation,
PTX execution, and retained object-store publication to Phase 93; and a UI lift, mutants, and host-CUDA
computation to Phase 94.

Every one of those instances depended on compiling seed source into an amoebius package, which is exactly what
[§2](#2-the-two-non-dependencies) now forbids. The old reports may inform future challenge design, but they do
not validate the *seams* or the *lifts*: the thing they exercised is no longer the thing amoebius
intends to build. Each of those phases owes a re-derivation under [§4](#4-the-re-derivation-rule-name-the-guarantee-you-are-adding) and a re-run of its gate against it. Typed Haskell
bindings own that executable audit map; their reader-facing explanation is
[`legacy_tracking_for_deletion.md`](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md).

---

## 9. Planning ownership

This document is normative only. Which phase re-derives which structure is owned by
[DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md) and
[system_components.md](../../DEVELOPMENT_PLAN/system_components.md); typed Haskell bindings own the executable
removal inventory and audit map, while
[legacy_tracking_for_deletion.md](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) explains them to
readers. Normative shapes are
design intent. Only a complete phase-specific qualified gate pass with separately authored oracles could
establish an amoebius result; every current phase is NOT VALIDATED.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [Extension Conformance Doctrine](./extension_conformance_doctrine.md) — the obligation surface a re-derived structure must satisfy to be composable at all
- [Extension Conformance Security](./extension_conformance_security.md) — the security laws the `mattandjames` re-derivation row discharges
- [Substrate Doctrine](./substrate_doctrine.md) — the substrate-specific instances of the [§7](#7-the-lift-calculus) lift calculus
- [Formal Model Doctrine](./formal_model_doctrine.md) — why the proof stack is forked rather than consumed, the same argument [§1](#1-why-this-doctrine-exists) makes about seeds
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md) — the `prodbox` row's guarantee: nothing generated is tracked
- [JIT Budget Doctrine](./jit_budget_doctrine.md) — the `jitML` row's guarantee: the grant carries its ceiling
- [Illegal-State Catalog](../illegal_state/illegal_state_catalog.md) — where a named guarantee resolves to a foreclosed state
- [Low-Code UI Runtime Doctrine](./low_code_ui_runtime_doctrine.md) — the UI seam the `infernix` and `mattandjames` rows re-derive against
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — the `prodbox` row's rendering seam
- [Pulsar Client Doctrine](./pulsar_client_doctrine.md) — the precedent: a load-bearing client is owned, not consumed
- [Vault / PKI Doctrine](./vault_pki_doctrine.md) — secrets by name, the seam every seed's credential handling is re-derived onto
- [Content Addressing Doctrine](./content_addressing_doctrine.md) — the `jitML` row's naming discipline
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — re-derivation is Register-1/2 validatable
- [App vs Deployment Doctrine](./app_vs_deployment_doctrine.md) — the line a re-derived structure must not blur
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
