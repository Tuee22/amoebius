# `vendor/supernova` — reviewed external source

> **Purpose**: Record the upstream provenance of the vendored `supernova` and `proto` packages and the edits
> the local copy carries.
> **Read this if**: the vendored Pulsar-client source is being reviewed, refreshed, or considered for removal.

This file records provenance for one vendored upstream. It owns no plan status and no gate; the Phase-1
contract in [`../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md`](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md)
owns both.

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_01_toolchain_spike.md
**Generated sections**: none

</details>

## Upstream

| Field | Value |
|---|---|
| Project | `supernova` |
| Upstream repository | https://github.com/cr-org/supernova |
| Upstream channel | default branch |
| Released package name/version | `supernova-0.0.3`, and the `proto-0.0.1` package it is built beside |
| Local package versions | `0.0.3` and `0.0.1` (unchanged; the edits below add no behaviour) |

No upstream revision identifier is recorded here. A frozen commit or archive checksum is resolver output, not
an authored requirement ([`repository_layout_doctrine.md` §4](../../documents/engineering/repository_layout_doctrine.md#4-dependency-and-toolchain-resolution)).

## What is vendored, and what is left behind

The two Haskell packages are vendored: `lib/` (the `supernova` library) and `proto/` (the `proto` package that
turns `pulsar_api.proto` into the protocol bindings), each with its `Setup.hs`, its `LICENSE`, and its source
tree. Four things upstream carries are not copied, because nothing here reads them:

- the Nix expressions (`default.nix`, `pkgs.nix`, `shell.nix`, `ci.nix`) and the GitHub Actions workflow —
  upstream's build and CI, both of which pin revisions this repository refuses to carry
  ([§4](../../documents/engineering/repository_layout_doctrine.md#4-dependency-and-toolchain-resolution));
- the upstream `README.md`, whose only consumer was `supernova.cabal`'s `extra-source-files` entry, deleted
  with it;
- `lib/test/`, upstream's own test suite. It is upstream's evidence about upstream, not amoebius's about
  amoebius, and vendoring it would put `streamly` and `aeson` into the pre-cluster solve for a suite no gate
  here runs;
- `lib/src/Proto/PulsarApi.hs` and `lib/src/Proto/PulsarApi_Fields.hs`, which is the edit worth reading
  carefully — see below.

## The local compatibility edits

**One import, for GHC 9.12.** GHC 9.12 removed the re-export of `Control.Monad.void` that
`Control.Monad.Reader` used to supply transitively, so `Pulsar.Internal.Core` fails `-Wall` with an
out-of-scope `void`. The vendored module adds the explicit import and changes nothing else.

**The generated protocol bindings are generated here rather than tracked here.** Upstream commits
`Proto/PulsarApi.hs` and `Proto/PulsarApi_Fields.hs` — some 32,000 lines that `proto-lens-protoc` emits from
`pulsar_api.proto` — into the `supernova` library's own source tree, alongside a `proto` package that
generates the same two modules from the same `.proto` file and then exposes neither. Tracking generated output
is exactly what this repository does not do
([`repository_layout_doctrine.md` §3](../../documents/engineering/repository_layout_doctrine.md#3-complete-generated-output-inventory)),
and a tracked copy of a generator's output is a second source of truth that drifts silently from the `.proto`
it claims to encode. So the vendored copy deletes the two committed modules, promotes them from
`other-modules` to `exposed-modules` in `proto.cabal`, and has `supernova.cabal` depend on `proto` for them.
The bindings are then build output beneath `.build/` on every run, produced by the same generator from the
same schema.

That edit is larger in effect than the import and smaller in risk than it looks: both halves of the
duplication were already the output of one generator over one input, so making the second half the only half
removes a copy rather than changing a definition.

**Why vendored rather than patched.** The compatibility edits above were a four-line diff under `patches/`,
replayed by a `post-checkout-command` against whatever `master` happened to be at resolution time. That is a
diff re-applied to source no one reviewed, which is the coupling
[`repository_layout_doctrine.md` §4.1](../../documents/engineering/repository_layout_doctrine.md#41-a-compatibility-edit-is-vendored-source-not-a-patch-against-a-moving-head)
removes. The copy carries its own review surface — sixteen modules and one schema, with the generated bulk
left out — and no revision pin. `vendor/dual/PROVENANCE.md` records the same trade for the other vendored
package; the earlier position that `supernova` was too large to review retired with the patch that argued it.

**What it forecloses.** Automatic pickup of upstream `supernova` fixes. That is the intended trade: a refresh
is a reviewed source update rather than a silent solver move.

## Related Documents

- [Repository Layout and Artifact Provenance](../../documents/engineering/repository_layout_doctrine.md) —
  [§4.1](../../documents/engineering/repository_layout_doctrine.md#41-a-compatibility-edit-is-vendored-source-not-a-patch-against-a-moving-head)
  owns the patch-versus-vendored-source rule this file is one instance of
- [`vendor/dual/PROVENANCE.md`](../dual/PROVENANCE.md) — the other vendored upstream, recorded on the same terms
- [Pulsar Client Doctrine](../../documents/engineering/pulsar_client_doctrine.md) — the amoebius client this
  fork is the starting point for
- [Phase 1: Toolchain spike](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md)
