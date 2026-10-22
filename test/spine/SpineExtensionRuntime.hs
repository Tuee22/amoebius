{-# LANGUAGE OverloadedStrings #-}

-- Observe the actual pipeline and renderer over shipped operator examples.
-- Expected inventories and refusal tags belong to the independent oracle.
module SpineExtensionRuntime (extensionRuntimeSection) where

import Amoebius.Capacity.Provision
import Amoebius.Capacity.RenderSource (RenderSourceOwner (CapabilityServiceOwner))
import Amoebius.Dsl.Examples.Extensions (Example (..), exampleNamed)
import Amoebius.Dsl.Examples.Extensions qualified as Examples
import Amoebius.Dsl.Examples.Substrates qualified as Substrates
import Amoebius.Dsl.Decode (decodeRoot)
import Amoebius.Dsl.Extensions (attestDeployment, scopeAuthorities, contributedSteps)
import Amoebius.Dsl.Import (freezeText)
import Amoebius.Dsl.Lower
import Amoebius.Dsl.Pipeline (PipelineError (ExtensionChainFailed), renderPipelineError, applyToDirectory, compileToDirectory)
import Amoebius.Dsl.Policy
import Amoebius.Dsl.TargetModel (fakeEngineOfferings)
import Amoebius.Scope.Attested qualified as Scope
import Amoebius.Extension.Linked qualified as Linked
import Amoebius.Extension.Monitoring qualified as Monitoring
import Amoebius.Test.ScopeFixture (fixtureIdentityText)
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.Render (renderRefusalTag)
import Control.Exception (SomeException, evaluate, try)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as Text
import System.Directory (createDirectoryIfMissing)
import System.Environment (getExecutablePath)
import System.FilePath ((</>))

extensionRuntimeSection :: FilePath -> IO ()
extensionRuntimeSection directory = do
  createDirectoryIfMissing True directory
  Text.writeFile (directory </> "corpus.tsv") (Text.unlines (map exampleName
    (drop (length Substrates.corpus) Examples.corpus)))
  Text.writeFile (directory </> "corpus-files.tsv") (Text.unlines
    [Text.pack path | (path, _) <- Examples.renderExampleFiles, "examples/" `Text.isPrefixOf` Text.pack path,
      path `notElem` map fst Substrates.renderExampleFiles])
  image <- getExecutablePath
  mapM_ (observe image)
    [("cpu-amd64", "infernix-linked"), ("cpu-arm64", "attested-scope"),
     ("cuda-amd64", "cuda-on-cuda-sibling"), ("cuda-arm64", "cuda-arm64-linked"),
     ("mixed", "mixed-inference-runtimes")]
  example <- getExample "infernix-linked"
  frozen <- freezeText directory (exampleText example) >>= checked
  root <- checked (decodeRoot frozen)
  lowered <- checked (lowerDeployment root)
  planned <- checked (planInfrastructure (loweredSupply lowered) (loweredDeployment lowered))
  observation <- checked (observationFromPlanningResult planned)
  context <- checked (mkProvisionContext deploymentLabel provisionGeneration provisionPolicy emptyPriorProvisionCatalog observation)
  provisioned <- checked (provisionWithEngineOfferings
    (fakeEngineOfferings (loweredTopology lowered) (loweredDeployment lowered)) context
    (loweredTopology lowered) (loweredDeployment lowered))
  attested <- checked (attestDeployment lowered)
  rendered <- checked (renderAll (scopeAuthorities attested) provisioned)
  steps <- checked (contributedSteps attested rendered)
  Text.writeFile (directory </> "chain-stage-controls.tsv") ("legal\taccepted:" <> Text.pack (show (length steps)) <> "\n" <>
    "missing-provider-objects\t" <> either (renderPipelineError . ExtensionChainFailed)
      (\values -> "accepted:" <> Text.pack (show (length values)) <> "\n") (contributedSteps attested []))
  let authorities = scopeAuthorities attested
      outcome = either renderRefusalTag (\objects -> "accepted:" <> Text.pack (show (length objects)))
      render values = outcome (renderAll values provisioned)
  Text.writeFile (directory </> "scope-controls.tsv") (Text.unlines
    ["attested\t" <> render authorities,
     "missing-authorities\t" <> render Map.empty,
     "missing-inference-authority\t" <> render (Map.filterWithKey
       (\owner _ -> case owner of CapabilityServiceOwner name -> not ("engine-" `Text.isPrefixOf` name); _ -> True) authorities)])
  core <- case [proof | proof <- Map.elems (loweredProofs lowered), Linked.bindingIssuer proof == "core/ObjectStore"] of
    [proof] -> pure proof
    _ -> fail "missing actual core authority"
  inference <- case [proof | proof <- Map.elems (loweredProofs lowered), Linked.bindingIssuer proof == "extension/infernix"] of
    [proof] -> pure proof
    _ -> fail "missing actual extension authority"
  other <- checked (fixtureIdentityText "tenant-other" "subject-other")
  unicode <- checked (fixtureIdentityText "ténant" "sübject")
  let coreEvidence = Scope.bindingAttestation core
      inferenceEvidence = Scope.bindingAttestation inference
      otherEvidence = Scope.principalAttestation other
      unicodeEvidence = Scope.principalAttestation unicode
      origin scope = [Scope.scopeIssuer scope, Scope.scopeApplication scope, Scope.scopeNeed scope, Scope.scopeLabel scope]
      outcome = either (Text.pack . show) (("accepted:" <>) . Scope.scopedValue)
  entered <- checked (Scope.attest coreEvidence $ \scope -> do
    let saved = Scope.persist scope "artifact" (Scope.scoped scope ("payload" :: Text))
    differentNeed <- checked (Scope.attest inferenceEvidence (\next -> outcome (Scope.reenter next saved)))
    differentTenant <- checked (Scope.attest otherEvidence (\next -> outcome (Scope.reenter next saved)))
    bottom <- try (evaluate (Scope.scoped (error "unattested scope") ("escaped" :: Text)) >> pure ()) :: IO (Either SomeException ())
    pure [["same-scope", outcome (Scope.reenter scope saved)], ["different-need", differentNeed],
      ["different-tenant", differentTenant], ["bottom-scope-eliminator", either (const "exception") (const "escaped") bottom]])
  reentry <- entered
  origins <- mapM (\evidence -> checked (Scope.attest evidence origin)) [coreEvidence, inferenceEvidence, otherEvidence, unicodeEvidence]
  Text.writeFile (directory </> "reentry-controls.tsv") (Text.unlines (map (Text.intercalate "\t") reentry))
  Text.writeFile (directory </> "authority-origins.tsv") (Text.unlines (map (Text.intercalate "\t") origins))
  metric <- checked (Monitoring.metricName "amoebius_test_success")
  sloBuilder <- checked (Monitoring.defaultSloBuilder metric)
  boardBuilder <- checked (Monitoring.tensorBoardBuilder (Linked.bindingNeed core))
  observed <- checked (Scope.attest inferenceEvidence $ \scope -> do
    slo <- checked (Monitoring.realizeMonitoring scope Nothing sloBuilder)
    tensor <- checked (Monitoring.realizeMonitoring scope (Just core) boardBuilder)
    let tag = either Monitoring.monitoringRefusalTag (const "accepted")
    Text.writeFile (directory </> "monitoring-slo.tsv") (renderRows (Monitoring.monitoringRows slo))
    Text.writeFile (directory </> "monitoring-tensorboard.tsv") (renderRows (Monitoring.monitoringRows tensor))
    pure [("tensorboard-with-backing", tag (Monitoring.realizeMonitoring scope (Just core) boardBuilder)),
      ("tensorboard-without-backing", tag (Monitoring.realizeMonitoring scope Nothing boardBuilder))])
  tensorControls <- observed
  crossApplication <- checked (Scope.attest otherEvidence (\scope -> either Monitoring.monitoringRefusalTag
    (const "accepted") (Monitoring.realizeMonitoring scope (Just core) boardBuilder)))
  let tag = either Monitoring.monitoringRefusalTag (const "accepted")
  Text.writeFile (directory </> "monitoring-controls.tsv") (renderRows
    ([("prometheus-name", tag (Monitoring.metricName "amoebius_requests_total")),
      ("empty-metric-name", tag (Monitoring.metricName "")), ("digit-leading-metric", tag (Monitoring.metricName "9requests")),
      ("zero-threshold", tag (Monitoring.objective 0 1000 300 1 100)),
      ("zero-window", tag (Monitoring.objective 999 1000 0 1 100)),
      ("zero-error-budget", tag (Monitoring.objective 999 1000 300 0 100)),
      ("unit-error-budget", tag (Monitoring.objective 999 1000 300 1 1))]
      <> tensorControls <> [("tensorboard-cross-application", crossApplication)]))
 where
  observe image (label, name) = do
    example <- getExample name
    let output = directory </> label
        input = output </> "input.dhall"
    createDirectoryIfMissing True output
    Text.writeFile input (exampleText example)
    _ <- compileToDirectory input (output </> "compiled")
    _ <- applyToDirectory False image input (output </> "applied")
    pure ()
  getExample name = maybe (fail ("missing shipped example " <> Text.unpack name)) pure (exampleNamed name)
  checked :: Show problem => Either problem value -> IO value
  checked = either (fail . show) pure
  renderRows = Text.unlines . map (\(name, value) -> name <> "\t" <> value)
