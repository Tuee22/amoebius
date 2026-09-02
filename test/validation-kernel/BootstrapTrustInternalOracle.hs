{-# LANGUAGE OverloadedStrings #-}

module BootstrapTrustInternalOracle
  ( runBootstrapTrustInternalOracle
  ) where

-- Direct-source oracle for the package-hidden genesis token. The constructor
-- seam it uses exists only when this component is compiled with
-- VALIDATION_BOOTSTRAP_TRUST_INTERNAL_TEST_HOOKS; packaged callers can acquire
-- a token only by observing the seven exact local input files.

import Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , genesisTrustArchitecture
  , genesisTrustAssumptionLabel
  , genesisTrustCheck
  , genesisTrustCompilerExecutable
  , genesisTrustDigest
  , genesisTrustInternalTestAcquire
  , genesisTrustInternalTestExpectedInputs
  , genesisTrustToolchainIdentity
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding (..)
  , Observation (..)
  )
import Control.Monad (unless)
import Data.Char (isHexDigit)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text

runBootstrapTrustInternalOracle :: IO ()
runBootstrapTrustInternalOracle =
  finishDiagnostics
    "BootstrapTrustInternalOracle"
    ( pinProblems
        <> validProblems
        <> canonicalOrderProblems
        <> environmentRefusalProblems
        <> inputRefusalProblems
    )

pinProblems :: [String]
pinProblems =
  expectEqual
    "the independently authored seven-file pin set"
    expectedInputs
    genesisTrustInternalTestExpectedInputs

validProblems :: [String]
validProblems = case validAttempt of
  Left problems -> ["the exact genesis facts refused: " <> show problems]
  Right trust ->
    expectEqual "the trust check is closed" [] (checkFindings (genesisTrustCheck trust))
      <> expectEqual
        "the trust check observations are exact"
        (expectedObservations trust)
        (checkObservations (genesisTrustCheck trust))
      <> expectEqual
        "the assumption label names only genesis and local custody"
        "GenesisAssumption/local-custody"
        (genesisTrustAssumptionLabel trust)
      <> expectEqual "the architecture projection" "x86_64" (genesisTrustArchitecture trust)
      <> expectEqual "the compiler executable projection" compilerExecutable (genesisTrustCompilerExecutable trust)
      <> expectEqual
        "the toolchain identity golden"
        expectedToolchainIdentity
        (genesisTrustToolchainIdentity trust)
      <> expectEqual
        "the assumption digest golden"
        expectedAssumptionDigest
        (genesisTrustDigest trust)
      <> ["the toolchain identity is not lowercase SHA-256" | not (lowerSha256 (genesisTrustToolchainIdentity trust))]
      <> ["the assumption digest is not lowercase SHA-256" | not (lowerSha256 (genesisTrustDigest trust))]
      <> prohibitedClaimProblems trust

canonicalOrderProblems :: [String]
canonicalOrderProblems = case (validAttempt, validAttemptWith (reverse expectedInputs)) of
  (Right canonical, Right reversed) ->
    expectEqual
      "input enumeration order cannot change the assumption digest"
      (genesisTrustDigest canonical)
      (genesisTrustDigest reversed)
  (Left problems, _) -> ["the canonical order control refused: " <> show problems]
  (_, Left problems) -> ["the reverse order control refused: " <> show problems]

