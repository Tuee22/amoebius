{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}

-- | A deliberately narrow trust root for the finite Phase-0 bootstrap.
--
-- A value from this module says only that this process was compiled by the
-- pinned compiler family and observed the exact prepared bytes in local
-- custody.  The signature files below are pinned as bytes; this module does
-- not interpret them or elevate them into publisher identity or rebuild
-- equivalence.  The constructor stays package-hidden so candidate code cannot
-- manufacture the assumption from caller-authored strings.
module Amoebius.Validation.BootstrapTrust.Internal
  ( GenesisTrust
  , acquireGenesisTrust
  , genesisTrustArchitecture
  , genesisTrustAssumptionLabel
  , genesisTrustCheck
  , genesisTrustCompilerExecutable
  , genesisTrustDigest
  , genesisTrustToolchainIdentity
#if defined(VALIDATION_BOOTSTRAP_TRUST_INTERNAL_TEST_HOOKS)
  , genesisTrustInternalTestAcquire
  , genesisTrustInternalTestExpectedInputs
#endif
  ) where

import Amoebius.Validation.BootstrapPredicate (bootstrapInputPathAllowed)
import Amoebius.Validation.Types
  ( CheckResult (..)
  , Finding
  , finding
  , observation
  )
import Control.Exception (IOException, displayException, try)
import Crypto.Hash qualified as Crypto
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteString8
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
#if !defined(__GLASGOW_HASKELL_PATCHLEVEL1__)
import Data.Version (showVersion)
#endif
import GHC.Paths qualified as GHCPaths
import System.Directory
  ( doesFileExist
  , getFileSize
  , makeAbsolute
  , pathIsSymbolicLink
  )
import System.FilePath (isAbsolute, (</>))
import System.Info qualified as SystemInfo
import System.IO (IOMode (ReadMode), withBinaryFile)
import System.IO.Error (isDoesNotExistError)

-- | Opaque evidence for one exact, locally held genesis input set.
data GenesisTrust = GenesisTrust
  { trustEnvironment :: GenesisEnvironment
  , trustInputs :: [ObservedBootstrapInput]
  , trustToolchainIdentityValue :: Text
  , trustDigestValue :: Text
  }
  deriving (Eq, Show)

data GenesisEnvironment = GenesisEnvironment
  { environmentCompilerVersion :: Text
  , environmentCompilerExecutable :: FilePath
  , environmentCompilerLibdir :: FilePath
  , environmentOperatingSystem :: Text
  , environmentArchitecture :: Text
  }
  deriving (Eq, Show)

data BootstrapInputPin = BootstrapInputPin
  { pinPath :: FilePath
  , pinSize :: Integer
  , pinSha256 :: Text
  }
  deriving (Eq, Ord, Show)

data ObservedBootstrapInput = ObservedBootstrapInput
  { observedInputPath :: FilePath
  , observedInputSize :: Integer
  , observedInputSha256 :: Text
  }
  deriving (Eq, Ord, Show)

genesisAssumptionLabel :: Text
genesisAssumptionLabel = "GenesisAssumption/local-custody"

pinnedCompilerVersion :: Text
pinnedCompilerVersion = "9.12.4"

pinnedOperatingSystem, pinnedArchitecture :: Text
pinnedOperatingSystem = "linux"
pinnedArchitecture = "x86_64"

-- These pins are the prepared external bytes audited in the Phase-0 plan.
-- The detached-signature blobs are inputs, not signature-verification
-- results.  Every path is also admitted by the separately qualified small
-- production predicate before it is read.
expectedBootstrapInputs :: [BootstrapInputPin]
expectedBootstrapInputs =
  [ BootstrapInputPin
      ".build/bootstrap-inputs/ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz"
      302637420
      "4da657809c06c1658ae5713911fcb168a32093e239f61fe77be78aba74132cfa"
  , BootstrapInputPin
      ".build/bootstrap-inputs/ghc-9.12.4-x86_64-ubuntu22_04-linux.tar.xz.sig"
      438
      "a5c8828b3c1c53cfc8d5e4459de0790efa5a8dea96cc16dd564382f005280cc5"
  , BootstrapInputPin
      ".build/bootstrap-inputs/ghc-SHA256SUMS"
      6585
      "67869bc776c7f0ffe76226a689c234b367b2194aececbb53da2275892040053b"
  , BootstrapInputPin
      ".build/bootstrap-inputs/ghc-SHA256SUMS.sig"
      438
      "9db94ced16b87713e89a41c408bf5efcb29462971c2494fbfec7e05a33de6bad"
  , BootstrapInputPin
      ".build/bootstrap-inputs/cabal-install-3.16.1.0-x86_64-linux-ubuntu22_04.tar.xz"
      5288744
      "9d68bd17d4aa87e93eea3f667d3edf41ab1cb2b5194bf1745da9dee678426c17"
  , BootstrapInputPin
      ".build/bootstrap-inputs/cabal-SHA256SUMS"
      2799
      "19ef5e11a70d6d06ae23a2b4cae6b52bcf19575be7343fc9dfcce4104bce8bb3"
  , BootstrapInputPin
      ".build/bootstrap-inputs/cabal-SHA256SUMS.sig"
      95
      "59fa7dbebd873bd1714f440111fe1607148d25afd23450e4c5ee9afdc38c4eb3"
  ]

