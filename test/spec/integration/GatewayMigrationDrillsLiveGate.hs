{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Multicluster.GatewayMigration
import Amoebius.Multicluster.PlannedHandover
import Amoebius.Multicluster.PromotionGate
import Control.Monad (unless, when)
import Data.Aeson (Value (..), eitherDecodeFileStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (sort)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import GatewayMigrationForest (expectedModeledActions)
import System.Environment (lookupEnv)
import System.Exit (die)

main :: IO ()
main = do
  verifyCustody
  verifyRuntimeCore
  pureOnly <- (== Just "1") <$> lookupEnv "GATEWAY_MIGRATION_DRILLS_PURE_ONLY"
  unless pureOnly verifyLive
  putStrLn "gateway-migration-drills-live: PASS (planned RPO=0, fenced failover, rebind, model actions, exact cleanup)"

verifyCustody :: IO ()
verifyCustody = do
  manifest <- TextIO.readFile "test/oracle/preimplementation_artifacts.tsv"
  let rows = filter (Text.isPrefixOf "43\t") (Text.lines manifest)
  require (length rows == 9) "Phase-44 custody cardinality"
  require (length (filter (Text.isInfixOf "\toracle\t") rows) == 7) "Phase-44 oracle custody"
  require (length (filter (Text.isInfixOf "\tmutant\t") rows) == 2) "Phase-44 mutant custody"

verifyRuntimeCore :: IO ()
verifyRuntimeCore = do
  require
    (plannedHandoverActions (WatermarkSnapshot 24 16) == Left TargetNotCaughtUp)
    "gateway-migration-drills-verify-caught-up: lagging target admitted"
  require
    (authorizePromotion (PromotionEvidence False False 1 5) == Left PromotionFreshnessUnproven)
    "gateway-migration-drills-promote-before-fence: unfenced survivor promoted"
  planned <- either die pure (runModelTrace
    [ "StartPlanned", "StandUpReplica", "Quiesce", "VerifyCaughtUp", "PromotePlanned"
    , "RepointPlannedDns", "Unfreeze", "DrainMonitor", "DecommissionSource"
    ])
  verdicts <- either die pure (traceSatisfiesNamedInvariants planned)
  require (all snd verdicts) "planned runtime trace violated a Phase-3 invariant"

verifyLive :: IO ()
verifyLive = do
  evidence <- decode "DEVELOPMENT_PLAN/evidence/phase_43/gateway-migration-live.json"
  require (path ["schema"] evidence == Just (String "amoebius.phase43.gateway-migration-live.v1")) "live schema"
  require (path ["register"] evidence == Just (Number 3)) "live register"
  require (path ["substrate"] evidence == Just (String "linux-cpu")) "live substrate"
  forEachTrue evidence
    [ ["forest", "ready"]
    , ["planned", "rpoZeroBySetEquality"]
    , ["planned", "sessionAlwaysRebindable"]
    , ["failover", "boundedByBudget"]
    , ["failover", "sessionRebound"]
    , ["wireGuardHubMove", "rawKernel"]
    , ["modelCorrespondence", "allFiveSafetyInvariantsAsserted"]
    , ["teardown", "exact"]
    , ["universalLinuxCpu", "availableOnEveryHardwareSubstrate"]
    ]
  require (path ["planned", "acknowledged"] evidence == Just (Number 24)) "planned acknowledged count"
  require (path ["planned", "unreplicatedAtCut"] evidence == Just (Number 8)) "planned positive lag count"
  require (path ["planned", "permanentLoss"] evidence == Just (Number 0)) "planned RPO"
  require (path ["failover", "unreplicatedAtKill"] evidence == Just (Number 8)) "failover positive lag count"
  require (path ["failover", "permanentLoss"] evidence == Just (Number 0)) "failover reconciliation"
  require (numberAt ["failover", "observedLagSeconds"] evidence <= 5) "failover lag bound"
  require (numberAt ["failover", "measuredRtoSeconds"] evidence <= 60) "failover RTO"
  require (path ["teardown", "survivingTestClusters"] evidence == Just (Number 0)) "cluster residue"
  require (path ["teardown", "survivingMigrationDnsRecords"] evidence == Just (Number 0)) "DNS residue"
  require
    (path ["deferred", "route53ProviderApi"] evidence == Just (String "UNVERIFIED (configured AWS token invalid; authoritative local DNS drilled)"))
    "Route53 honesty marker"
  require (path ["universalLinuxCpu", "pristineLinuxHost", "linux"] evidence == Just (String "Incus")) "Linux pristine route"
  require (path ["universalLinuxCpu", "pristineLinuxHost", "linux-cuda"] evidence == Just (String "Incus")) "Linux-CUDA pristine route"
  require (path ["universalLinuxCpu", "pristineLinuxHost", "apple"] evidence == Just (String "Lima")) "Apple pristine route"
  require (path ["universalLinuxCpu", "pristineLinuxHost", "windows"] evidence == Just (String "WSL2")) "Windows pristine route"
  let expectedActions = sort expectedModeledActions
  require (sort (stringsAt ["modelCorrespondence", "modeledActionsCovered"] evidence) == expectedActions) "modeled action coverage"

forEachTrue :: Value -> [[Text]] -> IO ()
forEachTrue value paths = mapM_ (\segments -> require (path segments value == Just (Bool True)) ("false/missing: " <> show segments)) paths

numberAt :: [Text] -> Value -> Double
numberAt segments value = case path segments value of
  Just (Number number) -> realToFrac number
  _ -> 1 / 0

stringsAt :: [Text] -> Value -> [String]
stringsAt segments value = case path segments value of
  Just (Array values) -> [Text.unpack item | String item <- foldr (:) [] values]
  _ -> []

decode :: FilePath -> IO Value
decode file = eitherDecodeFileStrict' file >>= either die pure

path :: [Text] -> Value -> Maybe Value
path [] value = Just value
path (segment : rest) (Object fields) = KeyMap.lookup (Key.fromText segment) fields >>= path rest
path _ _ = Nothing

require :: Bool -> String -> IO ()
require condition message = when (not condition) (die message)
