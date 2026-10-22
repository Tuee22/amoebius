{-# LANGUAGE OverloadedStrings #-}

-- Independent literals for extension binding, runtime projection and attestation.
-- These declarations precede the phase's product implementation. Nothing here
-- imports the product or derives an expectation from its output.
module DslExtensionContract
  ( extensionSubjects, extensionCases, linkedIds, extensionGraph, extensionDependencyOrder, coreCapabilityNames, inferenceGrid
  , inferenceObjects, inferenceResources, scopeFields, scopeRefusals
  , mergeControls, specControls, sourceClosureControls, attestationControls, configurationControls, declarationWorkflows
  , contributionModules, monitoringCounts
  , loweringControls
  , mixedInferenceNeeds
  , siblingModule, siblingBinding, siblingWitnessFields
  , closedApiBoundaries
  , specRuntimeControls, mergeRuntimeControls, sourceTreeControls
  , extensionExampleNames
  ) where

import Data.Text (Text)

extensionSubjects :: [Text]
extensionSubjects =
  [ "Amoebius.Extension.Spec", "Amoebius.Extension.Linked"
  , "Amoebius.Extension.AstCheck", "Amoebius.Scope.Attested"
  , "Amoebius.Extension.Calculi", "Amoebius.Dsl.Lower"
  ]

extensionCases :: [(Text, Text, Text)]
extensionCases =
  [ ("infernix-linked", "accepted", "provider objects and application binding")
  , ("cuda-on-cuda-sibling", "accepted", "cuda lane and DaemonSet")
  , ("attested-scope", "accepted", "one attested scope on every object")
  , ("UnboundCapability", "lower", "same app and need in a recompiled unlinked sibling")
  , ("LaneUnavailable", "lower", "cuda request with only cpu lanes")
  , ("AstEvasion", "extension-astcheck", "located native AST or pragma node")
  , ("UnattestedScope", "render", "unlabeled object is refused")
  ]

-- The two workload contributions close over two horizontal capability peers.
-- Every entry is real; built-in capabilities are a separate provider inventory.
linkedIds :: [Text]
linkedIds = ["jit-build", "coordination", "infernix", "jitml"]

contributionModules :: [Text]
contributionModules =
  [ "Amoebius.Extension.Contributed.Coordination", "Amoebius.Extension.Contributed.Infernix"
  , "Amoebius.Extension.Contributed.JitBuild", "Amoebius.Extension.Contributed.JitML" ]

monitoringCounts :: [(Text, Integer)]
monitoringCounts = [("jit-build", 1), ("coordination", 1), ("infernix", 1), ("jitml", 2)]

extensionGraph :: [(Text, [Text], [Text])]
extensionGraph =
  [ ("jit-build", ["JitBuild"], ["ObjectStore", "Registry"])
  , ("coordination", ["Coordination"], ["MessageBus"])
  , ("infernix", ["InferenceEngine"], ["JitBuild"])
  , ("jitml", [], ["JitBuild", "Coordination", "InferenceEngine"])
  ]

-- Deterministic depth-first provider order, starting from sorted identities.
extensionDependencyOrder :: [Text]
extensionDependencyOrder = ["coordination", "jit-build", "infernix", "jitml"]

coreCapabilityNames :: [Text]
coreCapabilityNames =
  [ "ObjectStore", "SecretStore", "MessageBus", "Sql", "Identity"
  , "Observability", "Registry", "Edge"
  ]

-- Architecture is supplied example data, never a condition on the validation host.
inferenceGrid :: [(Text, Text, Text, Maybe Integer)]
inferenceGrid =
  [ ("cpu-amd64", "Deployment", "linux-cpu/amd64", Nothing)
  , ("cpu-arm64", "Deployment", "linux-cpu/arm64", Nothing)
  , ("cuda-amd64", "DaemonSet", "linux-cuda/amd64", Just 1)
  , ("cuda-arm64", "DaemonSet", "linux-cuda/arm64", Just 1)
  ]

inferenceResources :: (Integer, Integer, Integer, Integer)
inferenceResources = (4, 8, 16, 1)

-- Identity suffix, kind, namespace, activation and reconcile mode. Runtime
-- changes the workload kind and accelerator claim; it never creates a PVC.
inferenceObjects :: Bool -> [(Text, Text, Text, Text, Text)]
inferenceObjects cuda =
  [ ("config", "ConfigMap", "amoebius-inference", "Immediate", "ServerSideApply")
  , ("service", "Service", "amoebius-inference", "AfterBootstrapAddonCutover", "ServerSideApply")
  , ("member-0", if cuda then "DaemonSet" else "Deployment", "amoebius-inference", "AfterBootstrapAddonCutover", "ServerSideApply")
  ]

-- The scope binds the actual issuer, application and need. The label is
-- s- plus sixty lower-case hex digits of a SHA-256 over UTF-8 byte-length
-- framing of ["scope/v1", issuer, app, need]; full fields remain observable.
scopeFields :: [Text]
scopeFields = ["issuer", "application", "need", "scope-label"]

scopeRefusals :: [(Text, Text)]
scopeRefusals =
  [ ("scope-constructor", "private constructor")
  , ("scope-from-text", "attestation required")
  , ("scope-retag", "nominal scope index")
  , ("flow-retag", "nominal scope index")
  , ("workflow-obligation-coerce", "nominal before and after indices")
  , ("declaration-retag", "nominal scope index")
  , ("declaration-name-update", "no exported declaration record labels")
  , ("typed-root-record-update", "no exported refined-record labels")
  , ("gate-plan-retag", "nominal scope index")
  , ("conformance-verdict-retag", "nominal scope index")
  , ("guarded-link-set-retag", "nominal scope index")
  , ("modeled-link-set-retag", "nominal scope index")
  , ("wrong-tenant-reentry", "ReentryTenantMismatch")
  , ("claimed-identity", "attested identity required")
  , ("ui-context-from-text", "attested identity required")
  , ("unlabeled-object", "UnattestedScope")
  ]

mergeControls :: [(Text, Text)]
mergeControls =
  [ ("legal-peer", "accepted")
  , ("jit-build-output-consumed", "infernix and jitML consume the same JitBuild producer")
  , ("missing-requirement", "UnboundCapability")
  , ("duplicate-id", "DuplicateExtensionId")
  , ("duplicate-provider", "ShadowingExtension")
  , ("cyclic-requirements", "CyclicExtension")
  ]

specControls :: [(Text, Text)]
specControls =
  [ ("unique-provides-requires", "accepted")
  , ("duplicate-provides", "DuplicateProvidedCapability")
  , ("duplicate-requires", "DuplicateRequiredCapability")
  , ("missing-monitoring", "NonEmpty monitoring required")
  , ("fake-source-seal", "concrete linked spec requires checker-issued seal")
  , ("spec-constructor", "private constructor")
  , ("spec-record-update", "no exported record labels")
  , ("spec-generic", "no Generic instance")
  , ("single-registration-type", "ExtensionDescriptor and ExtensionName retired; ExtensionSpec is canonical")
  ]

sourceClosureControls :: [(Text, Text)]
sourceClosureControls =
  [ ("complete-peer-closure", "accepted")
  , ("pure-helper-closure", "accepted")
  , ("empty-source-root", "MissingContributionSource")
  , ("module-path-mismatch", "ContributionModuleMismatch")
  , ("duplicate-module", "duplicate-module")
  , ("source-symlink", "ContributionSymlink")
  , ("alternate-source-suffix", "UnexpectedContributionFile")
  , ("unchecked-helper-import", "UnsanctionedImport")
  , ("unrelated-factory-seal", "UnadmittedContributionFactory")
  , ("precompile-template-effect", "TemplateHaskell; effect marker absent")
  , ("precompile-plugin-option", "UnsafeOperation; plugin marker absent")
  , ("changed-helper-dependency", "compiler invalidates checked closure")
  , ("incremental-existing-unsafe-source", "native compiler transport refuses before contributed compilation")
  , ("incremental-new-unsafe-source", "native compiler transport refuses before contributed compilation")
  , ("incremental-new-pure-helper", "native compiler transport accepts complete closure")
  ]

attestationControls :: [(Text, Text)]
attestationControls =
  [ ("verified-principal", "accepted")
  , ("actual-core-binding", "core/ObjectStore")
  , ("actual-extension-binding", "extension/infernix")
  , ("changed-signed-tenant", "attestation-refused")
  , ("changed-signed-subject", "attestation-refused")
  , ("persisted-same-scope", "accepted")
  , ("persisted-different-tenant", "ReentryTenantMismatch")
  , ("persisted-different-need", "ReentryScopeMismatch")
  , ("scope-label-frame", "scope/v1; UTF-8 bytes; unsigned 64-bit big-endian lengths")
  , ("core-extension-same-name", "distinct issuer origins and labels")
  , ("unicode-scope-frame", "byte length differs from character length")
  , ("direct-text-factory", "no withRequestScope export")
  , ("text-only-binding-proof", "actual refined application need required")
  , ("binding-subject-constructor", "private product authority module")
  , ("identity-coerce", "nominal trust index")
  , ("scoped-key-coerce", "nominal scope index")
  , ("bottom-scope-eliminator", "exception before authority-bearing value escapes")
  ]

configurationControls :: [(Text, Text)]
configurationControls =
  [ ("positive-cache-bounds", "accepted")
  , ("zero-cache-budget", "InvalidCacheBounds")
  , ("zero-first-miss-concurrency", "InvalidCacheBounds")
  , ("temporary-above-budget", "InvalidCacheBounds")
  , ("cache-bounds-overflow", "InvalidCacheBounds")
  , ("coordination-reference", "accepted")
  , ("reference-url", "InvalidExtensionReference")
  , ("schema-mismatch", "ExtensionConfigurationMismatch")
  , ("duplicate-request", "DuplicateExtensionRequest")
  , ("missing-peer-configuration", "ExtensionConfigurationMissing")
  , ("typed-inference-binding", "runtime and family belong to deployment")
  ]

declarationWorkflows :: [(Text, [Text])]
declarationWorkflows =
  [ ("jit-build", ["build", "observe"])
  , ("coordination", ["deploy", "observe"])
  , ("infernix", ["build", "deploy", "observe"])
  , ("jitml", ["build", "deploy", "observe"])
  ]

-- Authored before binding, configuration and lane integration. These exercise
-- supplied model values; none is permission to inspect a development host.
loweringControls :: [(Text, Text)]
loweringControls =
  [ ("cpu-linked", "accepted")
  , ("cuda-linked", "accepted")
  , ("cuda-on-cpu", "LaneUnavailable")
  , ("missing-explicit-inference-binding", "InferenceBindingRequired")
  , ("vllm-on-cpu", "EngineFamilyUnavailable")
  , ("missing-peer-configuration", "ExtensionConfigurationMissing")
  , ("wrong-peer-schema", "ExtensionConfigurationMismatch")
  , ("unknown-extension-request", "UnboundCapability")
  , ("coordination-reference-unbound", "ExtensionDependencyBindingRequired")
  , ("training-reference-unbound", "ExtensionDependencyBindingRequired")
  ]

-- Two real needs use the same admitted provider prototype. Each instantiation
-- owns a distinct attested scope and its four dependency-plan objects.
mixedInferenceNeeds :: [(Text, Text)]
mixedInferenceNeeds =
  [("engine-0b5e17e11a0c0ffee0de1e9a7e5ba5ed", "Deployment"),
   ("engine-cuda-0b5e17e11a0c0ffee0de1e9a7e5ba5ed", "DaemonSet")]

-- The counterfactual is another source-bound binary, not a runtime switch.
siblingModule, siblingBinding :: Text
siblingModule = "Amoebius.Extension.Linked"
siblingBinding = "linkedExtensions"

siblingWitnessFields :: [Text]
siblingWitnessFields = ["nonce", "module", "binding", "operator", "source-before", "source-after",
  "source-diff", "binary-before", "binary-after", "input-before", "input-after"]

-- Client names and the independently expected rejected authority. A refusal
-- must occur at the submitted expression, after its legal public API control.
closedApiBoundaries :: [(Text, [Text])]
closedApiBoundaries =
  [("scope-constructor", ["RequestScope"]), ("scope-text-factory", ["withRequestScope"]),
   ("binding-subject-constructor", ["BindingSubject"]), ("source-seal-constructor", ["CheckedExtensionSource"]),
   ("spec-constructor", ["ExtensionSpec"]), ("spec-record-update", ["extId"]),
   ("spec-generic", ["Generic"]), ("claimed-identity", ["Claimed", "Attested"]),
   ("workflow-before-retag", ["alpha", "beta", "coerce"]),
   ("workflow-after-retag", ["alpha", "beta", "coerce"]),
   ("missing-monitoring", ["NonEmpty"]), ("empty-sli-set", ["NonEmpty"]),
   ("public-monitor-access", ["Public"]), ("unrelated-factory-seal", ["UnadmittedContributionFactory"])]

extensionExampleNames :: [Text]
extensionExampleNames = ["infernix-linked", "attested-scope", "cuda-on-cuda-sibling", "cuda-arm64-linked",
  "mixed-inference-runtimes", "cuda-on-cpu"]

specRuntimeControls, mergeRuntimeControls, sourceTreeControls :: [(Text, Text)]
specRuntimeControls = [("unique-provides-requires", "accepted"),
  ("duplicate-provides", "DuplicateProvidedCapability"), ("duplicate-requires", "DuplicateRequiredCapability")]
mergeRuntimeControls = [("legal-peer", "accepted"), ("missing-requirement", "UnboundCapability"),
  ("duplicate-id", "DuplicateExtensionId"), ("duplicate-provider", "ShadowingExtension"),
  ("cyclic-requirements", "CyclicExtension")]
sourceTreeControls = [("legal-tree", "accepted:4"), ("pure-helper-closure", "accepted:5"),
  ("empty-source-root", "MissingContributionSource"), ("module-path-mismatch", "ContributionModuleMismatch"),
  ("duplicate-module", "ContributionRejected:UnsafeOperation:duplicate-module"),
  ("source-symlink", "ContributionSymlink"), ("alternate-source-suffix", "UnexpectedContributionFile"),
  ("unchecked-helper-import", "ContributionRejected:UnsanctionedImport:import-declaration")]
