# Development Plan: gate integrity and repository closure

> **Purpose**: Define the non-spoofable phase-gate contract, the universal source and artifact postconditions,
> the typed divergence inventory plus its one reader-facing register, and the final-tree rule every phase inherits.
> **Read this if**: a phase gate is being written, reviewed, run, or proposed as evidence for a status change.

This slice is authoritative for gate integrity. The phase model and status authority live in
[`development_plan_phase_model.md`](development_plan_phase_model.md); the hub that preserves the rulebook's
section lettering lives in [`development_plan_standards.md`](development_plan_standards.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/evidence_calculus_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/testing_spoof_resistance.md, documents/engineering/validation_frame_doctrine.md
**Generated sections**: none

</details>

## Contents

- [M. Gate integrity (a gate cannot authorize itself)](#m-gate-integrity-a-gate-cannot-authorize-itself)
- [S. Universal source and artifact hygiene gate](#s-universal-source-and-artifact-hygiene-gate)
- [T. Plan-to-implementation reconciliation](#t-plan-to-implementation-reconciliation)
- [U. The final repository layout](#u-the-final-repository-layout)
- [Related Documents](#related-documents)

---

<a id="m-gate-integrity-a-gate-cannot-be-passed-by-a-stub"></a>

## M. Gate integrity (a gate cannot authorize itself)

A phase gate is an attempt to falsify one bounded claim. It is not a script exit code, an evidence bundle, a
hash, a self-reported ledger, or a count of tests. Those are observations a reviewer may use. None can promote
a phase by itself.

Three parties are deliberately distinct:

1. the **subject** implements the claimed behaviour;
2. the **oracle and harness** attempt to falsify that behaviour without importing its decision logic; and
3. the **human validation authority** reviews the contract and raw observations and alone may promote status.

The subject, harness, generated evidence, an LLM, or CI may produce a **validation candidate**. Only the human
authority may write ✅ Done. A candidate remains **NOT VALIDATED** until that decision. The approval is an
external, cryptographically authenticated receipt bound to the source snapshot, phase-contract digest,
qualified-harness digest, and raw-observation digest. It verifies against a human-controlled trust root that
the candidate change cannot amend and use in the same promotion. A path, hash-looking string, or unsigned
Markdown assertion is not approval.

This trust split is intentional. Source in one repository can always be changed so that subject and test
collude; no program in that same trust domain can prove the absence of such collusion. Independent review and
human-held signing authority close the authorization gap that mutation testing alone cannot close.

### M.1 The fixed gate contract

Every numbered phase contains a `## Gate integrity` section with exactly one table using the following keys.
Free prose cannot substitute for a missing row, `N/A` carries the required reason and reviewer, and generated
evidence cannot populate authored contract fields.

| Key | Required content |
|---|---|
| `Claim` | One falsifiable capability statement and its explicit exclusions. |
| `Subject` | The production `.hs` module and entry point exercised; a wrapper, manifest, or gate runner alone is not a subject. |
| `Command` | Future public target: `pb validate phase NN`. Before Phase 50 has current human approval, the executable candidate command is the exact absolute source-bound Haskell binary built directly from an authenticated, network-independent toolchain input; invoking `pb` is inadmissible evidence. Phase 50 alone subjects `pb` to external runtime observation. Phase 51 onward may use `pb` only while binding the current Phase-50 approval. Python always treats argv as opaque; the Haskell binary owns host-floor policy, command dispatch, and every verdict. |
| `Oracle` | A separately authored `.hs` oracle module, its independence boundary, provenance, and human reviewer. |
| `Positive controls` | A closed named corpus and the exact observations expected for each member. |
| `Paired negatives` | For every foreclosed dimension, a minimally different positive/negative pair and the exact rejection locus and reason. |
| `Mutants` | For each mutant: operator, production locus, applied-change witness, expected red observation, and controls that must remain green. |
| `Discovery` | The authoritative expected surface, runtime-discovered surface, two-way equality rule, and explicit refusal of empty discovery. |
| `Challenge` | A post-start nonce/canary for effectful claims, or a reviewed reason that a pure claim uses an independent predicate instead. |
| `Observer` | The observer outside the subject, raw observation it reads, authenticity check, and fail-closed rule. |
| `Authority/bypass` | Paired least-privilege success/foreign-scope denial and alternate-path probes, or reviewed non-applicability. |
| `Freshness` | How stale state, cached output, prior evidence, and replayed responses are made unable to pass. |
| `Qualification` | Sabotage cases that qualify the harness before the clean candidate run. |
| `Cleanroom` | Proof that the gate starts without generated products or condemned legacy copies and derives everything required lazily. |
| `Legacy closure` | Reader-facing references to the typed Haskell IDs due in this phase; the compiled lifecycle/owner/required-analyzer dispatch and the owning analyzer's independent oracle supply the zero-finding decision. An unavailable analyzer for a due or retired ID refuses; before its owner an active unavailable analyzer is explicit later-owned debt and cannot claim closure. Cell text supplies no executable value. |
| `Predecessor` | The immediately preceding phase's human approval receipt, or `genesis` for Phase 0. |
| `Residue` | Untested layers and assumptions, stated as `UNVERIFIED`; an empty residue requires reviewer justification. |
| `Human authority` | Required external approval class; always `human-only`, never a tool-generated assertion. |

The `**Gate:**` summary line contains only the future public command and a link to this table. A
phase-specific command may be an argument selected by the Haskell dispatcher, but Python, shell, a data file,
or a generated program may not decide or wrap the verdict. The public spelling is not admissible evidence for
Phase 0 through Phase 49: those candidates invoke the exact absolute source-built Haskell executable directly.
Phase 50 validates the `pb` transport itself under an external observer; only its current human approval makes
that transport eligible for Phase 51 onward. Presence of the target spelling in a phase document is never a
claim that it exists, ran, or passed.

The structural documentation checker may parse governed inventory, metadata, headings, links, anchors,
backlinks, status syntax, phase dependencies, and this fixed table shape. It may not infer any row's semantic
adequacy or any cross-cutting product/source/provider decision from natural-language wording or token counts.
Those executable decisions live in reviewed Haskell declarations; prose correspondence is a separate human
review obligation. A policy-looking prose decoy must be behaviorally inert.

<a id="gate-integrity-delegation"></a>

### M.2 Oracle independence

An oracle is independent only when all of the following are true:

- its expectation is authored from the requirement, not captured or regenerated from subject output;
- it does not import, call, copy, or mechanically translate the subject's decision function;
- its reviewer is not the sole author of the subject behaviour under review;
- its provenance predates the candidate implementation or has an explicit independent-review receipt; and
- changing it is reviewed as a contract change and invalidates affected evidence.

Independent expectations are Haskell source. A second-language copy or repository-retained serialized
expectation in TSV, JSON, YAML, Dhall, or any other transport format is not stronger independence; it is
additional behavioural source that the Haskell-only rule forbids. Byte output is compared by a separately
authored Haskell semantic predicate or by bytes derived at run time from that predicate under `.build/**`.

### M.3 Mutants must prove that they changed the subject

Counting mutant declarations is not mutation testing. Before a mutant result is accepted, the harness records
the clean subject digest, applies a named operator to a named production locus in an isolated
`.build/source-snapshot/**` copy, records the changed digest and a semantic or textual diff witness, builds
that changed subject, and observes the specified red result. A missing locus, no-op transform, unchanged
binary, unexecuted mutant, skipped mutant, or red result at another locus fails the gate.

The operator set and mutant declarations are Haskell values. The run must demonstrate at least these
properties:

- each required mutant is discovered and executed exactly once;
- each mutant changes the intended production behaviour;
- the named oracle row turns red for the named reason;
- unrelated positive controls remain green; and
- restoring the clean source restores the clean result.

A deliberately broken alternate implementation that production can never select is not a mutant of the
subject. A build flag is admissible only when the resulting compiled production locus and changed binary are
both observed.

### M.4 Harness qualification precedes every candidate

The harness is qualified against a fixed, reviewed sabotage corpus before it judges a candidate. Qualification
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
11. a generated or legacy input smuggled into the cleanroom run.

Qualification and the clean run are separate invocations over the same harness digest. A candidate produced
by an unqualified harness is rejected regardless of its own result. The qualification corpus is Haskell
source reviewed independently of the harness implementation; its raw observations are generated lazily and
never committed.

### M.5 Effectful and pure claims

An effectful claim uses a challenge issued after the subject starts and recovers it through an authenticated
observer outside the subject. Missing, incomplete, unauthenticated, challenge-mismatched, or self-reported
observations fail closed. Security claims pair an own-scope success with a foreign-scope denial and observe
zero forbidden effect; route claims probe the intended route and every direct bypass.

A pure claim cannot use a live nonce meaningfully. It instead uses a separately reviewed predicate, branch
coverage obligations, boundary generators, explicit positive/negative pairs, and changed-subject mutants.
Property sampling reports only the explored sample and its coverage; it never upgrades to universal proof.

### M.6 Candidate evidence and human promotion

The Haskell gate writes raw observations and a schema-checked candidate bundle beneath `.build/runs/**`. Its
digest binds provenance; it does not make the contents true. The candidate must contain explicit per-row
`green`, `red`, `refused`, or `UNVERIFIED` states. Missing rows, empty arrays, implicit defaults, skipped work,
or a top-level success bit without row evidence fail schema validation.

The human reviewer compares the contract, qualification observations, clean observations, source diff,
unverified residue, and predecessor approval. The reviewer may then issue the external approval receipt and
personally change status. Automation and LLMs are prohibited from creating, copying, inferring, or claiming
that approval.

---

<a id="s-universal-artifact-hygiene-gate"></a>

## S. Universal source and artifact hygiene gate

The final invariant is absolute, but numerical migration needs a fail-closed transition rule. Before the final
source migration closes, a phase candidate may contain only source-boundary findings joined in both directions
to an active ID in the closed Haskell legacy universe whose typed owner is a strictly later phase. The reviewed
Haskell inventory owns each identity, stable encoding, lifecycle state, owner, required-analyzer key, and total
dispatch. Dispatch to an absent, mismatched, or unfinished analyzer produces a typed unavailable state;
inventory setup cannot stand in for that analyzer's observations, closure predicate, or independently authored
domain negative. An unbound finding, a due or earlier-owned finding, a stale active binding with no finding, a
duplicated locus, or an unavailable analyzer for a due or retired ID refuses the candidate. Before its owner,
an active unavailable analyzer is recorded only as explicit later-owned debt and cannot report closure. Defining
the inventory early therefore creates no dependency on later implementation: the owning sprint implements and
qualifies its analyzer in numerical order.

Retirement is a typed transition, not deletion of executable memory. After the owner analyzer reports zero, its
reintroduction negative succeeds, predecessor evidence is present, and the human accepts the transition, the ID
becomes `Retired`; its constructor, owner, analyzer key, and Haskell reintroduction guard remain compiled. The
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
    key, and one total fail-closed dispatch route in reviewed Haskell. The owning sprint supplies the domain
    observation/closure analyzer and independent reintroduction negative; until then, `AnalyzerUnavailable`
    cannot be represented as closure and refuses once the binding is due or retired. Before its owner it is
    explicit later-owned debt only. The owning phase reaches zero matching findings before it
    may be a validation candidate. Earlier phases account exactly for later-owned findings against those active
    bindings; findings may not be deferred out of, reassigned by, or survive their owning phase. After accepted
    retirement, the Haskell ID and reintroduction guard remain even though the active explanation is removed.
    The single [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md) file explains the inventory to
    readers. The legacy structural seam may enforce that this exact canonical file exists once, is UTF-8
    readable, and has no archive alias. The general documentation checker may separately enforce ordinary
    orientation metadata, headings, links, and anchors. Neither seam may interpret a row, table cell, ID
    spelling, owner phrase, predicate-shaped string, or row count as legacy semantics or use it to alter a
    closure verdict. Human review owns correspondence between the Haskell bindings and that explanation.
17. **Predecessor closure.** Except Phase 0, the immediately preceding phase has a valid human approval receipt
    for the exact current contract. Hardware-specific work cannot run as a phase gate before the no-hardware
    DSL promotion barrier is human-approved.
18. **Evidence is not authority.** Run bundles are generated diagnostics. No path, digest, attestation, test
    count, or tool-emitted “pass” authorizes ✅ Done.

<a id="s-commit-timing"></a>

The source-snapshot digest records what ran; commit timing is not an input. A later source or contract change
invalidates only evidence it changes, but every phase in the present reset is explicitly **NOT VALIDATED** and
has no reusable approval. No pre-reset seal, attestation, hash, status sentence, or scoped result may be
promoted into current evidence.

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
   [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md). Human review, not a parser, owns the
   correspondence between those two surfaces. The owning sprint implements the exact observation/closure
   analyzer and independent domain reintroduction negative; registering the obligation does not execute later
   work or make the mismatch eligible to close.
5. Keep that reader-facing register active-only. Closed or superseded explanations are deleted after the human
   confirms the corresponding Haskell transition; the retired constructor, owner, analyzer key, and
   reintroduction guard remain compiled, while Git history is the prose archive. No archive file, archive slice,
   “closed” appendix, or second deletion list is permitted. The legacy structural seam checks exact canonical
   file cardinality, UTF-8 readability, and archive absence; the general documentation checker may still
   enforce ordinary orientation metadata, headings, links, and anchors. Neither interprets a row, cell, ID,
   owner, count, or predicate-shaped string into inventory, lifecycle, or closure authority.
6. Resolve policy ambiguity in doctrine before changing implementation. An audit does not choose product
   policy implicitly.
7. Update the doctrine owner, phase contract, tracker, component/substrate inventory, Haskell legacy binding,
   and reader-facing legacy explanation together when a decision changes their shared boundary. The human
   correspondence review is required even though the Markdown explanation cannot change an executable result.
8. Re-run source closure from an empty generated tree. A local ignored file, pre-existing tool, cache, or
   compatibility copy cannot satisfy a prerequisite silently.
9. Audit revision history separately. Historical blobs may require a human decision, but they never become a
   second live work register.
10. Preserve numerical order. A later phase may not validate an earlier phase by proxy, and hardware evidence
    may not substitute for the pre-hardware DSL promotion barrier.

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
- [Phase model](development_plan_phase_model.md) — status, sequence, and human-only promotion
- [Development-plan tracker](README.md) — the sole current phase-status source
- [Reader-facing legacy register](legacy_tracking_for_deletion.md) — current divergence explanation only;
  Haskell owns executable identity, lifecycle, ownership, dispatch, and retained reintroduction guards
- [Migration doctrine](../documents/engineering/migration_doctrine.md) — distinguishes active prose retirement
  from permanent executable reintroduction memory
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md) — the complete tree and source classification
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md) — the trust and evidence threat model
