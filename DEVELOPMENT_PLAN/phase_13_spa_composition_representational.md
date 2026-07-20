# Phase 13: SPA composition (representational) + demo-SPA local

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_37_spa_live_deploy.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/tenancy_doctrine.md
**Generated sections**: none

> **Purpose**: Prove — in-process, before any cluster exists — that a multi-service app spec composes with an
> ML-workflow demo fragment into one decoding SPA value (`prop_spaCompositionDecodes`), and that the lifted
> PureScript demo SPA, its contracts regenerated from the composed Haskell ADTs, runs locally against a faked
> backend under Playwright.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement
is design intent, never a tested amoebius result. This phase opens after the Phase 11 boundary fake-tool gate
passes and runs on **no substrate** (`none`) across **Registers 1 and 2** — it stands up no host and no
cluster, only an in-process composition-decode battery (Register 1) and a locally-served demo SPA driven
against a faked backend (Register 2). Where a shape below is already exercised in a sibling system — the
`infernix` and `jitML` `web/` PureScript demo SPAs, their `purescript-bridge` contract generation, and the
prodbox pure/no-process suite — that is **sibling evidence, not an amoebius result**. This is the
**representational** half of SPA composition; the **live** SPA deploy behind Keycloak/Envoy on `linux-cpu`
stays [Phase 37](phase_37_spa_live_deploy.md).

## Phase Summary

This phase proves that amoebius's SPA composition is sound **at the spec/code layer** and that its rendered
frontend contract drives a real browser — both without any live infrastructure. It delivers the SPA app-spec
type (a multi-service surface whose dependencies are declared as **capability needs**, never products), the
composition of an ML-workflow demo fragment into that surface as **shared-library use** (a nested
infernix/jitML `.dhall`, which is application logic), the QuickCheck property `prop_spaCompositionDecodes`
establishing that an app spec + a demo fragment always compose into one well-typed value that decodes through
Gate 1 + Gate 2, and the lifted PureScript demo SPA whose contract types are **regenerated from the composed
Haskell ADTs via `purescript-bridge`** (a build artifact, never committed) and driven end to end against a
faked backend under Playwright. What is *not* here: the live deploy onto a cluster, the Keycloak/Envoy edge,
the typed reconciler applying manifests, and any inference on a real substrate — all of that is
[Phase 37](phase_37_spa_live_deploy.md). This phase front-loads exactly the parts of SPA composition that a
pure decode and a locally-served browser run can settle.

**Substrate:** none — no host, no cluster; the gate is an in-process `cabal test` composition battery
(Register 1) plus a locally-served demo SPA driven under Playwright against a faked backend (Register 2),
analogous to the Phase-11 boundary fake-tool harness. The inference/training substrate is structurally absent
from the SPA surface — it is a deployment rule bound only at [Phase 37](phase_37_spa_live_deploy.md).

**Register:** 1/2 — the single deliberate two-register gate: Register 1 (the composition property decodes) + Register 2 (the PureScript demo SPA against a faked backend), both in-process, no cluster (§K).

