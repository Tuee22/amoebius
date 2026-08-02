# Phase 49: infernix core artifact lift

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_25_base_image_registry.md, DEVELOPMENT_PLAN/phase_48_determinism_jitcache.md, DEVELOPMENT_PLAN/phase_50_infernix_ui_lift.md, DEVELOPMENT_PLAN/phase_51_jitml_lift_cuda.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Lift the sibling infernix inference core behind one linked Haskell artifact adapter and test
> live that only a committed, owned artifact can drive deterministic CPU inference through amoebius services.

---

## Phase Status

📋 Planned. The linked adapter and its live evidence do not exist; the sibling infernix implementation is
feasibility evidence only, not an amoebius result.

## Phase Summary

This phase owns one seam: `Infernix.Adapter.Core` maps the existing infernix workflow and artifact contracts
onto already-closed amoebius capabilities. Store operations use the Phase-37 three-tier content-addressed
store; commands and events use the Phase-35 native CBOR Pulsar client; credentials remain Vault `SecretRef`
names; named engines resolve through the Phase-48 jit-build cache; CPU decode uses the Phase-48
`experimentHash` and derived SplitMix seed. The sibling inference algorithms remain linked Haskell library
code and are not rewritten.

Every workflow start enters the adapter with one server-derived, scope-qualified `CommandId`. The adapter
preserves it unchanged as the Phase-37 work-id in the canonical command payload and in every progress or
terminal event; it never derives a replacement from a pod, retry, run id, or artifact digest. Producer resends
retain the producer identity/sequence required by Phase 35, while consumer redelivery folds on that stable
work-id. Reusing the same scoped command id and normalized input returns the same workflow/artifact outcome;
reusing it with a different normalized input is a typed idempotency conflict before inference or store effects.

The adapter exposes only server-side, scope-indexed workflow and artifact values. A private-constructor
`ReadyArtifactHandle scope` is minted only after blob and canonical-CBOR manifest verification and the final
ready-pointer commit. It carries no client-chosen tenant, storage coordinate, engine address, credential, or
raw provider handle. Phase 50 is the sole infernix-to-UI boundary; this phase owns no frontend, browser probe,
HTTP presentation server, generated client contract, or UI deployment.

One finite `CpuInferenceWorkBudget` supplies model/engine identity, threads, concurrency, token bounds, retry
and buffer bounds, and complete CPU/memory/ephemeral demand to the inherited Phase-37 workflow envelope. Its
accelerator is structurally `None`; engine-cache and content-store demand merge into their existing owners,
with no unbounded/default resource arm or fictional client Pod.

