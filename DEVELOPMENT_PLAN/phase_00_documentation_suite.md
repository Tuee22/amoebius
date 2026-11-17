# Phase 0: Documentation, governance, and the validation seed

> **Purpose**: Establish the governance seed (decision log, frozen baseline, standalone documentation checker), the finite bootstrap seed (`GenesisTrust`, the three-case predicate matrix, the six custody controls), and the validator itself (custody core, generic gate runner, mechanical transition commands, kernel budget).
> **Read this if**: Phase 0's status or contract is being assessed, a cross-cutting rule changes, or a later phase needs the exact boundary between bootstrap assumptions and numbered validation claims.

Phase 0 specifies the seed needed to start ordered validation under certification generation 2; it proves no
reproducible toolchain, no source closure, no product capability, and no live substrate. It builds the
validator that judges every later phase, so nothing product-facing is a Phase-0 deliverable.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_06_extension_admission_attested_scope.md, DEVELOPMENT_PLAN/system_components.md, documents/decision_log.md, documents/documentation_standards.md, documents/engineering/gate_runner_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/validation_frame_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 0.1: Governance surface](#sprint-01-governance-surface-)
- [Sprint 0.2: Checker reconciliation](#sprint-02-checker-reconciliation-)
- [Sprint 0.3: Documentation checker extraction](#sprint-03-documentation-checker-extraction-)
- [Sprint 0.4: Gate specification and runner core](#sprint-04-gate-specification-and-runner-core-)
- [Sprint 0.5: Custody core and verifier commands](#sprint-05-custody-core-and-verifier-commands-)
- [Sprint 0.6: Delete pass, package rewrite, and executable split](#sprint-06-delete-pass-package-rewrite-and-executable-split-)
- [Sprint 0.7: Phase-0 gate specification, first generation, and receipt-bearing reset](#sprint-07-phase-0-gate-specification-first-generation-and-receipt-bearing-reset-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

## Phase Status

✅ Done.
**Receipt**: d63eec54d322841b6ef6bc6c396afa7080daec8c2d98ddc68906d81bcc544d83

**Historical accepted repair and governance replay — DL-0042.** The complete repaired preview passed all
eighteen gate rows and the archive-evidence projection with exit zero and minted nothing. The separate
complete acceptance issued [receipt `d209a9dad927a2e8a7fbc6aa0bb33c3a74eca3bdc4414817eee94a3d5022ba9c`](../validation-records/generation-732468e33bfbee88/receipts/phase-00-d209a9dad927a2e8a7fbc6aa0bb33c3a74eca3bdc4414817eee94a3d5022ba9c-08a711f06b8fc38ed0078eb95e75b24330222039b78e0194bf3207474d03c2e0/receipt.tsv)
at 2026-10-26 22:11:40.134788 UTC. Its archived ordinary ledger has 1,120 unique green judgments: 41
documentation and 1,079 runner rows. The accepted candidate records 45 legacy reports and nine
source-bound qualification transcripts with 549 green judgments. Its kernel is twenty files and 3,353
lines at the unchanged cap. These are the bounded Phase-0 results; they supply no successor gate pass.

The acceptance qualifies the image/completion repair opened by
[DL-0041](../documents/decision_log.md#dl-0041--runner-authority-reopens-for-image-and-oracle-completion-witnesses).
[DL-0042](../documents/decision_log.md#dl-0042--qualified-image-and-completion-custody-retires-runner-authority) retires exactly `LTD-VAL-001` and removes its active reader row while retaining all forty-four
Haskell identities, owners, analyzers, source queries, independent expectations, five original canonical
authority cases and retained guards. The explicit finite-image and supplied-transcript extension remains.
At that checkpoint, the changed lifecycle and governance required complete Phase-0 replay before fresh
Phase-1 preview and separate acceptance, followed by Phase 2 in order. Done and receipt fields remain the verifier's
mechanical projection; the linked acceptance remains immutable evidence of its recorded inputs.

The subsequent complete replay failed at 2026-10-26 23:46:22.055946 UTC and published an
[immutable revocation marker](../validation-records/generation-732468e33bfbee88/voids/phase-00-08a711f06b8fc38ed0078eb95e75b24330222039b78e0194bf3207474d03c2e0-ccc911f3c3f121f6b2dd109dadc31f3d8e0b07cbbdead0080271b49692252e15.tsv).
Its positive-control, paired-negative and pass-criterion rows were red. The nine source-bound legacy
qualifications had completed with 549 green judgments; the clean documentation run had zero findings
and all nine rendered negatives produced their named findings. A focused plan-projection diagnostic
then reproduced one red judgment, `frozen.amendment-digests`: the independent oracle still named the
legacy register's pre-DL-0042 digest. An independent Haskell hash of the authored amended document
confirmed the new body identity, and that stale literal has been corrected. The corrected projection
passed all 29 core judgments. A fresh source-bound documentation component then passed all 41 full
judgments and seventeen independent checks of the seven native process returns, three protocol frames,
source identity and stable executable images. The red replay left the Done line in place and revoked
that receipt; the marker remains immutable and no older bundle can bypass it. At that checkpoint, a
complete green replay was required before Phase 1 could proceed.

The ordered reproduction begun on 2026-10-29 published a new complete green Phase-0 record on
2026-10-30 at 02:18:45 UTC, with all eighteen categories green and the bounded archive projection
verified. The receipt field above is the verifier's projection. The subsequent Phase-1 run was interrupted
at the user's request and supplies no new successor pass. The [Phase-2 handoff](phase_02_repository_layout_conformance.md#phase-status)
records the stopping point. These observations bind the inputs of that completed reproduction; subsequent
documentation or source changes require fresh affected-closure replay before reuse.

The earlier [receipt-bearing reset](../validation-records/generation-cb7e5824edef6f01/receipts/phase-00-d038b39e4408fe5b9493ba326cca0eb09f1d8bc7e496d95a912d084f6d45c3c6-3c35b68f109f63510fdc2864cdb7ba19568b6b23929960e48d50dd333c422279/receipt.tsv)
at 2026-10-24 11:26:08 UTC was a nongate reopening under DL-0041. Earlier image-less observations and
the component checkpoints below do not replace the repaired owning acceptance or its required replay.
The implemented factory is available and constructs opaque readiness only after the complete framed
source-bound run. The initial single-analyzer diagnostic qualified authority but correctly refused the
other eight absent Phase-0 bindings; only the complete gate joined all nine qualifications.

The finite seed now retains actual clean and changed predicate/driver inputs, complete rebuilt image
buffers before and after execution, exact process observations and explicit attempted/unattempted fields.
Eligibility requires the original silent clean success, the exact label-only exit-one refusal for each
of the three bypasses, stable image bytes during each known run and a changed image for every mutant.
An unavailable native build or run stops the remaining seed cases, retains the owned leaf and leaves
later image, source and cleanup operations unattempted. This is the existing three-mutant Phase-0 matrix;
qualification controls add no product mutant or later-owned capability to it.

The ordinary controller acquires separate inventory, missing-input probe and normal oracle frames through
the actual native process path. Each invocation binds its own fresh challenge, retained complete output,
ordinary prefix, row count, digest, names and terminal purpose. Semantic red at exit one remains an ordinary
judgment. Malformed, incomplete or abnormal completion supplies no product kill. Separate invocations
retain separate witnesses; combining clean documentation and custody ledgers does not merge their frames.

Candidate-owned native records retain the selected configuration attempt and complete selected bytes,
prepared executable/argv/cwd/environment, returned native tuple and actual operation prefix. Compiler windows
must associate uniquely with their requests and close with complete canonical records, contiguous Natural
ordinals and exact call inventories. Bridge sources, helper plans/images, requested compiler and parent
returns must agree. The controller also retains complete target-plan bytes and binds each suite/oracle image
to its unique local source unit before image reads or execution. Missing, ambiguous, foreign or mismatched
bindings refuse. Image paths must be confined regular nonempty files, and retained before/after bytes must
remain equal. These checks preserve supplied/fake pre-DSL scope and introduce no digest-pinned toolchain,
hardware, privileged account or external supervisor prerequisite.

An actual native `IOException` retains its original object, known observations and owned root, attempts one
stopped-prefix write outside normal teardown, and performs no dependent native or closing operations.
An unclosed compiler journal escapes separately and retains the root without additional producer logging.
Post-return plan/helper observations establish their stated readback and consistency checks; they do not
alone prove pre-execution helper use, complete required-read/provider custody or child quiescence.

The shipped verifier now exposes `authority-observe --input PATH` as an explicitly untrusted diagnostic
through the same compiled controller. It captures and materializes actual source under a fresh confined
`.build/runs/**` destination and retains the resulting native records, image measurements, issuance/frame
projections, source checks and contexts. It mints no readiness, receipt or status. Actual Runner and
documentation runs passed seventeen independent checks apiece over their complete 783-name and 41-name
namespaces. Unsupported profiles, two native plan/image mismatches and a missing Cabal boundary refused as
specified; reused and out-of-frame destinations refused before mutation. Compiler controls admitted the
public diagnostic and refused private qualification constructors, native scope and the hidden Core module.

A catalogue-generated weakening rebuilt the actual source-bound verifier, rather than an augmented Core
entry. The independent Runner oracle produced exactly ten expected failures and five early-stop checks
remained green. Exact source restoration and rebuilding restored all seventeen Runner checks. Complete
mutant and restored verifier images remained byte-stable during their executions, and the changed image
differed from its baseline. Equality between separate unmodified rebuilds is not claimed.

The retained [finite-seed producer](../test/runner/SeedImages.hs) and
[independent oracle](../test/oracle/runner/SeedImages.hs) expose seventeen explicit component scenarios
through `--seed-image-completion`. They exercise the compiled public product API with actual native returns,
full retained image buffers and separately authored literal expectations. The scenarios include source/locus
mismatches, known exit 127, missing/empty/symlinked images, identical clean/mutant images with otherwise exact
output, images changed during execution, incorrect driver output and unavailable build/run boundaries.
Fake compilers are explicit supplied boundaries and supply no native-toolchain admission. The initial public
API run passed all 212 independent checks. A catalogue branch swap of the production clean/mutant image
comparison rebuilt the actual product provider and produced exactly its three predicted failures; exact
restoration and rebuilding restored all 212 checks. Complete collector images stayed stable during execution,
and the changed provider's linked collector image differed from baseline.
The retained native test mode also passed all 212 checks from a caller tree without Git metadata: it
copied the three selected source inputs into its own fresh fixture repository and left the caller's bytes
and inventory unchanged. Its serial source-bound build succeeded. The complete independent Runner
regression passed all 783 rows; the full namespace and phase specifications remain unchanged. These
component observations supply no owning qualification or phase pass.

The changed-image control now builds distinct pre-run images, so the separate clean/mutant image guard
cannot mask its closing-image failure. The strengthened retained mode passed 213 independent checks.
A separate catalogue swap of the closing-image equality rebuilt the actual source-bound suite and produced
exactly its two predicted failures. Exact source restoration and rebuilding restored all 213 checks;
mutant and restored suite/oracle images stayed byte-stable during execution, and the mutant suite image
differed from the restored one. The comparison checker was corrected to read the retained oracle's three
columns; its expected failing identities remained unchanged.

At the first framed checkpoint, the owning runner-authority path ran the complete `runner.full.v2` profile
through the same native controller used by ordinary validation. Its 996 ordinary judgments retained the original 783-name
namespace and add the 213 finite-image checks. The authority transcript selects its 272 existing and
extension judgments from that complete normal prefix without renaming them. Inventory, missing-input
probe and normal completion keep separate challenges and retained frames. Full suite/oracle image buffers
remain available before and after execution and are written beneath the owned output for independent
comparison. Reflowing reexport metadata preserves every exported name and funds this integration.

At that checkpoint the actual source-bound owning invocation passed eleven independent checks, including the seven real
native returns, all three complete frames, source closure, exact authority subset and complete image
buffers. It then returned the deliberate unqualified refusal rather than issuing readiness. Two catalogue
weakenings of the actual selected production source now execute through that same factory. The independent
oracle observes exactly three attributed red rows for the clean/mutant image comparison and two for the
closing-image comparison. Twenty comparisons pass across those controls, including normal red completion
at exit one, complete 996-name frames, stable target plans, changed full suite-image bytes and source closure.
These are qualification controls; they add no mutant to the finite three-case phase matrix.

The authority path also retains its owned source root on unexpected propagation. An actual supplied Cabal
boundary forwarded a successful real target build, then removed its private selected-configuration copy.
Six independent checks observed the original missing-file cause in the private `NativeStopped` carrier,
retained source, the known real success and absence of normal completion artifacts. This direct diagnostic
observes propagation to its caller; it does not itself execute the outer gate's prefix finisher or mint a
phase receipt. Known semantic refusals still remove their owned source copy.

At that checkpoint the counted kernel was twenty files and 3,347 lines under its unchanged 3,353-line ratchet. The new
public diagnostic was the only added Core export; all seven existing public compatibility
bodies remain exact. Renderer reflow funds the change without moving validation policy out of the kernel.
The final seed comparison occupies its own line so the existing first-comparison catalogue operator can select it.
The gate specification is unchanged. That framed Runner profile owned the explicit 996-name extension;
its ordinary judgments remain separate from completion bookkeeping.

The retained transcript producer now exercises the actual public decoder with 81 supplied inputs;
the independent oracle declares its expectations separately and adds complete discovery and field-locus
checks. All 83 checks passed. The data-only `inspectOracleTranscript` API delegates to the shipped normal,
inventory and missing-input classifiers and grants no native, readiness or gate authority. The complete
`runner.full.v2` profile now has 1,079 judgments, including the original 783, 213 finite-image checks and
83 transcript checks. Its unchanged-name authority projection has 355 judgments.

Three independently specified source weakenings execute through the actual owning factory: weakening
summary agreement produces exactly two attributed red rows, weakening the normal native-terminal check
produces three, and weakening the probe native-terminal check produces one. All 39 independent comparisons
passed, including complete normal red frames at exit one, unchanged full namespaces, source and plan
bindings, changed suite-image bytes and qualification refusal. Re-executing each retained exact subject
image through the supplied-transcript mode independently lifted its refusal to those precise failures.
These controls add no case to the finite three-mutant phase matrix.

After those controls, the final deliberate unqualified refusal was removed and the implemented factory
was declared available. A fresh source-bound owning run constructed readiness and passed eleven
independent checks over its seven real native returns, three complete frames, exact 355-row projection,
full image buffers and source closure. Its diagnostic still refused the other missing Phase-0 bindings;
that single-analyzer result supplies no complete phase pass. At that checkpoint the counted kernel was twenty files and
3,351 lines under the unchanged 3,353-line cap. All seven public compatibility bodies remain exact.

The actual outer `runGate` interruption control also passed all eight independent checks. Its supplied
Cabal boundary forwarded a successful real target build and removed only its private selected-config
copy. The controller retained that known successful parent return, propagated the original closing-read
`IOException`, wrote exactly one stopped prefix under the owning source root and retained both owned
roots. No clean, seed or normal-completion work followed. The independent reader checks the retained
native tuple and latest closing-read step; quoted compiler output cannot supply the terminal assertion.
This control records no phase evidence. At that checkpoint complete Phase-0 preview and separate
acceptance were still required.

The subsequent integrated preview retained green authority, correspondence, custody, status and freshness
ledgers, but its kernel oracle refused an absent subject-output file. The new owning integration had moved
that write after oracle execution for the older non-behavioral paths. The candidate was stopped after this
observed failure, with its owned native process group terminated; it supplied no complete gate pass.
Re-executing the retained exact oracle against the same retained observations after the output file existed
passed all ten kernel checks. The repair writes non-behavioral subject output before invoking its oracle
and preserves behavioral output handling. At that checkpoint the kernel was twenty files and 3,352 lines under the
unchanged 3,353-line cap. A fresh complete preview and separate acceptance were then required.

The repaired complete preview then passed all eighteen gate rows with exit zero and minted nothing.
Its distinct acceptance completed a green candidate but refused publication with `ARCHIVE-ORACLE-ABSENT`:
the archive selector still expected the former Cabal `run` arguments, while the controller now invokes
the observed images directly. All protected plan fields and all 638 historical archive files remained
unchanged. Publication now selects the exact ordinary prefixes from the retained completion contexts,
preserving the existing transcript cardinality and ordering; it does not infer a transcript from argv.
Preview also requires those archive evidence values to be formable, so a missing export is reported
before a later acceptance attempt. This repair adds no public API or gate-specification change. The
counted kernel was twenty files and 3,353 lines at the unchanged cap. The subsequent complete preview
passed all eighteen rows and the archive-evidence check. Its distinct acceptance published the immutable
bundle linked above and applied only the verifier's Phase-0 status projection. The lifecycle/governance
amendment now requires the replay described above before Phase 1's fresh gates.
Later-owned oracle cases remain deferred to their own gates under
[gate integrity §M.4](development_plan_gate_integrity.md#m4-harness-qualification-precedes-every-candidate).
Historical accepted and reset bundles remain immutable evidence of their own executions. The reset
withdrew older reuse; the repaired owning acceptance and its required replay supply no successor pass.

[DL-0025](../documents/decision_log.md#dl-0025--native-version-checks-replace-toolchain-pins-before-the-dsl-barrier)
owns native GHCup/GHC version admission, and
[DL-0028](../documents/decision_log.md#dl-0028--hardware-boundaries-follow-the-dsl-barrier-role)
owns the role-based hardware barrier. Reopening and fresh validation follow
[the phase model](development_plan_phase_model.md#n-reopening-and-amending-a-phase).
No status or receipt line is edited by hand.

At the 2026-10-27 toolchain-repair checkpoint, a later phase's complete preview exposed one unclassified
compiler-negative, two shortened CLI judgment lists and a fixture-copy failure under changed discovery.
The hardware-free repair retained complete independent namespaces, source-bound native observations and
actual image checks. A fresh 135-row control, the actual compiler-negative and nine missing/mismatched
evidence negatives passed their focused checks. Three changed toolchain subjects produced complete
135-row specific-red frames with unchanged source and stable, changed suite images. The generic archive
projection preserves its full text through a token-dictionary/gzip/hex envelope for large diagnostic fields;
five checks re-derived every retained byte and reduced the earlier full projection to 15,294,382 bytes,
below the unchanged 16 MiB record limit. Preview also enforces that publication bound. These are component
observations, not another owning gate pass. The changed verifier, build metadata and plan prose require a
fresh complete Phase-0 replay before the next complete Phase-1 preview and separate acceptance.

## Phase Summary

Phase 0 establishes a finite root from which the numbered plan can validate in strict numerical order. Its
subject is the governance surface, the standalone documentation checker, the gate-specification library, the
generic runner, the retained custody core, the mechanical transition commands, and the three-case bootstrap
mutation seed. Every executable decision and independent expectation is Haskell. Python under `pb/**` is
inspected as source but is not used as validation transport.

`GenesisTrust` is the explicit assumption that version-compatible native GHCup and GHC execute correctly.
Its admission is a version check, with no archive, signature, executable digest, prepared input directory,
operating-system, CPU-architecture, device, or privileged-host requirement. It is not a theorem proved by
the executable those tools compile. Cabal is an available build tool. Tool paths and reported versions are
observations; source and receipt hashes retain their separate custody role
([DL-0025](../documents/decision_log.md#dl-0025--native-version-checks-replace-toolchain-pins-before-the-dsl-barrier)).

The validator is specified by the [gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md):
one generic runner consumes one typed `GateSpec` per phase, holds every verdict, generates every mutant, and
records the kernel line count against a ratchet. The agent command `preview` mints nothing; agent-run
`accept` applies exactly one phase's status patch and publishes its immutable bundle. The contract below
specifies that machinery. Earlier accepted runs and replays remain historical observations. The new
complete owning acceptance is recorded above, separately from the nongate reset and focused components.
DL-0040's lifecycle and governance amendment requires complete Phase-0 replay before the fresh successor
gates; the owning pass does not supply those later results.

Numerical order governs gate execution, evidence, and status. It does not prohibit implementation of a later
`Substrate: none` phase after that phase has an exact typed contract and separately authored oracle. Such work
cannot validate, mint candidate evidence, use `pb`, consume an absent predecessor, or touch live or hardware
resources before the validation frontier reaches it.

**Phase scope:** Build and validate the governance seed, the finite bootstrap seed, and the generation-2 validator; split immediately if a requirement needs native tool installation, compiler semantic analysis, product behavior, or live infrastructure.
**Substrate:** `none`
**Lane:** `none`
**Register:** —
**Depends on:** genesis
**Forward-deferred:** version-checked native toolchain selection, with publisher identity unverified — [Phase 1](phase_01_toolchain_spike.md) `toolchain_spike` / `LTD-BOOT-001`; compiler-backed source closure — [Phase 2](phase_02_repository_layout_conformance.md) `repository_layout_conformance` / `LTD-SRC-000`, `LTD-SRC-008`; the spine fact through the shipped binary — [Phase 3](phase_03_typed_spine.md) `typed_spine` / `LTD-DSL-001`
**Gate:** `pb validate phase 00`; see [Gate integrity](#gate-integrity).

### Gate specification

The compiled specification the runner executes, rendered by `amoebius-validate spec phase 00`; the
documentation checker refuses this document when the block and the compiled value differ.

```gate-spec
capability: documentation_suite
role: seed
claim: For one snapshot, the standalone documentation checker reports zero findings on the governed corpus and the named finding on each rendered negative; the three bootstrap predicate mutants are judged by the independent driver; the custody probes pass; the hygiene row is green at the recorded cap; the generation-2 seed is content-addressed and agent-recorded with an immutable accepted bundle.
subjects: Amoebius.Validation.BootstrapPredicate, Amoebius.Doc.Check, Amoebius.Validation.Runner, Amoebius.Validation.Custody
suite: plan-decisions-suite
oracle: oracle-doc
positive: clean-predicate | input=Amoebius.Validation.BootstrapPredicate | expected=silent ExitSuccess
negative: digest-equality-bypass | input=bootstrapDigestMatches | tag=digest-equality-bypass | stage=predicate
negative: snapshot-freshness-bypass | input=bootstrapSnapshotMatches | tag=snapshot-freshness-bypass | stage=predicate
negative: bootstrap-path-bypass | input=bootstrapInputPathAllowed | tag=bootstrap-path-bypass | stage=predicate
positive: store-seed-roundtrip | input=SeedRecord | expected=equal
positive: store-receipt-roundtrip | input=Receipt | expected=equal
negative: store-tampered-receipt | input=receipt payload | tag=record digest does not match its sidecar | stage=custody
positive: receipt-reproducible-digest-stable | input=candidate rows | expected=same digest
negative: preflight-status-surface-dirty | input=surface digest | tag=StatusSurfaceDirty | stage=preflight
negative: preflight-predecessor-not-reproduced | input=receipt digest | tag=PredecessorNotReproduced | stage=preflight
mutants: stages= per-module=8 cap=40 kill-ratio=3/5
substrate: none
seed: predicates=clean-predicate,digest-equality-bypass,snapshot-freshness-bypass,bootstrap-path-bypass | custody=store-seed-roundtrip,store-receipt-roundtrip,store-tampered-receipt,receipt-reproducible-digest-stable,preflight-status-surface-dirty,preflight-predecessor-not-reproduced
```

### GenesisTrust version assumption

Admission checks GHCup and GHC against `Amoebius.Toolchain.Versions`: currently GHCup >=0.1.50.2 and <0.3,
and GHC 9.12.4. The version report must parse unambiguously and its command must succeed.
No fixed compiler/package-tool bytes, manifests, signatures, Linux host, or x86_64 architecture are required.
Native installed tool paths are read-only inputs, not tracked source or generated output. The compiler's
semantic correctness and publisher identity remain assumptions. This policy supersedes the seven-file
bootstrap contract under [DL-0025](../documents/decision_log.md#dl-0025--native-version-checks-replace-toolchain-pins-before-the-dsl-barrier); prior receipts retain their historical scope.

### Finite Phase-0 exit contract

This checklist is the complete exit boundary. New hardening that is not necessary to falsify one of these
items is assigned to its numbered owner instead of extending Phase 0.

- Admit certification generation 2 as the content address of the verifier, entered by the first `accept` under
  [DL-0007](../documents/decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel),
  under the custody boundary in [§M.0](development_plan_gate_integrity.md#m0-accepted-baseline-and-certification-generation).
  Generation-1 stores are archived, never deleted, and supply no authority.
- Check the native GHCup and GHC versions and record their selected paths, while making no
  publisher-authentication, compiler-proof, or platform-specific claim.
- Run the standalone documentation checker over the governed corpus and over a runner-rendered corpus of
  negatives; report zero findings on the corpus and the named finding on each negative.
- Reconcile the checker with the fifty-six-phase plan: the domain, tracker cardinality, identity-table
  cardinality, semantic registry, resource registry, and Phase 50's predecessor edge are derived from the
  compiled phase-identity table, so the expected findings recorded in
  [DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice) reach zero.
- Verify the frozen baseline and the decision-log structure; refuse a frozen body change without an entry.
- Run the clean bootstrap predicate and exactly three changed-source cases serially; clean must be silent
  and successful, while each mutant must return `ExitFailure 1`, empty stdout, and its exact case-label stderr.
- Observe the six compiled custody controls through the independently authored runner oracle: seed-record
  roundtrip, receipt roundtrip, tampered-receipt refusal, stable reproducible digest, dirty-status refusal,
  and missing-predecessor refusal. The tracked archive has separate exact-read, tamper, missing-file, and
  symlink controls ([DL-0018](../documents/decision_log.md#dl-0018--plan-claims-follow-the-keyless-gates-observed-scope)).
- Record the kernel hygiene row: line count at or below the ratchet, no conditional compilation, no `*Run*`
  module, no phase-number literal, one phase table, one definition per vocabulary type.
- Refuse `preview` from minting anything; allow agent-run `accept` only after the complete qualified gate.
- Observe that the compiled legacy due-count for Phase 0 covers exactly the validator rows named in the
  `Legacy closure` cell below and nothing product-facing.
- Produce one complete qualified candidate whose required rows pass, then record it with `accept`.

## Gate integrity

**Contract check**: BOUND — certification generation 2, the protected accepted baseline, the authenticated
phase receipt, and the closure-based compatibility decision are Haskell-owned inputs. Execution evidence
remains phase-local and cannot be supplied by this prose.

An earlier current-verifier replay returned red for Oracle, Positive controls, Paired negatives, Mutants, Challenge,
Qualification, Legacy closure, and Pass criterion. The verifier published replay void markers for the affected
recorded frontier; the existing Done lines remain until a successful replay or verifier reset. The underlying
failures need diagnosis and correction before any successor gate can proceed.
The runner suite subsequently exposed a stale synthetic Phase 3 subject closure and an oracle executable
inventory that omitted the wire-preparation helper. After correcting both, the standalone runner and its
independent oracle completed 1,082 rows green. This was a component diagnostic, not a phase pass.
The source-bound authority qualification subsequently completed 355 independent rows green with matching
opening and closing images. Its isolated command reported the other unsupplied phase qualifications as
unavailable, so it is not a phase pass.
After the fixture and oracle repairs, a second complete replay returned red only for Legacy closure and Pass
criterion. The verifier again left the predecessor voided; the outstanding qualification must be isolated and
corrected before another replay.
The kernel-shape qualification was still anchored to the old expanded `renderVerdict` line, which no longer
exists after the kernel reduction. Its paired phase-literal control and independent source expectation now
target the current implementation. The source-bound kernel qualification passed all ten independent rows.
A subsequent complete Phase-0 replay passed and refreshed the receipt above; Phase 0 also reproduced during
the ordered replay through Phase 1. That Phase-1 replay returned red for Mutants, Qualification, and Pass
criterion. Later verifier and plan changes require fresh ordered reproduction before successor reuse.

| Key | Contract |
|---|---|
| `Claim` | For one exact source snapshot, the standalone documentation checker reports zero findings on the governed corpus and the named finding on each rendered negative; the three bootstrap mutants are judged by the independent driver; the six custody controls pass; the kernel hygiene row is green at the recorded ratchet; the generation-2 seed is content-addressed and agent-recorded with an immutable accepted bundle. Toolchain reproducibility, source closure, product, and live-resource claims are excluded ([DL-0018](../documents/decision_log.md#dl-0018--plan-claims-follow-the-keyless-gates-observed-scope)). |
| `Subject` | The documentation checker under `src/doc-check/**`, the gate-specification library under `src/gate-spec/**`, the plan-decisions library under `src/plan-decisions/**`, the retained custody core, and the runner under `src/validation-kernel/**`. No caller-authored snapshot, digest, row result, predecessor, or status projection can substitute for an acquired value. |
| `Command` | Future public spelling is `pb validate phase 00`, but `pb` is inadmissible before `BOOTSTRAP_HANDOFF`. The agent runs the shipped verifier directly as `amoebius-validate preview phase 00`, which mints nothing, then `amoebius-validate accept --phase 00`, which records the reproducible receipt and applies one phase's status patch. The seed hook compiles and runs the three-case predicate matrix serially with `-j1`. |
| `Oracle` | `test/oracle/doc/Main.hs` prints the expected finding ledger from literals and imports no product or validator module. Acquired `test/validation-kernel/BootstrapMutationDriver.hs` independently states the clean-plus-three predicate expectations. `test/oracle/runner/Main.hs` independently judges the record, preflight, and archive observations against its own literals. |
| `Positive controls` | The governed corpus; the clean predicate; the three positive custody controls and accepted archive roundtrip; a frozen baseline that matches the tree; a decision log whose entries are well-formed and strictly increasing. |
| `Paired negatives` | Rendered documentation negatives: broken link, stale backlink, missing status line, non-frontier status vector, unauthorised frozen edit, uncited module claim, gate-specification block mismatch, decision-log order. The three predicate mutants. Tampered-receipt, dirty-status, missing-predecessor, and archived-evidence tamper/missing/symlink refusals. Each is refused with its exact finding or case label at its exact locus. |
| `Mutants` | The finite seed protocol in §M.4 runs the clean predicate and exactly three changed-source predicate cases serially. Each mutant requires its exact independent rejection. The owning legacy qualifications separately exercise their canonical production weakenings; the non-seed generated-mutant policy begins at its later owner. |
| `Discovery` | The governed path inventory is compared two-way with the frozen baseline; the package description's stanza module map is compared two-way with the subjects named above; empty discovery refuses. |
| `Challenge` | The runner renders the negative corpus beneath `.build/docs/**` after the run starts, with a nonce in each negative's path; the checker's finding ledger must carry that nonce. |
| `Observer` | `ProcessObserver` over the checker, the predicate binaries, and the runner-area suite: executable identity, argv, complete output, and exit are runner-captured; no subject log is trusted. |
| `Authority/bypass` | No `sudo`, issuer key, or agent-marker tripwire is required. `preview` cannot record status or publish an accepted bundle; `accept` runs the same complete gate and applies one bounded status patch. Direct record forgery, candidate-selected baselines, and altered predecessor evidence must refuse ([DL-0018](../documents/decision_log.md#dl-0018--plan-claims-follow-the-keyless-gates-observed-scope)). |
| `Freshness` | The verifier digest equals the seed's; opening and closing source identities are equal; the negative corpus is rendered fresh under a unique run root. |
| `Qualification` | The eight owning legacy factories and the captured-bootstrap structural factory run serially against the same acquired source, followed by the finite three-case predicate matrix and the clean candidate. Missing qualification, unexpected observations, wrong source or scope, and incomplete discovery fail the gate. |
| `Cleanroom` | All generated material lives beneath one unique `.build/runs/phase-00/**` leaf, which must be absent afterward; the kernel line count is recorded as the ratchet for the next accept. |
| `Legacy closure` | `LTD-VAL-001`, `LTD-VAL-002`, `LTD-VAL-003`, `LTD-VAL-004`, `LTD-VAL-006`, `LTD-KRN-001`, `LTD-KRN-002`, and `LTD-KRN-003` close here through the compiled inventory; the due-count for every other identifier is zero. The Markdown register is reader-facing only. |
| `Predecessor` | `genesis` means the explicit non-numbered `GenesisTrust`/`BootstrapRoot`; there is no prior numbered phase and no synthetic Phase -1 result. |
| `Residue` | Phase-1 toolchain provenance, Phase-2 source closure, every product claim, and every hardware claim remain explicit typed limitations outside this claim. |
| `Pass criterion` | `qualified-gate-pass` — every required Phase-0 row succeeds in one serial run for the same source and `GenesisTrust` identities, and `accept` records it. |

## Doctrine adopted

- [`documentation_standards.md` §1 — philosophy](../documents/documentation_standards.md#1-philosophy) — one documentary authority, closed structural facts, and reconciled links.
- [`documentation_standards.md` §6 — honesty](../documents/documentation_standards.md#6-honesty-the-proventestedassumed-discipline) — the three-mood rule this checker enforces.
- [`documentation_standards.md` §17 — the doctrine freeze](../documents/documentation_standards.md#17-the-doctrine-freeze) — the frozen set and its baseline.
- [`gate_runner_doctrine.md` §2 — the gate-specification vocabulary](../documents/engineering/gate_runner_doctrine.md#2-the-gate-specification-vocabulary) — the typed specification every phase renders.
- [`gate_runner_doctrine.md` §6 — commands, generations, and receipts](../documents/engineering/gate_runner_doctrine.md#6-commands-generations-and-receipts) — `preview`, `accept`, `replay`, `reset`, and `demo`.
- [`repository_layout_doctrine.md` §1 — classification rule](../documents/engineering/repository_layout_doctrine.md#1-classification-rule) — Haskell behavioral source and the bounded `pb/**` exception.
- [`validation_frame_doctrine.md` §1 — native Haskell validation](../documents/engineering/validation_frame_doctrine.md#1-native-haskell-is-the-validation-environment) — the finite seed and explicit exclusions.
- [`testing_spoof_resistance.md` §12 — spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence) — independent expectations and changed-source witnesses.
- [`development_plan_gate_integrity.md` §M.3 — mutants must prove that they changed the subject](development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject) — runner-generated mutants and the kill ratio.

## Sprints

## Sprint 0.1: Governance surface ✅

**Status**: Done
**Implementation**: `AGENTS.md`, `documents/decision_log.md`, `documents/documentation_standards.md`, `src/plan-decisions/Amoebius/Plan/Decisions.hs`, `src/plan-decisions/Amoebius/Plan/PhaseIdentity.hs`, `src/plan-decisions/Amoebius/Plan/Legacy.hs`, `src/validation-kernel/Amoebius/Validation/PolicyContract/Internal.hs`, and `src/plan-decisions/Amoebius/Plan/StatusFrontier.hs`
**Blocked by**: `genesis`
**Independent Validation**: The frozen baseline that matches the governed corpus, the strictly ordered decision-log entries, the fifty-six-row phase-identity table, and the role-named policy contract are the positive control. A frozen body change without an entry, an entry with a reused identifier, a table with a gap-crossing predecessor, and an ordinal literal in the policy contract are paired negatives refused by name. Generated mutants in `Amoebius.Plan.Decisions` are killed by the doc-check oracle.
**Oracle**: `test/oracle/doc/Main.hs` states the expected baseline rows, entry identifiers, and table cardinality from literals; it imports no plan-decisions module.
**Legacy IDs**: none
**Docs to update**: `AGENTS.md`, `documents/documentation_standards.md`, and `documents/decision_log.md`

### Objective

Make the governance surface executable: one frozen set with a baseline, one decision log with a checked entry
contract, one phase-identity table that resolves every role by capability, and a status frontier that is aware
of the reserved gap.

### Deliverables

- `Amoebius.Plan.Decisions` with the frozen path list and baseline rows `(path, digest, DecisionId)`.
- `Amoebius.Plan.PhaseIdentity` with fifty-six rows and role resolution for `DSL_BARRIER`, `BOOTSTRAP_HANDOFF`, `HOST_ENSURE`, and `FIRST_HARDWARE`.
- `Amoebius.Plan.Legacy` with the closed `LegacyId` enumeration, owner-by-capability map and opaque lifecycle/scope/analyzer/case declarations, including the `LTD-KRN-*`, `LTD-DSL-*`, `LTD-LIB-*`, `LTD-UI-*`, and `LTD-HELPER-*` families.
- A policy contract that names roles, never ordinals.
- A status frontier that treats table position, not ordinal adjacency, as the predecessor relation.

### Validation

Compare independently authored expected baseline rows, entry identifiers, and table rows with the acquired
values. Refuse a one-row baseline change without an entry, a duplicate identifier, and an ordinal literal at
their exact loci.

### Remaining Work

The qualified owning image/completion repair is recorded under [Phase Status](#phase-status) and
[DL-0042](../documents/decision_log.md#dl-0042--qualified-image-and-completion-custody-retires-runner-authority).
Preserve this sprint's independent expectations and inherited guards. Current reuse requires a compatible
receipt and complete replay for affected source or governance; historical component observations below
do not replace that replay or qualify a successor gate.

At the historical DL-0040 checkpoint, the complete owning acceptance recorded under [Phase Status](#phase-status) was recorded as discharging this sprint's
paired negatives through the complete Phase-0 specification owned by
[Sprint 0.7](#sprint-07-phase-0-gate-specification-first-generation-and-receipt-bearing-reset-). A plan-decisions
projection and its oracle alone remain component diagnostics. At that checkpoint, the DL-0040 amendment required complete
Phase-0 replay before successor gates. The frozen baseline is re-projected from the governed corpus in the
same change that lands it, so the digest rows never lag the bytes they freeze.

## Sprint 0.2: Checker reconciliation ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/Runner.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`, `src/doc-check/Amoebius/Doc/Governance.hs`, `src/plan-decisions/Amoebius/Plan/PhaseIdentity.hs`, `test/runner/Main.hs`, `test/runner/LegacyAudit.hs`, `test/oracle/runner/Main.hs`, and `test/oracle/runner/LegacyAudit.hs`
**Blocked by**: Sprint 0.1
**Independent Validation**: The reconciled checker reports zero findings over the fifty-six-phase plan; the expected findings recorded in [DL-0008](../documents/decision_log.md#dl-0008--plan-re-sequence-into-a-vertical-slice) are paired negatives. The five canonical `LTD-VAL-002` pairs exercise document/specification correspondence, role binding, render-equivalent argument lists, shipped-subject membership and the reserved phase gap. Each weakened production check must produce its exact independent red rows and qualification refusal, with changed source and image identities and no retained build-source tree. At the component checkpoint, integrated legacy closure and phase acceptance remained outstanding.
**Oracle**: `test/oracle/doc/Main.hs` states the documentation findings from literals; `test/oracle/runner/Main.hs` and `test/oracle/runner/LegacyAudit.hs` independently state the native correspondence and evidence-binding expectations and import no product module.
**Legacy IDs**: `LTD-VAL-002` — structural contract relation, owned here
**Docs to update**: `DEVELOPMENT_PLAN/development_plan_standards.md` and `DEVELOPMENT_PLAN/development_plan_phase_model.md`

### Objective

Derive every ordinal-bearing check from the compiled phase-identity table so that the reserved gap, the
fifty-six-row tracker, capability-keyed gate registrations, and Phase 50's predecessor edge are correct
without a second ordinal authority. The selected candidate binds its own semantics; later-owned gaps do not
require implementing later phases before Phase 0.

### Deliverables

- Domain, tracker cardinality, identity cardinality, and predecessor adjacency derived from the table.
- The capability-keyed `GateSpec` registry, with missing selected specifications refused rather than replaced by generation-1 placeholders.
- One resolver for phase identity, role, capability and smart-constructor checks, shared by documentation projection, specification rendering, acceptance and replay.
- The receipt domain upper bound derived from the table.

### Validation

Run the checker over the plan and require zero findings. Re-insert each retired literal in turn and require
the named finding at the named locus.

### Remaining Work

The qualified owning image/completion repair is recorded under [Phase Status](#phase-status) and
[DL-0042](../documents/decision_log.md#dl-0042--qualified-image-and-completion-custody-retires-runner-authority).
Preserve this sprint's independent expectations and inherited guards. Current reuse requires a compatible
receipt and complete replay for affected source or governance; historical component observations below
do not replace that replay or qualify a successor gate.

The generation-1 semantic-registry modules and their retired-literal component suites are absent from the
current source tree. They are not retained placeholders and must not be recreated: the compiled phase table
and `GateSpec` registry supply their generation-2 replacement under
[DL-0007](../documents/decision_log.md#dl-0007--certification-generation-2-replaces-the-validation-kernel).
Historical correspondence checkpoint: the following component observations describe their recorded source
and do not replace the current complete replay requirement. The native contract-correspondence factory built the
exact captured source and its independent oracle.
Its eighteen checks cover the five canonical pairs, the actual snapshot's compiled/documented contract
projection, Phase-0 subject admission, and preflight refusal before candidate creation. The runner compares
the supplied `GateSpec` with the canonical typed value and checks its role. Distinct command argument lists
can render identically; the render digest therefore cannot substitute for this typed comparison.

At that checkpoint all forty-two independent evidence-binding controls passed. Five separately compiled
production weakenings produced only their assigned red rows and were refused qualification. The controls bind the complete source
rewrite, changed executable bytes, unchanged copied inputs, source-tree teardown, owner, scope and source
identity; missing, duplicated, forged and other-analyzer evidence refuse. The general qualification API
replaces the four forwarding wrappers, and a behavioral zero requires its opaque source-bound result.
An initial audit accidentally repeated source scans; its incomplete output supplies no evidence. The
corrected implementation shares the observations, and the complete native matrix and audit were rerun in
a fresh directory. At that checkpoint the validator was 3,355 lines against the accepted 3,357-line cap.
The full runner regression following that repair passed all 610 independent rows.

These were component qualifications. At that checkpoint the complete Phase-0 candidate still needed to
execute and retain every required analyzer, join the source-bound legacy observations, and pass `preview`
and `accept`. No `LTD-VAL-002` lifecycle transition or phase receipt follows from the component result.

## Sprint 0.3: Documentation checker extraction ✅

**Status**: Done
**Implementation**: `src/doc-check/Amoebius/Doc/Check.hs`, `src/doc-check/Amoebius/Doc/Governance.hs`, `src/doc-check/Amoebius/Doc/Phase.hs`, `src/doc-check/Amoebius/Doc/Render.hs`, `src/doc-check/Amoebius/Doc/Types.hs`, `src/plan-decisions/Amoebius/Plan/StatusFrontier.hs`, and `app/amoebius-validate/Main.hs`
**Blocked by**: Sprint 0.2
**Independent Validation**: The standalone checker over the governed corpus is the positive control; each runner-rendered negative is a paired negative refused by its named finding. The new checks — decision-log structure, frozen baseline, three-mood honesty under the scope [DL-0011](../documents/decision_log.md#dl-0011--the-honesty-rule-scope-and-trigger) fixes, gate-specification block equality, and the status vector — each have a rendered negative judged by the oracle from its own literals; the paragraph-spanning sentence measurement stays an observation of the prose budget and has no negative. The independent oracle judges the named findings from all nine rendered corpus perturbations; the finite seed separately runs its clean control and exactly three generated bypasses in `Amoebius.Validation.BootstrapPredicate`, judged by `test/validation-kernel/BootstrapMutationDriver.hs` under [DL-0034](../documents/decision_log.md#dl-0034--phase-0-acceptance-qualifies-the-finite-seed-boundary).
**Oracle**: `test/oracle/doc/Main.hs`; it depends on no `amoebius` library.
**Legacy IDs**: none
**Docs to update**: `documents/documentation_standards.md`

### Objective

Move the documentation checker into a standalone package with no kernel import and no conditional
compilation, and add the governance checks
([DL-0005](../documents/decision_log.md#dl-0005--the-documentation-checker-is-a-standalone-package)).

### Deliverables

- `Amoebius.Doc.Check` with a recorded size cap and a non-zero exit on findings.
- `Amoebius.Doc.Render` rendering the negative corpus beneath `.build/docs/**`.
- `checkDecisionLog`, `checkFrozenDoctrine`, `checkHonestyCitations`, gate-specification block equality, and the status-vector check.

### Validation

Run the standalone checker over the corpus and over each rendered negative; require zero findings and the
named finding respectively. Refuse a checker that imports a validator module at the package-description locus.

### Remaining Work

The qualified owning image/completion repair is recorded under [Phase Status](#phase-status) and
[DL-0042](../documents/decision_log.md#dl-0042--qualified-image-and-completion-custody-retires-runner-authority).
Preserve this sprint's independent expectations and inherited guards. Current reuse requires a compatible
receipt and complete replay for affected source or governance; historical component observations below
do not replace that replay or qualify a successor gate.

At the checker-extraction checkpoint, the seven-thousand-line cap across `src/doc-check` depended on the
hygiene row and compiled gate-specification library assigned to
[Sprint 0.4](#sprint-04-gate-specification-and-runner-core-). Before those boundaries were wired, the cap
was only a declared constant and block comparison used the corpus's own blocks. Those were historical
construction dependencies, not current implementation gaps. The initial design assigned generated checker
mutation to the runner rather than this component's corpus ledger.

The current finite seed must observe the hygiene cap, compare every fenced gate block with its compiled
value, retain the corpus ledger and all nine named documentation negatives, and execute its three-predicate
mutation protocol. The component ledger cannot discharge the complete current Phase-0 gate.

## Sprint 0.4: Gate specification and runner core ✅

**Status**: Done
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec.hs`, `src/internal-cabal/Amoebius/Internal/Cabal/ComponentDescription.hs`, `src/internal-process/Amoebius/Internal/Process/EmptyInput.hs`, `src/validation-kernel/Amoebius/Validation/Authority/Core.hs`, `src/validation-kernel/Amoebius/Validation/Runner.hs`, `src/validation-kernel/Amoebius/Validation/Runner/Capture.hs`, `test/runner/Main.hs`, `test/runner/LegacyAudit.hs`, `test/oracle/runner/Main.hs`, `test/oracle/runner/LegacyAudit.hs`, and `test/oracle/runner/NativeApi.hs`
**Blocked by**: Sprint 0.3
**Independent Validation**: A specification whose subjects are inside the executable's closure verifies; a kernel subject, a non-seed specification without a `BinaryFact`, and an oracle stanza with a product dependency are refused by the smart constructor or `verifySpec` at their exact loci. A generated mutant that changes suite bytes is killed; a stillborn mutant is excluded, not counted.
**Oracle**: `test/oracle/runner/Main.hs` states the expected refusals, sampled loci and kill table from literals; `test/oracle/runner/NativeApi.hs` supplies independent native checker fakes, and `test/oracle/runner/LegacyAudit.hs` checks the source changes and evidence bindings.
**Legacy IDs**: `LTD-KRN-001` — per-phase runners replaced by the one runner
**Docs to update**: `documents/engineering/gate_runner_doctrine.md`

### Objective

Implement the gate-specification library and the generic runner specified by the
[gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md).

### Deliverables

- `GateSpec`, `ExactCase`, `MutantPolicy`, `BinaryFact`, `SpineFact`, and `Substrate` with smart constructors.
- `verifySpec`, the clean run, generated mutants, binary and spine perturbation, `ProcessObserver`, the hygiene row, and capture into the eighteen-row candidate.

### Validation

Verify a legal specification and refuse each illegal one by name. Apply each operator to a stage module copy
and require the oracle to refuse the changed bytes at the following stage.

### Remaining Work

The qualified owning image/completion repair is recorded under [Phase Status](#phase-status) and
[DL-0042](../documents/decision_log.md#dl-0042--qualified-image-and-completion-custody-retires-runner-authority).
Preserve this sprint's independent expectations and inherited guards. Current reuse requires a compatible
receipt and complete replay for affected source or governance; historical component observations below
do not replace that replay or qualify a successor gate.

The operator catalogue is fixed at delivery: constant flip, boundary shift, branch swap, field drop, and
list truncation, sampled by a seeded stream so a rerun draws the same loci. The runner's own suite
exercises the constructor refusals, verification against a fixture package description, the loci and the
witness, the kill table, the hygiene row over a fixture tree, and capture. Rebuild-and-judge mutation over
shipped product modules belongs to [Phase 1](phase_01_toolchain_spike.md), the first non-seed gate.
At the earlier generation-1 migration checkpoint, two rows stayed red pending
[Sprint 0.6](#sprint-06-delete-pass-package-rewrite-and-executable-split-): hygiene, because that kernel was
over budget and carried conditional compilation; and authority, because that product executable linked the
validator. Those were historical migration defects. A component diagnostic could observe later stages but
could not mint a green candidate while either row was red
([DL-0012](../documents/decision_log.md#dl-0012--the-hygiene-rows-roots-run-module-pattern-and-run-directory-convention)).

The remaining component records in this section describe earlier implementation checkpoints, including
their then-current counts and outstanding integrations. They supply no current gate pass. The current
finite seed requires every gate row green, source-bound qualification and observed cleanup under the
accepted ratchet; its owning acceptance and current replay requirement are recorded in Sprint 0.5.

Source acquisition now returns an opaque `CapturedSource` from the actual Git inventory and native file
reads. It retains raw bytes, the portable executable flag, confirmed deletion records and the native Git
observations. Failed, empty, malformed, duplicate or partial-root discovery refuses; symlinks and
unreadable inputs cannot become a successful digest. Global Git excludes cannot conceal candidate files.
Only canonical archive paths leave the source identity; the separate archive audit remains required.
Opening and closing acquisition failures are typed runner refusals, and their observed native processes
join the runner's transcript chain. Source identity itself supplies no closure or qualification verdict.

All 63 independent source-custody rows and five native legal/illegal API pairs pass. The API pairs
refuse source constructor/deserialization forgeries, the removed prebuilt-product configuration field,
and construction or deserialization of owning-query qualification evidence.
Disposable local checkouts exercise pending deletions without staging or committing, and source custody
still admits version-compatible native tools without a fixed host, architecture or device. These checks
were component diagnostics. At that checkpoint the full legacy finding/lifecycle join, canonical owner-domain
qualification and integrated source-copy execution were still required before an owning analyzer could
close an ID or the phase could pass.

Source materialization now writes retained bytes and portable executable flags into a fresh destination;
it never reopens a live source path. The runner rechecks the copied specification and hygiene, builds
the product there, and derives mutant, foreign-path and sibling copies from the same capture. Custody no
longer supplies an earlier live-worktree product binary. Copy verification refuses changed inputs,
unexpected paths, symlinks and destination reuse. Generated state is allowed only beneath `.build/**`,
and explicitly captured inputs there remain checked. Confirmed deletion records produce no file.
The native component compiles and runs the captured program after the live program is changed, retains
argv, paths, environment policy and complete process results, and verifies the copy afterward. Its
product-free oracle checks those raw observations against separately authored expectations.
These checks exercise acquisition and copy boundaries; they supply no owning-analyzer qualification
or numbered phase result.

Freshness diagnostics exposed a custody defect: `runFresh` deleted the previous phase run directory
before the runner checked whether its candidate path was fresh. It now preserves that directory and
selects a child path for each attempt. The clock supplies a name only; an occupied path refuses, and
source materialization claims the candidate root directly with an atomic directory creation. Generated
state then stays beneath the copied tree's `.build/**`. Preflight rejects both occupied files and
directories before reaching the unavailable-analyzer refusal.

Before this repair, four of nine new independent freshness controls failed, including direct observation
of the deleted sentinel. At that point all 317 runner rows passed; the fresh counterparts still refuse the missing
analyzers and create no candidate. All 63 source-capture/copy rows also pass, including native compilation
and execution of captured bytes with generated state beneath `.build/**`. The before/after source and
binary observations are component evidence. At that checkpoint, canonical qualification of `LTD-VAL-006`,
the remaining fresh-input cases and complete candidate teardown remained required; those checks closed no
legacy ID or phase.

The canonical fresh-input component now exercises all six required pairs through native capture, copy,
filesystem and entry-point observations. Its baseline exposed two failures for the same missing boundary:
an outside run path was admitted by the path decision and reached the unavailable-analyzer refusal at the
public runner entry. The runner now refuses `RUN-ROOT-OUTSIDE-FRAME` before execution. The decision checks
canonical paths and the existing bounded run-path predicate. Opening/closing source identity also uses
the shared snapshot predicate. Explicit Cabal dependencies and package-qualified imports select the
predicate library rather than compiling an unintended second home-module copy.

All twenty-one native controls pass. They cover fresh and reused destinations, an explicitly captured
input beneath generated state, an authored expected-output artifact, an outside run path, changed source
identities, an old copy checked against the new capture, empty discovery, sentinel preservation and cleanup.
At that checkpoint the kernel was 3,357 lines after redundant comments were consolidated; no validation behavior moved
outside that budget. The complete runner regression passes all 741 independent rows. Serial qualification
of seven production weakenings passes fifty-two independent evidence checks. The changed implementations
fail at the exact stale-copy, ignored-input, authored-output, path-policy, path-entry, replay and empty-discovery
rows. The audit binds complete source rewrites, changed images, row discovery, source-copy cleanup and
owner/source/analyzer identity, and rejects missing, reused, duplicated, forged or other-analyzer evidence.
Those observations supplied no phase receipt or authenticated legacy retirement; the complete phase gate
still needed to collect and qualify every required legacy row at that checkpoint.

Native runner-authority controls reproduced four false passes: a constant-success checker, a failed
subject that printed a success token, an omitted required ledger row and an unavailable probe boundary.
The no-op subject was already refused. The production suite decision now binds the observed subject
exit and spawn results, requires a directly observed native checker to refuse missing subject output,
and checks the declared required row identities. Genuine red oracle ledgers remain available for mutant
attribution; invalid execution cannot supply a valid ledger. The clean checker run remains last in the
transcript so receipt archival selects its result rather than the missing-output probe.

At that checkpoint, all sixteen native component rows passed. The positive subjects and the no-op, failed,
constant-checker, incomplete-checker and unavailable-boundary counterparts are native observations;
the independent oracle owns the checker source literals. They run serially and their generated source,
images and outputs are removed afterward. At that checkpoint the kernel was 3,357 lines after redundant comments
were consolidated. The serial source-weakening qualification passes forty-two independent evidence
checks. An unconditional-green ledger fails all five negative cases; each of the other four weakened
guards fails its assigned negative. The factory refuses all five changed implementations, and the
independent audit checks their exact source rewrites, changed images, complete row discovery, cleanup
and source/analyzer/owner bindings, including absent, reused, duplicated and forged proof. The full runner
regression at that checkpoint passed all 677 independent rows.

The next audit exposed a missing seed binding: its clean-suite call selected only `case:` names and supplied
no required names for the documentation oracle. All forty-one omitted-row cases were accepted; the
independent oracle reported forty-two failures including the empty manifest itself. The shared Haskell
selector now binds all forty-one documentation observations. Ordinal-bearing names resolve through the
compiled phase-identity table. Clean and mutant execution use that selector; no Markdown value supplies
the registry or verdict. The independent oracle owns a separate literal manifest and native checker.
All fifty-nine native authority controls pass after this repair, including each individual omission.
The shipped documentation oracle also passes all forty-one observations on the current corpus and nine
freshly rendered negatives; its emitted row identities exactly match the manifest. The clean documentation
checker reports zero findings, and every negative reports its named finding.
The expanded source-weakening qualification passes forty-seven independent evidence checks. All six
changed implementations fail at their assigned rows, including removal of the seed selector and removal
of the required-row guard. The audit also checks source/image bindings, complete discovery, cleanup and
rejection of missing, forged, reused, duplicate or other-analyzer proof. The complete runner regression
passed all 720 independent rows at that checkpoint. Those component controls supplied no phase receipt or
authenticated legacy retirement; the integrated collector/lifecycle gate was still required.

The read-only `legacy-audit` diagnostic now executes the `LTD-KRN-001` kernel-shape query and the
`LTD-KRN-002` reserved-mutation-syntax query over captured source bytes, reporting the other
unimplemented analyzers explicitly. Its prequalification
audit checks the complete identity/scope inventory, source/analyzer/lifecycle correspondence, finding
bindings and duplicate loci. Missing due analyzers, due findings and Active zeroes outside their owner
refuse; an owner zero still refuses without canonical qualification. Public report values are untrusted
observations and cannot grant a pass. The separate captured-bootstrap row cannot retire the full
bootstrap ID. All 29 independently specified component rows pass, including actual query perturbations
and malformed reports. The shipped diagnostic refuses the real tree without writing status or evidence.
At that checkpoint the numbered gate retained its unconditional eight-analyzer refusal pending complete
qualification and custody.

The kernel query now has a source-bound qualification path. It builds the observed verifier and its
independent oracle from one fresh captured copy, checks the three canonical positive/negative input
pairs and their complete source projections, and requires exact findings at the runner-path, literal
and ratchet loci. Native GHCup/GHC version checks admit the tools; hashes of the generated subject and
oracle identify observed outputs. Hashes of executable bytes before and after execution, raw process
observations and the canonical case identities are retained, and the copied build tree is removed before readiness
returns. The resulting `LegacyQualification` is opaque and supplies no phase pass or lifecycle change.
The qualified-report audit checks correspondence with actual source observations and refuses a
different source, duplicate evidence, forged metadata and fabricated observations. The diagnostic
`legacy-qualify` records no phase receipt. At that checkpoint integration with the complete phase candidate,
qualification of the other due analyzers and the scoped bootstrap check were still required.

All ten native domain-oracle rows and all twenty-seven independent evidence-join controls pass. Three
generated source twins each weaken one real query constraint, rebuild the changed subject, and lift
only that negative's refusal; the qualifying oracle rejects the changed binary at the corresponding
row while its other nine rows remain green. Source and binary differences and teardown are checked.
These are owning-query component controls; the phase's finite three-predicate seed matrix is unchanged.

The mutation-syntax query uses GHC tokens over captured `src/`, `app/` and `test/` Haskell and parses
flag declarations from the captured Cabal description. It observes reserved identifiers, atomic reserved
selector names and conditional-source lines, while comments and quoted module bodies remain data. Its
twenty-seven independent component rows pass over complete source/package projections derived from the
shipped vocabulary and package description, including qualified identifiers, ordinary flags and the
twenty/twenty-one-flag boundary. Duplicate virtual layout tokens are coalesced into one physical finding.
These are syntax observations: complete selector/seam coverage, canonical owning-query qualification,
source-bound evidence issuance and integration were still required at that checkpoint. The numbered gate then refused all eight
unqualified/unintegrated analyzer requirements, and no lifecycle or status changes.

Hygiene now indexes source lines once and shares its repeated budget checks; process observations use
one lossless field projection for both their digest and rendered record. That projection retains argv
boundaries, environment policy and spawn failure, and counts UTF-8 stdout bytes. All nineteen independently
specified projection/digest controls pass. A fresh kernel-query qualification attempt then refused
before building: oracle hygiene misclassified the quoted `"$(literal)"` transport argument as Template
Haskell. Its copied tree was removed. Oracle hygiene now shares the native GHC token reader with the
mutation query. It distinguishes quoted text, nested comments and ordinary dollar operators from
actual pragmas, splices, quotes, conditional-source lines and foreign declarations; unscanned syntax
and opaque compiler options refuse. For an ambiguous single quote, a native AST projection distinguishes
Template Haskell name quotes from promoted types. All 348 runner rows pass, including thirty independently
specified syntax controls and their complete-discovery check. After the AST refinement, all twenty-seven
mutation-query rows and all five native legal/illegal API pairs also pass. After that repair, source-bound kernel-query
qualification passed all ten domain rows and all twenty-seven evidence-join controls, including three
compiled weakening twins. Each twin produces exactly its intended red negative and nine green rows;
source and binary differences and copied-tree teardown are checked. At that checkpoint the validator was 3,357 lines.
Those component results closed no legacy ID, supplied no phase receipt and left the eight required
unqualified or unintegrated analyzer requirements in place at that checkpoint.

Qualification acquisition now shares one native build/capture/teardown path across the kernel-shape
and mutation-source queries. Its opaque result retains the analyzer identity, so evidence for one
query cannot discharge the other; distinct legitimate results may be audited together, while repeated
identities refuse. The mutation path has independently specified canonical symbol, flag and selector
pairs over complete source/package projections. Its oracle reads source as raw UTF-8 bytes, preserving
native line endings in those projections. The generalization passes all 348 runner rows, twenty-seven
mutation-query rows, five native API pairs and twenty-nine report-audit rows. Fresh mutation and kernel
qualification each pass ten domain rows. All thirty-one mutation evidence-join controls pass, including
wrong-analyzer evidence, joint use of distinct qualifications and repeated-identity refusal. Three
compiled source twins each lose exactly their intended negative while preserving nine green rows;
their source and binary differences and qualification-tree teardown are checked. At that checkpoint the validator was
at 3,357 lines. Those were component results only. At that checkpoint broader selector/seam coverage, the
remaining analyzers, the scoped bootstrap query and integration were still required; the numbered gate refused.

Expanded selector controls exposed eight false zeroes in that token-only query: assembled strings,
character lists, aliases, local bindings and bare marker reads; the other thirty-nine checks passed.
The native AST extension now passes sixty-five component rows. It respects language pragmas in the
header, resolves the tested closed string constructions and aliases, and retains the lexical environment
of each definition. Controls cover parameter and local shadowing, `where` closures, self-qualified
references, alias cycles, ordinary data and a multiline CPP-looking decoy before a real selector.
Literal and name payloads are pruned after the relevant expression check. Exact path/content pairs share
pure source analysis within one run; this is neither persisted evidence nor a digest-only verdict cache.

Repeated custody error propagation has been consolidated without removing its refusal checks, and
candidate rendering retains the same bytes. All 348 runner rows, five native API pairs and twenty-nine
report-audit rows pass after these changes. The validator is 3,356 lines against the 3,357-line ratchet.
The canonical selector qualification family now includes the expanded AST forms and independent exact
locus expectations. Its positive/negative pair preserves the complete source projection and requires ten
selector findings across definitions and uses; a single literal finding cannot satisfy it. Its source-bound
run passes all ten domain rows and all thirty-one evidence-join controls. Each of the three compiled
weakenings produces exactly its intended red negative and nine green rows. The selector weakening retains
only the two bare-read findings, which cannot satisfy the ten-locus expectation. Source and binary changes,
qualification-tree teardown and distinct-analyzer evidence binding pass their independent checks; the
cross-analyzer kernel qualification also has ten green rows. The captured kernel at that checkpoint was 3,357 lines. These
component observations close no ID or phase; the numbered gate retains its eight-analyzer refusal and no
status advances.

Oracle admission now retains Cabal build information and rejects unsafe compiler options, enabled
CPP/Template Haskell/quotation extensions, unknown languages/extensions, foreign or generated inputs,
linking settings, build tools and pkg-config dependencies. Conditional branches are combined rather than
selected by the current host, and imported common settings remain visible. All thirty-six independent
metadata controls pass, including ordinary and legacy clean inputs, disabled Template Haskell and clean
conditional/common counterparts. The initial baseline exposed twenty-six admitted unsafe settings; one
additional baseline fixture used a nonexistent Cabal field and supplies no negative evidence. Its replacement
uses supported GHCJS profiling/shared syntax. These controls are included in the normal runner/oracle
projection. All 384 runner-regression rows passed at that metadata-admission checkpoint, with zero
documentation findings and a 3,357-line kernel.

Seventeen further entry/source/setup controls now pass. Admission binds every retained test interface to
its declared entry, requires declared modules to have Haskell source, checks known preprocessor and boot
counterparts, and rejects ambiguous source-directory paths. Alternate entry names and split source
directories are admitted without requiring a decoy `Main.hs` in each directory. Non-executable test
interfaces, non-Simple build types and custom setup declarations refuse. The graph retains interfaces from
all conditional nodes; the shared library-closure traversal and the standard library's first-file search
replace duplicate implementations. All 401 runner-regression rows pass, and documentation checks have
zero findings. At that checkpoint the kernel was 3,356 lines.
Package parsing now refuses every warning except a supported deprecated-field warning. The refusal
carries the typed Cabal warning kind and exact source position; warning prose supplies no behavioral
decision. All twenty-one independent syntax controls pass. The six previously admitted unknown or
ignored inputs now refuse, including fields in conditional and common stanzas and a field unavailable
under the declared Cabal specification. Native parser observations independently confirm each warning;
ordinary metadata, an inert custom field and a known parsed deprecated field remain admissible. The
repository package itself produces no warning. All 422 runner-regression rows pass, and the documentation
checker reports zero findings. At that checkpoint the kernel was 3,357 lines.
Oracle admission now parses every otherwise hygienic discovered Haskell module and rejects imports of
package-owned modules, including qualified, post-qualified, package-qualified, SOURCE and aliased imports.
The same check covers local helpers and rejects an oracle module declaring a package-owned module name.
Malformed source refuses rather than supplying an empty import list. Comments, string literals and external
imports remain admissible. Twenty-nine independent entry/source/setup/import controls pass; the initial
run exposed nine missing refusals. The runner regression had 461 green rows at that checkpoint.

Admission also binds each discovered source to a declared entry or helper, checks its parsed module name,
and refuses multiple providers of the same entry or module across source directories. Eight additional
controls retain implicit `Main`, alternate entry filenames and split directories while rejecting wrong
module names, undeclared files, duplicate providers and misleading module paths. Before this repair, six
invalid cases were admitted; three existing negative cases already refused for other reasons but lacked
the expected undeclared-source diagnostic. All thirty-seven focused controls and 469 runner-regression
rows passed at that checkpoint.

Source discovery, copy verification and archive inventory now share a portable streaming traversal with
fixed limits of 100,000 directory entries and 128 path components per traversal. It rejects links, paths
resolving outside their declared location, non-regular entries, duplicates and invalid entry names. Streams
close on inspection, open, read and limit failures. Copy verification skips only a safe top-level `.build`
directory and still exact-reads captured inputs beneath it; archive inventory still refuses nested empty
directories. The common walker replaces three separate unbounded traversals without growing the kernel
beyond its ratchet. Generation selection also retains its existing behavior after removal of a single-use
enumeration wrapper.

Forty-nine independent traversal controls pass. Link, failure and resource-limit observations are supplied
Haskell values; the new controls need only ordinary native files for their filesystem positive. They check
exact results and boundary call/close counts, including the exact limit, an infinite supplied entry stream,
a budget shared across directories and the precise depth boundary. All 518 runner-regression rows and all
63 existing source-custody diagnostic rows pass.

Oracle admission now retains executable source information and refuses area-directory overlap with
libraries, executables and unrelated or unsafe test components. Matching independent entries in the same
area share their declared entry/helper inventory; product dependencies or unsafe build settings exclude
that grouping. Component boundaries, normalized paths, case variants, default source roots, conditional
branches and common settings are checked without selecting a host. Twenty-six independent isolation
controls pass, including the repository's six oracle executables. The initial twenty-control run exposed
fifteen admitted overlaps and two rejected same-area counterparts.

The duplicate `astcheck-spec` component consumed the DSL oracle's expectation module from its source
directory. It has been removed. Focused `--astcheck` modes on `extensions-suite` and `oracle-extensions`
use the existing producer and independent oracle instead, preserving all forty-three cases and twenty-four
paired controls without changing their inputs or expectations. Their sixty-eight judgments pass; absent
observations produce sixty-eight red rows and a failing exit. All 544 runner-regression rows passed at
that checkpoint.

Repository source and metadata reads now require ordinary files, enforce a 16 MiB per-file limit and
decode text as strict UTF-8. The same reader serves source capture and copy verification, oracle admission,
closure and mutation inputs, seed sources, fact files, status projections and custody records. Executable
images retain their separate custody-read path. Buffers follow the observed file size within the fixed
limit; an EOF check refuses unread growth instead of accepting a truncated prefix. Oracle scan/read failures
become `OracleSourceUnscanned`, metadata read failures become `PackageDescriptionUnparsable`, and gate or
fresh-preflight I/O failures become `SourceCaptureRefused`. Status-surface reads return their failure without
constructing a partial surface. Reader/configuration wrappers were consolidated within the existing kernel
ratchet.

Fifteen independent source-read controls pass, including the exact byte boundary, non-regular files,
invalid UTF-8, missing metadata, source capture, hygiene and all three refusal boundaries. A corrected
baseline exposed six missing refusals. The first three metadata fixtures had no component section and
triggered Cabal's legacy-syntax warning; those observations supplied no byte-limit evidence. Valid sectioned
fixtures replaced them before the baseline was counted. All 559 runner-regression rows and all 63 existing
source-custody rows passed at that checkpoint. These per-file controls supply no canonical analyzer qualification, authenticated
legacy-closure join or phase receipt; that owning execution and lifecycle work was still required at that checkpoint.

Contract projection now fails closed instead of dropping a registered specification when its constructor
refuses. One resolver supplies roles, capability binding and constructor checks to documentation projection,
specification rendering, acceptance and replay. Empty or duplicate registrations, unknown capabilities, mismatched capability fields,
missing binary facts and missing seed facts refuse; domain and role lookups still derive from the compiled
phase-identity table. A fenced phase specification without a compiled registration is now a documentation
finding, including when duplicate fences would otherwise hide it.

The initial twenty-two independent contract controls exposed one red row: the live corpus published
specifications for Phases 7, 8 and 9 without Haskell registrations. Documentation checking reported three
`DOC-GATE-SPEC-PHASE` findings, and the initial full regression had 579 green rows and two red rows. Those
three capabilities are now registered, and their fenced blocks are rendered from the compiled specifications.
The declarations preserve the complete predecessor case set, earlier subject stages, exact new refusal
tags/stages and the `oracle-dsl` boundary; all remain hardware-free. The barrier's rendered/applied comparison
names the compiled manifest, and its operator demonstration requires a recorded operator-authored input
digest under the keyless receipt model, with no signature prerequisite.

Review also exposed a second entry-path defect: documentation projection rejected duplicate registrations
while direct phase resolution accepted the first one. The independent regression reproduced that acceptance
before the repair. Registry integrity now belongs to the shared resolver, so direct resolution refuses the
same duplicate. At that checkpoint, all thirty-three focused contract controls and 592 runner-regression
rows passed, documentation checking reported zero findings, and the validator was 3,357 lines. The later
native correspondence qualification is recorded in Sprint 0.2 above. At that checkpoint complete analyzer
integration and the authenticated lifecycle join remained outstanding; neither the registrations nor their
matching Markdown advanced a phase.

Receipt publication now writes only the canonical tracked archive. The unused, best-effort receipt-cache
writer and permissive cache reader have been removed; generation seed storage remains. Existing custody
controls still exercise the production receipt codec and digest-checked record store directly, including
reset/pass coexistence, exact tamper refusal and restoration. Archive admission and rollback controls remain
in the current regression. This simplification supplies no custody qualification or phase receipt.
At that checkpoint the direct-native Phase-0 preview refused with `LEGACY-ANALYZER-UNAVAILABLE` for all
eight due analyzer integrations. It produced no receipt or status transition; those component results did
not discharge that historical refusal. The owning acceptance and current replay requirement are recorded in Sprint 0.5.

A later component rerun of the runner's source API controls initially failed before its intended boundaries
because the compiler clients did not expose the internal packages needed by the runner's source roots. The
independent harness now supplies those package identities explicitly; its nine legal and illegal API checks
were green. This repairs the component diagnostic and does not reproduce the complete Phase 0 gate.

## Sprint 0.5: Custody core and verifier commands ✅

**Status**: Done
**Implementation**: `src/validation-kernel/Amoebius/Validation/Custody.hs`, `src/validation-kernel/Amoebius/Validation/Custody/Preflight.hs`, `src/validation-kernel/Amoebius/Validation/Runner.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`, `app/amoebius-validate/Main.hs`, `test/runner/Main.hs`, `test/runner/LegacyAudit.hs`, `test/oracle/runner/Main.hs`, and `test/oracle/runner/LegacyAudit.hs`
**Blocked by**: Sprint 0.4
**Independent Validation**: `preview` runs the complete gate and mints nothing; agent-run `accept` applies exactly one phase's patch and publishes its immutable accepted bundle. A missing, altered, or incomplete tracked bundle is refused before predecessor use; distinct observed runs with the same reproducible digest retain distinct bundle addresses. Closure-based chaining keeps a receipt across an edit outside the closure and reopens across an edit inside it ([DL-0016](../documents/decision_log.md#dl-0016--acceptance-and-replay-publish-the-archive-with-the-status-projection)).
**Oracle**: `test/oracle/runner/Main.hs` states the receipt, archive and dependency observations from literals; `test/oracle/runner/LegacyAudit.hs` independently checks the canonical native source changes and evidence bindings. Neither imports a product module.
**Legacy IDs**: `LTD-VAL-003`, `LTD-VAL-004` — receipt authenticity and status authority, owned here
**Docs to update**: `documents/engineering/validation_frame_doctrine.md` and `documents/engineering/gate_runner_doctrine.md`

### Objective

Make every status transition a verifier act with a reproducible receipt and a content-addressed generation
behind it ([DL-0009](../documents/decision_log.md#dl-0009--status-authority-is-one-human-act-per-transition),
([DL-0013](../documents/decision_log.md#dl-0013--validation-authority-is-mechanical-and-receipts-are-reproducible))).

### Deliverables

- Content-addressed generations and immutable accepted bundles under `validation-records/**`.
- Agent-run `preview`, `accept`, `reset`, and `demo` commands.
- The preflight refusals, closure-based predecessor chaining, and refresh as an identity projection.
- Receipt fields: verifier digest, governance digest, `SubjectChangeWitness`, `ResetCause`, `OperatorDemonstration`.

### Validation

Run each command from the agent identity; require the specified success or refusal. Edit a file outside and
then inside the predecessor closure and require the receipt to survive and then reopen. Delete the optional
`.build/**` receipt cache and require the tracked bundle to remain exact-readable. Remove or tamper with a
bundle in a negative test and require predecessor refusal
([DL-0016](../documents/decision_log.md#dl-0016--acceptance-and-replay-publish-the-archive-with-the-status-projection)).

### Remaining Work

The qualified owning image/completion repair is recorded under [Phase Status](#phase-status) and
[DL-0042](../documents/decision_log.md#dl-0042--qualified-image-and-completion-custody-retires-runner-authority).
Preserve this sprint's independent expectations and inherited guards. Current reuse requires a compatible
receipt and complete replay for affected source or governance; historical component observations below
do not replace that replay or qualify a successor gate.

The Phase-2 preview following the completed numerical Phase-0/Phase-1 replay on 2026-10-23 exited 1
before its gate, reporting `PredecessorNotCommitted` and `PREDECESSOR-GATE-UNAVAILABLE`. Recursive custody
compared Phase 0's older whole-status postimage with the later Phase-1 surface. This exposed an unqualified
positive boundary in this sprint's existing same-worktree custody claim. The prior accepted bundles retain
their historical observations; they do not qualify this repair or the new canonical case.

[DL-0039](../documents/decision_log.md#dl-0039--recursive-custody-preserves-accepted-completed-prefixes) reactivated exactly `LTD-VAL-003` with its existing owner,
`receipt-custody` analyzer and three canonical pairs, plus the fourth source-bound pair
`uncommitted-prefix-series`. The new source-bound verifier completed the [reset receipt](../validation-records/generation-d7ecfa4c132f6845/receipts/phase-00-35b097c8a6c5efe44b0d0e0966c92b1e04a3b333fa26fe67086e630733951e26-35c947452b34e28599086c516ec4b4fbc7bbbb34ccc038ef52643625495251b7/receipt.tsv)
on 2026-10-23 at 17:41:25 UTC, naming that product gap and validator gap
`recursive uncommitted predecessor postimage admission`. The receipt records a nongate reset, not a
qualified owner pass; its issued-at value is 17:41:21.759055 UTC.

The focused custody oracle recorded all 67 rows green, and the independent qualification join recorded
52 green evidence-binding checks. All seven changed production subjects produced exactly their assigned
red-row sets, including the old whole-postimage refusal and the bypassed-prefix weakening. These are
component diagnostics over metadata admission and real production weakenings; they supply no `PassedGate`
and do not establish full publisher/recursive-gate integration. Publication-bound own-prefix evidence,
whole-current-postimage anchoring, legacy fallback and every archive/current-closure/full-reproduction guard
remain requirements of every complete gate and predecessor reproduction. The distinct complete owning
acceptance recorded under [Phase Status](#phase-status), rather than these components, qualifies the
reopened binding. [DL-0040](../documents/decision_log.md#dl-0040--qualified-recursive-custody-retires-its-reopened-binding) restores Retired and removes exactly its single active reader row, retaining all four
canonical cases. This amended source and governance require complete Phase-0 replay before a fresh
complete Phase-1 preview and separate acceptance, then the Phase-2 preview and separate acceptance.
The actual successor gates must still exercise their publication and recursive predecessor paths; this
Phase-0 pass supplies no later phase result. No prior toolchain or documentation observation supplies
these new gate results. The component records below describe earlier snapshots.

The current generation-2 custody core contains the accepted archive beneath `validation-records/**`, receipt
records with reproducible digests, the status surface and its one-phase patch with the receipt line, the
preflight decision as a pure function of gathered facts, closure digests and `replay`. The generation-1
supervisor, signed receipt format, root-owned mirror and issuer key are absent from the current source;
they are not an alternative execution path. Generation seeds still use `.build/certification/**`, while
receipt publication and admission use the canonical tracked archive. The replacement is governed by
[Sprint 0.6](#sprint-06-delete-pass-package-rewrite-and-executable-split-) and
[DL-0013](../documents/decision_log.md#dl-0013--validation-authority-is-mechanical-and-receipts-are-reproducible).
`accept` selects the compiled gate specification registered under
[Sprint 0.7](#sprint-07-phase-0-gate-specification-first-generation-and-receipt-bearing-reset-). The preview
at that earlier integration checkpoint refused the eight unqualified analyzer integrations and issued
no receipt. An accepted
phase also turns every paragraph that said it was owed by that phase into an honesty finding, so the agent's
next act after `accept` is to re-mood those paragraphs as observed implementations citing the new receipt,
under a decision-log entry where the paragraph is frozen.

The reproducible-core comparison now consumes the parsed oracle ledger rather than its raw transcript
digest. It binds the process exit, ledger validity and sorted row identities/verdicts; run-local diagnostic
paths, nonces and row ordering do not change it. The raw transcript digest remains in candidate evidence
and the immutable archive. Parsing refuses empty, malformed, duplicate and unknown-verdict rows, and a
malformed ledger cannot supply a mutation kill. Thirty-one independent component assertions pass; the
pre-repair implementation failed eleven of them. The controls also distinguish changed gate verdicts,
specifications, oracle rows, exits and mutant outcomes, stages, locations and operators. These observations
did not discharge `LTD-VAL-003`'s native qualification or the integrated lifecycle join.

At the earlier receipt-custody checkpoint, twenty-nine native controls and forty-two independent
evidence-binding checks passed. Its three canonical pairs rejected the old receipt format, a self-consistent
archive with a foreign verifier, and a predecessor whose actual source closure has changed. Reader and
compatibility verifier checks each have their own pair. The shared compatibility decision binds phase,
capability, receipt identity, verifier, governance, specification and a known current closure; a missing or
sentinel closure cannot be reused as evidence.

The first dependency audit exposed eight missing bindings: suite, oracle, custody-suite, entry-point,
seed-driver, build-metadata, bootstrap-source and documentation edits left the old closure unchanged.
The closure now includes the selected product, suite and oracle source/dependency graph, the native
validation and source-admission inputs, build metadata and bounded bootstrap bytes. The seed's document
corpus is hashed after the existing status projector maps it to a canonical frontier, so a verifier-owned
status/receipt projection preserves that input while a documentation-body edit invalidates it. No
Markdown value supplies product behavior or an expected verdict. Toolchain admission remains native
version checking; these source and receipt hashes serve custody.

At that checkpoint five separately compiled production weakenings were refused at their assigned
independent rows: receipt version, archive verifier, compatibility verifier, production closure and oracle-source coverage. The
evidence checks also cover owner/source binding, forged or absent proof, other-analyzer proof, exact changed
images and source-copy teardown. The kernel at that checkpoint was 3,357 lines; redundant comments were consolidated
without moving validation behavior outside its budget. The earlier eighteen-control, thirty-seven-check
run is a narrower historical diagnostic and supplies no complete dependency-coverage evidence.
The complete runner regression after that dependency repair passed all 639 independent rows.

The native status-authority controls exercise the four canonical `LTD-VAL-004` pairs and the public
`accept` and `preview` refusals on isolated plan fixtures. The first run exposed three failures: a phase
status edit that contradicted the tracker was not reported as `StatusSurfaceDirty` when no local generation
seed existed. Preflight now receives the existing structural-consistency result as an explicit fact and
refuses that contradiction independently of the accepted-postimage comparison. Hardware observation also
requires structural consistency. All twenty-two native controls pass after this repair; refused commands
leave the observed status and accepted archive unchanged, and fixture teardown is checked.
Serial qualification now passes thirty-seven independent evidence-binding checks. Each of the four
separately compiled production weakenings fails exactly its direct-preflight, `accept` and `preview` rows;
the factory refuses it and removes the source copy. The independent audit checks the exact rewrites,
changed images, complete row discovery, owner/source binding and missing, reused, duplicate, forged or
other-analyzer evidence. The kernel at that checkpoint was 3,357 lines. The complete runner regression
after the status-authority repair passes all 661 independent rows.

Those were component results. At that checkpoint the remaining owning analyzers, complete legacy collection,
authenticated lifecycle transitions and the exact current Phase-0 gate were still required. No legacy ID,
sprint or phase closes from these counts; only a complete green gate followed by `accept` records status.

## Sprint 0.6: Delete pass, package rewrite, and executable split ✅

**Status**: Done
**Implementation**: `amoebius.cabal`, `app/amoebius/Main.hs`, `app/amoebius-validate/Main.hs`, `src/cli-delegation/Amoebius/Cli/Delegate.hs`, `test/runner/Main.hs`, `test/runner/Portability.hs`, `test/oracle/runner/Portability.hs`, the parked symbolic/refinement checker APIs, `test/oracle/runner/SolverDemotion.hs`, and the flag-free compile-fail twins beside their legal suites
**Blocked by**: Sprint 0.5
**Independent Validation**: After the pass, the kernel line count is at or below fourteen thousand, no conditional-compilation line remains under `src/`, `app/`, or `test/`, no `*Run*` module remains, the package description declares at most twenty flags, and the product executable's closure contains no validator module. Each is a paired negative reproduced by re-inserting one artefact. The unprotected component suite passes after every family deletion.
**Oracle**: `test/oracle/runner/Main.hs` states the expected hygiene row and closure from literals.
**Legacy IDs**: `LTD-KRN-002`, `LTD-KRN-003`, `LTD-VAL-001`, `LTD-VAL-006` — authored mutant seams, the fake solver as a decision procedure, harness self-measurement, and stale-input acceptance, all owned here
**Docs to update**: `documents/engineering/repository_layout_doctrine.md` and `DEVELOPMENT_PLAN/development_plan_gate_integrity.md`

### Objective

Delete the validator families the runner replaces, one family per serial build, and split the product from
the verifier.

### Deliverables

- Removal of the per-phase runners, the compiler-subject family, the legacy-oracle family, the semantic-contract family, the consumer-graph family, the bootstrap-grammar family, the sabotage corpus, the opacity-attack suites, and every authored conditional-compilation mutant seam.
- A package description of roughly sixty libraries, two executables, and at most twenty flags.
- `amoebius validate` launching the separate verifier with unchanged argv, inherited streams and environment, and its exit status propagated; the bounded bootstrap's exec handoff remains separate.
- A package-description test that refuses any product-to-validator dependency edge.

### Validation

After each family deletion, build serially with `--jobs=1` and run the unprotected component suite. At the
end, require the hygiene row and the closure test to pass.

### Remaining Work

The qualified owning image/completion repair is recorded under [Phase Status](#phase-status) and
[DL-0042](../documents/decision_log.md#dl-0042--qualified-image-and-completion-custody-retires-runner-authority).
Preserve this sprint's independent expectations and inherited guards. Current reuse requires a compatible
receipt and complete replay for affected source or governance; historical component observations below
do not replace that replay or qualify a successor gate.

Historical package-rewrite checkpoint: no receipt was issued during that pass. The retained kernel was the
generation-2 custody core, runner and three-module seed vocabulary; every generation-1 family, its authored
mutant seams and its four hundred suites had been removed, and the package description declared no flag.
The recorded residues included flag-selected compile-fail twins rendered as flag-free Haskell files beside
their legal suites; their compilation-failure judgement remains owned by [Phase 3](phase_03_typed_spine.md).
At that checkpoint the Pulsar client and the fifteen components linking it were held unbuilt pending the
lazily generated transport input assigned to [Phase 1](phase_01_toolchain_spike.md). The historical toolchain
records now describe that phase's bounded probes; maintained-fork compilation remains Phase 67's claim,
not a result of this seed. Packaging defects exposed in never-built stanzas were repaired through declared
dependencies and listed modules, never as source changes. The following component observations retain their checkpoint scope and
supply no current Phase-0 acceptance.

The fake-solver boundary had remained unsound: an arbitrary executable's parsed responses could yield
`Inductive`, `Proved`, or an asserted counterexample. The parked symbolic and refinement APIs now return
explicit `Inconclusive` diagnostics for unadmitted solver responses. The positive proof constructors are
removed; translation, parsing, query execution and raw diagnostic observations remain. The existing seven
symbolic examples and six refinement fixtures now produce bytes for a separate, product-free oracle,
with fresh per-example fake binaries and invocation transcripts. The malformed-expression cases retain
their exact typed refusals, and unsupported or unmapped inputs invoke no solver.

All 74 runtime/transcript oracle rows and both native legal/illegal API pairs pass. Before the repair,
22 runtime rows failed and both API pairs exposed the old boundary. Each forbidden constructor
now fails at the independently named GHC reason and source location. Those were component diagnostics:
at that checkpoint the numbered gate did not consume the parked proof libraries, `LTD-KRN-003` remained
active, and its qualified owning analyzer and authenticated lifecycle join were still required.
The canonical reintroduction driver now materializes fresh source copies for the repaired checkers and
the two false-proof regressions, builds each copy serially and runs the existing runtime and API oracles.
Its twenty independent evidence checks pass, binding the complete source rewrites, changed checker
images, exact failing rows, unchanged copied inputs and source-tree teardown. The repaired baseline has
74 green runtime rows and two green API rows. Each reintroduced defect produces its six required runtime
failures and one API failure, preserving the other 69 green rows. The driver constructs no analyzer
readiness or phase evidence. All 422 normal runner-regression rows pass after this addition. Fake-solver
copies retain the native executable suffix, while transcript names remain stable across that suffix.
The native GHC parser now observes the exact result-type declarations in both captured checker sources.
Ten source controls yield 23 green independent assertions: the existing constructor sets and quoted decoys
are clean; added, renamed or missing constructors produce a finding at the declaration; missing or duplicate
declarations, malformed syntax and absent files refuse observation. Complete input projections, distinct
source identities and teardown are checked. Before implementation all ten observation assertions failed.
That structural observation granted no qualification or retirement authority; the runtime/API evidence and
authenticated lifecycle integration were still required at that checkpoint.
Changed checker snapshots now derive from retained bytes rather than a new Git inventory of each copy.
The bounded rewrite API changes one existing, nondeleted input, preserves every other entry, executable
mode, deletion record and acquisition event, and derives the new source digest itself. Seventeen independent
assertions pass, including equality with a fresh native capture, restored identity, copied-input checks and
refusal of absent, deleted or unchanged targets. Live-file edits after acquisition do not enter the copy.
The reintroduction driver now calls the kernel-owned serial native execution path. The owning qualifier
combines structural source pairs with the clean and changed-checker runtime/API matrix, requires its exact
independent oracle rows, and binds the source snapshot, canonical case identities, observed processes and
unchanged executable images before constructing opaque readiness. Its qualification and audit joins are
now tested on the captured source: all 27 owning-qualifier rows and all 27 independent audit-join assertions
pass. Each of the two compiled query weakenings produces exactly its intended source-negative failure
while the other 26 qualifier rows remain green. The audit join checks source and analyzer identity,
duplicate or missing evidence, forged observations and lifecycle labels, wrong-owner and reused runs,
cross-analyzer binding and copied-tree teardown. All 449 normal runner-regression assertions pass.
Those were component readiness results; candidate integration and the authenticated lifecycle transition
were still required at that checkpoint before the full phase gate could pass.
The scoped bootstrap-source analyzer now uses the shipped Haskell bootstrap grammar over retained bytes;
it never starts Python or `pb`. Opaque readiness carries the compiled scope as well as identity and source,
and later-phase use of captured-bootstrap evidence cannot supply whole-snapshot readiness. All 16
source-qualification rows and 28 independent scope/audit assertions pass on the captured source. The
compiled no-op analyzer fails exactly the five canonical negative rows while its other 11 rows remain
green, and its factory refuses readiness. Borrowing the captured proof at the whole-snapshot owner still
leaves that snapshot unqualified and reports unexpected scope evidence. Source/analyzer swaps, forged
reports, duplicate or missing evidence, wrong-owner and reused runs, and teardown are checked. The normal
runner regression has 449 green assertions. The whole-snapshot source binding remains later-owned, and
runtime handoff remains owned by Phase 50; neither claim is discharged by these component checks.
The parked checkers' three separate audit defects and real decision-procedure admission remain owned by
the [proof-assistant track](later_phases.md#candidate-phase-surgical-proof-assistant-track-emittla-faithfulness--fold-closure).

The documentation checker now uses a portable bracketed directory stream, preserving incremental reads
and the exact directory/total-entry limits. Layout file-status reads use a portable provider and reject
symbolic links explicitly. The repository's unconditional `unix` dependencies and direct POSIX imports
are removed. The product's separate-verifier transport preserves argv, standard streams, working directory,
environment and exit status while waiting for its child; the bootstrap's exec handoff is unchanged.
All twelve transport/discovery controls pass, including sibling preference, PATH fallback, missing-verifier
refusal, Unicode/opaque arguments, environment and stdin/out/err, and the 1,024/1,025-entry boundary.
The layout producer and its independent oracle complete successfully with 1,312 unique green rows;
the runner regression now has 317 green rows. The fake `kubectl` image is copied with the native executable
suffix, and the hostile PATH decoy is generated Haskell, compiled serially and demonstrated executable
before the challenge. These fixtures no longer require a symbolic-link installation or a shell interpreter.
The source model rejects drive, UNC, device and backslash-ambiguous paths; copied inventories retain
logical Git-relative separators. Supplied Windows path/name models establish no live Windows result.
The archive reader now accepts supplied path observations for component checks; its acceptance and replay
callers retain the native path query. Root, bundle and evidence-file link refusals and the exact queried
path sets pass the independent oracle without creating links. Extension-source discovery likewise uses
supplied link observations, with seven ordinary-file cases also checked against native files and all eleven
registry oracle rows green. Native symlink and executable-mode fixtures in the separate source-capture
diagnostic still needed reconciliation at that checkpoint before a complete portability claim. Those were
component diagnostics; the due analyzers and complete phase gate were then unfinished. They supply no
current gate result and do not replace the amended predecessor's complete replay requirement.

## Sprint 0.7: Phase-0 gate specification, first generation, and receipt-bearing reset ✅

**Status**: Done
**Implementation**: `src/gate-spec/Amoebius/Validation/GateSpec/Seed.hs`, `src/gate-spec/Amoebius/Validation/GateSpec/Registry.hs`, `src/validation-kernel/Amoebius/Validation/BootstrapQualification/Internal.hs`, `src/validation-kernel/Amoebius/Validation/Runner.hs`, and `test/validation-kernel/BootstrapMutationDriver.hs`
**Blocked by**: Sprint 0.6
**Independent Validation**: The Phase-0 specification verifies and its fenced block equals the compiled value; the first `accept` enters generation 2 at the verifier's content address; the receipt-bearing reset names `ResetCause { validatorGap = "gates measured the harness", productGap = LTD-DSL-001 }`; a reset without a product gap is refused while any `LTD-DSL-*` row is open. The three predicate cases retain their exact exits and streams. A wiped scratch cache leaves the tracked bundle intact; a missing historical bundle requires a fresh gate run, and a receipt whose digest does not re-derive is void ([DL-0016](../documents/decision_log.md#dl-0016--acceptance-and-replay-publish-the-archive-with-the-status-projection)).
**Oracle**: `test/validation-kernel/BootstrapMutationDriver.hs` for the predicate matrix; `test/oracle/runner/Main.hs` for the specification and reset cases.
**Legacy IDs**: none due here beyond the closures recorded above
**Docs to update**: `DEVELOPMENT_PLAN/README.md` only through `accept`

### Objective

Author the first generation-2 specification, enter generation 2 with the first `accept`, and record the
reset that starts the frontier at this phase.

### Deliverables

- The Phase-0 `GateSpec` with `gateSeed` present and no `BinaryFact`.
- The reset with `--decision DL-0008 --product-gap LTD-DSL-001`.
- The complete Phase-0 candidate recorded by `accept`, with its receipt digest beside Done status and its
  immutable seven-file bundle under `validation-records/**`.

### Validation

Run `preview phase 00` and require every row green; run `accept --phase 00` and require exactly one phase's
patch plus the receipt line and one complete archive bundle; delete the scratch cache and require archive
verification to succeed. Remove the bundle in a negative test and require `replay` to run the gate green and
publish a new bundle and refreshed digest.

### Remaining Work

The qualified owning image/completion repair is recorded under [Phase Status](#phase-status) and
[DL-0042](../documents/decision_log.md#dl-0042--qualified-image-and-completion-custody-retires-runner-authority).
Preserve this sprint's independent expectations and inherited guards. Current reuse requires a compatible
receipt and complete replay for affected source or governance; historical component observations below
do not replace that replay or qualify a successor gate.

The seed protocol is generated, never authored: each bypass is one complete-line rewrite of the predicate
source applied to a fresh copy beneath the run root, compiled directly with the version-compatible compiler together with
the independent driver, and run under the observer; the driver refuses with the case label alone. The seed
role is the one role whose subjects are validator modules and whose closure is the verifier executable's.
It validates the finite validator seed and requires no product `BinaryFact`; it does not assert that a
shipped product binary is absent. The specification joins the registry under its capability, and the fenced
block in this document must equal its compiled rendering. The distinct complete owning acceptance
recorded under [Phase Status](#phase-status) closes the reopened binding; DL-0040's lifecycle and governance
amendment requires complete numerical Phase-0 replay before fresh Phase-1 preview and separate acceptance
and then Phase 2. The human's durability action remains the commit.

## Documentation Requirements

**Engineering docs to update when their governed boundary changes:**

- `documents/documentation_standards.md` — only if governed document mechanics change.
- `documents/engineering/gate_runner_doctrine.md` — only if the runner's vocabulary, refusals, or commands change.
- `documents/engineering/repository_layout_doctrine.md` — only if the finite source boundary changes.
- `documents/engineering/validation_frame_doctrine.md` — only if `GenesisTrust` or the host precondition changes.

**Cross-references to add:**

- Actual inbound links discovered by the Haskell link-graph checker, reconciled in the same change.

## Related Documents

- [Development-plan tracker](README.md)
- [Phase 1 toolchain spike](phase_01_toolchain_spike.md) — native version admission after the seed
- [Phase 2 repository layout conformance](phase_02_repository_layout_conformance.md) — source closure
- [Phase 3 typed spine](phase_03_typed_spine.md) — the first product specification
- [Development-plan standards](development_plan_standards.md)
- [Canonical phase model](development_plan_phase_model.md)
- [Gate integrity](development_plan_gate_integrity.md)
- [Reader-facing legacy register](legacy_tracking_for_deletion.md)
- [Decision log](../documents/decision_log.md)
- [Gate-runner doctrine](../documents/engineering/gate_runner_doctrine.md)
- [Validation-frame doctrine](../documents/engineering/validation_frame_doctrine.md)
- [Repository-layout doctrine](../documents/engineering/repository_layout_doctrine.md)
- [Testing spoof resistance](../documents/engineering/testing_spoof_resistance.md)
- [Behavioural verification doctrine](../documents/engineering/behavioural_verification_doctrine.md) — a verdict never rests on how a subject presents itself
