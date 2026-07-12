# The Formal Model: one reifiable value, two renderings

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_29_gateway_migration_drills.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/tla_modelling_assumptions.md
**Generated sections**: none

> **Purpose**: Single source of truth for how amoebius expresses a concurrent protocol as **one reifiable Haskell `Model` value** from which both the runtime decision function (`interpret`) and the TLA+ specification (`emitTLA`) are total renderings — so the model↔code correspondence holds *by construction*, and the `.tla`/`.cfg` are **generated, never-committed** artifacts.

---

## 1. Why this doctrine exists

A formal model earns its keep only if it describes the system that actually runs. The usual practice keeps
two artifacts by hand: a `.tla` specification written in TLA+, and the Haskell code that implements it. Their
relationship is then a **hand-maintained correspondence table** — "TLA+ variable `x` stands for Haskell field
`y` in module `Z`" — plus a divergence log recording every place the two have drifted. The sibling prodbox
project carries exactly this: a prose variable→module table and a numbered list of known divergences
(`prodbox/documents/engineering/tla_modelling_assumptions.md §2–§3`). That table is a standing liability: it
is never machine-checked, it rots as either artifact changes, and a green model-check proves a property of the
`.tla` that may no longer describe the code.

The obvious alternative — "keep the two artifacts in sync by discipline" — fails for the same reason every
copy-paste fails: two sources of truth diverge, and nothing forces them back together. The correspondence is
the load-bearing claim, and it is precisely the claim left unverified.

Amoebius forecloses the drift by removing the second source of truth. **The protocol is authored once, as a
reifiable Haskell value — the `Model` — and both the running decision function and the TLA+ specification are
total functions of that one value.** This is the same move the rest of the system already makes: hostbootstrap's
plan is the data (`chain :: cfg -> [Step]`, rendered to both a `--dry-run` preview and live execution), and a
Kubernetes manifest is a typed record rendered by `render` ([manifest_generation_doctrine.md](./manifest_generation_doctrine.md)).
Here the *model* is the data, TLA+ is one rendering, and the runtime step is another.

What this forecloses: a model that asserts a property the code does not have, and code that takes a transition
the model never sanctioned. Because both descend from the one `Model`, there is no correspondence table to
maintain and nothing to drift — the correspondence is a fact about the rendering functions, not a document.

---

## 2. The `Model` is data

A `Model` is a bounded transition system expressed in a deliberately small, **first-order, side-effect-free**
fragment: named state variables, an initial assignment, a set of guarded parameterized actions, named boolean
invariants, and an optional state constraint that bounds exploration. The expression language carries only what
the amoebius safety invariants need — booleans, arithmetic comparison, finite sets, quantifiers over finite
sets, function literals/update/application — and no more.

    data Model = Model
      { modelName       :: Name
      , modelConstants  :: [(Name, ConstVal)]     -- e.g. the cluster set, a bound
      , modelVars       :: [Name]                  -- state variables
      , modelInit       :: [(Name, Expr)]          -- initial value per variable
      , modelActions    :: [Action]                -- guarded, parameterized transitions
      , modelInvariants :: [(Name, Expr)]          -- named boolean SAFETY properties
      , modelFairness   :: [(Name, Fairness)]      -- per-action weak/strong fairness (WF/SF)
      , modelProperties :: [(Name, Temporal)]      -- named LIVENESS properties (temporal)
      , modelConstraint :: Maybe Expr              -- bounds the explored state space
      }

    data Action = Action                            -- a guard that, when it holds, assigns primed
      { actName   :: Name                           -- variables; unlisted variables are UNCHANGED
      , actParams :: [(Name, Expr)]                 -- each parameter ranges over a finite set
      , actGuard  :: Expr
      , actEffect :: [(Name, Expr)]
      }

The smallness is a requirement, not an economy. **To render a model to TLA+ faithfully, its transition relation
must be reified — expressed in this closed first-order fragment — not written as an opaque Haskell function.**
An arbitrary Haskell function cannot be translated to TLA+; a value in this fragment can be walked structurally.
Keeping every modelled protocol inside the fragment is the price of "generate the `.tla`, never hand-write it,"
and it is affordable because the one obligation amoebius models is small (a handful of variables — see
[gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md)).

**Safety and liveness are both first-class.** `modelInvariants` are boolean **safety** properties (checked on
every reachable state). Some protocol guarantees are irreducibly **liveness** — *progress*, not just the
absence of a bad state: the anti-split-brain guarantee amoebius most cares about is that the forest
*eventually converges to exactly one owner* ([gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md)),
which a safety invariant cannot express (a stuck state with *zero* owners satisfies "at most one" yet has not
converged). The fragment therefore carries two more closed, structurally-walkable pieces alongside the
first-order `Expr`:

    data Fairness = WeakFair | StrongFair          -- WF_vars / SF_vars on an action
    data Temporal                                   -- the minimal liveness sub-fragment
      = Always     Expr                             -- []P
      | Eventually Expr                             -- <>P
      | LeadsTo    Expr Expr                        -- P ~> Q  (P leads to Q)

