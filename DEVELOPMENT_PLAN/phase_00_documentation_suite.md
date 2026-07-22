# Phase 0: Documentation suite (whole DSL)

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Author the complete amoebius DSL specification and every engineering doctrine before any
> implementation phase begins, gated by a single documentation lint over the whole text and link graph.

---

## Phase Status

🔄 Active. The whole DSL is specified — comprehensively and explicitly — across `documents/` and
`DEVELOPMENT_PLAN/` before a line of the binary is written; every sprint below is Planned, and every
prescriptive statement in the authored doctrine is design intent, never a tested amoebius result. The
substrate is `none`: the phase authors prose, stands up no cluster, and runs no workflow.

## Phase Summary

This phase owns the **entire documentation suite** — the DSL specification and every doctrine in the
[engineering doctrine index](../documents/engineering/README.md), plus the plan suite that sequences the
implementation phases. It is the one phase whose deliverable *is* prose: the orchestration Dhall DSL and its
illegal-state-unrepresentable contract; service capabilities and the capability→provider→shape binder; typed
manifest generation and the SSA reconciler; the standard platform services; storage lifecycle; substrate,
cluster-topology, and resource-capacity models; Vault/PKI and Pulumi-from-inside; the daemon-topology grid;
host↔cluster comms; the native Pulsar client; content-addressing and determinism; tenancy; the verification
layer; and the cross-cutting method doctrines. It also authors the plan spine — the rulebook, the live
tracker, and the target architecture/inventory/substrate documents — so every later phase cites doctrine by
name when it schedules adoption work.

The suite is written to the reversed intent that governs the whole plan. The control-plane singleton is a
Kubernetes Deployment with `replicas=1` whose single-writer authority is **delegated to k8s/etcd through the
mandatory reconciler `Lease`** — there is no bespoke election and no standby pod, and its durable state is the
Vault-enveloped MinIO bucket, not a PVC. ML engines, models, and kernels are **named catalog identities**
jit-resolved on first miss into a `CacheBudget`-bounded content-addressed cache — never baked, never
URL-fetched. amoebius's one formal proof obligation is the **cross-cluster gateway migration**, both the
`Planned` and `Failover` branches, modelled once as data. Generated artifacts (k8s manifests, the emitted
`.tla`/`.cfg`, the reflected Dhall schema, the PureScript contracts) are emitted from a Haskell source of truth
and never committed. Validation runs in three named registers; rendering a plan or `--dry-run` never requires
live infrastructure. The suite's naming and header mechanics adapt conventions proven in the sibling
**prodbox** project — that is sibling evidence, not an amoebius result.

This phase runs in **no validation register (Register —)**: no code executes and no register-1/2/3 harness is
exercised; the gate is a pure text-and-link lint. The cross-cutting invariants the whole plan upholds are
first written down here and then adopted, phase by phase, by the pre-cluster and live bands that follow.

**Substrate:** none (§L) — the gate is a pure documentation lint over text and the link graph; it touches no
`apple`, `linux-cpu`, `linux-cuda`, or `windows` host and stands up no resources.

**Register:** — (no register: the documentation-lint gate validates text and the link graph, not amoebius behaviour, §K).

