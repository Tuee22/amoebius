# Phase 14: Python midwife + substrate detect + single kind cluster

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_15_base_image_registry.md, DEVELOPMENT_PLAN/phase_16_renderer_reconciler.md, DEVELOPMENT_PLAN/system_components.md
**Generated sections**: none

> **Purpose**: Specify the first live phase — the Python `pb` midwife that ensures a toolchain and builds the
> binary before any `PATH` discipline can run, live substrate detection, the absolute-path-only host tool-ensure,
> and an idempotent `pb bootstrap --distro=kind` that brings up an empty single-node kind cluster and is a no-op
> on re-run.

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
opens only after the pre-cluster band (Phases 1–12) is green, and it composes four things: the Python `pb`
midwife that gets a built amoebius binary onto a bare host before any Haskell `PATH` discipline can exist; live
substrate detection that learns what the machine *is*; the no-environment / no-`PATH` lazy tool-ensure that
resolves `ghcup`/`cabal`/`kubectl`/`kind` — and pointedly **not** Helm — through the substrate's package manager
and invokes each by absolute path; and an idempotent single-node kind bring-up driven as a reconcile. The
cluster it produces is deliberately **empty**: no platform services, no retained storage, no Vault, no
control-plane singleton — those land in Phase 15 onward. The two load-bearing claims this gate proves are that
bring-up is an **idempotent reconcile** (re-running changes nothing), not a one-shot script, and that **every**
external invocation went through an `AbsExe` absolute path rather than a bare-name `PATH` lookup.

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

**Gate prerequisite (stated, not ensured):** a container runtime (Docker or Podman) is a **pre-installed host
prerequisite** of this gate, *not* a member of the closed `HostTool` enum. `kind` cannot create a cluster
without one, but amoebius does not provision it; the enum stays exactly `ghcup`, `cabal`, `kubectl`, `kind`,
and the package-manager root. The gate preflight records the runtime's presence in the ledger as an assumed
input; the enum's closedness (no sixth member) is asserted structurally in Sprint 13.2.

**External-observer requirement (§M.5).** Every "how it behaved" assertion in this gate — every invocation went
through an absolute path, zero Helm, zero mutating package-manager calls on a re-run — is read from an
**OS-boundary observer**, never a trace the code under test emits about itself. The observer of record is an
`execve` audit log (`strace -f -e trace=execve,execveat` or an equivalent eBPF/auditd capture) wrapping the
entire process tree of the run, committed as a gate artifact. As a redundant trap, the run also executes with
`PATH` pointed at a directory of same-named trap executables (`kind`, `kubectl`, `helm`, `apt`, …) that abort
loudly and log if invoked by bare name; any trap firing fails the gate. A self-emitted `runTool` compliance
trace is **not** an admissible observer for any of these assertions.

**Oracle-pinning (§M.1).** The gate's oracles are authored and **committed in Phase 0**, before any
implementation exists: the `classify` decision table (Sprint 13.1), the per-substrate `[InstallStep]` golden
plans and the `mkAbsExe`-reject expected-error set (Sprint 13.2), and the named divergent-start fixtures with
their expected converged observation (Sprint 13.4). A golden regenerated from the implementation is not
admitted.

**Committed seeded mutants (§M.2).** The gate re-runs against committed mutants that MUST go red: (M1) a
`classify` guard-negation that drops the "present NVIDIA GPU promotes Linux to `linux-cuda`" rule; (M2) an
`Ensure` variant that resolves one tool by bare name (`execve` argv[0] non-absolute) — the observer must catch
it; (M3) a bring-up that replaces the reconciler with the `kind get clusters | grep` one-shot guard — the
divergence-repair fixture must go red against it. A gate run in which any of M1–M3 stays green is void.

**Gate:** on a `linux-cpu` host with a container runtime pre-installed, the Python `pb` midwife's
`pb bootstrap --distro=kind` ensures the package-manager root, the pinned GHC 9.12.4 / Cabal 3.16.1.0
toolchain, and a built binary, then `exec`s `amoebius bootstrap --distro=kind`, which brings an empty
single-node kind cluster to exactly one `Ready` node (`kubectl get nodes` shows one node, `Ready`);
**re-running the identical command reports already-converged and changes nothing** — where "changes nothing"
means the observable triple `(docker/podman container list, `kind get clusters`, kubeconfig file bytes)` is
byte-for-byte identical before and after the re-run, and the `execve` audit log for the re-run contains **zero
mutating package-manager or `kind create` invocations**; from at least one named partially-converged start
state the identical run **converges without recreating the cluster** (divergence-repair, Sprint 13.4); **every
external tool invocation during the run resolved through an `AbsExe` absolute path** as witnessed by the
`execve` audit log (every `argv[0]` absolute, drawn from the resolved tool map), no bare-name `PATH` lookup,
and Helm is never ensured or invoked (no `helm` `execve`, no `helm` trap fired); and the gate ends by tearing
the cluster down (`kind delete cluster`) and asserting a **leak-free postflight sweep** (no residual kind
cluster, node container, or kubeconfig context).

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

