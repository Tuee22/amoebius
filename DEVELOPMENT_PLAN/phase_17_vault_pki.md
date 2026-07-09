# Phase 17: Root Vault + PKI + built-in Haskell Vault client

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, overview.md, phase_16_retained_storage.md, phase_18_platform_services.md, system_components.md
**Generated sections**: none

> **Purpose**: Stand up the root single-node password-encrypted Vault as the fail-closed secrets root, root its
> self-signed PKI trust anchor, and prove the Vault client compiled *into* the amoebius binary (no agent sidecar)
> reads a `SecretRef` by name — the secrets floor the standard-service stack is built on.

---

## Phase Status

📋 Planned. Specified before implementation; every sprint below is 📋 Planned and every prescriptive statement is
design intent, never a tested amoebius result. This phase opens after the Phase 16 gate (no-provisioner retained
storage + lossless rebind) and runs on the **linux-cpu** substrate in **Register 3** — live infrastructure: a
single-node `kind` cluster on a linux-cpu host, its Vault rendered and applied by the Phase-15 reconciler onto
the Phase-16 retained PV. The whole model is **proven in the sibling prodbox project** — its `vault_doctrine.md`,
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
secret-missing read returns a typed, fail-closed error that carries no secret material.

What this phase deliberately does **not** do: the full standard-service stack that consumes these secrets (Phase
18), the Keycloak-owned edge (Phase 19), and the parent/child unseal modes, parent secret injection, and the
cross-cluster intermediate-CA hierarchy (the amoebic-spawning/federation phases). Only the root cluster's own
single-node Vault, its self-signed anchor, and the in-cluster read path are in scope here.

**Substrate:** linux-cpu — the whole gate runs on a single-node `kind` cluster on a linux-cpu host; no apple,
linux-cuda, or windows substrate is touched.

**Gate:** on a single-node linux-cpu cluster, the root single-node password-encrypted Vault **inits exactly once
and unseals fail-closed** (an empty PV inits and password-seals its unlock material without printing raw keys, a
delete+recreate only unseals the same Vault, and a secret-dependent workload against a sealed Vault fails closed);
the Vault `pki/` engine holds a **self-signed root CA that issues** an internal leaf chaining back to it; and the
**built-in Haskell Vault client (no agent sidecar)** authenticates via Vault Kubernetes auth and **reads a
`SecretRef` by name**, returning a typed fail-closed error on any sealed/missing/denied read — a **Register-3**
live-infrastructure check.

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
  19) and the cross-cluster intermediate-CA hierarchy (federation) are deferred and **live-proof-pending even in
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

## Sprints

## Sprint 17.1: Root single-node password-encrypted Vault — init-once / unseal-on-rebuild 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Vault/Init.hs`, `src/Amoebius/Vault/Unseal.hs`, `src/Amoebius/Vault/Seal.hs`
(the Argon2id-KDF → AEAD password-sealed unlock-material envelope) — target paths, not yet built.
**Blocked by**: Phase 15 gate (the typed renderer + SSA reconciler — Vault is rendered and applied through it);
Phase 16 gate (no-provisioner retained storage — Vault's durable KV lives on a retained PV, so a rebuild
*unseals* rather than re-initializes); Phase 14 (the baked Vault binary in the in-cluster `distribution`
registry).
**Independent Validation**: on an empty PV, `vault init` runs exactly once and captures password-sealed unlock
material while **never** printing raw unseal/recovery keys or the root token; a cluster delete + recreate brings
the *same* Vault up by **unseal only** (no re-init, no key regeneration); a secret-dependent workload started
against a sealed Vault fails its readiness gate closed with no plaintext fallback.
**Docs to update**: `documents/engineering/vault_pki_doctrine.md`, `documents/engineering/platform_services_doctrine.md`,
`documents/engineering/storage_lifecycle_doctrine.md`, `DEVELOPMENT_PLAN/system_components.md`.

