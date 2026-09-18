{-# LANGUAGE OverloadedStrings #-}

-- | The finite Phase-0 seed protocol (gate integrity section M.4). It copies the
-- exact predicate source and the independent driver into the run root, compiles
-- them directly with the pinned compiler, runs the clean case, then applies each
-- of the three named bypass rewrites to a fresh copy, recompiles, and runs the
-- driver again. Clean must exit silently with success; every mutant must exit
-- with failure, an empty standard output, and its case label plus one newline on
-- standard error. Every process runs under the observer and the ordered receipts
-- are hash-chained.
module Amoebius.Validation.BootstrapQualification.Internal
  ( SeedCase (..)
  , SeedOutcome (..)
  , SeedProtocol (..)
  , defaultSeedProtocol
  , renderSeedOutcome
  , runSeedProtocol
  , seedCases
  , seedGreen
  ) where

import Amoebius.Validation.Runner.Observer
import Control.Monad (forM)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Directory (createDirectoryIfMissing, doesFileExist, findExecutable, makeAbsolute)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))

data SeedCase = SeedCase
  { caseLabel :: Text
  , caseBefore :: Text
  , caseAfter :: Text
  }
  deriving (Eq, Show)

-- | The three bypasses: each replaces exactly one complete line of the predicate.
seedCases :: [SeedCase]
seedCases =
  [ SeedCase
      "digest-equality-bypass"
      "bootstrapDigestMatches actual expected = validLowerSha256 actual && actual == expected"
      "bootstrapDigestMatches actual _expected = validLowerSha256 actual"
  , SeedCase
      "snapshot-freshness-bypass"
      "bootstrapSnapshotMatches opening closing = validLowerSha256 opening && opening == closing"
      "bootstrapSnapshotMatches opening _closing = validLowerSha256 opening"
  , SeedCase
      "bootstrap-path-bypass"
      "bootstrapInputPathAllowed path = \".build/bootstrap-inputs/\" `isPrefixOf` path && boundedRelativePath path"
      "bootstrapInputPathAllowed path = \".build/bootstrap-inputs/\" `isPrefixOf` path"
  ]

data SeedProtocol = SeedProtocol
  { protocolRoot :: FilePath
  , protocolRunRoot :: FilePath
  , protocolPredicateSource :: FilePath
  , protocolDriverSource :: FilePath
  , protocolCompiler :: Maybe FilePath
  }
  deriving (Eq, Show)

defaultSeedProtocol :: FilePath -> FilePath -> SeedProtocol
defaultSeedProtocol root runRoot =
  SeedProtocol
    { protocolRoot = root
    , protocolRunRoot = runRoot
    , protocolPredicateSource = "src/validation-kernel/Amoebius/Validation/BootstrapPredicate.hs"
    , protocolDriverSource = "test/validation-kernel/BootstrapMutationDriver.hs"
    , protocolCompiler = Nothing
    }

data SeedOutcome = SeedOutcome
  { seedCompiler :: Maybe FilePath
  , seedCleanRun :: Maybe ObservedRun
  , seedMutantRuns :: [(SeedCase, Maybe ObservedRun, Maybe Text)]
  , seedProblems :: [Text]
  , seedChain :: Text
  }
  deriving (Eq, Show)

-- | Every case behaved exactly as the protocol requires.
seedGreen :: SeedOutcome -> Bool
seedGreen outcome =
  null (seedProblems outcome)
    && maybe False cleanExact (seedCleanRun outcome)
    && length (seedMutantRuns outcome) == length seedCases
    && all mutantExact (seedMutantRuns outcome)
 where
  cleanExact run = runExit run == ExitSuccess && Text.null (runStdout run) && Text.null (runStderr run)
  mutantExact (seedCase, run, problem) =
    problem == Nothing
      && maybe False (\r -> runExit r == ExitFailure 1 && Text.null (runStdout r) && runStderr r == caseLabel seedCase <> "\n") run

