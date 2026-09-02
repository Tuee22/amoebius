-- | The deliberately small production predicate qualified by the Phase-0
-- bootstrap harness.
--
-- This module depends only on @base@ so the harness can compile an exact
-- source copy directly with the genesis compiler.  Its three decisions are
-- the complete mutation surface of the finite seed; broader source,
-- toolchain, and self-reference claims belong to their numbered owners.
module Amoebius.Validation.BootstrapPredicate
  ( bootstrapDigestMatches
  , bootstrapSnapshotMatches
  , bootstrapInputPathAllowed
  ) where

import Data.Char (isHexDigit)
import Data.List (isPrefixOf)

-- Keep each decision on one stable line. BootstrapQualification.Internal
-- replaces exactly one complete line in an acquired source copy and refuses
-- if the expected line is absent or duplicated.
bootstrapDigestMatches :: String -> String -> Bool
bootstrapDigestMatches actual expected = validLowerSha256 actual && actual == expected

bootstrapSnapshotMatches :: String -> String -> Bool
bootstrapSnapshotMatches opening closing = validLowerSha256 opening && opening == closing

bootstrapInputPathAllowed :: FilePath -> Bool
bootstrapInputPathAllowed path = ".build/bootstrap-inputs/" `isPrefixOf` path && boundedRelativePath path

validLowerSha256 :: String -> Bool
validLowerSha256 value =
  length value == 64
    && all (\character -> isHexDigit character && not (isLetterUpper character)) value
 where
  isLetterUpper character = character >= 'A' && character <= 'F'

boundedRelativePath :: FilePath -> Bool
boundedRelativePath path =
  not (null path)
    && length path <= 256
    && not ("/" `isPrefixOf` path)
    && all validSegment (splitSlash path)
 where
  validSegment segment =
    not (null segment)
      && segment /= "."
      && segment /= ".."
      && length segment <= 128
      && all validPathCharacter segment
  validPathCharacter character =
    (character >= 'a' && character <= 'z')
      || (character >= 'A' && character <= 'Z')
      || (character >= '0' && character <= '9')
      || character `elem` ("-_." :: String)

splitSlash :: String -> [String]
splitSlash value = case break (== '/') value of
  (segment, []) -> [segment]
  (segment, _ : remaining) -> segment : splitSlash remaining
