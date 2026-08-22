{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Amoebius.Calculus.Artifact.Recipe (RecipeId (RecipeId))
import Amoebius.Calculus.Budget.Grant (Bytes (Bytes), Slots (Slots), allowance)
import Amoebius.Calculus.Composition
  ( append
  , artifactComponent
  , budgetComponent
  , calculusTag
  , compose
  , compositionKinds
  , compositionNames
  , compositionResource
  , evidenceComponent
  , everyCalculus
  , liftComponent
  , singleton
  , workflowComponent
  )
import Amoebius.Calculus.Evidence.Register (Register (PureRegister))
import Amoebius.Calculus.Lift.Layer (Layer (OnHost))
import Amoebius.Calculus.Workflow.Ledger (emptyLedger)
import Amoebius.Capacity.Types (ResourceVector (ResourceVector))
import Amoebius.Scope.Index qualified as CalculusScope
import Amoebius.Ui.Bind
import Amoebius.Ui.Check (checkUiSource)
import Amoebius.Ui.ExternalLinkCatalog
import Amoebius.Ui.Security.Authorization
import Amoebius.Ui.Security.Scope
import Amoebius.Ui.Source (decodeUiSource)
import Control.Monad (forM_, unless)
import Data.List (sort)
import qualified Data.Text as Text
import EffectBindingReference (referenceBindings, referenceExternalLinks)
import System.Directory (canonicalizePath, getCurrentDirectory)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import Test.QuickCheck
  ( Args (..)
  , Property
  , checkCoverage
  , counterexample
  , cover
  , elements
  , forAll
  , isSuccess
  , property
  , quickCheckWithResult
  , stdArgs
  )
import Test.QuickCheck.Random (mkQCGen)

data Fixture = Fixture
  { authorizationRegistry :: BoundActionRegistry
  , ports :: [PortRequirement]
  , handlers :: [HandlerSpec]
  , capabilities :: [CapabilityBinding]
  , links :: BoundExternalLinks
  }

data CoverageClass
  = ReadPortClass
  | MutatePortClass
  | StartPortClass
  | ObservePortClass
  | SubscribePortClass
  | UploadPortClass
  | ArtifactPortClass
  | MissingHandlerClass
  | DuplicateHandlerClass
  | ContractMismatchClass
  | ScopeMismatchClass
  | MissingCapabilityClass
  | UnsafeRetryClass
  deriving stock (Bounded, Enum, Eq, Show)

data Mutant = Mutant
  { mutantName :: String
  , mutantCase :: String
  , mutantFile :: FilePath
  , mutantMarker :: String
  }

mutants :: [Mutant]
mutants =
  [ Mutant "M-first-handler-wins" "duplicate-handler" "M-first-handler-wins.mutant" "quantifier-weakening"
  , Mutant "M-drop-capability" "missing-capability" "M-drop-capability.mutant" "guard-deletion"
  , Mutant "M-erase-handler-scope" "scope-mismatch" "M-erase-handler-scope.mutant" "scope-guard-deletion"
  , Mutant "M-swap-response-codec" "codec-mismatch" "M-swap-response-codec.mutant" "effect-type-swap"
  , Mutant "M-retry-without-idempotency" "unsafe-retry" "M-retry-without-idempotency.mutant" "invariant-clause-delete"
  , Mutant "export_raw_topic" "raw-topic" "export_raw_topic.mutant" "provider-coordinate-escape"
  , Mutant "M-link-id-as-url" "link-as-url" "M-link-id-as-url.mutant" "escape-arm-addition"
  ]

main :: IO ()
main = do
  root <- getCurrentDirectory >>= canonicalizePath
  fixture <- buildFixture root
  arguments <- getArgs
  case arguments of
    [] -> runGreen root fixture
    [argument] | "--mutant=" `prefixOf` argument -> runMutant root fixture (drop 9 argument)
    _ -> die ("unknown arguments: " <> show arguments)

runGreen :: FilePath -> Fixture -> IO ()
runGreen root fixture = do
  checkBindingOracle root fixture
  checkExternalLinkOracle root fixture
  checkPinnedErrors root fixture
  checkAdditionalLinkErrors
  checkBoundedPortErrors fixture
  checkCoverageProperties fixture
  checkCalculus root
  checkMutantControls root fixture
  putStrLn "ui-effect-binding-calculus: PASS (5 kinds, 48 projected units)"
  putStrLn "ui-effect-binding-spec: PASS (7 ports, 2 links, 8 errors, 13 coverage classes, 7 mutants)"

buildFixture :: FilePath -> IO Fixture
buildFixture root = do
  portRows <- loadTable (root </> "test/fixture/ui_effect_binding/ports.tsv")
  handlerRows <- loadTable (root </> "test/fixture/ui_effect_binding/handlers.tsv")
  capabilityRows <- loadTable (root </> "test/fixture/ui_effect_binding/capabilities.tsv")
  linkRows <- loadTable (root </> "test/fixture/ui_effect_binding/external_link_catalog.tsv")
  parsedPorts <- traverse parsePort portRows
  parsedHandlers <- traverse parseHandler handlerRows
  parsedCapabilities <- traverse parseCapability capabilityRows
  requirements <- traverse (requireLink . firstField) linkRows
  entries <- traverse parseLinkEntry linkRows
  boundLinks <- requireRight "external links" (bindExternalLinks requirements entries)
  authorization <- buildAuthorizationRegistry root
  pure Fixture
    { authorizationRegistry = authorization
    , ports = parsedPorts
    , handlers = parsedHandlers
    , capabilities = parsedCapabilities
    , links = boundLinks
    }

buildAuthorizationRegistry :: FilePath -> IO BoundActionRegistry
buildAuthorizationRegistry root = do
  decoded <- decodeUiSource (root </> "test/fixture/ui_program_schema/minimal_single_tenant.dhall")
  source <- either (die . Text.unpack) pure decoded
  checked <- either (die . show) pure (checkUiSource source)
  tenant <- requireRight "tenant" (trustedTenant "tenant-a")
  subject <- requireRight "subject" (trustedSubject tenant "alice")
  membership <- requireRight "membership" (activeMembership tenant subject)
  context <- requireRight "context" (trustedRequestContext tenant subject membership)
  let scoped = scopeCheckedProgram checked context
  actionRows <- loadTable (root </> "test/fixture/ui_authorization/action_registry.tsv")
  specs <- traverse parseAuthorizationAction actionRows
  let projections = map projectAuthorization specs
  requireRight "authorization registry" (bindActionRegistry scoped specs projections)

checkBindingOracle :: FilePath -> Fixture -> IO ()
checkBindingOracle root fixture = do
  portRows <- loadTable (root </> "test/fixture/ui_effect_binding/ports.tsv")
  handlerRows <- loadTable (root </> "test/fixture/ui_effect_binding/handlers.tsv")
  capabilityRows <- loadTable (root </> "test/fixture/ui_effect_binding/capabilities.tsv")
  expected <- loadTable (root </> "test/fixture/ui_effect_binding/expected_bindings.tsv")
  reference <- either die pure (referenceBindings portRows handlerRows capabilityRows)
  bound <- requireRight "bind fixture" (bindFixture fixture (ports fixture) (handlers fixture) (capabilities fixture))
  let actual = sort (map renderBoundPort (boundPortProjection bound))
  assertEqual "authored expected bindings" (sort expected) reference
  assertEqual "production/independent binding" reference actual
  assertEqual "all seven port effects" [minBound .. maxBound] (sort (map requiredEffect (ports fixture)))

checkExternalLinkOracle :: FilePath -> Fixture -> IO ()
checkExternalLinkOracle root fixture = do
  expected <- loadTable (root </> "test/fixture/ui_effect_binding/expected_external_links.tsv")
  catalog <- loadTable (root </> "test/fixture/ui_effect_binding/external_link_catalog.tsv")
  reference <- either die pure (referenceExternalLinks expected catalog)
  bound <- requireRight "bind links" (bindFixture fixture (ports fixture) (handlers fixture) (capabilities fixture))
  let actual = sort (map renderResolvedLink (boundExternalLinkProjection bound))
  assertEqual "authored external links" (sort expected) reference
  assertEqual "production/independent links" reference actual

checkPinnedErrors :: FilePath -> Fixture -> IO ()
checkPinnedErrors root fixture = do
  rows <- loadTable (root </> "test/fixture/ui_effect_binding/bind_errors.tsv")
  assertEqual "pinned bind error count" 8 (length rows)
  forM_ rows $ \row -> case row of
    [caseName, expected] -> do
      result <- bindCaseResult fixture caseName
      let actual = either (Text.unpack . uiBindErrorTag) (const "accepted") result
      assertEqual caseName expected actual
      assertEqual (caseName <> " denied trace") ([] :: [BindEvent]) (either (const []) interpretBoundProgram result)
    _ -> die ("invalid bind error row: " <> show row)

bindErrorCase :: Fixture -> String -> IO String
bindErrorCase fixture caseName = do
  result <- bindCaseResult fixture caseName
  pure (either (Text.unpack . uiBindErrorTag) (const "accepted") result)

bindCaseResult :: Fixture -> String -> IO (Either UiBindError BoundUiProgram)
bindCaseResult fixture caseName = case caseName of
  "missing-handler" -> pure (bindFixture fixture (ports fixture) (removeHandler "data-read" (handlers fixture)) (capabilities fixture))
  "duplicate-handler" -> pure (bindFixture fixture (ports fixture) (handlers fixture <> take 1 (handlers fixture)) (capabilities fixture))
  "codec-mismatch" -> do
    codec <- requireRight "mismatched codec" (trustedCodec "MutationReceipt")
    pure (bindFixture fixture (ports fixture) (map (changeResponse "data-read" codec) (handlers fixture)) (capabilities fixture))
  "missing-capability" -> pure (bindFixture fixture (ports fixture) (handlers fixture) (removeCapability "data-read" (capabilities fixture)))
  "scope-mismatch" -> pure (bindFixture fixture (ports fixture) (map (changeScope "data-read" TenantScope) (handlers fixture)) (capabilities fixture))
  "unsafe-retry" -> pure (bindFixture fixture (ports fixture) (map (changeRetry "data-write" NoRetryContract) (handlers fixture)) (capabilities fixture))
  "raw-topic" -> pure (targetResult fixture (parsePortEffectTarget "pulsar://tenant/raw-topic"))
  "link-as-url" -> pure (targetResult fixture (parsePortEffectTarget "link:docs"))
  _ -> die ("unknown bind error case: " <> caseName)

targetResult :: Fixture -> Either UiBindError PortEffect -> Either UiBindError BoundUiProgram
targetResult fixture target = case target of
  Left problem -> Left problem
  Right _ -> bindFixture fixture (ports fixture) (handlers fixture) (capabilities fixture)

checkAdditionalLinkErrors :: IO ()
checkAdditionalLinkErrors = do
  docs <- requireLink "docs"
  extra <- requireLink "extra"
  let requirement = [docs]
      valid = ExternalLinkCatalogEntry (linkOf docs) "https://docs.example.invalid/help"
      cases :: [(String, Either UiLinkBindError BoundExternalLinks)]
      cases =
        [ ("missing", bindExternalLinks requirement [])
        , ("duplicate", bindExternalLinks requirement [valid, valid])
        , ("http", bindExternalLinks requirement [ExternalLinkCatalogEntry (linkOf docs) "http://docs.example.invalid/help"])
        , ("userinfo", bindExternalLinks requirement [ExternalLinkCatalogEntry (linkOf docs) "https://user@docs.example.invalid/help"])
        , ("wildcard", bindExternalLinks requirement [ExternalLinkCatalogEntry (linkOf docs) "https://*.example.invalid/help"])
        , ("noncanonical", bindExternalLinks requirement [ExternalLinkCatalogEntry (linkOf docs) "https://Docs.example.invalid/help"])
        , ("template", bindExternalLinks requirement [ExternalLinkCatalogEntry (linkOf docs) "https://docs.example.invalid/{tenant}"])
        , ("unexpected", bindExternalLinks requirement [valid, ExternalLinkCatalogEntry (linkOf extra) "https://extra.example.invalid/help"])
        ]
      expected =
        [ "MissingExternalLink", "DuplicateExternalLink", "InsecureExternalLink", "UserInfoExternalLink"
        , "WildcardExternalLink", "NoncanonicalExternalLink", "CallerTemplatedExternalLink", "UnexpectedExternalLink"
        ]
  assertEqual "external-link negative tags" expected (map (either (Text.unpack . uiLinkBindErrorTag) (const "accepted") . snd) cases)

checkBoundedPortErrors :: Fixture -> IO ()
checkBoundedPortErrors fixture = do
  rawBlob <- requireRight "raw blob codec" (trustedCodec "Blob")
  rawSubscription <- requireRight "raw subscription codec" (trustedCodec "UnboundedStream")
  rawArtifact <- requireRight "raw artifact codec" (trustedCodec "ArtifactId")
  let mutations =
        [ ("upload", rawBlob, "UnboundedUpload")
        , ("subscribe", rawSubscription, "UnboundedSubscription")
        , ("artifact", rawArtifact, "ArtifactNotReady")
        ]
  forM_ mutations $ \(portName, codec, expected) -> do
    let changed = map (changePortRequest portName codec) (ports fixture)
    assertEqual (portName <> " bounded check") expected
      (either (Text.unpack . uiBindErrorTag) (const "accepted") (bindFixture fixture changed (handlers fixture) (capabilities fixture)))

checkCoverageProperties :: Fixture -> IO ()
checkCoverageProperties fixture = do
  let classes = [minBound .. maxBound] :: [CoverageClass]
      args = stdArgs {maxSuccess = 700, replay = Just (mkQCGen 190019, 0), chatty = False}
  result <- quickCheckWithResult args $ forAll (elements classes) (coverageProperty fixture classes)
  assert (isSuccess result) "effect-binding generated coverage failed"

checkCalculus :: FilePath -> IO ()
checkCalculus root = do
  expected <- loadTable (root </> "test/oracle/ui_effect_binding/calculus_projection.tsv")
  tenant <- requireRight "calculus tenant" (CalculusScope.trustedTenant "ui-effect-binding-calculus-tenant")
  subject <- requireRight "calculus subject" (CalculusScope.trustedSubject tenant "ui-effect-binding-calculus-subject")
  membership <- requireRight "calculus membership" (CalculusScope.activeMembership tenant subject)
  action <- requireRight "calculus request scope" $
    CalculusScope.withRequestScope tenant subject membership $ \scope -> do
      let resources :: Int -> ResourceVector
          resources count = ResourceVector 1 (fromIntegral count) 0 0
          counts = [7, 2, 19, 13, 7] :: [Int]
          artifact = artifactComponent scope "port-bindings" (resources 7) (RecipeId "ui-effect-binding" 7)
          budget = budgetComponent scope "external-link-bindings" (resources 2)
            (allowance (Bytes 2) (Slots 1) (Bytes 2))
          lift = liftComponent scope "binding-refusals" (resources 19) OnHost
          workflow = workflowComponent scope "generated-coverage-workflow" (resources 13) emptyLedger
          evidence = evidenceComponent scope "mutant-evidence" (resources 7) PureRegister
          composition = append (compose artifact budget) (append (compose lift workflow) (singleton evidence))
          ResourceVector cpu memory ephemeral pods = compositionResource composition
          render = Text.unpack . Text.intercalate ","
          actual =
            [ ["calculus-kinds", render (map calculusTag (compositionKinds composition))]
            , ["component-names", render (compositionNames composition)]
            , ["projection-counts", render (map (Text.pack . show) counts)]
            , ["resource-vector", render (map (Text.pack . show) [cpu, memory, ephemeral, pods])]
            ]
      assertEqual "five calculus kinds" everyCalculus (compositionKinds composition)
      assertEqual "effect-binding calculus projection" expected actual
  action

coverageProperty :: Fixture -> [CoverageClass] -> CoverageClass -> Property
coverageProperty fixture classes selected =
  checkCoverage
    $ foldr (\coverageClass -> cover 5 (selected == coverageClass) (show coverageClass))
      (counterexample (show selected) (property (exerciseClass fixture selected)))
      classes

exerciseClass :: Fixture -> CoverageClass -> Bool
exerciseClass fixture coverageClass = case coverageClass of
  ReadPortClass -> portBinds PortReadData
  MutatePortClass -> portBinds PortMutateData
  StartPortClass -> portBinds PortStartWorkflow
  ObservePortClass -> portBinds PortObserveWorkflow
  SubscribePortClass -> portBinds PortSubscribe
  UploadPortClass -> portBinds PortUploadBounded
  ArtifactPortClass -> portBinds PortUseReadyArtifact
  MissingHandlerClass -> rejected MissingHandlerTag
    (bindFixture fixture (ports fixture) (removeHandler "data-read" (handlers fixture)) (capabilities fixture))
  DuplicateHandlerClass -> rejected DuplicateHandlerTag
    (bindFixture fixture (ports fixture) (handlers fixture <> take 1 (handlers fixture)) (capabilities fixture))
  ContractMismatchClass -> case handlerNamed fixture "data-write" of
    Nothing -> False
    Just source -> rejected ContractMismatchTag
      (bindFixture fixture (ports fixture) (map (changeResponse "data-read" (handlerResponse source)) (handlers fixture)) (capabilities fixture))
  ScopeMismatchClass -> rejected ScopeMismatchTag
    (bindFixture fixture (ports fixture) (map (changeScope "data-read" TenantScope) (handlers fixture)) (capabilities fixture))
  MissingCapabilityClass -> rejected MissingCapabilityTag
    (bindFixture fixture (ports fixture) (handlers fixture) (removeCapability "data-read" (capabilities fixture)))
  UnsafeRetryClass -> rejected IdempotencyRequiredTag
    (bindFixture fixture (ports fixture) (map (changeRetry "data-write" NoRetryContract) (handlers fixture)) (capabilities fixture))
  where
    portBinds effect = case (portNamedByEffect fixture effect, bindFixture fixture (ports fixture) (handlers fixture) (capabilities fixture)) of
      (Just expectedPort, Right bound) -> any (\projection -> boundPort projection == requiredPort expectedPort) (boundPortProjection bound)
      _ -> False
    rejected tag = either ((== tag) . tagClass) (const False)

data ErrorTagClass
  = MissingHandlerTag
  | DuplicateHandlerTag
  | ContractMismatchTag
  | ScopeMismatchTag
  | MissingCapabilityTag
  | IdempotencyRequiredTag
  | OtherTag
  deriving stock (Eq)

tagClass :: UiBindError -> ErrorTagClass
tagClass problem = case problem of
  MissingHandler _ -> MissingHandlerTag
  DuplicateHandler _ -> DuplicateHandlerTag
  ContractMismatch _ -> ContractMismatchTag
  ScopeMismatch _ -> ScopeMismatchTag
  MissingCapability _ -> MissingCapabilityTag
  IdempotencyRequired _ -> IdempotencyRequiredTag
  _ -> OtherTag

checkMutantControls :: FilePath -> Fixture -> IO ()
checkMutantControls root fixture = forM_ mutants $ \mutant -> do
  source <- readFile (root </> "test/mutant/ui_effect_binding" </> mutantFile mutant)
  assert (mutantMarker mutant `contains` source) (mutantName mutant <> " fixture drifted")
  actual <- bindErrorCase fixture (mutantCase mutant)
  assert (actual /= "accepted") (mutantName mutant <> " has no red production locus")

runMutant :: FilePath -> Fixture -> String -> IO ()
runMutant root fixture name = case firstMatching ((== name) . mutantName) mutants of
  Nothing -> die ("unknown mutant: " <> name)
  Just mutant -> do
    checkMutantControls root fixture
    putStrLn ("ui-effect-binding-mutant: RED " <> mutantName mutant <> " locus=" <> mutantCase mutant)
    exitFailure

bindFixture
  :: Fixture -> [PortRequirement] -> [HandlerSpec] -> [CapabilityBinding]
  -> Either UiBindError BoundUiProgram
bindFixture fixture portValues handlerValues capabilityValues =
  bindUiProgram (authorizationRegistry fixture) portValues handlerValues capabilityValues (links fixture)

parsePort :: [String] -> IO PortRequirement
parsePort row = case row of
  [portName, request, response, scope, effect] -> PortRequirement
    <$> requireRight portName (trustedPortId (Text.pack portName))
    <*> requireRight request (trustedCodec (Text.pack request))
    <*> requireRight response (trustedCodec (Text.pack response))
    <*> parseScope scope
    <*> requireRight effect (parsePortEffectTarget (Text.pack effect))
  _ -> die ("invalid port row: " <> show row)

parseHandler :: [String] -> IO HandlerSpec
parseHandler row = case row of
  [name, request, response, scope, retry, audit] -> HandlerSpec
    <$> requireRight name (trustedHandlerId (Text.pack name))
    <*> requireRight request (trustedCodec (Text.pack request))
    <*> requireRight response (trustedCodec (Text.pack response))
    <*> parseScope scope
    <*> parseRetry retry
    <*> parseAudit audit
  _ -> die ("invalid handler row: " <> show row)

parseCapability :: [String] -> IO CapabilityBinding
parseCapability row = case row of
  [handler, capability] -> CapabilityBinding
    <$> requireRight handler (trustedHandlerId (Text.pack handler))
    <*> parseCapabilityName capability
  _ -> die ("invalid capability row: " <> show row)

parseLinkEntry :: [String] -> IO ExternalLinkCatalogEntry
parseLinkEntry row = case row of
  [name, url] -> ExternalLinkCatalogEntry
    <$> requireRight name (trustedExternalLinkId (Text.pack name))
    <*> pure (Text.pack url)
  _ -> die ("invalid external-link row: " <> show row)

requireLink :: String -> IO ExternalLinkRequirement
requireLink name = ExternalLinkRequirement <$> requireRight name (trustedExternalLinkId (Text.pack name))

linkOf :: ExternalLinkRequirement -> ExternalLinkId
linkOf (ExternalLinkRequirement link) = link

parseAuthorizationAction :: [String] -> IO ActionSpec
parseAuthorizationAction row = case row of
  [name, effect, permission, visibility, idempotent] -> ActionSpec
    <$> requireRight name (trustedActionId (Text.pack name))
    <*> parseActionEffect effect
    <*> parsePermission permission
    <*> parseVisibility visibility
    <*> parseBoolean idempotent
  _ -> die ("invalid authorization action: " <> show row)

projectAuthorization :: ActionSpec -> ActionProjection
projectAuthorization spec = ActionProjection
  (specAction spec) (specEffect spec) (specPermission spec) (specVisibility spec) (specIdempotent spec)

parseActionEffect :: String -> IO ActionEffect
parseActionEffect value = case value of
  "ReadData" -> pure ReadData
  "MutateData" -> pure MutateData
  "StartWorkflow" -> pure StartWorkflow
  "ObserveWorkflow" -> pure ObserveWorkflow
  "EndSession" -> pure EndSession
  _ -> die ("invalid authorization effect: " <> value)

parsePermission :: String -> IO Permission
parsePermission value = case value of
  "read" -> pure ReadPermission
  "write" -> pure WritePermission
  "invoke" -> pure InvokePermission
  _ -> die ("invalid permission: " <> value)

parseVisibility :: String -> IO Visibility
parseVisibility value = case value of
  "visible" -> pure Visible
  "hidden" -> pure Hidden
  _ -> die ("invalid visibility: " <> value)

parseBoolean :: String -> IO Bool
parseBoolean value = case value of
  "true" -> pure True
  "false" -> pure False
  _ -> die ("invalid Boolean: " <> value)

parseScope :: String -> IO ScopeRequirement
parseScope value = case value of
  "owner" -> pure OwnerScope
  "tenant" -> pure TenantScope
  "grant" -> pure GrantScope
  _ -> die ("invalid scope: " <> value)

parseRetry :: String -> IO RetryPolicy
parseRetry value = case value of
  "none" -> pure NoRetryContract
  "required" -> pure IdempotentRetry
  _ -> die ("invalid retry policy: " <> value)

parseAudit :: String -> IO AuditClass
parseAudit value = case value of
  "read" -> pure ReadAudit
  "mutation" -> pure MutationAudit
  "workflow" -> pure WorkflowAudit
  "stream" -> pure StreamAudit
  "blob" -> pure BlobAudit
  "artifact" -> pure ArtifactAudit
  _ -> die ("invalid audit class: " <> value)

parseCapabilityName :: String -> IO CapabilityName
parseCapabilityName value = case value of
  "SqlRead" -> pure SqlRead
  "SqlWrite" -> pure SqlWrite
  "Workflow" -> pure Workflow
  "PulsarSubscription" -> pure PulsarSubscription
  "ContentStore" -> pure ContentStore
  "InferenceEngine" -> pure InferenceEngine
  _ -> die ("invalid capability: " <> value)

renderBoundPort :: BoundPortProjection -> [String]
renderBoundPort projection =
  [ Text.unpack (portIdText (boundPort projection))
  , Text.unpack (handlerIdText (boundHandler projection))
  , show (boundCapability projection)
  , renderScope (boundScope projection)
  , renderRetry (boundRetry projection)
  , renderAudit (boundAudit projection)
  ]

renderResolvedLink :: ResolvedExternalLink -> [String]
renderResolvedLink link =
  [ Text.unpack (externalLinkIdText (resolvedLinkId link))
  , Text.unpack (resolvedLinkUrl link)
  , Text.unpack (resolvedLinkTarget link)
  , Text.unpack (resolvedLinkRel link)
  ]

renderScope :: ScopeRequirement -> String
renderScope scope = case scope of OwnerScope -> "owner"; TenantScope -> "tenant"; GrantScope -> "grant"

renderRetry :: RetryPolicy -> String
renderRetry retry = case retry of NoRetryContract -> "none"; IdempotentRetry -> "required"

renderAudit :: AuditClass -> String
renderAudit audit = case audit of
  ReadAudit -> "read"
  MutationAudit -> "mutation"
  WorkflowAudit -> "workflow"
  StreamAudit -> "stream"
  BlobAudit -> "blob"
  ArtifactAudit -> "artifact"

portNamedByEffect :: Fixture -> PortEffect -> Maybe PortRequirement
portNamedByEffect fixture effect = firstMatching ((== effect) . requiredEffect) (ports fixture)

handlerNamed :: Fixture -> String -> Maybe HandlerSpec
handlerNamed fixture name = firstMatching ((== Text.pack name) . handlerIdText . handlerId) (handlers fixture)

changeResponse :: String -> Codec -> HandlerSpec -> HandlerSpec
changeResponse name codec handler
  | handlerIdText (handlerId handler) == Text.pack name = handler {handlerResponse = codec}
  | otherwise = handler

changeScope :: String -> ScopeRequirement -> HandlerSpec -> HandlerSpec
changeScope name scope handler
  | handlerIdText (handlerId handler) == Text.pack name = handler {handlerScope = scope}
  | otherwise = handler

changeRetry :: String -> RetryPolicy -> HandlerSpec -> HandlerSpec
changeRetry name retry handler
  | handlerIdText (handlerId handler) == Text.pack name = handler {handlerRetry = retry}
  | otherwise = handler

changePortRequest :: String -> Codec -> PortRequirement -> PortRequirement
changePortRequest name codec port
  | portIdText (requiredPort port) == Text.pack name = port {requiredRequest = codec}
  | otherwise = port

removeHandler :: String -> [HandlerSpec] -> [HandlerSpec]
removeHandler name = filter ((/= Text.pack name) . handlerIdText . handlerId)

removeCapability :: String -> [CapabilityBinding] -> [CapabilityBinding]
removeCapability name = filter (\(CapabilityBinding handler _) -> handlerIdText handler /= Text.pack name)

firstField :: [String] -> String
firstField row = case row of value : _ -> value; [] -> ""

firstMatching :: (value -> Bool) -> [value] -> Maybe value
firstMatching predicate values = case filter predicate values of value : _ -> Just value; [] -> Nothing

loadTable :: FilePath -> IO [[String]]
loadTable path = do
  content <- readFile path
  case lines content of
    [] -> die ("empty TSV: " <> path)
    _header : rows -> pure (map splitTabs (filter (not . null) rows))

splitTabs :: String -> [String]
splitTabs value = case break (== '\t') value of
  (field, []) -> [field]
  (field, _ : rest) -> field : splitTabs rest

contains :: String -> String -> Bool
contains needle haystack = any (needle `prefixOf`) (tails haystack)
  where
    tails [] = [[]]
    tails value@(_ : rest) = value : tails rest

prefixOf :: String -> String -> Bool
prefixOf [] _ = True
prefixOf _ [] = False
prefixOf (left : lefts) (right : rights) = left == right && prefixOf lefts rights

requireRight :: Show problem => String -> Either problem value -> IO value
requireRight label result = either (die . ((label <> ": ") <>) . show) pure result

assertEqual :: (Eq value, Show value) => String -> value -> value -> IO ()
assertEqual label expected actual = assert (expected == actual) (label <> ": expected " <> show expected <> ", got " <> show actual)

assert :: Bool -> String -> IO ()
assert condition message = unless condition (die message)

die :: String -> IO value
die message = putStrLn ("ui-effect-binding-spec: FAIL: " <> message) >> exitFailure
