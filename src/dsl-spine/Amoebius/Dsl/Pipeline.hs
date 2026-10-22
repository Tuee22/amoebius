{-# LANGUAGE OverloadedStrings #-}

-- | The stages plan, provision, and render, and the composition of every stage from text
-- to the bytes handed to the executor. Each stage consumes only the value the stage before
-- it produced, and every stage writes the artefact it produced whether or not a later
-- stage refuses, so a refusal is observed at the stage that made it.
module Amoebius.Dsl.Pipeline
  ( PipelineError (..)
  , pipelineErrorTag
  , pipelineErrorStage
  , renderPipelineError
  , Compiled
  , compiledFiles
  , compiledSteps
  , compiledRefusal
  , compiledManifest
  , compileDeployment
  , compileText
  , dumpPlan
  , dumpProvisioned
  , compileToDirectory
  , lowerToDirectory
  , ApplyOutcome (..)
  , applyToDirectory
  , EndpointOutcome (..)
  , endpointOutcome
  ) where

import Amoebius.Capacity.Provision
  ( InfrastructureDemand (..)
  , InfrastructurePlanningResult (..)
  , ProvisionError
  , ProvisionedCapacitySchedulerSystem (..)
  , ProvisionedServicePart (..)
  , ProvisionedSpec
  , deriveInfrastructureDemand
  , emptyPriorProvisionCatalog
  , materializationIsReceiptBound
  , mkProvisionContext
  , observationFromPlanningResult
  , observedMaterializedCapacity
  , observedMaterializedIdentities
  , planInfrastructure
  , provisionWithEngineOfferings
  , provisionErrorTag
  , provisionedPlacement
  , provisionedRenderSources
  , provisionedSchedulerSystem
  , provisionedServiceParts
  )
import Amoebius.Capacity.RenderSource (K8sObjectIdentity (K8sObjectIdentity), RenderActivation (Immediate), ReconcileMode (ServerSideApply), provisionedRenderSourceMap, renderSourceActivation)
import Amoebius.Capacity.Types (Assignment (..), MaterializedNode (..), Node (..), Placement (..))
import Amoebius.Capability.Types (BoundApp (boundAppName))
import Amoebius.Dsl.Decode (DecodeRefusal, decodeRefusalTag, decodeRoot, dumpRoot)
import Amoebius.Dsl.Dump (commas, natural, row, rows, vector)
import Amoebius.Dsl.Import (Frozen, ImportRefusal, freezeText, frozenText, importRefusalTag)
import Amoebius.Dsl.Lower (LowerRefusal, Lowered, dumpLowered, loweredApp, loweredDeployment, loweredSupply, loweredTopology, lowerDeployment, lowerRefusalTag)
import Amoebius.Dsl.Extensions
import Amoebius.Dsl.TargetModel (fakeEngineOfferings, targetModelDump)
import Amoebius.Dsl.Policy (deploymentLabel, provisionGeneration, provisionPolicy)
import Amoebius.Dsl.Topology (Topology, ComputeEngine (Rke2Engine), NodeSupply (..), topologyEngine, topologySupply)
import Amoebius.Topology.Lanes (laneLabels)
import Amoebius.Vocabulary (detectedArchitecture, detectedSubstrate, architectureName, substrateName)
import Amoebius.Placement.Witness (placedPlacement)
import Amoebius.Kernel.Interpret
  ( InterpretRefusal
  , Executor
  , dryRun
  , interpretRefusalTag
  , materializeFake
  , renderDryRun
  , runChainFromFrame
  , sha256Hex
  )
import Amoebius.Kernel.Step
  ( Frame (ImmediateFrame)
  , Step
  , StepRefusal
  , manifestBytes
  , planOf
  , renderPlan
  , stepRefusalTag
  , validateChain
  )
import Amoebius.Manifest (renderAll)
import Amoebius.Manifest.Render (RenderRefusal, renderRefusalTag, stampScope)
import Amoebius.Scope.Attested (ScopeStamp)
import Amoebius.Manifest.K8sObject (K8sObject (..), K8sObjectKind (NodeKind), ObjectMetadata (..), ObjectSpec (GlobalControlSpec))
import Amoebius.Image.Recipe (RecipeRefusal (NoImageLanes), imageRecipe, recipeRefusalTag)
import Amoebius.Image.Bake (imageRecipeArtifacts)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT, runExceptT, throwE)
import Control.Monad.Trans.Writer.Strict (Writer, runWriter, tell)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as Lazy
import Data.Map.Strict qualified as Map
import Data.List.NonEmpty qualified as NonEmpty
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory, (</>))

