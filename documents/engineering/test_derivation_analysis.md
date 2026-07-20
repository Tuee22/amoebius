# Test Derivation: what a spec may generate, and what must be authored against it

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

> **Purpose**: Analyse the current amoebius testing corpus and recommend a derivation boundary — the spec generates the *enumeration* of surfaces requiring coverage; the operator authors the *expectations* asserted against them.

This document is the **analysis record** behind an adopted change, not an authoritative source. It owns no
concept: the derivation boundary it argued for is owned by
[testing_doctrine.md §9](./testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation), and
the typed surfaces by
[chaos_failover_doctrine.md §11.2](./chaos_failover_doctrine.md#112-the-typed-expectation-surface-expectation).
It is retained because the reasoning, the rejected alternatives, and the defect evidence are not recoverable
from the doctrine that resulted. Every claim here is design intent, never a proven amoebius result
([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline));
[§8](#8-what-was-adopted) records what landed where.

---

## 1. Why this analysis exists

Three questions about amoebius testing had no answer in the corpus as it stood, and one had an answer that
was correct but unstated. Each is stated below in the form it was found; [§8](#8-what-was-adopted) records
the resolution.

**A test topology cannot state what it expects.** The test-topology contract
([testing_doctrine.md §3](./testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down))
specifies spin-up, chaos injection, and mandatory teardown. It specifies no assertion, expectation, or
oracle. A topology's pass/fail signal is therefore drawn entirely from the leak-inventory diff, the
provision fold, and a golden ledger match — none of which is a claim about the behaviour under test. A
topology that stands up a cluster, kills the active worker, and tears down cleanly reports success without
having asserted that anything took over.

**Nothing derives test obligations from a spec.** `suggest-test`
([testing_doctrine.md §5](./testing_doctrine.md#5-suggest-test-detect-the-world-emit-a-representative-test-dhall))
is a capacity sizer: it consumes substrate classification, observed capacity, and credential authority, and
emits a topology sized to what the host can afford. It does not read the spec under test. The
`FaultTarget`-as-projection rule ([chaos_failover_doctrine.md §11](./chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose))
constrains a fault to resolve only against a declared component, which is a *restriction* on authorship,
not an *enumeration* of what authorship must cover. The illegal-state catalog is numbered and every
negative fixture carries a pinned tag, but no check joins the two.

**Testing by an application author is absent, and correctly so.** Chaos schedules live on the
deployment-rules surface
([app_vs_deployment_doctrine.md §3](./app_vs_deployment_doctrine.md#3-the-deployment-rules-surface--how-the-same-app-runs)),
which the app/deployment split assigns to the operator. An application author therefore has no surface on
which to write a test. For v1 this is sound — the extension set is closed and no third-party author exists —
but the corpus does not say so, and an unstated exclusion is indistinguishable from an oversight.

The fourth question — whether integration and browser tests should be generated from the spec or maintained
by hand — is answered in [§3](#3-generate-the-enumeration-author-the-expectation--adopted).

---

## 2. What exists today

Descriptive only. Each concept is owned by the document named; nothing here restates normative content.

| Concept | Owner |
|---|---|
| The four registers (pure, boundary, deterministic simulation 2.5, live test-`.dhall` topology) | [testing_doctrine.md §2](./testing_doctrine.md#2-three-registers-of-amoebius-testing) |
| Spin up → run → always tear down; the leak-free cycle | [testing_doctrine.md §3](./testing_doctrine.md#3-the-test-topology-contract-spin-up--run--always-tear-down) |
| The per-run proven/tested/assumed ledger and the UNVERIFIED rule | [testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) |
| Extract → Model → Inject; the three-layer correctness argument | [chaos_failover_doctrine.md §5](./chaos_failover_doctrine.md#5-three-layers-and-the-blindness-that-binds-them) |
| The concentration principle — one proof obligation, delegated consensus | [chaos_failover_doctrine.md §6](./chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives) |
| proven / tested / assumed strengths | [chaos_failover_doctrine.md §12](./chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed) |
| The `ChaosSchedule` / `FaultKind` types and the `FaultKind`→invariant map | [chaos_failover_doctrine.md §11](./chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose) |
| The simulated-substrate fault model | [deterministic_simulation_doctrine.md §3](./deterministic_simulation_doctrine.md#3-the-simulated-environment-and-its-fault-model) |
| The no-cluster spine and its honesty boundary | [conformance_harness_doctrine.md §5](./conformance_harness_doctrine.md#5-honesty-what-the-harness-does-and-does-not-establish) |
| Generated artifacts are never committed; the ledger carve-out | [generated_artifacts_doctrine.md §3](./generated_artifacts_doctrine.md#3-the-rule) |
| `PromotionGate` and per-environment evidence strength | [release_lifecycle_doctrine.md §4](./release_lifecycle_doctrine.md#4-promotiongate-promote-unverifiedprod-is-unrepresentable) |

Sequencing and status are owned by [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md).
No phase delivering any of the above has started.

---

## 3. Generate the enumeration; author the expectation — adopted

This analysis's central recommendation. It was **adopted** and is now owned by
[testing_doctrine.md §9](./testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation),
which states the rule, the enumeration/expectation table, and the coverage-obligation diagram. The argument
is not restated here.

In summary: a test artifact divides into an **enumeration** (which surfaces exist — generated from committed
source, never committed) and an **expectation** (what must hold — authored, committed, independent of the
code under test). Generating expectations is forbidden rather than merely unnecessary, because an oracle
rendered from the subject's own source is a tautology
([development_plan_standards.md §M](../../DEVELOPMENT_PLAN/development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)).
The join between the halves is a **coverage obligation**: an enumerated surface with no bound expectation
emits an UNVERIFIED ledger row rather than passing silently.

---

## 4. Recommended additions

Each subsection states the defect, the alternative that fails, the recommended rule, and what the rule gives
up. Ordered by value; [§4.2](#42-an-illegal-state-catalog--fixture-coverage-check) is the cheapest and is
buildable against the current phase.

### 4.1 A typed expectation surface on the test topology

**Defect.** A test topology asserts nothing about behaviour ([§1](#1-why-this-analysis-exists)).

**Why free-form assertions fail.** Admitting an arbitrary predicate on the test surface reintroduces exactly
what the DSL forecloses elsewhere: a value that type-checks while naming a component, an invariant, or a
state the enclosing spec does not declare. It also makes the ledger's applicable-move set unverifiable,
because an emitter that declares its own obligations can declare none.

**The rule.** The `FaultKind`→invariant map published by
[chaos_failover_doctrine.md §11](./chaos_failover_doctrine.md#11-move-iii--inject-break-the-running-thing-on-purpose)
is already a total function from an injected fault to the invariant its drill must not break. That map is
the generator. For each `FaultInjection` in a schedule, the required expectation set is derived; the operator
authors a witness per derived invariant; a derived invariant with no authored witness is UNVERIFIED rather
than absent. `Expectation` is a projection over that map, bounded exactly as `FaultTarget` is a projection
over declared components.

**What it forecloses.** Asserting an invariant no injected fault stresses, and asserting anything about a
component the spec does not declare. Both are deliberate: an expectation unreachable from the schedule is
not evidence the run produced.

### 4.2 An illegal-state-catalog → fixture coverage check

**Defect.** Negative fixtures are hand-enumerated per phase. Nothing detects a catalog entry with no
witness.

**Why per-phase enumeration fails.** It places the completeness obligation on the author of each phase, at
the moment the phase is written, against a catalog that grows afterwards. An entry added later acquires no
fixture and no record that it lacks one.

**The rule.** Derive the required-fixture list from the catalog; the check is red when an entry has no
committed witness, and the ledger carries one UNVERIFIED row per uncovered entry.

**Cost and timing — corrected.** An earlier revision of this document asserted the check was "buildable
now". That was wrong, and the correction matters because the overclaim is the kind
[documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)
exists to forbid. The join has neither a populated right-hand side nor a key:

- **No fixture files exist.** Every `illegal_*.dhall` path in the corpus is a planned target path, so the
  join's right side is empty.
- **No entry→fixture reference exists.** No catalog entry names a fixture, an owning phase, or an error tag.
  Error tags live only in phase documents and are never structurally bound to an entry, so the
  `(entry, expected-tag)` pair is absent from the catalog by construction.
- **No ownership fields exist.** Entries carry `Validation-locus:` only. `Delivery-owner:` and
  `Case-family:` — the fields that distinguish a *missing* fixture from a *correctly deferred* one — are on
  no entry. Without them every `provision-seal` entry reads as a violation when it is in fact deferred.
- **No subcase identifiers exist**, yet at least two entries each owe two fixtures at two distinct loci, so
  the join cannot be expressed as one row per entry.

The recommendation therefore splits. The **catalog-side integrity** half — every entry carries a locus,
entry numbering is contiguous, index anchors resolve, every entry has a coverage-matrix row — is buildable
now over Markdown alone and lands in Phase 0. The **fixture-coverage join** is the consumer side of the
`locus_registry.tsv` that `phase_06_illegal_state_corpus.md` Sprint 6.1 already schedules, and lands there.
Building the consumer first would hardcode the ownership rules the registry is meant to own, which that
phase explicitly warns against.

**What it forecloses.** Adding a catalog entry without either a fixture or an explicit UNVERIFIED record.

### 4.3 Browser testing: enumerate the surface, author the interaction

**Defect.** Playwright coverage is specified as prose naming one interaction per phase. Nothing relates the
set of driven interactions to the set of workflow states the contract admits.

**Why generating the interactions fails.** The generated PureScript contract and the SPA consuming it derive
from one source; a browser test generated from that source asserts self-agreement. The coupling that
generation *can* establish is already established, by the committed field-rename mutant that must turn the
run red.

**The rule.** Enumerate from the composed workflow ADT every constructor carrying a UI affordance. Each
enumerated constructor is bound to an authored interaction or emits an UNVERIFIED row. Interactions and
their assertions remain authored.

**Honest limit.** The `purescript-bridge` boundary carries types only — no routes, methods, or
request/response pairing — so enumeration reaches constructors, not endpoints. Endpoint-level obligation
generation would require an API description the corpus does not currently specify, and is not recommended
here.

**What it forecloses.** A browser suite whose coverage is asserted in prose rather than computed.

### 4.4 A bounded schedule type for fault injection

**Defect.** `FaultInjection` elides timing. Doctrine examples describe periodic injection, and the type
carries no field able to express it.

**The rule.** Add a bounded schedule, constrained by the determinism rule that forbids asserting on
wall-clock: logical or simulated time under Register 2.5, bounded relative offsets under Register 3. Every
bound is finite and declared, per the bound-everything rule.

**What it forecloses.** An unbounded or wall-clock-relative chaos schedule, which is not replayable and
therefore not admissible as Register-2.5 evidence.

### 4.5 Recording app-author testing as a deliberate v1 exclusion

**Defect.** The absence of an application-author testing surface is structural and correct, and is
unrecorded. An unstated exclusion reads as an oversight and invites a later contributor to close it by
leaking a deployment-rules concern into application logic — the modelling error the concentration principle
names as a diagnostic.

**The rule.** State the exclusion, its basis (the extension set is closed for v1, so no third-party
application author exists), and what a later surface would require: an application-level expectation surface
that composes with, but cannot author, deployment rules.

**What it forecloses.** Nothing in v1. It removes the ambiguity, not a capability.

### 4.6 Consolidating the mutation-operator vocabulary

**Defect.** The mutation-operator set — guard negation and weakening, effect swap, dropped effect,
quantifier flip, fairness drop, invariant-clause deletion, union-arm addition, field rename — is stable
across phases and re-enumerated by hand in each.

**Why a mutation engine fails.** Automatic mutant generation produces a large population of mutants that are
equivalent, unreachable, or uninteresting, and the triage cost exceeds the cost of the committed per-gate
mutants the phases actually require.

**The rule.** One committed operator catalog, plus a per-gate check that each gate names which operators
apply and commits at least one mutant per applicable operator.

**What it forecloses.** A gate silently applying a narrower operator set than its neighbours.

---

## 5. Chaos, failover, and gateway testing

The recommendation for this area is that it needs almost nothing, and the reason is worth recording because
the natural instinct runs the other way.

The chaos, failover, and gateway material is the strongest part of the corpus. The concentration principle
delegates intra-cluster consensus to the substrates that already prove it and concentrates a single
obligation at the asynchronous cross-cluster gateway migration. Each `FaultKind` is bound to the invariant
its drill stresses. The drill evidence is held by a write journal maintained outside the system under test.
Numeric budgets are hash-pinned so a budget edited after measurement fails its check. Liveness properties
carry a fairness-sensitivity check that must turn red when fairness is removed, and model checks carry
antecedent-reachability and no-dead-action conditions so a green result cannot be vacuous. That combination
exceeds what most deployed systems attempt.

Two changes are recommended, both already stated elsewhere in this document: the typed expectation surface
of [§4.1](#41-a-typed-expectation-surface-on-the-test-topology), and resolving the `independent` conflict
recorded in [§5](#6-defects-found-in-the-current-corpus).

Broader chaos coverage is **not** recommended. Per
[chaos_failover_doctrine.md §6](./chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives),
a proof obligation appearing outside that one boundary indicates a modelling error — typically a
deployment-rules concern that has leaked into application logic, or a re-proof of what the delegated
substrates already prove. Recommending additional chaos surface would therefore be recommending the defect
the principle exists to detect, and a coverage matrix showing chaos drills spread across the forest would be
evidence of a problem rather than of thoroughness.

---

## 6. Defects found in the current corpus

Four inconsistencies were found while reading. All four have since been **resolved**; each is retained here
with its evidence, the decision taken, and where the fix landed, because a defect record that vanishes on
repair leaves no trace of why the corpus now reads as it does.

### 6.1 Prod promotion was unsatisfiable as written — resolved

[release_lifecycle_doctrine.md §4](./release_lifecycle_doctrine.md#4-promotiongate-promote-unverifiedprod-is-unrepresentable)
required that `Prod` reach the **Runtime/chaos layer proven**, and restated the requirement when fencing the
Tier-1-only ledger. [testing_doctrine.md §4](./testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
requires the Runtime/chaos layer ***tested***, and the strength table at
[chaos_failover_doctrine.md §12](./chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed)
classifies live injection as **tested (the faults chosen), never proven**. Read literally, prod required a
strength no applicable move can emit, so no `Release` could ever advance to `Prod`.

**Resolved:** the testing doctrine is authoritative. `release_lifecycle_doctrine.md` §4 now requires
*tested* and states why that is the layer's highest achievable strength rather than a concession, so the
wording cannot drift back. `DEVELOPMENT_PLAN/phase_26_release_lifecycle.md` propagated the same claim in
four places; a first pass corrected only one (`:194`), and an audit found the other three surviving in the
Sprint 26.3 validation, deliverable, and the committed `evidence_strength.txt` oracle it produces. All four
now read *tested*. The lesson is recorded in the verification discipline: an absence-check whose pattern
could not span a newline reported the defect closed when three instances remained.

### 6.2 `independent` was defined two incompatible ways — resolved

[gateway_migration_model_doctrine.md §5](./gateway_migration_model_doctrine.md#5-one-and-done-plus-a-per-inforcespec-structural-fit)
defined independence on the label projection and **not** on the vertices, admitting a single survivor
cluster as the standby of two edges and naming that the shared-survivor stress case.
`DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md` defined `independent` as graph-independence **and**
resource-independence, had the fold reject cluster-reuse across records, and claimed the two readings were
thereby reconciled. They were not: the phase-3 fold would reject the doctrine's own stress case.

**Resolved: the strict reading holds.** The fold rejects cluster-reuse-across-records. The rationale is that
admitting a shared survivor would let the decoder accept specs the scope-2 proof does not cover on the
strength of the shared-resource premise, which is *assumed* rather than proven; the fold admits only what
the proof reaches.

The honest limit narrows but does not vanish, and
[§6](./gateway_migration_model_doctrine.md#6-modelling-bounds-and-honesty) now says so: rejecting cluster
reuse removes the one shared-resource class the decoder can see, while the classes it cannot see — one
route53 hosted zone and its write rate-limit, one Vault, one commit log — remain shared across vertex-disjoint
instances, so the shared-resource independence premise survives in narrowed form. The excluded
shared-survivor topology is recorded as a named deferred obligation gated on the decomposition lemma, and the
over-scope stress run still models a shared survivor in, so the stress model retains the ability to detect a
cutoff violation the fold now forecloses.

### 6.3 `Staging` had no evidence mapping — resolved

[release_lifecycle_doctrine.md §3](./release_lifecycle_doctrine.md#3-environment-and-the-etag-cas-promotion-pointer)
declares a closed three-arm union, `Dev | Staging | Prod`, with the comment that no fourth, unnamed
environment exists, while the required-evidence-strength mapping in
[§4](./release_lifecycle_doctrine.md#4-promotiongate-promote-unverifiedprod-is-unrepresentable) specified
`Dev` and `Prod` only — a partial function over a type declared total.

**Resolved:** the mapping now specifies all three arms, with `Staging` requiring the Protocol layer
*proven-for-the-model* (the design-time TLC result, no live substrate) between `Dev`'s Decision layer and
`Prod`'s Runtime layer.

### 6.4 Appendix C misattribution — resolved

`chaos_failover_doctrine.md` Appendix C stated that the concrete spec for the active-active OLTP worked
example is owned by [gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md), which
models the gateway migration only, while the same appendix's own summary table marks the row *illustrative
only — no owning model or phase*.

**Resolved:** editorial. The sentence now matches the table and points at
[§17](./chaos_failover_doctrine.md#17-the-boundary-and-its-classifier) for the method it illustrates.

### 6.5 One reported defect that was not real

An earlier reading reported two stale anchors in the illegal-state index (§3.27 and §3.30), on the grounds
that both headings had been retitled without their inbound anchors being updated. **That report was a false
positive.** The corpus uses explicit `<a id="old-slug">` tags to keep inbound links alive across a heading
rename, and both entries — along with nine other retitled headings — carry one. A whole-repo check that
honours explicit HTML anchors resolves all 6,300-odd internal links with zero failures. The pattern is
deliberate and is recorded here so it is not "fixed" away by a later reader.

---

## 7. What this analysis does not own

| Concern | Owned by |
|---|---|
| The registers, the teardown contract, the ledger artifact, `suggest-test`, flagged credentials | [testing_doctrine.md](./testing_doctrine.md) |
| Extract → Model → Inject, proven/tested/assumed, the `FaultKind`→invariant map, the concentration principle | [chaos_failover_doctrine.md](./chaos_failover_doctrine.md) |
| The one formal obligation, the structural-fit fold, the scope-2 cutoff | [gateway_migration_model_doctrine.md](./gateway_migration_model_doctrine.md) |
| Which artifacts are generated and the never-commit rule | [generated_artifacts_doctrine.md](./generated_artifacts_doctrine.md) |
| `PromotionGate`, `Environment`, per-environment evidence strength | [release_lifecycle_doctrine.md](./release_lifecycle_doctrine.md) |
| The app/deployment dividing line | [app_vs_deployment_doctrine.md](./app_vs_deployment_doctrine.md) |
| The simulated-substrate fault model and the Register-2.5 fidelity premise | [deterministic_simulation_doctrine.md](./deterministic_simulation_doctrine.md) |
| Making an illegal test cluster unrepresentable | [dsl_doctrine.md](./dsl_doctrine.md), [../illegal_state/illegal_state_catalog.md](../illegal_state/illegal_state_catalog.md) |
| Phase order, status, gates, the toolchain pin | [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md) |

---

## 8. What was adopted

This analysis has been **adopted**. Its thesis is now normative doctrine, its six recommendations are
placed, and all four defects are repaired. What follows records where each part landed, so a reader arriving
at this document can find the owner rather than treat it as a live proposal.

| This document's section | Landed in |
|---|---|
| [§3](#3-generate-the-enumeration-author-the-expectation--adopted) the derivation boundary and the coverage obligation | [testing_doctrine.md §9](./testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) |
| [§4.1](#41-a-typed-expectation-surface-on-the-test-topology) the typed expectation surface | [chaos_failover_doctrine.md §11.2](./chaos_failover_doctrine.md#112-the-typed-expectation-surface-expectation) |
| [§4.4](#44-a-bounded-schedule-type-for-fault-injection) the bounded fault schedule | [chaos_failover_doctrine.md §11.2](./chaos_failover_doctrine.md#112-the-typed-expectation-surface-expectation) (`FaultSchedule`) |
| [§4.5](#45-recording-app-author-testing-as-a-deliberate-v1-exclusion) the v1 exclusion | [app_vs_deployment_doctrine.md §10](./app_vs_deployment_doctrine.md#10-application-author-testing-is-a-deliberate-v1-exclusion) |
| [§4.2](#42-an-illegal-state-catalog--fixture-coverage-check) catalog integrity (catalog-side half) | Phase 0, as a documentation-lint check |
| [§4.2](#42-an-illegal-state-catalog--fixture-coverage-check) the fixture-coverage join | Phase 6, as a consumer of `locus_registry.tsv` |
| [§6](#6-defects-found-in-the-current-corpus) the four defects | repaired in their owning documents; see each subsection |

Two recommendations are **not** adopted and are recorded as open:
[§4.3](#43-browser-testing-enumerate-the-surface-author-the-interaction) (enumerating driven interactions
from the contract) has no owning phase, and
[§4.6](#46-consolidating-the-mutation-operator-vocabulary) (one mutation-operator catalog) remains
re-enumerated per phase. Neither blocks anything; both are noted so their absence is a recorded decision.

Because this document is now referenced by the doctrine it fed, the one-sided-link exception its earlier
revision claimed no longer applies, and its `Referenced by` field is reconciled from the true link graph like
any other document.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [Testing Doctrine](./testing_doctrine.md)
- [Chaos / Failover Doctrine](./chaos_failover_doctrine.md)
- [Generated Artifacts Doctrine](./generated_artifacts_doctrine.md)
- [Application Logic vs Deployment Rules](./app_vs_deployment_doctrine.md)
- [Release Lifecycle Doctrine](./release_lifecycle_doctrine.md)
- [Gateway Migration Model Doctrine](./gateway_migration_model_doctrine.md)
- [Deterministic Simulation Doctrine](./deterministic_simulation_doctrine.md)
- [Conformance Harness Doctrine](./conformance_harness_doctrine.md)
- [Documentation Standards](../documentation_standards.md)
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
