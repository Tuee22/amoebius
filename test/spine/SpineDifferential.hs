{-# LANGUAGE OverloadedStrings #-}

-- | The differential: every authored leaf of the baseline is changed on its own and the
-- pipeline is run again. A leaf that changes no artefact and is not refused reaches no
-- byte; the oracle refuses that. This section records, for each leaf, which artefacts
-- changed and how the pipeline answered; it decides nothing.
module SpineDifferential
  ( differentialSection
  ) where

import Amoebius.Dsl.Encode (encodeRaw, rawOf)
import Amoebius.Dsl.Examples.Spine (baselineRoot)
import Amoebius.Dsl.Pipeline
  ( Compiled
  , compileText
  , compiledFiles
  , compiledRefusal
  , pipelineErrorStage
  , pipelineErrorTag
  )
import Amoebius.Dsl.Raw qualified as Raw
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import System.FilePath ((</>))

type Update = Raw.RawRoot -> Raw.RawRoot

artefactNames :: [FilePath]
artefactNames = ["frozen.dhall", "decoded.dump", "lowered.dump", "plan.dump", "provisioned.dump", "manifest.json", "chain.dump", "dry-run.dump"]

differentialSection :: FilePath -> IO ()
differentialSection suite = do
  base <- run baseline
  rows <- mapM (leafRow base) leaves
  ByteString.writeFile (suite </> "differential.tsv") (Encoding.encodeUtf8 (Text.unlines rows))
 where
  run raw = compileText (suite </> "examples") (encodeRaw raw <> "\n")
  leafRow base (name, update) = do
    twin <- run (update baseline)
    pure (Text.intercalate "\t" [name, refusalOf twin, Text.intercalate "," (changed base twin), envelopeOf twin])

baseline :: Raw.RawRoot
baseline = either (const (Raw.RawRoot [] [] [] [])) rawOf baselineRoot

refusalOf :: Compiled -> Text
refusalOf compiled = case compiledRefusal compiled of
  Nothing -> "-"
  Just problem -> pipelineErrorTag problem <> ":" <> pipelineErrorStage problem

-- | The application's resource envelope as the lowered dump states it, when there is one.
envelopeOf :: Compiled -> Text
envelopeOf compiled = case [Text.drop 1 (Text.dropWhile (/= '\t') line) | line <- maybe [] (Text.lines . Encoding.decodeUtf8) (fileOf "lowered.dump" compiled), ".envelope\t" `Text.isInfixOf` line] of
  value : _ -> value
  [] -> "-"

changed :: Compiled -> Compiled -> [Text]
changed base twin = [Text.pack name | name <- artefactNames, fileOf name base /= fileOf name twin]

fileOf :: FilePath -> Compiled -> Maybe ByteString
fileOf name compiled = lookup name (compiledFiles compiled)

leaves :: [(Text, Update)]
leaves =
  [ ("clusterName", onCluster (\cluster -> cluster {Raw.clusterName = "kind-b"}))
  , ("kindHost", onCluster (\cluster -> renameHost "kind-node" cluster))
  , ("kindReplicas", onCluster (withKind (\kind -> kind {Raw.kindReplicas = 2})))
  , ("hostName", onCluster (\cluster -> renameHost "kind-node" cluster))
  , ("hostCpu", onHost (\host -> host {Raw.hostCpu = 17}))
  , ("hostMemory", onHost (\host -> host {Raw.hostMemory = 65}))
  , ("hostEphemeral", onHost (\host -> host {Raw.hostEphemeral = 501}))
  , ("hostPods", onHost (\host -> host {Raw.hostPods = 111}))
  , ("appName", renameApp "notes-t")
  , ("needCapability", onNeed (\need -> need {Raw.needCapability = Raw.SecretStore}))
  , ("needName", renameNeed "assets-t")
  , ("requestsCpu", onWorkload (\workload -> workload {Raw.workloadRequests = (Raw.workloadRequests workload) {Raw.podCpu = 2}}))
  , ("requestsMemory", onWorkload (\workload -> workload {Raw.workloadRequests = (Raw.workloadRequests workload) {Raw.podMemory = 3}}))
  , ("requestsEphemeral", onWorkload (\workload -> workload {Raw.workloadRequests = (Raw.workloadRequests workload) {Raw.podEphemeral = 5}}))
  , ("limitsCpu", onWorkload (\workload -> workload {Raw.workloadLimits = (Raw.workloadLimits workload) {Raw.podCpu = 3}}))
  , ("limitsMemory", onWorkload (\workload -> workload {Raw.workloadLimits = (Raw.workloadLimits workload) {Raw.podMemory = 5}}))
  , ("limitsEphemeral", onWorkload (\workload -> workload {Raw.workloadLimits = (Raw.workloadLimits workload) {Raw.podEphemeral = 9}}))
  , ("headroomCpu", onWorkload (\workload -> workload {Raw.workloadHeadroom = Just (Raw.RawPod 1 0 0)}))
  , ("headroomMemory", onWorkload (\workload -> workload {Raw.workloadHeadroom = Just (Raw.RawPod 0 1 0)}))
  , ("headroomEphemeral", onWorkload (\workload -> workload {Raw.workloadHeadroom = Just (Raw.RawPod 0 0 1)}))
  , ("deploymentOf", onDeployment (\deployment -> deployment {Raw.deploymentOf = "ghost-app"}))
  , ("bindingNeed", onBinding (\binding -> binding {Raw.bindingNeed = "ghost-need"}))
  , ("bindingProvider", onBinding (\binding -> binding {Raw.bindingProvider = "Alternate"}))
  , ("bindingShape", onBinding (\binding -> binding {Raw.bindingShape = Raw.Distributed 3}))
  , ("replicas", onDeployment (\deployment -> deployment {Raw.distribution = Raw.RawDistribution 2}))
  ]

onCluster :: (Raw.RawCluster -> Raw.RawCluster) -> Update
onCluster change root = root {Raw.rootClusters = map change (Raw.rootClusters root)}

withKind :: (Raw.RawKind -> Raw.RawKind) -> Raw.RawCluster -> Raw.RawCluster
withKind change cluster = case Raw.clusterTopology cluster of
  Raw.KindTopology kind -> cluster {Raw.clusterTopology = Raw.KindTopology (change kind)}
  Raw.Rke2Topology _ -> cluster

onHost :: (Raw.RawHost -> Raw.RawHost) -> Update
onHost change = onCluster (\cluster -> cluster {Raw.clusterHosts = map change (Raw.clusterHosts cluster)})

renameHost :: Text -> Raw.RawCluster -> Raw.RawCluster
renameHost name cluster = (withKind (\kind -> kind {Raw.kindHost = name}) cluster) {Raw.clusterHosts = map (\host -> host {Raw.hostName = name}) (Raw.clusterHosts cluster)}

onApp :: (Raw.RawApp -> Raw.RawApp) -> Update
onApp change root = root {Raw.rootApps = map change (Raw.rootApps root)}

onNeed :: (Raw.RawNeed -> Raw.RawNeed) -> Update
onNeed change = onApp (\app -> app {Raw.needs = map change (Raw.needs app)})

onWorkload :: (Raw.RawWorkload -> Raw.RawWorkload) -> Update
onWorkload change = onApp (\app -> app {Raw.workload = change (Raw.workload app)})

onDeployment :: (Raw.RawDeployment -> Raw.RawDeployment) -> Update
onDeployment change root = root {Raw.rootDeployments = map change (Raw.rootDeployments root)}

onBinding :: (Raw.RawBinding -> Raw.RawBinding) -> Update
onBinding change = onDeployment (\deployment -> deployment {Raw.bindings = map change (Raw.bindings deployment)})

renameApp :: Text -> Update
renameApp name = onApp (\app -> app {Raw.appName = name}) . onDeployment (\deployment -> deployment {Raw.deploymentOf = name})

renameNeed :: Text -> Update
renameNeed name = onNeed (\need -> need {Raw.needName = name}) . onBinding (\binding -> binding {Raw.bindingNeed = name})
