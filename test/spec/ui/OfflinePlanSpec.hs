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
import Amoebius.Ui.Offline.Decode
import Amoebius.Ui.Offline.Plan
import Amoebius.Ui.Offline.Types
import Amoebius.Ui.Source qualified as UiSource
import Control.Monad (forM_, unless)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Directory (doesFileExist, getCurrentDirectory, setCurrentDirectory)
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)

main :: IO ()
main = do
  root <- projectRoot
  setCurrentDirectory root
  verifyCustody root
  positiveRows <- loadWordsTable (root </> "test/fixture/offline_language_plan/positive_contracts.tbl")
  negativeRows <- loadWordsTable (root </> "test/fixture/offline_language_plan/negative_contracts.tbl")
  planRows <- loadWordsTable (root </> "test/golden/offline_language_plan/plan_keys.tbl")
  sources <- checkDhallContinuity root positiveRows
  source <- combineOfflineSources sources
  forM_ sources $ \offline -> requireCompiled "individual offline source" (compileOffline offline)
  (client, replay) <- requireCompiled "combined offline source" (compileOffline source)
  checkPlanRows planRows client replay
  checkNegatives negativeRows
  assertEqual "paired queue keys" (clientKeys client) (replayKeys replay)
  assertEqual "paired projection keys" (clientProjectionKeys client) (replayProjectionKeys replay)
  assertEqual "paired blob keys" (clientBlobKeys client) (replayBlobKeys replay)
  assertEqual "deterministic" (Right (client, replay)) (compileOffline source)
  checkPrivateFields client
  checkMechanisms
  assertEqual "artifact commands"
    ["emit-client-offline-plan", "emit-server-replay-plan"] generatedArtifactCommands
  checkCalculus root
  putStrLn "offline-plan-calculus: PASS (5 kinds, 40 projected units)"
  putStrLn "offline-plan-spec: PASS (3 positive contracts, 13 exact negatives, 8 plan rows, 3 paired key sets, 5 mutants)"

checkDhallContinuity :: FilePath -> [[String]] -> IO [OfflineSource]
checkDhallContinuity root expected = do
  minimal <- decodeSource (root </> "test/fixture/ui_program_schema/minimal_single_tenant.dhall")
  infernix <- decodeSource (root </> "dhall/ui/infernix.dhall")
  jitml <- decodeSource (root </> "dhall/ui/jitml.dhall")
  assertEqual "authored positive continuity rows" expected
    [ renderContinuity "online-only" (UiSource.continuity minimal)
    , renderContinuity "infernix" (UiSource.continuity infernix)
    , renderContinuity "jitml" (UiSource.continuity jitml)
    ]
  traverse requireOffline
    [("infernix", UiSource.continuity infernix), ("jitml", UiSource.continuity jitml)]
  where
    decodeSource path = UiSource.decodeUiSource path >>= either (die . Text.unpack) pure
    requireOffline (label, selected) = case selected of
      Offline source -> pure source
      OnlineOnly -> die (label <> " unexpectedly declared OnlineOnly")

renderContinuity :: String -> Continuity -> [String]
renderContinuity label selected = case selected of
  OnlineOnly -> [label, "OnlineOnly", "-", "0", "0", "0", "-", "-", "-", "-", "-", "-"]
  Offline source -> case queuedPorts source of
    [QueuedPort selectedOperation queue] ->
      [ label
      , "Offline"
      , renderPort (operationPort selectedOperation)
      , show (maxCount queue)
      , show (maxBytes queue)
      , show (maxAgeSeconds queue)
      , Text.unpack (localValidation queue)
      , Text.unpack (idempotency queue)
      , Text.unpack (conflict queue)
      , Text.unpack (ordering queue)
      , Text.unpack (dependency queue)
      , Text.unpack (authoritativeValidation queue)
      ]
    rows -> [label, "invalid-queued-port-count", show (length rows)]