-- | Acquire the local-custody assumption from the exact repository-relative
-- input paths. Missing, replaced, malformed, or unreadable input refuses the
-- acquisition; a partial input set never mints a token.
acquireGenesisTrust :: FilePath -> IO (Either [Finding] GenesisTrust)
acquireGenesisTrust repositoryRoot = do
  absoluteRootAttempt <- try (makeAbsolute repositoryRoot) :: IO (Either IOException FilePath)
  case absoluteRootAttempt of
    Left problem ->
      pure
        ( Left
            [ finding
                "GENESIS-TRUST-ROOT"
                repositoryRoot
                ("cannot resolve the repository root: " <> boundedException problem)
            ]
        )
    Right absoluteRoot -> do
      let environment = currentGenesisEnvironment
      case environmentFindings environment of
        problems@(_ : _) -> pure (Left problems)
        [] -> do
          attempts <- mapM (observeBootstrapInput absoluteRoot) expectedBootstrapInputs
          let inputFindings = concat [problems | Left problems <- attempts]
              observedInputs = [input | Right input <- attempts]
          pure
            ( if null inputFindings
                then validateAndMintGenesisTrust environment observedInputs
                else Left inputFindings
            )

-- | Re-project the complete bounded check from an opaque token. The check
-- repeats the token's structural invariants and digest bindings; it does not
-- reread mutable local paths.
genesisTrustCheck :: GenesisTrust -> CheckResult
genesisTrustCheck trust =
  CheckResult
    { checkName = "bootstrap-genesis-trust"
    , checkObservations =
        [ observation "genesis-trust.assumption" (genesisTrustAssumptionLabel trust)
        , observation "genesis-trust.compiler-version" (environmentCompilerVersion environment)
        , observation "genesis-trust.compiler-executable" (Text.pack (environmentCompilerExecutable environment))
        , observation "genesis-trust.compiler-libdir" (Text.pack (environmentCompilerLibdir environment))
        , observation "genesis-trust.operating-system" (environmentOperatingSystem environment)
        , observation "genesis-trust.architecture" (genesisTrustArchitecture trust)
        , observation "genesis-trust.input-count" (Text.pack (show (length (trustInputs trust))))
        , observation "genesis-trust.toolchain-identity-sha256" (genesisTrustToolchainIdentity trust)
        , observation "genesis-trust.assumption-sha256" (genesisTrustDigest trust)
        ]
    , checkFindings = genesisTrustIntegrityFindings trust
    }
 where
  environment = trustEnvironment trust

genesisTrustDigest :: GenesisTrust -> Text
genesisTrustDigest = trustDigestValue

-- | The exact absolute compiler path carried by the assumption. Downstream
-- bootstrap qualification consumes this projection instead of repeating an
-- ambient executable lookup.
genesisTrustCompilerExecutable :: GenesisTrust -> FilePath
genesisTrustCompilerExecutable = environmentCompilerExecutable . trustEnvironment

genesisTrustToolchainIdentity :: GenesisTrust -> Text
genesisTrustToolchainIdentity = trustToolchainIdentityValue

genesisTrustArchitecture :: GenesisTrust -> Text
genesisTrustArchitecture = environmentArchitecture . trustEnvironment

genesisTrustAssumptionLabel :: GenesisTrust -> Text
genesisTrustAssumptionLabel _ = genesisAssumptionLabel

currentGenesisEnvironment :: GenesisEnvironment
currentGenesisEnvironment =
  GenesisEnvironment
    { environmentCompilerVersion = compiledCompilerVersion
    , environmentCompilerExecutable = GHCPaths.ghc
    , environmentCompilerLibdir = GHCPaths.libdir
    , environmentOperatingSystem = Text.pack SystemInfo.os
    , environmentArchitecture = Text.pack SystemInfo.arch
    }

