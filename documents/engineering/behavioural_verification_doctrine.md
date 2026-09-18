# Behavioural Verification

> **Purpose**: Fix what counts as verifying a claim, so a gate cannot be satisfied by how a subject presents itself.
> **Read this if**: a check is about to assert that source text contains a token, that a process printed a label, or that an observation reads as a sentence.

This document owns the distinction between evidence about *behaviour* and evidence about *presentation*, and the two corollaries that keep it enforceable: the layer that decides a verdict is itself a subject, and an invariant has one enforcing site. It does not own gate acceptance, which belongs to [`development_plan_gate_integrity.md` §M](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub), nor the catalogue of product illegal states, which belongs to [`illegal_state_catalog.md`](../illegal_state/illegal_state_catalog.md). A reader must already know the three foreclosure layers from [`illegal_state_techniques.md` §6](../illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: 
**Generated sections**: none

</details>

## Contents

- [1. Scope](#1-scope)
- [2. Rule A — a gate verifies behaviour, not presentation](#2-rule-a--a-gate-verifies-behaviour-not-presentation)
- [3. Rule B — the verdict layer is a subject](#3-rule-b--the-verdict-layer-is-a-subject)
- [4. Rule C — one invariant, one enforcing site](#4-rule-c--one-invariant-one-enforcing-site)
- [5. Every rule names its enforcement tier](#5-every-rule-names-its-enforcement-tier)
- [6. What this doctrine does not claim](#6-what-this-doctrine-does-not-claim)
- [Related Documents](#related-documents)

## 1. Scope

These rules bind all authored source, including the validation kernel. A mechanism that judges a claim is a subject of this doctrine while it is judging. The catalogue of product illegal states scopes itself to the product; that boundary is why an evidence value the domain forbids was representable for as long as it was.

## 2. Rule A — a gate verifies behaviour, not presentation

An assertion that production source **contains a token**, that a child process **printed a label**, or that an observation **reads as a sentence** is evidence about presentation. It is admissible as context and never as the row that establishes a claim.

Every phase's central claim is established by an independently authored expected **value** compared against a produced **value**. Where the subject renders an artefact, the oracle authors the artefact. Where the subject computes, the oracle computes the answer another way.

The failure this forecloses is already registered as [`LTD-VAL-002`](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md#3-validation-integrity-violations): fixed contract tables and compile-selected mutant labels preserve presentation while failing to establish the specified semantics. A subject whose claim is a rendered artefact can satisfy a token match while emitting an artefact its consumer would reject.

## 3. Rule B — the verdict layer is a subject

Whatever adjudicates a claim carries its own oracle and its own mutants. A predicate that decides whether anything passed, and that nothing tests, is the one place where an error is invisible in both directions: it can refuse a correct subject, and it can admit an incorrect one.

A published row and the verdict computed from it are the same question asked twice. They must be one predicate, so an artefact cannot name a row green that the verdict rejects.

## 4. Rule C — one invariant, one enforcing site

An invariant restated in *N* places has a defect surface of *N*. Discipline is not the variable: a guard applied by hand can be correct every time it is applied and still fail where the author did not think to apply it. Reduce *N* by construction rather than maintaining it by attention.

Two specific forms follow. A predicate that decides the same question as another predicate violates this rule even when both are currently correct. A literal that must agree with a computed cardinality violates it too — derive the bound from the collection, or let the collection's type carry it.

Where a total combinator collapses cardinality — joining a possibly-empty list, or pairing two independently maintained lists — the degenerate case must have a representation of its own. An empty result that means something is a claim, not a missing payload.

## 5. Every rule names its enforcement tier

A doctrine no mechanism enforces is decorative. Each rule reaches one of the three layers in [`illegal_state_techniques.md` §6](../illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force) and names it.

| Tier | Meaning | Mechanism |
|---|---|---|
| 1 — unspellable | no constructor exists | a compile-negative fixture and its registered compile refusal |
| 2 — forbidden | spellable, refused before use | a source-discipline check in the owning phase runner |
| 3 — checked | refused at run time | a runtime predicate **and** a named consumer that asserts it |

Tier 3 alone is insufficient for Rules A and C. A runtime predicate with no asserting consumer produces evidence nothing reads, which is the condition Rule A exists to forbid. A claim must name the tier it reaches, per the honesty discipline in [`documentation_standards.md` §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline); "foreclosed" without a tier is not a claim.

## 6. What this doctrine does not claim

It does not claim the validation apparatus is too large. For software that provisions clusters and seals secrets, a substantial apparatus is proportionate; the question this doctrine asks is how that effort is allocated, not how much of it there is.

It does not claim types carry every invariant. No type prevents a pairing combinator from truncating two lists of the same type, so that case is a tier-2 rule rather than tier 1.

It does not claim duplication is always wrong. Per-phase mutation attribution may require distinct loci under [`development_plan_gate_integrity.md` §M.2](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m2-oracle-independence) and [§M.3](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject). Rule C governs rules, not code. Where the two conflict, attribution wins and the invariant moves to tier 2.

## Related Documents

- [Illegal-state techniques](../illegal_state/illegal_state_techniques.md): the nine typing techniques and the three foreclosure layers this doctrine cites.
- [Gate integrity](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md): gate acceptance, oracle independence, and mutant attribution.
- [Legacy tracking for deletion](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md): the active register, including the row Rule A forecloses.