environmentRefusalProblems :: [String]
environmentRefusalProblems =
  concat
    [ expectLeftCodes
        "a different compiler version refuses"
        ["GENESIS-TRUST-COMPILER-VERSION"]
        (testAcquire "9.12.3" compilerExecutable compilerLibdir "linux" "x86_64" expectedInputs)
    , expectLeftCodes
        "a relative compiler executable refuses"
        ["GENESIS-TRUST-COMPILER-EXECUTABLE"]
        (testAcquire "9.12.4" "relative/ghc" compilerLibdir "linux" "x86_64" expectedInputs)
    , expectLeftCodes
        "a relative compiler libdir refuses"
        ["GENESIS-TRUST-COMPILER-LIBDIR"]
        (testAcquire "9.12.4" compilerExecutable "relative/libdir" "linux" "x86_64" expectedInputs)
    , expectLeftCodes
        "a different operating system refuses"
        ["GENESIS-TRUST-OPERATING-SYSTEM"]
        (testAcquire "9.12.4" compilerExecutable compilerLibdir "darwin" "x86_64" expectedInputs)
    , expectLeftCodes
        "a different architecture refuses"
        ["GENESIS-TRUST-ARCHITECTURE"]
        (testAcquire "9.12.4" compilerExecutable compilerLibdir "linux" "aarch64" expectedInputs)
    ]

inputRefusalProblems :: [String]
inputRefusalProblems =
  concat
    [ expectLeftCodes
        "a missing pin refuses"
        ["GENESIS-TRUST-INPUT-INVENTORY"]
        (validAttemptWith (dropFirst expectedInputs))
    , expectLeftCodes
        "a duplicate pin refuses"
        ["GENESIS-TRUST-INPUT-INVENTORY"]
        (validAttemptWith (duplicateFirst expectedInputs))
    , expectLeftCodes
        "a changed byte count refuses"
        ["GENESIS-TRUST-INPUT-SIZE"]
        (validAttemptWith (mapFirstInput changeSize expectedInputs))
    , expectLeftCodes
        "a changed digest refuses"
        ["GENESIS-TRUST-INPUT-DIGEST"]
        (validAttemptWith (mapFirstInput changeDigest expectedInputs))
    , expectLeftCodes
        "an absolute replacement path refuses both inventory and path admission"
        ["GENESIS-TRUST-INPUT-INVENTORY", "GENESIS-TRUST-INPUT-PATH"]
        (validAttemptWith (mapFirstInput changePath expectedInputs))
    ]
 where
  changeSize (path, size, digest) = (path, size + 1, digest)
  changeDigest (path, size, _) = (path, size, Text.replicate 64 "0")
  changePath (_, size, digest) = ("/outside/bootstrap-input", size, digest)

validAttempt :: Either [Finding] GenesisTrust
validAttempt = validAttemptWith expectedInputs

validAttemptWith :: [(FilePath, Integer, Text)] -> Either [Finding] GenesisTrust
validAttemptWith =
  testAcquire "9.12.4" compilerExecutable compilerLibdir "linux" "x86_64"

testAcquire
  :: Text
  -> FilePath
  -> FilePath
  -> Text
  -> Text
  -> [(FilePath, Integer, Text)]
  -> Either [Finding] GenesisTrust
testAcquire = genesisTrustInternalTestAcquire

compilerExecutable, compilerLibdir :: FilePath
compilerExecutable = "/toolchain/bin/ghc"
compilerLibdir = "/toolchain/lib/ghc-9.12.4"

expectedToolchainIdentity, expectedAssumptionDigest :: Text
expectedToolchainIdentity = "f9450d2824cdfce0d10989cc9332bc96532c5aff9d71d4647118e5ef9e98a257"
expectedAssumptionDigest = "024ab3914435631802d221f0aeb08e2822fb06a2fcc5f387757b19c8f5c4366f"