`modelFairness` annotates the actions whose continued enablement the liveness argument assumes; `modelProperties`
are the named temporal goals. Both are as small and closed as the safety fragment, so `emitTLA` walks them
structurally too ([§3](#3-two-total-renderings)); what liveness costs — a *fairness assumption*, and a checker
that reasons about infinite behaviours — is paid honestly in [§3](#3-two-total-renderings) and
[§6](#6-what-a-green-model-check-proves-and-what-it-does-not), never hidden.

---

## 3. Two total renderings

One `Model` value is consumed by two total functions:

- **`interpret :: Model -> (Event -> State -> State)`** — the runtime decision core. Given a state and an event
  (an action under a parameter binding), it computes the next state. This is the pure function a daemon calls to
  decide what to do next; it is unit-testable with no cluster (Register 1, [conformance_harness_doctrine.md](./conformance_harness_doctrine.md)).
- **`emitTLA :: Model -> (Tla, Cfg)`** — renders the same value to a TLA+ module and its configuration, which
  TLC then model-checks. The emitter is a structural walk of the fragment: state variables become `VARIABLES`,
  the initial assignment becomes `Init`, each action becomes an operator, their disjunction becomes `Next`, the
  invariants become named operators listed as `INVARIANT`s in the `.cfg`, and the constraint becomes a
  `CONSTRAINT`. The **liveness** pieces render too: each `modelFairness` entry becomes a `WF_vars`/`SF_vars`
  conjunct on the temporal `Spec` formula, and each `modelProperties` entry becomes a named temporal operator
  listed as a `PROPERTY` in the `.cfg` — so TLC checks liveness under the declared fairness, not merely safety.

**Safety is checked by both readings; liveness is checked by TLC only.** The in-process explorer
([§4](#4-correspondence-by-construction)) is a bounded *reachability* search — it evaluates every safety
invariant on every reachable state, but it does **not** detect infinite/lasso behaviours and so does **not**
check `modelProperties`. Liveness is therefore a **TLC-only** verdict; the explorer↔TLC agreement cross-check
covers safety only. This asymmetry is deliberate (a lasso/SCC liveness checker in-process is a large lift for
little marginal assurance) and is carried into the honesty ledger ([§6](#6-what-a-green-model-check-proves-and-what-it-does-not)).

The interpreter and the emitter are the *only* two consumers, and each is a faithful denotation of the fragment.
Their agreement on the meaning of every constructor is what makes the single source trustworthy.

---

## 4. Correspondence by construction

Because `interpret` and `emitTLA` are two renderings of one `Model`, there is **no variable→code correspondence
table and no divergence log** — the artifacts amoebius does not inherit from the prodbox practice. The
correspondence is a property of the rendering functions, discharged once for all models, not a per-model prose
obligation.

Correspondence is made *testable* by a second in-process reading of the same value: a bounded reachability
explorer over `interpret` (breadth-first over reachable states, pruned by the constraint, checking every
invariant on every reachable state — the same shape TLC applies to the emitted spec). A model is validated by
running **both** checkers on the same `Model`:

- the in-process explorer (Register 1, a `cabal test`), and
- TLC on the emitted `.tla` (Register 1 as well; run through the standard `tla2tools` toolchain).

A validated model is one where both agree — green on the correct model — **and both go red under the same
mutation** (a deliberately broken variant of the model reaches the illegal state and both checkers report it).
Agreement plus shared sensitivity to a seeded fault is the operational form of "the two renderings mean the same
thing." This agreement is a **safety** cross-check: both the explorer and TLC evaluate the safety invariants, so
their agreement catches an `emitTLA`/`interpret` divergence on the safety semantics. Liveness has no such
cross-check ([§3](#3-two-total-renderings)) — it is checked by TLC alone.

**Assurance accounting — what "by construction" does and does not buy.** Two precisions keep the guarantee from
being over-read. First, correspondence-by-construction is between the TLA+ spec and the **decision core**
(`interpret`), *not* between the spec and the effectful **daemon**: `interpret` is the pure function a daemon
*calls*, but whether the daemon captures its inputs with the right freshness/fencing and applies the decision
faithfully is a separate, **runtime-fidelity** obligation (Register-2.5 deterministic simulation and Register-3
chaos, [conformance_harness_doctrine.md](./conformance_harness_doctrine.md),
[chaos_failover_doctrine.md §12](./chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)). Second,
running the explorer, TLC, and io-sim over one `Model` yields **one** protocol proof (the TLC run) plus two
**cross-checks on the renderers** (the explorer over `interpret`, io-sim over the lifted core) — not three
independent proofs of the protocol. The value of the ensemble is real (it hardens the load-bearing renderers,
[§7](#7-prototype-validation), and exercises schedules the pure core leaves open) but must not be triple-counted
as three separate assurances.

**Faithfulness is the load-bearing meta-property, and it is checked — not merely asserted.** The whole scheme
rests on `emitTLA` and `interpret` being faithful denotations of *every* constructor; a renderer bug (a
mistranslated quantifier, a dropped `UNCHANGED`, a mis-ordered primed assignment, a wrong `CONSTRAINT`
semantics) would silently make TLC check a different protocol than the daemon runs. Round-tripping one `ToyModel`
plus one seeded mutation is thin coverage for a property this load-bearing. The operational form of "faithful
denotation" is therefore a **differential property test**: a generator over the `Model` fragment produces random
small models, and the explorer and TLC are run on each under a **pinned convention** — the explorer mirrors
TLC's `CONSTRAINT` semantics (a boundary state that violates the constraint is counted and its invariants
checked but is **not** expanded), `CHECK_DEADLOCK` is set explicitly on both sides, and the test asserts the two
produce identical **canonical state-fingerprint *sets*** — not merely equal cardinality, which equal counts
alone do not establish (equal count + equal verdict is not equal state set) — alongside the same verdict,
shrinking any divergence to a minimal offending model. This differential faithfulness claim is **scoped to the
safety sub-fragment**: the generator exercises `emitTLA`'s `Init`/`Next`/`INVARIANT`/`CONSTRAINT` rendering, and
the explorer checks no liveness, so the `modelFairness`/`modelProperties` (`WF`/`SF`/`PROPERTY`) rendering is
**not** covered by this test and rests on the `emitTLA` golden and the TLC-only liveness runs instead. This is the single most valuable place in the
kernel for a **proof assistant**: a machine-checked meta-theorem that each `Expr`/`Temporal` constructor's
`interpret`-denotation equals the TLA+ denotation `emitTLA` targets would upgrade faithfulness from
*tested* to *proven*. That meta-theorem, and the fold-closure proofs the confluence ledger requires
([chaos_failover_doctrine.md §19](./chaos_failover_doctrine.md#19-the-cross-boundary-ledger-and-conformance-rows)),
are the **only** two places a proof assistant is warranted here — adopt it surgically (evaluate Liquid Haskell,
which checks the *actual* Haskell and so introduces no second artifact to drift, against Lean) or not at all; a
broad proof-assistant layer would re-introduce exactly the artifact-drift the `Model`-as-data pattern exists to
foreclose ([§1](#1-why-this-doctrine-exists)).

---

## 5. The `.tla`/`.cfg` are generated, never committed

The TLA+ module and its configuration are **build artifacts**, emitted from the `Model` SSoT by an `amoebius`
subcommand and stamped as generated. They are **not** committed to the repository, exactly like the rendered
Kubernetes manifests and the Dhall schema reflected from Haskell types
([generated_artifacts_doctrine.md](./generated_artifacts_doctrine.md)). Model-checking regenerates them from the
current `Model` and runs TLC; a stale committed `.tla` cannot exist because there is no committed `.tla`. This is
the mechanical guarantee behind [§4](#4-correspondence-by-construction): the only authored artifact is the
Haskell `Model`.

---

## 6. What a green model-check proves, and what it does not

Per the honesty discipline ([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline),
[chaos_failover_doctrine.md](./chaos_failover_doctrine.md)):

- **Proven-for-the-model, at the declared bound.** A green TLC run is an exhaustive proof that the declared
  invariants hold on every reachable state of the model *at the bounded scope*. It is a real result, and because
  the model is the same value the runtime interprets, it is a result about the shape the code takes — not about a
  separate hand-written abstraction.
- **Liveness is proven only under the named fairness, and only by TLC.** A green `PROPERTY` result proves a
  `modelProperties` liveness goal holds on the model **under the `modelFairness` assumptions** — which are
  themselves an *assumed* premise (a real system starves an action if a scheduler is adversarial), recorded like
  the R8 synchrony premise ([chaos_failover_doctrine.md §13](./chaos_failover_doctrine.md#13-the-supporting-rules--the-conditions-the-moves-need)),
  never proven. A liveness `PROPERTY` is furthermore **not** checked under a state `CONSTRAINT`: a `CONSTRAINT`
  truncates the behaviour graph at the bound and distorts `WF`/`SF` enabledness, so a continuously-enabled action
  can be cut off at the boundary and TLC report a *spurious* green liveness **within** the bound — a distortion
  the "not a general-scope proof" bullet below (which speaks only to what lies *beyond* the bound) does not
  cover. Amoebius therefore **finitizes** every liveness run — bounding the state space through `CONSTANTS` and
  finite, saturating variable domains rather than a state `CONSTRAINT` — so `PROPERTY` checking runs
  **`CONSTRAINT`-free**; where a run instead retains a `CONSTRAINT`, TLC's constraint-truncation semantics is
  recorded as an explicit *assumed* premise, and which of the two a run uses is stated. A liveness green is
  credible only with a **fairness-sensitivity check**: the property must go
  **red** when the fairness assumption is removed (otherwise it was vacuously true and the fairness annotation
  was load-bearing on nothing). The in-process explorer does not check liveness at all ([§3](#3-two-total-renderings)),
  so a liveness verdict is TLC-only and carries no explorer cross-check.
- **Not a general-scope proof.** Bounded model-checking proves nothing beyond its bound unless a **cutoff**
  argument reduces the general case to the bounded one. Where amoebius relies on such a reduction it states the
  reduction explicitly ([gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md)); absent a
  cutoff, "green at scope *N*" is exactly that.
- **Not a proof that the model is the right model.** Model-checking proves the model satisfies its invariants,
  never that the invariants are the right ones or that the model faithfully captures the intended protocol. That
  faithfulness is a human act, unchecked by any tool, and is called out as an assumption.
- **One-and-done, never per-`InForceSpec`.** The protocol is model-checked **once**, at design time, over the
  bounded model. TLC is a whole-state-space search and **never** runs on the spec-decode path. What runs
  per-`InForceSpec` is a fast, total **decode-time structural-fit fold** that rejects any spec falling outside
  the envelope the one-and-done proof assumed. This split is owned in detail by
  [gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md).

---

## 7. Prototype validation

The mechanism of this doctrine — a `Model` value, the `interpret` explorer, and the `emitTLA` renderer producing
a TLC-checkable spec — was **prototyped in a throwaway spike** over a small transition-system model. The spike
confirmed the load-bearing claims end to end: the in-process explorer and TLC reached the *same* verdict on the
generated spec (identical reachable-state count), and a seeded mutation of the model produced the *expected*
counterexample in both. The spike has been removed; per
[documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline) this
is **evidence that the mechanism works**, not a built amoebius result — the implementation is deferred to its
phase ([DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md)).

---

## 8. Trace validation: the earlier code↔model bridge

Correspondence-by-construction ([§4](#4-correspondence-by-construction)) closes the spec↔decision-core gap, but
the spec↔**daemon** gap — that the *effectful* runtime only ever takes transitions the `Model` sanctions — is a
runtime-fidelity obligation. The design's default instrument for it is Register-3 chaos injection, which is
*sampled* and *late*. **Trace validation** is a formal, earlier bridge that reuses the same `Model`: the daemon
emits a structured **transition log** (its observed `(state, action, state')` steps), and a checker asserts each
observed step is a legal `Next`-step of the emitted spec — the conformance/"eXtreme-modelling" pattern (record
the implementation's real trace, replay it against the TLA+ `Next` relation). Because the spec is generated from
the `Model` the daemon's `interpret` already renders, the trace-check needs no separate abstraction map. It is a
**partial** discharge — it proves the observed transitions were legal, not that every reachable transition is —
so it is honestly weaker than the exhaustive design proof and stronger than sampled chaos; it can run in
Register 2.5 (against the deterministically-simulated daemon,
[deterministic_simulation_doctrine.md](./deterministic_simulation_doctrine.md)) and in Register 3 (against the
live forest). The concrete obligation for the one model is owned by
[gateway_migration_model_doctrine.md §6](./gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty).

---

## 9. Planning ownership

This document is normative formal-model doctrine only. It is authored in the documentation phase; the `Model`
EDSL, the `interpret` explorer, and the `emitTLA` renderer are built and validated in the pre-cluster
formal-model phase, and the one concrete model (gateway migration) is authored and model-checked there. Phase
order, status, and gates live only in [DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md); this doc
states the target shape and links back for status. Every prescriptive statement here is design intent, never a
tested amoebius result.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Gateway Migration Model](./gateway_migration_model_doctrine.md) — the one concrete `Model`: both branches of `GatewayMigration`, model-checked and simulated
- [Chaos & Failover Doctrine](./chaos_failover_doctrine.md) — the Extract→Model→Inject methodology and the proven/tested/assumed ledger this rendering serves
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md) — why the emitted `.tla`/`.cfg` are never committed
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — the Register-1 in-process explorer that mirrors TLC
- [Deterministic Simulation Doctrine](./deterministic_simulation_doctrine.md) — the Register-2.5 io-sim environment that runs the real daemon against a modeled world; the trace-validation home for the built code
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — the sibling "render a typed value to its artifact" pattern
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
