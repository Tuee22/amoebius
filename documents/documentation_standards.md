# Amoebius Documentation Standards

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/README.md, DEVELOPMENT_PLAN/development_plan_standards.md, DEVELOPMENT_PLAN/overview.md, DEVELOPMENT_PLAN/phase_00_documentation_suite.md, README.md, documents/README.md, documents/engineering/README.md, documents/engineering/app_vs_deployment_doctrine.md, documents/engineering/apple_metal_headless_builds.md, documents/engineering/backup_recovery_doctrine.md, documents/engineering/bootstrap_sequence_doctrine.md, documents/engineering/capability_extension_doctrine.md, documents/engineering/chaos_failover_doctrine.md, documents/engineering/cluster_lifecycle_doctrine.md, documents/engineering/cluster_topology_doctrine.md, documents/engineering/conformance_harness_doctrine.md, documents/engineering/consistency_pacelc_doctrine.md, documents/engineering/content_addressing_doctrine.md, documents/engineering/daemon_topology_doctrine.md, documents/engineering/deterministic_simulation_doctrine.md, documents/engineering/dsl_doctrine.md, documents/engineering/formal_model_doctrine.md, documents/engineering/gateway_migration_doctrine.md, documents/engineering/gateway_migration_model_doctrine.md, documents/engineering/generated_artifacts_doctrine.md, documents/engineering/host_cluster_comms_doctrine.md, documents/engineering/image_build_doctrine.md, documents/engineering/inforcespec_migration_doctrine.md, documents/engineering/lift_and_compose_doctrine.md, documents/engineering/manifest_generation_doctrine.md, documents/engineering/monitoring_doctrine.md, documents/engineering/namespace_layout_doctrine.md, documents/engineering/network_fabric_doctrine.md, documents/engineering/platform_services_doctrine.md, documents/engineering/pulsar_client_doctrine.md, documents/engineering/pulumi_iac_doctrine.md, documents/engineering/readiness_ordering_doctrine.md, documents/engineering/release_lifecycle_doctrine.md, documents/engineering/resource_capacity_doctrine.md, documents/engineering/service_capability_doctrine.md, documents/engineering/single_logical_data_plane_doctrine.md, documents/engineering/storage_lifecycle_doctrine.md, documents/engineering/substrate_doctrine.md, documents/engineering/tenancy_doctrine.md, documents/engineering/test_derivation_analysis.md, documents/engineering/testing_doctrine.md, documents/engineering/vault_pki_doctrine.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: Single Source of Truth for how documentation is written and maintained across amoebius.

This adapts the conventions proven in the sibling `prodbox` project. The Phase 0 documentation suite — and
all later doctrine — conforms to it.

---

## 1. Philosophy

### SSoT-first
Every concept has **exactly one** canonical document. Other documents reference it; they never duplicate
it. SSoT ownership, bidirectional links, and non-duplication are mandatory for all doctrinal content.

### Development-plan authority
[`DEVELOPMENT_PLAN/README.md`](../DEVELOPMENT_PLAN/README.md) is the single source of truth for phase
order, status, validation gates, and remaining work. Documents under `documents/` explain architecture,
doctrine, and verification boundaries, and **link back to the plan** rather than maintaining competing
status ledgers.

### DRY + link liberally
Never copy-paste between documents. Use relative links with section anchors; prefer deep links
(`./engineering/dsl_doctrine.md#deployment-rules`).

### Separation of concerns
- **Engineering docs** (`documents/engineering/`): architecture, doctrine, patterns, verification
  boundaries.
- **Domain / operator docs**: workflows and configuration options.
- **Reference docs**: API and type indexes.

---

## 2. Naming

All documentation files use `snake_case.md` (`storage_lifecycle_doctrine.md`, `dsl_doctrine.md`). The only
ALL-CAPS exceptions are `README.md`, `CLAUDE.md`, and `AGENTS.md`. The `DEVELOPMENT_PLAN/` suite may define
its own internal structure but still uses the header metadata and relative-link discipline below.

