# `vendor/dual` — reviewed external source

> **Purpose**: Record the upstream provenance of the vendored `dual` package and the reason amoebius carries a
> local copy rather than a patch against a resolved revision.
> **Read this if**: the vendored `dual` source is being reviewed, refreshed, or considered for removal.

This file records provenance for one vendored package. It owns no plan status and no gate; the Phase-1
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
| Project | `dual` |
| Upstream repository | https://github.com/strake/dual.hs |
| Upstream channel | default branch |
| Released package name/version | `dual-0.1.1.2` |
| Local package version | `0.1.1.2` (unchanged; the compatibility edit adds instances only) |

No upstream revision identifier is recorded here. A frozen commit or archive checksum is resolver output, not
an authored requirement ([`repository_layout_doctrine.md` §4](../../documents/engineering/repository_layout_doctrine.md#4-dependency-and-toolchain-resolution)).

## The local compatibility edit

GHC 9.12 checks the unary superclasses of `Eq2`, `Ord2`, `Read2`, and `Show2`. The released package supplies
the binary instances and the `Functor`/`Foldable`/`Traversable` set but not `Eq1`/`Ord1`/`Read1`/`Show1`, so
`Control.Category.Dual` fails to compile under the pre-cluster compiler. The vendored source adds those four
instances using the same argument reversal the binary instances already use, and changes nothing else.

**Why vendored rather than patched.** `dual` is two small modules and the edit touches the instance set of one
of them. A patch would have to be re-reviewed against whatever the branch head happened to be on each clean
resolution, which is the coupling to a frozen revision this repository is removing. A reviewed source copy of
a two-module package carries its own review surface and no revision pin.

That reasoning is now the general rule rather than this package's exception. An earlier revision of this file
recorded `supernova` as taking the opposite trade and staying a four-line patch, on the ground that its tree
was too large to review. Size decides how much review a copy costs; it does not decide whether a diff replayed
against a moving head is still the diff that was reviewed.
[`repository_layout_doctrine.md` §4.1](../../documents/engineering/repository_layout_doctrine.md#41-a-compatibility-edit-is-vendored-source-not-a-patch-against-a-moving-head)
settles it in one direction for both packages. `supernova` now sits beside this one under
[`vendor/supernova/`](../supernova/PROVENANCE.md); the copy landed with
[`phase_01_toolchain_spike.md` Sprint 1.8](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md#sprint-18-vendor-supernova-retire-patches-),
which deleted the patch and the `patches/` root along with it.

**What it forecloses.** Automatic pickup of upstream `dual` fixes. That is the intended trade: the package has
had no release in the compatibility window, so there is nothing to pick up, and a refresh is a reviewed source
update rather than a silent solver move.

## Related Documents

- [Repository Layout and Artifact Provenance](../../documents/engineering/repository_layout_doctrine.md) —
  [§4.1](../../documents/engineering/repository_layout_doctrine.md#41-a-compatibility-edit-is-vendored-source-not-a-patch-against-a-moving-head)
  owns the patch-versus-vendored-source rule this file is one instance of
- [Phase 1: Toolchain spike](../../DEVELOPMENT_PLAN/phase_01_toolchain_spike.md)
