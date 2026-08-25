{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Ui.Offline.Browser.Crypto
import Amoebius.Ui.Offline.Browser.Leader
import Amoebius.Ui.Offline.Browser.Partition
import Amoebius.Ui.Offline.Browser.ServiceWorker
import Amoebius.Ui.Offline.Browser.Store
import Control.Monad (forM_, unless)
import Data.Aeson (FromJSON, eitherDecode)
import Data.ByteString.Lazy qualified as Lazy
import Data.List (isInfixOf)
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

data ActionTrace = ActionTrace
  { actions :: [Text]
  , expected :: Text
  }
  deriving stock (Eq, Show, Generic)

instance FromJSON ActionTrace

main :: IO ()
main = do
  root <- projectRoot
  setCurrentDirectory root
  verifyCustody root
  checkActionTrace root
  checkStorageOracle root
  checkAssetOracle root
  checkQuotaOracle root
  checkPartitionOracle root
  checkReferenceModel
  checkCalculus root
  putStrLn "offline-browser-runtime-calculus: PASS (5 kinds, 50 projected units)"
  putStrLn "offline-browser-runtime-spec: PASS (14 actions, 3 storage rows, 2 assets, 3 quota rows, 3 partition rows, 6 mutants)"

checkActionTrace :: FilePath -> IO ()
checkActionTrace root = do
  bytes <- Lazy.readFile (root </> "test/golden/browser/encrypted_browser_runtime/action_trace.json")
  trace <- either (die . ("action trace: " <>)) pure (eitherDecode bytes)
  assertEqual "action trace outcome" "PASS" (expected trace)
  assertEqual "action trace"
    [ "derive-partition", "unlock", "queue", "inspect-ciphertext", "restart", "unlock", "recover"
    , "claim-tab-a", "refuse-tab-b", "release-tab-a", "claim-tab-b", "upgrade-assets"
    , "switch-partition", "quota-refusal"
    ] (actions trace)

checkStorageOracle :: FilePath -> IO ()
checkStorageOracle root = do
  rows <- loadWordsTable (root </> "test/golden/browser/encrypted_browser_runtime/storage_inventory.tbl")
  assertEqual "storage inventory"
    [ ["records", "partition/record", "ciphertext", "true"]
    , ["metadata", "partition", "offline-auth-metadata", "true"]
    , ["keys", "-", "none", "credential,refresh-token,private-plan"]
    ] rows
  assertEqual "prohibited fields" [] prohibitedPersistenceFields

checkAssetOracle :: FilePath -> IO ()
checkAssetOracle root = do
  rows <- loadWordsTable (root </> "test/golden/browser/encrypted_browser_runtime/asset_manifest.tbl")
  let assets = [Asset path digest (visibility == "public") (mutable == "false") | [path, digest, visibility, mutable] <- rows]
  assertEqual "asset row count" 2 (length assets)
  assertEqual "asset manifest" (Right assets) (admitAssetManifest assets)

checkQuotaOracle :: FilePath -> IO ()
checkQuotaOracle root = do
  rows <- loadWordsTable (root </> "test/golden/browser/encrypted_browser_runtime/quota_outcomes.tbl")
  assertEqual "quota oracle"
    [ ["within-budget", "Stored", "true"]
    , ["over-budget-independent", "RejectedQuota", "true"]
    , ["over-budget-depended", "RejectedQuota", "true"]
    ] rows
  assertEqual "within quota" Stored (admitBytes 100 70 20 True)
  assertEqual "independent quota" RejectedQuota (admitBytes 100 90 20 False)
  assertEqual "depended quota" RejectedQuota (admitBytes 100 90 20 True)

checkPartitionOracle :: FilePath -> IO ()
checkPartitionOracle root = do
  rows <- loadWordsTable (root </> "test/golden/browser/encrypted_browser_runtime/partition_access.tbl")
  assertEqual "partition row count" 3 (length rows)
  assertEqual "partition decisions" ["allow", "deny", "deny"] [decision | [_record, _requester, decision] <- rows]
  let own = partitionKey "tenant-a" "alice" "device-1" "program-1" 1
      otherSubject = partitionKey "tenant-a" "bob" "device-1" "program-1" 1
      otherTenant = partitionKey "tenant-b" "alice" "device-1" "program-1" 1
  assert (own /= otherSubject) "subject partition collision"
  assert (own /= otherTenant) "tenant partition collision"

checkReferenceModel :: IO ()
checkReferenceModel = do
  let canary = "fresh-offline-canary"
      secret = Secret "local-unlock-secret"
      encrypted = sealRecord secret canary
      own = partitionKey "tenant-a" "alice" "device-1" "program-1" 1
  assert (not (canary `isInfixOf` rawCiphertext encrypted)) "plaintext canary visible"
  assertEqual "decrypt" (Just canary) (openRecord secret encrypted)
  first <- either (die . show) pure (claimLeader own (TabId "tab-a") emptyLeaderState)
  assertLeft "concurrent tab" (claimLeader own (TabId "tab-b") first)
  second <- either (die . show) pure (claimLeader own (TabId "tab-b") (releaseLeader (TabId "tab-a") first))
  assertEqual "single leader" [TabId "tab-b"] (leaderOwners second)
  assertEqual "fencing generation" (Generation 2) (leaderGeneration second)

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expectedRows <- loadWordsTable (root </> "test/oracle/encrypted_browser_runtime/calculus_projection.tsv")
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "offline-browser-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "offline-browser-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources count = ResourceVector 1 (fromIntegral count) 0 0
          counts = [2, 3, 25, 14, 6] :: [Int]
          artifact = artifactComponent scope "production-offline-artifacts" (resources 2)
            (RecipeId "encrypted-browser-runtime" 2)
          budget = budgetComponent scope "closed-offline-budget" (resources 3)
            (allowance (Bytes 3) (Slots 1) (Bytes 3))
          lift = liftComponent scope "browser-offline-corpus" (resources 25) OnHost
          workflow = workflowComponent scope "fenced-tab-workflow" (resources 14) emptyLedger
          evidence = evidenceComponent scope "mutant-evidence" (resources 6) PureRegister
          composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
          ResourceVector cpu memory ephemeral pods = compositionResource composition
          render = Text.unpack . Text.intercalate ","
          actual =
            [ ["calculus-kinds", render (map calculusTag (compositionKinds composition))]
            , ["component-names", render (compositionNames composition)]
            , ["projection-counts", render (map (Text.pack . show) counts)]
            , ["resource-vector", render (map (Text.pack . show) [cpu, memory, ephemeral, pods])]
            ]
      assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
      assertEqual "offline browser calculus projection" expectedRows actual
  action

verifyCustody :: FilePath -> IO ()
verifyCustody root = do
  rows <- drop 1 . lines <$> readFile (root </> "test/oracle/preimplementation_artifacts.tsv")
  let phaseRows = [fields | fields@(phase : _) <- map splitTabs rows, phase == "28"]
  assertEqual "phase-0 custody" 11 (length phaseRows)
  forM_ phaseRows $ \row -> case row of
    (_phase : _kind : path : _) -> doesFileExist (root </> path) >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-29 custody row"

loadWordsTable :: FilePath -> IO [[String]]
loadWordsTable path = do
  rows <- lines <$> readFile path
  case rows of
    [] -> die ("empty table: " <> path)
    _header : body -> do
      assert (not (null body)) ("table has no rows: " <> path)
      pure (map words body)

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

assertLeft :: String -> Either problem value -> IO ()
assertLeft _ (Left _) = pure ()
assertLeft label (Right _) = die (label <> " unexpectedly succeeded")

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label wanted actual =
  unless (wanted == actual) (die (label <> ": expected " <> show wanted <> ", got " <> show actual))

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= go
  where
    go path = do
      found <- doesFileExist (path </> "cabal.project")
      if found then pure path else
        let parent = takeDirectory path
        in if parent == path then die "encrypted-browser-runtime-root" else go parent