---

## 3. Required header metadata

Every document begins with:

```markdown
# Document Title

**Status**: [Authoritative source | Reference only | Deprecated]
**Supersedes**: [N/A | path/to/old/doc.md]
**Referenced by**: [comma-separated list of docs that link here]
**Generated sections**: [none | comma-separated marker keys]

> **Purpose**: One-sentence description.
```

| Status | Meaning |
|--------|---------|
| `Authoritative source` | The SSoT for this topic |
| `Reference only` | Points to authoritative sources |
| `Deprecated` | Scheduled for removal |

Vague status values (e.g. "doctrine / notes") are forbidden. `Generated sections` is mandatory: `none`, or
the keys of any generated-marker pairs the file contains.

---

## 4. Cross-referencing

- Use **relative links with anchors**.
- **Bidirectional links:** when document A references document B, B's `Referenced by` must include A.
- Doctrine docs link back to `DEVELOPMENT_PLAN/README.md` for status/sequencing rather than restating it.

### Section references are always anchor links

A `§N` reference to a document section — the current document or another — **must** be a Markdown anchor
link, never bare `§N` prose. Bare `§N` does not render as a hotlink and silently rots when sections are
renumbered.

- **Same document:** `[§6](#6-honesty-the-proventestedassumed-discipline)`.
- **Another suite document:** deep-link to the section anchor, keeping the `§N` label terse:
  `[§6](./engineering/chaos_failover_doctrine.md#6-the-concentration-principle--where-the-obligation-lives)`.
  When the reference names the file, keep the filename in the visible text —
  `[documentation_standards.md §6](./documentation_standards.md#6-honesty-the-proventestedassumed-discipline)`.
- **Anchor slugs follow GitHub's rule:** lowercase the heading text, drop every character that is not a
  letter, digit, space, hyphen, or underscore (so `.`, `:`, `/`, `()`, backticks and em/en-dashes are deleted
  — *not* replaced, while `_` is **kept**, e.g. `DEVELOPMENT_PLAN` → `development_plan`), then turn each
  remaining space into a hyphen. A ` — ` between words therefore yields a double
  hyphen (`--`). Numbered headings keep their number: `## 6. Honesty …` → `#6-honesty-…`.
