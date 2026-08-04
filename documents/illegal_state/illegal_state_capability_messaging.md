# Illegal States — Capability & Messaging

> **Purpose**: The themed slice of the illegal-state catalog covering the states in which an application
> names a concrete product instead of a portable capability, and in which a Pulsar message carries a
> non-CBOR body, or a low-code browser escapes its server-mediated capability boundary — with the honest limit
> that a type-check proves the *spec composes*, not that the *running cluster enforces it*.
> **Read this if**: a capability binding or message-bus state has to be shown impossible to express.

This is the smallest slice, covering the states where an application could otherwise name a product directly
or put an untyped payload on the wire. The numbering belongs to
[illegal_state_catalog.md](./illegal_state_catalog.md); the capability abstraction is owned by
[service_capability_doctrine.md](../engineering/service_capability_doctrine.md) and the wire encoding by
[pulsar_client_doctrine.md](../engineering/pulsar_client_doctrine.md).

<details>
<summary>Link-graph metadata</summary>

**Status**: Authoritative source
**Supersedes**: N/A
**Referenced by**: DEVELOPMENT_PLAN/phase_04_dhall_gate1_schema.md, DEVELOPMENT_PLAN/phase_06_illegal_state_corpus.md, DEVELOPMENT_PLAN/phase_10_capability_bind.md, DEVELOPMENT_PLAN/phase_19_ui_effect_binding.md, DEVELOPMENT_PLAN/phase_21_ui_browser_interpreter.md, DEVELOPMENT_PLAN/phase_35_pulsar_client.md, DEVELOPMENT_PLAN/phase_56_ui_multi_tenant_live.md, documents/engineering/pulsar_client_doctrine.md, documents/illegal_state/README.md, documents/illegal_state/illegal_state_catalog.md, documents/illegal_state/illegal_state_techniques.md
**Generated sections**: none

</details>

---

## 1. Scope

