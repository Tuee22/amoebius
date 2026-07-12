# Phase 9: Pure render + rendered-output goldens

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_08_capability_binder.md, DEVELOPMENT_PLAN/phase_10_chain_kernel_dryrun.md, DEVELOPMENT_PLAN/phase_11_boundary_fake_tool_harness.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the pure, total `render :: ServiceSpec -> [K8sObject]` and lock its emitted object
> set byte-for-byte with rendered-output goldens — proving the by-construction manifest-safety invariants on
> the emitted objects in-process, before any cluster exists.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. This phase opens after the Phase 8
capability→provider→shape binder gate passes and runs on **no substrate** (`none`) in **Register 1** — it
stands up no host and no cluster, only an in-process render-and-golden battery. Where a shape below is already
exercised in a sibling system (prodbox renders a slice of its object set from typed Haskell records to Aeson
and pins byte-for-byte dry-run goldens over a pure, no-process suite), that is **sibling evidence, not an
amoebius result**. This phase deliberately builds **only the pure `render` half** of the manifest doctrine;
the server-side-apply reconciler that *runs* `render` on a live cluster — driven by the control-plane
singleton, a Kubernetes Deployment `replicas=1` whose single-instance guarantee is delegated to k8s/etcd with
no bespoke election — is deferred to the live band ([Phase 16](phase_16_renderer_reconciler.md)).

## Phase Summary

This phase delivers the pure manifest renderer: the typed `K8sObject` model, the total function
`render :: ServiceSpec -> [K8sObject]` that emits the complete per-service Kubernetes object set from Haskell
ADTs serialized via Aeson — no Helm, no text template, no `values.yaml` — and the rendered-output golden
battery that locks that output and proves its by-construction safety. `render` performs no I/O, reaches no
apiserver, and is total over the decoded `ServiceSpec` the Phase-8 binder produces, so the emitted object set
is a *value* the suite inspects end to end. The battery does two things: it pins the emitted `[K8sObject]`
**byte-for-byte** against a golden fixture (any change to the renderer's output is a red diff, never a silent
drift), and it asserts the **rendered-output-golden illegal states** directly on the emitted objects — an
unsafe manifest is not a value `render` can return, so a golden test over the output proves the property with
no cluster. What is *not* here: the SSA/ApplySet apply-and-prune reconciler, wait-for-ready, drift-heal, the
release ledger, and any live convergence — all deferred to [Phase 16](phase_16_renderer_reconciler.md); and
the `chain`/`[Step]` `--dry-run` plan render, which is [Phase 10](phase_10_chain_kernel_dryrun.md). This phase
locks the **render** step of the pre-cluster spine.

**Substrate:** `none` — no host, no cluster; the gate is an in-process `cabal test` render-and-golden battery
analogous to the Phase-5 decode battery and the Phase-4 `dhall type` corpus.

**Register:** 1 — pure/golden, in-process, no cluster (§K).

**Gate:** `cabal test render-golden` is green against Phase-0-pinned oracles — the pure, total
`render :: ServiceSpec -> [K8sObject]` emits, **for the concrete corpus** (the full Phase-8 binder output set:
every capability arm × both deployment shapes {`SingleNode`, `Distributed`}, enumerated explicitly in Sprint 9.3's
Deliverables and jointly covering every `K8sObject` sum variant at least once), an object set the
**byte-for-byte** goldens pin exactly, and the three rendered-output-golden illegal-state properties hold
**non-vacuously** on the emitted objects. The goldens are authored and **committed in Phase 0** under
`test/manifest/golden/<service-id>.json` *before* `render` exists, under a single pinned **canonical Aeson
encoding** (object keys lexicographically sorted, two-space indent, trailing LF, exactly one golden file per
service keyed by `ServiceSpec` id — so "drifts by a single byte" is unambiguous), and are **never regenerated
from the renderer's own output** (a golden regenerated from `render` is not a test). The three properties, with
their predicates fixed: **(a)** every emitted pod carries a hardened `securityContext` *and* every container
declares non-zero cpu/ram requests+limits; **(b)** no backdoor/insecure ingress — concretely, no `Service` of
type `NodePort`/`LoadBalancer` outside the single declared edge service, every `HTTPRoute` parented to the
Keycloak-owned `Gateway`, and no bare `Ingress` kind anywhere; **(c)** every NetworkPolicy is default-deny plus
allow edges that **exactly equal** (set equality — no missing edge, no extra edge) the edge set an
**independent, test-side re-derivation from the declared dependency graph** produces, the reference side
authored by hand/spec in Phase 0 and *not* by reusing `render`'s own connectivity fold. Non-vacuity is enforced
by the shape-completeness and non-zero-count assertions and by the three committed seeded mutants named in
Sprint 9.3, each of which must turn the relevant **property** (not merely the byte diff) red. A **Register-1**
in-process check that runs on no substrate and contacts no infrastructure; it still emits the
proven/tested/assumed ledger, marking runtime enforcement UNVERIFIED (owned by the live band).

