{-# LANGUAGE OverloadedStrings #-}

-- | The preflight refusals (gate_runner_doctrine.md section 5; DL-0013). The facts
-- are gathered from the tree, the store, and the host; the decision is a pure
-- function of them so every refusal has a paired negative the runner suite can
-- state as a value.
module Amoebius.Validation.Custody.Preflight
  ( HostFacts (..)
  , PreflightFacts (..)
  , PreflightRefusal (..)
  , hostFacts
  , preflight
  , renderPreflightRefusal
  , specWeakened
  ) where

import Amoebius.Validation.GateSpec
import Data.List (isPrefixOf)
import Data.Maybe (isJust, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (doesPathExist)
import System.Info (os)

data PreflightRefusal
  = StatusSurfaceDirty
  | PredecessorNotCommitted
  | StatusWithoutReceipt [Int]
  | PredecessorNotReproduced [Int]
  | GovernanceUnaccepted Text
  | HardwareBeforeBarrier
  | SubstrateAbsent Substrate
  | KernelOverBudget Text
  | SpecWeakened [Text]
  deriving (Eq, Ord, Show)

renderPreflightRefusal :: PreflightRefusal -> Text
renderPreflightRefusal refusal = case refusal of
  StatusSurfaceDirty -> "StatusSurfaceDirty: the status surface differs from the last recorded postimage"
  PredecessorNotCommitted -> "PredecessorNotCommitted: the predecessor receipt's tree is not an ancestor of the current tree"
  StatusWithoutReceipt phases -> "STATUS-WITHOUT-RECEIPT: " <> Text.intercalate "," (map (Text.pack . show) phases)
  PredecessorNotReproduced phases -> "PredecessorNotReproduced: no store record of this generation re-derives the receipt digest recorded for phase " <> Text.intercalate "," (map (Text.pack . show) phases) <> "; run `amoebius-validate replay`"
  GovernanceUnaccepted detail -> "GOVERNANCE-UNACCEPTED: " <> detail
  HardwareBeforeBarrier -> "HARDWARE-BEFORE-BARRIER: no DSL_BARRIER receipt exists"
  SubstrateAbsent substrate -> "SUBSTRATE-ABSENT: " <> renderSubstrate substrate
  KernelOverBudget detail -> "KernelOverBudget: " <> detail
  SpecWeakened dropped -> "SPEC-WEAKENED: " <> Text.intercalate "; " dropped

data HostFacts = HostFacts
  { hostSubstrates :: [Substrate]
  }
  deriving (Eq, Show)

-- | The substrates this host can carry: hardware-free always; linux-cpu on
-- Linux; linux-cuda when an NVIDIA device node exists; apple on darwin.
hostFacts :: IO HostFacts
hostFacts = do
  nvidia <- doesPathExist "/dev/nvidia0"
  pure
    HostFacts
      { hostSubstrates =
          HardwareFree
            : concat
              [ [LinuxCpu | os == "linux"]
              , [LinuxCuda | os == "linux", nvidia]
              , [Apple | os == "darwin"]
              , [Windows | "mingw" `isPrefixOf` os]
              ]
      }

data PreflightFacts = PreflightFacts
  { factsSpec :: GateSpec
  , factsSurfaceDigest :: Text
  , factsAcceptedPostimage :: Maybe Text
  , factsPredecessorCommitted :: Maybe Bool
  , factsDoneWithoutReceipt :: [Int]
  , factsPredecessorsNotReproduced :: [Int]
  , factsFrozenFindings :: [Text]
  , factsBarrierReceipt :: Bool
  , factsHost :: HostFacts
  , factsHygieneProblems :: [Text]
  , factsPreviousSpec :: Maybe GateSpec
  }
  deriving (Show)

-- | Every refusal that applies, in the doctrine's order.
preflight :: PreflightFacts -> [PreflightRefusal]
preflight facts =
  concat
    [ [StatusSurfaceDirty | Just accepted <- [factsAcceptedPostimage facts], accepted /= factsSurfaceDigest facts]
    , [PredecessorNotCommitted | factsPredecessorCommitted facts == Just False]
    , [StatusWithoutReceipt (factsDoneWithoutReceipt facts) | not (null (factsDoneWithoutReceipt facts))]
    , [PredecessorNotReproduced (factsPredecessorsNotReproduced facts) | not (null (factsPredecessorsNotReproduced facts))]
    , [GovernanceUnaccepted (Text.intercalate "," (factsFrozenFindings facts)) | not (null (factsFrozenFindings facts))]
    , [HardwareBeforeBarrier | gateRole spec == HardwareGate, not (factsBarrierReceipt facts)]
    , [SubstrateAbsent (gateSubstrate spec) | gateSubstrate spec `notElem` hostSubstrates (factsHost facts)]
    , [KernelOverBudget (Text.intercalate "; " (factsHygieneProblems facts)) | not (null (factsHygieneProblems facts))]
    , [SpecWeakened dropped | Just previous <- [factsPreviousSpec facts], let dropped = specWeakened previous spec, not (null dropped)]
    ]
 where
  spec = factsSpec facts

-- | What the new specification dropped relative to the last accepted one: a
-- case, a stage module, or a fact.
specWeakened :: GateSpec -> GateSpec -> [Text]
specWeakened previous current =
  [ "case " <> caseName item
  | item <- gateCases previous
  , caseName item `notElem` map caseName (gateCases current)
  ]
    <> [ "stage module " <> productionModuleName stage
       | stage <- stageModules (gateMutants previous)
       , stage `notElem` stageModules (gateMutants current)
       ]
    <> ["binary fact" | isJust (gateBinaryFact previous), isNothing (gateBinaryFact current)]
    <> ["spine fact" | isJust (gateSpineFact previous), isNothing (gateSpineFact current)]
    <> ["kill ratio" | killRatio (gateMutants current) < killRatio (gateMutants previous)]
    <> ["per-module count" | perModule (gateMutants current) < perModule (gateMutants previous)]
