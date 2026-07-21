# Phase 14: Python midwife + substrate detect + single kind cluster

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_15_base_image_registry.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/resource_capacity_doctrine.md
**Generated sections**: none

> **Purpose**: Specify the first live phase — the Python `pb` midwife that ensures a toolchain and builds the
> binary before any `PATH` discipline can run, live substrate detection, the absolute-path-only host tool-ensure,
> and an idempotent `pb bootstrap --distro=kind` that brings up an empty single-node kind cluster, records its
> complete observed resource inventory, cross-checks the declared topology against that inventory, and is a
> no-op on re-run.

---

## Phase Status

📋 Planned. This is the **first live phase** — the crossing from the pure/in-process pre-cluster band into
**Register 3** on the **linux-cpu** substrate. Nothing here is implemented; every sprint below is design intent,
and every `Implementation` field names a **target** path in the intended layout, not an existing one. The gate
has not run on any substrate. Per [development_plan_standards.md §K](development_plan_standards.md), no sprint is
marked Done — or 🧪 Live-proof-pending — until its proof actually runs live on `linux-cpu`. The mechanisms this
phase composes exist as **sibling evidence, not amoebius results**: the `hostbootstrap` seed carries the
`classify`/`detect` detector, the closed `HostTool` enum, the unexported `AbsExe` newtype, and the
`installAndVerify` driver; the lazy package-manager tool-ensure is proven prior art in the sibling ML projects;
and the midwife is ported from a prior Python detector. None has been built or run as amoebius.

## Phase Summary

This phase delivers the smallest slice of amoebius that **acts on a real host and stands up a real cluster**. It
opens only after the pre-cluster band (Phases 1–13) is green, and it composes four things: the Python `pb`
midwife that gets a built amoebius binary onto a bare host before any Haskell `PATH` discipline can exist; live
substrate detection that learns what the machine *is*; the no-environment / no-`PATH` lazy tool-ensure that
resolves `ghcup`/`cabal`/`kubectl`/`kind` — and pointedly **not** Helm — through the substrate's package manager
and invokes each by absolute path; and an idempotent single-node kind bring-up driven as a reconcile. The
cluster it produces is deliberately **empty**: no platform services, no retained storage, no Vault, no
control-plane singleton — those land in Phase 15 onward. Before `kind create`, bootstrap observes physical-host
residual CPU, memory, and named disk pools and proves the declared kind engine/node-container demand fits,
including every ordinal's node capacity + in-node reserve inside its container and the separate host-only
engine reserve, logical pod-ephemeral budget, and layout-routed image demand. Each container is charged once. A
failure has no create continuation. The reserve is not one unexplained disk number: the control-plane node contains a finite
`ControlPlaneStorageDemand` whose version-pinned etcd model derives backend, bounded WAL, snapshot-save, and
serialized defrag transition peaks (Events derived solely from `etcd.logical.churn` and included once), plus
bounded apiserver audit and
kubelet/container-runtime logs, and the sum fits its named physical carve. The selected canonical kubelet
filesystem layout is realized as either `Unified` or `SplitRuntime`: the generated kind/runtime configuration
places the nodefs and containerd content/snapshot roots on the declared hard-capped backing identities, never
on nominal independent budgets over one hidden filesystem. After creation and before handoff, bootstrap
records a typed observed inventory: node allocatable CPU, memory, logical local ephemeral storage, the observed
filesystem layout and its mount/quota identities, all resident CRI content/snapshots, and the enforced
image-pull concurrency policy; disjoint host
durable-storage and optional native-host-cache backing pools; and the closed accelerator offering, including
each CUDA device/profile, raw VRAM, mandatory driver/runtime reserve, net allocatable VRAM, and current free
VRAM (observed as `None` on the linux-cpu gate host). The declared target
topology must be no larger than and capability-compatible with that observation. The three load-bearing claims
this gate proves are that bring-up is an **idempotent reconcile** (re-running changes nothing), not a one-shot
script; that **every** external invocation went through an `AbsExe` absolute path rather than a bare-name
`PATH` lookup; and that an empty cluster is not reported usable when its real resource/capability inventory
cannot satisfy the pure declaration.

The midwife is a **Python `pb` CLI, not a shell script**. amoebius owns no shell script; the earlier
`bootstrap.sh` igniter is retired ([legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md)). `pb`
is one CLI with two modes — **midwife** (bare host → toolchain → build → `exec` the binary, this phase) and
**admin-REST client** (the operator CLI that drives the singleton after handoff, a later phase) — so the
per-substrate pre-binary surface is exactly the package-manager-root bootstrap and nothing else.

**Substrate:** linux-cpu (the default validation substrate; tracked in [substrates.md](substrates.md), per
[development_plan_standards.md §L](development_plan_standards.md)). The Apple/Windows package-manager roots and
the Lima/WSL2 providers named in the substrate doctrine are explicitly **not** exercised by this gate; they land
in the Apple/Windows phases.

**Register:** 3 (live infrastructure) — the gate provisions a real kind cluster on a real `linux-cpu` host and
tears down leak-free; a Register-1/2 in-process check cannot discharge it.

**Gate:** on a `linux-cpu` host with a container runtime pre-installed, the Python `pb` midwife's
`pb bootstrap --distro=kind` ensures the package-manager root, the pinned GHC 9.12.4 / Cabal 3.16.1.0
toolchain, and a built binary, then `exec`s `amoebius bootstrap --distro=kind`, which brings an empty
single-node kind cluster to exactly one `Ready` node (`kubectl get nodes` shows one node, `Ready`) **only after**
a physical-host observation proves the complete kind engine carve fits; records a
complete observed inventory of allocatable CPU/memory/logical local-ephemeral capacity, canonical
`Unified | SplitRuntime` nodefs/imagefs backing and quota identities, resident CRI content/snapshots, disjoint
durable/native-host-cache backing pools, and accelerator devices/profiles/per-device
raw/reserved/allocatable plus current-free VRAM; and proves the decoded target's declared
capacity/capability is no greater than and compatible with that inventory (the linux-cpu observation has no
CUDA offering);
**re-running the identical command reports already-converged and changes nothing** — where "changes nothing"
means the observable triple `(docker/podman container id/name/image/state, `kind get clusters`, kubeconfig file bytes)` — the container element compared as a normalized id/name/image/state projection, not the volatile uptime/status column — is
byte-for-byte identical before and after the re-run, and the `execve` audit log for the re-run contains **zero
mutating package-manager or `kind create` invocations**; from at least one named partially-converged start
state the identical run **converges without recreating the cluster** (divergence-repair, Sprint 14.4); **every
external tool invocation during the run resolved through an `AbsExe` absolute path** as witnessed by the
`execve` audit log (every `argv[0]` absolute, drawn from the resolved tool map), no bare-name `PATH` lookup,
and Helm is never ensured or invoked (no `helm` `execve`, no `helm` trap fired); and the gate ends by tearing
the cluster down (`kind delete cluster`) and asserting a **leak-free postflight sweep** (no residual kind
cluster, node container, or kubeconfig context).

