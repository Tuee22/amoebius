{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The hardware-free composition boundary. Stage implementations remain in
-- their owning libraries; this module checks the acquired observations that
-- prove their values crossed the complete spine in one run.
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
import Data.List (nub)
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
  , fakeRequestBytes :: Text
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
#if defined(DSL_BARRIER_LEGALITY_DROP_MUTANT)
  [Decode, BindExpand, PlanResolve, Provision, RenderAll, Plan, DryRun, FakeApply]
#elif defined(DSL_BARRIER_BIND_ARM_SWAP_MUTANT)
  [Decode, Legality, PlanResolve, BindExpand, Provision, RenderAll, Plan, DryRun, FakeApply]
#elif defined(DSL_BARRIER_RENDER_OMISSION_MUTANT)
  [Decode, Legality, BindExpand, PlanResolve, Provision, Plan, DryRun, FakeApply]
#elif defined(DSL_BARRIER_PLAN_REORDER_MUTANT)
  [Decode, Legality, BindExpand, PlanResolve, Provision, RenderAll, DryRun, Plan, FakeApply]
#else
  [minBound .. maxBound]
#endif

validateDslBarrier ::
  [StageObservation] -> BarrierChallenge -> FakeBoundaryObservation -> GateRun -> Either BarrierProblem ()
validateDslBarrier stages challenge fake gateRun = do
  require (map observedStage stages == expectedBarrierStages) (StageInventoryMismatch (map observedStage stages))
  mapM_ checkStage stages
  require (uniqueDigests stages) StageDigestCollision
  require (isAbsolute (fakeExecutable fake)) FakeExecutableNotAbsolute
  require (fakeArgv fake == ["apply", "--server-side=true", "-f", "-"]) FakeArgvMismatch
  require (fakeRequestBytes fake == "phase-49:" <> barrierChallengeText challenge) FakeRequestMismatch
  require (fakeRecoveredChallenge fake == barrierChallengeText challenge) FakeChallengeMismatch
#if !defined(DSL_BARRIER_DRY_RUN_EXECUTION_MUTANT)
  require (fakeEffectStage fake == FakeApply) EffectBeforeFakeApply
#endif
#if !defined(DSL_BARRIER_FAKE_CALL_BYPASS_MUTANT)
  require (fakeExternallyObserved fake) SelfObservation
#endif
  require (fakeTeardownObserved fake) FakeTeardownMissing
  require (runArms gateRun == everyArm) WorkflowArmMismatch
  require (evidenceObservation (runEvidence gateRun) == Evidence "observed") WorkflowEvidenceMismatch
  require (evidenceVerdict (runEvidence gateRun) == GatePassed) WorkflowEvidenceMismatch
  require (runBalances gateRun) WorkflowResourceLeak
  require (runDischargedOnce gateRun) WorkflowDoubleDischarge
  require (runIncludesMutants gateRun) WorkflowMutantsSkipped
 where
  checkStage observation = do
#if defined(DSL_BARRIER_DECODE_WIDENING_MUTANT)
    if observedStage observation == Decode then pure () else require (observedStagePassed observation) (StageFailed (observedStage observation))
#else
    require (observedStagePassed observation) (StageFailed (observedStage observation))
#endif
#if defined(DSL_BARRIER_DEMAND_OMISSION_MUTANT)
    if observedStage observation == PlanResolve then pure () else require (sha256Text (observedStageDigest observation)) (StageDigestMalformed (observedStage observation))
#else
    require (sha256Text (observedStageDigest observation)) (StageDigestMalformed (observedStage observation))
#endif

uniqueDigests :: [StageObservation] -> Bool
#if defined(DSL_BARRIER_PROVISION_IDENTITY_COLLAPSE_MUTANT)
uniqueDigests _ = True
#else
uniqueDigests observations =
  let values = map observedStageDigest observations
  in length values == length (nub values)
#endif

sha256Text :: Text -> Bool
sha256Text value =
  Text.length value == 64
    && Text.all (\character -> character >= '0' && character <= '9' || character >= 'a' && character <= 'f') value

require :: Bool -> problem -> Either problem ()
require condition problem = if condition then Right () else Left problem
