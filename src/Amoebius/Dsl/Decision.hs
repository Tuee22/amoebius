{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Dsl.Decision
  ( DecisionFragment
  , fragmentResources
  , fragmentServices
  , fragmentSubstrates
  , mkDecisionFragment
  , encodeDecision
  , decodeDecision
  , composeDecisionFragments
  , foldResourceTotal
  , distinctHostIds
  , Rke2Servers (..)
  , allRke2Servers
  , rke2ServerCount
  ) where

import Control.DeepSeq (NFData)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Numeric.Natural (Natural)
import Text.Read (readMaybe)

data DecisionFragment = DecisionFragment
  { fragmentSubstrates :: [Text]
  , fragmentServices :: [Text]
  , fragmentResources :: [Natural]
  }
  deriving stock (Eq, Generic, Read, Show)
  deriving anyclass (NFData)

mkDecisionFragment :: [Text] -> [Text] -> [Natural] -> Either Text DecisionFragment
mkDecisionFragment substrates services resources
  | null substrates = Left "fragment.substrates.NonEmpty"
  | null services = Left "fragment.services.NonEmpty"
  | not (unique substrates) = Left "fragment.substrates.Unique"
  | not (unique services) = Left "fragment.services.Unique"
  | otherwise = Right (DecisionFragment substrates services resources)

encodeDecision :: DecisionFragment -> Text
#ifdef PHASE6_MUTANT
encodeDecision fragment = Text.pack (show fragment {fragmentServices = []})
#else
encodeDecision = Text.pack . show
#endif

decodeDecision :: Text -> Either Text DecisionFragment
decodeDecision encoded = case readMaybe (Text.unpack encoded) of
  Nothing -> Left "fragment.decode"
  Just fragment -> mkDecisionFragment (fragmentSubstrates fragment) (fragmentServices fragment) (fragmentResources fragment)

composeDecisionFragments :: DecisionFragment -> DecisionFragment -> Either Text DecisionFragment
#ifdef PHASE6_MUTANT
composeDecisionFragments _ _ = Left "mutant.dropped-composition"
#else
composeDecisionFragments left right =
  mkDecisionFragment
    (fragmentSubstrates left <> fragmentSubstrates right)
    (fragmentServices left <> fragmentServices right)
    (fragmentResources left <> fragmentResources right)
#endif

foldResourceTotal :: [Natural] -> Natural
#ifdef PHASE6_MUTANT
foldResourceTotal [] = 1
foldResourceTotal values = foldl' (+) 0 values
#else
foldResourceTotal = foldl' (+) 0
#endif

distinctHostIds :: [Text] -> Either Text [Text]
distinctHostIds hosts
  | unique hosts = Right hosts
  | otherwise = Left "cluster.rke2.distinctHostIds"

data Rke2Servers = Rke2One | Rke2Three | Rke2Five
  deriving stock (Bounded, Enum, Eq, Generic, Ord, Read, Show)
  deriving anyclass (NFData)

allRke2Servers :: [Rke2Servers]
allRke2Servers = [minBound .. maxBound]

rke2ServerCount :: Rke2Servers -> Natural
rke2ServerCount servers = case servers of
  Rke2One -> 1
  Rke2Three -> 3
  Rke2Five -> 5

unique :: Ord value => [value] -> Bool
unique values = length values == Set.size (Set.fromList values)