-- 'System.Info.compilerVersion' may omit the distribution patch component
-- (GHC 9.12.4 reports 9.12 here). The compiler's CPP patchlevel is the exact
-- compile-time fact this trust boundary means to record.
compiledCompilerVersion :: Text
#if defined(__GLASGOW_HASKELL_PATCHLEVEL1__)
compiledCompilerVersion =
  Text.intercalate
    "."
    ( map
        (Text.pack . show)
        ( [ __GLASGOW_HASKELL__ `div` 100
          , __GLASGOW_HASKELL__ `mod` 100
          , __GLASGOW_HASKELL_PATCHLEVEL1__
          ] :: [Int]
        )
    )
#else
compiledCompilerVersion = Text.pack (showVersion SystemInfo.compilerVersion)
#endif

-- __GLASGOW_HASKELL__ identifies the compiler series; compilerVersion is a
-- value embedded by that compiler and supplies the required patch component.
compiledWithPinnedGhc :: GenesisEnvironment -> Bool
#if __GLASGOW_HASKELL__ == 912
compiledWithPinnedGhc environment =
  environmentCompilerVersion environment == pinnedCompilerVersion
#else
compiledWithPinnedGhc _ = False
#endif

environmentFindings :: GenesisEnvironment -> [Finding]
environmentFindings environment =
  [ finding
      "GENESIS-TRUST-COMPILER-VERSION"
      "validation-kernel"
      ( "expected compile-time GHC "
          <> pinnedCompilerVersion
          <> ", observed "
          <> environmentCompilerVersion environment
      )
  | not (compiledWithPinnedGhc environment)
  ]
    <> [ finding
          "GENESIS-TRUST-COMPILER-EXECUTABLE"
          (environmentCompilerExecutable environment)
          "GHC.Paths.ghc must be an absolute compiler executable path"
       | not (isAbsolute (environmentCompilerExecutable environment))
       ]
    <> [ finding
          "GENESIS-TRUST-COMPILER-LIBDIR"
          (environmentCompilerLibdir environment)
          "GHC.Paths.libdir must be an absolute compiler library path"
       | not (isAbsolute (environmentCompilerLibdir environment))
       ]
    <> [ finding
          "GENESIS-TRUST-OPERATING-SYSTEM"
          "runtime-platform"
          ( "expected "
              <> pinnedOperatingSystem
              <> ", observed "
              <> environmentOperatingSystem environment
          )
       | environmentOperatingSystem environment /= pinnedOperatingSystem
       ]
    <> [ finding
          "GENESIS-TRUST-ARCHITECTURE"
          "runtime-platform"
          ( "expected "
              <> pinnedArchitecture
              <> ", observed "
              <> environmentArchitecture environment
          )
       | environmentArchitecture environment /= pinnedArchitecture
       ]

observeBootstrapInput
  :: FilePath
  -> BootstrapInputPin
  -> IO (Either [Finding] ObservedBootstrapInput)
observeBootstrapInput repositoryRoot pin
  | not (bootstrapInputPathAllowed relative) =
      pure
        ( Left
            [ finding
                "GENESIS-TRUST-INPUT-PATH"
                relative
                "the exact bootstrap input pin is outside the bounded production path predicate"
            ]
        )
  | otherwise = do
      linkedAttempt <- try (pathIsSymbolicLink absolute) :: IO (Either IOException Bool)
      case linkedAttempt of
        Left problem
          | isDoesNotExistError problem -> pure (Left [inputMissingFinding relative])
          | otherwise -> pure (Left [inputReadFinding relative "cannot inspect the input path" problem])
        Right True ->
          pure
            ( Left
                [ finding
                    "GENESIS-TRUST-INPUT-SYMLINK"
                    relative
                    "a local-custody bootstrap input must not be a symbolic link"
                ]
            )
        Right False -> do
          regularAttempt <- try (doesFileExist absolute) :: IO (Either IOException Bool)
          case regularAttempt of
            Left problem -> pure (Left [inputReadFinding relative "cannot inspect the input file type" problem])
            Right False ->
              pure (Left [inputMissingFinding relative])
            Right True -> observeExistingBootstrapInput absolute pin
 where
  relative = pinPath pin
  absolute = repositoryRoot </> relative

observeExistingBootstrapInput
  :: FilePath
  -> BootstrapInputPin
  -> IO (Either [Finding] ObservedBootstrapInput)
