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
**Referenced by**: documents/README.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_techniques.md, documents/reading_order.md
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
  It answers *where the claim is checked*. Haskell declarations record the locus per subcase and lazily emit
  any tabular view beneath `.build/docs/**`; no tracked serialized locus registry is authoritative.
- **Case family** — the structural axis, closed at fourteen members: `accelerator` · `backup` · `cache` ·
  `capability-provision` · `capacity` · `image` · `lifecycle` · `messaging` · `ml-asset` · `multicluster` ·
  `security` · `storage` · `topology` · `ui`. It answers *what the state is about*.

  The members are listed here rather than described, because an axis defined as "whatever the entries happen to
  use" cannot make an empty cell a defect — a family nothing declares would produce no cells to be empty, so
  the covering could never report a missing domain. This list is the reader-facing specification of the axis.
  A separately reviewed Haskell declaration must encode exactly these values; the Haskell covering-grid
  generator consumes that declaration, never this Markdown, and may materialize views only beneath
  `.build/**`. The existing Python/Markdown/TSV mechanisms are condemned
  migration footprints tracked only by
  [`legacy_tracking_for_deletion.md`](../../DEVELOPMENT_PLAN/legacy_tracking_for_deletion.md). Note that the family axis is **not** a
  refinement of the themed slices and is not meant to be: there is a `tenancy` slice with no `tenancy` family
  (its states are `security`), and `backup`, `image`, `ui` and `accelerator` are families with no slice of
  their own. A slice is a reading unit; a family is a subject.

A **cell** is one triple, and an entry specifies the cells it occupies on its own **`Cells:`** line — one
`` `layer`×`locus` `` pair per foreclosure the entry makes, so a reader can inspect the intended pairing.
The line is doctrine, not a serialized registry: no generator, checker, or oracle may parse it. The executable
pairing is a separately reviewed Haskell value, and a separate Haskell oracle checks it. Every cell either
holds at least one catalog entry, is inadmissible under the relation below, or
carries a one-line statement of why no illegal state lives there; an unjustified empty cell is a defect. A
justification may cover a whole row or column where the reason is structural rather than particular. The grid
itself is **generated** to `.build/docs/` from Haskell declarations of the three axes, so widening an axis
reports its own new empty cells. Markdown remains explanatory doctrine and never becomes executable input.

**Historical result (invalidated).** Before this reset, the Python generator credited an entry with
the *product* of every layer its prose named and every locus its prose named, because the pairing lived in
sentences no parser could split. Fifty-eight of the ninety-seven entries name more than one of each, so the
grid reported 143 occupied cells where the entries assert 64 — occupancy was an upper bound, the unjustified
count a floor, and eleven cells were left owing a reason nobody could honestly write, because each was
*unknown* rather than empty. The `Cells:` line replaces that estimate with a measurement, and the eleven
resolved into occupied, inadmissible, and three genuinely empty cells whose reasons are stated below. Those
numbers are rationale only and cannot be reused as current evidence; the Python/Markdown parser remains
condemned by the active legacy register.

### Which locus can observe which layer

The layer answers *what kind of impossibility is claimed*; the locus answers *where a fixture observes it*.
They classify different questions, but their product is not inhabited: a locus **downstream** of the check
that forecloses a state never sees that state, because the value did not survive to reach it, and a locus
**upstream** of the effect a residue is about cannot settle it, because the effect has not happened yet. Seven
of the eighteen pairs are inhabitable and the other eleven are empty for that reason rather than for want of
an entry. A reviewed Haskell relation must encode this rule, a separately authored Haskell oracle must check
it, and any tabular view is emitted only beneath `.build/**`; neither may parse this explanatory table.

| layer | loci that can observe it | why not the others |
|---|---|---|
| `type-foreclosed` | `dhall-typecheck` · `gadt-decode` · `extension-astcheck` | An uninhabitable value has no constructor, so nothing after the authoring-time and link-time checks can observe it: the seal folds decoded values, the oracle reads rendered output, and the cluster runs an applied one. Where an entry appears to pair this layer with a later locus, it is pairing its *residue* — a different, weaker claim — with that locus, and its `Cells:` line says so. |
| `decode-foreclosed` | `gadt-decode` · `provision-seal` · `rendered-artifact-oracle` | The three loci are the total pure checks that reject a **constructible** value before any effect. `dhall-typecheck` is excluded from the other side: a state the Dhall typechecker refuses is one the schema gives no inhabitant, which is type-foreclosure by definition. `live-effect` is excluded because a checked rejection happens before the effect exists. |
| `runtime-checked` | `live-effect` | A runtime-checked residue is exactly what remains *after* every authoring-time, decode-time, seal-time, and render-time check has passed. Each of those runs before any effect exists to observe, so none of them can settle it. |

