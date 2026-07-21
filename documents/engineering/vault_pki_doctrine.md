# Vault, PKI & Secret Injection

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_18_vault_pki.md, DEVELOPMENT_PLAN/phase_19_platform_backbone.md, DEVELOPMENT_PLAN/phase_20_platform_services_2.md, DEVELOPMENT_PLAN/phase_23_app_tenancy.md, DEVELOPMENT_PLAN/phase_27_network_fabric_wireguard.md, DEVELOPMENT_PLAN/phase_28_multicluster_spawn_georepl.md, DEVELOPMENT_PLAN/phase_30_provider_clusters.md, DEVELOPMENT_PLAN/phase_33_infernix_lift.md, DEVELOPMENT_PLAN/phase_35_apple_metal_host_daemon.md, DEVELOPMENT_PLAN/phase_36_test_topology_dsl.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/testing_doctrine.md, documents/illegal_state/illegal_state_ml_asset.md, documents/illegal_state/illegal_state_security.md, documents/illegal_state/illegal_state_storage.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: Single source of truth for amoebius secrets and trust — Vault as the fail-closed secrets root, the SecretRef-by-name contract, the root cluster's single-node password-encrypted unseal, the two sanctioned parent/child unseal modes, parent-injects-secrets-into-child, and the root-owned PKI trust anchor for the whole forest.

---

## 1. Why this doctrine exists

