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
be recorded as ✅ Done by a human, agent, or CI job. The gate result binds the source snapshot, phase-contract digest, qualified-harness digest,
raw-observation digest, and exact status projection.

The projection's closed diff may touch only the tracker, phase, and sprint status fields named in the passing
result. Any other source, contract, oracle, or documentation change requires a new gate run rather than
borrowing the result for the pre-edit snapshot.

Independent oracle expectations, changed-subject qualification, and raw observations keep the test meaningful.
They are test requirements. After recording a pass, execution may continue
with the next phase in numeric order.

### M.1 The fixed gate contract

Every numbered phase contains a `## Gate integrity` section with exactly one table using the following keys.
Free prose cannot substitute for a missing row, `N/A` carries the required reason, and generated
evidence cannot populate authored contract fields.

| Key | Required content |
|---|---|
| `Claim` | One falsifiable capability statement and its explicit exclusions. |
| `Subject` | The production `.hs` module and entry point exercised; a wrapper, manifest, or gate runner alone is not a subject. |
| `Command` | Future public target: `pb validate phase NN`. Before the Phase-50 gate passes, the executable candidate command is the exact absolute source-bound Haskell binary built directly from a pinned, network-independent toolchain input; invoking `pb` is inadmissible evidence. Phase 50 starts that exact Haskell OS supervisor directly and has it invoke `pb` as the externally observed child subject; the public spelling cannot supervise its own handoff. Phase 51 onward may use `pb` only while binding the current Phase-50 gate pass. Python always treats argv as opaque; the Haskell binary owns host-floor policy, command dispatch, and every verdict. |
| `Oracle` | A separately authored `.hs` oracle module, its independence boundary, and provenance. |
| `Positive controls` | A closed named corpus and the exact observations expected for each member. |
| `Paired negatives` | For every foreclosed dimension, a minimally different positive/negative pair and the exact rejection locus and reason. |
| `Mutants` | An independently literal oracle-owned selector-to-exact-case registry, exact two-way identity reconciliation against production and build mappings, and, for each mutant, its atomic requirement predicate, operator, production locus, applied-change witness, assigned exact red observation, named rejection locus, and same-harness controls that must remain green. |
| `Discovery` | The authoritative expected surface, runtime-discovered surface, two-way equality rule, and explicit refusal of empty discovery. |
| `Challenge` | A post-start nonce/canary for effectful claims, or a stated reason that a pure claim uses an independent predicate instead. |
| `Observer` | The observer outside the subject, raw observation it reads, authenticity check, and fail-closed rule. |
| `Authority/bypass` | Paired least-privilege success/foreign-scope denial and alternate-path probes, or tested non-applicability. |
| `Freshness` | How stale state, cached output, prior evidence, and replayed responses are made unable to pass. |
| `Qualification` | Sabotage cases that qualify the harness before the clean candidate run. |
| `Cleanroom` | Proof that the gate starts without generated products or condemned legacy copies and derives everything required lazily. |
| `Legacy closure` | Reader-facing references to the typed Haskell IDs due in this phase; the compiled lifecycle/owner/required-analyzer dispatch and the owning analyzer's independent oracle supply the zero-finding decision. An unavailable analyzer for a due or retired ID refuses; before its owner an active unavailable analyzer is explicit later-owned debt and cannot claim closure. Cell text supplies no executable value. |
| `Predecessor` | The immediately preceding phase's current gate-pass result, or `genesis` for Phase 0. |
| `Residue` | Untested layers and assumptions, stated as `UNVERIFIED`; an empty residue requires an explicit test rationale. |
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

**Which gates run the whole corpus.** Mutation effort is bounded by what a gate claims, not by what the corpus
contains. The complete selector corpus runs only at a milestone gate. A milestone is named as a phase
capability and resolved through the identity table, never as an ordinal literal, so a reorder cannot silently
move it and a split must assign it to a named successor rather than let it lapse. The milestones are:

- the role boundaries — `self_referential_gates`, `host_assert_cli`, `host_ensure_kernel`, and
  `linux_engine_bringup`;
- the band closures — `repository_layout_conformance`, `calculus_composition`, `compile_fail_harness`,
  `conformance_gate_generator`, `chain_kernel_boundary`, and `test_workflow_algebra`; and
- the live closures — `live_dsl_deploy`, `determinism_jitcache`, and `test_topology_live`.

Each closes a band or a role boundary, so it is the point at which a regression anywhere beneath it must still
be caught.

**What an ordinary gate runs.** An ordinary gate runs a selector if and only if that selector's declared impact
set intersects the exact oracle cases named by the phase's own contract in its `Claim`, `Positive controls`,
and `Paired negatives` rows. The intersection is computed from typed values; no author decides it. The gate
asserts both directions: the impacted selection reddens exactly the intersecting cases, and the complement
stays green. A selector whose reddening is attributed to another selector fails the run, which is what
separates a mutation registry from a rubber stamp. A phase may not narrow its own contract rows to shrink this
set, because those rows are themselves checked against the claim.

**The floor.** Relevance bounds effort; it never excuses absence. Every independent `Deliverables` bullet in a
sprint requires at least one selector. Every permanent refusal and every compile-fail foreclosure claim
requires a weaken-the-constraint selector, whose changed subject makes the illegal twin compile, or the
refusal lift, and only then. A declared locus no suite can execute is not coverage; it is reported against the
capability that owns closing it and is never counted as a mutant.