The committed fixtures, seeded mutants, and independent observers this gate is checked against are named in the [`## Gate integrity`](#gate-integrity) section below (§M Gate → Gate-integrity delegation).

## Gate integrity

<a id="gate-integrity"></a>

**Gate prerequisite (stated, not ensured):** a container runtime (Docker or Podman) is a **pre-installed host
prerequisite** of this gate, *not* a member of the closed `HostTool` enum. `kind` cannot create a cluster
without one, but amoebius does not provision it; the enum stays exactly `ghcup`, `cabal`, `kubectl`, `kind`,
and the package-manager root. The gate preflight records the runtime's presence in the ledger as an assumed
input; the enum's closedness (no sixth member) is asserted structurally in Sprint 14.2.

**External-observer requirement (§M.5).** Every "how it behaved" assertion in this gate — every invocation went
through an absolute path, zero Helm, zero mutating package-manager calls on a re-run — is read from an
**OS-boundary observer**, never a trace the code under test emits about itself. The process-invocation observer
of record is an `execve` audit log (`strace -f -e trace=execve,execveat` or an equivalent eBPF/auditd capture)
wrapping the entire process tree of the run, committed as a gate artifact. Resource enforcement is observed
independently through effective process argv/config, cgroup, mount/device/quota, CRI content/snapshot, and
filesystem high-water reads. As a redundant process trap, the run also executes with
`PATH` pointed at a directory of same-named trap executables (`kind`, `kubectl`, `helm`, `apt`, …) that abort
loudly and log if invoked by bare name; any trap firing fails the gate. A self-emitted `runTool` compliance
trace is **not** an admissible observer for any of these assertions.

**Oracle-pinning (§M.1).** The gate's oracles are authored and **committed in Phase 0**, before any
implementation exists: the `classify` decision table (Sprint 14.1), the per-substrate `[InstallStep]` golden
plans and the `mkAbsExe`-reject expected-error set (Sprint 14.2), and the named divergent-start fixtures with
their expected converged observation (Sprint 14.4). A golden regenerated from the implementation is not
admitted.

**Committed seeded mutants (§M.2).** The gate re-runs against committed mutants that MUST go red: (M1) a
`classify` guard-negation that drops the "present NVIDIA GPU promotes Linux to `linux-cuda`" rule; (M2) an
`Ensure` variant that resolves one tool by bare name (`execve` argv[0] non-absolute) — the observer must catch
it; (M3) a bring-up that replaces the reconciler with the `kind get clusters | grep` one-shot guard — the
divergence-repair fixture must go red against it; and (M4) a bootstrap that invokes `kind create` before the
host→engine fold — the zero-create overdraw fixture must catch it; (M5) an etcd storage fold that substitutes a
steady-state WAL/backend estimate and omits transition workspace — the one-byte transition fixture must catch
it; and (M6) a kind config renderer that swaps/aliases runtime roots or omits their hard quota — the independent
layout readback must catch it. A gate run in which any of M1–M6 stays green is void.

## Doctrine adopted

- **Substrate doctrine §6 — the midwife contract (a Python `pb` CLI, not `bootstrap.sh`).** This phase
  implements [`substrate_doctrine.md` §6 — the midwife contract: a Python CLI ensures a toolchain, builds the
  binary, hands off](../documents/engineering/substrate_doctrine.md#6-the-midwife-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off):
  the thin pre-binary driver that ensures the package-manager root, installs the pinned toolchain via `ghcup`,
  `cabal build`s, and `exec`s `amoebius bootstrap --distro=…`. It is Python because it runs on a bare host
  before any Haskell toolchain exists and because it is unified with the operator CLI — one `pb` with two modes,
  the second being the admin-REST client in
  [`bootstrap_sequence_doctrine.md` §5 — the admin control plane](../documents/engineering/bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api).
- **Substrate doctrine §2 — detection as a pure classification over three reads.** This phase adopts
  [`substrate_doctrine.md` §2 — detection: a pure classification over three reads](../documents/engineering/substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads):
  a total `classify` over three runtime reads (OS, normalized architecture, NVIDIA-GPU presence), with the two
  hard-failure rules encoded (Apple is always `arm64`; a present NVIDIA GPU promotes Linux to `linux-cuda`), and
  the only `IO` being the reads — the substrate is detected, never configured.
- **Substrate doctrine §3 — the no-environment / no-`PATH` lazy tool-ensure contract.** This phase implements
  [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
  probe → install-if-absent → resolve absolute path → invoke by full path; the closed `HostTool` enum, the
  unexported `AbsExe` constructor that makes a bare-name invocation unrepresentable, and — for this phase —
  ensuring `ghcup`/`cabal`/`kubectl`/`kind` but **not** Helm (amoebius renders and applies its own typed
  manifests and never shells out to Helm).
- **Cluster lifecycle doctrine §1, §2, §9 — two cluster kinds and bring-up-as-reconcile.** This phase
  implements the self-managed half of
  [`cluster_lifecycle_doctrine.md` §1 — two cluster kinds, one lifecycle shape](../documents/engineering/cluster_lifecycle_doctrine.md#1-two-cluster-kinds-one-lifecycle-shape)
  (the host-binary-present `kind`/`rke2` cluster, in its root single-node form),
  [`cluster_lifecycle_doctrine.md` §2 — bring-up and bootstrap](../documents/engineering/cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap)
  (whose load-bearing claim for this gate is "bring-up is itself a reconcile" — re-running when already
  converged is a no-op), and the reconciler shape of
  [`cluster_lifecycle_doctrine.md` §9 — how bring-up and teardown are implemented: the reconciler, not a state
  machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
  (`discover → diff → enact → re-observe`). The provider-managed half and post-bring-up init (Vault, the
  `.dhall` handoff) are later phases.
- **DSL doctrine §3 — the orchestration surface: parameters, context, witness.** The in-binary `bootstrap`
  command the midwife hands off to carries a typed host context per
  [`dsl_doctrine.md` §3 — the orchestration surface: parameters, context, witness](../documents/engineering/dsl_doctrine.md#3-the-orchestration-surface-parameters-context-witness):
  parameters (substrate, distro, replicas), context (where the binary sits), and witnesses (locally-checkable
  runtime facts), adapted to the no-environment-variable invariant via file/socket-existence witnesses rather
  than `PATH`/env kinds. The pure Step/Chain kernel this rides on is already delivered pre-cluster.
- **Resource-capacity doctrine §8 — declared in pure input, provisioned before render, cross-checked at
  runtime.** This phase establishes the
  first live inventory required by
  [`resource_capacity_doctrine.md` §8](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime):
  allocatable CPU, memory, and logical local ephemeral storage; canonical kubelet filesystem backing and
  content/snapshot-root identities; disjoint durable/native-host-cache pools; and the closed accelerator/device/
  net-allocatable-VRAM offering. A declared target that exceeds or contradicts the observation is refused before
  any platform workload or storage object is created.

## Sprints

## Sprint 14.1: Live substrate detection 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Substrate.hs` (target: the total `classify` plus the three-read `detect`)
**Blocked by**: Phase 13 gate (the pre-cluster band closes; this is the first live phase).
**Independent Validation**: a unit table of `classify` over the enumerated cross-product asserts each expected
substrate and each expected hard failure with zero host I/O, checked against a **Phase-0-committed
hand-authored decision table** (§M.1, §M.3) that is written independently of `classify` — never regenerated
from it. The representative set is defined explicitly (§M.7): OS ∈ {`"linux"`, `"darwin"`, one unknown-OS
sentinel e.g. `"freebsd"`}, arch ∈ {`"x86_64"`/`amd64`, `"aarch64"`/`arm64`, one unknown-arch sentinel e.g.
`"ppc64le"`}, GPU ∈ {present, absent} — the full 3×3×2 = 18-cell product, so that the unknown-OS and
unknown-arch `Left` cases are exercised, not merely the four known-good substrates. The committed table pins
the expected `Right Substrate` or `Left <reason>` for all 18 cells, including the two load-bearing hard
failures (Intel-Mac `darwin`+`amd64` → `Left`, and Linux+GPU → `linux-cuda`). No cell in this linux/darwin
representative set produces the `windows` catalog member, so the `windows` output arm is pinned by the Windows
phase's oracle, not this gate's. On the gate host, `detect`
returns `linux-cpu`.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`.

### Objective
Adopt [`substrate_doctrine.md` §2 — detection: a pure classification over three reads](../documents/engineering/substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads):
learn what the host *is* by classifying three runtime reads (OS, normalized architecture, NVIDIA-GPU presence)
into the closed substrate set, with the only `IO` being the reads — the substrate is a fact about the host, not
a knob.

### Deliverables
- A total `classify :: OsName -> RawArch -> Gpu -> Either String Substrate` over the four-member catalog with
  the two load-bearing hard-failure rules encoded: Apple is always `arm64` (Intel-Mac rejected), and a present
  NVIDIA GPU promotes Linux to `linux-cuda`.
- An `Either`-returning `detect :: IO (Either String Substrate)` wrapping `classify` over the three reads
  (non-`amd64`/`arm64` a hard `Left`), classifying the gate host as `linux-cpu` (no GPU).
- A **Phase-0-committed independent decision table** (the 18-cell OS × arch × GPU oracle, authored before
  `classify` exists and never regenerated from it) and the committed `classify` mutant M1 (GPU-guard negated)
  that Validation 2 turns red.

### Validation
1. Unit-test `classify` across the enumerated 18-cell cross-product (OS × arch × GPU, including the unknown-OS
   and unknown-arch sentinels) with no host access, asserting each cell against the Phase-0-committed
   independent decision table — including the Intel-Mac and Linux+GPU hard-failure cells, and the two sentinel
   `Left` cells. **Specific-reason negatives (§M.8):** each `Left` cell asserts its *expected reason string/tag*
   (e.g. `apple-arm64-only` for `darwin`+`amd64`, `unknown-arch` for the arch sentinel), paired with the
   positive that differs only in the foreclosed dimension (`darwin`+`arm64` → `Right apple`).
2. **Committed mutant M1 (§M.2):** re-run test 1 against the committed `classify` mutant with the GPU-promotion
   guard negated; assert the Linux+GPU cell flips and the test goes **red**. A run where M1 stays green is void.
3. Run `detect` on the `linux-cpu` gate host; confirm it returns `linux-cpu`.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 14.2: No-`PATH` lazy tool-ensure — closed enum, `AbsExe`, install-and-verify 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/HostTool.hs`, `src/Amoebius/Host/Ensure.hs` (target: the `HostTool` enum
+ `AbsExe` newtype + `HostConfig` tool map + the `installAndVerify` driver)
**Blocked by**: Sprint 14.1.
**Independent Validation**: pure `[InstallStep]` plan tests per substrate asserted against **Phase-0-committed
golden plans** (authored independently of the reconciler, not regenerated from it — §M.1, §M.3), plus a
property that `mkAbsExe` rejects every non-absolute path with `cover`/`classify` obligations (§M.4) forcing the
reject branch; on the host, ensuring `kind`/`kubectl`/`cabal`/`ghcup` **from a machine-verified clean state**
(a preflight probe, recorded in the phase ledger, shows ghc/cabal/ghcup/kind/kubectl all absent before the
first run) then re-running is a **verified no-op — defined as zero mutating package-manager invocations on the
re-run, read from the `execve` audit log** (§M.5, §M.6), never inferred from an exit-0 re-run of idempotent
installers; and Helm is never ensured or invoked (no `helm` `execve`; the `helm` `PATH` trap never fires).
**Docs to update**: `documents/engineering/substrate_doctrine.md`.

### Objective
Adopt [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
ensure `ghcup`, `cabal`, `kubectl`, and `kind` — and pointedly **not** Helm — through the substrate's package
manager and invoke them only by absolute path, making a bare-name invocation structurally unrepresentable rather
than merely discouraged.

### Deliverables
- A closed `HostTool` enum naming exactly the Phase-14 tool set (`ghcup`, `cabal`, `kubectl`, `kind`, and the
  package-manager root — **five members, no sixth**; the container runtime is a stated host prerequisite, not
  an enum member; Helm is intentionally absent); an unlisted tool cannot be invoked. A structural/CI check
  asserts the enum has exactly these five constructors.
- An `AbsExe` newtype whose constructor is unexported; `mkAbsExe` rejects any non-absolute path.
- A **CI structural check that no module outside `src/Amoebius/Host/Ensure.hs` imports any process-spawn API**
  (`System.Process`, `System.Posix.Process` exec family, `typed-process`, etc.), so bring-up cannot bypass the
  `AbsExe` chokepoint with a bare-name spawn (§M.5 forecloses the self-emitted-trace bypass at the source
  level).
- A `HostConfig` carrying the detected substrate (Sprint 14.1) plus a `Map HostTool AbsExe`, and a probe-first,
  idempotent `installAndVerify` driver (probe → verified no-op if satisfied, else run the pure
  substrate-branched `[InstallStep]` plan, re-resolving after each step, then re-verify or fail fast), with
  `runTool`/`runToolWithStdin` exec-ing `absExePath` only.
- Before any post-binary package mutation, the host reader validates the remaining `ToolInstallDemand`s from
  the same `BootstrapExecutionEnvelope` against CPU/memory and named `ToolInstall` disk residual, mints a
  single-use fingerprint token, and rechecks it immediately before the install. An overdraw/unknown backing or
  changed fingerprint performs zero package-manager mutations.
- **Phase-0-committed oracles/mutants:** the per-substrate `[InstallStep]` golden plans, the `mkAbsExe`-reject
  expected-error set, and the committed mutant M2 (`Ensure` resolves one tool by bare name) that Validation 4
  turns red under the `execve` observer.

### Validation
1. Unit-test each reconciler's `[InstallStep]` plan as a pure value per substrate (no package-manager call),
   asserting equality against the **Phase-0-committed golden plans** — the reference side is the committed
   hand-authored table, never the reconciler's own output (§M.3).
2. Property-test that `mkAbsExe` rejects non-absolute paths, with a `cover`/`classify` obligation requiring at
   least 20% of generated inputs to hit the non-absolute (reject) branch and at least 20% the absolute branch
   (§M.4); a **specific-reason negative (§M.8)** asserts the reject carries the expected non-absolute-path
   error tag, paired with an absolute-path positive that succeeds. The structural/CI check confirms no module
   outside `Ensure.hs` imports a process-spawn API.
3. On the `linux-cpu` host, **record a preflight probe in the ledger showing ghc/cabal/ghcup/kind/kubectl all
   absent**, ensure the four tools from clean, then re-run; assert the re-run is a **verified no-op = zero
   mutating package-manager (`apt`/`ghcup`/`cabal`) invocations in the `execve` audit log** (§M.5), not merely
   exit-0; and confirm Helm is never ensured or invoked (no `helm` `execve`; `helm` `PATH` trap silent).
4. **Committed mutant M2 (§M.2):** re-run the host ensure under the `execve` observer against the committed
   `Ensure` mutant that resolves one tool by bare name; assert a non-absolute `argv[0]` appears (or the bare-name
   `PATH` trap fires) and the gate goes **red**. A run where M2 stays green is void.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 14.3: The Python `pb` midwife (package-manager root → toolchain → build → `exec`) 📋

**Status**: Planned
**Implementation**: `pb/pyproject.toml`, `pb/pb/cli.py`, `pb/pb/midwife.py` (target: the two-mode `pb` CLI; this
sprint delivers the **midwife** mode only — the admin-REST client mode lands with the singleton). No shell
script: amoebius owns none.
**Blocked by**: Phase 1 gate (the pinned toolchain builds the binary).
**Independent Validation**: on a bare `linux-cpu` host **whose cleanliness is machine-verified by a
preflight probe recorded in the ledger (no GHC/cabal/ghcup present)**, `pb bootstrap --distro=kind` ensures the
package-manager root (`apt`), `ghcup`, GHC 9.12.4 / Cabal 3.16.1.0, `cabal build`s the binary, and `exec`s
`amoebius bootstrap --distro=kind`; a second run with the toolchain present is a verified no-op up to the
`exec` — **no-op defined as zero mutating `apt`/`ghcup`/`cabal-install` invocations in the second run's
`execve` audit log** (§M.5, §M.6), never an exit-0 re-run of idempotent installers; the repository tree
contains no `bootstrap.sh` and no shell script.
**Docs to update**: `documents/engineering/substrate_doctrine.md`,
`documents/engineering/bootstrap_sequence_doctrine.md`, `DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md`.

### Objective
Adopt [`substrate_doctrine.md` §6 — the midwife contract: a Python CLI ensures a toolchain, builds the binary,
hands off](../documents/engineering/substrate_doctrine.md#6-the-midwife-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off):
the midwife exists because the no-`PATH` / no-env discipline cannot start until there is a Haskell binary to
enforce it, so a thin Python driver ensures the package-manager root pre-binary, then hands off. It is unified
with the operator CLI as `pb`'s midwife mode, the second mode being the admin-REST client of
[`bootstrap_sequence_doctrine.md` §5](../documents/engineering/bootstrap_sequence_doctrine.md#5-the-admin-control-plane-the-cli--the-singleton-rest-api).

### Deliverables
- A Python `pb` CLI (midwife mode) that, on `linux-cpu`, ensures the `apt` package-manager root pre-binary,
  ensures `ghcup`, installs the pinned GHC 9.12.4 / Cabal 3.16.1.0 toolchain, `cabal build`s the binary, and as
  its final act `exec`s `amoebius bootstrap --distro={kind,rke2} [--replicas=n]` (replicas defaulting to `1` on
  `kind`) — a thin driver that installs nothing beyond the toolchain root, holds no cluster logic, and never
  runs after the `exec`.
- A committed pure `BootstrapExecutionEnvelope` readable before the Haskell binary exists: bounded installer
  CPU/memory; per-tool installed and peak download/unpack bytes on named `ToolInstall` pools; and a single-
  stage cabal `BuildExecutionEnvelope` with CPU/memory, intermediate scratch, cache-write delta, and explicit
  concurrency. `pb` performs a read-only OS residual/backing/process observation, validates this envelope, and
  mints a single-use `ValidatedBootstrapExecution` bound to the fingerprint. Every apt/ghcup/cabal mutation
  and build process consumes the applicable token after an immediate fingerprint recheck; installer/build
  processes run inside the declared CPU/RSS policy and fixed scratch/cache locations.
  Its ordered install list is a unique exact join to every mutating apt/ghcup/toolchain step. Per backing the
  oracle derives `observed residents + cumulative successful installed bytes + current download/unpack
  workspace` at each step and admits the maximum; no step can execute if omitted from the envelope.
- The retirement of `bootstrap.sh` recorded in the removal ledger; amoebius owns no shell script.

### Validation
1. On a `linux-cpu` host **with a ledger-recorded preflight probe confirming ghc/cabal/ghcup absent**,
   `pb bootstrap --distro=kind` completes steps 1–4 and `exec`s the binary.
2. Re-run with the toolchain already present is a **verified no-op up to the `exec`, defined as zero mutating
   `apt`/`ghcup`/`cabal-install` invocations in the re-run's `execve` audit log** (§M.5), not merely exit-0.
3. Confirm the tree contains no `bootstrap.sh` / no `.sh` igniter.
4. Independently overdraw installer disk, cabal CPU/RSS, build scratch, and cache-write headroom by one unit;
   make a backing unknown; and change one host commitment after validation. Each case records zero mutating
   apt/ghcup/cabal calls, zero compiler processes, and zero scratch/cache writes. A fitting build is observed
   within its enforced CPU/RSS/disk/cache ceilings.
5. Drop the largest install step from the envelope, duplicate one tool id, and make prior installed residents
   plus the next download/unpack workspace exceed a `ToolInstall` backing by one byte. Exact plan/envelope
   coverage or the ordered transition formula rejects each with zero package/build mutation.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 14.4: The in-binary `bootstrap` command — idempotent single-node kind bring-up 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Cluster/Bootstrap.hs`, `src/Amoebius/Cluster/Kind.hs`,
`src/Amoebius/Cluster/Inventory.hs`, `src/Amoebius/Host/Context.hs` (target: the `bootstrap` command chain,
the kind bring-up reconciler, the complete observed-inventory reader/cross-check, and the
parameters/context/witness host context)
**Blocked by**: Sprint 14.2, Sprint 14.3.
**Independent Validation**: on a `linux-cpu` host, `amoebius bootstrap --distro=kind` yields exactly one `Ready`
node; an immediate re-run reports already-converged and **changes nothing — the observable triple `(docker/
podman container id/name/image/state, `kind get clusters`, kubeconfig file bytes)` is byte-identical before and after, and the
re-run's `execve` audit log holds zero `kind create` or mutating package-manager calls**; from at least one
**named partially-converged start state** the identical re-run **converges without recreating the cluster** and
prints an explicit per-managed-resource discover/diff result showing an empty diff; and **every external
invocation went through an `AbsExe` absolute path as witnessed by the `execve` audit log** (every `argv[0]`
absolute, from the resolved tool map — §M.5), never a self-emitted `runTool` trace; the sprint ends by tearing
the cluster down and asserting a leak-free postflight sweep. Before the first create, a distinct host reader
proves the declared `KindEngineDemand` (ordinal node-container runtime, exact `NodeCapacity`, nested in-node
reserve, separate host process reserve, structural host OCI/snapshot/data-root demand, and disk carves) fits
current physical-host residual without double debit. Its
system reserve expands the finite, version-pinned etcd backend/WAL/snapshot-save/defrag transitions,
Event retention from `etcd.logical.churn.eventRetention`, audit-log, and kubelet/runtime-log budgets; an
overdraw fixture records zero `kind create`.
The create reconcile realizes the declared `Unified | SplitRuntime` filesystem layout, pins the containerd
content and snapshotter roots to the derived physical backing, and enforces each nodefs/imagefs carve with a
hard quota. It separately realizes and probes the host Docker/Podman data-root/graphroot backing, storage
driver/model, selected kind-node image objects, active node-container snapshot/writable/log bytes, and pull
  workspace; these host-runtime bytes are outside the nested node's CRI roots. Before handoff, a distinct
  inventory reader records allocatable CPU/memory/logical local-ephemeral-storage, allocatable pod slots and
  remaining CNI/IP capacity, the driver-scoped attachment limits from `CSINode`/driver configuration, the
  observed layout plus content/snapshot roots and mount/device/quota identities,
disjoint durable/native-host-cache backing pools, and accelerator
devices/profiles/per-device raw/reserved/allocatable plus current-free VRAM, and the declared-vs-observed
cross-check succeeds; fixtures that overstate
ephemeral storage or declare CUDA on this CPU-only target fail with their specific resource/capability reason
and cause zero workload/storage API writes or host backing allocations.
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`,
`documents/engineering/substrate_doctrine.md`, `documents/engineering/resource_capacity_doctrine.md`,
`documents/engineering/dsl_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`.

### Objective
Adopt [`cluster_lifecycle_doctrine.md` §2 — bring-up and bootstrap](../documents/engineering/cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap)
and [`cluster_lifecycle_doctrine.md` §9 — the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
for the self-managed, host-binary-present, single-node kind cluster of
[`cluster_lifecycle_doctrine.md` §1](../documents/engineering/cluster_lifecycle_doctrine.md#1-two-cluster-kinds-one-lifecycle-shape),
brought up as a `discover → diff → enact → re-observe` reconcile so that **re-running is a no-op** — carrying a
typed host context per [`dsl_doctrine.md` §3](../documents/engineering/dsl_doctrine.md#3-the-orchestration-surface-parameters-context-witness)
and discharging the live-inventory cross-check of
[`resource_capacity_doctrine.md` §8](../documents/engineering/resource_capacity_doctrine.md#8-where-the-numbers-come-from-declared-in-pure-input-provisioned-before-render-cross-checked-at-runtime).

### Deliverables
- A `bootstrap` command chain that detects the substrate (Sprint 14.1), assembles a `BinaryContext`
  (parameters + context + file/socket witnesses), ensures `kind`/`kubectl` by absolute path (Sprint 14.2), and
  drives single-node kind bring-up as a genuine `discover → diff → enact → re-observe` reconcile over a
  managed-resource registry — not a one-shot script — such that each managed resource's discover/diff result is
  printed on every run.
- A pre-create
  `observePhysicalHost → provision KindEngineDemand → validateSnapshot → Either HostOvercommit
  ValidatedKindCreate` boundary. The single-use success token is bound to the complete host/process/disk/device
  fingerprint and consumed by the ordered filesystem-realization + `kind create` enactment; the fingerprint is
  re-read immediately before the first mutation, and change discards the plan with zero create/backing effects.
  Each ordinal proves
  `NodeCapacity + KindControlPlane|KindWorker reserve ≤ nodeContainer.runtime`; the physical host then charges
  the node container once plus only the separate Docker/containerd/kind-supervisor
  `KindHostEngineReserve`, including its private `ProvisionedKindHostRuntimeStorageDemand`. The in-node reserve
  is not added again. Named node-root carves are routed by the
  canonical kubelet filesystem layout rather than assumed to be disjoint: `Unified` charges nodefs, image
  content, snapshots, writable layers, and pull workspace to one backing once; `SplitRuntime` keeps nodefs
  separate and charges containerd content, snapshots, writable layers, and pull workspace to imagefs. Existing
  host processes/VMs/backing allocations are subtracted.
  The generated kind/kubelet config enforces the declared `Serial | BoundedParallel n` image-pull policy.
- A separate host-container-runtime realization from `KindHostRuntimeStorageDemand`. It pins the host
  Docker/Podman data-root/graphroot carve, storage driver/model, and pull policy; exact-joins the selected
  kind-node `ImageArtifact`; deduplicates host OCI content by digest; charges one model-derived active
  snapshot plus writable/log allowance per node-container ordinal; and adds missing-pull workspace. The
  external runtime/filesystem observer reads every content object, active snapshot, ordinal container
  writable/log usage, root mount/device/quota identity, driver/model, and pull policy. Unknown/swapped roots or
  models reject before pull/create. Two synthetic ordinals debit shared base content once but two active
  snapshots.
- A kind-filesystem realization owned by the same snapshot-bound plan. For `Unified`, the kubelet nodefs root
  and containerd content/snapshotter roots resolve to the same declared mount/device/quota identity and one
  hard byte ceiling. For `SplitRuntime`, kind `extraMounts` and the runtime/kubelet configuration place nodefs
  on one hard-capped identity and both containerd roots on a distinct hard-capped imagefs identity;
  `containerfs=imagefs` is derived, never separately authored. The independent OS/CRI observer reads the
  effective mount source, filesystem/device identity, project-or-filesystem quota id and hard limit, kubelet
  root, containerd content root, snapshotter root, and resident object/chain bytes. `SplitImage` is rejected
  because this v1 containerd engine cannot provide its required runtime/feature witness. A hidden alias,
  swapped root, soft-only quota, or capacity reported under two nominal ids is
  `BackingAlias | FilesystemLayoutMismatch`, never spare capacity.
- A mandatory finite
  `ControlPlaneStorageDemand { staticEngineBytes, etcd { backendQuotaBytes, maxWalFiles,
  retainedSnapshots, maintenance = SerializedSnapshotAndDefrag, storageModel,
  logical : EtcdLogicalDemand { desiredObjects,
  churn { maxUpdatesPerWindow, updateWindow, revisionRetention, maxActiveLeases, maxLeaseBytes,
  maxEventsPerWindow, eventWindow, maxEventBytes, eventRetention }, model } },
  audit { maxBytesPerFile, maxBackups, retention },
  kubeletRuntimeLogs { maxBytesPerFile, maxBackups, retention }, historyRequirement }` nested inside the
  control-plane node system carve. Its private, version-pinned `etcdPhysicalPeak` derives the backend-at-quota;
  the `maxWalFiles` resident set plus modelled WAL segment maximum/overshoot and preallocated-next segment;
  retained snapshots plus snapshot-save temporary overlap; and defrag's old+new backend-copy peak. Because the
  only v1 maintenance arm serializes snapshot and defrag, it takes the modelled maximum transition rather than
  inventing concurrent workspace. There is no caller-authored WAL-byte aggregate, exact-segment assumption, or
  quota-sized-snapshot shortcut. Before that physical expansion, the exact serialized desired/live
  Kubernetes objects plus bounded old/new/apply revisions, Leases, and Events pass through the pinned MVCC
  model and must fit `backendQuotaBytes`; a physically large system carve cannot excuse a logical quota
  overflow. Every kube-system ConfigMap/Secret/projected/token volume also derives
  `KubeletMappedFileDemand`; its AtomicWriter old+new/symlink/metadata bytes route to nodefs or memory and enter
  the addon pod envelope. The four Event operands
  `{ maxEventsPerWindow, eventWindow, maxEventBytes, eventRetention }` have exactly one
  authority: `etcd.logical.churn`. They derive the logical Event peak and its controls; only
  `eventRetention` projects the apiserver Event TTL. Events remain inside the backend quota; log rotation uses
  `(maxBackups + 1) × maxBytesPerFile`; and Event/audit retention covers `historyRequirement` (at least the
  longest live-gate observation window). Generated etcd/apiserver and maintenance-runner configuration projects
  the exact backend quota, `maxWalFiles`, retained-snapshot count, serialized policy, Event TTL, and log
  rotation/retention. Generated mounts place etcd data/WAL, retained snapshots and maintenance workspace,
  apiserver audit, and kubelet/runtime system logs on the one named system carve. An external
  process/config/path/mount/quota readback must equal those operands and backing identity. No control-plane byte
  is hidden in pod ephemeral or node image storage.
- An empty cluster as the end state: one node, `Ready`, with **no** platform services (those are Phase 15+).
- A typed `ObservedInventory` assembled from an independent apiserver/OS-boundary read: net node allocatable
  CPU, memory, logical local ephemeral storage, `status.allocatable.pods`, remaining CNI/IP slots, and the
  lesser of declared/SKU and observed `CSINode` driver attachment limits; current pod and unique-PVC
  attachments spend those residual maps. Its explicit `ObservedNodeRuntimeStorageInventory` records the
  witnessed `Unified | SplitRuntime | SplitImage` layout, role→root physical mount/device/quota identities,
  kubelet/CRI metadata components, containerd content/snapshot roots, resident OCI objects/snapshot chains,
  missing/pulling/failed-partial workspaces, and the exact enforced image-pull policy; separately-owned durable
  and optional native-host-cache
  backing pools with no double-counted bytes; and
  `NodeAcceleratorOffering = None | CudaOffering { devices, links }` with stable profile, link endpoints/kinds,
  and per-device `{ rawVram, driverRuntimeReserve, allocatableVram }`, plus the separately observed current-free
  value used only by live residual admission. The constructor proves
  `driverRuntimeReserve + allocatableVram ≤ rawVram`; neither raw total nor product label is spendable.
  (The physical-host-only `AppleMetalOffering` is outside this linux-cpu node gate and lands
  in Phase 35.) The bootstrap handoff exists only after `declaredCapacity <= observedCapacity` on every
  quantity and exact accelerator-family compatibility; linux-cpu must observe `None`. Unknown CNI/CSI limits,
  a lower observed pod-slot bound, or an unexplained live attachment refuses the handoff.
- An engine-system accounting rule: every kind node has an enforced role-indexed `EngineSystemReserve`.
  The control-plane node has kubelet, apiserver, etcd, controller-manager, scheduler, and node-overhead
  envelopes; workers have kubelet/node overhead. Those are nested inside their node-container runtime. A
  separate `KindHostEngineReserve` contains only host Docker/containerd/kind-supervisor work plus the
  structural host runtime-root image/snapshot/writable/log/pull demand. The test oracle
  recomputes `Σ nodeContainer.runtime + hostReserve`, and a mutant that adds the in-node reserve twice goes
  red. Generated kind static-pod/kubelet/runtime configuration projects each in-node process's CPU/memory
  envelope; host Docker/containerd/supervisor processes run in host cgroups with the exact host-reserve
  settings. An OS/cgroup observer compares every configured/runtime ceiling to its
  `EngineProcessEnvelope`; aggregate container fit is not a substitute. Every kube-system addon Pod/controller
  not inside that reserve is topology-expanded with stable identity and explicit CPU/memory/ephemeral
  requests+limits, private allowances, image/runtime-storage metadata, controller policy, and maximum
  termination/replacement overlap. A missing addon ceiling is `UnknownCommitment`, not silently free.
  These bootstrap add-ons may still use `default-scheduler` in this Phase-14 empty-cluster state; the later
  cutover of these `default-scheduler` bootstrap add-ons onto the managed capacity scheduler — subtracting them
  as foreign/static commitments, minting `BootstrapCapacitySchedulerReady` then `ManagedCapacityReady`, and
  leaving the scheduler bootstrap Pod as the sole `default-scheduler` exception — is Phase 16's scope and is
  specified there.
- **Phase-0-committed divergent-start fixtures** (§M.1) with their expected converged observation, and the
  committed mutant M3 (reconciler replaced by a `kind get clusters | grep <name>` one-shot guard) that the
  divergence-repair validation turns red.
- A **teardown + leak-free postflight sweep** (`kind delete cluster`, then assert no residual kind cluster,
  node container, or kubeconfig context) that closes the gate.

### Validation
1. **Gate.** On a `linux-cpu` host (container runtime pre-installed), `amoebius bootstrap --distro=kind`; assert
   `kubectl get nodes` shows exactly one `Ready` node.
2. **Pre-create host→engine admission.** Run the one-field `kind_engine_memory_exceeds_host` and
   `kind_engine_disk_exceeds_host` fixtures, plus `control_plane_storage_exceeds_system_carve_by_one` and
   `etcd_transition_peak_exceeds_system_carve_by_one`, `control_plane_history_too_short`, and a
   `SplitRuntime` fixture that aliases nodefs/imagefs. Also run a host-runtime-root fixture whose nested
   `NodeCapacity` fits but host OCI content + active snapshot + writable/log + pull workspace is one byte over,
   and unknown/swapped graphroot/storage-model fixtures; removing one required static process envelope is
   `UnknownCommitment`. Each must fail before mutation with its specific capacity/layout reason, and the
   external `execve`/runtime observer must record zero `kind create` and zero new node containers/backing
   allocations. The paired fitting engine differs only in the reduced demand and creates successfully.
   The independent oracle proves for each ordinal
   `NodeCapacity + inNodeReserve ≤ nodeContainer.runtime` and then
   `Σ nodeContainer.runtime + KindHostEngineReserve ≤ host residual`; the committed double-add-in-node-reserve
   mutant must go red. A fixture changes one observed host commitment after validation but before create; the
   immediate fingerprint recheck invalidates the single-use token and records zero `kind create`/backing
   effects.
   A two-ordinal pure fixture proves equal kind-node image content is digest-deduplicated once while two active
   snapshots/writable allowances are charged; dropping the second active snapshot turns it red.
   Run isolated `Unified` and `SplitRuntime` positive creates. For `Unified`, assert nodefs, the containerd
   content root, and the snapshotter root have one mount/device/quota identity and one hard ceiling. For
   `SplitRuntime`, assert nodefs is distinct while content and snapshotter roots share the imagefs identity and
   hard ceiling. Fill each physical backing to its admitted boundary and prove the kernel quota refuses the
   next byte. The OS/CRI readback must equal the generated kind/kubelet/containerd paths and declared aliases;
   committed swapped-root, soft-quota, unrecorded-alias, and one-byte-hard-limit renderer mutants each turn the
   corresponding layout run red. `SplitImage` must fail before create as `UnsupportedEnforcement` for this
   containerd engine.
   After the positive create, read etcd's effective `--quota-backend-bytes` and `--max-wals`, the maintenance
   runner's retained-snapshot count and `SerializedSnapshotAndDefrag` lock, apiserver Event TTL, and every log
   rotation setting. Require the TTL to equal only `etcd.logical.churn.eventRetention`; require Event
   rate/window and maximum-byte controls to equal the projections of `maxEventsPerWindow`, `eventWindow`, and
   `maxEventBytes`. Prove all corresponding data,
   WAL, snapshot/temp, audit, and system-log paths resolve to the declared system-carve mount/quota identity.
   Independently fill/rotate each class to its boundary and exercise WAL rollover/overshoot plus
   preallocated-next, snapshot-save temporary overlap, and defrag old+new copy. The observed high-water mark
   must stay within the version-pinned
   `etcdPhysicalPeak` plus the static/rotated-log formula, with Events not added again, and retained Event/audit
   history must cover `historyRequirement`. One-byte-under-carve and committed transition mutants that replace
   the model with an arbitrary WAL scalar, omit WAL overshoot/preallocation, omit snapshot-save temporary
   bytes, assume in-place defrag, or permit snapshot and defrag concurrently under the serialized arm must each
   go red. Mutants that add a sibling Event-retention authority, disagree with any of the four Event churn
   operands, double-add Events, or treat `maxBackups` as the total file count also go red.
   Drive one in-node static process and one host engine process past CPU/RSS ceilings; the process-level
   cgroup/static-pod observer proves throttling or termination within its exact envelope. Mutants that omit a
   per-process projection while preserving the aggregate container/host total must go red.
3. **Declared-vs-observed resource/capability post-create cross-check.** Read the node and host through an
   observer distinct from the capacity fold; assert the recorded inventory contains CPU, memory, local
   ephemeral storage, allocatable pod slots, remaining CNI/IP capacity, per-driver `CSINode` attachment
   limits/current unique-PVC attachments, the canonical filesystem layout and exact mount/device/quota identities, containerd
   content/snapshot roots and all resident objects/chains, exact enforced image-pull policy, disjoint
   durable/native-host-cache backing pools, bounded
   kube-system commitments, and the accelerator offering with per-device raw/reserved/allocatable/current-
   free VRAM plus its device-link graph, then assert the
   pure declared target is within it on every axis. Independently enumerate/serialize live Kubernetes objects
   and addon mapped-file sources; require the modelled MVCC object/revision/Lease/Event peak to fit the observed
   etcd quota and every AtomicWriter mapped-file byte to be present in nodefs/memory accounting. Run
   `declared_ephemeral_exceeds_observed`,
   `declared_pod_slots_exceed_observed`, `declared_csi_attach_exceeds_observed`,
   `declared_etcd_logical_peak_exceeds_quota`, `declared_mapped_file_omitted`,
   `declared_filesystem_layout_mismatch`, `declared_image_pull_policy_mismatch`, and
   `declared_cuda_on_linux_cpu`: each must fail with its pinned
   resource/capability reason, and an apiserver
   audit plus host allocation observer must show **zero workload/storage API writes and zero durable/native-host-cache
   backing allocations after the failed preflight begins**.
4. **Idempotence (the gate's core claim).** Re-run the identical command; assert it reports already-converged
   and **changes nothing — the observable triple `(docker/podman container id/name/image/state, `kind get clusters`,
   kubeconfig file bytes)` is byte-identical before and after the re-run, and the re-run's `execve` audit log
   contains zero `kind create` and zero mutating package-manager calls** — leaving the single node `Ready`, and
   printing the per-managed-resource empty-diff discover result.
5. **Divergence-repair (§M — forecloses the one-shot-guard stub).** From each Phase-0-committed
   partially-converged start state — at minimum (a) the kind cluster exists but its node container is stopped /
   `NotReady`, and (b) the kubeconfig context is missing — run the identical command; assert it converges to
   exactly one `Ready` node **without recreating the cluster** (no `kind create` for an existing cluster in the
   `execve` log; cluster UID/creation-timestamp unchanged), the printed diff was non-empty then re-observes
   empty.
6. **External-observer absolute-path assertion (§M.5).** From the committed `execve` audit log of the whole run,
   assert every `argv[0]` is an absolute path drawn from the resolved tool map — no bare name, no Helm `execve`,
   and the bare-name `PATH` trap directory recorded no hits. A self-emitted `runTool` trace is inadmissible.
7. **Committed mutants M3–M6 (§M.2).** Re-run Validation 5 against the committed one-shot-guard mutant; assert at
   least one divergent-start fixture goes **red** (the guard skips repair or recreates the cluster). A run where
   M3 stays green is void. Re-run Validation 2 against the pre-create-fold-drop mutant and require the external
   observer to catch its forbidden `kind create`; M4 staying green is void. Re-run Validation 2 against the
   steady-state-only etcd fold and the swapped/soft-only filesystem renderer; the one-byte transition oracle and
   OS mount/quota/root readback must turn M5 and M6 red.
8. **Teardown + leak sweep.** `kind delete cluster`; assert the postflight sweep finds no residual kind
   cluster, node container, or kubeconfig context.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/substrate_doctrine.md` — when detection, the `AbsExe`/closed-enum tool-ensure, and the
  Python `pb` midwife land, flip the §9 planning-ownership orientation note for this phase from intent to a
  delivered-status pointer (status stays in the plan) and reconcile any seed-vs-target discovery caveats in §3.
- `documents/engineering/bootstrap_sequence_doctrine.md` — record that `pb`'s **midwife** mode is delivered here
  and that its **admin-REST client** mode (§5) remains a later phase.
- `documents/engineering/cluster_lifecycle_doctrine.md` — confirm the §2/§9 "bring-up is itself a reconcile"
  no-op shape is exercised by this phase's gate.
- `documents/engineering/resource_capacity_doctrine.md` — record Phase 14 as the first live producer of the
  complete observed inventory and declared-capacity/capability cross-check, including version-pinned etcd
  transition geometry and `Unified | SplitRuntime` mount/quota/root readback.
- `documents/engineering/dsl_doctrine.md` — record that the orchestration surface
  (parameters/context/witness) is first carried by a live typed host context here (the pure Step/Chain kernel it
  rides on was delivered pre-cluster), flipping that note from intent to a delivered-status pointer.

**Cross-references to add:**
- [README.md](README.md) — flip the Phase 14 tracker-row status once work begins and keep its link current.
- [substrates.md](substrates.md) — record `linux-cpu` as the Phase 14 gate substrate (the first Register-3 row).
- [legacy_tracking_for_deletion.md](legacy_tracking_for_deletion.md) — mark `bootstrap.sh` retired, superseded
  by the Python `pb` midwife.
- [system_components.md](system_components.md) — register the target paths named in the sprint `Implementation`
  fields (`Amoebius.Host.*`, `Amoebius.Cluster.*`, and the `pb/` Python midwife package).

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 14 row is the authoritative one-line gate and status.
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  Register-3 honesty token: a passed gate is a live-substrate result, never a compile claim).
- [overview.md](overview.md) — target architecture, the GHC 9.12.4 / Cabal 3.16.1.0 pin, and the pre-cluster →
  live boundary this phase crosses.
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — detection, the no-`PATH` lazy
  tool-ensure, and the Python `pb` midwife contract.
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — two cluster kinds and
  bring-up-as-reconcile.
- [Bootstrap Sequence Doctrine](../documents/engineering/bootstrap_sequence_doctrine.md) — the unified `pb` CLI's
  two modes (midwife here; admin-REST client later).
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the parameters/context/witness orchestration surface
  the `bootstrap` command carries.
