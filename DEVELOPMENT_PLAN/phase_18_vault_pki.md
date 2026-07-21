# Phase 18: Root Vault + PKI + built-in Haskell Vault client

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_17_retained_storage.md, DEVELOPMENT_PLAN/phase_19_platform_backbone.md, DEVELOPMENT_PLAN/phase_20_platform_services_2.md, DEVELOPMENT_PLAN/phase_27_network_fabric_wireguard.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Stand up the root single-node password-encrypted Vault as the fail-closed secrets root, root its
> self-signed PKI trust anchor, and prove the Vault client compiled *into* the amoebius binary (no agent sidecar)
> reads a `SecretRef` by name — the secrets floor the standard-service stack is built on.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement is
design intent, never a tested amoebius result. This phase opens after the Phase 17 gate (no-provisioner retained
storage + lossless rebind) and runs on the **linux-cpu** substrate in **Register 3** — live infrastructure: a
single-node `kind` cluster on a linux-cpu host, its Vault rendered and applied by the Phase-16 reconciler onto
the Phase-17 retained PV. The whole model is **proven in the sibling prodbox project** — its `vault_doctrine.md`,
`cluster_federation_doctrine.md`, and `Prodbox.Vault.Client` are the realized version of most of this — but that
is **sibling evidence, not an amoebius result**; amoebius has not yet built any of these sprints.

## Phase Summary

This phase installs the **secrets root** every later phase depends on. It brings up the **root Vault** as a
single-node, Shamir-sealed, password-encrypted, human-gated, **fail-closed** service whose first-ever `vault
init` runs exactly once against an empty retained PV and whose every later bring-up only **unseals** the same
durable data — never a re-init, never a key regeneration. The one-and-only ephemeral secret is the operator's
memorized password, which decrypts (via a real Argon2id KDF feeding an AEAD, never raw SHA-256) the
password-sealed unlock material that recovers the Shamir keys; it is supplied at the prompt and persisted
nowhere. The unsealed Vault owns the forest's **one self-signed PKI trust anchor** — a `pki/` root CA that issues
internal leaf certificates that chain back to it. Finally, the phase proves the **built-in Haskell Vault client**:
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
(Phases 19–20), the Keycloak-owned edge (Phase 21), and the parent/child unseal modes, parent secret injection, and the
cross-cluster intermediate-CA hierarchy (the amoebic-spawning/federation phases). Only the root cluster's own
single-node Vault, its self-signed anchor, and the in-cluster read path are in scope here.

**Substrate:** linux-cpu — the whole gate runs on a single-node `kind` cluster on a linux-cpu host; no apple,
linux-cuda, or windows substrate is touched.

**Register:** 3 — live infrastructure (§K).

**Gate:** on a single-node linux-cpu cluster, the root single-node password-encrypted Vault **inits exactly once
and unseals fail-closed** (an empty correctly provisioned PV inits and password-seals its unlock material without
printing raw keys, a delete+recreate only unseals the same Vault, and a secret-dependent workload against a
sealed Vault fails closed); the bounded source populations plus versioned Raft/audit models derive exact
retained and rotated-audit backing demands, with a one-byte-under provision rejected before effects and live
snapshot/compaction/recovery plus audit rotation remaining inside those caps, and every Vault app/init/rotation
execution unit and volume exactly matching its complete `ProvisionedServiceSpec` projection;
the Vault `pki/` engine holds a **self-signed root CA that issues** an internal leaf chaining back to it; and the
**built-in Haskell Vault client (no agent sidecar)** authenticates via Vault Kubernetes auth and **reads a
`SecretRef` by name**, returning a typed fail-closed error on any sealed/missing/denied read — a **Register-3**
live-infrastructure check.