### Objective
Adopt [`vault_pki_doctrine.md §5`](../documents/engineering/vault_pki_doctrine.md#5-the-root-cluster-single-node-password-encrypted-unseal),
[`§4`](../documents/engineering/vault_pki_doctrine.md#4-init-follows-readiness-fail-closed-vault-init), and
[`§2`](../documents/engineering/vault_pki_doctrine.md#2-vault-is-the-fail-closed-secrets-root): bring up the
single-node, password-encrypted, human-gated, fail-closed secrets root, init-once and unseal-on-rebuild, on the
retained PV — the prodbox root-unseal shape as **sibling evidence, not an amoebius result**.

### Deliverables
- Root Vault in **Shamir seal mode**, rendered and reconciled onto the Phase-16 retained PV; first-ever `vault
  init` runs only when the PV is empty, and every later bring-up redeploys against existing data and only unseals.
- **Password-sealed unlock material**: the first init's unseal/recovery keys + initial root token captured once
  and immediately sealed under the operator's password with a real KDF (**Argon2id**) feeding an AEAD
  (ChaCha20-Poly1305 / AES-256-GCM) — **never raw SHA-256**; the password memorized, entered at the prompt on
  init and every unseal, persisted nowhere; raw keys never printed.
- A **pluggable unlock-material backend** behind one interface (a sealed object in durable MinIO, a host-side
  `.age` file, a cloud KMS, or a TPM/YubiKey identity) — the load-bearing property is only that the material is
  password-AEAD-sealed and never plaintext at rest.
- **Fail-closed ordering**: no secret-dependent workload runs before Vault reports reachable, initialized, and
  unsealed; a consumer reaching a sealed Vault fails closed.

### Validation
1. On an empty PV, run init; assert it produced password-sealed unlock material and never printed raw keys; then
   delete + recreate the cluster and assert the bring-up **unseals** the same Vault (no re-init).
2. Start a secret-dependent workload against a sealed Vault and assert it fails closed with no plaintext fallback.
3. Assert the operator password is the sole human-supplied secret and is persisted nowhere.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 17.2: The self-signed PKI trust anchor issues 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Vault/Pki.hs` (the `pki/` root-CA mount + internal leaf issuance) — target path,
not yet built.
**Blocked by**: Sprint 17.1 (a live, unsealed Vault is a precondition for enabling `pki/` and issuing).
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
  (ZeroSSL/route53, Phase 19) and is not the distro's own self-signed cluster CA (the chicken-and-egg floor,
  [`vault_pki_doctrine.md §10`](../documents/engineering/vault_pki_doctrine.md#10-the-chicken-and-egg-floor-what-stays-outside-vault));
  the cross-cluster intermediate-CA hierarchy is deferred to federation and flagged **live-proof-pending**.

### Validation
1. Assert `pki/` holds a self-signed root CA after bring-up.
2. Issue an internal leaf cert from `pki/` and assert it chains to the self-signed root CA.
3. Seal Vault and assert issuance fails closed (no certificate is produced).

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 17.3: Built-in Haskell Vault client (no agent sidecar) reads a `SecretRef` by name — the gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Vault/Client.hs` (the client linked into the amoebius binary), `src/Amoebius/Vault/SecretRef.hs`
(the `SecretRef` resolver), `src/Amoebius/Vault/Error.hs` (the typed fail-closed error) — target paths, not yet built.
**Blocked by**: Sprint 17.1 (a live, unsealed Vault to read from); Sprint 17.2 (a workload verifying a peer cert
resolves the chain rooted here); the `SecretRef` type + decode-time validator from the pre-cluster band (owned by
the Dhall schema / decoder phases — an earlier-phase prereq, not restated here).
**Independent Validation**: an in-cluster consumer authenticates to Vault with its **Kubernetes service-account
JWT** (role bound to its namespace + service account, least-privilege policy) and resolves a
`SecretRef.Vault { mount, path, field }` **by name**, receiving exactly the stored bytes; the consumer pod carries
**no Vault Agent sidecar container** and mounts **no plaintext k8s Secret**; a read of a path outside policy is
denied; a sealed / uninitialized / policy-missing / secret-missing read returns a **typed fail-closed error** that
carries no secret material and emits no presence oracle in its logs.
**Docs to update**: `documents/engineering/vault_pki_doctrine.md`, `documents/engineering/testing_doctrine.md`,
`DEVELOPMENT_PLAN/README.md` (flip the Phase-17 status when the gate passes), `DEVELOPMENT_PLAN/system_components.md`.

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

### Validation
1. A consumer authenticates via Vault Kubernetes auth and reads a `SecretRef.Vault`-named KV secret, getting
   exactly the stored bytes; assert the pod has no agent sidecar and no plaintext Secret mount.
2. A read of a path outside the consumer's policy is denied; a sealed / secret-missing read returns the typed
   fail-closed error and the logs carry no secret material and no presence oracle.
3. Emit the Register-3 ledger; assert the deferred federation surfaces are recorded UNVERIFIED, not green.

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
- `documents/engineering/testing_doctrine.md` — record the Register-3 ledger variant this gate emits (federation
  surfaces UNVERIFIED).

**Cross-references to add:**
- `DEVELOPMENT_PLAN/README.md` — flip the Phase-17 status when the gate passes; link this document.
- `DEVELOPMENT_PLAN/substrates.md` — record Phase 17's gate substrate (linux-cpu) in the per-phase substrate map.
- `DEVELOPMENT_PLAN/system_components.md` — register `src/Amoebius/Vault/{Init,Unseal,Seal,Pki,Client,SecretRef,Error}.hs`
  as Phase-17 design-first rows against the component inventory.

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
- [Storage Lifecycle Doctrine](../documents/engineering/storage_lifecycle_doctrine.md) — the retained Vault PV and
  init-once / unseal-on-rebuild durability
- [phase_15](phase_15_renderer_reconciler.md) — the typed renderer + SSA reconciler that renders and applies Vault
- [phase_16](phase_16_retained_storage.md) — the no-provisioner retained PV Vault's durable KV lives on
- [phase_18](phase_18_platform_services.md) — the standard-service stack that consumes these Vault secrets
