# Generated Artifacts: emitted from a source of truth, never committed

> **Purpose**: State the semantic rule that every reproducible projection, compilation, resolution, test
> result, and run record is emitted at build/check time and never committed; only authored inputs and reviewed
> external source are version-controlled.
> **Read this if**: it has to be settled whether an artifact is committed or produced.

This document owns the semantic authored-versus-generated boundary. The complete path inventory, repository
tree, ignore contracts, and enforcement rules are owned by
[`repository_layout_doctrine.md`](./repository_layout_doctrine.md). Each generator's domain semantics remain
with the doctrine that defines its output.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_35_image_recipe_generation.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/browser_offline_runtime_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/extension_conformance_doctrine.md, documents/engineering/extension_conformance_transactions.md, documents/engineering/formal_model_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/jit_artifact_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/low_code_ui_runtime_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/tla_modelling_assumptions.md, documents/engineering/validation_frame_doctrine.md, documents/illegal_state/illegal_state_lifecycle.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

</details>

> **Historical result (invalidated).** Phase-run and implementation-result statements predate the 2026-08-11 reopen unless the owning phase is Done; target doctrine remains normative, and current state is in the [tracker](../../DEVELOPMENT_PLAN/README.md).

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

**The rule has since generalised, and this doctrine has narrowed.** What began as a list of artifact classes is
now a single rule with a closed exception list: *every artifact that is not Haskell source is generated from
Haskell types, unless it must exist before the generator can run*
([`jit_artifact_doctrine.md` §2](./jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list)). That
document owns the calculus — targets, recipes, content-derived addresses, and the materialize/consume/reap
region. **This document owns the repository half**: which paths emitted artifacts may occupy, how an authored
oracle stays textually distinguishable from the output it checks, and the checks that keep a generated file out
of version control. The two are read together, and neither restates the other.

---

## 2. What is generated (and from what)

Each generated artifact names its typed source of truth and the deterministic renderer/compiler that emits it:

