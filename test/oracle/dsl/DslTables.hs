{-# LANGUAGE OverloadedStrings #-}

-- | Every expectation the oracle holds, typed here from the contract and the doctrine, never
-- read from the product: the host classification, the boundaries of the typed specification,
-- the tags and stages of the refusals, the stage dumps, and the objects the baseline
-- renders. The only quantities parameterised are the authored names, the shape, and the
-- replica count, which the examples and the runner's perturbation vary.
module DslTables
  ( sentinel
  , Params (..)
  , HostP (..)
  , nodeNames
  , Shape (..)
  , Arm (..)
  , NeedP (..)
  , paramNeed
  , paramShape
  , armNamespace
  , armSlug
  , armName
  , membersOf
  , baselineParams
  , Expected (..)
  , expectedObjects
  , chainOrder
  , frameOf
  , expectedDecoded
  , expectedLowered
  , expectedPlan
  , expectedRenderActivations
  , expectedServiceRow
  , expectedPlacementRow
  , expectedNodesRow
  , expectedReservations
  , unitsOf
  , hostGrid
  , detectGrid
  , labelGrid
  , extensionGrid
  , specGrid
  , freezeRefusals
  , decodeRawGrid
  , exampleDecodeTags
  , exampleLowerTags
  , pipelineRefusals
  , positiveExamples
  , refusedExamples
  , corpusInventory
  , differentialGrid
  , chainTable
  , interpretTable
  , schemaLiteral
  , stageFiles
  , refusalStageFiles
  , wireMessages
  , differentialEnvelopes
  ) where

import Data.Text (Text)
import Data.Text qualified as Text
import Numeric.Natural (Natural)

-- | The placeholder the runner rewrites; the corpus examples keep it.
sentinel :: Text
sentinel = "0b5e17e11a0c0ffee0de1e9a7e5ba5ed"

data Shape = Single | Spread
  deriving stock (Eq, Show)

-- | The capabilities the corpus authors.
data Arm = ObjectStoreArm | SqlArm
  deriving stock (Eq, Show)

-- | A need an application authors, and the shape its binding takes.
data NeedP = NeedP
  { needArm :: Arm
  , needLabel :: Text
  , needShape :: Shape
  }

-- | What the authored names, the needs and their shapes, the replica count, the nodes, and
-- what each node holds are in a run, and the node the oracle states each workload lands on.
data HostP = HostP
  { hostPName :: Text
  , hostPSubstrate :: Text
  , hostPArchitecture :: Text
  , hostPLanes :: [Text]
  , hostPTaints :: [Text]
  }

data Params = Params
  { paramApp :: Text
  , paramNeeds :: [NeedP]
  , paramReplicas :: Natural
  , paramNodes :: Natural
  , paramHost :: (Natural, Natural, Natural, Natural)
  , paramNodeOf :: Text -> Text
  , paramRke2 :: [HostP]
  }

-- | One kind node on a host of sixteen processors: every workload lands on the one node.
baselineParams :: Params
baselineParams = Params ("notes-" <> sentinel) [NeedP ObjectStoreArm ("assets-" <> sentinel) Single] 1 1 (16, 64, 500, 110) (const "kind-host-1") []

-- | The first need's label, for the examples that author exactly one.
paramNeed :: Params -> Text
paramNeed params = case paramNeeds params of
  need : _ -> needLabel need
  [] -> ""

-- | The shape of the first need.
paramShape :: Params -> Shape
paramShape params = case paramNeeds params of
  need : _ -> needShape need
  [] -> Single

-- | An object the baseline renders. A kind that is @Nothing@ is not asserted.
data Expected = Expected
  { expectedIdentity :: Text
  , expectedKind :: Maybe Text
  , expectedName :: Text
  , expectedNamespace :: Maybe Text
  , expectedActivation :: Text
  , expectedReconcile :: Text
  , expectedOwner :: Text
  }

armSlug :: Arm -> Text
armSlug arm = case arm of
  ObjectStoreArm -> "objectstore"
  SqlArm -> "sql"

armName :: Arm -> Text
armName arm = case arm of
  ObjectStoreArm -> "ObjectStore"
  SqlArm -> "Sql"

armNamespace :: Arm -> Text
armNamespace arm = case arm of
  ObjectStoreArm -> "amoebius-minio"
  SqlArm -> "amoebius-postgres"

armProduct :: Arm -> Text
armProduct arm = case arm of
  ObjectStoreArm -> "MinIO"
  SqlArm -> "Patroni"

-- | The provider's members: one for a single node, three when spread.
membersOf :: Shape -> [Text]
membersOf shape = case shape of
  Single -> ["member-0"]
  Spread -> ["member-0", "member-1", "member-2"]

-- | The unit that bootstraps the schema of a relational provider.
bootstrapOf :: Arm -> [Text]
bootstrapOf arm = case arm of
  SqlArm -> ["schema-bootstrap"]
  ObjectStoreArm -> []

-- | Every object a run renders, in no particular order.
expectedObjects :: Params -> [Expected]
expectedObjects params = app <> global <> concatMap provider (paramNeeds params) <> [Expected ("node/" <> hostPName host) (Just "Node") (hostPName host) Nothing "Immediate" "ServerSideApply" "deployment-global" | host <- paramRke2 params]
 where
  name = paramApp params
  app =
    [ Expected ("app/" <> name <> "/namespace") (Just "Namespace") name Nothing "Immediate" "ServerSideApply" name
    , Expected ("app/" <> name <> "/deployment") (Just "Deployment") name (Just name) "AfterManagedCapacityReady" "ServerSideApply" name
    , Expected ("app/" <> name <> "/service") (Just "Service") name (Just name) "AfterManagedCapacityReady" "ServerSideApply" name
    ]
  global =
    [ Expected "global/namespace" (Just "Namespace") "namespace" Nothing "Immediate" "ServerSideApply" "deployment-global"
    , Expected "global/capacity-scheduler" (Just "Deployment") "capacity-scheduler" (Just "amoebius-capacity-scheduler") "BootstrapSchedulerStage" "ServerSideApply" "deployment-global"
    , Expected "global/bootstrap-addon-cutover" (Just "ConfigMap") "bootstrap-addon-cutover" (Just "amoebius-capacity-scheduler") "AfterBootstrapAddonCutover" "CreateBeforeDelete" "deployment-global"
    , Expected "global/managed-capacity-admission" (Just "ValidatingWebhookConfiguration") "managed-capacity-admission" Nothing "AfterManagedCapacityReady" "ServerSideApply" "deployment-global"
    ]
  provider need =
    let label = needLabel need
        prefix = armSlug (needArm need) <> "/" <> label <> "/"
        namespace = Just (armNamespace (needArm need))
     in [ Expected (prefix <> "config") (Just "ConfigMap") "config" namespace "Immediate" "ServerSideApply" label
        , Expected (prefix <> "service") (Just "Service") "service" namespace "AfterBootstrapAddonCutover" "ServerSideApply" label
        ]
          <> [Expected (prefix <> member) (Just "StatefulSet") member namespace "AfterBootstrapAddonCutover" "ServerSideApply" label | member <- membersOf (needShape need)]
          <> [Expected (prefix <> member <> "/pvc") (Just "PersistentVolumeClaim") ("data-" <> member <> "-0") namespace "AfterBootstrapAddonCutover" "ServerSideApply" label | member <- membersOf (needShape need)]
          <> [Expected (prefix <> unit) (Just "Job") unit namespace "AfterBootstrapAddonCutover" "ReplaceOnChange" label | unit <- bootstrapOf (needArm need)]
          <> case needShape need of
            Single -> []
            Spread ->
              [ Expected (prefix <> "discovery") Nothing "discovery" namespace "AfterManagedCapacityReady" "ServerSideApply" label
              , Expected (prefix <> "quorum-policy") Nothing "quorum-policy" namespace "AfterManagedCapacityReady" "ServerSideApply" label
              ]

-- | The rank of an activation in the readiness chain: scheduler bootstrap, add-on cutover,
-- managed authority, platform pods.
frameRank :: Text -> Int
frameRank activation = case activation of
  "Immediate" -> 0
  "BootstrapSchedulerStage" -> 1
  "AfterBootstrapAddonCutover" -> 2
  _ -> 3

frameOf :: Text -> Text
frameOf activation = case activation of
  "Immediate" -> "ImmediateFrame"
  "BootstrapSchedulerStage" -> "BootstrapSchedulerFrame"
  "AfterBootstrapAddonCutover" -> "AfterBootstrapAddonCutoverFrame"
  _ -> "AfterManagedCapacityReadyFrame"

-- | The order the chain applies objects: by frame, then by identity.
chainOrder :: [Expected] -> [Expected]
chainOrder objects = sortObjects objects
 where
  sortObjects items = case items of
    [] -> []
    pivot : rest -> sortObjects [item | item <- rest, before item pivot] <> [pivot] <> sortObjects [item | item <- rest, not (before item pivot)]
  before left right = (frameRank (expectedActivation left), expectedIdentity left) < (frameRank (expectedActivation right), expectedIdentity right)

-- | The units the plan sees: the application, and for each need every provider member and
-- the schema bootstrap when the provider has one.
unitsOf :: Params -> [Text]
unitsOf params = ["app/" <> paramApp params] <> concat [[armSlug (needArm need) <> "/" <> needLabel need <> "/" <> member | member <- membersOf (needShape need) <> bootstrapOf (needArm need)] | need <- paramNeeds params]

tab :: Text -> Text -> Text
tab key value = key <> "\t" <> value

commas :: [Text] -> Text
commas = Text.intercalate ","

shapeText :: Shape -> Text
shapeText shape = case shape of
  Single -> "SingleNode"
  Spread -> "Distributed 3"

natText :: Natural -> Text
natText = Text.pack . show

hostCommas :: Params -> Text
hostCommas params = let (cpu, memory, ephemeral, pods) = paramHost params in commas (map natText [cpu, memory, ephemeral, pods])

-- | The capacity of the supply: every node's allocatable resources, summed.
supplyCommas :: Params -> Text
supplyCommas params = let (cpu, memory, ephemeral, pods) = paramHost params; n = paramNodes params in commas (map natText [n * cpu, n * memory, n * ephemeral, n * pods])

-- | The decoded dump of an example that differs from the baseline only in names, needs, shapes,
-- replicas, nodes, and what a node holds.
expectedDecoded :: Params -> [Text]
expectedDecoded params =
  [tab "cluster.0.name" (if null (paramRke2 params) then "kind-a" else "rke2-a")]
    <> topology
    <> concat
      [ [ tab (base <> ".name") (hostPName host)
        , tab (base <> ".cpu") (natText cpu)
        , tab (base <> ".memory") (natText memory)
        , tab (base <> ".ephemeral") (natText ephemeral)
        , tab (base <> ".pods") (natText pods)
        , tab (base <> ".substrate") (hostPSubstrate host)
        , tab (base <> ".architecture") (hostPArchitecture host)
        , tab (base <> ".lanes") (commas (hostPLanes host))
        , tab (base <> ".taints") (commas (hostPTaints host))
        ]
      | (index, host) <- zip [0 :: Int ..] hosts
      , let base = "cluster.0.host." <> Text.pack (show index)
      ]
    <> [tab "app.0.name" (paramApp params)]
    <> concat
      [ [ tab ("app.0.need." <> index <> ".capability") (armName (needArm need))
        , tab ("app.0.need." <> index <> ".name") (needLabel need)
        ]
      | (position, need) <- zip [0 :: Int ..] (paramNeeds params)
      , let index = Text.pack (show position)
      ]
    <> [ tab "app.0.workload.requests" "1,2,4"
       , tab "app.0.workload.limits" "2,4,8"
       , tab "app.0.workload.headroom" "none"
       , tab "deployment.0.app" (paramApp params)
       ]
    <> concat
      [ [ tab ("deployment.0.binding." <> index <> ".need") (needLabel need)
        , tab ("deployment.0.binding." <> index <> ".provider") "Canonical"
        , tab ("deployment.0.binding." <> index <> ".shape") (shapeText (needShape need))
        ]
      | (position, need) <- zip [0 :: Int ..] (paramNeeds params)
      , let index = Text.pack (show position)
      ]
    <> [tab "deployment.0.distribution.replicas" (natText (paramReplicas params))]
 where
  (cpu, memory, ephemeral, pods) = paramHost params
  hosts = if null (paramRke2 params) then [HostP "kind-host" "linux-cpu" "amd64" ["linux-cpu/amd64"] []] else paramRke2 params
  topology = if null (paramRke2 params)
    then [tab "cluster.0.topology" "KindTopology", tab "cluster.0.topology.host" "kind-host", tab "cluster.0.topology.replicas" (natText (paramNodes params))]
    else [tab "cluster.0.topology" "Rke2Topology", tab "cluster.0.topology.servers" (commas (map hostPName (take 3 hosts))), tab "cluster.0.topology.agents" (commas (map hostPName (drop 3 hosts)))]

-- | The lowered dump: the topology, the bound application, the bound services, and the supply.
expectedLowered :: Params -> [Text]
expectedLowered params =
  [ tab "topology.cluster" (if null (paramRke2 params) then "kind-a" else "rke2-a")
  , tab "topology.engine" (if null (paramRke2 params) then "KindEngine" else "Rke2Engine")
  , tab "topology.nodes" (commas nodes)
  ]
    <> concat
      [ [ tab (base <> ".host") (if null (paramRke2 params) then "kind-host" else node)
        , tab (base <> ".allocatable") (hostCommas params)
        , tab (base <> ".taints") (commas taints)
        , tab (base <> ".substrate") (hostPSubstrate host)
        , tab (base <> ".architecture") (hostPArchitecture host)
        , tab (base <> ".lanes") (commas (hostPLanes host))
        , tab (base <> ".role") role
        ]
      | (index, node) <- zip [0 :: Int ..] nodes
      , let base = "topology.node." <> node
      , let host = if null (paramRke2 params) then HostP "kind-host" "linux-cpu" "amd64" ["linux-cpu/amd64"] [] else paramRke2 params !! index
      , let role = if null (paramRke2 params) then "KindWorker" else if index < 3 then "Rke2Server" else "Rke2Agent"
      , let taints = (if role == "Rke2Server" then ["node-role.kubernetes.io/control-plane"] else []) <> hostPTaints host
      ]
    <> [ tab "bound.app" app
       , tab ("bound.app." <> app <> ".unit") ("app/" <> app)
       , tab ("bound.app." <> app <> ".replicas") (natText (paramReplicas params))
       , tab ("bound.app." <> app <> ".revision") "1"
       , tab ("bound.app." <> app <> ".envelope") "requests=1,2,4,1;limits=2,4,8,1;headroom=0,0,0,0"
       , tab ("bound.app." <> app <> ".needs") (commas [armName (needArm need) <> ":" <> needLabel need | need <- paramNeeds params])
       ]
    <> concatMap serviceRows (sortOn' needLabel (paramNeeds params))
    <> [ tab "bound.units" (commas units)
       , tab "supply.state" "InfrastructureAlreadyPresent"
       , tab "supply.capacity" (supplyCommas params)
       , tab "supply.snapshot" "1"
       , tab "supply.identities" (commas units)
       ]
 where
  app = paramApp params
  nodes = nodeNames params
  units = unitsOf params
  serviceRows need =
    let label = needLabel need
        prefix = armSlug (needArm need) <> "/" <> label <> "/"
        service suffix = "bound.service." <> label <> suffix
     in [ tab "bound.service" label
        , tab (service ".arm") (armName (needArm need))
        , tab (service ".provider") "CanonicalProvider"
        , tab (service ".product") (armProduct (needArm need))
        , tab (service ".shape") (shapeText (needShape need))
        , tab (service ".objects") (commas (objectsOf need))
        , tab (service ".controllers") (commas ([prefix <> member <> ":StatefulSetBody 1 StatefulSetNativeSerial" | member <- membersOf (needShape need)] <> [prefix <> unit <> ":JobBody 1 1 3 600" | unit <- bootstrapOf (needArm need)]))
        , tab (service ".intents") (intentsOf need)
        ]

-- | The services' intents, as the binding names them.
intentsOf :: NeedP -> Text
intentsOf need = case needArm need of
  ObjectStoreArm -> "ObjectStoreProducerIntent ApplicationBuckets \"" <> label <> "\",ObjectStoreGatewayIntent \"" <> label <> "\""
  SqlArm -> "PatroniSqlIntent \"" <> label <> "\",SchemaMigrationIntent \"" <> label <> "\""
 where
  label = needLabel need

-- | Sorted by a key, ascending.
sortOn' :: Ord key => (value -> key) -> [value] -> [value]
sortOn' key items = case items of
  [] -> []
  pivot : rest -> sortOn' key [item | item <- rest, key item < key pivot] <> [pivot] <> sortOn' key [item | item <- rest, key item >= key pivot]

-- | The provider's objects in the order its graph lists them.
objectsOf :: NeedP -> [Text]
objectsOf need =
  [prefix <> "service:Service:stable-endpoint", prefix <> "config:ConfigMap:provider-config"]
    <> [prefix <> member <> ":StatefulSet:member" | member <- membersOf (needShape need)]
    <> [prefix <> unit <> ":Job:bootstrap" | unit <- bootstrapOf (needArm need)]
    <> case needShape need of
      Single -> []
      Spread -> [prefix <> "discovery:Service:member-discovery", prefix <> "quorum-policy:PodDisruptionBudget:quorum-policy"]
 where
  prefix = armSlug (needArm need) <> "/" <> needLabel need <> "/"

-- | The plan dump: the application and the members were demanded and all were present.
expectedPlan :: Params -> [Text]
expectedPlan params =
  [ tab "plan.result" "NoInfrastructureRequired"
  , tab "plan.demand.units" (natText (fromIntegral (length units)))
  , tab "plan.demand.identities" (commas units)
  , tab "plan.materialized.capacity" (supplyCommas params)
  , tab "plan.materialized.identities" (commas units)
  , tab "plan.materialized.receipt-bound" "False"
  ]
 where
  units = unitsOf params

-- | The activation of every object, keyed by identity in the order identities sort.
expectedRenderActivations :: Params -> [Text]
expectedRenderActivations params = [tab ("provision.render." <> expectedIdentity item) (expectedActivation item) | item <- sortedByIdentity (expectedObjects params), expectedKind item /= Just "PersistentVolumeClaim", expectedKind item /= Just "Node"]
 where
  sortedByIdentity items = case items of
    [] -> []
    pivot : rest -> sortedByIdentity [item | item <- rest, expectedIdentity item < expectedIdentity pivot] <> [pivot] <> sortedByIdentity [item | item <- rest, expectedIdentity item >= expectedIdentity pivot]

-- | The placement the fold produced: its kind, how many nodes it used, and their processors.
expectedPlacementRow :: Params -> Text
expectedPlacementRow params = tab "provision.placement" (commas ["FixedPlacement", natText (paramNodes params), natText (paramNodes params * cpu)])
 where
  (cpu, _, _, _) = paramHost params

-- | The nodes the placement ranges over, in the order the topology names them.
nodeNames :: Params -> [Text]
nodeNames params = if null (paramRke2 params)
  then ["kind-host-" <> natText ordinal | ordinal <- [1 .. paramNodes params]]
  else map hostPName (paramRke2 params)

expectedNodesRow :: Params -> Text
expectedNodesRow params = tab "provision.nodes" (commas (nodeNames params))

-- | What was provisioned for each service, in the order the services' names sort.
expectedServiceRow :: Params -> Text
expectedServiceRow params = tab "provision.services" (commas [needLabel need <> ":" <> armName (needArm need) <> ":" <> natText (fromIntegral (length (objectsOf need))) | need <- sortOn' needLabel (paramNeeds params)])

expectedReservations :: Params -> Text
expectedReservations params = tab "provision.scheduler.reservations" (Text.pack (show (length (unitsOf params))))

-- | The host classification, from the operating-system and architecture spellings a host
-- reports and whether a GPU device is present. The table states what the substrate
-- doctrine states: Linux is CPU or, with a device, CUDA; Apple is arm64 only and offers the
-- Metal lane; Windows is amd64 only; an architecture that is not recognised is refused before an
-- operating system that is not recognised.
hostGrid :: [[Text]]
hostGrid =
  [ host "linux" arch gpu (detected substrate architecture lanes)
  | (arch, architecture) <- [("x86_64", "amd64"), ("amd64", "amd64"), ("aarch64", "arm64"), ("arm64", "arm64")]
  , (gpu, substrate, lanes) <-
      [ ("GpuAbsent", "linux-cpu", ["linux-cpu-" <> architecture])
      , ("GpuPresent", "linux-cuda", ["linux-cpu-" <> architecture, "linux-cuda-" <> architecture])
      ]
  ]
    <> [host "linux" "sparc" gpu "refused:UnknownArch:unknown-arch" | gpu <- gpus]
    <> [host "darwin" arch gpu "refused:NotNaturalArchitecture Apple:apple-arm64-only" | arch <- ["x86_64", "amd64"], gpu <- gpus]
    <> [host "darwin" arch gpu "detected:apple:arm64:linux-cpu-arm64,apple-metal" | arch <- ["aarch64", "arm64"], gpu <- gpus]
    <> [host "darwin" "sparc" gpu "refused:UnknownArch:unknown-arch" | gpu <- gpus]
    <> [host os arch gpu "detected:windows:amd64:linux-cpu-amd64" | os <- ["mingw32", "windows"], arch <- ["x86_64", "amd64"], gpu <- gpus]
    <> [host os arch gpu "refused:NotNaturalArchitecture Windows:windows-natural-architecture-only" | os <- ["mingw32", "windows"], arch <- ["aarch64", "arm64"], gpu <- gpus]
    <> [host os "sparc" gpu "refused:UnknownArch:unknown-arch" | os <- ["mingw32", "windows"], gpu <- gpus]
    <> [host "freebsd" arch gpu "refused:UnknownOs:unknown-os" | arch <- ["x86_64", "amd64", "aarch64", "arm64"], gpu <- gpus]
    <> [host "freebsd" "sparc" gpu "refused:UnknownArch:unknown-arch" | gpu <- gpus]
 where
  gpus = ["GpuAbsent", "GpuPresent"]
  host os arch gpu result = ["host", os, arch, gpu, result]
  detected substrate architecture lanes = "detected:" <> substrate <> ":" <> architecture <> ":" <> commas lanes

-- | Which substrate and architecture pairs exist.
detectGrid :: [[Text]]
detectGrid =
  [ ["detect", "linux-cpu", "amd64", "ok"]
  , ["detect", "linux-cpu", "arm64", "ok"]
  , ["detect", "linux-cuda", "amd64", "ok"]
  , ["detect", "linux-cuda", "arm64", "ok"]
  , ["detect", "apple", "amd64", "refused"]
  , ["detect", "apple", "arm64", "ok"]
  , ["detect", "windows", "amd64", "ok"]
  , ["detect", "windows", "arm64", "refused"]
  ]

-- | DNS labels: one to sixty-three lowercase alphanumerics or hyphens, alphanumeric at both ends.
labelGrid :: [[Text]]
labelGrid =
  [ ["label", "empty", "False"]
  , ["label", "one", "True"]
  , ["label", "digit-first", "True"]
  , ["label", "digit-last", "True"]
  , ["label", "inner-hyphen", "True"]
  , ["label", "sixty-three", "True"]
  , ["label", "sixty-four", "False"]
  , ["label", "uppercase", "False"]
  , ["label", "underscore", "False"]
  , ["label", "leading-hyphen", "False"]
  , ["label", "trailing-hyphen", "False"]
  , ["label", "dot", "False"]
  ]

extensionGrid :: [[Text]]
extensionGrid = [["extension", "label", "some"], ["extension", "uppercase", "none"], ["extension", "empty", "none"]]

-- | The boundary of every constructor of the typed specification: the exact answer at the
-- edge and one step beyond it.
specGrid :: [[Text]]
specGrid =
  [ ["name.cluster.valid", "ok"]
  , ["name.cluster.empty", "refused:InvalidName"]
  , ["name.cluster.uppercase", "refused:InvalidName"]
  , ["name.app.valid", "ok"]
  , ["name.app.underscore", "refused:InvalidName"]
  , ["name.need.valid", "ok"]
  , ["name.need.trailing-hyphen", "refused:InvalidName"]
  , ["name.host.valid", "ok"]
  , ["name.host.long", "refused:InvalidName"]
  , ["kind-replicas.zero", "refused:KindReplicasZero"]
  , ["kind-replicas.one", "ok"]
  , ["replicas.zero", "refused:ZeroReplicas"]
  , ["replicas.one", "ok"]
  , ["cluster.ok", "ok"]
  , ["cluster.host-undeclared", "refused:TopologyHostUndeclared"]
  , ["cluster.unreferenced-host", "refused:UnreferencedHost"]
  , ["cluster.duplicate-host", "refused:DuplicateHost"]
  , ["need.objectstore", "ok"]
  , ["need.secretstore", "ok"]
  , ["need.messagebus", "ok"]
  , ["need.sql", "ok"]
  , ["need.identity", "ok"]
  , ["need.observability", "ok"]
  , ["need.registry", "ok"]
  , ["need.edge", "ok"]
  , ["need.inferenceengine", "ok"]
  , ["workload.exact", "ok"]
  , ["workload.over-cpu", "refused:RequestsAboveLimits"]
  , ["workload.over-memory", "refused:RequestsAboveLimits"]
  , ["workload.over-ephemeral", "refused:RequestsAboveLimits"]
  , ["workload.pad-exact", "ok"]
  , ["workload.pad-over-cpu", "refused:RequestsAboveLimits"]
  , ["workload.pad-over-memory", "refused:RequestsAboveLimits"]
  , ["workload.pad-over-ephemeral", "refused:RequestsAboveLimits"]
  , ["workload.pad-zero", "refused:HeadroomAllZero"]
  , ["workload.pad-one-axis", "ok"]
  , ["app.ok", "ok"]
  , ["app.empty-needs", "refused:EmptyNeeds"]
  , ["app.duplicate-need", "refused:DuplicateNeed"]
  , ["deployment.ok", "ok"]
  , ["deployment.empty-bindings", "refused:EmptyBindings"]
  , ["deployment.duplicate-binding", "refused:DuplicateBinding"]
  , ["root.ok", "ok"]
  , ["root.empty-clusters", "refused:EmptyClusters"]
  ]

-- | The examples the freeze refuses, each at its own tag.
freezeRefusals :: [(Text, Text)]
freezeRefusals =
  [ ("forbidden-env", "ForbiddenImport")
  , ("forbidden-remote", "ForbiddenImport")
  , ("forbidden-alternative", "ForbiddenImport")
  , ("forbidden-transitive", "ForbiddenImport")
  , ("forbidden-absolute", "AbsolutePath")
  , ("forbidden-home", "HomePath")
  , ("non-code-import", "NonCodeMode")
  , ("parse-failure", "ParseFailure")
  , ("ill-typed-alternative", "IllTyped")
  ]

-- | Authored values that are illegal in one dimension, decoded, and what the decoder answers.
decodeRawGrid :: [(Text, Text)]
decodeRawGrid =
  [ ("baseline", "ok")
  , ("empty-clusters", "refused:EmptyClusters")
  , ("zero-kind-replicas", "refused:KindReplicasZero")
  , ("host-undeclared", "refused:TopologyHostUndeclared")
  , ("no-hosts", "refused:TopologyHostUndeclared")
  , ("unreferenced-host", "refused:UnreferencedHost")
  , ("duplicate-host", "refused:DuplicateHost")
  , ("invalid-cluster-name", "refused:InvalidName")
  , ("invalid-host-name", "refused:InvalidName")
  , ("invalid-app-name", "refused:InvalidName")
  , ("invalid-need-name", "refused:InvalidName")
  , ("inference-engine-need", "ok")
  , ("duplicate-need", "refused:DuplicateNeed")
  , ("empty-bindings", "refused:EmptyBindings")
  , ("duplicate-binding", "refused:DuplicateBinding")
  , ("unbuilt-provider", "refused:UnbuiltProviderArm")
  , ("distributed-one", "refused:DistributedShape")
  , ("distributed-two", "ok")
  , ("pad-present", "ok")
  ]

-- | What the decoder makes of each example that reaches it.
exampleDecodeTags :: [(Text, Text)]
exampleDecodeTags =
  [ ("kind-single-objectstore", "ok")
  , ("shape-swap-sibling", "ok")
  , ("replicas-3-sibling", "ok")
  , ("local-import-twin", "ok")
  , ("kind-two-nodes", "ok")
  , ("exact-fit-sibling", "ok")
  , ("kind-sql-distributed3", "ok")
  , ("kind-two-needs", "ok")
  , ("one-short-twin", "ok")
  , ("over-capacity-twin", "ok")
  , ("unbound-need", "ok")
  , ("dangling-binding", "ok")
  , ("unknown-deployment", "ok")
  , ("requests-above-limits", "RequestsAboveLimits")
  , ("empty-needs", "EmptyNeeds")
  , ("zero-replicas", "ZeroReplicas")
  , ("headroom-all-zero", "HeadroomAllZero")
  , ("host-short", "ok")
  , ("replicas-over-capacity", "ok")
  , ("product-named-in-app", "DhallFailure")
  , ("shape-in-app", "DhallFailure")
  ]

-- | What lowering makes of each example that decodes.
exampleLowerTags :: [(Text, Text)]
exampleLowerTags =
  [ ("kind-single-objectstore", "ok")
  , ("shape-swap-sibling", "ok")
  , ("replicas-3-sibling", "ok")
  , ("local-import-twin", "ok")
  , ("kind-two-nodes", "ok")
  , ("exact-fit-sibling", "ok")
  , ("kind-sql-distributed3", "ok")
  , ("kind-two-needs", "ok")
  , ("one-short-twin", "ok")
  , ("over-capacity-twin", "ok")
  , ("unbound-need", "UnboundNeed")
  , ("dangling-binding", "DanglingBinding")
  , ("unknown-deployment", "UnknownDeployment")
  , ("host-short", "ok")
  , ("replicas-over-capacity", "ok")
  ]

-- | The pipeline's answer for every refused example: tag and stage.
pipelineRefusals :: [(Text, (Text, Text))]
pipelineRefusals =
  [ ("unbound-need", ("UnboundNeed", "lower"))
  , ("dangling-binding", ("DanglingBinding", "lower"))
  , ("unknown-deployment", ("UnknownDeployment", "lower"))
  , ("forbidden-env", ("ForbiddenImport", "freeze"))
  , ("forbidden-remote", ("ForbiddenImport", "freeze"))
  , ("forbidden-alternative", ("ForbiddenImport", "freeze"))
  , ("forbidden-transitive", ("ForbiddenImport", "freeze"))
  , ("forbidden-absolute", ("AbsolutePath", "freeze"))
  , ("forbidden-home", ("HomePath", "freeze"))
  , ("non-code-import", ("NonCodeMode", "freeze"))
  , ("parse-failure", ("ParseFailure", "freeze"))
  , ("ill-typed-alternative", ("IllTyped", "freeze"))
  , ("requests-above-limits", ("RequestsAboveLimits", "decode"))
  , ("empty-needs", ("EmptyNeeds", "decode"))
  , ("zero-replicas", ("ZeroReplicas", "decode"))
  , ("headroom-all-zero", ("HeadroomAllZero", "decode"))
  , ("product-named-in-app", ("DhallFailure", "decode"))
  , ("shape-in-app", ("DhallFailure", "decode"))
  , ("host-short", ("InfrastructureDemandExceeded", "plan"))
  , ("replicas-over-capacity", ("PostBindExpansionOvercommit", "provision"))
  , ("one-short-twin", ("OneShort", "provision"))
  , ("over-capacity-twin", ("OverCapacity", "provision"))
  ]

positiveExamples :: [Text]
positiveExamples = ["kind-single-objectstore", "shape-swap-sibling", "replicas-3-sibling", "local-import-twin", "kind-two-nodes", "exact-fit-sibling", "kind-sql-distributed3", "kind-two-needs"]

refusedExamples :: [Text]
refusedExamples = map fst pipelineRefusals

-- | Every file the corpus renders, relative to the suite directory.
corpusInventory :: [Text]
corpusInventory =
  map (\name -> "examples/" <> name <> ".dhall") (positiveExamples <> refusedExamples)
    <> ["examples/local-import-name.dhall", "examples/forbidden-transitive-inner.dhall", "schema.dhall"]

-- | The artefacts each stage writes, in stage order.
stageFiles :: [(Text, Text)]
stageFiles =
  [ ("freeze", "frozen.dhall")
  , ("decode", "decoded.dump")
  , ("lower", "lowered.dump")
  , ("recipe", "image-recipe.tsv")
  , ("bake", "bake-catalog.tsv")
  , ("build-argv", "image-build-arguments.tsv")
  , ("plan", "plan.dump")
  , ("provision", "provisioned.dump")
  , ("chain", "manifest.json")
  , ("chain", "chain.dump")
  , ("dry-run", "dry-run.dump")
  ]

-- | The artefacts present when a stage refuses: those of the stages before it.
refusalStageFiles :: Text -> [Text]
refusalStageFiles stage = case stage of
  "freeze" -> []
  "decode" -> ["frozen.dhall"]
  "lower" -> ["frozen.dhall", "decoded.dump"]
  "recipe" -> ["frozen.dhall", "decoded.dump", "lowered.dump"]
  "plan" -> ["frozen.dhall", "decoded.dump", "lowered.dump", "image-recipe.tsv", "bake-catalog.tsv", "image-build-arguments.tsv", "images"]
  "provision" -> ["frozen.dhall", "decoded.dump", "lowered.dump", "image-recipe.tsv", "bake-catalog.tsv", "image-build-arguments.tsv", "images", "plan.dump", "target-model.tsv"]
  "chain" -> ["frozen.dhall", "decoded.dump", "lowered.dump", "image-recipe.tsv", "bake-catalog.tsv", "image-build-arguments.tsv", "images", "plan.dump", "provisioned.dump"]
  _ -> ["frozen.dhall", "decoded.dump", "lowered.dump", "image-recipe.tsv", "bake-catalog.tsv", "image-build-arguments.tsv", "images", "plan.dump", "provisioned.dump", "manifest.json", "chain.dump"]

-- | For each authored leaf: the artefacts that must change when it alone changes, or the
-- refusal it must draw.
differentialGrid :: [(Text, Either (Text, Text) [Text])]
differentialGrid =
  [ ("clusterName", Right ["decoded.dump", "lowered.dump"])
  , ("kindHost", Right ["decoded.dump", "lowered.dump"])
  , ("kindReplicas", Right ["decoded.dump", "lowered.dump"])
  , ("hostName", Right ["decoded.dump", "lowered.dump"])
  , ("hostCpu", Right ["decoded.dump", "lowered.dump"])
  , ("hostMemory", Right ["decoded.dump", "lowered.dump"])
  , ("hostEphemeral", Right ["decoded.dump", "lowered.dump"])
  , ("hostPods", Right ["decoded.dump", "lowered.dump"])
  , ("appName", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("needCapability", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("needName", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("requestsCpu", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("requestsMemory", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("requestsEphemeral", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("limitsCpu", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("limitsMemory", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("limitsEphemeral", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("headroomCpu", Right ["decoded.dump", "lowered.dump"])
  , ("headroomMemory", Right ["decoded.dump", "lowered.dump"])
  , ("headroomEphemeral", Right ["decoded.dump", "lowered.dump"])
  , ("deploymentOf", Left ("UnknownDeployment", "lower"))
  , ("bindingNeed", Left ("UnboundNeed", "lower"))
  , ("bindingProvider", Left ("UnbuiltProviderArm", "decode"))
  , ("bindingShape", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  , ("replicas", Right ["decoded.dump", "lowered.dump", "manifest.json"])
  ]

-- | The step algebra's table: how many steps each frame leaves, the frame that follows, and
-- the constructor's refusals.
chainTable :: [[Text]]
chainTable =
  [ ["count", "11"]
  , ["steps-from", "ImmediateFrame", "11"]
  , ["steps-from", "BootstrapSchedulerFrame", "8"]
  , ["steps-from", "AfterBootstrapAddonCutoverFrame", "7"]
  , ["steps-from", "AfterManagedCapacityReadyFrame", "3"]
  , ["steps-from", "BoundaryFrame", "0"]
  , ["next-frame", "ImmediateFrame", "BootstrapSchedulerFrame"]
  , ["next-frame", "BootstrapSchedulerFrame", "AfterBootstrapAddonCutoverFrame"]
  , ["next-frame", "AfterBootstrapAddonCutoverFrame", "AfterManagedCapacityReadyFrame"]
  , ["next-frame", "AfterManagedCapacityReadyFrame", "Nothing"]
  , ["next-frame", "BoundaryFrame", "Nothing"]
  , ["mk-step", "empty-label", "refused:EmptyLabel"]
  , ["mk-step", "apply-without-objects", "refused:ApplyWithoutObjects"]
  , ["mk-step", "objects-on-build", "refused:ObjectsOnNonApply"]
  , ["mk-step", "apply", "ok"]
  , ["mk-step", "empty-ApplyObjects", "refused:ApplyWithoutObjects"]
  , ["mk-step", "empty-DockerBuild", "ok"]
  , ["mk-step", "empty-DockerPush", "ok"]
  , ["mk-step", "empty-PulumiUp", "ok"]
  , ["mk-step", "empty-HostProcess", "ok"]
  , ["validate", "baseline", "ok"]
  , ["validate", "reversed", "refused:NonMonotoneFrames"]
  , ["validate", "reversed-pair", "refused:NonMonotoneFrames"]
  , ["manifest", "skips-non-apply", "ok"]
  , ["validate", "duplicate", "refused:DuplicateStepLabel"]
  , ["validate", "empty", "ok"]
  , ["chain", "empty", "ok:0"]
  , ["chain", "objects", "ok:11"]
  ]

-- | The interpreter's table for the scenarios whose answer is fixed; the chain scenarios
-- that name a step by its identity are judged separately.
interpretTable :: [[Text]]
interpretTable =
  [ ["full.result", "ok:11"]
  , ["from-cutover.result", "ok:7"]
  , ["from-managed.result", "ok:3"]
  , ["from-boundary.result", "ok:0"]
  , ["hostile-path.result", "ok:3"]
  , ["hostile-path.environment-restored", "True"]
  , ["unsupported-kind.result", "UnsupportedStepKind:DockerBuild"]
  , ["single-step.result", "ok:1"]
  , ["apply-full.result", "applied:11"]
  , ["missing-environment.exit", "ExitFailure 2"]
  , ["dry-run.fake-directory", "absent"]
  , ["dry-run.planned", "11"]
  , ["dry-run.unsupported", "Left:UnsupportedStepKind DockerBuild"]
  , ["real-executor.exit", "ExitFailure 2"]
  ]

-- | The type every authored specification must have, written out independently of the
-- decoder the product derives it from.
schemaLiteral :: Text
schemaLiteral =
  "{ rootClusters : List { clusterName : Text, clusterTopology : < KindTopology : { kindHost : Text, kindReplicas : Natural } | Rke2Topology : { rke2Servers : < Single : Text | Three : { server1 : Text, server2 : Text, server3 : Text } | Five : { serverA : Text, serverB : Text, serverC : Text, serverD : Text, serverE : Text } >, rke2Agents : List Text } >, clusterHosts : List { hostName : Text, hostCpu : Natural, hostMemory : Natural, hostEphemeral : Natural, hostPods : Natural, hostOs : Text, hostArch : Text, hostGpu : Bool, hostTaints : List Text } }"
    <> ", rootApps : List { appName : Text, needs : List { needCapability : < ObjectStore | SecretStore | MessageBus | Sql | Identity | Observability | Registry | Edge | InferenceEngine >, needName : Text }, workload : { workloadRequests : { podCpu : Natural, podMemory : Natural, podEphemeral : Natural }, workloadLimits : { podCpu : Natural, podMemory : Natural, podEphemeral : Natural }, workloadHeadroom : Optional { podCpu : Natural, podMemory : Natural, podEphemeral : Natural } } }"
    <> ", rootDeployments : List { deploymentOf : Text, bindings : List { bindingNeed : Text, bindingProvider : Text, bindingShape : < SingleNode | Distributed : Natural >, bindingInference : Optional { engineRuntime : < AppleMetal | Cuda | LinuxCpu >, engineFamily : < LlamaCpp | WhisperCpp | Onnx | Vllm | Pytorch | Diffusers | Transformers | Audiveris > } }, distribution : { replicas : Natural } }"
    <> ", rootExtensions : List { extensionId : Text, extensionParameters : < BuildCacheParameters : { cacheBudgetBytes : Natural, cacheTemporaryBytes : Natural, cacheFirstMissConcurrency : Natural } | CoordinationParameters : Text | InferenceParameters : Natural | TrainingParameters : Text > } }"

-- | The wire messages the repository declares: name, then field names with their numbers.
wireMessages :: [(Text, [(Text, Integer)])]
wireMessages =
  [ ("MessageIdData", [("ledgerId", 1), ("entryId", 2), ("partition", 3)])
  , ("MessageMetadata", [("producer_name", 1), ("sequence_id", 2), ("publish_time", 3)])
  , ("CommandConnect", [("client_version", 1), ("protocol_version", 4)])
  ]

-- | The application's resource envelope after each leaf that feeds it is changed alone; every
-- other leaf leaves the baseline's envelope.
differentialEnvelopes :: [(Text, Text)]
differentialEnvelopes =
  [ ("requestsCpu", "requests=2,2,4,1;limits=2,4,8,1;headroom=0,0,0,0")
  , ("requestsMemory", "requests=1,3,4,1;limits=2,4,8,1;headroom=0,0,0,0")
  , ("requestsEphemeral", "requests=1,2,5,1;limits=2,4,8,1;headroom=0,0,0,0")
  , ("limitsCpu", "requests=1,2,4,1;limits=3,4,8,1;headroom=0,0,0,0")
  , ("limitsMemory", "requests=1,2,4,1;limits=2,5,8,1;headroom=0,0,0,0")
  , ("limitsEphemeral", "requests=1,2,4,1;limits=2,4,9,1;headroom=0,0,0,0")
  , ("headroomCpu", "requests=1,2,4,1;limits=2,4,8,1;headroom=1,0,0,0")
  , ("headroomMemory", "requests=1,2,4,1;limits=2,4,8,1;headroom=0,1,0,0")
  , ("headroomEphemeral", "requests=1,2,4,1;limits=2,4,8,1;headroom=0,0,1,0")
  ]
