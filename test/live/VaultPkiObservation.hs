{-# LANGUAGE OverloadedStrings #-}

module VaultPkiObservation (verifyObservations) where

import Control.Monad (forM, forM_, unless)
import Data.Aeson (FromJSON, Object, Value (Object), eitherDecode, eitherDecodeFileStrict', object, withObject, (.:), (.=))
import Data.Aeson.Key (Key)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy.Char8 qualified as Bytes
import Data.Either (isLeft, isRight)
import Data.List (nub, sort)
import Data.Maybe (fromMaybe, listToMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import System.Exit (die)
import System.FilePath ((</>), takeDirectory)
import Text.Read (readMaybe)

at :: Object -> Key -> Parser Object
at parent name = parent .: name >>= withObject "observation object" pure

require :: Bool -> String -> Parser ()
require condition label = unless condition (fail label)

equal :: (Eq value, FromJSON value) => Object -> Key -> value -> Parser ()
equal parent name expected = do
  actual <- parent .: name
  require (actual == expected) ("unexpected observation: " <> Key.toString name)

truth :: Object -> Key -> Parser ()
truth parent name = equal parent name True

integer :: Object -> Key -> Parser Integer
integer = (.:)

verifyObservations :: FilePath -> Value -> IO ()
verifyObservations evidencePath evidence = do
  verifyCheckpointPolicy
  let folder = takeDirectory evidencePath </> "observers"
      summaryPath = folder </> "storage-summary.json"
  summary <- either die pure =<< eitherDecodeFileStrict' summaryPath
  traceBytes <- Bytes.readFile (folder </> "storage.jsonl")
  trace <- traverse (either die pure . eitherDecode) (Bytes.lines traceBytes)
  either die pure (parseEither (verifyAll summaryPath summary trace) evidence)

verifyAll :: FilePath -> Value -> [Value] -> Value -> Parser ()
verifyAll summaryPath summary trace = withObject "Vault evidence" $ \evidence -> do
  challenge <- at evidence "challenge"
  truth challenge "issuedAfterSubjectStart"
  truth challenge "absentBeforeWrite"
  nonce <- challenge .: "nonceSha256" :: Parser Text
  require (Text.length nonce == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) nonce) "fresh challenge digest absent"
  prompt <- at evidence "promptWrite"
  forM_ ["ownScopeSuccess", "foreignScopeDenied", "forbiddenStateAbsent", "stdinOnly", "writerPodRemoved"] (truth prompt)
  readiness <- at evidence "secretDependentReadiness"
  forM_ ["missingFieldDenied", "unreadyWhileSealed", "readyAfterUnseal", "presenceOnly"] (truth readiness)
  envelope <- at evidence "unlockEnvelope"
  scan <- at envelope "externalSurfaceObservation"
  truth scan "clean"
  scanDigest <- scan .: "needleSha256" :: Parser Text
  require (Text.length scanDigest == 64) "external secret scan challenge absent"
  surfaces <- at scan "surfaces"
  host <- at surfaces "ownedHostState"
  verifyScan host
  scannedBytes <- integer host "bytes"
  require (scannedBytes >= 201326592) "external scan omitted raw retained backing"
  at surfaces "runOutput" >>= verifyScan
  pods <- surfaces .: "podFilesystems" :: Parser [Value]
  require (length pods == 2) "external scan omitted a pod filesystem"
  forM_ pods (withObject "pod scan" verifyScan)
  processes <- surfaces .: "processState" :: Parser [Value]
  require (not (null processes)) "external scan omitted process state"
  forM_ processes $ withObject "process scan" $ \row -> do
    equal row "processes" (1 :: Int)
    equal row "matches" (0 :: Integer)
  lifecycle <- at surfaces "processLifecycle"
  zombies <- integer lifecycle "zombieProcesses"
  vanished <- integer lifecycle "vanishedProcesses"
  require (zombies >= 0 && vanished >= 0) "invalid process-lifecycle observation"
  storage <- at evidence "storage"
  negative <- at storage "negativeBoundary"
  before <- negative .: "before" :: Parser Value
  after <- negative .: "after" :: Parser Value
  require (before == after) "pre-allocation rejection wrote state"
  withObject "negative boundary" (\row -> do
      equal row "retainedRootPresent" False
      equal row "poolImagePresent" False
      equal row "kindClusters" ([] :: [Text])) before
  equal negative "storageEffects" (0 :: Int)
  equal negative "apiEffects" (0 :: Int)
  equal negative "reasons" (["DurableBackingTooSmall", "AuditBackingTooSmall", "VaultDurableUsableTooSmall", "VaultAuditUsableTooSmall"] :: [Text])
  reasons <- negative .: "reasons" :: Parser [Text]
  equal negative "executionSupply" ([1000, 1073741824, 134217728, 2] :: [Integer])
  operands <- negative .: "positiveOperands" :: Parser [Integer]
  require (operands == [134217728, 67108864, 2023424, 4194304]) "unexpected positive storage boundary"
  positiveProjection <- negative .: "positiveProjection" :: Parser Value
  cases <- negative .: "cases" :: Parser [Value]
  let deltas = [[-1048576, 0, 0, 0], [0, -1048576, 0, 0], [0, 0, -1, 0], [0, 0, 0, -1]]
  require (length cases == 4) "storage negative pair missing"
  forM_ (zip3 cases deltas reasons) $ \(value, expectedDelta, reason) -> withObject "paired storage case" (\row -> do
    equal row "reason" reason
    actual <- row .: "operands" :: Parser [Integer]
    require (length actual == 4 && zipWith (-) actual operands == expectedDelta) "storage negative changes another dimension") value
  bounds <- at storage "run1HighWater"
  installation <- at bounds "snapshotInstall"
  oldInode <- integer installation "oldInode"
  newInode <- integer installation "newInode"
  require (oldInode > 0 && newInode > 0 && oldInode /= newInode) "snapshot did not replace active FSM"
  truth installation "restoredPopulationVerified"
  forM_ ["compactionExternallyObserved", "recoveryExternallyObserved", "automaticRotationObserved", "realClockRetentionBoundaryObserved"] (truth bounds)
  checkpoints <- bounds .: "raftLogCheckpoints" :: Parser [Value]
  require (length checkpoints == 3) "two Raft compactions were not observed"
  indexes <- traverse (withObject "Raft log checkpoint" (verifyCheckpoint [])) checkpoints
  require (and (zipWith (<) (map fst indexes) (drop 1 (map fst indexes)))) "Raft log prefix did not compact"
  burned <- snapshotBurnedIndex summary
  shutdown <- at bounds "logIndexesAtShutdown" >>= verifyCheckpoint [burned]
  recovered <- at bounds "logIndexesAfterRecovery" >>= verifyCheckpoint [burned]
  require (snd recovered >= snd shutdown && all ((<= snd shutdown) . snd) indexes) "committed Raft suffix was not recovered"
  observer <- at storage "observer"
  equal observer "summary" summaryPath
  require (Object (KeyMap.delete "summary" observer) == summary) "copied storage summary differs from external observer"
  verifyTrace summary trace bounds
  manifest <- at evidence "manifestProjection"
  service1 <- at manifest "serviceRun1" >>= (.: "sealed")
  service2 <- at manifest "serviceRun2" >>= (.: "sealed")
  applied1 <- at manifest "appliedRun1"
  applied2 <- at manifest "appliedRun2"
  truth applied1 "completeMatch"
  truth applied2 "completeMatch"
  equal applied1 "sealed" (service1 :: Value)
  equal applied2 "sealed" (service1 :: Value)
  require (service1 == service2) "service seal changed during recreation"
  require (positiveProjection == service1) "pre-allocation positive differs from the live service seal"
  let normalized = object
        [ "requests" .= object ["cpu" .= (100 :: Int), "memory" .= (134217728 :: Int), "ephemeral-storage" .= (33554432 :: Int)]
        , "limits" .= object ["cpu" .= (500 :: Int), "memory" .= (536870912 :: Int), "ephemeral-storage" .= (67108864 :: Int)]
        ]
  equal applied1 "normalizedResources" normalized
  equal applied2 "normalizedResources" normalized
  withObject "sealed Vault service" (\sealed -> do
      equal sealed "controller" ("StatefulSet" :: Text)
      equal sealed "replicas" (1 :: Int)
      equal sealed "executionUnit" ("root-vault" :: Text)
      equal sealed "executionRoles" (["vault-server", "vault-init-exec", "audit-writer"] :: [Text])
      equal sealed "cache" ("None" :: Text)
      equal sealed "accelerator" ("None" :: Text)
      equal sealed "writableBytes" (8388608 :: Integer)
      equal sealed "logBytes" (4194304 :: Integer)
      scratch <- at sealed "scratch"
      equal scratch "bytes" (16777216 :: Integer)
      equal scratch "path" ("/tmp" :: Text)
      logs <- at sealed "logPolicy"
      equal logs "maximumFileBytes" (1048576 :: Int)
      equal logs "maximumFiles" (3 :: Int)) service1

verifyScan :: Object -> Parser ()
verifyScan row = do
  count <- integer row "files"
  bytes <- integer row "bytes"
  require (count > 0 && bytes > 0) "empty external secret surface scan"
  equal row "matches" (0 :: Integer)

verifyCheckpoint :: [Integer] -> Object -> Parser (Integer, Integer)
verifyCheckpoint allowedMissing row = do
  low <- integer row "lowestLogIndex"
  high <- integer row "highestLogIndex"
  count <- integer row "logEntryCount"
  transaction <- integer row "metaTransactionId"
  bytes <- integer row "databaseBytes"
  indexes <- row .: "logIndexes" :: Parser [Integer]
  require (low > 0 && high >= low && transaction > 0 && bytes > 0 && bytes <= 134217728
    && listToMaybe indexes == Just low && listToMaybe (reverse indexes) == Just high
    && count == toInteger (length indexes) && and (zipWith (<) indexes (drop 1 indexes))) "invalid external Raft checkpoint"
  let expectedMissing = sort (filter (\index -> index >= low && index <= high) allowedMissing)
      missingCount = high - low + 1 - count
  require (missingCount == toInteger (length expectedMissing)) "unexpected Raft gap count"
  let actualMissing = concat (zipWith (\left right -> [left + 1 .. right - 1]) indexes (drop 1 indexes))
  require (actualMissing == expectedMissing) "Raft gap is not the observed snapshot restore index"
  pure (low, high)

verifyCheckpointPolicy :: IO ()
verifyCheckpointPolicy = do
  let checkpoint :: [Integer] -> Value
      checkpoint indexes = object
        [ "lowestLogIndex" .= fromMaybe 0 (listToMaybe indexes), "highestLogIndex" .= fromMaybe 0 (listToMaybe (reverse indexes))
        , "logEntryCount" .= length indexes, "logIndexes" .= indexes
        , "metaTransactionId" .= (1 :: Integer), "databaseBytes" .= (4096 :: Integer)]
      parse allowed = parseEither (withObject "checkpoint policy" (verifyCheckpoint allowed)) . checkpoint
      checks =
        [ isRight (parse [] [5, 6, 7]), isRight (parse [6] [5, 7])
        , isLeft (parse [] [5, 7]), isLeft (parse [7] [5, 7, 8])
        , isLeft (parse [6] [5, 6, 7]), isLeft (parse [6] [5, 5, 7]) ]
  unless (and checks) (die "Raft checkpoint policy self-check failed")

snapshotBurnedIndex :: Value -> Parser Integer
snapshotBurnedIndex = withObject "snapshot restore observation" $ \record -> do
  paths <- record .: "installingSnapshotDatabasesObserved" :: Parser [Text]
  indexes <- forM paths $ \path -> case Text.splitOn "/" path of
    ["raft", "raft", "snapshots", generation, "vault.db"] -> case Text.splitOn "-" generation of
      [term, index, stamp] ->
        let instant = fromMaybe stamp (Text.stripSuffix ".tmp" stamp)
         in case traverse (readMaybe . Text.unpack) [term, index, instant] :: Maybe [Integer] of
              Just [t, i, n] | all (> 0) [t, i, n] -> pure i
              _ -> fail "invalid snapshot identity"
      _ -> fail "invalid snapshot generation"
    _ -> fail "snapshot outside the pinned Raft layout"
  case nub indexes of
    [index] -> pure index
    _ -> fail "exactly one snapshot restore index must be observed"

verifyTrace :: Value -> [Value] -> Object -> Parser ()
verifyTrace summary trace bounds = withObject "storage summary" (\record -> do
    require (length trace >= 2) "storage observer raw trace absent"
    samples <- integer record "samples"
    require (samples >= toInteger (length trace)) "storage observer sample count invalid"
    baseline <- at record "baseline"
    peaks <- at record "peakDataAllocatedBytes"
    observed <- forM trace $ withObject "storage sample" $ \sample -> do
      volumes <- at sample "volumes"
      vault <- at volumes "vault"
      audit <- at volumes "vault-audit"
      files <- at audit "files"
      let allowed = ["audit.log", "audit.log.1", "audit.log.2", "audit.log.3"]
      require (all (`elem` allowed) (KeyMap.keys files)) "unexpected audit file outside policy"
      forM_ (KeyMap.elems files) $ withObject "audit file" $ \file -> do
        size <- integer file "sizeBytes"
        require (size <= 1048576) "raw audit byte ceiling exceeded"
      vaultUsed <- integer vault "filesystemUsedBytes"
      auditUsed <- integer audit "filesystemUsedBytes"
      vaultFiles <- at vault "files"
      incoming <- installingDatabases vaultFiles
      pure (vaultUsed, auditUsed, incoming)
    baselineVault <- at baseline "vault" >>= (\row -> integer row "filesystemUsedBytes")
    baselineAudit <- at baseline "vault-audit" >>= (\row -> integer row "filesystemUsedBytes")
    let vaultPeak = maximum (map (\(value, _, _) -> value) observed) - baselineVault
        auditPeak = maximum (map (\(_, value, _) -> value) observed) - baselineAudit
        databases = maximum (map (\(_, _, value) -> if null value then 0 else 1 + length value) observed)
        paths = sort (nub (concatMap (\(_, _, value) -> value) observed))
    require (vaultPeak >= 0 && auditPeak >= 0 && databases >= 2) "raw high-water/snapshot observation incomplete"
    equal peaks "vault" vaultPeak
    equal peaks "vault-audit" auditPeak
    equal bounds "raftHighWaterBytes" vaultPeak
    equal bounds "auditHighWaterBytes" auditPeak
    equal record "installingSnapshotDatabasesObserved" paths
    equal record "maximumSimultaneousFsmDatabases" databases) summary

installingDatabases :: Object -> Parser [Text]
installingDatabases files = case KeyMap.lookup "raft/vault.db" files of
  Nothing -> pure []
  Just value -> withObject "active FSM file" (\active -> do
    activeInode <- integer active "inode"
    activeDevice <- integer active "device"
    activeBytes <- integer active "allocatedBytes"
    incoming <- forM (KeyMap.toList files) $ \(name, metadata) -> do
      let parts = Text.splitOn "/" (Key.toText name)
      if length parts == 5 && take 3 parts == ["raft", "raft", "snapshots"] && last parts == "vault.db"
        then withObject "incoming snapshot file" (\file -> do
          inode <- integer file "inode"
          device <- integer file "device"
          bytes <- integer file "allocatedBytes"
          pure (if activeBytes > 0 && bytes > 0 && (inode, device) /= (activeInode, activeDevice) then [Key.toText name] else [])) metadata
        else pure []
    pure (concat incoming)) value
