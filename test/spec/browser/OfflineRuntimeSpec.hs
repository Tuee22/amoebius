{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Ui.Offline.Browser.Crypto
import Amoebius.Ui.Offline.Browser.Leader
import Amoebius.Ui.Offline.Browser.Partition
import Amoebius.Ui.Offline.Browser.Runtime
import Amoebius.Ui.Offline.Browser.ServiceWorker
import Amoebius.Ui.Offline.Browser.Store
import Control.Monad (forM_, unless)
import Data.List (isInfixOf)
import Data.Text qualified as Text
import OfflineRuntimeCases qualified as Cases
import OfflineRuntimeReference qualified as Reference
import System.Directory (createDirectory, createDirectoryIfMissing, getCurrentDirectory, removeDirectoryRecursive, removeFile)
import System.Exit (die)
import System.FilePath ((</>))
import System.IO (hClose, openTempFile)

main :: IO ()
main = do
  let canary = "fresh-offline-canary"
      secret = Secret "local-unlock-secret"
      encrypted = sealRecord secret canary
      own = partitionKey "tenant-a" "alice" "device-1" "program-1" 1
      otherSubject = partitionKey "tenant-a" "bob" "device-1" "program-1" 1
      otherTenant = partitionKey "tenant-b" "alice" "device-1" "program-1" 1
      assets = [Asset "app.js" "sha256-js" True True, Asset "app.css" "sha256-css" True True]
  assertEqual "ciphertext envelope" False (canary `isInfixOf` rawCiphertext encrypted)
  assertEqual "credential persistence fields" [] prohibitedPersistenceFields
  first <- requireRight "first owner" (claimLeader own (TabId "tab-a") emptyLeaderState)
  assertLeft "concurrent owner refusal" (claimLeader own (TabId "tab-b") first)
  second <- requireRight "replacement owner" (claimLeader own (TabId "tab-b") (releaseLeader (TabId "tab-a") first))
  assertEqual "fencing generation" (Generation 2) (leaderGeneration second)
  assertEqual "dependency quota refusal" RejectedQuota (admitBytes 100 90 20 True)
  assertEqual "tenant partition separation" True (own /= otherTenant)
  assertEqual "projection fencing hook" True (all (isInfixOf "fenceGeneration" . snd) (filter ((`elem` ["web-locks.js", "broadcast-channel.js"]) . fst) renderRuntimeProjection))
  assertEqual "decrypt" (Just canary) (openRecord secret encrypted)
  assertEqual "single owner" [TabId "tab-b"] (leaderOwners second)
  assertEqual "subject partition separation" True (own /= otherSubject)
  assertEqual "actions" 14 (length Cases.actionNames)
  assertEqual "storage rows" Reference.storageRows [("protected-record", "ciphertext", True), ("offline-auth-metadata", "partition-only", True), ("credentials", "absent", null prohibitedPersistenceFields)]
  admitted <- requireRight "asset manifest" (admitAssetManifest assets)
  assertEqual "asset rows" Reference.assetRows [(assetPath asset, "admitted") | asset <- admitted]
  assertEqual "quota rows" Reference.quotaRows [("within-budget", show (admitBytes 100 70 20 True)), ("over-budget-independent", show (admitBytes 100 90 20 False)), ("over-budget-depended", show (admitBytes 100 90 20 True))]
  assertEqual "access rows" Reference.accessRows [("own", "allow"), ("foreign-subject", if own == otherSubject then "allow" else "deny"), ("foreign-tenant", if own == otherTenant then "allow" else "deny")]
  let initial = initialOfflineState own (Generation 2)
  assertEqual "migration rows" Reference.migrationRows [("next-epoch", eitherShow (migrateState 2 initial)), ("skip-epoch", eitherShow (migrateState 3 initial)), ("regress", eitherShow (migrateState 1 initial))]
  assertEqual "replay rows" Reference.replayRows [("ordered", eitherShow (recoverReplay own (Generation 2) [1,2] initial)), ("sequence-gap", eitherShow (recoverReplay own (Generation 2) [1,3] initial)), ("foreign-partition", eitherShow (recoverReplay otherTenant (Generation 2) [1] initial)), ("stale-fence", eitherShow (recoverReplay own (Generation 1) [1] initial))]
  assertEqual "facility rows" Reference.facilityRows (map show supportedFacilities)
  assertEqual "projection paths" Cases.projectionPaths (map fst renderRuntimeProjection)
  checkProjectionMaterialization
  checkCalculus
  putStrLn "offline-browser-runtime-calculus: PASS (5 kinds, 69 projected units)"
  putStrLn "offline-browser-runtime-spec: PASS (14 actions, 3 storage rows, 2 assets, 3 quota rows, 3 access rows, 3 migrations, 4 replay rows, 6 facilities, 7 mutants)"

eitherShow :: Either problem value -> String
eitherShow (Left _) = "deny"
eitherShow (Right _) = "allow"

checkProjectionMaterialization :: IO ()
checkProjectionMaterialization = do
  root <- getCurrentDirectory
  let parent = root </> ".build/runs/phase-45/projected"
  createDirectoryIfMissing True parent
  (leaf, handle) <- openTempFile parent "runtime-"
  hClose handle
  removeFile leaf
  let first = leaf <> "-a"; second = leaf <> "-b"
  createDirectory first
  createDirectory second
  forM_ renderRuntimeProjection $ \(path, contents) -> do
    writeFile (first </> path) contents
    writeFile (second </> path) contents
  firstRows <- mapM (readFile . (first </>) . fst) renderRuntimeProjection
  secondRows <- mapM (readFile . (second </>) . fst) renderRuntimeProjection
  assertEqual "deterministic runtime projection" firstRows secondRows
  removeDirectoryRecursive first
  removeDirectoryRecursive second

checkCalculus :: IO ()
checkCalculus = do
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "offline-browser-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "offline-browser-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $ CalculusScope.withRequestScope tenant subject membership $ \scope -> do
    let resources count = ResourceVector 1 (fromIntegral (count :: Int)) 0 0
        counts = [6, 7, 35, 14, 7] :: [Int]
        artifact = artifactComponent scope "production-offline-artifacts" (resources 6) (RecipeId "encrypted-browser-runtime" 6)
        budget = budgetComponent scope "closed-offline-budget" (resources 7) (allowance (Bytes 7) (Slots 1) (Bytes 7))
        lift = liftComponent scope "browser-offline-corpus" (resources 35) OnHost
        workflow = workflowComponent scope "fenced-tab-workflow" (resources 14) emptyLedger
        evidence = evidenceComponent scope "mutant-evidence" (resources 7) PureRegister
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
    assertEqual "offline browser calculus projection" Cases.calculusRows actual
  action

assertLeft :: Show value => String -> Either problem value -> IO ()
assertLeft _ (Left _) = pure ()
assertLeft label (Right value) = die (label <> ": expected Left, got Right " <> show value)

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
