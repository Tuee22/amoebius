{-# LANGUAGE CPP #-}

module Amoebius.Release.PromotionGate
  ( PromotionRefusal (..)
  , Advance
  , advanceEnvironment
  , requiredEvidence
  , preparePromotion
  ) where

import Amoebius.Release.Environment
import Amoebius.Release.EvidenceWitness

data PromotionRefusal
  = PromotionRefusedDecisionEvidenceMissing
  | PromotionRefusedProtocolEvidenceMissing
  | PromotionRefusedRuntimeEvidenceMissing
  deriving stock (Eq, Show)

data Advance = Advance Environment EvidenceWitness

advanceEnvironment :: Advance -> Environment
advanceEnvironment (Advance environment _) = environment

requiredEvidence :: Environment -> EvidenceLayer
requiredEvidence Dev = Decision
requiredEvidence Staging = Protocol
requiredEvidence Prod = Runtime

preparePromotion :: Environment -> EvidenceLedger -> Either PromotionRefusal Advance
preparePromotion environment ledger =
#ifdef RELEASE_LIFECYCLE_GATE_ADMITS_UNVERIFIED_MUTANT
  Right (Advance environment (mutantWitness required))
#else
  case witnessFor required ledger of
    Just witness -> Right (Advance environment witness)
    Nothing -> Left (refusal required)
#endif
 where
  required = requiredEvidence environment
  refusal Decision = PromotionRefusedDecisionEvidenceMissing
  refusal Protocol = PromotionRefusedProtocolEvidenceMissing
  refusal Runtime = PromotionRefusedRuntimeEvidenceMissing
#ifdef RELEASE_LIFECYCLE_GATE_ADMITS_UNVERIFIED_MUTANT
  mutantWitness layer = case witnessFor layer (evidenceLedger [(layer, Tested)]) of
    Just witness -> witness
    Nothing -> error "release-lifecycle-mutant-witness-invariant"
#endif
