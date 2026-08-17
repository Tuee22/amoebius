# Phase 54: infernix core artifact lift

> **Purpose**: Lift the sibling infernix inference core behind one linked Haskell artifact adapter and test
> live that only a committed, owned artifact can drive deterministic CPU inference through amoebius services.
> **Read this if**: phase 54 is next in the queue, or a later phase depends on what its gate establishes.

Phase 54 delivers the infernix core artifact lift; its design is owned by [lift_and_compose_doctrine.md](../documents/engineering/lift_and_compose_doctrine.md), [app_vs_deployment_doctrine.md](../documents/engineering/app_vs_deployment_doctrine.md), [content_addressing_doctrine.md](../documents/engineering/content_addressing_doctrine.md), and the plan for reaching it is owned here.
Register 3, live, on the `linux-cpu` substrate.
Scoped seal: `python3 tools/phase49_gate.py --reuse-fresh-live` passed 19 checks
on 2026-08-11; ledger `external-run-reference`,
receipt `external-run-reference`. `linux-cpu`
remains a valid choice on Linux, Linux-CUDA, Apple, and Windows hardware. Clean Linux execution is
materialized with Incus, Lima, and WSL2 respectively.


> **Historical result (invalidated).** Any pass, seal, validation, ledger, receipt, or implementation observation
> in the orientation text above is diagnostic only. The Phase Status section and [tracker](README.md) own current state; the
> target contract below remains normative.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_30_base_image_registry.md, DEVELOPMENT_PLAN/phase_53_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_55_infernix_ui_lift.md, DEVELOPMENT_PLAN/phase_65_jitml_lift_cuda.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

</details>

