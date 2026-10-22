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
encodeDecision = Text.pack . show

decodeDecision :: Text -> Either Text DecisionFragment
decodeDecision encoded = case readMaybe (Text.unpack encoded) of
  Nothing -> Left "fragment.decode"
  Just fragment -> mkDecisionFragment (fragmentSubstrates fragment) (fragmentServices fragment) (fragmentResources fragment)

composeDecisionFragments :: DecisionFragment -> DecisionFragment -> Either Text DecisionFragment
composeDecisionFragments left right =
  mkDecisionFragment
    (fragmentSubstrates left <> fragmentSubstrates right)
    (fragmentServices left <> fragmentServices right)
    (fragmentResources left <> fragmentResources right)

foldResourceTotal :: [Natural] -> Natural
foldResourceTotal = foldl' (+) 0

distinctHostIds :: [Text] -> Either Text [Text]
distinctHostIds hosts
  | unique hosts = Right hosts
  | otherwise = Left "cluster.rke2.distinctHostIds"

unique :: Ord value => [value] -> Bool
unique values = length values == Set.size (Set.fromList values)
