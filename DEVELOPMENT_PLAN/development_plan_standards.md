# Development Plan Standards

> **Purpose**: Define the required shape, status discipline, validation contract, and repository-boundary
> rules for every document under `DEVELOPMENT_PLAN/`.
> **Read this if**: a phase, sprint, gate, dependency, or plan document is being created or changed.

This is the development-plan rulebook hub. Detailed arguments live in
[`development_plan_phase_model.md`](development_plan_phase_model.md) and
[`development_plan_gate_integrity.md`](development_plan_gate_integrity.md); this file preserves the complete
section/anchor surface and the exact document templates.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: AGENTS.md, DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_10_calculus_composition.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_12_explicit_state_checker.md, DEVELOPMENT_PLAN/phase_13_symbolic_checker.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, documents/documentation_standards.md, documents/engineering/formal_model_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/testing_doctrine.md, documents/glossary.md, documents/reading_order.md
**Generated sections**: none

</details>

## Contents

- [A. Header metadata (same block as the doctrine suite)](#a-header-metadata-same-block-as-the-doctrine-suite)
- [B. Canonical file layout (snake_case)](#b-canonical-file-layout-snake_case)
- [C. Status vocabulary](#c-status-vocabulary)
- [D. The per-phase document skeleton](#d-the-per-phase-document-skeleton)
- [E. One canonical phase model](#e-one-canonical-phase-model)
- [F. The sprint block format](#f-the-sprint-block-format)
- [G. Documentation Requirements](#g-documentation-requirements)
- [H. The doctrine-citation rule (cite by name)](#h-the-doctrine-citation-rule-cite-by-name)
- [I. Generated documentation remains untracked](#i-generated-documentation-remains-untracked)
- [J. Cross-reference path rules](#j-cross-reference-path-rules)
- [K. Honesty (proven / tested / assumed)](#k-honesty-proven--tested--assumed)
- [L. One-substrate discipline](#l-one-substrate-discipline)
- [M. Gate integrity (a gate cannot be passed by a stub)](#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
- [N. Reopening and amending a phase](#n-reopening-and-amending-a-phase)
- [O. Sprint-sized seams and bounded phase gates](#o-sprint-sized-seams-and-bounded-phase-gates)
- [P. Plan-document shape](#p-plan-document-shape)
- [Q. The two phase diagrams](#q-the-two-phase-diagrams)
- [R. Where the cross-cutting invariants live](#r-where-the-cross-cutting-invariants-live)
- [S. Universal artifact-hygiene gate](#s-universal-artifact-hygiene-gate)
- [T. Plan-to-implementation reconciliation](#t-plan-to-implementation-reconciliation)
- [U. The final repository layout](#u-the-final-repository-layout)
- [Related Documents](#related-documents)

---

## A. Header metadata (same block as the doctrine suite)

Every file opens with the orientation and link-graph block required by
[`documentation_standards.md`](../documents/documentation_standards.md):

```markdown
# <Title>

> **Purpose**: <one sentence>
> **Read this if**: <reader and decision enabled>

<lead: ownership, exclusions, prerequisite>

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: <actual inbound links>
**Generated sections**: none

</details>
```

`Referenced by` is reconciled from the actual graph. It never names a deleted archive or guesses a blanket
audience. Generated Markdown lives under `.build/docs/**`, not between markers in an authored document.

---

## B. Canonical file layout (snake_case)

The governed set is closed:

| Path | Role |
|---|---|
| `README.md` | Sole live tracker and plan index |
| `development_plan_standards.md` | Rulebook hub and templates |
| `development_plan_phase_model.md` | Status, order, substrate, reopening, and seams |
| `development_plan_gate_integrity.md` | Gate trust split, source/artifact closure, reconciliation, and tree rules |
| `overview.md` | Target architecture and sequence narrative |
| `system_components.md` | Target component inventory |
| `substrates.md` | Substrate vocabulary and per-phase map |
| `legacy_tracking_for_deletion.md` | The one active reader-facing explanation of implementation/plan divergence |
| `phase_NN_<slug>.md` | One contract per contiguous numbered phase |
| `later_phases.md` | Unnumbered future intent only |

There is one reader-facing legacy register only. Closed and superseded explanations are deleted; Git history
is the archive. No other file may become a second deletion register. Its legacy-specific structural seam
enforces exact canonical file cardinality, regular non-executable mode, UTF-8 readability, absence of a second
exact canonical basename, and absence of the exact forbidden archive basename. It does not infer semantic
aliases from arbitrary prose or filenames. The general documentation checker may separately enforce ordinary
orientation metadata, headings, links, and anchors. It also applies a basename-substring
register-cardinality diagnostic and a case-folded forbidden-archive-basename content diagnostic; those are
documentation findings, not legacy semantic findings. A closed Haskell legacy inventory owns identities,
owners, observation bindings, closure bindings, and required reintroduction-case identities. At the owner, a
zero is admissible only with opaque execution evidence binding the same row and source snapshot to the exact
canonical case set and qualifying transcript. An owning analyzer must later qualify the corresponding negative
before retirement; neither structural seam may
interpret a Markdown row, cell, count, ID spelling, owner phrase, or predicate-shaped string as legacy
semantics or use it in an executable closure verdict.
The documentation gate owns structural correspondence between the two surfaces; semantic discrepancies are
ordinary test failures.

All planned implementation paths name authored `.hs` source. The sole non-Haskell source exception is
`pb/**`, whose bootstrap-only scope is closed by [§S](#s-universal-artifact-hygiene-gate). Reproducible
non-Haskell material is a lazy `.build/**` product and never an `Implementation` path.

---

## C. Status vocabulary

The five markers and their mandatory wording are defined in
[`development_plan_phase_model.md` §C](development_plan_phase_model.md#c-status-vocabulary). Every non-Done
phase and sprint says `NOT VALIDATED`. A complete qualified phase-gate pass is sufficient for ✅ Done. Digests
and generated evidence remain inputs to the test rather than substitutes for running it.

The 2026-08-22 reset initialized Phase 0 as `🔄 Active — NOT VALIDATED` and every later numbered phase as
`⏸️ Blocked — NOT VALIDATED`; no pre-reset completion claim survived. Current status is read only from the
canonical tracker/phase/sprint projection, whose complete vector must be one Done prefix, exactly one Active
phase, and one Blocked suffix (or the terminal all-Done state).

The current phase-status line is a raw, one-line, exact field and occurs once. The `**Gate:**` summary is a
separate immutable command/link field: it never carries status or result prose, so recording a pass cannot make
the summary contradict the phase status or require it to join the status patch. A substring such as
`Validated — NOT VALIDATED`, a second bare status marker, another `**Status**:` field, or a canonical-looking
copy supplied through a fence, HTML comment, or physical line wrap is a defect. Sprint sections likewise
contain exactly one current `**Status**:` field and no additional bare current-status marker. Historical status
is described only as explicitly invalidated prose; it is never restated as a second status field or bare marker.

Contract specification, candidate observation, and status recording are distinct state spaces. An authored gate cell
uses `UNRESOLVED` only when its required specification is incomplete. It must not use `MISSING` to stand for a
runtime receipt that cannot exist while the contract is being authored; for example, the `Predecessor` cell
specifies the typed `ImmediatePredecessorPass` requirement, while a later candidate records an exact
`EVIDENCE-ABSENT` refusal if that result is unavailable. `UNVERIFIED` is permitted only for an explicitly
named residue layer in candidate evidence; it cannot satisfy a contract slot. Markdown words never transition
among these states: the compiled Haskell registry and captured observations do.

A status update is the mechanical status-only patch produced after the exact current phase gate passes. The
gate binds the source snapshot it tested and permits only the tracker, phase, and sprint status fields named by
that result to change. The one contiguous frontier advances with the pass: the closing phase and all of its
sprints become Done, and its immediate successor plus that successor's first sprint become Active when one
exists; every later phase remains Blocked. The validator emits the verified patch only beneath `.build/**` and
never changes a tracked file. After that process exits, a human, agent, or CI job may recheck the bound preimage
and apply the exact patch. Any other byte change creates a new candidate and requires the gate to run again.

A later implementation change does not invalidate an earlier pass merely because the repository-wide source
digest changes. A verified immediate-predecessor receipt is a monotonic frontier fact: the active gate projects
that fact onto its exact opening snapshot and owns compatibility between the current source and every capability
it consumes. Receipt refresh remains available when a completed phase itself is deliberately revalidated, uses
an identity projection, changes no status, and installs a new durable receipt; it is not a recursive prerequisite
for later development. Multiple valid receipts for one phase are one deterministic equivalence class, not
ambiguous authority: the verifier checks every entry and selects the lexicographically least content digest.
Malformed, detached, wrong-phase, and non-green evidence remains fail-closed. This rule prevents an edit to the
current validator or a later phase from forcing replay of the entire completed prefix while keeping each new
candidate bound to both an authentic predecessor fact and its exact current-source gate result.

---

## D. The per-phase document skeleton

Every `phase_NN_<slug>.md` uses this order:

```markdown
# Phase N: <Title>
<§A orientation block>

## Contents

## Phase Status
⏸️ Blocked — NOT VALIDATED.
<named immediate predecessor and any additional blockers>

## Phase Summary
<one cohesive capability claim>

**Phase scope:** <claim, seams, split trigger>
**Substrate:** <none | apple | linux-cpu | linux-cuda | windows>
**Lane:** <none | linux-cpu/amd64 | linux-cpu/arm64 | metal | cuda | provider>
**Register:** <— | 1 | 2 | 3>
**Depends on:** <the exact linked immediate numeric predecessor only, or genesis for Phase 0; additional earlier dependencies belong in typed contract/prose rather than this structural field>
**Forward-deferred:** <conditional; each later-owned capability this phase names, with its owner and forward-deferral tag>
**Gate:** `pb validate phase NN`; see [Gate integrity](#gate-integrity).

## Gate integrity
<the exact §M table; required>

## Resource provision — <optional suffix>
<required when phase-specific subject or observer effects provision external/live resources>

## Doctrine adopted
## Sprints
## Documentation Requirements
## Related Documents
```

The six unconditional Phase Summary fields are required, closed, and ordered exactly as shown. Phase 0's
literal `genesis` dependency denotes the explicit irreducible, non-numbered `GenesisTrust`/`BootstrapRoot`
input; it is neither a hidden phase nor a capability Phase 0 can prove with the compiler being checked. The immutable
Gate line is a future public-command target, not an assertion that it exists, runs, or passes; status belongs
only to the tracker, phase-status line, sprint headings, and sprint status fields.

`Forward-deferred:` is the one conditional field, placed exactly between `Depends on:` and `Gate:`. It is
present when and only when the phase names an artefact a later phase owns, and it carries that owner's
capability plus the contract-level forward-deferral tag under which the reach is recorded. That tag is not an
entry in the earlier candidate's `captureResidue`. `Depends on:` is structurally restricted to
the immediate predecessor and
[`development_plan_phase_model.md` §E](development_plan_phase_model.md#e-one-canonical-phase-model) routes
additional dependencies to prose only when they run backwards in the plan's order, so without this field a
forward reach has nowhere to be stated and is invisible to every checker. Naming one is not permission to
consume it: the reach is an excluded forward deferral the later owner discharges, and a phase whose claim cannot be settled without
the later artefact is mis-ordered rather than forward-deferred.

Until Phase 50's qualified gate passes,
`pb` is an inadmissible validation transport: Phase 0 through Phase 49 invoke the exact source-bound Haskell
executable directly. Phase 0 carries only the narrow `GenesisTrust` local-custody and compile-time/platform
assumption; it does not authenticate the actual compiler executable bytes or derivation. Phase 1 owns the
authenticated, reproducible toolchain acquisition bound by subsequent builds without retroactively providing
Phase 0's compiler. Phase 50
alone places the already source-bounded `pb` ensure/build/unchanged-argv/exec handoff under external runtime
observation: its candidate starts the exact source-built Haskell supervisor directly, and that supervisor
invokes `pb` as the child subject. The future public spelling cannot supervise its own handoff. Phase 51 and
later may use the public `pb validate phase NN` transport only after binding the
current Phase-50 pass result. In every case the Haskell binary decides the candidate verdict; Python may never do
so. A Python or shell verdict is non-conforming.

`## Gate integrity` is mandatory for every phase, including documentation-only Phase 0. Its fixed table makes
missing trust boundaries mechanically visible; prose, a diagram, or a link to a generic runner cannot replace
it. `## Resource provision` is the only optional section between Gate integrity and Doctrine adopted.

The universal validation envelope does not by itself select that optional section. Starting the exact outer
source-bound Haskell gate and containing its ordinary generated observations beneath the run-scoped `.build/**`
root are common gate mechanics governed by `Command`, `Cleanroom`, and candidate-evidence binding. They do not
make all ninety-six phases resource-provisioning phases.

A phase must include `## Resource provision` when its phase-specific subject, fake, adapter, external observer,
or cleanup helper may create, change, retain, or delete an additional process, host, VM, container, cluster,
namespace, cloud object, credential binding, volume, mount, device allocation, network object, or other live/
external state. Short-lived, local, diagnostic, fake-boundary, and test-only effects are not exceptions. A pure
in-process predicate requires no section merely because the outer gate process exists. A resolved section has
exactly these closed labels:

- **Owner marker:** a run-scoped identity that is minted before mutation and binds every resource the phase
  may own;
- **Preflight:** fresh read-only authority, capacity, collision, predecessor, and scope observations that must
  pass before the first effect;
- **Allowed mutations:** the complete finite resource/effect set;
- **Forbidden mutations:** foreign, unmarked, out-of-scope, post-refusal, or authority-bypassing effects;
- **External observer:** independent raw before/during/after observations that do not trust subject logs or a
  self-authored summary;
- **Scoped cleanup:** success, failure, interruption, and ambiguous-outcome cleanup limited by the owner
  marker, with no wildcard or inferred foreign target; and
- **Zero-owned-residue:** the exact post-cleanup query, including declared retained resources and every
  process/path/mount/volume/device/network/provider class that must be absent.

These labels are structural only. Executable meaning lives in a separately authored Haskell
`ResourceProvisionContract`, its effect interpreter, and an independent observer; Markdown cannot authorize a
mutation or establish cleanup. If any field or implementation is missing, the heading is exactly
`## Resource provision — UNRESOLVED`, its first blockquote begins
`**UNRESOLVED — blocks validation.** No live mutation may begin.`, and all following detail is
non-operative capability inventory. A descriptive capacity envelope, teardown intention, or successful
command cannot substitute for this contract.

---

## E. One canonical phase model

Phases are contiguous and considered in numerical order. Every gate after Phase 0 binds the immediately
preceding gate pass. Phase 49 is the no-hardware end-to-end DSL gate barrier; no fake-host takeover,
hardware bring-up, container, registry, cluster, GPU, or cloud evidence may open before its gate passes.

The full argument is in
[`development_plan_phase_model.md` §E](development_plan_phase_model.md#e-one-canonical-phase-model).

---

## F. The sprint block format

Each sprint uses this exact header and field set:

```markdown
## Sprint N.Y: <Name> ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: <authored .hs path, documentation path, or pb/** bootstrap path>
**Blocked by**: <immediate prior sprint or earlier phase gate pass; genesis only where true>
**Forward-deferred**: <conditional; later-owned capability this sprint names, with owner and forward-deferral tag; omit if none>
**Requires**: <`natural-linux-cpu-amd64-host` | `disposable-linux-cpu-amd64-host`; omit if none>
**Independent Validation**: <one falsifiable seam; never merely the parent gate>
**Oracle**: <separate .hs module and independence boundary>
**Legacy IDs**: <reader-facing references to the typed Haskell bindings, or `none`>
**Docs to update**: <governed doctrine owners>

### Objective
### Deliverables
### Validation
### Remaining Work
```

For behavioural work, `Implementation` and `Oracle` are `.hs`. A sprint may name `pb/**` only when its
objective is within the bootstrap exception; Python tests, gate logic, source-policy logic, product logic, or
oracle logic are never admitted there.

Every behavioral test, expectation, fixture declaration, and mutation reference elsewhere in a phase also
names one exact `.hs` path, Haskell module, or Haskell declaration. A plan must not point at a test artifact-family directory,
wildcard, serialized file, script, patch, or foreign-language file as retained repository material. Haskell
may render the corresponding transport lazily beneath an explicit `.build/**` destination. A reset notice
does not excuse contradictory retained instructions; the documentation syntax check rejects the retired path
form until the body is corrected. That syntax check reads raw Markdown bytes, including fenced blocks and
HTML comments, and joins wrapped artifact-authority wording across line boundaries.

`Independent Validation` names the seam's positive control, paired specific-reason negative, changed-subject
mutant, and residue. The expanded numbered Validation list may provide detail. A command exit code, parent
gate reference, test count, fixture existence, or hash comparison alone is insufficient.

Where the seam has selectable changed-production subjects, `Independent Validation` also names its
independently literal oracle-owned selector-to-exact-case registry. The candidate must reconcile exact selector
identities in both directions across production, that registry, and build mappings; reject duplicates, unknown
targets, and omissions; and run each changed subject against its assigned exact case and named locus. A registry
derived from production or build declarations, cardinality-only agreement, or an aggregate oracle that turns
red outside the assigned case is inadmissible under
[`testing_spoof_resistance.md` §12.4](../documents/engineering/testing_spoof_resistance.md#124-subject-change-witnesses).

`Forward-deferred` is present when and only when the sprint's deliverables or validation name an artefact a
later phase owns. It records an excluded reach with its owner and never enters the earlier candidate's
`captureResidue`; it never authorises consuming that artefact to settle this sprint's claim.

`Blocked by` names plan work. `Requires` names only an environmental fact no phase can build. Its current
closed vocabulary is `natural-linux-cpu-amd64-host` and `disposable-linux-cpu-amd64-host`; a new fact requires
a standards amendment before use. A tool, predecessor capability, prior sprint output, or same-run
resource is never a `Requires` token: those belong in `Blocked by` or `Resource provision`. The source-bound
Haskell binary ensures phase tools lazily into `.build/**`. Python under `pb/**` may establish only the Haskell
toolchain needed to build and replace itself with that binary; it cannot resolve a phase tool or policy.

No sprint is Done merely because its isolated check runs. Its candidate must be retained by the complete
qualified parent gate; that passing parent gate makes the sprint eligible for the mechanical status update.

Within one phase, `Blocked by` orders implementation; it is not a request for confirmation between sprints. A downstream
sprint in the same phase may begin when the predecessor's deliverables exist and its declared component
diagnostics have produced the observations needed to expose any remaining work. This readiness decision
changes no status, is not candidate evidence, and is not validation. If the predecessor's implementation,
contract, oracle, or observations change, its diagnostics rerun before their result is relied on again.

For the first sprint of a later phase, the cross-phase `Blocked by` edge orders gate execution and status rather
than prohibiting all source preparation. A sprint with `Substrate: none` may be implemented ahead of the
validation frontier only after its exact typed contract and separately authored oracle have replaced the reset
inventory. That work may run bounded component diagnostics, but it cannot run the phase gate, mint candidate
evidence, use `pb` before `BOOTSTRAP_HANDOFF`, consume an absent predecessor, or create, change, or discover a
host, image, container, cluster, accelerator, provider, or other live resource. Its phase and sprint remain
Blocked — NOT VALIDATED until the immediate predecessor gate passes.

The raw blocker value is closed: Phase 0 Sprint 0.1 uses only `` `genesis` ``; a first sprint in every later
phase uses only `[Phase N](phase_NN_<slug>.md) gate pass` for the immediate predecessor; and every later
sprint uses only `Sprint N.(Y-1)`. Appended candidate, confirmation, earlier-phase, or additional-sprint prose
is a second edge and refuses the schema even when the immediate edge also appears.

Validation is consolidated at the phase gate. The qualified parent gate must rerun and retain every sprint
seam in one complete candidate run. When that gate passes, its emitted status patch may be applied by a human,
agent, or CI job after the validator exits and the bound preimage is rechecked.
Where `Blocked by` names an earlier phase rather than an earlier sprint, that dependency is the earlier gate
pass. An agent may validate, record, and continue across multiple phases in one run, but each phase still
receives its own candidate and ordered gate execution.

The `Oracle` field declares the independence boundary exercised by the consolidated phase gate. It is not an
intermediate confirmation request. An agent continues through implementation-ready sprint seams while the
work is implementation-ready.

The `Legacy IDs` field is structural plan prose, not a legacy inventory. Automation may require the field and
its exact position, but it may not parse its IDs, owner implications, cardinality, or closure wording into a
finding or verdict. The closed Haskell inventory and total owner/closure bindings govern execution; the
documentation gate compares this field and the rest of the sprint prose with those values.

**Fail-closed reset transition.** A blocked phase may temporarily retain a pre-reset sprint body only beneath
both its phase-level `Reset contract interpretation` notice and its `Reset validation check` notice. Such a
body is capability inventory, **not a sprint contract**: every omitted field above is treated as missing,
every command and validation item is non-operative, every result is inadmissible, and every path or source
format that conflicts with the current Haskell/`.build/**` rules is condemned rather than grandfathered. The
phase gate must refuse while any retained body has not been replaced wholesale with the exact sprint schema;
no line may be copied out, selectively reactivated, or used as an implementation instruction. Once rewritten,
the inventory is deleted—Git history is its only archive. Each numbered phase owns this replacement for its own
contract. Phase 0 checks the closed document inventory, required structure, and typed owner assignment, but it
does not have to implement or semantically resolve later-phase cells. A generic reset banner can block that
phase's validation but can never count as the completed phase-specific check.

---

## G. Documentation Requirements

Every phase closes with:

```markdown
## Documentation Requirements

**Engineering docs to update (after the complete gate passes, never before):**

- `documents/engineering/<owner>.md` — <the normative boundary that changes>

**Cross-references to add:**

- <required backlinks>
```

Doctrine states design intent and assumptions; it does not mirror phase status or claim a phase instance is
currently validated.

---

## H. The doctrine-citation rule (cite by name)

A phase adopts a doctrine section by relative link, section number, and human name. A filename or section
number without the section's name is insufficient context. `Docs to update` lists the same owners in gathered
form.

---

## I. Generated documentation remains untracked

All governed Markdown is human-authored and declares `Generated sections: none`. Generated tables, status
projections, link reports, inventories, run summaries, and evidence renderings are lazy outputs beneath
`.build/docs/**`. A generated report may diagnose the plan; it may not edit status or become a verdict.

Plan automation parses only closed structure: governed paths, metadata, headings, links/anchors/backlinks,
exact status syntax, numerical dependencies, sprint fields, and the fixed eighteen-row table. It never derives
a semantic contract, source/provider choice, legacy closure, or validation verdict from prose or keyword
counts. Executable cross-cutting choices live in the source-bound Haskell `PolicyContract`; phase semantics live
in separately authored Haskell declarations. The documentation gate owns prose correspondence, and a prose decoy must be
inert with respect to those executable semantics even though ordinary documentation or the disclosed
filename/content diagnostics may report a documentation finding.

The fixed Gate and tracker tables are each one exact top-level, physically contiguous Markdown frame. The
structural parser accounts for every raw candidate and retains an opaque boundary for fences, HTML blocks,
comments, indented code, lists, and blockquotes; it may not trim a container prefix, delete a malformed row, or
stitch fragments into the required inventory. Header, delimiter, cell cardinality, quoting, ordinal spelling,
row order, and the structurally closed tracker link are exact rather than prefix-normalized.

---

## J. Cross-reference path rules

- Links within `DEVELOPMENT_PLAN/` are relative paths.
- Links to doctrine use `../documents/...`.
- A rename updates every inbound link and `Referenced by` field in the same change.
- Contract-bearing phase references include the linked slug, not a bare ordinal.
- The sentence naming the next held-shut phase is derived as `N + 1`.
- No link or metadata field may reference the eliminated legacy archive.

---

## K. Honesty (proven / tested / assumed)

Every result is bounded to its model, corpus, register, substrate, observer, and source snapshot. Missing
layers are `UNVERIFIED`. A complete qualified green candidate is a passing phase gate; partial candidate
evidence is not. The current reset invalidates all prior gate evidence.

The full argument is in
[`development_plan_phase_model.md` §K](development_plan_phase_model.md#k-honesty-proven--tested--assumed).

---

## L. One-substrate discipline

Pure DSL validation runs before images and hardware and declares `Substrate: none`. A hardware phase names
one real substrate and natural lane and proves only what it observed. `Lane: provider` denotes a managed
target reached from one `Substrate: linux-cpu` parent; it is not a substrate/architecture composite and must
never be written `linux-cpu → provider` or `linux-cpu/amd64 → provider`. Container replay is later parity
evidence, never a prerequisite for the pre-hardware DSL gate.

The full argument is in
[`development_plan_phase_model.md` §L](development_plan_phase_model.md#l-one-substrate-discipline).

---

## M. Gate integrity (a gate cannot be passed by a stub)

Every phase uses the fixed eighteen-row contract from
[`development_plan_gate_integrity.md` §M.1](development_plan_gate_integrity.md#m1-the-fixed-gate-contract):
claim, subject, command, oracle, positive controls, paired negatives, mutants, discovery, challenge, observer,
authority/bypass, freshness, qualification, cleanroom, legacy closure, predecessor, residue, and pass
criterion.

A candidate is inadmissible unless the harness first rejects its phase-owned qualification corpus, required
mutants visibly change production and are rejected by their independent oracle, discovery is non-empty and
two-way complete, required freshness/authority checks fail closed, and cleanup leaves no forbidden residue.
Phase 0 has the closed finite exception in gate-integrity §M.4: its three changed sources and binaries must
differ from clean; its v2 transcript must retain a silent successful clean run and, for every mutant, exact
`ExitFailure 1`, empty stdout, and canonical case-label-plus-newline stderr.
Its `captureResidue` is empty; later-owned work is an exclusion/forward deferral, not an `UNVERIFIED` candidate
entry. Later phases retain their applicable `UNVERIFIED` layers. Once the complete gate passes, the status
update is mechanical.

Mutation scope is bounded by the claim and typed owner frontier. A milestone runs the cumulative selector
corpus owned at or before that capability; Phase 49 is the first complete hardware-free universal corpus. The
milestones are named in [`development_plan_gate_integrity.md` §M.3](development_plan_gate_integrity.md#m3-mutants-must-prove-that-they-changed-the-subject).
An ordinary gate runs exactly those selectors whose declared impact set intersects its own `Claim`,
`Positive controls`, and `Paired negatives` rows, subject to the per-deliverable and foreclosure floor. A
milestone is named as a capability, never as an ordinal.

Before an adapter has authenticated every authority its claim requires, its parser and integrity-consistent
values remain private behind an always-refusing `CheckResult`; it may not export a conventional success branch,
optional residue, arbitrary-result eliminator, or detachable observation projection. A “diagnostic” name is not
an authority boundary. Its oracle uses separately authored Haskell fixture types, literal limits, full expected
projections, and exact boundary/one-over results rather than production constructors, encoders, constants, or
shared expected lists. A green diagnostic that violates this shape is a gate defect and cannot be retained as
candidate evidence.

An execution attempt cannot supply both its evidence and the contract used to declare that evidence complete.
The expected target/operator/result/control registry is a distinct acquired authority joined to exact source and
build inputs. A process-backed claim retains one opaque bounded supervisor receipt from opened executable identity
through argv/environment policy, complete stdout/stderr capture, termination, parsing, cleanup, and fresh run
challenge; digest-shaped transcript fields or a `CheckResult` wrapped in a caller-nominated run identity are
diagnostic data only.

The full rule is in
[`development_plan_gate_integrity.md` §M](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub).

---

## N. Reopening and amending a phase

Changing a subject, oracle, contract, source boundary, or predecessor invalidates affected evidence and
returns status to a non-Done marker carrying `NOT VALIDATED`. Historical detail is minimal, explicitly
invalidated, and never reusable; Git history holds the archive.

The full rule is in
[`development_plan_phase_model.md` §N](development_plan_phase_model.md#n-reopening-and-amending-a-phase).

---

## O. Sprint-sized seams and bounded phase gates

A sprint owns one falsifiable implementation seam. A phase owns one cohesive final claim and splits on a
second final register, real substrate, or independently useful capability. The phase gate enumerates sprint
evidence; it does not replace it with a top-level success bit.

The full rule is in
[`development_plan_phase_model.md` §O](development_plan_phase_model.md#o-sprint-sized-seams-and-bounded-phase-gates).

---

## P. Plan-document shape

Plan documents inherit the shape, orientation, prose, and diagram rules in
[`documentation_standards.md`](../documents/documentation_standards.md). In addition:

1. a phase over 400 lines has `## Contents`;
2. field values stay brief and move detail to the owned section;
3. the Gate line is the canonical command plus Gate-integrity link, not a result narrative;
4. one deliverable appears per bullet; and
5. current requirements and invalidated history never share an unbounded paragraph; and
6. Contents navigation labels omit status markers, so the one current sprint heading remains the only
   heading-marker projection target.

---

## Q. The two phase diagrams

A long phase may use at most two diagrams:

1. a gate apparatus showing subject, independent oracle, changed-subject mutant, external observer,
   qualification refusal, candidate evidence, and the passing status patch; and
2. a sprint seam map showing what each sprint hands to the next.

Diagrams orient; the fixed table and sprint fields carry the enforceable rules.

---

## R. Where the cross-cutting invariants live

The ownership table is in
[`development_plan_phase_model.md` §R](development_plan_phase_model.md#r-where-the-cross-cutting-invariants-live).
No phase or doctrine document restates current status, registry choice, source-language policy, or another
cross-cutting rule as a second authority.

---

## S. Universal artifact-hygiene gate

Every gate inherits the eighteen source/artifact postconditions in
[`development_plan_gate_integrity.md` §S](development_plan_gate_integrity.md#s-universal-source-and-artifact-hygiene-gate).
They include the closed Haskell source language, bounded `pb/**` exception, semantic source scan, lazy
generation beneath `.build/**`, clean-snapshot closure, absence of condemned fallbacks, tracked-tree
immutability, containment, complete discovery, exact accounting against strictly-later typed Haskell legacy
bindings, zero findings for the candidate phase's due bindings, predecessor gate pass, and the rule that
partial evidence is not a gate pass. A later-owned binding records temporary observed debt; it is not permission to add
or consume that source. The reader-facing register explains those bindings but supplies no executable value.
The transition expires before the gate cut: Phase 49 requires every `LTD-SRC-*` query, including
Phase-2-owned `LTD-SRC-008`, to be zero. Phase 0 first requires a scoped `SourcePb` zero for its captured
bootstrap source without retiring that binding. The only non-Haskell behavioral source then remaining is `pb/**`
Python positively classified by the deny-by-default Haskell grammar as minimal platform discrimination,
contained toolchain establishment, source-bound build, and opaque exec handoff. Phase 50 validates that
already-bounded runtime handoff and owns no source-migration binding; Phase 51 onward retains the same grammar.
Hardware therefore cannot begin with condemned tracked source present.

---

## T. Plan-to-implementation reconciliation

The plan, doctrine, implementation, and evidence are separate inputs. Current mismatches have executable
identity, owner, observation, closure, and reintroduction bindings only in tested Haskell. The single
`legacy_tracking_for_deletion.md` file explains that active inventory to readers; the documentation gate
owns its agreement with Haskell. Its legacy-specific structural seam may enforce canonical file cardinality,
UTF-8 readability, and archive absence, while the general documentation checker may enforce ordinary
document structure plus its basename-substring cardinality and forbidden-archive-basename content diagnostics.
Neither may interpret row content or count as legacy semantics or use it in a closure
verdict. Closed explanations are deleted after the corresponding passing Haskell transition; Git history is
the archive.

The full rule is in
[`development_plan_gate_integrity.md` §T](development_plan_gate_integrity.md#t-plan-to-implementation-reconciliation).

---

## U. The final repository layout

The final tree is normative. Behavioural source is Haskell; the only non-Haskell source is bounded bootstrap
code under `pb/**`; every reproducible non-Haskell artifact is generated lazily beneath `.build/**`. A phase
does not introduce provisional roots or phase-numbered implementation paths.

The full rule is in
[`development_plan_gate_integrity.md` §U](development_plan_gate_integrity.md#u-the-final-repository-layout).

---

## Related Documents

- [Development-plan tracker](README.md)
- [Phase model](development_plan_phase_model.md)
- [Gate integrity and repository closure](development_plan_gate_integrity.md)
- [Reader-facing legacy register](legacy_tracking_for_deletion.md) — prose correspondence, not executable
  inventory or closure authority
- [Documentation standards](../documents/documentation_standards.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
