# Amoebius Illegal-State Catalog Family

> **Purpose**: Router for the illegal-state catalog family — the authoritative index is
> [`illegal_state_catalog.md`](./illegal_state_catalog.md); this file gives the folder a conventional entry
> point and defers to that index rather than restating it.
> **Read this if**: an enumerated illegal state needs locating, or the catalog's own structure is unclear.

This router explains how the illegal-state family is split: one index holding the enumeration, nine themed
slices holding the entries, and one document holding the techniques that foreclose them. It owns the split, the
taxonomy the catalog covers, and nothing else — the entries are owned by their slices and the techniques by
[illegal_state_techniques.md](./illegal_state_techniques.md). Reading it presumes the foreclosure vocabulary
that document defines.

<details>
<summary>Link-graph metadata</summary>

**Status**: Reference only
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/development_plan_gate_integrity.md, documents/README.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_techniques.md, documents/reading_order.md
**Generated sections**: none

</details>

---

The catalog family enumerates the cluster states a valid `InForceSpec` cannot represent, and the typing
techniques that foreclose them. It has three parts:

- **[`illegal_state_catalog.md`](./illegal_state_catalog.md)** — the authoritative index: the themed map of
  *which* states are foreclosed, the honest limit (a type-check proves the spec composes, not that a running
  cluster enforces it), and links into the nine themed sub-catalogs.
- **The nine themed sub-catalogs** — the deep, numbered `§3.N` entries, each carrying an `Owner`,
  `Technique`, `Layer`, and `Validation-locus`:
  [storage](./illegal_state_storage.md) ·
  [topology](./illegal_state_topology.md) ·
  [capacity](./illegal_state_capacity.md) ·
  [security](./illegal_state_security.md) ·
  [tenancy](./illegal_state_tenancy.md) ·
  [capability-messaging](./illegal_state_capability_messaging.md) ·
  [ml-asset](./illegal_state_ml_asset.md) ·
  [multi-cluster](./illegal_state_multicluster.md) ·
  [lifecycle](./illegal_state_lifecycle.md).
- **[`illegal_state_techniques.md`](./illegal_state_techniques.md)** — the nine typing techniques, the
  coverage matrix (one row per entry), the three foreclosure layers, and the validation-locus axis.

