# The Formal Model: one reifiable value, two renderings

> **Purpose**: Single source of truth for how amoebius expresses a concurrent protocol as **one reifiable Haskell `Model` value** from which both the runtime decision function (`interpret`) and the TLA+ specification (`emitTLA`) are total renderings — minimizing drift while differential checks test their correspondence — and the `.tla`/`.cfg` are **generated, never-committed** artifacts.
> **Read this if**: a protocol has to be model-checked, or a model-checking result has to be read for its actual reach.

This document owns the model-as-data discipline: one reifiable value, two total renderings, and the boundary
between what a green model-check establishes and what running code must still earn. It does not own the
protocol being modelled, owned by
[gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md), nor the simulation layer that
bridges model and implementation, owned by
[deterministic_simulation_doctrine.md](./deterministic_simulation_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_12_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_13_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_14_symbolic_checker.md, DEVELOPMENT_PLAN/phase_15_refinement_checker.md, DEVELOPMENT_PLAN/phase_18_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_19_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_20_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_76_gateway_migration_drills.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/chaos_failover_second_axis.md, documents/engineering/chaos_failover_worked_examples.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/preflight_validation_doctrine.md, documents/engineering/tla_modelling_assumptions.md, documents/glossary.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents
- [1. Why this doctrine exists](#1-why-this-doctrine-exists)
- [2. The `Model` is data](#2-the-model-is-data)
- [3. Two total renderings](#3-two-total-renderings)
- [4. Single-source correspondence](#4-single-source-correspondence)
- [5. The `.tla`/`.cfg` are generated, never committed](#5-the-tlacfg-are-generated-never-committed)
- [6. What a green model-check proves, and what it does not](#6-what-a-green-model-check-proves-and-what-it-does-not)
- [7. Prototype validation](#7-prototype-validation)
- [8. Trace validation: the earlier code↔model bridge](#8-trace-validation-the-earlier-codemodel-bridge)
- [9. Planning ownership](#9-planning-ownership)
- [Related Documents](#related-documents)

---

## 1. Why this doctrine exists

A formal model is only useful when it describes the system that actually runs. The usual practice keeps
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

amoebius forecloses the drift by removing the second source of truth. **The protocol is authored once, as a
reifiable Haskell value — the `Model` — and both the running decision function and the TLA+ specification are
total functions of that one value.** This is the same move the rest of the system already makes: hostbootstrap's
plan is the data (`chain :: cfg -> [Step]`, rendered to both a `--dry-run` preview and live execution), and a
Kubernetes manifest is a typed record rendered by `renderAll` ([manifest_generation_doctrine.md](./manifest_generation_doctrine.md)).
Here the *model* is the data, TLA+ is one rendering, and the runtime step is another.

What this forecloses: a model that asserts a property the code does not have, and code that takes a transition
the model never sanctioned. Because both descend from the one `Model`, there is no correspondence table to
maintain and nothing to drift — the correspondence is a fact about the rendering functions, not a document.

---

## 2. The `Model` is data

A `Model` is a bounded transition system expressed in a deliberately small, **first-order, side-effect-free**
fragment: named state variables, an initial assignment, a set of guarded parameterized actions, named boolean
invariants, and an optional state constraint that bounds exploration. The expression language carries only what
the amoebius safety and liveness properties need — booleans, bounded integer arithmetic and comparison, finite
sets with cardinality, quantifiers over finite sets, function literals/update/application, and a conditional —
and no more. The constructor set is declared below rather than described, so the differential generator's
per-constructor coverage floor ([DEVELOPMENT_PLAN/phase_12_formal_model_kernel.md](../../DEVELOPMENT_PLAN/phase_12_formal_model_kernel.md))
quantifies over an enumerated set and not over prose.

The owning gate must exercise every constructor below through both renderings and a separately implemented
checker. Its composition adapter consumes the real calculus sequence and resource fold rather than defining a
formal substitute. The development plan alone records whether that obligation has been validated.

```haskell
data Model = Model
  { modelName       :: Name
  , modelConstants  :: [(Name, ConstVal)]     -- e.g. the cluster set, a bound
  , modelVars       :: [Name]                  -- state variables
  , modelInit       :: [(Name, Expr)]          -- initial value per variable
  , modelActions    :: [Action]                -- guarded, parameterized transitions
  , modelInvariants :: [(Name, Expr)]          -- named boolean SAFETY properties
  , modelFairness   :: [(Name, Fairness)]      -- per-action weak/strong fairness (WF/SF)
  , modelProperties :: [(Name, Temporal)]      -- named LIVENESS properties (temporal)
  , modelConstraint :: Maybe Expr              -- TLC state constraint (excludes failing states)
  , modelExpansionLimit :: Maybe Expr           -- checked boundary state is not expanded
  }

data Action = Action                            -- a guard that, when it holds, assigns primed
  { actName   :: Name                           -- variables; unlisted variables are UNCHANGED
  , actParams :: [(Name, Expr)]                 -- each parameter ranges over a finite set
  , actGuard  :: Expr
  , actEffect :: [(Name, Expr)]
  }

type Name = Text                                -- a TLA+-legal identifier

data ConstVal                                   -- the closed value domain: what a CONSTANT holds,
  = CBool  Bool                                 -- what a state variable holds, and what an Expr
  | CInt   Integer                              -- evaluates to
  | CStr   Text                                 -- a model value / enumerated symbol
  | CSet   (Set ConstVal)                        -- a finite set
  | CFun   (Map ConstVal ConstVal)               -- a finite function (TLA+ [d -> r])

data Expr                                       -- closed, first-order, side-effect-free
  = Lit     ConstVal                            -- a literal in the value domain
  | Var     Name                                -- read a state variable in the pre-state
  | Param   Name                                -- read an action parameter's binding
  | Const   Name                                -- read a CONSTANT
  | Not     Expr        | And   Expr Expr       -- boolean
  | Or      Expr Expr   | Implies Expr Expr
  | Eq      Expr Expr   | Lt    Expr Expr       -- equality and arithmetic comparison
  | Le      Expr Expr
  | Add     Expr Expr   | Sub   Expr Expr       -- bounded integer arithmetic
  | Card    Expr                                -- finite-set cardinality
  | SetLit  [Expr]      | Union Expr Expr       -- finite sets
  | Diff    Expr Expr   | Member Expr Expr
  | Forall  Name Expr Expr                       -- forall x \in S : P  (S finite)
  | Exists  Name Expr Expr                       -- exists x \in S : P  (S finite)
  | FunLit  Name Expr Expr                       -- [ x \in S |-> e ]
  | FunApp  Expr Expr                            -- f[x]
  | FunUpd  Expr Expr Expr                       -- [ f EXCEPT ![x] = e ]
  | IfThen  Expr Expr Expr
```

**Reading state, and priming.** `Expr` denotes over the **pre-state**: `Var` reads a state variable's current
value, `Param` reads the enclosing action's parameter binding, `Const` reads a `CONSTANT`. There is no primed
term-former, deliberately. Priming is **structural**: the `Name` key of an `actEffect` pair *is* the primed
variable, its `Expr` value is evaluated in the pre-state, and every `modelVars` entry absent from `actEffect`
is `UNCHANGED`. A next-state value therefore cannot be read inside an expression, which is what keeps the
fragment first-order and makes `emitTLA`'s walk a local translation rather than a scope analysis.

`Expr` is **unityped**: nothing at the Haskell type level forbids `And (Lit (CInt 1)) …`. That is a recorded
decision, not an oversight — a GADT-indexed `Expr t` would buy well-formedness at the cost of a generator
(`§4`) that must produce well-typed values by construction, which is the harder half of the differential
test. Ill-sorted expressions are instead rejected by a total well-formedness pass at model-construction time
(booleans where `modelInvariants` and `actGuard` require them; a finite set where `actParams`, `Forall`,
`Exists`, and `FunLit` require one; a `modelFairness` key that names a declared `modelActions` entry), and
that pass is a decode-style check, never claimed as a type fact.

**`Card` and `Add`/`Sub` are load-bearing, not decoration.** amoebius's one obligation states its convergence
goal as `ownerCount ~> ownerCount = 1`
([gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md)); `ownerCount` is the
cardinality of the owner set, so a fragment with comparison but no cardinality former could not express the
property the model exists to prove. The bounded arithmetic serves the same role for the replication offset and
the accrued-divergence bound. The fragment is as small as it can be *and still express the one model* — not
smaller.

The smallness is a requirement, not an economy. **To render a model to TLA+ faithfully, its transition relation must be reified — expressed in this closed first-order fragment — not written as an opaque Haskell function.**
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

```haskell
data Fairness = WeakFair | StrongFair          -- WF_vars / SF_vars on an action
data Temporal                                   -- the minimal liveness sub-fragment
  = Always     Expr                             -- []P
  | Eventually Expr                             -- <>P
  | LeadsTo    Expr Expr                        -- P ~> Q  (P leads to Q)
```

`modelFairness` annotates the actions whose continued enablement the liveness argument assumes; `modelProperties`
are the named temporal goals. Both are as small and closed as the safety fragment, so `emitTLA` walks them
structurally too ([§3](#3-two-total-renderings)); what liveness costs — a *fairness assumption*, and a checker
that reasons about infinite behaviours — is paid honestly in [§3](#3-two-total-renderings) and
[§6](#6-what-a-green-model-check-proves-and-what-it-does-not), never hidden.

---

## 3. Two total renderings

The types the two renderings consume and produce are closed and small:

```haskell
type State = Map Name ConstVal                  -- one binding per `modelVars` entry, total over it
data Event = Event                              -- an action under a parameter binding
  { evAction :: Name                            -- names a `modelActions` entry
  , evArgs   :: Map Name ConstVal               -- one binding per `actParams` entry
  }
newtype Tla = Tla Text                          -- the rendered module
newtype Cfg = Cfg Text                          -- the rendered TLC configuration
```

One `Model` value is consumed by two total functions:

- **`interpret :: Model -> Event -> State -> Maybe State`** — the runtime decision core. Given a state and an
  event (an action under a parameter binding), it computes the next state. It returns `Nothing` exactly when
  the event is **not enabled** — the named action's `actGuard` evaluates false under the binding, or the event
  names no declared action — and `Just` the successor otherwise; a disabled event is not an error and is not
  an identity step, because a self-loop would fabricate a stuttering transition TLA+'s `Next` does not
  sanction. Totality is the absence of partiality, not the absence of a `Nothing` case. This is the pure
  function a daemon calls to
  decide what to do next; it is unit-testable with no cluster (Register 1, [conformance_harness_doctrine.md](./conformance_harness_doctrine.md)).
  The explorer's companion is **`enabledEvents :: Model -> State -> [Event]`**, the finite enumeration of every action × parameter binding whose guard holds in a state — finite because each `actParams` range is a finite set — which is what makes the breadth-first frontier of [§4](#4-single-source-correspondence)
  computable at all.
- **`emitTLA :: Model -> (Tla, Cfg)`** — renders the same value to a TLA+ module and its configuration, which
  TLC then model-checks. The emitter is a structural walk of the fragment: state variables become `VARIABLES`,
  the initial assignment becomes `Init`, each action becomes an operator, their disjunction becomes `Next`, the
  invariants become named operators listed as `INVARIANT`s in the `.cfg`, and the constraint becomes a
  `CONSTRAINT`. The **liveness** pieces render too: each `modelFairness` entry becomes a `WF_vars`/`SF_vars`
  conjunct on the temporal `Spec` formula, and each `modelProperties` entry becomes a named temporal operator
  listed as a `PROPERTY` in the `.cfg` — so TLC checks liveness under the declared fairness, not merely safety.

**Safety is checked by both readings; liveness is checked by TLC only.** The in-process explorer
([§4](#4-single-source-correspondence)) is a bounded *reachability* search — it evaluates every safety
invariant on every reachable state, but it does **not** detect infinite/lasso behaviours and so does **not**
check `modelProperties`. Liveness is therefore a **TLC-only** verdict; the explorer↔TLC agreement cross-check
covers safety only. This asymmetry is deliberate (a lasso/SCC liveness checker in-process is a large lift for
little marginal assurance) and is carried into the honesty ledger ([§6](#6-what-a-green-model-check-proves-and-what-it-does-not)).

The interpreter and the emitter are the *only* two consumers, and each is intended to denote the same fragment.
Their checked agreement on the meaning of every constructor is what makes the single source trustworthy.

---

```mermaid
flowchart LR
  %% register: algebra
  m["Model: one reifiable value"]:::intent
  i[["interpret :: Model -> Event -> State -> Maybe State"]]:::intent
  e[["emitTLA :: Model -> Tla"]]:::intent
  dec["the runtime decision, Nothing where an event is disabled"]:::intent
  tla["generated .tla and .cfg, never committed"]:::intent
  tlc{{"TLC model check"}}:::gate
  ok((("safety and liveness established for the model"))):::seal
  no>"counterexample trace: the model is wrong, not the code"]:::refuse
  m -->|"binds the model"| i
  m -->|"binds the same model"| e
  i --> dec
  e --> tla
  tla --> tlc
  tlc -->|"no counterexample"| ok
  tlc -->|"counterexample"| no
  classDef intent   fill:#e8eef7,stroke:#33587a,color:#12283f,stroke-width:1px
  classDef gate     fill:#fde9c8,stroke:#b8791b,color:#5c3a06,stroke-width:2px
  classDef seal     fill:#d3f0dd,stroke:#1f8a4c,color:#0c3a1f,stroke-width:2px
  classDef refuse   fill:#f8d6d6,stroke:#b23636,color:#5c1414,stroke-width:2px
```
*Design intent, Tier-1. Two total renderings of one value, which is what makes the correspondence between the checked model and the running decision function structural rather than asserted. A green check establishes properties of the model alone; what the code owes beyond that is stated in [§6](#6-what-a-green-model-check-proves-and-what-it-does-not). Vocabulary: [diagram_conventions.md](./diagram_conventions.md).*

## 4. Single-source correspondence

Because `interpret` and `emitTLA` are two renderings of one `Model`, there is **no per-model variable→code correspondence table and no divergence log**. Sharing the source removes one class of manual
drift, but it does not prove the two rendering functions semantically equivalent. Renderer faithfulness is one
reusable meta-obligation, checked across the fragment rather than asserted separately in prose for each model.

Correspondence is made *testable* by a second in-process reading of the same value: a bounded reachability
explorer over `interpret` (breadth-first over reachable states, pruned by the TLC state constraint, checking every
invariant on every reachable state — the same shape TLC applies to the emitted spec). A model is validated by
running **both** checkers on the same `Model`:

- the in-process Haskell explorer suite (Register 1, a supporting observation rather than a phase verdict), and
- TLC on the emitted `.tla` (Register 1 as well; run through the standard `tla2tools` toolchain).

A validated model is one where both agree — green on the correct model — **and both go red under the same mutation** (a deliberately broken variant of the model reaches the illegal state and both checkers report it).
Agreement plus shared sensitivity to a seeded fault is the operational form of "the two renderings mean the same
thing." This agreement is a **safety** cross-check: both the explorer and TLC evaluate the safety invariants, so
their agreement catches an `emitTLA`/`interpret` divergence on the safety semantics. Liveness has no such
cross-check ([§3](#3-two-total-renderings)) — it is checked by TLC alone.

**Assurance accounting — what the single source does and does not buy.** Two precisions keep the guarantee from
being over-read. First, checked correspondence is between the TLA+ spec and the **decision core**
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
small models, and the explorer and TLC are run on each under a **pinned convention**. TLC's actual
`CONSTRAINT` semantics excludes a failing successor from the distinct-state set; the explorer mirrors that
exactly. The separate `modelExpansionLimit` is compiled into every action's source guard so a state reached at
that boundary remains distinct and invariant-checked but is **not** expanded in either reading.
`CHECK_DEADLOCK` is set explicitly on both sides, and the test asserts the two
produce identical **canonical state-fingerprint *sets*** — not merely equal cardinality, which equal counts
alone do not establish (equal count + equal verdict is not equal state set) — alongside the same verdict,
shrinking any divergence to a minimal offending model. This differential faithfulness claim is **scoped to the safety sub-fragment**: the generator exercises `emitTLA`'s `Init`/`Next`/`INVARIANT`/`CONSTRAINT` rendering, and
the explorer checks no liveness, so the `modelFairness`/`modelProperties` (`WF`/`SF`/`PROPERTY`) rendering is
**not** covered by this test and rests on the independently reviewed Haskell renderer-semantics oracle and the TLC-only liveness
runs instead. This is the single most valuable place in the
kernel for a **proof assistant**: a machine-checked meta-theorem that each `Expr`/`Temporal` constructor's
`interpret`-denotation equals the TLA+ denotation `emitTLA` targets would upgrade faithfulness from
*tested* to *proven*. That meta-theorem, and the fold-closure proofs the confluence ledger requires
([chaos_failover_second_axis.md §19](./chaos_failover_second_axis.md#19-the-cross-boundary-ledger-and-conformance-rows)),
are the **only** two places a proof assistant is warranted here — adopt it surgically (evaluate Liquid Haskell,
which checks the *actual* Haskell and so introduces no second artifact to drift, against Lean) or not at all; a
broad proof-assistant layer would re-introduce exactly the artifact-drift the `Model`-as-data pattern exists to
foreclose ([§1](#1-why-this-doctrine-exists)).

### 4.1 The reference model and its semantic oracle

**The problem.** The renderers are the load-bearing artifacts, and nothing in the scheme so far exercises them
against an expectation authored independently of them. A renderer validated only by re-running itself proves
that it is stable, not that it is right; and the differential test above is **safety-scoped**, so an emitter
that renders `StrongFair` as `WF_vars`, or swaps `[]` for `<>`, is invisible to every other oracle in the kernel. Both gaps are invisible at author time and surface as a TLC run that model-checks a protocol the daemon does not implement.

**Why a byte snapshot fails.** Copying the renderer's first output into source tests only whether the next
output is identical to the last. It cannot distinguish a semantic repair from a regression, and regenerating
the snapshot after a failure erases its evidence. The content address already observes byte change. Acceptance
therefore asks what the generated module *means*, not whether its whitespace and declaration layout remained
frozen.

**The chosen rule.** The kernel carries a **reference model** — one small, complete, independently reviewed Haskell `Model`
that exists only to validate the renderers, distinct from every model that describes a real amoebius protocol.
Its committed Haskell expectations are semantic:

1. A distinct Haskell renderer-semantics module fixes the exact set of module, extension, declaration,
   initial-assignment, action, fairness-strength, invariant, constraint, temporal-kind, specification, and
   deadlock facts. The suite extracts those facts from freshly rendered `.tla`/`.cfg` and compares sets in
   both directions.
2. A distinct Haskell invariant-case module fixes an independently authored truth table over valid and invalid
   states. It catches obligation weakening that retains the same invariant name and would remain green under
   model checking.
3. The safety differential and TLC syntax/semantic run retain the details a fact projection intentionally
   does not restate: action effects, `UNCHANGED`, quantifier denotation, precedence, state constraints, and the
   complete reachable-state fingerprint set.
4. Non-vacuity remains structural: the reference model must carry finite quantifier and function
   literal/update/application nodes, both fairness constructors, and all three temporal constructors.

The two liveness renderer mutants (`StrongFair`→`WeakFair`, `Always`→`Eventually`) must change the fact set;
the invariant-clause deletion must change the truth table; the two safety renderer mutants must diverge from
the explorer under TLC. This partition matters: no one oracle is credited for a defect it cannot observe.

**What it forecloses.** Generated TLA+/CFG bytes may be reformatted without an expectation rewrite, but their
declared semantics may change only through the oracle-amendment discipline
([development_plan_standards.md §M](../../DEVELOPMENT_PLAN/development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)).
Copying fresh output into an expected fixture remains prohibited. The concrete reference model — its name, its
protocol, its Haskell oracle modules, and the mutants that must break them — is specified by the
formal-model phase contract in
[DEVELOPMENT_PLAN/phase_12_formal_model_kernel.md](../../DEVELOPMENT_PLAN/phase_12_formal_model_kernel.md);
this doctrine owns only the obligation and its rationale. The reference model is specified to qualify the
**kernel**; whether its gate has done so is plan status. It is not an amoebius protocol, and no protocol claim
follows from it. The obligations intended to ride a qualified kernel are the **cross-cluster gateway migration**
([gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md)) and the **DSL's own semantics**
— the decoder, the folds, `renderAll`, the `chain`/`Step` descent, the reconcile invariants, and the
snapshot-token/CAS and reservation protocols.

**Why the DSL is modelled, when its pure surfaces are already total.** A model adds nothing to totality that
the type system has not already settled. The pure-surface obligation is therefore a **bounded differential**:
actual Haskell behavior is compared with independently authored semantic expectations over declared finite
cases and domains. That catches disagreement at those bounds; it is neither a TLA+-to-Haskell refinement proof
nor a claim over the unbounded DSL. Generated normalization hashes are change detectors and do not count as
semantic acceptance. The obligations that a model alone can discharge are the ones about
**behaviour over time** — a token that must not be reused after an observed transition, a reservation that
must not double-debit, a Lease that must admit one writer. No type in the decoder constrains their
interleavings. Without that model and an accepted gate, only the motivating seed observation remains; it is
not amoebius validation evidence.

---

## 5. The `.tla`/`.cfg` are generated, never committed

The TLA+ module and its configuration are **build artifacts**, emitted from the `Model` SSoT by an `amoebius`
subcommand and stamped as generated. They are **not** committed to the repository, exactly like the rendered
Kubernetes manifests and the Dhall schema reflected from Haskell types
([generated_artifacts_doctrine.md](./generated_artifacts_doctrine.md)). Model-checking regenerates them from the
current `Model` and runs TLC; a stale committed `.tla` cannot exist because there is no committed `.tla`. This is
the mechanical guarantee behind [§4](#4-single-source-correspondence): the only authored artifact is the
Haskell `Model`.

---

## 6. What a green model-check proves, and what it does not

Per the honesty discipline ([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline), [chaos_failover_doctrine.md](./chaos_failover_doctrine.md)):

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
  cover. amoebius therefore **finitizes** every liveness run — bounding the state space through `CONSTANTS` and
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

### 6.1 The proof stack is amoebius-owned

The limits above are the reason there is more than one checker, and the reason every one of them is amoebius's
own. A guarantee this corpus rests on cannot depend on a third party's maintenance decisions — the argument
[`lift_and_compose_doctrine.md` §1](./lift_and_compose_doctrine.md#1-why-this-doctrine-exists) makes about
seeds, and [`pulsar_client_doctrine.md` §1](./pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets)
makes about the message client, applies with more force here: a checker that stops being maintained, changes
its semantics, or drops a feature invalidates proofs already recorded as evidence.

Four layers, each answering a limit the one above it leaves:

- **An explicit-state model checker,** amoebius-maintained, consuming the same `Model` value the runtime
  interprets. This is what [§4](#4-single-source-correspondence) already describes. Its limit is the bound: it
  proves invariants over a finite scope, and says nothing beyond it.
- **A symbolic model checker,** answering that limit by discharging the same invariants to an SMT solver rather
  than enumerating states, so a proof can be unbounded in the dimensions that admit induction. It reads the
  same `Model`, so a symbolic result and an explicit-state result are results about one artifact.
- **A refinement-type checker for Haskell,** answering a different limit: the model is checked, and the *code*
  is only tied to it by the single-source correspondence. Refinement types put the obligations on the functions
  themselves, so a property holds of the implementation and not only of its abstraction.
- **A deterministic-scheduler simulator,** answering the concurrency limit, where the bug is an interleaving
  rather than a state ([`deterministic_simulation_doctrine.md`](./deterministic_simulation_doctrine.md)).

**The explicit-state layer is independent.** It must breadth-first search the shared `Model`/`interpret`
semantics without calling the primary explorer. Its verdict distinguishes safe completion, invariant or
deadlock counterexamples, and bound exhaustion. Haskell reference models and expected result classes constrain
it; generated traces or tables do not.

**The symbolic layer has a separate reading.** amoebius owns a total classifier, QF
linear-integer/boolean SMT-LIB translation, and full-conjunction base/step induction schema over `Model`; a
dynamically resolved absolute Z3 path supplies only formula decisions. Unsupported syntax and `unknown` stay
explicit. A reachable-safe but non-inductive Haskell model must demonstrate conservative incompleteness.

**The refinement layer is deliberately narrow.** One-equation `Integer` Haskell modules carry a closed source
annotation and are accepted by an injected absolute GHC. The owned checker parses the supported
arithmetic/boolean/conditional body and constructs preservation and postcondition-to-invariant implication
queries. Named invariant expressions are emitted beneath `.build/checkers/**`; independent semantic
expectations remain Haskell values.

This is a narrow source proof, not a whole-language theorem. The fixture annotation declares which named
model result the function implements, and the supported models deliberately share the state name `result`;
the checker does not infer an arbitrary state projection. It does not admit effects, recursion, higher-order
values, algebraic data, polymorphism, or nonlinear arithmetic, and it does not prove that a production call
site takes exactly the model action. Within that boundary, both the preservation and projected-invariant
implication formulas must be unsatisfiable; unsupported source, an unknown invariant, a satisfying
counterexample, or a non-decision is never promoted to proof.

---

## 7. Prototype validation

Prototype or prior-run evidence never validates this doctrine. The formal-model phase must qualify the real
Haskell kernel with independent Haskell reference models, semantic expectations, and production-source
mutants. At minimum, it must expose renderer meaning changes, explorer/checker disagreement, fairness
weakening, invariant deletion, frontier truncation, unsupported-theory refusal, and stale evidence.

Generated TLA+/CFG bytes, traces, fingerprints, and solver transcripts are observations beneath `.build/**`.
They cannot be committed or used as their own reference. A green finite model establishes only the declared
bound; an inductive result establishes only the supported theory; neither establishes effectful runtime
fidelity.

---

## 8. Trace validation: the earlier code↔model bridge

Single-source correspondence ([§4](#4-single-source-correspondence)) removes the hand-maintained mapping and
differentially checks the spec↔decision-core gap, but
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

This document remains the normative formal-model doctrine. Phase order, validation status, gate ownership,
and remaining work live only in
[DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md). This doctrine records no current validation
result. Hardware-free model, DSL, and generator checks must pass the human-approved promotion barrier before
any live runtime correspondence check begins.

---

## Related Documents
- [Engineering Doctrine Index](./README.md)
- [Gateway Migration Model](./gateway_migration_model_doctrine.md) — the one concrete `Model`: both branches of `GatewayMigration`, model-checked and simulated
- [Chaos & Failover Doctrine](./chaos_failover_doctrine.md) — the Extract→Model→Inject methodology and the proven/tested/assumed ledger this rendering serves
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md) — why the emitted `.tla`/`.cfg` are never committed
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md) — the Register-1 in-process explorer that mirrors TLC
- [Deterministic Simulation Doctrine](./deterministic_simulation_doctrine.md) — the Register-2.5 io-sim environment that runs the real daemon against a modeled world; the trace-validation home for the built code
- [Manifest Generation Doctrine](./manifest_generation_doctrine.md) — the sibling "render a typed value to its artifact" pattern
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
