# Phase 91: The infernix inference core, re-derived

> **Purpose**: Re-derive the infernix inference core as an amoebius-owned extension behind one artifact
> adapter, and test live that only a ready-pointer-committed, owned artifact can drive deterministic CPU inference through
> amoebius services. The guarantee this adds over the seed is an ownership index on the artifact: an adapter
> cannot be handed one it does not own.
> **Read this if**: phase 91 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_56_base_image_registry.md, DEVELOPMENT_PLAN/phase_80_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md, DEVELOPMENT_PLAN/phase_93_jitml_rederivation.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 91.1: Re-derive infernix behind one scoped artifact adapter ⏸️](#sprint-911-re-derive-infernix-behind-one-scoped-artifact-adapter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 90, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**What this phase re-derives, and what it must add.** The seed scopes a *resource* with a rank-2 region; amoebius re-derives that orchestration core so the same region scopes a **tenant**, which is what makes a phantom scope tag survive a tenant learned at run time. Nothing is linked: amoebius compiles no seed module and takes no dependency on the seed's release cadence.

This phase owns one seam: `Infernix.Adapter.Core` maps an infernix workflow and artifact contract onto
capabilities supplied only by human-approved predecessor phases. The package compiles the untouched sibling
`Infernix.Topic.Metadata` module and uses its compacted view for command-outcome deduplication; the remaining
sibling source boundary is reviewed and resolved dynamically. Store operations use the Phase-69 three-tier content-addressed store;
commands and events use typed native CBOR over Pulsar; credentials remain Vault `SecretRef` names; named
engines resolve through the Phase-80 jit-build cache; CPU decode uses a deterministic pinned micro-model.
Linkage of the full sibling inference-engine core and production TinyLlama execution remain UNVERIFIED.

Every workflow start enters the adapter with one server-derived, scope-qualified `CommandId`. The adapter
preserves it unchanged as the Phase-69 work-id in the canonical command payload and in every progress or
terminal event; it never derives a replacement from a pod, retry, run id, or artifact digest. Producer resends
retain the producer identity/sequence required by Phase 67, while consumer redelivery folds on that stable
work-id. Reusing the same scoped command id and normalized input returns the same workflow/artifact outcome;
reusing it with a different normalized input is a typed idempotency conflict before inference or store effects.

The adapter exposes only server-side, scope-indexed workflow and artifact values. A private-constructor
`ReadyArtifactHandle scope` is minted only after blob and canonical-CBOR manifest verification and the final
ready-pointer commit. It carries no client-chosen tenant, storage coordinate, engine address, credential, or
raw provider handle. Phase 92 is the sole infernix-to-UI boundary; this phase owns no frontend, browser probe,
HTTP presentation server, generated client contract, or UI deployment.

One finite `CpuInferenceWorkBudget` supplies model/engine identity, threads, concurrency, token bounds, retry
and buffer bounds, and complete CPU/memory/ephemeral demand to the inherited Phase-69 workflow envelope. Its
accelerator is structurally `None`; engine-cache and content-store demand merge into their existing owners,
with no unbounded/default resource arm or fictional client Pod.

The bounded campaign must implement the thin locally re-derived adapter facade and submit it to the Phase-91 aggregate
gate; the command cannot accept or promote the phase. Split if the work changes sibling inference algorithms, adds a
platform capability, or creates a server/UI runtime.
**Phase scope:** one cohesive claim — *only a ready-pointer-committed, owned artifact can drive inference through amoebius services*. The re-derivation adds an ownership index the seed's adapter does not carry. Here, "committed" names observed content-store pointer state, never a version-control operation or repository artifact.

**Substrate:** linux-cpu
**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure)
**Depends on:** [Phase 90](phase_90_test_topology_live.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 91`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | one cohesive claim — *only a ready-pointer-committed, owned artifact can drive inference through amoebius services*. The re-derivation adds an ownership index the seed's adapter does not carry. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 91` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
| `Oracle` | UNRESOLVED — blocks validation: no separately authored `.hs` oracle, independence boundary, provenance, and independent human reviewer have been accepted. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 90 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [Lift and Compose Doctrine §5 — The re-derivation map](../documents/engineering/lift_and_compose_doctrine.md#5-the-re-derivation-map)
  and [`lift_and_compose_doctrine.md` §4 — The re-derivation rule: name the guarantee you are adding](../documents/engineering/lift_and_compose_doctrine.md#4-the-re-derivation-rule-name-the-guarantee-you-are-adding):
  retain infernix computation while re-homing store, transport, secrets, and engine seams.
- [Lift and Compose Doctrine §3 — A seed is a reference implementation](../documents/engineering/lift_and_compose_doctrine.md#3-a-seed-is-a-reference-implementation):
  keep sibling behavior as evidence until this live gate passes.
- [`app_vs_deployment_doctrine.md` §7 — infernix is a shared library; the inference substrate is a deployment rule](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule):
  link the core as a library while keeping substrate selection in deployment rules.
- [`content_addressing_doctrine.md` §2 — The three-tier store: blobs ← manifests ← pointers](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers),
  [`content_addressing_doctrine.md` §3 — `experimentHash`: identity is *what was requested* ‖ *where it ran*](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran),
  and [`content_addressing_determinism.md` §4 — Determinism by construction: pinned inputs + pure stages + derived seed](../documents/engineering/content_addressing_determinism.md#4-determinism-by-construction-pinned-inputs--pure-stages--derived-seed):
  bind verified artifacts, substrate identity, pure decode, and derived seed.
- [`content_addressing_determinism.md` §4.5 — The ML-asset lifecycle: one bounded content-addressed cache, resolved on first miss](../documents/engineering/content_addressing_determinism.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
  and [`content_addressing_doctrine.md` §6 — The honest ceiling: types make the bookkeeping total, not the physics deterministic](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic):
  resolve named engines on first miss and claim reproducibility only on the tested substrate.
- [`pulsar_client_doctrine.md` §1 — One client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets),
  [`pulsar_client_doctrine.md` §3.1 — Payloads are exclusively CBOR](../documents/engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor),
  and [`pulsar_client_doctrine.md` §7 — Delivery: at-least-once with broker-side dedup (the robust default)](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default):
  remove the WebSocket/JSON envelope, preserve the scope-qualified work id through every CBOR command/event,
  and keep producer resend separate from consumer-redelivery idempotence.
- [`vault_pki_doctrine.md` §3 — The SecretRef contract: a name, never a value](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)
  and [`tenancy_doctrine.md` §7 — Two isolation layers, and the honest limit](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit):
  derive scope from authenticated service context and keep secret values out of configuration.
- [`testing_spoof_resistance.md` §12 — Spoof-resistant evidence](../documents/engineering/testing_spoof_resistance.md#12-spoof-resistant-evidence):
  require an unpredictable challenge and independently observed effect.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in reviewed Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 91.1: Re-derive infernix behind one scoped artifact adapter ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [Lift and Compose Doctrine §5 — The re-derivation map](../documents/engineering/lift_and_compose_doctrine.md#5-the-re-derivation-map):
link the existing inference core behind one typed, reversible, scope-checked artifact facade over amoebius's
already-closed store, transport, secret, engine, workflow, determinism, and resource capabilities.

### Deliverables

- One `Infernix.Adapter.Core` facade and narrow effect adapters, with the resolved sibling core unchanged.
- Private-constructor staged/ready artifact states indexed by authenticated tenant scope and provenance.
- Native CBOR commands/events preserving one scope-qualified command/work id, Vault secret names, named cached
  engines, deterministic CPU decode, and ready-last content-store publication behind that facade.
- A finite `CpuInferenceWorkBudget` merged into inherited workflow/cache/store resource owners.
- Independently reviewed Haskell cases and expectations, four named Haskell changed-subject operators, a
  generated Register-3 ledger, and run-local sibling
  source identity observations.

### Validation

1. The pre-reset Python command is rejected and must not run. The future Haskell Phase-91 supporting suite must run on linux-cpu with
   networking limited to the declared live dependencies and harness observers.
2. Require ready-last staging, two independently executed cold results, byte equality with each other and the
   run-local sibling reference, and warm reuse of the named engine.
3. Resend the exact workflow-start command and require the original outcome with no duplicate effect; reuse its
   command id with a changed input and require the pinned pre-effect idempotency conflict.
4. Replay the ready reference under tenant B and the pre-commit reference under tenant A; require their exact
   denials and zero forbidden Pulsar, MinIO, cache, or worker effect.
5. Require the Haskell URL-engine and one-short resource cases to refuse before effects. Generate the sibling-source
   inventory before and after both adapter selections under the run bundle and require it to remain unchanged.
6. Apply each named Haskell changed-subject operator and require the unchanged command to fail before a leak-free evidence ledger can be
   emitted.

### Remaining Work

Any pre-reset serialized source inventories, expected hashes, golden outputs, or duplicated hash constants are
condemned legacy inventory and not implementation instructions. Generate before/after source identity and
reference output per run beneath ignored `.build/**`, from independently reviewed Haskell expectations that do
not share the production subject's revision. Production
TinyLlama-weights inference, linkage of the full sibling inference-engine core, direct Pulsar-command-to-worker
causality, worker-direct MinIO artifact fetch with a worker-used Vault credential, general noninterference, and
cross-substrate bit equality remain explicit UNVERIFIED follow-on surfaces.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/lift_and_compose_doctrine.md` and
  `documents/engineering/app_vs_deployment_doctrine.md` — record the linked core and four re-homed seams, with
  no frontend claim and with full-engine linkage still UNVERIFIED.
- `documents/engineering/content_addressing_doctrine.md` — record only the tested linux-cpu artifact and
  reproducibility matrix.
- `documents/engineering/pulsar_client_doctrine.md` and `documents/engineering/vault_pki_doctrine.md` — record
  the live CBOR transport and secrets-by-name observations.
- `documents/engineering/tenancy_doctrine.md` and `documents/engineering/testing_doctrine.md` — record the
  tested scope denial, fresh challenge, repository-local evidence, and killed Haskell changed subjects without a general proof claim.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/substrates.md` — link the scoped phase result and its
  linux-cpu Register-3 ledger after the aggregate gate is green.
- `DEVELOPMENT_PLAN/system_components.md` — register only the core adapter, deterministic decode, and live gate.
- `DEVELOPMENT_PLAN/phase_92_infernix_ui_rederivation.md` — remain the sole owner of infernix UI projection and
  interaction.
- `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md` — record the replaced store, WebSocket, secret, and baked
  engine envelope pieces.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 69 — content store and workflow runtime](phase_69_content_store_workflow.md)
- [Phase 80 — determinism and JIT cache](phase_80_determinism_jitcache.md)
- [Phase 92 — infernix UI lift](phase_92_infernix_ui_rederivation.md)
- [Phase 93 — jitML lift](phase_93_jitml_rederivation.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md)
- [Native Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md)
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
