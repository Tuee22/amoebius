# Illegal States — Capability & Messaging

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_24_pulsar_client.md, documents/engineering/pulsar_client_doctrine.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

> **Purpose**: The themed slice of the illegal-state catalog covering the states in which an application
> names a concrete product instead of a portable capability, and in which a Pulsar message carries a
> non-CBOR body — with the honest limit that a type-check proves the *spec composes*, not that the *running
> cluster enforces it*.

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog: the two entries in which an app welds
itself to a product name rather than a capability abstraction ([§3.12](#312-an-app-that-names-a-product-instead-of-a-capability)),
and in which a producer puts a non-CBOR body on a Pulsar topic ([§3.23](#323-a-non-cbor-pulsar-payload)).

The **catalog index** (the enumerated list of every illegal state) and the **honesty limit** (that a
type-check proves the specification composes, never that the running cluster enforces it) are owned by
[`illegal_state_catalog.md`](./illegal_state_catalog.md) — referenced here, not restated. The **seven typing
techniques**, the **coverage matrix**, the **three foreclosure layers**, and the orthogonal
**validation-locus axis** (`Gate-1-editor` / `Gate-2-decoder` / `provision-seal` /
`rendered-output-golden` / `live-effect`; `provision-seal` is post-bind Phase-8 provision returning a
`ProvisionError` before any `ProvisionedSpec` exists) are owned by [`illegal_state_techniques.md`](./illegal_state_techniques.md) — likewise referenced, not
restated. Each entry below names its owning doctrine, which remains the SSoT for the normative rule.

Everything below is **design intent** for the type discipline: a type-check proves the spec composes into
something internally coherent; it says nothing about whether the interpreter renders correct manifests,
whether the apiserver admits them, or whether the running cluster behaves — those live at the Protocol and
Runtime layers and their enforcement is deferred on purpose (see [`illegal_state_catalog.md` §2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)
and [§6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)).

---

## 2. The capability & messaging illegal states

### 3.12 An app that names a product instead of a capability

Application logic that writes `minio` or `vault` welds itself to one realization and loses portability across
clusters that deploy the capability differently. amoebius's app surface offers a **capability** union —
`ObjectStore`, `SecretStore`, `MessageBus`, `Sql`, `Identity`, `Observability`, `Registry`, `Edge` — with no
product arms, so "depend on `minio` directly" has no syntax: it fails Gate 1 (the Dhall typechecker) before
any binary runs. **Owner:** [`service_capability_doctrine.md`](../engineering/service_capability_doctrine.md) (the
capability abstraction; one canonical provider, the type admitting alternates). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(capabilities as a closed union — a product name is uninhabitable).
**Validation-locus:** `Gate-1-editor` — a closed-union capability with no product arms; "depend on `minio`
directly" has no syntax and fails `dhall type` at authoring time, before any binary runs. No runtime
residue: the illegal shape is unrepresentable, not merely rejected downstream.

### 3.23 A non-CBOR Pulsar payload

Raw messaging lets a producer put any bytes on a topic — JSON, base64-in-JSON (infernix's retired path),
protobuf, an untyped blob — so two services silently disagree on the body format and a consumer mis-reads or
drops. amoebius makes the Pulsar message **body** exclusively CBOR: the produce surface takes only a
`Serialise` value (equivalently a `CborPayload` whose sole constructor is `encodeCbor`), with **no**
`produceRaw` / JSON / protobuf / base64 constructor, so a non-CBOR payload has no inhabitant; consume is a
total `Either DecodeError a`. Canonical CBOR is reused from the content store where a payload is
content-addressed, and the protocol framing (`BaseCommand` / metadata) stays protobuf — Pulsar's wire, a
different layer. **Owner:** [`pulsar_client_doctrine.md` §3.1](../engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor) (+
[`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) for the canonical-CBOR discipline).
**Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (a closed codec — only the CBOR constructor exists) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (constructor-gating; there is
no non-CBOR payload handle) — **no new technique**. **Layer:** type-foreclosed uninhabitable on the *produce* side; the
*consume* decode is a total fail-fast check — decode-foreclosed, exactly like the CRC32C frame check — never a
runtime-checked claim that a received body is valid.
**Validation-locus:** `Gate-1-editor` on the *produce* side (a closed codec — the non-CBOR payload has no
constructor, so it fails the authoring-time gate) **+** `Gate-2-decoder` on the *consume* side (the total
`Either DecodeError a` returns `Left` on a malformed body, exactly like the CRC32C frame check). Explicitly
**not** a `live-effect` locus: there is no runtime-checked claim that a received body is valid — the decode
either succeeds or fails fast.

---

## Cross-references

- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the catalog index, the honesty limit ([§2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)),
  and the three-layer foreclosure with the honesty it forces ([§6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)); this doc is one themed slice of it.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the seven typing techniques, the coverage
  matrix, the foreclosure layers, and the validation-locus axis referenced by every entry above.
- [`dsl_doctrine.md`](../engineering/dsl_doctrine.md) — the DSL surface and the contract ("a valid `InForceSpec` cannot
  represent illegal state") that both entries instantiate.
- [`service_capability_doctrine.md`](../engineering/service_capability_doctrine.md) — owner of the capability abstraction
  ([§3.12](#312-an-app-that-names-a-product-instead-of-a-capability)): the closed capability union, one
  canonical provider, the type admitting alternates.
- [`pulsar_client_doctrine.md` §3.1](../engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor) — owner of
  the CBOR-only payload rule ([§3.23](#323-a-non-cbor-pulsar-payload)).
- [`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) — owner of the canonical-CBOR
  discipline the Pulsar payload rule reuses ([§3.23](#323-a-non-cbor-pulsar-payload)).