## Sprints

## Sprint 13.1: Live substrate detection 📋

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
failures (Intel-Mac `darwin`+`amd64` → `Left`, and Linux+GPU → `linux-cuda`). On the gate host, `detect`
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
   positive that differs only in the foreclosed dimension (`darwin`+`arm64` → `Right macos-arm64`).
2. **Committed mutant M1 (§M.2):** re-run test 1 against the committed `classify` mutant with the GPU-promotion
   guard negated; assert the Linux+GPU cell flips and the test goes **red**. A run where M1 stays green is void.
3. Run `detect` on the `linux-cpu` gate host; confirm it returns `linux-cpu`.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 13.2: No-`PATH` lazy tool-ensure — closed enum, `AbsExe`, install-and-verify 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/HostTool.hs`, `src/Amoebius/Host/Ensure.hs` (target: the `HostTool` enum
+ `AbsExe` newtype + `HostConfig` tool map + the `installAndVerify` driver)
**Blocked by**: Sprint 13.1.
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
- A closed `HostTool` enum naming exactly the Phase-13 tool set (`ghcup`, `cabal`, `kubectl`, `kind`, and the
  package-manager root — **five members, no sixth**; the container runtime is a stated host prerequisite, not
  an enum member; Helm is intentionally absent); an unlisted tool cannot be invoked. A structural/CI check
  asserts the enum has exactly these five constructors.
- An `AbsExe` newtype whose constructor is unexported; `mkAbsExe` rejects any non-absolute path.
- A **CI structural check that no module outside `src/Amoebius/Host/Ensure.hs` imports any process-spawn API**
  (`System.Process`, `System.Posix.Process` exec family, `typed-process`, etc.), so bring-up cannot bypass the
  `AbsExe` chokepoint with a bare-name spawn (§M.5 forecloses the self-emitted-trace bypass at the source
  level).
- A `HostConfig` carrying the detected substrate (Sprint 13.1) plus a `Map HostTool AbsExe`, and a probe-first,
  idempotent `installAndVerify` driver (probe → verified no-op if satisfied, else run the pure
  substrate-branched `[InstallStep]` plan, re-resolving after each step, then re-verify or fail fast), with
  `runTool`/`runToolWithStdin` exec-ing `absExePath` only.
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

## Sprint 13.3: The Python `pb` midwife (package-manager root → toolchain → build → `exec`) 📋

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
- The retirement of `bootstrap.sh` recorded in the removal ledger; amoebius owns no shell script.

### Validation
1. On a `linux-cpu` host **with a ledger-recorded preflight probe confirming ghc/cabal/ghcup absent**,
   `pb bootstrap --distro=kind` completes steps 1–4 and `exec`s the binary.
2. Re-run with the toolchain already present is a **verified no-op up to the `exec`, defined as zero mutating
   `apt`/`ghcup`/`cabal-install` invocations in the re-run's `execve` audit log** (§M.5), not merely exit-0.
3. Confirm the tree contains no `bootstrap.sh` / no `.sh` igniter.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 13.4: The in-binary `bootstrap` command — idempotent single-node kind bring-up 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Cluster/Bootstrap.hs`, `src/Amoebius/Cluster/Kind.hs`,
`src/Amoebius/Host/Context.hs` (target: the `bootstrap` command chain, the kind bring-up reconciler, and the
parameters/context/witness host context)
**Blocked by**: Sprint 13.2, Sprint 13.3.
**Independent Validation**: on a `linux-cpu` host, `amoebius bootstrap --distro=kind` yields exactly one `Ready`
node; an immediate re-run reports already-converged and **changes nothing — the observable triple `(docker/
podman container list, `kind get clusters`, kubeconfig file bytes)` is byte-identical before and after, and the
re-run's `execve` audit log holds zero `kind create` or mutating package-manager calls**; from at least one
**named partially-converged start state** the identical re-run **converges without recreating the cluster** and
prints an explicit per-managed-resource discover/diff result showing an empty diff; and **every external
invocation went through an `AbsExe` absolute path as witnessed by the `execve` audit log** (every `argv[0]`
absolute, from the resolved tool map — §M.5), never a self-emitted `runTool` trace; the sprint ends by tearing
the cluster down and asserting a leak-free postflight sweep.
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`,
`documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`.

### Objective
Adopt [`cluster_lifecycle_doctrine.md` §2 — bring-up and bootstrap](../documents/engineering/cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap)
and [`cluster_lifecycle_doctrine.md` §9 — the reconciler, not a state machine](../documents/engineering/cluster_lifecycle_doctrine.md#9-how-bring-up-and-teardown-are-implemented-the-reconciler-not-a-state-machine)
for the self-managed, host-binary-present, single-node kind cluster of
[`cluster_lifecycle_doctrine.md` §1](../documents/engineering/cluster_lifecycle_doctrine.md#1-two-cluster-kinds-one-lifecycle-shape),
brought up as a `discover → diff → enact → re-observe` reconcile so that **re-running is a no-op** — carrying a
typed host context per [`dsl_doctrine.md` §3](../documents/engineering/dsl_doctrine.md#3-the-orchestration-surface-parameters-context-witness).

### Deliverables
- A `bootstrap` command chain that detects the substrate (Sprint 13.1), assembles a `BinaryContext`
  (parameters + context + file/socket witnesses), ensures `kind`/`kubectl` by absolute path (Sprint 13.2), and
  drives single-node kind bring-up as a genuine `discover → diff → enact → re-observe` reconcile over a
  managed-resource registry — not a one-shot script — such that each managed resource's discover/diff result is
  printed on every run.
- An empty cluster as the end state: one node, `Ready`, with **no** platform services (those are Phase 15+).
- **Phase-0-committed divergent-start fixtures** (§M.1) with their expected converged observation, and the
  committed mutant M3 (reconciler replaced by a `kind get clusters | grep <name>` one-shot guard) that the
  divergence-repair validation turns red.
- A **teardown + leak-free postflight sweep** (`kind delete cluster`, then assert no residual kind cluster,
  node container, or kubeconfig context) that closes the gate.

### Validation
1. **Gate.** On a `linux-cpu` host (container runtime pre-installed), `amoebius bootstrap --distro=kind`; assert
   `kubectl get nodes` shows exactly one `Ready` node.
2. **Idempotence (the gate's core claim).** Re-run the identical command; assert it reports already-converged
   and **changes nothing — the observable triple `(docker/podman container list, `kind get clusters`,
   kubeconfig file bytes)` is byte-identical before and after the re-run, and the re-run's `execve` audit log
   contains zero `kind create` and zero mutating package-manager calls** — leaving the single node `Ready`, and
   printing the per-managed-resource empty-diff discover result.
3. **Divergence-repair (§M — forecloses the one-shot-guard stub).** From each Phase-0-committed
   partially-converged start state — at minimum (a) the kind cluster exists but its node container is stopped /
   `NotReady`, and (b) the kubeconfig context is missing — run the identical command; assert it converges to
   exactly one `Ready` node **without recreating the cluster** (no `kind create` for an existing cluster in the
   `execve` log; cluster UID/creation-timestamp unchanged), the printed diff was non-empty then re-observes
   empty.
4. **External-observer absolute-path assertion (§M.5).** From the committed `execve` audit log of the whole run,
   assert every `argv[0]` is an absolute path drawn from the resolved tool map — no bare name, no Helm `execve`,
   and the bare-name `PATH` trap directory recorded no hits. A self-emitted `runTool` trace is inadmissible.
5. **Committed mutant M3 (§M.2).** Re-run Validation 3 against the committed one-shot-guard mutant; assert at
   least one divergent-start fixture goes **red** (the guard skips repair or recreates the cluster). A run where
   M3 stays green is void.
6. **Teardown + leak sweep.** `kind delete cluster`; assert the postflight sweep finds no residual kind
   cluster, node container, or kubeconfig context.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/substrate_doctrine.md` — when detection, the `AbsExe`/closed-enum tool-ensure, and the
  Python `pb` midwife land, flip the §9 planning-ownership orientation note for this phase from intent to a
  delivered-status pointer (status stays in the plan) and reconcile any seed-vs-target discovery caveats in §3.
- `documents/engineering/bootstrap_sequence_doctrine.md` — record that `pb`'s **midwife** mode is delivered here
  and that its **admin-REST client** mode (§5) remains a later phase.
- `documents/engineering/cluster_lifecycle_doctrine.md` — confirm the §2/§9 "bring-up is itself a reconcile"
  no-op shape is exercised by this phase's gate.

**Cross-references to add:**
- [README.md](README.md) — flip the Phase 14 row status once work begins, and link this document from the Phase
  13 paragraph.
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
