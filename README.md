# amoebius

> **Purpose**: Introduce the amoebius distributed-systems core and route readers to its design and development plan.
> **Read this if**: the project is unfamiliar or its architecture and validation boundaries need an entry point.

amoebius targets a Haskell core for describing deployments, applications, and hardware capabilities through
five composable calculi. This page provides orientation. Architecture belongs to
[`documents/`](./documents/README.md); implementation progress and validation status belong to the
[development plan](./DEVELOPMENT_PLAN/README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: documents/engineering/daemon_topology_doctrine.md
**Generated sections**: none

</details>

## Target architecture

The design composes artifact, budget, lift, workflow, and evidence values. An extension supplies the required
semantics and satisfies independently specified laws. The
[extension contract](./documents/engineering/extension_conformance_doctrine.md) owns admission and composition
requirements; adding a declaration alone does not establish those laws.

One Haskell runtime is specified to serve host, control-plane, scheduler, and worker responsibilities.
External, untracked operator values describe deployments and bounded UI applications. Their checked
representations feed binding, planning, provisioning, rendering, and effect execution. The
[DSL doctrine](./documents/engineering/dsl_doctrine.md) and
[daemon topology](./documents/engineering/daemon_topology_doctrine.md) own these boundaries.

The target UI compiles one checked program into matching client and server plans. Generic interpretation,
authorization, typed effects, and offline behavior remain obligations of the
[UI runtime](./documents/engineering/low_code_ui_runtime_doctrine.md) and
[offline runtime](./documents/engineering/browser_offline_runtime_doctrine.md) doctrines.

Hardware capabilities are specified at each substrate's natural architecture. Native execution, image
publication, registry operation, and live service behavior require their own observations. The
[substrate doctrine](./documents/engineering/substrate_doctrine.md) and
[image-build doctrine](./documents/engineering/image_build_doctrine.md) own those requirements.

## Validation boundaries

A type restriction, bounded model result, semantic test, fake-boundary test, and live observation establish
different claims. A finite test corpus does not prove the entire language. A generated report, content digest,
or opaque Haskell value does not establish that its claimed operation occurred.

The [formal-model doctrine](./documents/engineering/formal_model_doctrine.md#6-what-a-green-model-check-proves-and-what-it-does-not)
defines proof scope. The [spoof-resistance doctrine](./documents/engineering/testing_spoof_resistance.md)
defines acceptance and observation boundaries. Current certification and the reset's repair work are recorded
only in the [tracker](./DEVELOPMENT_PLAN/README.md#current-implementation-audit).

Development can progress automatically through ready sprints. A complete qualified phase run permits its exact
status-only transition and the next numerical gate. Candidate changes must not redefine the accepted
requirements used to judge that run. The
[gate-integrity contract](./DEVELOPMENT_PLAN/development_plan_gate_integrity.md) owns this procedure.

## Where to start

- [Reading order](./documents/reading_order.md): a guided route through the design.
- [Glossary](./documents/glossary.md): terms and their canonical owners.
- [Development plan](./DEVELOPMENT_PLAN/README.md): phase order, current status, and remaining work.
- [Documentation index](./documents/README.md): architecture and domain references.
- [Testing doctrine](./documents/engineering/testing_doctrine.md): registers, expectations, and test lifecycles.
- [Repository layout](./documents/engineering/repository_layout_doctrine.md): tracked source and generated state.
- [Documentation standards](./documents/documentation_standards.md): ownership, structure, and claim discipline.

## Toolchain

The bounded Python bootstrap under `pb/**` is specified to establish the toolchain, build the source-bound
Haskell executable, and replace itself with that executable while preserving every argument. Haskell owns
commands and verdicts. The bootstrap cannot validate its own handoff.

The [validation-execution doctrine](./documents/engineering/validation_frame_doctrine.md) owns bootstrap trust,
tool authentication, and execution boundaries. Before handoff validation, gates invoke the source-bound
Haskell executable directly. Required generated tools and artifacts stay beneath the repository roots defined
by the [layout doctrine](./documents/engineering/repository_layout_doctrine.md).

## Working agreement

[`AGENTS.md`](./AGENTS.md) owns agent conduct, including serial compiler execution and the prohibition on
agent staging, committing, or pushing. [`CLAUDE.md`](./CLAUDE.md) imports that file mechanically.

## Related Documents

- [Development-plan standards](./DEVELOPMENT_PLAN/development_plan_standards.md): phase contracts and progression.
- [Lift and compose](./documents/engineering/lift_and_compose_doctrine.md): domain re-derivation and seed boundaries.
- [Evidence calculus](./documents/engineering/evidence_calculus_doctrine.md): claim-scoped evidence composition.
