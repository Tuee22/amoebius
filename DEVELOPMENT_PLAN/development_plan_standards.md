# Development Plan Standards

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/later_phases.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, DEVELOPMENT_PLAN/phase_01_toolchain_spike.md, DEVELOPMENT_PLAN/phase_02_formal_model_kernel.md, DEVELOPMENT_PLAN/phase_03_gateway_migration_model.md, DEVELOPMENT_PLAN/phase_04_dhall_gate1_schema.md, DEVELOPMENT_PLAN/phase_05_gadt_decoder_gate2.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_07_capacity_topology_folds.md, DEVELOPMENT_PLAN/phase_08_capability_binder.md, DEVELOPMENT_PLAN/phase_09_render_manifest_goldens.md, DEVELOPMENT_PLAN/phase_10_chain_kernel_dryrun.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_12_spa_composition_representational.md, DEVELOPMENT_PLAN/phase_13_midwife_bootstrap_kind.md, DEVELOPMENT_PLAN/phase_14_base_image_registry.md, DEVELOPMENT_PLAN/phase_15_renderer_reconciler.md, DEVELOPMENT_PLAN/phase_16_retained_storage.md, DEVELOPMENT_PLAN/phase_17_vault_pki.md, DEVELOPMENT_PLAN/phase_18_platform_services.md, DEVELOPMENT_PLAN/phase_19_keycloak_ingress.md, DEVELOPMENT_PLAN/phase_20_live_dsl_singleton.md, DEVELOPMENT_PLAN/phase_21_app_tenancy.md, DEVELOPMENT_PLAN/phase_22_pulsar_client.md, DEVELOPMENT_PLAN/phase_23_content_store_workflow.md, DEVELOPMENT_PLAN/phase_24_determinism_kernel.md, DEVELOPMENT_PLAN/phase_25_jitbuild_engine_cache.md, DEVELOPMENT_PLAN/phase_26_infernix_lift.md, DEVELOPMENT_PLAN/phase_27_jitml_lift_cuda.md, DEVELOPMENT_PLAN/phase_28_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_29_multicluster_gateway_migration.md, DEVELOPMENT_PLAN/phase_30_provider_clusters.md, DEVELOPMENT_PLAN/phase_31_test_topology_dsl.md, DEVELOPMENT_PLAN/phase_32_spa_live_deploy.md, DEVELOPMENT_PLAN/substrates.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/generated_artifacts_doctrine.md
**Generated sections**: none

> **Purpose**: The rulebook for the amoebius `DEVELOPMENT_PLAN/` suite — the canonical file layout, the
> per-phase and per-sprint document formats, the status vocabulary, the doctrine-citation rule, and the
> honesty + one-substrate disciplines every plan document obeys.