| Generated artifact | Source of truth (committed) | Renderer | Owning doctrine |
|---|---|---|---|
| Kubernetes objects (Deployment/Service/RBAC/NetworkPolicy/HTTPRoute/…) | the opaque post-bind, capacity/capability-checked whole-deployment `ProvisionedSpec` derived from `InForceSpec` + target inventory | `renderAll :: ProvisionedSpec -> [K8sObject]` (pure, total; private service/global projections merge by object identity) | [manifest_generation_doctrine.md](./manifest_generation_doctrine.md) |
| TLA+ `.tla` + `.cfg` | the reifiable Haskell `Model` | `emitTLA :: Model -> (Tla, Cfg)` (built and byte-golden validated in [Phase 11](../../DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md)) | [formal_model_doctrine.md](./formal_model_doctrine.md) |
| The Dhall dhall-typecheck schema, its prelude of smart constructors, and every `.dhall` example | the Haskell checked-IR types themselves | schema reflection from the Haskell types, so decoder and schema cannot disagree: there is no parity report because there is no second authored statement to compare | [dsl_doctrine.md](./dsl_doctrine.md) |
| The relational schema, its constraints, composite keys, and row-level policies | the scope-bearing Haskell row types and the closed transaction vocabulary | one emission per declaration, so statement and policy share a term | [extension_conformance_transactions.md](./extension_conformance_transactions.md) |
| The repository's own checking tools and the build-flag mutant corpus | the declarations they check, and the positive seed plus mutation operator | per-kind emitters; a tool that checks a declaration is a projection of it | [jit_artifact_doctrine.md](./jit_artifact_doctrine.md) |
| Paired `ClientPlan`/serializable `UiServerPlan` manifests, resolved external-link subset, per-app public-contract/content manifest, route manifest, and sealed dispatch projection | authored `UiSource` plus the reified Haskell public contracts, bound handlers, policies, scopes, capability graph, and trusted external-link catalog | UI dhall-typecheck/gadt-decode/bind followed by the client/server/content projections from one private `BoundUiProgram` | [low_code_ui_runtime_doctrine.md §3](./low_code_ui_runtime_doctrine.md#3-one-checked-value-two-runtime-plans) |
| Offline client/replay projections, record codecs, migration/compatibility table, local-store descriptors, and service-worker asset manifest | the checked `UiSource.continuity`, queue/blob contracts, runtime ABI catalog, and deployment `OfflinePolicy` | the offline projection of the same private `BoundUiProgram` and release-compatibility fold | [browser_offline_runtime_doctrine.md §§5, 11](./browser_offline_runtime_doctrine.md#5-one-bound-program-paired-online-and-offline-plans) |
| PureScript public catalog types/codecs and the one immutable generic client bundle per runtime ABI/catalog | committed generic PureScript interpreter/component catalog plus reified public catalog contracts | deterministic catalog generation plus the pinned PureScript build | [low_code_ui_runtime_doctrine.md §15](./low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts) |
| The reconcile plan / `--dry-run` preview | the `chain :: cfg -> [Step]` value whose amoebius config contains the whole opaque `ProvisionedSpec` | `renderChainPlan` | [manifest_generation_doctrine.md](./manifest_generation_doctrine.md) |
| The image build recipe (`Dockerfile`, per identity) | the typed bake catalog — each stage's `NonEmpty BakeStep` | `renderDockerfile :: BakeCatalog -> Either CatalogError Dockerfile` (pure, total) | [image_build_doctrine.md](./image_build_doctrine.md) |

The common shape is a deterministic projection or compiler-backed build from authored typed source. Pure
renderers remain pure and total; a compiler-backed artifact additionally records the exact per-run resolved
compiler/runtime ABI and component-catalog inputs. Repetition under the same recorded inputs must emit
byte-identical output; changing a dynamically resolved input creates a distinct observation, not a committed pin.

The paired UI artifacts have asymmetric visibility. `ClientPlan` is an allowlisted browser artifact;
`UiServerPlan` is readable only by the UI-server service identity and has no client-asset route. A content
address names bytes but does not make those bytes public or grant authority to fetch them.

[Phase 40](../../DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md) supplies concrete build-boundary evidence: the
paired plans, public contracts, and content manifest are produced in memory from `BoundUiProgram`, match only
committed test goldens, and remain byte-identical across fresh randomized-order compiler processes. No emitted
per-application artifact is added to the authored source tree.

[Phase 42](../../DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md) supplies the complementary generic-bundle
evidence. The pinned PureScript/Spago build emits the bundle only into ignored build directories, an independent
scanner checks its allowlisted runtime surface, and two application plans execute without rebuilding or adding
an application-authored browser artifact.

[Phase 72](../../DEVELOPMENT_PLAN/phase_72_ui_program_release.md) supplies the live release instance. Its
deterministic projection writes paired client/server plans, public contracts, and release manifests as
immutable content objects, while the repository scan keeps those per-application outputs absent from the
committed generated tree. The serializable server plan contains handler/dispatch identities and codecs, never
Haskell functions, and two program revisions retain the same generic runtime-image digest.

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

- **No generated artifact lives in the repository.** The rule is stated positively and once, by
  [`jit_artifact_doctrine.md` §2](./jit_artifact_doctrine.md#2-the-rule-and-the-closed-exception-list): every
  artifact that is not Haskell source is generated, unless it must exist before the generator can run. The
  repository therefore holds Haskell source, the generic PureScript interpreter, authored expectations (see
  [§5](#5-authored-vs-generated-the-committed-source)), and the bootstrap exceptions — and nothing else. No
  `.tla`, rendered manifest, reflected `*.dhall` schema, emitted `ClientPlan`/`UiServerPlan`, offline
  codec or service-worker manifest, per-app content manifest, generated `*.purs` codec, compiled bundle,
  emitted SQL, container recipe, or generated checking tool is committed.
### 3.1 The retired image-recipe allowlist

**This allowlist is retired.** It existed because the general rule had exceptions and the exceptions needed
somewhere to live, so a per-file admitted set was authored here and keyed on the renderer input each entry
pinned. The closed exception list replaces it with a *criterion* rather than a list — an artifact is exempt only
if it must exist before the generator can run — and a per-file allowlist is exactly the mechanism that criterion
removes: a list admits whatever somebody added to it, and its rows accumulate.

One tracked file was admitted under the old mechanism and does not meet the new criterion: the committed
byte golden of the rendered container recipe. It is a byte golden of generated output, which
[§7](./jit_artifact_doctrine.md#7-goldens-become-oracles) of the artifact doctrine replaces with a semantic
oracle, and it does not have to exist before anything. It is therefore a **condemned artifact** rather than an
allowlisted one: it remains in the tree until the phase that emits the recipe under the artifact calculus
replaces it with an oracle over the rendered content, and the audit map recording that owner and its closure
condition is
[`legacy_tracking_for_deletion.md`](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md). Until then, a
tracked file that reads as an image recipe and is not that one is a finding, and an authored digest inside one
is a finding regardless.

- **Each artifact is emitted by an `amoebius` subcommand** and stamped with a generated-by header ("do not edit
  by hand; edit the source and re-emit"). The Dhall-generation pattern already proven in the siblings stamps
  its output `-- GENERATED … Do not edit by hand`.
- **An expectation is a semantic oracle, not a byte golden.** A byte golden of generated output tests a
  renderer against a copy of its own past output: it cannot distinguish a correct change from an incorrect one,
  and the usual response to a red golden is to regenerate it, which deletes the test one file at a time. Under
  the artifact calculus it is also redundant, because a change in the rendered bytes is already a change in the
  artifact's address ([`jit_artifact_doctrine.md` §4](./jit_artifact_doctrine.md#4-the-address-folds-in-the-rendered-text)).
  What a phase commits instead is an **oracle**: an independently authored predicate over the rendered artifact,
  asserting the property the artifact exists to have, written from the requirement rather than from the output
  ([conformance_harness_doctrine.md](./conformance_harness_doctrine.md)). Copying the renderer's own output into
  a fixture remains prohibited: that copy is a generated artifact and supplies no independent expectation.
  Phase 33 applies this distinction to `renderAll`: the emitted `[K8sObject]` deployment is never committed,
  and the eighteen `.json.golden` digest fixtures that currently lock it are **condemned artifacts** on the
  same terms as [§3.1](#31-the-retired-image-recipe-allowlist)'s recipe golden — byte locks over generated
  output, awaiting replacement by oracles asserting what each object must satisfy. They grant no authority to
  deploy and they are not the acceptance condition the phase is re-authored against. Phase 58 consumes the generated object values directly at
  apply time and validates their live convergence without writing rendered manifests into the repository;
  only independently authored fixtures are committed. Receipts are run evidence and remain outside Git.
- **History must establish or review independence.** When a fixture and the implementation it tests first
  appear in the same commit, Git establishes no before-implementation provenance. The fixture is a regression
  fixture until a reviewer independently validates or replaces its expectation. A filename, `golden` label,
  or same-commit manifest assertion cannot promote it to an independent oracle.
- **Generated negative copies are not authored mutants.** A positive seed, mutation operator, and mutation
  selection may be authored source. The materialized negative files produced from them are generated test
  input and belong under `.build/test-corpora/` or `.build/tmp/`, even when committed copies would make a
  checker convenient to run.
- **One emitted path, one suffix convention, one scan.** So that "generated" and "authored oracle" can never
  be confused by a reader or a check, three conventions are normative and are stated **here**, not
  re-derived per phase:
  1. **Emitted artifacts are written only under the git-ignored `.build/` tree**, in a per-kind subdirectory
     (`.build/tla/`, `.build/manifests/`, `.build/dhall/`, `.build/ui/`). No emitted artifact is written anywhere else,
     and nothing under `.build/` is ever tracked.
  2. **A committed oracle carries a `.golden` suffix appended to its natural extension**
     (`ToyModel.tla.golden`, `<deployment-id>.json.golden`) and lives under `test/`. The suffix is what makes
     an authored fixture textually distinguishable from the artifact it pins.
  3. **The never-committed check is one command**: `git ls-files -- '.build/*'` plus a per-kind extension sweep
     over tracked paths whose extension is *literally* the generated one — for TLA+,
     `git ls-files -- '*.tla' '*.cfg'` — each returning empty. A `.golden`-suffixed fixture does not match
     either, by construction; an actually-emitted `.tla`/`.cfg` under version control fails.
- **A golden is amended, never rewritten from a failing run.** When a renderer's output legitimately changes —
  a formatting fix, a new constructor, a fragment extension, a toolchain bump that alters accepted syntax —
  the golden is updated under the oracle-amendment discipline of
  [development_plan_standards.md §M](../../DEVELOPMENT_PLAN/development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub),
  which requires the amendment be authored from the *intended* output and reviewed as a change to the
  expectation. Regenerating a golden from the failing run's actual output silently converts an oracle into a
  snapshot and is prohibited at any phase.
- **Run evidence is generated and never committed.** Ledgers, receipts, logs, traces, coverage, enumeration,
  resolved toolchains, dependency graphs, screenshots, and machine observations are written beneath
  `.build/runs/` and installed in the content-addressed `.build/evidence-store/`. Optional publication may
  copy an attestation to a remote service, but no local evidence or staging path may live outside the checkout.
- **Dependency resolution is generated and never committed.** Lock/freeze files, solver plans, package
  checksum tables, resolved paths, and hard-coded library or package SHA values are prohibited in tracked
  files. The current compatible graph and observed integrity data are resolved dynamically for every clean
  run as specified by
  [`repository_layout_doctrine.md` §4](./repository_layout_doctrine.md#4-dependency-and-toolchain-resolution).
- **Python interpreter bytecode is the source-adjacent cache exception.** It is generated and never committed,
  but the interpreter may cache it beside imported source. Both repository and container ignore contracts
  cover the directory and suffix forms. Python commands use ordinary cache behavior; they do not suppress
  cache writes merely to keep authored directories physically empty.

The distinction is source-based rather than directory-based. An independently authored expected fixture may
be committed; output copied from the subject, a reference program, a resolver, or a prior run may not.

---

## 4. What this buys

- **Dry-run needs no cluster and no repository artifact.** Rendering the plan, the manifests, or the `.tla` is a
  pure function of committed source, so it runs in-process (Register 1). The "rendering a plan MUST NOT require
  live infrastructure" invariant of [conformance_harness_doctrine.md](./conformance_harness_doctrine.md) is a
  direct consequence. Phase 34 validates this for the chain plan: emitted dry-run bytes remain uncommitted,
  independently authored `.plan.golden` fixtures pin them, and the fake boundary consumes the same input bytes.
- **The formal-model correspondence is mechanical.** Because the `.tla` is *only ever* emitted from the `Model`,
  a stale or hand-edited spec cannot exist; the model↔code correspondence of
  [formal_model_doctrine.md §5](./formal_model_doctrine.md#5-the-tlacfg-are-generated-never-committed) is
  guaranteed by there being nothing else to check.
  Phase 11 validates this discipline with the `amoebius dev model emit` path, a byte-exact independent golden,
  four renderer mutants, and a tracked-file scan that rejects generated `.tla`/`.cfg` artifacts.
  Phase 17 applies the same path to `GatewayMigration`: the committed files under
  `test/golden/formal/gateway/` are renderer oracles, while every executable TLC input remains under ignored
  `.build/tla/`; the phase gate checks their byte equality before model checking.
- **One place to change a shape.** Editing a manifest shape, an invariant, or a schema field is an edit to one
  Haskell source; every rendering follows.

---

## 5. Authored vs generated: the committed source

The rule is about *rendered* artifacts, not all non-Haskell files. The committed source of truth includes:

- **Authored Dhall, now a much smaller class.** The dhall-typecheck schemas, the prelude of smart constructors,
  and the hand-written examples are **no longer authored**: they are reflected from the Haskell checked-IR
  types, so the schema and the decoder cannot disagree, and none of them is committed. What remains authored is
  input that is not a rendering of anything amoebius holds — an operator's `InForceSpec` and an application's
  bounded `UiSource`, both of which live in the deployment that owns them rather than in this tree — and the
  independently authored positives of the DSL fixture corpus, which are oracles under `test/`. The negatives
  are generated from those positives and a mutation operator, and are not committed.
- **Haskell source** — the DSL and UI checked-IR types, trusted workflow/data/artifact adapters, binders,
  `renderAll`/`emitTLA`/`chain` functions, and `Model` values.
- **PureScript source** — the one generic client interpreter, offline browser-facility interpreter, and audited
  trusted component catalog. Generated catalog/offline record codecs, migration tables, service-worker asset
  manifests, and the compiled generic bundle are not source. An app contributes a checked
  plan/content manifest, not PureScript source or an app-specific bundle.
- **Documentation** — this doctrine suite.
- **Phase contracts and policies** — human-authored requirements that contain no generated status view,
  ledger copy, dependency resolution, or package integrity value.

The Phase-37 UI schema gate treats `UiSource` fixtures and independent graph/wire tables as authored inputs.
Checked values, coverage reports, and later client/server plans are derived outputs; only test goldens are
committed as oracles. See [Phase 37](../../DEVELOPMENT_PLAN/phase_37_ui_program_schema.md).

The line: a human-authored input or reviewed external source is version-controlled. An artifact projected,
compiled, resolved, observed, or reported from another input is generated and is not version-controlled.

### 5.1 When the reflected schema changes under an operator's `.dhall`

**The problem.** The two classes above are coupled in one direction that the rule above does not cover. The
dhall-typecheck schema is **reflected from the Haskell types** and is not committed here; what is authored is
an operator's own `InForceSpec` and an app's `UiSource`, which live in the deployment that owns them rather
than in this repository. A change to the Haskell types — a field added, a union arm added, a field renamed or
removed — changes the reflected schema, and therefore changes the meaning or admissibility of every operator
value already written against it.

The failure is not a stale generated artifact, because there is no tracked copy to go stale. It is an
*operator's* authored value that no longer type-checks against the new reflection, or worse, still type-checks
and now means something else. It surfaces at the next `dhall update`, on a spec the operator did not touch,
and amoebius cannot fix it by editing anything in this tree.

**Why the obvious alternative fails.** Versioning the schema and keeping N of them re-admits exactly what
[§1](#1-why-this-doctrine-exists) removes: several concurrent descriptions of one type surface, kept in step by
hope. Refusing ever to change the schema is not available either — the whole plan is a sequence of phases that
widen them.

**The chosen rule.** Schema evolution is classified by what it does to already-authored values, and only two
of the three classes are admissible without an authored migration:

- **Widening** — adding an *optional* field with a default, or adding a union arm no existing value inhabits.
  Every committed `.dhall` still type-checks and still denotes what it denoted. Admissible.
- **Narrowing** — removing a field or arm, or making an optional field required. Existing values may stop
  type-checking. Admissible **only** as a `dhall update` that is rejected at dhall-typecheck with the operator holding
  the authored value: the operator edits the source, because amoebius does not own it. There is no automatic
  rewrite of an authored file, and there is deliberately no facility to produce one — a tool that silently
  edited an operator's committed spec would make the authored/generated line meaningless.
- **Reinterpretation** — keeping a field's name and type while changing its meaning. **Not admissible.** It is
  the one change that cannot be caught by any gate, because the old value still type-checks and now denotes
  something else. A meaning change is expressed as a *rename* (a narrowing plus a widening), so that dhall-typecheck
  refuses the old value rather than accepting it under new semantics.

**What it forecloses.** amoebius gives up in-place schema upgrades of operator-authored specs: a narrowing is
an operator edit, and there is no migration tool to write. The honest residue is that the widening/narrowing
classification is a property of the ADT change, checked by the Dhall typechecker on the corpus rather than
proven — nothing forbids an author from making a reinterpretation change, and only review catches it.

This is the DSL's own instance of the general migration law
([migration_doctrine.md §3](./migration_doctrine.md#3-one-discipline-many-instances)); it is recorded there as
an instance whose verification gate is the dhall-typecheck typecheck over the committed fixture corpus, followed by
gadt-decode parity against the Haskell decoder mirror.

---

## 6. Planning ownership

This document is normative only. Which phase builds each renderer is owned by
[DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md) and [system_components.md](../../DEVELOPMENT_PLAN/system_components.md);
the plan-standards requirement that a phase never register a generated artifact as a committed module path is
owned by [development_plan_standards.md](../../DEVELOPMENT_PLAN/development_plan_standards.md). This doc states
the target shape and links back for status; every statement here is design intent, never a tested amoebius
result.

---

## Related Documents

- [Repository Layout and Artifact Provenance](./repository_layout_doctrine.md) — complete tree, generated inventory, and ignore contracts

Phase 41 now emits the deterministic `emit-client-offline-plan` and `emit-server-replay-plan` projections
from one checked offline source. Their independently pinned port-key sets match exactly, private fields remain
absent from the public artifact, and five mutants pass. Runtime interpretation remains UNVERIFIED.

Phase 45 pins the immutable public asset manifest and admits only public, content-digested, non-mutable cache
entries. Real Chrome preserves exactly those assets across restart and registers the Service Worker. The
production PureScript-generated client bundle remains UNVERIFIED.

Phase 87 emits `emit-offline-compatibility-manifest` and `emit-offline-migration-table` from the checked
witness. The scoped gate checks complete key coverage, finite horizon, deterministic names, migration/retained
paths, and incompatible refusal. Production PureScript and live provider rollout remain UNVERIFIED.

- [Engineering Doctrine Index](./README.md)
- [Formal Model Doctrine](./formal_model_doctrine.md) — the `.tla`/`.cfg` case
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — the k8s-object and `--dry-run` cases
- [DSL Doctrine](./dsl_doctrine.md) — the Dhall surface reflected from the Haskell types, and the operator-owned `InForceSpec` written against it
- [Low-Code UI Runtime Doctrine](./low_code_ui_runtime_doctrine.md) — [§15](./low_code_ui_runtime_doctrine.md#15-versioning-rollout-and-generated-artifacts) owns the complete UI generated-artifact set
- [Browser Offline Runtime](./browser_offline_runtime_doctrine.md) — offline plans, codecs, migrations, and service-worker manifests are projections of checked source
- [Lift and Compose Doctrine](./lift_and_compose_doctrine.md) — sibling UI contracts and flows are inputs to the generic checked runtime, not committed demo-shell output
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — golden rendering tests, no committed artifact
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Testing Doctrine](./testing_doctrine.md) — run-time enumeration, authored expectation, and repository-local evidence
