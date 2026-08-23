# Phase 73: WireGuard network fabric

> **Purpose**: Stand up the raw-kernel WireGuard fabric configured directly by amoebius — Vault-KV Curve25519 peer keys named by `SecretRef`, per-peer config *rendered* from the node inventory and reconciled by the control-plane daemon, a hub bound to the gateway *role* — so every cluster (root included) draws a VPN IP from the root-deployed gateway and the hub is reachable across the fabric.
> **Read this if**: phase 73 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_74_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/vault_pki_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 73.1: Vault-KV Curve25519 peer keys — secrets by name, minted and custodied in Vault ⏸️](#sprint-731-vault-kv-curve25519-peer-keys--secrets-by-name-minted-and-custodied-in-vault-)
- [Sprint 73.2: Rendered peer config + the wg reconcile — render → wg show/diff/wg set ⏸️](#sprint-732-rendered-peer-config--the-wg-reconcile--render--wg-showdiffwg-set-)
- [Sprint 73.3: Phase gate harness — live fabric + external-observer reachability over the VPN IP ⏸️](#sprint-733-phase-gate-harness--live-fabric--external-observer-reachability-over-the-vpn-ip-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 72, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-49 barrier is invalidated and non-operative.

## Phase Summary

This phase's target is the inter-node / inter-cluster network fabric as **raw kernel WireGuard configured directly by amoebius — never Netmaker**. The root node must deploy an HA cluster that configures a WireGuard *gateway*, and
every cluster in the forest — the root included — receives a VPN IP from that gateway; the gateway node is the
**hub**, bound to the gateway *role* rather than to a fixed cluster, so the flattened mesh moves with the
gateway on a later migration.

WireGuard fits the amoebius disciplines because it is a *primitive*, not a platform.
Its three obligations map onto machinery supplied only by human-approved predecessors:
- (1) **keys** are raw Curve25519 static keypairs custodied as a **Vault-KV secret class** — Vault mints and
  holds each keypair, the Dhall names it by `SecretRef` only, and the parent injects it into a child's Vault
  (they are *not* X.509 PKI certs, and never gate an unseal)
- (2) **peer config** is `render(nodeInventory) -> [WireGuardPeerConfig]`, the pure-`render()` discipline
  lifted to `wg` config, so a keyless peer is type-foreclosed (unrepresentable) and overlapping VPN IPs / an
  `AllowedIPs` outside the fabric CIDR are decode-foreclosed (a total fold returning `Left`)
- (3) **distribution** is the control-plane daemon's ordinary `discover (wg show) → diff against render(inventory) →
  enact (wg set)` reconcile — no Netmaker agent, no second control server, no MQTT push channel, no second
  state store.

The fabric is not free host overhead: the pure `NetworkFabricSystemDemand` supplies a finite packet-rate,
queue-byte bound, rotated-log policy, and versioned cost model. Provisioning joins it to the exact
topology-expanded node/peer graph and derives finite per-node kernel/listener CPU and memory
reservation+ceiling plus nodefs bytes before any interface, peer, queue, or listener mutation.

The design half of the render obligation depends on human-approved pre-cluster work (Registers 1–2, substrate
`none`): the typed decoder (Phase 26), the illegal-state corpus (Phase 27), and the pure `renderAll` manifest oracles
(Phase 33) must establish, in-process, that a keyless peer will not construct and an overlapping-IP peer set
will not decode. Once those approvals exist, Phase 73 must add the **runtime residue**: a real `wg0` interface on each node, brought up by the
control-plane daemon reconcile, over which a spoke actually reaches the hub at its VPN IP. VPN-IP allocation is by disjoint
per-cluster sub-ranges of the fabric CIDR — the same disjoint-namespace allocation the failover doctrine uses,
so two clusters can never mint the same VPN IP (confluent by construction). The cross-cluster **broker↔broker**
geo-replication wire is *not* delivered here — its per-peer `render()` obligation is deferred to Phase 74; the
two spans this phase must render are the remote-worker↔home attach carrier and the fabric-bound listener boundary.
The gateway-migration hub *repoint* is Phase 75; the Phase-73 gate must establish the static fabric it will
later move.

**Phase scope:** one cohesive target claim — *peer configuration must be rendered from the node inventory and
reconciled, never hand-written*. Keys must live in Vault by reference, and the hub must bind to a role rather
than a host.

**Substrate:** linux-cpu — the target may run only on the single-node `kind` host after Phase 55 has been
human-approved; that host's kernel must provide the WireGuard
module; the representative fabric is two peers (a gateway-role hub node and one spoke) each in its own Linux
network namespace on that host. No apple, linux-cuda, or windows substrate is exercised by this phase's gate.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).
The future contract must bind any independently validated pre-cluster model receipt and then observe the tunnel
and resource-control/readback layer on `linux-cpu`. A candidate may call that bounded runtime observation
*tested*, never *proven*, and cannot promote itself.

**Depends on:** [Phase 72](phase_72_ui_program_release.md) — exact current human approval; the numeric chain includes every earlier phase
**Gate:** `pb validate phase 73`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | one cohesive claim — *peer configuration is rendered from the node inventory and reconciled, never hand-written*. Keys live in Vault by reference, and the hub binds to a role rather than a host. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | `pb validate phase 73` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | MISSING — blocks validation: the current Phase 72 human approval receipt does not exist. |
| `Residue` | UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The detailed material retained below is capability inventory only and cannot supply or substitute for that contract.

The two kernel interfaces and their listeners are host execution units, not resource-free infrastructure.
Before `wg`, `ip`, `tc`, a socket bind, a key read, or a log write, binding expands one pure fabric transition
demand over the exact peer graph. For each node it retains the content digest and installed bytes of the
host listener executable (there is no OCI image for this host process), Linux-cgroup-v2 CPU/memory
reservation and ceiling, queue memory, bounded temporary/writable state, active-plus-rotated log bytes and
their nodefs backing, packet/queue concurrency, and the interface/listener identity. The small amount of
fabric-render/diff work performed by the already-existing Phase-65 control-plane daemon is added to that control-plane daemon's
existing container CPU/memory/ephemeral/log/mapped-file envelope; it does **not** create a fabric controller
pod or a second pod/IP/CSI debit. The Vault server is a surviving service whose full envelope/storage is
already in the same live snapshot; key mint/read request buffers and CPU are charged to Vault and the
control-plane daemon client, not to a fictitious key-agent Pod. The phase introduces no durable volume, cache,
accelerator, or VRAM demand.

The v1 transition is in-place for peer/config changes: one interface and one listener remain live. A listener
binary replacement is `RecreateAfterObservedExit`; the old executable, process, cgroup, socket, and log extent
remain charged until the external observer sees them gone, and only then may the replacement start. Thus no
unmodelled old/new process overlap is hidden in the steady-state row. The gate harness is itself a bounded
linux-cpu host process with an executable digest, CPU/memory reservation+ceiling, packet-capture buffer,
temporary capture/log bytes on a named host backing, and finite probe concurrency; the ICMP/TCP clients are
operations inside that envelope, not invented pods.

After controller expansion, the binder serializes exhaustive `desiredObjects` for **all** rendered and derived
Kubernetes objects, not a selected kind list, and joins observed survivors with old/new/apply-before-prune.
`EtcdLogicalDemand { desiredObjects, churn, model }` includes revision, Lease and Event churn; only private
`ProvisionedEtcdLogicalDemand.derivedPeak <= backendQuotaBytes` may continue. Separately, physical capacity fits
backend-at-quota plus WALs, retained/saving snapshots and defrag old+new workspace. Live object serialization,
logical quota and backend/WAL/snapshot state must equal the witness. Haskell one-byte shortage and
drop-fabric-object/churn/model mutation operators must reject before kernel mutation; any external mutation
form is generated beneath `.build/test-corpora/**`.

Only the opaque whole-deployment provision result may project the listener cgroup, executable path, `tc`
settings, log policy, and control-plane daemon resource delta. Immediately before enactment, and again after it, the
gate reads the live process/cgroup, executable digest, nodefs high-water, interface/socket, and control-plane daemon Pod
resources and compares them exactly with that projection. Independent one-unit-short CPU reservation,
CPU ceiling, memory reservation, memory ceiling, queue, writable/log/nodefs, host-process-slot, and harness
capture-space Haskell cases return their tagged `Left` with zero fabric effects. An applied Haskell
dropped-envelope mutant that starts the listener or probe without its resource row, and a Haskell
replacement-overlap mutant that starts the new listener before the old PID is observed absent, must both turn
the gate red.

## Doctrine adopted

- [`workflow_calculus_doctrine.md` §3 — Teardown is a type obligation](../documents/engineering/workflow_calculus_doctrine.md#3-teardown-is-a-type-obligation) — wireGuard network fabric provisions, and a teardown obligation it cannot discharge is a value it cannot construct.
- [`network_fabric_doctrine.md §2` — Raw WireGuard, not Netmaker](../documents/engineering/network_fabric_doctrine.md#2-raw-wireguard-not-netmaker):
  amoebius configures the raw kernel WireGuard *primitive* it owns end to end and runs none of Netmaker's
  machinery — no second control server, no second desired-state DB, no MQTT peer-push broker, no second PKI, no
  second node inventory. This phase configures `wg` directly.
- [`network_fabric_doctrine.md` §3 — Keys, config, and distribution — WireGuard as just-another-reconcile](../documents/engineering/network_fabric_doctrine.md#3-keys-config-and-distribution--wireguard-as-just-another-reconcile):
  peer keys are a **Vault-KV Curve25519 secret class** under the secrets-by-name + parent-injection model (not
  PKI certs, never gating an unseal); peer config is the pure `render(nodeInventory) -> [WireGuardPeerConfig]`
  (keyless peer type-foreclosed, overlapping IP / out-of-CIDR `AllowedIPs` decode-foreclosed); distribution is
  the control-plane daemon's `wg show → diff → wg set` reconcile, not an agent.
- [`network_fabric_doctrine.md` §4 — Topology: the hub is the gateway *role*, and the fabric moves with it](../documents/engineering/network_fabric_doctrine.md#4-topology-the-hub-is-the-gateway-role-and-the-fabric-moves-with-it):
  the hub is bound to the gateway *role* at a stable VPN-IP + `Endpoint`, VPN-IP allocation is by disjoint
  per-cluster ranges (confluent by construction), and for the attach topology the home cluster is the hub. This
  phase's target must stand up the static hub; Phase 75 later repoints it on migration.
- [`network_fabric_doctrine.md §5` — The security boundary generalizes: localhost → authenticated fabric](../documents/engineering/network_fabric_doctrine.md#5-the-security-boundary-generalizes-localhost--authenticated-fabric):
  fabric-bound listeners bind to `wg0`, never `0.0.0.0`/LAN/WAN, so the host-comms security property moves from
  "reachable only from localhost" to "reachable only over the authenticated WireGuard fabric" — Curve25519 peer
  auth + ChaCha20-Poly1305 encryption supply what the WAN removed, with no in-cluster mTLS tax reintroduced.
- [`network_fabric_doctrine.md §6` — The service-mesh verdict: no Linkerd for v1](../documents/engineering/network_fabric_doctrine.md#6-the-service-mesh-verdict-no-linkerd-for-v1):
  a service mesh is **not** adopted; this phase's target fabric must be WireGuard, and no Linkerd sidecar fleet
  may be introduced. (Cited for the boundary; no mesh component is built here.)
- [`vault_pki_doctrine.md §3.1` — The parent-custody KV secret family: SSH keys, WireGuard keys, and the `Rke2NodeToken`](../documents/engineering/vault_pki_doctrine.md#31-the-parent-custody-kv-secret-family-ssh-keys-wireguard-keys-and-the-rke2nodetoken):
  WireGuard peer keys are custodied as a **Vault-KV Curve25519 secret class** named by `SecretRef` — Vault mints
  and parent-injects each keypair; they are never X.509 PKI certs and never gate an unseal.
- [`manifest_generation_doctrine.md §2` — The typed manifest model: `renderAll` is the sole public pure function to objects](../documents/engineering/manifest_generation_doctrine.md#2-the-typed-manifest-model-renderall-is-the-sole-public-pure-function-to-objects):
  the peer config is a pure-`render()` product reconciled by the control-plane daemon like any other manifest, with keyless
  and overlapping-IP peers foreclosed.
- [`resource_capacity_doctrine.md` §3 — The types: `Quantity`, `Capacity`, `Demand`, `Budget`](../documents/engineering/resource_capacity_doctrine.md#3-the-types-quantity-capacity-demand-budget)
  and [`resource_capacity_doctrine.md` §4 — The total fold: `fits`, `carve`, `place`, and the nesting](../documents/engineering/resource_capacity_doctrine.md#4-the-total-fold-fits-carve-place-and-the-nesting):
  the raw `NetworkFabricSystemDemand` is an input to provisioning, not a free fixed subtraction; its private
  topology-expanded result is admitted as a named infrastructure reserve against the same node/candidate
  ledger used for workloads before the host reconcile may mutate anything.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

> **Permanent sprint reset.** Every pre-reset sprint status, result, date, pass, seal, receipt, evidence path, and closure statement below is permanently invalid for promotion. The retained body is non-operative capability inventory only. Current acceptance requires the resolved eighteen-row Haskell gate contract, fresh independently observed evidence, immediate-predecessor approval, owned legacy closure, and a human tracker change.
>
> **Source/artifact boundary.** Every retained fixture, oracle, expected value, corpus, schema, config, manifest, transcript, receipt, script, and mutation name below denotes semantics authored in reviewed Haskell `.hs`. Any reproducible serialized or materialized form is generated lazily beneath ignored `.build/**` and remains untracked. No retained artifact path is an implementation instruction; `pb/**` remains the bootstrap-only exception and owns none of this behavior.

## Sprint 73.1: Vault-KV Curve25519 peer keys — secrets by name, minted and custodied in Vault ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`network_fabric_doctrine.md §3`](../documents/engineering/network_fabric_doctrine.md#3-keys-config-and-distribution--wireguard-as-just-another-reconcile):
custody WireGuard peer keys as a **Vault-KV Curve25519 secret class** under the secrets-by-name +
parent-injection model — Vault mints and holds each keypair, the Dhall names it by `SecretRef` only, and no
fabric key is ever an X.509 cert or an unseal gate. This foreclose-secrets-in-Dhall property is the floor the
rendered config (Sprint 73.2) stands on.

### Deliverables

- A Haskell `WireGuardPeer` declaration whose lazily generated Dhall projection has a **`SecretRef` name** key
  field — key material is unrepresentable in the external spec (type-foreclosed).
- The Curve25519 peer-key KV secret class: mint a keypair into Vault-KV, and resolve a peer's private/public key
  by `SecretRef` name at render time through the Phase-61 built-in Vault client (no agent sidecar).
- A Haskell-declared inline-key-literal negative with a separately authored Haskell expected tag, paired with
  the positive `SecretRef`-named peer differing only in that dimension; serialized cases are `.build/**` output.

### Validation

1. A minted peer keypair is readable from Vault-KV by `SecretRef` name through the Phase-61 client, and no key
   bytes appear in any tracked source — the external schema field is a `SecretRef` name and any serialized
   Dhall is generated beneath `.build/**`. The inline-key-literal negative fails at
   dhall-typecheck/gadt-decode with the exact separately authored Haskell tag, and its matched positive (same peer, key by `SecretRef`
   name) decodes.
2. A `SecretRef` naming an absent/rotated KV entry yields a specific-reason resolution error (never an empty or
   default key), so the missing-key mutant of the gate (Sprint 73.3) has a defined failure to trip on.

### Remaining Work

The pre-reset `None` claim is permanently invalid; this sprint remains blocked and NOT VALIDATED.

## Sprint 73.2: Rendered peer config + the wg reconcile — render → wg show/diff/wg set ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`network_fabric_doctrine.md §3`](../documents/engineering/network_fabric_doctrine.md#3-keys-config-and-distribution--wireguard-as-just-another-reconcile)
and [`§4`](../documents/engineering/network_fabric_doctrine.md#4-topology-the-hub-is-the-gateway-role-and-the-fabric-moves-with-it):
render each peer config purely and totally from the node inventory (VPN IPs drawn from disjoint per-cluster
ranges, the hub keyed by the gateway role), and distribute it as the control-plane daemon's ordinary `wg show → diff →
wg set` reconcile — no Netmaker agent, no side channel.

### Deliverables

- The pure total `render(nodeInventory) -> [WireGuardPeerConfig]`: keyless peer type-foreclosed; overlapping VPN
  IPs and out-of-fabric-CIDR `AllowedIPs` decode-foreclosed (a total fold returning `Left`); each peer's key a
  `SecretRef` name resolved from Vault-KV (Sprint 73.1). The gateway-role hub renders a stable hub VPN-IP +
  `Endpoint`; VPN-IP allocation is disjoint-per-cluster (confluent by construction).
- A separately authored Haskell peer-config expectation containing `SecretRef` names rather than key bytes.
  The golden transport is generated lazily beneath `.build/test-corpora/network_fabric_wireguard/**` and the
  render is compared with the Haskell expectation.
- The control-plane daemon's `wg` reconcile: `discover` reads live interface state via `wg show`, `diff` against
  `render(inventory)`, `enact` via `wg set` — idempotent, driven only by observed kernel state, with `wg0`-bound
  listeners never bound to `0.0.0.0`/LAN/WAN ([`§5`](../documents/engineering/network_fabric_doctrine.md#5-the-security-boundary-generalizes-localhost--authenticated-fabric)).
- The exact capacity boundary:
  `renderTopology → provision NetworkFabricSystemDemand → validateSnapshot → Either ProvisionError
  ValidatedFabricEnactment`. The raw demand contains finite `maxPacketsPerSecond`, `maxQueuedBytes`, rotated
  log size/count/retention, and a `NetworkFabricCostModelVersion`; expansion must produce exactly one private
  per-node row for every topology node and exactly its rendered peer ids. The cost model derives kernel +
  listener `HostResources { reservation, ceiling }` and nodefs log bytes; missing/extra peers, unlimited
  rate/queue/log state, or a caller-authored fixed aggregate rejects.
- Each private per-node row is charged exactly once as `InfrastructureReserve.NetworkFabric`: it is subtracted
  from effective node/candidate CPU, memory, and layout-routed nodefs before workload placement, while the same
  reserve fits inside the enclosing kind-node/RKE2 runtime. It is not rendered as a pod, included in
  `EngineSystemReserve`, or added again at the physical host. The single-use token binds the expanded graph and
  complete resource/kernel/listener fingerprint, is rechecked immediately before the first effect, and alone
  authorizes the ordered interface/peer/queue/listener reconcile.
- Effective OS controls and readback: the listener process cgroup projects reservation through
  `cpu.weight`/`memory.low` and ceilings through `cpu.max`/`memory.max`; `tc`/interface controls enforce the
  packet-rate and queue-byte bounds that cap modelled kernel work; finite rotation enforces
  `(maxBackups + 1) × maxBytesPerFile` and retention on the witnessed nodefs backing. An independent observer
  reads those cgroup files, qdisc/interface settings, log policy/high-water, listener socket binding, and
  `wg show`, comparing every value with the provisioned row.

### Validation

1. Render the Haskell-declared topology materialized beneath `.build/test-corpora/network_fabric_wireguard/**`
   and compare it with the independent Haskell peer-config expectation. The overlapping-VPN-IP and
   out-of-CIDR-`AllowedIPs` negatives are rejected with their Haskell-declared `DecodeError` tags, each paired with
   a positive differing only in the foreclosed dimension.
2. On the linux-cpu host the reconcile brings `wg0` to the rendered peer set on each node (confirmed by `wg show`
   read from the kernel), and a second reconcile pass issues zero `wg set` mutations (idempotent) — the compute
   path is re-run (not memoized), its `discover` observed to re-read live kernel state before concluding the
   empty diff (§M.6). Before the first pass, compare topology/resource expansion with a separately authored
   Haskell expectation whose JSON projection is generated beneath `.build/test-corpora/**`, then read back the
   listener cgroup, rate/queue controls, log rotation and
   nodefs high-water, interface peers, and socket binding. All identities, reservations, ceilings, bounds, and
   peer sets must equal the admitted row; stress at the declared rate/queue boundary remains inside it.
3. Increase CPU reservation, CPU ceiling, memory reservation, memory ceiling, queue memory, and rotated nodefs
   demand independently by one unit beyond current residual. Remove one topology peer from the expansion and
   change one live commitment after validation. Each case must fail with its pinned reason before the first
   effect, while external `ip monitor`, `wg show`, qdisc/cgroup/log-policy observers and the listener process
   table prove zero interface creation, `wg set`, queue/cgroup/log mutation, listener bind/restart, and nodefs
   writes. The matched fitting case differs only in the reduced field and enacts. Haskell-authored changed-subject mutants that admit
   against the pre-expansion aggregate, reuse a stale token, or double-charge the named reserve must turn this
   validation red.

### Remaining Work

The pre-reset `None` claim is permanently invalid; this sprint remains blocked and NOT VALIDATED.

## Sprint 73.3: Phase gate harness — live fabric + external-observer reachability over the VPN IP ⏸️

**Status**: Blocked — NOT VALIDATED

### Objective

Adopt [`network_fabric_doctrine.md §2`](../documents/engineering/network_fabric_doctrine.md#2-raw-wireguard-not-netmaker)–[`§5`](../documents/engineering/network_fabric_doctrine.md#5-the-security-boundary-generalizes-localhost--authenticated-fabric):
assemble the phase's single live acceptance gate — the control-plane daemon renders each peer config from Vault-KV
Curve25519 keys (secrets by name) and reconciles raw-kernel WireGuard so every peer draws its VPN IP from the
gateway-role hub and the hub is reachable across the fabric — and prove that reach with an external-observer
probe over the VPN IP, not a self-report.

### Deliverables

- The positive gate: a Haskell-declared two-peer fabric, lazily rendered beneath
  `.build/test-corpora/network_fabric_wireguard/**`, compared with independent Haskell peer-config and demand
  expectations, admitted through
  `ValidatedFabricEnactment`, and reconciled onto real `wg0` interfaces; its OS-enforced per-node
  CPU/memory/rate/queue/log controls read back exactly, the spoke→hub reachability probe is green over the hub
  VPN-IP, and teardown is leak-free — expressed as a Haskell test-topology declaration with a teardown
  obligation; any Dhall transport is rendered lazily beneath `.build/**` and remains untracked.
- The negative regression guard: the Haskell inline-key-literal (secrets-in-Dhall), overlapping-VPN-IP, and
  out-of-CIDR-`AllowedIPs` cases re-run against the same render entry point, each failing at dhall-typecheck/gadt-decode
  with its foreclosure tag equal to an independently authored Haskell oracle. Its reproducible TSV view is
  generated lazily at `.build/test-corpora/network_fabric_wireguard/negative-expected-tags.tsv` and remains
  untracked (§M.3/§M.8); each is paired with a positive differing only in
  the foreclosed dimension.
- **Haskell-authored changed-subject mutation operators (§M.2):** `missing-peer-key` (the spoke's
  `SecretRef` resolves to no live Vault-KV entry — `wg0` never comes up, the probe fails red) and
  `hub-no-endpoint` (the hub-role config omits its `Endpoint` and the probe fails red). Reviewed Haskell
  mutation intent is applied to production source; any patch representation is generated lazily beneath
  `.build/test-mutants/network_fabric_wireguard/**` and remains untracked.
- The independently reviewed Haskell oracle bundle declares the topology, peer config, demand, reachability,
  and negative tags before implementation. Dhall, golden, JSON, and TSV projections are generated lazily
  beneath `.build/test-corpora/network_fabric_wireguard/**` and carry no independent authority.
- The pre-effect negative bundle: CPU reservation/ceiling, memory reservation/ceiling, queue-state memory, and
  rotated nodefs demand each exceed the current residual by exactly one unit; an expansion omits one rendered
  peer; and a validated fingerprint changes before enactment. Each must return its Haskell-declared specific reason
  and an external observer must prove zero interface/peer/qdisc/cgroup/log/listener effects.
- A **Register-3** proven/tested/assumed ledger recording the live-reachability result (the spoke reached the
  hub over the VPN IP) and marking the deferred / out-of-register surfaces UNVERIFIED: the cross-cluster
  **broker↔broker** geo-replication render obligation (Phase 74), the **gateway-migration hub repoint**
  (Phase 75), and the stretched kubelet↔apiserver `ControlPlanePeer` span (owned by cluster_topology). The
  ledger marks the runtime tunnel and resource-control/readback layers **tested**, never *proven*; the
  keyless-peer (type-foreclosed) and
  overlapping-IP / out-of-CIDR (decode-foreclosed) layers may be recorded as proven-for-model only after the
  corresponding predecessor model gates are human-approved in the
  pre-cluster band.

### Validation

1. The harness stands the two-peer fabric — the gateway-role hub and one spoke, each in its own Linux network
   namespace on the linux-cpu host from the Haskell-declared topology. The control-plane daemon's config and
   capacity expansion equal the independent Haskell expectations; the provisioned node/peer rows exactly
   cover the topology; and the current-residual fingerprint yields one `ValidatedFabricEnactment`. It reconciles
   `wg0` on both peers; the spoke's external-observer probe reaches the hub at its VPN-IP matching
   a separately authored Haskell reachability predicate (an OS-level ICMP echo and TCP connect from the spoke
   netns succeed, an underlay `tcpdump` capture shows WireGuard UDP and never cleartext application bytes, and
   effective peer state is read from `wg show` — the kernel, never a control-plane daemon self-report — §M.5). Read back
   CPU/memory cgroup controls, packet-rate/queue bounds, rotated-log policy
   and nodefs high-water, listener bind, and peer graph exactly; the `missing-peer-key` and `hub-no-endpoint`
   mutants each turn this red.
2. Every Haskell-declared negative, generated beneath `.build/**` and submitted through the same render entry
   the positive used, is rejected at dhall-typecheck/gadt-decode with its emitted tag equal to the independent
   Haskell oracle (secrets-in-Dhall foreclosed,
   overlapping IPs and out-of-CIDR `AllowedIPs` decode-foreclosed); the positives decode. Teardown tears `wg0`
   down on each node and leaks no interface, peer, cgroup, qdisc, or log allocation. The **Register-3**
   proven/tested/assumed ledger the run emits names the live linux-cpu substrate and honestly classifies each
   layer (no deferred surface — broker↔broker geo-replication, the gateway-migration repoint — reported as
   proven, and the runtime tunnel marked *tested*, not *proven*).
3. Run every one-unit overdraw, omitted-peer, and changed-fingerprint fixture through the same live admission
   boundary. Assert its exact independently authored Haskell reason and use `ip monitor`, `wg show`, cgroup/qdisc/log-policy
   readback, listener process/socket observation, and nodefs byte accounting to prove zero fabric effects.
   Re-run the fitting control and require enactment. A mutant that calls `ip link`, `wg set`, or binds/restarts
   the listener before consuming a freshly rechecked token must turn the gate red.

### Remaining Work

The pre-reset `None` claim is permanently invalid; this sprint remains blocked and NOT VALIDATED. The Phase-74/54 and stretched-control-plane surfaces named above remain UNVERIFIED.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/network_fabric_doctrine.md` — the §2–§5 "Phase 0 design intent" honesty note flips from
  design intent to a delivered raw-kernel WireGuard fabric with its Register-3 ledger attached: the rendered
  peer config, the `wg show → diff → wg set` reconcile, the Vault-KV Curve25519 key custody, and the
  localhost→fabric listener boundary are live on linux-cpu; the broker↔broker geo-replication render and the
  gateway-migration hub repoint remain deferred (Phase 75).
- `documents/engineering/vault_pki_doctrine.md` — record that WireGuard peer keys landed as a Vault-KV
  Curve25519 secret class named by `SecretRef` (not PKI certs, not an unseal gate), minted and parent-injected.
- `documents/engineering/manifest_generation_doctrine.md` — record that the peer config is a pure-`render()`
  product reconciled by the control-plane daemon like any other manifest, with keyless / overlapping-IP peers foreclosed.
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (runtime
  tunnel and resource-control/readback *tested*; broker↔broker geo-replication and gateway-migration repoint
  UNVERIFIED).
- `documents/engineering/resource_capacity_doctrine.md` — record the live producer/consumer evidence for the
  topology-expanded `NetworkFabricSystemDemand`, named infrastructure-reserve debit, snapshot token, and OS
  control readback without changing its pure contract.

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — add the Phase-73 row and flip its status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — add the Phase-73 linux-cpu gate row (the raw-kernel WireGuard fabric).
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Fabric/{Keys,WgRender,WgReconcile}.hs` as
  Phase-73 design-first rows against `network_fabric_doctrine.md`.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (the network fabric)
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map (the linux-cpu gate row)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Network Fabric Doctrine](../documents/engineering/network_fabric_doctrine.md) — raw-kernel WireGuard, the
  Vault-KV Curve25519 peer keys, the rendered-config reconcile, and the hub = gateway-role topology
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md) — the KV secret class the peer keys are
  custodied as, named by `SecretRef`
- [Manifest Generation Doctrine](../documents/engineering/manifest_generation_doctrine.md) — the pure `render()`
  discipline the peer config reuses
- [Resource Capacity Doctrine](../documents/engineering/resource_capacity_doctrine.md) — the pure fabric-system
  demand, topology expansion, one-time named reserve debit, and pre-effect admission contract
- [phase_61](phase_61_vault_pki.md) — the root Vault + `SecretRef`-by-name client custodying the peer keys
- [phase_65](phase_65_live_dsl_deploy.md) — the control-plane daemon whose reconcile enacts the fabric
- [phase_74](phase_74_multicluster_spawn_georepl.md) — multi-cluster spawn + geo-replication (the deferred broker↔broker per-peer render obligation)
- [phase_75](phase_75_gateway_migration_drills.md) — the gateway migration that later repoints the WireGuard hub
