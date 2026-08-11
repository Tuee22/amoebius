{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module CorpusSpec
  ( CorpusSummary (..)
  , CoverageKey
  , runCorpusSpec
  ) where

import Amoebius.Dsl.Cbor (decodeCbor)
import Amoebius.Dsl.Decode (decodeCluster)
import Amoebius.Dsl.Error (decodeErrorTag)
import Amoebius.Dsl.Types (ClusterIR (clusterExecutions), executionResourceNodes)
import Control.Monad (forM_, unless)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAlphaNum)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Exit (ExitCode (ExitSuccess))
import System.Process (proc, readCreateProcessWithExitCode)

type CoverageKey = (Text, Text, Text)

data CorpusSummary = CorpusSummary
  { gate1Count :: Int
  , gate2Count :: Int
  , positiveCount :: Int
  , coveredKeys :: Set CoverageKey
  }

dhall :: FilePath
dhall = "/home/matthewnowak/.local/bin/dhall"

runCorpusSpec :: IO CorpusSummary
runCorpusSpec = do
  gate1Rows <- rowsOf "tests/oracle/phase6/gate1_cases.tsv"
  gate2Rows <- rowsOf "tests/oracle/phase6/gate2_cases.tsv"
  gate1Keys <- traverse checkGate1 gate1Rows
  gate2Keys <- traverse checkGate2 gate2Rows
  forM_ positiveFixtures requireDecoded
  checkMalformedCbor
  let cborKey = ("3.23", "consume-codec", "Gate-2-decoder")
  pure
    CorpusSummary
      { gate1Count = length gate1Rows
      , gate2Count = length gate2Rows + 1
      , positiveCount = length positiveFixtures
      , coveredKeys = Set.fromList (gate1Keys <> gate2Keys <> [cborKey])
      }

checkGate1 :: [Text] -> IO CoverageKey
checkGate1 columns = case columns of
  [entry, subcase, negative, legal, golden, required] -> do
    requireDhallTyped legal
    (exitCode, _, stderr) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack negative, "--quiet"]) ""
    assert (exitCode /= ExitSuccess) (Text.unpack negative <> " unexpectedly passed Gate 1")
    let cleaned = stripAnsi (Text.pack stderr)
    assert (required `Text.isInfixOf` cleaned) (Text.unpack negative <> " failed at the wrong Gate-1 locus")
    expected <- Text.readFile (Text.unpack golden)
    let actual = normalizeDhallError cleaned
    assert (actual == expected) (Text.unpack negative <> " Gate-1 error diverged from " <> Text.unpack golden)
    pure (entry, subcase, "Gate-1-editor")
  _ -> failTest "malformed Gate-1 corpus row"

checkGate2 :: [Text] -> IO CoverageKey
checkGate2 columns = case columns of
  [entry, subcase, negative, legal, golden] -> do
    requireDhallTyped negative
    requireDhallTyped legal
    requireDecoded legal
    expected <- Text.strip <$> Text.readFile (Text.unpack golden)
    decoded <- decodeCluster (Text.unpack negative)
    case decoded of
      Right _ -> failTest (Text.unpack negative <> " crossed Gate 2")
      Left problem ->
        assert
          (decodeErrorTag problem == expected)
          (Text.unpack negative <> " returned " <> Text.unpack (decodeErrorTag problem) <> ", expected " <> Text.unpack expected)
    pure (entry, subcase, "Gate-2-decoder")
  _ -> failTest "malformed Gate-2 corpus row"

checkMalformedCbor :: IO ()
checkMalformedCbor = case decodeCbor @Int (LazyByteString.pack [0xff]) of
  Left problem -> do
    expected <- Text.strip <$> Text.readFile "test/dsl/goldens/consume-codec.tag"
    assert (decodeErrorTag problem == expected) "malformed CBOR returned the wrong DecodeError tag"
  Right _ -> failTest "malformed CBOR decoded"

requireDhallTyped :: Text -> IO ()
requireDhallTyped fixture = do
  (exitCode, _, stderr) <- readCreateProcessWithExitCode (proc dhall ["type", "--file", Text.unpack fixture, "--quiet"]) ""
  assert (exitCode == ExitSuccess) (Text.unpack fixture <> " did not type-check:\n" <> stderr)

requireDecoded :: Text -> IO ()
requireDecoded fixture = do
  result <- decodeCluster (Text.unpack fixture)
  case result of
    Left problem -> failTest (Text.unpack fixture <> " unexpectedly decode-rejected: " <> show problem)
    Right ir ->
      assert
        (all ((> 10) . length . executionResourceNodes) (clusterExecutions ir))
        (Text.unpack fixture <> " resource normalization dropped execution fields")

positiveFixtures :: [Text]
positiveFixtures =
  [ "dhall/examples/legal_multisubstrate_cluster.dhall"
  , "dhall/examples/legal_managed_eks.dhall"
  , "dhall/examples/trivial_app.dhall"
  , "dhall/examples/legal_deployment_rules.dhall"
  , "dhall/examples/legal_rollout_surge.dhall"
  , "dhall/examples/legal_rollout_unavailable.dhall"
  , "dhall/examples/legal_controller_deployment.dhall"
  , "dhall/examples/legal_controller_statefulset.dhall"
  , "dhall/examples/legal_controller_daemonset.dhall"
  , "dhall/examples/legal_controller_job.dhall"
  , "dhall/examples/legal_controller_hostprocess.dhall"
  , "dhall/examples/legal_controller_metal_hostprocess.dhall"
  ]

rowsOf :: FilePath -> IO [[Text]]
rowsOf path = do
  contents <- Text.readFile path
  pure [Text.splitOn "\t" line | line <- drop 1 (Text.lines contents), not (Text.null line)]

normalizeDhallError :: Text -> Text
normalizeDhallError cleaned = Text.unlines (errorLine <> signedTokens)
 where
  compactLines = fmap (Text.unwords . Text.words) (Text.lines cleaned)
  errorLine = take 1 [line | line <- compactLines, "Error:" `Text.isPrefixOf` line]
  signedTokens = concatMap tokens compactLines
  tokens line =
    [ sign <> " " <> Text.takeWhile isToken name
    | (sign, name) <- zip wordsList (drop 1 wordsList)
    , sign `elem` ["+", "-"]
    , not (Text.null (Text.takeWhile isToken name))
    ]
   where
    wordsList = Text.words line
  isToken character = isAlphaNum character

stripAnsi :: Text -> Text
stripAnsi value = case Text.breakOn "\ESC[" value of
  (before, rest)
    | Text.null rest -> before
    | otherwise -> before <> stripAnsi (Text.drop 1 (Text.dropWhile (/= 'm') rest))

assert :: Bool -> String -> IO ()
assert condition message = unless condition (failTest message)

failTest :: String -> IO value
failTest message = ioError (userError message)
