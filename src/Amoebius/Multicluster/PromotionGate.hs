{-# LANGUAGE CPP #-}

module Amoebius.Multicluster.PromotionGate
  ( PromotionEvidence (..)
  , PromotionAuthorization (..)
  , PromotionError (..)
  , authorizePromotion
  ) where

data PromotionEvidence = PromotionEvidence
  { hasFreshnessWitness :: Bool
  , holdsFence :: Bool
  , observedLagSeconds :: Int
  , lagBoundSeconds :: Int
  }
  deriving stock (Eq, Show)

data PromotionAuthorization = PromotionAuthorized
  deriving stock (Eq, Show)

data PromotionError
  = PromotionFreshnessUnproven
  | PromotionLagBoundExceeded Int Int
  deriving stock (Eq, Show)

authorizePromotion :: PromotionEvidence -> Either PromotionError PromotionAuthorization
authorizePromotion evidence
  | observedLagSeconds evidence > lagBoundSeconds evidence =
      Left (PromotionLagBoundExceeded (observedLagSeconds evidence) (lagBoundSeconds evidence))
#ifdef PHASE43_PROMOTE_BEFORE_FENCE_MUTANT
  | not (hasFreshnessWitness evidence || holdsFence evidence) = Right PromotionAuthorized
  | otherwise = Left PromotionFreshnessUnproven
#else
  | hasFreshnessWitness evidence || holdsFence evidence = Right PromotionAuthorized
  | otherwise = Left PromotionFreshnessUnproven
#endif