Phase order, status, and validation gates live **only** in
[`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md); the entries here state the target
design and never restate a phase status.

## The taxonomy the catalog covers

The catalog is a **covering over a declared taxonomy**, not a list, on the terms
[`documentation_standards.md` §16](../documentation_standards.md#16-the-illegal-state-catalogue-is-a-covering-not-a-list)
fixes. This router owns the declaration. The taxonomy is the product of three closed axes:

- **Foreclosure layer** — `type-foreclosed` · `decode-foreclosed` · `runtime-checked`, owned by
  [`illegal_state_techniques.md` §6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force).
  It answers *what kind of impossibility is being claimed*.
- **Validation locus** — `dhall-typecheck` · `gadt-decode` · `extension-astcheck` · `provision-seal` ·
  `rendered-artifact-oracle` · `live-effect`, owned by
  [`illegal_state_techniques.md` §6.1](./illegal_state_techniques.md#61-the-validation-locus-axis--where-each-illegal-state-is-caught-orthogonal-to-the-foreclosure-layer).
  It answers *where the claim is checked*, and is the axis
  [`dhall/examples/locus_registry.tsv`](../../dhall/examples/locus_registry.tsv) records per subcase.
- **Case family** — the structural axis, closed at fourteen members: `accelerator` · `backup` · `cache` ·
  `capability-provision` · `capacity` · `image` · `lifecycle` · `messaging` · `ml-asset` · `multicluster` ·
  `security` · `storage` · `topology` · `ui`. It answers *what the state is about*.

  The members are listed here rather than described, because an axis defined as "whatever the entries happen to
  use" cannot make an empty cell a defect — a family nothing declares would produce no cells to be empty, so
  the covering could never report a missing domain. This list is the axis;
  [`../../tools/covering_grid.py`](../../tools/covering_grid.py) reads it, and
  `tools/locus_registry_lint.py` accepts exactly these values. Note that the family axis is **not** a
  refinement of the themed slices and is not meant to be: there is a `tenancy` slice with no `tenancy` family
  (its states are `security`), and `backup`, `image`, `ui` and `accelerator` are families with no slice of
  their own. A slice is a reading unit; a family is a subject.

A **cell** is one triple. Every cell either holds at least one catalog entry or carries a one-line statement of
why no illegal state lives there, and an unjustified empty cell is a defect. A justification may cover a whole
row or column where the reason is structural rather than particular — a locus that a layer cannot reach names
that once, not once per family. The grid itself is **generated** to `.build/docs/` from the three axes, so
widening an axis reports its own new empty cells; the entries stay authored, because an entry is an independent
expectation.

### The justified empty cells

In these rows `*` reads as "every member of that axis". The generated grid at `.build/docs/covering.tsv`
resolves each cell against them.

| cell | why no illegal state lives there |
|---|---|
| `*` × `extension-astcheck` × `*` | The extension AST checker judges linked extension **source**, not a decoded spec value. Only a family whose illegal states are reachable from linked source can occupy this locus, which today is `lifecycle` alone ([§3.78](./illegal_state_lifecycle.md#378-extension-source-that-reaches-outside-the-sanctioned-api)). |
| `decode-foreclosed` × `dhall-typecheck` × `*` | Contradictory by definition. A state the Dhall typechecker refuses is one the schema gives **no inhabitant** — that is type-foreclosure. A decode-foreclosed state is precisely one the schema admits and the decoder then rejects, so it is caught at `gadt-decode`. Where a family appears to occupy this pair, it is an entry naming both tags in different sentences and the grid crediting the product. |
| `runtime-checked` × `dhall-typecheck` × `*` | Contradictory by definition, from the other side. A runtime-checked residue is what remains *after* every authoring-time check has passed; the typechecker runs before any effect exists to observe. |
| `*` × `*` × `cache` | A cache is a substrate, not a subject. Every way a cache can be wrong is already some other family's state seen through it: a cache **key** that admits two scopes is a `security` state ([§3.95](./illegal_state_tenancy.md#395-a-replay-key-that-does-not-name-its-scope)), a cache that grows without a ceiling is a `capacity` state, and a cache holding a stale build output is an `ml-asset` or `image` state. Nothing is illegal *because* it is cached, so no cell in this column has an occupant that is not double-counted from another column. The family stays declared because a reviewer looks for it, and an axis member with a stated reason is more useful than a member quietly absent. |
| `*` × `gadt-decode` × `accelerator` | Both accelerator states are capacity arithmetic over a node's declared devices — an ownership index and a memory envelope. Arithmetic is decided by the capacity fold, not by decoding a value's shape. |
| `*` × `provision-seal` × `backup` | A backup lives in a remote append-only store outside the deployment the seal folds. The seal decides whether *this* deployment's declared resources fit its targets, and a backup coordinate is neither a resource it provisions nor a capability it binds. |
| `*` × `live-effect` × `image` | An image state is settled before anything runs: the recipe is rendered from the catalog and the image is built from the recipe. A running cluster can only show that the wrong image was *pulled*, which is the registry's state rather than the image's. |
| `*` × `provision-seal` × `image` | The seal folds a deployment's resource and capability graph. An image's content is fixed at build time and enters that graph as an already-resolved identity, so there is nothing left for the seal to decide about it. |
| `*` × `dhall-typecheck` × `lifecycle` | The lifecycle states are claims about *ordering and authority over time* — a readiness edge, a promotion, a chaos target, extension source. None is a shape a total typechecker can refuse; each needs a decoded graph or a running system. |
| `*` × `provision-seal` × `lifecycle` | The same reason from the other side: the seal is a fold over resources and capabilities at one instant, and every lifecycle state is a claim about a sequence. |
| `*` × `rendered-artifact-oracle` × `lifecycle` | A rendered object set says what will exist. It does not say in what order those objects become ready, or who is permitted to promote them, which is what this family forecloses. |
| `*` × `provision-seal` × `messaging` | Both messaging states concern a payload's encoding and a feed's merge order — properties of a wire and a stream, not of the resource graph the seal folds. |
| `*` × `rendered-artifact-oracle` × `messaging` | A CBOR body and a partition merge order never appear in a rendered manifest: the manifest names the broker, not what crosses it. |
| `*` × `rendered-artifact-oracle` × `ml-asset` | An ML asset is named by content and resolved into a bounded cache on first miss. Neither its identity nor its readiness is emitted into the object set, so a rendered golden has nothing of it to compare. |
| `*` × `rendered-artifact-oracle` × `multicluster` | A multi-cluster state is a relation *between* two clusters' specs. The rendered output of either one shows only its own half, so the relation has no witness there. |
| `*` × `rendered-artifact-oracle` × `storage` | Storage states are decided by the geometry folds before rendering and by the live volume afterwards. The emitted PVC/PV pair restates the fold's conclusion rather than testing it. |

**What is specified, and what is still owed.** The taxonomy is normative and the grid is generated.
[`../../tools/covering_grid.py`](../../tools/covering_grid.py) resolves all **252** cells — 3 layers × 6 loci ×
14 families — against the 97 authored entries and the justification table above, and reports:

| | cells |
|---|---|
| occupied by at least one entry | 143 |
| empty and justified | 98 |
| **empty and still owing a reason** | **11** |

The sixteen justification rows above close 98 of the 109 empty cells: one column for the extension AST checker,
one for the `cache` family, twelve for families a particular locus structurally cannot reach, and two pairs
that are contradictory by definition.

**The eleven that remain are not justifiable as written, and that is the finding rather than a backlog item.**
In each, the family already occupies that locus at another layer, so the cell is not evidently empty — it is
*unknown*. The reason is a limitation of the entries, not of the tool: an entry that names several foreclosure
layers and several loci in prose is credited with the **product** of them, because no parser can tell which
layer the author paired with which locus. So the tool over-credits occupancy and under-reports the gap, and
**11 is a floor rather than a measurement**. Writing a reason for these cells would be inventing one.

They close when each entry pairs a layer to a locus explicitly, which is authoring work on the catalogue rather
than a better regex. The phase that owes it is named in
[`../../DEVELOPMENT_PLAN/README.md`](../../DEVELOPMENT_PLAN/README.md), and until then the covering is a
discharged obligation over 241 cells and a claim over 11.

A complete covering would establish exhaustiveness relative to these three axes and to nothing else — a hazard
lying along an axis nobody declared stays outside the claim, which is the residue
[`illegal_state_techniques.md` §6.2](./illegal_state_techniques.md#62-the-covering-obligation--exhaustive-relative-to-a-declared-taxonomy)
carries.

## Related Documents
- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the authoritative catalog index.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the typing techniques and coverage matrix.
- [`illegal_state_tenancy.md`](./illegal_state_tenancy.md) — the newest slice: scope learned at run time.
- [`../documentation_standards.md` §16](../documentation_standards.md#16-the-illegal-state-catalogue-is-a-covering-not-a-list) — the covering obligation this router declares the taxonomy for.
- [`../README.md`](../README.md) — the top-level documentation index.
- [`../engineering/README.md`](../engineering/README.md) — the sibling engineering doctrine family.