## Doctrine adopted

- [`namespace_layout_doctrine.md §2`](../documents/engineering/namespace_layout_doctrine.md#2-one-namespace-per-platform-capability--the-derived-set)
  — **one namespace per platform capability, derived never authored.** The render-golden battery asserts every
  emitted object lands in its doctrine-**derived** namespace and that a free-text or cross-capability namespace
  is not a value `render` can emit — the rendered-output enactment that gates the namespace-layout foreclosure.
- [`manifest_generation_doctrine.md §2`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects)
  — **the typed manifest model: `render` is a pure, total function to objects.** Adopt the pure, total,
  cluster-free `render :: ServiceSpec -> [K8sObject]` whose output is a value amoebius inspects before any
  object reaches a cluster; the record *is* the manifest, serialized via Aeson, with no intermediate template
  and no `values.yaml`. **Only the pure-render half is adopted here**; the apply/reconcile engine of that
  doctrine's §5 is the live-band [Phase 16](phase_16_renderer_reconciler.md) residue.
- [`manifest_generation_doctrine.md §3`](../documents/engineering/manifest_generation_doctrine.md#3-best-practice-by-construction-an-unsafe-manifest-is-not-constructible)
  — **best practice by construction: an unsafe manifest is not constructible.** The renderer emits a hardened
  `securityContext` on every pod, least-privilege per-workload RBAC, default-deny-plus-derived-allow
  NetworkPolicies, required non-zero cpu/ram requests+limits, and Secret objects that carry a Vault coordinate
  and never bytes — a manifest lacking any of these is not a value `render` can return.
- [`conformance_harness_doctrine.md §3`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
  — **the load-bearing invariant: rendering never touches live infrastructure**, and its §4 decode → validate
  → render → plan → dry-run spine (this phase locks the **render** step). A render is a pure function of
  committed source that completes in-process with no apiserver, no credentials, no Vault; the byte-for-byte
  golden is a fixture of the renderer, and the rendered-output-golden validation locus catches a large share
  of the illegal-state catalog here, not at runtime.
- [`illegal_state_catalog.md §3.11`](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)
  (the unsafe workload — no resource limits, no hardened `securityContext`),
  [`§3.7`](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)
  (accidental insecure / backdoor ingress), and
  [`§3.6`](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other)
  (blocking / underived NetworkPolicy) — the three states realized here at the **rendered-output-golden**
  locus. Honors [`§6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
  — three layers of foreclosure: these are proven on the *emitted objects* in Register 1; the runtime-checked
  claim that the live cluster enforces them stays deferred to the live band.
- [`platform_services_doctrine.md §9`](../documents/engineering/platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)
  (east-west connectivity derived from the dependency graph; the single wild-ingress path) and
  [`§10`](../documents/engineering/platform_services_doctrine.md#10-every-container-declares-cpu-and-ram)
  (every container declares cpu/ram) — the *owners* of the connectivity and resource rules; this phase adopts
  their **rendering enactment** (the derived NetworkPolicy and the required cpu/ram fields on the emitted
  objects), not the rules themselves.
- [`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
  — generated artifacts are emitted from a Haskell source of truth and **never committed**: the rendered
  `[K8sObject]` set is never a checked-in deployment artifact; the byte-for-byte golden is a *test fixture*
  that pins the renderer, not a committed manifest.
- [`testing_doctrine.md §2`](../documents/engineering/testing_doctrine.md) — **Register 1** (pure/golden,
  in-process, no cluster): the register this phase's gate reaches; and §4 — the per-run
  proven/tested/assumed ledger the battery emits, marking runtime-enforcement correspondence UNVERIFIED
  (owned by the live band).

## Sprints

## Sprint 9.1: The typed `K8sObject` model + Aeson serialization 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/K8sObject.hs` (the typed `K8sObject` sum — Deployment /
StatefulSet / Service / RBAC triple / NetworkPolicy / HTTPRoute / Gateway / ConfigMap / CRD / CR instance /
`ClusterIssuer` / `Certificate` / Secret-reference), `src/Amoebius/Manifest/Types.hs` — target paths, not yet
built.
**Blocked by**: Phase 8 gate (the capability→provider→shape binder that decodes a capability need to the
`ServiceSpec` this model renders from); Phase 5 (the GADT-indexed IR the `ServiceSpec` is a projection of).
**Independent Validation**: the object model compiles under the pinned GHC 9.12.4; a hand-built object
round-trips through Aeson (`toJSON`/`fromJSON`) to an equal value, and its encoding matches a small
byte-for-byte golden — proving the record *is* the manifest with no template layer.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md` (Phase-9 backlink for the typed
object model), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`manifest_generation_doctrine.md §2`](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-render-is-a-pure-total-function-to-objects):
build the typed Haskell `K8sObject` model — every Kubernetes object amoebius emits as a typed record
serialized to JSON via Aeson, exactly the `object [...]` discipline the prodbox sibling already applies to its
supporting objects (*sibling evidence, not an amoebius result*) — so a manifest is a value, not interpolated
text.

### Deliverables
- A typed `K8sObject` sum covering the full per-service object set, each variant a Haskell record with an
  Aeson `ToJSON`/`FromJSON` instance; the record is the manifest — no `values.yaml`, no text template.
- The Secret variant carries a Vault coordinate (a reference), structurally admitting no literal secret
  bytes; the whole `SecretRef` / Vault model stays owned by the vault/PKI doctrine and is not restated.

### Validation
1. The model compiles on the pinned toolchain; a hand-built object round-trips through Aeson to an equal
   value and encodes to a byte-for-byte golden.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 9.2: Pure total `render` + best-practice-by-construction 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Manifest/Render.hs` (`render :: ServiceSpec -> [K8sObject]`, pure and
total) and its per-shape helpers — target paths, not yet built.
**Blocked by**: Sprint 9.1.
**Independent Validation**: totality is established by compiling `render` and its transitive closure under
`-Werror=incomplete-patterns` and `-Werror=incomplete-uni-patterns` (a partiality grep does not establish
reachability or totality and is not sufficient), plus an **import-graph check** that no `IO`,
`unsafePerformIO`, or partial-`Prelude` name (`head`/`fromJust`/`!!`/`error`/`undefined`) appears in `render`'s
transitive module surface. A QuickCheck property asserts the by-construction invariants hold on the emitted
`[K8sObject]` for arbitrary legal `ServiceSpec` values, and its generator is **not** near-constant: it carries
`cover`/`checkCoverage` obligations (coverage failure is a hard test failure) forcing each capability arm, both
deployment shapes {`SingleNode`, `Distributed`}, and every `K8sObject` sum variant to appear at a stated
minimum frequency — so the property demonstrably exercises the whole spec surface, not one happy-path shape.
**Docs to update**: `documents/engineering/manifest_generation_doctrine.md` (backlink §3 to the Phase-9 pure
renderer; keep the SSA reconciler half as the live-band residue), `documents/engineering/platform_services_doctrine.md`
(the rendering enactment of the §9/§10 rules), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`manifest_generation_doctrine.md §3`](../documents/engineering/manifest_generation_doctrine.md#3-best-practice-by-construction-an-unsafe-manifest-is-not-constructible):
implement the pure, total `render` that emits the complete per-service object set — including generated
operator installs (CRDs, controller Deployment, CR instances) as typed objects rather than upstream charts —
with the safe shape as the *only* shape it can return: hardened `securityContext` on every pod,
least-privilege per-workload RBAC, default-deny-plus-graph-derived-allow NetworkPolicies, required non-zero
cpu/ram requests+limits, and Vault-coordinate Secret references.

### Deliverables
- `render :: ServiceSpec -> [K8sObject]`, pure and total (no I/O, no apiserver, no partial head), producing
  best-practice-by-construction objects; the cluster renderer is the fold of every service's `render` over
  the decoded spec, connectivity derived from the declared dependency graph.
- An in-file honesty note: this is the render half only — the SSA/ApplySet apply, prune, wait-for-ready, and
  release ledger are the live-band [Phase 16](phase_16_renderer_reconciler.md) reconciler, run by the
  Deployment-`replicas=1` singleton (single-instance delegated to k8s/etcd, no bespoke election).

### Validation
1. The `-Werror=incomplete-patterns`/`-Werror=incomplete-uni-patterns` compile and the import-graph check
   report no partial call and no `IO`/`unsafePerformIO`/partial-`Prelude` name reachable from `render`; a
   QuickCheck property over arbitrary legal `ServiceSpec` values — with `cover`/`checkCoverage` obligations
   (hard-failing) that force each capability arm, both shapes, and every `K8sObject` variant to fire at its
   stated minimum — confirms every emitted pod is hardened, every NetworkPolicy is default-deny + derived-allow,
   and every container declares cpu/ram.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 9.3: The rendered-output golden battery (`render-golden`) — the gate 📋

**Status**: Planned
**Implementation**: `test/manifest/RenderGoldenSpec.hs`, `test/manifest/golden/<service-id>.json` (the
Phase-0-committed golden fixtures, one per service, under the canonical Aeson encoding), the independent
test-side allow-edge oracle `test/manifest/DepGraphOracle.hs` (a hand-authored re-derivation of allow edges
from the declared dependency graph, not a call into `render`), and the **concrete corpus** — the full Phase-8
binder output set: every capability arm × both deployment shapes {`SingleNode`, `Distributed`}, jointly
covering every `K8sObject` sum variant at least once — target paths, not yet built.
**Blocked by**: Sprint 9.2; Phase 8 gate (the `ServiceSpec` corpus the goldens render from).
**Independent Validation**: `cabal test render-golden` is green — the emitted `[K8sObject]` matches its
Phase-0-committed byte-for-byte golden under the canonical encoding and every rendered-output-golden
illegal-state property holds non-vacuously; the suite goes **red** if the renderer's output drifts by a single
byte or if any emitted object violates a by-construction invariant. The NetworkPolicy property checks allow-edge
**set equality** against the independent `DepGraphOracle` re-derivation (authored in Phase 0, never `render`'s
own fold), so an extra allow edge for an undeclared dependency is caught. The three committed seeded mutants
(below) are re-run each build and each must go red via the *property* assertion it targets, with that mutant's
golden regenerated to match its (illegal) output so the byte diff alone cannot be what fails.
**Docs to update**: `documents/engineering/conformance_harness_doctrine.md` (record the rendered-output-golden
locus realized in Register 1), `documents/illegal_state/illegal_state_catalog.md` (annotate §3.6/§3.7/§3.11
with realized foreclosure layer = rendered-output-golden, Register 1),
`documents/engineering/generated_artifacts_doctrine.md`, `DEVELOPMENT_PLAN/README.md` (flip the Phase-9 status
when the gate passes).

### Objective
Adopt [`conformance_harness_doctrine.md §3`](../documents/engineering/conformance_harness_doctrine.md#3-the-load-bearing-invariant-rendering-never-touches-live-infrastructure)
and its §4 spine's **render** step: assemble the in-process battery that pins `render`'s output byte-for-byte
and proves the three rendered-output-golden illegal states — the unsafe-workload
([`§3.11`](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext)),
backdoor-ingress ([`§3.7`](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)),
and blocking/underived-NetworkPolicy ([`§3.6`](../documents/illegal_state/illegal_state_security.md#36-blocking-networkpolicy-services-cant-reach-each-other))
states — directly on the emitted objects, all without a cluster.

### Deliverables
- `test/manifest/RenderGoldenSpec.hs` pinning the emitted object set byte-for-byte against the
  Phase-0-committed `test/manifest/golden/<service-id>.json` (canonical Aeson encoding) for **the concrete
  corpus** (every capability arm × {`SingleNode`, `Distributed`}), plus, per service, **shape-completeness**
  assertions (each workload capability renders ≥1 `Deployment`/`StatefulSet`, its `ServiceAccount`/`Role`/
  `RoleBinding` triple, ≥1 `NetworkPolicy`, cpu/ram on every container) and **corpus-wide non-zero counts**
  (total pods > 0, total NetworkPolicies > 0) so no property holds vacuously over an empty object set; plus the
  three fixed-predicate safety assertions — every emitted pod carries a hardened `securityContext`; no `Service`
  of type `NodePort`/`LoadBalancer` outside the single declared edge, every `HTTPRoute` parented to the
  Keycloak-owned `Gateway`, no bare `Ingress` kind; and every NetworkPolicy default-deny with allow edges set-
  equal to the independent `DepGraphOracle` re-derivation.
- **Three committed seeded mutants** (operator: invariant-clause delete / union-arm addition / guard weakening),
  each committed and re-run and each of which must turn its *targeted property* (not the byte diff) red — its
  golden regenerated to the mutant's output so only the property can fail: **M1** a pod rendered without the
  hardened `securityContext` (kills property a); **M2** a wild `NodePort` route / a `Keycloak`-skipping
  `HTTPRoute` (kills property b); **M3** an allow edge emitted for a dependency absent from the declared graph
  (kills property c's set-equality against `DepGraphOracle`).
- A Register-1 proven/tested/assumed ledger led by a runtime-UNVERIFIED banner: the emitted objects are
  proven safe *as values* in-process; no claim is made that a live cluster enforces them (deferred to the
  live band). The golden fixtures are test artifacts, never committed deployment manifests.

### Validation
1. `cabal test render-golden` is green — output matches the Phase-0-committed byte-for-byte goldens (canonical
   encoding) across the concrete corpus, shape-completeness and corpus-wide non-zero counts hold (no vacuous
   universal), and every rendered-output invariant holds — the NetworkPolicy check by allow-edge set equality
   against the independent `DepGraphOracle`. Each of the three committed seeded mutants (M1 unhardened pod, M2
   wild/Keycloak-skipping route, M3 undeclared allow edge), with its golden regenerated to its own output, must
   turn the corresponding **property assertion** red — so a mutant is caught by a safety property, not merely by
   the byte diff.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/manifest_generation_doctrine.md` — backlink §2/§3 to the Phase-9 pure renderer and
  rendered-output goldens; keep §5's SSA/ApplySet apply-and-prune reconciler explicitly as the live-band
  [Phase 16](phase_16_renderer_reconciler.md) residue, run by the Deployment-`replicas=1` singleton (no
  election).
- `documents/engineering/conformance_harness_doctrine.md` — record the rendered-output-golden validation
  locus this phase realizes as the **render** step of the pre-cluster spine, in Register 1.
- `documents/illegal_state/illegal_state_catalog.md` — annotate §3.6 / §3.7 / §3.11 with their realized
  foreclosure layer (rendered-output-golden → Register 1); keep the runtime-checked (layer-3) enforcement
  claim deferred to the live band.
- `documents/engineering/generated_artifacts_doctrine.md` — note that the rendered `[K8sObject]` set is
  emitted from Haskell and never committed; the byte-for-byte golden is a test fixture of the renderer.

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-9 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-9 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Manifest/{K8sObject,Types,Render}.hs` and
  the `render-golden` test-suite as Phase-9 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  design-proof acceptance token: *rendered-output proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the pure-render / no-Helm posture
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — §2 the pure
  renderer adopted here; §3 best-practice-by-construction; §5 the SSA reconciler deferred to the live band
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — the render step
  of the pre-cluster spine and the invariant that rendering never touches live infrastructure
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — §3.6/§3.7/§3.11 the three
  rendered-output-golden states; §6 the honest foreclosure-layer split
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — §9 the derived
  NetworkPolicy rule, §10 the cpu/ram rule this phase renders by construction
- [Generated Artifacts Doctrine](../documents/engineering/generated_artifacts_doctrine.md) — why the render
  output is generated and never committed
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — §2 Register 1, §4 the per-run ledger
- [phase_08](phase_08_capability_binder.md) — the capability→provider→shape binder producing the `ServiceSpec`
- [phase_10](phase_10_chain_kernel_dryrun.md) — the `chain`/`[Step]` `--dry-run` plan render deferred from here
- [phase_16](phase_16_renderer_reconciler.md) — the live SSA/ApplySet reconciler that applies `render`'s output
