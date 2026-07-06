# Phase 0: Documentation suite (whole DSL)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, overview.md
**Generated sections**: none

> **Purpose**: Author the complete amoebius DSL specification and every engineering doctrine before any
> implementation phase begins, with a documentation lint as the single acceptance gate.

---

## Phase Status

📋 Planned. The whole DSL is specified — comprehensively and explicitly — in `documents/` and
`DEVELOPMENT_PLAN/` before a line of the binary is written; nothing here is built, only authored.

## Phase Summary

This phase owns the **entire documentation suite**: the DSL specification and every doctrine enumerated in
the [engineering doctrine index](../documents/engineering/README.md), plus the plan suite that sequences the
implementation phases. It is the one phase whose deliverable *is* prose — the orchestration Dhall DSL
(cluster / app-spec / deployment-rules types) and its illegal-state-unrepresentable contract;
service-capabilities; manifest-generation (typed manifests + the typed reconciler, no Helm);
platform-services; image-build (baked binaries + the `distribution` registry); storage-lifecycle; Vault/PKI
trust-tree + secret-injection; Pulumi IaC; the chaos/failover (async geo-replication) doctrine;
daemon-topology (control-plane singleton + worker roles); substrate; host↔cluster comms; the native Pulsar
client; content-addressing/determinism; and the testing doctrine (test-as-`.dhall`, `suggest-test`, the
proven/tested/assumed ledger). It also authors the plan-suite spine — the rulebook, the live tracker, and the
target architecture/inventory/substrate documents — so that every later phase cites doctrine by name when it
schedules adoption work.

Because the deliverable is documentation, this phase establishes no cluster state and runs no workflow. The
cross-cutting invariants the whole plan upholds (no environment variables ever including `PATH`;
illegal/unsafe cluster state unrepresentable in Dhall; the app-logic/deployment-rules split; secrets-by-name;
HA-always; `no-provisioner` retained PVs; declared cpu/ram; Keycloak-owns-all-ingress) are *first written
down here* and then upheld by Phases 1–12.

**Substrate:** none (§L) — the gate is a pure documentation lint over text and the link graph; it touches no
`apple`, `linux-cpu`, `linux-cuda`, or `windows` host and stands up no resources.

**Gate:** the documentation lint passes — every document in `documents/` and `DEVELOPMENT_PLAN/` carries a
valid header metadata block (per the documentation standard), the SSoT/no-duplication rules hold (each
concept owned by exactly one doc, others link to it), and there are **no orphan cross-links** (every relative
link with an anchor resolves, and `Referenced by` headers are reconciled from the true link graph in both
directions).

## Doctrine adopted

This phase *authors* every document below; the citations point at the flagship section each doc owns and
state what Phase 0 commits to writing. The plan-suite naming and header mechanics adapt conventions proven in
the sibling **prodbox** project — that is prior-art evidence, not amoebius proof.

- [`documentation_standards.md` §3 — Required header metadata](../documents/documentation_standards.md#3-required-header-metadata):
  this phase writes every doc against the standard's header block, SSoT-first philosophy (§1), and
  bidirectional cross-referencing (§4) — the three rules the gate's lint checks.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  this phase specifies the orchestration Dhall surface and the two-gate (Dhall typechecker + Haskell typed
  decoder) contract that makes illegal cluster state fail to type-check.
