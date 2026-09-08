{-# LANGUAGE OverloadedStrings #-}

module Amoebius.Validation.HostEnsureKernelRun
  ( runHostEnsureKernelComponentDiagnostic
  ) where

import Amoebius.Validation.BootstrapTrust.Internal (acquireGenesisTrust)
import Amoebius.Validation.HostEnsureKernelRun.Internal
  ( acquireHostEnsureKernelRun, acquiredHostEnsureKernelRunCheck )
import Amoebius.Validation.SourceClosure.Internal
  ( loadGitSnapshot, mkGitExecutable, renderSnapshotProblem )
import Amoebius.Validation.Types (CheckResult (..), finding)
import System.Directory (findExecutable, makeAbsolute)

runHostEnsureKernelComponentDiagnostic :: FilePath -> IO CheckResult
runHostEnsureKernelComponentDiagnostic rawRoot = do
  root <- makeAbsolute rawRoot
  gitPath <- findExecutable "git"
  case gitPath >>= either (const Nothing) Just . mkGitExecutable of
    Nothing -> pure (failure "HOST-ENSURE-KERNEL-COMPONENT-GIT" "<git>" "an absolute Git executable was unavailable")
    Just git -> do
      snapshot <- loadGitSnapshot git root
      trust <- acquireGenesisTrust root
      case (snapshot, trust) of
        (Left problems, _) -> pure (CheckResult "host-ensure-kernel-component" [] [finding "HOST-ENSURE-KERNEL-COMPONENT-SNAPSHOT" "<source-snapshot>" (renderSnapshotProblem problem) | problem <- problems])
        (_, Left problems) -> pure (CheckResult "host-ensure-kernel-component" [] problems)
        (Right acquired, Right acquiredTrust) -> acquiredHostEnsureKernelRunCheck <$> acquireHostEnsureKernelRun root acquired acquiredTrust
 where
  failure code subject detail = CheckResult "host-ensure-kernel-component" [] [finding code subject detail]
