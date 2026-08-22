# Testing spoof resistance

> **Purpose**: Define the threat model and trust separation that prevent a subject, runner, fixture, stale
> artifact, or generated report from manufacturing validation.
> **Read this if**: a gate reports success and you need to determine whether its evidence could have been
> produced without the claimed behaviour.

This document owns spoof-resistant evidence. It does not own phase status or promotion, which belong to the
development plan, or register definitions, which belong to
[`testing_doctrine.md`](./testing_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/testing_doctrine.md, documents/engineering/workflow_calculus_doctrine.md, documents/glossary.md
**Generated sections**: none

</details>

## Contents

- [12. Spoof-resistant evidence](#12-spoof-resistant-evidence)
- [12.1 Threat model](#121-threat-model)
- [12.2 Trust split](#122-trust-split)
- [12.3 Harness qualification](#123-harness-qualification)
- [12.4 Subject-change witnesses](#124-subject-change-witnesses)
- [12.5 Fresh external observation](#125-fresh-external-observation)
- [12.6 Pure claims](#126-pure-claims)
- [12.7 Candidate evidence is not authority](#127-candidate-evidence-is-not-authority)
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

> A phase candidate requires a qualified harness, a changed production subject, an independently reviewed
> oracle, a fresh external observation where effects are claimed, and explicit residue. A validation decision
> additionally requires external human authorization and the human's separate status promotion.

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

Also assume subject and gate source in one repository can collude. Mutation sensitivity reduces accidental
self-agreement; it cannot prove that the shared trust domain is honest. Therefore technical evidence is never
the final status authority.

### 12.2 Trust split

The validation boundary has three distinct roles:

| Role | May do | May not do |
|---|---|---|
| **Subject** | Implement the capability and emit ordinary outputs | Define its own expected result or validation status |
| **Oracle/harness** | Attempt to falsify the claim and preserve raw observations | Import subject decision logic or promote the phase |
| **Human validation authority** | Review the contract, qualification, observations, residue, and source diff; sign and apply promotion | Delegate promotion to a pass bit, agent, or generated receipt |

The oracle is separately authored Haskell source. It is reviewed by someone other than the subject's sole
author, is based on the requirement rather than captured output, and does not mechanically translate or call
the subject's decision function. A second implementation produced by the same derivation is not independent.

The human approval is externally authenticated and binds the source snapshot, current phase contract,
qualified-harness digest, and raw-observation digest. The trust root is human-controlled and cannot be changed
and used by the candidate in one promotion. An unsigned field, a hash-like token, or a generated attestation
does not satisfy this boundary.

### 12.3 Harness qualification

Before each clean candidate, the exact harness build is challenged with a reviewed sabotage corpus. It must
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
12. a generated or legacy input smuggled into an otherwise clean run.

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

- a separately reviewed Haskell reference predicate;
- a closed, non-empty positive corpus;
- minimally different negatives with pinned rejection reason and locus;
- boundary-focused generators with explicit coverage floors; and
- changed-subject mutants that redden the intended predicate.

A property run says only that its explored sample found no counterexample. A compile-fail case says only that
the named expression failed for the pinned reason. A byte comparison says only that two bytestrings agree.
None becomes a universal proof through wording.

### 12.7 Candidate evidence is not authority

The Haskell harness emits a candidate bundle with explicit row states: `green`, `red`, `refused`, or
`UNVERIFIED`. The schema rejects missing rows, empty required arrays, implicit “tested” defaults, skipped work,
and a top-level pass with no raw observations. A digest binds provenance but does not make a claim true.

CI, an LLM, the subject, the harness, and an evidence reader may report a **Validation candidate**. They may
not mark or describe a phase as Done. Only the human validation authority may sign the external approval and
personally change the plan status.

This is the control that prevents a repository-local runner from certifying its own correctness. It is also
why old evidence cannot be “re-verified” into a new status after the contract changes.

### 12.8 Source and cleanroom boundary

All product, test, gate, oracle, fake, generator, and mutation logic is Haskell source. The sole non-Haskell
source exception, `pb/**`, may only make the minimum platform distinction needed to establish the pinned
Haskell toolchain, build the source-bound binary, and exec it with every user argument unchanged. Haskell
owns host-floor policy, help, version, validation, and every other public command. A deny-by-default Haskell
AST/import/effect audit and an external effect observer—not tokens or help output—bound the exception.

Every candidate starts without `.build/**`, `.data/**`, `.test_data/**`, generated formats, evidence, caches,
or legacy fallbacks. The run derives required non-Haskell material lazily beneath `.build/**`, proves which
inputs it read, leaves tracked files unchanged, and reports all external residue. A run that succeeds only
because the worktree retained an ignored input is a refusal, not a pass.

### 12.9 Residue and limits

Spoof resistance does not prove that the human reviewer, compiler, kernel, identity authority, provider,
observer, hardware, or cryptography is uncompromised. Those are named assumptions. Nor does one live run prove
future behaviour or another substrate.

Every candidate states its untested layers as `UNVERIFIED`. An empty residue requires explicit human review;
it is never inferred from a full test count. The current repository reset treats every earlier phase result as
invalidated evidence, so this doctrine contains no current per-phase success instances.

---

## Related Documents

- [Testing doctrine](./testing_doctrine.md) — register definitions and test topology
- [Evidence calculus](./evidence_calculus_doctrine.md) — claim-to-fixture binding
- [No-cluster conformance harness](./conformance_harness_doctrine.md) — the pre-hardware pipeline
- [Development-plan gate integrity](../../DEVELOPMENT_PLAN/development_plan_gate_integrity.md) — fixed phase contract and human promotion
- [Development-plan tracker](../../DEVELOPMENT_PLAN/README.md) — sole current phase status
