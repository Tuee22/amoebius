{-# LANGUAGE OverloadedStrings #-}

-- | Component-diagnostic facade for the acquired Phase-50 boundary runner.
-- This executes the real runner but cannot consume predecessor evidence,
-- publish candidate evidence, or mark a phase complete.
module Amoebius.Validation.PbBoundaryRun
  ( runPbBoundaryComponentDiagnostic
  ) where

import Amoebius.Validation.BootstrapTrust.Internal (acquireGenesisTrust)
import Amoebius.Validation.PbBoundaryRun.Internal
  ( acquirePbBoundaryRun
  , acquiredPbBoundaryRunCheck
  )
import Amoebius.Validation.SourceClosure.Internal
  ( loadGitSnapshot
  , mkGitExecutable
  , renderSnapshotProblem
  )
import Amoebius.Validation.Types (CheckResult (..), finding)
import System.Directory (findExecutable, makeAbsolute)

runPbBoundaryComponentDiagnostic :: FilePath -> IO CheckResult
runPbBoundaryComponentDiagnostic rawRoot = do
  root <- makeAbsolute rawRoot
  gitPath <- findExecutable "git"
  case gitPath >>= either (const Nothing) Just . mkGitExecutable of
    Nothing -> pure (failure "PB-BOUNDARY-COMPONENT-GIT" "<git>" "an absolute Git executable was unavailable")
    Just git -> do
      snapshot <- loadGitSnapshot git root
      trust <- acquireGenesisTrust root
      case (snapshot, trust) of
        (Left problems, _) -> pure (CheckResult "pb-boundary-component" [] [finding "PB-BOUNDARY-COMPONENT-SNAPSHOT" "<source-snapshot>" (renderSnapshotProblem problem) | problem <- problems])
        (_, Left problems) -> pure (CheckResult "pb-boundary-component" [] problems)
        (Right acquired, Right acquiredTrust) -> acquiredPbBoundaryRunCheck <$> acquirePbBoundaryRun root acquired acquiredTrust
 where
  failure code subject detail = CheckResult "pb-boundary-component" [] [finding code subject detail]
