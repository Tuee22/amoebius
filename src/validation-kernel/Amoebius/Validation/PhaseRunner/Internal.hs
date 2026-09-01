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