data PipelineError
  = ImportFailed ImportRefusal
  | DecodeFailed DecodeRefusal
  | LowerFailed LowerRefusal
  | PlanFailed ProvisionError
  | ProvisionFailed ProvisionError
  | RenderFailed RenderRefusal
  | ChainFailed StepRefusal
  | DryRunFailed InterpretRefusal
  | RecipeFailed RecipeRefusal
  | ExtensionFailed ExtensionRefusal
  | ExtensionChainFailed ExtensionRefusal
  deriving stock (Eq, Show)

-- | The stable tag of a refusal: the tag its own stage gives it.
pipelineErrorTag :: PipelineError -> Text
pipelineErrorTag problem = case problem of
  ImportFailed refusal -> importRefusalTag refusal
  DecodeFailed refusal -> decodeRefusalTag refusal
  LowerFailed refusal -> lowerRefusalTag refusal
  PlanFailed refusal -> provisionErrorTag refusal
  ProvisionFailed refusal -> provisionErrorTag refusal
  RenderFailed refusal -> renderRefusalTag refusal
  ChainFailed refusal -> stepRefusalTag refusal
  DryRunFailed refusal -> interpretRefusalTag refusal
  RecipeFailed refusal -> recipeRefusalTag refusal
  ExtensionFailed refusal -> extensionRefusalTag refusal
  ExtensionChainFailed refusal -> extensionRefusalTag refusal

-- | The stage that refused.
pipelineErrorStage :: PipelineError -> Text
pipelineErrorStage problem = case problem of
  ImportFailed _ -> "freeze"
  DecodeFailed _ -> "decode"
  LowerFailed _ -> "lower"
  PlanFailed _ -> "plan"
  ProvisionFailed _ -> "provision"
  RenderFailed _ -> "render"
  ChainFailed _ -> "chain"
  DryRunFailed _ -> "dry-run"
  RecipeFailed _ -> "recipe"
  ExtensionFailed _ -> "attest"
  ExtensionChainFailed _ -> "extension-chain"

-- | The refusal record: tag, stage, and detail, tab-separated on one line.
renderPipelineError :: PipelineError -> Text
renderPipelineError problem = Text.intercalate "\t" [pipelineErrorTag problem, pipelineErrorStage problem, Text.replace "\n" " " (Text.pack (show problem))] <> "\n"

type Artefact = (FilePath, ByteString)

-- | The artefacts of every stage that completed, the chain when it was built, and the
-- refusal when a stage refused.
data Compiled = Compiled
  { compiledFiles :: [Artefact]
  , compiledSteps :: [Step]
  , compiledRefusal :: Maybe PipelineError
  }

-- | The manifest: the payloads of the chain's apply steps, in order.
compiledManifest :: Compiled -> ByteString
compiledManifest = manifestBytes . compiledSteps

type Pipe = ExceptT PipelineError (Writer [Artefact])

emit :: FilePath -> ByteString -> Pipe ()
emit path bytes = lift (tell [(path, bytes)])

emitText :: FilePath -> Text -> Pipe ()
emitText path text = emit path (Encoding.encodeUtf8 text)

refuse :: (problem -> PipelineError) -> Either problem value -> Pipe value
refuse wrap = either (throwE . wrap) pure

-- | Freeze a source text relative to a directory, then run every later stage.
compileText :: FilePath -> Text -> IO Compiled
compileText directory source = do
  frozen <- freezeText directory source
  pure (either (\refusal -> Compiled [] [] (Just (ImportFailed refusal))) compileDeployment frozen)

-- | Decode, lower, plan, provision, render, chain, and plan the dry run of a frozen
-- specification.
compileDeployment :: Frozen -> Compiled
compileDeployment frozen = case runWriter (runExceptT (stages frozen)) of
  (Left problem, files) -> Compiled files [] (Just problem)
  (Right steps, files) -> Compiled files steps Nothing