observeExistingBootstrapInput absolute pin = do
  initialSizeAttempt <- try (getFileSize absolute) :: IO (Either IOException Integer)
  case initialSizeAttempt of
    Left problem -> pure (Left [inputReadFinding relative "cannot measure the input before hashing" problem])
    Right initialSize
      | initialSize /= pinSize pin -> pure (Left [inputSizeFinding relative (pinSize pin) initialSize])
      | otherwise -> do
          hashAttempt <- try (hashFileBounded absolute (pinSize pin)) :: IO (Either IOException (Integer, Text))
          case hashAttempt of
            Left problem -> pure (Left [inputReadFinding relative "cannot hash the input" problem])
            Right (bytesRead, digest) -> do
              finalSizeAttempt <- try (getFileSize absolute) :: IO (Either IOException Integer)
              pure $ case finalSizeAttempt of
                Left problem -> Left [inputReadFinding relative "cannot measure the input after hashing" problem]
                Right finalSize
                  | bytesRead /= pinSize pin -> Left [inputSizeFinding relative (pinSize pin) bytesRead]
                  | finalSize /= initialSize ->
                      Left
                        [ finding
                            "GENESIS-TRUST-INPUT-CHANGED"
                            relative
                            "the bootstrap input size changed while it was being hashed"
                        ]
                  | digest /= pinSha256 pin ->
                      Left
                        [ finding
                            "GENESIS-TRUST-INPUT-DIGEST"
                            relative
                            ("expected sha256=" <> pinSha256 pin <> "; observed sha256=" <> digest)
                        ]
                  | otherwise ->
                      Right
                        ObservedBootstrapInput
                          { observedInputPath = relative
                          , observedInputSize = bytesRead
                          , observedInputSha256 = digest
                          }
 where
  relative = pinPath pin

hashFileBounded :: FilePath -> Integer -> IO (Integer, Text)
hashFileBounded path maximumBytes =
  withBinaryFile path ReadMode $ \handle ->
    consume handle 0 (Crypto.hashInit :: Crypto.Context Crypto.SHA256)
 where
  consume handle bytesRead context
    | bytesRead > maximumBytes =
        pure
          ( bytesRead
          , Text.pack (show (Crypto.hashFinalize context :: Crypto.Digest Crypto.SHA256))
          )
    | otherwise = do
        chunk <- ByteString.hGetSome handle 65536
        if ByteString.null chunk
          then
            pure
              ( bytesRead
              , Text.pack (show (Crypto.hashFinalize context :: Crypto.Digest Crypto.SHA256))
              )
          else
            consume
              handle
              (bytesRead + fromIntegral (ByteString.length chunk))
              (Crypto.hashUpdate context chunk)

inputReadFinding :: FilePath -> Text -> IOException -> Finding
inputReadFinding path action problem =
  finding
    "GENESIS-TRUST-INPUT-READ"
    path
    (action <> ": " <> boundedException problem)

inputMissingFinding :: FilePath -> Finding
inputMissingFinding path =
  finding
    "GENESIS-TRUST-INPUT-MISSING"
    path
    "the exact local-custody bootstrap input is absent or is not a regular file"

inputSizeFinding :: FilePath -> Integer -> Integer -> Finding
inputSizeFinding path expected observed =
  finding
    "GENESIS-TRUST-INPUT-SIZE"
    path
    ( "expected bytes="
        <> Text.pack (show expected)
        <> "; observed bytes="
        <> Text.pack (show observed)
    )

boundedException :: IOException -> Text
boundedException = Text.take 512 . Text.pack . displayException

validateAndMintGenesisTrust
  :: GenesisEnvironment
  -> [ObservedBootstrapInput]
  -> Either [Finding] GenesisTrust
validateAndMintGenesisTrust environment inputs =
  case environmentFindings environment <> inputSetFindings inputs of
    [] -> Right (mintGenesisTrust environment inputs)
    problems -> Left problems

inputSetFindings :: [ObservedBootstrapInput] -> [Finding]
inputSetFindings inputs =
  [ finding
      "GENESIS-TRUST-INPUT-INVENTORY"
      ".build/bootstrap-inputs"
      "the observed bootstrap input paths do not exactly equal the seven pinned paths"
  | sort observedPaths /= sort expectedPaths
  ]
    <> [ finding
          "GENESIS-TRUST-INPUT-PATH"
          path
          "an observed bootstrap input is outside the bounded production path predicate"
       | path <- observedPaths
       , not (bootstrapInputPathAllowed path)
       ]
    <> concatMap pinMismatchFindings expectedBootstrapInputs
 where
  observedPaths = map observedInputPath inputs
  expectedPaths = map pinPath expectedBootstrapInputs
  pinMismatchFindings pin = case [input | input <- inputs, observedInputPath input == pinPath pin] of
    [input] ->
      [ inputSizeFinding (pinPath pin) (pinSize pin) (observedInputSize input)
      | observedInputSize input /= pinSize pin
      ]
        <> [ finding
              "GENESIS-TRUST-INPUT-DIGEST"
              (pinPath pin)
              ( "expected sha256="
                  <> pinSha256 pin
                  <> "; observed sha256="
                  <> observedInputSha256 input
              )
           | observedInputSha256 input /= pinSha256 pin
           ]
    _ -> []

