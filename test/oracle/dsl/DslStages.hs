{-# LANGUAGE OverloadedStrings #-}

-- | The judgement of one run's stage artefacts: the same checks apply to an example the
-- suite compiled and to the specification the runner perturbed and the shipped binary
-- compiled, differing only in the names, the shape, and the replica count they expect.
module DslStages
  ( View (..)
  , corpusView
  , stageRows
  , fakeTranscriptRows
  , manifestObjects
  , manifestEntries
  ) where

import Data.Aeson (Value (..), eitherDecodeStrict')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Foldable (toList)
import Data.Map.Strict qualified as Map
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Encoding
import DslParse
import DslTables
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath ((</>))

-- | Where a run's artefacts are, what it was given, and how its rows are named.
data View = View
  { viewDirectory :: FilePath
  , viewParams :: Params
  , viewName :: Text -> Text -> Text
  }

corpusView :: FilePath -> Text -> Params -> View
corpusView suite example params = View (suite </> "stages" </> Text.unpack example) params (\family what -> family <> "." <> example <> "." <> what)

linesOf :: Maybe Text -> Maybe [Text]
linesOf = fmap (filter (not . Text.null) . Text.lines)

-- | The rows a run's artefacts earn in every family from decode through pipeline.
stageRows :: View -> IO [Row]
stageRows view = do
  let directory = viewDirectory view
      params = viewParams view
      name = viewName view
      expectedChain = chainOrder (expectedObjects params)
  decoded <- readText (directory </> "decoded.dump")
  lowered <- readText (directory </> "lowered.dump")
  plan <- readText (directory </> "plan.dump")
  provisioned <- readText (directory </> "provisioned.dump")
  manifest <- readBytes (directory </> "manifest.json")
  chainDump <- readBytes (directory </> "chain.dump")
  dryRun <- readText (directory </> "dry-run.dump")
  present <- directoryFiles directory
  let payloads = maybe [] splitPayloads manifest
      objects = mapMaybe parseObject payloads
  pure
    [ expectEqual (name "decode" "dump") (expectedDecoded params) (linesOf decoded)
    , expectEqual (name "lower" "dump") (expectedLowered params) (linesOf lowered)
    , expectEqual (name "plan" "dump") (expectedPlan params) (linesOf plan)
    , provisionedRow (name "provision" "dump") params (linesOf provisioned)
    , objectsRow (name "render" "objects") params expectedChain payloads objects
    , placeRow (name "place" "nodes") params objects
    , claimRow (name "claims" "volumes") params objects
    , appDeploymentRow (name "render" "app-deployment") params objects
    , appSmallRow (name "render" "app-namespace-service") params objects
    , chainRow (name "chain" "dump") expectedChain chainDump
    , chainManifestRow (name "chain" "manifest") expectedChain payloads objects
    , chainFormatRow (name "chain" "format") chainDump
    , dryRunRow (name "dry-run" "dump") expectedChain payloads dryRun
    , expectEqual (name "pipeline" "artefacts") (sortTexts (map snd stageFiles)) (Just (sortTexts (filter (`elem` map snd stageFiles) present)))
    , check (name "pipeline" "no-refusal") (not ("refusal.tsv" `elem` present) && not ("exception.txt" `elem` present)) (Text.pack (show present))
    ]

sortTexts :: [Text] -> [Text]
sortTexts items = case items of
  [] -> []
  pivot : rest -> sortTexts [item | item <- rest, item < pivot] <> [pivot] <> sortTexts [item | item <- rest, item >= pivot]

directoryFiles :: FilePath -> IO [Text]
directoryFiles directory = do
  present <- doesDirectoryExist directory
  if present then map Text.pack <$> listDirectory directory else pure []

-- | The provisioned dump: where each unit was placed (in no promised order), when each object
-- activates, what was provisioned for the service, and the scheduler's reservations.
provisionedRow :: Text -> Params -> Maybe [Text] -> Row
provisionedRow name params actual = case actual of
  Nothing -> Row name False "the artefact is absent or unreadable"
  Just rows ->
    let placement = [row | row <- rows, "provision.assignments\t" `Text.isPrefixOf` row]
        placed = case placement of
          [row] -> sortTexts (Text.splitOn "," (Text.drop (Text.length "provision.assignments\t") row))
          _ -> []
        rest = [row | row <- rows, not ("provision.assignments\t" `Text.isPrefixOf` row)]
        expectedRest = [expectedPlacementRow params, expectedNodesRow params] <> expectedRenderActivations params <> [expectedServiceRow params, expectedReservations params]
        expectedPlaced = sortTexts [unit <> "@" <> paramNodeOf params unit | unit <- unitsOf params]
     in check name (placed == expectedPlaced && rest == expectedRest && length placement == 1) (Text.pack (show (placed, rest)))

-- | The manifest's objects: each arrives in the chain's order carrying the identity,
-- activation and reconcile mode its annotations name, and the kind, name, namespace,
-- owner, and API version the contract gives it.
objectsRow :: Text -> Params -> [Expected] -> [Payload] -> [Manifested] -> Row
objectsRow name _ expected payloads objects = check name ok detail
 where
  ok = length payloads == length expected && length objects == length expected && null mismatches
  detail = Text.pack (show (length payloads, length objects, length expected, take 3 mismatches))
  mismatches = concat (zipWith compareObject expected objects)
  compareObject wanted found =
    [ label "identity" | annotationText "amoebius.io/object-identity" found /= Just (expectedIdentity wanted) ]
      <> [label "activation" | annotationText "amoebius.io/render-activation" found /= Just (expectedActivation wanted)]
      <> [label "reconcile" | annotationText "amoebius.io/reconcile-mode" found /= Just (expectedReconcile wanted)]
      <> [label "kind" | maybe False (/= mKind found) (expectedKind wanted)]
      <> [label "name" | mName found /= expectedName wanted]
      <> [label "namespace" | mNamespace found /= expectedNamespace wanted]
      <> [label "api-version" | mApiVersion found /= apiVersionOf (mKind found)]
      <> [label "owner" | Map.lookup "amoebius.io/owner" (mLabels found) /= Just (expectedOwner wanted)]
      <> [label "managed-by" | Map.lookup "app.kubernetes.io/managed-by" (mLabels found) /= Just "amoebius"]
      <> [label "epoch" | Map.lookup "amoebius.io/epoch" (mLabels found) /= Just "generation-1"]
   where
    label what = expectedIdentity wanted <> ":" <> what

-- | Each workload names the node the placement gave its unit: the application's deployment the
-- node of the application's unit, every provider workload the node of its own identity, and an
-- object that is no unit's workload names none.
placeRow :: Text -> Params -> [Manifested] -> Row
placeRow name params objects = check name (null wrong) (Text.pack (show (take 4 wrong)))
 where
  units = unitsOf params
  wrong =
    [ (identity, got)
    | object <- objects
    , Just got <- [podNode object]
    , Just identity <- [annotationText "amoebius.io/object-identity" object]
    , got /= expected identity
    ]
  expected identity
    | identity == "app/" <> paramApp params <> "/deployment" = String (paramNodeOf params ("app/" <> paramApp params))
    | identity `elem` units = String (paramNodeOf params identity)
    | otherwise = Null
  podNode object = case mSpec object of
    Object spec
      | Just (Array items) <- KeyMap.lookup "contents" spec
      , [String _, Object template] <- toList items -> Just (fromMaybe Null (KeyMap.lookup "podNodeName" template))
    _ -> Nothing

-- | Each claim carries the explicit size of its provider's volume, the one storage class, the
-- volume its identity pre-binds, and the StatefulSet that owns it; a StatefulSet owns exactly one
-- claim and nothing else is a claim.
claimRow :: Text -> Params -> [Manifested] -> Row
claimRow name params objects = check name (found == wanted) (Text.pack (show (found, wanted)))
 where
  found = sortTexts [Text.intercalate "|" [mName object, fromMaybe "" (mNamespace object), claimText object] | object <- objects, mKind object == "PersistentVolumeClaim"]
  wanted = sortTexts [Text.intercalate "|" ["data-" <> member <> "-0", armNamespace (needArm need), render (armNamespace (needArm need)) member (volumeBytes (needArm need))] | need <- paramNeeds params, member <- membersOf (needShape need)]
  volumeBytes arm = case arm of
    ObjectStoreArm -> "10737418240"
    SqlArm -> "8589934592"
  render namespace member size = Text.intercalate "," [size, member, "amoebius-retained", namespace <> "." <> member <> ".pv-0"]
  claimText object = case mSpec object of
    Object spec | Just (Object contents) <- KeyMap.lookup "contents" spec ->
      let field key = case KeyMap.lookup key contents of
            Just (String text) -> text
            Just (Number number) -> Text.pack (show (round number :: Integer))
            _ -> "?"
       in Text.intercalate "," [field "claimBytes", field "claimOwner", field "claimStorageClass", field "claimVolumeName"]
    _ -> "?"

-- | The annotation's value is JSON text of a string.
annotationText :: Text -> Manifested -> Maybe Text
annotationText key object = do
  raw <- Map.lookup key (mAnnotations object)
  case eitherDecodeStrict' (Encoding.encodeUtf8 raw) of
    Right (String text) -> Just text
    _ -> Nothing

apiVersionOf :: Text -> Text
apiVersionOf kind = case kind of
  "Deployment" -> "apps/v1"
  "StatefulSet" -> "apps/v1"
  "Job" -> "batch/v1"
  "NetworkPolicy" -> "networking.k8s.io/v1"
  "ValidatingWebhookConfiguration" -> "admissionregistration.k8s.io/v1"
  _ -> "v1"

objectNamed :: Text -> [Manifested] -> Maybe Manifested
objectNamed identity objects = case [object | object <- objects, annotationText "amoebius.io/object-identity" object == Just identity] of
  object : _ -> Just object
  [] -> Nothing

-- | The application's workload carries the authored replica count and resources, the
-- hardened security context, the node the placement gave it, no accelerator, bounded
-- volumes, and an image named for the application.
appDeploymentRow :: Text -> Params -> [Manifested] -> Row
appDeploymentRow name params objects = case objectNamed ("app/" <> paramApp params <> "/deployment") objects >>= pod of
  Nothing -> Row name False "the application's workload is absent or has no pod template"
  Just template ->
    let fields = KeyMap.toList template
        get key = lookup (Key.fromText key) fields
     in check name
          ( get "podReplicas" == Just (Number (fromIntegral (paramReplicas params)))
              && get "podResources" == Just (resources (vector 1 2 4) (vector 2 4 8))
              && get "podSecurityContext" == Just (security)
              && get "podSchedulerName" == Just (String "amoebius-capacity")
              && get "podNodeName" == Just (String (paramNodeOf params ("app/" <> paramApp params)))
              && get "podAcceleratorClaim" == Just Null
              && get "podVolumesBounded" == Just (Bool True)
              && maybe False (\value -> case value of String image -> ("@sha256:" `Text.isInfixOf` image) && (paramApp params `Text.isInfixOf` image); _ -> False) (get "podImage")
          )
          (Text.pack (show template))
 where
  pod object = case mSpec object of
    Object spec | Just (Array items) <- KeyMap.lookup "contents" spec, [String "DeploymentWorkload", Object template] <- toList items -> Just template
    _ -> Nothing
  vector cpu memory ephemeral = Object (KeyMap.fromList [("resourceCpu", Number cpu), ("resourceMemory", Number memory), ("resourceEphemeralStorage", Number ephemeral), ("resourcePodSlots", Number 1)])
  resources requests limits = Object (KeyMap.fromList [("resourceRequests", requests), ("resourceLimits", limits)])
  security = Object (KeyMap.fromList [("securityRunAsNonRoot", Bool True), ("securityReadOnlyRootFilesystem", Bool True), ("securityAllowPrivilegeEscalation", Bool False)])

-- | The application's namespace and endpoint carry the specifications their kinds take.
appSmallRow :: Text -> Params -> [Manifested] -> Row
appSmallRow name params objects =
  check name
    ( fmap specTag (objectNamed ("app/" <> app <> "/namespace") objects) == Just (Just "NamespaceSpec")
        && fmap specTag (objectNamed ("app/" <> app <> "/service") objects) == Just (Just "ServiceSpec")
        && fmap specContents (objectNamed ("app/" <> app <> "/service") objects) == Just (Just (String "ClusterInternal"))
    )
    "the application's namespace or endpoint has an unexpected specification"
 where
  app = paramApp params
  specTag object = case mSpec object of
    Object spec -> case KeyMap.lookup "tag" spec of
      Just (String tag) -> Just tag
      _ -> Nothing
    _ -> Nothing
  specContents object = case mSpec object of
    Object spec -> KeyMap.lookup "contents" spec
    _ -> Nothing

-- | The chain dump: one apply step per object in the chain's order, each labelled by and
-- carrying its object's identity, in the frame its activation belongs to.
chainRow :: Text -> [Expected] -> Maybe ByteString -> Row
chainRow name expected bytes = case bytes >>= either (const Nothing) Just . eitherDecodeStrict' of
  Just (Object root) | Just (Array entries) <- KeyMap.lookup "planEntries" root ->
    let found = map entryOf (toList entries)
        wanted = [Just (expectedIdentity item, frameOf (expectedActivation item)) | item <- expected]
     in check name (found == wanted && length entries == length expected) (Text.pack (show found))
  _ -> Row name False "the chain dump is absent or is not a plan"
 where
  entryOf entry = case entry of
    Object fields ->
      case (KeyMap.lookup "planEntryLabel" fields, KeyMap.lookup "planEntryFrame" fields, KeyMap.lookup "planEntryKind" fields, KeyMap.lookup "planEntryObjectIdentities" fields) of
        (Just (String label), Just (String frame), Just (String "ApplyObjects"), Just (Array identities))
          | [String only] <- toList identities, only == label -> Just (label, frame)
        _ -> Nothing
    _ -> Nothing

-- | The manifest carries one array per step, in the chain's order, each holding its step's object.
chainManifestRow :: Text -> [Expected] -> [Payload] -> [Manifested] -> Row
chainManifestRow name expected payloads objects =
  check name (length payloads == length expected && map (annotationText "amoebius.io/object-identity") objects == map (Just . expectedIdentity) expected) (Text.pack (show (length payloads, length objects)))

-- | The chain dump is written in its canonical form: two-space indentation, keys in order.
chainFormatRow :: Text -> Maybe ByteString -> Row
chainFormatRow name bytes = case fmap (Text.lines . Encoding.decodeUtf8) bytes of
  Just rows ->
    check name
      ( take 5 rows == ["{", "  \"planEntries\": [", "    {", "      \"planEntryFrame\": \"ImmediateFrame\",", "      \"planEntryKind\": \"ApplyObjects\","]
          && drop (length rows - 3) rows == ["    }", "  ]", "}"]
      )
      (Text.pack (show (take 5 rows)))
  Nothing -> Row name False "the chain dump is absent"

-- | The dry run lists, for each step in order, its label, the arguments the executor would
-- pass, and the digest of the payload it would receive, which the oracle recomputes.
dryRunRow :: Text -> [Expected] -> [Payload] -> Maybe Text -> Row
dryRunRow name expected payloads dump = expectEqual name wanted (linesOf dump)
 where
  wanted = [Text.intercalate "\t" [Text.pack (show position), expectedIdentity item, "apply --server-side=true -f -", sha256Hex payload] | (position, item, payload) <- zip3 [1 :: Int ..] expected payloads]

-- | The objects of a manifest, in the order they appear.
manifestObjects :: Maybe ByteString -> [Manifested]
manifestObjects = mapMaybe parseObject . maybe [] splitPayloads

-- | Each object of a manifest with the identity its annotation names and the bytes it arrived as.
manifestEntries :: Maybe ByteString -> [(Text, Payload, Manifested)]
manifestEntries bytes = [(identity, payload, object) | payload <- maybe [] splitPayloads bytes, Just object <- [parseObject payload], Just identity <- [annotationText "amoebius.io/object-identity" object]]

-- | The fake's transcript of one scenario: the number of calls, each call's arguments,
-- environment, and stdin, the concatenation of the stdin, and the digest of that
-- concatenation recomputed here.
fakeTranscriptRows :: Text -> FilePath -> [Payload] -> IO [Row]
fakeTranscriptRows name directory expectedPayloads = do
  countText <- readText (directory </> "kubectl.count")
  combined <- readBytes (directory </> "stdin.combined")
  applied <- readText (directory </> "applied.sha256")
  let count = fromMaybe 0 (countText >>= readCount)
  calls <- mapM (call directory) [1 .. length expectedPayloads]
  let argvOk = all (\(argv, _, _) -> argv == Just ["kubectl", "apply", "--server-side=true", "-f", "-"]) calls
      envOk = all (\(_, env, _) -> env == Just ["AMOEBIUS_FAKE_TRANSCRIPT"]) calls
      stdinOk = and (zipWith (\(_, _, stdin) wanted -> stdin == Just wanted) calls expectedPayloads)
      wantedCombined = ByteString.concat expectedPayloads
  pure
    [ check (name <> ".count") (count == length expectedPayloads) (Text.pack (show (count, length expectedPayloads)))
    , check (name <> ".argv") argvOk "a call did not receive the apply arguments"
    , check (name <> ".environment") envOk "a call saw an environment other than the transcript variable"
    , check (name <> ".stdin") stdinOk "a call's stdin differs from the payload the chain hands it"
    , check (name <> ".combined") (if null expectedPayloads then combined == Nothing else combined == Just wantedCombined) "the combined stdin differs from the concatenated payloads"
    , check (name <> ".digest") (if null expectedPayloads then applied == Nothing else applied == Just (sha256Hex wantedCombined <> "\n")) "the applied digest differs from the digest of the combined stdin"
    ]
 where
  readCount text = case Text.unpack (Text.strip text) of
    digits | not (null digits), all (`elem` ['0' .. '9']) digits -> Just (read digits)
    _ -> Nothing

call :: FilePath -> Int -> IO (Maybe [Text], Maybe [Text], Maybe ByteString)
call directory index = do
  let stem = directory </> ("kubectl." <> show index)
  argv <- readText (stem <> ".argv")
  env <- readText (stem <> ".env")
  stdin <- readBytes (stem <> ".stdin")
  pure (fmap Text.lines argv, fmap Text.lines env, stdin)