## Contents
- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 54.1: Lift infernix through one scoped artifact adapter ⏸️](#sprint-541-lift-infernix-through-one-scoped-artifact-adapter-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked pending Phase-53 revalidation — **reopened 2026-08-16 by the natural-architecture amendment.**
[§S](development_plan_gate_integrity.md#s-universal-artifact-hygiene-gate) clause 15 requires a run to record
the natural architecture it proved and to execute no artifact of another. This phase's last gate recorded no
architecture, so its seal is invalidated as a current result and stands only as history; the rerun differs from
it by naming the lane and architecture the run actually used. A sprint marker below records what that sprint achieved before the amendment; under
[§N](development_plan_phase_model.md#n-reopening-and-amending-a-phase) it is a diagnostic, not surviving closure.

**Pre-natural-architecture status record (invalidated where it claims completion):**

Blocked (superseded) — containment amendment recorded 2026-08-15. Any earlier capability seal is historical and
invalidated until this phase reruns in numerical order with all amoebius-owned state confined to the
repository roots defined by Phase 0. Scope amendments below remain normative.

**Pre-containment status record (invalidated where it claims completion):**

Blocked (superseded) by the reopened numeric sequence. Reopened 2026-08-11: the prior seal did not include the universal artifact-hygiene
postcondition. This phase returns to numeric order only after Phase 0 closes, then must rerun its capability
gate against its source snapshot and publish repository-local evidence without changing an authored path.

**Observed artifact migration — 2026-08-11:** `frozen_sources.txt` inventories sibling source,
`expected_hashes.tsv` reproduces its file hashes, and `sibling_golden.cbor` captures sibling-program output.
The gate also duplicates the hashes as constants. These are generated observations, not authored expectations.
The owning sprint must resolve and execute the reviewed sibling boundary per run and retain its identity and
reference output only in repository-local evidence.

**Invalidated historical record:**

🟡 PASS-SCOPED. The typed artifact facade, linked sibling compacted-topic module, native
CBOR driver, deterministic CPU micro-decoder, finite budget, pure contracts, compile-foreclosure cases, four
compiled mutants, and fresh retained-platform evidence are present. The evidence uses a pinned micro-model,
not production TinyLlama weights, and therefore does not establish the full sibling inference engine or
cross-substrate equality.

## Phase Summary

This phase owns one seam: `Infernix.Adapter.Core` maps an infernix workflow and artifact contract onto
already-closed amoebius capabilities. The package compiles the untouched sibling
`Infernix.Topic.Metadata` module and uses its compacted view for command-outcome deduplication; the remaining
sibling source boundary is reviewed and resolved dynamically. Store operations use the Phase-42 three-tier content-addressed store;
commands and events use typed native CBOR over Pulsar; credentials remain Vault `SecretRef` names; named
engines resolve through the Phase-53 jit-build cache; CPU decode uses a deterministic pinned micro-model.
Linkage of the full sibling inference-engine core and production TinyLlama execution remain UNVERIFIED.

Every workflow start enters the adapter with one server-derived, scope-qualified `CommandId`. The adapter
preserves it unchanged as the Phase-42 work-id in the canonical command payload and in every progress or
terminal event; it never derives a replacement from a pod, retry, run id, or artifact digest. Producer resends
retain the producer identity/sequence required by Phase 40, while consumer redelivery folds on that stable
work-id. Reusing the same scoped command id and normalized input returns the same workflow/artifact outcome;
reusing it with a different normalized input is a typed idempotency conflict before inference or store effects.

The adapter exposes only server-side, scope-indexed workflow and artifact values. A private-constructor
`ReadyArtifactHandle scope` is minted only after blob and canonical-CBOR manifest verification and the final
ready-pointer commit. It carries no client-chosen tenant, storage coordinate, engine address, credential, or
raw provider handle. Phase 55 is the sole infernix-to-UI boundary; this phase owns no frontend, browser probe,
HTTP presentation server, generated client contract, or UI deployment.

One finite `CpuInferenceWorkBudget` supplies model/engine identity, threads, concurrency, token bounds, retry
and buffer bounds, and complete CPU/memory/ephemeral demand to the inherited Phase-42 workflow envelope. Its
accelerator is structurally `None`; engine-cache and content-store demand merge into their existing owners,
with no unbounded/default resource arm or fictional client Pod.

**Session scope:** In one uninterrupted engineering session, implement the thin linked adapter facade and
accept it with the Phase-54 aggregate gate. Split if the work changes sibling inference algorithms, adds a
platform capability, or creates a server/UI runtime.
**Substrate:** linux-cpu
**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 (live infrastructure)
**Gate:** `python3 tools/phase49_gate.py --reuse-fresh-live` passes every fixture, observer, oracle, paired
case, and mutant of [Gate integrity](#gate-integrity). `cabal test infernix-core-artifact-lift-live-gate` is an
independent evidence reader, never the acceptance command.

## Gate integrity

- **What the one command decides.** The gate verifies reviewed fixture provenance, dynamic sibling linkage and
  run-local before/after identity, constructor foreclosure, pure contracts, Register-3 evidence, external
  cleanup, an independent Haskell evidence reader, all four compiled mutants, baseline restoration,
  documentation, and the ledger. Every one of those rests on a clause below.
- **Representative-set candidates.** After Phase-0 and owning-phase provenance review, the gate may retain
  `test/dhall/phase_50/infernix_core_artifact_lift.dhall`,
  `test/dhall/phase_50/cpu_budget_one_short.dhall`,
  `test/fixtures/phase_50/request.cbor`,
  `test/fixtures/phase_50/command_identity_matrix.tsv`,
  `test/fixtures/phase_50/artifact_scope_readiness_matrix.tsv`. Existing same-commit candidates remain
  regression fixtures until independently reviewed or replaced. The fixed request uses the closed catalog identity
  `catalog/tinyllama-1.1b-cpu@<sha256>` and seed `0x0000000000000001`.
- **Fresh authenticated challenge.** After Pulsar, MinIO, Vault, the cache owner, and workflow workers are
  Ready, the elevated harness obtains one-use least-privilege service credentials for tenant A and tenant B
  and generates an unpredictable nonce and command id. Tenant A's command, every derived event, committed
  result provenance, and terminal identity tuple must contain them unchanged; replayed evidence from an
  earlier run cannot pass.
- **Positive artifact flow.** Tenant A stages the pinned model as blob → canonical manifest → ready pointer,
  last, and obtains `ReadyArtifactHandle TenantA`. Two distinct run ids under one unchanged `experimentHash`
  begin without output keys, execute independently, and produce byte-identical outputs that also match a
  fresh independently executed sibling reference under the run bundle. A second invocation reuses the named
  engine cache without rematerialization. An
  exact resend of the workflow-start command returns the original handle/outcome and causes no second workflow,
  worker execution, pointer advance, or result object; the same command id with a changed input returns the
  pinned idempotency conflict with the same zero-effect rule.
- **Paired denials.** The identical ready reference, request, program identity, and nonce under tenant B differ
  only in authenticated scope and yield the pinned non-enumerating denial with zero worker dispatch, artifact
  read, or result write. Under tenant A, an otherwise identical pre-commit artifact differs only in readiness;
  no typed conversion exists, and a forged wire reference yields `ArtifactNotReady` with the same zero effect.
- **Closed capability and resource negatives.** A positive catalog engine identity typechecks; changing only
  that identity to a download URL fails at the absent `Url` constructor. The one-short CPU/RAM/cache budget
  fixture refuses before Vault read, Pulsar publish, cache materialization, or MinIO mutation.
- **Bypass probes.** Tenant B's real credential is sent directly to the adapter with tenant A's ready digest,
  bypassing any workflow-facing guard, and is also tried directly against the MinIO and Pulsar service paths.
  Adapter dispatch must remain absent and the caller credential must confer no provider authority; external
  provider observers, rather than the adapter response, decide both outcomes.
- **Observer outside the SUT.** The gate reads Pulsar topic offsets/audit, MinIO audit and object history, Vault
  audit, cache-owner inventory, and the worker's containerd/cgroup plus argv/syscall execution witness. Adapter
  logs and self-reported traces are not evidence; absent, unauthenticated, or nonce-mismatched evidence fails.
- **Committed mutants.** Phase 0 commits
  `test/mutants/phase_49/mut-49-drop-artifact-scope.patch`,
  `test/mutants/phase_49/mut-49-mint-ready-before-pointer-commit.patch`, and
  `test/mutants/phase_49/mut-49-use-wallclock-seed.patch`, plus
  `test/mutants/phase_49/mut-49-regenerate-command-id.patch`. The unchanged gate must turn red on the exact
  scope, readiness, cold-recompute, and command-redelivery rows respectively.
- **Independent oracle and reversibility.** The sibling expected behavior is recomputed by the independently
  built sibling reference during the run; its output stays under `.build/runs/phase_54/`. The reviewed
  scope/readiness matrix supplies the behavior expectation. The gate records a run-local sibling-source
  inventory before and after both adapter paths and requires equality, without a tracked inventory or hash.
- **Teardown and honesty.** An external pre/post inventory must enumerate and clear test-owned Kubernetes,
  Pulsar, and run-prefixed MinIO ephemera; named content-addressed fixtures are the only retained class. The
  gate tests one linux-cpu corpus and scope pair, not general noninterference or cross-substrate bit equality.

## Doctrine adopted

- [Lift and Compose Doctrine §2 — What lifts](../documents/engineering/lift_and_compose_doctrine.md#2-what-lifts-the-reuse-map)
  and [§3 — Friction envelope](../documents/engineering/lift_and_compose_doctrine.md#3-the-friction-envelope-what-is-re-shaped-during-the-lift):
  retain infernix computation while re-homing store, transport, secrets, and engine seams.
- [Lift and Compose Doctrine §5 — Evidence, not proof](../documents/engineering/lift_and_compose_doctrine.md#5-evidence-not-proof):
  keep sibling behavior as evidence until this live gate passes.
- [App vs Deployment Doctrine §7 — infernix is a shared library](../documents/engineering/app_vs_deployment_doctrine.md#7-infernix-is-a-shared-library-the-inference-substrate-is-a-deployment-rule):
  link the core as a library while keeping substrate selection in deployment rules.
- [Content Addressing Doctrine §2 — Three-tier store](../documents/engineering/content_addressing_doctrine.md#2-the-three-tier-store-blobs--manifests--pointers),
  [§3 — `experimentHash`](../documents/engineering/content_addressing_doctrine.md#3-experimenthash-identity-is-what-was-requested--where-it-ran),
  and [§4 — Determinism by construction](../documents/engineering/content_addressing_doctrine.md#4-determinism-by-construction-pinned-inputs--pure-stages--derived-seed):
  bind verified artifacts, substrate identity, pure decode, and derived seed.
- [Content Addressing Doctrine §4.5 — Bounded ML-asset cache](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
  and [§6 — Honest ceiling](../documents/engineering/content_addressing_doctrine.md#6-the-honest-ceiling-types-make-the-bookkeeping-total-not-the-physics-deterministic):
  resolve named engines on first miss and claim reproducibility only on the tested substrate.
- [Pulsar Client Doctrine §1 — One wire](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets),
  [§3.1 — CBOR payloads](../documents/engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor),
  and [§7 — At-least-once with dedup](../documents/engineering/pulsar_client_doctrine.md#7-delivery-at-least-once-with-broker-side-dedup-the-robust-default):
  remove the WebSocket/JSON envelope, preserve the scope-qualified work id through every CBOR command/event,
  and keep producer resend separate from consumer-redelivery idempotence.
- [Vault / PKI Doctrine §3 — `SecretRef`](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value)
  and [Tenancy Doctrine §7 — Two isolation layers](../documents/engineering/tenancy_doctrine.md#7-two-isolation-layers-and-the-honest-limit):
  derive scope from authenticated service context and keep secret values out of configuration.
- [Testing Doctrine §12 — Spoof-resistant evidence](../documents/engineering/testing_doctrine.md#12-spoof-resistant-evidence-a-gate-observes-an-unforgeable-fresh-effect):
  require an unpredictable challenge and independently observed effect.

## Sprints

> **Current revalidation rule.** Every sprint is blocked by the reopened numeric sequence. Historical dates,
> pass/seal claims, repository-resident evidence paths, and `Remaining Work: None` statements below describe
> the pre-amendment capability record only; they do not override current status. Functional and validation
> outcomes remain target requirements. Any instruction to commit generated output, freeze dependency resolution,
> retain a resolved version, path, or integrity hash, or consume repository-resident evidence, ledgers, or
> enumerations is superseded by the current generated-artifact and dynamic-resolution doctrine. Closure requires
> the current phase gate plus universal artifact hygiene.

## Sprint 54.1: Lift infernix through one scoped artifact adapter ⏸️

**Status**: Blocked by the reopened numeric sequence; prior capability footprint retained for migration
**Implementation**:
`infernix/src/Infernix/Adapter/{Core,Store,Pulsar,Secrets,Engine}.hs`,
`infernix/src/Infernix/Inference/Deterministic.hs`, `infernix/dhall/infernix.dhall`, and
`infernix/app/NativeDriver.hs` — a **gate driver, not a runtime role**, and therefore not a second amoebius
executable; its `executable phase49-native-driver` stanza in `infernix/infernix-lift.cabal` names a phase
ordinal and retires here
([legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md#one-binary-many-roles--2026-08-17)) —
`tools/phase49_infernix_artifact_live.py`, and
`test/live/InfernixArtifactLift.hs`
**Blocked by**: reopened numeric predecessor gates.
**Independent Validation**: the one live gate compares two
externally observed cold computations with a fresh sibling reference and reviewed identity/scope/readiness
oracles, establishes that both denials have zero effect, and requires all four committed mutants to fail.
**Docs to update**: `documents/engineering/lift_and_compose_doctrine.md`,
`documents/engineering/app_vs_deployment_doctrine.md`,
`documents/engineering/content_addressing_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`,
`documents/engineering/vault_pki_doctrine.md`, `documents/engineering/tenancy_doctrine.md`, and
`documents/engineering/testing_doctrine.md`.

### Objective

Adopt [Lift and Compose Doctrine §2 — What lifts](../documents/engineering/lift_and_compose_doctrine.md#2-what-lifts-the-reuse-map):
link the existing inference core behind one typed, reversible, scope-checked artifact facade over amoebius's
already-closed store, transport, secret, engine, workflow, determinism, and resource capabilities.

### Deliverables

- One `Infernix.Adapter.Core` facade and narrow effect adapters, with the resolved sibling core unchanged.
- Private-constructor staged/ready artifact states indexed by authenticated tenant scope and provenance.
- Native CBOR commands/events preserving one scope-qualified command/work id, Vault secret names, named cached
  engines, deterministic CPU decode, and ready-last content-store publication behind that facade.
- A finite `CpuInferenceWorkBudget` merged into inherited workflow/cache/store resource owners.
- Independently reviewed fixtures, four named mutants, a generated Register-3 ledger, and run-local sibling
  source identity observations.

### Validation

1. Run `python3 tools/phase49_gate.py --reuse-fresh-live` on linux-cpu with
   networking limited to the declared live dependencies and harness observers.
2. Require ready-last staging, two independently executed cold results, byte equality with each other and the
   run-local sibling reference, and warm reuse of the named engine.
3. Resend the exact workflow-start command and require the original outcome with no duplicate effect; reuse its
   command id with a changed input and require the pinned pre-effect idempotency conflict.
4. Replay the ready reference under tenant B and the pre-commit reference under tenant A; require their exact
   denials and zero forbidden Pulsar, MinIO, cache, or worker effect.
5. Require the URL-engine and one-short resource fixtures to refuse before effects. Generate the sibling-source
   inventory before and after both adapter selections under the run bundle and require it to remain unchanged.
6. Apply each named mutant and require the unchanged command to fail before a leak-free evidence ledger can be
   emitted.

### Remaining Work

Remove `frozen_sources.txt`, `expected_hashes.tsv`, `sibling_golden.cbor`, and the gate's duplicated hash
constants. Generate before/after source identity and reference output per run, and independently review or
replace the remaining same-commit fixtures before revalidation. Production
TinyLlama-weights inference, linkage of the full sibling inference-engine core, direct Pulsar-command-to-worker
causality, worker-direct MinIO artifact fetch with a worker-used Vault credential, general noninterference, and
cross-substrate bit equality remain explicit UNVERIFIED follow-on surfaces.

## Documentation Requirements

**Engineering docs updated for the scoped result:**
- `documents/engineering/lift_and_compose_doctrine.md` and
  `documents/engineering/app_vs_deployment_doctrine.md` — record the linked core and four re-homed seams, with
  no frontend claim and with full-engine linkage still UNVERIFIED.
- `documents/engineering/content_addressing_doctrine.md` — record only the tested linux-cpu artifact and
  reproducibility matrix.
- `documents/engineering/pulsar_client_doctrine.md` and `documents/engineering/vault_pki_doctrine.md` — record
  the live CBOR transport and secrets-by-name observations.
- `documents/engineering/tenancy_doctrine.md` and `documents/engineering/testing_doctrine.md` — record the
  tested scope denial, fresh challenge, repository-local evidence, and killed mutants without a general proof claim.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/substrates.md` — link the scoped phase result and its
  linux-cpu Register-3 ledger after the aggregate gate is green.
- `DEVELOPMENT_PLAN/system_components.md` — register only the core adapter, deterministic decode, and live gate.
- `DEVELOPMENT_PLAN/phase_55_infernix_ui_lift.md` — remain the sole owner of infernix UI projection and
  interaction.
- `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md` — record the replaced store, WebSocket, secret, and baked
  engine envelope pieces.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 42 — content store and workflow runtime](phase_42_content_store_workflow.md)
- [Phase 53 — determinism and JIT cache](phase_53_determinism_jitcache.md)
- [Phase 55 — infernix UI lift](phase_55_infernix_ui_lift.md)
- [Phase 65 — jitML lift](phase_65_jitml_lift_cuda.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md)
- [Native Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md)
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
