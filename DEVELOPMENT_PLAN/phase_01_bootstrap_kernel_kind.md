# Phase 1: Bootstrap + kernel + single kind cluster

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, legacy_tracking_for_deletion.md, overview.md, system_components.md
**Generated sections**: none

> **Purpose**: Specify the first implementation phase — substrate detection, the no-`PATH` lazy tool-ensure
> contract, the `dsl-step`/`chain` kernel seeded from hostbootstrap, the binary as CLI + host context, and an
> idempotent `bootstrap` that brings up an empty single-node kind cluster and is a no-op on re-run.

---

## Phase Status

📋 Planned. Nothing in this phase is implemented; every sprint below is design intent, and every
`Implementation` field names a **target** module path in the intended layout, not an existing one. The gate
has not run on any substrate. Per [development_plan_standards.md §K](development_plan_standards.md), no sprint
is marked Done — or 🧪 Live-proof-pending — until its proof actually runs on `linux-cpu`.

## Phase Summary

This phase delivers the smallest end-to-end slice of amoebius that can *act on a host*: it learns what the
machine is, ensures the host tools it needs without ever consulting `PATH`, seeds the pure Step/Chain kernel
that every later reconcile rides on, exposes the binary as a CLI carrying a typed host context, and uses all
of that to stand up — and re-converge to — an empty single-node kind cluster. It is deliberately *empty*:
no platform services, no storage, no Vault — those are [Phase 2](README.md). The one thing Phase 1 must prove
is that `amoebius bootstrap` is an **idempotent reconcile**, not a one-shot script.

Scope **in**: substrate detection (pure classify over three reads); the closed host-tool enum + `AbsExe`
absolute-path discipline + probe-first `install-and-verify` for `ghcup`/`cabal`/`kubectl`/`kind` (no env, no
`PATH`, no Helm); the `dsl-step`/`chain` kernel (Step algebra, recursive interpreter, dry-run plan render);
the binary as CLI + host context (parameters/context/witness); `bootstrap.sh` igniter and
`bootstrap --distro={kind,rke2} [--replicas=n]` bringing up an empty single-node kind cluster idempotently.
Scope **out**: standard services, retained PVs, Vault/PKI, the in-cluster control-plane singleton, provider
clusters, amoebic spawning — all later phases.

**Substrate:** linux-cpu (the default validation substrate; tracked in [substrates.md](substrates.md), per
[development_plan_standards.md §L](development_plan_standards.md)). The Apple/Windows VM providers and host
worker nodes named in the substrate doctrine are explicitly **not** exercised by this gate; they land in
Phase 7.

**Gate:** on a `linux-cpu` host, `amoebius bootstrap --distro=kind` brings up an empty single-node kind
cluster (`kubectl get nodes` shows exactly one `Ready` node); **re-running the identical command is a
no-op** — the reconcile reports already-converged and changes nothing — and the run touched no host tool by
bare name (every external invocation went through an `AbsExe` absolute path).

## Doctrine adopted

