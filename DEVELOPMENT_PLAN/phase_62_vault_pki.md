# Phase 62: Root Vault + PKI + built-in Haskell Vault client

> **Purpose**: Stand up the root single-node password-encrypted Vault as the fail-closed secrets root, root its
> self-signed PKI trust anchor, and prove the Vault client compiled *into* the amoebius binary (no agent sidecar)
> reads a `SecretRef` by name — the secrets floor the standard-service stack is built on.
> **Read this if**: phase 62 is next in the queue, or a later phase depends on what its gate establishes.

This document specifies a target capability only. Any pre-reset implementation result, pass, seal, receipt,
command transcript, or evidence reference retained below is historical inventory only: it is permanently
non-operative, cannot satisfy any current contract, and cannot regain authority through a status edit. Current
status is owned by [the tracker](README.md) and the Phase Status block below.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_26_dhall_schema_generation.md, DEVELOPMENT_PLAN/phase_27_gadt_decode_ir.md, DEVELOPMENT_PLAN/phase_61_retained_storage.md, DEVELOPMENT_PLAN/phase_63_platform_backbone.md, DEVELOPMENT_PLAN/phase_64_platform_services_2.md, DEVELOPMENT_PLAN/phase_66_live_dsl_deploy.md, DEVELOPMENT_PLAN/phase_74_network_fabric_wireguard.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/vault_pki_doctrine.md
**Generated sections**: none

</details>

## Contents

