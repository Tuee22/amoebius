# Development Plan Standards

> **Purpose**: The rulebook for the amoebius `DEVELOPMENT_PLAN/` suite — the canonical file layout, the
> per-phase and per-sprint document formats, the status vocabulary, the doctrine-citation rule, and the
> honesty, implementation-reconciliation, and one-substrate disciplines every plan document obeys.
> **Read this if**: a plan document is being written or reviewed, or a phase gate has to be judged sufficient.

This rulebook governs the plan suite: the per-phase skeleton, the sprint format, the status vocabulary, and
the gate-integrity clauses a gate must satisfy before it can be trusted. The tracker owns order, status, and
the dated implementation-progress audit;
each phase document owns that phase's human-authored validation contract. It inherits header and link mechanics
from [`../documents/documentation_standards.md`](../documents/documentation_standards.md), which wins on
those; this document wins on plan structure. It owns no phase status, which belongs to
[README.md](README.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_gate_integrity.md, DEVELOPMENT_PLAN/development_plan_phase_model.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion_archive.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_repository_layout_conformance.md, DEVELOPMENT_PLAN/phase_08_scope_index.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_11_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_16_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_17_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_18_dsl_formal_model.md, DEVELOPMENT_PLAN/phase_19_reconcile_core_simulation.md, DEVELOPMENT_PLAN/phase_25_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_27_illegal_state_covering.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md, DEVELOPMENT_PLAN/phase_31_provision_seal.md, DEVELOPMENT_PLAN/phase_32_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_33_render_manifest_oracles.md, DEVELOPMENT_PLAN/phase_34_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_37_ui_program_schema.md, DEVELOPMENT_PLAN/phase_38_ui_authorization_kernel.md, DEVELOPMENT_PLAN/phase_39_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_40_ui_plan_compiler.md, DEVELOPMENT_PLAN/phase_41_offline_language_plan.md, DEVELOPMENT_PLAN/phase_42_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_43_ui_server_boundary.md, DEVELOPMENT_PLAN/phase_44_ui_local_composition.md, DEVELOPMENT_PLAN/phase_45_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_48_test_workflow_algebra.md, DEVELOPMENT_PLAN/phase_55_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_57_complementary_arch_child.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md, DEVELOPMENT_PLAN/phase_59_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_60_retained_storage.md, DEVELOPMENT_PLAN/phase_61_vault_pki.md, DEVELOPMENT_PLAN/phase_62_platform_backbone.md, DEVELOPMENT_PLAN/phase_63_platform_services_2.md, DEVELOPMENT_PLAN/phase_64_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_65_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_66_app_tenancy.md, DEVELOPMENT_PLAN/phase_67_pulsar_client.md, DEVELOPMENT_PLAN/phase_68_user_tenant_isolation_live.md, DEVELOPMENT_PLAN/phase_69_content_store_workflow.md, DEVELOPMENT_PLAN/phase_70_ui_projection_runtime.md, DEVELOPMENT_PLAN/phase_71_release_lifecycle.md, DEVELOPMENT_PLAN/phase_72_ui_program_release.md, DEVELOPMENT_PLAN/phase_73_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_75_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_76_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_77_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_78_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_79_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_81_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_82_ui_multi_tenant_live.md, DEVELOPMENT_PLAN/phase_83_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_84_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_85_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_86_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_87_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_88_offline_multizone_continuity.md, DEVELOPMENT_PLAN/phase_89_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_91_infernix_rederivation.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md, DEVELOPMENT_PLAN/phase_94_jitml_ui_rederivation.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, documents/documentation_standards.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/glossary.md, documents/reading_order.md
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

Tone and the design-choice motivation structure follow
[`../documents/documentation_standards.md` §8–§9](../documents/documentation_standards.md#8-tone-and-voice);
this document adds no plan-specific register rules.

---

## A. Header metadata (same block as the doctrine suite)

Every file in `DEVELOPMENT_PLAN/` opens with the standard block from
[`documents/documentation_standards.md` §3](../documents/documentation_standards.md#3-required-header-metadata):

```markdown
# <Title>

> **Purpose**: <one sentence>
> **Read this if**: <the reader, and what that reader can do afterwards>

<the lead: what this document owns, what it does not, the one prerequisite>

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: <comma-separated relative links to docs that link here>
**Generated sections**: none

</details>
```

- `**Referenced by**` lists the **actual** inbound links (bidirectional rule, [documentation_standards.md §4](../documents/documentation_standards.md#4-cross-referencing)) —
  not a blanket "everything." It is reconciled from the true link graph, never hand-guessed.
- `**Generated sections**` is always `none`. Generated Markdown lives under ignored `.build/docs/`, never in the
  governed plan suite ([§I](#i-generated-documentation-remains-untracked)).
- `**Status**` is `Authoritative source` for every plan doc (the plan is the SSoT for sequencing/status);
  the README is additionally the *live tracker*.

## B. Canonical file layout (snake_case)

`DEVELOPMENT_PLAN/` uses **`snake_case.md`** for every file (per [documentation_standards.md §2](../documents/documentation_standards.md#2-naming); the only ALL-CAPS exception is `README.md`). The canonical set:

| File | Role |
|------|------|
| `README.md` | Live tracker + index: document index, phase order, status vocabulary, and Definition of Done. |
| `development_plan_standards.md` | This rulebook's hub: it keeps every section heading and anchor, and carries the argument for the sections it did not move out. |
| `development_plan_phase_model.md` | Family slice: the status and progress vocabularies, the phase model, honesty, one-substrate discipline, reopening and re-baselining, seam sizing, and invariant ownership. |
| `development_plan_gate_integrity.md` | Family slice: gate integrity, the universal artifact-hygiene postcondition, plan-to-implementation reconciliation, and the final repository layout. |
| `overview.md` | Target architecture / vision / current-baseline narrative (the "why/what"). |
| `system_components.md` | Target component inventory: surface → owning doctrine → planned module path. |
| `substrates.md` | Authored substrate registry and per-phase substrate map. Generated views go to `.build/docs/`. |
| `legacy_tracking_for_deletion.md` | The implementation/plan divergence and migration-removal ledger: observed mismatch, owner, and closure condition. |
| `phase_NN_<slug>.md` | One document per phase, zero-padded `NN` for sort order (`phase_00_documentation_suite.md` … `phase_88_offline_multizone_continuity.md`). |
| `later_phases.md` | The in-scope, high-numbered phases not yet given their own document. |

This deviates from prodbox's hyphenated names (`phase-51-gateway-dns.md`) on purpose: amoebius's
documentation standard mandates snake_case. The *structure* mirrors prodbox; the *naming* follows amoebius.

**Generated artifacts are never a committed module path.** A phase's `Implementation` field
([§F](#f-the-sprint-block-format)) names authored source, never a generated artifact, lock/freeze file,
resolver result, evidence file, or run ledger. The complete rule is owned by
[`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md).

**This section governs `DEVELOPMENT_PLAN/` only.** The repository's own layout — every root, its
justification, and the rule that no phase creates a path outside it — is owned by
[§U](#u-the-final-repository-layout) and
[`repository_layout_doctrine.md` §2](../documents/engineering/repository_layout_doctrine.md#2-complete-repository-structure); a phase's `Implementation` names a path from that tree.

## C. Status vocabulary

Five status markers — ✅ Done, 🔄 Active, 📋 Planned, ⏸️ Blocked, 🧪 Live-proof pending — and a separate
progress vocabulary for what a dated inspection can actually find. Status is a gate decision; progress is an
observation, and only `Policy-conformant` is compatible with ✅ Done. Status lives only in the plan, never in
a doctrine document.

The argument is carried by [`development_plan_phase_model.md`](development_plan_phase_model.md#c-status-vocabulary).

---

## D. The per-phase document skeleton

Every `phase_NN_<slug>.md` follows this skeleton:

```markdown
# Phase N: <Title>
<the orientation block of [§A](#a-header-metadata-same-block-as-the-doctrine-suite)>

## Contents                  (where §P.1 requires one)

## Phase Status
📋 Planned. <one-line summary; reverse-chronological dated entries once work begins>

## Phase Summary
<what this phase owns, declarative; the objective and scope>
**Phase scope:** <one cohesive capability claim, its sprint seams, one acceptance command, and the explicit split trigger>
**Substrate:** <none | apple | linux-cpu | linux-cuda | windows> ([§L](#l-one-substrate-discipline))
**Lane:** <none | linux-cpu/amd64 | linux-cpu/arm64 | metal | cuda> ([§L](#l-one-substrate-discipline))
**Register:** <1 pure/golden · 2 boundary-with-fakes · 3 live · 1/2 only for Phase 34 · — for Phase 0> ([§K](#k-honesty-proven--tested--assumed))
**Depends on:** <[Phase M](phase_MM_<slug>.md) — why, for each; or `none`> ([§F](#f-the-sprint-block))
**Gate:** <the concrete acceptance test that must pass before the next phase opens; §S applies implicitly>

## Gate integrity            (optional; see below)
## Resource provision — …    (optional, live band; see below)
## Doctrine adopted
<the engineering doctrine sections this phase implements, each cited by name + anchor (§H)>

## Sprints
## Sprint N.1: <Name> 📋
...

## Documentation Requirements
## Related Documents
```

`Phase Summary` is declarative present tense ("this phase stands up …"), not a promise log. The **Gate** is a
single, checkable acceptance condition — ideally an `InForceSpec` topology that spins resources up, runs a
workflow, and tears them down. Every gate also inherits the source-snapshot, generated-output, and target-tree
postconditions of [§S](#s-universal-artifact-hygiene-gate) and [§U](#u-the-final-repository-layout), without
duplicating them in the phase documents. The enforceable sizing rules are owned by
[§O](#o-sprint-sized-seams-and-bounded-phase-gates) and apply independently of what the summary says.

**The six Phase Summary fields are required, and the set is closed.** `Phase scope`, `Substrate`, `Lane`,
`Register`, `Depends on`, and `Gate`, in that order, each on its own line with the colon **inside** the bold.
Two of them were previously written as optional, and the cost of that was measurable: `Phase scope` was absent
from sixty-four contracts and `Depends on` from fifty-seven, and nothing reported either, because no check
reads them. A field that is optional in the skeleton and unchecked by the lint is a field that does not exist.
The legacy **Session scope** note is retired; a phase that carried one states its claim as `Phase scope`.

**Two optional sections have fixed slots and fixed names**, both in the gate-detail block between
`## Phase Summary` and `## Doctrine adopted`, in this order. A phase whose gate-integrity apparatus (the
committed representative set, oracle pins, and seeded mutants of [§M](#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub))
is too large to sit inline in the `**Gate:**` paragraph places it in a **`## Gate integrity`** section; the
`**Gate:**` line then delegates to it by anchor (permitted by
[§M](#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)). A live-band phase that itemises the complete
resource envelope its gate provisions places it in a **`## Resource provision`** section, whose heading takes a
fixed `## Resource provision` prefix and an optional ` — <phrase>` suffix naming what is provisioned. The
**`## Gate integrity`** name is exact — a literal `## N.` heading, using the letter `N` as a section id, is not
admitted (it collides with the `Phase N` placeholder above). Neither section is required; a phase whose gate
fits inline and provisions nothing worth itemising needs neither.

```mermaid
flowchart LR
  %% register: orientation
  o["the orientation block"]
  c["## Contents"]
  st["## Phase Status"]
  su["## Phase Summary"]
  gi["## Gate integrity"]
  da["## Doctrine adopted"]
  sp["## Sprints"]
  dr["## Documentation Requirements"]
  rd["## Related Documents"]
  o -->|"then"| c
  c -->|"then"| st
  st -->|"then"| su
  su -->|"then, optional, in this fixed slot"| gi
  gi -->|"then"| da
  da -->|"then"| sp
  sp -->|"then"| dr
  dr -->|"then"| rd
```
*Orientation. Design intent. The per-phase skeleton [§D](#d-the-per-phase-document-skeleton) fixes, in order. The slots are positional: a conforming lint reads the span between the summary's gate line and the doctrine section for the gate apparatus, so nothing else may be placed there.*

## E. One canonical phase model

Phases are `0..N`, contiguous, with no fractional id. A re-baseline may reorder or split them at any time
provided the same change carries a full audit map. A sprint belongs to exactly one phase, and no sprint's
`Blocked by` names a later phase.

The argument is carried by [`development_plan_phase_model.md`](development_plan_phase_model.md#e-one-canonical-phase-model).

---

## F. The sprint block format

Each `## Sprint N.Y: <Name> <marker>` carries this header then these sections:

```markdown
## Sprint N.2: <Name> 📋

**Status**: Planned
**Implementation**: <planned module path(s)> (required, becomes concrete when Done)
**Blocked by**: <earlier sprint id | earlier phase gate | none>
**Requires**: <environment precondition(s) no phase builds | omit if none>
**Independent Validation**: <how this sprint is checked on its own>
**Docs to update**: <the governed documents/engineering/*.md this sprint must keep in sync>

### Objective
Adopt <doctrine section cited by name, §H>; <what this sprint delivers>.

### Deliverables
- <typed, checkable outputs>

### Validation
1. <how to prove it>

### Remaining Work
<for a Planned sprint: the whole sprint; for Done: "None.">
```

`Implementation` for a Planned sprint names the **target** module path (the intended layout from
[`system_components.md`](system_components.md)), honestly marked as not-yet-built. That path lies inside the
target tree of [§U](#u-the-final-repository-layout); a sprint whose implementation needs a path the tree does
not contain amends the tree in the same documentation change, and never names a provisional one.

**`Blocked by` and `Requires` are different obligations, and conflating them is what makes a plan look
unbuildable when it is not.**

- **`Blocked by`** names **phases and sprints only**, and never one later than itself. It is the
  numerical-order contract: a phase's gate may consume only what a phase ≤ its own number delivers.
- **`Depends on`** is the **phase-scope** twin of `Blocked by`, and sits in `Phase Summary` beside
  `Substrate` / `Lane` / `Register` / `Gate`. `Blocked by` is a *sprint* field, so before this field existed a
  phase-level prerequisite could only be stated by repeating it on every sprint or by an undeclared field the
  lint could not read. Its content is closed to `Phase N` tokens and `none`, and check `f4` parses it into the
  dependency graph. The retired `Prerequisites satisfied` field is folded into it: "satisfied" is a *status*
  claim, and [§C](#c-status-vocabulary) confines status to the tracker and `## Phase Status`.
- **`Requires`** names an **environment precondition** — a fact about the host, account, or developer
  machine that *no phase builds and none ever will*, because it is not amoebius's to build. It is declared
  so it is checked at gate start rather than assumed, exactly as the substrate is
  ([`substrates.md` §2](substrates.md#2-substrate-inventory) owns the substrate half of the same idea).

| `Requires` precondition | What it is | Declared by |
|---|---|---|
| `cloud-account` | A credentialed provider account carrying the quota and permissions the `Managed Eks` registry entry names | Phases 76, 77, 78, 79, 48, 84, 88 |
| `host-floor` | The per-substrate floor of [`substrate_doctrine.md` §3.1](../documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply) — the package-manager root, a hardware or firmware fact, and nothing else. Named here, defined there | Phases 1, 2, 50, 51, 35, 52, 53, 54, 25, 26, 93, 57 |

**A tool is never a `Requires` precondition.** A tool with a supported install plan is *ensured*: probed,
installed when absent, resolved to an absolute path, and invoked by it
([`substrate_doctrine.md` §3](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)).
The retired `host-toolchain` token named six binaries this way, two of which the resolver was already
acquiring; the retired `accelerator-device-plugin` token named a DaemonSet the reconciler renders like every
other operator install. Both are gone, and what remains is the floor, which no phase can build because it is
the ground a phase stands on.

No phase requires a live public DNS zone: [`phase_64`](phase_64_keycloak_ingress.md) accepts a local ACME
chain in place of public issuance, and Phase 17's `dnsRecord` TTLs are model parameters, not live records.

**The table is the vocabulary, and the lint reads it.** The closed token set is this table's first column,
parsed rather than restated in code, and the `Declared by` column joins to the phase documents in both
directions: a token no phase declares is stale, and a phase declaring a token this table does not list, or
declaring one whose row omits it, is a defect ([§M](#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)).

Together they make numerical-order developability decidable: **every artifact a gate names is either
delivered by a phase ≤ its own number, or declared under `Requires`.** An artifact that is neither is an
orphan prerequisite and a defect — not a reason to invent a new owner phase.

**The four `###` sub-headings repeat once per sprint, so their anchors collide — and that is expected.**
`Objective`, `Deliverables`, `Validation`, and `Remaining Work` appear in every sprint block, so GitHub mints
`#objective`, `#objective-1`, `#objective-2`, … in document order. Those suffixed anchors are **positional and therefore unstable**: inserting a sprint renumbers every later one. Consequently **none of the four is ever a link target**. A reference to a sprint's content cites the sprint itself — the `## Sprint N.Y: <Name>` heading,
whose anchor is unique and stable — and never one of its sub-headings. A documentation lint that checks for
duplicate heading slugs **exempts these four names inside `phase_NN_*.md`**; a collision among them is
conformant, not a defect.

## G. Documentation Requirements

Every phase doc ends its body with an explicit doc-sync block so doctrine and plan never drift:

```markdown
## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/<doc>.md` — <what changes when this phase lands>

**Cross-references to add:**
- <backlinks to add>
```

The parenthetical on the `**Engineering docs to update**` label is **required**, not decorative: it carries
the [§K](#k-honesty-proven--tested--assumed) honesty rule that a doctrine doc's verification layer is flipped
only when the phase gate actually runs on its substrate, never on merge. The bare label without it is
non-conforming.

## H. The doctrine-citation rule (cite by name)

A sprint or phase that schedules adoption work **cites the doctrine section by name**: a relative link
`../documents/engineering/<doc>.md#<section-anchor>` *and* the section's human name in the surrounding
prose. Example:

> Adopt [`manifest_generation_doctrine.md` §5 — the apply/reconcile engine](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-snapshot-bound-typed-actions):
> a server-side-apply reconciler with a fixed `amoebius` field manager and ApplySet pruning.

The `Docs to update` field then lists exactly those governed docs. A phase doc's **Doctrine adopted** section
is the gathered list of every section the phase implements — this is the spine that keeps the plan and the
doctrine suite in lockstep.

## I. Generated documentation remains untracked

Every governed plan document is a human-authored input and declares `**Generated sections**: none`.
Tool-produced tables, indexes, dashboards, contents blocks, status projections, and run summaries are written
only below ignored `.build/docs/`. They may be inspected or published from CI, but they are never copied into a
tracked Markdown file.

A table that must remain in a phase contract is authored and reviewed as a requirement. A table that can be
regenerated from code, a phase contract, repository discovery, or an evidence store is generated output and
belongs in `.build/docs/`. This rule removes generated-marker fences from the version-controlled corpus.

## J. Cross-reference path rules

- Links **within** `DEVELOPMENT_PLAN/` use plain relative paths (`README.md`, `phase_51_…md`).
- Links to governed doctrine under `documents/` use the parent-relative path
  (`../documents/engineering/<doc>.md#<anchor>`).
- A rename updates every inbound link in the same change; the `Referenced by` headers are reconciled from the
  true link graph afterward.
- **A contract-bearing reference carries its slug.** In `Depends on`, `Dependency`, and `Blocked by`, a phase
  is named as a link, never as a bare ordinal. The slug is the injective key and the ordinal is a view derived
  from it, so a linked reference is revalidated on every run by `u3` while a bare one is checked by nothing —
  which is how three successive re-baselines each left stale ordinals behind. `f5` enforces this. Narrative
  prose is deliberately outside the rule: a paragraph may name a phase by number.
- **A gate's successor clause names `own + 1`.** The sentence that says which phase a gate holds shut is
  derived from this document's own ordinal, so `f5` recomputes rather than trusts it. Written bare, the clause
  survives an insertion unchanged and silently redirects at whatever phase inherits the number.

## K. Honesty (proven / tested / assumed)

The proven/tested/assumed vocabulary and the rule that a pure result never claims a runtime property. An
applicable layer a run did not reach is UNVERIFIED, which is a statement, not an omission.

The argument is carried by [`development_plan_phase_model.md`](development_plan_phase_model.md#k-honesty-proven--tested--assumed).

---

## L. One-substrate discipline

Every gate names one substrate from the closed catalogue, and at most one specialized lane beyond the
`linux-cpu` baseline. The baseline never substitutes for a specialized claim. A lane is named with its
architecture — the substrate's natural one — and no gate emulates or cross-builds another.

The argument is carried by [`development_plan_phase_model.md`](development_plan_phase_model.md#l-one-substrate-discipline).

---

## M. Gate integrity (a gate cannot be passed by a stub)

Thirteen clauses a gate must satisfy before it can be trusted: independent oracle provenance, a committed
mutation quota, independent reference predicates, generator coverage, external-observer traces, determinism
honesty, a concrete corpus, specific-reason negatives, fresh-challenge binding, authenticated observer
provenance, authority-paired security checks, bypass-path negatives, and extension-conformance discharge. A
gate a stub can pass is not a gate.

The argument is carried by [`development_plan_gate_integrity.md`](development_plan_gate_integrity.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub).

---

## N. Reopening and amending a phase

Reopening is permitted, and a reopened phase may change its validation criteria outright. Three invariants
bound every reopen and re-baseline: one cohesive development narrative, no later phase contradicting or
undoing earlier work, and completability in numerical order. Every reopen is recorded in that phase's status
block, and whatever it condemns takes a row in the divergence register.

The argument is carried by [`development_plan_phase_model.md`](development_plan_phase_model.md#n-reopening-and-amending-a-phase).

---

## O. Sprint-sized seams and bounded phase gates

What forces a phase split — a second final register, a second substrate, or an independently useful
acceptance claim — and how a sprint seam is sized so a gate stays bounded.

The argument is carried by [`development_plan_phase_model.md`](development_plan_phase_model.md#o-sprint-sized-seams-and-bounded-phase-gates).

---

## P. Plan-document shape

The plan suite inherits [documentation_standards.md §10](../documents/documentation_standards.md#10-document-shape),
[§11](../documents/documentation_standards.md#11-the-orientation-block), and
[§13](../documents/documentation_standards.md#13-sentence-and-paragraph-budget) whole, and specializes them here.

1. **Contents.** The skeleton of [§D](#d-the-per-phase-document-skeleton) gains `## Contents` between the
   orientation block and `## Phase Status`. It never sits between the `**Gate:**` line and
   `## Doctrine adopted`, because a conforming lint reads exactly that span for the gate apparatus.
2. **Fields are fields, not essays.** `**Independent Validation**`, `**Blocked by**`, and `**Docs to update**`
   carry at most **60 words** each. A validation needing more is a numbered `### Validation` list.
3. **`**Gate:**` carries at most 45 words** and states one checkable acceptance condition. Its apparatus is
   delegated by anchor to `## Gate integrity`, which [§M](#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
   already reserves for exactly that.
4. **One deliverable per item.** A `### Deliverables` entry states one deliverable. An entry that enumerates a
   schema is a table or a fenced block, never a bullet: a list item that spells out dozens of type names as
   prose can be neither reviewed nor diffed.

---

## Q. The two phase diagrams

A phase document over 400 lines carries at least one of two sanctioned diagrams, and **at most one of each**.
A third is noise in a work plan.

1. **The gate-apparatus diagram** sits in `## Gate integrity`, or immediately beneath the `**Gate:**` line
   where the phase has no separate integrity section. Its node set is fixed: the committed fixtures and the
   pinned oracle, the seeded mutant, the gate itself, the pass path to the phase seal, and the mutant path to
   a refusal. It exists to make an under-specified gate visible as a missing node.
2. **The sprint-seam map** shows which sprint produces what the next consumes, ending at the gate. It is an
   orientation diagram, and it is what satisfies the register-balance floor of
   [`../documents/engineering/diagram_conventions.md` §10](../documents/engineering/diagram_conventions.md#10-the-diagram-quota)
   for a phase document long enough to owe one.

Neither adds a rule of its own. [§M](#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub) states every
obligation the first draws, [§F](#f-the-sprint-block-format) every seam the second draws, and per
[documentation_standards.md §7](../documents/documentation_standards.md#7-diagrams) a diagram is never the
sole statement of one.

---

## R. Where the cross-cutting invariants live

Which document owns each cross-cutting invariant, so a reader knows where to look and an author knows where
not to restate it.

The argument is carried by [`development_plan_phase_model.md`](development_plan_phase_model.md#r-where-the-cross-cutting-invariants-live).

---

## S. Universal artifact-hygiene gate

<a id="s-commit-timing"></a>
<a id="gate-integrity-delegation"></a>

Sixteen postconditions every gate inherits on top of its own capability check: the source-snapshot binding,
run-time surface enumeration, generated output confined to `.build/**`, production state confined to
`.data/**`, test state confined to marker-owned `.test_data/**`, `test-secrets.dhall` rejected by production,
the authored-root write guard, the repository-local attestation, the host inventory, the target-tree
partition, the recorded natural architecture, and the illegal-state covering. Commit timing is never a gate
input.

The argument is carried by [`development_plan_gate_integrity.md`](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate).

---

## T. Plan-to-implementation reconciliation

Nine rules for reconciling plan, implementation, tests, and historical evidence, none of which is presumed
correct merely because it exists — and the requirement that every divergence takes a row in the register with
an owner and a closure condition.

The argument is carried by [`development_plan_gate_integrity.md`](development_plan_gate_integrity.md#t-plan-to-implementation-reconciliation).

---

## U. The final repository layout

One target tree, normative and owned by Phase 0. No phase creates a path outside it; everything this
repository's source, checks, tests, or gates produce is ignored by both contracts; no directory or filename
carries a phase ordinal; and every root is justified by what its contents are.

The argument is carried by [`development_plan_gate_integrity.md`](development_plan_gate_integrity.md#u-the-final-repository-layout).

---

## Related Documents
- [README.md](README.md) — the live tracker this rulebook governs
- [overview.md](overview.md) — target architecture and constraints
- [substrates.md](substrates.md) — the substrate registry and per-phase map
- [system_components.md](system_components.md) — the target component inventory
- [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) — existing code/test/artifact divergence and its owning closure phase
- [Documentation Standards](../documents/documentation_standards.md) — the header/link mechanics this inherits
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine the phases adopt
- [Repository Layout and Artifact Provenance](../documents/engineering/repository_layout_doctrine.md) — generated paths and ignore contracts
- [Phase 0](phase_00_documentation_suite.md) — implements the documentation and artifact-policy gate
- [Phase 27](phase_27_illegal_state_covering.md) — owns the catalog-coverage implementation referenced by the rulebook
