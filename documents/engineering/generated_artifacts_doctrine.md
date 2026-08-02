# Generated Artifacts: emitted from a source of truth, never committed

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_13_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_14_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_20_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_25_base_image_registry.md, DEVELOPMENT_PLAN/phase_26_object_reconciler.md, DEVELOPMENT_PLAN/phase_40_ui_program_release.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/tla_modelling_assumptions.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: Single source of truth for the rule that every artifact amoebius can *render from a typed source* — Kubernetes manifests, TLA+ files, Dhall schemas, checked UI plans/content manifests, PureScript catalog codecs, and the generic client bundle — is a **build artifact emitted at build/check time and never committed to the repository**; only authored Dhall and runtime/generator source are committed.

---

## 1. Why this doctrine exists

A generated artifact that is committed to the repository becomes a **second source of truth**. It can be edited
by hand, it drifts from the source it was rendered from, and a reader can no longer tell whether the committed
copy or the generator is authoritative. The defect is the same one the manifest, DSL, and formal-model doctrines
each remove in their own domain: two representations of one fact, kept in sync by hope.

The obvious alternative — "commit the generated output but regenerate it carefully, and review the diff" — fails
because the discipline is unenforceable and the failure is silent: a stale committed manifest, a hand-tweaked
`.tla`, or an out-of-date schema type-checks and reads as authoritative while no longer matching its source.

amoebius forecloses this by **not committing generated artifacts at all.** Each is emitted deterministically
from its typed source by an `amoebius` subcommand, stamped as generated, and produced fresh at the moment it is
needed (a build, a `--dry-run`, a model-check, a deploy). What this forecloses: a stale or hand-edited generated
artifact, because there is no committed artifact to go stale — the source is the only thing under version
control, and every consumer renders from it.

---

## 2. What is generated (and from what)

Each generated artifact names its typed source of truth and the deterministic renderer/compiler that emits it:

| Generated artifact | Source of truth (committed) | Renderer | Owning doctrine |
|---|---|---|---|
| Kubernetes objects (Deployment/Service/RBAC/NetworkPolicy/HTTPRoute/…) | the opaque post-bind, capacity/capability-checked whole-deployment `ProvisionedSpec` derived from `InForceSpec` + target inventory | `renderAll :: ProvisionedSpec -> [K8sObject]` (pure, total; private service/global projections merge by object identity) | [manifest_generation_doctrine.md](./manifest_generation_doctrine.md) |
| TLA+ `.tla` + `.cfg` | the reifiable Haskell `Model` | `emitTLA :: Model -> (Tla, Cfg)` | [formal_model_doctrine.md](./formal_model_doctrine.md) |
| The Dhall schema (types the DSL is authored against) | the Haskell DSL ADTs | schema reflected from the types (the hostbootstrap `reflectedSchema` / prodbox `SchemaDhall` pattern) | [dsl_doctrine.md](./dsl_doctrine.md) |
| Paired `ClientPlan`/serializable `UiServerPlan` manifests, resolved external-link subset, per-app public-contract/content manifest, route manifest, and sealed dispatch projection | authored `UiSource` plus the reified Haskell public contracts, bound handlers, policies, scopes, capability graph, and trusted external-link catalog | UI Gate 1/Gate 2/bind followed by the client/server/content projections from one private `BoundUiProgram` | [low_code_ui_runtime_doctrine.md §3](./low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans) |
| PureScript public catalog types/codecs and the one immutable generic client bundle per runtime ABI/catalog | committed generic PureScript interpreter/component catalog plus reified public catalog contracts | deterministic catalog generation plus the pinned PureScript build | [low_code_ui_runtime_doctrine.md §15](./low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts) |
| The reconcile plan / `--dry-run` preview | the `chain :: cfg -> [Step]` value whose amoebius config contains the whole opaque `ProvisionedSpec` | `renderChainPlan` | [manifest_generation_doctrine.md](./manifest_generation_doctrine.md) |
| The image build recipe (`Dockerfile`, per identity) | the typed bake catalog — each stage's `NonEmpty BakeStep` in its `BuildExecutionEnvelope` | `renderDockerfile :: BuildExecutionEnvelope -> Dockerfile` (pure, total) | [image_build_doctrine.md](./image_build_doctrine.md) |

