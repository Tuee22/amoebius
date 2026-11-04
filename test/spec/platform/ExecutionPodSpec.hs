{-# LANGUAGE OverloadedStrings #-}

module ExecutionPodSpec (verifyExecutionPods) where

import Amoebius.Capacity.Execution
import Amoebius.Capacity.Types
import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import System.Exit (die)

verifyExecutionPods :: IO ()
verifyExecutionPods = do
  corpus <- Lazy.readFile "test/oracle/platform_backbone_execution_pods.json" >>= right . eitherDecode
  cases <- right (parseEither (withObject "independent execution invariant" (.: "cases")) corpus)
  mapM_ verify (cases :: [Value])
 where
  verify value = do
    (name,units,available,expected,count,peak) <- right (parseEither row value)
    case provisionExecutionEpochs Map.empty available (BoundExecutionInventory FirstDeployment units) of
      Left problem -> unless (expected == ("reject" :: Text) && "pod" `Text.isInfixOf` Text.pack (show problem))
        (die ("independent pod reservation case " <> Text.unpack name <> ": " <> show problem))
      Right provision -> do
        unless (expected == "accept"
          && Map.size (provisionedDesiredSteady provision) == count && Just (provisionedExecutionPeak provision) == peak)
          (die ("independent pod reservation expectation: " <> Text.unpack name))
        let kubernetes = [executionUnitId bound | bound <- units, case executionBody bound of HostProcessBody{} -> False; _ -> True]
        unless (all (\instance' -> executionInstanceSource instance' `notElem` kubernetes
          || resourcePodSlots (executionInstanceResource instance') >= 1) (Map.elems (provisionedDesiredSteady provision)))
          (die ("emitted Kubernetes instance has no pod reservation: " <> Text.unpack name))
  row = withObject "literal pod reservation case" $ \fields -> do
    input <- fields .: "input"
    (units,available) <- withObject "execution input" (\source -> do
      transition <- source .: "transition" :: Parser Text
      unless (transition == "FirstDeployment") (fail "unsupported literal transition")
      (,) <$> (source .: "units" >>= traverse unit) <*> (source .: "available" >>= vector)) input
    peakValue <- fields .: "expectedPeak"
    peak <- if peakValue == Null then pure Nothing else Just <$> vector peakValue
    (,,,,,) <$> fields .: "id" <*> pure units <*> pure available <*> fields .: "expected"
      <*> fields .: "expectedEmittedInstances" <*> pure peak

unit :: Value -> Parser BoundExecutionUnit
unit = withObject "bound execution unit" $ \row -> do
  envelope <- row .: "envelope" >>= withObject "reserved resource envelope" (\fields -> do
    requests <- fields .: "requests" >>= vector
    limits <- fields .: "limits" >>= vector
    headroom <- fields .: "headroom" >>= vector
    either (fail . show) pure (mkResourceEnvelope requests limits headroom))
  controller <- row .: "body" >>= withObject "controller body" (\fields -> do
    kind <- fields .: "kind" :: Parser Text
    case kind of
      "Deployment" -> rollout fields "Recreate" >> DeploymentBody <$> fields .: "replicas" <*> pure recreateRollout
      "StatefulSet" -> rollout fields "OnDelete" >> StatefulSetBody <$> fields .: "replicas" <*> pure StatefulSetOnDelete
      "DaemonSet" -> rollout fields "OnDelete" >> DaemonSetBody <$> fields .: "slots" <*> pure DaemonSetOnDelete
      "Job" -> JobBody <$> fields .: "completions" <*> fields .: "parallelism" <*> fields .: "backoffLimit"
        <*> fields .: "terminalRetentionSeconds"
      "HostProcess" -> HostProcessBody <$> fields .: "slots" <*> fields .: "replacement"
      _ -> fail "unknown literal controller")
  BoundExecutionUnit <$> row .: "id" <*> row .: "revision" <*> pure envelope <*> pure controller
 where
  rollout fields expected = do
    actual <- fields .: "rollout" :: Parser Text
    unless (actual == expected) (fail "unsupported literal rollout")

vector :: Value -> Parser ResourceVector
vector = withObject "resource vector" $ \row -> ResourceVector
  <$> row .: "cpuMillis" <*> row .: "memoryBytes" <*> row .: "ephemeralBytes" <*> row .: "podSlots"

right :: Show problem => Either problem value -> IO value
right = either (die . show) pure
