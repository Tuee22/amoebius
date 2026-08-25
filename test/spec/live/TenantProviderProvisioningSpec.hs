{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Tenancy.Provider.KubernetesApi qualified as KubernetesApi
import Amoebius.Tenancy.Provider.Keycloak qualified as Keycloak
import Amoebius.Tenancy.Provider.Minio qualified as Minio
import Amoebius.Tenancy.Provider.Postgres qualified as Postgres
import Amoebius.Tenancy.Provider.Pulsar qualified as Pulsar
import Amoebius.Tenancy.Provider.Vault qualified as Vault
import Amoebius.Tenancy.ProviderProjection
import Amoebius.Tenancy.ProviderTransaction
import Control.Monad (unless)
import Data.Aeson (FromJSON, eitherDecodeFileStrict')
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import GHC.Generics (Generic)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.Process (callProcess)

data ProviderEvidence = ProviderEvidence
  { provider :: Text
  , tenant :: Text
  , objectTypes :: [Text]
  , challengeRecovered :: Bool
  , rawObservationSha256 :: Text
  }
  deriving stock (Generic, Show)

instance FromJSON ProviderEvidence

data ObserverEvidence = ObserverEvidence
  { observerProvider :: Text
  , identity :: Text
  , authenticated :: Bool
  , credentialReused :: Bool
  }
  deriving stock (Generic, Show)

instance FromJSON ObserverEvidence

data RejectedEvidence = RejectedEvidence
  { tag :: Text
  , providerEffects :: Int
  , forbiddenNonceAbsentAllProviders :: Bool
  }
  deriving stock (Generic, Show)

instance FromJSON RejectedEvidence

data CleanupEvidence = CleanupEvidence
  { inventoriesEqual :: Bool
  , residue :: [Text]
  }
  deriving stock (Generic, Show)

instance FromJSON CleanupEvidence

data Evidence = Evidence
  { schemaVersion :: Text
  , providers :: [ProviderEvidence]
  , observers :: [ObserverEvidence]
  , rejectedTwins :: [RejectedEvidence]
  , cleanup :: CleanupEvidence
  , applicationDataPath :: Text
  }
  deriving stock (Generic, Show)

instance FromJSON Evidence

main :: IO ()
main = do
  legal <- decodeFixture "test/fixture/app_tenancy/legal-tenant-graph.json"
  checked <- requireRight (decodeCheckedTenantGraph legal)
  derivation <- requireProjection (deriveTenantPolicy checked)
  let actions = derivationActions derivation
  assertEqual "derived action count" 18 (length actions)
  assertEqual "provider arms" (Set.fromList [minBound .. maxBound]) (Set.fromList (map actionProvider actions))
  assertEqual "qualified keys" 18 (Set.size (Set.fromList (map actionQualifiedKey actions)))
  checkMatrix actions
  checkIllegalFixtures
  checkProvision derivation
  reuse <- lookupEnv "APP_TENANCY_REUSE_FRESH_LIVE"
  callProcess "python3" (["tools/app_tenancy_live.py"] <> ["--reuse-fresh-live" | reuse == Just "1"])
  evidence <- either die pure =<< eitherDecodeFileStrict' "DEVELOPMENT_PLAN/evidence/phase_34/tenant-provider-live.json"
  checkEvidence evidence
  putStrLn "tenant-provider-provisioning-live: PASS (sealed total derivation, six authenticated provider readbacks, paired zero-effect rejects, teardown)"

decodeFixture :: FilePath -> IO RawTenantGraph
decodeFixture path = either die pure =<< eitherDecodeFileStrict' path

requireRight :: Show errorValue => Either errorValue value -> IO value
requireRight = either (die . show) pure

requireProjection :: Either ProjectionError value -> IO value
requireProjection = either (die . Text.unpack . renderProjectionError) pure

checkIllegalFixtures :: IO ()
checkIllegalFixtures = do
  authored <- decodeFixture "test/fixture/app_tenancy/illegal-hand-authored-grant.json"
  mismatch <- decodeFixture "test/fixture/app_tenancy/illegal-tenant-mismatch.json"
  assertLeft "hand-authored" isHandAuthored (decodeCheckedTenantGraph authored)
  assertLeft "tenant mismatch" isMismatch (decodeCheckedTenantGraph mismatch)
 where
  isHandAuthored (HandAuthoredProviderGrant _) = True
  isHandAuthored _ = False
  isMismatch (TenantReferenceMismatch _ _) = True
  isMismatch _ = False

checkProvision :: TenantPolicyDerivation -> IO ()
checkProvision derivation = do
  let exact = ProvisionBudget 18 4096
  provisioned <- requireRight (provisionTenantPolicy exact derivation)
  assertEqual "provisioned actions" 18 (length provisioned)
  assertLeft "slot one-short" isSlotShort (provisionTenantPolicy (exact {providerActionSlots = 17}) derivation)
  target <- requireRight (validateProviderTarget "fresh-challenge-1234" "epoch-1")
  assertEqual "sealed render" (derivationActions derivation) (map (renderProvisionedAction target) provisioned)
 where
  isSlotShort (ProviderActionSlotsShort 18 17) = True
  isSlotShort _ = False

checkMatrix :: [ProjectionAction] -> IO ()
checkMatrix actions = do
  source <- TextIO.readFile "test/fixture/app_tenancy/provider_projection_matrix.tsv"
  let rows = map (Text.splitOn "\t") (drop 1 (Text.lines source))
      matrix = Map.fromListWith Set.union [(providerName, Set.singleton objectType) | (_ : providerName : objectType : _) <- rows]
      expected = providerObjectTypes
      observed = Map.fromListWith Set.union [(providerText (actionProvider action), Set.singleton (actionObjectType action)) | action <- actions]
  assertEqual "matrix modules" expected matrix
  assertEqual "matrix derivation" expected observed

providerObjectTypes :: Map Text (Set Text)
providerObjectTypes =
  Map.fromList
    [ ("Keycloak", Keycloak.objectTypes)
    , ("Vault", Vault.objectTypes)
    , ("Pulsar", Pulsar.objectTypes)
    , ("Minio", Minio.objectTypes)
    , ("KubernetesApi", KubernetesApi.objectTypes)
    , ("Postgres", Postgres.objectTypes)
    ]

checkEvidence :: Evidence -> IO ()
checkEvidence evidence = do
  assertEqual "evidence schema" "amoebius.phase34.live-evidence.v1" (schemaVersion evidence)
  assertEqual "provider observations" 12 (length (providers evidence))
  assertEqual "provider names" (Set.fromList (Map.keys providerObjectTypes)) (Set.fromList (map provider (providers evidence)))
  unless (all challengeRecovered (providers evidence)) (die "provider challenge not recovered")
  unless (all (("sha256:" `Text.isPrefixOf`) . rawObservationSha256) (providers evidence)) (die "provider observation digest absent")
  assertEqual "observer count" 6 (length (observers evidence))
  assertEqual "observer identities" 6 (Set.size (Set.fromList (map identity (observers evidence))))
  unless (all authenticated (observers evidence) && all (not . credentialReused) (observers evidence)) (die "observer authority separation")
  assertEqual "rejected twins" 2 (length (rejectedTwins evidence))
  unless (all (\row -> providerEffects row == 0 && forbiddenNonceAbsentAllProviders row) (rejectedTwins evidence)) (die "illegal twin provider effect")
  unless (inventoriesEqual (cleanup evidence) && null (residue (cleanup evidence))) (die "provider cleanup residue")
  assertEqual "application isolation honesty" "UNVERIFIED (Phase 37)" (applicationDataPath evidence)

assertLeft :: String -> (errorValue -> Bool) -> Either errorValue value -> IO ()
assertLeft label predicate result =
  case result of
    Left err | predicate err -> pure ()
    Left _ -> die (label <> ": wrong error")
    Right _ -> die (label <> ": unexpectedly accepted")

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual =
  unless (expected == actual) (die (label <> ": expected " <> show expected <> ", got " <> show actual))