### M.4 Harness qualification precedes every candidate

The harness is qualified against a fixed, separately authored sabotage corpus before it judges a candidate. Qualification
must show that it rejects, at minimum:

1. a constant-success verdict;
2. a no-op subject;
3. a wrong but well-formed output;
4. empty discovery and a missing subject or oracle;
5. a skipped or no-op mutant;
6. a mutant that fails at the wrong locus;
7. stale or replayed evidence;
8. a self-reported observer substituted for the external observer;
9. an authority or bypass violation;
10. residue or teardown leakage; and
11. a generated or legacy input smuggled into the cleanroom run;
12. a selector omitted from any one of production, the independently literal oracle registry, or the build
    mapping; and
13. a changed subject that makes only an unassigned oracle row red.

Qualification and the clean run are separate invocations over the same harness digest. A candidate produced
by an unqualified harness is rejected regardless of its own result. The qualification corpus is Haskell
source authored independently of the harness implementation; its raw observations are generated lazily and
never committed.

### M.5 Effectful and pure claims

An effectful claim uses a challenge issued after the subject starts and recovers it through an authenticated
observer outside the subject. Missing, incomplete, unauthenticated, challenge-mismatched, or self-reported
observations fail closed. Security claims pair an own-scope success with a foreign-scope denial and observe
zero forbidden effect; route claims probe the intended route and every direct bypass.

A pure claim cannot use a live nonce meaningfully. It instead uses a separately authored predicate, branch
coverage obligations, boundary generators, explicit positive/negative pairs, and changed-subject mutants.
Property sampling reports only the explored sample and its coverage; it never upgrades to universal proof.

### M.6 Candidate evidence and gate pass

The Haskell gate writes raw observations and a schema-checked candidate bundle beneath `.build/runs/**`. Its
digest binds provenance; it does not make the contents true. The candidate must contain explicit per-row
`green`, `red`, `refused`, or `UNVERIFIED` states. Missing rows, empty arrays, implicit defaults, skipped work,
or a top-level success bit without row evidence fail schema validation.

An authored `ContractGap` and an observed `EvidenceAbsent` are different typed refusals. A gate-table slot is
`Bound specification` or `ContractGap`; it never embeds the current presence of a receipt, live host, or run
artifact. Candidate execution separately records whether each specified input was available. In particular,
`Predecessor` specifies `ImmediatePredecessorPass Phase N`; a missing or stale result is an earlier-run
finding, not a reason to leave the contract itself as generic `MISSING`. Reader-facing Markdown cannot convert
either refusal to a satisfied state.

The gate compares the contract, qualification observations, clean observations, source diff, unverified
residue, predecessor result, and exact proposed status-only projection. When every required row is green and
every required refusal was observed, the gate passes and that result is sufficient to apply the projection. A
human, agent, or CI job may repeat this validate-and-record sequence across consecutive phases.

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
guard. An Active zero is admissible only in the owning phase's integrated candidate after the owner analyzer
implements and passes its independently authored negative; it is candidate readiness, not a status or
lifecycle transition. After predecessor evidence is present and that owning gate passes, the next
phase's source records the `Retired` transition. An Active zero before its owner refuses as a stale/missing
finding, and an Active zero after its owner refuses as an unrecorded post-pass transition. The retired
constructor, owner, analyzer key, and qualified Haskell reintroduction negative remain compiled. The
reader-facing Markdown register contributes no identity, owner, lifecycle state, predicate, count, or join
operand to that decision. It is active-only, so the accepted retired explanation is removed and Git history is
the only prose archive. This is accounting, not a waiver: the owning phase must reach zero, and no later phase
may reintroduce the finding.

The transition exception has a hard stop. A Phase-49 candidate must report **zero source-boundary debt**:
every `LTD-SRC-*` query, including Phase-0-owned `LTD-SRC-008`, is zero. The only remaining non-Haskell
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
3. **Semantic source scan.** The source-closure check classifies path, extension, executable bit, shebang,
   imports, resolved call/control-flow graph, potential effects, content role, and consumer. For `pb/**`, a
   deny-by-default Haskell-owned Python AST/import/call/control-flow/effect grammar rejects unsupported syntax,
   unresolved calls, dynamic execution/import/reflection/hooks, and every potential effect not routed to the
   one declared `BootstrapAdapter` boundary. This is a static Phase-0 source-admission result, not evidence that
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
7. **Snapshot closure.** The documented command succeeds from a fresh source snapshot with `.build/**`,
   `.data/**`, and `.test_data/**` absent. An ignored worktree input makes the gate fail.
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
17. **Predecessor closure.** Except Phase 0, the immediately preceding phase has a valid gate-pass result for
    the exact current contract. Hardware-specific work cannot run as a phase gate before the no-hardware DSL
    gate barrier passes.
18. **Complete gate pass.** Run bundles record the test. An isolated or partial check is insufficient, while
    the complete qualified phase-gate pass is sufficient for
    ✅ Done.

<a id="s-commit-timing"></a>

The source-snapshot digest records what ran; commit timing is not an input. A later source or contract change
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
3. No source, fixture, oracle, mutant, harness, build component, directory, or diagnostic filename contains a
   phase ordinal. The only exceptions are `DEVELOPMENT_PLAN/phase_NN_<slug>.md` and generated `.build/**`
   partitions keyed by phase.
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
