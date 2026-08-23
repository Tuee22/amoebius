# JIT Artifact Doctrine

> **Purpose**: Single source of truth for the **artifact calculus** — the rule that every non-`.hs` artifact
> amoebius needs is *generated from pure Haskell types* rather than authored, the closed exception list that
> rule admits, content-derived addressing that folds the rendered text into its own name, and the
> materialize → consume → reap lifecycle that makes "deleted once no longer needed" a type rather than an
> intention.
> **Read this if**: a file that is not Haskell source is about to be added to the repository, or an artifact's
> name, lifetime, or retention has to be reasoned about.

This document owns the artifact calculus: targets, recipes, addresses, and the artifact lifecycle. It does not
own the budget those artifacts are charged against, the workflow that materializes them, or the container image
that consumes them; each names its own doctrine.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_47_tool_and_mutant_generation.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, README.md, documents/engineering/README.md, documents/engineering/dsl_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_laws.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/jit_budget_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

</details>

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. The rule, and the closed exception list](#2-the-rule-and-the-closed-exception-list)
- [3. Targets and recipes](#3-targets-and-recipes)
- [4. The address folds in the rendered text](#4-the-address-folds-in-the-rendered-text)
- [5. Materialize, consume, reap](#5-materialize-consume-reap)
- [6. Ephemeral and retained](#6-ephemeral-and-retained)
- [7. Goldens become oracles](#7-goldens-become-oracles)
- [8. What this does not give](#8-what-this-does-not-give)
- [9. Planning ownership](#9-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

A repository that tracks a generated file has two statements of one fact — the generator and its output — and
they diverge the first time one of them is edited. Nothing reports it: the stale copy is well formed, the build
succeeds, and the reader has no way to tell which of the two is current. The corpus already recognises this for
a few classes ([`generated_artifacts_doctrine.md`](./generated_artifacts_doctrine.md)); this doctrine
generalises it to a rule with no exceptions except bootstrapping ones.

The generative turn is also what makes the algebra reachable. Every calculus in the core is stated over *pure
values*, and an artifact that is authored is not a value the core can reason about — it is a file the core
hopes matches. Once artifacts are functions of declarations, an extension's outputs are as inspectable as its
types, which is what lets a conformance gate be derived rather than written
([`extension_conformance_doctrine.md` §5](./extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored)).

This generalises jitML's insight beyond machine learning. jitML compiles numerical kernels on demand, names
them by content, and caches them under a budget, because writing them out ahead of time is both wasteful and a
source of drift. Nothing about that argument is specific to numerics. A Dhall schema, a container recipe, a
Kubernetes manifest, a SQL migration, a PureScript contract, and a build mutant are all the same kind of thing:
a rendering of a declaration the program already holds.

---

## 2. The rule, and the closed exception list

> **Every behavioral artifact that is not tracked Haskell source is generated lazily from Haskell beneath
> `.build/**`. Python under `pb/**` is the sole source-language exception.**

The target tracked-tree classification is closed and is to be enforced by a deny-by-default Haskell
source/effect audit; this table is a reader-facing explanation and is never parsed as an allowlist. It is
intentionally not an “independent expectation” exception: independently authored expectations are Haskell
values, while their serialized encodings are generated. The repository-layout doctrine owns the exact path
grammar. The completed audit must join that grammar to a complete semantic consumer/effect graph, traverse
every authored root through a descriptor-relative no-follow walk, authenticate immutable source blobs and the
network-independent toolchain input, and qualify the `pb/**` argv/`exec` effects under an observer outside the
bootstrap. Metadata and documentation receive only structural checks and human review, which can never admit a
behavioral artifact.

**Observed footprint / Known partial — NOT VALIDATED.** The current Haskell source-closure components are
partial diagnostics recorded in the tracker’s
[current implementation audit](../../DEVELOPMENT_PLAN/README.md#current-implementation-audit). They do not yet
establish the complete semantic consumer/effect graph, the descriptor-relative no-follow authored-root walk,
authenticated blob/tool acquisition, changed-production qualification, or independent human review. Their
presence therefore establishes neither a completed source/effect audit nor a qualified `pb/**` exception.

| Exception | Why it must exist first |
|---|---|
| `pb/` Python sources | The bounded pre-binary handoff makes the minimum platform-adapter distinction, establishes the contained toolchain, builds Haskell, and `exec`s the binary with argv unchanged. It is not the Haskell `BootstrapCoordinator` and never decides validation or product behavior |
| Cabal project and package descriptions | Consumed by the compiler that builds the generator. Generating them would require the generator to already be built |
| The ignore contracts | Read by version control and the container builder, both of which act on the tree before and around any amoebius process |
| Governance prose and licences | Human requirements and legal text are non-source inputs; generated documentation still belongs under `.build/docs/**` |

Everything else is generated: Dhall schemas and values, the container recipe and bake catalog, rendered
manifests, SQL, PureScript/JavaScript source and bundles, shell helpers, Proto, Pulumi programs, serialized
fixtures/oracles, checking tools, and materialized mutants. Operator values are external or untracked inputs,
not a source exception.

Checking mechanisms and expectations are separately reviewed Haskell source. A checker may lazily emit an
external-language helper or encoded corpus, but that emitted half never decides its own verdict. The
expectation remains independent because it is authored from the requirement in a distinct Haskell module and
subject to human review, not because a serialized file is tracked.

**What this forecloses.** A second home for a class of artifact. Once the tracked copy is gone there is no
place for drift to hide, which is the guarantee
[`lift_and_compose_doctrine.md` §5](./lift_and_compose_doctrine.md#5-the-re-derivation-map) records against
`prodbox`: not a better reconciliation of tracked generated files, but nothing left to reconcile.

---

## 3. Targets and recipes

The calculus has two nouns.

A **target** is the kind of artifact, and it is a type index rather than a string. `Target DhallSchema` and
`Target ContainerRecipe` are different types, so a consumer expecting one cannot be handed the other, and the
set of targets is closed — adding a kind of artifact is a change to the core, not a new string in a
configuration file.

A **recipe** is a pure function from a declaration to rendered content, at a target. It is pure in the strong
sense L2 requires: no clock, no environment, no directory listing, no unordered traversal
([`extension_conformance_laws.md` §L2](./extension_conformance_laws.md#l2-determinism)). A recipe that needs an
observation of the world takes it as an argument, so the observation is part of the declaration and therefore
part of the address.

From the two nouns everything else follows. The artifact set of an extension is the image of its declared
recipes, which is a value; the artifact set of a composition is the union of those images, which is why C7 can
speak about disjointness at all.

---

## 4. The address folds in the rendered text

An artifact's name is a content address, and the content it addresses includes **the rendered bytes
themselves**, not only the inputs that produced them. The address is a digest over the target, the recipe's own
identity, the declaration, and the rendering.

Folding the output into its own name looks redundant — if the recipe is deterministic, the inputs determine the
output — and it is exactly the redundancy that matters. It converts L2 (determinism) from a property somebody
asserts into a property the naming scheme detects: two runs producing different bytes produce different
addresses, so the disagreement surfaces as a cache miss rather than as a silently reused stale artifact. It
also makes a recipe change and an input change indistinguishable to consumers, which is correct, because both
mean *this artifact is not the one you had*.

The rendering is **total**, on the terms
[`../illegal_state/illegal_state_techniques.md` §4.5](../illegal_state/illegal_state_techniques.md#45-content-address-totality--names-are-total-functions-of-content)
fixes: every artifact has an address, and equal content yields one address.

It is **not injective**, and the word is worth refusing here because the corpus uses it correctly elsewhere. A
digest over unbounded content cannot be injective — there are more contents than digests. What the scheme has
is collision resistance, which is a cryptographic assumption about the hash rather than a property of a type,
and it is an assumption every claim in this section rests on. (Injectivity *is* achievable, and is required, for
a bounded scope-key encoding; that is a different rendering, owned by
[`extension_conformance_security.md` S5](./extension_conformance_security.md#4-s1s6).)

This is what C7 (address collision) consumes: under the assumption, two extensions do not land on one address
without rendering identical content, and if they render identical content they are the same artifact.

---

## 5. Materialize, consume, reap

An artifact's existence is a **region**, not a fact about the filesystem. The three operations:

- **Materialize.** Given a recipe, a declaration, and a grant, produce the bytes and place them at their
  address. Materialization consumes budget ([`jit_budget_doctrine.md`](./jit_budget_doctrine.md)) and yields a
  handle. It is idempotent: materializing an address that exists is a hit, and the calculus does not
  distinguish the two for the consumer.
- **Consume.** A consumer takes the handle, never a path. There is no operation from an address to a filesystem
  location outside the region, so an artifact cannot be referenced after its region ends — the same escape
  argument the skolem scope uses for identity
  ([`extension_conformance_security.md` §3](./extension_conformance_security.md#3-the-skolem-scope)).
- **Reap.** Leaving the region reaps every artifact materialized within it that was not promoted to retained.
  Reaping is not a cleanup step somebody schedules; it is what region exit *means*, so an artifact with no
  retention decision cannot survive its region.

The consequence is the one the corpus has been missing: **"deleted once no longer needed" becomes a type.**
Today that phrase appears in prose as an intention, and an intention is discharged by whoever remembers. Here,
not deciding is not an option the type offers — an artifact is retained with a stated condition, or it is
ephemeral and gone.

---

## 6. Ephemeral and retained

The two dispositions differ in exactly one way, and it is not lifetime.

An **ephemeral** artifact is charged against the region's grant and released at region exit. Its cost is
bounded by the region, so the only question its budget asks is whether the region's ceiling is high enough.

A **retained** artifact outlives its region, so it is charged against a *retention* grant, and that grant
demands the thing an ephemeral one does not: a **reaper** — the condition under which the artifact stops being
needed. A reaper is a value, not a comment: an eviction policy, a generation bound, a dependent's lifetime. An
artifact promoted to retained without one has no constructor, which is L3 (budget honesty) at this seam.

Promotion is explicit and one-way. There is no demotion, because an artifact something else already depends on
cannot be made ephemeral by a later decision; the dependent would be the thing that breaks, and it is not
present to object.

---

## 7. Goldens become oracles

A byte golden of generated output is a test of the generator against a copy of its own past output. It catches
accidental change and nothing else — it cannot tell a correct change from an incorrect one, and the usual
response to a red golden is to regenerate it, which is the test being deleted one file at a time.

Under this calculus the golden is also redundant with the address: a change in the rendered bytes is already a
change in the name, so "did the output change" is answered by the calculus and needs no fixture.

What replaces it is a **Haskell semantic oracle**: an independently authored predicate over the rendered artifact,
asserting the property the artifact exists to have. That a rendered manifest declares no privileged container.
That an emitted schema's every scope-bearing table carries its constraint. That a container recipe's every
layer is reachable from a declared stage. An oracle is written from the requirement rather than from the
output, so it stays red when the generator is wrong, which is the whole job
([`testing_doctrine.md`](./testing_doctrine.md)).

---

## 8. What this does not give

- **It does not make the recipes correct.** A deterministic, budgeted, injectively named rendering of the wrong
  content is all of those things and still wrong. That is the [§7](#7-goldens-become-oracles) oracle's job.
- **It does not remove the bootstrap boundary.** Python beneath `pb/**` is the sole target bounded
  source-language exception. Its completed qualification must observe actual argv/`exec` effects from outside
  the bootstrap, and its deny-by-default Haskell source/effect audit must close the semantic consumer/effect,
  no-follow authored-root, authenticated blob/tool, changed-production qualification, and independent-review
  gaps stated in [§2](#2-the-rule-and-the-closed-exception-list). The current partial footprint does not do so.
  Prose and filename conventions cannot widen the target classification. Repository/build metadata and
  documentation receive structural checks and human review only. No product behavior, test expectation,
  oracle, mutant, fixture, recipe, or generated source is admitted merely because a human reviewed a
  non-Haskell artifact: those declarations remain Haskell, and every serialized projection is materialized
  lazily beneath `.build/**`.
- **It does not establish delivery status.** Which recipes exist and which gates have been independently
  accepted belongs only to the [tracker](../../DEVELOPMENT_PLAN/README.md). This doctrine carries no current
  validation claim.

---

## 9. Planning ownership

This document is normative only. Which phase delivers the target set, the recipes for each artifact class, the
addressing scheme, and the region is owned by [DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md).
Normative shapes are design intent. Candidate evidence becomes accepted phase status only through the plan's
human-controlled promotion procedure; this doctrine records no tested instance.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [JIT Budget Doctrine](./jit_budget_doctrine.md) — the grant [§5](#5-materialize-consume-reap) spends and the retention grant [§6](#6-ephemeral-and-retained) demands
- [Workflow Calculus Doctrine](./workflow_calculus_doctrine.md) — the workflows that open and close artifact regions
- [Evidence Calculus Doctrine](./evidence_calculus_doctrine.md) — why an expectation is authored independently as Haskell while its encodings remain generated
- [Extension Conformance Doctrine](./extension_conformance_doctrine.md) — the obligation surface an extension's artifact component fills
- [Extension Conformance Laws](./extension_conformance_laws.md) — L2, L3, and C7, the laws stated over this calculus
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md) — the narrower rule this doctrine generalises
- [Content Addressing Doctrine](./content_addressing_doctrine.md) — pointers, manifests, and blobs, the addressing machinery [§4](#4-the-address-folds-in-the-rendered-text) reuses
- [Content Addressing Determinism](./content_addressing_determinism.md) — the determinism discipline the address detects violations of
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — one recipe class: typed rendering of the object set
- [Image Build Doctrine](./image_build_doctrine.md) — another: the container recipe and its published tags
- [DSL Doctrine](./dsl_doctrine.md) — the Dhall surface whose schema is itself a generated artifact
- [Repository Layout Doctrine](./repository_layout_doctrine.md) — the target tree the exception list is expressed against
- [Testing Doctrine](./testing_doctrine.md) — the oracle discipline [§7](#7-goldens-become-oracles) invokes
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