The common shape is a deterministic projection or pinned compilation from committed typed source. Pure
renderers remain pure and total; a compiler-backed artifact additionally records the exact compiler/runtime ABI
and component-catalog inputs. The same normalized source, linked binary, catalog, contracts, and pinned toolchain
must emit byte-identical output.

The paired UI artifacts have asymmetric visibility. `ClientPlan` is an allowlisted browser artifact;
`UiServerPlan` is readable only by the UI-server service identity and has no client-asset route. A content
address names bytes but does not make those bytes public or grant authority to fetch them.

**Why the `Dockerfile` belongs on this list.** The argument is the one
[manifest_generation_doctrine.md §1](./manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not)
already makes against Helm, one layer down. A Go-templated chart is text that becomes YAML only after string
interpolation, so nothing inspects the result until the apiserver does; an `ARG`/`RUN` Dockerfile is text
that becomes a *filesystem* only after interpolation, so nothing inspects the result until the image runs.
amoebius refused the first and cannot consistently accept the second. With each stage's content a
`NonEmpty BakeStep` ([image_build_doctrine.md §6](./image_build_doctrine.md#6-host-build-vs-in-pod-build--development_plan-decision-recommended-default-host-builder-for-v1)),
the recipe becomes a projection of typed data and the committed artifact is the catalog, not the template.

---

## 3. The rule

- **No production generated artifact lives in the repository.** No `spec/tla/*.tla`, rendered manifest YAML, reflected
  `*.dhall` schema, checked `ClientPlan`/`UiServerPlan`, per-app content manifest, generated `*.purs` catalog
  codec, or compiled generic client bundle is committed. The repository holds Haskell and generic PureScript
  source, authored Dhall (see
  [§5](#5-authored-vs-generated-the-committed-source)), and this doctrine.
- **Each artifact is emitted by an `amoebius` subcommand** and stamped with a generated-by header ("do not edit
  by hand; edit the source and re-emit"). The Dhall-generation pattern already proven in the siblings stamps
  its output `-- GENERATED … Do not edit by hand`.
- **Independent expected-output fixtures are authored test inputs, not captured generated artifacts.** A
  Register-1 golden may pin a renderer only when it is independently authored before or apart from the
  renderer and committed under `test/` as an oracle
  ([conformance_harness_doctrine.md](./conformance_harness_doctrine.md)). Copying the renderer's own output into
  the golden is prohibited: that copy is a generated artifact and supplies no independent expectation.
- **Run-evidence ledgers are committed records.** The honesty ledger a gate emits
  ([testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact),
  [development_plan_standards.md §K](../../DEVELOPMENT_PLAN/development_plan_standards.md#k-honesty-proven--tested--assumed))
  **is committed**, deliberately. It is the second non-production committed class, alongside independently
  authored test oracles. It is *not* a rendering
  of a committed source that can be regenerated on demand — it is the durable record of *what a gate run
  established and by what means*, whose evidentiary value depends on being version-controlled and externally
  lint-checked, pinned to the run that produced it. A regenerable-from-source artifact goes stale silently and
  so is never committed; a run-evidence ledger is worthless unless committed.

The distinction is therefore source-based rather than directory-based: an independently authored expected
fixture and an observed run ledger may be committed; output copied from the system under test may not, even if
renamed as a golden.

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

- **Authored Dhall** — an operator's `InForceSpec`, an application's bounded `UiSource`, the DSL fixture corpus
  (`legal_*` / `illegal_*`), and hand-written examples. These are inputs rather than renderings and are
  committed. Their reflected Dhall schemas and checked plans are generated.
- **Haskell source** — the DSL and UI checked-IR types, trusted workflow/data/artifact adapters, binders,
  `renderAll`/`emitTLA`/`chain` functions, and `Model` values.
- **PureScript source** — the one generic client interpreter and audited trusted component catalog. Generated
  catalog types/codecs and its compiled generic bundle are not source. An app contributes a checked
  plan/content manifest, not PureScript source or an app-specific bundle.
- **Documentation** — this doctrine suite.

The line: a human-authored typed input or runtime/generator implementation is committed source; an artifact
projected or compiled deterministically from that source is generated and is not committed.

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
- [Low-Code UI Runtime Doctrine](./low_code_ui_runtime_doctrine.md) — [§15](./low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts) owns the complete UI generated-artifact set
- [Lift and Compose Doctrine](./lift_and_compose_doctrine.md) — sibling UI contracts and flows are inputs to the generic checked runtime, not committed demo-shell output
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — golden rendering tests, no committed artifact
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