stages :: Frozen -> Pipe [Step]
stages frozen = do
  lowered <- frontStages frozen
  planned <- refuse PlanFailed (planInfrastructure (loweredSupply lowered) (loweredDeployment lowered))
  emitText "plan.dump" (dumpPlan lowered planned)
  observation <- refuse PlanFailed (observationFromPlanningResult planned)
  context <- refuse PlanFailed (mkProvisionContext deploymentLabel provisionGeneration provisionPolicy emptyPriorProvisionCatalog observation)
  let offerings = fakeEngineOfferings (loweredTopology lowered) (loweredDeployment lowered)
  emitText "target-model.tsv" (targetModelDump offerings)
  provisioned <- refuse ProvisionFailed (provisionWithEngineOfferings offerings context (loweredTopology lowered) (loweredDeployment lowered))
  emitText "provisioned.dump" (dumpProvisioned provisioned)
  attested <- refuse ExtensionFailed (attestDeployment lowered)
  emitText "extensions.tsv" (extensionFacts attested)
  emitText "scope.tsv" (scopeFacts attested)
  emitText "workflow.tsv" (workflowFacts attested)
  mapM_ (uncurry emit) (conformanceFiles attested)
  mapM_ (uncurry emitText) admittedSources
  objects <- refuse RenderFailed (renderAll (scopeAuthorities attested) provisioned)
  steps <- refuse ExtensionChainFailed (contributedSteps attested
    (objects <> nodeObjects (deploymentScope attested) (loweredTopology lowered)))
  refuse ChainFailed (validateChain steps)
  emit "manifest.json" (manifestBytes steps)
  emit "chain.dump" (Lazy.toStrict (renderPlan (planOf steps)))
  planned' <- refuse DryRunFailed (dryRun steps)
  emitText "dry-run.dump" (renderDryRun planned')
  pure steps

-- | The rke2 node envelope carries the observed substrate and all derived
-- lanes alongside the inventory's taints. Live NodeSpec projection is later.
nodeObjects :: ScopeStamp -> Topology -> [K8sObject]
nodeObjects authority topology
  | topologyEngine topology /= Rke2Engine = []
  | otherwise = case topologySupply topology of
      FixedSupply nodes -> map nodeObject (NonEmpty.toList nodes)
      ElasticSupply {} -> []
 where
  nodeObject node = stampScope authority K8sObject
    { objectIdentity = K8sObjectIdentity ("node/" <> nodeId node)
    , objectApiVersion = "v1"
    , objectKind = NodeKind
    , objectMetadata = ObjectMetadata (nodeId node) Nothing labels Map.empty
    , objectSpec = GlobalControlSpec (Map.fromList [("role", Text.pack (show (nodeRole node))), ("taints", commas (Set.toAscList (nodeTaints node)))])
    , objectActivation = Immediate
    , objectReconcileMode = ServerSideApply
    }
   where
    detected = nodeDetected node
    labels = Map.fromList
      ([ ("amoebius.io/owner", "deployment-global"), ("app.kubernetes.io/managed-by", "amoebius"), ("amoebius.io/epoch", "generation-1")
       , ("amoebius.io/substrate", Text.pack (substrateName (detectedSubstrate detected)))
       , ("kubernetes.io/arch", Text.pack (architectureName (detectedArchitecture detected)))
       ] <> [("amoebius.io/lane-" <> Text.replace "/" "-" lane, "true") | lane <- laneLabels detected])

-- | The hardware-free prefix can be observed without claiming provisioning
-- or an application on a substrate absent from the gate.
frontStages :: Frozen -> Pipe Lowered
frontStages frozen = do
  emitText "frozen.dhall" (frozenText frozen)
  root <- refuse DecodeFailed (decodeRoot frozen)
  emitText "decoded.dump" (dumpRoot root)
  lowered <- refuse LowerFailed (lowerDeployment root)
  emitText "lowered.dump" (dumpLowered lowered)
  recipe <- case topologySupply (loweredTopology lowered) of
    FixedSupply nodes -> refuse RecipeFailed (imageRecipe (boundAppName (loweredApp lowered)) (topologyEngine (loweredTopology lowered)) (fmap nodeDetected nodes))
    ElasticSupply {} -> throwE (RecipeFailed NoImageLanes)
  artefacts <- refuse RecipeFailed (imageRecipeArtifacts recipe)
  mapM_ (uncurry emitText) artefacts
  pure lowered

lowerToDirectory :: FilePath -> FilePath -> IO (Either PipelineError ())
lowerToDirectory input output = do
  source <- Encoding.decodeUtf8 <$> ByteString.readFile input
  frozen <- freezeText (takeDirectory input) source
  let (result, files) = case frozen of
        Left problem -> (Left (ImportFailed problem), [])
        Right value -> let (outcome, artefacts) = runWriter (runExceptT (frontStages value)) in (fmap (const ()) outcome, artefacts)
  createDirectoryIfMissing True output
  writeArtefacts output files
  case result of
    Left problem -> ByteString.writeFile (output </> "refusal.tsv") (Encoding.encodeUtf8 (renderPipelineError problem))
    Right () -> pure ()
  pure result

-- | The plan dump: what the plan demanded and what the materialised supply offered.
dumpPlan :: Lowered -> InfrastructurePlanningResult -> Text
dumpPlan lowered planned = rows (resultRows <> materializedRows)
 where
  demand = deriveInfrastructureDemand (loweredDeployment lowered)
  resultRows =
    [ row "plan.result" (resultTag planned)
    , row "plan.demand.units" (natural (infrastructureRequiredUnits demand))
    , row "plan.demand.identities" (commas (Set.toAscList (infrastructureRequiredIdentities demand)))
    ]
  materializedRows = case planned of
    NoInfrastructureRequired observation ->
      [ row "plan.materialized.capacity" (vector (observedMaterializedCapacity observation))
      , row "plan.materialized.identities" (commas (Set.toAscList (observedMaterializedIdentities observation)))
      , row "plan.materialized.receipt-bound" (Text.pack (show (materializationIsReceiptBound observation)))
      ]
    InfrastructureRequired _ -> []

resultTag :: InfrastructurePlanningResult -> Text
resultTag planned = case planned of
  NoInfrastructureRequired _ -> "NoInfrastructureRequired"
  InfrastructureRequired _ -> "InfrastructureRequired"

-- | The provision dump: where each unit was placed and what the placement used, when each
-- object activates, the services provisioned, and the scheduler's bootstrap reservations.
dumpProvisioned :: ProvisionedSpec -> Text
dumpProvisioned provisioned = rows (assignmentRows <> placementRows <> nodeRows <> activationRows <> serviceRows <> schedulerRows)
 where
  placement = placedPlacement (provisionedPlacement provisioned)
  assignmentRows = [row "provision.assignments" (commas [assignmentWorkload assignment <> "@" <> assignmentNode assignment | assignment <- placementAssignments placement])]
  placementRows = [row "provision.placement" (commas [Text.pack (show (placementKind placement)), natural (placementInstances placement), natural (placementVcpu placement)])]
  nodeRows = [row "provision.nodes" (commas [nodeId (materializedNode node) | node <- placementNodes placement])]
  activationRows = [row ("provision.render." <> identity) (Text.pack (show (renderSourceActivation source))) | (K8sObjectIdentity identity, source) <- Map.toList (provisionedRenderSourceMap (provisionedRenderSources provisioned))]
  serviceRows = [row "provision.services" (commas [provisionedServiceName part <> ":" <> Text.pack (show (provisionedServiceArm part)) <> ":" <> natural (fromIntegral (length (provisionedServiceObjects part))) | part <- Map.elems (provisionedServiceParts provisioned)])]
  schedulerRows = [row "provision.scheduler.reservations" (natural (schedulerBootstrapReservations (provisionedSchedulerSystem provisioned)))]

-- | The whole of the compile command: freeze the input beside its own directory, run the
-- pipeline, write every artefact a completed stage produced, and record the refusal when a
-- stage refused.
compileToDirectory :: FilePath -> FilePath -> IO (Either PipelineError [Step])
compileToDirectory input output = do
  source <- Encoding.decodeUtf8 <$> ByteString.readFile input
  compiled <- compileText (takeDirectory input) source
  createDirectoryIfMissing True output
  writeArtefacts output (compiledFiles compiled)
  case compiledRefusal compiled of
    Nothing -> pure (Right (compiledSteps compiled))
    Just problem -> do
      ByteString.writeFile (output </> "refusal.tsv") (Encoding.encodeUtf8 (renderPipelineError problem))
      pure (Left problem)

writeArtefacts :: FilePath -> [Artefact] -> IO ()
writeArtefacts output = mapM_ (\(path, bytes) -> do
  let target = output </> path
  createDirectoryIfMissing True (takeDirectory target)
  ByteString.writeFile target bytes)

data ApplyOutcome
  = ApplyRefused PipelineError
  | ApplyDryRun
  | ApplyFailed InterpretRefusal
  | Applied Int

-- | The whole of the apply command: compile, then either stop at the dry run or hand every
-- step to the executor the program image provides.
applyToDirectory :: Bool -> FilePath -> FilePath -> FilePath -> IO ApplyOutcome
applyToDirectory dry image input output = do
  compiled <- compileToDirectory input output
  case compiled of
    Left problem -> pure (ApplyRefused problem)
    Right steps
      | dry -> pure ApplyDryRun
      | otherwise -> do
          executor <- materializeFake image (output </> "fake")
          applied <- runAll executor steps
          pure (either ApplyFailed (Applied . length) applied)

runAll :: Executor -> [Step] -> IO (Either InterpretRefusal [()])
runAll executor steps = fmap (fmap (map (const ()))) (runChainFromFrame executor ImmediateFrame steps)

data EndpointOutcome
  = EndpointRendered Text
  | EndpointRefused Text Text
  deriving stock (Eq, Show)

-- | What the control-plane endpoint answers for an uploaded specification: the digest of
-- the manifest it compiles to, or the tag and stage of the refusal.
endpointOutcome :: FilePath -> Text -> IO EndpointOutcome
endpointOutcome directory source = do
  compiled <- compileText directory source
  pure $ case compiledRefusal compiled of
    Nothing -> EndpointRendered (sha256Hex (compiledManifest compiled))
    Just problem -> EndpointRefused (pipelineErrorTag problem) (pipelineErrorStage problem)