This document is a **themed slice** of the illegal-state catalog: an app welding itself to a product name rather
than a capability abstraction ([§3.12](#312-an-app-that-names-a-product-instead-of-a-capability)), a producer
putting a non-CBOR body on a Pulsar topic ([§3.23](#323-a-non-cbor-pulsar-payload)), and a browser bypassing the
UI server to reach code or a provider outside the closed effect algebra
([§3.82](#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary)).

The **catalog index** (the enumerated list of every illegal state) and the **honesty limit** (that a
type-check proves the specification composes, never that the running cluster enforces it) are owned by
[`illegal_state_catalog.md`](./illegal_state_catalog.md) — referenced here, not restated. The **seven typing techniques**, the **coverage matrix**, the **three foreclosure layers**, and the orthogonal
**validation-locus axis** (`Gate-1-editor` / `Gate-2-decoder` / `provision-seal` /
`rendered-output-golden` / `live-effect`; `provision-seal` is post-bind Phase-11 provision returning a
`ProvisionError` before any `ProvisionedSpec` exists) are owned by [`illegal_state_techniques.md`](./illegal_state_techniques.md) — likewise referenced, not
restated. Each entry below names its owning doctrine, which remains the SSoT for the normative rule.

Everything below is **design intent** for the type discipline: a type-check proves the spec composes into
something internally coherent; it says nothing about whether the interpreter renders correct manifests,
whether the apiserver admits them, or whether the running cluster behaves — those live at the Protocol and
Runtime layers and their enforcement is deferred on purpose (see [`illegal_state_catalog.md` §2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it) and [§6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)).

---

## 2. The capability & messaging illegal states

### 3.12 An app that names a product instead of a capability

Application logic that writes `minio` or `vault` welds itself to one realization and loses portability across
clusters that deploy the capability differently. amoebius's app surface offers a **capability** union —
`ObjectStore`, `SecretStore`, `MessageBus`, `Sql`, `Identity`, `Observability`, `Registry`, `Edge` — with no
product arms, so "depend on `minio` directly" has no syntax: it fails Gate 1 (the Dhall typechecker) before
any binary runs. **Owner:** [`service_capability_doctrine.md`](../engineering/service_capability_doctrine.md) (the capability abstraction; one canonical provider, the type admitting alternates). **Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(capabilities as a closed union — a product name is uninhabitable).
**Layer:** type-foreclosed — a closed-union capability with no product arm; the illegal spec has no inhabitant.
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
different layer. **Owner:** [`pulsar_client_doctrine.md` §3.1](../engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor) (+ [`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) for the canonical-CBOR discipline).
**Technique:** [§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable) (a closed codec — only the CBOR constructor exists) + [§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (constructor-gating; there is no non-CBOR payload handle) — **no new technique**. **Layer:** type-foreclosed uninhabitable on the *produce* side; the
*consume* decode is a total fail-fast check — decode-foreclosed, exactly like the CRC32C frame check — never a
runtime-checked claim that a received body is valid.
**Validation-locus:** `Gate-2-decoder` on the *produce* side — the closed codec is a **Haskell** surface
(`Serialise` / `CborPayload` / `encodeCbor`), so the foreclosure is a compile-fail golden at the Gate-2
Haskell layer, **not** a `dhall type` failure: `dhall type` never sees the produce API **+** `Gate-2-decoder`
on the *consume* side (the total
`Either DecodeError a` returns `Left` on a malformed body, exactly like the CRC32C frame check). Explicitly
**not** a `live-effect` locus: there is no runtime-checked claim that a received body is valid — the decode
either succeeds or fails fast.

### 3.82 A browser effect or provider call escaping the server-mediated capability boundary

Arbitrary JavaScript, raw HTML, a fetch URL, a provider SDK, or a serialized provider handle turns an
otherwise typed SPA into a second authority surface. It can skip current server authorization, leak a
credential, address MinIO/Pulsar/SQL/Vault/inference directly, or reinterpret untrusted text as executable
markup. The low-code client surface is therefore closed: it has no `RawHtml`, `RawJavaScript`, `RawUrl`,
`CustomFetch`, provider-coordinate, raw-codec, or persistent-browser-storage arm. Plain text is escaped; trusted
components have bounded typed properties/events and no ambient network authority. A `ClientPlan` contains only
public values, safe instructions, and opaque `PortId`/handle values that cannot be converted into credentials or
provider addresses. Every effect crosses one same-origin transport to the amoebius UI server, whose sealed port
table supplies the bound provider capability and current request-context/auth witnesses. Provider handles are
server-only and intentionally have no client-plan encoder. A named external link carries only an id in Dhall,
exact-joins a linked fixed-HTTPS catalog, is covered by `ProgramDigest`, and projects as navigation-only; it
cannot be reused as fetch, media, form, or effect transport. **Owner:**
[`low_code_ui_runtime_doctrine.md` §13](../engineering/low_code_ui_runtime_doctrine.md#13-generic-purescript-client-and-amoebius-ui-server)
(the browser/server split), with the permanently absent escape arms owned by
[`low_code_ui_runtime_doctrine.md` §19](../engineering/low_code_ui_runtime_doctrine.md#19-extension-rule-and-permanently-absent-escape-hatches).
**Technique:**
[§4.2](./illegal_state_techniques.md#42-capability-and-phantom-tenant-tags--cross-tenant-refs-are-uninhabitable)
(only the server holds provider capabilities; handles keep their scope and side) +
[§4.3](./illegal_state_techniques.md#43-gadt-indexed-state-machines--only-legal-transitions-are-typed) (`PortId` can transition to an effect only through sealed server dispatch, never browser-side provider invocation).

**Layer:** `type-foreclosed` for raw-code/network/provider arms and for serializing a server-only capability;
`decode-foreclosed` for a checked component or plan that contains an incompatible side/scope; `runtime-checked`
residue — that the generated bundle, CSP, edge, NetworkPolicy, and browser actually expose no other path.
**Validation-locus:** `Gate-1-editor` (forbidden arms have no Dhall constructor) + `Gate-2-decoder` (only the
closed instruction/component/port sets can produce a checked program) + `provision-seal` (every effect must bind
to one server handler/capability and no provider coordinate may enter `ClientPlan`) +
`rendered-output-golden` (the bundle contract, CSP, routes, and NetworkPolicy expose only the same-origin UI
server path) + `live-effect` residue (browser traffic and provider authentication confirm the boundary).

**Independent oracle and mutants.** A built-artifact scanner independent of plan generation rejects executable
inline content, forbidden browser APIs/imports, provider hostnames, provider protocols, secret material, and
client encodings of server handles. A browser network harness records every request while exercising every port
and requires the declared immutable-asset origins plus the same-origin UI-server transport only; a separate
user-initiated named-link case may navigate only to its exact catalog destination with fixed referrer/opener
policy and no appended data. Mutants add
each absent raw arm, serialize a provider capability, inject a provider URL or credential into hydration data,
reuse a catalog link as fetch, add direct network access to a trusted component, and place untrusted text in an
HTML sink; compile/check, artifact scan, CSP, or the network oracle must turn red before the provider accepts an
effect.

---

## Related Documents
- [`illegal_state_catalog.md`](./illegal_state_catalog.md) — the catalog index, the honesty limit ([§2](./illegal_state_catalog.md#2-the-load-bearing-limit-a-type-check-proves-the-spec-composes-not-that-the-cluster-enforces-it)),
  and the three-layer foreclosure with the honesty it forces ([§6](./illegal_state_techniques.md#6-three-layers-of-foreclosure-and-the-honesty-they-force)); this doc is one themed slice of it.
- [`illegal_state_techniques.md`](./illegal_state_techniques.md) — the seven typing techniques, the coverage
  matrix, the foreclosure layers, and the validation-locus axis referenced by every entry above.
- [`dsl_doctrine.md`](../engineering/dsl_doctrine.md) — the DSL surface and the contract ("a valid `InForceSpec` cannot represent illegal state") that both entries instantiate.
- [`service_capability_doctrine.md`](../engineering/service_capability_doctrine.md) — owner of the capability abstraction
  ([§3.12](#312-an-app-that-names-a-product-instead-of-a-capability)): the closed capability union, one
  canonical provider, the type admitting alternates.
- [`pulsar_client_doctrine.md` §3.1](../engineering/pulsar_client_doctrine.md#31-payloads-are-exclusively-cbor) — owner of
  the CBOR-only payload rule ([§3.23](#323-a-non-cbor-pulsar-payload)).
- [`content_addressing_doctrine.md`](../engineering/content_addressing_doctrine.md) — owner of the canonical-CBOR
  discipline the Pulsar payload rule reuses ([§3.23](#323-a-non-cbor-pulsar-payload)).
- [`low_code_ui_runtime_doctrine.md`](../engineering/low_code_ui_runtime_doctrine.md) — owner of the closed
  client instruction/component algebra and server-mediated provider-capability boundary
  ([§3.82](#382-a-browser-effect-or-provider-call-escaping-the-server-mediated-capability-boundary)).