**Gate integrity ([§M](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)).** The
gate's oracles are **authored and committed in Phase 0, before any `src/Amoebius/Vault/*.hs` exists** (§M.1):
(a) a canary KV fixture `test/golden/vault/canary.json` — `SecretRef.Vault { mount="secret", path="amoebius/canary",
field="token" }` with a fixed 32-byte value; (b) the pinned unlock-material envelope format spec
`test/golden/vault/unlock-envelope.spec` (magic bytes, Argon2id parameters `m/t/p`, AEAD algorithm identifier, and
field layout), hand-authored independently of `Seal.hs` (§M.3); (c) the typed-error-tag table
`test/golden/vault/error-tags.golden` enumerating the six tags (`unavailable`/`uninitialized`/`sealed`/
`policy-missing`/`secret-missing`/`decrypt-denied`) with, per tag, the exact redacted log line the client must emit
(§M.3, §M.8); (d) `test/golden/vault/storage-demand.golden`, a hand-calculated component table for the bounded
KV/Transit/PKI/auth/version/lease population and pinned Raft model, including resident, WAL, snapshot,
old+new-compaction, and recovery bytes; and (e) `test/golden/vault/audit-rotation.golden`, the independent
per-file/backups/retention/total-backing oracle (§M.3). The **representative set (§M.7)** is exactly: this one KV
`SecretRef.Vault`, one `TransitKey` unwrap, the self-signed root CA plus one internal leaf, the six typed error
tags, and the one bounded storage-population fixture with its exact-fit/one-byte-under variants — no other
shapes are in gate scope.
**External-observer traces (§M.5)** are read from a Vault **audit device** (file backend) and an argv/exec observer
on the consumer pod, never from any log the client emits about itself. Each sprint below names **>=1 committed
seeded mutant** (§M.2) that MUST turn the gate red, committed and re-run.

## Doctrine adopted

- [`vault_pki_doctrine.md §5`](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal)
  — *the root cluster: single-node, password-encrypted unseal*: the root's single-node shape lets it bootstrap
  with zero secrets, so the only secret standing up its Vault is the one a human types; the unlock material is
  password-AEAD-sealed (Argon2id → ChaCha20-Poly1305/AES-256-GCM), **never** raw SHA-256, and never plaintext at
  rest. The prodbox password-encrypted root unseal is **sibling evidence, not an amoebius result**.
- [`vault_pki_doctrine.md §4`](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init)
  — *init follows readiness: fail-closed Vault init*: **init-once / unseal-on-rebuild** — `vault init` runs exactly
  once when the retained PV is empty, and every later bring-up only unseals; a rebuilt cluster is *not* a fresh
  Vault.