- **Three exceptions stay as prose:** a `§N` that points at a section of an *external* project not in this repo
  (e.g. sibling `config_doctrine.md`, `vault_doctrine.md`); a `§N` that appears *inside a heading* or a
  fenced code / Mermaid block (a link there would corrupt the heading's own slug or fail to render); and a
  **clause reference of the form `§M.N`** that names item *N* of a numbered *list* inside an already-anchored
  section (e.g. the eight gate-integrity clauses of
  [`development_plan_standards.md §M`](../DEVELOPMENT_PLAN/development_plan_standards.md#m-gate-integrity-a-gate-cannot-be-passed-by-a-stub)).
  A list clause is not itself a section and has no heading anchor; `§M.N` is prose shorthand, and the enclosing
  section (`§M`) is linked once at first mention. This exemption covers only list-clause shorthand, never a bare
  `§N` that names a *section*.

### The illegal-state catalog is cited by its index name, resolved to its themed slice

The illegal-state catalog is one logical SSoT — `illegal_state_catalog.md` is its **index** — whose numbered
entries (`§3.N`, `§4.N`) physically live in themed sub-files (`illegal_state_capacity.md`,
`illegal_state_security.md`, `illegal_state_multicluster.md`, …). A reference to a numbered entry therefore keeps
**`illegal_state_catalog.md §3.N` in the visible text** — the logical catalog is the name readers cite — while the
anchor **deep-links to the themed slice that owns the entry** — e.g. the visible text
`illegal_state_catalog.md §3.17` resolving to `illegal_state_capacity.md#317-…` (the themed slice that owns
`§3.17`). This is the **one sanctioned case where the visible filename differs from the link target**, because the index
holds the enumeration and the slice holds the heading. Bidirectionality (above) is still checked against the
**slice actually linked** — that slice's `Referenced by` lists the citing document, not the index.

### `§N` in a plan-suite task-note is shorthand, not a reader cross-reference

A `§N` inside a **`Docs to update` entry, a `Documentation Requirements` bullet, or a `(§N backlink)`
parenthetical** — where the owning document is named in that same entry — is build-task shorthand (like the
`§M.N` list-clause form above), recording *which section a later phase will backlink*; it need not be a separate
anchor link. The anchor-link mandate governs a section reference a **reader follows to navigate** — in body
prose, a heading's cross-reference, or a Related-Documents description — not this task metadata. When such a note
is promoted into reader-facing prose it takes the anchor-link form.

---

## 5. Duplication rules

- Never copy configuration examples, invariant catalogs, or proofs between docs — link to the owner.
- A worked example may *illustrate* a subsystem owned elsewhere, but must name the owning SSoT doc and not
  restate its normative content.

---

## 6. Honesty (the proven/tested/assumed discipline)

Amoebius doctrine inherits the chaos/failover doctrine's moral rule: **never report a tested, assumed, or
merely argued result as proven.** Verification claims state the layer they actually reach; the rest is
evidence, not proof, and the document must say so. See
[`engineering/chaos_failover_doctrine.md`](./engineering/chaos_failover_doctrine.md) (Phase 0).

---

## 7. Diagrams

Mermaid diagrams use `flowchart`/sequence forms with **no subgraphs and no dotted/animated edges** (these
render unreliably); prefer flat, solid, labeled edges. Code fences are always language-tagged.

---

## 8. Tone and voice

> **Purpose**: fix the register of doctrinal prose so tone is uniform and enforceable. §6 governs
> whether a claim is *true*; §8 governs how any claim is *phrased*. Both are mandatory and
> independent.

### Register
Doctrine prose is technical, declarative, and impersonal. The grammatical subject is amoebius, a
named subsystem, or a named artifact:

- **Amoebius forbids _X_.**
- **The DSL carries only names, never values.**
- **A valid `InForceSpec` cannot represent illegal cluster state.**

Lead with the rule or the problem. Do not build tension, address the reader, or narrate the
reasoning process; the argument is the surrounding sentences, not a rhetorical frame.

### Grammatical person

| Person | Status | Rule |
|--------|--------|------|
| Third-person declarative | **Default** | amoebius / the subsystem / the artifact is the subject. Every normative statement. |
| First-person plural (`we` / `our`) | **Forbidden in amoebius's own prose** | Recast with an impersonal subject (`Amoebius rejects Crossplane`; `The recorded operator decision is to drop Helm`). First-person survives **only inside a verbatim quotation** of the operator's recorded vision or decision — cited source material, not amoebius's narration (subject to §8's *Quoted vision text* rule below). |
| Second-person (`you` / `your`) | **Forbidden** | Recast impersonally (`a PVC can bind to no PV`, not `you can write a PVC that…`). Genuine operator instructions use the **imperative mood** (`Run amoebius up`), which is not second-person address. |

### Banned constructs
Each row is forbidden in doctrine prose. *Instead* is the required replacement.

| Banned | Instead |
|--------|---------|
| Rhetorical questions as prose (`Why does this bug survive the test suite?`) | State the answer as a declarative sentence. If a question organizes a section, put it in the **heading**, not the body. |
| War-story / time-of-day dramatization (`at 3 a.m.`, `a decade of bash`, `the nightmare is…`) | Name the failure mode in technical terms and state **when it is detected** (author time / type-check / runtime). |
| Marketing / stakes framing (`central bet`, `the whole point`, `gift`) | State the mechanism and the property it guarantees. |
| Slang / cutesy labels (`footgun`, `bouncer`, `cattle`, `is a smell`, `cardinal sin`, `wearing a different hat`, `indictment`, `hack`) | Use the precise technical term for the hazard or role. |
| Formulaic openers (`The intuition:`, `Lead with the intuition:`, `The one idea:`, `The payoff is…`) | Delete the label; open with the rule or the problem directly. |
| Emphatic filler (`the whole point` / `the whole reason` / `the whole identity`, `refuses that outright`, `bluntly`, `with a straight face`, decorative `exactly`) | Delete. A correctly stated rule needs no intensifier. |
| First-person sentimentality (`amoebius's gift to its own engineers is focus`) | Delete, or restate as a structural property of the system. |

### Metaphor and slogan
A metaphor, analogy, or slogan may appear **only** when both hold:

1. it is **immediately cashed out** — the precise technical statement follows in the same or the
   next sentence; and
2. the precise statement, not the metaphor, is the **normative rule**.

A slogan may never be the sole statement of a rule, the only content of a heading, or a
cross-reference target. Prefer no metaphor. Permitted form: state the rule precisely, then, if
useful, append the shorthand — *"(Shorthand: clusters are cattle; storage is not.)"*

### Relationship to §6 (Honesty)
§6 and §8 are orthogonal and both mandatory. §6 governs truth-claims (proven / tested / assumed);
§8 governs register. Where they meet — hedging language — §6 dictates *which* hedge word is
required; §8 forbids *dramatizing* the hedge. Neither section licenses violating the other.

### Quoted vision text
A verbatim quotation is kept **only** when it is a load-bearing provenance citation — it establishes
what the original vision or notes specified, in contrast to what amoebius decided. Keep it minimal,
mark it as a quote, and clean amoebius's own narration around it. A casual musing quote used
decoratively is **paraphrased** into a precise impersonal statement, with the quote marks dropped.

The exemption covers **only** a citation of external source material (the operator's recorded vision, notes,
or an upstream project's own words). It does **not** cover an **invented strawman position** the document
quotes in order to rebut it — a sentence like *"you cannot know the manifests are right until a cluster
admits them"* or *"we validated the DSL in-process"* is amoebius's own narration wearing quotation marks, not
a provenance citation, and inherits the first/second-person ban in full. Recast such a position impersonally
(*"the manifests cannot be known correct until a cluster admits them"*) rather than quoting it.

---

## 9. Motivating a design choice

> **Purpose**: a design choice is justified by motivating the problem it solves, not by asserting
> the choice. Any "Why this doctrine exists" or decision section states the problem before the rule.

A section that introduces or defends a design decision has four parts, in order:

1. **The problem the choice prevents** — in precise technical terms: the concrete illegal state,
   desync, or class of defect, and the layer at which it would otherwise surface (author time /
   type-check / decode / runtime). No dramatization (§8).
2. **Why the obvious alternative fails** — name the tempting or industry-default approach and the
   specific property it cannot provide.
3. **The chosen rule** — stated as a declarative invariant (§8).
4. **What it forecloses** — the capability or freedom the rule gives up, and (per §6) any residual
   tension stated honestly.

**Exemplars** — these sections already follow the shape and are the models to copy:

- [`engineering/manifest_generation_doctrine.md` §1](./engineering/manifest_generation_doctrine.md) —
  no-Helm: string-templated YAML is unverified (problem) → typed render (rule) → what a chart could
  still express (foreclosed).
- [`engineering/pulumi_iac_doctrine.md`](./engineering/pulumi_iac_doctrine.md) — keep-Pulumi /
  reject-Crossplane, with the checkpoint tension stated honestly.
- [`engineering/pulsar_client_doctrine.md` §1](./engineering/pulsar_client_doctrine.md) —
  no-WebSockets / CBOR-only.
- [`engineering/apple_metal_headless_builds.md` §6](./engineering/apple_metal_headless_builds.md) —
  no-Tart.

---

## Cross-references
- [Development Plan](../DEVELOPMENT_PLAN/README.md)
- [Engineering Doctrine Index](./engineering/README.md)
