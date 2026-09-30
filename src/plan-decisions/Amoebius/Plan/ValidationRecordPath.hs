{-# LANGUAGE OverloadedStrings #-}

-- | The two admitted tracked validation-evidence path shapes: immutable
-- acceptance bundles and replay-void records. These classify paths only;
-- custody checks their bytes and provenance.
module Amoebius.Plan.ValidationRecordPath
  ( ValidationRecordFile (..)
  , ValidationRecordPath (..)
  , ValidationVoidPath (..)
  , isValidationRecordPath
  , parseValidationRecordPath
  , parseValidationVoidPath
  , validationRecordRoot
  ) where

import Amoebius.Plan.PhaseIdentity (lookupPhaseIdentity)
import Data.Maybe (isJust)
import Data.Text (Text)
import Data.Text qualified as Text

validationRecordRoot :: FilePath
validationRecordRoot = "validation-records"

data ValidationRecordFile
  = ReceiptFile
  | ReceiptHashFile
  | CandidateFile
  | KillTableFile
  | OutcomeFile
  | OracleLedgerFile
  | ObserverFile
  deriving (Eq, Ord, Show)

data ValidationRecordPath = ValidationRecordPath
  { recordGenerationPrefix :: Text
  , recordPhaseOrdinal :: Int
  , recordReproducibleDigest :: Text
  , recordBundleDigest :: Text
  , recordFile :: ValidationRecordFile
  }
  deriving (Eq, Ord, Show)

data ValidationVoidPath = ValidationVoidPath
  { voidGenerationPrefix :: Text
  , voidPhaseOrdinal :: Int
  , voidTargetBundleDigest :: Text
  , voidDigest :: Text
  }
  deriving (Eq, Ord, Show)

-- | Accept only a canonical repository-relative path beneath the evidence root.
-- All hash fields are lower-case hexadecimal; the generation prefix has 16
-- digits and both run digests have 64. The phase must exist in the compiled table.
parseValidationRecordPath :: FilePath -> Maybe ValidationRecordPath
parseValidationRecordPath path = case Text.splitOn "/" (Text.pack path) of
  ["validation-records", generationPart, "receipts", phasePart, filePart] -> do
    generation <- Text.stripPrefix "generation-" generationPart
    if not (hexOfLength 16 generation) then Nothing else do
      (ordinal, digest, bundleDigest) <- parsePhaseAndDigests phasePart
      file <- parseRecordFile filePart
      pure (ValidationRecordPath generation ordinal digest bundleDigest file)
  _ -> Nothing

isValidationRecordPath :: FilePath -> Bool
isValidationRecordPath path =
  isJust (parseValidationRecordPath path) || isJust (parseValidationVoidPath path)

-- | A replay-void record has one exact TSV filename, keyed by its target bundle
-- and by its own digest. It cannot be confused with a seven-file receipt bundle.
parseValidationVoidPath :: FilePath -> Maybe ValidationVoidPath
parseValidationVoidPath path = case Text.splitOn "/" (Text.pack path) of
  ["validation-records", generationPart, "voids", filePart] -> do
    generation <- Text.stripPrefix "generation-" generationPart
    if not (hexOfLength 16 generation) then Nothing else do
      stem <- Text.stripSuffix ".tsv" filePart
      rest <- Text.stripPrefix "phase-" stem
      case Text.splitOn "-" rest of
        [ordinalText, targetBundleDigest, voidRecordDigest]
          | hexOfLength 64 targetBundleDigest
          , hexOfLength 64 voidRecordDigest -> do
              ordinal <- readKnownOrdinal ordinalText
              pure (ValidationVoidPath generation ordinal targetBundleDigest voidRecordDigest)
        _ -> Nothing
  _ -> Nothing

parsePhaseAndDigests :: Text -> Maybe (Int, Text, Text)
parsePhaseAndDigests segment = do
  rest <- Text.stripPrefix "phase-" segment
  case Text.splitOn "-" rest of
    [ordinalText, digest, bundleDigest]
      | hexOfLength 64 digest
      , hexOfLength 64 bundleDigest -> do
          ordinal <- readKnownOrdinal ordinalText
          Just (ordinal, digest, bundleDigest)
    _ -> Nothing

readKnownOrdinal :: Text -> Maybe Int
readKnownOrdinal rendered
  | Text.length rendered /= 2 || not (Text.all asciiDigit rendered) = Nothing
  | otherwise = do
      ordinal <- readOrdinal rendered
      if isJust (lookupPhaseIdentity ordinal) then Just ordinal else Nothing

readOrdinal :: Text -> Maybe Int
readOrdinal rendered = case reads (Text.unpack rendered) of
  [(ordinal, "")] -> Just ordinal
  _ -> Nothing

parseRecordFile :: Text -> Maybe ValidationRecordFile
parseRecordFile file = case file of
  "receipt.tsv" -> Just ReceiptFile
  "receipt.tsv.sha256" -> Just ReceiptHashFile
  "candidate.tsv" -> Just CandidateFile
  "kill-table.tsv" -> Just KillTableFile
  "outcome.tsv" -> Just OutcomeFile
  "oracle-ledger.tsv" -> Just OracleLedgerFile
  "observer.tsv" -> Just ObserverFile
  _ -> Nothing

hexOfLength :: Int -> Text -> Bool
hexOfLength lengthWanted value =
  Text.length value == lengthWanted && Text.all isLowerHex value

isLowerHex :: Char -> Bool
isLowerHex value = asciiDigit value || (value >= 'a' && value <= 'f')

asciiDigit :: Char -> Bool
asciiDigit value = value >= '0' && value <= '9'