**Session scope:** In one uninterrupted engineering session, implement the thin linked adapter facade and
accept it with `cabal test infernix-core-artifact-lift-live-gate`. Split if the work changes sibling inference
algorithms, adds a platform capability, creates a server/UI runtime, or requires a second acceptance command.
**Substrate:** linux-cpu
**Register:** 3 (live infrastructure)
**Gate:** `cabal test infernix-core-artifact-lift-live-gate` drives a freshly challenged, tenant-scoped workflow
through the live adapter to a committed ready artifact and two cache-cold CPU inferences, then establishes that a
foreign-scope reference and an uncommitted artifact are denied before dispatch. The representative fixtures,
external observers, independent oracle, paired cases, and mutants are delegated to
[Gate integrity](#gate-integrity).

## Gate integrity

- **Phase-0 representative set.** Before implementation, Phase 0 commits
  `test/dhall/phase_49/infernix_core_artifact_lift.dhall`,
  `test/dhall/phase_49/cpu_budget_one_short.dhall`,
  `test/fixtures/phase_49/request.cbor`,
  `test/fixtures/phase_49/sibling_golden.cbor`,
  `test/fixtures/phase_49/expected_hashes.tsv`,
  `test/fixtures/phase_49/command_identity_matrix.tsv`,
  `test/fixtures/phase_49/artifact_scope_readiness_matrix.tsv`, and
  `test/fixtures/phase_49/frozen_sources.txt`. The fixed request uses the closed catalog identity
  `catalog/tinyllama-1.1b-cpu@<sha256>` and seed `0x0000000000000001`.
- **Fresh authenticated challenge.** After Pulsar, MinIO, Vault, the cache owner, and workflow workers are
  Ready, the elevated harness obtains one-use least-privilege service credentials for tenant A and tenant B
  and generates an unpredictable nonce and command id. Tenant A's command, every derived event, committed
  result provenance, and terminal identity tuple must contain them unchanged; replayed evidence from an
  earlier run cannot pass.
- **Positive artifact flow.** Tenant A stages the pinned model as blob → canonical manifest → ready pointer,
  last, and obtains `ReadyArtifactHandle TenantA`. Two distinct run ids under one unchanged `experimentHash`
  begin without output keys, execute independently, and produce byte-identical outputs that also match the
  Phase-0 sibling golden. A second invocation reuses the named engine cache without rematerialization. An
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
- **Independent oracle and reversibility.** The sibling golden is recorded from the frozen sibling binary;
  expected hashes and the scope/readiness matrix are hand-authored independently of the adapter. Switching
  legacy ↔ amoebius adapters must leave every pre-lift core source in `frozen_sources.txt` byte-unchanged.
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

## Sprint 49.1: Lift infernix through one scoped artifact adapter 📋

**Status**: Planned
**Implementation**: `infernix/src/Infernix/Adapter/{Core,Store,Pulsar,Secrets,Engine}.hs`,
`infernix/src/Infernix/Inference/Deterministic.hs`, `infernix/dhall/infernix.dhall`, and
`test/live/Phase49InfernixArtifactLift.hs` (target paths; not yet built)
**Blocked by**: Phase 29 gate; Phase 35 gate; Phase 37 gate; Phase 48 gate.
**Independent Validation**: the one live gate compares two externally observed cold computations with the
sibling golden and hand-authored identity/scope/readiness oracles, establishes that both denials have zero effect, and
requires all four committed mutants to fail.
**Docs to update**: `documents/engineering/lift_and_compose_doctrine.md`,
`documents/engineering/app_vs_deployment_doctrine.md`,
`documents/engineering/content_addressing_doctrine.md`,
`documents/engineering/pulsar_client_doctrine.md`, `documents/engineering/vault_pki_doctrine.md`,
`documents/engineering/tenancy_doctrine.md`, and `documents/engineering/testing_doctrine.md`.

### Objective

Adopt [Lift and Compose Doctrine §2 — What lifts](../documents/engineering/lift_and_compose_doctrine.md#2-what-lifts-the-reuse-map):
link the existing inference core behind one typed, reversible, scope-checked artifact facade over amoebius's
already-closed store, transport, secret, engine, workflow, determinism, and resource capabilities.

### Deliverables

- One `Infernix.Adapter.Core` facade and narrow effect adapters, with the frozen sibling core unchanged.
- Private-constructor staged/ready artifact states indexed by authenticated tenant scope and provenance.
- Native CBOR commands/events preserving one scope-qualified command/work id, Vault secret names, named cached
  engines, deterministic CPU decode, and ready-last content-store publication behind that facade.
- A finite `CpuInferenceWorkBudget` merged into inherited workflow/cache/store resource owners.
- Phase-0 fixtures, four named mutants, and a Register-3 evidence ledger with external-source digests.

### Validation

1. Run `cabal test infernix-core-artifact-lift-live-gate` on linux-cpu with networking limited to the declared
   live dependencies and harness observers.
2. Require ready-last staging, two independently executed cold results, byte equality with each other and the
   sibling golden, and warm reuse of the named engine.
3. Resend the exact workflow-start command and require the original outcome with no duplicate effect; reuse its
   command id with a changed input and require the pinned pre-effect idempotency conflict.
4. Replay the ready reference under tenant B and the pre-commit reference under tenant A; require their exact
   denials and zero forbidden Pulsar, MinIO, cache, or worker effect.
5. Require the URL-engine and one-short resource fixtures to refuse before effects, and verify the frozen core
   remains byte-unchanged across legacy/amoebius adapter selection.
6. Apply each named mutant and require the unchanged command to fail before a leak-free evidence ledger can be
   emitted.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/lift_and_compose_doctrine.md` and
  `documents/engineering/app_vs_deployment_doctrine.md` — record the linked core and four re-homed seams, with
  no frontend claim.
- `documents/engineering/content_addressing_doctrine.md` — record only the tested linux-cpu artifact and
  reproducibility matrix.
- `documents/engineering/pulsar_client_doctrine.md` and `documents/engineering/vault_pki_doctrine.md` — record
  the live CBOR transport and secrets-by-name observations.
- `documents/engineering/tenancy_doctrine.md` and `documents/engineering/testing_doctrine.md` — record the
  tested scope denial, fresh challenge, external evidence, and killed mutants without a general proof claim.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` and `DEVELOPMENT_PLAN/substrates.md` — link the phase and flip status only after
  the linux-cpu Register-3 ledger is green.
- `DEVELOPMENT_PLAN/system_components.md` — register only the core adapter, deterministic decode, and live gate.
- `DEVELOPMENT_PLAN/phase_50_infernix_ui_lift.md` — remain the sole owner of infernix UI projection and
  interaction.
- `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md` — record the replaced store, WebSocket, secret, and baked
  engine envelope pieces.

## Related Documents

- [Development-plan standards](development_plan_standards.md)
- [Phase 37 — content store and workflow runtime](phase_37_content_store_workflow.md)
- [Phase 48 — determinism and JIT cache](phase_48_determinism_jitcache.md)
- [Phase 50 — infernix UI lift](phase_50_infernix_ui_lift.md)
- [Phase 51 — jitML lift](phase_51_jitml_lift_cuda.md)
- [Lift and Compose Doctrine](../documents/engineering/lift_and_compose_doctrine.md)
- [Content Addressing Doctrine](../documents/engineering/content_addressing_doctrine.md)
- [Native Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md)
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md)
- [Tenancy Doctrine](../documents/engineering/tenancy_doctrine.md)
- [Testing Doctrine](../documents/engineering/testing_doctrine.md)
