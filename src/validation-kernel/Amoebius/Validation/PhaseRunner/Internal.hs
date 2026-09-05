{-# LANGUAGE OverloadedStrings #-}

{- | Closed production runner selection.  Selection is performed from the
compiled phase capability identity, never from a second ordinal switch or a
caller-supplied name.  The registry remains a list so duplicate entries are
observed and refused rather than silently collapsed by a map.
-}
module Amoebius.Validation.PhaseRunner.Internal (
    PhaseRunner (..),
    phaseRunnerRegistryCheck,
    phaseRunnerInternalTestRegistryCheck,
    phaseRunnerInternalTestSelect,
    selectPhaseRunner,
) where

import Amoebius.Validation.PhaseIdentity (
    allPhaseIdentities,
    lookupPhaseIdentity,
    phaseIdentityCapability,
    phaseIdentityOrdinal,
 )
import Amoebius.Validation.Types (
    CheckResult (..),
    Finding,
    finding,
    observation,
 )
import Data.List (group, sort)
import Data.Text (Text)
import Data.Text qualified as Text

data PhaseRunner
    = DocumentationSuiteRunner
    | ToolchainSpikeRunner
    | RepositoryLayoutRunner
    | ArtifactCalculusRunner
    | BudgetCalculusRunner
    | LiftCalculusRunner
    | WorkflowCalculusRunner
    | EvidenceCalculusRunner
    | ScopeIndexRunner
    | ResourceIndexRunner
    | CalculusCompositionRunner
    | FormalModelKernelRunner
    | ExplicitStateCheckerRunner
    | SymbolicCheckerRunner
    | RefinementCheckerRunner
    | CompileFailHarnessRunner
    | DeterministicSimulationRunner
    | GatewayMigrationModelRunner
    | DslFormalModelRunner
    | ReconcileCoreRunner
    | ExtensionDeclarationRunner
    | ExtensionLawsRunner
    | ExtensionCompositionRunner
    | ExtensionSecurityRunner
    | ConformanceGateRunner
    | DhallSchemaRunner
    | GadtDecodeRunner
    | IllegalStateCoveringRunner
    | StorageGeometryRunner
    | ExecutionAcceleratorRunner
    | CapabilityBindRunner
    | ProvisionSealRunner
    | InferenceAcceleratorRunner
    | RenderManifestRunner
    | ChainBoundaryRunner
    | ImageRecipeRunner
    | TransactionVocabularyRunner
    | UiProgramSchemaRunner
    | UiAuthorizationRunner
    | UiEffectBindingRunner
    | UiPlanCompilerRunner
    | OfflineLanguagePlanRunner
    | UiBrowserInterpreterRunner
    | UiServerBoundaryRunner
    | UiLocalCompositionRunner
    | EncryptedBrowserRuntimeRunner
    | UiContractGenerationRunner
    deriving (Eq, Ord, Show)

data RegisteredRunner = RegisteredRunner
    { registeredCapability :: Text
    , registeredRunner :: PhaseRunner
    }
    deriving (Eq, Ord, Show)

registeredRunners :: [RegisteredRunner]
registeredRunners =
    [ RegisteredRunner
        { registeredCapability = "documentation_suite"
        , registeredRunner = DocumentationSuiteRunner
        }
    , RegisteredRunner
        { registeredCapability = "toolchain_spike"
        , registeredRunner = ToolchainSpikeRunner
        }
    , RegisteredRunner
        { registeredCapability = "repository_layout_conformance"
        , registeredRunner = RepositoryLayoutRunner
        }
    , RegisteredRunner
        { registeredCapability = "artifact_calculus"
        , registeredRunner = ArtifactCalculusRunner
        }
    , RegisteredRunner
        { registeredCapability = "budget_calculus"
        , registeredRunner = BudgetCalculusRunner
        }
    , RegisteredRunner
        { registeredCapability = "lift_calculus"
        , registeredRunner = LiftCalculusRunner
        }
    , RegisteredRunner
        { registeredCapability = "workflow_calculus"
        , registeredRunner = WorkflowCalculusRunner
        }
    , RegisteredRunner
        { registeredCapability = "evidence_calculus"
        , registeredRunner = EvidenceCalculusRunner
        }
    , RegisteredRunner
        { registeredCapability = "scope_index"
        , registeredRunner = ScopeIndexRunner
        }
    , RegisteredRunner
        { registeredCapability = "resource_index"
        , registeredRunner = ResourceIndexRunner
        }
    , RegisteredRunner
        { registeredCapability = "calculus_composition"
        , registeredRunner = CalculusCompositionRunner
        }
    , RegisteredRunner
        { registeredCapability = "formal_model_kernel"
        , registeredRunner = FormalModelKernelRunner
        }
    , RegisteredRunner
        { registeredCapability = "explicit_state_checker"
        , registeredRunner = ExplicitStateCheckerRunner
        }
    , RegisteredRunner
        { registeredCapability = "symbolic_checker"
        , registeredRunner = SymbolicCheckerRunner
        }
    , RegisteredRunner
        { registeredCapability = "refinement_checker"
        , registeredRunner = RefinementCheckerRunner
        }
    , RegisteredRunner
        { registeredCapability = "compile_fail_harness"
        , registeredRunner = CompileFailHarnessRunner
        }
    , RegisteredRunner
        { registeredCapability = "deterministic_sim_substrate"
        , registeredRunner = DeterministicSimulationRunner
        }
    , RegisteredRunner
        { registeredCapability = "gateway_migration_model"
        , registeredRunner = GatewayMigrationModelRunner
        }
    , RegisteredRunner
        { registeredCapability = "dsl_formal_model"
        , registeredRunner = DslFormalModelRunner
        }
    , RegisteredRunner
        { registeredCapability = "reconcile_core_simulation"
        , registeredRunner = ReconcileCoreRunner
        }
    , RegisteredRunner
        { registeredCapability = "extension_declaration"
        , registeredRunner = ExtensionDeclarationRunner
        }
    , RegisteredRunner
        { registeredCapability = "extension_laws_per_extension"
        , registeredRunner = ExtensionLawsRunner
        }
    , RegisteredRunner
        { registeredCapability = "extension_laws_compositional"
        , registeredRunner = ExtensionCompositionRunner
        }
    , RegisteredRunner
        { registeredCapability = "extension_security_laws"
        , registeredRunner = ExtensionSecurityRunner
        }
    , RegisteredRunner
        { registeredCapability = "conformance_gate_generator"
        , registeredRunner = ConformanceGateRunner
        }
    , RegisteredRunner
        { registeredCapability = "dhall_schema_generation"
        , registeredRunner = DhallSchemaRunner
        }
    , RegisteredRunner
        { registeredCapability = "gadt_decode_ir"
        , registeredRunner = GadtDecodeRunner
        }
    , RegisteredRunner
        { registeredCapability = "illegal_state_covering"
        , registeredRunner = IllegalStateCoveringRunner
        }
    , RegisteredRunner
        { registeredCapability = "storage_geometry_folds"
        , registeredRunner = StorageGeometryRunner
        }
    , RegisteredRunner
        { registeredCapability = "execution_accelerator_folds"
        , registeredRunner = ExecutionAcceleratorRunner
        }
    , RegisteredRunner
        { registeredCapability = "capability_bind"
        , registeredRunner = CapabilityBindRunner
        }
    , RegisteredRunner
        { registeredCapability = "provision_seal"
        , registeredRunner = ProvisionSealRunner
        }
    , RegisteredRunner
        { registeredCapability = "inference_accelerator_provision"
        , registeredRunner = InferenceAcceleratorRunner
        }
    , RegisteredRunner
        { registeredCapability = "render_manifest_oracles"
        , registeredRunner = RenderManifestRunner
        }
    , RegisteredRunner
        { registeredCapability = "chain_kernel_boundary"
        , registeredRunner = ChainBoundaryRunner
        }
    , RegisteredRunner
        { registeredCapability = "image_recipe_generation"
        , registeredRunner = ImageRecipeRunner
        }
    , RegisteredRunner
        { registeredCapability = "transaction_vocabulary"
        , registeredRunner = TransactionVocabularyRunner
        }
    , RegisteredRunner
        { registeredCapability = "ui_program_schema"
        , registeredRunner = UiProgramSchemaRunner
        }
    , RegisteredRunner
        { registeredCapability = "ui_authorization_kernel"
        , registeredRunner = UiAuthorizationRunner
        }
    , RegisteredRunner
        { registeredCapability = "ui_effect_binding"
        , registeredRunner = UiEffectBindingRunner
        }
    , RegisteredRunner
        { registeredCapability = "ui_plan_compiler"
        , registeredRunner = UiPlanCompilerRunner
        }
    , RegisteredRunner
        { registeredCapability = "offline_language_plan"
        , registeredRunner = OfflineLanguagePlanRunner
        }
    , RegisteredRunner
        { registeredCapability = "ui_browser_interpreter"
        , registeredRunner = UiBrowserInterpreterRunner
        }
    , RegisteredRunner
        { registeredCapability = "ui_server_boundary"
        , registeredRunner = UiServerBoundaryRunner
        }
    , RegisteredRunner
        { registeredCapability = "ui_local_composition"
        , registeredRunner = UiLocalCompositionRunner
        }
    , RegisteredRunner
        { registeredCapability = "encrypted_browser_runtime"
        , registeredRunner = EncryptedBrowserRuntimeRunner
        }
    , RegisteredRunner
        { registeredCapability = "ui_contract_generation"
        , registeredRunner = UiContractGenerationRunner
        }
    ]

selectPhaseRunner :: Int -> Either Finding PhaseRunner
selectPhaseRunner = selectPhaseRunnerWith registeredRunners

phaseRunnerInternalTestSelect :: [(Text, PhaseRunner)] -> Int -> Either Finding PhaseRunner
phaseRunnerInternalTestSelect entries =
    selectPhaseRunnerWith
        [ RegisteredRunner capability runner
        | (capability, runner) <- entries
        ]

selectPhaseRunnerWith :: [RegisteredRunner] -> Int -> Either Finding PhaseRunner
selectPhaseRunnerWith registry ordinal =
    case lookupPhaseIdentity ordinal of
        Nothing ->
            Left
                ( finding
                    "PHASE-RUNNER-IDENTITY-ABSENT"
                    ("phase-" <> show ordinal)
                    "the requested ordinal has no compiled phase identity"
                )
        Just identity ->
            case [ registeredRunner entry
                 | entry <- registry
                 , registeredCapability entry == phaseIdentityCapability identity
                 ] of
                [runner] -> Right runner
                [] ->
                    Left
                        ( finding
                            "PHASE-RUNNER-ABSENT"
                            ("phase-" <> show ordinal)
                            ( "no production runner is registered for capability "
                                <> phaseIdentityCapability identity
                            )
                        )
                _ ->
                    Left
                        ( finding
                            "PHASE-RUNNER-AMBIGUOUS"
                            ("phase-" <> show ordinal)
                            ( "more than one production runner is registered for capability "
                                <> phaseIdentityCapability identity
                            )
                        )

phaseRunnerRegistryCheck :: CheckResult
phaseRunnerRegistryCheck = phaseRunnerRegistryCheckWith registeredRunners

phaseRunnerInternalTestRegistryCheck :: [(Text, PhaseRunner)] -> CheckResult
phaseRunnerInternalTestRegistryCheck entries =
    phaseRunnerRegistryCheckWith
        [ RegisteredRunner capability runner
        | (capability, runner) <- entries
        ]

phaseRunnerRegistryCheckWith :: [RegisteredRunner] -> CheckResult
phaseRunnerRegistryCheckWith registry =
    CheckResult
        { checkName = "phase-runner-registry"
        , checkObservations =
            [ observation "phase-runner.registry-count" (Text.pack (show (length registry)))
            , observation "phase-runner.registry-kind" "closed capability-keyed list"
            ]
                <> [ observation
                        ("phase-runner." <> registeredCapability entry)
                        (Text.pack (show (registeredRunner entry)))
                   | entry <- registry
                   ]
        , checkFindings = registryFindings registry
        }

registryFindings :: [RegisteredRunner] -> [Finding]
registryFindings registry =
    [ finding
        "PHASE-RUNNER-CAPABILITY-DUPLICATE"
        (Text.unpack capability)
        "a capability occurs more than once in the closed runner registry"
    | capability <- duplicates (map registeredCapability registry)
    ]
        <> [ finding
                "PHASE-RUNNER-CAPABILITY-UNKNOWN"
                (Text.unpack (registeredCapability entry))
                "a registered runner names no compiled phase capability"
           | entry <- registry
           , registeredCapability entry `notElem` compiledCapabilities
           ]
        <> [ finding
                "PHASE-RUNNER-ORDINAL-DUPLICATE"
                ("phase-" <> show ordinal)
                "distinct registered capabilities resolve to the same phase ordinal"
           | ordinal <- duplicates registeredOrdinals
           ]
  where
    compiledCapabilities = map phaseIdentityCapability allPhaseIdentities
    registeredOrdinals =
        [ phaseIdentityOrdinal identity
        | entry <- registry
        , identity <- allPhaseIdentities
        , phaseIdentityCapability identity == registeredCapability entry
        ]

duplicates :: (Ord value) => [value] -> [value]
duplicates = foldr repeated [] . group . sort
  where
    repeated (value : _ : _) rest = value : rest
    repeated _ rest = rest
