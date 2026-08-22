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
| `legacy_tracking_for_deletion.md` | The one active implementation/plan divergence register |
| `phase_NN_<slug>.md` | One contract per contiguous numbered phase |
| `later_phases.md` | Unnumbered future intent only |

There is one legacy register only. Closed and superseded rows are deleted; Git history is
the archive. No other file may become a second deletion register.

All planned implementation paths name authored `.hs` source. The sole non-Haskell source exception is
`pb/**`, whose bootstrap-only scope is closed by [§S](#s-universal-artifact-hygiene-gate). Reproducible
non-Haskell material is a lazy `.build/**` product and never an `Implementation` path.

---

## C. Status vocabulary

The five markers and their mandatory wording are defined in
[`development_plan_phase_model.md` §C](development_plan_phase_model.md#c-status-vocabulary). Every non-Done
phase and sprint says `NOT VALIDATED`. Only a human user may promote to ✅ Done; gates and agents may produce
only a `Validation candidate`.

At this reset, Phase 0 is `🔄 Active — NOT VALIDATED`; every later numbered phase is
`⏸️ Blocked — NOT VALIDATED` pending its immediate predecessor's human approval. No prior completion claim,
seal, hash, receipt, attestation, or status survives as current evidence.

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
**Depends on:** <linked immediate predecessor plus additional earlier dependencies, or genesis for Phase 0>
**Gate:** `pb validate phase NN`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity
<the exact §M table; required>

## Resource provision — <optional suffix>
<required only when the gate provisions external/live resources>

## Doctrine adopted
## Sprints
## Documentation Requirements
## Related Documents
```

The six Phase Summary fields are required, closed, and ordered exactly as shown. The Gate line is a target
command, not an assertion that it exists or passes. The Haskell binary decides the candidate verdict; `pb`
may only make the minimal platform distinction, establish the contained toolchain, build the source-bound
binary, and exec that exact binary with every argument unchanged. A Python or shell phase-gate command is
non-conforming.

`## Gate integrity` is mandatory for every phase, including documentation-only Phase 0. Its fixed table makes
missing trust boundaries mechanically visible; prose, a diagram, or a link to a generic runner cannot replace
it. `## Resource provision` is the only optional section between Gate integrity and Doctrine adopted.

A phase that may create, change, retain, or delete a process, host, VM, container, cluster, namespace, cloud
object, credential binding, volume, mount, device allocation, network object, or other live/external state must
include `## Resource provision`. A resolved section has exactly these closed labels:

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

These labels are structural only. Executable meaning lives in a separately reviewed Haskell
`ResourceProvisionContract`, its effect interpreter, and an independent observer; Markdown cannot authorize a
mutation or establish cleanup. If any field or implementation is missing, the heading is exactly
`## Resource provision — UNRESOLVED`, its first blockquote begins
`**UNRESOLVED — blocks validation.** No live mutation is authorized.`, and all following detail is
non-operative capability inventory. A descriptive capacity envelope, teardown intention, or successful
command cannot substitute for this contract.

---

## E. One canonical phase model

Phases are contiguous and considered in numerical order. Every gate after Phase 0 binds the immediately
preceding human approval. Phase 49 is the no-hardware end-to-end DSL promotion barrier; no fake-host takeover,
hardware bring-up, container, registry, cluster, GPU, or cloud evidence may open before it is human-approved.

The full argument is in
[`development_plan_phase_model.md` §E](development_plan_phase_model.md#e-one-canonical-phase-model).

---

## F. The sprint block format

Each sprint uses this exact header and field set:

```markdown
## Sprint N.Y: <Name> ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: <authored .hs path, documentation path, or pb/** bootstrap path>
**Blocked by**: <immediate prior sprint or earlier phase approval; genesis only where true>
**Requires**: <`natural-linux-cpu-amd64-host` | `disposable-linux-cpu-amd64-host`; omit if none>
**Independent Validation**: <one falsifiable seam; never merely the parent gate>
**Oracle**: <separate .hs module, independence boundary, and human reviewer>
**Legacy IDs**: <owned active rows, or `none` with the zero-finding query>
**Docs to update**: <governed doctrine owners>

### Objective
### Deliverables
### Validation
### Remaining Work
```

For behavioural work, `Implementation` and `Oracle` are `.hs`. A sprint may name `pb/**` only when its
objective is within the bootstrap exception; Python tests, gate logic, source-policy logic, product logic, or
oracle logic are never admitted there.

`Independent Validation` names the seam's positive control, paired specific-reason negative, changed-subject
mutant, and residue. The expanded numbered Validation list may provide detail. A command exit code, parent
gate reference, test count, fixture existence, or hash comparison alone is insufficient.

`Blocked by` names plan work. `Requires` names only an environmental fact no phase can build. Its current
closed vocabulary is `natural-linux-cpu-amd64-host` and `disposable-linux-cpu-amd64-host`; a new fact requires
a reviewed standards amendment before use. A tool, predecessor capability, prior sprint output, or same-run
resource is never a `Requires` token: those belong in `Blocked by` or `Resource provision`, while `pb` or the
Haskell binary ensures tools lazily into `.build/**`.

No sprint is Done merely because its isolated check runs. Its candidate must be retained by the qualified
parent gate, reviewed by the human authority, and promoted by that human.

**Fail-closed reset transition.** A blocked phase may temporarily retain a pre-reset sprint body only beneath
both its phase-level `Reset contract interpretation` notice and its `Reset validation review` notice. Such a
body is capability inventory, **not a sprint contract**: every omitted field above is treated as missing,
every command and validation item is non-operative, every result is inadmissible, and every path or source
format that conflicts with the current Haskell/`.build/**` rules is condemned rather than grandfathered. The
phase gate must refuse while any retained body has not been replaced wholesale with the exact sprint schema;
no line may be copied out, selectively reactivated, or used as an implementation instruction. Once rewritten,
the inventory is deleted—Git history is its only archive. Phase 0 Sprint 0.7 owns this review across all
numbered phases, so a generic reset banner can block validation but can never count as the completed review.

---

## G. Documentation Requirements

Every phase closes with:

```markdown
## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

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
`.build/docs/**`. A generated report may diagnose the plan; it may not edit status or become approval.

Plan automation parses only closed structure: governed paths, metadata, headings, links/anchors/backlinks,
exact status syntax, numerical dependencies, sprint fields, and the fixed eighteen-row table. It never derives
a semantic contract, source/provider choice, legacy closure, or validation verdict from prose or keyword
counts. Executable cross-cutting choices live in the reviewed Haskell `PolicyContract`; phase semantics live
in separately reviewed Haskell declarations. Human review owns prose correspondence, and a prose decoy must
be behaviorally inert.

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
layers are `UNVERIFIED`. Candidate evidence is never a status decision. The current reset invalidates all
prior evidence for promotion.

The full argument is in
[`development_plan_phase_model.md` §K](development_plan_phase_model.md#k-honesty-proven--tested--assumed).

---

## L. One-substrate discipline

Pure DSL validation runs before images and hardware and declares `Substrate: none`. A hardware phase names
one real substrate and natural lane and proves only what it observed. `Lane: provider` denotes a managed
target reached from one `Substrate: linux-cpu` parent; it is not a substrate/architecture composite and must
never be written `linux-cpu → provider` or `linux-cpu/amd64 → provider`. Container replay is later parity
evidence, never a prerequisite or authority for the pre-hardware DSL gate.

The full argument is in
[`development_plan_phase_model.md` §L](development_plan_phase_model.md#l-one-substrate-discipline).

---

## M. Gate integrity (a gate cannot be passed by a stub)

Every phase uses the fixed eighteen-row contract from
[`development_plan_gate_integrity.md` §M.1](development_plan_gate_integrity.md#m1-the-fixed-gate-contract):
claim, subject, command, oracle, positive controls, paired negatives, mutants, discovery, challenge, observer,
authority/bypass, freshness, qualification, cleanroom, legacy closure, predecessor, residue, and human
authority.

A candidate is inadmissible unless the harness first rejects the qualification sabotage corpus, each mutant
is observed to change the intended production locus and redden the intended oracle, discovery is non-empty and
two-way complete, stale evidence and self-reporting fail, and cleanup leaves no residue. The human validation
authority alone promotes status.

The full rule is in
[`development_plan_gate_integrity.md` §M](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-authorize-itself).

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
5. current requirements and invalidated history never share an unbounded paragraph.

---

## Q. The two phase diagrams

A long phase may use at most two diagrams:

1. a gate apparatus showing subject, independent oracle, changed-subject mutant, external observer,
   qualification refusal, candidate evidence, and human promotion; and
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
immutability, containment, complete discovery, exact accounting of strictly-later migration rows, zero
findings for the candidate phase's owned rows, predecessor approval, and the rule that evidence is not
authority. A later-owned row is temporary observed debt, not permission to add or consume that source. The
transition expires before the promotion cut: Phase 49 requires every `LTD-SRC-*` query, including
Phase-0-owned `LTD-SRC-008`, to be zero. The only non-Haskell behavioral source then remaining is `pb/**`
Python positively classified by the deny-by-default Haskell grammar as minimal platform discrimination,
contained toolchain establishment, source-bound build, and opaque exec handoff. Phase 50 validates that
already-bounded runtime handoff and owns no source-migration row; Phase 51 onward retains the same grammar.
Hardware therefore cannot begin with condemned tracked source present.

---

## T. Plan-to-implementation reconciliation

The plan, doctrine, implementation, and evidence are separate inputs. Current mismatches live only in
`legacy_tracking_for_deletion.md` with stable ID, owner, detection command, and executable closure. Closed rows
are deleted; Git history is the archive.

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
- [Active legacy register](legacy_tracking_for_deletion.md)
- [Documentation standards](../documents/documentation_standards.md)
- [Repository layout doctrine](../documents/engineering/repository_layout_doctrine.md)
