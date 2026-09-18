{-# LANGUAGE OverloadedStrings #-}

-- | The hardware-free composition boundary. Stage implementations remain in
-- their owning libraries; this module checks the acquired observations that
-- prove their values crossed the complete spine in one run.
--
-- Nothing here supplies a value it also checks. Every stage digest is computed
-- by the caller from an actual stage output, and the application boundary is
-- accepted only when the bytes a separate process was observed to receive are
-- the bytes the render stage was observed to produce.
module Amoebius.Validation.DslBarrier
  ( BarrierChallenge (..)
  , BarrierProblem (..)
  , BarrierStage (..)
  , FakeBoundaryObservation (..)
  , StageObservation (..)
  , expectedBarrierStages
  , validateDslBarrier
  ) where

import Amoebius.Calculus.Workflow.Arm (Evidence (Evidence), everyArm)
import Amoebius.Gate.SelfReferential
  ( GateRun (..), GateVerdict (GatePassed), evidenceObservation, evidenceVerdict, runEvidence )
import Data.List (find, nub)
import Data.Text (Text)
import Data.Text qualified as Text
import System.FilePath (isAbsolute)

data BarrierStage
  = Decode
  | Legality
  | BindExpand
  | PlanResolve
  | Provision
  | RenderAll
  | Plan
  | DryRun
  | FakeApply
  deriving stock (Bounded, Enum, Eq, Ord, Show)

data StageObservation = StageObservation
  { observedStage :: BarrierStage
  , observedStageDigest :: Text
  , observedStagePassed :: Bool
  }
  deriving stock (Eq, Show)

newtype BarrierChallenge = BarrierChallenge { barrierChallengeText :: Text }
  deriving stock (Eq, Show)

data FakeBoundaryObservation = FakeBoundaryObservation
  { fakeExecutable :: FilePath
  , fakeArgv :: [Text]
  , fakeRequestDigest :: Text
  , fakeRecoveredChallenge :: Text
  , fakeEffectStage :: BarrierStage
  , fakeExternallyObserved :: Bool
  , fakeTeardownObserved :: Bool
  }
  deriving stock (Eq, Show)

data BarrierProblem
  = StageInventoryMismatch [BarrierStage]
  | StageFailed BarrierStage
  | StageDigestMalformed BarrierStage
  | StageDigestCollision
  | FakeExecutableNotAbsolute
  | FakeArgvMismatch
  | FakeRequestMismatch
  | FakeChallengeMismatch
  | EffectBeforeFakeApply
  | SelfObservation
  | FakeTeardownMissing
  | WorkflowArmMismatch
  | WorkflowEvidenceMismatch
  | WorkflowResourceLeak
  | WorkflowDoubleDischarge
  | WorkflowMutantsSkipped
  deriving stock (Eq, Show)

expectedBarrierStages :: [BarrierStage]
expectedBarrierStages =
  [minBound .. maxBound]

validateDslBarrier ::
  [StageObservation] -> BarrierChallenge -> FakeBoundaryObservation -> GateRun -> Either BarrierProblem ()
validateDslBarrier stages challenge fake gateRun = do
  require (map observedStage stages == expectedBarrierStages) (StageInventoryMismatch (map observedStage stages))
  mapM_ checkStage stages
  require (uniqueDigests stages) StageDigestCollision
  require (isAbsolute (fakeExecutable fake)) FakeExecutableNotAbsolute
  require (fakeArgv fake == ["apply", "--server-side=true", "-f", "-"]) FakeArgvMismatch
  -- The applied request is accepted only when the bytes the separate child was
  -- observed to receive digest to the bytes the render stage was observed to
  -- produce. Neither side of this comparison is a constant in this module.
  renderedDigest <- maybe (Left (StageInventoryMismatch (map observedStage stages))) Right (digestOf RenderAll stages)
  require (fakeRequestDigest fake == renderedDigest) FakeRequestMismatch
  require (fakeRecoveredChallenge fake == barrierChallengeText challenge) FakeChallengeMismatch
  require (fakeEffectStage fake == FakeApply) EffectBeforeFakeApply
  require (fakeExternallyObserved fake) SelfObservation
  require (fakeTeardownObserved fake) FakeTeardownMissing
  require (runArms gateRun == everyArm) WorkflowArmMismatch
  require (evidenceObservation (runEvidence gateRun) == Evidence "observed") WorkflowEvidenceMismatch
  require (evidenceVerdict (runEvidence gateRun) == GatePassed) WorkflowEvidenceMismatch
  require (runBalances gateRun) WorkflowResourceLeak
  require (runDischargedOnce gateRun) WorkflowDoubleDischarge
  require (runIncludesMutants gateRun) WorkflowMutantsSkipped
 where
  checkStage observation = do
    require (observedStagePassed observation) (StageFailed (observedStage observation))
    require (sha256Text (observedStageDigest observation)) (StageDigestMalformed (observedStage observation))

digestOf :: BarrierStage -> [StageObservation] -> Maybe Text
digestOf stage = fmap observedStageDigest . find ((== stage) . observedStage)

uniqueDigests :: [StageObservation] -> Bool
uniqueDigests observations =
  let values = map observedStageDigest observations
  in length values == length (nub values)

sha256Text :: Text -> Bool
sha256Text value =
  Text.length value == 64
    && Text.all (\character -> character >= '0' && character <= '9' || character >= 'a' && character <= 'f') value

require :: Bool -> problem -> Either problem ()
require condition problem = if condition then Right () else Left problem
