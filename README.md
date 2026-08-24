# amoebius

> **Purpose**: Entry point for amoebius — an **open core for distributed systems** targeting a fixed algebra
> whose lawful instances are domains and hardware substrates, plus independently reviewable evidence that
> *arbitrary compositions* of pure logic drawn from those domains are well defined at run time, so illegal
> deployment, application, and security states can be made unrepresentable at their modeled boundaries.
> **Read this if**: amoebius is unfamiliar, or a starting point into its documentation is needed.

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

The amoebius target has one Haskell **runtime binary** with closed responsibilities for its bootstrap/host command mode,
**sudo-capable host daemon**, **in-cluster control-plane daemon**, **capacity scheduler**, and **unelected
workers**. The only admitted role for Python `pb` is before that binary: make the minimum platform distinction
needed to establish the pinned toolchain, build the source-bound binary, and replace itself with that exact
binary via `exec`, forwarding every user argument unchanged. Haskell owns host-floor decisions, help,
version, validation, and every operator command. Python may not dispatch those commands, decide a validation
result, or act as a second runtime; typed Haskell keeps current out-of-bounds `pb` behaviour as an active
migration binding, explained to readers in the
[single legacy register](./DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md). The target worker set
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

**The required version-controlled behavioral-source boundary is Haskell (`.hs`) only**. This includes product,
runtime, test, gate, generator, checker, fixture, oracle, and mutant source. Python under `pb/**` is the sole
source-language exception and has only the bootstrap role above. Documentation, licences, Cabal/project
descriptions, and ignore policies are non-source inputs, not additional implementation languages. Everything
else — Dhall, PureScript, JavaScript, shell, Proto, Pulumi, Dockerfiles, serialized fixtures/oracles, rendered
manifests, SQL, browser contracts, checking tools, and materialized mutants — must be rendered lazily from
Haskell beneath `.build/**`, named by a content address that folds in its own rendered text, charged against a
budget, and reaped when its region ends. Operator values remain external or untracked inputs. **The current
tree does not yet conform**: every observed foreign-source family has a typed Haskell migration binding whose
reader-facing explanation is in the
[single legacy register](./DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md). That Markdown table supplies no
executable ID, owner, count, predicate, or closure result; a human reviewer owns its correspondence with the
Haskell inventory. Phase 0 owns the binding explained as `LTD-SRC-008` and must reduce `pb/**` to the exact
single `pb/__main__.py` inventory whose closed supported authored syntax/import/resolved-direct-call/control-flow/effect
graph statically fits the toolchain-establish/build/opaque-argv-exec role. Interpreter startup,
standard-library/native/transitive behavior, concrete adapter effects, unchanged argv, process replacement,
and exit propagation remain Phase-50 runtime observations. Every source-migration binding, including that one, must be
zero before the Phase-49 hardware-free promotion barrier may emit a candidate. Phase 49 builds and invokes the
Haskell barrier directly; it does not use `pb` as transport. Phase 50 alone validates the runtime behavior of
the already source-bounded handoff and owns no source-migration binding: the exact source-built Haskell
supervisor starts directly and invokes `pb` as its observed child subject. Phase 51 onward retains the same
closed grammar. Phase 51 remains a hardware-free Haskell host-ensure gate against fake boundaries; Phase 52 is
the first hardware-bearing validation phase. That target discipline
generalises jitML's just-in-time discipline from machine learning to everything amoebius touches, and it is
owned by the [JIT artifact doctrine](./documents/engineering/jit_artifact_doctrine.md) and the
[JIT budget doctrine](./documents/engineering/jit_budget_doctrine.md).

Only Haskell source and the closed set of non-source repository inputs belong in version control. Every
amoebius-owned generated byte stays
inside this checkout. `.build/` holds reproducible, transient, and evidentiary output; `.data/` holds
operator-retained production runtime and durable state; `.test_data/` holds only harness-owned test state and
is never allowed to alias `.data/`. Builds, temporary files, caches, kubeconfigs, virtual disks, container
engine data, run bundles, and local attestations all resolve beneath one of those roots. The complete closed
root set, lifecycle split, repository tree, and required ignore coverage are owned by the
[repository-layout doctrine](./documents/engineering/repository_layout_doctrine.md).
`pb` redirects Python bytecode, virtual environments, caches, and tool state beneath `.build/**`; no
source-adjacent cache exception exists.

