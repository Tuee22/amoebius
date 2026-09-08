# The Formal Model: one reifiable value, two renderings

> **Purpose**: Define the shared Haskell model, its executable and TLA+ readings, and the evidence required for
> each formal claim about the language or its implementation.
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
**Referenced by**: DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_14_refinement_checker.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/engineering/README.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/chaos_failover_second_axis.md, documents/engineering/chaos_failover_worked_examples.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/preflight_validation_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/tla_modelling_assumptions.md, documents/glossary.md, documents/reading_order.md
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

## 1. Why this doctrine exists

**The problem.** A model can satisfy its invariants while production implements a different transition
relation. Shared invariant names, matching fixture counts, and a correspondence table do not detect that gap.

**Why the obvious alternative fails.** Maintaining model and code separately, then testing a few matching
examples, leaves their general correspondence assumed. Generating TLA+ from Haskell removes a foreign source
copy but does not connect an unrelated Haskell implementation to the model.

**The rule.** The target protocol is authored as one reifiable Haskell `Model`. Its decision interpreter and
TLA+ emitter must consume that same value. Production call sites must consume those interpreted decisions or
carry an explicit, independently checked refinement relation to them.

**What it forecloses.** A protocol copy cannot inherit the model's proof through matching labels or traces.
Sharing a value reduces one source of drift. Equivalence of its readings, production consumption, and
environmental fidelity remain separate obligations.

## 2. The `Model` is data

The executable constructor inventory belongs to
[`Model.hs`](../../src/Amoebius/Formal/Model.hs). This document explains its semantics and does not maintain a
second schema. Markdown is never a model generator or an acceptance input.

A model declares constants, state variables, initial assignments, guarded parameterized actions, safety
invariants, fairness assumptions, temporal properties, and explicit exploration boundaries. Its expression
fragment contains booleans, integer arithmetic and comparisons, finite sets, finite quantifiers, functions,
and conditionals.

Every expression is interpreted over the pre-state. An action assigns its listed successor variables
simultaneously; variables omitted from its effects retain their values. Parameter bindings range over
declared finite sets. Unknown names, ill-sorted expressions, invalid assignments, and malformed fairness
references require exact construction or interpretation refusals.

The Haskell constructor set does not itself prove those semantic conditions. A unityped expression can
represent an ill-sorted formula. The well-formedness checker and its independent negative corpus must enforce
the admissible fragment; the result must not be described as a GADT guarantee.

