# amoebius

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, documents/documentation_standards.md
**Generated sections**: none

> **Purpose**: Entry point for amoebius — an everything-orchestrator whose Dhall DSL makes illegal cluster
> state unrepresentable.

amoebius is a single Haskell binary that runs as a **CLI**, a **sudo-capable host daemon**, and an
**in-cluster singleton service**. It manages Kubernetes cluster lifecycle and interprets a `.dhall` DSL
into opinionated, provably-coherent deployments. Its constituent capabilities are unified libraries, not
separate products: **prodbox** (root control-plane behaviour), **infernix** + **jitML** (ML extensions),
**hostbootstrap** (bootstrap + DSL core), and **mattandjames** (application logic).

## Where to start

- **The plan:** [`DEVELOPMENT_PLAN/README.md`](./DEVELOPMENT_PLAN/README.md) — the single, authoritative,
  numerically-ordered phased plan that delivers the vision. Phase 0 is the complete documentation suite.
- **The doctrine:** [`documents/engineering/README.md`](./documents/engineering/README.md) — the index of
  all engineering doctrine (the DSL, platform services, storage, secrets, runtime, verification).
- **How docs work:** [`documents/documentation_standards.md`](./documents/documentation_standards.md).

## Toolchain

GHC 9.12.4, Cabal 3.16.1.0 (one shared pin across all packages).

## Working agreement

LLMs/assistants must not run `git add`, `git commit`, or `git push`; staging and committing are reserved
for the human (see [`CLAUDE.md`](./CLAUDE.md)).