The relation is a consequence of what the two axes mean, and it holds one honest surprise: the layer is a
**function of the locus** everywhere except `gadt-decode`, which admits both foreclosure layers because Dhall
has no opaque types and the residual teeth of a type-foreclosure land at the Haskell decoder
([`illegal_state_techniques.md` §6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)).
So the layer axis carries one bit of information beyond the locus axis, at one locus, and that bit is what
each entry's `Cells:` line specifies for the reader and its Haskell counterpart declares for execution.

### The justified empty cells

In these rows `*` reads as "every member of that axis". They apply only to **admissible** cells: the eleven
inadmissible pairs are already foreclosed by the relation above and need no row. This table records doctrine
for human review only. The target grid at `.build/docs/covering.tsv` resolves each cell against independently
reviewed Haskell occupancy, relation, and justification values; it never reads this table.

| cell | why no illegal state lives there |
|---|---|
| `*` × `extension-astcheck` × `*` | The extension AST checker judges linked extension **source**, not a decoded spec value. Only a family whose illegal states are reachable from linked source can occupy this locus, which today is `lifecycle` alone ([§3.78](./illegal_state_lifecycle.md#378-extension-source-that-reaches-outside-the-sanctioned-api)). |
| `*` × `*` × `cache` | A cache is a substrate, not a subject. Every way a cache can be wrong is already some other family's state seen through it: a cache **key** that admits two scopes is a `security` state ([§3.95](./illegal_state_tenancy.md#395-a-replay-key-that-does-not-name-its-scope)), a cache that grows without a ceiling is a `capacity` state, and a cache holding a stale build output is an `ml-asset` or `image` state. Nothing is illegal *because* it is cached, so no cell in this column has an occupant that is not double-counted from another column. The family stays declared because a reviewer looks for it, and an axis member with a stated reason is more useful than a member quietly absent. |
| `*` × `gadt-decode` × `accelerator` | Both accelerator states are capacity arithmetic over a node's declared devices — an ownership index and a memory envelope. Arithmetic is decided by the capacity fold at the seal, not by decoding a value's shape. |
| `type-foreclosed` × `gadt-decode` × `capacity` | Capacity is a *value*, not a type index, and Dhall has no dependent arithmetic to make `Σ ≤ cap` a statement about inhabitance ([`illegal_state_techniques.md` §6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)). So no capacity state is uninhabitable at the decoder: the family's type-foreclosures are *shapes* — closed controller-policy arms, mandatory fields, the absent `Exempt` arm — and every one of those is refused at `dhall-typecheck`, while what reaches the decoder is a checked rejection. |
| `type-foreclosed` × `gadt-decode` × `image` | An image state is settled by the schema: the closed `ImageIdentity` union, the required `process` field, and the closed build-content union each give the illegal shape no arm to write, so all three fail `dhall type`. What is left for the decoder is a *relation between names* — a worker naming an extension its binary does not link ([§3.77](./illegal_state_lifecycle.md#377-a-worker-naming-an-extension-its-own-binary-does-not-link)) — and a cross-field relation is a fold, never an absent inhabitant. |
| `decode-foreclosed` × `gadt-decode` × `capability-provision` | A capability is a name in a closed union and a grant is the image of one total derivation of the tenant→role graph, so both illegal states are absences of a constructor rather than values a fold rejects. The family's one checked rejection is whole-deployment source equality between the derived policies and their demands, which is a `provision-seal` fold over the bound deployment, not a decode-local one. |
| `*` × `provision-seal` × `backup` | A backup lives in a remote append-only store outside the deployment the seal folds. The seal decides whether *this* deployment's declared resources fit its targets, and a backup coordinate is neither a resource it provisions nor a capability it binds. |
| `*` × `provision-seal` × `image` | The seal folds a deployment's resource and capability graph. An image's content is fixed at build time and enters that graph as an already-resolved identity, so there is nothing left for the seal to decide about it. |
| `*` × `dhall-typecheck` × `lifecycle` | The lifecycle states are claims about *ordering and authority over time* — a readiness edge, a promotion, a chaos target, extension source. None is a shape a total typechecker can refuse; each needs a decoded graph or a running system. |
| `*` × `provision-seal` × `lifecycle` | The same reason from the other side: the seal is a fold over resources and capabilities at one instant, and every lifecycle state is a claim about a sequence. |
| `*` × `rendered-artifact-oracle` × `lifecycle` | A rendered object set says what will exist. It does not say in what order those objects become ready, or who is permitted to promote them, which is what this family forecloses. |
| `*` × `provision-seal` × `messaging` | Both messaging states concern a payload's encoding and a feed's merge order — properties of a wire and a stream, not of the resource graph the seal folds. |
| `*` × `rendered-artifact-oracle` × `messaging` | A CBOR body and a partition merge order never appear in a rendered manifest: the manifest names the broker, not what crosses it. |
| `*` × `rendered-artifact-oracle` × `ml-asset` | An ML asset is named by content and resolved into a bounded cache on first miss. Neither its identity nor its readiness is emitted into the object set, so a rendered golden has nothing of it to compare. |
| `*` × `rendered-artifact-oracle` × `multicluster` | A multi-cluster state is a relation *between* two clusters' specs. The rendered output of either one shows only its own half, so the relation has no witness there. |
| `*` × `rendered-artifact-oracle` × `storage` | Storage states are decided by the geometry folds before rendering and by the live volume afterwards. The emitted PVC/PV pair restates the fold's conclusion rather than testing it. |

**Target covering claim — NOT VALIDATED.** The Haskell generator must resolve all **252** cells — 3 layers ×
6 loci × 14 families — against Haskell-declared entry pairings, relation, and justifications whose rationale
is stated above. The
following counts are target expectations, not a current tool result:

| | cells |
|---|---|
| occupied by at least one entry | 64 |
| inadmissible: the layer cannot be observed at that locus | 154 |
| admissible, empty, and justified | 34 |
| **admissible, empty, and still owing a reason** | **0** |

The obligation is not discharged until Phase 27 has a reviewed Haskell subject, an independent Haskell
oracle, a qualified harness, and human promotion. The target occupancy uses declared pairings rather than an
upper bound over prose. Historical analysis reduced an earlier estimate from 143 to 64 and exposed defects,
but that analysis is rationale, not current validation evidence — an
`image` state was recorded as having no runtime residue when [§3.77](./illegal_state_lifecycle.md#377-a-worker-naming-an-extension-its-own-binary-does-not-link)
plainly claims one, and five entries claimed a foreclosure layer at no locus at all
([§3.69](./illegal_state_multicluster.md#369-a-cold-seeded-secondary-taking-the-gateway-without-proven-freshness),
[§3.83](./illegal_state_security.md#383-a-ui-plan-executed-after-an-authority-bearing-source-changed),
[§3.92](./illegal_state_tenancy.md#392-a-scope-filter-whose-absent-value-means-every-scope),
[§3.96](./illegal_state_tenancy.md#396-a-scope-column-that-admits-null),
[§3.97](./illegal_state_tenancy.md#397-a-scope-key-whose-rendering-is-not-injective)), which is a claim with
nothing behind it.

A complete covering would establish exhaustiveness relative to these three axes and to nothing else — a hazard
lying along an axis nobody declared stays outside the claim, which is the residue
[`illegal_state_techniques.md` §6.2](./illegal_state_techniques.md#62-the-covering-obligation--exhaustive-relative-to-a-declared-taxonomy)
carries. The covering also says nothing about whether an occupied cell's entry is *right*; that each entry's
foreclosure actually rejects its fixture at the locus it names is the Phase-27 corpus obligation, keyed to the
same pairing through separately reviewed Haskell declarations. Any serialized registry is lazily generated
beneath `.build/**` and has no verdict authority.

## Related Documents
- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the authoritative catalog index.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the typing techniques and coverage matrix.
- [`illegal_state_tenancy.md`](./illegal_state_tenancy.md) — the newest slice: scope learned at run time.
- [`../documentation_standards.md` §16](../documentation_standards.md#16-the-illegal-state-catalogue-is-a-covering-not-a-list) — the covering obligation this router declares the taxonomy for.
- [`../README.md`](../README.md) — the top-level documentation index.
- [`../engineering/README.md`](../engineering/README.md) — the sibling engineering doctrine family.
