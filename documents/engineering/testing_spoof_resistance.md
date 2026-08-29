# Testing spoof resistance

> **Purpose**: Define the threat model and test separation that prevent a subject, runner, fixture, stale
> artifact, or generated report from manufacturing validation.
> **Read this if**: a gate reports success and you need to determine whether its evidence could have been
> produced without the claimed behaviour.

This document owns spoof-resistant evidence. It does not own phase status or its mechanical transition, which belong to the
development plan, or register definitions, which belong to
[`testing_doctrine.md`](./testing_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md
**Generated sections**: none

</details>

## Contents

- [12. Spoof-resistant evidence](#12-spoof-resistant-evidence)
- [12.1 Threat model](#121-threat-model)
- [12.2 Test split](#122-test-split)
- [12.3 Harness qualification](#123-harness-qualification)
- [12.4 Subject-change witnesses](#124-subject-change-witnesses)
- [12.5 Fresh external observation](#125-fresh-external-observation)
- [12.6 Pure claims](#126-pure-claims)
- [12.7 Complete candidate evidence is the gate result](#127-complete-candidate-evidence-is-the-gate-result)
- [12.8 Source and cleanroom boundary](#128-source-and-cleanroom-boundary)
- [12.9 Residue and limits](#129-residue-and-limits)
- [Related Documents](#related-documents)

---

## 12. Spoof-resistant evidence

A gate is spoof-resistant only when a claimed pass cannot be obtained by substituting a constant-success
subject, a no-op, a canned response, stale state, a self-report, an empty discovery set, an unchanged mutant,
or a different failure at the wrong locus. A green exit code is an encoding of observations, not the
observations themselves.

The governing rule is:

> A phase passes when one qualified harness run exercises the changed production subject, a separately authored
> oracle, fresh external observation where effects are claimed, and explicit residue. That complete pass is
> sufficient for the status-only transition.

Omitting any noun changes the claim, rather than weakening an optional defence.

### 12.1 Threat model

Assume each of the following can be wrong, stale, empty, bypassed, or adversarial:

- the subject implementation;
- the test runner and its discovery mechanism;
- fixtures, goldens, snapshots, and expected errors;
- mutant declarations and build flags;
- caches, ignored files, pre-existing generated outputs, and prior evidence;
- self-reported traces, identity fields, and success summaries;
- fake tools, live observers, credentials, and cleanup code; and
- documentation or automation that converts a result into status.

Also assume subject and gate source in one repository can accidentally agree on the same defect. Mutation
sensitivity and separately authored expectations reduce that risk. The project accepts the residual shared-
repository risk and treats a complete qualified gate pass as sufficient.

### 12.2 Test split

The validation boundary has two distinct roles:

| Role | May do | May not do |
|---|---|---|
| **Subject** | Implement the capability and emit ordinary outputs | Define its own expected result |
| **Oracle/harness** | Attempt to falsify the claim, preserve raw observations, and produce the complete gate result | Import subject decision logic or omit required gate rows |

The oracle is separately authored Haskell source, is based on the requirement rather than captured output, and
does not mechanically translate or call the subject's decision function. A second implementation produced by
the same derivation is not independent. The gate records the exact source snapshot, current phase contract,
qualified-harness digest, and raw-observation digest so a later edit cannot reuse an earlier pass.

An integrity adapter that has not crossed its required acquisition, observer, or qualification boundary is a
diagnostic refusal, not a smaller success type. Its raw decoder, integrity-consistent records, constructors,
selectors, and eliminators remain private. Its sole public executable front door returns a `CheckResult` with an
exact non-empty permanent refusal and can never make `checkPassed` true. A conventional `Either ... Right value`,
`Maybe value`, optional residue list, success constructor, general result-producing fold, or getter that detaches
observations from mandatory residue is forbidden even when names and comments say “Diagnostic”. Future candidate
composition consumes a package-hidden verified value; it never promotes the diagnostic record.

The oracle describes wire fixtures, expected identities, limits, projections, and semantic variants with its own
Haskell types and independent literals. It may invoke the one public subject front door, but it does not construct
fixtures with production record constructors, reuse production encoders or expected-value lists, derive its
limits from exported production constants, or accept an unrelated refusal at a boundary. Every admitted boundary
has an exact full projection and every one-over case has an exact reason and locus.

“One-over” means the literal maximum plus one, not an arbitrary larger sample. Every independent acceptance
conjunct and every alternative in a closed grammar has its own minimally different negative; a neighboring case
cannot stand in for timestamp, timezone, case, width, separator, ordering, reserved-name, punctuation, or path-
segment predicates that it does not exercise. Each selected changed-subject operator changes one such production
locus and must make an otherwise internally consistent path differ. A privacy compile-negative names and uses
exactly one forbidden symbol, has a same-library public positive control, and cannot pass merely because a second
private import failed first.

### 12.3 Harness qualification

Before each clean candidate, the exact harness build is challenged with a fixed sabotage corpus. It must
reject all of these:

1. constant success;
2. no-op behaviour;
3. wrong but well-formed output;
4. empty discovery;
5. missing subject or oracle;
6. skipped, missing, or unchanged mutant;
7. mutant failure at an unrelated locus;
8. replayed or stale evidence;
9. self-report substituted for external observation;
10. bypass or foreign-authority success;
11. teardown or external-resource leakage; and
12. a generated or legacy input smuggled into an otherwise clean run;
13. a selector present in production, the oracle, or the build mapping but absent from either of the other
    two inventories; and
14. a changed subject that makes the broad oracle red while its independently assigned exact row stays green.

Qualification is a separate invocation over the same harness digest, followed by the clean candidate run.
The sabotage corpus and qualifier are Haskell source; their observations are generated lazily beneath
`.build/**`. A harness cannot qualify itself by emitting a list saying that these cases passed. The runner
retains the raw refusal observed for each injected sabotage.

### 12.4 Subject-change witnesses

A mutant is useful only if it changes the production subject that the clean gate exercised. For every mutant,
the harness must observe:

- a named operator and exact production locus;
- clean source and binary digests;
- a non-empty applied-change witness in an isolated `.build/source-snapshot/**`;
- a changed subject or binary digest;
- execution of that changed subject;
- the named oracle row turning red for the named reason;
- unrelated controls remaining green; and
- clean behaviour returning after restoration.

A missing target, no-op transform, alternate dead implementation, compilation failure unrelated to the claim,
or blanket red result fails mutation qualification. Mutant count alone carries no evidentiary weight.

Mutation discovery is not itself a pass. Each component oracle owns a literal, closed registry mapping
every expected production selector to the exact independently authored case and rejection locus it is intended
to change. That registry is not generated from CPP declarations, build flags, Cabal mappings, production
constructors, or a previous run. Before any matrix executes, the harness rejects duplicate selector identities,
duplicate or missing exact-case identities, unknown mappings, and every non-empty difference among the
production-selector, oracle-registry, and build-mapping sets in both directions. Cardinality agreement without
identity agreement is insufficient.

The registry itself must be complete against the requirement: every independently meaningful acceptance
conjunct, permanent refusal, resource limit, result-retention rule, closed-grammar alternative, and routing or
composition decision has its own once-only production selector and assigned exact case. A compound challenge
may supplement those atomic selectors but cannot replace them. For each isolated changed subject, the harness
runs the assigned case directly and requires that exact ordered result to differ at the named locus while
unrelated same-harness controls remain green. A failure reported only by the aggregate oracle, an unassigned
case, warning-as-error fallout from dead code, or another boundary is a wrong-locus refusal and does not kill
the mutant.

### 12.5 Fresh external observation

An effectful gate issues an unpredictable challenge after the subject starts, sends it through the public
operation, and recovers it from an authenticated observer outside the subject. The observer reads the effect
owner: for example an OS-boundary invocation trace, authoritative datastore, provider API, raw browser store,
or independently queried control plane.

Unavailable, incomplete, unauthenticated, challenge-mismatched, or self-reported evidence fails closed. A
signature authenticates its emitter; it does not prove that the emitter performed the effect it describes.

Security checks use real least-privilege authority and pair own-scope success with foreign-scope denial while
observing zero forbidden effect. Route and ownership checks probe the sanctioned route and each plausible
direct bypass. A positive path without its paired negative is incomplete.

### 12.6 Pure claims

A pure calculation has no meaningful external effect challenge. It uses:

- a separately authored Haskell reference predicate;
- a closed, non-empty positive corpus;
- minimally different negatives with pinned rejection reason and locus;
- boundary-focused generators with explicit coverage floors; and
- changed-subject mutants that redden the intended predicate.

A property run says only that its explored sample found no counterexample. A compile-fail case says only that
the named expression failed for the pinned reason. A byte comparison says only that two bytestrings agree.
None becomes a universal proof through wording.

### 12.7 Complete candidate evidence is the gate result

The Haskell harness emits a candidate bundle with explicit row states: `green`, `red`, `refused`, or
`UNVERIFIED`. The schema rejects missing rows, empty required arrays, implicit “tested” defaults, skipped work,
and a top-level pass with no raw observations. A digest binds provenance but does not make a claim true.

CI, an agent, or a human may mark a phase Done when the exact current candidate has every required row and the
qualified gate passes. Recording the status is mechanical. Partial evidence, a digest without execution, or an
old result from a different contract remains insufficient.

### 12.8 Source and cleanroom boundary

All product, test, gate, oracle, fake, generator, and mutation logic is Haskell source. The sole non-Haskell
source exception, `pb/**`, may only make the minimum platform distinction needed to establish the pinned
Haskell toolchain, build the source-bound binary, and exec it with every user argument unchanged. Haskell
owns host-floor policy, help, version, validation, and every other public command. Phase 0 bounds the checked-in
exception statically with an exact non-empty, deny-by-default Haskell-owned AST/import/resolved-call/
control-flow/potential-effect graph; tokens, filenames, comments, dead strings, and help output cannot satisfy
it. That result is source admission, not runtime evidence. Phase 0 through Phase 49 invoke Haskell directly.
Phase 50 alone places the already source-bounded adapter effects, executable identity, unchanged argv, exec
replacement, and exit propagation under an external observer.

Every candidate starts without `.build/**`, `.data/**`, `.test_data/**`, generated formats, evidence, caches,
or legacy fallbacks. The run derives required non-Haskell material lazily beneath `.build/**`, proves which
inputs it read, leaves tracked files unchanged, and reports all external residue. A run that succeeds only
because the worktree retained an ignored input is a refusal, not a pass.

### 12.9 Residue and limits

Spoof resistance does not prove that the compiler, kernel, identity authority, provider,
observer, hardware, or cryptography is uncompromised. Those are named assumptions. Nor does one live run prove
future behaviour or another substrate.

Every candidate states its untested layers as `UNVERIFIED`. An empty residue requires an explicit test
rationale; it is never inferred from a full test count. The current repository reset treats every earlier phase result as
invalidated evidence, so this doctrine contains no current per-phase success instances.

---

## Related Documents

- [Testing doctrine](./testing_doctrine.md) — register definitions and test topology
- [Evidence calculus](./evidence_calculus_doctrine.md) — claim-to-fixture binding
- [No-cluster conformance harness](./conformance_harness_doctrine.md) — the pre-hardware pipeline
- [Development-plan gate integrity](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md) — fixed phase contract and gate pass
- [Development-plan tracker](../../DEVELOPMENT_PLAN/README.md) — sole current phase status
