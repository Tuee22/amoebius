{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.GatePass
  ( CandidateBinding (..)
  , GatePass (..)
  , GatePassError (..)
  , requiredGateRows
  , requiredStatusFields
  , verifyGatePass
  ) where

import Amoebius.Validation.PolicyContract.Internal
  ( AutomationRole (CandidateEvidenceAndGatePass)
  , GatePassRule (QualifiedGatePass)
  , StatusTransitionRule (PassingGate)
  , automationRole
  , canonicalPolicyContract
  , gateCompletionContract
  , gatePassRule
  , orderingContract
  , phaseDomainUpper
  , phaseOrdinalNumber
  , statusTransitionRule
  )
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text

-- | A caller-constructible diagnostic description of the exact candidate a
-- complete phase gate claims to have exercised.  This value is never write
-- authority; only the package-hidden verified token can authorize a status
-- projection.
data CandidateBinding = CandidateBinding
  { candidatePhase :: Text
  , candidateSourceDigest :: Text
  , candidateContractDigest :: Text
  , candidateHarnessDigest :: Text
  , candidateEvidenceDigest :: Text
  , candidatePredecessorDigest :: Text
  , candidateProjectionDigest :: Text
  , candidateStatusFields :: Set Text
  }
  deriving (Eq, Ord, Show)

-- | A caller-constructible diagnostic report for one qualified run.  Matching
-- this report is necessary but not itself authority to change tracked state.
data GatePass = GatePass
  { passPhase :: Text
  , passSourceDigest :: Text
  , passContractDigest :: Text
  , passHarnessDigest :: Text
  , passEvidenceDigest :: Text
  , passPredecessorDigest :: Text
  , passProjectionDigest :: Text
  , passStatusFields :: Set Text
  , passRows :: Set Text
  , passQualificationSucceeded :: Bool
  , passCleanRunSucceeded :: Bool
  , passSourceUnchanged :: Bool
  }
  deriving (Eq, Ord, Show)

data GatePassError
  = GatePassPolicyContractMismatch
  | GatePassBindingMalformed
  | GatePassPhaseMismatch
  | GatePassSourceMismatch
  | GatePassContractMismatch
  | GatePassHarnessMismatch
  | GatePassEvidenceMismatch
  | GatePassPredecessorMismatch
  | GatePassPredecessorGenesisMismatch
  | GatePassProjectionMismatch
  | GatePassStatusFieldsMismatch
  | GatePassRowsIncomplete
  | GatePassQualificationFailed
  | GatePassCleanRunFailed
  | GatePassSourceChanged
  deriving (Eq, Ord, Show)

requiredGateRows :: Set Text
requiredGateRows =
  Set.fromList
    [ "Claim"
    , "Subject"
    , "Command"
    , "Oracle"
    , "Positive controls"
    , "Paired negatives"
    , "Mutants"
    , "Discovery"
    , "Challenge"
    , "Observer"
    , "Authority/bypass"
    , "Freshness"
    , "Qualification"
    , "Cleanroom"
    , "Legacy closure"
    , "Predecessor"
    , "Residue"
    , "Pass criterion"
    ]

requiredStatusFields :: Set Text
requiredStatusFields =
  Set.fromList
    [ "tracker-phase-status"
    , "phase-status"
    , "sprint-heading-statuses"
    , "sprint-status-fields"
    ]

verifyGatePass :: CandidateBinding -> GatePass -> Either GatePassError ()
verifyGatePass candidate result = do
  require (canonicalBinding candidate result) GatePassBindingMalformed
  require canonicalGateBoundary GatePassPolicyContractMismatch
  require (passPhase result == candidatePhase candidate) GatePassPhaseMismatch
  require (passSourceDigest result == candidateSourceDigest candidate) GatePassSourceMismatch
  require (passContractDigest result == candidateContractDigest candidate) GatePassContractMismatch
  require (passHarnessDigest result == candidateHarnessDigest candidate) GatePassHarnessMismatch
  require (passEvidenceDigest result == candidateEvidenceDigest candidate) GatePassEvidenceMismatch
  require (passPredecessorDigest result == candidatePredecessorDigest candidate) GatePassPredecessorMismatch
  require
    ( predecessorMatchesPhase (candidatePhase candidate) (candidatePredecessorDigest candidate)
        && predecessorMatchesPhase (passPhase result) (passPredecessorDigest result)
    )
    GatePassPredecessorGenesisMismatch
  require (passProjectionDigest result == candidateProjectionDigest candidate) GatePassProjectionMismatch
  require
    ( candidateStatusFields candidate == requiredStatusFields
        && passStatusFields result == requiredStatusFields
    )
    GatePassStatusFieldsMismatch
  require (passRows result == requiredGateRows) GatePassRowsIncomplete
  require (passQualificationSucceeded result) GatePassQualificationFailed
  require (passCleanRunSucceeded result) GatePassCleanRunFailed
  require (passSourceUnchanged result) GatePassSourceChanged
 where
  require True _ = Right ()
  require False problem = Left problem

predecessorMatchesPhase :: Text -> Text -> Bool
predecessorMatchesPhase phase predecessor
  | phase == "00" = predecessor == "genesis"
  | otherwise = predecessor /= "genesis" && sha256Text predecessor

canonicalGateBoundary :: Bool
canonicalGateBoundary =
  gatePassRule contract == QualifiedGatePass
    && automationRole contract == CandidateEvidenceAndGatePass
    && statusTransitionRule contract == PassingGate
 where
  contract = gateCompletionContract canonicalPolicyContract

canonicalBinding :: CandidateBinding -> GatePass -> Bool
canonicalBinding candidate result =
  all singleLine fields
    && Text.length (candidatePhase candidate) == 2
    && Text.all isDigit (candidatePhase candidate)
    && candidatePhase candidate <= canonicalUpperPhaseText
    && all sha256Text digests
    && predecessorText (candidatePredecessorDigest candidate)
    && predecessorText (passPredecessorDigest result)
 where
  fields =
    [ candidatePhase candidate
    , candidateSourceDigest candidate
    , candidateContractDigest candidate
    , candidateHarnessDigest candidate
    , candidateEvidenceDigest candidate
    , candidatePredecessorDigest candidate
    , candidateProjectionDigest candidate
    , passPhase result
    , passSourceDigest result
    , passContractDigest result
    , passHarnessDigest result
    , passEvidenceDigest result
    , passPredecessorDigest result
    , passProjectionDigest result
    ]
      <> Set.toList (candidateStatusFields candidate)
      <> Set.toList (passStatusFields result)
      <> Set.toList (passRows result)
  digests =
    [ candidateSourceDigest candidate
    , candidateContractDigest candidate
    , candidateHarnessDigest candidate
    , candidateEvidenceDigest candidate
    , candidateProjectionDigest candidate
    , passSourceDigest result
    , passContractDigest result
    , passHarnessDigest result
    , passEvidenceDigest result
    , passProjectionDigest result
    ]
  singleLine value = not (Text.null value) && not (Text.any (`elem` ['\r', '\n', '\0']) value)
  isDigit character = character >= '0' && character <= '9'
  predecessorText value = value == "genesis" || sha256Text value

sha256Text :: Text -> Bool
sha256Text value =
  Text.length value == 64
    && Text.all
      (\character -> (character >= '0' && character <= '9') || (character >= 'a' && character <= 'f'))
      value

canonicalUpperPhaseText :: Text
canonicalUpperPhaseText =
  let upper = phaseOrdinalNumber (phaseDomainUpper (orderingContract canonicalPolicyContract))
   in Text.justifyRight 2 '0' (Text.pack (show upper))
