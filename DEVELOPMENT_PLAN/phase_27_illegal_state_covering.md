# Phase 27: Illegal-state corpus + validation-locus ledger

> **Purpose**: Define the exhaustive illegal-state corpus as Haskell values — every negative split by the locus
> that must reject it — plus Haskell properties and the per-entry validation-locus ledger, in-process,
> before any real resource exists.
> **Read this if**: phase 27 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_09_resource_index.md, DEVELOPMENT_PLAN/phase_26_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_28_storage_geometry_folds.md, DEVELOPMENT_PLAN/phase_29_execution_accelerator_folds.md, DEVELOPMENT_PLAN/phase_30_capability_bind.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 27.1: Exhaustive negative/positive corpus split by foreclosure locus ⏸️](#sprint-271-exhaustive-negativepositive-corpus-split-by-foreclosure-locus-)
- [Sprint 27.2: GADT-index compile-refusal cases (type-foreclosed layer) ⏸️](#sprint-272-gadt-index-compile-refusal-cases-type-foreclosed-layer-)
- [Sprint 27.3: QuickCheck property suite ⏸️](#sprint-273-quickcheck-property-suite-)
- [Sprint 27.4: The per-entry validation-locus ledger — the gate ⏸️](#sprint-274-the-per-entry-validation-locus-ledger--the-gate-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 26, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

**Target capability — NOT VALIDATED.** A closed Haskell corpus is to map every illegal-state catalog entry to
exactly one truth-maker locus: structural typecheck, Haskell decode, provision seal, rendered-object oracle, or
deferred live effect. Haskell values own all positive/negative pairs, properties, compile-refusal modules, and
independent expectations. When a case needs Dhall, compiler input, a rendered object, or mutation bytes, the
Haskell harness is to materialize them beneath `.build/**`; no fixture, golden, ledger, or mutant is tracked as
non-Haskell source. This phase may cover only the Phase-25/26 pure loci and exact-owner deferrals. Capacity,
rendering, browser, hardware, and every live-effect row remain with later phases.

**Phase scope:** one target claim — every catalog entry is represented by a Haskell case at its exact pure
rejection locus or by an exact-owner deferral; generated case bytes stay beneath `.build/**`.

**Substrate:** `none` — no host, cluster, browser, or hardware; the canonical Haskell gate owns all tool
invocation and the candidate verdict.

**Lane:** none ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 1 — pure/semantic-oracle, in-process, no cluster ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 26](phase_26_gadt_decode_ir.md)
**Gate:** `pb validate phase 27`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Target only — every illegal-state catalog entry is a Haskell-owned case at its exact pure rejection locus or an exact-owner deferral; all non-Haskell case, compiler, oracle, and mutant bytes are generated beneath `.build/**`. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 27` is future public spelling only. Before current human approval of Phase 50, `pb` is inadmissible validation transport; the candidate must invoke the exact absolute source-bound Haskell executable directly from an authenticated, network-independent toolchain input. The Haskell verdict entry point remains `UNRESOLVED` and blocks validation. |
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
| `Legacy closure` | UNRESOLVED — blocks validation: `LTD-DOC-001` remains active; its exact zero-consumer input-closure check and Markdown/serialized-registry reintroduction negatives have not been implemented or qualified. |
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 26; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. The owner marker, preflight, complete
> allowed/forbidden mutations, external observer, scoped cleanup, and zero-owned-residue contract are absent.

## Doctrine adopted

- [`illegal_state_techniques.md §6 — Three layers of foreclosure (and the honesty they force)`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force):
  the three foreclosure layers (`type-foreclosed` / `decode-foreclosed` / `runtime-checked`) and the
  **structural-typecheck-vs-Haskell-decode caveat** — Dhall has no opaque types, so the Haskell corpus must
  split its cases between the two loci and lazily generate any Dhall projection; it may never bill a
  decode-only foreclosure as a structural type-check failure.
- [`illegal_state_techniques.md` §5 — Coverage matrix — which technique forecloses which illegal state](../documents/illegal_state/illegal_state_techniques.md#5-coverage-matrix--which-technique-forecloses-which-illegal-state)
  and [`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it):
  the coverage matrix is the checklist the Haskell corpus must exhaust — one case per Register-1-settleable entry —
  and [`illegal_state_catalog.md` §2 — The load-bearing limit: a type-check proves the spec composes, not that the cluster enforces it](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)'s limit is honored verbatim: *a type-check proves the spec composes, not that the cluster enforces
  it.* Entries whose truth-maker is the running cluster are ledgered `live-effect`, never claimed here.
- [`dsl_doctrine.md` §5 — The illegal-state-unrepresentable contract](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract):
  the **typed spec gates** — dhall-typecheck (the Dhall typechecker) and gadt-decode (the in-process `Dhall.inputFile auto`
  decoder). The target Haskell harness exercises both and generates compile-refusal input beneath `.build/**`;
  no serialized golden gives the GADT indices authority; reviewed Haskell expectations do.
- [`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  and [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting):
  the complete resource envelope and opaque post-bind checked boundary. This phase exhausts the resource
  **shape/normalization** cases its predecessors own (including the missing-envelope [`illegal_state_security.md` §3.11 — An unsafe workload (no resource limits, no hardened securityContext)](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext) negative) and
  derives every later capacity, storage, accelerator, VRAM, and missing-capability deferral from registry
  ownership tags; it never claims later capacity or provisioning folds have run early.
- [`testing_doctrine.md` §2 — The registers of amoebius testing](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) — **Register 1**
  (pure/semantic-oracle, in-process, no cluster): the register this phase's gate reaches; and
  [`testing_doctrine.md` §4 — No skips, fail fast, and the per-run ledger artifact](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) — the proven/tested/assumed ledger
  the battery emits, the validation-locus ledger being its per-catalog-entry specialization with model↔runtime
  correspondence marked UNVERIFIED.
- [`conformance_harness_doctrine.md` §2 — The registers, as amoebius uses them for pre-cluster validation](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)
  and [`conformance_harness_doctrine.md` §6 — Honesty: what the harness does and does not establish](../documents/engineering/conformance_harness_doctrine.md#6-honesty-what-the-harness-does-and-does-not-establish): Register 1 is the pure/semantic-oracle
  no-cluster band. Any future candidate result is limited to pure composition and named refusals; it can say
  **nothing** about whether physical effects converge, which is the deferred `live-effect` locus.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanently invalidated history.** Every completion, seal, reseal, transcript, evidence, and
> closure statement in the sprint bodies below is rejected as current validation. The material is retained
> only as a target-capability inventory and cannot support status, promotion, or a validation claim.

## Sprint 27.1: Exhaustive negative/positive corpus split by foreclosure locus ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: [Phase 26](phase_26_gadt_decode_ir.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`illegal_state_techniques.md §5/§6`](../documents/illegal_state/illegal_state_techniques.md#5-coverage-matrix--which-technique-forecloses-which-illegal-state):
assemble the corpus that exercises the type discipline exhaustively over the coverage matrix, **honestly split by the locus that rejects each fixture** — dhall-typecheck negatives that must fail `dhall type`, gadt-decode negatives that
must pass `dhall type` and decode-reject — never billing a gadt-decode-only foreclosure as a dhall-typecheck failure.

### Deliverables

- A closed Haskell catalogue declares each entry, validation locus, delivery owner, case family, and occupied
  cell. A separately authored Haskell oracle states the expected identities and relations. Reader-facing
  `Validation-locus:`, `Delivery-owner:`, `Case-family:`, and `Cells:` prose may be checked for document shape,
  but no gate translates it into a behavioural value or treats it as the executable registry.
- Positive Haskell case declarations (`legal_multisubstrate_cluster`, `legal_managed_eks`, `trivial_app`, and
  deployment rules) lazily render any Dhall/compiler input beneath `.build/**`, then decode with complete
  normalized resource envelopes and target capacities.
- dhall-typecheck negatives (`illegal_dhall_typecheck_*`, must fail `dhall type`) are **exactly** the Haskell
  catalogue rows with `validation_locus = dhall-typecheck` and
  `owner_phase ≤ Phase-27`. Required members
  include product-named capability ([§3.12](../documents/illegal_state/illegal_state_capability_messaging.md#312-an-app-that-names-a-product-instead-of-a-capability)), insecure/backdoor ingress ([§3.7](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)), a workload missing its complete
  `ResourceEnvelope` ([§3.11](../documents/illegal_state/illegal_state_security.md#311-an-unsafe-workload-no-resource-limits-no-hardened-securitycontext); the Phase-25 `illegal_missing_resource_envelope` case), unbounded storage /
  un-tiered topic ([§3.18](../documents/illegal_state/illegal_state_storage.md#318-unbounded-storage-anywhere)/[§3.20](../documents/illegal_state/illegal_state_storage.md#320-a-pulsar-topic-without-a-bounded--tiered--retained-lifecycle)), growth with no scaling policy ([§3.21](../documents/illegal_state/illegal_state_storage.md#321-capacity-growth-without-an-amoebius-owned-scaling-policy)), even/zero-server rke2 control plane
  ([§3.24](../documents/illegal_state/illegal_state_topology.md#324-an-evenzero-server-rke2-control-plane-no-etcd-quorum--split-brain)), a substrate/topology arm the union does not offer
  ([§3.14](../documents/illegal_state/illegal_state_topology.md#314-rke2kind-on-a-host-with-no-linux-node-applewindows-without-an-interposed-linux-vm)/[§3.15](../documents/illegal_state/illegal_state_topology.md#315-a-multi-node-kind-cluster-not-on-a-single-linux-host)), and the controller fields Dhall intentionally omits:
  DaemonSet both-positive rollout, StatefulSet unsupported feature/nonzero partition, and Job missing terminal
  retention. The reviewed Haskell catalogue, not this prose list or a Markdown/TSV projection, is the exact
  enumeration.
- gadt-decode negatives (`illegal_decode_*`, must pass `dhall type`, then decode-reject) are **exactly** registry
  rows with `validation_locus = gadt-decode` whose
  `owner_phase ≤ Phase-27`; these exercise the Phase-26
  structural decoder, normalized resource/capacity representation, ownership indices, and compile-fail
  boundary already available to this phase. Required execution-normalization cases cover every
  controller-kind/cardinality/policy/resource mismatch, including raw Deployment
  `RollingUpdate { maxSurge = 0, maxUnavailable = 0 }` returning the pinned
  `UnspellableCombination` tag, paired with independently exercised `{ 1, 0 }` and `{ 0, 1 }` positives.
  The representable gadt-decode controller cases cover controller/cardinality/resource mismatches, CUDA rolling,
  Metal-on-Deployment, and reused rke2 hosts, each with a minimally differing legal twin. The received-side
  malformed CBOR body is also rejected here. Produce-side non-CBOR is stronger: the typed payload codec has
  no such inhabitant and is pinned by the fifth compile-fail pair in Sprint 27.2.
  The declared-compute-headroom cases belong here rather than to the deferred set below, because both are
  cross-field checks the Phase-26 smart constructor owns: `illegal_decode_headroom_over_limit`, whose pad
  breaches `requests + pad ≤ limits` on one axis, and `illegal_decode_headroom_all_zero`, whose pad is `Zero`
  on every axis and so has no `PositiveHeadroomAxisWitness`. Each mutates a single construct of a legal twin
  that declares lawful headroom, so the pinned tag proves the pad rule fired rather than an unrelated shape
  error.
- **Provisioning-deferred negatives are selected by tags, never section-number ranges.** A registry row with
  `validation_locus = provision-seal`, an `owner_phase` of `Phase-9` or `Phase-31`, and a `case_family` of
  `topology`, `capacity`, `storage`, `cache`, `accelerator`, or `capability-provision` carries no rejecting
  fixture in Phase 27 and is ledgered with that owner. The generated selection must include every current
  aggregate and atomic fit case: engine/substrate incompatibility and host reuse; host/VM/cluster and
  elastic-quota overcommit; pod ephemeral-storage and finite-limit/physical-peak overflow; a padded
  reservation that fits on required requests alone but overcommits allocatable once declared headroom is
  charged;
  durable/native-cache-pool and
  in-cluster-cache-nesting violations; Pulsar two-ceiling overflow; affinity/taint unplaceability; CUDA
  requested on a CPU-only target;
  whole-device-count shortage; accelerator source/workload or policy-domain mismatch; invalid residency/shard
  structure; a policy-permitted coexistence epoch whose co-resident per-device aggregate exceeds net
  allocatable VRAM; and provider-expanded resource demand. Phase 9 owns the pure folds and Phase 31 owns the end-to-end post-bind
  `ProvisionContext → Topology → BoundDeployment → Either ProvisionError ProvisionedSpec` boundary. Adding a new catalog row with
  those tags automatically adds it to the deferred set; no phase-doc range edit is required.
- **Near-miss twinning (forecloses wrong-reason negatives, §M.8).** Each dhall-typecheck negative is a
  **single-construct mutation** of a Haskell-declared legal twin, differing only in the foreclosed dimension.
  The twin must pass `dhall type`; the observed error must match a separately authored Haskell expectation
  naming the foreclosing union or field. Each `illegal_decode_*` negative is likewise a single-field mutation
  of a legal twin that decodes and is checked against an independently declared `DecodeError` tag. All
  non-Haskell bytes are generated beneath the fresh run root.
- **Per-Register-1-locus fixtures (disambiguation).** A catalog entry carrying more than one Register-1 locus
  (e.g. [§3.16](../documents/illegal_state/illegal_state_topology.md#316-a-multi-node-rke2-cluster-with-fewer-linux-hosts-than-nodes-or-a-host-reused) = `dhall-typecheck` cardinality sub-part + `gadt-decode` distinctness fold) owes **one fixture row per Register-1 locus it carries**, each rejected at its own locus — not one row total. The ledger's
  single "truth-maker locus" per entry is the earliest-sufficient among the loci it carries (§M.8 tie-break:
  `dhall-typecheck` < `gadt-decode`), but delivery follows each row's owner: Phase 27 supplies only rows owned
  by reached phases, while later-owned subcases remain visibly deferred to those phases.

### Validation

1. Every reached dhall-typecheck negative fails `dhall type` with its observed error matching a separately
   authored Haskell expectation that names the foreclosing union or field, and its legal near-miss twin passes
   `dhall type`.
2. Every reached gadt-decode negative passes `dhall type` and then decodes to a `Left DecodeError` whose tag
   equals its separately authored Haskell expectation; its legal twin and every positive case decode.
3. `CorpusSpec` is red if any illegal Haskell-declared case is admitted at or past its tagged locus, if any twin
   fails, or if any observed error diverges from its separately authored Haskell expectation.
4. The coverage note maps each fixture to its catalog entry and foreclosure layer and is reconciled against
   the separately authored Haskell locus inventory, and every exact-owner provisioning row is present in the derived
   deferred set with the exact owner.
5. Haskell-declared union-arm-addition and resource-normalization mutants are applied to generated run-local
   sources; each turns `CorpusSpec` red and records the changed production locus.

### Remaining Work

The pre-reset `None` claim is permanently invalid; Sprint 27.1 remains blocked and NOT VALIDATED.

## Sprint 27.2: GADT-index compile-refusal cases (type-foreclosed layer) ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 27.1
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt the [`illegal_state_techniques.md §6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
`type-foreclosed` layer at its strongest: give the GADT indices their teeth by proving the illegal value has
**no inhabitant** — it does not merely decode to a `Left`, it does not compile at all. This is the residue the
Phase-25 honesty caveat routed here, since Dhall has no opaque types.

### Deliverables

- Haskell declarations for compile-refusal cases covering the type-foreclosed entries the IR indices foreclose:
  a cross-tenant `Ref`
  ([§3.8](../documents/illegal_state/illegal_state_security.md#38-cross-tenant-references-and-literal-secrets)/[§3.10](../documents/illegal_state/illegal_state_security.md#310-a-child-spec-that-reaches-beyond-its-own-subtree)), a PVC with no matching PV ([§3.2](../documents/illegal_state/illegal_state_storage.md#32-pvcs-that-dont-bind-pvs)), an endpoint-kind interconversion ([§3.7](../documents/illegal_state/illegal_state_security.md#37-accidental-insecure--backdoor-ingress)), and a route built
  from no live service handle ([§3.3](../documents/illegal_state/illegal_state_security.md#33-misconfigured-gateway)), plus a non-CBOR Pulsar produce payload
  ([§3.23](../documents/illegal_state/illegal_state_capability_messaging.md#323-a-non-cbor-pulsar-payload)).
  Each declaration lazily renders an expect-fail module beneath `.build/**`; no module, golden, or expected
  compiler output is tracked as non-Haskell source.
- A pinned `ghc -fno-code` expect-fail harness reporting one aggregate green/red over the generated case set,
  plus a generated positive-control module that compiles. A separately authored Haskell oracle declares each
  expected GHC error class and locus and each one-token legal twin; the harness renders both modules and
  expectations only beneath the fresh `.build/**` run root.
- A Haskell-declared guard-weakening GADT-index mutation, applied to a run-local production-source copy, that
  proves the harness actually rejects changed production behaviour.

### Validation

1. Every generated compile-refusal case imports only the real exported vocabulary, is scope-clean and
   parse-clean, and
   fails to compile under the pinned `ghc -fno-code` harness with a GHC **type** error whose class and locus
   match the separately authored Haskell expectation.
2. The error class is asserted, not merely "fails": it is read from structured diagnostics —
   `-fdiagnostics-as-json`, or a pinned `--json`-derived tag — so a scope, parse, or name error does not
   satisfy a case.
3. Each case's one-token legal twin, differing only in the single foreclosed index, compiles, as does the
   companion positive control module carrying the legal vocabulary.
4. The harness is red if any negative compiles, if any negative fails for a non-type reason, or if any
   observed diagnostic diverges from its Haskell expectation.
5. The guard-weakening GADT-index mutation makes at least one negative compile and thereby turns the harness
   red while an unaffected control remains green.

### Remaining Work

The pre-reset `None` claim is permanently invalid; Sprint 27.2 remains blocked and NOT VALIDATED.

## Sprint 27.3: QuickCheck property suite ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 27.2
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`illegal_state_techniques.md §6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)
and [`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact): establish the
closure / round-trip / fold-totality / composition-preservation properties of the type discipline, labelled
honestly — **TESTED (sampled)** for infinite domains, upgraded to **PROVEN** only where a finite domain is
exhausted (the three `Rke2Servers` arms).

### Deliverables

- `prop_smartCtorClosure` (a smart constructor never yields an illegal value), `prop_decodeRoundTrip`
  (encode∘decode is identity on well-formed IR), `prop_foldTotal` (every decode-time fold terminates on
  generated input without partiality), and `prop_compositionPreservesWellFormedness` (composing two
  well-formed fragments yields a well-formed value).
- A per-property label: TESTED (sampled) by default; PROVEN for the exhausted `Rke2Servers` finite domain.
- **Declared coverage minima (forecloses vacuous generators, §M.4).** Each property runs under `checkCoverage`
  with explicit `cover` obligations forcing its nontrivial arms: `prop_smartCtorClosure` covers each
  smart-constructor family (≥ 15% each, ≥ 3 distinct families); `prop_decodeRoundTrip` covers non-empty
  multi-substrate and multi-service IR (≥ 20% multi-substrate, ≥ 20% ≥2-service); `prop_foldTotal` covers each
  distinct fold with a boundary/near-illegal-but-legal input (≥ 10% per fold); `prop_compositionPreservesWell-
  formedness` covers non-identity compositions of two distinct non-trivial fragments (≥ 25%). Generators that
  emit a single trivial value fail the coverage check and the suite is red.
- A reviewed Haskell broken-smart-constructor / partialized-fold mutation operator (d), applied to a temporary
  source copy beneath `.build/mutants/**`, that must turn each property red while the unchanged control stays
  green.

### Validation

1. Rejected historical observation: the Cabal property suite was recorded green under `checkCoverage`:
   closure holds over the smart-constructor
   vocabulary, decode round-trips, every fold is total on generated input, and composition preserves
   well-formedness.
2. Each property declares its `cover`/`classify` obligations, and the run fails if a declared minimum is not
   met, so a generator emitting one trivial value cannot pass.
3. The exhausted-domain properties are marked PROVEN and the sampled ones TESTED — no sampled property is
   billed as a proof.
4. The applied Haskell broken-smart-constructor / partialized-fold mutant (d) turns each of the four properties
   red, and the suite is red if that mutant survives any property or if the production-change witness is absent.

### Remaining Work

The pre-reset `None` claim is permanently invalid; Sprint 27.3 remains blocked and NOT VALIDATED.

## Sprint 27.4: The per-entry validation-locus ledger — the gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: exact authored Haskell implementation paths have not been bound to this sprint.
**Blocked by**: Sprint 27.3
**Independent Validation**: UNRESOLVED — blocks validation: independent positive, paired-negative, changed-subject mutant, and residue observations have not been bound to this sprint.
**Oracle**: UNRESOLVED — blocks validation: a separately authored Haskell oracle, its provenance, and its human reviewer have not been bound to this sprint.
**Legacy IDs**: UNRESOLVED — blocks validation: this sprint has not been joined to exact typed Haskell legacy-inventory IDs.
**Docs to update**: UNRESOLVED — blocks validation: the governed documentation owners and exact update set have not been reviewed for this sprint.

### Objective

Adopt [`testing_doctrine.md §4`](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) and
[`illegal_state_techniques.md §6`](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force):
emit the per-entry validation-locus ledger — the honest map from every catalog entry to the one locus that
settles it — and gate on it, so no entry is silently unvalidated and no deferred entry is silently claimed.
The truth-maker locus and delivery ownership stay separate: reached Dhall/GADT rows through Phase 27 are
discharged here; whole-deployment fold/provision rows carry the distinct `provision-seal` locus and remain
assigned to their exact owners; `rendered-artifact-oracle` is owned by
[Phase 33](phase_33_render_manifest_oracles.md), and `live-effect` by the live band.

The gate discovers surfaces into `.build/test-surfaces/` and emits its run ledger under `.build/runs/`. The emitted
validation-locus artifact is a **coverage projection** of the catalog and the modules under test, so by the
source-based rule of [`generated_artifacts_doctrine.md §3`](../documents/engineering/generated_artifacts_doctrine.md#3-the-rule)
it is a **generated** Register-1 output beneath `.build/**` and is not repository source. It is *not* the run-evidence ledger
[§K](development_plan_standards.md#k-honesty-proven--tested--assumed) requires every gate to emit and
externally attest: that is a separate artifact recording what this gate established and by what means, and
its schema, linter, and path are centrally owned rather than re-derived here.

### Deliverables

- Consumption of the Sprint-27.1 Haskell catalog enrichment and its run-local generated locus projection; Sprint 27.4 does not
  regenerate or reinterpret their owner/family classification from the emitter.
- A ledger emitter that classifies each catalog entry into its earliest-sufficient truth-maker locus:
  `dhall-typecheck` (fails `dhall type`, authoring-time), `gadt-decode` (a `.hs` compile-refusal case checked by
  an independent Haskell error-class/locus expectation, or decode
  `Left`), `provision-seal` (post-bind `ProvisionError` before `ProvisionedSpec`), `rendered-artifact-oracle`
  (settled on emitted bytes in Phase 33), `live-effect` (settled only by a
  running cluster, deferred to Register 3). A separate disposition records `discharged-here` or
  `deferred : owner_phase`; ownership never changes the recorded locus. Tie-break for a multi-locus entry:
  the earliest-sufficient Register-1 locus
  (`dhall-typecheck` < `gadt-decode` < `provision-seal` < `rendered-artifact-oracle`), while each sub-case retains
  its own registry row so one entry can owe fixtures at more than one locus or phase.
- The independent Haskell locus oracle, which may render a diagnostic `locus_registry.tsv` only beneath
  `.build/**`, checks the production Haskell catalogue against separately authored Haskell expectations. It
  never derives semantics from the catalogue Markdown. The generated projection has columns at minimum
  `entry`, `subcase`, `validation_locus`, `owner_phase`, and `case_family`. The
  provisioning-deferred set is a query over those Haskell-declared rows (`owner_phase ∈ {Phase-9, Phase-31}` plus the
  provisioning case families), not a duplicated literal section-number list.
- A coverage assertion that **reconciles the emitter's locus for every entry against the registry** and goes
  red on any locus/owner/family divergence, then requires every reached `dhall-typecheck` /
  `gadt-decode` row to have its rejecting fixture present and passing here, and every later-owned row to be
  marked deferred with its exact owner. The emitted ledger leads with a Register-1-only,
  Tier-2-UNVERIFIED banner.

### Validation

1. The ledger emits with every catalog entry mapped to exactly one truth-maker locus (`dhall-typecheck` /
   `gadt-decode` / `provision-seal` / `rendered-artifact-oracle` / `live-effect`) and one disposition
   (`discharged-here` or `deferred : owner_phase`), with the production Haskell map reconciled against the
   separately authored Haskell oracle and red on any locus, owner, or family divergence.
2. The production catalogue and independent oracle are distinct Haskell modules with separate human-review
   custody. Neither consumes the other, a Markdown page, or a serialized registry, so the emitter cannot
   decide which class owes a case.
3. The coverage assertion is green: every reached `dhall-typecheck` or `gadt-decode` row carries a
   passing rejecting fixture here, and every deferred row names its registry owner — `provision-seal`
   topology/capacity/storage/cache/accelerator/capability-provision rows → Phase 9 or Phase 31,
   `rendered-artifact-oracle` → Phase 33, `live-effect` → the live band — without being reclassified.
4. The suite is red if any entry or subcase is unmapped, misclassified relative to the registry, selected by
   a stale hard-coded range, or claimed settled before its owner phase.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate. Enumeration, ledgers, and run evidence remain generated beneath `.build/` and join to authored
expectations at gate time.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/illegal_state/illegal_state_*.md` — annotate every themed entry with reader-facing
  `**Delivery-owner:**` and `**Case-family:**` statements alongside its existing validation locus
  (`dhall-typecheck` / `gadt-decode` / `provision-seal` →
  Register 1, with reached generated-Dhall/GADT rows targeted here; later or different-locus rows retain their exact
  owners; `rendered-artifact-oracle` → Phase 33; `live-effect` → the live band), and confirm the §5
  coverage matrix is exhausted for the Register-1 rows this phase owns.
- `documents/engineering/dsl_doctrine.md` — backlink §5's two gates to the exhaustive Phase-27 corpus and the
  compile-refusal case family that pins the type-foreclosed layer.
- `documents/engineering/testing_doctrine.md` — record the validation-locus ledger variant and the
  sampled-vs-exhausted QuickCheck label discipline this gate emits (correspondence and runtime fidelity
  UNVERIFIED).

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — the human authority alone may change Phase-27 status after the redesigned gate and external approval; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — the Phase-27 `none` gate row.
- `DEVELOPMENT_PLAN/system_components.md` — map only the target Haskell corpus, compile-fail, property, and
  validation-locus modules; serialized Dhall examples are lazy `.build/**` products, never tracked components.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- Phase 27 illegal-state ledger — the authored proven/tested/unverified account of this gate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the design-proof acceptance token: *spec-composition proven*, never *runtime proven*)
- [overview.md](overview.md) — target architecture and the DSL vision
- [Illegal State Catalog](../documents/illegal_state/illegal_state_catalog.md) — the catalog index and its [§2](../documents/illegal_state/illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)
  load-bearing limit; the [§5](../documents/illegal_state/illegal_state_techniques.md#5-coverage-matrix--which-technique-forecloses-which-illegal-state) coverage matrix this corpus exhausts and the [§6](../documents/illegal_state/illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force) three foreclosure layers with the
  honest dhall-typecheck-vs-gadt-decode split live in `illegal_state_techniques.md`
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — [§5](../documents/engineering/dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract) the typed spec gates exercised against the corpus
- [Testing Doctrine](../documents/engineering/testing_doctrine.md) — [§2](../documents/engineering/testing_doctrine.md#2-the-registers-of-amoebius-testing) Register 1, [§4](../documents/engineering/testing_doctrine.md#4-no-skips-fail-fast-and-the-per-run-ledger-artifact) the per-run ledger the
  validation-locus ledger specializes
- [Conformance Harness Doctrine](../documents/engineering/conformance_harness_doctrine.md) — [§2](../documents/engineering/conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation) the registers,
  [§5](../documents/engineering/conformance_harness_doctrine.md#6-honesty-what-the-harness-does-and-does-not-establish) the honesty limit (a green Register-1 corpus is not a live-effect claim)
- [phase_25](phase_25_dhall_schema_generation.md) — dhall-typecheck, the Dhall schema + positive corpus this phase extends
- [phase_26](phase_26_gadt_decode_ir.md) — gadt-decode, the GADT-indexed IR + decoder this corpus rides atop
- [phase_9](phase_09_resource_index.md) — the pure capacity/topology/storage fold negatives selected
  from the registry as deferred from here
- [phase_30](phase_30_capability_bind.md) — the post-bind provisioning/capability negatives selected from the
  registry as deferred from here
- [phase_33](phase_33_render_manifest_oracles.md) — the `rendered-artifact-oracle` locus this ledger points at
- [phase_65](phase_65_live_dsl_deploy.md) — the live band where the `live-effect` locus is discharged
