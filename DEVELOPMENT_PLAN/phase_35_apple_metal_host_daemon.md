# Phase 35: Apple-Metal host compute daemon

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_34_jitml_lift_cuda.md, DEVELOPMENT_PLAN/system_components.md, documents/engineering/apple_metal_headless_builds.md
**Generated sections**: none

> **Purpose**: Stand up the Apple-Silicon host compute daemon that runs a Metal ML workload as a plain cluster
> Pulsar/MinIO peer over a host-only loopback NodePort with no mTLS, with the native worker built **headless
> on-host through the fixed Metal bridge — no VM**.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is 📋 Planned and every prescriptive
statement is design intent, never a tested amoebius result. The phase runs on the **apple** substrate in
**Register 3** (live infrastructure): an Apple-Silicon host whose Lima-synthesized Ubuntu-24.04 Linux VM
carries a single-node cluster. The mechanisms it composes exist only as **sibling evidence, not amoebius
results**: the loopback-NodePort peering pattern is precedent in the sibling prodbox project (in-cluster
Harbor reached at `127.0.0.1:30080` over a loopback-bound NodePort); the headless fixed-Metal-bridge build is
proven in the sibling jitML project and adopted after the sibling infernix library *removed* its own legacy
Tart path; and the substrate detection + no-`PATH` lazy tool-ensure kernel is inherited from the hostbootstrap
seed. None has been built or run as amoebius, and there is no amoebius Tart code, now or planned. Status
transitions are recorded reverse-chronologically here once work begins.

## Phase Summary

This phase delivers the one class of amoebius compute that lives **outside a cluster pod**: a long-running
host subprocess that reaches hardware which refuses to be performantly contained — Apple-Metal needs Apple
Silicon unified memory, so it cannot run in a Linux container or a Linux VM. The phase does four things and
stops there. First, it manages the apple substrate, synthesizing the Linux host the cluster wants via **Lima**
and rooting every host tool in **brew** through the no-environment / no-`PATH` lazy tool-ensure contract —
probe, install-if-absent, resolve the absolute path from the package manager, invoke by full path. Second, it
binds the in-cluster MinIO and Pulsar standard services to a **host-only loopback NodePort** reachable only
from the host (`127.0.0.1:<nodeport>`), with no LoadBalancer, no Envoy route, and no path from LAN/WAN — the
sanctioned localhost carve-out from Keycloak-owns-all-wild-ingress. Third, it builds the native Apple-Metal
worker **headless, directly on the host — no VM (no Tart)** — via a fixed Objective-C/C Metal bridge
source-built with `/usr/bin/clang` by absolute path, with generated MSL compiled at runtime through the OS
Metal framework. Fourth, it runs that worker as a managed subprocess of the host binary and wires it as an
**ordinary Pulsar + MinIO peer over the host-only NodePort with no mTLS**: commands arrive as Pulsar messages,
results land in the content-addressed MinIO store, and there is no bespoke binary↔daemon RPC — coordination
*is* Pulsar/MinIO, with security from the network restriction, not from transport crypto.

The scope stops at the host-worker shell and its wire. The Metal ML kernel it runs is a **named catalog
identity the shared jit-build resolver materializes on first miss into the `CacheBudget`-bounded
content-addressed cache** (Phase 32), never a baked or URL-fetched payload; on the Apple substrate the cache
artifact is content-addressed source metadata — the rendered MSL plus launch/determinism metadata — not a
compiled dylib. The daemon carries no cluster-control authority: state-changing coordination flows through the
same Pulsar/MinIO nervous system every in-cluster worker uses, and the durable side of that store lives in the
Vault-enveloped MinIO bucket that is the stateless Deployment-`replicas=1` control-plane singleton's only
durable state (single-instance delegated to k8s/etcd, **no election**). The windows-CUDA host worker is the
structurally identical case on a different substrate and is named throughout as target shape, but it is **not**
part of this phase's single-substrate gate. This phase consumes earlier phases rather than re-implementing
them: Phase 14's substrate detection, `pb` midwife handoff, and no-`PATH` tool-ensure kernel; Phase 19's MinIO
and Pulsar standard services; Phase 24's native Pulsar client; Phase 25's content-addressed store and workflow
runtime; Phase 31's determinism kernel; Phase 32's jit-build engine cache; and Phase 18's Vault secrets-by-name.

```mermaid
flowchart LR
  apple[Apple Silicon host: detected apple substrate] --> lima[Lima Ubuntu-24.04 VM: single-node cluster]
  lima --> svc[In-cluster MinIO and Pulsar standard services]
  svc --> np[Host-only NodePort bound to 127.0.0.1, no mTLS]
  apple --> bridge[Headless on-host fixed Metal bridge build: clang, no VM]
  bridge --> daemon[Host compute daemon: managed subprocess of the host binary]
  np --> daemon
  daemon --> metal[Metal ML kernel: jit-resolved MSL on Apple unified memory]
  daemon --> peer[Channel-2 peer: Pulsar consume plus MinIO put and get]
  peer --> gate[Gate: Apple daemon runs a Metal workload as a cluster peer]
```

