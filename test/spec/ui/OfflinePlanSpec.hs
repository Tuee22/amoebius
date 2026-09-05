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
import Amoebius.Ui.Offline.Decode
import Amoebius.Ui.Offline.Plan
import Amoebius.Ui.Offline.Types
import Control.Monad (forM_, unless)
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import OfflinePlanCases qualified as Cases
import OfflinePlanReference qualified as Reference
import System.Exit (die)

main :: IO ()
main = do
    assertEqual "authored positive continuity rows" Reference.referenceContinuityRows (map renderContinuity Cases.positiveContinuities)
    source <- combineOfflineSources Cases.offlineSources
    forM_ Cases.offlineSources $ \offline -> requireCompiled "individual offline source" (compileOffline offline)
    (client, replay) <- requireCompiled "combined offline source" (compileOffline source)
    checkPlanRows Reference.referencePlanRows client replay
    checkNegatives Reference.referenceNegativeTags Cases.negativeCases
    assertEqual "paired queue keys" (clientKeys client) (replayKeys replay)
    assertEqual "paired projection keys" (clientProjectionKeys client) (replayProjectionKeys replay)
    assertEqual "paired blob keys" (clientBlobKeys client) (replayBlobKeys replay)
    assertEqual "deterministic" (Right (client, replay)) (compileOffline source)
    checkPrivateFields client
    checkMechanisms
    assertEqual "artifact commands" ["emit-client-offline-plan", "emit-server-replay-plan"] generatedArtifactCommands
    checkCalculus
    putStrLn "offline-plan-calculus: PASS (5 kinds, 40 projected units)"
    putStrLn "offline-plan-spec: PASS (3 positive contracts, 13 exact negatives, 8 plan rows, 3 paired key sets, 5 mutants)"

renderContinuity :: (Text, Continuity) -> [String]
renderContinuity (label, selected) = case selected of
    OnlineOnly -> [Text.unpack label, "OnlineOnly", "-", "0", "0", "0", "-", "-", "-", "-", "-", "-"]
    Offline source -> case queuedPorts source of
        [QueuedPort selectedOperation queue] ->
            [ Text.unpack label, "Offline", renderPort (operationPort selectedOperation)
            , show (maxCount queue), show (maxBytes queue), show (maxAgeSeconds queue)
            , Text.unpack (localValidation queue), Text.unpack (idempotency queue)
            , Text.unpack (conflict queue), Text.unpack (ordering queue)
            , Text.unpack (dependency queue), Text.unpack (authoritativeValidation queue)
            ]
        rows -> [Text.unpack label, "invalid-queued-port-count", show (length rows)]

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
        blobRows = [[Text.unpack key, Text.unpack key, privateKey key, "local-blob"] | key <- clientBlobKeys client]
        viewRow = ["offline-view", Text.unpack (clientOfflineView client), "-", "client-view"]
    assertEqual "independent public/private plan rows" (sort expected) (sort (operationRows <> blobRows <> [viewRow]))
  where
    renderOperation selected =
        let port = operationPort selected; name = renderPort port
         in if port `elem` clientKeys client
              then [name, name, if port `elem` replayKeys replay then name else "-", "queued"]
              else if Text.pack name `elem` clientProjectionKeys client
                then [name, name, if Text.pack name `elem` replayProjectionKeys replay then name else "-", "cached-projection"]
                else [name, "-", "-", "online-only"]
    privateKey key = if key `elem` replayBlobKeys replay then Text.unpack key else "-"

checkNegatives :: [(String, String)] -> [(Text, QueuedPort)] -> IO ()
checkNegatives expected subjects = do
    assertEqual "negative row cardinality" 13 (length subjects)
    assertEqual "negative case names" (map fst expected) (map (Text.unpack . fst) subjects)
    forM_ (zip expected subjects) $ \((_, expectedTag), (label, queued)) -> checkNegative (Text.unpack label) expectedTag queued

checkNegative :: String -> String -> QueuedPort -> IO ()
checkNegative label expected queued = case decodeQueueContract queued of
    Left actual -> assertEqual label expected (errorTag actual)
    Right _
        | label == "zero-age" -> die "offline-plan-mutant: RED drop_queue_bound locus=queue-age-bound"
        | label == "queue-model-invocation" -> die "offline-plan-mutant: RED queue_model_invocation locus=model-invocation-classification"
        | otherwise -> die (label <> " unexpectedly accepted")

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

requireCompiled :: String -> Either OfflinePlanError value -> IO value
requireCompiled label result = case result of
    Right value -> pure value
    Left PlanKeyMismatch -> die "offline-plan-mutant: RED omit_server_handler locus=paired-plan-keys"
    Left problem -> die (label <> ": " <> show problem)

checkPrivateFields :: ClientPlan -> IO ()
checkPrivateFields client
    | leakedPrivateFields client == [] = pure ()
    | leakedPrivateFields client == ["authority-policy"] = die "offline-plan-mutant: RED persist_private_field locus=public-plan-private-fields"
    | otherwise = die ("unexpected private fields: " <> show (leakedPrivateFields client))

checkMechanisms :: IO ()
checkMechanisms
    | mechanismConstructors == [] = pure ()
    | mechanismConstructors == ["IndexedDB", "Redis"] = die "offline-plan-mutant: RED browser_redis_constructor locus=authored-mechanism-surface"
    | otherwise = die ("unexpected mechanism constructors: " <> show mechanismConstructors)

checkCalculus :: IO ()
checkCalculus = do
    tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "offline-plan-calculus-tenant")
    subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "offline-plan-calculus-subject")
    membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
    action <- requireRight "calculus request scope" $ CalculusScope.withRequestScope tenant subject membership $ \scope -> do
        let resources :: Int -> ResourceVector
            resources count = ResourceVector 1 (fromIntegral count) 0 0
            counts = [2, 9, 16, 8, 5] :: [Int]
            artifact = artifactComponent scope "offline-plan-artifacts" (resources 2) (RecipeId "offline-language-plan" 2)
            budget = budgetComponent scope "bounded-queue-contract" (resources 9) (allowance (Bytes 9) (Slots 1) (Bytes 9))
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
        assertEqual "offline-plan calculus projection" Cases.calculusRows actual
    action

renderPort :: PortId -> String
renderPort (PortId value) = Text.unpack value

uniqueSorted :: Ord value => [value] -> [value]
uniqueSorted = foldr add [] . sort
  where
    add value values = case values of first : _ | first == value -> values; _ -> value : values

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label = either (die . ((label <> ": ") <>) . show) pure

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
