# Development Plan Standards

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, later_phases.md, legacy_tracking_for_deletion.md, overview.md, phase_00_documentation_suite.md, phase_01_bootstrap_kernel_kind.md, phase_02_platform_services_storage_vault.md, phase_03_dsl_control_plane_singleton.md, phase_04_pulsar_content_store_workflow.md, phase_05_determinism_infernix.md, phase_06_jitml_ha_coordinator.md, phase_07_host_compute_daemons.md, phase_08_mattandjames_app_logic.md, phase_09_multicluster_spawn_georeplication.md, phase_10_provider_clusters_provisioning.md, phase_11_test_topology_dsl.md, phase_12_spa_composition.md, substrates.md, system_components.md
**Generated sections**: none

> **Purpose**: The rulebook for the amoebius `DEVELOPMENT_PLAN/` suite — the canonical file layout, the
> per-phase and per-sprint document formats, the status vocabulary, the doctrine-citation rule, and the
> honesty + one-substrate disciplines every plan document obeys.

This document governs *how the plan is written and maintained*. It is the plan-suite analogue of
[`documents/documentation_standards.md`](../documents/documentation_standards.md), which it inherits and
specializes; where the two could conflict, the documentation standards win on header/link mechanics and this
document wins on plan-suite structure.

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
| `phase_NN_<slug>.md` | One document per phase, zero-padded `NN` for sort order (`phase_00_documentation_suite.md` … `phase_12_spa_composition.md`). |
| `later_phases.md` | The in-scope, high-numbered phases not yet given their own document. |

This deviates from prodbox's hyphenated names (`phase-2-gateway-dns.md`) on purpose: amoebius's
documentation standard mandates snake_case. The *structure* mirrors prodbox; the *naming* follows amoebius.

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
**Substrate:** <apple | linux-cpu | linux-cuda | windows | none> (§L)
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
single, checkable acceptance condition — ideally an `amoebius.dhall` that spins resources up, runs a
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

- Links **within** `DEVELOPMENT_PLAN/` use plain relative paths (`README.md`, `phase_02_…md`).
- Links to governed doctrine under `documents/` use the parent-relative path
  (`../documents/engineering/<doc>.md#<anchor>`).
- A rename updates every inbound link in the same change; the `Referenced by` headers are reconciled from the
  true link graph afterward.

## K. Honesty (proven / tested / assumed)

The plan inherits the chaos/failover moral rule (documentation_standards §6,
[`chaos_failover_doctrine.md`](../documents/engineering/chaos_failover_doctrine.md)): **never mark a sprint
✅ Done on the strength of "it compiles."** A sprint whose live/substrate proof has not run is
🧪 Live-proof-pending, not Done. A phase gate is passed only when its acceptance test actually ran on its
substrate (§L). Pre-implementation, every phase and sprint is 📋 Planned and every prescriptive statement is
design intent.

## L. One-substrate discipline

Each phase's acceptance gate requires **at most one** substrate (`apple` | `linux-cuda` | `linux-cpu` |
`windows`), named in the phase's `Phase Summary` and tracked in [`substrates.md`](substrates.md). This
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
