# Test Derivation: what a spec may generate, and what must be authored against it

> **Purpose**: Analyse the boundary between generated coverage enumeration and independently authored Haskell
> expectations.
> **Read this if**: the coverage implied by a specification has to be derived without letting a gate become
> its own oracle.

This document supports the normative rule in
[`testing_doctrine.md` §9](./testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation). It
owns no validation status or independent obligation. The repository source boundary is owned by
[`repository_layout_doctrine.md` §1](./repository_layout_doctrine.md#1-classification-rule).

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: documents/engineering/README.md, documents/engineering/testing_doctrine.md
**Generated sections**: none

</details>

## Contents
- [1. Why this analysis exists](#1-why-this-analysis-exists)
- [2. Target boundary](#2-target-boundary)
- [3. Generate the enumeration; author the expectation](#3-generate-the-enumeration-author-the-expectation)
- [4. Required controls](#4-required-controls)
- [5. Chaos, failover, and gateway testing](#5-chaos-failover-and-gateway-testing)
- [6. Anti-patterns a gate must reject](#6-anti-patterns-a-gate-must-reject)
- [7. What this analysis does not own](#7-what-this-analysis-does-not-own)
- [8. Normative consequences](#8-normative-consequences)
- [Related Documents](#related-documents)

---

## 1. Why this analysis exists

A hand-maintained test inventory can lag the production declaration. Generating the entire test from that
declaration removes the lag but creates a tautology: the subject chooses both what is checked and what result
counts as correct.

The sound split is between two Haskell values:

- the production declaration generates the set of surfaces requiring coverage; and
- a separately authored and human-reviewed Haskell module states the expected relation over those surfaces.

Any Dhall, JSON, TSV, YAML, browser script, golden, expected diagnostic, or mutation body needed by a consumer
is a serialization of those Haskell values. It is generated beneath `.build/**` and never committed.

<a id="2-what-exists-today"></a>
## 2. Target boundary

This analysis records the required target, not current implementation state. The development plan and the
single legacy register own the observed tree and migration status.

The target test flow is:

```mermaid
flowchart LR
%% register: algebra
  src["production Haskell declaration"]:::intent -->|pure projection| enum["coverage enumeration"]:::intent
  exp["independent Haskell expectation"]:::intent -->|join by stable identity| join[["coverage obligation"]]:::intent
  enum --> join
  join -->|bound| run["qualified check"]:::intent
  join -->|missing expectation| refuse>"UNVERIFIED and phase refusal":::refuse
  run -->|when external encoding is needed| gen[".build materialization"]:::intent
  classDef intent fill:#e8eef7,stroke:#33587a,color:#12283f,stroke-width:1px
  classDef refuse fill:#f8d6d6,stroke:#b23636,color:#5c1414,stroke-width:2px
```
*Design intent. The subject generates only the enumeration. A distinct Haskell expectation decides meaning,
and every external encoding is disposable.*

<a id="3-generate-the-enumeration-author-the-expectation--adopted"></a>
## 3. Generate the enumeration; author the expectation

The boundary has four rules:

1. Production Haskell generates every coverage identity.
2. A separate Haskell module authored from the requirement supplies the expected result.
3. The join is exact in both directions: missing, extra, duplicate, or shadowed identities fail.
4. All serialized inputs and outputs are generated beneath `.build/**` and removed for a clean-room rerun.

Independent means more than a separate filename. The expectation must not import the production decision,
renderer, expected-output projection, or a shared constant that already contains the answer. Same-change
authorship has no independent provenance until a human reviewer explicitly accepts the oracle boundary.

An expectation can reuse public domain types and stable identifiers. It cannot reuse the function under test,
copy the generated output, or accept a checksum as semantic truth. Determinism and hashes are useful change
detectors, not correctness oracles.

<a id="4-recommended-additions"></a>
## 4. Required controls

### 4.1 A typed expectation surface on the test topology

Each test topology carries references to Haskell `Expectation` values. An expectation names:

- the claim and stable surface identity;
- the independent predicate or expected semantic value;
- the observer allowed to supply evidence;
- the strongest evidence register it can support; and
- the negative control that must make it fail.

The topology cannot invent an expectation from a generated plan. A missing expectation produces no verdict
seal and blocks promotion.

### 4.2 An illegal-state-catalog → fixture coverage check

The catalog taxonomy generates the set of required foreclosure cases. Each case joins to one Haskell witness:
a compile-fail module, a decode expectation, a pure refusal predicate, a boundary observation, or a live
zero-effect assertion. Non-Haskell negative inputs are generated from the Haskell witness under
`.build/test-corpora/**`.

A catalog row with no witness is an explicit uncovered obligation. A fixture path or catalog count is not a
witness, and an unchanged byte golden cannot establish a semantic foreclosure.

### 4.3 Browser testing: enumerate the surface, author the interaction

The checked UI plan generates the set of routes, controls, events, ports, focus targets, and public data
contracts requiring interaction. A separate Haskell module declares the driven interaction and expected DOM,
accessibility, focus, transport, effect, and denial observations.

Haskell materializes Playwright or another browser protocol beneath `.build/**` only after the hardware-free
DSL promotion barrier. Generated PureScript, JavaScript, browser scripts, and JSON observations are never
tracked. The browser cannot validate the Haskell/DSL generator that emitted its own program.

### 4.4 A bounded schedule type for fault injection

Fault schedules are Haskell values with finite bounds, declared targets, required observers, and teardown
obligations. A generator may enumerate schedules within that bound, but the safety/liveness expectation remains
independent Haskell. A schedule trace is run evidence, not an oracle.

<a id="45-application-authored-expectations-without-deployment-control"></a>
### 4.5 External application expectations without deployment control

An operator application may supply external `UiSource` or `InForceSpec` values, but repository expectations
remain Haskell. Application-level expectations name public behavior; deployment rules retain sole authority
over replicas, placement, chaos, provider resources, and teardown.

Importing an operator value into a gate does not authorize committing it. The gate stages it as external input
or renders an equivalent Haskell test value beneath `.build/**`.

### 4.6 Consolidating the mutation-operator vocabulary

Mutation operators are one closed Haskell vocabulary. Each operator records:

- the production-source locus it changes;
- the semantic dimension it attacks;
- an applied-change witness proving the subject changed;
- the exact check expected to turn red; and
- unaffected controls expected to remain green.

Materialized mutated files are generated beneath `.build/test-corpora/**`. A committed bad file, textual patch,
or table row is prohibited.

## 5. Chaos, failover, and gateway testing

The same split applies to temporal and live checks. Haskell declarations enumerate faults, transitions,
participants, and observer surfaces. Independent Haskell invariants state what must remain true. The run
produces traces and provider readback beneath `.build/runs/**`.

Live evidence adds correspondence; it does not repair a missing pure oracle. Hardware execution is prohibited
until the hardware-free DSL promotion barrier and every predecessor have human approval. A cluster or image
built from the DSL cannot be used to establish the earlier DSL's semantics.

<a id="6-defects-found-in-the-current-corpus"></a>
## 6. Anti-patterns a gate must reject

This analysis does not maintain a live defect ledger. The single
[`legacy_tracking_for_deletion.md`](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) file owns every
observed migration obligation and removes a row only after its closure predicate is met. Git history is the
archive.

The anti-patterns that must remain represented in gate sabotage suites are:

- a generated output copied into the expected side;
- a Python or shell runner returning the verdict to a Haskell wrapper;
- a no-op or constant-success production implementation;
- a missing or empty discovery set;
- a skipped mutant or a mutant that changed no production source;
- a same-change oracle without human independence review;
- a stale receipt or manually typed hash;
- a tracked non-Haskell fixture hidden behind an allowed path or renamed extension; and
- a live/container result used to promote an earlier hardware-free claim.

The analysis carries no resolved-defect subledger. Historical or disputed findings remain available in Git
history, while any active migration obligation belongs only in the single legacy register.

## 7. What this analysis does not own

This document does not own:

- phase order or validation status;
- the tracked-tree grammar;
- evidence strength or promotion policy;
- the illegal-state taxonomy;
- fault semantics or release topology; or
- the current divergence inventory.

The linked owner must be amended when the analysis discovers a real rule; this file must not become a second
normative home.

<a id="8-what-was-adopted"></a>
## 8. Normative consequences

The normative testing doctrine adopts:

- generated enumeration joined to independent Haskell expectation;
- exact bidirectional coverage joins;
- explicit uncovered obligations;
- Haskell-authored browser interactions and mutation operators;
- lazy `.build/**` serialization for every external language and fixture format; and
- human review before any expectation is treated as independent.

This adoption is a documentation decision only. It does not mark an implementation phase validated.

## Related Documents

- [Testing Doctrine](./testing_doctrine.md) — normative derivation and register rules
- [Repository Layout](./repository_layout_doctrine.md) — closed Haskell source boundary
- [Generated Artifacts](./generated_artifacts_doctrine.md) — lazy materialization and no-commit rule
- [Evidence Calculus](./evidence_calculus_doctrine.md) — claim-to-expectation strength
- [Chaos and Failover](./chaos_failover_doctrine.md) — temporal expectations and live observers
- [Development Plan](../../DEVELOPMENT_PLAN/README.md) — phase contracts and human-controlled status
- [Legacy Tracking](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) — sole active divergence register
