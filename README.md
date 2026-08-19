# amoebius

>
**Purpose**: Entry point for amoebius — an everything-orchestrator and bounded low-code UI runtime whose
> Dhall DSLs make illegal deployment and application states unrepresentable where their modeled boundaries
> permit that claim.
>
**Read this if**: amoebius is unfamiliar, or a starting point into its documentation is needed.

This page states what amoebius is and routes into the corpus; it owns no doctrine and no schedule. The design
is owned by the doctrine set under [`documents/`](./documents/README.md), phase order and status by
[`DEVELOPMENT_PLAN/README.md`](./DEVELOPMENT_PLAN/README.md), and the sequence in which to read either by
[`documents/reading_order.md`](./documents/reading_order.md). The phase tracker is the authority for what is
built and validated; this page describes the target architecture and does not promote planned surfaces to
tested results.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: documents/engineering/daemon_topology_doctrine.md
**Generated sections**: none

</details>

---

amoebius has one Haskell **runtime binary** with closed responsibilities for its bootstrap/host command mode,
**sudo-capable host daemon**, **in-cluster control-plane daemon**, **capacity scheduler**, and **unelected
workers**. A separate thin Python `pb` program is the pre-binary bootstrap coordinator and post-handoff admin-REST client; it
is an operator frontend, not another runtime role or control plane. The worker set
includes the generic UI server and owner-scoped UI projector as well as linked workflow and ML roles; an
application does not introduce another executable or privileged server.

Every detected hardware substrate can always run the baseline **`linux-cpu`** lane, at that host's **natural
architecture** and at no other. Linux runs it natively, Apple supplies it through Lima at `arm64`, and
Windows supplies it through WSL2 at `amd64`; a Linux-CUDA host can select the same CPU-only lane, at its own
architecture, without exposing its accelerator. Nothing is validated under emulation or built through a
cross-toolchain, so covering both architectures takes two machines. When a gate needs a **pristine Linux
host**, the provider is fixed by the physical substrate: **Incus on Linux or Linux-CUDA, Lima on Apple, and
WSL2 on Windows**. The complete mapping and its tested/assumed status live in the
[substrate plan](./DEVELOPMENT_PLAN/substrates.md) and
[substrate doctrine](./documents/engineering/substrate_doctrine.md).

Only authored inputs and reviewed external source belong in version control. Every amoebius-owned byte stays
inside this checkout. `.build/` holds reproducible, transient, and evidentiary output; `.data/` holds
operator-retained production runtime and durable state; `.test_data/` holds only harness-owned test state and
is never allowed to alias `.data/`. Builds, temporary files, caches, kubeconfigs, virtual disks, container
engine data, run bundles, and local attestations all resolve beneath one of those roots. The complete closed
root set, lifecycle split, repository tree, and required ignore coverage are owned by the
[repository-layout doctrine](./documents/engineering/repository_layout_doctrine.md).
Python interpreter bytecode is the one source-adjacent cache exception: Python uses its normal cache behavior,
while `.gitignore` and `.dockerignore` exclude every `__pycache__` directory and bytecode suffix.

Secrets never appear in the production DSL. A sensitive field carries a typed *reference* — a name — and the value lives
only in the cluster's Vault: the CLI prompts the operator and writes straight into Vault, so no cleartext
secret is ever at rest on the filesystem in production. Because admitting a spec proves that every secret it
names already exists in Vault, and refuses before any effect otherwise, **Vault necessarily precedes every
live provider deployment**. The typed reference, the prompt-to-Vault path, the admission proof, and the
test-only seam that automates the prompt are owned by the
[Vault/PKI doctrine](./documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value).
Root `test-secrets.dhall` is the sole cleartext secret-at-rest exception. It is ignored, test-only, feeds the
same prompt-to-Vault path, and every production command must reject it rather than reading or copying it.

Every service the cluster runs ships in **one image amoebius builds** — an Ubuntu-based container carrying
every third-party service binary, installed by preference from `apt`, then an official artifact, then source.
There is one Dockerfile, rendered from a typed bake catalog rather than hand-maintained, and it names no
digest anybody typed: the parent is an authored channel and the digest is resolved per run. Each architecture
is built natively and published under its own tag — no emulation, no cross-build, and no index joining two
halves that no single machine ever ran. The base image is published so a consumer pulls a toolchain rather
than rebuilding it; **no workload pulls from a public registry**, and every image a cluster runs comes from
that cluster's own registry. The one dependency that does not join it is the browser: an end-to-end gate
drives chromium, firefox and webkit from a separate image built on demand, because a renderer no pod reaches
does not belong in the image every pod runs. The build/publish contract, the acquisition ladder, and the
bounded host-bootstrap exception are owned by the
[image-build doctrine](./documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster).

