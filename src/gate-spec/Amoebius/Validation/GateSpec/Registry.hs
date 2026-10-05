{-# LANGUAGE OverloadedStrings #-}
-- | The sole capability-keyed gate registry; absent specifications refuse.
module Amoebius.Validation.GateSpec.Registry
  ( registeredCapabilities
  , specInputFor
  ) where
import Amoebius.Validation.GateSpec
import Amoebius.Validation.GateSpec.Seed (phaseZeroSpecInput)
import Amoebius.Validation.GateSpec.Toolchain (toolchainSpecInput)
import Data.Text (Text)
registeredCapabilities :: [Text]
registeredCapabilities = map fst registry
specInputFor :: Text -> Maybe GateSpecInput
specInputFor capability = lookup capability registry
registry :: [(Text, GateSpecInput)]
registry = [("documentation_suite", phaseZeroSpecInput), ("toolchain_spike", toolchainSpecInput), ("repository_layout_conformance", layoutSpecInput), ("typed_spine", spineSpecInput), ("witness_manifests_capacity_storage", capacitySpecInput)]

layoutSubjects :: [ProductionModule]
layoutSubjects = map ProductionModule ["Amoebius.Layout.Classify", "Amoebius.Layout.PackageMap", "Amoebius.Layout.PbGrammar", "Amoebius.Layout.Report", "Amoebius.Layout.SourceGraph"]
layoutSpecInput :: GateSpecInput
layoutSpecInput = GateSpecInput
  { inputCapability = "repository_layout_conformance"
  , inputClaim = "The shipped layout-report classifies every present source path, enforces the six admitted metadata paths and bounded bootstrap bytes, and resolves the compiler-backed whole-source graph; the independent oracle judges planted foreign inputs and typed legacy ownership. Archive custody remains verifier-owned."
  , inputSubjects = layoutSubjects
  , inputSuite = CabalTarget "layout-suite"
  , inputOracle = OracleExecutable "oracle-layout"
  , inputCases =
      [PositiveControl "case:positive.bootstrap" "pb/__main__.py" "admitted", PositiveControl "case:six-metadata-files" "six metadata paths" "six classes", PositiveControl "case:positive.archive" "accepted bundle path" "historical-evidence", PositiveControl "case:graph-qualified" "whole source inventory" "resolved"]
      <> [PairedNegative "case:negative.python" "src/example.py" "NonHaskellSource" "classify", PairedNegative "case:negative.dhall" "dhall/example.dhall" "ForeignSourceOwed" "classify", PairedNegative "case:negative.pulumi" "pulumi/Pulumi.yaml" "TrackedPulumiProgram" "classify", PairedNegative "case:negative.test-table" "test/layout/expected.tsv" "NonHaskellTestInput" "classify", PairedNegative "case:negative.ignore-root" "ui/output" "RetiredIgnoreRoot" "classify", PairedNegative "case:negative.ordinal" "src/Amoebius/Phase42Runtime.hs" "OrdinalRuntimeIdentity" "classify", PairedNegative "case:graph.ambiguous-import" "ambiguous import fixture" "AmbiguousSourceImport" "graph", PairedNegative "case:graph.module-path-mismatch" "misdeclared module fixture" "ModuleDeclarationPathMismatch" "graph"]
  , inputMutants = defaultMutantPolicy layoutSubjects
  , inputBinaryFact = Just BinaryFact {factCommand = ["layout-report", "--root", "{tree}", "--paths-file", "{input}", "--output", "{run}/layout-report.tsv"], factInput = "paths.txt", factPerturbation = PlantForeignPaths [("src/Challenge{nonce}.py", "NonHaskellSource"), ("dhall/Challenge{nonce}.dhall", "ForeignSourceOwed"), ("pulumi/Pulumi{nonce}.yaml", "TrackedPulumiProgram")], factOutputs = ["{run}/layout-report.tsv"]}
  , inputSpineFact = Nothing
  , inputSubstrate = HardwareFree
  , inputSeed = Nothing
  }

spineSubjects :: [ProductionModule]
spineSubjects = map ProductionModule ["Amoebius.Vocabulary", "Amoebius.Dsl.Spec", "Amoebius.Dsl.Import", "Amoebius.Dsl.Decode", "Amoebius.Dsl.Lower", "Amoebius.Kernel.Step", "Amoebius.Kernel.Interpret", "Amoebius.Dsl.Pipeline"]
spineSpecInput :: GateSpecInput
spineSpecInput = GateSpecInput
  { inputCapability = "typed_spine"
  , inputClaim = "From one operator-authored Dhall specification the shipped render-examples, compile, and apply commands freeze, decode, lower, plan, provision, render, chain, dry-run, and apply it through a separate fake kubectl process image. The runner rewrites the rendered example after the run starts, planting a nonce in the authored names and changing the replica count, and recovers the nonce from every stage artefact. The independent oracle judges every stage artefact of the corpus examples and of that run from literals, the fake's per-step stdin bytes concatenate to the compile output, and every refusal is observed at its exact tag and stage. Witness-driven rendering, capacity over application workloads beyond fit, substrates other than kind on one host, extensions, children, and the UI language are excluded."
  , inputSubjects = spineSubjects
  , inputSuite = CabalTarget "spine-suite"
  , inputOracle = OracleExecutable "oracle-dsl"
  , inputCases = [PositiveControl ("case:" <> name) input expected | (name, input, expected) <- spinePositives] <> [PairedNegative ("case:" <> name) input tag stage | (name, input, tag, stage) <- spineNegatives]
  , inputMutants = (defaultMutantPolicy spineSubjects) {stageArtefacts = spineArtefacts}
  , inputBinaryFact = Just BinaryFact {factCommand = ["compile", "--input", "{input}", "--out", "{run}/compiled"], factInput = "root.dhall", factPerturbation = Staged [["render-examples", "--example", "kind-single-objectstore", "--output", "{input}"]] [["apply", "--executor", "fake", "--input", "{input}", "--out", "{run}/applied"]] [SentinelToNonce "0b5e17e11a0c0ffee0de1e9a7e5ba5ed", ReplicaCount 1 3], factOutputs = ["{run}/compiled/" <> name | name <- ["frozen.dhall", "decoded.dump", "lowered.dump", "plan.dump", "provisioned.dump", "manifest.json", "chain.dump", "dry-run.dump"]] <> ["{run}/applied/fake/stdin.combined"]}
  , inputSpineFact = Just SpineFact {spineRendered = "compiled/manifest.json", spineStages = ["freeze", "decode", "lower", "plan", "provision", "render", "chain", "dry-run", "fake-apply"], spineAppliedDigestFile = "applied/fake/applied.sha256"}
  , inputSubstrate = HardwareFree
  , inputSeed = Nothing
  }
spineArtefacts :: [(Text, Text)]
spineArtefacts = [("Amoebius.Vocabulary", "vocab."), ("Amoebius.Dsl.Spec", "spec."), ("Amoebius.Dsl.Import", "freeze."), ("Amoebius.Dsl.Decode", "decode."), ("Amoebius.Dsl.Lower", "lower."), ("Amoebius.Kernel.Step", "chain."), ("Amoebius.Kernel.Interpret", "dry-run."), ("Amoebius.Kernel.Interpret", "fake-apply.")] <> [("Amoebius.Dsl.Pipeline", prefix) | prefix <- ["plan.", "provision.", "render.", "pipeline.", "endpoint."]]
spinePositives :: [(Text, Text, Text)]
spinePositives = [("kind-single-objectstore", "kind-single-objectstore.dhall", "objects equal the oracle rows"), ("shape-swap-sibling", "shape-swap-sibling.dhall", "provider objects change, application bytes do not"), ("replicas-3-sibling", "replicas-3-sibling.dhall", "one differing path"), ("local-import-twin", "local-import-twin.dhall", "freezes to the baseline"), ("lanes-of", "host grid", "total lane table"), ("round-trip", "encode then decode", "equal values"), ("step-sequence", "chain order", "frame then identity"), ("dry-run-zero", "dry run", "no step executed"), ("fake-relay", "fake kubectl", "stdin equals payload"), ("endpoint-digest", "control-plane endpoint", "manifest digest"), ("fields-consumed", "authored leaves", "each reaches a byte"), ("corpus-discovery", "rendered files", "equals inventory"), ("shipped-binary", "perturbed run", "nonce in every artefact")]
spineNegatives :: [(Text, Text, Text, Text)]
spineNegatives = [("AppleNeedsArm64", "darwin amd64", "NotNaturalArchitecture", "vocabulary"), ("WindowsNeedsAmd64", "windows arm64", "NotNaturalArchitecture", "vocabulary"), ("ForbiddenImportEnv", "forbidden-env.dhall", "ForbiddenImport", "freeze"), ("ForbiddenImportRemote", "forbidden-remote.dhall", "ForbiddenImport", "freeze"), ("ForbiddenImportAlternative", "forbidden-alternative.dhall", "ForbiddenImport", "freeze"), ("ForbiddenImportTransitive", "forbidden-transitive.dhall", "ForbiddenImport", "freeze"), ("AbsoluteImport", "forbidden-absolute.dhall", "AbsolutePath", "freeze"), ("HomeImport", "forbidden-home.dhall", "HomePath", "freeze"), ("NonCodeImport", "non-code-import.dhall", "NonCodeMode", "freeze"), ("ParseFailure", "parse-failure.dhall", "ParseFailure", "freeze"), ("IllTypedAlternative", "ill-typed-alternative.dhall", "IllTyped", "freeze"), ("RequestsAboveLimits", "requests-above-limits.dhall", "RequestsAboveLimits", "decode"), ("EmptyNeeds", "empty-needs.dhall", "EmptyNeeds", "decode"), ("ZeroReplicas", "zero-replicas.dhall", "ZeroReplicas", "decode"), ("HeadroomAllZero", "headroom-all-zero.dhall", "HeadroomAllZero", "decode"), ("ProductNamedInApp", "product-named-in-app.dhall", "DhallFailure", "decode"), ("ShapeInApp", "shape-in-app.dhall", "DhallFailure", "decode"), ("UnboundNeed", "unbound-need.dhall", "UnboundNeed", "lower"), ("DanglingBinding", "dangling-binding.dhall", "DanglingBinding", "lower"), ("UnknownDeployment", "unknown-deployment.dhall", "UnknownDeployment", "lower"), ("HostShort", "host-short.dhall", "InfrastructureDemandExceeded", "plan"), ("ReplicasOverCapacity", "replicas-over-capacity.dhall", "PostBindExpansionOvercommit", "provision"), ("DetectedAppleAmd64", "Detected Apple Amd64", "ConstructorNotExported", "compile"), ("BoundDeploymentOutsideLower", "BoundDeployment construction", "ConstructorNotExported", "compile"), ("StepCarriesIO", "Step with IO", "StepHasNoFunctionSlot", "compile"), ("TwoServerQuorum", "two-server quorum", "EvenQuorumUnspellable", "compile")]

capacitySubjects :: [ProductionModule]
capacitySubjects = map ProductionModule ["Amoebius.Capacity.Vector", "Amoebius.Capacity.Fits", "Amoebius.Placement.Witness", "Amoebius.Storage.Witness", "Amoebius.Manifest.StatefulSet", "Amoebius.Manifest.Render"]
capacitySpecInput :: GateSpecInput
capacitySpecInput = GateSpecInput
  { inputCapability = "witness_manifests_capacity_storage"
  , inputClaim = "The two-node corpus example reaches fake-applied bytes whose node names, replica counts, resource requests, and claim bytes equal the placement, envelope, and storage witnesses, and every capacity is a unit-tagged quantity. The runner rewrites the rendered example after the run starts, planting a nonce and raising one host capacity by one unit so the application's placement flips, and the oracle judges every stage artefact from literals. The total fit over every pair of three-valued vectors, the volume identities, and the render of a claim without a StatefulSet are judged from the suite's bytes, and the over-capacity twins are refused at provision with the exact-fit twin accepted. Substrates, taints, extensions, children, and the UI language are excluded."
  , inputSubjects = capacitySubjects
  , inputSuite = CabalTarget "spine-suite"
  , inputOracle = OracleExecutable "oracle-dsl"
  , inputCases = [PositiveControl ("case:" <> name) input expected | (name, input, expected) <- spinePositives <> capacityPositives] <> [PairedNegative ("case:" <> name) input tag stage | (name, input, tag, stage) <- spineNegatives <> capacityNegatives]
  , inputMutants = (defaultMutantPolicy capacitySubjects) {stageArtefacts = capacityArtefacts}
  , inputBinaryFact = Just BinaryFact {factCommand = ["compile", "--input", "{input}", "--out", "{run}/compiled"], factInput = "root.dhall", factPerturbation = Staged [["render-examples", "--example", "kind-two-nodes", "--output", "{input}"]] [["apply", "--executor", "fake", "--input", "{input}", "--out", "{run}/applied"]] [SentinelToNonce "0b5e17e11a0c0ffee0de1e9a7e5ba5ed", Rewrite "hostCpu = 3" "hostCpu = 4"], factOutputs = ["{run}/compiled/" <> name | name <- ["frozen.dhall", "decoded.dump", "lowered.dump", "plan.dump", "provisioned.dump", "manifest.json", "chain.dump", "dry-run.dump"]] <> ["{run}/applied/fake/stdin.combined"]}
  , inputSpineFact = Just SpineFact {spineRendered = "compiled/manifest.json", spineStages = ["freeze", "decode", "lower", "plan", "provision", "render", "chain", "dry-run", "fake-apply"], spineAppliedDigestFile = "applied/fake/applied.sha256"}
  , inputSubstrate = HardwareFree
  , inputSeed = Nothing
  }
capacityArtefacts :: [(Text, Text)]
capacityArtefacts = [(name, prefix) | (name, prefixes) <- owned, prefix <- prefixes]
 where
  owned =
    [ ("Amoebius.Capacity.Vector", ["fits."])
    , ("Amoebius.Capacity.Fits", ["fits."])
    , ("Amoebius.Placement.Witness", ["place.", "provision."])
    , ("Amoebius.Storage.Witness", ["volume.", "claims."])
    , ("Amoebius.Manifest.StatefulSet", ["claims.", "render."])
    , ("Amoebius.Manifest.Render", ["render.", "claims."])
    ]
capacityPositives :: [(Text, Text, Text)]
capacityPositives = [("kind-two-nodes", "kind-two-nodes.dhall", "application on the second node"), ("exact-fit-sibling", "exact-fit-sibling.dhall", "accepted on the boundary"), ("kind-sql-distributed3", "kind-sql-distributed3.dhall", "one claim per member"), ("kind-two-needs", "kind-two-needs.dhall", "both providers' objects"), ("fits-total", "three-valued vectors", "every pair judged"), ("volume-witness", "volume identities", "names from identity"), ("statefulset-claims", "statefulset render", "claim bytes equal the witness")]
capacityNegatives :: [(Text, Text, Text, Text)]
capacityNegatives = [("OneShort", "one-short-twin.dhall", "OneShort", "provision"), ("OverCapacity", "over-capacity-twin.dhall", "OverCapacity", "provision"), ("UnitMismatch", "cpu plus memory", "UnitsDoNotMix", "compile"), ("RenderWithoutWitness", "render without a placement", "WitnessRequired", "compile"), ("PlacedOutsideFold", "Placed construction", "ConstructorNotExported", "compile"), ("PvcWithoutStatefulSet", "claim on a Deployment", "PvcWithoutStatefulSet", "render"), ("VolumeOutsideWitness", "VolumeWitness construction", "ConstructorNotExported", "compile")]
