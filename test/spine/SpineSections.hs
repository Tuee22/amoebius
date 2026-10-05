{-# LANGUAGE OverloadedStrings #-}

-- | The sections that judge the front of the spine: the example corpus and every stage it
-- passes through, the vocabulary, the typed specification's constructors, the freeze, the
-- decoder, and the endpoint. Each writes the bytes it observed; none decides anything.
module SpineSections
  ( corpusSection
  , stagesSection
  , vocabularySection
  , specSection
  , freezeSection
  , decodeSection
  , endpointSection
  ) where

import Amoebius.Capability.Types (CapabilityProvider (CanonicalProvider), ServiceShape (..))
import Amoebius.Dsl.Decode (decodeFrozen, decodeRefusalTag, decodeRoot, dumpRoot)
import Amoebius.Dsl.Encode (encodeRaw, encodeRoot, rawOf)
import Amoebius.Dsl.Examples.Capacity (Example (..), corpus, renderExampleFiles)
import Amoebius.Dsl.Examples.Spine (baselineRoot, variant)
import Amoebius.Dsl.Import (Frozen, ImportRefusal, freezeFile, freezeText, frozenHash, importRefusalTag)
import Amoebius.Dsl.Lower (lowerDeployment, lowerRefusalTag)
import Amoebius.Dsl.Pipeline (EndpointOutcome (..), compileToDirectory, endpointOutcome)
import Amoebius.Dsl.Raw qualified as Raw
import Amoebius.Dsl.Spec
import Amoebius.Kernel.Interpret (sha256Hex)
import Amoebius.Pulsar.Wire (ProtocolField (..), ProtocolMessage (..), protocolDeclarations, renderProtocol)
import Amoebius.Vocabulary
  ( Architecture (..)
  , CapabilityArm (..)
  , Gpu (..)
  , OsName (..)
  , RawArch (..)
  , Substrate (..)
  , architectureName
  , detectedArchitecture
  , detectedSubstrate
  , hostEnvironment
  , hostRefusalTag
  , isLabel
  , laneName
  , lanesOf
  , mkDetected
  , mkExtensionId
  , substrateName
  )
import Control.Exception (SomeException, try)
import Control.Monad (void)
import Data.ByteString qualified as ByteString
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import Numeric.Natural (Natural)
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory, (</>))

writeText :: FilePath -> Text -> IO ()
writeText path contents = do
  createDirectoryIfMissing True (takeDirectory path)
  ByteString.writeFile path (Encoding.encodeUtf8 contents)

writeLines :: FilePath -> [Text] -> IO ()
writeLines path rows = writeText path (Text.unlines rows)

tabs :: [Text] -> Text
tabs = Text.intercalate "\t"

-- | Render the whole corpus and record the file inventory; render the wire schema from the
-- message declarations beside it.
corpusSection :: FilePath -> IO ()
corpusSection suite = do
  mapM_ (\(path, contents) -> writeText (suite </> path) contents) renderExampleFiles
  writeLines (suite </> "corpus.tsv") [Text.pack path | (path, _) <- renderExampleFiles]
  writeText (suite </> "proto" </> "PulsarApi.proto") renderProtocol
  writeLines (suite </> "wire.tsv") [tabs (protocolMessageName message : [protocolFieldName field <> ":" <> Text.pack (show (protocolFieldNumber field)) | field <- protocolMessageFields message]) | message <- protocolDeclarations]

-- | Compile every example exactly as the compile command does, into its own directory.
stagesSection :: FilePath -> IO ()
stagesSection suite = mapM_ one corpus
 where
  one example = do
    let name = Text.unpack (exampleName example)
        input = suite </> "examples" </> (name <> ".dhall")
        output = suite </> "stages" </> name
    outcome <- try (void (compileToDirectory input output)) :: IO (Either SomeException ())
    case outcome of
      Left problem -> writeText (output </> "exception.txt") (Text.pack (takeWhile (/= '\n') (show problem)) <> "\n")
      Right _ -> pure ()

-- | What the endpoint answers for each example.
endpointSection :: FilePath -> IO ()
endpointSection suite = do
  rows <- mapM one corpus
  writeLines (suite </> "endpoint.tsv") rows
 where
  one example = do
    outcome <- endpointOutcome (suite </> "examples") (exampleText example <> "\n")
    pure $ tabs
      [ exampleName example
      , case outcome of
          EndpointRendered digest -> "rendered:" <> digest
          EndpointRefused tag stage -> "refused:" <> tag <> ":" <> stage
      ]