**Substrate:** apple — the whole gate runs on an Apple-Silicon host whose Lima-synthesized Linux VM carries a
single-node cluster in Register 3 (live infrastructure); no linux-cpu, linux-cuda, or windows substrate is
touched by the gate, and the windows-CUDA host worker is named only as the structurally identical non-gate case.

**Register:** 3 — live infrastructure (§K).

**Gate:** an Apple-Silicon host daemon runs a Metal ML workload as a cluster Pulsar/MinIO peer over a host-only
NodePort — one `InForceSpec` in Register 3 brings up the apple-substrate cluster on Lima, exposes MinIO and
Pulsar on a host-only loopback NodePort, builds the native worker **headless on-host via the fixed Metal bridge
(no VM)**, starts the daemon as a managed subprocess, dispatches a Metal inference job over Pulsar with **no
mTLS**, lands its output in the content-addressed MinIO store by content address, and tears the worker and
cluster down leak-free; the run emits a proven/tested/assumed ledger recording that host-only reachability was
*tested* (reachable from `127.0.0.1`, unreachable from the LAN) and that no mTLS or bespoke RPC was introduced
on channel 2, with Apple-Metal physics marked *assumed* (sibling evidence, not an amoebius measurement).

**Gate-integrity clauses (§M).** The gate passes only when all of the following hold; each is authored under
the [§M gate-integrity standard](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)
and its concrete fixtures are pinned per the [Phase-0 oracle-pinning obligation](#n-phase-0-pinned-oracle-set-for-this-phase).

- **Input-dependent output oracle (§M.1/§M.3).** The artifact retrieved from MinIO by content address must be
  byte-equal to an independently pinned expected output computed **off-implementation** — the committed
  Phase-0 CPU reference `test/golden/phase_35/metal_job_ref.py` (a plain NumPy recompute of the same kernel
  math, authored before the bridge exists, never derived from bridge output). Two committed jobs `job_A` and
  `job_B` (differing only in their input tensor) must land two **different** pinned outputs
  `blobs/<sha256(out_A)>` and `blobs/<sha256(out_B)>`; a constant, input-independent, or `job_A==job_B` worker
  output turns the gate red. The dispatch additionally observes a real `MTLDevice` artifact (the compiled
  `MTLLibrary`/pipeline-reflection handle), not only the returned buffer.
- **Committed seeded mutant (§M.2).** The committed mutant set `test/mutants/phase_35/` includes at minimum
  `const_output.patch` (worker writes a fixed constant regardless of job payload — an effect-swap operator)
  and `lb_nodeport.patch` (the host-comms spec re-typed `LoadBalancer` — a union-arm addition); the gate is
  re-run against each and **must go red** (`const_output.patch` fails the input-dependent oracle,
  `lb_nodeport.patch` fails the wild-exposure type-check). A green gate against any committed mutant fails the
  phase.
- **Representative set (§M.7).** The gate's representative set is exactly: one apple substrate (Apple-Silicon
  host + Lima Ubuntu-24.04 VM), the two host-only NodePort services {MinIO, Pulsar}, the two dispatch jobs
  {`job_A`, `job_B`}, and the four wild-exposure negatives enumerated in Sprint 28.5. No other shape is claimed.
- **Leak-free, defined (§M).** "Tears down leak-free" at Phase 35 means, asserted by the postflight probe:
  after teardown (a) `limactl list` shows the named VM absent; (b) no worker/bridge subprocess of the host
  binary survives (checked by pgrep of the recorded child PIDs); and (c) the host-side residue set — the
  bridge dylib path, the jit MSL cache dir, and any brew-installed `limactl` marked ephemeral by this run — is
  swept to its pre-run state. Phase 36's general postflight sweep is not yet available, so this phase pins its
  own explicit three-part residue check rather than deferring to it.

## N. Phase-0-pinned oracle set for this phase

Under [§M.1 oracle-pinning](development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub),
the following fixtures, goldens, and expected-error tags are authored and committed **in Phase 0 — before any
Phase-28 implementation exists** — and are the byte-authority the gate checks against (none is regenerated from
the implementation):

- `test/golden/phase_35/metal_job_ref.py` — the off-implementation CPU (NumPy) reference for the dispatched
  kernel; the source of the expected output bytes.
- `test/golden/phase_35/job_A.input`, `job_B.input` — the two committed job inputs, differing only in their
  tensor payload.
- `test/golden/phase_35/job_A.expected`, `job_B.expected` — the two pinned expected outputs (produced by the
  CPU reference, not the bridge), whose sha256 the gate retrieves from MinIO.