- [Phase Status](#phase-status)
- [Phase Summary](#phase-summary)
- [Gate integrity](#gate-integrity)
- [Resource provision — UNRESOLVED](#resource-provision--unresolved)
- [Doctrine adopted](#doctrine-adopted)
- [Sprints](#sprints)
- [Sprint 62.1: Root single-node password-encrypted Vault — init-once / unseal-on-rebuild ⏸️](#sprint-621-root-single-node-password-encrypted-vault--init-once--unseal-on-rebuild-)
- [Sprint 62.2: The self-signed PKI trust anchor issues ⏸️](#sprint-622-the-self-signed-pki-trust-anchor-issues-)
- [Sprint 62.3: Built-in Haskell Vault client (no agent sidecar) reads a `SecretRef` by name — the gate ⏸️](#sprint-623-built-in-haskell-vault-client-no-agent-sidecar-reads-a-secretref-by-name--the-gate-)
- [Sprint 62.4: Register-2.5 fail-closed Vault unseal under simulated faults ⏸️](#sprint-624-register-25-fail-closed-vault-unseal-under-simulated-faults-)
- [Documentation Requirements](#documentation-requirements)
- [Related Documents](#related-documents)

---

## Phase Status

⏸️ Blocked — NOT VALIDATED.

Blocked by redesigned Phase 61, its independent validation, and human promotion; every earlier
promotion barrier must also be satisfied in numerical order. Every prior pass, seal, receipt, attestation,
completion claim, and implementation result in this document is invalidated as validation evidence, even
where historical prose has not yet been rewritten. Existing implementation is an **Observed footprint /
Known partial** only.

Hardware validation is also prohibited until the hardware-free DSL promotion barrier is independently
satisfied and human-approved.

> **Reset contract interpretation.** The phase-specific gate review below is REJECTED — NOT VALIDATED. Until Phase 0 Sprint 0.7 replaces every unresolved row and a human independently reviews it, the summary and work breakdown are a capability inventory, not executable authority. Any wording that prescribes tracked non-`.hs` behavioural source, a Python/shell verdict, repository-retained generated behavioral transport material, `pb` behavior outside its minimal-platform-discrimination/contained-toolchain-establishment/source-bound-build/opaque-exec grammar, or host/hardware validation before the Phase-50 barrier is invalidated and non-operative.

## Phase Summary

This phase's target is the **secrets root** every later phase depends on. Its gate must bring up the **root Vault** as a
single-node, Shamir-sealed, password-encrypted, human-gated, **fail-closed** service whose first-ever `vault
init` runs exactly once against an empty retained PV and whose every later bring-up only **unseals** the same
durable data — never a re-init, never a key regeneration. The one-and-only ephemeral secret is the operator's
memorized password, which decrypts (via a real Argon2id KDF feeding an AEAD, never raw SHA-256) the
password-sealed unlock material that recovers the Shamir keys; it is supplied at the prompt and persisted
nowhere. The unsealed Vault owns the forest's **one self-signed PKI trust anchor** — a `pki/` root CA that issues
internal leaf certificates that chain back to it. Finally, the gate must test the **built-in Haskell Vault client**:
the client is linked directly into the amoebius binary, so an in-cluster consumer authenticates to Vault with its
Kubernetes service-account JWT and resolves a `SecretRef` by name — **no HashiCorp Vault Agent sidecar**, no
Secret-mounted plaintext, no environment variable, no `PATH` lookup. A sealed, uninitialized, policy-missing, or
secret-missing read returns a typed, fail-closed error that carries no secret material. Its retained state is
not an arbitrary PVC: a canonical `VaultStorageDemand` is derived from finite declared KV/Transit/PKI/auth
populations, value/key/certificate sizes, version histories, revocations, and active/expired leases. A
version-pinned Raft model adds WAL, snapshot, old+new compaction overlap, and restart/recovery headroom; each
Raft target names its claim/backing and `VolumePresentation`. A separate finite rotated file-audit demand
selects either a bounded pod-ephemeral volume or a retained claim/backing/presentation. Only the resulting private
`ProvisionedVaultStorageDemand` can reach rendering, and its exact durable and audit capacities are enforced.
The Vault app and every init/rotation execution unit are likewise rendered only from the enclosing opaque
`ProvisionedServiceSpec`: explicit CPU, memory, and `ephemeral-storage` requests/limits, bounded pod-local
volumes and writable/log allowances, durable/audit backings as above, cache `None`, and accelerator `None` on
linux-cpu.

What this phase deliberately does **not** do: the full standard-service stack that consumes these secrets
(Phases 63–64), the Keycloak-owned edge (Phase 65), and the parent/child unseal modes, parent secret injection, and the
cross-cluster intermediate-CA hierarchy (the amoebic-spawning/federation phases). Only the root cluster's own
single-node Vault, its self-signed anchor, and the in-cluster read path are in scope here.

**Phase scope:** one cohesive claim — *secrets have a fail-closed root, and the client that reads them is compiled in rather than run beside*. No agent sidecar is a security claim, not a packaging preference.

**Substrate:** `linux-cpu` — this lane is available on every hardware substrate. The future gate is restricted
to the local Linux CPU-only lane. When a pristine Linux host is required, use Incus on Linux or Linux-CUDA, Lima
on Apple, and WSL2 on Windows.

**Lane:** linux-cpu/amd64 ([§L](development_plan_standards.md#l-one-substrate-discipline))

**Register:** 3 — live infrastructure ([§K](development_plan_standards.md#k-honesty-proven--tested--assumed)).

**Depends on:** [Phase 61](phase_61_retained_storage.md)
**Gate:** `pb validate phase 62`; see [Gate integrity](#gate-integrity). NOT VALIDATED.

## Gate integrity

**Contract review**: REJECTED — NOT VALIDATED.

| Key | Contract |
|---|---|
| `Claim` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: one cohesive claim — *secrets have a fail-closed root, and the client that reads them is compiled in rather than run beside*. No agent sidecar is a security claim, not a packaging preference. Explicit exclusions: every layer named in `Residue` remains UNVERIFIED. |
| `Subject` | UNRESOLVED — blocks validation: no production `.hs` module and entry point have been independently established for this reset contract. |
| `Command` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `pb validate phase 62` is the target command only; `pb` may only make the minimal platform distinction, establish the contained toolchain, build the source-bound binary, and exec it with argv unchanged, while the Haskell verdict entry point remains UNRESOLVED and blocks validation. |
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
| `Predecessor` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: Exact external `ImmediatePredecessorApproval` for Phase 61; candidate execution separately refuses an absent, stale, replayed, or locally shaped receipt. |
| `Residue` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: UNVERIFIED — the entire phase claim and all semantic, effect, runtime, hardware, and cleanup layers remain unvalidated; no empty residue is asserted. |
| `Human authority` | UNRESOLVED — blocks validation: typed semantic payload and reviewer custody missing; prior prose: `human-only` — no agent, gate, CI job, digest, receipt-shaped file, or generated assertion may promote status. |

## Resource provision — UNRESOLVED

> **UNRESOLVED — blocks validation.** No live mutation is authorized. Before review this phase must name its exact owner marker, preflight, allowed and forbidden mutations, external observer, scoped cleanup, and zero-owned-residue criterion. The reset inventory below cannot supply that contract.

## Doctrine adopted

- [`extension_conformance_security.md` §4 — S1–S6](../documents/engineering/extension_conformance_security.md#4-s1s6) — root Vault + PKI + built-in Haskell Vault client carries an identity boundary, and S1-S6 are what make crossing it unrepresentable.
- [`vault_pki_doctrine.md` §5 — The root cluster: single-node, password-encrypted unseal](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal)
  — *the root cluster: single-node, password-encrypted unseal*: the root's single-node shape lets it bootstrap
  with zero secrets, so the only secret standing up its Vault is the one a human types; the unlock material is
  password-AEAD-sealed (Argon2id → ChaCha20-Poly1305/AES-256-GCM), **never** raw SHA-256, and never plaintext at
  rest. The prodbox password-encrypted root unseal is **sibling evidence, not an amoebius result**.
- [`vault_pki_doctrine.md` §4 — Init follows readiness: fail-closed Vault init](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init)
  — *init follows readiness: fail-closed Vault init*: **init-once / unseal-on-rebuild** — `vault init` runs exactly
  once when the retained PV is empty, and every later bring-up only unseals; a rebuilt cluster is *not* a fresh
  Vault.
- [`vault_pki_doctrine.md` §2 — Vault is the fail-closed secrets root](../documents/engineering/vault_pki_doctrine.md#2-vault-is-the-fail-closed-secrets-root)
  — *Vault is the fail-closed secrets root*: a sealed Vault **bricks** the cluster; the sole-backend and
  no-degraded-leak invariants mean no secret reconstructs from any non-Vault source and secret-dependent Pod
  startup fails its readiness gate.
- [`vault_pki_doctrine.md` §8 — The root cluster owns the PKI trust anchor](../documents/engineering/vault_pki_doctrine.md#8-the-root-cluster-owns-the-pki-trust-anchor)
  — *the root cluster owns the PKI trust anchor*: exactly one self-signed root of trust, the Vault `pki/` root CA,
  with internal certs chaining to it; this phase's target must build **plane 1 (internal PKI) only** — public-edge TLS (Phase
  25) and the cross-cluster intermediate-CA hierarchy (federation) are deferred and **live-proof-pending even in prodbox**.
- [`vault_pki_doctrine.md` §9 — In-cluster consumers authenticate to Vault directly](../documents/engineering/vault_pki_doctrine.md#9-in-cluster-consumers-authenticate-to-vault-directly)
  and [`vault_pki_doctrine.md` §3 — The SecretRef contract: a name, never a value](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value) —
  *in-cluster consumers authenticate to Vault directly* and *the SecretRef contract, a name never a value*: the
  built-in client authenticates per consumer via Vault Kubernetes auth (service account → role → least-privilege
  policy → JWT) and resolves a `SecretRef.Vault { mount, path, field }` by name — no Secret-mounted plaintext, no
  env var, no `PATH`, and no agent sidecar (the `Prodbox.Vault.Client` shape as **sibling evidence**).
- [`vault_pki_doctrine.md` §11 — Error model and no-leak logging](../documents/engineering/vault_pki_doctrine.md#11-error-model-and-no-leak-logging)
  — *error model and no-leak logging*: Vault failures are ordinary typed control flow (unavailable / uninitialized
  / sealed / policy-missing / secret-missing / decrypt-denied) that let a caller fail closed with an actionable,
  non-leaking message; a log line never emits a resolved value, a token, or a presence oracle.
- [`platform_services_doctrine.md` §11 — Bring-up and dependency ordering](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
  — *bring-up and dependency ordering*: the hard edge this phase's target must install — **Vault reachable,
  initialized, and unsealed before any secret-dependent startup** — as a witnessed readiness gate, never a timer.
- [`resource_capacity_doctrine.md` §5 — `StorageBudget`: bounded by construction, single-owner ceiling per arm](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm) — *`StorageBudget`: bounded by construction, single-owner ceiling per arm*: the canonical
  `VaultStorageDemand` and private `ProvisionedVaultStorageDemand` — every persisted source population and
  history is finite, the version-pinned Raft model includes WAL/snapshot/compaction/recovery peaks, and the
  file audit device has a named backing/presentation with finite rotation. A raw demand cannot author its own physical
  bytes, and neither renderer nor reconciler accepts an unprovisioned Vault storage value.

## Sprints

> **Reset validation review.** Every pre-reset `Independent Validation` and `### Validation` below is rejected as a current criterion and MUST NOT be executed or cited. It is retained only to inventory the capability while the fixed Haskell subject/oracle/reviewer/mutant/legacy contract is rewritten.

## Sprint 62.1: Root single-node password-encrypted Vault — init-once / unseal-on-rebuild ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: [Phase 61](phase_61_retained_storage.md) human approval
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`vault_pki_doctrine.md §5`](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal),
[`§4`](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init), and
[`§2`](../documents/engineering/vault_pki_doctrine.md#2-vault-is-the-fail-closed-secrets-root): bring up the
single-node, password-encrypted, human-gated, fail-closed secrets root, init-once and unseal-on-rebuild, on the
retained PV — the prodbox root-unseal shape as **sibling evidence, not an amoebius result**.

### Deliverables

- Root Vault in **Shamir seal mode**, rendered and reconciled onto the Phase-61 retained PV; first-ever `vault
  init` runs only when the PV is empty, and every later bring-up redeploys against existing data and only
  unseals. The PVC/PV claim slot, backing, presentation, required usable bytes, and rounded provisioned
  capacity are exact projections of the private
  `ProvisionedVaultStorageDemand`, never a hand-authored storage constant.
- A canonical `VaultStorageDemand` derived from the complete bounded persisted source sets: maximum KV secrets,
  value/path/envelope bytes and retained versions; Transit keys and retained versions; PKI roots/roles,
  certificates, revocations and leases; Kubernetes-auth roles/policies; and active plus retained-expired lease
  records. The version-pinned Raft cost fold accounts for resident records/metadata, WAL, snapshots,
  simultaneous old+new bytes during compaction, and restart/recovery headroom. Binding fits that peak to the
  named retained claim/backing/presentation, applies filesystem overhead and backing allocation quantum, and
  alone constructs `ProvisionedVaultStorageDemand`; no unbounded population,
  ignored history, or raw physical-byte override exists.
- A separate finite file-audit demand within that provision names either its pod-ephemeral volume or retained
  claim/backing/presentation and declares enforceable
  per-file maximum bytes, backup count, and retention. Rendering mounts exactly that backing, enables Vault's
  file audit device at the provisioned path, and installs the derived rotation/sweeper limits; audit files
  cannot spill into an unbounded container writable layer or borrow the Raft claim implicitly.
- The complete Vault pod projection: every app/init/rotation container has the exact checked CPU, memory, and
  `ephemeral-storage` request/limit; each pod-local volume and private writable/log allowance is bounded and
  covered; the durable and audit mounts come only from the storage provision; and cache/accelerator are
  explicitly `None` for the linux-cpu gate.
- **Password-sealed unlock material**: the first init's unseal/recovery keys + initial root token captured once
  and immediately sealed under the operator's password with a real KDF (**Argon2id**) feeding an AEAD
  (ChaCha20-Poly1305 / AES-256-GCM) — **never raw SHA-256**; the password memorized, entered at the prompt on
  init and every unseal, persisted nowhere; raw keys never printed.
- A **pluggable unlock-material backend** behind one interface — the load-bearing property is only that the
  material is password-AEAD-sealed and never plaintext at rest. **At the root Phase-62 bring-up the backend is a
  host-side encrypted runtime file outside the repository**: MinIO does not exist until Phase 63, so a MinIO-sealed object (and equally a cloud
  KMS or TPM/YubiKey identity) is a *later* backend option, never a root-unseal prerequisite — the root Vault
  must not depend on a platform service it precedes (no Vault↔MinIO bootstrap cycle).
- **Fail-closed ordering**: no secret-dependent workload runs before Vault reports reachable, initialized, and
  unsealed; a consumer reaching a sealed Vault fails closed.
- **Haskell changed-production-subject mutants (§M.2)**, re-run on every candidate, each MUST turn Validation red: (i) a
  *dropped-guard* mutant of `Unseal.hs` that re-runs `vault operator init` on rebuild instead of unsealing existing
  data (must fail the canary-identity and already-initialized checks); (ii) an *effect-swap* mutant of `Seal.hs`
  that seals the unlock material with raw `SHA-256(password)`-keyed obfuscation instead of the Argon2id→AEAD
  envelope (must fail the envelope-format and wrong-password checks); (iii) a *storage-term deletion* mutant
  that omits Raft old+new compaction/recovery headroom or renders a one-byte-smaller PVC (must fail the
  independently authored Haskell peak expectation before apply); and (iv) an *unbounded-audit* mutant that drops the backup/retention
  limits or points the audit path outside its named backing (must fail render identity and the live cap probe).

### Validation

1. **Init-once / unseal-on-rebuild witness (forecloses wipe-and-re-init).** On an empty PV, run init; write
   Haskell-declared run-unique canary bytes into Vault and record (i) the canary value read back and
   (ii) the SHA-256 digest of the at-rest unlock-material ciphertext. Then delete + recreate the cluster and assert:
   (a) the canary reads back **byte-identical** to the independently retained run-local expectation (proves the same durable data, not a fresh
   Vault); (b) the unlock-material ciphertext digest is **unchanged** (no key regeneration); (c) a `vault operator
   init` attempt against the recreated cluster returns **already-initialized**; and (d) the Vault audit device
   records an **unseal** operation and **no** init operation on the rebuild.
2. **Password-crypto witness (forecloses fake/plaintext sealing).** Assert: (a) the at-rest unlock file parses
   according to a separately authored Haskell envelope expectation with its Argon2id `m/t/p` parameters and AEAD
   algorithm identifier matching that expectation; (b) an unseal attempt with a **wrong password** fails closed and yields
   no key material (paired positive: the correct password unseals — the two runs differ only in the password,
   §M.8); (c) a Haskell byte scanner over the unlock file, the PV bytes, stdout/stderr, and every bring-up
   artifact finds **none**
   of the raw unseal keys and **not** the root token.
3. **Fail-closed ordering (named workload, paired positive).** Deploy the named canary consumer pod
   (`vault-canary-consumer`, a workload whose sole readiness dependency is reading the canary `SecretRef.Vault`)
   against a **sealed** Vault and assert it **never reports Ready**, its container surfaces the typed `sealed`
   error (not an image-pull or unrelated failure — the same image pulls and starts, only the read fails), and no
   plaintext value is present anywhere in its pod filesystem or env. **Paired positive (§M.8):** after unseal, the
   **same** pod reports Ready and reads the canary value — the two runs differ only in Vault's seal state.
4. **Password-persistence scope (disambiguated).** Assert the operator password is the sole human-supplied secret
   and appears in **none** of the following explicitly enumerated stores: the Vault pod filesystem and mounted
   volumes, the host filesystem under the retained-PV mount, the raw PV block bytes, every container's environment
   block (`/proc/<pid>/environ`), the reconciler and Vault logs, and the bring-up shell history — a Haskell byte
   scan for
   the password string over exactly this set, no broader and no narrower.
5. **Pure storage-boundary and zero-effects witness.** Independently rederive the durable usable peak from the declared
   KV/Transit/PKI/auth populations, histories, leases, and pinned Raft model. Supply a retained backing or
   mounted target exactly one usable byte below the resident + WAL + snapshot + old/new compaction + recovery
   peak and require typed rejection before rendering/apply; separately make the raw backing one allocation
   quantum below the private rounded requirement, and repeat those boundaries for retained audit (or one byte
   below its pod-ephemeral volume arm). In every case,
   apiserver audit, retained-backing, and host filesystem observers record zero object/allocation/file effects.
   The paired exact-fit values produce the private `ProvisionedVaultStorageDemand`; applied PVC/PV claim slot,
   backing, presentation, rounded capacity, mounted usable bytes, audit arm/mount/path, and rotation settings
   read back byte-identical to it. The same readback
   compares every Vault app/init/rotation CPU, memory, and `ephemeral-storage` request/limit, bounded pod-local
   volume, writable/log allowance, cache `None`, and accelerator `None` to the enclosing opaque
   `ProvisionedServiceSpec`; presence-only checks are insufficient.
6. **Live Raft/audit high-water witness.** Populate the bounded Haskell test corpus through its declared retained
   versions, certificate/revocation and lease histories; force a Raft snapshot and compaction while observing
   simultaneous old+new files, then restart at that boundary and observe WAL replay/recovery. The mounted
   filesystem high-water must stay within the usable provision and the raw device within
   `provisionedBytes`. Generate audited operations through more
   than one file boundary, wait through the declared retention boundary, and assert active-file size, retained
   backup count/age, and total audit-backing high-water stay within the provision; no audit byte appears outside
   the named mount. The storage-term-deletion and unbounded-audit mutants must turn these live checks red.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 62.2: The self-signed PKI trust anchor issues ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 62.1
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`vault_pki_doctrine.md §8`](../documents/engineering/vault_pki_doctrine.md#8-the-root-cluster-owns-the-pki-trust-anchor):
make the root Vault's `pki/` engine the one self-signed trust anchor for the forest, building **plane 1 (internal PKI) only** — public-edge TLS and the cross-cluster intermediate-CA hierarchy are explicitly out of scope here.

### Deliverables

- The Vault `pki/` engine holding a **self-signed root CA** as the single forest trust anchor.
- Internal-leaf issuance from `pki/` for in-cluster service-to-service TLS, every issued cert chaining back to the
  root anchor.
- The **three-planes distinction** recorded and enforced: internal PKI (this phase) is not public-edge TLS
  (ZeroSSL/route53, Phase 65) and is not the distro's own self-signed cluster CA (the chicken-and-egg floor,
  [`vault_pki_doctrine.md §10`](../documents/engineering/vault_pki_doctrine.md#10-the-chicken-and-egg-floor-what-stays-outside-vault));
  the cross-cluster intermediate-CA hierarchy is deferred to federation and flagged **live-proof-pending**.
- **Haskell changed-production-subject mutants (§M.2)**, re-run on every candidate, each MUST turn Validation red: (i) a *dropped-guard*
  mutant of `Pki.hs` that issues an internal leaf while Vault is **sealed** instead of failing closed (must fail
  the sealed-issuance check); and (ii) an *effect-swap* mutant of `Pki.hs` that returns a leaf signed by an
  unrelated key so it does **not** chain back to the self-signed root CA (must fail the chain-verify check).

### Validation

1. Assert `pki/` holds a self-signed root CA after bring-up.
2. Issue an internal leaf cert from `pki/` and assert it chains to the self-signed root CA.
3. Seal Vault and assert issuance fails closed with the typed **`sealed`** reason (no certificate is produced) —
   the run differing only in seal state from item 2's successful unsealed issuance (§M.8).

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 62.3: Built-in Haskell Vault client (no agent sidecar) reads a `SecretRef` by name — the gate ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 62.2
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`vault_pki_doctrine.md §9`](../documents/engineering/vault_pki_doctrine.md#9-in-cluster-consumers-authenticate-to-vault-directly),
[`§3`](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value), and
[`§11`](../documents/engineering/vault_pki_doctrine.md#11-error-model-and-no-leak-logging): prove the one
in-cluster secret-delivery path — a workload authenticating directly to Vault and reading a `SecretRef` by name
through the **built-in** client, with a typed, no-leak error model. The `Prodbox.Vault.Client` lineage is
**sibling evidence, not an amoebius result**.

### Deliverables

- **`src/Amoebius/Vault/Client.hs`**: the Vault client compiled directly into the amoebius binary — **no HashiCorp Vault Agent sidecar**, no Secret-mounted plaintext, no environment variable, no `PATH` lookup;
  in-cluster reads authenticate via **Vault Kubernetes auth** (service account → Vault role → least-privilege
  policy → service-account JWT), so a leaked grant is contained to one consumer's paths.
- **`SecretRef` resolution by name**: a `SecretRef.Vault { mount, path, field }` resolves to its KV bytes and a
  `TransitKey` to an unwrap; a secret is generated/minted **once** into Vault and fetched by each consumer — no
  chart template generates or stores a value, and there is no seed to derive from.
- **The typed error type** (`unavailable` / `uninitialized` / `sealed` / `policy-missing` / `secret-missing` /
  `decrypt-denied`) as ordinary control flow so a caller fails closed with an actionable, non-leaking message; the
  **no-leak logging** rule (redacted structured logs, no resolved value, no token, no presence oracle).
- A **Register-3** proven/tested/assumed ledger naming the live substrate; the cross-cluster intermediate-CA
  hierarchy, parent/child unseal, and parent secret injection are explicitly left UNVERIFIED (owned by the
  federation phases), never marked green.
- **Haskell changed-production-subject mutants (§M.2)**, re-run on every candidate, each MUST turn Validation red: (i) a
  *dropped-effect* mutant of `Client.hs` that reads a token from a mounted file / env var instead of performing
  `auth/kubernetes/login` (must fail the audit-device login-provenance check and the role-deletion negative);
  (ii) a *guard-weakening* mutant of `Error.hs` that folds `secret-missing` and `sealed` into one tag or logs the
  requested path (must fail the error-tag table and the presence-oracle checks).

### Validation

1. **K8s-auth provenance witness (forecloses image-baked token).** A consumer authenticates via Vault Kubernetes
   auth and reads the canary `SecretRef.Vault`-named KV secret, getting **byte-identical** the independently
   generated run-unique value held by the external observer; the **Vault audit device** records the read ran under a token minted by
   `auth/kubernetes/login` bound to the consumer's exact namespace + service account. Then **delete the Vault role (or the service account)** and assert the same read now fails with the typed `policy-missing`/denied error —
   proving the login actually occurs rather than a pre-minted token. Assert the pod has no agent sidecar and no
   plaintext Secret mount (read from the argv/exec observer and the pod spec, §M.5).
2. **Typed negatives + presence-oracle absence (disambiguated).** A read of a path outside the consumer's policy
   is denied; the representative `TransitKey` unwrap is exercised — its positive unwrap succeeds, and a
   policy-denied unwrap yields the typed **`decrypt-denied`** tag; a read against an unreachable Vault (no
   listener) yields the typed **`unavailable`** tag; and each of the sealed / uninitialized / policy-missing /
   secret-missing / unavailable / decrypt-denied reads returns **its specific tag from a separately authored
   Haskell error-tag expectation** (§M.8 — each negative asserts *why* it failed, paired with the
   positive canary read or unwrap that differs only in the foreclosed dimension), so all six error tags and the
   one `TransitKey` unwrap in the representative set (§M.7) are gated here. **Presence-oracle absence is
   operationally defined:** the emitted log line for `secret-missing`, `policy-missing`, and `sealed` must be
   **byte-identical except for the typed tag itself** (so log shape reveals nothing about whether a path/secret
   exists), and a Haskell scanner over the complete Vault-audit and consumer structured-log observations finds
   **none** of: the requested mount/path, the resolved value, and the auth token.
3. Emit the Register-3 ledger; assert the deferred federation surfaces are recorded UNVERIFIED, not green.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Sprint 62.4: Register-2.5 fail-closed Vault unseal under simulated faults ⏸️

**Status**: Blocked — NOT VALIDATED
**Implementation**: UNRESOLVED — blocks validation: the authored Haskell implementation path has not been established.
**Blocked by**: Sprint 62.3
**Independent Validation**: UNRESOLVED — blocks validation: no falsifiable positive control, paired specific-reason negative, changed-subject mutant, and residue seam has been established.
**Oracle**: UNRESOLVED — blocks validation: no separate Haskell oracle, independence boundary, and human reviewer have been established.
**Legacy IDs**: UNRESOLVED — blocks validation: typed Haskell legacy bindings have not been reconciled for this sprint.
**Docs to update**: UNRESOLVED — blocks validation: governed doctrine owners have not been established for this sprint.

### Objective

Adopt [`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md) and
re-adopt [`vault_pki_doctrine.md §2`](../documents/engineering/vault_pki_doctrine.md#2-vault-is-the-fail-closed-secrets-root):
prove the **fail-closed secrets-root invariant in simulation** — run the real init/unseal client against the
modeled fault-injectable Vault under `IOSim`/`IOSimPOR` and assert that no adversarial fault schedule (sealed,
unreachable, lease-expiry, restart) ever lets the daemon proceed while Vault is sealed or its freshness is
unproven. This is a **Register-2.5** deterministic-simulation check, run in-process **before** the Sprint-55.3
Register-3 live gate — not a substitute for it.

### Deliverables

- An `IOSim`/`IOSimPOR` harness running the **real** `src/Amoebius/Vault/{Init,Unseal,Seal,Client}.hs` code
  (`io-classes`-written, byte-for-byte the live path — no simulation-only fork) against the **Phase 17 Sprint 17.2 modeled Vault** (`src/Amoebius/Sim/Fakes/*`) with its fault knobs — **sealed**, **unreachable**, **lease-expiry**, and
  **restart** — driven by the scheduler.
- The **fail-closed invariant** asserted under **adversarial schedules**: across the explored interleavings the
  daemon **never** issues from `pki/`, **never** accepts a `.dhall`, and **never** resolves a `SecretRef` while
  Vault is sealed or while its unseal freshness is unproven; a sealed→unreachable→lease-expiry→restart sequence
  leaves the consumer failed closed with a typed error, never a plaintext fallback and never a stale read.
- **Exploration budget + coverage (§M.4, disambiguated).** The suite explores **at least 500 distinct seeds** per
  fault family under `IOSimPOR`, and carries `cover`/`classify` obligations that FAIL the run unless each is met:
  the **sealed** knob fires in >=25% of schedules, **unreachable** in >=25%, **lease-expiry** in >=15%, **restart**
  in >=15%, and the specific adversarial sequence sealed→unreachable→lease-expiry→restart is exercised in >=1% —
  so the named sequence is a *covered case*, never the entire explored set. A run whose generator fails to hit
  these fractions is a red gate, not a pass.
- **A Haskell changed-production-subject mutant (§M.2)**, re-run on every candidate, MUST turn the invariant red: a *dropped-guard* mutant of
  the freshness check that permits a `SecretRef` read while the modeled Vault is sealed (must produce a
  counterexample under the explored schedules).
- **Deterministic replay**: every schedule is seed-addressed, so a counterexample is replayable byte-for-byte from
  its seed for debugging.
- A **Register-2.5** proven/tested/assumed ledger (substrate `none`), stating the **honest limit** — the harness
  proves the *client's* fail-closed logic against a **modeled** Vault whose fidelity is **assumed**; that fidelity
  assumption is discharged only by this phase's **Sprint-55.3 Register-3 live gate**, never by simulation.

### Validation

1. Run the real init/unseal client under `IOSim`/`IOSimPOR` across **>=500 seeds per fault family** and assert the
   fail-closed invariant holds on every explored interleaving — no PKI issuance, no `.dhall` acceptance, no
   `SecretRef` read while sealed or freshness-unproven — **and** assert the §M.4 `cover`/`classify` fractions above
   were met (else the run is red for insufficient coverage, not passed).
2. Force a counterexample (e.g. a modeled-Vault fault that would tempt a stale read) and assert it is
   **deterministically replayable** from its seed.
3. Emit the Register-2.5 ledger (substrate `none`); assert it records modeled-Vault fidelity as **assumed** and
   names the Sprint-55.3 Register-3 live gate as the discharge, never marking the live invariant green from
   simulation.

### Remaining Work

The pre-reset record said `None`; that statement is permanently invalid for promotion. Current remaining work includes every `UNRESOLVED`/`MISSING` contract row, predecessor approval, owned legacy closure, and phase-specific obligation in the redesigned gate.

## Documentation Requirements

**Engineering docs to update (when the human promotes the gate, never before):**

- `documents/engineering/vault_pki_doctrine.md` — the §5 root-unseal, §4 init-once/unseal-on-rebuild, §8 PKI-anchor,
  and §9/§11 built-in-client + error-model honesty notes flip from "design intent for the root-Vault phase" to a
  delivered single-node root Vault with its proven/tested/assumed ledger attached; the KDF/AEAD primitives and the
  unlock-material backend chosen are recorded as pinned.
- `documents/engineering/platform_services_doctrine.md` — the §11 Vault-unsealed-before-secret-dependent-startup
  ordering edge gains its first amoebius validation.
- `documents/engineering/storage_lifecycle_doctrine.md` — the init-once/unseal-on-rebuild Vault face of the
  retained-PV durability guarantee gains its first amoebius proof on linux-cpu.
- `documents/engineering/resource_capacity_doctrine.md` — record the exact bounded Vault source-population,
  Raft peak, retained claim/backing, and rotated-audit backing as live-checked against the private provision.
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (federation
  surfaces UNVERIFIED).

**Cross-references to add:**

- `DEVELOPMENT_PLAN/README.md` — flip the Phase-62 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 62's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Vault/{Init,Unseal,Seal,Pki,Client,SecretRef,Error}.hs`
  as Phase-62 design-first rows against the component inventory.

## Related Documents

- [README.md](README.md) — the live tracker and phase order this document serves
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [overview.md](overview.md) — the target architecture and cross-cutting invariants
- [substrates.md](substrates.md) — the substrate registry and per-phase substrate map
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Vault, PKI & Secret Injection](../documents/engineering/vault_pki_doctrine.md) — the root Vault, SecretRef
  contract, PKI trust anchor, in-cluster-auth, and error model adopted here
- [Platform Services Doctrine](../documents/engineering/platform_services_doctrine.md) — the Vault-ready bring-up
  ordering edge this phase installs
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — the retained Vault
  backing, deterministic PV rebind, and init-once / unseal-on-rebuild durability
- [Deterministic Simulation Doctrine](../documents/engineering/deterministic_simulation_doctrine.md) — the
  Register-2.5 `IOSim` fail-closed check the real unseal client runs against the modeled Vault before the live gate
- [phase_59](phase_59_object_reconciler.md) — the typed renderer + SSA reconciler that renders and applies Vault
- [phase_61](phase_61_retained_storage.md) — the no-provisioner retained PV Vault's durable KV lives on
- [phase_63](phase_63_platform_backbone.md) — the standard-service stack that consumes these Vault secrets
