{-# LANGUAGE OverloadedStrings #-}
-- | Pure preflight over observed facts (gate_runner_doctrine.md section 5; DL-0013).
module Amoebius.Validation.Custody.Preflight
  ( HostFacts (..), PreflightFacts (..), PreflightRefusal (..), hostFacts, preflight, renderPreflightRefusal, specWeakened ) where
import Amoebius.Validation.GateSpec
import Data.List (isPrefixOf)
import Data.Maybe (isJust, isNothing)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (doesPathExist)
import System.Info (os)
data PreflightRefusal
  = StatusSurfaceDirty | PredecessorNotCommitted | StatusWithoutReceipt [Int] | PredecessorNotReproduced [Int]
  | GovernanceUnaccepted Text | HardwareBeforeBarrier | SubstrateAbsent GateSubstrate
  | KernelOverBudget Text | SpecWeakened [Text]
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
data HostFacts = HostFacts { hostSubstrates :: [GateSubstrate] } deriving (Eq, Show)
-- | Live substrate observations; callers must already have passed the hardware barrier.
hostFacts :: IO HostFacts
hostFacts = do
  nvidia <- doesPathExist "/dev/nvidia0"
  pure (HostFacts (HardwareFree : concat
    [[LinuxCpu | os == "linux"], [LinuxCuda | os == "linux", nvidia],
     [Apple | os == "darwin"], [Windows | "mingw" `isPrefixOf` os]]))
data PreflightFacts = PreflightFacts
  { factsSpec :: GateSpec, factsSurfaceDigest :: Text, factsAcceptedPostimage :: Maybe Text, factsSurfaceConsistent :: Bool
  , factsPredecessorCommitted :: Maybe Bool, factsDoneWithoutReceipt :: [Int], factsPredecessorsNotReproduced :: [Int]
  , factsFrozenFindings :: [Text], factsBarrierReceipt :: Bool, factsHost :: HostFacts
  , factsHygieneProblems :: [Text], factsPreviousSpec :: Maybe GateSpec } deriving (Show)
preflight :: PreflightFacts -> [PreflightRefusal]
preflight facts =
  concat
    [ [StatusSurfaceDirty | not (factsSurfaceConsistent facts) || maybe False (/= factsSurfaceDigest facts) (factsAcceptedPostimage facts)]
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
-- | Detect dropped accepted cases, stages, facts and mutation bounds.
specWeakened :: GateSpec -> GateSpec -> [Text]
specWeakened previous current =
  ["case " <> caseName item | item <- gateCases previous, caseName item `notElem` map caseName (gateCases current)]
    <> ["stage module " <> productionModuleName stage | stage <- stageModules (gateMutants previous), stage `notElem` stageModules (gateMutants current)]
    <> ["binary fact" | isJust (gateBinaryFact previous), isNothing (gateBinaryFact current)]
    <> ["spine fact" | isJust (gateSpineFact previous), isNothing (gateSpineFact current)]
    <> ["kill ratio" | killRatio (gateMutants current) < killRatio (gateMutants previous)]
    <> ["per-module count" | perModule (gateMutants current) < perModule (gateMutants previous)]