combineOfflineSources :: [OfflineSource] -> IO OfflineSource
combineOfflineSources sources = case sources of
  [infernix, jitml] -> pure OfflineSource
    { projections = uniqueSorted (projections infernix <> projections jitml)
    , queuedPorts = queuedPorts infernix <> queuedPorts jitml
    , localBlobs = uniqueSorted (localBlobs infernix <> localBlobs jitml)
    , offlineView = "offline.dashboard"
    }
  _ -> die ("expected two offline sources, got " <> show (length sources))

checkPlanRows :: [[String]] -> ClientPlan -> ReplayPlan -> IO ()
checkPlanRows expected client replay = do
  let operationRows = map renderOperation [minBound .. maxBound]
      blobRows =
        [ [Text.unpack key, Text.unpack key, privateKey key, "local-blob"]
        | key <- clientBlobKeys client
        ]
      viewRow =
        [ "offline-view"
        , Text.unpack (clientOfflineView client)
        , "-"
        , "client-view"
        ]
      actual = sort (operationRows <> blobRows <> [viewRow])
  assertEqual "independent public/private plan rows" (sort expected) actual
  where
    renderOperation selected =
      let port = operationPort selected
          name = renderPort port
      in if port `elem` clientKeys client
        then [name, name, if port `elem` replayKeys replay then name else "-", "queued"]
        else if Text.pack name `elem` clientProjectionKeys client
          then [name, name, if Text.pack name `elem` replayProjectionKeys replay then name else "-", "cached-projection"]
          else [name, "-", "-", "online-only"]
    privateKey key = if key `elem` replayBlobKeys replay then Text.unpack key else "-"

checkNegatives :: [[String]] -> IO ()
checkNegatives rows = do
  assertEqual "negative row cardinality" 13 (length rows)
  forM_ rows $ \row -> case row of
    [label, expected] -> checkNegative label expected (negativeCase label)
    _ -> die ("invalid negative row: " <> show row)

checkNegative :: String -> String -> QueuedPort -> IO ()
checkNegative label expected queued = case decodeQueueContract queued of
  Left actual -> assertEqual label expected (errorTag actual)
  Right _
    | label == "zero-age" -> die "offline-plan-mutant: RED drop_queue_bound locus=queue-age-bound"
    | label == "queue-model-invocation" -> die "offline-plan-mutant: RED queue_model_invocation locus=model-invocation-classification"
    | otherwise -> die (label <> " unexpectedly accepted")

negativeCase :: String -> QueuedPort
negativeCase label = case label of
  "zero-count" -> QueuedPort InfernixStart (base {maxCount = 0})
  "zero-bytes" -> QueuedPort InfernixStart (base {maxBytes = 0})
  "zero-age" -> QueuedPort InfernixStart (base {maxAgeSeconds = 0})
  "missing-local-validation" -> QueuedPort InfernixStart (base {localValidation = ""})
  "missing-idempotency" -> QueuedPort InfernixStart (base {idempotency = ""})
  "missing-conflict" -> QueuedPort InfernixStart (base {conflict = ""})
  "missing-order" -> QueuedPort InfernixStart (base {ordering = ""})
  "missing-dependency" -> QueuedPort InfernixStart (base {dependency = ""})
  "missing-validation" -> QueuedPort InfernixStart (base {authoritativeValidation = ""})
  "queue-progress" -> QueuedPort WorkflowProgress base
  "queue-signal" -> QueuedPort MlSignal base
  "queue-cancel" -> QueuedPort WorkflowCancel base
  "queue-model-invocation" -> QueuedPort ModelInvocation base
  _ -> QueuedPort InfernixStart base
  where
    base = validContract "dependency"

