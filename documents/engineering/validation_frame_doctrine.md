# Validation frame doctrine

> **Purpose**: Define the validation frame — the `amoebius-base` container in which every language-validation
> verb executes — and establish why a gate that runs inside it still declares substrate `none`.
> **Read this if**: a gate compiles, typechecks, decodes, or renders, and you need to know where that runs and
> what the run may assume about the host.

This document owns one idea: **language validation happens inside the image, not on the host.** It owns the
frame's contents, the bind mount through which generated output leaves it, the argument that a frame-lifted
gate remains substrate-neutral, and the single exception the browser suite carves out. It does not own how the
image is built or published — owned by [image_build_doctrine.md](./image_build_doctrine.md) — nor what a
register is, owned by [testing_doctrine.md](./testing_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_phase_model.md, documents/engineering/README.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/testing_doctrine.md, documents/glossary.md
**Generated sections**: none

</details>

---

## 1. The frame: one environment, every language

A DSL project validates in several languages at once — Dhall schemas, Haskell decoders and folds, PureScript
UI sources, a JSON/YAML render surface. Each needs a compiler or interpreter at an exact version, and each of
those is a fact about the machine the validation ran on rather than about the thing being validated. Left on
the host, a language-validation gate proves "this typechecks *here*", and the plan cannot tell a genuine
result from a locally lucky toolchain.

The **validation frame** removes the host from the claim. Every language-validation verb the host binary
offers is a `docker run --rm` into `amoebius-base`, and the toolchain the run uses is the one the image
carries. Two runs of the same verb against the same source differ only if the image differs, and the image is
named by an architecture-qualified tag ([image_build_doctrine.md §3](./image_build_doctrine.md#3-one-image-per-architecture--the-tag-carries-the-architecture-not-an-index)).
The host contributes a container engine and nothing else.

**The engine is the whole host requirement, and the host band supplies it on every substrate.** Phases 6, 7,
and 8 exist to make exactly that true — Docker configured sudoless on Linux, Colima on Apple, WSL2-hosted
Docker on Windows — each at its own natural architecture
([substrate_doctrine.md §4.1](./substrate_doctrine.md#41-colima-and-lima-on-apple-the-provider-follows-the-workload)).
That is why the frame is available before the DSL band opens and why the band may assume it.

## 2. What the frame carries, and why it lives in the base

`amoebius-base` carries the **language toolchains**, not merely the runtime libraries the services need. That
is a deliberate choice with a real cost — every pod that pulls the base pulls a compiler it will not run — and
it buys two things worth more than the bytes.

- **One lineage.** The base is pushed and the amoebius binary is layered on it, so the environment that
  *validated* the source is the environment that *runs* it. A separate, smaller runtime base would be a second
  lineage, and a second lineage is a second thing to keep in step with the catalog.
- **One recipe to audit.** The acquisition ladder admits `AptPackage`, `OfficialArtifact`, `BuildProduct`, and
  `CopyOci` and nothing else. A toolchain acquired through those rungs is auditable in the same way every
  service in the image is; a toolchain installed on a developer's host is not.

Rung-3 build products are still compiled in throwaway builder containers rather than in the image, because a
build product's *inputs* are not something the image should carry. The distinction is between a toolchain the
frame **runs** — which belongs in the base — and a toolchain a build **consumes once** — which does not.

## 3. Why a frame-lifted gate is still `Substrate: none`

`Substrate: none` asserts that a gate is **decidable on every substrate in the catalog**. It has never meant
"uses no tools"; a gate that reaches a Linux kernel tracer has declared `linux-cpu` whether it says so or not
([testing_doctrine.md §8](./testing_doctrine.md#8-one-substrate-per-validation)).
The test is availability, not absence.

The frame passes that test where `strace` failed it. `strace` exists on one substrate; a container engine
exists on all three, at each one's natural architecture, because the host band gates it there. A verb lifted
into the frame is therefore *more* substrate-neutral than the same verb run natively, not less: natively it
inherits whatever compiler the host happens to have, and framed it inherits the image.

**A separate container is not a fake.** Register 1 already admits a separate *process* — a pinned, hermetic,
deterministic checker over committed source is Register 1 even when it runs out-of-process, as TLC through the
pinned `tla2tools.jar` does. What distinguishes Register 2 is a **fake tool standing in for infrastructure**,
not a process or container count
([conformance_harness_doctrine.md §2](./conformance_harness_doctrine.md#2-the-registers-as-amoebius-uses-them-for-pre-cluster-validation)).
The frame fakes nothing: it carries the real compilers, and the source it compiles is the committed source.

## 4. Generated output leaves through one bind mount

A framed run writes nothing to the authored tree. Its output lands in a single bind-mounted directory beneath
`.build/`, which is ignored by both `.gitignore` and `.dockerignore`, so the container cannot smuggle a
generated artifact into the repository and a build context cannot carry one back in
([generated_artifacts_doctrine.md](./generated_artifacts_doctrine.md)).

This is what makes `--rm` honest. The container is discarded at the end of every verb, so no state survives a
run except what crossed the mount, and the mount is inspected by the same artifact policy that governs every
other generated root. A verb that needed writable state elsewhere in the container would be declaring a
dependency the frame does not model, and is rejected rather than accommodated.

## 5. The one exception: browsers

End-to-end browser tests do not run in the frame. They run in a **dedicated Playwright image**, also built
from Ubuntu, carrying Chromium, Firefox, and WebKit, and every end-to-end test runs against all three
([testing_doctrine.md §13](./testing_doctrine.md#13-end-to-end-tests-run-in-the-playwright-image-against-three-browsers)).

The exception is bounded by how the image is obtained rather than by what it contains. `amoebius-base` is
published and preferentially pulled; the Playwright image is **never published** and is built on demand,
idempotently, by the host binary. Three browser engines and their system libraries are a large payload that
no workload ever needs, and pushing it would put a test-only artifact into the lineage every pod pulls.

## Related Documents

- [image_build_doctrine.md](./image_build_doctrine.md) — how `amoebius-base` is built, tagged, and published.
- [testing_doctrine.md](./testing_doctrine.md) — the registers, the execution lane, and the browser policy.
- [conformance_harness_doctrine.md](./conformance_harness_doctrine.md) — how the registers are used pre-cluster.
- [substrate_doctrine.md](./substrate_doctrine.md) — the substrate catalog and the tool-ensure contract.
- [generated_artifacts_doctrine.md](./generated_artifacts_doctrine.md) — where generated output is allowed to land.
- [`DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md) — the tracker that owns current phase status.
- [`development_plan_phase_model.md` §L](../../DEVELOPMENT_PLAN/development_plan_phase_model.md#l-one-substrate-discipline) — the one-substrate rule this frame satisfies.
