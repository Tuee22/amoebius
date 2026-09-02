{-# LANGUAGE OverloadedStrings #-}

-- | The @toolchain_spike@ capability's phase runner.
--
-- The capability's claim is to derive a compatible dependency graph from
-- pinned, network-independent toolchain inputs and build the required probes
-- without committing resolution output, integrity pins, generated code, or
-- host-specific paths.
--
-- Only part of that claim is establishable from an acquired source snapshot,
-- and this module is deliberately explicit about which part. It decides the
-- source-boundary half — the two legacy families this capability owns, and the
-- absence of committed resolution output — and it refuses, by name, every half
-- that needs an authenticated toolchain acquisition and a bound contract that
-- do not yet exist. A runner that returned a pass for the establishable half
-- alone would report a capability nobody has demonstrated.
module Amoebius.Validation.ToolchainSpikeRun
  ( toolchainSpikeRunCheck
  ) where

import Amoebius.Validation.SourceClosure.Internal
  ( AcquiredSourceSnapshot
  , IndexEntry (..)
  , SourceSnapshot (..)
  , TrackedEntry (..)
  , acquiredSourceSnapshot
  )
import Amoebius.Validation.Types (CheckResult (..), finding, observation)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text

-- | The capability's check over one acquired snapshot.
toolchainSpikeRunCheck :: AcquiredSourceSnapshot -> CheckResult
toolchainSpikeRunCheck acquired =
  CheckResult
    { checkName = "toolchain-spike"
    , checkObservations =
        [ observation "toolchain-spike.probe-foreign-count" (countText probeForeign)
        , observation "toolchain-spike.vendor-tracked-count" (countText vendorTracked)
        , observation "toolchain-spike.resolution-output-count" (countText resolutionOutput)
        ]
    , checkFindings =
        probeFindings <> vendorFindings <> resolutionFindings <> unresolvedFindings
    }
 where
  paths = sort (map (indexPath . trackedIndex) (snapshotEntries (acquiredSourceSnapshot acquired)))

  -- LTD-SRC-007. The probe root keeps its Haskell and its Cabal declaration;
  -- every case, mutation, and expected observation is generated beneath
  -- @.build/probe/**@ rather than tracked.
  probeForeign =
    [ path
    | path <- paths
    , under "probe" path
    , not (hasSuffix ".hs" path)
    , not (hasSuffix ".cabal" path)
    ]

  -- LTD-SRC-009. The transitional top-level vendor root is outside the target
  -- layout; maintained Haskell is re-derived beneath @src/vendor/**@ and every
  -- upstream input is acquired at an immutable identity beneath @.build/**@.
  vendorTracked = [path | path <- paths, under "vendor" path]

  -- Resolution output is a derived product of the dependency solve. Committing
  -- it would make the graph a checked-in artefact rather than something derived
  -- from the authenticated inputs, which is the half of the claim this snapshot
  -- can decide.
  resolutionOutput = [path | path <- paths, isResolutionOutput path]

  probeFindings =
    [ finding
        "TOOLCHAIN-SPIKE-PROBE-DEBT-OPEN"
        path
        "LTD-SRC-007: a tracked probe input is neither Haskell nor its Cabal declaration"
    | path <- probeForeign
    ]

  vendorFindings =
    [ finding
        "TOOLCHAIN-SPIKE-VENDOR-DEBT-OPEN"
        path
        "LTD-SRC-009: the transitional top-level vendor root is still tracked"
    | path <- vendorTracked
    ]

  resolutionFindings =
    [ finding
        "TOOLCHAIN-SPIKE-RESOLUTION-OUTPUT-TRACKED"
        path
        "resolution output is a derived product and belongs beneath .build/**, never in the tracked tree"
    | path <- resolutionOutput
    ]

  -- The rows the contract leaves UNRESOLVED. Each is a permanent refusal until
  -- its own artefact exists; naming them separately is what lets a reader tell
  -- an absent capability from a failing one.
  unresolvedFindings =
    [ finding
        "TOOLCHAIN-SPIKE-SUBJECT-UNRESOLVED"
        "DEVELOPMENT_PLAN/phase_01_toolchain_spike.md"
        "no production module and entry point are bound as this capability's Subject"
    , finding
        "TOOLCHAIN-SPIKE-ORACLE-UNRESOLVED"
        "DEVELOPMENT_PLAN/phase_01_toolchain_spike.md"
        "no separately authored oracle, independence boundary, or provenance is bound"
    , finding
        "TOOLCHAIN-SPIKE-TOOLCHAIN-UNAUTHENTICATED"
        "cabal.project"
        "no authenticated network-independent toolchain acquisition has been observed, so the dependency graph is not derived from a proven input"
    ]

countText :: [FilePath] -> Text
countText = Text.pack . show . length

under :: FilePath -> FilePath -> Bool
under root path = Text.pack (root <> "/") `Text.isPrefixOf` Text.pack path

hasSuffix :: String -> FilePath -> Bool
hasSuffix suffix = Text.isSuffixOf (Text.pack suffix) . Text.pack

-- | Committed output of a dependency solve, recognised by path rather than by
-- parsing any tracked non-Haskell file.
isResolutionOutput :: FilePath -> Bool
isResolutionOutput path =
  any
    (`hasSuffix` path)
    [ ".freeze"
    , ".lock"
    , "cabal.project.freeze"
    , "package-lock.json"
    , "yarn.lock"
    ]