**Gate:** the documentation lint passes **two-sided** — it runs clean over every document in `documents/` and
`DEVELOPMENT_PLAN/` (valid header metadata per the documentation standard; every anchored relative link resolves
under the §4 slug rule; every `Referenced by` header reconciled from the true link graph in both directions;
**near-duplicate normative content** — measured by sentence-shingle overlap above a stated threshold between two
governed docs, outside quoted/exempt blocks — absent, with semantic SSoT *ownership* documented as a hand review
rather than a lint verdict; each README Phase-Overview status marker equal to its phase doc's `## Phase Status`
marker; every phase **Gate** naming its committed fixtures, at least one committed mutant, and an
independent oracle per [`development_plan_standards.md §M`](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub);
and **illegal-state catalog integrity** — every entry carrying a `**Validation-locus:**`, entry numbering
contiguous with no gaps or duplicates, every index bullet's anchor resolving, and every entry carrying a
technique-matrix row)
**and** it exits non-zero on every fixture in a committed seeded-negative corpus. A lint that only passes on the
suite is not a gate; the committed corpus is what proves the lint can fail. **The corpus is this gate's
independent oracle (§M.3):** the `tools/doc_lint_corpus/` fixtures are hand-authored — one seeded negative per
check and sub-check, committed in [`Sprint 0.5`](#sprint-05-verification-formal-model-doctrine--the-documentation-lint-gate-)
*before* `tools/doc_lint.sh` exists, so the party writing the lint is not the sole author of
what "clean" means; a lint that cannot turn its own committed negatives red is not admitted, exactly as it
requires of every other phase's gate.

## Doctrine adopted

This phase *authors* every document in the suite; the citations below point at the flagship section each doc
owns and state what Phase 0 commits to writing. Each is cited by relative link and by the section's human
name.

- [`documentation_standards.md §3`](../documents/documentation_standards.md#3-required-header-metadata) — the
  *Required header metadata* block, with the SSoT-first philosophy and the bidirectional cross-referencing rule:
  the three mechanics the gate's lint checks.
- [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) —
  *The illegal-state-unrepresentable contract*: the two typed gates (the Dhall typechecker and the Haskell typed
  decoder) that make illegal cluster state fail to type-check.
- [`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) —
  *The registers*: the three named validation registers (Register 1 pure/golden, Register 2 boundary-with-fakes,
  Register 3 live) — and
  [`§3`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure),
  *rendering never touches live infrastructure*.
- [`formal_model_doctrine.md §3`](../documents/engineering/formal_model_doctrine.md#3-two-total-renderings) —
  *Two total renderings*, and
  [`§4`](../documents/engineering/formal_model_doctrine.md#4-correspondence-by-construction),
  *Correspondence by construction*: one reifiable Haskell `Model` renders both the runtime `interpret` function
  and the generated, never-committed `.tla` via `emitTLA`.
- [`gateway_migration_model_doctrine.md §1`](../documents/engineering/gateway_migration_model_doctrine.md#1-the-one-obligation) —
  *The one obligation*: the cross-cluster gateway migration, both `Planned` and `Failover` branches, is
  amoebius's single simulation/proof obligation — reduced to every `InForceSpec` by a decode-time structural-fit
  fold, never a per-spec model-check. There is no First-Axis / singleton-election obligation.
- [`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule) —
  *The rule*: rendered artifacts are emitted from a Haskell source of truth and never committed; only the source
  is versioned.
- [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton) —
  *The control-plane singleton*: a Deployment `replicas=1`, stateless (no PVC), single-instance delegated to
  k8s/etcd through the mandatory reconciler Lease (§3.1, no bespoke election), durable state the
  Vault-enveloped MinIO bucket; §3.3 separately owns the same-binary capacity-scheduler role with no singleton
  or secret authority.
- [`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) —
  *The ML-asset lifecycle*: each engine/model/kernel is a named catalog identity the shared `jit-build` resolver
  materializes on first miss into a `CacheBudget`-bounded content-addressed cache — never baked, never
  URL-fetched.
- [`lift_and_compose_doctrine.md §1`](../documents/engineering/lift_and_compose_doctrine.md#1-why-this-doctrine-exists) —
  *Why this doctrine exists*: amoebius lifts and re-homes the proven primitives of prodbox/hostbootstrap/
  infernix/jitML rather than reimplementing them, and each ML library ships a PureScript demo SPA.
- [`tenancy_doctrine.md §1`](../documents/engineering/tenancy_doctrine.md#1-why-this-doctrine-exists) —
  *Why this doctrine exists*: the first-class `TenantId` orthogonal to the cluster axis, so a valid `InForceSpec`
  cannot name a foreign tenant's resource.
- [`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed) —
  *The moral core — proven, tested, assumed*: the honesty ledger the documentation standard and this whole plan
  inherit.
- [`testing_doctrine.md §1`](../documents/engineering/testing_doctrine.md#1-a-test-is-an-amoebius-spec) —
  *A test is an amoebius spec*: test-as-`InForceSpec` (spin up → run → always tear down), `suggest-test`, and the
  per-run ledger artifact — and
  [`§9`](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation),
  *Derivation: generated enumeration, authored expectation*: the enumeration/expectation split and the coverage
  obligation whose catalog-side half this phase's lint check (g) enforces.
- [`illegal_state_catalog.md`](../documents/illegal_state/illegal_state_catalog.md) — the *illegal-state catalog*
  index and its themed sub-catalogs: the numbered entry set, each carrying a `**Validation-locus:**`, that
  check (g) validates as a well-formed enumeration before any fixture exists to join against.
- [`tla_modelling_assumptions.md`](../documents/engineering/tla_modelling_assumptions.md#why-this-doc-is-deprecated) —
  authored as a **deprecated redirect stub**: its content is re-homed to `formal_model_doctrine.md` and
  `gateway_migration_model_doctrine.md`, and its header carries `Status: Deprecated` so the lint accepts the
  redirect rather than flagging an orphan.

## Sprints

> Note: the per-sprint **Independent Validation** blocks below describe what the Sprint 0.5 documentation lint
> checks over each sprint's docs; they are realized once that lint lands. There is no in-sequence, tool-present
> validation at each sprint's own point in the order — the phase gate is a single end-of-phase two-sided run,
> so "validated in isolation" names the per-doc-group scope of the check, not the moment it can first execute.

## Sprint 0.1: Documentation standards + plan-suite spine 📋

**Status**: Planned
**Implementation**: `documents/documentation_standards.md`, `DEVELOPMENT_PLAN/development_plan_standards.md`,
`DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/overview.md`, `DEVELOPMENT_PLAN/system_components.md`,
`DEVELOPMENT_PLAN/substrates.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`,
`DEVELOPMENT_PLAN/later_phases.md`, and the `phase_00`…`phase_43` phase docs (target documentation files; not
yet complete)
**Blocked by**: none
**Independent Validation**: lint the spine files in isolation — each carries a valid header block, the status
vocabulary and per-phase/per-sprint skeletons are defined, the 44-phase overview table is internally
consistent, and every intra-plan link resolves.
**Docs to update**: the spine files above and `documents/engineering/README.md`

### Objective

Adopt [`documentation_standards.md §3`](../documents/documentation_standards.md#3-required-header-metadata) —
*Required header metadata* — with the SSoT-first philosophy and bidirectional cross-referencing: establish the
header/link mechanics and the plan-suite structure every other document and phase obeys. The naming and header
conventions adapt the sibling prodbox project's documentation discipline (sibling evidence, then specialized for
amoebius's snake_case rule), and the tracker is rebuilt for the 38 single-gate phases.

### Deliverables

- The documentation standard (header block, naming, SSoT/no-duplication, bidirectional links, honesty, tone,
  diagram rules).
- The plan rulebook (`development_plan_standards.md`): the §A–§M disciplines (header, snake_case layout, status
  vocabulary, per-phase skeleton, one-phase model, sprint block format, Documentation Requirements,
  doctrine-citation rule, generated markers, cross-ref path rules, honesty, one-substrate, gate integrity).
- The live tracker (`README.md`): the Document Index, the 44-phase Overview table with its one-line gates and
  substrate/register columns, the status vocabulary, the phase discipline, and the cross-cutting invariants.
- `overview.md`, `system_components.md`, `substrates.md`, `legacy_tracking_for_deletion.md`, `later_phases.md`,
  and the per-phase docs' spine.

### Validation

1. Run the documentation lint (Sprint 0.5 tool) over the spine files: all headers valid, no orphan links, no
   duplicated normative content.
2. Every doctrine doc and every phase doc can cite the standard's section anchors by name (the doctrine-citation
   rule resolves).

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 0.2: DSL core + cross-cutting method doctrine 📋

**Status**: Planned
**Implementation**: `documents/engineering/dsl_doctrine.md`, `app_vs_deployment_doctrine.md`,
`illegal_state_catalog.md` (the pure index) and its eight themed sub-catalogs (`illegal_state_storage.md`,
`illegal_state_topology.md`, `illegal_state_capacity.md`, `illegal_state_security.md`,
`illegal_state_capability_messaging.md`, `illegal_state_ml_asset.md`, `illegal_state_multicluster.md`,
`illegal_state_lifecycle.md`) and the `illegal_state_techniques.md` coverage matrix, `service_capability_doctrine.md`,
`tenancy_doctrine.md`, `lift_and_compose_doctrine.md`, `generated_artifacts_doctrine.md`,
`conformance_harness_doctrine.md` (target documentation files; not yet complete)
**Blocked by**: Sprint 0.1
**Independent Validation**: lint the DSL-core and method docs together — the illegal-state catalog links to the
DSL contract rather than restating it; the three-register model and the generated-never-committed rule are each
owned by exactly one doc and referenced elsewhere.
**Docs to update**: the docs above and `documents/engineering/README.md`

### Objective

Adopt [`dsl_doctrine.md §5`](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) —
*The illegal-state-unrepresentable contract*,
[`conformance_harness_doctrine.md §2`](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) —
*The registers*,
[`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule) —
*The rule*,
[`lift_and_compose_doctrine.md §1`](../documents/engineering/lift_and_compose_doctrine.md#1-why-this-doctrine-exists),
and [`tenancy_doctrine.md §1`](../documents/engineering/tenancy_doctrine.md#1-why-this-doctrine-exists): write the
DSL core (the orchestration surface, the two typed gates, the app-logic/deployment split, the illegal-state
catalog with honest foreclosure layers, the capability binder, the tenant axis) and the cross-cutting method
doctrines (the three validation registers, the generated-never-committed rule, and lift-and-compose).

### Deliverables

- `dsl_doctrine.md`, `app_vs_deployment_doctrine.md`, `illegal_state_catalog.md` (the pure index) with its
  eight themed sub-catalogs (`illegal_state_storage.md`, `illegal_state_topology.md`,
  `illegal_state_capacity.md`, `illegal_state_security.md`, `illegal_state_capability_messaging.md`,
  `illegal_state_ml_asset.md`, `illegal_state_multicluster.md`, `illegal_state_lifecycle.md`) and the
  `illegal_state_techniques.md` coverage matrix that check (g) validates,
  `service_capability_doctrine.md`, `tenancy_doctrine.md`.
- `conformance_harness_doctrine.md`: the three registers and the rendering-never-touches-live invariant.
- `generated_artifacts_doctrine.md`: the emit-from-source, never-commit rule for manifests, the `.tla`/`.cfg`,
  the reflected Dhall schema, and the PureScript contracts.
- `lift_and_compose_doctrine.md`: the reuse map and the PureScript demo SPAs.

### Validation

1. Lint resolves every cross-link among the eight docs and to the spine.
2. The catalog's foreclosure layers are stated honestly (proven-by-typecheck vs enforced-at-runtime), with no
   "it compiles ⇒ the cluster enforces it" overclaim.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 0.3: Platform, cluster, storage, substrate & image doctrine 📋

**Status**: Planned
**Implementation**: `documents/engineering/platform_services_doctrine.md`, `storage_lifecycle_doctrine.md`,
`cluster_lifecycle_doctrine.md`, `gateway_migration_doctrine.md`, `readiness_ordering_doctrine.md`,
`single_logical_data_plane_doctrine.md`, `cluster_topology_doctrine.md`, `resource_capacity_doctrine.md`,
`substrate_doctrine.md`, `apple_metal_headless_builds.md`, `image_build_doctrine.md`,
`manifest_generation_doctrine.md` (target documentation files; not yet complete)
**Blocked by**: Sprint 0.1
**Independent Validation**: lint the platform/cluster docs together — manifest generation owns the
render/reconcile model, platform-services owns the standard-service inventory, resource-capacity owns the
placement fold, and no doc restates another's normative content.
**Docs to update**: the twelve docs above and `documents/engineering/README.md`

### Objective

Adopt [`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
for the rendered manifests, and write the platform/cluster layer: the standard services (HA-always,
Keycloak-owns-all-ingress), no-Helm typed manifest generation plus the SSA reconciler, `no-provisioner` retained
storage, the cluster lifecycle and typed gateway-migration taxonomy, event-driven readiness ordering, the single
logical data plane, the declared compute-engine/substrate topology, the capacity placement fold, substrate
detection with the no-env/no-`PATH` lazy tool-ensure contract, and baked-binary multi-arch image build with the
`distribution` registry.

### Deliverables

- `platform_services_doctrine.md`, `storage_lifecycle_doctrine.md`, `cluster_lifecycle_doctrine.md`,
  `gateway_migration_doctrine.md`, `readiness_ordering_doctrine.md`, `single_logical_data_plane_doctrine.md`.
- `cluster_topology_doctrine.md`, `resource_capacity_doctrine.md`, `substrate_doctrine.md`,
  `apple_metal_headless_builds.md`.
- `image_build_doctrine.md` (service binaries + the `distribution` registry; the ML engine payloads are the
  deliberate not-baked exception) and `manifest_generation_doctrine.md`.

### Validation

1. Lint resolves all intra-group and spine links; the no-Helm and no-public-pull rules are stated once and
   referenced elsewhere.
2. The substrate doc's no-env/no-`PATH` invariant matches the cross-cutting invariant recorded in `README.md`.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 0.4: Secrets/IaC + runtime/transport/determinism doctrine 📋

**Status**: Planned
**Implementation**: `documents/engineering/vault_pki_doctrine.md`, `pulumi_iac_doctrine.md`,
`daemon_topology_doctrine.md`, `host_cluster_comms_doctrine.md`, `bootstrap_sequence_doctrine.md`,
`network_fabric_doctrine.md`, `pulsar_client_doctrine.md`, `content_addressing_doctrine.md`,
`monitoring_doctrine.md`, `release_lifecycle_doctrine.md` (target documentation files; not yet complete)
**Blocked by**: Sprint 0.1, Sprint 0.2
**Independent Validation**: lint the ten docs together — Vault owns secrets-root semantics, daemon-topology owns
the `replicas=1` singleton model, and content-addressing owns the jit-resolved ML-asset cache; host-comms and
bootstrap reference (not restate) the capability and Pulsar surfaces from Sprint 0.2.
**Docs to update**: the ten docs above and `documents/engineering/README.md`

### Objective

Adopt [`daemon_topology_doctrine.md §3`](../documents/engineering/daemon_topology_doctrine.md#3-the-control-plane-singleton) —
*The control-plane singleton* (Deployment `replicas=1`, mandatory Lease, no bespoke election, no PVC) — plus
§3.3's separate same-binary capacity-scheduler role — and
[`content_addressing_doctrine.md §4.5`](../documents/engineering/content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss) —
*The ML-asset lifecycle*: write the secrets/IaC and runtime/transport/determinism layers. The bootstrap doctrine
records that the pre-binary **midwife is a Python `pb` CLI** (two modes: midwife and admin-REST client), not a
shell script; the daemon-topology and content-addressing docs carry the reversed control-plane and
jit-resolved-cache intent.

### Deliverables

- `vault_pki_doctrine.md`, `pulumi_iac_doctrine.md` (in-cluster-only Pulumi, MinIO+Vault-envelope backend).
- `daemon_topology_doctrine.md` (the three contexts; the `replicas=1` singleton under its mandatory Lease, no
  bespoke election; separate capacity-scheduler and worker roles), `host_cluster_comms_doctrine.md`, `bootstrap_sequence_doctrine.md` (the `pb`
  midwife + admin-REST client), `network_fabric_doctrine.md`.
- `pulsar_client_doctrine.md` (native protocol, CBOR-only payloads), `content_addressing_doctrine.md`
  (three-tier store, `experimentHash`, the jit-resolved `CacheBudget`-bounded engine cache),
  `monitoring_doctrine.md`, `release_lifecycle_doctrine.md`.

### Validation

1. Lint resolves every cross-link, including the back-references from host-comms/bootstrap to the
   capability/Pulsar docs authored in Sprint 0.2.
2. The daemon-topology doc states honestly that single-instance safety is a k8s/etcd property, not an amoebius
   election, and carries no standby-pod or ranked-failover language.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 0.5: Verification, formal-model doctrine & the documentation-lint gate 📋

**Status**: Planned
**Implementation**: `documents/engineering/chaos_failover_doctrine.md`, `testing_doctrine.md`,
`test_derivation_analysis.md` (the analysis record behind the derivation boundary),
`formal_model_doctrine.md`, `gateway_migration_model_doctrine.md`, `tla_modelling_assumptions.md` (deprecated
stub), `tools/doc_lint.sh`, `tools/doc_lint_corpus/` (the committed seeded-negative fixtures), and
`tools/ledger_lint` (target standalone scripts; not yet built — they must not depend on the amoebius binary,
which first appears in the pre-cluster implementation band, Phase 2+)
**Blocked by**: Sprint 0.1, Sprint 0.2, Sprint 0.3, Sprint 0.4
**Independent Validation**: run the lint **two-sided** — clean over the whole `documents/` + `DEVELOPMENT_PLAN/`
tree, **and** non-zero on every fixture in the committed `tools/doc_lint_corpus/` (a bad header (a); a
near-duplicate paragraph (d); a dangling anchor and a bare `§N` prose reference (b); a one-way `Referenced by` (c); a drifted status marker
(e); a gate line missing its committed mutant/oracle (f); and — for catalog integrity (g), one per sub-check —
a catalog entry missing its `**Validation-locus:**`, non-contiguous catalog numbering, a catalog index bullet
with a dangling anchor, and a catalog entry with no technique-matrix row; and a doctrine doc missing its
`DEVELOPMENT_PLAN/README.md` back-link (h)). The malformed-ledger negative lives
in `ledger_lint`'s own corpus, not here.
**Docs to update**: the five verification docs above, `DEVELOPMENT_PLAN/README.md` (record the gate command),
`documents/engineering/README.md`

### Objective

Adopt [`chaos_failover_doctrine.md §12`](../documents/engineering/chaos_failover_doctrine.md#12-the-moral-core--proven-tested-assumed) —
*The moral core — proven, tested, assumed*,
[`testing_doctrine.md §1`](../documents/engineering/testing_doctrine.md#1-a-test-is-an-amoebius-spec) —
*A test is an amoebius spec*,
[`formal_model_doctrine.md §4`](../documents/engineering/formal_model_doctrine.md#4-correspondence-by-construction) —
*Correspondence by construction*, and
[`gateway_migration_model_doctrine.md §1`](../documents/engineering/gateway_migration_model_doctrine.md#1-the-one-obligation) —
*The one obligation*: write the verification layer — the proven/tested/assumed ledger, test-as-`InForceSpec`,
the model-as-data pattern, and amoebius's single gateway-migration proof obligation — and build the standalone
checker that *is* the Phase 0 gate.

### Deliverables

- `chaos_failover_doctrine.md` (the Extract→Model→Inject moves, the proven/tested/assumed ledger, the Second
  Axis of async cross-cluster failover) and `testing_doctrine.md`.
- `formal_model_doctrine.md` (one reifiable `Model`, two total renderings, correspondence by construction) and
  `gateway_migration_model_doctrine.md` (the one obligation, both `Planned` and `Failover` branches, reduced by
  a decode-time structural-fit fold).
- `tla_modelling_assumptions.md`: a `Deprecated` redirect stub pointing at the two docs above.
- `tools/doc_lint.sh`: a pure text/link checker (no amoebius-binary dependency), run **two-sided** — it must
  pass clean on the suite **and** fail on every fixture in the committed `tools/doc_lint_corpus/`. It checks,
  mechanically: (a) valid header metadata — decomposed per the documentation standard's five facets: a `Status`
drawn from the enum with vague values banned, a `Supersedes` field, a `Referenced by` field, `Generated
sections` keys that match the real in-body markers, and a one-sentence `Purpose` — each an independently
seeded sub-check; (b) every anchored relative link resolves under the §4 slug rule,
and **no bare `§N` section reference** appears outside a Markdown link label, heading, fenced/Mermaid block,
`§M.N` clause-shorthand, or external-project reference — a section citation must be an anchor link, never bare
`§N` prose (the lint flags any `§`-plus-digit occurring in prose that is not one of those forms);
  (c) every `Referenced by` header reconciled in both directions from the true link graph; (d) **near-duplicate
  normative content** by a named method — sentence-shingle overlap above a stated threshold between two governed
  docs outside quoted/exempt blocks (semantic SSoT *ownership* is a documented hand review, not a lint verdict);
  (e) **status-consistency** — each README Phase-Overview marker equals that phase doc's `## Phase Status`
  marker; (f) **gate-integrity** ([`development_plan_standards.md §M`](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)) —
  every phase Gate names its committed fixtures/goldens, ≥1 committed mutant, and an independent oracle —
  **following one anchor hop** from the `**Gate:**` line into the phase's `## Gate integrity` section where the
  gate delegates to it (§M Gate → Gate-integrity delegation), so a gate whose apparatus lives one hop away is not flagged —
  and a
  ✅ Done row carries a recorded gate command + date + substrate + ledger hash. The gate command is recorded in
  the tracker; and (g) **illegal-state catalog integrity** — every `### 3.N` entry across the eight themed
  sub-catalogs (`illegal_state_storage.md`, `_topology.md`, `_capacity.md`, `_security.md`,
  `_capability_messaging.md`, `_ml_asset.md`, `_multicluster.md`, `_lifecycle.md` — **not**
  [`illegal_state_catalog.md`](../documents/illegal_state/illegal_state_catalog.md), which is the pure index
  and holds no `### 3.N` entries) carries a `**Validation-locus:**` field, entry numbering is contiguous with
  no gaps or duplicates, every [`illegal_state_catalog.md`](../documents/illegal_state/illegal_state_catalog.md)
  index bullet's anchor resolves to a real heading, and every entry carries a row in the
  [`illegal_state_techniques.md`](../documents/illegal_state/illegal_state_techniques.md) coverage matrix; and
  (h) **plan back-link** — every doctrine doc under `documents/engineering/` contains a link back to
  `DEVELOPMENT_PLAN/README.md`, guarding the documentation standard's back-link rule against future rot.
  Check (g) is the **catalog-side** half of the coverage obligation of
  [`testing_doctrine.md §9`](../documents/engineering/testing_doctrine.md#9-derivation-generated-enumeration-authored-expectation) —
  it validates the enumeration the fixture join will later consume. The *fixture* half (an entry with no
  committed witness yields an UNVERIFIED row) is **not** in Phase 0: it requires the
  `Delivery-owner:`/`Case-family:` enrichment and the `locus_registry.tsv` that
  [`phase_06`](phase_06_illegal_state_corpus.md) Sprint 6.1 owns, and no fixture exists to join against
  until then. An explicit `<a id="...">` is a valid anchor target for (b) and (g): the suite uses it to keep
  inbound links alive across a heading rename.
- `tools/doc_lint_corpus/`: the **committed** seeded-negative fixtures — **at least one per check (a)–(f) and (h) —
  with (a) decomposed into one negative per header facet (status-enum-membership, supersedes, referenced-by,
  generated-sections-keys-match-markers, and one-sentence-purpose) — and one per sub-check of (g)**, so every
  check, header facet, and sub-check has a fixture that turns it red — that the lint
  must turn red; this is what makes the lint falsifiable rather than a checker that can always exit 0. Each
  fixture is a **minimal single-defect mutation** of an otherwise-conforming document — differing from a
  passing positive only in the one seeded flaw — and the lint must detect that specific seeded defect (naming
  the failing check), not the fixture's filename or identity, so a stub that keys on fixture identity
  (`if path in known_corpus: exit 1`) cannot pass both sides. The
  malformed-ledger negative is **not** in this corpus; it lives in `ledger_lint`'s own corpus below.
- `tools/ledger_lint`: a schema checker for the proven/tested/assumed ledger
  ([`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact)) —
  the `{phase, gate_command, register, substrate, date, layers, coverage, ledger_hash}` shape, `register`/`substrate`
  equal to the tracker row, every out-of-register correctness layer a mandatory UNVERIFIED `layers` row, and
  every `coverage` row's `surface` resolving against the run's regenerated enumeration (an unresolvable
  `surface` fails the lint) — with its own committed malformed-ledger negatives, including a `coverage` row
  naming a non-existent surface.

### Validation

1. The lint runs **two-sided**: clean over the full suite once Sprints 0.1–0.4 have landed, **and** non-zero
   (with an actionable message) on every fixture in the committed `tools/doc_lint_corpus/` — the Phase 0 gate.
2. The committed negative corpus covers each check — a broken header (a), a dangling anchor and a bare `§N`
   prose reference (b), a one-way
   bidirectional link (c), a near-duplicate normative paragraph (d), a drifted status marker (e), a gate line
   missing its committed mutant/oracle (f), and — for catalog integrity (g) — a catalog entry missing its
   `**Validation-locus:**`, non-contiguous catalog numbering, a catalog index bullet with a dangling anchor,
   and a catalog entry with no technique-matrix row — plus a doctrine doc missing its
   `DEVELOPMENT_PLAN/README.md` back-link (h) — each causing a
   non-zero exit with a message naming the offending file and check; `ledger_lint` likewise fails on its
   malformed-ledger negatives.
3. The formal-model docs unambiguously separate what a green model-check proves (the protocol, in the abstract)
   from the model↔code correspondence and runtime fidelity discharged in the later implementation phases.

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/documentation_standards.md` — authored/finalized as the header/link/SSoT mechanics the gate
  enforces (Sprint 0.1).
- `documents/engineering/README.md` — the doctrine index flips each doc's authoring marker as Sprints 0.2–0.5
  land, records `tla_modelling_assumptions.md` as the deprecated redirect stub, and links back to this phase.
- The DSL-core and cross-cutting method docs — authored in Sprint 0.2.
- The platform/cluster/storage/substrate/image docs — authored in Sprint 0.3.
- The secrets/IaC and runtime/transport/determinism docs — authored in Sprint 0.4.
- `chaos_failover_doctrine.md`, `testing_doctrine.md`, `formal_model_doctrine.md`,
  `gateway_migration_model_doctrine.md`, `tla_modelling_assumptions.md` — authored in Sprint 0.5.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` Phase Overview links its Phase 0 row to this document.
- `development_plan_standards.md` lists this document among the phase docs it governs (already in its
  `Referenced by`).
- Each authored doctrine doc's `Referenced by` is reconciled to include the phase docs that cite it by name.

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 0 row is the source for this phase's objective and gate.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys.
- [overview.md](overview.md) — target architecture/vision (authored in Sprint 0.1).
- [system_components.md](system_components.md) — surface → owning doctrine → planned module path (authored in
  Sprint 0.1).
- [substrates.md](substrates.md) — the substrate registry and per-phase map (authored in Sprint 0.1).
- [Documentation Standards](../documents/documentation_standards.md) — the header/link/SSoT mechanics the gate
  enforces.
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite this phase authors.
- [`conformance_harness_doctrine.md`](../documents/engineering/conformance_harness_doctrine.md) — the three
  validation registers this plan's gates are stated in.
- [`generated_artifacts_doctrine.md`](../documents/engineering/generated_artifacts_doctrine.md) — the
  emit-from-source, never-commit rule.
- [`gateway_migration_model_doctrine.md`](../documents/engineering/gateway_migration_model_doctrine.md) —
  amoebius's one simulation/proof obligation.
