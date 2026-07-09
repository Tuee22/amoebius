# The Formal Model: one reifiable value, two renderings

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/system_components.md
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
      , modelInvariants :: [(Name, Expr)]          -- named boolean safety properties
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

---

## 3. Two total renderings

One `Model` value is consumed by two total functions:

- **`interpret :: Model -> (Event -> State -> State)`** — the runtime decision core. Given a state and an event
  (an action under a parameter binding), it computes the next state. This is the pure function a daemon calls to
  decide what to do next; it is unit-testable with no cluster (Register 1, [conformance_harness_doctrine.md](./conformance_harness_doctrine.md)).
- **`emitTLA :: Model -> (Tla, Cfg)`** — renders the same value to a TLA+ module and its configuration, which
  TLC then model-checks. The emitter is a structural walk of the fragment: state variables become `VARIABLES`,
  the initial assignment becomes `Init`, each action becomes an operator, their disjunction becomes `Next`, the
  invariants become named operators listed in the `.cfg`, and the constraint becomes a `CONSTRAINT`.

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
thing."

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

## 8. Planning ownership

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
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — the sibling "render a typed value to its artifact" pattern
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
