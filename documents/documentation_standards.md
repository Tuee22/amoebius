# Amoebius Documentation Standards

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: README.md, CLAUDE.md, DEVELOPMENT_PLAN/README.md, documents/engineering/README.md
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
  letter, digit, space, or hyphen (so `.`, `:`, `/`, `()`, backticks and em/en-dashes are deleted — *not*
  replaced), then turn each remaining space into a hyphen. A ` — ` between words therefore yields a double
  hyphen (`--`). Numbered headings keep their number: `## 6. Honesty …` → `#6-honesty-…`.
- **Two exceptions stay as prose:** a `§N` that points at a section of an *external* project not in this repo
  (e.g. sibling `config_doctrine.md`, `vault_doctrine.md`), and a `§N` that appears *inside a heading* or a
  fenced code / Mermaid block (a link there would corrupt the heading's own slug or fail to render).

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

## Cross-references
- [Development Plan](../DEVELOPMENT_PLAN/README.md)
- [Engineering Doctrine Index](./engineering/README.md)
