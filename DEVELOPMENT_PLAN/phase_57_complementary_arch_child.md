# Phase 57: The complementary-architecture base image

> **Purpose**: Build the base image's second architecture on hardware that natively executes it and publish it
> under its own architecture-qualified tag, advertised only on the attestation produced by the host that ran it.
> **Read this if**: phase 57 is next in the queue, or a later phase pulls the complementary architecture's tag.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_58_object_reconciler.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 57.1: The complementary-architecture bake on its own hardware ⏸️](#sprint-571-the-complementary-architecture-bake-on-its-own-hardware-)
- [Sprint 57.2: The architecture-qualified publication and its atomic advertisement ⏸️](#sprint-572-the-architecture-qualified-publication-and-its-atomic-advertisement-)
- [Sprint 57.3: The no-emulation and unattested-child negatives ⏸️](#sprint-573-the-no-emulation-and-unattested-child-negatives-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 56, its independent validation, and delegated promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and reviewer-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and an authorized reviewer independently inspects it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** The complement's tag must be an address too, which is what makes
“advertised only on its own attestation” checkable. Because the target tag is derived from the recipe rather
than chosen, there must be no second name under which a half-uploaded or foreign-built child can become
resolvable ([`image_build_doctrine.md` §2.1](../documents/engineering/image_build_doctrine.md#21-a-published-tag-is-a-cache-warm-up-and-its-name-is-the-content-address)). This phase's claim therefore narrows
to the hardware that produced the content, not who holds the naming rights.

If Phase 56 is independently approved, it will leave the cluster pulling only from itself at one architecture;
this phase must then supply the other one. Neither result exists yet.

The future gate must bake the **same typed catalog** on a host whose natural architecture is the complement
of Phase 56's, execute every baked binary there **natively**, and publish that architecture's image under its own
**architecture-qualified tag**. There is no index and no manifest list: the architecture lives in the
reference a consumer names, not in a descriptor a registry resolves
([`image_build_doctrine.md` §3](../documents/engineering/image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index)).
An earlier contract joined the two halves into one attested index; that join was retracted with the manifest
list, and what survives it is the rule the join existed to enforce.

**Publication is where the amendment's rule must become a check rather than a claim.** A tag may be advertised
**only** with an attestation produced by the hardware that executed its content — recording that host's
detected substrate, selected lane, and natural architecture, and the per-binary execution and ELF-machine
observations. The future gate must treat an image whose attestation is missing, belongs to the other
architecture, or cannot be verified against the content it describes exactly as one that was never pushed:
the tag must not be advertised.

What this phase deliberately does not do is re-derive Phase 56's work. The acquisition ladder, bake-inventory
Haskell oracle, registry standup, mutation-admission proxy, and egress boundary may be consumed only as bound to Phase
56's future external reviewer approval. This phase targets one architecture, one publication, and the negatives
that keep the tag honest.

**Phase scope:** one cohesive target claim — *the base image must be published for both architectures, and each
must be tested on its own natural architecture*. Its seams are the complementary bake, the attested publication, and the negatives; its
acceptance command is one gate; it splits further only if a third architecture is ever added, which would be
its own substrate and therefore its own phase.

**Substrate:** apple ([§L](development_plan_standards.md#l-one-substrate-discipline)) — the gate needs a host
whose natural architecture is `arm64`, and on this project's hardware that is the Apple Silicon machine, which
supplies the CPU-only Linux lane through Lima
([`substrates.md` §3](substrates.md#3-virtualized-substrates-incus--lima--wsl2)). The Apple-Metal lane is
**not** exercised here — that is [Phase 89](phase_89_apple_metal_host_daemon.md)'s — so naming `apple` claims
the host, not the accelerator. Any host natively running `arm64` Linux satisfies the same requirement.

**Lane:** linux-cpu/arm64 — the complement of Phase 56's `linux-cpu/amd64`.

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 56](phase_56_base_image_registry.md)
**Gate:** `pb validate phase 57`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive target claim — *the base image is published for both architectures, and each is tested on its own natural architecture*. Its seams are the complementary bake, the attested publication, and the negatives; its acceptance command is one gate; it splits further only if a third architecture is ever added, which would be its own substrate and therefore its own phase. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 57` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent reviewer have been accepted. |
| `Positive controls` | UNRESOLVED — blocks validation: no closed named Haskell corpus and exact per-member observations have been accepted. |
| `Paired negatives` | UNRESOLVED — blocks validation: minimally different pairs, exact rejection loci, and exact reasons have not been accepted for every foreclosed dimension. |
| `Mutants` | UNRESOLVED — blocks validation: operators, production loci, applied-change witnesses, expected red observations, and unaffected controls have not been accepted. |
| `Discovery` | UNRESOLVED — blocks validation: expected and runtime-discovered surfaces, two-way equality, and empty-discovery refusal have not been accepted. |
| `Challenge` | UNRESOLVED — blocks validation: neither a post-start challenge nor a reviewed pure-claim independent predicate has been accepted. |
| `Observer` | UNRESOLVED — blocks validation: no outside observer, raw observation, authenticity check, and fail-closed rule have been accepted. |
| `Authority/bypass` | UNRESOLVED — blocks validation: least-privilege/foreign-scope pairs, bypass probes, or reviewed non-applicability have not been accepted. |
| `Freshness` | UNRESOLVED — blocks validation: stale state, cached output, prior evidence, and replayed responses have not been made unable to pass. |
| `Qualification` | UNRESOLVED — blocks validation: the fixed sabotage corpus has not qualified a Haskell harness independently of a clean candidate run. |
| `Cleanroom` | UNRESOLVED — blocks validation: no run has derived all products lazily with generated and condemned legacy copies absent. |
| `Legacy closure` | UNRESOLVED — blocks validation: stable owned legacy IDs and their exact zero-finding check have not been reconciled. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 56; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Promotion authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `delegated-reviewer` — an authorized human or agent may promote after inspecting the complete qualified candidate; no gate, CI job, digest, receipt-shaped file, or generated assertion may promote by itself. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`extension_conformance_doctrine.md` §5 — The conformance gate is generated, not authored](../documents/engineering/extension_conformance_doctrine.md#5-the-conformance-gate-is-generated-not-authored) — the complementary-architecture base image is admitted by satisfying the contract, not by appearing on a list.
- [`substrate_doctrine.md` §1.1 — the natural-architecture rule](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule):
  a substrate proves its lane only at its own architecture, which is why this phase exists as a separate gate
  on a separate host rather than as a second platform argument to Phase 56's build.
- [`image_build_doctrine.md` §3 — One image per architecture — the tag carries the architecture, not an index](../documents/engineering/image_build_doctrine.md#3-multi-architecture-images--one-natively-built-child-per-architecture):
  the architecture is in the tag and nothing joins the two, so this phase publishes beside Phase 56 rather
  than on top of it.
- [`image_build_doctrine.md` §4 — Atomic publication — a partial upload is a failed upload](../documents/engineering/image_build_doctrine.md#4-atomic-publication--a-partial-multi-arch-upload-is-a-failed-upload):
  the advertisement is one act; an unattested image is an absent image, so a partial upload is never
  advertised.
- [`development_plan_gate_integrity.md` §S — Universal source and artifact hygiene gate](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate)
  clause 15: the run records the detected substrate, the selected lane, and the natural architecture, and every
  executed artifact belongs to that architecture.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 57.1: The complementary-architecture bake on its own hardware ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 56](phase_56_base_image_registry.md) reviewer approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`substrate_doctrine.md` §1.1 — the natural-architecture rule](../documents/engineering/substrate_doctrine.md#11-the-natural-architecture-rule);
bake the complementary child from the same typed catalog on hardware that natively runs it.

### Deliverables

- The complementary-architecture image, built by one plain `docker build` on a host of that architecture.
- A typed `Attestation` recording the host's detected substrate, selected lane, natural architecture, the
  run nonce, and the per-binary execution and ELF-machine observations for that image.
- The Haskell changed-subject mutants `emulated-build` and `stub-arm64-binary`; any external form is generated
  lazily beneath `.build/**`.

### Validation

1. The image's platform is exactly this host's natural platform.
2. Every baked binary runs natively by absolute path and matches its pinned probe.
3. The `binfmt_misc` table is unchanged across the run and no emulator binary is executed.
4. Both Haskell mutants turn the sprint red for their specific reasons.

### Remaining Work

The whole sprint.

## Sprint 57.2: The architecture-qualified publication and its atomic advertisement ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 57.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`image_build_doctrine.md` §3](../documents/engineering/image_build_doctrine.md#3-multi-architecture-images--one-natively-built-child-per-architecture)
and [§4](../documents/engineering/image_build_doctrine.md#4-atomic-publication--a-partial-multi-arch-upload-is-a-failed-upload);
publish one attested, architecture-qualified tag.

### Deliverables

- The pure admission decision: one attested image to one advertised tag, total, with a closed refusal set for
  a missing, foreign, or unverifiable attestation.
- One immutable digest-pinned, architecture-qualified tag resolving from the in-cluster registry.
- The Haskell changed-subject mutants `foreign-attestation`, `unattested-image`, and
  `advertise-before-upload`.

### Validation

1. The published descriptor set equals the separately authored Haskell oracle, layer for layer.
2. The attestation verifies against the image's content digest and its host's issued nonce.
3. A `GET /v2/<repo>/tags/list` omits the tag until the whole attested upload lands.
4. All three Haskell mutants turn the sprint red for their specific reasons.

### Remaining Work

The whole sprint.

## Sprint 57.3: The no-emulation and unattested-child negatives ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 57.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`development_plan_gate_integrity.md` §S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate)
clause 15; seal the phase behind negatives that fail for their stated reasons.

### Deliverables

- The phase gate composing both sprints' validations plus the same-catalog reconciliation.
- The Haskell changed-subject mutant `divergent-catalog`.
- A run-local attestation beneath `.build/**` recording both hosts' substrate, lane, and natural architecture.

### Validation

1. Every negative asserts its exact refusal tag, each paired with a positive differing only in the foreclosed
   dimension.
2. The same-catalog reconciliation joins both children to one Haskell `BakeCatalog` declaration digest; any
   external catalog projection is generated lazily beneath `.build/**`.
3. `divergent-catalog` turns the gate red.
4. The universal postconditions of [§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate)
   hold on both hosts, including clause 15 on each.

### Remaining Work

The whole sprint.

## Documentation Requirements

**Engineering docs to update (when an authorized reviewer promotes the gate, never before):**

- `documents/engineering/image_build_doctrine.md` — the attested-join half of §3 moves from target shape to
  validated boundary, naming the index this phase published.
- `documents/engineering/substrate_doctrine.md` — the `apple` substrate's `linux-cpu/arm64` lane gains its
  first live result, while the Metal lane stays UNVERIFIED until Phase 89.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/substrates.md` — the per-phase map row for this phase.
- `DEVELOPMENT_PLAN/phase_56_base_image_registry.md` — the predecessor whose child this phase joins.

## Related Documents

- [Phase 56](phase_56_base_image_registry.md) — the catalog, ladder, registry, and first child this phase consumes
- [Phase 58](phase_58_object_reconciler.md) — runs on the native-architecture child alone; the joined index is published after it, so no phase before this one consumes the join
- [Image Build & Registry](../documents/engineering/image_build_doctrine.md) — the join and publication contract
- [Substrates](../documents/engineering/substrate_doctrine.md) — the natural-architecture rule this phase enforces
- [substrates.md](substrates.md) — the per-phase substrate and lane map
- [README.md](README.md) — the live tracker that owns this phase's status