- [`app_vs_deployment_doctrine.md` §1 — Two surfaces, one app written once](../documents/engineering/app_vs_deployment_doctrine.md#1-two-surfaces-one-app-written-once):
  this phase documents the hard split between application logic and deployment rules.
- [`illegal_state_catalog.md` §1 — The promise: illegal states fail to type-check](../documents/engineering/illegal_state_catalog.md#1-the-promise-illegal-states-fail-to-type-check):
  this phase catalogs each illegal state and the typing technique that forecloses it, with honest layers of
  foreclosure.
- [`service_capability_doctrine.md` §1 — Why capabilities, not products](../documents/engineering/service_capability_doctrine.md#1-why-capabilities-not-products):
  this phase specifies the capability set, the one-canonical-provider rule, and capability→provider→shape
  binding.
- [`platform_services_doctrine.md` §1 — The Invariant: every cluster is the same cluster](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster):
  this phase enumerates the standard services and the HA-always / Keycloak-owns-all-ingress invariants.
- [`storage_lifecycle_doctrine.md` §1 — The one idea: clusters are cattle, storage is land](../documents/engineering/storage_lifecycle_doctrine.md#1-the-one-idea-clusters-are-cattle-storage-is-land):
  this phase specifies `no-provisioner` retained PVs, deterministic rebind, and the deletion-forbidden rule.
- [`cluster_lifecycle_doctrine.md` §1 — Two cluster kinds, one lifecycle shape](../documents/engineering/cluster_lifecycle_doctrine.md#1-two-cluster-kinds-one-lifecycle-shape):
  this phase documents bootstrap, amoebic spawning, teardown-with-cleanup vs chaos-failover, and push-back on
  unsatisfiable `.dhall`.
- [`readiness_ordering_doctrine.md` §1 — Why this doctrine exists](../documents/engineering/readiness_ordering_doctrine.md#1-why-this-doctrine-exists):
  this phase documents event-driven bring-up sequencing — a dependent starts on a dependency's observed
  readiness edge, never an elapsed duration — with the honest limit that the spec forecloses the sequence
  shape, not the port's liveness.
- [`substrate_doctrine.md` §1 — The substrate is a fact about the host, not a knob](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob):
  this phase specifies substrate detection, virtualized substrates, and the no-env/no-`PATH` lazy
  tool-ensure contract.
- [`image_build_doctrine.md` §2 — The single distribution rule: bake the binaries, build the amoebius image, pull only in-cluster](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster):
  this phase documents baked multi-arch binaries and the single-binary `distribution` registry that replaces
  Harbor.
- [`manifest_generation_doctrine.md` §1 — Why this doctrine exists: types render manifests, Helm does not](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not):
  this phase specifies pure typed manifest generation and the idempotent typed reconciler (server-side apply,
  ApplySet prune, wait).
- [`vault_pki_doctrine.md` §2 — Vault is the fail-closed secrets root](../documents/engineering/vault_pki_doctrine.md#2-vault-is-the-fail-closed-secrets-root):
  this phase documents the fail-closed Vault root, root password-encrypted unseal, parent/child injection,
  the PKI trust anchor, and the SecretRef-by-name contract.
- [`pulumi_iac_doctrine.md` §1 — The one rule: Pulumi runs only from inside an existing amoebius cluster](../documents/engineering/pulumi_iac_doctrine.md#1-the-one-rule-pulumi-runs-only-from-inside-an-existing-amoebius-cluster):
  this phase specifies the MinIO+Vault-envelope backend, DNS (route53)/TLS (zerossl), and the EBS
  create-vs-delete credential model.
- [`daemon_topology_doctrine.md` §1 — One binary, three contexts](../documents/engineering/daemon_topology_doctrine.md#1-one-binary-three-contexts):
  this phase documents the CLI / sudo host-daemon / in-cluster-singleton contexts, the elected control-plane
  singleton, and worker roles.
- [`host_cluster_comms_doctrine.md` §1 — The whole surface: two channels, both localhost-only](../documents/engineering/host_cluster_comms_doctrine.md#1-the-whole-surface-two-channels-both-localhost-only):
  this phase specifies the host compute daemon as a Pulsar+MinIO peer over host-only NodePorts (no mTLS) and
  the host binary↔kubeapi distro-mTLS channel.
- [`pulsar_client_doctrine.md` §1 — One client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets):
  this phase documents the native-protocol `amoebius-pulsar` client, the declarative topology algebra, and
  at-least-once + broker-side dedup.
- [`content_addressing_doctrine.md` §1 — The one idea: a name you cannot lie about](../documents/engineering/content_addressing_doctrine.md#1-the-one-idea-a-name-you-cannot-lie-about):
  this phase specifies the three-tier content-addressed store, `experimentHash`, and seed-derivation
  determinism for both infernix and jitML.
- [`chaos_failover_doctrine.md` §12 — The moral core — proven, tested, assumed](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed):
  this phase writes the Extract→Model→Inject methodology and the proven/tested/assumed ledger, including the
  honesty rule the documentation standard inherits.
- [`testing_doctrine.md` §1 — The one idea: a test is an amoebius spec](../documents/engineering/testing_doctrine.md#1-the-one-idea-a-test-is-an-amoebius-spec):
  this phase documents test-as-`.dhall` (spin up → run → always tear down), `suggest-test`, flagged
  credentials, and the per-run ledger artifact.
- [`tla_modelling_assumptions.md` §0 — Scheduled stub — read this first](../documents/engineering/tla_modelling_assumptions.md#0-scheduled-stub--read-this-first):
  this phase writes the honest scheduled-stub framing (the formal-model assumptions doc is filled in at
  Phase 9; Phase 0 only records its SSoT scope and the stub marker).

## Sprints

## Sprint 0.1: Documentation standards + plan-suite spine 📋

**Status**: Planned
**Implementation**: `documents/documentation_standards.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`,
`DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/overview.md`,
`DEVELOPMENT_PLAN/system_components.md`, `DEVELOPMENT_PLAN/substrates.md` (target documentation files; not
yet complete)
**Blocked by**: none
**Independent Validation**: lint the six spine files in isolation — each carries a valid header block, the
status vocabulary and per-phase/per-sprint skeletons are defined, and every intra-plan link resolves.
**Docs to update**: `documents/documentation_standards.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`,
`DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/overview.md`, `DEVELOPMENT_PLAN/system_components.md`,
`DEVELOPMENT_PLAN/substrates.md`

### Objective

Adopt [`documentation_standards.md` §3 — Required header metadata](../documents/documentation_standards.md#3-required-header-metadata)
(with SSoT-first philosophy §1 and bidirectional cross-referencing §4): establish the header/link mechanics
and the plan-suite structure that every other document and phase obeys. The naming and header conventions
adapt the sibling prodbox project's proven documentation discipline — cited as evidence, then specialized for
amoebius's snake_case rule.

### Deliverables

- The documentation standard (header block, naming, SSoT/no-duplication, bidirectional links, honesty,
  diagram rules).
- The plan rulebook (`development_plan_standards.md`): the §A–§L disciplines (header, snake_case layout,
  status vocabulary, per-phase skeleton, one-phase model, sprint block format, doctrine-citation rule,
  generated markers, cross-ref path rules, honesty, one-substrate).
- The live tracker (`README.md`): Document Index, Phase Overview table, status vocabulary, phase discipline.
- `overview.md` (target architecture/vision), `system_components.md` (surface → owning doctrine → planned
  module path), and `substrates.md` (substrate registry + per-phase map; sole home of generated tables).

### Validation

1. Run the documentation lint (Sprint 0.6 tool) over the six spine files: all headers valid, no orphan
   links, no duplicated normative content.
2. Confirm every doctrine doc and every phase doc can cite the standard's section anchors by name (the
   doctrine-citation rule resolves).

### Remaining Work

The whole sprint.

## Sprint 0.2: The DSL core doctrine 📋

**Status**: Planned
**Implementation**: `documents/engineering/dsl_doctrine.md`,
`documents/engineering/app_vs_deployment_doctrine.md`,
`documents/engineering/illegal_state_catalog.md`,
`documents/engineering/service_capability_doctrine.md` (target documentation files; not yet complete)
**Blocked by**: Sprint 0.1
**Independent Validation**: lint the four DSL-core docs together — the illegal-state catalog links to the DSL
contract rather than restating it, and the capability doctrine and app/deployment split are each owned by
exactly one doc.
**Docs to update**: `documents/engineering/dsl_doctrine.md`,
`documents/engineering/app_vs_deployment_doctrine.md`, `documents/engineering/illegal_state_catalog.md`,
`documents/engineering/service_capability_doctrine.md`, `documents/engineering/README.md`

### Objective

Adopt [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract),
[`app_vs_deployment_doctrine.md` §1 — Two surfaces, one app written once](../documents/engineering/app_vs_deployment_doctrine.md#1-two-surfaces-one-app-written-once),
[`illegal_state_catalog.md` §1 — The promise: illegal states fail to type-check](../documents/engineering/illegal_state_catalog.md#1-the-promise-illegal-states-fail-to-type-check),
and [`service_capability_doctrine.md` §1 — Why capabilities, not products](../documents/engineering/service_capability_doctrine.md#1-why-capabilities-not-products):
write the core of the DSL — the orchestration surface, the two-gate type contract, the app-logic/deployment
split, the illegal-state catalog with honest foreclosure layers, and the capability abstraction.

### Deliverables

- `dsl_doctrine.md`: orchestration surface (parameters/context/witness), total composability, secrets-by-name,
  the Dhall-typechecker + Haskell-decoder gates.
- `app_vs_deployment_doctrine.md`: the application-logic vs deployment-rules split and its litmus test.
- `illegal_state_catalog.md`: the catalog of illegal states, the typing techniques, the coverage matrix, and
  the three layers of foreclosure.
- `service_capability_doctrine.md`: the capability set, one-canonical-provider rule, capability→provider→shape
  binding, and the link to the illegal-state contract.

### Validation

1. Lint resolves every cross-link among the four docs and to the spine.
2. The catalog's foreclosure layers are stated honestly (proven-by-typecheck vs enforced-at-runtime), with no
   "it compiles ⇒ the cluster enforces it" overclaim.

### Remaining Work

The whole sprint.

## Sprint 0.3: Platform & cluster doctrine 📋

**Status**: Planned
**Implementation**: `documents/engineering/platform_services_doctrine.md`,
`documents/engineering/storage_lifecycle_doctrine.md`,
`documents/engineering/cluster_lifecycle_doctrine.md`,
`documents/engineering/readiness_ordering_doctrine.md`,
`documents/engineering/substrate_doctrine.md`,
`documents/engineering/image_build_doctrine.md`,
`documents/engineering/manifest_generation_doctrine.md` (target documentation files; not yet complete)
**Blocked by**: Sprint 0.1
**Independent Validation**: lint the seven platform/cluster docs together — manifest generation owns the
render/reconcile model, platform-services owns the standard-service inventory, and no doc restates another's
normative content.
**Docs to update**: `documents/engineering/platform_services_doctrine.md`,
`documents/engineering/storage_lifecycle_doctrine.md`,
`documents/engineering/cluster_lifecycle_doctrine.md`, `documents/engineering/readiness_ordering_doctrine.md`,
`documents/engineering/substrate_doctrine.md`,
`documents/engineering/image_build_doctrine.md`,
`documents/engineering/manifest_generation_doctrine.md`, `documents/engineering/README.md`

### Objective

Adopt [`platform_services_doctrine.md` §1 — The Invariant: every cluster is the same cluster](../documents/engineering/platform_services_doctrine.md#1-the-invariant-every-cluster-is-the-same-cluster),
[`manifest_generation_doctrine.md` §1 — Why this doctrine exists: types render manifests, Helm does not](../documents/engineering/manifest_generation_doctrine.md#1-why-this-doctrine-exists-types-render-manifests-helm-does-not),
[`storage_lifecycle_doctrine.md` §1 — The one idea: clusters are cattle, storage is land](../documents/engineering/storage_lifecycle_doctrine.md#1-the-one-idea-clusters-are-cattle-storage-is-land),
[`cluster_lifecycle_doctrine.md` §1 — Two cluster kinds, one lifecycle shape](../documents/engineering/cluster_lifecycle_doctrine.md#1-two-cluster-kinds-one-lifecycle-shape),
[`substrate_doctrine.md` §1 — The substrate is a fact about the host, not a knob](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob),
and [`image_build_doctrine.md` §2 — The single distribution rule](../documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster):
write the platform/cluster layer — standard services, no-Helm typed manifest generation + reconciler,
retained storage, cluster lifecycle, substrate detection + no-env/no-`PATH`, and baked-binary image build.

### Deliverables

- `platform_services_doctrine.md`: the standard-service inventory, HA-always, the single wild-ingress path.
- `manifest_generation_doctrine.md`: pure typed render, the apply/reconcile engine, the desired/observed
  state model.
- `storage_lifecycle_doctrine.md`: one no-provisioner storage class, deterministic PV naming + rebind, the
  deletion-forbidden rule.
- `cluster_lifecycle_doctrine.md`: bootstrap, amoebic spawning, teardown-vs-failover, push-back semantics.
- `substrate_doctrine.md`: detection, virtualized substrates, the no-env/no-`PATH` tool-ensure contract.
- `image_build_doctrine.md`: baked multi-arch binaries + the `distribution` registry.

### Validation

1. Lint resolves all intra-group and spine links; the no-Helm and no-public-pull rules are stated once and
   referenced elsewhere.
2. The substrate doc's no-env/no-`PATH` invariant matches the cross-cutting invariant recorded in
   `README.md`.

### Remaining Work

The whole sprint.

## Sprint 0.4: Secrets/IaC + runtime/transport/determinism doctrine 📋

**Status**: Planned
**Implementation**: `documents/engineering/vault_pki_doctrine.md`,
`documents/engineering/pulumi_iac_doctrine.md`,
`documents/engineering/daemon_topology_doctrine.md`,
`documents/engineering/host_cluster_comms_doctrine.md`,
`documents/engineering/pulsar_client_doctrine.md`,
`documents/engineering/content_addressing_doctrine.md` (target documentation files; not yet complete)
**Blocked by**: Sprint 0.1, Sprint 0.2
**Independent Validation**: lint the six docs together — Vault owns secrets-root semantics, daemon-topology
owns the singleton/worker model, and the host-comms doc references (not restates) the capability and Pulsar
surfaces from earlier sprints.
**Docs to update**: `documents/engineering/vault_pki_doctrine.md`,
`documents/engineering/pulumi_iac_doctrine.md`, `documents/engineering/daemon_topology_doctrine.md`,
`documents/engineering/host_cluster_comms_doctrine.md`, `documents/engineering/pulsar_client_doctrine.md`,
`documents/engineering/content_addressing_doctrine.md`, `documents/engineering/README.md`

### Objective

Adopt [`vault_pki_doctrine.md` §2 — Vault is the fail-closed secrets root](../documents/engineering/vault_pki_doctrine.md#2-vault-is-the-fail-closed-secrets-root),
[`pulumi_iac_doctrine.md` §1 — The one rule: Pulumi runs only from inside an existing amoebius cluster](../documents/engineering/pulumi_iac_doctrine.md#1-the-one-rule-pulumi-runs-only-from-inside-an-existing-amoebius-cluster),
[`daemon_topology_doctrine.md` §1 — One binary, three contexts](../documents/engineering/daemon_topology_doctrine.md#1-one-binary-three-contexts),
[`host_cluster_comms_doctrine.md` §1 — The whole surface: two channels, both localhost-only](../documents/engineering/host_cluster_comms_doctrine.md#1-the-whole-surface-two-channels-both-localhost-only),
[`pulsar_client_doctrine.md` §1 — One client, one wire, no WebSockets](../documents/engineering/pulsar_client_doctrine.md#1-one-client-one-wire-no-websockets),
and [`content_addressing_doctrine.md` §1 — The one idea: a name you cannot lie about](../documents/engineering/content_addressing_doctrine.md#1-the-one-idea-a-name-you-cannot-lie-about):
write the secrets/IaC and runtime/transport/determinism layers — Vault/PKI, Pulumi-from-inside, the
daemon-topology grid, host↔cluster comms, the native Pulsar client, and content-addressed determinism.

### Deliverables

- `vault_pki_doctrine.md`: fail-closed Vault root, root password-encrypted unseal, parent/child injection,
  PKI trust anchor, SecretRef-by-name.
- `pulumi_iac_doctrine.md`: in-cluster-only Pulumi, MinIO+Vault-envelope backend, route53/zerossl, EBS
  credential model.
- `daemon_topology_doctrine.md`: the three contexts, the elected singleton, worker roles, leadership election
  (proof delegated to the chaos/failover doctrine).
- `host_cluster_comms_doctrine.md`: the two localhost-only channels and why no-mTLS is safe there.
- `pulsar_client_doctrine.md`: native binary protocol, topology algebra, at-least-once + dedup.
- `content_addressing_doctrine.md`: three-tier store, `experimentHash`, seed-derivation determinism.

### Validation

1. Lint resolves every cross-link, including the back-references from host-comms to the capability/Pulsar
   docs authored in Sprints 0.2–0.4.
2. The leadership-election doc states honestly that its safety proof lives in the chaos/failover doctrine, not
   here (no duplicated proof).

### Remaining Work

The whole sprint.

## Sprint 0.5: Verification doctrine + the honesty ledger 📋

**Status**: Planned
**Implementation**: `documents/engineering/chaos_failover_doctrine.md`,
`documents/engineering/testing_doctrine.md`,
`documents/engineering/tla_modelling_assumptions.md` (target documentation files; not yet complete)
**Blocked by**: Sprint 0.1
**Independent Validation**: lint the three verification docs together — the chaos/failover doctrine owns the
proven/tested/assumed rule, the testing doctrine owns test-as-`.dhall`, and the TLA+ doc is an honest
scheduled stub that names its Phase 9 fill-in.
**Docs to update**: `documents/engineering/chaos_failover_doctrine.md`,
`documents/engineering/testing_doctrine.md`, `documents/engineering/tla_modelling_assumptions.md`,
`documents/engineering/README.md`

### Objective

Adopt [`chaos_failover_doctrine.md` §12 — The moral core — proven, tested, assumed](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed),
[`testing_doctrine.md` §1 — The one idea: a test is an amoebius spec](../documents/engineering/testing_doctrine.md#1-the-one-idea-a-test-is-an-amoebius-spec),
and [`tla_modelling_assumptions.md` §0 — Scheduled stub — read this first](../documents/engineering/tla_modelling_assumptions.md#0-scheduled-stub--read-this-first):
write the verification layer — the Extract→Model→Inject methodology, the proven/tested/assumed ledger that
the whole plan's honesty rule descends from, the test-topology contract, and the honest scheduled-stub for
the Phase 9 formal model.

### Deliverables

- `chaos_failover_doctrine.md`: the defect class, the three correctness layers, the Extract→Model→Inject
  moves, the moral core (proven/tested/assumed), the Second Axis (async cross-cluster failover), and the
  worked examples.
- `testing_doctrine.md`: test-as-`.dhall` (spin up → run → always tear down), `suggest-test`, flagged
  credentials, the elevated-harness-only deletion rule, the per-run ledger artifact.
- `tla_modelling_assumptions.md`: the scheduled-stub marker, SSoT scope, and the single proof obligation the
  Phase 9 model discharges.

### Validation

1. Lint resolves all links; the proven/tested/assumed rule is owned by one doc and referenced (not restated)
   by the documentation standard and this plan.
2. The TLA+ doc is unambiguously marked a scheduled stub — no green claim for unwritten proof content.

### Remaining Work

The whole sprint.

## Sprint 0.6: The documentation-lint gate 📋

**Status**: Planned
**Implementation**: `tools/doc_lint.sh` (target standalone lint script; not yet built — it must not depend on
the amoebius binary, which first appears in Phase 1)
**Blocked by**: Sprint 0.1, Sprint 0.2, Sprint 0.3, Sprint 0.4, Sprint 0.5
**Independent Validation**: run the lint over the whole `documents/` + `DEVELOPMENT_PLAN/` tree; a seeded bad
header, a duplicated normative paragraph, and a dangling anchor each make it exit non-zero.
**Docs to update**: `DEVELOPMENT_PLAN/README.md` (record the gate command), `documents/engineering/README.md`

### Objective

Adopt the documentation standard's cross-referencing and SSoT rules
([`documentation_standards.md` §3 — Required header metadata](../documents/documentation_standards.md#3-required-header-metadata),
with SSoT-first §1 and bidirectional links §4): build the standalone checker that *is* the Phase 0 gate. It
validates header metadata, the SSoT/no-duplication discipline, and the link graph (no orphan cross-links;
`Referenced by` headers reconciled bidirectionally) across every doc the prior sprints authored.

### Deliverables

- `tools/doc_lint.sh`: a pure text/link checker (no amoebius-binary dependency) that fails on an invalid
  header block, an unresolved relative-link anchor, a one-way `Referenced by`, or duplicated normative
  content flagged for SSoT review.
- A recorded gate command in the tracker so every later phase can re-run the same lint.

### Validation

1. The lint passes clean over the full suite once Sprints 0.1–0.5 are complete — the Phase 0 gate.
2. Negative tests: a deliberately broken header, a dangling anchor, and an unbalanced bidirectional link each
   cause a non-zero exit with an actionable message.

### Remaining Work

The whole sprint.

## Documentation Requirements

**Engineering docs to update:**
- `documents/documentation_standards.md` — authored/finalized as the header/link/SSoT mechanics the gate
  enforces.
- `documents/engineering/README.md` — the doctrine index flips each doc's authoring marker to ✅ as Sprints
  0.2–0.5 land, and links back to this phase.
- `documents/engineering/dsl_doctrine.md`, `app_vs_deployment_doctrine.md`, `illegal_state_catalog.md`,
  `service_capability_doctrine.md` — authored in Sprint 0.2.
- `documents/engineering/platform_services_doctrine.md`, `storage_lifecycle_doctrine.md`,
  `cluster_lifecycle_doctrine.md`, `readiness_ordering_doctrine.md`, `substrate_doctrine.md`,
  `image_build_doctrine.md`, `manifest_generation_doctrine.md` — authored in Sprint 0.3.
- `documents/engineering/vault_pki_doctrine.md`, `pulumi_iac_doctrine.md`, `daemon_topology_doctrine.md`,
  `host_cluster_comms_doctrine.md`, `pulsar_client_doctrine.md`, `content_addressing_doctrine.md` — authored
  in Sprint 0.4.
- `documents/engineering/chaos_failover_doctrine.md`, `testing_doctrine.md`,
  `tla_modelling_assumptions.md` — authored in Sprint 0.5.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` Phase Overview links its Phase 0 row to this document.
- `development_plan_standards.md` lists this document among the phase docs it governs (already in its
  `Referenced by`).
- Each authored doctrine doc's `Referenced by` is reconciled to include the phase docs that cite it by name.

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 0 paragraph is the source for this phase's objective
  and gate.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys.
- [overview.md](overview.md) — target architecture/vision (authored in Sprint 0.1).
- [system_components.md](system_components.md) — surface → owning doctrine → planned module path (authored in
  Sprint 0.1).
- [substrates.md](substrates.md) — the substrate registry and per-phase map (authored in Sprint 0.1).
- [Documentation Standards](../documents/documentation_standards.md) — the header/link/SSoT mechanics the
  gate enforces.
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite this phase authors.
