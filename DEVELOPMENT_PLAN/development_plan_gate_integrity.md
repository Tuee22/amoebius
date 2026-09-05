# Development Plan: gate integrity and repository closure

> **Purpose**: Define the non-spoofable phase-gate contract, the universal source and artifact postconditions,
> the typed divergence inventory plus its one reader-facing register, and the final-tree rule every phase inherits.
> **Read this if**: a phase gate is being written, checked, run, or proposed as evidence for a status change.

This slice is authoritative for gate integrity. The phase model and status transition live in
[`development_plan_phase_model.md`](development_plan_phase_model.md); the hub that preserves the rulebook's
section lettering lives in [`development_plan_standards.md`](development_plan_standards.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_03_artifact_calculus.md, DEVELOPMENT_PLAN/phase_04_budget_calculus.md, DEVELOPMENT_PLAN/phase_05_lift_calculus.md, DEVELOPMENT_PLAN/phase_06_workflow_calculus.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/validation_frame_doctrine.md
**Generated sections**: none

</details>

## Contents

- [M. Gate integrity (a gate cannot be passed by a stub)](#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
- [S. Universal source and artifact hygiene gate](#s-universal-source-and-artifact-hygiene-gate)
- [T. Plan-to-implementation reconciliation](#t-plan-to-implementation-reconciliation)
- [U. The final repository layout](#u-the-final-repository-layout)
- [Related Documents](#related-documents)

---

<a id="m-gate-integrity-a-gate-cannot-be-passed-by-a-stub"></a>

## M. Gate integrity (a gate cannot be passed by a stub)

A phase gate is an attempt to falsify one bounded claim. A complete qualified pass is sufficient for the
phase's status-only transition. A smaller script exit code, isolated check, evidence bundle, hash, self-reported
ledger, or test count is not the complete phase gate.

Two test responsibilities remain deliberately distinct:

1. the **subject** implements the claimed behaviour; and
2. the **oracle and harness** attempt to falsify that behaviour without importing its decision logic.

The gate remains **NOT VALIDATED** until every required row passes in one qualified run. That complete pass may
be recorded as ✅ Done by a human, agent, or CI job. The package-hidden `VerifiedGatePass` binds phase, source
preimage, complete acquired-evidence digest, exact status-patch digest, and projected whole-source postimage
digest, and retains the opaque durable-publication receipt. Every identity, execution-context value, predecessor,
ordered row observation, and residue entry is transitively bound by the evidence digest.

The patch's closed diff may touch only the typed status frontier derived for the passing phase: its tracker
row and phase-status line, both status surfaces for every sprint it closes, and—except at the terminal
phase—the successor's tracker row, phase-status line, and first-sprint heading/status activation. Any other
source, contract, oracle, or documentation change requires a new gate run rather than borrowing the result for
the pre-edit snapshot.

Independent oracle expectations, changed-subject qualification, and raw observations keep the test meaningful.
They are test requirements. The validator emits the verified patch beneath `.build/**` and leaves the tracked
tree unchanged; only after it exits may a human, agent, or CI job recheck the preimage and apply it. After recording a pass, execution may continue
with the next phase in numeric order.

### M.1 The fixed gate contract

Every numbered phase contains a `## Gate integrity` section with exactly one table using the following keys.
Free prose cannot substitute for a missing row, `N/A` carries the required reason, and generated
evidence cannot populate authored contract fields.

| Key | Required content |
|---|---|
| `Claim` | One falsifiable capability statement and its explicit exclusions. |
| `Subject` | The production `.hs` module and entry point exercised; a wrapper, manifest, or gate runner alone is not a subject. |
| `Command` | Future public target: `pb validate phase NN`. Before the Phase-50 gate passes, the executable candidate command is the exact absolute source-bound Haskell binary invoked directly; invoking `pb` is inadmissible evidence. Phase 0 binds the narrow non-numbered `GenesisTrust` local-custody token, which does not authenticate the actual compiler executable bytes, derivation, loader, broader host, or reproducibility. Phase 1 owns those acquisition/provenance claims for subsequent builds; neither claim lets a binary prove its own compiler. Phase 50 starts the exact Haskell OS supervisor directly and has it invoke `pb` as the externally observed child subject; the public spelling cannot supervise its own handoff. Phase 51 onward may use `pb` only while binding the current Phase-50 gate pass. Python always treats argv as opaque; the Haskell binary owns host-floor policy, command dispatch, and every verdict. |
| `Oracle` | A separately authored `.hs` oracle module, its independence boundary, and provenance. |
| `Positive controls` | A closed named corpus and the exact observations expected for each member. |
| `Paired negatives` | For every foreclosed dimension, a minimally different positive/negative pair and the exact rejection locus and reason. |
| `Mutants` | An independently literal oracle-owned selector-to-exact-case registry, exact two-way identity reconciliation against production and build mappings, and, for each mutant, its atomic requirement predicate, operator, production locus, applied-change witness, assigned exact red observation, named rejection locus, and same-harness controls that must remain green. The sole finite-bootstrap exception is Phase 0's exact three `BootstrapPredicate` cases in §M.4, which use acquired one-line replacements and a direct serial compiler harness rather than Cabal selectors. |
| `Discovery` | The authoritative expected surface, runtime-discovered surface, two-way equality rule, and explicit refusal of empty discovery. |
| `Challenge` | A post-start nonce/canary for effectful claims, or a stated reason that a pure claim uses an independent predicate instead. |
| `Observer` | The observer outside the subject, raw observation it reads, authenticity check, and fail-closed rule. |
| `Authority/bypass` | Paired least-privilege success/foreign-scope denial and alternate-path probes, or tested non-applicability. |
| `Freshness` | How stale state, cached output, prior evidence, and replayed responses are made unable to pass. |
| `Qualification` | The phase-owned qualification that precedes the clean candidate. Phase 0 uses the exact clean-plus-three finite-bootstrap protocol in §M.4. The `self_referential_gates` universal owner uses the closed seventeen-case sabotage corpus; no earlier phase must counterfeit that later capability. |
| `Cleanroom` | Proof that the gate starts without its disallowed current-run products and derives required outputs lazily. The ordinary sole retained generated input is the exact read-only immediate-predecessor receipt. Phase 0 instead consumes its seven GenesisTrust inputs and proves only that its uniquely named qualification leaf is absent after the serial run; whole-`.build/**` absent-before and universal replay closure belong to Phase 49. |
| `Legacy closure` | Reader-facing references to the typed Haskell IDs due in this phase; the compiled lifecycle/owner/required-analyzer dispatch and the owning analyzer's independent oracle supply the zero-finding decision. Phase 0 instead proves structural register integrity and an exact due-count of zero; its separately required scoped `SourcePb` zero does not retire Phase-2-owned `LTD-SRC-008`. An unavailable analyzer for a due or retired ID refuses; before its owner an active unavailable analyzer is an explicit forward deferral and cannot claim closure. Cell text supplies no executable value. |
| `Predecessor` | The immediately preceding phase's current gate-pass result, or the digest-bound irreducible `GenesisTrust`/`BootstrapRoot` represented structurally as `genesis` for Phase 0. |
| `Residue` | Phase 0 requires exactly empty `captureResidue`; later-owned capabilities are typed exclusions/forward deferrals and never candidate residue. A later phase states applicable untested layers and assumptions as `UNVERIFIED`; an empty later-phase residue requires an explicit test rationale. |
| `Pass criterion` | Always `qualified-gate-pass`: every required row succeeds in one qualified run for the exact current source. That result is sufficient for the status-only transition. |

The `**Gate:**` summary line contains only the future public command and a link to this table. A
phase-specific command may be an argument selected by the Haskell dispatcher, but Python, shell, a data file,
or a generated program may not decide or wrap the verdict. The public spelling is not admissible evidence for
Phase 0 through Phase 49: those candidates invoke the exact absolute source-built Haskell executable directly.
Phase 50 validates the `pb` transport itself under an external observer; only its current gate pass makes
that transport eligible for Phase 51 onward. Presence of the target spelling in a phase document is never a
claim that it exists, ran, or passed.

The structural documentation checker may parse governed inventory, metadata, headings, links, anchors,
backlinks, status syntax, phase dependencies, and this fixed table shape. It may not infer any row's semantic
adequacy or any cross-cutting product/source/provider decision from natural-language wording or token counts.
Those executable decisions live in tested Haskell declarations; prose correspondence is a documentation-gate
obligation. A policy-looking prose decoy must be behaviorally inert.

<a id="gate-integrity-delegation"></a>

### M.2 Oracle independence

An oracle is independent only when all of the following are true:

- its expectation is authored from the requirement, not captured or regenerated from subject output;
- it does not import, call, copy, or mechanically translate the subject's decision function;
- its fixtures, limits, expected projections, and expected semantic variants use separately authored Haskell
  types and literals rather than production record constructors, encoders, constants, or shared value lists;
- every accepted boundary asserts the complete expected projection, and every one-over input asserts one exact
  refusal reason and locus rather than accepting any failure;
- it is separately authored from the subject behaviour it checks;
- its provenance is recorded with the candidate; and
- changing it is a contract change that invalidates affected evidence.

Independent expectations are Haskell source. A second-language copy or repository-retained serialized
expectation in TSV, JSON, YAML, Dhall, or any other transport format is not stronger independence; it is
additional behavioural source that the Haskell-only rule forbids. Byte output is compared by a separately
authored Haskell semantic predicate or by bytes derived at run time from that predicate under `.build/**`.

An adapter below a missing capture, observer, or qualification boundary exposes no success-shaped decoded
value. Raw parsers, integrity-consistent records, constructors, selectors, and general eliminators are private;
the public diagnostic front door is an always-refusing `CheckResult` with exact non-empty permanent residue. An
`Either` right branch, optional finding list, arbitrary-result fold, or detachable getter is non-conforming even
when its type or function name contains `Diagnostic`.

### M.3 Mutants must prove that they changed the subject

Counting mutant declarations is not mutation testing. Before a mutant result is accepted, the harness records
the clean subject digest, applies a named operator to a named production locus in an isolated
`.build/source-snapshot/**` copy, records the changed digest and a semantic or textual diff witness, builds
that changed subject, and observes the specified red result. A missing locus, no-op transform, unchanged
binary, unexecuted mutant, skipped mutant, or red result at another locus fails the gate.

The operator set and mutant declarations are Haskell values. The run must demonstrate at least these
properties:

- an independently literal oracle registry and the production and build inventories contain exactly the same
  selector identities, with no duplicate, unknown, missing, or unassigned selector or exact-case target;
- each required mutant is discovered and executed exactly once;
- each mutant changes the intended production behaviour;
- the registry-assigned exact oracle row turns red at the named locus for the named reason;
- unrelated positive controls remain green; and
- restoring the clean source restores the clean result.

A deliberately broken alternate implementation that production can never select is not a mutant of the
subject. A build flag is admissible only when the resulting compiled production locus and changed binary are
both observed. Production or build declarations may be reconciled against the oracle registry, but may not
generate it or define its expected cardinality. An aggregate oracle red outside the assigned row, a
warning-as-error caused by dead changed-subject code, or a failure at another boundary is not a mutant kill.
At a milestone gate, every independent acceptance conjunct, permanent refusal, resource and
result-retention bound, closed-grammar alternative, and routing or composition decision requires an atomic
selector; a compound challenge is supplemental rather than a substitute. An ordinary gate draws from that same
corpus by the selection rule below.

**Which gates run the cumulative corpus.** Mutation effort is bounded by what a gate claims and by what the
numeric frontier has made eligible, not by selectors owned by future phases. A milestone runs every selector
whose typed owner is at or before that milestone; a future-owned selector is forward-deferred and cannot reopen an
earlier phase merely by being added. Phase 49 is the first complete hardware-free universal/self-referential
corpus. Later milestones add only selectors whose owners have since become eligible. A milestone is named as a phase
capability and resolved through the identity table, never as an ordinal literal, so a reorder cannot silently
move it and a split must assign it to a named successor rather than let it lapse. The milestones are:

- the role boundaries — `self_referential_gates`, `host_assert_cli`, `host_ensure_kernel`, and
  `linux_engine_bringup`;
- the band closures — `repository_layout_conformance`, `calculus_composition`, `compile_fail_harness`,
  `conformance_gate_generator`, `chain_kernel_boundary`, and `test_workflow_algebra`; and
- the live closures — `live_dsl_deploy`, `determinism_jitcache`, and `test_topology_live`.

Each closes a band or a role boundary, so it is the point at which a regression anywhere at or beneath its
typed ownership frontier must still be caught. `repository_layout_conformance` therefore closes the finite
source/layout/compiler corpus owned through that capability; it does not execute selectors that later phases
have not yet authored or owned.

**What an ordinary gate runs.** An ordinary gate runs a selector if and only if that selector's declared impact
set intersects the exact oracle cases named by the phase's own contract in its `Claim`, `Positive controls`,
and `Paired negatives` rows. The intersection is computed from typed values; no author decides it. The gate
asserts both directions: the impacted selection reddens exactly the intersecting cases, and the complement
stays green. A selector whose reddening is attributed to another selector fails the run, which is what
separates a mutation registry from a rubber stamp. A phase may not narrow its own contract rows to shrink this
set, because those rows are themselves checked against the claim.

**The floor.** Relevance bounds effort; it never excuses absence. Except for the explicit finite Phase-0 seed
in §M.4, every independent `Deliverables` bullet in a sprint requires at least one selector. Every permanent
refusal and every compile-fail foreclosure claim requires a weaken-the-constraint selector, whose changed
subject makes the illegal twin compile, or the refusal lift, and only then. A declared locus no suite can
execute is not coverage; it is reported against the capability that owns closing it and is never counted as a
mutant. The exception is closed over three bootstrap predicates and cannot be widened by calling later work a
Phase-0 deliverable.

### M.4 Harness qualification precedes every candidate

Every candidate is preceded by the qualification contract owned at its capability frontier. Phase 0 has one
explicit finite-seed exception: `BootstrapQualification.Internal` compiles and runs, serially, the unchanged
`BootstrapPredicate` followed by exactly `digest-equality-bypass`, `snapshot-freshness-bypass`, and
`bootstrap-path-bypass`. The independent `BootstrapMutationDriver` must accept only clean; every mutant must
change both source and binary identity; the exact ordered transcript binds the acquired snapshot, genesis
compiler path, exits, stdout/stderr, and teardown; clean must return silent `ExitSuccess`; every mutant must
return `ExitFailure 1`, empty stdout, and its canonical case label plus one newline on stderr; and the generated
leaf must be absent. This v2 protocol is the whole Phase-0 qualification requirement. It does not claim the
universal validator can detect all ways of sabotaging itself.

At the `self_referential_gates` universal owner, the harness is additionally qualified against this fixed,
separately authored seventeen-case sabotage corpus before it judges the universal clean candidate. That
qualification must reject exactly the closed inventory before any supplemental cases:

1. a constant-success verdict;
2. a no-op subject;
3. a wrong but well-formed output;
4. empty discovery;
5. a missing subject;
6. a missing oracle;
7. a skipped or no-op mutant;
8. a mutant that fails at the wrong locus;
9. stale or replayed evidence;
10. a self-reported observer substituted for the external observer;
11. an authority or bypass violation;
12. residue or teardown leakage;
13. a generated or legacy input smuggled into the cleanroom run;
14. a selector omitted from production;
15. a selector omitted from the independently literal oracle registry;
16. a selector omitted from the build mapping; and
17. a changed subject that makes only an unassigned oracle row red.

For the universal owner, qualification and the clean run are separate invocations over the same harness digest.
A candidate produced by an unqualified harness is rejected regardless of its own result. The corpus is Haskell
source authored independently of the harness implementation; its raw observations are generated lazily and
never committed. The public `checkQualificationReportDiagnostic` seam checks only caller-supplied report
consistency and permanently emits `QUALIFICATION-REPORT-DIAGNOSTIC-ONLY`; it cannot mint the execution-derived
qualification digest used by candidate evidence.

The seventeen sabotage shapes belong to the complete hardware-free universal and self-referential surface.
Phase 1 separately adds authenticated toolchain acquisition and Phase 2 adds the compiler-backed source graph;
neither is pulled into Phase 0. Later-owned cases are typed forward deferrals and cannot block an earlier
candidate merely because the closed plan already names their owner.

Both qualification authorities are opaque. The Phase-0 authority binds one common acquired snapshot, subject,
independent driver, qualification harness, absolute genesis compiler path, clean receipt, three mutation
receipts, transcript, and zero-residue teardown. The universal authority binds its common source, executable,
harness, oracle, compiler, toolchain, and execution identity to a clean full-subject run, all seventeen
positional sabotage runs, and terminal teardown. Each universal sabotage carries exact source/executable
preimage and postimage, independently assigned code/subject/gate-row locus, exact same-run unaffected controls,
bounded raw results, and transcript projections. A digest-shaped caller value, a different control inventory,
an unchanged source or binary, or a result copied from another run cannot mint either authority.

For the universal protocol, the case contract is a distinct acquired authority; an attempt may not nominate its own target, operator,
expected result, or control inventory and then compare the observation back to that nomination. Process evidence
is likewise inseparable from execution: one opaque bounded supervisor receipt owns exact executable file identity,
argv, working directory, environment policy, stdout/stderr EOF and non-truncation, termination mode, and the parsed
result derived from those same bytes. A signal, timeout, spawn failure, or resource/output limit is not an ordinary
refusal. The supervisor issues a fresh candidate-run challenge after acquisition and hash-chains the ordered
sabotage, restored-clean, and teardown receipts to it; replaying an older protocol for identical source bytes or
wrapping a copied `CheckResult` in a new scalar run identity must fail candidate binding.

### M.5 Effectful and pure claims

An effectful claim uses a challenge issued after the subject starts and recovers it through an authenticated
observer outside the subject. Missing, incomplete, unauthenticated, challenge-mismatched, or self-reported
observations fail closed. Security claims pair an own-scope success with a foreign-scope denial and observe
zero forbidden effect; route claims probe the intended route and every direct bypass.

A pure claim cannot use a live nonce meaningfully. It instead uses a separately authored predicate, branch
coverage obligations, boundary generators, explicit positive/negative pairs, and changed-subject mutants.
Property sampling reports only the explored sample and its coverage; it never upgrades to universal proof.

### M.6 Candidate evidence and gate pass

Production runner selection is a closed capability-keyed Haskell registry. The dispatcher first resolves the
requested ordinal through the compiled phase-identity table and then requires exactly one registered runner for
that capability; an absent identity, absent runner, duplicate capability, or ambiguous selection refuses. A
second ordinal switch or caller-supplied runner name is not an execution authority. A candidate runs that one
selected phase; it does not re-run gates `0..N` as one expanding subject. Phase 0 binds `GenesisTrust`, and every
later candidate binds an exact verified immediate-predecessor receipt. That receipt records the predecessor's
completed frontier transition and is monotonic across later source snapshots. The active phase's exact
current-source gate owns compatibility with the capabilities it consumes, including shared validation policy.
A source change therefore cannot erase an earlier pass or force recursive prefix replay; malformed, detached,
wrong-phase, or non-green predecessor evidence still refuses.

A Done phase has one additional legal execution mode: **receipt refresh**. It reruns the complete
qualified gate against the exact current source, changes no tracked status, emits an identity status projection,
and installs a new content-addressed receipt. Receipt refresh cannot make a phase Done, skip a failed row, or
advance the frontier. It is an explicit regression operation, never a prerequisite automatically induced by a
later edit. Normal phase implementation therefore never recursively invalidates the completed prefix.

Repeated qualified runs for the same phase form one receipt equivalence class; their
run-specific identities may differ without creating competing predecessor meanings. Acquisition verifies every
entry fail-closed, filters to the exact phase, and selects the lexicographically least content digest as the
deterministic exact receipt. A malformed or detached entry still fails the whole acquisition. Thus refresh is
idempotent while conflicting provenance cannot be silently selected.

The dispatcher first constructs one opaque acquired run whose owner recomputes the selected Subject from the
exact source/compiler/qualification/debt/contract products. Evidence cannot accept a caller-authored Subject or
opening digest. It seals the sixteen non-circular rows, evaluates Legacy from those exact premises, and derives
Pass criterion only afterward. The dispatcher then serializes those raw observations into a package-hidden, schema-checked
candidate bundle beneath `.build/runs/phase-NN/candidates/**`. Its content digest binds the serialized evidence;
it does not make the contents true. The writer publishes the bounded canonical bytes without replacement at the
exact phase/content address, exact-reads and synchronizes the same no-follow regular-file descriptor and parent,
exact-reads again, and only then returns an opaque receipt bound to repository, directory, and file identity.
The acquired v2 candidate records opening and closing source digests, contract/subject/oracle/
harness/observer/qualification identities, proposed-status-patch and postimage digests, typed predecessor,
executable path/digest and argv, toolchain/substrate/lane/architecture/run/cleanup context, the exact ordered
eighteen-row inventory, and explicit residue. Each row is exactly execution-derived `green`, `red`, or
`unverified`; a green row must retain at least one well-formed raw observation. An observation key occupies one
TSV field; its value may retain tab-framed raw columns, while an empty value, line terminator, or NUL is malformed.
JSON publication escapes admitted tabs without changing their bytes. Missing, duplicate, reordered, empty,
defaulted, skipped, or caller-constructed row evidence cannot pass verification.

The public evidence and gate-pass records remain caller-constructible diagnostic seams and carry no tracked-
state write authority. `verifyPublishedGatePass` first re-acquires the absolute canonical content-addressed
regular non-symlink file, its stored identities, and exact bytes; an unpublished or in-memory candidate cannot
mint authority. Only that package-hidden verifier can mint `VerifiedGatePass`, and only after the source is
unchanged, every required identity and execution-context field is present and canonical, all eighteen rows are
green, residue exactly matches the contract's explicit later-owned or assumed `UNVERIFIED` set with no due,
unclassified, or undeclared item, and the typed predecessor is the digest-bound `GenesisTrust` root only for
Phase 0 or the immediate predecessor's evidence digest otherwise. The token binds phase, source, complete
evidence digest, exact proposed patch, projected whole-source postimage, and the retained publication receipt.

An authored `ContractGap` and an observed `EvidenceAbsent` are different typed refusals. A gate-table slot is
`Bound specification` or `ContractGap`; it never embeds the current presence of a receipt, live host, or run
artifact. Candidate execution separately records whether each specified input was available. In particular,
`Predecessor` specifies `ImmediatePredecessorPass Phase N`; a missing or stale result is an earlier-run
finding, not a reason to leave the contract itself as generic `MISSING`. Reader-facing Markdown cannot convert
either refusal to a satisfied state.

The closed registry remains structural across all numbered phases, but semantic obligation is scoped to the
selected candidate: a gap owned at or before Phase N refuses Phase N, while an exactly owner-bound later gap is
typed deferred residue. Phase 0 therefore checks the all-phase shape and owner relation but binds only its finite
seed semantics. It cannot be made dependent on implementing every later phase contract.

The status patch is derived from the acquired source snapshot and typed status frontier, never from a
caller-supplied edit. Its exact target set is the closing phase's tracker/phase status and every sprint heading/
status pair, plus the successor's tracker/phase status and first sprint heading/status when a successor exists.
The projected postimage must satisfy the compiled post-pass phase-contract check before its digest can be bound
into candidate evidence. Authorization requires the hidden verified token to match phase, source preimage,
patch digest, and projected whole-source postimage digest exactly, and retains the complete verified pass
and receipt.

For receipt refresh the exact target set is empty, the projection preimage and postimage are the same current
source digest, and the phase must already be Done in one canonical frontier. The same hidden verifier, complete
eighteen-row gate, opening/closing equality, qualification, cleanup, and durable-publication checks apply. A
nonempty refresh projection, a refresh of an Active/Blocked phase, or use of refresh evidence to advance status
is rejected.

The production dispatcher gives the sealed `AuthorizedStatusProjection` to
`writeAuthorizedStatusProjection`, which serializes the canonical patch, its preimage identity, exact target
set, and projected postimage beneath the run-scoped `.build/**` evidence root. The underlying unsealed writer is
reachable only through a direct-source test seam. The validator does not acquire tracked-write authority, lock
the repository, write a status journal, exchange tracked files, roll back a partial tracked edit, or recover one.
After emission it re-acquires the Git source snapshot and refuses if that capture is unavailable or differs
from the opening source identity. A successful gate therefore satisfies tracked-tree immutability for that run.
After the process exits, a human, agent, or CI job may re-acquire the tracked preimage and apply the exact
emitted patch. A stale preimage, symlink, unexpected target bytes, widened target set, patch tamper, or postimage
mismatch refuses that external mechanical application and requires a fresh candidate. Cross-platform crash
recovery belongs to the actor's ordinary source-control workflow, not to Phase 0's validation subject.

The gate therefore compares the contract, qualification observations, clean observations, source diff,
unverified residue, predecessor result, and exact proposed status-only patch before the token can exist.
When every required row is green and every required refusal was observed, the verified result is sufficient to
authorize that patch for external mechanical application. These structural paths do not themselves prove that
any current phase qualified or passed. A human, agent, or CI job may repeat this validate-and-record sequence
across consecutive phases.

### M.7 Representative corpora and partitions

A claim whose domain is too large to enumerate may be gated over a named representative corpus rather than the
whole domain. The corpus is admissible only when it is a closed Haskell value authored from the requirement,
each member names the exact dimension it stands for, the selection rule is stated, and `Residue` names the
unexercised remainder as `UNVERIFIED`. A count of passing cases is not a representative corpus. Neither is a
sample drawn from subject output, nor one whose membership a production declaration decides.

A partition splits one domain across several owners. It is admissible only when every member is assigned to
exactly one owner, the assignment reconciles two-way against the domain with no duplicate and no unassigned
member, and each member is exercised once, at its assigned owner. Where one phase owns a fold's mechanics and
another owns the gate oracle for the same member, the partition names both roles and the member is gated at
the oracle owner. An unassigned member refuses the candidate; it is not silently inherited by the earlier
phase.

### M.8 Paired negatives assert an exact reason at an exact locus

A negative that merely fails is not evidence. For every foreclosed dimension the gate carries a minimally
different positive/negative pair. The paired positive differs in exactly that one dimension and must succeed.
The negative must be refused with the exact reason and at the exact locus a separately authored Haskell
expectation names. This is the operative form of the `Paired negatives` row in [§M.1](#m1-the-fixed-gate-contract)
and of the one-over rule in [§M.2](#m2-oracle-independence).

None of the following is a kill: a generic failure, a non-zero exit, any compile failure rather than the named
one, a refusal at another locus, an unpaired negative, an expectation captured from subject output, or a twin
that differs in more than the foreclosed dimension. Where an input carries several sufficient loci, each locus
owes its own pair rejected at that locus; the single truth-maker recorded for the entry is the
earliest-sufficient locus in pipeline order, which selects the record rather than excusing the other pairs.

---

<a id="s-universal-artifact-hygiene-gate"></a>

## S. Universal source and artifact hygiene gate

The final invariant is absolute, but numerical migration needs a fail-closed transition rule. Before the final
source migration closes, a phase candidate may contain only source-boundary findings joined in both directions
to an active ID in the closed Haskell legacy universe whose typed owner is a strictly later phase. The tested
Haskell inventory owns each identity, stable encoding, lifecycle state, owner, required-analyzer key, and total
dispatch. Dispatch to an absent, mismatched, or unfinished analyzer produces a typed unavailable state;
inventory setup cannot stand in for that analyzer's observations, closure predicate, or independently authored
domain negative. An unbound finding, a due or earlier-owned finding, a stale active binding with no finding, a
duplicated locus, or an unavailable analyzer for a due or retired ID refuses the candidate. Before its owner,
an active unavailable analyzer is recorded only as explicit later-owned debt and cannot report closure. Defining
the inventory early therefore creates no dependency on later implementation: the owning sprint implements and
qualifies its analyzer in numerical order.

The current Sprint-0.2 disposition universe is Active-only. Retirement is a future typed transition, not
deletion of executable memory. Sprint 0.2 retains a required reintroduction-case identity, not an executed
guard. An Active zero is admissible only in the owning phase's integrated candidate when opaque evidence binds
the same row and source snapshot to the exact canonical reintroduction-case set and qualifying transcript, after
the owner analyzer implements and passes its independently authored negative; it is candidate readiness, not a status or
lifecycle transition. After predecessor evidence is present and that owning gate passes, the next
phase's source records the `Retired` transition. An Active zero before its owner refuses as a stale/missing
finding, and an Active zero after its owner refuses as an unrecorded post-pass transition. The retired
constructor, owner, analyzer key, and qualified Haskell reintroduction negative remain compiled. The
reader-facing Markdown register contributes no identity, owner, lifecycle state, predicate, count, or join
operand to that decision. It is active-only, so the accepted retired explanation is removed and Git history is
the only prose archive. This is accounting, not a waiver: the owning phase must reach zero, and no later phase
may reintroduce the finding.

The transition exception has a hard stop. A Phase-49 candidate must report **zero source-boundary debt**:
every `LTD-SRC-*` query, including Phase-2-owned `LTD-SRC-008`, is zero. Phase 0 first requires a scoped
`SourcePb` zero for its captured bootstrap source without retiring that binding. The only remaining non-Haskell
behavioral source is Python under `pb/**` that a deny-by-default Haskell AST/import/effect audit has positively
classified into minimal platform discrimination, contained toolchain establishment, source-bound build, and
opaque exec handoff. Phase 50 validates the runtime behavior of that already-bounded handoff and owns no
source-migration binding. Phase 51 and every later candidate retain the same final source grammar.
Consequently no host or hardware phase can open while condemned source remains tracked.

Every phase inherits the following postconditions. They are part of the gate, not optional cleanup:

1. **Closed source language.** The target snapshot contains no tracked executable, behavioural, validation,
   test, fake, oracle, generator, migration, or runtime logic except `.hs`; during the ordered migration, every
   contrary finding must satisfy the strictly-later typed-binding transition rule above, which expires before
   the Phase-49 candidate.
2. **One bootstrap exception.** Non-Haskell program source is permitted only under `pb/**`, and only to make
   the minimum platform distinction needed to select the establishment adapter, establish the pinned
   Haskell toolchain, build the source-bound
   Haskell binary, and exec it with every user argument unchanged. Haskell owns host-floor decisions, public
   commands, help, version, product policy, tests, gates, evidence, and validation verdicts.
3. **Phase-scoped source scan.** Phase 0 exhaustively captures every tracked path, kind, mode, and byte sequence,
   applies the closed path/extension/executable-bit/shebang classification, and statically checks `pb/**` with a
   deny-by-default Haskell-owned Python AST/import/call/control-flow/effect grammar that rejects unsupported syntax,
   unresolved calls, dynamic execution/import/reflection/hooks, and every potential effect not routed to the
   one declared `BootstrapAdapter` boundary. Phase 2 owns the compiler-backed import, resolved call/control-flow,
   potential-effect, content-role, provenance, dynamic-load, sink, and consumer graph for the Haskell source.
   Until Phase 2 closes it, that unproved semantic layer is an exact typed later-owned finding, not an implicit
   Phase-0 prerequisite. This is a static Phase-0 `pb` source-admission result, not evidence that
   the adapter or handoff ran. Phase 50 alone validates actual effects, binary identity, unchanged argv, and
   exec replacement under an external observer. Renaming another program as data or omitting an extension does
   not admit it; keyword absence or public-help enumeration is never proof of role.
4. **Lazy derivation.** Dockerfiles, bake files, Dhall, PureScript, JavaScript, shell, Proto, Pulumi programs,
   manifests, fixtures, goldens, negatives, mutant materializations, inventories, ledgers, and every other
   reproducible product are generated only when consumed and only beneath `.build/**`.
5. **Narrow authored non-code inputs.** Markdown, licenses, Cabal/project configuration, ignore rules, and
   narrowly justified packaging metadata may be tracked. None may encode executable product or validation
   decisions that belong in Haskell.
6. **No source-adjacent output.** Compilation, generation, resolution, caches, temporary files, interpreter
   bytecode, evidence, and test discovery remain beneath `.build/**`. There is no cache exception beside
   authored source, including for `pb`.
7. **Snapshot closure.** The documented command ordinarily succeeds from a fresh source snapshot with the
   current run, build/cache, `.data/**`, and `.test_data/**` roots absent. The sole retained generated input is
   the exact read-only content-addressed immediate-predecessor receipt beneath `.build/evidence-store/**`.
   Phase 0 instead consumes its seven GenesisTrust files, binds exact opening/pre-publication-closing source
   identities, re-acquires Git source after status-projection emission, and proves its unique qualification leaf
   absent after the run; it does not claim whole-`.build/**` absent-before or universal replay detection. A
   Every later candidate projects the verified immediate-predecessor frontier fact onto its current opening
   source; repeated valid receipts for that phase form the deterministic equivalence class defined in §M.6. Malformed or detached
   evidence, or any other ignored worktree input outside the declared Phase-0 exception, makes the gate fail.
8. **No condemned fallback.** The cleanroom run starts with every legacy path owned by the phase absent and
   proves no fallback, migration input, compatibility copy, or pre-generated substitute was read.
9. **Tracked-tree immutability.** The gate does not change any tracked file and leaves no unignored output.
10. **Two ignore boundaries.** Generated output, dependency trees, caches, evidence, secrets, and runtime
    state are excluded from both the repository and container build contexts.
11. **State containment.** Production state lives only under `.data/**`; test state lives only under one
    marker-proven `.test_data/runs/<run-id>/**` root; teardown removes exactly the owned test root.
12. **External residue check.** Before/after observation reports every repository-owned path, mount, loop
    device, container, volume, cache, daemon, namespace, and external resource touched by the run. Unexpected
    residue fails.
13. **Secret containment.** No cleartext secret enters source, output, arguments, environments, logs, build
    contexts, or candidate evidence. Test-secret exceptions, if any, are explicit inputs outside production
    and are destroyed with the run.
14. **Natural architecture.** Hardware runs record detected substrate, selected lane, and natural
    architecture; emulation and cross-built evidence cannot establish another lane.
15. **Complete discovery.** Expected and discovered test/capability/resource surfaces agree in both
    directions, are non-empty where the claim requires behaviour, and contain no implicit “tested” defaults.
16. **Active legacy closure.** Every divergence has one stable typed identity, one owner, one required-analyzer
    key, and one total fail-closed dispatch route in tested Haskell. The owning sprint supplies the domain
    observation/closure analyzer and independent reintroduction negative; until then, `AnalyzerUnavailable`
    cannot be represented as closure and refuses once the binding is due or retired. Before its owner it is
    explicit later-owned debt only. The owning phase reaches zero matching findings before it
    may be a validation candidate. Earlier phases account exactly for later-owned findings against those active
    bindings; findings may not be deferred out of, reassigned by, or survive their owning phase. After retirement
    is recorded, the Haskell ID and qualified owner-domain reintroduction negative remain even though the active explanation is removed.
    The single [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md) file explains the inventory to
    readers. The legacy structural seam enforces that this exact canonical file exists once as a regular
    non-executable UTF-8 file, that its exact basename occurs nowhere else, and that the exact forbidden archive
    basename is absent. It does not classify arbitrary renamed prose as a semantic alias. The general
    documentation checker may separately enforce ordinary orientation metadata, headings, links, and anchors,
    and it also applies a basename-substring register-cardinality diagnostic and case-folded
    forbidden-archive-basename content diagnostic. Those documentation findings do not supply legacy semantics.
    Neither seam may interpret a row, table cell, ID
    spelling, owner phrase, predicate-shaped string, or row count as legacy semantics or use it to alter a
    closure verdict. The documentation gate owns correspondence between the Haskell bindings and that explanation.
17. **Predecessor closure.** Except Phase 0, the immediately preceding phase has a valid durable gate-pass
    result. The current phase owns compatibility with its exact opening source. Hardware-specific work cannot run as a phase gate before the no-hardware DSL
    gate barrier passes.
18. **Complete gate pass.** Run bundles record the test. An isolated or partial check is insufficient, while
    the complete qualified phase-gate pass is sufficient for
    ✅ Done.

<a id="s-commit-timing"></a>

The source-snapshot digest records what ran; version-control commit timing is not a gate input. A later source or contract change
invalidates only evidence it changes, but every phase in the present reset is explicitly **NOT VALIDATED** and
has no reusable gate pass. No pre-reset result may be carried into the current gate.

---

## T. Plan-to-implementation reconciliation

Doctrine states target intent, the plan states sequence and acceptance, repository inspection states what is
present, and qualified evidence states what one run observed. None can silently substitute for another.

Every reconciliation follows these rules:

1. Record the date, exact source snapshot, worktree boundary, inspected roots, and whether each observation is
   tracked, untracked, ignored, generated, historical, or external.
2. Compare semantic contracts: capability, subject entry point, independent oracle, gate behaviour,
   source/artifact provenance, register, substrate, and cleanup. Similar filenames prove nothing.
3. Report implementation presence only as an observed footprint or known partial. Compilation, file presence,
   an old run, or a generated bundle is never validation.
4. Put every current mismatch in the closed Haskell legacy universe, with a typed stable ID, `Active` lifecycle
   state, owner phase, required-analyzer key, and total dispatch route whose unavailable state refuses. Then
   update the corresponding reader-facing explanation in
   [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md). The documentation gate, not a parser, owns the
   correspondence between those two surfaces. The owning sprint implements the exact observation/closure
   analyzer and independent domain reintroduction negative; registering the obligation does not execute later
   work or make the mismatch eligible to close.
5. Keep that reader-facing register active-only. Closed or superseded explanations are deleted after the
   corresponding owning gate passes; the retired constructor, owner, analyzer key, and qualified
   owner-domain reintroduction negative remain compiled, while Git history is the prose archive. No archive file, archive slice,
   “closed” appendix, or second deletion list is permitted. The legacy structural seam checks exact canonical
   file cardinality, UTF-8 readability, and archive absence; the general documentation checker may still
   enforce ordinary orientation metadata, headings, links, and anchors plus its basename-substring cardinality
   and forbidden-archive-basename content diagnostics. Neither interprets a row, cell, ID,
   owner, count, or predicate-shaped string into inventory, lifecycle, or a closure verdict.
6. Resolve policy ambiguity in doctrine before changing implementation. An audit does not choose product
   policy implicitly.
7. Update the doctrine owner, phase contract, tracker, component/substrate inventory, Haskell legacy binding,
   and reader-facing legacy explanation together when a decision changes their shared boundary. The consolidated
   phase documentation gate must check correspondence even though the Markdown explanation cannot change a
   legacy binding or closure verdict.
8. Re-run source closure from an empty generated tree. A local ignored file, pre-existing tool, cache, or
   compatibility copy cannot satisfy a prerequisite silently.
9. Audit revision history separately. Historical blobs may inform debugging, but they never become a second
   live work register.
10. Preserve numerical order. A later phase may not validate an earlier phase by proxy, and hardware evidence
    may not substitute for the pre-hardware DSL gate barrier.

---

## U. The final repository layout

[`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md) owns the complete
normative tree and the mechanical file classification. The development plan adds four consequences:

1. A phase may name only a final authored path already admitted by that tree. A needed new root is justified
   and added to doctrine before implementation, never treated as temporary.
2. Authored behavioural source is Haskell, with the sole bounded `pb/**` bootstrap exception in [§S](#s-universal-source-and-artifact-hygiene-gate).
   Reproducible non-Haskell material is a lazy product beneath `.build/**`, not repository source.
3. No product/runtime identity, authored product path, build component, or product diagnostic filename contains
   a phase ordinal. Phase contracts and validation evidence may name the phase they validate: the
   `DEVELOPMENT_PLAN/phase_NN_<slug>.md` contracts, source-bound validation-kernel/oracle identifiers, and
   generated `.build/**` evidence partitions are necessarily phase-keyed. They must not be consumed as
   product/runtime identities.
4. Every root is justified by what its contents are and who consumes them, not by the phase or build target
   that first needed it.

These rules make repository closure a prerequisite to evidence. A gate cannot certify behaviour while
silently consuming a condemned source language, a pre-generated artifact, or a legacy fallback.

---

## Related Documents

- [Development-plan standards](development_plan_standards.md) — the family hub and phase-document schema
- [Phase model](development_plan_phase_model.md) — status, sequence, and gate pass
- [Development-plan tracker](README.md) — the sole current phase-status source
- [Reader-facing legacy register](legacy_tracking_for_deletion.md) — current divergence explanation only;
  Haskell owns executable identity, lifecycle, ownership, dispatch, and required reintroduction-case identities;
  an owning analyzer supplies a qualified executable negative before any retirement
- [Migration doctrine](../documents/engineering/migration_doctrine.md) — distinguishes active prose retirement
  from permanent executable reintroduction memory
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md) — the complete tree and source classification
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md) — the trust and evidence threat model
