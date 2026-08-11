module Amoebius.Release.EvidenceWitness
  ( EvidenceLayer (..)
  , EvidenceStrength (..)
  , EvidenceLedger
  , evidenceLedger
  , evidenceStrength
  , EvidenceWitness
  , witnessLayer
  , witnessFor
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map

data EvidenceLayer = Decision | Protocol | Runtime
  deriving stock (Bounded, Enum, Eq, Ord, Read, Show)

data EvidenceStrength = Unverified | Assumed | Tested | Proven
  deriving stock (Bounded, Enum, Eq, Ord, Read, Show)

newtype EvidenceLedger = EvidenceLedger (Map EvidenceLayer EvidenceStrength)
  deriving stock (Eq, Show)

evidenceLedger :: [(EvidenceLayer, EvidenceStrength)] -> EvidenceLedger
evidenceLedger = EvidenceLedger . Map.fromList

evidenceStrength :: EvidenceLedger -> EvidenceLayer -> EvidenceStrength
evidenceStrength (EvidenceLedger values) layer = Map.findWithDefault Unverified layer values

newtype EvidenceWitness = EvidenceWitness EvidenceLayer
  deriving stock (Eq, Show)

witnessLayer :: EvidenceWitness -> EvidenceLayer
witnessLayer (EvidenceWitness layer) = layer

witnessFor :: EvidenceLayer -> EvidenceLedger -> Maybe EvidenceWitness
witnessFor layer ledger
  | evidenceStrength ledger layer >= Tested = Just (EvidenceWitness layer)
  | otherwise = Nothing
