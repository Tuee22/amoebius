# Amoebius Reading Order

> **Purpose**: The sequence in which the amoebius corpus is read by someone meeting it for the first time.
> **Read this if**: the corpus is unfamiliar and the question is where to start rather than what a given document says.

This document owns the *order*, and nothing else. Every index in the corpus — the
[engineering doctrine index](./engineering/README.md), the
[illegal-state family](./illegal_state/README.md), the
[plan tracker](../DEVELOPMENT_PLAN/README.md) — groups documents by subject; none of them says which to open
first, and subject order is not reading order. The stops below name what each document establishes and where
to stop reading it; the documents themselves remain the only authority on their content. Nothing here presumes
prior knowledge, but every stop presumes the stops above it.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: README.md, documents/README.md, documents/documentation_standards.md, documents/engineering/README.md, documents/glossary.md
**Generated sections**: none

</details>

## Contents
- [Before starting](#before-starting)
- [Stop 1. What amoebius is](#stop-1-what-amoebius-is)
- [Stop 2. The one idea — illegal states are unrepresentable](#stop-2-the-one-idea--illegal-states-are-unrepresentable)
- [Stop 2b. The algebra and the laws](#stop-2b-the-algebra-and-the-laws)
- [Stop 3. The description language](#stop-3-the-description-language)
- [Stop 4. From description to effect](#stop-4-from-description-to-effect)
- [Stop 5. What the gates establish, and what they do not](#stop-5-what-the-gates-establish-and-what-they-do-not)
- [Stop 6. The plan](#stop-6-the-plan)
- [Stop 7. Where to go next, by role](#stop-7-where-to-go-next-by-role)
- [Related Documents](#related-documents)

---

## Before starting

> **Doctrine describes the target; it is not implementation or validation evidence.** Candidate gate output
> cannot promote itself. Only the human-controlled plan records phase status, after independent expectations,
> sabotage controls, predecessor order, and the applicable hardware-free barrier have been reviewed.

- [`glossary.md`](./glossary.md) — open in a second tab and leave it open; every stop below assumes it.

The whole path runs about three hours. Stops 1 and 2 alone, about forty minutes, are enough to follow a design
discussion.

## Stop 1. What amoebius is

- [`DEVELOPMENT_PLAN/overview.md` §1](../DEVELOPMENT_PLAN/overview.md#1-the-everything-orchestrator-shape-one-runtime-binary-three-contexts) — one binary, three contexts, and the shape of the whole system.
- [`DEVELOPMENT_PLAN/overview.md` §2](../DEVELOPMENT_PLAN/overview.md#2-the-seed-projects-reference-implementations-amoebius-re-derives-from) — the five seed projects amoebius re-derives from, and why depending on none of them is the point.
- [`repository_layout_doctrine.md` §1](./engineering/repository_layout_doctrine.md#1-classification-rule) — the closed source boundary: behavioral source is Haskell, `pb/**` is the sole source-language exception, and everything else is generated lazily or supplied externally.

Stop there. The invariant table in
[§3](../DEVELOPMENT_PLAN/overview.md#3-the-hard-constraints-cross-cutting-invariants) and the phase index in
[§4](../DEVELOPMENT_PLAN/overview.md#4-the-phase-index-one-line-per-phase) are reference material for stop 6.

## Stop 2. The one idea — illegal states are unrepresentable

Everything else in the corpus is downstream of this stop. The foreclosure layers below are stated in the
vocabulary of the validation registers, so that stop comes first.

- [`testing_doctrine.md` §2](./engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) — the registers of evidence, and what each one can and cannot reach.
- [`illegal_state_techniques.md` §4](./illegal_state/illegal_state_techniques.md#4-the-typing-techniques) — the nine construction patterns that do the work.
- [`illegal_state_techniques.md` §6](./illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force) — the three foreclosure layers, and why the strongest is rarely available.
- [`illegal_state_techniques.md` §6.1](./illegal_state/illegal_state_techniques.md#61-the-validation-locus-axis--where-each-illegal-state-is-caught-orthogonal-to-the-foreclosure-layer) — the orthogonal axis naming where a state is actually caught.
- [`illegal_state_catalog.md` §3](./illegal_state/illegal_state_catalog.md#3-the-catalog--states-a-valid-spec-cannot-represent) — skim the enumeration, then read three entries in full. Three, not eighty.

**Then read why the catalogue is finishable.** The list above is a technique set; the claim that it *covers*
its subject rests on the covering obligation, and the claim that it survives an open set of domains rests on
the algebra. Both are short:

- [`documentation_standards.md` §16](./documentation_standards.md#16-the-illegal-state-catalogue-is-a-covering-not-a-list) — why the catalogue is a covering over a declared taxonomy, and why an unjustified empty cell is a defect.
- [`illegal_state/README.md`](./illegal_state/README.md) — the three axes that taxonomy names, and what is specified versus discharged.

## Stop 2b. The algebra and the laws

This is the stop that makes the previous one hold for code nobody has written yet. amoebius is an **open core**:
it admits extensions carrying arbitrary logic, so it cannot enumerate its compositions and instead proves that
lawful instances compose.

- [`extension_conformance_doctrine.md` §1](./engineering/extension_conformance_doctrine.md#1-why-this-doctrine-exists)–[§3](./engineering/extension_conformance_doctrine.md#3-the-obligation-surface-one-component-per-calculus) — why an open core needs a contract, and the five-component obligation surface that is the whole of it.
- [`extension_conformance_doctrine.md` §7](./engineering/extension_conformance_doctrine.md#7-link-time-union-closure) — the closure argument: read this one carefully, it is the load-bearing claim.
- [`extension_conformance_laws.md` §2](./engineering/extension_conformance_laws.md#2-how-to-read-a-law) — how a law is stated, then skim L1–L5 and C1–C7.
- [`extension_conformance_security.md` §3](./engineering/extension_conformance_security.md#3-the-skolem-scope) — the one mechanism five of the six security laws rest on.
- [`lift_and_compose_doctrine.md` §2](./engineering/lift_and_compose_doctrine.md#2-the-two-non-dependencies) — why amoebius owns what it must prove, and what a seed project is for.

## Stop 3. The description language

- [`dsl_doctrine.md` §2](./engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic) — the split between external, untracked Dhall values and version-controlled Haskell logic.
- [`app_vs_deployment_doctrine.md` §1](./engineering/app_vs_deployment_doctrine.md#1-two-surfaces-one-app-written-once) — the split that lets one application run many ways unchanged.
- [`service_capability_doctrine.md` §2](./engineering/service_capability_doctrine.md#2-the-capability-set) — the abstract service roles an application names instead of products.

## Stop 4. From description to effect

This is the spine: how an external operator value or a version-controlled Haskell declaration becomes a
running cluster. External-language materializations are lazy `.build/**` products, never a second tracked
source surface.

- [`dsl_doctrine.md` §5](./engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) — the contract stop 2 described, stated as the language's own guarantee.

- [`resource_capacity_doctrine.md` §1](./engineering/resource_capacity_doctrine.md#1-capacity-is-a-budget-the-fold-consumes-and-overcommit-is-a-checked-rejection) — capacity as a budget a fold consumes, and overcommit as a checked rejection.
- [`resource_capacity_doctrine.md` §2](./engineering/resource_capacity_doctrine.md#2-the-load-bearing-honesty-limit-a-capacity-sum-is-a-decode-foreclosed-check-never-type-foreclosed) — the honesty limit that keeps the whole model from overclaiming.
- [`manifest_generation_doctrine.md` §1](./engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not) — why manifests are rendered from types rather than templated.
- [`manifest_generation_doctrine.md` §2](./engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects) — the sealed value and the single public function that consumes it.
- [`cluster_lifecycle_doctrine.md` §9](./engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine) — the reconcile loop, and why it is deliberately not a state machine.
- [`bootstrap_sequence_doctrine.md` §4](./engineering/bootstrap_sequence_doctrine.md#4-the-host-daemon--control-plane-daemon-handoff) — the one moment authority moves from the host to the cluster.

## Stop 5. What the gates establish, and what they do not

The corpus is unusually careful about the difference between proving something and testing it. This stop is
what makes the rest of it readable at face value.

- [`documentation_standards.md` §6](./documentation_standards.md#6-honesty-the-proventestedassumed-discipline) — the rule every claim in the corpus is written under.
- [`chaos_failover_doctrine.md` §6](./engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives) — why one boundary carries the whole formal obligation and the rest delegate.
- [`formal_model_doctrine.md` §6](./engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not) — the boundary between what the model establishes and what the code must still earn.
- [`gateway_migration_doctrine.md` §5](./engineering/gateway_migration_doctrine.md#5-the-migration-as-a-typed-edge-observed-state-machine) — the one place that obligation concentrates, drawn as a state machine.

The first promotion barrier is hardware-free: the DSL parser/typechecker/decoder, pure semantics, generation
determinism, independent Haskell expectations, negative controls, and source-boundary audit must be accepted
before live container, cluster, browser, provider, accelerator, or other hardware-specific replay can count as
downstream evidence. Later replay checks portability; it cannot stand in for the language result it consumes.

## Stop 6. The plan

- [`DEVELOPMENT_PLAN/README.md`](../DEVELOPMENT_PLAN/README.md) — the tracker; the only place phase order, status, and gates live.
- [`development_plan_standards.md` §M](../DEVELOPMENT_PLAN/development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) — the fixed eighteen-row contract that stops a gate from being passable by a stub.
- [`development_plan_standards.md` §K](../DEVELOPMENT_PLAN/development_plan_standards.md#k-honesty-proven--tested--assumed) — how stop 5's discipline binds a phase before it may be marked done.
- [`development_plan_standards.md` §C](../DEVELOPMENT_PLAN/development_plan_standards.md#c-status-vocabulary) — status is a human decision; a command, script, generated report, or agent may produce candidate evidence but may not mark a sprint or phase Done or Validated.
- [`development_plan_standards.md` §L](../DEVELOPMENT_PLAN/development_plan_standards.md#l-one-substrate-discipline) — later hardware evidence stays scoped to the one natural substrate actually exercised and cannot be generalized to an untested substrate.

Work proceeds in numerical phase order. A later hardware-dependent gate does not compensate for an open or
unaccepted predecessor, and no hardware provisioning should begin merely to validate a language surface that
has not crossed the hardware-free barrier above.

## Stop 7. Where to go next, by role

> **Read this if** the goal has narrowed from the whole system to one subsystem.

Each row below is an entry point, not a sequence; the doctrine index carries the rest.

- [`engineering/README.md`](./engineering/README.md) — the full doctrine index, grouped by subject.
- [Platform and cluster](./engineering/README.md#platform--cluster) — for bring-up, platform services, storage, and networking.
- [Secrets, identity, and infrastructure-as-code](./engineering/README.md#secrets-identity-iac) — for the secret store, the trust anchor, and provider provisioning.
- [Runtime, transport, and determinism](./engineering/README.md#runtime-transport-determinism) — for the message bus, the content store, and reproducibility.
- [Verification](./engineering/README.md#verification) — for testing, simulation, conformance, and the formal model.
- [`illegal_state/README.md`](./illegal_state/README.md) — for the enumerated catalog, by theme.
- [`documentation_standards.md`](./documentation_standards.md) — for writing or reviewing a document in this corpus.

---

## Related Documents
- [Glossary](./glossary.md) — the term registry every stop above assumes
- [Documentation Standards](./documentation_standards.md) — the rules the corpus is written under
- [Engineering Doctrine Index](./engineering/README.md) — subject grouping, where this file gives sequence
- [Illegal State Catalog](./illegal_state/illegal_state_catalog.md) — the enumeration stop 2 samples
- [Development Plan](../DEVELOPMENT_PLAN/README.md) — phase order and status, owned there and never restated here