The DSL holds no secrets — only *names* for them
([dsl_doctrine.md §6](./dsl_doctrine.md#6-secrets-are-names-never-values)). That single rule determines what this
document specifies: for an `InForceSpec` that is composed, diffed, rolled out across an entire
forest of clusters, and stored in an object store yet carries no secret bytes, **where the bytes
live, who puts them there, and what happens when they cannot be reached.** The answer is one subsystem:
an in-cluster Vault per cluster, a tree of trust between those Vaults, and a single human-memorized
password at the root that the whole forest's liveness depends on.

This document owns six things:

1. **Vault as the fail-closed secrets root** — the sole backend for every secret, key, and certificate;
   sealed means *bricked*, never *degraded* ([§2](#2-vault-is-the-fail-closed-secrets-root)).
2. **The SecretRef contract** — the typed *reference* the DSL carries, and the validator that rejects a
   literal secret in a production `.dhall` ([§3](#3-the-secretref-contract-a-name-never-a-value)).
3. **Fail-closed Vault init that follows readiness** — *init Vault, then deliver the `InForceSpec`*,
   init-once / unseal-on-rebuild ([§4](#4-init-follows-readiness-fail-closed-vault-init)).
4. **The root cluster's single-node, password-encrypted unseal** — *root single-node "prodbox"
   behaviour, init to password-encrypted Vault keys*, human-on-init ([§5](#5-the-root-cluster-single-node-password-encrypted-unseal)).
5. **The two parent/child unseal modes and parent secret injection** — self-unseal via a k8s secret
   **or** parent-owns-the-secret-and-the-child-requests-an-unlock, and *parents directly inject the
   secrets into the child's Vault* ([§6](#6-parentchild-unseal-two-sanctioned-modes), [§7](#7-parent-injects-secrets-into-the-childs-vault)).
6. **The root-owned PKI trust anchor** — the root cluster owns the self-signed anchor *for everything
   else*; trust flows down the tree, never sideways ([§8](#8-the-root-cluster-owns-the-pki-trust-anchor)).

It does **not** own: the DSL-surface rule that secrets are names not values
([dsl_doctrine.md §6](./dsl_doctrine.md#6-secrets-are-names-never-values)); the fact that Vault is one
of the nine standard services ([platform_services_doctrine.md §5](./platform_services_doctrine.md#5-vault--the-secrets-root-reference-only));
the retained Vault backing, deterministic PV rebind, and init-once/unseal-on-rebuild *storage* mechanics
([storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md)); the cluster bring-up/spawn/teardown
*lifecycle verbs* ([cluster_lifecycle_doctrine.md](./cluster_lifecycle_doctrine.md)); the Pulumi
MinIO-backend Vault-envelope encryption ([pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md)); or the
host-only NodePort comms carve-out ([host_cluster_comms_doctrine.md](./host_cluster_comms_doctrine.md)).
Phase order and status live only in [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md).

> **Honesty.** Everything here is Phase 0 design intent, specified before implementation. The model is
> **proven in the sibling prodbox project** — its `vault_doctrine.md`, `cluster_federation_doctrine.md`,
> and `secret_derivation_doctrine.md` are the realized version of most of this — but that is *evidence
> from a sibling system, not proof in amoebius*, which has not yet built the relevant phases. Read every
> prescriptive statement as the contract amoebius intends to satisfy, never as a tested amoebius result
> ([documentation_standards.md §6](../documentation_standards.md#6-honesty-the-proventestedassumed-discipline)).

---

## 2. Vault is the fail-closed secrets root

The load-bearing requirement of the whole model: **a sealed Vault bricks the cluster.** There is one
secrets backend and no plaintext fallback, so when Vault is sealed the cluster degrades to an opaque
pile of durable data that reveals nothing.

> A sealed, unreachable, or uninitialized Vault means **no secret resolves** — no KV read, no Transit
> unwrap, no certificate issued. PVs and MinIO objects may still exist, but they yield no secret, no
> in-force config, and no downstream-cluster inventory until Vault is unsealed.

Three invariants make that concrete (generalized from prodbox's `vault_doctrine.md §2` and
`secret_derivation_doctrine.md §3`, lifted from "prodbox-managed cluster" to "every amoebius cluster"):

1. **Sole-backend invariant.** Every secret / credential / key / certificate is a Vault object. There
   is no second store and no plaintext fallback; no secret reconstructs from any non-Vault source.
2. **No-degraded-leak invariant.** When Vault is sealed, no secret resolves, no certificate issues, no
   envelope decrypts, and secret-dependent Pod startup fails its readiness gate
   ([platform_services_doctrine.md §11](./platform_services_doctrine.md#11-bring-up-and-dependency-ordering)).
   Already-running workloads may continue only to the extent they need no *new* Vault operation; a new
   Pod must never reconstruct a secret from a non-Vault source, because none exists.
3. **Metadata-is-secret invariant.** Downstream-cluster names, endpoints, kubeconfigs, and account IDs
   are themselves secret data; a sealed cluster reveals none of them ([§6](#6-parentchild-unseal-two-sanctioned-modes); the federation consequence is
   owned by [cluster_lifecycle_doctrine.md §3](./cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)).

Every amoebius secret is one of **three Vault object shapes**:

| Shape | Vault subsystem | Used for |
|---|---|---|
| KV v2 secret | `secret/` engine | passwords, API keys, OIDC client secrets, SMTP creds, cloud IAM creds, ACME EAB material |
| Transit key | `transit/` engine | envelope encryption of MinIO objects (in-force config, Pulumi backend state, the content store) — the backend encryption itself is owned by [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md) and [content_addressing_doctrine.md](./content_addressing_doctrine.md) |
| PKI certificate | `pki/` engine | internal TLS leaf/intermediate certs chaining to the root anchor ([§8](#8-the-root-cluster-owns-the-pki-trust-anchor)) |

This *replaces*, rather than extends, any earlier "derive secrets from a seed" scheme: prodbox's
master-seed HMAC-derivation model was retired in favour of exactly this Vault-object model
(`secret_derivation_doctrine.md §1, §4`), and amoebius adopts the finished shape — there is no seed, no
host-side cache, and no chart-template `lookup`+`randAlphaNum` path. A secret is **generated once and
persisted on Vault's durable storage**, then fetched by each consumer ([§9](#9-in-cluster-consumers-authenticate-to-vault-directly)). Vault is a singleton HA
platform service on every cluster ([platform_services_doctrine.md §5](./platform_services_doctrine.md#5-vault--the-secrets-root-reference-only)),
and its durable PV is owned by [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md).

---

## 3. The SecretRef contract: a name, never a value

The DSL must be *safe to read* — composed, diffed, rolled out from the root across the whole forest,
and stored. So a sensitive field encodes a typed **reference** to a secret, never the secret itself
([dsl_doctrine.md §6](./dsl_doctrine.md#6-secrets-are-names-never-values) owns the DSL-surface rule;
this section owns the *typed mechanism* it defers to). The reference names *where* a secret will be;
Vault holds *what* it is.

Conceptual Dhall union, imported by every app/cluster schema (adapted from prodbox's proven `SecretRef`
in its `config_doctrine.md` / `vault_doctrine.md §3`):

```dhall
-- Example: shared SecretRef type, imported wherever a sensitive value would otherwise appear
let SecretRef =
      < Vault : { mount : Text, path : Text, field : Text }
      | TransitKey : { name : Text }
      | Prompt : { name : Text, purpose : Text }
      | TestPlaintext : Text
      >

in  SecretRef
```

| Constructor | Production `.dhall` | Notes |
|---|---|---|
| `Vault` / `TransitKey` | Allowed | The target for every in-cluster-consumed secret and every envelope key. |
| `Prompt` | Allowed (CLI only) | One-off elevated operator material (e.g. the cloud-admin credential that mints a least-privilege identity); supplied at the prompt, used, and discarded — never written to disk. |
| `TestPlaintext` | **Rejected** | Accepted only by the test harness, only from a flagged test-secrets file. |

The contract is enforced by the same **two typed gates** that guard every `InForceSpec`
([dsl_doctrine.md §5](./dsl_doctrine.md#5-the-illegal-state-unrepresentable-contract)): Gate 1 (the
Dhall typechecker) admits only a well-typed `SecretRef`, and Gate 2 (the in-process Haskell decoder
under GHC 9.12.4) runs a validator that **rejects any literal secret value and any `TestPlaintext` arm
in production mode**. A plaintext secret in a production config is therefore not "linted later" — it
fails to decode, and an undecoded config is never reconciled. *If it decodes, it carries no secret.*

The corollary — *flagged* test credentials — is a locked amoebius rule: credentials used for test
deployments are specifically flagged so the harness can recognize and clean them up.
`TestPlaintext` is that flag in the type system; its lifecycle (spin-up →
run → always tear down, elevated-only storage deletion) is owned by
[testing_doctrine.md](./testing_doctrine.md).

### 3.1 The parent-custody KV secret family: SSH keys, WireGuard keys, and the `Rke2NodeToken`

Some secrets are not read by an in-cluster workload reaching Vault ([§9](#9-in-cluster-consumers-authenticate-to-vault-directly)) but are **node-provisioning
material** the parent must place *before* (or as) a node comes up — SSH host/login keys, the Curve25519
WireGuard peer keypairs
([network_fabric_doctrine.md §3](./network_fabric_doctrine.md#3-keys-config-and-distribution--wireguard-as-just-another-reconcile)),
and the rke2 cluster's join token. These share **one custody shape**, and it is exactly the shape [§7](#7-parent-injects-secrets-into-the-childs-vault)
gives every named secret:

- **KV v2 objects, referenced by `SecretRef` name** ([§2](#2-vault-is-the-fail-closed-secrets-root) shape table, [§3](#3-the-secretref-contract-a-name-never-a-value) contract). The key/token
  **never** appears as a value in any `.dhall`; the config names *where* it lives and Vault holds *what*
  it is.
- **Parent-minted, parent-injected** ([§7](#7-parent-injects-secrets-into-the-childs-vault)). The parent mints/resolves the material into its own unsealed
  Vault and injects it into the child's Vault over the spawn-time trust channel; no operator ever handles
  the bytes, and a child names only its own subtree's material.
- **Rotatable.** Because consumers resolve by name, rotating the value is a Vault write plus a reconcile —
  no `.dhall` edit and no re-roll from the root.

`Rke2NodeToken` is the newest member of this family: the single shared secret every rke2 server and agent
presents to join the cluster's etcd / control-plane fabric. It is a **Vault-KV `SecretRef` class**,
parent-minted and parent-injected, referenced **by name**, and rotatable like any other KV secret — the
same custody family as the SSH keys and the Curve25519 WireGuard keys above. The **rollout** that consumes
it (first server runs etcd `cluster-init`; further servers and all agents join by a `server:` URL + this
token, rendered read-only into each node's `config.yaml`) is a host-level reconcile owned by
[cluster_lifecycle_doctrine.md §3](./cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)
(elastic agent growth by
[cluster_lifecycle_doctrine.md §8](./cluster_lifecycle_doctrine.md#8-dynamic-node-provisioning)); this
section owns only the token's **custody**. Distinguish it sharply from the rke2 cluster **CA**: the
node-token is a *Vault-owned, rotatable KV secret*, whereas rke2's self-signed cluster CA is chicken-and-egg
**floor** Vault cannot own ([§8](#8-the-root-cluster-owns-the-pki-trust-anchor) plane 3, [§10](#10-the-chicken-and-egg-floor-what-stays-outside-vault)). One carve-out rides on the **Curve25519 WireGuard keys**: they are
Vault-KV custody like the rest of this family, but they are the *data-plane* fabric's transport **only** —
never the wire by which a mode-(b) child reaches its unseal authority ([§6](#6-parentchild-unseal-two-sanctioned-modes), [network_fabric_doctrine.md §3](./network_fabric_doctrine.md#3-keys-config-and-distribution--wireguard-as-just-another-reconcile)),
since a Vault-KV key cannot be the transport that unseals the Vault holding it. That reach is the floor
`ParentReachChannel` ([bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api)).

```dhall
-- The node-provisioning KV secret family — every member a `SecretRef.Vault { mount, path, field }`
-- named in `.dhall`, minted into the child's Vault by its parent (§7), never a literal:
--   SSH host/login keys · Curve25519 WireGuard peer keypairs · Rke2NodeToken (the rke2 join token)
```

> **Honesty.** `Rke2NodeToken` custody is Phase-0 design intent. The single-node rke2 base (one
> `rke2-server` with its `config.yaml` / install markers) is **sibling evidence** in prodbox's `Rke2.hs`;
> a multi-node server/agent rollout that mints and injects a *shared join token* is net-new across the
> whole family — sibling evidence, not an amoebius result.

A **stretched (non-member) host worker** reuses this custody family **wholesale**. When a native
host-level worker (Apple-Metal or Windows-CUDA) reaches a home cluster's data plane from off-box — the
stretched "K1" host-worker shape — its channel-2 data-plane credential *and* its own Curve25519 WireGuard
peer key are both parent-minted, parent-injected, name-referenced KV `SecretRef`s of exactly this shape
([§7](#7-parent-injects-secrets-into-the-childs-vault)). The stretched-node doctrine adds **no new secret
custody** — only new *reach*; it names only the mint/inject/name-reference family this section already owns.
What such a worker lacks is an in-cluster identity to *authenticate* the by-name read with, and that seam —
distinct from custody — is flagged at [§9](#9-in-cluster-consumers-authenticate-to-vault-directly).

### 3.2 ML asset-staging credentials resolve from Vault by name — no second store

The three-tier ML-asset lifecycle stages **Tier-2** model artifacts *eagerly*: the control-plane singleton pulls
the parent-named model set from upstream and re-keys it onto the content-addressed store, writing `.ready`
last ([content_addressing_doctrine.md §4.5](./content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)).
That staging step needs **two** credentials, and **both resolve from Vault by name** as ordinary
`SecretRef`s ([§3](#3-the-secretref-contract-a-name-never-a-value)):

- the **object-store** credential the singleton uses to write the MinIO content store, and
- the **upstream** credential it uses to pull weights from the model source.

Neither is a second secret store and neither has a hardcoded fallback. This is a deliberate, load-bearing
correction of the sibling: infernix stages models via a **Kubernetes-Secret store** plus a hardcoded
`minioadmin` / `minioadmin123` default when that Secret is absent (its `model_cache.py`). That fallback is
precisely the **sole-backend invariant** violation [§2](#2-vault-is-the-fail-closed-secrets-root) forbids — a secret reconstructed from a non-Vault
source — and the k8s-Secret store is the "no second secret store" divergence amoebius refuses. In amoebius
both credentials are `SecretRef.Vault` names, parent-injected ([§7](#7-parent-injects-secrets-into-the-childs-vault)) and resolved in-cluster via Vault
Kubernetes auth ([§9](#9-in-cluster-consumers-authenticate-to-vault-directly)); a missing credential **fails closed** rather than silently defaulting to a well-known
account. This is **sibling evidence of the anti-pattern, not an amoebius result** — amoebius has not built
the staging path; it specifies that the path carry no second store and no default.

The **upstream-pull** credential is, further, **scoped per app**. Naming a model to import is a first-class,
provenance-carrying constructor (the import arm of a serveable `ModelArtifact`,
[content_addressing_doctrine.md §4.5](./content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)),
and each app's staging resolves only its **own** app-namespaced upstream `SecretRef` — one app's staging
cannot pull, and therefore cannot mint an artifact from, another app's model source. This is the
secrets-by-name face of per-app model isolation (an app serves only models it produced or imported); the
content-store namespacing and the decode-foreclosed "app B serving/continuing app A's model without a grant" illegal
state are owned by [content_addressing_doctrine.md §4.5](./content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss)
and [illegal_state_catalog.md](../illegal_state/illegal_state_catalog.md); this section owns only that the pull credential
is itself a per-app name. Correspondingly, the bytes that credential pulls are **verified against a pinned
expected content-address, failing closed before `.ready`** — the pin-and-verify import constructor (and its
layers: pin *presence* type-foreclosed, pin *match* decode-foreclosed, "the pin names the intended model" runtime-checked/assumed)
is owned by content_addressing §4.5; vault_pki owns only that the credential resolving the pull is a name,
never a value.

---

## 4. Init follows readiness: fail-closed Vault init

**Init never precedes readiness.** Only after the cluster is bootstrapped and all the core services are
up and reachable is it *initialized*: init Vault, then deliver its `InForceSpec`.
The bring-up sequence that arrives at "core services reachable" is owned by
[cluster_lifecycle_doctrine.md §2](./cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap); the
platform-service ordering edge — **Vault initialized and unsealed before any secret-dependent startup**
— is owned by [platform_services_doctrine.md §11](./platform_services_doctrine.md#11-bring-up-and-dependency-ordering).
This section owns the Vault-init contract those two point at.

- **Init-once / unseal-on-rebuild.** The cluster is ephemeral; its storage is not. `vault init` runs
  **exactly once, ever** — the first time the retained Vault backing contains no initialized Vault data. Every
  later bring-up redeploys Vault against the existing data and only **unseals** it: no re-init, no key
  regeneration. A cluster rebuild is *not* a fresh Vault. This is the Vault face of the deterministic-rebind
  guarantee owned by
  [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md) and
  [cluster_lifecycle_doctrine.md §7](./cluster_lifecycle_doctrine.md#7-ephemeral-spin-updown-with-deterministic-rebind):
  because the retained backing survives teardown and a fresh PV object rebinds it identically, a Vault KV
  object is as durable across rebuilds as any other retained byte.
- **Delivering the `InForceSpec` is a fail-closed handoff.** Once unsealed, the cluster receives its
  in-force configuration. The configuration's *at-rest* protection — a Vault-Transit envelope over the MinIO
  backend — is owned by [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md) and the content store
  ([content_addressing_doctrine.md](./content_addressing_doctrine.md)); the relevant fact here is that
  while Vault is sealed that object is opaque ciphertext, so a sealed cluster reveals nothing about its
  own setup beyond the minimal seal-mode basics it needs to reach and unseal its Vault ([§6](#6-parentchild-unseal-two-sanctioned-modes)).
- **The decrypted spec never lands in a cluster-legible store.** The control-plane daemon fetches the
  envelope and **decrypts it in-process, on demand** (prodbox's `Settings.loadConfigFile`-via-
  `Prodbox.Minio.EncryptedObject` pattern); the `InForceSpec` is **never** written to a plaintext
  Kubernetes ConfigMap or to etcd. Any ConfigMap a workload reads may carry only the [§6](#6-parentchild-unseal-two-sanctioned-modes) unencrypted-basics
  floor — never the spec, secrets, or downstream inventory. As defense-in-depth, etcd is configured with
  an `--encryption-provider-config` so even that floor is encrypted at rest. A plaintext spec at rest is
  therefore foreclosed at two layers: the spec is an envelope handle **by type** (author-time), and the
  daemon decrypts it only **in-process**, never persisting plaintext — a **runtime** discipline, not a
  type-level impossibility ([illegal_state_catalog.md](../illegal_state/illegal_state_catalog.md)).
- **Ready-before-consumer is absolute.** No consumer of a secret may run before Vault reports
  reachable, initialized, and unsealed. A consumer that reaches a sealed Vault fails closed rather than
  racing it ([§2](#2-vault-is-the-fail-closed-secrets-root)). This generalizes prodbox's `secret_derivation_doctrine.md §7` bootstrap-order rule.

---

## 5. The root cluster: single-node, password-encrypted unseal

The root is the one cluster a human ever unseals, and the reason it can be is its single-node shape.
*Root single-node "prodbox" behaviour … init to password-encrypted Vault keys*
is the constituent capability amoebius inherits from prodbox.

**Why single-node makes this work.** A multi-node root bring-up would need secrets — SSH keys or cloud
credentials for the extra nodes — and that would violate secrets-never-in-Dhall before Vault even
exists to hold them. Constraining the root to a single node lets it
bootstrap with **zero secrets**, so the *only* secret involved in standing up the root Vault is the one
a human types. The single-node-root *bootstrap* decision is owned by
[cluster_lifecycle_doctrine.md §2](./cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap); the
consequence this section owns is the unseal model that zero-secret bootstrap enables.

The model:

- **Root Vault uses Shamir seal mode.** First-ever `vault init` ([§4](#4-init-follows-readiness-fail-closed-vault-init)) produces unseal/recovery keys plus
  the initial root token. amoebius captures that material exactly once and immediately seals it under
  the operator's password into **password-encrypted unlock material** — then never prints raw keys.
- **The password is the sole ephemeral secret.** It is *memorized*, *persisted nowhere*, and supplied
  by a human at the unseal prompt on root init and on every subsequent unseal
  (*the human provides this password on root cluster init*). It is the single ephemeral root of trust
  for the whole forest.
- **A password is not a hash.** The unlock material is sealed with a real password-based KDF
  (Argon2id) feeding an AEAD (e.g. ChaCha20-Poly1305 / AES-256-GCM) — **never raw SHA-256**, which is a
  hash, not encryption. The password derives the key that *decrypts the unseal keys*; an unsealed Vault
  is then what decrypts and serves everything else.

```text
operator memorized password (entered on init / unseal; stored nowhere persistent)
  -> Argon2id KDF -> AEAD-decrypt the unlock material
  -> recover the root Vault's Shamir unseal keys
  -> submit them -> UNSEAL THE ROOT VAULT
  -> the unsealed root Vault serves every secret, every Transit unwrap, and the PKI anchor (§8),
     and is the unseal authority that lets child clusters come up (§6)
```

The consequence is exactly the [§2](#2-vault-is-the-fail-closed-secrets-root) brick, viewed from the top: **no password this boot → root Vault
stays sealed → nothing below it can come up.** The concrete realization — a password-AEAD-sealed
*unlock bundle*, where it is stored, and how the bootstrap path reaches it before Vault is up — is
proven in prodbox (`vault_doctrine.md §6`–`§6.1`); amoebius keeps that backend deliberately *pluggable*
(a sealed object in durable MinIO, a host-side `.age` file, a cloud KMS, a TPM/YubiKey identity) behind
one interface, because the load-bearing property is only that the unseal material is **password-AEAD-
sealed and never plaintext at rest**, not which vault holds the ciphertext. The *channel* by which the
operator supplies the password at bring-up (and on every reboot) is the admin control plane's
**`vault init/unseal` endpoint** — the operator CLI → the amoebius NodePort service → the control-plane singleton —
owned by [bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api);
this section owns the *sealed-material* model, that doc owns the *delivery channel*. Because a reboot
re-enters the sealed régime, that reach is the **seal-critical, node-local** arm of that doc's admin-plane
reach class — Vault-independent, never over the fabric — so a reboot's unseal never depends on the very Vault
it is unsealing.

> **Honesty.** The password-encrypted root unseal is *implemented and exercised in prodbox*; in
> amoebius it is design intent for the root-Vault phase. The specific KDF/AEAD primitives and the
> unlock-material backend are pinned by the implementing phase, not fixed here. Status lives only in
> [../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md).

---

## 6. Parent/child unseal: two sanctioned modes

Below the root, no human is in the loop — a child must come up on its own. amoebius sanctions **exactly
two** ways a child Vault may unseal, and the choice is a typed field of the child's scoped `InForceSpec`:

| Mode | How the child unseals | Where the unseal authority lives |
|---|---|---|
| **(a) Self-unseal** | The child reads its own unseal key from a Kubernetes secret and unseals itself | A k8s secret on the child cluster |
| **(b) Parent-held unlock** | The child requests an unlock from its parent; the parent owns the unseal secret/authority | The parent cluster's Vault |

Both are legal; neither is a human prompt. Mode (b) is the stricter, fail-closed-by-construction
choice, and it is the mode prodbox realizes in full: a child Vault configured with a transit seal
pointed at its parent, so the child *literally cannot unseal without a live, unsealed parent*, with the
child's recovery keys and initial root token custodied in the parent's Vault KV
(prodbox `cluster_federation_doctrine.md §2–§3`). amoebius treats prodbox's transit-seal tree as the
**evidence-backed realization of mode (b)**, while keeping mode (a) available for clusters that should
hold their own unseal key locally.

The seal mode is one of the few facts a cluster may know about itself *before* its Vault is unsealed —
the minimal, non-revealing basics it needs to reach and unseal its own Vault: its cluster id, its own
Vault address, its seal mode, and (for a child in mode (b)) the parent reference it must contact. These
basics carry nothing about workloads, secrets, or downstream clusters; everything else is behind the
unsealed Vault.

**A remote mode-(b) child reaches its unseal authority over the floor channel, not the data fabric.** When a
mode-(b) child sits at a different network locality than its parent, its unlock request crosses the WAN — and
it rides the **`ParentReachChannel` floor path** ([bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api), the same SSH/cloud-API path the parent
provisioned the child over), **not** the data-plane WireGuard fabric. This is forced, not stylistic: the
fabric's own peer key is a Vault-KV secret ([§3.1](#31-the-parent-custody-kv-secret-family-ssh-keys-wireguard-keys-and-the-rke2nodetoken)) in the child's *sealed* Vault, so a fabric-carried unseal would be circular
(wg0 needs a key that only the Vault it is unsealing can serve). The child's bootstrap reference and unseal
credential — **including the transport** to reach the authority — are therefore floor material provisioned by
the parent ([§10](#10-the-chicken-and-egg-floor-what-stays-outside-vault) item 4), present before the child's Vault, or any fabric, exists.

```mermaid
flowchart TD
  childinit[Child Vault initialized once on an empty durable PV] --> mode{Which unseal mode does the ChildInForceSpec declare?}
  mode -->|mode a| selfsecret[Self-unseal: child reads its own unseal key from a Kubernetes secret]
  mode -->|mode b| requestunlock[Parent-held unlock: child requests an unlock from the parent]
  requestunlock -->|parent sealed or unreachable| brick[Child cannot unseal: fail-closed brick cascades down the tree]
  requestunlock -->|parent unsealed| unsealed[Child Vault unsealed]
  selfsecret --> unsealed
```

Two encapsulation rules make the forest safe to reason about, and both are owned upstream — recorded
here only because they are *unseal-trust* facts:

- **Children know nothing about siblings.** A child receives only its own subtree's `ChildInForceSpec`
  (including its own children's) and nothing about siblings or any wider part of the forest
  ([cluster_lifecycle_doctrine.md §3](./cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)).
  A child's unseal request reaches *up* to its parent and never *sideways*. A sealed cluster therefore
  cannot be made to reveal whether it even *has* children, how many, or where ([§2](#2-vault-is-the-fail-closed-secrets-root) metadata invariant).
- **The brick cascades down, by design.** In mode (b), if any parent is sealed or unreachable, its
  children cannot unseal, and their children cannot unseal, down the whole subtree. This is the safety
  property, not a fault: a sealed parent must brick its descendants rather than let them come up with
  secrets recovered from any non-Vault source. Cluster liveness for the entire forest roots in one
  operator unsealing the root ([§5](#5-the-root-cluster-single-node-password-encrypted-unseal)). The cascade is depth-generic: it bricks the whole subtree to
  **arbitrary depth**, exactly as the transit-seal trust tree nests parent→child→grandchild.
- **Each child's spec is sliced under its own Transit key.** Need-to-know is not only a *distribution*
  rule (a child receives only its own subtree, above) — it is a *cryptographic* one. Each child's subtree
  spec is enveloped under a **per-child Vault Transit key** (`transit/amoebius-<child-id>-config`) with a
  per-child policy that grants decrypt on that key alone, and the id↔object index is sharded per child. So
  a child cannot decrypt a sibling's subtree **even if its parent's Vault is unsealed** — the horizontal
  need-to-know boundary holds by *key*, not merely by which ciphertext was handed down. The parent
  necessarily holds every child key (it must, to spawn), so the boundary is **horizontal** between
  siblings and **bounded downward** to a node's own subtree, never **upward** to an ancestor. That a
  child's spec value can only *be* its own subtree projection is owned by
  [cluster_lifecycle_doctrine.md §3](./cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)
  and [dsl_doctrine.md](./dsl_doctrine.md); this section owns the key mechanism. Optionally the parent
  signs each envelope's digest so a child can *attest* it received the intended, untampered spec.

---

## 7. Parent injects secrets into the child's Vault

Section 3 says the DSL holds only a *name*. This section closes the loop: the bytes get into the
child's Vault because **the parent puts them there**. *Parents directly inject the secrets into the
child's Vault* — the DSL names *where* a secret will be, and the parent
materializes *what* it is into the child during spawn/reconcile.

The end-to-end path, in order:

1. **The `InForceSpec` names the secret** ([§3](#3-the-secretref-contract-a-name-never-a-value)) — a `SecretRef` coordinate, no value, safe to roll out from
   the root across the whole tree.
2. **The parent resolves the value from its own (unsealed) Vault** and **injects it into the child's
   Vault** over a trusted parent→child channel established at spawn time. The spawn itself — a Pulumi
   deploy from inside the parent, with a MinIO backend encrypted via Vault Transit — is owned by
   [cluster_lifecycle_doctrine.md §3](./cluster_lifecycle_doctrine.md#3-amoebic-spawning--the-recursive-forest)
   and [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md); the injection rides that established trust.
3. **In-cluster consumers on the child read it via Vault Kubernetes auth** ([§9](#9-in-cluster-consumers-authenticate-to-vault-directly)) — never from a
   Dhall-mounted plaintext fragment, never from an environment variable.

This is why secrets-by-name is not a loophole: there is no point at which a secret value sits in a
file an operator hands around. The value lives only in Vault, injected downward by the parent that
  already holds it, and resolved in-cluster by the workload that needs it. A child only ever receives the
  secrets for *its own* subtree — the same children-know-nothing-about-siblings boundary as [§6](#6-parentchild-unseal-two-sanctioned-modes), applied
to secret material: injecting a parent's or a sibling's secret into a child is not expressible, because
a child's scoped `InForceSpec` names only its own.

> **Honesty.** Parent→child secret injection is *specified* here and scheduled with amoebic spawning;
> prodbox proves the adjacent custody flow (a parent writing a child's init keys and downstream
> metadata into the parent's own Vault KV, `cluster_federation_doctrine.md §3`), which is evidence for
> the trust channel but is *not* itself the same "inject arbitrary named secrets into the child's Vault"
> operation. Treat this as design intent, not a tested amoebius result.

---

## 8. The root cluster owns the PKI trust anchor

There is exactly **one** self-signed root of trust in the forest, and it sits at the root cluster: *that
root cluster's kind owns the (self-signed) PKI trust anchor for everything else*. Internal trust flows **down** the tree from that anchor; it is never minted independently at a
leaf and never shared sideways between siblings — the same direction as unseal authority ([§6](#6-parentchild-unseal-two-sanctioned-modes)).

- **Vault PKI is the anchor.** The root cluster's Vault `pki/` engine holds the self-signed **root
  CA**. As the forest grows, the root issues an **intermediate CA** to each child, the child issues to
  its own children, and so on — a CA hierarchy whose shape mirrors the amoebic forest. Every internal
  certificate (service-to-service TLS, any mesh, in-cluster component certs) chains back to the single
  root anchor, so a workload anywhere in the tree can validate a peer's certificate against a trust
  root it inherited from above.
- **Internal PKI is not public-edge TLS.** Three certificate planes coexist and must not be conflated:
  1. **Internal PKI (this doc):** Vault-PKI certs chaining to the root anchor, for traffic *inside* and
     *between* amoebius clusters.
  2. **Public-edge TLS:** the certificates Keycloak's wild-ingress edge presents to the outside world,
     provisioned via ZeroSSL and DNS (route53). That ACME path — including the EAB material, which is a
     Vault KV secret referenced by `SecretRef` ([§2](#2-vault-is-the-fail-closed-secrets-root), [§3](#3-the-secretref-contract-a-name-never-a-value)) — is owned by
     [pulumi_iac_doctrine.md](./pulumi_iac_doctrine.md); the single wild-ingress door is owned by
     [platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path).
  3. **Distro mTLS:** the Kubernetes distro's own self-signed cluster CA for kube-apiserver — for an
     `rke2` cluster, rke2's own self-signed cluster CA — over which the host amoebius binary talks to the
     control plane. This is part of the chicken-and-egg floor ([§10](#10-the-chicken-and-egg-floor-what-stays-outside-vault)), not something Vault owns — Vault
     runs *inside* that PKI. The rke2 *join token* is **not** this CA: it is a Vault-owned, rotatable KV
     secret ([§3.1](#31-the-parent-custody-kv-secret-family-ssh-keys-wireguard-keys-and-the-rke2nodetoken)).
- **The host-comms hop is deliberately not PKI-secured.** Host compute daemons reach in-cluster MinIO
  and Pulsar as **peers over host-only NodePorts with no mTLS** — that hop is safe by being
  localhost-only and unreachable off-box, not by certificate, so the PKI anchor does **not** extend to
  it ([host_cluster_comms_doctrine.md](./host_cluster_comms_doctrine.md);
  [platform_services_doctrine.md §9](./platform_services_doctrine.md#9-the-loadbalancer-and-the-single-wild-ingress-path)).

```mermaid
flowchart TD
  human[Operator password supplied on root init] -->|Argon2id plus AEAD unseal| rootvault[Root cluster Vault: Shamir seal, self-signed root CA]
  rootvault -->|issues intermediate CA down the tree| childa[Child A Vault: intermediate CA]
  rootvault -->|injects named secret values into child Vault| childa
  rootvault -->|issues intermediate CA down the tree| childb[Child B Vault: intermediate CA]
  rootvault -->|injects named secret values into child Vault| childb
  childb -->|is itself a parent: issues CA and injects secrets| grand[Grandchild Vault: intermediate CA]
```

> **Honesty.** The Vault-PKI-as-root-anchor design is specified here; prodbox uses Vault as its TLS/PKI
> authority with cert-manager driving ZeroSSL and Vault holding the EAB material
> (`vault_doctrine.md §11`), and the native-Vault-PKI internal-CA hierarchy is a deferred,
> live-proof-pending option even there. Read the cross-cluster CA hierarchy as amoebius's intended end
> state, not a tested result.

---

## 9. In-cluster consumers authenticate to Vault directly

There is exactly **one** in-cluster secret-delivery path: a workload authenticates to Vault with its
Kubernetes service account and reads only what its policy grants. This is the amoebius adoption of
prodbox's proven model (`secret_derivation_doctrine.md §5–§6`,
prodbox `vault_doctrine.md §12`); the inventory table there is the evidence, not restated here.

- **Vault Kubernetes auth per consumer.** Each component has a service account; a Vault role bound to
  that namespace + service account; a least-privilege policy granting read on exactly its own KV paths
  or Transit keys and nothing else; and it authenticates with the service-account JWT. A leaked grant
  is contained to one consumer's paths.
- **No Secret-mounted plaintext, no env var, no PATH.** There is no Dhall fragment mounted as a k8s
  Secret and no credential read from the environment — consistent with amoebius's locked
  no-environment-variables / no-`PATH` contract ([substrate_doctrine.md](./substrate_doctrine.md)):
  the only inputs a workload reads are its typed config (names, [§3](#3-the-secretref-contract-a-name-never-a-value)) and the Vault objects its policy
  allows.
- **Generated once, never derived.** A secret a chart needs is minted once into Vault (KV) or issued
  by Vault (PKI) at install and persisted on the durable PV ([§2](#2-vault-is-the-fail-closed-secrets-root), [§4](#4-init-follows-readiness-fail-closed-vault-init)); no chart template generates or
  stores a secret value, and there is no seed to derive from.
- **A built-in Haskell Vault client, no Agent sidecar.** Vault is reached through a **built-in Haskell client
  library linked into the one amoebius binary** — never a Vault Agent sidecar, a CSI secrets-store driver, or a
  `vault` CLI subprocess. One client, one auth path, one dependency closure
  ([daemon_topology_doctrine.md §1](./daemon_topology_doctrine.md#1-one-binary-three-contexts)): the singleton
  operates Vault, and every worker reads only its own paths through the same in-process client. A sidecar would
  add a second process, a second failure mode, and a file-mounted secret surface this contract forbids; a
  built-in client keeps the read in-process (the `InForceSpec` and every envelope are decrypted in-process and
  never written to a plaintext ConfigMap or PVC).

> **Non-member auth-method seam (named this round, not yet closed).** The Vault Kubernetes auth above
> **assumes the consumer is a cluster member** — a pod with a Kubernetes service account whose JWT Vault
> can verify. A **host-level worker is not a member**: an Apple-Metal or Windows-CUDA host worker — and,
> stretched, a non-member "K1" host worker reaching a remote home cluster over the host-only NodePort, the
> WireGuard fabric, **or** a secure gateway — runs as a native subprocess with **no service account and no
> kubelet identity**, so the k8s-auth path does not apply to it. **OPEN (auth method only; custody
> family closed).** A non-member host worker resolves its named, parent-injected secrets via the same
> SecretRef/parent-custody family
> ([§3](#3-the-secretref-contract-a-name-never-a-value)/[§3.1](#31-the-parent-custody-kv-secret-family-ssh-keys-wireguard-keys-and-the-rke2nodetoken)/[§7](#7-parent-injects-secrets-into-the-childs-vault));
> only the auth **method** (not k8s-JWT) is unpinned. Current position: the candidate is a parent-issued
> AppRole/wrapped-token or a WireGuard-identity-bound method, minted at attach, to be pinned in the
> host-compute/stretched phase. This holds for **every** host worker (both VPN- and gateway-reached) and is
> **runtime-checked residue**, not a foreclosed illegal state. The stretched-node
> doctrine that surfaces the seam is owned elsewhere ([host_cluster_comms_doctrine.md](./host_cluster_comms_doctrine.md)
> and the stretched split in cluster_topology / network_fabric); this section owns only the Vault-auth
> consequence.

---

## 10. The chicken-and-egg floor: what stays outside Vault

Vault owns everything except the minimal floor it cannot bootstrap itself from. This is the amoebius
generalization of prodbox's `vault_doctrine.md §17`. The **only** data that may live outside Vault:

1. **The distro's self-signed cluster CA + admin kubeconfig** — for an `rke2` cluster, rke2's own
   self-signed cluster CA. Vault runs *inside* this cluster's PKI, so it cannot be the thing that mints
   it ([§8](#8-the-root-cluster-owns-the-pki-trust-anchor) plane 3). This CA is also what issues any **in-cluster serving cert needed before the Vault
   PKI anchor exists** — e.g. Vault's own bootstrap `:8200` listener — since the sealed Vault cannot mint the
   cert that fronts it; the admin-REST NodePort's own pre-PKI transport, and the host-comms hops, are instead
   secured by **network restriction, not a certificate** ([§8](#8-the-root-cluster-owns-the-pki-trust-anchor) last bullet;
   [bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api) the admin-plane reach class), so there is no separate admin-transport
   cert for this list to enumerate. The rke2 *node-join token*, by contrast, is **not** floor material: it is a
   Vault-owned, rotatable KV `SecretRef` ([§3.1](#31-the-parent-custody-kv-secret-family-ssh-keys-wireguard-keys-and-the-rke2nodetoken)).
2. **The retained Vault backing and its deterministic PV binding** — owned by
   [storage_lifecycle_doctrine.md](./storage_lifecycle_doctrine.md).
3. **Root cluster only:** the operator's memorized unseal password — the sole ephemeral secret ([§5](#5-the-root-cluster-single-node-password-encrypted-unseal)).
   The password-AEAD-sealed unlock material it decrypts is not a Vault-owned object; it is what
   *unseals* Vault, and its body is password-sealed regardless of where the ciphertext rests.
4. **Child cluster only:** the bootstrap reference and unseal credential the child uses to reach its
   unseal authority — **including the transport** to reach that authority (the `ParentReachChannel` floor path,
   [bootstrap_sequence_doctrine.md §5](./bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api)), so the reach never depends on the child's own sealed Vault or on
   the Vault-KV data-plane fabric ([§6](#6-parentchild-unseal-two-sanctioned-modes)). In mode (b) it is provisioned and owned by the parent
   ([§6](#6-parentchild-unseal-two-sanctioned-modes)); in mode (a) it is the local Kubernetes secret holding the child's own unseal key.

Everything else — all generated secrets, cloud creds, OIDC and SMTP material, internal TLS, the
in-force config, the Pulumi backend state, and child custody material — is Vault-owned and
unrecoverable from a sealed cluster.

---

## 11. Error model and no-leak logging

Vault failures are ordinary, typed control flow — not exceptions thrown into a half-applied effect —
and they never carry secret material. A conceptual error type (adapted from prodbox's
`Prodbox.Vault.Client`, `vault_doctrine.md §14`) distinguishes *unavailable / uninitialized / sealed /
policy-missing / secret-missing / decrypt-denied* so a caller can fail closed with an actionable,
non-leaking message.

The logging rule extends the [§2](#2-vault-is-the-fail-closed-secrets-root) and [§6](#6-parentchild-unseal-two-sanctioned-modes) invariants to output: on a sealed-state path, a log line never
emits a SecretRef-resolved value, a Vault token, child init keys, a downstream-cluster name, or an
exists-vs-absent oracle that would distinguish "this child/secret is present" from "absent" — presence
is itself metadata. Prefer redacted structured logs
(`vault_status=sealed component=child-unseal result=blocked`) over identifying messages. The deployed,
cross-surface proof that *every* sealed surface leaks nothing — the sealed-Vault red-team — is part of
the verification surface owned by [chaos_failover_doctrine.md](./chaos_failover_doctrine.md) and
[testing_doctrine.md](./testing_doctrine.md), and is *evidence-backed in prodbox* (its
`vault_doctrine.md §19` red-team checklist), not yet proven in amoebius.

---

## 12. Planning ownership

This document is normative Vault/PKI/secret-injection doctrine only. Delivery sequencing, completion
status, validation gates, and remaining work are owned by
[../../DEVELOPMENT_PLAN/README.md](../../DEVELOPMENT_PLAN/README.md), never restated here. For
orientation only (the plan is authoritative): **root Vault + the self-signed PKI anchor** land with
platform services in the same phase as the standard service set
([cluster_lifecycle_doctrine.md §10](./cluster_lifecycle_doctrine.md#10-planning-ownership),
[platform_services_doctrine.md §13](./platform_services_doctrine.md#13-planning-ownership)); the
**SecretRef decode-time validator** rides the orchestration-DSL gate phase
([dsl_doctrine.md §10](./dsl_doctrine.md#10-planning-ownership)); and **parent/child unseal, parent
secret injection, and the cross-cluster CA hierarchy** land with amoebic spawning/federation. This doc
states the target shape and links back for status.

---

## Cross-references

- [Engineering Doctrine Index](./README.md)
- [DSL Doctrine](./dsl_doctrine.md) — secrets-are-names-not-values (the DSL-surface rule this doc's mechanism serves)
- [Cluster Lifecycle Doctrine](./cluster_lifecycle_doctrine.md) — single-node-root bootstrap, amoebic spawning, and the child unseal lifecycle
- [Platform Services Doctrine](./platform_services_doctrine.md) — Vault as a standard HA platform service and the Vault-ready ordering edge
- [Readiness Ordering Doctrine](./readiness_ordering_doctrine.md) — readiness_ordering [§5](./readiness_ordering_doctrine.md#5-the-bootstrap-tier-local-observed-witnesses-never-timers) and this doc's [§4 init-follows-readiness / fail-closed](#4-init-follows-readiness-fail-closed-vault-init) are the event-driven resolution of the readiness race, not a wait around it
- [Storage Lifecycle Doctrine](./storage_lifecycle_doctrine.md) — the retained Vault backing, deterministic PV rebind, and init-once / unseal-on-rebuild durability
- [Pulumi IaC Doctrine](./pulumi_iac_doctrine.md) — Vault-Transit-envelope encryption of the MinIO Pulumi backend and the public-edge ZeroSSL/route53 path
- [Content Addressing & Determinism](./content_addressing_doctrine.md) — the content-addressed model store the Tier-2 staging credentials write to ([§4.5](./content_addressing_doctrine.md#45-the-ml-asset-lifecycle-one-bounded-content-addressed-cache-resolved-on-first-miss))
- [Network Fabric Doctrine](./network_fabric_doctrine.md) — the Curve25519 WireGuard peer keys in the same parent-custody KV secret family as the `Rke2NodeToken` ([§3.1](#31-the-parent-custody-kv-secret-family-ssh-keys-wireguard-keys-and-the-rke2nodetoken))
- [Host ↔ Cluster Comms Doctrine](./host_cluster_comms_doctrine.md) — the host-only NodePort hop that is deliberately not PKI-secured
- [Substrate Doctrine](./substrate_doctrine.md) — the no-environment-variables / no-`PATH` contract
- [Testing Doctrine](./testing_doctrine.md) — flagged test credentials and the elevated-only storage-deletion model
- [Chaos / Failover Doctrine](./chaos_failover_doctrine.md) — the proven/tested/assumed ledger and the sealed-Vault red-team surface
- [Development Plan](../../DEVELOPMENT_PLAN/README.md)
- [Documentation Standards](../documentation_standards.md)