**Observed implementation — refreshed 2026-08-16.** The natural-architecture amendment reopened every phase:
Phase 0 is Active and Phases 1–74 are Blocked, each returning to work in numeric order. No prior seal records
the architecture it proved, and the one that claimed two reached the second under emulation, so every earlier
result is an observed footprint rather than a current pass. The amendment also split the image phase — Phase 36
builds and publishes its own architecture's child, and a new Phase 73 adds the complementary child on its own
hardware and publishes it under its own architecture-qualified tag — which shifted the phases above it by one.
Earlier capability results remain historical evidence until their owner phase reruns; later tools still contain
legacy repository-root, system-temp, user-home, and host-global container-engine assumptions. The exact
current and historical divergences, their owners, and their closure conditions are recorded in the
[legacy register](./DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md); the
[development-plan tracker](./DEVELOPMENT_PLAN/README.md#current-implementation-audit) controls migration order
and is the authority on status.

The binary manages Kubernetes cluster lifecycle and interprets checked `.dhall` values into opinionated
deployments and bounded low-code applications. A low-code app is finite `UiSource` data compiled into matching
client and server plans: one generic PureScript interpreter renders it, while the UI-server responsibility
mediates every effect through current authorization, trusted tenant/subject scope, and typed capabilities.
A spec that mis-binds a PVC, opens a backdoor ingress, exposes a raw browser effect, omits authorization, or
crosses a checked tenant/owner boundary is rejected at its declared validation or enforcement layer. That is a
design claim about the modeled surface, not a claim that a live provider or implementation is defect-free; the boundary is
stated precisely in the [verification doctrine](./documents/engineering/testing_doctrine.md), the
[low-code UI doctrine](./documents/engineering/low_code_ui_runtime_doctrine.md), the
[realtime-coordination doctrine](./documents/engineering/ui_realtime_coordination_doctrine.md), the
[browser-offline doctrine](./documents/engineering/browser_offline_runtime_doctrine.md), and the
[honesty rule](./documents/documentation_standards.md#6-honesty-the-proventestedassumed-discipline).

Its constituent capabilities are unified libraries, not separate products: **prodbox** supplies root
control-plane behaviour, **infernix** and **jitML** supply trusted ML/workflow adapters, and **hostbootstrap**
supplies the bootstrap and DSL core. The sibling demo SPAs are UX evidence and migration fixtures; they are not
amoebius application code or authority surfaces.

Every amoebius-managed Kubernetes cluster — root, child, self-managed, or provider-managed — has
**ephemeral infrastructure** and independently retained durable backing. Ephemeral means replaceable, not
TTL-bound or automatically torn down: a rebuilt cluster reconciles toward the persistent root `InForceSpec`
and reattaches retained backing
([cluster lifecycle](./documents/engineering/cluster_lifecycle_doctrine.md), [storage lifecycle](./documents/engineering/storage_lifecycle_doctrine.md)).

## Where to start

- **Never seen this before:** [`documents/reading_order.md`](./documents/reading_order.md) — the sequenced
  path through the corpus. About three hours end to end; the first two stops, about forty minutes, are enough
  to follow a design discussion.
- **An unfamiliar term:** [`documents/glossary.md`](./documents/glossary.md) — the routing table from every
  amoebius term and acronym to the section that owns it. It defines nothing; it routes.
- **The plan:** [`DEVELOPMENT_PLAN/README.md`](./DEVELOPMENT_PLAN/README.md) — the single, authoritative,
  numerically-ordered phased plan that delivers the vision. Phase 0 is the complete documentation suite.
- **The doctrine:** [`documents/README.md`](./documents/README.md) — the top-level index of all doctrine:
  the engineering family (the DSL, platform services, storage, secrets, runtime, verification) and the
  illegal-state catalog family.
- **How docs work:** [`documents/documentation_standards.md`](./documents/documentation_standards.md).
- **How amoebius is tested:** [`documents/engineering/testing_doctrine.md`](./documents/engineering/testing_doctrine.md)
  — a test *is* an amoebius deployment: a spec composed with a chaos schedule, a typed expectation surface,
  and a mandatory teardown. Validation runs in three phase-gate registers (1 pure/golden · 2
  boundary-with-fakes · 3 live), plus the Register-2.5 deterministic-simulation activity, which is never
  itself a phase gate; every gate emits an untracked proven/tested/assumed ledger, externally attested against
  the source snapshot it ran on, that states which layer it reached and marks the rest UNVERIFIED.
- **How the repository is laid out:**
  [`documents/engineering/repository_layout_doctrine.md`](./documents/engineering/repository_layout_doctrine.md)
  — the complete authored/generated tree, dependency-resolution policy, and ignore contracts.
- **How low-code applications work:**
  [`documents/engineering/low_code_ui_runtime_doctrine.md`](./documents/engineering/low_code_ui_runtime_doctrine.md)
  — bounded Dhall UI programs, one checked value projected into client/server plans, typed effects,
  single-/multi-tenant isolation, workflow/model lifting, rollout, and the honest HA boundary; its
  [realtime companion](./documents/engineering/ui_realtime_coordination_doctrine.md) fixes replicated
  WebSocket routing through ephemeral Redis, while its
  [offline companion](./documents/engineering/browser_offline_runtime_doctrine.md) fixes bounded encrypted
  local continuity and authoritative replay.

## Toolchain

Python `pb` is the pre-binary bootstrap coordinator and post-handoff operator client. Compilers, package tools,
libraries, and browser dependencies resolve dynamically from authored compatibility requirements. Resolved
versions, paths, dependency graphs, and integrity observations are generated per run and never committed.

A tool that is absent is **installed, not reported as a prerequisite**, beneath the ignored build root. What a
host must already supply is short and per-substrate: the package manager amoebius installs through — Homebrew,
the system package manager, or winget — plus the Xcode Command Line Tools on Apple, and firmware
virtualization enabled on Windows. The complete floor, and what is ensured rather than required, live in the
[substrate doctrine](./documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply).

## Working agreement

LLMs/assistants must not run `git add`, `git commit`, or `git push`; staging and committing are reserved
for the human (see [`AGENTS.md`](./AGENTS.md); [`CLAUDE.md`](./CLAUDE.md) mirrors the same restriction).
