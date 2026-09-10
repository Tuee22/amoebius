{-# LANGUAGE OverloadedStrings #-}

-- | Non-authoritative executable continuation for the package-hidden seed
-- custody supervisor.  Public callers can request only one of the fixed
-- candidate denial probes; receipt issuance remains package-hidden.
module Amoebius.Validation.SeedCustodySupervisor
  ( runSeedCustodySupervisorContinuation
  ) where

import Amoebius.Validation.SeedCustodySupervisor.Internal
  ( initializeSeedAuthority
  , runSeedCustodyProbeContinuation
  )
import Amoebius.Validation.Types
  ( CheckResult (..)
  , checkPassed
  , observationKey
  , observationValue
  , renderFinding
  )
import Data.Text.IO qualified as TextIO
import Data.Word (Word32)
import System.Exit (ExitCode (..))
import Text.Read (readMaybe)

runSeedCustodySupervisorContinuation :: [String] -> IO (Maybe ExitCode)
runSeedCustodySupervisorContinuation arguments = do
  probe <- runSeedCustodyProbeContinuation arguments
  case probe of
    Just outcome -> pure (Just outcome)
    Nothing -> case arguments of
      ["validation-seed", "initialize", root, uidText, gidText]
        | Just uid <- (readMaybe uidText :: Maybe Word32)
        , Just gid <- (readMaybe gidText :: Maybe Word32) -> do
            result <- initializeSeedAuthority root uid gid
            emit result
      _ -> pure Nothing

emit :: CheckResult -> IO (Maybe ExitCode)
emit result = do
  TextIO.putStrLn ("validation " <> checkName result <> ": " <> verdict)
  mapM_
    (\item -> TextIO.putStrLn ("OBSERVATION\t" <> observationKey item <> "\t" <> observationValue item))
    (checkObservations result)
  mapM_ (TextIO.putStrLn . ("REFUSAL\t" <>) . renderFinding) (checkFindings result)
  TextIO.putStrLn ("status\t" <> if checkPassed result then "PASS" else "NOT VALIDATED")
  pure (Just (if checkPassed result then ExitSuccess else ExitFailure 1))
 where
  verdict
    | checkPassed result = "PASS"
    | otherwise = "REFUSED"
