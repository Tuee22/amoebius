# Generated Artifacts: emitted from a source of truth, never committed

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_10_chain_kernel_dryrun.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_13_spa_composition_representational.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, DEVELOPMENT_PLAN/phase_34_jitml_lift_cuda.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/tla_modelling_assumptions.md
**Generated sections**: none

> **Purpose**: Single source of truth for the rule that every artifact amoebius can *render from a typed source* — Kubernetes manifests, the TLA+ `.tla`/`.cfg`, the Dhall schema, the PureScript frontend contracts — is a **build artifact emitted at build/check time and never committed to the repository**; the only committed truth is the Haskell (or authored-Dhall) source it is rendered from.

---

## 1. Why this doctrine exists

A generated artifact that is committed to the repository becomes a **second source of truth**. It can be edited
by hand, it drifts from the source it was rendered from, and a reader can no longer tell whether the committed
copy or the generator is authoritative. The defect is the same one the manifest, DSL, and formal-model doctrines
each remove in their own domain: two representations of one fact, kept in sync by hope.

The obvious alternative — "commit the generated output but regenerate it carefully, and review the diff" — fails
because the discipline is unenforceable and the failure is silent: a stale committed manifest, a hand-tweaked
`.tla`, or an out-of-date schema type-checks and reads as authoritative while no longer matching its source.

Amoebius forecloses this by **not committing generated artifacts at all.** Each is emitted deterministically
from its typed source by an `amoebius` subcommand, stamped as generated, and produced fresh at the moment it is
needed (a build, a `--dry-run`, a model-check, a deploy). What this forecloses: a stale or hand-edited generated
artifact, because there is no committed artifact to go stale — the source is the only thing under version
control, and every consumer renders from it.

---

## 2. What is generated (and from what)

Each generated artifact names its typed source of truth and the pure renderer that emits it:

| Generated artifact | Source of truth (committed) | Renderer | Owning doctrine |
|---|---|---|---|
| Kubernetes objects (Deployment/Service/RBAC/NetworkPolicy/HTTPRoute/…) | the opaque post-bind, capacity/capability-checked whole-deployment `ProvisionedSpec` derived from `InForceSpec` + target inventory | `renderAll :: ProvisionedSpec -> [K8sObject]` (pure, total; private service/global projections merge by object identity) | [manifest_generation_doctrine.md](./manifest_generation_doctrine.md) |
| TLA+ `.tla` + `.cfg` | the reifiable Haskell `Model` | `emitTLA :: Model -> (Tla, Cfg)` | [formal_model_doctrine.md](./formal_model_doctrine.md) |
| The Dhall schema (types the DSL is authored against) | the Haskell DSL ADTs | schema reflected from the types (the hostbootstrap `reflectedSchema` / prodbox `SchemaDhall` pattern) | [dsl_doctrine.md](./dsl_doctrine.md) |
| PureScript frontend contract types | the Haskell app/workflow ADTs | `purescript-bridge` contract generation | [lift_and_compose_doctrine.md](./lift_and_compose_doctrine.md) |
| The reconcile plan / `--dry-run` preview | the `chain :: cfg -> [Step]` value whose amoebius config contains the whole opaque `ProvisionedSpec` | `renderChainPlan` | [manifest_generation_doctrine.md](./manifest_generation_doctrine.md) |

The common shape: a **pure, total function** from a committed typed value to text-or-objects. Because the
renderer is pure, the artifact is a deterministic function of the source, and regenerating is free.

---

## 3. The rule

- **No generated artifact lives in the repository.** No `spec/tla/*.tla`, no rendered manifest YAML, no
  reflected `*.dhall` schema, no generated `*.purs` contract is committed. The repository holds the Haskell
  source, the authored Dhall (see [§5](#5-authored-vs-generated-the-committed-source)), and this doctrine.
- **Each artifact is emitted by an `amoebius` subcommand** and stamped with a generated-by header ("do not edit
  by hand; edit the source and re-emit"). The Dhall-generation pattern already proven in the siblings stamps
  its output `-- GENERATED … Do not edit by hand`.
- **Regeneration is deterministic and reproducible.** The same source renders byte-identical output, so a
  golden test can pin the rendering (a Register-1 check, [conformance_harness_doctrine.md](./conformance_harness_doctrine.md))
  without the artifact itself being committed as anything other than a golden fixture of the *renderer's*
  behaviour.
- **The one committed exception: a gate's proven/tested/assumed ledger.** The honesty ledger a gate emits
  ([testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact),
  [development_plan_standards.md §K](../../DEVELOPMENT_PLAN/development_plan_standards.md#k-honesty-proven--tested--assumed))
  **is committed**, deliberately, and is the sole carve-out from the never-commit rule. It is *not* a rendering
  of a committed source that can be regenerated on demand — it is the durable record of *what a gate run
  established and by what means*, whose evidentiary value depends on being version-controlled and externally
  lint-checked, pinned to the run that produced it. A regenerable-from-source artifact goes stale silently and
  so is never committed; a run-evidence ledger is worthless unless committed.

---

## 4. What this buys

- **Dry-run needs no cluster and no repository artifact.** Rendering the plan, the manifests, or the `.tla` is a
  pure function of committed source, so it runs in-process (Register 1) — the "rendering a plan MUST NOT require
  live infrastructure" invariant of [conformance_harness_doctrine.md](./conformance_harness_doctrine.md) is a
  direct consequence.
- **The formal-model correspondence is mechanical.** Because the `.tla` is *only ever* emitted from the `Model`,
  a stale or hand-edited spec cannot exist; the model↔code correspondence of
  [formal_model_doctrine.md §5](./formal_model_doctrine.md#5-the-tlacfg-are-generated-never-committed) is
  guaranteed by there being nothing else to check.
- **One place to change a shape.** Editing a manifest shape, an invariant, or a schema field is an edit to one
  Haskell source; every rendering follows.

---

## 5. Authored vs generated: the committed source

The rule is about *rendered* artifacts, not all non-Haskell files. The committed source of truth includes:

- **Authored Dhall** — an operator's `InForceSpec`, the DSL fixture corpus (`legal_*` / `illegal_*`), and any
  hand-written example. These are *inputs* an operator writes, not renderings of a Haskell value, so they are
  source and are committed. (The Dhall *schema* an `InForceSpec` is type-checked against is generated; the
  `InForceSpec` itself is authored.)
- **Haskell source** — the DSL types, the `renderAll`/`emitTLA`/`chain` functions, the `Model` values.
- **Documentation** — this doctrine suite.

The line: if a human authors it, it is committed source; if a pure function renders it from committed source, it
is a generated artifact and is not committed.

---

## 6. Planning ownership

This document is normative only. Which phase builds each renderer is owned by
[DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md) and [system_components.md](../../DEVELOPMENT_PLAN/system_components.md);
the plan-standards requirement that a phase never register a generated artifact as a committed module path is
owned by [development_plan_standards.md](../../DEVELOPMENT_PLAN/development_plan_standards.md). This doc states
the target shape and links back for status; every statement here is design intent, never a tested amoebius
result.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Formal Model Doctrine](./formal_model_doctrine.md) — the `.tla`/`.cfg` case
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — the k8s-object and `--dry-run` cases
- [DSL Doctrine](./dsl_doctrine.md) — the reflected Dhall schema vs the authored `InForceSpec`
- [Lift and Compose Doctrine](./lift_and_compose_doctrine.md) — the PureScript contract case
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — golden rendering tests, no committed artifact
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
