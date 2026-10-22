{-# LANGUAGE OverloadedStrings #-}

-- Predecessor observations always run serially, including compiler controls.
module SpineSuite (runBase, guarded) where

import Control.Exception (SomeException, try)
import SpineCapacity (capacitySection)
import SpineSubstrates (substrateSection)
import SpineDifferential (differentialSection)
import SpineFake (chainSection, interpretSection)
import SpineSections
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))
import System.Timeout (timeout)

runBase :: FilePath -> IO ()
runBase suite = do
  createDirectoryIfMissing True (suite </> "sections")
  mapM_ (\(name, section) -> guarded suite name (section suite))
    [("corpus", corpusSection), ("stages", stagesSection), ("vocab", vocabularySection),
     ("spec", specSection), ("freeze", freezeSection), ("decode", decodeSection),
     ("differential", differentialSection), ("chain", chainSection),
     ("interpret", interpretSection), ("endpoint", endpointSection),
     ("capacity", capacitySection), ("substrates", substrateSection)]

guarded :: FilePath -> String -> IO () -> IO ()
guarded suite family action = do
  outcome <- try (timeout (900 * 1000000) action) :: IO (Either SomeException (Maybe ()))
  case outcome of
    Right (Just ()) -> pure ()
    Right Nothing -> writeFile marker "timeout\n"
    Left problem -> writeFile marker (takeWhile (/= '\n') (show problem) <> "\n")
 where marker = suite </> "sections" </> (family <> ".failed")