- [`vault_pki_doctrine.md §2`](../documents/engineering/vault_pki_doctrine.md#2-vault-is-the-fail-closed-secrets-root)
  — *Vault is the fail-closed secrets root*: a sealed Vault **bricks** the cluster; the sole-backend and
  no-degraded-leak invariants mean no secret reconstructs from any non-Vault source and secret-dependent Pod
  startup fails its readiness gate.
- [`vault_pki_doctrine.md §8`](../documents/engineering/vault_pki_doctrine.md#8-the-root-cluster-owns-the-pki-trust-anchor)
  — *the root cluster owns the PKI trust anchor*: exactly one self-signed root of trust, the Vault `pki/` root CA,
  with internal certs chaining to it; this phase builds **plane 1 (internal PKI) only** — public-edge TLS (Phase
  21) and the cross-cluster intermediate-CA hierarchy (federation) are deferred and **live-proof-pending even in
  prodbox**.
- [`vault_pki_doctrine.md §9`](../documents/engineering/vault_pki_doctrine.md#9-in-cluster-consumers-authenticate-to-vault-directly)
  and [`§3`](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value) —
  *in-cluster consumers authenticate to Vault directly* and *the SecretRef contract, a name never a value*: the
  built-in client authenticates per consumer via Vault Kubernetes auth (service account → role → least-privilege
  policy → JWT) and resolves a `SecretRef.Vault { mount, path, field }` by name — no Secret-mounted plaintext, no
  env var, no `PATH`, and no agent sidecar (the `Prodbox.Vault.Client` shape as **sibling evidence**).
- [`vault_pki_doctrine.md §11`](../documents/engineering/vault_pki_doctrine.md#11-error-model-and-no-leak-logging)
  — *error model and no-leak logging*: Vault failures are ordinary typed control flow (unavailable / uninitialized
  / sealed / policy-missing / secret-missing / decrypt-denied) that let a caller fail closed with an actionable,
  non-leaking message; a log line never emits a resolved value, a token, or a presence oracle.
- [`platform_services_doctrine.md §11`](../documents/engineering/platform_services_doctrine.md#11-bring-up-and-dependency-ordering)
  — *bring-up and dependency ordering*: the hard edge this phase installs — **Vault reachable, initialized, and
  unsealed before any secret-dependent startup** — as a witnessed readiness gate, never a timer.
- [`resource_capacity_doctrine.md §5`](../documents/engineering/resource_capacity_doctrine.md#5-storagebudget-bounded-by-construction-single-owner-ceiling-per-arm) — *`StorageBudget`: bounded by construction, single-owner ceiling per arm*: the canonical
  `VaultStorageDemand` and private `ProvisionedVaultStorageDemand` — every persisted source population and
  history is finite, the version-pinned Raft model includes WAL/snapshot/compaction/recovery peaks, and the
  file audit device has a named backing/presentation with finite rotation. A raw demand cannot author its own physical
  bytes, and neither renderer nor reconciler accepts an unprovisioned Vault storage value.

## Sprints

## Sprint 18.1: Root single-node password-encrypted Vault — init-once / unseal-on-rebuild 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Vault/Init.hs`, `src/Amoebius/Vault/Unseal.hs`, `src/Amoebius/Vault/Seal.hs`
(the Argon2id-KDF → AEAD password-sealed unlock-material envelope) — target paths, not yet built.
**Blocked by**: Phase 16 gate (the typed renderer + SSA reconciler — Vault is rendered and applied through it);
Phase 17 gate (no-provisioner retained storage — Vault's durable KV lives on a retained PV, so a rebuild
*unseals* rather than re-initializes); Phase 15 (the baked Vault binary in the in-cluster `distribution`
registry).
**Independent Validation**: on an empty PV, `vault init` runs exactly once and captures password-sealed unlock
material while **never** printing raw unseal/recovery keys or the root token; a cluster delete + recreate brings
the *same* Vault up by **unseal only** (no re-init, no key regeneration); a secret-dependent workload started
against a sealed Vault fails its readiness gate closed with no plaintext fallback; one byte below the derived
Raft or rotated-audit physical peak rejects before effects, while a live snapshot/compaction/recovery and audit
rotation stay within their provisioned backings.
**Docs to update**: `documents/engineering/vault_pki_doctrine.md`, `documents/engineering/platform_services_doctrine.md`,
`documents/engineering/storage_lifecycle_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`vault_pki_doctrine.md §5`](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal),
[`§4`](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init), and
[`§2`](../documents/engineering/vault_pki_doctrine.md#2-vault-is-the-fail-closed-secrets-root): bring up the
single-node, password-encrypted, human-gated, fail-closed secrets root, init-once and unseal-on-rebuild, on the
retained PV — the prodbox root-unseal shape as **sibling evidence, not an amoebius result**.

### Deliverables
- Root Vault in **Shamir seal mode**, rendered and reconciled onto the Phase-17 retained PV; first-ever `vault
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
  material is password-AEAD-sealed and never plaintext at rest. **At the root Phase-18 bring-up the backend is
  the host-side `.age` file**: MinIO does not exist until Phase 19, so a MinIO-sealed object (and equally a cloud
  KMS or TPM/YubiKey identity) is a *later* backend option, never a root-unseal prerequisite — the root Vault
  must not depend on a platform service it precedes (no Vault↔MinIO bootstrap cycle).
- **Fail-closed ordering**: no secret-dependent workload runs before Vault reports reachable, initialized, and
  unsealed; a consumer reaching a sealed Vault fails closed.
- **Committed seeded mutant(s) (§M.2)**, committed and re-run, each MUST turn Validation red: (i) a
  *dropped-guard* mutant of `Unseal.hs` that re-runs `vault operator init` on rebuild instead of unsealing existing
  data (must fail the canary-identity and already-initialized checks); (ii) an *effect-swap* mutant of `Seal.hs`
  that seals the unlock material with raw `SHA-256(password)`-keyed obfuscation instead of the Argon2id→AEAD
  envelope (must fail the envelope-format and wrong-password checks); (iii) a *storage-term deletion* mutant
  that omits Raft old+new compaction/recovery headroom or renders a one-byte-smaller PVC (must fail the
  independent peak oracle before apply); and (iv) an *unbounded-audit* mutant that drops the backup/retention
  limits or points the audit path outside its named backing (must fail render identity and the live cap probe).

### Validation
1. **Init-once / unseal-on-rebuild witness (forecloses wipe-and-re-init).** On an empty PV, run init; write the
   committed canary secret `test/golden/vault/canary.json` into Vault and record (i) the canary value read back and
   (ii) the SHA-256 digest of the at-rest unlock-material ciphertext. Then delete + recreate the cluster and assert:
   (a) the canary reads back **byte-identical** to the committed fixture (proves the same durable data, not a fresh
   Vault); (b) the unlock-material ciphertext digest is **unchanged** (no key regeneration); (c) a `vault operator
   init` attempt against the recreated cluster returns **already-initialized**; and (d) the Vault audit device
   records an **unseal** operation and **no** init operation on the rebuild.
2. **Password-crypto witness (forecloses fake/plaintext sealing).** Assert: (a) the at-rest unlock file parses as
   the pinned `test/golden/vault/unlock-envelope.spec` envelope with its Argon2id `m/t/p` parameters and AEAD
   algorithm identifier matching the spec; (b) an unseal attempt with a **wrong password** fails closed and yields
   no key material (paired positive: the correct password unseals — the two runs differ only in the password,
   §M.8); (c) a byte-scan of the unlock file, the PV bytes, stdout/stderr, and every bring-up artifact finds **none**
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
   block (`/proc/<pid>/environ`), the reconciler and Vault logs, and the bring-up shell history — a byte-scan for
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
6. **Live Raft/audit high-water witness.** Populate the bounded test corpus through its declared retained
   versions, certificate/revocation and lease histories; force a Raft snapshot and compaction while observing
   simultaneous old+new files, then restart at that boundary and observe WAL replay/recovery. The mounted
   filesystem high-water must stay within the usable provision and the raw device within
   `provisionedBytes`. Generate audited operations through more
   than one file boundary, wait through the declared retention boundary, and assert active-file size, retained
   backup count/age, and total audit-backing high-water stay within the provision; no audit byte appears outside
   the named mount. The storage-term-deletion and unbounded-audit mutants must turn these live checks red.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 18.2: The self-signed PKI trust anchor issues 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Vault/Pki.hs` (the `pki/` root-CA mount + internal leaf issuance) — target path,
not yet built.
**Blocked by**: Sprint 18.1 (a live, unsealed Vault is a precondition for enabling `pki/` and issuing).
**Independent Validation**: the Vault `pki/` engine holds a self-signed **root CA**; an internal leaf certificate
issued from `pki/` **chains to that root CA**; while Vault is sealed, no certificate issues.
**Docs to update**: `documents/engineering/vault_pki_doctrine.md`, `documents/engineering/platform_services_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`vault_pki_doctrine.md §8`](../documents/engineering/vault_pki_doctrine.md#8-the-root-cluster-owns-the-pki-trust-anchor):
make the root Vault's `pki/` engine the one self-signed trust anchor for the forest, building **plane 1 (internal
PKI) only** — public-edge TLS and the cross-cluster intermediate-CA hierarchy are explicitly out of scope here.

### Deliverables
- The Vault `pki/` engine holding a **self-signed root CA** as the single forest trust anchor.
- Internal-leaf issuance from `pki/` for in-cluster service-to-service TLS, every issued cert chaining back to the
  root anchor.
- The **three-planes distinction** recorded and enforced: internal PKI (this phase) is not public-edge TLS
  (ZeroSSL/route53, Phase 21) and is not the distro's own self-signed cluster CA (the chicken-and-egg floor,
  [`vault_pki_doctrine.md §10`](../documents/engineering/vault_pki_doctrine.md#10-the-chicken-and-egg-floor-what-stays-outside-vault));
  the cross-cluster intermediate-CA hierarchy is deferred to federation and flagged **live-proof-pending**.
- **Committed seeded mutant(s) (§M.2)**, committed and re-run, each MUST turn Validation red: (i) a *dropped-guard*
  mutant of `Pki.hs` that issues an internal leaf while Vault is **sealed** instead of failing closed (must fail
  the sealed-issuance check); and (ii) an *effect-swap* mutant of `Pki.hs` that returns a leaf signed by an
  unrelated key so it does **not** chain back to the self-signed root CA (must fail the chain-verify check).

### Validation
1. Assert `pki/` holds a self-signed root CA after bring-up.
2. Issue an internal leaf cert from `pki/` and assert it chains to the self-signed root CA.
3. Seal Vault and assert issuance fails closed with the typed **`sealed`** reason (no certificate is produced) —
   the run differing only in seal state from item 2's successful unsealed issuance (§M.8).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 18.3: Built-in Haskell Vault client (no agent sidecar) reads a `SecretRef` by name — the gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Vault/Client.hs` (the client linked into the amoebius binary), `src/Amoebius/Vault/SecretRef.hs`
(the `SecretRef` resolver), `src/Amoebius/Vault/Error.hs` (the typed fail-closed error) — target paths, not yet built.
**Blocked by**: Sprint 18.1 (a live, unsealed Vault to read from); Sprint 18.2 (a workload verifying a peer cert
resolves the chain rooted here); the `SecretRef` type + decode-time validator from the pre-cluster band (owned by
the Dhall schema / decoder phases — an earlier-phase prereq, not restated here).
**Independent Validation**: an in-cluster consumer authenticates to Vault with its **Kubernetes service-account
JWT** (role bound to its namespace + service account, least-privilege policy) and resolves a
`SecretRef.Vault { mount, path, field }` **by name**, receiving exactly the stored bytes; **a Vault audit device
(§M.5) records that this read ran under a token minted by `auth/kubernetes/login` bound to the consumer's exact
namespace + service account** — not a pre-minted or image-baked token; the consumer pod carries **no Vault Agent
sidecar container** and mounts **no plaintext k8s Secret**; a read of a path outside policy is
denied; a sealed / uninitialized / policy-missing / secret-missing read returns a **typed fail-closed error** that
carries no secret material and emits no presence oracle in its logs.
**Docs to update**: `documents/engineering/vault_pki_doctrine.md`, `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/README.md` (flip the Phase-18 status when the gate passes), `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`vault_pki_doctrine.md §9`](../documents/engineering/vault_pki_doctrine.md#9-in-cluster-consumers-authenticate-to-vault-directly),
[`§3`](../documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value), and
[`§11`](../documents/engineering/vault_pki_doctrine.md#11-error-model-and-no-leak-logging): prove the one
in-cluster secret-delivery path — a workload authenticating directly to Vault and reading a `SecretRef` by name
through the **built-in** client, with a typed, no-leak error model. The `Prodbox.Vault.Client` lineage is
**sibling evidence, not an amoebius result**.

### Deliverables
- **`src/Amoebius/Vault/Client.hs`**: the Vault client compiled directly into the amoebius binary — **no
  HashiCorp Vault Agent sidecar**, no Secret-mounted plaintext, no environment variable, no `PATH` lookup;
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
- **Committed seeded mutant(s) (§M.2)**, committed and re-run, each MUST turn Validation red: (i) a
  *dropped-effect* mutant of `Client.hs` that reads a token from a mounted file / env var instead of performing
  `auth/kubernetes/login` (must fail the audit-device login-provenance check and the role-deletion negative);
  (ii) a *guard-weakening* mutant of `Error.hs` that folds `secret-missing` and `sealed` into one tag or logs the
  requested path (must fail the error-tag table and the presence-oracle checks).

### Validation
1. **K8s-auth provenance witness (forecloses image-baked token).** A consumer authenticates via Vault Kubernetes
   auth and reads the canary `SecretRef.Vault`-named KV secret, getting **byte-identical** the value in
   `test/golden/vault/canary.json`; the **Vault audit device** records the read ran under a token minted by
   `auth/kubernetes/login` bound to the consumer's exact namespace + service account. Then **delete the Vault role
   (or the service account)** and assert the same read now fails with the typed `policy-missing`/denied error —
   proving the login actually occurs rather than a pre-minted token. Assert the pod has no agent sidecar and no
   plaintext Secret mount (read from the argv/exec observer and the pod spec, §M.5).
2. **Typed negatives + presence-oracle absence (disambiguated).** A read of a path outside the consumer's policy
   is denied; the representative `TransitKey` unwrap is exercised — its positive unwrap succeeds, and a
   policy-denied unwrap yields the typed **`decrypt-denied`** tag; a read against an unreachable Vault (no
   listener) yields the typed **`unavailable`** tag; and each of the sealed / uninitialized / policy-missing /
   secret-missing / unavailable / decrypt-denied reads returns **its specific tag from
   `test/golden/vault/error-tags.golden`** (§M.8 — each negative asserts *why* it failed, paired with the
   positive canary read or unwrap that differs only in the foreclosed dimension), so all six error tags and the
   one `TransitKey` unwrap in the representative set (§M.7) are gated here. **Presence-oracle absence is operationally
   defined:** the emitted log line for `secret-missing`, `policy-missing`, and `sealed` must be **byte-identical
   except for the typed tag itself** (so log shape reveals nothing about whether a path/secret exists), and a grep
   of the Vault audit device and the consumer's structured logs finds **none** of: the requested mount/path, the
   resolved value, and the auth token.
3. Emit the Register-3 ledger; assert the deferred federation surfaces are recorded UNVERIFIED, not green.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 18.4: Register-2.5 fail-closed Vault unseal under simulated faults 📋

**Status**: Planned
**Implementation**: `test/Amoebius/Sim/Vault/UnsealFailClosedSpec.hs` (the `IOSim`/`IOSimPOR` driver that runs the
**real** `src/Amoebius/Vault/{Init,Unseal,Seal,Client}.hs` against the modeled Vault) — target path, not yet built.
**Blocked by**: Sprint 18.1 (the real init/unseal/seal client under test), Sprint 18.3 (the real `SecretRef`
resolver + typed error under test); Phase 12 Sprint 12.2 (`src/Amoebius/Sim/Env.hs` + `src/Amoebius/Sim/Fakes/*` —
the modeled fault-injectable Vault with the sealed / unreachable / lease-expiry knobs the schedules drive).
**Independent Validation**: the **real** Vault init/unseal client code — written against `io-classes`, unchanged
from the live path — runs under `IOSim`/`IOSimPOR` against the Sprint 12.2 modeled Vault with injected **sealed /
unreachable / lease-expiry / restart** faults, and under adversarial schedules the **fail-closed invariant** holds:
the daemon **never** proceeds — never issues from `pki/`, never accepts a `.dhall`, never reads a `SecretRef` —
while Vault is sealed or its freshness is unproven; every failing schedule is **deterministically replayable** from
its seed; substrate `none`, **Register 2.5**.
**Docs to update**: `documents/engineering/deterministic_simulation_doctrine.md`,
`documents/engineering/vault_pki_doctrine.md`, `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`deterministic_simulation_doctrine.md`](../documents/engineering/deterministic_simulation_doctrine.md) and
re-adopt [`vault_pki_doctrine.md §2`](../documents/engineering/vault_pki_doctrine.md#2-vault-is-the-fail-closed-secrets-root):
prove the **fail-closed secrets-root invariant in simulation** — run the real init/unseal client against the
modeled fault-injectable Vault under `IOSim`/`IOSimPOR` and assert that no adversarial fault schedule (sealed,
unreachable, lease-expiry, restart) ever lets the daemon proceed while Vault is sealed or its freshness is
unproven. This is a **Register-2.5** deterministic-simulation check, run in-process **before** the Sprint-18.3
Register-3 live gate — not a substitute for it.

### Deliverables
- An `IOSim`/`IOSimPOR` harness running the **real** `src/Amoebius/Vault/{Init,Unseal,Seal,Client}.hs` code
  (`io-classes`-written, byte-for-byte the live path — no simulation-only fork) against the **Sprint 12.2 modeled
  Vault** (`src/Amoebius/Sim/Fakes/*`) with its fault knobs — **sealed**, **unreachable**, **lease-expiry**, and
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
- **Committed seeded mutant (§M.2)**, committed and re-run, MUST turn the invariant red: a *dropped-guard* mutant of
  the freshness check that permits a `SecretRef` read while the modeled Vault is sealed (must produce a
  counterexample under the explored schedules).
- **Deterministic replay**: every schedule is seed-addressed, so a counterexample is replayable byte-for-byte from
  its seed for debugging.
- A **Register-2.5** proven/tested/assumed ledger (substrate `none`), stating the **honest limit** — the harness
  proves the *client's* fail-closed logic against a **modeled** Vault whose fidelity is **assumed**; that fidelity
  assumption is discharged only by this phase's **Sprint-18.3 Register-3 live gate**, never by simulation.

### Validation
1. Run the real init/unseal client under `IOSim`/`IOSimPOR` across **>=500 seeds per fault family** and assert the
   fail-closed invariant holds on every explored interleaving — no PKI issuance, no `.dhall` acceptance, no
   `SecretRef` read while sealed or freshness-unproven — **and** assert the §M.4 `cover`/`classify` fractions above
   were met (else the run is red for insufficient coverage, not passed).
2. Force a counterexample (e.g. a modeled-Vault fault that would tempt a stale read) and assert it is
   **deterministically replayable** from its seed.
3. Emit the Register-2.5 ledger (substrate `none`); assert it records modeled-Vault fidelity as **assumed** and
   names the Sprint-18.3 Register-3 live gate as the discharge, never marking the live invariant green from
   simulation.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
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
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-18 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 18's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Vault/{Init,Unseal,Seal,Pki,Client,SecretRef,Error}.hs`
  as Phase-18 design-first rows against the component inventory.

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
- [phase_16](phase_16_renderer_reconciler.md) — the typed renderer + SSA reconciler that renders and applies Vault
- [phase_17](phase_17_retained_storage.md) — the no-provisioner retained PV Vault's durable KV lives on
- [phase_19](phase_19_platform_backbone.md) — the standard-service stack that consumes these Vault secrets