-- | The classification of hosts, the detections that exist, the labels, and the extensions.
vocabularySection :: FilePath -> IO ()
vocabularySection suite = writeLines (suite </> "vocabulary.tsv") (hostRows <> detectRows <> labelRows <> extensionRows)
 where
  hosts =
    [ (os, architecture, gpu)
    | os <- ["linux", "darwin", "mingw32", "windows", "freebsd"]
    , architecture <- ["x86_64", "amd64", "aarch64", "arm64", "sparc"]
    , gpu <- [GpuAbsent, GpuPresent]
    ]
  hostRows = [hostRow os architecture gpu | (os, architecture, gpu) <- hosts]
  hostRow os architecture gpu =
    tabs
      [ "host"
      , Text.pack os
      , Text.pack architecture
      , Text.pack (show gpu)
      , case hostEnvironment (OsName os) (RawArch architecture) gpu of
          Left refusal -> "refused:" <> Text.pack (show refusal) <> ":" <> Text.pack (hostRefusalTag refusal)
          Right detected ->
            "detected:"
              <> Text.pack (substrateName (detectedSubstrate detected))
              <> ":"
              <> Text.pack (architectureName (detectedArchitecture detected))
              <> ":"
              <> Text.intercalate "," (map (Text.pack . laneName) (lanesOf detected))
      ]
  detectRows =
    [ tabs ["detect", Text.pack (substrateName substrate), Text.pack (architectureName architecture), either (const "refused") (const "ok") (mkDetected substrate architecture)]
    | substrate <- [LinuxCpu, LinuxCuda, Apple, Windows]
    , architecture <- [Amd64, Arm64]
    ]
  labelRows = [tabs ["label", name, Text.pack (show (isLabel text))] | (name, text) <- labels]
  labels =
    [ ("empty", "")
    , ("one", "a")
    , ("digit-first", "0a")
    , ("digit-last", "a0")
    , ("inner-hyphen", "a-b")
    , ("sixty-three", Text.replicate 63 "a")
    , ("sixty-four", Text.replicate 64 "a")
    , ("uppercase", "A")
    , ("underscore", "a_b")
    , ("leading-hyphen", "-a")
    , ("trailing-hyphen", "a-")
    , ("dot", "a.b")
    ]
  extensionRows = [tabs ["extension", name, maybe "none" (const "some") (mkExtensionId text)] | (name, text) <- [("label", "good"), ("uppercase", "Bad"), ("empty", "")]]

verdict :: Either SpecError value -> Text
verdict = either (\problem -> "refused:" <> specErrorTag problem) (const "ok")

