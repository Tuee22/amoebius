{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Monad (unless)
import Data.Aeson (FromJSON, Result (Error, Success), Value (Object), eitherDecodeFileStrict', fromJSON)
import Data.Aeson.Key (Key)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import System.Exit (die)

main :: IO ()
main = do
  decoded <- eitherDecodeFileStrict' "DEVELOPMENT_PLAN/evidence/phase_31/services-live.json"
  evidence <- either die pure decoded
  expectedDigest <- Text.strip <$> TextIO.readFile "test/fixtures/phase31/expected-base-digest.txt"
  shareFixture <- Text.words <$> TextIO.readFile "test/fixtures/phase31/postgres-share-package.sha256"
  expectedShare <- case shareFixture of
    digest : _ -> pure ("sha256:" <> digest)
    [] -> die "empty postgres share checksum fixture"
  either die pure (verify expectedDigest expectedShare evidence)
  putStrLn "phase31-services-live-spec: PASS (Patroni, pgAdmin, Redis failover, bounded Prometheus, Grafana/Postgres, readiness trace)"

verify :: Text -> Text -> Value -> Either String ()
verify expectedDigest expectedShare evidence = do
  equal ["schema"] ("amoebius.phase31.services-live.v1" :: Text)
  equal ["register"] (3 :: Int)
  equal ["substrate"] ("linux-cpu" :: Text)
  equal ["artifactSource", "digest"] expectedDigest
  equal ["artifactSource", "imagePullPolicy"] ("Never" :: Text)
  equal ["artifactSource", "publicPulls"] (0 :: Int)
  equal ["artifactSource", "pullEvents", "publicPullEventCount"] (0 :: Int)
  true ["vaultMaterial", "vaultSourced"]
  true ["operatorObservation", "operatorObservedCr"]
  true ["operatorObservation", "manualChildProjection"]
  equal ["postgres", "replicas"] (3 :: Int)
  equal ["postgres", "readyReplicas"] (3 :: Int)
  equal ["postgres", "mandatedConfiguration"] ("synchronous_mode: on\nsynchronous_mode_strict: on\nmaximum_lag_on_failover: 1048576\n" :: Text)
  true ["databaseSurfaces", "sqlGatewayReady"]
  true ["databaseSurfaces", "pgAdminReady"]
  true ["grafana", "ready"]
  equal ["grafana", "databaseType"] ("postgres" :: Text)
  positive ["grafana", "migrationRows"]
  equal ["redis", "redisReplicas"] (3 :: Int)
  equal ["redis", "sentinelVoters"] (3 :: Int)
  false ["redis", "persistence"]
  true ["redisBoundary", "tls"]
  true ["redisBoundary", "replicaReadback"]
  true ["redisBoundary", "failoverObserved"]
  positive ["redisBoundary", "challengeTtlRemainingSeconds"]
  true ["observability", "prometheusReady"]
  true ["observability", "queryProxyReady"]
  equal ["observability", "retentionBytes"] (67108864 :: Integer)
  equal ["monitoringBoundary", "queryProxyPositive"] (200 :: Int)
  equal ["monitoringBoundary", "queryProxyOneOverSeries"] (429 :: Int)
  equal ["monitoringBoundary", "directQueryFromGrafana"] ("DENIED" :: Text)
  atLeast ["monitoringBoundary", "activeTargets"] 3
  equal ["retainedStorage", "postgresShare", "packageSha256"] expectedShare
  equal ["readinessDag", "observer"] ("kubernetes-apiserver-status-readback-during-warm-reconciliation" :: Text)
  listLength ["readinessDag", "events"] 14
  equal ["readinessDag", "preconditionViolations"] ([] :: [Text])
  true ["provenance", "allRuntimeImageIdsMatchBaseDigest"]
  true ["provenance", "completeResourceFields"]
  equal ["provenance", "publicImageReferences"] ([] :: [Text])
  true ["provenance", "ssaProjection", "allOwnedFieldsByteIdentical"]
  equal ["provenance", "ssaProjection", "fieldManager"] ("amoebius" :: Text)
  positive ["provenance", "ssaProjection", "objectCount"]
  true ["provenance", "haskellProjection", "freshGateProcessOutput"]
  true ["provenance", "haskellProjection", "allAppliedProjectionsByteIdentical"]
  equal ["provenance", "haskellProjection", "objectCount"] (11 :: Int)
  imageIds <- get ["provenance", "runtimeImageIds"] evidence :: Either String [Text]
  unless (not (null imageIds) && all (expectedDigest `Text.isInfixOf`) imageIds) (Left "runtime imageID digest drifted")
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
