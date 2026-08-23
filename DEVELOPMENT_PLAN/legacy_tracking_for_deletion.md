# Legacy Tracking for Deletion

> **Purpose**: Provide the one active reader-facing explanation of repository divergence while reviewed
> Haskell owns every executable identity, owner, observation, closure, and reintroduction binding.
> **Read this if**: current source, validation machinery, or runtime structure differs from target doctrine.

This document is the sole reader-facing projection of active repository divergence. Its cardinality, history,
and authority boundary are defined by [§1](#1-register-contract). Executable inventory and closure authority
remain Haskell; design belongs to doctrine and phase status belongs to [README.md](README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_49_self_referential_gates.md, DEVELOPMENT_PLAN/phase_50_host_assert_cli.md, DEVELOPMENT_PLAN/phase_51_host_ensure_kernel.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/system_components.md, README.md, documents/documentation_standards.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/migration_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/illegal_state/README.md, pb/README.md, pb/stubs/README.md, vendor/dual/PROVENANCE.md, vendor/supernova/PROVENANCE.md
**Generated sections**: none

</details>

> **Validation reset.** Every phase is NOT VALIDATED. A row records observed work; it never carries a passed
> phase result, preserves an old seal, or authorizes a later phase.

## Contents

- [1. Register contract](#1-register-contract)
- [2. Tracked-source violations](#2-tracked-source-violations)
- [3. Validation-integrity violations](#3-validation-integrity-violations)
- [4. Host, image, and lift violations](#4-host-image-and-lift-violations)
- [5. Closure order](#5-closure-order)
- [Related Documents](#related-documents)

---

## 1. Register contract

Exactly one reader-facing legacy register is permitted, at this path. A second current, historical,
superseded, archived, or completed-row ledger is prohibited. A closed explanation is deleted only after its
reviewed Haskell transition and human acceptance; Git history is the only record of its former existence.
The legacy structural seam may enforce that this exact canonical file occurs once, is UTF-8 readable, and has
no forbidden archive path or alias. The general documentation checker may separately enforce ordinary
orientation metadata, headings, links, anchors, and other corpus-wide structural rules. Neither seam may
interpret rows, cells, IDs, owner phrases, predicates, counts, or order as legacy semantics or use them to
produce a legacy closure verdict.

The executable contract is a closed typed inventory in `Amoebius.Validation.Legacy`. That Haskell surface
must declare the complete `LegacyId` universe and provide one total owner binding, one observation/closure
binding, and one reintroduction negative for every ID. The source classifier joins raw findings to those
bindings in both directions. Missing, stale, duplicate, wrongly owned, due, or unbound findings refuse at
typed Haskell loci. The compiled inventory also determines predecessor and Phase-49 closure; nothing in the
tables below is an operand in those decisions.

The rows below explain that intended Haskell inventory to readers. An ID is described as stable and its owner
as the earliest phase whose contract must make the replacement true. A later consumer may depend on the
replacement, but it cannot own or waive it. Reader-facing counts describe the 2026-08-22 reset. Code-shaped
text in the closure column is explanatory notation, not a predicate consumed by a checker. Adding, deleting,
duplicating, reordering, or changing any row, ID, owner, count, or closure sentence cannot add, remove,
reassign, or satisfy a compiled binding.

Human correspondence review owns agreement between the compiled Haskell surface and these explanations. A
mismatch is a documentation defect that the human must reject before acceptance, but it cannot manufacture a
machine pass or failure. The same review confirms a row deletion only after the typed closure binding reaches
zero, its independently authored Haskell negative detects reintroduction, predecessor approval is present,
and the evidence is retrievable.

The target `amoebius validate legacy --id <ID>` entry point decodes a typed Haskell ID and dispatches only to
its compiled closure binding. Python under `pb/**` may make only the minimum platform distinction needed to
establish the contained compiler, build the source-bound binary, and `exec` that exact binary with every
argument unchanged; Python may not calculate, translate, or override the verdict. A future closure run is
admissible only when all of these conditions hold:

1. The compiled binding receives the complete version-controlled source snapshot and reports its snapshot
   digest.
2. It reports every matching path or semantic locus rather than accepting a caller-supplied count.
3. The clean candidate satisfies the typed closure binding, independently of this Markdown file's contents.
4. A generated isolated snapshot reintroduces one matching violation and makes the same binding fail at the
   expected locus; a no-op checker, constant-success checker, empty enumeration, and skipped negative also
   fail.
5. The typed owner has no open predecessor or other due binding.
6. A human reviewer confirms the binding, raw observations, negative, evidence, and prose correspondence
   before removing the explanatory row.

**Observed footprint / Known partial.** `Amoebius.Validation.Legacy` now owns a closed 25-constructor ID
universe, stable encodings, typed owners and lifecycle states, total required-analyzer/observation/closure/
reintroduction bindings, frozen source-family baselines, and per-constructor fail-closed dispatch. An active
binding whose owner-domain observer is unavailable cannot report closure; at or after its owner it emits a
typed `LEGACY-ANALYZER-UNAVAILABLE` refusal. Active source-family zero requires a reviewed Haskell retirement
transition, while a retired non-zero source family reports reintroduction. This is an unqualified component
footprint, not evidence that any owner-domain analyzer ran or any binding closed. A separately stated component
oracle pins all 25 bindings and all nine source baselines; its clean aggregate is green, and eight isolated
changed-production builds each red only that oracle while every unrelated named oracle executes green. Those
same-workstream diagnostics provide no external reviewer authorship/custody, parent-harness qualification, or
human correspondence decision. The dispatcher therefore continues to refuse Phase-0 readiness. The table
cannot fill any of those gaps. No deletion, textual assertion, hash-shaped string, Python exit code,
implementation-authored component check, or LLM-produced completion claim can close a binding.

---

## 2. Tracked-source violations

The target source boundary is closed: behavioral source under version control is Haskell. Python beneath
`pb/**` is the sole language exception, and only for the pre-binary bootstrap handoff. Documentation,
licences, Cabal/project declarations, ignore rules, and the minimal package metadata required to build `pb`
are non-code inputs. Serialized configuration, schemas, programs, fixtures, oracles, mutants, scripts, and
rendered recipes are generated lazily from Haskell into `.build/**`.

| ID explained for readers | Current observation | Owner/replacement explanation for readers | Closure behavior explained for readers |
|---|---|---|---|
| `LTD-SRC-000` | A Haskell source-snapshot classifier and `legacyCheck` footprint now acquire and classify the Git snapshot, and the Phase-0 dispatcher invokes them. The component rejects Git `assume-unchanged`/`skip-worktree`, binds final visibility to stage/mode/object/path, reads tracked regular files through no-follow descriptors, and compares worktree bytes/kind/owner-execute mode with the index. Its authored-root recursion does inventory ignored and untracked material, but still uses path-based directory queries; an ancestor-symlink or replacement race can therefore escape or conceal that observation. Content-role detection also remains first-line lexical matching rather than a semantic parser/consumer/effect graph; Git/tool identity, independent blob hashing, clean-candidate qualification, changed-subject harness qualification, and independent human review are absent. The dispatcher deliberately refuses readiness, so the row remains active and NOT VALIDATED. | **Phase 0.** Complete and independently qualify the Haskell source-snapshot classifier, semantic consumer/effect graph, descriptor-relative no-follow authored-root walker, and external workspace observer, then make their complete accounting a mandatory precondition of every phase gate. Later-owned migrations remain explicit typed Haskell bindings; they cannot make Phase 0 depend on a later phase. | The typed Haskell join must account for every tracked path exactly once against the compiled legacy inventory. It rejects behavioral non-Haskell bytes outside `pb/**`, disguised source by executable mode/shebang/semantic consumer role, index concealment flags, and independently observed kind/mode/byte mismatch. Its unbound-finding, executable, shebang, content-role, consumer-graph, assume-unchanged, skip-worktree, ancestor-symlink, special-file, replacement-race, authored-root concealment, independent-blob-hash, and mode/byte-divergence mutants must fail. |
| `LTD-SRC-001` | `tools/**` contains 237 tracked files: 201 Python programs, four shell programs, tables, JSON, copied documentation corpora, and other gate inputs. | **Phase 47.** Haskell values generate every required tool lazily beneath `.build/tools/**`; the authored `tools/**` root is removed. | `trackedUnder "tools" snapshot == []`; a generated Python gate at `tools/reintroduced_gate.py` fails `sourceBoundary` before execution, and clean-room gate generation succeeds with `tools/**` absent. |
| `LTD-SRC-002` | The frozen SourceDhall family contains 279 paths: 278 `.dhall` files across `dhall/**`, `test/**`, `probe/**`, and the repository root, plus the behavioural `dhall/examples/locus_registry.tsv` input. | **Phase 25.** Haskell checked-IR types and Haskell-authored semantic cases generate every Dhall projection and associated serialized registry beneath `.build/dhall/**`; no Dhall/registry source is tracked. | `sourceDhallFamily snapshot == []`; generated schema, registry, legal cases, and illegal cases materialize from Haskell in a clean room, while a tracked one-file Dhall or TSV reintroduction fails. |
| `LTD-SRC-003` | `proto/Amoebius/Pulsar/Proto/PulsarApi.proto` is tracked behavioral source; the other current Proto path belongs to the frozen top-level-vendor family `LTD-SRC-009`, so no locus is double-counted. | **Phase 26.** Haskell message declarations generate the wire schema and bindings beneath `.build/proto/**`; maintained Haskell consumes only generated bindings. | `trackedBySuffix ".proto" snapshot == []`; the generated schema round-trips every message constructor and a changed field-number mutant fails the independent Haskell wire oracle. |
| `LTD-SRC-004` | `ui/**` contains 15 tracked PureScript, JavaScript, and YAML files, and root `package.json` is a second authored UI build input. | **Phase 46.** Haskell public-boundary values generate the generic browser interpreter, foreign-function shims, package description, and build description beneath `.build/ui/**`. | `trackedUnder "ui" snapshot == [] && not (tracked "package.json" snapshot)`; a clean-room browser build consumes only generated UI files, and a reintroduced `.purs`, `.js`, or package manifest fails. |
| `LTD-SRC-005` | `pulumi/child-cluster/Pulumi.yaml` is tracked serialized infrastructure-program input. | **Phase 47.** Typed Haskell provider declarations generate Pulumi program metadata beneath `.build/pulumi/**` before the complete hardware-free DSL barrier; no later source-migration exception exists. | `trackedUnder "pulumi" snapshot == []`; clean-room provider metadata generation reaches the declared engine from Haskell alone, and a tracked YAML reintroduction fails. |
| `LTD-SRC-006` | `test/**` contains 998 non-Haskell files. The 108 Dhall files belong to `LTD-SRC-002`; the other 890 include Python, shell, JSON/YAML/TSV tables, goldens, expected outputs, patches, and mutant bodies. | **Phase 47.** Tests and independent expectations are Haskell; every serialized fixture, executable fake, rendered oracle, and applied mutant is generated lazily beneath `.build/test-corpora/**`. | `all isHaskellSource (behavioralTrackedUnder "test" snapshot)` after excluding no format by filename; clean-room test generation covers every declared case and mutant, while one reintroduced table, script, golden, or patch fails. |
| `LTD-SRC-007` | `probe/**` retains seven non-Haskell behavioral inputs besides its two Dhall files: expected-output files, extensionless mutant/oracle programs, and a mutant project file. | **Phase 1.** Keep the Haskell probe and Cabal declaration; generate its cases, mutations, and expected observations beneath `.build/probe/**`. | `behavioralTrackedUnder "probe" snapshot == trackedHaskellAndCabalUnder "probe" snapshot`; a clean probe generates all cases, and each non-Haskell reintroduction fails. |
| `LTD-SRC-008` | All 15 current `pb/**` paths remain a frozen source-debt family. Some Python modules now appear lexically limited, but comments, dead strings, dynamic imports, or an unobserved branch could spoof that claim; admin/test/check modules, serialized behavior, and obsolete packaging are still present. | **Phase 0.** Before any phase can use `pb validate`, reduce `pb` to an exact non-empty source inventory implementing only the minimum pre-binary mechanism: platform discrimination only as needed to choose the establishment adapter, contained toolchain establishment, source-bound Haskell build, and exact-binary `exec` with unchanged argv. Python does not own user-facing verbs; Haskell owns host-floor decisions, validation, help, version, and every public command. | The Phase-0 Haskell analyzer admits every target `pb` path through an exact non-empty deny-by-default AST/import/resolved-call/control-flow/potential-effect graph, rejects every unsupported or unresolved node, proves every possible effect is routed to the declared `BootstrapAdapter`, and finds no tracked behavioural data under `pb/**`. Paired source mutants cover admin, test, check, verdict, argv rewrite, dynamic import/eval/reflection/hooks, hidden terminal/no-exec control flow, effect bypass, and envelope reintroduction in isolated `.build/source-snapshot/**` copies. This row closes on static source admission only; actual adapter effects, executable identity, unchanged argv, exec replacement, and exit propagation remain Phase-50 runtime claims. |
| `LTD-SRC-009` | Top-level `vendor/**` contains 28 tracked paths: 19 Haskell modules plus foreign package descriptions, one Proto schema, provenance prose, and licences. Although most implementation files end in `.hs`, this transitional root is outside the exhaustive target layout and its foreign build inputs remain tracked. | **Phase 1.** Remove top-level `vendor/**`; re-derive maintained Haskell code beneath `src/vendor/**/*.hs`, and acquire every required upstream non-Haskell input at an immutable identity beneath `.build/vendor/**`. Declare provenance and transformations in reviewed Haskell values. | `trackedUnder "vendor" snapshot == []`; the clean build resolves the declared immutable upstream bytes into `.build/vendor/**`, the maintained Haskell fork passes a separately authored Haskell oracle, and top-level-vendor, mutable-ref, tracked-Proto, tracked-foreign-package, and patch-program reintroductions fail at their exact loci. |
| `LTD-META-001` | `.gitignore` and `.dockerignore` still name retired source-adjacent generated roots such as `gen/**`, `DEVELOPMENT_PLAN/evidence/**`, `test/enumeration/**`, phase-ledger files, and UI build-output directories. | **Phase 2.** Derive the exact ignore/context policy from the closed repository roots; generated material has no admitted home outside `.build/**`, `.data/**`, and marker-owned `.test_data/**`. | `legacyGeneratedIgnorePatterns snapshot == [] && ignoreContract snapshot == canonicalContainedRoots`; a generated mutation adding each retired root to either ignore file fails at that exact pattern, while the canonical contained-root corpus passes. |

---

## 3. Validation-integrity violations

| ID explained for readers | Current observation | Owner/replacement explanation for readers | Closure behavior explained for readers |
|---|---|---|---|
| `LTD-VAL-001` | All 96 phase contracts name the target `pb validate phase NN` command, but current `pb/**` still parses public verbs and has no conforming opaque validation route. Only Phase 0 has a Haskell dispatcher implementation, and it deliberately refuses readiness; the old Python runner and other condemned tools remain tracked as later-owned source. The universal Haskell protocol remains active work and NOT VALIDATED. | **Phase 0.** Complete and independently qualify the universal Haskell-owned subject/oracle/negative/evidence protocol and the bounded opaque handoff into it. No phase command outside that handoff may name Python or an authored generated tool. | `allPhaseGatesHaskell contracts` and `verdictAuthorityGraph contracts == Right haskellOnly`; replacing a subject with no-op, replacing a checker with constant success, passing a forged exit code, or omitting discovery makes gate qualification fail. |
| `LTD-VAL-002` | All 96 phase documents now expose the fixed gate-contract table, but 93 contracts still contain 1,290 `UNRESOLVED` cells and 92 `MISSING` predecessor cells (1,382 fail-closed cells total). Phase-0 Haskell structural-oracle components exist, but implementation-authored component checks are not independent review, clean-room qualification, or human reviewer custody. This row remains active and NOT VALIDATED. | **Phase 0.** Rewrite all 96 validation contracts with frozen claims, separately reviewed Haskell oracles, explicit dependency boundaries, production-locus mutations, unaffected controls, and human reviewer custody. | `validationContractAudit contracts == Right ()`; it rejects shared subject/oracle derivation, same-change unreviewed custody, byte-copy equivalence as semantics, a mutant outside production behavior, an unaffected claimed check, and every unexplained `N/A`. |
| `LTD-VAL-003` | Every phase and sprint status has been reset to NOT VALIDATED, so prior completion text and hash-shaped seals no longer authorize later work. Candidate-evidence and receipt-verification components exist, but no qualified candidate has been accepted into a retrievable evidence store and no human promotion has occurred. The row remains active. | **Phase 0.** Keep every phase NOT VALIDATED until a retrievable evidence receipt is bound to source, contract, subject, oracle, negatives, observer, and predecessor receipt and is then accepted by the human authority. | `statusProjection tracker evidence == allNotValidated` for this refactor; a later promotion succeeds only when `verifyReceipt` resolves every digest and the human approval signature. Typed hashes, missing records, stale source, stale contracts, and replayed predecessor receipts fail. |
| `LTD-VAL-004` | The current Phase-0 dispatcher does not mutate plan status, and a Haskell approval verifier binds candidate fields to an Ed25519 signature. There is still no externally held trust root or key-custody workflow, independently supplied human approval, or qualified human-only promotion path. The row remains active and NOT VALIDATED. | **Phase 0.** Complete and independently qualify a promotion boundary that reserves sprint and phase promotion to the human user. Automation and LLMs may emit candidate evidence only. | `promotionAuthority policy == HumanOnly`; synthetic automation-authored, LLM-authored, absent, and mismatched approvals all fail before tracker mutation. |
| `LTD-VAL-005` | The validation-frame sequence makes a downstream base image part of validating the earlier DSL, allowing hardware/image availability to precede semantic confidence. | **Phase 49.** Establish an independently reviewed, hardware-free promotion barrier over the real Haskell path: decode → legality → bind/expand → plan/resolve infrastructure → provision → renderAll → plan → dry-run → fake apply. Hardware, containers, clusters, VMs, and published images are forbidden inputs to this barrier. | `dslPromotionBarrier source == Passed receipt` using only the source snapshot and Haskell-resolved tools; every Phase 50+ gate refuses without that exact human-approved receipt, and network/container/hardware-use mutants fail the barrier. |
| `LTD-VAL-006` | Authored gates and tests still contain hundreds of references to generated evidence roots, enumerations, ambient temporary roots, and retained observations; a stale worktree can therefore influence a verdict. | **Phase 47.** Generate all transient cases and evidence under a fresh run root in `.build/**`, bind reads to that root, and refuse any input from an earlier run or authored output root. | `runInputClosure run snapshot == Right () && externalWrites run == []`; stale-run, ignored-input, authored-output, ambient-temp, replay, and empty-discovery mutants each fail at distinct loci. |
| `LTD-DOC-001` | `tools/covering_grid.py`, `tools/locus_registry_lint.py`, and `tools/illegal_state_corpus_gate.py` still parse reader-facing `Cells:` Markdown and an authored TSV registry into behavioural coverage values. The reset doctrine forbids that authority path, but the implementation remains tracked and the replacement has not been qualified. | **Phase 27.** Replace every behavioural Markdown/TSV consumer with reviewed Haskell catalogue, relation, pairing, and justification declarations plus a separately authored Haskell oracle. Generate fixtures and diagnostic views lazily beneath `.build/**`; Markdown remains explanation only. | `behavioralMarkdownConsumers snapshot == [] && coveringSemanticInputs snapshot == HaskellOnly`; a production mutant that reads governed Markdown or a serialized registry fails input-closure before generation, while changing only reader-facing prose cannot make the behavioural covering pass. |

---

## 4. Host, image, and lift violations

| ID explained for readers | Current observation | Owner/replacement explanation for readers | Closure behavior explained for readers |
|---|---|---|---|
| `LTD-NAME-001` | Phase ordinals remain in non-plan Haskell comments/strings and generated-source inputs; gate ordinals and their contracts have drifted repeatedly. | **Phase 2.** Runtime identities and source names describe capabilities, never plan position; the contract path is the sole source of a gate's phase identity. | `phaseOrdinalsOutsidePlan snapshot == []` and every contract identity derives from its filename; stale ordinal, copied numeric constant, and phase-named runtime identity mutants fail. |
| `LTD-HOST-001` | `installAndVerify` has no production caller, `Host.Context` retains a second executable discovery helper, and host-tool requirements are duplicated across Haskell, Python, and tables. | **Phase 51.** One closed Haskell requirement algebra and one probe-first ensure interpreter serve every production host path. | A production entry point reaches `installAndVerify`; `executableResolvers production == 1`; the closed tool set is declared once; absent→installed→resolved and idempotent replay pass, while no-caller, stale-snapshot, duplicate-resolver, and constant-success mutants fail. |
| `LTD-HOST-002` | Current Haskell production modules and Haskell specs retain developer-home executable paths, ambient `/tmp` or `/var/tmp` state, and external-state fallbacks; condemned non-Haskell gates are already covered by `LTD-SRC-001`. | **Phase 51.** Logical tools resolve through the host kernel; all run-local state is beneath `.build/**` or the exact live-test `.test_data/**` ownership root. | `ambientPathLoci haskellSource == []`; two-host resolution uses disjoint `<os>-<arch>` roots, and home-prefix, ambient-temp, unresolved-`PATH`, changed-owner, and production-overlap mutants fail before effects. |
| `LTD-IMG-001` | Image code and fixtures still construct a joined `linux/amd64,linux/arm64` build, require emulator arguments, and carry QEMU/binfmt paths although the architecture rule requires native per-architecture artifacts. | **Phase 56.** Build and attest one architecture-qualified image on a host of that natural architecture; Phase 57 later performs the complementary host run without an index join. | `imageBuildPlatforms host request == [naturalArchitecture host]`; the emitted command has no emulator/index/multi-platform operation, the kernel's binfmt table is unchanged, and cross-architecture or manifest-list mutants fail. |
| `LTD-RUN-001` | The Cabal file now declares one executable, but tools, tests, fixtures, and runtime strings still name `amoebius-singleton` and phase-ordinal artifact paths. | **Phase 55.** One binary receives its role as a decoded Haskell value; no path, field manager, image command, or fixture invents a second executable identity. | `amoebiusExecutableStanzas == 1 && obsoleteRuntimeIdentities snapshot == []`; identity-by-executable, phase-path, and second-stanza mutants fail. |
| `LTD-SEED-001` | `cabal.project` resolves infernix from mutable `tag: master`, and six `src/Infernix/**` modules retain an upstream namespace inside amoebius. | **Phase 91.** Re-derive the required behavior under `Amoebius.*`; no build input, vendored tree, module, hash table, or captured output depends on the seed. | `seedDependencies Infernix snapshot == [] && trackedUnder "src/Infernix" snapshot == []`; a clean build succeeds with no sibling/network access, and seed-fetch, upstream-namespace, copied-hash, and captured-output mutants fail. |
| `LTD-SEED-002` | `cabal.project` resolves jitML from mutable `tag: master`; tests name `JitML.Codegen.RuntimeOperationsCuda`, which the tracked source does not provide. | **Phase 93.** Re-derive the required CUDA-training behavior under `Amoebius.*`; no build or validation input depends on the seed or a missing upstream module. | `seedDependencies JitML snapshot == []`; a clean build and semantic suite succeed with no sibling/network access, and seed-fetch, missing-module, copied-output, and silent-CPU-fallback mutants fail. |

---

## 5. Closure order

Compiled legacy bindings close only in their typed owner-phase order. Within one phase, source-boundary and
validation-framework bindings close before a capability binding that relies on them. The sequence below is a
reader-facing explanation; human correspondence review compares it with the compiled owner map, and no list
item changes execution. In particular:

1. Phase 0 resets status, closes `LTD-SRC-008`, and installs the Haskell source/contract/promotion authority
   checks before `pb validate` can become an admissible handoff.
2. Phase 1 closes both probe debt and the top-level `vendor/**` family; Phase 2 closes metadata and naming debt.
3. Phase 25 and Phase 26 establish Haskell-derived schema and wire projections.
4. Phase 27 removes Markdown/TSV behavioral authority under `LTD-DOC-001`.
5. Phase 46 and Phase 47 remove the remaining authored generated programs, fixtures, tools, and mutants.
6. Phase 49 requires every source-migration Haskell binding to be zero and passes the hardware-free DSL
   promotion barrier.
7. Only then may Phase 50 validate the already-bounded `pb` handoff. Phase 51 must next validate the Haskell
   host-ensure kernel against fake boundaries with no hardware. Only after both receive their own human
   approvals may Phase 52 begin the first hardware-bearing candidate; image, cluster, and live-provider bands
   remain numerically downstream.

No binding is considered closed merely because its path is absent in one worktree or its explanatory row was
edited or deleted. Its typed Haskell closure, independently authored reintroduction negative, predecessor
chain, retrievable evidence, and human approval must all agree. The human then reconciles or removes the
reader-facing explanation.

---

## Related Documents

- [Development Plan](README.md) — the only phase-status projection; every phase is currently NOT VALIDATED
- [Development Plan Standards](development_plan_standards.md) — phase-contract and migration rules
- [Gate Integrity](development_plan_gate_integrity.md) — universal anti-spoof validation requirements
- [Repository Layout Doctrine](../documents/engineering/repository_layout_doctrine.md) — the closed tracked-source grammar and lazy-generation boundary
- [JIT Artifact Doctrine](../documents/engineering/jit_artifact_doctrine.md) — content-addressed lazy materialization
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — the hardware-free promotion boundary
