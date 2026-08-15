{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Ui.Server.TenantSession
import Control.Monad (forM_, unless)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  projectRoot >>= setCurrentDirectory
  verifyCustody
  let alice = SubjectId "alice"; mallory = SubjectId "mallory"; ta = TenantId "t-a"; tb = TenantId "t-b"
      active = membership [(alice, ta), (alice, tb)]
  choiceA <- either (die . show) pure (issueChoice active alice ta)
  sessionA <- either (die . show) pure (selectChoice active Nothing alice choiceA)
  choiceB <- either (die . show) pure (issueChoice active alice tb)
  sessionB <- either (die . show) pure (selectChoice active (Just sessionA) alice choiceB)
  assertEqual "scope rotation" (ScopeEpoch 2) (sessionEpoch sessionB)
  assert (sessionStateCleared sessionB && not (sessionOldHandlesValid sessionB)) "state/handle invalidation"
  assertEqual "tenant+subject lookup key" ("t-b", "alice", "same-action") (scopedLookupKey sessionB "same-action")
  assertEqual "tenant+subject+epoch route" ("t-b", "alice", 2) (realtimeRouteKey sessionB)
  let revoked = membership [(alice, ta)]
  assertLeft "revoked choice" (selectChoice revoked (Just sessionB) alice choiceB)
  assertLeft "never-member issue" (issueChoice active mallory tb)
  assertLeft "captured choice subject mismatch" (selectChoice active Nothing mallory choiceB)
  let bob = SubjectId "bob"; bobSession = sessionB {sessionSubject = bob}
  assert (scopedLookupKey bobSession "same-action" /= scopedLookupKey sessionB "same-action") "subject key collision"
  let tenantASession = sessionB {sessionTenant = ta}
  assert (scopedLookupKey tenantASession "same-action" /= scopedLookupKey sessionB "same-action") "tenant key collision"
  putStrLn "phase56-ui-multi-tenant-live: PASS-SCOPED (opaque choice; current membership; epoch rotation; stale handle refusal; tenant/subject/epoch keys; Keycloak/browser/provider live surfaces UNVERIFIED)"

verifyCustody = do
  rows <- lines <$> readFile "test/oracle/preimplementation_artifacts.tsv"
  let phaseRows = filter (Text.isPrefixOf "56\t" . Text.pack) rows
  assertEqual "Phase-0 custody" 9 (length phaseRows)
  forM_ phaseRows $ \row -> case splitTabs row of (_ : _ : path : _) -> doesFileExist path >>= flip assert ("missing " <> path); _ -> die "bad custody"
assertLeft label value = case value of Left _ -> pure (); Right _ -> die (label <> ": unexpected success")
splitTabs source = case break (== '\t') source of (field, []) -> [field]; (field, _ : rest) -> field : splitTabs rest
assert condition message = unless condition (die message)
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
projectRoot = getCurrentDirectory >>= ascend where ascend path = do found <- doesFileExist (path </> "cabal.project"); if found then pure path else let parent=takeDirectory path in if parent==path then die "phase56-root" else ascend parent