This document governs *how the plan is written and maintained*. It is the plan-suite analogue of
[`documents/documentation_standards.md`](../documents/documentation_standards.md), which it inherits and
specializes; where the two could conflict, the documentation standards win on header/link mechanics and this
document wins on plan-suite structure. Tone and the design-choice motivation structure follow
[`documents/documentation_standards.md` §8–§9](../documents/documentation_standards.md#8-tone-and-voice); this
document adds no plan-specific register rules.

---

## A. Header metadata (same block as the doctrine suite)

Every file in `DEVELOPMENT_PLAN/` opens with the standard block from
[`documents/documentation_standards.md` §3](../documents/documentation_standards.md):

```markdown
# <Title>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: <comma-separated relative links to docs that link here>
**Generated sections**: none

> **Purpose**: <one sentence>
```

- `**Referenced by**` lists the **actual** inbound links (bidirectional rule, documentation_standards §4) —
  not a blanket "everything." It is reconciled from the true link graph, never hand-guessed.
- `**Generated sections**` is `none` unless the file contains tool-generated blocks (§I); then it names their
  ids, comma-separated.
- `**Status**` is `Authoritative source` for every plan doc (the plan is the SSoT for sequencing/status);
  the README is additionally the *live tracker*.

## B. Canonical file layout (snake_case)

`DEVELOPMENT_PLAN/` uses **`snake_case.md`** for every file (per documentation_standards §2; the only
ALL-CAPS exception is `README.md`). The canonical set:

| File | Role |
|------|------|
| `README.md` | Live tracker + index: Document Index, Phase Overview table, status vocabulary, Definition of Done. |
| `development_plan_standards.md` | This rulebook. |
| `overview.md` | Target architecture / vision / current-baseline narrative (the "why/what"). |
| `system_components.md` | Target component inventory: surface → owning doctrine → planned module path. |
| `substrates.md` | Substrate registry + per-phase substrate map; sole home of generated tables. |
| `legacy_tracking_for_deletion.md` | The migration-removal ledger (what the convergence retires, and when). |
| `phase_NN_<slug>.md` | One document per phase, zero-padded `NN` for sort order (`phase_00_documentation_suite.md` … `phase_32_spa_live_deploy.md`). |
| `later_phases.md` | The in-scope, high-numbered phases not yet given their own document. |

This deviates from prodbox's hyphenated names (`phase-3-gateway-dns.md`) on purpose: amoebius's
documentation standard mandates snake_case. The *structure* mirrors prodbox; the *naming* follows amoebius.

**Generated artifacts are never a committed module path.** A phase's `Implementation` field (§F) names
authored Haskell/Dhall *source*, never a generated artifact — a rendered k8s manifest, an emitted TLA+
`.tla`/`.cfg`, a reflected Dhall schema, or a PureScript contract are emitted from a Haskell source of truth
and not committed ([`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md)).

## C. Status vocabulary

One vocabulary, used in the README Phase Overview, in each phase's **Phase Status**, and on every sprint:

| Marker | Meaning |
|--------|---------|
| ✅ **Done** | Delivered and validated; the gate passed. |
| 🔄 **Active** | In progress now. |
| 📋 **Planned** | Specified, not started. (The default for every phase and sprint pre-implementation.) |
| ⏸️ **Blocked** | Waiting on a named earlier-or-same-phase sprint or an external prerequisite. |
| 🧪 **Live-proof pending** | Code merged; the live/substrate proof has not yet run (the honesty gap, §K). |

Status lives **only** in the plan. A doctrine doc never carries status; it states the target shape and links
back here (documentation_standards §1, §6).

## D. The per-phase document skeleton

Every `phase_NN_<slug>.md` follows this skeleton:

```markdown
# Phase N: <Title>
<standard header block>
> **Purpose**: <one sentence>

## Phase Status
📋 Planned. <one-line summary; reverse-chronological dated entries once work begins>

## Phase Summary
<what this phase owns, declarative; the objective and scope>
**Substrate:** <none | apple | linux-cpu | linux-cuda | windows> (§L)
**Register:** <1 pure/golden · 2 boundary-with-fakes · 3 live> (§K)
**Gate:** <the concrete acceptance test that must pass before the next phase opens>

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
workflow, and tears them down.

## E. One canonical phase model

- **Contiguous numbering, no gaps.** Phases are `0..N`. A new phase is appended or inserted with a full
  renumber, never given a fractional id.
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
**Blocked by**: <earlier sprint id | external prereq | none>
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

## G. Documentation Requirements

Every phase doc ends its body with an explicit doc-sync block so doctrine and plan never drift:

```markdown
## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/<doc>.md` — <what changes when this phase lands>

**Cross-references to add:**
- <backlinks to add>
```

## H. The doctrine-citation rule (cite by name)

A sprint or phase that schedules adoption work **cites the doctrine section by name**: a relative link
`../documents/engineering/<doc>.md#<section-anchor>` *and* the section's human name in the surrounding
prose. Example:

> Adopt [`manifest_generation_doctrine.md` §5 — the apply/reconcile engine](../documents/engineering/manifest_generation_doctrine.md#5-the-applyreconcile-engine-server-side-apply-owned-field-manager-prune-wait):
> a server-side-apply reconciler with a fixed `amoebius` field manager and ApplySet pruning.

The `Docs to update` field then lists exactly those governed docs. A phase doc's **Doctrine adopted** section
is the gathered list of every section the phase implements — this is the spine that keeps the plan and the
doctrine suite in lockstep.

## I. Generated-section markers

Tool-generated tables are fenced and registered, never hand-edited between the fences:

```markdown
<!-- amoebius:<id>:start -->
... generated content ...
<!-- amoebius:<id>:end -->
```

The `<id>` set must equal the comma-separated `**Generated sections**` header field. Generated tables live
only in `substrates.md` (and any future generated home); every other file declares `none`. Until an
amoebius `dev docs generate` exists, a file may declare `none` and carry the equivalent table by hand —
marking it generated is reserved for when the generator does.

## J. Cross-reference path rules

- Links **within** `DEVELOPMENT_PLAN/` use plain relative paths (`README.md`, `phase_03_…md`).
- Links to governed doctrine under `documents/` use the parent-relative path
  (`../documents/engineering/<doc>.md#<anchor>`).
- A rename updates every inbound link in the same change; the `Referenced by` headers are reconciled from the
  true link graph afterward.

## K. Honesty (proven / tested / assumed)

The plan inherits the chaos/failover moral rule (documentation_standards §6,
[`chaos_failover_doctrine.md`](../documents/engineering/chaos_failover_doctrine.md)): **never mark a sprint
✅ Done on the strength of "it compiles."** A sprint whose live/substrate proof has not run is
🧪 Live-proof-pending, not Done. A phase gate is passed only when its acceptance test actually ran in its
register on its substrate (§L). Pre-implementation, every phase and sprint is 📋 Planned and every prescriptive
statement is design intent.

**Validation happens in three registers, and the ledger names the register(s) it reached.** A phase gate runs
in **exactly one register** ([`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md),
[`testing_doctrine.md` §2](../documents/engineering/testing_doctrine.md#2-three-registers-of-amoebius-testing)):
**Register 1** (pure/golden, in-process, no cluster), **Register 2** (boundary integration with fake tools, no
cluster), and **Register 3** (live infrastructure) — with exactly two deliberate exceptions at the two ends of
the count: **Phase 0** (the documentation-lint gate) reaches **no** register (it validates text and the link
graph, not amoebius behaviour), and **Phase 12** (the representational SPA phase) is the single gate that
spans **two** — Register 1 (the composition property decodes) *and* Register 2 (the PureScript demo SPA against
a faked backend), both in-process, no cluster. The pre-cluster band (phases 1–12, substrate `none`) discharges
Registers 1–2; the live band (phases 13–32) is Register 3. **Rendering a plan / `--dry-run` must never require
live infrastructure.** The per-phase proven/tested/assumed ledger names the register(s) its gate reached; a
Register-1/2 in-process ledger marks the Register-3 runtime layer UNVERIFIED and can never advance a production
`PromotionGate`.

A **design-proof / in-process phase** — one whose substrate is `none` (§L) and whose gate is an in-process
type/model check rather than a live-substrate run, e.g. the pre-cluster band, [phases 1–12](README.md) —
emits a ledger whose acceptance token reads **"spec-composition proven"** / **"proven for the model"**, never
**"runtime proven"**: a green Dhall typecheck, Haskell decoder, or TLC run establishes that the spec composes
and the protocol is sound in the abstract, not that any cluster enforces it. Front-loading such a design
proof *ahead of* the later phase that builds the runtime it will correspond to is legitimate — **provided**
that same ledger marks the model↔code correspondence and the runtime fidelity **UNVERIFIED** until that later
phase discharges them. This front-loading introduces no forward dependency and does not bend the
contiguous-numbering / no-fractional-phase-id rule (§E): the design phase keeps its own integer id and its
own single-substrate (`none`) gate.

## L. One-substrate discipline

Each phase's acceptance gate requires **at most one** substrate (`none` for the pre-cluster band; else
`apple` | `linux-cuda` | `linux-cpu` | `windows`), named in the phase's `Phase Summary` and tracked in
[`substrates.md`](substrates.md). This
prevents cross-substrate flip-flopping mid-development. A phase whose work touches several substrates is
split until each gate is single-substrate.

---

## Related Documents
- [README.md](README.md) — the live tracker this rulebook governs
- [overview.md](overview.md) — target architecture and constraints
- [substrates.md](substrates.md) — the substrate registry and per-phase map
- [system_components.md](system_components.md) — the target component inventory
- [Documentation Standards](../documents/documentation_standards.md) — the header/link mechanics this inherits
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine the phases adopt