renderSeedOutcome :: SeedOutcome -> [(Text, Text)]
renderSeedOutcome outcome =
  [("seed.compiler", maybe "absent" Text.pack (seedCompiler outcome)), ("seed.chain", seedChain outcome), ("seed.green", Text.pack (show (seedGreen outcome)))]
    <> maybe [] (renderObserved "seed.clean") (seedCleanRun outcome)
    <> concat
      [ maybe [("seed." <> caseLabel seedCase <> ".problem", maybe "absent-run" id problem)] (renderObserved ("seed." <> caseLabel seedCase)) run
      | (seedCase, run, problem) <- seedMutantRuns outcome
      ]
    <> [("seed.problem", problem) | problem <- seedProblems outcome]

-- | Run the protocol. The compiler is the pinned @ghc@ on PATH unless the caller
-- names one; the seed's toolchain provenance belongs to Phase 1, not here.
runSeedProtocol :: SeedProtocol -> Text -> IO SeedOutcome
runSeedProtocol protocol challenge = do
  compiler <- maybe (findExecutable "ghc") (pure . Just) (protocolCompiler protocol)
  predicateExists <- doesFileExist (protocolRoot protocol </> protocolPredicateSource protocol)
  driverExists <- doesFileExist (protocolRoot protocol </> protocolDriverSource protocol)
  case (compiler, predicateExists, driverExists) of
    (Nothing, _, _) -> pure (SeedOutcome Nothing Nothing [] ["no compiler on PATH and none configured"] challenge)
    (_, False, _) -> pure (SeedOutcome compiler Nothing [] ["predicate source absent: " <> Text.pack (protocolPredicateSource protocol)] challenge)
    (_, _, False) -> pure (SeedOutcome compiler Nothing [] ["driver source absent: " <> Text.pack (protocolDriverSource protocol)] challenge)
    (Just ghc, True, True) -> do
      predicate <- TextIO.readFile (protocolRoot protocol </> protocolPredicateSource protocol)
      driver <- TextIO.readFile (protocolRoot protocol </> protocolDriverSource protocol)
      (cleanRun, chain1) <- compileAndRun ghc (protocolRunRoot protocol </> "seed" </> "clean") predicate driver challenge
      mutants <- forM seedCases $ \seedCase -> do
        let occurrences = length (filter (== caseBefore seedCase) (Text.lines predicate))
        if occurrences /= 1
          then pure (seedCase, Nothing, Just ("expected exactly one locus line; found " <> Text.pack (show occurrences)))
          else do
            let mutated = Text.unlines [if line == caseBefore seedCase then caseAfter seedCase else line | line <- Text.lines predicate]
            (run, _) <- compileAndRun ghc (protocolRunRoot protocol </> "seed" </> Text.unpack (caseLabel seedCase)) mutated driver chain1
            pure (seedCase, Just run, Nothing)
      let chain = foldl chainDigest chain1 [run | (_, Just run, _) <- mutants]
      pure
        SeedOutcome
          { seedCompiler = Just ghc
          , seedCleanRun = Just cleanRun
          , seedMutantRuns = mutants
          , seedProblems = []
          , seedChain = chain
          }

-- | Write the two sources into a fresh directory, compile them with @ghc@ into one
-- driver executable, and run it under the observer.
compileAndRun :: FilePath -> FilePath -> Text -> Text -> Text -> IO (ObservedRun, Text)
compileAndRun ghc relativeDirectory predicate driver chain = do
  createDirectoryIfMissing True relativeDirectory
  directory <- makeAbsolute relativeDirectory
  createDirectoryIfMissing True (directory </> "Amoebius" </> "Validation")
  TextIO.writeFile (directory </> "Amoebius" </> "Validation" </> "BootstrapPredicate.hs") predicate
  TextIO.writeFile (directory </> "Driver.hs") driver
  build <- observe directory ghc ["-v0", "-i.", "-outputdir", "objects", "-o", "driver", "Driver.hs"]
  if runExit build /= ExitSuccess
    then pure (build, chainDigest chain build)
    else do
      run <- observe directory (directory </> "driver") []
      pure (run, chainDigest (chainDigest chain build) run)