- `test/dhall/phase_35_illegal/` — the four wild-exposure negatives (see Sprint 28.5), each a one-field
  mutation of the committed green host-comms spec, each carrying its validation-locus tag and its expected
  `dhall type` error string, registered in the Phase-6 illegal-state corpus.
- `test/mutants/phase_35/const_output.patch`, `lb_nodeport.patch` — the committed seeded mutants the gate must
  turn red.

## Doctrine adopted

This phase is the first live amoebius realization of three doctrines; individual sprints cite the same sections
where they adopt them.

- [`host_cluster_comms_doctrine.md §2`](../documents/engineering/host_cluster_comms_doctrine.md#2-the-decision-that-was-open-and-is-now-resolved)
  — *the decision that was open, and is now resolved*: this phase builds the resolved channel-2 design — a host
  compute daemon as a plain Pulsar + MinIO peer over host-only NodePorts with **no mTLS** — taking the two
  localhost-only channels of [`§1`](../documents/engineering/host_cluster_comms_doctrine.md#1-the-whole-surface-two-channels-both-localhost-only),
  the no-bespoke-control-channel rule of [`§3`](../documents/engineering/host_cluster_comms_doctrine.md#3-there-is-no-bespoke-control-channel--coordination-is-pulsar--minio)
  (*coordination is Pulsar + MinIO*), the network-restriction threat model of [`§5`](../documents/engineering/host_cluster_comms_doctrine.md#5-why-no-mtls-is-safe-here-the-network-restriction-is-the-security-boundary)
  (*why no mTLS is safe here*), the loopback-NodePort realization and prodbox precedent of [`§6`](../documents/engineering/host_cluster_comms_doctrine.md#6-the-host-only-restriction-in-practice-and-its-sibling-precedent),
  and the type-excluded illegal states of [`§7`](../documents/engineering/host_cluster_comms_doctrine.md#7-what-the-dsl-makes-unrepresentable-here)
  (*what the DSL makes unrepresentable here*).
- [`substrate_doctrine.md §5`](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained)
  — *host worker nodes: substrate-specific hardware that refuses to be contained*: this phase implements the
  apple host worker (Apple-Metal on unified memory) as a managed subprocess of the host binary with the
  Load → Prereq → Acquire → Ready → Serve → Drain → Exit role lifecycle, built via the virtualized-substrate
  provider of [`§4`](../documents/engineering/substrate_doctrine.md#4-virtualized-substrates-synthesizing-a-linux-host-where-the-host-is-not-linux)
  ([`§4.1 — Lima on Apple`](../documents/engineering/substrate_doctrine.md#41-lima-on-apple) for the Linux VM),
  all under the [`§3`](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)
  *no-environment / no-`PATH` lazy tool-ensure contract* rooted in brew, handed off by the Python `pb` midwife
  of [`§6`](../documents/engineering/substrate_doctrine.md#6-the-midwife-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off)
  (*the midwife contract*), never a shell script.
- [`apple_metal_headless_builds.md §1`](../documents/engineering/apple_metal_headless_builds.md#1-the-commitment-headless-on-host-no-vm)
  — *the commitment: headless, on-host, no VM* — with [`§3 — Architecture`](../documents/engineering/apple_metal_headless_builds.md#3-architecture)
  (the fixed host Metal bridge), [`§4 — Build and prerequisite model`](../documents/engineering/apple_metal_headless_builds.md#4-build-and-prerequisite-model),
  and [`§6 — Why Tart is not viable`](../documents/engineering/apple_metal_headless_builds.md#6-why-tart-is-not-viable-the-no-vm-rationale):
  this phase builds the Apple-Metal worker **headless on the host — no Tart, no macOS VM** — source-building the
  fixed Objective-C/C Metal bridge with `/usr/bin/clang` by absolute path and compiling generated MSL at
  runtime through the OS Metal framework, so a cache miss never starts a VM, invokes SwiftPM, or depends on a
  login keychain.

## Sprints

## Sprint 28.1: Apple substrate management — Lima Linux VM + brew lazy tool-ensure 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Substrate/Apple.hs`, `src/Amoebius/Substrate/Lima.hs`, `src/Amoebius/Substrate/Brew.hs` (target paths; not yet built)
**Blocked by**: Phase 14 gate (external prereq — substrate detection, the `pb` midwife handoff, and the closed-enum no-`PATH` lazy-tool-ensure kernel that invokes by absolute path, here extended to the brew root and the Lima provider on apple)
**Independent Validation**: on a detected apple substrate, `ensure lima` is `brew install lima` when `limactl` is absent and a verified no-op otherwise; a named Ubuntu-24.04 VM sized to the pinned Phase-28 apple budget — **4 vCPU, 8 GiB memory, 40 GiB disk** (the single fixed budget this phase enforces; the reconciler rejects a Lima config requesting more) — starts and carries a single-node cluster; every host tool used is resolved to an absolute path via the package manager, and **no bare command name and no environment variable (including `PATH`) is ever read** on the host surface, asserted from the execution-boundary argv/env trace of Validation 3 (not a source grep).
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective
Adopt [`substrate_doctrine.md §4.1 — Lima on Apple`](../documents/engineering/substrate_doctrine.md#41-lima-on-apple)
and [`substrate_doctrine.md §3`](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)
— the no-environment / no-`PATH` lazy tool-ensure contract — handed off by the Python `pb` midwife of
[`substrate_doctrine.md §6`](../documents/engineering/substrate_doctrine.md#6-the-midwife-contract-a-python-cli-ensures-a-toolchain-builds-the-binary-hands-off):
synthesize the Linux host the apple substrate's cluster runs on via Lima, with every host tool ensured and
invoked by absolute path through brew — the substrate foundation every later Phase-28 sprint stands on.

### Deliverables
- An apple-substrate manager that drives Lima (`limactl`) to start a named, budget-sized Ubuntu-24.04 VM and
  re-invokes amoebius subcommands inside it via `limactl shell <vm> -- <amoebius> <subcmd>` (the composition
  lift is owned elsewhere and only consumed here).
- A brew-rooted lazy-tool-ensure binding: probe → install-if-absent → resolve the absolute path from the
  package manager (`brew --prefix`) → invoke by full path; the install *plan* is a pure value so the substrate
  branching is unit-tested without invoking brew, and only the driver is `IO`.
- A substrate-applicability guard so the apple reconcilers fail fast — before any side effect — when run on a
  non-apple substrate, with a one-line diagnostic.

### Validation
1. With `limactl` absent, the reconciler installs it via brew, re-resolves it to an absolute path, and starts
   the VM; with it present, the same call is a verified no-op (idempotent).
2. A unit test exercises the pure install plan for apple without invoking brew.
3. Execution-boundary trace check (not a source grep): the whole sprint run is driven through the tool-ensure
   seam, which records `(argv, env)` for every spawn, and is additionally run under an OS-boundary exec trace
   (`dtruss`/`execsnoop` capturing every `execve` and its environment). The suite asserts, from the trace, that
   **every** recorded `argv[0]` is an absolute path (no bare command name) and every spawn's environment is
   exactly the fixed closed allow-set the contract permits (`PATH` absent from it) — covering transitively
   spawned subprocesses and library-issued execs, which a grep of the author's modules cannot see.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 28.2: Host-only loopback NodePort exposure of MinIO + Pulsar 📋

**Status**: Planned
**Implementation**: `src/Amoebius/HostComms/NodePort.hs`, `src/Amoebius/HostComms/Loopback.hs` (target paths; not yet built)
**Blocked by**: Sprint 28.1 (the Lima VM provides the node network whose NodePorts must be bound to the host's loopback); Phase 19 gate (external prereq — the in-cluster MinIO and Pulsar standard services to expose)
**Independent Validation**: after bring-up, MinIO and Pulsar are reachable from the host at `127.0.0.1:<nodeport>` and **unreachable** from (a) a second physical machine on the same LAN and (b) the host's own primary non-loopback interface address (`<lan-ip>:<nodeport>`, the WAN-equivalent probe — dialing the routable interface stands in for an off-LAN client without requiring a real WAN peer). "Unreachable" is defined as either an immediate `connection refused`/`no route` **or** a connect that does not complete within a 5s timeout (a silent drop counts as unreachable, an established TCP session does not); there is no `LoadBalancer`-typed Service, no Envoy route, and no wild listener for either port; the loopback binding holds even though the Lima VM's node network does not bind NodePorts to loopback by default.
**Docs to update**: `documents/engineering/host_cluster_comms_doctrine.md`, `documents/engineering/substrate_doctrine.md`

### Objective
Adopt [`host_cluster_comms_doctrine.md §6 — the host-only restriction in practice`](../documents/engineering/host_cluster_comms_doctrine.md#6-the-host-only-restriction-in-practice-and-its-sibling-precedent)
and [`§1 — two channels, both localhost-only`](../documents/engineering/host_cluster_comms_doctrine.md#1-the-whole-surface-two-channels-both-localhost-only):
realize channel 2's transport — a NodePort bound to the host's loopback so the daemon connects to
`127.0.0.1:<nodeport>` with no path from LAN/WAN — generalizing the prodbox `127.0.0.1:30080` Harbor precedent
(sibling evidence, not an amoebius result) onto the Lima-backed apple substrate. The rendered manifests are
emitted from Haskell and never committed.

### Deliverables
- Rendered host-only NodePort Services for MinIO and Pulsar whose reachability is restricted to host-origin
  traffic, plus the substrate-layer loopback binding / host-only firewalling that makes the
  `127.0.0.1:<nodeport>` shape hold on the Lima VM **without relaxing the restriction** (never by publishing
  the port wider).
- An assertion seam proving the negative: no `LoadBalancer` Service, no Gateway/HTTPRoute, and no wild listener
  references either port — these are the only channel-2 endpoints and they are localhost-only.
- A recorded note that the same loopback shape is what the windows substrate's WSL2 case would target, as
  target shape (not exercised by the apple gate).

### Validation
1. Connect to MinIO and Pulsar from the host at `127.0.0.1:<nodeport>` and succeed; attempt the same from a
   second physical host on the LAN and from the host's routable `<lan-ip>:<nodeport>` (WAN-equivalent probe) and
   fail — where fail means `connection refused`/`no route` or a connect that does not complete within a 5s
   timeout (no established session), per the Independent Validation definition.
2. Assert there is no `LoadBalancer`-typed Service and no Envoy route fronting either port.
3. Tear the cluster down and back up; the loopback binding is re-established idempotently.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 28.3: Headless host-native Metal bridge + native worker build (no Tart) 📋

**Status**: Planned
**Implementation**: `src/Amoebius/HostWorker/MetalBridge.hs` (fixed ObjC/C bridge install + probe + runtime MSL dispatch), `src/Amoebius/HostWorker/AppleMetalBuild.hs` (target paths; not yet built)
**Blocked by**: Sprint 28.1 (the apple substrate manager + brew lazy tool-ensure that resolves `/usr/bin/clang` and the OS Metal runtime by absolute path); Phase 32 gate (external prereq — the jit-build resolver + `CacheBudget`-bounded content-addressed cache the MSL source-metadata artifact lands in); Phase 31 gate (external prereq — the determinism kernel: fast-math-off, `experimentHash`)
**Independent Validation**: the fixed Objective-C/C Metal bridge dylib is source-built on the host with `/usr/bin/clang` (absolute path, no env/`PATH`), `dlopen`'d, and verified by its probe symbol; generated MSL compiles at runtime via `MTLDevice.makeLibrary(source:options:)` and dispatches on the host GPU, and the dispatch surfaces a real `MTLDevice` artifact — the compiled `MTLLibrary` handle and its pipeline reflection — not merely a returned buffer; the dispatched kernel's output is byte-equal to the Phase-0-pinned off-implementation CPU reference (`test/golden/phase_35/job_A.expected`) for `job_A`'s input and byte-**different** and equal to `job_B.expected` for `job_B`'s input, so an input-independent or constant worker output is red; **no VM is ever started, no SwiftPM/`swift build` runs on a cache miss, and no login-keychain unlock is required**; the source-metadata cache artifact is content-addressed and yields bit-identical output when recomputed on a cache-bypassed second run in a distinct content-addressed namespace (an independent recompute, not a store hit).
**Docs to update**: `documents/engineering/apple_metal_headless_builds.md`, `documents/engineering/substrate_doctrine.md`

### Objective
Adopt [`apple_metal_headless_builds.md §1 — the commitment: headless, on-host, no VM`](../documents/engineering/apple_metal_headless_builds.md#1-the-commitment-headless-on-host-no-vm),
[`§3 — Architecture`](../documents/engineering/apple_metal_headless_builds.md#3-architecture),
[`§4 — Build and prerequisite model`](../documents/engineering/apple_metal_headless_builds.md#4-build-and-prerequisite-model),
and [`§6 — Why Tart is not viable`](../documents/engineering/apple_metal_headless_builds.md#6-why-tart-is-not-viable-the-no-vm-rationale),
with the host-worker build rule of [`substrate_doctrine.md §5`](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained):
build the Apple-Metal worker **headless, directly on the host — with no macOS VM (no Tart)** — so build
provenance is host-controlled without inheriting VM lifecycle, keychain, or SwiftPM surfaces. The
headless fixed-bridge shape is proven in the sibling jitML project (sibling evidence, not an amoebius result);
this sprint realizes it in amoebius for the first time.

### Deliverables
- A fixed Objective-C/C Metal bridge, source-built once on the host by invoking `/usr/bin/clang` **by absolute
  path** (linking macOS `Foundation`/`Metal`), then `dlopen`'d and verified by resolving an exported probe
  symbol before the worker subscribes to work — no env, no `PATH`, no VM.
- Runtime MSL compilation: the host binary renders Metal Shading Language, writes a content-addressed
  source-metadata cache record into the Phase-25 `CacheBudget`-bounded cache, and dispatches through the
  bridge's `MTLDevice.makeLibrary(source:options:)` with fast-math **off** (the Phase-24 determinism
  contract), reusing an in-process pipeline cache across calls.
- The native Apple-Metal worker built on-host (targeting Apple Silicon unified memory) as a host-worker binary,
  **not** a container image; the optional Homebrew-`swiftc` + explicit-`SDKROOT` lane is available for any
  non-core Swift parts but is never the cache-miss path and never a VM.

### Validation
1. Build the fixed bridge with `/usr/bin/clang`, `dlopen` it, and pass its probe; assert (from the
   Sprint-28.3 exec trace, not a self-report) no `tart`/VM process was started and no `security`/keychain
   unlock call was made.
2. Compile generated MSL at runtime through the bridge and dispatch a kernel for both `job_A` and `job_B`;
   assert the returned buffer is byte-equal to the Phase-0-pinned CPU reference expected output for each job
   (`test/golden/phase_35/job_A.expected`, `job_B.expected`), that the two outputs **differ** (so a constant
   output fails), and that a real `MTLLibrary`/pipeline-reflection handle was obtained. Assert bit-stable output
   under the fast-math-off determinism contract by recomputing `job_A` on a **cache-bypassed** run in a distinct
   content-addressed namespace and asserting the compute path (MSL compile + GPU dispatch) actually executed and
   produced a bit-identical result — a store hit does not satisfy this. The committed mutant
   `test/mutants/phase_35/const_output.patch` must turn this validation red.
3. Execution-boundary trace check (not a source grep): under the OS-boundary exec trace, assert every tool the
   build/dispatch path spawns has an absolute-path `argv[0]`, every spawn env is the fixed closed allow-set with
   `PATH` absent, and the trace contains no `tart`, `swift build`, or offline `metal` compiler `execve` on the
   core path — covering transitively spawned processes a module grep cannot observe.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 28.4: Host compute daemon lifecycle as a managed subprocess 📋

**Status**: Planned
**Implementation**: `src/Amoebius/HostWorker/Lifecycle.hs`, `src/Amoebius/HostWorker/Supervise.hs` (target paths; not yet built)
**Blocked by**: Sprint 28.3 (the built native worker binary is what the lifecycle manages); Sprint 28.1 (the apple substrate context the subprocess runs in)
**Independent Validation**: the worker runs as a subprocess of the host binary with a defined Load → Prereq → Acquire → Ready → Serve → Drain → Exit lifecycle; a `Drain` runs **even if serving throws**; a missing prerequisite fails fast before `Serve`; killing the host binary tears the worker down with it (no unmanaged orphan process).
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective
Adopt [`substrate_doctrine.md §5 — host worker nodes: substrate-specific hardware that refuses to be contained`](../documents/engineering/substrate_doctrine.md#5-host-worker-nodes-substrate-specific-hardware-that-refuses-to-be-contained):
run the Apple-Metal worker as a **managed subprocess of the host binary** — the one place amoebius compute
lives outside a cluster pod — with the stateless-role lifecycle and a guaranteed drain, so the worker has a
defined startup and a clean shutdown rather than an unmanaged background process.

### Deliverables
- A supervised host-worker lifecycle implementing Load → Prereq → Acquire → Ready → Serve → Drain → Exit, with
  the drain guaranteed via bracket-style resource handling even when `Serve` raises.
- Prerequisite gating that fails fast — before `Serve` — when the Metal worker binary, the host-only NodePort
  endpoints, or the worker's MinIO/Pulsar credential names are not available, with a one-line diagnostic.
- Subprocess ownership tying the worker's lifetime to the host binary: a host-binary exit (clean or signal)
  drains and reaps the worker; no orphaned process survives.

### Validation
1. Start the worker, force `Serve` to throw, and assert `Drain` still runs and resources are released.
2. Remove a prerequisite and assert a fast, pre-`Serve` failure with an actionable message.
3. Kill the host binary mid-`Serve` and assert the worker subprocess is drained and gone.

### Remaining Work
The whole sprint (📋 Planned).

## Sprint 28.5: Channel-2 peer + wild-exposure unrepresentable + the Apple-Metal peer gate 📋

**Status**: Planned
**Implementation**: `src/Amoebius/HostWorker/Peer.hs`, `src/Amoebius/HostWorker/Auth.hs`, `src/Amoebius/HostComms/Illegal.hs`, `test/dhall/phase_35_apple_metal_peer.dhall`, `test/live/AppleMetalPeerSpec.hs` (target paths; not yet built)
**Blocked by**: Sprint 28.2 (the host-only loopback NodePorts the peer dials and the gate asserts is localhost-only); Sprint 28.4 (the daemon lifecycle whose `Serve` step does the peering); Phase 24 gate (external prereq — the native Pulsar CBOR client); Phase 25 gate (external prereq — the content-addressed store + workflow runtime); Phase 18 gate (external prereq — Vault for secrets-by-name auth)
**Independent Validation**: the worker subscribes to its work topic over the native Pulsar TCP binary protocol (no WebSockets), does the work, and writes outputs to the content-addressed MinIO store — all over `127.0.0.1:<nodeport>` with **no mTLS and no bespoke binary↔daemon RPC**; client auth resolves through Vault by secret-name, never via a host environment variable or `PATH`; **each of four** wild-exposure negatives — (1) host-origin NodePort typed `LoadBalancer`, (2) an Envoy/HTTPRoute route on it, (3) any wild listener referencing the port, (4) the daemon publishing its own wild ingress — is a committed `.dhall` that is **a one-field mutation of the committed green host-comms spec** (identical except the single wild field, so that field is provably the rejection cause), is registered in the Phase-6 illegal-state corpus with its validation-locus tag, and **fails `dhall type` with the specific structured error naming the violated exclusion** (asserted against the pinned expected error string, not merely "fails"); the gate `.dhall` runs the full Apple-Metal peer workflow end-to-end and tears down leak-free (per the three-part residue check in the Gate), emitting a proven/tested/assumed ledger artifact.
**Docs to update**: `documents/engineering/host_cluster_comms_doctrine.md`, `DEVELOPMENT_PLAN/README.md`, `DEVELOPMENT_PLAN/substrates.md`

### Objective
Adopt [`host_cluster_comms_doctrine.md §3 — coordination is Pulsar + MinIO`](../documents/engineering/host_cluster_comms_doctrine.md#3-there-is-no-bespoke-control-channel--coordination-is-pulsar--minio)
with the resolution of [`§2`](../documents/engineering/host_cluster_comms_doctrine.md#2-the-decision-that-was-open-and-is-now-resolved),
the threat model of [`§5 — why no mTLS is safe here`](../documents/engineering/host_cluster_comms_doctrine.md#5-why-no-mtls-is-safe-here-the-network-restriction-is-the-security-boundary),
and the type-exclusions of [`§7 — what the DSL makes unrepresentable here`](../documents/engineering/host_cluster_comms_doctrine.md#7-what-the-dsl-makes-unrepresentable-here):
make the host worker an ordinary Pulsar/MinIO peer over the host-only NodePort with no custom RPC and no
transport crypto, close the carve-out so its boundaries cannot be drawn wrong, and prove the phase gate from
[`§1`](../documents/engineering/host_cluster_comms_doctrine.md#1-the-whole-surface-two-channels-both-localhost-only)
— an Apple-Silicon host daemon runs a Metal ML workload as a cluster Pulsar/MinIO peer.

### Deliverables
- A channel-2 peer that consumes its work topic via the shared native-protocol Pulsar client (at-least-once +
  dedup preserved; broker ids/timestamps are never part of any content address) and writes results to
  `blobs/<sha256>` + a content-addressed manifest in the MinIO store — the same coordination shape an
  in-cluster worker Pod uses — over a plain socket on `127.0.0.1:<nodeport>` with **no mTLS layer added**, and
  secrets-by-name client auth resolved through Vault (no host env, no `PATH`, no bespoke RPC to the binary).
- Type-level exclusions instantiated from the illegal-state catalog: a host-origin NodePort cannot be expressed
  as `LoadBalancer`-typed, Envoy-routed, or wild-listening, and a host compute daemon cannot publish its own
  wild ingress — its only inbound coordination is Pulsar/MinIO peering.
- The gate `.dhall` (`test/dhall/phase_35_apple_metal_peer.dhall`) is a **generated artifact emitted from
  Haskell at gate-run time and never committed** — its byte-authority is the authored Haskell emitter in
  `src/Amoebius/HostWorker/Peer.hs` / `HostComms/Illegal.hs`, per development_plan_standards §B (Implementation
  names authored source, never a generated artifact); the path in the Implementation field denotes this
  emitted-at-runtime output, not committed source. The committed byte-authority for the type-check negatives is
  instead the green host-comms spec and the four one-field-mutant illegal fixtures under
  `test/dhall/phase_35_illegal/` (authored, committed in Phase 0). The gate `.dhall`, once emitted, drives:
  bring up the apple cluster on Lima, expose MinIO/Pulsar on the host-only loopback NodePort, build the worker
  **headless on-host via the fixed Metal bridge (no VM)**, start the daemon as a managed subprocess, dispatch a
  Metal inference job over Pulsar, land its output in the content-addressed store, then tear the worker and
  cluster down — emitting a ledger recording NodePort-is-localhost-only and no-mTLS / no-bespoke-RPC as
  **tested on apple**, and Apple-Metal physics as **assumed** (prodbox loopback precedent, not an amoebius
  proof).

### Validation
1. Each of the four committed wild-exposure negatives in `test/dhall/phase_35_illegal/` (NodePort as
   `LoadBalancer`; Envoy/HTTPRoute route on the port; wild listener on the port; daemon wild ingress) — each a
   one-field mutation of the committed green host-comms spec, differing only in the foreclosed field — fails
   `dhall type` with the pinned structured error naming its specific violated exclusion (asserted against the
   corpus-registered expected error string at its validation-locus tag), while the green spec type-checks; the
   committed mutant `test/mutants/phase_35/lb_nodeport.patch` (which re-types the NodePort `LoadBalancer` in the
   *gate* spec) must turn this validation red.
2. The gate `.dhall` runs the full Apple-Metal peer workflow: the worker consumes the job over native Pulsar
   (no WebSocket frames, no TLS handshake, only `127.0.0.1:<nodeport>`), and the output landed in MinIO,
   retrieved by its content address, is byte-equal to the Phase-0-pinned off-implementation expected output for
   the dispatched job (`test/golden/phase_35/job_A.expected`) — with `job_B` yielding the distinct pinned
   `job_B.expected`, so a constant or input-independent artifact fails — and tears down leak-free per the
   three-part residue check.
3. Auth resolves the worker's MinIO/Pulsar credentials by name through Vault with no env/`PATH` read; the
   ledger artifact is emitted and marks the Apple-Metal physics row as assumed, not green.

### Remaining Work
The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update (when the gate runs, flip the honest layer, never before):**
- `documents/engineering/host_cluster_comms_doctrine.md` — its §9 planning-ownership pointer resolves to
  delivered Phase-28 sprints, and the §2/§5/§6 honesty notes flip from "resolved design decision / sibling
  evidence" to a delivered, apple-tested channel-2 peer (status recorded here in the plan, never as doctrine
  status); add the `Amoebius.HostComms.*` and `Amoebius.HostWorker.*` module paths to its cross-reference set.
- `documents/engineering/apple_metal_headless_builds.md` — its §1/§3/§4/§6 honesty notes flip from "jitML
  sibling evidence / design intent" to a delivered, apple-tested amoebius fixed-Metal-bridge build (status in
  the plan, never as doctrine status).
- `documents/engineering/substrate_doctrine.md` — its §9 planning-ownership pointer resolves to delivered
  Phase-28 sprints; the §4.3 "no macOS build VM" note and the §5 host-worker description gain their first
  amoebius datapoint on apple; record that the Lima provider, the headless on-host Metal-bridge build, and the
  brew lazy-tool-ensure were exercised by full-path subprocess with no env/`PATH`.

**Cross-references to add:**
- [README.md](README.md) — flip the Phase-28 row status once the gate passes and link this document.
- [substrates.md](substrates.md) — record Phase 35's gate substrate (apple) in the per-phase substrate map, and
  note the windows-CUDA host worker as the structurally identical non-gate case.
- [system_components.md](system_components.md) — register the host-worker and host-comms modules
  (`Substrate/Apple`, `Substrate/Lima`, `Substrate/Brew`, `HostComms/NodePort`, `HostComms/Loopback`,
  `HostWorker/MetalBridge`, `HostWorker/Lifecycle`, `HostWorker/Peer`) and the `AppleMetalPeerSpec` live suite
  as Phase-28 design-first rows.

## Related Documents
- [README.md](README.md) — the live tracker; the Phase 35 row is the authoritative one-line gate and status
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys (the
  Register-3 honesty token: a passed gate is a live-substrate result, never a compile claim)
- [overview.md](overview.md) — the target architecture and cross-cutting invariants (the host-only NodePort
  carve-out, host worker nodes, the stateless `replicas=1` singleton, and jit-resolved engine payloads)
- [system_components.md](system_components.md) — the target component inventory for the module paths above
- [Host ↔ Cluster Comms Doctrine](../documents/engineering/host_cluster_comms_doctrine.md) — the host-only
  NodePort, no-mTLS channel-2 peer design this phase implements
- [Apple Metal Headless Builds](../documents/engineering/apple_metal_headless_builds.md) — the headless,
  on-host, no-Tart fixed-Metal-bridge build/run shape this phase implements
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — the apple host worker, the Lima
  provider, the no-env/no-`PATH` tool-ensure, and the `pb` midwife contract this phase implements
- [Pulsar Client Doctrine](../documents/engineering/pulsar_client_doctrine.md) — the native-protocol CBOR
  client the peer rides on (cross-reference, not adopted here)
- [Vault / PKI Doctrine](../documents/engineering/vault_pki_doctrine.md) — the secrets-by-name client auth the
  channel-2 peer resolves through (cross-reference, not adopted here)
- [phase_32](phase_32_jitbuild_engine_cache.md) — the jit-build engine resolver + `CacheBudget` cache the Metal
  kernel is materialized into
- [phase_34](phase_34_jitml_lift_cuda.md) — the CUDA jitML lift; its Windows-CUDA case is the structurally
  identical host worker on a different substrate
- [Engineering Doctrine Index](../documents/engineering/README.md) — the doctrine suite these phases adopt
