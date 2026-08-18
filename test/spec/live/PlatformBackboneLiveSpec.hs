{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON, Result (Error, Success), Value (Object), eitherDecodeFileStrict', fromJSON)
import Data.Aeson.Key (Key)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Text (Text)
import Data.Text qualified as Text
import System.Environment (lookupEnv)
import System.Exit (die)

main :: IO ()
main = do
  evidencePath <- requireEnvironment "AMOEBIUS_PLATFORM_BACKBONE_EVIDENCE"
  expectedDigest <- Text.pack <$> requireEnvironment "AMOEBIUS_PLATFORM_BACKBONE_IMAGE_DIGEST"
  decoded <- eitherDecodeFileStrict' evidencePath
  evidence <- either die pure decoded
  either die pure (verify expectedDigest evidence)
  putStrLn "platform-backbone-live-spec: PASS (external VIP, object migration, native dedup/offload, runtime provenance)"

requireEnvironment :: String -> IO String
requireEnvironment name = lookupEnv name >>= maybe (die (name <> " is required")) pure

verify :: Text -> Value -> Either String ()
verify expectedDigest evidence = do
  equal ["register"] (3 :: Int)
  equal ["substrate"] ("linux-cpu" :: Text)
  equal ["artifactSource", "digest"] expectedDigest
  equal ["artifactSource", "imagePullPolicy"] ("Never" :: Text)
  equal ["artifactSource", "publicPulls"] (0 :: Int)
  equal ["artifactSource", "pullEvents", "observer"] ("kind-node-containerd-log-window" :: Text)
  equal ["artifactSource", "pullEvents", "publicPullEventCount"] (0 :: Int)
  true ["loadBalancer", "externallyReachable"]
  atLeast ["loadBalancer", "stableReadyObservations"] 5
  equal ["metallb", "controller"] ("Ready" :: Text)
  equal ["metallb", "speaker"] ("Ready" :: Text)
  equal ["minio", "topology"] ("distributed-erasure-four-drive" :: Text)
  equal ["minio", "replicas"] (1 :: Int)
  listLength ["minio", "volumes"] 4
  true ["minioRoundtrip", "byteIdentical"]
  equal ["registryRehome", "backend"] ("s3" :: Text)
  true ["registryRehome", "migration", "verified"]
  true ["registryRehome", "sourceHashStable"]
  equal ["pulsar", "zookeeper", "replicas"] (3 :: Int)
  equal ["pulsar", "zookeeper", "readyPods"] (3 :: Int)
  equal ["pulsar", "bookkeeper", "replicas"] (3 :: Int)
  equal ["pulsar", "bookkeeper", "readyPods"] (3 :: Int)
  equal ["pulsar", "bookkeeper", "ensemble"] (3 :: Int)
  equal ["pulsar", "bookkeeper", "writeQuorum"] (2 :: Int)
  equal ["pulsar", "bookkeeper", "ackQuorum"] (2 :: Int)
  equal ["pulsar", "broker", "replicas"] (2 :: Int)
  equal ["pulsar", "broker", "readyPods"] (2 :: Int)
  false ["pulsar", "broker", "webSocketUsed"]
  false ["pulsar", "broker", "developmentOffloaderMount"]
  positive ["pulsar", "broker", "bakedOffloaderFileCount"]
  true ["pulsar", "vaultReadyEdge", "initialized"]
  false ["pulsar", "vaultReadyEdge", "sealed"]
  true ["pulsar", "vaultReadyEdge", "observedBeforePulsar"]
  true ["pulsar", "drill", "nativeRoundtrip"]
  true ["pulsar", "drill", "deduplicationExercised"]
  true ["pulsar", "drill", "cborByteIdentical"]
  equal ["pulsar", "drill", "sequenceIds"] ([7, 7, 8] :: [Int])
  equal ["pulsar", "drill", "deliveredMessages"] (2 :: Int)
  contains ["pulsar", "drill", "dedupProbeOutput"] "platform-backbone-dedup-probe: PASS"
  true ["pulsar", "drill", "producerExited"]
  contains ["pulsar", "drill", "producerOutputMarker"] "100 messages successfully produced"
  false ["pulsar", "drill", "offload", "timeOnly"]
  true ["pulsar", "drill", "offload", "bounded"]
  equal ["pulsar", "drill", "offload", "configuredSizeTriggerBytes"] (65536 :: Integer)
  positive ["pulsar", "drill", "offload", "objectCount"]
  cap <- get ["pulsar", "drill", "offload", "hotTierCapBytes"] evidence
  hot <- get ["pulsar", "drill", "offload", "hotTierBytes"] evidence
  unless (hot <= (cap :: Integer)) (Left "external hot-tier observation exceeded cap")
  true ["provenance", "allRuntimeImageIdsMatchBaseDigest"]
  true ["provenance", "completeResourceFields"]
  true ["provenance", "ssaProjection", "allOwnedFieldsByteIdentical"]
  equal ["provenance", "ssaProjection", "fieldManager"] ("amoebius" :: Text)
  positive ["provenance", "ssaProjection", "objectCount"]
  true ["provenance", "haskellRenderProjection", "freshGateProcessOutput"]
  true ["provenance", "haskellRenderProjection", "allAppliedProjectionsByteIdentical"]
  equal ["provenance", "haskellRenderProjection", "objectCount"] (11 :: Int)
  equal ["provenance", "publicImageReferences"] ([] :: [Text])
  imageIds <- get ["provenance", "runtimeImageIds"] evidence :: Either String [Text]
  unless (not (null imageIds) && all (expectedDigest `Text.isInfixOf`) imageIds) (Left "runtime imageID digest drifted")
  equal ["deferred", "keycloak"] ("UNVERIFIED" :: Text)
  equal ["deferred", "phase31Services"] ("UNVERIFIED" :: Text)
  equal ["deferred", "controlPlaneOwnedReconcile"] ("UNVERIFIED" :: Text)
  true ["universalLinuxCpu", "availableOnEveryHardwareSubstrate"]
  equal ["universalLinuxCpu", "pristineLinuxHost", "linux"] ("Incus" :: Text)
  equal ["universalLinuxCpu", "pristineLinuxHost", "linux-cuda"] ("Incus" :: Text)
  equal ["universalLinuxCpu", "pristineLinuxHost", "apple"] ("Lima" :: Text)
  equal ["universalLinuxCpu", "pristineLinuxHost", "windows"] ("WSL2" :: Text)
 where
  equal :: (Eq value, Show value, FromJSON value) => [Key] -> value -> Either String ()
  equal path expected = do
    actual <- get path evidence
    unless (actual == expected) (Left (showPath path <> ": expected " <> show expected <> ", got " <> show actual))
  true path = equal path True
  false path = equal path False
  atLeast path minimumValue = do
    actual <- get path evidence
    unless ((actual :: Int) >= minimumValue) (Left (showPath path <> ": below minimum"))
  positive path = atLeast path 1
  listLength path expected = do
    actual <- get path evidence
    unless (length (actual :: [Value]) == expected) (Left (showPath path <> ": wrong list length"))
  contains path needle = do
    actual <- get path evidence
    unless (needle `Text.isInfixOf` (actual :: Text)) (Left (showPath path <> ": marker absent"))

get :: FromJSON value => [Key] -> Value -> Either String value
get path value = do
  selected <- lookupPath path value
  case fromJSON selected of
    Error problem -> Left (showPath path <> ": " <> problem)
    Success decoded -> Right decoded

lookupPath :: [Key] -> Value -> Either String Value
lookupPath [] value = Right value
lookupPath (key : rest) (Object object) =
  maybe (Left (showPath (key : rest) <> ": absent")) (lookupPath rest) (KeyMap.lookup key object)
lookupPath path _ = Left (showPath path <> ": parent is not an object")

showPath :: [Key] -> String
showPath = Text.unpack . Text.intercalate "." . fmap (Text.pack . show)
