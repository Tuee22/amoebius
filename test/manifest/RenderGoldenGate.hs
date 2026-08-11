{-# LANGUAGE OverloadedStrings #-}

module RenderGoldenGate
  ( printRenderGoldenOracle
  , runRenderGoldenGate
  ) where

import Amoebius.Capacity.Provision (ProvisionedSpec)
import Amoebius.Capacity.RenderSource (K8sObjectIdentity)
import Amoebius.Capability.Types (ServiceShape (..))
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.K8sObject
import BindFixtures (CapabilityFixture (..), capabilityFixtures)
import Control.Monad (forM, forM_, unless)
import Crypto.Hash.SHA256 qualified as SHA256
import Data.Aeson (eitherDecode, encode)
import Data.ByteString qualified as Strict
import Data.ByteString.Lazy (ByteString)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import Numeric (showHex)
import ProvisionFixtures (provisionFixture)
import RenderGoldenProps (renderInvariantFailures, runRenderGoldenProps)

runRenderGoldenGate :: IO ()
runRenderGoldenGate = do
  corpus <- fmap concat (mapM checkFixture capabilityFixtures)
  let objects = concatMap snd corpus
      variants = Set.fromList (fmap objectKind objects)
      expectedVariants =
        Set.fromList
          [ NamespaceKind
          , DeploymentKind
          , StatefulSetKind
          , DaemonSetKind
          , JobKind
          , ServiceKind
          , ConfigMapKind
          , NetworkPolicyKind
          , ValidatingWebhookConfigurationKind
          ]
      podCount = length [() | object <- objects, WorkloadSpec {} <- [objectSpec object]]
      policyCount = length [() | object <- objects, NetworkPolicySpec {} <- [objectSpec object]]
  assert (variants == expectedVariants) "render corpus no longer covers the exact nine emitted object variants"
  assert (podCount > 0 && policyCount > 0) "render safety predicates became vacuous"
  checkRoundTrip objects
  checkPureBoundary
  runRenderGoldenProps
  putStrLn "render-golden: PASS (18 byte-locked deployment goldens, 9 object variants, 3 non-vacuous safety predicates, 12 mutants, 1 covered property)"

checkFixture :: CapabilityFixture -> IO [(ProvisionedSpec, [K8sObject])]
checkFixture fixture = forM [SingleNode, Distributed 3] $ \shape -> do
  sealed <- either (fail . show) pure (provisionFixture fixture shape)
  let objects = renderAll sealed
      identities = fmap objectIdentity objects
      failures = renderInvariantFailures sealed objects
  assert (identities == Set.toAscList (Set.fromList identities)) "renderAll output is not in deterministic identity order"
  assert (null failures) ("render invariant failures: " <> show failures)
  expected <- Text.readFile (goldenPath fixture shape)
  let actual = goldenSummary objects
  assert (actual == expected) (goldenPath fixture shape <> " digest/byte-count golden drifted\nEXPECTED: " <> Text.unpack expected <> "ACTUAL: " <> Text.unpack actual)
  pure (sealed, objects)

printRenderGoldenOracle :: IO ()
printRenderGoldenOracle = forM_ capabilityFixtures $ \fixture -> forM_ [SingleNode, Distributed 3] $ \shape -> do
  sealed <- either (fail . show) pure (provisionFixture fixture shape)
  Text.putStrLn (Text.pack (goldenPath fixture shape) <> "\t" <> Text.stripEnd (goldenSummary (renderAll sealed)))

goldenPath :: CapabilityFixture -> ServiceShape -> FilePath
goldenPath fixture shape =
  "test/manifest/golden/"
    <> Text.unpack (fixtureSlug fixture)
    <> "_"
    <> case shape of
      SingleNode -> "singlenode.json.golden"
      Distributed _ -> "distributed.json.golden"

goldenSummary :: [K8sObject] -> Text
goldenSummary objects =
  "{\"objects\":"
    <> Text.pack (show (length objects))
    <> ",\"sha256\":\""
    <> sha256Hex (encodeK8sObjects objects)
    <> "\"}\n"

sha256Hex :: ByteString -> Text
sha256Hex bytes = Text.pack (concatMap byteHex (Strict.unpack (SHA256.hashlazy bytes)))
 where
  byteHex byte = case showHex byte "" of
    [digit] -> ['0', digit]
    digits -> digits

checkRoundTrip :: [K8sObject] -> IO ()
checkRoundTrip objects = case objects of
  [] -> fail "render corpus is empty"
  object : _ -> case eitherDecode (encode object) of
    Left problem -> fail ("typed K8sObject failed Aeson round trip: " <> problem)
    Right decoded -> assert (decoded == object) "typed K8sObject Aeson round trip changed the value"

checkPureBoundary :: IO ()
checkPureBoundary = do
  facade <- Text.readFile "src/Amoebius/Manifest.hs"
  renderAllSource <- Text.readFile "src/Amoebius/Manifest/RenderAll.hs"
  renderSource <- Text.readFile "src/Amoebius/Manifest/Render.hs"
  let surface = facade <> renderAllSource <> renderSource
      prohibited = ["unsafePerformIO", "fromJust", "undefined", "error ", "head ", "!!"]
  assert (all (not . (`Text.isInfixOf` surface)) prohibited) "renderAll transitive surface contains a partial or unsafe token"
  assert ("  ( renderAll\n" `Text.isInfixOf` facade) "public manifest facade does not export renderAll"
  assert (not ("renderSourcePrivate" `Text.isInfixOf` facade)) "public manifest facade exports a per-source renderer"
  assert (not ("BoundDeployment" `Text.isInfixOf` surface)) "renderer accepts a merely bound deployment"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (fail message)
