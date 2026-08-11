{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Release.Ledger
  ( Release (..)
  , releaseFromSource
  , ReleaseLedger
  , emptyReleaseLedger
  , LedgerWrite (..)
  , LedgerError (..)
  , writeRelease
  , ledgerEntries
  , AppliedGeneration (..)
  , appendAppliedGeneration
  ) where

import Amoebius.Release.ReleaseHash
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)

data Release = Release
  { releaseHash :: ReleaseHash
  , releaseDeploymentDhallRef :: Text
  , releaseImages :: [Text]
  , releaseSubstrateFp :: Text
  }
  deriving stock (Eq, Show)

releaseFromSource :: Text -> ReleaseSource -> Release
releaseFromSource reference source = Release
  { releaseHash = deriveReleaseHash source
  , releaseDeploymentDhallRef = reference
  , releaseImages = releaseImageDigests source
  , releaseSubstrateFp = releaseSubstrateFingerprint source
  }

data AppliedGeneration = AppliedGeneration
  { appliedReleaseHash :: ReleaseHash
  , appliedObservedGeneration :: Text
  }
  deriving stock (Eq, Show)

data ReleaseLedger = ReleaseLedger
  { ledgerEntries :: Map ReleaseHash Release
  , ledgerApplied :: [AppliedGeneration]
  }
  deriving stock (Eq, Show)

emptyReleaseLedger :: ReleaseLedger
emptyReleaseLedger = ReleaseLedger Map.empty []

data LedgerWrite = LedgerInserted | LedgerDeduplicated
  deriving stock (Eq, Show)

data LedgerError = ImmutableReleaseConflict ReleaseHash
  deriving stock (Eq, Show)

writeRelease :: Release -> ReleaseLedger -> Either LedgerError (ReleaseLedger, LedgerWrite)
writeRelease release ledger = case Map.lookup key (ledgerEntries ledger) of
  Nothing -> Right (ledger {ledgerEntries = Map.insert key release (ledgerEntries ledger)}, LedgerInserted)
  Just existing
    | existing == release -> Right (ledger, LedgerDeduplicated)
    | otherwise -> Left (ImmutableReleaseConflict key)
 where
  key = releaseHash release

appendAppliedGeneration :: AppliedGeneration -> ReleaseLedger -> ReleaseLedger
appendAppliedGeneration applied ledger
  | applied `elem` ledgerApplied ledger = ledger
  | otherwise = ledger {ledgerApplied = ledgerApplied ledger <> [applied]}