mintGenesisTrust :: GenesisEnvironment -> [ObservedBootstrapInput] -> GenesisTrust
mintGenesisTrust environment inputs =
  GenesisTrust
    { trustEnvironment = environment
    , trustInputs = canonicalInputs
    , trustToolchainIdentityValue = toolchainIdentity environment
    , trustDigestValue = assumptionDigest environment canonicalInputs
    }
 where
  canonicalInputs = sort inputs

genesisTrustIntegrityFindings :: GenesisTrust -> [Finding]
genesisTrustIntegrityFindings trust =
  environmentFindings environment
    <> inputSetFindings inputs
    <> [ finding
          "GENESIS-TRUST-TOOLCHAIN-IDENTITY"
          "genesis-trust"
          "the stored toolchain identity is not the exact digest of the compiler path and libdir facts"
       | trustToolchainIdentityValue trust /= toolchainIdentity environment
       ]
    <> [ finding
          "GENESIS-TRUST-ASSUMPTION-DIGEST"
          "genesis-trust"
          "the stored assumption digest is not the exact digest of the local-custody facts"
       | trustDigestValue trust /= assumptionDigest environment inputs
       ]
 where
  environment = trustEnvironment trust
  inputs = trustInputs trust

toolchainIdentity :: GenesisEnvironment -> Text
toolchainIdentity environment =
  digestFields
    "amoebius.genesis-toolchain.v1"
    [ environmentCompilerVersion environment
    , Text.pack (environmentCompilerExecutable environment)
    , Text.pack (environmentCompilerLibdir environment)
    ]

assumptionDigest :: GenesisEnvironment -> [ObservedBootstrapInput] -> Text
assumptionDigest environment inputs =
  digestFields
    "amoebius.genesis-assumption.v1"
    ( [ genesisAssumptionLabel
      , environmentCompilerVersion environment
      , Text.pack (environmentCompilerExecutable environment)
      , Text.pack (environmentCompilerLibdir environment)
      , environmentOperatingSystem environment
      , environmentArchitecture environment
      ]
        <> concatMap inputFields inputs
    )
 where
  inputFields input =
    [ Text.pack (observedInputPath input)
    , Text.pack (show (observedInputSize input))
    , observedInputSha256 input
    ]

digestFields :: Text -> [Text] -> Text
digestFields domain fields =
  Text.pack
    ( show
        ( Crypto.hashWith Crypto.SHA256 payload
            :: Crypto.Digest Crypto.SHA256
        )
    )
 where
  payload = ByteString.concat (map framed (domain : fields))
  framed field =
    let bytes = TextEncoding.encodeUtf8 field
     in ByteString8.pack (show (ByteString.length bytes))
          <> ":"
          <> bytes
          <> ";"

#if defined(VALIDATION_BOOTSTRAP_TRUST_INTERNAL_TEST_HOOKS)
-- | Direct-source-only constructor seam for the independently authored pure
-- oracle. It is absent from the packaged library and production executable.
genesisTrustInternalTestAcquire
  :: Text
  -> FilePath
  -> FilePath
  -> Text
  -> Text
  -> [(FilePath, Integer, Text)]
  -> Either [Finding] GenesisTrust
genesisTrustInternalTestAcquire version executable libdir operatingSystem architecture inputs =
  validateAndMintGenesisTrust
    GenesisEnvironment
      { environmentCompilerVersion = version
      , environmentCompilerExecutable = executable
      , environmentCompilerLibdir = libdir
      , environmentOperatingSystem = operatingSystem
      , environmentArchitecture = architecture
      }
    [ ObservedBootstrapInput path size digest
    | (path, size, digest) <- inputs
    ]

genesisTrustInternalTestExpectedInputs :: [(FilePath, Integer, Text)]
genesisTrustInternalTestExpectedInputs =
  [ (pinPath pin, pinSize pin, pinSha256 pin)
  | pin <- expectedBootstrapInputs
  ]
#endif