-- | The boundary of every constructor of the typed specification.
specSection :: FilePath -> IO ()
specSection suite = writeLines (suite </> "spec.tsv") (map (\(name, result) -> tabs [name, result]) rows)
 where
  rows =
    [ ("name.cluster.valid", verdict (mkClusterName "a"))
    , ("name.cluster.empty", verdict (mkClusterName ""))
    , ("name.cluster.uppercase", verdict (mkClusterName "A"))
    , ("name.app.valid", verdict (mkAppName "a"))
    , ("name.app.underscore", verdict (mkAppName "a_b"))
    , ("name.need.valid", verdict (mkNeedName "a"))
    , ("name.need.trailing-hyphen", verdict (mkNeedName "a-"))
    , ("name.host.valid", verdict (mkHostName "a"))
    , ("name.host.long", verdict (mkHostName (Text.replicate 64 "a")))
    , ("kind-replicas.zero", verdict (mkKindReplicas 0))
    , ("kind-replicas.one", verdict (mkKindReplicas 1))
    , ("replicas.zero", verdict (mkReplicas 0))
    , ("replicas.one", verdict (mkReplicas 1))
    , ("cluster.ok", verdict (cluster "h1" ["h1"]))
    , ("cluster.host-undeclared", verdict (cluster "missing" ["h1"]))
    , ("cluster.unreferenced-host", verdict (cluster "h1" ["h1", "h2"]))
    , ("cluster.duplicate-host", verdict (cluster "h1" ["h1", "h1"]))
    ]
      <> [("need." <> Text.toLower (Text.pack (show arm)), verdict (need arm)) | arm <- [minBound .. maxBound]]
      <> [ ("workload.exact", verdict (workload (1, 1, 1) (1, 1, 1) Nothing))
         , ("workload.over-cpu", verdict (workload (2, 1, 1) (1, 1, 1) Nothing))
         , ("workload.over-memory", verdict (workload (1, 2, 1) (1, 1, 1) Nothing))
         , ("workload.over-ephemeral", verdict (workload (1, 1, 2) (1, 1, 1) Nothing))
         , ("workload.pad-exact", verdict (workload (1, 1, 1) (2, 2, 2) (Just (1, 1, 1))))
         , ("workload.pad-over-cpu", verdict (workload (1, 1, 1) (2, 2, 2) (Just (2, 1, 1))))
         , ("workload.pad-over-memory", verdict (workload (1, 1, 1) (2, 2, 2) (Just (1, 2, 1))))
         , ("workload.pad-over-ephemeral", verdict (workload (1, 1, 1) (2, 2, 2) (Just (1, 1, 2))))
         , ("workload.pad-zero", verdict (workload (1, 1, 1) (2, 2, 2) (Just (0, 0, 0))))
         , ("workload.pad-one-axis", verdict (workload (1, 1, 1) (2, 2, 2) (Just (0, 0, 1))))
         , ("app.ok", verdict (app ["assets"]))
         , ("app.empty-needs", verdict (app []))
         , ("app.duplicate-need", verdict (app ["assets", "assets"]))
         , ("deployment.ok", verdict (deployment ["assets"]))
         , ("deployment.empty-bindings", verdict (deployment []))
         , ("deployment.duplicate-binding", verdict (deployment ["assets", "assets"]))
         , ("root.ok", verdict (root [cluster "h1" ["h1"]]))
         , ("root.empty-clusters", verdict (root []))
         ]
  host name = HostSpec <$> mkHostName name <*> pure (HostResources 1 1 1 1)
  cluster kindHost names = do
    name <- mkClusterName "c"
    replicas <- mkKindReplicas 1
    hosts <- traverse host names
    case hosts of
      [] -> Left EmptyClusters
      first : rest -> mkClusterSpec name kindHost replicas (first :| rest)
  need arm = mkNeedName "n" >>= mkNeedSpec arm
  workload (cpu, memory, ephemeral) (limitCpu, limitMemory, limitEphemeral) pad =
    mkWorkloadSpec (PodResources cpu memory ephemeral) (PodResources limitCpu limitMemory limitEphemeral) (fmap (\(a, b, c) -> PodResources a b c) pad)
  plainWorkload = workload (1, 1, 1) (1, 1, 1) Nothing
  app needNames = do
    name <- mkAppName "a"
    needs <- traverse (\text -> mkNeedName text >>= mkNeedSpec ObjectStore) needNames
    mkAppSpec name needs =<< plainWorkload
  deployment needNames = do
    name <- mkAppName "a"
    replicas <- mkReplicas 1
    bindings <- traverse (\text -> (\label -> BindingSpec label CanonicalProvider SingleNode) <$> mkNeedName text) needNames
    mkDeploymentRules name bindings (DistributionRule replicas)
  root clusters = do
    built <- sequence clusters
    mkRootInForceSpec built [] []

