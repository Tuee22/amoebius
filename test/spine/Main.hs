{-# LANGUAGE OverloadedStrings #-}

-- | The suite that writes the bytes the independent oracle judges. It prints no verdict.
-- Every section writes its files beneath the directory it is given and runs under an
-- exception handler and a clock, so a stage that fails or hangs leaves a marker the oracle
-- turns into red rows of that stage's own family instead of ending the run. Invoked under
-- the name @kubectl@ the same program is the fake the executor spawns.
module Main (main) where

import Control.Exception (SomeException, try)
import SpineCapacity (capacitySection)
import SpineDifferential (differentialSection)
import SpineFake (chainSection, fakeImage, interpretSection)
import SpineSections
  ( corpusSection
  , decodeSection
  , endpointSection
  , freezeSection
  , specSection
  , stagesSection
  , vocabularySection
  )
import System.Directory (createDirectoryIfMissing, makeAbsolute)
import System.Environment (getArgs, getProgName)
import System.Exit (die)
import System.FilePath ((</>))
import System.Timeout (timeout)

main :: IO ()
main = do
  name <- getProgName
  if name == "kubectl"
    then fakeImage
    else do
      arguments <- getArgs
      case arguments of
        [directory] -> makeAbsolute directory >>= run
        _ -> die "usage: spine-suite SUITE-DIRECTORY"

run :: FilePath -> IO ()
run suite = do
  createDirectoryIfMissing True (suite </> "sections")
  guarded suite "corpus" (corpusSection suite)
  guarded suite "stages" (stagesSection suite)
  guarded suite "vocab" (vocabularySection suite)
  guarded suite "spec" (specSection suite)
  guarded suite "freeze" (freezeSection suite)
  guarded suite "decode" (decodeSection suite)
  guarded suite "differential" (differentialSection suite)
  guarded suite "chain" (chainSection suite)
  guarded suite "interpret" (interpretSection suite)
  guarded suite "endpoint" (endpointSection suite)
  guarded suite "capacity" (capacitySection suite)
  writeFile (suite </> "complete.marker") "complete\n"

-- | Run one section under a clock; a failure or an overrun leaves a marker named for the
-- section and lets the next section run.
guarded :: FilePath -> String -> IO () -> IO ()
guarded suite family action = do
  outcome <- try (timeout budget action) :: IO (Either SomeException (Maybe ()))
  case outcome of
    Right (Just ()) -> pure ()
    Right Nothing -> writeFile (marker family) "timeout\n"
    Left problem -> writeFile (marker family) (takeWhile (/= '\n') (show problem) <> "\n")
 where
  marker name = suite </> "sections" </> (name <> ".failed")
  budget = 900 * 1000000