- **Substrate doctrine — the `bootstrap.sh` contract and the no-environment / no-`PATH` lazy tool-ensure
  contract.** This phase implements
  [`substrate_doctrine.md` §6 — the `bootstrap.sh` contract](../documents/engineering/substrate_doctrine.md#6-the-bootstrapsh-contract-ensure-a-toolchain-build-the-binary-hand-off)
  (the thin substrate-specific igniter that ensures the package-manager root, installs the pinned GHC 9.12.4 /
  Cabal 3.16.1.0 toolchain via `ghcup`, builds the binary, and hands off to `bootstrap`) and
  [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract)
  (probe → install-if-absent → resolve absolute path → invoke by full path; the closed `HostTool` enum and the
  unexported `AbsExe` constructor that makes a bare-name invocation unrepresentable — and, for this phase,
  ensuring `ghcup`/`cabal`/`kubectl`/`kind` but **not** Helm). Substrate detection itself is adopted from
  [`substrate_doctrine.md` §2 — detection as a pure classification over three reads](../documents/engineering/substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads).
- **DSL doctrine §2–§3 — the chain/Step kernel and the binary-context surface.** This phase seeds, from
  hostbootstrap, the
  [`dsl_doctrine.md` §2 — two languages, one system: Dhall carries params, Haskell carries logic](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic)
  Step/Chain algebra (`chain :: cfg -> [Step]`, each `Step` = a pure renderable shape plus an effectful
  `stepRun`, with a thin effectful interpreter seam and a pure dry-run plan render) and the
  [`dsl_doctrine.md` §3 — the orchestration surface: parameters, context, witness](../documents/engineering/dsl_doctrine.md#3-the-orchestration-surface-parameters-context-witness)
  binary-context contract (parameters / context / witness), adapted to the no-environment-variable invariant
  via file/socket-existence witnesses. The full Dhall orchestration DSL and the illegal-state gates ride on
  this kernel but are Phase 3, not here.
- **Cluster lifecycle doctrine §1–§2 — two cluster kinds and bring-up-as-reconcile.** This phase implements
  the self-managed half of
  [`cluster_lifecycle_doctrine.md` §1 — two cluster kinds, one lifecycle shape](../documents/engineering/cluster_lifecycle_doctrine.md#1-two-cluster-kinds-one-lifecycle-shape)
  (the host-binary-present `kind`/`rke2` cluster, in its root single-node form) and
  [`cluster_lifecycle_doctrine.md` §2 — bring-up and bootstrap](../documents/engineering/cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap),
  whose load-bearing claim for this gate is "**bring-up is itself a reconcile**" — re-running `bootstrap` when
  already converged is a no-op. The provider-managed half (§1) and post-bring-up init (Vault, the `.dhall`
  handoff, §2) are later phases.

## Sprints

## Sprint 1.1: Substrate detection 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/Substrate.hs` (target: a pure `classify` plus the three-read `detect`)
**Blocked by**: none
**Independent Validation**: unit tests of the total `classify` function over an OS × arch × GPU table, with
zero host I/O.
**Docs to update**: `documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`

### Objective

Adopt [`substrate_doctrine.md` §2 — detection as a pure classification over three reads](../documents/engineering/substrate_doctrine.md#2-detection-a-pure-classification-over-three-reads):
learn what the host *is* by classifying three runtime reads (OS, normalized architecture, NVIDIA-GPU
presence) into the closed substrate set, with the only `IO` being the reads — the substrate is detected, never
configured ([`substrate_doctrine.md` §1 — the substrate is a fact about the host, not a knob](../documents/engineering/substrate_doctrine.md#1-the-substrate-is-a-fact-about-the-host-not-a-knob)).

### Deliverables

- A total `classify :: OsName -> RawArch -> Gpu -> Either String Substrate` over the four-member catalog,
  with the two load-bearing hard-failure rules encoded: Apple is always `arm64` (Intel-Mac rejected), and a
  present NVIDIA GPU promotes Linux to `linux-cuda`.
- An `Either`-returning `detect :: IO (Either Substrate)` wrapping `classify` over the three reads (OS,
  `parseDockerArch`-normalized arch with non-`amd64`/`arm64` a hard `Left`, and an NVIDIA probe).
- For the gate substrate, classification of this host as `linux-cpu` (`amd64` or `arm64`, no GPU).

### Validation

1. Unit-test `classify` across the full OS × arch × GPU cross-product, asserting each expected substrate and
   each expected hard failure, with no host access.
2. Run `detect` on the `linux-cpu` gate host and confirm it returns `linux-cpu`.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 1.2: Lazy tool-ensure — closed enum, `AbsExe`, install-and-verify 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Host/HostTool.hs`, `src/Amoebius/Host/Ensure.hs` (target: the `HostTool`
enum + `AbsExe` newtype + `HostConfig` tool map + the `installAndVerify` driver)
**Blocked by**: Sprint 1.1
**Independent Validation**: pure `[InstallStep]` plan tests per substrate, plus a property that `mkAbsExe`
rejects every non-absolute path — no package manager invoked.
**Docs to update**: `documents/engineering/substrate_doctrine.md`

### Objective

Adopt [`substrate_doctrine.md` §3 — the no-environment / no-`PATH` lazy tool-ensure contract](../documents/engineering/substrate_doctrine.md#3-the-no-environment--no-path-lazy-tool-ensure-contract):
ensure `ghcup`, `cabal`, `kubectl`, and `kind` — and pointedly **not** Helm — through the substrate's package
manager and invoke them only by absolute path, making a bare-name invocation structurally unrepresentable
rather than merely discouraged.

### Deliverables

- A closed `HostTool` enum naming exactly the Phase-1 tool set (`ghcup`, `cabal`, `kubectl`, `kind`, and the
  package-manager root) — an unlisted tool cannot be invoked, and Helm is intentionally absent.
- An `AbsExe` newtype whose constructor is unexported; `mkAbsExe` rejects any non-absolute path, so a resolved
  tool is by type always an absolute path.
- A `HostConfig` carrying the detected substrate (Sprint 1.1) plus a `Map HostTool AbsExe`, and an
  `installAndVerify` driver that is probe-first and idempotent: probe → verified no-op if satisfied, else run
  the pure substrate-branched `[InstallStep]` plan, re-resolving every tool after each step, then re-verify or
  fail fast with a one-line diagnostic.
- `runTool` / `runToolWithStdin` that exec `absExePath` only — never a bare name.

### Validation

1. Unit-test each reconciler's `[InstallStep]` plan as a pure value per substrate (no package-manager call).
2. Property-test that `mkAbsExe` rejects non-absolute paths and that `runTool` has no code path that accepts a
   bare name.
3. On the `linux-cpu` host, ensure `kind`/`kubectl`/`cabal`/`ghcup` from clean, then re-run and confirm a
   verified no-op; confirm Helm is never ensured or invoked.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 1.3: The `dsl-step`/`chain` kernel 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Kernel/Step.hs`, `src/Amoebius/Kernel/Chain.hs` (target: the Step algebra,
the recursive interpreter, and the pure plan render, seeded from hostbootstrap)
**Blocked by**: none
**Independent Validation**: pure tests that `renderChainPlan` of a fixture chain matches a golden plan and
that the descent logic is exercised without running any `stepRun` action.
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Adopt [`dsl_doctrine.md` §2 — two languages, one system: Dhall carries params, Haskell carries logic](../documents/engineering/dsl_doctrine.md#2-two-languages-one-system-dhall-carries-params-haskell-carries-logic):
seed hostbootstrap's chain/Step algebra as the amoebius reconcile kernel — `chain :: cfg -> [Step]`, each
`Step` being a pure renderable shape (label, frame, `StepKind`) plus an effectful `stepRun`, with the chain
being the system and the config merely supplying `cfg`.

### Deliverables

- A `Step` type = label + frame + `StepKind` + `stepRun :: cfg -> IO ()`, and a `chain :: cfg -> [Step]`
  builder, both pure values.
- A pure `renderChainPlan` / `renderChain` that produces the exact plan a `--dry-run` would execute without
  running a single action — byte-for-byte what runs.
- A recursive interpreter (`runChainFromFrame`) that runs a step's action only when the binary is in that
  step's frame; the descent logic is pure and unit-tested, and `runChainFromFrame` is the one thin effectful
  seam.

### Validation

1. Golden-test `renderChainPlan` of a fixture chain against an expected rendered plan, asserting no action
   runs during render.
2. Unit-test the descent logic (frame matching) purely; assert an out-of-frame step is rendered but not run.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 1.4: The binary as CLI + host context 📋

**Status**: Planned
**Implementation**: `src/Amoebius/Cli.hs`, `src/Amoebius/Host/Context.hs`, `app/amoebius/Main.hs` (target: the
command parser, the parameters/context/witness binary context, and the executable entrypoint)
**Blocked by**: Sprint 1.1, Sprint 1.2, Sprint 1.3
**Independent Validation**: `amoebius --help` and `amoebius bootstrap --help` render the typed command surface;
a witness-gated command refuses fast when its file/socket witness is absent — with no cluster touched.
**Docs to update**: `documents/engineering/dsl_doctrine.md`

### Objective

Adopt [`dsl_doctrine.md` §3 — the orchestration surface: parameters, context, witness](../documents/engineering/dsl_doctrine.md#3-the-orchestration-surface-parameters-context-witness):
expose the binary as a CLI carrying a typed host context — parameters (substrate, distro, replicas),
context (where this binary sits), and witnesses (locally-checkable runtime facts) — adapted to the
no-environment-variable invariant via file/socket-existence witnesses rather than `PATH`/env-equality kinds.

### Deliverables

- A typed CLI surface parsing `bootstrap --distro={kind,rke2} [--replicas=n]` (replicas defaulting to `1` on
  `kind`), with an illegal flag combination rejected before any effect.
- A `BinaryContext` (parameters + context + witness) assembled from Sprint 1.1's substrate and Sprint 1.2's
  resolved tool map, gating each command on its witnesses passing (`commandAllowed` / `validateRuntimeContext`).
- `app/amoebius/Main.hs` wiring the parser to the Sprint 1.3 chain interpreter; commands compute a chain and
  either render it (`--dry-run`) or run it.

### Validation

1. `amoebius --help` and `amoebius bootstrap --help` render the typed surface; an out-of-domain flag combo
   exits non-zero before any effect.
2. A command whose witness (a required file/socket) is absent refuses fast with an actionable error, touching
   nothing.

### Remaining Work

The whole sprint (📋 Planned).

## Sprint 1.5: `bootstrap.sh` igniter + idempotent single-node kind bring-up 📋

**Status**: Planned
**Implementation**: `bootstrap.sh`, `src/Amoebius/Cluster/Bootstrap.hs`, `src/Amoebius/Cluster/Kind.hs`
(target: the substrate igniter script, the `bootstrap` command chain, and the kind bring-up reconciler)
**Blocked by**: Sprint 1.2, Sprint 1.4
**Independent Validation**: on a `linux-cpu` host, `amoebius bootstrap --distro=kind` yields exactly one
`Ready` node, and an immediate re-run reports already-converged and changes nothing.
**Docs to update**: `documents/engineering/cluster_lifecycle_doctrine.md`,
`documents/engineering/substrate_doctrine.md`, `DEVELOPMENT_PLAN/substrates.md`

### Objective

Adopt [`substrate_doctrine.md` §6 — the `bootstrap.sh` contract](../documents/engineering/substrate_doctrine.md#6-the-bootstrapsh-contract-ensure-a-toolchain-build-the-binary-hand-off)
(the thin igniter: ensure the package-manager root, ensure `ghcup`, install the pinned GHC 9.12.4 / Cabal
3.16.1.0 toolchain, `cabal build`, then hand off to `amoebius bootstrap`) together with
[`cluster_lifecycle_doctrine.md` §1 — two cluster kinds, one lifecycle shape](../documents/engineering/cluster_lifecycle_doctrine.md#1-two-cluster-kinds-one-lifecycle-shape)
and [`cluster_lifecycle_doctrine.md` §2 — bring-up and bootstrap](../documents/engineering/cluster_lifecycle_doctrine.md#2-bring-up-and-bootstrap):
the self-managed, host-binary-present, single-node kind cluster, brought up by a reconcile so that
**re-running is a no-op**.

### Deliverables

- A substrate-specific `bootstrap.sh` (the only shell script amoebius owns) that ensures the package-manager
  root pre-binary, installs the pinned toolchain via `ghcup`, builds the binary, and invokes
  `amoebius bootstrap --distro=kind [--replicas=n]`.
- A `bootstrap` command chain that detects the substrate (Sprint 1.1), ensures `kind`/`kubectl` by absolute
  path (Sprint 1.2), and drives single-node kind bring-up as a `discover → diff → enact → re-observe`
  reconcile — not a one-shot script.
- An empty cluster as the end state: one node, `Ready`, with **no** platform services (those are Phase 2).

### Validation

1. **Gate.** On a `linux-cpu` host, run `amoebius bootstrap --distro=kind`; assert `kubectl get nodes` shows
   exactly one `Ready` node.
2. **Idempotence (the gate's core claim).** Re-run the identical command; assert it reports already-converged,
   creates nothing, and leaves the single node `Ready`.
3. Assert every external tool invocation during the run resolved through an `AbsExe` absolute path (no bare
   name, no Helm).

### Remaining Work

The whole sprint (📋 Planned).

## Documentation Requirements

**Engineering docs to update:**
- `documents/engineering/substrate_doctrine.md` — when detection, the `AbsExe`/closed-enum tool-ensure, and
  the `bootstrap.sh` hand-off land, flip the §8 planning-ownership orientation note for Phase 1 from intent to
  delivered status pointer (status stays in the plan) and reconcile any seed-vs-target discovery caveats in §3.
- `documents/engineering/dsl_doctrine.md` — record that the §2 chain/Step kernel and the §3 binary-context
  surface are seeded in Phase 1 (the full Dhall DSL remains Phase 3).
- `documents/engineering/cluster_lifecycle_doctrine.md` — confirm the §2 "bring-up is itself a reconcile"
  no-op shape is exercised by the Phase 1 gate.

**Cross-references to add:**
- [README.md](README.md) — set the Phase 1 row status from "not started" once work begins, and link this
  document from the Phase 1 paragraph.
- [substrates.md](substrates.md) — record `linux-cpu` as the Phase 1 gate substrate in the per-phase substrate
  map.
- [system_components.md](system_components.md) — register the target module paths named in the sprint
  `Implementation` fields (`Amoebius.Host.*`, `Amoebius.Kernel.*`, `Amoebius.Cluster.*`, `Amoebius.Cli`).

## Related Documents

- [README.md](README.md) — the live tracker; its Phase 1 paragraph is the authoritative objective and gate
- [development_plan_standards.md](development_plan_standards.md) — the rulebook this document obeys
- [substrates.md](substrates.md) — the substrate registry and per-phase map (Phase 1: `linux-cpu`)
- [system_components.md](system_components.md) — the target component inventory the `Implementation` paths map to
- [Substrate Doctrine](../documents/engineering/substrate_doctrine.md) — detection, lazy tool-ensure, `bootstrap.sh`
- [DSL Doctrine](../documents/engineering/dsl_doctrine.md) — the chain/Step kernel and binary-context surface
- [Cluster Lifecycle Doctrine](../documents/engineering/cluster_lifecycle_doctrine.md) — two cluster kinds, bring-up-as-reconcile
