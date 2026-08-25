{-# LANGUAGE OverloadedStrings #-}

-- | Mechanical observations and predicates for the five per-extension laws.
--
-- The values in this module are observations made by a gate over an
-- 'ExtensionDeclaration'; they are not a second extension declaration.  Coverage checks
-- join every observation back to the declaration's five derived sets before a law can
-- pass.  Process isolation, exception capture, compiler execution, and source scanning
-- stay in the harness that constructs these observations.
module Amoebius.Extension.Laws.PerExtension
  ( Law (..)
  , everyLaw
  , lawTag
  , OperationOutcome (..)
  , OperationObservation (..)
  , ArtifactObservation (..)
  , ExhaustionObservation (..)
  , RetentionObservation (..)
  , BudgetObservation (..)
  , FlowScope (..)
  , FlowObservation (..)
  , FixtureObservation (..)
  , ClaimObservation (..)
  , LawObservations (..)
  , LawVocabulary
  , emptyVocabulary
  , declarationVocabulary
  , unionVocabulary
  , vocabularyOperationNames
  , vocabularyArtifactNames
  , vocabularyBudgetNames
  , vocabularyClaimNames
  , restrictObservations
  , LawFailure (..)
  , LawVerdict (..)
  , evaluateLaws
  , evaluateVocabularyLaws
  , lawPassed
  ) where

import Amoebius.Extension.Declaration
  ( DeclaredComponent (declaredName)
  , ExtensionDeclaration
  , declarationArtifactSet
  , declarationBudgetSet
  , declarationEvidenceSet
  , declarationWorkflowSet
  )
import Data.ByteString (ByteString)
import Data.List (sort)
import Data.Set qualified as Set
import Data.Text (Text)

data Law = L1 | L2 | L3 | L4 | L5
  deriving stock (Eq, Ord, Show, Enum, Bounded)

everyLaw :: [Law]
everyLaw = [minBound .. maxBound]

lawTag :: Law -> Text
lawTag law = case law of
  L1 -> "L1"
  L2 -> "L2"
  L3 -> "L3"
  L4 -> "L4"
  L5 -> "L5"

data OperationOutcome
  = OperationReturned Text
  | OperationRefused Text
  | OperationEscaped Text
  deriving stock (Eq, Ord, Show)

data OperationObservation = OperationObservation
  { operationName :: Text
  , operationInput :: Text
  , operationOutcome :: OperationOutcome
  }
  deriving stock (Eq, Ord, Show)

data ArtifactObservation = ArtifactObservation
  { artifactName :: Text
  , artifactFirstBytes :: ByteString
  , artifactSecondBytes :: ByteString
  }
  deriving stock (Eq, Ord, Show)

data ExhaustionObservation
  = RefusedBeforeMaterialization
  | MaterializedBeforeRefusal
  | ExhaustionWasNotRefused
  deriving stock (Eq, Ord, Show)

data RetentionObservation
  = EphemeralOutput
  | RetainedWithReaper Text
  | RetainedWithoutReaper
  deriving stock (Eq, Ord, Show)

data BudgetObservation = BudgetObservation
  { budgetArtifact :: Text
  , budgetComponent :: Text
  , budgetExhaustion :: ExhaustionObservation
  , budgetRetention :: RetentionObservation
  }
  deriving stock (Eq, Ord, Show)

-- | Narrowest to widest.  A result may stay at or narrow from its source; increasing
-- this order is the scope loss L4 forbids.
data FlowScope = RequestFlow | TenantFlow | GlobalFlow
  deriving stock (Eq, Ord, Show, Enum, Bounded)

data FlowObservation = FlowObservation
  { flowOperation :: Text
  , flowSource :: FlowScope
  , flowSink :: FlowScope
  }
  deriving stock (Eq, Ord, Show)

data FixtureObservation
  = FixturePassedAtPinnedReason Text
  | FixtureFailedAtOtherReason Text
  | FixtureMissing
  deriving stock (Eq, Ord, Show)

data ClaimObservation = ClaimObservation
  { claimName :: Text
  , claimFixture :: FixtureObservation
  }
  deriving stock (Eq, Ord, Show)

data LawObservations = LawObservations
  { observedOperations :: [OperationObservation]
  , observedArtifacts :: [ArtifactObservation]
  , observedBudgets :: [BudgetObservation]
  , observedFlows :: [FlowObservation]
  , observedClaims :: [ClaimObservation]
  }
  deriving stock (Eq, Show)

-- | The declaration-derived names against which observations are checked.  Its
-- constructor is private: callers obtain a vocabulary from a complete declaration and
-- combine vocabularies only by set union.  Phase 23 uses that union for a composite
-- without weakening Phase 21's exactly-five-components declaration invariant.
data LawVocabulary = LawVocabulary
  { vocabularyOperations :: Set.Set Text
  , vocabularyArtifacts :: Set.Set Text
  , vocabularyBudgets :: Set.Set Text
  , vocabularyClaims :: Set.Set Text
  }
  deriving stock (Eq, Show)

emptyVocabulary :: LawVocabulary
emptyVocabulary = LawVocabulary Set.empty Set.empty Set.empty Set.empty

declarationVocabulary :: ExtensionDeclaration scope -> LawVocabulary
declarationVocabulary declaration =
  LawVocabulary
    { vocabularyOperations = namesOf (declarationWorkflowSet declaration)
    , vocabularyArtifacts = namesOf (declarationArtifactSet declaration)
    , vocabularyBudgets = namesOf (declarationBudgetSet declaration)
    , vocabularyClaims = namesOf (declarationEvidenceSet declaration)
    }

unionVocabulary :: LawVocabulary -> LawVocabulary -> LawVocabulary
unionVocabulary left right =
  LawVocabulary
    { vocabularyOperations = Set.union (vocabularyOperations left) (vocabularyOperations right)
    , vocabularyArtifacts = Set.union (vocabularyArtifacts left) (vocabularyArtifacts right)
    , vocabularyBudgets = Set.union (vocabularyBudgets left) (vocabularyBudgets right)
    , vocabularyClaims = Set.union (vocabularyClaims left) (vocabularyClaims right)
    }

vocabularyOperationNames :: LawVocabulary -> [Text]
vocabularyOperationNames = Set.toAscList . vocabularyOperations

vocabularyArtifactNames :: LawVocabulary -> [Text]
vocabularyArtifactNames = Set.toAscList . vocabularyArtifacts

vocabularyBudgetNames :: LawVocabulary -> [Text]
vocabularyBudgetNames = Set.toAscList . vocabularyBudgets

vocabularyClaimNames :: LawVocabulary -> [Text]
vocabularyClaimNames = Set.toAscList . vocabularyClaims

-- | Restrict a composite observation bundle to one declaration-derived vocabulary.
-- This is the observable projection used by C4; it does not synthesize a missing row.
restrictObservations :: LawVocabulary -> LawObservations -> LawObservations
restrictObservations vocabulary observations =
  LawObservations
    { observedOperations = filter ((`Set.member` vocabularyOperations vocabulary) . operationName) (observedOperations observations)
    , observedArtifacts = filter ((`Set.member` vocabularyArtifacts vocabulary) . artifactName) (observedArtifacts observations)
    , observedBudgets = filter ((`Set.member` vocabularyArtifacts vocabulary) . budgetArtifact) (observedBudgets observations)
    , observedFlows = filter ((`Set.member` vocabularyOperations vocabulary) . flowOperation) (observedFlows observations)
    , observedClaims = filter ((`Set.member` vocabularyClaims vocabulary) . claimName) (observedClaims observations)
    }

data LawFailure
  = OperationCoverageMismatch [Text] [Text]
  | OperationEscapedFailure Text Text
  | ArtifactCoverageMismatch [Text] [Text]
  | ArtifactBytesDiffer Text
  | BudgetCoverageMismatch [Text] [Text]
  | UnknownBudgetComponent Text Text
  | ExhaustionDidNotRefuseBeforeMaterialization Text
  | RetainedOutputHasNoReaper Text
  | FlowCoverageMismatch [Text] [Text]
  | ScopeWasWidened Text FlowScope FlowScope
  | ClaimCoverageMismatch [Text] [Text]
  | ClaimHasNoFixture Text
  | ClaimFixtureMissedPinnedReason Text
  deriving stock (Eq, Ord, Show)

data LawVerdict
  = LawPassed
  | LawFailed [LawFailure]
  deriving stock (Eq, Ord, Show)

evaluateLaws
  :: ExtensionDeclaration scope
  -> LawObservations
  -> [(Law, LawVerdict)]
evaluateLaws declaration = evaluateVocabularyLaws (declarationVocabulary declaration)

evaluateVocabularyLaws :: LawVocabulary -> LawObservations -> [(Law, LawVerdict)]
evaluateVocabularyLaws vocabulary observations =
  [ (L1, verdict (l1Failures vocabulary observations))
  , (L2, verdict (l2Failures vocabulary observations))
  , (L3, verdict (l3Failures vocabulary observations))
  , (L4, verdict (l4Failures vocabulary observations))
  , (L5, verdict (l5Failures vocabulary observations))
  ]

lawPassed :: LawVerdict -> Bool
lawPassed verdictValue = case verdictValue of
  LawPassed -> True
  LawFailed _ -> False

verdict :: [LawFailure] -> LawVerdict
verdict failures = case failures of
  [] -> LawPassed
  _ -> LawFailed failures

l1Failures :: LawVocabulary -> LawObservations -> [LawFailure]
l1Failures vocabulary observations =
  coverageFailure
    OperationCoverageMismatch
    (vocabularyOperationNames vocabulary)
    (fmap operationName operations)
    <> [ OperationEscapedFailure (operationName operation) (operationInput operation)
       | operation <- operations
       , isEscape (operationOutcome operation)
       ]
 where
  operations = observedOperations observations
  isEscape outcome = case outcome of
    OperationReturned _ -> False
    OperationRefused _ -> False
    OperationEscaped _ -> True

l2Failures :: LawVocabulary -> LawObservations -> [LawFailure]
l2Failures vocabulary observations =
  coverageFailure
    ArtifactCoverageMismatch
    (vocabularyArtifactNames vocabulary)
    (fmap artifactName artifacts)
    <> [ArtifactBytesDiffer (artifactName artifact) | artifact <- artifacts, artifactFirstBytes artifact /= artifactSecondBytes artifact]
 where
  artifacts = observedArtifacts observations

l3Failures :: LawVocabulary -> LawObservations -> [LawFailure]
l3Failures vocabulary observations =
  coverageFailure
    BudgetCoverageMismatch
    (vocabularyArtifactNames vocabulary)
    (fmap budgetArtifact budgets)
    <> concatMap checkBudget budgets
 where
  budgets = observedBudgets observations
  declaredBudgets = Set.fromList (vocabularyBudgetNames vocabulary)
  checkBudget budget =
    [ UnknownBudgetComponent (budgetArtifact budget) (budgetComponent budget)
    | budgetComponent budget `Set.notMember` declaredBudgets
    ]
      <> [ ExhaustionDidNotRefuseBeforeMaterialization (budgetArtifact budget)
         | budgetExhaustion budget /= RefusedBeforeMaterialization
         ]
      <> case budgetRetention budget of
        EphemeralOutput -> []
        RetainedWithReaper condition | condition /= "" -> []
        RetainedWithReaper _ -> [RetainedOutputHasNoReaper (budgetArtifact budget)]
        RetainedWithoutReaper -> [RetainedOutputHasNoReaper (budgetArtifact budget)]

l4Failures :: LawVocabulary -> LawObservations -> [LawFailure]
l4Failures vocabulary observations =
  coverageFailure
    FlowCoverageMismatch
    (vocabularyOperationNames vocabulary)
    (fmap flowOperation flows)
    <> [ ScopeWasWidened (flowOperation flow) (flowSource flow) (flowSink flow)
       | flow <- flows
       , flowSink flow > flowSource flow
       ]
 where
  flows = observedFlows observations

l5Failures :: LawVocabulary -> LawObservations -> [LawFailure]
l5Failures vocabulary observations =
  coverageFailure
    ClaimCoverageMismatch
    (vocabularyClaimNames vocabulary)
    (fmap claimName claims)
    <> concatMap checkClaim claims
 where
  claims = observedClaims observations
  checkClaim claim = case claimFixture claim of
    FixturePassedAtPinnedReason path | path /= "" -> []
    FixturePassedAtPinnedReason _ -> [ClaimHasNoFixture (claimName claim)]
    FixtureFailedAtOtherReason _ -> [ClaimFixtureMissedPinnedReason (claimName claim)]
    FixtureMissing -> [ClaimHasNoFixture (claimName claim)]

componentNames :: Set.Set DeclaredComponent -> [Text]
componentNames = sort . fmap declaredName . Set.toList

namesOf :: Set.Set DeclaredComponent -> Set.Set Text
namesOf = Set.fromList . componentNames

coverageFailure
  :: ([Text] -> [Text] -> LawFailure)
  -> [Text]
  -> [Text]
  -> [LawFailure]
coverageFailure constructor expected observed
  | expected == distinctObserved = []
  | otherwise = [constructor expected distinctObserved]
 where
  distinctObserved = Set.toAscList (Set.fromList observed)
