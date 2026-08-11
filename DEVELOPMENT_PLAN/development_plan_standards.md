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
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_04_dhall_gate1_schema.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_07_capacity_core_folds.md, DEVELOPMENT_PLAN/phase_08_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_09_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_10_capability_bind.md, DEVELOPMENT_PLAN/phase_11_provision_seal.md, DEVELOPMENT_PLAN/phase_12_inference_accelerator_provision.md, DEVELOPMENT_PLAN/phase_13_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_14_chain_kernel_boundary.md, DEVELOPMENT_PLAN/phase_15_deterministic_sim_substrate.md, DEVELOPMENT_PLAN/phase_16_ui_program_schema.md, DEVELOPMENT_PLAN/phase_17_scoped_identity_kernel.md, DEVELOPMENT_PLAN/phase_24_bootstrap_coordinator_kind.md, DEVELOPMENT_PLAN/phase_25_base_image_registry.md, DEVELOPMENT_PLAN/phase_26_object_reconciler.md, DEVELOPMENT_PLAN/phase_27_capacity_scheduler.md, DEVELOPMENT_PLAN/phase_28_retained_storage.md, DEVELOPMENT_PLAN/phase_29_vault_pki.md, DEVELOPMENT_PLAN/phase_30_platform_backbone.md, DEVELOPMENT_PLAN/phase_31_platform_services_2.md, DEVELOPMENT_PLAN/phase_32_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_33_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_35_pulsar_client.md, DEVELOPMENT_PLAN/phase_37_content_store_workflow.md, DEVELOPMENT_PLAN/phase_39_release_lifecycle.md, DEVELOPMENT_PLAN/phase_40_ui_program_release.md, DEVELOPMENT_PLAN/phase_41_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_42_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_43_gateway_migration_drills.md, DEVELOPMENT_PLAN/phase_44_provider_deploy_checkpoint.md, DEVELOPMENT_PLAN/phase_45_provider_child_bringup.md, DEVELOPMENT_PLAN/phase_46_provider_ebs_credential.md, DEVELOPMENT_PLAN/phase_47_provider_dynamic_nodes.md, DEVELOPMENT_PLAN/phase_48_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_49_infernix_lift.md, DEVELOPMENT_PLAN/phase_50_infernix_ui_lift.md, DEVELOPMENT_PLAN/phase_51_jitml_lift_cuda.md, DEVELOPMENT_PLAN/phase_52_jitml_ui_lift.md, DEVELOPMENT_PLAN/phase_53_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_54_test_topology_dsl.md, DEVELOPMENT_PLAN/phase_55_ui_single_tenant_live.md, DEVELOPMENT_PLAN/phase_57_ui_rollout_reconnect.md, DEVELOPMENT_PLAN/phase_58_ui_ha_multizone.md, DEVELOPMENT_PLAN/phase_59_offline_language_plan.md, DEVELOPMENT_PLAN/phase_60_encrypted_browser_runtime.md, DEVELOPMENT_PLAN/phase_61_offline_replay_receipts.md, DEVELOPMENT_PLAN/phase_62_offline_blobs_isolation.md, DEVELOPMENT_PLAN/phase_63_offline_release_evolution.md, DEVELOPMENT_PLAN/phase_64_offline_multizone_continuity.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, documents/documentation_standards.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/repository_layout_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/glossary.md, documents/reading_order.md
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
- `**Generated sections**` is always `none`. Generated Markdown lives under ignored `gen/docs/`, never in the
  governed plan suite ([§I](#i-generated-documentation-remains-untracked)).
- `**Status**` is `Authoritative source` for every plan doc (the plan is the SSoT for sequencing/status);
  the README is additionally the *live tracker*.

## B. Canonical file layout (snake_case)

`DEVELOPMENT_PLAN/` uses **`snake_case.md`** for every file (per [documentation_standards.md §2](../documents/documentation_standards.md#2-naming); the only ALL-CAPS exception is `README.md`). The canonical set:

| File | Role |
|------|------|
| `README.md` | Live tracker + index: document index, phase order, status vocabulary, and Definition of Done. |
| `development_plan_standards.md` | This rulebook. |
| `overview.md` | Target architecture / vision / current-baseline narrative (the "why/what"). |
| `system_components.md` | Target component inventory: surface → owning doctrine → planned module path. |
| `substrates.md` | Authored substrate registry and per-phase substrate map. Generated views go to `gen/docs/`. |
| `legacy_tracking_for_deletion.md` | The implementation/plan divergence and migration-removal ledger: observed mismatch, owner, and closure condition. |
| `phase_NN_<slug>.md` | One document per phase, zero-padded `NN` for sort order (`phase_00_documentation_suite.md` … `phase_64_offline_multizone_continuity.md`). |
| `later_phases.md` | The in-scope, high-numbered phases not yet given their own document. |

This deviates from prodbox's hyphenated names (`phase-3-gateway-dns.md`) on purpose: amoebius's
documentation standard mandates snake_case. The *structure* mirrors prodbox; the *naming* follows amoebius.

**Generated artifacts are never a committed module path.** A phase's `Implementation` field
([§F](#f-the-sprint-block-format)) names authored source, never a generated artifact, lock/freeze file,
resolver result, evidence file, or run ledger. The complete rule is owned by
[`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md).

## C. Status vocabulary

One vocabulary, used in the README Phase Overview, in each phase's **Phase Status**, and on every sprint:

| Marker | Meaning |
|--------|---------|
| ✅ **Done** | Delivered; the redesigned gate passed from a clean committed tree and its external attestation verified. |
| 🔄 **Active** | In progress now. |
| 📋 **Planned** | Specified, not started. (The default for every phase and sprint pre-implementation.) |
| ⏸️ **Blocked** | Waiting on a named earlier-or-same-phase sprint or an external prerequisite. |
| 🧪 **Live-proof pending** | Code exists; the required live/substrate proof has not yet run (the honesty gap, [§K](#k-honesty-proven--tested--assumed)). |

Status lives **only** in the plan. A doctrine doc never carries status; it states the target shape and links
back here ([documentation_standards.md §1](../documents/documentation_standards.md#1-philosophy), [§6](../documents/documentation_standards.md#6-honesty-the-proventestedassumed-discipline)).

**Status and implementation progress are different axes.** Status answers whether the current validation
contract is open, blocked, pending live proof, or closed. Progress records what a dated static inspection can
actually find. A source path, test, gate script, or historical run is an **observed footprint**; it is not a
passed current gate. The tracker uses only these progress terms:

| Progress term | Meaning |
|---|---|
| **No footprint observed** | The audit found no implementation path attributable to the phase. Absence is not proof that no implementation exists outside the audit boundary. |
| **Observed footprint** | At least one attributable source, test, gate, or generated migration artifact exists; completeness and correctness are not established. |
| **Known partial** | The footprint exists and the phase contract or static inspection names a missing seam, target, provider, observer, or validation layer. |
| **Policy-conformant** | The current phase gate passed in numeric order from a clean committed tree, including [§S](#s-universal-artifact-hygiene-gate), and its external attestation verified. Only this term is compatible with ✅ Done. |

The tracker attaches a date and audit boundary to every progress summary. Doctrine may describe a target or a
specifically labelled historical observation, but it never converts progress into status.

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
**Register:** <1 pure/golden · 2 boundary-with-fakes · 3 live · 1/2 only for Phase 14 · — for Phase 0> ([§K](#k-honesty-proven--tested--assumed))
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
workflow, and tears them down. Every gate also inherits the clean-tree and generated-output postcondition of
[§S](#s-universal-artifact-hygiene-gate), without duplicating it in the 65 phase documents. A phase may state an optional **Phase scope** or legacy **Session scope** note;
the enforceable sizing rules are owned by [§O](#o-sprint-sized-seams-and-bounded-phase-gates) and apply whether or not that
summary note is present.

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

- **Contiguous numbering, no gaps.** Phases are `0..N`. A new phase is appended or inserted with a full
  renumber, never given a fractional id.
- **A full renumber carries an audit map.** A pre-implementation re-baseline may reorder or split planned phases
  only when the same change records every old phase as `old id/path → new id/path(s)`, updates every inbound
  link and dependency, and leaves no stale old-number reference. Once any affected phase is ✅ Done, the
  no-renumber rule of [§N](#n-reopening-and-amending-a-phase) applies.
- **A sprint belongs to exactly one phase.** No sprint is duplicated across phases.
- **No forward dependencies.** A sprint's `Blocked by` names only an earlier-or-same-phase sprint or an
  external prerequisite — **never** a later phase (that would violate the strict numeric order in
  [README.md](README.md) Phase discipline).

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
[`system_components.md`](system_components.md)), honestly marked as not-yet-built.

**`Blocked by` and `Requires` are different obligations, and conflating them is what makes a plan look
unbuildable when it is not.**

- **`Blocked by`** names **phases and sprints only**, and never one later than itself. It is the
  numerical-order contract: a phase's gate may consume only what a phase ≤ its own number delivers.
- **`Requires`** names an **environment precondition** — a fact about the host, account, or developer
  machine that *no phase builds and none ever will*, because it is not amoebius's to build. It is declared
  so it is checked at gate start rather than assumed, exactly as the substrate is
  ([`substrates.md` §2](substrates.md#2-substrate-inventory) owns the substrate half of the same idea).

| `Requires` precondition | What it is | Declared by |
|---|---|---|
| `accelerator-device-plugin` | A Kubernetes device plugin advertising `nvidia.com/gpu` for the host's device vector — part of what *makes* a host `linux-cuda`, so it belongs to the host, not to a phase | Phase 51 |
| `cloud-account` | A credentialed provider account carrying the quota and permissions the `Managed Eks` registry entry names | Phases 44–47, 54 |
| `host-toolchain` | The `ghc`/`cabal`/`dhall`/`spago`/`purs`/Chromium binaries present on the developer host. Phase 1 authors compatibility requirements; resolved versions and absolute paths are run-local generated observations under `gen/toolchain/` | Phase 1 |

No phase requires a live public DNS zone: [`phase_32`](phase_32_keycloak_ingress.md) accepts a local ACME
chain in place of public issuance, and Phase 3's `dnsRecord` TTLs are model parameters, not live records.

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
only below ignored `gen/docs/`. They may be inspected or published from CI, but they are never copied into a
tracked Markdown file.

A table that must remain in a phase contract is authored and reviewed as a requirement. A table that can be
regenerated from code, a phase contract, repository discovery, or an evidence store is generated output and
belongs in `gen/docs/`. This rule removes generated-marker fences from the version-controlled corpus.

## J. Cross-reference path rules

- Links **within** `DEVELOPMENT_PLAN/` use plain relative paths (`README.md`, `phase_03_…md`).
- Links to governed doctrine under `documents/` use the parent-relative path
  (`../documents/engineering/<doc>.md#<anchor>`).
- A rename updates every inbound link in the same change; the `Referenced by` headers are reconciled from the
  true link graph afterward.

## K. Honesty (proven / tested / assumed)

The plan inherits the chaos/failover moral rule ([documentation_standards.md §6](../documents/documentation_standards.md#6-honesty-the-proventestedassumed-discipline), [`chaos_failover_doctrine.md`](../documents/engineering/chaos_failover_doctrine.md)): **never mark a sprint ✅ Done on the strength of "it compiles."** A sprint whose live/substrate proof has not run is
🧪 Live-proof-pending, not Done. A phase gate is passed only when its acceptance test actually ran in its
register on its substrate ([§L](#l-one-substrate-discipline)). Before any implementation footprint is
observed, a phase or sprint is 📋 Planned and every prescriptive statement is design intent. Once a footprint
exists, [§C](#c-status-vocabulary)'s separate progress vocabulary prevents that observation from being
misreported as validation.

**Validation happens in registers, and the ledger names the register(s) it reached.** A phase gate runs
in **exactly one register** ([`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md), [`testing_doctrine.md` §2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing)):
**Register 1** (pure/golden, in-process, no cluster), **Register 2** (boundary integration with fake tools, no
cluster), and **Register 3** (live infrastructure) — with exactly two deliberate exceptions: **Phase 0** (the
documentation-lint gate) reaches **no** register because it validates text and the link graph, not amoebius
behaviour; and **Phase 14** (the chain/Step kernel + `--dry-run` + boundary fake-tool harness) spans Register 1
(the in-process `chain`/`Step` corpus) and Register 2 (the boundary fake-tool harness). Every bounded-UI phase
has one register: pure schema/check/bind/compiler work in Phases 16–20 and boundary browser/server/composition
work in Phases 21–23 are deliberately separate. The pre-cluster band (phases 1–23, substrate `none`) discharges
Registers 1–2; the initial live band (phases 24–58) is Register 3. Promoted phases retain the register their
gate actually needs (Phases 59–60 are Registers 1–2; Phases 61–64 are Register 3) rather than inheriting a
register from their number. **Rendering a plan / `--dry-run` must never require live infrastructure.** The per-phase proven/tested/assumed ledger names the register(s) its gate reached; a
Register-1/2 in-process ledger marks the Register-3 runtime layer UNVERIFIED and can never advance a production
`PromotionGate`.

**Register 2.5 — deterministic simulation — is a pre-cluster validation *activity*, not a phase-gate register.**
A live-band phase may additionally run its real daemon/reconciler code under `IOSim`/`IOSimPOR` against a
modeled, fault-injectable environment (no cluster, deterministically replayable;
[`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md),
[`testing_doctrine.md` §2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing))
as an in-process check **before** its Register-3 gate. Because **no phase's acceptance gate keys to Register 2.5** — the phase's single gate remains its Register-3 live proof — the one-gate-one-register rule above is
unbroken; a `**Register:**` field is never `2.5`. The Register-2.5 run emits its own proven/tested/assumed
ledger (its result is *tested against a modeled environment*, with the environment's fidelity to the real
substrate recorded **assumed**), which does not by itself advance a `PromotionGate`.

A **design-proof / in-process phase** — one whose substrate is `none` ([§L](#l-one-substrate-discipline)) and whose gate is an in-process
type/model check rather than a live-substrate run, e.g. the pre-cluster band, [phases 1–23](README.md) —
emits a ledger whose acceptance token reads **"spec-composition proven"** / **"proven for the model"**, never
**"runtime proven"**: a green Dhall typecheck, Haskell decoder, or TLC run establishes that the spec composes
and the protocol is sound in the abstract, not that any cluster enforces it. Front-loading such a design
proof *ahead of* the later phase that builds the runtime it will correspond to is legitimate — **provided**
that same ledger marks the model↔code correspondence and the runtime fidelity **UNVERIFIED** until that later
phase discharges them. This front-loading introduces no forward dependency and does not bend the
contiguous-numbering / no-fractional-phase-id rule ([§E](#e-one-canonical-phase-model)): the design phase keeps its own integer id and its
own single-substrate (`none`) gate.

**A ✅ Done flip references verified external evidence.** A phase moves to Done only when its gate runs from
the human-committed tree, satisfies [§S](#s-universal-artifact-hygiene-gate), and its immutable external
attestation verifies. A sprint moves to Done only when its current independent validation passes and the
parent phase's run retains that result; an added phase-level requirement reopens only the sprint whose
deliverable or validation it changes. The tracker records the human status decision and may link the external
run. It never copies a generated ledger, receipt, hash, command transcript, or machine observation into
Markdown.

**Status is single-sourced and consistent.** Status lives only in the plan ([documentation_standards.md §1](../documents/documentation_standards.md#1-philosophy)). The
marker in a phase's README Phase-Overview row and the marker in that phase doc's `## Phase Status` line **must be identical**; the documentation lint checks this equality and fails on drift.

**The proven/tested/assumed ledger is generated, schema-checked, and externally retained.** Every gate emits
the ledger under `gen/runs/`; no ledger or evidence copy is committed. The external attestation binds it to
the committed source tree and phase contract. The ledger names the reached register and marks every layer
outside that register UNVERIFIED. [`testing_doctrine.md` §4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)
owns its schema and retention boundary.

## L. One-substrate discipline

Every acceptance gate runs on the **always-available `linux-cpu` baseline** and may additionally require
**at most one specialized substrate** — `apple` or `linux-cuda`. A gate naming a specialized member *implies*
the baseline and need not restate it: a `linux-cuda` host **is** a Linux host, and an `apple` host supplies
the baseline through its Lima VM ([`substrates.md` §3](substrates.md#3-virtualized-substrates-incus--lima--wsl2)).
Windows supplies it through WSL2. When a gate requires a pristine Linux host, the provider is fixed by the
detected hardware: **Incus on `linux-cpu` or `linux-cuda`, Lima on `apple`, WSL2 on `windows`**. Consequently,
a gate row labelled `linux-cpu` names the CPU-only execution lane, not an assertion that the physical host is
Linux or has no accelerator.
**No gate may require two specialized substrates.** The pre-cluster band names `none` — no host at all.

The gate's substrate is named in the phase's `Phase Summary` and tracked in
[`substrates.md`](substrates.md). This prevents cross-substrate flip-flopping mid-development: a phase whose
work would need both an Apple host and a CUDA host is split until each gate needs at most one.

`windows` remains a catalog member ([`substrates.md` §2](substrates.md#2-substrate-inventory)) but **no phase
in 0–64 gates it**; it is a declared future member, not a validated one.

**Two named forms satisfy the one-substrate rule without naming a fixed catalog member on the parent gate**, and
both keep the discipline checkable rather than bending it:

- **Deferred-to-generation** (Phase 54, `per generated test`). A gate that *emits* a test `.dhall` names the
  **rule** that each generated test is substrate-locked to exactly one substrate, chosen at generation time — the
  single-substrate property holds per generated artifact, not as a fixed member on the emitting gate.
- **Parent-drives-provider** (Phases 44–47 and 58, `linux-cpu → provider`). The gate runs from one selected
  `linux-cpu` parent lane and *targets* a provider it does not itself run — EKS is a **declared managed engine,
  not a detected substrate** ([`substrates.md` §2](substrates.md#2-substrate-inventory)). The parent lane may be
  native Linux or the Incus/Lima/WSL2 guest appropriate to its detected hardware; the provider is a
  compute-engine axis, never a fifth substrate.

## M. Gate integrity (a gate cannot be passed by a stub)

A phase gate exists to prove the phase's objective was actually delivered. A gate a stub, fake, hardcoded
happy-path, or self-fulfilling fixture can pass is not a gate. Every phase **Gate** — and every sprint
**Validation** that feeds it — obeys the clauses below; a gate that omits an applicable clause is incomplete.

1. **Independent oracle provenance.** A version-controlled fixture, golden, expected error, or locus tag is a
   human-authored input reviewed independently of the implementation. The implementation author is not its
   sole author or reviewer.
   - A golden or expected value regenerated from the implementation's own output is not a test: it passes
     for any output, a stub's included.
   - A reference implementation may generate an expected value at run time, but that expected file remains
     under `gen/runs/` and is never committed. The reference implementation and its authored inputs may be
     version-controlled when they do not import or reuse the subject's decision logic.
   - Authorship before the implementation is strong provenance when Git history establishes it. An existing
     oracle whose chronology or independent review cannot be established is a regression fixture, not an
     independent oracle, until it receives an independent review or replacement.
   - **Amendment.** A pinned oracle is not frozen — a renderer's output, an error tag, or an expected value
     may legitimately change when the design does.
   - It is **amended**, never rewritten from a failing run: the new expectation is authored from the
     *intended* output, the change to the expectation is reviewed as its own change (with the reason
     recorded beside it), and the mutants that the oracle must still turn red are re-run against the amended
     value.
   - Copying the failing run's actual output over a golden converts an oracle into a snapshot and voids
     clause 1 for every subsequent run; it is prohibited in every phase.
   - Where a byte-exact golden is used, the phase must also pin the **canonical rendering convention** the
     golden is authored under (encoding, ordering, indentation, and a content-stable generated-by stamp
     carrying no timestamp or run-varying field) — without one, a hand-authored byte-exact fixture is not
     writable and clause 1 cannot be satisfied ([generated_artifacts_doctrine.md §3](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)).
     A byte-exact golden is therefore authored no earlier than the sprint that fixes its convention.
2. **Committed mutation quota.** Every gate names **at least one committed seeded mutant** — a deliberately
   broken implementation or spec — that the gate must turn red. Mutants are drawn from a defined operator set
   (guard negation/weakening, effect swap, dropped effect/`UNCHANGED`, quantifier flip, fairness drop,
   invariant-clause delete, union-arm addition), not one hand-picked strawman, and are committed and re-run,
   not run once.
3. **Independent reference predicates.** An equivalence or exact-match check — an `accepts ⟺ in-envelope`
   property, an expected-argv assertion, an expected-error-tag assertion — defines its reference side
   **independently of the code under test** (a committed hand-authored table or a distinct specification),
   never by reusing the implementation's own fold, helper, or `Step→argv` function. A check whose oracle is the
   subject under test is a tautology.
4. **Generator coverage.** A property-based (QuickCheck) gate carries `cover` / `classify` obligations that
   force the illegal / reject / boundary branch to fire a stated minimum fraction of cases. A generator that
   emits one near-constant legal value proves nothing about the reject path.
5. **External-observer traces.** A gate that asserts *how* the binary behaved — every tool invoked by absolute
   path, zero Helm invocations, no public-registry pull, no credential access on the render path — reads its
   trace from an **observer at the OS boundary** (an argv-recording shim, `strace`, a CNI/containerd log),
   never from a compliance trace the code under test emits about itself, which cannot record the calls that
   bypass it.
6. **Determinism honesty.** A determinism / reproducibility gate forces an **independent recomputation** on the
   second run (cache-bypass, or a distinct content-addressed namespace) and asserts the compute path actually
   executed. A "second run" served from a content-addressed store hit proves memoization, not determinism.
7. **Concrete corpus.** A gate names its "representative set" **explicitly** — which capabilities, which
   service set, which fixtures — in the phase doc. An undefined "representative set" is satisfied by one
   hand-picked happy-path shape.
8. **Specific-reason negatives.** A negative fixture asserts **why** it fails — its expected `dhall type`
   error, `DecodeError` tag, or compile-fail locus — and is paired with a positive that differs only in the
   foreclosed dimension. A negative that merely "fails" can fail for an unrelated reason (a typo, a missing
   field) while the illegal state it targets stays representable.
9. **Fresh-challenge binding.** Every effectful boundary or live gate uses a harness-generated unpredictable
   nonce or canary issued after the subject starts, carries it through the public operation, and recovers it
   from the independent observation. Fixed output, stale state, or a pre-recorded response cannot satisfy the
   gate. Pure gates name a separately authored reference predicate and mark an effectful challenge not
   applicable.
10. **Authenticated observer provenance.** The gate names the observer outside the system under test and the
    raw evidence it reads. An unavailable, unauthenticated, incomplete, or challenge-mismatched observer fails
    closed; a self-reported compliance trace is never a fallback.
11. **Authority-paired security checks.** An authentication, authorization, tenancy, or ownership gate uses
    real least-privilege credentials minted by the authority under test. It pairs an own-scope success with a
    foreign-scope denial that differs only in authority or scope, and externally observes zero forbidden
    effect. Caller-authored identity or tenant headers are hostile inputs, not evidence.
12. **Bypass-path negatives.** A gate claiming a single edge, broker, store, workflow, or provider path probes
    the alternate direct paths as well as the intended path. Success through the sanctioned route cannot hide
    an independently reachable bypass.

These clauses are what a phase's **Gate** and each sprint's **Validation** are checked against. The Phase-0
documentation lint verifies that every gate names its authored fixtures, mutant(s), and independent oracle.
The generated run ledger records the result and is externally attested. The implementation author must not be
the sole author or reviewer of the oracle.

Clauses 9–12 are the plan projection of
[`testing_doctrine.md` §12 — spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect).
Each applicable phase declares the challenge, observer, authority source, and paired negative in its gate
apparatus. Raw observations and digests remain generated run evidence outside Git.

<a id="gate-integrity-delegation"></a>
**Gate → Gate-integrity delegation.** A `**Gate:**` line may discharge these clauses inline **or** delegate them to the
phase's `## Gate integrity` section ([§D](#d-the-per-phase-document-skeleton)) by anchor. Delegation is a
first-class, conforming form: a `**Gate:**` line that names its fixtures, mutant(s), and oracle *in a linked
`## Gate integrity` section* satisfies this section exactly as an inline naming does. A conforming
implementation of the Phase-0 gate-integrity lint (check (f)) therefore **follows one anchor hop** from the
`**Gate:**` line into the delegated section before reporting a gate under-specified; it must not flag a gate
whose apparatus lives one hop away.

---

## N. Reopening and amending a phase

[§C](#c-status-vocabulary) names five status markers and [§K](#k-honesty-proven--tested--assumed) defines one
transition: a phase moves **to** ✅ Done only after the redesigned gate and external attestation verify. This
section defines reverse and lateral moves so changing a gated phase is recorded rather than silent.

- **A reverse transition is recorded, never silent.** Moving a phase ✅ Done → 🔄 Active or 📋 Planned, or a
  🔄 Active phase back to 📋 Planned, requires a dated entry in that phase's `## Phase Status` log
  ([§D](#d-the-per-phase-document-skeleton) prescribes reverse-chronological dated entries) naming **which gate is invalidated, why, and by what change**. The README Phase-Overview marker and the phase doc's
  `## Phase Status` marker move together ([§K](#k-honesty-proven--tested--assumed) single-sourcing); the
  documentation lint's status-consistency check holds across the move.

- **Scope amendment of a gated phase invalidates the prior attestation.** A new sprint, doctrine adoption, or
  widened gate reverts the phase to Active, Planned, Blocked, or Live-proof pending. The current tracker and
  status block stop presenting the earlier run as completion evidence. Historical prose may state that a
  prior boundary ran only when it is explicitly labelled invalidated and carries no copied generated record.

- **The amendment log is the `## Phase Status` block.** Every reopen or scope amendment appends a dated entry
  there; the block is the phase's audit trail, and no amendment is made without one.

- **Reopening also refreshes observed progress and legacy divergence.** The same documentation change updates
  the tracker audit using [§C](#c-status-vocabulary)'s progress terms and records every discovered
  implementation-to-plan mismatch in
  [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md). Neither the old plan nor the existing
  code silently wins; [§T](#t-plan-to-implementation-reconciliation) governs reconciliation.

- **`Invalidated historical record` is a bounded non-normative block.** Inside `## Phase Status`, that exact
  label opens a historical sub-block and the next `##` heading closes it. Every status, gate result, evidence
  path, fixed version, integrity value, and completion claim inside the sub-block is migration context whenever
  it conflicts with current status, the current gate, this standard, or repository-layout doctrine. It does
  not make later sections historical implicitly: a retained historical statement elsewhere is labelled
  locally under [§K](#k-honesty-proven--tested--assumed). Reopening does not rewrite history into a false claim
  about what an earlier run did. A new sprint and gate state the replacement contract, and closure requires a
  new run under [§S](#s-universal-artifact-hygiene-gate). In particular, old committed-ledger,
  lock/freeze, fixed-resolution, and developer-path language never governs future work.

- **What reopening never does after implementation evidence exists.** It never renumbers a completed phase
  and never mints a fractional id. Adding cross-cutting discipline to existing phases with **zero renumber** —
  the pattern recorded in [`later_phases.md`](later_phases.md) where a discipline is folded into the phases
  that already own its surfaces — remains the default. The only renumbering exception is the fully mapped
  pre-implementation re-baseline of [§E](#e-one-canonical-phase-model), before any affected gate has evidence.

The generated-artifact redesign dated 2026-08-11 invokes this section across phases 0–64. Phase 0 is Active;
phases 1–64 and their sprints are Blocked by the reopened numeric sequence. Retained sprint bodies preserve
functional and validation outcomes plus pre-amendment capability diagnostics, not obsolete artifact or
dependency-resolution mechanics and not current closure. A retained instruction to commit generated output,
freeze resolution, retain a resolved version, path, or integrity hash, or consume repository-resident
evidence, ledgers, or enumerations is historical and superseded; prior results remain
historical until each phase gate satisfies [§S](#s-universal-artifact-hygiene-gate).

---

## O. Sprint-sized seams and bounded phase gates

A **sprint** is the implementation-session unit; a **phase** is the smallest cohesive capability claim that
needs an integrated acceptance gate. This matches the plan's existing hierarchy: a phase may require several
ordered implementation seams, but each sprint isolates one seam and its independent validation so the final
gate cannot hide which part supplied the behaviour.

amoebius applies the following scope contract:

1. Each sprint owns **one primary implementation seam**: one algebra, interpreter, boundary adapter, runtime
   process change, live transition, or fault/isolation claim. Supporting fixtures, tests, documentation, and
   mechanical wiring may ride that sprint.
2. A phase groups only seams needed for **one cohesive end-to-end capability claim**. The phase summary names
   that claim; every implementation sprint must be necessary to its gate or be moved to another phase.
3. A phase has **one acceptance command in one register on at most one substrate**. Sprint validations may be
   pure or boundary-local prerequisites, but the phase's claimed evidentiary strength is only the named final
   register. A second final register, second substrate, or independently useful acceptance claim triggers a
   phase split.
4. Every implementation sprint has an independently checkable validation and a concrete completion state.
   The phase gate enumerates or composes those validations; it may not replace them with one broad success bit.
5. A sprint must be completable in one uninterrupted engineering session. If a sprint acquires a second
   public algebra, runtime process, or independently meaningful validation, that sprint is split before work
   continues.
6. A phase that discovers a second capability claim during implementation stops without widening its gate;
   the plan is amended into contiguous successor phases before work resumes.

The contract forecloses unbounded milestone phases while permitting a dependency-ordered seam chain such as a
typed kernel followed by the one live consumer that establishes the phase's integrated claim. It does not
impose a source-line estimate: generated fixtures, exhaustive negative corpora, and doctrinal explanation can
be large. The sprint blocks, phase summary, and phase gate are the auditable sizing record.

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

**The problem.** The invariant set was stated twice — once as a bullet list in the tracker and once as a table
in the overview — and the two copies drifted in wording while both continued to claim currency. Near-duplicate
detection did not catch it, because paraphrase is not lexical overlap, so the drift was invisible to tooling
and to any reader who consulted only one of them.

**Why the obvious alternative fails.** Keeping both and reconciling them by review is what was already being
attempted. Review cannot hold two prose statements of twenty-three invariants in correspondence across every
edit, and the copy a reader trusts is whichever one they opened.

**The rule.** [overview.md §3](overview.md#3-the-hard-constraints-cross-cutting-invariants) is the sole home
of the cross-cutting invariant set, because it carries the owning-doctrine citation per invariant, which is
what makes the set maintainable. [README.md](README.md) is the live tracker ([§B](#b-canonical-file-layout-snake_case)):
phase order, status, Definition of Done, and the document index. Each phase document owns its specific gate.
The tracker links to both and never restates them.

**What it forecloses.** Reading the tracker alone as a complete statement of what every phase must uphold.
That is the intended trade: one hop to a table that names its owners beats two lists that agree only by
accident.

---

## S. Universal artifact-hygiene gate

Every phase gate includes one implicit postcondition in addition to its phase-specific capability check. A
gate cannot pass unless all of these conditions hold:

1. The run begins from a clean human-committed tree.
2. Test surfaces are enumerated at run time into `gen/test-surfaces/` and joined to authored expectations.
3. All deliberate compilation, generation, resolution, and run evidence stays under `gen/`, a declared build
   root, or a temporary directory; ignored Python interpreter caches are the sole source-adjacent exception.
4. No command writes beneath an authored root except for Python's ignored interpreter cache.
5. No `.lock`, `.freeze`, package checksum database, hard-coded library/package SHA, resolved user-home path,
   generated ledger, evidence file, enumeration, bytecode, or generated source is tracked.
6. The gate leaves tracked files unchanged and creates no unignored generated path.
7. The Docker context contains no generated output, evidence, dependency tree, cache, secret, or runtime state.
8. The generated run bundle is schema-checked and uploaded as an immutable external attestation bound to the
   committed tree and phase contract.

Python runs with ordinary bytecode caching enabled. `.gitignore` and `.dockerignore` must cover every
`__pycache__` directory and Python bytecode suffix, and Phase 0 rejects tracked bytecode, context leakage,
missing patterns, or command-level suppression. A source-adjacent ignored cache is allowed to remain locally;
it is not a gate output, authored input, or version-controlled artifact.

The complete file classification, output inventory, ignore patterns, and clean-clone acceptance are owned by
[`repository_layout_doctrine.md`](../documents/engineering/repository_layout_doctrine.md). A phase document
states only its capability-specific acceptance condition; it does not duplicate these eight clauses.

This amendment invalidates every prior phase seal because the former gates could consume committed
enumerations and ledgers, write evidence beneath `DEVELOPMENT_PLAN/`, and rely on tracked resolver output or
host-specific paths. Existing code may satisfy the capability part, but that result cannot restore Done until
the redesigned gate passes in numeric order.

---

## T. Plan-to-implementation reconciliation

The plan, implementation, tests, and historical evidence are independent inputs to a reconciliation. None is
presumed correct merely because it already exists or is authoritative for a different concern. Target intent
comes from current doctrine and explicit operator decisions; sequencing and acceptance come from this plan;
implementation presence comes from dated repository inspection; current proof comes only from the redesigned
gate and verified external attestation.

Every documentation sweep follows this policy:

1. **Establish the audit boundary.** Record the date, tree state, roots inspected, and whether observations are
   committed, uncommitted, untracked, generated, or external. A dirty worktree is an observation boundary,
   never a committed baseline.
2. **Compare by contract, not filename.** For each phase, compare target capability, implementation paths,
   tests, gate behavior, artifact provenance, substrate/register, and remaining work. A similarly named file
   does not establish semantic coverage.
3. **Classify, do not promote.** Update the tracker with one [§C](#c-status-vocabulary) progress term. File
   presence, compilation, an old ledger, or an invalidated pass cannot yield `Policy-conformant` or ✅ Done.
4. **Record every divergence.** Missing target code, extra legacy code, generated material in authored roots,
   obsolete terminology, incompatible gate behavior, hard-coded resolution, test-plan mismatch, and unclear
   ownership each receive a row in
   [`legacy_tracking_for_deletion.md`](legacy_tracking_for_deletion.md), with an owner and closure condition.
5. **Resolve ambiguity explicitly.** If doctrine, plan, and code disagree on intended behavior, the phase stays
   open or blocked while documentation records the conflict and the decision required. An audit never chooses
   a new product policy implicitly.
6. **Update all owners together.** A settled decision updates the owning doctrine, tracker, affected phase
   contracts, component/substrate inventory, and legacy row in one documentation change. Duplicated status or
   generated audit projections are prohibited.
7. **Refresh or retire snapshots.** Counts and path inventories are dated diagnostics. A later relevant change
   refreshes them; closure replaces the divergence row with its verified disposition rather than preserving a
   stale count as current truth.

`legacy_tracking_for_deletion.md` is therefore broader than a deletion list: until convergence it is the
mandatory register of existing code, test, tool, and generated-file state that conflicts with the intended
plan. The tracker provides the concise current view; the legacy register provides the actionable mismatch
detail.

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
- [Phase 6](phase_06_illegal_state_corpus.md) — owns the catalog-coverage implementation referenced by the rulebook