errorTag :: DecodeError -> String
errorTag actual = case actual of
  MissingCountBound -> "MissingCountBound"
  MissingByteBound -> "MissingByteBound"
  MissingAgeBound -> "MissingAgeBound"
  MissingLocalValidation -> "MissingLocalValidation"
  MissingIdempotency -> "MissingIdempotency"
  MissingConflictRule -> "MissingConflictRule"
  MissingOrderRule -> "MissingOrderRule"
  MissingDependencyRule -> "MissingDependencyRule"
  MissingAuthorityValidation -> "MissingAuthorityValidation"
  OnlineOnlyOperation _ -> "OnlineOnlyOperation"

validContract :: Text -> QueueContract
validContract selectedDependency = QueueContract
  { maxCount = 8
  , maxBytes = 65536
  , maxAgeSeconds = 86400
  , localValidation = "advisory"
  , idempotency = "command-id"
  , conflict = "reject"
  , ordering = "preserve"
  , dependency = selectedDependency
  , authoritativeValidation = "current-authority"
  }

requireCompiled :: String -> Either OfflinePlanError value -> IO value
requireCompiled label result = case result of
  Right value -> pure value
  Left PlanKeyMismatch -> die "offline-plan-mutant: RED omit_server_handler locus=paired-plan-keys"
  Left problem -> die (label <> ": " <> show problem)

checkPrivateFields :: ClientPlan -> IO ()
checkPrivateFields client
  | leakedPrivateFields client == [] = pure ()
  | leakedPrivateFields client == ["authority-policy"] =
      die "offline-plan-mutant: RED persist_private_field locus=public-plan-private-fields"
  | otherwise = die ("unexpected private fields: " <> show (leakedPrivateFields client))

checkMechanisms :: IO ()
checkMechanisms
  | mechanismConstructors == [] = pure ()
  | mechanismConstructors == ["IndexedDB", "Redis"] =
      die "offline-plan-mutant: RED browser_redis_constructor locus=authored-mechanism-surface"
  | otherwise = die ("unexpected mechanism constructors: " <> show mechanismConstructors)

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expected <- loadWordsTable (root </> "test/oracle/offline_language_plan/calculus_projection.tsv")
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "offline-plan-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "offline-plan-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources :: Int -> ResourceVector
          resources count = ResourceVector 1 (fromIntegral count) 0 0
          counts = [2, 9, 16, 8, 5] :: [Int]
          artifact = artifactComponent scope "offline-plan-artifacts" (resources 2)
            (RecipeId "offline-language-plan" 2)
          budget = budgetComponent scope "bounded-queue-contract" (resources 9)
            (allowance (Bytes 9) (Slots 1) (Bytes 9))
          lift = liftComponent scope "language-and-refusal-corpus" (resources 16) OnHost
          workflow = workflowComponent scope "paired-plan-workflow" (resources 8) emptyLedger
          evidence = evidenceComponent scope "mutant-evidence" (resources 5) PureRegister
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
      assertEqual "offline-plan calculus projection" expected actual
  action

verifyCustody :: FilePath -> IO ()
verifyCustody root = do
  rows <- drop 1 . lines <$> readFile (root </> "test/oracle/preimplementation_artifacts.tsv")
  let parsed = map splitTabs rows
      phaseRows = [fields | fields@(phase : _) <- parsed, phase == "24"]
  assertEqual "phase-0 custody" 8 (length phaseRows)
  forM_ phaseRows $ \row -> case row of
    (_phase : _kind : path : _) -> doesFileExist (root </> path) >>= flip assert ("missing " <> path)
    _ -> die "bad Phase-24 custody row"

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

renderPort :: PortId -> String
renderPort (PortId value) = Text.unpack value

uniqueSorted :: Ord value => [value] -> [value]
uniqueSorted = foldr add [] . sort
  where
    add value values = case values of
      first : _ | first == value -> values
      _ -> value : values

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))

projectRoot :: IO FilePath
projectRoot = getCurrentDirectory >>= go
  where
    go path = do
      found <- doesFileExist (path </> "cabal.project")
      if found
        then pure path
        else let parent = takeDirectory path
          in if parent == path then die "offline-language-plan-root" else go parent