expectedInputs :: [(FilePath, Integer, Text)]
expectedInputs =
  [ ( ".build/bootstrap-inputs/ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz"
    , 302637420
    , "4da657809c06c1658ae5713911fcb168a32093e239f61fe77be78aba74132cfa"
    )
  , ( ".build/bootstrap-inputs/ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz.sig"
    , 438
    , "a5c8828b3c1c53cfc8d5e4459de0790efa5a8dea96cc16dd564382f005280cc5"
    )
  , ( ".build/bootstrap-inputs/ghc-SHA256SUMS"
    , 6585
    , "67869bc776c7f0ffe76226a689c234b367b2194aececbb53da2275892040053b"
    )
  , ( ".build/bootstrap-inputs/ghc-SHA256SUMS.sig"
    , 438
    , "9db94ced16b87713e89a41c408bf5efcb29462971c2494fbfec7e05a33de6bad"
    )
  , ( ".build/bootstrap-inputs/cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz"
    , 5288744
    , "9d68bd17d4aa87e93eea3f667d3edf41ab1cb2b5194bf1745da9dee678426c17"
    )
  , ( ".build/bootstrap-inputs/cabal-SHA256SUMS"
    , 2799
    , "19ef5e11a70d6d06ae23a2b4cae6b52bcf19575be7343fc9dfcce4104bce8bb3"
    )
  , ( ".build/bootstrap-inputs/cabal-SHA256SUMS.sig"
    , 95
    , "59fa7dbebd873bd1714f440111fe1607148d25afd23450e4c5ee9afdc38c4eb3"
    )
  ]

expectedObservations :: GenesisTrust -> [Observation]
expectedObservations trust =
  [ Observation "genesis-trust.assumption" "GenesisAssumption/local-custody"
  , Observation "genesis-trust.compiler-version" "9.12.4"
  , Observation "genesis-trust.compiler-executable" (Text.pack compilerExecutable)
  , Observation "genesis-trust.compiler-libdir" (Text.pack compilerLibdir)
  , Observation "genesis-trust.operating-system" "linux"
  , Observation "genesis-trust.architecture" "x86_64"
  , Observation "genesis-trust.input-count" "7"
  , Observation "genesis-trust.toolchain-identity-sha256" (genesisTrustToolchainIdentity trust)
  , Observation "genesis-trust.assumption-sha256" (genesisTrustDigest trust)
  ]

prohibitedClaimProblems :: GenesisTrust -> [String]
prohibitedClaimProblems trust =
  [ "the trust projection used a broader toolchain claim: " <> Text.unpack rendered
  | forbidden <- ["authenticated", "reproducible"]
  , forbidden `Text.isInfixOf` Text.toLower rendered
  ]
 where
  rendered =
    Text.intercalate
      "\n"
      [ key <> "=" <> value
      | Observation key value <- checkObservations (genesisTrustCheck trust)
      ]

expectLeftCodes
  :: String
  -> [Text]
  -> Either [Finding] GenesisTrust
  -> [String]
expectLeftCodes label expected attempt = case attempt of
  Left findings -> expectEqual label (sort expected) (sort (map findingCode findings))
  Right trust -> [label <> ": unexpectedly minted " <> Text.unpack (genesisTrustDigest trust)]

lowerSha256 :: Text -> Bool
lowerSha256 value =
  Text.length value == 64
    && Text.all (\character -> isHexDigit character && not (character >= 'A' && character <= 'F')) value

dropFirst :: [value] -> [value]
dropFirst values = case values of
  [] -> []
  _ : remaining -> remaining

duplicateFirst :: [value] -> [value]
duplicateFirst values = case values of
  [] -> []
  first : remaining -> first : first : remaining

mapFirstInput
  :: ((FilePath, Integer, Text) -> (FilePath, Integer, Text))
  -> [(FilePath, Integer, Text)]
  -> [(FilePath, Integer, Text)]
mapFirstInput transform values = case values of
  [] -> []
  first : remaining -> transform first : remaining

expectEqual :: (Eq value, Show value) => String -> value -> value -> [String]
expectEqual label expected observed =
  [ label <> ": expected " <> show expected <> ", observed " <> show observed
  | expected /= observed
  ]

finishDiagnostics :: String -> [String] -> IO ()
finishDiagnostics name problems =
  unless
    (null problems)
    ( fail
        ( unlines
            ( (name <> " reported " <> show (length problems) <> " problem(s):")
                : map ("  " <>) problems
            )
        )
    )