Secrets never appear in the production DSL. A sensitive field carries a typed *reference* — a name — and the value lives
only in the cluster's Vault: the CLI prompts the operator and writes straight into Vault, so no cleartext
secret is ever at rest on the filesystem in production. Because admitting a spec proves that every secret it
names already exists in Vault, and refuses before any effect otherwise, **Vault necessarily precedes every
live provider deployment**. The typed reference, the prompt-to-Vault path, the admission proof, and the
test-only seam that automates the prompt are owned by the
[Vault/PKI doctrine](./documents/engineering/vault_pki_doctrine.md#3-the-secretref-contract-a-name-never-a-value).
The untracked `test-secrets.dhall` test input is the sole cleartext secret-at-rest exception. It is test-only, feeds the
same prompt-to-Vault path, and every production command must reject it rather than reading or copying it.

Every amoebius workload and third-party service except the Registry capability ships in **one image amoebius
builds** — an Ubuntu-based container carrying those service binaries, installed by preference from `apt`,
then an official artifact, then source. The sole Registry provider instead runs the fixed Distribution
`registry:2` image, pinned and preloaded as the bootstrap image; its binary is not copied into `amoebius-base`.
There is one Dockerfile per materialized image identity, rendered lazily beneath `.build/**` from a Haskell
bake catalog rather than hand-maintained, and it names no
digest anybody typed: the parent is a Haskell-declared compatibility channel and the digest is resolved per run. Each architecture
is built natively and published under its own tag — no emulation, no cross-build, and no index joining two
halves that no single machine ever ran. The base image is published so a consumer pulls a toolchain rather
than rebuilding it. The fixed `registry:2` bootstrap image is preloaded before the Registry service exists;
after it is healthy, **no workload pulls from a public registry**, and every other image a cluster runs comes
from that cluster's own Distribution registry. The browser test image also remains build infrastructure: an end-to-end gate
drives chromium, firefox and webkit from a separate image built on demand, because a renderer no pod reaches
does not belong in the image every pod runs. The build/publish contract, the acquisition ladder, and the
bounded host-bootstrap exception are owned by the
[image-build doctrine](./documents/engineering/image_build_doctrine.md#2-the-single-distribution-rule-bake-the-binaries-build-the-amoebius-image-pull-only-in-cluster).

Current implementation state, phase validation, and migration order are owned by the
[development-plan tracker](./DEVELOPMENT_PLAN/README.md). Executable divergence identities and closure
bindings are Haskell; the single
[legacy register](./DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md) explains them to readers. Nothing in
this entry point is evidence that a target surface has been implemented or validated.

The binary manages Kubernetes cluster lifecycle and interprets external, untracked `.dhall` values into opinionated
deployments and bounded low-code applications. A low-code app is finite `UiSource` data compiled into matching
client and server plans. Haskell declarations lazily generate the generic PureScript interpreter beneath
`.build/**`, while the UI-server responsibility
mediates every effect through current authorization, trusted tenant/subject scope, and typed capabilities.
A spec that mis-binds a PVC, opens a backdoor ingress, exposes a raw browser effect, omits authorization, or
crosses a checked tenant/owner boundary is rejected at its declared validation or enforcement layer. That is a
design claim about the modeled surface, not a claim that a live provider or implementation is defect-free; the boundary is
stated precisely in the [verification doctrine](./documents/engineering/testing_doctrine.md), the
[low-code UI doctrine](./documents/engineering/low_code_ui_runtime_doctrine.md), the
[realtime-coordination doctrine](./documents/engineering/ui_realtime_coordination_doctrine.md), the
[browser-offline doctrine](./documents/engineering/browser_offline_runtime_doctrine.md), and the
[honesty rule](./documents/documentation_standards.md#6-honesty-the-proventestedassumed-discipline).

**amoebius depends on no other project, and no other project depends on amoebius.** Five **seed projects** —
`hostbootstrap`, `prodbox`, `jitML`, `infernix`, and `mattandjames` — are its **reference implementations**:
each is authoritative about what its domain actually requires and about none of the solution, and amoebius
**re-derives** their pure structures under stronger obligations rather than linking them. A re-derivation is
admissible only once the doctrine specifying it names, in one sentence, the guarantee amoebius adds that the
seed's version does not carry. The strongest evidence that this algebra is discoverable rather than invented is
that the seeds converged on the same shapes independently, with no code dependency between them. The rule, the
re-derivation map, and the lift calculus are owned by the
[lift-and-compose doctrine](./documents/engineering/lift_and_compose_doctrine.md); the seed demo SPAs are UX
evidence, never amoebius application code or authority surfaces.

Because amoebius is an **open core** rather than a closed DSL, a new domain or a new hardware substrate joins by
satisfying one contract: a component in each of the five calculi — artifact, budget, lift, workflow, evidence —
and four law families, **L1–L5** per extension, **C1–C7** over composition, **S1–S6** for security, and
**P1–P6** for relational transactions. The conformance gate is *generated from the extension's own declaration*
rather than authored beside it, and a sealed verdict is what admits an extension to a link set — so composing
two unrelated extensions is safe by induction rather than by review. That contract is owned by the
[extension-conformance doctrine](./documents/engineering/extension_conformance_doctrine.md).

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
  numerically ordered phased plan that delivers the vision. Phase 0 owns the documentation suite; its status,
  like every phase's, is human-controlled and is not implied here.
- **The doctrine:** [`documents/README.md`](./documents/README.md) — the top-level index of all doctrine:
  the engineering family (the DSL, platform services, storage, secrets, runtime, verification) and the
  illegal-state catalog family.
- **How docs work:** [`documents/documentation_standards.md`](./documents/documentation_standards.md).
- **How amoebius is tested:** [`documents/engineering/testing_doctrine.md`](./documents/engineering/testing_doctrine.md)
  — a test *is* an amoebius deployment: a spec composed with a chaos schedule, a typed expectation surface,
  and a mandatory teardown. Validation runs in three phase-gate registers (1 pure with independent Haskell
  expectations · 2 boundary-with-fakes · 3 live), plus a non-gating deterministic-simulation activity.
  A gate emits only a candidate `.build/**` evidence bundle; a receipt or digest proves provenance, not
  correctness, and only the human user may promote plan status. The hardware-free DSL/generator barrier must
  be accepted before any live container, cluster, browser, provider, or accelerator gate begins; pure browser
  semantics and lazy UI generation remain part of the pre-barrier DSL proof.
- **How the repository is laid out:**
  [`documents/engineering/repository_layout_doctrine.md`](./documents/engineering/repository_layout_doctrine.md)
  — the closed tracked-source grammar, generated-state tree, dependency-resolution policy, and ignore contracts.
- **How low-code applications work:**
  [`documents/engineering/low_code_ui_runtime_doctrine.md`](./documents/engineering/low_code_ui_runtime_doctrine.md)
  — bounded external Dhall UI programs, one checked value projected into client/server plans, typed effects,
  single-/multi-tenant isolation, workflow/model lifting, rollout, and the honest HA boundary; its
  [realtime companion](./documents/engineering/ui_realtime_coordination_doctrine.md) fixes replicated
  WebSocket routing through ephemeral Redis, while its
  [offline companion](./documents/engineering/browser_offline_runtime_doctrine.md) fixes bounded encrypted
  local continuity and authoritative replay.

## Toolchain

Python `pb` is only the bounded pre-binary handoff: it makes the minimum platform distinction required
to establish the pinned toolchain, builds the source-bound Haskell binary, and `exec`s it with every argv
unchanged. Haskell owns host-floor policy and every user-visible command. Compilers, package tools,
libraries, and browser dependencies resolve dynamically from Haskell or minimal bootstrap compatibility
requirements. Resolved
versions, paths, dependency graphs, and integrity observations are generated per run and never committed.

A tool that is absent is **installed, not reported as a prerequisite**, beneath the ignored build root. What a
host must already supply is short and per-substrate: the package manager amoebius installs through — Homebrew,
the system package manager, or winget — plus the Xcode Command Line Tools on Apple, and firmware
virtualization enabled on Windows. The complete floor, and what is ensured rather than required, live in the
[substrate doctrine](./documents/engineering/substrate_doctrine.md#31-the-per-substrate-floor-what-only-the-operator-can-supply).

## Working agreement

LLMs/assistants must not run `git add`, `git commit`, or `git push`; staging and committing are reserved
for the human (see [`AGENTS.md`](./AGENTS.md); [`CLAUDE.md`](./CLAUDE.md) imports it).