**Gate:** two in-process registers pass together over the **representative set pinned in [Gate integrity](#gate-integrity)** — **(Register 1)**
each of the two committed positive app-spec fixtures (`spa_chatbot.dhall` composing infernix,
`spa_rl_gaming.dhall` composing jitML) composes into one well-typed Dhall value that decodes through Gate 1
(`dhall type`) + Gate 2 (the total decoder), `prop_spaCompositionDecodes` holds over generated app+fragment
pairs **at the [Gate integrity](#gate-integrity) coverage thresholds**, and every committed `illegal_spa_compose_*` fixture from the [Gate integrity](#gate-integrity) catalog
fails at its **Phase-0-pinned tagged reason** (its recorded `dhall type` error locus or `DecodeError` tag), not
merely "fails"; **(Register 2)** both lifted PureScript demo SPAs (the infernix chat shell *and* the jitML
RL-gaming shell), their contract types regenerated from the composed Haskell ADTs via `purescript-bridge`
(never committed), run locally against a faked backend whose every recorded request/response is decoded/encoded
through the composed ADTs' own serialization instances, and are each driven end to end under Playwright — all on
no substrate, with the run emitting a proven/tested/assumed ledger that marks the live SPA deploy
([Phase 37](phase_37_spa_live_deploy.md)) UNVERIFIED. The gate is red unless the committed seeded mutants named
in [Gate integrity](#gate-integrity) (one per register) go red: a composed-ADT field-rename mutant must break the Register-1 round-trip
battery, the golden, and the Register-2 `spago` build; and a seeded ill-composing generator mutant must make
`prop_spaCompositionDecodes` fail. All goldens, positive/negative fixtures, expected-error tags, and mutants are
authored and committed in Phase 0 before the implementation exists; a golden regenerated from the generator is
not a test.

## Gate integrity

This section fixes the one shared interpretation of the gate's "representative set", coverage bounds, committed
oracles, and mutants, so two engineers implement the same gate (§M clauses 1–8). All artifacts named here are
authored and committed in Phase 0, before `Amoebius.Spa.*` exists.

- **Representative positive set (Register 1):** exactly two committed composing fixtures —
  `dhall/examples/spa_chatbot.dhall` (a multi-service surface using `ObjectStore` + `Sql` + `MessageBus` +
  `Identity` + `Edge`, composing the **infernix** demo fragment) and `dhall/examples/spa_rl_gaming.dhall`
  (composing the **jitML** demo fragment) — plus their intermediate `spa_compose_*` composition fixtures.
- **Representative negative catalog (Register 1):** at least six committed `illegal_spa_compose_*.dhall`
  fixtures, one per foreclosed dimension, each paired with a positive differing only in that dimension: (a) a
  product literal (`minio`) smuggled onto the app surface; (b) a deployment dial (`replicas`) added; (c) a
  substrate name (`linux-cpu`) named; (d) a workflow fragment whose capability needs do not compose with the
  surface; (e) a `SecretRef` to an undeclared secret; (f) a demo fragment nested under the wrong capability arm.
  Each fixture's expected failure — its `dhall type` error locus or Gate-2 `DecodeError` tag — is recorded in a
  committed `spa_negatives.expected` table in Phase 0; the gate asserts the *tag*, not merely non-zero exit.
- **Generator coverage thresholds (Register 1, §M-4):** `prop_spaCompositionDecodes` carries QuickCheck `cover`
  obligations that fail the run if unmet: each of the five capability arms
  (`ObjectStore`/`Sql`/`MessageBus`/`Identity`/`Edge`) appears in ≥ 20% of generated surfaces, both the infernix
  and jitML fragment shapes are generated (each ≥ 20%), and multi-service surfaces (≥ 2 distinct capability
  arms) constitute ≥ 50% of cases.
- **Independent round-trip oracle (Registers 1→2, §M-3):** a committed cross-language battery encodes
  QuickCheck-generated composed-ADT values with the Haskell serialization instances and decodes them via the
  generated PureScript types under `node`, red on any composed app/workflow ADT type absent from the emitted
  module — an oracle independent of the byte-for-byte golden and of the SUT's own emitter.
- **Committed seeded mutants (§M-2), each committed and re-run, drawn from the operator set:**
  - **M-comp** (union-arm addition): a generator variant emitting a workflow fragment whose capability need is
    unsatisfiable on the surface — `prop_spaCompositionDecodes` MUST go red.
  - **M-field** (field rename on a composed ADT): renaming one composed-ADT field MUST break the Register-1
    round-trip battery, change the Register-1 golden, and break the Register-2 `spago` build of both shells.
  - **M-neg** (invariant-clause delete): removing the product-literal rejection MUST let
    `illegal_spa_compose_minio.dhall` decode and turn the negative suite red.

## Doctrine adopted

- [`app_vs_deployment_doctrine.md §8 — Shared-library use is application logic`](../documents/engineering/app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic),
  with [`§2 — The application-logic surface`](../documents/engineering/app_vs_deployment_doctrine.md#2-the-application-logic-surface--what-an-app-is):
  the SPA composes an ML workflow by naming *that* it uses infernix (a chatbot) or jitML (an RL-gaming
  platform) — a nested `ExtensionSpec` `.dhall`, which is application logic; the app surface has no field for
  a replica count, a region, or an inference substrate, so the composition carries no placement vocabulary.
- [`service_capability_doctrine.md §2 — The capability set`](../documents/engineering/service_capability_doctrine.md#2-the-capability-set)
  and [`§7 — Expressing a capability in the DSL`](../documents/engineering/service_capability_doctrine.md#7-expressing-a-capability-in-the-dsl):
  the SPA's multi-service surface declares each dependency as a capability need drawn from the fixed no-product
  union — `ObjectStore` / `Sql` / `MessageBus` / `Identity` / `Edge` — never as a product literal.
- [`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md#4-the-demo-web-apps-purescript-spas-contracts-generated-from-haskell) §4 (the demo web
  apps as PureScript SPAs whose contracts are generated from the Haskell ADTs via `purescript-bridge`) and
  §2/§3 (the reuse map): amoebius **lifts** the infernix/jitML `web/` demo-SPA shells and **regenerates** their
  contracts from the amoebius-composed types — a demo web app is application logic that *uses* its extension,
  never itself an extension. That the sibling shells run today is **sibling evidence, not an amoebius result**.
- [`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what) §2/§3: the
  PureScript frontend contract is a build artifact emitted from the composed Haskell ADTs and **never
  committed**; only the Haskell source and the authored fixtures are versioned, and a Register-1 golden pins
  the emitted contract as a fixture of the *renderer's* behaviour.
- [`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) §2/§3: the
  pre-cluster spine — **Register 1** explicitly includes the representational SPA composition and **Register 2**
  explicitly includes the demo SPAs run locally against a faked backend, driven end to end; rendering the
  composition and its contract never touches live infrastructure.
- [`testing_doctrine.md §2 — Three registers`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
  this phase's gate reaches Registers 1 and 2 and emits a per-run proven/tested/assumed ledger whose acceptance
  token reads *spec-composition proven* / *tested (local browser)*, never *runtime proven*, with the live
  deploy marked UNVERIFIED (owned by [Phase 37](phase_37_spa_live_deploy.md)).
- [`dsl_doctrine.md §5 — the illegal-state-unrepresentable contract`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  the two typed gates — Gate 1 (Dhall typechecker) + Gate 2 (in-process `Dhall.inputFile auto` decoder) — that
  the composed SPA value passes; `prop_spaCompositionDecodes` establishes that composition preserves
  well-formedness so *if it composes, it decodes*.

## Sprints

## Sprint 13.1: The SPA app-spec type — a multi-service surface of capability needs 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Spa/Spec.hs`, `dhall/amoebius/Spa.dhall`, `dhall/examples/spa_chatbot.dhall`
(target paths; not yet built)
**Blocked by**: Phase 4 (the Gate-1 Dhall schema + the no-product `Capability` union the surface draws from);
Phase 8 (the capability → provider → shape binder the SPA's needs resolve against)
**Independent Validation**: `dhall type` accepts `dhall/examples/spa_chatbot.dhall` against the SPA app-spec
type; a grep for `minio` / `keycloak` / `pulsar` / `patroni` / `postgres` on the SPA surface returns nothing;
a variant that names a product, or that adds a `replicas` / `region` / `substrate` field, fails Gate 1 because
the SPA surface has no such arm.
**Docs to update**: `documents/engineering/service_capability_doctrine.md`,
`documents/engineering/app_vs_deployment_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`

### Objective
Adopt [`service_capability_doctrine.md §2/§7`](../documents/engineering/service_capability_doctrine.md#2-the-capability-set)
and [`app_vs_deployment_doctrine.md §2`](../documents/engineering/app_vs_deployment_doctrine.md#2-the-application-logic-surface--what-an-app-is):
define the SPA app-spec type as an application-logic artifact whose multi-service surface composes capability
needs — buckets against `ObjectStore`, a database against `Sql`, topics against `MessageBus`, auth rules
against `Identity`, published UI against `Edge` — and never names a product or a deployment dial.

### Deliverables
- An `Amoebius.Spa.Spec` library defining the SPA app-spec type: a set of named UI/service surfaces plus the
  capability-need record each depends on, carrying the SPA's cluster-unique name and **no** deployment
  vocabulary (the type has nowhere to put `replicas`, `region`, `failover`, `chaos`, or `substrate`).
- A `dhall/amoebius/Spa.dhall` type the example SPAs decode against, composing the Phase-4 capability-need arms
  into one multi-service surface, with secrets referenced by name only (a typed `SecretRef`).
- A worked `dhall/examples/spa_chatbot.dhall` skeleton declaring an `ObjectStore` bucket set (`<app>/<bucket>`),
  a `Sql` need, `MessageBus` topics, an `Identity` auth rule, and an `Edge` publish — each against the
  capability arm, no provider or shape named.

### Validation
1. `dhall type` over the example SPA succeeds; every service dependency resolves to a capability arm and no
   product name appears on the SPA surface.
2. A variant naming `minio` directly fails Gate 1 (no product arm), and a variant adding a `replicas` field
   fails Gate 1 (no such field on the SPA surface).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 13.2: Compose an ML-workflow demo fragment as shared-library use — `prop_spaCompositionDecodes` 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Spa/Workflow.hs`, `dhall/examples/spa_chatbot.dhall` (uses infernix),
`dhall/examples/spa_rl_gaming.dhall` (uses jitML), `test/dsl/SpaCompositionSpec.hs` (target paths; not yet
built)
**Blocked by**: Sprint 13.1; Phase 5 (the total Gate-2 `Dhall.inputFile auto` decoder the composed value
decodes through); Phase 6 (the illegal-state corpus + QuickCheck harness the `prop_*` properties live in)
**Independent Validation**: `prop_spaCompositionDecodes` is green over generated app-spec + demo-fragment
pairs **at the [Gate integrity](#gate-integrity) generator-coverage thresholds** (the QuickCheck `cover` obligations — each capability arm
≥ 20%, both infernix and jitML fragment shapes present, multi-service surfaces ≥ 50% — fail the run if unmet, so
a near-constant generator re-decoding the worked example is rejected); each positive `dhall/examples/spa_compose_*.dhall`
decodes through Gate 1 + Gate 2 with the library `.dhall` nested inside the SPA spec; each of the **six [Gate integrity](#gate-integrity)-catalog**
ill-composed `illegal_spa_compose_*.dhall` fixtures fails at the **exact `dhall type` error locus or Gate-2
`DecodeError` tag recorded for it in the Phase-0-committed `spa_negatives.expected` table** (asserting *why* it
fails, each paired with a positive differing only in the foreclosed dimension), not merely a non-zero exit; the
committed seeded mutant **M-comp** (a generator variant emitting an unsatisfiable-capability fragment) MUST turn
`prop_spaCompositionDecodes` red and the committed **M-neg** (product-literal rejection deleted) MUST let
`illegal_spa_compose_minio.dhall` decode and turn the negative suite red — a green run under either mutant fails
the gate; a grep of either SPA surface for `cuda` / `metal` / `linux-cpu` returns nothing.
**Docs to update**: `documents/engineering/app_vs_deployment_doctrine.md`,
`documents/engineering/lift_and_compose_doctrine.md`, `documents/engineering/testing_doctrine.md`

### Objective
Adopt [`app_vs_deployment_doctrine.md §8 — Shared-library use is application logic`](../documents/engineering/app_vs_deployment_doctrine.md#8-shared-library-use-is-application-logic):
compose an ML-workflow demo fragment into the SPA as a shared-library dependency — a chatbot via infernix, an
RL-gaming platform via jitML — declaring *that* the SPA uses it (the library `.dhall` nested inside the SPA
spec) while *where* the workflow runs stays structurally absent, and prove that the composition always yields
one decoding value.

### Deliverables
- An `Amoebius.Spa.Workflow` library and a workflow-composition field on the SPA spec that names a shared
  library (infernix or jitML) and nests its configuration `.dhall` into the SPA spec (the library call graph =
  application logic).
- The worked `dhall/examples/spa_chatbot.dhall` composing the infernix demo fragment and
  `dhall/examples/spa_rl_gaming.dhall` composing the jitML demo fragment — each naming *that* it uses the
  library, neither naming a substrate; plus the **six [Gate integrity](#gate-integrity)-catalog** `illegal_spa_compose_*` negatives (product
  literal; `replicas` dial; substrate name; non-composing capability need; undeclared `SecretRef`; wrong-arm
  nesting), and the committed Phase-0 `spa_negatives.expected` table pinning each negative's expected `dhall type`
  error locus / Gate-2 `DecodeError` tag.
- A `prop_spaCompositionDecodes` QuickCheck property (an app spec + an ML-workflow demo fragment always
  compose to a value that decodes through Gate 1 + Gate 2), labelled **TESTED (sampled)**, carrying the [Gate integrity](#gate-integrity)
  `cover`/`classify` obligations (a run failing those thresholds fails the gate).
- The committed seeded mutants **M-comp** (unsatisfiable-capability generator variant) and **M-neg**
  (product-literal rejection deleted), each committed and re-run, that the suite MUST turn red.

### Validation
1. The positive `spa_compose_*` fixtures compose and decode (Gate 1 + Gate 2 green); each of the six [Gate integrity](#gate-integrity)-catalog
   `illegal_spa_compose_*` fixtures fails at the **exact error locus / `DecodeError` tag recorded for it in the
   Phase-0 `spa_negatives.expected` table** (not merely a non-zero exit), each paired with a positive differing
   only in the foreclosed dimension; the suite is red if any ill-composed SPA decodes.
2. `prop_spaCompositionDecodes` is green at the [Gate integrity](#gate-integrity) `cover` thresholds (a run below them fails), and both committed
   mutants go red — **M-comp** turns the property red and **M-neg** turns the negative suite red; a green run
   under either mutant fails the gate. The representational composition is proven at the spec/code layer, with the
   live deploy left to [Phase 37](phase_37_spa_live_deploy.md).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 13.3: `purescript-bridge` contract generation from the composed ADTs (never committed) 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Spa/Contract.hs` (the `purescript-bridge` generator over the composed ADTs),
`web/` (the lifted infernix/jitML PureScript demo-SPA shells), `test/spa/ContractGoldenSpec.hs` (target paths;
not yet built). The emitted `*.purs` contract is a **generated artifact and is not committed**.
**Blocked by**: Sprint 13.2 (the composed Haskell app/workflow ADTs the contract reflects)
**Independent Validation**: `Amoebius.Spa.Contract` emits the PureScript contract types deterministically from
the composed ADTs; a Register-1 golden pins the emitted contract byte-for-byte; a repository check finds **no**
committed `*.purs` contract; the `spago` build of each lifted demo SPA type-checks against the freshly-generated
contract, where **"against" means the shell's exercised modules `import` the generated contract module and
reference its types** (verified by a check that removing the generated module from the build makes `spago` fail —
mere presence in the source tree is insufficient). Because a golden regenerated from the emitter passes for any
output, an **independent round-trip battery** ([Gate integrity](#gate-integrity)) — QuickCheck-generated composed-ADT values encoded with the
Haskell serialization instances and decoded via the generated PureScript types under `node` — is red on any
composed app/workflow ADT type absent from the emitted module; and the committed seeded mutant **M-field**
(renaming one composed-ADT field) MUST break the round-trip battery, change the byte-for-byte golden, AND break
the `spago` build of both shells — a green build under M-field fails the gate, proving the shells consume the
generated types.
**Docs to update**: `documents/engineering/generated_artifacts_doctrine.md`,
`documents/engineering/lift_and_compose_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`

### Objective
Adopt [`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md#2-what-is-generated-and-from-what) §2/§3 and
[`lift_and_compose_doctrine.md`](../documents/engineering/lift_and_compose_doctrine.md#4-the-demo-web-apps-purescript-spas-contracts-generated-from-haskell) §4: regenerate the
lifted infernix/jitML demo SPAs' frontend contract types from the amoebius-composed Haskell ADTs via
`purescript-bridge`, emitted fresh at build time and never committed, so the frontend contract cannot drift
from the composed types.

### Deliverables
- An `Amoebius.Spa.Contract` renderer that emits the PureScript contract types from the composed app/workflow
  ADTs, stamped generated ("do not edit by hand; edit the source and re-emit").
- The lifted infernix/jitML PureScript demo-SPA shells under `web/`, whose exercised modules `import` and
  reference the generated contract's types (not a hand-maintained one), building with `spago`.
- A Register-1 golden pinning the emitted `*.purs` byte-for-byte as a fixture of the renderer, with **no**
  generated contract committed to the repository.
- The **independent cross-language round-trip battery** ([Gate integrity](#gate-integrity)) that encodes QuickCheck-generated composed-ADT
  values with the Haskell instances and decodes them via the generated PureScript types under `node`, covering
  every composed app/workflow ADT type — an oracle independent of the golden and the emitter.
- The committed seeded mutant **M-field** (Phase-0), whose field rename MUST break the golden, the round-trip
  battery, and the `spago` build of both shells.

### Validation
1. The generator emits the contract deterministically; the golden (Phase-0-authored) matches byte-for-byte; the
   repository holds no committed `*.purs` contract; the independent round-trip battery ([Gate integrity](#gate-integrity)) is green over every
   composed ADT type and red on any absent type.
2. The `spago` build of **each** demo SPA type-checks against the freshly-generated contract via `import`ing and
   referencing its types (removing the generated module fails the build); the committed mutant **M-field** MUST
   break the golden, the round-trip battery, and both `spago` builds — a green result under M-field fails the gate.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 13.4: The demo-SPA-local gate — Playwright against a faked backend + the ledger 📋

**Status**: Planned
**Implementation**: `test/spa/DemoSpaLocalSpec.hs` (the Register-2 driver + faked-backend fixture), `web/` (the
demo SPA served locally) (target paths; not yet built)
**Blocked by**: Sprint 13.2; Sprint 13.3; Phase 11 (the boundary fake-tool / faked-backend harness this reuses
for the local backend)
**Independent Validation**: **both** lifted PureScript demo SPAs are driven end to end under **Playwright** —
the infernix chat shell (a chat turn) *and* the jitML RL-gaming shell (one RL-gaming interaction turn); "end to
end" is fixed as: the SPA loads, issues a real request over the wire to the local faked backend, and renders the
response the backend returned (not a hardcoded DOM update). The faked backend (reusing the Phase-11 fake-tool
seam) **decodes every recorded request and encodes every response through the composed Haskell ADTs' own
serialization instances — the same source the Sprint-12.3 contract generator consumes — and is red on any
payload that does not conform** (this ties the browser wire traffic to the composed ADTs, foreclosing an SPA and
fake that agree only with each other). Call recording is read from an **OS-boundary observer** (the faked
backend's argv/HTTP-access log at the process boundary), never a self-emitted compliance trace from the SPA. The
committed seeded mutant **M-field** ([Gate integrity](#gate-integrity) — a composed-ADT field rename, regenerating the contract) MUST turn the
Playwright run red (the wire payload no longer conforms) or break the `spago` build, proving the exercised
browser path consumes the generated types. No cluster and no live infrastructure. The composite gate ledger
records `prop_spaCompositionDecodes` (Register 1) and both Playwright runs (Register 2) as green and the live SPA
deploy ([Phase 37](phase_37_spa_live_deploy.md)) as UNVERIFIED.
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md`,
`documents/engineering/testing_doctrine.md`, `DEVELOPMENT_PLAN/README.md`

### Objective
Adopt [`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) §2/§3 (the
Register-2 demo-SPA-local move) and [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing):
serve the lifted demo SPA locally against a faked backend, drive it end to end under a browser driver, and
emit the composite proven/tested/assumed ledger for both halves of the gate — never a runtime claim.

### Deliverables
- A `test/spa/DemoSpaLocalSpec.hs` that serves **both** demo SPAs locally, stands up a faked backend that
  records its calls at the OS boundary (argv/HTTP-access log, reusing the Phase-11 fake-tool seam) **and
  decodes/encodes every request/response through the composed Haskell ADTs' serialization instances, red on any
  non-conforming payload**, and drives each SPA under Playwright — asserting for the infernix shell that a chat
  turn renders the backend-returned response, and for the jitML shell that one RL-gaming interaction turn renders
  its backend-returned response, each backend call round-tripping through the composed ADTs.
- The committed seeded mutant **M-field** ([Gate integrity](#gate-integrity)) wired into this gate: with the composed-ADT field renamed and the
  contract regenerated, the Playwright run MUST go red (payload non-conformance) or the `spago` build MUST fail —
  a green run under M-field fails the gate.
- A composite gate ledger recording: the SPA composition + `prop_spaCompositionDecodes` as **proven for the
  spec composition** (Register 1), the local browser run as **tested (local, faked backend)** (Register 2), and
  the live SPA deploy, the Keycloak/Envoy edge, and any real inference as **explicitly UNVERIFIED** (owned by
  [Phase 37](phase_37_spa_live_deploy.md)).

### Validation
1. **Both** demo SPAs (infernix chat, jitML RL-gaming) are driven end to end under Playwright against the faked
   backend; each asserted turn renders the **backend-returned** response (loaded over the wire, not a hardcoded
   DOM update); every recorded request/response decodes/encodes through the composed ADTs' serialization
   instances (red on non-conformance); the calls are read from the OS-boundary observer log — no cluster, no live
   infra. The committed mutant **M-field** MUST turn this run red (or break the `spago` build).
2. The composite ledger is emitted, marking Registers 1–2 green and the live deploy UNVERIFIED; it is
   structurally insufficient to advance any production `PromotionGate`.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/app_vs_deployment_doctrine.md` — backlink §8 to the worked representational SPA
  composition: a demo fragment composed as shared-library use, proven to decode with no substrate on its
  surface (status recorded here in the plan, never as doctrine status).
- `documents/engineering/service_capability_doctrine.md` — note the SPA `.dhall` as a worked multi-service
  surface composing capability needs (§2/§7) with no product literal.
- `documents/engineering/lift_and_compose_doctrine.md` — record the lifted infernix/jitML demo-SPA shells and
  their regenerated-from-Haskell contracts (§4) as the amoebius SPA-composition fixtures.
- `documents/engineering/generated_artifacts_doctrine.md` — record the emitted PureScript contract as a worked
  never-committed generated artifact with a Register-1 golden of the renderer.
- `documents/engineering/conformance_harness_doctrine.md` / `testing_doctrine.md` — record the Register-1
  composition battery and the Register-2 demo-SPA-local run, and the composite proven/tested/assumed ledger
  they emit (live deploy UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-13 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-13 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Spa/{Spec,Workflow,Contract}.hs`, the
  `dhall/amoebius/Spa.dhall` type, the `dhall/examples/spa_*` fixtures, and the `web/` demo-SPA shells as
  Phase-13 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL vision
- [system_components.md](system_components.md) — target component inventory (the SPA modules and the
  `Spa.dhall` type)
- [substrates.md](substrates.md) — substrate registry and per-phase map
- [Application Logic vs Deployment Rules Doctrine](../documents/engineering/app_vs_deployment_doctrine.md) —
  §8 shared-library use is application logic; §2 the application-logic surface
- [Service Capability Doctrine](../documents/engineering/service_capability_doctrine.md) — the capability set
  the SPA composes, never products
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md) — the lifted PureScript
  demo SPAs and their `purescript-bridge` contracts
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — the PureScript
  contract is generated, never committed
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — Register 1 the
  representational composition; Register 2 the demo SPA run locally against a faked backend
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 the three registers and the per-run ledger
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — §5 the two typed gates the composed SPA decodes through
- [phase_11](phase_11_boundary_fake_tool_harness.md) — the boundary fake-tool / faked-backend harness this phase reuses
- [phase_37](phase_37_spa_live_deploy.md) — the live SPA deploy; its representational composition is proven here
