{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Dsl.GadtDecode
import Control.Monad (forM_, unless)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import GadtDecodeOracle
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import System.FilePath ((</>))

main :: IO ()
main = do
  output <- maybe (die "AMOEBIUS_GADT_DECODE_OUTPUT is required") pure =<< lookupEnv "AMOEBIUS_GADT_DECODE_OUTPUT"
  createDirectoryIfMissing True output
  assertEqual "case census" 17 (length expectedCases)
  assertEqual "protocol declarations" expectedProtocolRows (map protocolRow protocolDeclarations)
  TextIO.writeFile (output </> "PulsarApi.proto") renderProtocol
  TextIO.writeFile (output </> "inventory.tsv") inventory
  forM_ expectedCases $ \entry -> do
    let path = output </> Text.unpack (oracleName entry) <> ".dhall"
    TextIO.writeFile path (oracleSource entry <> "\n")
    result <- decodeWorldFile path
    case (oracleExpected entry, result) of
      (Right controller, Right decoded) ->
        assert (controller `Text.isInfixOf` Text.pack (show (decodedExecution decoded))) (Text.unpack (oracleName entry) <> ": positive controller mismatch")
      (Left expected, Left actual) ->
        assertEqual (Text.unpack (oracleName entry)) expected (failureTag actual)
      (Right _, Left actual) -> die (Text.unpack (oracleName entry) <> ": positive rejected: " <> show actual)
      (Left expected, Right _) -> die (Text.unpack (oracleName entry) <> ": negative admitted at " <> Text.unpack expected)
  putStrLn "gadt-decode-spec: PASS (5 positives, 12 paired negatives, 3 Haskell protocol messages, 19 generated products)"

protocolRow :: ProtocolMessage -> (Text, [(Text, Integer)])
protocolRow message =
  ( protocolMessageName message
  , [(protocolFieldName field, fromIntegral (protocolFieldNumber field)) | field <- protocolMessageFields message]
  )

inventory :: Text
inventory = Text.unlines ("case\texpectation" : [oracleName entry <> "\t" <> either id id (oracleExpected entry) | entry <- expectedCases])

failureTag :: DecodeFailure -> Text
failureTag failure = case failure of
  ForbiddenImport _ -> "ForbiddenImport"
  DhallFailure _ -> "DhallFailure"
  UnknownSurface _ -> "UnknownSurface"
  UnknownController _ -> "UnknownController"
  UnknownResourceArm _ -> "UnknownResourceArm"
  EmptyExecutionId -> "EmptyExecutionId"
  ZeroRevision -> "ZeroRevision"
  TenantMismatch _ _ -> "TenantMismatch"
  PlaintextSecret -> "PlaintextSecret"
  UnknownSecretRef _ -> "UnknownSecretRef"
  ResourceArmMismatch _ _ -> "ResourceArmMismatch"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = assert (expected == actual) (label <> ": expected=" <> show expected <> "; actual=" <> show actual)

die :: String -> IO value
die message = putStrLn ("gadt-decode-spec: FAIL: " <> message) >> exitFailure