Integer-valued variables are not automatically finite because their representation is Haskell `Integer`.
A finite model requires an explicit bound or finite reachable-state argument. Symbolic reasoning over integers
requires the separate decision authority in [§6.1](#61-the-proof-stack-is-amoebius-owned).

Safety predicates are evaluated at reachable states. Temporal properties describe behaviour over paths.
Weak and strong fairness state assumptions about enabled actions; they are neither safety predicates nor
facts established about a production scheduler by the model declaration.

The owning gate must discover the complete constructor inventory and test each meaning independently.
Required constructor combinations also need coverage. A count of constructors cannot establish the
semantics of quantifier nesting, simultaneous updates, or fairness composition.

## 3. Two total renderings

The target readings are the decision interpreter in
[`Interpret.hs`](../../src/Amoebius/Formal/Interpret.hs) and the TLA+ emitter in
[`EmitTLA.hs`](../../src/Amoebius/Formal/EmitTLA.hs). They consume the same model identity.

The decision interpreter computes the enabled successor for a model, event, and state. Disabled or unknown
events have a declared refusal outcome. Ill-formed states and expressions must not become successful
identity transitions. The enabled-event enumeration must agree with the interpreter under every declared
parameter binding.

The emitter derives `Init`, `Next`, frame conditions, invariants, temporal properties, fairness, and checker
configuration from that model. Generated TLA+ and CFG files remain run-scoped artifacts. A complete proof
run binds their actual bytes and the executable checker that consumed them.

Totality is an obligation, not a consequence of a function signature or exhaustive pattern matching alone.
Bottoms, nontermination, incomplete validation, and resource exhaustion require their own treatment.
Compile-time rejection witnesses establish only the named type boundary under the recorded compiler.

**The problem.** Requiring the kernel to depend on a later checker can create a circular phase prerequisite.

**Why the obvious alternative fails.** Deferring every renderer check until a concrete model runs leaves the
kernel's semantics unspecified. Making the whole later proof stack a prerequisite prevents the finite kernel
from being established independently.

**The rule.** [Phase 11](../../DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md) owns the finite kernel and
independent semantic expectations. Later checker and concrete-model phases add executable checker
correspondence and protocol proofs. Each phase states the exact strength and scope it owns.

**What it forecloses.** A structural renderer check cannot be labelled an executed TLC proof. A later TLC
result cannot retroactively qualify a missing earlier kernel obligation.

## 4. Single-source correspondence

Sharing a `Model` identifies the input to two readings. It does not prove their semantic equivalence or that
production uses either reading. The complete claim requires both connections.

The kernel's independent reference semantics must check interpretation, enabled actions, invariant meaning,
and emitted semantics. It cannot derive expected results from the interpreter, emitter, explorer, or their
shared decision helpers. Import separation alone cannot establish that independence.

Consumer phases compare freshly generated checker inputs with actual explorer results. Safety differentials
compare complete canonical reachable-state sets and exact verdicts, not merely equal state counts. A generated
state fingerprint is an observation; an independent interpretation gives that comparison meaning.

TLC state constraints exclude states failing the constraint. A model expansion limit instead retains a reached
boundary state for invariant checking and prevents further expansion. The readings must preserve that
distinction. Bound exhaustion is incomplete exploration and cannot become a safe-completion result.

Random small-model generation requires declared constructor and interaction coverage plus shrinkable
counterexamples. Its result is sampled differential evidence. Exhausting a finite declared model gives a
bounded result. Neither establishes a meta-theorem over every expressible model.

Production correspondence additionally binds the actual decision entry point and its consumers. For each
claimed protocol, the gate must either observe the shared interpreter's typed output reaching production or
check an explicit implementation-to-model relation. Comparing a model inventory with matching assertion names
does not check a transition relation.

The complete DSL obligation includes decoder, legality, capacity and capability folds, provision, renderer,
planner, and generated-language consumers. Their ownership follows the
[development plan](../../DEVELOPMENT_PLAN/README.md). Moving one obligation to its artifact-owning phase must
preserve its identity and its inclusion in the hardware-free barrier.

### 4.1 The reference model and its semantic oracle

**The problem.** An interpreter and renderer can agree on a weakened invariant, and a renderer can preserve
all labels while changing fairness or temporal meaning.

**Why the obvious alternative fails.** Copying generated bytes into a golden freezes layout rather than
meaning. Counting states or invariants cannot distinguish different state sets or predicates with the same
names.

**The rule.** The kernel has independently authored Haskell expectations for a reference model. They cover
initial assignments, guards, simultaneous effects, frame conditions, quantifier meaning, invariant truth
tables, constraints, expansion limits, fairness strength, temporal operators, and deadlock configuration.

The reference model qualifies the model machinery. It cannot stand in for a production protocol.
Concrete-model gates need independent protocol expectations and actual production correspondence in addition
to the reference model.

Applied production mutations must change each assigned semantic boundary. Guard changes, invariant weakening,
dropped frame conditions, fairness swaps, and truncated exploration must reach their named independent
rejection. Unrelated compile errors, arbitrary exceptions, and missing output do not count as semantic
counterexamples.

The concrete-model owners are
[Phase 17](../../DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md) and
[Phase 18](../../DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md).
[Phase 19](../../DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md) owns correspondence under modeled
concurrency. Their plans define the executable case inventories; this doctrine records no passing counts.

**What it forecloses.** A model that initializes a fixture count and asserts that same count does not validate
the production calculation. A test comparing invariant names with test labels does not prove refinement.
A valid kernel reference model does not prove every DSL composition correct.

## 5. The `.tla`/`.cfg` are generated, never committed

TLA+ modules, checker configurations, SMT-LIB, traces, and serialized proof observations are generated from
Haskell beneath `.build/**`. Independently authored semantic expectations remain Haskell source.

Regeneration prevents a tracked foreign-language copy from becoming a second authority. It does not prove
that the generated bytes are valid, that the intended checker consumed them, or that they match production.
The owning gate must establish those facts separately.

Changing whitespace need not change semantic expectations. Changing an invariant, accepted theory,
correspondence relation, or required coverage is a contract change under the
[phase-amendment rule](../../DEVELOPMENT_PLAN/development_plan_phase_model.md#n-reopening-and-amending-a-phase).
A new output cannot authorize its own expected-result rewrite.

## 6. What a green model-check proves, and what it does not

Claims use the [documentation honesty vocabulary](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline).
Their scope must accompany the result.

| Evidence | Permitted claim | Required limit |
|---|---|---|
| Type-check and exact compile-negative pairs | Named static boundary under the recorded compiler | Not totality or correctness of every program |
| Complete finite-state exploration | Invariants hold for the declared model at its bound | No bound exhaustion; no unproved generalization |
| Qualified symbolic induction | Declared obligations hold in the supported theory | Solver, translation, hypotheses, and source identity bound |
| Qualified source refinement | Supported implementation fragment satisfies its stated relation | Actual compiled body and correspondence checked |
| Generated property cases | Tested on the sampled domain | Coverage and seed recorded; no universal proof |
| Differential model/code cases | Tested correspondence for those cases | Not general model-to-code refinement |
| Externally observed fake boundary | Actual request/effect selection under the fake model | Real-provider fidelity remains assumed |
| Live observed execution | Tested effects on the named substrate and run | No guarantee about every future execution |

A green TLC run establishes safety only when exploration completed and the relevant invariants were checked.
A liveness result additionally depends on the exact temporal formula and named fairness assumptions.
The in-process safety explorer does not independently establish liveness.

Liveness runs must preserve enabledness at the declared boundary. State constraints can truncate that
behaviour and change the claim. The preferred obligation finitizes through constants and finite variable
domains without a state constraint. Any admitted alternative needs an explicit argument and cannot hide
constraint truncation as ordinary finite-state proof.

Fairness-sensitive properties require paired runs showing the expected change when fairness is removed.
Invariant weakening requires independently invalid states even when the clean model remains green.
A parser failure, timeout, solver crash, or unrelated nonzero exit is not the expected counterexample.

A finite bound supports a general claim only through a checked cutoff or inductive reduction. The
[gateway-model doctrine](./gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty) owns that
protocol's reduction obligations. A missing reduction remains missing evidence.

Model checking cannot decide whether the authored requirements capture the intended product.
Renderer fidelity, production call-site binding, observation authenticity, and environmental assumptions
remain explicit. Evidence from one shared model must not be counted as several independent protocol proofs.

Model checks run at development and gate time for the bound source and contract. They are repeated after
relevant changes; an earlier result is not permanent. Per-spec structural admission checks must enforce the
envelope assumed by the model without pretending to rerun its exhaustive proof.

### 6.1 The proof stack is amoebius-owned

amoebius owns the Haskell model, translations, decision classification, refinement relation, and qualification.
Ownership of source does not remove the trust placed in external compilers, solvers, or their runtime.
Their acquisition and isolation follow
[validation_frame_doctrine.md](./validation_frame_doctrine.md#4-generated-output-and-cleanroom-execution).

The explicit-state checker independently explores the model without invoking the primary explorer's search
algorithm. It distinguishes completed safety, invariant counterexample, deadlock, malformed input, and
exhausted bound. Independently replayable counterexamples must identify the actual transitions.

**The problem.** A finite integer sampler can return no witness even when an SMT formula is satisfiable
outside its sampled values. Treating that result as `unsat` can turn a false obligation into a proof.

**Why the obvious alternative fails.** Sampling a fixed interval, input constants, and adjacent values has no
general completeness theorem for linear integer constraints. A fake process returning solver-shaped text
does not supply that theorem.

**The rule.** [Phase 13](../../DEVELOPMENT_PLAN/phase_13_symbolic_checker.md) must bind an authenticated real
decision procedure or an independently checked complete procedure for the exact admitted theory. Base and
step induction use the full invariant conjunction. Unsupported theory, timeout, unknown, and malformed
results remain distinct refusals or inconclusive outcomes.

A fake solver may test transport, parsing, and classification. Its finite search cannot authorize an
unbounded proof. Qualification includes satisfiable formulas whose witnesses escape a naive sampled domain,
false unsatisfiability responses, incomplete models, and replayed solver output. Exact Haskell cases belong
to the phase oracle.

[Phase 14](../../DEVELOPMENT_PLAN/phase_14_refinement_checker.md) additionally binds the actual GHC-accepted
source body to the parsed refinement fragment. GHC acceptance alone does not establish the annotation.
Preservation and postcondition-to-model implication must be discharged by the admitted decision authority.

A supported source fragment needs a complete parser and exact refusal for syntax outside it. Ignored
equations, comments masquerading as annotations, unsupported bindings, or unbound variables cannot silently
change the checked function. The production function consumed by callers must match the source being proved.

**What it forecloses.** A finite fake's `unsat`, a clean compile, or a pair of agreeing annotation strings
cannot establish source refinement. A checked narrow fragment does not prove recursion, higher-order code,
effects, or the entire language. Those exclusions must remain attached to each result.

## 7. Prototype validation

A prototype or earlier run can guide implementation but cannot satisfy a current gate. The owning phase
must qualify its exact subject and independent oracle against the current contract and source snapshot.

The required adversaries include false solver decisions, weakened invariants, ignored production outputs,
disconnected model/code mappings, unfair liveness, truncated exploration, wrong-reason failure, and replayed
evidence. Haskell declarations own their cases, expected reasons, and production mutation loci.

The qualification boundary is defined by
[testing_spoof_resistance.md](./testing_spoof_resistance.md#123-harness-qualification).
Adding a new case without observing its assigned production change does not discharge that obligation.

## 8. Trace validation: the earlier code↔model bridge

Trace validation checks actual transitions against the model's transition relation. It must bind observed
pre-state, action, successor state, and the explicit abstraction from production state into model state.
Shared names or a daemon-authored success label cannot replace those values.

A simulated environment can supply deterministic schedules for real production code.
The [simulation doctrine](./deterministic_simulation_doctrine.md) owns that boundary.
A live observer can later capture the corresponding real effects. In either case, the trace collector and
validator must remain independent of the subject's assertion that the trace was legal.

The checker must reject reordered, omitted, duplicated, foreign, or impossible transitions at their exact
loci. A trace accepted by the model establishes only that the observed transitions satisfy the checked
relation. It does not establish that every possible execution does so.

The target shared-model design can reduce the required abstraction mapping. Its presence must be established
at the production call site; it cannot be inferred from an import, a module name, or a matching model digest.

## 9. Planning ownership

This doctrine owns the target model and evidence distinctions. The
[development-plan tracker](../../DEVELOPMENT_PLAN/README.md) owns the validation reset, dated implementation
audit, status, and remaining work. This document records no current formal-validation result.

The complete DSL target remains the connected language and its required compositions. Each phase discharges
only its declared obligation. Bounded proof and sampled checks remain useful evidence without becoming an
unbounded whole-language theorem through a phase-status change.

The finite bootstrap trust root is not required to prove the entire checker stack.
The [hardware-free barrier](./conformance_harness_doctrine.md#5-the-pre-hardware-gate-barrier) owns complete
language integration before live validation opens.

## Related Documents

- [Engineering doctrine index](./README.md)
- [Gateway migration model](./gateway_migration_model_doctrine.md)
- [Chaos and failover](./chaos_failover_doctrine.md)
- [Generated artifacts](./generated_artifacts_doctrine.md)
- [No-cluster conformance harness](./conformance_harness_doctrine.md)
- [Deterministic simulation](./deterministic_simulation_doctrine.md)
- [Manifest generation](./manifest_generation_doctrine.md)
- [Documentation standards](../documentation_standards.md)
- [Development plan](../../DEVELOPMENT_PLAN/README.md)
