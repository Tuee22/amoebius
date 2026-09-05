{-# LANGUAGE CPP #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Compiler.CompileFailHarness
  ( Pair (..)
  , Diagnostic (..)
  , validateTwinSources
  , parseDiagnostics
  , validateNegative
  , positiveCounterpartRequired
  ) where

import Data.Aeson (FromJSON, eitherDecodeStrict')
import Data.ByteString.Char8 qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import Prelude hiding (span)
import System.Exit (ExitCode (..))

data Pair = Pair
  { pairClaim :: Text
  , pairOwnerPhase :: Int
  , pairLegal :: FilePath
  , pairIllegal :: FilePath
  , pairDimension :: Text
  , pairCode :: Int
  , pairLine :: Int
  , pairColumn :: Int
  , pairMessageFragments :: [Text]
  , pairLegalProbe :: Text
  , pairIllegalProbe :: Text
  }
  deriving (Eq, Show)

data Position = Position
  { line :: Int
  , column :: Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON Position

data Span = Span
  { start :: Position
  }
  deriving (Eq, Show, Generic)

instance FromJSON Span

data Diagnostic = Diagnostic
  { severity :: Text
  , code :: Int
  , span :: Span
  , message :: [Text]
  }
  deriving (Eq, Show, Generic)

instance FromJSON Diagnostic

validateTwinSources :: Pair -> Text -> Text -> Either Text ()
validateTwinSources pair legalSource illegalSource
  | Text.null (Text.strip (pairClaim pair)) = Left "claim is empty"
  | Text.null (Text.strip (pairDimension pair)) = Left (at "dimension is empty")
  | null (pairMessageFragments pair) = Left (at "diagnostic message fragments are empty")
  | pairLegalProbe pair `Text.isInfixOf` legalSource
      && not (pairLegalProbe pair `Text.isInfixOf` illegalSource)
      && pairIllegalProbe pair `Text.isInfixOf` illegalSource
      && not (pairIllegalProbe pair `Text.isInfixOf` legalSource) = Right ()
  | otherwise = Left (at "legal and illegal probes do not isolate the named dimension")
 where
  at detail = pairClaim pair <> ": " <> detail

parseDiagnostics :: Text -> [Diagnostic]
parseDiagnostics = foldr parseLine [] . Text.lines
 where
  parseLine source found =
    case eitherDecodeStrict' (ByteString.pack (Text.unpack source)) of
      Right diagnostic | severity diagnostic == "Error" -> diagnostic : found
      _ -> found

validateNegative :: Pair -> ExitCode -> Text -> Either Text Int
validateNegative pair status compilerOutput
  | status == ExitSuccess = Left (at "illegal fixture compiled")
  | null errors = Left (at "illegal fixture emitted no structured error")
#ifdef COMPILE_FAIL_ACCEPT_ANY_FAILURE_MUTANT
  | otherwise = Right (length errors)
#else
  | any unrelated errors = Left (at "illegal fixture failed for an unrelated compiler reason")
#ifdef COMPILE_FAIL_IMPOSSIBLE_PIN_MUTANT
  | otherwise = Right (length errors)
#else
  | distinctCodes /= [pairCode pair] = Left (at ("diagnostic codes " <> Text.pack (show distinctCodes) <> " do not equal the authored singleton"))
  | length pinned /= 1 = Left (at ("expected exactly one diagnostic at " <> Text.pack (show (pairLine pair, pairColumn pair))))
  | not (all (`Text.isInfixOf` pinnedMessage) (pairMessageFragments pair)) = Left (at "pinned diagnostic lacks an authored message fragment")
  | otherwise = Right (length errors)
#endif
#endif
 where
  errors = parseDiagnostics compilerOutput
  distinctCodes = uniqueSorted (map code errors)
  pinned =
    [ diagnostic
    | diagnostic <- errors
    , code diagnostic == pairCode pair
    , line (start (span diagnostic)) == pairLine pair
    , column (start (span diagnostic)) == pairColumn pair
    ]
  pinnedMessage = Text.intercalate "\n" (concatMap message pinned)
  unrelated diagnostic = any (`Text.isInfixOf` pinnedText diagnostic) forbiddenMessages
  pinnedText = Text.intercalate "\n" . message
  at detail = pairClaim pair <> ": " <> detail

positiveCounterpartRequired :: Bool
#ifdef COMPILE_FAIL_DROPS_POSITIVE_COUNTERPART_MUTANT
positiveCounterpartRequired = False
#else
positiveCounterpartRequired = True
#endif

forbiddenMessages :: [Text]
forbiddenMessages = ["Could not find module", "Variable not in scope", "parse error"]

uniqueSorted :: Ord value => [value] -> [value]
uniqueSorted = foldr insert []
 where
  insert value [] = [value]
  insert value values@(first : rest)
    | value < first = value : values
    | value == first = values
    | otherwise = first : insert value rest