-- | What the freeze makes of each text: its hash, or the tag of its refusal.
freezeSection :: FilePath -> IO ()
freezeSection suite = do
  fixtures
  baselineText <- pure (exampleText (head' corpus))
  baseline <- freezeText examples (baselineText <> "\n")
  again <- freezeText examples (baselineText <> "\n")
  byFile <- mapM (\name -> freezeFile (examples </> (name <> ".dhall")))
    ["kind-single-objectstore", "local-import-twin", "shape-swap-sibling", "replicas-3-sibling"]
  refused <- mapM (\name -> freezeFile (examples </> (Text.unpack name <> ".dhall"))) refusedNames
  missing <- freezeFile (examples </> "absent.dhall")
  inline <- freezeText fixtureDirectory "1\n"
  nested <- freezeFile (fixtureDirectory </> "nested-a.dhall")
  parent <- freezeFile (fixtureDirectory </> "sub" </> "parent-child.dhall")
  cycle' <- freezeFile (fixtureDirectory </> "cycle-a.dhall")
  fallback <- freezeText examples "./local-import-name.dhall ? env:SPINE_UNSET_VARIABLE\n"
  writeLines (suite </> "freeze.tsv") $
    [ tabs ["baseline", result baseline]
    , tabs ["baseline-again", result again]
    ]
      <> [tabs [name, result outcome] | (name, outcome) <- zip ["baseline-file", "local-twin", "shape-swap", "replicas-3"] byFile]
      <> [tabs [name, result outcome] | (name, outcome) <- zip refusedNames refused]
      <> [ tabs ["missing-file", result missing]
         , tabs ["inline-one", result inline]
         , tabs ["nested", result nested]
         , tabs ["parent", result parent]
         , tabs ["cycle", result cycle']
         , tabs ["fallback-forbidden", result fallback]
         ]
 where
  examples = suite </> "examples"
  fixtureDirectory = suite </> "freeze-fixtures"
  head' items = case items of
    item : _ -> item
    [] -> Example "" ""
  refusedNames :: [Text]
  refusedNames =
    [ "forbidden-env"
    , "forbidden-remote"
    , "forbidden-alternative"
    , "forbidden-transitive"
    , "forbidden-absolute"
    , "forbidden-home"
    , "non-code-import"
    , "parse-failure"
    , "ill-typed-alternative"
    ]
  fixtures = do
    writeText (fixtureDirectory </> "nested-a.dhall") "./nested-b.dhall\n"
    writeText (fixtureDirectory </> "nested-b.dhall") "./nested-c.dhall\n"
    writeText (fixtureDirectory </> "nested-c.dhall") "1\n"
    writeText (fixtureDirectory </> "sub" </> "parent-child.dhall") "../nested-c.dhall\n"
    writeText (fixtureDirectory </> "cycle-a.dhall") "./cycle-b.dhall\n"
    writeText (fixtureDirectory </> "cycle-b.dhall") "./cycle-a.dhall\n"

result :: Either ImportRefusal Frozen -> Text
result outcome = case outcome of
  Left refusal -> "refused:" <> importRefusalTag refusal
  Right frozen -> "frozen:" <> frozenHash frozen

-- | Encode then decode returns the authored value; an authored value that is illegal is
-- refused at the tag of its own dimension.
decodeSection :: FilePath -> IO ()
decodeSection suite = do
  positives <- mapM roundTrip
    [ ("kind-single-objectstore", baselineRoot)
    , ("shape-swap-sibling", variant 16 (Distributed 3) 1)
    , ("replicas-3-sibling", variant 16 SingleNode 3)
    ]
  raws <- mapM rawRow rawCases
  walked <- mapM exampleRow corpus
  writeLines (suite </> "decode.tsv") (positives <> raws <> map fst walked)
  writeLines (suite </> "lower.tsv") [row | (_, Just row) <- walked]
 where
  -- Each example, frozen and decoded by the stages themselves; one that decodes is also lowered.
  exampleRow example = do
    let name = exampleName example
    outcome <- decodeFrozen (suite </> "examples" </> (Text.unpack name <> ".dhall"))
    pure $ case outcome of
      Left (Left refusal) -> (tabs ["example." <> name, "frozen:refused:" <> importRefusalTag refusal], Nothing)
      Left (Right refusal) -> (tabs ["example." <> name, "refused:" <> decodeRefusalTag refusal], Nothing)
      Right root -> (tabs ["example." <> name, "ok"], Just (tabs [name, either lowerRefusalTag (const "ok") (lowerDeployment root)]))
  roundTrip (name, built) = case built of
    Left problem -> pure (tabs ["roundtrip." <> name, "unbuilt:" <> specErrorTag problem])
    Right value -> do
      frozen <- freezeText (suite </> "examples") (encodeRoot value)
      pure $ tabs
        [ "roundtrip." <> name
        , case frozen of
            Left refusal -> "frozen:refused:" <> importRefusalTag refusal
            Right ready -> case decodeRoot ready of
              Left refusal -> "decoded:refused:" <> decodeRefusalTag refusal
              Right decoded -> (if decoded == value then "equal" else "differ") <> ":" <> (if dumpRoot decoded == dumpRoot value then "dump-equal" else "dump-differ")
        ]
  rawRow (name, raw) = do
    frozen <- freezeText (suite </> "examples") (encodeRaw raw)
    pure $ tabs
      [ "raw." <> name
      , case frozen of
          Left refusal -> "frozen:refused:" <> importRefusalTag refusal
          Right ready -> case decodeRoot ready of
            Left refusal -> "refused:" <> decodeRefusalTag refusal
            Right _ -> "ok"
      ]
  base = rawOf' baselineRoot
  rawOf' built = either (const (Raw.RawRoot [] [] [])) rawOf built
  cluster0 = case Raw.rootClusters base of
    first : _ -> first
    [] -> Raw.RawCluster "" (Raw.KindTopology (Raw.RawKind "" 0)) []
  app0 = case Raw.rootApps base of
    first : _ -> first
    [] -> Raw.RawApp "" [] (Raw.RawWorkload (Raw.RawPod 0 0 0) (Raw.RawPod 0 0 0) Nothing)
  deployment0 = case Raw.rootDeployments base of
    first : _ -> first
    [] -> Raw.RawDeployment "" [] (Raw.RawDistribution 0)
  withCluster change = base {Raw.rootClusters = [change cluster0]}
  withApp change = base {Raw.rootApps = [change app0]}
  withDeployment change = base {Raw.rootDeployments = [change deployment0]}
  withKind change cluster = case Raw.clusterTopology cluster of
    Raw.KindTopology kind -> cluster {Raw.clusterTopology = Raw.KindTopology (change kind)}
  extraHost name cluster = cluster {Raw.clusterHosts = Raw.clusterHosts cluster <> [Raw.RawHost name 1 1 1 1]}
  firstBinding change deployment = case Raw.bindings deployment of
    first : rest -> deployment {Raw.bindings = change first : rest}
    [] -> deployment
  shaped nodes = withDeployment (firstBinding (\binding -> binding {Raw.bindingShape = Raw.Distributed nodes}))
  rawCases :: [(Text, Raw.RawRoot)]
  rawCases =
    [ ("baseline", base)
    , ("empty-clusters", base {Raw.rootClusters = []})
    , ("zero-kind-replicas", withCluster (withKind (\kind -> kind {Raw.kindReplicas = 0})))
    , ("host-undeclared", withCluster (withKind (\kind -> kind {Raw.kindHost = "missing"})))
    , ("no-hosts", withCluster (\cluster -> cluster {Raw.clusterHosts = []}))
    , ("unreferenced-host", withCluster (extraHost "spare"))
    , ("duplicate-host", withCluster (extraHost "kind-host"))
    , ("invalid-cluster-name", withCluster (\cluster -> cluster {Raw.clusterName = "Bad"}))
    , ("invalid-host-name", withCluster (\cluster -> cluster {Raw.clusterHosts = [(head' (Raw.clusterHosts cluster)) {Raw.hostName = "Bad"}]}))
    , ("invalid-app-name", withApp (\app -> app {Raw.appName = "Bad"}))
    , ("invalid-need-name", withApp (\app -> app {Raw.needs = [(head' (Raw.needs app)) {Raw.needName = "Bad"}]}))
    , ("inference-engine-need", withApp (\app -> app {Raw.needs = [(head' (Raw.needs app)) {Raw.needCapability = Raw.InferenceEngine}]}))
    , ("duplicate-need", withApp (\app -> app {Raw.needs = Raw.needs app <> Raw.needs app}))
    , ("empty-bindings", withDeployment (\deployment -> deployment {Raw.bindings = []}))
    , ("duplicate-binding", withDeployment (\deployment -> deployment {Raw.bindings = Raw.bindings deployment <> Raw.bindings deployment}))
    , ("unbuilt-provider", withDeployment (firstBinding (\binding -> binding {Raw.bindingProvider = "Alternate"})))
    , ("distributed-one", shaped 1)
    , ("distributed-two", shaped 2)
    , ("pad-present", withApp (\app -> app {Raw.workload = (Raw.workload app) {Raw.workloadHeadroom = Just (Raw.RawPod 1 1 1)}}))
    ]
  head' :: [a] -> a
  head' items = case items of
    item : _ -> item
    [] -> error "the baseline has an element here"
